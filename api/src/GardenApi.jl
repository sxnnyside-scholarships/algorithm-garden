module GardenApi

using HTTP
import Oxygen

include("config.jl")
include("i18n.jl")
include("errors.jl")
include("security.jl")
include("catalog_seed.jl")
include("db.jl")
include("runner_client.jl")
include("routes_health.jl")
include("routes_auth.jl")
include("routes_catalog.jl")
include("routes_executions.jl")
include("routes_experiments.jl")

using .Config
using .ApiI18n
using .ApiErrors
using .Security
using .Database
using .RunnerClient
using .HealthRoutes
using .AuthRoutes
using .CatalogRoutes
using .ExecutionRoutes
using .ExperimentRoutes

export AppContext,
    AppConfig,
    RunnerPool,
    load_config,
    open_store,
    close_store!,
    migrate_and_seed!,
    build_app!,
    start_server,
    stop_server

"""
    AppContext{F1, F2}

Runtime dependency container for the `GardenApi` HTTP router.
"""
struct AppContext{F1, F2}
    cfg::AppConfig
    db::DbStore
    limiter::RateLimiter
    exec_runner_fn::F1
    readiness_runner_fn::F2
    registered_routes::Vector{Tuple{String, String}}
    runner_pool::Union{Nothing, RunnerPool}
end

const ACTIVE_POOL = Ref{Union{Nothing, RunnerPool}}(nothing)

function _cors_headers(cfg::AppConfig)::Vector{Pair{String, String}}
    return Pair{String, String}[
        "Access-Control-Allow-Origin" => cfg.cors_origin,
        "Access-Control-Allow-Headers" => "Authorization, Content-Type, Accept-Language",
        "Access-Control-Allow-Methods" => "GET, POST, PATCH, DELETE, OPTIONS",
        "Vary" => "Origin",
    ]
end

const STATIC_CSP = "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com data:; img-src 'self' data:; connect-src 'self'; frame-ancestors 'none'; base-uri 'self';"

const STATIC_MIME_MAP = Dict{String, String}(
    ".html" => "text/html; charset=utf-8",
    ".js" => "application/javascript; charset=utf-8",
    ".mjs" => "application/javascript; charset=utf-8",
    ".css" => "text/css; charset=utf-8",
    ".json" => "application/json; charset=utf-8",
    ".svg" => "image/svg+xml; charset=utf-8",
    ".png" => "image/png",
    ".jpg" => "image/jpeg",
    ".jpeg" => "image/jpeg",
    ".webp" => "image/webp",
    ".ico" => "image/x-icon",
    ".woff" => "font/woff",
    ".woff2" => "font/woff2",
    ".txt" => "text/plain; charset=utf-8",
)

function _serve_static_spa(cfg::AppConfig, req::HTTP.Request)::HTTP.Response
    raw_target = String(split(req.target, '?'; limit=2)[1])
    if startswith(raw_target, "/api/") || raw_target == "/api" || startswith(raw_target, "/health")
        return json_error(404, "not_found", amsg("not_found_route", "target" => raw_target))
    end

    root_dir = abspath(cfg.static_dir)
    root_prefix = endswith(root_dir, Base.Filesystem.path_separator) ? root_dir : root_dir * Base.Filesystem.path_separator
    rel = lstrip(HTTP.unescapeuri(raw_target), '/')
    rel_parts = [p for p in split(rel, '/') if !isempty(p) && p != "."]
    if any(p -> p == ".." || occursin('\\', p) || occursin('\0', p), rel_parts)
        return json_error(400, "validation_failed", amsg("validation_failed"))
    end

    candidate = isempty(rel_parts) ? joinpath(root_dir, "index.html") : abspath(joinpath(root_dir, rel_parts...))
    inside_root = candidate == root_dir || startswith(candidate, root_prefix)
    is_asset = inside_root && isfile(candidate)
    if !is_asset
        if startswith(raw_target, "/assets/")
            return json_error(404, "not_found", amsg("not_found_route", "target" => raw_target))
        end
        candidate = joinpath(root_dir, "index.html")
        isfile(candidate) || return json_error(404, "not_found", amsg("not_found_route", "target" => raw_target))
    end

    ext = lowercase(splitext(candidate)[2])
    ctype = get(STATIC_MIME_MAP, ext, "application/octet-stream")
    cache_ctrl = startswith(raw_target, "/assets/") && is_asset ? "public, max-age=31536000, immutable" : "no-cache"
    headers = Pair{String, String}[
        "Content-Type" => ctype,
        "Cache-Control" => cache_ctrl,
        "Content-Security-Policy" => STATIC_CSP,
    ]
    return HTTP.Response(200, headers, read(candidate))
end

function _apply_security_headers!(resp::HTTP.Response, target::AbstractString)::HTTP.Response
    HTTP.setheader(resp, "X-Content-Type-Options" => "nosniff")
    HTTP.setheader(resp, "X-Frame-Options" => "DENY")
    HTTP.setheader(resp, "Referrer-Policy" => "strict-origin-when-cross-origin")
    if startswith(target, "/api/") || startswith(target, "/health")
        HTTP.setheader(resp, "Cache-Control" => "no-store")
    end
    return resp
end

function _apply_cors!(resp::HTTP.Response, cfg::AppConfig, target::AbstractString = "")::HTTP.Response
    for (k, v) in _cors_headers(cfg)
        HTTP.setheader(resp, k => v)
    end
    _apply_security_headers!(resp, target)
    return resp
