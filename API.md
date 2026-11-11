# Algorithm Garden API

## Conventions

- **Base path:** `/api/v1` for all business endpoints. Root `/`, `/health`, and `/health/ready` are unversioned and unauthenticated.
- **Authentication:** `Authorization: Bearer <token>` header. Tokens are issued by `/api/v1/auth/register` and `/api/v1/auth/login`.
- **Success envelope:** `{"data": ...}`
- **Error envelope:** `{"error": {"code": "<snake_case>", "message": "<human text>", "details"?: ...}}` (`details` is included only for `validation_failed`).
- **Timestamps:** ISO 8601 UTC (`YYYY-MM-DDTHH:MM:SSZ`).
- **IDs:** UUID strings unless otherwise noted.
- **Enums:** lowercase strings.
- **Rate limiting:** Returns `429` with `Retry-After` header.

### Error codes

| HTTP | code | When |
|---|---|---|
| 400 | `invalid_json` | Request body is not valid JSON |
| 401 | `unauthorized` | Missing, expired, or invalid Bearer token |
| 403 | `forbidden` | Authenticated user lacks ownership or role permissions |
| 404 | `not_found` | Requested garden, algorithm, exercise, or experiment does not exist |
| 409 | `conflict` | Email or username already registered |
| 422 | `validation_failed` | Payload failed schema or domain constraints (`details` lists fields) |
| 429 | `rate_limited` | Client exceeded request budget for auth or execution endpoints |
| 500 | `internal_error` | Unexpected server failure |
| 503 | `runner_unavailable` | Isolated execution runtime or dependency is unavailable |

## Root

| Method & Path | Auth | Body | Returns |
|---|---|---|---|
| `GET /` | None | — | `{"data": {"service": "algorithm-garden-api", "version": "0.1.0"}}` |
| `GET /health` | None | — | `{"status": "ok"}` (liveness; no dependency checks) |
| `GET /health/ready` | None | — | `200 {"status": "ready", "checks": {...}}` or `503 {"status": "not_ready", "checks": {...}}` |

## Authentication

| Method & Path | Auth | Body | Returns |
|---|---|---|---|
| `POST /api/v1/auth/register` | None | `{email, username, password}` | `201 {"data": {"user": {...}, "token": "..."}}` |
| `POST /api/v1/auth/login` | None | `{email, password}` | `200 {"data": {"user": {...}, "token": "..."}}` |
| `POST /api/v1/auth/logout` | Bearer | — | `200 {"data": {"revoked": true}}` |
| `GET /api/v1/auth/me` | Bearer | — | `200 {"data": {"user": {...}}}` |

## Catalog (Gardens & Algorithms)

| Method & Path | Auth | Body | Returns |
|---|---|---|---|
| `GET /api/v1/gardens` | Optional | — | `200 {"data": [{"slug", "name", "description", "algorithms_count"}]}` |
| `GET /api/v1/algorithms` | Optional | — | `200 {"data": [{"slug", "garden", "name", "summary", "difficulty"}]}` |
| `GET /api/v1/algorithms/:slug` | Optional | — | `200 {"data": {"algorithm": {...}, "exercises": [...]}}` |

## Execution & Exercises

| Method & Path | Auth | Body | Returns |
|---|---|---|---|
| `POST /api/v1/executions` | Bearer (or Guest Rate-Limited) | `{algorithm_slug, code, params}` | `200 {"data": {"execution": {...}}}` |
| `POST /api/v1/exercises/:id/verify` | Bearer | `{code}` | `200 {"data": {"passed": bool, "results": [...], "execution": {...}}}` |

## Personal Experiments

| Method & Path | Auth | Body | Returns |
|---|---|---|---|
| `GET /api/v1/experiments` | Bearer | — | `200 {"data": [...]}` |
| `POST /api/v1/experiments` | Bearer | `{algorithm_slug, title, code, params}` | `201 {"data": {"experiment": {...}}}` |
| `GET /api/v1/experiments/:id` | Bearer | — | `200 {"data": {"experiment": {...}}}` |
| `PATCH /api/v1/experiments/:id` | Bearer | `{title?, code?, params?}` | `200 {"data": {"experiment": {...}}}` |
| `DELETE /api/v1/experiments/:id` | Bearer | — | `200 {"data": {"deleted": true}}` |

