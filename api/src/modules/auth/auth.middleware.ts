import type { FastifyReply, FastifyRequest } from 'fastify';
import { UnauthorizedError } from '../../shared/errors.js';
import {
  SESSION_COOKIE_NAME,
  type AuthenticatedOwner,
  type SessionManager,
} from './session.manager.js';

declare module 'fastify' {
  interface FastifyRequest {
    owner?: AuthenticatedOwner;
  }
}

function extractCookieValue(cookieHeader: string | undefined, name: string): string | null {
  if (!cookieHeader) return null;

  for (const part of cookieHeader.split(';')) {
    const separator = part.indexOf('=');
    if (separator === -1) continue;
    const key = part.slice(0, separator).trim();
    if (key === name) {
      const value = part.slice(separator + 1).trim();
      return value ? decodeURIComponent(value) : null;
    }
  }
  return null;
}

export function extractSessionToken(request: FastifyRequest): string | null {
  const authHeader = request.headers.authorization;
  if (authHeader !== undefined) {
    const [scheme, credentials, ...extra] = authHeader.trim().split(/\s+/);
    if (!scheme || scheme.toLowerCase() !== 'bearer' || !credentials || extra.length > 0) {
      throw new UnauthorizedError('Cabeçalho Authorization inválido.');
    }
    return credentials;
  }

  return extractCookieValue(request.headers.cookie, SESSION_COOKIE_NAME);
}

export function createRequireOwnerAuth(sessions: SessionManager) {
  return async function requireOwnerAuth(
    request: FastifyRequest,
    _reply: FastifyReply,
  ): Promise<void> {
    const token = extractSessionToken(request);
    if (!token) {
      throw new UnauthorizedError('Autenticação obrigatória.');
    }

    request.owner = sessions.verifyAndTouch(token);
  };
}
