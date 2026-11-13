-- Standalone Instant Prompt feature for beta2.
-- Uses executor fireproximityprompt when available; normal client APIs cannot force server interactions.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Feature = {}
Feature.Name = "Instant Prompt"
Feature.Description = "Mempercepat interaksi ProximityPrompt saat tombol interaksi ditekan."

local enabled = false
local connections = {}
local knownPrompts = {}
local visiblePrompts = {}
local states = setmetatable({}, {__mode = "k"})
local retryGap, cooldown, busyTimeout = 0.10, 0.15, 0.70

local function isPrompt(object)
    return object ~= nil and object:IsA("ProximityPrompt") and object.Parent ~= nil and object.Enabled
end

local function remember(prompt)
    if prompt and prompt:IsA("ProximityPrompt") then
        knownPrompts[prompt] = true
        if not states[prompt] then
            states[prompt] = {busy = false, busyUntil = 0, lastAttempt = 0}
        end
    end
end

local function rootPart()
    local player = Players.LocalPlayer
    local character = player and player.Character
    return character and (character:FindFirstChild("HumanoidRootPart")
        or character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso"))
end

local function promptPosition(prompt)
    local parent = prompt and prompt.Parent
    if not parent then return nil end
    if parent:IsA("Attachment") then return parent.WorldPosition end
    if parent:IsA("BasePart") then return parent.Position end
    local model = parent:IsA("Model") and parent or parent:FindFirstAncestorOfClass("Model")
    if model then
        local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
        return part and part.Position
    end
    return nil
end

local function nearestPrompt()
    local root = rootPart()
    if not root then return nil end
    local best, bestDistance = nil, math.huge
    local function inspect(list)
        for prompt in pairs(list) do
            if not isPrompt(prompt) then
                list[prompt] = nil
                visiblePrompts[prompt] = nil
            else
                local position = promptPosition(prompt)
                if position then
                    local distance = (root.Position - position).Magnitude
                    if distance <= prompt.MaxActivationDistance and distance < bestDistance then
                        best, bestDistance = prompt, distance
                    end
                end
            end
        end
    end
    inspect(visiblePrompts)
    if not best then inspect(knownPrompts) end
    return best
end

local function fire(prompt)
    if not enabled or not isPrompt(prompt) then return false end
    local fireFunction = fireproximityprompt
    if type(fireFunction) ~= "function" then return false end
    local state = states[prompt]
    if not state then
        remember(prompt)
        state = states[prompt]
    end
    local now = os.clock()
    if state.busy and now < state.busyUntil then return false end
    if now - state.lastAttempt < cooldown then return false end
    state.busy, state.busyUntil, state.lastAttempt = true, now + busyTimeout, now

    local success = pcall(fireFunction, prompt, 0, false)
    if not success and isPrompt(prompt) then
        success = pcall(fireFunction, prompt, 0, true)
    end
    if not success and isPrompt(prompt) then
        success = pcall(fireFunction, prompt)
    end
    task.delay(retryGap, function()
        if states[prompt] then
            states[prompt].busy = false
            states[prompt].busyUntil = 0
        end
    end)
    return success
end

local function activateNearest()
    local prompt = nearestPrompt()
    if prompt then fire(prompt) end
end

local function disconnectAll()
    for index = #connections, 1, -1 do
        pcall(function() connections[index]:Disconnect() end)
        connections[index] = nil
    end
end

Feature.Start = function()
    if enabled then return true end
    if type(fireproximityprompt) ~= "function" then
        warn("[Tryo Instant Prompt] Executor tidak menyediakan fireproximityprompt.")
        return false
    end
    enabled = true

    table.insert(connections, ProximityPromptService.PromptShown:Connect(function(prompt)
        if enabled then
            visiblePrompts[prompt] = true
            remember(prompt)
        end
    end))
    table.insert(connections, ProximityPromptService.PromptHidden:Connect(function(prompt)
        visiblePrompts[prompt] = nil
    end))
    table.insert(connections, ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
        if enabled then
            remember(prompt)
            task.defer(function() fire(prompt) end)
        end
    end))
    table.insert(connections, UserInputService.InputBegan:Connect(function(input, processed)
        if not enabled or processed then return end
        local key = input.KeyCode
        if key == Enum.KeyCode.E or key == Enum.KeyCode.F or key == Enum.KeyCode.G then
            task.defer(activateNearest)
        end
    end))
    table.insert(connections, workspace.DescendantAdded:Connect(function(object)
        if object:IsA("ProximityPrompt") then remember(object) end
    end))
    table.insert(connections, workspace.DescendantRemoving:Connect(function(object)
        if object:IsA("ProximityPrompt") then
            knownPrompts[object], visiblePrompts[object], states[object] = nil, nil, nil
        end
    end))
    for _, object in ipairs(workspace:GetDescendants()) do
        if object:IsA("ProximityPrompt") then remember(object) end
    end
    return true
end

Feature.Stop = function()
    enabled = false
    disconnectAll()
    table.clear(knownPrompts)
    table.clear(visiblePrompts)
    table.clear(states)
end

return Feature
