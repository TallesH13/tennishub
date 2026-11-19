import Fastify, { type FastifyInstance, type FastifyServerOptions } from 'fastify';
import type { Queryable } from './db/pool.js';
import { HealthRepository } from './modules/health/health.repository.js';
import { healthRoutes } from './modules/health/health.routes.js';
import { HealthService } from './modules/health/health.service.js';
import { registerErrorHandling } from './shared/errors.js';

/** Prefixo de todas as rotas REST. O build do Flutter Web será servido na raiz (#4). */
export const API_PREFIX = '/api';

export type AppDependencies = {
  db: Queryable;
};

export type BuildAppOptions = {
  logger?: FastifyServerOptions['logger'];
};

/**
 * Monta a aplicação sem abrir porta, o que permite testá-la com `inject`/Supertest.
 * Camadas: rotas (HTTP) → serviços (regras de negócio) → repositórios (SQL).
 */
export async function buildApp(
  deps: AppDependencies,
  options: BuildAppOptions = {},
): Promise<FastifyInstance> {
  const app = Fastify({
    logger: options.logger ?? false,
    disableRequestLogging: false,
  });

  registerErrorHandling(app);

  const healthService = new HealthService(new HealthRepository(deps.db));

  await app.register(
    async (api) => {
      await api.register(healthRoutes(healthService));
    },
    { prefix: API_PREFIX },
  );

  return app;
}
