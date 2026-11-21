import type pg from 'pg';
import { createPool } from '../../src/db/pool.js';

/**
 * URL do banco de teste. Por segurança, só aceita bancos cujo nome termina em "_test":
 * os testes apagam e recriam o schema, e não podem rodar contra o Neon de ninguém.
 * Localmente vem da TEST_DATABASE_URL do api/.env; o CI define só DATABASE_URL.
 */
export function testDatabaseUrl(): string {
  const url = process.env.TEST_DATABASE_URL || process.env.DATABASE_URL;
  if (!url) {
    throw new Error(
      'Defina TEST_DATABASE_URL no api/.env apontando para um banco de teste (ex.: .../tennishub_test).',
    );
  }
  const databaseName = decodeURIComponent(new URL(url).pathname.replace(/^\//, ''));
  if (!databaseName.endsWith('_test')) {
    throw new Error(
      `Recusando rodar testes no banco "${databaseName}": defina TEST_DATABASE_URL no api/.env com um banco cujo nome termine em "_test".`,
    );
  }
  return url;
}

export function createTestPool(): pg.Pool {
  return createPool(testDatabaseUrl());
}
