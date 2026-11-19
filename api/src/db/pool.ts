import pg from 'pg';

/** O mínimo que a camada de dados precisa: facilita trocar o pool por um client de transação. */
export type Queryable = Pick<pg.Pool, 'query'>;

export const APP_TIME_ZONE = 'America/Sao_Paulo';

// Colunas DATE voltam como texto 'AAAA-MM-DD', sem conversão de fuso pelo driver.
pg.types.setTypeParser(pg.types.builtins.DATE, (value) => value);

export function createPool(connectionString: string): pg.Pool {
  return new pg.Pool({
    connectionString,
    max: 10,
    idleTimeoutMillis: 30_000,
    // O Neon pode estar "dormindo" no plano gratuito (D17): dá folga para acordar.
    connectionTimeoutMillis: 10_000,
    application_name: 'tennishub-api',
  });
}

/**
 * Executa `work` dentro de uma transação. As travas de concorrência
 * (`pg_advisory_xact_lock`, `FOR UPDATE`) precisam rodar aqui dentro, pois o
 * pooler do Neon não mantém estado de sessão entre transações (D16).
 */
export async function withTransaction<T>(
  pool: pg.Pool,
  work: (client: pg.PoolClient) => Promise<T>,
): Promise<T> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(`SET LOCAL TIME ZONE '${APP_TIME_ZONE}'`);
    const result = await work(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK').catch(() => undefined);
    throw error;
  } finally {
    client.release();
  }
}
