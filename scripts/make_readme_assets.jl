# Generate README figures: curves, seed comparison, fact-check comparison, heatmap.
# Requires the package to be instantiated (julia --project=. -e 'using Pkg; Pkg.instantiate()').
# Usage: julia --project=. scripts/make_readme_assets.jl

using Cascade
using DataFrames
using Statistics

assetdir = joinpath(@__DIR__, "..", "assets")
isdir(assetdir) || mkdir(assetdir)
println("writing assets to $(abspath(assetdir))")

n = 1000
spec = NetworkSpec(:barabasi_albert, n; k = 3)

println("1/4 curve with interval band")
sims = run_replications(spec, CascadeParams(beta = 0.15);
                        replications = 20, base_seed = 42, steps = 120)
plot_curve_interval(sims, joinpath(assetdir, "curve-interval.png"))

println("2/4 seed comparison (random vs hub)")
hub = run_simulation(spec, CascadeParams(beta = 0.05); seed = 42, strategy = :hub, steps = 120)
rnd = run_simulation(spec, CascadeParams(beta = 0.05); seed = 42, strategy = :random, steps = 120)
plot_seed_comparison([("random seeds", rnd), ("hub seeds", hub)],
                     joinpath(assetdir, "seed-comparison.png"))

println("3/4 fact-check timing (none vs t=10 vs t=25)")
sim_none = run_simulation(spec, CascadeParams(beta = 0.15); seed = 42, steps = 120)
sim_t10 = run_simulation(spec, CascadeParams(beta = 0.15, factcheck_time = 10, factcheck_reach = 0.7); seed = 42, steps = 120)
sim_t25 = run_simulation(spec, CascadeParams(beta = 0.15, factcheck_time = 25, factcheck_reach = 0.7); seed = 42, steps = 120)
plot_factcheck_comparison([("no fact-check", sim_none), ("t = 10", sim_t10), ("t = 25", sim_t25)],
                          joinpath(assetdir, "factcheck-comparison.png"))

println("4/4 beta x forget_rate heatmap")
df = sweep2(spec, [0.02, 0.05, 0.08, 0.12, 0.16], [0.0, 0.1, 0.2, 0.3],
            :beta, :forget_rate;
            replications = 4, base_seed = 42, steps = 100)
plot_sweep_heatmap(df, :beta, :forget_rate, joinpath(assetdir, "sweep-heatmap.png"))

println("done")
