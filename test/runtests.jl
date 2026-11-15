using Test
using Cascade
using StableRNGs
using DataFrames
using CSV

@testset "Cascade" begin
    include("test_networks.jl")
    include("test_model.jl")
    include("test_experiments.jl")
    include("test_config_io.jl")
    include("test_plots.jl")
end
