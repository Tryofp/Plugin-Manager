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


Features.MobileInspector = local controller
local function make(className, props, parent)
    local object = Instance.new(className)
    for key, value in pairs(props or {}) do object[key] = value end
    object.Parent = parent
    return object
end
local function round(parent, radius)
    make("UICorner", {CornerRadius = UDim.new(0, radius or 8)}, parent)
end
local function getPath(instance)
    local ok, path = pcall(function() return instance:GetFullName() end)
    return ok and path or (instance and instance.Name or "Unknown")
end
local function safeClipboard(value)
    if type(setclipboard) ~= "function" then return false end
    return pcall(setclipboard, value)
end
local function getMapName()
    local ok, info = pcall(function() return MarketplaceService:GetProductInfo(game.PlaceId) end)
    local name = ok and info and info.Name or ("Place_" .. tostring(game.PlaceId))
    return tostring(name):gsub('[%z\1-\31<>:"/\\|?*]', "_")
end
local function serialize(instance)
    local data = {
        Name = instance.Name,
        ClassName = instance.ClassName,
        Path = getPath(instance),
        Properties = {},
        Children = {}
    }
    pcall(function()
        if instance:IsA("BasePart") then
            data.Properties.Position = {instance.Position.X, instance.Position.Y, instance.Position.Z}
            data.Properties.Size = {instance.Size.X, instance.Size.Y, instance.Size.Z}
            data.Properties.Anchored = instance.Anchored
            data.Properties.CanCollide = instance.CanCollide
        elseif instance:IsA("Model") then
            data.Properties.PrimaryPart = instance.PrimaryPart and instance.PrimaryPart.Name or nil
        end
    end)
    for _, child in ipairs(instance:GetChildren()) do
        table.insert(data.Children, {Name = child.Name, ClassName = child.ClassName})
    end
    return data
end

