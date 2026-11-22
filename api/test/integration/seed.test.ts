import bcrypt from 'bcryptjs';
import type pg from 'pg';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { ownerFromEnv, seed } from '../../src/db/seed.js';
import { createTestPool } from '../helpers/database.js';
import { resetData } from '../helpers/fixtures.js';

const owner = {
  name: 'Dono da Quadra',
  email: 'dono@tennishub.local',
  password: 'senha-forte-123',
};

describe('seed', () => {
  let pool: pg.Pool;

  beforeAll(() => {
    pool = createTestPool();
  });

  afterAll(async () => {
    await pool.end();
  });

  beforeEach(async () => {
    await resetData(pool);
  });

  it('cria o proprietário com a senha em hash e os dados de exemplo', async () => {
    const result = await seed(pool, owner);

    expect(result.courtsCreated).toBe(3);
    expect(result.bookingsCreated).toBe(2);

    const { rows } = await pool.query<{ email: string; password_hash: string }>(
      'SELECT email, password_hash FROM owners',
    );
    expect(rows).toHaveLength(1);
    expect(rows[0]!.password_hash).not.toBe(owner.password);
    expect(await bcrypt.compare(owner.password, rows[0]!.password_hash)).toBe(true);

    const rules = await pool.query('SELECT 1 FROM availability_rules');
    expect(rules.rows).toHaveLength(3 * 7);
  });

  it('pode rodar de novo sem duplicar dados e atualiza a senha do proprietário', async () => {
    await seed(pool, owner);
    const second = await seed(pool, {
      ...owner,
      email: 'DONO@tennishub.local',
      password: 'nova-senha-456',
    });

    expect(second).toMatchObject({ courtsCreated: 0, bookingsCreated: 0 });

    const owners = await pool.query<{ password_hash: string }>('SELECT password_hash FROM owners');
    expect(owners.rows).toHaveLength(1);
    expect(await bcrypt.compare('nova-senha-456', owners.rows[0]!.password_hash)).toBe(true);

    const courts = await pool.query('SELECT 1 FROM courts');
    expect(courts.rows).toHaveLength(3);
  });

  it('exige o proprietário nas variáveis de ambiente, sem senha no código', () => {
    expect(() => ownerFromEnv({})).toThrow(/OWNER_/);
    expect(() =>
      ownerFromEnv({ OWNER_NAME: 'Dono', OWNER_EMAIL: 'dono@x.com', OWNER_PASSWORD: '123' }),
    ).toThrow(/8 caracteres/);
    expect(
      ownerFromEnv({ OWNER_NAME: 'Dono', OWNER_EMAIL: 'dono@x.com', OWNER_PASSWORD: '12345678' }),
    ).toEqual({ name: 'Dono', email: 'dono@x.com', password: '12345678' });
  });
});
