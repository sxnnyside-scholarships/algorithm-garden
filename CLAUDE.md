# Algorithm Garden — Repository Guide

## Topology

This repository is a **polyglot monorepo** with three language/runtime boundaries coordinated from the root `Justfile`:

| Path | Role | Stack |
|---|---|---|
| `runner/` | Isolated Julia execution sandbox & sysimage (`GardenRunner`) | Julia `1.13.3` + Docker |
| `api/` | HTTP API server, auth, persistence, runner orchestrator | Julia `1.13.3` (`Oxygen.jl`) + SQLite / PostgreSQL |
| `web/` | Interactive web workspace, CodeMirror editor, visualizers | TypeScript + Vue 3 + Vite + Bun (`1.4.4`) |
| `docs/` | Architecture, execution contract, glossary, deployment | Markdown |
| `scripts/` | Git hook installers and Conventional Commit validators | POSIX Bash |

## Task Runner (`just`)

Always use root `just` recipes as the primary interface:

- `just install` — install dependencies and wire Git hooks (`pre-commit`, `commit-msg`)
- `just dev` — start API backend + Vite frontend together with coordinated shutdown
- `just dev-back` — start Julia API backend (`subprocess` fallback if Docker runner image is unavailable)
- `just dev-front` — start Vite frontend dev server
- `just check` — non-mutating quality gate (`format-check`, `lint`, `typecheck`, `test`)
- `just format` — format all source files
- `just test` — run all test suites
- `just build` — build frontend bundle and runner Docker image
- `just docker-build` — build runner, api, and web Docker images

## Where Things Go

- Domain glossary: [docs/glossary.md](docs/glossary.md)
- Execution & visualization event contract: [docs/EXECUTION_CONTRACT.md](docs/EXECUTION_CONTRACT.md)
- HTTP API contract (must update in the same commit as route changes): [API.md](API.md)
- Do not add ad-hoc top-level folders; place code inside `runner/`, `api/`, or `web/` according to each boundary's conventions.

## Coding & Git Conventions

- **Commits:** Conventional Commits (`feat`, `fix`, `docs`, `refactor`, `test`, `build`, `ci`, `chore`).
- **Pre-commit:** `just check` must pass before committing.
- **Security:** Student code executes strictly inside isolated `runner/` containers (`--network=none`, `--read-only`, non-root, CPU/memory/PID/event caps). Never trust client input or interpolate user strings into shell commands or SQL.

