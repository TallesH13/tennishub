import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { isoDateSchema } from '../../shared/dates.js';
import { AppError, zodToFieldErrors } from '../../shared/errors.js';
import type { CourtsService } from '../courts/courts.service.js';
import type { AvailabilityService } from './availability.service.js';

const optionalDateQuerySchema = z.object({ date: isoDateSchema.optional() });
const dateQuerySchema = z.object({ date: isoDateSchema });
const courtIdParamsSchema = z.object({
  id: z.coerce.number().int('ID da quadra inválido.').positive('ID da quadra inválido.'),
});

// A issue #13 pede 400 (e não o 422 padrão) para data inválida na consulta pública.
function parseRequest<T>(schema: z.ZodType<T>, value: unknown): T {
  const parsed = schema.safeParse(value);
  if (!parsed.success) {
    throw new AppError(400, 'VALIDATION_ERROR', 'Dados inválidos.', zodToFieldErrors(parsed.error));
  }
  return parsed.data;
}

export function publicAvailabilityRoutes(
  courtsService: CourtsService,
  availabilityService: AvailabilityService,
) {
  return async function register(app: FastifyInstance): Promise<void> {
    app.get('/courts', async (request) => {
      const { date } = parseRequest(optionalDateQuerySchema, request.query);
      if (date === undefined) {
        return { courts: await courtsService.listPublicCourts() };
      }

      const days = await availabilityService.getDayAvailability(date);
      return {
        date,
        courts: days.filter((day) => day.slots.some((slot) => slot.status === 'free')),
      };
    });

    app.get('/courts/:id/slots', async (request) => {
      const { id } = parseRequest(courtIdParamsSchema, request.params);
      const { date } = parseRequest(dateQuerySchema, request.query);
      return { date, ...(await availabilityService.getCourtDayAvailability(id, date)) };
    });

    // Contrato usado pelo app Flutter (HttpCourtsRepository.fetchAvailability).
    app.get('/availability', async (request) => {
      const { date } = parseRequest(dateQuerySchema, request.query);
      return { date, courts: await availabilityService.getDayAvailability(date) };
    });
  };
}
