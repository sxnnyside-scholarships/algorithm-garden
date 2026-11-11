@testset "HealthEndpoints" begin
    ctx = make_test_ctx(; readiness_runner_fn = _ -> (true, 2))
    try
        s0, b0, _ = api_req("GET", "/")
        @test s0 == 200
        @test b0["data"]["service"] == "algorithm-garden-api"

        s1, b1, _ = api_req("GET", "/health")
        @test s1 == 200
        @test b1["status"] == "ok"

        s2, b2, _ = api_req("GET", "/health/ready")
        @test s2 == 200
        @test b2["status"] == "ready"
        @test b2["checks"]["database"]["ok"] === true
        @test b2["checks"]["runner"]["ok"] === true

        h0 = Oxygen.internalrequest(HTTP.Request("HEAD", "/"))
        @test h0.status == 200
        @test isempty(h0.body)
        h1 = Oxygen.internalrequest(HTTP.Request("HEAD", "/health"))
        @test h1.status == 200
        @test isempty(h1.body)
    finally
        close_store!(ctx.db)
    end

    # Failing runner dependency -> 503
    ctx_bad_runner = make_test_ctx(; readiness_runner_fn = _ -> (false, 5))
    try
        s3, b3, _ = api_req("GET", "/health/ready")
        @test s3 == 503
        @test b3["status"] == "not_ready"
        @test b3["checks"]["runner"]["ok"] === false
    finally
        close_store!(ctx_bad_runner.db)
    end

    # Closed DB -> 503 while /health stays 200
    ctx_bad_db = make_test_ctx(; readiness_runner_fn = _ -> (true, 1))
    close_store!(ctx_bad_db.db)
    s_live, _, _ = api_req("GET", "/health")
    @test s_live == 200
    s_ready, b_ready, _ = api_req("GET", "/health/ready")
    @test s_ready == 503
    @test b_ready["status"] == "not_ready"
    @test b_ready["checks"]["database"]["ok"] === false

    # Single-container static SPA serving when STATIC_DIR is configured
    spa_dir = mktempdir()
    try
        mkdir(joinpath(spa_dir, "assets"))
        write(joinpath(spa_dir, "index.html"), "<!doctype html><div id=\"app\">garden</div>")
        write(joinpath(spa_dir, "assets", "app.js"), "console.log('garden');")

        cfg_spa = load_config(;
            overrides=Dict(
                "APP_ENV" => "test",
                "HOST" => "127.0.0.1",
                "DB_DRIVER" => "sqlite",
                "SQLITE_PATH" => ":memory:",
                "RUNNER_MODE" => "subprocess",
                "STATIC_DIR" => spa_dir,
            ),
        )
        ctx_spa = build_app!(cfg_spa; readiness_runner_fn = _ -> (true, 1))
        try
            r_idx = Oxygen.internalrequest(HTTP.Request("GET", "/"))
            @test r_idx.status == 200
            @test occursin("garden", String(r_idx.body))

            h_idx = Oxygen.internalrequest(HTTP.Request("HEAD", "/"))
            @test h_idx.status == 200
            @test isempty(h_idx.body)

            h_route = Oxygen.internalrequest(HTTP.Request("HEAD", "/workspace/bubble-sort"))
            @test h_route.status == 200
            @test isempty(h_route.body)

            r_route = Oxygen.internalrequest(HTTP.Request("GET", "/workspace/bubble-sort"))
            @test r_route.status == 200
            @test occursin("garden", String(r_route.body))

            r_js = Oxygen.internalrequest(HTTP.Request("GET", "/assets/app.js"))
            @test r_js.status == 200
            @test occursin("console.log", String(r_js.body))

            s_api_404, b_api_404, _ = api_req("GET", "/api/v1/does-not-exist")
            @test s_api_404 == 404
            @test haskey(b_api_404, "error")

            s_trav, _, _ = api_req("GET", "/../../etc/passwd")
            @test s_trav == 400
        finally
            close_store!(ctx_spa.db)
        end
    finally
        rm(spa_dir; recursive=true, force=true)
    end
end

