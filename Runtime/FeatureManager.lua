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

function FeatureManager:Destroy()
    if self.Destroyed then return end
    for id,enabled in pairs(self.States) do
        if enabled then self:SetEnabled(id,false) end
    end
    self.Destroyed=true
end
return FeatureManager
