import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { ScheduleService } from './schedule.service.js';

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

function isValidIsoDateTime(value: string): boolean {
  return (
    /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2}(\.\d+)?)?(Z|[+-]\d{2}:\d{2})$/.test(value) &&
    !Number.isNaN(Date.parse(value))
  );
}

const isoDateSchema = z
  .string()
  .refine(isValidIsoDate, 'Data deve estar no formato AAAA-MM-DD e ser válida.');

const isoDateTimeSchema = z
  .string()
  .refine(isValidIsoDateTime, 'Data/hora deve estar no formato ISO-8601 com fuso horário.');

const courtIdParamsSchema = z.object({
  id: z.coerce.number().int('ID da quadra inválido.').positive('ID da quadra inválido.'),
});

const blockIdParamsSchema = z.object({
  id: z.coerce.number().int('ID do bloqueio inválido.').positive('ID do bloqueio inválido.'),
});

const courtAndBlockParamsSchema = z.object({
  id: z.coerce.number().int('ID da quadra inválido.').positive('ID da quadra inválido.'),
  blockId: z.coerce.number().int('ID do bloqueio inválido.').positive('ID do bloqueio inválido.'),
});

const scheduleQuerySchema = z.object({
  date: isoDateSchema.optional(),
});

const openingRangeSchema = z
  .object({
    weekday: z
      .number()
      .int('Dia da semana deve ser um inteiro entre 0 (domingo) e 6 (sábado).')
      .min(0, 'Dia da semana deve ser entre 0 (domingo) e 6 (sábado).')
      .max(6, 'Dia da semana deve ser entre 0 (domingo) e 6 (sábado).'),
    startHour: z
      .number()
      .int('Hora inicial deve ser um número inteiro (múltiplo de 1 hora) entre 0 e 23.')
      .min(0, 'Hora inicial deve ser entre 0 e 23.')
      .max(23, 'Hora inicial deve ser entre 0 e 23.'),
    endHour: z
      .number()
      .int('Hora final deve ser um número inteiro (múltiplo de 1 hora) entre 1 e 24.')
      .min(1, 'Hora final deve ser entre 1 e 24.')
      .max(24, 'Hora final deve ser entre 1 e 24.'),
  })
  .refine((range) => range.endHour > range.startHour, {
    message: 'Hora final deve ser maior que a hora inicial.',
    path: ['endHour'],
  });

const saveScheduleBodySchema = z.object({
  validFrom: isoDateSchema,
  ranges: z.array(openingRangeSchema).min(1, 'Informe pelo menos uma faixa de horário.'),
});

const createBlockBodySchema = z
  .object({
    startsAt: isoDateTimeSchema,
    endsAt: isoDateTimeSchema,
    reason: z
      .string()
      .trim()
      .max(200, 'Motivo do bloqueio deve ter no máximo 200 caracteres.')
      .nullable()
      .optional(),
  })
  .refine((block) => Date.parse(block.endsAt) > Date.parse(block.startsAt), {
    message: 'Data/hora final do bloqueio deve ser maior que a inicial.',
    path: ['endsAt'],
  });

export function ownerScheduleRoutes(service: ScheduleService) {
  return async function register(app: FastifyInstance): Promise<void> {
    // Endpoints GET e PUT /api/owner/courts/:id/schedule (RF07 / Issue #12)
    app.get('/courts/:id/schedule', async (request) => {
      const { id } = courtIdParamsSchema.parse(request.params);
      const { date } = scheduleQuerySchema.parse(request.query ?? {});
      return service.getCourtSchedule(id, date);
    });

    app.put('/courts/:id/schedule', async (request) => {
      const { id } = courtIdParamsSchema.parse(request.params);
      const body = saveScheduleBodySchema.parse(request.body ?? {});
      return service.saveCourtSchedule(id, body);
    });

    // Endpoints compatíveis com o cliente Flutter (docs/api.md)
    app.get('/courts/:id/opening-hours', async (request) => {
      const { id } = courtIdParamsSchema.parse(request.params);
      const { date } = scheduleQuerySchema.parse(request.query ?? {});
      const { openingHours } = await service.getCourtSchedule(id, date);
      return { openingHours };
    });

    app.post('/courts/:id/opening-hours', async (request) => {
      const { id } = courtIdParamsSchema.parse(request.params);
      const body = saveScheduleBodySchema.parse(request.body ?? {});
      const result = await service.saveCourtSchedule(id, body);
      return {
        openingHours: result.openingHours,
        affectedBookings: result.affectedBookings,
        bookingsNeedingRelocation: result.bookingsNeedingRelocation,
      };
    });

    // Bloqueios pontuais (ex.: manutenção) sem apagar a regra semanal
    app.get('/courts/:id/blocks', async (request) => {
      const { id } = courtIdParamsSchema.parse(request.params);
      const blocks = await service.listBlocks(id);
      return { blocks };
    });

    app.post('/courts/:id/blocks', async (request, reply) => {
      const { id } = courtIdParamsSchema.parse(request.params);
      const body = createBlockBodySchema.parse(request.body ?? {});
      const block = await service.createBlock(id, body);
      return reply.status(201).send({ block });
    });

    app.delete('/blocks/:id', async (request, reply) => {
      const { id } = blockIdParamsSchema.parse(request.params);
      await service.deleteBlock(id);
      return reply.status(204).send();
    });

    app.delete('/courts/:id/blocks/:blockId', async (request, reply) => {
      const { id, blockId } = courtAndBlockParamsSchema.parse(request.params);
      await service.deleteBlock(blockId, id);
      return reply.status(204).send();
    });
  };
}
