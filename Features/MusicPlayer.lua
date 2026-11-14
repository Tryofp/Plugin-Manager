-- Standalone Play Music migration from beta Plugin/MusicTimeML.
-- Owns only sounds created by this feature; it never destroys map/game audio.
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

local Feature = {
    Name = "Play Music",
    Description = "Memutar audio Roblox berdasarkan Asset ID."
}
local gui
local currentSound
local function notify(message)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Play Music", Text = message, Duration = 3
        })
    end)
end
local function stopCurrent()
    if currentSound then
        pcall(function() currentSound:Stop(); currentSound:Destroy() end)
        currentSound = nil
    end
end
local function play(id, pitch, volume)
    id = tostring(id or ""):gsub("%s+", "")
    if id == "" then id = "6729922069" end
    if not id:match("^%d+$") then
        notify("Asset ID harus berupa angka.")
        return false
    end
    stopCurrent()
    local sound = Instance.new("Sound")
    sound.Name = "TryoBeta2Music"
    sound.SoundId = "rbxassetid://" .. id
    sound.PlaybackSpeed = math.clamp(tonumber(pitch) or 1, 0.25, 3)
    sound.Volume = math.clamp(tonumber(volume) or 1, 0, 10)
    sound.Parent = workspace
    currentSound = sound
    local ended
    ended = sound.Ended:Connect(function()
        if currentSound == sound then currentSound = nil end
        if ended then ended:Disconnect() end
        pcall(function() sound:Destroy() end)
    end)
    local ok, err = pcall(function() sound:Play() end)
    if not ok then
        stopCurrent()
        notify("Gagal memutar audio: " .. tostring(err))
        return false
    end
    notify("Memutar Asset ID " .. id)
    return true
end
local function make(class, props, parent)
    local object = Instance.new(class)
    for key, value in pairs(props) do object[key] = value end
    object.Parent = parent
    return object
end
function Feature.Start()
    if gui and gui.Parent then gui.Enabled = true; return true end
    gui = Instance.new("ScreenGui")
    gui.Name = "TryoBeta2MusicPlayer"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    local parentOk = pcall(function() gui.Parent = CoreGui end)
    if not parentOk then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
    local panel = make("Frame", {
        Size = UDim2.fromOffset(270, 190), Position = UDim2.new(0.5, -135, 0.5, -95),
        BackgroundColor3 = Color3.fromRGB(39, 55, 79), BackgroundTransparency = 0.12,
        BorderSizePixel = 0, Active = true
    }, gui)
    make("UICorner", {CornerRadius = UDim.new(0, 10)}, panel)
    make("UIStroke", {Color = Color3.fromRGB(105, 160, 205), Transparency = 0.35}, panel)
    local title = make("TextLabel", {
        Size = UDim2.new(1, -40, 0, 32), Position = UDim2.fromOffset(10, 0),
        BackgroundTransparency = 1, Font = Enum.Font.GothamBold, Text = "PLAY MUSIC",
        TextColor3 = Color3.new(1,1,1), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left
    }, panel)
    local close = make("TextButton", {
        Size = UDim2.fromOffset(25, 24), Position = UDim2.new(1, -30, 0, 4),
        BackgroundColor3 = Color3.fromRGB(160, 65, 80), Text = "×",
        TextColor3 = Color3.new(1,1,1), Font = Enum.Font.GothamBold, TextSize = 16
    }, panel)
    make("UICorner", {CornerRadius = UDim.new(0, 6)}, close)
    close.MouseButton1Click:Connect(function() gui.Enabled = false end)
    local idBox = make("TextBox", {
        Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 40),
        BackgroundColor3 = Color3.fromRGB(20, 32, 49), Text = "6729922069",
        PlaceholderText = "Roblox Audio Asset ID", TextColor3 = Color3.new(1,1,1),
        Font = Enum.Font.Gotham, TextSize = 12, ClearTextOnFocus = false
    }, panel)
    make("UICorner", {CornerRadius = UDim.new(0, 6)}, idBox)
    local pitchBox = make("TextBox", {
        Size = UDim2.new(0.48, -12, 0, 28), Position = UDim2.fromOffset(10, 78),
        BackgroundColor3 = Color3.fromRGB(20, 32, 49), Text = "1", PlaceholderText = "Pitch",
        TextColor3 = Color3.new(1,1,1), Font = Enum.Font.Gotham, TextSize = 11, ClearTextOnFocus = false
    }, panel)
    make("UICorner", {CornerRadius = UDim.new(0, 6)}, pitchBox)
    local volumeBox = make("TextBox", {
        Size = UDim2.new(0.48, -12, 0, 28), Position = UDim2.new(0.52, 2, 0, 78),
        BackgroundColor3 = Color3.fromRGB(20, 32, 49), Text = "1", PlaceholderText = "Volume",
        TextColor3 = Color3.new(1,1,1), Font = Enum.Font.Gotham, TextSize = 11, ClearTextOnFocus = false
    }, panel)
    make("UICorner", {CornerRadius = UDim.new(0, 6)}, volumeBox)
    local playBtn = make("TextButton", {
        Size = UDim2.new(0.48, -12, 0, 32), Position = UDim2.fromOffset(10, 118),
        BackgroundColor3 = Color3.fromRGB(20, 145, 100), Text = "PLAY",
        TextColor3 = Color3.new(1,1,1), Font = Enum.Font.GothamBold, TextSize = 12
    }, panel)
    make("UICorner", {CornerRadius = UDim.new(0, 6)}, playBtn)
    local stopBtn = make("TextButton", {
        Size = UDim2.new(0.48, -12, 0, 32), Position = UDim2.new(0.52, 2, 0, 118),
        BackgroundColor3 = Color3.fromRGB(160, 65, 80), Text = "STOP",
        TextColor3 = Color3.new(1,1,1), Font = Enum.Font.GothamBold, TextSize = 12
    }, panel)
    make("UICorner", {CornerRadius = UDim.new(0, 6)}, stopBtn)
    local hint = make("TextLabel", {
        Size = UDim2.new(1, -20, 0, 22), Position = UDim2.fromOffset(10, 158),
        BackgroundTransparency = 1, Text = "Audio playback may be restricted by Roblox.",
        TextColor3 = Color3.fromRGB(190, 204, 220), Font = Enum.Font.Gotham, TextSize = 9
    }, panel)
    playBtn.MouseButton1Click:Connect(function() play(idBox.Text, pitchBox.Text, volumeBox.Text) end)
    stopBtn.MouseButton1Click:Connect(function() stopCurrent(); notify("Audio dihentikan.") end)
    return true
end
function Feature.Stop()
    stopCurrent()
    if gui then pcall(function() gui:Destroy() end); gui = nil end
    return true
end
return Feature
