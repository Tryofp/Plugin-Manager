-- Tryo UI Library
-- Standalone compact UI foundation for Tryo Plugin Manager.
-- No Infinite Yield or third-party UI framework dependency.

local TryoUI = {}
TryoUI.__index = TryoUI

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local COLORS = {
    Background = Color3.fromRGB(20, 22, 29),
    Sidebar = Color3.fromRGB(25, 27, 36),
    Surface = Color3.fromRGB(31, 34, 44),
    SurfaceHover = Color3.fromRGB(41, 44, 57),
    Accent = Color3.fromRGB(139, 92, 246),
    Text = Color3.fromRGB(238, 240, 248),
    Muted = Color3.fromRGB(150, 156, 174),
    Border = Color3.fromRGB(55, 59, 73),
    Success = Color3.fromRGB(74, 222, 128)
}

local function make(className, props, parent)
    local object = Instance.new(className)
    for key, value in pairs(props or {}) do
        object[key] = value
    end
    object.Parent = parent
    return object
end

local function corner(parent, radius)
    make("UICorner", { CornerRadius = UDim.new(0, radius or 8) }, parent)
end

local function stroke(parent, color, transparency)
    make("UIStroke", {
        Color = color or COLORS.Border,
        Transparency = transparency or 0,
        Thickness = 1
    }, parent)
end

local function label(parent, text, size, color, font)
    return make("TextLabel", {
        BackgroundTransparency = 1,
        Text = text or "",
        TextColor3 = color or COLORS.Text,
        TextSize = size or 13,
        Font = font or Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        Size = UDim2.new(1, 0, 0, 22)
    }, parent)
end

