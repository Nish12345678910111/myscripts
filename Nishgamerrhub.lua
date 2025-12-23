-- Nishgamer Hub — Full Single-File LocalScript (Start Closed toggle added)
-- Place as a LocalScript in StarterPlayer > StarterPlayerScripts
-- Preserves GUI layout exactly. Adds "Start Closed" setting (persisted) and immediate apply.

-- Services
local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local UserInput   = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

-- Persistence helpers (exploit FS if available)
local HAS_FS = (type(isfile) == "function") and (type(readfile) == "function") and (type(writefile) == "function")
local DATA_FILE = "Nishgamer_FullHub_Data.json"

local function safeReadJSON(path)
    if not HAS_FS then return nil end
    if not isfile(path) then return nil end
    local ok, raw = pcall(readfile, path)
    if not ok or type(raw) ~= "string" then return nil end
    local ok2, tbl = pcall(function() return HttpService:JSONDecode(raw) end)
    if ok2 and type(tbl) == "table" then return tbl end
    return nil
end
local function safeWriteJSON(path, tbl)
    if not HAS_FS then return end
    local ok, enc = pcall(function() return HttpService:JSONEncode(tbl) end)
    if ok and type(enc) == "string" then
        pcall(writefile, path, enc)
    end
end

local function readPersist()
    if HAS_FS then
        return safeReadJSON(DATA_FILE)
    else
        local raw = LocalPlayer:GetAttribute("Nishgamer_FullHub_Data")
        if type(raw) == "string" then
            local ok, tbl = pcall(function() return HttpService:JSONDecode(raw) end)
            if ok and type(tbl) == "table" then return tbl end
        end
        return nil
    end
end
local function writePersist(tbl)
    if HAS_FS then
        safeWriteJSON(DATA_FILE, tbl)
    else
        local ok, enc = pcall(function() return HttpService:JSONEncode(tbl) end)
        if ok and type(enc) == "string" then
            pcall(function() LocalPlayer:SetAttribute("Nishgamer_FullHub_Data", enc) end)
        end
    end
end

-- Default data
local DefaultData = {
    settings = {
        resetOnSpawn = false,
        screenLock   = false,
        noConfirm    = false,
        lastSection  = "My Scripts",
        position     = { X = 60, Y = 10 }, -- saved position
        mainColor    = { R = 28, G = 28, B = 28 },
        accentColor  = { R = 60, G = 120, B = 60 },
        openColor    = { R = 45, G = 45, B = 45 },
        savePosition = true, -- whether moving the main updates the saved position
        startClosed  = false, -- NEW: start closed on run if true
    },
    tabs = {},
    nextId = 1,
    designHistory = {},
    designIndex = 0,
    lastExecutor = "",
}
local Data = readPersist() or DefaultData
Data.settings = Data.settings or DefaultData.settings
Data.tabs = Data.tabs or {}
Data.nextId = Data.nextId or DefaultData.nextId
Data.designHistory = Data.designHistory or DefaultData.designHistory
Data.designIndex = Data.designIndex or DefaultData.designIndex
Data.lastExecutor = Data.lastExecutor or DefaultData.lastExecutor

