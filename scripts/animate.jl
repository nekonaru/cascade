# Animated GIF of a single cascade on a small network.
# Usage: julia --project=. scripts/animate.jl [path/to/out.gif]

using Cascade

out = length(ARGS) >= 1 ? ARGS[1] : "cascade.gif"

spec = NetworkSpec(:barabasi_albert, 300; k = 3)
sim = run_simulation(spec, CascadeParams(beta = 0.06);
                     seed = 42, strategy = :hub, m_seeds = 1, steps = 80,
                     record_trace = true)

animate_gif(sim, out; fps = 12, stride = 2, seed_pos = 1)
println("animated GIF written to $out")
