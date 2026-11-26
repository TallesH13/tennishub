import type { FastifyInstance } from 'fastify';
import type pg from 'pg';
import request from 'supertest';
import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { buildApp } from '../../src/app.js';
import { createTestPool } from '../helpers/database.js';
import { resetData } from '../helpers/fixtures.js';

// Quinta-feira, 10/01/2030, 12:30 em São Paulo.
const NOW = Date.parse('2030-01-10T12:30:00-03:00');

describe('Limite de 2 reservas por telefone por dia (RF03, #15)', () => {
  let pool: pg.Pool;
  let app: FastifyInstance | null = null;
  let courtId = 0;

  const book = (startsAt: string, customerPhone = '31999990000') =>
    request(app!.server).post('/api/bookings').send({
      courtId,
      startsAt,
      customerName: 'Ana Paula Ribeiro',
      customerPhone,
    });

  const confirmedCount = async () =>
    Number(
      (
        await pool.query<{ n: string }>(
          `SELECT count(*) AS n FROM bookings WHERE status = 'confirmed'`,
        )
      ).rows[0]!.n,
    );

  beforeAll(() => {
    pool = createTestPool();
  });

  beforeEach(async () => {
    await resetData(pool);
    const { rows } = await pool.query<{ id: string }>(
      `INSERT INTO courts (name) VALUES ('Quadra 1') RETURNING id`,
    );
    courtId = Number(rows[0]!.id);
    await pool.query(
      `INSERT INTO availability_rules (court_id, weekday, start_hour, end_hour, valid_from)
       SELECT $1, weekday, 0, 24, '2030-01-01' FROM generate_series(0, 6) AS weekday`,
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

  it('aceita a 1ª e a 2ª reserva do dia e recusa a 3ª com DAILY_LIMIT_REACHED', async () => {
    expect((await book('2030-01-11T08:00:00-03:00')).status).toBe(201);
    expect((await book('2030-01-11T09:00:00-03:00')).status).toBe(201);

    const third = await book('2030-01-11T10:00:00-03:00');

    expect(third.status).toBe(409);
    expect(third.body.error.code).toBe('DAILY_LIMIT_REACHED');
    expect(third.body.error.message).toContain('escolha outra data');
    expect(await confirmedCount()).toBe(2);
  });

  it('trata telefones escritos de formas diferentes como o mesmo cliente (D07)', async () => {
    expect((await book('2030-01-11T08:00:00-03:00', '(31) 99999-0000')).status).toBe(201);
    expect((await book('2030-01-11T09:00:00-03:00', '31999990000')).status).toBe(201);

    const third = await book('2030-01-11T10:00:00-03:00', '31 99999 0000');

    expect(third.status).toBe(409);
    expect(third.body.error.code).toBe('DAILY_LIMIT_REACHED');
  });

  it('reserva cancelada libera a vaga do dia (D01)', async () => {
    await book('2030-01-11T08:00:00-03:00');
    await book('2030-01-11T09:00:00-03:00');
    await pool.query(
      `UPDATE bookings SET status = 'cancelled', cancelled_at = now(), cancelled_by = 'customer'
       WHERE starts_at = '2030-01-11 08:00-03'`,
    );

    expect((await book('2030-01-11T10:00:00-03:00')).status).toBe(201);
  });

  it('o limite é por dia: outro dia aceita novas reservas', async () => {
    await book('2030-01-11T08:00:00-03:00');
    await book('2030-01-11T09:00:00-03:00');

    expect((await book('2030-01-12T08:00:00-03:00')).status).toBe(201);
  });

  it('o limite é por telefone: outro telefone reserva no mesmo dia', async () => {
    await book('2030-01-11T08:00:00-03:00');
    await book('2030-01-11T09:00:00-03:00');

    expect((await book('2030-01-11T10:00:00-03:00', '31912345678')).status).toBe(201);
  });

  it('conta o dia do jogo no fuso de São Paulo: 23h e 0h caem em dias diferentes', async () => {
    expect((await book('2030-01-11T22:00:00-03:00')).status).toBe(201);
    expect((await book('2030-01-11T23:00:00-03:00')).status).toBe(201);

    // 0h do dia 12 em São Paulo é 03h UTC do dia 12; 21h do dia 11 é 00h UTC do dia 12.
    expect((await book('2030-01-12T00:00:00-03:00')).status).toBe(201);
    const sameDay = await book('2030-01-11T21:00:00-03:00');
    expect(sameDay.status).toBe(409);
    expect(sameDay.body.error.code).toBe('DAILY_LIMIT_REACHED');
  });

  it('com 5 pedidos simultâneos do mesmo telefone, no máximo 2 são criados', async () => {
    const responses = await Promise.all(
      [8, 9, 10, 11, 12].map((hour) =>
        book(`2030-01-11T${String(hour).padStart(2, '0')}:00:00-03:00`),
      ),
    );

    expect(responses.filter((r) => r.status === 201)).toHaveLength(2);
    const refused = responses.filter((r) => r.status === 409);
    expect(refused).toHaveLength(3);
    for (const r of refused) expect(r.body.error.code).toBe('DAILY_LIMIT_REACHED');
    expect(await confirmedCount()).toBe(2);
  });
});
