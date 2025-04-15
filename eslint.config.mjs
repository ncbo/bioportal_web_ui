import { defineConfig } from 'eslint/config';
import js from '@eslint/js';
import globals from 'globals';
import prettierPlugin from 'eslint-plugin-prettier';

export default defineConfig(
  [
    {
      files: [
        'app/javascript/**/*.{js,mjs,cjs}',
        'app/components/**/*.{js,mjs,cjs}',
      ],
      plugins: {
        js,
        prettier: prettierPlugin,
      },
      extends: ['js/recommended'],
      languageOptions: {
        globals: globals.browser,
      },
      rules: {
        'prettier/prettier': 'error',
      },
    },
  ],
  {
    ignores: [
      'app/assets/**',
      'public/browse/**',
      'vendor/**',
      'node_modules/**',
    ],
  },
);