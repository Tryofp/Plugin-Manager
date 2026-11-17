-- Tryo Plugin Manager - Standalone beta2
-- Compact UI bootstrap. Independent from Infinite Yield.

local BASE_URL = "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/beta2/"
local LIBRARY_URL = BASE_URL .. "UI/Library.lua"

local loadedModuleSources = {}
local function fetchModule(url, chunkName)
    local source = game:HttpGet(url)
    assert(type(source) == "string" and source ~= "", "Failed to download " .. chunkName)
    loadedModuleSources[chunkName] = { Url = url, Source = source }
    local compiled, compileError = loadstring(source, chunkName)
    assert(type(compiled) == "function", tostring(compileError))
    return compiled()
end

local ok, result = pcall(function()
    local TryoUI = fetchModule(LIBRARY_URL, "TryoUI/Library.lua")
    assert(type(TryoUI) == "table" and type(TryoUI.new) == "function", "Invalid Tryo UI Library")

    -- Read the shared LastUpdate metadata from the production Apps Script endpoint.
    -- The endpoint serves pluginMetadata.LastUpdate from Firestore.
    local HttpService = game:GetService("HttpService")
    local TweenService = game:GetService("TweenService")
    local METADATA_URL = "https://script.google.com/macros/s/AKfycbxJzU3MiL_o9PjkF4h-prSw-P8vLVfJqGFXM7pFJOPzIzJXaGmu6z6oK0oJl54a6bQy0Q/exec"
    -- Reuse the owner allowlist already enforced by the legacy Developer Panel.
    -- Add additional trusted UserIds here when the private admin rollout is approved.
    local ADMIN_USER_IDS = { [6141017541] = true }

    local function reportRuntimeError(command, source, message)
        local req = request or http_request or (syn and syn.request)
        if type(req) ~= "function" then return end
        task.spawn(function()
            pcall(function()
                req({
                    Url = METADATA_URL,
                    Method = "POST",
                    Headers = { ["Content-Type"] = "application/json" },
                    Body = HttpService:JSONEncode({
                        Type = "PluginRuntimeError",
                        Plugin = "Standalone Script Hub",
                        Command = tostring(command or "Runtime"),
                        Source = tostring(source or "beta2/Main.lua"),
                        Error = tostring(message or "Unknown error"):sub(1, 1500),
                        PlaceId = tostring(game.PlaceId)
                    }),
                    FollowRedirects = true
                })
            end)
        end)
    end

    -- Public changelog manifest: keep this history current before every stable release.
    local RELEASES = {
        {
            Version = "0.9", Date = "17/11/2026", Title = "Waypoint Radar & Public Map",
            Summary = "Peningkatan deteksi checkpoint, rute AuraCP, dan katalog Waypoint lintas map.",
            Changes = {
                {Id = "PlainCheckpointSequence", FeatureId = "WaypointManager", Type = "UPDATE", Tab = "Gunung", Feature = "Waypoint",
                    Details = "Checkpoint biasa pada Workspace.Checkpoint.Checkpoint kini dikenali dan diberi nomor CP1, CP2, dan seterusnya berdasarkan urutan ketinggian; deteksi CP bernomor dan Summit tetap dipertahankan."},
                {Id = "AuraCPRouteDetection", FeatureId = "WaypointManager", Type = "NEW", Tab = "Gunung", Feature = "Waypoint",
                    Details = "Radar mendukung deteksi checkpoint rute AuraCP dengan nomor desimal tanpa mengubah klasifikasi Summit."},
                {Id = "WaypointPublicMap", FeatureId = "WaypointManager", Type = "NEW", Tab = "Gunung", Feature = "Waypoint Public Map",
                    Details = "Public Map terhubung ke Firestore, mendukung pencarian rute, metadata nama Place Roblox, katalog lintas map, validasi PlaceId, serta unggah, ambil, dan hapus rute."}
            }
        },

        {
            Version = "0.8", Date = "16/11/2026", Title = "Preset, Waypoint & Sound Fixes",
            Summary = "Perbaikan pemulihan preset Interactable, deteksi checkpoint QUEST, dan kontrol mute suara.",
            Changes = {
                {Id = "InteractablePresetRestore", Type = "UPDATE", Tab = "Presets", Feature = "Preset Manager",
                    Details = "Preset kini menyimpan dan memulihkan ketujuh status Interactable; indikator toggle mengikuti hasil Load."},
                {Id = "QuestWaypointDetection", FeatureId = "WaypointManager", Type = "UPDATE", Tab = "Gunung", Feature = "Waypoint",
                    Details = "Radar mengenali Workspace.QUEST.CP<number>.Part dan Workspace.QUEST.CPSUMMIT.Part, termasuk pencarian ProximityPrompt pada ancestor terkait."},
                {Id = "MuteAllSounds", FeatureId = "MuteMapSounds", Type = "UPDATE", Tab = "Horor", Feature = "Mute Sound",
                    Details = "Mute Sound membisukan seluruh objek Sound di Workspace dan SoundService, termasuk suara karakter, checkpoint, dan respawn."}
            }
        },
        {
            Version = "0.7", Date = "15/11/2026", Title = "Changelog & Tab Organization",
            Summary = "Penyempurnaan navigasi fitur dan riwayat pembaruan Script Hub.",
            Changes = {
                {Id = "ScrollableChangelog", Type = "NEW", Tab = "Main", Feature = "Changelog!",
                    Details = "Riwayat versi kini dibuka melalui jendela khusus yang dapat di-scroll, dengan kartu terpisah untuk setiap versi dan rincian perubahannya."},
                {Id = "NoFallDamageTab", FeatureId = "NoFallDamage", Type = "UPDATE", Tab = "Tools", Feature = "No Fall Damage",
                    Details = "No Fall Damage dipindahkan dari tab Horor ke Tools agar lebih mudah ditemukan."},
                {Id = "VisualEnvironmentMountain", Type = "UPDATE", Tab = "Gunung", Feature = "Visual Environment",
                    Details = "Visual Environment kini tersedia di tab Gunung dan tetap tersedia di tab Horor."}
            }
        },
        {
            Version = "0.6", Date = "15/11/2026", Title = "Movement & Visual Update",
            Summary = "Peningkatan sistem WalkSpeed, perlindungan jatuh, dan kontrol lingkungan visual.",
            Changes = {
                {Id = "WalkSpeedLoop", FeatureId = "WalkSpeed", Type = "UPDATE", Tab = "Main", Feature = "WalkSpeed",
                    Details = "WalkSpeed kini menggunakan PropertyChangedSignal seperti loopws Infinite Yield dan dipasang ulang otomatis setelah respawn."},
                {Id = "NoFallDamage", FeatureId = "NoFallDamage", Type = "NEW", Tab = "Horor", Feature = "No Fall Damage",
                    Details = "Perlindungan jatuh tinggi dengan ambang berdasarkan jarak turun dari titik puncak, tanpa memperlambat lompatan normal."},
                {Id = "VisualEnvironment", FeatureId = "VisualEnvironment", Type = "NEW", Tab = "Horor", Feature = "Visual Environment",
                    Details = "Peningkatan Full Bright menjadi kontrol visual modular: Brightness & Ambient, No Fog, Daylight, Disable Shadows, dan Disable Post FX."}
            }
        },
        {
            Version = "0.5", Date = "15/11/2026", Title = "Admin Detector Status Update",
            Summary = "Pemeriksaan awal Admin Detector kini memberikan status ketika belum ada admin/staff yang terdeteksi.",
            Changes = {
                {Id = "AdminDetectorSafeStatus", FeatureId = "AdminDetector", Type = "UPDATE", Tab = "Tools", Feature = "Admin Detector",
                    Details = "Setelah pemindaian awal selesai, notifikasi status aman ditampilkan jika belum ada admin/staff yang terdeteksi."}
            }
        },
        {
            Version = "0.4", Date = "15/11/2026", Title = "Preset Manager",
            Summary = "Pengelolaan preset slot untuk menyimpan dan memuat konfigurasi fitur.",
            Changes = {
                {Id = "PresetManager", Type = "NEW", Tab = "Presets", Feature = "Preset Manager",
                    Details = "Lima slot awal, slot tambahan tanpa batas, serta fungsi SAVE, LOAD, EDIT, dan DELETE dengan penyimpanan lokal."}
            }
        },
        {
            Version = "0.3", Date = "15/11/2026", Title = "UI & Waypoint Improvements",
            Summary = "Penyempurnaan tampilan Script Hub dan pengalaman penggunaan Waypoint.",
            Changes = {
                {Id = "ResponsiveUI", Type = "UPDATE", Tab = "Main", Feature = "Tampilan Script Hub",
                    Details = "Penyempurnaan ukuran jendela responsif dan posisi bubble TPM agar lebih nyaman digunakan."},
                {Id = "WaypointResponsive", FeatureId = "WaypointManager", Type = "UPDATE", Tab = "Gunung", Feature = "Waypoint",
                    Details = "Tampilan Waypoint dibuat lebih ringkas dan responsif, termasuk penyesuaian posisi tombol dan tab."}
            }
        },
        {
            Version = "0.2", Date = "14/11/2026", Title = "Camera Tools Update",
            Summary = "Peningkatan Force Unlock Camera dan sistem navigasi rilis publik.",
            Changes = {
                {Id = "ForceUnlockCamera", Type = "UPDATE", Tab = "Main", Feature = "Lock Kamera",
                    Details = "Force Unlock Camera kini menangani pergantian CurrentCamera dan memulihkan tipe kamera asal saat fitur dimatikan."}
            }
        }
    }

    -- beta2-only experiments are displayed in Changelog without changing the
    -- stable release manifest or its version/badge identity.
    local BETA2_EXPERIMENTS = {
        Version = "0.9-BETA2", Date = "17/11/2026",
        Title = "Eksperimen Waypoint Radar & Stabilitas",
        Summary = "Penyempurnaan eksperimental deteksi checkpoint dan pengurangan stutter pada pemindaian serta upload Public Map.",
        Changes = {
            {Id = "WaypointModelCandidateFilter", Type = "FIX", Tab = "Gunung", Feature = "Waypoint",
                Details = "Filter Model kini menerima pola CP1, Stage 2, WP3, Pos1, Ring1, dan nama angka saja agar container checkpoint tidak terlewat."},
            {Id = "WaypointDecimalLabels", Type = "UPDATE", Tab = "Gunung", Feature = "Waypoint",
                Details = "Parser mendukung label desimal seperti CP1.1, CP 1.1, CP-1.1, CP_1.1, Stage 2.5, dan WP3.1; nomor desimal tetap menjadi identitas terpisah."},
            {Id = "WaypointIncrementalScan", Type = "PERFORMANCE", Tab = "Gunung", Feature = "Waypoint",
                Details = "UI dibangun secara asynchronous, scan Workspace dilakukan bertahap dengan yield, refresh dan render Radar dibatch, serta pencocokan SAVED memakai spatial bucket untuk mengurangi beban frame."},
            {Id = "WaypointUploadWorker", Type = "FIX", Tab = "Gunung", Feature = "Waypoint Public Map",
                Details = "Persiapan rute, konversi CFrame, encoding, dan HTTP dipindahkan ke worker; konversi dilakukan per batch agar callback tombol tidak membekukan UI."},
            {Id = "WaypointUploadColdStart", Type = "FIX", Tab = "Gunung", Feature = "Waypoint Public Map",
                Details = "Nama Place Roblox dipanaskan di background. Upload memakai cache atau fallback PlaceId sehingga tidak menunggu lookup katalog saat tombol ditekan."}
        }
    }
    local function getChangelogEntries()
        local entries = {BETA2_EXPERIMENTS}
        for _, release in ipairs(RELEASES) do
            table.insert(entries, release)
        end
        return entries
    end

    local RELEASE_STATE_FILE = "TryoPluginManager_Releases.json"
    local releaseState = {Seen = {}}
    if type(readfile) == "function" and type(isfile) == "function" then
        pcall(function()
            if isfile(RELEASE_STATE_FILE) then
                local saved = HttpService:JSONDecode(readfile(RELEASE_STATE_FILE))
                if type(saved) == "table" and type(saved.Seen) == "table" then releaseState = saved end
            end
        end)
    end
    local function saveReleaseState()
        if type(writefile) == "function" then pcall(function() writefile(RELEASE_STATE_FILE, HttpService:JSONEncode(releaseState)) end) end
    end
    local function releaseKey(scope, id) return RELEASES[1].Version .. ":" .. scope .. ":" .. id end
    local function isReleaseSeen(scope, id) return releaseState.Seen[releaseKey(scope, id)] == true end
    local function markReleaseSeen(scope, id) releaseState.Seen[releaseKey(scope, id)] = true; saveReleaseState() end


    -- Hub tracker: record every hub load and send exit data synchronously from exit events.
    -- The backend sends push notifications and excludes the developer account.
    local Players = game:GetService("Players")
    local UserInputService = game:GetService("UserInputService")
    local MarketplaceService = game:GetService("MarketplaceService")
    local LocalPlayer = Players.LocalPlayer
    local trackerSessionStart = os.time()
    local trackerExitSent = false
    local trackerMapName = "Place " .. tostring(game.PlaceId)
    local trackerRequest = request or http_request or (syn and syn.request)

    -- Resolve the actual Place name by PlaceId. game.Name can be a generic
    -- experience label (for example "UGC"), while GetProductInfo may return
    -- the universe title instead of the individual Place title.
    local function getTrackerPlaceName()
        local placeId = tostring(game.PlaceId)
        local function getJson(url)
            if type(trackerRequest) ~= "function" then return nil end
            local ok, response = pcall(trackerRequest, {
                Url = url,
                Method = "GET",
                Headers = {["Accept"] = "application/json"},
                FollowRedirects = true
            })
            if not ok or type(response) ~= "table" then return nil end
            local code = tonumber(response.StatusCode or response.Status or 0) or 0
            if code < 200 or code >= 300 then return nil end
            local body = response.Body or response.body
            if type(body) ~= "string" or body == "" then return nil end
            local decodedOk, decoded = pcall(function() return HttpService:JSONDecode(body) end)
            return decodedOk and type(decoded) == "table" and decoded or nil
        end

        -- Convert the current PlaceId to its UniverseId, then match the exact
        -- PlaceId in Roblox's Places catalog (not just the experience root).
        local universeData = getJson("https://apis.roblox.com/universes/v1/places/" .. placeId .. "/universe")
        local universeId = universeData and tostring(universeData.universeId or universeData.UniverseId or "")
        if universeId ~= "" then
            local cursor = nil
            for page = 1, 10 do
                local url = "https://develop.roblox.com/v1/universes/" .. universeId ..
                    "/places?isUniverseCreation=false&limit=100&sortOrder=Asc"
                if cursor and cursor ~= "" then
                    url = url .. "&cursor=" .. HttpService:UrlEncode(cursor)
                end
                local placesData = getJson(url)
                if not placesData then break end
                local places = placesData.data or placesData.Data
                if type(places) == "table" then
                    for _, placeInfo in ipairs(places) do
                        local id = tostring(placeInfo.id or placeInfo.Id or "")
                        local name = tostring(placeInfo.name or placeInfo.Name or ""):gsub("^%s*(.-)%s*$", "%1")
                        if id == placeId and name ~= "" and string.lower(name) ~= "ugc" then
                            return name:sub(1, 120)
                        end
                    end
                end
                cursor = placesData.nextPageCursor or placesData.NextPageCursor
                if not cursor or cursor == "" then break end
            end
        end

        -- Secondary fallback. Reject generic UGC rather than saving it.
        local ok, info = pcall(function()
            return MarketplaceService:GetProductInfo(game.PlaceId)
        end)
        if ok and type(info) == "table" then
            local name = tostring(info.Name or ""):gsub("^%s*(.-)%s*$", "%1")
            if name ~= "" and string.lower(name) ~= "ugc" then
                return name:sub(1, 120)
            end
        end
        return "Place " .. placeId
    end

    local function getTrackerDevice()
        if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
            return "Mobile / Tablet"
        elseif UserInputService.KeyboardEnabled and UserInputService.MouseEnabled then
            return "PC / Laptop"
        elseif UserInputService.GamepadEnabled then
            return "Console / Controller"
        end
        return "Unknown Device"
    end

    local function sendTrackerData(isLeaving)
        if isLeaving then
            if trackerExitSent then return end
            trackerExitSent = true
        end
        if type(trackerRequest) ~= "function" then return end

        -- Intentionally synchronous: exit events may be the last chance to POST.
        pcall(function()
            local elapsed = math.max(0, os.time() - trackerSessionStart)
            local playtime = string.format("%d Menit %d Detik", math.floor(elapsed / 60), elapsed % 60)
            playtime = playtime .. (isLeaving and " (Keluar Game)" or " (Baru Load)")
            local payload = HttpService:JSONEncode({
                Type = isLeaving and "Tracker" or "HubLoad",
                Username = LocalPlayer.Name,
                UserId = tostring(LocalPlayer.UserId),
                Device = getTrackerDevice(),
                Playtime = playtime,
                MapName = trackerMapName,
                PlaceId = tostring(game.PlaceId),
                JobId = game.JobId or "Private/Solo Server"
            })
            trackerRequest({
                Url = METADATA_URL,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = payload
            })
        end)
    end

    -- Resolve the exact Place title before the first HubLoad record is sent,
    -- preventing an immediate generic "UGC" value from being saved to Firestore.
    task.spawn(function()
        local ok, name = pcall(getTrackerPlaceName)
        if ok and type(name) == "string" and name ~= "" then
            trackerMapName = name
        end
        sendTrackerData(false)
    end)

    local function replaceTrackerConnection(key, signal, callback)
        local previous = _G[key]
        if previous then pcall(function() previous:Disconnect() end) end
        _G[key] = signal:Connect(callback)
    end

    replaceTrackerConnection("TryoPluginHubBeta2_TrackerRemoving", Players.PlayerRemoving, function(player)
        if player == LocalPlayer then sendTrackerData(true) end
    end)
    replaceTrackerConnection("TryoPluginHubBeta2_TrackerAncestry", LocalPlayer.AncestryChanged, function(_, parent)
        if parent == nil then sendTrackerData(true) end
    end)
    replaceTrackerConnection("TryoPluginHubBeta2_TrackerTeleport", LocalPlayer.OnTeleport, function(state)
        if state == Enum.TeleportState.Started or state == Enum.TeleportState.RequestedFromServer then
            sendTrackerData(true)
        end
    end)

    local function formatLastUpdate(raw)
        raw = tostring(raw or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if raw == "" then return "-" end

        local yyyy, mm, dd, hh, mi = raw:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)[T ](%d%d):(%d%d)")
        if yyyy and mm and dd and hh and mi then
            return string.format("%s/%s/%s %s:%s", dd, mm, yyyy:sub(3), hh, mi)
        end

        -- Accept both four-digit and two-digit years, then always display DD/MM/YY HH:MM.
        dd, mm, yyyy, hh, mi = raw:match("^(%d%d?)[/%-](%d%d?)[/%-](%d%d%d%d)[ T](%d%d?):(%d%d?)")
        if not dd then
            dd, mm, yyyy, hh, mi = raw:match("^(%d%d?)[/%-](%d%d?)[/%-](%d%d)[ T](%d%d?):(%d%d?)")
        end
        if dd and mm and yyyy and hh and mi then
            return string.format("%02d/%02d/%s %02d:%02d",
                tonumber(dd) or 0, tonumber(mm) or 0, yyyy:sub(-2), tonumber(hh) or 0, tonumber(mi) or 0)
        end

        -- Normalize compact DDMMYY dates with either HHMM or HH:MM time.
        local compactDate, compactHour, compactMinute =
            raw:match("^(%d%d%d%d%d%d)%s+(%d%d):(%d%d)$")
        if not compactDate then
            local compactTime
            compactDate, compactTime = raw:match("^(%d%d%d%d%d%d)%s+(%d%d%d%d)$")
            if compactDate and compactTime then
                compactHour, compactMinute = compactTime:sub(1, 2), compactTime:sub(3, 4)
            end
        end
        if compactDate and compactHour and compactMinute then
            return string.format("%s/%s/%s %s:%s",
                compactDate:sub(1, 2), compactDate:sub(3, 4), compactDate:sub(5, 6),
                compactHour, compactMinute)
        end

        -- Also accept compact YYYYMMDD dates and render them as DD/MM/YY.
        local year, month, day, hour, minute =
            raw:match("^(%d%d%d%d)(%d%d)(%d%d)[ T](%d%d):(%d%d)$")
        if year and month and day then
            return string.format("%s/%s/%s %s:%s", day, month, year:sub(3), hour, minute)
        end

        return raw
    end

    local function readLastUpdate()
        local url = METADATA_URL .. "?_=" .. tostring(DateTime.now().UnixTimestampMillis)
        local response = game:HttpGet(url)
        local decoded = HttpService:JSONDecode(response or "{}")
        assert(type(decoded) == "table", "Metadata response is not a JSON object")

        -- The public endpoint normally returns a flat { LastUpdate = value } map.
        -- Accept common casing/nesting variants too, so a wrapper response does not
        -- silently turn a valid Firestore value into a dash.
        local raw = decoded.LastUpdate or decoded.lastUpdate or decoded.last_update
        local containers = { decoded.metadata, decoded.Metadata, decoded.data, decoded.Data }
        for _, container in ipairs(containers) do
            if raw == nil and type(container) == "table" then
                raw = container.LastUpdate or container.lastUpdate or container.last_update
            end
        end
        if raw == nil then
            for key, value in pairs(decoded) do
                if tostring(key):lower():gsub("[^a-z]", "") == "lastupdate" then
                    raw = value
                    break
                end
            end
        end
        if type(raw) == "table" then
            raw = raw.Value or raw.value or raw.Timestamp or raw.timestamp or raw.updatedAt
        end
        assert(raw ~= nil and tostring(raw) ~= "", "LastUpdate key is missing or empty in metadata response")
        return formatLastUpdate(raw)
    end

    -- Build the visible shell immediately; metadata loads asynchronously.
    local window = TryoUI.new({
        Title = "PLUGIN MANAGER",
        Subtitle = "V" .. RELEASES[1].Version .. " • BETA",
        LastUpdate = "Memuat...",
        Size = UDim2.fromOffset(590, 370)
    })
    window:CreateFeedbackButton({ Endpoint = METADATA_URL })

    task.spawn(function()
        local ok, value = pcall(readLastUpdate)
        if ok and window and not window.Destroyed then
            window:SetLastUpdate(value)
        elseif not ok then
            warn("[Tryo Plugin Manager] LastUpdate metadata: " .. tostring(value))
            if window and not window.Destroyed then window:SetLastUpdate("N/A") end
        end
    end)
    local loadingTab = window:CreateTab("Loading", "◌")
    loadingTab:CreateSection("INITIALIZING")
    local loadingMessage = loadingTab:CreateButton({Name = "Loading features, please wait..."})

    local FeatureManager = fetchModule(BASE_URL .. "Runtime/FeatureManager.lua", "FeatureManager.lua")
    assert(type(FeatureManager) == "table" and type(FeatureManager.new) == "function", "Invalid FeatureManager")
    local toolFeatures = fetchModule(BASE_URL .. "Features/Tools.lua", "Features/Tools.lua")
    assert(type(toolFeatures) == "table", "Invalid standalone Tools module")
    local espFeatures = fetchModule(BASE_URL .. "Features/ESP.lua", "Features/ESP.lua")
    assert(type(espFeatures) == "table", "Invalid standalone ESP module")
    local teleportFeatures = fetchModule(BASE_URL .. "Features/Teleport.lua", "Features/Teleport.lua")
    assert(type(teleportFeatures) == "table", "Invalid standalone Teleport module")
    local soundViewFeatures = fetchModule(BASE_URL .. "Features/SoundView.lua", "Features/SoundView.lua")
    assert(type(soundViewFeatures) == "table", "Invalid Sound & View module")
    local adminDetector = fetchModule(BASE_URL .. "Features/AdminDetector.lua", "AdminDetector.lua")
    assert(type(adminDetector) == "table" and type(adminDetector.Start) == "function", "Invalid Admin Detector module")
    local antiDisturbFeatures = fetchModule(BASE_URL .. "Features/AntiDisturb.lua", "Features/AntiDisturb.lua")
    assert(type(antiDisturbFeatures) == "table", "Invalid Anti-Disturb Shield module")
    local codeFinder = fetchModule(BASE_URL .. "Features/CodeFinder.lua", "CodeFinder.lua")
    assert(type(codeFinder) == "table" and type(codeFinder.Start) == "function", "Invalid Code Finder module")
    local instantPrompt = fetchModule(BASE_URL .. "Features/InstantPrompt.lua", "InstantPrompt.lua")
    assert(type(instantPrompt) == "table" and type(instantPrompt.Start) == "function", "Invalid Instant Prompt module")
    local lastServer = fetchModule(BASE_URL .. "Features/LastServer.lua", "LastServer.lua")
    assert(type(lastServer) == "table" and type(lastServer.Start) == "function", "Invalid Last Server module")
    local smartRejoin = fetchModule(BASE_URL .. "Features/SmartRejoin.lua", "SmartRejoin.lua")
    assert(type(smartRejoin) == "table" and type(smartRejoin.Start) == "function", "Invalid Smart Rejoin module")
    local waypoint = fetchModule(BASE_URL .. "Features/Waypoint.lua", "Waypoint.lua")
    assert(type(waypoint) == "table" and type(waypoint.Start) == "function", "Invalid Waypoint Manager module")
    local cameraTools = fetchModule(BASE_URL .. "Features/CameraTools.lua", "CameraTools.lua")
    assert(type(cameraTools) == "table" and cameraTools.F1Lock and cameraTools.ForceUnlockCamera, "Invalid Camera Tools module")
    local aimAssist = fetchModule(BASE_URL .. "Features/AimAssist.lua", "AimAssist.lua")
    assert(type(aimAssist) == "table" and type(aimAssist.Start) == "function", "Invalid Aim Assist module")
    local interactable = fetchModule(BASE_URL .. "Features/Interactable.lua", "Interactable.lua")
    assert(type(interactable) == "table" and type(interactable.SetFeatureEnabled) == "function", "Invalid Interactable module")
    local tpItem = fetchModule(BASE_URL .. "Features/TPitem.lua", "TPitem.lua")
    assert(type(tpItem) == "table" and type(tpItem.Start) == "function" and type(tpItem.Stop) == "function", "Invalid TPitem module")
    local musicPlayer = fetchModule(BASE_URL .. "Features/MusicPlayer.lua", "MusicPlayer.lua")
    assert(type(musicPlayer) == "table" and type(musicPlayer.Start) == "function" and type(musicPlayer.Stop) == "function", "Invalid Music Player module")

    local featureManager = FeatureManager.new()
    featureManager.Context.FeatureManager = featureManager
    local featureControllers = {}
    local walkSpeedControllers = {}

local RELEASE_FEATURE_BADGES = {
        NoFallDamage = "UPDATE",
        WaypointManager = "UPDATE"
    }
    local function attachFeatureReleaseBadge(control, featureId)
        local kind = RELEASE_FEATURE_BADGES[featureId]
        if not kind or not control or type(control.SetBadge) ~= "function" then return end
        if isReleaseSeen("feature", featureId) then return end
        control.SetBadge(kind)
        control.OnBadgeActivate = function()
            control.SetBadge(nil)
            markReleaseSeen("feature", featureId)
            for _, other in ipairs(featureControllers[featureId] or {}) do
                if other ~= control and type(other.SetBadge) == "function" then other.SetBadge(nil) end
            end
            if featureId == "WalkSpeed" then
                for _, other in ipairs(walkSpeedControllers or {}) do
                    if other ~= control and type(other.SetBadge) == "function" then other.SetBadge(nil) end
                end
            end
        end
    end
    local function attachTabReleaseBadge(tab, tabId, kind)
        if not tab or isReleaseSeen("tab", tabId) then return end
        tab:SetBadge(kind)
        local previous = tab.OnActivated
        tab.OnActivated = function()
            tab:SetBadge(nil)
            markReleaseSeen("tab", tabId)
            if type(previous) == "function" then pcall(previous) end
        end
    end


        local maintenanceEntries = {}
    local maintenanceLocks = {}

    local function registerMaintenanceControl(featureId, displayName, control, kind)
        local entry = maintenanceEntries[featureId]
        if not entry then
            entry = { Id = featureId, Name = displayName or featureId, Kind = kind, Controls = {}, Locked = false }
            maintenanceEntries[featureId] = entry
        end
        table.insert(entry.Controls, control)
        if entry.Locked and control.SetMaintenance then control.SetMaintenance(true) end
    end

    local function setMaintenanceLocked(featureId, locked)
        local entry = maintenanceEntries[featureId]
        if not entry then return end
        entry.Locked = locked == true
        if entry.Locked then
            if entry.Kind == "interactable" then
                pcall(function() interactable:SetFeatureEnabled(featureId, false) end)
            elseif featureManager.Registry[featureId] then
                pcall(function() featureManager:SetEnabled(featureId, false) end)
            end
        end
        for _, control in ipairs(entry.Controls) do
            if control.SetMaintenance then control.SetMaintenance(entry.Locked) end
            if entry.Locked and control.Set then control.Set(false, true) end
        end
    end

    local function syncFeature(featureId, enabled)
        for _, control in ipairs(featureControllers[featureId] or {}) do
            control.Set(enabled, true)
        end
    end

    local function syncInteractable(featureId, enabled)
        local entry = maintenanceEntries[featureId]
        for _, control in ipairs(entry and entry.Controls or {}) do
            if control.Set then control.Set(enabled, true) end
        end
    end

    local function addFeatureToggle(tab, featureId, definition, displayName, parent)
        if not definition then return end
        if not featureManager.Registry[featureId] then featureManager:Register(featureId, definition) end
        local control = tab:CreateToggle({
            Name = displayName or definition.Name or featureId,
            Default = featureManager:IsEnabled(featureId),
            Parent = parent,
            Callback = function(enabled)
                if enabled and maintenanceLocks[featureId] then
                    syncFeature(featureId, false)
                    return
                end
                local success, err = featureManager:SetEnabled(featureId, enabled)
                if not success then
                    warn("[Tryo Plugin Manager] " .. featureId .. ": " .. tostring(err))
                    reportRuntimeError(featureId, "beta2/Runtime/FeatureManager.lua", err)
                end
                syncFeature(featureId, featureManager:IsEnabled(featureId))
            end
        })
        featureControllers[featureId] = featureControllers[featureId] or {}
        table.insert(featureControllers[featureId], control)
        attachFeatureReleaseBadge(control, featureId)
        registerMaintenanceControl(featureId, displayName or definition.Name or featureId, control, "feature")
        return control
    end

    local function addWalkSpeed(tab)
        if not featureManager.Registry.WalkSpeed then featureManager:Register("WalkSpeed", toolFeatures.WalkSpeed) end
        if featureManager.Context.WalkSpeedTarget == nil then featureManager.Context.WalkSpeedTarget = 16 end
        local control = tab:CreateWalkSpeedControl({
            Name = "WalkSpeed",
            GetValue = function() return featureManager.Context.WalkSpeedTarget end,
            SetValue = function(value)
                local numeric = tonumber(value)
                if not numeric then return false end
                featureManager.Context.WalkSpeedTarget = math.clamp(numeric, 16, 100)
                if featureManager.Context.WalkSpeedApply then featureManager.Context.WalkSpeedApply() end
                for _, item in ipairs(walkSpeedControllers) do item.Refresh() end
                return true
            end,
            Callback = function(enabled)
                if enabled and maintenanceLocks.WalkSpeed then
                    for _, item in ipairs(walkSpeedControllers) do item.Set(false, true) end
                    return
                end
                local success, err = featureManager:SetEnabled("WalkSpeed", enabled)
                if not success then
                    warn("[Tryo Plugin Manager] WalkSpeed: " .. tostring(err))
                    reportRuntimeError("WalkSpeed", "beta2/Features/Tools.lua", err)
                end
                for _, item in ipairs(walkSpeedControllers) do item.Set(featureManager:IsEnabled("WalkSpeed"), true) end
            end
        })
        table.insert(walkSpeedControllers, control)
        attachFeatureReleaseBadge(control, "WalkSpeed")
        registerMaintenanceControl("WalkSpeed", "WalkSpeed", control, "feature")
        control.Set(featureManager:IsEnabled("WalkSpeed"), true)
    end

    local function addInteractableToggle(tab, id, name, parent)
        local control
        control = tab:CreateToggle({
            Name = name,
            Parent = parent,
            Default = false,
            Callback = function(enabled)
                if enabled and maintenanceLocks[id] then
                    control.Set(false, true)
                    return
                end
                local success, err = interactable:SetFeatureEnabled(id, enabled)
                if not success then
                    warn("[Tryo Plugin Manager] " .. id .. ": " .. tostring(err))
                    reportRuntimeError(id, "beta2/Features/Interactable.lua", err)
                end
            end
        })
        registerMaintenanceControl(id, name, control, "interactable")
        return control
    end

    -- Preset Manager is the first standalone navigation tab.
    local presetsTab = window:CreateTab("Presets", "▣")

    local mainTab = window:CreateTab("Main", "⌂")
    attachTabReleaseBadge(mainTab, "Main", "UPDATE")
    mainTab:CreateSection("QUICK ACCESS")
    local changelogButton = mainTab:CreateButton({
        Name = "Changelog!",
        Callback = function()
            if window and not window.Destroyed then window:ShowChangelog(getChangelogEntries()) end
        end
    })
    -- Subtle RGB text cycle to make updated release notes easy to notice.
    local changelogColors = {
        Color3.fromRGB(90, 220, 255),
        Color3.fromRGB(125, 125, 255),
        Color3.fromRGB(205, 115, 255),
        Color3.fromRGB(255, 125, 175),
        Color3.fromRGB(105, 235, 175),
        Color3.fromRGB(255, 205, 105)
    }
    changelogButton.TextStrokeColor3 = Color3.fromRGB(12, 17, 27)
    changelogButton.TextStrokeTransparency = 0.55
    task.spawn(function()
        local colorIndex = 1
        while changelogButton.Parent do
            local tween = TweenService:Create(
                changelogButton,
                TweenInfo.new(0.85, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                {TextColor3 = changelogColors[colorIndex]}
            )
            tween:Play()
            tween.Completed:Wait()
            colorIndex = colorIndex % #changelogColors + 1
        end
    end)
    addFeatureToggle(mainTab, "WaypointManager", waypoint, "Waypoint")
    mainTab:CreateDropdown({
        Name = "TELEPORT",
        Build = function(panel)
            addFeatureToggle(mainTab, "TeleportToPlayer", teleportFeatures.PlayerTeleport, "TELEPORT TO PLAYER", panel)
            addFeatureToggle(mainTab, "TeleportToItemUniversal", tpItem, "TELEPORT TO ITEM", panel)
        end
    })

    addWalkSpeed(mainTab)
    addFeatureToggle(mainTab, "PlayMusic", musicPlayer, "Play Music")
    mainTab:CreateDropdown({
        Name = "Rejoin",
        Build = function(panel)
            local autoSave = {
                Name = "Auto Save Server",
                Start = function()
                    if featureManager.Context.AutoSaveRunning then return true end
                    featureManager.Context.AutoSaveRunning = true
                    task.spawn(function()
                        while featureManager.Context.AutoSaveRunning do
                            pcall(lastServer.SaveCurrent)
                            task.wait(30)
                        end
                    end)
                    pcall(lastServer.SaveCurrent)
                    return true
                end,
                Stop = function() featureManager.Context.AutoSaveRunning = false end
            }
            addFeatureToggle(mainTab, "AutoSaveServer", autoSave, "Auto Save", panel)
            panel.Parent = panel.Parent
            mainTab:CreateButton({Name = "Save Server", Parent = panel, Callback = function() lastServer.SaveCurrent() end})
            mainTab:CreateButton({Name = "Last Rejoin", Parent = panel, Callback = function() lastServer.RejoinSaved() end})
            addFeatureToggle(mainTab, "SmartRejoin", smartRejoin, "Smart Rejoin", panel)
        end
    })
    mainTab:CreateDropdown({
        Name = "AIMBOT",
        Build = function(panel)
            addFeatureToggle(mainTab, "AimAssist", aimAssist, "Aimbot", panel)
            mainTab:CreateButton({Name = "Set Radius", Parent = panel, Callback = function()
                if aimAssist.OpenSettings then aimAssist.OpenSettings() end
            end})
        end
    })
    mainTab:CreateDropdown({
        Name = "F1Lock",
        Build = function(panel)
            addFeatureToggle(mainTab, "F1Lock", cameraTools.F1Lock, "F1 Toggle", panel)
            addFeatureToggle(mainTab, "ForceUnlockCamera", cameraTools.ForceUnlockCamera, "Lock Kamera", panel)
        end
    })

    local mountainTab = window:CreateTab("Gunung", "▲")
    attachTabReleaseBadge(mountainTab, "Gunung", "UPDATE")
    mountainTab:CreateSection("MOUNTAIN QUICK ACCESS")
    addFeatureToggle(mountainTab, "WaypointManager", waypoint, "Waypoint")
    addFeatureToggle(mountainTab, "PlayerESP", espFeatures.PlayerESP)
    addFeatureToggle(mountainTab, "InfiniteJump", toolFeatures.InfiniteJump)
    addFeatureToggle(mountainTab, "InstantPrompt", instantPrompt, "Instant Prompt")
    addWalkSpeed(mountainTab)
    local mountainVisualEnvironmentMenu
    mountainVisualEnvironmentMenu = mountainTab:CreateDropdown({
        Name = "Visual Environment",
        OnExpanded = function(expanded)
            if expanded and mountainVisualEnvironmentMenu then
                mountainVisualEnvironmentMenu.SetBadge(nil)
                markReleaseSeen("menu", "VisualEnvironmentGunung")
            end
        end,
        Build = function(panel)
            addFeatureToggle(mountainTab, "Fullbright", toolFeatures.Fullbright, "Brightness & Ambient", panel)
            addFeatureToggle(mountainTab, "VisualFog", toolFeatures.VisualFog, "No Fog", panel)
            addFeatureToggle(mountainTab, "VisualTime", toolFeatures.VisualTime, "Daylight", panel)
            addFeatureToggle(mountainTab, "VisualShadows", toolFeatures.VisualShadows, "Disable Shadows", panel)
            addFeatureToggle(mountainTab, "VisualPostFX", toolFeatures.VisualPostFX, "Disable Post FX", panel)
        end
    })
    if not isReleaseSeen("menu", "VisualEnvironmentGunung") then
        mountainVisualEnvironmentMenu.SetBadge("UPDATE")
    end
    addInteractableToggle(mountainTab, "PPESP", "PPESP")
    addFeatureToggle(mountainTab, "Spectate", soundViewFeatures.Spectate, "Spectator")

    local horrorTab = window:CreateTab("Horor", "◈")
    attachTabReleaseBadge(horrorTab, "Horor", "UPDATE")
    horrorTab:CreateSection("HORROR QUICK ACCESS")
    horrorTab:CreateDropdown({
        Name = "Interactable",
        Build = function(panel)
            local items = {
                {id="PPESP", name="Proximity (PPESP)"},
                {id="ITP", name="Item Teleport (ITP)"},
                {id="DESP", name="Door (DESP)"},
                {id="CDESP", name="Click (CDESP)"},
                {id="TESP", name="Touch (TESP)"},
                {id="ITESP", name="Item (ITESP)"},
                {id="LOOT", name="Loot"}
            }
            for _, item in ipairs(items) do addInteractableToggle(horrorTab, item.id, item.name, panel) end
        end
    })
    horrorTab:CreateDropdown({
        Name = "ESP",
        Build = function(panel)
            addFeatureToggle(horrorTab, "PlayerESP", espFeatures.PlayerESP, "Player ESP", panel)
            addFeatureToggle(horrorTab, "EnemyESP", espFeatures.EnemyESP, "Enemy ESP", panel)
        end
    })
    horrorTab:CreateDropdown({
        Name = "Visual Environment",
        Build = function(panel)
            addFeatureToggle(horrorTab, "Fullbright", toolFeatures.Fullbright, "Brightness & Ambient", panel)
            addFeatureToggle(horrorTab, "VisualFog", toolFeatures.VisualFog, "No Fog", panel)
            addFeatureToggle(horrorTab, "VisualTime", toolFeatures.VisualTime, "Daylight", panel)
            addFeatureToggle(horrorTab, "VisualShadows", toolFeatures.VisualShadows, "Disable Shadows", panel)
            addFeatureToggle(horrorTab, "VisualPostFX", toolFeatures.VisualPostFX, "Disable Post FX", panel)
        end
    })
    addFeatureToggle(horrorTab, "InstantPrompt", instantPrompt, "Instant Prompt")
    addFeatureToggle(horrorTab, "InfiniteJump", toolFeatures.InfiniteJump)
    addWalkSpeed(horrorTab)
    addFeatureToggle(horrorTab, "MuteMapSounds", soundViewFeatures.MuteMapSounds, "Mute Sound")
    addFeatureToggle(horrorTab, "Noclip", toolFeatures.Noclip)
    addFeatureToggle(horrorTab, "CodeFinder", codeFinder, "Code Finder")

    local toolsTab = window:CreateTab("Tools", "⚒")
    attachTabReleaseBadge(toolsTab, "Tools", "UPDATE")
    toolsTab:CreateSection("UTILITY")
    addFeatureToggle(toolsTab, "AdminDetector", adminDetector, "Admin Detect")
    addFeatureToggle(toolsTab, "NoFallDamage", toolFeatures.NoFallDamage, "No Fall Damage")
    addFeatureToggle(toolsTab, "AntiAFK", toolFeatures.AntiAFK)
    addFeatureToggle(toolsTab, "MobileInspector", toolFeatures.MobileInspector, "Inspector")
    toolsTab:CreateDropdown({
        Name = "Effect",
        Build = function(panel)
            for _, featureId in ipairs({"AnchorNearby", "AntiWind", "AntiTrigger", "AntiShake"}) do
                addFeatureToggle(toolsTab, featureId, antiDisturbFeatures[featureId], nil, panel)
            end
        end
    })

    local settingsTab = window:CreateTab("Settings", "⚙")
    settingsTab:CreateSection("APPEARANCE")
    settingsTab:CreateSizeControl({ Name = "Customize window size" })
    settingsTab:CreateGlassControl({ Name = "Glass transparency" })
    settingsTab:CreateColorWheel({ Name = "Custom theme color • Color wheel" })

    -- Slot-based Preset Manager. Five slots are shown initially; users can add more.
    local PRESET_FILE = "TryoScriptHub_Presets.json"
    local presetStore = { Version = 2, SlotCount = 5, Slots = {} }
    local presetRows = {}
    local presetControllers = {}
    local PRESET_INFO_TEXT = "Aktifkan dahulu fitur yang ingin di tambahkan ke preset, lalu masukan nama dan klik SAVE"
    local presetStatusRevision = 0
    local presetStatus = presetsTab:CreateInfo({
        Name = "PresetStatus", Height = 34,
        Text = PRESET_INFO_TEXT
    })
    local function setPresetStatus(message, isError)
        presetStatusRevision = presetStatusRevision + 1
        presetStatus.Text = tostring(message)
        presetStatus.TextColor3 = isError and Color3.fromRGB(255, 145, 145) or Color3.fromRGB(125, 225, 185)
    end
    local function setPresetSuccess(message)
        setPresetStatus(message, false)
        local revision = presetStatusRevision
        task.delay(3, function()
            if presetStatusRevision == revision and presetStatus and presetStatus.Parent then
                setPresetStatus(PRESET_INFO_TEXT, false)
            end
        end)
    end
    local function cleanPresetName(value)
        local name = tostring(value or ""):gsub("[%c]", ""):gsub("^%s+", ""):gsub("%s+$", "")
        if #name > 32 then name = name:sub(1, 32) end
        return name
    end
    local function savePresetStore()
        if type(writefile) ~= "function" then return false, "Executor tidak menyediakan writefile." end
        local okWrite, errWrite = pcall(function()
            writefile(PRESET_FILE, HttpService:JSONEncode(presetStore))
        end)
        return okWrite, okWrite and nil or tostring(errWrite)
    end
    local function snapshotPreset()
        local features = {}
        for id in pairs(featureManager.Registry) do
            features[id] = featureManager:IsEnabled(id)
        end
        return {
            Features = features,
            -- Interactable commands are outside FeatureManager, so snapshot their real runtime states separately.
            Interactables = interactable:GetStates(),
            WalkSpeedTarget = math.clamp(tonumber(featureManager.Context.WalkSpeedTarget) or 16, 16, 100),
            SavedAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            PlaceId = tostring(game.PlaceId)
        }
    end
    local function loadPresetStore()
        if type(readfile) ~= "function" or type(isfile) ~= "function" then
            return false, "Executor tidak menyediakan readfile/isfile."
        end
        if not isfile(PRESET_FILE) then return true end
        local okRead, decoded = pcall(function() return HttpService:JSONDecode(readfile(PRESET_FILE)) end)
        if not okRead or type(decoded) ~= "table" then
            return false, "File preset tidak valid atau rusak."
        end
        if type(decoded.Slots) == "table" then
            presetStore = {
                Version = 2,
                SlotCount = math.max(5, math.floor(tonumber(decoded.SlotCount) or #decoded.Slots)),
                Slots = decoded.Slots
            }
        elseif type(decoded.Presets) == "table" then
            -- Migrate the earlier named-preset format into numbered slots.
            local names = {}
            for name, data in pairs(decoded.Presets) do
                if type(name) == "string" and type(data) == "table" then table.insert(names, name) end
            end
            table.sort(names, function(a, b) return string.lower(a) < string.lower(b) end)
            presetStore.SlotCount = math.max(5, #names)
            for index, name in ipairs(names) do
                presetStore.Slots[index] = { Name = name, Data = decoded.Presets[name] }
            end
        end
        return true
    end

    local function createPresetRow(index)
        local row = Instance.new("Frame")
        row.Name = "PresetSlot_" .. tostring(index)
        row.Size = UDim2.new(1, -4, 0, 39)
        row.BackgroundColor3 = Color3.fromRGB(35, 42, 57)
        row.BorderSizePixel = 0
        row.LayoutOrder = index
        row.Parent = presetsTab.Page
        local rowCorner = Instance.new("UICorner")
        rowCorner.CornerRadius = UDim.new(0, 7)
        rowCorner.Parent = row

        local function makeText(className, properties)
            local object = Instance.new(className)
            for property, value in pairs(properties) do object[property] = value end
            object.Parent = row
            return object
        end
        local function makeAction(text, xScale, widthScale, color, callback)
            local button = makeText("TextButton", {
                Text = text, Position = UDim2.new(xScale, 0, 0, 5),
                Size = UDim2.new(widthScale, -4, 0, 29),
                BackgroundColor3 = color, BorderSizePixel = 0,
                TextColor3 = Color3.fromRGB(245, 248, 255),
                Font = Enum.Font.GothamBold, TextSize = 10,
                AutoButtonColor = true
            })
            local cr = Instance.new("UICorner")
            cr.CornerRadius = UDim.new(0, 5)
            cr.Parent = button
            button.MouseButton1Click:Connect(callback)
            return button
        end
        local nameLabel = makeText("TextLabel", {
            Name = "PresetName", BackgroundTransparency = 1,
            Position = UDim2.fromOffset(10, 0), Size = UDim2.new(0.43, -10, 1, 0),
            Text = "Slot " .. tostring(index), TextColor3 = Color3.fromRGB(225, 232, 244),
            Font = Enum.Font.GothamSemibold, TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd
        })
        local nameInput = makeText("TextBox", {
            Name = "PresetNameInput", Visible = false,
            Position = UDim2.fromOffset(8, 5), Size = UDim2.new(0.43, -8, 0, 29),
            BackgroundColor3 = Color3.fromRGB(20, 26, 37), BorderSizePixel = 0,
            Text = "", PlaceholderText = "Nama preset", ClearTextOnFocus = false,
            TextColor3 = Color3.fromRGB(245, 248, 255),
            PlaceholderColor3 = Color3.fromRGB(135, 147, 168),
            Font = Enum.Font.Gotham, TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left
        })
        local inputCorner = Instance.new("UICorner")
        inputCorner.CornerRadius = UDim.new(0, 5)
        inputCorner.Parent = nameInput
        local inputPadding = Instance.new("UIPadding")
        inputPadding.PaddingLeft = UDim.new(0, 7)
        inputPadding.Parent = nameInput

        local slot = { Index = index, Frame = row }
        local editing = false
        local function updateVisual()
            local entry = presetStore.Slots[index]
            local saved = type(entry) == "table" and type(entry.Data) == "table"
            nameLabel.Visible = saved and not editing
            nameInput.Visible = (not saved) or editing
            if saved and not editing then
                nameLabel.Text = tostring(entry.Name or ("Slot " .. index))
                nameInput.Text = tostring(entry.Name or "")
            elseif not saved then
                nameInput.Text = ""
                nameInput.PlaceholderText = "Nama preset..."
            end
            if saved then
                slot.EditButton.Visible = true
                slot.LoadButton.Visible = true
                slot.DeleteButton.Visible = true
                slot.SaveButton.Visible = false
                slot.EditButton.Text = editing and "✓" or "✏"
            else
                slot.EditButton.Visible = false
                slot.LoadButton.Visible = false
                slot.DeleteButton.Visible = false
                slot.SaveButton.Visible = true
            end
        end
        slot.SaveButton = makeAction("SAVE", 0.76, 0.24, Color3.fromRGB(30, 130, 105), function()
            local name = cleanPresetName(nameInput.Text)
            if name == "" then setPresetStatus("Isi nama preset pada slot " .. index .. " terlebih dahulu.", true); return end
            presetStore.Slots[index] = { Name = name, Data = snapshotPreset() }
            local okSave, errSave = savePresetStore()
            if not okSave then
                presetStore.Slots[index] = nil
                updateVisual()
                setPresetStatus("Gagal menyimpan: " .. tostring(errSave), true)
                return
            end
            editing = false
            updateVisual()
            setPresetSuccess('Preset "' .. name .. '" telah berhasil dimasukan ke slot "' .. index .. '"')
        end)
        slot.EditButton = makeAction("✏", 0.44, 0.14, Color3.fromRGB(83, 91, 119), function()
            local entry = presetStore.Slots[index]
            if not entry then return end
            if editing then
                local newName = cleanPresetName(nameInput.Text)
                if newName == "" then setPresetStatus("Nama preset tidak boleh kosong.", true); return end
                local oldName = entry.Name
                entry.Name = newName
                local okSave, errSave = savePresetStore()
                if not okSave then entry.Name = oldName; setPresetStatus("Gagal mengganti nama: " .. tostring(errSave), true); return end
                editing = false
                updateVisual()
                setPresetStatus("Nama preset berhasil diperbarui.")
            else
                editing = true
                nameInput.Text = tostring(entry.Name or "")
                updateVisual()
                nameInput:CaptureFocus()
            end
        end)
        slot.LoadButton = makeAction("LOAD", 0.59, 0.19, Color3.fromRGB(35, 105, 155), function()
            local entry = presetStore.Slots[index]
            local data = entry and entry.Data
            if type(data) ~= "table" or type(data.Features) ~= "table" then return end
            task.spawn(function()
                local applied, skipped = 0, 0
                for id in pairs(featureManager.Registry) do
                    local target = data.Features[id]
                    if type(target) == "boolean" then
                        if target and maintenanceLocks[id] then
                            skipped = skipped + 1
                        else
                            local okSet, errSet = featureManager:SetEnabled(id, target)
                            if okSet then
                                syncFeature(id, featureManager:IsEnabled(id))
                                applied = applied + 1
                            else
                                skipped = skipped + 1
                                warn("[Tryo Plugin Manager] Preset load " .. tostring(id) .. ": " .. tostring(errSet))
                            end
                        end
                        task.wait(0.035)
                    end
                end
                -- Interactable commands are not registered in FeatureManager.
                -- Restore each saved toggle through its own command controller.
                if type(data.Interactables) == "table" then
                    for _, id in ipairs(interactable:GetFeatureIds()) do
                        local target = data.Interactables[id]
                        if type(target) == "boolean" then
                            local uiEnabled = false
                            if target and maintenanceLocks[id] then
                                skipped = skipped + 1
                            else
                                local okSet, errSet = interactable:SetFeatureEnabled(id, target)
                                if okSet then
                                    applied = applied + 1
                                    -- The command controller confirms that the requested state was applied.
                                    -- Use that result for the toggle indicator instead of a potentially stale
                                    -- internal running flag immediately after command startup.
                                    uiEnabled = target
                                else
                                    skipped = skipped + 1
                                    warn("[Tryo Plugin Manager] Preset load " .. tostring(id) .. ": " .. tostring(errSet))
                                end
                            end
                            syncInteractable(id, uiEnabled)
                            task.wait(0.035)
                        end
                    end
                end
                local speed = tonumber(data.WalkSpeedTarget)
                if speed then
                    featureManager.Context.WalkSpeedTarget = math.clamp(speed, 16, 100)
                    for _, item in ipairs(walkSpeedControllers) do item.Refresh() end
                end
                setPresetStatus("Preset '" .. tostring(entry.Name) .. "' dimuat • " .. applied .. " diterapkan" ..
                    (skipped > 0 and (" • " .. skipped .. " dilewati") or "") .. ".")
            end)
        end)
        slot.DeleteButton = makeAction("DELETE", 0.79, 0.21, Color3.fromRGB(145, 63, 72), function()
            local previousEntry = presetStore.Slots[index]
            presetStore.Slots[index] = nil
            local okSave, errSave = savePresetStore()
            if not okSave then
                presetStore.Slots[index] = previousEntry
                updateVisual()
                setPresetStatus("Gagal menghapus preset: " .. tostring(errSave), true)
                return
            end
            editing = false
            updateVisual()
            setPresetStatus("Slot " .. index .. " berhasil dikosongkan.")
        end)
        slot.SaveButton.Position = UDim2.new(0.76, 0, 0, 5)
        slot.EditButton.Position = UDim2.new(0.44, 0, 0, 5)
        slot.LoadButton.Position = UDim2.new(0.59, 0, 0, 5)
        slot.DeleteButton.Position = UDim2.new(0.79, 0, 0, 5)
        presetControllers[index] = slot
        updateVisual()
        return slot
    end

    local presetLoadOk, presetLoadError = loadPresetStore()
    if not presetLoadOk then
        setPresetStatus("Penyimpanan preset tidak tersedia: " .. tostring(presetLoadError), true)
    end
    presetStore.SlotCount = math.max(5, math.floor(tonumber(presetStore.SlotCount) or 5))
    local function refreshPresetSlots()
        for index = 1, presetStore.SlotCount do
            if not presetControllers[index] or not presetControllers[index].Frame.Parent then
                createPresetRow(index)
            end
        end
    end
    refreshPresetSlots()
    local addPresetSlotButton = presetsTab:CreateButton({
        Name = "+",
        Callback = function()
            presetStore.SlotCount = presetStore.SlotCount + 1
            refreshPresetSlots()
            -- Keep the add control after every slot, including newly-created rows.
            addPresetSlotButton.LayoutOrder = 100000
            local okSave, errSave = savePresetStore()
            if not okSave then
                setPresetStatus("Slot ditambahkan untuk sesi ini, tetapi gagal disimpan: " .. tostring(errSave), true)
            else
                setPresetStatus("Slot " .. presetStore.SlotCount .. " berhasil ditambahkan.")
            end
        end
    })
    -- A high order value prevents the + control from being trapped above future slots.
    addPresetSlotButton.LayoutOrder = 100000
    addPresetSlotButton.TextXAlignment = Enum.TextXAlignment.Center
    addPresetSlotButton.TextSize = 20
    addPresetSlotButton.Font = Enum.Font.GothamBold
    addPresetSlotButton.BackgroundColor3 = Color3.fromRGB(42, 55, 76)

    local function applyMaintenanceSnapshot(metadata)
        for id, entry in pairs(maintenanceEntries) do
            local raw = metadata["FeatureMaintenance_" .. tostring(id)]
            local locked = raw ~= nil and tostring(raw) ~= "ACTIVE"
            maintenanceLocks[id] = locked
            setMaintenanceLocked(id, locked)
        end
    end

    local function refreshPublicMaintenance()
        local okMeta, metadata = pcall(function()
            local body = game:HttpGet(METADATA_URL .. "?_=" .. tostring(DateTime.now().UnixTimestampMillis))
            local decoded = HttpService:JSONDecode(body or "{}")
            assert(type(decoded) == "table", "Invalid maintenance metadata")
            return decoded
        end)
        if not okMeta then
            warn("[Tryo Plugin Manager] Maintenance sync failed: " .. tostring(metadata))
            return false
        end
        applyMaintenanceSnapshot(metadata)
        return true
    end

    -- Private Admin tab: only UserIds in ADMIN_USER_IDS receive the tab.
    if ADMIN_USER_IDS[LocalPlayer.UserId] then
        local adminTab = window:CreateTab("Admin", "🛡")
        adminTab:CreateSection("ADMIN ACCESS")
        local adminKeyInput = adminTab:CreateTextInput({
            Name = "Apps Script Admin Key",
            Placeholder = "Masukkan Admin Key (tidak disimpan)"
        })
        local adminStatus = adminTab:CreateInfo({
            Name = "AdminStatus",
            Height = 38,
            Text = "Admin siap. Masukkan Admin Key untuk mengubah maintenance."
        })

        local function setAdminStatus(message, isError)
            if adminStatus and adminStatus.Parent then
                adminStatus.Text = tostring(message)
                adminStatus.TextColor3 = isError and Color3.fromRGB(255, 145, 145) or Color3.fromRGB(125, 225, 185)
            end
        end

        local function readAdminMetadata()
            local response = game:HttpGet(METADATA_URL .. "?_=" .. tostring(DateTime.now().UnixTimestampMillis))
            local decoded = HttpService:JSONDecode(response or "{}")
            assert(type(decoded) == "table", "Metadata server mengembalikan JSON tidak valid.")
            return decoded
        end

        local function postAdmin(payload)
            local req = request or http_request or (syn and syn.request)
            if type(req) ~= "function" then return false, "Executor tidak menyediakan HTTP request." end
            payload.AdminKey = tostring(adminKeyInput.Text or "")
            if payload.AdminKey == "" then return false, "Masukkan Admin Key terlebih dahulu." end
            local okPost, response = pcall(function()
                return req({
                    Url = METADATA_URL,
                    Method = "POST",
                    Headers = { ["Content-Type"] = "application/json" },
                    Body = HttpService:JSONEncode(payload),
                    FollowRedirects = true
                })
            end)
            if not okPost or not response then return false, tostring(response or "Server tidak merespons.") end
            local body = type(response) == "table" and (response.Body or response.body or response.ResponseBody) or nil
            if type(body) == "string" and body ~= "" then
                local decoded = nil
                pcall(function() decoded = HttpService:JSONDecode(body) end)
                if type(decoded) == "table" and decoded.status == "error" then
                    return false, tostring(decoded.message or "Server menolak permintaan.")
                end
            end
            return true, response
        end

        local maintenanceRows = {}
        local function updateMaintenanceRow(entry)
            local button = maintenanceRows[entry.Id]
            if not button or not button.Parent then return end
            button.Text = (entry.Locked and "🔴  " or "🟢  ") .. entry.Name ..
                (entry.Locked and "  •  MAINTENANCE" or "  •  ACTIVE")
            button.BackgroundColor3 = entry.Locked and Color3.fromRGB(92, 43, 52) or Color3.fromRGB(38, 76, 66)
        end

        local function refreshMaintenance()
            local okMeta, metadata = pcall(readAdminMetadata)
            if not okMeta then
                setAdminStatus("Gagal membaca status maintenance: " .. tostring(metadata), true)
                return false
            end
            applyMaintenanceSnapshot(metadata)
            for _, entry in pairs(maintenanceEntries) do updateMaintenanceRow(entry) end
            local featureCount = 0
            for _ in pairs(maintenanceEntries) do featureCount = featureCount + 1 end
            setAdminStatus("Status maintenance tersinkron • " .. tostring(featureCount) .. " fitur.")
            return true
        end

        adminTab:CreateSection("FEATURE MAINTENANCE")
        adminTab:CreateInfo({
            Height = 42,
            Text = "Matikan fitur secara online. Pengguna akan melihat badge MAINTENANCE dan tidak dapat mengaktifkannya."
        })
        local maintenanceDropdown = adminTab:CreateDropdown({
            Name = "MANAGE PUBLIC FEATURES",
            Build = function(panel)
                local entries = {}
                for _, entry in pairs(maintenanceEntries) do table.insert(entries, entry) end
                table.sort(entries, function(a, b) return string.lower(a.Name) < string.lower(b.Name) end)
                for _, entry in ipairs(entries) do
                    local row = adminTab:CreateButton({
                        Name = entry.Name .. "  •  ACTIVE",
                        Parent = panel,
                        Callback = function()
                            local targetEnabled = entry.Locked
                            setAdminStatus("Mengirim perubahan maintenance: " .. entry.Name .. "...")
                            task.spawn(function()
                                local sent, response = postAdmin({
                                    Type = "FeatureMaintenance",
                                    FeatureId = entry.Id,
                                    Enabled = targetEnabled
                                })
                                if not sent then
                                    setAdminStatus("Gagal: " .. tostring(response), true)
                                    return
                                end
                                local verified = false
                                for attempt = 1, 5 do
                                    task.wait(0.35)
                                    local okMeta, metadata = pcall(readAdminMetadata)
                                    if okMeta then
                                        local key = "FeatureMaintenance_" .. tostring(entry.Id)
                                        local actual = tostring(metadata[key] or "")
                                        local expected = targetEnabled and "ACTIVE" or ""
                                        if actual == expected then
                                            applyMaintenanceSnapshot(metadata)
                                            for _, currentEntry in pairs(maintenanceEntries) do updateMaintenanceRow(currentEntry) end
                                            verified = true
                                            break
                                        end
                                    end
                                end
                                if verified then
                                    setAdminStatus(entry.Name .. (targetEnabled and " kembali ACTIVE." or " masuk MAINTENANCE."))
                                else
                                    setAdminStatus("Server belum mengonfirmasi perubahan " .. entry.Name .. ".", true)
                                end
                            end)
                        end
                    })
                    maintenanceRows[entry.Id] = row
                end
            end
        })

        adminTab:CreateSection("DIAGNOSTICS")
        adminTab:CreateInfo({
            Height = 42,
            Text = "Health Check memeriksa source yang digunakan hub. Runtime Error menampilkan laporan error yang tercatat di server."
        })

        local healthPanel
        adminTab:CreateDropdown({
            Name = "HEALTH CHECK RESULTS",
            Build = function(panel) healthPanel = panel end
        })
        local runtimePanel
        adminTab:CreateDropdown({
            Name = "RUNTIME ERROR LOG",
            Build = function(panel) runtimePanel = panel end
        })

        local function clearDiagnosticPanel(panel)
            if not panel then return end
            for _, child in ipairs(panel:GetChildren()) do
                if child:IsA("GuiObject") and not child:IsA("UIListLayout") then child:Destroy() end
            end
        end

        local function addDiagnosticInfo(panel, text, failed)
            if not panel then return end
            adminTab:CreateInfo({
                Parent = panel,
                Height = 43,
                Text = text,
                Color = failed and Color3.fromRGB(255, 145, 145) or Color3.fromRGB(135, 225, 185),
                Background = failed and Color3.fromRGB(73, 39, 48) or Color3.fromRGB(34, 62, 57),
                TextSize = 9
            })
        end

        local function runHealthCheck()
            clearDiagnosticPanel(healthPanel)
            setAdminStatus("Menjalankan Health Check...")
            local names = {}
            for name in pairs(loadedModuleSources) do table.insert(names, name) end
            table.sort(names)
            local checks, errors = 0, 0
            for _, name in ipairs(names) do
                local item = loadedModuleSources[name]
                local success, source = pcall(function()
                    return game:HttpGet(item.Url .. "?_=" .. tostring(DateTime.now().UnixTimestampMillis))
                end)
                checks = checks + 1
                if not success or type(source) ~= "string" or source == "" then
                    errors = errors + 1
                    addDiagnosticInfo(healthPanel, "[ERROR] " .. name .. " • gagal diunduh: " .. tostring(source), true)
                else
                    local compiled, chunk = pcall(loadstring, source, "HealthCheck/" .. name)
                    local valid = compiled and type(chunk) == "function"
                    if not valid then errors = errors + 1 end
                    addDiagnosticInfo(healthPanel,
                        (valid and "[OK] " or "[ERROR] ") .. name .. (valid and (" • compile OK • " .. tostring(#source) .. " byte") or (" • compile gagal: " .. tostring(chunk))),
                        not valid)
                end
                task.wait(0.04)
            end
            local mainOk, mainSource = pcall(function()
                return game:HttpGet(BASE_URL .. "Main.lua?_=healthcheck")
            end)
            checks = checks + 1
            if not mainOk or type(mainSource) ~= "string" or mainSource == "" then
                errors = errors + 1
                addDiagnosticInfo(healthPanel, "[ERROR] Main.lua • gagal diunduh: " .. tostring(mainSource), true)
            else
                local compiled, chunk = pcall(loadstring, mainSource, "HealthCheck/Main.lua")
                local valid = compiled and type(chunk) == "function"
                if not valid then errors = errors + 1 end
                addDiagnosticInfo(healthPanel,
                    (valid and "[OK] " or "[ERROR] ") .. "Main.lua" .. (valid and (" • compile OK • " .. tostring(#mainSource) .. " byte") or (" • compile gagal: " .. tostring(chunk))),
                    not valid)
            end
            setAdminStatus("Health Check selesai • " .. tostring(checks) .. " pemeriksaan • " .. tostring(errors) .. " error.", errors > 0)
        end

        local function loadRuntimeErrors()
            clearDiagnosticPanel(runtimePanel)
            setAdminStatus("Mengambil Runtime Error terbaru...")
            local okFetch, body = pcall(function()
                return game:HttpGet(METADATA_URL .. "?action=PluginErrors&limit=50&_=" .. tostring(DateTime.now().UnixTimestampMillis))
            end)
            if not okFetch then
                addDiagnosticInfo(runtimePanel, "[ERROR] Gagal mengambil log: " .. tostring(body), true)
                setAdminStatus("Runtime Error gagal dimuat.", true)
                return
            end
            local decoded
            local okDecode = pcall(function() decoded = HttpService:JSONDecode(body) end)
            if not okDecode or type(decoded) ~= "table" or decoded.status ~= "success" or type(decoded.records) ~= "table" then
                addDiagnosticInfo(runtimePanel, "[ERROR] Respons log tidak valid: " .. tostring(body), true)
                setAdminStatus("Respons Runtime Error tidak valid.", true)
                return
            end
            if #decoded.records == 0 then
                addDiagnosticInfo(runtimePanel, "Belum ada laporan runtime error.", false)
            end
            for index, record in ipairs(decoded.records) do
                local title = tostring(record.Plugin or record.Command or "Plugin Error")
                local command = tostring(record.Command or "")
                local errorText = tostring(record.Error or "Tidak ada detail")
                local source = tostring(record.Source or record.Timestamp or "")
                addDiagnosticInfo(runtimePanel,
                    string.format("[%02d] %s%s\n%s\n%s", index, title, command ~= "" and (" • " .. command) or "", errorText, source),
                    true)
            end
            setAdminStatus("Runtime Error dimuat • " .. tostring(#decoded.records) .. " laporan.")
        end

        adminTab:CreateButton({Name = "RUN HEALTH CHECK", Callback = function()
            task.spawn(runHealthCheck)
        end})
        adminTab:CreateButton({Name = "LOAD RUNTIME ERRORS", Callback = function()
            task.spawn(loadRuntimeErrors)
        end})
        adminTab:CreateButton({Name = "REFRESH MAINTENANCE", Callback = function()
            task.spawn(refreshMaintenance)
        end})

        task.spawn(refreshMaintenance)
    end

    task.spawn(refreshPublicMaintenance)
    task.spawn(function()
        while window and not window.Destroyed do
            task.wait(30)
            if not window or window.Destroyed then break end
            refreshPublicMaintenance()
        end
    end)

    if window.Gui then
        window.Gui.Destroying:Connect(function()
            -- Do not synchronously stop every enabled feature inside the GUI
            -- destruction event; that creates a visible close-button hitch.
            task.spawn(function()
                featureManager:DestroyAsync()
                task.wait()
                pcall(function() interactable:Stop() end)
            end)
        end)
    end

    -- Remove the temporary loading page after all feature tabs are ready.
    for index, tab in ipairs(window.Tabs) do
        if tab == loadingTab then table.remove(window.Tabs, index); break end
    end
    loadingTab.Button:Destroy()
    loadingTab.Page:Destroy()
    if window.Tabs[1] then window.Tabs[1]:Activate() end

    return window
end)

if not ok then
    warn("[Tryo Plugin Manager beta2] " .. tostring(result))
end
