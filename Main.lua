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

    -- Build the visible shell before downloading the feature modules.
    local window = TryoUI.new({
        Title = "PLUGIN MANAGER",
        Subtitle = "Versi Window • Stable",
        LastUpdate = "14 Nov 2026",
        Size = UDim2.fromOffset(590, 370)
    })
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


    local function addFeatureToggle(tab, featureId, definition)
        if not definition then return end
        featureManager:Register(featureId, definition)
        tab:CreateToggle({
            Name = definition.Name or featureId,
            Default = false,
            Callback = function(enabled)
                local success, err = featureManager:SetEnabled(featureId, enabled)
                if not success then
                    warn("[Tryo Plugin Manager] " .. featureId .. ": " .. tostring(err))
                end
            end
        })
    end

    local mainTab = window:CreateTab("Main", "⌂")
    mainTab:CreateSection("PLAYER & ENEMY ESP")
    for _, featureId in ipairs({"PlayerESP", "EnemyESP"}) do
        addFeatureToggle(mainTab, featureId, espFeatures[featureId])
    end
    mainTab:CreateSection("TELEPORT")
    addFeatureToggle(mainTab, "PlayerTeleport", teleportFeatures.PlayerTeleport)
    mainTab:CreateSection("STATUS")
    mainTab:CreateButton({
        Name = "Tryo Plugin Manager is running",
        Callback = function()
            print("[Tryo Plugin Manager] Standalone beta2 is running.")
        end
    })

    local mountainTab = window:CreateTab("Gunung", "▲")
    mountainTab:CreateSection("WAYPOINT & CHECKPOINT")
    addFeatureToggle(mountainTab, "WaypointManager", waypoint)

    local horrorTab = window:CreateTab("Horor", "◈")
    horrorTab:CreateSection("HOROR")
    horrorTab:CreateButton({ Name = "Feature slots are ready" })

    local visualTab = window:CreateTab("Visual", "◉")
    visualTab:CreateSection("VISUAL")
    visualTab:CreateSection("TARGET ASSIST")
    addFeatureToggle(visualTab, "AimAssist", aimAssist)
    visualTab:CreateButton({
        Name = "Aim Assist Settings (Radius)",
        Callback = function()
            if aimAssist.OpenSettings then aimAssist.OpenSettings() end
        end
    })
    visualTab:CreateButton({ Name = "Visual features will be migrated here" })

    local toolsTab = window:CreateTab("Tools", "⚒")
    toolsTab:CreateSection("STANDALONE TOOLS")
    for _, featureId in ipairs({"AntiAFK", "Fullbright", "InfiniteJump", "Noclip"}) do
        addFeatureToggle(toolsTab, featureId, toolFeatures[featureId])
    end
    featureManager:Register("WalkSpeed", toolFeatures.WalkSpeed)
    featureManager.Context.WalkSpeedTarget = 16
    toolsTab:CreateWalkSpeedControl({
        Name = "WalkSpeed",
        GetValue = function() return featureManager.Context.WalkSpeedTarget end,
        SetValue = function(value)
            featureManager.Context.WalkSpeedTarget = math.clamp(tonumber(value) or 16, 16, 100)
        end,
        Callback = function(enabled)
            local success, err = featureManager:SetEnabled("WalkSpeed", enabled)
            if not success then warn("[Tryo Plugin Manager] WalkSpeed: " .. tostring(err)) end
        end
    })
    toolsTab:CreateSection("INSPECTOR")
    addFeatureToggle(toolsTab, "MobileInspector", toolFeatures.MobileInspector)
    toolsTab:CreateSection("CAMERA")
    addFeatureToggle(toolsTab, "F1Lock", cameraTools.F1Lock)
    addFeatureToggle(toolsTab, "ForceUnlockCamera", cameraTools.ForceUnlockCamera)
    toolsTab:CreateSection("SOUND & VIEW")
    addFeatureToggle(toolsTab, "MuteMapSounds", soundViewFeatures.MuteMapSounds)
    addFeatureToggle(toolsTab, "Spectate", soundViewFeatures.Spectate)
    toolsTab:CreateSection("SECURITY")
    addFeatureToggle(toolsTab, "AdminDetector", adminDetector)
    toolsTab:CreateSection("ANTI-DISTURB SHIELD")
    for _, featureId in ipairs({"AnchorNearby", "AntiWind", "AntiTrigger", "AntiShake"}) do
        addFeatureToggle(toolsTab, featureId, antiDisturbFeatures[featureId])
    end
    toolsTab:CreateSection("INTERACTION")
    addFeatureToggle(toolsTab, "InstantPrompt", instantPrompt)
    toolsTab:CreateSection("INTERACTABLE")
    local interactableFeatures = {
        {id = "PPESP", name = "Proximity (PPESP)"},
        {id = "ITP", name = "Item Teleport (ITP)"},
        {id = "DESP", name = "Door (DESP)"},
        {id = "CDESP", name = "Click (CDESP)"},
        {id = "TESP", name = "Touch (TESP)"},
        {id = "ITESP", name = "Item (ITESP)"},
        {id = "LOOT", name = "Loot"}
    }
    for _, item in ipairs(interactableFeatures) do
        local featureId = item.id
        local featureName = item.name
        toolsTab:CreateToggle({
            Name = featureName,
            Default = false,
            Callback = function(enabled)
                local success, err = interactable:SetFeatureEnabled(featureId, enabled)
                if not success then
                    warn("[Tryo Plugin Manager] " .. item.id .. ": " .. tostring(err))
                end
            end
        })
    end
    toolsTab:CreateSection("ITEM GRABBER")
    addFeatureToggle(toolsTab, "TeleportToItem", tpItem)
    toolsTab:CreateSection("MUSIC")
    addFeatureToggle(toolsTab, "PlayMusic", musicPlayer)
    toolsTab:CreateSection("SERVER SESSION")
    featureManager:Register("LastServer", lastServer)
    local lastServerStarted, lastServerError = featureManager:SetEnabled("LastServer", true)
    if not lastServerStarted then warn("[Tryo Plugin Manager] LastServer: " .. tostring(lastServerError)) end
    toolsTab:CreateButton({ Name = "Save Current Server", Callback = function() lastServer.SaveCurrent() end })
    toolsTab:CreateButton({ Name = "Rejoin Saved Server", Callback = function() lastServer.RejoinSaved() end })
    toolsTab:CreateSection("SMART REJOIN")
    addFeatureToggle(toolsTab, "SmartRejoin", smartRejoin)
    toolsTab:CreateSection("PUZZLE TOOLS")
    addFeatureToggle(toolsTab, "CodeFinder", codeFinder)

    local settingsTab = window:CreateTab("Settings", "⚙")
    settingsTab:CreateSection("APPEARANCE")
    settingsTab:CreateSizeControl({ Name = "Customize window size" })
    settingsTab:CreateGlassControl({ Name = "Glass transparency" })
    settingsTab:CreateSection("SETTINGS")
    settingsTab:CreateButton({
        Name = "Close Plugin Manager",
        Callback = function() window:Destroy() end
    })

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
