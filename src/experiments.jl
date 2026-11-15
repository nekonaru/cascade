# Experiment orchestration: single runs, Monte Carlo replications, parameter sweeps.

"""
    run_simulation(spec::NetworkSpec, params::CascadeParams; seed, strategy, m_seeds, steps) -> Simulation

Generate the network, pick seed nodes with `strategy`, and run `steps` steps.
"""
function run_simulation(spec::NetworkSpec, params::CascadeParams;
                        seed::Integer, strategy::Symbol = :random,
                        m_seeds::Integer = 1, steps::Integer = 200,
                        record_trace::Bool = false)
    net = generate_network(spec; seed = seed)
    rng = StableRNG(seed + 1)   # independent stream for seed selection
    seeds = seed_nodes(net, strategy; m = m_seeds, rng = rng)
    sim = init_simulation(net.adj, net.degree, params; seed = seed, seeds = seeds, record_trace = record_trace)
    simulate(sim, steps)
    return sim
end

# ---------- metrics ----------

"""Fraction of agents that were ever reached (not Susceptible at the end of the run)."""
final_reach(sim::Simulation) = 1.0 - sim.history[end].susceptible / length(sim)

"""Peak number of simultaneously active Believers."""
peak_believers(sim::Simulation) = maximum(h -> h.believer, sim.history)

"""Step at which the peak number of active Believers occurs (first occurrence)."""
function time_to_peak(sim::Simulation)
    times = [h.believer for h in sim.history]
    return argmax(times) - 1   # history[1] is t = 0
end

"""Average number of new Believers per step over the first `window` steps."""
function initial_growth_rate(sim::Simulation; window::Integer = 5)
    w = min(window, length(sim.history) - 1)
    w <= 0 && return 0.0
    return (sim.history[w + 1].ever_believer - sim.history[1].ever_believer) / w
end

metrics_dataframe(sim::Simulation) = DataFrame(
    final_reach = final_reach(sim),
    peak_believers = peak_believers(sim),
    time_to_peak = time_to_peak(sim),
    initial_growth = initial_growth_rate(sim),
    ever_believer = sim.history[end].ever_believer,
)

history_dataframe(sim::Simulation) = DataFrame(
    t = [h.t for h in sim.history],
    susceptible = [h.susceptible for h in sim.history],
    believer = [h.believer for h in sim.history],
    skeptic = [h.skeptic for h in sim.history],
    recovered = [h.recovered for h in sim.history],
    ever_believer = [h.ever_believer for h in sim.history],
)

write_history_csv(sim::Simulation, path::AbstractString) = CSV.write(path, history_dataframe(sim))
write_metrics_csv(sim::Simulation, path::AbstractString) = CSV.write(path, metrics_dataframe(sim))

# ---------- Monte Carlo ----------

function _one_run(spec::NetworkSpec, params::CascadeParams, run_seed::Integer;
                  strategy::Symbol, m_seeds::Integer, steps::Integer)
    net = generate_network(spec; seed = run_seed)
    rng = StableRNG(run_seed + 1)
    seeds = seed_nodes(net, strategy; m = m_seeds, rng = rng)
    sim = init_simulation(net.adj, net.degree, params; seed = run_seed, seeds = seeds)
    simulate(sim, steps)
    return sim
end

"""
    run_replications(spec, params; replications, base_seed, strategy, m_seeds, steps) -> Vector{Simulation}
"""
function run_replications(spec::NetworkSpec, params::CascadeParams;
                          replications::Integer = 10, base_seed::Integer = 42,
                          strategy::Symbol = :random, m_seeds::Integer = 1, steps::Integer = 200)
    replications >= 1 || throw(ArgumentError("replications must be >= 1, got $replications"))
    return [_one_run(spec, params, base_seed + i; strategy = strategy, m_seeds = m_seeds, steps = steps)
            for i in 0:replications-1]
end

"""
    summarize_runs(sims::Vector{Simulation}) -> DataFrame

Per-run metrics plus mean, std and 95% CI (t-distribution) for each metric.
"""
function summarize_runs(sims::Vector{Simulation})
    isempty(sims) && throw(ArgumentError("sims must not be empty"))
    m = metrics_dataframe(sims[1])
    for s in sims[2:end]
        m = vcat(m, metrics_dataframe(s))
    end
    n = nrow(m)
    ci_half(col) = n > 1 ? quantile(TDist(n - 1), 0.975) * std(col; corrected = true) / sqrt(n) : 0.0
    out = DataFrame(
        metric = names(m),
        mean = [mean(m[!, c]) for c in names(m)],
        std = [n > 1 ? std(m[!, c]; corrected = true) : 0.0 for c in names(m)],
        ci95_half = [ci_half(m[!, c]) for c in names(m)],
        runs = n,
    )
    return out
end

# ---------- parameter sweeps ----------

"""
    sweep(configs::Vector{CascadeParams}, spec; replications, base_seed, strategy, m_seeds, steps) -> DataFrame

Run Monte Carlo replications for each parameter set; return one row per config with mean metrics.
"""
function sweep(configs::AbstractVector{CascadeParams}, spec::NetworkSpec;
               replications::Integer = 5, base_seed::Integer = 42,
               strategy::Symbol = :random, m_seeds::Integer = 1, steps::Integer = 200)
    isempty(configs) && throw(ArgumentError("configs must not be empty"))
    rows = map(configs) do p
        sims = run_replications(spec, p; replications = replications, base_seed = base_seed,
                                strategy = strategy, m_seeds = m_seeds, steps = steps)
        s = summarize_runs(sims)
        (beta = p.beta, forget_rate = p.forget_rate, literacy_boost = p.literacy_boost,
         factcheck_time = something(p.factcheck_time, -1),
         factcheck_reach = p.factcheck_reach,
         block_top_k = p.block_top_k,
         final_reach = only(s.mean[s.metric .== "final_reach"]),
         peak_believers = only(s.mean[s.metric .== "peak_believers"]),
         time_to_peak = only(s.mean[s.metric .== "time_to_peak"]),
         initial_growth = only(s.mean[s.metric .== "initial_growth"]))
    end
    return DataFrame(rows)
end

"""
    sweep2(spec, xs, ys, xname, yname; replications, base_seed, strategy, m_seeds, steps, base) -> DataFrame

Two-parameter grid sweep. `base` provides default values for the parameters not swept.
The returned DataFrame has one row per (x, y) pair with mean final_reach.
"""
function sweep2(spec::NetworkSpec, xs, ys, xname::Symbol, yname::Symbol;
                replications::Integer = 5, base_seed::Integer = 42,
                strategy::Symbol = :random, m_seeds::Integer = 1, steps::Integer = 200,
                base::CascadeParams = CascadeParams())
    rows = NamedTuple[]
    for x in xs
        for y in ys
            kw = Dict{Symbol, Any}(name => getfield(base, name)
                                   for name in fieldnames(CascadeParams))
            kw[xname] = x
            kw[yname] = y
            p1 = CascadeParams(; kw...)
            sims = run_replications(spec, p1; replications = replications, base_seed = base_seed,
                                    strategy = strategy, m_seeds = m_seeds, steps = steps)
            r = mean(final_reach, sims)
            push!(rows, (xname => x, yname => y, final_reach = r))
        end
    end
    return DataFrame(rows)
end
