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

-- Visual Environment uses one-shot local overrides and restores only values it still owns.
local function applyTracked(target, property, value, store)
    local ok, original = pcall(function() return target[property] end)
    if not ok then return end
    local setOK = pcall(function() target[property] = value end)
    if setOK then table.insert(store, {Target=target, Property=property, Original=original, Applied=value}) end
end

local function restoreTracked(store)
    for index = #store, 1, -1 do
        local item = store[index]
        pcall(function()
            if item.Target and item.Target.Parent ~= nil and item.Target[item.Property] == item.Applied then
                item.Target[item.Property] = item.Original
            elseif item.Target == Lighting and item.Target[item.Property] == item.Applied then
                item.Target[item.Property] = item.Original
            end
        end)
    end
    table.clear(store)
end

local visualStores = {}
local function makeVisualFeature(id, name, description, apply)
    local store
    return {
        Name=name,
        Description=description,
        Start=function()
            if store then return true end
            store={}
            visualStores[id]=store
            local ok,err=pcall(function() apply(store) end)
            if not ok then
                restoreTracked(store)
                store=nil
                visualStores[id]=nil
                warn("[Tryo Visual] "..id..": "..tostring(err))
                return false
            end
            notify(name,"Pengaturan visual lokal diaktifkan.")
            return true
        end,
        Stop=function()
            if store then restoreTracked(store); store=nil; visualStores[id]=nil end
            notify(name,"Pengaturan visual dipulihkan.")
        end
    }
end

Features.Fullbright=makeVisualFeature(
    "Fullbright","Brightness & Ambient",
    "Meningkatkan pencahayaan lokal tanpa mengubah waktu atau menghapus efek map.",
    function(store)
        applyTracked(Lighting,"Brightness",2,store)
        applyTracked(Lighting,"Ambient",Color3.fromRGB(200,200,200),store)
        applyTracked(Lighting,"OutdoorAmbient",Color3.fromRGB(200,200,200),store)
    end
)

Features.VisualFog=makeVisualFeature(
    "VisualFog","No Fog",
    "Mengurangi Fog dan Atmosphere secara lokal tanpa menghapus objeknya.",
    function(store)
        applyTracked(Lighting,"FogStart",0,store)
        applyTracked(Lighting,"FogEnd",100000,store)
        for _,effect in ipairs(Lighting:GetChildren()) do
            if effect:IsA("Atmosphere") then
                applyTracked(effect,"Density",0,store)
                applyTracked(effect,"Haze",0,store)
                applyTracked(effect,"Glare",0,store)
            end
        end
    end
)

Features.VisualTime=makeVisualFeature(
    "VisualTime","Daylight",
    "Mengatur ClockTime lokal ke siang hari.",
    function(store) applyTracked(Lighting,"ClockTime",14,store) end
)

Features.VisualShadows=makeVisualFeature(
    "VisualShadows","Disable Shadows",
    "Menonaktifkan GlobalShadows secara lokal.",
    function(store) applyTracked(Lighting,"GlobalShadows",false,store) end
)

Features.VisualPostFX=makeVisualFeature(
    "VisualPostFX","Disable Post FX",
    "Menonaktifkan Bloom, Blur, Color Correction, Depth of Field, dan Sun Rays lokal.",
    function(store)
        local supported={
            BloomEffect=true,BlurEffect=true,ColorCorrectionEffect=true,
            DepthOfFieldEffect=true,SunRaysEffect=true
        }
        for _,effect in ipairs(Lighting:GetChildren()) do
            if supported[effect.ClassName] then applyTracked(effect,"Enabled",false,store) end
        end
    end
)

