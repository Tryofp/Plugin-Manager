-- Standalone player teleport panel for beta2.
-- Local client-side CFrame movement; game/server rules may prevent it.
local Players=game:GetService("Players")
local LocalPlayer=Players.LocalPlayer
local CoreGui=game:GetService("CoreGui")
local Feature={Name="Teleport to Player",Description="Membuka daftar pemain untuk berpindah ke dekat target."}

local gui
local connections={}
local list
local search
local running=false

local function disconnectAll()
    for _,connection in ipairs(connections) do
        pcall(function() connection:Disconnect() end)
    end
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
    local ownRoot=getRoot(LocalPlayer.Character)
    local targetRoot=getRoot(player.Character)
    if not ownRoot or not targetRoot then
        notify("Karakter target atau karakter kamu belum siap.")
        return
    end
    local ok,err=pcall(function()
        ownRoot.CFrame=targetRoot.CFrame*CFrame.new(0,0,3)
    end)
    if ok then notify("Permintaan teleport ke "..player.DisplayName.." dikirim.")
    else notify("Teleport gagal: "..tostring(err)) end
end

local function make(class,properties,parent)
    local object=Instance.new(class)
    for key,value in pairs(properties) do object[key]=value end
    object.Parent=parent
    return object
end

local function refresh()
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
                    Size=UDim2.new(1,-8,0,34),
                    BackgroundColor3=Color3.fromRGB(48,66,91),
                    BackgroundTransparency=0.12,
                    BorderSizePixel=0,
                    Font=Enum.Font.GothamMedium,
                    Text=player.DisplayName.."  @"..player.Name.."     TELEPORT",
                    TextColor3=Color3.fromRGB(245,248,255),
                    TextSize=12,
                    TextXAlignment=Enum.TextXAlignment.Left,
                    AutoButtonColor=true
                },list)
                make("UICorner",{CornerRadius=UDim.new(0,7)},row)
                table.insert(connections,row.MouseButton1Click:Connect(function() teleportTo(player) end))
            end
        end
    end
    list.CanvasSize=UDim2.new(0,0,0,count*38+6)
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
        Name="Panel",Size=UDim2.fromOffset(320,300),Position=UDim2.new(0.5,-160,0.5,-150),
        BackgroundColor3=Color3.fromRGB(37,52,75),BackgroundTransparency=0.08,BorderSizePixel=0
    },gui)
    make("UICorner",{CornerRadius=UDim.new(0,12)},panel)
    make("UIStroke",{Color=Color3.fromRGB(115,165,205),Transparency=0.35,Thickness=1},panel)
    local header=make("Frame",{Size=UDim2.new(1,0,0,38),BackgroundColor3=Color3.fromRGB(57,105,145),BorderSizePixel=0},panel)
    make("UICorner",{CornerRadius=UDim.new(0,12)},header)
    make("TextLabel",{
        Size=UDim2.new(1,-48,1,0),Position=UDim2.fromOffset(12,0),BackgroundTransparency=1,
        Font=Enum.Font.GothamBold,Text="TELEPORT TO PLAYER",TextColor3=Color3.new(1,1,1),
        TextSize=13,TextXAlignment=Enum.TextXAlignment.Left
    },header)
    local close=make("TextButton",{
        Size=UDim2.fromOffset(26,26),Position=UDim2.new(1,-32,0,6),BackgroundColor3=Color3.fromRGB(170,65,75),
        BorderSizePixel=0,Font=Enum.Font.GothamBold,Text="×",TextColor3=Color3.new(1,1,1),TextSize=18
    },header)
    make("UICorner",{CornerRadius=UDim.new(0,7)},close)
    search=make("TextBox",{
        Size=UDim2.new(1,-20,0,32),Position=UDim2.fromOffset(10,48),
        BackgroundColor3=Color3.fromRGB(24,37,56),BorderSizePixel=0,
        Font=Enum.Font.Gotham,PlaceholderText="Cari username / display name...",
        Text="",TextColor3=Color3.new(1,1,1),PlaceholderColor3=Color3.fromRGB(165,180,198),
        TextSize=12,ClearTextOnFocus=false
    },panel)
    make("UICorner",{CornerRadius=UDim.new(0,7)},search)
    list=make("ScrollingFrame",{
        Size=UDim2.new(1,-20,1,-91),Position=UDim2.fromOffset(10,86),
        BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,
        CanvasSize=UDim2.new(0,0,0,0)
    },panel)
    local layout=make("UIListLayout",{Padding=UDim.new(0,4),SortOrder=Enum.SortOrder.LayoutOrder},list)
    table.insert(connections,layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        if list then list.CanvasSize=UDim2.new(0,0,0,layout.AbsoluteContentSize.Y+6) end
    end))
    table.insert(connections,search:GetPropertyChangedSignal("Text"):Connect(refresh))
    table.insert(connections,Players.PlayerAdded:Connect(refresh))
    table.insert(connections,Players.PlayerRemoving:Connect(refresh))
    table.insert(connections,close.MouseButton1Click:Connect(function()
        if gui then gui.Enabled=false end
    end))
    refresh()
    return true
end

Feature.Start=function() return start() end
Feature.Stop=function()
    running=false
    disconnectAll()
    if gui then gui:Destroy(); gui=nil end
    list=nil
    search=nil
end
return {PlayerTeleport=Feature}
