# runner — GardenRunner

Isolated Julia `1.13.3` execution engine for student algorithms.

## Conventions

- Zero external package dependencies: uses Julia stdlib (`Random`, `Test`) only so the sandbox has minimal supply-chain surface and starts fast.
- All student code runs inside an isolated `Module` validated by `GardenRunner.Sandbox` inside an unprivileged `--network=none --read-only` Docker container.
- Event payloads must conform to [../docs/EXECUTION_CONTRACT.md](../docs/EXECUTION_CONTRACT.md).

## Commands

- Run tests: `julia --project=runner -e 'using Pkg; Pkg.test()'`
- Run from root: `just test`

