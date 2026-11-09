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

    -- Metadata harus selesai dimuat sebelum badge boleh ditampilkan.
    -- Ini mencegah timestamp lokal Loader.lua menampilkan badge lama sesaat
    -- sebelum status penghapusan dari Google Sheets diterima.
    local remoteMetadata = {}
    local metadataReady = false
    local metadataRefreshPending = false
    local lastMetadataSnapshot = nil
    local playerBadgeCache = {}
    local globalLoaderData = nil
    local refreshBadgeUI = nil

    local function fetchRemoteMetadata()
        local cacheBuster = tostring(DateTime.now().UnixTimestampMillis)
        local requestUrl = SHEETS_WEB_APP_URL .. "?_=" .. cacheBuster

        local requestOk, response = pcall(function()
            return game:HttpGet(requestUrl)
        end)
        if not requestOk or type(response) ~= "string" or response == "" then
            return false, nil, false
        end

        local decodeOk, decoded = pcall(function()
            return HttpService:JSONDecode(response)
        end)
        if not decodeOk or type(decoded) ~= "table" then
            return false, nil, false
        end

        local snapshotOk, snapshot = pcall(function()
            return HttpService:JSONEncode(decoded)
        end)
        local changed = snapshotOk and snapshot ~= lastMetadataSnapshot
        if snapshotOk then lastMetadataSnapshot = snapshot end

        remoteMetadata = decoded
        metadataReady = true
        return true, decoded, changed
    end

    task.spawn(function()
        local ok = fetchRemoteMetadata()
        if ok then
            metadataRefreshPending = true
            if refreshBadgeUI and globalLoaderData then
                metadataRefreshPending = false
                task.defer(refreshBadgeUI)
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

    local function isFeatureNew(uniqueKey, configValue)
        if not uniqueKey or uniqueKey == "" then return false end
        -- Jangan tampilkan badge dari Loader lokal sebelum metadata online siap.
        if not metadataReady then return false end

        -- Per-feature clear selalu menang, sampai workflow mengaktifkannya lagi.
        local featureStatus = tostring(remoteMetadata[uniqueKey] or "")
        -- Kompatibilitas dengan metadata versi lama: key yang ada tetapi Value kosong = pernah dihapus.
        if remoteMetadata[uniqueKey] ~= nil and (featureStatus == "" or featureStatus == "CLEARED") then
            return false
        end

        local startTime, durationSec = parseCustomConfig(configValue)
        if startTime == 0 then return false end

        -- Loader timestamp dibuat dalam WIB; konversi ke epoch UTC.
        local utcStartTime = startTime - 25200
        local currentTime = os.time()
        local globalClearBefore = tonumber(remoteMetadata["BadgeClearBefore"]) or 0
        local activeAt = tonumber(featureStatus:match("^ACTIVE:(%d+)$")) or 0

        -- Override ACTIVE hanya berlaku jika file diubah setelah reset global terakhir.
        if activeAt > 0 then
            if activeAt <= globalClearBefore then return false end
        elseif (utcStartTime * 1000) <= globalClearBefore then
            return false
        end

        return (currentTime - utcStartTime) >= 0 and (currentTime - utcStartTime) <= durationSec
    end


    -- Badge identity is permanent and independent from RawUrl / filename.
    -- Legacy fallback keeps older Loader entries working during migration.
    local function getFeatureBadgeKey(feature, legacyKey)
        local featureId = feature and tostring(feature.FeatureId or "") or ""
        if featureId ~= "" then
            local stableKey = "FeatureBadge_" .. featureId
            -- One-time client-side compatibility: honor an old per-feature clear
            -- immediately, even before the server registry migration finishes.
            if remoteMetadata[stableKey] == nil and legacyKey and remoteMetadata[legacyKey] ~= nil then
                remoteMetadata[stableKey] = remoteMetadata[legacyKey]
            end
            return stableKey
        end
        return legacyKey
    end

    -- Remote maintenance status is independent from New/Update badge metadata.
    local function isFeatureInMaintenance(feature)
        local featureId = feature and tostring(feature.FeatureId or "") or ""
        if featureId == "" then return false end
        return tostring(remoteMetadata["FeatureMaintenance_" .. featureId] or "") == "ACTIVE"
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
            local decoded = HttpService:JSONDecode(response or "{}")
            local raw = tostring((type(decoded) == "table" and decoded.LastUpdate) or "")
            local dd, mm, yyyy, hour, min = raw:match("^(%d%d?)[/%-](%d%d?)[/%-](%d%d%d%d)[ T](%d%d?):(%d%d?)")
            if not (dd and mm and yyyy and hour and min) then
                local digits = raw:gsub("%D", "")
                if #digits >= 12 then
                    dd, mm, yyyy = digits:sub(1, 2), digits:sub(3, 4), digits:sub(5, 8)
                    hour, min = digits:sub(9, 10), digits:sub(11, 12)
                end
            end
            if dd and mm and yyyy and hour and min then
                LastUpdateLabel.Text = string.format("Last Update: %02d/%02d/%s %02d:%02d",
                    tonumber(dd) or 0, tonumber(mm) or 0, yyyy, tonumber(hour) or 0, tonumber(min) or 0)
            elseif raw ~= "" then
                LastUpdateLabel.Text = "Last Update: " .. raw
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

    local MaintenanceListView = Instance.new("Frame")
    MaintenanceListView.Size = UDim2.new(1, -16, 1, -45)
    MaintenanceListView.Position = UDim2.new(0, 8, 0, 40)
    MaintenanceListView.BackgroundTransparency = 1
    MaintenanceListView.Visible = false
    MaintenanceListView.ZIndex = 31
    MaintenanceListView.Parent = DevPanelContainer

    local VersionHistoryView = Instance.new("Frame")
    VersionHistoryView.Size = UDim2.new(1, -16, 1, -45)
    VersionHistoryView.Position = UDim2.new(0, 8, 0, 40)
    VersionHistoryView.BackgroundTransparency = 1
    VersionHistoryView.Visible = false
    VersionHistoryView.ZIndex = 31
    VersionHistoryView.Parent = DevPanelContainer

    local VersionHistoryBackBtn = Instance.new("TextButton")
    VersionHistoryBackBtn.Size = UDim2.new(1, 0, 0, 28)
    VersionHistoryBackBtn.BackgroundColor3 = Color3.fromRGB(35, 45, 60)
    VersionHistoryBackBtn.BorderSizePixel = 0
    VersionHistoryBackBtn.Font = Enum.Font.GothamBold
    VersionHistoryBackBtn.Text = "< KEMBALI KE MENU DEV"
    VersionHistoryBackBtn.TextColor3 = Color3.fromRGB(0, 200, 255)
    VersionHistoryBackBtn.TextSize = 10
    VersionHistoryBackBtn.ZIndex = 32
    VersionHistoryBackBtn.Parent = VersionHistoryView
    Instance.new("UICorner", VersionHistoryBackBtn).CornerRadius = UDim.new(0, 4)

    local VersionHistoryInfo = Instance.new("TextLabel")
    VersionHistoryInfo.Size = UDim2.new(1, 0, 0, 30)
    VersionHistoryInfo.Position = UDim2.new(0, 0, 0, 32)
    VersionHistoryInfo.BackgroundTransparency = 1
    VersionHistoryInfo.Font = Enum.Font.Gotham
    VersionHistoryInfo.Text = "Pilih file untuk melihat riwayat commit GitHub."
    VersionHistoryInfo.TextColor3 = Color3.fromRGB(160, 175, 195)
    VersionHistoryInfo.TextSize = 8
    VersionHistoryInfo.TextWrapped = true
    VersionHistoryInfo.TextXAlignment = Enum.TextXAlignment.Left
    VersionHistoryInfo.ZIndex = 32
    VersionHistoryInfo.Parent = VersionHistoryView

    local VersionHistoryScroll = Instance.new("ScrollingFrame")
    VersionHistoryScroll.Size = UDim2.new(1, 0, 1, -66)
    VersionHistoryScroll.Position = UDim2.new(0, 0, 0, 64)
    VersionHistoryScroll.BackgroundTransparency = 1
    VersionHistoryScroll.BorderSizePixel = 0
    VersionHistoryScroll.ScrollBarThickness = 4
    VersionHistoryScroll.ZIndex = 32
    VersionHistoryScroll.Parent = VersionHistoryView

    local VersionHistoryLayout = Instance.new("UIListLayout")
    VersionHistoryLayout.SortOrder = Enum.SortOrder.LayoutOrder
    VersionHistoryLayout.Padding = UDim.new(0, 6)
    VersionHistoryLayout.Parent = VersionHistoryScroll

    local MaintenanceBackBtn = Instance.new("TextButton")
    MaintenanceBackBtn.Size = UDim2.new(1, 0, 0, 28)
    MaintenanceBackBtn.BackgroundColor3 = Color3.fromRGB(35, 45, 60)
    MaintenanceBackBtn.BorderSizePixel = 0
    MaintenanceBackBtn.Font = Enum.Font.GothamBold
    MaintenanceBackBtn.Text = "< KEMBALI KE MENU DEV"
    MaintenanceBackBtn.TextColor3 = Color3.fromRGB(0, 200, 255)
    MaintenanceBackBtn.TextSize = 10
    MaintenanceBackBtn.ZIndex = 32
    MaintenanceBackBtn.Parent = MaintenanceListView
    Instance.new("UICorner", MaintenanceBackBtn).CornerRadius = UDim.new(0, 4)

    MaintenanceBackBtn.MouseButton1Click:Connect(function()
        MaintenanceListView.Visible = false
        DevMainMenu.Visible = true
    end)

    VersionHistoryBackBtn.MouseButton1Click:Connect(function()
        VersionHistoryView.Visible = false
        DevMainMenu.Visible = true
    end)

    local MaintenanceAdminKeyBox = Instance.new("TextBox")
    MaintenanceAdminKeyBox.Size = UDim2.new(1, 0, 0, 26)
    MaintenanceAdminKeyBox.Position = UDim2.new(0, 0, 0, 33)
    MaintenanceAdminKeyBox.BackgroundColor3 = Color3.fromRGB(28, 36, 48)
    MaintenanceAdminKeyBox.BorderSizePixel = 0
    MaintenanceAdminKeyBox.Font = Enum.Font.Gotham
    MaintenanceAdminKeyBox.PlaceholderText = "Masukkan kunci Dev Panel"
    MaintenanceAdminKeyBox.Text = ""
    MaintenanceAdminKeyBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    MaintenanceAdminKeyBox.PlaceholderColor3 = Color3.fromRGB(145, 160, 180)
    MaintenanceAdminKeyBox.TextSize = 9
    MaintenanceAdminKeyBox.ClearTextOnFocus = false
    MaintenanceAdminKeyBox.ZIndex = 32
    MaintenanceAdminKeyBox.Parent = MaintenanceListView
    Instance.new("UICorner", MaintenanceAdminKeyBox).CornerRadius = UDim.new(0, 4)

    local MaintenanceScroll = Instance.new("ScrollingFrame")
    MaintenanceScroll.Size = UDim2.new(1, 0, 1, -64)
    MaintenanceScroll.Position = UDim2.new(0, 0, 0, 64)
    MaintenanceScroll.BackgroundTransparency = 1
    MaintenanceScroll.BorderSizePixel = 0
    MaintenanceScroll.ScrollBarThickness = 4
    MaintenanceScroll.ZIndex = 32
    MaintenanceScroll.Parent = MaintenanceListView

    local MaintenanceScrollLayout = Instance.new("UIListLayout")
    MaintenanceScrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
    MaintenanceScrollLayout.Padding = UDim.new(0, 6)
    MaintenanceScrollLayout.Parent = MaintenanceScroll

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

                        remoteMetadata[targetKey] = "CLEARED"
                        playerBadgeCache[targetKey] = false
                        if refreshBadgeUI then refreshBadgeUI() end
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
                            Body = HttpService:JSONEncode({ Type = "ClearAllBadges" })
                        })
                        remoteMetadata["BadgeClearBefore"] = tostring(DateTime.now().UnixTimestampMillis)
                        playerBadgeCache = {}
                        if refreshBadgeUI then refreshBadgeUI() end
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
                local legacyKey = tostring(item.RawUrl or "") .. "_" .. tostring(item.Cmd or item.Name)
                local uniqueKey = getFeatureBadgeKey(item, legacyKey)
                local timestamp = item.UpdateTimestamp or ""
                local isMaintenance = (not item.SubFeatures and (not item.Cmd or item.Cmd == ""))
                local hasBadge = isFeatureNew(uniqueKey, timestamp) or isMaintenance

                local activeSubFeatures = {}
                if item.SubFeatures and #item.SubFeatures > 0 then
                    for _, sub in ipairs(item.SubFeatures) do
                        local subRaw = (sub.RawUrl and sub.RawUrl ~= "") and sub.RawUrl or item.RawUrl
                        local legacySubKey = tostring(subRaw) .. "_" .. tostring(sub.Cmd)
                        local subKey = getFeatureBadgeKey(sub, legacySubKey)
                        local subTimestamp = sub.UpdateTimestamp or ""
                        local isSubMaint = (not sub.Cmd or sub.Cmd == "")
                        if isFeatureNew(subKey, subTimestamp) or isSubMaint then
                            table.insert(activeSubFeatures, {sub = sub, key = subKey})
                        end
                    end
                end

                if (not item.SubFeatures or #item.SubFeatures == 0) and (hasBadge or isMaintenance) then
                    table.insert(activeItemsInTab, {item = item, key = uniqueKey, subFeatures = {}})
                elseif #activeSubFeatures > 0 then
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
                    if #entry.subFeatures == 0 then
                        createBadgeRow(entry.key, entry.item.Name, BadgeScroll, SHEETS_WEB_APP_URL, loadBadgeListForDev)
                    end

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

    local function loadMaintenanceListForDev()
        for _, child in ipairs(MaintenanceScroll:GetChildren()) do
            if child:IsA("Frame") or child:IsA("TextLabel") then child:Destroy() end
        end

        if not globalLoaderData then
            local loading = Instance.new("TextLabel")
            loading.Size = UDim2.new(1, 0, 0, 30)
            loading.BackgroundTransparency = 1
            loading.Font = Enum.Font.GothamBold
            loading.Text = "Memuat daftar fitur dari Loader..."
            loading.TextColor3 = Color3.fromRGB(160, 175, 195)
            loading.TextSize = 9
            loading.Parent = MaintenanceScroll
            return
        end

        local features, seen = {}, {}
        for _, tabInfo in ipairs(globalLoaderData.Tabs or {}) do
            for _, item in ipairs(globalLoaderData[tabInfo.DataKey] or {}) do
                if item.SubFeatures and #item.SubFeatures > 0 then
                    for _, sub in ipairs(item.SubFeatures) do
                        local id = tostring(sub.FeatureId or "")
                        if id ~= "" and not seen[id] then
                            seen[id] = true
                            table.insert(features, { id = id, name = sub.Name or sub.Cmd or id, tab = tabInfo.Name })
                        end
                    end
                else
                    local id = tostring(item.FeatureId or "")
                    if id ~= "" and not seen[id] then
                        seen[id] = true
                        table.insert(features, { id = id, name = item.Name or item.Cmd or id, tab = tabInfo.Name })
                    end
                end
            end
        end

        table.sort(features, function(a, b) return string.lower(a.name) < string.lower(b.name) end)
        if #features == 0 then
            local empty = Instance.new("TextLabel")
            empty.Size = UDim2.new(1, 0, 0, 36)
            empty.BackgroundTransparency = 1
            empty.Font = Enum.Font.GothamBold
            empty.Text = "Tidak ada fitur ber-FeatureID di Loader."
            empty.TextColor3 = Color3.fromRGB(160, 175, 195)
            empty.TextSize = 9
            empty.Parent = MaintenanceScroll
            return
        end

        for _, feature in ipairs(features) do
            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, 0, 0, 40)
            row.BackgroundColor3 = Color3.fromRGB(25, 32, 42)
            row.BorderSizePixel = 0
            row.ZIndex = 33
            row.Parent = MaintenanceScroll
            Instance.new("UICorner", row).CornerRadius = UDim.new(0, 4)

            local name = Instance.new("TextLabel")
            name.Size = UDim2.new(1, -105, 0, 18)
            name.Position = UDim2.new(0, 8, 0, 3)
            name.BackgroundTransparency = 1
            name.Font = Enum.Font.GothamBold
            name.Text = feature.name
            name.TextColor3 = Color3.fromRGB(255, 255, 255)
            name.TextSize = 9
            name.TextXAlignment = Enum.TextXAlignment.Left
            name.ZIndex = 34
            name.Parent = row

            local status = Instance.new("TextLabel")
            status.Size = UDim2.new(1, -105, 0, 13)
            status.Position = UDim2.new(0, 8, 0, 21)
            status.BackgroundTransparency = 1
            status.Font = Enum.Font.Gotham
            status.Text = feature.id .. "  •  " .. feature.tab
            status.TextColor3 = Color3.fromRGB(145, 160, 180)
            status.TextSize = 7
            status.TextXAlignment = Enum.TextXAlignment.Left
            status.ZIndex = 34
            status.Parent = row

            local enabled = tostring(remoteMetadata["FeatureMaintenance_" .. feature.id] or "") == "ACTIVE"
            local toggle = Instance.new("TextButton")
            toggle.Size = UDim2.new(0, 82, 0, 24)
            toggle.AnchorPoint = Vector2.new(1, 0.5)
            toggle.Position = UDim2.new(1, -7, 0.5, 0)
            toggle.BackgroundColor3 = enabled and Color3.fromRGB(0, 130, 85) or Color3.fromRGB(150, 45, 45)
            toggle.BorderSizePixel = 0
            toggle.Font = Enum.Font.GothamBold
            toggle.Text = enabled and "DISABLE MT" or "MAINTENANCE"
            toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
            toggle.TextSize = 8
            toggle.ZIndex = 34
            toggle.Parent = row
            Instance.new("UICorner", toggle).CornerRadius = UDim.new(0, 4)

            toggle.MouseButton1Click:Connect(function()
                toggle.Active = false
                toggle.Text = "..."
                task.spawn(function()
                    local req = request or http_request or (syn and syn.request)
                    local requestSent = false
                    local expectedValue = (not enabled) and "ACTIVE" or ""
                    local maintenanceKey = "FeatureMaintenance_" .. feature.id

                    if req then
                        local ok, response = pcall(function()
                            return req({
                                Url = SHEETS_WEB_APP_URL,
                                Method = "POST",
                                Headers = { ["Content-Type"] = "application/json" },
                                Body = HttpService:JSONEncode({
                                    Type = "FeatureMaintenance",
                                    FeatureId = feature.id,
                                    Enabled = not enabled,
                                    AdminKey = MaintenanceAdminKeyBox.Text
                                })
                            })
                        end)
                        requestSent = ok and response ~= nil
                    end

                    -- Jangan menilai hasil dari JSON body POST saja.
                    -- Beberapa executor mengembalikan respons redirect/format berbeda
                    -- walaupun Apps Script sudah menjalankan perintahnya.
                    -- Verifikasi status final langsung dari metadata server.
                    local success = false
                    if requestSent then
                        for attempt = 1, 2 do
                            local fetchOk = fetchRemoteMetadata()
                            if fetchOk and tostring(remoteMetadata[maintenanceKey] or "") == expectedValue then
                                success = true
                                break
                            end
                            if attempt == 1 then task.wait(0.35) end
                        end
                    end

                    if success then
                        if refreshBadgeUI then task.defer(refreshBadgeUI) end
                        loadMaintenanceListForDev()
                    else
                        toggle.Text = "ERROR"
                        toggle.Active = true
                        task.wait(1.2)
                        if toggle and toggle.Parent then
                            toggle.Text = enabled and "DISABLE MT" or "MAINTENANCE"
                        end
                    end
                end)
            end)
        end

        task.defer(function()
            local total = 0
            for _, child in ipairs(MaintenanceScroll:GetChildren()) do
                if child:IsA("Frame") or child:IsA("TextLabel") or child:IsA("TextButton") then total = total + child.AbsoluteSize.Y + 6 end
            end
            MaintenanceScroll.CanvasSize = UDim2.new(0, 0, 0, total)
        end)
    end


    local function clearVersionHistoryRows()
        for _, child in ipairs(VersionHistoryScroll:GetChildren()) do
            if child:IsA("Frame") or child:IsA("TextLabel") or child:IsA("TextButton") then child:Destroy() end
        end
        VersionHistoryScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    end

    local function addVersionHistoryMessage(message)
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -4, 0, 34)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.Gotham
        label.Text = message
        label.TextColor3 = Color3.fromRGB(160, 175, 195)
        label.TextSize = 9
        label.TextWrapped = true
        label.ZIndex = 33
        label.Parent = VersionHistoryScroll
    end

    local function loadVersionHistoryForFile(fileInfo)
        clearVersionHistoryRows()
        VersionHistoryInfo.Text = "Memuat " .. fileInfo.name .. "..."
        task.spawn(function()
            local encodedPath = tostring(fileInfo.path):gsub(" ", "%%20")
            local url = "https://api.github.com/repos/Tryofp/Plugin-Manager/commits?path=" .. encodedPath .. "&per_page=12"
            local ok, response = pcall(function() return game:HttpGet(url) end)
            if not ok or type(response) ~= "string" or response == "" then
                VersionHistoryInfo.Text = fileInfo.name .. " • Gagal menghubungi GitHub"
                addVersionHistoryMessage("Periksa koneksi lalu coba pilih file lagi.")
                return
            end

            local decodeOk, decoded = pcall(function() return HttpService:JSONDecode(response) end)
            if not decodeOk or type(decoded) ~= "table" or decoded.message then
                VersionHistoryInfo.Text = fileInfo.name .. " • GitHub API tidak tersedia"
                addVersionHistoryMessage(type(decoded) == "table" and tostring(decoded.message or "Respons tidak valid") or "Respons GitHub tidak valid.")
                return
            end

            VersionHistoryInfo.Text = fileInfo.name .. " • " .. fileInfo.path

            local fileBack = Instance.new("TextButton")
            fileBack.Size = UDim2.new(1, -4, 0, 26)
            fileBack.BackgroundColor3 = Color3.fromRGB(35, 45, 60)
            fileBack.BorderSizePixel = 0
            fileBack.Font = Enum.Font.GothamBold
            fileBack.Text = "< KEMBALI KE DAFTAR FILE"
            fileBack.TextColor3 = Color3.fromRGB(0, 200, 255)
            fileBack.TextSize = 8
            fileBack.ZIndex = 33
            fileBack.Parent = VersionHistoryScroll
            Instance.new("UICorner", fileBack).CornerRadius = UDim.new(0, 4)
            fileBack.MouseButton1Click:Connect(function()
                loadVersionHistoryFiles()
            end)

            if #decoded == 0 then
                addVersionHistoryMessage("Belum ada riwayat commit untuk file ini.")
                return
            end

            for index, entry in ipairs(decoded) do
                local commitData = entry.commit or {}
                local authorData = commitData.author or {}
                local sha = tostring(entry.sha or "")
                local message = tostring(commitData.message or "Tanpa pesan"):gsub("[\r\n]+", " ")
                if #message > 90 then message = message:sub(1, 87) .. "..." end

                local row = Instance.new("Frame")
                row.Size = UDim2.new(1, -4, 0, 48)
                row.BackgroundColor3 = Color3.fromRGB(28, 36, 48)
                row.BackgroundTransparency = 0.15
                row.BorderSizePixel = 0
                row.ZIndex = 33
                row.Parent = VersionHistoryScroll
                Instance.new("UICorner", row).CornerRadius = UDim.new(0, 4)

                local title = Instance.new("TextLabel")
                title.Size = UDim2.new(1, -12, 0, 18)
                title.Position = UDim2.new(0, 6, 0, 3)
                title.BackgroundTransparency = 1
                title.Font = Enum.Font.GothamBold
                title.Text = tostring(index) .. ". " .. message
                title.TextColor3 = Color3.fromRGB(235, 240, 248)
                title.TextSize = 8
                title.TextXAlignment = Enum.TextXAlignment.Left
                title.TextTruncate = Enum.TextTruncate.AtEnd
                title.ZIndex = 34
                title.Parent = row

                local details = Instance.new("TextLabel")
                details.Size = UDim2.new(1, -12, 0, 14)
                details.Position = UDim2.new(0, 6, 0, 24)
                details.BackgroundTransparency = 1
                details.Font = Enum.Font.Gotham
                details.Text = tostring(authorData.date or "Tanggal tidak tersedia") .. " • " .. sha:sub(1, 7)
                details.TextColor3 = Color3.fromRGB(145, 165, 190)
                details.TextSize = 8
                details.TextXAlignment = Enum.TextXAlignment.Left
                details.ZIndex = 34
                details.Parent = row
            end

            task.defer(function()
                local total = 0
                for _, child in ipairs(VersionHistoryScroll:GetChildren()) do
                    if child:IsA("Frame") or child:IsA("TextLabel") then total = total + child.AbsoluteSize.Y + 6 end
                end
                VersionHistoryScroll.CanvasSize = UDim2.new(0, 0, 0, total)
            end)
        end)
    end

    local function loadVersionHistoryFiles()
        clearVersionHistoryRows()
        if not globalLoaderData then
            VersionHistoryInfo.Text = "Loader belum siap."
            addVersionHistoryMessage("Buka kembali Dev Panel setelah Loader selesai dimuat.")
            return
        end

        local files, seen = {}, {}
        for _, tabInfo in ipairs(globalLoaderData.Tabs or {}) do
            for _, item in ipairs(globalLoaderData[tabInfo.DataKey] or {}) do
                local candidates = item.SubFeatures and #item.SubFeatures > 0 and item.SubFeatures or {item}
                for _, feature in ipairs(candidates) do
                    local rawUrl = tostring(feature.RawUrl or item.RawUrl or "")
                    local path = rawUrl:match("raw%.githubusercontent%.com/Tryofp/Plugin%-Manager/refs/heads/main/(.+)")
                        or rawUrl:match("raw%.githubusercontent%.com/Tryofp/Plugin%-Manager/main/(.+)")
                    if path and not seen[path] then
                        seen[path] = true
                        table.insert(files, {name = tostring(feature.Name or item.Name or path), path = path})
                    end
                end
            end
        end
        table.sort(files, function(a, b) return string.lower(a.name) < string.lower(b.name) end)
        VersionHistoryInfo.Text = "Pilih file • menampilkan 12 commit terakhir"
        if #files == 0 then
            addVersionHistoryMessage("Tidak ada RawUrl Plugin-Manager yang ditemukan di Loader.")
            return
        end

        for _, fileInfo in ipairs(files) do
            local row = Instance.new("TextButton")
            row.Size = UDim2.new(1, -4, 0, 34)
            row.BackgroundColor3 = Color3.fromRGB(28, 36, 48)
            row.BackgroundTransparency = 0.15
            row.BorderSizePixel = 0
            row.Font = Enum.Font.GothamBold
            row.Text = "  " .. fileInfo.name .. "   ›"
            row.TextColor3 = Color3.fromRGB(235, 240, 248)
            row.TextSize = 9
            row.TextXAlignment = Enum.TextXAlignment.Left
            row.ZIndex = 33
            row.Parent = VersionHistoryScroll
            Instance.new("UICorner", row).CornerRadius = UDim.new(0, 4)
            row.MouseButton1Click:Connect(function() loadVersionHistoryForFile(fileInfo) end)
        end

        task.defer(function()
            local total = 0
            for _, child in ipairs(VersionHistoryScroll:GetChildren()) do
                if child:IsA("TextButton") then total = total + child.AbsoluteSize.Y + 6 end
            end
            VersionHistoryScroll.CanvasSize = UDim2.new(0, 0, 0, total)
        end)
    end

    addDevMenuOption("🕘 Version History", "Lihat 12 commit terakhir setiap file plugin", function()
        DevMainMenu.Visible = false
        loadVersionHistoryFiles()
        VersionHistoryView.Visible = true
    end)

    addDevMenuOption("🛠️ Maintenance Fitur", "Aktifkan/nonaktifkan Maintenance realtime untuk fitur di Loader", function()
        DevMainMenu.Visible = false
        loadMaintenanceListForDev()
        MaintenanceListView.Visible = true
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
            MaintenanceListView.Visible = false
            VersionHistoryView.Visible = false
            DevPanelContainer.Visible = true
        end
    end)

    local function setTabBadge(tabName, badgeText, badgeColor, priority, featureKeys)
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
        if featureKeys then
            local merged, seen = {}, {}
            local oldJson = existing:GetAttribute("BadgeFeatureKeys")
            if oldJson then
                local ok, oldList = pcall(function() return HttpService:JSONDecode(oldJson) end)
                if ok and type(oldList) == "table" then
                    for _, entry in ipairs(oldList) do
                        if type(entry) == "table" and entry.key and not seen[entry.key] then
                            seen[entry.key] = true
                            table.insert(merged, entry)
                        end
                    end
                end
            end
            for _, entry in ipairs(featureKeys) do
                if type(entry) == "table" and entry.key and not seen[entry.key] then
                    seen[entry.key] = true
                    table.insert(merged, entry)
                end
            end
            existing:SetAttribute("BadgeFeatureKeys", HttpService:JSONEncode(merged))
        end
        existing.Text = tostring(badgeText or "NEW")
        existing.TextColor3 = badgeColor or Color3.fromRGB(255, 215, 0)
        local width = TextService:GetTextSize(existing.Text, 8, Enum.Font.GothamBold, Vector2.new(100, 20)).X
        existing.Size = UDim2.new(0, math.max(22, width + 6), 0, 12)
    end

    -- Sinkronisasi online. Fetch pertama berjalan saat startup; polling berikutnya
    -- hanya memperbarui UI jika metadata benar-benar berubah.
    task.spawn(function()
        while ScreenGui and ScreenGui.Parent do
            task.wait(15)

            local ok, decoded, metadataChanged = fetchRemoteMetadata()
            if ok and decoded then
                local lastRaw = tostring(decoded.LastUpdate or "")
                local dd, mm, yyyy, hh, mi = lastRaw:match("^(%d%d?)[/%-](%d%d?)[/%-](%d%d%d%d)[ T](%d%d?):(%d%d?)")
                if not (dd and mm and yyyy and hh and mi) then
                    local digits = lastRaw:gsub("%D", "")
                    if #digits >= 12 then
                        dd, mm, yyyy = digits:sub(1, 2), digits:sub(3, 4), digits:sub(5, 8)
                        hh, mi = digits:sub(9, 10), digits:sub(11, 12)
                    end
                end

                if dd and mm and yyyy and hh and mi then
                    LastUpdateLabel.Text = string.format("Last Update: %02d/%02d/%s %02d:%02d",
                        tonumber(dd) or 0, tonumber(mm) or 0, yyyy, tonumber(hh) or 0, tonumber(mi) or 0)
                elseif lastRaw == "" then
                    LastUpdateLabel.Text = "Last Update: -"
                else
                    LastUpdateLabel.Text = "Last Update: " .. lastRaw
                end

                if metadataChanged and refreshBadgeUI and globalLoaderData then
                    task.defer(refreshBadgeUI)
                end
            end
        end
    end)

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
            -- ⚡ TAMBAHAN: Sembunyikan juga Dev Panel saat di-minimize agar tidak nyembul keluar
            DevPanelContainer.Visible = false
        else
            Frame.Size = UDim2.new(0, 280, 0, 340)
            MinBtn.Text = "-"
            TabBar.Visible = true
            HeaderContainer.Visible = true
            ContentArea.Visible = true
        end
    end)

    local currentSubMenuTitle, currentSubMenuRawUrl, currentSubMenuFeatures
    local function showSubMenu(menuTitle, rawUrl, subFeatures)
        currentSubMenuTitle, currentSubMenuRawUrl, currentSubMenuFeatures = menuTitle, rawUrl, subFeatures
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
            local subRawUrl = (subFeat.RawUrl and subFeat.RawUrl ~= "") and subFeat.RawUrl or rawUrl
            local uniqueKey = tostring(subRawUrl) .. "_" .. tostring(subFeat.Cmd)
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

            local badgeKey = getFeatureBadgeKey(subFeat, uniqueKey)
            local timestamp = subFeat.UpdateTimestamp or ""
            local activeBadgeText = subFeat.BadgeText or "New!"
            local activeBadgeColor = getColorFromName(subFeat.BadgeColor)
            local isMaintenance = (not subFeat.Cmd or subFeat.Cmd == "") or isFeatureInMaintenance(subFeat)

            if isMaintenance then
                activeBadgeText = "MAINTENANCE!"
                activeBadgeColor = Color3.fromRGB(255, 60, 60)
            end

            if isFeatureNew(badgeKey, timestamp) or isMaintenance then
                local badgeText = "[" .. activeBadgeText .. "]"
                local textWidth = TextService:GetTextSize(badgeText, 9, Enum.Font.GothamBold, Vector2.new(200, 20)).X
                
                local NewBadge = Instance.new("TextLabel")
                NewBadge.Size = UDim2.new(0, textWidth + 5, 0, 14)
                NewBadge.Position = UDim2.new(0, TextService:GetTextSize(subFeat.Name, 11, Enum.Font.GothamBold, Vector2.new(150, 20)).X + 12, 0, 2)
                NewBadge.BackgroundTransparency = 1
                NewBadge.Text = badgeText
                NewBadge:SetAttribute("BadgeFeatureKey", badgeKey)
                NewBadge:SetAttribute("BadgeTimestamp", timestamp)
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
                            local targetRaw = subRawUrl
                            if not loadedModules[targetRaw] then
                                loadedModules[targetRaw] = loadstring(game:HttpGet(targetRaw))()
                            end
                            local pluginMod = loadedModules[targetRaw]
                            if pluginMod and pluginMod.Commands then
                                -- WalkSpeed menyediakan command unws di modulnya.
                                -- Fallback ini menjaga tombol tetap punya pasangan UNEXECUTE
                                -- meskipun metadata submenu belum mengisi UnCmd.
                                local unCommand = subFeat.UnCmd
                                if (not unCommand or unCommand == "") and string.lower(tostring(subFeat.Cmd or "")) == "ws" then
                                    unCommand = "unws"
                                end
                                local targetCmd = isUnexec and unCommand or subFeat.Cmd
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

                        local hasUnCmd = (subFeat.UnCmd and subFeat.UnCmd ~= "")
                            or string.lower(tostring(subFeat.Cmd or "")) == "ws"
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
                                for word in string.gmatch(typedText, "%S+") do table.init(argsTable, word) end
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

            local uniqueKey = tostring(item.RawUrl or "") .. "_" .. tostring(item.Cmd or item.Name)
            local badgeKey = getFeatureBadgeKey(item, uniqueKey)
            local timestamp = item.UpdateTimestamp or ""
            local activeBadgeText = item.BadgeText or "New!"
            local activeBadgeColorName = item.BadgeColor
            local isMaintenance = (not item.SubFeatures and (not item.Cmd or item.Cmd == "")) or isFeatureInMaintenance(item)
            local hasSubMaintenance = false
            local badgeFeatureKeys = {}

            if isMaintenance then
                activeBadgeText = "MAINTENANCE!"
                activeBadgeColorName = "red"
            end

            if item.SubFeatures and #item.SubFeatures > 0 then
                for _, sub in ipairs(item.SubFeatures) do
                    local subRaw = (sub.RawUrl and sub.RawUrl ~= "") and sub.RawUrl or item.RawUrl
                    local legacySubKey = tostring(subRaw) .. "_" .. tostring(sub.Cmd)
                    local subKey = getFeatureBadgeKey(sub, legacySubKey)
                    local subTimestamp = sub.UpdateTimestamp or ""
                    if isFeatureInMaintenance(sub) then
                        hasSubMaintenance = true
                    end
                    if isFeatureNew(subKey, subTimestamp) then
                        table.insert(badgeFeatureKeys, { key = subKey, timestamp = subTimestamp })
                        if #badgeFeatureKeys == 1 then
                            activeBadgeText = sub.BadgeText or activeBadgeText
                            activeBadgeColorName = sub.BadgeColor or activeBadgeColorName
                        end
                    end
                end
            elseif isFeatureNew(badgeKey, timestamp) then
                table.insert(badgeFeatureKeys, { key = badgeKey, timestamp = timestamp })
            end

            if isMaintenance or hasSubMaintenance then
                activeBadgeText = "MAINTENANCE!"
                activeBadgeColorName = "red"
            end

            if #badgeFeatureKeys > 0 or isMaintenance or hasSubMaintenance then
                local badgeText = "[" .. activeBadgeText .. "]"
                local badgeColor = getColorFromName(activeBadgeColorName)
                local textWidth = TextService:GetTextSize(badgeText, 9, Enum.Font.GothamBold, Vector2.new(200, 20)).X

                local NewBadge = Instance.new("TextLabel")
                NewBadge.Size = UDim2.new(0, textWidth + 5, 0, 14)
                NewBadge.Position = UDim2.new(0, TextService:GetTextSize(item.Name, 11, Enum.Font.GothamBold, Vector2.new(150, 20)).X + 12, 0, 2)
                NewBadge.BackgroundTransparency = 1
                NewBadge.Text = badgeText
                if #badgeFeatureKeys == 1 then
                    NewBadge:SetAttribute("BadgeFeatureKey", badgeFeatureKeys[1].key)
                    NewBadge:SetAttribute("BadgeTimestamp", badgeFeatureKeys[1].timestamp)
                elseif #badgeFeatureKeys > 1 then
                    NewBadge:SetAttribute("BadgeFeatureKeys", HttpService:JSONEncode(badgeFeatureKeys))
                end
                NewBadge.TextColor3 = badgeColor
                NewBadge.Font = Enum.Font.GothamBold
                NewBadge.TextSize = 9
                NewBadge.Parent = ItemFrame
                applyBlinkAnimation(NewBadge)

                if tabName then
                    local badgeShortText
                    local lowerBadgeText = string.lower(tostring(activeBadgeText))
                    if isMaintenance or hasSubMaintenance or string.find(lowerBadgeText, "maintenance", 1, true) then
                        badgeShortText = "MAINT"
                    elseif string.find(lowerBadgeText, "update", 1, true) then
                        badgeShortText = "UP"
                    else
                        badgeShortText = "NEW"
                    end
                    setTabBadge(tabName, badgeShortText, badgeColor, 2, badgeFeatureKeys)
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

    refreshBadgeUI = function()
        if not globalLoaderData then return end
        -- Ambil Loader terbaru agar timestamp fitur yang baru di-push langsung tersedia.
        local ok, newData = pcall(function()
            local loaderUrl = "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/main/Loader.lua"
            local source = game:HttpGet(loaderUrl .. "?_=" .. tostring(DateTime.now().UnixTimestampMillis))
            return loadstring(source)()
        end)
        if ok and type(newData) == "table" then globalLoaderData = newData end

        for key in pairs(activeButtons) do activeButtons[key] = nil end
        for tabName, tabBtn in pairs(tabButtons) do
            local oldBadge = tabBtn:FindFirstChild("TabUnifiedBadge")
            if oldBadge then oldBadge:Destroy() end
        end

        for _, tabInfo in ipairs(globalLoaderData.Tabs or {}) do
            local tabName = tabInfo.Name
            local scroll = tabScrolls[tabName]
            if scroll then
                for _, child in ipairs(scroll:GetChildren()) do
                    if child:IsA("Frame") or child:IsA("TextLabel") then child:Destroy() end
                end
                local tabUniqueKey = "TabAutoBadge_" .. tabName
                if isFeatureNew(tabUniqueKey, "071120260000, 86400") then
                    setTabBadge(tabName, "BARU!", Color3.fromRGB(255, 215, 0), 1,
                        {{ key = tabUniqueKey, timestamp = "071120260000, 86400" }})
                end
                renderMenuCategory(globalLoaderData[tabInfo.DataKey] or {}, scroll, tabName)
            end
        end

        if isCurrentlyInSubMenu and currentSubMenuTitle then
            for _, tabInfo in ipairs(globalLoaderData.Tabs or {}) do
                for _, menuItem in ipairs(globalLoaderData[tabInfo.DataKey] or {}) do
                    if menuItem.Name == currentSubMenuTitle and menuItem.SubFeatures then
                        showSubMenu(menuItem.Name, menuItem.RawUrl, menuItem.SubFeatures)
                        return
                    end
                end
            end
        end
    end

    local configOk, configErr = xpcall(function()
        local configUrl = "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/main/Loader.lua"
        local source = game:HttpGet(configUrl .. "?_=" .. tostring(DateTime.now().UnixTimestampMillis))
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
                setTabBadge(tabName, "BARU!", Color3.fromRGB(255, 215, 0), 1, {{ key = tabUniqueKey, timestamp = "071120260000, 86400" }})
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
    elseif metadataReady and metadataRefreshPending and refreshBadgeUI then
        metadataRefreshPending = false
        task.defer(refreshBadgeUI)
    end
end