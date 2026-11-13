local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local LocalPlayer = Players.LocalPlayer

----------------------------------------------------------------
-- CONNECTION STORAGE
----------------------------------------------------------------

local connections = {
    click = nil,
    proximity = nil,
    proximityRemoving = nil,
    door = nil,
    doorRemoving = nil,
    touchItem = nil,
    touchTrigger = nil,
    loot = nil,
    lootRemoving = nil,
    itp = nil,
}

----------------------------------------------------------------
-- FILTER, BLACKLIST & PIN STORAGE (PER-TAB CONTEXT)
----------------------------------------------------------------
local tabFilters = {
    ["PPESP"] = "",
    ["ITESP"] = "",
    ["CDESP"] = "",
    ["DESP"] = "",
    ["LOOT"] = "",
}

local tabBlacklists = {
    ["PPESP"] = {},
    ["ITESP"] = {},
    ["CDESP"] = {},
    ["DESP"] = {},
    ["LOOT"] = {},
}

local pinnedItems = {} -- Penyimpanan global untuk item yang di-pin (📌)

-- Variabel Filter Khusus untuk ESP Utama via Command Arguments
local ppespFilter = ""
local cdespFilter = ""
local itespFilter = ""
local despFilter = ""
local lootFilter = ""

-- Cache Independen untuk ITP
local itpCache = {} 
local itpTouchCache = {}
local itpClickCache = {}
local itpLootCache = {}

----------------------------------------------------------------
-- PROXIMITY ESP (PPESP)
----------------------------------------------------------------

local proximityTracked = {}
local proximityPartMap = {}
local proximityCompleted = {}

local PPESP_NAME = "proximity esp"
local DESP_NAME = "door esp"
local DESP_LABEL_NAME = "door esp name"
local ppespEnabled = false
local despEnabled = false
local despTracked = {}
local PPESP_DOOR_COLOR = "Bright blue"
local PPESP_ITEM_COLOR = "Bright green"
local PPESP_DONE_COLOR = "Institutional white"
local PPESP_LABEL_NAME = "proximity esp name"

local PPESP_RENDER_DISTANCE = 800
local PPESP_LABEL_DISTANCE = 800
local PPESP_DISTANCE_INTERVAL = 0.30
local ppespDistanceLoopToken = 0

local DOOR_KEYWORDS = {
    "door", "doors", "gate", "gates", "entrance", "entrances",
    "exit", "exits", "entry", "portal", "passage", "doorway",
    "airlock", "hatch"
}

local ITEM_PROTECT_KEYWORDS = {
    "keris", "sword", "kunci", "key", "item", "artifact", "relic", "dagger", "blade", "gembok", "padlock", "jerigen", "fuel", "bensin"
}

local CONTAINER_KEYWORDS = {
    "laci", "loker", "drawer", "locker", "cabinet", "chest", "desk", "closet", "wardrobe", "lemari"
}

local GENERIC_PART_NAMES = {
    "part", "meshpart", "handle", "base", "core", "proximitypart", "visualmodel", "model", "collectibles", "primarypart"
}

-- Mapping Bahasa sederhana untuk mendukung pencarian bilingual
local TRANSLATION_MAP = {
    ["telur"] = "egg",
    ["egg"] = "telur",
    ["cangkir"] = "cup",
    ["cup"] = "cangkir",
    ["roti"] = "bread",
    ["bread"] = "roti",
    ["susu"] = "milk",
    ["milk"] = "susu",
    ["keju"] = "cheese",
    ["cheese"] = "keju",
    ["mentega"] = "butter",
    ["butter"] = "mentega",
    ["kue"] = "cake",
    ["cake"] = "kue",
    ["kopi"] = "coffee",
    ["coffee"] = "kopi",
    ["teh"] = "tea",
    ["tea"] = "teh"
}

----------------------------------------------------------------
-- COMMON HELPERS
----------------------------------------------------------------

local function lower(value)
    return string.lower(tostring(value or ""))
end

local function isInWorkspace(instance)
    if not instance then
        return false
    end

    return instance:IsDescendantOf(Workspace)
end

local function containsKeyword(text, keywords)
    text = lower(text)

    for _, keyword in ipairs(keywords) do
        if string.find(text, lower(keyword), 1, true) then
            return true
        end
    end

    return false
end

local function isGenericName(name)
    local lName = lower(name)
    for _, gName in ipairs(GENERIC_PART_NAMES) do
        if lName == gName or string.find(lName, "^pcylinder") or string.find(lName, "^pcube") or string.find(lName, "^polysurface") then
            return true
        end
    end
    return false
end

