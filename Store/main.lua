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

    local edata = ctx.edata

    local wot = function(text, x, y)
        term.setCursorPos(x, y)
        term.write(text)
    end
    local function split(str, sep)
        local result = {}
        if sep == nil or sep == "" then
            for word in string.gmatch(str, "%S+") do
                table.insert(result, word)
            end
        else
            local pattern = "([^" .. sep:gsub("%p", "%%%0") .. "]+)"
            for word in string.gmatch(str, pattern) do
                table.insert(result, word)
            end
        end
        return result
    end

    local storeApps = textutils.unserializeJSON(http.get("https://raw.githubusercontent.com/Entaru-Studio/XsyndaOSStore/refs/heads/main/store.json").readAll())

    local url = "https://raw.githubusercontent.com/Entaru-Studio/XsyndaOSStore/refs/heads/main/"

    local scrollOffsetY = 0
    local currentString = 1

    local history = {}

    for i, v in ipairs(storeApps) do
        wot(v.name .. " | Version " .. v.version, 1, currentString+scrollOffsetY)
        history[currentString] = v

        currentString = currentString + 1
    end

    --print(storeApps)

    local function redraw()
        term.clear()
        currentString = 1
        for i, v in ipairs(history) do
            wot(v.name .. " | Version " .. v.version, 1, currentString+scrollOffsetY)
            currentString = currentString + 1
        end
    end

    local function mainLoop()
        while true do
            local eventData = {os.pullEvent()}
            local event = eventData[1]

            if event == "mouse_scroll" then
                if eventData[2] == 1 then
                    if (math.abs(scrollOffsetY)+_H) < #history then
                        scrollOffsetY = scrollOffsetY - 1
                        redraw()
                    end
                elseif eventData[2] == 0 and math.abs(scrollOffsetY) >= 1 then
                    scrollOffsetY = scrollOffsetY + 1
                    redraw()
                end
            elseif event == "mouse_click" then
                local y = eventData[4]

                local selectedApp = history[y+scrollOffsetY]
                if selectedApp then
                    local selectedAppPath = split(selectedApp.path, "/")
                    wot(selectedApp.name .. " | Version " .. selectedApp.version .. " | Installed!", 1, y+scrollOffsetY)
                    fs.makeDir("users/" .. ctx.currentProfile .. "/apps/" .. selectedAppPath[1])
                    edata.write("users/" .. ctx.currentProfile .. "/apps/" .. selectedAppPath[1] .. "/main.lua" , http.get(url .. selectedApp.path).readAll(), 1, "")
                    sleep(0.5)
                    redraw()
                end
            end

            sleep(0.05)
        end
    end

    parallel.waitForAny(endLoop, mainLoop)
end

return m