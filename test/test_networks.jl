using Test
using Cascade
using StableRNGs

@testset "networks" begin
    @testset "erdos-renyi" begin
        spec = NetworkSpec(:erdos_renyi, 120; p = 0.05)
        net = generate_network(spec; seed = 7)
        @test net.n == 120
        @test length(net.adj) == 120
        @test sum(net.degree) == sum(length, net.adj)
        @test iseven(sum(net.degree))  # undirected graph
        @test all(d -> d >= 0, net.degree)
    end

    @testset "watts-strogatz" begin
        spec = NetworkSpec(:watts_strogatz, 60; k = 4, ws_beta = 0.1)
        net = generate_network(spec; seed = 7)
        @test net.n == 60
        @test all(d -> d == 4, net.degree)  # rewiring preserves each node's degree
    end

    @testset "barabasi-albert" begin
        spec = NetworkSpec(:barabasi_albert, 80; k = 3)
        net = generate_network(spec; seed = 7)
        @test net.n == 80
        @test all(d -> d >= 1, net.degree)
        @test maximum(net.degree) > 3  # hubs emerge
    end

    @testset "sbm" begin
        sizes = [30, 25, 20]
        probs = [0.20 0.01 0.01; 0.01 0.20 0.01; 0.01 0.01 0.20]
        spec = NetworkSpec(:sbm, 75; sizes = sizes, probs = probs)
        net = generate_network(spec; seed = 7)
        @test net.n == 75
        @test maximum(net.communities) == 3
        @test all(==(1), net.communities[1:30])  # nodes are laid out block by block
        @test all(==(2), net.communities[31:55])
        @test all(==(3), net.communities[56:75])
    end

    @testset "reproducibility" begin
        spec = NetworkSpec(:erdos_renyi, 100; p = 0.05)
        a = generate_network(spec; seed = 99)
        b = generate_network(spec; seed = 99)
        c = generate_network(spec; seed = 100)
        @test a.adj == b.adj
        @test a.degree == b.degree
        @test a.adj != c.adj || a.degree != c.degree
    end

    @testset "validation" begin
        @test_throws ArgumentError network_erdos_renyi(10, 1.5; rng = StableRNG(1))
        @test_throws ArgumentError network_erdos_renyi(1, 0.5; rng = StableRNG(1))
        @test_throws ArgumentError network_watts_strogatz(10, 3, 0.1; rng = StableRNG(1))  # k must be even
        @test_throws ArgumentError network_stochastic_block_model([5], fill(0.1, 1, 1); rng = StableRNG(1))
        @test_throws ArgumentError network_stochastic_block_model([5, 5], fill(1.5, 2, 2); rng = StableRNG(1))
    end

    @testset "community seeding round-robin" begin
        sizes = [10, 10]
        probs = [0.5 0.01; 0.01 0.5]
        spec = NetworkSpec(:sbm, 20; sizes = sizes, probs = probs)
        net = generate_network(spec; seed = 3)
        seeds = seed_nodes(net, :community; m = 4, rng = StableRNG(1))
        @test length(seeds) == 4
        @test length(unique(seeds)) == 4
        @test count(<=(10), seeds) == 2
        @test count(>(10), seeds) == 2
    end

    @testset "hub seeding picks highest degree" begin
        spec = NetworkSpec(:barabasi_albert, 100; k = 3)
        net = generate_network(spec; seed = 11)
        seeds = seed_nodes(net, :hub; m = 5, rng = StableRNG(1))
        expected = sortperm(1:100; by = i -> (-net.degree[i], i))[1:5]
        @test Set(seeds) == Set(expected)
    end

    @testset "random seeding is deterministic per rng" begin
        net = generate_network(NetworkSpec(:erdos_renyi, 100; p = 0.1); seed = 5)
        a = seed_nodes(net, :random; m = 3, rng = StableRNG(42))
        b = seed_nodes(net, :random; m = 3, rng = StableRNG(42))
        @test a == b
        @test length(unique(a)) == 3
    end
end
