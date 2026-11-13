-- Standalone Sound & View features. No Infinite Yield globals or command registry.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local Features = {}
local WHITELIST = {
    "checkpoint", "respawn", "cp", "pos", "pospemeriksaan",
    "oof", "gettingup", "music", "radio", "boombox", "jukebox",
    "song", "soundtrack", "bgm", "audio"
}

local function notify(title, message)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = title, Text = message, Duration = 3
        })
    end)
end

local function isWhitelisted(sound)
    local name = string.lower(sound.Name or "")
    for _, keyword in ipairs(WHITELIST) do
        if string.find(name, keyword, 1, true) then return true end
    end
    return false
end

local mutedOriginals = {}
local muteConnections = {}
local soundAddedConnections = {}
local muteEnabled = false

local function muteSound(sound)
    if not muteEnabled or not sound:IsA("Sound") or isWhitelisted(sound) then return end
    if mutedOriginals[sound] == nil then mutedOriginals[sound] = sound.Volume end
    sound.Volume = 0
    if not muteConnections[sound] then
        muteConnections[sound] = sound:GetPropertyChangedSignal("Volume"):Connect(function()
            if muteEnabled and sound.Parent and not isWhitelisted(sound) and sound.Volume ~= 0 then
                sound.Volume = 0
            end
        end)
    end
end

local function stopMute()
    muteEnabled = false
    for _, connection in pairs(soundAddedConnections) do connection:Disconnect() end
    table.clear(soundAddedConnections)
    for sound, volume in pairs(mutedOriginals) do
        if sound and sound.Parent then pcall(function() sound.Volume = volume end) end
    end
    for sound, connection in pairs(muteConnections) do
        connection:Disconnect()
        muteConnections[sound] = nil
    end
    table.clear(mutedOriginals)
end

Features.MuteMapSounds = {
    Name = "Mute Map Sounds",
    Description = "Membisukan efek suara map sambil mempertahankan suara checkpoint dan musik yang diizinkan.",
    Start = function()
        if muteEnabled then return true end
        muteEnabled = true
        for _, root in ipairs({Workspace, SoundService}) do
            for _, object in ipairs(root:GetDescendants()) do
                if object:IsA("Sound") then muteSound(object) end
            end
            table.insert(soundAddedConnections, root.DescendantAdded:Connect(function(object)
                if object:IsA("Sound") then task.defer(muteSound, object) end
            end))
        end
        notify("Mute Map Sounds", "Suara map dibisukan.")
        return true
    end,
    Stop = function()
        stopMute()
        notify("Mute Map Sounds", "Volume suara awal dipulihkan.")
    end
}

local spectate = {
    Enabled = false, Target = nil, Gui = nil, RenderConnection = nil,
    PlayerAdded = nil, PlayerRemoving = nil, CameraType = nil, CameraSubject = nil
}

local function otherPlayers()
    local list = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then table.insert(list, player) end
    end
    table.sort(list, function(a, b) return a.Name:lower() < b.Name:lower() end)
    return list
end

local function setSpectateTarget(player)
    if not player or player == LocalPlayer or not player.Character then return false end
    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end
    spectate.Target = player
    local camera = Workspace.CurrentCamera
    if camera then
        camera.CameraType = Enum.CameraType.Custom
        camera.CameraSubject = humanoid
    end
    if spectate.Gui then
        local targetLabel = spectate.Gui:FindFirstChild("TargetName", true)
        if targetLabel then targetLabel.Text = player.DisplayName .. "  (@" .. player.Name .. ")" end
    end
    pcall(function()
        local root = player.Character:FindFirstChild("HumanoidRootPart")
        if root then LocalPlayer:RequestStreamAroundAsync(root.Position, 2) end
    end)
    return true
end

