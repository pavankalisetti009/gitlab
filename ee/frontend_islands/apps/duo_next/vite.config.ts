import path from 'node:path';
import vue, { type Api } from '@vitejs/plugin-vue';
import { defineConfig, type Plugin } from 'vite';
import tailwindcss from '@tailwindcss/vite';

// Let parent choose watch mode by env var if needed
const watchEnabled = process.env.WATCH === '1';

export default defineConfig({
  plugins: [
    vue({
      customElement: true,
      template: {
        compilerOptions: {
          isCustomElement: (tag) => tag.startsWith('fe-island-'),
        },
      },
    }) as Plugin<Api>,
    tailwindcss() as Plugin[],
  ],
  define: {
    __VUE_OPTIONS_API__: JSON.stringify(true), // set per your usage
    __VUE_PROD_DEVTOOLS__: JSON.stringify(false),
    'process.env.NODE_ENV': JSON.stringify(process.env.NODE_ENV),
  },
  build: {
    lib: {
      entry: './src/main.ts',
      formats: ['iife'], // easiest for legacy host
      name: 'DuoNext',
      fileName: () => 'duo_next.js',
    },
    rollupOptions: {
      // bundle everything, including Vue runtime
      external: [],
      output: {
        // CE + IIFE + dynamic imports don't mix; inline them just in case
        inlineDynamicImports: true,
      },
    },
    target: 'es2019',
    // Enable rollup watch when requested. (Using CLI --watch also works.)
    watch: watchEnabled
      ? {
          include: ['src/**'],
          exclude: ['node_modules/**', 'dist/**'],
        }
      : null,
  },
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
});
