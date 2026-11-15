# Core agent model: state, parameters, and the per-step transition rules.
#
# Agent states (Int8 codes):
#   SUSCEPTIBLE (0)  not yet reached by the message
#   BELIEVER    (1)  believes and actively forwards the message
#   SKEPTIC     (2)  was exposed but does not believe (or was fact-checked)
#   RECOVERED   (3)  no longer spreads (forgetting or blocked seed)
#
# All randomness flows through the explicit rng passed to init_simulation;
# there is no global RNG state hidden anywhere in the model.

const SUSCEPTIBLE = Int8(0)
const BELIEVER    = Int8(1)
const SKEPTIC     = Int8(2)
const RECOVERED   = Int8(3)

struct CascadeParams
    beta::Float64              # per-neighbor forwarding probability per step
    forget_rate::Float64       # probability a Believer stops spreading per step
    literacy_boost::Float64    # added to every agent's skepticism before t=0 (clipped to [0, 0.99])
    factcheck_time::Union{Int,Nothing}  # step at which a fact-check lands (nothing disables it)
    factcheck_reach::Float64   # fraction of current Believers converted to Skeptic by the fact-check
    block_top_k::Int           # upfront: block the k highest-degree seed nodes (they never spread)
end

CascadeParams(; beta::Float64 = 0.08, forget_rate::Float64 = 0.05,
                literacy_boost::Float64 = 0.0,
                factcheck_time::Union{Int,Nothing} = nothing,
                factcheck_reach::Float64 = 0.5,
                block_top_k::Int = 0) = begin
    0.0 <= beta || throw(ArgumentError("beta must be >= 0, got $beta"))
    0.0 <= forget_rate <= 1.0 || throw(ArgumentError("forget_rate must be in [0, 1], got $forget_rate"))
    literacy_boost >= 0.0 || throw(ArgumentError("literacy_boost must be >= 0 (use 0.0 for no boost), got $literacy_boost"))
    factcheck_time === nothing || factcheck_time >= 1 ||
        throw(ArgumentError("factcheck_time must be a step >= 1, got $factcheck_time"))
    0.0 <= factcheck_reach <= 1.0 || throw(ArgumentError("factcheck_reach must be in [0, 1], got $factcheck_reach"))
    block_top_k >= 0 || throw(ArgumentError("block_top_k must be >= 0, got $block_top_k"))
    CascadeParams(beta, forget_rate, literacy_boost, factcheck_time, factcheck_reach, block_top_k)
end

struct StateCounts
    t::Int
    susceptible::Int
    believer::Int
    skeptic::Int
    recovered::Int
    ever_believer::Int         # cumulative count of agents that became Believer up to and including t
end

mutable struct Simulation
    adj::Vector{Vector{Int32}}
    state::Vector{Int8}
    skepticism::Vector{Float64}
    degree::Vector{Int32}
    params::CascadeParams
    rng::StableRNG
    t::Int
    ever_believer::Int
    history::Vector{StateCounts}
    record_trace::Bool          # keep a full state snapshot per step (for animations)
    trace::Vector{Vector{Int8}}
end

Base.length(sim::Simulation) = length(sim.adj)

count_states(state::Vector{Int8}, ever_believer::Int, t::Int) = StateCounts(
    t,
    count(==(SUSCEPTIBLE), state),
    count(==(BELIEVER), state),
    count(==(SKEPTIC), state),
    count(==(RECOVERED), state),
    ever_believer,
)

