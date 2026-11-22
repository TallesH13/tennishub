import { createHmac, randomBytes, timingSafeEqual } from 'node:crypto';
import { UnauthorizedError } from '../../shared/errors.js';
import type { PublicOwner } from './auth.repository.js';

/** Tempo máximo de inatividade permitido (D03: 30 minutos). */
export const SESSION_INACTIVITY_TTL_MS = 30 * 60 * 1000;
export const SESSION_INACTIVITY_TTL_SECONDS = SESSION_INACTIVITY_TTL_MS / 1000;
export const SESSION_COOKIE_NAME = 'tennishub_session';

export type AuthenticatedOwner = PublicOwner & {
  sessionId: string;
};

type SessionPayload = {
  jti: string;
  sub: number;
  email: string;
  name: string;
  iat: number;
  exp: number;
};

type SessionEntry = {
  lastActivityAt: number;
  revoked: boolean;
};

const MAX_TRACKED_SESSIONS = 2000;

export class SessionManager {
  private readonly sessions = new Map<string, SessionEntry>();

  constructor(
    private readonly secret: string,
    private readonly now: () => number = () => Date.now(),
  ) {
    if (secret.length < 32) {
      throw new Error('SESSION_SECRET deve ter pelo menos 32 caracteres.');
    }
  }

  issue(owner: PublicOwner): { token: string; expiresIn: number } {
    const issuedAt = this.now();
    const sessionId = randomBytes(16).toString('hex');
    const payload: SessionPayload = {
      jti: sessionId,
      sub: owner.id,
      email: owner.email,
      name: owner.name,
      iat: issuedAt,
      exp: issuedAt + SESSION_INACTIVITY_TTL_MS,
    };

    const encodedPayload = Buffer.from(JSON.stringify(payload), 'utf8').toString('base64url');
    const signature = this.sign(encodedPayload);

    this.pruneIfNeeded(issuedAt);
    this.sessions.set(sessionId, { lastActivityAt: issuedAt, revoked: false });

    return {
      token: `${encodedPayload}.${signature}`,
      expiresIn: SESSION_INACTIVITY_TTL_SECONDS,
    };
  }

  verifyAndTouch(rawToken: string): AuthenticatedOwner {
    const parts = rawToken.split('.');
    if (parts.length !== 2 || !parts[0] || !parts[1]) {
      throw new UnauthorizedError('Credencial de sessão inválida.');
    }

    const [encodedPayload, providedSignature] = parts;
    const expectedSignature = this.sign(encodedPayload);

    const providedBuf = Buffer.from(providedSignature, 'utf8');
    const expectedBuf = Buffer.from(expectedSignature, 'utf8');
    if (providedBuf.length !== expectedBuf.length || !timingSafeEqual(providedBuf, expectedBuf)) {
      throw new UnauthorizedError('Credencial de sessão inválida.');
    }

    const payload = this.parsePayload(encodedPayload);
    const currentTime = this.now();
    const tracked = this.sessions.get(payload.jti);

    if (tracked) {
      if (tracked.revoked) {
        throw new UnauthorizedError('Sessão encerrada. Faça login novamente.');
      }
      if (currentTime - tracked.lastActivityAt >= SESSION_INACTIVITY_TTL_MS) {
        this.sessions.delete(payload.jti);
        throw new UnauthorizedError('Sessão expirada por inatividade. Faça login novamente.');
      }
      tracked.lastActivityAt = currentTime;
    } else {
      if (currentTime >= payload.exp) {
        throw new UnauthorizedError('Sessão expirada por inatividade. Faça login novamente.');
      }
      this.pruneIfNeeded(currentTime);
      this.sessions.set(payload.jti, { lastActivityAt: currentTime, revoked: false });
    }

    return {
      id: payload.sub,
      email: payload.email,
      name: payload.name,
      sessionId: payload.jti,
    };
  }

  revoke(sessionId: string): void {
    this.sessions.set(sessionId, { lastActivityAt: this.now(), revoked: true });
  }

  private sign(encodedPayload: string): string {
    return createHmac('sha256', this.secret).update(encodedPayload).digest('base64url');
  }

  private parsePayload(encodedPayload: string): SessionPayload {
    try {
      const parsed = JSON.parse(
        Buffer.from(encodedPayload, 'base64url').toString('utf8'),
      ) as Partial<SessionPayload>;

      if (
        typeof parsed.jti !== 'string' ||
        typeof parsed.sub !== 'number' ||
        !Number.isInteger(parsed.sub) ||
        typeof parsed.email !== 'string' ||
        typeof parsed.name !== 'string' ||
        typeof parsed.iat !== 'number' ||
        typeof parsed.exp !== 'number'
      ) {
        throw new UnauthorizedError('Credencial de sessão inválida.');
      }

      return parsed as SessionPayload;
    } catch (error) {
      if (error instanceof UnauthorizedError) throw error;
      throw new UnauthorizedError('Credencial de sessão inválida.');
    }
  }

  private pruneIfNeeded(currentTime: number): void {
    if (this.sessions.size < MAX_TRACKED_SESSIONS) return;
    for (const [id, entry] of this.sessions.entries()) {
      if (currentTime - entry.lastActivityAt >= SESSION_INACTIVITY_TTL_MS) {
        this.sessions.delete(id);
      }
    }
  }
}
