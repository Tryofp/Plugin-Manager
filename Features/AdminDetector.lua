-- Tryo Standalone Admin Detector
-- Conservative client-side signals only; no Infinite Yield dependencies.
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer
local Feature = {Name = "Admin Detector", Description = "Mendeteksi owner, group owner, role overhead, dan tool moderasi dengan filter ketat."}

local running = false
local connections = {}
local known = {}
local lastNotice = {}

local ROLE_WORDS = {
    "admin", "administrator", "moderator", "mod", "staff",
    "head admin", "super admin", "lead developer",
    "head developer", "senior developer", "game developer"
}
local EXCLUDED_TEXT = {
    "vip", "member", "pendaki", "summit", "checkpoint",
    "owner pass", "admin pass", "admin potion", "admin gamepass"
}
local MODERATION_TOOLS = {
    ["ban hammer"] = true, ["banhammer"] = true,
    ["admin panel"] = true, ["admin command"] = true,
    ["admin tool"] = true, ["admin wand"] = true,
    ["moderator wand"] = true, ["mod wand"] = true,
    ["kick tool"] = true, ["ban tool"] = true
}

local function notify(title, message, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title, Text = message, Duration = duration or 5
        })
    end)
end

local function normalize(text)
    text = string.lower(tostring(text or ""))
    text = text:gsub("[%[%]{}<>|]", " ")
    text = text:gsub("[%p]", " ")
    text = text:gsub("%s+", " ")
    return text:match("^%s*(.-)%s*$") or ""
end

local function hasRole(text, player)
    local raw = tostring(text or "")
    if raw == "" or #raw > 48 then return false end
    local value = normalize(raw)
    if value == "" then return false end
    for _, excluded in ipairs(EXCLUDED_TEXT) do
        if string.find(value, excluded, 1, true) then return false end
    end
    local playerName = normalize(player.Name)
    local displayName = normalize(player.DisplayName)
    if value == playerName or value == displayName then return false end
    for _, role in ipairs(ROLE_WORDS) do
        if value == role then return true, raw end
        if string.match(value, "^" .. role:gsub(" ", "%s+") .. "%s*[:%-]?$") then
            return true, raw
        end
    end
    return false
end

local function detectTool(player)
    local containers = {player:FindFirstChildOfClass("Backpack"), player.Character}
    for _, container in ipairs(containers) do
        if container then
            for _, item in ipairs(container:GetChildren()) do
                if item:IsA("Tool") then
                    local name = normalize(item.Name)
                    if MODERATION_TOOLS[name] then
                        return "Stealth Admin (Tool: " .. item.Name .. ")"
                    end
                end
            end
        end
    end
end

local function inspectOverhead(player)
    local character = player.Character
    if not character then return nil end
    for _, object in ipairs(character:GetDescendants()) do
        if object:IsA("TextLabel") or object:IsA("TextBox") then
            local ok, text = pcall(function() return object.Text end)
            if ok then
                local valid, role = hasRole(text, player)
                if valid then return "Role: " .. role end
            end
        end
    end
    return nil
end

local function detectPlayer(player)
    if player == LocalPlayer then return nil end

    local creatorId = tonumber(game.CreatorId) or 0
    local creatorType = tostring(game.CreatorType)

    if creatorId > 1000 and (creatorType == "Enum.CreatorType.User" or creatorType == "0")
        and player.UserId == creatorId then
        return "Game Owner"
    end

    if creatorId > 0 and (creatorType == "Enum.CreatorType.Group" or creatorType == "1") then
        local ok, rank = pcall(function() return player:GetRankInGroup(creatorId) end)
        if ok and rank == 255 then return "Group Owner (Rank 255)" end
    end

    return inspectOverhead(player) or detectTool(player)
end

local function scan()
    if not running then return end
    local current = {}
    for _, player in ipairs(Players:GetPlayers()) do
        local role = detectPlayer(player)
        if role then
            current[player.UserId] = {
                Name = player.DisplayName,
                Username = player.Name,
                Role = role
            }
        end
        task.wait()
    end

    local added = {}
    for userId, entry in pairs(current) do
        if not known[userId] then
            table.insert(added, entry)
            lastNotice[userId] = os.clock()
        end
    end

    known = current
    if #added > 0 then
        table.sort(added, function(a, b) return a.Username < b.Username end)
        local lines = {}
        for _, entry in ipairs(added) do
            table.insert(lines, entry.Name .. " (@" .. entry.Username .. ") — " .. entry.Role)
        end
        notify("⚠ Admin / Staff terdeteksi", table.concat(lines, "\n"), 8)
    end
end

local function connectPlayer(player)
    table.insert(connections, player.CharacterAdded:Connect(function()
        task.delay(1, scan)
    end))
    local backpack = player:FindFirstChildOfClass("Backpack")
    if backpack then
        table.insert(connections, backpack.ChildAdded:Connect(function()
            task.delay(0.25, scan)
        end))
    end
    if player.Character then
        table.insert(connections, player.Character.DescendantAdded:Connect(function(object)
            if object:IsA("TextLabel") or object:IsA("TextBox") then
                task.delay(0.25, scan)
            end
        end))
    end
end

function Feature.Start()
    if running then return true end
    running = true
    table.clear(connections)
    table.clear(known)
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then connectPlayer(player) end
    end
    table.insert(connections, Players.PlayerAdded:Connect(function(player)
        connectPlayer(player)
        task.delay(1.5, scan)
    end))
    table.insert(connections, Players.PlayerRemoving:Connect(function(player)
        if known[player.UserId] then
            known[player.UserId] = nil
            notify("Admin Detector", player.DisplayName .. " keluar dari server.", 4)
        end
    end))
    task.spawn(function()
        task.wait(2)
        while running do
            scan()
            for _ = 1, 20 do
                if not running then break end
                task.wait(1)
            end
        end
    end)
    notify("Admin Detector", "Pemantauan aktif. Pemeriksaan otomatis setiap 20 detik.", 4)
    return true
end

function Feature.Stop()
    running = false
    for _, connection in ipairs(connections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(connections)
    table.clear(known)
    notify("Admin Detector", "Pemantauan dinonaktifkan.", 3)
end

return Feature
