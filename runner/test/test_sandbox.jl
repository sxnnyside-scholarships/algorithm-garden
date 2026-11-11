using GardenRunner.Sandbox
using GardenRunner.Trace

@testset "Sandbox" begin
    # Forbidden constructs must be rejected before evaluation
    for unsafe_code in [
        "function sort_algorithm!(a); run(`ls`); end",
        "function sort_algorithm!(a); open(\"/etc/passwd\"); end",
        "using Sockets\nfunction sort_algorithm!(a); end",
        "function sort_algorithm!(a); ccall(:exit, Cvoid, (Cint,), 0); end",
        "function sort_algorithm!(a); eval(:(1+1)); end",
        "function sort_algorithm!(a); ENV[\"SECRET\"]; end",
        "function sort_algorithm!(a); @eval 1 + 1; end",
    ]
        @test_throws ContractError compile_student_module(unsafe_code)
    end

    # Syntax errors classified cleanly
    err = try
        compile_student_module("function sort_algorithm!(a)\n  if true\n    x = 1\n")
        nothing
    catch e
        classify_error(e)
    end
    @test err !== nothing
    @test err["category"] == "syntax"

    # Valid compilation
    mod = compile_student_module("""
    function sort_algorithm!(arr)
        swap!(arr, 1, 2)
    end
    """)
    @test isdefined(mod, :sort_algorithm!)
end