end

function _invoke_wrapped(ctx::AppContext, handler, req::HTTP.Request, args...)
    loc = request_locale(req)
    return with_api_locale(loc) do
        try
            resp = handler(req, args...)
            return _apply_cors!(resp, ctx.cfg, req.target)
        catch err
            if err isa ApiException
                hdrs = Pair{String, String}[]
                if err.code == "rate_limited" && err.details isa AbstractDict && haskey(err.details, "retry_after")
                    push!(hdrs, "Retry-After" => string(err.details["retry_after"]))
                end
                resp = json_error(err.status, err.code, err.message; details=err.details, headers=hdrs)
                return _apply_cors!(resp, ctx.cfg, req.target)
            else
                @error "Unhandled API error" exception = (err, catch_backtrace())
                resp = json_error(500, "internal_error", amsg("internal_error"))
                return _apply_cors!(resp, ctx.cfg, req.target)
            end
        end
    end
end

function _wrap_handler(ctx::AppContext, path::AbstractString, handler)
    if occursin("{slug}", path)
        return function (req::HTTP.Request, slug::String)
            return _invoke_wrapped(ctx, handler, req, slug)
        end
    elseif occursin("{id}", path)
        return function (req::HTTP.Request, id::String)
            return _invoke_wrapped(ctx, handler, req, id)
        end
    elseif occursin('{', path)
        error("Unsupported path parameter in route '$path'; add a wrapper branch in _wrap_handler")
    else
        return function (req::HTTP.Request)
            return _invoke_wrapped(ctx, handler, req)
        end
    end
end

"""
    build_app!(cfg::AppConfig; db=open_store(cfg), ...) -> AppContext

Run migrations, seed catalog data, initialize the optional warm `RunnerPool`, and register routes.
"""
function build_app!(
    cfg::AppConfig;
    db::DbStore = open_store(cfg),
    exec_runner_fn = nothing,
    readiness_runner_fn = check_runner_ready,
    reset_router::Bool = true,
)::AppContext
    reset_router && Oxygen.resetstate()
    migrate_and_seed!(db)

    pool = exec_runner_fn === nothing && cfg.runner_pool_size > 0 ? start_pool(cfg) : nothing
    effective_exec = if exec_runner_fn === nothing
        (c, p) -> execute_in_sandbox(c, p; pool=pool)
    else
        exec_runner_fn
    end

    ctx = AppContext(
        cfg,
        db,
        RateLimiter(),
        effective_exec,
        readiness_runner_fn,
        Tuple{String, String}[],
        pool,
    )

    options_paths = Set{String}()

    function register_route!(method::AbstractString, path::AbstractString, handler)
        m = String(method)
        p = String(path)
        push!(ctx.registered_routes, (m, p))
        Oxygen.route([m], p, _wrap_handler(ctx, p, handler))
        if m == "GET" && p in ("/", "/health", "/health/ready")
            Oxygen.route(["HEAD"], p, _wrap_handler(ctx, p, function (req::HTTP.Request, args...)
                res = handler(req, args...)
                return HTTP.Response(res.status, copy(res.headers), UInt8[])
            end))
        end
        if !(p in options_paths)
            push!(options_paths, p)
            opt_wrapped = _wrap_handler(ctx, p, function (_req::HTTP.Request, _args...)
                return HTTP.Response(204, "")
            end)
            Oxygen.route(["OPTIONS"], p, opt_wrapped)
        end
    end

    Oxygen.route(["OPTIONS"], "/**", function (_req::HTTP.Request)
        return _apply_security_headers!(HTTP.Response(204, _cors_headers(cfg), ""), "/")
    end)

    spa_index_fn = if !isempty(cfg.static_dir) && isdir(cfg.static_dir)
        (req::HTTP.Request) -> _serve_static_spa(cfg, req)
    else
        nothing
    end

    register_health_routes!(register_route!, ctx; serve_spa_index_fn=spa_index_fn)
    register_auth_routes!(register_route!, ctx)
    register_catalog_routes!(register_route!, ctx)
    register_execution_routes!(register_route!, ctx)
    register_experiment_routes!(register_route!, ctx)

    if spa_index_fn !== nothing
        Oxygen.route(["GET", "HEAD"], "/**", function (req::HTTP.Request)
            return with_api_locale(request_locale(req)) do
                res = _serve_static_spa(cfg, req)
                if uppercase(req.method) == "HEAD"
                    res = HTTP.Response(res.status, copy(res.headers), UInt8[])
                end
                return _apply_security_headers!(res, req.target)
            end
        end)
    end

    return ctx
end

"""
    start_server(cfg::AppConfig = load_config(); async::Bool = false) -> AppContext

Build the application context and start the HTTP server.
"""
function start_server(cfg::AppConfig = load_config(); async::Bool = false)
    ctx = build_app!(cfg)
    ACTIVE_POOL[] = ctx.runner_pool
    try
        Oxygen.serve(; host=cfg.host, port=cfg.port, async=async, show_banner=false, show_errors=false)
    finally
        async || stop_pool!(ctx.runner_pool)
    end
    return ctx
end

function stop_server()
    stop_pool!(ACTIVE_POOL[])
    ACTIVE_POOL[] = nothing
    Oxygen.terminate()
end

end
