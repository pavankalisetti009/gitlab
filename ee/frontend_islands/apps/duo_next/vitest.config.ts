import path from 'node:path';
import vue, { type Api } from '@vitejs/plugin-vue';
import { defineConfig, type Plugin } from 'vitest/config';

const inCI = !!process.env.CI;

export default defineConfig({
  plugins: [vue() as Plugin<Api>],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
  test: {
    globals: true,
    environment: 'jsdom',
    include: ['src/**/*_spec.{js,ts}'],
    reporters: inCI ? ['default', 'junit'] : ['default'],
    outputFile: {
      junit: './junit_jest.xml',
    },
    coverage: {
      provider: 'v8',
      reporter: inCI ? ['json', 'lcov', 'text', 'clover'] : ['text', 'html'],
      exclude: ['node_modules/**', 'test/**', '**/*.d.ts', '**/*.config.*', 'dist/**'],
      include: ['src/**/*.{js,ts,vue}'],
      thresholds: {
        global: {
          branches: 80,
          functions: 80,
          lines: 80,
          statements: 80,
        },
      },
    },
  },
});
