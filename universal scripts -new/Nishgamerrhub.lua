-- Nishgamer Hub — Full Single-File LocalScript
-- Features: Drag Fix, Instant Save, Key System, More (Auto Run), and NEW Secret Feature.
-- "More" section included as requested.

local Players             = game:GetService("Players")
local RunService          = game:GetService("RunService")
local UserInput           = game:GetService("UserInputService")
local HttpService         = game:GetService("HttpService")
local PathfindingService  = game:GetService("PathfindingService")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

-- Persistence helpers
local HAS_FS = (type(isfile) == "function") and (type(readfile) == "function") and (type(writefile) == "function")

-- Custom Save Path Configuration
local FOLDER_NAME = "Nishgamerrhub"
local FILE_NAME = "Nishgamerrhub.json"
local DATA_FILE = FOLDER_NAME .. "/" .. FILE_NAME

if HAS_FS and type(makefolder) == "function" then
    if not isfolder(FOLDER_NAME) then
        pcall(makefolder, FOLDER_NAME)
    end
end

local function safeReadJSON(path)
    if not HAS_FS then return nil end
    local lockPath = path .. ".lock"
    local retries = 5
    while isfile(lockPath) and retries > 0 do
        task.wait(0.05)
        retries = retries - 1
    end
    if not isfile(path) then return nil end
    local ok, raw = pcall(readfile, path)
    if not ok or type(raw) ~= "string" then return nil end
    local ok2, tbl = pcall(function() return HttpService:JSONDecode(raw) end)
    if ok2 and type(tbl) == "table" then return tbl end
    return nil
end

local function safeWriteJSON(path, tbl)
    if not HAS_FS then return end
    local lockPath = path .. ".lock"
    local retries = 10
    while isfile(lockPath) and retries > 0 do
        task.wait(0.05)
        retries = retries - 1
    end
    if isfile(lockPath) then return end
    local ok_lock = pcall(writefile, lockPath, "lock")
    if not ok_lock then return end
    local ok, enc = pcall(function() return HttpService:JSONEncode(tbl) end)
    if ok and type(enc) == "string" then
        local ok_write = pcall(writefile, path, enc)
        pcall(delfile, lockPath)
        return ok_write
    end
    pcall(delfile, lockPath)
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

local DefaultData = {
    settings = {
        resetOnSpawn = false,
        screenLock   = false,
        noConfirm    = false,
        lastSection  = "Key System",
        position     = { X = 60, Y = 10 },
        mainColor    = { R = 28, G = 28, B = 28 },
        accentColor  = { R = 60, G = 120, B = 60 },
        openColor    = { R = 45, G = 45, B = 45 },
        savePosition = true,
        startClosed  = false,
        lastOpenState = false,
        aimlock      = false,
        pathfind     = false,
        autoRunLoader = false,
    },
    tabs = {},
    nextId = 1,
    designHistory = {},
    designIndex = 0,
    lastExecutor = "",
    whitelisted = false,
    secretCode = "",
}
local Data = readPersist() or DefaultData
Data.settings = Data.settings or DefaultData.settings
Data.tabs = Data.tabs or {}
Data.nextId = Data.nextId or DefaultData.nextId
Data.designHistory = Data.designHistory or DefaultData.designHistory
Data.designIndex = Data.designIndex or DefaultData.designIndex
Data.lastExecutor = Data.lastExecutor or DefaultData.lastExecutor
Data.whitelisted = Data.whitelisted or false
Data.settings.autoRunLoader = Data.settings.autoRunLoader or false
Data.settings.secretCode = Data.settings.secretCode or ""

-- Coerce saved position
do
    local p = Data.settings.position or {}
    local x = tonumber(p.X) or tonumber((p.X or 0)) or DefaultData.settings.position.X
    local y = tonumber(p.Y) or tonumber((p.Y or 0)) or DefaultData.settings.position.Y
    Data.settings.position = { X = math.floor(x + 0.5), Y = math.floor(y + 0.5) }
end

-- Ensure nextId doesn't collide
do
    local maxId = 0
    for _, t in ipairs(Data.tabs) do
        if type(t.id) == "number" and t.id > maxId then maxId = t.id end
    end
    if Data.nextId <= maxId then Data.nextId = maxId + 1 end
end

local function Save()
    Data.nextId = Data.nextId or (#Data.tabs + 1)
    writePersist(Data)
end

local function cleanupOldGUIs()
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

local function rgbToColor3(t)
    if not t then return Color3.fromRGB(28,28,28) end
    return Color3.fromRGB(math.clamp(t.R or 28,0,255), math.clamp(t.G or 28,0,255), math.clamp(t.B or 28,0,255))
end

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

local oldMain = screen:FindFirstChild("Main")
if oldMain then oldMain:Destroy() end

local isTouchDevice = UserInput.TouchEnabled

local function chooseDesktopTextSize(obj)
    local cur = obj.TextSize or 14
    if obj.Name == "title" then return 16 end
    if obj:IsA("TextBox") then return 14 end
    return math.clamp(cur >= 12 and cur or 14, 12, 16)
end

local function enforceDesktopText(obj)
    if isTouchDevice then return end
    if not obj then return end
    if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
        pcall(function() obj.TextScaled = false end)
        local ts = chooseDesktopTextSize(obj)
        pcall(function() obj.TextSize = ts end)
    end
end

local function enforceDesktopTextRecursively(parent)
    if not parent then return end
    for _, v in ipairs(parent:GetDescendants()) do
        enforceDesktopText(v)
    end
end

screen.DescendantAdded:Connect(function(desc)
    task.defer(function() enforceDesktopText(desc) end)
end)

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
enforceDesktopText(openBtn)

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(420,280)
main.Position = UDim2.new(0, Data.settings.position.X or 60, 0, Data.settings.position.Y or 10)
main.BackgroundColor3 = rgbToColor3(Data.settings.mainColor)
main.BorderSizePixel = 0
main.Active = true
main.Parent = screen
main.ZIndex = 100

local top = Instance.new("Frame")
top.Size = UDim2.new(1,0,0,28)
top.BackgroundColor3 = Color3.fromRGB(40,40,40)
top.BorderSizePixel = 0
top.Active = true
top.Parent = main
top.ZIndex = 150

local title = Instance.new("TextLabel")
title.Name = "title"
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
enforceDesktopText(title)

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
enforceDesktopText(closeBtn)

closeBtn.MouseButton1Click:Connect(function()
    main.Visible = false
    openBtn.Visible = true
    if not Data.settings.startClosed then
        Data.settings.lastOpenState = false
    end
    if Data.settings.savePosition then
        local abs = main.AbsolutePosition
        Data.settings.position = { X = math.floor(abs.X + 0.5), Y = math.floor(abs.Y + 0.5) }
    end
    Save()
end)

openBtn.MouseButton1Click:Connect(function()
    main.Visible = true
    openBtn.Visible = false
    if not Data.settings.startClosed then
        Data.settings.lastOpenState = true
        Save()
    end
end)

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
    enforceDesktopText(b)
    return b
end

local btnScripts = mkNavBtn("My Scripts", 6)
local btnExec    = mkNavBtn("Executor", 40)
local btnSettings= mkNavBtn("Settings", 74)
local btnDesign  = mkNavBtn("Design", 108)
local btnUtility = mkNavBtn("Utility", 142)
local btnKeySys  = mkNavBtn("Key System", 176)
local btnMore    = mkNavBtn("More", 210) -- RESTORED
local btnSecret = mkNavBtn("Secret", 244)   -- RESTORED

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
pages["Utility"]    = newPage()
pages["Key System"] = newPage()
pages["More"]       = newPage()    -- RESTORED
pages["Secret"]      = newPage()    -- NEW

local function showPage(name)
    for k,v in pairs(pages) do v.Visible = (k == name) end
    Data.settings.lastSection = name
    Save()
end

btnScripts.MouseButton1Click:Connect(function() showPage("My Scripts") end)
btnExec.MouseButton1Click:Connect(function() showPage("Executor") end)
btnSettings.MouseButton1Click:Connect(function() showPage("Settings") end)
btnDesign.MouseButton1Click:Connect(function() showPage("Design") end)
btnUtility.MouseButton1Click:Connect(function() showPage("Utility") end)
btnKeySys.MouseButton1Click:Connect(function() showPage("Key System") end)
btnMore.MouseButton1Click:Connect(function() showPage("More") end) -- RESTORED
btnSecret.MouseButton1Click:Connect(function() showPage("Secret") end) -- NEW

local useLastOnStart = not Data.settings.startClosed
local startVisibleOnStart = useLastOnStart and (Data.settings.lastOpenState ~= nil and Data.settings.lastOpenState or false) or false
main.Visible = startVisibleOnStart
openBtn.Visible = not startVisibleOnStart

if Data.whitelisted then
    showPage(Data.settings.lastSection or "My Scripts")
else
    showPage("Key System")
end

-- Dragging state + stick-on-release (FIXED)
local MAIN_DRAG_ACTIVE = false
local MAIN_STICKED = false
local LAST_DRAG_POS = Vector2.new( Data.settings.position.X or 60, Data.settings.position.Y or 10 )

local function makeDraggable(frame, handle, opts)
    opts = opts or {}
    local saveOnEnd = opts.saveOnEnd or false

    local dragging = false
    local dragInput = nil
    local dragStart = Vector2.new()
    local startPos = Vector2.new()
    local endConn

    handle.InputBegan:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and not Data.settings.screenLock then
            dragging = true
            dragInput = input
            if frame == main then
                MAIN_DRAG_ACTIVE = true
                MAIN_STICKED = false
            end
            if input.Position then
                dragStart = Vector2.new(input.Position.X, input.Position.Y)
            else
                dragStart = UserInput:GetMouseLocation()
            end
            local abs = frame.AbsolutePosition
            startPos = Vector2.new(abs.X, abs.Y)
            endConn = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    dragInput = nil
                    if endConn then endConn:Disconnect(); endConn = nil end

                    local cam = workspace and workspace.CurrentCamera
                    if not cam then
                        LAST_DRAG_POS = startPos
                    else
                        local vs = cam.ViewportSize
                        local sz = frame.AbsoluteSize
                        local delta = (input.Position and (Vector2.new(input.Position.X, input.Position.Y) - dragStart)) or (UserInput:GetMouseLocation() - dragStart)
                        local newPos = startPos + delta
                        local minX = math.min(0, vs.X - sz.X)
                        local maxX = math.max(0, vs.X - sz.X)
                        local minY = math.min(0, vs.Y - sz.Y)
                        local maxY = math.max(0, vs.Y - sz.Y)
                        local x = math.clamp(math.floor(newPos.X + 0.5), minX, maxX)
                        local y = math.clamp(math.floor(newPos.Y + 0.5), minY, maxY)
                        LAST_DRAG_POS = Vector2.new(x, y)
                    end

                    frame.Position = UDim2.fromOffset(LAST_DRAG_POS.X, LAST_DRAG_POS.Y)

                    if frame == main then
                        MAIN_STICKED = true
                        MAIN_DRAG_ACTIVE = false
                    end

                    if saveOnEnd and Data.settings.savePosition and frame == main then
                        Data.settings.position = { X = LAST_DRAG_POS.X, Y = LAST_DRAG_POS.Y }
                        Save()
                    end
                end
            end)
        end
    end)

    UserInput.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input == dragInput then
            local current
            if input.Position then
                current = Vector2.new(input.Position.X, input.Position.Y)
            else
                current = UserInput:GetMouseLocation()
            end

            local delta = current - dragStart
            local newPos = startPos + delta

            local cam = workspace and workspace.CurrentCamera
            if not cam then return end
            local vs = cam.ViewportSize
            local sz = frame.AbsoluteSize

            local minX = math.min(0, vs.X - sz.X)
            local maxX = math.max(0, vs.X - sz.X)
            local minY = math.min(0, vs.Y - sz.Y)
            local maxY = math.max(0, vs.Y - sz.Y)

            local x = math.clamp(math.floor(newPos.X + 0.5), minX, maxX)
            local y = math.clamp(math.floor(newPos.Y + 0.5), minY, maxY)

            local finalPos = Vector2.new(x, y)
            frame.Position = UDim2.fromOffset(finalPos.X, finalPos.Y)
            LAST_DRAG_POS = finalPos
        end
    end)
