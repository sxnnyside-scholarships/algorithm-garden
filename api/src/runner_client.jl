module RunnerClient

using JSON3
using Random
using ..Config
using ..ApiI18n

export RunnerPool,
    start_pool,
    stop_pool!,
    pool_ready_count,
    check_runner_ready,
    execute_in_sandbox

function _build_runner_cmd(
    cfg::AppConfig;
    warm_one_shot::Bool = false,
    container_name::Union{Nothing, String} = nothing,
)::Cmd
    if cfg.runner_mode == "docker"
        args = String[
            "docker",
            "run",
            "--rm",
            "-i",
            "--network=none",
            "--read-only",
            "--cap-drop=ALL",
            "--security-opt=no-new-privileges",
            "--user",
            "nobody",
            "--pids-limit=$(cfg.runner_pids_limit)",
            "--memory=$(cfg.runner_memory_limit)",
            "--cpus=$(cfg.runner_cpu_limit)",
            "--tmpfs",
            "/tmp:rw,noexec,nosuid,nodev,size=32m",
        ]
        if container_name !== nothing
            push!(args, "--name", container_name)
        end
        push!(args, cfg.runner_image)
        if warm_one_shot
            push!(args, "--warm-one-shot")
        end
        return Cmd(args)
    end

    entry = joinpath(cfg.runner_dir, "scripts", "entrypoint.jl")
    sysimage = joinpath(cfg.runner_dir, "GardenRunner.so")
    exec_args = String[Base.julia_cmd().exec[1]]
    isfile(sysimage) && push!(exec_args, "--sysimage=$(sysimage)")
    append!(
        exec_args,
        String[
            "--project=$(cfg.runner_dir)",
            "--startup-file=no",
            entry,
        ],
    )
    warm_one_shot && push!(exec_args, "--warm-one-shot")
    base_cmd = Cmd(exec_args)
    clean_env = Dict{String, String}(
        "PATH" => get(ENV, "PATH", "/usr/local/bin:/usr/bin:/bin"),
        "HOME" => get(ENV, "HOME", "/tmp"),
        "JULIA_PKG_OFFLINE" => "true",
    )
    if haskey(ENV, "JULIA_DEPOT_PATH")
        clean_env["JULIA_DEPOT_PATH"] = ENV["JULIA_DEPOT_PATH"]
    end
    return setenv(base_cmd, clean_env)
end

include("runner_pool.jl")

function check_runner_ready(cfg::AppConfig)::Tuple{Bool, Int}
    t0 = time_ns()
    try
        if cfg.runner_mode == "subprocess"
            entry = joinpath(cfg.runner_dir, "scripts", "entrypoint.jl")
            ok = isfile(entry)
            ms = max(0, round(Int, (time_ns() - t0) / 1e6))
            return ok, ms
        end

        proc = run(
            pipeline(Cmd(["docker", "image", "inspect", cfg.runner_image]); stdout=devnull, stderr=devnull);
            wait=false,
        )
        timed_out = Ref(false)
        timer = Timer(1.5) do _
            if process_running(proc)
                timed_out[] = true
                kill(proc, Base.SIGKILL)
            end
        end
        wait(proc)
        close(timer)
        ms = max(0, round(Int, (time_ns() - t0) / 1e6))
        return (!timed_out[] && proc.exitcode == 0), ms
    catch
        ms = max(0, round(Int, (time_ns() - t0) / 1e6))
        return false, ms
    end
end

function _failed_runner_response(payload::Dict{String, Any}, category::String, msg::String, hint::String)::Dict{String, Any}
    return Dict{String, Any}(
        "status" => "failed",
        "garden" => get(payload, "garden", ""),
        "algorithm" => get(payload, "algorithm", ""),
        "initial_state" => nothing,
        "events" => Any[],
        "final_state" => nothing,
        "metrics" => nothing,
        "tests" => nothing,
        "error" => Dict{String, Any}(
            "category" => category,
            "message" => msg,
            "line" => nothing,
            "hint" => hint,
        ),
    )
end

function _await_runner_output(
    cfg::AppConfig,
    payload::Dict{String, Any},
    proc::Base.Process,
    out_pipe::Pipe,
    err_pipe::Pipe;
    warm_worker::Union{Nothing, WarmWorker} = nothing,
)::Dict{String, Any}
    timed_out = Ref(false)
    # Give cold invocations (especially cold Docker container startup) enough wall time while runner enforces RUNNER_TIMEOUT_MS
    grace_ms = if warm_worker !== nothing
        cfg.runner_timeout_ms + 1_500
    elseif cfg.runner_mode == "subprocess"
        max(cfg.runner_timeout_ms + 3_000, 8_000)
    else
        max(cfg.runner_timeout_ms + 5_000, 10_000)
    end
    timer = Timer(grace_ms / 1000.0) do _
        if process_running(proc)
            timed_out[] = true
            kill(proc, Base.SIGKILL)
        end
    end

    out_task = @async read(out_pipe, cfg.runner_max_stdout_bytes + 1)
    err_task = @async read(err_pipe, 16_384)
    wait(proc)
    close(timer)

    out_bytes = fetch(out_task)
    _ = fetch(err_task)
    warm_worker === nothing || _cleanup_worker!(warm_worker)

    loc = String(get(payload, "locale", "en"))
    if timed_out[]
        return _failed_runner_response(
            payload,
            "timeout",
            amsg(loc, "runner_timeout", "ms" => cfg.runner_timeout_ms),
            amsg(loc, "runner_timeout_hint"),
        )
    end

    if length(out_bytes) > cfg.runner_max_stdout_bytes
        return _failed_runner_response(
            payload,
            "resource_limit",
            amsg(loc, "runner_stdout"),
            amsg(loc, "runner_stdout_hint"),
        )
    end

    raw_out = strip(String(out_bytes))
    if isempty(raw_out) || proc.exitcode != 0
        error("Runner exited abnormally (code=$(proc.exitcode))")
    end

    return JSON3.read(raw_out, Dict{String, Any})
end

function execute_in_sandbox(
    cfg::AppConfig,
    payload::Dict{String, Any};
    pool::Union{Nothing, RunnerPool} = nothing,
)::Dict{String, Any}
    req_payload = copy(payload)
    req_payload["max_events"] = cfg.runner_max_events
    req_payload["timeout_ms"] = cfg.runner_timeout_ms

    if pool !== nothing
        warm = take_warm_worker!(pool)
        if warm !== nothing
            wrote_ok = try
                write(warm.in_pipe, JSON3.write(req_payload) * "\n")
                flush(warm.in_pipe)
                close(warm.in_pipe)
                true
            catch
                _cleanup_worker!(warm)
                false
            end
            if wrote_ok
                return _await_runner_output(
                    cfg,
                    payload,
                    warm.proc,
                    warm.out_pipe,
                    warm.err_pipe;
                    warm_worker=warm,
                )
            end
        end
    end

    cmd = _build_runner_cmd(cfg)
    in_pipe = Pipe()
    out_pipe = Pipe()
    err_pipe = Pipe()

    proc = run(pipeline(cmd; stdin=in_pipe, stdout=out_pipe, stderr=err_pipe); wait=false)
    close(in_pipe.out)
    close(out_pipe.in)
    close(err_pipe.in)

    write(in_pipe, JSON3.write(req_payload))
    close(in_pipe)

    return _await_runner_output(cfg, payload, proc, out_pipe, err_pipe)
end

end
