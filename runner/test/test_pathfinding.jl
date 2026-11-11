using GardenRunner.Trace
using GardenRunner.PathfindingDomain

@testset "PathfindingDomain" begin
    rec = TraceRecorder(; max_events=200, timeout_ms=2000)
    walls = Set([(1, 2), (2, 2)])
    weights = Dict((2, 3) => 4.0)
    grid = TrackedGrid(3, 3, (1, 1), (3, 3), walls, weights, rec)

    @test start_node(grid) == (1, 1)
    @test goal_node(grid) == (3, 3)
    @test grid_size(grid) == (3, 3)
    @test neighbors(grid, (1, 1)) == [(2, 1)]
    @test step_cost(grid, (2, 2), (2, 3)) == 4.0
    @test manhattan((1, 1), (3, 3)) == 4

    frontier!(grid, (2, 1); cost=1.0)
    visit!(grid, (2, 1); cost=1.0)
    relax_edge!(grid, (1, 1), (2, 1), 1.0)

    total = mark_path!(grid, [(1, 1), (2, 1), (3, 1), (3, 2), (3, 3)])
    @test total == 4.0
    @test rec.metrics["nodes_visited"] == 1
    @test rec.metrics["frontier_enqueued"] == 1
    @test rec.metrics["edges_relaxed"] == 1

    @test_throws ContractError mark_path!(grid, [(1, 1), (1, 2)])
    @test_throws ContractError mark_path!(grid, [(1, 1), (3, 3)])

    pq = MinPriorityQueue{Tuple{Int, Int}, Float64}()
    enqueue!(pq, (2, 2), 5.0)
    enqueue!(pq, (1, 1), 1.5)
    enqueue!(pq, (3, 3), 3.0)
    @test dequeue!(pq) == ((1, 1), 1.5)
    @test dequeue!(pq) == ((3, 3), 3.0)
    @test dequeue!(pq) == ((2, 2), 5.0)
    @test isempty(pq)
end