end

makeDraggable(main, top, { saveOnEnd = true })

RunService.RenderStepped:Connect(function()
    if MAIN_DRAG_ACTIVE then return end
    if MAIN_STICKED then return end
    local cam = workspace and workspace.CurrentCamera
    if not cam then return end
    local vs = cam.ViewportSize
    local pos = main.AbsolutePosition
    local sz = main.AbsoluteSize

    local minX = math.min(0, vs.X - sz.X)
    local maxX = math.max(0, vs.X - sz.X)
    local minY = math.min(0, vs.Y - sz.Y)
    local maxY = math.max(0, vs.Y - sz.Y)

    local x = math.clamp(pos.X, minX, maxX)
    local y = math.clamp(pos.Y, minY, maxY)

    main.Position = UDim2.fromOffset(math.floor(x+0.5), math.floor(y+0.5))
end)

top.InputBegan:Connect(function(input)
    if Data.settings.screenLock then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        MAIN_STICKED = false
    end
end)

if not isTouchDevice then
    enforceDesktopTextRecursively(screen)
    for i=1,3 do
        task.delay(i*0.05, function() enforceDesktopTextRecursively(screen) end)
    end
end

local function findIndexById(id)
    for i,t in ipairs(Data.tabs) do if t.id == id then return i end end
    return nil
end

-- ---------- KEY SYSTEM ----------
do
    local page = pages["Key System"]
    local HTML_URL = "https://key-231.oneapp.dev/" 
    local info = Instance.new("TextLabel", page)
    info.Size = UDim2.new(1,0,0,60)
    info.Position = UDim2.new(0,0,0,10)
    info.BackgroundTransparency = 1
    info.Text = "Welcome to Nishgamer Hub.\nPlease get a key to continue."
    info.TextColor3 = Color3.new(1,1,1)
    info.TextWrapped = true
    info.Font = Enum.Font.SourceSansBold
    info.TextSize = 16
    info.ZIndex = 150
    enforceDesktopText(info)

    local getKeyBtn = Instance.new("TextButton", page)
    getKeyBtn.Size = UDim2.new(0,150,0,30)
    getKeyBtn.Position = UDim2.new(0.5, -75, 0, 80)
    getKeyBtn.Text = "Get Key Link"
    getKeyBtn.Font = Enum.Font.SourceSansBold
    getKeyBtn.TextSize = 14
    getKeyBtn.TextColor3 = Color3.new(1,1,1)
    getKeyBtn.BackgroundColor3 = rgbToColor3(Data.settings.accentColor)
    getKeyBtn.BorderSizePixel = 0
    getKeyBtn.ZIndex = 150
    enforceDesktopText(getKeyBtn)

    local inputLabel = Instance.new("TextLabel", page)
    inputLabel.Size = UDim2.new(0,200,0,20)
    inputLabel.Position = UDim2.new(0.5, -100, 0, 130)
    inputLabel.BackgroundTransparency = 1
    inputLabel.Text = "Enter Key:"
    inputLabel.TextColor3 = Color3.new(1,1,1)
    inputLabel.Font = Enum.Font.SourceSans
    inputLabel.TextSize = 14
    inputLabel.ZIndex = 150
    enforceDesktopText(inputLabel)

    local keyInput = Instance.new("TextBox", page)
    keyInput.Size = UDim2.new(0,200,0,30)
    keyInput.Position = UDim2.new(0.5, -100, 0, 155)
    keyInput.PlaceholderText = "Paste key here..."
    keyInput.BackgroundColor3 = Color3.fromRGB(40,40,40)
    keyInput.TextColor3 = Color3.new(1,1,1)
    keyInput.Font = Enum.Font.SourceSans
    keyInput.TextSize = 14
    keyInput.ClearTextOnFocus = false
    keyInput.ZIndex = 150
    enforceDesktopText(keyInput)

    local checkBtn = Instance.new("TextButton", page)
    checkBtn.Size = UDim2.new(0,200,0,30)
    checkBtn.Position = UDim2.new(0.5, -100, 0, 200)
    checkBtn.Text = "Check Key"
    checkBtn.Font = Enum.Font.SourceSansBold
    checkBtn.TextSize = 14
    checkBtn.TextColor3 = Color3.new(1,1,1)
    checkBtn.BackgroundColor3 = Color3.fromRGB(70,70,110)
    checkBtn.BorderSizePixel = 0
    checkBtn.ZIndex = 150
    enforceDesktopText(checkBtn)

    local statusLabel = Instance.new("TextLabel", page)
    statusLabel.Size = UDim2.new(1,0,0,30)
    statusLabel.Position = UDim2.new(0,0,0,240)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = ""
    statusLabel.TextColor3 = Color3.new(1,1,1)
    statusLabel.Font = Enum.Font.SourceSansBold
    statusLabel.TextSize = 14
    statusLabel.ZIndex = 150
    enforceDesktopText(statusLabel)

    if Data.whitelisted then
        info.Text = "Welcome Back!\nAccess Granted."
        getKeyBtn.Visible = false
        inputLabel.Visible = false
        keyInput.Visible = false
        checkBtn.Visible = false
    end

    getKeyBtn.MouseButton1Click:Connect(function()
        local success, err = pcall(function()
            setclipboard(HTML_URL)
        end)
        
        if success then
            statusLabel.Text = "Link copied to clipboard!"
            statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
        else
            -- FALLBACK IF EXECUTOR BLOCKS CLIPBOARD
            keyInput.Text = HTML_URL
            statusLabel.Text = "Clipboard blocked! Link in box above."
            statusLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
            keyInput:FocusLost()
            keyInput:CaptureFocus()
        end
    end)

    checkBtn.MouseButton1Click:Connect(function()
        local key = keyInput.Text
        if key == "" then
            statusLabel.Text = "Please enter a key."
            statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            return
        end
        statusLabel.Text = "Checking..."
        statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        local supabaseUrl = "https://xvnbxdcqmfsnnvbugasi.supabase.co"
        local supabaseKey = "sb_publishable_OQbzgO3ZE6-6qDl1YT_fXA_LA5aM-f0"
        local endpoint = supabaseUrl .. "/rest/v1/key?key=eq." .. key .. "&select=id"
        
        local success, response = pcall(function()
            return HttpService:RequestAsync({
                Url = endpoint,
                Method = "GET",
                Headers = {
                    ["apikey"] = supabaseKey,
                    ["Authorization"] = "Bearer " .. supabaseKey,
                    ["Content-Type"] = "application/json"
                }
            })
        end)
        
        if success and response.Success then
            local body = HttpService:JSONDecode(response.Body)
            if type(body) == "table" and #body > 0 then
                Data.whitelisted = true
                Save()
                statusLabel.Text = "Key Valid! Unlocking..."
                statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
                task.wait(1)
                showPage("My Scripts")
            else
                statusLabel.Text = "Invalid Key."
                statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            end
        else
            statusLabel.Text = "Error connecting to server."
            statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        end
    end)
