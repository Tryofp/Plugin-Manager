-- Tryo Standalone Interactable Scanner
-- Event-driven object detection with lightweight ESP and a compact browser panel.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local LocalPlayer = Players.LocalPlayer
local Feature = { Name = "Interactable Scanner" }

local COLORS = {
    Proximity = Color3.fromRGB(45, 145, 255),
    Door = Color3.fromRGB(45, 190, 255),
    Click = Color3.fromRGB(255, 220, 55),
    Touch = Color3.fromRGB(65, 225, 135),
    Loot = Color3.fromRGB(255, 105, 95)
}
local TABS = {"Proximity", "Door", "Click", "Touch", "Loot"}
local LOOT_WORDS = {
    "loot", "item", "pickup", "collect", "drop", "chest", "crate",
    "supply", "weapon", "key", "kunci", "keris", "sword", "fuel",
    "bensin", "artifact", "relic", "coin", "gold", "reward"
}
local DOOR_WORDS = {
    "door", "gate", "entrance", "exit", "portal", "hatch",
    "pintu", "gerbang", "airlock", "passage"
}

local active = false
local records = {}
local byKey = {}
local connections = {}
local currentTab = "Proximity"
local filterText = ""
local gui
local listFrame
local titleLabel
local countLabel
local scanGeneration = 0
local lastUiUpdate = 0
local dragConnection
local dragActionName = "TryoInteractableDrag"

local function lower(value)
    return string.lower(tostring(value or ""))
end

local function hasWord(text, words)
    text = lower(text)
    for _, word in ipairs(words) do
        if string.find(text, word, 1, true) then return true end
    end
    return false
end

local function isPlayerPart(part)
    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        if character and part:IsDescendantOf(character) then return true end
    end
    return false
end

local function getBasePart(object)
    if not object then return nil end
    if object:IsA("BasePart") then return object end
    local cursor = object
    for _ = 1, 8 do
        if not cursor or cursor == Workspace then break end
        if cursor:IsA("BasePart") then return cursor end
        if cursor:IsA("Model") and cursor.PrimaryPart then return cursor.PrimaryPart end
        cursor = cursor.Parent
    end
    local model = object:FindFirstAncestorWhichIsA("Model")
    if model then return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true) end
    return nil
end

local function getContextName(object, part)
    local names = {}
    local cursor = object
    for _ = 1, 7 do
        if not cursor or cursor == Workspace then break end
        table.insert(names, cursor.Name)
        cursor = cursor.Parent
    end
    if part then table.insert(names, part.Name) end
    return table.concat(names, " ")
end

local function classify(object)
    if not object or not object.Parent then return nil end
    local kind, part, label

    if object:IsA("ProximityPrompt") then
        part = getBasePart(object.Parent)
        if not part then return nil end
        local text = getContextName(object, part) .. " " .. object.ActionText .. " " .. object.ObjectText
        kind = hasWord(text, DOOR_WORDS) and "Door" or "Proximity"
        label = object.ObjectText ~= "" and object.ObjectText or (object.ActionText ~= "" and object.ActionText or part.Name)
    elseif object:IsA("ClickDetector") then
        part = getBasePart(object.Parent)
        kind = "Click"
        label = part and part.Name
    elseif object.ClassName == "TouchTransmitter" then
        part = getBasePart(object.Parent)
        if not part or isPlayerPart(part) then return nil end
        local text = getContextName(object, part)
        kind = hasWord(text, LOOT_WORDS) and "Loot" or "Touch"
        label = part.Name
    elseif object:IsA("Model") or object:IsA("BasePart") then
        local text = getContextName(object, object:IsA("BasePart") and object or nil)
        if hasWord(text, LOOT_WORDS) then
            part = getBasePart(object)
            kind = "Loot"
            label = object.Name
        end
    end

    if not part or not part:IsDescendantOf(Workspace) or isPlayerPart(part) then return nil end
    return {Key = object, Part = part, Kind = kind, Name = tostring(label or part.Name)}
end

local function removeRecord(key)
    local record = byKey[key]
    if not record then return end
    if record.Box then pcall(function() record.Box:Destroy() end) end
    if record.Label then pcall(function() record.Label:Destroy() end) end
    byKey[key] = nil
    for i = #records, 1, -1 do
        if records[i] == record then table.remove(records, i) break end
    end
end