local function Save()
    Data.nextId = Data.nextId or (#Data.tabs + 1)
    writePersist(Data)
end

-- Remove old hub GUIs from CoreGui and PlayerGui to avoid duplicates/overlap
local function cleanupOldGUIs()
    local candidates = { "Nishgamer_Hub_Screen", "Nishgamer_Hub_Player", "Nishgamer_Core_AllFeatures", "Nishgamer_CoreGui", "Nishgamer_Core_AllFeatures", "Nishgamer_PlayerGui", "Nishgamer_Hub_Full", "Nishgamer_Hub" }
    local ok, CoreGui = pcall(function() return game:GetService("CoreGui") end)
    if ok and CoreGui then
        for _, child in ipairs(CoreGui:GetChildren()) do
            if child.Name:match("^Nishgamer") then
                pcall(function() child:Destroy() end)
            end
        end
    end
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if pg then
        for _, child in ipairs(pg:GetChildren()) do
            if child.Name:match("^Nishgamer") then
                pcall(function() child:Destroy() end)
            end
        end
    end
end

cleanupOldGUIs()

-- Color helpers
local function rgbToColor3(t)
    if not t then return Color3.fromRGB(28,28,28) end
    return Color3.fromRGB(math.clamp(t.R or 28,0,255), math.clamp(t.G or 28,0,255), math.clamp(t.B or 28,0,255))
end

-- Parent GUI: try CoreGui then PlayerGui
local screen, USED_CORE = nil, false
do
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok and cg then
        local success = pcall(function()
            local test = Instance.new("ScreenGui")
            test.Name = "Nishgamer_TempParentTest"
            test.Parent = cg
            test:Destroy()
            return true
        end)
        if success then
            screen = Instance.new("ScreenGui")
            screen.Name = "Nishgamer_Hub_Screen"
            screen.IgnoreGuiInset = true
            screen.ResetOnSpawn = Data.settings.resetOnSpawn and true or false
            screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
            screen.Parent = cg
            USED_CORE = true
        end
    end
    if not screen then
        local pg = LocalPlayer:WaitForChild("PlayerGui")
        screen = Instance.new("ScreenGui")
        screen.Name = "Nishgamer_Hub_Player"
        screen.IgnoreGuiInset = true
        screen.ResetOnSpawn = Data.settings.resetOnSpawn and true or false
        screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        screen.Parent = pg
        USED_CORE = false
    end
end

-- Remove previous main if any
local oldMain = screen:FindFirstChild("Main")
if oldMain then oldMain:Destroy() end

-- Build UI (KEEP layout identical)
local openBtn = Instance.new("TextButton")
openBtn.Name = "OpenHub"
openBtn.Size = UDim2.new(0,46,0,20)
openBtn.Position = UDim2.new(0,8,0.5,-10)
openBtn.Text = "Hub"
openBtn.Font = Enum.Font.SourceSansBold
openBtn.TextSize = 14
openBtn.TextColor3 = Color3.fromRGB(255,255,255)
openBtn.BackgroundColor3 = rgbToColor3(Data.settings.openColor)
openBtn.BorderSizePixel = 0
openBtn.ZIndex = 200
openBtn.Parent = screen
openBtn.Visible = false

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(420,280)
main.Position = UDim2.new(0, Data.settings.position.X or 60, 0, Data.settings.position.Y or 10)
main.BackgroundColor3 = rgbToColor3(Data.settings.mainColor)
main.BorderSizePixel = 0
main.Active = true
main.Parent = screen
main.ZIndex = 100

-- Top bar
local top = Instance.new("Frame")
top.Size = UDim2.new(1,0,0,28)
top.BackgroundColor3 = Color3.fromRGB(40,40,40)
top.BorderSizePixel = 0
top.Active = true
top.Parent = main
top.ZIndex = 150

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,-90,1,0)
title.Position = UDim2.new(0,8,0,0)
title.BackgroundTransparency = 1
title.Text = "Nishgamer Hub"
title.Font = Enum.Font.SourceSansBold
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(245,245,245)
title.Parent = top
title.ZIndex = 151

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0,60,1,0)
closeBtn.Position = UDim2.new(1,-64,0,0)
closeBtn.Text = "Close"
closeBtn.Font = Enum.Font.SourceSansBold
closeBtn.TextSize = 14
closeBtn.TextColor3 = Color3.fromRGB(255,255,255)
closeBtn.BackgroundColor3 = Color3.fromRGB(200,60,60)
closeBtn.BorderSizePixel = 0
closeBtn.Parent = top
closeBtn.ZIndex = 151

closeBtn.MouseButton1Click:Connect(function()
    main.Visible = false
    openBtn.Visible = true
    -- Save position only if SavePosition is enabled
    if Data.settings.savePosition then
        local p = main.Position
        Data.settings.position = { X = p.X.Offset, Y = p.Y.Offset }
        Save()
    end
end)
openBtn.MouseButton1Click:Connect(function()
    main.Visible = true
    openBtn.Visible = false
end)

-- Left nav
local left = Instance.new("Frame")
left.Size = UDim2.new(0,120,1,-28)
left.Position = UDim2.new(0,0,0,28)
left.BackgroundColor3 = Color3.fromRGB(35,35,35)
left.BorderSizePixel = 0
left.Parent = main
left.ZIndex = 120

local function mkNavBtn(text,y)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1,0,0,30)
    b.Position = UDim2.new(0,0,0,y)
    b.Text = text
    b.Font = Enum.Font.SourceSansBold
    b.TextSize = 14
    b.TextColor3 = Color3.fromRGB(255,255,255)
    b.BackgroundColor3 = Color3.fromRGB(55,55,55)
    b.BorderSizePixel = 0
    b.Parent = left
    b.ZIndex = 121
    return b
end

local btnScripts = mkNavBtn("My Scripts", 6)
local btnExec    = mkNavBtn("Executor", 40)
local btnSettings= mkNavBtn("Settings", 74)
local btnDesign  = mkNavBtn("Design", 108)

-- Content area
local content = Instance.new("Frame")
content.Size = UDim2.new(1,-120,1,-28)
content.Position = UDim2.new(0,120,0,28)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.Parent = main
content.ZIndex = 110

