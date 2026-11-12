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
    local serverVersionProfilesLoadStarted = false
    local globalLoaderData = nil
    local refreshBadgeUI = nil
    local openPublicHistoryPanels = 0
    local pendingPublicBadgeRefresh = false

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
                    Type = isLeaving and "Tracker" or "HubLoad",
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

    -- Replace the previous exit hook when the hub UI is reopened.
    -- Otherwise every MasterWindow invocation adds another Tracker POST on exit.
    local previousTrackerConnection = _G.MasterPluginHub_TrackerRemovingConnection
    if previousTrackerConnection then
        pcall(function() previousTrackerConnection:Disconnect() end)
    end
    _G.MasterPluginHub_TrackerRemovingConnection = Players.PlayerRemoving:Connect(function(plr)
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

    -- ==========================================
    -- ⭐ FAVORITE / PIN (PERSISTEN LOKAL PER USER)
    -- ==========================================
    local FAVORITE_FOLDER = "PluginManager/Profiles"
    local FAVORITE_FILE = FAVORITE_FOLDER .. "/" .. tostring(LocalPlayer.UserId) .. ".json"
    local favoritePlugins = _G.MasterPluginHub_Favorites or {}
    _G.MasterPluginHub_Favorites = favoritePlugins

    local function loadFavoritePlugins()
        if type(readfile) ~= "function" or type(isfile) ~= "function" then return end
        local ok, exists = pcall(isfile, FAVORITE_FILE)
        if not ok or not exists then return end
        local readOk, raw = pcall(readfile, FAVORITE_FILE)
        if not readOk or type(raw) ~= "string" or raw == "" then return end
        local decodeOk, decoded = pcall(function()
            return HttpService:JSONDecode(raw)
        end)
        if decodeOk and type(decoded) == "table" then
            favoritePlugins = decoded
            _G.MasterPluginHub_Favorites = favoritePlugins
        end
    end

    local function saveFavoritePlugins()
        if type(writefile) ~= "function" then return end
        if type(makefolder) == "function" then
            pcall(makefolder, "PluginManager")
            pcall(makefolder, FAVORITE_FOLDER)
        end
        local ok, encoded = pcall(function()
            return HttpService:JSONEncode(favoritePlugins)
        end)
        if ok and type(encoded) == "string" then
            pcall(writefile, FAVORITE_FILE, encoded)
        end
    end

    loadFavoritePlugins()

    -- Kunci Favorite dipisah berdasarkan tab; submenu juga berdasarkan menu induknya.
    local function getMenuFavoriteKey(item, tabName)
        return "menu|" .. tostring(tabName or "") .. "|" .. tostring(item.RawUrl or "") .. "|" .. tostring(item.Name or "")
    end

    local function getSubFavoriteKey(subFeat, parentRawUrl, tabName, parentMenuTitle)
        local rawUrl = (subFeat.RawUrl and subFeat.RawUrl ~= "") and subFeat.RawUrl or parentRawUrl
        return "feature|" .. tostring(tabName or "") .. "|" .. tostring(parentMenuTitle or "") .. "|" ..
            tostring(rawUrl or "") .. "|" .. tostring(subFeat.Cmd or subFeat.Name or "")
    end

    -- Migrasi Favorite lama hanya jika item tersebut unik di seluruh tab.
    -- Jika item lama muncul di beberapa tab, jangan menebak tab mana yang dipilih user.
    local function migrateLegacyFavorites(loaderData)
        if type(loaderData) ~= "table" or type(loaderData.Tabs) ~= "table" then return end
        local matches = {}
        for _, tabInfo in ipairs(loaderData.Tabs) do
            local tabName = tabInfo.Name
            for _, item in ipairs(loaderData[tabInfo.DataKey] or {}) do
                local oldMenuKey = "menu|" .. tostring(item.RawUrl or "") .. "|" .. tostring(item.Name or "")
                local newMenuKey = getMenuFavoriteKey(item, tabName)
                matches[oldMenuKey] = matches[oldMenuKey] or { count = 0, key = newMenuKey }
                matches[oldMenuKey].count = matches[oldMenuKey].count + 1

                for _, subFeat in ipairs(item.SubFeatures or {}) do
                    local rawUrl = (subFeat.RawUrl and subFeat.RawUrl ~= "") and subFeat.RawUrl or item.RawUrl
                    local oldSubKey = "feature|" .. tostring(rawUrl or "") .. "|" ..
                        tostring(subFeat.Cmd or subFeat.Name or "")
                    local newSubKey = getSubFavoriteKey(subFeat, item.RawUrl, tabName, item.Name)
                    matches[oldSubKey] = matches[oldSubKey] or { count = 0, key = newSubKey }
                    matches[oldSubKey].count = matches[oldSubKey].count + 1
                end
            end
        end

        local changed = false
        for oldKey, info in pairs(matches) do
            if info.count == 1 and favoritePlugins[oldKey] == true then
                if favoritePlugins[info.key] == nil then
                    favoritePlugins[info.key] = true
                end
                favoritePlugins[oldKey] = nil
                changed = true
            end
        end
        if changed then saveFavoritePlugins() end
    end

    local function isFavorite(key)
        return favoritePlugins[key] == true
    end

    local function toggleFavorite(key)
        if favoritePlugins[key] == true then
            favoritePlugins[key] = nil
        else
            favoritePlugins[key] = true
        end
        saveFavoritePlugins()
        return favoritePlugins[key] == true
    end


    -- ==========================================================
    local loadedModules = {}
    local loadedPluginVersionShas = {}
    -- PUBLIC VERSION HISTORY (STABLE ONLY)
    -- Every source starts at V0.1 from this rollout baseline.
    -- Later commits affecting that exact file on stable increment it.
    -- ==========================================================
    local VERSION_HISTORY_BASELINES = {
        ["Plugin/Interactable"] = "fce4275585d4547c07d136e93d56ec0b56eac776",
        ["Plugin/colorESP"] = "e8ede9f6b9be9b9db8cdd652767a8519c1a9d0e5",
        ["Plugin/Waypoint"] = "502b56c9511d7cef29bc198e1d3415a4a8a19e0d",
        ["Plugin/PlayerTeleport"] = "d74ac425926ba70324bc40320f5cd2b6c16ebc8a",
        ["Plugin/SoundandView"] = "75f89f5110440e0c9958d8f4cd10c902597c7641",
        ["Plugin/MusicTimeML"] = "f16aad35ed0383eb81b88b3e99a7384e103a15ab",
        ["Plugin/TPitem"] = "f132f123e65c2b0a546dca769042d29360ee3717",
        ["Tools/clickinspector"] = "3e1845a2e48c2f2f272c2ccf223ccd39c1195277",
        ["Tools/AntiAFK"] = "dab262ab6542bbcae55fa2158efae02f81e76f1a",
        ["Plugin/LastRejoin"] = "c279773579cde6d858870f4755d4d58ef6d352c8",
        ["Plugin/SmartRejoin"] = "431bf62301241d39ec0245df9150846e0be8c19b",
        ["Plugin/SimpleAimbot"] = "59f0f72f4f409c34c4527fddbcc6316de7513349",
        ["Plugin/F1Lock"] = "49453083033b894ec6df776ec5fc7b369498c624",
        ["Tools/AntiEffect"] = "fb8b8f928a8a28d11dacd10fd1ea1c86d52c9cd8",
        ["Tools/Fullbright"] = "a6c65cc72ac51da8af544b3eaba59b1b193bee86",
        ["Tools/InstanPrompt"] = "79d1be4f87c503d73342beefbed0c42bff56614f",
        ["Tools/WalkSpeed"] = "e48fe3690404492011ae4c803e6c7130d508f71d",
        ["Tools/InfiniteJump"] = "76721c6781e1571528d177f519b382efe47dd78a",
        ["Tools/AdminDetect"] = "c05cd9b7fab156cdbe04bf9fb4b77e3e20ae1994",
        ["Tools/Noclip"] = "cdb525f8413b898315c9a9d7ebe56aed19957d03",
        ["Tools/CodeFinder"] = "1fbdfc5c06efb2124e5f527542560ada0fc6b8fd"
    }

    -- Manually assigned stable release per plugin path. Set the exact commit SHA when approved.
    -- Example: VERSION_HISTORY_STABLE["Plugin/Waypoint"] = "<40-character-commit-sha>"
    local VERSION_HISTORY_STABLE = {}

    -- Per-user acknowledgement of released stable commits.
    -- A release stays marked UPDATE! until this user has selected that release once.
    local VERSION_PROFILE_FOLDER = "PluginManager/Profiles"
    local VERSION_RELEASE_ACK_FILE = VERSION_PROFILE_FOLDER .. "/" .. tostring(LocalPlayer.UserId) .. "_release_ack.json"
    local acknowledgedReleaseShas = {}
    local function loadAcknowledgedReleases()
        if type(readfile) ~= "function" or type(isfile) ~= "function" then return end
        local ok, exists = pcall(isfile, VERSION_RELEASE_ACK_FILE)
        if not ok or not exists then return end
        local readOk, raw = pcall(readfile, VERSION_RELEASE_ACK_FILE)
        if not readOk or type(raw) ~= "string" or raw == "" then return end
        local decodeOk, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
        if decodeOk and type(decoded) == "table" then acknowledgedReleaseShas = decoded end
    end
    local function saveAcknowledgedReleases()
        if type(writefile) ~= "function" then return end
        if type(makefolder) == "function" then
            pcall(makefolder, "PluginManager")
            pcall(makefolder, VERSION_PROFILE_FOLDER)
        end
        local ok, encoded = pcall(function() return HttpService:JSONEncode(acknowledgedReleaseShas) end)
        if ok and type(encoded) == "string" then pcall(writefile, VERSION_RELEASE_ACK_FILE, encoded) end
    end
    loadAcknowledgedReleases()

    local VERSION_PROFILE_FILE = VERSION_PROFILE_FOLDER .. "/" .. tostring(LocalPlayer.UserId) .. "_versions.json"
    local selectedPluginVersions = {}
    local function loadSelectedPluginVersions()
        if type(readfile) ~= "function" or type(isfile) ~= "function" then return end
        local ok, exists = pcall(isfile, VERSION_PROFILE_FILE)
        if not ok or not exists then return end
        local readOk, raw = pcall(readfile, VERSION_PROFILE_FILE)
        if not readOk or type(raw) ~= "string" or raw == "" then return end
        local decodeOk, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
        if decodeOk and type(decoded) == "table" then selectedPluginVersions = decoded end
    end
    local function saveSelectedPluginVersions()
        if type(writefile) ~= "function" then return end
        if type(makefolder) == "function" then
            pcall(makefolder, "PluginManager")
            pcall(makefolder, VERSION_PROFILE_FOLDER)
        end
        local ok, encoded = pcall(function() return HttpService:JSONEncode(selectedPluginVersions) end)
        if ok and type(encoded) == "string" then pcall(writefile, VERSION_PROFILE_FILE, encoded) end
    end
    loadSelectedPluginVersions()

    local function getPluginSourceBranch(rawUrl)
        local url = tostring(rawUrl or "")
        return url:match("raw%.githubusercontent%.com/Tryofp/Plugin%-Manager/refs/heads/([^/]+)/")
            or url:match("raw%.githubusercontent%.com/Tryofp/Plugin%-Manager/([^/]+)/")
            or "main"
    end

    local function getPluginSourcePath(rawUrl)
        local url = tostring(rawUrl or "")
        local branchPath = url:match("raw%.githubusercontent%.com/Tryofp/Plugin%-Manager/refs/heads/[^/]+/(.+)")
        if branchPath then return branchPath end
        return url:match("raw%.githubusercontent%.com/Tryofp/Plugin%-Manager/[^/]+/(.+)")
    end


    local function requestUserVersionProfile(action, branch, path, commitSha)
        local req = request or http_request or (syn and syn.request)
        if not req then return false, "Executor tidak menyediakan HTTP request." end
        local payload = {
            Type = "UserVersionProfile",
            Action = action,
            UserId = tostring(LocalPlayer.UserId),
            Branch = tostring(branch or "main")
        }
        if path then payload.Path = tostring(path) end
        if commitSha then payload.CommitSha = tostring(commitSha) end

        local ok, response = pcall(function()
            return req({
                Url = SHEETS_WEB_APP_URL,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode(payload)
            })
        end)
        if not ok or not response then return false, tostring(response or "Server tidak merespons.") end
        local body = response.Body or response.body or ""
        local decodeOk, decoded = pcall(function() return HttpService:JSONDecode(body) end)
        if not decodeOk or type(decoded) ~= "table" then
            return false, "Respons server bukan JSON yang valid."
        end
        if decoded.status ~= "success" then return false, tostring(decoded.message or "Server menolak penyimpanan.") end
        return true, decoded
    end

    local function loadServerVersionProfiles()
        if not globalLoaderData then return end
        -- Public release UI only resolves stable sources from main.
        -- Do not merge Beta profiles here: both branches share file paths and
        -- would overwrite each other in the path-keyed client selection table.
        local branches = { "main" }
        local serverVersions = {}

        for _, branch in ipairs(branches) do
            local url = SHEETS_WEB_APP_URL .. "?action=GetUserVersionProfile&userId="
                .. HttpService:UrlEncode(tostring(LocalPlayer.UserId))
                .. "&branch=" .. HttpService:UrlEncode(branch)
                .. "&_=" .. tostring(DateTime.now().UnixTimestampMillis)
            local ok, response = pcall(function() return game:HttpGet(url) end)
            if ok and type(response) == "string" and response ~= "" then
                local decodeOk, decoded = pcall(function() return HttpService:JSONDecode(response) end)
                if decodeOk and type(decoded) == "table" and decoded.status == "success"
                    and type(decoded.versions) == "table" then
                    for path, sha in pairs(decoded.versions) do
                        if type(path) == "string" and type(sha) == "string" and #sha == 40 then
                            serverVersions[path] = sha
                        end
                    end
                end
            end
        end

        -- Server profile wins; local-only selections are migrated to the server.
        for path, sha in pairs(serverVersions) do
            selectedPluginVersions[path] = sha
        end
        -- If profile loading finishes after the stable scan, acknowledge a release
        -- that the user had already selected so UPDATE! does not reappear.
        for path, sha in pairs(selectedPluginVersions) do
            if stableLatestShaCache[path] == sha then
                if acknowledgedReleaseShas[path] ~= sha then
                    acknowledgedReleaseShas[path] = sha
                    saveAcknowledgedReleases()
                end
                releaseUpdateByPath[path] = false
            end
        end
        saveSelectedPluginVersions()

        for path, sha in pairs(selectedPluginVersions) do
            if not serverVersions[path] then
                local branchForPath = "main"
                for _, tabInfo in ipairs(globalLoaderData.Tabs or {}) do
                    for _, item in ipairs(globalLoaderData[tabInfo.DataKey] or {}) do
                        local candidates = item.SubFeatures and #item.SubFeatures > 0 and item.SubFeatures or { item }
                        for _, feature in ipairs(candidates) do
                            local featureUrl = (feature.RawUrl and feature.RawUrl ~= "") and feature.RawUrl or item.RawUrl
                            if getPluginSourcePath(featureUrl) == path then
                                branchForPath = getPluginSourceBranch(featureUrl)
                                break
                            end
                        end
                    end
                end
                requestUserVersionProfile("Save", branchForPath, path, sha)
            end
        end

        if refreshBadgeUI then
            task.defer(refreshBadgeUI)
        end
    end
    -- A parent with mixed child sources uses its most common source for the parent
    -- history arrow. Other source files keep their own arrows inside the submenu.
    local function getPrimarySubFeatureSourceUrl(subFeatures, fallbackUrl)
        if type(subFeatures) ~= "table" then return nil end
        local counts, urls, firstSeen = {}, {}, {}
        for _, feature in ipairs(subFeatures) do
            local featureUrl = (feature.RawUrl and feature.RawUrl ~= "") and feature.RawUrl or fallbackUrl
            local featurePath = getPluginSourcePath(featureUrl)
            if featurePath then
                if not counts[featurePath] then
                    counts[featurePath] = 0
                    urls[featurePath] = featureUrl
                    table.insert(firstSeen, featurePath)
                end
                counts[featurePath] = counts[featurePath] + 1
            end
        end
        local bestPath, bestCount
        for _, path in ipairs(firstSeen) do
            if not bestCount or counts[path] > bestCount then
                bestPath, bestCount = path, counts[path]
            end
        end
        return bestPath and urls[bestPath] or nil
    end

    local function getResolvedPluginUrl(rawUrl)
        local path = getPluginSourcePath(rawUrl)
        local selectedSha = path and tostring(selectedPluginVersions[path] or VERSION_HISTORY_BASELINES[path] or "") or ""
        if selectedSha ~= "" and #selectedSha >= 7 then
            return "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/" .. selectedSha .. "/" .. path
        end
        return rawUrl
    end

    local stableLatestShaCache = {}
    local releaseUpdateByPath = {}
    local releaseStatusCheckStarted = false
    -- Cache paginated history by source path so retries resume at the failed page.
    local stableHistoryCache = {}

    -- Retry short-lived GitHub/API interruptions without duplicating cached commits.
    local function requestGitHubWithRetry(url, attempts)
        attempts = math.max(1, tonumber(attempts) or 3)
        local lastError = nil
        for attempt = 1, attempts do
            local ok, response = pcall(function()
                return game:HttpGet(url)
            end)
            if ok and type(response) == "string" and response ~= "" then return true, response end
            lastError = ok and "Respons GitHub kosong." or tostring(response)
            if attempt < attempts then task.wait(attempt * 1.25) end
        end
        return false, lastError
    end

    local function checkStableReleaseUpdates()
        if releaseStatusCheckStarted or not globalLoaderData then return end
        releaseStatusCheckStarted = true
        task.spawn(function()
            local paths, seen = {}, {}
            for _, tabInfo in ipairs(globalLoaderData.Tabs or {}) do
                for _, item in ipairs(globalLoaderData[tabInfo.DataKey] or {}) do
                    local candidates = type(item.SubFeatures) == "table" and #item.SubFeatures > 0 and item.SubFeatures or {item}
                    for _, feature in ipairs(candidates) do
                        local featureUrl = (feature.RawUrl and feature.RawUrl ~= "") and feature.RawUrl or item.RawUrl
                        local sourcePath = getPluginSourcePath(featureUrl)
                        if sourcePath and VERSION_HISTORY_BASELINES[sourcePath] and not seen[sourcePath] then
                            seen[sourcePath] = true
                            table.insert(paths, sourcePath)
                        end
                    end
                end
            end
            -- Periksa AntiEffect lebih dulu agar badge pengujian muncul tanpa
            -- menunggu seluruh file lain selesai diperiksa.
            table.sort(paths, function(a, b)
                if a == "Tools/AntiEffect" then return true end
                if b == "Tools/AntiEffect" then return false end
                return a < b
            end)
            -- Scan beberapa source secara paralel agar badge tidak menunggu
            -- antrean panjang. Batasi worker agar Apps Script/GitHub tidak dibanjiri.
            local nextPath = 0
            local changed = false
            local function scanWorker()
                while true do
                    nextPath = nextPath + 1
                    local sourcePath = paths[nextPath]
                    if not sourcePath then break end

                    -- Gunakan Apps Script sebagai proxy GitHub terautentikasi.
                    -- Hindari REST API publik langsung dari client Roblox (rate limit 60/jam).
                    local historyUrl = SHEETS_WEB_APP_URL .. "?action=VersionHistory&branch=main&path="
                        .. HttpService:UrlEncode(sourcePath)
                    local ok, response = requestGitHubWithRetry(historyUrl, 3)
                    if ok then
                        local decodeOk, payload = pcall(function() return HttpService:JSONDecode(response) end)
                        local commits = decodeOk and type(payload) == "table" and payload.status == "success"
                            and payload.commits or nil
                        local latest = type(commits) == "table" and commits[1] or nil
                        local latestSha = type(latest) == "table" and tostring(latest.sha or "") or ""
                        if #latestSha == 40 then
                            stableLatestShaCache[sourcePath] = latestSha
                            if selectedPluginVersions[sourcePath] == latestSha and acknowledgedReleaseShas[sourcePath] ~= latestSha then
                                acknowledgedReleaseShas[sourcePath] = latestSha
                                saveAcknowledgedReleases()
                            end
                            releaseUpdateByPath[sourcePath] = latestSha ~= VERSION_HISTORY_BASELINES[sourcePath]
                                and acknowledgedReleaseShas[sourcePath] ~= latestSha
                            changed = true
                            -- Badge diperbarui segera setelah hasil tiap source tersedia.
                            if refreshBadgeUI then task.defer(refreshBadgeUI) end
                        end
                    end
                end
            end

            local workerCount = math.min(4, #paths)
            for worker = 1, workerCount do
                task.spawn(scanWorker)
            end
            if changed and refreshBadgeUI then task.defer(refreshBadgeUI) end
        end)
    end

    local function isPluginSourceActive(path)
        for featureKey, isActive in pairs(featureStates) do
            if isActive then
                local rawUrl = tostring(featureKey):match("^(https://raw%.githubusercontent%.com/Tryofp/Plugin%-Manager/[^_]+)")
                if rawUrl and getPluginSourcePath(rawUrl) == path then return true end
            end
        end
        return false
    end

    local function clearPluginModuleCache(path)
        if not path or isPluginSourceActive(path) then return end
        for cacheKey in pairs(loadedModules) do
            if getPluginSourcePath(cacheKey) == path then loadedModules[cacheKey] = nil end
        end
        loadedPluginVersionShas[path] = nil
    end

    local function isLegacyUpdateBadge(feature)
        local badgeText = string.lower(tostring(feature and feature.BadgeText or ""))
        return string.find(badgeText, "update", 1, true) ~= nil
    end

    local function getUserFacingBadgeText(feature)
        local badgeText = string.lower(tostring(feature and feature.BadgeText or "new"))
        -- UPDATE! is reserved for a newly promoted stable source commit.
        -- Loader metadata may describe an older Beta-side change and must not
        -- independently create a stable release badge.
        if string.find(badgeText, "update", 1, true) then return nil end
        if string.find(badgeText, "new", 1, true) then return "NEW!" end
        return nil
    end

    local function updateHistoryCanvas(scroll)
        if not scroll then return end
        local layout = scroll:FindFirstChildOfClass("UIListLayout")
        if layout then
            scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 8)
        end
    end

    local function attachPublicVersionHistory(card, scrollContainer, rawUrl, displayName, baseHeight, nameLabel, showUpdateDot)
        local path = getPluginSourcePath(rawUrl)
        if not path then return end

        local arrow = Instance.new("TextButton")
        arrow.Name = "PublicVersionHistoryToggle"
        -- Samakan tinggi dengan tombol EXECUTE/OPEN (24 px) dan lebarkan area sentuh.
        arrow.Size = UDim2.new(0, 30, 0, 24)
        arrow.AnchorPoint = Vector2.new(1, 0.5)
        -- Keep the toggle anchored to the original feature row when the history panel expands.
        arrow.Position = UDim2.new(1, -8, 0, baseHeight / 2)
        arrow.ZIndex = (card.ZIndex or 1) + 5
        arrow.BackgroundColor3 = Color3.fromRGB(45, 65, 85)
        arrow.BackgroundTransparency = 0.1
        arrow.BorderSizePixel = 0
        arrow.Font = Enum.Font.GothamBold
        arrow.Text = "▼"
        arrow.TextColor3 = Color3.fromRGB(190, 220, 245)
        arrow.TextSize = 14
        arrow.Parent = card
        Instance.new("UICorner", arrow).CornerRadius = UDim.new(0, 4)

        if showUpdateDot then
            local updateDot = Instance.new("TextLabel")
            updateDot.Name = "VersionUpdateDot"
            updateDot.Size = UDim2.new(0, 10, 0, 10)
            updateDot.AnchorPoint = Vector2.new(0.5, 0.5)
            -- Center the dot directly above the arrow, not at the card's far corner.
            updateDot.Position = UDim2.new(0.5, 0, 0, -4)
            updateDot.BackgroundTransparency = 1
            updateDot.Font = Enum.Font.GothamBold
            updateDot.Text = "•"
            updateDot.TextColor3 = Color3.fromRGB(70, 255, 135)
            updateDot.TextSize = 17
            updateDot.ZIndex = arrow.ZIndex + 2
            updateDot.Parent = arrow
            applyBlinkAnimation(updateDot)
        end

        local panel
        local expanded = false
        card.Destroying:Connect(function()
            if expanded then
                expanded = false
                openPublicHistoryPanels = math.max(0, openPublicHistoryPanels - 1)
                if openPublicHistoryPanels == 0 and pendingPublicBadgeRefresh then
                    pendingPublicBadgeRefresh = false
                    task.defer(function()
                        if refreshBadgeUI then refreshBadgeUI() end
                    end)
                end
            end
        end)

        local function refreshPanel()
            if panel then panel:Destroy() panel = nil end
            panel = Instance.new("Frame")
            panel.Name = "PublicVersionHistoryPanel"
            panel.Position = UDim2.new(0, 6, 0, baseHeight)
            panel.Size = UDim2.new(1, -12, 0, 148)
            panel.BackgroundColor3 = Color3.fromRGB(16, 23, 33)
            panel.BackgroundTransparency = 0.08
            panel.BorderSizePixel = 0
            panel.ZIndex = math.max(1, (card.ZIndex or 1) + 1)
            panel.Parent = card
            Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 5)

            local info = Instance.new("TextLabel")
            info.Size = UDim2.new(1, -12, 0, 18)
            info.Position = UDim2.new(0, 6, 0, 3)
            info.BackgroundTransparency = 1
            info.Font = Enum.Font.GothamBold
            info.Text = "Memuat riwayat stable..."
            info.TextColor3 = Color3.fromRGB(255, 255, 255)
            info.TextTransparency = 0
            info.TextSize = 10
            info.TextStrokeTransparency = 1
            info.TextXAlignment = Enum.TextXAlignment.Left
            info.Parent = panel

            -- Keep connection warnings in their own fully visible row.
            -- Do not append long warning text to the compact version header.
            local warningLabel = Instance.new("TextLabel")
            warningLabel.Name = "GitHubStatusWarning"
            warningLabel.Position = UDim2.new(0, 6, 0, 22)
            warningLabel.Size = UDim2.new(1, -12, 0, 27)
            warningLabel.BackgroundTransparency = 1
            warningLabel.Font = Enum.Font.GothamBold
            warningLabel.Text = ""
            warningLabel.TextColor3 = Color3.fromRGB(255, 220, 105)
            warningLabel.TextTransparency = 0
            warningLabel.TextSize = 10
            warningLabel.TextWrapped = true
            warningLabel.TextXAlignment = Enum.TextXAlignment.Left
            warningLabel.TextYAlignment = Enum.TextYAlignment.Top
            warningLabel.Visible = false
            warningLabel.ZIndex = panel.ZIndex + 2
            warningLabel.Parent = panel

            local historyScroll = Instance.new("ScrollingFrame")
            historyScroll.Name = "VersionRows"
            -- Saat tidak ada pesan peringatan, naikkan daftar agar lebih dekat ke info header.
            -- Ruang tambahan ini juga membuat lebih banyak versi terlihat tanpa perlu scroll.
            historyScroll.Position = UDim2.new(0, 5, 0, 25)
            historyScroll.Size = UDim2.new(1, -10, 1, -30)
            historyScroll.BackgroundTransparency = 1

            local function setHistoryListWarningLayout(showWarning)
                historyScroll.Position = UDim2.new(0, 5, 0, showWarning and 51 or 25)
                historyScroll.Size = UDim2.new(1, -10, 1, showWarning and -56 or -30)
            end
            historyScroll.BorderSizePixel = 0
            historyScroll.ScrollBarThickness = 3
            historyScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
            historyScroll.Parent = panel

            local rowsLayout = Instance.new("UIListLayout")
            rowsLayout.SortOrder = Enum.SortOrder.LayoutOrder
            rowsLayout.Padding = UDim.new(0, 4)
            rowsLayout.Parent = historyScroll

            local baselineSha = VERSION_HISTORY_BASELINES[path]
            task.spawn(function()
                local history = stableHistoryCache[path]
                if not history then
                    history = { commits = {}, nextPage = 1, complete = false }
                    stableHistoryCache[path] = history
                end
                local loadWarning = nil
                local foundBaseline = baselineSha == nil
                for _, entry in ipairs(history.commits) do
                    if baselineSha and tostring(entry.sha or "") == baselineSha then
                        foundBaseline = true
                        break
                    end
                end
                if foundBaseline and baselineSha then history.complete = true end

                -- Ambil halaman tambahan hanya saat baseline belum ditemukan.
                -- Maksimal 10 halaman per pembukaan agar request tetap terkendali.
                local shouldFetch = #history.commits == 0
                    or (baselineSha ~= nil and not foundBaseline and not history.complete)
                if shouldFetch and not history.complete then
                    local page = math.max(1, tonumber(history.nextPage) or 1)
                    while page <= 10 and not history.complete do
                        local historyUrl = SHEETS_WEB_APP_URL .. "?action=VersionHistory&branch=main&path="
                            .. HttpService:UrlEncode(path) .. "&page=" .. tostring(page)
                        local ok, response = requestGitHubWithRetry(historyUrl, 3)
                        if not ok or type(response) ~= "string" or response == "" then
                            loadWarning = "Server Version History belum merespons pada halaman "
                                .. tostring(page) .. ". Buka ulang panah untuk mencoba lagi."
                            break
                        end

                        local decodeOk, payload = pcall(function() return HttpService:JSONDecode(response) end)
                        local decoded = decodeOk and type(payload) == "table" and payload.status == "success"
                            and payload.commits or nil
                        if type(decoded) ~= "table" then
                            loadWarning = "Server Version History gagal mengambil halaman "
                                .. tostring(page) .. ": "
                                .. tostring(type(payload) == "table" and payload.message or "respons tidak valid")
                            break
                        end

                        local knownShas = {}
                        for _, cachedEntry in ipairs(history.commits) do
                            knownShas[tostring(cachedEntry.sha or "")] = true
                        end
                        for _, entry in ipairs(decoded) do
                            local entrySha = tostring(entry.sha or "")
                            if entrySha ~= "" and not knownShas[entrySha] then
                                table.insert(history.commits, entry)
                                knownShas[entrySha] = true
                            end
                            if baselineSha and entrySha == baselineSha then foundBaseline = true end
                        end

                        history.nextPage = page + 1
                        history.complete = #decoded < 30 or foundBaseline
                        page = page + 1
                    end
                end

                local commits = history.commits
                local usedStaticManifest = false
                if #commits == 0 then
                    -- Fallback statis dari GitHub Raw: tidak membutuhkan GitHub REST API.
                    local manifestUrl = "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/main/VersionManifest.json"
                    local manifestOk, manifestResponse = pcall(function() return game:HttpGet(manifestUrl) end)
                    if manifestOk and type(manifestResponse) == "string" and manifestResponse ~= "" then
                        local manifestDecodeOk, manifest = pcall(function() return HttpService:JSONDecode(manifestResponse) end)
                        local item = manifestDecodeOk and type(manifest) == "table" and manifest[path]
                        if type(item) == "table" and type(item.sha) == "string" and #item.sha >= 7 then
                            commits = {{
                                sha = item.sha,
                                commit = {
                                    message = item.message or "Versi terbaru (manifest)",
                                    author = { date = item.date or "Tanggal tidak tersedia" }
                                }
                            }}
                            usedStaticManifest = true
                            stableLatestShaCache[path] = item.sha
                        end
                    end
                    if #commits > 0 then history.commits = commits end
                end
                if not baselineSha and #commits > 0 and not usedStaticManifest then
                    baselineSha = tostring(commits[#commits].sha or "")
                    history.complete = true
                end

                local baselineIndex
                for index, entry in ipairs(commits) do
                    if tostring(entry.sha or "") == baselineSha then baselineIndex = index break end
                end
                if not baselineIndex and not loadWarning then
                    loadWarning = history.complete
                        and "Baseline V0.1 tidak ditemukan di riwayat stable."
                        or "Baseline belum terjangkau. Commit terbaru tetap ditampilkan; buka ulang untuk melanjutkan."
                end

                if #commits == 0 then
                    local activeSha = loadedPluginVersionShas[path]
                    if activeSha == "__STABLE_LATEST__" then
                        info.Text = displayName .. " • versi branch aktif"
                    elseif type(activeSha) == "string" and #activeSha >= 7 then
                        info.Text = displayName .. " • aktif " .. activeSha:sub(1, 7)
                    else
                        info.Text = displayName .. " • versi aktif tidak teridentifikasi"
                    end
                    if loadWarning then
                        warningLabel.Text = loadWarning
                        warningLabel.Visible = true
                    else
                        warningLabel.Text = "Belum ada data riwayat yang dapat ditampilkan."
                        warningLabel.Visible = true
                    end
                    setHistoryListWarningLayout(true)
                    return
                end

                local totalVersions = baselineIndex or #commits
                local latestSha = tostring(commits[1] and commits[1].sha or "")
                stableLatestShaCache[path] = latestSha
                local selectedSha = tostring(selectedPluginVersions[path] or "")
                local loadedSha = loadedPluginVersionShas[path]
                local currentSha = loadedSha == "__STABLE_LATEST__" and latestSha or loadedSha or selectedSha or tostring(VERSION_HISTORY_BASELINES[path] or "")

                info.Text = usedStaticManifest
                    and (displayName .. " • versi manifest main")
                    or (baselineIndex
                        and (displayName .. " • " .. tostring(totalVersions) .. " versi • main")
                        or (displayName .. " • commit terbaru • main"))
                if loadWarning then
                    warningLabel.Text = usedStaticManifest
                        and "API GitHub tidak merespons. Menampilkan versi terbaru dari manifest statis."
                        or loadWarning
                    warningLabel.Visible = true
                elseif usedStaticManifest then
                    warningLabel.Text = "Riwayat lengkap sementara tidak tersedia; versi terbaru tetap bisa dikenali."
                    warningLabel.Visible = true
                end
                setHistoryListWarningLayout(warningLabel.Visible)
                for index = 1, math.min(12, #commits) do
                    local entry = commits[index]
                    local sha = tostring(entry.sha or "")
                    local commitData = entry.commit or {}
                    local author = commitData.author or {}
                    local versionNumber = totalVersions - index + 1
                    local versionName = usedStaticManifest and "Versi terbaru" or (baselineIndex and ("V0." .. tostring(versionNumber)) or ("Commit #" .. tostring(index)))
                    local message = tostring(commitData.message or "Tanpa pesan"):gsub("[\r\n]+", " ")
                    if #message > 58 then message = message:sub(1, 55) .. "..." end

                    local row = Instance.new("Frame")
                    row.Size = UDim2.new(1, -3, 0, 39)
                    row.BackgroundColor3 = Color3.fromRGB(31, 43, 58)
                    row.BackgroundTransparency = 0.08
                    row.BorderSizePixel = 0
                    row.ZIndex = panel.ZIndex + 1
                    row.Parent = historyScroll
                    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 4)

                    -- If this user already selected the latest release before this tracker
                    -- existed, treat it as acknowledged even if no acknowledgement file exists.
                    if index == 1 and selectedPluginVersions[path] == latestSha
                        and acknowledgedReleaseShas[path] ~= latestSha then
                        acknowledgedReleaseShas[path] = latestSha
                        saveAcknowledgedReleases()
                    end
                    local isUpdateAvailable = index == 1
                        and sha ~= baselineSha
                        and acknowledgedReleaseShas[path] ~= sha
                    local isStableVersion = tostring(VERSION_HISTORY_STABLE[path] or "") ~= ""
                        and sha == tostring(VERSION_HISTORY_STABLE[path])

                    local versionLabel = Instance.new("TextLabel")
                    versionLabel.Size = UDim2.new(1, -112, 0, 16)
                    versionLabel.Position = UDim2.new(0, 6, 0, 2)
                    versionLabel.BackgroundTransparency = 1
                    versionLabel.Font = Enum.Font.GothamBold
                    local versionBadges = isStableVersion and "  Stable!" or ""
                    versionLabel.Text = versionName .. versionBadges .. " • " .. message
                    versionLabel.TextColor3 = Color3.fromRGB(225, 235, 245)
                    versionLabel.TextSize = 8
                    versionLabel.TextXAlignment = Enum.TextXAlignment.Left
                    versionLabel.TextTruncate = Enum.TextTruncate.AtEnd
                    versionLabel.ZIndex = row.ZIndex + 1
                    versionLabel.Parent = row

                    if isUpdateAvailable then
                        local updateBadge = Instance.new("TextLabel")
                        updateBadge.Name = "NewReleaseBadge"
                        updateBadge.Size = UDim2.new(0, 46, 0, 13)
                        updateBadge.Position = UDim2.new(1, -52, 0, 3)
                        updateBadge.BackgroundTransparency = 1
                        updateBadge.Font = Enum.Font.GothamBold
                        updateBadge.Text = "UPDATE!"
                        updateBadge.TextColor3 = Color3.fromRGB(80, 235, 145)
                        updateBadge.TextSize = 8
                        updateBadge.ZIndex = row.ZIndex + 2
                        updateBadge.Parent = row
                        local blink = TweenService:Create(
                            updateBadge,
                            TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                            { TextTransparency = 0.8 }
                        )
                        blink:Play()
                    end

                    local detail = Instance.new("TextLabel")
                    detail.Size = UDim2.new(1, -68, 0, 13)
                    detail.Position = UDim2.new(0, 6, 0, 20)
                    detail.BackgroundTransparency = 1
                    detail.Font = Enum.Font.Gotham
                    detail.Text = tostring(author.date or "Tanggal tidak tersedia") .. " • " .. sha:sub(1, 7)
                    detail.TextColor3 = Color3.fromRGB(135, 160, 185)
                    detail.TextSize = 7
                    detail.TextXAlignment = Enum.TextXAlignment.Left
                    detail.ZIndex = row.ZIndex + 1
                    detail.Parent = row

                    if usedStaticManifest or sha == currentSha or sha == selectedSha then
                        local current = Instance.new("TextLabel")
                        current.Size = UDim2.new(0, 54, 0, 12)
                        current.Position = UDim2.new(1, -60, 0, 2)
                        current.BackgroundTransparency = 1
                        current.Font = Enum.Font.GothamBold
                        current.Text = (sha == currentSha or (usedStaticManifest and loadedSha == "__STABLE_LATEST__")) and loadedSha ~= nil and "DIPAKAI" or "DIPILIH"
                        current.TextColor3 = sha == currentSha and loadedSha ~= nil
                            and Color3.fromRGB(100, 235, 155) or Color3.fromRGB(125, 195, 245)
                        current.TextSize = 7
                        current.ZIndex = row.ZIndex + 1
                        current.Parent = row
                    end

                    local choose = Instance.new("TextButton")
                    choose.Size = UDim2.new(0, 54, 0, 19)
                    choose.Position = UDim2.new(1, -60, 0, 18)
                    choose.BackgroundColor3 = Color3.fromRGB(35, 105, 150)
                    choose.BorderSizePixel = 0
                    choose.Font = Enum.Font.GothamBold
                    choose.Text = "PILIH"
                    choose.TextColor3 = Color3.fromRGB(255, 255, 255)
                    choose.TextSize = 8
                    choose.ZIndex = row.ZIndex + 1
                    choose.Parent = row
                    Instance.new("UICorner", choose).CornerRadius = UDim.new(0, 4)
                    choose.MouseButton1Click:Connect(function()
                        selectedPluginVersions[path] = sha
                        saveSelectedPluginVersions()
                        -- Acknowledge a release only when this user actually selects the latest main release.
                        if sha == latestSha then
                            acknowledgedReleaseShas[path] = sha
                            saveAcknowledgedReleases()
                            releaseUpdateByPath[path] = false
                            if refreshBadgeUI then task.defer(refreshBadgeUI) end
                        end
                        local selectedBranch = getPluginSourceBranch(rawUrl)
                        info.Text = versionName .. " dipilih. Menyimpan profil ke server..."
                        task.spawn(function()
                            local saved, result = requestUserVersionProfile("Save", selectedBranch, path, sha)
                            if saved then
                                info.Text = versionName .. " dipilih dan tersimpan di server untuk UserId ini."
                            else
                                info.Text = versionName .. " tersimpan lokal, tetapi sinkronisasi server gagal: " .. tostring(result)
                            end
                        end)
                        -- Keep an active module cached so its UNEXECUTE command can still clean up.
                        -- Inactive modules are invalidated immediately and use the selected SHA next time.
                        clearPluginModuleCache(path)
                        info.Text = versionName .. " dipilih. Jalankan ulang fitur untuk memuat source ini."
                        refreshPanel()
                    end)
                end
                updateHistoryCanvas(historyScroll)
            end)
        end

        arrow.MouseButton1Click:Connect(function()
            expanded = not expanded
            if expanded then
                openPublicHistoryPanels = openPublicHistoryPanels + 1
                arrow.Text = "▲"
                -- User version profiles are only needed when this feature is opened.
                if not serverVersionProfilesLoadStarted then
                    serverVersionProfilesLoadStarted = true
                    task.spawn(loadServerVersionProfiles)
                end
                refreshPanel()
                card.Size = UDim2.new(1, 0, 0, baseHeight + 152)
            else
                openPublicHistoryPanels = math.max(0, openPublicHistoryPanels - 1)
                arrow.Text = "▼"
                if panel then panel:Destroy() panel = nil end
                card.Size = UDim2.new(1, 0, 0, baseHeight)
                if openPublicHistoryPanels == 0 and pendingPublicBadgeRefresh then
                    pendingPublicBadgeRefresh = false
                    task.defer(refreshBadgeUI)
                end
            end
            task.defer(function() updateHistoryCanvas(scrollContainer) end)
        end)
        return true
    end

    local loadedModuleFingerprints = {}
    local stableFixPrompted = {}
    local stableFixPromptActive = false
    -- Forward declaration: the stable prompt is defined before the Health Check UI.
    local HealthCheckInfo

    -- Fingerprint is only a lightweight content comparison, not a security hash.
    local function getPluginSourceFingerprint(source)
        local fingerprint = 0
        for index = 1, #source do
            fingerprint = (fingerprint * 131 + string.byte(source, index)) % 2147483647
        end
        return tostring(#source) .. ":" .. tostring(fingerprint)
    end

    -- Keep the exact source fingerprint used to create each cached module.
    local function loadPluginModule(rawUrl)
        local resolvedUrl = getResolvedPluginUrl(rawUrl)
        local source = game:HttpGet(resolvedUrl)
        if type(source) ~= "string" or source == "" then
            error("Source plugin kosong atau gagal diunduh: " .. tostring(resolvedUrl))
        end
        local compiled, compileError = loadstring(source)
        if type(compiled) ~= "function" then
            error("Gagal compile plugin: " .. tostring(compileError))
        end
        local module = compiled()
        local sourcePath = getPluginSourcePath(rawUrl)
        if sourcePath then
            loadedPluginVersionShas[sourcePath] = selectedPluginVersions[sourcePath] or VERSION_HISTORY_BASELINES[sourcePath] or "__STABLE_LATEST__"
        end
        loadedModuleFingerprints[tostring(resolvedUrl):match("^[^?]+") or tostring(resolvedUrl)] = getPluginSourceFingerprint(source)
        loadedModuleFingerprints[tostring(rawUrl):match("^[^?]+") or tostring(rawUrl)] = getPluginSourceFingerprint(source)
        return module
    end

    local function showStableFixPrompt(pluginName, commandName, sourceUrl, latestSource)
        if stableFixPromptActive then return end
        local gui = CoreGui:FindFirstChild("MasterPluginHub")
        if not gui then return end

        stableFixPromptActive = true
        local prompt = Instance.new("Frame")
        prompt.Name = "StableFixAvailablePrompt"
        prompt.Size = UDim2.new(0, 248, 0, 112)
        prompt.Position = UDim2.new(0.5, -124, 0.5, -56)
        prompt.BackgroundColor3 = Color3.fromRGB(25, 33, 45)
        prompt.BorderSizePixel = 0
        prompt.ZIndex = 100
        prompt.Parent = gui
        Instance.new("UICorner", prompt).CornerRadius = UDim.new(0, 7)

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -16, 0, 22)
        title.Position = UDim2.new(0, 8, 0, 6)
        title.BackgroundTransparency = 1
        title.Font = Enum.Font.GothamBold
        title.Text = "PERBAIKAN STABLE TERSEDIA"
        title.TextColor3 = Color3.fromRGB(100, 230, 150)
        title.TextSize = 10
        title.ZIndex = 101
        title.Parent = prompt

        local detail = Instance.new("TextLabel")
        detail.Size = UDim2.new(1, -16, 0, 34)
        detail.Position = UDim2.new(0, 8, 0, 29)
        detail.BackgroundTransparency = 1
        detail.Font = Enum.Font.Gotham
        detail.Text = tostring(pluginName) .. " / " .. tostring(commandName)
            .. "\nSource stable berubah. Muat ulang source untuk mencoba versi terbaru."
        detail.TextColor3 = Color3.fromRGB(205, 215, 228)
        detail.TextSize = 8
        detail.TextWrapped = true
        detail.TextXAlignment = Enum.TextXAlignment.Left
        detail.ZIndex = 101
        detail.Parent = prompt

        local reloadButton = Instance.new("TextButton")
        reloadButton.Size = UDim2.new(0.58, -6, 0, 26)
        reloadButton.Position = UDim2.new(0, 8, 1, -34)
        reloadButton.BackgroundColor3 = Color3.fromRGB(0, 145, 95)
        reloadButton.BorderSizePixel = 0
        reloadButton.Font = Enum.Font.GothamBold
        reloadButton.Text = "MUAT ULANG HUB"
        reloadButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        reloadButton.TextSize = 8
        reloadButton.ZIndex = 101
        reloadButton.Parent = prompt
        Instance.new("UICorner", reloadButton).CornerRadius = UDim.new(0, 4)

        local laterButton = Instance.new("TextButton")
        laterButton.Size = UDim2.new(0.42, -6, 0, 26)
        laterButton.Position = UDim2.new(0.58, 2, 1, -34)
        laterButton.BackgroundColor3 = Color3.fromRGB(65, 76, 92)
        laterButton.BorderSizePixel = 0
        laterButton.Font = Enum.Font.GothamBold
        laterButton.Text = "NANTI"
        laterButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        laterButton.TextSize = 8
        laterButton.ZIndex = 101
        laterButton.Parent = prompt
        Instance.new("UICorner", laterButton).CornerRadius = UDim.new(0, 4)

        laterButton.MouseButton1Click:Connect(function()
            prompt:Destroy()
            stableFixPromptActive = false
        end)

        reloadButton.Text = "MUAT ULANG SOURCE"
        reloadButton.MouseButton1Click:Connect(function()
            reloadButton.Text = "MEMUAT..."
            reloadButton.Active = false
            task.spawn(function()
                local ok, err = pcall(function()
                    local chunk, compileError = loadstring(latestSource)
                    if type(chunk) ~= "function" then
                        error("Source stable gagal di-compile: " .. tostring(compileError))
                    end
                    local updatedModule = chunk()
                    if type(updatedModule) ~= "table" or type(updatedModule.Commands) ~= "table" then
                        error("Source terbaru tidak menghasilkan modul Commands yang valid.")
                    end

                    loadedModules[sourceUrl] = updatedModule
                    loadedModuleFingerprints[sourceUrl] = getPluginSourceFingerprint(latestSource)

                    -- Reset only the failed feature's toggle state so its next
                    -- EXECUTE click uses the refreshed command, not stale UNEXECUTE.
                    local data = globalLoaderData
                    if type(data) == "table" then
                        for _, tabInfo in ipairs(data.Tabs or {}) do
                            local list = type(tabInfo) == "table" and data[tabInfo.DataKey] or nil
                            if type(list) == "table" then
                                for _, item in ipairs(list) do
                                    if type(item) == "table" then
                                        local candidates = type(item.SubFeatures) == "table" and #item.SubFeatures > 0
                                            and item.SubFeatures or {item}
                                        for _, feature in ipairs(candidates) do
                                            if type(feature) == "table" then
                                                local featureUrl = tostring((feature.RawUrl and feature.RawUrl ~= "")
                                                    and feature.RawUrl or item.RawUrl or "")
                                                if featureUrl == sourceUrl
                                                    and (tostring(feature.Cmd or "") == tostring(commandName)
                                                        or tostring(feature.UnCmd or "") == tostring(commandName)) then
                                                    local featureKey = featureUrl .. "_" .. tostring(feature.Cmd or "")
                                                    featureStates[featureKey] = false
                                                    for _, button in ipairs(activeButtons[featureKey] or {}) do
                                                        if button and button.Parent then
                                                            button.Text = "EXECUTE"
                                                            button.BackgroundColor3 = Color3.fromRGB(0, 150, 90)
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                    prompt:Destroy()
                    stableFixPromptActive = false
                    if HealthCheckInfo and HealthCheckInfo.Parent then
                        HealthCheckInfo.Text = "BERHASIL: source stable terbaru sudah diunduh, di-compile, divalidasi, dan cache module diperbarui. Fitur yang sedang berjalan tidak otomatis di-restart; tekan EXECUTE untuk menjalankan versi terbaru."
                    end
                end)
                if not ok then
                    reloadButton.Text = "GAGAL - COBA LAGI"
                    reloadButton.Active = true
                    warn("[Plugin Manager] Gagal memuat source stable terbaru: " .. tostring(err))
                    if HealthCheckInfo and HealthCheckInfo.Parent then
                        HealthCheckInfo.Text = "GAGAL memuat source stable: " .. tostring(err)
                    end
                end
            end)
        end)
    end

    local function checkStableFixAvailable(pluginName, commandName, sourceUrl, forcePrompt)
        local normalizedUrl = tostring(sourceUrl or ""):match("^[^?]+") or ""
        local loadedFingerprint = loadedModuleFingerprints[normalizedUrl]
        if not loadedFingerprint then return end

        local path = normalizedUrl:match("^https://raw%.githubusercontent%.com/Tryofp/Plugin%-Manager/refs/heads/main/(.+)$")
            or normalizedUrl:match("^https://raw%.githubusercontent%.com/Tryofp/Plugin%-Manager/main/(.+)$")
        if not path then return end
        -- A manually selected historical version is intentional; use its UPDATE! badge
        -- instead of silently offering to replace it with moving stable source.
        if selectedPluginVersions[path] then return end

        local latestUrl = "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/main/" .. path
        local ok, latestSource = pcall(function() return game:HttpGet(latestUrl) end)
        if not ok or type(latestSource) ~= "string" or latestSource == "" then return end

        local latestFingerprint = getPluginSourceFingerprint(latestSource)
        if latestFingerprint == loadedFingerprint then return end

        local promptKey = latestUrl .. "|" .. latestFingerprint
        if stableFixPrompted[promptKey] and not forcePrompt then return end
        stableFixPrompted[promptKey] = true
        showStableFixPrompt(pluginName, commandName, latestUrl, latestSource)
    end

    -- Anonymous, non-blocking runtime reports. Detached plugin tasks may not be attributable.
    -- Keep the 60-second duplicate-report cooldown across MasterWindow reopens.
    -- Recreating the UI must not reset the same runtime error's reporting window.
    local runtimeErrorLastSent = _G.MasterPluginHub_RuntimeErrorLastSent
    if type(runtimeErrorLastSent) ~= "table" then
        runtimeErrorLastSent = {}
        _G.MasterPluginHub_RuntimeErrorLastSent = runtimeErrorLastSent
    end
    local function reportPluginRuntimeError(pluginName, commandName, sourceUrl, errorMessage)
        local plugin = tostring(pluginName or "Unknown Plugin"):sub(1, 120)
        local command = tostring(commandName or "Unknown Command"):sub(1, 100)
        local source = tostring(sourceUrl or ""):sub(1, 500)
        local errText = tostring(errorMessage or "Unknown runtime error"):sub(1, 1500)
        local fingerprint = plugin .. "|" .. command .. "|" .. errText
        local now = os.clock()
        if runtimeErrorLastSent[fingerprint] and now - runtimeErrorLastSent[fingerprint] < 60 then return end
        runtimeErrorLastSent[fingerprint] = now

        task.spawn(function()
            pcall(function()
                local req = request or http_request or (syn and syn.request)
                if type(req) ~= "function" then return end
                local body = HttpService:JSONEncode({
                    Type = "PluginRuntimeError",
                    Plugin = plugin,
                    Command = command,
                    Source = source,
                    Error = errText,
                    PlaceId = tostring(game.PlaceId)
                })
                req({
                    Url = SHEETS_WEB_APP_URL,
                    Method = "POST",
                    Headers = { ["Content-Type"] = "application/json" },
                    Body = body
                })
            end)
        end)

        -- Only offer a fix when the published stable source differs from the
        -- exact source currently cached in this session.
        task.spawn(function()
            pcall(checkStableFixAvailable, plugin, command, source)
        end)
    end

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
    TitleLabel.Size = UDim2.new(1, -120, 1, 0)
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

    local FeedbackBtn = Instance.new("TextButton")
    FeedbackBtn.Size = UDim2.new(0, 58, 0, 20)
    FeedbackBtn.Position = UDim2.new(1, -112, 0, 5)
    FeedbackBtn.BackgroundColor3 = Color3.fromRGB(0, 125, 155)
    FeedbackBtn.BorderSizePixel = 0
    FeedbackBtn.Font = Enum.Font.GothamBold
    FeedbackBtn.Text = "FEEDBACK"
    FeedbackBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    FeedbackBtn.TextSize = 8
    FeedbackBtn.ZIndex = 11
    FeedbackBtn.Parent = TopBar
    Instance.new("UICorner", FeedbackBtn).CornerRadius = UDim.new(0, 4)

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
            -- Metadata snapshot is shared-cached server-side; polling once per minute
            -- keeps badge changes responsive without hammering Firestore.
            task.wait(60)

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


    local feedbackCategories = { "Bug Report", "Feature Request", "Suggestion", "Other" }
    local function openFeedbackDialog()
        local existing = Frame:FindFirstChild("FeedbackOverlay")
        if existing then existing:Destroy() end

        local Overlay = Instance.new("Frame")
        Overlay.Name = "FeedbackOverlay"
        Overlay.Size = UDim2.new(1, 0, 1, 0)
        Overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        Overlay.BackgroundTransparency = 0.35
        Overlay.BorderSizePixel = 0
        Overlay.ZIndex = 50
        Overlay.Parent = Frame

        local Modal = Instance.new("Frame")
        Modal.Size = UDim2.new(1, -24, 0, 286)
        Modal.Position = UDim2.new(0, 12, 0.5, -143)
        Modal.BackgroundColor3 = Color3.fromRGB(25, 32, 42)
        Modal.BorderSizePixel = 0
        Modal.ZIndex = 51
        Modal.Parent = Overlay
        Instance.new("UICorner", Modal).CornerRadius = UDim.new(0, 7)

        local function makeLabel(name, text, position, size, textSize, color)
            local label = Instance.new("TextLabel")
            label.Name = name
            label.Position = position
            label.Size = size
            label.BackgroundTransparency = 1
            label.Font = Enum.Font.GothamBold
            label.Text = text
            label.TextColor3 = color or Color3.fromRGB(225, 235, 245)
            label.TextSize = textSize or 10
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.ZIndex = 52
            label.Parent = Modal
            return label
        end

        makeLabel("Title", "KIRIM FEEDBACK", UDim2.new(0, 10, 0, 8), UDim2.new(1, -45, 0, 22), 12, Color3.fromRGB(0, 220, 255))

        local Close = Instance.new("TextButton")
        Close.Size = UDim2.new(0, 22, 0, 22)
        Close.Position = UDim2.new(1, -31, 0, 7)
        Close.BackgroundColor3 = Color3.fromRGB(170, 55, 55)
        Close.BorderSizePixel = 0
        Close.Font = Enum.Font.GothamBold
        Close.Text = "X"
        Close.TextColor3 = Color3.fromRGB(255, 255, 255)
        Close.TextSize = 10
        Close.ZIndex = 53
        Close.Parent = Modal
        Instance.new("UICorner", Close).CornerRadius = UDim.new(0, 4)

        makeLabel("CategoryLabel", "Kategori", UDim2.new(0, 10, 0, 36), UDim2.new(0.5, -14, 0, 16), 9)
        local categoryIndex = 1
        local CategoryBtn = Instance.new("TextButton")
        CategoryBtn.Size = UDim2.new(0.5, -14, 0, 25)
        CategoryBtn.Position = UDim2.new(0, 10, 0, 53)
        CategoryBtn.BackgroundColor3 = Color3.fromRGB(40, 55, 72)
        CategoryBtn.BorderSizePixel = 0
        CategoryBtn.Font = Enum.Font.GothamBold
        CategoryBtn.Text = feedbackCategories[categoryIndex] .. "  ▾"
        CategoryBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        CategoryBtn.TextSize = 9
        CategoryBtn.ZIndex = 52
        CategoryBtn.Parent = Modal
        Instance.new("UICorner", CategoryBtn).CornerRadius = UDim.new(0, 4)

        makeLabel("RatingLabel", "Rating", UDim2.new(0.5, 4, 0, 36), UDim2.new(0.5, -14, 0, 16), 9)
        local rating = 5
        local RatingBtn = Instance.new("TextButton")
        RatingBtn.Size = UDim2.new(0.5, -14, 0, 25)
        RatingBtn.Position = UDim2.new(0.5, 4, 0, 53)
        RatingBtn.BackgroundColor3 = Color3.fromRGB(75, 62, 30)
        RatingBtn.BorderSizePixel = 0
        RatingBtn.Font = Enum.Font.GothamBold
        RatingBtn.Text = "★★★★★  5/5"
        RatingBtn.TextColor3 = Color3.fromRGB(255, 220, 90)
        RatingBtn.TextSize = 9
        RatingBtn.ZIndex = 52
        RatingBtn.Parent = Modal
        Instance.new("UICorner", RatingBtn).CornerRadius = UDim.new(0, 4)

        CategoryBtn.MouseButton1Click:Connect(function()
            categoryIndex = categoryIndex % #feedbackCategories + 1
            CategoryBtn.Text = feedbackCategories[categoryIndex] .. "  ▾"
        end)
        RatingBtn.MouseButton1Click:Connect(function()
            rating = rating % 5 + 1
            RatingBtn.Text = string.rep("★", rating) .. string.rep("☆", 5 - rating) .. "  " .. rating .. "/5"
        end)

        makeLabel("MessageLabel", "Pesan (8–1.500 karakter)", UDim2.new(0, 10, 0, 86), UDim2.new(1, -20, 0, 16), 9)
        local MessageBox = Instance.new("TextBox")
        MessageBox.Size = UDim2.new(1, -20, 0, 104)
        MessageBox.Position = UDim2.new(0, 10, 0, 104)
        MessageBox.BackgroundColor3 = Color3.fromRGB(13, 18, 25)
        MessageBox.BorderSizePixel = 0
        MessageBox.ClearTextOnFocus = false
        MessageBox.MultiLine = true
        MessageBox.TextWrapped = true
        MessageBox.TextXAlignment = Enum.TextXAlignment.Left
        MessageBox.TextYAlignment = Enum.TextYAlignment.Top
        MessageBox.Font = Enum.Font.Gotham
        MessageBox.Text = ""
        MessageBox.PlaceholderText = "Tulis bug, saran, atau ide lu di sini..."
        MessageBox.PlaceholderColor3 = Color3.fromRGB(115, 130, 148)
        MessageBox.TextColor3 = Color3.fromRGB(240, 245, 250)
        MessageBox.TextSize = 10
        MessageBox.ZIndex = 52
        MessageBox.Parent = Modal
        Instance.new("UICorner", MessageBox).CornerRadius = UDim.new(0, 4)

        local Status = makeLabel("Status", "", UDim2.new(0, 10, 0, 212), UDim2.new(1, -20, 0, 25), 8, Color3.fromRGB(170, 190, 205))
        Status.TextWrapped = true

        local Submit = Instance.new("TextButton")
        Submit.Size = UDim2.new(0.5, -15, 0, 25)
        Submit.Position = UDim2.new(0, 10, 0, 250)
        Submit.BackgroundColor3 = Color3.fromRGB(0, 145, 90)
        Submit.BorderSizePixel = 0
        Submit.Font = Enum.Font.GothamBold
        Submit.Text = "SUBMIT"
        Submit.TextColor3 = Color3.fromRGB(255, 255, 255)
        Submit.TextSize = 9
        Submit.ZIndex = 52
        Submit.Parent = Modal
        Instance.new("UICorner", Submit).CornerRadius = UDim.new(0, 4)

        local Cancel = Instance.new("TextButton")
        Cancel.Size = UDim2.new(0.5, -15, 0, 25)
        Cancel.Position = UDim2.new(0.5, 5, 0, 250)
        Cancel.BackgroundColor3 = Color3.fromRGB(65, 75, 90)
        Cancel.BorderSizePixel = 0
        Cancel.Font = Enum.Font.GothamBold
        Cancel.Text = "TUTUP"
        Cancel.TextColor3 = Color3.fromRGB(255, 255, 255)
        Cancel.TextSize = 9
        Cancel.ZIndex = 52
        Cancel.Parent = Modal
        Instance.new("UICorner", Cancel).CornerRadius = UDim.new(0, 4)

        Close.MouseButton1Click:Connect(function() Overlay:Destroy() end)
        Cancel.MouseButton1Click:Connect(function() Overlay:Destroy() end)

        Submit.MouseButton1Click:Connect(function()
            local message = tostring(MessageBox.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
            if #message < 8 or #message > 1500 then
                Status.Text = "Pesan harus 8–1.500 karakter."
                Status.TextColor3 = Color3.fromRGB(255, 175, 100)
                return
            end

            local req = request or http_request or (syn and syn.request)
            if type(req) ~= "function" then
                Status.Text = "Executor tidak menyediakan HTTP request."
                Status.TextColor3 = Color3.fromRGB(255, 120, 120)
                return
            end

            Submit.Active = false
            Submit.AutoButtonColor = false
            Submit.Text = "MENGIRIM..."
            Status.Text = "Mengirim feedback..."
            Status.TextColor3 = Color3.fromRGB(170, 190, 205)

            task.spawn(function()
                local requestId = HttpService:GenerateGUID(false)
                local payload = HttpService:JSONEncode({
                    Type = "Feedback",
                    RequestId = requestId,
                    Username = LocalPlayer.Name,
                    UserId = tostring(LocalPlayer.UserId),
                    Category = feedbackCategories[categoryIndex],
                    Rating = rating,
                    Message = message,
                    Device = getDeviceType(),
                    PlaceId = tostring(game.PlaceId),
                    PlaceName = tostring(game.Name or "Unknown Game")
                })

                -- Apps Script ContentService responds through a 302 redirect.
                -- Keep the POST intact, then fetch the redirected JSON URL with GET.
                local requestOk, response = pcall(function()
                    return req({
                        Url = SHEETS_WEB_APP_URL,
                        Method = "POST",
                        Headers = { ["Content-Type"] = "application/json" },
                        FollowRedirects = false,
                        Body = payload
                    })
                end)

                local function getHeader(headers, wanted)
                    if type(headers) ~= "table" then return nil end
                    for key, value in pairs(headers) do
                        if string.lower(tostring(key)) == string.lower(wanted) then
                            return tostring(value)
                        end
                    end
                    return nil
                end

                local responseCode = response and (response.StatusCode or response.Status or response.status_code)
                local responseHeaders = response and (response.Headers or response.headers)
                local redirectUrl = getHeader(responseHeaders, "Location")
                if requestOk and response and redirectUrl and
                    (tonumber(responseCode) == 301 or tonumber(responseCode) == 302 or
                     tonumber(responseCode) == 303 or tonumber(responseCode) == 307 or
                     tonumber(responseCode) == 308) then
                    requestOk, response = pcall(function()
                        return req({
                            Url = redirectUrl,
                            Method = "GET",
                            FollowRedirects = true
                        })
                    end)
                end

                local decoded
                local responseBody = ""
                if requestOk and response then
                    responseBody = response.Body or response.body or ""
                    responseCode = response.StatusCode or response.Status or response.status_code
                    local decodeOk, result = pcall(function() return HttpService:JSONDecode(responseBody) end)
                    if decodeOk and type(result) == "table" then decoded = result end
                end

                -- Some executors turn the Apps Script ContentService POST redirect into HTTP 405
                -- even though doPost has already saved the feedback. Confirm via a read-only GET.
                if not decoded and tonumber(responseCode) == 405 then
                    local statusOk, statusResponse = pcall(function()
                        return req({
                            Url = SHEETS_WEB_APP_URL .. "?action=FeedbackStatus&requestId=" .. requestId,
                            Method = "GET",
                            FollowRedirects = true
                        })
                    end)
                    if statusOk and statusResponse then
                        local statusBody = statusResponse.Body or statusResponse.body or ""
                        local statusDecodeOk, statusResult = pcall(function()
                            return HttpService:JSONDecode(statusBody)
                        end)
                        if statusDecodeOk and type(statusResult) == "table" then
                            decoded = statusResult
                        end
                    end
                end

                if not Overlay.Parent then return end
                if decoded and decoded.status == "success" then
                    Submit.Text = "TERKIRIM"
                    Submit.BackgroundColor3 = Color3.fromRGB(0, 115, 75)
                    Status.Text = decoded.notificationSent
                        and "Feedback tersimpan dan notifikasi terkirim!"
                        or ("Feedback tersimpan. ntfy: " .. tostring(decoded.notificationError or "belum terkirim"))
                    Status.TextColor3 = Color3.fromRGB(100, 235, 155)
                    MessageBox.Text = ""
                else
                    Submit.Active = true
                    Submit.AutoButtonColor = true
                    Submit.Text = "COBA LAGI"
                    if decoded then
                        Status.Text = tostring(decoded.message or "Server menolak feedback.")
                    elseif not requestOk then
                        Status.Text = "Request gagal: " .. tostring(response):sub(1, 110)
                    elseif not response then
                        Status.Text = "Server tidak mengembalikan respons."
                    elseif responseCode then
                        Status.Text = "Respons server bukan JSON (HTTP " .. tostring(responseCode) .. ")."
                    else
                        Status.Text = "Respons server bukan JSON atau redirect gagal."
                    end
                    Status.TextColor3 = Color3.fromRGB(255, 130, 120)
                end
            end)
        end)
    end

    FeedbackBtn.MouseButton1Click:Connect(openFeedbackDialog)

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

    local currentSubMenuTitle, currentSubMenuRawUrl, currentSubMenuFeatures, currentSubMenuTabName
    local function showSubMenu(menuTitle, rawUrl, subFeatures, tabName)
        currentSubMenuTitle, currentSubMenuRawUrl, currentSubMenuFeatures, currentSubMenuTabName =
            menuTitle, rawUrl, subFeatures, tabName
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

        local parentSourcePath = getPluginSourcePath(rawUrl)
            or getPluginSourcePath(getPrimarySubFeatureSourceUrl(subFeatures, rawUrl))
        local subSourcePaths, subPathSeen = {}, {}
        for _, feature in ipairs(subFeatures) do
            local featureUrl = (feature.RawUrl and feature.RawUrl ~= "") and feature.RawUrl or rawUrl
            local featurePath = getPluginSourcePath(featureUrl)
            if featurePath and not subPathSeen[featurePath] then
                subPathSeen[featurePath] = true
                table.insert(subSourcePaths, featurePath)
            end
        end
        local allSubFeaturesShareParentSource = parentSourcePath ~= nil and #subSourcePaths == 1
            and subSourcePaths[1] == parentSourcePath

        local orderedSubFeatures = {}
        for index, feature in ipairs(subFeatures) do
            table.insert(orderedSubFeatures, { item = feature, index = index })
        end
        table.sort(orderedSubFeatures, function(a, b)
            local aFav = isFavorite(getSubFavoriteKey(a.item, rawUrl, tabName, menuTitle))
            local bFav = isFavorite(getSubFavoriteKey(b.item, rawUrl, tabName, menuTitle))
            if aFav ~= bFav then return aFav end
            return a.index < b.index
        end)

        for _, subEntry in ipairs(orderedSubFeatures) do
            local subFeat = subEntry.item
            local subRawUrl = (subFeat.RawUrl and subFeat.RawUrl ~= "") and subFeat.RawUrl or rawUrl
            local subSourcePath = getPluginSourcePath(subRawUrl)
            local hasSubUpdateBadge = subSourcePath and releaseUpdateByPath[subSourcePath] == true or false
            local uniqueKey = tostring(subRawUrl) .. "_" .. tostring(subFeat.Cmd)
            if featureStates[uniqueKey] == nil then featureStates[uniqueKey] = false end

            local Item = Instance.new("Frame")
            Item.BackgroundColor3 = Color3.fromRGB(25, 32, 42)
            Item.BackgroundTransparency = 0.35
            Item.BorderSizePixel = 0
            Item.Parent = SubScroll
            Instance.new("UICorner", Item).CornerRadius = UDim.new(0, 4)

            local LblName = Instance.new("TextLabel")
            LblName.Size = UDim2.new(1, -118, 0, 18)
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
            local activeBadgeText = getUserFacingBadgeText(subFeat)
            local activeBadgeColor = getColorFromName(subFeat.BadgeColor)
            local isMaintenance = (not subFeat.Cmd or subFeat.Cmd == "") or isFeatureInMaintenance(subFeat)

            if isMaintenance then
                activeBadgeText = "MAINTENANCE!"
                activeBadgeColor = Color3.fromRGB(255, 60, 60)
            elseif hasSubUpdateBadge then
                activeBadgeText = "UPDATE!"
                activeBadgeColor = Color3.fromRGB(80, 235, 145)
            end

            if (activeBadgeText and isFeatureNew(badgeKey, timestamp)) or hasSubUpdateBadge or isMaintenance then
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
            LblDesc.Size = UDim2.new(1, -118, 0, descHeight)
            Item.Size = UDim2.new(1, 0, 0, descHeight + 28)

            local subHasHistory = false
            if subSourcePath and not allSubFeaturesShareParentSource then
                local firstSubPath = true
                for priorIndex = 1, subEntry.index - 1 do
                    local prior = subFeatures[priorIndex]
                    local priorUrl = (prior.RawUrl and prior.RawUrl ~= "") and prior.RawUrl or rawUrl
                    if getPluginSourcePath(priorUrl) == subSourcePath then
                        firstSubPath = false
                        break
                    end
                end
                if firstSubPath and subSourcePath ~= parentSourcePath then
                    subHasHistory = attachPublicVersionHistory(Item, SubScroll, subRawUrl,
                        tostring(subFeat.Name or subSourcePath), descHeight + 28, LblName, hasSubUpdateBadge) == true
                end
            end

            local SubFavoriteBtn = Instance.new("TextButton")
            SubFavoriteBtn.Size = UDim2.new(0, 22, 0, 22)
            SubFavoriteBtn.AnchorPoint = Vector2.new(0, 0.5)
            SubFavoriteBtn.Position = UDim2.new(1, subHasHistory and -122 or -108, 0.5, 0)
            SubFavoriteBtn.BackgroundTransparency = 1
            SubFavoriteBtn.BorderSizePixel = 0
            SubFavoriteBtn.Font = Enum.Font.GothamBold
            SubFavoriteBtn.TextSize = 18
            SubFavoriteBtn.Text = isFavorite(getSubFavoriteKey(subFeat, rawUrl, tabName, menuTitle)) and "★" or "☆"
            SubFavoriteBtn.TextColor3 = isFavorite(getSubFavoriteKey(subFeat, rawUrl, tabName, menuTitle))
                and Color3.fromRGB(255, 205, 55) or Color3.fromRGB(135, 145, 160)
            SubFavoriteBtn.Parent = Item
            SubFavoriteBtn.MouseButton1Click:Connect(function()
                toggleFavorite(getSubFavoriteKey(subFeat, rawUrl, tabName, menuTitle))
                showSubMenu(menuTitle, rawUrl, subFeatures, tabName)
            end)

            local ExecSub = Instance.new("TextButton")
            ExecSub.Size = UDim2.new(0, subHasHistory and 58 or 75, 0, 24)
            ExecSub.AnchorPoint = Vector2.new(0, 0.5)
            ExecSub.Position = UDim2.new(1, subHasHistory and -100 or -80, 0.5, 0)
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
                        local commandOk, commandErr = xpcall(function()
                            local targetRaw = subRawUrl
                            if not loadedModules[targetRaw] then
                                loadedModules[targetRaw] = loadPluginModule(targetRaw)
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
                                if foundFunc then
                                    task.spawn(function()
                                        local ok, err = xpcall(function() foundFunc(customArgs or {}, speaker) end, function(e) return debug.traceback(tostring(e), 2) end)
                                        if not ok then reportPluginRuntimeError(subFeat.Name, isUnexec and (subFeat.UnCmd or subFeat.Cmd) or subFeat.Cmd, targetRaw, err) end
                                    end)
                                else
                                    error("Command function tidak ditemukan: " .. tostring(targetCmd))
                                end
                            else
                                error("Modul plugin tidak memiliki tabel Commands: " .. tostring(subFeat.Name))
                            end
                        end, function(err) return debug.traceback(tostring(err), 2) end)
                                if not commandOk then
                                    reportPluginRuntimeError(subFeat.Name, isUnexec and (subFeat.UnCmd or subFeat.Cmd) or subFeat.Cmd, subRawUrl, commandErr)
                                end

                        local hasUnCmd = (subFeat.UnCmd and subFeat.UnCmd ~= "")
                            or string.lower(tostring(subFeat.Cmd or "")) == "ws"
                        if hasUnCmd then
                            featureStates[uniqueKey] = not featureStates[uniqueKey]
                            updateAllButtonStates(uniqueKey, featureStates[uniqueKey])
                        else
                            featureStates[uniqueKey] = false
                            updateAllButtonStates(uniqueKey, false)
                        end
                        if isUnexec and not featureStates[uniqueKey] then
                            clearPluginModuleCache(getPluginSourcePath(subRawUrl))
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

        local orderedMenuItems = {}
        for index, menuItem in ipairs(menuList) do
            table.insert(orderedMenuItems, { item = menuItem, index = index })
        end
        table.sort(orderedMenuItems, function(a, b)
            local aFav = isFavorite(getMenuFavoriteKey(a.item, tabName))
            local bFav = isFavorite(getMenuFavoriteKey(b.item, tabName))
            if aFav ~= bFav then return aFav end
            return a.index < b.index
        end)

        for _, menuEntry in ipairs(orderedMenuItems) do
            local item = menuEntry.item
            local ItemFrame = Instance.new("Frame")
            ItemFrame.BackgroundColor3 = Color3.fromRGB(25, 32, 42)
            ItemFrame.BackgroundTransparency = 0.35
            ItemFrame.BorderSizePixel = 0
            ItemFrame.Parent = targetParentScroll
            Instance.new("UICorner", ItemFrame).CornerRadius = UDim.new(0, 4)

            local NameLabel = Instance.new("TextLabel")
            NameLabel.Size = UDim2.new(1, -118, 0, 18)
            NameLabel.Position = UDim2.new(0, 8, 0, 4)
            NameLabel.BackgroundTransparency = 1
            NameLabel.Text = item.Name
            NameLabel.TextColor3 = Color3.fromRGB(0, 220, 255)
            NameLabel.Font = Enum.Font.GothamBold
            NameLabel.TextSize = 11
            NameLabel.TextXAlignment = Enum.TextXAlignment.Left
            NameLabel.Parent = ItemFrame

            local uniqueKey = tostring(item.RawUrl or "") .. "_" .. tostring(item.Cmd or item.Name)
            local historyRawUrl = item.RawUrl
            if (not historyRawUrl or historyRawUrl == "") and item.SubFeatures and #item.SubFeatures > 0 then
                historyRawUrl = getPrimarySubFeatureSourceUrl(item.SubFeatures, item.RawUrl)
            end
            local itemSourcePath = getPluginSourcePath(historyRawUrl)
            local hasUpdateBadge = itemSourcePath and releaseUpdateByPath[itemSourcePath] == true or false
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
                    local subPath = getPluginSourcePath(subRaw)
                    if subPath and releaseUpdateByPath[subPath] then hasUpdateBadge = true end
                    local subBadgeText = getUserFacingBadgeText(sub)
                    if subBadgeText and isFeatureNew(subKey, subTimestamp) then
                        table.insert(badgeFeatureKeys, { key = subKey, timestamp = subTimestamp })
                        if #badgeFeatureKeys == 1 or subBadgeText == "UPDATE!" then
                            activeBadgeText = subBadgeText
                            activeBadgeColorName = sub.BadgeColor or activeBadgeColorName
                        end
                    end
                end
            elseif getUserFacingBadgeText(item) and isFeatureNew(badgeKey, timestamp) then
                table.insert(badgeFeatureKeys, { key = badgeKey, timestamp = timestamp })
            end

            if isMaintenance or hasSubMaintenance then
                activeBadgeText = "MAINTENANCE!"
                activeBadgeColorName = "red"
            end

            if #badgeFeatureKeys > 0 or isMaintenance or hasSubMaintenance or hasUpdateBadge then
                activeBadgeText = hasUpdateBadge and "UPDATE!" or "NEW!"
                if hasUpdateBadge then activeBadgeColorName = "green" end
                if isMaintenance or hasSubMaintenance then
                    activeBadgeText = "MAINTENANCE!"
                    activeBadgeColorName = "red"
                end
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
                    elseif hasUpdateBadge then
                        badgeShortText = "UPDATE!"
                    else
                        badgeShortText = "NEW!"
                    end
                    setTabBadge(tabName, badgeShortText, badgeColor, hasUpdateBadge and 3 or 2, badgeFeatureKeys)
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
            DescLabel.Size = UDim2.new(1, -118, 0, descHeight)
            ItemFrame.Size = UDim2.new(1, 0, 0, descHeight + 28)

            local itemHasHistory = false
            if itemSourcePath then
                itemHasHistory = attachPublicVersionHistory(ItemFrame, targetParentScroll, historyRawUrl,
                    tostring(item.Name or itemSourcePath), descHeight + 28, NameLabel, hasUpdateBadge) == true
            end

            local MenuFavoriteBtn = Instance.new("TextButton")
            MenuFavoriteBtn.Size = UDim2.new(0, 22, 0, 22)
            MenuFavoriteBtn.AnchorPoint = Vector2.new(0, 0.5)
            MenuFavoriteBtn.Position = UDim2.new(1, itemHasHistory and -122 or -108, 0.5, 0)
            MenuFavoriteBtn.BackgroundTransparency = 1
            MenuFavoriteBtn.BorderSizePixel = 0
            MenuFavoriteBtn.Font = Enum.Font.GothamBold
            MenuFavoriteBtn.TextSize = 18
            MenuFavoriteBtn.Text = isFavorite(getMenuFavoriteKey(item, tabName)) and "★" or "☆"
            MenuFavoriteBtn.TextColor3 = isFavorite(getMenuFavoriteKey(item, tabName))
                and Color3.fromRGB(255, 205, 55) or Color3.fromRGB(135, 145, 160)
            MenuFavoriteBtn.Parent = ItemFrame
            MenuFavoriteBtn.MouseButton1Click:Connect(function()
                toggleFavorite(getMenuFavoriteKey(item, tabName))
                for _, child in ipairs(targetParentScroll:GetChildren()) do
                    if child:IsA("Frame") or child:IsA("TextLabel") then child:Destroy() end
                end
                renderMenuCategory(menuList, targetParentScroll, tabName)
            end)

            if item.SubFeatures and #item.SubFeatures > 0 then
                local OpenBtn = Instance.new("TextButton")
                OpenBtn.Size = UDim2.new(0, itemHasHistory and 58 or 75, 0, 24)
                OpenBtn.AnchorPoint = Vector2.new(0, 0.5)
                OpenBtn.Position = UDim2.new(1, itemHasHistory and -100 or -80, 0.5, 0)
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
                    showSubMenu(item.Name, historyRawUrl or item.RawUrl, item.SubFeatures, tabName)
                end)
            else
                if featureStates[uniqueKey] == nil then featureStates[uniqueKey] = false end

                local ExecBtn = Instance.new("TextButton")
                ExecBtn.Size = UDim2.new(0, itemHasHistory and 58 or 75, 0, 24)
                ExecBtn.AnchorPoint = Vector2.new(0, 0.5)
                ExecBtn.Position = UDim2.new(1, itemHasHistory and -100 or -80, 0.5, 0)
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
                            local commandOk, commandErr = xpcall(function()
                                if not loadedModules[item.RawUrl] then
                                    loadedModules[item.RawUrl] = loadPluginModule(item.RawUrl)
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
                                    if foundFunc then
                                    task.spawn(function()
                                        local ok, err = xpcall(function() foundFunc(customArgs or {}, speaker) end, function(e) return debug.traceback(tostring(e), 2) end)
                                        if not ok then reportPluginRuntimeError(item.Name, isUnexec and (item.UnCmd or item.Cmd) or item.Cmd, item.RawUrl, err) end
                                    end)
                                    else
                                        error("Command function tidak ditemukan: " .. tostring(targetCmd))
                                    end
                                else
                                    error("Modul plugin tidak memiliki tabel Commands: " .. tostring(item.Name))
                                end
                            end, function(err) return debug.traceback(tostring(err), 2) end)
                                if not commandOk then
                                    reportPluginRuntimeError(item.Name, isUnexec and (item.UnCmd or item.Cmd) or item.Cmd, item.RawUrl, commandErr)
                                end

                            local hasUnCmd = item.UnCmd and item.UnCmd ~= ""
                            if hasUnCmd then
                                featureStates[uniqueKey] = not featureStates[uniqueKey]
                                updateAllButtonStates(uniqueKey, featureStates[uniqueKey])
                            else
                                featureStates[uniqueKey] = false
                                updateAllButtonStates(uniqueKey, false)
                            end
                            if isUnexec and not featureStates[uniqueKey] then
                                clearPluginModuleCache(getPluginSourcePath(item.RawUrl))
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
        if openPublicHistoryPanels > 0 then
            pendingPublicBadgeRefresh = true
            return
        end
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
                    setTabBadge(tabName, "NEW!", Color3.fromRGB(255, 215, 0), 1,
                        {{ key = tabUniqueKey, timestamp = "071120260000, 86400" }})
                end
                renderMenuCategory(globalLoaderData[tabInfo.DataKey] or {}, scroll, tabName)
            end
        end

        if isCurrentlyInSubMenu and currentSubMenuTitle then
            for _, tabInfo in ipairs(globalLoaderData.Tabs or {}) do
                for _, menuItem in ipairs(globalLoaderData[tabInfo.DataKey] or {}) do
                    if (not currentSubMenuTabName or tabInfo.Name == currentSubMenuTabName)
                        and menuItem.Name == currentSubMenuTitle and menuItem.SubFeatures then
                        showSubMenu(menuItem.Name, menuItem.RawUrl, menuItem.SubFeatures, tabInfo.Name)
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
        migrateLegacyFavorites(data)
        task.defer(checkStableReleaseUpdates)

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
                setTabBadge(tabName, "NEW!", Color3.fromRGB(255, 215, 0), 1, {{ key = tabUniqueKey, timestamp = "071120260000, 86400" }})
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
    else
        if metadataReady and metadataRefreshPending and refreshBadgeUI then
            metadataRefreshPending = false
            task.defer(refreshBadgeUI)
        end
    end
end