import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { CourtsService } from './courts.service.js';

function isValidIsoDate(value: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const [yearStr, monthStr, dayStr] = value.split('-');
  const year = Number(yearStr);
  const month = Number(monthStr);
  const day = Number(dayStr);
  const date = new Date(Date.UTC(year, month - 1, day));
  return (
    date.getUTCFullYear() === year && date.getUTCMonth() === month - 1 && date.getUTCDate() === day
  );
}

const isoDateSchema = z
  .string()
  .refine(isValidIsoDate, 'Data deve estar no formato AAAA-MM-DD e ser válida.');

const courtIdParamsSchema = z.object({
  id: z.coerce.number().int('ID da quadra inválido.').positive('ID da quadra inválido.'),
});

const createCourtBodySchema = z.object({
  name: z
    .string()
    .trim()
    .min(2, 'Nome da quadra deve ter entre 2 e 60 caracteres.')
    .max(60, 'Nome da quadra deve ter entre 2 e 60 caracteres.'),
  hourlyPriceCents: z
    .number()
    .int('Valor por hora deve ser um número inteiro em centavos.')
    .min(0, 'Valor por hora deve ser maior ou igual a zero.')
    .nullable()
    .optional(),
  unavailableFrom: isoDateSchema.nullable().optional(),
});

const updateCourtBodySchema = z.object({
  name: z
    .string()
    .trim()
    .min(2, 'Nome da quadra deve ter entre 2 e 60 caracteres.')
    .max(60, 'Nome da quadra deve ter entre 2 e 60 caracteres.'),
  hourlyPriceCents: z
    .number()
    .int('Valor por hora deve ser um número inteiro em centavos.')
    .min(0, 'Valor por hora deve ser maior ou igual a zero.')
    .nullable()
    .optional(),
  unavailableFrom: isoDateSchema.nullable().optional(),
});

const removeCourtSchema = z.object({
  unavailableFrom: isoDateSchema,
});

export function publicCourtsRoutes(service: CourtsService) {
  return async function register(app: FastifyInstance): Promise<void> {
    app.get('/courts', async () => {
      const courts = await service.listPublicCourts();
      return { courts };
    });
  };
}

export function ownerCourtsRoutes(service: CourtsService) {
  return async function register(app: FastifyInstance): Promise<void> {
    app.get('/courts', async () => {
      const courts = await service.listOwnerCourts();
      return { courts };
    });

    app.post('/courts', async (request, reply) => {
      const body = createCourtBodySchema.parse(request.body ?? {});
      const court = await service.createCourt(body);
      return reply.status(201).send({ court });
    });

    app.put('/courts/:id', async (request) => {
      const { id } = courtIdParamsSchema.parse(request.params);
      const body = updateCourtBodySchema.parse(request.body ?? {});
      const court = await service.updateCourt(id, body);
      return { court };
    });

    app.delete('/courts/:id', async (request) => {
      const { id } = courtIdParamsSchema.parse(request.params);
      const rawInput =
        request.body && typeof request.body === 'object' ? request.body : (request.query ?? {});
      const { unavailableFrom } = removeCourtSchema.parse(rawInput);
      const court = await service.removeCourt(id, unavailableFrom);
      return { court };
    });
  };
}