end

-- ---------- My Scripts ----------
local list, layout, nameBox, addBtn, searchBox, placeholder
do
    local page = pages["My Scripts"]

    nameBox = Instance.new("TextBox", page)
    nameBox.Size = UDim2.new(0,170,0,28)
    nameBox.Position = UDim2.new(0,0,0,0)
    nameBox.PlaceholderText = "New tab name"
    nameBox.ClearTextOnFocus = false
    nameBox.BackgroundColor3 = Color3.fromRGB(45,45,45)
    nameBox.TextColor3 = Color3.fromRGB(255,255,255)
    nameBox.Font = Enum.Font.SourceSans
    nameBox.TextSize = 14
    enforceDesktopText(nameBox)

    addBtn = Instance.new("TextButton", page)
    addBtn.Size = UDim2.new(0,70,0,28)
    addBtn.Position = UDim2.new(0,180,0,0)
    addBtn.Text = "Add"
    addBtn.Font = Enum.Font.SourceSansBold
    addBtn.TextSize = 14
    addBtn.BackgroundColor3 = rgbToColor3(Data.settings.accentColor)
    addBtn.TextColor3 = Color3.new(1,1,1)
    enforceDesktopText(addBtn)

    searchBox = Instance.new("TextBox", page)
    searchBox.Size = UDim2.new(0,180,0,22)
    searchBox.Position = UDim2.new(0,260,0,4)
    searchBox.BackgroundColor3 = Color3.fromRGB(50,50,50)
    searchBox.TextColor3 = Color3.new(1,1,1)
    searchBox.ClearTextOnFocus = false
    searchBox.Text = ""
    enforceDesktopText(searchBox)

    placeholder = Instance.new("TextLabel", page)
    placeholder.Size = searchBox.Size
    placeholder.Position = searchBox.Position
    placeholder.BackgroundTransparency = 1
    placeholder.Text = "Search by name..."
    placeholder.TextColor3 = Color3.fromRGB(170,170,170)
    placeholder.Font = Enum.Font.SourceSans
    placeholder.TextXAlignment = Enum.TextXAlignment.Left
    placeholder.ZIndex = 160
    enforceDesktopText(placeholder)

    searchBox:GetPropertyChangedSignal("Text"):Connect(function() placeholder.Visible = (searchBox.Text == "") end)
    searchBox.Focused:Connect(function() placeholder.Visible = false end)
    searchBox.FocusLost:Connect(function() placeholder.Visible = (searchBox.Text == "") end)

    list = Instance.new("ScrollingFrame", page)
    list.Size = UDim2.new(0,170,1,-38)
    list.Position = UDim2.new(0,0,0,36)
    list.BackgroundColor3 = Color3.fromRGB(38,38,38)
    list.BorderSizePixel = 0
    list.ScrollBarThickness = 6
    list.ZIndex = 155

    layout = Instance.new("UIListLayout", list)
    layout.Padding = UDim.new(0,6)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        list.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 12)
    end)
end

local function sanitizeName(s)
    s = tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if s == "" then s = "Untitled" end
    if #s > 64 then s = s:sub(1,64) end
    return s
end

