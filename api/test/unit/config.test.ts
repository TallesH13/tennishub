import { describe, expect, it } from 'vitest';
import { ConfigError, loadConfig } from '../../src/config/env.js';

const validEnv = {
  DATABASE_URL: 'postgres://user:pass@localhost:5432/tennishub',
  SESSION_SECRET: 'a'.repeat(32),
};

describe('loadConfig', () => {
  it('aplica os valores padrão e usa a DATABASE_URL nas migrations quando não há conexão direta', () => {
    const config = loadConfig(validEnv);

    expect(config).toMatchObject({
      nodeEnv: 'development',
      host: '127.0.0.1',
      port: 3000,
      databaseUrl: validEnv.DATABASE_URL,
      databaseUrlDirect: validEnv.DATABASE_URL,
    });
  });

  it('usa a DATABASE_URL_DIRECT nas migrations quando informada', () => {
    const direct = 'postgres://user:pass@direct-host:5432/tennishub';
    const config = loadConfig({ ...validEnv, DATABASE_URL_DIRECT: direct, PORT: '8080' });

    expect(config.databaseUrlDirect).toBe(direct);
    expect(config.port).toBe(8080);
  });

  it('trata DATABASE_URL_DIRECT vazia como ausente', () => {
    const config = loadConfig({ ...validEnv, DATABASE_URL_DIRECT: '' });
    expect(config.databaseUrlDirect).toBe(validEnv.DATABASE_URL);
  });

  it('lista todos os problemas de uma vez', () => {
    try {
      loadConfig({ DATABASE_URL: 'mysql://x', SESSION_SECRET: 'curto' });
      expect.fail('deveria ter lançado ConfigError');
    } catch (error) {
      expect(error).toBeInstanceOf(ConfigError);
      const problems = (error as ConfigError).problems;
      expect(problems.some((p) => p.startsWith('DATABASE_URL'))).toBe(true);
      expect(problems.some((p) => p.startsWith('SESSION_SECRET'))).toBe(true);
    }
  });
});
