-- Nishgamer Hub — V8 (FINAL - CLOUD SAVE + ANTI FLING + KEY SYSTEM)
-- Place as a LocalScript in StarterPlayer > StarterPlayerScripts

local Players             = game:GetService("Players")
local RunService          = game:GetService("RunService")
local UserInput           = game:GetService("UserInputService")
local HttpService         = game:GetService("HttpService")
local PathfindingService  = game:GetService("PathfindingService")
local MarketplaceService  = game:GetService("MarketplaceService")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

-- ============================================================
-- SUPABASE CONFIG
-- ============================================================
local SUPABASE_URL = "https://xvnbxdcqmfsnnvbugasi.supabase.co"
local SUPABASE_KEY = "sb_publishable_OQbzgO3ZE6-6qDl1YT_fXA_LA5aM-f0"
local TABLE_KEYS   = "keys"
local COLUMN_KEY   = "key"
local TABLE_USERS  = "users"
local TABLE_CLOUD  = "data"
local SUPABASE_SCHEMA = "public"

-- ============================================================
-- FILE SYSTEM
-- ============================================================
local HAS_FS = (type(isfile) == "function") and (type(readfile) == "function") and (type(writefile) == "function")
local FOLDER = "Nishgamerrhub"
local FILE = FOLDER .. "/Nishgamerrhub.json"
if HAS_FS and type(makefolder) == "function" then pcall(makefolder, FOLDER) end

local function readJSON(path)
    if not HAS_FS or not isfile(path) then return nil end
    local ok, raw = pcall(readfile, path)
    if not ok or type(raw) ~= "string" then return nil end
    local ok2, t = pcall(function() return HttpService:JSONDecode(raw) end)
    if ok2 and type(t) == "table" then return t end
    return nil
end

local function writeJSON(path, t)
    if not HAS_FS then return false end
    local ok, enc = pcall(function() return HttpService:JSONEncode(t) end)
    if ok and type(enc) == "string" then return pcall(writefile, path, enc) end
    return false
end

local function loadConfig()
    local data = readJSON(FILE)
    if not data then
        data = {
            settings = {
                resetOnSpawn = false, screenLock = false, noConfirm = false,
                lastSection = "My Scripts", position = {X=60,Y=10},
                mainColor = {R=28,G=28,B=28}, accentColor = {R=60,G=120,B=60},
                openColor = {R=45,G=45,B=45}, savePosition = true,
                startClosed = false, lastOpenState = false,
                aimlock = false, pathfind = false, antiFling = false,
                isKeyValid = false, validKey = ""
            },
            tabs = {}, nextId = 1, designHistory = {}, designIndex = 0, lastExecutor = ""
        }
    end
    data.settings = data.settings or {}
    data.settings.isKeyValid = data.settings.isKeyValid or false
    data.settings.validKey = data.settings.validKey or ""
    data.settings.antiFling = data.settings.antiFling or false
    data.tabs = data.tabs or {}
    data.nextId = data.nextId or 1
    data.designHistory = data.designHistory or {}
    data.designIndex = data.designIndex or 0
    data.lastExecutor = data.lastExecutor or ""
    local p = data.settings.position or {}
    data.settings.position = {X = tonumber(p.X) or 60, Y = tonumber(p.Y) or 10}
    return data
end

local Data = loadConfig()

-- ============================================================
-- SUPABASE HELPERS (WITH public SCHEMA)
-- ============================================================
local function supabaseGet(tablePath, filters)
    local parts = {}
    for col, val in pairs(filters or {}) do
        table.insert(parts, col .. "=" .. HttpService:UrlEncode(val))
    end
    local url = SUPABASE_URL .. "/rest/v1/" .. tablePath
    if #parts > 0 then url = url .. "?" .. table.concat(parts, "&") end
    local ok, resp = pcall(function()
        return HttpService:RequestAsync({
            Url = url, Method = "GET",
            Headers = {
                ["apikey"] = SUPABASE_KEY,
                ["Authorization"] = "Bearer " .. SUPABASE_KEY,
                ["Content-Type"] = "application/json",
                ["Accept-Profile"] = SUPABASE_SCHEMA
            }
        })
    end)
    if not ok then return false, "Network Error" end
    if not resp.Success then
        local msg = "HTTP " .. tostring(resp.StatusCode)
        if resp.Body then
            local dOk, d = pcall(function() return HttpService:JSONDecode(resp.Body) end)
            if dOk and type(d) == "table" and d.message then msg = msg .. ": " .. d.message end
        end
        return false, msg
    end
    if resp.Body and resp.Body ~= "" then
        local dOk, d = pcall(function() return HttpService:JSONDecode(resp.Body) end)
        if dOk then return true, d end
        return false, "Decode Error"
    end
    return true, {}
end

local function supabasePost(tablePath, body)
    local ok, enc = pcall(function() return HttpService:JSONEncode(body) end)
    if not ok then return false, "Encode Error" end
    local url = SUPABASE_URL .. "/rest/v1/" .. tablePath
    local rOk, resp = pcall(function()
        return HttpService:RequestAsync({
            Url = url, Method = "POST",
            Headers = {
                ["apikey"] = SUPABASE_KEY,
                ["Authorization"] = "Bearer " .. SUPABASE_KEY,
                ["Content-Type"] = "application/json",
                ["Prefer"] = "return=representation",
                ["Content-Profile"] = SUPABASE_SCHEMA
            },
            Body = enc
        })
    end)
    if not rOk then return false, "Network Error" end
    if not resp.Success then return false, "HTTP " .. tostring(resp.StatusCode) end
    return true, resp.Body
end

local function supabasePatch(tablePath, filters, body)
    local parts = {}
    for col, val in pairs(filters or {}) do table.insert(parts, col .. "=" .. HttpService:UrlEncode(val)) end
    local url = SUPABASE_URL .. "/rest/v1/" .. tablePath
    if #parts > 0 then url = url .. "?" .. table.concat(parts, "&") end
    local ok, enc = pcall(function() return HttpService:JSONEncode(body) end)
    if not ok then return false, "Encode Error" end
    local rOk, resp = pcall(function()
        return HttpService:RequestAsync({
            Url = url, Method = "PATCH",
            Headers = {
                ["apikey"] = SUPABASE_KEY,
                ["Authorization"] = "Bearer " .. SUPABASE_KEY,
                ["Content-Type"] = "application/json",
                ["Prefer"] = "return=representation",
                ["Content-Profile"] = SUPABASE_SCHEMA
            },
            Body = enc
        })
    end)
    if not rOk then return false, "Network Error" end
    if not resp.Success then return false, "HTTP " .. tostring(resp.StatusCode) end
    return true, resp.Body
end

-- ============================================================
-- KEY VALIDATION
-- ============================================================
local function checkKey(inputKey)
    inputKey = tostring(inputKey or ""):match("^%s*(.-)%s*$")
    if inputKey == "" then return false, "Enter a key first" end
    local ok, data = supabaseGet(TABLE_KEYS, { [COLUMN_KEY] = "eq." .. inputKey, ["select"] = "*" })
    if not ok then return false, "Connection Error" end
    if type(data) == "table" and #data > 0 then return true, "Key Valid!" end
    return false, "Invalid Key!"
end

local function autoVerifySavedKey()
    if not Data.settings.isKeyValid or Data.settings.validKey == "" then return end
    local ok, _ = checkKey(Data.settings.validKey)
    if not ok then Data.settings.isKeyValid = false; Data.settings.validKey = ""; writeJSON(FILE, Data) end
end
task.spawn(autoVerifySavedKey)

-- ============================================================
-- CLOUD SAVE/LOAD
-- ============================================================
local cloudBusy = false
local function cloudSaveNow()
    if not Data.settings.isKeyValid or cloudBusy then return false end
    cloudBusy = true
    local ok1, enc = pcall(function() return HttpService:JSONEncode({ tabs = Data.tabs, nextId = Data.nextId }) end)
    if not ok1 then cloudBusy = false; return false end
    local payload = { username = LocalPlayer.Name, data = enc }
    local encName = HttpService:UrlEncode(LocalPlayer.Name)
    local checkOk, existing = supabaseGet(TABLE_CLOUD, { username = "eq." .. encName, select = "id" })
    local result = false
    if checkOk and type(existing) == "table" and #existing > 0 then
        result = supabasePatch(TABLE_CLOUD, { id = "eq." .. tostring(existing[1].id) }, payload)
    else
        result = supabasePost(TABLE_CLOUD, payload)
    end
    cloudBusy = false
    return result
end

local cloudSaveDebounce = 0
local function triggerCloudSave()
    if not Data.settings.isKeyValid then return end
    if tick() - cloudSaveDebounce < 2 then return end
    cloudSaveDebounce = tick()
    task.spawn(cloudSaveNow)
