import bcrypt from 'bcryptjs';
import type { FastifyInstance } from 'fastify';
import type pg from 'pg';
import request from 'supertest';
import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { buildApp } from '../../src/app.js';
import { SESSION_INACTIVITY_TTL_MS } from '../../src/modules/auth/session.manager.js';
import { createTestPool } from '../helpers/database.js';
import { resetData } from '../helpers/fixtures.js';

const TEST_SECRET = 'integration-test-session-secret-min-32-chars';
const OWNER_EMAIL = 'proprietario@tennishub.com';
const OWNER_PASSWORD = 'SenhaForte@2026';

describe('Autenticação do proprietário (/api/auth/* e /api/owner/*)', () => {
  let pool: pg.Pool;
  let app: FastifyInstance | null = null;
  let currentTime = 1_700_000_000_000;

  beforeAll(async () => {
    pool = createTestPool();
  });

  beforeEach(async () => {
    currentTime = 1_700_000_000_000;
    await resetData(pool);

    const passwordHash = await bcrypt.hash(OWNER_PASSWORD, 4);
    await pool.query('INSERT INTO owners (name, email, password_hash) VALUES ($1, $2, $3)', [
      'Proprietário TennisHub',
      OWNER_EMAIL,
      passwordHash,
    ]);

    app = await buildApp(
      {
        db: pool,
        sessionSecret: TEST_SECRET,
        now: () => currentTime,
      },
      {
        registerOwnerRoutes: async (ownerApi) => {
          ownerApi.get('/ping', async () => ({ ok: true }));
        },
      },
    );
    await app.ready();
  });

  afterEach(async () => {
    if (app) {
      await app.close();
      app = null;
    }
  });

  afterAll(async () => {
    await pool.end();
  });

  it('realiza login válido, devolve credencial de sessão e permite acessar /api/auth/me e /api/owner/*', async () => {
    const loginRes = await request(app!.server).post('/api/auth/login').send({
      email: '  PROPRIETARIO@TENNISHUB.COM ',
      password: OWNER_PASSWORD,
    });

    expect(loginRes.status).toBe(200);
    expect(loginRes.body).toMatchObject({
      expiresIn: 1800,
      owner: {
        id: 1,
        name: 'Proprietário TennisHub',
        email: OWNER_EMAIL,
      },
    });
    expect(typeof loginRes.body.token).toBe('string');
    expect(loginRes.headers['set-cookie']?.[0]).toContain('tennishub_session=');
    expect(loginRes.headers['set-cookie']?.[0]).toContain('HttpOnly');

    const token: string = loginRes.body.token;

    const meRes = await request(app!.server)
      .get('/api/auth/me')
      .set('Authorization', `Bearer ${token}`);
    expect(meRes.status).toBe(200);
    expect(meRes.body).toEqual({
      owner: {
        id: 1,
        name: 'Proprietário TennisHub',
        email: OWNER_EMAIL,
      },
    });

    const ownerRouteRes = await request(app!.server)
      .get('/api/owner/ping')
      .set('Authorization', `Bearer ${token}`);
    expect(ownerRouteRes.status).toBe(200);
    expect(ownerRouteRes.body).toEqual({ ok: true });
  });

  it('recusa e-mail inexistente e senha errada com a mesma mensagem genérica (401)', async () => {
    const unknownEmailRes = await request(app!.server).post('/api/auth/login').send({
      email: 'naoexiste@tennishub.com',
      password: OWNER_PASSWORD,
    });

    const wrongPasswordRes = await request(app!.server).post('/api/auth/login').send({
      email: OWNER_EMAIL,
      password: 'SenhaErrada123',
    });

    expect(unknownEmailRes.status).toBe(401);
    expect(wrongPasswordRes.status).toBe(401);
    expect(unknownEmailRes.body).toEqual({
      error: {
        code: 'UNAUTHORIZED',
        message: 'E-mail ou senha inválidos.',
      },
    });
    expect(wrongPasswordRes.body).toEqual(unknownEmailRes.body);
  });

  it('expira a sessão após 30 minutos de inatividade e retorna 401 na ação seguinte', async () => {
    const loginRes = await request(app!.server).post('/api/auth/login').send({
      email: OWNER_EMAIL,
      password: OWNER_PASSWORD,
    });
    const token: string = loginRes.body.token;

    // Avança 30 minutos sem nenhuma requisição
    currentTime += SESSION_INACTIVITY_TTL_MS;

    const expiredRes = await request(app!.server)
      .get('/api/owner/ping')
      .set('Authorization', `Bearer ${token}`);

    expect(expiredRes.status).toBe(401);
    expect(expiredRes.body.error.code).toBe('UNAUTHORIZED');
  });

  it('rejeita token adulterado com 401', async () => {
    const loginRes = await request(app!.server).post('/api/auth/login').send({
      email: OWNER_EMAIL,
      password: OWNER_PASSWORD,
    });
    const token: string = loginRes.body.token;
    const tampered = `${token.slice(0, -4)}xxxx`;

    const res = await request(app!.server)
      .get('/api/owner/ping')
      .set('Authorization', `Bearer ${tampered}`);

    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('UNAUTHORIZED');
  });

  it('bloqueia rotas /api/owner/* e /api/auth/me sem token com 401', async () => {
    const ownerPingRes = await request(app!.server).get('/api/owner/ping');
    const ownerMeRes = await request(app!.server).get('/api/owner/me');
    const authMeRes = await request(app!.server).get('/api/auth/me');

    expect(ownerPingRes.status).toBe(401);
    expect(ownerMeRes.status).toBe(401);
    expect(authMeRes.status).toBe(401);
  });

  it('encerra a sessão no logout e recusa o token em seguida', async () => {
    const loginRes = await request(app!.server).post('/api/auth/login').send({
      email: OWNER_EMAIL,
      password: OWNER_PASSWORD,
    });
    const token: string = loginRes.body.token;

    const logoutRes = await request(app!.server)
      .post('/api/auth/logout')
      .set('Authorization', `Bearer ${token}`);
    expect(logoutRes.status).toBe(204);

    const afterLogoutRes = await request(app!.server)
      .get('/api/auth/me')
      .set('Authorization', `Bearer ${token}`);
    expect(afterLogoutRes.status).toBe(401);
  });

  it('bloqueia tentativas de login após 5 falhas em 15 minutos (429)', async () => {
    for (let i = 0; i < 5; i++) {
      const failed = await request(app!.server)
        .post('/api/auth/login')
        .send({
          email: OWNER_EMAIL,
          password: `SenhaIncorreta${i}`,
        });
      expect(failed.status).toBe(401);
    }

    // Até mesmo com a senha correta, a 6ª tentativa dentro da janela é bloqueada
    const blocked = await request(app!.server).post('/api/auth/login').send({
      email: OWNER_EMAIL,
      password: OWNER_PASSWORD,
    });

    expect(blocked.status).toBe(429);
    expect(blocked.body.error.code).toBe('TOO_MANY_ATTEMPTS');
  });
});
