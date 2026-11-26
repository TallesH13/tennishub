import type pg from 'pg';
import { ConflictError, SLOT_TAKEN_MESSAGE } from '../../shared/errors.js';
import type { Court, CourtsRepository } from '../courts/courts.repository.js';
import { ScheduleRepository } from '../schedule/schedule.repository.js';
import { ScheduleService } from '../schedule/schedule.service.js';
import { BookingsRepository } from './bookings.repository.js';

export function slotUnavailable(message: string): ConflictError {
  return new ConflictError('SLOT_UNAVAILABLE', message);
}

export type SlotGuardDeps = {
  pool: pg.Pool;
  courtsRepository: CourtsRepository;
  now: () => number;
};

/**
 * Trava a quadra e o horário até o fim da transação e confirma que o horário está livre
 * (RNF01). Toda rota que ocupa um horário usa esta função: criação (#14), remarcação pelo
 * cliente (#17) e realocação pelo proprietário (#19). Quem também trava o telefone e o dia
 * (#15) deve fazer isso antes, para todas as transações travarem na mesma ordem.
 */
export async function claimSlotInTransaction(
  client: pg.PoolClient,
  deps: SlotGuardDeps,
  court: Court,
  startsAt: Date,
  gameDate: string,
): Promise<void> {
  await new BookingsRepository(client).lockSlot(court.id, startsAt.toISOString());

  // Lê os horários pela conexão da transação: pegar outra do pool enquanto a trava
  // está presa esgotaria o pool sob pedidos simultâneos.
  const schedule = new ScheduleService(
    deps.pool,
    new ScheduleRepository(client),
    deps.courtsRepository,
    deps.now,
  );
  const slots = await schedule.buildCourtDaySlots(court, gameDate, { now: new Date(deps.now()) });
  const slot = slots.find((candidate) => Date.parse(candidate.startsAt) === startsAt.getTime());

  if (!slot || slot.status === 'closed') {
    throw slotUnavailable('A quadra não está disponível nesse horário. Escolha outro.');
  }
  if (slot.status === 'busy') {
    throw slotUnavailable(SLOT_TAKEN_MESSAGE);
  }
}
