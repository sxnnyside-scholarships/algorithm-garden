@testset "Executor" begin
    bubble_code = """
    function sort_algorithm!(arr)
        n = length(arr)
        for i in 1:n-1
            for j in 1:n-i
                if compare(arr, j, j + 1) > 0
                    swap!(arr, j, j + 1)
                end
            end
            mark_sorted!(arr, n - i + 1)
        end
        mark_sorted!(arr, 1)
    end
    """

    res = run_request(
        Dict(
            "garden" => "sorting",
            "algorithm" => "bubble-sort",
            "code" => bubble_code,
            "params" => Dict("values" => [9, 3, 7, 1]),
            "tests" => [
                Dict("name" => "reversed", "params" => Dict("values" => [5, 4, 3, 2, 1])),
                Dict("name" => "duplicates", "params" => Dict("values" => [3, 1, 3, 2, 1])),
            ],
        ),
    )

    @test res["status"] == "completed"
    @test res["final_state"]["values"] == [1, 3, 7, 9]
    @test res["metrics"]["swaps"] > 0
    @test length(res["events"]) > 0
    @test all(t -> t["passed"] === true, res["tests"])

    # Failing exercise implementation
    broken_sort = """
    function sort_algorithm!(arr)
        return arr
    end
    """
    fail_res = run_request(
        Dict(
            "garden" => "sorting",
            "algorithm" => "bubble-sort",
            "code" => broken_sort,
            "params" => Dict("values" => [4, 2, 1]),
            "tests" => [Dict("name" => "must_sort", "params" => Dict("values" => [4, 2, 1]))],
        ),
    )
    @test fail_res["status"] == "completed"
    @test fail_res["tests"][1]["passed"] === false

    # Pathfinding A* with weighted cell
    astar_code = """
    function find_path(grid)
        s = start_node(grid)
        g = goal_node(grid)
        pq = MinPriorityQueue{Tuple{Int,Int}, Float64}()
        enqueue!(pq, s, 0.0)
        came_from = Dict{Tuple{Int,Int}, Tuple{Int,Int}}(s => s)
        g_score = Dict{Tuple{Int,Int}, Float64}(s => 0.0)
        frontier!(grid, s; cost=0.0)

        while !isempty(pq)
            cur, _ = dequeue!(pq)
            visit!(grid, cur; cost=g_score[cur])
            if cur == g
                path = Tuple{Int,Int}[]
                while cur != s
                    pushfirst!(path, cur)
                    cur = came_from[cur]
                end
                pushfirst!(path, s)
                return path
            end
            for nxt in neighbors(grid, cur)
                tentative = g_score[cur] + step_cost(grid, cur, nxt)
                if tentative < get(g_score, nxt, Inf)
                    came_from[nxt] = cur
                    g_score[nxt] = tentative
                    relax_edge!(grid, cur, nxt, tentative)
                    enqueue!(pq, nxt, tentative + manhattan(nxt, g))
                    frontier!(grid, nxt; cost=tentative)
                end
            end
        end
        return Tuple{Int,Int}[]
    end
    """
    pf_res = run_request(
        Dict(
            "garden" => "pathfinding",
            "algorithm" => "a-star",
            "code" => astar_code,
            "params" => Dict(
                "rows" => 4,
                "cols" => 4,
                "start" => [1, 1],
                "goal" => [4, 4],
                "walls" => [[1, 2], [2, 2], [3, 2]],
                "weights" => [[4, 2, 10.0]],
            ),
            "tests" => [
                Dict(
                    "name" => "basic_grid",
                    "params" => Dict("rows" => 3, "cols" => 3, "start" => [1, 1], "goal" => [3, 3]),
                    "expected_cost" => 4.0,
                ),
                Dict(
                    "name" => "unreachable",
                    "params" => Dict(
                        "rows" => 3,
                        "cols" => 3,
                        "start" => [1, 1],
                        "goal" => [3, 3],
                        "walls" => [[1, 2], [2, 1]],
                    ),
                    "expect_reachable" => false,
                ),
            ],
        ),
    )
    @test pf_res["status"] == "completed"
    @test pf_res["final_state"]["found"] === true
    @test pf_res["final_state"]["path"][1] == [1, 1]
    @test pf_res["final_state"]["path"][end] == [4, 4]
    @test all(t -> t["passed"] === true, pf_res["tests"])

    # Infinite loop caught by event/time budget
    loop_res = run_request(
        Dict(
            "garden" => "sorting",
            "algorithm" => "infinite",
            "code" => "function sort_algorithm!(arr); while true; compare(arr, 1, 2); end; end",
            "params" => Dict("values" => [2, 1]),
            "max_events" => 50,
        ),
    )
    @test loop_res["status"] == "failed"
    @test loop_res["error"]["category"] == "resource_limit"

    # Spanish locale execution errors and exercise feedback
    loop_es = run_request(
        Dict(
            "locale" => "es",
            "garden" => "sorting",
            "algorithm" => "infinite",
            "code" => "function sort_algorithm!(arr); while true; compare(arr, 1, 2); end; end",
            "params" => Dict("values" => [2, 1]),
            "max_events" => 50,
        ),
    )
    @test loop_es["status"] == "failed"
    @test occursin("límite máximo de eventos (50)", loop_es["error"]["message"])
    @test occursin("Reduce la cantidad de operaciones", loop_es["error"]["hint"])

    sort_es = run_request(
        Dict(
            "locale" => "es-MX",
            "garden" => "sorting",
            "algorithm" => "bubble-sort",
            "code" => "function sort_algorithm!(arr); arr; end",
            "params" => Dict("values" => [3, 1, 2]),
            "tests" => [
                Dict("name" => "reverse", "params" => Dict("values" => [3, 1, 2])),
            ],
        ),
    )
    @test sort_es["status"] == "completed"
    @test sort_es["tests"][1]["passed"] === false
    @test occursin("Se esperaba [1, 2, 3], se obtuvo [3, 1, 2].", sort_es["tests"][1]["message"])
end

