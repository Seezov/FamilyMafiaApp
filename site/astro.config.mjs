import { defineConfig } from 'astro/config';

export default defineConfig({
  site: 'https://seezov.github.io',
  base: '/FamilyMafiaApp',
  trailingSlash: 'always',
  build: { format: 'directory' },
});
