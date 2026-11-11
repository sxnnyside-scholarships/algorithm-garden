# Changelog

All notable changes to **Algorithm Garden** are documented here.

This project follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added

- Four additional PRD Algorithm Gardens (`CellularDomain`, `GraphDomain`, `FractalDomain`, `EvolutionDomain`) across `GardenRunner`, `GardenApi` seed catalog, and `web/` stage visualizers.
- 12 new reference implementations and 6 auto-verified exercises covering Conway's Game of Life, HighLife (`B36/S23`), Brian's Brain, Graph BFS/DFS, Kruskal's MST, Connected Components, Mandelbrot Set, Julia Set, Recursive Botanical Tree, Genetic Algorithm, and Elitist Mutation Climber.
- Interactive cellular grid painting, 2× complex-plane fractal zoom on click, graph topology presets, evolutionary fitness convergence charts, and full `en`/`es` translations across all 6 gardens.

---

## [0.1.0] — 2026-11-11

### Added

- Isolated Julia runner (`GardenRunner`) with AST allowlist sandbox, resource caps, precompiled sysimage, and warm `--warm-one-shot` container protocol.
- `TrackedVector` and `TrackedGrid` domain abstractions emitting normalized execution trace events and metrics.
- Julia HTTP API (`GardenApi` with `Oxygen.jl`) supporting SQLite and PostgreSQL storage, authentication, rate limiting, algorithm catalog, saved experiments, exercise verification, and warm Docker container pooling.
- Interactive Vue 3 + TypeScript web workspace featuring CodeMirror 6 Julia editing, deterministic trace playback controls, inspector metrics, and visualizers for Sorting Garden and Pathfinding Garden.
- Bilingual (`en` / `es`) localization across frontend UI, API responses, and runner error diagnostics.
- Dockerfiles for `runner`, `api`, and `web`, root `Justfile` orchestration, `docker-compose.yml`, and self-hosted deployment documentation.

---

[Unreleased]: https://github.com/sxnnyside-scholarships/algorithm-garden/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/sxnnyside-scholarships/algorithm-garden/releases/tag/v0.1.0

