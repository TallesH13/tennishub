import type pg from 'pg';
import { createPool } from '../../src/db/pool.js';

/**
 * URL do banco de teste. Por segurança, só aceita bancos cujo nome termina em "_test":
 * os testes apagam e recriam o schema, e não podem rodar contra o Neon de ninguém.
 */
export function testDatabaseUrl(): string {
  const url = process.env.DATABASE_URL;
  if (!url) {
    throw new Error(
      'DATABASE_URL não definida para os testes. Crie api/.env.test apontando para um PostgreSQL local (ex.: .../tennishub_test).',
    );
  }
  const databaseName = new URL(url).pathname.replace(/^\//, '');
  if (!databaseName.endsWith('_test')) {
    throw new Error(
      `Recusando rodar testes no banco "${databaseName}": o nome do banco de teste precisa terminar em "_test".`,
    );
  }
  return url;
}

export function createTestPool(): pg.Pool {
  return createPool(testDatabaseUrl());
}
