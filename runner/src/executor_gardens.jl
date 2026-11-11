function _default_cellular_pattern(preset::AbstractString, rows::Int, cols::Int)::Matrix{Int}
    mat = zeros(Int, rows, cols)
    mr = max(2, rows ÷ 2)
    mc = max(2, cols ÷ 2)

    if preset == "blinker"
        for dc in -1:1
            c = clamp(mc + dc, 1, cols)
            mat[mr, c] = 1
        end
    elseif preset == "r_pentomino"
        coords = ((0, 0), (0, 1), (-1, 0), (1, 0), (-1, -1))
        for (dr, dc) in coords
            r = clamp(mr + dr, 1, rows)
            c = clamp(mc + dc, 1, cols)
            mat[r, c] = 1
        end
    elseif preset == "brians_glider"
        coords_on = ((0, 0), (0, 1), (1, -1), (1, 2))
        coords_dying = ((-1, 0), (-1, 1))
        for (dr, dc) in coords_on
            mat[clamp(mr + dr, 1, rows), clamp(mc + dc, 1, cols)] = 1
        end
        for (dr, dc) in coords_dying
            mat[clamp(mr + dr, 1, rows), clamp(mc + dc, 1, cols)] = 2
        end
    elseif preset == "random"
        rng = MersenneTwister(42)
        for r in 1:rows, c in 1:cols
            mat[r, c] = rand(rng) < 0.32 ? 1 : 0
        end
    else
        # Default classic glider near top-left quarter
        r0 = clamp(2, 1, max(1, rows - 3))
        c0 = clamp(2, 1, max(1, cols - 3))
        for (dr, dc) in ((0, 1), (1, 2), (2, 0), (2, 1), (2, 2))
            (r0 + dr <= rows && c0 + dc <= cols) && (mat[r0 + dr, c0 + dc] = 1)
        end
    end
    return mat
end

function _build_cellular_spec(params::AbstractDict)
    rows = clamp(Int(get(params, "rows", 14)), 2, 48)
    cols = clamp(Int(get(params, "cols", 18)), 2, 48)
    generations = clamp(Int(get(params, "generations", 16)), 1, 60)
    wrap = Bool(get(params, "wrap", true))
    born = haskey(params, "born") && params["born"] isa AbstractVector ? Int[Int(x) for x in params["born"]] : Int[3]
    survive =
        haskey(params, "survive") && params["survive"] isa AbstractVector ? Int[Int(x) for x in params["survive"]] :
        Int[2, 3]

    cells = zeros(Int, rows, cols)
    if haskey(params, "cells") && params["cells"] isa AbstractVector && length(params["cells"]) == rows
        for r in 1:rows
            row_vec = params["cells"][r]
            row_vec isa AbstractVector && length(row_vec) == cols ||
                throw(ContractError(rmsg("cellular_matrix_size")))
            for c in 1:cols
                cells[r, c] = Int(row_vec[c])
            end
        end
    elseif haskey(params, "live_cells") && params["live_cells"] isa AbstractVector
        for item in params["live_cells"]
            (item isa AbstractVector && length(item) >= 2) ||
                throw(ContractError(rmsg("coord_format", "label" => "live_cell")))
            r = Int(item[1])
            c = Int(item[2])
            st = length(item) >= 3 ? Int(item[3]) : 1
            (1 <= r <= rows && 1 <= c <= cols) ||
                throw(ContractError(rmsg("cell_oob", "cell" => "($r, $c)")))
            cells[r, c] = st
        end
    else
        preset = String(get(params, "preset", "glider"))
        cells = _default_cellular_pattern(preset, rows, cols)
    end

    return (rows = rows, cols = cols, cells = cells, born = born, survive = survive, generations = generations, wrap = wrap)
end

function _run_cellular(
    mod::Module,
    params::AbstractDict;
    max_events::Int,
    timeout_ms::Int,
    record_events::Bool = true,
)
    fn = _resolve_entry_fn(mod, :evolve_cellular, "evolve_cellular(grid)")
    spec = _build_cellular_spec(params)
    initial_cells = copy(spec.cells)
    rec = TraceRecorder(; max_events=max_events, timeout_ms=timeout_ms, record_events=record_events)
    grid = CellularGrid(spec.rows, spec.cols, spec.cells, spec.born, spec.survive, spec.generations, spec.wrap, rec)

    t0 = time_ns()
    Base.invokelatest(fn, grid)
    elapsed_ms = (time_ns() - t0) / 1e6

    initial_state = Dict{String, Any}(
        "rows" => spec.rows,
        "cols" => spec.cols,
        "cells" => matrix_to_rows(initial_cells),
        "born" => spec.born,
        "survive" => spec.survive,
        "generations" => spec.generations,
        "wrap" => spec.wrap,
    )
    final_state = Dict{String, Any}(
        "cells" => matrix_to_rows(grid.cells),
        "generations" => rec.metrics["generations_simulated"],
        "alive_count" => count(==(1), grid.cells),
    )
    return (
        initial_state = initial_state,
        final_state = final_state,
        events = rec.events,
        metrics = snapshot_metrics(rec, elapsed_ms),
    )
