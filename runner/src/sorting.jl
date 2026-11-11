module SortingDomain

using ..RunnerI18n
using ..Trace

export TrackedVector, swap!, compare, is_less, is_greater, mark_pivot!, mark_range!, mark_sorted!

"""
    TrackedVector{T <: Integer} <: AbstractVector{T}

Instrumented 1-indexed vector that records reads, writes, comparisons, swaps, and semantic
markers while executing student sorting implementations.
"""
struct TrackedVector{T <: Integer} <: AbstractVector{T}
    data::Vector{T}
    recorder::TraceRecorder
end

function TrackedVector(values::AbstractVector{T}, recorder::TraceRecorder) where {T <: Integer}
    return TrackedVector{T}(collect(T, values), recorder)
end

Base.size(v::TrackedVector) = size(v.data)
Base.IndexStyle(::Type{<:TrackedVector}) = IndexLinear()

function Base.getindex(v::TrackedVector, i::Integer)
    idx = Int(i)
    checkbounds(v.data, idx)
    increment_metric!(v.recorder, "reads")
    record!(v.recorder, "read"; index=idx)
    return v.data[idx]
end

function Base.setindex!(v::TrackedVector{T}, val, i::Integer) where {T <: Integer}
    idx = Int(i)
    checkbounds(v.data, idx)
    converted = convert(T, val)
    v.data[idx] = converted
    increment_metric!(v.recorder, "writes")
    record!(v.recorder, "write"; index=idx, value=Int(converted))
    return converted
end

"""
    compare(v::TrackedVector, i::Integer, j::Integer) -> Int

Compare elements at `i` and `j`, returning `-1`, `0`, or `1` while emitting a `compare` event.
"""
function compare(v::TrackedVector, i::Integer, j::Integer)::Int
    idx_i = Int(i)
    idx_j = Int(j)
    checkbounds(v.data, idx_i)
    checkbounds(v.data, idx_j)
    increment_metric!(v.recorder, "reads", 2)
    increment_metric!(v.recorder, "comparisons")
    record!(v.recorder, "compare"; indices=[idx_i, idx_j])
    a = v.data[idx_i]
    b = v.data[idx_j]
    return a < b ? -1 : (a > b ? 1 : 0)
end

"""
    is_less(v::TrackedVector, i::Integer, j::Integer) -> Bool

Return `true` if `v[i] < v[j]`, recording a comparison event.
"""
is_less(v::TrackedVector, i::Integer, j::Integer)::Bool = compare(v, i, j) < 0

"""
    is_greater(v::TrackedVector, i::Integer, j::Integer) -> Bool

Return `true` if `v[i] > v[j]`, recording a comparison event.
"""
is_greater(v::TrackedVector, i::Integer, j::Integer)::Bool = compare(v, i, j) > 0

"""
    swap!(v::TrackedVector, i::Integer, j::Integer) -> TrackedVector

Swap elements at positions `i` and `j` in place and emit a `swap` trace event.
"""
function swap!(v::TrackedVector, i::Integer, j::Integer)
    idx_i = Int(i)
    idx_j = Int(j)
    checkbounds(v.data, idx_i)
    checkbounds(v.data, idx_j)
    increment_metric!(v.recorder, "reads", 2)
    increment_metric!(v.recorder, "writes", 2)
    increment_metric!(v.recorder, "swaps")
    v.data[idx_i], v.data[idx_j] = v.data[idx_j], v.data[idx_i]
    record!(v.recorder, "swap"; indices=[idx_i, idx_j], values=[Int(v.data[idx_i]), Int(v.data[idx_j])])
    return v
end

"""
    mark_pivot!(v::TrackedVector, i::Integer)

Emit a `mark_pivot` visual hint at index `i`.
"""
function mark_pivot!(v::TrackedVector, i::Integer)
    idx = Int(i)
    checkbounds(v.data, idx)
    record!(v.recorder, "mark_pivot"; index=idx)
    return nothing
end

"""
    mark_range!(v::TrackedVector, lo::Integer, hi::Integer)

Emit a `mark_range` visual hint highlighting slice `lo:hi`.
"""
function mark_range!(v::TrackedVector, lo::Integer, hi::Integer)
    lo_i = Int(lo)
    hi_i = Int(hi)
    checkbounds(v.data, lo_i)
    checkbounds(v.data, hi_i)
    if lo_i > hi_i
        throw(ArgumentError(rmsg("invalid_range", "lo" => lo_i, "hi" => hi_i)))
    end
    record!(v.recorder, "mark_range"; range=[lo_i, hi_i])
    return nothing
end

"""
    mark_sorted!(v::TrackedVector, i::Integer)

Emit a `mark_sorted` visual hint indicating index `i` is in its final position.
"""
function mark_sorted!(v::TrackedVector, i::Integer)
    idx = Int(i)
    checkbounds(v.data, idx)
    record!(v.recorder, "mark_sorted"; index=idx)
    return nothing
end

end
