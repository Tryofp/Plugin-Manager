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

    local window = TryoUI.new({
        Title = "Tryo Plugin Manager",
        Subtitle = "Standalone • beta2",
        Size = UDim2.fromOffset(590, 370)
    })

    local mainTab = window:CreateTab("Main", "⌂")
    mainTab:CreateSection("WELCOME")
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

    local toolsTab = window:CreateTab("Tools", "⚒")
    toolsTab:CreateSection("TOOLS")
    toolsTab:CreateToggle({
        Name = "Example toggle",
        Default = false,
        Callback = function(enabled)
            print("[Tryo Plugin Manager] Example toggle:", enabled)
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

    return window
end)

if not ok then
    warn("[Tryo Plugin Manager beta2] " .. tostring(result))
end
