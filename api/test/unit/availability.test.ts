import { describe, expect, it } from 'vitest';
import { buildApp } from '../../src/app.js';
import { isWithinBookingWindow } from '../../src/modules/availability/availability.service.js';
import { addDaysToIsoDate, isValidIsoDate } from '../../src/shared/dates.js';

describe('datas da consulta pública', () => {
  it.each([
    ['2030-01-31', 1, '2030-02-01'],
    ['2030-12-31', 1, '2031-01-01'],
    ['2028-02-28', 1, '2028-02-29'],
    ['2030-01-10', 30, '2030-02-09'],
  ])('%s + %i dia(s) = %s', (date, days, expected) => {
    expect(addDaysToIsoDate(date, days)).toBe(expected);
  });

  it.each([['2030-02-30'], ['2030-13-01'], ['10/01/2030'], ['2030-1-5'], ['']])(
    'rejeita data inválida: "%s"',
    (value) => {
      expect(isValidIsoDate(value)).toBe(false);
    },
  );

  it('aceita de hoje até o último dia da janela (D08)', () => {
    expect(isWithinBookingWindow('2030-01-10', '2030-01-10', 30)).toBe(true);
    expect(isWithinBookingWindow('2030-02-09', '2030-01-10', 30)).toBe(true);
    expect(isWithinBookingWindow('2030-02-10', '2030-01-10', 30)).toBe(false);
    expect(isWithinBookingWindow('2030-01-09', '2030-01-10', 30)).toBe(false);
  });
});

describe('validação das rotas públicas de disponibilidade', () => {
  const unusedDb = {
    query: async () => {
      throw new Error('a validação deve falhar antes de consultar o banco');
    },
  };

  it.each([
    ['/api/availability'],
    ['/api/availability?date=2030-02-30'],
    ['/api/courts?date=amanha'],
    ['/api/courts/1/slots'],
    ['/api/courts/1/slots?date=2030-1-5'],
    ['/api/courts/abc/slots?date=2030-01-10'],
  ])('GET %s responde 400', async (url) => {
    const app = await buildApp({ db: unusedDb as never, sessionSecret: 'x'.repeat(32) });
    const response = await app.inject({ method: 'GET', url });

    expect(response.statusCode).toBe(400);
    expect(response.json().error.code).toBe('VALIDATION_ERROR');
    await app.close();
  });
});