"""
    init_simulation(adj, degree, params; seed, seeds, record_trace=false) -> Simulation

Build the initial state. `seeds` is a non-empty vector of distinct 1-based seed
node ids (see seed_nodes). Seed nodes start as BELIEVER, unless blocked by
`params.block_top_k` (then RECOVERED). Skepticism is sampled from Beta(2, 5) and
shifted by `params.literacy_boost` (clipped to [0, 0.99]).
"""
function init_simulation(adj::Vector{Vector{Int32}}, degree::Vector{Int32},
                         params::CascadeParams; seed::Integer,
                         seeds::AbstractVector{<:Integer},
                         record_trace::Bool = false)
    rng = StableRNG(seed)
    n = length(adj)
    state = fill(SUSCEPTIBLE, n)
    nseeds = length(seeds)
    nseeds >= 1 || throw(ArgumentError("at least one seed node is required"))
    all(s -> 1 <= s <= n, seeds) || throw(ArgumentError("seed ids out of range"))
    length(unique(Int.(seeds))) == nseeds || throw(ArgumentError("duplicate seed ids are not allowed: $seeds"))

    # Block the k highest-degree seeds up front (banning the main spreaders).
    blocked = Set{Int}()
    if params.block_top_k > 0
        ranked = sort(seeds; by = s -> (-degree[s], s))
        for s in Iterators.take(ranked, min(params.block_top_k, nseeds))
            push!(blocked, Int(s))
        end
    end

    for s in seeds
        state[Int(s)] = (Int(s) in blocked) ? RECOVERED : BELIEVER
    end

    skepticism = clamp.(rand(rng, Beta(2, 5), n) .+ params.literacy_boost, 0.0, 0.99)
    ever = count(==(BELIEVER), state)

    sim = Simulation(adj, state, skepticism, degree, params, rng, 0, ever, StateCounts[], record_trace, Vector{Int8}[])
    push!(sim.history, count_states(state, ever, 0))
    record_trace && push!(sim.trace, copy(state))
    return sim
end

"""
    step!(sim::Simulation) -> Simulation

Advance the simulation by one step. Processing order:
1. Believers attempt to forward to each Susceptible neighbor (probability beta * (1 - skepticism)).
2. The neighbor is converted: to BELIEVER with probability (1 - skepticism), else to SKEPTIC.
3. Believers that were already spreading at the start of the step forget with probability forget_rate (-> RECOVERED).
4. If params.factcheck_time == this step, a fact-check converts a random fraction
   params.factcheck_reach of current Believers to SKEPTIC.
"""
function step!(sim::Simulation)
    sim.t += 1
    state = sim.state
    skepticism = sim.skepticism
    adj = sim.adj
    params = sim.params
    rng = sim.rng
    n = length(state)

    # Snapshot of believers at the start of the step; new converts act next step.
    believers = Int[]
    sizehint!(believers, count(==(BELIEVER), state))
    @inbounds for i in 1:n
        state[i] == BELIEVER && push!(believers, i)
    end

    # 1-2: forwarding and conversion.
    converted = 0
    for b in believers
        @inbounds for nb in adj[b]
            state[nb] == SUSCEPTIBLE || continue
            p = params.beta * (1.0 - skepticism[nb])
            if rand(rng) < p
                if rand(rng) < (1.0 - skepticism[nb])
                    state[nb] = BELIEVER
                    converted += 1
                else
                    state[nb] = SKEPTIC
                end
            end
        end
    end

    # 3: forgetting (only agents that were believers at the start of the step).
    fl = params.forget_rate
    if fl > 0.0
        @inbounds for b in believers
            state[b] == BELIEVER && rand(rng) < fl && (state[b] = RECOVERED)
        end
    end

    # 4: fact-check lands on this step.
    ft = params.factcheck_time
    if ft !== nothing && sim.t == ft && params.factcheck_reach > 0.0
        current = Int[]
        @inbounds for i in 1:n
            state[i] == BELIEVER && push!(current, i)
        end
        take_n = floor(Int, params.factcheck_reach * length(current))
        # partial Fisher-Yates shuffle of the first take_n positions
        for i in 1:take_n
            j = i + rand(rng, 0:(length(current) - i))
            current[i], current[j] = current[j], current[i]
            state[current[i]] = SKEPTIC
        end
    end

    sim.ever_believer += converted
    push!(sim.history, count_states(state, sim.ever_believer, sim.t))
    sim.record_trace && push!(sim.trace, copy(state))
    return sim
end

"""
    simulate(sim::Simulation, steps::Integer) -> Simulation

Run `steps` steps of the simulation, returning the simulation with a full history.
"""
function simulate(sim::Simulation, steps::Integer)
    steps >= 0 || throw(ArgumentError("steps must be >= 0, got $steps"))
    for _ in 1:steps
        step!(sim)
    end
    return sim
end
