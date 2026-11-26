import type pg from 'pg';
import { withTransaction } from '../../db/pool.js';
import { ConflictError, mapDatabaseError, NotFoundError } from '../../shared/errors.js';
import type { AvailabilityService } from '../availability/availability.service.js';
import type { CourtsRepository } from '../courts/courts.repository.js';
import { todayInSaoPaulo } from '../schedule/schedule.service.js';
import { generateBookingCode, type BookingCodeGenerator } from './booking-code.js';
import { BookingsRepository, type Booking } from './bookings.repository.js';
import { claimSlotInTransaction, slotUnavailable } from './slot-guard.js';

export type CreateBookingInput = {
  courtId: number;
  startsAt: string;
  customerName: string;
  customerPhone: string;
};

const MAX_CODE_ATTEMPTS = 5;

// RF03 / D01: por telefone e dia do jogo, contando só reservas confirmadas.
export const DAILY_BOOKING_LIMIT = 2;

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

        const bookingsThatDay = await repository.countConfirmedOnGameDate(customerPhone, gameDate);
        if (bookingsThatDay >= DAILY_BOOKING_LIMIT) {
          throw new ConflictError(
            'DAILY_LIMIT_REACHED',
            `Este telefone já tem ${DAILY_BOOKING_LIMIT} reservas para este dia. O limite é de ${DAILY_BOOKING_LIMIT} reservas por dia: escolha outra data.`,
          );
        }

        await claimSlotInTransaction(
          client,
          { pool: this.pool, courtsRepository: this.courtsRepository, now: this.now },
          court,
          new Date(startsAtMs),
          gameDate,
        );

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
      throw mapDatabaseError(error) ?? error;
    }
  }
}
