import type pg from 'pg';

const NEON_HOST = /\.neon\.tech$/i;
// No Neon, o host do pooler (PgBouncer) tem o sufixo "-pooler" no id do endpoint.
const NEON_POOLER_HOST = /-pooler\./i;

export type ConnectionInfo = {
  host: string;
  database: string;
  isNeon: boolean;
  isPooler: boolean;
};

export function describeConnection(url: string): ConnectionInfo {
  const parsed = new URL(url);
  return {
    host: parsed.hostname,
    database: decodeURIComponent(parsed.pathname.replace(/^\//, '')),
    isNeon: NEON_HOST.test(parsed.hostname),
    isPooler: NEON_POOLER_HOST.test(parsed.hostname),
  };
}

/**
 * Monta a configuração do `pg` a partir da string de conexão.
 *
 * O Neon exige TLS. A string copiada do painel traz `sslmode=require` e
 * `channel_binding=require`; o `pg` interpreta esses parâmetros de um jeito
 * próprio (e avisa no console), então eles saem da URL e o TLS é ligado
 * explicitamente, validando o certificado do Neon.
 */
export function connectionConfig(url: string): pg.ClientConfig {
  const parsed = new URL(url);
  const sslmode = parsed.searchParams.get('sslmode');
  parsed.searchParams.delete('sslmode');
  parsed.searchParams.delete('channel_binding');

  const { isNeon } = describeConnection(url);
  const useSsl = isNeon || (sslmode !== null && sslmode !== 'disable');

  return {
    connectionString: parsed.toString(),
    ssl: useSsl ? { rejectUnauthorized: true } : false,
  };
}
