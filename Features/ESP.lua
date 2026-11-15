-- Native standalone ESP features for beta2.
-- No Infinite Yield command registry, globals, or external dependencies.
local Players=game:GetService("Players")
local Workspace=game:GetService("Workspace")
local RunService=game:GetService("RunService")
local CollectionService=game:GetService("CollectionService")
local Lighting=game:GetService("Lighting")
local UserInputService=game:GetService("UserInputService")
local LocalPlayer=Players.LocalPlayer

local Features={}
local PLAYER_TAG="TryoBeta2_PlayerESP"
local ENEMY_TAG="TryoBeta2_EnemyESP"

local function rootOf(model)
    if not model then return nil end
    local root=model:FindFirstChild("HumanoidRootPart",true)
        or model:FindFirstChild("RootPart",true)
        or model:FindFirstChild("Root",true)
        or model:FindFirstChild("PrimaryPart",true)
        or model:FindFirstChild("UpperTorso",true)
        or model:FindFirstChild("Torso",true)
        or model:FindFirstChild("Body",true)
        or model:FindFirstChild("Head",true)
        or model.PrimaryPart
    return root and root:IsA("BasePart") and root or nil
end

local function makeVisual(model,tag,color,label,depthMode)
    if not model or not model.Parent then return end
    local highlight=model:FindFirstChild(tag)
    if not highlight then
        highlight=Instance.new("Highlight")
        highlight.Name=tag
        highlight.DepthMode=depthMode or Enum.HighlightDepthMode.AlwaysOnTop
        highlight.FillTransparency=0.72
        highlight.OutlineTransparency=0.08
        highlight.Parent=model
    end
    highlight.Adornee=model
    highlight.DepthMode=depthMode or Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor=color
    highlight.OutlineColor=color

    local billboard=model:FindFirstChild(tag.."_Name")
    local adornee=model:FindFirstChild("Head",true) or rootOf(model)
    if not adornee or not adornee:IsA("BasePart") then return end

    if not billboard then
        billboard=Instance.new("BillboardGui")
        billboard.Name=tag.."_Name"
        billboard.Size=UDim2.fromOffset(220,35)
        billboard.StudsOffset=Vector3.new(0,3,0)
        billboard.AlwaysOnTop=true
        billboard.Parent=model
        local text=Instance.new("TextLabel")
        text.Name="Label"
        text.Size=UDim2.fromScale(1,1)
        text.BackgroundTransparency=1
        text.Font=Enum.Font.GothamBold
        text.TextSize=14
        text.TextStrokeTransparency=0.2
        text.TextStrokeColor3=Color3.new(0,0,0)
        text.TextColor3=color
        text.Parent=billboard
    end

    -- Rebind on every pass: character parts can stream in or be replaced.
    billboard.Adornee=adornee
    billboard.MaxDistance=math.huge
    billboard.AlwaysOnTop=true

    local text=billboard:FindFirstChild("Label")
    if text then
        text.Text=label
        text.TextColor3=color
        text.Font=Enum.Font.GothamBold
        text.TextStrokeTransparency=0.2
        text.TextStrokeColor3=Color3.new(0,0,0)
    end
end

local function removeVisual(model,tag)
    if not model then return end
    for _,name in ipairs({tag,tag.."_Name"}) do
        local object=model:FindFirstChild(name)
        if object then object:Destroy() end
    end
end

local function isPlayerModel(model)
    return Players:GetPlayerFromCharacter(model)~=nil
end

local function isEnemyCandidate(model)
    if not model or not model:IsA("Model") or isPlayerModel(model) then return false end
    if not rootOf(model) then return false end
    if model:FindFirstChildOfClass("Humanoid") or model:FindFirstChildOfClass("AnimationController") then
        return true
    end
    local markerNames={"Enemy","IsEnemy","Hostile","IsHostile","IsMonster","Monster","IsNPCEnemy","NPCEnemy"}
    for _,key in ipairs(markerNames) do
        local value=model:GetAttribute(key)
        if value==true or (type(value)=="number" and value>0) then return true end
        if type(value)=="string" then
            local text=string.lower(value)
            if text=="enemy" or text=="hostile" or text=="monster" or text=="true" then return true end
        end
        local child=model:FindFirstChild(key,true)
        if child then
            if child:IsA("BoolValue") and child.Value then return true end
            if child:IsA("NumberValue") and child.Value>0 then return true end
            if child:IsA("StringValue") then
                local text=string.lower(tostring(child.Value))
                if text=="enemy" or text=="hostile" or text=="monster" or text=="true" then return true end
            end
        end
    end
    return CollectionService:HasTag(model,"Enemy")
        or CollectionService:HasTag(model,"Hostile")
        or CollectionService:HasTag(model,"Monster")
end

