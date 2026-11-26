import type { FastifyInstance } from 'fastify';
import type pg from 'pg';
import request from 'supertest';
import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { buildApp } from '../../src/app.js';
import { createTestPool } from '../helpers/database.js';
import { insertBooking, resetData } from '../helpers/fixtures.js';

// Quinta-feira, 10/01/2030, 12:30 em São Paulo.
const NOW = Date.parse('2030-01-10T12:30:00-03:00');
const TODAY = '2030-01-10';

type Slot = { startsAt: string; endsAt: string; status: string };
type CourtDay = {
  courtId: number;
  courtName: string;
  hourlyPriceCents: number | null;
  slots: Slot[];
};

async function insertCourt(
  pool: pg.Pool,
  name: string,
  options: {
    hourlyPrice?: string;
    unavailableFrom?: string;
    openFrom?: number;
    openUntil?: number;
  } = {},
): Promise<number> {
  const { rows } = await pool.query<{ id: string }>(
    'INSERT INTO courts (name, hourly_price, unavailable_from) VALUES ($1, $2, $3) RETURNING id',
    [name, options.hourlyPrice ?? null, options.unavailableFrom ?? null],
  );
  const id = Number(rows[0]!.id);
  if (options.openFrom !== undefined) {
    await pool.query(
      `INSERT INTO availability_rules (court_id, weekday, start_hour, end_hour, valid_from)
       SELECT $1, weekday, $2, $3, '2030-01-01' FROM generate_series(0, 6) AS weekday`,
      [id, options.openFrom, options.openUntil ?? 22],
    );
  }
  return id;
}

function statusByHour(slots: Slot[]): Record<number, string> {
  const byHour: Record<number, string> = {};
  for (const slot of slots) {
    const hour = Number(
      new Intl.DateTimeFormat('en-GB', {
        timeZone: 'America/Sao_Paulo',
        hour: '2-digit',
        hourCycle: 'h23',
      }).format(new Date(slot.startsAt)),
    );
    byHour[hour] = slot.status;
  }
  return byHour;
}