local function getNameChain(instance)
    local names = {}
    local current = instance
    local count = 0

    while current and current ~= Workspace and count < 10 do
        names[#names + 1] = current.Name
        current = current.Parent
        count += 1
    end

    return names
end

local function createESP(part, name, color)
    if not part or not part:IsA("BasePart") then
        return nil
    end

    local existing = part:FindFirstChild(name)

    if existing and existing:IsA("BoxHandleAdornment") then
        existing.Adornee = part
        existing.Size = part.Size
        existing.AlwaysOnTop = true
        existing.Transparency = 0.1
        existing.Color = BrickColor.new(color)
        existing.Visible = true
        return existing
    end

    local esp = Instance.new("BoxHandleAdornment")
    esp.Name = name
    esp.Parent = part
    esp.Adornee = part
    esp.AlwaysOnTop = true
    esp.ZIndex = 0
    esp.Size = part.Size
    esp.Transparency = 0.1
    esp.Color = BrickColor.new(color)
    esp.Visible = true

    return esp
end

local function removeESP(part)
    if not part then
        return
    end

    local esp = part:FindFirstChild(PPESP_NAME)

    if esp and esp:IsA("BoxHandleAdornment") then
        esp:Destroy()
    end

    local label = part:FindFirstChild(PPESP_LABEL_NAME)

    if label and label:IsA("BillboardGui") then
        label:Destroy()
    end
end

local isDoorPrompt

local function getProximityItemName(prompt, part)
    if prompt then
        local objectText = tostring(prompt.ObjectText or "")
        if objectText ~= "" then
            return objectText
        end
        local actionText = tostring(prompt.ActionText or "")
        if actionText ~= "" then
            return actionText
        end
    end

    if part then
        local partName = tostring(part.Name or "")
        if partName ~= "" and not isGenericName(partName) then
            return partName
        end

        local current = part.Parent
        while current and current ~= Workspace do
            local currentName = tostring(current.Name or "")
            if currentName ~= "" and not isGenericName(currentName) and currentName ~= "_INTERACTABLES" then
                return currentName
            end
            current = current.Parent
        end
    end

    return "Interactable"
end

-- Helper Pengecekan Filter Spesifik ESP Utama
local function passesESPFilter(filterKeyword, promptOrTouch, part)
    if not filterKeyword or filterKeyword == "" then return true end

    local textTargets = {}
    if promptOrTouch then
        if promptOrTouch:IsA("ProximityPrompt") or promptOrTouch:IsA("ClickDetector") then
            table.insert(textTargets, lower(promptOrTouch.Name))
            table.insert(textTargets, lower(promptOrTouch.ActionText))
            table.insert(textTargets, lower(promptOrTouch.ObjectText))
        end
    end

    if part then
        table.insert(textTargets, lower(part.Name))
        if part.Parent and part.Parent ~= Workspace then
            table.insert(textTargets, lower(part.Parent.Name))
        end
    end

    for _, target in ipairs(textTargets) do
        if string.find(target, filterKeyword, 1, true) then
            return true
        end
    end

    return false
end

local function createProximityNameLabel(prompt, part)
    if not ppespEnabled then return nil end
    if not part or not part:IsA("BasePart") then
        return nil
    end

    local text = getProximityItemName(prompt, part)
    local label = part:FindFirstChild(PPESP_LABEL_NAME)

    if not label or not label:IsA("BillboardGui") then
        if label then
            label:Destroy()
        end

        label = Instance.new("BillboardGui")
        label.Name = PPESP_LABEL_NAME
        label.Parent = part
        label.Adornee = part
        label.AlwaysOnTop = true
        label.LightInfluence = 0
        label.Size = UDim2.fromOffset(180, 32)
        label.StudsOffset = Vector3.new(0, math.max(2.8, part.Size.Y * 0.5 + 1), 0)
        label.MaxDistance = PPESP_LABEL_DISTANCE
        label.Enabled = true

        local textLabel = Instance.new("TextLabel")
        textLabel.Name = "Name"
        textLabel.Parent = label
        textLabel.BackgroundTransparency = 1
        textLabel.Size = UDim2.fromScale(1, 1)
        textLabel.Font = Enum.Font.GothamBold
        textLabel.TextSize = 14
        textLabel.TextColor3 = Color3.new(1, 1, 1)
        textLabel.TextStrokeTransparency = 0.25
        textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
        textLabel.TextXAlignment = Enum.TextXAlignment.Center
        textLabel.TextYAlignment = Enum.TextYAlignment.Center
        textLabel.TextWrapped = true
    end

    label.MaxDistance = PPESP_LABEL_DISTANCE
    label.Enabled = true

    local textLabel = label:FindFirstChild("Name")

    if textLabel and textLabel:IsA("TextLabel") then
        textLabel.Text = text
    end

    return label
end

----------------------------------------------------------------
-- PROMPT / CHARACTER DETECTION
----------------------------------------------------------------

local markPromptCompleted

local function getPromptPart(prompt)
    if not prompt then
        return nil
    end

    local parent = prompt.Parent

    if not parent then
        return nil
    end

    if parent:IsA("BasePart") then
        return parent
    end

    if parent:IsA("Attachment") then
        if parent.Parent and parent.Parent:IsA("BasePart") then
            return parent.Parent
        end
    end

    local current = parent
    while current and current ~= Workspace do
        if current:IsA("BasePart") then
            return current
        elseif current:IsA("Model") or current:IsA("Folder") then
            if current:IsA("Model") and current.PrimaryPart and current.PrimaryPart:IsA("BasePart") then
                return current.PrimaryPart
            end

            local handleCandidate = current:FindFirstChild("Handle", true) or current:FindFirstChild("Core", true) or current:FindFirstChild("ProximityPart", true)
            if handleCandidate and handleCandidate:IsA("BasePart") then
                return handleCandidate
            end

            local anyPart = current:FindFirstChildWhichIsA("BasePart", true)
            if anyPart then
                return anyPart
            end
        end
        current = current.Parent
    end

    return nil
end

local isNPCPrompt

isNPCPrompt = function(prompt)
    if not prompt then
        return false
    end

    local current = prompt.Parent

    while current and current ~= Workspace do
        if current:IsA("Model") then
            if current:FindFirstChildOfClass("Humanoid")
            and not Players:GetPlayerFromCharacter(current) then
                return true
            end
        end

        current = current.Parent
    end

    return false
end

local function isPlayerCharacter(prompt)
    if not prompt then
        return false
    end

    local current = prompt.Parent

    while current and current ~= Workspace do
        if current:IsA("Model") then
            local player = Players:GetPlayerFromCharacter(current)

            if player then
                return true
            end

            if LocalPlayer.Character and current == LocalPlayer.Character then
                return true
            end
        end

        current = current.Parent
    end

    return false
end

local function isValidPrompt(prompt, part)
    if not prompt or not prompt:IsA("ProximityPrompt") then
        return false
    end

    if not isInWorkspace(prompt) then
        return false
    end

    if not part or not part:IsA("BasePart") or not isInWorkspace(part) then
        return false
    end

    if isPlayerCharacter(prompt) then
        return false
    end

    return true
end

----------------------------------------------------------------
-- LOOT SYSTEM & LOOT ESP LOGIC (BILINGUAL DETECTOR & ADVANCED FILTER)
----------------------------------------------------------------

local LOOT_ESP_NAME = "loot esp"
local LOOT_LABEL_NAME = "loot esp name"
local LOOT_COLOR = "Really red"
local lootEnabled = false

local function getLootPart(model)
    if not model then return nil end
    if model:IsA("BasePart") then return model end
    if model:IsA("Model") then
        if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then
            return model.PrimaryPart
        end
        local candidate = model:FindFirstChildWhichIsA("BasePart", true)
        if candidate then return candidate end
    end
    return nil
end

local function getLootItemName(model)
    if not model then return "Loot Item" end
    
    local guiText = model:FindFirstChildWhichIsA("TextLabel", true)
    if guiText and guiText.Text ~= "" then
        return guiText.Text
    end

    local prompt = model:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt then
        if prompt.ObjectText ~= "" then return prompt.ObjectText end
        if prompt.ActionText ~= "" then return prompt.ActionText end
    end

    local name = model.Name
    if name and name ~= "" and not isGenericName(name) then
        return name
    end

    return "Loot Item"
end

local function isLootItem(obj)
    if not obj then return false end
    if obj:IsA("Model") or obj:IsA("BasePart") then
        if obj:IsDescendantOf(Workspace) then
            local parent = obj.Parent
            if parent and (lower(parent.Name) == "items" or obj:FindFirstChildOfClass("ClickDetector") or obj:FindFirstChildOfClass("ProximityPrompt", true) or parent:FindFirstChild("Items")) then
                if Players:GetPlayerFromCharacter(obj) then return false end
                return getLootPart(obj) ~= nil
            end
        end
    end
    return false
end

local function passesLootFilter(model, itemName, filterKeyword)
    if not filterKeyword or filterKeyword == "" then return true end

    local filterLower = lower(filterKeyword)
    local targetTextName = lower(itemName)
    local modelName = lower(model.Name)

    if string.find(targetTextName, filterLower, 1, true) or string.find(modelName, filterLower, 1, true) then
        return true
    end

    local translated = TRANSLATION_MAP[filterLower]
    if translated then
        if string.find(targetTextName, translated, 1, true) or string.find(modelName, translated, 1, true) then
            return true
        end
    end

    return false
end

local function removeLootESP(model)
    local part = getLootPart(model)
    if not part then return end

    local esp = part:FindFirstChild(LOOT_ESP_NAME)
    if esp then esp:Destroy() end

    local label = part:FindFirstChild(LOOT_LABEL_NAME)
    if label then label:Destroy() end
end

local function createLootESP(model)
    if not lootEnabled then return end
    local itemName = getLootItemName(model)
    
    if not passesLootFilter(model, itemName, lootFilter) then
        removeLootESP(model)
        return
    end

    local part = getLootPart(model)
    if not part or not isInWorkspace(part) then return end

    local existing = part:FindFirstChild(LOOT_ESP_NAME)
    if not existing or not existing:IsA("BoxHandleAdornment") then
        if existing then existing:Destroy() end
        existing = Instance.new("BoxHandleAdornment")
        existing.Name = LOOT_ESP_NAME
        existing.Parent = part
        existing.Adornee = part
        existing.AlwaysOnTop = true
        existing.ZIndex = 0
    end

    existing.Adornee = part
    existing.Size = part.Size
    existing.Transparency = 0.1
    existing.Color = BrickColor.new(LOOT_COLOR)
    existing.Visible = true

    local label = part:FindFirstChild(LOOT_LABEL_NAME)
    if not label or not label:IsA("BillboardGui") then
        if label then label:Destroy() end

        label = Instance.new("BillboardGui")
        label.Name = LOOT_LABEL_NAME
        label.Parent = part
        label.Adornee = part
        label.AlwaysOnTop = true
        label.LightInfluence = 0
        label.Size = UDim2.fromOffset(180, 32)
        label.StudsOffset = Vector3.new(0, math.max(2.8, part.Size.Y * 0.5 + 1), 0)
        label.MaxDistance = 800

        local textLabel = Instance.new("TextLabel")
        textLabel.Name = "Name"
        textLabel.Parent = label
        textLabel.BackgroundTransparency = 1
        textLabel.Size = UDim2.fromScale(1, 1)
        textLabel.Font = Enum.Font.GothamBold
        textLabel.TextSize = 14
        textLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
        textLabel.TextStrokeTransparency = 0.25
        textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
        textLabel.TextXAlignment = Enum.TextXAlignment.Center
        textLabel.TextYAlignment = Enum.TextYAlignment.Center
        textLabel.TextWrapped = true
    end

    local textLabel = label:FindFirstChild("Name")
    if textLabel and textLabel:IsA("TextLabel") then
        textLabel.Text = itemName
    end
end

local function rebuildLootCache()
    table.clear(itpLootCache)
    local seenParts = {}

    for _, obj in ipairs(Workspace:GetDescendants()) do
        if isLootItem(obj) then
            local modelRoot = obj
            if obj:IsA("BasePart") and obj.Parent and obj.Parent:IsA("Model") then
                modelRoot = obj.Parent
            end

            local part = getLootPart(modelRoot)
            if part and not seenParts[part] then
                seenParts[part] = true
                local itemName = getLootItemName(modelRoot)
                local tabKw = tabFilters["LOOT"] or ""
                
                local passTabFilter = passesLootFilter(modelRoot, itemName, tabKw)
                local isBl = tabBlacklists["LOOT"][lower(itemName)] == true or tabBlacklists["LOOT"][lower(modelRoot.Name)] == true

                if not isBl and passTabFilter then
                    table.insert(itpLootCache, {
                        key = modelRoot,
                        part = part,
                        name = itemName
                    })
                end
            end
        end
    end
end

local function scanLootESP()
    lootEnabled = true
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if isLootItem(obj) then
            local modelRoot = obj
            if obj:IsA("BasePart") and obj.Parent and obj.Parent:IsA("Model") then
                modelRoot = obj.Parent
            end
            createLootESP(modelRoot)
        end
    end
end

local function stopLootESP()
    lootEnabled = false
    if connections.loot then
        connections.loot:Disconnect()
        connections.loot = nil
    end
    if connections.lootRemoving then
        connections.lootRemoving:Disconnect()
        connections.lootRemoving = nil
    end

    for _, object in ipairs(game:GetDescendants()) do
        if object:IsA("BoxHandleAdornment") and object.Name == LOOT_ESP_NAME then
            object:Destroy()
        elseif object:IsA("BillboardGui") and object.Name == LOOT_LABEL_NAME then
            object:Destroy()
        end
    end
end

----------------------------------------------------------------
-- DOOR / ITEM CLASSIFICATION & FILTER LOGIC
----------------------------------------------------------------

isDoorPrompt = function(prompt, part)
    if not prompt then
        return false
    end

    if prompt then
        if containsKeyword(prompt.Name, ITEM_PROTECT_KEYWORDS)
        or containsKeyword(prompt.ActionText, ITEM_PROTECT_KEYWORDS)
        or containsKeyword(prompt.ObjectText, ITEM_PROTECT_KEYWORDS) then
            return false
        end
    end

    if part then
        for _, name in ipairs(getNameChain(part)) do
            if containsKeyword(name, ITEM_PROTECT_KEYWORDS) then
                return false
            end
        end
    end

    if containsKeyword(prompt.Name, DOOR_KEYWORDS) then
        return true
    end

    if containsKeyword(prompt.ActionText, DOOR_KEYWORDS)
    or containsKeyword(prompt.ObjectText, DOOR_KEYWORDS) then
        return true
    end

    if part and containsKeyword(part.Name, DOOR_KEYWORDS) then
        return true
    end

    for _, name in ipairs(getNameChain(prompt)) do
        if containsKeyword(name, DOOR_KEYWORDS) then
            return true
        end
    end

    if part then
        local size = part.Size
        if size.Y >= 6 and (size.X >= 2 or size.Z >= 2) and size.Y >= size.X and size.Y >= size.Z then
            return true
        end
    end

    return false
end

local function isContainerPrompt(prompt, part)
    if not prompt then
        return false
    end

    if containsKeyword(prompt.Name, CONTAINER_KEYWORDS) then
        return true
    end

    if containsKeyword(prompt.ActionText, CONTAINER_KEYWORDS)
    or containsKeyword(prompt.ObjectText, CONTAINER_KEYWORDS) then
        return true
    end

    if part and containsKeyword(part.Name, CONTAINER_KEYWORDS) then
        return true
    end

    for _, name in ipairs(getNameChain(prompt)) do
        if containsKeyword(name, CONTAINER_KEYWORDS) then
            return true
        end
    end

    return false
end

local function isItemPrompt(prompt, part)
    if not isValidPrompt(prompt, part) then
        return false
    end

    return not isDoorPrompt(prompt, part)
end

local function isItemMatchingKeyword(tabName, promptOrTouch, part, keyword)
    if not keyword or keyword == "" then return false end

    local textTargets = {}

    if (tabName == "PPESP" or tabName == "DESP") and promptOrTouch then
        table.insert(textTargets, lower(promptOrTouch.Name))
        table.insert(textTargets, lower(promptOrTouch.ActionText))
        table.insert(textTargets, lower(promptOrTouch.ObjectText))
    elseif tabName == "CDESP" and promptOrTouch then
        table.insert(textTargets, lower(promptOrTouch.Name))
    end

    if part then
        table.insert(textTargets, lower(part.Name))
        if part.Parent and part.Parent ~= Workspace then
            table.insert(textTargets, lower(part.Parent.Name))
        end
    end

    for _, target in ipairs(textTargets) do
        if string.find(target, keyword, 1, true) then
            return true
        end
    end

    return false
end

local function isBlacklisted(tabName, promptOrTouch, part)
    local blMap = tabBlacklists[tabName]
    if not blMap or not next(blMap) then return false end

    for kw in pairs(blMap) do
        if isItemMatchingKeyword(tabName, promptOrTouch, part, kw) then
            return true
        end
    end

    return false
end

local function passesFilter(tabName, promptOrTouch, part)
    local kw = tabFilters[tabName]
    if not kw or kw == "" then return true end

    return isItemMatchingKeyword(tabName, promptOrTouch, part, kw)
end

local function rebuildPPESPCache()
    table.clear(itpCache)
    for prompt, part in pairs(proximityPartMap) do
        if prompt and part and isValidPrompt(prompt, part) and not isDoorPrompt(prompt, part) then
            if not isBlacklisted("PPESP", prompt, part) and passesFilter("PPESP", prompt, part) then
                table.insert(itpCache, {
                    key = prompt,
                    part = part,
                    name = getProximityItemName(prompt, part)
                })
            end
        end
    end
end

local function hasOtherLivePromptOnPart(part, exceptPrompt)
    if not part then
        return false
    end

    for prompt, trackedPart in pairs(proximityPartMap) do
        if prompt ~= exceptPrompt
        and trackedPart == part
        and prompt.Parent
        and isInWorkspace(prompt)
        and prompt:IsA("ProximityPrompt") then
            return true
        end
    end

    return false
end

local function clearPartIfUnused(part, exceptPrompt)
    if not part then
        return
    end

    if not hasOtherLivePromptOnPart(part, exceptPrompt) then
        removeESP(part)
    end
end

local function updateProximityESP(prompt)
    if not prompt then
        return
    end

    local part = proximityPartMap[prompt] or getPromptPart(prompt)

    if not part or not isInWorkspace(part) then
        return
    end

    proximityPartMap[prompt] = part

    if isNPCPrompt(prompt) then
        proximityCompleted[prompt] = nil
    end

    if isDoorPrompt(prompt, part) then
        proximityCompleted[prompt] = nil
        clearPartIfUnused(part, prompt)
        return
    end

    if proximityCompleted[prompt] and not isNPCPrompt(prompt) then
        if isInWorkspace(part) then
            if ppespEnabled and passesESPFilter(ppespFilter, prompt, part) then
                createESP(part, PPESP_NAME, PPESP_DONE_COLOR)
            else
                removeESP(part)
            end

            local label = part:FindFirstChild(PPESP_LABEL_NAME)
            if label and label:IsA("BillboardGui") then
                label:Destroy()
            end
        else
            proximityCompleted[prompt] = nil
            clearPartIfUnused(part, prompt)
        end

        return
    end

    if not isValidPrompt(prompt, part) then
        proximityCompleted[prompt] = nil
        clearPartIfUnused(part, prompt)
        return
    end

    if isItemPrompt(prompt, part) then
        if ppespEnabled and passesESPFilter(ppespFilter, prompt, part) then
            createESP(part, PPESP_NAME, PPESP_ITEM_COLOR)
            if not isContainerPrompt(prompt, part) then
                createProximityNameLabel(prompt, part)
            else
                local label = part:FindFirstChild(PPESP_LABEL_NAME)
                if label and label:IsA("BillboardGui") then
                    label:Destroy()
                end
            end
        else
            removeESP(part)
        end
    else
        clearPartIfUnused(part, prompt)
    end
end

local cleanupProximityPrompt

local function getLocalRoot()
    local character = LocalPlayer and LocalPlayer.Character

    if not character then
        return nil
    end

    return character:FindFirstChild("HumanoidRootPart")
        or character:FindFirstChild("Torso")
        or character:FindFirstChild("UpperTorso")
end

local function updateProximityDistance()
    local root = getLocalRoot()

    if not root then
        return
    end

    local rootPosition = root.Position
    local renderDistanceSquared = PPESP_RENDER_DISTANCE * PPESP_RENDER_DISTANCE
    local labelDistanceSquared = PPESP_LABEL_DISTANCE * PPESP_LABEL_DISTANCE

    for prompt, part in pairs(proximityPartMap) do
        if not prompt
        or not prompt.Parent
        or not part
        or not part.Parent
        or not isInWorkspace(prompt)
        or not isInWorkspace(part) then
            cleanupProximityPrompt(prompt)
        else
            local offset = part.Position - rootPosition
            local distanceSquared = offset:Dot(offset)
            local inRange = distanceSquared <= renderDistanceSquared

            if ppespEnabled then
                local esp = part:FindFirstChild(PPESP_NAME)
                if inRange and passesESPFilter(ppespFilter, prompt, part) then
                    if not esp or not esp:IsA("BoxHandleAdornment") then
                        updateProximityESP(prompt)
                        esp = part:FindFirstChild(PPESP_NAME)
                    end

                    if esp and esp:IsA("BoxHandleAdornment") then
                        esp.Visible = true
                    end

                    local label = part:FindFirstChild(PPESP_LABEL_NAME)

                    if label and label:IsA("BillboardGui") then
                        label.MaxDistance = PPESP_LABEL_DISTANCE
                        label.Enabled = distanceSquared <= labelDistanceSquared
                    end
                else
                    removeESP(part)
                end
            else
                removeESP(part)
            end
        end
    end
end

local function startProximityDistanceLoop()
    ppespDistanceLoopToken += 1
    local myToken = ppespDistanceLoopToken

    task.spawn(function()
        while myToken == ppespDistanceLoopToken and next(proximityTracked) do
            updateProximityDistance()
            task.wait(PPESP_DISTANCE_INTERVAL)
        end
    end)
end

local function stopProximityDistanceLoop()
    ppespDistanceLoopToken += 1
end

cleanupProximityPrompt = function(prompt)
    if not prompt then
        return
    end

    local data = proximityTracked[prompt]

    if data then
        for _, connection in pairs(data) do
            if connection then
                connection:Disconnect()
            end
        end
    end

    local part = proximityPartMap[prompt]

    proximityTracked[prompt] = nil
    proximityPartMap[prompt] = nil
    proximityCompleted[prompt] = nil

    clearPartIfUnused(part, prompt)
end

local function addProximityESP(prompt)
    if not prompt or not prompt:IsA("ProximityPrompt") then
        return
    end

    if not isInWorkspace(prompt) then
        return
    end

    if isPlayerCharacter(prompt) then
        return
    end

    local part = getPromptPart(prompt)

    if not part then
        return
    end

    if proximityTracked[prompt] then
        proximityPartMap[prompt] = part
        updateProximityESP(prompt)
        return
    end

    proximityPartMap[prompt] = part

    local ancestryConnection = prompt.AncestryChanged:Connect(function()
        task.defer(function()
            if not proximityTracked[prompt] then
                return
            end

            if not isInWorkspace(prompt) then
                cleanupProximityPrompt(prompt)
                return
            end

            local oldPart = proximityPartMap[prompt]
            local newPart = getPromptPart(prompt)

            if newPart ~= oldPart then
                proximityPartMap[prompt] = newPart

                clearPartIfUnused(oldPart, prompt)

                local tracked = proximityTracked[prompt]

                if tracked then
                    if tracked.partAncestry then
                        tracked.partAncestry:Disconnect()
                    end

                    if tracked.partDestroying then
                        tracked.partDestroying:Disconnect()
                    end

                    if newPart then
                        tracked.partAncestry = newPart.AncestryChanged:Connect(function()
                            task.defer(function()
                                if not proximityTracked[prompt] then
                                    return
                                end

                                if not isInWorkspace(newPart) then
                                    cleanupProximityPrompt(prompt)
                                else
                                    updateProximityESP(prompt)
                                end
                            end)
                        end)

                        tracked.partDestroying = newPart.Destroying:Connect(function()
                            cleanupProximityPrompt(prompt)
                        end)
                    end
                end
            end

            updateProximityESP(prompt)
        end)
    end)

    local destroyingConnection = prompt.Destroying:Connect(function()
        cleanupProximityPrompt(prompt)
    end)

    local partAncestryConnection = part.AncestryChanged:Connect(function()
        task.defer(function()
            if not proximityTracked[prompt] then
                return
            end

            if not isInWorkspace(part) then
                cleanupProximityPrompt(prompt)
            else
                updateProximityESP(prompt)
            end
        end)
    end)

    local partDestroyingConnection = part.Destroying:Connect(function()
        cleanupProximityPrompt(prompt)
    end)

    local enabledConnection = prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
        updateProximityESP(prompt)
    end)

    local triggeredConnection = prompt.Triggered:Connect(function()
        markPromptCompleted(prompt)
    end)

    local distanceConnection = prompt:GetPropertyChangedSignal("MaxActivationDistance"):Connect(function()
        updateProximityESP(prompt)
    end)

    local actionConnection = prompt:GetPropertyChangedSignal("ActionText"):Connect(function()
        updateProximityESP(prompt)
    end)

    local objectConnection = prompt:GetPropertyChangedSignal("ObjectText"):Connect(function()
        updateProximityESP(prompt)
    end)

    proximityTracked[prompt] = {
        ancestry = ancestryConnection,
        destroying = destroyingConnection,
        partAncestry = partAncestryConnection,
        partDestroying = partDestroyingConnection,
        enabled = enabledConnection,
        distance = distanceConnection,
        action = actionConnection,
        object = objectConnection,
        triggered = triggeredConnection
    }

    updateProximityESP(prompt)
