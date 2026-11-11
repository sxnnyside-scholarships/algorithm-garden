module Config

using Random

export AppConfig, load_config

struct AppConfig
    host::String
    port::Int
    app_env::String
    db_driver::String
    sqlite_path::String
    database_url::String
    auth_token_secret::Vector{UInt8}
    token_ttl_seconds::Int
    pbkdf2_iterations::Int
    runner_mode::String
    runner_image::String
    runner_dir::String
    runner_timeout_ms::Int
    runner_memory_limit::String
    runner_cpu_limit::String
    runner_pids_limit::Int
    runner_max_events::Int
    runner_max_stdout_bytes::Int
    runner_pool_size::Int
    cors_origin::String
    static_dir::String
end

function _env_int(key::AbstractString, default::Integer)::Int
    k = String(key)
    raw = get(ENV, k, "")
    isempty(strip(raw)) && return Int(default)
    val = tryparse(Int, strip(raw))
    val === nothing && error("Invalid integer environment variable $k='$raw'")
    return val
end

function load_config(;
    repo_root::AbstractString = dirname(dirname(@__DIR__)),
    overrides::AbstractDict = Dict{String, String}(),
)::AppConfig
    env_get(k, d) = haskey(overrides, k) ? string(overrides[k]) : get(ENV, k, d)
    env_int(k, d) = haskey(overrides, k) ? parse(Int, string(overrides[k])) : _env_int(k, d)

    app_env = lowercase(strip(env_get("APP_ENV", "development")))
    host = strip(env_get("HOST", "127.0.0.1"))
    port = env_int("PORT", 8080)
    db_driver = lowercase(strip(env_get("DB_DRIVER", "sqlite")))
    db_driver in ("sqlite", "postgres") || error("Unsupported DB_DRIVER='$db_driver'")

    sqlite_path = env_get("SQLITE_PATH", joinpath(repo_root, "data", "algorithm_garden.sqlite"))
    database_url = env_get("DATABASE_URL", "")

    secret_raw = env_get("AUTH_TOKEN_SECRET", "")
    secret_bytes = if isempty(secret_raw)
        if app_env == "production"
            error("AUTH_TOKEN_SECRET must be set (>= 32 bytes) in production")
        end
        # Ephemeral per-process CSPRNG secret for non-production; never a static fallback string.
        rand(RandomDevice(), UInt8, 32)
    else
        length(codeunits(secret_raw)) >= 32 ||
            error("AUTH_TOKEN_SECRET must be at least 32 bytes")
        Vector{UInt8}(codeunits(secret_raw))
    end

    token_ttl_seconds = max(env_int("TOKEN_TTL_SECONDS", 86_400), 60)
    default_iters = app_env == "test" ? 10_000 : 120_000
    pbkdf2_iterations = max(env_int("PBKDF2_ITERATIONS", default_iters), 10_000)

    runner_mode = lowercase(strip(env_get("RUNNER_MODE", "docker")))
    runner_mode in ("docker", "subprocess") || error("Unsupported RUNNER_MODE='$runner_mode'")

    runner_image = env_get("RUNNER_IMAGE", "algorithm-garden-runner:0.1.0")
    runner_dir = env_get("RUNNER_DIR", joinpath(repo_root, "runner"))
    runner_timeout_ms = clamp(env_int("RUNNER_TIMEOUT_MS", 5_000), 250, 30_000)
    runner_memory_limit = env_get("RUNNER_MEMORY_LIMIT", "256m")
    runner_cpu_limit = env_get("RUNNER_CPU_LIMIT", "1.0")
    runner_pids_limit = clamp(env_int("RUNNER_PIDS_LIMIT", 64), 16, 256)
    runner_max_events = clamp(env_int("RUNNER_MAX_EVENTS", 50_000), 100, 200_000)
    runner_max_stdout_bytes = clamp(env_int("RUNNER_MAX_STDOUT_BYTES", 2_097_152), 65_536, 16_777_216)
    default_pool = app_env == "test" ? 0 : 2
    runner_pool_size = clamp(env_int("RUNNER_POOL_SIZE", default_pool), 0, 16)
    cors_origin = env_get("CORS_ORIGIN", "http://127.0.0.1:5173")
    static_dir = strip(env_get("STATIC_DIR", ""))

    return AppConfig(
        host,
        port,
        app_env,
        db_driver,
        sqlite_path,
        database_url,
        secret_bytes,
        token_ttl_seconds,
        pbkdf2_iterations,
        runner_mode,
        runner_image,
        runner_dir,
        runner_timeout_ms,
        runner_memory_limit,
        runner_cpu_limit,
        runner_pids_limit,
        runner_max_events,
        runner_max_stdout_bytes,
        runner_pool_size,
        cors_origin,
        static_dir,
    )
end

end

