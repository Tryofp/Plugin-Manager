-- Tryo beta2 Waypoint / Checkpoint Manager
-- Standalone implementation. No Infinite Yield dependency.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local LocalPlayer = Players.LocalPlayer
local FILE_NAME = "TeleportCP_MasterSaves.json"
local HEIGHT_OFFSET = 1
local IGNORE = {
    "teleport","coin","gold","reward","cash","money","gem","damage","time",
    "chat","block","boost","tutorial","kill","brick","gift","adminzone",
    "crocodile","alligator","mob","npc","monster","animal","pet","zombie",
    "boss","bear","sky","skybox","cloud","atmosphere","barrier","invisible",
    "tree","branch","trunk","foliage","leaf","mushroom","axe","fence","bridge",
    "ladder","stair","fog","hat","skip","wood","stone","rock","bamboo","raft",
    "platform","floor","slime","camera","lamp","lantern","light","speaker",
    "audio","music","sound","effect","head","torso","humanoid","character",
    "arm","leg","face","hair","decoration","wall","roof","ceiling","window",
    "door","table","chair","particle","sparkle","fire","smoke","player"
}

local Feature = { Name = "Waypoint / Checkpoint Manager" }
local active = false
local connections = {}
local cache = {}
local saved = {}
local plainNumbers = {}
local gui, panel, list, nameBox, promptFrame
local page = "RADAR"
local scanBusy = false
local refreshQueued = false
local dragAction = "TryoWaypointDrag_" .. tostring(LocalPlayer.UserId)
local dragging = false
local dragInput, dragStart, frameStart

local function connect(signal, callback)
    local c = signal:Connect(callback)
    table.insert(connections, c)
    return c
end

local function notify(message)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "Waypoint Manager",
            Text = tostring(message),
            Duration = 2
        })
    end)
end

local function isIgnored(name)
    local lower = string.lower(tostring(name or ""))
    for _, word in ipairs(IGNORE) do
        if string.find(lower, word, 1, true) then return true end
    end
    return false
end

local function getHRP()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getPart(object)
    if not object then return nil end
    if object:IsA("BasePart") then return object end
    if object:IsA("Model") then
        return object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart", true)
    end
    return nil
end

local function getPath(object)
    local names = {}
    local current = object
    for _ = 1, 6 do
        if not current or current == Workspace then break end
        table.insert(names, 1, current.Name)
        current = current.Parent
    end
    return table.concat(names, ".")
end

local function folderContext(part)
    local current = part
    while current and current ~= Workspace do
        local n = string.lower(current.Name)
        if string.find(n, "gunung", 1, true) or string.find(n, "jalur", 1, true)
            or string.find(n, "track", 1, true) or string.find(n, "path", 1, true)
            or string.find(n, "route", 1, true) or string.find(n, "checkpoint", 1, true) then
            return current.Name
        end
        current = current.Parent
    end
    return "Main"
end