local function addRecord(data)
    if not active or not data or byKey[data.Key] then return end
    local part = data.Part
    if not part or not part.Parent then return end

    local box = Instance.new("BoxHandleAdornment")
    box.Name = "TryoInteractableESP"
    box.Adornee = part
    box.Size = part.Size
    box.AlwaysOnTop = true
    box.ZIndex = 5
    box.Transparency = 0.18
    box.Color3 = COLORS[data.Kind] or Color3.new(1, 1, 1)
    box.Parent = part

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "TryoInteractableLabel"
    billboard.Adornee = part
    billboard.Size = UDim2.fromOffset(150, 22)
    billboard.StudsOffset = Vector3.new(0, math.max(2, part.Size.Y * 0.5 + 1), 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 800
    billboard.Parent = part

    local text = Instance.new("TextLabel")
    text.Size = UDim2.fromScale(1, 1)
    text.BackgroundColor3 = Color3.fromRGB(18, 24, 34)
    text.BackgroundTransparency = 0.22
    text.BorderSizePixel = 0
    text.Font = Enum.Font.GothamSemibold
    text.TextSize = 11
    text.TextColor3 = COLORS[data.Kind] or Color3.new(1, 1, 1)
    text.TextStrokeTransparency = 0.65
    text.Text = data.Kind .. " • " .. data.Name
    text.TextTruncate = Enum.TextTruncate.AtEnd
    text.Parent = billboard
    Instance.new("UICorner", text).CornerRadius = UDim.new(0, 5)

    data.Box = box
    data.Label = billboard
    byKey[data.Key] = data
    table.insert(records, data)
end

local function clearRows()
    if not listFrame then return end
    for _, child in ipairs(listFrame:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
end

local function getRoot()
    local character = LocalPlayer.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function refreshList()
    if not listFrame or not listFrame.Parent then return end
    clearRows()
    local root = getRoot()
    local found = {}

    for _, record in ipairs(records) do
        local part = record.Part
        if record.Kind == currentTab and part and part.Parent and part:IsDescendantOf(Workspace) then
            local nameMatch = filterText == "" or string.find(lower(record.Name), filterText, 1, true)
            if nameMatch then
                local distance = root and (part.Position - root.Position).Magnitude or math.huge
                if distance <= 800 then
                    table.insert(found, {Record = record, Distance = distance})
                end
            end
        end
    end

    table.sort(found, function(a, b) return a.Distance < b.Distance end)
    countLabel.Text = tostring(#found) .. " detected"
    for index = 1, math.min(#found, 45) do
        local item = found[index]
        local record = item.Record
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -4, 0, 30)
        row.BackgroundColor3 = Color3.fromRGB(35, 45, 60)
        row.BackgroundTransparency = 0.2
        row.BorderSizePixel = 0
        row.LayoutOrder = index
        row.Parent = listFrame
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 5)

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -92, 1, 0)
        label.Position = UDim2.fromOffset(7, 0)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.Gotham
        label.TextSize = 10
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextColor3 = Color3.fromRGB(235, 240, 248)
        label.TextTruncate = Enum.TextTruncate.AtEnd
        label.Text = string.format("%s  [%.0fm]", record.Name, item.Distance)
        label.Parent = row

        local tp = Instance.new("TextButton")
        tp.Size = UDim2.fromOffset(62, 22)
        tp.Position = UDim2.new(1, -68, 0.5, -11)
        tp.BackgroundColor3 = Color3.fromRGB(30, 155, 115)
        tp.BorderSizePixel = 0
        tp.Font = Enum.Font.GothamBold
        tp.TextSize = 10
        tp.TextColor3 = Color3.new(1, 1, 1)
        tp.Text = "TELE"
        tp.Parent = row
        Instance.new("UICorner", tp).CornerRadius = UDim.new(0, 4)
        tp.MouseButton1Click:Connect(function()
            local target = record.Part
            local character = LocalPlayer.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if target and target.Parent and character and humanoid and humanoid.Health > 0 then
                pcall(function()
                    character:PivotTo(CFrame.new(target.Position + Vector3.new(0, 3, 0)))
                end)
            end
        end)
    end
    listFrame.CanvasSize = UDim2.new(0, 0, 0, math.min(#found, 45) * 34)
end

local function buildGui()
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    gui = Instance.new("ScreenGui")
    gui.Name = "TryoInteractableScanner"
    gui.ResetOnSpawn = false
    gui.Parent = playerGui

    local frame = Instance.new("Frame")
    frame.Name = "Panel"
    frame.Size = UDim2.fromOffset(310, 330)
    frame.Position = UDim2.new(0.5, -155, 0.5, -165)
    frame.BackgroundColor3 = Color3.fromRGB(25, 34, 49)
    frame.BackgroundTransparency = 0.18
    frame.BorderSizePixel = 0
    frame.Parent = gui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(45, 85, 115)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(70, 45, 100))
    })
    gradient.Rotation = 35
    gradient.Parent = frame
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(115, 165, 205)
    stroke.Transparency = 0.55
    stroke.Parent = frame

    local top = Instance.new("TextButton")
    top.Size = UDim2.new(1, 0, 0, 34)
    top.BackgroundColor3 = Color3.fromRGB(35, 65, 95)
    top.BackgroundTransparency = 0.15
    top.BorderSizePixel = 0
    top.Text = "INTERACTABLE SCANNER"
    top.Font = Enum.Font.GothamBold
    top.TextSize = 12
    top.TextColor3 = Color3.new(1, 1, 1)
    top.Parent = frame
    Instance.new("UICorner", top).CornerRadius = UDim.new(0, 9)

    local close = Instance.new("TextButton")
    close.Size = UDim2.fromOffset(25, 23)
    close.Position = UDim2.new(1, -29, 0, 5)
    close.BackgroundColor3 = Color3.fromRGB(175, 65, 75)
    close.BorderSizePixel = 0
    close.Text = "×"
    close.TextSize = 16
    close.Font = Enum.Font.GothamBold
    close.TextColor3 = Color3.new(1, 1, 1)
    close.Parent = frame
    Instance.new("UICorner", close).CornerRadius = UDim.new(0, 5)
    close.MouseButton1Click:Connect(function()
        if dragConnection then dragConnection:Disconnect(); dragConnection = nil end
        ContextActionService:UnbindAction(dragActionName)
        if gui then gui:Destroy(); gui = nil; listFrame = nil; titleLabel = nil; countLabel = nil end
    end)

    local tabs = Instance.new("Frame")
    tabs.Size = UDim2.new(1, -14, 0, 26)
    tabs.Position = UDim2.fromOffset(7, 40)
    tabs.BackgroundTransparency = 1
    tabs.Parent = frame
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.Padding = UDim.new(0, 3)
    layout.Parent = tabs

    for _, tabName in ipairs(TABS) do
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(0, 56, 1, 0)
        button.BackgroundColor3 = tabName == currentTab and Color3.fromRGB(105, 80, 170) or Color3.fromRGB(45, 55, 70)
        button.BorderSizePixel = 0
        button.Text = tabName
        button.Font = Enum.Font.GothamBold
        button.TextSize = 9
        button.TextColor3 = Color3.new(1, 1, 1)
        button.Parent = tabs
        Instance.new("UICorner", button).CornerRadius = UDim.new(0, 4)
        button.MouseButton1Click:Connect(function()
            currentTab = tabName
            for _, child in ipairs(tabs:GetChildren()) do
                if child:IsA("TextButton") then
                    child.BackgroundColor3 = child.Text == currentTab and Color3.fromRGB(105, 80, 170) or Color3.fromRGB(45, 55, 70)
                end
            end
            refreshList()
        end)
    end

    local search = Instance.new("TextBox")
    search.Size = UDim2.new(1, -88, 0, 26)
    search.Position = UDim2.fromOffset(7, 72)
    search.BackgroundColor3 = Color3.fromRGB(20, 28, 40)
    search.BackgroundTransparency = 0.12
    search.BorderSizePixel = 0
    search.PlaceholderText = "Filter keyword..."
    search.Text = ""
    search.ClearTextOnFocus = false
    search.Font = Enum.Font.Gotham
    search.TextSize = 10
    search.TextColor3 = Color3.new(1, 1, 1)
    search.Parent = frame
    Instance.new("UICorner", search).CornerRadius = UDim.new(0, 5)
    search:GetPropertyChangedSignal("Text"):Connect(function()
        filterText = lower(search.Text)
        refreshList()
    end)

    local refresh = Instance.new("TextButton")
    refresh.Size = UDim2.fromOffset(72, 26)
    refresh.Position = UDim2.new(1, -79, 0, 72)
    refresh.BackgroundColor3 = Color3.fromRGB(50, 125, 155)
    refresh.BorderSizePixel = 0
    refresh.Text = "REFRESH"
    refresh.Font = Enum.Font.GothamBold
    refresh.TextSize = 9
    refresh.TextColor3 = Color3.new(1, 1, 1)
    refresh.Parent = frame
    Instance.new("UICorner", refresh).CornerRadius = UDim.new(0, 5)
    refresh.MouseButton1Click:Connect(function()
        scanGeneration += 1
        local generation = scanGeneration
        task.spawn(function()
            for index, object in ipairs(Workspace:GetDescendants()) do
                if not active or generation ~= scanGeneration then return end
                local data = classify(object)
                if data then addRecord(data) end
                if index % 100 == 0 then task.wait() end
            end
            refreshList()
        end)
    end)

    countLabel = Instance.new("TextLabel")
    countLabel.Size = UDim2.new(1, -14, 0, 18)
    countLabel.Position = UDim2.fromOffset(7, 101)
    countLabel.BackgroundTransparency = 1
    countLabel.Font = Enum.Font.Gotham
    countLabel.TextSize = 10
    countLabel.TextColor3 = Color3.fromRGB(190, 205, 220)
    countLabel.TextXAlignment = Enum.TextXAlignment.Left
    countLabel.Text = "0 detected"
    countLabel.Parent = frame

    listFrame = Instance.new("ScrollingFrame")
    listFrame.Size = UDim2.new(1, -14, 1, -128)
    listFrame.Position = UDim2.fromOffset(7, 122)
    listFrame.BackgroundColor3 = Color3.fromRGB(16, 23, 34)
    listFrame.BackgroundTransparency = 0.35
    listFrame.BorderSizePixel = 0
    listFrame.ScrollBarThickness = 3
    listFrame.CanvasSize = UDim2.new()
    listFrame.Parent = frame
    Instance.new("UICorner", listFrame).CornerRadius = UDim.new(0, 6)
    local rows = Instance.new("UIListLayout")
    rows.Padding = UDim.new(0, 4)
    rows.SortOrder = Enum.SortOrder.LayoutOrder
    rows.Parent = listFrame
    rows:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        listFrame.CanvasSize = UDim2.new(0, 0, 0, rows.AbsoluteContentSize.Y + 4)
    end)

    local dragging, dragStart, startPos
    top.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            ContextActionService:BindActionAtPriority(dragActionName, function()
                return Enum.ContextActionResult.Sink
            end, false, 3000, Enum.UserInputType.MouseButton1, Enum.UserInputType.Touch)
        end
    end)
    top.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            ContextActionService:UnbindAction(dragActionName)
        end
    end)
    dragConnection = UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    refreshList()
