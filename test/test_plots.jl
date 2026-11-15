using Test
using Cascade

@testset "plots (smoke)" begin
    dir = mktempdir()
    net = NetworkSpec(:erdos_renyi, 80; p = 0.08)
    sim = run_simulation(net, CascadeParams(beta = 0.2); seed = 5, steps = 25, record_trace = true)

    p1 = joinpath(dir, "state.png")
    plot_state_curve(sim, p1)
    @test isfile(p1) && filesize(p1) > 0

    sims = run_replications(net, CascadeParams(beta = 0.2); replications = 2, base_seed = 100, steps = 15)
    p2 = joinpath(dir, "interval.png")
    plot_curve_interval(sims, p2)
    @test isfile(p2) && filesize(p2) > 0

    p3 = joinpath(dir, "seeds.png")
    a = run_simulation(net, CascadeParams(beta = 0.2); seed = 6, steps = 15, strategy = :random)
    b = run_simulation(net, CascadeParams(beta = 0.2); seed = 6, steps = 15, strategy = :hub)
    plot_seed_comparison([("random", a), ("hub", b)], p3)
    @test isfile(p3) && filesize(p3) > 0

    p4 = joinpath(dir, "factcheck.png")
    plot_factcheck_comparison([("none", a), ("t=5", b)], p4)
    @test isfile(p4) && filesize(p4) > 0

    df = sweep2(net, [0.1, 0.2], [0.0, 0.3], :beta, :literacy_boost;
                replications = 1, base_seed = 300, steps = 15)
    p5 = joinpath(dir, "heatmap.png")
    plot_sweep_heatmap(df, :beta, :literacy_boost, p5)
    @test isfile(p5) && filesize(p5) > 0

    p6 = joinpath(dir, "anim.gif")
    animate_gif(sim, p6; fps = 10, stride = 5, seed_pos = 1)
    @test isfile(p6) && filesize(p6) > 0
end