function TryoUI.new(config)
    config = config or {}
    local self = setmetatable({}, TryoUI)
    self.Title = config.Title or "Tryo Plugin Manager"
    self.Subtitle = config.Subtitle or "Standalone Script Hub"
    self.Size = config.Size or UDim2.fromOffset(590, 370)
    self.Tabs = {}
    self.ActiveTab = nil
    self.Destroyed = false

    local player = Players.LocalPlayer
    local guiParent = config.Parent
    if not guiParent then
        local ok, coreGui = pcall(function()
            return game:GetService("CoreGui")
        end)
        guiParent = ok and coreGui or player:WaitForChild("PlayerGui")
    end

    local old = guiParent:FindFirstChild("TryoPluginManager")
    if old then old:Destroy() end

    self.Gui = make("ScreenGui", {
        Name = "TryoPluginManager",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    }, guiParent)

    self.Window = make("Frame", {
        Name = "Window",
        Size = self.Size,
        Position = UDim2.new(0.5, -self.Size.X.Offset / 2, 0.5, -self.Size.Y.Offset / 2),
        BackgroundColor3 = COLORS.Background,
        BorderSizePixel = 0,
        ClipsDescendants = true
    }, self.Gui)
    corner(self.Window, 11)
    stroke(self.Window, COLORS.Border)

    local top = make("Frame", {
        Name = "TopBar",
        Size = UDim2.new(1, 0, 0, 43),
        BackgroundColor3 = COLORS.Surface,
        BorderSizePixel = 0
    }, self.Window)

    local title = label(top, self.Title, 14, COLORS.Text, Enum.Font.GothamBold)
    title.Position = UDim2.fromOffset(14, 3)
    title.Size = UDim2.new(1, -110, 0, 20)
    local subtitle = label(top, self.Subtitle, 10, COLORS.Muted)
    subtitle.Position = UDim2.fromOffset(14, 22)
    subtitle.Size = UDim2.new(1, -110, 0, 14)

    local close = make("TextButton", {
        Name = "Close",
        Text = "×",
        TextSize = 22,
        Font = Enum.Font.Gotham,
        TextColor3 = COLORS.Muted,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(34, 34),
        Position = UDim2.new(1, -39, 0, 4)
    }, top)
    close.MouseButton1Click:Connect(function() self:Destroy() end)

    local minimize = make("TextButton", {
        Name = "Minimize",
        Text = "−",
        TextSize = 20,
        Font = Enum.Font.Gotham,
        TextColor3 = COLORS.Muted,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(30, 34),
        Position = UDim2.new(1, -72, 0, 4)
    }, top)

    local body = make("Frame", {
        Name = "Body",
        Position = UDim2.fromOffset(0, 43),
        Size = UDim2.new(1, 0, 1, -43),
        BackgroundTransparency = 1
    }, self.Window)

    self.Sidebar = make("Frame", {
        Name = "Sidebar",
        Size = UDim2.new(0, 145, 1, 0),
        BackgroundColor3 = COLORS.Sidebar,
        BorderSizePixel = 0
    }, body)

    self.Nav = make("ScrollingFrame", {
        Name = "Navigation",
        Position = UDim2.fromOffset(8, 9),
        Size = UDim2.new(1, -16, 1, -76),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 2,
        CanvasSize = UDim2.new()
    }, self.Sidebar)
    local navLayout = make("UIListLayout", {
        Padding = UDim.new(0, 5),
        SortOrder = Enum.SortOrder.LayoutOrder
    }, self.Nav)
    navLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        self.Nav.CanvasSize = UDim2.fromOffset(0, navLayout.AbsoluteContentSize.Y + 4)
    end)

    local profile = make("Frame", {
        Name = "Profile",
        Position = UDim2.new(0, 8, 1, -59),
        Size = UDim2.new(1, -16, 0, 50),
        BackgroundColor3 = COLORS.Surface,
        BorderSizePixel = 0
    }, self.Sidebar)
    corner(profile, 8)
    local avatar = make("ImageLabel", {
        Name = "Avatar",
        Position = UDim2.fromOffset(7, 8),
        Size = UDim2.fromOffset(32, 32),
        BackgroundColor3 = COLORS.SurfaceHover,
        Image = ""
    }, profile)
    corner(avatar, 16)
    local username = label(profile, player and player.DisplayName or "Player", 11, COLORS.Text, Enum.Font.GothamBold)
    username.Position = UDim2.fromOffset(46, 7)
    username.Size = UDim2.new(1, -50, 0, 16)
    local userId = label(profile, "ID: " .. tostring(player and player.UserId or "N/A"), 9, COLORS.Muted)
    userId.Position = UDim2.fromOffset(46, 24)
    userId.Size = UDim2.new(1, -50, 0, 14)

    if player then
        task.spawn(function()
            local ok, image = pcall(function()
                return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
            end)
            if ok and avatar.Parent then avatar.Image = image end
        end)
    end

    self.Content = make("Frame", {
        Name = "Content",
        Position = UDim2.fromOffset(145, 0),
        Size = UDim2.new(1, -145, 1, 0),
        BackgroundTransparency = 1
    }, body)

    -- Drag only from the top bar. Sink the active pointer action while dragging
    -- so Roblox's default camera controls do not receive the same touch/mouse gesture.
    local drag, dragInput, dragStart, startPos
    local dragActionName = "TryoWindowDrag_" .. tostring(player and player.UserId or 0)
    top.Active = true

    top.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            drag = true
            dragStart = input.Position
            startPos = self.Window.Position
            ContextActionService:BindActionAtPriority(
                dragActionName,
                function() return Enum.ContextActionResult.Sink end,
                false,
                Enum.ContextActionPriority.High.Value,
                Enum.UserInputType.MouseButton1,
                Enum.UserInputType.Touch
            )
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    drag = false
                    ContextActionService:UnbindAction(dragActionName)
                end
            end)
        end
    end)

    top.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    self.DragConnection = UserInputService.InputChanged:Connect(function(input)
        if drag and (input == dragInput or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            self.Window.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)

    -- Floating circular restore button; the final Tryo logo can replace this glyph later.
    self.FloatingButton = make("TextButton", {
        Name = "TryoFloatingToggle",
        AnchorPoint = Vector2.new(0, 0),
        Position = UDim2.new(1, -76, 1, -164),
        Size = UDim2.fromOffset(54, 54),
        BackgroundColor3 = COLORS.Surface,
        BackgroundTransparency = 0.16,
        BorderSizePixel = 0,
        Text = "T",
        TextColor3 = COLORS.Text,
        TextSize = 25,
        Font = Enum.Font.GothamBlack,
        AutoButtonColor = false,
        Visible = false,
        ZIndex = 20
    }, self.Gui)
    corner(self.FloatingButton, 27)
    stroke(self.FloatingButton, COLORS.Accent, 0.12)
    make("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(65, 190, 220)),
            ColorSequenceKeypoint.new(0.52, COLORS.Accent),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 65, 160))
        }),
        Rotation = 35
    }, self.FloatingButton)

    self.ExpandedSize = self.Size
    self.Minimized = false

    local function restoreWindow()
        self.Minimized = false
        self.FloatingButton.Visible = false
        self.Window.Visible = true
        self.Window.Size = self.ExpandedSize
    end

    minimize.MouseButton1Click:Connect(function()
        if self.Minimized then return end
        self.Minimized = true
        self.Window.Visible = false
        self.FloatingButton.Visible = true
    end)

    -- Let users freely reposition the bubble with mouse or touch.
    -- A short movement threshold distinguishes dragging from a normal tap.
    local bubbleDragging = false
    local bubbleMoved = false
    local bubbleStartPointer
    local bubbleStartPosition
    local bubblePointerInput
    local bubbleActionName = "TryoBubbleDrag_" .. tostring(player and player.UserId or 0)
    self.FloatingButton.Active = true

    self.FloatingButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            bubbleDragging = true
            bubbleMoved = false
            bubbleStartPointer = input.Position
            bubbleStartPosition = self.FloatingButton.AbsolutePosition
            bubblePointerInput = input

            ContextActionService:BindActionAtPriority(
                bubbleActionName,
                function() return Enum.ContextActionResult.Sink end,
                false,
                Enum.ContextActionPriority.High.Value,
                Enum.UserInputType.MouseButton1,
                Enum.UserInputType.Touch
            )

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    bubbleDragging = false
                    ContextActionService:UnbindAction(bubbleActionName)
                    if bubbleMoved then
                        self.BubbleWasDragged = true
                        task.delay(0.18, function()
                            self.BubbleWasDragged = false
                        end)
                    end
                end
            end)
        end
    end)

    self.BubbleDragConnection = UserInputService.InputChanged:Connect(function(input)
        if not bubbleDragging then return end
        local isMatchingTouch = input == bubblePointerInput
        local isMouseMove = bubblePointerInput
            and bubblePointerInput.UserInputType == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseMovement
        if not isMatchingTouch and not isMouseMove then return end

        local delta = input.Position - bubbleStartPointer
        if delta.Magnitude > 6 then bubbleMoved = true end
        if not bubbleMoved then return end

        local camera = workspace.CurrentCamera
        local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
        local size = self.FloatingButton.AbsoluteSize
        local x = math.clamp(bubbleStartPosition.X + delta.X, 0, math.max(0, viewport.X - size.X))
        local y = math.clamp(bubbleStartPosition.Y + delta.Y, 0, math.max(0, viewport.Y - size.Y))
        self.FloatingButton.Position = UDim2.fromOffset(x, y)
    end)

    self.FloatingButton.MouseButton1Click:Connect(function()
        if self.BubbleWasDragged then return end
        restoreWindow()
    end)

    return self
