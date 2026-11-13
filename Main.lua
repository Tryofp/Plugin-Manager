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

    local featureManager = FeatureManager.new()
    featureManager.Context.FeatureManager = featureManager

    local window = TryoUI.new({
        Title = "Tryo Plugin Manager",
        Subtitle = "Standalone • beta2",
        Size = UDim2.fromOffset(590, 370)
    })

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
    mountainTab:CreateSection("GUNUNG")
    mountainTab:CreateButton({ Name = "Feature slots are ready" })

    local horrorTab = window:CreateTab("Horor", "◈")
    horrorTab:CreateSection("HOROR")
    horrorTab:CreateButton({ Name = "Feature slots are ready" })

    local visualTab = window:CreateTab("Visual", "◉")
    visualTab:CreateSection("VISUAL")
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
        toolsTab:CreateSection("SOUND & VIEW")
    addFeatureToggle(toolsTab, "MuteMapSounds", soundViewFeatures.MuteMapSounds)
    addFeatureToggle(toolsTab, "Spectate", soundViewFeatures.Spectate)

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
        end)
    end

    return window
end)

if not ok then
    warn("[Tryo Plugin Manager beta2] " .. tostring(result))
end
