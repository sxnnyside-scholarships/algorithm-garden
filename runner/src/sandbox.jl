module Sandbox

using ..RunnerI18n
using ..Trace
using ..SortingDomain
using ..PathfindingDomain
using ..CellularDomain
using ..GraphDomain
using ..FractalDomain
using ..EvolutionDomain

export compile_student_module, classify_error

const FORBIDDEN_SYMBOLS = Set{Symbol}([
    :ccall,
    :llvmcall,
    :eval,
    :include,
    :open,
    :read,
    :write,
    :readline,
    :readlines,
    :eachline,
    :readdir,
    :run,
    :pipeline,
    :Cmd,
    :download,
    :rm,
    :mv,
    :cp,
    :mkdir,
    :mkpath,
    :stat,
    :chmod,
    :chown,
    :ENV,
    :Sys,
    :Filesystem,
    :Sockets,
    :Distributed,
    :Threads,
    :Libdl,
    :Pkg,
    :unsafe_load,
    :unsafe_store!,
    :unsafe_copyto!,
    :pointer,
    :Ptr,
    :exit,
    :atexit,
    :getfield,
    :setfield!,
    :getglobal,
    :setglobal!,
    :invokelatest,
    :evalfile,
    :include_string,
    :include_dependency,
    :parentmodule,
    :names,
    :methods,
    :which,
    :unsafe_string,
    :unsafe_wrap,
    :unsafe_pointer_to_objref,
    :cglobal,
    :finalizer,
    :Base,
    :Core,
    :Main,
])

const FORBIDDEN_MACROS = Set{Symbol}([
    Symbol("@ccall"),
    Symbol("@eval"),
    Symbol("@async"),
    Symbol("@spawn"),
    Symbol("@task"),
    Symbol("@generated"),
    Symbol("@cmd"),
])

const CONTRACT_EXPORTS = (
    :TrackedVector => SortingDomain.TrackedVector,
    :swap! => SortingDomain.swap!,
    :compare => SortingDomain.compare,
    :is_less => SortingDomain.is_less,
    :is_greater => SortingDomain.is_greater,
    :mark_pivot! => SortingDomain.mark_pivot!,
    :mark_range! => SortingDomain.mark_range!,
    :mark_sorted! => SortingDomain.mark_sorted!,
    :TrackedGrid => PathfindingDomain.TrackedGrid,
    :MinPriorityQueue => PathfindingDomain.MinPriorityQueue,
    :start_node => PathfindingDomain.start_node,
    :goal_node => PathfindingDomain.goal_node,
    :grid_size => PathfindingDomain.grid_size,
    :in_bounds => PathfindingDomain.in_bounds,
    :is_walkable => PathfindingDomain.is_walkable,
    :neighbors => PathfindingDomain.neighbors,
    :step_cost => PathfindingDomain.step_cost,
    :manhattan => PathfindingDomain.manhattan,
    :euclidean => PathfindingDomain.euclidean,
    :frontier! => PathfindingDomain.frontier!,
    :visit! => PathfindingDomain.visit!,
    :relax_edge! => PathfindingDomain.relax_edge!,
    :mark_path! => PathfindingDomain.mark_path!,
    :enqueue! => PathfindingDomain.enqueue!,
    :dequeue! => PathfindingDomain.dequeue!,
    :CellularGrid => CellularDomain.CellularGrid,
    :grid_dims => CellularDomain.grid_dims,
    :generations_count => CellularDomain.generations_count,
    :wrap_edges => CellularDomain.wrap_edges,
    :rule_born => CellularDomain.rule_born,
    :rule_survive => CellularDomain.rule_survive,
    :current_cells => CellularDomain.current_cells,
    :live_neighbors => CellularDomain.live_neighbors,
    :record_generation! => CellularDomain.record_generation!,
    :TrackedGraph => GraphDomain.TrackedGraph,
    :node_count => GraphDomain.node_count,
    :graph_nodes => GraphDomain.graph_nodes,
    :graph_edges => GraphDomain.graph_edges,
    :start_vertex => GraphDomain.start_vertex,
    :target_vertex => GraphDomain.target_vertex,
    :adjacent => GraphDomain.adjacent,
    :visit_node! => GraphDomain.visit_node!,
    :queue_node! => GraphDomain.queue_node!,
    :inspect_edge! => GraphDomain.inspect_edge!,
    :mark_component! => GraphDomain.mark_component!,
    :mark_tree_edge! => GraphDomain.mark_tree_edge!,
    :mark_graph_path! => GraphDomain.mark_graph_path!,
    :FractalPlane => FractalDomain.FractalPlane,
    :plane_size => FractalDomain.plane_size,
    :complex_bounds => FractalDomain.complex_bounds,
    :max_iterations => FractalDomain.max_iterations,
    :julia_seed => FractalDomain.julia_seed,
    :recursion_depth => FractalDomain.recursion_depth,
    :pixel_complex => FractalDomain.pixel_complex,
    :emit_row! => FractalDomain.emit_row!,
    :emit_segments! => FractalDomain.emit_segments!,
    :EvolutionEnvironment => EvolutionDomain.EvolutionEnvironment,
    :env_config => EvolutionDomain.env_config,
    :initial_population => EvolutionDomain.initial_population,
    :seeded_rng => EvolutionDomain.seeded_rng,
    :evaluate_fitness => EvolutionDomain.evaluate_fitness,
    :mutate_bit => EvolutionDomain.mutate_bit,
    :record_population! => EvolutionDomain.record_population!,
)