local function clearList()
    for _,c in ipairs(list:GetChildren()) do
        if not c:IsA("UIListLayout") then pcall(function() c:Destroy() end) end
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
    enforceDesktopText(nameLbl)

    local execB = Instance.new("TextButton", card)
    execB.Size = UDim2.new(0,70,0,22); execB.Position = UDim2.new(0,6,0,34)
    execB.Text = "Execute"; execB.BackgroundColor3 = rgbToColor3(Data.settings.accentColor)
    execB.BorderSizePixel = 0; execB.TextColor3 = Color3.new(1,1,1); execB.ZIndex = 157
    enforceDesktopText(execB)

    local editB = Instance.new("TextButton", card)
    editB.Size = UDim2.new(0,60,0,22); editB.Position = UDim2.new(0,84,0,34)
    editB.Text = "Edit"; editB.BackgroundColor3 = Color3.fromRGB(70,70,110)
    editB.BorderSizePixel = 0; editB.TextColor3 = Color3.new(1,1,1); editB.ZIndex = 157
    enforceDesktopText(editB)

    local renB = Instance.new("TextButton", card)
    renB.Size = UDim2.new(0,70,0,22); renB.Position = UDim2.new(0,6,0,60)
    renB.Text = "Rename"; renB.BackgroundColor3 = Color3.fromRGB(110,90,60)
    renB.BorderSizePixel = 0; renB.TextColor3 = Color3.new(1,1,1); renB.ZIndex = 157
    enforceDesktopText(renB)

    local delB = Instance.new("TextButton", card)
    delB.Size = UDim2.new(0,56,0,22); delB.Position = UDim2.new(0,84,0,60)
    delB.Text = "Del"; delB.BackgroundColor3 = Color3.fromRGB(150,60,60)
    delB.BorderSizePixel = 0; delB.TextColor3 = Color3.new(1,1,1); delB.ZIndex = 157
    enforceDesktopText(delB)

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

    editB.MouseButton1Click:Connect(function()
        local popup = Instance.new("Frame")
        popup.Size = UDim2.new(0,420,0,240)
        popup.Position = UDim2.new(0.5,-210,0.5,-120)
        popup.BackgroundColor3 = Color3.fromRGB(30,30,30)
        popup.BorderSizePixel = 0
        popup.Active = true
        popup.Parent = screen
        popup.ZIndex = 310

        local hdr = Instance.new("TextLabel", popup)
        hdr.Size = UDim2.new(1,0,0,28); hdr.Position = UDim2.new(0,0,0,0)
        hdr.BackgroundColor3 = Color3.fromRGB(45,45,45)
        hdr.Text = "Edit: "..(tab.name or "")
        hdr.TextColor3 = Color3.new(1,1,1)
        hdr.Font = Enum.Font.SourceSansBold
        hdr.ZIndex = 311
        hdr.Active = true
        enforceDesktopText(hdr)

        local box = Instance.new("TextBox", popup)
        box.Size = UDim2.new(1,-20,1,-110)
        box.Position = UDim2.new(0,10,0,36)
        box.MultiLine = true
        box.ClearTextOnFocus = false
        box.Text = tab.code or ""
        box.Font = Enum.Font.Code
        box.BackgroundColor3 = Color3.fromRGB(40,40,40)
        box.TextColor3 = Color3.new(1,1,1)
        box.ZIndex = 311
        enforceDesktopText(box)

        local saveB = Instance.new("TextButton", popup)
        saveB.Size = UDim2.new(0.5,-16,0,30)
        saveB.Position = UDim2.new(0,10,1,-68)
        saveB.Text = "Save"; saveB.BackgroundColor3 = rgbToColor3(Data.settings.accentColor)
        saveB.TextColor3 = Color3.new(1,1,1); saveB.ZIndex = 311
        enforceDesktopText(saveB)

        local closeB = Instance.new("TextButton", popup)
        closeB.Size = UDim2.new(0.5,-16,0,30)
        closeB.Position = UDim2.new(0.5,6,1,-68)
        closeB.Text = "Close"; closeB.BackgroundColor3 = Color3.fromRGB(120,60,60)
        closeB.TextColor3 = Color3.new(1,1,1); closeB.ZIndex = 311
        enforceDesktopText(closeB)

        local clearB = Instance.new("TextButton", popup)
        clearB.Size = UDim2.new(1,-20,0,26)
        clearB.Position = UDim2.new(0,10,1,-34)
        clearB.Text = "Clear"; clearB.BackgroundColor3 = Color3.fromRGB(90,90,90)
        clearB.TextColor3 = Color3.new(1,1,1); clearB.ZIndex = 311
        enforceDesktopText(clearB)

        local autoSaveThread = nil

        local function performSave()
            tab.code = box.Text
            Save()
        end

        box:GetPropertyChangedSignal("Text"):Connect(function()
            if autoSaveThread then task.cancel(autoSaveThread) end
            autoSaveThread = task.spawn(function()
                task.wait(0.5)
                performSave()
            end)
        end)
        box.FocusLost:Connect(function()
            performSave()
        end)

        clearB.MouseButton1Click:Connect(function()
            box.Text = ""
            performSave()
        end)

        saveB.MouseButton1Click:Connect(function()
            performSave()
            popup:Destroy()
            refreshScripts()
        end)

        closeB.MouseButton1Click:Connect(function()
            performSave()
            popup:Destroy()
        end)

        makeDraggable(popup, hdr, { saveOnEnd = false })

        local conn
        conn = RunService.RenderStepped:Connect(function()
            if not popup.Parent then conn:Disconnect(); return end
            local cam = workspace and workspace.CurrentCamera
            if not cam then return end
            local vs = cam.ViewportSize
            local pos = popup.AbsolutePosition
            local sz = popup.AbsoluteSize

            local minX = math.min(0, vs.X - sz.X)
            local maxX = math.max(0, vs.X - sz.X)
            local minY = math.min(0, vs.Y - sz.Y)
            local maxY = math.max(0, vs.Y - sz.Y)

            local clampedX = math.clamp(pos.X, minX, maxX)
            local clampedY = math.clamp(pos.Y, minY, maxY)

            if clampedX ~= pos.X or clampedY ~= pos.Y then
                popup.Position = UDim2.fromOffset(clampedX, clampedY)
            end
        end)
    end)

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
        head.Active = true
        enforceDesktopText(head)

        local nameInput = Instance.new("TextBox", pop)
        nameInput.Size = UDim2.new(1,-20,0,28); nameInput.Position = UDim2.new(0,10,0,36)
        nameInput.PlaceholderText = "Enter new name"; nameInput.Text = tab.name or ""
        nameInput.BackgroundColor3 = Color3.fromRGB(40,40,40); nameInput.TextColor3 = Color3.new(1,1,1)
        nameInput.Font = Enum.Font.SourceSans; nameInput.TextSize = 14
        enforceDesktopText(nameInput)

        local saveB = Instance.new("TextButton", pop)
        saveB.Size = UDim2.new(0.5,-14,0,28); saveB.Position = UDim2.new(0,10,1,-36)
        saveB.Text = "Save"; saveB.BackgroundColor3 = rgbToColor3(Data.settings.accentColor)
        saveB.TextColor3 = Color3.new(1,1,1)
        enforceDesktopText(saveB)

        local cancelB = Instance.new("TextButton", pop)
        cancelB.Size = UDim2.new(0.5,-14,0,28); cancelB.Position = UDim2.new(0.5,14,1,-36)
        cancelB.Text = "Cancel"; cancelB.BackgroundColor3 = Color3.fromRGB(120,60,60)
        cancelB.TextColor3 = Color3.new(1,1,1)
        enforceDesktopText(cancelB)

        saveB.MouseButton1Click:Connect(function()
            local nm = sanitizeName(nameInput.Text)
            tab.name = nm
            Save()
            refreshScripts()
            pop:Destroy()
        end)

        cancelB.MouseButton1Click:Connect(function() pop:Destroy() end)

        makeDraggable(pop, head, { saveOnEnd = false })

        local conn
        conn = RunService.RenderStepped:Connect(function()
            if not pop.Parent then conn:Disconnect(); return end
            local cam = workspace and workspace.CurrentCamera
            if not cam then return end
            local vs = cam.ViewportSize
            local pos = pop.AbsolutePosition
            local sz = pop.AbsoluteSize

            local minX = math.min(0, vs.X - sz.X)
            local maxX = math.max(0, vs.X - sz.X)
            local minY = math.min(0, vs.Y - sz.Y)
            local maxY = math.max(0, vs.Y - sz.Y)

            local clampedX = math.clamp(pos.X, minX, maxX)
            local clampedY = math.clamp(pos.Y, minY, maxY)

            if clampedX ~= pos.X or clampedY ~= pos.Y then
                pop.Position = UDim2.fromOffset(clampedX, clampedY)
            end
        end)
    end)

    delB.MouseButton1Click:Connect(function()
        if Data.settings.noConfirm then
            local idx = findIndexById(tab.id)
            if idx then table.remove(Data.tabs, idx); Save(); refreshScripts() end
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
            head.Active = true
            enforceDesktopText(head)

            local msg = Instance.new("TextLabel", pop)
            msg.Size = UDim2.new(1,-20,0,28); msg.Position = UDim2.new(0,10,0,36)
            msg.BackgroundTransparency = 1
            msg.Text = "Delete '" .. (tab.name or "") .. "'?"
            msg.TextColor3 = Color3.new(1,1,1); msg.Font = Enum.Font.SourceSans
            enforceDesktopText(msg)

            local confirmB = Instance.new("TextButton", pop)
            confirmB.Size = UDim2.new(0.5,-14,0,28); confirmB.Position = UDim2.new(0,10,1,-36)
            confirmB.Text = "Yes"; confirmB.BackgroundColor3 = Color3.fromRGB(150,60,60); confirmB.TextColor3 = Color3.new(1,1,1)
            enforceDesktopText(confirmB)

            local cancelB = Instance.new("TextButton", pop)
            cancelB.Size = UDim2.new(0.5,-14,0,28); cancelB.Position = UDim2.new(0.5,14,1,-36)
            cancelB.Text = "No"; cancelB.BackgroundColor3 = Color3.fromRGB(90,90,90); cancelB.TextColor3 = Color3.new(1,1,1)
            enforceDesktopText(cancelB)

            confirmB.MouseButton1Click:Connect(function()
                local idx = findIndexById(tab.id)
                if idx then table.remove(Data.tabs, idx); Save(); refreshScripts() end
                pop:Destroy()
            end)
            cancelB.MouseButton1Click:Connect(function() pop:Destroy() end)

            makeDraggable(pop, head, { saveOnEnd = false })
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
    refreshScripts()
end)

searchBox:GetPropertyChangedSignal("Text"):Connect(function() refreshScripts() end)

function refreshScripts()
    clearList()
    local filter = tostring(searchBox.Text or ""):lower()
    for _, tab in ipairs(Data.tabs) do
        if filter == "" or (tostring(tab.name or ""):lower():find(filter,1,true)) then
            renderCard(tab)
        end
    end
end
refreshScripts()

-- Executor page
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
    box.TextSize = 14
    enforceDesktopText(box)

    box.FocusLost:Connect(function()
        Data.lastExecutor = box.Text
        Save()
    end)

    local execB = Instance.new("TextButton", page)
    execB.Size = UDim2.new(0.5,-10,0,28)
    execB.Position = UDim2.new(0,5,1,-38)
    execB.Text = "Execute"
    execB.BackgroundColor3 = rgbToColor3(Data.settings.accentColor)
    execB.TextColor3 = Color3.new(1,1,1)
    execB.TextSize = 14
    enforceDesktopText(execB)

    local clearB = Instance.new("TextButton", page)
    clearB.Size = UDim2.new(0.5,-10,0,28)
    clearB.Position = UDim2.new(0.5,5,1,-38)
    clearB.Text = "Clear"
    clearB.BackgroundColor3 = Color3.fromRGB(90,90,90)
    clearB.TextColor3 = Color3.new(1,1,1)
    clearB.TextSize = 14
    enforceDesktopText(clearB)

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

