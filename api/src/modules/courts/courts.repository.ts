import type { Queryable } from '../../db/pool.js';
import { ConflictError } from '../../shared/errors.js';

export type Court = {
  id: number;
  name: string;
  hourlyPriceCents: number | null;
  unavailableFrom: string | null;
};

export type CreateCourtData = {
  name: string;
  hourlyPriceCents: number | null;
  unavailableFrom: string | null;
};

export type UpdateCourtData = {
  name: string;
  hourlyPriceCents: number | null;
  unavailableFrom: string | null;
};

type CourtDbRow = {
  id: string;
  name: string;
  hourly_price: string | null;
  unavailable_from: string | null;
};

function mapCourtRow(row: CourtDbRow): Court {
  return {
    id: Number(row.id),
    name: row.name,
    hourlyPriceCents: row.hourly_price === null ? null : Math.round(Number(row.hourly_price) * 100),
    unavailableFrom: row.unavailable_from,
  };
}

function centsToDecimal(cents: number | null): string | null {
  if (cents === null) return null;
  return (cents / 100).toFixed(2);
}

function isUniqueViolation(error: unknown): boolean {
  return (
    typeof error === 'object' &&
    error !== null &&
    'code' in error &&
    (error as { code?: string }).code === '23505'
  );
}

export class CourtsRepository {
  constructor(private readonly db: Queryable) {}

  async listPublic(): Promise<Court[]> {
    const { rows } = await this.db.query<CourtDbRow>(
      `SELECT id, name, hourly_price, unavailable_from
       FROM courts
       WHERE unavailable_from IS NULL
          OR unavailable_from > (now() AT TIME ZONE 'America/Sao_Paulo')::date
       ORDER BY id ASC`,
    );
    return rows.map(mapCourtRow);
  }

  async listAll(): Promise<Court[]> {
    const { rows } = await this.db.query<CourtDbRow>(
      `SELECT id, name, hourly_price, unavailable_from
       FROM courts
       ORDER BY id ASC`,
    );
    return rows.map(mapCourtRow);
  }

  async findById(id: number): Promise<Court | null> {
    const { rows } = await this.db.query<CourtDbRow>(
      `SELECT id, name, hourly_price, unavailable_from
       FROM courts
       WHERE id = $1
       LIMIT 1`,
      [id],
    );
    const row = rows[0];
    return row ? mapCourtRow(row) : null;
  }

  async existsActiveWithName(name: string, excludeId?: number): Promise<boolean> {
    const { rows } = await this.db.query<{ exists: boolean }>(
      `SELECT EXISTS (
         SELECT 1
         FROM courts
         WHERE lower(btrim(name)) = lower(btrim($1))
           AND unavailable_from IS NULL
           AND ($2::bigint IS NULL OR id <> $2)
       ) AS exists`,
      [name, excludeId ?? null],
    );
    return Boolean(rows[0]?.exists);
  }

  async countConfirmedBookingsFrom(courtId: number, fromDate: string): Promise<number> {
    const { rows } = await this.db.query<{ count: number }>(
      `SELECT count(*)::int AS count
       FROM bookings
       WHERE court_id = $1
         AND status = 'confirmed'
         AND game_date >= $2::date`,
      [courtId, fromDate],
    );
    return rows[0]?.count ?? 0;
  }

  async create(data: CreateCourtData): Promise<Court> {
    try {
      const { rows } = await this.db.query<CourtDbRow>(
        `INSERT INTO courts (name, hourly_price, unavailable_from)
         VALUES ($1, $2, $3::date)
         RETURNING id, name, hourly_price, unavailable_from`,
        [data.name, centsToDecimal(data.hourlyPriceCents), data.unavailableFrom],
      );
      return mapCourtRow(rows[0]!);
    } catch (error) {
      if (isUniqueViolation(error)) {
        throw new ConflictError('COURT_NAME_TAKEN', 'Já existe uma quadra ativa com este nome.');
      }
      throw error;
    }
  }

  async update(id: number, data: UpdateCourtData): Promise<Court | null> {
    try {
      const { rows } = await this.db.query<CourtDbRow>(
        `UPDATE courts
         SET name = $2,
             hourly_price = $3,
             unavailable_from = $4::date
         WHERE id = $1
         RETURNING id, name, hourly_price, unavailable_from`,
        [id, data.name, centsToDecimal(data.hourlyPriceCents), data.unavailableFrom],
      );
      const row = rows[0];
      return row ? mapCourtRow(row) : null;
    } catch (error) {
      if (isUniqueViolation(error)) {
        throw new ConflictError('COURT_NAME_TAKEN', 'Já existe uma quadra ativa com este nome.');
      }
      throw error;
    }
  }

  async markUnavailable(id: number, unavailableFrom: string): Promise<Court | null> {
    const { rows } = await this.db.query<CourtDbRow>(
      `UPDATE courts
       SET unavailable_from = $2::date
       WHERE id = $1
       RETURNING id, name, hourly_price, unavailable_from`,
      [id, unavailableFrom],
    );
    const row = rows[0];
    return row ? mapCourtRow(row) : null;
  }
}
