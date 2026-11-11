@testset "Phase5Hardening" begin
    # Production requires AUTH_TOKEN_SECRET (>= 32 bytes)
    @test_throws ErrorException load_config(
        overrides=Dict("APP_ENV" => "production", "AUTH_TOKEN_SECRET" => ""),
    )
    @test_throws ErrorException load_config(
        overrides=Dict("APP_ENV" => "production", "AUTH_TOKEN_SECRET" => "too-short"),
    )

    cfg_warm = load_config(
        overrides=Dict(
            "APP_ENV" => "development",
            "HOST" => "127.0.0.1",
            "DB_DRIVER" => "sqlite",
            "SQLITE_PATH" => ":memory:",
            "RUNNER_MODE" => "subprocess",
            "RUNNER_POOL_SIZE" => "1",
        ),
    )
    @test cfg_warm.runner_pool_size == 1

    # Synchronous warmup populates 1 warm subprocess worker, executes on it cleanly, then stops cleanly
    pool = GardenApi.RunnerClient.start_pool(cfg_warm; async=false)
    try
        @test GardenApi.RunnerClient.pool_ready_count(pool) == 1
        res = GardenApi.RunnerClient.execute_in_sandbox(
            cfg_warm,
            Dict{String, Any}(
                "garden" => "sorting",
                "algorithm" => "bubble-sort",
                "code" => "function sort_algorithm!(arr); swap!(arr, 1, 3); end",
                "params" => Dict{String, Any}("values" => [3, 2, 1]),
                "locale" => "es",
            );
            pool=pool,
        )
        @test res["status"] == "completed"
        @test res["final_state"]["values"] == [1, 2, 3]
    finally
        GardenApi.RunnerClient.stop_pool!(pool)
        @test GardenApi.RunnerClient.pool_ready_count(pool) == 0
    end

    ctx = make_test_ctx()
    try
        # Defensive security & CORS headers
        s_opt, _, opt_resp = api_req("OPTIONS", "/api/v1/executions")
        @test s_opt == 204
        allow_hdrs = HTTP.header(opt_resp, "Access-Control-Allow-Headers", "")
        @test occursin("Accept-Language", allow_hdrs)
        @test occursin("Authorization", allow_hdrs)

        _, _, h_resp = api_req("GET", "/health")
        @test HTTP.header(h_resp, "X-Content-Type-Options", "") == "nosniff"
        @test HTTP.header(h_resp, "X-Frame-Options", "") == "DENY"
        @test HTTP.header(h_resp, "Cache-Control", "") == "no-store"

        # Sandbox escape over HTTP execution endpoint
        s_esc, b_esc, _ = api_req(
            "POST",
            "/api/v1/executions";
            body=Dict(
                "algorithm_slug" => "bubble-sort",
                "code" => "function sort_algorithm!(arr); getfield(Main, :eval); end",
            ),
            headers=["Accept-Language" => "es"],
        )
        @test s_esc == 200
        @test b_esc["data"]["execution"]["status"] == "failed"
        @test b_esc["data"]["execution"]["error"]["category"] == "contract_violation"

        # Parameterized queries store literal SQLi/XSS strings safely without execution or injection
        _, reg, _ = api_req(
            "POST",
            "/api/v1/auth/register";
            body=Dict("email" => "sec@example.com", "username" => "secuser", "password" => "password123"),
        )
        tok = reg["data"]["token"]

        tricky_title = "<script>alert(1)</script> ' OR 1=1; DROP TABLE users;--"
        s_exp, b_exp, exp_resp = api_req(
            "POST",
            "/api/v1/experiments";
            token=tok,
            body=Dict(
                "algorithm_slug" => "bubble-sort",
                "title" => tricky_title,
                "code" => "function sort_algorithm!(arr); arr; end",
                "params" => Dict("values" => [3, 1, 2]),
            ),
        )
        @test s_exp == 201
        @test b_exp["data"]["experiment"]["title"] == tricky_title
        @test startswith(HTTP.header(exp_resp, "Content-Type", ""), "application/json")

        # Users table still intact after tricky title insert
        s_me, b_me, _ = api_req("GET", "/api/v1/auth/me"; token=tok)
        @test s_me == 200
        @test b_me["data"]["user"]["username"] == "secuser"
    finally
        close_store!(ctx.db)
    end
end