local function parseCheckpoint(object)
    if not object or not (object:IsA("BasePart") or object:IsA("Model")) then return nil end
    if isIgnored(object.Name) then return nil end
    local part = getPart(object)
    if not part then return nil end

    local parent = object.Parent
    local lowerName = string.lower(object.Name)
    local lowerParent = string.lower(parent and parent.Name or "")
    if lowerName == "text" or lowerName == "field" or lowerName == "base"
        or lowerParent == "text" or lowerParent == "field" or lowerParent == "base"
        or isIgnored(lowerParent) then return nil end

    local touch = part:FindFirstChild("TouchInterest") or part:FindFirstChildOfClass("TouchTransmitter")
    local prompt = object:FindFirstChildWhichIsA("ProximityPrompt", true)
        or part:FindFirstChildWhichIsA("ProximityPrompt", true)
    local plain = lowerName == "checkpoint" and lowerParent == "checkpoint"
    if not touch and not prompt and not plain then return nil end

    local context = folderContext(part)
    if string.find(lowerName, "summit", 1, true) or string.find(lowerParent, "summit", 1, true)
        or string.find(lowerName, "peak", 1, true) or string.find(lowerName, "finish", 1, true)
        or string.find(lowerName, "puncak", 1, true) then
        return "SUMMIT", context .. " - " .. object.Name, part, 10, false
    end
    if string.find(lowerName, "reset", 1, true) or string.find(lowerParent, "reset", 1, true) then
        local path = string.lower(getPath(object))
        if string.find(path, "checkpoint", 1, true) or string.find(path, "obby", 1, true)
            or string.find(path, "gunung", 1, true) then
            return "SUMMIT", context .. " - " .. object.Name, part, 10, false
        end
    end

    -- Exact plain Checkpoint.Checkpoint entries are numbered separately.
    if plain then
        return "PLAIN", context .. " - " .. object.Name, part, 3, true
    end

    local guiObject = part:FindFirstChildWhichIsA("BillboardGui")
        or part:FindFirstChildWhichIsA("SurfaceGui")
        or (part.Parent and part.Parent:IsA("Model") and (
            part.Parent:FindFirstChildWhichIsA("BillboardGui") or part.Parent:FindFirstChildWhichIsA("SurfaceGui")
        ))
    local guiText = ""
    if guiObject then
        local textLabel = guiObject:FindFirstChildWhichIsA("TextLabel", true)
        if textLabel then guiText = string.lower(textLabel.Text) end
    end
    local combined = lowerParent .. " " .. lowerName .. " " .. guiText
    local patterns = {
        "checkpoints?%s*[_ ]*(%d+%.?%d*)", "checkpoint(%d+%.?%d*)",
        "cekpoin%s*[_ ]*(%d+%.?%d*)", "cp%s*[_ ]*(%d+%.?%d*)",
        "cp(%d+%.?%d*)", "stage%s*[_ ]*(%d+%.?%d*)",
        "waypoint%s*[_ ]*(%d+%.?%d*)", "wp%s*[_ ]*(%d+%.?%d*)",
        "ring%s*[_ ]*(%d+%.?%d*)", "pos%s*[_ ]*(%d+%.?%d*)"
    }
    local number
    for _, pattern in ipairs(patterns) do
        number = string.match(combined, pattern)
        if number then break end
    end
    if not number and guiText ~= "" then number = string.match(guiText, "(%d+%.?%d*)") end
    if not number then number = string.match(object.Name, "^(%d+%.?%d*)$") end
    local n = tonumber(number)
    if not n or n < 0 or n > 500 then return nil end
    local description = guiText ~= "" and (context .. " - " .. guiText) or (context .. " - " .. object.Name)
    return n, description, part, 3, false
end

local function positionToken(position)
    return string.format("%.1f|%.1f|%.1f", position.X, position.Y, position.Z)
end

local function loadSaved()
    saved = {}
    if type(readfile) ~= "function" or type(isfile) ~= "function" then return end
    pcall(function()
        if not isfile(FILE_NAME) then return end
        local data = HttpService:JSONDecode(readfile(FILE_NAME))
        if type(data) == "table" and type(data[tostring(game.PlaceId)]) == "table" then
            saved = data[tostring(game.PlaceId)]
        end
    end)
    local used = {}
    for _, item in ipairs(saved) do
        local n = tonumber(item.key)
        if n and not item.plain then used[n] = true end
    end
    local plains = {}
    for _, item in ipairs(saved) do
        if item.cf and (item.plain or item.key == "CP+" or item.desc == "Checkpoint - Checkpoint") then
            table.insert(plains, item)
        end
    end
    table.sort(plains, function(a,b)
        local ap = CFrame.new(unpack(a.cf)).Position
        local bp = CFrame.new(unpack(b.cf)).Position
        if ap.Y == bp.Y then return ap.X == bp.X and ap.Z < bp.Z or ap.X < bp.X end
        return ap.Y < bp.Y
    end)
    local nextNumber = 1
    for _, item in ipairs(plains) do
        while used[nextNumber] do nextNumber = nextNumber + 1 end
        item.key, item.plain = nextNumber, true
        plainNumbers[positionToken(CFrame.new(unpack(item.cf)).Position)] = nextNumber
        used[nextNumber] = true
        nextNumber = nextNumber + 1
    end
