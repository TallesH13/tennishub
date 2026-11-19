import { defineConfig } from 'vitest/config';

// Localmente, as variáveis do banco de teste podem ficar em api/.env.test (fora do Git).
try {
  process.loadEnvFile('.env.test');
} catch {
  // sem .env.test: usa as variáveis já definidas (é o caso do CI)
}

export default defineConfig({
  test: {
    include: ['test/**/*.test.ts'],
    globalSetup: ['test/setup/global-setup.ts'],
    // Os testes de integração compartilham o mesmo banco: um arquivo por vez.
    fileParallelism: false,
    testTimeout: 20_000,
    hookTimeout: 30_000,
  },
});
