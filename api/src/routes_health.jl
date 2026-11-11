module HealthRoutes

using HTTP
using ..Database
using ..ApiErrors
using ..RunnerClient

export register_health_routes!

function register_health_routes!(register_fn, ctx; serve_spa_index_fn = nothing)
    register_fn("GET", "/", function (req::HTTP.Request)
        if serve_spa_index_fn !== nothing && !isempty(ctx.cfg.static_dir) && isdir(ctx.cfg.static_dir)
            return serve_spa_index_fn(req)
        end
        return json_ok(Dict("service" => "algorithm-garden-api", "version" => "0.1.0"))
    end)

    # Liveness probe: must stay fast and free of dependency checks.
    register_fn("GET", "/health", function (_req::HTTP.Request)
        return json_response(200, Dict("status" => "ok"))
    end)

    # Readiness probe: verifies hard dependencies with bounded timeouts.
    register_fn("GET", "/health/ready", function (_req::HTTP.Request)
        db_ok, db_ms = ping_db(ctx.db)
        runner_ok, runner_ms = ctx.readiness_runner_fn(ctx.cfg)

        checks = Dict{String, Any}(
            "database" => Dict{String, Any}("ok" => db_ok, "latency_ms" => db_ms),
            "runner" => Dict{String, Any}("ok" => runner_ok, "latency_ms" => runner_ms),
        )

        all_ok = db_ok && runner_ok
        status_code = all_ok ? 200 : 503
        status_label = all_ok ? "ready" : "not_ready"
        return json_response(status_code, Dict("status" => status_label, "checks" => checks))
    end)
end

end

