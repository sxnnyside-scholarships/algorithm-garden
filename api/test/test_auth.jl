@testset "AuthRoutes" begin
    ctx = make_test_ctx()
    try
        # Validation failure
        s_bad, b_bad, _ = api_req(
            "POST",
            "/api/v1/auth/register";
            body=Dict("email" => "not-an-email", "username" => "x", "password" => "123"),
        )
        @test s_bad == 422
        @test b_bad["error"]["code"] == "validation_failed"
        @test haskey(b_bad["error"]["details"], "email")
        @test haskey(b_bad["error"]["details"], "password")

        # Register success
        s_reg, b_reg, _ = api_req(
            "POST",
            "/api/v1/auth/register";
            body=Dict("email" => "ada@example.com", "username" => "ada_lovelace", "password" => "supersecret123"),
        )
        @test s_reg == 201
        token = b_reg["data"]["token"]
        @test b_reg["data"]["user"]["username"] == "ada_lovelace"
        @test !haskey(b_reg["data"]["user"], "password_hash")

        # Duplicate conflict
        s_dup, b_dup, _ = api_req(
            "POST",
            "/api/v1/auth/register";
            body=Dict("email" => "ada@example.com", "username" => "ada2", "password" => "supersecret123"),
        )
        @test s_dup == 409
        @test b_dup["error"]["code"] == "conflict"

        # Me endpoint
        s_me, b_me, _ = api_req("GET", "/api/v1/auth/me"; token=token)
        @test s_me == 200
        @test b_me["data"]["user"]["email"] == "ada@example.com"

        # Wrong password
        s_wp, _, _ = api_req(
            "POST",
            "/api/v1/auth/login";
            body=Dict("email" => "ada@example.com", "password" => "wrongpass"),
        )
        @test s_wp == 401

        # Valid login
        s_log, b_log, _ = api_req(
            "POST",
            "/api/v1/auth/login";
            body=Dict("email" => "ada@example.com", "password" => "supersecret123"),
        )
        @test s_log == 200
        token2 = b_log["data"]["token"]

        # Logout revokes session
        s_out, _, _ = api_req("POST", "/api/v1/auth/logout"; token=token2)
        @test s_out == 200
        s_after, _, _ = api_req("GET", "/api/v1/auth/me"; token=token2)
        @test s_after == 401
    finally
        close_store!(ctx.db)
    end
end

