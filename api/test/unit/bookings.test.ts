import { describe, expect, it } from 'vitest';
import { buildApp } from '../../src/app.js';
import { generateBookingCode } from '../../src/modules/bookings/booking-code.js';
import { createBookingBodySchema } from '../../src/modules/bookings/bookings.routes.js';

const valid = {
  courtId: 1,
  startsAt: '2030-01-10T19:00:00-03:00',
  customerName: 'Ana Paula Ribeiro',
  customerPhone: '31987654321',
};

describe('código da reserva (D06)', () => {
  it('gera 1.000 códigos de 8 caracteres sem 0, O, 1 e I, todos diferentes', () => {
    const codes = Array.from({ length: 1000 }, () => generateBookingCode());

    for (const code of codes) expect(code).toMatch(/^[A-HJ-NP-Z2-9]{8}$/);
    expect(new Set(codes).size).toBe(1000);
  });
});

describe('validação do pedido de reserva', () => {
  it('normaliza o nome e guarda só os dígitos do telefone (D07)', () => {
    const parsed = createBookingBodySchema.parse({
      ...valid,
      courtId: '1',
      customerName: '  Ana   Paula  ',
      customerPhone: '(31) 98765-4321',
    });

    expect(parsed).toMatchObject({
      courtId: 1,
      customerName: 'Ana Paula',
      customerPhone: '31987654321',
    });
  });

  it.each([['3133334444'], ['31987654321'], ['(11) 3333-4444']])(
    'aceita telefone brasileiro: %s',
    (customerPhone) => {
      expect(createBookingBodySchema.safeParse({ ...valid, customerPhone }).success).toBe(true);
    },
  );

  it.each([['9876543'], ['01987654321'], ['31887654321'], ['3113334444'], ['319876543210']])(
    'recusa telefone inválido: %s',
    (customerPhone) => {
      const result = createBookingBodySchema.safeParse({ ...valid, customerPhone });
      expect(result.success).toBe(false);
      expect(result.error?.issues[0]?.path).toEqual(['customerPhone']);
    },
  );

  it.each([['Ana'], ['Anastácia'], ['A B'], ['Ana 123'], ['x'.repeat(60) + ' ' + 'y'.repeat(60)]])(
    'recusa nome sem nome e sobrenome ou fora de 5 a 100 caracteres: %s',
    (customerName) => {
      const result = createBookingBodySchema.safeParse({ ...valid, customerName });
      expect(result.success).toBe(false);
      expect(result.error?.issues[0]?.path).toEqual(['customerName']);
    },
  );

  it.each([["D'Ávila Souza"], ['João da Silva-Neto'], ['Zé Lu']])('aceita nome: %s', (name) => {
    expect(createBookingBodySchema.safeParse({ ...valid, customerName: name }).success).toBe(true);
  });

  it('exige início em hora cheia', () => {
    const result = createBookingBodySchema.safeParse({
      ...valid,
      startsAt: '2030-01-10T19:30:00-03:00',
    });
    expect(result.error?.issues.map((issue) => issue.message)).toEqual([
      'A reserva deve começar em hora cheia.',
    ]);
  });

  it('dá um único erro para horário fora do formato', () => {
    const result = createBookingBodySchema.safeParse({ ...valid, startsAt: '10/01/2030 19h' });
    expect(result.error?.issues).toHaveLength(1);
  });
});

describe('POST /api/bookings sem banco', () => {
  it('responde 422 com o erro de cada campo antes de consultar o banco', async () => {
    const app = await buildApp({
      db: {
        query: async () => {
          throw new Error('a validação deve falhar antes de consultar o banco');
        },
      } as never,
      sessionSecret: 'x'.repeat(32),
    });

    const response = await app.inject({ method: 'POST', url: '/api/bookings', payload: {} });

    expect(response.statusCode).toBe(422);
    expect(response.json().error.code).toBe('VALIDATION_ERROR');
    const fields = (response.json().error.details as { field: string }[]).map((d) => d.field);
    expect(fields.sort()).toEqual(['courtId', 'customerName', 'customerPhone', 'startsAt']);
    await app.close();
  });
});
