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

    wot("Checking updates...", 1, 1)

    local updateData = textutils.unserializeJSON(http.get("https://raw.githubusercontent.com/Entaru-Studio/XsyndaOS/refs/heads/main/updates.json").readAll())
    if updateData.version > ctx.sysVer then
        wot("The new update is available", 1, 3)
        wot("Do you want to install it?", 1, 4)

        wot("Press \"1\" for install", 1, 6)
        wot("Press \"Home\" for cancel", 1, 7)
    end
    local function chooseLoop()
        while true do
            local ev = {os.pullEvent()}
            if ev[1] == "key" then
                local key = keys.getName(ev[2])

                if key == "one" then
                    local edata = loadstring(http.get("https://raw.githubusercontent.com/Entaru-Studio/XsyndaOS/refs/heads/main/sys/edata.lua").readAll())()

                    edata.write("install.lua", http.get("https://raw.githubusercontent.com/Entaru-Studio/XsyndaOS/refs/heads/main/install.lua").readAll(), 1, "")
                    edata.write("startup.lua", "shell.run(\"install.lua\")")

                    wot("Update is downloaded. Rebooting for install...", 1, 9)
                    sleep(3)
                    os.reboot()
                end
            end
            sleep(0.05)
        end
    end

    parallel.waitForAny(endLoop, chooseLoop)
end

return m
