import type { FastifyInstance } from 'fastify';
import type pg from 'pg';
import request from 'supertest';
import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { buildApp } from '../../src/app.js';
import { createTestPool } from '../helpers/database.js';
import { resetData } from '../helpers/fixtures.js';

// Quinta-feira, 10/01/2030, 12:30 em São Paulo.
const NOW = Date.parse('2030-01-10T12:30:00-03:00');
const PHONE = '31999990000';
const MASKED_PHONE = '(31) 99999-0000';

type Booking = {
  id: number;
  code: string;
  courtId: number;
  startsAt: string;
  status: string;
  cancelledBy: string | null;
  needsRelocation: boolean;
};

describe('Consultar, cancelar e remarcar pelo cliente (#17)', () => {
  let pool: pg.Pool;
  let app: FastifyInstance | null = null;
  let court1 = 0;
  let court2 = 0;

  async function insertCourt(name: string): Promise<number> {
    const { rows } = await pool.query<{ id: string }>(
      'INSERT INTO courts (name) VALUES ($1) RETURNING id',
      [name],
    );
    const id = Number(rows[0]!.id);
    await pool.query(
      `INSERT INTO availability_rules (court_id, weekday, start_hour, end_hour, valid_from)
       SELECT $1, weekday, 8, 22, '2030-01-01' FROM generate_series(0, 6) AS weekday`,
      [id],
    );
    return id;
  }

  async function startApp(options: { cancellationDeadlineHours?: number } = {}) {
    await app?.close();
    app = await buildApp({ db: pool, sessionSecret: 'x'.repeat(32), now: () => NOW, ...options });
    await app.ready();
  }

  async function create(startsAt: string, courtId = court1, phone = PHONE): Promise<Booking> {
    const response = await request(app!.server).post('/api/bookings').send({
      courtId,
      startsAt,
      customerName: 'Ana Paula Ribeiro',
      customerPhone: phone,
    });
    expect(response.status).toBe(201);
    return response.body.booking as Booking;
  }

  const post = (path: string, body: object) => request(app!.server).post(path).send(body);

  const slotStatus = async (courtId: number, date: string, startsAt: string) => {
    const response = await request(app!.server).get(`/api/courts/${courtId}/slots?date=${date}`);
    return (response.body.slots as { startsAt: string; status: string }[]).find(
      (slot) => slot.startsAt === new Date(startsAt).toISOString(),
    )?.status;
  };

  const storedBooking = async (id: number) =>
    (
      await pool.query<{ court_id: string; starts_at: Date; status: string }>(
        'SELECT court_id, starts_at, status FROM bookings WHERE id = $1',
        [id],
      )
    ).rows[0]!;

  beforeAll(() => {
    pool = createTestPool();
  });

  beforeEach(async () => {
    await resetData(pool);
    court1 = await insertCourt('Quadra 1');
    court2 = await insertCourt('Quadra 2');
    await startApp();
  });

  afterEach(async () => {
    await app?.close();
    app = null;
  });

  afterAll(async () => {
    await pool.end();
  });

  describe('consulta por código', () => {
    it('acha a reserva com o código e o telefone, aceitando máscara e letras minúsculas', async () => {
      const booking = await create('2030-01-11T19:00:00-03:00');

      const response = await post('/api/bookings/lookup', {
        code: booking.code.toLowerCase(),
        phone: MASKED_PHONE,
      });

      expect(response.status).toBe(200);
      expect(response.body.booking).toMatchObject({ id: booking.id, code: booking.code });
    });

    it('código errado e telefone errado devolvem exatamente a mesma resposta genérica', async () => {
      const booking = await create('2030-01-11T19:00:00-03:00');

      const wrongCode = await post('/api/bookings/lookup', { code: 'ZZZZZZZZ', phone: PHONE });
      const wrongPhone = await post('/api/bookings/lookup', {
        code: booking.code,
        phone: '31988887777',
      });

      expect(wrongCode.status).toBe(404);
      expect(wrongPhone.status).toBe(404);
      expect(wrongCode.body).toEqual(wrongPhone.body);
      expect(wrongCode.body.error.message).toBe(
        'Reserva não encontrada. Confira o código e o telefone.',
      );
    });

    it('exige código e telefone (422)', async () => {
      const response = await post('/api/bookings/lookup', { code: 'ABCDEFGH' });
      expect(response.status).toBe(422);
      expect(response.body.error.details.map((d: { field: string }) => d.field)).toEqual(['phone']);
    });

    it('depois de 10 falhas em 15 minutos responde 429, mesmo com os dados certos', async () => {
      const booking = await create('2030-01-11T19:00:00-03:00');
      for (let i = 0; i < 10; i++) {
        const miss = await post('/api/bookings/lookup', { code: 'ZZZZZZZZ', phone: PHONE });
        expect(miss.status).toBe(404);
      }

      const blocked = await post('/api/bookings/lookup', { code: booking.code, phone: PHONE });

      expect(blocked.status).toBe(429);
      expect(blocked.body.error.code).toBe('TOO_MANY_ATTEMPTS');
    });
  });

  describe('cancelamento', () => {
    it('cancela dentro do prazo e o horário volta a ficar disponível', async () => {
      const booking = await create('2030-01-11T19:00:00-03:00');
      expect(await slotStatus(court1, '2030-01-11', booking.startsAt)).toBe('busy');

      const response = await post('/api/bookings/cancel', { code: booking.code, phone: PHONE });

      expect(response.status).toBe(200);
      expect(response.body.booking).toMatchObject({
        code: booking.code,
        status: 'cancelled',
        cancelledBy: 'customer',
      });
      expect(await slotStatus(court1, '2030-01-11', booking.startsAt)).toBe('free');
    });

    it('recusa cancelar duas vezes', async () => {
      const booking = await create('2030-01-11T19:00:00-03:00');
      await post('/api/bookings/cancel', { code: booking.code, phone: PHONE });

      const again = await post('/api/bookings/cancel', { code: booking.code, phone: PHONE });

      expect(again.status).toBe(409);
      expect(again.body.error.code).toBe('BOOKING_ALREADY_CANCELLED');
    });

    it('recusa cancelar com menos de 2 horas de antecedência, com mensagem clara (D02)', async () => {
      const soon = await create('2030-01-10T14:00:00-03:00');
      const inTime = await create('2030-01-10T15:00:00-03:00');

      const late = await post('/api/bookings/cancel', { code: soon.code, phone: PHONE });
      expect(late.status).toBe(409);
      expect(late.body.error.code).toBe('CHANGE_DEADLINE_PASSED');
      expect(late.body.error.message).toContain('até 2 horas antes do início');
      expect((await storedBooking(soon.id)).status).toBe('confirmed');

      const ok = await post('/api/bookings/cancel', { code: inTime.code, phone: PHONE });
      expect(ok.status).toBe(200);
    });

    it('o prazo é configurável (D02)', async () => {
      const soon = await create('2030-01-10T14:00:00-03:00');
      await startApp({ cancellationDeadlineHours: 1 });

      const response = await post('/api/bookings/cancel', { code: soon.code, phone: PHONE });
      expect(response.status).toBe(200);
    });

    it('código ou telefone errados não cancelam nada', async () => {
      const booking = await create('2030-01-11T19:00:00-03:00');

      const response = await post('/api/bookings/cancel', {
        code: booking.code,
        phone: '31988887777',
      });

      expect(response.status).toBe(404);
      expect((await storedBooking(booking.id)).status).toBe('confirmed');
    });
  });

  describe('remarcação', () => {
    it('move para outra quadra e dia livres mantendo o código, e libera o horário antigo', async () => {
      const booking = await create('2030-01-11T19:00:00-03:00');

      const response = await post('/api/bookings/reschedule', {
        code: booking.code,
        phone: MASKED_PHONE,
        courtId: court2,
        startsAt: '2030-01-12T10:00:00-03:00',
      });

      expect(response.status).toBe(200);
      expect(response.body.booking).toMatchObject({
        id: booking.id,
        code: booking.code,
        courtId: court2,
        courtName: 'Quadra 2',
        startsAt: '2030-01-12T13:00:00.000Z',
        endsAt: '2030-01-12T14:00:00.000Z',
        status: 'confirmed',
      });
      expect(await slotStatus(court1, '2030-01-11', booking.startsAt)).toBe('free');
      expect(await slotStatus(court2, '2030-01-12', '2030-01-12T10:00:00-03:00')).toBe('busy');
    });

    it('para um horário ocupado devolve 409 e a reserva antiga continua valendo (D10)', async () => {
      const mine = await create('2030-01-11T19:00:00-03:00');
      await create('2030-01-12T10:00:00-03:00', court1, '31912345678');

      const response = await post('/api/bookings/reschedule', {
        code: mine.code,
        phone: PHONE,
        courtId: court1,
        startsAt: '2030-01-12T10:00:00-03:00',
      });

      expect(response.status).toBe(409);
      expect(response.body.error.code).toBe('SLOT_UNAVAILABLE');
      const stored = await storedBooking(mine.id);
      expect(stored.status).toBe('confirmed');
      expect(stored.starts_at.toISOString()).toBe(mine.startsAt);
    });

    it('respeita o limite de 2 por dia na data de destino', async () => {
      const mine = await create('2030-01-11T19:00:00-03:00');
      await create('2030-01-12T08:00:00-03:00');
      await create('2030-01-12T09:00:00-03:00');

      const response = await post('/api/bookings/reschedule', {
        code: mine.code,
        phone: PHONE,
        courtId: court1,
        startsAt: '2030-01-12T10:00:00-03:00',
      });

      expect(response.status).toBe(409);
      expect(response.body.error.code).toBe('DAILY_LIMIT_REACHED');
      expect((await storedBooking(mine.id)).starts_at.toISOString()).toBe(mine.startsAt);
    });

    it('remarcar dentro do mesmo dia não conta a própria reserva no limite', async () => {
      await create('2030-01-12T08:00:00-03:00');
      const mine = await create('2030-01-12T09:00:00-03:00');

      const response = await post('/api/bookings/reschedule', {
        code: mine.code,
        phone: PHONE,
        courtId: court1,
        startsAt: '2030-01-12T17:00:00-03:00',
      });

      expect(response.status).toBe(200);
    });

    it('respeita a regra de 1 hora em hora cheia (422) e recusa o mesmo horário (409)', async () => {
      const mine = await create('2030-01-11T19:00:00-03:00');

      const broken = await post('/api/bookings/reschedule', {
        code: mine.code,
        phone: PHONE,
        courtId: court1,
        startsAt: '2030-01-12T10:30:00-03:00',
      });
      const same = await post('/api/bookings/reschedule', {
        code: mine.code,
        phone: PHONE,
        courtId: court1,
        startsAt: '2030-01-11T19:00:00-03:00',
      });

      expect(broken.status).toBe(422);
      expect(same.status).toBe(409);
      expect(same.body.error.code).toBe('BOOKING_SAME_SLOT');
    });

    it('recusa remarcar com menos de 2 horas de antecedência', async () => {
      const soon = await create('2030-01-10T14:00:00-03:00');

      const response = await post('/api/bookings/reschedule', {
        code: soon.code,
        phone: PHONE,
        courtId: court1,
        startsAt: '2030-01-11T10:00:00-03:00',
      });

      expect(response.status).toBe(409);
      expect(response.body.error.code).toBe('CHANGE_DEADLINE_PASSED');
    });

    it('duas remarcações simultâneas para o mesmo horário: só uma ocupa o horário (#16)', async () => {
      const a = await create('2030-01-11T19:00:00-03:00', court1, '31911111111');
      const b = await create('2030-01-11T20:00:00-03:00', court1, '31922222222');

      const responses = await Promise.all([
        post('/api/bookings/reschedule', {
          code: a.code,
          phone: '31911111111',
          courtId: court2,
          startsAt: '2030-01-13T10:00:00-03:00',
        }),
        post('/api/bookings/reschedule', {
          code: b.code,
          phone: '31922222222',
          courtId: court2,
          startsAt: '2030-01-13T10:00:00-03:00',
        }),
      ]);

      expect(responses.map((r) => r.status).sort()).toEqual([200, 409]);
      const { rows } = await pool.query(
        `SELECT 1 FROM bookings WHERE court_id = $1 AND starts_at = '2030-01-13 10:00-03'
           AND status = 'confirmed'`,
        [court2],
      );
      expect(rows).toHaveLength(1);
    });
  });
});
