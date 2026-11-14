-- Standalone Aim Assist migrated from beta SimpleAimbot.
-- Client-side camera assistance; no Infinite Yield dependency.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local AimAssist = {
    Name = "Aim Assist",
    Radius = 200,
    Smoothness = 0.18,
    Target = nil
}

local active = false
local renderConnection
local currentCamera

local function notify(message)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "Aim Assist",
            Text = message,
            Duration = 3
        })
    end)
end

local function isEnemy(player)
    if player == LocalPlayer then return false end
    if LocalPlayer.Team ~= nil and player.Team ~= nil then
        return LocalPlayer.Team ~= player.Team
    end
    return true
end

local function getTargetPart(player)
    local character = player.Character
    if not character then return nil end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return nil end
    return character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
end

local function hasLineOfSight(camera, targetPart, character)
    local origin = camera.CFrame.Position
    local direction = targetPart.Position - origin
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LocalPlayer.Character, camera}
    params.IgnoreWater = true
    local result = Workspace:Raycast(origin, direction, params)
    return result == nil or result.Instance:IsDescendantOf(character)
end

local function findNearestTarget(camera)
    local viewport = camera.ViewportSize
    local center = Vector2.new(viewport.X * 0.5, viewport.Y * 0.5)
    local bestPlayer, bestPart, bestDistance = nil, nil, math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if isEnemy(player) then
            local part = getTargetPart(player)
            if part then
                local screen, onScreen = camera:WorldToViewportPoint(part.Position)
                if onScreen and screen.Z > 0 then
                    local distance = (Vector2.new(screen.X, screen.Y) - center).Magnitude
                    if distance <= AimAssist.Radius and distance < bestDistance then
                        local character = player.Character
                        if character and hasLineOfSight(camera, part, character) then
                            bestPlayer, bestPart, bestDistance = player, part, distance
                        end
                    end
                end
            end
        end
    end

    return bestPlayer, bestPart
end

function AimAssist.Start()
    if active then return true end
    active = true
    currentCamera = Workspace.CurrentCamera

    renderConnection = RunService.RenderStepped:Connect(function()
        if not active then return end
        local camera = Workspace.CurrentCamera
        if not camera then return end
        currentCamera = camera

        local targetPlayer, targetPart = findNearestTarget(camera)
        AimAssist.Target = targetPlayer

        if targetPart then
            local desired = CFrame.lookAt(camera.CFrame.Position, targetPart.Position)
            local alpha = math.clamp(tonumber(AimAssist.Smoothness) or 0.18, 0.03, 1)
            camera.CFrame = camera.CFrame:Lerp(desired, alpha)
        end
    end)

    notify("Aktif. Arahkan crosshair ke target dalam radius.")
    return true
end

function AimAssist.Stop()
    active = false
    AimAssist.Target = nil
    if renderConnection then
        renderConnection:Disconnect()
        renderConnection = nil
    end
    notify("Dinonaktifkan.")
    return true
end

function AimAssist.SetRadius(value)
    AimAssist.Radius = math.clamp(tonumber(value) or 200, 25, 800)
end

function AimAssist.SetSmoothness(value)
    AimAssist.Smoothness = math.clamp(tonumber(value) or 0.18, 0.03, 1)
end

local settingsGui
function AimAssist.OpenSettings()
    if settingsGui and settingsGui.Parent then
        settingsGui.Enabled = true
        return true
    end
    local gui = Instance.new("ScreenGui")
    gui.Name = "TryoAimAssistSettings"
    gui.ResetOnSpawn = false
    local parentOk = pcall(function() gui.Parent = game:GetService("CoreGui") end)
    if not parentOk then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
    settingsGui = gui

    local panel = Instance.new("Frame")
    panel.Size = UDim2.fromOffset(230, 112)
    panel.Position = UDim2.new(0.5, -115, 0.5, -56)
    panel.BackgroundColor3 = Color3.fromRGB(38, 54, 78)
    panel.BackgroundTransparency = 0.12
    panel.BorderSizePixel = 0
    panel.Parent = gui
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 9)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -36, 0, 28)
    title.Position = UDim2.fromOffset(9, 0)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.Text = "AIM ASSIST SETTINGS"
    title.TextColor3 = Color3.new(1, 1, 1)
    title.TextSize = 11
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = panel

    local close = Instance.new("TextButton")
    close.Size = UDim2.fromOffset(23, 22)
    close.Position = UDim2.new(1, -27, 0, 3)
    close.Text = "×"
    close.Font = Enum.Font.GothamBold
    close.TextSize = 15
    close.TextColor3 = Color3.new(1, 1, 1)
    close.BackgroundColor3 = Color3.fromRGB(150, 65, 80)
    close.Parent = panel
    close.MouseButton1Click:Connect(function() gui.Enabled = false end)

    local radiusBox = Instance.new("TextBox")
    radiusBox.Size = UDim2.new(1, -18, 0, 28)
    radiusBox.Position = UDim2.fromOffset(9, 36)
    radiusBox.BackgroundColor3 = Color3.fromRGB(20, 32, 49)
    radiusBox.TextColor3 = Color3.new(1, 1, 1)
    radiusBox.PlaceholderText = "Radius 25 - 800"
    radiusBox.Text = tostring(AimAssist.Radius)
    radiusBox.ClearTextOnFocus = false
    radiusBox.Font = Enum.Font.Gotham
    radiusBox.TextSize = 11
    radiusBox.Parent = panel

    local apply = Instance.new("TextButton")
    apply.Size = UDim2.new(1, -18, 0, 27)
    apply.Position = UDim2.fromOffset(9, 74)
    apply.BackgroundColor3 = Color3.fromRGB(25, 140, 100)
    apply.Text = "APPLY"
    apply.TextColor3 = Color3.new(1, 1, 1)
    apply.Font = Enum.Font.GothamBold
    apply.TextSize = 11
    apply.Parent = panel
    apply.MouseButton1Click:Connect(function()
        local number = tonumber(radiusBox.Text)
        if not number then
            notify("Masukkan radius berupa angka.")
            return
        end
        AimAssist.SetRadius(number)
        radiusBox.Text = tostring(AimAssist.Radius)
        notify("Radius diperbarui: " .. tostring(AimAssist.Radius))
    end)
    return true
end

return AimAssist
