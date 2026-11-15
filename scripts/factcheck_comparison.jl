# Monte Carlo comparison of fact-check timings.
# Usage: julia --project=. scripts/factcheck_comparison.jl [output.csv]

using Cascade
using DataFrames
using CSV
using Statistics

out = length(ARGS) >= 1 ? ARGS[1] : "factcheck-comparison.csv"
spec = NetworkSpec(:barabasi_albert, 1000; k = 3)

rows = NamedTuple[]
for ft in (nothing, 6, 12, 24)
    params = CascadeParams(beta = 0.15, factcheck_time = ft, factcheck_reach = 0.7)
    sims = run_replications(spec, params; replications = 100, base_seed = 42, steps = 150)
    reach = mean(final_reach, sims)
    label = ft === nothing ? "none" : string(ft)
    push!(rows, (factcheck_time = label, mean_reach = reach,
                 sd = std(final_reach.(sims))))
    println("factcheck_time=$label  mean reach=$(round(reach, digits = 3))")
end

CSV.write(out, DataFrame(rows))
println("summary written to $out")
