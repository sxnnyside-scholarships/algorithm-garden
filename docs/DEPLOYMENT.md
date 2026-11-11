# Self-Hosted Deployment Guide (Docker & Coolify)

Algorithm Garden is designed for single-node or multi-service self-hosting with pinned multi-stage containers, unprivileged runtime users, explicit readiness gates, and isolated per-execution Julia sandboxes.

---

## 1. Deployment Modes & Artifacts

Algorithm Garden supports **two production Docker topologies**:

1. **Single-Resource All-in-One ([`Dockerfile`](../Dockerfile)) — Recommended for 1-click Coolify & quick VPS deploys:**
   Builds `web/` (Vite SPA), precompiles `runner/` (`GardenRunner.so` sysimage), and runs `GardenApi` (`api/`) on port `8080` serving static SPA assets (`STATIC_DIR=/app/web/dist`) + `/api/v1/*` + `/health*` with `USER nobody`. No `/var/run/docker.sock` mount is required (`RUNNER_MODE=subprocess` uses AST sandbox allowlisting + `TraceRecorder` limits + isolated modules).
   Published image: `ghcr.io/sxnnyside-scholarships/algorithm-garden:<version>`.

2. **Multi-Container Stack (Maximum per-execution container isolation):**

| Component | Path | Purpose | Runtime User | Port |
|---|---|---|---|---|
| **Runner Sandbox** | [`runner/Dockerfile`](../runner/Dockerfile) | Precompiled Julia `1.13.3` sysimage (`GardenRunner.so`) executing student code over stdin/stdout JSON (`ghcr.io/.../algorithm-garden-runner`) | `nobody` | N/A (CLI image) |
| **HTTP API** | [`api/Dockerfile`](../api/Dockerfile) | Julia `Oxygen.jl` API (`api/`), SQLite/PostgreSQL persistence, auth, and `RunnerPool` orchestrator (`ghcr.io/.../algorithm-garden-api`) | `nobody` | `8080` |
| **Web Workspace** | [`web/Dockerfile`](../web/Dockerfile) | Built Vue 3 + TypeScript SPA served by unprivileged Nginx with reverse proxy to `API_UPSTREAM` (`ghcr.io/.../algorithm-garden-web`) | UID `101` (`nginx`) | `8080` |

> **Important:** In multi-container mode, `runner` is **not** a long-running network service. It must exist on the Docker host (pulled from GHCR or built as `algorithm-garden-runner:0.1.0`) so `api` can launch isolated containers (`--network=none --read-only --cap-drop=ALL --security-opt=no-new-privileges --user nobody`) with zero network access.

---

## 2. Quick Local Self-Hosted Stack (Docker Compose)

1. Create a local `.env` from `.env.example` and set a 32+ byte random `AUTH_TOKEN_SECRET`:

```bash
cp .env.example .env
openssl rand -hex 32
```

2. Start the full stack (Compose automatically builds `algorithm-garden-runner:0.1.0` on first run):

```bash
# Linux (grants container 'nobody' read/write access to the host docker socket group)
DOCKER_GID=$(stat -c '%g' /var/run/docker.sock) docker compose up --build -d --wait

# Or via Justfile (auto-detects Linux/macOS DOCKER_GID):
just docker-up
```

- Web UI & proxied API: `http://localhost:5173`
- Direct API health check: `http://localhost:8080/health/ready`
- Optional PostgreSQL profile:

```bash
DB_DRIVER=postgres \
DATABASE_URL=postgres://postgres:postgres@postgres:5432/algorithm_garden \
docker compose --profile postgres up --build -d
```

> `docker-compose.yml` is intended strictly for local development and single-host previewing. In Coolify, deploy `api/` and `web/` using their individual Dockerfiles.

---

## 3. Production Deployment on Coolify

### Option A — Single-Resource Coolify App (Easiest, 1 Container)

Deploy the repository as **one** Coolify resource using the root [`Dockerfile`](../Dockerfile):

- **Build Pack:** `Dockerfile` (or **Docker Image** using `ghcr.io/sxnnyside-scholarships/algorithm-garden:0.1.0`)
- **Base Directory:** `/`
- **Dockerfile Location:** `/Dockerfile`
- **Port Exposes:** `8080`
- **Persistent Storage Volume:** Mount a volume at `/app/data` (or configure `DB_DRIVER=postgres` + `DATABASE_URL`)
- **Health Check:** `/health/ready` on port `8080` (expects `200`)
- **Required Env Vars:** `APP_ENV=production`, `AUTH_TOKEN_SECRET=<random >= 32 bytes>`, `CORS_ORIGIN=https://garden.example.com`

### Option B — Multi-Service Coolify (Isolated Runner Containers)

#### Step 1 — Pull or Build the Runner Image on the Coolify Host

On the server hosting Coolify (or via a scheduled build pushing to a private registry reachable by the host):

```bash
git clone <your-repo-url> /tmp/algorithm-garden
cd /tmp/algorithm-garden
docker build -t algorithm-garden-runner:0.1.0 ./runner
```

Verify the sandboxed image executes offline with no network access:

