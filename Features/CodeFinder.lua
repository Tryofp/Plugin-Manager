-- Standalone Code Finder: scans only client-visible puzzle/map data.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

local Feature = {}
local activeGui
local dragConnection
local MIN_LENGTH, MAX_LENGTH, MAX_RESULTS = 3, 12, 80
local KEYWORDS = {
    "code","kode","pin","password","passcode","combination","combo","vault",
    "safe","brankas","keypad","door","puzzle","clue","hint","lock","security","secret","digit"
}
local BLOCKED_PATHS = {
    "playergui","players.","leaderstats","userid","user_id","account","backpack","character"
}

local function notify(title, message)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = title, Text = message, Duration = 4
        })
    end)
end

local function hasKeyword(value)
    local text = string.lower(tostring(value or ""))
    for _, word in ipairs(KEYWORDS) do
        if string.find(text, word, 1, true) then return true end
    end
    return false
end

local function blockedPath(path)
    local text = string.lower(path)
    for _, word in ipairs(BLOCKED_PATHS) do
        if string.find(text, word, 1, true) then return true end
    end
    return false
end

local function getPath(instance)
    local ok, path = pcall(function() return instance:GetFullName() end)
    return ok and path or instance.Name
end

local function scan()
    local playerNames = {}
    for _, player in ipairs(Players:GetPlayers()) do
        playerNames[string.lower(player.Name)] = true
        playerNames[string.lower(player.DisplayName)] = true
    end

    local results, seen = {}, {}
    local function add(value, path, source, context)
        value = tostring(value or "")
        if #results >= MAX_RESULTS or #value < MIN_LENGTH or #value > MAX_LENGTH then return end
        if blockedPath(path) then return end
        local numeric = value:match("^%d+$") ~= nil
        local alpha = value:match("^[A-Za-z]+$") ~= nil
        if not numeric and not alpha then return end
        local lower = string.lower(value)
        if playerNames[lower] or seen[lower] or hasKeyword(value) then return end
        local contextual = hasKeyword(path) or hasKeyword(context)
        if alpha and (value ~= string.upper(value) or #value < 4) and not contextual then return end
        if numeric and (#value == 3 or value == "1234" or value == "0000" or value == "1111") and not contextual then return end
        seen[lower] = true
        table.insert(results, {
            Code = value, Path = path, Source = source,
            Priority = contextual and 3 or 1
        })
    end

    local function scanText(value, path, source)
        if type(value) ~= "string" or value == "" then return end
        for token in value:gmatch("[%w]+") do
            if #token >= MIN_LENGTH and #token <= MAX_LENGTH then
                if token:match("^%d+$") or token:match("^[A-Za-z]+$") then
                    add(token, path, source, value)
                end
            end
        end
    end

    local containers = {workspace, ReplicatedStorage, ReplicatedFirst}
    local scanned = 0
    for _, container in ipairs(containers) do
        local ok, descendants = pcall(function() return container:GetDescendants() end)
        if ok and descendants then
            for _, instance in ipairs(descendants) do
                if scanned >= 16000 or #results >= MAX_RESULTS then break end
                scanned += 1
                pcall(function()
                    local path = getPath(instance)
                    if blockedPath(path) then return end
                    for name, value in pairs(instance:GetAttributes()) do
                        local attributePath = path .. " [Attribute: " .. tostring(name) .. "]"
                        if type(value) == "string" then
                            scanText(value, attributePath, "Attribute")
                        elseif type(value) == "number" and value % 1 == 0 then
                            add(value, attributePath, "Attribute", name)
                        end
                    end
                    if instance:IsA("StringValue") then
                        scanText(instance.Value, path, "StringValue")
                    elseif instance:IsA("IntValue") then
                        add(instance.Value, path, "IntValue", instance.Name)
                    elseif instance:IsA("NumberValue") then
                        if instance.Value % 1 == 0 then add(instance.Value, path, "NumberValue", instance.Name) end
                    elseif instance:IsA("TextLabel") or instance:IsA("TextButton")
                        or instance:IsA("TextBox") then
                        scanText(instance.Text, path, instance.ClassName)
                    end
                    if hasKeyword(instance.Name) then
                        scanText(instance.Name, path, "InstanceName")
                    end
                end)
            end
        end
    end

    table.sort(results, function(a, b)
        if a.Priority ~= b.Priority then return a.Priority > b.Priority end
        if #a.Code ~= #b.Code then return #a.Code > #b.Code end
        return a.Code < b.Code
    end)
    return results, scanned
end

local function make(className, props, parent)
    local object = Instance.new(className)
    for key, value in pairs(props or {}) do object[key] = value end
    object.Parent = parent
    return object
end

local function corner(parent, radius)
    make("UICorner", {CornerRadius = UDim.new(0, radius)}, parent)
end

local function buildGui(results, scanned)
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not playerGui then return nil end
    local gui = make("ScreenGui", {
        Name = "TryoCodeFinder", ResetOnSpawn = false, IgnoreGuiInset = true
    }, playerGui)
    local frame = make("Frame", {
        Name = "Panel", Size = UDim2.fromOffset(360, 310),
        Position = UDim2.new(0.5, -180, 0.5, -155),
        BackgroundColor3 = Color3.fromRGB(38, 48, 68),
        BackgroundTransparency = 0.16, BorderSizePixel = 0
    }, gui)
    corner(frame, 12)
    make("UIStroke", {Color = Color3.fromRGB(105, 160, 205), Transparency = 0.55}, frame)
    make("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(55, 105, 135)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 55, 115))
        }), Rotation = 25
    }, frame)

    local title = make("TextLabel", {
        Size = UDim2.new(1, -90, 0, 38), Position = UDim2.fromOffset(12, 2),
        BackgroundTransparency = 1, Text = "CODE FINDER",
        TextColor3 = Color3.new(1,1,1), TextSize = 15,
        Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left
    }, frame)
    local close = make("TextButton", {
        Size = UDim2.fromOffset(32, 30), Position = UDim2.new(1, -38, 0, 4),
        BackgroundTransparency = 1, Text = "×", TextColor3 = Color3.fromRGB(255,120,120),
        TextSize = 24, Font = Enum.Font.GothamBold
    }, frame)
    close.MouseButton1Click:Connect(function() gui:Destroy() end)

    make("TextLabel", {
        Size = UDim2.new(1, -24, 0, 22), Position = UDim2.fromOffset(12, 38),
        BackgroundTransparency = 1,
        Text = string.format("%d candidate(s) • %d objects scanned", #results, scanned),
        TextColor3 = Color3.fromRGB(205, 215, 230), TextSize = 10,
        Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left
    }, frame)

    local scroll = make("ScrollingFrame", {
        Name = "Results", Size = UDim2.new(1, -18, 1, -72),
        Position = UDim2.fromOffset(9, 66), BackgroundColor3 = Color3.fromRGB(20, 26, 38),
        BackgroundTransparency = 0.22, BorderSizePixel = 0,
        ScrollBarThickness = 3, AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new()
    }, frame)
    corner(scroll, 8)
    make("UIPadding", {
        PaddingTop = UDim.new(0, 7), PaddingBottom = UDim.new(0, 7),
        PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7)
    }, scroll)
    make("UIListLayout", {Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder}, scroll)

    if #results == 0 then
        make("TextLabel", {
            Size = UDim2.new(1, -8, 0, 58), BackgroundTransparency = 1,
            Text = "Belum ada kandidat kode. Coba buka area/clue puzzle lalu scan lagi.",
            TextColor3 = Color3.fromRGB(205, 215, 230), TextSize = 12,
            Font = Enum.Font.Gotham, TextWrapped = true
        }, scroll)
    else
        for index, result in ipairs(results) do
            local item = make("Frame", {
                Size = UDim2.new(1, -3, 0, 57),
                BackgroundColor3 = result.Priority >= 3 and Color3.fromRGB(75, 69, 48) or Color3.fromRGB(43, 52, 70),
                BackgroundTransparency = 0.12, LayoutOrder = index, BorderSizePixel = 0
            }, scroll)
            corner(item, 7)
            make("TextLabel", {
                Size = UDim2.new(0, 95, 0, 25), Position = UDim2.fromOffset(9, 5),
                BackgroundTransparency = 1, Text = result.Code,
                TextColor3 = Color3.new(1,1,1), TextSize = 18,
                Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left
            }, item)
            make("TextLabel", {
                Size = UDim2.new(1, -112, 0, 35), Position = UDim2.fromOffset(104, 4),
                BackgroundTransparency = 1, Text = result.Path,
                TextColor3 = Color3.fromRGB(190, 200, 215), TextSize = 9,
                Font = Enum.Font.Gotham, TextTruncate = Enum.TextTruncate.AtEnd,
                TextXAlignment = Enum.TextXAlignment.Left
            }, item)
            local copy = make("TextButton", {
                Size = UDim2.fromOffset(68, 22), Position = UDim2.new(1, -77, 1, -27),
                BackgroundColor3 = Color3.fromRGB(85, 105, 150), Text = "COPY",
                TextColor3 = Color3.new(1,1,1), TextSize = 9, Font = Enum.Font.GothamBold,
                BorderSizePixel = 0
            }, item)
            corner(copy, 5)
            copy.MouseButton1Click:Connect(function()
                if type(setclipboard) == "function" then
                    local ok = pcall(setclipboard, result.Code)
                    copy.Text = ok and "COPIED" or "UNAVAILABLE"
                else
                    copy.Text = "NO CLIPBOARD"
                end
                task.delay(1.1, function()
                    if copy.Parent then copy.Text = "COPY" end
                end)
            end)
        end
    end

    local dragging, dragStart, startPos, activeInput = false, nil, nil, nil
    local dragAction = "TryoCodeFinderDrag_" .. tostring(LocalPlayer.UserId)
    local function sinkDragInput()
        return Enum.ContextActionResult.Sink
    end
    local function stopDragging()
        dragging = false
        activeInput = nil
        ContextActionService:UnbindAction(dragAction)
    end
    title.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos, activeInput = true, input.Position, frame.Position, input
            ContextActionService:BindActionAtPriority(
                dragAction, sinkDragInput, false, 3000,
                Enum.UserInputType.MouseButton1, Enum.UserInputType.Touch
            )
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then stopDragging() end
            end)
        end
    end)
    local connection = UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        local mouseMove = activeInput and activeInput.UserInputType == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseMovement
        if input ~= activeInput and not mouseMove then return end
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end)
    gui.Destroying:Connect(function()
        stopDragging()
        connection:Disconnect()
    end)
    return gui
end

Feature.Name = "Code Finder"
Feature.Description = "Mencari kandidat kode puzzle dari data map yang terlihat oleh client."
Feature.Start = function()
    if activeGui and activeGui.Parent then activeGui:Destroy() end
    notify("Code Finder", "Memindai data map dan replicated client...")
    local results, scanned = scan()
    activeGui = buildGui(results, scanned)
    if not activeGui then
        notify("Code Finder", "PlayerGui belum tersedia.")
        return false
    end
    notify("Code Finder", "Scan selesai: " .. #results .. " kandidat.")
    return true
end
Feature.Stop = function()
    if activeGui then activeGui:Destroy(); activeGui = nil end
end

return Feature
