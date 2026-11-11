module Executor

using Random
using ..GardenJSON
using ..RunnerI18n
using ..Trace
using ..SortingDomain
using ..PathfindingDomain
using ..CellularDomain
using ..GraphDomain
using ..FractalDomain
using ..EvolutionDomain
using ..Sandbox

export run_request

include("executor_gardens.jl")

function _build_sorting_values(params::AbstractDict)::Vector{Int}
    if haskey(params, "values") && params["values"] !== nothing
        raw = params["values"]
        raw isa AbstractVector || throw(ContractError(rmsg("values_array")))
        isempty(raw) && throw(ContractError(rmsg("values_empty")))
        length(raw) > 500 && throw(ContractError(rmsg("values_too_long")))
        return [Int(x) for x in raw]
    end

    size = Int(get(params, "size", 20))
    (2 <= size <= 500) || throw(ContractError(rmsg("size_range")))
    dist = String(get(params, "distribution", "random"))
    seed = Int(get(params, "seed", 42))
    rng = MersenneTwister(seed)

    if dist == "random"
        return rand(rng, 5:100, size)
    elseif dist == "reversed"
        return collect(size:-1:1) .* 4
    elseif dist == "nearly_sorted"
        arr = collect(1:size) .* 4
        swaps = max(1, size ÷ 8)
        for _ in 1:swaps
            i = rand(rng, 1:size)
            j = rand(rng, 1:size)
            arr[i], arr[j] = arr[j], arr[i]
        end
        return arr
    elseif dist == "few_unique"
        palette = [15, 35, 55, 75, 95]
        return [palette[rand(rng, 1:length(palette))] for _ in 1:size]
    else
        throw(ContractError(rmsg("unsupported_dist", "dist" => dist)))
    end
end

function _parse_coord(raw, label::AbstractString)::Tuple{Int, Int}
    (raw isa AbstractVector && length(raw) == 2) ||
        throw(ContractError(rmsg("coord_format", "label" => label)))
    return (Int(raw[1]), Int(raw[2]))
end

function _build_grid_spec(params::AbstractDict)
    rows = Int(get(params, "rows", 12))
    cols = Int(get(params, "cols", 18))
    (2 <= rows <= 60 && 2 <= cols <= 60) ||
        throw(ContractError(rmsg("grid_dims")))

    start = haskey(params, "start") ? _parse_coord(params["start"], "start") : (1, 1)
    goal = haskey(params, "goal") ? _parse_coord(params["goal"], "goal") : (rows, cols)

    walls = Set{Tuple{Int, Int}}()
    if haskey(params, "walls") && params["walls"] !== nothing
        for item in params["walls"]
            push!(walls, _parse_coord(item, "wall"))
        end
    end

    weights = Dict{Tuple{Int, Int}, Float64}()
    if haskey(params, "weights") && params["weights"] !== nothing
        for item in params["weights"]
            (item isa AbstractVector && length(item) == 3) ||
                throw(ContractError(rmsg("weight_entry")))
            w = Float64(item[3])
            w > 0 || throw(ContractError(rmsg("weight_positive")))
            weights[(Int(item[1]), Int(item[2]))] = w
        end
    end

    return (rows = rows, cols = cols, start = start, goal = goal, walls = walls, weights = weights)
end

function _resolve_entry_fn(mod::Module, sym::Symbol, signature_hint::String)
    return Base.invokelatest() do
        isdefined(mod, sym) || throw(ContractError(rmsg("missing_fn", "sig" => signature_hint)))
        return getfield(mod, sym)
    end
end

function _run_sorting(
    mod::Module,
    params::AbstractDict;
    max_events::Int,
    timeout_ms::Int,
    record_events::Bool = true,
)
    fn = _resolve_entry_fn(mod, :sort_algorithm!, "sort_algorithm!(arr)")
    values = _build_sorting_values(params)
    rec = TraceRecorder(; max_events=max_events, timeout_ms=timeout_ms, record_events=record_events)
    arr = TrackedVector(values, rec)

    t0 = time_ns()
    Base.invokelatest(fn, arr)
    elapsed_ms = (time_ns() - t0) / 1e6

    return (
        initial_state = Dict{String, Any}("values" => values),
        final_state = Dict{String, Any}("values" => copy(arr.data)),
        events = rec.events,
        metrics = snapshot_metrics(rec, elapsed_ms),
    )
end

function _run_pathfinding(
    mod::Module,
    params::AbstractDict;
    max_events::Int,
    timeout_ms::Int,
    record_events::Bool = true,
)
    fn = _resolve_entry_fn(mod, :find_path, "find_path(grid)")
    spec = _build_grid_spec(params)
    rec = TraceRecorder(; max_events=max_events, timeout_ms=timeout_ms, record_events=record_events)
    grid = TrackedGrid(spec.rows, spec.cols, spec.start, spec.goal, spec.walls, spec.weights, rec)

    t0 = time_ns()
    raw_path = Base.invokelatest(fn, grid)
    elapsed_ms = (time_ns() - t0) / 1e6

    raw_path isa AbstractVector ||
        throw(ContractError(rmsg("find_path_return")))
    path = Tuple{Int, Int}[(Int(p[1]), Int(p[2])) for p in raw_path]
    total_cost = mark_path!(grid, path)

    initial_state = Dict{String, Any}(
        "rows" => spec.rows,
        "cols" => spec.cols,
        "start" => [spec.start[1], spec.start[2]],
        "goal" => [spec.goal[1], spec.goal[2]],
        "walls" => [[w[1], w[2]] for w in sort!(collect(spec.walls))],
        "weights" => [[k[1], k[2], v] for (k, v) in spec.weights],
    )
    final_state = Dict{String, Any}(
        "path" => [[p[1], p[2]] for p in path],
        "found" => !isempty(path),
        "total_cost" => round(total_cost; digits=4),
    )

    return (
        initial_state = initial_state,
        final_state = final_state,
        events = rec.events,
        metrics = snapshot_metrics(rec, elapsed_ms),
    )