```bash
echo '{"garden":"sorting","algorithm":"bubble-sort","code":"function sort_algorithm!(a); swap!(a,1,2); end","params":{"values":[2,1]}}' \
  | docker run --rm -i --network=none --read-only --cap-drop=ALL --security-opt=no-new-privileges --user nobody \
    --tmpfs /tmp:rw,noexec,nosuid,nodev,size=32m algorithm-garden-runner:0.1.0
```

### Step 2 — Deploy the `api` Service

Create a **Dockerfile** resource in Coolify pointing to this repository:

- **Build Pack:** `Dockerfile`
- **Base Directory:** `/api`
- **Dockerfile Location:** `/Dockerfile`
- **Port Exposes:** `8080`
- **Persistent Storage Volume:** Mount a volume at `/app/data` when `DB_DRIVER=sqlite`.
- **Docker Socket Mount:** Bind `/var/run/docker.sock:/var/run/docker.sock` under **Storages / Custom Mounts** so `GardenApi` can orchestrate `algorithm-garden-runner:0.1.0`.
  - Because `api/Dockerfile` runs as `USER nobody`, ensure the container has group access to `/var/run/docker.sock` (set host docker group GID via Docker `group_add` / Coolify custom container options matching `stat -c '%g' /var/run/docker.sock`).
- **Health Check:**
  - **Path:** `/health/ready`
  - **Port:** `8080`
  - **Expected Status:** `200` (Coolify waits until DB ping + `docker image inspect` succeed; `/health` stays available as container liveness probe).

#### Required `api` Environment Variables

| Variable | Recommended Value | Notes |
|---|---|---|
| `APP_ENV` | `production` | Enforces mandatory `AUTH_TOKEN_SECRET` validation on startup |
| `HOST` | `0.0.0.0` | Bind inside container |
| `PORT` | `8080` | Internal HTTP port |
| `AUTH_TOKEN_SECRET` | `$(openssl rand -hex 32)` | Must be >= 32 bytes; server refuses to start otherwise |
| `DB_DRIVER` | `sqlite` or `postgres` | Default `sqlite` |
| `SQLITE_PATH` | `/app/data/algorithm_garden.sqlite` | Persistent file inside mounted volume |
| `DATABASE_URL` | `postgres://...` | Used when `DB_DRIVER=postgres` |
| `RUNNER_MODE` | `docker` | Always use `docker` in multi-tenant production |
| `RUNNER_IMAGE` | `algorithm-garden-runner:0.1.0` | Matches host-built runner image tag |
| `RUNNER_POOL_SIZE` | `2` | Pre-warmed single-use containers kept ready (reduces first-run Julia latency; `0` disables pool) |
| `RUNNER_TIMEOUT_MS` | `5000` | Max execution time per job (`250..30000`) |
| `RUNNER_MEMORY_LIMIT` | `256m` | Container memory limit per student execution |
| `RUNNER_CPU_LIMIT` | `1.0` | Container CPU quota |
| `RUNNER_PIDS_LIMIT` | `64` | Fork-bomb protection (`16..256`) |
| `RUNNER_MAX_EVENTS` | `50000` | Trace cap per execution |
| `CORS_ORIGIN` | `https://garden.example.com` | Exact public origin of the web frontend |

### Step 3 — Deploy the `web` Service

Create a second **Dockerfile** resource in Coolify on the same network as `api`:

- **Build Pack:** `Dockerfile`
- **Base Directory:** `/web`
- **Dockerfile Location:** `/Dockerfile`
- **Port Exposes:** `8080`
- **Health Check Path:** `/healthz` (expects `200 ok`)
- **Domain:** `https://garden.example.com` (TLS terminated by Coolify/Traefik)

#### Web Service Environment Variables

- **Runtime (`API_UPSTREAM`):** Internal URL of the `api` service (for example `http://api:8080` or the Coolify internal service UUID URL). Nginx proxies `/api/` and `/health*` cleanly over the same origin with security headers (`CSP`, `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`).
- **Build Arg (`VITE_API_BASE_URL`):** Keep empty `""` (default) when serving `web` and `api` through Nginx's same-origin proxy, or set `https://api.example.com` if hosting the frontend and API on separate origins.

---

## 4. Warm Runner Pool Behavior

When `RUNNER_POOL_SIZE > 0`, `api` boots `N` single-use `--warm-one-shot` runner containers in the background with `GardenRunner.so` already loaded. Each incoming `POST /api/v1/executions` or `POST /api/v1/exercises/:id/verify` consumes one pre-warmed container for that single run, enforces the configured CPU/memory/PID/timeout/event limits, immediately destroys the container (`--rm`), and asynchronously refills the pool. Zero student state persists between executions.

---

## 5. Production Security Checklist

- [ ] `APP_ENV=production` and unique `AUTH_TOKEN_SECRET` (`>= 32` random bytes) configured.
- [ ] `algorithm-garden-runner:0.1.0` built on host and verified by `GET /health/ready` (`"runner":{"ok":true}`).
- [ ] HTTPS enforced at Coolify edge proxy and `CORS_ORIGIN` restricted to your public domain.
- [ ] `/app/data` backed up regularly (if using SQLite) or managed PostgreSQL backups enabled.
- [ ] `.env` never committed to Git; secrets injected strictly via Coolify environment settings.

