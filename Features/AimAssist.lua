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

return AimAssist