local pages = {}
local function newPage()
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1,-10,1,-10)
    f.Position = UDim2.new(0,5,0,5)
    f.BackgroundTransparency = 1
    f.Visible = false
    f.Parent = content
    f.ZIndex = 130
    return f
end

pages["My Scripts"] = newPage()
pages["Executor"]   = newPage()
pages["Settings"]   = newPage()
pages["Design"]     = newPage()

local function showPage(name)
    for k,v in pairs(pages) do v.Visible = (k == name) end
    Data.settings.lastSection = name
    Save()
end
btnScripts.MouseButton1Click:Connect(function() showPage("My Scripts") end)
btnExec.MouseButton1Click:Connect(function() showPage("Executor") end)
btnSettings.MouseButton1Click:Connect(function() showPage("Settings") end)
btnDesign.MouseButton1Click:Connect(function() showPage("Design") end)

-- Apply startClosed on startup
if Data.settings.startClosed then
    main.Visible = false
    openBtn.Visible = true
else
    main.Visible = true
    openBtn.Visible = false
end

showPage(Data.settings.lastSection or "My Scripts")

-- Dragging main via top (manual) — respects savePosition toggle
do
    local dragging = false
    local dragInput = nil
    local dragStart = Vector2.new()
    local startPos = UDim2.new()

    local function startDrag(input)
        if Data.settings.screenLock then return end
        dragging = true
        dragInput = input
        dragStart = input.Position
        startPos = main.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
                dragInput = nil
                -- Save only if enabled
                if Data.settings.savePosition then
                    local p = main.Position
                    Data.settings.position = { X = p.X.Offset, Y = p.Y.Offset }
                    Save()
                end
            end
        end)
    end

    top.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            startDrag(input)
        end
    end)
    UserInput.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            main.Position = UDim2.fromOffset(startPos.X.Offset + delta.X, startPos.Y.Offset + delta.Y)
        end
    end)

    -- clamp main each frame so it never goes off-screen
    RunService.RenderStepped:Connect(function()
        local cam = workspace and workspace.CurrentCamera
        if not cam then return end
        local vs = cam.ViewportSize
        local pos = main.AbsolutePosition
        local sz = main.AbsoluteSize
        main.Position = UDim2.fromOffset(math.clamp(pos.X, 0, math.max(0, vs.X - sz.X)),
                                          math.clamp(pos.Y, 0, math.max(0, vs.Y - sz.Y)))
    end)
end

-- Helper: find index by id
local function findIndexById(id)
    for i,t in ipairs(Data.tabs) do if t.id == id then return i end end
    return nil
end

