# All-in-one single-container image for one-click Coolify and standalone Docker deployments.
# Stage 1 builds the Vite web SPA; Stage 2 precompiles GardenRunner.so;
# Stage 3 precompiles GardenApi; Stage 4 serves SPA + HTTP API + sandboxed Julia runner on PORT 8080.
ARG BUN_IMAGE=oven/bun:1.4.4-alpine
ARG JULIA_IMAGE=julia:1.13.3-bookworm

FROM ${BUN_IMAGE} AS web-builder

WORKDIR /build/web
COPY web/package.json web/bun.lock ./
RUN bun install --frozen-lockfile

COPY web/index.html web/tsconfig.json web/vite.config.ts ./
COPY web/src ./src

ARG VITE_API_BASE_URL=""
ENV VITE_API_BASE_URL=${VITE_API_BASE_URL}

RUN bun run build

FROM ${JULIA_IMAGE} AS runner-builder

# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends gcc libc6-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/garden
COPY runner/Project.toml runner/Manifest.toml ./
COPY runner/src ./src
COPY runner/scripts ./scripts

RUN julia --project=/opt/garden -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()' \
    && julia -e 'using Pkg; Pkg.activate("/tmp/compiler"); Pkg.add(PackageSpec(name="PackageCompiler", version="2.2")); Pkg.develop(path="/opt/garden"); include("/opt/garden/scripts/build_sysimage.jl")'

FROM ${JULIA_IMAGE} AS api-builder

ENV JULIA_DEPOT_PATH=/opt/julia_depot
WORKDIR /app/api
COPY api/Project.toml api/Manifest.toml ./
RUN julia --project=/app/api -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'
COPY api/src ./src
RUN julia --project=/app/api -e 'using Pkg; Pkg.precompile(); using GardenApi'

FROM ${JULIA_IMAGE} AS runtime

# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=api-builder /opt/julia_depot /opt/julia_depot
COPY --from=web-builder /build/web/dist ./web/dist
COPY --from=runner-builder /opt/garden/Project.toml ./runner/Project.toml
COPY --from=runner-builder /opt/garden/Manifest.toml ./runner/Manifest.toml
COPY --from=runner-builder /opt/garden/src ./runner/src
COPY --from=runner-builder /opt/garden/scripts ./runner/scripts
COPY --from=runner-builder /opt/garden/GardenRunner.so ./runner/GardenRunner.so

COPY api/Project.toml api/Manifest.toml ./api/
COPY api/src ./api/src

RUN mkdir -p /app/data && chown -R 65534:65534 /app /opt/julia_depot

USER 65534:65534
ENV JULIA_DEPOT_PATH=/opt/julia_depot
ENV HOST=0.0.0.0
ENV PORT=8080
ENV SQLITE_PATH=/app/data/algorithm_garden.sqlite
ENV RUNNER_MODE=subprocess
ENV RUNNER_DIR=/app/runner
ENV RUNNER_POOL_SIZE=2
ENV STATIC_DIR=/app/web/dist

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=45s --retries=3 \
    CMD ["sh", "-c", "curl -fsS http://127.0.0.1:${PORT:-8080}/health >/dev/null || exit 1"]

CMD ["julia", "--project=/app/api", "--startup-file=no", "/app/api/src/main.jl"]
