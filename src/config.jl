# TOML configuration loading.
#
# Schema (see config/default.toml):
#   [network] kind, n, p, k, ws_beta, sizes, probs
#   [params]  beta, forget_rate, literacy_boost, factcheck_time, factcheck_reach, block_top_k
#   [run]     seed, strategy, m_seeds, steps

function load_config(path::AbstractString)
    isfile(path) || throw(ArgumentError("config file not found: $path"))
    raw = TOML.parsefile(path)

    netcfg = get(raw, "network", Dict{String, Any}())
    kind = Symbol(get(netcfg, "kind", "barabasi_albert"))
    spec = if kind === :erdos_renyi
        NetworkSpec(:erdos_renyi, Int(get(netcfg, "n", 1000)); p = Float64(get(netcfg, "p", 0.01)))
    elseif kind === :watts_strogatz
        NetworkSpec(:watts_strogatz, Int(get(netcfg, "n", 1000)); k = Int(get(netcfg, "k", 6)),
                    ws_beta = Float64(get(netcfg, "ws_beta", 0.1)))
    elseif kind === :barabasi_albert
        NetworkSpec(:barabasi_albert, Int(get(netcfg, "n", 1000)); k = Int(get(netcfg, "k", 4)))
    elseif kind === :sbm
        sizes = Vector{Int}(get(netcfg, "sizes", [500, 500]))
        probs_raw = get(netcfg, "probs", [[0.02, 0.002], [0.002, 0.02]])
        probs = reduce(vcat, [permutedims(Float64.(r)) for r in probs_raw])
        NetworkSpec(:sbm, sum(sizes); sizes = sizes, probs = probs)
    else
        throw(ArgumentError("unknown network kind in config: $kind"))
    end

    pcfg = get(raw, "params", Dict{String, Any}())
    ft = get(pcfg, "factcheck_time", nothing)
    factcheck_time = ft === nothing ? nothing : Int(ft)
    params = CascadeParams(;
        beta = Float64(get(pcfg, "beta", 0.08)),
        forget_rate = Float64(get(pcfg, "forget_rate", 0.05)),
        literacy_boost = Float64(get(pcfg, "literacy_boost", 0.0)),
        factcheck_time = factcheck_time,
        factcheck_reach = Float64(get(pcfg, "factcheck_reach", 0.5)),
        block_top_k = Int(get(pcfg, "block_top_k", 0)),
    )

    rcfg = get(raw, "run", Dict{String, Any}())
    seed = Int(get(rcfg, "seed", 42))
    strategy = Symbol(get(rcfg, "strategy", "random"))
    m_seeds = Int(get(rcfg, "m_seeds", 1))
    steps = Int(get(rcfg, "steps", 200))

    return (spec = spec, params = params, seed = seed, strategy = strategy,
            m_seeds = m_seeds, steps = steps)
end
