module Cascade

using Random
using Graphs
using StableRNGs
using Distributions
using DataFrames
using CSV
using TOML
using Printf
using Statistics

export
    # networks
    generate_network, NetworkSpec, NetworkResult,
    network_erdos_renyi, network_watts_strogatz, network_barabasi_albert, network_stochastic_block_model,
    # model
    SUSCEPTIBLE, BELIEVER, SKEPTIC, RECOVERED,
    CascadeParams, Simulation, StateCounts,
    init_simulation, step!, simulate,
    # interventions (seed selection)
    seed_nodes,
    # experiments
    run_simulation, run_replications, summarize_runs,
    final_reach, peak_believers, time_to_peak, initial_growth_rate,
    sweep, sweep2,
    history_dataframe, metrics_dataframe, write_history_csv, write_metrics_csv, write_metrics_json,
    # config
    load_config,
    # plots
    plot_state_curve, plot_curve_interval, plot_seed_comparison,
    plot_factcheck_comparison, plot_sweep_heatmap, animate_gif

include("networks.jl")
include("model.jl")
include("interventions.jl")
include("experiments.jl")
include("config.jl")
include("plots.jl")

end # module Cascade