end

function _verify_sorting_test(mod::Module, tc::AbstractDict, max_events::Int, timeout_ms::Int)
    name = String(get(tc, "name", "test"))
    tparams = get(tc, "params", Dict{String, Any}())
    res = _run_sorting(mod, tparams; max_events=max_events, timeout_ms=timeout_ms, record_events=false)
    actual = res.final_state["values"]
    expected = sort(res.initial_state["values"])
    passed = actual == expected
    msg = passed ? rmsg("sort_pass") : rmsg("sort_fail", "expected" => expected, "actual" => actual)
    return Dict{String, Any}("name" => name, "passed" => passed, "message" => msg)
end

function _verify_pathfinding_test(mod::Module, tc::AbstractDict, max_events::Int, timeout_ms::Int)
    name = String(get(tc, "name", "test"))
    tparams = get(tc, "params", Dict{String, Any}())
    res = _run_pathfinding(mod, tparams; max_events=max_events, timeout_ms=timeout_ms, record_events=false)
    path = res.final_state["path"]
    expect_reachable = Bool(get(tc, "expect_reachable", true))
    expected_cost = get(tc, "expected_cost", nothing)

    if !expect_reachable
        passed = isempty(path)
        msg = passed ? rmsg("path_unreachable_ok") : rmsg("path_unreachable_fail")
        return Dict{String, Any}("name" => name, "passed" => passed, "message" => msg)
    end

    start = res.initial_state["start"]
    goal = res.initial_state["goal"]
    if isempty(path) || path[1] != start || path[end] != goal
        return Dict{String, Any}(
            "name" => name,
            "passed" => false,
            "message" => rmsg("path_endpoints", "start" => start, "goal" => goal),
        )
    end

    if expected_cost !== nothing
        actual_cost = Float64(res.final_state["total_cost"])
        if abs(actual_cost - Float64(expected_cost)) > 1e-4
            return Dict{String, Any}(
                "name" => name,
                "passed" => false,
                "message" => rmsg("path_cost", "expected" => expected_cost, "actual" => actual_cost),
            )
        end
    end

    return Dict{String, Any}("name" => name, "passed" => true, "message" => rmsg("path_valid"))
end

const GARDEN_HANDLERS = Dict{String, NamedTuple{(:run, :verify), Tuple{Any, Any}}}(
    "sorting" => (run = _run_sorting, verify = _verify_sorting_test),
    "pathfinding" => (run = _run_pathfinding, verify = _verify_pathfinding_test),
    "cellular" => (run = _run_cellular, verify = _verify_cellular_test),
    "graph" => (run = _run_graph, verify = _verify_graph_test),
    "fractal" => (run = _run_fractal, verify = _verify_fractal_test),
    "evolution" => (run = _run_evolution, verify = _verify_evolution_test),
)

function run_request(payload::AbstractDict)::Dict{String, Any}
    garden = String(get(payload, "garden", ""))
    algorithm = String(get(payload, "algorithm", "custom"))
    code = String(get(payload, "code", ""))
    params = get(payload, "params", Dict{String, Any}())
    tests_spec = get(payload, "tests", nothing)
    max_events = Int(get(payload, "max_events", 50_000))
    timeout_ms = Int(get(payload, "timeout_ms", 5_000))
    locale = normalize_locale(get(payload, "locale", "en"))

    return with_locale(locale) do
        try
            mod = compile_student_module(code)

            haskey(GARDEN_HANDLERS, garden) ||
                throw(ContractError(rmsg("unknown_garden", "garden" => garden)))
            handlers = GARDEN_HANDLERS[garden]

            res = handlers.run(mod, params; max_events=max_events, timeout_ms=timeout_ms)

            test_results = nothing
            if tests_spec isa AbstractVector
                test_results = [
                    handlers.verify(mod, tc, max_events, timeout_ms) for tc in tests_spec
                ]
            end

            return Dict{String, Any}(
                "status" => "completed",
                "garden" => garden,
                "algorithm" => algorithm,
                "initial_state" => res.initial_state,
                "events" => res.events,
                "final_state" => res.final_state,
                "metrics" => res.metrics,
                "tests" => test_results,
                "error" => nothing,
            )
        catch err
            bt = catch_backtrace()
            return Dict{String, Any}(
                "status" => "failed",
                "garden" => garden,
                "algorithm" => algorithm,
                "initial_state" => nothing,
                "events" => Any[],
                "final_state" => nothing,
                "metrics" => nothing,
                "tests" => nothing,
                "error" => classify_error(err, bt),
            )
        end
    end
end

end

