@testset "Phase4GardensAndExercises" begin
    ctx = make_test_ctx()
    try
        sorting_algos = [a for a in GardenApi.CatalogSeed.ALGORITHMS_SEED if a.garden_slug == "sorting"]
        path_algos = [a for a in GardenApi.CatalogSeed.ALGORITHMS_SEED if a.garden_slug == "pathfinding"]
        @test length(sorting_algos) == 6
        @test length(path_algos) == 4

        sorting_ex = [
            e for e in GardenApi.CatalogSeed.EXERCISES_SEED if
            any(a -> a.slug == e.algorithm_slug && a.garden_slug == "sorting", sorting_algos)
        ]
        path_ex = [
            e for e in GardenApi.CatalogSeed.EXERCISES_SEED if
            any(a -> a.slug == e.algorithm_slug && a.garden_slug == "pathfinding", path_algos)
        ]
        @test length(sorting_ex) >= 3
        @test length(path_ex) >= 3

        # Verify every Sorting reference algorithm completes cleanly in the isolated runner.
        for algo in sorting_algos
            s, body, _ = api_req(
                "POST",
                "/api/v1/executions";
                body=Dict(
                    "algorithm_slug" => algo.slug,
                    "code" => algo.reference_code,
                    "params" => Dict("size" => 10, "distribution" => "reversed", "seed" => 7),
                ),
            )
            @test s == 200
            exec = body["data"]["execution"]
            @test exec["status"] == "completed"
            @test !isempty(exec["events"])
            @test exec["final_state"]["values"] == sort(exec["initial_state"]["values"])
        end

        # Verify every Pathfinding reference algorithm completes cleanly in the isolated runner.
        for algo in path_algos
            s, body, _ = api_req(
                "POST",
                "/api/v1/executions";
                body=Dict(
                    "algorithm_slug" => algo.slug,
                    "code" => algo.reference_code,
                    "params" => Dict(
                        "rows" => 6,
                        "cols" => 6,
                        "start" => [1, 1],
                        "goal" => [6, 6],
                        "walls" => [[2, 2], [3, 2], [4, 2]],
                        "weights" => [[1, 3, 6.0], [1, 4, 6.0]],
                    ),
                ),
            )
            @test s == 200
            exec = body["data"]["execution"]
            @test exec["status"] == "completed"
            @test !isempty(exec["events"])
            @test exec["final_state"]["found"] === true
            path = exec["final_state"]["path"]
            @test path[1] == [1, 1]
            @test path[end] == [6, 6]
        end

        # Verify every seeded exercise rejects incomplete starter_code and passes reference_code.
        _, reg, _ = api_req(
            "POST",
            "/api/v1/auth/register";
            body=Dict(
                "email" => "phase4@example.com",
                "username" => "phase4tester",
                "password" => "password123",
            ),
        )
        tok = reg["data"]["token"]

        ref_by_slug = Dict(a.slug => a.reference_code for a in GardenApi.CatalogSeed.ALGORITHMS_SEED)
        for ex in GardenApi.CatalogSeed.EXERCISES_SEED
            s_fail, b_fail, _ = api_req(
                "POST",
                "/api/v1/exercises/$(ex.id)/verify";
                token=tok,
                body=Dict("code" => ex.starter_code),
            )
            @test s_fail == 200
            @test b_fail["data"]["passed"] === false

            s_ok, b_ok, _ = api_req(
                "POST",
                "/api/v1/exercises/$(ex.id)/verify";
                token=tok,
                body=Dict("code" => ref_by_slug[ex.algorithm_slug]),
            )
            @test s_ok == 200
            @test b_ok["data"]["passed"] === true
        end
    finally
        close_store!(ctx.db)
    end
end