end

markPromptCompleted = function(prompt)
    if not prompt then
        return
    end

    if isNPCPrompt(prompt) then
        return
    end

    local part = proximityPartMap[prompt] or getPromptPart(prompt)

    if part and isDoorPrompt(prompt, part) then
        proximityCompleted[prompt] = nil
        return
    end

    if not prompt.Parent then
        proximityCompleted[prompt] = nil
        return
    end

    proximityCompleted[prompt] = true

    if part and isInWorkspace(part) and ppespEnabled and passesESPFilter(ppespFilter, prompt, part) then
        createESP(part, PPESP_NAME, PPESP_DONE_COLOR)

        local label = part:FindFirstChild(PPESP_LABEL_NAME)

        if label and label:IsA("BillboardGui") then
            label:Destroy()
        end
    end
end

----------------------------------------------------------------
-- DOOR ESP (DESP) & BACKEND TRACKING
----------------------------------------------------------------

local doorPromptMap = {}

local function removeDoorESP(part)
    if not part then return end

    local esp = part:FindFirstChild(DESP_NAME)
    if esp and esp:IsA("BoxHandleAdornment") then
        esp:Destroy()
    end

    local label = part:FindFirstChild(DESP_LABEL_NAME)
    if label and label:IsA("BillboardGui") then
        label:Destroy()
    end
end

local function createDoorESP(prompt, part)
    if not despEnabled
    or not isValidPrompt(prompt, part)
    or isNPCPrompt(prompt)
    or not isDoorPrompt(prompt, part)
    or not passesESPFilter(despFilter, prompt, part) then
        removeDoorESP(part)
        return
    end

    local esp = part:FindFirstChild(DESP_NAME)

    if not esp or not esp:IsA("BoxHandleAdornment") then
        if esp then esp:Destroy() end
        esp = Instance.new("BoxHandleAdornment")
        esp.Name = DESP_NAME
        esp.Parent = part
        esp.Adornee = part
        esp.AlwaysOnTop = true
        esp.ZIndex = 0
    end

    esp.Adornee = part
    esp.Size = part.Size
    esp.Transparency = 0.1
    esp.Color = BrickColor.new(PPESP_DOOR_COLOR)
    esp.Visible = true

    local label = part:FindFirstChild(DESP_LABEL_NAME)
    if not label or not label:IsA("BillboardGui") then
        if label then label:Destroy() end

        label = Instance.new("BillboardGui")
        label.Name = DESP_LABEL_NAME
        label.Parent = part
        label.Adornee = part
        label.AlwaysOnTop = true
        label.LightInfluence = 0
        label.Size = UDim2.fromOffset(180, 32)
        label.StudsOffset = Vector3.new(0, math.max(2.8, part.Size.Y * 0.5 + 1), 0)
        label.MaxDistance = PPESP_RENDER_DISTANCE

        local textLabel = Instance.new("TextLabel")
        textLabel.Name = "Name"
        textLabel.Parent = label
        textLabel.BackgroundTransparency = 1
        textLabel.Size = UDim2.fromScale(1, 1)
        textLabel.Font = Enum.Font.GothamBold
        textLabel.TextSize = 14
        textLabel.TextColor3 = Color3.new(0.35, 0.75, 1)
        textLabel.TextStrokeTransparency = 0.25
        textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
        textLabel.TextXAlignment = Enum.TextXAlignment.Center
        textLabel.TextYAlignment = Enum.TextYAlignment.Center
        textLabel.TextWrapped = true
    end

    local textLabel = label:FindFirstChild("Name")
    if textLabel and textLabel:IsA("TextLabel") then
        textLabel.Text = getProximityItemName(prompt, part)
    end
end

local function cleanupDoorPrompt(prompt)
    local data = despTracked[prompt]
    if not data then return end

    for _, connection in pairs(data) do
        if typeof(connection) == "RBXScriptConnection" then
            connection:Disconnect()
        end
    end

    removeDoorESP(data.part)
    despTracked[prompt] = nil
end