function Feature.Start()
    if controller then return true end
    local self = {Connections = {}, Selected = nil, Active = true}
    controller = self

    local gui = make("ScreenGui", {
        Name = "TryoMobileInspector",
        ResetOnSpawn = false,
        DisplayOrder = 999990,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    })
    local parent
    pcall(function() parent = game:GetService("CoreGui") end)
    if parent then
        local ok = pcall(function() gui.Parent = parent end)
        if not ok then parent = nil end
    end
    if not parent then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
    self.Gui = gui

    local frame = make("Frame", {
        Name = "Panel",
        Size = UDim2.fromOffset(286, 210),
        Position = UDim2.new(1, -298, 0.5, -105),
        BackgroundColor3 = Color3.fromRGB(30, 39, 58),
        BackgroundTransparency = 0.16,
        BorderSizePixel = 0,
        Active = true
    }, gui)
    round(frame, 10)
    make("UIStroke", {Color = Color3.fromRGB(110, 145, 190), Transparency = 0.45}, frame)
    make("UIGradient", {
        Color = ColorSequence.new(Color3.fromRGB(48, 77, 111), Color3.fromRGB(79, 53, 112)),
        Rotation = 25
    }, frame)

    local top = make("Frame", {
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = Color3.fromRGB(53, 90, 128),
        BackgroundTransparency = 0.12,
        BorderSizePixel = 0,
        Active = true
    }, frame)
    round(top, 9)
    local title = make("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(10, 0),
        Size = UDim2.new(1, -74, 1, 0),
        Text = "MOBILE INSPECTOR",
        TextColor3 = Color3.fromRGB(245, 248, 255),
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left
    }, top)
    local close = make("TextButton", {
        Size = UDim2.fromOffset(26, 25),
        Position = UDim2.new(1, -31, 0, 4),
        Text = "×",
        TextSize = 18,
        Font = Enum.Font.GothamBold,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundColor3 = Color3.fromRGB(160, 70, 90),
        BorderSizePixel = 0
    }, top)
    round(close, 6)

    local status = make("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(10, 39),
        Size = UDim2.new(1, -20, 0, 18),
        Text = "Tap objek di map untuk memilih",
        TextColor3 = Color3.fromRGB(110, 220, 240),
        Font = Enum.Font.GothamMedium,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left
    }, frame)
    local info = make("TextLabel", {
        BackgroundColor3 = Color3.fromRGB(18, 24, 37),
        BackgroundTransparency = 0.18,
        Position = UDim2.fromOffset(9, 61),
        Size = UDim2.new(1, -18, 0, 65),
        Text = "Belum ada objek dipilih.",
        TextColor3 = Color3.fromRGB(235, 239, 248),
        Font = Enum.Font.Gotham,
        TextSize = 10,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top
    }, frame)
    round(info, 6)
    make("UIPadding", {PaddingLeft = UDim.new(0, 7), PaddingTop = UDim.new(0, 6), PaddingRight = UDim.new(0, 5)}, info)
    local path = make("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(10, 130),
        Size = UDim2.new(1, -20, 0, 32),
        Text = "Path: -",
        TextColor3 = Color3.fromRGB(125, 240, 190),
        Font = Enum.Font.Gotham,
        TextSize = 9,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top
    }, frame)

    local function actionButton(text, x, width, callback)
        local b = make("TextButton", {
            Position = UDim2.fromOffset(x, 170),
            Size = UDim2.fromOffset(width, 27),
            Text = text,
            TextColor3 = Color3.fromRGB(245, 248, 255),
            Font = Enum.Font.GothamBold,
            TextSize = 9,
            BackgroundColor3 = Color3.fromRGB(75, 91, 132),
            BackgroundTransparency = 0.08,
            BorderSizePixel = 0
        }, frame)
        round(b, 6)
        b.MouseButton1Click:Connect(callback)
    end
    actionButton("COPY PATH", 9, 82, function()
        if not self.Selected then status.Text = "Pilih objek dahulu."; return end
        if safeClipboard(getPath(self.Selected)) then status.Text = "Full path berhasil disalin."
        else status.Text = "Clipboard tidak tersedia di executor ini." end
    end)
    actionButton("EXPORT JSON", 96, 92, function()
        if not self.Selected then status.Text = "Pilih objek dahulu."; return end
        if type(writefile) ~= "function" or type(isfolder) ~= "function" or type(makefolder) ~= "function" then
            status.Text = "File API tidak tersedia di executor ini."; return
        end
        local ok, result = pcall(function()
            local folder = "MobileInspectorExports"
            if not isfolder(folder) then makefolder(folder) end
            local data = serialize(self.Selected)
            local safePart = tostring(self.Selected.Name):gsub('[%z\1-\31<>:"/\\|?*]', "_")
            local file = string.format("%s/%s_%s_%s.json", folder, getMapName(), safePart, os.date("%H%M%S"))
            writefile(file, HttpService:JSONEncode(data))
            return file
        end)
        status.Text = ok and ("Saved: " .. result) or ("Export gagal: " .. tostring(result))
    end)
    actionButton("CLEAR", 194, 82, function()
        self.Selected = nil
        info.Text = "Belum ada objek dipilih."
        path.Text = "Path: -"
        status.Text = "Pilihan dibersihkan."
    end)

    local dragging, dragInput, dragStart, startPos
    local function inputSink() return Enum.ContextActionResult.Sink end
    local actionName = "TryoInspectorDrag_" .. tostring(LocalPlayer.UserId)
    local function beginDrag(input)
        dragging = true
        dragStart = input.Position
        startPos = frame.Position
        dragInput = input
        pcall(function()
            game:GetService("ContextActionService"):BindActionAtPriority(actionName, inputSink, false, 3000,
                Enum.UserInputType.MouseButton1, Enum.UserInputType.Touch)
        end)
    end
    table.insert(self.Connections, top.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            beginDrag(input)
        end
    end))
    table.insert(self.Connections, UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        local matches = input == dragInput or
            (dragInput and dragInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement)
        if matches then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end))
    table.insert(self.Connections, UserInputService.InputEnded:Connect(function(input)
        if dragging and (input == dragInput or input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            dragging = false
            dragInput = nil
            pcall(function() game:GetService("ContextActionService"):UnbindAction(actionName) end)
        end
    end))

    table.insert(self.Connections, UserInputService.TouchTapInWorld:Connect(function(position, processed)
        if not self.Active or processed then return end
        local camera = Workspace.CurrentCamera
        if not camera then return end
        local ray = camera:ViewportPointToRay(position.X, position.Y)
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        if LocalPlayer.Character then params.FilterDescendantsInstances = {LocalPlayer.Character} end
        local result = Workspace:Raycast(ray.Origin, ray.Direction * 500, params)
        if not result or not result.Instance then return end
        local selected = result.Instance
        self.Selected = selected
        local children = {}
        for _, child in ipairs(selected:GetChildren()) do
            table.insert(children, child.Name .. " (" .. child.ClassName .. ")")
        end
        info.Text = string.format("Name: %s\nClass: %s\nChildren: %s", selected.Name, selected.ClassName,
            #children > 0 and table.concat(children, ", ") or "None")
        path.Text = "Path: " .. getPath(selected)
        status.Text = "Objek terpilih. Siap copy atau export."
    end))

    close.MouseButton1Click:Connect(function()
        if controller then Feature.Stop() end
    end)
    return true
end

function Feature.Stop()
    local self = controller
    if not self then return end
    self.Active = false
    for _, connection in ipairs(self.Connections) do pcall(function() connection:Disconnect() end) end
    pcall(function() game:GetService("ContextActionService"):UnbindAction("TryoInspectorDrag_" .. tostring(LocalPlayer.UserId)) end)
    if self.Gui then self.Gui:Destroy() end
    controller = nil
end

return Feature

return Features
