@testset "CatalogRoutes" begin
    ctx = make_test_ctx()
    try
        s_g, b_g, _ = api_req("GET", "/api/v1/gardens")
        @test s_g == 200
        @test length(b_g["data"]) == 6
        @test [g["slug"] for g in b_g["data"]] == ["sorting", "pathfinding", "cellular", "graph", "fractal", "evolution"]
        @test b_g["data"][1]["algorithms_count"] == 6
        @test b_g["data"][2]["algorithms_count"] == 4
        @test b_g["data"][3]["algorithms_count"] == 3
        @test b_g["data"][4]["algorithms_count"] == 4
        @test b_g["data"][5]["algorithms_count"] == 3
        @test b_g["data"][6]["algorithms_count"] == 2

        s_a, b_a, _ = api_req("GET", "/api/v1/algorithms?garden=sorting")
        @test s_a == 200
        @test length(b_a["data"]) == 6

        s_d, b_d, _ = api_req("GET", "/api/v1/algorithms/quick-sort")
        @test s_d == 200
        @test b_d["data"]["algorithm"]["slug"] == "quick-sort"
        @test !isempty(b_d["data"]["exercises"])

        s_404, b_404, _ = api_req("GET", "/api/v1/algorithms/missing-algo")
        @test s_404 == 404
        @test b_404["error"]["code"] == "not_found"
    finally
        close_store!(ctx.db)
    end
end

