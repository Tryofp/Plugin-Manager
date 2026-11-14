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
    self.Subtitle = config.Subtitle or "Versi Window • Stable"
    self.LastUpdate = config.LastUpdate or "N/A"
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
    if type(savedSettings) == "table" and type(savedSettings.Accent) == "table" then
        local r = math.clamp(tonumber(savedSettings.Accent.R) or 139, 0, 255)
        local g = math.clamp(tonumber(savedSettings.Accent.G) or 92, 0, 255)
        local b = math.clamp(tonumber(savedSettings.Accent.B) or 246, 0, 255)
        COLORS.Accent = Color3.fromRGB(r, g, b)
    end
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
        Size = UDim2.new(1, 0, 0, 52),
        BackgroundColor3 = Color3.fromRGB(38, 43, 61),
        BackgroundTransparency = math.min(self.Transparency + 0.06, 0.68),
        BorderSizePixel = 0
    }, self.Window)
    make("UIGradient", {
        Color = ColorSequence.new(Color3.fromRGB(65, 133, 166), Color3.fromRGB(119, 75, 165)),
        Rotation = 0
    }, top)

    self.TopBar = top
    local title = label(top, self.Title, 14, Color3.fromRGB(255, 255, 255), Enum.Font.GothamBlack)
    title.Position = UDim2.fromOffset(14, 0)
    title.Size = UDim2.new(1, -180, 0, 19)

    local metadata = label(top,
        self.Subtitle .. " • LAST UPDATE : " .. self.LastUpdate,
        10, Color3.fromRGB(220, 235, 255), Enum.Font.GothamBold)
    metadata.Position = UDim2.fromOffset(14, 19)
    metadata.Size = UDim2.new(1, -180, 0, 14)
    self.LastUpdateLabel = metadata

    local tickerClip = make("Frame", {
        Name = "HeaderTickerClip",
        Position = UDim2.fromOffset(14, 35),
        Size = UDim2.new(1, -180, 0, 13),
        BackgroundTransparency = 1,
        ClipsDescendants = true
    }, top)
    local tickerText = label(tickerClip,
        "TRYO PLUGIN MANAGER  •  STANDALONE SCRIPT HUB  •  MOBILE FRIENDLY  •  ",
        9, Color3.fromRGB(205, 230, 255), Enum.Font.GothamBold)
    tickerText.Name = "HeaderTicker"
    tickerText.AutomaticSize = Enum.AutomaticSize.X
    tickerText.Size = UDim2.fromOffset(460, 13)
    tickerText.Position = UDim2.fromOffset(0, 0)
    tickerText.TextStrokeColor3 = Color3.fromRGB(20, 35, 60)
    tickerText.TextStrokeTransparency = 0.65

    task.spawn(function()
        while tickerText.Parent and top.Parent do
            tickerText.Position = UDim2.fromOffset(tickerClip.AbsoluteSize.X, 0)
            local distance = tickerClip.AbsoluteSize.X + tickerText.AbsoluteSize.X
            local duration = math.max(8, distance / 32)
            local tween = TweenService:Create(tickerText, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
                Position = UDim2.fromOffset(-tickerText.AbsoluteSize.X, 0)
            })
            tween:Play()
            tween.Completed:Wait()
        end
    end)

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
        Position = UDim2.fromOffset(0, 52),
        Size = UDim2.new(1, 0, 1, -52),
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
        Position = UDim2.new(1, -76, 0, 88),
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
                Transparency = self.Transparency,
                Accent = { R = math.floor(COLORS.Accent.R * 255 + 0.5), G = math.floor(COLORS.Accent.G * 255 + 0.5), B = math.floor(COLORS.Accent.B * 255 + 0.5) }
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

    function self:SetLastUpdate(value)
        self.LastUpdate = tostring(value or "-")
        if self.LastUpdateLabel then
            self.LastUpdateLabel.Text = self.Subtitle .. " • LAST UPDATE : " .. self.LastUpdate
        end
        return self.LastUpdate
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

    function self:SetAccent(color)
        if typeof(color) ~= "Color3" then return COLORS.Accent end
        local previous = COLORS.Accent
        COLORS.Accent = color
        if self.Gui then
            for _, object in ipairs(self.Gui:GetDescendants()) do
                if object:IsA("GuiObject") and object.BackgroundColor3 == previous then
                    object.BackgroundColor3 = color
                end
                if (object:IsA("TextLabel") or object:IsA("TextButton")) and object.TextColor3 == previous then
                    object.TextColor3 = color
                end
                if object:IsA("UIStroke") and object.Color == previous then
                    object.Color = color
                end
                if object:IsA("UIGradient") then
                    local updated, changed = {}, false
                    for _, keypoint in ipairs(object.Color.Keypoints) do
                        local keyColor = keypoint.Value
                        if keyColor == previous then keyColor = color; changed = true end
                        table.insert(updated, ColorSequenceKeypoint.new(keypoint.Time, keyColor))
                    end
                    if changed then object.Color = ColorSequence.new(updated) end
                end
            end
        end
        self:SaveSettings()
        return color
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

