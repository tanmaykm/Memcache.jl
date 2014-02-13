# Julia Memcache Client

[![Build Status](https://travis-ci.org/tanmaykm/Memcache.jl.png)](https://travis-ci.org/tanmaykm/Memcache.jl)

### Type MemcacheClient
A pure Julia client for memcached servers. All memcached commands [(https://code.google.com/p/memcached/wiki/NewCommands)](https://code.google.com/p/memcached/wiki/NewCommands) as of memcached version 1.4.17 are implemented.

Strings and numbers are stored in simple ASCII format to be interoperable with other client libraries. Any other julia type can be set as value as long as they are serializable.

### Type MemcacheClients
Wraps over multiple `MemcacheClient` instances to provide distributed cache. Operations are routed to appropriate server based on hash value of the key.

### Methods
- Setting and getting data: set, cas, add, replace, append, prepend, incr, decr, get, touch
- Administration: stats, version, flush\_all, close, slabs\_reassign, slabs\_automove, quit

Example:
````
julia> using Memcache

julia> mc = MemcacheClient("localhost", 11211)
MemcacheClient("localhost",11211,TcpSocket(open, 0 bytes waiting),false)

julia> set(mc, "num1", 1)

julia> incr(mc, "num1", 5)
6

julia> get(mc, "num1") 
6
````

### TODO
- compression
- optimize multi get for `MemcacheClients`