-- ---------- My Scripts page ----------
do
    local page = pages["My Scripts"]

    local nameBox = Instance.new("TextBox", page)
    nameBox.Size = UDim2.new(0,170,0,28)
    nameBox.Position = UDim2.new(0,0,0,0)
    nameBox.PlaceholderText = "New tab name"
    nameBox.ClearTextOnFocus = false
    nameBox.BackgroundColor3 = Color3.fromRGB(45,45,45)
    nameBox.TextColor3 = Color3.fromRGB(255,255,255)
    nameBox.Font = Enum.Font.SourceSans
    nameBox.TextSize = 14

    local addBtn = Instance.new("TextButton", page)
    addBtn.Size = UDim2.new(0,70,0,28)
    addBtn.Position = UDim2.new(0,180,0,0)
    addBtn.Text = "Add"
    addBtn.Font = Enum.Font.SourceSansBold
    addBtn.TextSize = 14
    addBtn.BackgroundColor3 = rgbToColor3(Data.settings.accentColor)
    addBtn.TextColor3 = Color3.new(1,1,1)

    local searchBox = Instance.new("TextBox", page)
    searchBox.Size = UDim2.new(0,180,0,22)
    searchBox.Position = UDim2.new(0,260,0,4)
    searchBox.BackgroundColor3 = Color3.fromRGB(50,50,50)
    searchBox.TextColor3 = Color3.new(1,1,1)
    searchBox.ClearTextOnFocus = false
    searchBox.Text = ""

    local placeholder = Instance.new("TextLabel", page)
    placeholder.Size = searchBox.Size
    placeholder.Position = searchBox.Position
    placeholder.BackgroundTransparency = 1
    placeholder.Text = "Search by name..."
    placeholder.TextColor3 = Color3.fromRGB(170,170,170)
    placeholder.Font = Enum.Font.SourceSans
    placeholder.TextXAlignment = Enum.TextXAlignment.Left
    placeholder.ZIndex = 160

    searchBox:GetPropertyChangedSignal("Text"):Connect(function() placeholder.Visible = (searchBox.Text == "") end)
    searchBox.Focused:Connect(function() placeholder.Visible = false end)
    searchBox.FocusLost:Connect(function() placeholder.Visible = (searchBox.Text == "") end)

    local list = Instance.new("ScrollingFrame", page)
    list.Size = UDim2.new(0,170,1,-38)
    list.Position = UDim2.new(0,0,0,36)
    list.BackgroundColor3 = Color3.fromRGB(38,38,38)
    list.BorderSizePixel = 0
    list.ScrollBarThickness = 6
    list.ZIndex = 155

    local layout = Instance.new("UIListLayout", list)
    layout.Padding = UDim.new(0,6)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        list.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 12)
    end)

    local function sanitizeName(s)
        s = tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if s == "" then s = "Untitled" end
        if #s > 64 then s = s:sub(1,64) end
        return s
    end

    local function clearList()
        for _,c in ipairs(list:GetChildren()) do
            if not c:IsA("UIListLayout") then c:Destroy() end
        end
    end

    local function renderCard(tab)
        if not tab or not tab.id then return end
        local card = Instance.new("Frame")
        card.Size = UDim2.new(1,-10,0,86)
        card.BackgroundColor3 = Color3.fromRGB(50,50,50)
        card.BorderSizePixel = 0
        card.Parent = list
        card.ZIndex = 156

        local nameLbl = Instance.new("TextLabel", card)
        nameLbl.Size = UDim2.new(1,-10,0,20)
        nameLbl.Position = UDim2.new(0,6,0,6)
        nameLbl.BackgroundTransparency = 1
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.Font = Enum.Font.SourceSansBold
        nameLbl.TextColor3 = Color3.new(1,1,1)
        nameLbl.Text = tab.name or ("Tab "..tostring(tab.id))
        nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
        nameLbl.ZIndex = 157

        local execB = Instance.new("TextButton", card)
        execB.Size = UDim2.new(0,70,0,22); execB.Position = UDim2.new(0,6,0,34)
        execB.Text = "Execute"; execB.BackgroundColor3 = rgbToColor3(Data.settings.accentColor)
        execB.BorderSizePixel = 0; execB.TextColor3 = Color3.new(1,1,1); execB.ZIndex = 157

        local editB = Instance.new("TextButton", card)
        editB.Size = UDim2.new(0,60,0,22); editB.Position = UDim2.new(0,84,0,34)
        editB.Text = "Edit"; editB.BackgroundColor3 = Color3.fromRGB(70,70,110)
        editB.BorderSizePixel = 0; editB.TextColor3 = Color3.new(1,1,1); editB.ZIndex = 157

        local renB = Instance.new("TextButton", card)
        renB.Size = UDim2.new(0,70,0,22); renB.Position = UDim2.new(0,154,0,34)
        renB.Text = "Rename"; renB.BackgroundColor3 = Color3.fromRGB(110,90,60)
        renB.BorderSizePixel = 0; renB.TextColor3 = Color3.new(1,1,1); renB.ZIndex = 157

        local delB = Instance.new("TextButton", card)
        delB.Size = UDim2.new(0,56,0,22); delB.Position = UDim2.new(0,6,0,60)
        delB.Text = "Del"; delB.BackgroundColor3 = Color3.fromRGB(150,60,60)
        delB.BorderSizePixel = 0; delB.TextColor3 = Color3.new(1,1,1); delB.ZIndex = 157

        -- Execute handler
        execB.MouseButton1Click:Connect(function()
            local src = tab.code or ""
            if src ~= "" then
                local loader = (typeof(loadstring) == "function" and loadstring) or (typeof(load) == "function" and load) or nil
                if loader then
                    local ok, fnOrErr = pcall(function() return loader(src) end)
                    if ok and type(fnOrErr) == "function" then
                        local sOk, sErr = pcall(fnOrErr)
                        if not sOk then warn("Script runtime error:", sErr) end
                    else
                        if not ok then warn("Compile error:", fnOrErr) end
                    end
                else
                    warn("No loadstring/load available.")
                end
            end
        end)

        -- Edit popup (Save / Clear / Close)
        editB.MouseButton1Click:Connect(function()
            local popup = Instance.new("Frame")
            popup.Size = UDim2.new(0,520,0,320)
            popup.Position = UDim2.new(0.5,-260,0.5,-160)
            popup.BackgroundColor3 = Color3.fromRGB(30,30,30)
            popup.BorderSizePixel = 0
            popup.Active = true
            popup.Parent = screen
            popup.ZIndex = 210

            local hdr = Instance.new("TextLabel", popup)
            hdr.Size = UDim2.new(1,0,0,28); hdr.Position = UDim2.new(0,0,0,0)
            hdr.BackgroundColor3 = Color3.fromRGB(45,45,45)
            hdr.Text = "Edit: "..(tab.name or "")
            hdr.TextColor3 = Color3.new(1,1,1)
            hdr.Font = Enum.Font.SourceSansBold
            hdr.ZIndex = 211

            local box = Instance.new("TextBox", popup)
            box.Size = UDim2.new(1,-20,1,-118)
            box.Position = UDim2.new(0,10,0,36)
            box.MultiLine = true
            box.ClearTextOnFocus = false
            box.Text = tab.code or ""
            box.Font = Enum.Font.Code
            box.BackgroundColor3 = Color3.fromRGB(40,40,40)
            box.TextColor3 = Color3.new(1,1,1)
            box.ZIndex = 211

            local saveB = Instance.new("TextButton", popup)
            saveB.Size = UDim2.new(0.5,-14,0,36)
            saveB.Position = UDim2.new(0,10,1,-72)
            saveB.Text = "Save"; saveB.BackgroundColor3 = rgbToColor3(Data.settings.accentColor)
            saveB.TextColor3 = Color3.new(1,1,1); saveB.ZIndex = 211

            local closeB = Instance.new("TextButton", popup)
            closeB.Size = UDim2.new(0.5,-14,0,36)
            closeB.Position = UDim2.new(0.5,14,1,-72)
            closeB.Text = "Close"; closeB.BackgroundColor3 = Color3.fromRGB(120,60,60)
            closeB.TextColor3 = Color3.new(1,1,1); closeB.ZIndex = 211

            local clearB = Instance.new("TextButton", popup)
            clearB.Size = UDim2.new(1,-20,0,28)
            clearB.Position = UDim2.new(0,10,1,-36)
            clearB.Text = "Clear"; clearB.BackgroundColor3 = Color3.fromRGB(90,90,90)
            clearB.TextColor3 = Color3.new(1,1,1); clearB.ZIndex = 211

            saveB.MouseButton1Click:Connect(function()
                tab.code = box.Text or ""
                Save()
                popup:Destroy()
            end)
            closeB.MouseButton1Click:Connect(function() popup:Destroy() end)
            clearB.MouseButton1Click:Connect(function() box.Text = "" end)

            -- Popup movable via hdr
            do
                local draggingPop = false
                local dragInputPop = nil
                local dragStartPop = Vector2.new()
                local startPosPop = popup.Position
                hdr.InputBegan:Connect(function(inp)
                    if (inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch) and not Data.settings.screenLock then
                        draggingPop = true
                        dragInputPop = inp
                        dragStartPop = inp.Position
                        startPosPop = popup.Position
                        inp.Changed:Connect(function()
                            if inp.UserInputState == Enum.UserInputState.End then
                                draggingPop = false
                                dragInputPop = nil
                            end
                        end)
                    end
                end)
                UserInput.InputChanged:Connect(function(inp)
                    if inp == dragInputPop and draggingPop then
                        local delta = inp.Position - dragStartPop
                        popup.Position = UDim2.fromOffset(startPosPop.X.Offset + delta.X, startPosPop.Y.Offset + delta.Y)
                    end
                end)
                local conn
                conn = RunService.RenderStepped:Connect(function()
                    if not popup.Parent then conn:Disconnect(); return end
                    local cam = workspace and workspace.CurrentCamera
                    if not cam then return end
                    local vs = cam.ViewportSize
                    local pos = popup.AbsolutePosition
                    local sz = popup.AbsoluteSize
                    popup.Position = UDim2.fromOffset(math.clamp(pos.X, 0, math.max(0, vs.X - sz.X)),
                                                      math.clamp(pos.Y, 0, math.max(0, vs.Y - sz.Y)))
                end)
            end
        end)

        -- Rename
        renB.MouseButton1Click:Connect(function()
            local pop = Instance.new("Frame")
            pop.Size = UDim2.new(0,320,0,120)
            pop.Position = UDim2.new(0.5,-160,0.5,-60)
            pop.BackgroundColor3 = Color3.fromRGB(30,30,30)
            pop.Active = true
            pop.Parent = screen
            pop.ZIndex = 210

            local head = Instance.new("TextLabel", pop)
            head.Size = UDim2.new(1,0,0,28); head.BackgroundColor3 = Color3.fromRGB(45,45,45)
            head.Text = "Rename Tab"; head.TextColor3 = Color3.new(1,1,1); head.Font = Enum.Font.SourceSansBold

            local nameInput = Instance.new("TextBox", pop)
            nameInput.Size = UDim2.new(1,-20,0,28); nameInput.Position = UDim2.new(0,10,0,36)
            nameInput.PlaceholderText = "Enter new name"; nameInput.Text = tab.name or ""
            nameInput.BackgroundColor3 = Color3.fromRGB(40,40,40); nameInput.TextColor3 = Color3.new(1,1,1)
            nameInput.Font = Enum.Font.SourceSans; nameInput.TextSize = 14

            local saveB = Instance.new("TextButton", pop)
            saveB.Size = UDim2.new(0.5,-14,0,28); saveB.Position = UDim2.new(0,10,1,-36)
            saveB.Text = "Save"; saveB.BackgroundColor3 = rgbToColor3(Data.settings.accentColor)
            saveB.TextColor3 = Color3.new(1,1,1)

            local cancelB = Instance.new("TextButton", pop)
            cancelB.Size = UDim2.new(0.5,-14,0,28); cancelB.Position = UDim2.new(0.5,14,1,-36)
            cancelB.Text = "Cancel"; cancelB.BackgroundColor3 = Color3.fromRGB(120,60,60)
            cancelB.TextColor3 = Color3.new(1,1,1)

            saveB.MouseButton1Click:Connect(function()
                local nm = sanitizeName(nameInput.Text)
                tab.name = nm
                nameLbl.Text = nm
                Save()
                pop:Destroy()
            end)
            cancelB.MouseButton1Click:Connect(function() pop:Destroy() end)

            -- movable header drag
            do
                local draggingPop = false
                local dragInp = nil
                local ds = Vector2.new()
                local sp = pop.Position
                head.InputBegan:Connect(function(inp)
                    if (inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch) and not Data.settings.screenLock then
                        draggingPop = true
                        dragInp = inp
                        ds = inp.Position
                        sp = pop.Position
                        inp.Changed:Connect(function()
                            if inp.UserInputState == Enum.UserInputState.End then draggingPop = false; dragInp = nil end
                        end)
                    end
                end)
                UserInput.InputChanged:Connect(function(inp)
                    if draggingPop and inp == dragInp then
                        local delta = inp.Position - ds
                        pop.Position = UDim2.fromOffset(sp.X.Offset + delta.X, sp.Y.Offset + delta.Y)
                    end
                end)
                local conn
                conn = RunService.RenderStepped:Connect(function()
                    if not pop.Parent then conn:Disconnect(); return end
                    local cam = workspace and workspace.CurrentCamera
                    if not cam then return end
                    local vs = cam.ViewportSize
                    local pos = pop.AbsolutePosition
                    local sz = pop.AbsoluteSize
                    pop.Position = UDim2.fromOffset(math.clamp(pos.X, 0, math.max(0, vs.X - sz.X)),
                                                    math.clamp(pos.Y, 0, math.max(0, vs.Y - sz.Y)))
                end)
            end
        end)

        -- Delete (with confirm unless noConfirm)
        delB.MouseButton1Click:Connect(function()
            if Data.settings.noConfirm then
                local idx = findIndexById(tab.id)
                if idx then table.remove(Data.tabs, idx); Save() end
                card:Destroy()
            else
                local pop = Instance.new("Frame")
                pop.Size = UDim2.new(0,320,0,120)
                pop.Position = UDim2.new(0.5,-160,0.5,-60)
                pop.BackgroundColor3 = Color3.fromRGB(30,30,30)
                pop.Active = true
                pop.Parent = screen
                pop.ZIndex = 220

                local head = Instance.new("TextLabel", pop)
                head.Size = UDim2.new(1,0,0,28); head.BackgroundColor3 = Color3.fromRGB(45,45,45)
                head.Text = "Confirm Delete"; head.TextColor3 = Color3.new(1,1,1); head.Font = Enum.Font.SourceSansBold

                local msg = Instance.new("TextLabel", pop)
                msg.Size = UDim2.new(1,-20,0,28); msg.Position = UDim2.new(0,10,0,36)
                msg.BackgroundTransparency = 1
                msg.Text = "Delete '" .. (tab.name or "") .. "'?"
                msg.TextColor3 = Color3.new(1,1,1); msg.Font = Enum.Font.SourceSans

                local confirmB = Instance.new("TextButton", pop)
                confirmB.Size = UDim2.new(0.5,-14,0,28); confirmB.Position = UDim2.new(0,10,1,-36)
                confirmB.Text = "Yes"; confirmB.BackgroundColor3 = Color3.fromRGB(150,60,60); confirmB.TextColor3 = Color3.new(1,1,1)

                local cancelB = Instance.new("TextButton", pop)
                cancelB.Size = UDim2.new(0.5,-14,0,28); cancelB.Position = UDim2.new(0.5,14,1,-36)
                cancelB.Text = "No"; cancelB.BackgroundColor3 = Color3.fromRGB(90,90,90); cancelB.TextColor3 = Color3.new(1,1,1)

                confirmB.MouseButton1Click:Connect(function()
                    local idx = findIndexById(tab.id)
                    if idx then table.remove(Data.tabs, idx); Save() end
                    pop:Destroy()
                    card:Destroy()
                end)
                cancelB.MouseButton1Click:Connect(function() pop:Destroy() end)
            end
        end)
    end

    addBtn.MouseButton1Click:Connect(function()
        local nm = sanitizeName(nameBox.Text)
        nameBox.Text = ""
        local tab = { id = Data.nextId, name = nm, code = "" }
        Data.nextId = Data.nextId + 1
        table.insert(Data.tabs, tab)
        Save()
        clearList()
        for _, t in ipairs(Data.tabs) do renderCard(t) end
    end)

    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        clearList()
        local filter = tostring(searchBox.Text or ""):lower()
        for _, tab in ipairs(Data.tabs) do
            if filter == "" or (tostring(tab.name or ""):lower():find(filter,1,true)) then
                renderCard(tab)
            end
        end
    end)

    -- initial render
    clearList()
    for _, tab in ipairs(Data.tabs) do renderCard(tab) end