-- Settings page
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
        lbl.TextSize = 14
        enforceDesktopText(lbl)

        local toggle = Instance.new("TextButton", f)
        toggle.Size = UDim2.new(0,60,0,22)
        toggle.Position = UDim2.new(1,-66,0,3)
        toggle.Text = Data.settings[key] and "On" or "Off"
        toggle.BackgroundColor3 = Data.settings[key] and rgbToColor3(Data.settings.accentColor) or Color3.fromRGB(90,90,90)
        toggle.TextColor3 = Color3.new(1,1,1)
        toggle.TextSize = 14
        enforceDesktopText(toggle)

        toggle.MouseButton1Click:Connect(function()
            Data.settings[key] = not Data.settings[key]
            toggle.Text = Data.settings[key] and "On" or "Off"
            toggle.BackgroundColor3 = Data.settings[key] and rgbToColor3(Data.settings.accentColor) or Color3.fromRGB(90,90,90)

            if key == "resetOnSpawn" then
                screen.ResetOnSpawn = Data.settings.resetOnSpawn and true or false
            elseif key == "screenLock" then
                if Data.settings.screenLock then
                    MAIN_STICKED = true
                    MAIN_DRAG_ACTIVE = false
                end
            elseif key == "startClosed" then
                local newClosed = Data.settings.startClosed
                local useLast = not newClosed
                local targetVisible = useLast and (Data.settings.lastOpenState ~= nil and Data.settings.lastOpenState or false) or false
                main.Visible = targetVisible
                openBtn.Visible = not targetVisible
            end
            Save()
        end)
    end
    mkToggle("Reset on Spawn", "resetOnSpawn", 6)
    mkToggle("Screen Lock", "screenLock", 46)
    mkToggle("No Confirm Delete", "noConfirm", 86)
    mkToggle("Save Position", "savePosition", 126)
    mkToggle("Start Closed On Run", "startClosed", 166)
end

-- Design page
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
    genB.TextSize = 14; enforceDesktopText(genB)

    local prevB = Instance.new("TextButton", page)
    prevB.Size = UDim2.new(0,50,0,28); prevB.Position = UDim2.new(0,5,0,144)
    prevB.Text = "Prev"; prevB.BackgroundColor3 = Color3.fromRGB(90,90,90); prevB.TextColor3 = Color3.new(1,1,1)
    prevB.TextSize = 14; enforceDesktopText(prevB)

    local nextB = Instance.new("TextButton", page)
    nextB.Size = UDim2.new(0,50,0,28); nextB.Position = UDim2.new(0,60,0,144)
    nextB.Text = "Next"; nextB.BackgroundColor3 = Color3.fromRGB(90,90,90); nextB.TextColor3 = Color3.new(1,1,1)
    nextB.TextSize = 14; enforceDesktopText(nextB)

    local applyB = Instance.new("TextButton", page)
    applyB.Size = UDim2.new(0,100,0,28); applyB.Position = UDim2.new(0,5,0,178)
    applyB.Text = "Apply"; applyB.BackgroundColor3 = rgbToColor3(Data.settings.accentColor); applyB.TextColor3 = Color3.new(1,1,1)
    applyB.TextSize = 14; enforceDesktopText(applyB)

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
            for _, pg in pairs(pages) do
                for _, obj in ipairs(pg:GetDescendants()) do
                    if obj:IsA("TextButton") then
                        obj.BackgroundColor3 = rgbToColor3(colors.accent)
                        enforceDesktopText(obj)
                    end
                end
            end
            for _, obj in ipairs(left:GetDescendants()) do
                if obj:IsA("TextButton") then obj.BackgroundColor3 = rgbToColor3(colors.accent); enforceDesktopText(obj) end
            end
            Save()
        end
    end)
end

