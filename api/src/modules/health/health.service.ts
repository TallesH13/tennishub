import { AppError } from '../../shared/errors.js';
import type { HealthRepository } from './health.repository.js';

export type HealthStatus = { status: 'ok'; database: 'ok' };

export class HealthService {
  constructor(private readonly repository: HealthRepository) {}

  async check(): Promise<HealthStatus> {
    try {
      await this.repository.ping();
    } catch (error) {
      throw new AppError(503, 'DATABASE_UNAVAILABLE', 'Banco de dados indisponível.', undefined, {
        cause: error,
      });
    }
    return { status: 'ok', database: 'ok' };
  }
}
