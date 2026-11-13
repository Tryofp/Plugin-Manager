-- Native standalone Anti-Disturb Shield. All changes are client-side and reversible.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer

local Features = {}

local function notify(title, message)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = title,
            Text = message,
            Duration = 4
        })
    end)
end

local function getRoot()
    local character = LocalPlayer.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function isPlayerCharacter(part)
    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        if character and part:IsDescendantOf(character) then
            return true
        end
    end
    return false
end

local function withinRadius(position, origin, radius)
    return (position - origin).Magnitude <= radius
end

local anchorOriginals = {}
Features.AnchorNearby = {
    Name = "Anchor Nearby",
    Description = "Mengunci part tidak anchored dalam radius 100 studs; kondisi awal dipulihkan saat dimatikan.",
    Start = function()
        local root = getRoot()
        if not root then notify("Anchor", "Karakter belum siap."); return false end
        local count = 0
        for _, object in ipairs(Workspace:GetDescendants()) do
            if object:IsA("BasePart") and not object.Anchored
                and not isPlayerCharacter(object)
                and withinRadius(object.Position, root.Position, 100) then
                if anchorOriginals[object] == nil then
                    anchorOriginals[object] = {
                        Anchored = object.Anchored,
                        CanCollide = object.CanCollide,
                        Color = object.Color
                    }
                end
                pcall(function()
                    object.Anchored = true
                    object.CanCollide = true
                    object.Color = Color3.fromRGB(255, 230, 70)
                end)
                count += 1
            end
        end
        notify("Anchor", "Mengunci " .. count .. " part secara lokal.")
        return true
    end,
    Stop = function()
        local count = 0
        for part, original in pairs(anchorOriginals) do
            if part and part.Parent then
                pcall(function()
                    part.Anchored = original.Anchored
                    part.CanCollide = original.CanCollide
                    part.Color = original.Color
                end)
                count += 1
            end
        end
        table.clear(anchorOriginals)
        notify("Anchor", "Memulihkan " .. count .. " part.")
    end
}

local windOriginals = {}
Features.AntiWind = {
    Name = "Anti-Wind",
    Description = "Meredam force/velocity di sekitar pemain dalam radius 150 studs.",
    Start = function()
        local root = getRoot()
        if not root then notify("Anti-Wind", "Karakter belum siap."); return false end
        local count = 0
        for _, object in ipairs(Workspace:GetDescendants()) do
            local supported = object:IsA("BodyForce") or object:IsA("VectorForce")
                or object:IsA("LinearVelocity") or object:IsA("AngularVelocity")
            if supported then
                local parentPart = object:IsA("BasePart") and object
                    or (object.Parent and object.Parent:IsA("BasePart") and object.Parent)
                if parentPart and withinRadius(parentPart.Position, root.Position, 150) then
                    if windOriginals[object] == nil then
                        local saved = {}
                        if object:IsA("BodyForce") then
                            saved.Force = object.Force
                        else
                            saved.Enabled = object.Enabled
                        end
                        windOriginals[object] = saved
                    end
                    pcall(function()
                        if object:IsA("BodyForce") then
                            object.Force = Vector3.zero
                        else
                            object.Enabled = false
                        end
                    end)
                    count += 1
                end
            end
        end
        notify("Anti-Wind", "Meredam " .. count .. " force secara lokal.")
        return true
    end,
    Stop = function()
        local count = 0
        for object, original in pairs(windOriginals) do
            if object and object.Parent then
                pcall(function()
                    if object:IsA("BodyForce") then
                        object.Force = original.Force
                    else
                        object.Enabled = original.Enabled
                    end
                end)
                count += 1
            end
        end
        table.clear(windOriginals)
        notify("Anti-Wind", "Memulihkan " .. count .. " force.")
    end
}

local triggerOriginals = {}
Features.AntiTrigger = {
    Name = "Anti-Trigger",
    Description = "Menonaktifkan CanTouch pada part bernama trigger/shake/sensor dalam radius 150 studs.",
    Start = function()
        local root = getRoot()
        if not root then notify("Anti-Trigger", "Karakter belum siap."); return false end
        local count = 0
        for _, object in ipairs(Workspace:GetDescendants()) do
            if object:IsA("BasePart") then
                local name = string.lower(object.Name)
                local matched = string.find(name, "trigger", 1, true)
                    or string.find(name, "shake", 1, true)
                    or string.find(name, "sensor", 1, true)
                if matched and withinRadius(object.Position, root.Position, 150) then
                    if triggerOriginals[object] == nil then
                        triggerOriginals[object] = {
                            CanTouch = object.CanTouch,
                            Transparency = object.Transparency
                        }
                    end
                    pcall(function()
                        object.CanTouch = false
                        object.Transparency = 0.8
                    end)
                    count += 1
                end
            end
        end
        notify("Anti-Trigger", "Menonaktifkan " .. count .. " trigger secara lokal.")
        return true
    end,
    Stop = function()
        local count = 0
        for object, original in pairs(triggerOriginals) do
            if object and object.Parent then
                pcall(function()
                    object.CanTouch = original.CanTouch
                    object.Transparency = original.Transparency
                end)
                count += 1
            end
        end
        table.clear(triggerOriginals)
        notify("Anti-Trigger", "Memulihkan " .. count .. " trigger.")
    end
}

local shakeConnection
local shakeCamera
local originalFov
Features.AntiShake = {
    Name = "Anti-Shake",
    Description = "Menstabilkan FOV kamera ke 70; FOV awal dipulihkan saat dimatikan.",
    Start = function()
        if shakeConnection then return true end
        local camera = Workspace.CurrentCamera
        if not camera then notify("Anti-Shake", "Kamera belum siap."); return false end
        shakeCamera = camera
        originalFov = camera.FieldOfView
        shakeConnection = RunService.RenderStepped:Connect(function()
            local current = Workspace.CurrentCamera
            if current and current ~= shakeCamera then
                shakeCamera = current
                originalFov = current.FieldOfView
            end
            if current then current.FieldOfView = 70 end
        end)
        notify("Anti-Shake", "Stabilisasi kamera aktif.")
        return true
    end,
    Stop = function()
        if shakeConnection then shakeConnection:Disconnect(); shakeConnection = nil end
        if shakeCamera and shakeCamera.Parent and originalFov then
            pcall(function() shakeCamera.FieldOfView = originalFov end)
        end
        shakeCamera = nil
        originalFov = nil
        notify("Anti-Shake", "FOV kamera dipulihkan.")
    end
}

return Features