end

local function cloudLoad()
    if not Data.settings.isKeyValid then return false end
    local encName = HttpService:UrlEncode(LocalPlayer.Name)
    local ok, data = supabaseGet(TABLE_CLOUD, { username = "eq." .. encName, select = "data" })
    if not ok or type(data) ~= "table" or #data == 0 then
        task.spawn(cloudSaveNow)
        return false
    end
    local rawJson = data[1].data
    if type(rawJson) ~= "string" then return false end
    local decOk, cloudData = pcall(function() return HttpService:JSONDecode(rawJson) end)
    if not decOk or type(cloudData) ~= "table" then return false end
    if type(cloudData.tabs) == "table" then
        Data.tabs = cloudData.tabs
        local maxId = 0
        for _, t in ipairs(Data.tabs) do if type(t.id) == "number" and t.id > maxId then maxId = t.id end end
        Data.nextId = (type(cloudData.nextId) == "number" and cloudData.nextId > maxId) and cloudData.nextId or (maxId + 1)
    end
    writeJSON(FILE, Data)
    return true
end

-- ============================================================
-- SAVE CONFIG
-- ============================================================
local main = nil
local function saveConfig()
    if main and main.Parent then
        local abs = main.AbsolutePosition
        Data.settings.position = {X = math.floor(abs.X + 0.5), Y = math.floor(abs.Y + 0.5)}
    end
    Data.nextId = Data.nextId or (#Data.tabs + 1)
    writeJSON(FILE, Data)
    triggerCloudSave()
end

-- ============================================================
-- GUI SETUP
-- ============================================================
local function cleanup()
    pcall(function() for _, c in ipairs(game:GetService("CoreGui"):GetChildren()) do if c.Name:match("^Nishgamer") then c:Destroy() end end end)
    for _, c in ipairs(LocalPlayer:WaitForChild("PlayerGui"):GetChildren()) do if c.Name:match("^Nishgamer") then pcall(function() c:Destroy() end) end end
end
cleanup()

local function rgb(t)
    if not t then return Color3.fromRGB(28,28,28) end
    return Color3.fromRGB(math.clamp(t.R or 28,0,255), math.clamp(t.G or 28,0,255), math.clamp(t.B or 28,0,255))
end

local screen
do
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok and cg then
        local s = pcall(function() local t = Instance.new("ScreenGui"); t.Parent = cg; t:Destroy() end)
        if s then screen = Instance.new("ScreenGui"); screen.Name = "Nishgamer_Hub_Screen"; screen.IgnoreGuiInset = true; screen.ResetOnSpawn = Data.settings.resetOnSpawn; screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; screen.Parent = cg end
    end
    if not screen then screen = Instance.new("ScreenGui"); screen.Name = "Nishgamer_Hub_Player"; screen.IgnoreGuiInset = true; screen.ResetOnSpawn = Data.settings.resetOnSpawn; screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; screen.Parent = LocalPlayer:WaitForChild("PlayerGui") end
end
local old = screen:FindFirstChild("Main"); if old then old:Destroy() end

local isTouch = UserInput.TouchEnabled
local function fixText(obj)
    if isTouch or not obj then return end
    if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
        pcall(function() obj.TextScaled = false end)
        pcall(function() obj.TextSize = obj.Name == "title" and 16 or 14 end)
    end
end
screen.DescendantAdded:Connect(function(d) task.defer(fixText, d) end)

main = Instance.new("Frame")
main.Name = "Main"; main.Size = UDim2.fromOffset(420,280)
main.Position = UDim2.new(0, Data.settings.position.X, 0, Data.settings.position.Y)
main.BackgroundColor3 = rgb(Data.settings.mainColor); main.BorderSizePixel = 0; main.Active = true
main.Parent = screen; main.ZIndex = 100

local top = Instance.new("Frame")
top.Size = UDim2.new(1,0,0,28); top.BackgroundColor3 = Color3.fromRGB(40,40,40); top.BorderSizePixel = 0; top.Active = true
top.Parent = main; top.ZIndex = 150

local title = Instance.new("TextLabel")
title.Name = "title"; title.Size = UDim2.new(1,-90,1,0); title.Position = UDim2.new(0,8,0,0)
title.BackgroundTransparency = 1; title.Text = "Nishgamer Hub"; title.Font = Enum.Font.SourceSansBold
title.TextSize = 16; title.TextXAlignment = Enum.TextXAlignment.Left; title.TextColor3 = Color3.fromRGB(245,245,245)
title.Parent = top; title.ZIndex = 151; fixText(title)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0,60,1,0); closeBtn.Position = UDim2.new(1,-64,0,0)
closeBtn.Text = "Close"; closeBtn.Font = Enum.Font.SourceSansBold; closeBtn.TextSize = 14
closeBtn.TextColor3 = Color3.new(1,1,1); closeBtn.BackgroundColor3 = Color3.fromRGB(200,60,60)
closeBtn.BorderSizePixel = 0; closeBtn.Parent = top; closeBtn.ZIndex = 151; fixText(closeBtn)

local openBtn = Instance.new("TextButton")
openBtn.Name = "OpenHub"; openBtn.Size = UDim2.new(0,46,0,20); openBtn.Position = UDim2.new(0,8,0.5,-10)
openBtn.Text = "Hub"; openBtn.Font = Enum.Font.SourceSansBold; openBtn.TextSize = 14
openBtn.TextColor3 = Color3.new(1,1,1); openBtn.BackgroundColor3 = rgb(Data.settings.openColor)
openBtn.BorderSizePixel = 0; openBtn.ZIndex = 200; openBtn.Parent = screen; openBtn.Visible = false; fixText(openBtn)

closeBtn.MouseButton1Click:Connect(function() main.Visible = false; openBtn.Visible = true; Data.settings.lastOpenState = false; saveConfig() end)
openBtn.MouseButton1Click:Connect(function() main.Visible = true; openBtn.Visible = false; Data.settings.lastOpenState = true; saveConfig() end)

local left = Instance.new("ScrollingFrame")
left.Size = UDim2.new(0,120,1,-28); left.Position = UDim2.new(0,0,0,28)
left.BackgroundColor3 = Color3.fromRGB(35,35,35); left.BorderSizePixel = 0; left.ScrollBarThickness = 4
left.ScrollBarImageColor3 = Color3.fromRGB(80,80,80); left.ScrollingDirection = Enum.ScrollingDirection.Y
left.CanvasSize = UDim2.fromOffset(0,220); left.Parent = main; left.ZIndex = 120

local function navBtn(text, y)
    local b = Instance.new("TextButton"); b.Size = UDim2.new(1,0,0,30); b.Position = UDim2.new(0,0,0,y)
    b.Text = text; b.Font = Enum.Font.SourceSansBold; b.TextSize = 14
    b.TextColor3 = Color3.new(1,1,1); b.BackgroundColor3 = Color3.fromRGB(55,55,55)
    b.BorderSizePixel = 0; b.Parent = left; b.ZIndex = 121; fixText(b); return b
end

local bScripts = navBtn("My Scripts", 6)
local bExec = navBtn("Executor", 40)
local bSettings = navBtn("Settings", 74)
local bDesign = navBtn("Design", 108)
local bUtility = navBtn("Utility", 142)
local bMore = navBtn("More", 176)

local content = Instance.new("Frame")
content.Size = UDim2.new(1,-120,1,-28); content.Position = UDim2.new(0,120,0,28)
content.BackgroundTransparency = 1; content.Parent = main; content.ZIndex = 110

local pages = {}
local function mkPage()
    local f = Instance.new("Frame"); f.Size = UDim2.new(1,-10,1,-10); f.Position = UDim2.new(0,5,0,5)
    f.BackgroundTransparency = 1; f.Visible = false; f.Parent = content; f.ZIndex = 130; return f
end

pages["My Scripts"] = mkPage(); pages["Executor"] = mkPage()
pages["Settings"] = mkPage(); pages["Design"] = mkPage()
pages["Utility"] = mkPage()

do
    local scrollPage = Instance.new("ScrollingFrame")
    scrollPage.Size = UDim2.new(1,-10,1,-10); scrollPage.Position = UDim2.new(0,5,0,5)
    scrollPage.BackgroundTransparency = 1; scrollPage.ScrollBarThickness = 4
    scrollPage.ScrollBarImageColor3 = Color3.fromRGB(60,60,60); scrollPage.ScrollingDirection = Enum.ScrollingDirection.Y
    scrollPage.CanvasSize = UDim2.fromOffset(0,700); scrollPage.Parent = content; scrollPage.ZIndex = 130
    pages["More"] = scrollPage
end

local function showPage(n)
    for k,v in pairs(pages) do v.Visible = (k == n) end
    Data.settings.lastSection = n; saveConfig()