local playerRunning=false
local playerConnections={}
local playerCharacterConnections={}
local PLAYER_COLOR=Color3.fromRGB(35,235,125)

local function applyPlayerVisual(player)
    if not playerRunning or player==LocalPlayer then return end
    local character=player.Character
    if not character or not character.Parent then return end
    -- This is intentionally safe to call repeatedly. If Head/root has not
    -- replicated yet, the next reconciliation pass will attach the ESP.
    makeVisual(character,PLAYER_TAG,PLAYER_COLOR,player.DisplayName)
end

local function addPlayer(player)
    if player==LocalPlayer or playerCharacterConnections[player] then return end
    playerCharacterConnections[player]=player.CharacterAdded:Connect(function(character)
        -- Remove stale visuals from the previous character, then retry after
        -- Roblox has had time to replicate the new character's body parts.
        task.defer(function()
            if playerRunning and character then
                applyPlayerVisual(player)
            end
        end)
        task.delay(0.35,function()
            if playerRunning and player.Character==character and character.Parent then
                applyPlayerVisual(player)
            end
        end)
    end)
    applyPlayerVisual(player)
end

local function clearPlayers()
    for _,player in ipairs(Players:GetPlayers()) do
        if player.Character then removeVisual(player.Character,PLAYER_TAG) end
    end
    for _,connection in pairs(playerCharacterConnections) do connection:Disconnect() end
    table.clear(playerCharacterConnections)
end

Features.PlayerESP={
    Name="Player ESP",Description="Menandai karakter pemain lain dengan highlight hijau.",
    Start=function()
        if playerRunning then return true end
        playerRunning=true
        for _,player in ipairs(Players:GetPlayers()) do addPlayer(player) end
        playerConnections={
            Players.PlayerAdded:Connect(addPlayer),
            Players.PlayerRemoving:Connect(function(player)
                if player.Character then removeVisual(player.Character,PLAYER_TAG) end
                local connection=playerCharacterConnections[player]
                if connection then connection:Disconnect(); playerCharacterConnections[player]=nil end
            end),
            -- Reconcile periodically so late/streamed body parts, replaced
            -- heads, and transient character replication cannot leave gaps.
            RunService.Heartbeat:Connect(function(dt)
                playerConnections._elapsed=(playerConnections._elapsed or 0)+dt
                if playerConnections._elapsed>=0.75 then
                    playerConnections._elapsed=0
                    for _,player in ipairs(Players:GetPlayers()) do
                        if player~=LocalPlayer then applyPlayerVisual(player) end
                    end
                end
            end)
        }
        return true
    end,
    Stop=function()
        playerRunning=false
        for _,connection in pairs(playerConnections) do
            if typeof(connection)=="RBXScriptConnection" then connection:Disconnect() end
        end
        table.clear(playerConnections)
        clearPlayers()
    end
}

local enemyRunning=false
local enemyConnection
local enemyModels={}
local confirmedEnemies={}
local damageConnection
local characterConnection
local enemyExtraConnections={}
local watchedCamera
local cameraChildConnection
local lastThreatTime=0
local effectSnapshot={}
local previousCameraCFrame
local shakeWindowStart=0
local shakeSamples=0
local lastManualCameraInput=-math.huge
local previousFOV=70

local NPC_COLOR=Color3.fromRGB(255,170,0)
local ENEMY_COLOR=Color3.fromRGB(255,0,0)
local DAMAGE_SEARCH_RADIUS=100
local THREAT_SEARCH_RADIUS=150
local THREAT_COOLDOWN=1.5

local function findNearestEnemy(origin,radius)
    if not origin then return nil end
    local nearest,nearestDistanceSquared=nil,radius*radius
    for model in pairs(enemyModels) do
        if model and model.Parent and isEnemyCandidate(model) then
            local root=rootOf(model)
            if root then
                local offset=root.Position-origin
                local distanceSquared=offset:Dot(offset)
                if distanceSquared<=nearestDistanceSquared then
                    nearest=model
                    nearestDistanceSquared=distanceSquared
                end
            end
        end
    end

    -- Match Beta's nearby-world fallback so streamed/late-registered NPCs can
    -- still be considered immediately when damage or a threat signal occurs.
    local overlap=OverlapParams.new()
    overlap.FilterType=Enum.RaycastFilterType.Exclude
    if LocalPlayer.Character then overlap.FilterDescendantsInstances={LocalPlayer.Character} end
    local ok,parts=pcall(function()
        return Workspace:GetPartBoundsInRadius(origin,radius,overlap)
    end)
    if ok and parts then
        for _,part in ipairs(parts) do
            local model=part:FindFirstAncestorOfClass("Model")
            if model and model.Parent and not isPlayerModel(model) and isEnemyCandidate(model) then
                enemyModels[model]=true
                local root=rootOf(model)
                if root then
                    local offset=root.Position-origin
                    local distanceSquared=offset:Dot(offset)
                    if distanceSquared<=nearestDistanceSquared then
                        nearest=model
                        nearestDistanceSquared=distanceSquared
                    end
                end
            end
        end
    end
    return nearest
