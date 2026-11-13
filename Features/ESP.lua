-- Native standalone ESP features for beta2.
-- No Infinite Yield command registry, globals, or external dependencies.
local Players=game:GetService("Players")
local Workspace=game:GetService("Workspace")
local RunService=game:GetService("RunService")
local CollectionService=game:GetService("CollectionService")
local LocalPlayer=Players.LocalPlayer

local Features={}
local PLAYER_TAG="TryoBeta2_PlayerESP"
local ENEMY_TAG="TryoBeta2_EnemyESP"

local function rootOf(model)
    if not model then return nil end
    local root=model:FindFirstChild("HumanoidRootPart")
        or model:FindFirstChild("RootPart")
        or model.PrimaryPart
        or model:FindFirstChild("Torso")
        or model:FindFirstChild("UpperTorso")
    return root and root:IsA("BasePart") and root or nil
end

local function makeVisual(model,tag,color,label)
    if not model or not model.Parent then return end
    local highlight=model:FindFirstChild(tag)
    if not highlight then
        highlight=Instance.new("Highlight")
        highlight.Name=tag
        highlight.DepthMode=Enum.HighlightDepthMode.Occluded
        highlight.FillTransparency=0.72
        highlight.OutlineTransparency=0.08
        highlight.Parent=model
    end
    highlight.Adornee=model
    highlight.FillColor=color
    highlight.OutlineColor=color

    local billboard=model:FindFirstChild(tag.."_Name")
    if not billboard then
        billboard=Instance.new("BillboardGui")
        billboard.Name=tag.."_Name"
        billboard.Size=UDim2.fromOffset(150,24)
        billboard.StudsOffset=Vector3.new(0,3,0)
        billboard.AlwaysOnTop=false
        billboard.Parent=model
        local text=Instance.new("TextLabel")
        text.Name="Label"
        text.Size=UDim2.fromScale(1,1)
        text.BackgroundTransparency=1
        text.Font=Enum.Font.GothamSemibold
        text.TextSize=13
        text.TextStrokeTransparency=0.35
        text.TextColor3=color
        text.Parent=billboard
    end
    local text=billboard:FindFirstChild("Label")
    if text then text.Text=label; text.TextColor3=color end
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
    for _,key in ipairs({"Enemy","IsEnemy","Hostile","IsHostile","Monster","IsMonster","NPCEnemy"}) do
        local value=model:GetAttribute(key)
        if value==true or (type(value)=="number" and value>0) then return true end
        local child=model:FindFirstChild(key,true)
        if child and child:IsA("BoolValue") and child.Value then return true end
    end
    return CollectionService:HasTag(model,"Enemy")
        or CollectionService:HasTag(model,"Hostile")
        or CollectionService:HasTag(model,"Monster")
end

local playerRunning=false
local playerConnections={}
local playerCharacterConnections={}
local function addPlayer(player)
    if player==LocalPlayer or playerCharacterConnections[player] then return end
    playerCharacterConnections[player]=player.CharacterAdded:Connect(function(character)
        task.wait(0.2)
        if playerRunning and character and character.Parent then
            makeVisual(character,PLAYER_TAG,Color3.fromRGB(35,235,125),player.DisplayName)
        end
    end)
    if player.Character then makeVisual(player.Character,PLAYER_TAG,Color3.fromRGB(35,235,125),player.DisplayName) end
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
            end)
        }
        return true
    end,
    Stop=function()
        playerRunning=false
        for _,connection in ipairs(playerConnections) do connection:Disconnect() end
        table.clear(playerConnections)
        clearPlayers()
    end
}

local enemyRunning=false
local enemyConnection
local enemyModels={}
local enemyDescendantConnection

local function registerEnemyModel(model)
    if not enemyRunning or not model or not model:IsA("Model") then return end
    task.defer(function()
        if enemyRunning and model.Parent and isEnemyCandidate(model) then enemyModels[model]=true end
    end)
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
        makeVisual(model,ENEMY_TAG,Color3.fromRGB(255,75,75),model.Name)
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
        if enemyConnection then enemyConnection:Disconnect(); enemyConnection=nil end
        if enemyDescendantConnection then enemyDescendantConnection:Disconnect(); enemyDescendantConnection=nil end
        for model in pairs(enemyModels) do removeVisual(model,ENEMY_TAG) end
        table.clear(enemyModels)
    end
}
return Features
