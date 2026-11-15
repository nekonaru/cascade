using Test
using Cascade
using DataFrames
using CSV

@testset "config and io" begin
    @testset "load_config parses a full config" begin
        toml = """
        [network]
        kind = "barabasi_albert"
        n = 50
        k = 3

        [params]
        beta = 0.2
        forget_rate = 0.1
        literacy_boost = 0.1
        factcheck_time = 12
        factcheck_reach = 0.6
        block_top_k = 2

        [run]
        seed = 42
        strategy = "hub"
        m_seeds = 3
        steps = 90
        """
        path = tempname() * ".toml"
        write(path, toml)
        cfg = load_config(path)
        @test cfg.spec.kind == :barabasi_albert
        @test cfg.spec.n == 50
        @test cfg.params.beta == 0.2
        @test cfg.params.factcheck_time == 12
        @test cfg.params.block_top_k == 2
        @test cfg.strategy == :hub
        @test cfg.m_seeds == 3
        @test cfg.steps == 90
        rm(path; force = true)
    end

    @testset "load_config defaults and sbm" begin
        toml = """
        [network]
        kind = "sbm"
        sizes = [10, 8]
        probs = [[0.4, 0.05], [0.05, 0.4]]
        """
        path = tempname() * ".toml"
        write(path, toml)
        cfg = load_config(path)
        @test cfg.spec.kind == :sbm
        @test cfg.spec.sizes == [10, 8]
        @test cfg.spec.probs[1, 1] == 0.4
        @test cfg.params.factcheck_time === nothing
        @test cfg.strategy == :random
        rm(path; force = true)
        @test_throws ArgumentError load_config("no/such/file.toml")
    end

    @testset "history CSV round-trips" begin
        sim = run_simulation(NetworkSpec(:erdos_renyi, 80; p = 0.05),
                             CascadeParams(beta = 0.15); seed = 7, steps = 25)
        path = tempname() * ".csv"
        write_history_csv(sim, path)
        df = CSV.read(path, DataFrame)
        @test nrow(df) == 26
        @test df.t == 0:25
        @test all(df.susceptible .+ df.believer .+ df.skeptic .+ df.recovered .== 80)
        mpath = tempname() * ".csv"
        write_metrics_csv(sim, mpath)
        mdf = CSV.read(mpath, DataFrame)
        @test nrow(mdf) == 1
        @test hasproperty(mdf, :final_reach)

        jpath = tempname() * ".json"
        write_metrics_json(sim, jpath)
        json = read(jpath, String)
        @test occursin("\"final_reach\"", json)
        @test occursin("\"peak_believers\"", json)
        @test occursin("\"time_to_peak\"", json)
        rm(path; force = true)
        rm(mpath; force = true)
        rm(jpath; force = true)
    end
end
