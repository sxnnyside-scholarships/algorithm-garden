mutable struct WarmWorker
    id::String
    container_name::Union{Nothing, String}
    proc::Base.Process
    in_pipe::Pipe
    out_pipe::Pipe
    err_pipe::Pipe
    docker_mode::Bool
end

mutable struct RunnerPool
    cfg::AppConfig
    target_size::Int
    slots::Channel{WarmWorker}
    closed::Threads.Atomic{Bool}
    lock::ReentrantLock
    pending_refills::Int
end

function _safe_close(io)
    try
        isopen(io) && close(io)
    catch
    end
end

function _cleanup_worker!(w::WarmWorker)
    _safe_close(w.in_pipe)
    _safe_close(w.out_pipe)
    _safe_close(w.err_pipe)
    try
        if process_running(w.proc)
            kill(w.proc, Base.SIGKILL)
        end
        wait(w.proc)
    catch
    end
    if w.docker_mode && w.container_name !== nothing
        try
            run(pipeline(Cmd(["docker", "rm", "-f", w.container_name]); stdout=devnull, stderr=devnull); wait=false)
        catch
        end
    end
end

function _spawn_warm_worker(cfg::AppConfig)::Union{Nothing, WarmWorker}
    id = "ag-warm-" * bytes2hex(rand(RandomDevice(), UInt8, 6))
    docker_mode = cfg.runner_mode == "docker"
    cname = docker_mode ? id : nothing
    cmd = _build_runner_cmd(cfg; warm_one_shot=true, container_name=cname)

    in_pipe = Pipe()
    out_pipe = Pipe()
    err_pipe = Pipe()

    proc = try
        run(pipeline(cmd; stdin=in_pipe, stdout=out_pipe, stderr=err_pipe); wait=false)
    catch
        _safe_close(in_pipe)
        _safe_close(out_pipe)
        _safe_close(err_pipe)
        return nothing
    end
    _safe_close(in_pipe.out)
    _safe_close(out_pipe.in)
    _safe_close(err_pipe.in)

    w = WarmWorker(id, cname, proc, in_pipe, out_pipe, err_pipe, docker_mode)
    timed_out = Ref(false)
    boot_timeout_s = docker_mode ? 15.0 : 12.0
    timer = Timer(boot_timeout_s) do _
        if process_running(proc)
            timed_out[] = true
            kill(proc, Base.SIGKILL)
        end
    end

    ready_line = try
        readline(out_pipe)
    catch
        ""
    end
    close(timer)

    if timed_out[] || strip(ready_line) != "{\"ready\":true}" || !process_running(proc)
        _cleanup_worker!(w)
        return nothing
    end
    return w
end

function pool_ready_count(pool::Union{Nothing, RunnerPool})::Int
    pool === nothing && return 0
    return Base.n_avail(pool.slots)
end

function schedule_refill!(pool::RunnerPool)
    pool.target_size <= 0 && return
    pool.closed[] && return
    to_spawn = 0
    lock(pool.lock) do
        pool.closed[] && return
        current = Base.n_avail(pool.slots) + pool.pending_refills
        to_spawn = max(0, pool.target_size - current)
        pool.pending_refills += to_spawn
    end
    for _ in 1:to_spawn
        @async begin
            w = try
                _spawn_warm_worker(pool.cfg)
            catch
                nothing
            end
            keep = false
            lock(pool.lock) do
                pool.pending_refills = max(0, pool.pending_refills - 1)
                keep = !pool.closed[] && w !== nothing
            end
            if keep
                try
                    put!(pool.slots, w)
                catch
                    _cleanup_worker!(w)
                end
            elseif w !== nothing
                _cleanup_worker!(w)
            end
        end
    end
end

function start_pool(cfg::AppConfig; async::Bool = true)::RunnerPool
    pool = RunnerPool(
        cfg,
        max(0, cfg.runner_pool_size),
        Channel{WarmWorker}(max(cfg.runner_pool_size, 1)),
        Threads.Atomic{Bool}(false),
        ReentrantLock(),
        0,
    )
    if pool.target_size > 0
        if async
            schedule_refill!(pool)
        else
            for _ in 1:(pool.target_size)
                w = _spawn_warm_worker(cfg)
                w === nothing || put!(pool.slots, w)
            end
        end
    end
    return pool
end

function take_warm_worker!(pool::RunnerPool)::Union{Nothing, WarmWorker}
    pool.closed[] && return nothing
    picked = nothing
    while isready(pool.slots)
        w = try
            take!(pool.slots)
        catch
            nothing
        end
        w === nothing && break
        if process_running(w.proc)
            picked = w
            break
        else
            _cleanup_worker!(w)
        end
    end
    schedule_refill!(pool)
    return picked
end

function stop_pool!(pool::Union{Nothing, RunnerPool})
    pool === nothing && return
    pool.closed[] = true
    while isready(pool.slots)
        w = try
            take!(pool.slots)
        catch
            nothing
        end
        w === nothing || _cleanup_worker!(w)
    end
    try
        close(pool.slots)
    catch
    end
end