end

-- ---------- Executor ----------
do
    local page = pages["Executor"]
    local box = Instance.new("TextBox", page)
    box.Size = UDim2.new(1,-10,1,-48)
    box.Position = UDim2.new(0,5,0,5)
    box.MultiLine = true
    box.ClearTextOnFocus = false
    box.Font = Enum.Font.Code
    box.BackgroundColor3 = Color3.fromRGB(40,40,40)
    box.TextColor3 = Color3.new(1,1,1)
    box.Text = Data.lastExecutor or ""

    local execB = Instance.new("TextButton", page)
    execB.Size = UDim2.new(0.5,-10,0,28)
    execB.Position = UDim2.new(0,5,1,-38)
    execB.Text = "Execute"
    execB.BackgroundColor3 = rgbToColor3(Data.settings.accentColor)
    execB.TextColor3 = Color3.new(1,1,1)

    local clearB = Instance.new("TextButton", page)
    clearB.Size = UDim2.new(0.5,-10,0,28)
    clearB.Position = UDim2.new(0.5,5,1,-38)
    clearB.Text = "Clear"
    clearB.BackgroundColor3 = Color3.fromRGB(90,90,90)
    clearB.TextColor3 = Color3.new(1,1,1)

    execB.MouseButton1Click:Connect(function()
        local src = box.Text or ""
        Data.lastExecutor = src
        Save()
        if src ~= "" then
            local loader = (typeof(loadstring) == "function" and loadstring) or (typeof(load) == "function" and load) or nil
            if loader then
                local ok, fnOrErr = pcall(function() return loader(src) end)
                if ok and type(fnOrErr) == "function" then
                    local sOk, sErr = pcall(fnOrErr)
                    if not sOk then warn("Executor runtime error:", sErr) end
                else
                    if not ok then warn("Executor compile error:", fnOrErr) end
                end
            else
                warn("No loadstring/load available.")
            end
        end
    end)
    clearB.MouseButton1Click:Connect(function() box.Text = "" end)
