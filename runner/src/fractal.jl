module FractalDomain

using ..RunnerI18n
using ..Trace

export FractalPlane,
    plane_size,
    complex_bounds,
    max_iterations,
    julia_seed,
    recursion_depth,
    pixel_complex,
    emit_row!,
    emit_segments!

"""
    FractalPlane

Complex-plane and recursive geometry canvas instrumented for scanline and vector fractals.
"""
mutable struct FractalPlane
    width::Int
    height::Int
    x_min::Float64
    x_max::Float64
    y_min::Float64
    y_max::Float64
    max_iter::Int
    julia_re::Float64
    julia_im::Float64
    depth::Int
    rows_buffer::Vector{Vector{Int}}
    segments_buffer::Vector{Vector{Float64}}
    rec::TraceRecorder
end

function FractalPlane(
    width::Integer,
    height::Integer,
    x_min::Real,
    x_max::Real,
    y_min::Real,
    y_max::Real,
    max_iter::Integer,
    julia_re::Real,
    julia_im::Real,
    depth::Integer,
    rec::TraceRecorder,
)
    w = clamp(Int(width), 16, 120)
    h = clamp(Int(height), 12, 90)
    mi = clamp(Int(max_iter), 8, 250)
    d = clamp(Int(depth), 1, 9)
    x0 = Float64(x_min)
    x1 = Float64(x_max)
    y0 = Float64(y_min)
    y1 = Float64(y_max)
    (x1 > x0 && y1 > y0) || throw(ContractError(rmsg("fractal_bounds")))
    rows = [zeros(Int, w) for _ in 1:h]
    return FractalPlane(w, h, x0, x1, y0, y1, mi, Float64(julia_re), Float64(julia_im), d, rows, Vector{Float64}[], rec)
end

"""Return canvas raster resolution `(width, height)`."""
plane_size(p::FractalPlane)::Tuple{Int, Int} = (p.width, p.height)

"""Return complex-plane viewport `(x_min, x_max, y_min, y_max)`."""
complex_bounds(p::FractalPlane)::Tuple{Float64, Float64, Float64, Float64} =
    (p.x_min, p.x_max, p.y_min, p.y_max)

"""Return configured maximum escape-time iterations."""
max_iterations(p::FractalPlane)::Int = p.max_iter

"""Return the complex seed `ComplexF64(julia_re, julia_im)` for Julia sets."""
julia_seed(p::FractalPlane)::ComplexF64 = ComplexF64(p.julia_re, p.julia_im)

"""Return configured recursion depth for vector fractals."""
recursion_depth(p::FractalPlane)::Int = p.depth

"""Map 1-based raster coordinate `(row, col)` to its complex coordinate `x + y*im`."""
function pixel_complex(p::FractalPlane, row::Integer, col::Integer)::ComplexF64
    r = Int(row)
    c = Int(col)
    (1 <= r <= p.height && 1 <= c <= p.width) ||
        throw(ContractError(rmsg("cell_oob", "cell" => "($r, $c)")))
    u = p.width == 1 ? 0.5 : (c - 1) / (p.width - 1)
    v = p.height == 1 ? 0.5 : (r - 1) / (p.height - 1)
    x = p.x_min + u * (p.x_max - p.x_min)
    y = p.y_max - v * (p.y_max - p.y_min)
    return ComplexF64(x, y)
end

"""
    emit_row!(p::FractalPlane, row::Integer, iters::AbstractVector{<:Integer})

Emit iteration counts for raster scanline `row` and update computed pixel metrics.
"""
function emit_row!(p::FractalPlane, row::Integer, iters::AbstractVector{<:Integer})
    r = Int(row)
    (1 <= r <= p.height) || throw(ContractError(rmsg("fractal_row_oob", "row" => r, "height" => p.height)))
    length(iters) == p.width ||
        throw(ContractError(rmsg("fractal_row_width", "width" => p.width, "got" => length(iters))))
    vals = [clamp(Int(x), 0, p.max_iter) for x in iters]
    p.rows_buffer[r] = vals
    increment_metric!(p.rec, "pixels_computed", p.width)
    record!(p.rec, "fractal_row"; row = r, values = vals, max_iter = p.max_iter)
end

"""
    emit_segments!(p::FractalPlane, depth_level::Integer, segments::AbstractVector)

Emit a batch of line segments `[x1, y1, x2, y2]` in normalized `[0, 100]` coordinates for `depth_level`.
"""
function emit_segments!(p::FractalPlane, depth_level::Integer, segments::AbstractVector)
    d = Int(depth_level)
    out = Vector{Vector{Float64}}(undef, length(segments))
    for (i, seg) in enumerate(segments)
        length(seg) >= 4 || throw(ContractError(rmsg("fractal_segment_shape")))
        vec = Float64[
            round(Float64(seg[1]); digits = 2),
            round(Float64(seg[2]); digits = 2),
            round(Float64(seg[3]); digits = 2),
            round(Float64(seg[4]); digits = 2),
            Float64(d),
        ]
        out[i] = vec
        push!(p.segments_buffer, vec)
    end
    increment_metric!(p.rec, "segments_drawn", length(out))
    record!(p.rec, "fractal_segments"; depth = d, segments = out)
end

end

