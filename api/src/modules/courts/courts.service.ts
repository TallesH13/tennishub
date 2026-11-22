import { AppError, ConflictError, NotFoundError } from '../../shared/errors.js';
import type { Court, CourtsRepository } from './courts.repository.js';

export type SaveCourtInput = {
  name: string;
  hourlyPriceCents?: number | null;
  unavailableFrom?: string | null;
};

export class CourtsService {
  constructor(private readonly repository: CourtsRepository) {}

  async listPublicCourts(): Promise<Court[]> {
    return this.repository.listPublic();
  }

  async listOwnerCourts(): Promise<Court[]> {
    return this.repository.listAll();
  }

  async createCourt(input: SaveCourtInput): Promise<Court> {
    const trimmedName = input.name.trim();
    const unavailableFrom = input.unavailableFrom ?? null;

    if (unavailableFrom === null) {
      const duplicated = await this.repository.existsActiveWithName(trimmedName);
      if (duplicated) {
        throw new ConflictError('COURT_NAME_TAKEN', 'Já existe uma quadra ativa com este nome.');
      }
    }

    return this.repository.create({
      name: trimmedName,
      hourlyPriceCents: input.hourlyPriceCents ?? null,
      unavailableFrom,
    });
  }

  async updateCourt(id: number, input: SaveCourtInput): Promise<Court> {
    const existing = await this.repository.findById(id);
    if (!existing) {
      throw new NotFoundError('Quadra não encontrada.');
    }

    const trimmedName = input.name.trim();
    const unavailableFrom =
      input.unavailableFrom === undefined ? existing.unavailableFrom : input.unavailableFrom;

    if (unavailableFrom !== null && unavailableFrom !== existing.unavailableFrom) {
      await this.ensureNoActiveBookingsFrom(id, unavailableFrom);
    }

    if (unavailableFrom === null) {
      const duplicated = await this.repository.existsActiveWithName(trimmedName, id);
      if (duplicated) {
        throw new ConflictError('COURT_NAME_TAKEN', 'Já existe uma quadra ativa com este nome.');
      }
    }

    const updated = await this.repository.update(id, {
      name: trimmedName,
      hourlyPriceCents:
        input.hourlyPriceCents === undefined ? existing.hourlyPriceCents : input.hourlyPriceCents,
      unavailableFrom,
    });

    if (!updated) {
      throw new NotFoundError('Quadra não encontrada.');
    }
    return updated;
  }

  async removeCourt(id: number, unavailableFrom: string): Promise<Court> {
    const existing = await this.repository.findById(id);
    if (!existing) {
      throw new NotFoundError('Quadra não encontrada.');
    }

    await this.ensureNoActiveBookingsFrom(id, unavailableFrom);

    const updated = await this.repository.markUnavailable(id, unavailableFrom);
    if (!updated) {
      throw new NotFoundError('Quadra não encontrada.');
    }
    return updated;
  }

  private async ensureNoActiveBookingsFrom(courtId: number, fromDate: string): Promise<void> {
    const activeBookings = await this.repository.countConfirmedBookingsFrom(courtId, fromDate);
    if (activeBookings > 0) {
      const message =
        activeBookings === 1
          ? 'Não é possível remover a quadra: há 1 reserva ativa a partir desta data que precisa ser tratada.'
          : `Não é possível remover a quadra: há ${activeBookings} reservas ativas a partir desta data que precisam ser tratadas.`;

      throw new AppError(409, 'COURT_HAS_BOOKINGS', message, { activeBookings });
    }
  }
}