local function trackDoorPrompt(prompt)
    if not prompt
    or not prompt:IsA("ProximityPrompt")
    or not isInWorkspace(prompt)
    or isPlayerCharacter(prompt) then
        return
    end

    local part = getPromptPart(prompt)
    if not part or not isDoorPrompt(prompt, part) then
        return
    end

    doorPromptMap[prompt] = part

    if not despEnabled then return end

    if despTracked[prompt] then
        despTracked[prompt].part = part
        createDoorESP(prompt, part)
        return
    end

    local data = {part = part}

    data.ancestry = prompt.AncestryChanged:Connect(function()
        task.defer(function()
            if not despTracked[prompt] then return end
            local newPart = getPromptPart(prompt)
            if not isInWorkspace(prompt) or not newPart then
                cleanupDoorPrompt(prompt)
                return
            end
            if newPart ~= despTracked[prompt].part then
                removeDoorESP(despTracked[prompt].part)
                despTracked[prompt].part = newPart
            end
            if isDoorPrompt(prompt, newPart) then
                createDoorESP(prompt, newPart)
            else
                cleanupDoorPrompt(prompt)
            end
        end)
    end)

    data.destroying = prompt.Destroying:Connect(function()
        cleanupDoorPrompt(prompt)
    end)

    data.enabled = prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
        if not despEnabled then return end
        createDoorESP(prompt, despTracked[prompt] and despTracked[prompt].part or part)
    end)

    data.action = prompt:GetPropertyChangedSignal("ActionText"):Connect(function()
        local current = despTracked[prompt]
        if current and isDoorPrompt(prompt, current.part) then
            createDoorESP(prompt, current.part)
        else
            cleanupDoorPrompt(prompt)
        end
    end)

    data.object = prompt:GetPropertyChangedSignal("ObjectText"):Connect(function()
        local current = despTracked[prompt]
        if current and isDoorPrompt(prompt, current.part) then
            createDoorESP(prompt, current.part)
        else
            cleanupDoorPrompt(prompt)
        end
    end)

    data.partAncestry = part.AncestryChanged:Connect(function()
        task.defer(function()
            local current = despTracked[prompt]
            if not current then return end
            if not isInWorkspace(current.part) then
                cleanupDoorPrompt(prompt)
            else
                createDoorESP(prompt, current.part)
            end
        end)
    end)

    data.partDestroying = part.Destroying:Connect(function()
        cleanupDoorPrompt(prompt)
    end)

    despTracked[prompt] = data
    createDoorESP(prompt, part)
end

local function scanDoorESP()
    despEnabled = true

    for _, object in ipairs(Workspace:GetDescendants()) do
        if object:IsA("ProximityPrompt") then
            trackDoorPrompt(object)
        end
    end

    if connections.door then connections.door:Disconnect() end
    if connections.doorRemoving then connections.doorRemoving:Disconnect() end

    connections.door = Workspace.DescendantAdded:Connect(function(object)
        if despEnabled and object:IsA("ProximityPrompt") then
            task.defer(function()
                trackDoorPrompt(object)
            end)
        end
    end)

    connections.doorRemoving = Workspace.DescendantRemoving:Connect(function(object)
        if object:IsA("ProximityPrompt") then
            cleanupDoorPrompt(object)
        end
    end)
end

local function stopDoorESP()
    despEnabled = false

    if connections.door then
        connections.door:Disconnect()
        connections.door = nil
    end
    if connections.doorRemoving then
        connections.doorRemoving:Disconnect()
        connections.doorRemoving = nil
    end

    for prompt in pairs(despTracked) do
        cleanupDoorPrompt(prompt)
    end
    table.clear(despTracked)

    for _, object in ipairs(game:GetDescendants()) do
        if object:IsA("BoxHandleAdornment") and object.Name == DESP_NAME then
            object:Destroy()
        elseif object:IsA("BillboardGui") and object.Name == DESP_LABEL_NAME then
            object:Destroy()
        end
    end
end

local function scanProximityESP()
    local descendants = Workspace:GetDescendants()
    local processed = 0

    for _, object in ipairs(descendants) do
        if object:IsA("ProximityPrompt") then
            addProximityESP(object)
        end

        processed += 1

        if processed >= 150 then
            processed = 0
            task.wait()
        end
    end

    updateProximityDistance()
    startProximityDistanceLoop()
end

local function stopProximityESP()
    stopProximityDistanceLoop()

    if connections.proximity then
        connections.proximity:Disconnect()
        connections.proximity = nil
    end

    if connections.proximityRemoving then
        connections.proximityRemoving:Disconnect()
        connections.proximityRemoving = nil
    end

    for prompt in pairs(proximityTracked) do
        cleanupProximityPrompt(prompt)
    end

    table.clear(proximityTracked)
    table.clear(proximityPartMap)
    table.clear(proximityCompleted)
    table.clear(itpCache)

    for _, object in ipairs(game:GetDescendants()) do
        if (object:IsA("BoxHandleAdornment") and object.Name == PPESP_NAME)
        or (object:IsA("BillboardGui") and object.Name == PPESP_LABEL_NAME) then
            object:Destroy()
        end
    end
end

----------------------------------------------------------------
-- CLICK DETECTOR ESP (CDESP) & BACKEND TRACKING
----------------------------------------------------------------

local CDESP_NAME = "clickdetector esp"
local CDESP_LABEL_NAME = "clickdetector esp name"
local CDESP_COLOR = "Bright yellow"
local cdespEnabled = false
local clickDetectorMap = {}

local function getClickItemName(detector, part)
    if not detector then
        return "Click Item"
    end

    if part then
        local partName = tostring(part.Name or "")

        if partName ~= "" and not isGenericName(partName) then
            return partName
        end

        local current = part.Parent

        while current and current ~= Workspace do
            local currentName = tostring(current.Name or "")
            if currentName ~= "" and not isGenericName(currentName) and currentName ~= "_INTERACTABLES" then
                return currentName
            end

            current = current.Parent
        end
    end

    return "Click Item"
end

local function createClickNameLabel(detector, part)
    if not part or not part:IsA("BasePart") then
        return nil
    end

    local label = part:FindFirstChild(CDESP_LABEL_NAME)

    if not label or not label:IsA("BillboardGui") then
        if label then
            label:Destroy()
        end

        label = Instance.new("BillboardGui")
        label.Name = CDESP_LABEL_NAME
        label.Parent = part
        label.Adornee = part
        label.AlwaysOnTop = true
        label.LightInfluence = 0
        label.Size = UDim2.fromOffset(180, 32)
        label.StudsOffset = Vector3.new(0, 2.8, 0)
        label.MaxDistance = 800
        label.Enabled = true

        local textLabel = Instance.new("TextLabel")
        textLabel.Name = "Name"
        textLabel.Parent = label
        textLabel.BackgroundTransparency = 1
        textLabel.Size = UDim2.fromScale(1, 1)
        textLabel.Font = Enum.Font.GothamBold
        textLabel.TextSize = 14
        textLabel.TextColor3 = Color3.new(1, 1, 1)
        textLabel.TextStrokeTransparency = 0.25
        textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
        textLabel.TextXAlignment = Enum.TextXAlignment.Center
        textLabel.TextYAlignment = Enum.TextYAlignment.Center
        textLabel.TextWrapped = true
    end

    local textLabel = label:FindFirstChild("Name")

    if textLabel and textLabel:IsA("TextLabel") then
        textLabel.Text = getClickItemName(detector, part)
    end

    return label
end

local function addClickESP(detector)
    if not detector or not detector:IsA("ClickDetector") then
        return
    end

    local parent = detector.Parent

    if parent and parent:IsA("BasePart") then
        if not passesESPFilter(cdespFilter, detector, parent) then
            local esp = parent:FindFirstChild(CDESP_NAME)
            if esp then esp:Destroy() end
            local lbl = parent:FindFirstChild(CDESP_LABEL_NAME)
            if lbl then lbl:Destroy() end
            return
        end

        if parent:FindFirstChildOfClass("ProximityPrompt", true) or parent:FindFirstAncestorWhichIsA("Model") and parent:FindFirstAncestorWhichIsA("Model"):FindFirstChildOfClass("ProximityPrompt", true) then
            return
        end

        clickDetectorMap[detector] = parent

        createESP(parent, CDESP_NAME, CDESP_COLOR)
        createClickNameLabel(detector, parent)
    end
end

local function scanClickESP()
    cdespEnabled = true
    for _, object in ipairs(Workspace:GetDescendants()) do
        if object:IsA("ClickDetector") then
            addClickESP(object)
        end
    end
end

local function stopClickESP()
    cdespEnabled = false
    if connections.click then
        connections.click:Disconnect()
        connections.click = nil
    end

    table.clear(clickDetectorMap)

    for _, object in ipairs(game:GetDescendants()) do
        if object:IsA("BoxHandleAdornment")
        and object.Name == CDESP_NAME then
            object:Destroy()
        elseif object:IsA("BillboardGui")
        and object.Name == CDESP_LABEL_NAME then
            object:Destroy()
        end
    end
end

----------------------------------------------------------------
-- TOUCH ESP LOGIC: ITESP (Item) vs TESP (Trigger)
----------------------------------------------------------------

local ITESP_ESP_NAME = "itemtouchesp"
local ITESP_LABEL_NAME = "itemtouchesp name"

local TESP_ESP_NAME = "touchtriggeresp"
local TESP_LABEL_NAME = "touchtriggeresp name"

local itespEnabled = false
local touchItemMap = {}

local TOUCH_TRIGGER_KEYWORDS = {
    "trigger", "jumpscare", "checkpoint", "cp", "scene", "event", 
    "ghost", "intro", "teleport", "damage", "kill", "objshowpart"
}

local function isTouchInteraction(object)
    if not object then
        return false
    end

    local className = object.ClassName

    return className == "TouchTransmitter"
        or className == "TouchInterest"
        or object:IsA("TouchTransmitter")
end

local function getTouchPart(touch)
    if not touch then
        return nil
    end

    if touch:IsA("BasePart") then
        return touch
    end

    local parent = touch.Parent

    if parent and parent:IsA("BasePart") then
        return parent
    end

    local current = parent

    while current and current ~= Workspace do
        if current:IsA("BasePart") then
            return current
        end
        current = current.Parent
    end

    return nil
end

local function isTriggerPart(part)
    if not part then return false end

    local current = part
    while current and current ~= Workspace do
        if containsKeyword(current.Name, TOUCH_TRIGGER_KEYWORDS) then
            return true
        end
        current = current.Parent
    end
    return false
end

local function isPlayerCharacterPart(part)
    if not part then return false end
    local current = part
    while current and current ~= Workspace do
        if current:IsA("Model") then
            if Players:GetPlayerFromCharacter(current) then
                return true
            end
            if LocalPlayer.Character and current == LocalPlayer.Character then
                return true
            end
        end
        current = current.Parent
    end
    return false
end

local function getTouchItemName(part)
    if not part then
        return "Touch Item"
    end

    local partName = tostring(part.Name or "")

    if partName ~= "" and not isGenericName(partName) then
        return partName
    end

    local current = part.Parent

    while current and current ~= Workspace do
        local currentName = tostring(current.Name or "")
        if currentName ~= "" and not isGenericName(currentName) and currentName ~= "_INTERACTABLES" then
            return currentName
        end

        current = current.Parent
    end

    return "Touch Item"
end

local function createItemTouchNameLabel(part)
    if not part or not part:IsA("BasePart") then
        return nil
    end

    local label = part:FindFirstChild(ITESP_LABEL_NAME)

    if not label or not label:IsA("BillboardGui") then
        if label then label:Destroy() end

        label = Instance.new("BillboardGui")
        label.Name = ITESP_LABEL_NAME
        label.Parent = part
        label.Adornee = part
        label.AlwaysOnTop = true
        label.LightInfluence = 0
        label.Size = UDim2.fromOffset(180, 32)
        label.StudsOffset = Vector3.new(0, math.max(2.8, part.Size.Y * 0.5 + 1.5), 0)
        label.MaxDistance = 250

        local textLabel = Instance.new("TextLabel")
        textLabel.Name = "Name"
        textLabel.Parent = label
        textLabel.BackgroundTransparency = 1
        textLabel.Size = UDim2.fromScale(1, 1)
        textLabel.Font = Enum.Font.GothamBold
        textLabel.TextSize = 14
        textLabel.TextColor3 = Color3.new(0, 1, 0)
        textLabel.TextStrokeTransparency = 0.25
        textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
        textLabel.TextXAlignment = Enum.TextXAlignment.Center
        textLabel.TextYAlignment = Enum.TextYAlignment.Center
        textLabel.TextWrapped = true
    end

    label.Adornee = part
    local textLabel = label:FindFirstChild("Name")
    if textLabel and textLabel:IsA("TextLabel") then
        textLabel.Text = getTouchItemName(part)
    end

    return label
