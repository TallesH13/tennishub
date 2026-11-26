import type { Queryable } from '../../db/pool.js';

export type BookingStatus = 'confirmed' | 'cancelled';

export type Booking = {
  id: number;
  code: string;
  courtId: number;
  courtName: string;
  startsAt: string;
  endsAt: string;
  customerName: string;
  customerPhone: string;
  status: BookingStatus;
  needsRelocation: boolean;
  relocationReason: string | null;
  cancelledBy: 'customer' | 'owner' | null;
  cancellationReason: string | null;
  createdAt: string;
};

export type NewBooking = {
  courtId: number;
  startsAt: string;
  customerName: string;
  customerPhone: string;
  code: string;
};

type BookingDbRow = {
  id: string;
  code: string;
  court_id: string;
  court_name: string;
  starts_at: Date;
  ends_at: Date;
  customer_name: string;
  customer_phone: string;
  status: BookingStatus;
  needs_relocation: boolean;
  relocation_reason: string | null;
  cancelled_by: 'customer' | 'owner' | null;
  cancellation_reason: string | null;
  created_at: Date;
};

export const BOOKING_COLUMNS = `b.id, b.code, b.court_id, c.name AS court_name, b.starts_at, b.ends_at,
  b.customer_name, b.customer_phone, b.status, b.needs_relocation, b.relocation_reason,
  b.cancelled_by, b.cancellation_reason, b.created_at`;

// SQL fixo, sem interpolação: código e telefone vão sempre como parâmetros ($1, $2).
const FIND_BY_CODE_AND_PHONE = `
  SELECT b.id, b.code, b.court_id, c.name AS court_name, b.starts_at, b.ends_at,
    b.customer_name, b.customer_phone, b.status, b.needs_relocation, b.relocation_reason,
    b.cancelled_by, b.cancellation_reason, b.created_at
  FROM bookings b
  JOIN courts c ON c.id = b.court_id
  WHERE b.code = $1 AND b.customer_phone = $2`;

// Trava a linha da reserva até o fim da transação, para cancelar ou remarcar com segurança.
const FIND_BY_CODE_AND_PHONE_FOR_UPDATE = `
  SELECT b.id, b.code, b.court_id, c.name AS court_name, b.starts_at, b.ends_at,
    b.customer_name, b.customer_phone, b.status, b.needs_relocation, b.relocation_reason,
    b.cancelled_by, b.cancellation_reason, b.created_at
  FROM bookings b
  JOIN courts c ON c.id = b.court_id
  WHERE b.code = $1 AND b.customer_phone = $2
  FOR UPDATE OF b`;

export function mapBookingRow(row: BookingDbRow): Booking {
  return {
    id: Number(row.id),
    code: row.code,
    courtId: Number(row.court_id),
    courtName: row.court_name,
    startsAt: row.starts_at.toISOString(),
    endsAt: row.ends_at.toISOString(),
    customerName: row.customer_name,
    customerPhone: row.customer_phone,
    status: row.status,
    needsRelocation: row.needs_relocation,
    relocationReason: row.relocation_reason,
    cancelledBy: row.cancelled_by,
    cancellationReason: row.cancellation_reason,
    createdAt: row.created_at.toISOString(),
  };
}

export class BookingsRepository {
  constructor(private readonly db: Queryable) {}

  /**
   * Trava, até o fim da transação, quem tenta reservar a mesma quadra e horário (D16).
   * Só funciona com `db` sendo o client de uma transação.
   */
  async lockSlot(courtId: number, startsAt: string): Promise<void> {
    await this.db.query('SELECT pg_advisory_xact_lock(hashtextextended($1, 0))', [
      `booking-slot:${courtId}:${new Date(startsAt).toISOString()}`,
    ]);
  }

  /** Trava, até o fim da transação, quem tenta reservar com o mesmo telefone no mesmo dia (RF03). */
  async lockCustomerDay(customerPhone: string, gameDate: string): Promise<void> {
    await this.db.query('SELECT pg_advisory_xact_lock(hashtextextended($1, 0))', [
      `booking-customer-day:${customerPhone}:${gameDate}`,
    ]);
  }

  /** `exceptBookingId` deixa a própria reserva fora da conta ao remarcar dentro do mesmo dia. */
  async countConfirmedOnGameDate(
    customerPhone: string,
    gameDate: string,
    exceptBookingId: number | null = null,
  ): Promise<number> {
    const { rows } = await this.db.query<{ total: string }>(
      `SELECT count(*) AS total
       FROM bookings
       WHERE customer_phone = $1 AND game_date = $2::date AND status = 'confirmed'
         AND ($3::bigint IS NULL OR id <> $3::bigint)`,
      [customerPhone, gameDate, exceptBookingId],
    );
    return Number(rows[0]?.total ?? 0);
  }

  async findByCodeAndPhone(
    code: string,
    customerPhone: string,
    options: { forUpdate?: boolean } = {},
  ): Promise<Booking | null> {
    const sql = options.forUpdate ? FIND_BY_CODE_AND_PHONE_FOR_UPDATE : FIND_BY_CODE_AND_PHONE;
    const { rows } = await this.db.query<BookingDbRow>(sql, [code, customerPhone]);
    return rows[0] ? mapBookingRow(rows[0]) : null;
  }

  async cancelByCustomer(bookingId: number): Promise<Booking> {
    const { rows } = await this.db.query<BookingDbRow>(
      `WITH updated AS (
         UPDATE bookings
         SET status = 'cancelled', cancelled_at = now(), cancelled_by = 'customer'
         WHERE id = $1
         RETURNING *
       )
       SELECT ${BOOKING_COLUMNS} FROM updated b JOIN courts c ON c.id = b.court_id`,
      [bookingId],
    );
    return mapBookingRow(rows[0]!);
  }

  /** Muda quadra e horário mantendo o código; a reserva deixa de precisar de realocação. */
  async moveTo(bookingId: number, courtId: number, startsAt: string): Promise<Booking> {
    const { rows } = await this.db.query<BookingDbRow>(
      `WITH updated AS (
         UPDATE bookings
         SET court_id = $2, starts_at = $3::timestamptz,
             ends_at = $3::timestamptz + interval '1 hour', needs_relocation = false
         WHERE id = $1
         RETURNING *
       )
       SELECT ${BOOKING_COLUMNS} FROM updated b JOIN courts c ON c.id = b.court_id`,
      [bookingId, courtId, startsAt],
    );
    return mapBookingRow(rows[0]!);
  }

  /** Devolve `null` quando o código já existe, para o serviço tentar outro. */
  async insert(data: NewBooking): Promise<Booking | null> {
    const { rows } = await this.db.query<BookingDbRow>(
      `WITH inserted AS (
         INSERT INTO bookings (court_id, starts_at, ends_at, customer_name, customer_phone, code)
         VALUES ($1, $2::timestamptz, $2::timestamptz + interval '1 hour', $3, $4, $5)
         ON CONFLICT ON CONSTRAINT bookings_code_key DO NOTHING
         RETURNING *
       )
       SELECT ${BOOKING_COLUMNS}
       FROM inserted b
       JOIN courts c ON c.id = b.court_id`,
      [data.courtId, data.startsAt, data.customerName, data.customerPhone, data.code],
    );
    return rows[0] ? mapBookingRow(rows[0]) : null;
  }
}
