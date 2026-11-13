-- Tryo Plugin Manager - Standalone beta2
-- Compact UI bootstrap. Independent from Infinite Yield.
-- Legacy feature modules will be migrated into this standalone architecture.

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
    local featureManager = FeatureManager.new()

    local window = TryoUI.new({
        Title = "Tryo Plugin Manager",
        Subtitle = "Standalone • beta2",
        Size = UDim2.fromOffset(590, 370)
    })

    local mainTab = window:CreateTab("Main", "⌂")
    mainTab:CreateSection("PLAYER & ENEMY ESP")
    local espOrder = {"PlayerESP", "EnemyESP"}
    for _, featureId in ipairs(espOrder) do
        local definition = espFeatures[featureId]
        if definition then
            featureManager:Register(featureId, definition)
            mainTab:CreateToggle({
                Name = definition.Name or featureId,
                Default = false,
                Callback = function(enabled)
                    local ok, err = featureManager:SetEnabled(featureId, enabled)
                    if not ok then
                        warn("[Tryo Plugin Manager] " .. featureId .. ": " .. tostring(err))
                    end
                end
            })
        end
    end
    mainTab:CreateSection("TELEPORT")
    local teleportDefinition = teleportFeatures.PlayerTeleport
    if teleportDefinition then
        featureManager:Register("PlayerTeleport", teleportDefinition)
        mainTab:CreateToggle({
            Name = teleportDefinition.Name or "Teleport to Player",
            Default = false,
            Callback = function(enabled)
                local ok, err = featureManager:SetEnabled("PlayerTeleport", enabled)
                if not ok then
                    warn("[Tryo Plugin Manager] PlayerTeleport: " .. tostring(err))
                end
            end
        })
    end
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
    local toolOrder = {"AntiAFK", "Fullbright", "InfiniteJump", "Noclip"}
    for _, featureId in ipairs(toolOrder) do
        local definition = toolFeatures[featureId]
        if definition then
            featureManager:Register(featureId, definition)
            toolsTab:CreateToggle({
                Name = definition.Name or featureId,
                Default = false,
                Callback = function(enabled)
                    local ok, err = featureManager:SetEnabled(featureId, enabled)
                    if not ok then
                        warn("[Tryo Plugin Manager] " .. featureId .. ": " .. tostring(err))
                    end
                end
            })
        end
    end

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
