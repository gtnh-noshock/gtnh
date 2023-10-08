-- rm v1.lua && wget http://192.168.5.102/mc/v1.lua && v1

coroutine.wrap(function()
    while true do
        print("111")
        wait(1)
    end
end)()

function wait(t)
    t = t or 0 -- default is 0 seconds
    local start = tick()
    local stop = start + t
    repeat coroutine.yield() until tick() > stop
    -- Return the time we waited + that second thingy of wait
    return tick() - start, tick() -- #2 isn't  tick(), but nobody knows
end
