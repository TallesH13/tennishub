import { buildApp } from './app.js';
import { ConfigError, loadConfig, loadEnvFile } from './config/env.js';
import { createPool } from './db/pool.js';

async function main(): Promise<void> {
  loadEnvFile();
  const config = loadConfig();
  const pool = createPool(config.databaseUrl);

  const app = await buildApp(
    { db: pool },
    {
      logger: {
        level: config.logLevel,
        // Nunca registrar senha, cookie de sessão ou cabeçalho de autorização.
        redact: ['req.headers.authorization', 'req.headers.cookie', 'body.password'],
      },
    },
  );

  const shutdown = async (signal: string) => {
    app.log.info({ signal }, 'encerrando');
    await app.close();
    await pool.end();
    process.exit(0);
  };
  process.on('SIGINT', () => void shutdown('SIGINT'));
  process.on('SIGTERM', () => void shutdown('SIGTERM'));

  await app.listen({ host: config.host, port: config.port });
}

try {
  await main();
} catch (error: unknown) {
  console.error(error instanceof ConfigError ? error.message : error);
  process.exit(1);
}
