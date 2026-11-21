import { readdirSync } from 'node:fs';
import type pg from 'pg';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { MIGRATIONS_DIR } from '../../src/db/migrate.js';
import { createTestPool } from '../helpers/database.js';
import { PG, createCourt, insertBooking, pgError, resetData } from '../helpers/fixtures.js';

let pool: pg.Pool;
let court1: number;
let court2: number;

beforeAll(() => {
  pool = createTestPool();
});

afterAll(async () => {
  await pool.end();
});

beforeEach(async () => {
  await resetData(pool);
  court1 = await createCourt(pool, 'Quadra 1');
  court2 = await createCourt(pool, 'Quadra 2');
});

describe('migrations', () => {
  it('aplicam todas as migrations do zero', async () => {
    const files = readdirSync(MIGRATIONS_DIR).filter((file) => file.endsWith('.sql'));
    const { rows } = await pool.query<{ name: string }>(
      'SELECT name FROM pgmigrations ORDER BY run_on, id',
    );

    expect(rows.map((row) => `${row.name}.sql`)).toEqual(files.sort());
  });

  it('definem o fuso America/Sao_Paulo para as conexões do banco', async () => {
    const { rows } = await pool.query<{ TimeZone: string }>('SHOW timezone');
    expect(rows[0]!.TimeZone).toBe('America/Sao_Paulo');
  });
});

describe('reservas: horário único (RNF01)', () => {
  it('rejeita duas reservas confirmadas para a mesma quadra e o mesmo início', async () => {
    await insertBooking(pool, {
      courtId: court1,
      startsAt: '2030-01-10 10:00-03',
      code: 'ABCDEFGH',
    });

    const error = await pgError(
      insertBooking(pool, {
        courtId: court1,
        startsAt: '2030-01-10 10:00-03',
        code: 'JKLMNPQR',
        phone: '3133334444',
      }),
    );

    expect(error).toEqual({
      code: PG.uniqueViolation,
      constraint: 'bookings_court_slot_confirmed_key',
    });
  });

  it('com 20 inserções simultâneas no mesmo horário, só 1 é gravada', async () => {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    const attempts = Array.from({ length: 20 }, (_, i) =>
      insertBooking(pool, {
        courtId: court1,
        startsAt: '2030-05-05 18:00-03',
        code: `PAR${alphabet[i]}2345`,
        phone: `3199999${String(i).padStart(4, '0')}`,
      }),
    );

    const results = await Promise.allSettled(attempts);
    const rejected = results.filter((r) => r.status === 'rejected') as PromiseRejectedResult[];

    expect(results.filter((r) => r.status === 'fulfilled')).toHaveLength(1);
    expect(rejected).toHaveLength(19);
    for (const failure of rejected) {
      expect((failure.reason as { code: string }).code).toBe(PG.uniqueViolation);
    }
  });

  it('permite o mesmo horário em quadras diferentes', async () => {
    await insertBooking(pool, {
      courtId: court1,
      startsAt: '2030-01-10 10:00-03',
      code: 'ABCDEFGH',
    });
    await insertBooking(pool, {
      courtId: court2,
      startsAt: '2030-01-10 10:00-03',
      code: 'JKLMNPQR',
    });

    const { rows } = await pool.query('SELECT 1 FROM bookings');
    expect(rows).toHaveLength(2);
  });

  it('libera o horário quando a reserva é cancelada', async () => {
    await insertBooking(pool, {
      courtId: court1,
      startsAt: '2030-01-10 10:00-03',
      code: 'ABCDEFGH',
    });
    await pool.query(
      `UPDATE bookings SET status = 'cancelled', cancelled_at = now(), cancelled_by = 'customer'
       WHERE code = 'ABCDEFGH'`,
    );

    await insertBooking(pool, {
      courtId: court1,
      startsAt: '2030-01-10 10:00-03',
      code: 'JKLMNPQR',
    });

    const { rows } = await pool.query(`SELECT 1 FROM bookings WHERE status = 'confirmed'`);
    expect(rows).toHaveLength(1);
  });
});

