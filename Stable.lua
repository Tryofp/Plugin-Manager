-- Plugin Manager - Stable Infinite Yield Plugin
-- This file is designed to be loaded by Infinite Yield's plugin system.

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local BASE_URL = "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/main/"
local MASTER_WINDOW_URL = BASE_URL .. "MasterWindow.lua"
local LOADER_URL = BASE_URL .. "Loader.lua"
local STORAGE_FILE = "MasterPluginHub_NewTracker.json"

local function fetchAndRun(url, chunkName)
    local source = game:HttpGet(url)
    if type(source) ~= "string" or source == "" then
        error("File kosong atau gagal diunduh: " .. tostring(url))
    end

    local compiled, compileError = loadstring(source, chunkName)
    if type(compiled) ~= "function" then
        error("Gagal compile " .. tostring(chunkName) .. ": " .. tostring(compileError))
    end

    return compiled()
end

local function backgroundSyncTimestamps()
    task.spawn(function()
        pcall(function()
            local data = fetchAndRun(LOADER_URL, "PluginManager/Loader.lua")
            if type(data) ~= "table" then
                error("Loader.lua tidak mengembalikan table")
            end

            local userSeenTimestamps = {}

            if type(readfile) == "function"
                and type(isfile) == "function"
                and isfile(STORAGE_FILE) then

                local readOk, decoded = pcall(function()
                    return HttpService:JSONDecode(readfile(STORAGE_FILE))
                end)

                if readOk and type(decoded) == "table" then
                    userSeenTimestamps = decoded
                end
            end

            local function checkAndSave(rawUrl, customTs)
                if type(rawUrl) ~= "string" or rawUrl == "" or customTs == nil then
                    return
                end

                local uniqueKey = rawUrl .. "_" .. tostring(customTs)
                if not userSeenTimestamps[uniqueKey] then
                    userSeenTimestamps[uniqueKey] = {
                        ScriptTime = tostring(customTs),
                        FirstSeen = os.time()
                    }
                end
            end

            for _, catList in pairs(data) do
                if type(catList) == "table" then
                    for _, item in ipairs(catList) do
                        if type(item) == "table" then
                            if type(item.SubFeatures) == "table" then
                                for _, sub in ipairs(item.SubFeatures) do
                                    if type(sub) == "table" and sub.UpdateTimestamp then
                                        local targetRaw =
                                            (type(sub.RawUrl) == "string" and sub.RawUrl ~= "")
                                            and sub.RawUrl
                                            or item.RawUrl

                                        checkAndSave(targetRaw, sub.UpdateTimestamp)
                                    end
                                end
                            end

                            if item.UpdateTimestamp then
                                checkAndSave(item.RawUrl, item.UpdateTimestamp)
                            end
                        end
                    end
                end
            end

            if type(writefile) == "function" then
                writefile(STORAGE_FILE, HttpService:JSONEncode(userSeenTimestamps))
            end
        end)
    end)
end

local Plugin = {
    ["PluginName"] = "Plugin Manager Stable",
    ["PluginDescription"] = "Membuka Plugin Manager Hub dari branch stable.",
    ["Commands"] = {
        ["hub"] = {
            ["ListName"] = "hub / masterhub",
            ["Description"] = "Membuka jendela utama Plugin Manager Hub versi stable",
            ["Aliases"] = {"masterhub"},
            ["Function"] = function(args, speaker)
                local targetPlayer = speaker or Players.LocalPlayer
                if not targetPlayer then
                    warn("[Plugin Manager] LocalPlayer belum tersedia.")
                    return
                end

                backgroundSyncTimestamps()

                local success, err = pcall(function()
                    local runWindow = fetchAndRun(
                        MASTER_WINDOW_URL,
                        "PluginManager/MasterWindow.lua"
                    )

                    if type(runWindow) ~= "function" then
                        error("MasterWindow.lua tidak mengembalikan function.")
                    end

                    runWindow(targetPlayer)
                end)

                if not success then
                    warn("[Plugin Manager] Gagal membuka Hub: " .. tostring(err))
                end
            end
        }
    }
}

return Plugin
