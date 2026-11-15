# Single run: print metrics and save the state curve + history CSV.
# Usage: julia --project=. scripts/run_single.jl

using Cascade

spec = NetworkSpec(:barabasi_albert, 1000; k = 3)
params = CascadeParams(beta = 0.08, forget_rate = 0.05)

sim = run_simulation(spec, params; seed = 42, strategy = :random, m_seeds = 1, steps = 200)

println("Cascade single run (barabasi_albert, n=1000, seed=42, random seeds)")
println("  final reach (fraction ever reached): ", round(final_reach(sim), digits = 3))
println("  ever believer (count):               ", sim.history[end].ever_believer)
println("  peak active believers:               ", peak_believers(sim))
println("  time to peak:                        ", time_to_peak(sim), " steps")
println("  initial growth (new believers/step): ", round(initial_growth_rate(sim), digits = 1))

write_history_csv(sim, "cascade-history.csv")
println("  history written to cascade-history.csv")
