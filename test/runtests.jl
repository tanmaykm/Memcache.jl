using Memcache

if isless(Base.VERSION, v"0.7.0-")
using Base.Test
else
using Test
end

@test isa(Memcache, Module)

include("test.jl")
