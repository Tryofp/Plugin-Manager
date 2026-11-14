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
local cameraChangedConnection
local originalCameraMode
local originalCameraTypes = {}

local function rememberCamera(camera)
    if camera and originalCameraTypes[camera] == nil then
        originalCameraTypes[camera] = camera.CameraType
    end
end

function UnlockCamera.Start()
    if unlockActive then return true end
    unlockActive = true
    originalCameraMode = LocalPlayer.CameraMode
    table.clear(originalCameraTypes)
    rememberCamera(workspace.CurrentCamera)

    pcall(function() LocalPlayer.CameraMode = Enum.CameraMode.Classic end)

    cameraChangedConnection = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        if unlockActive then rememberCamera(workspace.CurrentCamera) end
    end)
    unlockConnection = RunService.RenderStepped:Connect(function()
        if not unlockActive then return end
        pcall(function()
            LocalPlayer.CameraMode = Enum.CameraMode.Classic
            local currentCamera = workspace.CurrentCamera
            if currentCamera then
                rememberCamera(currentCamera)
                if currentCamera.CameraType ~= Enum.CameraType.Custom then
                    currentCamera.CameraType = Enum.CameraType.Custom
                end
            end
        end)
    end)

    notify("Force Unlock Camera aktif. Pergantian kamera ditangani; pengaturan asal dipulihkan saat OFF.")
    return true
end

function UnlockCamera.Stop()
    unlockActive = false
    if unlockConnection then unlockConnection:Disconnect(); unlockConnection = nil end
    if cameraChangedConnection then cameraChangedConnection:Disconnect(); cameraChangedConnection = nil end
    pcall(function()
        if originalCameraMode then LocalPlayer.CameraMode = originalCameraMode end
        for camera, cameraType in pairs(originalCameraTypes) do
            if camera and camera.Parent then camera.CameraType = cameraType end
        end
    end)
    originalCameraMode = nil
    table.clear(originalCameraTypes)
    notify("Force Unlock Camera dihentikan; pengaturan kamera dipulihkan.")
    return true
end

Features.F1Lock = F1Lock
Features.ForceUnlockCamera = UnlockCamera
return Features
