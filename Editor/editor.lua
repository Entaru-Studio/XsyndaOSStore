local m = {}

function m.start(ctx)
    ctx = ctx or {}
    local args = ctx.args or {}
    local cwd = ctx.cwd or "/"

    if #args < 1 then
        term.clear()
        term.setCursorPos(1, 1)
        print("Usage: editor <path>")
        print("Press HOME to exit")
        while not (ctx.isClosed and ctx.isClosed()) do
            local ev = {os.pullEvent()}
            if ev[1] == "key" and keys.getName(ev[2]) == "home" then
                break
            end
        end
        term.clear()
        term.setCursorPos(1, 1)
        return
    end

    local sPath = args[1]
    if not sPath:match("^/") then
        sPath = fs.combine(cwd, sPath)
    end

    if not fs.exists(sPath) or fs.isDir(sPath) then
        term.clear()
        term.setCursorPos(1, 1)
        print("Cannot open: " .. sPath)
        print("Press HOME to exit")
        while not (ctx.isClosed and ctx.isClosed()) do
            local ev = {os.pullEvent()}
            if ev[1] == "key" and keys.getName(ev[2]) == "home" then
                break
            end
        end
        term.clear()
        term.setCursorPos(1, 1)
        return
    end

    local bReadOnly = fs.isReadOnly(sPath)

    local x, y = 1, 1
    local w, h = term.getSize()
    local scrollX, scrollY = 0, 0

    local tLines = {}
    local bRunning = true

    local bMenu = false
    local nMenuItem = 1
    local tMenuItems = {}
    if not bReadOnly then
        table.insert(tMenuItems, "Save")
    end
    if peripheral and peripheral.find and peripheral.find("printer") then
        table.insert(tMenuItems, "Print")
    end
    table.insert(tMenuItems, "Exit")

    local status_ok, status_text
    local function set_status(text, ok)
        status_ok = ok ~= false
        status_text = text
    end

    if not bReadOnly and fs.getFreeSpace(sPath) < 1024 then
        set_status("Disk is low on space", false)
    else
        local message
        if term.isColour() then
            message = "Press Ctrl or click here to access menu"
        else
            message = "Press Ctrl to access menu"
        end
        if #message > w - 5 then
            message = "Press Ctrl for menu"
        end
        set_status(message)
    end

    local function load(_sPath)
        tLines = {}
        local file = io.open(_sPath, "r")
        if file then
            local sLine = file:read()
            while sLine do
                table.insert(tLines, sLine)
                sLine = file:read()
            end
            file:close()
        end
        if #tLines == 0 then
            table.insert(tLines, "")
        end
    end

    local function save(_sPath, fWrite)
        local sDir = _sPath:sub(1, _sPath:len() - fs.getName(_sPath):len())
        if sDir ~= "" and not fs.exists(sDir) then
            fs.makeDir(sDir)
        end

        local file, fileerr
        local function innerSave()
            file, fileerr = fs.open(_sPath, "w")
            if file then
                fWrite(file)
            else
                error("Failed to open " .. _sPath)
            end
        end

        local ok, err = pcall(innerSave)
        if file then
            file.close()
        end
        return ok, err, fileerr
    end

    local function redrawText()
        for row = 1, h - 1 do
            term.setCursorPos(1, row)
            term.clearLine()
            local sLine = tLines[row + scrollY]
            if sLine ~= nil then
                term.write(sLine)
            end
        end
        term.setCursorPos(x - scrollX, y - scrollY)
    end

    local function redrawLine(_nY)
        local sLine = tLines[_nY]
        if sLine then
            term.setCursorPos(1, _nY - scrollY)
            term.clearLine()
            term.write(sLine)
            term.setCursorPos(x - scrollX, _nY - scrollY)
        end
    end

    local function redrawMenu()
        term.setCursorPos(1, h)
        term.clearLine()

        term.setCursorPos(w - #("Ln " .. y) + 1, h)
        term.write("Ln " .. y)

        term.setCursorPos(1, h)
        if bMenu then
            for nItem, sItem in ipairs(tMenuItems) do
                if nItem == nMenuItem then
                    term.write("[" .. sItem .. "]")
                else
                    term.write(" " .. sItem .. " ")
                end
            end
        else
            term.write(status_text or "")
        end

        term.setCursorPos(x - scrollX, y - scrollY)
    end

    local tMenuFuncs = {
        Save = function()
            if bReadOnly then
                set_status("Access denied", false)
            else
                local ok, _, fileerr = save(sPath, function(file)
                    for _, sLine in ipairs(tLines) do
                        file.write(sLine .. "\n")
                    end
                end)
                if ok then
                    set_status("Saved to " .. sPath)
                else
                    if fileerr then
                        set_status("Error saving: " .. fileerr, false)
                    else
                        set_status("Error saving to " .. sPath, false)
                    end
                end
            end
            redrawMenu()
        end,

        Print = function()
            local printer = peripheral and peripheral.find and peripheral.find("printer")
            if not printer then
                set_status("No printer attached", false)
                return
            end

            local nPage = 0
            local sName = fs.getName(sPath)
            if printer.getInkLevel() < 1 then
                set_status("Printer out of ink", false)
                return
            elseif printer.getPaperLevel() < 1 then
                set_status("Printer out of paper", false)
                return
            end

            local screenTerminal = term.current()
            local printerTerminal = {
                getCursorPos = printer.getCursorPos,
                setCursorPos = printer.setCursorPos,
                getSize = printer.getPageSize,
                write = printer.write,
            }
            printerTerminal.scroll = function()
                if nPage == 1 then
                    printer.setPageTitle(sName .. " (page " .. nPage .. ")")
                end
                while not printer.newPage() do
                    if printer.getInkLevel() < 1 then
                        set_status("Printer out of ink, please refill", false)
                    elseif printer.getPaperLevel() < 1 then
                        set_status("Printer out of paper, please refill", false)
                    else
                        set_status("Printer output tray full, please empty", false)
                    end
                    term.redirect(screenTerminal)
                    redrawMenu()
                    term.redirect(printerTerminal)
                    sleep(0.5)
                end
                nPage = nPage + 1
                if nPage == 1 then
                    printer.setPageTitle(sName)
                else
                    printer.setPageTitle(sName .. " (page " .. nPage .. ")")
                end
            end

            bMenu = false
            term.redirect(printerTerminal)
            local ok, error = pcall(function()
                term.scroll()
                for _, sLine in ipairs(tLines) do
                    print(sLine)
                end
            end)
            term.redirect(screenTerminal)
            if not ok then
                print(error)
            end

            while not printer.endPage() do
                set_status("Printer output tray full, please empty")
                redrawMenu()
                sleep(0.5)
            end
            bMenu = true

            if nPage > 1 then
                set_status("Printed " .. nPage .. " Pages")
            else
                set_status("Printed 1 Page")
            end
            redrawMenu()
        end,

        Exit = function()
            bRunning = false
        end,
    }

    local function doMenuItem(_n)
        local name = tMenuItems[_n]
        if name and tMenuFuncs[name] then
            tMenuFuncs[name]()
        end
        if bMenu then
            bMenu = false
            term.setCursorBlink(true)
        end
        redrawMenu()
    end

    local function setCursor(newX, newY)
        local oldY = y
        x, y = newX, newY
        local screenX = x - scrollX
        local screenY = y - scrollY

        local bRedraw = false
        if screenX < 1 then
            scrollX = x - 1
            screenX = 1
            bRedraw = true
        elseif screenX > w then
            scrollX = x - w
            screenX = w
            bRedraw = true
        end
        if screenY < 1 then
            scrollY = y - 1
            screenY = 1
            bRedraw = true
        elseif screenY > h - 1 then
            scrollY = y - (h - 1)
            screenY = h - 1
            bRedraw = true
        end

        if bRedraw then
            redrawText()
        elseif y ~= oldY then
            redrawLine(oldY)
            redrawLine(y)
        else
            redrawLine(y)
        end
        term.setCursorPos(screenX, screenY)
        redrawMenu()
    end

    load(sPath)

    term.clear()
    term.setCursorPos(x, y)
    term.setCursorBlink(true)

    redrawText()
    redrawMenu()

    while bRunning and not (ctx.isClosed and ctx.isClosed()) do
        local sEvent, param, param2, param3 = os.pullEvent()

        if sEvent == "key" then
            if param == keys.f1 then
                bRunning = false

            elseif param == keys.up then
                if not bMenu then
                    if y > 1 then
                        setCursor(math.min(x, #tLines[y - 1] + 1), y - 1)
                    end
                end

            elseif param == keys.down then
                if not bMenu then
                    if y < #tLines then
                        setCursor(math.min(x, #tLines[y + 1] + 1), y + 1)
                    end
                end

            elseif param == keys.tab then
                if not bMenu and not bReadOnly then
                    local sLine = tLines[y]
                    tLines[y] = string.sub(sLine, 1, x - 1) .. "    " .. string.sub(sLine, x)
                    setCursor(x + 4, y)
                end

            elseif param == keys.pageUp then
                if not bMenu then
                    local newY
                    if y - (h - 1) >= 1 then newY = y - (h - 1) else newY = 1 end
                    setCursor(math.min(x, #tLines[newY] + 1), newY)
                end

            elseif param == keys.pageDown then
                if not bMenu then
                    local newY
                    if y + (h - 1) <= #tLines then newY = y + (h - 1) else newY = #tLines end
                    setCursor(math.min(x, #tLines[newY] + 1), newY)
                end

            elseif param == keys["end"] then
                if not bMenu then
                    local nLimit = #tLines[y] + 1
                    if x < nLimit then setCursor(nLimit, y) end
                end

            elseif param == keys.left then
                if not bMenu then
                    if x > 1 then
                        setCursor(x - 1, y)
                    elseif x == 1 and y > 1 then
                        setCursor(#tLines[y - 1] + 1, y - 1)
                    end
                else
                    nMenuItem = nMenuItem - 1
                    if nMenuItem < 1 then nMenuItem = #tMenuItems end
                    redrawMenu()
                end

            elseif param == keys.right then
                if not bMenu then
                    local nLimit = #tLines[y] + 1
                    if x < nLimit then
                        setCursor(x + 1, y)
                    elseif x == nLimit and y < #tLines then
                        setCursor(1, y + 1)
                    end
                else
                    nMenuItem = nMenuItem + 1
                    if nMenuItem > #tMenuItems then nMenuItem = 1 end
                    redrawMenu()
                end

            elseif param == keys.delete then
                if not bMenu and not bReadOnly then
                    local nLimit = #tLines[y] + 1
                    if x < nLimit then
                        local sLine = tLines[y]
                        tLines[y] = string.sub(sLine, 1, x - 1) .. string.sub(sLine, x + 1)
                        redrawLine(y)
                    elseif y < #tLines then
                        tLines[y] = tLines[y] .. tLines[y + 1]
                        table.remove(tLines, y + 1)
                        redrawText()
                    end
                end

            elseif param == keys.backspace then
                if not bMenu and not bReadOnly then
                    if x > 1 then
                        local sLine = tLines[y]
                        if x > 4 and string.sub(sLine, x - 4, x - 1) == "    " and not string.sub(sLine, 1, x - 1):find("%S") then
                            tLines[y] = string.sub(sLine, 1, x - 5) .. string.sub(sLine, x)
                            setCursor(x - 4, y)
                        else
                            tLines[y] = string.sub(sLine, 1, x - 2) .. string.sub(sLine, x)
                            setCursor(x - 1, y)
                        end
                    elseif y > 1 then
                        local sPrevLen = #tLines[y - 1]
                        tLines[y - 1] = tLines[y - 1] .. tLines[y]
                        table.remove(tLines, y)
                        setCursor(sPrevLen + 1, y - 1)
                        redrawText()
                    end
                end

            elseif param == keys.enter or param == keys.numPadEnter then
                if not bMenu and not bReadOnly then
                    local sLine = tLines[y]
                    local _, spaces = string.find(sLine, "^[ ]+")
                    if not spaces then spaces = 0 end
                    tLines[y] = string.sub(sLine, 1, x - 1)
                    table.insert(tLines, y + 1, string.rep(' ', spaces) .. string.sub(sLine, x))
                    setCursor(spaces + 1, y + 1)
                    redrawText()
                elseif bMenu then
                    doMenuItem(nMenuItem)
                end

            elseif param == keys.leftCtrl or param == keys.rightCtrl then
                bMenu = not bMenu
                term.setCursorBlink(not bMenu)
                redrawMenu()

            elseif param == keys.rightAlt then
                if bMenu then
                    bMenu = false
                    term.setCursorBlink(true)
                    redrawMenu()
                end
            end

        elseif sEvent == "char" then
            if not bMenu and not bReadOnly then
                local sLine = tLines[y]
                tLines[y] = string.sub(sLine, 1, x - 1) .. param .. string.sub(sLine, x)
                setCursor(x + 1, y)
            elseif bMenu then
                for n, sMenuItem in ipairs(tMenuItems) do
                    if string.lower(string.sub(sMenuItem, 1, 1)) == string.lower(param) then
                        doMenuItem(n)
                        break
                    end
                end
            end

        elseif sEvent == "paste" then
            if not bReadOnly then
                if bMenu then
                    bMenu = false
                    term.setCursorBlink(true)
                    redrawMenu()
                end
                local sLine = tLines[y]
                tLines[y] = string.sub(sLine, 1, x - 1) .. param .. string.sub(sLine, x)
                setCursor(x + #param, y)
            end

        elseif sEvent == "mouse_click" then
            local cx, cy = param2, param3
            if not bMenu then
                if param == 1 then
                    if cy < h then
                        local newY = math.min(math.max(scrollY + cy, 1), #tLines)
                        local newX = math.min(math.max(scrollX + cx, 1), #tLines[newY] + 1)
                        setCursor(newX, newY)
                    else
                        bMenu = true
                        redrawMenu()
                    end
                end
            else
                if cy == h then
                    local nMenuPosEnd = 1
                    local nMenuPosStart = 1
                    for n, sMenuItem in ipairs(tMenuItems) do
                        nMenuPosEnd = nMenuPosEnd + #sMenuItem + 1
                        if cx > nMenuPosStart and cx < nMenuPosEnd then
                            doMenuItem(n)
                        end
                        nMenuPosEnd = nMenuPosEnd + 1
                        nMenuPosStart = nMenuPosEnd
                    end
                else
                    bMenu = false
                    term.setCursorBlink(true)
                    redrawMenu()
                end
            end

        elseif sEvent == "mouse_scroll" then
            if not bMenu then
                if param == -1 then
                    if scrollY > 0 then
                        scrollY = scrollY - 1
                        redrawText()
                    end
                elseif param == 1 then
                    local nMaxScroll = #tLines - (h - 1)
                    if scrollY < nMaxScroll then
                        scrollY = scrollY + 1
                        redrawText()
                    end
                end
            end

        elseif sEvent == "term_resize" then
            w, h = term.getSize()
            setCursor(x, y)
            redrawMenu()
            redrawText()
        end
    end

    term.setCursorBlink(false)
    term.clear()
    term.setCursorPos(1, 1)
end

return m
