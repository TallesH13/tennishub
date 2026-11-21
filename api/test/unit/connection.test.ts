import { describe, expect, it } from 'vitest';
import { ConfigError, loadConfig } from '../../src/config/env.js';
import { connectionConfig, describeConnection } from '../../src/db/connection.js';
import { migrate } from '../../src/db/migrate.js';

// Strings no formato que o painel do Neon gera (valores fictícios).
const NEON_POOLER =
  'postgresql://neondb_owner:segredo@ep-cool-river-a1b2c3d4-pooler.sa-east-1.aws.neon.tech/neondb?sslmode=require&channel_binding=require';
const NEON_DIRECT =
  'postgresql://neondb_owner:segredo@ep-cool-river-a1b2c3d4.sa-east-1.aws.neon.tech/neondb?sslmode=require&channel_binding=require';
const LOCAL = 'postgres://postgres:postgres@localhost:5432/tennishub_test';

describe('describeConnection', () => {
  it('reconhece o pooler e a conexão direta do Neon', () => {
    expect(describeConnection(NEON_POOLER)).toMatchObject({
      isNeon: true,
      isPooler: true,
      database: 'neondb',
    });
    expect(describeConnection(NEON_DIRECT)).toMatchObject({ isNeon: true, isPooler: false });
  });

  it('trata o PostgreSQL local como não-Neon', () => {
    expect(describeConnection(LOCAL)).toMatchObject({
      isNeon: false,
      isPooler: false,
      host: 'localhost',
    });
  });
});

describe('connectionConfig', () => {
  it('liga o TLS validando o certificado no Neon e tira os parâmetros sslmode/channel_binding', () => {
    const config = connectionConfig(NEON_POOLER);

    expect(config.ssl).toEqual({ rejectUnauthorized: true });
    expect(config.connectionString).not.toContain('sslmode');
    expect(config.connectionString).not.toContain('channel_binding');
    expect(config.connectionString).toContain('-pooler.sa-east-1.aws.neon.tech/neondb');
  });

  it('mantém o TLS no Neon mesmo sem sslmode na URL', () => {
    expect(connectionConfig(NEON_DIRECT.split('?')[0]!).ssl).toEqual({ rejectUnauthorized: true });
  });

  it('não usa TLS no PostgreSQL local', () => {
    expect(connectionConfig(LOCAL)).toEqual({ connectionString: LOCAL, ssl: false });
  });
});

describe('loadConfig com Neon', () => {
  const secret = { SESSION_SECRET: 'a'.repeat(32) };

  it('aceita pooler na API e conexão direta nas migrations', () => {
    const config = loadConfig({
      ...secret,
      DATABASE_URL: NEON_POOLER,
      DATABASE_URL_DIRECT: NEON_DIRECT,
    });
    expect(config.databaseUrl).toBe(NEON_POOLER);
    expect(config.databaseUrlDirect).toBe(NEON_DIRECT);
  });

  it('exige a conexão direta quando a API usa o pooler', () => {
    expect(() => loadConfig({ ...secret, DATABASE_URL: NEON_POOLER })).toThrow(ConfigError);
  });

  it('recusa o pooler como conexão direta', () => {
    expect(() =>
      loadConfig({ ...secret, DATABASE_URL: NEON_POOLER, DATABASE_URL_DIRECT: NEON_POOLER }),
    ).toThrow(/sem "-pooler"/);
  });
});

describe('migrate', () => {
  it('recusa rodar migrations pelo pooler do Neon, antes de conectar', async () => {
    await expect(migrate({ databaseUrl: NEON_POOLER })).rejects.toThrow(/pooler do Neon/);
  });
});
