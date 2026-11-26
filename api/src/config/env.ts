import { z } from 'zod';
import { describeConnection } from '../db/connection.js';

function isPostgresUrl(value: string): boolean {
  return /^postgres(ql)?:\/\//.test(value) && URL.canParse(value);
}

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  HOST: z.string().min(1).default('127.0.0.1'),
  PORT: z.coerce.number().int().min(1).max(65535).default(3000),
  LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace', 'silent']).default('info'),
  DATABASE_URL: z
    .string()
    .min(1, 'DATABASE_URL é obrigatória')
    .refine(isPostgresUrl, 'DATABASE_URL deve ser uma URL postgres://usuario:senha@host/banco'),
  // Vazia vira undefined: as migrations caem na DATABASE_URL.
  DATABASE_URL_DIRECT: z
    .string()
    .optional()
    .transform((value) => (value ? value : undefined))
    .refine(
      (value) => value === undefined || isPostgresUrl(value),
      'DATABASE_URL_DIRECT deve ser uma URL postgres://usuario:senha@host/banco',
    ),
  SESSION_SECRET: z.string().min(32, 'SESSION_SECRET deve ter pelo menos 32 caracteres'),
  BOOKING_WINDOW_DAYS: z.coerce
    .number()
    .int('BOOKING_WINDOW_DAYS deve ser um número inteiro de dias')
    .min(1, 'BOOKING_WINDOW_DAYS deve ser de pelo menos 1 dia')
    .max(365, 'BOOKING_WINDOW_DAYS deve ser de no máximo 365 dias')
    .default(30),
});

export type AppConfig = {
  nodeEnv: 'development' | 'test' | 'production';
  host: string;
  port: number;
  logLevel: string;
  databaseUrl: string;
  databaseUrlDirect: string;
  sessionSecret: string;
  bookingWindowDays: number;
};

export class ConfigError extends Error {
  constructor(public readonly problems: string[]) {
    super(`Configuração inválida:\n- ${problems.join('\n- ')}`);
    this.name = 'ConfigError';
  }
}

/**
 * No Neon, a API usa o pooler e as migrations usam a conexão direta (D16).
 * Pega as trocas mais comuns antes que virem erro difícil de entender.
 */
function checkNeonUrls(databaseUrl: string, directUrl: string | undefined): string[] {
  const problems: string[] = [];
  const app = describeConnection(databaseUrl);

  if (app.isPooler && !directUrl) {
    problems.push(
      'DATABASE_URL_DIRECT: obrigatória quando a DATABASE_URL usa o pooler do Neon (as migrations precisam da conexão direta)',
    );
  }
  if (directUrl && describeConnection(directUrl).isPooler) {
    problems.push('DATABASE_URL_DIRECT: use a conexão direta do Neon, sem "-pooler" no host');
  }
  return problems;
}

/** Lê e valida as variáveis de ambiente. Falha cedo, listando tudo que está errado. */
export function loadConfig(env: NodeJS.ProcessEnv = process.env): AppConfig {
  const parsed = envSchema.safeParse(env);
  if (!parsed.success) {
    throw new ConfigError(
      parsed.error.issues.map((issue) => `${issue.path.join('.')}: ${issue.message}`),
    );
  }

  const data = parsed.data;
  const neonProblems = checkNeonUrls(data.DATABASE_URL, data.DATABASE_URL_DIRECT);
  if (neonProblems.length > 0) throw new ConfigError(neonProblems);

  return {
    nodeEnv: data.NODE_ENV,
    host: data.HOST,
    port: data.PORT,
    logLevel: data.LOG_LEVEL,
    databaseUrl: data.DATABASE_URL,
    databaseUrlDirect: data.DATABASE_URL_DIRECT ?? data.DATABASE_URL,
    sessionSecret: data.SESSION_SECRET,
    bookingWindowDays: data.BOOKING_WINDOW_DAYS,
  };
}

/** Carrega um arquivo .env se ele existir (Node 24 tem suporte nativo). */
export function loadEnvFile(path = '.env'): void {
  try {
    process.loadEnvFile(path);
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error;
  }
}
