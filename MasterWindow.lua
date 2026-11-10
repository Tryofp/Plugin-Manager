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
        local branches = { "main", "Beta" }
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
        local selectedSha = path and tostring(selectedPluginVersions[path] or "") or ""
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
            local changed = false
            for _, sourcePath in ipairs(paths) do
                local apiUrl = "https://api.github.com/repos/Tryofp/Plugin-Manager/commits?path="
                    .. HttpService:UrlEncode(sourcePath) .. "&sha=main&per_page=1&page=1"
                local ok, response = requestGitHubWithRetry(apiUrl, 2)
                if ok then
                    local decodeOk, commits = pcall(function() return HttpService:JSONDecode(response) end)
                    local latest = decodeOk and type(commits) == "table" and commits[1] or nil
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
                    end
                end
                task.wait(0.15)
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
        arrow.Size = UDim2.new(0, 20, 0, 20)
        arrow.AnchorPoint = Vector2.new(1, 0.5)
        -- Keep the toggle anchored to the original feature row when the history panel expands.
        arrow.Position = UDim2.new(1, -8, 0, baseHeight / 2)
        arrow.ZIndex = (card.ZIndex or 1) + 5
        arrow.BackgroundColor3 = Color3.fromRGB(45, 65, 85)
        arrow.BackgroundTransparency = 0.1
        arrow.BorderSizePixel = 0
        arrow.Font = Enum.Font.GothamBold
        arrow.Text = "v"
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
            historyScroll.Position = UDim2.new(0, 5, 0, 51)
            historyScroll.Size = UDim2.new(1, -10, 1, -56)
            historyScroll.BackgroundTransparency = 1
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
                local foundBaseline = false
                for _, entry in ipairs(history.commits) do
                    if tostring(entry.sha or "") == baselineSha then foundBaseline = true break end
                end

                while not foundBaseline and not history.complete and history.nextPage <= 10 do
                    local page = history.nextPage
                    local apiUrl = "https://api.github.com/repos/Tryofp/Plugin-Manager/commits?path="
                        .. path .. "&sha=main&per_page=100&page=" .. tostring(page)
                    local ok, response = requestGitHubWithRetry(apiUrl, 3)
                    if not ok or type(response) ~= "string" or response == "" then
                        loadWarning = "GitHub belum merespons setelah 3 percobaan. Riwayat yang sudah diterima tetap ditampilkan; tekan panah lagi untuk mencoba ulang."
                        break
                    end
                    local decodeOk, decoded = pcall(function() return HttpService:JSONDecode(response) end)
                    if not decodeOk or type(decoded) ~= "table" or decoded.message then
                        loadWarning = "GitHub membatasi atau gagal merespons. Riwayat yang sudah diterima tetap ditampilkan; buka ulang untuk mencoba lagi."
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
                        if entrySha == baselineSha then foundBaseline = true break end
                    end
                    history.nextPage = page + 1
                    if foundBaseline or #decoded < 100 then history.complete = true break end
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
                    return
                end

                local totalVersions = baselineIndex or #commits
                local latestSha = tostring(commits[1] and commits[1].sha or "")
                stableLatestShaCache[path] = latestSha
                local selectedSha = tostring(selectedPluginVersions[path] or latestSha)
                local loadedSha = loadedPluginVersionShas[path]
                local currentSha = loadedSha == "__STABLE_LATEST__" and latestSha or loadedSha or selectedSha

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
                arrow.Text = "^"
                refreshPanel()
                card.Size = UDim2.new(1, 0, 0, baseHeight + 152)
            else
                arrow.Text = "v"
                if panel then panel:Destroy() panel = nil end
                card.Size = UDim2.new(1, 0, 0, baseHeight)
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
            loadedPluginVersionShas[sourcePath] = selectedPluginVersions[sourcePath] or "__STABLE_LATEST__"
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

        local path = normalizedUrl:match("^https://raw%.githubusercontent%.com/Tryofp/Plugin%-Manager/refs/heads/Beta/(.+)$")
            or normalizedUrl:match("^https://raw%.githubusercontent%.com/Tryofp/Plugin%-Manager/Beta/(.+)$")
            or normalizedUrl:match("^https://raw%.githubusercontent%.com/Tryofp/Plugin%-Manager/refs/heads/main/(.+)$")
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
    local runtimeErrorLastSent = {}
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

    -- Read-only Plugin Health Check UI
    local HealthCheckView = Instance.new("Frame")
    HealthCheckView.Size = UDim2.new(1, -16, 1, -45)
    HealthCheckView.Position = UDim2.new(0, 8, 0, 40)
    HealthCheckView.BackgroundTransparency = 1
    HealthCheckView.Visible = false
    HealthCheckView.ZIndex = 31
    HealthCheckView.Parent = DevPanelContainer

    -- Plugin Update Checker UI
    local UpdateCheckerView = Instance.new("Frame")
    UpdateCheckerView.Size = UDim2.new(1, -16, 1, -45)
    UpdateCheckerView.Position = UDim2.new(0, 8, 0, 40)
    UpdateCheckerView.BackgroundTransparency = 1
    UpdateCheckerView.Visible = false
    UpdateCheckerView.ZIndex = 31
    UpdateCheckerView.Parent = DevPanelContainer

    local UpdateCheckerBackBtn = Instance.new("TextButton")
    UpdateCheckerBackBtn.Size = UDim2.new(1, 0, 0, 28)
    UpdateCheckerBackBtn.BackgroundColor3 = Color3.fromRGB(35, 45, 60)
    UpdateCheckerBackBtn.BorderSizePixel = 0
    UpdateCheckerBackBtn.Font = Enum.Font.GothamBold
    UpdateCheckerBackBtn.Text = "< KEMBALI KE MENU DEV"
    UpdateCheckerBackBtn.TextColor3 = Color3.fromRGB(0, 200, 255)
    UpdateCheckerBackBtn.TextSize = 10
    UpdateCheckerBackBtn.ZIndex = 32
    UpdateCheckerBackBtn.Parent = UpdateCheckerView
    Instance.new("UICorner", UpdateCheckerBackBtn).CornerRadius = UDim.new(0, 4)
    UpdateCheckerBackBtn.MouseButton1Click:Connect(function()
        UpdateCheckerView.Visible = false
        DevMainMenu.Visible = true
    end)

    local UpdateCheckerScanBtn = Instance.new("TextButton")
    UpdateCheckerScanBtn.Size = UDim2.new(0.49, 0, 0, 28)
    UpdateCheckerScanBtn.Position = UDim2.new(0, 0, 0, 33)
    UpdateCheckerScanBtn.BackgroundColor3 = Color3.fromRGB(0, 130, 90)
    UpdateCheckerScanBtn.BorderSizePixel = 0
    UpdateCheckerScanBtn.Font = Enum.Font.GothamBold
    UpdateCheckerScanBtn.Text = "CEK UPDATE"
    UpdateCheckerScanBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    UpdateCheckerScanBtn.TextSize = 9
    UpdateCheckerScanBtn.ZIndex = 32
    UpdateCheckerScanBtn.Parent = UpdateCheckerView
    Instance.new("UICorner", UpdateCheckerScanBtn).CornerRadius = UDim.new(0, 4)

    local UpdateCheckerBaselineBtn = Instance.new("TextButton")
    UpdateCheckerBaselineBtn.Size = UDim2.new(0.49, 0, 0, 28)
    UpdateCheckerBaselineBtn.Position = UDim2.new(0.51, 0, 0, 33)
    UpdateCheckerBaselineBtn.BackgroundColor3 = Color3.fromRGB(45, 95, 155)
    UpdateCheckerBaselineBtn.BorderSizePixel = 0
    UpdateCheckerBaselineBtn.Font = Enum.Font.GothamBold
    UpdateCheckerBaselineBtn.Text = "SIMPAN BASELINE"
    UpdateCheckerBaselineBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    UpdateCheckerBaselineBtn.TextSize = 9
    UpdateCheckerBaselineBtn.ZIndex = 32
    UpdateCheckerBaselineBtn.Parent = UpdateCheckerView
    Instance.new("UICorner", UpdateCheckerBaselineBtn).CornerRadius = UDim.new(0, 4)

    local UpdateCheckerAdminKeyBox = Instance.new("TextBox")
    UpdateCheckerAdminKeyBox.Size = UDim2.new(1, 0, 0, 24)
    UpdateCheckerAdminKeyBox.Position = UDim2.new(0, 0, 0, 64)
    UpdateCheckerAdminKeyBox.BackgroundColor3 = Color3.fromRGB(28, 36, 48)
    UpdateCheckerAdminKeyBox.BorderSizePixel = 0
    UpdateCheckerAdminKeyBox.Font = Enum.Font.Gotham
    UpdateCheckerAdminKeyBox.PlaceholderText = "Kunci Dev Panel (untuk menyimpan baseline online)"
    UpdateCheckerAdminKeyBox.Text = ""
    UpdateCheckerAdminKeyBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    UpdateCheckerAdminKeyBox.PlaceholderColor3 = Color3.fromRGB(145, 160, 180)
    UpdateCheckerAdminKeyBox.TextSize = 8
    UpdateCheckerAdminKeyBox.ClearTextOnFocus = false
    UpdateCheckerAdminKeyBox.ZIndex = 33
    UpdateCheckerAdminKeyBox.Parent = UpdateCheckerView
    Instance.new("UICorner", UpdateCheckerAdminKeyBox).CornerRadius = UDim.new(0, 4)

    local UpdateCheckerInfo = Instance.new("TextLabel")
    UpdateCheckerInfo.Size = UDim2.new(1, 0, 0, 28)
    UpdateCheckerInfo.Position = UDim2.new(0, 0, 0, 91)
    UpdateCheckerInfo.BackgroundTransparency = 1
    UpdateCheckerInfo.Font = Enum.Font.Gotham
    UpdateCheckerInfo.Text = "Cek commit GitHub. Pemeriksaan pertama perlu menyimpan baseline."
    UpdateCheckerInfo.TextColor3 = Color3.fromRGB(160, 175, 195)
    UpdateCheckerInfo.TextSize = 8
    UpdateCheckerInfo.TextWrapped = true
    UpdateCheckerInfo.TextXAlignment = Enum.TextXAlignment.Left
    UpdateCheckerInfo.ZIndex = 32
    UpdateCheckerInfo.Parent = UpdateCheckerView

    local UpdateCheckerScroll = Instance.new("ScrollingFrame")
    UpdateCheckerScroll.Size = UDim2.new(1, 0, 1, -130)
    UpdateCheckerScroll.Position = UDim2.new(0, 0, 0, 126)
    UpdateCheckerScroll.BackgroundTransparency = 1
    UpdateCheckerScroll.BorderSizePixel = 0
    UpdateCheckerScroll.ScrollBarThickness = 4
    UpdateCheckerScroll.Active = true
    UpdateCheckerScroll.ScrollingEnabled = true
    UpdateCheckerScroll.ZIndex = 32
    UpdateCheckerScroll.Parent = UpdateCheckerView

    local UpdateCheckerLayout = Instance.new("UIListLayout")
    UpdateCheckerLayout.SortOrder = Enum.SortOrder.LayoutOrder
    UpdateCheckerLayout.Padding = UDim.new(0, 5)
    UpdateCheckerLayout.Parent = UpdateCheckerScroll
    UpdateCheckerLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        UpdateCheckerScroll.CanvasSize = UDim2.new(0, 0, 0, UpdateCheckerLayout.AbsoluteContentSize.Y + 8)
    end)

    local HealthCheckBackBtn = Instance.new("TextButton")
    HealthCheckBackBtn.Size = UDim2.new(1, 0, 0, 28)
    HealthCheckBackBtn.BackgroundColor3 = Color3.fromRGB(35, 45, 60)
    HealthCheckBackBtn.BorderSizePixel = 0
    HealthCheckBackBtn.Font = Enum.Font.GothamBold
    HealthCheckBackBtn.Text = "< KEMBALI KE MENU DEV"
    HealthCheckBackBtn.TextColor3 = Color3.fromRGB(0, 200, 255)
    HealthCheckBackBtn.TextSize = 10
    HealthCheckBackBtn.ZIndex = 32
    HealthCheckBackBtn.Parent = HealthCheckView
    Instance.new("UICorner", HealthCheckBackBtn).CornerRadius = UDim.new(0, 4)
    HealthCheckBackBtn.MouseButton1Click:Connect(function()
        HealthCheckView.Visible = false
        DevMainMenu.Visible = true
    end)

    local HealthCheckRunBtn = Instance.new("TextButton")
    HealthCheckRunBtn.Size = UDim2.new(0.49, 0, 0, 28)
    HealthCheckRunBtn.Position = UDim2.new(0, 0, 0, 33)
    HealthCheckRunBtn.BackgroundColor3 = Color3.fromRGB(0, 130, 90)
    HealthCheckRunBtn.BorderSizePixel = 0
    HealthCheckRunBtn.Font = Enum.Font.GothamBold
    HealthCheckRunBtn.Text = "JALANKAN PEMERIKSAAN"
    HealthCheckRunBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    HealthCheckRunBtn.TextSize = 9
    HealthCheckRunBtn.ZIndex = 32
    HealthCheckRunBtn.Parent = HealthCheckView
    Instance.new("UICorner", HealthCheckRunBtn).CornerRadius = UDim.new(0, 4)

    local HealthCheckExportBtn = Instance.new("TextButton")
    HealthCheckExportBtn.Size = UDim2.new(0.49, 0, 0, 28)
    HealthCheckExportBtn.Position = UDim2.new(0.51, 0, 0, 33)
    HealthCheckExportBtn.BackgroundColor3 = Color3.fromRGB(45, 95, 155)
    HealthCheckExportBtn.BorderSizePixel = 0
    HealthCheckExportBtn.Font = Enum.Font.GothamBold
    HealthCheckExportBtn.Text = "EXPORT HASIL"
    HealthCheckExportBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    HealthCheckExportBtn.TextSize = 9
    HealthCheckExportBtn.ZIndex = 32
    HealthCheckExportBtn.Parent = HealthCheckView
    Instance.new("UICorner", HealthCheckExportBtn).CornerRadius = UDim.new(0, 4)

    local RuntimeHistoryBtn = Instance.new("TextButton")
    RuntimeHistoryBtn.Size = UDim2.new(0.49, 0, 0, 25)
    RuntimeHistoryBtn.Position = UDim2.new(0, 0, 0, 64)
    RuntimeHistoryBtn.BackgroundColor3 = Color3.fromRGB(105, 75, 155)
    RuntimeHistoryBtn.BorderSizePixel = 0
    RuntimeHistoryBtn.Font = Enum.Font.GothamBold
    RuntimeHistoryBtn.Text = "RIWAYAT ERROR"
    RuntimeHistoryBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    RuntimeHistoryBtn.TextSize = 9
    RuntimeHistoryBtn.ZIndex = 32
    RuntimeHistoryBtn.Parent = HealthCheckView
    Instance.new("UICorner", RuntimeHistoryBtn).CornerRadius = UDim.new(0, 4)

    local RuntimeTestBtn = Instance.new("TextButton")
    RuntimeTestBtn.Size = UDim2.new(0.49, 0, 0, 25)
    RuntimeTestBtn.Position = UDim2.new(0.51, 0, 0, 64)
    RuntimeTestBtn.BackgroundColor3 = Color3.fromRGB(150, 95, 35)
    RuntimeTestBtn.BorderSizePixel = 0
    RuntimeTestBtn.Font = Enum.Font.GothamBold
    RuntimeTestBtn.Text = "TES LAPORAN"
    RuntimeTestBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    RuntimeTestBtn.TextSize = 9
    RuntimeTestBtn.ZIndex = 32
    RuntimeTestBtn.Parent = HealthCheckView
    Instance.new("UICorner", RuntimeTestBtn).CornerRadius = UDim.new(0, 4)

    local StableUpdateTestBtn = Instance.new("TextButton")
    StableUpdateTestBtn.Size = UDim2.new(1, 0, 0, 25)
    StableUpdateTestBtn.Position = UDim2.new(0, 0, 0, 94)
    StableUpdateTestBtn.BackgroundColor3 = Color3.fromRGB(35, 115, 105)
    StableUpdateTestBtn.BorderSizePixel = 0
    StableUpdateTestBtn.Font = Enum.Font.GothamBold
    StableUpdateTestBtn.Text = "TES UPDATE STABLE"
    StableUpdateTestBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    StableUpdateTestBtn.TextSize = 9
    StableUpdateTestBtn.ZIndex = 32
    StableUpdateTestBtn.Parent = HealthCheckView
    Instance.new("UICorner", StableUpdateTestBtn).CornerRadius = UDim.new(0, 4)

    HealthCheckInfo = Instance.new("TextLabel")
    HealthCheckInfo.Size = UDim2.new(1, 0, 0, 28)
    HealthCheckInfo.Position = UDim2.new(0, 0, 0, 124)
    HealthCheckInfo.BackgroundTransparency = 1
    HealthCheckInfo.Font = Enum.Font.Gotham
    HealthCheckInfo.Text = "Pemeriksaan belum dijalankan. Source hanya diunduh dan dikompilasi, tidak dieksekusi."
    HealthCheckInfo.TextColor3 = Color3.fromRGB(160, 175, 195)
    HealthCheckInfo.TextSize = 8
    HealthCheckInfo.TextWrapped = true
    HealthCheckInfo.TextXAlignment = Enum.TextXAlignment.Left
    HealthCheckInfo.ZIndex = 32
    HealthCheckInfo.Parent = HealthCheckView

    local HealthCheckScroll = Instance.new("ScrollingFrame")
    HealthCheckScroll.Size = UDim2.new(1, 0, 1, -160)
    HealthCheckScroll.Position = UDim2.new(0, 0, 0, 156)
    HealthCheckScroll.BackgroundTransparency = 1
    HealthCheckScroll.BorderSizePixel = 0
    HealthCheckScroll.ScrollBarThickness = 4
    HealthCheckScroll.Active = true
    HealthCheckScroll.ScrollingEnabled = true
    HealthCheckScroll.ZIndex = 32
    HealthCheckScroll.Parent = HealthCheckView

    local HealthCheckLayout = Instance.new("UIListLayout")
    HealthCheckLayout.SortOrder = Enum.SortOrder.LayoutOrder
    HealthCheckLayout.Padding = UDim.new(0, 5)
    HealthCheckLayout.Parent = HealthCheckScroll
    HealthCheckLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        HealthCheckScroll.CanvasSize = UDim2.new(0, 0, 0, HealthCheckLayout.AbsoluteContentSize.Y + 8)
    end)

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

    local VersionHistoryAdminKeyBox = Instance.new("TextBox")
    VersionHistoryAdminKeyBox.Size = UDim2.new(1, 0, 0, 26)
    VersionHistoryAdminKeyBox.Position = UDim2.new(0, 0, 0, 64)
    VersionHistoryAdminKeyBox.BackgroundColor3 = Color3.fromRGB(28, 36, 48)
    VersionHistoryAdminKeyBox.BorderSizePixel = 0
    VersionHistoryAdminKeyBox.Font = Enum.Font.Gotham
    VersionHistoryAdminKeyBox.PlaceholderText = "Masukkan kunci Dev Panel untuk restore"
    VersionHistoryAdminKeyBox.Text = ""
    VersionHistoryAdminKeyBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    VersionHistoryAdminKeyBox.PlaceholderColor3 = Color3.fromRGB(145, 160, 180)
    VersionHistoryAdminKeyBox.TextSize = 9
    VersionHistoryAdminKeyBox.ClearTextOnFocus = false
    VersionHistoryAdminKeyBox.ZIndex = 33
    VersionHistoryAdminKeyBox.Parent = VersionHistoryView
    Instance.new("UICorner", VersionHistoryAdminKeyBox).CornerRadius = UDim.new(0, 4)

    local VersionHistoryScroll = Instance.new("ScrollingFrame")
    VersionHistoryScroll.Size = UDim2.new(1, 0, 1, -96)
    VersionHistoryScroll.Position = UDim2.new(0, 0, 0, 94)
    VersionHistoryScroll.BackgroundTransparency = 1
    VersionHistoryScroll.BorderSizePixel = 0
    VersionHistoryScroll.ScrollBarThickness = 4
    VersionHistoryScroll.Active = true
    VersionHistoryScroll.ScrollingEnabled = true
    VersionHistoryScroll.ZIndex = 32
    VersionHistoryScroll.Parent = VersionHistoryView

    local VersionHistoryLayout = Instance.new("UIListLayout")
    VersionHistoryLayout.SortOrder = Enum.SortOrder.LayoutOrder
    VersionHistoryLayout.Padding = UDim.new(0, 6)
    VersionHistoryLayout.Parent = VersionHistoryScroll

    -- Keep the canvas matched to the real content height, including TextButton rows.
    VersionHistoryLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        VersionHistoryScroll.CanvasSize = UDim2.new(0, 0, 0, VersionHistoryLayout.AbsoluteContentSize.Y + 8)
    end)

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

    local healthScanRunning = false
    local healthReportLines = {}

    local updateScanRunning = false
    local updateScanResults = {}
    local updateBaseline = {}
    local updateBaselineLoaded = false
    local UPDATE_BASELINE_KEY = "PluginUpdateCheckerBaseline"

    local function loadUpdateBaseline()
        updateBaseline = {}
        local raw = tostring(remoteMetadata[UPDATE_BASELINE_KEY] or "")
        if raw ~= "" then
            local decodeOk, decoded = pcall(function()
                return HttpService:JSONDecode(raw)
            end)
            if decodeOk and type(decoded) == "table" then
                updateBaseline = decoded
            end
        end
        updateBaselineLoaded = true
    end

    local function clearUpdateCheckerRows()
        for _, child in ipairs(UpdateCheckerScroll:GetChildren()) do
            if child:IsA("Frame") or child:IsA("TextLabel") then
                child:Destroy()
            end
        end
    end

    local function addUpdateCheckerRow(title, detail, status)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -4, 0, 42)
        row.BackgroundColor3 = Color3.fromRGB(25, 32, 42)
        row.BorderSizePixel = 0
        row.ZIndex = 33
        row.Parent = UpdateCheckerScroll
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 4)

        local titleLabel = Instance.new("TextLabel")
        titleLabel.Size = UDim2.new(1, -14, 0, 17)
        titleLabel.Position = UDim2.new(0, 7, 0, 4)
        titleLabel.BackgroundTransparency = 1
        titleLabel.Font = Enum.Font.GothamBold
        titleLabel.Text = tostring(status) .. " " .. tostring(title)
        titleLabel.TextColor3 = status == "UPDATE" and Color3.fromRGB(255, 185, 90)
            or status == "ERROR" and Color3.fromRGB(255, 105, 105)
            or status == "BARU" and Color3.fromRGB(100, 190, 255)
            or Color3.fromRGB(100, 230, 150)
        titleLabel.TextSize = 9
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left
        titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
        titleLabel.ZIndex = 34
        titleLabel.Parent = row

        local detailLabel = Instance.new("TextLabel")
        detailLabel.Size = UDim2.new(1, -14, 0, 16)
        detailLabel.Position = UDim2.new(0, 7, 0, 21)
        detailLabel.BackgroundTransparency = 1
        detailLabel.Font = Enum.Font.Gotham
        detailLabel.Text = tostring(detail or "")
        detailLabel.TextColor3 = Color3.fromRGB(165, 178, 195)
        detailLabel.TextSize = 8
        detailLabel.TextXAlignment = Enum.TextXAlignment.Left
        detailLabel.TextTruncate = Enum.TextTruncate.AtEnd
        detailLabel.ZIndex = 34
        detailLabel.Parent = row
    end

    local function collectUpdateCheckerFiles()
        local files, seen = {}, {}
        local data = globalLoaderData
        if type(data) ~= "table" then return files end
        for _, tabInfo in ipairs(data.Tabs or {}) do
            local dataKey = type(tabInfo) == "table" and tabInfo.DataKey or nil
            local list = dataKey and dataKey ~= "" and data[dataKey] or nil
            if type(list) == "table" then
                for _, item in ipairs(list) do
                    if type(item) == "table" then
                        local candidates = item.SubFeatures and #item.SubFeatures > 0 and item.SubFeatures or {item}
                        for _, feature in ipairs(candidates) do
                            if type(feature) == "table" then
                                local rawUrl = tostring((feature.RawUrl and feature.RawUrl ~= "" and feature.RawUrl) or item.RawUrl or "")
                                local path = rawUrl:match("raw%.githubusercontent%.com/Tryofp/Plugin%-Manager/refs/heads/Beta/(.+)")
                                    or rawUrl:match("raw%.githubusercontent%.com/Tryofp/Plugin%-Manager/Beta/(.+)")
                                    or rawUrl:match("raw%.githubusercontent%.com/Tryofp/Plugin%-Manager/refs/heads/main/(.+)")
                                    or rawUrl:match("raw%.githubusercontent%.com/Tryofp/Plugin%-Manager/main/(.+)")
                                if path and not seen[path] then
                                    seen[path] = true
                                    table.insert(files, {
                                        path = path,
                                        name = tostring(feature.Name or item.Name or path)
                                    })
                                end
                            end
                        end
                    end
                end
            end
        end
        table.sort(files, function(a, b) return string.lower(a.path) < string.lower(b.path) end)
        return files
    end

    local function runPluginUpdateCheck()
        if updateScanRunning then return end
        updateScanRunning = true
        UpdateCheckerScanBtn.Active = false
        UpdateCheckerBaselineBtn.Active = false
        UpdateCheckerScanBtn.Text = "MEMERIKSA..."
        UpdateCheckerInfo.Text = "Memeriksa isi source plugin dari GitHub..."
        clearUpdateCheckerRows()
        updateScanResults = {}
        task.spawn(function()
            -- Ambil baseline terbaru dari Metadata server sebelum membandingkan.
            local metadataOk = fetchRemoteMetadata()
            if metadataOk then
                loadUpdateBaseline()
            else
                UpdateCheckerInfo.Text = "Gagal mengambil baseline online. Coba cek ulang."
                UpdateCheckerScanBtn.Text = "CEK ULANG"
                UpdateCheckerScanBtn.Active = true
                UpdateCheckerBaselineBtn.Active = false
                updateScanRunning = false
                return
            end

            local files = collectUpdateCheckerFiles()
            if #files == 0 then
                addUpdateCheckerRow("Loader tidak tersedia", "Tidak ada source yang bisa diperiksa.", "ERROR")
                UpdateCheckerInfo.Text = "Tidak ada source yang bisa diperiksa."
                UpdateCheckerScanBtn.Text = "CEK ULANG"
                UpdateCheckerScanBtn.Active = true
                UpdateCheckerBaselineBtn.Active = false
                updateScanRunning = false
                return
            end

            -- Unduh source secara paralel agar tidak menunggu 21 request satu per satu.
            -- Maksimal 4 worker untuk menjaga beban jaringan dan executor tetap terkendali.
            local updated, unchanged, newBaseline, errors = 0, 0, 0, 0
            local completed, nextIndex = 0, 0
            local workerCount = math.min(4, #files)

            local downloadRequest = request or http_request or (syn and syn.request)
            local function checkOneFile(fileInfo)
                local rawUrl = "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/Beta/" .. fileInfo.path
                local rawOk, source
                if type(downloadRequest) == "function" then
                    rawOk, source = pcall(function()
                        local response = downloadRequest({
                            Url = rawUrl,
                            Method = "GET",
                            Timeout = 12
                        })
                        if not response then error("Tidak ada respons dari server") end
                        local statusCode = tonumber(response.StatusCode or response.Status or 0)
                        if statusCode ~= 200 then
                            error("HTTP " .. tostring(statusCode) .. ": " .. string.sub(tostring(response.Body or response.StatusMessage or ""), 1, 70))
                        end
                        return response.Body
                    end)
                else
                    rawOk, source = pcall(function() return game:HttpGet(rawUrl) end)
                end

                if not rawOk or type(source) ~= "string" or source == "" then
                    errors = errors + 1
                    addUpdateCheckerRow(fileInfo.name, "Gagal mengambil isi source: " .. string.sub(tostring(source), 1, 100), "ERROR")
                else
                    -- Fingerprint deterministik dari isi file (bukan hash keamanan).
                    local fingerprint = 0
                    for byteIndex = 1, #source do
                        fingerprint = (fingerprint * 131 + string.byte(source, byteIndex)) % 2147483647
                    end
                    local latestFingerprint = "content:" .. tostring(#source) .. ":" .. tostring(fingerprint)
                    updateScanResults[fileInfo.path] = {
                        sha = latestFingerprint,
                        name = fileInfo.name
                    }

                    local baselineFingerprint = tostring(updateBaseline[fileInfo.path] or "")
                    if baselineFingerprint == "" then
                        newBaseline = newBaseline + 1
                        addUpdateCheckerRow(fileInfo.name, "Belum ada baseline • " .. tostring(#source) .. " byte", "BARU")
                    elseif baselineFingerprint ~= latestFingerprint then
                        updated = updated + 1
                        addUpdateCheckerRow(fileInfo.name, "Isi file berubah sejak baseline terakhir.", "UPDATE")
                    else
                        unchanged = unchanged + 1
                        addUpdateCheckerRow(fileInfo.name, "Isi file masih sama • " .. tostring(#source) .. " byte.", "OK")
                    end
                end
            end

            for worker = 1, workerCount do
                task.spawn(function()
                    while true do
                        nextIndex = nextIndex + 1
                        local index = nextIndex
                        if index > #files then break end

                        local fileInfo = files[index]
                        UpdateCheckerInfo.Text = string.format(
                            "Mengunduh paralel • %d/%d selesai • %s",
                            completed, #files, fileInfo.name
                        )

                        local ok, err = pcall(checkOneFile, fileInfo)
                        if not ok then
                            errors = errors + 1
                            addUpdateCheckerRow(fileInfo.name, "Kesalahan pemeriksaan: " .. string.sub(tostring(err), 1, 100), "ERROR")
                        end

                        completed = completed + 1
                        UpdateCheckerInfo.Text = string.format(
                            "Memeriksa source • %d/%d selesai (%d worker)",
                            completed, #files, workerCount
                        )
                    end
                end)
            end

            while completed < #files do
                task.wait(0.05)
            end

            UpdateCheckerInfo.Text = string.format(
                "Selesai • %d source • %d update • %d sama • %d baseline baru • %d gagal. Simpan baseline setelah meninjau.",
                #files, updated, unchanged, newBaseline, errors
            )
            UpdateCheckerScanBtn.Text = "CEK ULANG"
            UpdateCheckerScanBtn.Active = true
            UpdateCheckerBaselineBtn.Active = next(updateScanResults) ~= nil
            updateScanRunning = false
        end)
    end

    UpdateCheckerScanBtn.MouseButton1Click:Connect(runPluginUpdateCheck)

    UpdateCheckerBaselineBtn.MouseButton1Click:Connect(function()
        if updateScanRunning or not next(updateScanResults) then
            UpdateCheckerInfo.Text = "Jalankan pemeriksaan terlebih dahulu."
            return
        end
        -- Keep old entries for files that failed this scan; never erase a valid baseline on a network error.
        local nextBaseline = {}
        for path, sha in pairs(updateBaseline) do
            nextBaseline[path] = sha
        end
        for path, result in pairs(updateScanResults) do
            nextBaseline[path] = result.sha
        end
        local encodedOk, encoded = pcall(function() return HttpService:JSONEncode(nextBaseline) end)
        if not encodedOk then
            UpdateCheckerInfo.Text = "Gagal membuat data baseline."
            return
        end

        local adminKey = tostring(UpdateCheckerAdminKeyBox.Text or "")
        if adminKey == "" then
            UpdateCheckerInfo.Text = "Masukkan kunci Dev Panel untuk menyimpan baseline online."
            return
        end

        UpdateCheckerBaselineBtn.Active = false
        UpdateCheckerBaselineBtn.Text = "MENYIMPAN..."
        local requestFn = request or http_request or (syn and syn.request)
        if type(requestFn) ~= "function" then
            UpdateCheckerInfo.Text = "Executor tidak menyediakan request untuk menyimpan ke server."
            UpdateCheckerBaselineBtn.Text = "SIMPAN BASELINE"
            UpdateCheckerBaselineBtn.Active = true
            return
        end

        local beforeBaselineUpdatedAt = tostring(remoteMetadata.PluginUpdateCheckerBaselineUpdatedAt or "")
        local requestOk, response = pcall(function()
            return requestFn({
                Url = SHEETS_WEB_APP_URL,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode({
                    Type = "UpdateBaseline",
                    Action = "Save",
                    Baseline = encoded,
                    AdminKey = adminKey
                })
            })
        end)

        local saveSuccess = false
        if requestOk and response then
            -- Apps Script may redirect POST responses in some executors.
            -- Confirm persistence from the public metadata snapshot instead of trusting the POST body.
            for attempt = 1, 4 do
                task.wait(attempt == 1 and 0.25 or 0.5)
                local stateOk = fetchRemoteMetadata()
                if stateOk then
                    local savedAt = tostring(remoteMetadata.PluginUpdateCheckerBaselineUpdatedAt or "")
                    local savedRaw = tostring(remoteMetadata[UPDATE_BASELINE_KEY] or "")
                    if savedAt ~= "" and savedAt ~= beforeBaselineUpdatedAt and savedRaw == encoded then
                        saveSuccess = true
                        break
                    end
                end
            end
        end

        if saveSuccess then
            updateBaseline = nextBaseline
            updateBaselineLoaded = true
            UpdateCheckerInfo.Text = "Baseline berhasil disimpan ONLINE di Google Sheets. Bisa dipakai lintas perangkat."
            UpdateCheckerAdminKeyBox.Text = ""
        else
            UpdateCheckerInfo.Text = requestOk
                and "Server belum mengonfirmasi penyimpanan. Periksa kunci Dev Panel atau koneksi, lalu coba lagi."
                or "Gagal menghubungi server untuk menyimpan baseline online."
        end
        UpdateCheckerBaselineBtn.Text = "SIMPAN BASELINE"
        UpdateCheckerBaselineBtn.Active = not saveSuccess
    end)

    local function addHealthCheckResult(title, detail, isError)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 42)
        row.BackgroundColor3 = Color3.fromRGB(25, 32, 42)
        row.BorderSizePixel = 0
        row.ZIndex = 33
        row.Parent = HealthCheckScroll
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 4)

        local titleLabel = Instance.new("TextLabel")
        titleLabel.Size = UDim2.new(1, -14, 0, 17)
        titleLabel.Position = UDim2.new(0, 7, 0, 4)
        titleLabel.BackgroundTransparency = 1
        titleLabel.Font = Enum.Font.GothamBold
        titleLabel.Text = (isError and "✖ " or "✓ ") .. tostring(title)
        titleLabel.TextColor3 = isError and Color3.fromRGB(255, 105, 105) or Color3.fromRGB(100, 230, 150)
        titleLabel.TextSize = 9
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left
        titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
        titleLabel.ZIndex = 34
        titleLabel.Parent = row

        local detailLabel = Instance.new("TextLabel")
        detailLabel.Size = UDim2.new(1, -14, 0, 16)
        detailLabel.Position = UDim2.new(0, 7, 0, 21)
        detailLabel.BackgroundTransparency = 1
        detailLabel.Font = Enum.Font.Gotham
        detailLabel.Text = tostring(detail or "")
        detailLabel.TextColor3 = Color3.fromRGB(165, 178, 195)
        detailLabel.TextSize = 8
        detailLabel.TextXAlignment = Enum.TextXAlignment.Left
        detailLabel.TextTruncate = Enum.TextTruncate.AtEnd
        detailLabel.ZIndex = 34
        detailLabel.Parent = row
    end

    local function runPluginHealthCheck()
        if healthScanRunning then return end
        healthScanRunning = true
        HealthCheckRunBtn.Active = false
        HealthCheckRunBtn.Text = "MEMERIKSA..."
        HealthCheckInfo.Text = "Mengumpulkan konfigurasi Loader..."
        healthReportLines = {"PLUGIN HEALTH CHECK", "=================="}
        for _, child in ipairs(HealthCheckScroll:GetChildren()) do
            if child:IsA("Frame") or child:IsA("TextLabel") then child:Destroy() end
        end

        task.spawn(function()
            local errors, checks = 0, 0
            local function report(title, detail, failed)
                checks = checks + 1
                if failed then errors = errors + 1 end
                table.insert(healthReportLines, (failed and "[ERROR] " or "[OK] ") .. tostring(title) .. " | " .. tostring(detail or ""))
                addHealthCheckResult(title, detail, failed)
            end

            local data = globalLoaderData
            if type(data) ~= "table" then
                report("Loader tidak tersedia", "Data Loader belum berhasil dimuat.", true)
            else
                local tabs = data.Tabs
                if type(tabs) ~= "table" or #tabs == 0 then
                    report("Struktur Tabs", "Loader.Tabs kosong atau bukan tabel.", true)
                else
                    report("Struktur Tabs", tostring(#tabs) .. " tab ditemukan.", false)
                end

                local features, seenObjects = {}, {}
                for _, tabInfo in ipairs(type(tabs) == "table" and tabs or {}) do
                    if type(tabInfo) ~= "table" or type(tabInfo.Name) ~= "string" or tabInfo.Name == "" then
                        report("Data tab tidak valid", "Ditemukan entri tab tanpa Name yang valid.", true)
                    else
                        local list = data[tabInfo.DataKey]
                        if type(list) ~= "table" then
                            report("Tab " .. tabInfo.Name, "DataKey tidak menunjuk ke tabel: " .. tostring(tabInfo.DataKey), true)
                        else
                            for _, item in ipairs(list) do
                                if type(item) == "table" and type(item.SubFeatures) == "table" and #item.SubFeatures > 0 then
                                    for _, sub in ipairs(item.SubFeatures) do
                                        if type(sub) == "table" and not seenObjects[sub] then
                                            seenObjects[sub] = true
                                            table.insert(features, { feature = sub, parent = item, tab = tabInfo.Name })
                                        end
                                    end
                                elseif type(item) == "table" and not seenObjects[item] then
                                    seenObjects[item] = true
                                    table.insert(features, { feature = item, parent = item, tab = tabInfo.Name })
                                end
                            end
                        end
                    end
                end

                local seenIds, seenCmds, urls = {}, {}, {}
                if #features == 0 then
                    report("Daftar fitur kosong", "Tidak ada fitur yang dapat diperiksa dari tab Loader.", true)
                end
                for _, entry in ipairs(features) do
                    local feature, parent = entry.feature, entry.parent
                    local name = tostring(feature.Name or feature.Cmd or "Fitur tanpa nama")
                    local url = tostring((feature.RawUrl and feature.RawUrl ~= "" and feature.RawUrl) or parent.RawUrl or "")
                    local cmd = tostring(feature.Cmd or "")
                    local featureId = tostring(feature.FeatureId or "")
                    if featureId == "" then
                        report(name, "FeatureId kosong (" .. entry.tab .. ").", true)
                    elseif seenIds[featureId] then
                        report(name, "FeatureId duplikat: " .. featureId, true)
                    else
                        seenIds[featureId] = name
                    end
                    if cmd == "" then
                        report(name, "Command kosong; tidak bisa dipetakan.", true)
                    else
                        local key = string.lower(url .. "|" .. cmd)
                        if seenCmds[key] then
                            report(name, "Kombinasi URL + command duplikat dengan " .. seenCmds[key] .. ".", true)
                        else
                            seenCmds[key] = name
                        end
                    end
                    if url == "" then
                        report(name, "RawUrl kosong.", true)
                    else
                        urls[url] = urls[url] or {}
                        table.insert(urls[url], { name = name, cmd = cmd, mode = feature.ExecutionMode or parent.ExecutionMode })
                    end
                end

                local urlCount = 0
                for _ in pairs(urls) do urlCount = urlCount + 1 end
                report("Konfigurasi fitur", tostring(#features) .. " entri fitur dan " .. tostring(urlCount) .. " URL unik diperiksa.", false)

                for url, mapped in pairs(urls) do
                    HealthCheckInfo.Text = "Memeriksa source " .. tostring(urlCount) .. " URL..."
                    local requestOk, source = pcall(function() return game:HttpGet(url) end)
                    if not requestOk or type(source) ~= "string" or source == "" then
                        report("URL gagal diakses", url, true)
                    else
                        local compileOk, compileResult = pcall(function()
                            if type(loadstring) ~= "function" then error("loadstring tidak tersedia") end
                            return loadstring(source)
                        end)
                        if not compileOk or type(compileResult) ~= "function" then
                            report("Syntax/source error", url .. " | " .. tostring(compileResult), true)
                        else
                            report("Source OK", url .. " | " .. tostring(#mapped) .. " mapping fitur.", false)
                            for _, mapping in ipairs(mapped) do
                                if mapping.mode == "standalone" then
                                    report("Script mandiri", mapping.name .. " → " .. mapping.cmd .. " | validasi tabel Commands dilewati; source berjalan langsung saat dimuat.", false)
                                else
                                    local escaped = mapping.cmd:gsub("([^%w])", "%%%1")
                                    -- Commands normally live inside a nested Commands table, so
                                    -- search for the command key itself rather than requiring
                                    -- the literal text "Commands" immediately before the key.
                                    local dotPattern = "%.%s*" .. escaped .. "%s*="
                                    local bracketPattern = "%[%s*[\"']" .. escaped .. "[\"']%s*%]%s*="
                                    if not string.find(source, dotPattern) and not string.find(source, bracketPattern) then
                                        report("Command tidak ditemukan", mapping.name .. " → " .. mapping.cmd, true)
                                    end
                                end
                            end
                        end
                    end
                    task.wait(0.1)
                end
            end

            table.insert(healthReportLines, "==================")
            table.insert(healthReportLines, string.format("RINGKASAN: %d pemeriksaan, %d temuan.", checks, errors))
            HealthCheckInfo.Text = string.format("Selesai: %d pemeriksaan, %d temuan. Source tidak dieksekusi.", checks, errors)
            HealthCheckRunBtn.Text = "JALANKAN ULANG PEMERIKSAAN"
            HealthCheckRunBtn.Active = true
            healthScanRunning = false
        end)
    end

    HealthCheckRunBtn.MouseButton1Click:Connect(runPluginHealthCheck)

    local runtimeTestSent = false
    RuntimeTestBtn.MouseButton1Click:Connect(function()
        if runtimeTestSent then
            HealthCheckInfo.Text = "Tes laporan baru saja dikirim. Muat riwayat untuk memeriksa hasilnya."
            return
        end
        runtimeTestSent = true
        RuntimeTestBtn.Text = "MENGIRIM TES..."
        RuntimeTestBtn.Active = false
        HealthCheckInfo.Text = "Mengirim satu laporan simulasi. Tidak ada command plugin asli yang dijalankan atau diubah."

        reportPluginRuntimeError(
            "Plugin Manager - TEST",
            "RuntimeReportTest",
            "internal://runtime-monitor-test",
            "SIMULASI: pengujian jalur laporan runtime error. Ini bukan error plugin asli."
        )

        task.delay(3, function()
            if RuntimeTestBtn and RuntimeTestBtn.Parent then
                RuntimeTestBtn.Text = "TES TERKIRIM - CEK RIWAYAT"
                RuntimeTestBtn.Active = true
            end
        end)
    end)

    local stableUpdateTestRunning = false
    StableUpdateTestBtn.MouseButton1Click:Connect(function()
        if stableUpdateTestRunning then return end
        if stableFixPromptActive then
            HealthCheckInfo.Text = "Tutup prompt perbaikan yang sedang terbuka sebelum mengulang tes."
            return
        end

        local stableSourceUrl
        for url, fingerprint in pairs(loadedModuleFingerprints) do
            local normalizedUrl = tostring(url):match("^[^?]+") or tostring(url)
            local isStableSource = normalizedUrl:match("^https://raw%.githubusercontent%.com/Tryofp/Plugin%-Manager/refs/heads/Beta/.+$")
                or normalizedUrl:match("^https://raw%.githubusercontent%.com/Tryofp/Plugin%-Manager/Beta/.+$")
                or normalizedUrl:match("^https://raw%.githubusercontent%.com/Tryofp/Plugin%-Manager/refs/heads/main/.+$")
                or normalizedUrl:match("^https://raw%.githubusercontent%.com/Tryofp/Plugin%-Manager/main/.+$")
            if isStableSource and fingerprint and loadedModules[normalizedUrl] then
                stableSourceUrl = normalizedUrl
                break
            end
        end

        if not stableSourceUrl then
            HealthCheckInfo.Text = "Belum ada plugin dari branch stable yang dimuat. Jalankan satu plugin stable dahulu, lalu tes lagi."
            return
        end

        stableUpdateTestRunning = true
        StableUpdateTestBtn.Active = false
        StableUpdateTestBtn.Text = "MENYIAPKAN TES..."
        HealthCheckInfo.Text = "Simulasi perbedaan fingerprint pada source stable yang sudah dimuat. Branch stable tidak diubah dan tidak ada laporan error palsu dikirim."

        task.spawn(function()
            local originalFingerprint = loadedModuleFingerprints[stableSourceUrl]
            local ok, err = pcall(function()
                loadedModuleFingerprints[stableSourceUrl] = "__PLUGIN_MANAGER_STABLE_UPDATE_TEST__"
                checkStableFixAvailable("Plugin Manager - TEST", "StableUpdateTest", stableSourceUrl, true)
            end)
            loadedModuleFingerprints[stableSourceUrl] = originalFingerprint

            if not ok then
                HealthCheckInfo.Text = "Tes gagal dijalankan: " .. tostring(err)
            else
                HealthCheckInfo.Text = "Tes dipicu. Jika prompt PERBAIKAN STABLE TERSEDIA muncul, tekan NANTI untuk menutup tanpa reload atau MUAT ULANG SOURCE untuk menguji reload."
            end
            StableUpdateTestBtn.Text = "ULANGI TES UPDATE STABLE"
            StableUpdateTestBtn.Active = true
            stableUpdateTestRunning = false
        end)
    end)

    local runtimeHistoryLoading = false
    RuntimeHistoryBtn.MouseButton1Click:Connect(function()
        if runtimeHistoryLoading then return end
        runtimeHistoryLoading = true
        RuntimeHistoryBtn.Text = "MEMUAT RIWAYAT..."
        HealthCheckInfo.Text = "Mengambil laporan runtime error terbaru..."
        for _, child in ipairs(HealthCheckScroll:GetChildren()) do
            if child:IsA("Frame") or child:IsA("TextLabel") then child:Destroy() end
        end

        task.spawn(function()
            local ok, response = pcall(function()
                return game:HttpGet(SHEETS_WEB_APP_URL .. "?action=PluginErrors&limit=50&_=" .. tostring(DateTime.now().UnixTimestampMillis))
            end)
            local decoded
            if ok and type(response) == "string" and response ~= "" then
                local decodeOk, result = pcall(function() return HttpService:JSONDecode(response) end)
                if decodeOk and type(result) == "table" then decoded = result end
            end

            if not decoded or decoded.status ~= "success" or type(decoded.records) ~= "table" then
                HealthCheckInfo.Text = "Gagal mengambil riwayat. Periksa koneksi atau deployment Apps Script."
                addHealthCheckResult("Riwayat tidak tersedia", ok and "Respons server tidak valid." or tostring(response), true)
            elseif #decoded.records == 0 then
                HealthCheckInfo.Text = "Belum ada runtime error yang tercatat di server."
                addHealthCheckResult("Belum ada laporan", "Laporan error akan muncul setelah command gagal dijalankan.", false)
            else
                HealthCheckInfo.Text = tostring(#decoded.records) .. " laporan terbaru berhasil dimuat."
                for _, record in ipairs(decoded.records) do
                    local title = tostring(record.Plugin or "Unknown Plugin") .. " / " .. tostring(record.Command or "Unknown Command")
                    local detail = tostring(record.Error or "Tanpa detail")
                    if record.Timestamp then detail = tostring(record.Timestamp) .. " | " .. detail end
                    if record.PlaceId and record.PlaceId ~= "" then detail = detail .. " | PlaceId " .. tostring(record.PlaceId) end
                    addHealthCheckResult(title, detail, true)
                end
            end
            RuntimeHistoryBtn.Text = "MUAT ULANG RIWAYAT ERROR"
            runtimeHistoryLoading = false
        end)
    end)

    HealthCheckExportBtn.MouseButton1Click:Connect(function()
        -- Export exactly the rows currently displayed, whether they are health-check
        -- results or runtime-error history. Do not reuse the separate scan baseline.
        local exportLines = {"PLUGIN MANAGER - HASIL YANG SEDANG DITAMPILKAN", "============================================"}
        local rowCount = 0
        for _, child in ipairs(HealthCheckScroll:GetChildren()) do
            if child:IsA("Frame") then
                local labels = {}
                for _, item in ipairs(child:GetChildren()) do
                    if item:IsA("TextLabel") then
                        table.insert(labels, item.Text)
                    end
                end
                if #labels > 0 then
                    rowCount = rowCount + 1
                    table.insert(exportLines, labels[1] .. (#labels > 1 and (" | " .. labels[2]) or ""))
                end
            end
        end

        if rowCount == 0 then
            HealthCheckInfo.Text = "Tidak ada hasil yang sedang ditampilkan untuk diekspor."
            return
        end

        local reportText = table.concat(exportLines, "\n")
        local copied = false
        if type(setclipboard) == "function" then
            copied = pcall(setclipboard, reportText)
        elseif type(toclipboard) == "function" then
            copied = pcall(toclipboard, reportText)
        end
        if copied then
            HealthCheckInfo.Text = tostring(rowCount) .. " hasil yang tampil berhasil disalin."
        elseif type(writefile) == "function" then
            local ok = pcall(writefile, "PluginHealthCheck.txt", reportText)
            HealthCheckInfo.Text = ok and "Clipboard tidak tersedia. Hasil yang tampil disimpan ke PluginHealthCheck.txt." or "Gagal menyalin dan menyimpan hasil."
        else
            HealthCheckInfo.Text = "Clipboard/file export tidak didukung executor ini."
        end
    end)

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

    local loadVersionHistoryFiles
    local loadVersionHistoryForFile
    local activeVersionHistoryFile = nil
    local selectedVersionCommit = nil
    local pendingVersionAction = nil
    local pendingVersionCommitSha = nil

    local VersionHistoryConfirm = Instance.new("Frame")
    VersionHistoryConfirm.Size = UDim2.new(1, -24, 0, 116)
    VersionHistoryConfirm.Position = UDim2.new(0, 12, 0.5, -58)
    VersionHistoryConfirm.BackgroundColor3 = Color3.fromRGB(22, 30, 42)
    VersionHistoryConfirm.BorderSizePixel = 0
    VersionHistoryConfirm.Visible = false
    VersionHistoryConfirm.ZIndex = 50
    VersionHistoryConfirm.Parent = VersionHistoryView
    Instance.new("UICorner", VersionHistoryConfirm).CornerRadius = UDim.new(0, 8)

    local VersionHistoryConfirmText = Instance.new("TextLabel")
    VersionHistoryConfirmText.Size = UDim2.new(1, -16, 0, 58)
    VersionHistoryConfirmText.Position = UDim2.new(0, 8, 0, 6)
    VersionHistoryConfirmText.BackgroundTransparency = 1
    VersionHistoryConfirmText.Font = Enum.Font.GothamBold
    VersionHistoryConfirmText.Text = "Konfirmasi tindakan Version Manager"
    VersionHistoryConfirmText.TextColor3 = Color3.fromRGB(235, 240, 248)
    VersionHistoryConfirmText.TextSize = 9
    VersionHistoryConfirmText.TextWrapped = true
    VersionHistoryConfirmText.ZIndex = 51
    VersionHistoryConfirmText.Parent = VersionHistoryConfirm

    local VersionHistoryConfirmYes = Instance.new("TextButton")
    VersionHistoryConfirmYes.Size = UDim2.new(0.5, -12, 0, 30)
    VersionHistoryConfirmYes.Position = UDim2.new(0, 8, 1, -38)
    VersionHistoryConfirmYes.BackgroundColor3 = Color3.fromRGB(0, 125, 85)
    VersionHistoryConfirmYes.BorderSizePixel = 0
    VersionHistoryConfirmYes.Font = Enum.Font.GothamBold
    VersionHistoryConfirmYes.Text = "YA, LANJUTKAN"
    VersionHistoryConfirmYes.TextColor3 = Color3.fromRGB(255, 255, 255)
    VersionHistoryConfirmYes.TextSize = 8
    VersionHistoryConfirmYes.ZIndex = 51
    VersionHistoryConfirmYes.Parent = VersionHistoryConfirm
    Instance.new("UICorner", VersionHistoryConfirmYes).CornerRadius = UDim.new(0, 4)

    local VersionHistoryConfirmNo = Instance.new("TextButton")
    VersionHistoryConfirmNo.Size = UDim2.new(0.5, -12, 0, 30)
    VersionHistoryConfirmNo.Position = UDim2.new(0.5, 4, 1, -38)
    VersionHistoryConfirmNo.BackgroundColor3 = Color3.fromRGB(75, 85, 100)
    VersionHistoryConfirmNo.BorderSizePixel = 0
    VersionHistoryConfirmNo.Font = Enum.Font.GothamBold
    VersionHistoryConfirmNo.Text = "BATAL"
    VersionHistoryConfirmNo.TextColor3 = Color3.fromRGB(255, 255, 255)
    VersionHistoryConfirmNo.TextSize = 8
    VersionHistoryConfirmNo.ZIndex = 51
    VersionHistoryConfirmNo.Parent = VersionHistoryConfirm
    Instance.new("UICorner", VersionHistoryConfirmNo).CornerRadius = UDim.new(0, 4)

    local function runVersionManagerAction(action, commitSha, fileInfo)
        task.spawn(function()
            local req = request or http_request or (syn and syn.request)
            if not req then
                VersionHistoryInfo.Text = "Executor tidak menyediakan HTTP request."
                return
            end

            VersionHistoryInfo.Text = "Memproses " .. action .. "..."

            -- Simpan state sebelum POST. Apps Script ContentService kadang
            -- mengembalikan HTTP 405 pada redirect executor walaupun aksi sudah
            -- berhasil dijalankan. Hasil akhir diverifikasi dari metadata GET.
            pcall(fetchRemoteMetadata)
            local targetBranch = tostring(fileInfo and fileInfo.branch or "main")
            local stableUpdatedAtKey = targetBranch == "main" and "StableBackupUpdatedAt" or ("StableBackupUpdatedAt_" .. targetBranch)
            local beforeStableUpdatedAt = tostring(remoteMetadata[stableUpdatedAtKey] or "")
            local beforeRestoreAt = tostring(remoteMetadata.LastVersionRestoreAt or "")

            local requestOk, response = pcall(function()
                return req({
                    Url = SHEETS_WEB_APP_URL,
                    Method = "POST",
                    Headers = { ["Content-Type"] = "application/json" },
                    Body = HttpService:JSONEncode({
                        Type = "VersionManager",
                        Action = action,
                        Path = fileInfo and fileInfo.path or "",
                        Branch = fileInfo and fileInfo.branch or "main",
                        CommitSha = commitSha or "",
                        AdminKey = VersionHistoryAdminKeyBox.Text
                    })
                })
            end)
            if not requestOk or not response then
                VersionHistoryInfo.Text = "Gagal menghubungi server Version Manager."
                return
            end

            -- Verifikasi hasil dari server, bukan status/body POST yang dapat
            -- terpengaruh redirect ContentService pada executor tertentu.
            for attempt = 1, 4 do
                task.wait(attempt == 1 and 0.25 or 0.5)
                local stateOk = fetchRemoteMetadata()
                if stateOk then
                    if action == "SetStable" then
                        local stableCommitKey = targetBranch == "main" and "StableBackupCommit" or ("StableBackupCommit_" .. targetBranch)
                        local stableCommit = tostring(remoteMetadata[stableCommitKey] or "")
                        local updatedAt = tostring(remoteMetadata[stableUpdatedAtKey] or "")
                        if stableCommit ~= "" and updatedAt ~= "" and updatedAt ~= beforeStableUpdatedAt then
                            VersionHistoryInfo.Text = "STABLE BACKUP tersimpan • " .. stableCommit:sub(1, 7)
                            return
                        end
                    elseif action == "RestoreStable" or action == "RestoreSelected" then
                        local restoreAt = tostring(remoteMetadata.LastVersionRestoreAt or "")
                        local restorePath = tostring(remoteMetadata.LastVersionRestorePath or "")
                        local restoreBranch = tostring(remoteMetadata.LastVersionRestoreBranch or "main")
                        local newCommit = tostring(remoteMetadata.LastVersionRestoreCommit or "")
                        if restoreAt ~= "" and restoreAt ~= beforeRestoreAt and restorePath == tostring(fileInfo.path)
                            and restoreBranch == targetBranch and newCommit ~= "" then
                            VersionHistoryInfo.Text = "Restore berhasil • commit baru " .. newCommit:sub(1, 7)
                            task.wait(0.5)
                            loadVersionHistoryForFile(fileInfo)
                            return
                        end
                    end
                end
            end

            local function readVersionManagerResponse(httpResponse)
                if type(httpResponse) ~= "table" then return nil, "Format respons HTTP tidak dikenali." end
                local responseBody = httpResponse.Body or httpResponse.body or httpResponse.ResponseBody or ""
                local headers = httpResponse.Headers or httpResponse.headers or {}
                local redirectUrl
                for headerName, headerValue in pairs(headers) do
                    if tostring(headerName):lower() == "location" then
                        redirectUrl = tostring(headerValue)
                        break
                    end
                end
                local statusCode = tonumber(httpResponse.StatusCode or httpResponse.Status or httpResponse.status_code)
                local isHtml = type(responseBody) == "string" and responseBody:lower():find("<html", 1, true) ~= nil

                -- Apps Script ContentService mengalihkan output ke URL googleusercontent.
                -- Coba ikuti Location SEBELUM menerima body HTML sebagai hasil final.
                if redirectUrl and (not responseBody or responseBody == "" or isHtml or (statusCode and statusCode >= 300 and statusCode < 400)) then
                    local redirectOk, redirectResponse = pcall(function()
                        return req({
                            Url = redirectUrl,
                            Method = "GET",
                            Headers = { ["Accept"] = "application/json" },
                            FollowRedirects = true
                        })
                    end)
                    if redirectOk and type(redirectResponse) == "table" then
                        local redirectedBody = redirectResponse.Body or redirectResponse.body or redirectResponse.ResponseBody or ""
                        if type(redirectedBody) == "string" and redirectedBody ~= "" then
                            return redirectedBody
                        end
                    end
                end

                if type(responseBody) == "string" and responseBody ~= "" then
                    return responseBody
                end

                local responseUrl = tostring(httpResponse.Url or httpResponse.url or httpResponse.FinalUrl or httpResponse.final_url or "")
                return nil, "HTTP " .. tostring(statusCode or "tidak diketahui") ..
                    " • body kosong" ..
                    (redirectUrl and " • redirect gagal diikuti" or " • Location tidak tersedia") ..
                    (responseUrl ~= "" and " • URL: " .. responseUrl:sub(1, 100) or "")
            end

            local body, responseError = readVersionManagerResponse(response)
            if not body then
                VersionHistoryInfo.Text = "Respons server tidak terbaca: " .. tostring(responseError)
                return
            end
            local decodeOk, result = pcall(function() return HttpService:JSONDecode(body) end)
            if not decodeOk or type(result) ~= "table" then
                local html = tostring(body)
                local pageTitle = html:match("<title[^>]*>(.-)</title>") or html:match("<TITLE[^>]*>(.-)</TITLE>") or "judul tidak ditemukan"
                pageTitle = pageTitle:gsub("%s+", " "):sub(1, 100)
                local responseHeaders = response.Headers or response.headers or {}
                local locationHeader = ""
                for headerName, headerValue in pairs(responseHeaders) do
                    if tostring(headerName):lower() == "location" then
                        locationHeader = tostring(headerValue):sub(1, 120)
                        break
                    end
                end
                local responseStatus = tostring(response.StatusCode or response.Status or response.status_code or "?")
                local responseUrl = tostring(response.Url or response.url or response.FinalUrl or response.final_url or "")
                VersionHistoryInfo.Text = "Respons Google bukan JSON • HTTP " .. responseStatus ..
                    " • " .. pageTitle ..
                    (responseUrl ~= "" and " • URL: " .. responseUrl:sub(1, 100) or "") ..
                    (locationHeader ~= "" and " • Location: " .. locationHeader or "") ..
                    " • Cuplikan: " .. html:gsub("%s+", " "):sub(1, 220)
                return
            end
            if result.status ~= "success" then
                VersionHistoryInfo.Text = "Gagal: " .. tostring(result.message or "Permintaan ditolak")
                return
            end

            if action == "SetStable" then
                VersionHistoryInfo.Text = "STABLE BACKUP tersimpan • " .. tostring(result.stableCommit or ""):sub(1, 7)
            else
                VersionHistoryInfo.Text = "Restore berhasil • commit baru " .. tostring(result.newCommit or ""):sub(1, 7)
                task.wait(0.5)
                loadVersionHistoryForFile(fileInfo)
            end
        end)
    end

    local function askVersionManagerConfirmation(action, commitSha, fileInfo)
        pendingVersionAction = action
        pendingVersionCommitSha = commitSha
        local targetBranch = tostring(fileInfo and fileInfo.branch or "main")
        local target = action == "SetStable" and ("Simpan posisi branch " .. targetBranch .. " saat ini sebagai Stable Backup?")
            or (action == "RestoreStable" and ("Kembalikan " .. fileInfo.name .. " pada branch " .. targetBranch .. " ke Stable Backup?")
            or ("Kembalikan " .. fileInfo.name .. " pada branch " .. targetBranch .. " ke commit " .. tostring(commitSha):sub(1, 7) .. "?"))
        VersionHistoryConfirmText.Text = target .. "\n\nVersi aktif sebelum restore tetap tercatat di GitHub. Stable Backup tidak akan ditimpa."
        VersionHistoryConfirm.Visible = true
    end

    VersionHistoryConfirmNo.MouseButton1Click:Connect(function()
        VersionHistoryConfirm.Visible = false
        pendingVersionAction = nil
        pendingVersionCommitSha = nil
    end)

    VersionHistoryConfirmYes.MouseButton1Click:Connect(function()
        local action = pendingVersionAction
        local commitSha = pendingVersionCommitSha
        pendingVersionAction = nil
        pendingVersionCommitSha = nil
        VersionHistoryConfirm.Visible = false
        if action then
            -- The active file is assigned by the detail view before the prompt opens.
            runVersionManagerAction(action, commitSha, activeVersionHistoryFile)
        end
    end)

    loadVersionHistoryForFile = function(fileInfo)
        activeVersionHistoryFile = fileInfo
        selectedVersionCommit = nil
        clearVersionHistoryRows()
        VersionHistoryInfo.Text = "Memuat " .. fileInfo.name .. "..."
        task.spawn(function()
            local sourceBranch = tostring(fileInfo.branch or "main")
            local historyUrl = SHEETS_WEB_APP_URL .. "?action=VersionHistory&branch="
                .. HttpService:UrlEncode(sourceBranch) .. "&path=" .. HttpService:UrlEncode(tostring(fileInfo.path))
            local historyOk, historyResponse = requestGitHubWithRetry(historyUrl, 3)
            local decoded = nil
            local historyError = nil
            if historyOk then
                local decodeOk, result = pcall(function() return HttpService:JSONDecode(historyResponse) end)
                if decodeOk and type(result) == "table" and result.status == "success"
                    and type(result.commits) == "table" then
                    decoded = result.commits
                elseif decodeOk and type(result) == "table" then
                    historyError = tostring(result.message or "Server tidak mengembalikan riwayat commit.")
                else
                    historyError = "Respons Version History bukan JSON yang valid."
                end
            else
                historyError = tostring(historyResponse or "Server Version History tidak merespons.")
            end

            -- Jangan mengganti riwayat lengkap dengan satu entry manifest.
            -- Jika server/API gagal, tampilkan error eksplisit agar tidak terlihat
            -- seolah-olah commit lama terhapus.
            if not decoded then
                VersionHistoryInfo.Text = fileInfo.name .. " • Riwayat tidak dapat dimuat"
                addVersionHistoryMessage("Version History: " .. tostring(historyError or "Respons kosong.")
                    .. " Commit GitHub tidak dihapus; coba muat ulang beberapa saat lagi.")
                return
            end

            VersionHistoryInfo.Text = fileInfo.name .. " • " .. fileInfo.path .. " • " .. sourceBranch

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

            local function createVersionActionButton(text, color, callback)
                local button = Instance.new("TextButton")
                button.Size = UDim2.new(1, -4, 0, 26)
                button.BackgroundColor3 = color
                button.BorderSizePixel = 0
                button.Font = Enum.Font.GothamBold
                button.Text = text
                button.TextColor3 = Color3.fromRGB(255, 255, 255)
                button.TextSize = 8
                button.ZIndex = 33
                button.Parent = VersionHistoryScroll
                Instance.new("UICorner", button).CornerRadius = UDim.new(0, 4)
                button.MouseButton1Click:Connect(callback)
                return button
            end

            createVersionActionButton("★ SIMPAN / PERBARUI STABLE BACKUP", Color3.fromRGB(35, 105, 75), function()
                askVersionManagerConfirmation("SetStable", nil, fileInfo)
            end)
            createVersionActionButton("↩ RESTORE STABLE BACKUP", Color3.fromRGB(65, 90, 125), function()
                askVersionManagerConfirmation("RestoreStable", nil, fileInfo)
            end)
            local restoreSelectedButton = createVersionActionButton("RESTORE COMMIT TERPILIH", Color3.fromRGB(125, 80, 35), function()
                if not selectedVersionCommit then
                    VersionHistoryInfo.Text = "Pilih salah satu commit terlebih dahulu."
                    return
                end
                askVersionManagerConfirmation("RestoreSelected", selectedVersionCommit.sha, fileInfo)
            end)

            task.spawn(function()
                local req = request or http_request or (syn and syn.request)
                if req then
                    local ok, response = pcall(function()
                        return req({
                            Url = SHEETS_WEB_APP_URL,
                            Method = "POST",
                            Headers = { ["Content-Type"] = "application/json" },
                            Body = HttpService:JSONEncode({
                                Type = "VersionManager",
                                Action = "GetState",
                                Branch = fileInfo.branch or "main",
                                AdminKey = VersionHistoryAdminKeyBox.Text
                            })
                        })
                    end)
                    if ok and response then
                        local decodeOk, state = pcall(function() return HttpService:JSONDecode(response.Body or response.body or "") end)
                        if decodeOk and type(state) == "table" and state.status == "success" then
                            local stable = tostring(state.stableCommit or "")
                            local stableBranch = tostring(state.branch or fileInfo.branch or "main")
                            if stable ~= "" then
                                VersionHistoryInfo.Text = fileInfo.name .. " • Stable Backup (" .. stableBranch .. ") " .. stable:sub(1, 7)
                            else
                                VersionHistoryInfo.Text = fileInfo.name .. " • Stable Backup (" .. stableBranch .. ") belum disimpan"
                            end
                        end
                    end
                end
            end)

            if #decoded == 0 then
                addVersionHistoryMessage("Belum ada riwayat commit untuk file ini.")
                return
            end

            -- CURRENT VERSION follows the source SHA of the code currently active.
            -- Restore creates a new commit, so the active source SHA may be lower in history.
            local currentVersionSha = tostring(decoded[1].sha or "")
            local beforeVersionSha = tostring(decoded[2] and decoded[2].sha or "")
            local latestCommitMessage = tostring((decoded[1].commit or {}).message or "")
            local restoredSourcePrefix = latestCommitMessage:match("^[Rr]estore .- to ([a-fA-F0-9]+)")
            if restoredSourcePrefix then
                local prefix = string.lower(restoredSourcePrefix)
                for _, historyEntry in ipairs(decoded) do
                    local historySha = tostring(historyEntry.sha or "")
                    if string.lower(historySha):sub(1, #prefix) == prefix then
                        currentVersionSha = historySha
                        -- BEFORE adalah versi aktif tepat sebelum restore:
                        -- commit parent/riwayat tepat di bawah commit Restore terbaru.
                        beforeVersionSha = tostring(decoded[2] and decoded[2].sha or "")
                        break
                    end
                end
            end

            for index, entry in ipairs(decoded) do
                local commitData = entry.commit or {}
                local authorData = commitData.author or {}
                local sha = tostring(entry.sha or "")
                local message = tostring(commitData.message or "Tanpa pesan"):gsub("[\\r\\n]+", " ")
                if #message > 90 then message = message:sub(1, 87) .. "..." end

                local badgeText = nil
                local isCurrentVersion = sha == currentVersionSha
                if isCurrentVersion then
                    badgeText = "CURRENT VERSION"
                elseif sha == beforeVersionSha then
                    badgeText = "BEFORE"
                end

                local row = Instance.new("TextButton")
                row.Size = UDim2.new(1, -4, 0, 48)
                row.BackgroundColor3 = Color3.fromRGB(28, 36, 48)
                row.BackgroundTransparency = 0.15
                row.BorderSizePixel = 0
                row.Text = ""
                row.AutoButtonColor = false
                row.ZIndex = 33
                row.Parent = VersionHistoryScroll
                Instance.new("UICorner", row).CornerRadius = UDim.new(0, 4)

                local title = Instance.new("TextLabel")
                title.Size = UDim2.new(1, badgeText and -104 or -12, 0, 18)
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

                if badgeText then
                    local isCurrentBadge = badgeText == "CURRENT VERSION"
                    local badgeWidth = isCurrentBadge and 92 or 48
                    local versionBadge = Instance.new("TextLabel")
                    versionBadge.Size = UDim2.new(0, badgeWidth, 0, 16)
                    versionBadge.Position = UDim2.new(1, -(badgeWidth + 6), 0, 4)
                    versionBadge.BackgroundColor3 = isCurrentBadge
                        and Color3.fromRGB(35, 105, 75) or Color3.fromRGB(65, 75, 95)
                    versionBadge.BorderSizePixel = 0
                    versionBadge.Font = Enum.Font.GothamBold
                    versionBadge.Text = badgeText
                    versionBadge.TextColor3 = isCurrentBadge
                        and Color3.fromRGB(190, 255, 215) or Color3.fromRGB(215, 225, 240)
                    versionBadge.TextSize = isCurrentBadge and 6 or 7
                    versionBadge.ZIndex = 35
                    versionBadge.Parent = row
                    Instance.new("UICorner", versionBadge).CornerRadius = UDim.new(0, 4)
                end

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

                row.MouseButton1Click:Connect(function()
                    selectedVersionCommit = {
                        sha = sha,
                        message = commitData.message or "Tanpa pesan",
                        path = fileInfo.path,
                        name = fileInfo.name,
                        date = authorData.date or ""
                    }
                    for _, commitRow in ipairs(VersionHistoryScroll:GetChildren()) do
                        if commitRow:IsA("TextButton") and commitRow ~= fileBack then
                            commitRow.BackgroundColor3 = Color3.fromRGB(28, 36, 48)
                        end
                    end
                    row.BackgroundColor3 = Color3.fromRGB(35, 85, 125)
                    restoreSelectedButton.Text = "RESTORE COMMIT " .. sha:sub(1, 7)
                    VersionHistoryInfo.Text = "Terpilih: " .. fileInfo.name .. " • " .. sha:sub(1, 7)
                end)
            end

            task.defer(function()
                VersionHistoryScroll.CanvasSize = UDim2.new(0, 0, 0, VersionHistoryLayout.AbsoluteContentSize.Y + 8)
                VersionHistoryScroll.CanvasPosition = Vector2.new(0, 0)
            end)
        end)
    end

    loadVersionHistoryFiles = function()
        VersionHistoryConfirm.Visible = false
        activeVersionHistoryFile = nil
        selectedVersionCommit = nil
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
                    local path = getPluginSourcePath(rawUrl)
                    local branch = getPluginSourceBranch(rawUrl)
                    if path and not seen[path] then
                        seen[path] = true
                        table.insert(files, {
                            name = tostring(feature.Name or item.Name or path),
                            path = path,
                            branch = branch
                        })
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
            VersionHistoryScroll.CanvasSize = UDim2.new(0, 0, 0, VersionHistoryLayout.AbsoluteContentSize.Y + 8)
            VersionHistoryScroll.CanvasPosition = Vector2.new(0, 0)
        end)
    end

    addDevMenuOption("🩺 Plugin Health Check", "Periksa Loader, URL, sintaks, dan mapping command tanpa menjalankan plugin", function()
        DevMainMenu.Visible = false
        HealthCheckView.Visible = true
        runPluginHealthCheck()
    end)

    addDevMenuOption("🔄 Plugin Update Checker", "Bandingkan commit source GitHub dengan baseline tersimpan", function()
        DevMainMenu.Visible = false
        UpdateCheckerView.Visible = true
        runPluginUpdateCheck()
    end)

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
            HealthCheckView.Visible = false
            UpdateCheckerView.Visible = false
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
            local hasSubUpdateBadge = (subSourcePath and releaseUpdateByPath[subSourcePath] == true)
                or (activeBadgeText == "UPDATE!" and isFeatureNew(badgeKey, timestamp))
            if hasSubUpdateBadge then activeBadgeColor = Color3.fromRGB(60, 255, 100) end
            local showSubBadgeText = hasSubUpdateBadge and "UPDATE!"
                or (activeBadgeText and isFeatureNew(badgeKey, timestamp) and activeBadgeText or nil)

            if showSubBadgeText then
                local badgeText = "[" .. showSubBadgeText .. "]"
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
                    subHasHistory = attachPublicVersionHistory(Item, SubScroll, subRawUrl, tostring(subFeat.Name or subSourcePath), descHeight + 28, LblName, hasSubUpdateBadge) == true
                end
            end

            local SubFavoriteBtn = Instance.new("TextButton")
            SubFavoriteBtn.Size = UDim2.new(0, 22, 0, 22)
            SubFavoriteBtn.AnchorPoint = Vector2.new(0, 0.5)
            SubFavoriteBtn.Position = UDim2.new(1, subHasHistory and -122 or -104, 0.5, 0)
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
            ExecSub.Size = UDim2.new(0, subHasHistory and 68 or 75, 0, 24)
            ExecSub.AnchorPoint = Vector2.new(0, 0.5)
            ExecSub.Position = UDim2.new(1, subHasHistory and -96 or -80, 0.5, 0)
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
            local itemHasHistory = false
            local badgeKey = getFeatureBadgeKey(item, uniqueKey)
            local timestamp = item.UpdateTimestamp or ""
            local activeBadgeText = getUserFacingBadgeText(item)
            local activeBadgeColorName = item.BadgeColor
            local badgeFeatureKeys = {}
            local hasUpdateBadge = itemSourcePath and releaseUpdateByPath[itemSourcePath] == true or false

            if item.SubFeatures and #item.SubFeatures > 0 then
                for _, sub in ipairs(item.SubFeatures) do
                    local subRaw = (sub.RawUrl and sub.RawUrl ~= "") and sub.RawUrl or item.RawUrl
                    local legacySubKey = tostring(subRaw) .. "_" .. tostring(sub.Cmd)
                    local subKey = getFeatureBadgeKey(sub, legacySubKey)
                    local subTimestamp = sub.UpdateTimestamp or ""
                    local subBadgeText = getUserFacingBadgeText(sub)
                    local subPath = getPluginSourcePath(subRaw)
                    if subPath and releaseUpdateByPath[subPath] then hasUpdateBadge = true end
                    if subBadgeText and isFeatureNew(subKey, subTimestamp) then
                        table.insert(badgeFeatureKeys, { key = subKey, timestamp = subTimestamp })
                        if subBadgeText == "UPDATE!" then hasUpdateBadge = true end
                        if #badgeFeatureKeys == 1 or subBadgeText == "UPDATE!" then
                            activeBadgeText = subBadgeText
                            activeBadgeColorName = sub.BadgeColor or activeBadgeColorName
                        end
                    end
                end
            elseif activeBadgeText and isFeatureNew(badgeKey, timestamp) then
                table.insert(badgeFeatureKeys, { key = badgeKey, timestamp = timestamp })
                hasUpdateBadge = hasUpdateBadge or activeBadgeText == "UPDATE!"
            end

            if #badgeFeatureKeys > 0 or hasUpdateBadge then
                activeBadgeText = hasUpdateBadge and "UPDATE!" or "NEW!"
                if hasUpdateBadge then activeBadgeColorName = "green" end
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
                    local badgePriority = hasUpdateBadge and 3 or 2
                    setTabBadge(tabName, activeBadgeText, badgeColor, badgePriority, badgeFeatureKeys)
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

            local descWidth = math.max(120, ItemFrame.AbsoluteSize.X - (itemSourcePath and 166 or 126))
            local textBounds = TextService:GetTextSize(item.Desc, 10, Enum.Font.Gotham, Vector2.new(descWidth, 10000))
            local descHeight = math.max(14, textBounds.Y + 5)
            DescLabel.Size = UDim2.new(1, itemSourcePath and -158 or -118, 0, descHeight)
            ItemFrame.Size = UDim2.new(1, 0, 0, descHeight + 28)

            if itemSourcePath then
                itemHasHistory = attachPublicVersionHistory(ItemFrame, targetParentScroll, historyRawUrl, tostring(item.Name or itemSourcePath), descHeight + 28, NameLabel, hasUpdateBadge) == true
            end

            local MenuFavoriteBtn = Instance.new("TextButton")
            MenuFavoriteBtn.Size = UDim2.new(0, 22, 0, 22)
            MenuFavoriteBtn.AnchorPoint = Vector2.new(0, 0.5)
            MenuFavoriteBtn.Position = UDim2.new(1, itemHasHistory and -122 or -104, 0.5, 0)
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
                OpenBtn.Size = UDim2.new(0, itemHasHistory and 68 or 75, 0, 24)
                OpenBtn.AnchorPoint = Vector2.new(0, 0.5)
                OpenBtn.Position = UDim2.new(1, itemHasHistory and -96 or -80, 0.5, 0)
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
                ExecBtn.Size = UDim2.new(0, itemHasHistory and 68 or 75, 0, 24)
                ExecBtn.AnchorPoint = Vector2.new(0, 0.5)
                ExecBtn.Position = UDim2.new(1, itemHasHistory and -96 or -80, 0.5, 0)
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
        if not globalLoaderData then return end
        -- Ambil Loader terbaru agar timestamp fitur yang baru di-push langsung tersedia.
        local ok, newData = pcall(function()
            local loaderUrl = "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/Beta/Loader.lua"
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
        local configUrl = "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/Beta/Loader.lua"
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
        task.spawn(loadServerVersionProfiles)
        if metadataReady and metadataRefreshPending and refreshBadgeUI then
            metadataRefreshPending = false
            task.defer(refreshBadgeUI)
        end
    end
end