end

local function persist()
    if type(writefile) ~= "function" then return false end
    local ok = pcall(function()
        local all = {}
        if type(readfile) == "function" and type(isfile) == "function" and isfile(FILE_NAME) then
            local decoded = HttpService:JSONDecode(readfile(FILE_NAME))
            if type(decoded) == "table" then all = decoded end
        end
        all[tostring(game.PlaceId)] = saved
        writefile(FILE_NAME, HttpService:JSONEncode(all))
    end)
    return ok
end

local function refresh()
    if refreshQueued then return end
    refreshQueued = true
    task.delay(0.15, function()
        refreshQueued = false
        if active and gui and gui.Parent then
            Feature.RefreshUI()
        end
    end)
end

local function assignPlainNumbers()
    local used = {}
    for _, item in ipairs(saved) do
        local n = tonumber(item.key)
        if n then used[n] = true end
    end
    local pending = {}
    for _, data in pairs(cache) do
        if data.plain and data.part and data.part.Parent then
            local token = positionToken(data.part.Position)
            if plainNumbers[token] then data.number = plainNumbers[token]
            elseif not data.number then table.insert(pending, data) end
        end
    end
    local hrp = getHRP()
    table.sort(pending, function(a,b)
        if hrp then
            local da = (a.part.Position - hrp.Position).Magnitude
            local db = (b.part.Position - hrp.Position).Magnitude
            if math.abs(da-db) > 0.01 then return da < db end
        end
        return a.part.Position.Y < b.part.Position.Y
    end)
    for _, data in ipairs(pending) do
        local token = positionToken(data.part.Position)
        local n = plainNumbers[token]
        if not n then
            n = 1
            while used[n] do n = n + 1 end
            plainNumbers[token] = n
        end
        data.number = n
        used[n] = true
    end
end

local function addSaved(key, description, cf, isPlain)
    local pos = cf.Position
    for _, item in ipairs(saved) do
        if item.cf and (CFrame.new(unpack(item.cf)).Position - pos).Magnitude < 3 then
            item.key, item.desc, item.cf, item.plain = key, description, {cf:GetComponents()}, isPlain == true
            persist()
            refresh()
            return
        end
    end
    table.insert(saved, {key=key, desc=description, cf={cf:GetComponents()}, plain=isPlain == true})
    table.sort(saved, function(a,b)
        local na, nb = tonumber(a.key), tonumber(b.key)
        if na and nb then return na < nb end
        if na then return true end
        if nb then return false end
        return tostring(a.key) < tostring(b.key)
    end)
    persist()
    refresh()
    notify("Tersimpan: " .. tostring(key))
end

local function saveFromData(data)
    if not data or not data.part or not data.part.Parent then return end
    assignPlainNumbers()
    local key = data.plain and (data.number or 1) or data.key
    addSaved(key, data.desc, data.part.CFrame, data.plain)
end

local function teleportTo(cf)
    local character = LocalPlayer.Character
    local root = getHRP()
    if not character or not root then notify("Karakter belum siap"); return end
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    character:PivotTo(cf + Vector3.new(0, HEIGHT_OFFSET, 0))
end

local function make(className, props, parent)
    local object = Instance.new(className)
    for k,v in pairs(props or {}) do object[k] = v end
    object.Parent = parent
    return object
end

local function corner(object, radius)
    make("UICorner", {CornerRadius=UDim.new(0,radius or 7)}, object)
end