end

local function createItemTouchESP(part)
    if not part or not part:IsA("BasePart") or not isInWorkspace(part) then
        return nil
    end

    if not passesESPFilter(itespFilter, nil, part) then
        local esp = part:FindFirstChild(ITESP_ESP_NAME)
        if esp then esp:Destroy() end
        local lbl = part:FindFirstChild(ITESP_LABEL_NAME)
        if lbl then lbl:Destroy() end
        return nil
    end

    local esp = part:FindFirstChild(ITESP_ESP_NAME)
    if not esp or not esp:IsA("BoxHandleAdornment") then
        if esp then esp:Destroy() end

        esp = Instance.new("BoxHandleAdornment")
        esp.Name = ITESP_ESP_NAME
        esp.Parent = part
        esp.Adornee = part
        esp.AlwaysOnTop = true
        esp.ZIndex = 0
    end

    esp.Adornee = part
    esp.Size = part.Size
    esp.Transparency = 0.1
    esp.Color = BrickColor.new("Bright green")

    createItemTouchNameLabel(part)
    return esp
end

local function scanItemTouchESP()
    itespEnabled = true
    local seen = {}
    for _, object in ipairs(Workspace:GetDescendants()) do
        if isTouchInteraction(object) then
            local part = getTouchPart(object)
            if part and not seen[part] then
                seen[part] = true
                if not isTriggerPart(part) and not isPlayerCharacterPart(part) then
                    touchItemMap[object] = part
                    createItemTouchESP(part)
                end
            end
        end
    end
end

local function stopItemTouchESP()
    itespEnabled = false
    if connections.touchItem then
        connections.touchItem:Disconnect()
        connections.touchItem = nil
    end

    table.clear(touchItemMap)

    for _, object in ipairs(game:GetDescendants()) do
        if object:IsA("BoxHandleAdornment") and object.Name == ITESP_ESP_NAME then
            object:Destroy()
        elseif object:IsA("BillboardGui") and object.Name == ITESP_LABEL_NAME then
            object:Destroy()
        end
    end
end

local function createTriggerTouchNameLabel(part)
    if not part or not part:IsA("BasePart") then
        return nil
    end

    local label = part:FindFirstChild(TESP_LABEL_NAME)

    if not label or not label:IsA("BillboardGui") then
        if label then label:Destroy() end

        label = Instance.new("BillboardGui")
        label.Name = TESP_LABEL_NAME
        label.Parent = part
        label.Adornee = part
        label.AlwaysOnTop = true
        label.LightInfluence = 0
        label.Size = UDim2.fromOffset(180, 32)
        label.StudsOffset = Vector3.new(0, math.max(2.8, part.Size.Y * 0.5 + 1.5), 0)
        label.MaxDistance = 250

        local textLabel = Instance.new("TextLabel")
        textLabel.Name = "Name"
        textLabel.Parent = label
        textLabel.BackgroundTransparency = 1
        textLabel.Size = UDim2.fromScale(1, 1)
        textLabel.Font = Enum.Font.GothamBold
        textLabel.TextSize = 14
        textLabel.TextColor3 = Color3.new(1, 1, 0)
        textLabel.TextStrokeTransparency = 0.25
        textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
        textLabel.TextXAlignment = Enum.TextXAlignment.Center
        textLabel.TextYAlignment = Enum.TextYAlignment.Center
        textLabel.TextWrapped = true
    end

    label.Adornee = part
    local textLabel = label:FindFirstChild("Name")
    if textLabel and textLabel:IsA("TextLabel") then
        textLabel.Text = getTouchItemName(part)
    end

    return label
end

local function createTriggerTouchESP(part)
    if not part or not part:IsA("BasePart") or not isInWorkspace(part) then
        return nil
    end

    local esp = part:FindFirstChild(TESP_ESP_NAME)
    if not esp or not esp:IsA("BoxHandleAdornment") then
        if esp then esp:Destroy() end

        esp = Instance.new("BoxHandleAdornment")
        esp.Name = TESP_ESP_NAME
        esp.Parent = part
        esp.Adornee = part
        esp.AlwaysOnTop = true
        esp.ZIndex = 0
    end

    esp.Adornee = part
    esp.Size = part.Size
    esp.Transparency = 0.1
    esp.Color = BrickColor.new("New Yeller")

    createTriggerTouchNameLabel(part)
    return esp
end

local function stopTriggerTouchESP()
    if connections.touchTrigger then
        connections.touchTrigger:Disconnect()
        connections.touchTrigger = nil
    end

    for _, object in ipairs(game:GetDescendants()) do
        if object:IsA("BoxHandleAdornment") and object.Name == TESP_ESP_NAME then
            object:Destroy()
        elseif object:IsA("BillboardGui") and object.Name == TESP_LABEL_NAME then
            object:Destroy()
        end
    end
end

----------------------------------------------------------------
-- ITEM TELEPORT (ITP) WINDOW, POPUP MODAL & 6 SCROLLABLE TABS
----------------------------------------------------------------

local itpGui = nil
local itpActive = false
local currentTab = "PPESP"
local MAX_DISPLAY_ITEMS = 50

-- Modal Popup Filter/Blacklist Context-Aware
local function showFilterPopup()
    if not itpGui or currentTab == "BLACKLIST" then return end

    local existingPopup = itpGui:FindFirstChild("FilterPopupModal")
    if existingPopup then existingPopup:Destroy() end

    local modalOverlay = Instance.new("TextButton")
    modalOverlay.Name = "FilterPopupModal"
    modalOverlay.Size = UDim2.new(1, 0, 1, 0)
    modalOverlay.Position = UDim2.new(0, 0, 0, 0)
    modalOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    modalOverlay.BackgroundTransparency = 0.5
    modalOverlay.Text = ""
    modalOverlay.AutoButtonColor = false
    modalOverlay.Parent = itpGui

    local popupFrame = Instance.new("Frame")
    popupFrame.Size = UDim2.new(0, 250, 0, 135)
    popupFrame.Position = UDim2.new(0.5, -125, 0.5, -67)
    popupFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    popupFrame.BorderSizePixel = 0
    popupFrame.Parent = modalOverlay
    Instance.new("UICorner", popupFrame).CornerRadius = UDim.new(0, 6)

    local popupTitle = Instance.new("TextLabel")
    popupTitle.Size = UDim2.new(1, -30, 0, 30)
    popupTitle.Position = UDim2.new(0, 10, 0, 0)
    popupTitle.BackgroundTransparency = 1
    popupTitle.Font = Enum.Font.GothamBold
    popupTitle.Text = "Filter (" .. currentTab .. ")"
    popupTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    popupTitle.TextSize = 12
    popupTitle.TextXAlignment = Enum.TextXAlignment.Left
    popupTitle.Parent = popupFrame

    local closePopupBtn = Instance.new("TextButton")
    closePopupBtn.Size = UDim2.new(0, 20, 0, 20)
    closePopupBtn.Position = UDim2.new(1, -25, 0, 5)
    closePopupBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closePopupBtn.BorderSizePixel = 0
    closePopupBtn.Font = Enum.Font.GothamBold
    closePopupBtn.Text = "X"
    closePopupBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closePopupBtn.TextSize = 11
    closePopupBtn.Parent = popupFrame
    Instance.new("UICorner", closePopupBtn).CornerRadius = UDim.new(0, 4)

    local textBox = Instance.new("TextBox")
    textBox.Size = UDim2.new(1, -20, 0, 30)
    textBox.Position = UDim2.new(0, 10, 0, 38)
    textBox.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    textBox.BorderSizePixel = 0
    textBox.Font = Enum.Font.Gotham
    textBox.Text = tabFilters[currentTab] or ""
    textBox.PlaceholderText = "Ketik keyword (misal: telur / egg)..."
    textBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    textBox.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
    textBox.TextSize = 11
    textBox.ClearTextOnFocus = false
    textBox.Parent = popupFrame
    Instance.new("UICorner", textBox).CornerRadius = UDim.new(0, 4)

    local btnContainer = Instance.new("Frame")
    btnContainer.Size = UDim2.new(1, -20, 0, 30)
    btnContainer.Position = UDim2.new(0, 10, 0, 85)
    btnContainer.BackgroundTransparency = 1
    btnContainer.Parent = popupFrame

    local blacklistBtn = Instance.new("TextButton")
    blacklistBtn.Size = UDim2.new(0.48, 0, 1, 0)
    blacklistBtn.Position = UDim2.new(0, 0, 0, 0)
    blacklistBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
    blacklistBtn.Font = Enum.Font.GothamBold
    blacklistBtn.Text = "Blacklist"
    blacklistBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    blacklistBtn.TextSize = 11
    blacklistBtn.Parent = btnContainer
    Instance.new("UICorner", blacklistBtn).CornerRadius = UDim.new(0, 4)

    local filterBtn = Instance.new("TextButton")
    filterBtn.Size = UDim2.new(0.48, 0, 1, 0)
    filterBtn.Position = UDim2.new(0.52, 0, 0, 0)
    filterBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 90)
    filterBtn.Font = Enum.Font.GothamBold
    filterBtn.Text = "Filter"
    filterBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    filterBtn.TextSize = 11
    filterBtn.Parent = btnContainer
    Instance.new("UICorner", filterBtn).CornerRadius = UDim.new(0, 4)

    closePopupBtn.MouseButton1Click:Connect(function()
        modalOverlay:Destroy()
    end)

    blacklistBtn.MouseButton1Click:Connect(function()
        local kw = lower(textBox.Text)
        if kw ~= "" then
            tabBlacklists[currentTab][kw] = true
            if currentTab == "PPESP" then rebuildPPESPCache()
            elseif currentTab == "ITESP" then rebuildITESPCache()
            elseif currentTab == "CDESP" then rebuildCDESPCache()
            elseif currentTab == "LOOT" then rebuildLootCache() end
        end
        modalOverlay:Destroy()
    end)

    filterBtn.MouseButton1Click:Connect(function()
        tabFilters[currentTab] = lower(textBox.Text)
        if currentTab == "PPESP" then rebuildPPESPCache()
        elseif currentTab == "ITESP" then rebuildITESPCache()
        elseif currentTab == "CDESP" then rebuildCDESPCache()
        elseif currentTab == "LOOT" then rebuildLootCache() end
        modalOverlay:Destroy()
    end)
end

-- Fungsi Rebuild Cache ITESP Independen untuk ITP
local function rebuildITESPCache()
    table.clear(itpTouchCache)
    local seen = {}
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if isTouchInteraction(obj) then
            local part = getTouchPart(obj)
            if part and isInWorkspace(part) and not seen[part] then
                seen[part] = true
                if not isTriggerPart(part) and not isPlayerCharacterPart(part) then
                    if not isBlacklisted("ITESP", obj, part) and passesFilter("ITESP", obj, part) then
                        table.insert(itpTouchCache, {
                            key = obj,
                            part = part,
                            name = getTouchItemName(part)
                        })
                    end
                end
            end
        end
    end
end

