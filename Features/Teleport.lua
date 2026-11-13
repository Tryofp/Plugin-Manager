-- Standalone player teleport panel for beta2.
-- Client-side movement only; authoritative game servers may reject or correct it.
local Players=game:GetService("Players")
local LocalPlayer=Players.LocalPlayer
local CoreGui=game:GetService("CoreGui")
local UserInputService=game:GetService("UserInputService")
local Feature={Name="Teleport to Player",Description="Membuka daftar pemain untuk berpindah ke dekat target."}

local gui
local connections={}
local rowConnections={}
local list
local search
local running=false

local function disconnectRows()
    for _,connection in ipairs(rowConnections) do pcall(function() connection:Disconnect() end) end
    table.clear(rowConnections)
end

local function disconnectAll()
    disconnectRows()
    for _,connection in ipairs(connections) do pcall(function() connection:Disconnect() end) end
    table.clear(connections)
end

local function notify(message)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification",{Title="Teleport",Text=message,Duration=3})
    end)
end

local function getRoot(character)
    if not character then return nil end
    return character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
end

local function teleportTo(player)
    if not player or player==LocalPlayer then return end
    local character=LocalPlayer.Character
    local targetRoot=getRoot(player.Character)
    local ownRoot=getRoot(character)
    if not character or not ownRoot or not targetRoot then
        notify("Karakter target atau karakter kamu belum siap.")
        return
    end
    local destination=targetRoot.CFrame*CFrame.new(0,0,3)
    local ok,err=pcall(function()
        character:PivotTo(destination)
        ownRoot.AssemblyLinearVelocity=Vector3.zero
        ownRoot.AssemblyAngularVelocity=Vector3.zero
    end)
    if ok then
        notify("Posisi dipindahkan ke dekat "..player.DisplayName..". Jika kembali, server game menolak teleport client.")
    else
        notify("Teleport gagal: "..tostring(err))
    end
end

local function make(class,properties,parent)
    local object=Instance.new(class)
    for key,value in pairs(properties) do object[key]=value end
    object.Parent=parent
    return object
end

