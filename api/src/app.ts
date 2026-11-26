import { randomBytes } from 'node:crypto';
import Fastify, {
  type FastifyInstance,
  type FastifyServerOptions,
  type preHandlerAsyncHookHandler,
} from 'fastify';
import type pg from 'pg';
import type { Queryable } from './db/pool.js';
import { createRequireOwnerAuth } from './modules/auth/auth.middleware.js';
import { AuthRepository } from './modules/auth/auth.repository.js';
import { authRoutes, ownerMeRoute } from './modules/auth/auth.routes.js';
import { AuthService } from './modules/auth/auth.service.js';
import { LoginRateLimiter } from './modules/auth/login-rate-limiter.js';
import { SessionManager } from './modules/auth/session.manager.js';
import { publicAvailabilityRoutes } from './modules/availability/availability.routes.js';
import { AvailabilityService } from './modules/availability/availability.service.js';
import { publicBookingsRoutes } from './modules/bookings/bookings.routes.js';
import { BookingsService } from './modules/bookings/bookings.service.js';
import { CourtsRepository } from './modules/courts/courts.repository.js';
import { ownerCourtsRoutes } from './modules/courts/courts.routes.js';
import { CourtsService } from './modules/courts/courts.service.js';
import { HealthRepository } from './modules/health/health.repository.js';
import { healthRoutes } from './modules/health/health.routes.js';
import { HealthService } from './modules/health/health.service.js';
import { ScheduleRepository } from './modules/schedule/schedule.repository.js';
import { ownerScheduleRoutes } from './modules/schedule/schedule.routes.js';
import { ScheduleService } from './modules/schedule/schedule.service.js';
import { registerErrorHandling } from './shared/errors.js';

/** Prefixo de todas as rotas REST. O build do Flutter Web será servido na raiz (#4). */
export const API_PREFIX = '/api';

export type AppDependencies = {
  db: Queryable;
  sessionSecret?: string;
  now?: () => number;
  /** Antecedência máxima de reserva em dias (D08). Padrão: 30. */
  bookingWindowDays?: number;
  /** Prazo mínimo, em horas, para o cliente cancelar ou remarcar (D02). Padrão: 2. */
  cancellationDeadlineHours?: number;
};

export type BuildAppOptions = {
  logger?: FastifyServerOptions['logger'];
  registerOwnerRoutes?: (
    ownerApi: FastifyInstance,
    requireOwnerAuth: preHandlerAsyncHookHandler,
  ) => Promise<void>;
};

function resolveSessionSecret(provided?: string): string {
  const secret = provided ?? process.env.SESSION_SECRET ?? '';
  if (secret.length >= 32) return secret;
  if (process.env.NODE_ENV === 'test') return randomBytes(32).toString('hex');
  throw new Error('SESSION_SECRET deve ter pelo menos 32 caracteres.');
}

/**
 * Monta a aplicação sem abrir porta, o que permite testá-la com `inject`/Supertest.
 * Camadas: rotas (HTTP) → serviços (regras de negócio) → repositórios (SQL).
 */
export async function buildApp(
  deps: AppDependencies,
  options: BuildAppOptions = {},
): Promise<FastifyInstance> {
  const loggerOption =
    typeof options.logger === 'object' && options.logger !== null
      ? {
          ...options.logger,
          redact: [
            'req.headers.authorization',
            'req.headers.cookie',
            '*.password',
            '*.passwordHash',
            '*.token',
          ],
        }
      : (options.logger ?? false);

  const app = Fastify({
    logger: loggerOption,
    disableRequestLogging: false,
  });

  registerErrorHandling(app);

  const now = deps.now ?? (() => Date.now());
  const sessionSecret = resolveSessionSecret(deps.sessionSecret);

  const courtsRepository = new CourtsRepository(deps.db);
  const healthService = new HealthService(new HealthRepository(deps.db));
  const courtsService = new CourtsService(courtsRepository);
  const scheduleService = new ScheduleService(
    deps.db as pg.Pool,
    new ScheduleRepository(deps.db),
    courtsRepository,
    now,
  );
  const availabilityService = new AvailabilityService(
    courtsRepository,
    scheduleService,
    now,
    deps.bookingWindowDays,
  );
  const bookingsService = new BookingsService(
    deps.db as pg.Pool,
    courtsRepository,
    availabilityService,
    now,
    undefined,
    { cancellationDeadlineHours: deps.cancellationDeadlineHours },
  );
  const sessionManager = new SessionManager(sessionSecret, now);
  const loginRateLimiter = new LoginRateLimiter({ now });
  const authService = new AuthService(
    new AuthRepository(deps.db),
    sessionManager,
    loginRateLimiter,
  );
  const requireOwnerAuth = createRequireOwnerAuth(sessionManager);

  await app.register(
    async (api) => {
      await api.register(healthRoutes(healthService));
      await api.register(authRoutes(authService, requireOwnerAuth));
      await api.register(publicAvailabilityRoutes(courtsService, availabilityService));
      await api.register(publicBookingsRoutes(bookingsService));

      // Todas as rotas /api/owner/* exigem sessão válida do proprietário.
      await api.register(
        async (ownerApi) => {
          ownerApi.addHook('preHandler', requireOwnerAuth);
          await ownerApi.register(ownerMeRoute(authService));
          await ownerApi.register(ownerCourtsRoutes(courtsService));
          await ownerApi.register(ownerScheduleRoutes(scheduleService));
          if (options.registerOwnerRoutes) {
            await options.registerOwnerRoutes(ownerApi, requireOwnerAuth);
          }
        },
        { prefix: '/owner' },
      );
    },
    { prefix: API_PREFIX },
  );

  return app;
}
