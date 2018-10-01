module Memcache

using Sockets
using Serialization

import Base: close, touch, get, replace

export set, cas, add, replace, append, prepend, get, touch, incr, decr, delete
export MemcacheClient, stats, version, flush_all, close, slabs_reassign, slabs_automove, quit
export MemcacheClients
# not exporting add_client as it could unintentionally change hash distribution calculation in the middle of execution
#export add_client

include("client.jl")
include("multi.jl")

end # module