-- Fungsi Rebuild Cache CDESP Independen untuk ITP
local function rebuildCDESPCache()
    table.clear(itpClickCache)
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ClickDetector") then
            local parent = obj.Parent
            if parent and parent:IsA("BasePart") and isInWorkspace(parent) then
                local hasPrompt = parent:FindFirstChildOfClass("ProximityPrompt", true) 
                    or (parent:FindFirstAncestorWhichIsA("Model") and parent:FindFirstAncestorWhichIsA("Model"):FindFirstChildOfClass("ProximityPrompt", true))

                if not hasPrompt then
                    if not isBlacklisted("CDESP", obj, parent) and passesFilter("CDESP", obj, parent) then
                        table.insert(itpClickCache, {
                            key = obj,
                            part = parent,
                            name = getClickItemName(obj, parent)
                        })
                    end
                end
            end
        end
    end
end

local function scanAndFetchAllPrompts()
    table.clear(doorPromptMap)
    table.clear(proximityPartMap)

    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            local part = getPromptPart(obj)
            if part and isValidPrompt(obj, part) then
                if isDoorPrompt(obj, part) then
                    doorPromptMap[obj] = part
                else
                    proximityPartMap[obj] = part
                end
            end
        end
    end
    rebuildPPESPCache()
    rebuildITESPCache()
    rebuildCDESPCache()
    rebuildLootCache()
end

