# Performance check: NFR target is 10,000 nodes x 200 steps x 1 run < 2 s.
# The network is built once, outside the timed region; the timing covers
# init + 200 steps of the simulation loop. Prints the best and median of
# several repetitions (BenchmarkTools lives in the test environment; this
# script only uses the standard library so it runs anywhere the package works).
# Usage: julia --project=. scripts/benchmark.jl

using Cascade
using StableRNGs
using Statistics
using Printf

const NSEC_PER_SEC = 1e9

spec = NetworkSpec(:barabasi_albert, 10_000; k = 4)
params = CascadeParams(beta = 0.3, forget_rate = 0.05)

net = generate_network(spec; seed = 42)
seeds = seed_nodes(net, :random; m = 1, rng = StableRNG(43))

# warm up
let sim = init_simulation(net.adj, net.degree, params; seed = 42, seeds = seeds)
    simulate(sim, 5)
end

times = Float64[]
reaches = Float64[]
for rep in 1:5
    t_start = time_ns()
    sim = init_simulation(net.adj, net.degree, params; seed = 42, seeds = seeds)
    simulate(sim, 200)
    push!(times, (time_ns() - t_start) / NSEC_PER_SEC)
    push!(reaches, final_reach(sim))
end
let
    global reach = last(reaches)
end

@printf("init + 200 steps on 10,000 nodes: best=%.3f s  median=%.3f s\n",
        minimum(times), median(times))
@printf("final reach: %.3f\n", reach)
