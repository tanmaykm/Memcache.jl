using Memcache
using Compat


function test_begin()
    mc = MemcacheClient()
    mc.debug = true

    st = stats(mc)
    @assert st["version"] == version(mc)

    flush_all(mc)

    st = stats(mc, "settings")
    @assert st["tcpport"] == "11211"

    mc
end

function test_end(mc)
    flush_all(mc)

    st = stats(mc)
    @assert parse(Int, st["get_hits"]) > 0

    @assert length(stats(mc, "items")) >= 0
    @assert length(stats(mc, "sizes")) >= 0
    @assert parse(Int, stats(mc, "slabs")["active_slabs"]) >= 0

    # commented out to avoid julia issue #5793
    #close(mc)
    nothing
end

function test_set_get(mc)
    set(mc, "key1", "val1")
    @assert get(mc, "key1") == "val1"

    set(mc, "key2", "val2")
    res = get(mc, "key1", "key2") 
    @assert res["key1"] == "val1"
    @assert res["key2"] == "val2"

    delete(mc, "key1")
    res = get(mc, "key1", "key2")
    @assert collect(keys(res)) == ["key2"]
end

function test_touch(mc)
    set(mc, "touch_key1", "touch_val1", exptime=2)
    set(mc, "touch_key2", "touch_val2", exptime=1000)
    sleep(3)
    res = get(mc, "touch_key1", "touch_key2")
    @assert collect(keys(res)) == ["touch_key2"]

    touch(mc, "touch_key2", 2)
    set(mc, "touch_key1", "touch_val1", exptime=1000)
    sleep(3)
    res = get(mc, "touch_key1", "touch_key2")
    @assert collect(keys(res)) == ["touch_key1"]
end

function test_incr_decr(mc)
    set(mc, "num1", 1)
    incr(mc, "num1", 5)
    @assert get(mc, "num1") == 6

    decr(mc, "num1", 2)
    @assert get(mc, "num1") == 4
end

function test_cas(mc)
    set(mc, "cas_key", 1)
    res = get(mc, "cas_key", cas=true)
    val,casval = res["cas_key"]
    @assert val == 1

    cas(mc, "cas_key", 2, casval)
    res = get(mc, "cas_key", cas=true)
    val,casval2 = res["cas_key"]
    @assert val == 2
    @assert casval != casval2

    @assert false == try cas(mc, "cas_key", 3, casval); true; catch; false; end
end

type mytype
    i::Int
    s::AbstractString
    k::Dict
end

function test_julia_type(mc)
    t = mytype(10, "hello", @compat(Dict(1=>"A", 2=>"B")))
    set(mc, "jul", t)
    t1 = get(mc, "jul")
    @assert t.i == t1.i
    @assert t.s == t1.s
    @assert t.k == t1.k
end

mc = test_begin()
println("began test")

test_set_get(mc)
println("tested set get")

test_touch(mc)
println("tested touch")

test_incr_decr(mc)
println("tested incr decr")

test_cas(mc)
println("tested cas")

test_julia_type(mc)
println("tested julia type")

test_end(mc)
println("end of test")

exit()

