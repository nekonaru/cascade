using Test
using Cascade
using Statistics
using StableRNGs

const NET = NetworkSpec(:barabasi_albert, 200; k = 3)
const REPS = 12

@testset "experiments" begin
    @testset "higher beta does not reduce mean reach" begin
        low = run_replications(NET, CascadeParams(beta = 0.02);
                               replications = REPS, base_seed = 1000, steps = 150)
        high = run_replications(NET, CascadeParams(beta = 0.25);
                                replications = REPS, base_seed = 1000, steps = 150)
        mlow = mean(final_reach, low)
        mhigh = mean(final_reach, high)
        @test mhigh >= mlow - 0.02
    end

    @testset "hub seeds reach at least as far as random seeds on average (BA)" begin
        hub = run_replications(NET, CascadeParams(beta = 0.1);
                               replications = REPS, base_seed = 2000, steps = 150, strategy = :hub)
        rnd = run_replications(NET, CascadeParams(beta = 0.1);
                               replications = REPS, base_seed = 2000, steps = 150, strategy = :random)
        @test mean(final_reach, hub) >= mean(final_reach, rnd) - 0.05
    end

    @testset "earlier fact-check reduces final reach" begin
        early = run_replications(NET, CascadeParams(beta = 0.12, factcheck_time = 5, factcheck_reach = 0.8);
                                 replications = REPS, base_seed = 3000, steps = 150)
        late = run_replications(NET, CascadeParams(beta = 0.12, factcheck_time = 30, factcheck_reach = 0.8);
                                replications = REPS, base_seed = 3000, steps = 150)
        never = run_replications(NET, CascadeParams(beta = 0.12);
                                 replications = REPS, base_seed = 3000, steps = 150)
        @test mean(final_reach, early) <= mean(final_reach, late) + 0.05
        @test mean(final_reach, early) <= mean(final_reach, never) + 0.05
    end

    @testset "literacy boost reduces final reach" begin
        plain = run_replications(NET, CascadeParams(beta = 0.12, literacy_boost = 0.0);
                                 replications = REPS, base_seed = 4000, steps = 150)
        boosted = run_replications(NET, CascadeParams(beta = 0.12, literacy_boost = 0.5);
                                   replications = REPS, base_seed = 4000, steps = 150)
        @test mean(final_reach, boosted) <= mean(final_reach, plain) + 0.02
    end

    @testset "blocking top-k hub seeds reduces reach" begin
        open = run_replications(NET, CascadeParams(beta = 0.15, block_top_k = 0);
                                replications = REPS, base_seed = 5000, steps = 150,
                                strategy = :hub, m_seeds = 8)
        blocked = run_replications(NET, CascadeParams(beta = 0.15, block_top_k = 4);
                                   replications = REPS, base_seed = 5000, steps = 150,
                                   strategy = :hub, m_seeds = 8)
        @test mean(final_reach, blocked) <= mean(final_reach, open) + 0.02
    end

    @testset "summarize_runs reports mean/std/ci95" begin
        sims = run_replications(NET, CascadeParams(beta = 0.1);
                                replications = 5, base_seed = 6000, steps = 60)
        s = summarize_runs(sims)
        @test 5 == maximum(s.runs)
        @test Set(s.metric) == Set(["final_reach", "peak_believers", "time_to_peak",
                                    "initial_growth", "ever_believer"])
        @test all(s.ci95_half .>= 0)
        @test all(isfinite, s.mean)
    end

    @testset "metrics are sane" begin
        sims = run_replications(NET, CascadeParams(beta = 0.1);
                                replications = 3, base_seed = 7000, steps = 60)
        for s in sims
            @test 0.0 <= final_reach(s) <= 1.0
            @test 1 <= peak_believers(s) <= length(s)
            @test 0 <= time_to_peak(s) < length(s.history)
            @test initial_growth_rate(s) >= 0.0
        end
    end

    @testset "sweep returns one row per config" begin
        configs = [CascadeParams(beta = b) for b in [0.05, 0.15]]
        df = sweep(configs, NET; replications = 2, base_seed = 8000, steps = 40)
        @test nrow(df) == 2
        @test hasproperty(df, :final_reach)
        @test eltype(df.final_reach) == Float64
        @test all(isfinite, df.final_reach)
    end

    @testset "mechanism: full reach fact-check zeroes current believers exactly at that step" begin
        spec = NetworkSpec(:barabasi_albert, 150; k = 3)
        sim = run_simulation(spec, CascadeParams(beta = 0.6, factcheck_time = 3, factcheck_reach = 1.0);
                             seed = 42, strategy = :hub, steps = 4)
        for h in sim.history
            h.t < 3 && @test h.believer > 0  # seeds and early growth happened
        end
        @test sim.history[4].believer == 0   # t == 3, fact-check lands after forwarding
    end

    @testset "mechanism: block_top_k blocks the highest-degree seeds at t=0" begin
        spec = NetworkSpec(:barabasi_albert, 120; k = 3)
        net = generate_network(spec; seed = 11)
        seeds = seed_nodes(net, :hub; m = 6, rng = StableRNG(1))
        blocked = sort(seeds; by = s -> (-net.degree[s], s))[1:2]
        sim = init_simulation(net.adj, net.degree, CascadeParams(beta = 0.1, block_top_k = 2);
                              seed = 11, seeds = seeds)
        for s in blocked
            @test sim.state[s] == RECOVERED
        end
        for s in setdiff(seeds, blocked)
            @test sim.state[s] == BELIEVER
        end
        @test sim.history[1].believer == length(seeds) - 2
    end

    @testset "mechanism: literacy boost raises sampled skepticism" begin
        spec = NetworkSpec(:erdos_renyi, 80; p = 0.1)
        net = generate_network(spec; seed = 77)
        seeds = [1]
        plain = init_simulation(net.adj, net.degree, CascadeParams(beta = 0.1, literacy_boost = 0.0); seed = 77, seeds = seeds)
        boosted = init_simulation(net.adj, net.degree, CascadeParams(beta = 0.1, literacy_boost = 0.4); seed = 77, seeds = seeds)
        @test boosted.skepticism == clamp.(plain.skepticism .+ 0.4, 0.0, 0.99)
    end

    @testset "sweep2 produces a grid with mean reach" begin
        df = sweep2(NET, [0.05, 0.15], [0.0, 0.3], :beta, :literacy_boost;
                    replications = 2, base_seed = 9000, steps = 40)
        @test nrow(df) == 4
        @test all(0.0 .<= df.final_reach .<= 1.0)
    end
end
