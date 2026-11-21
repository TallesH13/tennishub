import type { FastifyInstance } from 'fastify';
import type { HealthService } from './health.service.js';

export function healthRoutes(service: HealthService) {
  return async function register(app: FastifyInstance): Promise<void> {
    app.get('/health', async () => service.check());
  };
}
