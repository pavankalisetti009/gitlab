import { defineConfig, type UserConfig } from 'vite';
import { defineLibraryConfig } from '@frontend-islands/vite-config';

export default defineConfig(
  (await defineLibraryConfig({
    entry: './src/main.ts',
    fileName: 'duo_next',
    name: 'DuoNext',
    tailwind: true,
    alias: {
      '@': './src',
    },
  })) as UserConfig,
);
