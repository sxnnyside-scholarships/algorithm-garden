using Test
using HTTP
using JSON3
using Oxygen
using GardenApi

function make_test_ctx(;
    exec_runner_fn::Function = GardenApi.RunnerClient.execute_in_sandbox,
    readiness_runner_fn::Function = _ -> (true, 1),
)
    cfg = load_config(;
        overrides=Dict(
            "APP_ENV" => "test",
            "HOST" => "127.0.0.1",
            "DB_DRIVER" => "sqlite",
            "SQLITE_PATH" => ":memory:",
            "RUNNER_MODE" => "subprocess",
        ),
    )
    return build_app!(
        cfg;
        exec_runner_fn=exec_runner_fn,
        readiness_runner_fn=readiness_runner_fn,
    )
end

function api_req(
    method::String,
    target::String;
    body = nothing,
    token::Union{Nothing, String} = nothing,
    headers::Vector{Pair{String, String}} = Pair{String, String}[],
)
    req_headers = Pair{String, String}[h for h in headers]
    payload = UInt8[]
    if body !== nothing
        push!(req_headers, "Content-Type" => "application/json")
        payload = Vector{UInt8}(codeunits(JSON3.write(body)))
    end
    if token !== nothing
        push!(req_headers, "Authorization" => "Bearer $token")
    end
    req = HTTP.Request(method, target, req_headers, payload)
    resp = Oxygen.internalrequest(req)
    parsed = isempty(resp.body) ? nothing : JSON3.read(String(resp.body), Dict{String, Any})
    return resp.status, parsed, resp
end

@testset "GardenApi" begin
    include("test_health.jl")
    include("test_auth.jl")
    include("test_catalog.jl")
    include("test_experiments.jl")
    include("test_executions.jl")
    include("test_phase4_gardens.jl")
    include("test_phase5_hardening.jl")
    include("test_phase6_gardens.jl")
    include("test_catalog_algorithms.jl")
    include("test_api_docs_sync.jl")
end

