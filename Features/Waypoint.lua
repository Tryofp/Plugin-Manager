-- Tryo beta2 Waypoint / Checkpoint Manager
-- Standalone implementation. No Infinite Yield dependency.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local LocalPlayer = Players.LocalPlayer
local FILE_NAME = "TeleportCP_MasterSaves.json"
local HEIGHT_OFFSET = 1
local IGNORE = {
    "teleport","tp","tele","coin","gold","reward","cash","money","gem","stop","jump","ready","inner","outer","damage",
    "time","seluncur","remove","clone","seat","laying","down","fall","jatuh","chat","block","boost","cave","lake","goa",
    "tutorial","hit","same","spin","kill","brick","birhday","gift","fun","needoh","rintangan","tanjakan","maut","uang",
    "join","community","komunitas","enter","handle","squish","stand","adminzone","run","jaw","sphere","lompat","long",
    "pop","boat","bot","crocodile","alligator","mob","npc","monster","animal","pet","zombie","boss","bear","sky",
    "skypart","skybox","cloud","atmosphere","barrier","invisible","boundary","tree","pohon","branch","trunk","foliage",
    "leaf","leaves","mushroom","axe","ice","shell","cookie","stick","fence","pagar","bridge","jembatan","ladder","stair",
    "tangga","fog","hat","skip","skipboard","wood","stone","rock","batu","bambu","raft","platform","floor","step",
    "pijakan","slime","camera","wax","lamp","lantern","light","street lamp","speaker","audio","music","sound","fx",
    "effect","butter","head","torso","humanoid","character","arm","leg","face","hair","holder","neon","oreo","view",
    "prop","decoration","wall","roof","ceiling","window","door","table","chair","badge","particle","sparkle","fire",
    "smoke","cewe","cowo","refresh","ava","chinese","bubble","ball","chinematic","cinematic","dance","male","female",
    "outfit","suguhan","big","small","sesi","trend","potret","player","douyin","jurnal","pedang"
}

local Feature = { Name = "Waypoint / Checkpoint Manager" }
local active = false
local connections = {}
local cache = {}
local saved = {}
local plainNumbers = {}
local visitedKeys = {}
local gui, panel, list, nameBox, promptFrame, reopenButton
local publicToolbar, publicRouteNameBox, publicSearchBox, publicStatus
local publicRoutes, publicBusy = {}, false
local WAYPOINT_API = "https://script.google.com/macros/s/AKfycbxJzU3MiL_o9PjkF4h-prSw-P8vLVfJqGFXM7pFJOPzIzJXaGmu6z6oK0oJl54a6bQy0Q/exec"
local page = "RADAR"
local scanBusy = false
local refreshQueued = false
local dragAction = "TryoWaypointDrag_" .. tostring(LocalPlayer.UserId)
local dragging = false
local dragInput, dragStart, frameStart
local reopenDragging, reopenDragInput, reopenDragStart, reopenButtonStart
local reopenWasDragged = false
local reopenDragAction = dragAction .. "_Toggle"

local function waypointRequest(method, url, payload)
    local req = (syn and syn.request) or (http and http.request) or http_request or request
    if type(req) ~= "function" then return nil, "Executor tidak mendukung HTTP request." end
    local ok, response = pcall(req, {Url=url, Method=method, Headers={["Content-Type"]="application/json"}, Body=payload and HttpService:JSONEncode(payload) or nil})
    if not ok then return nil, tostring(response) end
    local code = tonumber(response.StatusCode or response.Status or 0) or 0
    if code >= 400 then return nil, "HTTP "..tostring(code) end
    local decodedOk, decoded = pcall(function() return HttpService:JSONDecode(response.Body or response.body or "") end)
    if not decodedOk or type(decoded) ~= "table" then return nil, "Respons server tidak valid." end
    if decoded.status == "error" then return nil, tostring(decoded.message or "Permintaan gagal.") end
    return decoded
end

local function waypointGet(action, params)
    local q = {"action="..HttpService:UrlEncode(action)}
    for k,v in pairs(params or {}) do table.insert(q,HttpService:UrlEncode(k).."="..HttpService:UrlEncode(tostring(v))) end
    return waypointRequest("GET",WAYPOINT_API.."?"..table.concat(q,"&"))
end

local function waypointPost(data)
    data.Type = "WaypointRoute"
    return waypointRequest("POST",WAYPOINT_API,data)
end

local function publicMessage(message, failed)
    if publicStatus and publicStatus.Parent then
        publicStatus.Text=tostring(message or "")
        publicStatus.TextColor3=failed and Color3.fromRGB(255,135,135) or Color3.fromRGB(170,220,190)
    end
end

