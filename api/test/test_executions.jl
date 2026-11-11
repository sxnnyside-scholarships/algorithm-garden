@testset "ExecutionRoutes" begin
    ctx = make_test_ctx()
    try
        # Real isolated subprocess execution against GardenRunner
        s_exec, b_exec, _ = api_req(
            "POST",
            "/api/v1/executions";
            body=Dict(
                "algorithm_slug" => "bubble-sort",
                "code" => """
                function sort_algorithm!(arr)
                    n = length(arr)
                    for i in 1:(n - 1), j in 1:(n - i)
                        if compare(arr, j, j + 1) > 0
                            swap!(arr, j, j + 1)
                        end
                    end
                end
                """,
                "params" => Dict("values" => [5, 1, 4, 2]),
            ),
        )
        @test s_exec == 200
        @test b_exec["data"]["execution"]["status"] == "completed"
        @test b_exec["data"]["execution"]["final_state"]["values"] == [1, 2, 4, 5]

        # Exercise verification requires auth
        s_unauth, _, _ = api_req(
            "POST",
            "/api/v1/exercises/ex-bubble-sort-early-exit/verify";
            body=Dict("code" => "function sort_algorithm!(a); end"),
        )
        @test s_unauth == 401

        _, reg, _ = api_req(
            "POST",
            "/api/v1/auth/register";
            body=Dict("email" => "student@example.com", "username" => "student1", "password" => "password123"),
        )
        tok = reg["data"]["token"]

        s_pass, b_pass, _ = api_req(
            "POST",
            "/api/v1/exercises/ex-bubble-sort-early-exit/verify";
            token=tok,
            body=Dict(
                "code" => """
                function sort_algorithm!(arr)
                    n = length(arr)
                    for i in 1:(n - 1), j in 1:(n - i)
                        if compare(arr, j, j + 1) > 0
                            swap!(arr, j, j + 1)
                        end
                    end
                end
                """,
            ),
        )
        @test s_pass == 200
        @test b_pass["data"]["passed"] === true
        @test length(b_pass["data"]["results"]) == 3

        # Multilocale end-to-end (Accept-Language: es translates API errors & runner messages)
        s_unauth_es, b_unauth_es, _ = api_req(
            "POST",
            "/api/v1/exercises/ex-bubble-sort-early-exit/verify";
            body=Dict("code" => "function sort_algorithm!(a); end"),
            headers=["Accept-Language" => "es"],
        )
        @test s_unauth_es == 401
        @test b_unauth_es["error"]["message"] == "Se requiere iniciar sesión"

        s_verify_es, b_verify_es, _ = api_req(
            "POST",
            "/api/v1/exercises/ex-bubble-sort-early-exit/verify";
            token=tok,
            headers=["Accept-Language" => "es"],
            body=Dict("code" => "function sort_algorithm!(arr); arr; end"),
        )
        @test s_verify_es == 200
        @test b_verify_es["data"]["passed"] === false
        @test occursin("Se esperaba", b_verify_es["data"]["results"][1]["message"])
    finally
        close_store!(ctx.db)
    end

    # Runner unavailable -> 503
    ctx_down = make_test_ctx(; exec_runner_fn = (_, _) -> error("docker daemon down"))
    try
        s_503, b_503, _ = api_req(
            "POST",
            "/api/v1/executions";
            body=Dict("algorithm_slug" => "bubble-sort", "code" => "function sort_algorithm!(a); end"),
        )
        @test s_503 == 503
        @test b_503["error"]["code"] == "runner_unavailable"
    finally
        close_store!(ctx_down.db)
    end
end

