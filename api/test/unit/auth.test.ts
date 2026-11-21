import { describe, expect, it } from 'vitest';
import { LoginRateLimiter } from '../../src/modules/auth/login-rate-limiter.js';
import {
  SESSION_INACTIVITY_TTL_MS,
  SessionManager,
} from '../../src/modules/auth/session.manager.js';
import { TooManyRequestsError, UnauthorizedError } from '../../src/shared/errors.js';

const SECRET = 'unit-test-session-secret-with-at-least-32-chars';

describe('SessionManager (unidade)', () => {
  it('emite e valida uma credencial de sessão do proprietário', () => {
    let now = 1_700_000_000_000;
    const manager = new SessionManager(SECRET, () => now);

    const { token, expiresIn } = manager.issue({
      id: 1,
      name: 'Proprietário Teste',
      email: 'dono@tennishub.com',
    });

    expect(expiresIn).toBe(1800);
    now += 5 * 60 * 1000; // 5 minutos depois

    const session = manager.verifyAndTouch(token);
    expect(session).toMatchObject({
      id: 1,
      name: 'Proprietário Teste',
      email: 'dono@tennishub.com',
    });
  });

  it('expira a sessão após 30 minutos de inatividade (D03)', () => {
    let now = 1_700_000_000_000;
    const manager = new SessionManager(SECRET, () => now);

    const { token } = manager.issue({
      id: 1,
      name: 'Proprietário Teste',
      email: 'dono@tennishub.com',
    });

    // Atividade aos 20 minutos renova o contador de inatividade
    now += 20 * 60 * 1000;
    expect(manager.verifyAndTouch(token).id).toBe(1);

    // Aos 45 minutos (25 min desde a última atividade) ainda está ativa
    now += 25 * 60 * 1000;
    expect(manager.verifyAndTouch(token).id).toBe(1);

    // Após 30 minutos sem nenhuma atividade, expira
    now += SESSION_INACTIVITY_TTL_MS;
    expect(() => manager.verifyAndTouch(token)).toThrow(UnauthorizedError);
  });

  it('rejeita token adulterado no payload ou na assinatura', () => {
    const manager = new SessionManager(SECRET);
    const { token } = manager.issue({
      id: 1,
      name: 'Proprietário Teste',
      email: 'dono@tennishub.com',
    });

    const [encodedPayload, signature] = token.split('.');
    const tamperedPayload = Buffer.from(
      JSON.stringify({
        jti: 'fake',
        sub: 999,
        email: 'invasor@tennishub.com',
        name: 'Invasor',
        iat: Date.now(),
        exp: Date.now() + 999_999,
      }),
      'utf8',
    ).toString('base64url');

    expect(() => manager.verifyAndTouch(`${tamperedPayload}.${signature}`)).toThrow(
      UnauthorizedError,
    );
    expect(() => manager.verifyAndTouch(`${encodedPayload}.assinatura-invalida`)).toThrow(
      UnauthorizedError,
    );
    expect(() => manager.verifyAndTouch('token-sem-ponto')).toThrow(UnauthorizedError);
  });

  it('invalida a sessão imediatamente após logout (revoke)', () => {
    const manager = new SessionManager(SECRET);
    const { token } = manager.issue({
      id: 1,
      name: 'Proprietário Teste',
      email: 'dono@tennishub.com',
    });

    const session = manager.verifyAndTouch(token);
    manager.revoke(session.sessionId);

    expect(() => manager.verifyAndTouch(token)).toThrow(UnauthorizedError);
  });
});

describe('LoginRateLimiter (unidade)', () => {
  it('bloqueia após 5 falhas em 15 minutos e libera após a janela expirar', () => {
    let now = 1_700_000_000_000;
    const limiter = new LoginRateLimiter({ now: () => now });

    for (let i = 0; i < 5; i++) {
      limiter.assertAllowed('127.0.0.1', 'dono@tennishub.com');
      limiter.recordFailure('127.0.0.1', 'dono@tennishub.com');
      now += 1000;
    }

    expect(() => limiter.assertAllowed('127.0.0.1', 'dono@tennishub.com')).toThrow(
      TooManyRequestsError,
    );

    // Após 15 minutos da primeira falha, a janela desliza e libera nova tentativa
    now += 15 * 60 * 1000;
    expect(() => limiter.assertAllowed('127.0.0.1', 'dono@tennishub.com')).not.toThrow();
  });

  it('zera o contador da conta após login bem-sucedido', () => {
    const limiter = new LoginRateLimiter();

    for (let i = 0; i < 4; i++) {
      limiter.recordFailure('127.0.0.1', 'dono@tennishub.com');
    }
    limiter.recordSuccess('127.0.0.1', 'dono@tennishub.com');

    expect(() => limiter.assertAllowed('127.0.0.1', 'dono@tennishub.com')).not.toThrow();
  });
});
