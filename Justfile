# Algorithm Garden — Root Task Runner
# Polyglot monorepo orchestrator for runner/ (Julia), api/ (Julia), and web/ (Vue 3 / Bun).

set shell := ["bash", "-euo", "pipefail", "-c"]

_julia_env := 'if [ -z "${JULIA_DEPOT_PATH:-}" ] && [ ! -w "${HOME}/.julia" ] 2>/dev/null; then mkdir -p /tmp/ag-julia-depot && export JULIA_DEPOT_PATH=/tmp/ag-julia-depot JULIA_PKG_OFFLINE=true; fi'

# Bootstrap dependencies and install git hooks across all packages
install:
    bash scripts/install-hooks.sh
    {{ _julia_env }}; if [ -f runner/Project.toml ]; then julia --project=runner -e 'using Pkg; Pkg.instantiate()'; fi
    {{ _julia_env }}; if [ -f api/Project.toml ]; then julia --project=api -e 'using Pkg; Pkg.instantiate()'; fi
    if [ -f web/package.json ]; then cd web && bun install --frozen-lockfile || bun install; fi

# Start backend API locally (uses Docker runner if available, otherwise subprocess fallback)
dev-back:
    {{ _julia_env }}; \
    if [ -f .env ]; then set -a; source .env; set +a; fi; \
    if [ -z "${RUNNER_MODE:-}" ]; then \
        if command -v docker >/dev/null 2>&1 && docker image inspect "${RUNNER_IMAGE:-algorithm-garden-runner:0.1.0}" >/dev/null 2>&1; then \
            export RUNNER_MODE=docker; \
        else \
            export RUNNER_MODE=subprocess RUNNER_POOL_SIZE=0; \
            echo "[dev-back] Docker runner image not available; using RUNNER_MODE=subprocess"; \
        fi; \
    fi; \
    exec julia --project=api api/src/main.jl

# Start frontend Vite dev server (proxies /api and /health to 127.0.0.1:8080)
dev-front:
    cd web && exec bun run dev

# Start full local dev stack (backend + frontend) with coordinated shutdown
dev:
    if [ -f .env ]; then set -a; source .env; set +a; fi; \
    just dev-back & \
    BACK_PID=$!; \
    cleanup() { kill "$BACK_PID" 2>/dev/null || true; wait "$BACK_PID" 2>/dev/null || true; }; \
    trap cleanup EXIT INT TERM; \
    API_URL="http://127.0.0.1:${PORT:-8080}/health"; \
    echo "[dev] Waiting for API readiness at $API_URL ..."; \
    for _ in $(seq 1 60); do \
        if ! kill -0 "$BACK_PID" 2>/dev/null; then \
            echo "[dev] Backend exited unexpectedly." >&2; \
            wait "$BACK_PID"; \
            exit 1; \
        fi; \
        if command -v curl >/dev/null 2>&1 && curl -fsS "$API_URL" >/dev/null 2>&1; then \
            echo "[dev] API ready."; \
            break; \
        fi; \
        sleep 0.5; \
    done; \
    just dev-front

# Build deployable artifacts (runner sysimage/image, web bundle)
build:
    if [ -f web/package.json ]; then cd web && bun run build; fi
    if [ -f runner/Dockerfile ]; then docker build -t algorithm-garden-runner:0.1.0 runner; fi

# Build all production Docker images locally
docker-build:
    docker build -t algorithm-garden:0.1.0 .
    docker build -t algorithm-garden-runner:0.1.0 runner
    docker build -t algorithm-garden-api:0.1.0 api
    docker build -t algorithm-garden-web:0.1.0 web

# Start Docker Compose stack with host DOCKER_GID auto-detected for Linux/macOS
docker-up:
    gid="${DOCKER_GID:-}"; \
    if [ -z "$gid" ] && [ -S /var/run/docker.sock ]; then \
        gid="$(stat -c '%g' /var/run/docker.sock 2>/dev/null || stat -f '%g' /var/run/docker.sock 2>/dev/null || echo 0)"; \
    fi; \
    export DOCKER_GID="${gid:-0}"; \
    docker compose up -d --build

# Package a self-hosted release archive into dist/
package:
    ver="${VERSION:-$(node -p "require('./web/package.json').version" 2>/dev/null || sed -nE 's/^version *= *"([^"]+)".*/\1/p' api/Project.toml | head -1)}"; \
    target="${TARGET:-x86_64-unknown-linux-gnu}"; \
    if [ ! -d web/dist ]; then (cd web && bun run build); fi; \
    stage="tmp/pkg/algorithm-garden-${ver}"; \
    rm -rf tmp/pkg && mkdir -p "$stage/web" dist; \
    cp Dockerfile docker-compose.yml .env.example Justfile LICENSE README.md CHANGELOG.md "$stage/"; \
    cp -R docs runner api "$stage/"; \
    cp -R web/dist web/package.json "$stage/web/"; \
    tar -C tmp/pkg -czf "dist/algorithm-garden-${ver}-${target}.tar.gz" "algorithm-garden-${ver}"; \
    rm -rf tmp/pkg; \
    ls -lh "dist/algorithm-garden-${ver}-${target}.tar.gz"

# Generate RELEASE_NOTES.md from Conventional Commits via git-cliff
changelog:
    if git tag -l 'v[0-9]*' | grep -q .; then \
        git-cliff --config cliff.toml --latest --strip header --output RELEASE_NOTES.md; \
    else \
        git-cliff --config cliff.toml --unreleased --strip header --output RELEASE_NOTES.md || printf "# Release Notes\n\n- Initial release\n" > RELEASE_NOTES.md; \
    fi

# Run test suites across all implemented packages
test:
    bash -n scripts/check-commit-message.sh scripts/check-commit-range.sh scripts/install-hooks.sh
    {{ _julia_env }}; if [ -f runner/Project.toml ]; then julia --project=runner -e 'using Pkg; Pkg.test()'; fi
    {{ _julia_env }}; if [ -f api/Project.toml ]; then julia --project=api -e 'using Pkg; Pkg.test()'; fi
    if [ -f web/package.json ]; then cd web && bun run test; fi

# Run static type checking
typecheck:
    if [ -f web/package.json ]; then cd web && bun run typecheck; fi

# Run static analysis / linters
lint:
    if [ -f web/package.json ]; then cd web && bunx biome lint .; fi

# Apply code formatting
format:
    if [ -f web/package.json ]; then cd web && bunx biome check --write .; fi

# Verify formatting without modifying files
format-check:
    if [ -f web/package.json ]; then cd web && bunx biome format .; fi

# Full non-mutating quality gate (called by CI and pre-commit hook)
check: format-check lint typecheck test

# Remove build artifacts and caches
clean:
    rm -rf dist build tmp RELEASE_NOTES.md web/dist web/.vite web/coverage
