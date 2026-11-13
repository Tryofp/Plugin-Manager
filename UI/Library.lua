-- Tryo UI Library
-- Standalone compact UI foundation for Tryo Plugin Manager.
-- No Infinite Yield or third-party UI framework dependency.

local TryoUI = {}
TryoUI.__index = TryoUI

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local HttpService = game:GetService("HttpService")

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
    self.SettingsFile = "TryoPluginManager_Settings.json"
    local savedSettings
    if type(readfile) == "function" and type(isfile) == "function" then
        pcall(function()
            if isfile(self.SettingsFile) then
                savedSettings = HttpService:JSONDecode(readfile(self.SettingsFile))
            end
        end)
    end
    local initialWidth = tonumber(savedSettings and savedSettings.Width) or (config.Size and config.Size.X.Offset) or 590
    local initialHeight = tonumber(savedSettings and savedSettings.Height) or (config.Size and config.Size.Y.Offset) or 370
    self.Size = UDim2.fromOffset(math.clamp(initialWidth, 480, 820), math.clamp(initialHeight, 300, 600))
    self.Transparency = math.clamp(tonumber(savedSettings and savedSettings.Transparency) or 0.34, 0.15, 0.60)
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
        BackgroundTransparency = self.Transparency,
        BorderSizePixel = 0,
        ClipsDescendants = true
    }, self.Gui)
    corner(self.Window, 11)
    stroke(self.Window, Color3.fromRGB(115, 125, 180), 0.28)
    make("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(48, 77, 111)),
            ColorSequenceKeypoint.new(0.48, Color3.fromRGB(79, 53, 112)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(31, 72, 87))
        }),
        Rotation = 28
    }, self.Window)

    local top = make("Frame", {
        Name = "TopBar",
        Size = UDim2.new(1, 0, 0, 43),
        BackgroundColor3 = Color3.fromRGB(38, 43, 61),
        BackgroundTransparency = math.min(self.Transparency + 0.06, 0.68),
        BorderSizePixel = 0
    }, self.Window)
    make("UIGradient", {
        Color = ColorSequence.new(Color3.fromRGB(65, 133, 166), Color3.fromRGB(119, 75, 165)),
        Rotation = 0
    }, top)

    self.TopBar = top
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
        BackgroundColor3 = Color3.fromRGB(24, 31, 47),
        BackgroundTransparency = math.min(self.Transparency + 0.08, 0.70),
        BorderSizePixel = 0
    }, body)
    make("UIGradient", {
        Color = ColorSequence.new(Color3.fromRGB(43, 82, 112), Color3.fromRGB(72, 48, 98)),
        Rotation = 90
    }, self.Sidebar)

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
        BackgroundColor3 = Color3.fromRGB(45, 54, 75),
        BackgroundTransparency = math.min(self.Transparency + 0.12, 0.72),
        BorderSizePixel = 0
    }, self.Sidebar)
    corner(profile, 8)
    self.Profile = profile
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

    function self:SaveSettings()
        if type(writefile) ~= "function" then return end
        pcall(function()
            writefile(self.SettingsFile, HttpService:JSONEncode({
                Width = self.Size.X.Offset,
                Height = self.Size.Y.Offset,
                Transparency = self.Transparency
            }))
        end)
    end

    function self:SetSize(width, height)
        width = math.clamp(math.floor(tonumber(width) or self.Size.X.Offset), 480, 820)
        height = math.clamp(math.floor(tonumber(height) or self.Size.Y.Offset), 300, 600)
        self.Size = UDim2.fromOffset(width, height)
        self.ExpandedSize = self.Size
        if self.Window and self.Window.Parent then self.Window.Size = self.Size end
        self:SaveSettings()
        return width, height
    end

    function self:SetTransparency(value)
        self.Transparency = math.clamp(tonumber(value) or self.Transparency, 0.15, 0.60)
        if self.Window then self.Window.BackgroundTransparency = self.Transparency end
        if self.TopBar then self.TopBar.BackgroundTransparency = math.min(self.Transparency + 0.06, 0.68) end
        if self.Sidebar then self.Sidebar.BackgroundTransparency = math.min(self.Transparency + 0.08, 0.70) end
        if self.Profile then self.Profile.BackgroundTransparency = math.min(self.Transparency + 0.12, 0.72) end
        self:SaveSettings()
        return self.Transparency
    end

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

    function tab:CreateSizeControl(options)
        options = options or {}
        local card = make("Frame", {
            Name = "WindowSizeControl",
            Size = UDim2.new(1, -4, 0, 102),
            BackgroundColor3 = Color3.fromRGB(42, 49, 68),
            BackgroundTransparency = 0.22,
            BorderSizePixel = 0
        }, self.Page)
        corner(card, 8)
        stroke(card, Color3.fromRGB(105, 125, 170), 0.65)

        local heading = label(card, options.Name or "Window size", 12, COLORS.Text, Enum.Font.GothamBold)
        heading.Position = UDim2.fromOffset(11, 6)
        heading.Size = UDim2.new(1, -22, 0, 20)
        local dimensions = label(card, "", 10, COLORS.Muted)
        dimensions.Position = UDim2.fromOffset(11, 29)
        dimensions.Size = UDim2.new(1, -22, 0, 17)

        local function adjustButton(text, x, callback)
            local button = make("TextButton", {
                Text = text, TextSize = 13, Font = Enum.Font.GothamBold,
                TextColor3 = COLORS.Text, BackgroundColor3 = Color3.fromRGB(75, 78, 112),
                BackgroundTransparency = 0.12, BorderSizePixel = 0,
                Size = UDim2.fromOffset(31, 25), Position = UDim2.fromOffset(x, 58),
                AutoButtonColor = true
            }, card)
            corner(button, 6)
            button.MouseButton1Click:Connect(callback)
        end

        local widthLabel = label(card, "W", 10, COLORS.Muted)
        widthLabel.Position = UDim2.fromOffset(11, 59)
        widthLabel.Size = UDim2.fromOffset(18, 24)
        local heightLabel = label(card, "H", 10, COLORS.Muted)
        heightLabel.Position = UDim2.fromOffset(151, 59)
        heightLabel.Size = UDim2.fromOffset(18, 24)

        local function updateSize(dw, dh)
            local width, height = tab._window:SetSize(tab._window.Size.X.Offset + dw, tab._window.Size.Y.Offset + dh)
            dimensions.Text = string.format("%d × %d px", width, height)
        end
        adjustButton("−", 31, function() updateSize(-20, 0) end)
        adjustButton("+", 65, function() updateSize(20, 0) end)
        adjustButton("−", 171, function() updateSize(0, -20) end)
        adjustButton("+", 205, function() updateSize(0, 20) end)

        local reset = make("TextButton", {
            Text = "Reset", TextSize = 10, Font = Enum.Font.GothamMedium,
            TextColor3 = COLORS.Text, BackgroundColor3 = COLORS.Accent,
            BorderSizePixel = 0, Size = UDim2.fromOffset(54, 25),
            Position = UDim2.new(1, -65, 0, 58), AutoButtonColor = true
        }, card)
        corner(reset, 6)
        reset.MouseButton1Click:Connect(function()
            local width, height = tab._window:SetSize(590, 370)
            dimensions.Text = string.format("%d × %d px", width, height)
        end)

        dimensions.Text = string.format("%d × %d px", tab._window.Size.X.Offset, tab._window.Size.Y.Offset)
        return card
    end

    function tab:CreateWalkSpeedControl(options)
        options = options or {}
        local card = make("Frame", {
            Name = "WalkSpeedControl",
            Size = UDim2.new(1, -4, 0, 35),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ClipsDescendants = true
        }, self.Page)

        local header = make("TextButton", {
            Name = "ToggleHeader",
            Text = "○  " .. (options.Name or "WalkSpeed") .. "     ▾",
            TextSize = 12,
            Font = Enum.Font.GothamMedium,
            TextColor3 = COLORS.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundColor3 = COLORS.Surface,
            AutoButtonColor = false,
            Size = UDim2.new(1, 0, 0, 35)
        }, card)
        corner(header, 7)

        local panel = make("Frame", {
            Name = "SpeedSettings",
            Position = UDim2.fromOffset(0, 41),
            Size = UDim2.new(1, 0, 0, 76),
            BackgroundColor3 = Color3.fromRGB(42, 49, 68),
            BackgroundTransparency = 0.22,
            BorderSizePixel = 0,
            Visible = false
        }, card)
        corner(panel, 8)
        stroke(panel, Color3.fromRGB(105, 125, 170), 0.65)

        local valueLabel = label(panel, "WalkSpeed: 16", 11, COLORS.Muted)
        valueLabel.Position = UDim2.fromOffset(11, 4)
        valueLabel.Size = UDim2.new(1, -22, 0, 19)

        local function controlButton(text, x, width, callback, accent)
            local b = make("TextButton", {
                Text = text,
                TextSize = 13,
                Font = Enum.Font.GothamBold,
                TextColor3 = COLORS.Text,
                BackgroundColor3 = accent and COLORS.Accent or Color3.fromRGB(75, 78, 112),
                BackgroundTransparency = 0.12,
                BorderSizePixel = 0,
                Size = UDim2.fromOffset(width, 25),
                Position = UDim2.fromOffset(x, 34),
                AutoButtonColor = true
            }, panel)
            corner(b, 6)
            b.MouseButton1Click:Connect(callback)
            return b
        end

        local function updateValue()
            local value = math.clamp(tonumber(options.GetValue and options.GetValue()) or 16, 16, 100)
            valueLabel.Text = "WalkSpeed: " .. tostring(value)
        end

        controlButton("−", 11, 38, function()
            if options.SetValue then options.SetValue(math.max(16, (tonumber(options.GetValue()) or 16) - 5)) end
            updateValue()
        end)
        controlButton("+", 55, 38, function()
            if options.SetValue then options.SetValue(math.min(100, (tonumber(options.GetValue()) or 16) + 5)) end
            updateValue()
        end)
        controlButton("Reset", 0, 58, function()
            if options.SetValue then options.SetValue(16) end
            updateValue()
        end, true).Position = UDim2.new(1, -69, 0, 34)

        local enabled = false
        local expanded = false
        local function refresh()
            header.Text = (enabled and "●  " or "○  ") .. (options.Name or "WalkSpeed") .. (expanded and "     ▴" or "     ▾")
            header.BackgroundColor3 = enabled and Color3.fromRGB(49, 65, 79) or COLORS.Surface
            card.Size = UDim2.new(1, -4, 0, expanded and 123 or 35)
            panel.Visible = expanded
            updateValue()
        end
        header.MouseButton1Click:Connect(function()
            enabled = not enabled
            expanded = enabled
            if type(options.Callback) == "function" then
                local ok, err = pcall(options.Callback, enabled)
                if not ok then warn("[Tryo UI] " .. tostring(err)) end
            end
            refresh()
        end)
        header.MouseEnter:Connect(function() header.BackgroundColor3 = COLORS.SurfaceHover end)
        header.MouseLeave:Connect(function() header.BackgroundColor3 = enabled and Color3.fromRGB(49, 65, 79) or COLORS.Surface end)
        refresh()
        return {
            Set = function(value)
                enabled = value == true
                expanded = enabled
                refresh()
            end,
            Get = function() return enabled end,
            Refresh = updateValue
        }
    end

    function tab:CreateGlassControl(options)
        options = options or {}
        local card = make("Frame", {
            Name = "GlassTransparencyControl",
            Size = UDim2.new(1, -4, 0, 92),
            BackgroundColor3 = Color3.fromRGB(50, 62, 87),
            BackgroundTransparency = 0.24,
            BorderSizePixel = 0
        }, self.Page)
        corner(card, 8)
        stroke(card, Color3.fromRGB(117, 157, 196), 0.62)

        local heading = label(card, options.Name or "Glass transparency", 12, COLORS.Text, Enum.Font.GothamBold)
        heading.Position = UDim2.fromOffset(11, 7)
        heading.Size = UDim2.new(1, -22, 0, 20)
        local valueLabel = label(card, "", 10, COLORS.Muted)
        valueLabel.Position = UDim2.fromOffset(11, 30)
        valueLabel.Size = UDim2.new(1, -22, 0, 16)

        local function change(delta)
            local value = tab._window:SetTransparency(tab._window.Transparency + delta)
            valueLabel.Text = string.format("Transparency: %d%%", math.floor(value * 100 + 0.5))
        end
        local function button(text, x, callback)
            local b = make("TextButton", {
                Text = text, TextSize = 13, Font = Enum.Font.GothamBold,
                TextColor3 = COLORS.Text, BackgroundColor3 = Color3.fromRGB(76, 94, 132),
                BackgroundTransparency = 0.12, BorderSizePixel = 0,
                Size = UDim2.fromOffset(38, 25), Position = UDim2.fromOffset(x, 57)
            }, card)
            corner(b, 6)
            b.MouseButton1Click:Connect(callback)
        end
        button("−", 11, function() change(-0.05) end)
        button("+", 54, function() change(0.05) end)
        local reset = make("TextButton", {
            Text = "Reset", TextSize = 10, Font = Enum.Font.GothamMedium,
            TextColor3 = COLORS.Text, BackgroundColor3 = COLORS.Accent,
            BorderSizePixel = 0, Size = UDim2.fromOffset(54, 25),
            Position = UDim2.new(1, -65, 0, 57)
        }, card)
        corner(reset, 6)
        reset.MouseButton1Click:Connect(function()
            local value = tab._window:SetTransparency(0.34)
            valueLabel.Text = string.format("Transparency: %d%%", math.floor(value * 100 + 0.5))
        end)
        valueLabel.Text = string.format("Transparency: %d%%", math.floor(tab._window.Transparency * 100 + 0.5))
        return card
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

    tab._window = self
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
