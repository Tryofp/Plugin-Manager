-- Tryo Standalone Feature Manager
-- Owns feature state and lifecycle; no Infinite Yield command registry.
local FeatureManager = {}
FeatureManager.__index = FeatureManager

function FeatureManager.new(context)
    return setmetatable({Context=context or {}, Registry={}, States={}, Destroyed=false}, FeatureManager)
end

function FeatureManager:Register(id, definition)
    assert(type(id)=="string" and id~="", "Feature id is required")
    assert(type(definition)=="table" and type(definition.Start)=="function", "Feature Start callback is required")
    assert(not self.Registry[id], "Feature already registered: "..id)
    self.Registry[id]=definition
    self.States[id]=false
    return definition
end

function FeatureManager:SetEnabled(id, enabled)
    if self.Destroyed then return false, "Feature manager is destroyed" end
    local definition=self.Registry[id]
    if not definition then return false, "Unknown feature: "..tostring(id) end
    enabled=enabled==true
    if self.States[id]==enabled then return true end
    if enabled then
        local ok,result=pcall(definition.Start,self.Context)
        if not ok or result==false then
            self.States[id]=false
            warn("[Tryo Feature] "..id.." failed to start: "..tostring(result))
            return false,result
        end
        self.States[id]=true
        return true
    end
    local ok,result=true,nil
    if type(definition.Stop)=="function" then ok,result=pcall(definition.Stop,self.Context) end
    self.States[id]=false
    if not ok then warn("[Tryo Feature] "..id.." failed to stop: "..tostring(result)) return false,result end
    return true
end

function FeatureManager:IsEnabled(id)
    return self.States[id]==true
end

-- Shutdown active features gradually so closing the hub does not run every
-- cleanup routine in the same frame. The UI can disappear immediately while
-- feature resources are released one feature at a time.
function FeatureManager:DestroyAsync()
    if self.Destroyed then return end
    self.Destroyed = true

    local queue = {}
    for id, enabled in pairs(self.States) do
        if enabled then
            table.insert(queue, {Id = id, Definition = self.Registry[id]})
            self.States[id] = false
        end
    end

    for index, item in ipairs(queue) do
        local stop = item.Definition and item.Definition.Stop
        if type(stop) == "function" then
            local ok, err = pcall(stop, self.Context)
            if not ok then
                warn("[Tryo Feature] " .. item.Id .. " shutdown failed: " .. tostring(err))
            end
        end
        -- Pace shutdown instead of stacking cleanup work on consecutive
        -- frames. Heavy feature-specific cleanup is responsible for batching
        -- its own large instance-removal loops.
        if index < #queue then task.wait(0.08) end
    end
end

function FeatureManager:Destroy()
    if self.Destroyed then return end
    for id, enabled in pairs(self.States) do
        if enabled then self:SetEnabled(id, false) end
    end
    self.Destroyed = true
end
return FeatureManager
