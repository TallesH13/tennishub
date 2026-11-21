import { defineConfig } from 'vitest/config';

// Localmente, a TEST_DATABASE_URL fica no api/.env (fora do Git).
try {
  process.loadEnvFile('.env');
} catch {
  // sem .env: usa as variáveis já definidas (é o caso do CI)
}

export default defineConfig({
  test: {
    testTimeout: 20_000,
    hookTimeout: 30_000,
    // Os testes de integração compartilham o mesmo banco: um arquivo por vez.
    fileParallelism: false,
    projects: [
      {
        extends: true,
        test: {
          name: 'unit',
          include: ['test/unit/**/*.test.ts'],
        },
      },
      {
        extends: true,
        test: {
          name: 'integration',
          include: ['test/integration/**/*.test.ts'],
          globalSetup: ['test/setup/global-setup.ts'],
        },
      },
    ],
  },
});
