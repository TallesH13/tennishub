import { randomInt } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import bcrypt from 'bcryptjs';
import { z } from 'zod';
import { loadEnvFile } from '../config/env.js';
import { createPool, withTransaction } from './pool.js';
import type pg from 'pg';

const BCRYPT_COST = 12;

/** Alfabeto do código da reserva (D06): sem 0, O, 1 e I. */
const CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

const ownerSchema = z.object({
  OWNER_NAME: z.string().trim().min(2, 'OWNER_NAME precisa ter pelo menos 2 caracteres'),
  OWNER_EMAIL: z.email('OWNER_EMAIL inválido'),
  OWNER_PASSWORD: z.string().min(8, 'OWNER_PASSWORD precisa ter pelo menos 8 caracteres'),
});

export type OwnerInput = { name: string; email: string; password: string };

export type SeedResult = {
  ownerId: number;
  courtsCreated: number;
  bookingsCreated: number;
};

export function ownerFromEnv(env: NodeJS.ProcessEnv = process.env): OwnerInput {
  const parsed = ownerSchema.safeParse(env);
  if (!parsed.success) {
    const problems = parsed.error.issues
      .map((issue) => `- ${issue.path.join('.')}: ${issue.message}`)
      .join('\n');
    throw new Error(`Defina o proprietário no .env antes de rodar o seed:\n${problems}`);
  }
  return {
    name: parsed.data.OWNER_NAME,
    email: parsed.data.OWNER_EMAIL,
    password: parsed.data.OWNER_PASSWORD,
  };
}

function sampleCode(): string {
  let code = '';
  for (let i = 0; i < 8; i++) code += CODE_ALPHABET[randomInt(CODE_ALPHABET.length)];
  return code;
}

/**
 * Cria (ou atualiza) o proprietário e, se o banco estiver vazio, quadras, horários e
 * reservas de exemplo. Pode rodar várias vezes sem duplicar dados.
 */
export async function seed(pool: pg.Pool, owner: OwnerInput): Promise<SeedResult> {
  const passwordHash = await bcrypt.hash(owner.password, BCRYPT_COST);

  return withTransaction(pool, async (client) => {
    const ownerRow = await client.query<{ id: string }>(
      `INSERT INTO owners (name, email, password_hash)
       VALUES ($1, $2, $3)
       ON CONFLICT ((lower(email)))
       DO UPDATE SET name = EXCLUDED.name, password_hash = EXCLUDED.password_hash
       RETURNING id`,
      [owner.name, owner.email, passwordHash],
    );
    const ownerId = Number(ownerRow.rows[0]!.id);

    const { rows: courtCount } = await client.query<{ count: string }>(
      'SELECT count(*) FROM courts',
    );
    if (Number(courtCount[0]!.count) > 0) {
      return { ownerId, courtsCreated: 0, bookingsCreated: 0 };
    }

    const { rows: courts } = await client.query<{ id: string }>(
      `INSERT INTO courts (name, hourly_price)
       VALUES ('Quadra 1 (saibro)', 80.00), ('Quadra 2 (saibro)', 80.00), ('Quadra 3 (rápida)', 100.00)
       RETURNING id`,
    );

    // Segunda a sexta 8h às 22h; sábado e domingo 8h às 18h; vigência a partir de hoje.
    for (const court of courts) {
      await client.query(
        `INSERT INTO availability_rules (court_id, weekday, start_hour, end_hour, valid_from)
         SELECT $1, weekday,
                8,
                CASE WHEN weekday IN (0, 6) THEN 18 ELSE 22 END,
                (now() AT TIME ZONE 'America/Sao_Paulo')::date
         FROM generate_series(0, 6) AS weekday`,
        [court.id],
      );
    }

    // Reservas fictícias para a demonstração (amanhã às 10h e às 19h, horário de São Paulo).
    const tomorrowAt = `((now() AT TIME ZONE 'America/Sao_Paulo')::date + 1)::timestamp`;
    const samples = [
      { court: courts[0]!.id, hour: 10, name: 'Cliente Exemplo Um', phone: '31900000001' },
      { court: courts[1]!.id, hour: 19, name: 'Cliente Exemplo Dois', phone: '31900000002' },
    ];
    for (const sample of samples) {
      await client.query(
        `INSERT INTO bookings (court_id, starts_at, ends_at, customer_name, customer_phone, code)
         VALUES ($1,
                 (${tomorrowAt} + make_interval(hours => $2)) AT TIME ZONE 'America/Sao_Paulo',
                 (${tomorrowAt} + make_interval(hours => $2 + 1)) AT TIME ZONE 'America/Sao_Paulo',
                 $3, $4, $5)`,
        [sample.court, sample.hour, sample.name, sample.phone, sampleCode()],
      );
    }

    return { ownerId, courtsCreated: courts.length, bookingsCreated: samples.length };
  });
}

// Execução pela linha de comando: `npm run seed`.
if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  loadEnvFile();
  const databaseUrl = process.env.DATABASE_URL_DIRECT || process.env.DATABASE_URL;
  if (!databaseUrl) {
    console.error('Defina DATABASE_URL para rodar o seed.');
    process.exit(1);
  }

  const pool = createPool(databaseUrl);
  try {
    const result = await seed(pool, ownerFromEnv());
    console.log(
      `Seed concluído: proprietário #${result.ownerId}, ${result.courtsCreated} quadra(s) e ${result.bookingsCreated} reserva(s) de exemplo criadas.`,
    );
  } catch (error: unknown) {
    console.error(error instanceof Error ? error.message : error);
    process.exitCode = 1;
  } finally {
    await pool.end();
  }
}
