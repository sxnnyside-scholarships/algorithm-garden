using GardenRunner.Trace
using GardenRunner.SortingDomain

@testset "SortingDomain" begin
    rec = TraceRecorder(; max_events=100, timeout_ms=2000)
    arr = TrackedVector([30, 10, 20], rec)

    @test length(arr) == 3
    @test compare(arr, 1, 2) == 1
    @test is_greater(arr, 1, 2)
    @test is_less(arr, 2, 3)

    swap!(arr, 1, 2)
    @test arr.data == [10, 30, 20]

    arr[3] = 25
    @test arr[3] == 25

    mark_pivot!(arr, 2)
    mark_range!(arr, 1, 3)
    mark_sorted!(arr, 1)

    @test rec.metrics["comparisons"] == 3
    @test rec.metrics["swaps"] == 1
    @test rec.metrics["writes"] == 3
    @test rec.events[1]["type"] == "compare"
    @test rec.events[4]["type"] == "swap"
    @test rec.events[4]["values"] == [10, 30]

    @test_throws BoundsError arr[99]
    @test_throws ArgumentError mark_range!(arr, 3, 1)

    tight = TraceRecorder(; max_events=2, timeout_ms=2000)
    tarr = TrackedVector([2, 1], tight)
    compare(tarr, 1, 2)
    compare(tarr, 1, 2)
    @test_throws RunnerLimitError compare(tarr, 1, 2)
end

