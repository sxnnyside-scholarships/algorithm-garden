@testset "SandboxSecurityHardening" begin
    dangerous_snippets = [
        "function sort_algorithm!(arr); eval(:(1 + 1)); end",
        "function sort_algorithm!(arr); Base.run(`id`); end",
        "function sort_algorithm!(arr); getfield(Main, :eval); end",
        "function sort_algorithm!(arr); getglobal(Base, :open); end",
        "function sort_algorithm!(arr); unsafe_string(Ptr{UInt8}(0)); end",
        "module EscapeAttempt; end\nfunction sort_algorithm!(arr); arr; end",
        "function sort_algorithm!(arr); @async println(1); end",
        "using Sockets\nfunction sort_algorithm!(arr); arr; end",
    ]

    for snippet in dangerous_snippets
        res_en = run_request(
            Dict(
                "garden" => "sorting",
                "algorithm" => "sec-check",
                "code" => snippet,
                "params" => Dict("values" => [3, 2, 1]),
                "locale" => "en",
            ),
        )
        @test res_en["status"] == "failed"
        @test res_en["error"]["category"] == "contract_violation"

        res_es = run_request(
            Dict(
                "garden" => "sorting",
                "algorithm" => "sec-check",
                "code" => snippet,
                "params" => Dict("values" => [3, 2, 1]),
                "locale" => "es",
            ),
        )
        @test res_es["status"] == "failed"
        @test res_es["error"]["category"] == "contract_violation"
        @test !occursin("not allowed", res_es["error"]["message"])
    end

    # Warm one-shot entrypoint protocol produces {"ready":true} then single-line result JSON
    entry_path = joinpath(dirname(@__DIR__), "scripts", "entrypoint.jl")
    runner_root = dirname(@__DIR__)
    cmd = Cmd([
        Base.julia_cmd().exec[1],
        "--project=$runner_root",
        "--startup-file=no",
        entry_path,
        "--warm-one-shot",
    ])
    in_p = Pipe()
    out_p = Pipe()
    err_p = Pipe()
    proc = run(pipeline(cmd; stdin = in_p, stdout = out_p, stderr = err_p); wait = false)
    close(in_p.out)
    close(out_p.in)
    close(err_p.in)

    ready_line = readline(out_p)
    @test strip(ready_line) == "{\"ready\":true}"

    payload = Dict(
        "garden" => "sorting",
        "algorithm" => "bubble-sort",
        "code" => "function sort_algorithm!(arr); swap!(arr, 1, 2); end",
        "params" => Dict("values" => [2, 1]),
        "locale" => "es",
    )
    write(in_p, to_json(payload) * "\n")
    flush(in_p)
    close(in_p)

    res_line = readline(out_p)
    wait(proc)
    @test proc.exitcode == 0
    parsed = parse_json(res_line)
    @test parsed["status"] == "completed"
    @test parsed["final_state"]["values"] == [1, 2]
end