end

function TryoUI:CreateTab(name, icon)
    local tab = {}
    tab.Name = name
    tab.Elements = {}
    tab.Button = make("TextButton", {
        Name = name .. "Tab",
        Text = (icon and (icon .. "  ") or "") .. name,
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        TextColor3 = COLORS.Muted,
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundColor3 = COLORS.Sidebar,
        AutoButtonColor = false,
        Size = UDim2.new(1, 0, 0, 33)
    }, self.Nav)
    corner(tab.Button, 7)

    tab.Page = make("ScrollingFrame", {
        Name = name .. "Page",
        Size = UDim2.new(1, -22, 1, -20),
        Position = UDim2.fromOffset(11, 10),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        Visible = false,
        CanvasSize = UDim2.new()
    }, self.Content)
    local layout = make("UIListLayout", {
        Padding = UDim.new(0, 7),
        SortOrder = Enum.SortOrder.LayoutOrder
    }, tab.Page)
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        tab.Page.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 8)
    end)

    local function activate()
        for _, existing in ipairs(self.Tabs) do
            existing.Page.Visible = false
            existing.Button.BackgroundColor3 = COLORS.Sidebar
            existing.Button.TextColor3 = COLORS.Muted
        end
        tab.Page.Visible = true
        tab.Button.BackgroundColor3 = COLORS.Accent
        tab.Button.TextColor3 = Color3.new(1, 1, 1)
        self.ActiveTab = tab
    end
    tab.Button.MouseButton1Click:Connect(activate)
    tab.Activate = activate

    function tab:CreateSection(text)
        local section = label(self.Page, text, 11, COLORS.Accent, Enum.Font.GothamBold)
        section.Size = UDim2.new(1, -4, 0, 22)
        return section
    end

    function tab:CreateButton(options)
        options = options or {}
        local button = make("TextButton", {
            Text = options.Name or "Button",
            TextSize = 12,
            Font = Enum.Font.GothamMedium,
            TextColor3 = COLORS.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundColor3 = COLORS.Surface,
            AutoButtonColor = false,
            Size = UDim2.new(1, -4, 0, 35)
        }, self.Page)
        corner(button, 7)
        local pad = make("UIPadding", { PaddingLeft = UDim.new(0, 11), PaddingRight = UDim.new(0, 10) }, button)
        button.MouseEnter:Connect(function() button.BackgroundColor3 = COLORS.SurfaceHover end)
        button.MouseLeave:Connect(function() button.BackgroundColor3 = COLORS.Surface end)
        button.MouseButton1Click:Connect(function()
            if type(options.Callback) == "function" then
                local ok, err = pcall(options.Callback)
                if not ok then warn("[Tryo UI] " .. tostring(err)) end
            end
        end)
        return button
    end

    function tab:CreateToggle(options)
        options = options or {}
        local state = options.Default == true
        local button = self:CreateButton({ Name = (state and "●  " or "○  ") .. (options.Name or "Toggle") })
        local function set(value)
            state = value == true
            button.Text = (state and "●  " or "○  ") .. (options.Name or "Toggle")
            if type(options.Callback) == "function" then options.Callback(state) end
        end
        button.MouseButton1Click:Connect(function() set(not state) end)
        return { Set = set, Get = function() return state end }
    end

    table.insert(self.Tabs, tab)
    if #self.Tabs == 1 then activate() end
    return tab
end

function TryoUI:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    if self.DragConnection then self.DragConnection:Disconnect() end
    if self.BubbleDragConnection then self.BubbleDragConnection:Disconnect() end
    ContextActionService:UnbindAction("TryoWindowDrag_" .. tostring(Players.LocalPlayer and Players.LocalPlayer.UserId or 0))
    ContextActionService:UnbindAction("TryoBubbleDrag_" .. tostring(Players.LocalPlayer and Players.LocalPlayer.UserId or 0))
    if self.Gui then self.Gui:Destroy() end
end

return TryoUI
