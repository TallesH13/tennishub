import type { FastifyInstance, FastifyReply, preHandlerAsyncHookHandler } from 'fastify';
import { z } from 'zod';
import { UnauthorizedError } from '../../shared/errors.js';
import type { AuthService } from './auth.service.js';
import { SESSION_COOKIE_NAME, SESSION_INACTIVITY_TTL_SECONDS } from './session.manager.js';

const loginBodySchema = z.object({
  email: z.string().trim().min(1, 'E-mail é obrigatório.').email('E-mail inválido.'),
  password: z.string().min(1, 'Senha é obrigatória.'),
});

function setSessionCookie(reply: FastifyReply, token: string): void {
  const parts = [
    `${SESSION_COOKIE_NAME}=${encodeURIComponent(token)}`,
    'Path=/',
    'HttpOnly',
    'SameSite=Lax',
    `Max-Age=${SESSION_INACTIVITY_TTL_SECONDS}`,
  ];
  if (process.env.NODE_ENV === 'production') {
    parts.push('Secure');
  }
  reply.header('Set-Cookie', parts.join('; '));
}

function clearSessionCookie(reply: FastifyReply): void {
  const parts = [`${SESSION_COOKIE_NAME}=`, 'Path=/', 'HttpOnly', 'SameSite=Lax', 'Max-Age=0'];
  if (process.env.NODE_ENV === 'production') {
    parts.push('Secure');
  }
  reply.header('Set-Cookie', parts.join('; '));
}

export function authRoutes(service: AuthService, requireOwnerAuth: preHandlerAsyncHookHandler) {
  return async function register(app: FastifyInstance): Promise<void> {
    app.post('/auth/login', async (request, reply) => {
      const parsed = loginBodySchema.parse(request.body ?? {});
      const result = await service.login({
        email: parsed.email,
        password: parsed.password,
        ip: request.ip,
      });

      setSessionCookie(reply, result.token);
      return reply.status(200).send(result);
    });

    app.post('/auth/logout', { preHandler: [requireOwnerAuth] }, async (request, reply) => {
      if (!request.owner) {
        throw new UnauthorizedError('Autenticação obrigatória.');
      }
      service.logout(request.owner.sessionId);
      clearSessionCookie(reply);
      return reply.status(204).send();
    });

    app.get('/auth/me', { preHandler: [requireOwnerAuth] }, async (request) => {
      if (!request.owner) {
        throw new UnauthorizedError('Autenticação obrigatória.');
      }
      const owner = await service.getCurrentOwner(request.owner);
      return { owner };
    });
  };
}

export function ownerMeRoute(service: AuthService) {
  return async function register(app: FastifyInstance): Promise<void> {
    app.get('/me', async (request) => {
      if (!request.owner) {
        throw new UnauthorizedError('Autenticação obrigatória.');
      }
      const owner = await service.getCurrentOwner(request.owner);
      return { owner };
    });
  };
}