-- Utility page
do
    local page = pages["Utility"]
    local header = Instance.new("TextLabel", page)
    header.Size = UDim2.new(1,-10,0,20)
    header.Position = UDim2.new(0,5,0,6)
    header.BackgroundTransparency = 1
    header.Text = "Utility"
    header.Font = Enum.Font.SourceSansBold
    header.TextColor3 = Color3.fromRGB(225,225,225)
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.ZIndex = 150
    enforceDesktopText(header)

    -- AIMLOCK
    local aimBtn = Instance.new("TextButton", page)
    aimBtn.Size = UDim2.new(0,140,0,30)
    aimBtn.Position = UDim2.new(0,5,0,36)
    aimBtn.Font = Enum.Font.SourceSansBold
    aimBtn.TextSize = 14
    aimBtn.TextColor3 = Color3.new(1,1,1)
    aimBtn.BorderSizePixel = 0
    aimBtn.ZIndex = 150
    enforceDesktopText(aimBtn)

    local AIM_ENABLED = Data.settings.aimlock and true or false
    aimBtn.Text = AIM_ENABLED and "Aimlock: On" or "Aimlock: Off"
    aimBtn.BackgroundColor3 = AIM_ENABLED and rgbToColor3(Data.settings.accentColor) or Color3.fromRGB(90,90,90)

    local aimConn = nil
    local aimPrevCameraType = nil
    local aimPrevCameraSubject = nil
    local aimPrevCFrame = nil

    local function findNearestPlayerCharacter_fromCam()
        local camPos
        local cam = workspace and workspace.CurrentCamera
        if cam then
            camPos = cam.CFrame.Position
        else
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                camPos = char.HumanoidRootPart.Position
            end
        end
        if not camPos then return nil end

        local bestP = nil
        local bestDist = math.huge
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= LocalPlayer and pl.Character and pl.Character.Parent and pl.Character:FindFirstChild("HumanoidRootPart") then
                local hrp = pl.Character:FindFirstChild("HumanoidRootPart")
                local humanoid = pl.Character:FindFirstChildOfClass("Humanoid")
                if hrp and humanoid and humanoid.Health > 0 then
                    local d = (hrp.Position - camPos).Magnitude
                    if d < bestDist then bestDist = d; bestP = pl end
                end
            end
        end
        return bestP
    end

    local function enableAimlock()
        if aimConn then
            pcall(function() aimConn:Disconnect() end)
            aimConn = nil
        end

        local cam = workspace and workspace.CurrentCamera
        if not cam then return end

        pcall(function()
            aimPrevCameraType = cam.CameraType
            aimPrevCameraSubject = cam.CameraSubject
            aimPrevCFrame = cam.CFrame
        end)
        pcall(function() cam.CameraType = Enum.CameraType.Scriptable end)
        aimConn = RunService.RenderStepped:Connect(function()
            if not AIM_ENABLED then return end
            local cam2 = workspace and workspace.CurrentCamera
            if not cam2 then return end
            local targetPl = findNearestPlayerCharacter_fromCam()
            local char = LocalPlayer.Character
            local myHRP = char and char:FindFirstChild("HumanoidRootPart")
            if targetPl and targetPl.Character and myHRP then
                local targetHRP = targetPl.Character:FindFirstChild("HumanoidRootPart")
                if targetHRP then
                    pcall(function()
                        local currentDist = (cam2.CFrame.Position - myHRP.Position).Magnitude
                        local dirToTarget = (targetHRP.Position - myHRP.Position).Unit
                        local zoomClamped = math.max(currentDist, 0.5)
                        local newCamPos = myHRP.Position + (dirToTarget * zoomClamped)
                        cam2.CFrame = CFrame.lookAt(newCamPos, targetHRP.Position)
                    end)
                end
            end
        end)
    end

    local function disableAimlock()
        if aimConn then
            pcall(function() aimConn: disableAimlock() end)
            aimConn = nil
        end
        local cam = workspace and workspace.CurrentCamera
        if not cam then return end
        pcall(function()
            if aimPrevCameraType then
                pcall(function() cam.CameraType = aimPrevCameraType end)
            else
                pcall(function() cam.CameraType = Enum.CameraType.Custom end)
            end
            if aimPrevCameraSubject and aimPrevCameraSubject and aimPrevCameraSubject.Parent then
                pcall(function() cam.CameraSubject = aimPrevCameraSubject end)
            else
                if LocalPlayer.Character then
                    local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                    if hum then pcall(function() cam.CameraSubject = hum end) end
                end
            end
            if aimPrevCFrame then
                pcall(function() cam.CFrame = aimPrevCFrame end)
            end
        end)
        aimPrevCameraType = nil
        aimPrevCameraSubject = nil
        aimPrevCFrame = nil
    end

    if AIM_ENABLED then enableAimlock() end

    aimBtn.MouseButton1Click:Connect(function()
        AIM_ENABLED = not AIM_ENABLED
        Data.settings.aimlock = AIM_ENABLED and true or false
        aimBtn.Text = AIM_ENABLED and "Aimlock: On" or "Aimlock: Off"
        aimBtn.BackgroundColor3 = AIM_ENABLED and rgbToColor3(Data.settings.accentColor) or Color3.fromRGB(90,90,90)
        Save()
        if AIM_ENABLED then enableAimlock() else disableAimlock() end
    end)

    -- PATHFIND (Robust implementation with robust cancellation)
    local pathBtn = Instance.new("TextButton", page)
    pathBtn.Size = UDim2.new(0,140,0,30)
    pathBtn.Position = UDim2.new(0,5,0,76)
    pathBtn.Font = Enum.Font.SourceSansBold
    pathBtn.TextSize = 14
    pathBtn.TextColor3 = Color3.new(1,1,1)
    pathBtn.BorderSizePixel = 0
    pathBtn.ZIndex = 150
    enforceDesktopText(pathBtn)

    local PATH_ENABLED = Data.settings.pathfind and true or false
    pathBtn.Text = PATH_ENABLED and "Pathfind: On" or "Pathfind: Off"
    pathBtn.BackgroundColor3 = PATH_ENABLED and rgbToColor3(Data.settings.accentColor) or Color3.fromRGB(90,90,90)

    local pathThread = nil
    local pathCancelFlag = false
    local manualCooldown = 1.0
    local lastManualAt = 0
    local lastHumanoidRef = nil

    local function markManual() lastManualAt = tick() end
    UserInput.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.UserInputType == Enum.UserInputType.Keyboard then
            local k = input.KeyCode
            if k == Enum.KeyCode.W or k == Enum.KeyCode.A or k == Enum.KeyCode.S or k == Enum.KeyCode.D or
               k == Enum.KeyCode.Up or k == Enum.KeyCode.Down or k == Enum.KeyCode.Left or k == Enum.KeyCode.Right or
               k == Enum.KeyCode.Space then
                markManual()
            end
        elseif input.UserInputType == Enum.UserInputType.Gamepad1 or input.UserInputType == Enum.UserInputType.Touch then markManual() end
    end)
    UserInput.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Gamepad1 then
            if input.Position and input.Position.Magnitude > 0.01 then markManual() end
        elseif input.UserInputType == Enum.UserInputType.Touch then markManual()
        end
    end)
    UserInput.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Keyboard then
            local k = input.KeyCode
            if k == Enum.KeyCode.W or k == Enum.KeyCode.A or k == Enum.KeyCode.S or k == Enum.KeyCode.D or
               k == Enum.KeyCode.Up or k == Enum.KeyCode.Down or k == Enum.KeyCode.Left or k == Enum.KeyCode.Right or
               k == Enum.KeyCode.Space then markManual()
            end
        elseif input.UserInputType == Enum.UserInputType.Gamepad1 or input.UserInputType == Enum.UserInputType.Touch then markManual()
        end
    end)

    local function getLocalCharacterParts(timeout)
        timeout = timeout or 5
        local t0 = tick()
        while tick() - t0 < timeout do
            local char = LocalPlayer.Character
            if char then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                local humanoid = char:FindFirstChildOfClass("Humanoid")
                if hrp and humanoid and humanoid.Health > 0 then return char, humanoid, hrp end
            end
            task.wait(0.2)
        end
        return nil, nil, nil
    end

    local function findNearestPlayerCharacter_fromPos(pos)
        if not pos then return nil end
        local bestP = nil
        local bestDist = math.huge
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= LocalPlayer and pl.Character and pl.Character.Parent and pl.Character:FindFirstChild("HumanoidRootPart") then
                local hrp = pl.Character:FindFirstChild("HumanoidRootPart")
                local humanoid = pl.Character:FindFirstChildOfClass("Humanoid")
                if hrp and humanoid and humanoid.Health > 0 then
                    local d = (hrp.Position - pos).Magnitude
                    if d < bestDist then bestDist = d; bestP = pl end
                end
            end
        end
        return bestP
    end

    local function computeBestPath(startPos, endPos)
        if not startPos or not endPos then return nil, "invalid" end
        local jumpHeights = {8, 12, 16, 24}
        local offsets = { Vector3.new(0,0,0), Vector3.new(3,0,0), Vector3.new(-3,0,0), Vector3.new(0,0,3), Vector3.new(0,0,-3) }
        for _, jh in ipairs(jumpHeights) do
            for _, off in ipairs(offsets) do
                local target = endPos + off
                local ok, path = pcall(function()
                    local p = PathfindingService:CreatePath({
                        AgentRadius = 2,
                        AgentHeight = 5,
                        AgentCanJump = true,
                        AgentJumpHeight = jh,
                        AgentMaxSlope = 55,
                    })
                    p:ComputeAsync(startPos, target)
                    return p
                end)
                if ok and path and path.Status == Enum.PathStatus.Success then return path, target end
            end
        end
        local ok, path = pcall(function()
            local p = PathfindingService:CreatePath({
                AgentRadius = 2,
                AgentHeight = 5,
                AgentCanJump = true,
                AgentJumpHeight = 60,
                AgentMaxSlope = 60,
            })
            p:ComputeAsync(startPos, endPos)
            return p
        end)
        if ok and path and path.Status == Enum.PathStatus.Success then return path, endPos end
        return nil, "no_path"
    end

    local function stopHumanoidMovementIfPossible()
        local h = lastHumanoidRef
        if h and h.Parent then
            local root = h.Parent:FindFirstChild("HumanoidRootPart")
            if root then pcall(function() h:MoveTo(root.Position) end) end
        lastHumanoidRef = nil
    end

    local function followPathToTarget(humanoid, hrp, targetPlayer)
        if not humanoid or not hrp or not targetPlayer then return nil end
        local targetChar = targetPlayer.Character
        if not targetChar then return nil end
        local targetHRP = targetChar:FindFirstChild("HumanoidRootPart")
        local targetHum = targetChar:FindFirstChildOfClass("Humanoid")
        if not targetHRP or not targetHum or targetHum.Health <= 0 then return nil end
        local path, _ = computeBestPath(hrp.Position, targetHRP.Position)
        if not path then return false end
        local waypoints = path:GetWaypoints()
        lastHumanoidRef = humanoid
        for _, wp in ipairs(waypoints) do
            if pathCancelFlag or not PATH_ENABLED then stopHumanoidMovementIfPossible(); return false end
            if not targetPlayer.Character or not targetPlayer.Character.Parent then stopHumanoidMovementIfPossible(); return false end

            local curTargetHum = targetPlayer.Character:FindFirstChildOfClass("Humanoid")
            if not curTargetHum or curTargetHum.Health <= 0 then stopHumanoidMovementIfPossible(); return false end

            if (tick() - lastManualAt) < manualCooldown then stopHumanoidMovementIfPossible(); task.wait(math.max(0.15, manualCooldown - (tick() - lastManualAt))) return false end

            if wp.Action == Enum.PathWaypointAction.Jump then pcall(function() humanoid.Jump = true end) task.wait(0.06) end
            if humanoid.Health <= 0 then stopHumanoidMovementIfPossible(); return false end

            local dest = wp.Position
            local distToDest = (hrp.Position - dest).Magnitude
            local arrivalRadius = 4
            if distToDest > 40 then arrivalRadius = 8 end
            if distToDest > 80 then arrivalRadius = 12 end

            pcall(function() humanoid:MoveTo(dest) end)

            local arrived = false
            local startWait = tick()
            local timeout = math.clamp(6 + (distToDest / 20), 6, 30)
            while tick() - startWait < timeout do
                if pathCancelFlag or not PATH_ENABLED then stopHumanoidMovementIfPossible(); return false end
                if not humanoid or humanoid.Health <= 0 then stopHumanoidMovementIfPossible(); return false end
                if not hrp.Parent then stopHumanoidMovementIfPossible(); return false end
                if (tick() - lastManualAt) < manualCooldown then stopHumanoidMovementIfPossible(); return false end

                local curDist = (hrp.Position - dest).Magnitude
                if curDist <= arrivalRadius then arrived = true; break end
                task.wait(0.08)
            end
            if not arrived then stopHumanoidMovementIfPossible(); return false end
        end

        lastHumanoidRef = nil
        return true
    end

    local function pathLoop()
        pathCancelFlag = false
        while PATH_ENABLED and not pathCancelFlag do
            local char, humanoid, hrp = getLocalCharacterParts(5)
            if not char or not humanoid or not hrp then
                pcall(function() LocalPlayer.CharacterAdded:Wait() end)
                if pathCancelFlag or not PATH_ENABLED then break end
                char, humanoid, hrp = getLocalCharacterParts(5)
            end

            if not char or not humanoid or not hrp then
                if pathCancelFlag or not PATH_ENABLED then break end
                task.wait(0.5)
            else
                if (tick() - lastManualAt) < manualCooldown then
                    task.wait(math.max(0.15, manualCooldown - (tick() - lastManualAt)))
                end
                local target = findNearestPlayerCharacter_fromPos(hrp.Position)
                if not target then
                    local waited = 0
                    while not target and waited < 3 and PATH_ENABLED and not pathCancelFlag do
                        task.wait(0.5); waited = waited + 0.5
                        target = findNearestPlayerCharacter_fromPos(hrp.Position)
                    end
                    if not target then
                        task.wait(1)
                    else
                        if PATH_ENABLED and not pathCancelFlag then
                            local ok, res = pcall(function() return followPathToTarget(humanoid, hrp, target) end)
                            if not ok then warn("[Nishgamer Hub] followPathToTarget error:", res) end
                        end
                    end
                else
                    if PATH_ENABLED and not pathCancelFlag then
                        local ok, res = pcall(function() return followPathToTarget(humanoid, hrp, target) end)
                        if not ok then warn("[Nishgamer Hub] followPathToTarget error:", res) end
                    end
                end
            end
            task.wait(0.25)
        end

        stopHumanoidMovementIfPossible()
        pathThread = nil
    end

    local function startPathfind()
        if pathThread then return end
        pathCancelFlag = true
        PATH_ENABLED = true
        Data.settings.pathfind = true
        Save()
        pathThread = task.spawn(function()
            local ok, err = pcall(pathLoop)
            if not ok then warn("[Nishgamer Hub] PathLoop error:", err) end
            pathThread = nil
        end)
    end

    local function stopPathfind()
        pathCancelFlag = true
        PATH_ENABLED = false
        Data.settings.pathfind = false
        Save()
        local stopWait = 0
        while pathThread and stopWait < 1.2 do
            task.wait(0.08); stopWait = stopWait + 0.08
        end
        stopHumanoidMovementIfPossible()
    end

    if PATH_ENABLED then startPathfind() end
    pathBtn.MouseButton1Click:Connect(function()
        if PATH_ENABLED then stopPathfind()
        pathBtn.Text = "Pathfind: Off"
        pathBtn.BackgroundColor3 = Color3.fromRGB(90,90,90)
    else
        pathBtn.Text = "Pathfind: On"
        pathBtn.BackgroundColor3 = rgbToColor3(Data.settings.accentColor)
        startPathfind()
    end)

    LocalPlayer.CharacterAdded:Connect(function()
        if Data.settings.resetOnSpawn then
            main.Visible = false
            openBtn.Visible = true
            Data.settings.lastOpenState = false
            Save()
        else
            local useLast = not Data.settings.startClosed
            local startVisible = useLast and (Data.settings.lastOpenState ~= nil and Data.settings.lastOpenState or false) or false
            main.Visible = startVisible
            openBtn.Visible = not startVisible
        end
        task.delay(0.3, function()
            pcall(function() disableAimlock() end)
            if Data.settings.pathfind then
                task.delay(0.6, function()
                    if Data.settings.pathfind and not pathThread then startPathfind() end
                end)
            end
            if Data.settings.aimlock then
                AIM_ENABLED = true
                task.delay(0.25, function()
                    if workspace and workspace.CurrentCamera then enableAimlock() end
                    aimBtn.Text = "Aimlock: On"
                    aimBtn.BackgroundColor3 = rgbToColor3(Data.settings.accentColor)
                end
            else
                AIM_ENABLED = false
                disableAimlock()
                aimBtn.Text = "Aimlock: Off"
                aimBtn.BackgroundColor3 = Color3.fromRGB(90,90,90)
            end
        end)
    end)

    local function attachDeathWatcherToCharacter(char)
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then hum = char:WaitForChild("Humanoid", 6) end
        if hum then
            hum.Died:Connect(function()
                pcall(function() disableAimlock() end)
                if Data.settings.resetOnSpawn then
                    main.Visible = false
                    openBtn.Visible = true
                    Data.settings.lastOpenState = false
                    Save()
                end
            end)
        end
    end
    if LocalPlayer.Character then attachDeathWatcherToCharacter(LocalPlayer.Character) end
    LocalPlayer.CharacterAdded:Connect(function(c) attachDeathWatcherToCharacter(c) end)

    LocalPlayer.CharacterRemoving:Connect(function()
        pcall(function() disableAimlock() end)
    end)

    Players.PlayerRemoving:Connect(function(pl)
        if pl == LocalPlayer then
            stopPathfind()
            disableAimlock()
        end
    end)

    enforceDesktopText(header)
    enforceDesktopText(aimBtn)
    enforceDesktopText(pathBtn)
end

-- ---------- MORE PAGE ----------
do
    local page = pages["More"]
    
    -- Top: Scrolling Frame
    local scrollFrame = Instance.new("ScrollingFrame", page)
    scrollFrame.Size = UDim2.new(1, -10, 1, -70)
    scrollFrame.Position = UDim2.new(0, 5, 0, 5)
    scrollFrame.BackgroundColor3 = Color3.fromRGB(38, 38, 38)
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 6
    scrollFrame.ZIndex = 155
    
    local listLayout = Instance.new("UIListLayout", scrollFrame)
    listLayout.Padding = UDim.new(0, 5)
    listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scrollFrame.CanvasSize = UDim2.fromOffset(0, listLayout.AbsoluteContentSize.Y + 10)
    end)

    -- Auto Run Loader Button
    local btnAutoRun = Instance.new("TextButton", scrollFrame)
    btnAutoRun.Size = UDim2.new(1, 0, 0, 40)
    btnAutoRun.BackgroundColor3 = rgbToColor3(Data.settings.accentColor)
    btnAutoRun.TextColor3 = Color3.new(1, 1, 1)
    btnAutoRun.Font = Enum.Font.SourceSansBold
    btnAutoRun.TextSize = 16
    btnAutoRun.Text = "Auto Run Loader"
    btnAutoRun.ZIndex = 156
    enforceDesktopText(btnAutoRun)

    -- Bottom: Control Panel
    local bottomPanel = Instance.new("Frame", page)
    bottomPanel.Size = UDim2.new(1, -10, 0, 60)
    bottomPanel.Position = UDim2.new(0, 5, 1, -65)
    bottomPanel.BackgroundTransparency = 1
    bottomPanel.ZIndex = 155

    local statusLabel = Instance.new("TextLabel", bottomPanel)
    statusLabel.Size = UDim2.new(1, -140, 1, 0)
    statusLabel.Position = UDim2.new(0, 0, 0, 0)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "Status: Disabled"
    statusLabel.TextColor3 = Color3.new(1, 1, 1)
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Font = Enum.Font.SourceSans
    statusLabel.TextSize = 14
    statusLabel.ZIndex = 156
    enforceDesktopText(statusLabel)

    local toggleBtn = Instance.new("TextButton", bottomPanel)
    toggleBtn.Size = UDim2.new(0, 120, 0, 30)
    toggleBtn.Position = UDim2.new(1, -120, 0, 15)
    toggleBtn.BackgroundColor3 = Data.settings.autoRunLoader and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
    toggleBtn.Text = Data.settings.autoRunLoader and "On" or "Off"
    toggleBtn.TextColor3 = Color3.new(0, 0, 0)
    toggleBtn.Font = Enum.Font.SourceSansBold
    toggleBtn.TextSize = 14
    toggleBtn.ZIndex = 156
    enforceDesktopText(toggleBtn)

    -- Logic
    local LOADER_URL = "https://raw.githubusercontent.com/Nish12345678910111/myscripts/refs/heads/main/universal%20scripts%20-new/loader-new-2.lua"

    local function updateStatus()
        if Data.settings.autoRunLoader then
            statusLabel.Text = "Auto Run Loader: Enabled"
        else
            statusLabel.Text = "Auto Run Loader: Disabled"
        end
    end

    local function runLoaderScript()
        if not game:HttpGet then
            statusLabel.Text = "Error: HttpGet not supported."
            return
        end
        statusLabel.Text = "Executing Loader..."
        task.spawn(function()
            local success, err = pcall(function()
                local content = game:HttpGet(LOADER_URL)
                local fn = loadstring(content)
                if fn then
                    fn()
                    statusLabel.Text = "Loader Executed Successfully!"
                else
                    error("Loadstring failed")
                end
            end)
            if not success then
                warn("[Nishgamer Hub] Loader Error:", err)
                statusLabel.Text = "Error: " .. tostring(err)
            end
        end)
    end

    updateStatus()
    if Data.settings.autoRunLoader then
        task.wait(1) 
        runLoaderScript()
    end

    btnAutoRun.MouseButton1Click:Connect(function()
        statusLabel.Text = "Use the toggle below to enable/disable."
    end)

    toggleBtn.MouseButton1Click:Connect(function()
        Data.settings.autoRunLoader = not Data.settings.autoRunLoader
        Save()
        
        local isOn = Data.settings.autoRunLoader
        toggleBtn.Text = isOn and "On" or "Off"
        toggleBtn.BackgroundColor3 = isOn and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
        
        updateStatus()
        
        if isOn then
            runLoaderScript()
        else
            statusLabel.Text = "Disabled."
        end
    end)