end

function _verify_cellular_test(mod::Module, tc::AbstractDict, max_events::Int, timeout_ms::Int)
    name = String(get(tc, "name", "test"))
    tparams = get(tc, "params", Dict{String, Any}())
    res = _run_cellular(mod, tparams; max_events=max_events, timeout_ms=timeout_ms, record_events=true)

    min_gens = Int(get(tc, "min_generations", 1))
    actual_gens = Int(res.final_state["generations"])
    if actual_gens < min_gens
        return Dict{String, Any}(
            "name" => name,
            "passed" => false,
            "message" => rmsg("cellular_gens_fail", "expected" => min_gens, "actual" => actual_gens),
        )
    end

    if haskey(tc, "expected_cells") && tc["expected_cells"] !== nothing
        expected = tc["expected_cells"]
        if res.final_state["cells"] != expected
            return Dict{String, Any}(
                "name" => name,
                "passed" => false,
                "message" => rmsg("cellular_cells_fail"),
            )
        end
    end

    if haskey(tc, "expected_alive") && tc["expected_alive"] !== nothing
        if Int(res.final_state["alive_count"]) != Int(tc["expected_alive"])
            return Dict{String, Any}(
                "name" => name,
                "passed" => false,
                "message" => rmsg("cellular_cells_fail"),
            )
        end
    end

    return Dict{String, Any}("name" => name, "passed" => true, "message" => rmsg("cellular_valid"))
end

function _default_graph_spec(preset::AbstractString)
    if preset == "two_islands"
        nodes = Dict{String, Any}[
            Dict("id" => 1, "label" => "A", "x" => 18, "y" => 28),
            Dict("id" => 2, "label" => "B", "x" => 36, "y" => 22),
            Dict("id" => 3, "label" => "C", "x" => 34, "y" => 52),
            Dict("id" => 4, "label" => "D", "x" => 16, "y" => 66),
            Dict("id" => 5, "label" => "E", "x" => 66, "y" => 26),
            Dict("id" => 6, "label" => "F", "x" => 84, "y" => 42),
            Dict("id" => 7, "label" => "G", "x" => 70, "y" => 72),
            Dict("id" => 8, "label" => "H", "x" => 48, "y" => 82),
        ]
        edges = Tuple{Int, Int, Float64}[
            (1, 2, 1.0),
            (2, 3, 2.0),
            (3, 4, 1.0),
            (1, 3, 3.0),
            (5, 6, 1.0),
            (6, 7, 2.0),
            (5, 7, 4.0),
        ]
        return nodes, edges, 1, 7
    elseif preset == "weighted_canopy"
        nodes = Dict{String, Any}[
            Dict("id" => 1, "label" => "Root", "x" => 14, "y" => 50),
            Dict("id" => 2, "label" => "Fern", "x" => 35, "y" => 20),
            Dict("id" => 3, "label" => "Moss", "x" => 35, "y" => 80),
            Dict("id" => 4, "label" => "Lotus", "x" => 60, "y" => 22),
            Dict("id" => 5, "label" => "Iris", "x" => 58, "y" => 78),
            Dict("id" => 6, "label" => "Crown", "x" => 86, "y" => 50),
        ]
        edges = Tuple{Int, Int, Float64}[
            (1, 2, 4.0),
            (1, 3, 2.0),
            (2, 3, 1.0),
            (2, 4, 5.0),
            (3, 4, 8.0),
            (3, 5, 6.0),
            (4, 5, 2.0),
            (4, 6, 3.0),
            (5, 6, 7.0),
        ]
        return nodes, edges, 1, 6
    end

    # Default botanical_web
    nodes = Dict{String, Any}[
        Dict("id" => 1, "label" => "1", "x" => 16, "y" => 50),
        Dict("id" => 2, "label" => "2", "x" => 36, "y" => 20),
        Dict("id" => 3, "label" => "3", "x" => 36, "y" => 80),
        Dict("id" => 4, "label" => "4", "x" => 60, "y" => 24),
        Dict("id" => 5, "label" => "5", "x" => 60, "y" => 76),
        Dict("id" => 6, "label" => "6", "x" => 84, "y" => 50),
        Dict("id" => 7, "label" => "7", "x" => 48, "y" => 50),
    ]
    edges = Tuple{Int, Int, Float64}[
        (1, 2, 2.0),
        (1, 3, 3.0),
        (2, 4, 4.0),
        (2, 7, 1.0),
        (3, 5, 2.0),
        (3, 7, 3.0),
        (7, 4, 2.0),
        (7, 5, 1.0),
        (4, 6, 3.0),
        (5, 6, 2.0),
    ]
    return nodes, edges, 1, 6
