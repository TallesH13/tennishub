import pg from 'pg';
import { migrate } from '../../src/db/migrate.js';
import { testDatabaseUrl } from '../helpers/database.js';

/** Recria o schema do banco de teste do zero e aplica todas as migrations antes da suíte. */
export default async function setup(): Promise<void> {
  const databaseUrl = testDatabaseUrl();

  const client = new pg.Client({ connectionString: databaseUrl });
  await client.connect();
  try {
    await client.query('DROP SCHEMA IF EXISTS public CASCADE');
    await client.query('CREATE SCHEMA public');
  } finally {
    await client.end();
  }

  await migrate({ databaseUrl, direction: 'up' });
}
