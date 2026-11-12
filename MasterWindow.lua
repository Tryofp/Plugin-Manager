return function()
    local Players = game:GetService("Players")
    local HttpService = game:GetService("HttpService")
    local UserInputService = game:GetService("UserInputService")
    local LocalPlayer = Players.LocalPlayer
    local SHEETS_WEB_APP_URL = "https://script.google.com/macros/s/AKfycbxJzU3MiL_o9PjkF4h-prSw-P8vLVfJqGFXM7pFJOPzIzJXaGmu6z6oK0oJl54a6bQy0Q/exec"
    local MAIN_RAW = "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/main/"
    local MAIN_LOADER_URL = MAIN_RAW .. "Loader.lua"
    local AUTHORIZED_USER_ID = 6141017541

    if not LocalPlayer or LocalPlayer.UserId ~= AUTHORIZED_USER_ID then
        warn("[Tryo Developer] Akses ditolak.")
        return
    end

    local metadata = {}
    local loaderData = nil
    local featureRows = {}
    local sourceFiles = {}
    local adminKey = ""
    local scanResults = {}
    local updateBaseline = {}
    local selectedFile = nil
    local selectedCommit = nil
    local historyPage = 1
    local pendingVersionAction = nil
    local pendingVersionSha = nil
    local pendingVersionFile = nil
    local currentPage = "home"
    local pageFrames = {}
    local resultLines = {}
    local showPage
    local loadVersionPage
    local Confirm, confirmText

    local function getRequest()
        return request or http_request or (syn and syn.request)
    end

    local function encode(value)
        local ok, result = pcall(function() return HttpService:JSONEncode(value) end)
        return ok and result or "{}"
    end

    local function decode(value)
        local ok, result = pcall(function() return HttpService:JSONDecode(value) end)
        return ok and result or nil
    end

    local function httpGet(url)
        local ok, result = pcall(function()
            return game:HttpGet(url)
        end)
        if not ok or type(result) ~= "string" or result == "" then
            return false, tostring(result or "Respons kosong")
        end
        return true, result
    end

    local function post(payload)
        local req = getRequest()
        if not req then return false, "Executor tidak menyediakan HTTP request." end
        local ok, response = pcall(function()
            return req({
                Url = SHEETS_WEB_APP_URL,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = encode(payload),
                FollowRedirects = true
            })
        end)
        if not ok or not response then return false, tostring(response or "Server tidak merespons.") end
        local responseBody = type(response) == "table" and (response.Body or response.body or response.ResponseBody) or nil
        local responseJson = type(responseBody) == "string" and decode(responseBody) or nil
        if type(responseJson) == "table" and responseJson.status == "error" then
            return false, tostring(responseJson.message or "Server menolak permintaan.")
        end
        return true, response
    end

    local function refreshMetadata()
        local ok, body = httpGet(SHEETS_WEB_APP_URL .. "?_=" .. tostring(DateTime.now().UnixTimestampMillis))
        if not ok then return false, body end
        local decoded = decode(body)
        if type(decoded) ~= "table" then return false, "Metadata bukan JSON yang valid." end
        metadata = decoded
        return true, decoded
    end

    local function refreshMainLoader()
        local ok, body = httpGet(MAIN_LOADER_URL .. "?_=" .. tostring(DateTime.now().UnixTimestampMillis))
        if not ok then return false, "Gagal mengambil Loader branch main: " .. tostring(body) end
        if type(loadstring) ~= "function" then return false, "loadstring tidak tersedia." end
        local compileOk, chunk = pcall(loadstring, body, "TryoDeveloper/MainLoader.lua")
        if not compileOk or type(chunk) ~= "function" then
            return false, "Loader main gagal dikompilasi: " .. tostring(chunk)
        end
        local runOk, data = pcall(chunk)
        if not runOk or type(data) ~= "table" or type(data.Tabs) ~= "table" then
            return false, "Struktur Loader main tidak valid: " .. tostring(data)
        end
        loaderData = data
        featureRows = {}
        sourceFiles = {}
        local seenFeatures, seenFiles = {}, {}
        for _, tab in ipairs(data.Tabs) do
            if tab.DataKey and tab.DataKey ~= "" then
                for _, item in ipairs(data[tab.DataKey] or {}) do
                    local children = item.SubFeatures and #item.SubFeatures > 0 and item.SubFeatures or { item }
                    for _, feature in ipairs(children) do
                        local id = tostring(feature.FeatureId or "")
                        local rawUrl = tostring((feature.RawUrl and feature.RawUrl ~= "") and feature.RawUrl or item.RawUrl or "")
                        local path = rawUrl:match("raw%.githubusercontent%.com/Tryofp/Plugin%-Manager/refs/heads/[^/]+/(.+)")
                            or rawUrl:match("raw%.githubusercontent%.com/Tryofp/Plugin%-Manager/[^/]+/(.+)")
                        if id ~= "" and not seenFeatures[id] then
                            seenFeatures[id] = true
                            table.insert(featureRows, {
                                id = id,
                                name = tostring(feature.Name or feature.Cmd or id),
                                tab = tostring(tab.Name or "Other"),
                                cmd = tostring(feature.Cmd or ""),
                                rawUrl = rawUrl,
                                path = path
                            })
                        end
                        if path and not seenFiles[path] then
                            seenFiles[path] = true
                            table.insert(sourceFiles, { path = path, name = tostring(feature.Name or item.Name or path), branch = "main" })
                        end
                    end
                end
            end
        end
        table.sort(featureRows, function(a,b) return string.lower(a.name) < string.lower(b.name) end)
        table.sort(sourceFiles, function(a,b) return string.lower(a.path) < string.lower(b.path) end)
        return true, data
    end

    local function featureMaintenanceKey(id)
        return "FeatureMaintenance_" .. tostring(id)
    end

    local function featureBadgeKey(id)
        return "FeatureBadge_" .. tostring(id)
    end

    local function fingerprint(source)
        local value = 0
        for i = 1, #source do
            value = (value * 131 + string.byte(source, i)) % 2147483647
        end
        return "content:" .. tostring(#source) .. ":" .. tostring(value)
    end

    local function create(className, props, parent)
        local obj = Instance.new(className)
        for key, value in pairs(props or {}) do
            obj[key] = value
        end
        obj.Parent = parent
        return obj
    end

    local COLORS = {
        bg = Color3.fromRGB(14, 19, 28),
        panel = Color3.fromRGB(23, 31, 44),
        card = Color3.fromRGB(31, 42, 58),
        cardHover = Color3.fromRGB(40, 55, 74),
        text = Color3.fromRGB(238, 244, 250),
        muted = Color3.fromRGB(151, 168, 188),
        accent = Color3.fromRGB(55, 190, 220),
        green = Color3.fromRGB(30, 150, 105),
        red = Color3.fromRGB(175, 62, 68),
        amber = Color3.fromRGB(190, 132, 45),
        line = Color3.fromRGB(53, 68, 88)
    }

    local parentGui
    pcall(function()
        if type(gethui) == "function" then parentGui = gethui() end
    end)
    if not parentGui then
        parentGui = game:GetService("CoreGui")
    end

    local oldGui = parentGui:FindFirstChild("TryoDeveloperPanel")
    if oldGui then oldGui:Destroy() end

    local ScreenGui = create("ScreenGui", {
        Name = "TryoDeveloperPanel",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    }, parentGui)

    local Frame = create("Frame", {
        Name = "Window",
        Size = UDim2.new(0, 360, 0, 440),
        Position = UDim2.new(0.5, -180, 0.5, -220),
        BackgroundColor3 = COLORS.bg,
        BorderSizePixel = 0,
        ClipsDescendants = true
    }, ScreenGui)
    create("UICorner", { CornerRadius = UDim.new(0, 10) }, Frame)
    create("UIStroke", { Color = COLORS.line, Transparency = 0.25, Thickness = 1 }, Frame)
    local frameScale = create("UIScale", { Scale = 1 }, Frame)
    local function fitWindow()
        local camera = workspace.CurrentCamera
        if not camera then return end
        local viewport = camera.ViewportSize
        frameScale.Scale = math.max(0.72, math.min(1, (viewport.X - 16) / 360, (viewport.Y - 24) / 440))
    end
    fitWindow()
    if workspace.CurrentCamera then
        workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitWindow)
    end

    local Header = create("Frame", {
        Size = UDim2.new(1, 0, 0, 43),
        BackgroundColor3 = COLORS.panel,
        BorderSizePixel = 0
    }, Frame)
    create("UICorner", { CornerRadius = UDim.new(0, 10) }, Header)
    create("Frame", {
        Size = UDim2.new(1, 0, 0, 10),
        Position = UDim2.new(0, 0, 1, -10),
        BackgroundColor3 = COLORS.panel,
        BorderSizePixel = 0
    }, Header)

    local Title = create("TextLabel", {
        Size = UDim2.new(1, -105, 0, 21),
        Position = UDim2.new(0, 13, 0, 5),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        Text = "TRYOPANEL  /  DEVELOPER",
        TextColor3 = COLORS.text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left
    }, Header)
    local Status = create("TextLabel", {
        Size = UDim2.new(1, -105, 0, 13),
        Position = UDim2.new(0, 13, 0, 25),
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        Text = "Menghubungkan ke branch main...",
        TextColor3 = COLORS.muted,
        TextSize = 8,
        TextXAlignment = Enum.TextXAlignment.Left
    }, Header)

    local Minimize = create("TextButton", {
        Size = UDim2.new(0, 27, 0, 25),
        Position = UDim2.new(1, -66, 0, 9),
        BackgroundColor3 = COLORS.card,
        BorderSizePixel = 0,
        Font = Enum.Font.GothamBold,
        Text = "—",
        TextColor3 = COLORS.text,
        TextSize = 13
    }, Header)
    create("UICorner", { CornerRadius = UDim.new(0, 5) }, Minimize)
    local Close = create("TextButton", {
        Size = UDim2.new(0, 27, 0, 25),
        Position = UDim2.new(1, -34, 0, 9),
        BackgroundColor3 = COLORS.red,
        BorderSizePixel = 0,
        Font = Enum.Font.GothamBold,
        Text = "×",
        TextColor3 = COLORS.text,
        TextSize = 15
    }, Header)
    create("UICorner", { CornerRadius = UDim.new(0, 5) }, Close)

    local Body = create("Frame", {
        Size = UDim2.new(1, -16, 1, -54),
        Position = UDim2.new(0, 8, 0, 49),
        BackgroundTransparency = 1
    }, Frame)

    local function label(parent, text, size, color, height)
        return create("TextLabel", {
            Size = UDim2.new(1, 0, 0, height or 22),
            BackgroundTransparency = 1,
            Font = Enum.Font.Gotham,
            Text = text,
            TextColor3 = color or COLORS.text,
            TextSize = size or 9,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center
        }, parent)
    end

    local function button(parent, text, color, height, callback)
        local b = create("TextButton", {
            Size = UDim2.new(1, 0, 0, height or 30),
            BackgroundColor3 = color or COLORS.card,
            BorderSizePixel = 0,
            AutoButtonColor = true,
            Font = Enum.Font.GothamBold,
            Text = text,
            TextColor3 = COLORS.text,
            TextSize = 9
        }, parent)
        create("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
        if callback then b.MouseButton1Click:Connect(callback) end
        return b
    end

    local function makeScroll(parent, y, bottom)
        local scroll = create("ScrollingFrame", {
            Size = UDim2.new(1, 0, 1, -(y + (bottom or 0))),
            Position = UDim2.new(0, 0, 0, y),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = COLORS.muted,
            Active = true,
            CanvasSize = UDim2.new(0, 0, 0, 0)
        }, parent)
        local layout = create("UIListLayout", {
            Padding = UDim.new(0, 6),
            SortOrder = Enum.SortOrder.LayoutOrder
        }, scroll)
        layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
        end)
        return scroll, layout
    end

    local function clearRows(scroll)
        for _, child in ipairs(scroll:GetChildren()) do
            if child:IsA("GuiObject") and not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
                child:Destroy()
            end
        end
        scroll.CanvasPosition = Vector2.new(0, 0)
    end

    local function setStatus(text, color)
        Status.Text = tostring(text or "")
        Status.TextColor3 = color or COLORS.muted
    end

    local function makePage(name, title, subtitle)
        local page = create("Frame", {
            Name = name,
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Visible = false
        }, Body)
        pageFrames[name] = page
        local back = button(page, "‹  KEMBALI", COLORS.card, 27, function()
            showPage("home")
        end)
        local head = label(page, title, 13, COLORS.text, 24)
        head.Position = UDim2.new(0, 0, 0, 32)
        local sub = label(page, subtitle or "", 8, COLORS.muted, 26)
        sub.Position = UDim2.new(0, 0, 0, 56)
        local scroll = makeScroll(page, 86, 0)
        return page, scroll, sub
    end

    showPage = function(name)
        currentPage = name
        for key, page in pairs(pageFrames) do page.Visible = key == name end
    end

    local Home = create("Frame", { Name = "Home", Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1 }, Body)
    pageFrames.home = Home
    local Welcome = label(Home, "PUBLIC CONTROL CENTER", 12, COLORS.accent, 22)
    Welcome.Position = UDim2.new(0, 0, 0, 0)
    local Intro = label(Home, "Semua kontrol di bawah membaca Loader branch main dan mengirim perubahan ke backend online.", 8, COLORS.muted, 32)
    Intro.Position = UDim2.new(0, 0, 0, 23)

    local KeyLabel = label(Home, "ADMIN KEY  •  dipakai untuk aksi yang dilindungi server", 8, COLORS.muted, 15)
    KeyLabel.Position = UDim2.new(0, 0, 0, 59)
    local KeyBox = create("TextBox", {
        Size = UDim2.new(1, 0, 0, 29),
        Position = UDim2.new(0, 0, 0, 76),
        BackgroundColor3 = COLORS.panel,
        BorderSizePixel = 0,
        Font = Enum.Font.Gotham,
        Text = "",
        PlaceholderText = "Masukkan kunci Developer",
        PlaceholderColor3 = COLORS.muted,
        TextColor3 = COLORS.text,
        TextSize = 9,
        ClearTextOnFocus = false
    }, Home)
    create("UICorner", { CornerRadius = UDim.new(0, 5) }, KeyBox)
    KeyBox:GetPropertyChangedSignal("Text"):Connect(function() adminKey = KeyBox.Text end)

    local Overview = create("Frame", {
        Size = UDim2.new(1, 0, 0, 43),
        Position = UDim2.new(0, 0, 0, 113),
        BackgroundColor3 = COLORS.panel,
        BorderSizePixel = 0
    }, Home)
    create("UICorner", { CornerRadius = UDim.new(0, 6) }, Overview)
    local OverviewText = create("TextLabel", {
        Size = UDim2.new(1, -16, 1, -8),
        Position = UDim2.new(0, 8, 0, 4),
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        Text = "Loader: --   •   Features: --   •   Source: --",
        TextColor3 = COLORS.muted,
        TextSize = 8,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left
    }, Overview)

    local HomeScroll = makeScroll(Home, 166, 0)
    local function homeCard(title, desc, color, callback)
        local card = create("TextButton", {
            Size = UDim2.new(1, 0, 0, 54),
            BackgroundColor3 = COLORS.card,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = true
        }, HomeScroll)
        create("UICorner", { CornerRadius = UDim.new(0, 7) }, card)
        local t = create("TextLabel", {
            Size = UDim2.new(1, -18, 0, 20),
            Position = UDim2.new(0, 9, 0, 6),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            Text = title,
            TextColor3 = color or COLORS.text,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left
        }, card)
        local d = create("TextLabel", {
            Size = UDim2.new(1, -18, 0, 20),
            Position = UDim2.new(0, 9, 0, 27),
            BackgroundTransparency = 1,
            Font = Enum.Font.Gotham,
            Text = desc,
            TextColor3 = COLORS.muted,
            TextSize = 8,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left
        }, card)
        card.MouseButton1Click:Connect(callback)
        return card
    end

    local MaintenancePage, MaintenanceScroll, MaintenanceInfo = makePage("maintenance", "MAINTENANCE CONTROL", "Toggle status fitur publik. Perubahan diverifikasi ulang dari metadata online.")
    local BadgePage, BadgeScroll, BadgeInfo = makePage("badges", "BADGE MANAGER", "Pilih beberapa badge sekaligus, atau reset semua badge publik.")
    local VersionPage, VersionScroll, VersionInfo = makePage("versions", "VERSION MANAGER", "Riwayat, Stable Backup, dan restore langsung pada source branch main.")
    local HealthPage, HealthScroll, HealthInfo = makePage("health", "PLUGIN HEALTH CHECK", "Memeriksa Loader dan source tanpa menjalankan kode plugin.")
    local UpdatePage, UpdateScroll, UpdateInfo = makePage("updates", "UPDATE CHECKER", "Bandingkan source main dengan baseline online yang tersimpan di Apps Script.")
    local RuntimePage, RuntimeScroll, RuntimeInfo = makePage("runtime", "RUNTIME ERROR HISTORY", "Lihat laporan error plugin yang tercatat di server.")

    local function addSimpleRow(scroll, title, detail, statusText, actionText, actionColor, callback)
        local row = create("Frame", {
            Size = UDim2.new(1, 0, 0, 45),
            BackgroundColor3 = COLORS.card,
            BorderSizePixel = 0
        }, scroll)
        create("UICorner", { CornerRadius = UDim.new(0, 5) }, row)
        local name = create("TextLabel", {
            Size = UDim2.new(1, -105, 0, 19),
            Position = UDim2.new(0, 8, 0, 4),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            Text = title,
            TextColor3 = COLORS.text,
            TextSize = 9,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd
        }, row)
        local desc = create("TextLabel", {
            Size = UDim2.new(1, -105, 0, 15),
            Position = UDim2.new(0, 8, 0, 24),
            BackgroundTransparency = 1,
            Font = Enum.Font.Gotham,
            Text = detail or "",
            TextColor3 = COLORS.muted,
            TextSize = 7,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd
        }, row)
        local action = create("TextButton", {
            Size = UDim2.new(0, 88, 0, 25),
            Position = UDim2.new(1, -96, 0.5, -12),
            BackgroundColor3 = actionColor or COLORS.green,
            BorderSizePixel = 0,
            Font = Enum.Font.GothamBold,
            Text = actionText or statusText or "BUKA",
            TextColor3 = COLORS.text,
            TextSize = 8
        }, row)
        create("UICorner", { CornerRadius = UDim.new(0, 4) }, action)
        if callback then action.MouseButton1Click:Connect(callback) end
        return row, action
    end

    local function reloadData()
        setStatus("Memuat Loader main dan metadata...")
        local a, b = refreshMainLoader()
        local m, md = refreshMetadata()
        if a then
            OverviewText.Text = "Loader: ONLINE   •   Features: " .. tostring(#featureRows) .. "   •   Source: " .. tostring(#sourceFiles)
            setStatus(m and "Terhubung • branch main" or "Loader online • metadata belum tersedia", m and COLORS.green or COLORS.amber)
        else
            OverviewText.Text = "Loader: ERROR   •   " .. tostring(b)
            setStatus("Gagal memuat Loader main", COLORS.red)
        end
        return a, b, m, md
    end

    local function loadMaintenancePage()
        clearRows(MaintenanceScroll)
        local ok, err = refreshMainLoader()
        local metaOk = refreshMetadata()
        if not ok then MaintenanceInfo.Text = tostring(err) return end
        MaintenanceInfo.Text = tostring(#featureRows) .. " fitur ditemukan dari Loader main."
        for _, feature in ipairs(featureRows) do
            local key = featureMaintenanceKey(feature.id)
            local enabled = tostring(metadata[key] or "") == "ACTIVE"
            local row, action
        row, action = addSimpleRow(MaintenanceScroll, feature.name, feature.tab .. "  •  " .. feature.id,
                enabled and "ACTIVE" or "OFF", enabled and "NONAKTIFKAN" or "MAINTENANCE",
                enabled and COLORS.green or COLORS.red, function()
                    action.Active = false
                    action.Text = "..."
                    task.spawn(function()
                        local sent, response = post({
                            Type = "FeatureMaintenance",
                            FeatureId = feature.id,
                            Enabled = not enabled,
                            AdminKey = adminKey
                        })
                        local verified = false
                        if sent then
                            for attempt = 1, 4 do
                                task.wait(0.35)
                                local fetched = refreshMetadata()
                                if fetched and tostring(metadata[key] or "") == ((not enabled) and "ACTIVE" or "") then
                                    verified = true
                                    break
                                end
                            end
                        end
                        if verified then
                            loadMaintenancePage()
                            setStatus("Maintenance diperbarui: " .. feature.name, COLORS.green)
                        else
                            action.Text = "GAGAL"
                            action.Active = true
                            setStatus("Aksi maintenance gagal diverifikasi. Periksa Admin Key.", COLORS.red)
                        end
                    end)
                end)
        end
    end

    local badgeSelections = {}
    local function loadBadgePage()
        clearRows(BadgeScroll)
        badgeSelections = {}
        local ok, err = refreshMainLoader()
        refreshMetadata()
        if not ok then BadgeInfo.Text = tostring(err) return end
        local selectedCount = 0
        local top = create("Frame", { Size = UDim2.new(1,0,0,35), BackgroundTransparency = 1 }, BadgeScroll)
        local countLabel = create("TextLabel", {
            Size = UDim2.new(0.5,0,1,0), BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold, Text = "0 dipilih", TextColor3 = COLORS.accent,
            TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left
        }, top)
        local deleteSelected = create("TextButton", {
            Size = UDim2.new(0.5,-4,0,27), Position = UDim2.new(0.5,4,0,3),
            BackgroundColor3 = COLORS.red, BorderSizePixel = 0,
            Font = Enum.Font.GothamBold, Text = "HAPUS TERPILIH",
            TextColor3 = COLORS.text, TextSize = 8
        }, top)
        create("UICorner", { CornerRadius = UDim.new(0,4) }, deleteSelected)
        button(BadgeScroll, "RESET SEMUA BADGE PUBLIK", COLORS.red, 30, function()
            task.spawn(function()
                local before = tostring(metadata.BadgeClearBefore or "")
                local sent = post({ Type = "ClearAllBadges" })
                task.wait(0.35)
                local refreshed = refreshMetadata()
                local verified = sent and refreshed and tostring(metadata.BadgeClearBefore or "") ~= before
                if verified then
                    BadgeInfo.Text = "Reset global terverifikasi dari metadata online."
                    loadBadgePage()
                    setStatus("Reset badge global selesai", COLORS.green)
                else
                    BadgeInfo.Text = "Reset global belum terverifikasi. Coba refresh metadata."
                    setStatus("Reset badge global gagal diverifikasi", COLORS.red)
                end
            end)
        end)
        local active = 0
        for _, feature in ipairs(featureRows) do
            local key = featureBadgeKey(feature.id)
            local value = tostring(metadata[key] or "")
            local isActive = value:match("^ACTIVE:") ~= nil
            if isActive then active = active + 1 end
            local row = create("Frame", { Size = UDim2.new(1,0,0,38), BackgroundColor3 = COLORS.card, BorderSizePixel = 0 }, BadgeScroll)
            create("UICorner", { CornerRadius = UDim.new(0,5) }, row)
            local check = create("TextButton", {
                Size = UDim2.new(0,25,0,25), Position = UDim2.new(0,6,0.5,-12),
                BackgroundColor3 = COLORS.panel, BorderSizePixel = 0,
                Font = Enum.Font.GothamBold, Text = "□", TextColor3 = COLORS.text, TextSize = 13
            }, row)
            create("UICorner", { CornerRadius = UDim.new(0,4) }, check)
            create("TextLabel", {
                Size = UDim2.new(1,-135,0,18), Position = UDim2.new(0,38,0,3),
                BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
                Text = feature.name, TextColor3 = COLORS.text, TextSize = 8,
                TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd
            }, row)
            create("TextLabel", {
                Size = UDim2.new(1,-135,0,13), Position = UDim2.new(0,38,0,21),
                BackgroundTransparency = 1, Font = Enum.Font.Gotham,
                Text = feature.tab .. " • " .. (isActive and "BADGE AKTIF" or "Tidak aktif"),
                TextColor3 = isActive and COLORS.accent or COLORS.muted,
                TextSize = 7, TextXAlignment = Enum.TextXAlignment.Left
            }, row)
            local clear = create("TextButton", {
                Size = UDim2.new(0,76,0,23), Position = UDim2.new(1,-82,0.5,-11),
                BackgroundColor3 = COLORS.red, BorderSizePixel = 0,
                Font = Enum.Font.GothamBold, Text = "HAPUS",
                TextColor3 = COLORS.text, TextSize = 8
            }, row)
            create("UICorner", { CornerRadius = UDim.new(0,4) }, clear)
            local function clearOne()
                clear.Active = false
                clear.Text = "..."
                task.spawn(function()
                    local sent = post({ Type = "FeatureUpdate", Key = key, Timestamp = "" })
                    task.wait(0.25)
                    refreshMetadata()
                    sent = sent and tostring(metadata[key] or "") == "CLEARED"
                    if sent then
                        clear.Text = "OK"
                        setStatus("Badge dibersihkan: " .. feature.name, COLORS.green)
                        task.wait(0.3)
                        loadBadgePage()
                    else
                        clear.Text = "ERROR"
                        clear.Active = true
                    end
                end)
            end
            clear.MouseButton1Click:Connect(clearOne)
            check.MouseButton1Click:Connect(function()
                badgeSelections[key] = not badgeSelections[key]
                check.Text = badgeSelections[key] and "✓" or "□"
                selectedCount = 0
                for _, selected in pairs(badgeSelections) do if selected then selectedCount = selectedCount + 1 end end
                countLabel.Text = tostring(selectedCount) .. " dipilih"
            end)
        end
        deleteSelected.MouseButton1Click:Connect(function()
            local keys = {}
            for key, selected in pairs(badgeSelections) do if selected then table.insert(keys, key) end end
            if #keys == 0 then BadgeInfo.Text = "Pilih minimal satu badge terlebih dahulu." return end
            deleteSelected.Active = false
            deleteSelected.Text = "MENGHAPUS..."
            task.spawn(function()
                local sentKeys, failed = {}, 0
                for _, key in ipairs(keys) do
                    local sent = post({ Type = "FeatureUpdate", Key = key, Timestamp = "" })
                    if sent then table.insert(sentKeys, key) else failed = failed + 1 end
                    task.wait(0.12)
                end
                refreshMetadata()
                local done = 0
                for _, key in ipairs(sentKeys) do
                    if tostring(metadata[key] or "") == "CLEARED" then done = done + 1 else failed = failed + 1 end
                end
                BadgeInfo.Text = tostring(done) .. " badge terverifikasi dihapus • " .. tostring(failed) .. " gagal."
                loadBadgePage()
                setStatus("Batch hapus badge selesai", failed == 0 and COLORS.green or COLORS.amber)
            end)
        end)
        BadgeInfo.Text = tostring(active) .. " badge aktif dari " .. tostring(#featureRows) .. " fitur."
    end

    local function requestVersionHistory(fileInfo, page)
        local url = SHEETS_WEB_APP_URL .. "?action=VersionHistory&branch=main&path="
            .. HttpService:UrlEncode(fileInfo.path) .. "&page=" .. tostring(page or 1)
            .. "&_=" .. tostring(DateTime.now().UnixTimestampMillis)
        return httpGet(url)
    end

    local function showVersionList(fileInfo, page)
        selectedFile = fileInfo
        selectedCommit = nil
        historyPage = math.max(1, tonumber(page) or 1)
        clearRows(VersionScroll)
        VersionInfo.Text = "Memuat riwayat " .. fileInfo.path .. "..."
        task.spawn(function()
            local ok, body = requestVersionHistory(fileInfo, historyPage)
            local result = ok and decode(body) or nil
            local commits = type(result) == "table" and result.status == "success" and result.commits or nil
            if type(commits) ~= "table" then
                VersionInfo.Text = "Riwayat gagal dimuat: " .. tostring(type(result) == "table" and result.message or body)
                return
            end
            VersionInfo.Text = fileInfo.path .. " • main • halaman " .. tostring(historyPage) .. " • " .. tostring(#commits) .. " commit"
            local back = button(VersionScroll, "‹  DAFTAR FILE", COLORS.card, 27, function()
                selectedFile = nil
                loadVersionPage()
            end)
            local function versionAction(text, action, shaSource)
                button(VersionScroll, text, COLORS.amber, 30, function()
                    local sha = type(shaSource) == "function" and shaSource() or shaSource
                    if action == "RestoreSelected" and not sha then
                        VersionInfo.Text = "Pilih commit terlebih dahulu."
                        return
                    end
                    pendingVersionAction = action
                    pendingVersionSha = sha
                    pendingVersionFile = fileInfo
                    confirmText.Text = "Konfirmasi " .. action .. " untuk " .. fileInfo.path ..
                        (sha and (" • " .. sha:sub(1,7)) or "") .. " pada branch main?"
                    Confirm.Visible = true
                end)
            end
            versionAction("SIMPAN STABLE BACKUP", "SetStable", nil)
            versionAction("RESTORE STABLE BACKUP", "RestoreStable", nil)
            versionAction("RESTORE COMMIT TERPILIH", "RestoreSelected", function() return selectedCommit and selectedCommit.sha end)
            task.spawn(function()
                refreshMetadata()
                local stable = tostring(metadata.StableBackupCommit or "")
                if stable ~= "" then
                    VersionInfo.Text = fileInfo.path .. " • main • halaman " .. tostring(historyPage) .. " • Stable Backup " .. stable:sub(1,7)
                end
            end)
            if #commits == 0 then
                label(VersionScroll, "Belum ada riwayat commit pada halaman ini.", 8, COLORS.muted, 25)
            end
            for index, entry in ipairs(commits) do
                local commit = entry.commit or {}
                local author = commit.author or {}
                local sha = tostring(entry.sha or "")
                local msg = tostring(commit.message or "Tanpa pesan"):gsub("[\r\n]+", " ")
                if #msg > 95 then msg = msg:sub(1,92) .. "..." end
                local row = create("TextButton", {
                    Size = UDim2.new(1,0,0,48), BackgroundColor3 = COLORS.card,
                    BorderSizePixel = 0, Text = "", AutoButtonColor = true
                }, VersionScroll)
                create("UICorner", { CornerRadius = UDim.new(0,5) }, row)
                create("TextLabel", {
                    Size = UDim2.new(1,-12,0,20), Position = UDim2.new(0,7,0,4),
                    BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
                    Text = tostring(index) .. ". " .. msg, TextColor3 = COLORS.text,
                    TextSize = 8, TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd
                }, row)
                create("TextLabel", {
                    Size = UDim2.new(1,-12,0,14), Position = UDim2.new(0,7,0,26),
                    BackgroundTransparency = 1, Font = Enum.Font.Gotham,
                    Text = tostring(author.date or "Tanggal tidak tersedia") .. " • " .. sha:sub(1,7),
                    TextColor3 = COLORS.muted, TextSize = 7,
                    TextXAlignment = Enum.TextXAlignment.Left
                }, row)
                row.MouseButton1Click:Connect(function()
                    selectedCommit = { sha = sha, message = msg }
                    VersionInfo.Text = "Terpilih: " .. sha:sub(1,7) .. " • " .. msg
                    for _, child in ipairs(VersionScroll:GetChildren()) do
                        if child:IsA("TextButton") and child ~= row then child.BackgroundColor3 = COLORS.card end
                    end
                    row.BackgroundColor3 = COLORS.cardHover
                end)
            end
            if historyPage > 1 then
                button(VersionScroll, "‹  HALAMAN SEBELUMNYA", COLORS.card, 27, function()
                    showVersionList(fileInfo, historyPage - 1)
                end)
            end
            if #commits >= 30 and historyPage < 10 then
                button(VersionScroll, "HALAMAN BERIKUTNYA  ›", COLORS.card, 27, function()
                    showVersionList(fileInfo, historyPage + 1)
                end)
            end
        end)
    end

    loadVersionPage = function()
        clearRows(VersionScroll)
        selectedFile = nil
        selectedCommit = nil
        local ok, err = refreshMainLoader()
        if not ok then VersionInfo.Text = tostring(err) return end
        VersionInfo.Text = tostring(#sourceFiles) .. " source file dari Loader main."
        for _, fileInfo in ipairs(sourceFiles) do
            addSimpleRow(VersionScroll, fileInfo.name, fileInfo.path, "main", "RIWAYAT", COLORS.accent, function()
                showVersionList(fileInfo)
            end)
        end
    end

    local function runVersionAction(action, sha, fileInfo)
        if adminKey == "" then VersionInfo.Text = "Masukkan Admin Key di halaman utama." return end
        refreshMetadata()
        local beforeRestore = tostring(metadata.LastVersionRestoreAt or "")
        local stableKey = "StableBackupCommit"
        local beforeStable = tostring(metadata.StableBackupUpdatedAt or "")
        VersionInfo.Text = "Mengirim " .. action .. " ke Apps Script..."
        local sent, response = post({
            Type = "VersionManager",
            Action = action,
            Path = fileInfo.path,
            Branch = "main",
            CommitSha = sha or "",
            AdminKey = adminKey
        })
        for attempt = 1, 5 do
            task.wait(0.4)
            if refreshMetadata() then
                if action == "SetStable" then
                    local newStable = tostring(metadata[stableKey] or "")
                    local updatedAt = tostring(metadata.StableBackupUpdatedAt or "")
                    if newStable ~= "" and updatedAt ~= "" and updatedAt ~= beforeStable then
                        VersionInfo.Text = "Stable Backup tersimpan • " .. newStable:sub(1,7)
                        return
                    end
                else
                    local restoreAt = tostring(metadata.LastVersionRestoreAt or "")
                    local restorePath = tostring(metadata.LastVersionRestorePath or "")
                    local restoreBranch = tostring(metadata.LastVersionRestoreBranch or "main")
                    local newCommit = tostring(metadata.LastVersionRestoreCommit or "")
                    if restoreAt ~= "" and restoreAt ~= beforeRestore and restorePath == fileInfo.path
                        and restoreBranch == "main" and newCommit ~= "" then
                        VersionInfo.Text = "Restore berhasil • commit baru " .. newCommit:sub(1,7)
                        showVersionList(fileInfo)
                        return
                    end
                end
            end
        end
        VersionInfo.Text = sent and "Server belum mengonfirmasi perubahan. Periksa Admin Key dan metadata." or ("Gagal: " .. tostring(response))
    end

    Confirm = create("Frame", {
        Size = UDim2.new(1,-28,0,122), Position = UDim2.new(0,14,0.5,-61),
        BackgroundColor3 = COLORS.panel, BorderSizePixel = 0, Visible = false, ZIndex = 20
    }, Frame)
    create("UICorner", { CornerRadius = UDim.new(0,8) }, Confirm)
    confirmText = create("TextLabel", {
        Size = UDim2.new(1,-18,0,65), Position = UDim2.new(0,9,0,7),
        BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
        Text = "Konfirmasi tindakan", TextColor3 = COLORS.text,
        TextSize = 9, TextWrapped = true, ZIndex = 21
    }, Confirm)
    local confirmYes = button(Confirm, "YA, LANJUTKAN", COLORS.green, 29, function()
        Confirm.Visible = false
        local action, sha, fileInfo = pendingVersionAction, pendingVersionSha, pendingVersionFile
        pendingVersionAction, pendingVersionSha, pendingVersionFile = nil, nil, nil
        if action and fileInfo then task.spawn(function() runVersionAction(action, sha, fileInfo) end) end
    end)
    confirmYes.Size = UDim2.new(0.5,-13,0,28)
    confirmYes.Position = UDim2.new(0,8,1,-36)
    local confirmNo = button(Confirm, "BATAL", COLORS.card, 28, function()
        Confirm.Visible = false
        pendingVersionAction, pendingVersionSha, pendingVersionFile = nil, nil, nil
    end)
    confirmNo.Size = UDim2.new(0.5,-13,0,28)
    confirmNo.Position = UDim2.new(0.5,5,1,-36)

    function loadHealthPage()
        clearRows(HealthScroll)
        resultLines = {}
        local ok, err = refreshMainLoader()
        if not ok then HealthInfo.Text = tostring(err) return end
        HealthInfo.Text = "Memeriksa " .. tostring(#featureRows) .. " fitur dan " .. tostring(#sourceFiles) .. " source..."
        local ids, errors, checks = {}, 0, 0
        local function report(title, detail, failed)
            checks = checks + 1
            if failed then errors = errors + 1 end
            local line = (failed and "[ERROR] " or "[OK] ") .. title .. " — " .. detail
            table.insert(resultLines, line)
            addSimpleRow(HealthScroll, title, detail, "", failed and "ERROR" or "OK", failed and COLORS.red or COLORS.green)
        end
        for _, feature in ipairs(featureRows) do
            if ids[feature.id] and ids[feature.id] ~= feature.name then
                report(feature.name, "FeatureId bentrok: " .. feature.id, true)
            else
                ids[feature.id] = feature.name
            end
            if feature.rawUrl == "" or not feature.path then
                report(feature.name, "RawUrl tidak valid / bukan source repo.", true)
            else
                report(feature.name, "FeatureId dan RawUrl valid • " .. feature.id, false)
            end
        end
        for _, fileInfo in ipairs(sourceFiles) do
            local got, source = httpGet(MAIN_RAW .. fileInfo.path)
            if not got then
                report(fileInfo.path, "Gagal mengunduh source: " .. tostring(source), true)
            elseif type(loadstring) ~= "function" then
                report(fileInfo.path, "Source terunduh, tetapi loadstring tidak tersedia untuk compile check.", true)
            else
                local compiled, chunk = pcall(loadstring, source, "HealthCheck/" .. fileInfo.path)
                report(fileInfo.path, compiled and type(chunk) == "function" and ("Compile OK • " .. #source .. " byte") or ("Compile gagal: " .. tostring(chunk)), not (compiled and type(chunk) == "function"))
            end
            task.wait(0.05)
        end
        HealthInfo.Text = "Selesai • " .. tostring(checks) .. " pemeriksaan • " .. tostring(errors) .. " temuan."
        setStatus("Health Check selesai", errors == 0 and COLORS.green or COLORS.amber)
    end

    local function loadUpdateBaseline()
        updateBaseline = {}
        local raw = tostring(metadata.PluginUpdateCheckerBaseline or "")
        if raw ~= "" then
            local decoded = decode(raw)
            if type(decoded) == "table" then updateBaseline = decoded end
        end
    end

    function runUpdateCheck()
        clearRows(UpdateScroll)
        scanResults = {}
        local ok, err = refreshMainLoader()
        local metaOk = refreshMetadata()
        if not ok then UpdateInfo.Text = tostring(err) return end
        if not metaOk then UpdateInfo.Text = "Metadata online gagal dimuat." return end
        loadUpdateBaseline()
        UpdateInfo.Text = "Memeriksa " .. tostring(#sourceFiles) .. " source..."
        local updated, unchanged, fresh, failed = 0, 0, 0, 0
        for _, fileInfo in ipairs(sourceFiles) do
            local got, source = httpGet(MAIN_RAW .. fileInfo.path)
            if not got then
                failed = failed + 1
                addSimpleRow(UpdateScroll, fileInfo.path, tostring(source), "ERROR", "ERROR", COLORS.red)
            else
                local fp = fingerprint(source)
                scanResults[fileInfo.path] = { sha = fp, name = fileInfo.name }
                local baseline = tostring(updateBaseline[fileInfo.path] or "")
                if baseline == "" then
                    fresh = fresh + 1
                    addSimpleRow(UpdateScroll, fileInfo.path, "Belum ada baseline • " .. #source .. " byte", "BARU", "BARU", COLORS.amber)
                elseif baseline ~= fp then
                    updated = updated + 1
                    addSimpleRow(UpdateScroll, fileInfo.path, "Isi source berubah dari baseline.", "UPDATE", "UPDATE", COLORS.amber)
                else
                    unchanged = unchanged + 1
                    addSimpleRow(UpdateScroll, fileInfo.path, "Source masih sama • " .. #source .. " byte", "OK", "OK", COLORS.green)
                end
            end
            task.wait(0.05)
        end
        UpdateInfo.Text = string.format("Selesai • %d source • %d update • %d sama • %d baru • %d gagal.", #sourceFiles, updated, unchanged, fresh, failed)
        setStatus("Update Checker selesai", failed == 0 and COLORS.green or COLORS.amber)
    end

    local function saveUpdateBaseline()
        if adminKey == "" then UpdateInfo.Text = "Masukkan Admin Key di halaman utama." return end
        if next(scanResults) == nil then UpdateInfo.Text = "Jalankan pemeriksaan terlebih dahulu." return end
        local nextBaseline = {}
        for path, value in pairs(updateBaseline) do nextBaseline[path] = value end
        for path, result in pairs(scanResults) do nextBaseline[path] = result.sha end
        local encoded = encode(nextBaseline)
        local before = tostring(metadata.PluginUpdateCheckerBaselineUpdatedAt or "")
        local sent, response = post({
            Type = "UpdateBaseline",
            Action = "Save",
            Baseline = encoded,
            AdminKey = adminKey
        })
        for attempt = 1, 5 do
            task.wait(0.4)
            if refreshMetadata() then
                if tostring(metadata.PluginUpdateCheckerBaseline or "") == encoded
                    and tostring(metadata.PluginUpdateCheckerBaselineUpdatedAt or "") ~= ""
                    and tostring(metadata.PluginUpdateCheckerBaselineUpdatedAt or "") ~= before then
                    updateBaseline = nextBaseline
                    UpdateInfo.Text = "Baseline berhasil disimpan online. Bisa digunakan lintas perangkat."
                    setStatus("Baseline online tersimpan", COLORS.green)
                    return
                end
            end
        end
        UpdateInfo.Text = sent and "Server belum mengonfirmasi baseline." or ("Gagal: " .. tostring(response))
    end

    local function loadRuntimeHistory()
        clearRows(RuntimeScroll)
        RuntimeInfo.Text = "Mengambil laporan error terbaru..."
        task.spawn(function()
            local ok, body = httpGet(SHEETS_WEB_APP_URL .. "?action=PluginErrors&limit=50&_=" .. tostring(DateTime.now().UnixTimestampMillis))
            local result = ok and decode(body) or nil
            if type(result) ~= "table" or result.status ~= "success" or type(result.records) ~= "table" then
                RuntimeInfo.Text = "Riwayat gagal dimuat: " .. tostring(type(result) == "table" and result.message or body)
                return
            end
            RuntimeInfo.Text = tostring(#result.records) .. " laporan terbaru."
            if #result.records == 0 then label(RuntimeScroll, "Belum ada laporan runtime error.", 8, COLORS.muted, 24) end
            for _, record in ipairs(result.records) do
                local title = tostring(record.Plugin or record.Command or "Plugin Error")
                local detail = tostring(record.Error or "Tidak ada detail") .. " • " .. tostring(record.Source or record.Timestamp or "")
                addSimpleRow(RuntimeScroll, title, detail, "", "LOG", COLORS.red)
            end
        end)
    end

    local function openMaintenance() showPage("maintenance"); loadMaintenancePage() end
    local function openBadges() showPage("badges"); loadBadgePage() end
    local function openVersions() showPage("versions"); loadVersionPage() end
    local function openHealth() showPage("health"); loadHealthPage() end
    local function openUpdates() showPage("updates"); clearRows(UpdateScroll); UpdateInfo.Text = "Tekan tombol di bawah untuk memulai pemeriksaan." end
    local function openRuntime() showPage("runtime"); loadRuntimeHistory() end

    homeCard("01  •  MAINTENANCE", "Aktifkan / nonaktifkan fitur publik secara online.", COLORS.accent, openMaintenance)
    homeCard("02  •  BADGE MANAGER", "Hapus satu badge, batch beberapa badge, atau reset global.", COLORS.text, openBadges)
    homeCard("03  •  VERSION MANAGER", "Lihat commit, simpan Stable Backup, dan restore source main.", COLORS.text, openVersions)
    homeCard("04  •  PLUGIN HEALTH CHECK", "Validasi Feature ID, URL, unduhan source, dan compile.", COLORS.text, openHealth)
    homeCard("05  •  UPDATE CHECKER", "Bandingkan source main dengan baseline online.", COLORS.text, openUpdates)
    homeCard("06  •  RUNTIME ERROR", "Baca laporan error plugin dari Apps Script.", COLORS.text, openRuntime)

    local healthRunButton = button(HealthPage, "JALANKAN PEMERIKSAAN", COLORS.green, 28, loadHealthPage)
    healthRunButton.Size = UDim2.new(0.49, -3, 0, 28)
    healthRunButton.Position = UDim2.new(0, 0, 1, -33)
    local healthExportButton = button(HealthPage, "EXPORT HASIL", COLORS.card, 28, function()
        if #resultLines == 0 then HealthInfo.Text = "Jalankan pemeriksaan sebelum export." return end
        local report = "TRYOPANEL HEALTH CHECK\n" .. table.concat(resultLines, "\n")
        if type(setclipboard) == "function" then
            local ok = pcall(setclipboard, report)
            HealthInfo.Text = ok and "Hasil pemeriksaan disalin ke clipboard." or "Clipboard gagal. Coba executor lain."
        elseif type(writefile) == "function" then
            local ok = pcall(writefile, "TryoDeveloperHealthCheck.txt", report)
            HealthInfo.Text = ok and "Hasil disimpan ke TryoDeveloperHealthCheck.txt." or "Gagal menyimpan file export."
        else
            HealthInfo.Text = "Executor tidak mendukung clipboard atau writefile."
        end
    end)
    healthExportButton.Size = UDim2.new(0.49, -3, 0, 28)
    healthExportButton.Position = UDim2.new(0.51, 3, 1, -33)
    button(UpdatePage, "SCAN SOURCE MAIN", COLORS.green, 28, runUpdateCheck).Position = UDim2.new(0,0,1,-66)
    button(UpdatePage, "SIMPAN BASELINE ONLINE", COLORS.amber, 28, saveUpdateBaseline).Position = UDim2.new(0,0,1,-33)
    button(RuntimePage, "KIRIM TEST REPORT", COLORS.amber, 28, function()
        local sent, response = post({
            Type = "PluginRuntimeError",
            Plugin = "Developer Panel Test",
            Command = "runtime-report-test",
            Source = "internal://developer-panel-test",
            Error = "Simulasi jalur laporan runtime error dari Developer Panel.",
            PlaceId = tostring(game.PlaceId)
        })
        RuntimeInfo.Text = sent and "Test report dikirim. Muat ulang riwayat untuk melihat hasilnya." or ("Test report gagal: " .. tostring(response))
    end).Position = UDim2.new(0,0,1,-66)
    button(RuntimePage, "MUAT ULANG RIWAYAT", COLORS.green, 28, loadRuntimeHistory).Position = UDim2.new(0,0,1,-33)

    -- Drag window, mobile-safe and independent of the page content.
    local dragging, dragStart, startPos
    Header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = Frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            Frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    local minimized = false
    Minimize.MouseButton1Click:Connect(function()
        minimized = not minimized
        Body.Visible = not minimized
        Frame.Size = minimized and UDim2.new(0,360,0,43) or UDim2.new(0,360,0,440)
        Minimize.Text = minimized and "+" or "—"
    end)
    Close.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

    local function refreshOverview()
        local ok, data = refreshMainLoader()
        local metaOk = refreshMetadata()
        if ok then
            OverviewText.Text = "Loader: ONLINE   •   Features: " .. tostring(#featureRows) .. "   •   Source: " .. tostring(#sourceFiles)
            setStatus(metaOk and ("Online • main • Last Update: " .. tostring(metadata.LastUpdate or "-")) or "Main online • metadata offline", metaOk and COLORS.green or COLORS.amber)
        else
            OverviewText.Text = "Loader: ERROR • " .. tostring(data)
            setStatus("Koneksi branch main gagal", COLORS.red)
        end
    end

    showPage("home")
    task.spawn(refreshOverview)
    task.spawn(function()
        while ScreenGui.Parent do
            task.wait(20)
            if not ScreenGui.Parent then break end
            refreshMetadata()
            if currentPage == "home" then
                local last = tostring(metadata.LastUpdate or "-")
                setStatus("Online • main • Last Update: " .. last, COLORS.green)
            end
        end
    end)
end
