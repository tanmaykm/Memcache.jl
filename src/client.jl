mutable struct MemcacheClient
    host::AbstractString
    port::Integer
    sock::IO
    debug::Bool

    function MemcacheClient(host::AbstractString="localhost", port::Integer=11211)
        sock = connect(host, port)
        new(host, port, sock, false)
    end
end

close(mc::MemcacheClient) = close(mc.sock)
quit(mc::MemcacheClient) = mc_send(mc, "quit")

for f in ("set", "add", "replace", "append", "prepend")
    @eval ($(Symbol(f)))(mc::MemcacheClient, key::AbstractString, val; exptime::Integer=0, cas::Integer=-1, noreply::Bool=false) = _setval(mc, $f, key, val, exptime=exptime, cas=cas, noreply=noreply)
end

cas(mc::MemcacheClient, key::AbstractString, val, cas::Integer; exptime::Integer=0, noreply::Bool=false) = _setval(mc, "cas", key, val, exptime=exptime, cas=cas, noreply=noreply)

function _setval(mc::MemcacheClient, cmd::AbstractString, key::AbstractString, val; exptime::Integer=0, cas::Integer=-1, noreply::Bool=false)
    flags, buff = mc_serialize(val)
    args = [key, flags, exptime, length(buff)]
    (cas != -1) && push!(args, cas)
    noreply && push!(args, "noreply")

    mc_send(mc, cmd, args...)
    mc_send(mc, buff)

    resp_line = validate(mc_recv(mc), "STORED", "NOT_STORED", "EXISTS", "NOT_FOUND")
    (resp_line[1] == "STORED") && return
    error(resp_line[1])
end

function get(mc::MemcacheClient, key::AbstractString)
    mc_send(mc, "get", key)
    cont = true

    local result::Any = nothing
    result_found = false
    while cont
        resp_line = validate(mc_recv(mc), "VALUE", "END")
        if resp_line[1] == "VALUE"
            result_found = true
            kv = split(resp_line[2])
            flags = parse(Int, kv[2])
            bytes = parse(Int, kv[3])
            result = mc_deserialize(mc_recv(mc, bytes), flags)
        else
            cont = false
        end
    end
    result_found ? result : error("NOT_FOUND")
end

function get(mc::MemcacheClient, key::AbstractString...; cas::Bool=false)
    c = (cas != nothing) ? "gets" : "get"
    mc_send(mc, c, key...)

    cont = true
    result = Dict{AbstractString,Any}()
    while cont
        resp_line = validate(mc_recv(mc), "VALUE", "END")
        if resp_line[1] == "VALUE"
            kv = split(resp_line[2])
            key = kv[1]
            flags = parse(Int, kv[2])
            bytes = parse(Int, kv[3])
            casval = cas ? parse(Int, kv[4]) : 0
            val = mc_deserialize(mc_recv(mc, bytes), flags)
    
            result[key] = cas ? (val, casval) : val
        else
            cont = false
        end
    end
    result
end

function delete(mc::MemcacheClient, key::AbstractString; noreply::Bool=false)
    mc_send(mc, "delete", key, noreply ? "noreply" : nothing)
    noreply && return
    resp_line = validate(mc_recv(mc), "DELETED", "NOT_FOUND")
    (resp_line[1] == "NOT_FOUND") && error(resp_line[1])
    nothing
end

incr(mc::MemcacheClient, key::AbstractString, val::Integer; noreply::Bool=false) = incr_decr(mc, "incr", key, val, noreply=noreply)
decr(mc::MemcacheClient, key::AbstractString, val::Integer; noreply::Bool=false) = incr_decr(mc, "decr", key, val, noreply=noreply)
function incr_decr(mc::MemcacheClient, c::AbstractString, key::AbstractString, val::Integer; noreply::Bool=false)
    mc_send(mc, c, key, val, noreply ? "noreply" : nothing)
    noreply && return
    resp_line = mc_recv(mc)
    (resp_line[1] == "NOT_FOUND") && error(resp_line[1])
    parse(Int, resp_line[1])
end

