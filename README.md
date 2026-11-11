# Algorithm Garden

![Version](https://img.shields.io/badge/version-0.1.0-blue)
![License](https://img.shields.io/badge/License-MIT-green)
[![CI](https://github.com/sxnnyside-scholarships/algorithm-garden/workflows/CI/badge.svg)](https://github.com/sxnnyside-scholarships/algorithm-garden/actions)

<p align="center">
  <strong>Experimentation-first ✦ Sandboxed Julia Runtime ✦ Self-Hostable</strong><br>
  <em>An interactive educational platform where programming students inspect, modify, run, and visualize Julia algorithms.</em>
</p>

<p align="center">
  <a href="#about">About</a> ✦
  <a href="#features">Features</a> ✦
  <a href="#installation">Installation</a> ✦
  <a href="#usage">Usage</a> ✦
  <a href="#architecture">Architecture</a> ✦
  <a href="#contributing">Contributing</a>
</p>

---

## About

**Algorithm Garden** is an interactive web workspace built for computer science students and self-learners to study algorithms through direct code experimentation in Julia.

Instead of watching fixed, pre-recorded animations disconnected from real source code, students edit actual Julia implementations, execute them inside resource-capped isolated containers, and replay the resulting normalized trace events step by step. Every comparison, swap, cell visit, frontier push, and path decision seen on screen comes directly from the code executed.

### Philosophy

> *"Don't just learn how algorithms work. Change them and find out."*

This is a **Sxnnyside Scholarships** project, part of the [Sxnnyside Project](https://www.sxnnysideproject.com/en/realms/sxnnyside-scholarships/) ecosystem.

## Features

- **Direct Julia Code Editing**: Integrated CodeMirror 6 workspace with Julia syntax highlighting, per-line error markers, and instant reset to reference or starter code.
- **Deterministic Trace Playback**: Step forward, step backward, pause, resume, scrub timeline progress, and adjust playback speed without holding server workers open.
- **Sandboxed Container Execution**: Student code runs in pre-warmed Docker containers (`--network=none`, `--read-only`, non-root user, CPU/memory/PID/event caps) using a precompiled `GardenRunner` sysimage.
- **Sorting Garden**: Interactive array bar visualizer and guided exercises for Bubble Sort, Selection Sort, Insertion Sort, Merge Sort, Quick Sort, and Heap Sort.
- **Pathfinding Garden**: Interactive grid editor (start/goal placement, obstacles, weighted cells, maze presets) and visualizer for BFS, DFS, Dijkstra, and A*.
- **Cellular Garden**: Interactive 2D cellular grid and live `B/S` rule editor for Conway's Game of Life, HighLife (`B36/S23`), and Brian's Brain.
- **Graph Garden**: Weighted/directed botanical network visualizer for Graph BFS, Graph DFS, Kruskal's MST, and Connected Components.
- **Fractal Garden**: Complex-plane escape rasterizer with interactive click-to-zoom (Mandelbrot and Julia sets) plus depth-layered SVG rendering for Recursive Botanical Trees.
- **Evolution Garden**: Genetic algorithm convergence curves and chromosome-vs-target comparison matrices for tournament selection, crossover, mutation, and elitist hill climbing.
- **Personal Workspaces & Verification**: User accounts, saved experiments, forked modifications, and automated Julia test-case verification for incomplete exercises.
- **Bilingual Experience (`en` / `es`)**: Full UI, API error responses, and sandbox compiler/runtime diagnostics localized across English and Spanish.

## Installation

### Prerequisites

- [Just](https://github.com/casey/just) (`>= 1.30`)
- [Julia](https://julialang.org/) (`1.13.3`)
- [Bun](https://bun.sh/) (`>= 1.4.4`)
- [Docker](https://www.docker.com/) (required for container-isolated execution and Compose self-hosting)

### From Source

```bash
git clone https://github.com/sxnnyside-scholarships/algorithm-garden.git
cd algorithm-garden

just install
```

### Self-Hosted Stack (Docker / Linux)

#### Single-Container (Fastest / One-Click)

```bash
docker run -d --name algorithm-garden \
  -p 8080:8080 \
  -e APP_ENV=production \
  -e AUTH_TOKEN_SECRET="$(openssl rand -hex 32)" \
  -v garden_data:/app/data \
  ghcr.io/sxnnyside-scholarships/algorithm-garden:0.1.0
```

#### Full Multi-Container Stack (Docker Compose with Container-Isolated Runner)

```bash
cp .env.example .env
DOCKER_GID=$(stat -c '%g' /var/run/docker.sock 2>/dev/null || echo 0) docker compose up -d --wait
```

Or run `just docker-up` from the repository root (`just` auto-detects `DOCKER_GID` on Linux and macOS).

For Coolify (single-resource or multi-service) and production hardening, see [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md).

## Usage

```bash
# Start both backend (api/) and frontend (web/) for local development
just dev

# Or run each service individually in separate terminals
just dev-back
just dev-front

# Run formatting checks, lint, typecheck, and all test suites
just check
```

When running locally with `just dev`, the web app is available at `http://127.0.0.1:5173` and proxies `/api` and `/health` requests to the API server at `http://127.0.0.1:8080`. If the Docker runner image is not built locally, `just dev-back` automatically falls back to `RUNNER_MODE=subprocess` so contributors can iterate immediately.

## Architecture

```text
algorithm-garden/
├── runner/    # Isolated Julia execution engine, domain abstractions & sysimage (GardenRunner)
├── api/       # Julia (Oxygen.jl) HTTP backend, auth, persistence & warm container pool (GardenApi)
├── web/       # Vue 3 + TypeScript + CodeMirror 6 + Pinia interactive workspace
├── docs/      # Execution contract, deployment guide, and domain glossary
└── scripts/   # Git hook installers and Conventional Commit validators
```

- HTTP endpoint specification: [API.md](API.md)
- Execution trace & event contract: [docs/EXECUTION_CONTRACT.md](docs/EXECUTION_CONTRACT.md)
- Self-hosted deployment guide: [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)

## Contributing

Contributions are accepted. See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

Before contributing, read the [Code of Conduct](CODE_OF_CONDUCT.md).

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

<p align="center">
  <strong>Algorithm Garden</strong> — A Sxnnyside Scholarships Project<br>
  <em>&copy; 2026 Sxnnyside Project</em>
</p>
