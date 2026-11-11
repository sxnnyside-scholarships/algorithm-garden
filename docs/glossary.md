# Domain Glossary

Use one term consistently across code, database schemas, API payloads, UI labels, and documentation.

| Term | Definition |
|---|---|
| **Garden** | A thematic category of algorithms sharing a computational domain and visualization model (e.g., `sorting`, `pathfinding`). |
| **Algorithm** | A catalog entry belonging to a Garden, containing educational explanations, interactive parameter defaults, and a reference Julia implementation. |
| **Exercise** | A guided challenge attached to an Algorithm with starter/incomplete Julia code, instructions, and automated verification test cases. |
| **Experiment** | A user-saved snapshot of Julia code, selected Algorithm, and interactive parameters that can be reloaded, edited, or forked. |
| **Execution** | A single isolated run of Julia code inside `GardenRunner` with specific input parameters, producing a deterministic trace or structured error. |
| **Trace Event** | A single normalized domain event emitted during an Execution (e.g., `compare`, `swap`, `visit`, `frontier`) consumed by the frontend player. |
| **TrackedVector** | The instrumented Julia vector abstraction used in the Sorting Garden to record array reads, writes, comparisons, swaps, and structural markers. |
| **TrackedGrid** | The instrumented Julia grid abstraction used in the Pathfinding Garden to record frontier enqueueing, node visits, edge relaxation, and path reconstruction. |
| **GardenRunner** | The isolated Julia execution package (`runner/`) compiled into a custom sysimage and executed inside a sandboxed container. |