local function toggleITP()
    if itpActive then
        if itpGui then
            itpGui:Destroy()
            itpGui = nil
        end
        if connections.itp then
            connections.itp:Disconnect()
            connections.itp = nil
        end
        if connections.itpAdded then connections.itpAdded:Disconnect() connections.itpAdded = nil end
        if connections.itpRemoving then connections.itpRemoving:Disconnect() connections.itpRemoving = nil end

        itpActive = false
        table.clear(itpCache)
        table.clear(itpTouchCache)
        table.clear(itpClickCache)
        table.clear(itpLootCache)
        return
    end

    itpActive = true

    scanAndFetchAllPrompts()

    if connections.itpAdded then connections.itpAdded:Disconnect() end
    connections.itpAdded = Workspace.DescendantAdded:Connect(function(object)
        if not itpActive then return end
        task.defer(function()
            if object:IsA("ProximityPrompt") then
                local part = getPromptPart(object)
                if part and isValidPrompt(object, part) then
                    if isDoorPrompt(object, part) then
                        doorPromptMap[object] = part
                    else
                        proximityPartMap[object] = part
                        rebuildPPESPCache()
                    end
                end
            elseif object:IsA("ClickDetector") then
                rebuildCDESPCache()
            elseif isTouchInteraction(object) then
                rebuildITESPCache()
            elseif isLootItem(object) then
                rebuildLootCache()
            end
        end)
    end)

    if connections.itpRemoving then connections.itpRemoving:Disconnect() end
    connections.itpRemoving = Workspace.DescendantRemoving:Connect(function(object)
        if object:IsA("ProximityPrompt") then
            proximityPartMap[object] = nil
            doorPromptMap[object] = nil
            proximityTracked[object] = nil
            rebuildPPESPCache()
        elseif object:IsA("ClickDetector") then
            rebuildCDESPCache()
        elseif isTouchInteraction(object) then
            rebuildITESPCache()
        elseif isLootItem(object) then
            rebuildLootCache()
        end
    end)

    itpGui = Instance.new("ScreenGui")
    itpGui.Name = "InfiniteYield_ITP"
    itpGui.ResetOnSpawn = false
    pcall(function() itpGui.Parent = CoreGui end)
    if not itpGui.Parent then itpGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 300, 0, 310)
    mainFrame.Position = UDim2.new(0.5, -150, 0.5, -155)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 25, 32)
    mainFrame.BackgroundTransparency = 0.25
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = false
    mainFrame.Parent = itpGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = mainFrame

    -- Penambahan UIGradient mirip MasterWindow & Waypoint
    local itpGradient = Instance.new("UIGradient")
    itpGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.0, Color3.fromRGB(28, 38, 52)),
        ColorSequenceKeypoint.new(1.0, Color3.fromRGB(15, 20, 28))
    })
    itpGradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0.0, 0.15),
        NumberSequenceKeypoint.new(1.0, 0.35)
    })
    itpGradient.Rotation = 45
    itpGradient.Parent = mainFrame

    -- TopBar
    local topBar = Instance.new("Frame")
    topBar.Name = "TopBar"
    topBar.Size = UDim2.new(1, 0, 0, 30)
    topBar.BackgroundColor3 = Color3.fromRGB(35, 45, 60)
    topBar.BackgroundTransparency = 0.3
    topBar.BorderSizePixel = 0
    topBar.Parent = mainFrame

    local topCorner = Instance.new("UICorner")
    topCorner.CornerRadius = UDim.new(0, 6)
    topCorner.Parent = topBar

    local topCover = Instance.new("Frame")
    topCover.Size = UDim2.new(1, 0, 0, 6)
    topCover.Position = UDim2.new(0, 0, 1, -6)
    topCover.BackgroundColor3 = Color3.fromRGB(35, 45, 60)
    topCover.BackgroundTransparency = 0.3
    topCover.BorderSizePixel = 0
    topCover.Parent = topBar

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -125, 1, 0)
    titleLabel.Position = UDim2.new(0, 8, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Text = "Item Teleport (ITP)"
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.TextSize = 13
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = topBar

    -- Only the empty title area is draggable; the control buttons remain independent.
    local dragArea = Instance.new("Frame")
    dragArea.Name = "DragArea"
    dragArea.Size = UDim2.new(1, -108, 1, 0)
    dragArea.BackgroundTransparency = 1
    dragArea.Active = true
    dragArea.ZIndex = 2
    dragArea.Parent = topBar

    local dragActionName = "TryoITPWindowDrag"
    local dragging, dragStart, frameStart = false, nil, nil
    dragArea.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            frameStart = mainFrame.Position
            ContextActionService:BindActionAtPriority(dragActionName, function()
                return Enum.ContextActionResult.Sink
            end, false, 3000, Enum.UserInputType.MouseButton1, Enum.UserInputType.Touch)
        end
    end)
    local dragEndedConnection = UserInputService.InputEnded:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch) then
            dragging = false
            ContextActionService:UnbindAction(dragActionName)
        end
    end)
    local dragMovedConnection = UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(
                frameStart.X.Scale, frameStart.X.Offset + delta.X,
                frameStart.Y.Scale, frameStart.Y.Offset + delta.Y
            )
        end
    end)
    itpGui.Destroying:Connect(function()
        dragging = false
        ContextActionService:UnbindAction(dragActionName)
        dragEndedConnection:Disconnect()
        dragMovedConnection:Disconnect()
    end)

    local btnSize = 20
    local btnY = 5

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, btnSize, 0, btnSize)
    closeBtn.Position = UDim2.new(1, -25, 0, btnY)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeBtn.BorderSizePixel = 0
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextSize = 11
    closeBtn.Parent = topBar
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 4)

    local minBtn = Instance.new("TextButton")
    minBtn.Size = UDim2.new(0, btnSize, 0, btnSize)
    minBtn.Position = UDim2.new(1, -50, 0, btnY)
    minBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
    minBtn.BorderSizePixel = 0
    minBtn.Font = Enum.Font.GothamBold
    minBtn.Text = "-"
    minBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    minBtn.TextSize = 12
    minBtn.Parent = topBar
    Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 4)

    local refBtn = Instance.new("TextButton")
    refBtn.Size = UDim2.new(0, btnSize, 0, btnSize)
    refBtn.Position = UDim2.new(1, -75, 0, btnY)
    refBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
    refBtn.BorderSizePixel = 0
    refBtn.Font = Enum.Font.GothamBold
    refBtn.Text = "🔄"
    refBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    refBtn.TextSize = 10
    refBtn.Parent = topBar
    Instance.new("UICorner", refBtn).CornerRadius = UDim.new(0, 4)

    local filterBtn = Instance.new("TextButton")
    filterBtn.Size = UDim2.new(0, btnSize, 0, btnSize)
    filterBtn.Position = UDim2.new(1, -100, 0, btnY)
    filterBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
    filterBtn.BorderSizePixel = 0
    filterBtn.Font = Enum.Font.GothamBold
    filterBtn.Text = "🔍"
    filterBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    filterBtn.TextSize = 10
    filterBtn.Parent = topBar
    Instance.new("UICorner", filterBtn).CornerRadius = UDim.new(0, 4)

    filterBtn.MouseButton1Click:Connect(function()
        showFilterPopup()
    end)

    ----------------------------------------------------------------
    -- SCROLLABLE TAB BAR NAVIGATION UI (6 TABS)
    ----------------------------------------------------------------
    local tabContainer = Instance.new("ScrollingFrame")
    tabContainer.Name = "TabContainer"
    tabContainer.Size = UDim2.new(1, -12, 0, 26)
    tabContainer.Position = UDim2.new(0, 6, 0, 34)
    tabContainer.BackgroundTransparency = 1
    tabContainer.BorderSizePixel = 0
    tabContainer.CanvasSize = UDim2.new(0, 0, 0, 0) -- Biar nanti dihitung otomatis
    tabContainer.ScrollBarThickness = 0
    tabContainer.Parent = mainFrame

    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    tabLayout.Padding = UDim.new(0, 4)
    tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tabLayout.Parent = tabContainer

    -- Tambahan baris ini agar CanvasSize otomatis pas mentok di tab terakhir
    tabLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        tabContainer.CanvasSize = UDim2.new(0, tabLayout.AbsoluteContentSize.X, 0, 0)
    end)

    local tabButtons = {}
    local tabNames = {"PPESP", "ITESP", "CDESP", "DESP", "LOOT", "BLACKLIST"}

    local scrollingFrame = Instance.new("ScrollingFrame")
    scrollingFrame.Name = "ItemList"
    scrollingFrame.Size = UDim2.new(1, -12, 1, -70)
    scrollingFrame.Position = UDim2.new(0, 6, 0, 64)
    scrollingFrame.BackgroundTransparency = 1
    scrollingFrame.BorderSizePixel = 0
    scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    scrollingFrame.ScrollBarThickness = 5
    scrollingFrame.Parent = mainFrame

    local uiListLayout = Instance.new("UIListLayout")
    uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    uiListLayout.Padding = UDim.new(0, 4)
    uiListLayout.Parent = scrollingFrame

    local itemFrames = {}

    local function updateTabStyles()
        for name, btn in pairs(tabButtons) do
            if name == currentTab then
                btn.BackgroundColor3 = (name == "BLACKLIST") and Color3.fromRGB(180, 50, 50) or Color3.fromRGB(0, 150, 90)
                btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            else
                btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
                btn.TextColor3 = Color3.fromRGB(180, 180, 180)
            end
        end
    end

    local function clearItemFrames()
        for key, frame in pairs(itemFrames) do
            if frame then frame:Destroy() end
        end
        table.clear(itemFrames)
    end

    for i, name in ipairs(tabNames) do
        local btn = Instance.new("TextButton")
        btn.Name = name .. "_Tab"
        btn.Size = UDim2.new(0, 54, 1, 0)
        btn.LayoutOrder = i
        btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.GothamBold
        btn.Text = name
        btn.TextColor3 = Color3.fromRGB(180, 180, 180)
        btn.TextSize = 9
        btn.Parent = tabContainer

        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

        btn.MouseButton1Click:Connect(function()
            if currentTab ~= name then
                currentTab = name
                updateTabStyles()
                clearItemFrames()
                if currentTab == "PPESP" then scanAndFetchAllPrompts()
                elseif currentTab == "ITESP" then rebuildITESPCache()
                elseif currentTab == "CDESP" then rebuildCDESPCache()
                elseif currentTab == "DESP" then scanAndFetchAllPrompts()
                elseif currentTab == "LOOT" then rebuildLootCache()
                end
            end
        end)

        tabButtons[name] = btn
    end

    updateTabStyles()

    local minimized = false
    minBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        scrollingFrame.Visible = not minimized
        tabContainer.Visible = not minimized
        if minimized then
            mainFrame.Size = UDim2.new(0, 300, 0, 30)
            minBtn.Text = "+"
        else
            mainFrame.Size = UDim2.new(0, 300, 0, 310)
            minBtn.Text = "-"
        end
    end)

    closeBtn.MouseButton1Click:Connect(function()
        toggleITP()
    end)

    refBtn.MouseButton1Click:Connect(function()
        clearItemFrames()
        scanAndFetchAllPrompts()
    end)

    -- MAIN LOOP UPDATE ITP UI
    local lastUpdate = 0
    connections.itp = RunService.RenderStepped:Connect(function()
        if not itpActive or not mainFrame or not mainFrame.Parent then return end

        local now = tick()
        if now - lastUpdate < 0.2 then return end
        lastUpdate = now

        local root = getLocalRoot()
        local myPos = root and root.Position or Vector3.new(0, 0, 0)
        local renderDistSq = PPESP_RENDER_DISTANCE * PPESP_RENDER_DISTANCE

        ----------------------------------------------------------------
        -- RENDER TAB BLACKLIST
        ----------------------------------------------------------------
        if currentTab == "BLACKLIST" then
            local allBlacklists = {}
            for tab, blMap in pairs(tabBlacklists) do
                for kw in pairs(blMap) do
                    table.insert(allBlacklists, {kw = kw, tab = tab})
                end
            end

            local activeListKeys = {}
            for _, item in ipairs(allBlacklists) do
                activeListKeys[item.kw .. "_" .. item.tab] = true
            end

            for key, frame in pairs(itemFrames) do
                if not activeListKeys[key] then
                    frame:Destroy()
                    itemFrames[key] = nil
                end
            end

            for i, item in ipairs(allBlacklists) do
                local key = item.kw .. "_" .. item.tab
                local frame = itemFrames[key]

                if not frame then
                    frame = Instance.new("Frame")
                    frame.Size = UDim2.new(1, 0, 0, 26)
                    frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
                    frame.BorderSizePixel = 0
                    frame.Parent = scrollingFrame

                    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 4)

                    local nameLabel = Instance.new("TextLabel")
                    nameLabel.Name = "NameLabel"
                    nameLabel.Size = UDim2.new(1, -95, 1, 0)
                    nameLabel.Position = UDim2.new(0, 8, 0, 0)
                    nameLabel.BackgroundTransparency = 1
                    nameLabel.Font = Enum.Font.Gotham
                    nameLabel.Text = '[' .. item.tab .. '] "' .. item.kw .. '"'
                    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                    nameLabel.TextSize = 11
                    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
                    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
                    nameLabel.Parent = frame

                    local unblkBtn = Instance.new("TextButton")
                    unblkBtn.Name = "UnblkButton"
                    unblkBtn.Size = UDim2.new(0, 75, 0, 18)
                    unblkBtn.Position = UDim2.new(1, -80, 0.5, -9)
                    unblkBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 90)
                    unblkBtn.BorderSizePixel = 0
                    unblkBtn.Font = Enum.Font.GothamBold
                    unblkBtn.Text = "Tampilkan"
                    unblkBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                    unblkBtn.TextSize = 10
                    unblkBtn.Parent = frame

                    Instance.new("UICorner", unblkBtn).CornerRadius = UDim.new(0, 4)

                    unblkBtn.MouseButton1Click:Connect(function()
                        tabBlacklists[item.tab][item.kw] = nil
                        if item.tab == "PPESP" then scanAndFetchAllPrompts()
                        elseif item.tab == "ITESP" then rebuildITESPCache()
                        elseif item.tab == "CDESP" then rebuildCDESPCache()
                        elseif item.tab == "LOOT" then rebuildLootCache() end
                        if frame then
                            frame:Destroy()
                            itemFrames[key] = nil
                        end
                    end)

                    itemFrames[key] = frame
                end

                frame.LayoutOrder = i
            end

            scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, #allBlacklists * 30)
            return
        end

        ----------------------------------------------------------------
        -- RENDER TAB NORMAL (PPESP, ITESP, CDESP, DESP, LOOT)
        ----------------------------------------------------------------
        local allItems = {}

        if currentTab == "PPESP" then
            if #itpCache == 0 then
                rebuildPPESPCache()
            end

            for i = 1, #itpCache do
                local item = itpCache[i]
                local part = item.part
                if part and part.Parent and isInWorkspace(part) then
                    local offset = part.Position - myPos
                    local distSq = offset:Dot(offset)
                    if distSq <= renderDistSq then
                        table.insert(allItems, {
                            key = item.key,
                            part = part,
                            name = item.name,
                            distance = math.sqrt(distSq),
                            isPinned = pinnedItems[item.key] == true
                        })
                    end
                end
            end
        elseif currentTab == "ITESP" then
            if #itpTouchCache == 0 then
                rebuildITESPCache()
            end

            for i = 1, #itpTouchCache do
                local item = itpTouchCache[i]
                local part = item.part
                if part and part.Parent and isInWorkspace(part) then
                    local offset = part.Position - myPos
                    local distSq = offset:Dot(offset)
                    if distSq <= renderDistSq then
                        table.insert(allItems, {
                            key = item.key,
                            part = part,
                            name = item.name,
                            distance = math.sqrt(distSq),
                            isPinned = pinnedItems[item.key] == true
                        })
                    end
                end
            end
        elseif currentTab == "CDESP" then
            if #itpClickCache == 0 then
                rebuildCDESPCache()
            end

            for i = 1, #itpClickCache do
                local item = itpClickCache[i]
                local part = item.part
                if part and part.Parent and isInWorkspace(part) then
                    local offset = part.Position - myPos
                    local distSq = offset:Dot(offset)
                    if distSq <= renderDistSq then
                        table.insert(allItems, {
                            key = item.key,
                            part = part,
                            name = item.name,
                            distance = math.sqrt(distSq),
                            isPinned = pinnedItems[item.key] == true
                        })
                    end
                end
            end
        elseif currentTab == "DESP" then
            for prompt, part in pairs(doorPromptMap) do
                if prompt and part and isInWorkspace(part) then
                    if not isBlacklisted("DESP", prompt, part) and passesFilter("DESP", prompt, part) then
                        local offset = part.Position - myPos
                        local distSq = offset:Dot(offset)
                        if distSq <= renderDistSq then
                            table.insert(allItems, {
                                key = prompt,
                                part = part,
                                name = getProximityItemName(prompt, part),
                                distance = math.sqrt(distSq),
                                isPinned = pinnedItems[prompt] == true
                            })
                        end
                    end
                end
            end
        elseif currentTab == "LOOT" then
            if #itpLootCache == 0 then
                rebuildLootCache()
            end

            for i = 1, #itpLootCache do
                local item = itpLootCache[i]
                local part = item.part
                if part and part.Parent and isInWorkspace(part) then
                    local offset = part.Position - myPos
                    local distSq = offset:Dot(offset)
                    if distSq <= renderDistSq then
                        table.insert(allItems, {
                            key = item.key,
                            part = part,
                            name = item.name,
                            distance = math.sqrt(distSq),
                            isPinned = pinnedItems[item.key] == true
                        })
                    end
                end
            end
        end

        table.sort(allItems, function(a, b)
            if a.isPinned and not b.isPinned then
                return true
            elseif not a.isPinned and b.isPinned then
                return false
            else
                return a.distance < b.distance
            end
        end)

        local displayItems = {}
        for i = 1, math.min(#allItems, MAX_DISPLAY_ITEMS) do
            table.insert(displayItems, allItems[i])
        end

        local currentActiveKeys = {}
        for _, data in ipairs(displayItems) do
            currentActiveKeys[data.key] = true
        end

        for key, frame in pairs(itemFrames) do
            if not currentActiveKeys[key] then
                frame:Destroy()
                itemFrames[key] = nil
            end
        end

        for i, data in ipairs(displayItems) do
            local frame = itemFrames[data.key]

            if not frame then
                frame = Instance.new("Frame")
                frame.Size = UDim2.new(1, 0, 0, 26)
                frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
                frame.BorderSizePixel = 0
                frame.Parent = scrollingFrame

                local fc = Instance.new("UICorner")
                fc.CornerRadius = UDim.new(0, 4)
                fc.Parent = frame

                local distLabel = Instance.new("TextLabel")
                distLabel.Name = "DistLabel"
                distLabel.Size = UDim2.new(0, 48, 1, 0)
                distLabel.Position = UDim2.new(0, 6, 0, 0)
                distLabel.BackgroundTransparency = 1
                distLabel.Font = Enum.Font.Gotham
                distLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
                distLabel.TextSize = 11
                distLabel.TextXAlignment = Enum.TextXAlignment.Left
                distLabel.Parent = frame

                local nameLabel = Instance.new("TextLabel")
                nameLabel.Name = "NameLabel"
                nameLabel.Size = UDim2.new(1, -150, 1, 0)
                nameLabel.Position = UDim2.new(0, 54, 0, 0)
                nameLabel.BackgroundTransparency = 1
                nameLabel.Font = Enum.Font.Gotham
                nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                nameLabel.TextSize = 11
                nameLabel.TextXAlignment = Enum.TextXAlignment.Left
                nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
                nameLabel.Parent = frame

                local pinBtn = Instance.new("TextButton")
                pinBtn.Name = "PinButton"
                pinBtn.Size = UDim2.new(0, 24, 0, 18)
                pinBtn.Position = UDim2.new(1, -88, 0.5, -9)
                pinBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                pinBtn.BorderSizePixel = 0
                pinBtn.Font = Enum.Font.GothamBold
                pinBtn.Text = "📌"
                pinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                pinBtn.TextSize = 10
                pinBtn.Parent = frame

                local pinc = Instance.new("UICorner")
                pinc.CornerRadius = UDim.new(0, 4)
                pinc.Parent = pinBtn

                local tpBtn = Instance.new("TextButton")
                tpBtn.Name = "TpButton"
                tpBtn.Size = UDim2.new(0, 58, 0, 18)
                tpBtn.Position = UDim2.new(1, -60, 0.5, -9)
                tpBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 90)
                tpBtn.BorderSizePixel = 0
                tpBtn.Font = Enum.Font.GothamBold
                tpBtn.Text = "Teleport"
                tpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                tpBtn.TextSize = 10
                tpBtn.Parent = frame

                local tpc = Instance.new("UICorner")
                tpc.CornerRadius = UDim.new(0, 4)
                tpc.Parent = tpBtn

                local capturedKey = data.key
                local capturedPart = data.part

                pinBtn.MouseButton1Click:Connect(function()
                    if pinnedItems[capturedKey] then
                        pinnedItems[capturedKey] = nil
                    else
                        pinnedItems[capturedKey] = true
                    end
                end)

                tpBtn.MouseButton1Click:Connect(function()
                    local c = LocalPlayer.Character
                    local rp = c and c:FindFirstChild("HumanoidRootPart")
                    if rp and capturedPart and isInWorkspace(capturedPart) then
                        rp.CFrame = CFrame.new(capturedPart.Position + Vector3.new(0, 3, 0))
                    end
                end)

                itemFrames[data.key] = frame
            end

            frame.LayoutOrder = i
            local distLabel = frame:FindFirstChild("DistLabel")
            local nameLabel = frame:FindFirstChild("NameLabel")
            local pinBtn = frame:FindFirstChild("PinButton")

            if distLabel then distLabel.Text = string.format("[%.1fm]", data.distance) end
            if nameLabel then nameLabel.Text = data.name end
            if pinBtn then
                if data.isPinned then
                    pinBtn.BackgroundColor3 = Color3.fromRGB(200, 140, 0)
                else
                    pinBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                end
            end
        end

        scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, #displayItems * 30)
    end)
end