end

-- ---------- SECRET PAGE (NEW "SCURRENT" FEATURE) ----------
do
    local page = pages["Secret"]
    
    -- Info
    local info = Instance.new("TextLabel", page)
    info.Size = UDim2.new(1,0,0,40)
    info.Position = UDim2.new(0,0,0,10)
    info.BackgroundTransparency = 1
    info.Text = "Enter Secret Code to unlock hidden features.\nDefault: Nishgamer123"
    info.TextColor3 = Color3.fromRGB(255, 215, 0)
    info.TextWrapped = true
    info.Font = Enum.Font.SourceSansBold
    info.TextSize = 16
    info.ZIndex = 150
    enforceDesktopText(info)

    local secretInput = Instance.new("TextBox", page)
    secretInput.Size = UDim2.new(0,200,0,30)
    secretInput.Position = UDim2.new(0.5, -100, 0, 60)
    secretInput.PlaceholderText = "Enter Secret Code"
    secretInput.BackgroundColor3 = Color3.fromRGB(40,40,40)
    secretInput.Text = ""
    secretInput.TextColor3 = Color3.new(1,1,1)
    secretInput.Font = Enum.Font.SourceSans
    secretInput.TextSize = 14
    secretInput.ZIndex = 150
    enforceDesktopText(secretInput)

    local unlockBtn = Instance.new("TextButton", page)
    unlockBtn.Size = UDim2.new(0,120,0,30)
    unlockBtn.Position = UDim2.new(0.5, -60, 0, 100)
    unlockBtn.Text = "Unlock Secrets"
    unlockBtn.Font = Enum.Font.SourceSansBold
    unlockBtn.TextSize = 14
    unlockBtn.TextColor3 = Color3.new(1,1,1)
    unlockBtn.BackgroundColor3 = Color3.fromRGB(70,70,110)
    unlockBtn.BorderSizePixel = 0
    unlockBtn.ZIndex = 150
    enforceDesktopText(unlockBtn)

    local statusLabel = Instance.new("TextLabel", page)
    statusLabel.Size = UDim2.new(1,0,0,30)
    statusLabel.Position = UDim2.new(0,0,0,140)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "Locked"
    statusLabel.TextColor3 = Color3.new(1,1,1)
    statusLabel.Font = Enum.Font.SourceSans
    statusLabel.TextSize = 14
    statusLabel.ZIndex = 150
    enforceDesktopText(statusLabel)

    -- Content Area (Hidden by default)
    local secretContent = Instance.new("Frame", page)
    secretContent.Size = UDim2.new(1,0,1, -180)
    secretContent.Position = UDim2.new(0,0,0,180)
    secretContent.BackgroundTransparency = 1
    secretContent.Visible = false
    secretContent.ZIndex = 150

    -- Secret Features
    local btnGodMode = Instance.new("TextButton", secretContent)
    btnGodMode.Size = UDim2.new(0,180,0,30)
    btnGodMode.Position = UDim2.new(0, 10,0,10)
    btnGodMode.Text = "God Mode"
    btnGodMode.Font = Enum.Font.SourceSansBold
    btnGodMode.TextSize = 14
    btnGodMode.TextColor3 = Color3.new(1,1,1)
    btnGodMode.BackgroundColor3 = Color3.fromRGB(50,50,50)
    btnGodMode.ZIndex = 151
    enforceDesktopText(btnGodMode)

    local btnNoclip = Instance.new("TextButton", secretContent)
    btnNoclip.Size = UDim2.new(0,180,0,30)
    btnNoclip.Position = UDim2.new(0, 210, 0,10)
    btnNoclip.Text = "Noclip"
    btnNoclip.Font = Enum.Font.SourceSansBold
    btnNoclip.TextSize = 14
    btnNoclip.TextColor3 = Color3.new(1,1,1)
    btnNoclip.BackgroundColor3 = Color3.fromRGB(70,70,110)
    btnNoclip.BorderSizePixel = 0
    btnNoclip.ZIndex = 151
    enforceDesktopText(btnNoclip)

    local btnSuperSpeed = Instance.new("TextButton", secretContent)
    btnSuperSpeed.Size = UDim2.new(0,180,0,30)
    btnSuperSpeed.Position = UDim2.new(0, 210,0,50)
    btnSuperSpeed.Text = "Super Speed"
    btnSuperSpeed.Font = Enum.Font.SourceSansBold
    btnSuperSpeed.TextSize = 14
    btnSuperSpeed.TextColor3 = Color3.new(1,1,1)
    btnSuperSpeed.BackgroundColor3 = Color3.fromRGB(90,90,90)
    btnSuperSpeed.BorderSizePixel = 0
    btnSuperSpeed.ZIndex = 151
    enforceDesktopText(btnSuperSpeed)

    -- Logic
    local SECRET_CODE = "Nishgamer123" -- Hardcoded Secret Code

    unlockBtn.MouseButton1Click:Connect(function()
        local input = secretInput.Text
        if input == SECRET_CODE then
            statusLabel.Text = "Access Granted."
            statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
            secretContent.Visible = true
        else
            statusLabel.Text = "Incorrect Code."
            statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            secretContent.Visible = false
        end
    end)

    -- Logic: Features
    btnGodMode.MouseButton1Click:Connect(function()
        local hum = LocalPlayer.Character
        if hum then
            if hum.Health > 0 then
                hum.MaxHealth = math.huge
                hum.Health = math.huge
                statusLabel.Text = "God Mode Enabled"
            else
                statusLabel.Text = "Character dead or not found."
            end
        end
    end)

    btnNoclip.MouseButton1Click:Connect(
        local NOCLIP_ACTIVE = not NOCLIP_ACTIVE
        local function setNoclip(active)
            NOCLIP_ACTIVE = active
            btnNoclip.Text = "Noclip: On"
            btnNoclip.BackgroundColor3 = Color3.fromRGB(100, 255, 100)

            if NOCLIP_ACTIVE then
                local conn = RunService.RenderStepped:Connect(function()
                    if hum then
                        hum.PlatformStand = true
                        for _, child in pairs(hum.Parent:GetChildren()) do
                            if child:IsA("BasePart") then
                                child.CanCollide = false
                            end
                        end
                    end
                end)
            else
                if noclipConn then
                    noclipConn:Disconnect()
                    noclipConn = nil
                    -- Restore collision
                    local char = LocalPlayer.Character
                    if char then
                        local hum = char:FindFirstChildOfClass("Humanoid")
                        if hum then
                            for _, child in pairs(char:GetDescendants()) do
                                if child and child:IsA("BasePart") then
                                    pcall(function() child.CanCollide = true end)
                                end
                            end
                        end
                    end
                    btnNoclip.Text = "Noclip: Off"
                    btnNoclip.BackgroundColor3 = Color3.fromRGB(70,70,110)
                end
            end
        end
    end)

    btnSuperSpeed.MouseButton1Click:Connect(function()
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                if hum.WalkSpeed == 100 then
                    hum.WalkSpeed = 16
                    statusLabel.Text = "Super Speed On!"
                else
                    hum.WalkSpeed = 100
                    statusLabel.Text = "Super Speed On!"
                end
            else
                statusLabel.Text = "No Character."
            end
        else
            statusLabel.Text = "No Character."
        end
    end)
end

-- Save on exit
Players.PlayerRemoving:Connect(function() Save() end)
game:BindToClose(function() Save() end)

print("[Nishgamer Hub] Loaded — Drag Fixed, Instant Save, Key System, More (Auto Run), and Secret features added.")
