-- Standalone Smart Rejoin for Tryo Plugin Manager beta2.
-- Retries failed teleports with a strict attempt limit and cooldown.
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer

local Feature = {}
Feature.Name = "Smart Rejoin"
Feature.Description = "Retry teleport gagal secara terbatas; fallback ke server saat ini bila tujuan dibatasi."

local MAX_RETRIES = 2
local RETRY_DELAY = 2
local EVENT_COOLDOWN = 5

local active = false
local retryCount = 0
local lastEventAt = 0
local generation = 0
local connections = {}

local function notify(title, message)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = title,
            Text = message,
            Duration = 5
        })
    end)
end

local function isRestricted(result, message)
    local resultText = string.lower(tostring(result or ""))
    local messageText = string.lower(tostring(message or ""))
    return resultText:find("unauthorized", 1, true) ~= nil
        or resultText:find("is teleport with code allowed", 1, true) ~= nil
        or messageText:find("restricted", 1, true) ~= nil
        or messageText:find("773", 1, true) ~= nil
end

local function attemptRetry(targetPlaceId, result, message)
    if not active then return end

    local now = os.clock()
    if now - lastEventAt < EVENT_COOLDOWN then return end
    lastEventAt = now

    if retryCount >= MAX_RETRIES then
        notify("Smart Rejoin", "Batas retry tercapai (" .. MAX_RETRIES .. "). Tidak mencoba lagi.")
        return
    end

    local restricted = isRestricted(result, message)
    local destination = tonumber(targetPlaceId)
    if restricted or not destination or destination <= 0 or destination ~= game.PlaceId then
        destination = game.PlaceId
    end

    retryCount += 1
    local thisGeneration = generation
    local attempt = retryCount
    local destinationName = destination == game.PlaceId and "map saat ini" or "map tujuan"

    notify("Smart Rejoin", "Teleport gagal. Retry " .. attempt .. "/" .. MAX_RETRIES .. " ke " .. destinationName .. "...")
    task.delay(RETRY_DELAY, function()
        if not active or generation ~= thisGeneration then return end
        local ok, err = pcall(function()
            TeleportService:Teleport(destination, LocalPlayer)
        end)
        if not ok then
            notify("Smart Rejoin", "Retry gagal dimulai: " .. tostring(err))
        end
    end)
end

function Feature.Start()
    if active then return true end
    active = true
    retryCount = 0
    lastEventAt = 0
    generation += 1

    local ok, connection = pcall(function()
        return TeleportService.TeleportFailed:Connect(function(player, result, message, targetPlaceId)
            if player == LocalPlayer then
                attemptRetry(targetPlaceId, result, message)
            end
        end)
    end)
    if ok and connection then table.insert(connections, connection) end

    local initOk, initConnection = pcall(function()
        return TeleportService.TeleportInitFailed:Connect(function(player, result, message, targetPlaceId)
            if player == LocalPlayer then
                attemptRetry(targetPlaceId, result, message)
            end
        end)
    end)
    if initOk and initConnection then table.insert(connections, initConnection) end

    notify("Smart Rejoin", "Aktif. Maksimal " .. MAX_RETRIES .. " percobaan ulang per sesi.")
    return true
end

function Feature.Stop()
    active = false
    generation += 1
    for _, connection in ipairs(connections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(connections)
    retryCount = 0
    lastEventAt = 0
    notify("Smart Rejoin", "Dinonaktifkan.")
end

return Feature
