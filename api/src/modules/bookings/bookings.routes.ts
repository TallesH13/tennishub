import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { isValidIsoDateTime } from '../../shared/dates.js';
import type { BookingsService } from './bookings.service.js';

const HOUR_MS = 60 * 60 * 1000;

// Nome e sobrenome: ao menos duas palavras com letras (acentos, apóstrofo e hífen valem).
const FULL_NAME = /^\p{L}[\p{L}'.-]*(\s+\p{L}[\p{L}'.-]*)+$/u;

// D07: DDD sem zero + 8 dígitos (fixo, começando de 2 a 5) ou 9 dígitos (celular, começando com 9).
const BRAZILIAN_PHONE = /^[1-9][1-9](?:[2-5]\d{7}|9\d{8})$/;

export const createBookingBodySchema = z.object({
  courtId: z.coerce
    .number({ error: 'Informe a quadra.' })
    .int('Quadra inválida.')
    .positive('Quadra inválida.'),
  startsAt: z
    .string({ error: 'Informe o horário da reserva.' })
    .refine(isValidIsoDateTime, {
      message: 'Horário deve estar no formato ISO-8601 com fuso horário.',
      abort: true,
    })
    // O fuso de São Paulo é UTC-3, então a hora cheia local também é hora cheia em UTC.
    .refine((value) => Date.parse(value) % HOUR_MS === 0, 'A reserva deve começar em hora cheia.'),
  customerName: z
    .string({ error: 'Informe o nome completo.' })
    .transform((value) => value.trim().replace(/\s+/g, ' '))
    .pipe(
      z
        .string()
        .min(5, { message: 'O nome deve ter entre 5 e 100 caracteres.', abort: true })
        .max(100, { message: 'O nome deve ter entre 5 e 100 caracteres.', abort: true })
        .regex(FULL_NAME, 'Informe nome e sobrenome.'),
    ),
  customerPhone: z
    .string({ error: 'Informe o telefone.' })
    .transform((value) => value.replace(/\D/g, ''))
    .pipe(z.string().regex(BRAZILIAN_PHONE, 'Telefone inválido. Informe DDD e número.')),
});

export function publicBookingsRoutes(service: BookingsService) {
  return async function register(app: FastifyInstance): Promise<void> {
    app.post('/bookings', async (request, reply) => {
      const input = createBookingBodySchema.parse(request.body ?? {});
      const booking = await service.createBooking(input);
      return reply.status(201).send({ booking });
    });
  };
}
