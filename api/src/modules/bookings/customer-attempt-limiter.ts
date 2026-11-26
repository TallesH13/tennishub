import { TooManyRequestsError } from '../../shared/errors.js';

export const DEFAULT_MAX_CUSTOMER_FAILURES = 10;
export const DEFAULT_CUSTOMER_WINDOW_MS = 15 * 60 * 1000;

export type CustomerAttemptLimiterOptions = {
  maxFailures?: number;
  windowMs?: number;
  now?: () => number;
};

/**
 * Limita tentativas falhas de achar uma reserva por código e telefone, por IP e por
 * telefone, para dificultar adivinhar códigos. Fica em memória: vale por processo da API.
 */
export class CustomerAttemptLimiter {
  private readonly failures = new Map<string, number[]>();
  private readonly maxFailures: number;
  private readonly windowMs: number;
  private readonly now: () => number;

  constructor(options: CustomerAttemptLimiterOptions = {}) {
    this.maxFailures = options.maxFailures ?? DEFAULT_MAX_CUSTOMER_FAILURES;
    this.windowMs = options.windowMs ?? DEFAULT_CUSTOMER_WINDOW_MS;
    this.now = options.now ?? (() => Date.now());
  }

  assertAllowed(ip: string, phone: string): void {
    const currentTime = this.now();
    const blocked = this.keys(ip, phone).some(
      (key) => this.active(key, currentTime).length >= this.maxFailures,
    );
    if (blocked) {
      throw new TooManyRequestsError(
        'Muitas tentativas sem encontrar a reserva. Tente novamente em 15 minutos.',
      );
    }
  }

  recordFailure(ip: string, phone: string): void {
    const currentTime = this.now();
    for (const key of this.keys(ip, phone)) {
      const list = this.active(key, currentTime);
      list.push(currentTime);
      this.failures.set(key, list);
    }
  }

  private keys(ip: string, phone: string): string[] {
    return phone ? [`ip:${ip}`, `phone:${phone}`] : [`ip:${ip}`];
  }

  private active(key: string, currentTime: number): number[] {
    const cutoff = currentTime - this.windowMs;
    const valid = (this.failures.get(key) ?? []).filter((ts) => ts > cutoff);
    if (valid.length === 0) this.failures.delete(key);
    else this.failures.set(key, valid);
    return valid;
  }
}
