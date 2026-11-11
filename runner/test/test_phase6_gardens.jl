@testset "Phase 6 Gardens (Cellular, Graph, Fractal, Evolution)" begin
    conway_code = """
    function evolve_cellular(grid)
        rows, cols = grid_dims(grid)
        born = rule_born(grid)
        survive = rule_survive(grid)
        cells = current_cells(grid)
        for gen in 1:generations_count(grid)
            nxt = zeros(Int, rows, cols)
            for r in 1:rows, c in 1:cols
                nb = live_neighbors(grid, r, c)
                if cells[r, c] == 1
                    nxt[r, c] = (nb in survive) ? 1 : 0
                else
                    nxt[r, c] = (nb in born) ? 1 : 0
                end
            end
            cells = record_generation!(grid, nxt, gen)
        end
    end
    """

    @testset "Cellular Garden execution & verification" begin
        res = run_request(
            Dict(
                "garden" => "cellular",
                "algorithm" => "conways-game-of-life",
                "code" => conway_code,
                "params" => Dict("rows" => 7, "cols" => 7, "generations" => 2, "preset" => "blinker", "wrap" => false),
                "tests" => [
                    Dict(
                        "name" => "blinker_period_2",
                        "params" => Dict("rows" => 7, "cols" => 7, "generations" => 2, "preset" => "blinker", "wrap" => false),
                        "min_generations" => 2,
                        "expected_alive" => 3,
                    ),
                ],
            ),
        )
        @test res["status"] == "completed"
        @test length(res["events"]) == 2
        @test res["final_state"]["alive_count"] == 3
        @test res["initial_state"]["cells"] == res["final_state"]["cells"]
        @test res["tests"][1]["passed"] === true
    end

    @testset "Graph Garden BFS, MST, Components & Localization" begin
        bfs_code = """
        function analyze_graph(graph)
            s = start_vertex(graph)
            t = target_vertex(graph)
            q = [s]
            parent = Dict{Int, Int}(s => s)
            queue_node!(graph, s)
            while !isempty(q)
                u = popfirst!(q)
                visit_node!(graph, u)
                if u == t
                    path = Int[]
                    cur = t
                    while cur != s
                        push!(path, cur)
                        cur = parent[cur]
                    end
                    push!(path, s)
                    reverse!(path)
                    mark_graph_path!(graph, path)
                    return path
                end
                for (v, w) in adjacent(graph, u)
                    fresh = !haskey(parent, v)
                    inspect_edge!(graph, u, v; weight = w, accepted = fresh)
                    if fresh
                        parent[v] = u
                        push!(q, v)
                        queue_node!(graph, v; from = u)
                    end
                end
            end
            return Int[]
        end
        """
        res = run_request(
            Dict(
                "garden" => "graph",
                "algorithm" => "graph-bfs",
                "code" => bfs_code,
                "params" => Dict("preset" => "botanical_web"),
                "tests" => [
                    Dict(
                        "name" => "short_hop_path",
                        "params" => Dict(
                            "nodes" => [
                                Dict("id" => 1, "label" => "A", "x" => 10, "y" => 50),
                                Dict("id" => 2, "label" => "B", "x" => 50, "y" => 20),
                                Dict("id" => 3, "label" => "C", "x" => 90, "y" => 50),
                            ],
                            "edges" => [[1, 2, 1], [2, 3, 1]],
                            "start_node" => 1,
                            "target_node" => 3,
                        ),
                        "expected_path" => [1, 2, 3],
                    ),
                ],
            ),
        )
        @test res["status"] == "completed"
        @test !isempty(res["final_state"]["path"])
        @test res["tests"][1]["passed"] === true

        kruskal_code = """
        function analyze_graph(graph)
            n = node_count(graph)
            parent = collect(1:n)
            find_root(x) = parent[x] == x ? x : (parent[x] = find_root(parent[x]))
            sorted_edges = sort(graph_edges(graph); by = e -> e[3])
            total = 0.0
            for (u, v, w) in sorted_edges
                ru = find_root(u)
                rv = find_root(v)
                accepted = ru != rv
                inspect_edge!(graph, u, v; weight = w, accepted = accepted)
                if accepted
                    parent[rv] = ru
                    mark_tree_edge!(graph, u, v, w)
                    total += w
                end
            end
            return total
        end
        """
        mst_res = run_request(
            Dict(
                "garden" => "graph",
                "algorithm" => "kruskal-mst",
                "code" => kruskal_code,
                "params" => Dict("preset" => "weighted_canopy"),
                "tests" => [
                    Dict(
                        "name" => "triangle_mst",
                        "params" => Dict(
                            "nodes" => [
                                Dict("id" => 1, "label" => "A", "x" => 10, "y" => 50),
                                Dict("id" => 2, "label" => "B", "x" => 50, "y" => 20),
                                Dict("id" => 3, "label" => "C", "x" => 90, "y" => 50),
                            ],
                            "edges" => [[1, 2, 2], [2, 3, 3], [1, 3, 10]],
                        ),
                        "expected_mst_weight" => 5.0,
                    ),
                ],
            ),
        )
        @test mst_res["status"] == "completed"
        @test mst_res["tests"][1]["passed"] === true

        es_err = run_request(
            Dict(
                "garden" => "graph",
                "code" => "function wrong_name(g)\nend",
                "locale" => "es",
            ),
        )
        @test es_err["status"] == "failed"
        @test occursin("analyze_graph(graph)", es_err["error"]["message"])
    end

    @testset "Fractal Garden Raster & Vector" begin
        mandel_code = """
        function render_fractal(plane)
            w, h = plane_size(plane)
            max_it = max_iterations(plane)
            for r in 1:h
                vals = Int[]
                for c in 1:w
                    c0 = pixel_complex(plane, r, c)
                    z = 0.0 + 0.0im
                    it = 0
                    while it < max_it && abs2(z) <= 4.0
                        z = z * z + c0
                        it += 1
                    end
                    push!(vals, it)
                end
                emit_row!(plane, r, vals)
            end
        end
        """
        fres = run_request(
            Dict(
                "garden" => "fractal",
                "algorithm" => "mandelbrot-set",
                "code" => mandel_code,
                "params" => Dict(
                    "width" => 21,
                    "height" => 15,
                    "x_min" => -1.0,
                    "x_max" => 1.0,
                    "y_min" => -1.0,
                    "y_max" => 1.0,
                    "max_iter" => 20,
                ),
                "tests" => [
                    Dict(
                        "name" => "origin_interior",
                        "params" => Dict(
                            "width" => 21,
                            "height" => 15,
                            "x_min" => -1.0,
                            "x_max" => 1.0,
                            "y_min" => -1.0,
                            "y_max" => 1.0,
                            "max_iter" => 20,
                        ),
                        "expected_min_pixels" => 315,
                        "sample_checks" => [Dict("row" => 8, "col" => 11, "expected" => 20)],
                    ),
                ],
            ),
        )
        @test fres["status"] == "completed"
        @test fres["final_state"]["mode"] == "raster"
        @test fres["final_state"]["pixels_computed"] == 315
        @test fres["tests"][1]["passed"] === true

        tree_code = """
        function render_fractal(plane)
            depth = recursion_depth(plane)
            function branch(x, y, angle, len, d, buckets)
                d > depth && return
                x2 = x + len * cos(angle)
                y2 = y - len * sin(angle)
                push!(buckets[d], [x, y, x2, y2])
                branch(x2, y2, angle - 0.45, len * 0.72, d + 1, buckets)
                branch(x2, y2, angle + 0.45, len * 0.72, d + 1, buckets)
            end
            buckets = [Vector{Float64}[] for _ in 1:depth]
            branch(50.0, 92.0, pi / 2, 22.0, 1, buckets)
            for d in 1:depth
                emit_segments!(plane, d, buckets[d])
            end
        end
        """
        vres = run_request(
            Dict(
                "garden" => "fractal",
                "algorithm" => "recursive-tree",
                "code" => tree_code,
                "params" => Dict("depth" => 4),
            ),
        )
        @test vres["status"] == "completed"
        @test vres["final_state"]["mode"] == "vector"
        @test vres["final_state"]["segments_drawn"] == 15
    end

    @testset "Evolution Garden Genetic Algorithm convergence" begin
        ga_code = """
        function evolve_population(env)
            cfg = env_config(env)
            rng = seeded_rng(cfg.seed + 7)
            pop = initial_population(env)
            n = cfg.population_size
            L = cfg.chromosome_length

            for gen in 1:cfg.generations
                fits = [evaluate_fitness(env, g) for g in pop]
                order = sortperm(fits; rev = true)
                mutations = 0
                crossovers = 0

                next_pop = Vector{Vector{Int}}()
                for k in 1:min(cfg.elite_count, n)
                    push!(next_pop, copy(pop[order[k]]))
                end

                pick() = begin
                    a = rand(rng, 1:n)
                    b = rand(rng, 1:n)
                    fits[a] >= fits[b] ? pop[a] : pop[b]
                end

                while length(next_pop) < n
                    p1 = pick()
                    p2 = pick()
                    if rand(rng) < cfg.crossover_rate && L > 1
                        cut = rand(rng, 1:(L - 1))
                        child = vcat(p1[1:cut], p2[(cut + 1):L])
                        crossovers += 1
                    else
                        child = copy(p1)
                    end
                    for i in 1:L
                        if rand(rng) < cfg.mutation_rate
                            child[i] = mutate_bit(child[i])
                            mutations += 1
                        end
                    end
                    push!(next_pop, child)
                end

                record_population!(env, gen, pop, fits; mutations = mutations, crossovers = crossovers)
                pop = next_pop
            end
        end
        """
        eres = run_request(
            Dict(
                "garden" => "evolution",
                "algorithm" => "genetic-algorithm",
                "code" => ga_code,
                "params" => Dict(
                    "seed" => 42,
                    "population_size" => 24,
                    "generations" => 25,
                    "chromosome_length" => 12,
                    "mutation_rate" => 0.05,
                    "crossover_rate" => 0.85,
                ),
                "tests" => [
                    Dict(
                        "name" => "ga_converges",
                        "params" => Dict(
                            "seed" => 42,
                            "population_size" => 24,
                            "generations" => 25,
                            "chromosome_length" => 12,
                            "mutation_rate" => 0.05,
                            "crossover_rate" => 0.85,
                        ),
                        "min_generations" => 20,
                        "min_best_fitness" => 0.9,
                    ),
                ],
            ),
        )
        @test eres["status"] == "completed"
        @test length(eres["events"]) == 25
        @test eres["final_state"]["best_fitness"] >= 0.9
        @test eres["tests"][1]["passed"] === true
    end
end

