import type { FastifyInstance } from 'fastify';
import type pg from 'pg';
import request from 'supertest';
import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { buildApp } from '../../src/app.js';
import { withTransaction } from '../../src/db/pool.js';
import { BookingsRepository } from '../../src/modules/bookings/bookings.repository.js';
import { claimSlotInTransaction } from '../../src/modules/bookings/slot-guard.js';
import { CourtsRepository } from '../../src/modules/courts/courts.repository.js';
import { mapDatabaseError } from '../../src/shared/errors.js';
import { createTestPool } from '../helpers/database.js';
import { resetData } from '../helpers/fixtures.js';

// Quinta-feira, 10/01/2030, 12:30 em São Paulo.
const NOW = Date.parse('2030-01-10T12:30:00-03:00');
const SLOT = '2030-01-11T19:00:00-03:00';

describe('Concorrência na reserva do mesmo horário (RNF01, #16)', () => {
  let pool: pg.Pool;
  let app: FastifyInstance | null = null;
  let courtId = 0;

  const book = (customerPhone: string) =>
    request(app!.server).post('/api/bookings').send({
      courtId,
      startsAt: SLOT,
      customerName: 'Cliente Concorrente',
      customerPhone,
    });

  const confirmedOnSlot = async () =>
    Number(
      (
        await pool.query<{ n: string }>(
          `SELECT count(*) AS n FROM bookings
           WHERE court_id = $1 AND starts_at = $2 AND status = 'confirmed'`,
          [courtId, SLOT],
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
       SELECT $1, weekday, 8, 22, '2030-01-01' FROM generate_series(0, 6) AS weekday`,
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

  it('com 25 pedidos simultâneos, exatamente 1 recebe 201 e os outros 409, sem nenhum 500', async () => {
    const responses = await Promise.all(
      Array.from({ length: 25 }, (_, i) => book(`3198${String(i).padStart(7, '0')}`)),
    );

    const statuses = responses.map((r) => r.status);
    expect(statuses.filter((s) => s === 201)).toHaveLength(1);
    expect(statuses.filter((s) => s === 409)).toHaveLength(24);
    for (const r of responses.filter((r) => r.status === 409)) {
      expect(r.body.error.code).toBe('SLOT_UNAVAILABLE');
    }
    expect(await confirmedOnSlot()).toBe(1);
  });

  it('cancelar libera o horário e uma nova reserva consegue ocupá-lo', async () => {
    expect((await book('31911111111')).status).toBe(201);
    expect((await book('31922222222')).status).toBe(409);

    await pool.query(
      `UPDATE bookings SET status = 'cancelled', cancelled_at = now(), cancelled_by = 'customer'`,
    );

    expect((await book('31922222222')).status).toBe(201);
    expect(await confirmedOnSlot()).toBe(1);
  });

  it('se duas gravações passarem pela verificação, o índice do banco barra a segunda como SLOT_UNAVAILABLE', async () => {
    const insert = (code: string, phone: string) =>
      withTransaction(pool, (client) =>
        new BookingsRepository(client).insert({
          courtId,
          startsAt: new Date(SLOT).toISOString(),
          customerName: 'Cliente Concorrente',
          customerPhone: phone,
          code,
        }),
      );

    await insert('ABCDEFGH', '31911111111');
    const error = await insert('JKLMNPQR', '31922222222').catch((e: unknown) => e);

    expect(error).toMatchObject({ code: '23505', constraint: 'bookings_court_slot_confirmed_key' });
    expect(mapDatabaseError(error)).toMatchObject({ statusCode: 409, code: 'SLOT_UNAVAILABLE' });
  });

  it('claimSlotInTransaction, usada por todas as rotas que ocupam horário, recusa horário ocupado', async () => {
    expect((await book('31911111111')).status).toBe(201);
    const courtsRepository = new CourtsRepository(pool);
    const court = (await courtsRepository.findById(courtId))!;

    const attempt = withTransaction(pool, (client) =>
      claimSlotInTransaction(
        client,
        { pool, courtsRepository, now: () => NOW },
        court,
        new Date(SLOT),
        '2030-01-11',
      ),
    );

    await expect(attempt).rejects.toMatchObject({ statusCode: 409, code: 'SLOT_UNAVAILABLE' });
  });
});
