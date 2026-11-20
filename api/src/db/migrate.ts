import { fileURLToPath } from 'node:url';
import { runner } from 'node-pg-migrate';
import { loadEnvFile } from '../config/env.js';
import { connectionConfig, describeConnection } from './connection.js';

export const MIGRATIONS_DIR = fileURLToPath(new URL('../../migrations', import.meta.url));

export type MigrateOptions = {
  databaseUrl: string;
  direction?: 'up' | 'down';
  /** Quantas migrations aplicar/desfazer. Padrão: todas no "up" e 1 no "down". */
  count?: number;
  log?: (message: string) => void;
};

export async function migrate(options: MigrateOptions): Promise<string[]> {
  if (describeConnection(options.databaseUrl).isPooler) {
    // O pooler do Neon (PgBouncer em modo transação) não serve para DDL nem para a
    // trava que o node-pg-migrate usa; as migrations precisam da conexão direta (D16).
    throw new Error(
      'As migrations não podem usar o pooler do Neon (host com "-pooler"). Defina DATABASE_URL_DIRECT com a conexão direta.',
    );
  }

  const direction = options.direction ?? 'up';
  const applied = await runner({
    databaseUrl: connectionConfig(options.databaseUrl),
    dir: MIGRATIONS_DIR,
    direction,
    count: options.count ?? (direction === 'up' ? Infinity : 1),
    migrationsTable: 'pgmigrations',
    checkOrder: true,
    singleTransaction: true,
    log: options.log ?? (() => undefined),
  });
  return applied.map((migration) => migration.name);
}

// Execução pela linha de comando: `npm run migrate` / `npm run migrate:down`.
if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  loadEnvFile();
  const direction = process.argv[2] === 'down' ? 'down' : 'up';
  // Migrations usam a conexão direta (sem pooler), conforme D16.
  const databaseUrl = process.env.DATABASE_URL_DIRECT || process.env.DATABASE_URL;
  if (!databaseUrl) {
    console.error('Defina DATABASE_URL_DIRECT ou DATABASE_URL para rodar as migrations.');
    process.exit(1);
  }

  migrate({ databaseUrl, direction, log: (message) => console.log(message) })
    .then((names) => {
      console.log(
        names.length ? `Migrations (${direction}): ${names.join(', ')}` : 'Nada a migrar.',
      );
    })
    .catch((error: unknown) => {
      console.error(error);
      process.exit(1);
    });
}
