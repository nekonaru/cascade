# Visualization (CairoMakie + GraphMakie).
#
# Model logic lives in model.jl; this file only turns histories into figures.

using CairoMakie
using GraphMakie
using Graphs

const STATE_COLORS = Dict(SUSCEPTIBLE => "#9aa5b1", BELIEVER => "#0e9f9a",
                          SKEPTIC => "#d9a441", RECOVERED => "#5b6470")
const STATE_LABELS = Dict(SUSCEPTIBLE => "Susceptible", BELIEVER => "Believer",
                          SKEPTIC => "Skeptic", RECOVERED => "Recovered")

"""
    plot_state_curve(sim::Simulation, path::AbstractString)

Line chart of S/B/K/R over time; saves to `path` (png/svg).
"""
function plot_state_curve(sim::Simulation, path::AbstractString)
    hdf = history_dataframe(sim)
    fig = Figure(; size = (900, 500))
    ax = Axis(fig[1, 1]; xlabel = "time step", ylabel = "agents", title = "Cascade over time")
    for (col, lab) in [(:susceptible, "Susceptible"), (:believer, "Believer"),
                       (:skeptic, "Skeptic"), (:recovered, "Recovered")]
        code = col === :susceptible ? SUSCEPTIBLE : col === :believer ? BELIEVER :
               col === :skeptic ? SKEPTIC : RECOVERED
        lines!(ax, hdf.t, hdf[!, col]; color = STATE_COLORS[code], label = lab, linewidth = 2)
    end
    axislegend(ax; position = :rt)
    save(path, fig)
    return fig
end

"""
    plot_curve_interval(sims::AbstractVector{Simulation}, path::AbstractString)

Mean believer/reached fraction with a 95% band across replications.
"""
function plot_curve_interval(sims::AbstractVector{Simulation}, path::AbstractString)
    isempty(sims) && throw(ArgumentError("sims must not be empty"))
    T = maximum(length(s.history) for s in sims)
    n = length(sims[1])
    reached = fill(Float64(NaN), T, length(sims))
    for (j, s) in enumerate(sims)
        for h in s.history
            reached[h.t + 1, j] = (n - h.susceptible) / n
        end
    end
    mu = vec(mean(reached; dims = 2))
    sd = vec(std(reached; dims = 2))
    ts = 0:(T - 1)
    fig = Figure(; size = (900, 500))
    ax = Axis(fig[1, 1]; xlabel = "time step", ylabel = "fraction reached",
              title = "Cascade size, mean and 95% band (n = $(length(sims)) replications)")
    band!(ax, ts, max.(mu .- 1.96 .* sd, 0.0), mu .+ 1.96 .* sd; color = (:teal, 0.25))
    lines!(ax, ts, mu; color = :teal, linewidth = 2, label = "mean")
    ylims!(ax, 0, 1)
    axislegend(ax; position = :rb)
    save(path, fig)
    return fig
end

"""
    plot_seed_comparison(curves, path::AbstractString)

Overlay reaching curves for seeding strategies. `curves` is a vector of (label, Simulation) pairs.
"""
function plot_seed_comparison(curves, path::AbstractString)
    fig = Figure(; size = (900, 500))
    ax = Axis(fig[1, 1]; xlabel = "time step", ylabel = "fraction reached",
              title = "Seed strategy comparison")
    for (label, sim) in curves
        hdf = history_dataframe(sim)
        n = length(sim)
        lines!(ax, hdf.t, (n .- hdf.susceptible) ./ n; label = label, linewidth = 2)
    end
    ylims!(ax, 0, 1)
    axislegend(ax; position = :rb)
    save(path, fig)
    return fig
end

"""
    plot_factcheck_comparison(curves, path::AbstractString)

Overlay believer curves for fact-check timings. `curves` is a vector of (label, Simulation) pairs.
"""
function plot_factcheck_comparison(curves, path::AbstractString)
    fig = Figure(; size = (900, 500))
    ax = Axis(fig[1, 1]; xlabel = "time step", ylabel = "active believers",
              title = "Fact-check timing")
    for (label, sim) in curves
        hdf = history_dataframe(sim)
        lines!(ax, hdf.t, hdf.believer; label = label, linewidth = 2)
    end
    axislegend(ax; position = :rt)
    save(path, fig)
    return fig
