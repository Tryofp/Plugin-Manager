-- Standalone camera utilities migrated from beta.
-- No Infinite Yield dependency.
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local Features = {}

local function notify(message)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "Camera Tools",
            Text = message,
            Duration = 4
        })
    end)
end

local F1Lock = { Name = "F1 Shift Lock" }
local f1OriginalValue
local f1BoundKeys
local f1CreatedValue = false
local f1Active = false

local function findBoundKeys()
    local playerScripts = LocalPlayer:FindFirstChild("PlayerScripts") or LocalPlayer:WaitForChild("PlayerScripts", 5)
    if not playerScripts then return nil end
    local playerModule = playerScripts:FindFirstChild("PlayerModule")
    local cameraModule = playerModule and playerModule:FindFirstChild("CameraModule")
    local mouseLockController = cameraModule and cameraModule:FindFirstChild("MouseLockController")
    return mouseLockController and mouseLockController:FindFirstChild("BoundKeys"), mouseLockController
end

function F1Lock.Start()
    if f1Active then return true end
    f1Active = true
    pcall(function()
        StarterGui:SetCore("EnableMouseLockOption", true)
    end)

    local controller
    f1BoundKeys, controller = findBoundKeys()
    if f1BoundKeys then
        f1OriginalValue = f1BoundKeys.Value
        f1BoundKeys.Value = "F1"
    elseif controller then
        local value = Instance.new("StringValue")
        value.Name = "BoundKeys"
        value.Value = "F1"
        value.Parent = controller
        f1BoundKeys = value
        f1CreatedValue = true
    end

    notify(f1BoundKeys and "Shift Lock di-bind ke tombol F1." or "Opsi Shift Lock diaktifkan; controller kamera belum ditemukan.")
    return true
end

function F1Lock.Stop()
    f1Active = false
    if f1BoundKeys then
        pcall(function()
            if f1CreatedValue then
                f1BoundKeys:Destroy()
            elseif f1OriginalValue ~= nil then
                f1BoundKeys.Value = f1OriginalValue
            end
        end)
    end
    f1BoundKeys, f1OriginalValue, f1CreatedValue = nil, nil, false
    notify("F1 Shift Lock dinonaktifkan.")
    return true
end

local UnlockCamera = { Name = "Force Unlock Camera" }
local unlockActive = false
local unlockConnection
local originalCameraMode
local originalCameraType

function UnlockCamera.Start()
    if unlockActive then return true end
    unlockActive = true
    originalCameraMode = LocalPlayer.CameraMode
    local camera = workspace.CurrentCamera
    originalCameraType = camera and camera.CameraType

    pcall(function()
        LocalPlayer.CameraMode = Enum.CameraMode.Classic
    end)

    unlockConnection = RunService.RenderStepped:Connect(function()
        if not unlockActive then return end
        pcall(function()
            LocalPlayer.CameraMode = Enum.CameraMode.Classic
            local currentCamera = workspace.CurrentCamera
            if currentCamera and currentCamera.CameraType ~= Enum.CameraType.Custom then
                currentCamera.CameraType = Enum.CameraType.Custom
            end
        end)
    end)

    notify("Force Unlock Camera aktif. Matikan toggle untuk memulihkan pengaturan kamera.")
    return true
end

function UnlockCamera.Stop()
    unlockActive = false
    if unlockConnection then
        unlockConnection:Disconnect()
        unlockConnection = nil
    end
    pcall(function()
        if originalCameraMode then LocalPlayer.CameraMode = originalCameraMode end
        local camera = workspace.CurrentCamera
        if camera and originalCameraType then camera.CameraType = originalCameraType end
    end)
    originalCameraMode, originalCameraType = nil, nil
    notify("Force Unlock Camera dihentikan.")
    return true
end

Features.F1Lock = F1Lock
Features.ForceUnlockCamera = UnlockCamera
return Features
