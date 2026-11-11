using PackageCompiler

const PRECOMPILE_SCRIPT = joinpath(@__DIR__, "precompile_workload.jl")

create_sysimage(
    [:GardenRunner];
    project=dirname(@__DIR__),
    sysimage_path=joinpath(dirname(@__DIR__), "GardenRunner.so"),
    precompile_execution_file=PRECOMPILE_SCRIPT,
)
