import js from '@eslint/js';
import pluginVue from 'eslint-plugin-vue';
import * as parserVue from 'vue-eslint-parser';
import * as parserTypeScript from '@typescript-eslint/parser';
import pluginTypeScript from '@typescript-eslint/eslint-plugin';
import pluginVitest from 'eslint-plugin-vitest';

export default [
  // Base JavaScript configuration
  js.configs.recommended,

  // Vue 3 configuration
  ...pluginVue.configs['flat/recommended'],

  // Global configuration
  {
    files: ['**/*.{js,ts,vue}'],
    languageOptions: {
      parser: parserVue,
      parserOptions: {
        parser: parserTypeScript,
        ecmaVersion: 'latest',
        sourceType: 'module',
      },
      globals: {
        // Vite globals
        __VUE_OPTIONS_API__: 'readonly',
        __VUE_PROD_DEVTOOLS__: 'readonly',
        // Browser globals
        customElements: 'readonly',
        HTMLElement: 'readonly',
        // Node.js globals for config files
        process: 'readonly',
      },
    },
    plugins: {
      vue: pluginVue,
      '@typescript-eslint': pluginTypeScript,
    },
    rules: {
      // Vue 3 specific rules
      'vue/multi-word-component-names': 'off',
      'vue/html-closing-bracket-newline': 'off',
      'vue/multiline-html-element-content-newline': 'off',
      'vue/singleline-html-element-content-newline': 'off',
      'vue/max-attributes-per-line': 'off',
      'vue/no-v-html': 'off',
      'vue/require-default-prop': 'error',
      'vue/require-explicit-emits': 'error',
      'vue/no-unused-vars': 'error',

      // TypeScript rules
      '@typescript-eslint/no-unused-vars': [
        'error',
        {
          argsIgnorePattern: '^_',
          varsIgnorePattern: '^_',
        },
      ],
      '@typescript-eslint/explicit-function-return-type': 'off',
      '@typescript-eslint/explicit-module-boundary-types': 'off',
      '@typescript-eslint/no-explicit-any': 'warn',

      // General rules
      'no-console': 'warn',
      'no-debugger': 'warn',
      'prefer-const': 'error',
    },
    settings: {
      vue: {
        version: '3',
      },
    },
  },

  // TypeScript files specific configuration
  {
    files: ['**/*.ts', '**/*.tsx'],
    languageOptions: {
      parser: parserTypeScript,
    },
    rules: {
      ...pluginTypeScript.configs.recommended.rules,
    },
  },

  // Test files configuration
  {
    files: ['**/*_spec.{js,ts}', '**/*.spec.{js,ts}', '**/__tests__/**/*.{js,ts}'],
    plugins: {
      vitest: pluginVitest,
    },
    languageOptions: {
      globals: {
        ...pluginVitest.environments.env.globals,
        global: 'writable',
        HTMLElement: 'readonly',
      },
      parserOptions: {
        projectService: true,
      },
    },
    rules: {
      ...pluginVitest.configs.recommended.rules,
      'no-console': 'off',
      '@typescript-eslint/no-explicit-any': 'warn',
    },
  },

  // Config files
  {
    files: ['*.config.{js,ts}', '*.setup.{js,ts}'],
    languageOptions: {
      globals: {
        process: 'readonly',
        __dirname: 'readonly',
        module: 'readonly',
        require: 'readonly',
      },
    },
    rules: {
      'no-console': 'off',
      '@typescript-eslint/no-var-requires': 'off',
      '@typescript-eslint/no-explicit-any': 'warn',
    },
  },

  // CommonJS files
  {
    files: ['**/*.cjs'],
    languageOptions: {
      globals: {
        module: 'readonly',
        require: 'readonly',
        __dirname: 'readonly',
        __filename: 'readonly',
        process: 'readonly',
      },
    },
    rules: {
      'no-console': 'off',
    },
  },

  // Ignore patterns
  {
    ignores: [
      'node_modules/**',
      'dist/**',
      'coverage/**',
      '.vscode/**',
      'tmp/**',
      '*.log',
      'junit_jest.xml',
    ],
  },
];
