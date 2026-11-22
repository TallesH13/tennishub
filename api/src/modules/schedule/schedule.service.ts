import type pg from 'pg';
import { withTransaction } from '../../db/pool.js';
import { ConflictError, NotFoundError } from '../../shared/errors.js';
import type { CourtsRepository } from '../courts/courts.repository.js';
import {
  ScheduleRepository,
  type CourtSchedule,
  type FlaggedBooking,
  type OpeningRange,
  type ScheduleBlock,
} from './schedule.repository.js';

export type SaveScheduleInput = {
  validFrom: string;
  ranges: OpeningRange[];
};

export type SaveScheduleResult = {
  openingHours: CourtSchedule;
  schedule: CourtSchedule;
  affectedBookings: number;
  bookingsNeedingRelocation: FlaggedBooking[];
};

export type CourtSlotStatus = 'free' | 'busy' | 'closed';

export type CourtHourSlot = {
  courtId: number;
  date: string;
  hour: number;
  startsAt: string;
  endsAt: string;
  status: CourtSlotStatus;
};

/** America/Sao_Paulo possui deslocamento fixo UTC-03:00. */
const SAO_PAULO_UTC_OFFSET_HOURS = 3;

export function todayInSaoPaulo(now: Date = new Date()): string {
  const formatter = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'America/Sao_Paulo',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  });
  return formatter.format(now);
}

export function saoPauloWeekdayOfDate(date: string): number {
  const [yearStr, monthStr, dayStr] = date.split('-');
  const utcMidday = new Date(
    Date.UTC(Number(yearStr), Number(monthStr) - 1, Number(dayStr), 12, 0, 0),
  );
  return utcMidday.getUTCDay();
}

export function saoPauloHourToUtcIso(date: string, hour: number): string {
  const [yearStr, monthStr, dayStr] = date.split('-');
  return new Date(
    Date.UTC(
      Number(yearStr),
      Number(monthStr) - 1,
      Number(dayStr),
      hour + SAO_PAULO_UTC_OFFSET_HOURS,
      0,
      0,
      0,
    ),
  ).toISOString();
}

export function validateNonOverlappingRanges(ranges: OpeningRange[]): OpeningRange[] {
  const sorted = [...ranges].sort(
    (a, b) => a.weekday - b.weekday || a.startHour - b.startHour || a.endHour - b.endHour,
  );

  for (let i = 1; i < sorted.length; i++) {
    const previous = sorted[i - 1]!;
    const current = sorted[i]!;
    if (previous.weekday === current.weekday && current.startHour < previous.endHour) {
      throw new ConflictError(
        'SCHEDULE_OVERLAP',
        'Faixas de horário sobrepostas no mesmo dia da semana.',
      );
    }
  }

  return sorted;
}

export function isSlotCoveredByRanges(
  ranges: OpeningRange[],
  weekday: number,
  hour: number,
): boolean {
  return ranges.some(
    (range) => range.weekday === weekday && hour >= range.startHour && hour < range.endHour,
  );
}

export function isSlotCoveredByBlocks(
  slotStartMs: number,
  slotEndMs: number,
  blocks: ScheduleBlock[],
): boolean {
  return blocks.some((block) => {
    const blockStartMs = Date.parse(block.startsAt);
    const blockEndMs = Date.parse(block.endsAt);
    return slotStartMs < blockEndMs && slotEndMs > blockStartMs;
  });
}

export class ScheduleService {
  constructor(
    private readonly pool: pg.Pool,
    private readonly repository: ScheduleRepository,
    private readonly courtsRepository: CourtsRepository,
    private readonly now: () => number = () => Date.now(),
  ) {}

  async getCourtSchedule(
    courtId: number,
    referenceDate?: string,
  ): Promise<{
    openingHours: CourtSchedule | null;
    schedule: CourtSchedule | null;
    blocks: ScheduleBlock[];
  }> {
    const exists = await this.repository.courtExists(courtId);
    if (!exists) {
      throw new NotFoundError('Quadra não encontrada.');
    }

    const targetDate = referenceDate ?? todayInSaoPaulo(new Date(this.now()));
    const schedule = await this.repository.findEffectiveSchedule(courtId, targetDate);
    const blocks = await this.repository.listBlocksByCourt(courtId);

    return {
      openingHours: schedule,
      schedule,
      blocks,
    };
  }