end

"""
    plot_sweep_heatmap(df::DataFrame, xname::Symbol, yname::Symbol, path::AbstractString)

Heatmap of mean final_reach for a two-parameter sweep (see sweep2).
"""
function plot_sweep_heatmap(df::DataFrame, xname::Symbol, yname::Symbol, path::AbstractString)
    xs = sort!(unique(df[!, xname]))
    ys = sort!(unique(df[!, yname]))
    Z = fill(Float64(NaN), length(ys), length(xs))
    for row in eachrow(df)
        ix = searchsortedfirst(xs, row[xname])
        iy = searchsortedfirst(ys, row[yname])
        Z[iy, ix] = row.final_reach
    end
    fig = Figure(; size = (800, 600))
    ax = Axis(fig[1, 1]; xlabel = String(xname), ylabel = String(yname),
              title = "Mean final reach")
    hm = heatmap!(ax, 1:length(xs), 1:length(ys), Z; colormap = :viridis)
    ax.xticks = (1:length(xs), string.(xs))
    ax.yticks = (1:length(ys), string.(ys))
    Colorbar(fig[1, 2], hm; label = "final reach")
    save(path, fig)
    return fig
end

# Deterministic radial layout: BFS from the first seed, layers at increasing radius.
function _radial_positions(adj::Vector{Vector{Int32}}, seed::Integer)
    n = length(adj)
    depth = fill(-1, n)
    depth[seed] = 0
    q = Int[seed]
    head = 1
    while head <= length(q)
        cur = q[head]; head += 1
        for nb in adj[cur]
            if depth[nb] == -1
                depth[nb] = depth[cur] + 1
                push!(q, nb)
            end
        end
    end
    maxd = maximum(depth)
    pos = Vector{Point2f}(undef, n)
    per_layer = Dict{Int, Vector{Int}}()
    for i in 1:n
        d = depth[i] < 0 ? maxd + 1 : depth[i]
        push!(get!(per_layer, d, Int[]), i)
    end
    for (d, members) in per_layer
        r = d / (maxd + 2)
        if d == 0
            pos[members[1]] = Point2f(0.0, 0.0)
            continue
        end
        for (j, member) in enumerate(members)
            ang = 2 * pi * (j - 1) / length(members)
            pos[member] = Point2f(r * cos(ang), r * sin(ang))
        end
    end
    return pos
end

function _to_graph(adj::Vector{Vector{Int32}})
    g = SimpleGraph(length(adj))
    for (u, nbs) in enumerate(adj)
        for v in nbs
            u < v && add_edge!(g, u, v)
        end
    end
    return g
end

"""
    animate_gif(sim::Simulation, path::AbstractString; fps=12, stride=1, seed_pos=1)

Animated GIF of the network with node colors encoding state. The simulation must have
been run with `record_trace=true` (see run_simulation). Saves to `path`.
`stride` records every `stride`-th step to keep the file small.
"""
function animate_gif(sim::Simulation, path::AbstractString; fps::Integer = 12,
                     stride::Integer = 1, seed_pos::Integer = 1)
    isempty(sim.trace) && throw(ArgumentError("simulation has no state trace; run with record_trace=true"))
    adj = sim.adj
    n = length(adj)
    pos = _radial_positions(adj, seed_pos)
    g = _to_graph(adj)

    color_obs = Observable([STATE_COLORS[s] for s in sim.trace[1]])
    fig = Figure(; size = (700, 700), backgroundcolor = :transparent)
    ax = Axis(fig[1, 1]; aspect = DataAspect())
    hidedecorations!(ax)
    hidespines!(ax)
    graphplot!(ax, g; node_positions = pos, node_color = color_obs,
               node_size = fill(12.0, n), edge_width = 0.4, edge_color = (:gray, 0.35))

    frames = 0:stride:(length(sim.trace) - 1)
    record(fig, path, frames; framerate = fps) do frame
        color_obs[] = [STATE_COLORS[s] for s in sim.trace[frame + 1]]
        ax.title = "Cascade, t = $frame"
    end
    return fig
end
