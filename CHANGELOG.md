# Changelog

## v0.1.0

First public release of Cascade.

## New features

- **Four network topologies.** Erdos-Renyi, Watts-Strogatz, Barabasi-Albert and Stochastic Block Model generators with explicit seeded RNGs.
- **Agent-based rumor model.** Susceptible, Believer, Skeptic and Recovered states, heterogeneous Beta(2, 5) skepticism, forgetting, and per-step transition rules documented in `docs/model.md`.
- **Seed strategies.** Random, hub and per-community seeding for the initial spreaders.
- **Interventions.** Late or early fact-checks with fixed reach, population-wide literacy boost, and upfront blocking of the top-k hub seeds.
- **Monte Carlo analysis.** Replication runner with mean, standard deviation and 95% CI, plus metrics for reach, peak activity, time to peak and initial growth.
- **Parameter sweeps.** Grid sweeps with a mean-final-reach heatmap.
- **Visualization.** State curves, mean-with-band curves, seed and fact-check comparisons, sweep heatmaps, CSV exports, and animated GIF output.
- **TOML configuration.** Full runs driven from `config/default.toml`, with scripts for single runs, Monte Carlo studies, benchmarks and animations.

## Improvements

- **Reproducibility.** StableRNG streams are split by concern (network, seeds, model); same seed, same history.
- **Deterministic adjacency.** Neighbor lists are sorted so iteration order never depends on hash or allocation order.

## Bug fixes

- None. First release.
