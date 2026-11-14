-- Tryo Plugin Manager - Standalone beta2
-- Compact UI bootstrap. Independent from Infinite Yield.

local BASE_URL = "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/beta2/"
local LIBRARY_URL = BASE_URL .. "UI/Library.lua"

local function fetchModule(url, chunkName)
    local source = game:HttpGet(url)
    assert(type(source) == "string" and source ~= "", "Failed to download " .. chunkName)
    local compiled, compileError = loadstring(source, chunkName)
    assert(type(compiled) == "function", tostring(compileError))
    return compiled()
end

local ok, result = pcall(function()
    local TryoUI = fetchModule(LIBRARY_URL, "TryoUI/Library.lua")
    assert(type(TryoUI) == "table" and type(TryoUI.new) == "function", "Invalid Tryo UI Library")

    -- Read the shared LastUpdate metadata from the production Apps Script endpoint.
    -- The endpoint serves pluginMetadata.LastUpdate from Firestore.
    local HttpService = game:GetService("HttpService")
    local METADATA_URL = "https://script.google.com/macros/s/AKfycbxJzU3MiL_o9PjkF4h-prSw-P8vLVfJqGFXM7pFJOPzIzJXaGmu6z6oK0oJl54a6bQy0Q/exec"
    -- Public release manifest: only intentional user-facing changes create badges.
    local RELEASES = {{
        Version = "0.2", Date = "14/11/2026", Title = "Camera Tools Update",
        Summary = "Peningkatan Force Unlock Camera dan sistem navigasi rilis publik.",
        Changes = {{
            Id = "ForceUnlockCamera", Type = "UPDATE", Tab = "Main", Menu = "F1Lock",
            Feature = "Lock Kamera",
            Details = "Force Unlock Camera kini menangani pergantian CurrentCamera dan memulihkan tipe kamera asal saat fitur dimatikan."
        }}
    }}
    local RELEASE_STATE_FILE = "TryoPluginManager_Releases.json"
    local releaseState = {Seen = {}}
    if type(readfile) == "function" and type(isfile) == "function" then
        pcall(function()
            if isfile(RELEASE_STATE_FILE) then
                local saved = HttpService:JSONDecode(readfile(RELEASE_STATE_FILE))
                if type(saved) == "table" and type(saved.Seen) == "table" then releaseState = saved end
            end
        end)
    end
    local function saveReleaseState()
        if type(writefile) == "function" then pcall(function() writefile(RELEASE_STATE_FILE, HttpService:JSONEncode(releaseState)) end) end
    end
    local function releaseKey(scope, id) return RELEASES[1].Version .. ":" .. scope .. ":" .. id end
    local function isReleaseSeen(scope, id) return releaseState.Seen[releaseKey(scope, id)] == true end
    local function markReleaseSeen(scope, id) releaseState.Seen[releaseKey(scope, id)] = true; saveReleaseState() end


    -- Hub tracker: record every hub load and send exit data synchronously from exit events.
    -- The backend sends push notifications and excludes the developer account.
    local Players = game:GetService("Players")
    local UserInputService = game:GetService("UserInputService")
    local MarketplaceService = game:GetService("MarketplaceService")
    local LocalPlayer = Players.LocalPlayer
    local trackerSessionStart = os.time()
    local trackerExitSent = false
    local trackerMapName = tostring(game.Name or "Unknown Map")
    local trackerRequest = request or http_request or (syn and syn.request)

    local function getTrackerDevice()
        if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
            return "Mobile / Tablet"
        elseif UserInputService.KeyboardEnabled and UserInputService.MouseEnabled then
            return "PC / Laptop"
        elseif UserInputService.GamepadEnabled then
            return "Console / Controller"
        end
        return "Unknown Device"
    end

    -- Resolve the game title ahead of time; never wait for this during shutdown.
    task.spawn(function()
        pcall(function()
            local info = MarketplaceService:GetProductInfo(game.PlaceId)
            if info and info.Name then trackerMapName = info.Name end
        end)
    end)

    local function sendTrackerData(isLeaving)
        if isLeaving then
            if trackerExitSent then return end
            trackerExitSent = true
        end
        if type(trackerRequest) ~= "function" then return end

        -- Intentionally synchronous: exit events may be the last chance to POST.
        pcall(function()
            local elapsed = math.max(0, os.time() - trackerSessionStart)
            local playtime = string.format("%d Menit %d Detik", math.floor(elapsed / 60), elapsed % 60)
            playtime = playtime .. (isLeaving and " (Keluar Game)" or " (Baru Load)")
            local payload = HttpService:JSONEncode({
                Type = isLeaving and "Tracker" or "HubLoad",
                Username = LocalPlayer.Name,
                UserId = tostring(LocalPlayer.UserId),
                Device = getTrackerDevice(),
                Playtime = playtime,
                MapName = trackerMapName,
                PlaceId = tostring(game.PlaceId),
                JobId = game.JobId or "Private/Solo Server"
            })
            trackerRequest({
                Url = METADATA_URL,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = payload
            })
        end)
    end

    -- Load logging can run asynchronously; exit logging remains synchronous.
    task.spawn(function() sendTrackerData(false) end)

    local function replaceTrackerConnection(key, signal, callback)
        local previous = _G[key]
        if previous then pcall(function() previous:Disconnect() end) end
        _G[key] = signal:Connect(callback)
    end

    replaceTrackerConnection("TryoPluginHubBeta2_TrackerRemoving", Players.PlayerRemoving, function(player)
        if player == LocalPlayer then sendTrackerData(true) end
    end)
    replaceTrackerConnection("TryoPluginHubBeta2_TrackerAncestry", LocalPlayer.AncestryChanged, function(_, parent)
        if parent == nil then sendTrackerData(true) end
    end)
    replaceTrackerConnection("TryoPluginHubBeta2_TrackerTeleport", LocalPlayer.OnTeleport, function(state)
        if state == Enum.TeleportState.Started or state == Enum.TeleportState.RequestedFromServer then
            sendTrackerData(true)
        end
    end)

    local function formatLastUpdate(raw)
        raw = tostring(raw or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if raw == "" then return "-" end

        local yyyy, mm, dd, hh, mi = raw:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)[T ](%d%d):(%d%d)")
        if yyyy and mm and dd and hh and mi then
            return string.format("%s/%s/%s %s:%s", dd, mm, yyyy:sub(3), hh, mi)
        end

        -- Accept both four-digit and two-digit years, then always display DD/MM/YY HH:MM.
        dd, mm, yyyy, hh, mi = raw:match("^(%d%d?)[/%-](%d%d?)[/%-](%d%d%d%d)[ T](%d%d?):(%d%d?)")
        if not dd then
            dd, mm, yyyy, hh, mi = raw:match("^(%d%d?)[/%-](%d%d?)[/%-](%d%d)[ T](%d%d?):(%d%d?)")
        end
        if dd and mm and yyyy and hh and mi then
            return string.format("%02d/%02d/%s %02d:%02d",
                tonumber(dd) or 0, tonumber(mm) or 0, yyyy:sub(-2), tonumber(hh) or 0, tonumber(mi) or 0)
        end

        -- Normalize compact DDMMYY dates with either HHMM or HH:MM time.
        local compactDate, compactHour, compactMinute =
            raw:match("^(%d%d%d%d%d%d)%s+(%d%d):(%d%d)$")
        if not compactDate then
            local compactTime
            compactDate, compactTime = raw:match("^(%d%d%d%d%d%d)%s+(%d%d%d%d)$")
            if compactDate and compactTime then
                compactHour, compactMinute = compactTime:sub(1, 2), compactTime:sub(3, 4)
            end
        end
        if compactDate and compactHour and compactMinute then
            return string.format("%s/%s/%s %s:%s",
                compactDate:sub(1, 2), compactDate:sub(3, 4), compactDate:sub(5, 6),
                compactHour, compactMinute)
        end

        -- Also accept compact YYYYMMDD dates and render them as DD/MM/YY.
        local year, month, day, hour, minute =
            raw:match("^(%d%d%d%d)(%d%d)(%d%d)[ T](%d%d):(%d%d)$")
        if year and month and day then
            return string.format("%s/%s/%s %s:%s", day, month, year:sub(3), hour, minute)
        end

        return raw
    end

    local function readLastUpdate()
        local url = METADATA_URL .. "?_=" .. tostring(DateTime.now().UnixTimestampMillis)
        local response = game:HttpGet(url)
        local decoded = HttpService:JSONDecode(response or "{}")
        assert(type(decoded) == "table", "Metadata response is not a JSON object")

        -- The public endpoint normally returns a flat { LastUpdate = value } map.
        -- Accept common casing/nesting variants too, so a wrapper response does not
        -- silently turn a valid Firestore value into a dash.
        local raw = decoded.LastUpdate or decoded.lastUpdate or decoded.last_update
        local containers = { decoded.metadata, decoded.Metadata, decoded.data, decoded.Data }
        for _, container in ipairs(containers) do
            if raw == nil and type(container) == "table" then
                raw = container.LastUpdate or container.lastUpdate or container.last_update
            end
        end
        if raw == nil then
            for key, value in pairs(decoded) do
                if tostring(key):lower():gsub("[^a-z]", "") == "lastupdate" then
                    raw = value
                    break
                end
            end
        end
        if type(raw) == "table" then
            raw = raw.Value or raw.value or raw.Timestamp or raw.timestamp or raw.updatedAt
        end
        assert(raw ~= nil and tostring(raw) ~= "", "LastUpdate key is missing or empty in metadata response")
        return formatLastUpdate(raw)
    end

    -- Build the visible shell immediately; metadata loads asynchronously.
    local window = TryoUI.new({
        Title = "PLUGIN MANAGER",
        Subtitle = "V" .. RELEASES[1].Version .. " • BETA",
        LastUpdate = "Memuat...",
        Size = UDim2.fromOffset(590, 370)
    })
    window:CreateFeedbackButton({ Endpoint = METADATA_URL })

    task.spawn(function()
        local ok, value = pcall(readLastUpdate)
        if ok and window and not window.Destroyed then
            window:SetLastUpdate(value)
        elseif not ok then
            warn("[Tryo Plugin Manager] LastUpdate metadata: " .. tostring(value))
            if window and not window.Destroyed then window:SetLastUpdate("N/A") end
        end
    end)
    local loadingTab = window:CreateTab("Loading", "◌")
    loadingTab:CreateSection("INITIALIZING")
    local loadingMessage = loadingTab:CreateButton({Name = "Loading features, please wait..."})

    local FeatureManager = fetchModule(BASE_URL .. "Runtime/FeatureManager.lua", "FeatureManager.lua")
    assert(type(FeatureManager) == "table" and type(FeatureManager.new) == "function", "Invalid FeatureManager")
    local toolFeatures = fetchModule(BASE_URL .. "Features/Tools.lua", "Features/Tools.lua")
    assert(type(toolFeatures) == "table", "Invalid standalone Tools module")
    local espFeatures = fetchModule(BASE_URL .. "Features/ESP.lua", "Features/ESP.lua")
    assert(type(espFeatures) == "table", "Invalid standalone ESP module")
    local teleportFeatures = fetchModule(BASE_URL .. "Features/Teleport.lua", "Features/Teleport.lua")
    assert(type(teleportFeatures) == "table", "Invalid standalone Teleport module")
    local soundViewFeatures = fetchModule(BASE_URL .. "Features/SoundView.lua", "Features/SoundView.lua")
    assert(type(soundViewFeatures) == "table", "Invalid Sound & View module")
    local adminDetector = fetchModule(BASE_URL .. "Features/AdminDetector.lua", "AdminDetector.lua")
    assert(type(adminDetector) == "table" and type(adminDetector.Start) == "function", "Invalid Admin Detector module")
    local antiDisturbFeatures = fetchModule(BASE_URL .. "Features/AntiDisturb.lua", "Features/AntiDisturb.lua")
    assert(type(antiDisturbFeatures) == "table", "Invalid Anti-Disturb Shield module")
    local codeFinder = fetchModule(BASE_URL .. "Features/CodeFinder.lua", "CodeFinder.lua")
    assert(type(codeFinder) == "table" and type(codeFinder.Start) == "function", "Invalid Code Finder module")
    local instantPrompt = fetchModule(BASE_URL .. "Features/InstantPrompt.lua", "InstantPrompt.lua")
    assert(type(instantPrompt) == "table" and type(instantPrompt.Start) == "function", "Invalid Instant Prompt module")
    local lastServer = fetchModule(BASE_URL .. "Features/LastServer.lua", "LastServer.lua")
    assert(type(lastServer) == "table" and type(lastServer.Start) == "function", "Invalid Last Server module")
    local smartRejoin = fetchModule(BASE_URL .. "Features/SmartRejoin.lua", "SmartRejoin.lua")
    assert(type(smartRejoin) == "table" and type(smartRejoin.Start) == "function", "Invalid Smart Rejoin module")
    local waypoint = fetchModule(BASE_URL .. "Features/Waypoint.lua", "Waypoint.lua")
    assert(type(waypoint) == "table" and type(waypoint.Start) == "function", "Invalid Waypoint Manager module")
    local cameraTools = fetchModule(BASE_URL .. "Features/CameraTools.lua", "CameraTools.lua")
    assert(type(cameraTools) == "table" and cameraTools.F1Lock and cameraTools.ForceUnlockCamera, "Invalid Camera Tools module")
    local aimAssist = fetchModule(BASE_URL .. "Features/AimAssist.lua", "AimAssist.lua")
    assert(type(aimAssist) == "table" and type(aimAssist.Start) == "function", "Invalid Aim Assist module")
    local interactable = fetchModule(BASE_URL .. "Features/Interactable.lua", "Interactable.lua")
    assert(type(interactable) == "table" and type(interactable.SetFeatureEnabled) == "function", "Invalid Interactable module")
    local tpItem = fetchModule(BASE_URL .. "Features/TPitem.lua", "TPitem.lua")
    assert(type(tpItem) == "table" and type(tpItem.Start) == "function" and type(tpItem.Stop) == "function", "Invalid TPitem module")
    local musicPlayer = fetchModule(BASE_URL .. "Features/MusicPlayer.lua", "MusicPlayer.lua")
    assert(type(musicPlayer) == "table" and type(musicPlayer.Start) == "function" and type(musicPlayer.Stop) == "function", "Invalid Music Player module")

    local featureManager = FeatureManager.new()
    featureManager.Context.FeatureManager = featureManager
    local featureControllers = {}
    local walkSpeedControllers = {}

    local function syncFeature(featureId, enabled)
        for _, control in ipairs(featureControllers[featureId] or {}) do
            control.Set(enabled, true)
        end
    end

    local function addFeatureToggle(tab, featureId, definition, displayName, parent)
        if not definition then return end
        if not featureManager.Registry[featureId] then featureManager:Register(featureId, definition) end
        local control = tab:CreateToggle({
            Name = displayName or definition.Name or featureId,
            Default = featureManager:IsEnabled(featureId),
            Parent = parent,
            Callback = function(enabled)
                local success, err = featureManager:SetEnabled(featureId, enabled)
                if not success then warn("[Tryo Plugin Manager] " .. featureId .. ": " .. tostring(err)) end
                syncFeature(featureId, featureManager:IsEnabled(featureId))
            end
        })
        featureControllers[featureId] = featureControllers[featureId] or {}
        table.insert(featureControllers[featureId], control)
        return control
    end

    local function addWalkSpeed(tab)
        if not featureManager.Registry.WalkSpeed then featureManager:Register("WalkSpeed", toolFeatures.WalkSpeed) end
        if featureManager.Context.WalkSpeedTarget == nil then featureManager.Context.WalkSpeedTarget = 16 end
        local control = tab:CreateWalkSpeedControl({
            Name = "WalkSpeed",
            GetValue = function() return featureManager.Context.WalkSpeedTarget end,
            SetValue = function(value)
                local numeric = tonumber(value)
                if not numeric then return false end
                featureManager.Context.WalkSpeedTarget = math.clamp(numeric, 16, 100)
                for _, item in ipairs(walkSpeedControllers) do item.Refresh() end
                return true
            end,
            Callback = function(enabled)
                local success, err = featureManager:SetEnabled("WalkSpeed", enabled)
                if not success then warn("[Tryo Plugin Manager] WalkSpeed: " .. tostring(err)) end
                for _, item in ipairs(walkSpeedControllers) do item.Set(featureManager:IsEnabled("WalkSpeed"), true) end
            end
        })
        table.insert(walkSpeedControllers, control)
        control.Set(featureManager:IsEnabled("WalkSpeed"), true)
    end

    local function addInteractableToggle(tab, id, name, parent)
        local control = tab:CreateToggle({
            Name = name,
            Parent = parent,
            Default = false,
            Callback = function(enabled)
                local success, err = interactable:SetFeatureEnabled(id, enabled)
                if not success then warn("[Tryo Plugin Manager] " .. id .. ": " .. tostring(err)) end
            end
        })
        return control
    end

    local mainTab = window:CreateTab("Main", "⌂")
    local release = RELEASES[1]
    local cameraChange = release.Changes[1]
    if not isReleaseSeen("tab", "Main") then mainTab:SetBadge(cameraChange.Type) end
    mainTab.OnActivated = function()
        mainTab:SetBadge(nil)
        markReleaseSeen("tab", "Main")
    end
    mainTab:CreateSection("QUICK ACCESS")
    mainTab:CreateDropdown({
        Name = "VERSION HISTORY",
        Build = function(panel)
            for _, item in ipairs(RELEASES) do
                mainTab:CreateButton({
                    Name = "V" .. item.Version .. "  •  " .. item.Date .. "  •  " .. item.Title,
                    Parent = panel,
                    Callback = function()
                        local details = item.Summary
                        for _, change in ipairs(item.Changes or {}) do
                            details = details .. "\n\n" .. change.Type .. " • " .. change.Feature .. "\n" .. change.Details
                        end
                        if window and not window.Destroyed then
                            window:ShowReleaseDetails("LOG VERSION", "V" .. item.Version .. "\n\n" .. details)
                        end
                    end
                })
            end
        end
    })
    addFeatureToggle(mainTab, "WaypointManager", waypoint, "Waypoint")
    addFeatureToggle(mainTab, "PlayMusic", musicPlayer, "Play Music")
    mainTab:CreateDropdown({
        Name = "Rejoin",
        Build = function(panel)
            local autoSave = {
                Name = "Auto Save Server",
                Start = function()
                    if featureManager.Context.AutoSaveRunning then return true end
                    featureManager.Context.AutoSaveRunning = true
                    task.spawn(function()
                        while featureManager.Context.AutoSaveRunning do
                            pcall(lastServer.SaveCurrent)
                            task.wait(30)
                        end
                    end)
                    pcall(lastServer.SaveCurrent)
                    return true
                end,
                Stop = function() featureManager.Context.AutoSaveRunning = false end
            }
            addFeatureToggle(mainTab, "AutoSaveServer", autoSave, "Auto Save", panel)
            panel.Parent = panel.Parent
            mainTab:CreateButton({Name = "Save Server", Parent = panel, Callback = function() lastServer.SaveCurrent() end})
            mainTab:CreateButton({Name = "Last Rejoin", Parent = panel, Callback = function() lastServer.RejoinSaved() end})
            addFeatureToggle(mainTab, "SmartRejoin", smartRejoin, "Smart Rejoin", panel)
        end
    })
    mainTab:CreateDropdown({
        Name = "AIMBOT",
        Build = function(panel)
            addFeatureToggle(mainTab, "AimAssist", aimAssist, "Aimbot", panel)
            mainTab:CreateButton({Name = "Set Radius", Parent = panel, Callback = function()
                if aimAssist.OpenSettings then aimAssist.OpenSettings() end
            end})
        end
    })
    local f1Menu
    f1Menu = mainTab:CreateDropdown({
        Name = "F1Lock",
        Build = function(panel)
            addFeatureToggle(mainTab, "F1Lock", cameraTools.F1Lock, "F1 Toggle", panel)
            local forceUnlockControl = addFeatureToggle(mainTab, "ForceUnlockCamera", cameraTools.ForceUnlockCamera, "Lock Kamera", panel)
            if not isReleaseSeen("feature", "ForceUnlockCamera") then
                forceUnlockControl.SetBadge(cameraChange.Type)
            end
            forceUnlockControl.OnBadgeActivate = function()
                forceUnlockControl.SetBadge(nil)
                markReleaseSeen("feature", "ForceUnlockCamera")
                f1Menu.SetBadge(nil)
                markReleaseSeen("menu", "F1Lock")
            end
        end
    })
    if not isReleaseSeen("menu", "F1Lock") then f1Menu.SetBadge(cameraChange.Type) end
    f1Menu.OnExpanded = function(expanded)
        if expanded then
            f1Menu.SetBadge(nil)
            markReleaseSeen("menu", "F1Lock")
        end
    end

    local mountainTab = window:CreateTab("Gunung", "▲")
    mountainTab:CreateSection("MOUNTAIN QUICK ACCESS")
    addFeatureToggle(mountainTab, "WaypointManager", waypoint, "Waypoint")
    addFeatureToggle(mountainTab, "PlayerESP", espFeatures.PlayerESP)
    addFeatureToggle(mountainTab, "InfiniteJump", toolFeatures.InfiniteJump)
    addFeatureToggle(mountainTab, "InstantPrompt", instantPrompt, "Instant Prompt")
    addWalkSpeed(mountainTab)
    addInteractableToggle(mountainTab, "PPESP", "PPESP")
    addFeatureToggle(mountainTab, "Spectate", soundViewFeatures.Spectate, "Spectator")

    local horrorTab = window:CreateTab("Horor", "◈")
    horrorTab:CreateSection("HORROR QUICK ACCESS")
    horrorTab:CreateDropdown({
        Name = "Interactable",
        Build = function(panel)
            local items = {
                {id="PPESP", name="Proximity (PPESP)"},
                {id="ITP", name="Item Teleport (ITP)"},
                {id="DESP", name="Door (DESP)"},
                {id="CDESP", name="Click (CDESP)"},
                {id="TESP", name="Touch (TESP)"},
                {id="ITESP", name="Item (ITESP)"},
                {id="LOOT", name="Loot"}
            }
            for _, item in ipairs(items) do addInteractableToggle(horrorTab, item.id, item.name, panel) end
        end
    })
    horrorTab:CreateDropdown({
        Name = "ESP",
        Build = function(panel)
            addFeatureToggle(horrorTab, "PlayerESP", espFeatures.PlayerESP, "Player ESP", panel)
            addFeatureToggle(horrorTab, "EnemyESP", espFeatures.EnemyESP, "Enemy ESP", panel)
        end
    })
    addFeatureToggle(horrorTab, "Fullbright", toolFeatures.Fullbright, "Full Bright")
    addFeatureToggle(horrorTab, "InstantPrompt", instantPrompt, "Instant Prompt")
    addFeatureToggle(horrorTab, "InfiniteJump", toolFeatures.InfiniteJump)
    addWalkSpeed(horrorTab)
    addFeatureToggle(horrorTab, "MuteMapSounds", soundViewFeatures.MuteMapSounds, "Mute Sound")
    addFeatureToggle(horrorTab, "Noclip", toolFeatures.Noclip)
    addFeatureToggle(horrorTab, "CodeFinder", codeFinder, "Code Finder")

    local toolsTab = window:CreateTab("Tools", "⚒")
    toolsTab:CreateSection("UTILITY")
    addFeatureToggle(toolsTab, "AdminDetector", adminDetector, "Admin Detect")
    addFeatureToggle(toolsTab, "AntiAFK", toolFeatures.AntiAFK)
    addFeatureToggle(toolsTab, "MobileInspector", toolFeatures.MobileInspector, "Inspector")
    toolsTab:CreateDropdown({
        Name = "Effect",
        Build = function(panel)
            for _, featureId in ipairs({"AnchorNearby", "AntiWind", "AntiTrigger", "AntiShake"}) do
                addFeatureToggle(toolsTab, featureId, antiDisturbFeatures[featureId], nil, panel)
            end
        end
    })

    local settingsTab = window:CreateTab("Settings", "⚙")
    settingsTab:CreateSection("APPEARANCE")
    settingsTab:CreateSizeControl({ Name = "Customize window size" })
    settingsTab:CreateGlassControl({ Name = "Glass transparency" })
    settingsTab:CreateColorWheel({ Name = "Custom theme color • Color wheel" })

    if window.Gui then
        window.Gui.Destroying:Connect(function()
            featureManager:Destroy()
            interactable:Stop()
        end)
    end

    -- Remove the temporary loading page after all feature tabs are ready.
    for index, tab in ipairs(window.Tabs) do
        if tab == loadingTab then table.remove(window.Tabs, index); break end
    end
    loadingTab.Button:Destroy()
    loadingTab.Page:Destroy()
    if window.Tabs[1] then window.Tabs[1]:Activate() end

    return window
end)

if not ok then
    warn("[Tryo Plugin Manager beta2] " .. tostring(result))
end