end

-- ---------- Settings ----------
do
    local page = pages["Settings"]
    local function mkToggle(labelText, key, y)
        local f = Instance.new("Frame", page)
        f.Size = UDim2.new(1,-10,0,28)
        f.Position = UDim2.new(0,5,0,y)
        f.BackgroundTransparency = 1

        local lbl = Instance.new("TextLabel", f)
        lbl.Size = UDim2.new(0.7,0,1,0)
        lbl.BackgroundTransparency = 1
        lbl.Text = labelText
        lbl.TextColor3 = Color3.new(1,1,1)
        lbl.Font = Enum.Font.SourceSans
        lbl.TextXAlignment = Enum.TextXAlignment.Left

        local toggle = Instance.new("TextButton", f)
        toggle.Size = UDim2.new(0,60,0,22)
        toggle.Position = UDim2.new(1,-66,0,3)
        toggle.Text = Data.settings[key] and "On" or "Off"
        toggle.BackgroundColor3 = Data.settings[key] and rgbToColor3(Data.settings.accentColor) or Color3.fromRGB(90,90,90)
        toggle.TextColor3 = Color3.new(1,1,1)

        toggle.MouseButton1Click:Connect(function()
            Data.settings[key] = not Data.settings[key]
            toggle.Text = Data.settings[key] and "On" or "Off"
            toggle.BackgroundColor3 = Data.settings[key] and rgbToColor3(Data.settings.accentColor) or Color3.fromRGB(90,90,90)

            if key == "resetOnSpawn" then
                screen.ResetOnSpawn = Data.settings.resetOnSpawn and true or false
            elseif key == "screenLock" then
                -- screen locking prevents drag of main and popups
                -- handled by checking Data.settings.screenLock in drag handlers
            elseif key == "startClosed" then
                -- immediate apply: hide/show main and open button
                if Data.settings.startClosed then
                    main.Visible = false
                    openBtn.Visible = true
                else
                    main.Visible = true
                    openBtn.Visible = false
                end
            end

            Save()
        end)
    end

    mkToggle("Reset on Spawn", "resetOnSpawn", 6)
    mkToggle("Screen Lock", "screenLock", 46)
    mkToggle("No Confirm Delete", "noConfirm", 86)
    mkToggle("Save Position", "savePosition", 126) -- existing
    mkToggle("Start Closed On Run", "startClosed", 166) -- NEW: added toggle
