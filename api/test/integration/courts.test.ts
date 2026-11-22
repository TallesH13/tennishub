import bcrypt from 'bcryptjs';
import type { FastifyInstance } from 'fastify';
import type pg from 'pg';
import request from 'supertest';
import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { buildApp } from '../../src/app.js';
import { createTestPool } from '../helpers/database.js';
import { insertBooking, resetData } from '../helpers/fixtures.js';

const TEST_SECRET = 'integration-test-courts-secret-min-32-chars';
const OWNER_EMAIL = 'proprietario@tennishub.com';
const OWNER_PASSWORD = 'SenhaForte@2026';

describe('Cadastro e gestão de quadras (/api/courts e /api/owner/courts)', () => {
  let pool: pg.Pool;
  let app: FastifyInstance | null = null;
  let authToken = '';

  beforeAll(async () => {
    pool = createTestPool();
  });

  beforeEach(async () => {
    await resetData(pool);

    const passwordHash = await bcrypt.hash(OWNER_PASSWORD, 4);
    await pool.query('INSERT INTO owners (name, email, password_hash) VALUES ($1, $2, $3)', [
      'Proprietário TennisHub',
      OWNER_EMAIL,
      passwordHash,
    ]);

    app = await buildApp({
      db: pool,
      sessionSecret: TEST_SECRET,
    });
    await app.ready();

    const loginRes = await request(app.server).post('/api/auth/login').send({
      email: OWNER_EMAIL,
      password: OWNER_PASSWORD,
    });
    authToken = loginRes.body.token as string;
  });

  afterEach(async () => {
    if (app) {
      await app.close();
      app = null;
    }
  });

  afterAll(async () => {
    await pool.end();
  });

  it('cadastra quadras com e sem valor por hora (D04) e lista na área pública e do proprietário', async () => {
    const withPriceRes = await request(app!.server)
      .post('/api/owner/courts')
      .set('Authorization', `Bearer ${authToken}`)
      .send({
        name: '  Quadra 1 (Saibro)  ',
        hourlyPriceCents: 8500,
      });

    expect(withPriceRes.status).toBe(201);
    expect(withPriceRes.body).toEqual({
      court: {
        id: 1,
        name: 'Quadra 1 (Saibro)',
        hourlyPriceCents: 8500,
        unavailableFrom: null,
      },
    });

    const withoutPriceRes = await request(app!.server)
      .post('/api/owner/courts')
      .set('Authorization', `Bearer ${authToken}`)
      .send({
        name: 'Quadra 2 (Gratuita)',
      });

    expect(withoutPriceRes.status).toBe(201);
    expect(withoutPriceRes.body).toEqual({
      court: {
        id: 2,
        name: 'Quadra 2 (Gratuita)',
        hourlyPriceCents: null,
        unavailableFrom: null,
      },
    });

    const publicListRes = await request(app!.server).get('/api/courts');
    expect(publicListRes.status).toBe(200);
    expect(publicListRes.body.courts).toHaveLength(2);
    expect(publicListRes.body.courts[0]).toEqual({
      id: 1,
      name: 'Quadra 1 (Saibro)',
      hourlyPriceCents: 8500,
      unavailableFrom: null,
    });
  });

  it('recusa criação com dados inválidos (422)', async () => {
    const shortName = await request(app!.server)
      .post('/api/owner/courts')
      .set('Authorization', `Bearer ${authToken}`)
      .send({ name: 'A', hourlyPriceCents: 5000 });
    expect(shortName.status).toBe(422);
    expect(shortName.body.error.code).toBe('VALIDATION_ERROR');

    const longName = await request(app!.server)
      .post('/api/owner/courts')
      .set('Authorization', `Bearer ${authToken}`)
      .send({ name: 'Q'.repeat(61), hourlyPriceCents: 5000 });
    expect(longName.status).toBe(422);

    const negativePrice = await request(app!.server)
      .post('/api/owner/courts')
      .set('Authorization', `Bearer ${authToken}`)
      .send({ name: 'Quadra Inválida', hourlyPriceCents: -100 });
    expect(negativePrice.status).toBe(422);

    const invalidDate = await request(app!.server)
      .post('/api/owner/courts')
      .set('Authorization', `Bearer ${authToken}`)
      .send({ name: 'Quadra Data Errada', unavailableFrom: '2026-02-30' });
    expect(invalidDate.status).toBe(422);
  });

  it('recusa nome duplicado entre quadras ativas (409) e permite reutilizar após remoção', async () => {
    const created = await request(app!.server)
      .post('/api/owner/courts')
      .set('Authorization', `Bearer ${authToken}`)
      .send({ name: 'Quadra Central', hourlyPriceCents: 9000 });
    expect(created.status).toBe(201);

    const duplicate = await request(app!.server)
      .post('/api/owner/courts')
      .set('Authorization', `Bearer ${authToken}`)
      .send({ name: '  quadra central ', hourlyPriceCents: 7000 });
    expect(duplicate.status).toBe(409);
    expect(duplicate.body.error.code).toBe('COURT_NAME_TAKEN');

    // Remove logicamente a primeira quadra
    const removed = await request(app!.server)
      .delete(`/api/owner/courts/${created.body.court.id}`)
      .set('Authorization', `Bearer ${authToken}`)
      .send({ unavailableFrom: '2026-12-01' });
    expect(removed.status).toBe(200);

    // Agora o mesmo nome volta a ser aceito
    const recreated = await request(app!.server)
      .post('/api/owner/courts')
      .set('Authorization', `Bearer ${authToken}`)
      .send({ name: 'Quadra Central', hourlyPriceCents: 9500 });
    expect(recreated.status).toBe(201);
  });

  it('edita dados da quadra e reflete a mudança na listagem pública', async () => {
    const created = await request(app!.server)
      .post('/api/owner/courts')
      .set('Authorization', `Bearer ${authToken}`)
      .send({ name: 'Quadra Antiga', hourlyPriceCents: 6000 });
    const courtId = created.body.court.id as number;

    const updated = await request(app!.server)
      .put(`/api/owner/courts/${courtId}`)
      .set('Authorization', `Bearer ${authToken}`)
      .send({
        name: 'Quadra Reformada',
        hourlyPriceCents: 11000,
        unavailableFrom: null,
      });

    expect(updated.status).toBe(200);
    expect(updated.body.court).toEqual({
      id: courtId,
      name: 'Quadra Reformada',
      hourlyPriceCents: 11000,
      unavailableFrom: null,
    });

    const publicList = await request(app!.server).get('/api/courts');
    expect(publicList.status).toBe(200);
    expect(publicList.body.courts).toEqual([
      {
        id: courtId,
        name: 'Quadra Reformada',
        hourlyPriceCents: 11000,
        unavailableFrom: null,
      },
    ]);
  });

  it('remove a quadra logicamente quando não há reservas ativas a partir da data informada', async () => {
    const created = await request(app!.server)
      .post('/api/owner/courts')
      .set('Authorization', `Bearer ${authToken}`)
      .send({ name: 'Quadra 3', hourlyPriceCents: 7500 });
    const courtId = created.body.court.id as number;

    // Reserva anterior à data de remoção não impede a remoção
    await insertBooking(pool, {
      courtId,
      startsAt: '2026-01-05T10:00:00-03:00',
      code: 'ABCD2345',
    });

    const removed = await request(app!.server)
      .delete(`/api/owner/courts/${courtId}`)
      .set('Authorization', `Bearer ${authToken}`)
      .send({ unavailableFrom: '2026-01-10' });

    expect(removed.status).toBe(200);
    expect(removed.body.court).toEqual({
      id: courtId,
      name: 'Quadra 3',
      hourlyPriceCents: 7500,
      unavailableFrom: '2026-01-10',
    });

    // Proprietário ainda enxerga a quadra no histórico; listagem pública já oculta (data passada)
    const ownerList = await request(app!.server)
      .get('/api/owner/courts')
      .set('Authorization', `Bearer ${authToken}`);
    expect(ownerList.body.courts).toHaveLength(1);

    const publicList = await request(app!.server).get('/api/courts');
    expect(publicList.body.courts).toHaveLength(0);
  });

  it('bloqueia a remoção se houver reservas ativas na data ou depois dela, informando quantas (D11)', async () => {
    const created = await request(app!.server)
      .post('/api/owner/courts')
      .set('Authorization', `Bearer ${authToken}`)
      .send({ name: 'Quadra Principal', hourlyPriceCents: 10000 });
    const courtId = created.body.court.id as number;

    // 2 reservas confirmadas a partir de 2026-12-10
    await insertBooking(pool, {
      courtId,
      startsAt: '2026-12-10T09:00:00-03:00',
      code: 'BK234567',
    });
    await insertBooking(pool, {
      courtId,
      startsAt: '2026-12-15T18:00:00-03:00',
      code: 'BK678923',
    });

    // 1 reserva cancelada depois da data (não deve contar como ativa)
    await pool.query(
      `INSERT INTO bookings (court_id, starts_at, ends_at, customer_name, customer_phone, code, status, cancelled_at, cancelled_by)
       VALUES ($1, '2026-12-20T10:00:00-03:00'::timestamptz, '2026-12-20T11:00:00-03:00'::timestamptz, 'Carlos Lima', '31988887777', 'CANC2345', 'cancelled', now(), 'customer')`,
      [courtId],
    );

    const blocked = await request(app!.server)
      .delete(`/api/owner/courts/${courtId}`)
      .set('Authorization', `Bearer ${authToken}`)
      .send({ unavailableFrom: '2026-12-10' });

    expect(blocked.status).toBe(409);
    expect(blocked.body.error.code).toBe('COURT_HAS_BOOKINGS');
    expect(blocked.body.error.message).toContain('2 reservas ativas');
    expect(blocked.body.error.details).toEqual({ activeBookings: 2 });
  });

  it('exige autenticação em GET/POST/PUT/DELETE /api/owner/courts (401)', async () => {
    const getRes = await request(app!.server).get('/api/owner/courts');
    const postRes = await request(app!.server)
      .post('/api/owner/courts')
      .send({ name: 'Quadra Teste' });
    const putRes = await request(app!.server)
      .put('/api/owner/courts/1')
      .send({ name: 'Quadra Teste' });
    const deleteRes = await request(app!.server)
      .delete('/api/owner/courts/1')
      .send({ unavailableFrom: '2026-12-10' });

    expect(getRes.status).toBe(401);
    expect(postRes.status).toBe(401);
    expect(putRes.status).toBe(401);
    expect(deleteRes.status).toBe(401);
  });
});