describe('Consulta pública de quadras e horários (#13)', () => {
  let pool: pg.Pool;
  let app: FastifyInstance | null = null;
  let court1 = 0;
  let courtWithoutHours = 0;
  let removedCourt = 0;
  let courtLeavingSoon = 0;

  beforeAll(() => {
    pool = createTestPool();
  });

  beforeEach(async () => {
    await resetData(pool);

    court1 = await insertCourt(pool, 'Quadra 1', { hourlyPrice: '80.00', openFrom: 8 });
    courtWithoutHours = await insertCourt(pool, 'Quadra 2');
    removedCourt = await insertCourt(pool, 'Quadra 3', { unavailableFrom: TODAY, openFrom: 8 });
    courtLeavingSoon = await insertCourt(pool, 'Quadra 4', {
      unavailableFrom: '2030-01-20',
      openFrom: 8,
    });

    await insertBooking(pool, {
      courtId: court1,
      startsAt: `${TODAY} 15:00-03`,
      code: 'ABCDEFGH',
      name: 'Cliente Secreto',
      phone: '31987654321',
    });
    await insertBooking(pool, {
      courtId: court1,
      startsAt: `${TODAY} 16:00-03`,
      code: 'JKLMNPQR',
    });
    await pool.query(
      `UPDATE bookings SET status = 'cancelled', cancelled_at = now(), cancelled_by = 'customer'
       WHERE code = 'JKLMNPQR'`,
    );
    await pool.query(
      `INSERT INTO schedule_blocks (court_id, starts_at, ends_at, reason)
       VALUES ($1, $2, $3, 'manutenção')`,
      [court1, `${TODAY} 18:00-03`, `${TODAY} 20:00-03`],
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

  it('GET /api/availability devolve os horários de cada quadra com a situação de cada um', async () => {
    const response = await request(app!.server).get(`/api/availability?date=${TODAY}`);

    expect(response.status).toBe(200);
    expect(response.body.date).toBe(TODAY);

    const courts = response.body.courts as CourtDay[];
    expect(courts.map((court) => court.courtId)).toEqual([court1, courtLeavingSoon]);

    const first = courts[0]!;
    expect(first).toMatchObject({ courtName: 'Quadra 1', hourlyPriceCents: 8000 });
    expect(statusByHour(first.slots)).toEqual({
      8: 'closed',
      9: 'closed',
      10: 'closed',
      11: 'closed',
      12: 'closed',
      13: 'free',
      14: 'free',
      15: 'busy',
      16: 'free',
      17: 'free',
      18: 'closed',
      19: 'closed',
      20: 'free',
      21: 'free',
    });
    expect(first.slots.find((slot) => slot.status === 'busy')).toEqual({
      startsAt: '2030-01-10T18:00:00.000Z',
      endsAt: '2030-01-10T19:00:00.000Z',
      status: 'busy',
    });
  });

  it('não devolve nome, telefone nem código de quem reservou', async () => {
    const response = await request(app!.server).get(`/api/availability?date=${TODAY}`);
    const body = JSON.stringify(response.body);

    expect(body).not.toContain('Cliente Secreto');
    expect(body).not.toContain('31987654321');
    expect(body).not.toContain('ABCDEFGH');
    for (const court of response.body.courts as CourtDay[]) {
      for (const slot of court.slots) {
        expect(Object.keys(slot).sort()).toEqual(['endsAt', 'startsAt', 'status']);
      }
    }
  });

  it('GET /api/courts?date= lista só as quadras com algum horário livre', async () => {
    await pool.query(
      `INSERT INTO schedule_blocks (court_id, starts_at, ends_at) VALUES ($1, $2, $3)`,
      [courtLeavingSoon, `${TODAY} 00:00-03`, `${TODAY} 23:59-03`],
    );

    const response = await request(app!.server).get(`/api/courts?date=${TODAY}`);

    expect(response.status).toBe(200);
    expect(response.body.date).toBe(TODAY);
    expect((response.body.courts as CourtDay[]).map((court) => court.courtId)).toEqual([court1]);
  });

  it('quadra com remoção marcada aparece só até a véspera da remoção', async () => {
    const before = await request(app!.server).get('/api/availability?date=2030-01-19');
    const after = await request(app!.server).get('/api/availability?date=2030-01-20');

    expect((before.body.courts as CourtDay[]).map((c) => c.courtId)).toContain(courtLeavingSoon);
    expect((after.body.courts as CourtDay[]).map((c) => c.courtId)).not.toContain(courtLeavingSoon);
    expect((after.body.courts as CourtDay[]).map((c) => c.courtId)).not.toContain(removedCourt);
  });

  it('GET /api/courts sem data mantém a listagem pública de quadras', async () => {
    const response = await request(app!.server).get('/api/courts');

    expect(response.status).toBe(200);
    expect(response.body).not.toHaveProperty('date');
    expect((response.body.courts as { id: number }[]).map((court) => court.id)).toContain(
      courtWithoutHours,
    );
  });

  it('respeita a antecedência máxima de 30 dias e não mostra dias passados (D08)', async () => {
    const lastDay = await request(app!.server).get('/api/availability?date=2030-02-09');
    const tooFar = await request(app!.server).get('/api/availability?date=2030-02-10');
    const yesterday = await request(app!.server).get('/api/availability?date=2030-01-09');
    const slotsTooFar = await request(app!.server).get(
      `/api/courts/${court1}/slots?date=2030-02-10`,
    );

    expect((lastDay.body.courts as CourtDay[]).length).toBeGreaterThan(0);
    expect(tooFar.body.courts).toEqual([]);
    expect(yesterday.body.courts).toEqual([]);
    expect(slotsTooFar.body.slots).toEqual([]);
  });

  it('GET /api/courts/:id/slots devolve os horários de uma quadra', async () => {
    const response = await request(app!.server).get(`/api/courts/${court1}/slots?date=${TODAY}`);

    expect(response.status).toBe(200);
    expect(response.body).toMatchObject({ date: TODAY, courtId: court1, courtName: 'Quadra 1' });
    expect(statusByHour(response.body.slots as Slot[])[15]).toBe('busy');
    expect(statusByHour(response.body.slots as Slot[])[16]).toBe('free');
  });

  it('quadra sem horário cadastrado devolve lista vazia e quadra inexistente devolve 404', async () => {
    const empty = await request(app!.server).get(
      `/api/courts/${courtWithoutHours}/slots?date=${TODAY}`,
    );
    const missing = await request(app!.server).get(`/api/courts/999999/slots?date=${TODAY}`);

    expect(empty.status).toBe(200);
    expect(empty.body.slots).toEqual([]);
    expect(missing.status).toBe(404);
  });

  it('cancelar uma reserva libera o horário na consulta seguinte', async () => {
    const before = await request(app!.server).get(`/api/courts/${court1}/slots?date=${TODAY}`);
    expect(statusByHour(before.body.slots as Slot[])[15]).toBe('busy');

    await pool.query(
      `UPDATE bookings SET status = 'cancelled', cancelled_at = now(), cancelled_by = 'customer'
       WHERE code = 'ABCDEFGH'`,
    );

    const after = await request(app!.server).get(`/api/courts/${court1}/slots?date=${TODAY}`);
    expect(statusByHour(after.body.slots as Slot[])[15]).toBe('free');
  });

  it('responde em menos de 1,5 s com 10 quadras (RNF03)', async () => {
    for (let i = 5; i <= 10; i++) {
      await insertCourt(pool, `Quadra ${i}`, { openFrom: 6, openUntil: 24 });
    }

    const started = performance.now();
    const response = await request(app!.server).get(`/api/availability?date=${TODAY}`);
    const elapsedMs = performance.now() - started;

    expect(response.status).toBe(200);
    expect((response.body.courts as CourtDay[]).length).toBe(8);
    expect(elapsedMs).toBeLessThan(1500);
  });
});
