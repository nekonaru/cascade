# Run a simulation from a TOML config file.
# Usage: julia --project=. scripts/run_config.jl [config/default.toml]

using Cascade

path = length(ARGS) >= 1 ? ARGS[1] : joinpath(@__DIR__, "..", "config", "default.toml")
cfg = load_config(path)

sim = run_simulation(cfg.spec, cfg.params; seed = cfg.seed, strategy = cfg.strategy,
                     m_seeds = cfg.m_seeds, steps = cfg.steps)

println("Cascade run from config: $path")
println("  network: ", cfg.spec.kind, " (n=", cfg.spec.n, ")")
println("  final reach (fraction ever reached): ", round(final_reach(sim), digits = 3))
println("  ever believer (count):               ", sim.history[end].ever_believer)
println("  peak active believers:               ", peak_believers(sim))
println("  time to peak:                        ", time_to_peak(sim), " steps")
println("  initial growth (new believers/step): ", round(initial_growth_rate(sim), digits = 1))