describe('reservas: duração e horário (RF02)', () => {
  it('rejeita reserva com duração diferente de 1 hora', async () => {
    const error = await pgError(
      insertBooking(pool, {
        courtId: court1,
        startsAt: '2030-01-11 10:00-03',
        endsAt: '2030-01-11 10:30-03',
        code: 'ABCDEFGH',
      }),
    );
    expect(error).toEqual({ code: PG.checkViolation, constraint: 'bookings_one_hour' });
  });

  it('rejeita início fora da hora cheia', async () => {
    const error = await pgError(
      insertBooking(pool, { courtId: court1, startsAt: '2030-01-11 10:30-03', code: 'ABCDEFGH' }),
    );
    expect(error).toEqual({ code: PG.checkViolation, constraint: 'bookings_starts_on_the_hour' });
  });

  it('calcula o dia do jogo no fuso de São Paulo, mesmo com a sessão em UTC', async () => {
    const client = await pool.connect();
    try {
      await client.query(`SET TIME ZONE 'UTC'`);
      await insertBooking(client, {
        courtId: court1,
        startsAt: '2030-01-11 22:00-03',
        code: 'NNNNNN22',
      });
      await insertBooking(client, {
        courtId: court1,
        startsAt: '2030-01-11 23:00-03',
        code: 'NNNNNN33',
      });
      await insertBooking(client, {
        courtId: court1,
        startsAt: '2030-01-12 00:00-03',
        code: 'NNNNNN44',
      });

      const { rows } = await client.query<{ code: string; game_date: string }>(
        'SELECT code, game_date FROM bookings ORDER BY starts_at',
      );
      expect(rows).toEqual([
        { code: 'NNNNNN22', game_date: '2030-01-11' },
        { code: 'NNNNNN33', game_date: '2030-01-11' },
        { code: 'NNNNNN44', game_date: '2030-01-12' },
      ]);
    } finally {
      client.release();
    }
  });
});

describe('reservas: dados do cliente e código', () => {
  it.each([
    ['com máscara', '(31) 99999-0000'],
    ['curto demais', '319999'],
    ['com DDD começando em 0', '01999990000'],
  ])('rejeita telefone %s', async (_, phone) => {
    const error = await pgError(
      insertBooking(pool, {
        courtId: court1,
        startsAt: '2030-01-11 12:00-03',
        code: 'ABCDEFGH',
        phone,
      }),
    );
    expect(error).toEqual({
      code: PG.checkViolation,
      constraint: 'bookings_customer_phone_digits',
    });
  });

  it.each([['3133334444'], ['31999990000']])(
    'aceita telefone só com dígitos: %s',
    async (phone) => {
      await insertBooking(pool, {
        courtId: court1,
        startsAt: '2030-01-11 12:00-03',
        code: 'ABCDEFGH',
        phone,
      });
    },
  );

  it('rejeita nome com menos de 5 caracteres', async () => {
    const error = await pgError(
      insertBooking(pool, {
        courtId: court1,
        startsAt: '2030-01-11 12:00-03',
        code: 'ABCDEFGH',
        name: 'Ana',
      }),
    );
    expect(error).toEqual({ code: PG.checkViolation, constraint: 'bookings_customer_name_length' });
  });

  it.each([['ABCDEFO0'], ['abcdefgh'], ['ABCDEF1I'], ['ABCDEFG']])(
    'rejeita código fora do formato: %s',
    async (code) => {
      const error = await pgError(
        insertBooking(pool, { courtId: court1, startsAt: '2030-01-11 12:00-03', code }),
      );
      expect(error).toEqual({ code: PG.checkViolation, constraint: 'bookings_code_format' });
    },
  );

  it('rejeita código repetido', async () => {
    await insertBooking(pool, {
      courtId: court1,
      startsAt: '2030-01-11 12:00-03',
      code: 'ABCDEFGH',
    });
    const error = await pgError(
      insertBooking(pool, { courtId: court1, startsAt: '2030-01-11 13:00-03', code: 'ABCDEFGH' }),
    );
    expect(error).toEqual({ code: PG.uniqueViolation, constraint: 'bookings_code_key' });
  });

  it('exige quando e por quem a reserva foi cancelada', async () => {
    await insertBooking(pool, {
      courtId: court1,
      startsAt: '2030-01-11 12:00-03',
      code: 'ABCDEFGH',
    });
    const error = await pgError(pool.query(`UPDATE bookings SET status = 'cancelled'`));
    expect(error).toEqual({
      code: PG.checkViolation,
      constraint: 'bookings_cancellation_consistent',
    });
  });

  it('impede apagar quadra que tem reservas', async () => {
    await insertBooking(pool, {
      courtId: court1,
      startsAt: '2030-01-11 12:00-03',
      code: 'ABCDEFGH',
    });
    const error = await pgError(pool.query('DELETE FROM courts WHERE id = $1', [court1]));
    expect([PG.foreignKeyViolation, '23001']).toContain(error.code);
  });
});