local function button(parent, text, size, position, callback, accent)
    local b = make("TextButton", {
        Text=text, Size=size, Position=position, BackgroundColor3=accent and Color3.fromRGB(93,78,145) or Color3.fromRGB(43,53,72),
        BackgroundTransparency=0.12, TextColor3=Color3.fromRGB(238,241,250),
        Font=Enum.Font.GothamMedium, TextSize=11, BorderSizePixel=0, AutoButtonColor=true
    }, parent)
    corner(b,6)
    b.MouseButton1Click:Connect(callback)
    return b
end

local function showNamePrompt()
    if promptFrame then promptFrame:Destroy() end
    promptFrame = make("Frame", {
        Size=UDim2.fromOffset(260,125), Position=UDim2.new(0.5,-130,0.5,-62),
        BackgroundColor3=Color3.fromRGB(29,36,52), BackgroundTransparency=0.08, BorderSizePixel=0, ZIndex=20
    }, gui)
    corner(promptFrame,9)
    make("UIStroke",{Color=Color3.fromRGB(116,137,181),Transparency=0.45},promptFrame)
    make("TextLabel",{Text="Nama waypoint manual",Position=UDim2.fromOffset(12,8),Size=UDim2.new(1,-24,0,22),BackgroundTransparency=1,TextColor3=Color3.fromRGB(238,241,250),Font=Enum.Font.GothamBold,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=21},promptFrame)
    nameBox = make("TextBox",{Text="",PlaceholderText="Contoh: Pos Istirahat",Position=UDim2.fromOffset(12,36),Size=UDim2.new(1,-24,0,30),BackgroundColor3=Color3.fromRGB(43,53,72),TextColor3=Color3.new(1,1,1),PlaceholderColor3=Color3.fromRGB(150,156,174),Font=Enum.Font.Gotham,TextSize=12,ClearTextOnFocus=false,ZIndex=21},promptFrame)
    corner(nameBox,6)
    button(promptFrame,"SAVE",UDim2.fromOffset(105,27),UDim2.fromOffset(12,82),function()
        local text = string.gsub(nameBox.Text or "", "^%s*(.-)%s*$", "%1")
        if text ~= "" then
            local root = getHRP()
            if root then addSaved("", text, root.CFrame, false) end
        end
        promptFrame:Destroy(); promptFrame=nil
    end,true).ZIndex = 21
    button(promptFrame,"CANCEL",UDim2.fromOffset(105,27),UDim2.new(1,-117,0,82),function()
        promptFrame:Destroy(); promptFrame=nil
    end,false).ZIndex = 21
end

