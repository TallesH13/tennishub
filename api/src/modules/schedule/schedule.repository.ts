import type { Queryable } from '../../db/pool.js';
import { ConflictError } from '../../shared/errors.js';

export type OpeningRange = {
  weekday: number;
  startHour: number;
  endHour: number;
};

export type CourtSchedule = {
  validFrom: string;
  ranges: OpeningRange[];
};

export type ScheduleBlock = {
  id: number;
  courtId: number;
  startsAt: string;
  endsAt: string;
  reason: string;
};

export type FlaggedBooking = {
  id: number;
  courtId: number;
  startsAt: string;
  endsAt: string;
  gameDate: string;
  customerName: string;
  customerPhone: string;
  code: string;
  needsRelocation: boolean;
};

type RuleDbRow = {
  weekday: number;
  start_hour: number;
  end_hour: number;
  valid_from: string;
};

type BlockDbRow = {
  id: string;
  court_id: string;
  starts_at: Date | string;
  ends_at: Date | string;
  reason: string | null;
};

type ConfirmedBookingDbRow = {
  id: string;
  court_id: string;
  starts_at: Date | string;
  ends_at: Date | string;
  game_date: string;
  customer_name: string;
  customer_phone: string;
  code: string;
  local_weekday: number;
  local_start_hour: number;
};

function toIsoString(value: Date | string): string {
  return value instanceof Date ? value.toISOString() : new Date(value).toISOString();
}

function isExclusionViolation(error: unknown): boolean {
  return (
    typeof error === 'object' &&
    error !== null &&
    'code' in error &&
    (error as { code?: string }).code === '23P01'
  );
}

export class ScheduleRepository {
  constructor(private readonly db: Queryable) {}

  async courtExists(courtId: number): Promise<boolean> {
    const { rows } = await this.db.query<{ exists: boolean }>(
      'SELECT EXISTS (SELECT 1 FROM courts WHERE id = $1) AS exists',
      [courtId],
    );
    return Boolean(rows[0]?.exists);
  }

  async findEffectiveSchedule(courtId: number, onDate: string): Promise<CourtSchedule | null> {
    const { rows: effectiveRows } = await this.db.query<{ valid_from: string }>(
      `SELECT max(valid_from)::text AS valid_from
       FROM availability_rules
       WHERE court_id = $1
         AND valid_from <= $2::date`,
      [courtId, onDate],
    );

    let targetValidFrom = effectiveRows[0]?.valid_from ?? null;

    if (!targetValidFrom) {
      const { rows: upcomingRows } = await this.db.query<{ valid_from: string }>(
        `SELECT min(valid_from)::text AS valid_from
         FROM availability_rules
         WHERE court_id = $1`,
        [courtId],
      );
      targetValidFrom = upcomingRows[0]?.valid_from ?? null;
    }

    if (!targetValidFrom) return null;

    const { rows } = await this.db.query<RuleDbRow>(
      `SELECT weekday, start_hour, end_hour, valid_from::text AS valid_from
       FROM availability_rules
       WHERE court_id = $1
         AND valid_from = $2::date
       ORDER BY weekday ASC, start_hour ASC`,
      [courtId, targetValidFrom],
    );

    if (rows.length === 0) return null;

    return {
      validFrom: targetValidFrom,
      ranges: rows.map((row) => ({
        weekday: Number(row.weekday),
        startHour: Number(row.start_hour),
        endHour: Number(row.end_hour),
      })),
    };
  }

  async findRulesActiveOnDate(courtId: number, date: string): Promise<OpeningRange[]> {
    const { rows: effectiveRows } = await this.db.query<{ valid_from: string }>(
      `SELECT max(valid_from)::text AS valid_from
       FROM availability_rules
       WHERE court_id = $1
         AND valid_from <= $2::date`,
      [courtId, date],
    );

    const validFrom = effectiveRows[0]?.valid_from ?? null;
    if (!validFrom) return [];

    const { rows } = await this.db.query<RuleDbRow>(
      `SELECT weekday, start_hour, end_hour, valid_from::text AS valid_from
       FROM availability_rules
       WHERE court_id = $1
         AND valid_from = $2::date
       ORDER BY weekday ASC, start_hour ASC`,
      [courtId, validFrom],
    );

    return rows.map((row) => ({
      weekday: Number(row.weekday),
      startHour: Number(row.start_hour),
      endHour: Number(row.end_hour),
    }));
  }

  async replaceScheduleForValidFrom(
    courtId: number,
    validFrom: string,
    ranges: OpeningRange[],
  ): Promise<void> {
    await this.db.query(
      `DELETE FROM availability_rules
       WHERE court_id = $1
         AND valid_from = $2::date`,
      [courtId, validFrom],
    );

    try {
      for (const range of ranges) {
        await this.db.query(
          `INSERT INTO availability_rules (court_id, weekday, start_hour, end_hour, valid_from)
           VALUES ($1, $2, $3, $4, $5::date)`,
          [courtId, range.weekday, range.startHour, range.endHour, validFrom],
        );
      }
    } catch (error) {
      if (isExclusionViolation(error)) {
        throw new ConflictError(
          'SCHEDULE_OVERLAP',
          'Faixas de horário sobrepostas no mesmo dia da semana.',
        );
      }
      throw error;
    }
  }

