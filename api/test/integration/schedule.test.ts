import bcrypt from 'bcryptjs';
import type { FastifyInstance } from 'fastify';
import type pg from 'pg';
import request from 'supertest';
import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { buildApp } from '../../src/app.js';
import { CourtsRepository } from '../../src/modules/courts/courts.repository.js';
import { ScheduleRepository } from '../../src/modules/schedule/schedule.repository.js';
import { ScheduleService } from '../../src/modules/schedule/schedule.service.js';
import { createTestPool } from '../helpers/database.js';
import { createCourt, insertBooking, resetData } from '../helpers/fixtures.js';

const TEST_SECRET = 'integration-test-schedule-secret-min-32-chars';
const OWNER_EMAIL = 'proprietario@tennishub.com';
const OWNER_PASSWORD = 'SenhaForte@2026';

describe('Disponibilização de horários das quadras (/api/owner/courts/:id/schedule)', () => {
  let pool: pg.Pool;
  let app: FastifyInstance | null = null;
  let authToken = '';
  let courtId = 0;

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

    courtId = await createCourt(pool, 'Quadra 1');

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

  it('define dias da semana e faixa de horas válida com data de início da vigência', async () => {
    const putRes = await request(app!.server)
      .put(`/api/owner/courts/${courtId}/schedule`)
      .set('Authorization', `Bearer ${authToken}`)
      .send({
        validFrom: '2026-12-01',
        ranges: [
          { weekday: 1, startHour: 8, endHour: 22 },
          { weekday: 6, startHour: 8, endHour: 18 },
        ],
      });

    expect(putRes.status).toBe(200);
    expect(putRes.body).toMatchObject({
      schedule: {
        validFrom: '2026-12-01',
        ranges: [
          { weekday: 1, startHour: 8, endHour: 22 },
          { weekday: 6, startHour: 8, endHour: 18 },
        ],
      },
      affectedBookings: 0,
      bookingsNeedingRelocation: [],
    });

    const getRes = await request(app!.server)
      .get(`/api/owner/courts/${courtId}/schedule`)
      .set('Authorization', `Bearer ${authToken}`);

    expect(getRes.status).toBe(200);
    expect(getRes.body.schedule).toEqual({
      validFrom: '2026-12-01',
      ranges: [
        { weekday: 1, startHour: 8, endHour: 22 },
        { weekday: 6, startHour: 8, endHour: 18 },
      ],
    });
  });

  it('rejeita faixas sobrepostas na mesma quadra (409) e hora final inválida ou fracionada (422)', async () => {
    const overlapRes = await request(app!.server)
      .put(`/api/owner/courts/${courtId}/schedule`)
      .set('Authorization', `Bearer ${authToken}`)
      .send({
        validFrom: '2026-12-01',
        ranges: [
          { weekday: 2, startHour: 8, endHour: 14 },
          { weekday: 2, startHour: 12, endHour: 18 },
        ],
      });

    expect(overlapRes.status).toBe(409);
    expect(overlapRes.body.error.code).toBe('SCHEDULE_OVERLAP');

    const invalidEndHourRes = await request(app!.server)
      .put(`/api/owner/courts/${courtId}/schedule`)
      .set('Authorization', `Bearer ${authToken}`)
      .send({
        validFrom: '2026-12-01',
        ranges: [{ weekday: 2, startHour: 18, endHour: 18 }],
      });

    expect(invalidEndHourRes.status).toBe(422);
    expect(invalidEndHourRes.body.error.code).toBe('VALIDATION_ERROR');

    const nonMultipleHourRes = await request(app!.server)
      .put(`/api/owner/courts/${courtId}/schedule`)
      .set('Authorization', `Bearer ${authToken}`)
      .send({
        validFrom: '2026-12-01',
        ranges: [{ weekday: 2, startHour: 8.5, endHour: 12 }],
      });

    expect(nonMultipleHourRes.status).toBe(422);
  });

  it('aplica vigência futura apenas a partir da data informada, preservando a regra anterior antes dela', async () => {
    // Vigência 1: a partir de 2026-12-01, quarta-feira (3) das 8h às 22h
    await request(app!.server)
      .put(`/api/owner/courts/${courtId}/schedule`)
      .set('Authorization', `Bearer ${authToken}`)
      .send({
        validFrom: '2026-12-01',
        ranges: [{ weekday: 3, startHour: 8, endHour: 22 }],
      });

    // Vigência 2 (futura): a partir de 2026-12-10, quarta-feira (3) das 10h às 16h
    const futureRes = await request(app!.server)
      .put(`/api/owner/courts/${courtId}/schedule`)
      .set('Authorization', `Bearer ${authToken}`)
      .send({
        validFrom: '2026-12-10',
        ranges: [{ weekday: 3, startHour: 10, endHour: 16 }],
      });
    expect(futureRes.status).toBe(200);

    // Em 2026-12-02 (quarta antes da vigência 2), vale a vigência 1 (8h às 22h)
    const beforeRes = await request(app!.server)
      .get(`/api/owner/courts/${courtId}/schedule?date=2026-12-02`)
      .set('Authorization', `Bearer ${authToken}`);
    expect(beforeRes.body.schedule.validFrom).toBe('2026-12-01');
    expect(beforeRes.body.schedule.ranges).toEqual([{ weekday: 3, startHour: 8, endHour: 22 }]);

    // Em 2026-12-16 (quarta após vigência 2), vale a vigência 2 (10h às 16h)
    const afterRes = await request(app!.server)
      .get(`/api/owner/courts/${courtId}/schedule?date=2026-12-16`)
      .set('Authorization', `Bearer ${authToken}`);
    expect(afterRes.body.schedule.validFrom).toBe('2026-12-10');
    expect(afterRes.body.schedule.ranges).toEqual([{ weekday: 3, startHour: 10, endHour: 16 }]);
  });

  it('não apaga reservas existentes fora da nova faixa e as sinaliza para realocação', async () => {
    // Regra inicial: quarta-feira (3) das 8h às 22h a partir de 2026-12-01
    await request(app!.server)
      .put(`/api/owner/courts/${courtId}/schedule`)
      .set('Authorization', `Bearer ${authToken}`)
      .send({
        validFrom: '2026-12-01',
        ranges: [{ weekday: 3, startHour: 8, endHour: 22 }],
      });

    // Reserva dentro da futura faixa (2026-12-16 às 14h SP)
    await insertBooking(pool, {
      courtId,
      startsAt: '2026-12-16T14:00:00-03:00',
      code: 'KEEP2345',
    });

    // Reserva que ficará fora da futura faixa (2026-12-16 às 20h SP)
    await insertBooking(pool, {
      courtId,
      startsAt: '2026-12-16T20:00:00-03:00',
      code: 'MV234567',
    });

    // Reduz horário a partir de 2026-12-10 para 8h às 18h
    const updateRes = await request(app!.server)
      .put(`/api/owner/courts/${courtId}/schedule`)
      .set('Authorization', `Bearer ${authToken}`)
      .send({
        validFrom: '2026-12-10',
        ranges: [{ weekday: 3, startHour: 8, endHour: 18 }],
      });

    expect(updateRes.status).toBe(200);
    expect(updateRes.body.affectedBookings).toBe(1);
    expect(updateRes.body.bookingsNeedingRelocation).toHaveLength(1);
    expect(updateRes.body.bookingsNeedingRelocation[0]).toMatchObject({
      code: 'MV234567',
      needsRelocation: true,
    });

    // Confirma no banco que nenhuma reserva foi apagada e apenas MOVE2345 está sinalizada
    const { rows } = await pool.query<{ code: string; status: string; needs_relocation: boolean }>(
      'SELECT code, status, needs_relocation FROM bookings ORDER BY code ASC',
    );
    expect(rows).toEqual([
      { code: 'KEEP2345', status: 'confirmed', needs_relocation: false },
      { code: 'MV234567', status: 'confirmed', needs_relocation: true },
    ]);
  });

  it('permite bloquear dia ou horário específico sem apagar a regra e reflete nos slots de 1 hora', async () => {
    // Quarta-feira (3) das 8h às 12h (4 slots: 8h, 9h, 10h, 11h)
    await request(app!.server)
      .put(`/api/owner/courts/${courtId}/schedule`)
      .set('Authorization', `Bearer ${authToken}`)
      .send({
        validFrom: '2026-12-01',
        ranges: [{ weekday: 3, startHour: 8, endHour: 12 }],
      });

    // Reserva confirmada às 8h SP em 2026-12-02
    await insertBooking(pool, {
      courtId,
      startsAt: '2026-12-02T08:00:00-03:00',
      code: 'SL234567',
    });

    // Bloqueio pontual de manutenção das 10h às 11h SP em 2026-12-02
    const blockRes = await request(app!.server)
      .post(`/api/owner/courts/${courtId}/blocks`)
      .set('Authorization', `Bearer ${authToken}`)
      .send({
        startsAt: '2026-12-02T10:00:00-03:00',
        endsAt: '2026-12-02T11:00:00-03:00',
        reason: 'Manutenção na rede',
      });

    expect(blockRes.status).toBe(201);
    const blockId = blockRes.body.block.id as number;

    const scheduleService = new ScheduleService(
      pool,
      new ScheduleRepository(pool),
      new CourtsRepository(pool),
    );

    const slots = await scheduleService.getCourtDaySlots(courtId, '2026-12-02', {
      now: new Date('2026-12-01T12:00:00Z'),
    });

    expect(slots).toEqual([
      {
        courtId,
        date: '2026-12-02',
        hour: 8,
        startsAt: '2026-12-02T11:00:00.000Z',
        endsAt: '2026-12-02T12:00:00.000Z',
        status: 'busy',
      },
      {
        courtId,
        date: '2026-12-02',
        hour: 9,
        startsAt: '2026-12-02T12:00:00.000Z',
        endsAt: '2026-12-02T13:00:00.000Z',
        status: 'free',
      },
      {
        courtId,
        date: '2026-12-02',
        hour: 10,
        startsAt: '2026-12-02T13:00:00.000Z',
        endsAt: '2026-12-02T14:00:00.000Z',
        status: 'closed',
      },
      {
        courtId,
        date: '2026-12-02',
        hour: 11,
        startsAt: '2026-12-02T14:00:00.000Z',
        endsAt: '2026-12-02T15:00:00.000Z',
        status: 'free',
      },
    ]);

    // Remove o bloqueio e confirma que a regra semanal continua intacta e o horário de 10h volta a ficar livre
    const deleteBlockRes = await request(app!.server)
      .delete(`/api/owner/blocks/${blockId}`)
      .set('Authorization', `Bearer ${authToken}`);
    expect(deleteBlockRes.status).toBe(204);

    const slotsAfterUnblock = await scheduleService.getAvailableCourtDaySlots(
      courtId,
      '2026-12-02',
      { now: new Date('2026-12-01T12:00:00Z') },
    );
    expect(slotsAfterUnblock.map((s) => s.hour)).toEqual([9, 10, 11]);
  });

  it('exige autenticação em GET e PUT /api/owner/courts/:id/schedule e nos bloqueios (401)', async () => {
    const getSchedule = await request(app!.server).get(`/api/owner/courts/${courtId}/schedule`);
    const putSchedule = await request(app!.server)
      .put(`/api/owner/courts/${courtId}/schedule`)
      .send({
        validFrom: '2026-12-01',
        ranges: [{ weekday: 1, startHour: 8, endHour: 18 }],
      });
    const postBlock = await request(app!.server).post(`/api/owner/courts/${courtId}/blocks`).send({
      startsAt: '2026-12-02T10:00:00-03:00',
      endsAt: '2026-12-02T11:00:00-03:00',
      reason: 'Manutenção',
    });

    expect(getSchedule.status).toBe(401);
    expect(putSchedule.status).toBe(401);
    expect(postBlock.status).toBe(401);
  });
});