end

function _build_graph_spec(params::AbstractDict)
    directed = Bool(get(params, "directed", false))
    if haskey(params, "nodes") && params["nodes"] isa AbstractVector && !isempty(params["nodes"])
        raw_nodes = params["nodes"]
        nodes = Dict{String, Any}[]
        for (idx, nd) in enumerate(raw_nodes)
            if nd isa AbstractDict
                nid = Int(get(nd, "id", idx))
                push!(
                    nodes,
                    Dict{String, Any}(
                        "id" => nid,
                        "label" => String(get(nd, "label", string(nid))),
                        "x" => Float64(get(nd, "x", 50.0)),
                        "y" => Float64(get(nd, "y", 50.0)),
                    ),
                )
            end
        end
        edges = Tuple{Int, Int, Float64}[]
        if haskey(params, "edges") && params["edges"] isa AbstractVector
            for e in params["edges"]
                if e isa AbstractVector && length(e) >= 2
                    u = Int(e[1])
                    v = Int(e[2])
                    w = length(e) >= 3 ? Float64(e[3]) : 1.0
                    push!(edges, (u, v, w))
                end
            end
        end
        s = clamp(Int(get(params, "start_node", 1)), 1, length(nodes))
        t = clamp(Int(get(params, "target_node", length(nodes))), 1, length(nodes))
        return nodes, edges, directed, s, t
    end

    preset = String(get(params, "preset", "botanical_web"))
    nodes, edges, def_s, def_t = _default_graph_spec(preset)
    s = clamp(Int(get(params, "start_node", def_s)), 1, length(nodes))
    t = clamp(Int(get(params, "target_node", def_t)), 1, length(nodes))
    return nodes, edges, directed, s, t
end

function _run_graph(
    mod::Module,
    params::AbstractDict;
    max_events::Int,
    timeout_ms::Int,
    record_events::Bool = true,
)
    fn = _resolve_entry_fn(mod, :analyze_graph, "analyze_graph(graph)")
    nodes, edges, directed, start_node, target_node = _build_graph_spec(params)
    rec = TraceRecorder(; max_events=max_events, timeout_ms=timeout_ms, record_events=record_events)
    graph = TrackedGraph(nodes, edges, directed, start_node, target_node, rec)

    t0 = time_ns()
    raw_res = Base.invokelatest(fn, graph)
    elapsed_ms = (time_ns() - t0) / 1e6

    mst_weight = 0.0
    mst_edges = Vector{Vector{Any}}()
    components = Dict{String, Int}()
    discovered_path = Int[]
    for ev in rec.events
        etype = get(ev, "type", "")
        if etype == "graph_mst_edge"
            w = Float64(get(ev, "weight", 1.0))
            mst_weight += w
            push!(mst_edges, Any[ev["from_node"], ev["to_node"], w])
        elseif etype == "graph_component"
            components[string(ev["node"])] = Int(ev["component"])
        elseif etype == "graph_path"
            discovered_path = Int[Int(x) for x in get(ev, "path", Int[])]
        end
    end

    serialized_ret = raw_res isa AbstractVector ? Any[x for x in raw_res] : raw_res isa Real ? raw_res : nothing
    initial_state = Dict{String, Any}(
        "nodes" => nodes,
        "edges" => Any[Any[u, v, w] for (u, v, w) in edges],
        "directed" => directed,
        "start_node" => start_node,
        "target_node" => target_node,
    )
    final_state = Dict{String, Any}(
        "path" => discovered_path,
        "mst_edges" => mst_edges,
        "mst_weight" => round(mst_weight; digits = 4),
        "components" => components,
        "result" => serialized_ret,
    )
    return (
        initial_state = initial_state,
        final_state = final_state,
        events = rec.events,
        metrics = snapshot_metrics(rec, elapsed_ms),
    )
end

