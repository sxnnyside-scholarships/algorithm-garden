module PathfindingDomain

using ..RunnerI18n
using ..Trace

export TrackedGrid,
    MinPriorityQueue,
    start_node,
    goal_node,
    grid_size,
    in_bounds,
    is_walkable,
    neighbors,
    step_cost,
    manhattan,
    euclidean,
    frontier!,
    visit!,
    relax_edge!,
    mark_path!,
    enqueue!,
    dequeue!

struct TrackedGrid
    rows::Int
    cols::Int
    start::Tuple{Int, Int}
    goal::Tuple{Int, Int}
    walls::Set{Tuple{Int, Int}}
    weights::Dict{Tuple{Int, Int}, Float64}
    recorder::TraceRecorder

    function TrackedGrid(
        rows::Int,
        cols::Int,
        start::Tuple{Int, Int},
        goal::Tuple{Int, Int},
        walls::Set{Tuple{Int, Int}},
        weights::Dict{Tuple{Int, Int}, Float64},
        recorder::TraceRecorder,
    )
        rows >= 2 && cols >= 2 || throw(ContractError(rmsg("grid_min_dims")))
        _check_coord(rows, cols, start, "start")
        _check_coord(rows, cols, goal, "goal")
        (start in walls || goal in walls) && throw(ContractError(rmsg("start_goal_wall")))
        return new(rows, cols, start, goal, walls, weights, recorder)
    end
end

function _check_coord(rows::Int, cols::Int, pos::Tuple{Int, Int}, label::AbstractString)
    r, c = pos
    if !(1 <= r <= rows && 1 <= c <= cols)
        throw(ContractError(rmsg("coord_oob", "label" => label, "r" => r, "c" => c, "rows" => rows, "cols" => cols)))
    end
end

start_node(g::TrackedGrid)::Tuple{Int, Int} = g.start
goal_node(g::TrackedGrid)::Tuple{Int, Int} = g.goal
grid_size(g::TrackedGrid)::Tuple{Int, Int} = (g.rows, g.cols)

in_bounds(g::TrackedGrid, pos::Tuple{Int, Int})::Bool =
    1 <= pos[1] <= g.rows && 1 <= pos[2] <= g.cols

is_walkable(g::TrackedGrid, pos::Tuple{Int, Int})::Bool =
    in_bounds(g, pos) && !(pos in g.walls)

function neighbors(g::TrackedGrid, pos::Tuple{Int, Int})::Vector{Tuple{Int, Int}}
    r, c = pos
    candidates = ((r - 1, c), (r, c + 1), (r + 1, c), (r, c - 1))
    out = Tuple{Int, Int}[]
    for nxt in candidates
        if is_walkable(g, nxt)
            push!(out, nxt)
        end
    end
    return out
end

function step_cost(g::TrackedGrid, _from::Tuple{Int, Int}, to::Tuple{Int, Int})::Float64
    is_walkable(g, to) || throw(BoundsError(rmsg("target_blocked", "cell" => to)))
    return get(g.weights, to, 1.0)
end

manhattan(a::Tuple{Int, Int}, b::Tuple{Int, Int})::Int = abs(a[1] - b[1]) + abs(a[2] - b[2])
euclidean(a::Tuple{Int, Int}, b::Tuple{Int, Int})::Float64 = hypot(a[1] - b[1], a[2] - b[2])

function frontier!(g::TrackedGrid, pos::Tuple{Int, Int}; cost::Union{Nothing, Real} = nothing)
    in_bounds(g, pos) || throw(BoundsError(rmsg("cell_oob", "cell" => pos)))
    increment_metric!(g.recorder, "frontier_enqueued")
    if isnothing(cost)
        record!(g.recorder, "frontier"; pos=[pos[1], pos[2]])
    else
        record!(g.recorder, "frontier"; pos=[pos[1], pos[2]], cost=Float64(cost))
    end
    return nothing
end

function visit!(g::TrackedGrid, pos::Tuple{Int, Int}; cost::Union{Nothing, Real} = nothing)
    in_bounds(g, pos) || throw(BoundsError(rmsg("cell_oob", "cell" => pos)))
    increment_metric!(g.recorder, "nodes_visited")
    if isnothing(cost)
        record!(g.recorder, "visit"; pos=[pos[1], pos[2]])
    else
        record!(g.recorder, "visit"; pos=[pos[1], pos[2]], cost=Float64(cost))
    end
    return nothing