local function buildUI()
    local parent
    pcall(function() parent = game:GetService("CoreGui") end)
    if not parent then parent = LocalPlayer:WaitForChild("PlayerGui") end
    gui = make("ScreenGui",{Name="TryoWaypointManager",ResetOnSpawn=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},parent)
    panel = make("Frame",{
        Name="Panel",Size=UDim2.fromOffset(340,330),Position=UDim2.new(0.5,-170,0.35,0),
        BackgroundColor3=Color3.fromRGB(25,32,46),BackgroundTransparency=0.16,BorderSizePixel=0,ClipsDescendants=true
    },gui)
    corner(panel,10)
    make("UIStroke",{Color=Color3.fromRGB(112,142,185),Transparency=0.45},panel)
    make("UIGradient",{Color=ColorSequence.new(Color3.fromRGB(43,76,108),Color3.fromRGB(75,48,105)),Rotation=28},panel)
    local header = make("TextButton",{
        Name="Header",Text="WAYPOINT MANAGER  •  " .. tostring(game.PlaceId),Size=UDim2.new(1,0,0,36),
        BackgroundColor3=Color3.fromRGB(47,80,112),BackgroundTransparency=0.12,TextColor3=Color3.fromRGB(245,247,255),
        Font=Enum.Font.GothamBold,TextSize=11,BorderSizePixel=0,AutoButtonColor=false
    },panel)
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging=true; dragStart=input.Position; frameStart=panel.Position
            ContextActionService:BindActionAtPriority(dragAction,function() return Enum.ContextActionResult.Sink end,false,3000,Enum.UserInputType.MouseButton1,Enum.UserInputType.Touch)
        end
    end)
    connect(UserInputService.InputChanged,function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local delta=input.Position-dragStart
            panel.Position=UDim2.new(frameStart.X.Scale,frameStart.X.Offset+delta.X,frameStart.Y.Scale,frameStart.Y.Offset+delta.Y)
        end
    end)
    connect(UserInputService.InputEnded,function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            dragging=false
            ContextActionService:UnbindAction(dragAction)
        end
    end)

    button(panel,"×",UDim2.fromOffset(28,25),UDim2.new(1,-32,0,5),function() Feature.Stop() end,false).ZIndex=3
    button(panel,"RADAR",UDim2.fromOffset(72,25),UDim2.fromOffset(10,42),function() page="RADAR"; Feature.RefreshUI() end,page=="RADAR")
    button(panel,"SAVED",UDim2.fromOffset(72,25),UDim2.fromOffset(88,42),function() page="SAVED"; Feature.RefreshUI() end,page=="SAVED")
    button(panel,"＋ SAVE HERE",UDim2.fromOffset(105,25),UDim2.new(1,-115,0,42),showNamePrompt,true)
    button(panel,"REFRESH",UDim2.fromOffset(72,23),UDim2.fromOffset(10,72),function() Feature.Scan(); Feature.RefreshUI() end,false)

    list=make("ScrollingFrame",{
        Name="WaypointList",Position=UDim2.fromOffset(10,101),Size=UDim2.new(1,-20,1,-111),
        BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,CanvasSize=UDim2.new(0,0,0,0)
    },panel)
    make("UIListLayout",{Padding=UDim.new(0,5),SortOrder=Enum.SortOrder.LayoutOrder},list)
end

