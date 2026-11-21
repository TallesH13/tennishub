import bcrypt from 'bcryptjs';
import { UnauthorizedError } from '../../shared/errors.js';
import type { AuthRepository, PublicOwner } from './auth.repository.js';
import type { LoginRateLimiter } from './login-rate-limiter.js';
import type { AuthenticatedOwner, SessionManager } from './session.manager.js';

/**
 * Hash bcrypt válido usado quando o e-mail não existe para manter tempo de resposta
 * constante e evitar enumeração de contas por temporização.
 */
const DUMMY_PASSWORD_HASH = '$2b$12$C6UzMDM.H6dfI/f/IKcEeO9sB6xP0lM2gG9iF4z6j4f8H3.Q1W8eK';

const INVALID_CREDENTIALS_MESSAGE = 'E-mail ou senha inválidos.';

export type LoginResult = {
  token: string;
  expiresIn: number;
  owner: PublicOwner;
};

export class AuthService {
  constructor(
    private readonly repository: AuthRepository,
    private readonly sessions: SessionManager,
    private readonly rateLimiter: LoginRateLimiter,
  ) {}

  async login(input: { email: string; password: string; ip: string }): Promise<LoginResult> {
    const normalizedEmail = input.email.trim().toLowerCase();
    this.rateLimiter.assertAllowed(input.ip, normalizedEmail);

    const owner = await this.repository.findByEmail(normalizedEmail);
    const hashToCompare = owner ? owner.passwordHash : DUMMY_PASSWORD_HASH;
    const passwordMatches = await bcrypt.compare(input.password, hashToCompare);

    if (!owner || !passwordMatches) {
      this.rateLimiter.recordFailure(input.ip, normalizedEmail);
      throw new UnauthorizedError(INVALID_CREDENTIALS_MESSAGE);
    }

    this.rateLimiter.recordSuccess(input.ip, normalizedEmail);

    const publicOwner: PublicOwner = {
      id: owner.id,
      name: owner.name,
      email: owner.email,
    };
    const { token, expiresIn } = this.sessions.issue(publicOwner);

    return {
      token,
      expiresIn,
      owner: publicOwner,
    };
  }

  logout(sessionId: string): void {
    this.sessions.revoke(sessionId);
  }

  async getCurrentOwner(session: AuthenticatedOwner): Promise<PublicOwner> {
    const owner = await this.repository.findById(session.id);
    if (!owner) {
      this.sessions.revoke(session.sessionId);
      throw new UnauthorizedError('Sessão inválida.');
    }
    return owner;
  }
}