struct SyntaxViolation <: Exception
    message::String
    line::Union{Nothing, Int}
    hint::String
end

function _find_syntax_error(node, current_line::Union{Nothing, Int} = nothing)
    if node isa LineNumberNode
        return nothing, node.line
    elseif node isa Expr
        if node.head == :error || node.head == :incomplete
            msg = isempty(node.args) ? rmsg("syntax_fallback") : string(node.args[1])
            return SyntaxViolation(
                msg,
                current_line,
                rmsg("syntax_near_line", "line" => something(current_line, 1)),
            ), current_line
        end
        ln = current_line
        for arg in node.args
            err, ln = _find_syntax_error(arg, ln)
            err !== nothing && return err, ln
        end
        return nothing, ln
    end
    return nothing, current_line
end

function _validate_ast(node)
    if node isa Symbol
        if node in FORBIDDEN_SYMBOLS
            throw(ContractError(rmsg("forbidden_symbol", "sym" => node)))
        end
        return
    elseif node isa QuoteNode
        if node.value isa Symbol && node.value in FORBIDDEN_SYMBOLS
            throw(ContractError(rmsg("forbidden_symbol", "sym" => node.value)))
        end
        return
    elseif !(node isa Expr)
        return
    end

    if node.head == :using || node.head == :import
        throw(ContractError(rmsg("forbidden_import")))
    elseif node.head == :module
        throw(ContractError(rmsg("forbidden_module")))
    elseif node.head == :macrocall && !isempty(node.args)
        mac = node.args[1]
        if mac isa Symbol && mac in FORBIDDEN_MACROS
            throw(ContractError(rmsg("forbidden_macro", "mac" => mac)))
        end
    end

    for arg in node.args
        _validate_ast(arg)
    end
end

"""
    compile_student_module(code::AbstractString) -> Module

Parse, enforce sandbox AST restrictions, and evaluate student code in a fresh `Module`.
"""
function compile_student_module(code::AbstractString)::Module
    parsed = try
        Meta.parseall(String(code))
    catch err
        if err isa Base.Meta.ParseError
            throw(SyntaxViolation(err.msg, nothing, rmsg("syntax_hint")))
        end
        rethrow()
    end

    syntax_err, _ = _find_syntax_error(parsed)
    syntax_err !== nothing && throw(syntax_err)

    _validate_ast(parsed)

    mod = Module(:StudentSandbox)
    for (name, val) in CONTRACT_EXPORTS
        Core.eval(mod, :(const $name = $val))
    end
    Core.eval(mod, parsed)
    return mod
end

function _extract_sandbox_line(bt)::Union{Nothing, Int}
    for frame in stacktrace(bt)
        fname = string(frame.file)
        if frame.line > 0 && (fname == "none" || occursin("StudentSandbox", fname))
            return frame.line
        end
    end
    return nothing
end

function classify_error(err, bt = nothing)::Dict{String, Any}
    if err isa SyntaxViolation
        return Dict{String, Any}(
            "category" => "syntax",
            "message" => err.message,
            "line" => err.line,
            "hint" => err.hint,
        )
    elseif err isa RunnerLimitError
        return Dict{String, Any}(
            "category" => err.category,
            "message" => err.message,
            "line" => bt === nothing ? nothing : _extract_sandbox_line(bt),
            "hint" =>
                err.category == "timeout" ? rmsg("timeout_hint") : rmsg("limit_hint"),
        )
    elseif err isa ContractError
        return Dict{String, Any}(
            "category" => "contract_violation",
            "message" => err.message,
            "line" => bt === nothing ? nothing : _extract_sandbox_line(bt),
            "hint" => rmsg("contract_hint"),
        )
    else
        msg = sprint(showerror, err)
        hint = if err isa BoundsError
            rmsg("bounds_hint")
        elseif err isa UndefVarError
            rmsg("undef_hint")
        elseif err isa MethodError
            rmsg("method_hint")
        else
            rmsg("generic_hint")
        end
        return Dict{String, Any}(
            "category" => "runtime",
            "message" => msg,
            "line" => bt === nothing ? nothing : _extract_sandbox_line(bt),
            "hint" => hint,
        )
    end
end

end

