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

local function escapePattern(value)
    return (tostring(value or ""):gsub("([^%w])", "%%%1"))
end

local function hasRole(text, player)
    local raw = tostring(text or "")
    if raw == "" or #raw > 128 then return false end
    local value = normalize(raw)
    if value == "" then return false end

    -- Exclude common non-staff labels before checking role tokens.
    for _, excluded in ipairs(EXCLUDED_TEXT) do
        if string.find(value, excluded, 1, true) then return false end
    end

    -- Remove player names from formatted chat prefixes so a username such as
    -- "AdminFan" or a display name cannot become an accidental role signal.
    local playerName = normalize(player.Name)
    local displayName = normalize(player.DisplayName)
    if playerName ~= "" then value = value:gsub(escapePattern(playerName), " ") end
    if displayName ~= "" then value = value:gsub(escapePattern(displayName), " ") end
    value = value:gsub("%s+", " ")

    for _, role in ipairs(ROLE_WORDS) do
        local pattern = "%f[%a]" .. role:gsub(" ", "%%s+") .. "%f[%A]"
        if string.find(value, pattern) then return true, raw end
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

local function watchCharacter(player, character)
    if not character then return end
    table.insert(connections, character.DescendantAdded:Connect(function(object)
        if object:IsA("TextLabel") or object:IsA("TextBox") then
            task.delay(0.25, scan)
        end
    end))
    task.delay(1, scan)
end

local function connectPlayer(player)
    table.insert(connections, player.CharacterAdded:Connect(function(character)
        watchCharacter(player, character)
    end))
    local backpack = player:FindFirstChildOfClass("Backpack")
    if backpack then
        table.insert(connections, backpack.ChildAdded:Connect(function()
            task.delay(0.25, scan)
        end))
    end
    table.insert(connections, player.ChildAdded:Connect(function(child)
        if child:IsA("Backpack") then
            table.insert(connections, child.ChildAdded:Connect(function()
                task.delay(0.25, scan)
            end))
        end
    end))
    if player.Character then watchCharacter(player, player.Character) end
end

local function handleChatRole(player, prefixText, tags)
    if not running or not player or player == LocalPlayer then return end
    local valid, role = hasRole(prefixText, player)
    if not valid and type(tags) == "table" then
        for _, tag in ipairs(tags) do
            local tagText = tag.TagText or tag.Text or ""
            local tagValid, tagRole = hasRole(tagText, player)
            if tagValid then valid, role = true, "[ " .. tagText .. " ] Chat Tag"; break end
        end
    end
    if valid then
        task.defer(scan)
    end
end

function Feature.Start()
    if running then return true end
    running = true
    table.clear(connections)
    table.clear(known)

    -- Legacy chat pipeline: inspect PrefixText and explicit tag metadata.
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    pcall(function()
        local legacy = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
        local remote = legacy and legacy:FindFirstChild("OnMessageDoneFiltering")
        if remote and remote:IsA("RemoteEvent") then
            table.insert(connections, remote.OnClientEvent:Connect(function(messageData)
                if type(messageData) ~= "table" then return end
                local speaker = messageData.FromSpeaker
                local player = type(speaker) == "string" and Players:FindFirstChild(speaker) or nil
                local extra = messageData.ExtraData or {}
                handleChatRole(player, extra.PrefixText or "", extra.Tags)
            end))
        end
    end)

    -- Modern TextChatService event (does not replace OnIncomingMessage).
    pcall(function()
        local TextChatService = game:GetService("TextChatService")
        table.insert(connections, TextChatService.MessageReceived:Connect(function(message)
            local source = message and message.TextSource
            if not source then return end
            local player = Players:GetPlayerByUserId(source.UserId)
            if player then handleChatRole(player, message.PrefixText or "", nil) end
        end))
    end)

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