end

local function confirmNearestEnemy(reason,radius)
    local localRoot=rootOf(LocalPlayer.Character)
    if not localRoot then return end
    local enemy=findNearestEnemy(localRoot.Position,radius or DAMAGE_SEARCH_RADIUS)
    if enemy then confirmedEnemies[enemy]=true end
end

local function triggerThreat(reason)
    if not enemyRunning then return end
    local now=os.clock()
    if now-lastThreatTime<THREAT_COOLDOWN then return end
    lastThreatTime=now
    confirmNearestEnemy("THREAT_"..tostring(reason),THREAT_SEARCH_RADIUS)
end

local function watchLocalCharacter(character)
    if damageConnection then damageConnection:Disconnect(); damageConnection=nil end
    task.spawn(function()
        local humanoid=character and character:WaitForChild("Humanoid",5)
        if not humanoid or not enemyRunning then return end
        local previousHealth=humanoid.Health
        damageConnection=humanoid.HealthChanged:Connect(function(newHealth)
            if not enemyRunning then return end
            if newHealth<previousHealth then
                triggerThreat("DAMAGE")
                confirmNearestEnemy("PLAYER_DAMAGE",DAMAGE_SEARCH_RADIUS)
            end
            previousHealth=newHealth
        end)
    end)
end
local enemyDescendantConnection

local function registerEnemyModel(model)
    if not enemyRunning or not model or not model:IsA("Model") then return end
    task.defer(function()
        if enemyRunning and model.Parent and isEnemyCandidate(model) then enemyModels[model]=true end
    end)
end

local function effectKey(object)
    if object:IsA("BlurEffect") then return "Blur:"..object:GetFullName() end
    if object:IsA("ColorCorrectionEffect") then return "Color:"..object:GetFullName() end
    if object:IsA("DepthOfFieldEffect") then return "DOF:"..object:GetFullName() end
    return nil
end

local function effectState(object)
    if object:IsA("BlurEffect") then return tostring(object.Size) end
    if object:IsA("ColorCorrectionEffect") then
        return table.concat({tostring(object.Brightness),tostring(object.Contrast),tostring(object.Saturation),tostring(object.TintColor)},"|")
    end
    if object:IsA("DepthOfFieldEffect") then
        return table.concat({tostring(object.FarIntensity),tostring(object.FocusDistance),tostring(object.InFocusRadius),tostring(object.NearIntensity)},"|")
    end
    return ""
end

local function scanPostEffects()
    for _,container in ipairs({Lighting,watchedCamera}) do
        if container then
            for _,object in ipairs(container:GetChildren()) do
                local key=effectKey(object)
                if key then
                    local state=effectState(object)
                    local previous=effectSnapshot[key]
                    if previous==nil then effectSnapshot[key]=state
                    elseif previous~=state then
                        effectSnapshot[key]=state
                        triggerThreat(object.ClassName)
                    end
                end
            end
        end
    end
end

local function watchCurrentCamera()
    if cameraChildConnection then cameraChildConnection:Disconnect(); cameraChildConnection=nil end
    watchedCamera=Workspace.CurrentCamera
    previousCameraCFrame=watchedCamera and watchedCamera.CFrame or nil
    previousFOV=watchedCamera and watchedCamera.FieldOfView or 70
    if watchedCamera then
        cameraChildConnection=watchedCamera.ChildAdded:Connect(function(object)
            if effectKey(object) then
                task.delay(0.05,function()
                    if enemyRunning then triggerThreat("CAMERA_"..object.ClassName) end
                end)
            end
        end)
    end
end

