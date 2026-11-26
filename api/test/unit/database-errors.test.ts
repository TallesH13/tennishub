import Fastify from 'fastify';
import { describe, expect, it } from 'vitest';
import { mapDatabaseError, registerErrorHandling } from '../../src/shared/errors.js';

const slotViolation = Object.assign(new Error('duplicate key value violates unique constraint'), {
  code: '23505',
  constraint: 'bookings_court_slot_confirmed_key',
});

describe('tradução de erros do banco (RNF01)', () => {
  it('converte a violação do índice de horário único em SLOT_UNAVAILABLE', () => {
    expect(mapDatabaseError(slotViolation)).toMatchObject({
      statusCode: 409,
      code: 'SLOT_UNAVAILABLE',
    });
  });

  it('ignora outras restrições e outros erros', () => {
    expect(mapDatabaseError({ code: '23505', constraint: 'owners_email_key' })).toBeNull();
    expect(mapDatabaseError({ code: '23514', constraint: 'bookings_one_hour' })).toBeNull();
    expect(mapDatabaseError(new Error('qualquer'))).toBeNull();
    expect(mapDatabaseError(undefined)).toBeNull();
  });

  it('qualquer rota que esbarre no índice responde 409, e não 500', async () => {
    const app = Fastify();
    registerErrorHandling(app);
    app.post('/qualquer-rota', async () => {
      throw slotViolation;
    });

    const response = await app.inject({ method: 'POST', url: '/qualquer-rota' });

    expect(response.statusCode).toBe(409);
    expect(response.json().error.code).toBe('SLOT_UNAVAILABLE');
    expect(response.body).not.toContain('duplicate key');
    await app.close();
  });
});
