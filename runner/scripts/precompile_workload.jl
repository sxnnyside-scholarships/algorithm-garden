using GardenRunner

function run_precompile_workload()
    sorting_req = Dict(
        "garden" => "sorting",
        "algorithm" => "bubble-sort",
        "code" => """
        function sort_algorithm!(arr)
            n = length(arr)
            for i in 1:(n - 1)
                for j in 1:(n - i)
                    if compare(arr, j, j + 1) > 0
                        swap!(arr, j, j + 1)
                    end
                end
                mark_sorted!(arr, n - i + 1)
            end
            mark_sorted!(arr, 1)
        end
        """,
        "params" => Dict("values" => [5, 3, 1, 4, 2]),
    )
    run_request(sorting_req)

    pathfinding_req = Dict(
        "garden" => "pathfinding",
        "algorithm" => "bfs",
        "code" => """
        function find_path(grid)
            s = start_node(grid)
            g = goal_node(grid)
            queue = [s]
            came_from = Dict{Tuple{Int, Int}, Tuple{Int, Int}}(s => s)
            frontier!(grid, s)
            while !isempty(queue)
                cur = popfirst!(queue)
                visit!(grid, cur)
                if cur == g
                    path = Tuple{Int, Int}[]
                    while cur != s
                        push!(path, cur)
                        cur = came_from[cur]
                    end
                    push!(path, s)
                    reverse!(path)
                    return path
                end
                for nxt in neighbors(grid, cur)
                    if !haskey(came_from, nxt)
                        came_from[nxt] = cur
                        push!(queue, nxt)
                        frontier!(grid, nxt)
                    end
                end
            end
            return Tuple{Int, Int}[]
        end
        """,
        "params" => Dict("rows" => 4, "cols" => 4, "start" => [1, 1], "goal" => [4, 4]),
    )
    run_request(pathfinding_req)

    run_request(
        Dict(
            "garden" => "cellular",
            "algorithm" => "conways-game-of-life",
            "code" => """
            function evolve_cellular(grid)
                rows, cols = grid_dims(grid)
                born = rule_born(grid)
                survive = rule_survive(grid)
                cells = current_cells(grid)
                for gen in 1:generations_count(grid)
                    nxt = zeros(Int, rows, cols)
                    for r in 1:rows, c in 1:cols
                        nb = live_neighbors(grid, r, c)
                        nxt[r, c] = cells[r, c] == 1 ? (nb in survive ? 1 : 0) : (nb in born ? 1 : 0)
                    end
                    cells = record_generation!(grid, nxt, gen)
                end
            end
            """,
            "params" => Dict("rows" => 6, "cols" => 6, "generations" => 2, "preset" => "blinker"),
        ),
    )

    run_request(
        Dict(
            "garden" => "graph",
            "algorithm" => "graph-bfs",
            "code" => """
            function analyze_graph(graph)
                s = start_vertex(graph)
                t = target_vertex(graph)
                q = [s]
                parent = Dict{Int, Int}(s => s)
                queue_node!(graph, s)
                while !isempty(q)
                    u = popfirst!(q)
                    visit_node!(graph, u)
                    u == t && break
                    for (v, w) in adjacent(graph, u)
                        inspect_edge!(graph, u, v; weight = w, accepted = !haskey(parent, v))
                        if !haskey(parent, v)
                            parent[v] = u
                            push!(q, v)
                            queue_node!(graph, v; from = u)
                        end
                    end
                end
                return Int[]
            end
            """,
            "params" => Dict("preset" => "botanical_web"),
        ),
    )

    run_request(
        Dict(
            "garden" => "fractal",
            "algorithm" => "mandelbrot-set",
            "code" => """
            function render_fractal(plane)
                w, h = plane_size(plane)
                max_it = max_iterations(plane)
                for r in 1:h
                    row_vals = Int[]
                    for c in 1:w
                        z0 = pixel_complex(plane, r, c)
                        z = 0.0 + 0.0im
                        it = 0
                        while it < max_it && abs2(z) <= 4.0
                            z = z * z + z0
                            it += 1
                        end
                        push!(row_vals, it)
                    end
                    emit_row!(plane, r, row_vals)
                end
            end
            """,
            "params" => Dict("width" => 16, "height" => 12, "max_iter" => 10),
        ),
    )

    run_request(
        Dict(
            "garden" => "evolution",
            "algorithm" => "genetic-algorithm",
            "code" => """
            function evolve_population(env)
                cfg = env_config(env)
                pop = initial_population(env)
                for gen in 1:2
                    fits = [evaluate_fitness(env, g) for g in pop]
                    record_population!(env, gen, pop, fits; mutations = 1, crossovers = 1)
                end
            end
            """,
            "params" => Dict("generations" => 2, "population_size" => 6, "chromosome_length" => 8),
        ),
    )
end

run_precompile_workload()
