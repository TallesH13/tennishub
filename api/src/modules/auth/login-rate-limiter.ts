import { TooManyRequestsError } from '../../shared/errors.js';

export const DEFAULT_MAX_LOGIN_ATTEMPTS = 5;
export const DEFAULT_LOGIN_WINDOW_MS = 15 * 60 * 1000;
const MAX_ATTEMPTS_PER_IP = 20;

export type LoginRateLimiterOptions = {
  maxAttempts?: number;
  windowMs?: number;
  now?: () => number;
};

/**
 * Limita tentativas falhas de login em janela deslizante para mitigar força bruta.
 */
export class LoginRateLimiter {
  private readonly attempts = new Map<string, number[]>();
  private readonly maxAttempts: number;
  private readonly windowMs: number;
  private readonly now: () => number;

  constructor(options: LoginRateLimiterOptions = {}) {
    this.maxAttempts = options.maxAttempts ?? DEFAULT_MAX_LOGIN_ATTEMPTS;
    this.windowMs = options.windowMs ?? DEFAULT_LOGIN_WINDOW_MS;
    this.now = options.now ?? (() => Date.now());
  }

  assertAllowed(ip: string, email: string): void {
    const currentTime = this.now();
    const accountKey = this.accountKey(ip, email);
    const ipKey = this.ipKey(ip);

    const accountFailures = this.activeTimestamps(accountKey, currentTime);
    const ipFailures = this.activeTimestamps(ipKey, currentTime);

    if (accountFailures.length >= this.maxAttempts || ipFailures.length >= MAX_ATTEMPTS_PER_IP) {
      throw new TooManyRequestsError(
        'Muitas tentativas de login falhas. Tente novamente em 15 minutos.',
      );
    }
  }

  recordFailure(ip: string, email: string): void {
    const currentTime = this.now();
    this.pushTimestamp(this.accountKey(ip, email), currentTime);
    this.pushTimestamp(this.ipKey(ip), currentTime);
  }

  recordSuccess(ip: string, email: string): void {
    this.attempts.delete(this.accountKey(ip, email));
  }

  private accountKey(ip: string, email: string): string {
    return `${ip}:${email.trim().toLowerCase()}`;
  }

  private ipKey(ip: string): string {
    return `${ip}:*`;
  }

  private activeTimestamps(key: string, currentTime: number): number[] {
    const list = this.attempts.get(key);
    if (!list) return [];

    const cutoff = currentTime - this.windowMs;
    const valid = list.filter((ts) => ts > cutoff);

    if (valid.length === 0) {
      this.attempts.delete(key);
    } else if (valid.length !== list.length) {
      this.attempts.set(key, valid);
    }

    return valid;
  }

  private pushTimestamp(key: string, timestamp: number): void {
    const valid = this.activeTimestamps(key, timestamp);
    valid.push(timestamp);
    this.attempts.set(key, valid);
  }
}
