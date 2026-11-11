module Trace

using ..RunnerI18n

export RunnerLimitError, ContractError, TraceRecorder, record!, increment_metric!, snapshot_metrics

struct RunnerLimitError <: Exception
    category::String
    message::String
end

struct ContractError <: Exception
    message::String
end

mutable struct TraceRecorder
    events::Vector{Dict{String, Any}}
    seq::Int
    max_events::Int
    deadline_ns::UInt64
    record_events::Bool
    metrics::Dict{String, Int}
end

function TraceRecorder(;
    max_events::Integer = 50_000,
    timeout_ms::Integer = 5_000,
    record_events::Bool = true,
)
    deadline = time_ns() + UInt64(max(Int(timeout_ms), 1)) * UInt64(1_000_000)
    metrics = Dict{String, Int}(
        "comparisons" => 0,
        "swaps" => 0,
        "reads" => 0,
        "writes" => 0,
        "nodes_visited" => 0,
        "frontier_enqueued" => 0,
        "edges_relaxed" => 0,
        "generations_simulated" => 0,
        "pixels_computed" => 0,
        "segments_drawn" => 0,
        "evaluations" => 0,
        "mutations" => 0,
        "crossovers" => 0,
    )
    return TraceRecorder(Dict{String, Any}[], 0, Int(max_events), deadline, record_events, metrics)
end

@inline function check_budget!(rec::TraceRecorder)
    if time_ns() > rec.deadline_ns
        throw(RunnerLimitError("timeout", rmsg("timeout_msg")))
    end
    if rec.seq >= rec.max_events
        throw(
            RunnerLimitError(
                "resource_limit",
                rmsg("max_events_count", "max" => rec.max_events),
            ),
        )
    end
end

"""
    increment_metric!(rec::TraceRecorder, key::AbstractString, delta::Integer = 1)

Accumulate an execution counter on `rec`.
"""
function increment_metric!(rec::TraceRecorder, key::AbstractString, delta::Integer = 1)
    k = String(key)
    rec.metrics[k] = get(rec.metrics, k, 0) + Int(delta)
end

"""
    record!(rec::TraceRecorder, event_type::AbstractString; fields...)

Verify execution time/event budgets and append a normalized trace event.
"""
function record!(rec::TraceRecorder, event_type::AbstractString; fields...)
    check_budget!(rec)
    rec.seq += 1
    if !rec.record_events
        return
    end
    ev = Dict{String, Any}("seq" => rec.seq, "type" => String(event_type))
    for (k, v) in fields
        ev[String(k)] = v
    end
    push!(rec.events, ev)
end

function snapshot_metrics(rec::TraceRecorder, elapsed_ms::Float64)::Dict{String, Any}
    out = Dict{String, Any}()
    for (k, v) in rec.metrics
        out[k] = v
    end
    out["total_events"] = rec.seq
    out["elapsed_ms"] = round(elapsed_ms; digits=3)
    return out
end

end

