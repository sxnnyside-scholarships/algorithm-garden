# Execution and Visualization Contract

This document defines the contract between student Julia code executed inside `runner/` (`GardenRunner`) and the frontend visualization engine (`web/`). Student code **never** interacts with browser rendering internals or DOM details; it operates strictly on domain abstractions that emit normalized trace events.

---

## 1. Execution Lifecycle

1. The student edits Julia code and configures experiment parameters in `web/`.
2. `web/` submits `{ algorithm_slug, code, params, mode }` to `POST /api/v1/executions` (or `POST /api/v1/exercises/:id/verify`).
3. `api/` dispatches the payload to an isolated `runner/` Docker container (`--network=none`, `--read-only`, non-root user, strict CPU/memory/PID/timeout limits).
4. `GardenRunner` parses and evaluates the student code inside an isolated `Module`, injects the instrumented domain input (`TrackedVector`, `TrackedGrid`, `CellularGrid`, `TrackedGraph`, `FractalPlane`, or `EvolutionEnvironment`), and executes the entry function.
5. Every domain operation appends a normalized **Trace Event** (up to `RUNNER_MAX_EVENTS`).
6. `GardenRunner` returns a single structured JSON response on `stdout` containing status, initial snapshot, ordered event list, accumulated metrics, final result, and any exercise test results.
7. `web/` loads the trace into `ExecutionPlayer` for deterministic replay (`run`, `pause`, `resume`, `step_forward`, `step_back`, `reset`, `speed`).

---

## 2. Student Entry Functions & Domain APIs

### 2.1. Sorting Garden (`garden = "sorting"`)

- **Required signature:** `sort_algorithm!(arr)`
- **Input:** `arr::TrackedVector{Int}` (1-indexed, behaves like an `AbstractVector{Int}`).
- **Automatic instrumentation via Julia multiple dispatch:**
  - `arr[i]` records `read(index=i)`
  - `arr[i] = val` records `write(index=i, value=val)`
  - `arr[i] < arr[j]` / `arr[i] > arr[j]` / `isless` / `compare(arr, i, j)` records `compare(indices=[i, j])`
  - `swap!(arr, i, j)` swaps elements and records `swap(indices=[i, j], values=[arr[i], arr[j]])`
- **Optional semantic markers:**
  - `mark_pivot!(arr, i)` → `mark_pivot(index=i)`
  - `mark_range!(arr, lo, hi)` → `mark_range(range=[lo, hi])`
  - `mark_sorted!(arr, i)` → `mark_sorted(index=i)`
- **Final validation:** `collect(arr)` is returned as `final_state` and verified against `sort(initial_values)` when checking correctness.

### 2.2. Pathfinding Garden (`garden = "pathfinding"`)

- **Required signature:** `find_path(grid)`
- **Input:** `grid::TrackedGrid` initialized with dimensions `(rows, cols)`, `start::Tuple{Int,Int}`, `goal::Tuple{Int,Int}`, `walls::Set{Tuple{Int,Int}}`, and optional cell weights.
- **Grid API:**
  - `start_node(grid)` → `(row, col)`
  - `goal_node(grid)` → `(row, col)`
  - `grid_size(grid)` → `(rows, cols)`
  - `neighbors(grid, pos)` → walkable 4-directional neighbor coordinates
  - `step_cost(grid, from, to)` → numeric edge cost (respects cell weights)
  - `manhattan(a, b)` / `euclidean(a, b)` → heuristic helpers
  - `frontier!(grid, pos; cost=nothing)` → records `frontier` event
  - `visit!(grid, pos; cost=nothing)` → records `visit` event
  - `relax_edge!(grid, from, to, cost)` → records `relax_edge` event
  - `mark_path!(grid, path::Vector{Tuple{Int,Int}})` → validates contiguous walkable path and records `path_found`
- **Return value:** `Vector{Tuple{Int,Int}}` representing the path from `start` to `goal` (or empty vector `Tuple{Int,Int}[]` if unreachable).

### 2.3. Cellular Garden (`garden = "cellular"`)

- **Required signature:** `evolve_cellular(grid)`
- **Input:** `grid::CellularGrid` with dimensions `(rows, cols)`, cell states matrix, `born`/`survive` rule digits, generation count, and edge wrapping flag.
- **Cellular API:** `grid_dims(grid)`, `generations_count(grid)`, `wrap_edges(grid)`, `rule_born(grid)`, `rule_survive(grid)`, `current_cells(grid)`, `live_neighbors(grid, r, c; state=1)`, `record_generation!(grid, next_cells, gen)`.

### 2.4. Graph Garden (`garden = "graph"`)

- **Required signature:** `analyze_graph(graph)`
- **Input:** `graph::TrackedGraph` with vertices, weighted edges `(u, v, weight)`, directed flag, and start/target vertices.
- **Graph API:** `node_count(g)`, `graph_nodes(g)`, `graph_edges(g)`, `start_vertex(g)`, `target_vertex(g)`, `adjacent(g, u)`, `visit_node!(g, u; component=nothing)`, `queue_node!(g, u; from=nothing)`, `inspect_edge!(g, u, v; weight=nothing, accepted=false)`, `mark_component!(g, u, component_id)`, `mark_tree_edge!(g, u, v, weight=1.0)`, `mark_graph_path!(g, path)`.

### 2.5. Fractal Garden (`garden = "fractal"`)

