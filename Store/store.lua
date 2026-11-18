local m = {}

function m.start(ctx)
    local function endLoop()
        while not ctx.isClosed() do
            local ev = {os.pullEvent()}
            if ev[1] == "key" and keys.getName(ev[2]) == "home" then
                ctx.close()
            end
        end 
        term.clear()
        term.setCursorPos(1, 1)
    end

    local wot = function(text, x, y)
        term.setCursorPos(x, y)
        term.write(text)
    end

    

    parallel.waitForAny(endLoop)
end

return m