function _verify_graph_test(mod::Module, tc::AbstractDict, max_events::Int, timeout_ms::Int)
    name = String(get(tc, "name", "test"))
    tparams = get(tc, "params", Dict{String, Any}())
    res = _run_graph(mod, tparams; max_events=max_events, timeout_ms=timeout_ms, record_events=true)

    if haskey(tc, "expected_path") && tc["expected_path"] !== nothing
        expected = Int[Int(x) for x in tc["expected_path"]]
        actual = Int[Int(x) for x in res.final_state["path"]]
        if actual != expected
            return Dict{String, Any}(
                "name" => name,
                "passed" => false,
                "message" => rmsg("graph_path_fail", "expected" => expected, "actual" => actual),
            )
        end
    end

    if haskey(tc, "expected_mst_weight") && tc["expected_mst_weight"] !== nothing
        exp_w = Float64(tc["expected_mst_weight"])
        act_w = Float64(res.final_state["mst_weight"])
        if abs(act_w - exp_w) > 1e-4
            return Dict{String, Any}(
                "name" => name,
                "passed" => false,
                "message" => rmsg("graph_mst_fail", "expected" => exp_w, "actual" => act_w),
            )
        end
    end

    if haskey(tc, "expected_components") && tc["expected_components"] !== nothing
        comp_map = res.final_state["components"]
        grouped = Dict{Int, Vector{Int}}()
        for (k, cid) in comp_map
            push!(get!(grouped, Int(cid), Int[]), parse(Int, String(k)))
        end
        actual_sets = Set(sort(v) for v in values(grouped))
        expected_sets = Set(sort(Int[Int(x) for x in grp]) for grp in tc["expected_components"])
        if actual_sets != expected_sets
            return Dict{String, Any}("name" => name, "passed" => false, "message" => rmsg("graph_comp_fail"))
        end
    end

    return Dict{String, Any}("name" => name, "passed" => true, "message" => rmsg("graph_valid"))
end

function _run_fractal(
    mod::Module,
    params::AbstractDict;
    max_events::Int,
    timeout_ms::Int,
    record_events::Bool = true,
)
    fn = _resolve_entry_fn(mod, :render_fractal, "render_fractal(plane)")
    width = Int(get(params, "width", 64))
    height = Int(get(params, "height", 48))
    x_min = Float64(get(params, "x_min", -2.1))
    x_max = Float64(get(params, "x_max", 0.8))
    y_min = Float64(get(params, "y_min", -1.2))
    y_max = Float64(get(params, "y_max", 1.2))
    max_iter = Int(get(params, "max_iter", 40))
    julia_re = Float64(get(params, "julia_re", -0.7))
    julia_im = Float64(get(params, "julia_im", 0.27015))
    depth = Int(get(params, "depth", 5))

    rec = TraceRecorder(; max_events=max_events, timeout_ms=timeout_ms, record_events=record_events)
    plane = FractalPlane(width, height, x_min, x_max, y_min, y_max, max_iter, julia_re, julia_im, depth, rec)

    t0 = time_ns()
    Base.invokelatest(fn, plane)
    elapsed_ms = (time_ns() - t0) / 1e6

    mode = rec.metrics["segments_drawn"] > 0 ? "vector" : "raster"
    initial_state = Dict{String, Any}(
        "width" => plane.width,
        "height" => plane.height,
        "x_min" => plane.x_min,
        "x_max" => plane.x_max,
        "y_min" => plane.y_min,
        "y_max" => plane.y_max,
        "max_iter" => plane.max_iter,
        "julia_re" => plane.julia_re,
        "julia_im" => plane.julia_im,
        "depth" => plane.depth,
        "mode" => mode,
    )
    final_state = Dict{String, Any}(
        "mode" => mode,
        "pixels_computed" => rec.metrics["pixels_computed"],
        "segments_drawn" => rec.metrics["segments_drawn"],
        "rows" => plane.rows_buffer,
        "segments" => plane.segments_buffer,
    )
    return (
        initial_state = initial_state,
        final_state = final_state,
        events = rec.events,
        metrics = snapshot_metrics(rec, elapsed_ms),
    )
end