----------------------------------------------------------------
-- STANDALONE INTERACTABLE HUB
----------------------------------------------------------------
local Plugin = {
    Commands = {
        proximityesp = {Function = function(args)
            ppespFilter = lower(args and args[1] or "")
            ppespEnabled = true
            stopProximityESP()
            task.spawn(scanProximityESP)
            connections.proximity = Workspace.DescendantAdded:Connect(function(object)
                if object:IsA("ProximityPrompt") then
                    task.defer(function() addProximityESP(object); rebuildPPESPCache() end)
                end
            end)
            connections.proximityRemoving = Workspace.DescendantRemoving:Connect(function(object)
                if object:IsA("ProximityPrompt") then cleanupProximityPrompt(object); rebuildPPESPCache() end
            end)
        end},
        itp = {Function = function() toggleITP() end},
        dooresp = {Function = function(args) despFilter = lower(args and args[1] or ""); stopDoorESP(); scanDoorESP() end},
        clickdetectoresp = {Function = function(args)
            cdespFilter = lower(args and args[1] or "")
            cdespEnabled = true
            stopClickESP()
            scanClickESP()
            connections.click = Workspace.DescendantAdded:Connect(function(object)
                if object:IsA("ClickDetector") then task.defer(function() addClickESP(object) end) end
            end)
        end},
        touchinterestesp = {Function = function()
            if connections.touchTrigger then connections.touchTrigger:Disconnect(); connections.touchTrigger = nil end
            local seen = {}
            for _, object in ipairs(Workspace:GetDescendants()) do
                if isTouchInteraction(object) then
                    local part = getTouchPart(object)
                    if part and not seen[part] then
                        seen[part] = true
                        if isTriggerPart(part) then createTriggerTouchESP(part) end
                    end
                end
            end
            connections.touchTrigger = Workspace.DescendantAdded:Connect(function(object)
                if isTouchInteraction(object) then
                    task.defer(function()
                        local part = getTouchPart(object)
                        if part and isTriggerPart(part) then createTriggerTouchESP(part) end
                    end)
                end
            end)
        end},
        itemtouchesp = {Function = function(args)
            itespFilter = lower(args and args[1] or "")
            itespEnabled = true
            stopItemTouchESP()
            scanItemTouchESP()
            connections.touchItem = Workspace.DescendantAdded:Connect(function(object)
                if isTouchInteraction(object) then
                    task.defer(function()
                        local part = getTouchPart(object)
                        if part and not isTriggerPart(part) and not isPlayerCharacterPart(part) then
                            touchItemMap[object] = part
                            if itespEnabled then createItemTouchESP(part) end
                        end
                    end)
                end
            end)
        end},
        loot = {Function = function(args)
            lootFilter = lower(args and args[1] or "")
            lootEnabled = true
            stopLootESP()
            scanLootESP()
            connections.loot = Workspace.DescendantAdded:Connect(function(object)
                if lootEnabled and isLootItem(object) then
                    task.defer(function()
                        local modelRoot = object
                        if object:IsA("BasePart") and object.Parent and object.Parent:IsA("Model") then modelRoot = object.Parent end
                        createLootESP(modelRoot)
                    end)
                end
            end)
            connections.lootRemoving = Workspace.DescendantRemoving:Connect(function(object)
                if isLootItem(object) then
                    local modelRoot = object
                    if object:IsA("BasePart") and object.Parent and object.Parent:IsA("Model") then modelRoot = object.Parent end
                    removeLootESP(modelRoot)
                end
            end)
        end}
    }
}

local Feature = {Name = "Interactable"}
local menuGui
local menuButtons = {}
local ORDER = {
    {id="PPESP", title="Proximity (PPESP)", command="proximityesp"},
    {id="ITP", title="Item Teleport (ITP)", command="itp"},
    {id="DESP", title="Door (DESP)", command="dooresp"},
    {id="CDESP", title="Click (CDESP)", command="clickdetectoresp"},
    {id="TESP", title="Touch (TESP)", command="touchinterestesp"},
    {id="ITESP", title="Item (ITESP)", command="itemtouchesp"},
    {id="LOOT", title="Loot", command="loot"}
}
local function isRunning(id)
    if id=="PPESP" then return ppespEnabled end
    if id=="ITP" then return itpActive end
    if id=="DESP" then return despEnabled end
    if id=="CDESP" then return cdespEnabled end
    if id=="TESP" then return connections.touchTrigger~=nil end
    if id=="ITESP" then return itespEnabled end
    if id=="LOOT" then return lootEnabled end
    return false
end
local function stopFeature(id)
    if id=="PPESP" then ppespEnabled=false; stopProximityESP()
    elseif id=="ITP" then if itpActive then toggleITP() end
    elseif id=="DESP" then stopDoorESP()
    elseif id=="CDESP" then stopClickESP()
    elseif id=="TESP" then stopTriggerTouchESP()
    elseif id=="ITESP" then stopItemTouchESP()
    elseif id=="LOOT" then stopLootESP() end
end
local function refreshButtons()
    for id, button in pairs(menuButtons) do
        local running=isRunning(id)
        button.Text=running and "STOP" or "EXECUTE"
        button.BackgroundColor3=running and Color3.fromRGB(170,65,75) or Color3.fromRGB(35,145,105)
    end
end

function Feature:OpenMenu()
    if menuGui and menuGui.Parent then menuGui.Enabled=true; refreshButtons(); return true end
    local playerGui=LocalPlayer:WaitForChild("PlayerGui")
    menuGui=Instance.new("ScreenGui")
    menuGui.Name="TryoInteractableHub"
    menuGui.ResetOnSpawn=false
    menuGui.Parent=playerGui
    table.clear(menuButtons)

    local frame=Instance.new("Frame")
    frame.Name="Panel"
    frame.Size=UDim2.fromOffset(286,292)
    frame.Position=UDim2.new(0.5,-143,0.5,-146)
    frame.BackgroundColor3=Color3.fromRGB(23,31,45)
    frame.BackgroundTransparency=0.12
    frame.BorderSizePixel=0
    frame.Parent=menuGui
    Instance.new("UICorner",frame).CornerRadius=UDim.new(0,9)
    local gradient=Instance.new("UIGradient")
    gradient.Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0,Color3.fromRGB(45,82,112)),
        ColorSequenceKeypoint.new(1,Color3.fromRGB(66,43,94))
    })
    gradient.Rotation=35
    gradient.Parent=frame
    local stroke=Instance.new("UIStroke")
    stroke.Color=Color3.fromRGB(115,160,200)
    stroke.Transparency=0.55
    stroke.Parent=frame

    local top=Instance.new("Frame")
    top.Name="TopBar"
    top.Size=UDim2.new(1,0,0,30)
    top.BackgroundColor3=Color3.fromRGB(38,60,86)
    top.BackgroundTransparency=0.1
    top.BorderSizePixel=0
    top.Parent=frame
    Instance.new("UICorner",top).CornerRadius=UDim.new(0,9)

    local dragArea=Instance.new("Frame")
    dragArea.Name="DragArea"
    dragArea.Size=UDim2.new(1,-34,1,0)
    dragArea.BackgroundTransparency=1
    dragArea.Active=true
    dragArea.Parent=top

    local title=Instance.new("TextLabel")
    title.Size=UDim2.new(1,-42,1,0)
    title.Position=UDim2.fromOffset(9,0)
    title.BackgroundTransparency=1
    title.Font=Enum.Font.GothamBold
    title.TextSize=12
    title.TextColor3=Color3.new(1,1,1)
    title.TextXAlignment=Enum.TextXAlignment.Left
    title.Text="INTERACTABLE"
    title.Parent=top

    local close=Instance.new("TextButton")
    close.Size=UDim2.fromOffset(23,22)
    close.Position=UDim2.new(1,-28,0,4)
    close.BackgroundColor3=Color3.fromRGB(175,65,75)
    close.BorderSizePixel=0
    close.Text="×"
    close.Font=Enum.Font.GothamBold
    close.TextSize=15
    close.TextColor3=Color3.new(1,1,1)
    close.Parent=top
    Instance.new("UICorner",close).CornerRadius=UDim.new(0,4)
    close.MouseButton1Click:Connect(function()
        if menuGui then menuGui:Destroy(); menuGui=nil end
        table.clear(menuButtons)
    end)

    local list=Instance.new("Frame")
    list.Size=UDim2.new(1,-12,1,-38)
    list.Position=UDim2.fromOffset(6,34)
    list.BackgroundTransparency=1
    list.Parent=frame
    local layout=Instance.new("UIListLayout")
    layout.Padding=UDim.new(0,4)
    layout.SortOrder=Enum.SortOrder.LayoutOrder
    layout.Parent=list

    for index,info in ipairs(ORDER) do
        local row=Instance.new("Frame")
        row.Size=UDim2.new(1,0,0,32)
        row.BackgroundColor3=Color3.fromRGB(25,35,49)
        row.BackgroundTransparency=0.16
        row.BorderSizePixel=0
        row.LayoutOrder=index
        row.Parent=list
        Instance.new("UICorner",row).CornerRadius=UDim.new(0,5)

        local label=Instance.new("TextLabel")
        label.Size=UDim2.new(1,-92,1,0)
        label.Position=UDim2.fromOffset(8,0)
        label.BackgroundTransparency=1
        label.Font=Enum.Font.GothamSemibold
        label.TextSize=10
        label.TextColor3=Color3.fromRGB(235,240,248)
        label.TextXAlignment=Enum.TextXAlignment.Left
        label.Text=info.title
        label.Parent=row

        local button=Instance.new("TextButton")
        button.Size=UDim2.fromOffset(76,23)
        button.Position=UDim2.new(1,-82,0.5,-11)
        button.BackgroundColor3=Color3.fromRGB(35,145,105)
        button.BorderSizePixel=0
        button.Font=Enum.Font.GothamBold
        button.TextSize=9
        button.TextColor3=Color3.new(1,1,1)
        button.Text="EXECUTE"
        button.Parent=row
        Instance.new("UICorner",button).CornerRadius=UDim.new(0,4)
        menuButtons[info.id]=button

        button.MouseButton1Click:Connect(function()
            if isRunning(info.id) then
                stopFeature(info.id)
            else
                local command=Plugin.Commands[info.command]
                if command and command.Function then
                    local ok,err=pcall(command.Function,{},LocalPlayer)
                    if not ok then warn("[Tryo Interactable] "..info.id..": "..tostring(err)) end
                end
            end
            task.delay(0.15,refreshButtons)
        end)
    end

    local dragName="TryoInteractableHubDrag"
    local dragging,dragStart,frameStart=false,nil,nil
    dragArea.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            dragging=true
            dragStart=input.Position
            frameStart=frame.Position
            ContextActionService:BindActionAtPriority(dragName,function() return Enum.ContextActionResult.Sink end,false,3000,Enum.UserInputType.MouseButton1,Enum.UserInputType.Touch)
        end
    end)
    local ended=UserInputService.InputEnded:Connect(function(input)
        if dragging and (input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch) then
            dragging=false
            ContextActionService:UnbindAction(dragName)
        end
    end)
    local moved=UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
            local delta=input.Position-dragStart
            frame.Position=UDim2.new(frameStart.X.Scale,frameStart.X.Offset+delta.X,frameStart.Y.Scale,frameStart.Y.Offset+delta.Y)
        end
    end)
    menuGui.Destroying:Connect(function()
        dragging=false
        ContextActionService:UnbindAction(dragName)
        ended:Disconnect()
        moved:Disconnect()
    end)
    refreshButtons()
    return true
end

function Feature:Start() return self:OpenMenu() end
function Feature:Stop()
    for _,info in ipairs(ORDER) do stopFeature(info.id) end
    if menuGui then menuGui:Destroy(); menuGui=nil end
    table.clear(menuButtons)
    return true
end
Feature.IsRunning=isRunning
return Feature