local function refresh()
    disconnectRows()
    if not list or not list.Parent then return end
    for _,child in ipairs(list:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    local query=string.lower(search and search.Text or "")
    local count=0
    for _,player in ipairs(Players:GetPlayers()) do
        if player~=LocalPlayer then
            local haystack=string.lower(player.Name.." "..player.DisplayName)
            if query=="" or string.find(haystack,query,1,true) then
                count=count+1
                local row=make("TextButton",{
                    Name="Player_"..player.UserId,
                    Size=UDim2.new(1,-6,0,31),
                    BackgroundColor3=Color3.fromRGB(62,82,112),
                    BackgroundTransparency=0.24,
                    BorderSizePixel=0,
                    Font=Enum.Font.GothamMedium,
                    Text=player.DisplayName.."  @"..player.Name.."   ›",
                    TextColor3=Color3.fromRGB(245,248,255),
                    TextSize=11,
                    TextXAlignment=Enum.TextXAlignment.Left,
                    AutoButtonColor=true
                },list)
                make("UICorner",{CornerRadius=UDim.new(0,7)},row)
                make("UIPadding",{PaddingLeft=UDim.new(0,9)},row)
                table.insert(rowConnections,row.MouseButton1Click:Connect(function() teleportTo(player) end))
            end
        end
    end
    list.CanvasSize=UDim2.new(0,0,0,count*35+5)
end

local function start()
    if running then
        if gui then gui.Enabled=true end
        return true
    end
    running=true
    gui=make("ScreenGui",{Name="TryoBeta2_PlayerTeleport",ResetOnSpawn=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},nil)
    local parentOk=pcall(function() gui.Parent=CoreGui end)
    if not parentOk then gui.Parent=LocalPlayer:WaitForChild("PlayerGui") end

    local panel=make("Frame",{
        Name="Panel",Size=UDim2.fromOffset(270,245),Position=UDim2.new(0.5,-135,0.5,-122),
        BackgroundColor3=Color3.fromRGB(42,58,84),BackgroundTransparency=0.24,BorderSizePixel=0,
        Active=true,ClipsDescendants=true
    },gui)
    make("UICorner",{CornerRadius=UDim.new(0,12)},panel)
    make("UIStroke",{Color=Color3.fromRGB(125,174,218),Transparency=0.38,Thickness=1},panel)
    make("UIGradient",{
        Color=ColorSequence.new({
            ColorSequenceKeypoint.new(0,Color3.fromRGB(67,112,151)),
            ColorSequenceKeypoint.new(0.55,Color3.fromRGB(91,69,133)),
            ColorSequenceKeypoint.new(1,Color3.fromRGB(38,91,105))
        }),Rotation=28
    },panel)

    local header=make("Frame",{
        Name="Header",Size=UDim2.new(1,0,0,36),
        BackgroundColor3=Color3.fromRGB(67,126,164),BackgroundTransparency=0.25,
        BorderSizePixel=0,Active=true
    },panel)
    make("UIGradient",{Color=ColorSequence.new(Color3.fromRGB(66,157,184),Color3.fromRGB(132,83,174)),Rotation=0},header)
    make("TextLabel",{
        Size=UDim2.new(1,-48,1,0),Position=UDim2.fromOffset(11,0),BackgroundTransparency=1,
        Font=Enum.Font.GothamBold,Text="TELEPORT TO PLAYER",TextColor3=Color3.new(1,1,1),
        TextSize=12,TextXAlignment=Enum.TextXAlignment.Left
    },header)
    local close=make("TextButton",{
        Size=UDim2.fromOffset(25,25),Position=UDim2.new(1,-30,0,5),BackgroundColor3=Color3.fromRGB(170,65,85),
        BackgroundTransparency=0.12,BorderSizePixel=0,Font=Enum.Font.GothamBold,
        Text="×",TextColor3=Color3.new(1,1,1),TextSize=17
    },header)
    make("UICorner",{CornerRadius=UDim.new(0,7)},close)
    search=make("TextBox",{
        Size=UDim2.new(1,-18,0,30),Position=UDim2.fromOffset(9,44),
        BackgroundColor3=Color3.fromRGB(23,35,54),BackgroundTransparency=0.28,BorderSizePixel=0,
        Font=Enum.Font.Gotham,PlaceholderText="Cari username / display name...",
        Text="",TextColor3=Color3.new(1,1,1),PlaceholderColor3=Color3.fromRGB(190,202,218),
        TextSize=11,ClearTextOnFocus=false
    },panel)
    make("UICorner",{CornerRadius=UDim.new(0,7)},search)
    list=make("ScrollingFrame",{
        Size=UDim2.new(1,-18,1,-84),Position=UDim2.fromOffset(9,80),
        BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,
        CanvasSize=UDim2.new(0,0,0,0)
    },panel)
    local layout=make("UIListLayout",{Padding=UDim.new(0,4),SortOrder=Enum.SortOrder.LayoutOrder},list)
    table.insert(connections,layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        if list then list.CanvasSize=UDim2.new(0,0,0,layout.AbsoluteContentSize.Y+5) end
    end))
    table.insert(connections,search:GetPropertyChangedSignal("Text"):Connect(refresh))
    table.insert(connections,Players.PlayerAdded:Connect(refresh))
    table.insert(connections,Players.PlayerRemoving:Connect(refresh))
    table.insert(connections,close.MouseButton1Click:Connect(function()
        if gui then gui.Enabled=false end
    end))

    -- Drag panel from its header; sink pointer input to avoid moving the camera.
    local dragging=false
    local dragStart
    local startPosition
    local dragInput
    local dragAction="TryoTeleportPanelDrag_"..tostring(LocalPlayer.UserId)
    table.insert(connections,header.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            dragging=true
            dragStart=input.Position
            startPosition=panel.Position
            UserInputService.InputBegan:Connect(function() end)
            input.Changed:Connect(function()
                if input.UserInputState==Enum.UserInputState.End then
                    dragging=false
                    game:GetService("ContextActionService"):UnbindAction(dragAction)
                end
            end)
            game:GetService("ContextActionService"):BindActionAtPriority(
                dragAction,function() return Enum.ContextActionResult.Sink end,false,
                Enum.ContextActionPriority.High.Value,Enum.UserInputType.MouseButton1,Enum.UserInputType.Touch
            )
        end
    end))
    table.insert(connections,header.InputChanged:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch then dragInput=input end
    end))
    table.insert(connections,UserInputService.InputChanged:Connect(function(input)
        if dragging and (input==dragInput or input.UserInputType==Enum.UserInputType.Touch) then
            local delta=input.Position-dragStart
            panel.Position=UDim2.new(startPosition.X.Scale,startPosition.X.Offset+delta.X,
                startPosition.Y.Scale,startPosition.Y.Offset+delta.Y)
        end
    end))
    refresh()
    return true
end

Feature.Start=function() return start() end
Feature.Stop=function()
    running=false
    disconnectAll()
    game:GetService("ContextActionService"):UnbindAction("TryoTeleportPanelDrag_"..tostring(LocalPlayer.UserId))
    if gui then gui:Destroy(); gui=nil end
    list=nil
    search=nil
end
return {PlayerTeleport=Feature}
