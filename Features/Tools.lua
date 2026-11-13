-- Native standalone Tools features. No Infinite Yield globals or command registry.
local Players=game:GetService("Players")
local UserInputService=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local Lighting=game:GetService("Lighting")
local LocalPlayer=Players.LocalPlayer
local Features={}

local function notify(title,message)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification",{Title=title,Text=message,Duration=3})
    end)
end

Features.AntiAFK={
    Name="Anti AFK", Description="Mencegah karakter dianggap idle oleh game.",
    Start=function(context)
        if context.AntiAFKConnection then return true end
        local virtualUser=game:GetService("VirtualUser")
        context.AntiAFKConnection=LocalPlayer.Idled:Connect(function()
            pcall(function() virtualUser:CaptureController(); virtualUser:ClickButton2(Vector2.new(0,0)) end)
        end)
        notify("Anti AFK","Anti AFK aktif.")
        return true
    end,
    Stop=function(context)
        if context.AntiAFKConnection then context.AntiAFKConnection:Disconnect(); context.AntiAFKConnection=nil end
        notify("Anti AFK","Anti AFK dinonaktifkan.")
    end
}

local originalLighting,removedAtmospheres,fullbrightConnection
removedAtmospheres={}
Features.Fullbright={
    Name="Full Bright", Description="Menerangkan map dan mengurangi kabut secara lokal.",
    Start=function()
        if fullbrightConnection then return true end
        originalLighting={Brightness=Lighting.Brightness,ClockTime=Lighting.ClockTime,FogEnd=Lighting.FogEnd,
            GlobalShadows=Lighting.GlobalShadows,Ambient=Lighting.Ambient,OutdoorAmbient=Lighting.OutdoorAmbient}
        table.clear(removedAtmospheres)
        for _,child in ipairs(Lighting:GetChildren()) do
            if child:IsA("Atmosphere") then table.insert(removedAtmospheres,child); child.Parent=nil end
        end
        fullbrightConnection=RunService.RenderStepped:Connect(function()
            Lighting.Brightness=2; Lighting.ClockTime=14; Lighting.FogEnd=100000
            Lighting.GlobalShadows=false
            Lighting.Ambient=Color3.fromRGB(200,200,200)
            Lighting.OutdoorAmbient=Color3.fromRGB(200,200,200)
        end)
        notify("Full Bright","Pencahayaan lokal diaktifkan.")
        return true
    end,
    Stop=function()
        if fullbrightConnection then fullbrightConnection:Disconnect(); fullbrightConnection=nil end
        if originalLighting then
            for property,value in pairs(originalLighting) do pcall(function() Lighting[property]=value end) end
            originalLighting=nil
        end
        for _,atmosphere in ipairs(removedAtmospheres) do
            if atmosphere and not atmosphere.Parent then atmosphere.Parent=Lighting end
        end
        table.clear(removedAtmospheres)
        notify("Full Bright","Pencahayaan awal dipulihkan.")
    end
}

local jumpConnection
Features.InfiniteJump={
    Name="Infinite Jump", Description="Mengizinkan JumpRequest saat karakter masih hidup.",
    Start=function()
        if jumpConnection then return true end
        jumpConnection=UserInputService.JumpRequest:Connect(function()
            local character=LocalPlayer.Character
            local humanoid=character and character:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health>0 then humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end
        end)
        notify("Infinite Jump","Infinite Jump aktif.")
        return true
    end,
    Stop=function()
        if jumpConnection then jumpConnection:Disconnect(); jumpConnection=nil end
        notify("Infinite Jump","Infinite Jump dinonaktifkan.")
    end
}

local noclipConnection,noclipCharacterConnection
local originalCollision={}
local function restoreCollision()
    for part,canCollide in pairs(originalCollision) do
        if part and part.Parent then pcall(function() part.CanCollide=canCollide end) end
    end
    table.clear(originalCollision)
end
local function applyNoclip(character)
    if not character then return end
    for _,object in ipairs(character:GetDescendants()) do
        if object:IsA("BasePart") then
            if originalCollision[object]==nil then originalCollision[object]=object.CanCollide end
            object.CanCollide=false
        end
    end
end
Features.Noclip={
    Name="Noclip", Description="Menonaktifkan tabrakan karakter secara lokal.",
    Start=function()
        if noclipConnection then return true end
        applyNoclip(LocalPlayer.Character)
        noclipCharacterConnection=LocalPlayer.CharacterAdded:Connect(function(character) task.wait(0.25); applyNoclip(character) end)
        noclipConnection=RunService.Stepped:Connect(function() applyNoclip(LocalPlayer.Character) end)
        notify("Noclip","Noclip aktif.")
        return true
    end,
    Stop=function()
        if noclipConnection then noclipConnection:Disconnect(); noclipConnection=nil end
        if noclipCharacterConnection then noclipCharacterConnection:Disconnect(); noclipCharacterConnection=nil end
        restoreCollision()
        notify("Noclip","Noclip dinonaktifkan.")
    end
}

local walkSpeedConnection
local walkSpeedCharacterConnection
local walkSpeedOriginals = {}
local walkSpeedContext
local function restoreWalkSpeeds()
    if walkSpeedConnection then walkSpeedConnection:Disconnect(); walkSpeedConnection=nil end
    if walkSpeedCharacterConnection then walkSpeedCharacterConnection:Disconnect(); walkSpeedCharacterConnection=nil end
    for humanoid, speed in pairs(walkSpeedOriginals) do
        if humanoid and humanoid.Parent then
            pcall(function() humanoid.WalkSpeed = speed end)
        end
    end
    table.clear(walkSpeedOriginals)
    walkSpeedContext = nil
end

Features.WalkSpeed = {
    Name = "WalkSpeed",
    Description = "Atur kecepatan jalan lokal; nilai awal dipulihkan saat dimatikan.",
    Start = function(context)
        if walkSpeedConnection then return true end
        walkSpeedContext = context
        context.WalkSpeedTarget = math.clamp(tonumber(context.WalkSpeedTarget) or 32, 16, 100)

        local function applyToCharacter(character)
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if not humanoid then return end
            if walkSpeedOriginals[humanoid] == nil then
                walkSpeedOriginals[humanoid] = humanoid.WalkSpeed
            end
            humanoid.WalkSpeed = context.WalkSpeedTarget
        end

        applyToCharacter(LocalPlayer.Character)
        walkSpeedCharacterConnection = LocalPlayer.CharacterAdded:Connect(function(character)
            task.wait(0.25)
            applyToCharacter(character)
        end)
        walkSpeedConnection = RunService.Heartbeat:Connect(function()
            local character = LocalPlayer.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                if walkSpeedOriginals[humanoid] == nil then
                    walkSpeedOriginals[humanoid] = humanoid.WalkSpeed
                end
                local target = math.clamp(tonumber(context.WalkSpeedTarget) or 32, 16, 100)
                if humanoid.WalkSpeed ~= target then humanoid.WalkSpeed = target end
            end
        end)
        notify("WalkSpeed", "Aktif: " .. tostring(context.WalkSpeedTarget))
        return true
    end,
    Stop = function()
        restoreWalkSpeeds()
        notify("WalkSpeed", "Kecepatan karakter dipulihkan.")
    end
}

return Features