local function startThreatWatchers()
    table.insert(enemyExtraConnections,Lighting.ChildAdded:Connect(function(object)
        if effectKey(object) then
            task.delay(0.05,function()
                if enemyRunning then triggerThreat("NEW_"..object.ClassName) end
            end)
        end
    end))
    table.insert(enemyExtraConnections,Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCurrentCamera))
    table.insert(enemyExtraConnections,UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.Touch then lastManualCameraInput=os.clock() end
    end))
    table.insert(enemyExtraConnections,UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.Touch then lastManualCameraInput=os.clock() end
    end))
    table.insert(enemyExtraConnections,RunService.Heartbeat:Connect(function()
        if not enemyRunning then return end
        local now=os.clock()
        local camera=Workspace.CurrentCamera
        if not camera then return end
        if now-(enemyExtraConnections._lastEffectScan or 0)>=0.15 then
            enemyExtraConnections._lastEffectScan=now
            scanPostEffects()
        end
        if now-(enemyExtraConnections._lastCameraScan or 0)>=0.1 then
            enemyExtraConnections._lastCameraScan=now
            local current=camera.CFrame
            if UserInputService.TouchEnabled and now-lastManualCameraInput<0.4 then
                previousCameraCFrame=current
                shakeSamples=0
                shakeWindowStart=now
            elseif previousCameraCFrame then
                local relative=previousCameraCFrame:ToObjectSpace(current)
                local rx,ry,rz=relative:ToOrientation()
                local angle=math.max(math.abs(rx),math.abs(ry),math.abs(rz))
                if angle>=math.rad(7) then
                    if now-shakeWindowStart>0.22 then
                        shakeWindowStart=now
                        shakeSamples=1
                    else
                        shakeSamples=shakeSamples+1
                    end
                    if shakeSamples>=3 then
                        triggerThreat("CAMERA_SHAKE")
                        shakeSamples=0
                        shakeWindowStart=now
                    end
                end
            end
            previousCameraCFrame=current
            if math.abs(camera.FieldOfView-previousFOV)>=4 then triggerThreat("FOV_CHANGE") end
            previousFOV=camera.FieldOfView
        end
    end))
    watchCurrentCamera()
end

local function scanEnemies()
    local localRoot=rootOf(LocalPlayer.Character)
    local candidates={}
    if not localRoot then return end
    for model in pairs(enemyModels) do
        if not model or not model.Parent then
            enemyModels[model]=nil
        elseif isEnemyCandidate(model) then
            local root=rootOf(model)
            if root then
                local offset=root.Position-localRoot.Position
                local distanceSquared=offset:Dot(offset)
                if distanceSquared<=180*180 then
                    table.insert(candidates,{model=model,distanceSquared=distanceSquared})
                end
            end
        else
            enemyModels[model]=nil
        end
    end
    table.sort(candidates,function(a,b) return a.distanceSquared<b.distanceSquared end)
    local active={}
    for i=1,math.min(#candidates,12) do
        local model=candidates[i].model
        active[model]=true
        local confirmed=confirmedEnemies[model]==true
        local color=confirmed and ENEMY_COLOR or NPC_COLOR
        local depthMode=confirmed and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
        makeVisual(model,ENEMY_TAG,color,(confirmed and "HOSTILE | " or "NPC | ")..model.Name,depthMode)
    end
    for model in pairs(enemyModels) do
        if not active[model] then removeVisual(model,ENEMY_TAG) end
    end
end

Features.EnemyESP={
    Name="Enemy ESP",Description="Menandai NPC/entitas musuh yang terdeteksi (maks. 12 dalam jarak 180 stud).",
    Start=function()
        if enemyRunning then return true end
        enemyRunning=true
        table.clear(enemyExtraConnections)
        table.clear(effectSnapshot)
        lastThreatTime=0
        shakeSamples=0
        lastManualCameraInput=-math.huge
        if LocalPlayer.Character then watchLocalCharacter(LocalPlayer.Character) end
        characterConnection=LocalPlayer.CharacterAdded:Connect(function(character)
            if enemyRunning then watchLocalCharacter(character) end
        end)
        startThreatWatchers()
        for _,object in ipairs(Workspace:GetDescendants()) do
            if object:IsA("Model") and isEnemyCandidate(object) then
                enemyModels[object]=true
            end
        end
        enemyDescendantConnection=Workspace.DescendantAdded:Connect(function(object)
            if object:IsA("Model") then registerEnemyModel(object)
            else
                local model=object:FindFirstAncestorOfClass("Model")
                if model then registerEnemyModel(model) end
            end
        end)
        local elapsed=0
        enemyConnection=RunService.Heartbeat:Connect(function(dt)
            elapsed=elapsed+dt
            if elapsed>=0.75 then elapsed=0; scanEnemies() end
        end)
        scanEnemies()
        return true
    end,
    Stop=function()
        enemyRunning=false
        if damageConnection then damageConnection:Disconnect(); damageConnection=nil end
        if characterConnection then characterConnection:Disconnect(); characterConnection=nil end
        if enemyConnection then enemyConnection:Disconnect(); enemyConnection=nil end
        if enemyDescendantConnection then enemyDescendantConnection:Disconnect(); enemyDescendantConnection=nil end
        if cameraChildConnection then cameraChildConnection:Disconnect(); cameraChildConnection=nil end
        for _,connection in ipairs(enemyExtraConnections) do
            if typeof(connection)=="RBXScriptConnection" then connection:Disconnect() end
        end
        table.clear(enemyExtraConnections)
        watchedCamera=nil
        table.clear(effectSnapshot)
        for model in pairs(enemyModels) do removeVisual(model,ENEMY_TAG) end
        table.clear(enemyModels)
        table.clear(confirmedEnemies)
    end
}
return Features
