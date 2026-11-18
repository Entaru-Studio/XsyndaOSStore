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

    local currentPage = 1
    local selectedPage = 1
    local currentStroka = 1

    local history = {{}}

    for i, v in ipairs(storeApps) do
        if currentStroka <= ctx.height then
            wot(v.name .. " | Version " .. v.version, 1, currentStroka)
            history[currentPage][currentStroka] = v

            currentStroka = currentStroka + 1
        else
            term.clear()
            currentStroka = 1
            currentPage = currentPage + 1
            history[currentPage] = {}
            selectedPage = currentPage
        end
    end

    --print(storeApps)

    local function redraw()
        term.clear()
        for i, v in ipairs(history[selectedPage]) do
            wot(v.name .. " | Version " .. v.version, 1, i)
        end
    end

    local function mainLoop()
        while true do
            local eventData = {os.pullEvent()}
            local event = eventData[1]

            if event == "mouse_scroll" then
                if eventData[2] == 1 then
                    -- down
                    if selectedPage < currentPage then
                        selectedPage = selectedPage + 1
                        redraw()
                    end
                else
                    -- up
                    if selectedPage > 1 then
                        selectedPage = selectedPage - 1
                        redraw()
                    end
                end
            elseif event == "mouse_click" then
                local y = eventData[4]

                local selectedApp = history[selectedPage][y]
                if selectedApp then
                    local selectedAppPath = split(selectedApp.path, "/")[#split(selectedApp.path, "/")]
                    edata.write(selectedAppPath, http.get(url .. selectedApp.path).readAll(), 1, "user")
                end
            end

            sleep(0.05)
        end
    end

    parallel.waitForAny(endLoop, mainLoop)
end

return m
