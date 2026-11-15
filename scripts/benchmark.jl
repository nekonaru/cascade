# Performance check: NFR target is 10,000 nodes x 200 steps x 1 run < 2 s.
# The network is built once, outside the timed region; the benchmark measures
# init + 200 steps of the simulation loop only.
# Usage: julia --project=. scripts/benchmark.jl

using Cascade
using BenchmarkTools
using StableRNGs

spec = NetworkSpec(:barabasi_albert, 10_000; k = 4)
params = CascadeParams(beta = 0.08, forget_rate = 0.05)

net = generate_network(spec; seed = 42)
seeds = seed_nodes(net, :random; m = 1, rng = StableRNG(43))

# warm up
let sim = init_simulation(net.adj, net.degree, params; seed = 42, seeds = seeds)
    simulate(sim, 5)
end

@time sim = let s = init_simulation(net.adj, net.degree, params; seed = 42, seeds = seeds)
    simulate(s, 200)
    s
end

res = @benchmark begin
    s = init_simulation($net.adj, $net.degree, $params; seed = 42, seeds = $seeds)
    simulate(s, 200)
end samples=5 evals=1
println(res)
println("median: ", round(median(res).time / 1e9, digits = 3), " s")
println("final reach: ", round(final_reach(sim), digits = 3))