function Feature.RefreshUI()
    if not list then return end
    for _, child in ipairs(list:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    local entries={}
    if page=="RADAR" then
        assignPlainNumbers()
        for _,data in pairs(cache) do
            if data.part and data.part.Parent then
                local key=data.plain and (data.number or 1) or data.key
                local already=false
                for _,item in ipairs(saved) do
                    if item.cf and (CFrame.new(unpack(item.cf)).Position-data.part.Position).Magnitude<3 then already=true; break end
                end
                if not already then table.insert(entries,{key=key,desc=data.desc,part=data.part,data=data}) end
            end
        end
        table.sort(entries,function(a,b)
            local na,nb=tonumber(a.key),tonumber(b.key)
            if na and nb then return na<nb end
            if na then return true end
            if nb then return false end
            return tostring(a.key)<tostring(b.key)
        end)
    else
        for index,item in ipairs(saved) do table.insert(entries,{key=item.key,desc=item.desc,item=item,index=index}) end
    end

    for index,entry in ipairs(entries) do
        local row=make("Frame",{Size=UDim2.new(1,-4,0,31),BackgroundColor3=Color3.fromRGB(34,43,60),BackgroundTransparency=0.12,BorderSizePixel=0,LayoutOrder=index},list)
        corner(row,6)
        local keyText=entry.key=="SUMMIT" and "SUMMIT" or (entry.key=="" and "MANUAL" or "CP "..tostring(entry.key))
        make("TextLabel",{Text=keyText,Position=UDim2.fromOffset(7,0),Size=UDim2.fromOffset(66,31),BackgroundTransparency=1,TextColor3=Color3.fromRGB(105,210,245),Font=Enum.Font.GothamBold,TextSize=10,TextXAlignment=Enum.TextXAlignment.Left},row)
        make("TextLabel",{Text=tostring(entry.desc),Position=UDim2.fromOffset(72,0),Size=UDim2.new(1,-157,1,0),BackgroundTransparency=1,TextColor3=Color3.fromRGB(225,230,242),Font=Enum.Font.Gotham,TextSize=10,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd},row)
        if page=="RADAR" then
            button(row,"SAVE",UDim2.fromOffset(68,23),UDim2.new(1,-73,0,4),function() saveFromData(entry.data) end,true)
        else
            button(row,"TELE",UDim2.fromOffset(45,23),UDim2.new(1,-94,0,4),function()
                if entry.item.cf then teleportTo(CFrame.new(unpack(entry.item.cf))) end
            end,true)
            button(row,"DEL",UDim2.fromOffset(40,23),UDim2.new(1,-45,0,4),function()
                table.remove(saved,entry.index); persist(); Feature.RefreshUI()
            end,false)
        end
    end
    task.defer(function()
        if list then list.CanvasSize=UDim2.new(0,0,0,list.UIListLayout.AbsoluteContentSize.Y+5) end
    end)
end

function Feature.Scan()
    if scanBusy or not active then return end
    scanBusy=true
    task.spawn(function()
        local descendants=Workspace:GetDescendants()
        for i,object in ipairs(descendants) do
            if not active then break end
            local key,desc,part,priority,plain=parseCheckpoint(object)
            if key and part and part.Parent then
                local cacheKey=plain and part or getPath(part)
                if not cache[cacheKey] then
                    cache[cacheKey]={key=key,desc=desc,part=part,priority=priority,plain=plain==true}
                    if part:FindFirstChild("TouchInterest") or plain then
                        local lastTouch=0
                        connect(part.Touched,function(hit)
                            if not active or tick()-lastTouch<1 then return end
                            local char=LocalPlayer.Character
                            local hum=char and char:FindFirstChildOfClass("Humanoid")
                            if char and hit:IsDescendantOf(char) and hum and hum.Health>0 then
                                lastTouch=tick()
                                saveFromData(cache[cacheKey])
                            end
                        end)
                    end
                    local prompt=part:FindFirstChildWhichIsA("ProximityPrompt",true)
                    if prompt then
                        connect(prompt.Triggered,function(player)
                            if player==LocalPlayer then saveFromData(cache[cacheKey]) end
                        end)
                    end
                end
            end
            if i%80==0 then task.wait() end
        end
        scanBusy=false
        assignPlainNumbers()
        refresh()
    end)
end

function Feature.Start()
    if active then return true end
    active=true
    loadSaved()
    buildUI()
    connect(Workspace.DescendantAdded,function(object)
        task.delay(0.2,function()
            if not active then return end
            local key,desc,part,priority,plain=parseCheckpoint(object)
            if key and part and part.Parent then
                local cacheKey=plain and part or getPath(part)
                if not cache[cacheKey] then
                    cache[cacheKey]={key=key,desc=desc,part=part,priority=priority,plain=plain==true}
                    if part:FindFirstChild("TouchInterest") or plain then
                        local lastTouch=0
                        connect(part.Touched,function(hit)
                            if not active or tick()-lastTouch<1 then return end
                            local char=LocalPlayer.Character
                            local hum=char and char:FindFirstChildOfClass("Humanoid")
                            if char and hit:IsDescendantOf(char) and hum and hum.Health>0 then lastTouch=tick(); saveFromData(cache[cacheKey]) end
                        end)
                    end
                    local prompt=part:FindFirstChildWhichIsA("ProximityPrompt",true)
                    if prompt then connect(prompt.Triggered,function(player) if player==LocalPlayer then saveFromData(cache[cacheKey]) end end) end
                    assignPlainNumbers(); refresh()
                end
            end
        end)
    end)
    Feature.Scan()
    notify("Scanner checkpoint aktif")
    return true
end

function Feature.Stop()
    if not active then return true end
    active=false
    dragging=false
    ContextActionService:UnbindAction(dragAction)
    for _,connection in ipairs(connections) do pcall(function() connection:Disconnect() end) end
    table.clear(connections)
    if gui then gui:Destroy() end
    gui,panel,list,nameBox,promptFrame=nil,nil,nil,nil,nil
    table.clear(cache)
    notify("Waypoint Manager dimatikan")
    return true
end

return Feature