end
bScripts.MouseButton1Click:Connect(function() showPage("My Scripts") end)
bExec.MouseButton1Click:Connect(function() showPage("Executor") end)
bSettings.MouseButton1Click:Connect(function() showPage("Settings") end)
bDesign.MouseButton1Click:Connect(function() showPage("Design") end)
bUtility.MouseButton1Click:Connect(function() showPage("Utility") end)
bMore.MouseButton1Click:Connect(function() showPage("More") end)

local startVis = Data.settings.lastOpenState and not Data.settings.startClosed
main.Visible = startVis; openBtn.Visible = not startVis
showPage(Data.settings.lastSection or "My Scripts")

local DRAG_ACTIVE = false; local DRAG_STUCK = false; local LAST_POS = Vector2.new(Data.settings.position.X, Data.settings.position.Y)
local function makeDrag(frame, handle)
    local dragging, dragIn, dragStart, startPos, endC = false, nil, Vector3.new(), Vector3.new(), nil
    handle.InputBegan:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and not Data.settings.screenLock then
            dragging = true; dragIn = input
            if frame == main then DRAG_ACTIVE = true; DRAG_STUCK = false end
            dragStart = input.Position and Vector3.new(input.Position.X, input.Position.Y) or Vector3.new(UserInput:GetMouseLocation().X, UserInput:GetMouseLocation().Y)
            startPos = Vector3.new(frame.AbsolutePosition.X, frame.AbsolutePosition.Y)
            endC = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false; dragIn = nil; if endC then endC:Disconnect(); endC = nil end
                    local cam = workspace and workspace.CurrentCamera
                    if not cam then LAST_POS = startPos
                    else
                        local vs = cam.ViewportSize; local sz = frame.AbsoluteSize
                        local delta = (input.Position and Vector3.new(input.Position.X, input.Position.Y) - dragStart) or (Vector3.new(UserInput:GetMouseLocation().X, UserInput:GetMouseLocation().Y) - dragStart)
                        local np = startPos + delta
                        LAST_POS = Vector3.new(math.clamp(math.floor(np.X+0.5),0,vs.X-sz.X), math.clamp(math.floor(np.Y+0.5),0,vs.Y-sz.Y))
                    end
                    frame.Position = UDim2.fromOffset(LAST_POS.X, LAST_POS.Y)
                    if frame == main then DRAG_STUCK = true; DRAG_ACTIVE = false; saveConfig() end
                end
            end)
        end
    end)
    UserInput.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input == dragIn then
            local cur = input.Position and Vector3.new(input.Position.X, input.Position.Y) or Vector3.new(UserInput:GetMouseLocation().X, UserInput:GetMouseLocation().Y)
            local np = startPos + (cur - dragStart)
            local cam = workspace and workspace.CurrentCamera; if not cam then return end
            local vs = cam.ViewportSize; local sz = frame.AbsoluteSize
            LAST_POS = Vector3.new(math.clamp(math.floor(np.X+0.5),0,vs.X-sz.X), math.clamp(math.floor(np.Y+0.5),0,vs.Y-sz.Y))
            frame.Position = UDim2.fromOffset(LAST_POS.X, LAST_POS.Y)
        end
    end)
end
makeDrag(main, top)

RunService.RenderStepped:Connect(function()
    if DRAG_ACTIVE or DRAG_STUCK then return end
    local cam = workspace and workspace.CurrentCamera; if not cam then return end
    local vs = cam.ViewportSize; local p = main.AbsolutePosition; local s = main.AbsoluteSize
    main.Position = UDim2.fromOffset(math.clamp(math.floor(p.X+0.5),0,vs.X-s.X), math.clamp(math.floor(p.Y+0.5),0,vs.Y-s.Y))
end)
top.InputBegan:Connect(function(input) if not Data.settings.screenLock and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then DRAG_STUCK = false end end)

-- MY SCRIPTS
local list, layout, nameBox, addBtn, searchBox, searchPH, saveBtn, cloudSaveBtn, saveLabel
do
    local pg = pages["My Scripts"]
    nameBox = Instance.new("TextBox", pg); nameBox.Size = UDim2.new(0,130,0,28); nameBox.Position = UDim2.new(0,0,0,0)
    nameBox.PlaceholderText = "New tab name"; nameBox.ClearTextOnFocus = false; nameBox.BackgroundColor3 = Color3.fromRGB(45,45,45)
    nameBox.TextColor3 = Color3.new(1,1,1); nameBox.Font = Enum.Font.SourceSans; nameBox.TextSize = 14; fixText(nameBox)
    addBtn = Instance.new("TextButton", pg); addBtn.Size = UDim2.new(0,55,0,28); addBtn.Position = UDim2.new(0,135,0,0)
    addBtn.Text = "Add"; addBtn.Font = Enum.Font.SourceSansBold; addBtn.TextSize = 14
    addBtn.BackgroundColor3 = rgb(Data.settings.accentColor); addBtn.TextColor3 = Color3.new(1,1,1); fixText(addBtn)
    searchBox = Instance.new("TextBox", pg); searchBox.Size = UDim2.new(0,130,0,22); searchBox.Position = UDim2.new(0,195,0,4)
    searchBox.BackgroundColor3 = Color3.fromRGB(50,50,50); searchBox.TextColor3 = Color3.new(1,1,1)
    searchBox.ClearTextOnFocus = false; searchBox.Text = ""; fixText(searchBox)
    searchPH = Instance.new("TextLabel", pg); searchPH.Size = searchBox.Size; searchPH.Position = searchBox.Position
    searchPH.BackgroundTransparency = 1; searchPH.Text = "Search..."; searchPH.TextColor3 = Color3.fromRGB(170,170,170)
    searchPH.Font = Enum.Font.SourceSans; searchPH.TextXAlignment = Enum.TextXAlignment.Left; searchPH.ZIndex = 160; fixText(searchPH)
    searchBox:GetPropertyChangedSignal("Text"):Connect(function() searchPH.Visible = searchBox.Text == "" end)
    searchBox.Focused:Connect(function() searchPH.Visible = false end)
    searchBox.FocusLost:Connect(function() searchPH.Visible = searchBox.Text == "" end)

    saveBtn = Instance.new("TextButton", pg); saveBtn.Size = UDim2.new(0,55,0,22); saveBtn.Position = UDim2.new(0,195,0,30)
    saveBtn.Text = "Save"; saveBtn.Font = Enum.Font.SourceSansBold; saveBtn.TextSize = 13
    saveBtn.BackgroundColor3 = Color3.fromRGB(70,110,70); saveBtn.TextColor3 = Color3.new(1,1,1); fixText(saveBtn)
    saveLabel = Instance.new("TextLabel", pg); saveLabel.Size = UDim2.new(0,55,0,16); saveLabel.Position = UDim2.new(0,195,0,54)
    saveLabel.BackgroundTransparency = 1; saveLabel.Text = ""; saveLabel.TextColor3 = Color3.fromRGB(85,255,85)
    saveLabel.Font = Enum.Font.SourceSansBold; saveLabel.TextSize = 12; saveLabel.TextXAlignment = Enum.TextXAlignment.Center; fixText(saveLabel)

    cloudSaveBtn = Instance.new("TextButton", pg)
    cloudSaveBtn.Size = UDim2.new(0,85,0,50); cloudSaveBtn.Position = UDim2.new(1,-90,0,36)
    cloudSaveBtn.Text = "Save in\nCloud"; cloudSaveBtn.Font = Enum.Font.SourceSansBold; cloudSaveBtn.TextSize = 12
    cloudSaveBtn.BackgroundColor3 = rgb(Data.settings.accentColor); cloudSaveBtn.TextColor3 = Color3.new(1,1,1)
    cloudSaveBtn.Visible = Data.settings.isKeyValid; cloudSaveBtn.ZIndex = 160; fixText(cloudSaveBtn)

    list = Instance.new("ScrollingFrame", pg); list.Size = UDim2.new(1,-95,1,-38); list.Position = UDim2.new(0,0,0,36)
    list.BackgroundColor3 = Color3.fromRGB(38,38,38); list.BorderSizePixel = 0; list.ScrollBarThickness = 6; list.ZIndex = 155
    layout = Instance.new("UIListLayout", list); layout.Padding = UDim.new(0,6); layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() list.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 12) end)

    saveBtn.MouseButton1Click:Connect(function() saveConfig(); saveLabel.Text = "Saved!"; task.delay(1.5, function() saveLabel.Text = "" end) end)
    cloudSaveBtn.MouseButton1Click:Connect(function()
        cloudSaveBtn.Text = "Saving..."
        task.spawn(function()
            local ok = cloudSaveNow()
            task.defer(function() cloudSaveBtn.Text = ok and "Saved in\nCloud!" or "Failed"; task.delay(2, function() cloudSaveBtn.Text = "Save in\nCloud" end) end)
        end)
    end)
