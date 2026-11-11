# Stage 1 (builder): install frozen JS/TS dependencies and build static Vite SPA bundle
# Stage 2 (runtime): unprivileged Nginx serving the built SPA and proxying /api to the backend
ARG BUN_IMAGE=oven/bun:1.4.4-alpine
ARG NGINX_IMAGE=nginxinc/nginx-unprivileged:1.27.4-alpine

FROM ${BUN_IMAGE} AS builder

WORKDIR /app
COPY package.json bun.lock ./
RUN bun install --frozen-lockfile

COPY index.html tsconfig.json vite.config.ts ./
COPY src ./src

ARG VITE_API_BASE_URL=""
ENV VITE_API_BASE_URL=${VITE_API_BASE_URL}

RUN bun run build

FROM ${NGINX_IMAGE} AS runtime

COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx/default.conf.template /etc/nginx/templates/default.conf.template

ENV API_UPSTREAM=http://api:8080
USER 101

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD ["sh", "-c", "wget -qO- http://127.0.0.1:8080/healthz >/dev/null || exit 1"]