local function loadPublicRoutes()
    if publicBusy then return end
    publicBusy=true
    publicMessage("Memuat rute publik...")
    task.spawn(function()
        local result,err=waypointGet("WaypointRoutes",{placeId=game.PlaceId,limit=100})
        if result and type(result.routes)=="table" then
            publicRoutes=result.routes
            publicMessage("Ditemukan "..#publicRoutes.." rute.")
            if page=="PUBLIC MAP" then Feature.RefreshUI() end
        else publicMessage(err or "Gagal memuat rute.",true) end
        publicBusy=false
    end)
end

local function uploadPublicRoute()
    if publicBusy then return end
    if #saved==0 then notify("SAVED masih kosong."); return end
    local name=string.gsub((publicRouteNameBox and publicRouteNameBox.Text) or "","^%s*(.-)%s*$","%1")
    if name=="" then notify("Isi nama rute terlebih dahulu."); return end
    local points={}
    for _,item in ipairs(saved) do
        if type(item.cf)=="table" and #item.cf>=3 then
            local p=CFrame.new(unpack(item.cf)).Position
            table.insert(points,{key=tostring(item.key or (#points+1)),x=p.X,y=p.Y,z=p.Z})
        end
    end
    if #points==0 or #points>300 then notify("Rute harus berisi 1–300 checkpoint."); return end
    publicBusy=true
    publicMessage("Mengunggah "..#points.." checkpoint...")
    task.spawn(function()
        local result,err=waypointPost({Method="UPLOAD",PlaceId=game.PlaceId,RouteName=name,MapName=tostring(game.Name):sub(1,120),UploaderId=tostring(LocalPlayer.UserId),UploaderName=tostring(LocalPlayer.Name),Waypoints=points})
        if result then
            publicMessage("Upload berhasil: "..tostring(result.totalCP or #points).." CP.")
            publicRouteNameBox.Text=""
        else publicMessage(err or "Upload gagal.",true) end
        publicBusy=false
        if result then loadPublicRoutes() end
    end)
end

local function importPublicRoute(route)
    if publicBusy then return end
    publicBusy=true
    publicMessage("Mengunduh rute...")
    task.spawn(function()
        local result,err=waypointGet("WaypointRouteGet",{placeId=game.PlaceId,routeId=route.RouteId})
        local record=result and result.route
        if not record or type(record.Waypoints)~="table" then
            publicMessage(err or "Data rute tidak tersedia.",true); publicBusy=false; return
        end
        local added=0
        for _,point in ipairs(record.Waypoints) do
            local x,y,z=tonumber(point.x),tonumber(point.y),tonumber(point.z)
            if x and y and z then
                local cf=CFrame.new(x,y,z); local duplicate=false
                for _,item in ipairs(saved) do
                    if item.cf and (CFrame.new(unpack(item.cf)).Position-cf.Position).Magnitude<2 then duplicate=true; break end
                end
                if not duplicate then
                    local key=tostring(point.key or (#saved+1))
                    table.insert(saved,{key=key,desc="Public: "..tostring(record.RouteName or "Route").." / CP "..key,cf={cf:GetComponents()},plain=false})
                    added=added+1
                end
            end
        end
        table.sort(saved,function(a,b) local na,nb=tonumber(a.key),tonumber(b.key); if na and nb then return na<nb end; if na then return true end; if nb then return false end; return tostring(a.key)<tostring(b.key) end)
        persist()
        publicMessage("Download selesai: "..added.." CP baru.")
        notify("Public Map: "..added.." CP diimpor.")
        publicBusy=false
    end)
end

local function removePublicRoute(route)
    if publicBusy then return end
    publicBusy=true
    publicMessage("Menghapus rute...")
    task.spawn(function()
        local result,err=waypointPost({Method="DELETE",PlaceId=game.PlaceId,RouteId=route.RouteId,UploaderId=tostring(LocalPlayer.UserId)})
        if result then publicMessage("Rute berhasil dihapus.") else publicMessage(err or "Gagal menghapus.",true) end
        publicBusy=false
        if result then loadPublicRoutes() end
    end)
end

local function connect(signal, callback)
    local c = signal:Connect(callback)
    table.insert(connections, c)
    return c
end

local function notify(message)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "Waypoint Manager",
            Text = tostring(message),
            Duration = 2
        })
    end)
end

local function isIgnored(name)
    local lower = string.lower(tostring(name or ""))
    for _, word in ipairs(IGNORE) do
        if string.find(lower, word, 1, true) then return true end
    end
    return false
end

local function getHRP()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getPart(object)
    if not object then return nil end
    if object:IsA("BasePart") then return object end
    if object:IsA("Model") then
        return object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart", true)
    end
    return nil
end

local function getPath(object)
    local names = {}
    local current = object
    for _ = 1, 6 do
        if not current or current == Workspace then break end
        table.insert(names, 1, current.Name)
        current = current.Parent
    end
    return table.concat(names, ".")
end

local function folderContext(part)
    local current = part
    while current and current ~= Workspace do
        local n = string.lower(current.Name)
        if string.find(n, "gunung", 1, true) or string.find(n, "jalur", 1, true)
            or string.find(n, "track", 1, true) or string.find(n, "path", 1, true)
            or string.find(n, "route", 1, true) or string.find(n, "checkpoint", 1, true) then
            return current.Name
        end
        current = current.Parent
    end
    return "Main"
end

local function isZoneCheckpoint(object)
    if not object or not object:IsA("BasePart") then return false end
    if not tonumber(object.Name) or not string.match(object.Name, "^%d+$") then return false end
    local parent = object.Parent
    local zoneFolder = parent and parent.Parent
    return parent and string.lower(parent.Name) == "checkpoints"
        and zoneFolder and string.lower(zoneFolder.Name) == "zones"
end

local function getValidCheckpointPart(obj)
    if not obj or not (obj:IsA("BasePart") or obj:IsA("Model")) then return nil end
    if isZoneCheckpoint(obj) then return obj end
    if isIgnored(obj.Name) then return nil end
    local touch = obj:FindFirstChild("TouchInterest") or obj:FindFirstChildOfClass("TouchTransmitter")
    local prompt = obj:FindFirstChildOfClass("ProximityPrompt") or obj:FindFirstChildWhichIsA("ProximityPrompt", true)
    if touch or prompt then
        if obj:IsA("Model") then
            return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
        end
        return obj
    end
    for _, descendant in ipairs(obj:GetDescendants()) do
        if descendant:IsA("BasePart") and not isIgnored(descendant.Name) then
            if descendant:FindFirstChild("TouchInterest") or descendant:FindFirstChildOfClass("TouchTransmitter")
                or descendant:FindFirstChildOfClass("ProximityPrompt") then
                return descendant
            end
        end
    end
    return nil
end

local function parseCheckpoint(object)
    if not object or not (object:IsA("BasePart") or object:IsA("Model")) then return nil end
    -- QUEST path checkpoints: Workspace.QUEST.CP<number>.Part.
    -- The ProximityPrompt may be attached to the CP container, not the Part itself.
    if object:IsA("BasePart") and string.lower(object.Name) == "part" then
        local cpContainer = object.Parent
        local questFolder = cpContainer and cpContainer.Parent
        if cpContainer and questFolder and string.lower(questFolder.Name) == "quest"
            and string.lower(cpContainer.Name) == "cpsummit" then
            return "SUMMIT", "QUEST - SUMMIT", object, 10, false
        end
        local cpNumber = cpContainer and string.match(string.lower(cpContainer.Name), "^cp(%d+)$")
        if cpNumber and questFolder and string.lower(questFolder.Name) == "quest" then
            local number = tonumber(cpNumber)
            if number and number <= 500 then
                return number, "QUEST - " .. cpContainer.Name, object, 3, false
            end
        end
    end

    -- Decimal route checkpoints: Workspace.CP1_1.CheckPoints.AuraCP1_1
    -- Use the AuraCP BasePart directly; these parts may not have TouchInterest/ProximityPrompt.
    if object:IsA("BasePart") then
        local routeParent = object.Parent
        local routeFolder = routeParent and routeParent.Parent
        local routeGroup = routeFolder and string.match(routeFolder.Name, "^CP(%d+)_(%d+)$")
        local auraMajor, auraMinor = string.match(object.Name, "^AuraCP(%d+)_(%d+)$")
        if routeParent and string.lower(routeParent.Name) == "checkpoints"
            and routeGroup and auraMajor and auraMinor
            and routeGroup == auraMajor .. "_" .. auraMinor then
            local major, minor = tonumber(auraMajor), tonumber(auraMinor)
            if major and minor and major <= 500 and minor <= 500 then
                return tostring(major) .. "." .. tostring(minor),
                    "CP" .. major .. "_" .. minor .. " - " .. object.Name,
                    object, 3, false, "DECIMAL_CP:" .. tostring(major) .. "_" .. tostring(minor)
            end
        end
    end

    local parent = object.Parent
    local lowerName = string.lower(object.Name)
    local lowerParent = string.lower(parent and parent.Name or "")
    local plain = lowerName == "checkpoint" and parent and lowerParent == "checkpoint"
    local zoneCheckpoint = isZoneCheckpoint(object)
    local part = getValidCheckpointPart(object)
    if not part and zoneCheckpoint then part = object end
    if not part and plain then
        part = object:IsA("BasePart") and object or (object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart", true))
    end
    if not part then return nil end

    -- Dedicated support for Workspace.CheckpointPart.Cp<number> touch checkpoints.
    -- Keep the established Summit, named CP, and plain Checkpoint rules below unchanged.
    local cpNumber = string.match(lowerName, "^cp(%d+)$")
    local checkpointPartFolder = Workspace:FindFirstChild("CheckpointPart")
    if cpNumber and object:IsA("BasePart") and parent == checkpointPartFolder
        and (object:FindFirstChild("TouchInterest") or object:FindFirstChildOfClass("TouchTransmitter")) then
        local number = tonumber(cpNumber)
        if number and number <= 500 then
            return number, "CheckpointPart - " .. object.Name, part, 3, false
        end
    end

    if lowerName=="text" or lowerParent=="text" or lowerName=="field" or lowerParent=="field"
        or lowerName=="base" or lowerParent=="base" or isIgnored(lowerName) or isIgnored(lowerParent) then return nil end
    if string.find(lowerName,"teleport",1,true) or string.find(lowerName,"tp",1,true)
        or string.find(lowerName,"tele",1,true) then return nil end

    local context=folderContext(part)
    if string.find(lowerName,"summit",1,true) or string.find(lowerParent,"summit",1,true)
        or string.find(lowerName,"peak",1,true) or string.find(lowerName,"finish",1,true)
        or string.find(lowerName,"puncak",1,true) then
        return "SUMMIT",context.." - "..object.Name,part,10,false
    end
    if string.find(lowerName,"reset",1,true) or string.find(lowerParent,"reset",1,true) then
        local path=string.lower(getPath(object))
        if string.find(path,"checkpoint",1,true) or string.find(path,"obby",1,true)
            or string.find(path,"gunung",1,true) then
            return "SUMMIT",context.." - "..object.Name,part,10,false
        end
    end
    if plain then return "CP+",parent.Name.." - "..object.Name,part,3,true end

    local guiText=""
    local guiObject=part:FindFirstChildOfClass("BillboardGui") or part:FindFirstChildOfClass("SurfaceGui")
    if not guiObject and part.Parent and part.Parent:IsA("Model") then
        guiObject=part.Parent:FindFirstChildOfClass("BillboardGui") or part.Parent:FindFirstChildOfClass("SurfaceGui")
    end
    if guiObject then
        local label=guiObject:FindFirstChildOfClass("TextLabel")
        if label and label.Text~="" then guiText=string.lower(label.Text) end
    end
    local combined=lowerParent.." "..lowerName.." "..guiText
    local number=
        string.match(combined,"checkpoints?%s*[_]?%s*(%d+%.?%d*)") or
        string.match(combined,"checkpoint(%d+%.?%d*)") or
        string.match(combined,"checkpoint%s*[_]?%s*(%d+%.?%d*)") or
        string.match(combined,"cekpoin%s*[%s_]*(%d+%.?%d*)") or
        string.match(combined,"cp%s*[_]?%s*(%d+%.?%d*)") or
        string.match(combined,"cp(%d+%.?%d*)") or
        string.match(combined,"stage%s*[_]?%s*(%d+%.?%d*)") or
        string.match(combined,"stage(%d+%.?%d*)") or
        string.match(combined,"pos%s*[_]?%s*(%d+%.?%d*)") or
        string.match(combined,"waypoint%s*[_]?%s*(%d+%.?%d*)") or
        string.match(combined,"wp%s*[_]?%s*(%d+%.?%d*)") or
        string.match(combined,"ring%s*[_]?%s*(%d+%.?%d*)")
    if not number and guiText~="" then number=string.match(guiText,"(%d+%.?%d*)") end
    if not number then number=string.match(object.Name,"^(%d+%.?%d*)$") end
    local n=tonumber(number)
    if not n or n<0 or n>500 then return nil end
    local explicit=zoneCheckpoint or string.find(combined,"checkpoint",1,true) or string.find(combined,"cekpoin",1,true)
        or string.find(combined,"cp",1,true) or string.find(combined,"waypoint",1,true)
        or string.find(combined,"wp",1,true) or string.find(combined,"stage",1,true)
        or string.find(combined,"pos",1,true)
    local priority=explicit and 3 or (string.find(combined,"ring",1,true) and 2 or 1)
    local description=object.Name
    if context~="" then description=context.." ("..object.Name..")" end
    if guiText~="" then description=context.." - "..guiText end
    return n,description,part,priority,false
end
local function getCheckpointPrompt(part)
    local current = part
    while current and current ~= Workspace do
        local prompt = current:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt then return prompt end
        if string.lower(current.Name) == "quest" then break end
        current = current.Parent
    end
    return nil
end

local function positionToken(position)
    return string.format("%.1f|%.1f|%.1f", position.X, position.Y, position.Z)
end

local function savedRouteIdentity(item)
    local desc = tostring(item and item.desc or "")
    local major, minor = string.match(desc, "[Cc][Pp](%d+)_(%d+)")
    if not major then
        major, minor = string.match(desc, "[Aa]ura[Cc][Pp](%d+)_(%d+)")
    end
    if major and minor then return "DECIMAL_CP:" .. major .. "_" .. minor end
    return nil
end

local function loadSaved()
    saved = {}
    if type(readfile) ~= "function" or type(isfile) ~= "function" then return end
    pcall(function()
        if not isfile(FILE_NAME) then return end
        local data = HttpService:JSONDecode(readfile(FILE_NAME))
        if type(data) == "table" and type(data[tostring(game.PlaceId)]) == "table" then
            saved = data[tostring(game.PlaceId)]
        end
    end)
    -- Collapse legacy duplicate saves for the same decimal-route checkpoint.
    local unique, seenRouteIds = {}, {}
    for _, item in ipairs(saved) do
        local routeId = item.id or savedRouteIdentity(item)
        if routeId then
            item.id = routeId
            if not seenRouteIds[routeId] then
                seenRouteIds[routeId] = true
                table.insert(unique, item)
            end
        else
            table.insert(unique, item)
        end
    end
    saved = unique

    local used = {}
    for _, item in ipairs(saved) do
        local n = tonumber(item.key)
        if n and not item.plain then used[n] = true end
    end
    local plains = {}
    for _, item in ipairs(saved) do
        if item.cf and (item.plain or item.key == "CP+" or item.desc == "Checkpoint - Checkpoint") then
            table.insert(plains, item)
        end
    end
    table.sort(plains, function(a,b)
        local ap = CFrame.new(unpack(a.cf)).Position
        local bp = CFrame.new(unpack(b.cf)).Position
        if ap.Y == bp.Y then return ap.X == bp.X and ap.Z < bp.Z or ap.X < bp.X end
        return ap.Y < bp.Y
    end)
    local nextNumber = 1
    for _, item in ipairs(plains) do
        while used[nextNumber] do nextNumber = nextNumber + 1 end
        item.key, item.plain = nextNumber, true
        plainNumbers[positionToken(CFrame.new(unpack(item.cf)).Position)] = nextNumber
        used[nextNumber] = true
        nextNumber = nextNumber + 1
    end
end

local function persist()
    if type(writefile) ~= "function" then return false end
    local ok = pcall(function()
        local all = {}
        if type(readfile) == "function" and type(isfile) == "function" and isfile(FILE_NAME) then
            local decoded = HttpService:JSONDecode(readfile(FILE_NAME))
            if type(decoded) == "table" then all = decoded end
        end
        all[tostring(game.PlaceId)] = saved
        writefile(FILE_NAME, HttpService:JSONEncode(all))
    end)
    return ok
end

local function refresh()
    if refreshQueued then return end
    refreshQueued = true
    task.delay(0.15, function()
        refreshQueued = false
        if active and gui and gui.Parent then
            Feature.RefreshUI()
        end
    end)
end

local function assignPlainNumbers()
    local used = {}
    for _, item in ipairs(saved) do
        local n = tonumber(item.key)
        if n then used[n] = true end
    end
    local pending = {}
    for _, data in pairs(cache) do
        if data.plain and data.part and data.part.Parent then
            local token = positionToken(data.part.Position)
            if plainNumbers[token] then data.number = plainNumbers[token]
            elseif not data.number then table.insert(pending, data) end
        end
    end
    local hrp = getHRP()
    table.sort(pending, function(a,b)
        if hrp then
            local da = (a.part.Position - hrp.Position).Magnitude
            local db = (b.part.Position - hrp.Position).Magnitude
            if math.abs(da-db) > 0.01 then return da < db end
        end
        local ap,bp=a.part.Position,b.part.Position
        if ap.Y==bp.Y then
            if ap.X==bp.X then return ap.Z<bp.Z end
            return ap.X<bp.X
        end
        return ap.Y<bp.Y
    end)
    for _, data in ipairs(pending) do
        local token = positionToken(data.part.Position)
        local n = plainNumbers[token]
        if not n then
            n = 1
            while used[n] do n = n + 1 end
            plainNumbers[token] = n
        end
        data.number = n
        used[n] = true
    end
end

local plainNumberingGeneration=0
local function queuePlainNumbering()
    plainNumberingGeneration=plainNumberingGeneration+1
    local generation=plainNumberingGeneration
    task.delay(0.6,function()
        if not active or generation~=plainNumberingGeneration then return end
        assignPlainNumbers()
        refresh()
    end)
end

local function checkpointKeyLess(a, b)
    local aMajor, aMinor = string.match(tostring(a), "^(%d+)%.(%d+)$")
    local bMajor, bMinor = string.match(tostring(b), "^(%d+)%.(%d+)$")
    if aMajor and bMajor then
        aMajor, aMinor = tonumber(aMajor), tonumber(aMinor)
        bMajor, bMinor = tonumber(bMajor), tonumber(bMinor)
        if aMajor ~= bMajor then return aMajor < bMajor end
        return aMinor < bMinor
    end
    local na, nb = tonumber(a), tonumber(b)
    if na and nb then return na < nb end
    if na then return true end
    if nb then return false end
    return tostring(a) < tostring(b)
end

local function addSaved(key, description, cf, isPlain, identity)
    local pos = cf.Position
    local visitKey=tostring(key).."_"..math.floor(pos.X).."_"..math.floor(pos.Y).."_"..math.floor(pos.Z)
    visitedKeys[visitKey]=true
    identity = identity or savedRouteIdentity({desc=description})
    if identity then
        for _, item in ipairs(saved) do
            local existingId = item.id or savedRouteIdentity(item)
            if existingId == identity then
                item.id = identity
                item.key, item.desc, item.cf, item.plain = key, description, {cf:GetComponents()}, isPlain == true
                persist()
                refresh()
                return
            end
        end
    else
        for _, item in ipairs(saved) do
            if not item.id and item.cf and (CFrame.new(unpack(item.cf)).Position - pos).Magnitude < 3 then
                item.key, item.desc, item.cf, item.plain = key, description, {cf:GetComponents()}, isPlain == true
                persist()
                refresh()
                return
            end
        end
    end
    table.insert(saved, {key=key, desc=description, cf={cf:GetComponents()}, plain=isPlain == true, id=identity})
    table.sort(saved, function(a,b)
        return checkpointKeyLess(a.key, b.key)
    end)
    persist()
    refresh()
    notify("Tersimpan: " .. tostring(key))
end

local function saveFromData(data)
    if not data or not data.part or not data.part.Parent then return end
    assignPlainNumbers()
    local key = data.plain and (data.number or 1) or data.key
    addSaved(key, data.desc, data.part.CFrame, data.plain, data.identity)
end

local function teleportTo(cf)
    local character = LocalPlayer.Character
    local root = getHRP()
    if not character or not root then notify("Karakter belum siap"); return end
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    character:PivotTo(cf + Vector3.new(0, HEIGHT_OFFSET, 0))
end

local function make(className, props, parent)
    local object = Instance.new(className)
    for k,v in pairs(props or {}) do object[k] = v end
    object.Parent = parent
    return object
end

local function corner(object, radius)
    make("UICorner", {CornerRadius=UDim.new(0,radius or 7)}, object)
end

local function button(parent, text, size, position, callback, accent)
    local b = make("TextButton", {
        Text=text, Size=size, Position=position, BackgroundColor3=accent and Color3.fromRGB(93,78,145) or Color3.fromRGB(43,53,72),
        BackgroundTransparency=0.12, TextColor3=Color3.fromRGB(238,241,250),
        Font=Enum.Font.GothamMedium, TextSize=11, BorderSizePixel=0, AutoButtonColor=true
    }, parent)
    corner(b,6)
    b.MouseButton1Click:Connect(callback)
    return b
end

local function showNamePrompt()
    if promptFrame then promptFrame:Destroy() end
    promptFrame = make("Frame", {
        Size=UDim2.fromOffset(260,125), Position=UDim2.new(0.5,-130,0.5,-62),
        BackgroundColor3=Color3.fromRGB(29,36,52), BackgroundTransparency=0.08, BorderSizePixel=0, ZIndex=20
    }, gui)
    corner(promptFrame,9)
    make("UIStroke",{Color=Color3.fromRGB(116,137,181),Transparency=0.45},promptFrame)
    make("TextLabel",{Text="Nama waypoint manual",Position=UDim2.fromOffset(12,8),Size=UDim2.new(1,-24,0,22),BackgroundTransparency=1,TextColor3=Color3.fromRGB(238,241,250),Font=Enum.Font.GothamBold,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=21},promptFrame)
    nameBox = make("TextBox",{Text="",PlaceholderText="Contoh: Pos Istirahat",Position=UDim2.fromOffset(12,36),Size=UDim2.new(1,-24,0,30),BackgroundColor3=Color3.fromRGB(43,53,72),TextColor3=Color3.new(1,1,1),PlaceholderColor3=Color3.fromRGB(150,156,174),Font=Enum.Font.Gotham,TextSize=12,ClearTextOnFocus=false,ZIndex=21},promptFrame)
    corner(nameBox,6)
    button(promptFrame,"SAVE",UDim2.fromOffset(105,27),UDim2.fromOffset(12,82),function()
        local text = string.gsub(nameBox.Text or "", "^%s*(.-)%s*$", "%1")
        if text ~= "" then
            local root = getHRP()
            if root then addSaved("", text, root.CFrame, false) end
        end
        promptFrame:Destroy(); promptFrame=nil
    end,true).ZIndex = 21
    button(promptFrame,"CANCEL",UDim2.fromOffset(105,27),UDim2.new(1,-117,0,82),function()
        promptFrame:Destroy(); promptFrame=nil
    end,false).ZIndex = 21
end

local function getThemeAccent()
    local fallback = Color3.fromRGB(139, 92, 246)
    if type(readfile) ~= "function" or type(isfile) ~= "function" then return fallback end
    local ok, color = pcall(function()
        local settingsFile = "TryoPluginManager_Settings.json"
        if not isfile(settingsFile) then return fallback end
        local settings = HttpService:JSONDecode(readfile(settingsFile))
        local accent = type(settings) == "table" and settings.Accent or nil
        if type(accent) ~= "table" then return fallback end
        return Color3.fromRGB(
            math.clamp(tonumber(accent.R) or 139, 0, 255),
            math.clamp(tonumber(accent.G) or 92, 0, 255),
            math.clamp(tonumber(accent.B) or 246, 0, 255)
        )
    end)
    return ok and typeof(color) == "Color3" and color or fallback
end

local function buildUI()
    local parent
    pcall(function() parent = game:GetService("CoreGui") end)
    if not parent then parent = LocalPlayer:WaitForChild("PlayerGui") end
    gui = make("ScreenGui",{Name="TryoWaypointManager",ResetOnSpawn=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},parent)
    panel = make("Frame",{
        Name="Panel",Size=UDim2.fromOffset(290,265),Position=UDim2.new(0.5,-145,0.35,0),
        BackgroundColor3=Color3.fromRGB(25,32,46),BackgroundTransparency=0.16,BorderSizePixel=0,ClipsDescendants=true
    },gui)
    corner(panel,10)
    make("UIStroke",{Color=Color3.fromRGB(112,142,185),Transparency=0.45},panel)
    make("UIGradient",{Color=ColorSequence.new(Color3.fromRGB(43,76,108),Color3.fromRGB(75,48,105)),Rotation=28},panel)
    local header = make("TextButton",{
        Name="Header",Text="WAYPOINT MANAGER",Size=UDim2.new(1,0,0,36),
        BackgroundColor3=Color3.fromRGB(47,80,112),BackgroundTransparency=0.12,TextColor3=Color3.fromRGB(245,247,255),
        Font=Enum.Font.GothamBold,TextSize=11,BorderSizePixel=0,AutoButtonColor=false
    },panel)
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging=true; dragStart=input.Position; frameStart=panel.Position
            ContextActionService:BindActionAtPriority(dragAction,function() return Enum.ContextActionResult.Sink end,false,3000,Enum.UserInputType.MouseButton1,Enum.UserInputType.Touch)
        end
    end)
    connect(UserInputService.InputChanged,function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local delta=input.Position-dragStart
            panel.Position=UDim2.new(frameStart.X.Scale,frameStart.X.Offset+delta.X,frameStart.Y.Scale,frameStart.Y.Offset+delta.Y)
        end
    end)
    connect(UserInputService.InputEnded,function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            dragging=false
            ContextActionService:UnbindAction(dragAction)
        end
    end)

    button(panel,"−",UDim2.fromOffset(24,25),UDim2.new(1,-28,0,5),function()
        panel.Visible=false
        if reopenButton then reopenButton.Visible=true end
    end,false).ZIndex=3
    local radarTab, savedTab, publicTab
    local function selectPage(nextPage)
        page = nextPage
        local activeColor = Color3.fromRGB(93,78,145)
        local inactiveColor = Color3.fromRGB(43,53,72)
        if radarTab then radarTab.BackgroundColor3 = page == "RADAR" and activeColor or inactiveColor end
        if savedTab then savedTab.BackgroundColor3 = page == "SAVED" and activeColor or inactiveColor end
        if publicTab then publicTab.BackgroundColor3 = page == "PUBLIC MAP" and activeColor or inactiveColor end
        if publicToolbar then publicToolbar.Visible = page == "PUBLIC MAP" end
        if page == "PUBLIC MAP" then loadPublicRoutes() end
        Feature.RefreshUI()
    end
    local tabBar = make("Frame",{
        Name="TabBar",Position=UDim2.fromOffset(8,42),Size=UDim2.new(1,-16,0,25),
        BackgroundTransparency=1,BorderSizePixel=0
    },panel)
    -- Scrollable primary tabs; the manual-save action remains fixed on the right.
    local tabScroll = make("ScrollingFrame",{
        Name="MainTabs",Position=UDim2.fromOffset(0,0),Size=UDim2.new(1,-84,1,0),
        BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=2,
        ScrollingDirection=Enum.ScrollingDirection.X,CanvasSize=UDim2.new(0,0,0,0),
        AutomaticCanvasSize=Enum.AutomaticSize.None,ClipsDescendants=true
    },tabBar)
    local tabLayout = make("UIListLayout",{
        FillDirection=Enum.FillDirection.Horizontal,HorizontalAlignment=Enum.HorizontalAlignment.Left,
        VerticalAlignment=Enum.VerticalAlignment.Center,Padding=UDim.new(0,3),SortOrder=Enum.SortOrder.LayoutOrder
    },tabScroll)
    tabLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        tabScroll.CanvasSize=UDim2.fromOffset(tabLayout.AbsoluteContentSize.X+2,0)
    end)
    radarTab = button(tabScroll,"RADAR",UDim2.fromOffset(65,25),UDim2.new(),function() selectPage("RADAR") end,page=="RADAR")
    radarTab.LayoutOrder=1
    radarTab.TextSize=9
    savedTab = button(tabScroll,"SAVED",UDim2.fromOffset(65,25),UDim2.new(),function() selectPage("SAVED") end,page=="SAVED")
    savedTab.LayoutOrder=2
    local refreshTab = button(tabScroll,"REFRESH",UDim2.fromOffset(72,25),UDim2.new(),function() Feature.Scan(); Feature.RefreshUI() end,false)
    refreshTab.LayoutOrder=3
    refreshTab.TextSize=9
    publicTab = button(tabScroll,"PUBLIC MAP",UDim2.fromOffset(88,25),UDim2.new(),function() selectPage("PUBLIC MAP") end,page=="PUBLIC MAP")
    publicTab.LayoutOrder=4
    publicTab.TextSize=9
    local saveHereTab = button(tabBar,"SAVE MANUAL",UDim2.fromOffset(80,25),UDim2.new(1,-80,0,0),showNamePrompt,true)
    saveHereTab.TextSize=8

    publicToolbar=make("Frame",{Name="PublicToolbar",Position=UDim2.fromOffset(8,73),Size=UDim2.new(1,-16,0,68),BackgroundColor3=Color3.fromRGB(31,40,57),BorderSizePixel=0,Visible=false},panel)
    corner(publicToolbar,7)
    publicToolbar.Size=UDim2.new(1,-16,0,94)
    publicRouteNameBox=make("TextBox",{PlaceholderText="Nama rute publik",Text="",Position=UDim2.fromOffset(5,5),Size=UDim2.new(1,-10,0,22),BackgroundColor3=Color3.fromRGB(43,53,72),TextColor3=Color3.new(1,1,1),PlaceholderColor3=Color3.fromRGB(155,165,185),Font=Enum.Font.Gotham,TextSize=10,ClearTextOnFocus=false},publicToolbar)
    corner(publicRouteNameBox,5)
    button(publicToolbar,"UPLOAD SAVED",UDim2.new(0.48,-4,0,21),UDim2.fromOffset(5,31),uploadPublicRoute,true).TextSize=9
    button(publicToolbar,"REFRESH",UDim2.new(0.48,-4,0,21),UDim2.new(0.52,0,0,31),loadPublicRoutes,false).TextSize=9
    publicSearchBox=make("TextBox",{PlaceholderText="Cari nama rute / uploader",Text="",Position=UDim2.fromOffset(5,56),Size=UDim2.new(1,-10,0,20),BackgroundColor3=Color3.fromRGB(43,53,72),TextColor3=Color3.new(1,1,1),PlaceholderColor3=Color3.fromRGB(155,165,185),Font=Enum.Font.Gotham,TextSize=9,ClearTextOnFocus=false},publicToolbar)
    corner(publicSearchBox,5)
    publicSearchBox:GetPropertyChangedSignal("Text"):Connect(function() if page=="PUBLIC MAP" then Feature.RefreshUI() end end)
    publicStatus=make("TextLabel",{Text="PUBLIC MAP",Position=UDim2.fromOffset(5,78),Size=UDim2.new(1,-10,0,12),BackgroundTransparency=1,TextColor3=Color3.fromRGB(170,220,190),Font=Enum.Font.Gotham,TextSize=8,TextXAlignment=Enum.TextXAlignment.Left},publicToolbar)

    list=make("ScrollingFrame",{
        Name="WaypointList",Position=UDim2.fromOffset(8,171),Size=UDim2.new(1,-16,1,-179),
        BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,CanvasSize=UDim2.new(0,0,0,0)
    },panel)
    make("UIListLayout",{Padding=UDim.new(0,5),SortOrder=Enum.SortOrder.LayoutOrder},list)
    reopenButton=button(gui,"Waypoint",UDim2.fromOffset(92,38),UDim2.new(1,-154,0,14),function()
        if reopenWasDragged then
            reopenWasDragged=false
            return
        end
        panel.Visible=true
        reopenButton.Visible=false
        Feature.RefreshUI()
    end,true)
    corner(reopenButton,19)
    reopenButton.BackgroundColor3 = getThemeAccent()
    make("UIStroke",{Color=reopenButton.BackgroundColor3,Transparency=0.18,Thickness=1.2},reopenButton)
    reopenButton.TextSize=10
    reopenButton.ZIndex=10
    reopenButton.Visible=false
    reopenButton.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            reopenDragging=true
            reopenDragInput=input
            reopenDragStart=input.Position
            reopenButtonStart=reopenButton.AbsolutePosition
            ContextActionService:BindActionAtPriority(reopenDragAction,function() return Enum.ContextActionResult.Sink end,false,3001,Enum.UserInputType.MouseButton1,Enum.UserInputType.Touch)
        end
    end)
    connect(UserInputService.InputChanged,function(input)
        if not reopenDragging then return end
        if input.UserInputType==Enum.UserInputType.MouseMovement or input==reopenDragInput then
            local delta=input.Position-reopenDragStart
            if delta.Magnitude>5 then reopenWasDragged=true end
            local camera=Workspace.CurrentCamera
            local viewport=camera and camera.ViewportSize or Vector2.new(1920,1080)
            local size=reopenButton.AbsoluteSize
            local x=math.clamp(reopenButtonStart.X+delta.X,0,math.max(0,viewport.X-size.X))
            local y=math.clamp(reopenButtonStart.Y+delta.Y,0,math.max(0,viewport.Y-size.Y))
            reopenButton.Position=UDim2.fromOffset(x,y)
        end
    end)
    connect(UserInputService.InputEnded,function(input)
        if reopenDragging and (input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch) then
            reopenDragging=false
            ContextActionService:UnbindAction(reopenDragAction)
            if reopenWasDragged then task.delay(0.15,function() reopenWasDragged=false end) end
        end
    end)
end

function Feature.RefreshUI()
    if not list then return end
    for _, child in ipairs(list:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    local entries={}
    if page=="PUBLIC MAP" then
        local shown=0
        local term=string.lower((publicSearchBox and publicSearchBox.Text) or "")
        for _,route in ipairs(publicRoutes) do
            local hay=string.lower(tostring(route.RouteName or "").." "..tostring(route.UploaderName or ""))
            if term=="" or string.find(hay,term,1,true) then
            shown=shown+1
            local index=shown
            local row=make("Frame",{Size=UDim2.new(1,-4,0,42),BackgroundColor3=Color3.fromRGB(34,43,60),BackgroundTransparency=0.12,BorderSizePixel=0,LayoutOrder=index},list)
            corner(row,6)
            make("TextLabel",{Text=tostring(route.RouteName or "Unnamed"),Position=UDim2.fromOffset(7,2),Size=UDim2.new(1,-110,0,17),BackgroundTransparency=1,TextColor3=Color3.fromRGB(235,239,248),Font=Enum.Font.GothamBold,TextSize=10,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd},row)
            make("TextLabel",{Text=tostring(route.UploaderName or "Unknown").." • "..tostring(route.TotalCP or 0).." CP",Position=UDim2.fromOffset(7,20),Size=UDim2.new(1,-110,0,15),BackgroundTransparency=1,TextColor3=Color3.fromRGB(165,178,200),Font=Enum.Font.Gotham,TextSize=8,TextXAlignment=Enum.TextXAlignment.Left},row)
            button(row,"GET",UDim2.fromOffset(42,25),UDim2.new(1,-92,0,8),function() importPublicRoute(route) end,true).TextSize=9
            if tostring(route.UploaderId)==tostring(LocalPlayer.UserId) then
                button(row,"DEL",UDim2.fromOffset(40,25),UDim2.new(1,-45,0,8),function() removePublicRoute(route) end,false).TextSize=9
            end
            end
        end
    elseif page=="RADAR" then
        assignPlainNumbers()
        for _,data in pairs(cache) do
            if data.part and data.part.Parent then
                local key=data.plain and (data.number or 1) or data.key
                local already=false
                for _,item in ipairs(saved) do
                    if item.cf and (CFrame.new(unpack(item.cf)).Position-data.part.Position).Magnitude<3 then already=true; break end
                end
                if not already then table.insert(entries,{key=key,desc=data.desc,part=data.part,data=data}) end
            end
        end
        table.sort(entries,function(a,b)
            return checkpointKeyLess(a.key,b.key)
        end)
    elseif page=="SAVED" then
        for index,item in ipairs(saved) do table.insert(entries,{key=item.key,desc=item.desc,item=item,index=index}) end
    else
        -- Public Map routes are rendered from the active PlaceId collection.
    end

    for index,entry in ipairs(entries) do
        local row=make("Frame",{Size=UDim2.new(1,-4,0,31),BackgroundColor3=Color3.fromRGB(34,43,60),BackgroundTransparency=0.12,BorderSizePixel=0,LayoutOrder=index},list)
        corner(row,6)
        local keyText=entry.key=="SUMMIT" and "SUMMIT" or (entry.key=="" and "MANUAL" or "CP "..tostring(entry.key))
        make("TextLabel",{Text=keyText,Position=UDim2.fromOffset(7,0),Size=UDim2.fromOffset(66,31),BackgroundTransparency=1,TextColor3=Color3.fromRGB(105,210,245),Font=Enum.Font.GothamBold,TextSize=10,TextXAlignment=Enum.TextXAlignment.Left},row)
        make("TextLabel",{Text=tostring(entry.desc),Position=UDim2.fromOffset(72,0),Size=UDim2.new(1,-157,1,0),BackgroundTransparency=1,TextColor3=Color3.fromRGB(225,230,242),Font=Enum.Font.Gotham,TextSize=10,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd},row)
        if page=="RADAR" then
            button(row,"TELE",UDim2.fromOffset(48,23),UDim2.new(1,-53,0,4),function()
                local data=entry.data
                if data and data.part and data.part.Parent then
                    assignPlainNumbers()
                    local key=data.plain and (data.number or 1) or data.key
                    teleportTo(data.part.CFrame)
                    addSaved(key,data.desc,data.part.CFrame,data.plain)
                    notify("Berhasil Teleport & Disave!")
                end
            end,true)
        else
            button(row,"TELE",UDim2.fromOffset(45,23),UDim2.new(1,-94,0,4),function()
                if entry.item.cf then teleportTo(CFrame.new(unpack(entry.item.cf))) end
            end,true)
            button(row,"DEL",UDim2.fromOffset(40,23),UDim2.new(1,-45,0,4),function()
                table.remove(saved,entry.index); persist(); Feature.RefreshUI()
            end,false)
        end
    end
    task.defer(function()
        if list then list.CanvasSize=UDim2.new(0,0,0,list.UIListLayout.AbsoluteContentSize.Y+5) end
    end)
end

function Feature.Scan()
    if scanBusy or not active then return end
    scanBusy=true
    task.spawn(function()
        local descendants=Workspace:GetDescendants()
        for i,object in ipairs(descendants) do
            if not active then break end
            local key,desc,part,priority,plain,identity=parseCheckpoint(object)
            if key and part and part.Parent then
                local cacheKey=identity or (plain and part or getPath(part))
                if not cache[cacheKey] then
                    cache[cacheKey]={key=key,desc=desc,part=part,priority=priority,plain=plain==true,identity=identity}
                    if plain then queuePlainNumbering() end
                    if part:FindFirstChild("TouchInterest") or plain or isZoneCheckpoint(part) then
                        local lastTouch=0
                        connect(part.Touched,function(hit)
                            if not active or tick()-lastTouch<1 then return end
                            local char=LocalPlayer.Character
                            local hum=char and char:FindFirstChildOfClass("Humanoid")
                            if char and hit:IsDescendantOf(char) and hum and hum.Health>0 then
                                lastTouch=tick()
                                saveFromData(cache[cacheKey])
                            end
                        end)
                    end
                    local prompt=getCheckpointPrompt(part)
                    if prompt then
                        connect(prompt.Triggered,function(player)
                            if player==LocalPlayer then saveFromData(cache[cacheKey]) end
                        end)
                    end
                end
            end
            if i%80==0 then task.wait() end
        end
        scanBusy=false
        assignPlainNumbers()
        refresh()
    end)
end

function Feature.Start()
    if active then return true end
    active=true
    loadSaved()
    buildUI()
    connect(Workspace.DescendantAdded,function(object)
        task.delay(0.2,function()
            if not active then return end
            local key,desc,part,priority,plain,identity=parseCheckpoint(object)
            if key and part and part.Parent then
                local cacheKey=identity or (plain and part or getPath(part))
                if not cache[cacheKey] then
                    cache[cacheKey]={key=key,desc=desc,part=part,priority=priority,plain=plain==true,identity=identity}
                    if plain then queuePlainNumbering() end
                    if part:FindFirstChild("TouchInterest") or plain or isZoneCheckpoint(part) then
                        local lastTouch=0
                        connect(part.Touched,function(hit)
                            if not active or tick()-lastTouch<1 then return end
                            local char=LocalPlayer.Character
                            local hum=char and char:FindFirstChildOfClass("Humanoid")
                            if char and hit:IsDescendantOf(char) and hum and hum.Health>0 then lastTouch=tick(); saveFromData(cache[cacheKey]) end
                        end)
                    end
                    local prompt=getCheckpointPrompt(part)
                    if prompt then connect(prompt.Triggered,function(player) if player==LocalPlayer then saveFromData(cache[cacheKey]) end end) end
                    assignPlainNumbers(); refresh()
                end
            end
        end)
    end)
    Feature.Scan()
    task.spawn(function()
        local lastAccent
        while active and reopenButton and reopenButton.Parent do
            local accent = getThemeAccent()
            if accent ~= lastAccent then
                reopenButton.BackgroundColor3 = accent
                local outline = reopenButton:FindFirstChildOfClass("UIStroke")
                if outline then outline.Color = accent end
                lastAccent = accent
            end
            task.wait(2)
        end
    end)
    notify("Scanner checkpoint aktif")
    return true
end

function Feature.Stop()
    if not active then return true end
    active=false
    dragging=false
    reopenDragging=false
    ContextActionService:UnbindAction(dragAction)
    ContextActionService:UnbindAction(reopenDragAction)
    for _,connection in ipairs(connections) do pcall(function() connection:Disconnect() end) end
    table.clear(connections)
    if gui then gui:Destroy() end
    gui,panel,list,nameBox,promptFrame,reopenButton=nil,nil,nil,nil,nil,nil
    publicToolbar,publicRouteNameBox,publicSearchBox,publicStatus=nil,nil,nil,nil
    publicRoutes={}
    table.clear(cache)
    notify("Waypoint Manager dimatikan")
    return true
end

return Feature
