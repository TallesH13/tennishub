import type { FastifyInstance } from 'fastify';
import type pg from 'pg';
import request from 'supertest';
import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { buildApp } from '../../src/app.js';
import { AvailabilityService } from '../../src/modules/availability/availability.service.js';
import { BookingsService } from '../../src/modules/bookings/bookings.service.js';
import { CourtsRepository } from '../../src/modules/courts/courts.repository.js';
import { ScheduleRepository } from '../../src/modules/schedule/schedule.repository.js';
import { ScheduleService } from '../../src/modules/schedule/schedule.service.js';
import { createTestPool } from '../helpers/database.js';
import { insertBooking, resetData } from '../helpers/fixtures.js';

// Quinta-feira, 10/01/2030, 12:30 em São Paulo.
const NOW = Date.parse('2030-01-10T12:30:00-03:00');

async function insertCourt(
  pool: pg.Pool,
  name: string,
  options: { unavailableFrom?: string; openFrom?: number; openUntil?: number } = {},
): Promise<number> {
  const { rows } = await pool.query<{ id: string }>(
    'INSERT INTO courts (name, unavailable_from) VALUES ($1, $2) RETURNING id',
    [name, options.unavailableFrom ?? null],
  );
  const id = Number(rows[0]!.id);
  await pool.query(
    `INSERT INTO availability_rules (court_id, weekday, start_hour, end_hour, valid_from)
     SELECT $1, weekday, $2, $3, '2030-01-01' FROM generate_series(0, 6) AS weekday`,
    [id, options.openFrom ?? 8, options.openUntil ?? 22],
  );
  return id;
}

function bookingServiceFor(pool: pg.Pool, generateCode?: () => string): BookingsService {
  const now = () => NOW;
  const courtsRepository = new CourtsRepository(pool);
  const scheduleService = new ScheduleService(
    pool,
    new ScheduleRepository(pool),
    courtsRepository,
    now,
  );
  const availabilityService = new AvailabilityService(courtsRepository, scheduleService, now);
  return new BookingsService(pool, courtsRepository, availabilityService, now, generateCode);
}