end

function relax_edge!(
    g::TrackedGrid,
    from::Tuple{Int, Int},
    to::Tuple{Int, Int},
    cost::Real,
)
    in_bounds(g, from) || throw(BoundsError(rmsg("cell_oob", "cell" => from)))
    in_bounds(g, to) || throw(BoundsError(rmsg("cell_oob", "cell" => to)))
    increment_metric!(g.recorder, "edges_relaxed")
    record!(
        g.recorder,
        "relax_edge";
        from=[from[1], from[2]],
        to=[to[1], to[2]],
        cost=Float64(cost),
    )
    return nothing
end

"""
    mark_path!(g::TrackedGrid, path::AbstractVector{<:Tuple{Integer, Integer}}) -> Float64

Validate that `path` is walkable and 4-directionally contiguous, emit `path_found`, and return total cost.
"""
function mark_path!(g::TrackedGrid, path::AbstractVector{<:Tuple{Integer, Integer}})::Float64
    if isempty(path)
        record!(g.recorder, "path_found"; path=Any[], total_cost=0.0)
        return 0.0
    end
    total_cost = 0.0
    prev_cell = (Int(first(path)[1]), Int(first(path)[2]))
    serialized = Vector{Vector{Int}}(undef, length(path))
    for (k, raw_cell) in enumerate(path)
        cell = (Int(raw_cell[1]), Int(raw_cell[2]))
        is_walkable(g, cell) || throw(ContractError(rmsg("path_blocked", "cell" => cell)))
        if k > 1
            if abs(cell[1] - prev_cell[1]) + abs(cell[2] - prev_cell[2]) != 1
                throw(ContractError(rmsg("path_not_contiguous", "prev" => prev_cell, "cell" => cell)))
            end
            total_cost += step_cost(g, prev_cell, cell)
        end
        serialized[k] = [cell[1], cell[2]]
        prev_cell = cell
    end
    record!(g.recorder, "path_found"; path=serialized, total_cost=round(total_cost; digits=4))
    return total_cost
end

# Lightweight binary min-heap priority queue so students can write Dijkstra / A* with zero deps.
mutable struct MinPriorityQueue{K, P <: Real}
    heap::Vector{Tuple{P, Int, K}}
    counter::Int
end

MinPriorityQueue{K, P}() where {K, P <: Real} = MinPriorityQueue{K, P}(Tuple{P, Int, K}[], 0)
MinPriorityQueue() = MinPriorityQueue{Any, Float64}()

Base.isempty(pq::MinPriorityQueue) = isempty(pq.heap)
Base.length(pq::MinPriorityQueue) = length(pq.heap)

function enqueue!(pq::MinPriorityQueue{K, P}, key::K, priority::Real) where {K, P <: Real}
    pq.counter += 1
    push!(pq.heap, (convert(P, priority), pq.counter, key))
    _sift_up!(pq.heap, length(pq.heap))
    return pq
end

function dequeue!(pq::MinPriorityQueue{K, P})::Tuple{K, P} where {K, P <: Real}
    isempty(pq.heap) && throw(ArgumentError(rmsg("pq_empty")))
    top = pq.heap[1]
    last = pop!(pq.heap)
    if !isempty(pq.heap)
        pq.heap[1] = last
        _sift_down!(pq.heap, 1)
    end
    return top[3], top[1]
end

function _sift_up!(heap::Vector{Tuple{P, Int, K}}, idx::Int) where {K, P <: Real}
    while idx > 1
        parent = idx >>> 1
        if (heap[idx][1], heap[idx][2]) < (heap[parent][1], heap[parent][2])
            heap[idx], heap[parent] = heap[parent], heap[idx]
            idx = parent
        else
            break
        end
    end
end

function _sift_down!(heap::Vector{Tuple{P, Int, K}}, idx::Int) where {K, P <: Real}
    n = length(heap)
    while true
        left = idx << 1
        right = left + 1
        smallest = idx
        if left <= n && (heap[left][1], heap[left][2]) < (heap[smallest][1], heap[smallest][2])
            smallest = left
        end
        if right <= n && (heap[right][1], heap[right][2]) < (heap[smallest][1], heap[smallest][2])
            smallest = right
        end
        if smallest != idx
            heap[idx], heap[smallest] = heap[smallest], heap[idx]
            idx = smallest
        else
            break
        end
    end
end

end