function TryoUI:CreateFeedbackButton(options)
    options = options or {}
    local endpoint = options.Endpoint
    local top = self.TopBar
    if not top or not endpoint then return nil end

    local button = make("TextButton", {
        Name = "FeedbackButton",
        Text = "FEEDBACK",
        TextSize = 9,
        Font = Enum.Font.GothamBold,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundColor3 = Color3.fromRGB(0, 125, 155),
        BorderSizePixel = 0,
        AutoButtonColor = true,
        Size = UDim2.fromOffset(70, 23),
        Position = UDim2.new(1, -150, 0, 5),
        ZIndex = 20
    }, top)
    corner(button, 5)

    local categories = {"Bug Report", "Feature Request", "Suggestion", "Other"}
    local function showFeedbackToast(message, success)
        if not self.Window or not self.Window.Parent then return end
        local oldToast = self.Window:FindFirstChild("FeedbackToast")
        if oldToast then oldToast:Destroy() end
        local toast = make("TextLabel", {
            Name = "FeedbackToast",
            AnchorPoint = Vector2.new(0.5, 0),
            Position = UDim2.new(0.5, 0, 0, 58),
            Size = UDim2.fromOffset(220, 32),
            BackgroundColor3 = success and Color3.fromRGB(0, 125, 82) or Color3.fromRGB(155, 55, 55),
            BackgroundTransparency = 0.05,
            BorderSizePixel = 0,
            Text = message,
            TextColor3 = Color3.new(1, 1, 1),
            TextSize = 11,
            Font = Enum.Font.GothamBold,
            ZIndex = 250
        }, self.Window)
        corner(toast, 6)
        task.delay(2.8, function()
            if toast and toast.Parent then toast:Destroy() end
        end)
    end

    local function openDialog()
        if not self.Window or not self.Window.Parent then return end
        local old = self.Window:FindFirstChild("FeedbackOverlay")
        if old then old:Destroy() end

        local overlay = make("Frame", {
            Name = "FeedbackOverlay",
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Color3.fromRGB(0, 0, 0),
            BackgroundTransparency = 0.32,
            BorderSizePixel = 0,
            ZIndex = 100
        }, self.Window)

        local modal = make("Frame", {
            Name = "FeedbackModal",
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.new(1, -28, 0, 292),
            BackgroundColor3 = Color3.fromRGB(25, 32, 42),
            BorderSizePixel = 0,
            ZIndex = 101
        }, overlay)
        corner(modal, 8)

        local function addLabel(name, text, pos, size, fontSize, color)
            local obj = make("TextLabel", {
                Name = name, Position = pos, Size = size,
                BackgroundTransparency = 1, Text = text,
                Font = Enum.Font.GothamBold, TextSize = fontSize or 10,
                TextColor3 = color or Color3.fromRGB(225, 235, 245),
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Center,
                ZIndex = 103
            }, modal)
            return obj
        end

        addLabel("Title", "KIRIM FEEDBACK", UDim2.fromOffset(11, 7), UDim2.new(1, -48, 0, 22), 12, Color3.fromRGB(0, 220, 255))
        local close = make("TextButton", {
            Text = "X", Size = UDim2.fromOffset(23, 23),
            Position = UDim2.new(1, -32, 0, 6),
            BackgroundColor3 = Color3.fromRGB(170, 55, 55),
            TextColor3 = Color3.new(1, 1, 1), TextSize = 10,
            Font = Enum.Font.GothamBold, BorderSizePixel = 0, ZIndex = 104
        }, modal)
        corner(close, 4)

        addLabel("CategoryLabel", "Kategori", UDim2.fromOffset(11, 34), UDim2.new(0.5, -16, 0, 16), 9)
        local categoryIndex = 1
        local categoryButton = make("TextButton", {
            Text = categories[1] .. "  ▾", Size = UDim2.new(0.5, -16, 0, 26),
            Position = UDim2.fromOffset(11, 52), BackgroundColor3 = Color3.fromRGB(40, 55, 72),
            TextColor3 = Color3.new(1, 1, 1), TextSize = 9, Font = Enum.Font.GothamBold,
            BorderSizePixel = 0, ZIndex = 103
        }, modal)
        corner(categoryButton, 4)

        addLabel("RatingLabel", "Rating", UDim2.new(0.5, 5, 0, 34), UDim2.new(0.5, -16, 0, 16), 9)
        local rating = 5
        local ratingButton = make("TextButton", {
            Text = "★★★★★  5/5", Size = UDim2.new(0.5, -16, 0, 26),
            Position = UDim2.new(0.5, 5, 0, 52), BackgroundColor3 = Color3.fromRGB(75, 62, 30),
            TextColor3 = Color3.fromRGB(255, 220, 90), TextSize = 9, Font = Enum.Font.GothamBold,
            BorderSizePixel = 0, ZIndex = 103
        }, modal)
        corner(ratingButton, 4)

        categoryButton.MouseButton1Click:Connect(function()
            categoryIndex = categoryIndex % #categories + 1
            categoryButton.Text = categories[categoryIndex] .. "  ▾"
        end)
        ratingButton.MouseButton1Click:Connect(function()
            rating = rating % 5 + 1
            ratingButton.Text = string.rep("★", rating) .. string.rep("☆", 5 - rating) .. "  " .. rating .. "/5"
        end)

        addLabel("MessageLabel", "Pesan (8–1.500 karakter)", UDim2.fromOffset(11, 84), UDim2.new(1, -22, 0, 16), 9)
        local messageBox = make("TextBox", {
            Size = UDim2.new(1, -22, 0, 112), Position = UDim2.fromOffset(11, 102),
            BackgroundColor3 = Color3.fromRGB(13, 18, 25), BorderSizePixel = 0,
            ClearTextOnFocus = false, MultiLine = true, TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
            Font = Enum.Font.Gotham, Text = "",
            PlaceholderText = "Tulis bug, saran, atau ide lu di sini...",
            PlaceholderColor3 = Color3.fromRGB(115, 130, 148),
            TextColor3 = Color3.fromRGB(240, 245, 250), TextSize = 10, ZIndex = 103
        }, modal)
        corner(messageBox, 4)

        local status = addLabel("Status", "", UDim2.fromOffset(11, 218), UDim2.new(1, -22, 0, 24), 8, Color3.fromRGB(170, 190, 205))
        status.TextWrapped = true
        local submit = make("TextButton", {
            Text = "KIRIM FEEDBACK", Size = UDim2.new(0.5, -16, 0, 26),
            Position = UDim2.fromOffset(11, 255), BackgroundColor3 = Color3.fromRGB(0, 145, 90),
            TextColor3 = Color3.new(1, 1, 1), TextSize = 9, Font = Enum.Font.GothamBold,
            BorderSizePixel = 0, ZIndex = 103
        }, modal)
        corner(submit, 4)
        local cancel = make("TextButton", {
            Text = "TUTUP", Size = UDim2.new(0.5, -16, 0, 26),
            Position = UDim2.new(0.5, 5, 0, 255), BackgroundColor3 = Color3.fromRGB(65, 75, 90),
            TextColor3 = Color3.new(1, 1, 1), TextSize = 9, Font = Enum.Font.GothamBold,
            BorderSizePixel = 0, ZIndex = 103
        }, modal)
        corner(cancel, 4)
        close.MouseButton1Click:Connect(function() overlay:Destroy() end)
        cancel.MouseButton1Click:Connect(function() overlay:Destroy() end)

        submit.MouseButton1Click:Connect(function()
            local message = tostring(messageBox.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
            if #message < 8 or #message > 1500 then
                status.Text = "Pesan harus 8–1.500 karakter."
                status.TextColor3 = Color3.fromRGB(255, 175, 100)
                return
            end
            local req = request or http_request
            if type(req) ~= "function" and type(syn) == "table" then req = syn.request end
            if type(req) ~= "function" then
                status.Text = "Executor tidak menyediakan HTTP request."
                status.TextColor3 = Color3.fromRGB(255, 120, 120)
                return
            end

            -- Instant confirmation; the HTTP request continues independently below.
            submit.Active = false
            submit.AutoButtonColor = false
            submit.Text = "TERKIRIM"
            submit.BackgroundColor3 = Color3.fromRGB(0, 115, 75)
            status.Text = "Feedback dikirim di background..."
            status.TextColor3 = Color3.fromRGB(100, 235, 155)
            showFeedbackToast("Feedback Terkirim!", true)

            task.spawn(function()
                local players = game:GetService("Players")
                local player = players.LocalPlayer
                local input = game:GetService("UserInputService")
                local device = (input.TouchEnabled and not input.KeyboardEnabled) and "Mobile / Tablet"
                    or (input.KeyboardEnabled and input.MouseEnabled) and "PC / Laptop"
                    or input.GamepadEnabled and "Console / Controller" or "Unknown"
                local requestId = HttpService:GenerateGUID(false)
                local payload = HttpService:JSONEncode({
                    Type = "Feedback", RequestId = requestId,
                    Username = player and player.Name or "Unknown",
                    UserId = player and tostring(player.UserId) or "0",
                    Category = categories[categoryIndex], Rating = rating, Message = message,
                    Device = device, PlaceId = tostring(game.PlaceId),
                    PlaceName = tostring(game.Name or "Unknown Game")
                })

                local requestOk, response = pcall(function()
                    return req({
                        Url = endpoint, Method = "POST",
                        Headers = {["Content-Type"] = "application/json"},
                        FollowRedirects = false, Body = payload
                    })
                end)
                local function headerValue(headers, wanted)
                    if type(headers) ~= "table" then return nil end
                    for key, value in pairs(headers) do
                        if tostring(key):lower() == wanted:lower() then return tostring(value) end
                    end
                end
                local code = response and (response.StatusCode or response.Status or response.status_code)
                local headers = response and (response.Headers or response.headers)
                local redirect = headerValue(headers, "Location")
                local redirectCodes = {[301]=true,[302]=true,[303]=true,[307]=true,[308]=true}
                if requestOk and response and redirect and redirectCodes[tonumber(code)] then
                    requestOk, response = pcall(function()
                        return req({Url = redirect, Method = "GET", FollowRedirects = true})
                    end)
                end

                local decoded
                if requestOk and response then
                    local body = response.Body or response.body or ""
                    code = response.StatusCode or response.Status or response.status_code
                    local decodeOk, result = pcall(function() return HttpService:JSONDecode(body) end)
                    if decodeOk and type(result) == "table" then decoded = result end
                end
                if not decoded and tonumber(code) == 405 then
                    local statusOk, statusResponse = pcall(function()
                        return req({Url = endpoint .. "?action=FeedbackStatus&requestId=" .. requestId, Method = "GET", FollowRedirects = true})
                    end)
                    if statusOk and statusResponse then
                        local body = statusResponse.Body or statusResponse.body or ""
                        local decodeOk, result = pcall(function() return HttpService:JSONDecode(body) end)
                        if decodeOk and type(result) == "table" then decoded = result end
                    end
                end

                if decoded and decoded.status == "success" then
                    if not overlay.Parent then return end
                    status.Text = decoded.notificationSent and "Feedback tersimpan dan notifikasi terkirim!"
                        or ("Feedback tersimpan. ntfy: " .. tostring(decoded.notificationError or "belum terkirim"))
                    status.TextColor3 = Color3.fromRGB(100, 235, 155)
                    messageBox.Text = ""
                else
                    showFeedbackToast("Gagal mengirim feedback!", false)
                    if not overlay.Parent then return end
                    submit.Active = true
                    submit.AutoButtonColor = true
                    submit.Text = "COBA LAGI"
                    status.Text = decoded and tostring(decoded.message or "Server menolak feedback.")
                        or (not requestOk and ("Request gagal: " .. tostring(response):sub(1, 100)))
                        or (not response and "Server tidak mengembalikan respons.")
                        or (code and ("Respons server bukan JSON (HTTP " .. tostring(code) .. ")."))
                        or "Respons server bukan JSON atau redirect gagal."
                    status.TextColor3 = Color3.fromRGB(255, 130, 120)
                end
            end)
        end)
    end

    button.MouseButton1Click:Connect(openDialog)
    return button
end

function TryoUI:CreateTab(name, icon)
    local tab = {}
    tab.Name = name
    tab.Elements = {}
    local function makeReleaseBadge(parent, badgeName)
        return make("TextLabel", {
            Name = badgeName, AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -7, 0.5, 0), Size = UDim2.fromOffset(43, 17),
            BackgroundColor3 = Color3.fromRGB(235, 171, 65), BorderSizePixel = 0,
            Text = "UPDATE", TextColor3 = Color3.fromRGB(24, 25, 30),
            TextSize = 8, Font = Enum.Font.GothamBlack, Visible = false, ZIndex = 6
        }, parent)
    end
    -- Use a Frame as the layout surface. A separate full-size click layer
    -- handles input; icon and title are siblings with fixed coordinates.
    tab.Button = make("Frame", {
        Name = name .. "Tab",
        BackgroundColor3 = COLORS.Sidebar,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 33),
        ClipsDescendants = true
    }, self.Nav)
    corner(tab.Button, 7)
    tab.ClickArea = make("TextButton", {
        Name = "ClickArea",
        Text = "",
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 2
    }, tab.Button)

    -- Icon and title are independent children. Avoid TextButton text alignment
    -- and UIPadding: mobile rendering can center text despite those properties.
    local tabTitle = make("TextLabel", {
        Name = "TabTitle",
        BackgroundTransparency = 1,
        Text = name,
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        TextColor3 = COLORS.Muted,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextWrapped = false,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Position = UDim2.fromOffset(36, 0),
        Size = UDim2.new(1, -88, 1, 0),
        ZIndex = 4,
        Active = false
    }, tab.Button)

    local tabIcon = make("Frame", {
        Name = "TabIcon",
        Position = UDim2.fromOffset(9, 8),
        Size = UDim2.fromOffset(17, 17),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 4
    }, tab.Button)

    local function iconPart(name, size, position, color, rotation, radius)
        local part = make("Frame", {
            Name = name,
            Size = size,
            Position = position,
            BackgroundColor3 = color or COLORS.Muted,
            BorderSizePixel = 0,
            Rotation = rotation or 0,
            ZIndex = 5
        }, tabIcon)
        if radius then corner(part, radius) end
        return part
    end

    -- Fixed high-contrast navigation colors: these must remain distinct
    -- from the user-customizable accent so Main/Settings never disappear into it.
    local iconColor = name == "Main" and Color3.fromRGB(70, 220, 235)
        or name == "Settings" and Color3.fromRGB(255, 195, 75)
        or name == "Gunung" and Color3.fromRGB(120, 195, 220)
        or name == "Tools" and Color3.fromRGB(120, 205, 170)
        or name == "Visual" and Color3.fromRGB(155, 175, 245)
        or name == "Horor" and Color3.fromRGB(220, 135, 155)
        or Color3.fromRGB(205, 215, 235)

    if name == "Gunung" then
        iconPart("MountainBase", UDim2.fromOffset(15, 3), UDim2.fromOffset(1, 13), iconColor, 0, 2)
        iconPart("PeakLeft", UDim2.fromOffset(9, 9), UDim2.fromOffset(2, 5), iconColor, 45, 1)
        iconPart("PeakRight", UDim2.fromOffset(9, 9), UDim2.fromOffset(8, 5), Color3.fromRGB(190, 205, 245), -45, 1)
    elseif name == "Main" then
        iconPart("HomeBase", UDim2.fromOffset(11, 9), UDim2.fromOffset(3, 7), iconColor, 0, 2)
        iconPart("RoofLeft", UDim2.fromOffset(10, 3), UDim2.fromOffset(1, 5), iconColor, -38, 1)
        iconPart("RoofRight", UDim2.fromOffset(10, 3), UDim2.fromOffset(8, 5), iconColor, 38, 1)
        iconPart("Door", UDim2.fromOffset(3, 5), UDim2.fromOffset(7, 11), COLORS.Sidebar, 0, 1)
    elseif name == "Horor" then
        iconPart("GhostBody", UDim2.fromOffset(12, 13), UDim2.fromOffset(2, 2), iconColor, 0, 6)
        iconPart("GhostCutout", UDim2.fromOffset(3, 3), UDim2.fromOffset(4, 6), COLORS.Sidebar, 0, 2)
        iconPart("GhostCutout2", UDim2.fromOffset(3, 3), UDim2.fromOffset(9, 6), COLORS.Sidebar, 0, 2)
        iconPart("GhostFoot", UDim2.fromOffset(12, 3), UDim2.fromOffset(2, 13), iconColor, 0, 1)
    elseif name == "Visual" then
        iconPart("EyeOuter", UDim2.fromOffset(15, 9), UDim2.fromOffset(1, 4), iconColor, 0, 6)
        iconPart("EyeInner", UDim2.fromOffset(5, 5), UDim2.fromOffset(6, 6), COLORS.Sidebar, 0, 3)
    elseif name == "Tools" then
        iconPart("ToolHandle", UDim2.fromOffset(4, 13), UDim2.fromOffset(7, 2), iconColor, 42, 2)
        iconPart("ToolHead", UDim2.fromOffset(10, 4), UDim2.fromOffset(4, 2), iconColor, -35, 2)
    elseif name == "Settings" then
        iconPart("GearCore", UDim2.fromOffset(9, 9), UDim2.fromOffset(4, 4), iconColor, 0, 5)
        for i = 0, 3 do
            iconPart("GearTooth" .. tostring(i), UDim2.fromOffset(3, 5), UDim2.fromOffset(7, 0), iconColor, i * 90, 1)
        end
    else
        iconPart("LoadingRing", UDim2.fromOffset(13, 13), UDim2.fromOffset(2, 2), iconColor, 0, 7)
        iconPart("LoadingCore", UDim2.fromOffset(7, 7), UDim2.fromOffset(5, 5), COLORS.Sidebar, 0, 4)
    end

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
            local existingTitle = existing.Button:FindFirstChild("TabTitle")
            if existingTitle then existingTitle.TextColor3 = COLORS.Muted end
        end
        tab.Page.Visible = true
        tab.Button.BackgroundColor3 = COLORS.Accent
        tabTitle.TextColor3 = Color3.new(1, 1, 1)
        self.ActiveTab = tab
        if type(tab.OnActivated) == "function" then pcall(tab.OnActivated) end
    end
    local tabBadge = makeReleaseBadge(tab.Button, "TabReleaseBadge")
    function tab:SetBadge(kind)
        if kind == nil then tabBadge.Visible = false; return end
        tabBadge.Text = tostring(kind):upper()
        tabBadge.BackgroundColor3 = kind == "NEW" and Color3.fromRGB(80, 215, 145) or Color3.fromRGB(235, 171, 65)
        tabBadge.Visible = true
    end
    tab.ClickArea.MouseButton1Click:Connect(activate)
    tab.Activate = activate

    function tab:CreateSection(text)
        local section = label(self.Page, text, 13, Color3.fromRGB(239, 242, 252), Enum.Font.GothamBlack)
        section.Size = UDim2.new(1, -4, 0, 25)
        section.TextXAlignment = Enum.TextXAlignment.Left
        section.TextStrokeColor3 = Color3.fromRGB(12, 15, 24)
        section.TextStrokeTransparency = 0.72
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
        }, options.Parent or self.Page)
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
        }, options.Parent or self.Page)
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
        }, options.Parent or self.Page)

        local header = make("TextButton", {
            Name = "ToggleHeader",
            Text = "",
            TextSize = 12,
            Font = Enum.Font.GothamMedium,
            TextColor3 = COLORS.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundColor3 = COLORS.Surface,
            AutoButtonColor = false,
            Size = UDim2.new(1, 0, 0, 35)
        }, card)
        corner(header, 7)
        local headerTitle = make("TextLabel", {
            Name = "ToggleTitle",
            BackgroundTransparency = 1,
            Text = options.Name or "WalkSpeed",
            TextSize = 12,
            Font = Enum.Font.GothamMedium,
            TextColor3 = COLORS.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            TextWrapped = false,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Position = UDim2.fromOffset(30, 0),
            Size = UDim2.new(1, -62, 1, 0),
            ZIndex = header.ZIndex + 1,
            Active = false
        }, header)
        local statusDot = make("Frame", {
            Name = "StatusDot",
            BackgroundColor3 = COLORS.Muted,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(11, 14),
            Size = UDim2.fromOffset(7, 7),
            ZIndex = header.ZIndex + 1
        }, header)
        corner(statusDot, 4)
        local expandMark = make("TextLabel", {
            Name = "ExpandMark",
            BackgroundTransparency = 1,
            Text = "v",
            TextColor3 = COLORS.Muted,
            TextSize = 12,
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
            Position = UDim2.new(1, -25, 0, 0),
            Size = UDim2.fromOffset(16, 35)
        }, header)

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

        local speedInput = make("TextBox", {
            Name = "ManualSpeedInput",
            Text = "16",
            PlaceholderText = "16-100",
            ClearTextOnFocus = false,
            TextSize = 12,
            Font = Enum.Font.GothamBold,
            TextColor3 = COLORS.Text,
            PlaceholderColor3 = COLORS.Muted,
            TextXAlignment = Enum.TextXAlignment.Center,
            BackgroundColor3 = Color3.fromRGB(61, 69, 91),
            BackgroundTransparency = 0.05,
            BorderSizePixel = 0,
            Size = UDim2.fromOffset(88, 25),
            Position = UDim2.fromOffset(11, 34)
        }, panel)
        corner(speedInput, 6)
        stroke(speedInput, Color3.fromRGB(115, 132, 170), 0.55)

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

        local function applyManualValue()
            local numeric = tonumber(speedInput.Text)
            if not numeric then
                speedInput.Text = tostring(options.GetValue and options.GetValue() or 16)
                return
            end
            numeric = math.clamp(numeric, 16, 100)
            if options.SetValue then options.SetValue(numeric) end
            speedInput.Text = tostring(numeric)
        end

        local function updateValue()
            local current = math.clamp(tonumber(options.GetValue and options.GetValue()) or 16, 16, 100)
            valueLabel.Text = "WalkSpeed: " .. tostring(current)
            if not speedInput:IsFocused() then speedInput.Text = tostring(current) end
        end

        speedInput.FocusLost:Connect(function()
            applyManualValue()
            updateValue()
        end)
        controlButton("Apply", 105, 49, applyManualValue, true)
        controlButton("−", 160, 32, function()
            if options.SetValue then options.SetValue(math.max(16, (tonumber(options.GetValue()) or 16) - 1)) end
            updateValue()
        end)
        controlButton("+", 198, 32, function()
            if options.SetValue then options.SetValue(math.min(100, (tonumber(options.GetValue()) or 16) + 1)) end
            updateValue()
        end)
        controlButton("Reset", 0, 54, function()
            if options.SetValue then options.SetValue(16) end
            updateValue()
        end, true).Position = UDim2.new(1, -65, 0, 34)

        local enabled = false
        local expanded = false
        local function refresh()
            statusDot.BackgroundColor3 = enabled and COLORS.Success or COLORS.Muted
            expandMark.Text = expanded and "^" or "v"
            expandMark.TextColor3 = enabled and COLORS.Text or COLORS.Muted
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
            Set = function(value, silent)
                enabled = value == true
                expanded = enabled
                refresh()
                if not silent and type(options.Callback) == "function" then options.Callback(enabled) end
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

    function tab:CreateColorWheel(options)
        options = options or {}
        local card = make("Frame", {
            Name = "AccentColorWheel",
            Size = UDim2.new(1, -4, 0, 176),
            BackgroundColor3 = Color3.fromRGB(42, 49, 68),
            BackgroundTransparency = 0.18,
            BorderSizePixel = 0
        }, options.Parent or self.Page)
        corner(card, 9)
        stroke(card, Color3.fromRGB(105, 125, 170), 0.58)

        local heading = label(card, options.Name or "Custom theme color", 12, COLORS.Text, Enum.Font.GothamBold)
        heading.Position = UDim2.fromOffset(11, 6)
        heading.Size = UDim2.new(1, -22, 0, 19)

        local wheel = make("Frame", {
            Name = "ColorWheel",
            Position = UDim2.fromOffset(15, 31),
            Size = UDim2.fromOffset(112, 112),
            BackgroundTransparency = 1,
            Active = true
        }, card)

        local center = Vector2.new(56, 56)
        local radius = 47
        for ring = 1, 5 do
            local saturation = ring / 5
            local ringRadius = radius * saturation
            for index = 0, 35 do
                local hue = index / 36
                local angle = hue * math.pi * 2
                local dot = make("Frame", {
                    Name = "Hue" .. tostring(ring) .. "_" .. tostring(index),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.fromOffset(center.X + math.cos(angle) * ringRadius, center.Y + math.sin(angle) * ringRadius),
                    Size = UDim2.fromOffset(9, 9),
                    BackgroundColor3 = Color3.fromHSV(hue, saturation, 1),
                    BorderSizePixel = 0
                }, wheel)
                corner(dot, 5)
            end
        end

        local selector = make("Frame", {
            Name = "ColorSelector",
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset(center.X + radius, center.Y),
            Size = UDim2.fromOffset(13, 13),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            BorderSizePixel = 0,
            ZIndex = 4
        }, wheel)
        corner(selector, 7)
        stroke(selector, Color3.fromRGB(25, 28, 38), 0)

        local preview = make("Frame", {
            Name = "ColorPreview",
            Position = UDim2.fromOffset(145, 42),
            Size = UDim2.fromOffset(42, 42),
            BackgroundColor3 = COLORS.Accent,
            BorderSizePixel = 0
        }, card)
        corner(preview, 21)
        stroke(preview, Color3.fromRGB(220, 225, 240), 0.2)

        local value = label(card, "Tap wheel to choose", 10, Color3.fromRGB(220, 225, 240), Enum.Font.GothamBold)
        value.Position = UDim2.fromOffset(196, 47)
        value.Size = UDim2.new(1, -205, 0, 32)
        value.TextWrapped = true

        local function chooseAt(position)
            -- Roblox InputObject.Position is a Vector3; convert to Vector2 before GUI math.
            local screenPoint = Vector2.new(position.X, position.Y)
            local localPoint = screenPoint - wheel.AbsolutePosition
            local dx, dy = localPoint.X - center.X, localPoint.Y - center.Y
            local distance = math.sqrt(dx * dx + dy * dy)
            if distance > 54 then return end
            local hue = (math.atan2(dy, dx) / (math.pi * 2)) % 1
            local saturation = math.clamp(distance / radius, 0.18, 1)
            local color = Color3.fromHSV(hue, saturation, 1)
            tab._window:SetAccent(color)
            preview.BackgroundColor3 = color
            selector.Position = UDim2.fromOffset(center.X + math.cos(hue * math.pi * 2) * math.min(distance, radius), center.Y + math.sin(hue * math.pi * 2) * math.min(distance, radius))
            value.Text = string.format("RGB  %d, %d, %d", math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
        end

        -- A transparent hit target sits above the decorative dots so mobile taps
        -- are received consistently instead of landing on individual color dots.
        local hitArea = make("TextButton", {
            Name = "ColorWheelHitArea",
            Text = "",
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            Active = true,
            Size = UDim2.fromScale(1, 1),
            ZIndex = 10
        }, wheel)

        local initialHue, initialSaturation = COLORS.Accent:ToHSV()
        local initialRadius = math.clamp(initialSaturation, 0.18, 1) * radius
        selector.Position = UDim2.fromOffset(
            center.X + math.cos(initialHue * math.pi * 2) * initialRadius,
            center.Y + math.sin(initialHue * math.pi * 2) * initialRadius
        )
        value.Text = string.format("RGB  %d, %d, %d",
            math.floor(COLORS.Accent.R * 255 + 0.5),
            math.floor(COLORS.Accent.G * 255 + 0.5),
            math.floor(COLORS.Accent.B * 255 + 0.5))

        local draggingWheel = false
        hitArea.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                draggingWheel = true
                chooseAt(input.Position)
            end
        end)
        local wheelChanged = UserInputService.InputChanged:Connect(function(input)
            if not draggingWheel then return end
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
                chooseAt(input.Position)
            end
        end)
        local wheelEnded = UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                draggingWheel = false
            end
        end)
        card.Destroying:Connect(function()
            wheelChanged:Disconnect()
            wheelEnded:Disconnect()
        end)

        return card
    end

    function tab:CreateDropdown(options)
        options = options or {}
        local card = make("Frame", {Name = "Dropdown_" .. tostring(options.Name or "Menu"):gsub("%W", ""), Size = UDim2.new(1, -4, 0, 35), BackgroundTransparency = 1, ClipsDescendants = true}, self.Page)
        local header = make("TextButton", {Name = "DropdownHeader", Text = "", BackgroundColor3 = COLORS.Surface, AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 35)}, card)
        corner(header, 7)
        local title = make("TextLabel", {Name = "DropdownTitle", BackgroundTransparency = 1, Text = options.Name or "Menu", TextSize = 12, Font = Enum.Font.GothamSemibold, TextColor3 = COLORS.Text, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(11, 0), Size = UDim2.new(1, -88, 1, 0), Active = false}, header)
        local arrow = make("TextLabel", {Name = "DropdownArrow", BackgroundTransparency = 1, Text = "v", TextSize = 12, Font = Enum.Font.GothamBold, TextColor3 = COLORS.Muted, Position = UDim2.new(1, -28, 0, 0), Size = UDim2.fromOffset(18, 35), Active = false}, header)
        local panel = make("Frame", {Name = "DropdownContent", Position = UDim2.fromOffset(0, 41), Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1, Visible = false}, card)
        local list = make("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, panel)
        local expanded = false
        local function resize()
            local h = list.AbsoluteContentSize.Y
            panel.Size = UDim2.new(1, 0, 0, h)
            card.Size = UDim2.new(1, -4, 0, expanded and (41 + h + 5) or 35)
        end
        list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(resize)
        local dropdownBadge = makeReleaseBadge(header, "DropdownReleaseBadge")
        local dropdownControl = {}
        function dropdownControl.SetBadge(kind)
            if kind == nil then dropdownBadge.Visible = false; return end
            dropdownBadge.Text = tostring(kind):upper()
            dropdownBadge.BackgroundColor3 = kind == "NEW" and Color3.fromRGB(80, 215, 145) or Color3.fromRGB(235, 171, 65)
            dropdownBadge.Visible = true
        end
        header.MouseButton1Click:Connect(function()
            expanded = not expanded
            panel.Visible = expanded
            arrow.Text = expanded and "^" or "v"
            header.BackgroundColor3 = expanded and Color3.fromRGB(49, 65, 79) or COLORS.Surface
            if type(options.OnExpanded) == "function" then pcall(options.OnExpanded, expanded) end
            resize()
        end)
        header.MouseEnter:Connect(function() header.BackgroundColor3 = COLORS.SurfaceHover end)
        header.MouseLeave:Connect(function() header.BackgroundColor3 = expanded and Color3.fromRGB(49, 65, 79) or COLORS.Surface end)
        if type(options.Build) == "function" then
            local ok, err = pcall(options.Build, panel)
            if not ok then warn("[Tryo UI] Dropdown " .. tostring(options.Name) .. ": " .. tostring(err)) end
        end
        resize()
        dropdownControl.Card = card
        dropdownControl.Content = panel
        dropdownControl.SetExpanded = function(value)
            expanded = value == true
            panel.Visible = expanded
            arrow.Text = expanded and "^" or "v"
            if type(options.OnExpanded) == "function" then pcall(options.OnExpanded, expanded) end
            resize()
        end
        return dropdownControl
    end

    function tab:CreateToggle(options)
        options = options or {}
        local state = options.Default == true
        local name = options.Name or "Toggle"

        -- Dedicated card + transparent click layer. Status and title never
        -- participate in TextButton text layout, so they cannot overlap.
        local card = make("Frame", {
            Name = "Toggle_" .. name:gsub("%W", ""),
            BackgroundColor3 = COLORS.Surface,
            BorderSizePixel = 0,
            Size = UDim2.new(1, -4, 0, 35),
            ClipsDescendants = true
        }, options.Parent or self.Page)
        corner(card, 7)

        local clickArea = make("TextButton", {
            Name = "ClickArea",
            Text = "",
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            Size = UDim2.fromScale(1, 1),
            ZIndex = 2
        }, card)

        local statusDot = make("Frame", {
            Name = "StatusDot",
            BackgroundColor3 = state and COLORS.Success or COLORS.Muted,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(11, 14),
            Size = UDim2.fromOffset(7, 7),
            ZIndex = 4
        }, card)
        corner(statusDot, 4)

        local toggleTitle = make("TextLabel", {
            Name = "ToggleTitle",
            BackgroundTransparency = 1,
            Text = name,
            TextSize = 12,
            Font = Enum.Font.GothamMedium,
            TextColor3 = COLORS.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            TextWrapped = false,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Position = UDim2.fromOffset(30, 0),
            Size = UDim2.new(1, -92, 1, 0),
            ZIndex = 4,
            Active = false
        }, card)

        local function set(value, silent)
            state = value == true
            statusDot.BackgroundColor3 = state and COLORS.Success or COLORS.Muted
            if not silent and type(options.Callback) == "function" then
                local ok, err = pcall(options.Callback, state)
                if not ok then warn("[Tryo UI] " .. tostring(err)) end
            end
        end
        local toggleBadge = makeReleaseBadge(card, "FeatureReleaseBadge")
        local toggleControl = { Set = set, Get = function() return state end }
        function toggleControl.SetBadge(kind)
            if kind == nil then toggleBadge.Visible = false; return end
            toggleBadge.Text = tostring(kind):upper()
            toggleBadge.BackgroundColor3 = kind == "NEW" and Color3.fromRGB(80, 215, 145) or Color3.fromRGB(235, 171, 65)
            toggleBadge.Visible = true
        end
        clickArea.MouseButton1Click:Connect(function()
            set(not state)
            if type(toggleControl.OnBadgeActivate) == "function" then pcall(toggleControl.OnBadgeActivate) end
        end)
        clickArea.MouseEnter:Connect(function() card.BackgroundColor3 = COLORS.SurfaceHover end)
        clickArea.MouseLeave:Connect(function() card.BackgroundColor3 = COLORS.Surface end)
        return toggleControl
    end

    tab._window = self
    table.insert(self.Tabs, tab)
    if #self.Tabs == 1 then activate() end
    return tab
end

function TryoUI:ShowReleaseDetails(titleText, bodyText)
    if not self.Window or not self.Window.Parent then return end
    local old = self.Window:FindFirstChild("ReleaseDetailsOverlay")
    if old then old:Destroy() end
    local overlay = make("Frame", {Name = "ReleaseDetailsOverlay", Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.3,
        BorderSizePixel = 0, ZIndex = 300}, self.Window)
    local panel = make("Frame", {AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -34, 0, 190),
        BackgroundColor3 = Color3.fromRGB(25, 32, 44), BorderSizePixel = 0, ZIndex = 301}, overlay)
    corner(panel, 9)
    make("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 8),
        Size = UDim2.new(1, -48, 0, 24), Text = titleText or "RELEASE NOTES",
        TextColor3 = Color3.fromRGB(90, 220, 240), Font = Enum.Font.GothamBlack,
        TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 302}, panel)
    local close = make("TextButton", {Position = UDim2.new(1, -34, 0, 7),
        Size = UDim2.fromOffset(25, 24), Text = "×", TextColor3 = Color3.new(1,1,1),
        BackgroundColor3 = Color3.fromRGB(150,55,65), Font = Enum.Font.GothamBold,
        TextSize = 15, BorderSizePixel = 0, ZIndex = 303}, panel)
    corner(close, 5)
    make("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 39),
        Size = UDim2.new(1, -24, 1, -50), Text = tostring(bodyText or ""),
        TextColor3 = Color3.fromRGB(225, 232, 244), Font = Enum.Font.Gotham,
        TextSize = 10, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 302}, panel)
    close.MouseButton1Click:Connect(function() overlay:Destroy() end)
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
