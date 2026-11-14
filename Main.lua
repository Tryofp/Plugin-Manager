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
        Subtitle = "V0.1 • Stable",
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
                featureManager.Context.WalkSpeedTarget = math.clamp(tonumber(value) or 16, 16, 100)
                for _, item in ipairs(walkSpeedControllers) do item.Refresh() end
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
    mainTab:CreateSection("QUICK ACCESS")
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
    mainTab:CreateDropdown({
        Name = "F1Lock",
        Build = function(panel)
            addFeatureToggle(mainTab, "F1Lock", cameraTools.F1Lock, "F1 Toggle", panel)
            addFeatureToggle(mainTab, "ForceUnlockCamera", cameraTools.ForceUnlockCamera, "Lock Kamera", panel)
        end
    })

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
