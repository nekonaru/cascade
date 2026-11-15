# Cascade: model documentation

This document records the model equations and the design decisions behind them.
Cascade simulates how a single rumor ("hoaks") spreads through a synthetic social
network and how simple interventions change the outcome. All data is synthetic.
Cascade does not model real accounts, real messages or real platform behavior, and
its outputs are not predictions about the real world.

## 1. Agents and states

Each of the `n` nodes `i = 1..n` carries two attributes: a state and a skepticism
level.

| State | Code | Meaning |
|-------|------|---------|
| Susceptible | 0 | Not yet reached by the message |
| Believer | 1 | Believes and actively forwards the message |
| Skeptic | 2 | Exposed but not convinced, or converted by a fact-check |
| Recovered | 3 | No longer spreads (forgot the message, or blocked as a seed) |

Skepticism `s_i` is sampled once per agent from `Beta(2, 5)`, then shifted by
`literacy_boost` and clipped to `[0, 0.99]`. One Monte Carlo replication therefore
contains a population of heterogeneous agents.

## 2. Transition rules

Let `B(t)` be the set of Believers at the start of step `t`. Processing order per
step (all randomness through an explicit `StableRNG`):

1. **Forwarding and conversion.** For each `b in B(t)` and each Susceptible neighbor
   `j` of `b`:
   - with probability `p_expose = beta * (1 - s_j)` the message reaches `j`;
   - given exposure, `j` becomes a Believer with probability `(1 - s_j)`, else a
     Skeptic.

   The effective probability that `j` becomes a Believer in one step is therefore
   `beta * (1 - s_j)^2`, and the probability of becoming an informed Skeptic is
   `beta * (1 - s_j) * s_j`.

2. **Forgetting.** Each agent in `B(t)` transitions to Recovered with probability
   `forget_rate`. Agents converted in step 1 do not act until step `t + 1`.

3. **Fact-check.** If `factcheck_time == t`, a uniformly random fraction
   `factcheck_reach` of the current Believers becomes Skeptic (without replacement).

4. **Recording.** Counts of each state are appended to the history.

## 3. Initial condition

One or more seed nodes start as Believers:

- `:random` - uniform without replacement;
- `:hub` - the `m` highest-degree nodes (ties by lower id);
- `:community` - round-robin across communities (for SBM: blocks; otherwise
  connected components), so every community is seeded before any community twice.

If `block_top_k > 0`, the `k` highest-degree seed nodes are set to Recovered at
t = 0 instead (upfront blocking).

## 4. Networks

| Generator | Function | Parameters |
|-----------|----------|------------|
| Erdos-Renyi | `erdos_renyi(n, p)` | connection probability p |
| Watts-Strogatz | `watts_strogatz(n, k, beta)` | ring lattice degree k (even), rewire probability |
| Barabasi-Albert | `barabasi_albert(n, k)` | preferential attachment k |
| Stochastic Block Model | `stochastic_block_model(sizes, probs)` | block sizes, block probability matrix |

Generators are thin wrappers around Graphs.jl; adjacency lists are sorted so
iteration order is deterministic. SBM communities come from block labels; the other
generators use connected components as pseudo-communities.

## 5. Metrics

- `final_reach` - fraction of agents that were ever reached: `1 - S_final / n`.
  Agents count as reached if they hold any non-Susceptible state at the end.
- `ever_believer` - cumulative number of agents that entered the Believer state
  (Believer + Recovered + the Believers that were later fact-checked).
- `peak_believers` - maximum number of simultaneous active Believers.
- `time_to_peak` - first step at which that maximum occurs.
- `initial_growth` - mean new Believers per step over the first 5 steps.

## 6. Reproducibility

Network generation and seed selection use separate StableRNG streams
(`seed` and `seed + 1` by default in `run_simulation`). The model itself draws only
from the stream passed to `init_simulation`. Two calls with identical arguments
produce identical histories; the tests assert this explicitly.

Model parameters are independent of any storage or random source. Nothing is read
from disk inside the simulation loop.

## 7. Limitations

- The model is SIR-like with an informed Skeptic class; it does not model message
  content, platform algorithms, repeat exposure or competing rumors.
- Skepticism is static per agent (no learning) except for the literacy_boost shift
  applied up front.
- Network is static (no tie formation or breakage).
- "Fact-check" is an abstract broadcast with a fixed reach, not a realistic
  distribution mechanism.
- Results describe this synthetic model only. They are a teaching tool for network
  science, not evidence about any real rumor, platform or population.