  async saveCourtSchedule(courtId: number, input: SaveScheduleInput): Promise<SaveScheduleResult> {
    const normalizedRanges = validateNonOverlappingRanges(input.ranges);

    return withTransaction(this.pool, async (client) => {
      const txRepo = new ScheduleRepository(client);
      const exists = await txRepo.courtExists(courtId);
      if (!exists) {
        throw new NotFoundError('Quadra não encontrada.');
      }

      await txRepo.replaceScheduleForValidFrom(courtId, input.validFrom, normalizedRanges);

      const nextValidFrom = await txRepo.findNextValidFrom(courtId, input.validFrom);
      const existingBookings = await txRepo.listConfirmedBookingsInEffectiveWindow(
        courtId,
        input.validFrom,
        nextValidFrom,
      );

      const outsideIds: number[] = [];
      const insideIds: number[] = [];
      const bookingsNeedingRelocation: FlaggedBooking[] = [];

      for (const item of existingBookings) {
        const covered = isSlotCoveredByRanges(
          normalizedRanges,
          item.localWeekday,
          item.localStartHour,
        );
        if (covered) {
          insideIds.push(item.booking.id);
        } else {
          outsideIds.push(item.booking.id);
          bookingsNeedingRelocation.push({
            ...item.booking,
            needsRelocation: true,
          });
        }
      }

      await txRepo.updateBookingsNeedsRelocation(outsideIds, true);
      await txRepo.updateBookingsNeedsRelocation(insideIds, false);

      const schedule: CourtSchedule = {
        validFrom: input.validFrom,
        ranges: normalizedRanges,
      };

      return {
        openingHours: schedule,
        schedule,
        affectedBookings: bookingsNeedingRelocation.length,
        bookingsNeedingRelocation,
      };
    });
  }

  async listBlocks(courtId: number): Promise<ScheduleBlock[]> {
    const exists = await this.repository.courtExists(courtId);
    if (!exists) {
      throw new NotFoundError('Quadra não encontrada.');
    }
    return this.repository.listBlocksByCourt(courtId);
  }

  async createBlock(
    courtId: number,
    input: { startsAt: string; endsAt: string; reason?: string | null },
  ): Promise<ScheduleBlock> {
    const exists = await this.repository.courtExists(courtId);
    if (!exists) {
      throw new NotFoundError('Quadra não encontrada.');
    }
    return this.repository.createBlock({
      courtId,
      startsAt: input.startsAt,
      endsAt: input.endsAt,
      reason: input.reason ?? null,
    });
  }

  async deleteBlock(blockId: number, courtId?: number): Promise<void> {
    const deleted = await this.repository.deleteBlock(blockId, courtId);
    if (!deleted) {
      throw new NotFoundError('Bloqueio não encontrado.');
    }
  }

  /**
   * Função reutilizável que devolve os horários de 1 hora de uma quadra em uma data
   * (usada pela consulta pública de disponibilidade e pela validação de agendamento).
   */
  async getCourtDaySlots(
    courtId: number,
    date: string,
    options: { now?: Date } = {},
  ): Promise<CourtHourSlot[]> {
    const court = await this.courtsRepository.findById(courtId);
    if (!court) {
      throw new NotFoundError('Quadra não encontrada.');
    }

    if (court.unavailableFrom !== null && date >= court.unavailableFrom) {
      return [];
    }

    const rules = await this.repository.findRulesActiveOnDate(courtId, date);
    if (rules.length === 0) {
      return [];
    }

    const weekday = saoPauloWeekdayOfDate(date);
    const dayRanges = rules.filter((rule) => rule.weekday === weekday);
    if (dayRanges.length === 0) {
      return [];
    }

    const hours = new Set<number>();
    for (const range of dayRanges) {
      for (let hour = range.startHour; hour < range.endHour; hour++) {
        hours.add(hour);
      }
    }

    const sortedHours = [...hours].sort((a, b) => a - b);
    const dayStartIso = saoPauloHourToUtcIso(date, 0);
    const dayEndIso = saoPauloHourToUtcIso(date, 24);

    const [blocks, bookedStarts] = await Promise.all([
      this.repository.listBlocksOverlappingPeriod(courtId, dayStartIso, dayEndIso),
      this.repository.listConfirmedBookingStartsInPeriod(courtId, dayStartIso, dayEndIso),
    ]);

    const bookedStartMs = new Set(bookedStarts.map((iso) => Date.parse(iso)));
    const currentTimeMs = (options.now ?? new Date(this.now())).getTime();

    return sortedHours.map((hour) => {
      const startsAt = saoPauloHourToUtcIso(date, hour);
      const endsAt = saoPauloHourToUtcIso(date, hour + 1);
      const slotStartMs = Date.parse(startsAt);
      const slotEndMs = Date.parse(endsAt);

      let status: CourtSlotStatus;
      if (bookedStartMs.has(slotStartMs)) {
        status = 'busy';
      } else if (
        isSlotCoveredByBlocks(slotStartMs, slotEndMs, blocks) ||
        slotStartMs <= currentTimeMs
      ) {
        status = 'closed';
      } else {
        status = 'free';
      }

      return {
        courtId,
        date,
        hour,
        startsAt,
        endsAt,
        status,
      };
    });
  }

  /** Atalho reutilizável que devolve apenas os horários livres (`status === 'free'`) do dia. */
  async getAvailableCourtDaySlots(
    courtId: number,
    date: string,
    options: { now?: Date } = {},
  ): Promise<CourtHourSlot[]> {
    const slots = await this.getCourtDaySlots(courtId, date, options);
    return slots.filter((slot) => slot.status === 'free');
  }
}