local function cycleSpectate(direction)
    local list = otherPlayers()
    if #list == 0 then return end
    local index = 0
    for i, player in ipairs(list) do
        if player == spectate.Target then index = i break end
    end
    index = ((index - 1 + direction) % #list) + 1
    setSpectateTarget(list[index])
end

local function makeSpectateButton(parent, text, position, size, color, callback)
    local button = Instance.new("TextButton")
    button.Size = size
    button.Position = position
    button.BackgroundColor3 = color
    button.BackgroundTransparency = 0.18
    button.BorderSizePixel = 0
    button.Font = Enum.Font.GothamSemibold
    button.Text = text
    button.TextColor3 = Color3.fromRGB(240, 244, 255)
    button.TextSize = 12
    button.AutoButtonColor = true
    button.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 7)
    corner.Parent = button
    button.MouseButton1Click:Connect(callback)
    return button
end

local function buildSpectateGui()
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local parent = playerGui
    pcall(function() parent = game:GetService("CoreGui") end)
    if not parent then parent = playerGui end
    local old = parent:FindFirstChild("TryoSpectateOverlay")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "TryoSpectateOverlay"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 30
    gui.Parent = parent
    spectate.Gui = gui

    local panel = Instance.new("Frame")
    panel.Name = "Panel"
    -- Minimal HUD strip, not a floating window.
    panel.Size = UDim2.fromOffset(330, 68)
    panel.AnchorPoint = Vector2.new(0.5, 1)
    panel.Position = UDim2.new(0.5, 0, 1, -24)
    panel.BackgroundTransparency = 1
    panel.BorderSizePixel = 0
    panel.Parent = gui

    local target = Instance.new("TextLabel")
    target.Name = "TargetName"
    target.Size = UDim2.fromOffset(250, 24)
    target.Position = UDim2.fromOffset(40, 0)
    target.TextXAlignment = Enum.TextXAlignment.Center
    target.BackgroundTransparency = 1
    target.Font = Enum.Font.GothamBold
    target.Text = "Pilih player..."
    target.TextColor3 = Color3.fromRGB(240, 244, 255)
    target.TextSize = 12
    target.TextTruncate = Enum.TextTruncate.AtEnd
    target.Parent = panel

    -- Row 1: previous arrow, selected player, next arrow.
    makeSpectateButton(panel, "‹", UDim2.fromOffset(0, 0), UDim2.fromOffset(34, 25), Color3.fromRGB(42, 67, 92), function()
        cycleSpectate(-1)
    end)
    makeSpectateButton(panel, "›", UDim2.fromOffset(296, 0), UDim2.fromOffset(34, 25), Color3.fromRGB(42, 67, 92), function()
        cycleSpectate(1)
    end)

    -- Row 2: player list, teleport, exit.
    makeSpectateButton(panel, "PLAYER", UDim2.fromOffset(0, 34), UDim2.fromOffset(100, 27), Color3.fromRGB(39, 94, 87), function()
        local list = gui:FindFirstChild("PlayerList")
        if list then list.Visible = not list.Visible end
    end)
    makeSpectateButton(panel, "TELEPORT", UDim2.fromOffset(108, 34), UDim2.fromOffset(110, 27), Color3.fromRGB(106, 83, 42), function()
        local target = spectate.Target
        local targetRoot = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
        local character = LocalPlayer.Character
        local localRoot = character and character:FindFirstChild("HumanoidRootPart")
        if targetRoot and localRoot then
            character:PivotTo(targetRoot.CFrame + Vector3.new(0, 3, 0))
            notify("Spectate Player", "Dipindahkan ke dekat target.")
        else
            notify("Spectate Player", "Target atau karakter belum siap.")
        end
    end)
    makeSpectateButton(panel, "EXIT", UDim2.fromOffset(226, 34), UDim2.fromOffset(104, 27), Color3.fromRGB(115, 48, 58), function()
        if spectate.Enabled and spectate.StopCallback then spectate.StopCallback() end
    end)

    local list = Instance.new("ScrollingFrame")
    list.Name = "PlayerList"
    list.Size = UDim2.fromOffset(170, 190)
    list.AnchorPoint = Vector2.new(0, 1)
    list.Position = UDim2.new(0, 12, 1, -76)
    list.BackgroundColor3 = Color3.fromRGB(25, 35, 48)
    list.BackgroundTransparency = 0.12
    list.BorderSizePixel = 0
    list.ScrollBarThickness = 3
    list.Visible = false
    list.CanvasSize = UDim2.new()
    list.Parent = gui
    Instance.new("UICorner", list).CornerRadius = UDim.new(0, 8)
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 4)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = list
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        list.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 8)
    end)

    local function refreshList()
        for _, child in ipairs(list:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end
        for _, player in ipairs(otherPlayers()) do
            local button = Instance.new("TextButton")
            button.Size = UDim2.new(1, -8, 0, 29)
            button.BackgroundColor3 = player == spectate.Target and Color3.fromRGB(38, 112, 91) or Color3.fromRGB(43, 52, 68)
            button.BackgroundTransparency = 0.12
            button.BorderSizePixel = 0
            button.Font = Enum.Font.Gotham
            button.Text = player.DisplayName
            button.TextColor3 = Color3.fromRGB(240, 244, 255)
            button.TextSize = 11
            button.Parent = list
            Instance.new("UICorner", button).CornerRadius = UDim.new(0, 6)
            button.MouseButton1Click:Connect(function()
                setSpectateTarget(player)
                refreshList()
            end)
        end
    end
    spectate.RefreshList = refreshList
    refreshList()
    return gui
end

Features.Spectate = {
    Name = "Spectate Player",
    Description = "Lihat player lain, pilih target dari daftar, dan pindah antar-target.",
    Start = function(context)
        if spectate.Enabled then return true end
        local camera = Workspace.CurrentCamera
        if not camera then return false end
        spectate.CameraType = camera.CameraType
        spectate.CameraSubject = camera.CameraSubject
        spectate.Enabled = true
        local gui = buildSpectateGui()
        local list = otherPlayers()
        if #list > 0 then setSpectateTarget(list[1]) end
        spectate.StopCallback = function()
            if context and context.FeatureManager then
                context.FeatureManager:SetEnabled("Spectate", false)
            end
        end
        spectate.PlayerAdded = Players.PlayerAdded:Connect(function()
            if spectate.RefreshList then spectate.RefreshList() end
        end)
        spectate.PlayerRemoving = Players.PlayerRemoving:Connect(function(player)
            if player == spectate.Target then
                spectate.Target = nil
                cycleSpectate(1)
            end
            if spectate.RefreshList then spectate.RefreshList() end
        end)
        spectate.RenderConnection = RunService.RenderStepped:Connect(function()
            local target = spectate.Target
            local character = target and target.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local currentCamera = Workspace.CurrentCamera
            if currentCamera and humanoid and currentCamera.CameraSubject ~= humanoid then
                currentCamera.CameraType = Enum.CameraType.Custom
                currentCamera.CameraSubject = humanoid
            end
        end)
        if #list == 0 then notify("Spectate Player", "Belum ada player lain di server.") end
        return true
    end,
    Stop = function()
        spectate.Enabled = false
        if spectate.RenderConnection then spectate.RenderConnection:Disconnect(); spectate.RenderConnection = nil end
        if spectate.PlayerAdded then spectate.PlayerAdded:Disconnect(); spectate.PlayerAdded = nil end
        if spectate.PlayerRemoving then spectate.PlayerRemoving:Disconnect(); spectate.PlayerRemoving = nil end
        if spectate.Gui then spectate.Gui:Destroy(); spectate.Gui = nil end
        spectate.Target = nil
        local camera = Workspace.CurrentCamera
        if camera then
            camera.CameraType = spectate.CameraType or Enum.CameraType.Custom
            local subject = spectate.CameraSubject
            if subject and subject.Parent then camera.CameraSubject = subject
            else
                local character = LocalPlayer.Character
                local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                if humanoid then camera.CameraSubject = humanoid end
            end
        end
        notify("Spectate Player", "Mode spectate dihentikan.")
    end
}
return Features
