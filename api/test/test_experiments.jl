@testset "ExperimentRoutes" begin
    ctx = make_test_ctx()
    try
        s_unauth, _, _ = api_req("GET", "/api/v1/experiments")
        @test s_unauth == 401

        _, r1, _ = api_req(
            "POST",
            "/api/v1/auth/register";
            body=Dict("email" => "u1@example.com", "username" => "user_one", "password" => "password123"),
        )
        tok1 = r1["data"]["token"]

        _, r2, _ = api_req(
            "POST",
            "/api/v1/auth/register";
            body=Dict("email" => "u2@example.com", "username" => "user_two", "password" => "password123"),
        )
        tok2 = r2["data"]["token"]

        s_create, b_create, _ = api_req(
            "POST",
            "/api/v1/experiments";
            token=tok1,
            body=Dict(
                "algorithm_slug" => "bubble-sort",
                "title" => "Mi Bubble Sort",
                "code" => "function sort_algorithm!(a); swap!(a, 1, 2); end",
                "params" => Dict("values" => [4, 1, 3]),
            ),
        )
        @test s_create == 201
        exp_id = b_create["data"]["experiment"]["id"]

        s_list, b_list, _ = api_req("GET", "/api/v1/experiments"; token=tok1)
        @test s_list == 200
        @test length(b_list["data"]) == 1

        # Cross-user access must be forbidden
        s_forb, b_forb, _ = api_req("GET", "/api/v1/experiments/$exp_id"; token=tok2)
        @test s_forb == 403
        @test b_forb["error"]["code"] == "forbidden"

        s_patch, b_patch, _ = api_req(
            "PATCH",
            "/api/v1/experiments/$exp_id";
            token=tok1,
            body=Dict("title" => "Bubble Optimizado"),
        )
        @test s_patch == 200
        @test b_patch["data"]["experiment"]["title"] == "Bubble Optimizado"

        s_del, b_del, _ = api_req("DELETE", "/api/v1/experiments/$exp_id"; token=tok1)
        @test s_del == 200
        @test b_del["data"]["deleted"] === true

        s_gone, _, _ = api_req("GET", "/api/v1/experiments/$exp_id"; token=tok1)
        @test s_gone == 404
    finally
        close_store!(ctx.db)
    end
end

