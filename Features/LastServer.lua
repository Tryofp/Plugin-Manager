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

function Feature.SaveCurrent()
    if game.JobId == nil or game.JobId == "" then
        notify("Last Server", "JobId kosong; server ini tidak bisa disimpan.")
        return false
    end
    local data = {
        PlaceId = game.PlaceId,
        JobId = game.JobId,
        PlaceName = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name,
        SavedAt = os.time()
    }
    persist(data)
    notify("Last Server", "Server saat ini berhasil disimpan.")
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
        local ok, info = pcall(function()
            return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
        end)
        persist({
            PlaceId = game.PlaceId,
            JobId = game.JobId,
            PlaceName = ok and info and info.Name or tostring(game.PlaceId),
            SavedAt = os.time()
        })
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
