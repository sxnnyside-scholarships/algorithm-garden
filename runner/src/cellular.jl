module CellularDomain

using ..RunnerI18n
using ..Trace

export CellularGrid,
    grid_dims,
    generations_count,
    wrap_edges,
    rule_born,
    rule_survive,
    current_cells,
    live_neighbors,
    record_generation!,
    matrix_to_rows

"""
    CellularGrid

Discrete 2D cellular automaton grid with configurable birth/survival rules and trace recording.
"""
mutable struct CellularGrid
    rows::Int
    cols::Int
    cells::Matrix{Int}
    born::Vector{Int}
    survive::Vector{Int}
    generations::Int
    wrap::Bool
    rec::TraceRecorder
end

function CellularGrid(
    rows::Integer,
    cols::Integer,
    cells::AbstractMatrix{<:Integer},
    born::AbstractVector{<:Integer},
    survive::AbstractVector{<:Integer},
    generations::Integer,
    wrap::Bool,
    rec::TraceRecorder,
)
    r = Int(rows)
    c = Int(cols)
    (2 <= r <= 48 && 2 <= c <= 48) || throw(ContractError(rmsg("cellular_dims")))
    size(cells) == (r, c) || throw(ContractError(rmsg("cellular_matrix_size")))
    mat = Matrix{Int}(cells)
    return CellularGrid(r, c, mat, [Int(x) for x in born], [Int(x) for x in survive], Int(generations), wrap, rec)
end

"""Return grid dimensions `(rows, cols)`."""
grid_dims(g::CellularGrid)::Tuple{Int, Int} = (g.rows, g.cols)

"""Return target number of generations to simulate."""
generations_count(g::CellularGrid)::Int = g.generations

"""Return whether grid edges wrap toroidally."""
wrap_edges(g::CellularGrid)::Bool = g.wrap

"""Return neighbor counts that cause a dead cell (`0`) to be born (`1`)."""
rule_born(g::CellularGrid)::Vector{Int} = copy(g.born)

"""Return neighbor counts that keep a live cell (`1`) alive (`1`)."""
rule_survive(g::CellularGrid)::Vector{Int} = copy(g.survive)

"""Return a mutable copy of the current cell state matrix."""
current_cells(g::CellularGrid)::Matrix{Int} = copy(g.cells)

"""Convert an integer matrix to JSON-friendly vector of row vectors."""
function matrix_to_rows(mat::AbstractMatrix{<:Integer})::Vector{Vector{Int}}
    rows, cols = size(mat)
    out = Vector{Vector{Int}}(undef, rows)
    for r in 1:rows
        out[r] = [Int(mat[r, c]) for c in 1:cols]
    end
    return out
end

"""
    live_neighbors(g::CellularGrid, r::Integer, c::Integer; state::Integer = 1)::Int

Count Moore (8-neighborhood) neighbors in `state` around cell `(r, c)`.
"""
function live_neighbors(g::CellularGrid, r::Integer, c::Integer; state::Integer = 1)::Int
    ri = Int(r)
    ci = Int(c)
    target = Int(state)
    (1 <= ri <= g.rows && 1 <= ci <= g.cols) ||
        throw(ContractError(rmsg("cell_oob", "cell" => "($ri, $ci)")))

    count = 0
    for dr in -1:1
        for dc in -1:1
            (dr == 0 && dc == 0) && continue
            nr = ri + dr
            nc = ci + dc
            if g.wrap
                nr = mod1(nr, g.rows)
                nc = mod1(nc, g.cols)
                g.cells[nr, nc] == target && (count += 1)
            elseif 1 <= nr <= g.rows && 1 <= nc <= g.cols
                g.cells[nr, nc] == target && (count += 1)
            end
        end
    end
    return count
end

"""
    record_generation!(g::CellularGrid, next_cells::AbstractMatrix{<:Integer}, gen::Integer)

Commit `next_cells` as generation `gen`, update metrics, and emit a `generation` event.
"""
function record_generation!(g::CellularGrid, next_cells::AbstractMatrix{<:Integer}, gen::Integer)
    size(next_cells) == (g.rows, g.cols) || throw(ContractError(rmsg("cellular_matrix_size")))
    next_mat = Matrix{Int}(next_cells)
    alive_count = 0
    born_count = 0
    died_count = 0

    for r in 1:g.rows
        for c in 1:g.cols
            prev = g.cells[r, c]
            cur = next_mat[r, c]
            cur == 1 && (alive_count += 1)
            prev == 0 && cur == 1 && (born_count += 1)
            prev == 1 && cur == 0 && (died_count += 1)
        end
    end

    g.cells = next_mat
    increment_metric!(g.rec, "generations_simulated", 1)
    record!(
        g.rec,
        "generation";
        gen = Int(gen),
        cells = matrix_to_rows(next_mat),
        alive_count = alive_count,
        born_count = born_count,
        died_count = died_count,
    )
    return next_mat
end

end