describe('proprietários e quadras', () => {
  const hash = 'x'.repeat(60);

  it('e-mail do proprietário é único sem diferenciar maiúsculas', async () => {
    await pool.query(
      `INSERT INTO owners (name, email, password_hash) VALUES ('Dono', 'dono@x.com', $1)`,
      [hash],
    );
    const error = await pgError(
      pool.query(
        `INSERT INTO owners (name, email, password_hash) VALUES ('Outro', 'DONO@X.com', $1)`,
        [hash],
      ),
    );
    expect(error).toEqual({ code: PG.uniqueViolation, constraint: 'owners_email_key' });
  });

  it('recusa senha em texto puro no lugar do hash', async () => {
    const error = await pgError(
      pool.query(
        `INSERT INTO owners (name, email, password_hash) VALUES ('Dono', 'd@x.com', 'senha123')`,
      ),
    );
    expect(error).toEqual({ code: PG.checkViolation, constraint: 'owners_password_hash_length' });
  });

  it('nome de quadra é único entre as ativas e pode ser reutilizado após a remoção', async () => {
    const duplicated = await pgError(pool.query(`INSERT INTO courts (name) VALUES ('quadra 1')`));
    expect(duplicated).toEqual({ code: PG.uniqueViolation, constraint: 'courts_active_name_key' });

    await pool.query(`UPDATE courts SET unavailable_from = '2030-03-01' WHERE id = $1`, [court1]);
    await pool.query(`INSERT INTO courts (name) VALUES ('quadra 1')`);
  });

  it('recusa valor por hora negativo', async () => {
    const error = await pgError(
      pool.query(`INSERT INTO courts (name, hourly_price) VALUES ('Q3', -1)`),
    );
    expect(error).toEqual({
      code: PG.checkViolation,
      constraint: 'courts_hourly_price_non_negative',
    });
  });
});

describe('regras de disponibilidade', () => {
  const insertRule = (start: number, end: number, validFrom = '2030-01-01') =>
    pool.query(
      `INSERT INTO availability_rules (court_id, weekday, start_hour, end_hour, valid_from)
       VALUES ($1, 1, $2, $3, $4)`,
      [court1, start, end, validFrom],
    );

  it('aceita faixas vizinhas e rejeita faixas sobrepostas na mesma vigência', async () => {
    await insertRule(8, 12);
    await insertRule(12, 22);

    const error = await pgError(insertRule(11, 13));
    expect(error).toEqual({
      code: PG.exclusionViolation,
      constraint: 'availability_rules_no_overlap',
    });
  });

  it('aceita a mesma faixa em outra vigência', async () => {
    await insertRule(8, 12);
    await insertRule(9, 13, '2030-02-01');
  });

  it('rejeita hora final menor ou igual à inicial', async () => {
    const error = await pgError(insertRule(10, 10));
    expect(error).toEqual({
      code: PG.checkViolation,
      constraint: 'availability_rules_end_after_start',
    });
  });
});