function touch(mc::MemcacheClient, key::AbstractString, exp::Integer; noreply::Bool=false)
    mc_send(mc, "touch", key, exp, noreply ? "noreply" : nothing) 
    noreply && return
    resp_line = validate(mc_recv(mc), "TOUCHED", "NOT_FOUND")
    (resp_line[1] == "NOT_FOUND") && error(resp_line[1])
    nothing
end

function flush_all(mc::MemcacheClient, delay::Integer=0; noreply::Bool=false)
    mc_send(mc, "flush_all", (delay > 0) ? delay : nothing)
    !noreply && validate(mc_recv(mc), "OK")
    nothing
end

function stats(mc::MemcacheClient, args...)
    mc_send(mc, "stats", args...)

    result = Dict{AbstractString, AbstractString}()
    
    cont = true
    while cont
        resp_line = validate(mc_recv(mc), "STAT", "END")
        if resp_line[1] == "STAT"
            kv = split(resp_line[2])
            result[kv[1]] = kv[2]
        else
            cont = false
        end
    end
    result
end

function version(mc::MemcacheClient)
    mc_send(mc, "version")
    validate(mc_recv(mc), "VERSION")[2]
end

function slabs_reassign(mc::MemcacheClient, src::Integer, dst::Integer)
    mc_send(mc, "slabs", "reassign", src, dst)
    resp_line = validate(mc_recv(mc), "OK", "BUSY", "BADCLASS", "NOSPARE", "NOTFULL", "UNSAFE", "SAME")
    (resp_line[1] == "OK") && return
    error(join(resp_line, ':'))
end

function slabs_automove(mc::MemcacheClient, mode::Integer)
    !(mode in [0, 1, 2]) && error("invalid mode $mode")
    mc_send(mc, "slabs", "automove", mode)
    validate(mc_recv(mc), "OK")
    nothing
end


##
# serialize and deserialize
# plain ascii format for numbers and strings so that they are interoperable with other implementations.
# julia serialization for other types.
const ser_pipe = PipeBuffer()
mc_serialize(val) = (mc_serialize(ser_pipe, val), take!(ser_pipe))
mc_serialize(s, val) = (serialize(s, val); 0)
mc_serialize(s, val::T) where T <: Integer = (print(s, val); 1)
mc_serialize(s, val::T) where T <: AbstractFloat = (print(s, val); 2)
mc_serialize(s, val::T) where T <: AbstractString = (print(s, val); 3)

function mc_deserialize(buff::Array{UInt8,1}, typ::Int)
    if 0 == typ
        return deserialize(IOBuffer(buff))
    elseif 1 == typ
        return parse(Int, String(buff))
    elseif 2 == typ
        return parse(Float64, String(buff))
    elseif 3 == typ
        return String(buff)
    end
    error("unknown data type $typ")
end


##
# memcache send/recv protocol
const CMD_DLM = "\r\n"

function mc_send(mc::MemcacheClient, cmd::AbstractString, args...)
    iob = IOBuffer()
    write(iob, cmd)
    for arg in args
        (arg == nothing) && continue
        write(iob, ' ')
        print(iob, arg)
    end
    write(iob, CMD_DLM)
    cmdline = take!(iob)
    write(mc.sock, cmdline)
    mc.debug && println("send: ", String(cmdline))
    nothing
end

function mc_send(mc::MemcacheClient, data::Array{UInt8})
    write(mc.sock, data)
    write(mc.sock, CMD_DLM)
    mc.debug && println("send: $(length(data)) bytes data")
    nothing
end

function mc_recv(mc::MemcacheClient)
    s = readline(mc.sock)
    mc.debug && println("recv: $s")
    s = rstrip(s)
    split(s, ' ', limit=2)
end

mc_recv(mc::MemcacheClient, len::Integer) = mc_recv(mc, Vector{UInt8}(undef, len))

function mc_recv(mc::MemcacheClient, data::Array{UInt8,1})
    read!(mc.sock, data)
    readline(mc.sock)
    mc.debug && println("recv: $(length(data)) bytes data")
    data
end

validate(resp::Array, valids...) = (resp[1] in valids) ? resp : error("unrecognized data from server: $(resp[1])")

