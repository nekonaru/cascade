# Synthetic network generators.
#
# All generators take an explicit StableRNG so results are reproducible.
# Each returns a NetworkResult: the adjacency list (neighbors sorted for
# deterministic iteration order), degree vector and community labels.

struct NetworkResult
    adj::Vector{Vector{Int32}}       # adjacency list, 1-based node ids
    degree::Vector{Int32}
    communities::Vector{Int32}       # community id per node (components or SBM blocks)
    kind::Symbol
    n::Int
end

Base.length(net::NetworkResult) = net.n

struct NetworkSpec
    kind::Symbol                     # :erdos_renyi, :watts_strogatz, :barabasi_albert, :sbm
    n::Int
    # Erdős-Rényi: p; Watts-Strogatz: (k, beta); Barabási-Albert: (k); SBM: (sizes, probs)
    p::Float64
    k::Int
    ws_beta::Float64
    sizes::Vector{Int}
    probs::Matrix{Float64}
end

NetworkSpec(kind::Symbol, n::Int; p::Float64 = 0.0, k::Int = 4, ws_beta::Float64 = 0.1,
            sizes::Vector{Int} = Int[], probs::Matrix{Float64} = Matrix{Float64}(undef, 0, 0)) =
    NetworkSpec(kind, n, p, k, ws_beta, sizes, probs)

function _communities_from_components(g::SimpleGraph)
    comp = zeros(Int32, nv(g))
    cid = 0
    for v in 1:nv(g)
        comp[v] != 0 && continue
        cid += 1
        stack = Int[v]
        comp[v] = Int32(cid)
        while !isempty(stack)
            cur = pop!(stack)
            for nb in neighbors(g, cur)
                if comp[nb] == 0
                    comp[nb] = Int32(cid)
                    push!(stack, nb)
                end
            end
        end
    end
    return comp
end

function _adj_from_graph(g::SimpleGraph)
    adj = [Int32.(sort(neighbors(g, v))) for v in 1:nv(g)]
    return adj
end

function _degree_from_adj(adj::Vector{Vector{Int32}})
    Int32[length(a) for a in adj]
end

function network_erdos_renyi(n::Int, p::Float64; rng::AbstractRNG)
    n >= 2 || throw(ArgumentError("n must be >= 2, got $n"))
    0.0 <= p <= 1.0 || throw(ArgumentError("p must be in [0, 1], got $p"))
    g = erdos_renyi(n, p; rng = rng)
    adj = _adj_from_graph(g)
    return NetworkResult(adj, _degree_from_adj(adj), _communities_from_components(g), :erdos_renyi, n)
end

function network_watts_strogatz(n::Int, k::Int, ws_beta::Float64; rng::AbstractRNG)
    n >= 3 || throw(ArgumentError("n must be >= 3, got $n"))
    iseven(k) || throw(ArgumentError("k must be even for Watts-Strogatz, got $k"))
    1 <= k < n || throw(ArgumentError("k must satisfy 1 <= k < n, got k=$k, n=$n"))
    0.0 <= ws_beta <= 1.0 || throw(ArgumentError("ws_beta must be in [0, 1], got $ws_beta"))
    g = watts_strogatz(n, k, ws_beta; rng=rng)
    adj = _adj_from_graph(g)
    return NetworkResult(adj, _degree_from_adj(adj), _communities_from_components(g), :watts_strogatz, n)
end

function network_barabasi_albert(n::Int, k::Int; rng::AbstractRNG)
    n >= 2 || throw(ArgumentError("n must be >= 2, got $n"))
    1 <= k < n || throw(ArgumentError("k must satisfy 1 <= k < n, got k=$k, n=$n"))
    g = barabasi_albert(n, k; rng = rng)
    adj = _adj_from_graph(g)
    return NetworkResult(adj, _degree_from_adj(adj), _communities_from_components(g), :barabasi_albert, n)
end

function network_stochastic_block_model(sizes::Vector{Int}, probs::Matrix{Float64}; rng::AbstractRNG)
    length(sizes) >= 2 || throw(ArgumentError("sizes must have at least 2 blocks"))
    all(s -> s >= 1, sizes) || throw(ArgumentError("each block must have at least 1 node"))
    B = length(sizes)
    size(probs) == (B, B) || throw(ArgumentError("probs must be $B x $B, got $(size(probs))"))
    all(0.0 .<= probs .<= 1.0) || throw(ArgumentError("probs entries must be in [0, 1]"))
    probs == probs' || throw(ArgumentError("probs must be symmetric (block-to-block connection probabilities)"))
    # Graphs.jl's stochastic_block_model takes mean neighbor counts, not probabilities:
    # c[a,b] = expected degree of a block-a node into block b = p[a,b] * sizes[b].
    # The diagonal can never exceed sizes[a] - 1, so clamp it to the achievable density
    # (a flat 1.0 would trip Graphs' own "mean degree" guard).
    c = probs .* reshape(Float64.(sizes), 1, :)
    for b in 1:B
        limit = (sizes[b] - 1) * (1.0 - 1e-9)
        c[b, b] = min(c[b, b], limit)
    end
    g = stochastic_block_model(c, sizes; rng = rng)
    n = nv(g)
    adj = _adj_from_graph(g)
    communities = Vector{Int32}(undef, n)
    idx = 1
    for (b, s) in enumerate(sizes)
        for _ in 1:s
            communities[idx] = Int32(b)
            idx += 1
        end
    end
    return NetworkResult(adj, _degree_from_adj(adj), communities, :sbm, n)
end

"""
    generate_network(spec::NetworkSpec; seed::Integer) -> NetworkResult

Generate a synthetic network from `spec` with an explicit seed.
"""
generate_network(spec::NetworkSpec; seed::Integer) = generate_network(spec, StableRNG(seed))

function generate_network(spec::NetworkSpec, rng::AbstractRNG)
    k = spec.kind
    if k === :erdos_renyi
        return network_erdos_renyi(spec.n, spec.p; rng=rng)
    elseif k === :watts_strogatz
        return network_watts_strogatz(spec.n, spec.k, spec.ws_beta; rng=rng)
    elseif k === :barabasi_albert
        return network_barabasi_albert(spec.n, spec.k; rng=rng)
    elseif k === :sbm
        return network_stochastic_block_model(spec.sizes, spec.probs; rng=rng)
    else
        throw(ArgumentError("unknown network kind: $k"))
    end
end
