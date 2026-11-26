import { NotFoundError } from '../../shared/errors.js';
import { addDaysToIsoDate } from '../../shared/dates.js';
import type { Court, CourtsRepository } from '../courts/courts.repository.js';
import {
  todayInSaoPaulo,
  type CourtHourSlot,
  type CourtSlotStatus,
  type ScheduleService,
} from '../schedule/schedule.service.js';

export const DEFAULT_BOOKING_WINDOW_DAYS = 30;

export type PublicSlot = {
  startsAt: string;
  endsAt: string;
  status: CourtSlotStatus;
};

export type CourtDayAvailability = {
  courtId: number;
  courtName: string;
  hourlyPriceCents: number | null;
  slots: PublicSlot[];
};

// D08: só do dia de hoje até a janela de antecedência (30 dias por padrão).
export function isWithinBookingWindow(date: string, today: string, windowDays: number): boolean {
  return date >= today && date <= addDaysToIsoDate(today, windowDays);
}

function toPublicSlot(slot: CourtHourSlot): PublicSlot {
  return { startsAt: slot.startsAt, endsAt: slot.endsAt, status: slot.status };
}

export class AvailabilityService {
  constructor(
    private readonly courtsRepository: CourtsRepository,
    private readonly scheduleService: ScheduleService,
    private readonly now: () => number = () => Date.now(),
    private readonly bookingWindowDays: number = DEFAULT_BOOKING_WINDOW_DAYS,
  ) {}

  isBookable(date: string): boolean {
    const today = todayInSaoPaulo(new Date(this.now()));
    return isWithinBookingWindow(date, today, this.bookingWindowDays);
  }

  /** Quadras com horário de funcionamento no dia; quadras sem nenhum horário ficam de fora. */
  async getDayAvailability(date: string): Promise<CourtDayAvailability[]> {
    if (!this.isBookable(date)) return [];

    const courts = await this.courtsRepository.listAvailableOn(date);
    const days = await Promise.all(courts.map((court) => this.courtDay(court, date)));
    return days.filter((day) => day.slots.length > 0);
  }

  async getCourtDayAvailability(courtId: number, date: string): Promise<CourtDayAvailability> {
    const court = await this.courtsRepository.findById(courtId);
    if (!court) {
      throw new NotFoundError('Quadra não encontrada.');
    }
    if (!this.isBookable(date)) {
      return { ...this.courtSummary(court), slots: [] };
    }
    return this.courtDay(court, date);
  }

  private async courtDay(court: Court, date: string): Promise<CourtDayAvailability> {
    const slots = await this.scheduleService.buildCourtDaySlots(court, date, {
      now: new Date(this.now()),
    });
    return { ...this.courtSummary(court), slots: slots.map(toPublicSlot) };
  }

  private courtSummary(court: Court): Omit<CourtDayAvailability, 'slots'> {
    return {
      courtId: court.id,
      courtName: court.name,
      hourlyPriceCents: court.hourlyPriceCents,
    };
  }
}