local noFallConnection
Features.NoFallDamage={
    Name="No Fall Damage",
    Description="Melindungi jatuh tinggi berdasarkan jarak turun dari titik puncak, tanpa memperlambat lompatan normal.",
    Start=function()
        if noFallConnection then return true end
        local rayParams=RaycastParams.new()
        rayParams.FilterType=Enum.RaycastFilterType.Exclude
        local trackedCharacter=nil
        local peakY=nil
        local highFallActive=false
        local FALL_DISTANCE_THRESHOLD=8
        noFallConnection=RunService.Heartbeat:Connect(function()
            local character=LocalPlayer.Character
            if not character then
                trackedCharacter=nil
                peakY=nil
                highFallActive=false
                return
            end
            local humanoid=character:FindFirstChildOfClass("Humanoid")
            local root=character:FindFirstChild("HumanoidRootPart")
            if not humanoid or humanoid.Health<=0 or not root or not root:IsA("BasePart") then return end

            if trackedCharacter~=character then
                trackedCharacter=character
                peakY=root.Position.Y
                highFallActive=false
            end

            local grounded=humanoid.FloorMaterial~=Enum.Material.Air
            if grounded then
                peakY=root.Position.Y
                highFallActive=false
                return
            end

            local velocity=root.AssemblyLinearVelocity
            -- Keep the highest airborne position as the reference point.
            if not peakY or root.Position.Y>peakY then
                peakY=root.Position.Y
            end

            if velocity.Y>=-1 then return end

            -- A standard Roblox jump usually drops less than 8 studs from
            -- its apex. Higher jumps and ledge falls cross this threshold.
            if not highFallActive and peakY-root.Position.Y>=FALL_DISTANCE_THRESHOLD then
                highFallActive=true
            end
            if not highFallActive then return end

            rayParams.FilterDescendantsInstances={character}
            local ground=workspace:Raycast(root.Position,Vector3.new(0,-12,0),rayParams)
            local maxDownSpeed=ground and 16 or 35
            if velocity.Y < -maxDownSpeed then
                root.AssemblyLinearVelocity=Vector3.new(velocity.X,-maxDownSpeed,velocity.Z)
            end
        end)
        notify("No Fall Damage","High Fall Protection aktif. Lompatan normal tetap normal.")
        return true
    end,
    Stop=function()
        if noFallConnection then noFallConnection:Disconnect(); noFallConnection=nil end
        notify("No Fall Damage","Perlindungan jatuh dinonaktifkan.")
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
        walkSpeedConnection = RunService.Stepped:Connect(function()
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


local InspectorPlayers = game:GetService("Players")
local InspectorWorkspace = game:GetService("Workspace")
local InspectorInput = game:GetService("UserInputService")
local InspectorHttp = game:GetService("HttpService")
local InspectorMarketplace = game:GetService("MarketplaceService")
local InspectorPlayer = InspectorPlayers.LocalPlayer
local inspectorController

local function inspectorMake(className, props, parent)
    local object = Instance.new(className)
    for key, value in pairs(props or {}) do object[key] = value end
    object.Parent = parent
    return object
end
local function inspectorCorner(parent, radius)
    inspectorMake("UICorner", {CornerRadius = UDim.new(0, radius or 8)}, parent)
end
local function inspectorPath(instance)
    local ok, path = pcall(function() return instance:GetFullName() end)
    return ok and path or instance.Name
end
local function inspectorMapName()
    local ok, info = pcall(function() return InspectorMarketplace:GetProductInfo(game.PlaceId) end)
    local name = ok and info and info.Name or ("Place_" .. tostring(game.PlaceId))
    return tostring(name):gsub('[%z\1-\31<>:"/\\|?*]', "_")
end
local function inspectorSerialize(instance)
    local data = {Name=instance.Name, ClassName=instance.ClassName, Path=inspectorPath(instance), Properties={}, Children={}}
    pcall(function()
        if instance:IsA("BasePart") then
            data.Properties.Position={instance.Position.X,instance.Position.Y,instance.Position.Z}
            data.Properties.Size={instance.Size.X,instance.Size.Y,instance.Size.Z}
            data.Properties.Anchored=instance.Anchored
            data.Properties.CanCollide=instance.CanCollide
        elseif instance:IsA("Model") then
            data.Properties.PrimaryPart=instance.PrimaryPart and instance.PrimaryPart.Name or nil
        end
    end)
    for _,child in ipairs(instance:GetChildren()) do
        table.insert(data.Children,{Name=child.Name,ClassName=child.ClassName})
    end
    return data
end

Features.MobileInspector = {
    Name = "Mobile Click Inspector",
    Description = "Tap objek di map untuk melihat nama, class, children, dan full path.",
    Start = function()
        if inspectorController then return true end
        local self={Connections={},Selected=nil,Active=true}
        inspectorController=self
        local gui=inspectorMake("ScreenGui",{Name="TryoMobileInspector",ResetOnSpawn=false,DisplayOrder=999990,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
        local parent
        pcall(function() parent=game:GetService("CoreGui") end)
        local parentOK=false
        if parent then parentOK=pcall(function() gui.Parent=parent end) end
        if not parentOK then gui.Parent=InspectorPlayer:WaitForChild("PlayerGui") end
        self.Gui=gui

        local frame=inspectorMake("Frame",{Name="Panel",Size=UDim2.fromOffset(286,210),Position=UDim2.new(1,-298,0.5,-105),BackgroundColor3=Color3.fromRGB(30,39,58),BackgroundTransparency=0.16,BorderSizePixel=0,Active=true},gui)
        inspectorCorner(frame,10)
        inspectorMake("UIStroke",{Color=Color3.fromRGB(110,145,190),Transparency=0.45},frame)
        inspectorMake("UIGradient",{Color=ColorSequence.new(Color3.fromRGB(48,77,111),Color3.fromRGB(79,53,112)),Rotation=25},frame)
        local top=inspectorMake("Frame",{Size=UDim2.new(1,0,0,34),BackgroundColor3=Color3.fromRGB(53,90,128),BackgroundTransparency=0.12,BorderSizePixel=0,Active=true},frame)
        inspectorCorner(top,9)
        inspectorMake("TextLabel",{BackgroundTransparency=1,Position=UDim2.fromOffset(10,0),Size=UDim2.new(1,-74,1,0),Text="MOBILE INSPECTOR",TextColor3=Color3.fromRGB(245,248,255),Font=Enum.Font.GothamBold,TextSize=11,TextXAlignment=Enum.TextXAlignment.Left},top)
        local close=inspectorMake("TextButton",{Size=UDim2.fromOffset(26,25),Position=UDim2.new(1,-31,0,4),Text="×",TextSize=18,Font=Enum.Font.GothamBold,TextColor3=Color3.new(1,1,1),BackgroundColor3=Color3.fromRGB(160,70,90),BorderSizePixel=0},top)
        inspectorCorner(close,6)
        local status=inspectorMake("TextLabel",{BackgroundTransparency=1,Position=UDim2.fromOffset(10,39),Size=UDim2.new(1,-20,0,18),Text="Tap objek di map untuk memilih",TextColor3=Color3.fromRGB(110,220,240),Font=Enum.Font.GothamMedium,TextSize=10,TextXAlignment=Enum.TextXAlignment.Left},frame)
        local info=inspectorMake("TextLabel",{BackgroundColor3=Color3.fromRGB(18,24,37),BackgroundTransparency=0.18,Position=UDim2.fromOffset(9,61),Size=UDim2.new(1,-18,0,65),Text="Belum ada objek dipilih.",TextColor3=Color3.fromRGB(235,239,248),Font=Enum.Font.Gotham,TextSize=10,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top},frame)
        inspectorCorner(info,6)
        inspectorMake("UIPadding",{PaddingLeft=UDim.new(0,7),PaddingTop=UDim.new(0,6),PaddingRight=UDim.new(0,5)},info)
        local path=inspectorMake("TextLabel",{BackgroundTransparency=1,Position=UDim2.fromOffset(10,130),Size=UDim2.new(1,-20,0,32),Text="Path: -",TextColor3=Color3.fromRGB(125,240,190),Font=Enum.Font.Gotham,TextSize=9,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top},frame)

        local function button(text,x,width,callback)
            local b=inspectorMake("TextButton",{Position=UDim2.fromOffset(x,170),Size=UDim2.fromOffset(width,27),Text=text,TextColor3=Color3.fromRGB(245,248,255),Font=Enum.Font.GothamBold,TextSize=9,BackgroundColor3=Color3.fromRGB(75,91,132),BackgroundTransparency=0.08,BorderSizePixel=0},frame)
            inspectorCorner(b,6)
            b.MouseButton1Click:Connect(callback)
        end
        button("COPY PATH",9,82,function()
            if not self.Selected then status.Text="Pilih objek dahulu."; return end
            if type(setclipboard)=="function" and pcall(setclipboard,inspectorPath(self.Selected)) then status.Text="Full path berhasil disalin."
            else status.Text="Clipboard tidak tersedia di executor ini." end
        end)
        button("EXPORT JSON",96,92,function()
            if not self.Selected then status.Text="Pilih objek dahulu."; return end
            if type(writefile)~="function" or type(isfolder)~="function" or type(makefolder)~="function" then status.Text="File API tidak tersedia."; return end
            local ok,result=pcall(function()
                local folder="MobileInspectorExports"
                if not isfolder(folder) then makefolder(folder) end
                local safePart=tostring(self.Selected.Name):gsub('[%z\1-\31<>:"/\\|?*]',"_")
                local file=string.format("%s/%s_%s_%s.json",folder,inspectorMapName(),safePart,os.date("%H%M%S"))
                writefile(file,InspectorHttp:JSONEncode(inspectorSerialize(self.Selected)))
                return file
            end)
            status.Text=ok and ("Saved: "..result) or ("Export gagal: "..tostring(result))
        end)
        button("CLEAR",194,82,function()
            self.Selected=nil
            info.Text="Belum ada objek dipilih."
            path.Text="Path: -"
            status.Text="Pilihan dibersihkan."
        end)

        local dragging,dragInput,dragStart,startPos=false,nil,nil,nil
        local actionName="TryoInspectorDrag_"..tostring(InspectorPlayer.UserId)
        local function sink() return Enum.ContextActionResult.Sink end
        table.insert(self.Connections,top.InputBegan:Connect(function(input)
            if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
                dragging=true; dragInput=input; dragStart=input.Position; startPos=frame.Position
                pcall(function() game:GetService("ContextActionService"):BindActionAtPriority(actionName,sink,false,3000,Enum.UserInputType.MouseButton1,Enum.UserInputType.Touch) end)
            end
        end))
        table.insert(self.Connections,InspectorInput.InputChanged:Connect(function(input)
            if not dragging then return end
            local matches=input==dragInput or (dragInput and dragInput.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseMovement)
            if matches then
                local delta=input.Position-dragStart
                frame.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+delta.X,startPos.Y.Scale,startPos.Y.Offset+delta.Y)
            end
        end))
        table.insert(self.Connections,InspectorInput.InputEnded:Connect(function(input)
            if dragging and (input==dragInput or input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch) then
                dragging=false; dragInput=nil
                pcall(function() game:GetService("ContextActionService"):UnbindAction(actionName) end)
            end
        end))
        table.insert(self.Connections,InspectorInput.TouchTapInWorld:Connect(function(position,processed)
            if not self.Active or processed then return end
            local camera=InspectorWorkspace.CurrentCamera
            if not camera then return end
            local ray=camera:ViewportPointToRay(position.X,position.Y)
            local params=RaycastParams.new()
            params.FilterType=Enum.RaycastFilterType.Exclude
            if InspectorPlayer.Character then params.FilterDescendantsInstances={InspectorPlayer.Character} end
            local result=InspectorWorkspace:Raycast(ray.Origin,ray.Direction*500,params)
            if not result or not result.Instance then return end
            local selected=result.Instance
            self.Selected=selected
            local children={}
            for _,child in ipairs(selected:GetChildren()) do table.insert(children,child.Name.." ("..child.ClassName..")") end
            info.Text=string.format("Name: %s\nClass: %s\nChildren: %s",selected.Name,selected.ClassName,#children>0 and table.concat(children,", ") or "None")
            path.Text="Path: "..inspectorPath(selected)
            status.Text="Objek terpilih. Siap copy atau export."
        end))
        close.MouseButton1Click:Connect(function()
            if inspectorController then Features.MobileInspector.Stop() end
        end)
        return true
    end,
    Stop = function()
        local self=inspectorController
        if not self then return end
        self.Active=false
        for _,connection in ipairs(self.Connections) do pcall(function() connection:Disconnect() end) end
        pcall(function() game:GetService("ContextActionService"):UnbindAction("TryoInspectorDrag_"..tostring(InspectorPlayer.UserId)) end)
        if self.Gui then self.Gui:Destroy() end
        inspectorController=nil
    end
}

return Features
