# Verification record (v0.1.0)

Machine: Windows laptop, Julia 1.10.13 (juliaup `lts`), 2026-11-16.

## Test suite

`julia --project=. -e 'using Pkg; Pkg.test()'` on Julia 1.10.13:

    Test Summary: | Pass  Total  Time
    Cascade       |  280    280  1m29.9s

The suite covers generator shapes and sizes, model invariants (constant agent
count, valid states, monotone history), determinism with fixed seeds, directional
effects (higher beta, hub seeds, early fact-check, literacy boost, blocked hubs),
Monte Carlo summaries, sweeps, TOML config round-trip, CSV export, and a Makie
smoke test (state curve, interval band, seed/fact-check comparisons, heatmap,
GIF animation).

## Performance (NFR: 10,000 nodes x 200 steps x 1 run < 2 s)

`julia --project=. scripts/benchmark.jl` (best and median of 5 runs, network built
once outside the timed region, beta = 0.3 so the cascade is live):

    init + 200 steps on 10,000 nodes: best=0.018 s  median=0.019 s
    final reach: 0.988

The NFR is met by roughly two orders of magnitude on this machine.

## Type stability

`@code_warntype step!(sim)` reports `Body::Simulation` with no `Core.Box` or
`Any`-typed fields in the hot loop. Fields involved per iteration are concrete:
`Vector{Int32}` adjacency lists, `Vector{Int8}` states, `Float64` skepticism,
`StableRNG` streams.

Note: `BenchmarkTools` is a test-only dependency (see `[extras]` in Project.toml)
as intended for the test environment; `scripts/benchmark.jl` uses `time_ns()` so
it runs without it.
