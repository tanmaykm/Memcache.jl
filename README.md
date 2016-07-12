# Julia Memcache Client

[![Build Status](https://travis-ci.org/tanmaykm/Memcache.jl.png)](https://travis-ci.org/tanmaykm/Memcache.jl)
[![Coverage Status](https://coveralls.io/repos/github/tanmaykm/Memcache.jl/badge.svg?branch=master)](https://coveralls.io/github/tanmaykm/Memcache.jl?branch=master)

A pure Julia client for memcached servers. All [memcached commands](https://github.com/memcached/memcached/wiki/Commands) as of memcached version 1.4.17 are implemented.

Both numbers and strings are stored in plain string format so as to be interoperable with other memcached client libraries. Other Julia types are stored in their serialized form.

Type `MemcacheClient` represents a connection to a single memcached server instance.

Type `MemcacheClients` wraps over multiple `MemcacheClient` instances to provide distributed cache across more than one memcached server instances. Operations are routed to appropriate server based on key hash value.


### Methods
- Setting and getting data: `set`, `cas`, `add`, `replace`, `append`, `prepend`, `incr`, `decr`, `get`, `touch`
- Administration: `stats`, `version`, `flush_all`, `close`, `slabs_reassign`, `slabs_automove`, `quit`

All methods are supported for both `MemcacheClient` and `MemcacheClients`, but results of administration commands would return and array of responses from all servers. See memcached command documentation for details of administration commands. 

Below is an illustration of using the most common commands.

````julia
julia> using Memcache

julia> # create a client connection

julia> mc = MemcacheClient("localhost", 11211);

julia> 

julia> # simple set and get

julia> set(mc, "key1", "val1")

julia> set(mc, "key2", 2)

julia> get(mc, "key1")
"val1"

julia> 

julia> # multi get

julia> get(mc, "key1", "key2")
["key1"=>"val1","key2"=>2]

julia> 

julia> # increment, decrement

julia> incr(mc, "key2", 8)
10

julia> decr(mc, "key2", 3)
7

julia> 

julia> # append, prepend

julia> append(mc, "key1", "--")

julia> prepend(mc, "key1", "--")

julia> get(mc, "key1")
"--val1--"

julia> 

julia> # cas

julia> res = get(mc, "key1", cas=true)
["key1"=>("--val1--",40)]

julia> val,casval = res["key1"]
("--val1--",40)

julia> cas(mc, "key1", 2, casval)

julia> get(mc, "key1")
2
````



### TODO
- compression
- optimize multi get for `MemcacheClients`

