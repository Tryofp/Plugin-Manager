return function(speaker)
    local CoreGui = game:GetService("CoreGui")
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local TextService = game:GetService("TextService")
    local TweenService = game:GetService("TweenService")
    local HttpService = game:GetService("HttpService")
    local MarketplaceService = game:GetService("MarketplaceService")
    local UserInputService = game:GetService("UserInputService")

    -- ==========================================
    -- 📊 GOOGLE SHEETS WEB HOOK / TRACKER URL
    -- ==========================================
    local SHEETS_WEB_APP_URL = "https://script.google.com/macros/s/AKfycbxJzU3MiL_o9PjkF4h-prSw-P8vLVfJqGFXM7pFJOPzIzJXaGmu6z6oK0oJl54a6bQy0Q/exec"

    -- Ambil data metadata terbaru dari Google Sheets secara online saat load
    local remoteMetadata = {}
    pcall(function()
        local response = game:HttpGet(SHEETS_WEB_APP_URL)
        if response and response ~= "" then
            local decoded = HttpService:JSONDecode(response)
            if decoded and type(decoded) == "table" then
                remoteMetadata = decoded
            end
        end
    end)

    local sessionStartTime = os.time()

    local function getDeviceType()
        if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
            return "Mobile / Tablet"
        elseif UserInputService.KeyboardEnabled and UserInputService.MouseEnabled then
            return "PC / Laptop"
        elseif UserInputService.GamepadEnabled then
            return "Console / Controller"
        else
            return "Unknown Device"
        end
    end

    local function sendTrackerData(isLeaving)
        pcall(function()
            if request or http_request or (syn and syn.request) then
                local req = request or http_request or (syn and syn.request)
                
                local mapName = "Unknown Map"
                pcall(function()
                    local success, placeInfo = pcall(function()
                        return MarketplaceService:GetProductInfo(game.PlaceId)
                    end)
                    if success and placeInfo and placeInfo.Name then
                        mapName = placeInfo.Name
                    else
                        mapName = game.Name
                    end
                end)

                local totalSeconds = os.time() - sessionStartTime
                local minutes = math.floor(totalSeconds / 60)
                local seconds = totalSeconds % 60
                local playtimeFormatted = string.format("%d Menit %d Detik", minutes, seconds)
                if isLeaving then
                    playtimeFormatted = playtimeFormatted .. " (Keluar Game)"
                else
                    playtimeFormatted = playtimeFormatted .. " (Baru Load)"
                end

                local payload = HttpService:JSONEncode({
                    Username = LocalPlayer.Name,
                    UserId = LocalPlayer.UserId,
                    Device = getDeviceType(),
                    Playtime = playtimeFormatted,
                    MapName = mapName,
                    PlaceId = game.PlaceId,
                    JobId = game.JobId or "Private/Solo Server"
                })

                req({
                    Url = SHEETS_WEB_APP_URL,
                    Method = "POST",
                    Headers = { ["Content-Type"] = "application/json" },
                    Body = payload
                })
            end
        end)
    end

    task.spawn(function()
        sendTrackerData(false)
    end)

    Players.PlayerRemoving:Connect(function(plr)
        if plr == LocalPlayer then
            sendTrackerData(true)
        end
    end)

    local CUSTOM_TEXT = "🔥 Selamat datang di Plugin Manager By Tryo! Enjoy the script! 🚀"
    local CUSTOM_TEXT_COLOR = Color3.fromRGB(0, 220, 255)
    local SCROLL_SPEED = 18
    local globalLoaderData = nil

    local colorMap = {
        red = Color3.fromRGB(255, 60, 60),
        yellow = Color3.fromRGB(255, 215, 0),
        green = Color3.fromRGB(60, 255, 100),
        blue = Color3.fromRGB(60, 160, 255),
        orange = Color3.fromRGB(255, 140, 0),
        purple = Color3.fromRGB(180, 60, 255),
        pink = Color3.fromRGB(255, 105, 180),
        white = Color3.fromRGB(255, 255, 255)
    }

    local function getColorFromName(name)
        if not name then return Color3.fromRGB(255, 215, 0) end
        local lowerName = string.lower(tostring(name)):gsub("%s+", "")
        return colorMap[lowerName] or Color3.fromRGB(255, 215, 0)
    end

    local function parseCustomConfig(configStr)
        if not configStr then return 0, 86400 end
        local str = tostring(configStr)
        local datePart, durationPart = str:match("([^,]+),%s*(.+)")
        datePart = datePart or str
        datePart = datePart:gsub("%s+", "")
        local customDuration = tonumber(durationPart) or 86400
        if #datePart < 12 then return 0, customDuration end
        
        local day = tonumber(datePart:sub(1, 2))
        local month = tonumber(datePart:sub(3, 4))
        local year = tonumber(datePart:sub(5, 8))
        local hour = tonumber(datePart:sub(9, 10))
        local min = tonumber(datePart:sub(11, 12))
        
        if not (day and month and year and hour and min) then return 0, customDuration end
        local success, timeVal = pcall(function()
            return os.time({year = year, month = month, day = day, hour = hour, min = min, sec = 0})
        end)
        return (success and timeVal or 0), customDuration
    end

    -- Sistem Pengecekan Badge Full Online (Tanpa JSON Lokal, Didukung Database Player Sheets)
    local function isFeatureNew(uniqueKey, configValue)
        if remoteMetadata["LastUpdate"] == "" or remoteMetadata["LastUpdate"] == "nil" then
            return false
        end
        if remoteMetadata[uniqueKey] == "" then
            return false
        end

        local startTime, durationSec = parseCustomConfig(configValue)
        if startTime == 0 then return false end

        local isNewOnline = false
        pcall(function()
            local req = request or http_request or (syn and syn.request)
            if req then
                local res = req({
                    Url = SHEETS_WEB_APP_URL,
                    Method = "POST",
                    Headers = { ["Content-Type"] = "application/json" },
                    Body = HttpService:JSONEncode({
                        Type = "CheckPlayerBadge",
                        UserId = LocalPlayer.UserId,
                        FeatureKey = uniqueKey,
                        ScriptTime = tostring(startTime),
                        DurationSec = durationSec
                    })
                })
                if res and res.Body then
                    local decoded = HttpService:JSONDecode(res.Body)
                    if decoded and decoded.status == "success" then
                        isNewOnline = decoded.isNew
                    end
                end
            end
        end)

        return isNewOnline
    end

    local function applyBlinkAnimation(label)
        task.spawn(function()
            while label and label.Parent do
                local tweenFadeOut = TweenService:Create(label, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {TextTransparency = 0.8})
                tweenFadeOut:Play()
                tweenFadeOut.Completed:Wait()
                if not (label and label.Parent) then break end
                local tweenFadeIn = TweenService:Create(label, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {TextTransparency = 0})
                tweenFadeIn:Play()
                tweenFadeIn.Completed:Wait()
            end
        end)
    end

    if not _G.MasterPluginHub_States then _G.MasterPluginHub_States = {} end
    local featureStates = _G.MasterPluginHub_States
    
    if not _G.MasterPluginHub_Buttons then _G.MasterPluginHub_Buttons = {} end
    local activeButtons = _G.MasterPluginHub_Buttons

    local loadedModules = {}

    local oldCore = CoreGui:FindFirstChild("MasterPluginHub")
    if oldCore then oldCore:Destroy() end

    local playerGui
    local playerGuiOk, playerGuiResult = pcall(function()
        return LocalPlayer:WaitForChild("PlayerGui", 10)
    end)
    if playerGuiOk then playerGui = playerGuiResult end

    if playerGui then
        local oldPlayer = playerGui:FindFirstChild("MasterPluginHub")
        if oldPlayer then oldPlayer:Destroy() end
    end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "MasterPluginHub"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.Parent = CoreGui

    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(0, 280, 0, 340)
    Frame.Position = UDim2.new(0.5, -140, 0.5, -170)
    Frame.BackgroundColor3 = Color3.fromRGB(20, 25, 32)
    Frame.BackgroundTransparency = 0.25
    Frame.BorderSizePixel = 0
    Frame.Active = true
    Frame.Draggable = false
    Frame.Parent = ScreenGui

    Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 6)

    local UIGradient = Instance.new("UIGradient")
    UIGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.0, Color3.fromRGB(28, 38, 52)),
        ColorSequenceKeypoint.new(1.0, Color3.fromRGB(15, 20, 28))
    })
    UIGradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0.0, 0.15),
        NumberSequenceKeypoint.new(1.0, 0.35)
    })
    UIGradient.Rotation = 45
    UIGradient.Parent = Frame

    local TopBar = Instance.new("Frame")
    TopBar.Size = UDim2.new(1, 0, 0, 30)
    TopBar.BackgroundColor3 = Color3.fromRGB(35, 45, 60)
    TopBar.BackgroundTransparency = 0.3
    TopBar.BorderSizePixel = 0
    TopBar.ZIndex = 10
    TopBar.Parent = Frame
    Instance.new("UICorner", TopBar).CornerRadius = UDim.new(0, 6)

    local dragging, dragInput, dragStart, startPos

    TopBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = Frame.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    TopBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            Frame.Position = UDim2.new(
                startPos.X.Scale, 
                startPos.X.Offset + delta.X, 
                startPos.Y.Scale, 
                startPos.Y.Offset + delta.Y
            )
        end
    end)

    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Size = UDim2.new(1, -70, 1, 0)
    TitleLabel.Position = UDim2.new(0, 8, 0, 0)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.Text = "PLUGIN MANAGER"
    TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    TitleLabel.TextSize = 12
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.ZIndex = 11
    TitleLabel.Parent = TopBar

    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, 20, 0, 20)
    CloseBtn.Position = UDim2.new(1, -25, 0, 5)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    CloseBtn.BorderSizePixel = 0
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.Text = "X"
    CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseBtn.TextSize = 10
    CloseBtn.ZIndex = 11
    CloseBtn.Parent = TopBar
    Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 4)

    CloseBtn.MouseButton1Click:Connect(function()
        task.spawn(function() sendTrackerData(true) end)
        ScreenGui:Destroy()
    end)

    local MinBtn = Instance.new("TextButton")
    MinBtn.Size = UDim2.new(0, 20, 0, 20)
    MinBtn.Position = UDim2.new(1, -50, 0, 5)
    MinBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
    MinBtn.BorderSizePixel = 0
    MinBtn.Font = Enum.Font.GothamBold
    MinBtn.Text = "-"
    MinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    MinBtn.TextSize = 11
    MinBtn.ZIndex = 11
    MinBtn.Parent = TopBar
    Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 4)

    local AUTHORIZED_USER_ID = 6141017541
    local isAuthorized = (LocalPlayer.UserId == AUTHORIZED_USER_ID)

    local DevBtn = Instance.new("TextButton")
    DevBtn.Size = UDim2.new(0, 54, 0, 20)
    DevBtn.Position = UDim2.new(1, -110, 0, 5) 
    DevBtn.BorderSizePixel = 0
    DevBtn.Font = Enum.Font.GothamBold
    DevBtn.TextSize = 9
    DevBtn.ZIndex = 11
    DevBtn.Parent = TopBar
    Instance.new("UICorner", DevBtn).CornerRadius = UDim.new(0, 4)

    if isAuthorized then
        DevBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 90)
        DevBtn.Text = "DEV PANEL"
        DevBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    else
        DevBtn.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
        DevBtn.Text = "DEV PANEL"
        DevBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    end

    local TabBar = Instance.new("ScrollingFrame")
    TabBar.Size = UDim2.new(1, -12, 0, 24)
    TabBar.Position = UDim2.new(0, 6, 0, 34)
    TabBar.BackgroundTransparency = 1
    TabBar.BorderSizePixel = 0
    TabBar.ScrollBarThickness = 0 
    TabBar.Parent = Frame

    local TabBarLayout = Instance.new("UIListLayout")
    TabBarLayout.FillDirection = Enum.FillDirection.Horizontal
    TabBarLayout.SortOrder = Enum.SortOrder.LayoutOrder
    TabBarLayout.Padding = UDim.new(0, 4)
    TabBarLayout.Parent = TabBar

    local HeaderContainer = Instance.new("Frame")
    HeaderContainer.Size = UDim2.new(1, -12, 0, 40)
    HeaderContainer.Position = UDim2.new(0, 6, 0, 62)
    HeaderContainer.BackgroundColor3 = Color3.fromRGB(25, 32, 42)
    HeaderContainer.BackgroundTransparency = 0.4
    HeaderContainer.BorderSizePixel = 0
    HeaderContainer.Parent = Frame
    Instance.new("UICorner", HeaderContainer).CornerRadius = UDim.new(0, 4)

    local AvatarImg = Instance.new("ImageLabel")
    AvatarImg.Size = UDim2.new(0, 36, 0, 36)
    AvatarImg.Position = UDim2.new(0, 2, 0, 2)
    AvatarImg.BackgroundColor3 = Color3.fromRGB(40, 50, 65)
    AvatarImg.BorderSizePixel = 0
    AvatarImg.Parent = HeaderContainer
    Instance.new("UICorner", AvatarImg).CornerRadius = UDim.new(0, 4)

    task.spawn(function()
        pcall(function()
            local content = Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
            if content then AvatarImg.Image = content end
        end)
    end)

    local MarqueeHolder = Instance.new("Frame")
    MarqueeHolder.Size = UDim2.new(1, -42, 0, 14)
    MarqueeHolder.Position = UDim2.new(0, 42, 0, 2)
    MarqueeHolder.BackgroundTransparency = 1
    MarqueeHolder.ClipsDescendants = true
    MarqueeHolder.Parent = HeaderContainer

    local MarqueeText = Instance.new("TextLabel")
    MarqueeText.Size = UDim2.new(0, 0, 1, 0)
    MarqueeText.Position = UDim2.new(1, 0, 0, 0)
    MarqueeText.BackgroundTransparency = 1
    MarqueeText.Font = Enum.Font.GothamBold
    MarqueeText.Text = CUSTOM_TEXT
    MarqueeText.TextColor3 = CUSTOM_TEXT_COLOR
    MarqueeText.TextSize = 9
    MarqueeText.TextXAlignment = Enum.TextXAlignment.Left
    MarqueeText.Parent = MarqueeHolder

    task.defer(function()
        local textSize = TextService:GetTextSize(MarqueeText.Text, 9, Enum.Font.GothamBold, Vector2.new(10000, 14))
        MarqueeText.Size = UDim2.new(0, textSize.X + 20, 1, 0)
        task.spawn(function()
            while MarqueeText and MarqueeText.Parent do
                MarqueeText.Position = UDim2.new(1, 0, 0, 0)
                local tween = TweenService:Create(MarqueeText, TweenInfo.new(SCROLL_SPEED, Enum.EasingStyle.Linear), {Position = UDim2.new(0, -textSize.X - 20, 0, 0)})
                tween:Play()
                tween.Completed:Wait()
            end
        end)
    end)

    local IdLabel = Instance.new("TextLabel")
    IdLabel.Size = UDim2.new(1, -44, 0, 12)
    IdLabel.Position = UDim2.new(0, 42, 0, 16)
    IdLabel.BackgroundTransparency = 1
    IdLabel.Font = Enum.Font.GothamBold
    IdLabel.Text = "@" .. LocalPlayer.Name .. " | ID: " .. tostring(LocalPlayer.UserId)
    IdLabel.TextColor3 = Color3.fromRGB(220, 230, 242)
    IdLabel.TextSize = 8
    IdLabel.TextXAlignment = Enum.TextXAlignment.Left
    IdLabel.Parent = HeaderContainer

    local MapLabel = Instance.new("TextLabel")
    MapLabel.Size = UDim2.new(1, -44, 0, 12)
    MapLabel.Position = UDim2.new(0, 42, 0, 26)
    MapLabel.BackgroundTransparency = 1
    MapLabel.Font = Enum.Font.Gotham
    MapLabel.Text = "Map: Memuat..."
    MapLabel.TextColor3 = Color3.fromRGB(160, 175, 195)
    MapLabel.TextSize = 8
    MapLabel.TextXAlignment = Enum.TextXAlignment.Left
    MapLabel.Parent = HeaderContainer

    task.spawn(function()
        pcall(function()
            local success, placeInfo = pcall(function() return MarketplaceService:GetProductInfo(game.PlaceId) end)
            if success and placeInfo and placeInfo.Name then
                MapLabel.Text = "Map: " .. placeInfo.Name
            else
                MapLabel.Text = "Map: " .. game.Name
            end
        end)
    end)

    local LastUpdateLabel = Instance.new("TextLabel")
    LastUpdateLabel.Size = UDim2.new(0, 160, 0, 14)
    LastUpdateLabel.Position = UDim2.new(0, 150, 0, 15)
    LastUpdateLabel.BackgroundTransparency = 1
    LastUpdateLabel.Font = Enum.Font.GothamBold
    LastUpdateLabel.Text = "Last Update: Memuat..."
    LastUpdateLabel.TextColor3 = Color3.fromRGB(160, 175, 195)
    LastUpdateLabel.TextSize = 8
    LastUpdateLabel.TextXAlignment = Enum.TextXAlignment.Left
    LastUpdateLabel.Parent = HeaderContainer

    task.spawn(function()
        pcall(function()
            local response = game:HttpGet(SHEETS_WEB_APP_URL)
            if response and response ~= "" and response ~= "Belum ada update" then
                local raw = tostring(response):match("^%s*(.-)%s*$") or tostring(response)
                local dd, mm, yyyy, hour, min

                dd, mm, yyyy, hour, min = raw:match("^(%d%d?)[/%-](%d%d?)[/%-](%d%d%d%d)[ T](%d%d?):(%d%d?)")

                if not (dd and mm and yyyy and hour and min) then
                    local digits = raw:gsub("%D", "")
                    if #digits >= 12 then
                        dd = digits:sub(1, 2)
                        mm = digits:sub(3, 4)
                        yyyy = digits:sub(5, 8)
                        hour = digits:sub(9, 10)
                        min = digits:sub(11, 12)
                    end
                end

                if dd and mm and yyyy and hour and min then
                    dd = string.format("%02d", tonumber(dd) or 0)
                    mm = string.format("%02d", tonumber(mm) or 0)
                    hour = string.format("%02d", tonumber(hour) or 0)
                    min = string.format("%02d", tonumber(min) or 0)

                    LastUpdateLabel.Text = "Last Update: " .. dd .. "/" .. mm .. "/" .. yyyy .. " " .. hour .. ":" .. min
                else
                    LastUpdateLabel.Text = "Last Update: " .. raw
                end
            else
                LastUpdateLabel.Text = "Last Update: -"
            end
        end)
    end)

    local ContentArea = Instance.new("Frame")
    ContentArea.Size = UDim2.new(1, -12, 1, -108)
    ContentArea.Position = UDim2.new(0, 6, 0, 104)
    ContentArea.BackgroundTransparency = 1
    ContentArea.BorderSizePixel = 0
    ContentArea.Parent = Frame

    local SubMenuContainer = Instance.new("Frame")
    SubMenuContainer.Size = UDim2.new(1, 0, 1, 0)
    SubMenuContainer.BackgroundTransparency = 1
    SubMenuContainer.BorderSizePixel = 0
    SubMenuContainer.Visible = false
    SubMenuContainer.Parent = ContentArea

    local tabButtons = {}
    local tabScrolls = {}

    -- ==========================================
    -- 🛠️ DEV PANEL CONTAINER & SISTEM HALAMAN
    -- ==========================================
    local DevPanelContainer = Instance.new("Frame")
    DevPanelContainer.Size = UDim2.new(1, 0, 1, -30)
    DevPanelContainer.Position = UDim2.new(0, 0, 0, 30)
    DevPanelContainer.BackgroundColor3 = Color3.fromRGB(18, 22, 30)
    DevPanelContainer.BackgroundTransparency = 0.1
    DevPanelContainer.BorderSizePixel = 0
    DevPanelContainer.Visible = false
    DevPanelContainer.ZIndex = 30
    DevPanelContainer.Parent = Frame
    Instance.new("UICorner", DevPanelContainer).CornerRadius = UDim.new(0, 6)

    local DevTitle = Instance.new("TextLabel")
    DevTitle.Size = UDim2.new(1, -70, 0, 30)
    DevTitle.Position = UDim2.new(0, 10, 0, 5)
    DevTitle.BackgroundTransparency = 1
    DevTitle.Font = Enum.Font.GothamBold
    DevTitle.Text = "⚙️ DEVELOPER CONTROL PANEL"
    DevTitle.TextColor3 = Color3.fromRGB(0, 220, 255)
    DevTitle.TextSize = 11
    DevTitle.TextXAlignment = Enum.TextXAlignment.Left
    DevTitle.ZIndex = 31
    DevTitle.Parent = DevPanelContainer

    local DevBackBtn = Instance.new("TextButton")
    DevBackBtn.Size = UDim2.new(0, 50, 0, 20)
    DevBackBtn.Position = UDim2.new(1, -60, 0, 8)
    DevBackBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    DevBackBtn.BorderSizePixel = 0
    DevBackBtn.Font = Enum.Font.GothamBold
    DevBackBtn.Text = "CLOSE"
    DevBackBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    DevBackBtn.TextSize = 9
    DevBackBtn.ZIndex = 31
    DevBackBtn.Parent = DevPanelContainer
    Instance.new("UICorner", DevBackBtn).CornerRadius = UDim.new(0, 4)

    DevBackBtn.MouseButton1Click:Connect(function()
        DevPanelContainer.Visible = false
        if currentActiveScroll then
            currentActiveScroll.Visible = true
        end
    end)

    local DevMainMenu = Instance.new("ScrollingFrame")
    DevMainMenu.Size = UDim2.new(1, -16, 1, -45)
    DevMainMenu.Position = UDim2.new(0, 8, 0, 40)
    DevMainMenu.BackgroundTransparency = 1
    DevMainMenu.BorderSizePixel = 0
    DevMainMenu.ScrollBarThickness = 4
    DevMainMenu.ZIndex = 31
    DevMainMenu.Parent = DevPanelContainer

    local MainMenuLayout = Instance.new("UIListLayout")
    MainMenuLayout.SortOrder = Enum.SortOrder.LayoutOrder
    MainMenuLayout.Padding = UDim.new(0, 6)
    MainMenuLayout.Parent = DevMainMenu

    local BadgeListView = Instance.new("Frame")
    BadgeListView.Size = UDim2.new(1, -16, 1, -45)
    BadgeListView.Position = UDim2.new(0, 8, 0, 40)
    BadgeListView.BackgroundTransparency = 1
    BadgeListView.Visible = false
    BadgeListView.ZIndex = 31
    BadgeListView.Parent = DevPanelContainer

    local BadgeBackMenuBtn = Instance.new("TextButton")
    BadgeBackMenuBtn.Size = UDim2.new(1, 0, 0, 28)
    BadgeBackMenuBtn.BackgroundColor3 = Color3.fromRGB(35, 45, 60)
    BadgeBackMenuBtn.BorderSizePixel = 0
    BadgeBackMenuBtn.Font = Enum.Font.GothamBold
    BadgeBackMenuBtn.Text = "< KEMBALI KE MENU DEV"
    BadgeBackMenuBtn.TextColor3 = Color3.fromRGB(0, 200, 255)
    BadgeBackMenuBtn.TextSize = 10
    BadgeBackMenuBtn.ZIndex = 32
    BadgeBackMenuBtn.Parent = BadgeListView
    Instance.new("UICorner", BadgeBackMenuBtn).CornerRadius = UDim.new(0, 4)

    BadgeBackMenuBtn.MouseButton1Click:Connect(function()
        BadgeListView.Visible = false
        DevMainMenu.Visible = true
    end)

    local BadgeScroll = Instance.new("ScrollingFrame")
    BadgeScroll.Size = UDim2.new(1, 0, 1, -34)
    BadgeScroll.Position = UDim2.new(0, 0, 0, 34)
    BadgeScroll.BackgroundTransparency = 1
    BadgeScroll.BorderSizePixel = 0
    BadgeScroll.ScrollBarThickness = 4
    BadgeScroll.ZIndex = 32
    BadgeScroll.Parent = BadgeListView

    local BadgeScrollLayout = Instance.new("UIListLayout")
    BadgeScrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
    BadgeScrollLayout.Padding = UDim.new(0, 6)
    BadgeScrollLayout.Parent = BadgeScroll

    local function addDevMenuOption(titleText, descText, onClickCallback)
        local OptionBtn = Instance.new("TextButton")
        OptionBtn.Size = UDim2.new(1, 0, 0, 40)
        OptionBtn.BackgroundColor3 = Color3.fromRGB(28, 36, 48)
        OptionBtn.BorderSizePixel = 0
        OptionBtn.Text = ""
        OptionBtn.ZIndex = 32
        OptionBtn.Parent = DevMainMenu
        Instance.new("UICorner", OptionBtn).CornerRadius = UDim.new(0, 4)

        local OptTitle = Instance.new("TextLabel")
        OptTitle.Size = UDim2.new(1, -15, 0, 18)
        OptTitle.Position = UDim2.new(0, 8, 0, 4)
        OptTitle.BackgroundTransparency = 1
        OptTitle.Font = Enum.Font.GothamBold
        OptTitle.Text = titleText
        OptTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
        OptTitle.TextSize = 10
        OptTitle.TextXAlignment = Enum.TextXAlignment.Left
        OptTitle.ZIndex = 33
        OptTitle.Parent = OptionBtn

        local OptDesc = Instance.new("TextLabel")
        OptDesc.Size = UDim2.new(1, -15, 0, 14)
        OptDesc.Position = UDim2.new(0, 8, 0, 20)
        OptDesc.BackgroundTransparency = 1
        OptDesc.Font = Enum.Font.Gotham
        OptDesc.Text = descText
        OptDesc.TextColor3 = Color3.fromRGB(160, 175, 195)
        OptDesc.TextSize = 8
        OptDesc.TextXAlignment = Enum.TextXAlignment.Left
        OptDesc.ZIndex = 33
        OptDesc.Parent = OptionBtn

        OptionBtn.MouseButton1Click:Connect(function()
            if onClickCallback then onClickCallback() end
        end)
    end

    local function createBadgeRow(targetKey, displayName, parentScroll, webUrl, refreshCallback)
        local ItemRow = Instance.new("Frame")
        ItemRow.Size = UDim2.new(1, 0, 0, 36)
        ItemRow.BackgroundColor3 = Color3.fromRGB(25, 32, 42)
        ItemRow.BorderSizePixel = 0
        ItemRow.ZIndex = 33
        ItemRow.Parent = parentScroll
        Instance.new("UICorner", ItemRow).CornerRadius = UDim.new(0, 4)

        local NameLbl = Instance.new("TextLabel")
        NameLbl.Size = UDim2.new(1, -70, 1, 0)
        NameLbl.Position = UDim2.new(0, 8, 0, 0)
        NameLbl.BackgroundTransparency = 1
        NameLbl.Font = Enum.Font.GothamBold
        NameLbl.Text = displayName
        NameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
        NameLbl.TextSize = 9
        NameLbl.TextXAlignment = Enum.TextXAlignment.Left
        NameLbl.ZIndex = 34
        NameLbl.Parent = ItemRow

        local DeleteBadgeBtn = Instance.new("TextButton")
        DeleteBadgeBtn.Size = UDim2.new(0, 55, 0, 22)
        DeleteBadgeBtn.AnchorPoint = Vector2.new(1, 0.5)
        DeleteBadgeBtn.Position = UDim2.new(1, -8, 0.5, 0)
        DeleteBadgeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        DeleteBadgeBtn.BorderSizePixel = 0
        DeleteBadgeBtn.Font = Enum.Font.GothamBold
        DeleteBadgeBtn.Text = "HAPUS"
        DeleteBadgeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        DeleteBadgeBtn.TextSize = 8
        DeleteBadgeBtn.ZIndex = 34
        DeleteBadgeBtn.Parent = ItemRow
        Instance.new("UICorner", DeleteBadgeBtn).CornerRadius = UDim.new(0, 4)

        DeleteBadgeBtn.MouseButton1Click:Connect(function()
            DeleteBadgeBtn.Text = "..."
            task.spawn(function()
                pcall(function()
                    local req = request or http_request or (syn and syn.request)
                    if req then
                        req({
                            Url = webUrl,
                            Method = "POST",
                            Headers = { ["Content-Type"] = "application/json" },
                            Body = HttpService:JSONEncode({ Type = "FeatureUpdate", Key = targetKey, Timestamp = "" })
                        })

                        remoteMetadata[targetKey] = ""
                        DeleteBadgeBtn.Text = "SUKSES!"
                        task.wait(1.5)
                        if refreshCallback then refreshCallback() end
                    else
                        DeleteBadgeBtn.Text = "ERROR"
                        task.wait(1)
                        DeleteBadgeBtn.Text = "HAPUS"
                    end
                end)
            end)
        end)
    end

    local function loadBadgeListForDev()
        for _, child in ipairs(BadgeScroll:GetChildren()) do
            if child:IsA("Frame") or child:IsA("TextLabel") then
                child:Destroy()
            end
        end

        local ResetAllRow = Instance.new("Frame")
        ResetAllRow.Size = UDim2.new(1, 0, 0, 36)
        ResetAllRow.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
        ResetAllRow.BorderSizePixel = 0
        ResetAllRow.ZIndex = 33
        ResetAllRow.Parent = BadgeScroll
        Instance.new("UICorner", ResetAllRow).CornerRadius = UDim.new(0, 4)

        local AllLbl = Instance.new("TextLabel")
        AllLbl.Size = UDim2.new(1, -70, 1, 0)
        AllLbl.Position = UDim2.new(0, 8, 0, 0)
        AllLbl.BackgroundTransparency = 1
        AllLbl.Font = Enum.Font.GothamBold
        AllLbl.Text = "🚨 Hapus Semua Badge Global"
        AllLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
        AllLbl.TextSize = 9
        AllLbl.TextXAlignment = Enum.TextXAlignment.Left
        AllLbl.ZIndex = 34
        AllLbl.Parent = ResetAllRow

        local ResetAllBtn = Instance.new("TextButton")
        ResetAllBtn.Size = UDim2.new(0, 55, 0, 22)
        ResetAllBtn.AnchorPoint = Vector2.new(1, 0.5)
        ResetAllBtn.Position = UDim2.new(1, -8, 0.5, 0)
        ResetAllBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        ResetAllBtn.BorderSizePixel = 0
        ResetAllBtn.Font = Enum.Font.GothamBold
        ResetAllBtn.Text = "SEMUA"
        ResetAllBtn.TextColor3 = Color3.fromRGB(180, 40, 40)
        ResetAllBtn.TextSize = 8
        ResetAllBtn.ZIndex = 34
        ResetAllBtn.Parent = ResetAllRow
        Instance.new("UICorner", ResetAllBtn).CornerRadius = UDim.new(0, 4)

        ResetAllBtn.MouseButton1Click:Connect(function()
            ResetAllBtn.Text = "..."
            task.spawn(function()
                pcall(function()
                    local req = request or http_request or (syn and syn.request)
                    if req then
                        req({
                            Url = SHEETS_WEB_APP_URL,
                            Method = "POST",
                            Headers = { ["Content-Type"] = "application/json" },
                            Body = HttpService:JSONEncode({ Type = "LastUpdate", Key = "LastUpdate", Timestamp = "" })
                        })
                        remoteMetadata["LastUpdate"] = ""
                        ResetAllBtn.Text = "SUKSES!"
                        task.wait(1.5)
                        loadBadgeListForDev()
                    end
                end)
            end)
        end)

        if not globalLoaderData then
            local LoadingLbl = Instance.new("TextLabel")
            LoadingLbl.Size = UDim2.new(1, 0, 0, 30)
            LoadingLbl.BackgroundTransparency = 1
            LoadingLbl.Font = Enum.Font.GothamBold
            LoadingLbl.Text = "Memuat data dari Loader..."
            LoadingLbl.TextColor3 = Color3.fromRGB(160, 175, 195)
            LoadingLbl.TextSize = 9
            LoadingLbl.Parent = BadgeScroll
            return
        end

        local activeBadgeCount = 0
        local detectedTabs = globalLoaderData.Tabs or {}

        for _, tabInfo in ipairs(detectedTabs) do
            local tabName = tabInfo.Name
            local dataKey = tabInfo.DataKey
            local items = globalLoaderData[dataKey] or {}

            local tabUniqueKey = "TabAutoBadge_" .. tabName
            local isTabBadgeActive = isFeatureNew(tabUniqueKey, "071120260000, 86400")

            local activeItemsInTab = {}

            for _, item in ipairs(items) do
                local uniqueKey = tostring(item.RawUrl) .. "_" .. tostring(item.Cmd or item.Name)
                local timestamp = item.UpdateTimestamp or ""
                local isMaintenance = (not item.SubFeatures and (not item.Cmd or item.Cmd == ""))
                local hasBadge = isFeatureNew(uniqueKey, timestamp) or isMaintenance

                local activeSubFeatures = {}
                if item.SubFeatures and #item.SubFeatures > 0 then
                    for _, sub in ipairs(item.SubFeatures) do
                        local subRaw = (sub.RawUrl and sub.RawUrl ~= "") and sub.RawUrl or item.RawUrl
                        local subKey = tostring(subRaw) .. "_" .. tostring(sub.Cmd)
                        local subTimestamp = sub.UpdateTimestamp or ""
                        local isSubMaint = (not sub.Cmd or sub.Cmd == "")
                        if isFeatureNew(subKey, subTimestamp) or isSubMaint then
                            table.insert(activeSubFeatures, {sub = sub, key = subKey})
                        end
                    end
                end

                if hasBadge or #activeSubFeatures > 0 then
                    table.insert(activeItemsInTab, {item = item, key = uniqueKey, subFeatures = activeSubFeatures})
                end
            end

            if isTabBadgeActive or #activeItemsInTab > 0 then
                activeBadgeCount = activeBadgeCount + 1

                local TabHeader = Instance.new("TextLabel")
                TabHeader.Size = UDim2.new(1, 0, 0, 24)
                TabHeader.BackgroundTransparency = 1
                TabHeader.Font = Enum.Font.GothamBold
                TabHeader.Text = "📁 TAB: " .. string.upper(tabName)
                TabHeader.TextColor3 = Color3.fromRGB(0, 220, 255)
                TabHeader.TextSize = 9
                TabHeader.ZIndex = 33
                TabHeader.Parent = BadgeScroll

                if isTabBadgeActive then
                    createBadgeRow(tabUniqueKey, "Tab Utama: " .. tabName, BadgeScroll, SHEETS_WEB_APP_URL, loadBadgeListForDev)
                end

                for _, entry in ipairs(activeItemsInTab) do
                    createBadgeRow(entry.key, entry.item.Name, BadgeScroll, SHEETS_WEB_APP_URL, loadBadgeListForDev)

                    for _, subEntry in ipairs(entry.subFeatures) do
                        createBadgeRow(subEntry.key, "  ↳ " .. subEntry.sub.Name, BadgeScroll, SHEETS_WEB_APP_URL, loadBadgeListForDev)
                    end
                end
            end
        end

        if activeBadgeCount == 0 then
            local EmptyNotice = Instance.new("TextLabel")
            EmptyNotice.Size = UDim2.new(1, 0, 0, 40)
            EmptyNotice.BackgroundTransparency = 1
            EmptyNotice.Font = Enum.Font.GothamBold
            EmptyNotice.Text = "✨ Tidak ada badge aktif saat ini!"
            EmptyNotice.TextColor3 = Color3.fromRGB(160, 175, 195)
            EmptyNotice.TextSize = 9
            EmptyNotice.TextXAlignment = Enum.TextXAlignment.Center
            EmptyNotice.ZIndex = 33
            EmptyNotice.Parent = BadgeScroll
        end

        task.defer(function()
            local totalH = 0
            for _, child in ipairs(BadgeScroll:GetChildren()) do
                if child:IsA("Frame") or child:IsA("TextLabel") then
                    totalH = totalH + child.AbsoluteSize.Y + 6
                end
            end
            BadgeScroll.CanvasSize = UDim2.new(0, 0, 0, totalH)
        end)
    end

    addDevMenuOption("🗑️ Hapus Badge Fitur", "Pilih dan bersihkan badge update/new pada fitur secara spesifik", function()
        DevMainMenu.Visible = false
        loadBadgeListForDev()
        BadgeListView.Visible = true
    end)

    DevBtn.MouseButton1Click:Connect(function()
        if not isAuthorized then
            pcall(function()
                local StarterGui = game:GetService("StarterGui")
                StarterGui:SetCore("SendNotification", {
                    Title = "Access Denied",
                    Text = "Menu ini khusus Developer!",
                    Duration = 3
                })
            end)
            return
        end

        if tabScrolls then
            for _, scroll in pairs(tabScrolls) do
                if scroll then scroll.Visible = false end
            end
        end
        if SubMenuContainer then SubMenuContainer.Visible = false end

        if DevPanelContainer then
            DevMainMenu.Visible = true
            BadgeListView.Visible = false
            DevPanelContainer.Visible = true
        end
    end)

    local function setTabBadge(tabName, badgeText, badgeColor, priority)
        local tabBtn = tabButtons[tabName]
        if not tabBtn then return end

        local badgeName = "TabUnifiedBadge"
        local existing = tabBtn:FindFirstChild(badgeName)
        local currentPriority = existing and (existing:GetAttribute("BadgePriority") or 0) or 0
        priority = tonumber(priority) or 1

        if existing and priority < currentPriority then return end

        if not existing then
            existing = Instance.new("TextLabel")
            existing.Name = badgeName
            existing.BackgroundTransparency = 1
            existing.Font = Enum.Font.GothamBold
            existing.TextSize = 8
            existing.TextXAlignment = Enum.TextXAlignment.Center
            existing.TextYAlignment = Enum.TextYAlignment.Center
            existing.AnchorPoint = Vector2.new(1, 0)
            existing.Position = UDim2.new(1, -3, 0, 2)
            existing.Parent = tabBtn
            applyBlinkAnimation(existing)
        end

        existing:SetAttribute("BadgePriority", priority)
        existing.Text = tostring(badgeText or "NEW")
        existing.TextColor3 = badgeColor or Color3.fromRGB(255, 215, 0)
        local width = TextService:GetTextSize(existing.Text, 8, Enum.Font.GothamBold, Vector2.new(100, 20)).X
        existing.Size = UDim2.new(0, math.max(22, width + 6), 0, 12)
    end

    local function showInputDialog(titleText, onSubmit)
        local PromptOverlay = Instance.new("Frame")
        PromptOverlay.Size = UDim2.new(1, 0, 1, 0)
        PromptOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        PromptOverlay.BackgroundTransparency = 0.5
        PromptOverlay.ZIndex = 50
        PromptOverlay.Parent = Frame

        local PromptBox = Instance.new("Frame")
        PromptBox.Size = UDim2.new(0, 220, 0, 110)
        PromptBox.Position = UDim2.new(0.5, -110, 0.5, -55)
        PromptBox.BackgroundColor3 = Color3.fromRGB(30, 38, 50)
        PromptBox.BorderSizePixel = 0
        PromptBox.ZIndex = 51
        PromptBox.Parent = PromptOverlay
        Instance.new("UICorner", PromptBox).CornerRadius = UDim.new(0, 6)

        local PromptTitle = Instance.new("TextLabel")
        PromptTitle.Size = UDim2.new(1, 0, 0, 25)
        PromptTitle.Position = UDim2.new(0, 0, 0, 5)
        PromptTitle.BackgroundTransparency = 1
        PromptTitle.Font = Enum.Font.GothamBold
        PromptTitle.Text = "INPUT: " .. titleText
        PromptTitle.TextColor3 = Color3.fromRGB(0, 200, 255)
        PromptTitle.TextSize = 11
        PromptTitle.ZIndex = 52
        PromptTitle.Parent = PromptBox

        local TextBox = Instance.new("TextBox")
        TextBox.Size = UDim2.new(1, -20, 0, 30)
        TextBox.Position = UDim2.new(0, 10, 0, 35)
        TextBox.BackgroundColor3 = Color3.fromRGB(15, 20, 28)
        TextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
        TextBox.PlaceholderText = "Baca Deskripsi..."
        TextBox.Text = ""
        TextBox.Font = Enum.Font.Gotham
        TextBox.TextSize = 11
        TextBox.ZIndex = 52
        TextBox.Parent = PromptBox
        Instance.new("UICorner", TextBox).CornerRadius = UDim.new(0, 4)

        local SubmitBtn = Instance.new("TextButton")
        SubmitBtn.Size = UDim2.new(0, 95, 0, 24)
        SubmitBtn.Position = UDim2.new(0, 10, 0, 75)
        SubmitBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 90)
        SubmitBtn.Text = "SUBMIT"
        SubmitBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        SubmitBtn.Font = Enum.Font.GothamBold
        SubmitBtn.TextSize = 10
        SubmitBtn.ZIndex = 52
        SubmitBtn.Parent = PromptBox
        Instance.new("UICorner", SubmitBtn).CornerRadius = UDim.new(0, 4)

        local CancelBtn = Instance.new("TextButton")
        CancelBtn.Size = UDim2.new(0, 95, 0, 24)
        CancelBtn.Position = UDim2.new(1, -105, 0, 75)
        CancelBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        CancelBtn.Text = "CANCEL"
        CancelBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        CancelBtn.Font = Enum.Font.GothamBold
        CancelBtn.TextSize = 10
        CancelBtn.ZIndex = 52
        CancelBtn.Parent = PromptBox
        Instance.new("UICorner", CancelBtn).CornerRadius = UDim.new(0, 4)

        SubmitBtn.MouseButton1Click:Connect(function()
            local inputVal = TextBox.Text
            PromptOverlay:Destroy()
            if onSubmit then onSubmit(inputVal) end
        end)

        CancelBtn.MouseButton1Click:Connect(function() PromptOverlay:Destroy() end)
    end

    local function updateAllButtonStates(uniqueKey, isActive)
        if not activeButtons[uniqueKey] then return end
        for _, btnObj in ipairs(activeButtons[uniqueKey]) do
            if btnObj and btnObj.Parent then
                if isActive then
                    btnObj.Text = "UNEXECUTE"
                    btnObj.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
                else
                    btnObj.Text = "EXECUTE"
                    btnObj.BackgroundColor3 = Color3.fromRGB(0, 150, 90)
                end
            end
        end
    end

    local minimized = false
    MinBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        if minimized then
            Frame.Size = UDim2.new(0, 280, 0, 30)
            MinBtn.Text = "+"
            TabBar.Visible = false
            HeaderContainer.Visible = false
            ContentArea.Visible = false
        else
            Frame.Size = UDim2.new(0, 280, 0, 340)
            MinBtn.Text = "-"
            TabBar.Visible = true
            HeaderContainer.Visible = true
            ContentArea.Visible = true
        end
    end)

    local function showSubMenu(menuTitle, rawUrl, subFeatures)
        isCurrentlyInSubMenu = true
        for _, child in ipairs(SubMenuContainer:GetChildren()) do child:Destroy() end
        SubMenuContainer.Visible = true
        for _, scroll in pairs(tabScrolls) do scroll.Visible = false end

        local BackBtn = Instance.new("TextButton")
        BackBtn.Size = UDim2.new(1, 0, 0, 26)
        BackBtn.BackgroundColor3 = Color3.fromRGB(35, 45, 60)
        BackBtn.BackgroundTransparency = 0.3
        BackBtn.BorderSizePixel = 0
        BackBtn.Font = Enum.Font.GothamBold
        BackBtn.Text = "< BACK : " .. menuTitle
        BackBtn.TextColor3 = Color3.fromRGB(0, 200, 255)
        BackBtn.TextSize = 10
        BackBtn.Parent = SubMenuContainer
        Instance.new("UICorner", BackBtn).CornerRadius = UDim.new(0, 4)

        local SubScroll = Instance.new("ScrollingFrame")
        SubScroll.Size = UDim2.new(1, 0, 1, -30)
        SubScroll.Position = UDim2.new(0, 0, 0, 30)
        SubScroll.BackgroundTransparency = 1
        SubScroll.BorderSizePixel = 0
        SubScroll.ScrollBarThickness = 4
        SubScroll.Parent = SubMenuContainer

        local SubLayout = Instance.new("UIListLayout")
        SubLayout.SortOrder = Enum.SortOrder.LayoutOrder
        SubLayout.Padding = UDim.new(0, 5)
        SubLayout.Parent = SubScroll

        BackBtn.MouseButton1Click:Connect(function()
            isCurrentlyInSubMenu = false
            SubMenuContainer.Visible = false
            currentActiveScroll.Visible = true
        end)

        for _, subFeat in ipairs(subFeatures) do
            local uniqueKey = tostring(subFeat.RawUrl or rawUrl) .. "_" .. tostring(subFeat.Cmd)
            if featureStates[uniqueKey] == nil then featureStates[uniqueKey] = false end

            local Item = Instance.new("Frame")
            Item.BackgroundColor3 = Color3.fromRGB(25, 32, 42)
            Item.BackgroundTransparency = 0.35
            Item.BorderSizePixel = 0
            Item.Parent = SubScroll
            Instance.new("UICorner", Item).CornerRadius = UDim.new(0, 4)

            local LblName = Instance.new("TextLabel")
            LblName.Size = UDim2.new(1, -90, 0, 18)
            LblName.Position = UDim2.new(0, 8, 0, 4)
            LblName.BackgroundTransparency = 1
            LblName.Text = subFeat.Name
            LblName.TextColor3 = Color3.fromRGB(0, 220, 255)
            LblName.Font = Enum.Font.GothamBold
            LblName.TextSize = 11
            LblName.TextXAlignment = Enum.TextXAlignment.Left
            LblName.Parent = Item

            local timestamp = subFeat.UpdateTimestamp or ""
            local activeBadgeText = subFeat.BadgeText or "New!"
            local activeBadgeColor = getColorFromName(subFeat.BadgeColor)
            local isMaintenance = (not subFeat.Cmd or subFeat.Cmd == "")

            if isMaintenance then
                activeBadgeText = "MAINTENANCE!"
                activeBadgeColor = Color3.fromRGB(255, 60, 60)
            end

            if isFeatureNew(uniqueKey, timestamp) or isMaintenance then
                local badgeText = "[" .. activeBadgeText .. "]"
                local textWidth = TextService:GetTextSize(badgeText, 9, Enum.Font.GothamBold, Vector2.new(200, 20)).X
                
                local NewBadge = Instance.new("TextLabel")
                NewBadge.Size = UDim2.new(0, textWidth + 5, 0, 14)
                NewBadge.Position = UDim2.new(0, TextService:GetTextSize(subFeat.Name, 11, Enum.Font.GothamBold, Vector2.new(150, 20)).X + 12, 0, 2)
                NewBadge.BackgroundTransparency = 1
                NewBadge.Text = badgeText
                NewBadge.TextColor3 = activeBadgeColor
                NewBadge.Font = Enum.Font.GothamBold
                NewBadge.TextSize = 9
                NewBadge.Parent = Item
                applyBlinkAnimation(NewBadge)
            end

            local LblDesc = Instance.new("TextLabel")
            LblDesc.Position = UDim2.new(0, 8, 0, 22)
            LblDesc.BackgroundTransparency = 1
            LblDesc.Text = subFeat.Desc
            LblDesc.TextColor3 = Color3.fromRGB(160, 170, 185)
            LblDesc.Font = Enum.Font.Gotham
            LblDesc.TextSize = 10
            LblDesc.TextXAlignment = Enum.TextXAlignment.Left
            LblDesc.TextYAlignment = Enum.TextYAlignment.Top
            LblDesc.TextWrapped = true
            LblDesc.Parent = Item

            local textBounds = TextService:GetTextSize(subFeat.Desc, 10, Enum.Font.Gotham, Vector2.new(174, 10000))
            local descHeight = math.max(14, textBounds.Y + 5)
            LblDesc.Size = UDim2.new(1, -90, 0, descHeight)
            Item.Size = UDim2.new(1, 0, 0, descHeight + 28)

            local ExecSub = Instance.new("TextButton")
            ExecSub.Size = UDim2.new(0, 75, 0, 24)
            ExecSub.AnchorPoint = Vector2.new(0, 0.5)
            ExecSub.Position = UDim2.new(1, -80, 0.5, 0)
            ExecSub.BorderSizePixel = 0
            ExecSub.Text = featureStates[uniqueKey] and "UNEXECUTE" or "EXECUTE"
            ExecSub.TextColor3 = Color3.fromRGB(255, 255, 255)
            ExecSub.Font = Enum.Font.GothamBold
            ExecSub.TextSize = 10
            ExecSub.Parent = Item
            Instance.new("UICorner", ExecSub).CornerRadius = UDim.new(0, 4)

            if isMaintenance then
                ExecSub.Text = "MAINT"
                ExecSub.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
                ExecSub.Active = false
            else
                ExecSub.BackgroundColor3 = featureStates[uniqueKey] and Color3.fromRGB(200, 50, 50) or Color3.fromRGB(0, 150, 90)
                if not activeButtons[uniqueKey] then activeButtons[uniqueKey] = {} end
                table.insert(activeButtons[uniqueKey], ExecSub)

                ExecSub.MouseButton1Click:Connect(function()
                    local function runCommand(customArgs, isUnexec)
                        pcall(function()
                            local targetRaw = (subFeat.RawUrl and subFeat.RawUrl ~= "") and subFeat.RawUrl or rawUrl
                            if not loadedModules[targetRaw] then
                                loadedModules[targetRaw] = loadstring(game:HttpGet(targetRaw))()
                            end
                            local pluginMod = loadedModules[targetRaw]
                            if pluginMod and pluginMod.Commands then
                                local targetCmd = isUnexec and subFeat.UnCmd or subFeat.Cmd
                                local foundFunc = nil
                                for cmdName, cmdData in pairs(pluginMod.Commands) do
                                    if string.lower(cmdName) == string.lower(tostring(targetCmd)) then
                                        if type(cmdData.Function) == "function" then
                                            foundFunc = cmdData.Function
                                            break
                                        end
                                    end
                                end
                                if foundFunc then task.spawn(function() foundFunc(customArgs or {}, speaker) end) end
                            end
                        end)

                        local hasUnCmd = subFeat.UnCmd and subFeat.UnCmd ~= ""
                        if hasUnCmd then
                            featureStates[uniqueKey] = not featureStates[uniqueKey]
                            updateAllButtonStates(uniqueKey, featureStates[uniqueKey])
                        else
                            featureStates[uniqueKey] = false
                            updateAllButtonStates(uniqueKey, false)
                        end
                    end

                    if featureStates[uniqueKey] then
                        runCommand({}, true)
                    else
                        if subFeat.NeedInput then
                            showInputDialog(subFeat.Name, function(typedText)
                                local argsTable = {}
                                for word in string.gmatch(typedText, "%S+") do table.insert(argsTable, word) end
                                runCommand(argsTable, false)
                            end)
                        else
                            runCommand({}, false)
                        end
                    end
                end)
            end
        end
        
        task.defer(function()
            local totalHeight = 0
            for _, child in ipairs(SubScroll:GetChildren()) do
                if child:IsA("Frame") then totalHeight = totalHeight + child.AbsoluteSize.Y + 5 end
            end
            SubScroll.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
        end)
    end

    local function renderMenuCategory(menuList, targetParentScroll, tabName)
        if not menuList or #menuList == 0 then
            local EmptyNotice = Instance.new("TextLabel")
            EmptyNotice.Size = UDim2.new(1, 0, 1, 0)
            EmptyNotice.BackgroundTransparency = 1
            EmptyNotice.Font = Enum.Font.GothamBold
            EmptyNotice.Text = "NANTIKAN UPDATENYA !!"
            EmptyNotice.TextColor3 = Color3.fromRGB(0, 220, 255)
            EmptyNotice.TextSize = 16
            EmptyNotice.TextWrapped = true
            EmptyNotice.TextXAlignment = Enum.TextXAlignment.Center
            EmptyNotice.TextYAlignment = Enum.TextYAlignment.Center
            EmptyNotice.Parent = targetParentScroll
            applyBlinkAnimation(EmptyNotice)
            return
        end

        for _, item in ipairs(menuList) do
            local ItemFrame = Instance.new("Frame")
            ItemFrame.BackgroundColor3 = Color3.fromRGB(25, 32, 42)
            ItemFrame.BackgroundTransparency = 0.35
            ItemFrame.BorderSizePixel = 0
            ItemFrame.Parent = targetParentScroll
            Instance.new("UICorner", ItemFrame).CornerRadius = UDim.new(0, 4)

            local NameLabel = Instance.new("TextLabel")
            NameLabel.Size = UDim2.new(1, -90, 0, 18)
            NameLabel.Position = UDim2.new(0, 8, 0, 4)
            NameLabel.BackgroundTransparency = 1
            NameLabel.Text = item.Name
            NameLabel.TextColor3 = Color3.fromRGB(0, 220, 255)
            NameLabel.Font = Enum.Font.GothamBold
            NameLabel.TextSize = 11
            NameLabel.TextXAlignment = Enum.TextXAlignment.Left
            NameLabel.Parent = ItemFrame

            local uniqueKey = tostring(item.RawUrl) .. "_" .. tostring(item.Cmd or item.Name)
            local timestamp = item.UpdateTimestamp or ""
            local activeBadgeText = item.BadgeText or "New!"
            local activeBadgeColorName = item.BadgeColor
            local isMaintenance = (not item.SubFeatures and (not item.Cmd or item.Cmd == ""))

            if isMaintenance then
                activeBadgeText = "MAINTENANCE!"
                activeBadgeColorName = "red"
            end

            if item.SubFeatures and #item.SubFeatures > 0 then
                for _, sub in ipairs(item.SubFeatures) do
                    local subRaw = (sub.RawUrl and sub.RawUrl ~= "") and sub.RawUrl or item.RawUrl
                    local subKey = tostring(subRaw) .. "_" .. tostring(sub.Cmd)
                    if sub.UpdateTimestamp and isFeatureNew(subKey, sub.UpdateTimestamp) then
                        timestamp = sub.UpdateTimestamp
                        if sub.BadgeText then activeBadgeText = sub.BadgeText end
                        if sub.BadgeColor then activeBadgeColorName = sub.BadgeColor end
                        break
                    end
                end
            end

            if isFeatureNew(uniqueKey, timestamp) or isMaintenance then
                local badgeText = "[" .. activeBadgeText .. "]"
                local badgeColor = getColorFromName(activeBadgeColorName)
                local textWidth = TextService:GetTextSize(badgeText, 9, Enum.Font.GothamBold, Vector2.new(200, 20)).X

                local NewBadge = Instance.new("TextLabel")
                NewBadge.Size = UDim2.new(0, textWidth + 5, 0, 14)
                NewBadge.Position = UDim2.new(0, TextService:GetTextSize(item.Name, 11, Enum.Font.GothamBold, Vector2.new(150, 20)).X + 12, 0, 2)
                NewBadge.BackgroundTransparency = 1
                NewBadge.Text = badgeText
                NewBadge.TextColor3 = badgeColor
                NewBadge.Font = Enum.Font.GothamBold
                NewBadge.TextSize = 9
                NewBadge.Parent = ItemFrame
                applyBlinkAnimation(NewBadge)

                if tabName then
                    local badgeShortText
                    local lowerBadgeText = string.lower(tostring(activeBadgeText))
                    if isMaintenance or string.find(lowerBadgeText, "maintenance", 1, true) then
                        badgeShortText = "MAINT"
                    elseif string.find(lowerBadgeText, "update", 1, true) then
                        badgeShortText = "UP"
                    else
                        badgeShortText = "NEW"
                    end
                    setTabBadge(tabName, badgeShortText, badgeColor, 2)
                end
            end

            local DescLabel = Instance.new("TextLabel")
            DescLabel.Position = UDim2.new(0, 8, 0, 22)
            DescLabel.BackgroundTransparency = 1
            DescLabel.Text = item.Desc
            DescLabel.TextColor3 = Color3.fromRGB(160, 170, 185)
            DescLabel.Font = Enum.Font.Gotham
            DescLabel.TextSize = 10
            DescLabel.TextXAlignment = Enum.TextXAlignment.Left
            DescLabel.TextYAlignment = Enum.TextYAlignment.Top
            DescLabel.TextWrapped = true
            DescLabel.Parent = ItemFrame

            local textBounds = TextService:GetTextSize(item.Desc, 10, Enum.Font.Gotham, Vector2.new(174, 10000))
            local descHeight = math.max(14, textBounds.Y + 5)
            DescLabel.Size = UDim2.new(1, -90, 0, descHeight)
            ItemFrame.Size = UDim2.new(1, 0, 0, descHeight + 28)

            if item.SubFeatures and #item.SubFeatures > 0 then
                local OpenBtn = Instance.new("TextButton")
                OpenBtn.Size = UDim2.new(0, 75, 0, 24)
                OpenBtn.AnchorPoint = Vector2.new(0, 0.5)
                OpenBtn.Position = UDim2.new(1, -80, 0.5, 0)
                OpenBtn.BackgroundColor3 = Color3.fromRGB(50, 120, 220)
                OpenBtn.BackgroundTransparency = 0.2
                OpenBtn.BorderSizePixel = 0
                OpenBtn.Text = "OPEN"
                OpenBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                OpenBtn.Font = Enum.Font.GothamBold
                OpenBtn.TextSize = 10
                OpenBtn.Parent = ItemFrame
                Instance.new("UICorner", OpenBtn).CornerRadius = UDim.new(0, 4)

                OpenBtn.MouseButton1Click:Connect(function()
                    showSubMenu(item.Name, item.RawUrl, item.SubFeatures)
                end)
            else
                if featureStates[uniqueKey] == nil then featureStates[uniqueKey] = false end

                local ExecBtn = Instance.new("TextButton")
                ExecBtn.Size = UDim2.new(0, 75, 0, 24)
                ExecBtn.AnchorPoint = Vector2.new(0, 0.5)
                ExecBtn.Position = UDim2.new(1, -80, 0.5, 0)
                ExecBtn.BorderSizePixel = 0
                ExecBtn.BackgroundTransparency = 0.2
                ExecBtn.Font = Enum.Font.GothamBold
                ExecBtn.TextSize = 10
                ExecBtn.Parent = ItemFrame
                Instance.new("UICorner", ExecBtn).CornerRadius = UDim.new(0, 4)

                if isMaintenance then
                    ExecBtn.Text = "MAINT"
                    ExecBtn.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
                    ExecBtn.Active = false
                else
                    ExecBtn.BackgroundColor3 = featureStates[uniqueKey] and Color3.fromRGB(200, 50, 50) or Color3.fromRGB(0, 150, 90)
                    ExecBtn.Text = featureStates[uniqueKey] and "UNEXECUTE" or "EXECUTE"

                    if not activeButtons[uniqueKey] then activeButtons[uniqueKey] = {} end
                    table.insert(activeButtons[uniqueKey], ExecBtn)

                    ExecBtn.MouseButton1Click:Connect(function()
                        local function runDirectCommand(customArgs, isUnexec)
                            pcall(function()
                                if not loadedModules[item.RawUrl] then
                                    loadedModules[item.RawUrl] = loadstring(game:HttpGet(item.RawUrl))()
                                end
                                local pluginMod = loadedModules[item.RawUrl]
                                if pluginMod and pluginMod.Commands then
                                    local targetCmd = isUnexec and item.UnCmd or item.Cmd
                                    local foundFunc = nil
                                    for cmdName, cmdData in pairs(pluginMod.Commands) do
                                        if string.lower(cmdName) == string.lower(tostring(targetCmd)) then
                                            if type(cmdData.Function) == "function" then
                                                foundFunc = cmdData.Function
                                                break
                                            end
                                        end
                                    end
                                    if foundFunc then task.spawn(function() foundFunc(customArgs or {}, speaker) end) end
                                end
                            end)

                            local hasUnCmd = item.UnCmd and item.UnCmd ~= ""
                            if hasUnCmd then
                                featureStates[uniqueKey] = not featureStates[uniqueKey]
                                updateAllButtonStates(uniqueKey, featureStates[uniqueKey])
                            else
                                featureStates[uniqueKey] = false
                                updateAllButtonStates(uniqueKey, false)
                            end
                        end

                        if featureStates[uniqueKey] then
                            runDirectCommand({}, true)
                        else
                            if item.NeedInput then
                                showInputDialog(item.Name, function(typedText)
                                    local argsTable = {}
                                    for word in string.gmatch(typedText, "%S+") do table.insert(argsTable, word) end
                                    runDirectCommand(argsTable, false)
                                end)
                            else
                                runDirectCommand({}, false)
                            end
                        end
                    end)
                end
            end
        end
        
        task.defer(function()
            valTotalHeight = 0
            for _, child in ipairs(targetParentScroll:GetChildren()) do
                if child:IsA("Frame") then valTotalHeight = valTotalHeight + child.AbsoluteSize.Y + 5 end
            end
            targetParentScroll.CanvasSize = UDim2.new(0, 0, 0, valTotalHeight)
        end)
    end

    local configOk, configErr = xpcall(function()
        local configUrl = "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/main/Loader.lua"
        local source = game:HttpGet(configUrl)
        local chunk = loadstring(source)
        local data = chunk()

        globalLoaderData = data

        local detectedTabs = data.Tabs or {
            { Name = "Main", DataKey = "Main" },
            { Name = "Tools", DataKey = "Tools" },
            { Name = "Horor", DataKey = "Horor" },
            { Name = "Gunung", DataKey = "Gunung" }
        }

        TabBar.CanvasSize = UDim2.new(0, 0, 0, 0)
        TabBarLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            TabBar.CanvasSize = UDim2.new(0, TabBarLayout.AbsoluteContentSize.X, 0, 0)
        end)

        for i, tabInfo in ipairs(detectedTabs) do
            local tabName = tabInfo.Name
            local dataKey = tabInfo.DataKey

            local Btn = Instance.new("TextButton")
            Btn.Size = UDim2.new(0, 85, 1, 0) 
            Btn.BackgroundColor3 = (i == 1) and Color3.fromRGB(0, 150, 90) or Color3.fromRGB(35, 45, 60)
            Btn.BackgroundTransparency = 0.3
            Btn.BorderSizePixel = 0
            Btn.Font = Enum.Font.GothamBold
            Btn.Text = tabName
            Btn.TextColor3 = (i == 1) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 190, 205)
            Btn.TextSize = 10
            Btn.Parent = TabBar
            Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 4)
            tabButtons[tabName] = Btn

            local tabUniqueKey = "TabAutoBadge_" .. tabName
            if isFeatureNew(tabUniqueKey, "071120260000, 86400") then
                setTabBadge(tabName, "BARU!", Color3.fromRGB(255, 215, 0), 1)
            end

            local Scroll = Instance.new("ScrollingFrame")
            Scroll.Size = UDim2.new(1, 0, 1, 0)
            Scroll.BackgroundTransparency = 1
            Scroll.BorderSizePixel = 0
            Scroll.ScrollBarThickness = 4
            Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
            Scroll.Visible = (i == 1)
            Scroll.Parent = ContentArea
            tabScrolls[tabName] = Scroll

            local Layout = Instance.new("UIListLayout")
            Layout.SortOrder = Enum.SortOrder.LayoutOrder
            Layout.Padding = UDim.new(0, 5)
            Layout.Parent = Scroll

            if i == 1 then currentActiveScroll = Scroll end

            Btn.MouseButton1Click:Connect(function()
                for _, otherBtn in pairs(tabButtons) do
                    otherBtn.BackgroundColor3 = Color3.fromRGB(35, 45, 60)
                    otherBtn.TextColor3 = Color3.fromRGB(180, 190, 205)
                end
                for _, otherScroll in pairs(tabScrolls) do otherScroll.Visible = false end

                Btn.BackgroundColor3 = Color3.fromRGB(0, 150, 90)
                Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
                SubMenuContainer.Visible = false
                Scroll.Visible = true
                currentActiveScroll = Scroll
                isCurrentlyInSubMenu = false
            end)

            renderMenuCategory(data[dataKey], Scroll, tabName)
        end
    end, function(e)
        return tostring(e)
    end)

    if not configOk then
        warn("[MasterWindow] GAGAL memuat Loader.lua: " .. tostring(configErr))
    end
end
