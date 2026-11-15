# Full Monte Carlo study: 200 replications, random vs hub seeds, CSV summary.
# Usage: julia --project=. scripts/montecarlo.jl [output.csv]

using Cascade
using DataFrames
using CSV
using Statistics

out = length(ARGS) >= 1 ? ARGS[1] : "montecarlo-summary.csv"
spec = NetworkSpec(:barabasi_albert, 1000; k = 3)
params = CascadeParams(beta = 0.06)

rows = NamedTuple[]
for strategy in (:random, :hub)
    sims = run_replications(spec, params; replications = 200, base_seed = 42,
                            strategy = strategy, steps = 150)
    s = summarize_runs(sims)
    for row in eachrow(s)
        push!(rows, (strategy = String(strategy), metric = row.metric,
                     mean = row.mean, std = row.std, ci95_half = row.ci95_half))
    end
    println("strategy=$strategy  reach=$(round(mean(final_reach, sims), digits = 3))")
end

CSV.write(out, DataFrame(rows))
println("summary written to $out")
