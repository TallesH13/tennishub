import type pg from 'pg';

export async function resetData(pool: pg.Pool): Promise<void> {
  await pool.query(
    'TRUNCATE bookings, schedule_blocks, availability_rules, courts, owners RESTART IDENTITY CASCADE',
  );
}

export async function createCourt(pool: pg.Pool, name: string): Promise<number> {
  const { rows } = await pool.query<{ id: string }>(
    'INSERT INTO courts (name) VALUES ($1) RETURNING id',
    [name],
  );
  return Number(rows[0]!.id);
}

export type BookingRow = {
  courtId: number;
  startsAt: string;
  endsAt?: string;
  name?: string;
  phone?: string;
  code: string;
};

/** Insere uma reserva direto no banco. `endsAt` padrão: início + 1 hora. */
export async function insertBooking(db: Pick<pg.Pool, 'query'>, row: BookingRow): Promise<void> {
  await db.query(
    `INSERT INTO bookings (court_id, starts_at, ends_at, customer_name, customer_phone, code)
     VALUES ($1, $2::timestamptz, COALESCE($3::timestamptz, $2::timestamptz + interval '1 hour'), $4, $5, $6)`,
    [
      row.courtId,
      row.startsAt,
      row.endsAt ?? null,
      row.name ?? 'Ana Souza',
      row.phone ?? '31999990000',
      row.code,
    ],
  );
}

/** Captura o erro do PostgreSQL para conferir o SQLSTATE e o nome da restrição. */
export async function pgError(
  promise: Promise<unknown>,
): Promise<{ code?: string; constraint?: string }> {
  try {
    await promise;
  } catch (error) {
    const { code, constraint } = error as { code?: string; constraint?: string };
    return { code, constraint };
  }
  throw new Error('Era esperado um erro do banco, mas a operação foi aceita.');
}

export const PG = {
  uniqueViolation: '23505',
  checkViolation: '23514',
  foreignKeyViolation: '23503',
  exclusionViolation: '23P01',
} as const;
