struct MemcacheClients
    clients::Vector{MemcacheClient}

    function MemcacheClients(clients::Vector{MemcacheClient}=MemcacheClient[])
        new(clients)
    end
end

add_client(dmc::MemcacheClients, host::AbstractString, port::Integer=11211) = (push!(dmc.clients, MemcacheClient(host, port)); nothing)

for f in [:close, :quit, :flush_all, :slabs_automove, :slabs_reassign]
    @eval ($f)(dmc::MemcacheClients, args...) = (map(c->($f)(c, args...), dmc.clients); nothing)
end

for f in [:stats, :version]
    @eval ($f)(dmc::MemcacheClients, args...) = map(c->($f)(c, args...), dmc.clients)
end

mc(dmc::MemcacheClients, key::AbstractString) = dmc.clients[(hash(key) % length(dmc.clients)) + 1]
touch(dmc::MemcacheClients, key::AbstractString, exp::Integer; noreply::Bool=false) = touch(mc(dmc,key), key, exp, noreply=noreply)

for f in [:set, :add, :replace, :append, :prepend]
    @eval ($f)(dmc::MemcacheClients, key::AbstractString, val; exptime::Integer=0, cas::Integer=-1, noreply::Bool=false) = ($f)(mc(dmc,key), key, val; exptime=exptime, cas=cas, noreply=noreply)
end

cas(dmc::MemcacheClients, key::AbstractString, val, cas::Integer; exptime::Integer=0, noreply::Bool=false) = cas(mc(dmc,key), key, val, cas; exptime=exptime, noreply=noreply)

get(dmc::MemcacheClients, key::AbstractString) = get(mc(dmc,key), key)
get(dmc::MemcacheClients, key::AbstractString...; cas::Bool=false) = merge(map(c->get(c, key...; cas=cas), dmc.clients)...)
delete(dmc::MemcacheClients, key::AbstractString; noreply::Bool=false) = delete(mc(dmc,key), key, noreply=noreply)

incr(dmc::MemcacheClients, key::AbstractString, val::Integer; noreply::Bool=false) = incr(mc(dmc,key), key, val, noreply=noreply)
decr(dmc::MemcacheClients, key::AbstractString, val::Integer; noreply::Bool=false) = decr(mc(dmc,key), key, val, noreply=noreply)