function _verify_fractal_test(mod::Module, tc::AbstractDict, max_events::Int, timeout_ms::Int)
    name = String(get(tc, "name", "test"))
    tparams = get(tc, "params", Dict{String, Any}())
    res = _run_fractal(mod, tparams; max_events=max_events, timeout_ms=timeout_ms, record_events=true)

    if haskey(tc, "expected_min_pixels") &&
       Int(res.final_state["pixels_computed"]) < Int(tc["expected_min_pixels"])
        return Dict{String, Any}("name" => name, "passed" => false, "message" => rmsg("fractal_verify_fail"))
    end
    if haskey(tc, "expected_min_segments") &&
       Int(res.final_state["segments_drawn"]) < Int(tc["expected_min_segments"])
        return Dict{String, Any}("name" => name, "passed" => false, "message" => rmsg("fractal_verify_fail"))
    end
    if haskey(tc, "sample_checks") && tc["sample_checks"] isa AbstractVector
        rows_buf = res.final_state["rows"]
        for chk in tc["sample_checks"]
            r = Int(chk["row"])
            c = Int(chk["col"])
            val = Int(rows_buf[r][c])
            if haskey(chk, "expected") && val != Int(chk["expected"])
                return Dict{String, Any}("name" => name, "passed" => false, "message" => rmsg("fractal_verify_fail"))
            end
            if haskey(chk, "min") && val < Int(chk["min"])
                return Dict{String, Any}("name" => name, "passed" => false, "message" => rmsg("fractal_verify_fail"))
            end
            if haskey(chk, "max") && val > Int(chk["max"])
                return Dict{String, Any}("name" => name, "passed" => false, "message" => rmsg("fractal_verify_fail"))
            end
        end
    end

    return Dict{String, Any}("name" => name, "passed" => true, "message" => rmsg("fractal_valid"))
end

function _run_evolution(
    mod::Module,
    params::AbstractDict;
    max_events::Int,
    timeout_ms::Int,
    record_events::Bool = true,
)
    fn = _resolve_entry_fn(mod, :evolve_population, "evolve_population(env)")
    seed = Int(get(params, "seed", 42))
    pop_size = Int(get(params, "population_size", 18))
    generations = Int(get(params, "generations", 20))
    chrom_len = Int(get(params, "chromosome_length", 16))
    mut_rate = Float64(get(params, "mutation_rate", 0.06))
    cross_rate = Float64(get(params, "crossover_rate", 0.8))
    elite_count = Int(get(params, "elite_count", 2))
    raw_target = get(params, "target_gene", nothing)
    target =
        raw_target isa AbstractVector && !isempty(raw_target) ? Int[Int(x) != 0 ? 1 : 0 for x in raw_target] :
        Int[i % 2 for i in 1:chrom_len]

    rec = TraceRecorder(; max_events=max_events, timeout_ms=timeout_ms, record_events=record_events)
    env = EvolutionEnvironment(
        seed,
        pop_size,
        generations,
        chrom_len,
        mut_rate,
        cross_rate,
        elite_count,
        target,
        rec,
    )

    t0 = time_ns()
    Base.invokelatest(fn, env)
    elapsed_ms = (time_ns() - t0) / 1e6

    initial_state = Dict{String, Any}(
        "seed" => env.seed,
        "population_size" => env.population_size,
        "generations" => env.generations,
        "chromosome_length" => env.chromosome_length,
        "mutation_rate" => env.mutation_rate,
        "crossover_rate" => env.crossover_rate,
        "elite_count" => env.elite_count,
        "target_gene" => env.target_gene,
    )
    final_state = Dict{String, Any}(
        "best_fitness" => env.best_fitness,
        "best_genome" => env.best_genome,
        "generations" => rec.metrics["generations_simulated"],
    )
    return (
        initial_state = initial_state,
        final_state = final_state,
        events = rec.events,
        metrics = snapshot_metrics(rec, elapsed_ms),
    )
end

function _verify_evolution_test(mod::Module, tc::AbstractDict, max_events::Int, timeout_ms::Int)
    name = String(get(tc, "name", "test"))
    tparams = get(tc, "params", Dict{String, Any}())
    res = _run_evolution(mod, tparams; max_events=max_events, timeout_ms=timeout_ms, record_events=true)

    min_gens = Int(get(tc, "min_generations", 2))
    actual_gens = Int(res.final_state["generations"])
    if actual_gens < min_gens
        return Dict{String, Any}(
            "name" => name,
            "passed" => false,
            "message" => rmsg("cellular_gens_fail", "expected" => min_gens, "actual" => actual_gens),
        )
    end

    min_fit = Float64(get(tc, "min_best_fitness", 0.8))
    act_fit = Float64(res.final_state["best_fitness"])
    if act_fit + 1e-6 < min_fit
        return Dict{String, Any}(
            "name" => name,
            "passed" => false,
            "message" => rmsg("evolution_verify_fail", "expected" => min_fit, "actual" => act_fit),
        )
    end

    return Dict{String, Any}("name" => name, "passed" => true, "message" => rmsg("evolution_valid"))
end