end

function Feature:Start()
    if active then return true end
    active = true
    scanGeneration += 1
    local generation = scanGeneration
    buildGui()

    task.spawn(function()
        for index, object in ipairs(Workspace:GetDescendants()) do
            if not active or generation ~= scanGeneration then return end
            local data = classify(object)
            if data then addRecord(data) end
            if index % 100 == 0 then task.wait() end
        end
        refreshList()
    end)

    connections.added = Workspace.DescendantAdded:Connect(function(object)
        task.defer(function()
            if not active then return end
            local data = classify(object)
            if data then
                addRecord(data)
                refreshList()
            end
        end)
    end)
    connections.removing = Workspace.DescendantRemoving:Connect(function(object)
        removeRecord(object)
        for key, data in pairs(byKey) do
            local part = data.Part
            if part == object or (part and part:IsDescendantOf(object)) then
                removeRecord(key)
            end
        end
    end)
    connections.playerRemoving = Players.PlayerRemoving:Connect(function(player)
        if player.Character then
            for key, data in pairs(byKey) do
                if data.Part and data.Part:IsDescendantOf(player.Character) then removeRecord(key) end
            end
        end
    end)

    connections.ui = game:GetService("RunService").Heartbeat:Connect(function()
        if not active then return end
        local now = os.clock()
        if now - lastUiUpdate >= 0.6 then
            lastUiUpdate = now
            refreshList()
        end
    end)
    return true
end

function Feature:Stop()
    if not active then return true end
    active = false
    scanGeneration += 1
    for _, connection in pairs(connections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(connections)
    if dragConnection then dragConnection:Disconnect(); dragConnection = nil end
    ContextActionService:UnbindAction(dragActionName)
    for key in pairs(byKey) do removeRecord(key) end
    table.clear(records)
    if gui then gui:Destroy(); gui = nil end
    listFrame = nil
    countLabel = nil
    return true
end

return Feature
