import type { Queryable } from '../../db/pool.js';

export class HealthRepository {
  constructor(private readonly db: Queryable) {}

  /** Faz uma consulta trivial para confirmar que o banco responde. */
  async ping(): Promise<void> {
    await this.db.query('SELECT 1');
  }
}
