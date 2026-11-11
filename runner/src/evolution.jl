module EvolutionDomain

using Random
using ..RunnerI18n
using ..Trace

export EvolutionEnvironment,
    env_config,
    initial_population,
    seeded_rng,
    evaluate_fitness,
    mutate_bit,
    record_population!

"""
    EvolutionEnvironment

Binary/discrete genome optimization environment for evolutionary algorithms.
"""
mutable struct EvolutionEnvironment
    seed::Int
    population_size::Int
    generations::Int
    chromosome_length::Int
    mutation_rate::Float64
    crossover_rate::Float64
    elite_count::Int
    target_gene::Vector{Int}
    best_fitness::Float64
    best_genome::Vector{Int}
    rec::TraceRecorder
end

function EvolutionEnvironment(
    seed::Integer,
    population_size::Integer,
    generations::Integer,
    chromosome_length::Integer,
    mutation_rate::Real,
    crossover_rate::Real,
    elite_count::Integer,
    target_gene::AbstractVector{<:Integer},
    rec::TraceRecorder,
)
    pop = clamp(Int(population_size), 4, 60)
    gens = clamp(Int(generations), 2, 80)
    clen = clamp(Int(chromosome_length), 4, 32)
    mr = clamp(Float64(mutation_rate), 0.0, 1.0)
    cr = clamp(Float64(crossover_rate), 0.0, 1.0)
    elites = clamp(Int(elite_count), 0, pop)
    target = length(target_gene) == clen ? [Int(x) != 0 ? 1 : 0 for x in target_gene] : [i % 2 for i in 1:clen]
    return EvolutionEnvironment(
        Int(seed),
        pop,
        gens,
        clen,
        mr,
        cr,
        elites,
        target,
        0.0,
        zeros(Int, clen),
        rec,
    )
end

"""Return configuration NamedTuple for the evolutionary run."""
function env_config(env::EvolutionEnvironment)
    return (
        seed = env.seed,
        population_size = env.population_size,
        generations = env.generations,
        chromosome_length = env.chromosome_length,
        mutation_rate = env.mutation_rate,
        crossover_rate = env.crossover_rate,
        elite_count = env.elite_count,
        target_gene = copy(env.target_gene),
    )
end

"""Generate the deterministic starting population of binary genomes."""
function initial_population(env::EvolutionEnvironment)::Vector{Vector{Int}}
    rng = MersenneTwister(env.seed)
    return [Int[rand(rng, 0:1) for _ in 1:env.chromosome_length] for _ in 1:env.population_size]
end

"""Return a deterministic RNG seeded for evolutionary exploration inside the sandbox."""
seeded_rng(seed::Integer) = MersenneTwister(Int(seed))

"""Flip binary gene `0 <-> 1`."""
mutate_bit(v::Integer)::Int = Int(v) == 0 ? 1 : 0

"""Compute normalized match fitness `0.0..1.0` against `target_gene`."""
function evaluate_fitness(env::EvolutionEnvironment, genome::AbstractVector{<:Integer})::Float64
    length(genome) == env.chromosome_length || throw(
        ContractError(
            rmsg("evolution_genome_len", "expected" => env.chromosome_length, "got" => length(genome)),
        ),
    )
    matches = 0
    for i in 1:env.chromosome_length
        Int(genome[i]) == env.target_gene[i] && (matches += 1)
    end
    increment_metric!(env.rec, "evaluations", 1)
    return matches / env.chromosome_length
end

"""
    record_population!(env, gen, population, fitnesses; mutations=0, crossovers=0)

Record generation summary statistics, top individuals, diversity, and fitness convergence.
"""
function record_population!(
    env::EvolutionEnvironment,
    gen::Integer,
    population::AbstractVector,
    fitnesses::AbstractVector{<:Real};
    mutations::Integer = 0,
    crossovers::Integer = 0,
)
    isempty(population) && throw(ContractError(rmsg("evolution_empty_pop")))
    length(population) == length(fitnesses) ||
        throw(ContractError(rmsg("evolution_fitness_mismatch")))

    fvals = Float64[Float64(f) for f in fitnesses]
    order = sortperm(fvals; rev = true)
    best_idx = order[1]
    best_f = round(fvals[best_idx]; digits = 4)
    avg_f = round(sum(fvals) / length(fvals); digits = 4)
    best_g = Int[Int(x) for x in population[best_idx]]

    if best_f >= env.best_fitness
        env.best_fitness = best_f
        env.best_genome = copy(best_g)
    end

    top_n = min(6, length(order))
    top_genomes = Vector{Vector{Int}}(undef, top_n)
    top_fitnesses = Vector{Float64}(undef, top_n)
    for k in 1:top_n
        idx = order[k]
        top_genomes[k] = Int[Int(x) for x in population[idx]]
        top_fitnesses[k] = round(fvals[idx]; digits = 4)
    end

    unique_count = length(Set(Tuple(Int(x) for x in g) for g in population))
    diversity = round(unique_count / length(population); digits = 4)

    increment_metric!(env.rec, "generations_simulated", 1)
    mutations > 0 && increment_metric!(env.rec, "mutations", Int(mutations))
    crossovers > 0 && increment_metric!(env.rec, "crossovers", Int(crossovers))

    record!(
        env.rec,
        "evolution_gen";
        gen = Int(gen),
        best_fitness = best_f,
        avg_fitness = avg_f,
        diversity = diversity,
        best_genome = best_g,
        top_genomes = top_genomes,
        top_fitnesses = top_fitnesses,
        mutations = Int(mutations),
        crossovers = Int(crossovers),
    )
end

end