end

local function sanitize(s) s = tostring(s or ""):gsub("^%s+",""):gsub("%s+$","") return s == "" and "Untitled" or s:sub(1,64) end
local function clearList() for _,c in ipairs(list:GetChildren()) do if not c:IsA("UIListLayout") then pcall(function() c:Destroy() end) end end end
local function findIdx(id) for i,t in ipairs(Data.tabs) do if t.id == id then return i end end return nil end

local function renderCard(tab)
    if not tab or not tab.id then return end
    local card = Instance.new("Frame"); card.Size = UDim2.new(1,-10,0,86); card.BackgroundColor3 = Color3.fromRGB(50,50,50)
    card.BorderSizePixel = 0; card.Parent = list; card.ZIndex = 156
    local nm = Instance.new("TextLabel", card); nm.Size = UDim2.new(1,-10,0,20); nm.Position = UDim2.new(0,6,0,6)
    nm.BackgroundTransparency = 1; nm.TextXAlignment = Enum.TextXAlignment.Left; nm.Font = Enum.Font.SourceSansBold
    nm.TextColor3 = Color3.new(1,1,1); nm.Text = tab.name or ("Tab "..tab.id); nm.TextTruncate = Enum.TextTruncate.AtEnd; nm.ZIndex = 157; fixText(nm)
    local execB = Instance.new("TextButton", card); execB.Size = UDim2.new(0,70,0,22); execB.Position = UDim2.new(0,6,0,34)
    execB.Text = "Execute"; execB.BackgroundColor3 = rgb(Data.settings.accentColor); execB.TextColor3 = Color3.new(1,1,1); execB.ZIndex = 157; fixText(execB)
    local editB = Instance.new("TextButton", card); editB.Size = UDim2.new(0,60,0,22); editB.Position = UDim2.new(0,84,0,34)
    editB.Text = "Edit"; editB.BackgroundColor3 = Color3.fromRGB(70,70,110); editB.TextColor3 = Color3.new(1,1,1); editB.ZIndex = 157; fixText(editB)
    local renB = Instance.new("TextButton", card); renB.Size = UDim2.new(0,70,0,22); renB.Position = UDim2.new(0,6,0,60)
    renB.Text = "Rename"; renB.BackgroundColor3 = Color3.fromRGB(110,90,60); renB.TextColor3 = Color3.new(1,1,1); renB.ZIndex = 157; fixText(renB)
    local delB = Instance.new("TextButton", card); delB.Size = UDim2.new(0,56,0,22); delB.Position = UDim2.new(0,84,0,60)
    delB.Text = "Del"; delB.BackgroundColor3 = Color3.fromRGB(150,60,60); delB.TextColor3 = Color3.new(1,1,1); delB.ZIndex = 157; fixText(delB)
    execB.MouseButton1Click:Connect(function()
        local src = tab.code or ""
        if src ~= "" then local loader = loadstring or load; if loader then local ok, fn = pcall(loader, src); if ok and type(fn) == "function" then pcall(fn) elseif not ok then warn("Compile error:", fn) end end end
    end)
    editB.MouseButton1Click:Connect(function()
        local pop = Instance.new("Frame"); pop.Size = UDim2.new(0,420,0,240); pop.Position = UDim2.new(0.5,-210,0.5,-120)
        pop.BackgroundColor3 = Color3.fromRGB(30,30,30); pop.BorderSizePixel = 0; pop.Active = true; pop.Parent = screen; pop.ZIndex = 310
        local h = Instance.new("TextLabel", pop); h.Size = UDim2.new(1,0,0,28); h.BackgroundColor3 = Color3.fromRGB(45,45,45)
        h.Text = "Edit: "..(tab.name or ""); h.TextColor3 = Color3.new(1,1,1); h.Font = Enum.Font.SourceSansBold; h.ZIndex = 311; h.Active = true; fixText(h)
        local box = Instance.new("TextBox", pop); box.Size = UDim2.new(1,-20,1,-110); box.Position = UDim2.new(0,10,0,36)
        box.MultiLine = true; box.ClearTextOnFocus = false; box.Text = tab.code or ""; box.Font = Enum.Font.Code
        box.BackgroundColor3 = Color3.fromRGB(40,40,40); box.TextColor3 = Color3.new(1,1,1); box.ZIndex = 311; fixText(box)
        local saveB = Instance.new("TextButton", pop); saveB.Size = UDim2.new(0.5,-16,0,30); saveB.Position = UDim2.new(0,10,1,-68)
        saveB.Text = "Save"; saveB.BackgroundColor3 = rgb(Data.settings.accentColor); saveB.TextColor3 = Color3.new(1,1,1); saveB.ZIndex = 311; fixText(saveB)
        local closeB = Instance.new("TextButton", pop); closeB.Size = UDim2.new(0.5,-16,0,30); closeB.Position = UDim2.new(0.5,6,1,-68)
        closeB.Text = "Close"; closeB.BackgroundColor3 = Color3.fromRGB(120,60,60); closeB.TextColor3 = Color3.new(1,1,1); closeB.ZIndex = 311; fixText(closeB)
        local clrB = Instance.new("TextButton", pop); clrB.Size = UDim2.new(1,-20,0,26); clrB.Position = UDim2.new(0,10,1,-34)
        clrB.Text = "Clear"; clrB.BackgroundColor3 = Color3.fromRGB(90,90,90); clrB.TextColor3 = Color3.new(1,1,1); clrB.ZIndex = 311; fixText(clrB)
        local autoThr = nil
        local function doSave() tab.code = box.Text; saveConfig() end
        box:GetPropertyChangedSignal("Text"):Connect(function() if autoThr then task.cancel(autoThr) end; autoThr = task.spawn(function() task.wait(0.5); doSave() end) end)
        box.FocusLost:Connect(doSave); clrB.MouseButton1Click:Connect(function() box.Text = ""; doSave() end)
        saveB.MouseButton1Click:Connect(function() doSave(); pop:Destroy(); refreshScripts() end)
        closeB.MouseButton1Click:Connect(function() doSave(); pop:Destroy() end)
        makeDrag(pop, h)
    end)
    renB.MouseButton1Click:Connect(function()
        local pop = Instance.new("Frame"); pop.Size = UDim2.new(0,320,0,120); pop.Position = UDim2.new(0.5,-160,0.5,-60)
        pop.BackgroundColor3 = Color3.fromRGB(30,30,30); pop.Active = true; pop.Parent = screen; pop.ZIndex = 210
        local h = Instance.new("TextLabel", pop); h.Size = UDim2.new(1,0,0,28); h.BackgroundColor3 = Color3.fromRGB(45,45,45)
        h.Text = "Rename Tab"; h.TextColor3 = Color3.new(1,1,1); h.Font = Enum.Font.SourceSansBold; h.Active = true; fixText(h)
        local ni = Instance.new("TextBox", pop); ni.Size = UDim2.new(1,-20,0,28); ni.Position = UDim2.new(0,10,0,36)
        ni.PlaceholderText = "New name"; ni.Text = tab.name or ""; ni.BackgroundColor3 = Color3.fromRGB(40,40,40)
        ni.TextColor3 = Color3.new(1,1,1); ni.Font = Enum.Font.SourceSans; ni.TextSize = 14; fixText(ni)
        local sB = Instance.new("TextButton", pop); sB.Size = UDim2.new(0.5,-14,0,28); sB.Position = UDim2.new(0,10,1,-36)
        sB.Text = "Save"; sB.BackgroundColor3 = rgb(Data.settings.accentColor); sB.TextColor3 = Color3.new(1,1,1); fixText(sB)
        local cB = Instance.new("TextButton", pop); cB.Size = UDim2.new(0.5,-14,0,28); cB.Position = UDim2.new(0.5,14,1,-36)
        cB.Text = "Cancel"; cB.BackgroundColor3 = Color3.fromRGB(120,60,60); cB.TextColor3 = Color3.new(1,1,1); fixText(cB)
        sB.MouseButton1Click:Connect(function() tab.name = sanitize(ni.Text); saveConfig(); refreshScripts(); pop:Destroy() end)
        cB.MouseButton1Click:Connect(function() pop:Destroy() end)
        makeDrag(pop, h)
    end)
    delB.MouseButton1Click:Connect(function()
        if Data.settings.noConfirm then
            local idx = findIdx(tab.id); if idx then table.remove(Data.tabs, idx); saveConfig(); refreshScripts() end
        else
            local pop = Instance.new("Frame"); pop.Size = UDim2.new(0,320,0,120); pop.Position = UDim2.new(0.5,-160,0.5,-60)
            pop.BackgroundColor3 = Color3.fromRGB(30,30,30); pop.Active = true; pop.Parent = screen; pop.ZIndex = 220
            local h = Instance.new("TextLabel", pop); h.Size = UDim2.new(1,0,0,28); h.BackgroundColor3 = Color3.fromRGB(45,45,45)
            h.Text = "Confirm Delete"; h.TextColor3 = Color3.new(1,1,1); h.Font = Enum.Font.SourceSansBold; h.Active = true; fixText(h)
            local m = Instance.new("TextLabel", pop); m.Size = UDim2.new(1,-20,0,28); m.Position = UDim2.new(0,10,0,36)
            m.BackgroundTransparency = 1; m.Text = "Delete '"..(tab.name or "").."'?"; m.TextColor3 = Color3.new(1,1,1); fixText(m)
            local yB = Instance.new("TextButton", pop); yB.Size = UDim2.new(0.5,-14,0,28); yB.Position = UDim2.new(0,10,1,-36)
            yB.Text = "Yes"; yB.BackgroundColor3 = Color3.fromRGB(150,60,60); yB.TextColor3 = Color3.new(1,1,1); fixText(yB)
            local nB = Instance.new("TextButton", pop); nB.Size = UDim2.new(0.5,-14,0,28); nB.Position = UDim2.new(0.5,14,1,-36)
            nB.Text = "No"; nB.BackgroundColor3 = Color3.fromRGB(90,90,90); nB.TextColor3 = Color3.new(1,1,1); fixText(nB)
            yB.MouseButton1Click:Connect(function() local idx = findIdx(tab.id); if idx then table.remove(Data.tabs, idx); saveConfig(); refreshScripts() end; pop:Destroy() end)
            nB.MouseButton1Click:Connect(function() pop:Destroy() end)
            makeDrag(pop, h)
        end
    end)
