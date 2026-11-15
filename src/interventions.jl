# Seed selection strategies.
#
# Interventions are expressed as CascadeParams fields (literacy_boost,
# factcheck_time, factcheck_reach, block_top_k) and applied inside the model;
# this file only handles choosing the initial seed nodes.

"""
    seed_nodes(net::NetworkResult, strategy; m, rng) -> Vector{Int}

Pick `m` distinct seed nodes for `strategy`:
- `:random`     uniform at random
- `:hub`        `m` highest-degree nodes (ties broken by lower id, deterministic)
- `:community`  round-robin across communities (largest-first), so each community is seeded first
"""
function seed_nodes(net::NetworkResult, strategy::Symbol; m::Integer, rng::AbstractRNG)
    n = net.n
    m >= 1 || throw(ArgumentError("m must be >= 1, got $m"))
    m <= n || throw(ArgumentError("m must be <= n ($n), got $m"))

    if strategy === :random
        # deterministic partial Fisher-Yates shuffle using the provided rng
        idx = collect(1:n)
        for i in 1:m
            j = i + rand(rng, 0:(n - i))
            idx[i], idx[j] = idx[j], idx[i]
        end
        return sort!(idx[1:m])
    elseif strategy === :hub
        ranked = sortperm(1:n; by = i -> (-net.degree[i], i))
        return sort!(ranked[1:m])
    elseif strategy === :community
        bycomm = Dict{Int32, Vector{Int}}()
        for i in 1:n
            c = net.communities[i]
            push!(get!(bycomm, c, Int[]), i)
        end
        blocks = sort(collect(values(bycomm)); by = b -> (-length(b), minimum(b)))
        seeds = Int[]
        round = 0
        while length(seeds) < m
            added = false
            for block in blocks
                if round + 1 <= length(block)
                    push!(seeds, block[round + 1])
                    added = true
                    length(seeds) == m && break
                end
            end
            added || break
            round += 1
        end
        return sort!(seeds)
    else
        throw(ArgumentError("unknown seed strategy: $strategy (use :random, :hub or :community)"))
    end
end
