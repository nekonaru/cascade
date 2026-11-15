using Test
using Cascade
using StableRNGs

@testset "model" begin
    spec = NetworkSpec(:erdos_renyi, 150; p = 0.05)

    @testset "agent count is invariant" begin
        net = generate_network(spec; seed = 17)
        params = CascadeParams(beta = 0.15, forget_rate = 0.02)
        sim = init_simulation(net.adj, net.degree, params; seed = 17, seeds = [1])
        simulate(sim, 80)
        n = length(net.adj)
        for h in sim.history
            @test h.susceptible + h.believer + h.skeptic + h.recovered == n
            @test 0 <= h.ever_believer <= n
        end
    end

    @testset "states are valid and history is monotone in time" begin
        sim = run_simulation(spec, CascadeParams(beta = 0.15); seed = 5, steps = 50)
        @test all(s in (SUSCEPTIBLE, BELIEVER, SKEPTIC, RECOVERED) for s in sim.state)
        @test issorted([h.t for h in sim.history])
        @test sim.t == 50
        @test length(sim.history) == 51
    end

    @testset "determinism: same seed, identical history" begin
        a = run_simulation(spec, CascadeParams(beta = 0.12); seed = 123, steps = 60)
        b = run_simulation(spec, CascadeParams(beta = 0.12); seed = 123, steps = 60)
        @test [h.believer for h in a.history] == [h.believer for h in b.history]
        @test a.state == b.state
        @test a.skepticism == b.skepticism
    end

    @testset "different seeds diverge" begin
        a = run_simulation(spec, CascadeParams(beta = 0.12); seed = 1, steps = 60)
        b = run_simulation(spec, CascadeParams(beta = 0.12); seed = 2, steps = 60)
        @test a.history != b.history
    end

    @testset "zero steps works" begin
        sim = run_simulation(spec, CascadeParams(); seed = 9, steps = 0)
        @test length(sim.history) == 1
        @test sim.t == 0
        @test peak_believers(sim) == sim.history[1].believer
        @test time_to_peak(sim) == 0
    end

    @testset "ever_believer counts transitions, not current believers" begin
        sim = run_simulation(spec, CascadeParams(beta = 0.2, forget_rate = 0.5); seed = 21, steps = 60)
        @test sim.history[end].ever_believer >= maximum(h.believer for h in sim.history)
    end

    @testset "parameter validation" begin
        @test_throws ArgumentError CascadeParams(beta = -0.1)
        @test_throws ArgumentError CascadeParams(forget_rate = -0.1)
        @test_throws ArgumentError CascadeParams(forget_rate = 1.5)
        @test_throws ArgumentError CascadeParams(literacy_boost = -0.1)
        @test_throws ArgumentError CascadeParams(factcheck_time = 0)
        @test_throws ArgumentError CascadeParams(factcheck_reach = 1.5)
        @test_throws ArgumentError CascadeParams(factcheck_reach = -0.1)
        @test_throws ArgumentError CascadeParams(block_top_k = -1)
    end

    @testset "duplicate seeds are rejected" begin
        net = generate_network(spec; seed = 17)
        params = CascadeParams(beta = 0.15)
        @test_throws ArgumentError init_simulation(net.adj, net.degree, params; seed = 17, seeds = [1, 1, 5])
        @test_throws ArgumentError init_simulation(net.adj, net.degree, params; seed = 17, seeds = [0])
        @test_throws ArgumentError init_simulation(net.adj, net.degree, params; seed = 17, seeds = [net.n + 1])
        @test_throws ArgumentError init_simulation(net.adj, net.degree, params; seed = 17, seeds = Int[])
    end

    @testset "record_trace captures per-step states" begin
        sim = run_simulation(spec, CascadeParams(beta = 0.15); seed = 33, steps = 20, record_trace = true)
        @test length(sim.trace) == 21
        @test length(sim.trace[1]) == length(sim)
        for tr in sim.trace
            @test all(s in (SUSCEPTIBLE, BELIEVER, SKEPTIC, RECOVERED) for s in tr)
        end
    end
end