describe('Criação de reserva pelo cliente (POST /api/bookings, #14)', () => {
  let pool: pg.Pool;
  let app: FastifyInstance | null = null;
  let courtId = 0;

  const validBody = () => ({
    courtId,
    startsAt: '2030-01-10T19:00:00-03:00',
    customerName: 'Ana Paula Ribeiro',
    customerPhone: '(31) 98765-4321',
  });

  const countBookings = async () =>
    Number((await pool.query<{ n: string }>('SELECT count(*) AS n FROM bookings')).rows[0]!.n);

  beforeAll(() => {
    pool = createTestPool();
  });

  beforeEach(async () => {
    await resetData(pool);
    courtId = await insertCourt(pool, 'Quadra 1');
    await pool.query(
      `INSERT INTO schedule_blocks (court_id, starts_at, ends_at, reason)
       VALUES ($1, '2030-01-10 20:00-03', '2030-01-10 21:00-03', 'manutenção')`,
      [courtId],
    );
    app = await buildApp({ db: pool, sessionSecret: 'x'.repeat(32), now: () => NOW });
    await app.ready();
  });

  afterEach(async () => {
    await app?.close();
    app = null;
  });

  afterAll(async () => {
    await pool.end();
  });

  it('cria a reserva de 1 hora e devolve a confirmação com o código', async () => {
    const response = await request(app!.server).post('/api/bookings').send(validBody());

    expect(response.status).toBe(201);
    const booking = response.body.booking;
    expect(booking).toMatchObject({
      courtId,
      courtName: 'Quadra 1',
      startsAt: '2030-01-10T22:00:00.000Z',
      endsAt: '2030-01-10T23:00:00.000Z',
      customerName: 'Ana Paula Ribeiro',
      customerPhone: '31987654321',
      status: 'confirmed',
      needsRelocation: false,
      relocationReason: null,
      cancelledBy: null,
      cancellationReason: null,
    });
    expect(booking.code).toMatch(/^[A-HJ-NP-Z2-9]{8}$/);
    expect(typeof booking.id).toBe('number');
    expect(Number.isNaN(Date.parse(booking.createdAt))).toBe(false);

    const { rows } = await pool.query('SELECT customer_phone, code FROM bookings');
    expect(rows).toEqual([{ customer_phone: '31987654321', code: booking.code }]);
  });

  it('depois de reservado, o horário aparece ocupado na consulta pública, sem o código', async () => {
    const created = await request(app!.server).post('/api/bookings').send(validBody());
    const availability = await request(app!.server).get('/api/availability?date=2030-01-10');

    const slot = availability.body.courts[0].slots.find(
      (s: { startsAt: string }) => s.startsAt === '2030-01-10T22:00:00.000Z',
    );
    expect(slot.status).toBe('busy');
    expect(JSON.stringify(availability.body)).not.toContain(created.body.booking.code);
  });

  it('horário já reservado devolve 409 SLOT_UNAVAILABLE e não cria nada', async () => {
    await request(app!.server).post('/api/bookings').send(validBody());

    const second = await request(app!.server)
      .post('/api/bookings')
      .send({ ...validBody(), customerName: 'Bruno Lima', customerPhone: '31912345678' });

    expect(second.status).toBe(409);
    expect(second.body.error.code).toBe('SLOT_UNAVAILABLE');
    expect(await countBookings()).toBe(1);
  });

  it('com 10 pedidos simultâneos para o mesmo horário, só 1 é aceito', async () => {
    const responses = await Promise.all(
      Array.from({ length: 10 }, (_, i) =>
        request(app!.server)
          .post('/api/bookings')
          .send({ ...validBody(), customerPhone: `3198765${String(i).padStart(4, '0')}` }),
      ),
    );

    expect(responses.filter((r) => r.status === 201)).toHaveLength(1);
    const rejected = responses.filter((r) => r.status === 409);
    expect(rejected).toHaveLength(9);
    for (const r of rejected) expect(r.body.error.code).toBe('SLOT_UNAVAILABLE');
    expect(await countBookings()).toBe(1);
  });

  it('horário de uma reserva cancelada pode ser reservado de novo', async () => {
    await insertBooking(pool, { courtId, startsAt: '2030-01-10 19:00-03', code: 'ABCDEFGH' });
    await pool.query(
      `UPDATE bookings SET status = 'cancelled', cancelled_at = now(), cancelled_by = 'customer'`,
    );

    const response = await request(app!.server).post('/api/bookings').send(validBody());
    expect(response.status).toBe(201);
  });

  it.each([
    ['horário passado', '2030-01-10T10:00:00-03:00', 'já passou'],
    ['além de 30 dias', '2030-02-15T19:00:00-03:00', '30 dias'],
    ['fora do funcionamento', '2030-01-11T06:00:00-03:00', 'não está disponível'],
    ['bloqueado', '2030-01-10T20:00:00-03:00', 'não está disponível'],
  ])('recusa %s com 409', async (_, startsAt, message) => {
    const response = await request(app!.server)
      .post('/api/bookings')
      .send({ ...validBody(), startsAt });

    expect(response.status).toBe(409);
    expect(response.body.error.code).toBe('SLOT_UNAVAILABLE');
    expect(response.body.error.message).toContain(message);
    expect(await countBookings()).toBe(0);
  });

  it('recusa quadra removida (409) e quadra inexistente (404)', async () => {
    const removed = await insertCourt(pool, 'Quadra Antiga', { unavailableFrom: '2030-01-05' });

    const onRemoved = await request(app!.server)
      .post('/api/bookings')
      .send({ ...validBody(), courtId: removed });
    const onMissing = await request(app!.server)
      .post('/api/bookings')
      .send({ ...validBody(), courtId: 999999 });

    expect(onRemoved.status).toBe(409);
    expect(onMissing.status).toBe(404);
    expect(await countBookings()).toBe(0);
  });

  it.each([
    ['telefone inválido', { customerPhone: '12345' }, 'customerPhone'],
    ['nome incompleto', { customerName: 'Ana' }, 'customerName'],
    ['horário quebrado', { startsAt: '2030-01-10T19:30:00-03:00' }, 'startsAt'],
  ])('%s devolve 422 com o erro no campo', async (_, change, field) => {
    const response = await request(app!.server)
      .post('/api/bookings')
      .send({ ...validBody(), ...change });

    expect(response.status).toBe(422);
    expect(response.body.error.code).toBe('VALIDATION_ERROR');
    expect(response.body.error.details.map((d: { field: string }) => d.field)).toEqual([field]);
    expect(await countBookings()).toBe(0);
  });

  it('se o código sorteado já existe, sorteia outro', async () => {
    await insertBooking(pool, { courtId, startsAt: '2030-01-11 09:00-03', code: 'ABCDEFGH' });
    const codes = ['ABCDEFGH', 'ABCDEFGH', 'JKLMNPQR'];
    const service = bookingServiceFor(pool, () => codes.shift()!);

    const booking = await service.createBooking({
      courtId,
      startsAt: '2030-01-10T19:00:00-03:00',
      customerName: 'Ana Paula Ribeiro',
      customerPhone: '31987654321',
    });

    expect(booking.code).toBe('JKLMNPQR');
  });

  it('gera códigos únicos em 1.000 reservas', { timeout: 120_000 }, async () => {
    const courts: number[] = [];
    for (let i = 2; i <= 9; i++)
      courts.push(await insertCourt(pool, `Quadra ${i}`, { openFrom: 0, openUntil: 24 }));
    const service = bookingServiceFor(pool);

    const codes: string[] = [];
    let n = 0;
    for (const day of ['11', '12', '13', '14', '15', '16']) {
      for (let hour = 0; hour < 24 && n < 1000; hour++) {
        for (const id of courts) {
          if (n >= 1000) break;
          const booking = await service.createBooking({
            courtId: id,
            startsAt: `2030-01-${day}T${String(hour).padStart(2, '0')}:00:00-03:00`,
            customerName: 'Cliente Teste',
            customerPhone: `3190${String(n).padStart(7, '0')}`,
          });
          codes.push(booking.code);
          n++;
        }
      }
    }

    expect(codes).toHaveLength(1000);
    expect(new Set(codes).size).toBe(1000);
  });
});