  async findNextValidFrom(courtId: number, afterDate: string): Promise<string | null> {
    const { rows } = await this.db.query<{ next_valid_from: string | null }>(
      `SELECT min(valid_from)::text AS next_valid_from
       FROM availability_rules
       WHERE court_id = $1
         AND valid_from > $2::date`,
      [courtId, afterDate],
    );
    return rows[0]?.next_valid_from ?? null;
  }

  async listConfirmedBookingsInEffectiveWindow(
    courtId: number,
    fromDate: string,
    beforeDate: string | null,
  ): Promise<
    Array<{
      booking: Omit<FlaggedBooking, 'needsRelocation'>;
      localWeekday: number;
      localStartHour: number;
    }>
  > {
    const { rows } = await this.db.query<ConfirmedBookingDbRow>(
      `SELECT id,
              court_id,
              starts_at,
              ends_at,
              game_date::text AS game_date,
              customer_name,
              customer_phone,
              code,
              EXTRACT(DOW FROM starts_at AT TIME ZONE 'America/Sao_Paulo')::int AS local_weekday,
              EXTRACT(HOUR FROM starts_at AT TIME ZONE 'America/Sao_Paulo')::int AS local_start_hour
       FROM bookings
       WHERE court_id = $1
         AND status = 'confirmed'
         AND game_date >= $2::date
         AND ($3::date IS NULL OR game_date < $3::date)
       ORDER BY starts_at ASC`,
      [courtId, fromDate, beforeDate],
    );

    return rows.map((row) => ({
      booking: {
        id: Number(row.id),
        courtId: Number(row.court_id),
        startsAt: toIsoString(row.starts_at),
        endsAt: toIsoString(row.ends_at),
        gameDate: row.game_date,
        customerName: row.customer_name,
        customerPhone: row.customer_phone,
        code: row.code,
      },
      localWeekday: Number(row.local_weekday),
      localStartHour: Number(row.local_start_hour),
    }));
  }

  async updateBookingsNeedsRelocation(
    bookingIds: number[],
    needsRelocation: boolean,
  ): Promise<void> {
    if (bookingIds.length === 0) return;
    await this.db.query(
      `UPDATE bookings
       SET needs_relocation = $2
       WHERE id = ANY($1::bigint[])`,
      [bookingIds, needsRelocation],
    );
  }

  async listBlocksByCourt(courtId: number): Promise<ScheduleBlock[]> {
    const { rows } = await this.db.query<BlockDbRow>(
      `SELECT id, court_id, starts_at, ends_at, reason
       FROM schedule_blocks
       WHERE court_id = $1
       ORDER BY starts_at ASC`,
      [courtId],
    );

    return rows.map((row) => ({
      id: Number(row.id),
      courtId: Number(row.court_id),
      startsAt: toIsoString(row.starts_at),
      endsAt: toIsoString(row.ends_at),
      reason: row.reason ?? '',
    }));
  }

  async listBlocksOverlappingPeriod(
    courtId: number,
    periodStartIso: string,
    periodEndIso: string,
  ): Promise<ScheduleBlock[]> {
    const { rows } = await this.db.query<BlockDbRow>(
      `SELECT id, court_id, starts_at, ends_at, reason
       FROM schedule_blocks
       WHERE court_id = $1
         AND starts_at < $3::timestamptz
         AND ends_at > $2::timestamptz
       ORDER BY starts_at ASC`,
      [courtId, periodStartIso, periodEndIso],
    );

    return rows.map((row) => ({
      id: Number(row.id),
      courtId: Number(row.court_id),
      startsAt: toIsoString(row.starts_at),
      endsAt: toIsoString(row.ends_at),
      reason: row.reason ?? '',
    }));
  }

  async createBlock(input: {
    courtId: number;
    startsAt: string;
    endsAt: string;
    reason?: string | null;
  }): Promise<ScheduleBlock> {
    const { rows } = await this.db.query<BlockDbRow>(
      `INSERT INTO schedule_blocks (court_id, starts_at, ends_at, reason)
       VALUES ($1, $2::timestamptz, $3::timestamptz, $4)
       RETURNING id, court_id, starts_at, ends_at, reason`,
      [input.courtId, input.startsAt, input.endsAt, input.reason?.trim() || null],
    );

    const row = rows[0]!;
    return {
      id: Number(row.id),
      courtId: Number(row.court_id),
      startsAt: toIsoString(row.starts_at),
      endsAt: toIsoString(row.ends_at),
      reason: row.reason ?? '',
    };
  }

  async deleteBlock(blockId: number, courtId?: number): Promise<boolean> {
    const { rowCount } = await this.db.query(
      `DELETE FROM schedule_blocks
       WHERE id = $1
         AND ($2::bigint IS NULL OR court_id = $2)`,
      [blockId, courtId ?? null],
    );
    return (rowCount ?? 0) > 0;
  }

  async listConfirmedBookingStartsInPeriod(
    courtId: number,
    periodStartIso: string,
    periodEndIso: string,
  ): Promise<string[]> {
    const { rows } = await this.db.query<{ starts_at: Date | string }>(
      `SELECT starts_at
       FROM bookings
       WHERE court_id = $1
         AND status = 'confirmed'
         AND starts_at >= $2::timestamptz
         AND starts_at < $3::timestamptz`,
      [courtId, periodStartIso, periodEndIso],
    );
    return rows.map((row) => toIsoString(row.starts_at));
  }
}