end

addBtn.MouseButton1Click:Connect(function() local nm = sanitize(nameBox.Text); nameBox.Text = ""; table.insert(Data.tabs, {id=Data.nextId, name=nm, code=""}); Data.nextId = Data.nextId + 1; saveConfig(); refreshScripts() end)
searchBox:GetPropertyChangedSignal("Text"):Connect(refreshScripts)
function refreshScripts()
    clearList()
    local f = tostring(searchBox.Text or ""):lower()
    for _, t in ipairs(Data.tabs) do if f == "" or tostring(t.name or ""):lower():find(f,1,true) then renderCard(t) end end
end
refreshScripts()

-- Executor
do
    local pg = pages["Executor"]
    local box = Instance.new("TextBox", pg); box.Size = UDim2.new(1,-10,1,-48); box.Position = UDim2.new(0,5,0,5)
    box.MultiLine = true; box.ClearTextOnFocus = false; box.Font = Enum.Font.Code
    box.BackgroundColor3 = Color3.fromRGB(40,40,40); box.TextColor3 = Color3.new(1,1,1)
    box.Text = Data.lastExecutor or ""; box.TextSize = 14; fixText(box)
    box.FocusLost:Connect(function() Data.lastExecutor = box.Text; saveConfig() end)
    local execB = Instance.new("TextButton", pg); execB.Size = UDim2.new(0.5,-10,0,28); execB.Position = UDim2.new(0,5,1,-38)
    execB.Text = "Execute"; execB.BackgroundColor3 = rgb(Data.settings.accentColor); execB.TextColor3 = Color3.new(1,1,1); fixText(execB)
    local clrB = Instance.new("TextButton", pg); clrB.Size = UDim2.new(0.5,-10,0,28); clrB.Position = UDim2.new(0.5,5,1,-38)
    clrB.Text = "Clear"; clrB.BackgroundColor3 = Color3.fromRGB(90,90,90); clrB.TextColor3 = Color3.new(1,1,1); fixText(clrB)
    execB.MouseButton1Click:Connect(function()
        local src = box.Text or ""; Data.lastExecutor = src; saveConfig()
        if src ~= "" then local loader = loadstring or load; if loader then local ok, fn = pcall(loader, src); if ok and type(fn) == "function" then pcall(fn) elseif not ok then warn("Compile error:", fn) end end end
    end)
    clrB.MouseButton1Click:Connect(function() box.Text = "" end)
end

-- Settings
do
    local pg = pages["Settings"]
    local function mkToggle(label, key, y)
        local f = Instance.new("Frame", pg); f.Size = UDim2.new(1,-10,0,28); f.Position = UDim2.new(0,5,0,y); f.BackgroundTransparency = 1
        local l = Instance.new("TextLabel", f); l.Size = UDim2.new(0.7,0,1,0); l.BackgroundTransparency = 1
        l.Text = label; l.TextColor3 = Color3.new(1,1,1); l.Font = Enum.Font.SourceSans; l.TextXAlignment = Enum.TextXAlignment.Left; l.TextSize = 14; fixText(l)
        local t = Instance.new("TextButton", f); t.Size = UDim2.new(0,60,0,22); t.Position = UDim2.new(1,-66,0,3)
        t.Text = Data.settings[key] and "On" or "Off"; t.BackgroundColor3 = Data.settings[key] and rgb(Data.settings.accentColor) or Color3.fromRGB(90,90,90)
        t.TextColor3 = Color3.new(1,1,1); t.TextSize = 14; fixText(t)
        t.MouseButton1Click:Connect(function()
            Data.settings[key] = not Data.settings[key]
            t.Text = Data.settings[key] and "On" or "Off"
            t.BackgroundColor3 = Data.settings[key] and rgb(Data.settings.accentColor) or Color3.fromRGB(90,90,90)
            if key == "resetOnSpawn" then screen.ResetOnSpawn = Data.settings.resetOnSpawn
            elseif key == "screenLock" then if Data.settings.screenLock then DRAG_STUCK = true; DRAG_ACTIVE = false end
            elseif key == "startClosed" then main.Visible = not Data.settings.startClosed; openBtn.Visible = Data.settings.startClosed
            elseif key == "antiFling" then if Data.settings.antiFling then enableAntiFling() else disableAntiFling() end end
            saveConfig()
        end)
    end
    mkToggle("Reset on Spawn", "resetOnSpawn", 6)
    mkToggle("Screen Lock", "screenLock", 46)
    mkToggle("No Confirm Delete", "noConfirm", 86)
    mkToggle("Save Position", "savePosition", 126)
    mkToggle("Start Closed", "startClosed", 166)
    mkToggle("Anti Fling", "antiFling", 206)
end

