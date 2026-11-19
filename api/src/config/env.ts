import { z } from 'zod';

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  HOST: z.string().min(1).default('127.0.0.1'),
  PORT: z.coerce.number().int().min(1).max(65535).default(3000),
  LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace', 'silent']).default('info'),
  DATABASE_URL: z
    .string()
    .min(1, 'DATABASE_URL é obrigatória')
    .refine(
      (value) => /^postgres(ql)?:\/\//.test(value),
      'DATABASE_URL deve começar com postgres://',
    ),
  // Vazia vira undefined: as migrations caem na DATABASE_URL.
  DATABASE_URL_DIRECT: z
    .string()
    .optional()
    .transform((value) => (value ? value : undefined)),
  SESSION_SECRET: z.string().min(32, 'SESSION_SECRET deve ter pelo menos 32 caracteres'),
});

export type AppConfig = {
  nodeEnv: 'development' | 'test' | 'production';
  host: string;
  port: number;
  logLevel: string;
  databaseUrl: string;
  databaseUrlDirect: string;
  sessionSecret: string;
};

export class ConfigError extends Error {
  constructor(public readonly problems: string[]) {
    super(`Configuração inválida:\n- ${problems.join('\n- ')}`);
    this.name = 'ConfigError';
  }
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
  return {
    nodeEnv: data.NODE_ENV,
    host: data.HOST,
    port: data.PORT,
    logLevel: data.LOG_LEVEL,
    databaseUrl: data.DATABASE_URL,
    databaseUrlDirect: data.DATABASE_URL_DIRECT ?? data.DATABASE_URL,
    sessionSecret: data.SESSION_SECRET,
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
