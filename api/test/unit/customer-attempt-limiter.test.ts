import { describe, expect, it } from 'vitest';
import { CustomerAttemptLimiter } from '../../src/modules/bookings/customer-attempt-limiter.js';

function limiterAt(start = 0) {
  const clock = { now: start };
  const limiter = new CustomerAttemptLimiter({ now: () => clock.now });
  return { limiter, clock };
}

describe('limite de tentativas do cliente (#17)', () => {
  it('bloqueia o IP depois de 10 falhas em 15 minutos', () => {
    const { limiter } = limiterAt();
    for (let i = 0; i < 10; i++) {
      limiter.assertAllowed('1.1.1.1', `319000000${String(i).padStart(2, '0')}`);
      limiter.recordFailure('1.1.1.1', `319000000${String(i).padStart(2, '0')}`);
    }

    expect(() => limiter.assertAllowed('1.1.1.1', '31911112222')).toThrow(
      expect.objectContaining({ statusCode: 429, code: 'TOO_MANY_ATTEMPTS' }),
    );
    expect(() => limiter.assertAllowed('2.2.2.2', '31911112222')).not.toThrow();
  });

  it('bloqueia o telefone depois de 10 falhas, mesmo vindas de IPs diferentes', () => {
    const { limiter } = limiterAt();
    for (let i = 0; i < 10; i++) limiter.recordFailure(`10.0.0.${i}`, '31999990000');

    expect(() => limiter.assertAllowed('10.0.0.99', '31999990000')).toThrow(
      expect.objectContaining({ statusCode: 429 }),
    );
    expect(() => limiter.assertAllowed('10.0.0.99', '31988887777')).not.toThrow();
  });

  it('9 falhas ainda permitem tentar, e as falhas expiram depois de 15 minutos', () => {
    const { limiter, clock } = limiterAt();
    for (let i = 0; i < 9; i++) limiter.recordFailure('1.1.1.1', '31999990000');
    expect(() => limiter.assertAllowed('1.1.1.1', '31999990000')).not.toThrow();

    limiter.recordFailure('1.1.1.1', '31999990000');
    expect(() => limiter.assertAllowed('1.1.1.1', '31999990000')).toThrow();

    clock.now += 15 * 60 * 1000 + 1;
    expect(() => limiter.assertAllowed('1.1.1.1', '31999990000')).not.toThrow();
  });
});
