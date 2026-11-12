-- Tryo Plugin Manager - Standalone Developer Panel
-- This launcher only loads the Developer UI from the developer branch.
-- Public plugins, tools and Loader are read from branch main by the panel.

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    warn("[Tryo Developer] LocalPlayer belum tersedia.")
    return
end

local BASE_URL = "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/developer/"
local WINDOW_URL = BASE_URL .. "MasterWindow.lua"

local ok, result = pcall(function()
    local source = game:HttpGet(WINDOW_URL .. "?_=" .. tostring(DateTime.now().UnixTimestampMillis))
    if type(source) ~= "string" or source == "" then
        error("MasterWindow.lua kosong atau gagal diunduh.")
    end
    local chunk, compileError = loadstring(source, "TryoDeveloper/MasterWindow.lua")
    if type(chunk) ~= "function" then
        error("Gagal compile Developer MasterWindow: " .. tostring(compileError))
    end
    local startPanel = chunk()
    if type(startPanel) ~= "function" then
        error("Developer MasterWindow tidak mengembalikan function.")
    end
    startPanel()
end)

if not ok then
    warn("[Tryo Developer] Gagal membuka panel: " .. tostring(result))
end
