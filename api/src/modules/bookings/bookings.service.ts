import type pg from 'pg';
import { withTransaction } from '../../db/pool.js';
import { ConflictError, mapDatabaseError, NotFoundError } from '../../shared/errors.js';
import type { AvailabilityService } from '../availability/availability.service.js';
import type { Court, CourtsRepository } from '../courts/courts.repository.js';
import { todayInSaoPaulo } from '../schedule/schedule.service.js';
import { generateBookingCode, type BookingCodeGenerator } from './booking-code.js';
import { BookingsRepository, type Booking } from './bookings.repository.js';
import { CustomerAttemptLimiter } from './customer-attempt-limiter.js';
import { claimSlotInTransaction, slotUnavailable } from './slot-guard.js';

export type CreateBookingInput = {
  courtId: number;
  startsAt: string;
  customerName: string;
  customerPhone: string;
};

export type BookingIdentity = {
  code: string;
  phone: string;
  /** IP de quem pede, para o limite de tentativas. */
  ip: string;
};

export type RescheduleBookingInput = BookingIdentity & {
  courtId: number;
  startsAt: string;
};

export type BookingsServiceOptions = {
  /** D02: o cliente cancela ou remarca até esse número de horas antes do início. */
  cancellationDeadlineHours?: number;
  attemptLimiter?: CustomerAttemptLimiter;
};

const MAX_CODE_ATTEMPTS = 5;
const HOUR_MS = 60 * 60 * 1000;

// RF03 / D01: por telefone e dia do jogo, contando só reservas confirmadas.
export const DAILY_BOOKING_LIMIT = 2;
export const DEFAULT_CANCELLATION_DEADLINE_HOURS = 2;

// Mesma resposta para código errado e telefone errado: não revela qual dos dois falhou.
const BOOKING_NOT_FOUND_MESSAGE = 'Reserva não encontrada. Confira o código e o telefone.';

type Target = { court: Court; startsAt: Date; gameDate: string };

function onlyDigits(value: string): string {
  return value.replace(/\D/g, '');
}

function normalizeCode(value: string): string {
  return value.replace(/[\s-]/g, '').toUpperCase();
}

export class BookingsService {
  private readonly cancellationDeadlineHours: number;
  private readonly attemptLimiter: CustomerAttemptLimiter;

  constructor(
    private readonly pool: pg.Pool,
    private readonly courtsRepository: CourtsRepository,
    private readonly availabilityService: AvailabilityService,
    private readonly now: () => number = () => Date.now(),
    private readonly generateCode: BookingCodeGenerator = generateBookingCode,
    options: BookingsServiceOptions = {},
  ) {
    this.cancellationDeadlineHours =
      options.cancellationDeadlineHours ?? DEFAULT_CANCELLATION_DEADLINE_HOURS;
    this.attemptLimiter = options.attemptLimiter ?? new CustomerAttemptLimiter({ now });
  }

  async createBooking(input: CreateBookingInput): Promise<Booking> {
    const target = await this.resolveTarget(input.courtId, input.startsAt);
    // D07: o mesmo cliente com o telefone escrito de outro jeito continua sendo o mesmo.
    const customerPhone = onlyDigits(input.customerPhone);

    return this.inTransaction(async (client, repository) => {
      await this.assertWithinDailyLimit(repository, customerPhone, target.gameDate);
      await this.claimSlot(client, target);

      for (let attempt = 0; attempt < MAX_CODE_ATTEMPTS; attempt++) {
        const booking = await repository.insert({
          courtId: target.court.id,
          startsAt: target.startsAt.toISOString(),
          customerName: input.customerName,
          customerPhone,
          code: this.generateCode(),
        });
        if (booking) return booking;
      }
      throw new Error('Não foi possível gerar um código de reserva único.');
    });
  }

  async findBooking(identity: BookingIdentity): Promise<Booking> {
    return this.withIdentity(identity, (code, phone) =>
      new BookingsRepository(this.pool).findByCodeAndPhone(code, phone),
    );
  }

  async cancelBooking(identity: BookingIdentity): Promise<Booking> {
    return this.inTransaction(async (_client, repository) => {
      const booking = await this.withIdentity(identity, (code, phone) =>
        repository.findByCodeAndPhone(code, phone, { forUpdate: true }),
      );
      this.assertCustomerCanChange(booking, 'cancelar');
      return repository.cancelByCustomer(booking.id);
    });
  }

