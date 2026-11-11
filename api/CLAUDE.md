# api — GardenApi

HTTP API server built with Julia `1.13.3` and `Oxygen.jl`.

## Conventions

- Unversioned routes are strictly limited to `GET /`, `GET /health`, and `GET /health/ready`.
- All business routes live under `/api/v1/...` and return `{"data": ...}` or `{"error": {"code", "message", "details"?}}`.
- Any route, payload field, or error-code change must update [../API.md](../API.md) in the same commit (`test_api_docs_sync.jl` enforces this).
- Never interpolate user input into SQL queries or shell commands; use parameterized queries (`DBInterface.execute`) and direct `Cmd` argument lists.

## Commands

- Run tests: `julia --project=api -e 'using Pkg; Pkg.test()'`
- Start dev server: `julia --project=api api/src/main.jl`
- Run from root: `just test` / `just check`

