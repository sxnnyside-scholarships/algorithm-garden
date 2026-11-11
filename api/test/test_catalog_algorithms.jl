using Test
using JSON3
using GardenApi

const _RUNNER_SRC = joinpath(dirname(dirname(@__DIR__)), "runner", "src")
if !(_RUNNER_SRC in LOAD_PATH)
    push!(LOAD_PATH, _RUNNER_SRC)
end
using GardenRunner

@testset "CatalogSeedAlgorithmsValidation" begin
    algos = GardenApi.CatalogSeed.ALGORITHMS_SEED
    @test length(algos) == 22

    @testset "All seeded algorithms complete on default_params_json" begin
        for algo in algos
            params = JSON3.read(algo.default_params_json, Dict{String, Any})
            res = GardenRunner.run_request(
                Dict{String, Any}(
                    "garden" => algo.garden_slug,
                    "algorithm" => algo.slug,
                    "code" => algo.reference_code,
                    "params" => params,
                    "max_events" => 50_000,
                    "timeout_ms" => 5_000,
                ),
            )
            @test res["status"] == "completed"
            @test res["error"] === nothing
            @test !isempty(res["events"])
            @test res["final_state"] !== nothing

            if algo.garden_slug == "sorting"
                vals = res["final_state"]["values"]
                @test issorted(vals)
                @test sort(res["initial_state"]["values"]) == vals
            elseif algo.garden_slug == "pathfinding"
                @test res["final_state"]["found"] === true
                @test !isempty(res["final_state"]["path"])
            elseif algo.garden_slug == "cellular"
                @test res["final_state"]["generations"] >= 1
            elseif algo.garden_slug == "graph"
                @test haskey(res["final_state"], "result")
            elseif algo.garden_slug == "fractal"
                @test haskey(res["final_state"], "mode")
            elseif algo.garden_slug == "evolution"
                @test res["final_state"]["generations"] >= 1
            end
        end
    end

    @testset "Sorting algorithms terminate and sort across stress inputs" begin
        sorting_algos = [a for a in algos if a.garden_slug == "sorting"]
        @test length(sorting_algos) == 6

        for algo in sorting_algos
            for dist in ("random", "reversed", "nearly_sorted", "few_unique")
                res = GardenRunner.run_request(
                    Dict{String, Any}(
                        "garden" => "sorting",
                        "algorithm" => algo.slug,
                        "code" => algo.reference_code,
                        "params" => Dict{String, Any}("size" => 50, "distribution" => dist, "seed" => 42),
                        "max_events" => 50_000,
                        "timeout_ms" => 5_000,
                    ),
                )
                @test res["status"] == "completed"
                @test issorted(res["final_state"]["values"])
            end

            for edge_vals in ([42], [5, 5, 5, 5], [9, 1])
                res = GardenRunner.run_request(
                    Dict{String, Any}(
                        "garden" => "sorting",
                        "algorithm" => algo.slug,
                        "code" => algo.reference_code,
                        "params" => Dict{String, Any}("values" => edge_vals),
                        "max_events" => 50_000,
                        "timeout_ms" => 5_000,
                    ),
                )
                @test res["status"] == "completed"
                @test res["final_state"]["values"] == sort(edge_vals)
            end
        end

        for fast_slug in ("merge-sort", "quick-sort", "heap-sort")
            algo = sorting_algos[findfirst(a -> a.slug == fast_slug, sorting_algos)]
            res = GardenRunner.run_request(
                Dict{String, Any}(
                    "garden" => "sorting",
                    "algorithm" => algo.slug,
                    "code" => algo.reference_code,
                    "params" => Dict{String, Any}("size" => 500, "distribution" => "reversed", "seed" => 42),
                    "max_events" => 50_000,
                    "timeout_ms" => 5_000,
                ),
            )
            @test res["status"] == "completed"
            @test issorted(res["final_state"]["values"])
        end
    end
end