  /** D10: tudo numa transação; se o novo horário falhar, a reserva antiga continua valendo. */
  async rescheduleBooking(input: RescheduleBookingInput): Promise<Booking> {
    const target = await this.resolveTarget(input.courtId, input.startsAt);

    return this.inTransaction(async (client, repository) => {
      const booking = await this.withIdentity(input, (code, phone) =>
        repository.findByCodeAndPhone(code, phone, { forUpdate: true }),
      );
      this.assertCustomerCanChange(booking, 'remarcar');

      if (
        booking.courtId === target.court.id &&
        Date.parse(booking.startsAt) === target.startsAt.getTime()
      ) {
        throw new ConflictError('BOOKING_SAME_SLOT', 'A reserva já está nesse dia e horário.');
      }

      await this.assertWithinDailyLimit(
        repository,
        booking.customerPhone,
        target.gameDate,
        booking.id,
      );
      await this.claimSlot(client, target);
      return repository.moveTo(booking.id, target.court.id, target.startsAt.toISOString());
    });
  }

  private async resolveTarget(courtId: number, startsAt: string): Promise<Target> {
    const court = await this.courtsRepository.findById(courtId);
    if (!court) {
      throw new NotFoundError('Quadra não encontrada.');
    }

    const startsAtMs = Date.parse(startsAt);
    if (startsAtMs <= this.now()) {
      throw slotUnavailable('Esse horário já passou. Escolha um horário futuro.');
    }

    const gameDate = todayInSaoPaulo(new Date(startsAtMs));
    if (!this.availabilityService.isBookable(gameDate)) {
      throw slotUnavailable(
        `Só é possível reservar até ${this.availabilityService.windowDays} dias à frente.`,
      );
    }
    return { court, startsAt: new Date(startsAtMs), gameDate };
  }

  private async assertWithinDailyLimit(
    repository: BookingsRepository,
    customerPhone: string,
    gameDate: string,
    exceptBookingId: number | null = null,
  ): Promise<void> {
    // Sempre telefone antes do horário: a mesma ordem em todas as transações evita deadlock.
    await repository.lockCustomerDay(customerPhone, gameDate);
    const total = await repository.countConfirmedOnGameDate(
      customerPhone,
      gameDate,
      exceptBookingId,
    );
    if (total >= DAILY_BOOKING_LIMIT) {
      throw new ConflictError(
        'DAILY_LIMIT_REACHED',
        `Este telefone já tem ${DAILY_BOOKING_LIMIT} reservas para este dia. O limite é de ${DAILY_BOOKING_LIMIT} reservas por dia: escolha outra data.`,
      );
    }
  }

  private claimSlot(client: pg.PoolClient, target: Target): Promise<void> {
    return claimSlotInTransaction(
      client,
      { pool: this.pool, courtsRepository: this.courtsRepository, now: this.now },
      target.court,
      target.startsAt,
      target.gameDate,
    );
  }

  private assertCustomerCanChange(booking: Booking, action: 'cancelar' | 'remarcar'): void {
    if (booking.status === 'cancelled') {
      throw new ConflictError('BOOKING_ALREADY_CANCELLED', 'Esta reserva já foi cancelada.');
    }

    const msUntilStart = Date.parse(booking.startsAt) - this.now();
    if (msUntilStart <= 0) {
      throw new ConflictError(
        'BOOKING_ALREADY_STARTED',
        'Esta reserva já começou ou já passou e não pode mais ser alterada.',
      );
    }
    if (msUntilStart < this.cancellationDeadlineHours * HOUR_MS) {
      throw new ConflictError(
        'CHANGE_DEADLINE_PASSED',
        `Só é possível ${action} até ${this.cancellationDeadlineHours} horas antes do início. Para mudar agora, fale com a administração da quadra.`,
      );
    }
  }

  /** Acha a reserva pelo código e telefone, contando as falhas para o limite de tentativas. */
  private async withIdentity(
    identity: BookingIdentity,
    find: (code: string, phone: string) => Promise<Booking | null>,
  ): Promise<Booking> {
    const phone = onlyDigits(identity.phone);
    this.attemptLimiter.assertAllowed(identity.ip, phone);

    const code = normalizeCode(identity.code);
    const booking = /^[A-HJ-NP-Z2-9]{8}$/.test(code) && phone ? await find(code, phone) : null;
    if (!booking) {
      this.attemptLimiter.recordFailure(identity.ip, phone);
      throw new NotFoundError(BOOKING_NOT_FOUND_MESSAGE);
    }
    return booking;
  }

  private async inTransaction<T>(
    work: (client: pg.PoolClient, repository: BookingsRepository) => Promise<T>,
  ): Promise<T> {
    try {
      return await withTransaction(this.pool, (client) =>
        work(client, new BookingsRepository(client)),
      );
    } catch (error) {
      // Última barreira: o índice único do banco, caso duas reservas passem juntas.
      throw mapDatabaseError(error) ?? error;
    }
  }
}
