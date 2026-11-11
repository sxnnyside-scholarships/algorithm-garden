using Test
using GardenRunner

@testset "GardenRunner" begin
    include("test_json.jl")
    include("test_sorting.jl")
    include("test_pathfinding.jl")
    include("test_sandbox.jl")
    include("test_sandbox_security.jl")
    include("test_executor.jl")
    include("test_phase6_gardens.jl")
end