-- Design
do
    local pg = pages["Design"]
    local preview = Instance.new("Frame", pg); preview.Size = UDim2.new(0,100,0,100); preview.Position = UDim2.new(0,5,0,5)
    preview.BackgroundColor3 = rgb(Data.settings.mainColor)
    local accPrev = Instance.new("Frame", preview); accPrev.Size = UDim2.new(0,50,0,50); accPrev.Position = UDim2.new(0.5,-25,0.5,-25)
    accPrev.BackgroundColor3 = rgb(Data.settings.accentColor)
    local genB = Instance.new("TextButton", pg); genB.Size = UDim2.new(0,100,0,28); genB.Position = UDim2.new(0,5,0,110)
    genB.Text = "Generate"; genB.BackgroundColor3 = Color3.fromRGB(90,90,90); genB.TextColor3 = Color3.new(1,1,1); fixText(genB)
    local prevB = Instance.new("TextButton", pg); prevB.Size = UDim2.new(0,50,0,28); prevB.Position = UDim2.new(0,5,0,144)
    prevB.Text = "Prev"; prevB.BackgroundColor3 = Color3.fromRGB(90,90,90); prevB.TextColor3 = Color3.new(1,1,1); fixText(prevB)
    local nextB = Instance.new("TextButton", pg); nextB.Size = UDim2.new(0,50,0,28); nextB.Position = UDim2.new(0,60,0,144)
    nextB.Text = "Next"; nextB.BackgroundColor3 = Color3.fromRGB(90,90,90); nextB.TextColor3 = Color3.new(1,1,1); fixText(nextB)
    local applyB = Instance.new("TextButton", pg); applyB.Size = UDim2.new(0,100,0,28); applyB.Position = UDim2.new(0,5,0,178)
    applyB.Text = "Apply"; applyB.BackgroundColor3 = rgb(Data.settings.accentColor); applyB.TextColor3 = Color3.new(1,1,1); fixText(applyB)
    local function rndC() return {R=math.random(0,255),G=math.random(0,255),B=math.random(0,255)} end
    genB.MouseButton1Click:Connect(function() local c={main=rndC(),accent=rndC()}; table.insert(Data.designHistory,c); Data.designIndex=#Data.designHistory; preview.BackgroundColor3=rgb(c.main); accPrev.BackgroundColor3=rgb(c.accent); saveConfig() end)
    prevB.MouseButton1Click:Connect(function() if Data.designIndex>1 then Data.designIndex=Data.designIndex-1; local c=Data.designHistory[Data.designIndex]; if c then preview.BackgroundColor3=rgb(c.main); accPrev.BackgroundColor3=rgb(c.accent); saveConfig() end end end)
    nextB.MouseButton1Click:Connect(function() if Data.designIndex<#Data.designHistory then Data.designIndex=Data.designIndex+1; local c=Data.designHistory[Data.designIndex]; if c then preview.BackgroundColor3=rgb(c.main); accPrev.BackgroundColor3=rgb(c.accent); saveConfig() end end end)
    applyB.MouseButton1Click:Connect(function() local c=Data.designHistory[Data.designIndex]; if c then Data.settings.mainColor=c.main; Data.settings.accentColor=c.accent; main.BackgroundColor3=rgb(c.main); for _,pg2 in pairs(pages) do for _,o in ipairs(pg2:GetDescendants()) do if o:IsA("TextButton") then o.BackgroundColor3=rgb(c.accent) end end end; for _,o in ipairs(left:GetDescendants()) do if o:IsA("TextButton") then o.BackgroundColor3=rgb(c.accent) end end; saveConfig() end end)
end

-- UTILITY
local aimConn, aimPrevType, aimPrevSub, aimPrevCF = nil, nil, nil, nil
local AIM = Data.settings.aimlock
local antiFlingConn = nil; local lastHRPPos = nil; local antiFlingEnabled = false

local function nearestFromCam()
    local cp; local cam = workspace and workspace.CurrentCamera
    if cam then cp = cam.CFrame.Position else local c = LocalPlayer.Character; if c and c:FindFirstChild("HumanoidRootPart") then cp = c.HumanoidRootPart.Position end end
    if not cp then return nil end
    local bp, bd = nil, math.huge
    for _,p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character.Parent then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart"); local hum = p.Character:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health > 0 then local d = (hrp.Position-cp).Magnitude; if d < bd then bd = d; bp = p end end
        end
    end return bp
end

local function enableAim()
    if aimConn then pcall(function() aimConn:Disconnect() end); aimConn = nil end
    local cam = workspace and workspace.CurrentCamera; if not cam then return end
    pcall(function() aimPrevType=cam.CameraType; aimPrevSub=cam.CameraSubject; aimPrevCF=cam.CFrame end)
    pcall(function() cam.CameraType = Enum.CameraType.Scriptable end)
    aimConn = RunService.RenderStepped:Connect(function()
        if not AIM then return end
        local cam2 = workspace and workspace.CurrentCamera; if not cam2 then return end
        local tp = nearestFromCam()
        if tp and tp.Character then local hrp = tp.Character:FindFirstChild("HumanoidRootPart"); if hrp then pcall(function() cam2.CFrame = CFrame.new(cam2.CFrame.Position, hrp.Position) end) end end
    end)
end

local function disableAim()
    if aimConn then pcall(function() aimConn:Disconnect() end); aimConn = nil end
    local cam = workspace and workspace.CurrentCamera; if not cam then return end
    pcall(function()
        cam.CameraType = aimPrevType or Enum.CameraType.Custom
        if aimPrevSub and aimPrevSub.Parent then cam.CameraSubject = aimPrevSub
        elseif LocalPlayer.Character then local h = LocalPlayer.Character:FindFirstChildOfClass("Humanoid"); if h then cam.CameraSubject = h end end
        if aimPrevCF then cam.CFrame = aimPrevCF end
    end); aimPrevType=nil; aimPrevSub=nil; aimPrevCF=nil
end

local function enableAntiFling()
    if antiFlingConn then pcall(function() antiFlingConn:Disconnect() end); antiFlingConn = nil end
    antiFlingEnabled = true; lastHRPPos = nil
    antiFlingConn = RunService.Heartbeat:Connect(function(dt)
        if not antiFlingEnabled then return end
        local char = LocalPlayer.Character
        if not char then lastHRPPos = nil; return end
        local hrp = char:FindFirstChild("HumanoidRootPart"); local hum = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum or hum.Health <= 0 then lastHRPPos = nil; return end
        local curPos = hrp.Position
        if lastHRPPos then
            local velocity = (curPos - lastHRPPos).Magnitude / math.max(dt, 0.001)
            if velocity > 80 then
                pcall(function() hrp.CFrame = CFrame.new(lastHRPPos); hrp.AssemblyLinearVelocity = Vector3.new(0,0,0); hrp.AssemblyAngularVelocity = Vector3.new(0,0,0) end)
            end
        end
        if hrp.AssemblyLinearVelocity.Y < 60 then lastHRPPos = curPos end
    end)
end

local function disableAntiFling()
    antiFlingEnabled = false
    if antiFlingConn then pcall(function() antiFlingConn:Disconnect() end); antiFlingConn = nil end
    lastHRPPos = nil
end

do
    local pg = pages["Utility"]
    local hdr = Instance.new("TextLabel", pg); hdr.Size = UDim2.new(1,-10,0,20); hdr.Position = UDim2.new(0,5,0,6)
    hdr.BackgroundTransparency = 1; hdr.Text = "Utility"; hdr.Font = Enum.Font.SourceSansBold
    hdr.TextColor3 = Color3.fromRGB(225,225,225); hdr.TextXAlignment = Enum.TextXAlignment.Left; fixText(hdr)

    local aimBtn = Instance.new("TextButton", pg); aimBtn.Size = UDim2.new(0,140,0,30); aimBtn.Position = UDim2.new(0,5,0,36)
    aimBtn.Font = Enum.Font.SourceSansBold; aimBtn.TextSize = 14; aimBtn.TextColor3 = Color3.new(1,1,1); aimBtn.BorderSizePixel = 0; fixText(aimBtn)
    aimBtn.Text = AIM and "Aimlock: On" or "Aimlock: Off"; aimBtn.BackgroundColor3 = AIM and rgb(Data.settings.accentColor) or Color3.fromRGB(90,90,90)
    if AIM then enableAim() end
    aimBtn.MouseButton1Click:Connect(function()
        AIM = not AIM; Data.settings.aimlock = AIM; aimBtn.Text = AIM and "Aimlock: On" or "Aimlock: Off"
        aimBtn.BackgroundColor3 = AIM and rgb(Data.settings.accentColor) or Color3.fromRGB(90,90,90); saveConfig()
        if AIM then enableAim() else disableAim() end
    end)

    local pathBtn = Instance.new("TextButton", pg); pathBtn.Size = UDim2.new(0,140,0,30); pathBtn.Position = UDim2.new(0,5,0,76)
    pathBtn.Font = Enum.Font.SourceSansBold; pathBtn.TextSize = 14; pathBtn.TextColor3 = Color3.new(1,1,1); pathBtn.BorderSizePixel = 0; fixText(pathBtn)
    local PATH = Data.settings.pathfind; pathBtn.Text = PATH and "Pathfind: On" or "Pathfind: Off"; pathBtn.BackgroundColor3 = PATH and rgb(Data.settings.accentColor) or Color3.fromRGB(90,90,90)
    local pathThread, pathCancel, lastManual = nil, false, 0
    local function markManual() lastManual = tick() end
    UserInput.InputBegan:Connect(function(i,p) if p then return end; if i.UserInputType == Enum.UserInputType.Keyboard then local k=i.KeyCode; if k==Enum.KeyCode.W or k==Enum.KeyCode.A or k==Enum.KeyCode.S or k==Enum.KeyCode.D or k==Enum.KeyCode.Space then markManual() end elseif i.UserInputType==Enum.UserInputType.Gamepad1 or i.UserInputType==Enum.UserInputType.Touch then markManual() end end)
    UserInput.InputChanged:Connect(function(i) if i.UserInputType==Enum.UserInputType.Gamepad1 and i.Position and i.Position.Magnitude>0.01 then markManual() elseif i.UserInputType==Enum.UserInputType.Touch then markManual() end end)
    local function getParts(to) local t0=tick(); while tick()-t0<(to or 5) do local c=LocalPlayer.Character; if c then local hrp=c:FindFirstChild("HumanoidRootPart"); local h=c:FindFirstChildOfClass("Humanoid"); if hrp and h and h.Health>0 then return c,h,hrp end end; task.wait(0.2) end; return nil,nil,nil end
    local function nearestFromPos(pos) if not pos then return nil end; local bp,bd=nil,math.huge; for _,p in ipairs(Players:GetPlayers()) do if p~=LocalPlayer and p.Character and p.Character.Parent then local hrp=p.Character:FindFirstChild("HumanoidRootPart"); local h=p.Character:FindFirstChildOfClass("Humanoid"); if hrp and h and h.Health>0 then local d=(hrp.Position-pos).Magnitude; if d<bd then bd=d; bp=p end end end end; return bp end
    local function computePath(a,b) if not a or not b then return nil end; for _,jh in ipairs({8,12,16,24}) do for _,off in ipairs({Vector3.new(0,0,0),Vector3.new(3,0,0),Vector3.new(-3,0,0),Vector3.new(0,0,3),Vector3.new(0,0,-3)}) do local ok,p=pcall(function() local pp=PathfindingService:CreatePath({AgentRadius=2,AgentHeight=5,AgentCanJump=true,AgentJumpHeight=jh,AgentMaxSlope=55}); pp:ComputeAsync(a,b+off); return pp end); if ok and p and p.Status==Enum.PathStatus.Success then return p end end end; local ok,p=pcall(function() local pp=PathfindingService:CreatePath({AgentRadius=2,AgentHeight=5,AgentCanJump=true,AgentJumpHeight=60,AgentMaxSlope=60}); pp:ComputeAsync(a,b); return pp end); if ok and p and p.Status==Enum.PathStatus.Success then return p end; return nil end
    local function followPath(hum,hrp,target) if not hum or not hrp or not target or not target.Character then return false end; local tHRP=target.Character:FindFirstChild("HumanoidRootPart"); local tH=target.Character:FindFirstChildOfClass("Humanoid"); if not tHRP or not tH or tH.Health<=0 then return false end; local path=computePath(hrp.Position,tHRP.Position); if not path then return false end; for _,wp in ipairs(path:GetWaypoints()) do if pathCancel or not PATH then return false end; if not target.Character or not target.Character.Parent then return false end; local cH=target.Character:FindFirstChildOfClass("Humanoid"); if not cH or cH.Health<=0 then return false end; if (tick()-lastManual)<1 then return false end; if wp.Action==Enum.PathWaypointAction.Jump then pcall(function() hum.Jump=true end); task.wait(0.06) end; if hum.Health<=0 then return false end; pcall(function() hum:MoveTo(wp.Position) end); local st=tick(); while tick()-st<10 do if pathCancel or not PATH or not hum or hum.Health<=0 or (tick()-lastManual)<1 then return false end; if (hrp.Position-wp.Position).Magnitude<=5 then break end; task.wait(0.08) end end; return true end
    local function pathLoop() pathCancel=false; while PATH and not pathCancel do local c,h,hrp=getParts(5); if not c then pcall(function() LocalPlayer.CharacterAdded:Wait() end); if pathCancel then break end; c,h,hrp=getParts(5) end; if c and (tick()-lastManual)>=1 then local t=nearestFromPos(hrp.Position); if t then pcall(function() followPath(h,hrp,t) end) end end; task.wait(0.25) end; pathThread=nil end
    local function startPath() if pathThread then return end; pathCancel=false; PATH=true; Data.settings.pathfind=true; saveConfig(); pathThread=task.spawn(function() pcall(pathLoop); pathThread=nil end) end
    local function stopPath() pathCancel=true; PATH=false; Data.settings.pathfind=false; saveConfig(); local w=0; while pathThread and w<1.2 do task.wait(0.08); w=w+0.08 end end
    if PATH then startPath() end
    pathBtn.MouseButton1Click:Connect(function() if PATH then stopPath(); pathBtn.Text="Pathfind: Off"; pathBtn.BackgroundColor3=Color3.fromRGB(90,90,90) else pathBtn.Text="Pathfind: On"; pathBtn.BackgroundColor3=rgb(Data.settings.accentColor); startPath() end end)

    local flingBtn = Instance.new("TextButton", pg); flingBtn.Size = UDim2.new(0,140,0,30); flingBtn.Position = UDim2.new(0,5,0,116)
    flingBtn.Font = Enum.Font.SourceSansBold; flingBtn.TextSize = 14; flingBtn.TextColor3 = Color3.new(1,1,1); flingBtn.BorderSizePixel = 0; fixText(flingBtn)
    flingBtn.Text = Data.settings.antiFling and "Anti Fling: On" or "Anti Fling: Off"
    flingBtn.BackgroundColor3 = Data.settings.antiFling and rgb(Data.settings.accentColor) or Color3.fromRGB(90,90,90)
    if Data.settings.antiFling then enableAntiFling() end
    flingBtn.MouseButton1Click:Connect(function()
        Data.settings.antiFling = not Data.settings.antiFling
        flingBtn.Text = Data.settings.antiFling and "Anti Fling: On" or "Anti Fling: Off"
        flingBtn.BackgroundColor3 = Data.settings.antiFling and rgb(Data.settings.accentColor) or Color3.fromRGB(90,90,90)
        if Data.settings.antiFling then enableAntiFling() else disableAntiFling() end
        saveConfig()
    end)

    LocalPlayer.CharacterAdded:Connect(function()
        task.delay(0.3, function()
            pcall(disableAim); lastHRPPos = nil
            if Data.settings.pathfind and not pathThread then task.delay(0.6, startPath) end
            if Data.settings.antiFling then task.delay(0.5, enableAntiFling) end
            if Data.settings.aimlock then AIM=true; task.delay(0.25, function() if workspace and workspace.CurrentCamera then enableAim() end; aimBtn.Text="Aimlock: On"; aimBtn.BackgroundColor3=rgb(Data.settings.accentColor) end) else AIM=false; disableAim(); aimBtn.Text="Aimlock: Off"; aimBtn.BackgroundColor3=Color3.fromRGB(90,90,90) end
        end)
    end)
    LocalPlayer.CharacterRemoving:Connect(function() pcall(disableAim); lastHRPPos = nil end)
    Players.PlayerRemoving:Connect(function(p) if p==LocalPlayer then pathCancel=true; pcall(disableAim); disableAntiFling() end end)
end

-- MORE PAGE
do
    local pg = pages["More"]
    local hdr = Instance.new("TextLabel", pg); hdr.Size = UDim2.new(1,0,0,20); hdr.Position = UDim2.new(0,0,0,0)
    hdr.BackgroundTransparency = 1; hdr.Text = "More"; hdr.Font = Enum.Font.SourceSansBold
    hdr.TextColor3 = Color3.fromRGB(225,225,225); hdr.TextXAlignment = Enum.TextXAlignment.Left; fixText(hdr)

    local ksFrame = Instance.new("Frame", pg); ksFrame.Size = UDim2.new(1,0,0,185); ksFrame.Position = UDim2.new(0,0,0,25)
    ksFrame.BackgroundColor3 = Color3.fromRGB(40,40,40); ksFrame.BorderSizePixel = 0; ksFrame.ZIndex = 140
    local ksTitle = Instance.new("TextLabel", ksFrame); ksTitle.Size = UDim2.new(1,0,0,25); ksTitle.Position = UDim2.new(0,0,0,0)
    ksTitle.BackgroundTransparency = 1; ksTitle.Text = "Key System"; ksTitle.Font = Enum.Font.SourceSansBold
    ksTitle.TextColor3 = Color3.new(1,1,1); ksTitle.TextSize = 16; ksTitle.TextXAlignment = Enum.TextXAlignment.Center; fixText(ksTitle)
    local ksInput = Instance.new("TextBox", ksFrame); ksInput.Size = UDim2.new(1,-10,0,30); ksInput.Position = UDim2.new(0,5,0,30)
    ksInput.PlaceholderText = "Enter Key..."; ksInput.Text = Data.settings.validKey or ""
    ksInput.BackgroundColor3 = Color3.fromRGB(60,60,60); ksInput.TextColor3 = Color3.new(1,1,1)
    ksInput.ClearTextOnFocus = false; ksInput.Font = Enum.Font.SourceSans; ksInput.TextSize = 14; fixText(ksInput)
    local btnC = Instance.new("Frame", ksFrame); btnC.Size = UDim2.new(1,-10,0,25); btnC.Position = UDim2.new(0,5,0,65); btnC.BackgroundTransparency = 1
    local ksCheck = Instance.new("TextButton", btnC); ksCheck.Size = UDim2.new(0.5,-2,1,0); ksCheck.Position = UDim2.new(0,0,0,0)
    ksCheck.Text = "Check Key"; ksCheck.BackgroundColor3 = rgb(Data.settings.accentColor); ksCheck.TextColor3 = Color3.new(1,1,1)
    ksCheck.Font = Enum.Font.SourceSansBold; ksCheck.TextSize = 14; fixText(ksCheck)
    local ksGet = Instance.new("TextButton", btnC); ksGet.Size = UDim2.new(0.5,-2,1,0); ksGet.Position = UDim2.new(0.5,2,0,0)
    ksGet.Text = "Get Key"; ksGet.BackgroundColor3 = Color3.fromRGB(70,70,70); ksGet.TextColor3 = Color3.new(1,1,1)
    ksGet.Font = Enum.Font.SourceSansBold; ksGet.TextSize = 14; fixText(ksGet)
    local ksStatus = Instance.new("TextLabel", ksFrame); ksStatus.Size = UDim2.new(1,0,0,20); ksStatus.Position = UDim2.new(0,0,0,95)
    ksStatus.BackgroundTransparency = 1; ksStatus.Text = ""; ksStatus.TextColor3 = Color3.fromRGB(200,200,200)
    ksStatus.Font = Enum.Font.SourceSans; ksStatus.TextSize = 14; ksStatus.TextXAlignment = Enum.TextXAlignment.Center; fixText(ksStatus)
    if Data.settings.isKeyValid then ksStatus.Text = "Validated (saved)"; ksStatus.TextColor3 = Color3.fromRGB(85,255,85) end

    local cloudMsg = Instance.new("TextLabel", ksFrame); cloudMsg.Size = UDim2.new(1,0,0,22); cloudMsg.Position = UDim2.new(0,0,0,117)
    cloudMsg.BackgroundTransparency = 1; cloudMsg.Text = "your scripts will be saved in the server :)!!"
    cloudMsg.TextColor3 = Color3.fromRGB(100,220,255); cloudMsg.Font = Enum.Font.SourceSansBold
    cloudMsg.TextSize = 13; cloudMsg.TextXAlignment = Enum.TextXAlignment.Center; cloudMsg.Visible = Data.settings.isKeyValid; fixText(cloudMsg)

    local ksClear = Instance.new("TextButton", ksFrame); ksClear.Size = UDim2.new(1,-10,0,22); ksClear.Position = UDim2.new(0,5,0,143)
    ksClear.Text = "Clear Saved Key"; ksClear.BackgroundColor3 = Color3.fromRGB(120,60,60); ksClear.TextColor3 = Color3.new(1,1,1)
    ksClear.Font = Enum.Font.SourceSans; ksClear.TextSize = 13; fixText(ksClear)

    local profFrame = Instance.new("Frame", pg); profFrame.Size = UDim2.new(1,0,0,130); profFrame.Position = UDim2.new(0,0,0,215)
    profFrame.BackgroundColor3 = Color3.fromRGB(40,40,40); profFrame.BorderSizePixel = 0; profFrame.ZIndex = 140
    profFrame.Visible = Data.settings.isKeyValid
    local profHdr = Instance.new("TextLabel", profFrame); profHdr.Size = UDim2.new(1,0,0,25); profHdr.Position = UDim2.new(0,0,0,0)
    profHdr.BackgroundTransparency = 1; profHdr.Text = "Profile"; profHdr.Font = Enum.Font.SourceSansBold
    profHdr.TextColor3 = Color3.new(1,1,1); profHdr.TextSize = 16; profHdr.TextXAlignment = Enum.TextXAlignment.Center; fixText(profHdr)
    local profAvatar = Instance.new("ImageLabel", profFrame); profAvatar.Size = UDim2.new(0,60,0,60); profAvatar.Position = UDim2.new(0,10,0,35)
    profAvatar.BackgroundColor3 = Color3.fromRGB(80,80,80); profAvatar.Image = "rbxassetid://0"; profAvatar.ZIndex = 145
    Instance.new("UICorner", profAvatar).CornerRadius = UDim.new(1,0)
    local profName = Instance.new("TextLabel", profFrame); profName.Size = UDim2.new(1,-80,0,20); profName.Position = UDim2.new(0,80,0,35)
    profName.BackgroundTransparency = 1; profName.Text = "Username: "..LocalPlayer.Name; profName.TextColor3 = Color3.new(1,1,1)
    profName.Font = Enum.Font.SourceSansBold; profName.TextSize = 14; profName.TextXAlignment = Enum.TextXAlignment.Left; fixText(profName)
    local profCreated = Instance.new("TextLabel", profFrame); profCreated.Size = UDim2.new(1,-80,0,20); profCreated.Position = UDim2.new(0,80,0,60)
    profCreated.BackgroundTransparency = 1; profCreated.Text = "Loading..."; profCreated.TextColor3 = Color3.fromRGB(200,200,200)
    profCreated.Font = Enum.Font.SourceSans; profCreated.TextSize = 13; profCreated.TextXAlignment = Enum.TextXAlignment.Left; fixText(profCreated)
    local profOnline = Instance.new("TextLabel", profFrame); profOnline.Size = UDim2.new(1,-80,0,20); profOnline.Position = UDim2.new(0,80,0,80)
    profOnline.BackgroundTransparency = 1; profOnline.Text = "Last Online: Checking..."; profOnline.TextColor3 = Color3.fromRGB(200,200,200)
    profOnline.Font = Enum.Font.SourceSans; profOnline.TextSize = 13; profOnline.TextXAlignment = Enum.TextXAlignment.Left; fixText(profOnline)

    local function loadProfile()
        local ok, img = pcall(function() return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150) end)
        if ok then profAvatar.Image = img end
        local ts = os.time() - (LocalPlayer.AccountAge * 86400); profCreated.Text = "Created: " .. os.date("%d/%m/%Y", ts)
        local sOk, sData = supabaseGet(TABLE_USERS, {username = "eq."..HttpService:UrlEncode(LocalPlayer.Name), select = "last_online"})
        if sOk and type(sData) == "table" and #sData > 0 and sData[1].last_online then
            profOnline.Text = "Last Online: " .. tostring(sData[1].last_online)
        else profOnline.Text = "Last Online: Now" end
    end

    local function syncUser()
        local gameName = "Unknown Game"
        local pOk, pInfo = pcall(function() return MarketplaceService:GetProductInfo(game.PlaceId) end)
        if pOk and pInfo then gameName = pInfo.Name end
        local payload = {username = LocalPlayer.Name, last_game = gameName, last_online = os.date("%Y-%m-%d %H:%M:%S")}
        local cOk, cData = supabaseGet(TABLE_USERS, {username = "eq."..HttpService:UrlEncode(LocalPlayer.Name), select = "id"})
        if cOk and type(cData) == "table" and #cData > 0 then
            supabasePatch(TABLE_USERS, {id = "eq."..tostring(cData[1].id)}, payload)
        else
            supabasePost(TABLE_USERS, payload)
        end
    end

    ksCheck.MouseButton1Click:Connect(function()
        local inputKey = ksInput.Text
        ksStatus.Text = "Checking..."; ksStatus.TextColor3 = Color3.fromRGB(255,255,255)
        ksCheck.Text = "..."; ksCheck.Active = false
        task.spawn(function()
            local isValid, message = checkKey(inputKey)
            task.defer(function()
                ksCheck.Text = "Check Key"; ksCheck.Active = true
                if isValid then
                    ksStatus.Text = "Valid! Saved to config."; ksStatus.TextColor3 = Color3.fromRGB(85,255,85)
                    Data.settings.isKeyValid = true; Data.settings.validKey = inputKey; saveConfig()
                    cloudMsg.Visible = true; profFrame.Visible = true; cloudSaveBtn.Visible = true
                    syncUser(); loadProfile()
                    task.spawn(function() local loaded = cloudLoad(); if loaded then refreshScripts() end; if not loaded then cloudSaveNow() end end)
                else
                    ksStatus.Text = message; ksStatus.TextColor3 = Color3.fromRGB(255,85,85)
                    if Data.settings.isKeyValid then
                        Data.settings.isKeyValid = false; Data.settings.validKey = ""
                        cloudMsg.Visible = false; profFrame.Visible = false; cloudSaveBtn.Visible = false; saveConfig()
                    end
                end
            end)
        end)
    end)

    ksGet.MouseButton1Click:Connect(function()
        local url = "https://key-231.oneapp.dev/"
        if setclipboard then setclipboard(url); ksStatus.Text = "URL Copied!"; ksStatus.TextColor3 = Color3.fromRGB(85,255,85)
        else ksStatus.Text = "Clipboard unsupported"; ksStatus.TextColor3 = Color3.fromRGB(255,170,0) end
    end)

    ksClear.MouseButton1Click:Connect(function()
        Data.settings.isKeyValid = false; Data.settings.validKey = ""
        cloudMsg.Visible = false; profFrame.Visible = false; cloudSaveBtn.Visible = false
        ksInput.Text = ""; ksStatus.Text = "Key cleared"; ksStatus.TextColor3 = Color3.fromRGB(255,170,0); saveConfig()
    end)

    if Data.settings.isKeyValid then
        profFrame.Visible = true; cloudMsg.Visible = true; cloudSaveBtn.Visible = true
        task.spawn(function() local loaded = cloudLoad(); if loaded then refreshScripts() end; loadProfile() end)
    end
end

task.spawn(function() while true do task.wait(60); saveConfig() end end)
print("[Nishgamer Hub] V8 Final Loaded")
