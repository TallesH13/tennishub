import { describe, expect, it } from 'vitest';
import {
  isSlotCoveredByBlocks,
  isSlotCoveredByRanges,
  saoPauloHourToUtcIso,
  saoPauloWeekdayOfDate,
  validateNonOverlappingRanges,
} from '../../src/modules/schedule/schedule.service.js';
import { ConflictError } from '../../src/shared/errors.js';

describe('Schedule helpers (unidade)', () => {
  it('aceita faixas válidas e adjacentes no mesmo dia da semana', () => {
    const result = validateNonOverlappingRanges([
      { weekday: 1, startHour: 14, endHour: 22 },
      { weekday: 1, startHour: 8, endHour: 12 },
      { weekday: 1, startHour: 12, endHour: 14 },
      { weekday: 6, startHour: 8, endHour: 18 },
    ]);

    expect(result).toEqual([
      { weekday: 1, startHour: 8, endHour: 12 },
      { weekday: 1, startHour: 12, endHour: 14 },
      { weekday: 1, startHour: 14, endHour: 22 },
      { weekday: 6, startHour: 8, endHour: 18 },
    ]);
  });

  it('rejeita faixas sobrepostas no mesmo dia da semana', () => {
    expect(() =>
      validateNonOverlappingRanges([
        { weekday: 3, startHour: 8, endHour: 14 },
        { weekday: 3, startHour: 13, endHour: 18 },
      ]),
    ).toThrow(ConflictError);
  });

  it('converte data e hora de São Paulo (UTC-3) para ISO UTC corretamente', () => {
    // 2026-12-02 é quarta-feira (weekday = 3)
    expect(saoPauloWeekdayOfDate('2026-12-02')).toBe(3);
    expect(saoPauloHourToUtcIso('2026-12-02', 8)).toBe('2026-12-02T11:00:00.000Z');
    expect(saoPauloHourToUtcIso('2026-12-02', 22)).toBe('2026-12-03T01:00:00.000Z');
  });

  it('verifica cobertura de faixa semanal e de bloqueio pontual', () => {
    const ranges = [{ weekday: 3, startHour: 8, endHour: 18 }];
    expect(isSlotCoveredByRanges(ranges, 3, 8)).toBe(true);
    expect(isSlotCoveredByRanges(ranges, 3, 17)).toBe(true);
    expect(isSlotCoveredByRanges(ranges, 3, 18)).toBe(false);
    expect(isSlotCoveredByRanges(ranges, 4, 10)).toBe(false);

    const blocks = [
      {
        id: 1,
        courtId: 1,
        startsAt: '2026-12-02T13:00:00.000Z', // 10h SP
        endsAt: '2026-12-02T15:00:00.000Z', // 12h SP
        reason: 'Manutenção',
      },
    ];

    // 10h-11h SP (13h-14h UTC) toca o bloqueio
    expect(
      isSlotCoveredByBlocks(
        Date.parse('2026-12-02T13:00:00.000Z'),
        Date.parse('2026-12-02T14:00:00.000Z'),
        blocks,
      ),
    ).toBe(true);

    // 12h-13h SP (15h-16h UTC) fica logo após o bloqueio
    expect(
      isSlotCoveredByBlocks(
        Date.parse('2026-12-02T15:00:00.000Z'),
        Date.parse('2026-12-02T16:00:00.000Z'),
        blocks,
      ),
    ).toBe(false);
  });
});
