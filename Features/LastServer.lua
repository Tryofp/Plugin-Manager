-- Standalone Last Server utility for beta2.
-- Saves the current PlaceId/JobId locally and rejoins only on explicit user action.
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

local Feature = {}
Feature.Name = "Last Server"
Feature.Description = "Simpan server saat ini dan kembali ke server tersebut."

local FILE_NAME = "TryoLastServer.json"
local saved = nil
local autoSaveConnection = nil
local failureConnection = nil

local function notify(title, message)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = title, Text = message, Duration = 4
        })
    end)
end

local function loadSaved()
    if saved then return saved end
    if type(readfile) == "function" and type(isfile) == "function" then
        pcall(function()
            if isfile(FILE_NAME) then
                local decoded = HttpService:JSONDecode(readfile(FILE_NAME))
                if type(decoded) == "table" and tonumber(decoded.PlaceId) and type(decoded.JobId) == "string" then
                    saved = decoded
                end
            end
        end)
    end
    if not saved and type(_G.TryoLastServer) == "table" then
        saved = _G.TryoLastServer
    end
    return saved
end

local function persist(data)
    saved = data
    _G.TryoLastServer = data
    if type(writefile) == "function" then
        pcall(function()
            writefile(FILE_NAME, HttpService:JSONEncode(data))
        end)
    end
end

-- Save only a code explicitly shared with this client through teleport data.
local function findAccessCode(value, depth)
    if type(value) ~= "table" or depth > 4 then return nil end
    for key, item in pairs(value) do
        if type(key) == "string" then
            local normalized = string.lower(key):gsub("[^%w]", "")
            if (normalized == "reservedserveraccesscode" or normalized == "reservedservercode"
                or normalized == "privateserveraccesscode" or normalized == "privateservercode")
                and type(item) == "string" and item ~= "" then
                return item
            end
        end
        if type(item) == "table" then
            local nested = findAccessCode(item, depth + 1)
            if nested then return nested end
        end
    end
    return nil
end

local function getSessionAccessCode()
    local ok, teleportData = pcall(function()
        return TeleportService:GetLocalPlayerTeleportData()
    end)
    if not ok then return nil end
    return findAccessCode(teleportData, 0)
end

local function buildCurrentServerData()
    local infoOk, info = pcall(function()
        return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
    end)
    local privateServerId = tostring(game.PrivateServerId or "")
    local privateServerOwnerId = tonumber(game.PrivateServerOwnerId) or 0
    local serverType = "Public"
    if privateServerId ~= "" then
        serverType = privateServerOwnerId == 0 and "Reserved" or "Private"
    end
    return {
        PlaceId = game.PlaceId,
        JobId = game.JobId,
        PlaceName = infoOk and info and info.Name or tostring(game.PlaceId),
        SavedAt = os.time(),
        PrivateServerId = privateServerId,
        PrivateServerOwnerId = privateServerOwnerId,
        ServerType = serverType,
        AccessCode = getSessionAccessCode()
    }
end

function Feature.SaveCurrent()
    if game.JobId == nil or game.JobId == "" then
        notify("Last Server", "JobId kosong; server ini tidak bisa disimpan.")
        return false
    end
    local data = buildCurrentServerData()
    persist(data)
    if data.ServerType == "Reserved" and data.AccessCode then
        notify("Last Server", "Reserved Server tersimpan. Access code tersedia dan ikut disimpan.")
    elseif data.ServerType == "Reserved" then
        notify("Last Server", "Reserved Server tersimpan, tetapi game tidak memberikan access code ke client.")
    else
        notify("Last Server", "Server saat ini berhasil disimpan.")
    end
    return true
end

function Feature.RejoinSaved()
    local data = loadSaved()
    if not data or not tonumber(data.PlaceId) or type(data.JobId) ~= "string" or data.JobId == "" then
        notify("Last Server", "Belum ada server tersimpan. Simpan server terlebih dahulu.")
        return false
    end
    if data.PlaceId == game.PlaceId and data.JobId == game.JobId then
        notify("Last Server", "Kamu sudah berada di server tersimpan.")
        return false
    end
    if data.ServerType == "Reserved" then
        if data.AccessCode then
            notify("Last Server", "Access code tersimpan. Rejoin Reserved Server tetap memerlukan teleport dari server game; client tidak bisa memakai kode ini langsung.")
        else
            notify("Last Server", "Reserved Server tersimpan tanpa access code. Game tidak membagikan kode ke client.")
        end
        return false
    end
    notify("Last Server", "Mencoba kembali ke server tersimpan...")
    local ok, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(tonumber(data.PlaceId), data.JobId, LocalPlayer)
    end)
    if not ok then
        notify("Last Server", "Teleport gagal: " .. tostring(err))
        return false
    end
    return true
end

function Feature.GetSaved()
    return loadSaved()
end

Feature.Start = function()
    if autoSaveConnection then return true end
    -- Keep the latest server available after respawn/session start; no teleport is triggered.
    if game.JobId ~= "" then
        persist(buildCurrentServerData())
    end
    failureConnection = TeleportService.TeleportFailed:Connect(function(player, result, message)
        if player == LocalPlayer then
            notify("Last Server", "Teleport tidak berhasil: " .. tostring(message or result))
        end
    end)
    return true
end

Feature.Stop = function()
    if autoSaveConnection then autoSaveConnection:Disconnect(); autoSaveConnection = nil end
    if failureConnection then failureConnection:Disconnect(); failureConnection = nil end
end

return Feature
