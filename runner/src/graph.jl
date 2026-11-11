module GraphDomain

using ..RunnerI18n
using ..Trace

export TrackedGraph,
    node_count,
    graph_nodes,
    graph_edges,
    start_vertex,
    target_vertex,
    adjacent,
    visit_node!,
    queue_node!,
    inspect_edge!,
    mark_component!,
    mark_tree_edge!,
    mark_graph_path!

"""
    TrackedGraph

Weighted/unweighted graph abstraction instrumented for traversals, components, and MSTs.
"""
struct TrackedGraph
    nodes::Vector{Dict{String, Any}}
    edges::Vector{Tuple{Int, Int, Float64}}
    adj::Vector{Vector{Tuple{Int, Float64}}}
    directed::Bool
    start_node::Int
    target_node::Int
    rec::TraceRecorder
end

function TrackedGraph(
    nodes::Vector{Dict{String, Any}},
    edges::Vector{Tuple{Int, Int, Float64}},
    directed::Bool,
    start_node::Integer,
    target_node::Integer,
    rec::TraceRecorder,
)
    n = length(nodes)
    n >= 2 || throw(ContractError(rmsg("graph_min_nodes")))
    s = Int(start_node)
    t = Int(target_node)
    (1 <= s <= n && 1 <= t <= n) || throw(ContractError(rmsg("graph_vertex_oob", "v" => "$s/$t")))

    adj = [Tuple{Int, Float64}[] for _ in 1:n]
    for (u, v, w) in edges
        (1 <= u <= n && 1 <= v <= n) || throw(ContractError(rmsg("graph_vertex_oob", "v" => "$u/$v")))
        push!(adj[u], (v, w))
        if !directed && u != v
            push!(adj[v], (u, w))
        end
    end
    for i in 1:n
        sort!(adj[i]; by = first)
    end
    return TrackedGraph(nodes, edges, adj, directed, s, t, rec)
end

function _check_vertex(g::TrackedGraph, u::Integer)
    ui = Int(u)
    (1 <= ui <= length(g.nodes)) || throw(ContractError(rmsg("graph_vertex_oob", "v" => ui)))
    return ui
end

"""Return total number of vertices."""
node_count(g::TrackedGraph)::Int = length(g.nodes)

"""Return the `1:N` range of vertex identifiers."""
graph_nodes(g::TrackedGraph)::UnitRange{Int} = 1:length(g.nodes)

"""Return the list of graph edges as `(u, v, weight)` tuples."""
graph_edges(g::TrackedGraph)::Vector{Tuple{Int, Int, Float64}} = copy(g.edges)

"""Return the configured start vertex id."""
start_vertex(g::TrackedGraph)::Int = g.start_node

"""Return the configured target vertex id."""
target_vertex(g::TrackedGraph)::Int = g.target_node

"""Return sorted `(neighbor, weight)` tuples adjacent to vertex `u`."""
function adjacent(g::TrackedGraph, u::Integer)::Vector{Tuple{Int, Float64}}
    ui = _check_vertex(g, u)
    return copy(g.adj[ui])
end

"""Record adding vertex `u` to the exploration frontier."""
function queue_node!(g::TrackedGraph, u::Integer; from::Union{Integer, Nothing} = nothing)
    ui = _check_vertex(g, u)
    increment_metric!(g.rec, "frontier_enqueued", 1)
    if from === nothing
        record!(g.rec, "graph_frontier"; node = ui)
    else
        fi = _check_vertex(g, from)
        record!(g.rec, "graph_frontier"; node = ui, from = fi)
    end
end

"""Record visiting vertex `u` (optionally tagged with a component id)."""
function visit_node!(g::TrackedGraph, u::Integer; component::Union{Integer, Nothing} = nothing)
    ui = _check_vertex(g, u)
    increment_metric!(g.rec, "nodes_visited", 1)
    if component === nothing
        record!(g.rec, "graph_visit"; node = ui)
    else
        record!(g.rec, "graph_visit"; node = ui, component = Int(component))
    end
end

"""Record inspecting edge `(u, v)` during traversal or MST construction."""
function inspect_edge!(
    g::TrackedGraph,
    u::Integer,
    v::Integer;
    weight::Union{Real, Nothing} = nothing,
    accepted::Bool = false,
)
    ui = _check_vertex(g, u)
    vi = _check_vertex(g, v)
    increment_metric!(g.rec, "edges_relaxed", 1)
    w = weight === nothing ? 1.0 : Float64(weight)
    record!(g.rec, "graph_edge"; from_node = ui, to_node = vi, weight = w, accepted = accepted)
end

"""Assign vertex `u` to connected component `component_id`."""
function mark_component!(g::TrackedGraph, u::Integer, component_id::Integer)
    ui = _check_vertex(g, u)
    cid = Int(component_id)
    record!(g.rec, "graph_component"; node = ui, component = cid)
end

"""Record an accepted Minimum Spanning Tree edge `(u, v)`."""
function mark_tree_edge!(g::TrackedGraph, u::Integer, v::Integer, weight::Real = 1.0)
    ui = _check_vertex(g, u)
    vi = _check_vertex(g, v)
    record!(g.rec, "graph_mst_edge"; from_node = ui, to_node = vi, weight = Float64(weight))
end

"""Record the discovered vertex path in traversal algorithms."""
function mark_graph_path!(g::TrackedGraph, path::AbstractVector{<:Integer})
    norm = [ _check_vertex(g, p) for p in path ]
    record!(g.rec, "graph_path"; path = norm)
end

end

