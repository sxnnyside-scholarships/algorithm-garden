@testset "Phase6Gardens" begin
    ctx = make_test_ctx()
    try
        phase6_slugs = Set(["cellular", "graph", "fractal", "evolution"])
        phase6_algos = [a for a in GardenApi.CatalogSeed.ALGORITHMS_SEED if a.garden_slug in phase6_slugs]
        @test length(phase6_algos) == 12

        for algo in phase6_algos
            s, body, _ = api_req(
                "POST",
                "/api/v1/executions";
                body=Dict(
                    "algorithm_slug" => algo.slug,
                    "code" => algo.reference_code,
                ),
            )
            @test s == 200
            exec = body["data"]["execution"]
            @test exec["status"] == "completed"
            @test exec["garden"] == algo.garden_slug
            @test !isempty(exec["events"])
        end
    finally
        close_store!(ctx.db)
    end
end