end

-- ---------- Design ----------
do
    local page = pages["Design"]
    local preview = Instance.new("Frame", page)
    preview.Size = UDim2.new(0,100,0,100)
    preview.Position = UDim2.new(0,5,0,5)
    preview.BackgroundColor3 = rgbToColor3(Data.settings.mainColor)

    local accentPreview = Instance.new("Frame", preview)
    accentPreview.Size = UDim2.new(0,50,0,50)
    accentPreview.Position = UDim2.new(0.5,-25,0.5,-25)
    accentPreview.BackgroundColor3 = rgbToColor3(Data.settings.accentColor)

    local genB = Instance.new("TextButton", page)
    genB.Size = UDim2.new(0,100,0,28); genB.Position = UDim2.new(0,5,0,110)
    genB.Text = "Generate"; genB.BackgroundColor3 = Color3.fromRGB(90,90,90); genB.TextColor3 = Color3.new(1,1,1)

    local prevB = Instance.new("TextButton", page)
    prevB.Size = UDim2.new(0,50,0,28); prevB.Position = UDim2.new(0,5,0,144)
    prevB.Text = "Prev"; prevB.BackgroundColor3 = Color3.fromRGB(90,90,90); prevB.TextColor3 = Color3.new(1,1,1)

    local nextB = Instance.new("TextButton", page)
    nextB.Size = UDim2.new(0,50,0,28); nextB.Position = UDim2.new(0,60,0,144)
    nextB.Text = "Next"; nextB.BackgroundColor3 = Color3.fromRGB(90,90,90); nextB.TextColor3 = Color3.new(1,1,1)

    local applyB = Instance.new("TextButton", page)
    applyB.Size = UDim2.new(0,100,0,28); applyB.Position = UDim2.new(0,5,0,178)
    applyB.Text = "Apply"; applyB.BackgroundColor3 = rgbToColor3(Data.settings.accentColor); applyB.TextColor3 = Color3.new(1,1,1)

    local function randomColorTbl()
        return { R = math.random(0,255), G = math.random(0,255), B = math.random(0,255) }
    end

    genB.MouseButton1Click:Connect(function()
        local newColors = { main = randomColorTbl(), accent = randomColorTbl() }
        table.insert(Data.designHistory, newColors)
        Data.designIndex = #Data.designHistory
        preview.BackgroundColor3 = rgbToColor3(newColors.main)
        accentPreview.BackgroundColor3 = rgbToColor3(newColors.accent)
        Save()
    end)

    prevB.MouseButton1Click:Connect(function()
        if Data.designIndex > 1 then
            Data.designIndex = Data.designIndex - 1
            local colors = Data.designHistory[Data.designIndex]
            if colors then
                preview.BackgroundColor3 = rgbToColor3(colors.main)
                accentPreview.BackgroundColor3 = rgbToColor3(colors.accent)
                Save()
            end
        end
    end)

    nextB.MouseButton1Click:Connect(function()
        if Data.designIndex < #Data.designHistory then
            Data.designIndex = Data.designIndex + 1
            local colors = Data.designHistory[Data.designIndex]
            if colors then
                preview.BackgroundColor3 = rgbToColor3(colors.main)
                accentPreview.BackgroundColor3 = rgbToColor3(colors.accent)
                Save()
            end
        end
    end)

    applyB.MouseButton1Click:Connect(function()
        local colors = Data.designHistory[Data.designIndex]
        if colors then
            Data.settings.mainColor = colors.main
            Data.settings.accentColor = colors.accent
            main.BackgroundColor3 = rgbToColor3(colors.main)
            -- update accent-colored buttons
            for _, pg in pairs(pages) do
                for _, obj in ipairs(pg:GetDescendants()) do
                    if obj:IsA("TextButton") then
                        obj.BackgroundColor3 = rgbToColor3(colors.accent)
                    end
                end
            end
            for _, obj in ipairs(left:GetDescendants()) do
                if obj:IsA("TextButton") then obj.BackgroundColor3 = rgbToColor3(colors.accent) end
            end
            Save()
        end
    end)
end

-- Save on exit
Players.PlayerRemoving:Connect(function() Save() end)
game:BindToClose(function() Save() end)

print("[Nishgamer Hub] Full loaded — StartClosed toggle implemented.")


