# Stage 1 (builder): compiles GardenRunner into a custom Julia sysimage using PackageCompiler
# Stage 2 (runtime): minimal unprivileged container executing student code via stdin/stdout JSON
ARG JULIA_IMAGE=julia:1.13.3-bookworm

FROM ${JULIA_IMAGE} AS builder

# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends gcc libc6-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/garden
COPY Project.toml ./
COPY src ./src
COPY scripts ./scripts

RUN julia --project=/opt/garden -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()' \
    && julia -e 'using Pkg; Pkg.activate("/tmp/compiler"); Pkg.add(PackageSpec(name="PackageCompiler", version="2.2")); Pkg.develop(path="/opt/garden"); include("/opt/garden/scripts/build_sysimage.jl")'

FROM ${JULIA_IMAGE} AS runtime

WORKDIR /opt/garden
COPY --from=builder /opt/garden/Project.toml ./Project.toml
COPY --from=builder /opt/garden/src ./src
COPY --from=builder /opt/garden/scripts ./scripts
COPY --from=builder /opt/garden/GardenRunner.so ./GardenRunner.so

RUN chown -R 65534:65534 /opt/garden

USER 65534:65534
ENV JULIA_DEPOT_PATH=/tmp/.julia

ENTRYPOINT ["julia", "--sysimage=/opt/garden/GardenRunner.so", "--project=/opt/garden", "--startup-file=no", "/opt/garden/scripts/entrypoint.jl"]

