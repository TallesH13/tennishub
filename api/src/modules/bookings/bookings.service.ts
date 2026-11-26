import type pg from 'pg';
import { withTransaction } from '../../db/pool.js';
import { ConflictError, NotFoundError } from '../../shared/errors.js';
import type { AvailabilityService } from '../availability/availability.service.js';
import type { CourtsRepository } from '../courts/courts.repository.js';
import { ScheduleRepository } from '../schedule/schedule.repository.js';
import { ScheduleService, todayInSaoPaulo } from '../schedule/schedule.service.js';
import { generateBookingCode, type BookingCodeGenerator } from './booking-code.js';
import { BookingsRepository, type Booking } from './bookings.repository.js';

export type CreateBookingInput = {
  courtId: number;
  startsAt: string;
  customerName: string;
  customerPhone: string;
};

const MAX_CODE_ATTEMPTS = 5;

// RF03 / D01: por telefone e dia do jogo, contando só reservas confirmadas.
export const DAILY_BOOKING_LIMIT = 2;

function slotUnavailable(message: string): ConflictError {
  return new ConflictError('SLOT_UNAVAILABLE', message);
}

function isSlotUniqueViolation(error: unknown): boolean {
  const { code, constraint } = error as { code?: string; constraint?: string };
  return code === '23505' && constraint === 'bookings_court_slot_confirmed_key';
}

export class BookingsService {
  constructor(
    private readonly pool: pg.Pool,
    private readonly courtsRepository: CourtsRepository,
    private readonly availabilityService: AvailabilityService,
    private readonly now: () => number = () => Date.now(),
    private readonly generateCode: BookingCodeGenerator = generateBookingCode,
  ) {}

  async createBooking(input: CreateBookingInput): Promise<Booking> {
    const court = await this.courtsRepository.findById(input.courtId);
    if (!court) {
      throw new NotFoundError('Quadra não encontrada.');
    }

    const startsAtMs = Date.parse(input.startsAt);
    const nowMs = this.now();
    if (startsAtMs <= nowMs) {
      throw slotUnavailable('Esse horário já passou. Escolha um horário futuro.');
    }

    const gameDate = todayInSaoPaulo(new Date(startsAtMs));
    // D07: o mesmo cliente com o telefone escrito de outro jeito continua sendo o mesmo.
    const customerPhone = input.customerPhone.replace(/\D/g, '');
    if (!this.availabilityService.isBookable(gameDate)) {
      throw slotUnavailable(
        `Só é possível reservar até ${this.availabilityService.windowDays} dias à frente.`,
      );
    }

    try {
      return await withTransaction(this.pool, async (client) => {
        const repository = new BookingsRepository(client);
        // Sempre telefone antes do horário: a mesma ordem em todas as transações evita deadlock.
        await repository.lockCustomerDay(customerPhone, gameDate);
        await repository.lockSlot(court.id, input.startsAt);

        const bookingsThatDay = await repository.countConfirmedOnGameDate(customerPhone, gameDate);
        if (bookingsThatDay >= DAILY_BOOKING_LIMIT) {
          throw new ConflictError(
            'DAILY_LIMIT_REACHED',
            `Este telefone já tem ${DAILY_BOOKING_LIMIT} reservas para este dia. O limite é de ${DAILY_BOOKING_LIMIT} reservas por dia: escolha outra data.`,
          );
        }

        // Lê os horários pela conexão da transação: pegar outra do pool enquanto a trava
        // está presa esgotaria o pool sob pedidos simultâneos.
        const schedule = new ScheduleService(
          this.pool,
          new ScheduleRepository(client),
          this.courtsRepository,
          this.now,
        );
        const slots = await schedule.buildCourtDaySlots(court, gameDate, {
          now: new Date(nowMs),
        });
        const slot = slots.find((candidate) => Date.parse(candidate.startsAt) === startsAtMs);
        if (!slot || slot.status === 'closed') {
          throw slotUnavailable('A quadra não está disponível nesse horário. Escolha outro.');
        }
        if (slot.status === 'busy') {
          throw slotUnavailable('Esse horário acabou de ser reservado. Escolha outro horário.');
        }

        for (let attempt = 0; attempt < MAX_CODE_ATTEMPTS; attempt++) {
          const booking = await repository.insert({
            courtId: court.id,
            startsAt: new Date(startsAtMs).toISOString(),
            customerName: input.customerName,
            customerPhone,
            code: this.generateCode(),
          });
          if (booking) return booking;
        }
        throw new Error('Não foi possível gerar um código de reserva único.');
      });
    } catch (error) {
      // Última barreira: o índice único do banco, caso duas reservas passem juntas.
      if (isSlotUniqueViolation(error)) {
        throw slotUnavailable('Esse horário acabou de ser reservado. Escolha outro horário.');
      }
      throw error;
    }
  }
}
