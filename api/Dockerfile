# Stage 1 (builder): instantiate and precompile Julia dependencies for GardenApi
# Stage 2 (runtime): minimal unprivileged runtime container exposing HTTP API on PORT
ARG JULIA_IMAGE=julia:1.13.3-bookworm
ARG DOCKER_CLI_IMAGE=docker:27.5.1-cli

FROM ${DOCKER_CLI_IMAGE} AS docker-cli

FROM ${JULIA_IMAGE} AS builder

ENV JULIA_DEPOT_PATH=/opt/julia_depot
WORKDIR /app/api
COPY Project.toml Manifest.toml ./
RUN julia --project=/app/api -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'
COPY src ./src
RUN julia --project=/app/api -e 'using Pkg; Pkg.precompile(); using GardenApi'

FROM ${JULIA_IMAGE} AS runtime

# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=docker-cli /usr/local/bin/docker /usr/local/bin/docker

WORKDIR /app
COPY --from=builder /opt/julia_depot /opt/julia_depot
COPY Project.toml Manifest.toml ./api/
COPY src ./api/src

RUN mkdir -p /app/data && chown -R 65534:65534 /app /opt/julia_depot

USER 65534:65534
ENV JULIA_DEPOT_PATH=/opt/julia_depot
ENV HOST=0.0.0.0
ENV PORT=8080
ENV SQLITE_PATH=/app/data/algorithm_garden.sqlite

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=20s --retries=3 \
    CMD ["sh", "-c", "curl -fsS http://127.0.0.1:${PORT:-8080}/health >/dev/null || exit 1"]

CMD ["julia", "--project=/app/api", "--startup-file=no", "/app/api/src/main.jl"]
