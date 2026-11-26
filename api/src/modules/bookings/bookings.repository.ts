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