- **Required signature:** `render_fractal(plane)`
- **Input:** `plane::FractalPlane` with canvas resolution, complex-plane bounds, max iterations, Julia complex seed, and recursion depth.
- **Fractal API:** `plane_size(p)`, `complex_bounds(p)`, `max_iterations(p)`, `julia_seed(p)`, `recursion_depth(p)`, `pixel_complex(p, row, col)`, `emit_row!(p, row, iters)`, `emit_segments!(p, depth_level, segments)`.

### 2.6. Evolution Garden (`garden = "evolution"`)

- **Required signature:** `evolve_population(env)`
- **Input:** `env::EvolutionEnvironment` with seeded RNG configuration, population size, generation cap, chromosome length, mutation/crossover rates, elite count, and target genome.
- **Evolution API:** `env_config(env)`, `initial_population(env)`, `seeded_rng(seed)`, `evaluate_fitness(env, genome)`, `mutate_bit(v)`, `record_population!(env, gen, population, fitnesses; mutations=0, crossovers=0)`.

---

## 3. Trace Event Envelope

Every event emitted during execution follows a flat, JSON-serializable object shape with a monotonic 1-based sequence number `seq`:

```json
{
  "seq": 1,
  "type": "compare",
  "indices": [1, 2],
  "values": [42, 17]
}
```

### 3.1. Common Lifecycle Metadata

The runner response payload wraps the trace:

```json
{
  "status": "completed",
  "garden": "sorting",
  "algorithm": "bubble-sort",
  "initial_state": { "values": [42, 17, 9, 25] },
  "events": [ ... ],
  "final_state": { "values": [9, 17, 25, 42] },
  "metrics": {
    "comparisons": 6,
    "swaps": 4,
    "reads": 12,
    "writes": 8,
    "total_events": 20,
    "elapsed_ms": 1.84
  },
  "tests": null,
  "error": null
}
```

### 3.2. Domain Event Types

| Garden | `type` | Fields | Meaning |
|---|---|---|---|
| `sorting` | `compare` | `indices: [i, j]` | Comparison between two indices |
| `sorting` | `swap` | `indices: [i, j]`, `values: [vi, vj]` | Elements at `i` and `j` swapped (post-swap values) |
| `sorting` | `write` | `index: i`, `value: v` | Value `v` written at index `i` |
| `sorting` | `read` | `index: i` | Element read at index `i` (counted in metrics; optionally omitted from high-frequency animation if identical) |
| `sorting` | `mark_pivot` | `index: i` | Highlights pivot index |
| `sorting` | `mark_range` | `range: [lo, hi]` | Highlights active subarray `[lo, hi]` |
| `sorting` | `mark_sorted` | `index: i` | Marks index `i` in its final sorted position |
| `pathfinding` | `frontier` | `pos: [r, c]`, `cost?: number` | Node added to exploration frontier |
| `pathfinding` | `visit` | `pos: [r, c]`, `cost?: number` | Node popped/expanded |
| `pathfinding` | `relax_edge` | `from: [r1, c1]`, `to: [r2, c2]`, `cost: number` | Tentative distance updated |
| `pathfinding` | `path_found` | `path: [[r, c], ...]`, `total_cost: number` | Final reconstructed path |
| `cellular` | `generation` | `gen: number`, `cells: number[][]`, `alive_count`, `born_count`, `died_count` | Committed generation state |
| `graph` | `graph_frontier` | `node: number`, `from?: number` | Vertex enqueued for exploration |
| `graph` | `graph_visit` | `node: number`, `component?: number` | Vertex expanded during traversal |
| `graph` | `graph_edge` | `from_node`, `to_node`, `weight`, `accepted` | Edge evaluated for traversal or MST |
| `graph` | `graph_component` | `node: number`, `component: number` | Connected component assignment |
| `graph` | `graph_mst_edge` | `from_node`, `to_node`, `weight` | Edge accepted into spanning tree |
| `graph` | `graph_path` | `path: number[]` | Reconstructed graph path |
| `fractal` | `fractal_row` | `row: number`, `values: number[]`, `max_iter` | Computed escape-time raster scanline |
| `fractal` | `fractal_segments` | `depth: number`, `segments: number[][]` | Recursive vector line batch `[x1, y1, x2, y2, depth]` |
| `evolution` | `evolution_gen` | `gen`, `best_fitness`, `avg_fitness`, `diversity`, `best_genome`, `top_genomes`, `mutations`, `crossovers` | Generation fitness and population snapshot |

---

## 4. Error Categories & Resource Limits

When `status == "failed"`, `error` contains:

```json
{
  "category": "syntax",
  "message": "syntax: incomplete: premature end of input",
  "line": 4,
  "hint": "Check for a missing 'end' keyword."
}
```

| `category` | Cause |
|---|---|
| `syntax` | Julia parser error (`Meta.parse` / `Base.Meta.ParseError`) |
| `runtime` | Uncaught exception during execution (e.g., `BoundsError`, `MethodError`, `UndefVarError`) |
| `timeout` | Execution exceeded `RUNNER_TIMEOUT_MS` wall-clock budget |
| `resource_limit` | Exceeded container memory, PID, stdout byte cap, or `RUNNER_MAX_EVENTS` |
| `contract_violation` | Required entry function missing, wrong return type, or forbidden unsafe construct |

