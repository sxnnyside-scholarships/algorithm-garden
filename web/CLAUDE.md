# web — Algorithm Garden Frontend

Vue 3 + TypeScript + Vite SPA managed with Bun (`1.4.4`).

## Placement Table

| Kind                             | Location                                                            | Naming              |
| -------------------------------- | ------------------------------------------------------------------- | ------------------- |
| Bootstrap (`main.ts`, `App.vue`) | `src/app/`                                                          | fixed names         |
| Router                           | `src/app/router/`                                                   | kebab-case          |
| Layouts                          | `src/app/layouts/<name>-layout.vue`                                 | `-layout` suffix    |
| Feature code                     | `src/features/<feature>/{components,composables,stores,api,types}/` | kebab-case files    |
| Pages / route views              | `src/features/<feature>/pages/<name>-page.vue`                      | `-page` suffix      |
| Shared UI primitives             | `src/shared/ui/`                                                    | kebab-case          |
| Shared libs / theme / api        | `src/shared/<concept>/`                                             | named by concept    |
| Pinia store                      | `src/features/<feature>/stores/<feature>-store.ts`                  | `use<Feature>Store` |
| Static assets                    | `public/` or `src/assets/`                                          | kebab-case          |
| Tests                            | `tests/` mirroring `src/`                                           | `<name>.test.ts`    |

## Design & Icon Rules

- Design system: **Floral / Bloomcore / Solarpunk** (`src/shared/theme/tokens.css`) supporting both light and dark modes.
- Icons: use **MingCute** exclusively (`@iconify-json/mingcute` via `@/shared/ui/mingcute-icon.vue`).
- Use `<script setup lang="ts">` with strict TypeScript; never use `v-html` on user/API-supplied strings.
- **TypeScript pin:** `typescript` stays on `^5.8.2` until `vue-tsc` officially supports TypeScript 7.0 (`tsgo`); do not bump major versions independently.

## Commands

- Run tests: `bun run test`
- Quality gate: `bun run check` (or `just check` from root)
