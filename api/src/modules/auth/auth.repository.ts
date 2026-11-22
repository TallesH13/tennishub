import type { Queryable } from '../../db/pool.js';

export type OwnerRecord = {
  id: number;
  name: string;
  email: string;
  passwordHash: string;
};

export type PublicOwner = {
  id: number;
  name: string;
  email: string;
};

type OwnerDbRow = {
  id: string;
  name: string;
  email: string;
  password_hash: string;
};

export class AuthRepository {
  constructor(private readonly db: Queryable) {}

  async findByEmail(email: string): Promise<OwnerRecord | null> {
    const { rows } = await this.db.query<OwnerDbRow>(
      `SELECT id, name, email, password_hash
       FROM owners
       WHERE lower(email) = lower($1)
       LIMIT 1`,
      [email],
    );

    const row = rows[0];
    if (!row) return null;

    return {
      id: Number(row.id),
      name: row.name,
      email: row.email,
      passwordHash: row.password_hash,
    };
  }

  async findById(id: number): Promise<PublicOwner | null> {
    const { rows } = await this.db.query<Omit<OwnerDbRow, 'password_hash'>>(
      `SELECT id, name, email
       FROM owners
       WHERE id = $1
       LIMIT 1`,
      [id],
    );

    const row = rows[0];
    if (!row) return null;

    return {
      id: Number(row.id),
      name: row.name,
      email: row.email,
    };
  }
}
