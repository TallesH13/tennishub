import Fastify from 'fastify';
import { describe, expect, it } from 'vitest';
import { z } from 'zod';
import { buildApp } from '../../src/app.js';
import { AppError, registerErrorHandling } from '../../src/shared/errors.js';

async function appWithFailingRoutes() {
  const app = Fastify();
  registerErrorHandling(app);
  app.get('/business', async () => {
    throw new AppError(409, 'SLOT_TAKEN', 'Horário indisponível.');
  });
  app.get('/validation', async () => {
    z.object({ phone: z.string().min(10, 'Telefone inválido') }).parse({ phone: '123' });
  });
  app.get('/boom', async () => {
    throw new Error('detalhe interno: SELECT * FROM segredo');
  });
  app.post('/echo', async (request) => request.body);
  return app;
}

describe('tratamento centralizado de erros', () => {
  it('devolve erro de negócio com status, código e mensagem', async () => {
    const app = await appWithFailingRoutes();
    const response = await app.inject({ method: 'GET', url: '/business' });

    expect(response.statusCode).toBe(409);
    expect(response.json()).toEqual({
      error: { code: 'SLOT_TAKEN', message: 'Horário indisponível.' },
    });
  });

  it('converte erro de validação do Zod em 422 com erros por campo', async () => {
    const app = await appWithFailingRoutes();
    const response = await app.inject({ method: 'GET', url: '/validation' });

    expect(response.statusCode).toBe(422);
    expect(response.json()).toEqual({
      error: {
        code: 'VALIDATION_ERROR',
        message: 'Dados inválidos.',
        details: [{ field: 'phone', message: 'Telefone inválido' }],
      },
    });
  });

  it('esconde detalhes internos em erros inesperados', async () => {
    const app = await appWithFailingRoutes();
    const response = await app.inject({ method: 'GET', url: '/boom' });

    expect(response.statusCode).toBe(500);
    expect(response.json()).toEqual({
      error: { code: 'INTERNAL_ERROR', message: 'Erro interno do servidor.' },
    });
    expect(response.body).not.toContain('segredo');
  });

  it('mantém o status 4xx de erros do Fastify, como JSON malformado', async () => {
    const app = await appWithFailingRoutes();
    const response = await app.inject({
      method: 'POST',
      url: '/echo',
      headers: { 'content-type': 'application/json' },
      payload: '{ invalido',
    });

    expect(response.statusCode).toBe(400);
    expect(response.json().error.code).toBeTypeOf('string');
  });

  it('responde 404 em JSON para rota inexistente', async () => {
    const app = await buildApp({ db: { query: async () => ({}) as never } });
    const response = await app.inject({ method: 'GET', url: '/api/nao-existe' });

    expect(response.statusCode).toBe(404);
    expect(response.json().error.code).toBe('NOT_FOUND');
  });
});

describe('GET /api/health sem banco', () => {
  it('responde 503 quando o banco não responde', async () => {
    const app = await buildApp({
      db: {
        query: async () => {
          throw new Error('connection refused');
        },
      } as never,
    });
    const response = await app.inject({ method: 'GET', url: '/api/health' });

    expect(response.statusCode).toBe(503);
    expect(response.json()).toEqual({
      error: { code: 'DATABASE_UNAVAILABLE', message: 'Banco de dados indisponível.' },
    });
  });
});
