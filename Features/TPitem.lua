-- Standalone migration of beta TPitem (Universal Multi-Map Grabber).
-- Original map-specific grab logic is retained; lifecycle cleanup is added for beta2.
local Feature = {
    Name = "Teleport to Item",
    Description = "Universal grabber for supported Store/Tycoon and Library maps."
}
local started = false
local function runLegacy()
    -- ================================================================
    -- UNIVERSAL MULTI-MAP GRABBER LOADER (MAP B: AUTO GRAB BUTTON + DROP/GRAB AMAN)
    -- ================================================================
    
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local CoreGui = game:GetService("CoreGui")
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    
    -- Bersihkan GUI sebelumnya jika ada 
    pcall(function()
        if playerGui:FindFirstChild("MapSelectorGui") then playerGui.MapSelectorGui:Destroy() end
        if playerGui:FindFirstChild("PreciseGrabGui") then playerGui.PreciseGrabGui:Destroy() end
        if playerGui:FindFirstChild("MapBLibraryGui") then playerGui.MapBLibraryGui:Destroy() end
        if CoreGui:FindFirstChild("MapSelectorGui") then CoreGui.MapSelectorGui:Destroy() end
        if CoreGui:FindFirstChild("PreciseGrabGui") then CoreGui.PreciseGrabGui:Destroy() end
        if CoreGui:FindFirstChild("MapBLibraryGui") then CoreGui.MapBLibraryGui:Destroy() end
    end)
    
    -- ================================================================
    -- [BAGIAN 1] LOGIKA MAP A (STORE / TYCOON) - 100% ORIGINAL & UNTOUCHED
    -- ================================================================
    local function loadMapA()
        local Workspace = game:GetService("Workspace")
        local VirtualInputManager = game:GetService("VirtualInputManager") 
        local Camera = Workspace.CurrentCamera
    
        local function lower(val)
            return string.lower(tostring(val or ""))
        end
    
        getgenv().ExecutePreciseGrab = function(keyword, maxLimitInput)
            local searchKeyword = lower(keyword)
            if searchKeyword == "" then
                print("[Grab A] Keyword kosong!")
                return
            end
    
            local maxAllowed = tonumber(maxLimitInput) or 7
            local character = LocalPlayer.Character
            local rootPart = character and character:FindFirstChild("HumanoidRootPart")
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            
            if not rootPart or not humanoid then
                print("[Grab A] Karakter / Humanoid tidak ditemukan!")
                return
            end
    
            local originalCFrame = rootPart.CFrame
            local originalCameraCFrame = Camera.CFrame 
            local itemsFolder = Workspace:FindFirstChild("Items") or Workspace
    
            local validItems = {}
            local addedModels = {}
    
            for _, obj in ipairs(itemsFolder:GetDescendants()) do
                local fullName = lower(obj:GetFullName())
                if not string.find(fullName, "placezone") and not string.find(fullName, "tempinvis") and not string.find(fullName, "display") then
                    local rootModel = obj
                    if obj:IsA("BasePart") then
                        local p = obj.Parent
                        while p and p ~= itemsFolder and p ~= Workspace do
                            if p:IsA("Model") then
                                rootModel = p
                                break
                            end
                            p = p.Parent
                        end
                    end
    
                    if not addedModels[rootModel] then
                        local searchTexts = {}
                        table.insert(searchTexts, lower(rootModel.Name))
                        for _, desc in ipairs(rootModel:GetDescendants()) do
                            table.insert(searchTexts, lower(desc.Name))
                        end
                        
                        pcall(function()
                            for _, attrVal in pairs(rootModel:GetAttributes()) do
                                table.insert(searchTexts, lower(tostring(attrVal)))
                            end
                            for _, child in ipairs(rootModel:GetChildren()) do
                                if child:IsA("StringValue") or child:IsA("ValueBase") then
                                    table.insert(searchTexts, lower(tostring(child.Value)))
                                end
                            end
                        end)
    
                        local combinedSearchString = table.concat(searchTexts, " ")
                        if string.find(combinedSearchString, searchKeyword, 1, true) then
                            local targetPart = nil
                            if rootModel:IsA("Model") then
                                targetPart = rootModel.PrimaryPart or rootModel:FindFirstChildWhichIsA("BasePart")
                            elseif rootModel:IsA("BasePart") then
                                if rootModel.Size.Magnitude < 15 and rootModel.Transparency < 1 then
                                    targetPart = rootModel
                                end
                            end
    
                            if targetPart and targetPart:IsDescendantOf(Workspace) then
                                addedModels[rootModel] = true
                                local dist = (targetPart.Position - rootPart.Position).Magnitude
                                table.insert(validItems, {Part = targetPart, Distance = dist})
                            end
                        end
                    end
                end
            end
    
            table.sort(validItems, function(a, b) return a.Distance < b.Distance end)
    
            if #validItems == 0 then
                print("[Grab A] Item atau Kategori '" .. keyword .. "' tidak ditemukan!")
                return
            end
    
            local targetLimit = math.min(#validItems, maxAllowed)
            print("[Grab A] Ditemukan " .. #validItems .. " item unik. Memproses " .. targetLimit .. " item terdekat...")
    
            local collected = 0
            for i = 1, targetLimit do
                local itemData = validItems[i]
                if not itemData then break end
                local targetPart = itemData.Part
    
                if targetPart and targetPart:IsDescendantOf(Workspace) then
                    pcall(function()
                        local itemPos = targetPart.Position
                        rootPart.CFrame = CFrame.lookAt(itemPos + Vector3.new(0, 0.3, 1.2), itemPos)
                        
                        Camera.CameraType = Enum.CameraType.Scriptable
                        Camera.CFrame = CFrame.lookAt(itemPos + Vector3.new(0, 2, 2), itemPos)
                        task.wait(0.06)
    
                        local vp = Camera.ViewportSize
                        VirtualInputManager:SendMouseButtonEvent(vp.X/2, vp.Y/2, 0, true, game, 0)
                        task.wait(0.03)
                        VirtualInputManager:SendMouseButtonEvent(vp.X/2, vp.Y/2, 0, false, game, 0)
    
                        if targetPart:IsA("BasePart") then
                            firetouchinterest(rootPart, targetPart, 0)
                            task.wait(0.03)
                            firetouchinterest(rootPart, targetPart, 1)
                        end
                        collected += 1
                    end)
                    task.wait(0.35)
                end
            end
    
            pcall(function()
                if rootPart and rootPart.Parent then
                    rootPart.AssemblyLinearVelocity = Vector3.zero
                    rootPart.AssemblyAngularVelocity = Vector3.zero
                    rootPart.CFrame = originalCFrame
                end
            end)
    
            pcall(function()
                Camera = Workspace.CurrentCamera
                Camera.CameraType = Enum.CameraType.Scriptable
                Camera.CFrame = originalCameraCFrame
                task.wait(0.05)
                Camera.CameraType = Enum.CameraType.Custom
                Camera.CameraSubject = humanoid
            end)
    
            pcall(function()
                humanoid.PlatformStand = false
                humanoid.Sit = false
                humanoid.AutoRotate = true
                humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
                humanoid:ChangeState(Enum.HumanoidStateType.Running)
            end)
    
            task.spawn(function()
                task.wait(0.1)
                pcall(function()
                    local playerScripts = LocalPlayer:FindFirstChild("PlayerScripts")
                    local playerModuleScript = playerScripts and playerScripts:FindFirstChild("PlayerModule")
                    if playerModuleScript then
                        local playerModule = require(playerModuleScript)
                        local controls = playerModule:GetControls()
                        if controls then controls:Enable() end
                    end
                end)
            end)
            print("[Grab A] Selesai! Berhasil mengambil " .. collected .. " item.")
        end
    
        local function getAllRacks()
            local racks = {}
            local seenNames = {}
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("TextLabel") or obj:IsA("TextButton") then
                    local txt = obj.Text
                    if txt and txt ~= "" and string.len(txt) < 30 then
                        local targetPart = nil
                        local parentName = ""
                        local parent = obj.Parent
                        while parent and parent ~= Workspace do
                            if parent:IsA("Model") or parent:IsA("Folder") then
                                if parentName == "" then parentName = parent.Name end
                            end
                            if parent:IsA("BasePart") then
                                targetPart = parent
                                break
                            elseif parent:IsA("Model") then
                                targetPart = parent.PrimaryPart or parent:FindFirstChildWhichIsA("BasePart")
                                if targetPart then break end
                            end
                            parent = parent.Parent
                        end
    
                        if targetPart then
                            local displayName = txt
                            if parentName ~= "" and parentName ~= txt and not string.find(parentName, "Model") then
                                displayName = txt .. " (" .. parentName .. ")"
                            end
                            if not seenNames[displayName] then
                                seenNames[displayName] = true
                                table.insert(racks, {Name = displayName, Part = targetPart})
                            end
                        end
                    end
                end
            end
            return racks
        end
    
        local screenGui = Instance.new("ScreenGui")
        screenGui.Name = "PreciseGrabGui"
        screenGui.ResetOnSpawn = false
        pcall(function() screenGui.Parent = CoreGui end)
        if not screenGui.Parent then screenGui.Parent = playerGui end
    
        local mainFrame = Instance.new("Frame", screenGui)
        mainFrame.Size = UDim2.new(0, 260, 0, 110)
        mainFrame.Position = UDim2.new(0.5, -130, 0.3, 0)
        mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        mainFrame.BorderSizePixel = 0
        mainFrame.Active = true
        mainFrame.Draggable = true
        Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 8)
    
        local topBar = Instance.new("Frame", mainFrame)
        topBar.Size = UDim2.new(1, 0, 0, 28)
        topBar.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
        Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 8)
    
        local title = Instance.new("TextLabel", topBar)
        title.Size = UDim2.new(1, -30, 1, 0)
        title.Position = UDim2.new(0, 8, 0, 0)
        title.BackgroundTransparency = 1
        title.Font = Enum.Font.GothamBold
        title.Text = "🎯 Precise Grabber (Map A)"
        title.TextColor3 = Color3.fromRGB(255, 255, 255)
        title.TextSize = 12
        title.TextXAlignment = Enum.TextXAlignment.Left
    
        local closeBtn = Instance.new("TextButton", topBar)
        closeBtn.Size = UDim2.new(0, 20, 0, 20)
        closeBtn.Position = UDim2.new(1, -24, 0, 4)
        closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        closeBtn.Font = Enum.Font.GothamBold
        closeBtn.Text = "X"
        closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        closeBtn.TextSize = 11
        Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 4)
        closeBtn.MouseButton1Click:Connect(function() screenGui:Destroy() end)
    
        local textBox = Instance.new("TextBox", mainFrame)
        textBox.Size = UDim2.new(0, 160, 0, 30)
        textBox.Position = UDim2.new(0, 8, 0, 36)
        textBox.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        textBox.Font = Enum.Font.Gotham
        textBox.PlaceholderText = "Input nama / kategori..."
        textBox.Text = ""
        textBox.TextColor3 = Color3.fromRGB(255, 255, 255)
        textBox.PlaceholderColor3 = Color3.fromRGB(140, 140, 140)
        textBox.TextSize = 11
        textBox.ClearTextOnFocus = false
        Instance.new("UICorner", textBox).CornerRadius = UDim.new(0, 6)
    
        local maxBox = Instance.new("TextBox", mainFrame)
        maxBox.Size = UDim2.new(0, 76, 0, 30)
        maxBox.Position = UDim2.new(0, 176, 0, 36)
        maxBox.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        maxBox.Font = Enum.Font.GothamBold
        maxBox.PlaceholderText = "Max"
        maxBox.Text = "7"
        maxBox.TextColor3 = Color3.fromRGB(255, 255, 255)
        maxBox.PlaceholderColor3 = Color3.fromRGB(140, 140, 140)
        maxBox.TextSize = 11
        maxBox.ClearTextOnFocus = false
        Instance.new("UICorner", maxBox).CornerRadius = UDim.new(0, 6)
    
        local btn = Instance.new("TextButton", mainFrame)
        btn.Size = UDim2.new(0, 150, 0, 30)
        btn.Position = UDim2.new(0, 8, 0, 72)
        btn.BackgroundColor3 = Color3.fromRGB(0, 150, 90)
        btn.Font = Enum.Font.GothamBold
        btn.Text = "START"
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextSize = 11
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    
        local putBtn = Instance.new("TextButton", mainFrame)
        putBtn.Size = UDim2.new(0, 86, 0, 30)
        putBtn.Position = UDim2.new(0, 166, 0, 72)
        putBtn.BackgroundColor3 = Color3.fromRGB(50, 110, 200)
        putBtn.Font = Enum.Font.GothamBold
        putBtn.Text = "List Placezone"
        putBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        putBtn.TextSize = 10
        Instance.new("UICorner", putBtn).CornerRadius = UDim.new(0, 6)
    
        local rackListPanel = Instance.new("Frame", screenGui)
        rackListPanel.Size = UDim2.new(0, 260, 0, 240)
        rackListPanel.AnchorPoint = Vector2.new(0.5, 0.5)
        rackListPanel.Position = UDim2.new(0.5, 0, 0.5, 0)
        rackListPanel.BackgroundColor3 = Color3.fromRGB(20, 35, 25)
        rackListPanel.BackgroundTransparency = 0.1
        rackListPanel.BorderSizePixel = 0
        rackListPanel.Visible = false
        Instance.new("UICorner", rackListPanel).CornerRadius = UDim.new(0, 8)
    
        local searchBar = Instance.new("TextBox", rackListPanel)
        searchBar.Size = UDim2.new(1, -10, 0, 28)
        searchBar.Position = UDim2.new(0, 5, 0, 5)
        searchBar.BackgroundColor3 = Color3.fromRGB(15, 25, 20)
        searchBar.Font = Enum.Font.Gotham
        searchBar.PlaceholderText = "Cari placezone..."
        searchBar.Text = ""
        searchBar.TextColor3 = Color3.fromRGB(255, 255, 255)
        searchBar.PlaceholderColor3 = Color3.fromRGB(140, 140, 140)
        searchBar.TextSize = 11
        searchBar.ClearTextOnFocus = false
        Instance.new("UICorner", searchBar).CornerRadius = UDim.new(0, 6)
    
        local scrollingContent = Instance.new("ScrollingFrame", rackListPanel)
        scrollingContent.Size = UDim2.new(1, 0, 1, -38)
        scrollingContent.Position = UDim2.new(0, 0, 0, 38)
        scrollingContent.BackgroundTransparency = 1
        scrollingContent.BorderSizePixel = 0
        scrollingContent.ScrollBarThickness = 3
    
        local cachedRacks = {}
        local function updateRackListUI(filterText)
            for _, child in ipairs(scrollingContent:GetChildren()) do
                if child:IsA("TextButton") then child:Destroy() end
            end
            local filter = lower(filterText or "")
            local itemHeight = 32
            local itemSpacing = 4
            local yOffset = 5
    
            for _, rack in ipairs(cachedRacks) do
                if filter == "" or string.find(lower(rack.Name), filter, 1, true) then
                    local rackBtn = Instance.new("TextButton")
                    rackBtn.Size = UDim2.new(1, -10, 0, itemHeight)
                    rackBtn.Position = UDim2.new(0, 5, 0, yOffset)
                    rackBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
                    rackBtn.BackgroundTransparency = 0.2
                    rackBtn.BorderSizePixel = 0
                    rackBtn.Font = Enum.Font.GothamSemibold
                    rackBtn.Text = "  " .. rack.Name
                    rackBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                    rackBtn.TextSize = 11
                    rackBtn.TextXAlignment = Enum.TextXAlignment.Left
                    rackBtn.Parent = scrollingContent
                    Instance.new("UICorner", rackBtn).CornerRadius = UDim.new(0, 6)
    
                    rackBtn.MouseButton1Click:Connect(function()
                        local character = LocalPlayer.Character
                        local rootPart = character and character:FindFirstChild("HumanoidRootPart")
                        if rootPart and rack.Part and rack.Part.Parent then
                            pcall(function()
                                local targetCFrame = rack.Part.CFrame
                                local safePos = targetCFrame + (targetCFrame.LookVector * -3.5) + Vector3.new(0, 0.5, 0)
                                rootPart.CFrame = CFrame.new(safePos.Position, targetCFrame.Position)
                            end)
                        end
                    end)
                    yOffset = yOffset + itemHeight + itemSpacing
                end
            end
            scrollingContent.CanvasSize = UDim2.new(0, 0, 0, yOffset + 10)
        end
    
        putBtn.MouseButton1Click:Connect(function()
            rackListPanel.Visible = not rackListPanel.Visible
            if rackListPanel.Visible then
                cachedRacks = getAllRacks()
                searchBar.Text = ""
                updateRackListUI("")
            end
        end)
    
        searchBar:GetPropertyChangedSignal("Text"):Connect(function() updateRackListUI(searchBar.Text) end)
    
        local function triggerGrab()
            if textBox.Text ~= "" then getgenv().ExecutePreciseGrab(textBox.Text, maxBox.Text) end
        end
        btn.MouseButton1Click:Connect(triggerGrab)
        textBox.FocusLost:Connect(function(enter) if enter then triggerGrab() end end)
        maxBox.FocusLost:Connect(function(enter) if enter then triggerGrab() end end)
        print("[Map A] Berhasil dimuat!")
    end
    
    -- ================================================================
    -- [BAGIAN 2] LOGIKA MAP B (LIBRARY / BUKU 1-N + AUTO CLICK GRAB BUTTON + DROP/GRAB AMAN)
    -- ================================================================
    local function loadMapB()
        local Workspace = game:GetService("Workspace")
        local VirtualInputManager = game:GetService("VirtualInputManager")
    
        local function lower(val)
            return string.lower(tostring(val or ""))
        end
    
        getgenv().ExecutePreciseGrabMapB = function(keyword, maxLimitInput)
            local searchKeyword = lower(keyword)
            if searchKeyword == "" then
                print("[Grab Map B] Keyword kosong!")
                return
            end
    
            local maxAllowed = tonumber(maxLimitInput) or 10
            local character = LocalPlayer.Character
            local rootPart = character and character:FindFirstChild("HumanoidRootPart")
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            
            if not rootPart or not humanoid then
                print("[Grab Map B] Karakter tidak ditemukan!")
                return
            end
    
            local originalCFrame = rootPart.CFrame
            local libraryFolder = Workspace:FindFirstChild("Library") or Workspace
            local booksFolder = libraryFolder:FindFirstChild("Books") or libraryFolder
    
            local validItems = {}
            local addedModels = {}
    
            for _, obj in ipairs(booksFolder:GetDescendants()) do
                local isInShelf = false
                local p = obj.Parent
                while p and p ~= Workspace do
                    local pName = lower(p.Name)
                    if pName == "bookshelves" or pName == "themeparks" or pName == "hoverarea" or string.find(pName, "2f") then
                        isInShelf = true
                        break
                    end
                    p = p.Parent
                end
    
                if not isInShelf then
                    local rootModel = obj
                    if obj:IsA("BasePart") or obj:IsA("MeshPart") then
                        local parentObj = obj.Parent
                        while parentObj and parentObj ~= booksFolder and parentObj ~= Workspace do
                            if parentObj:IsA("Model") then
                                rootModel = parentObj
                                break
                            end
                            parentObj = parentObj.Parent
                        end
                    end
    
                    if not addedModels[rootModel] then
                        local modelName = rootModel.Name
                        local combinedSearchString = lower(modelName)
                        for _, desc in ipairs(rootModel:GetDescendants()) do
                            combinedSearchString = combinedSearchString .. " " .. lower(desc.Name)
                        end
    
                        if string.find(combinedSearchString, searchKeyword, 1, true) then
                            local targetPart = nil
                            if rootModel:IsA("Model") then
                                targetPart = rootModel.PrimaryPart or rootModel:FindFirstChildWhichIsA("BasePart") or rootModel:FindFirstChildWhichIsA("MeshPart")
                            elseif rootModel:IsA("BasePart") or rootModel:IsA("MeshPart") then
                                targetPart = rootModel
                            end
    
                            if targetPart and targetPart:IsDescendantOf(Workspace) then
                                addedModels[rootModel] = true
                                local bookNum = tonumber(string.match(modelName, "%d+$")) or 999
                                table.insert(validItems, {Part = targetPart, Number = bookNum, Name = modelName})
                            end
                        end
                    end
                end
            end
    
            -- Urutkan berdasarkan NOMOR URUT BUKU (1, 2, 3... secara Ascending)
            table.sort(validItems, function(a, b)
                return a.Number < b.Number
            end)
    
            if #validItems == 0 then
                print("[Grab Map B] Buku '" .. keyword .. "' di lantai/tumpukan tidak ditemukan!")
                return
            end
    
            local targetLimit = math.min(#validItems, maxAllowed)
            print("[Grab Map B] Ditemukan " .. #validItems .. " buku. Memproses " .. targetLimit .. " buku secara berurutan...")
    
            local collected = 0
            for i = 1, targetLimit do
                local itemData = validItems[i]
                if not itemData then break end
                local targetPart = itemData.Part
    
                if targetPart and targetPart:IsDescendantOf(Workspace) then
                    pcall(function()
                        local itemPos = targetPart.Position
                        
                        -- 1. Teleport pas di dekat buku dan hadapkan karakter ke arah buku
                        rootPart.CFrame = CFrame.lookAt(itemPos + Vector3.new(0, 0.3, 1.2), itemPos)
                        task.wait(0.06)
    
                        -- 2. Cari tombol "Grab" di PlayerGui secara otomatis dan klik tombolnya
                        local grabButton = nil
                        for _, guiObj in ipairs(playerGui:GetDescendants()) do
                            if guiObj:IsA("GuiButton") and string.lower(guiObj.Name) == "grab" then
                                grabButton = guiObj
                                break
                            end
                        end
    
                        if grabButton and grabButton.AbsoluteSize.X > 0 then
                            local absPos = grabButton.AbsolutePosition
                            local absSize = grabButton.AbsoluteSize
                            local clickX = absPos.X + (absSize.X / 2)
                            local clickY = absPos.Y + (absSize.Y / 2)
    
                            -- Simulasi klik virtual pada tombol Grab di layar HP
                            VirtualInputManager:SendMouseButtonEvent(clickX, clickY, 0, true, game, 0)
                            task.wait(0.03)
                            VirtualInputManager:SendMouseButtonEvent(clickX, clickY, 0, false, game, 0)
                        end
    
                        collected += 1
                    end)
                    task.wait(0.3)
                end
            end
    
            -- PEMULIHAN AKHIR (KEMBALI KE POSISI AWAL TANPA GANGGU KAMERA/GUI)
            pcall(function()
                if rootPart and rootPart.Parent then
                    rootPart.AssemblyLinearVelocity = Vector3.zero
                    rootPart.AssemblyAngularVelocity = Vector3.zero
                    rootPart.CFrame = originalCFrame
                end
            end)
    
            pcall(function()
                humanoid.PlatformStand = false
                humanoid.Sit = false
                humanoid.AutoRotate = true
                humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
                humanoid:ChangeState(Enum.HumanoidStateType.Running)
            end)
    
            print("[Grab Map B] Selesai! Berhasil mengambil " .. collected .. " buku secara berurutan.")
        end
    
        local function getAllMapBRacks()
            local racks = {}
            local seenNames = {}
            local libraryFolder = Workspace:FindFirstChild("Library") or Workspace
    
            for _, obj in ipairs(libraryFolder:GetDescendants()) do
                if obj:IsA("TextLabel") or obj:IsA("TextButton") then
                    local txt = obj.Text
                    if txt and txt ~= "" and string.len(txt) < 30 then
                        local targetPart = nil
                        local parentName = ""
                        local parent = obj.Parent
                        while parent and parent ~= Workspace do
                            if parent:IsA("Model") or parent:IsA("Folder") then
                                if parentName == "" then parentName = parent.Name end
                            end
                            if parent:IsA("BasePart") or parent:IsA("MeshPart") then
                                targetPart = parent
                                break
                            elseif parent:IsA("Model") then
                                targetPart = parent.PrimaryPart or parent:FindFirstChildWhichIsA("BasePart") or parent:FindFirstChildWhichIsA("MeshPart")
                                if targetPart then break end
                            end
                            parent = parent.Parent
                        end
    
                        if targetPart then
                            local displayName = txt
                            if parentName ~= "" and parentName ~= txt and not string.find(parentName, "Model") then
                                displayName = txt .. " (" .. parentName .. ")"
                            end
                            if not seenNames[displayName] then
                                seenNames[displayName] = true
                                table.insert(racks, {Name = displayName, Part = targetPart})
                            end
                        end
                    end
                end
            end
            return racks
        end
    
        local screenGui = Instance.new("ScreenGui")
        screenGui.Name = "MapBLibraryGui"
        screenGui.ResetOnSpawn = false
        pcall(function() screenGui.Parent = CoreGui end)
        if not screenGui.Parent then screenGui.Parent = playerGui end
    
        local mainFrame = Instance.new("Frame", screenGui)
        mainFrame.Size = UDim2.new(0, 260, 0, 110)
        mainFrame.Position = UDim2.new(0.5, -130, 0.3, 0)
        mainFrame.BackgroundColor3 = Color3.fromRGB(20, 40, 60)
        mainFrame.BorderSizePixel = 0
        mainFrame.Active = true
        mainFrame.Draggable = true
        Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 8)
    
        local topBar = Instance.new("Frame", mainFrame)
        topBar.Size = UDim2.new(1, 0, 0, 28)
        topBar.BackgroundColor3 = Color3.fromRGB(35, 60, 90)
        Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 8)
    
        local title = Instance.new("TextLabel", topBar)
        title.Size = UDim2.new(1, -30, 1, 0)
        title.Position = UDim2.new(0, 8, 0, 0)
        title.BackgroundTransparency = 1
        title.Font = Enum.Font.GothamBold
        title.Text = "📚 Library Grabber (Map B)"
        title.TextColor3 = Color3.fromRGB(255, 255, 255)
        title.TextSize = 12
        title.TextXAlignment = Enum.TextXAlignment.Left
    
        local closeBtn = Instance.new("TextButton", topBar)
        closeBtn.Size = UDim2.new(0, 20, 0, 20)
        closeBtn.Position = UDim2.new(1, -24, 0, 4)
        closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        closeBtn.Font = Enum.Font.GothamBold
        closeBtn.Text = "X"
        closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        closeBtn.TextSize = 11
        Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 4)
        closeBtn.MouseButton1Click:Connect(function() screenGui:Destroy() end)
    
        local textBox = Instance.new("TextBox", mainFrame)
        textBox.Size = UDim2.new(0, 160, 0, 30)
        textBox.Position = UDim2.new(0, 8, 0, 36)
        textBox.BackgroundColor3 = Color3.fromRGB(15, 25, 35)
        textBox.Font = Enum.Font.Gotham
        textBox.PlaceholderText = "Nama/Kategori buku..."
        textBox.Text = ""
        textBox.TextColor3 = Color3.fromRGB(255, 255, 255)
        textBox.PlaceholderColor3 = Color3.fromRGB(140, 140, 140)
        textBox.TextSize = 11
        textBox.ClearTextOnFocus = false
        Instance.new("UICorner", textBox).CornerRadius = UDim.new(0, 6)
    
        local maxBox = Instance.new("TextBox", mainFrame)
        maxBox.Size = UDim2.new(0, 76, 0, 30)
        maxBox.Position = UDim2.new(0, 176, 0, 36)
        maxBox.BackgroundColor3 = Color3.fromRGB(15, 25, 35)
        maxBox.Font = Enum.Font.GothamBold
        maxBox.PlaceholderText = "Max"
        maxBox.Text = "10"
        maxBox.TextColor3 = Color3.fromRGB(255, 255, 255)
        maxBox.PlaceholderColor3 = Color3.fromRGB(140, 140, 140)
        maxBox.TextSize = 11
        maxBox.ClearTextOnFocus = false
        Instance.new("UICorner", maxBox).CornerRadius = UDim.new(0, 6)
    
        local btn = Instance.new("TextButton", mainFrame)
        btn.Size = UDim2.new(0, 150, 0, 30)
        btn.Position = UDim2.new(0, 8, 0, 72)
        btn.BackgroundColor3 = Color3.fromRGB(0, 150, 90)
        btn.Font = Enum.Font.GothamBold
        btn.Text = "START (URUT 1-N)"
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextSize = 10
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    
        local putBtn = Instance.new("TextButton", mainFrame)
        putBtn.Size = UDim2.new(0, 86, 0, 30)
        putBtn.Position = UDim2.new(0, 166, 0, 72)
        putBtn.BackgroundColor3 = Color3.fromRGB(50, 110, 200)
        putBtn.Font = Enum.Font.GothamBold
        putBtn.Text = "List Rak Buku"
        putBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        putBtn.TextSize = 10
        Instance.new("UICorner", putBtn).CornerRadius = UDim.new(0, 6)
    
        -- PANEL LIST RAK BUKU DI TENGAH LAYAR
        local rackListPanel = Instance.new("Frame", screenGui)
        rackListPanel.Size = UDim2.new(0, 260, 0, 240)
        rackListPanel.AnchorPoint = Vector2.new(0.5, 0.5)
        rackListPanel.Position = UDim2.new(0.5, 0, 0.5, 0)
        rackListPanel.BackgroundColor3 = Color3.fromRGB(15, 30, 45)
        rackListPanel.BackgroundTransparency = 0.1
        rackListPanel.BorderSizePixel = 0
        rackListPanel.Visible = false
        Instance.new("UICorner", rackListPanel).CornerRadius = UDim.new(0, 8)
    
        local searchBar = Instance.new("TextBox", rackListPanel)
        searchBar.Size = UDim2.new(1, -10, 0, 28)
        searchBar.Position = UDim2.new(0, 5, 0, 5)
        searchBar.BackgroundColor3 = Color3.fromRGB(10, 20, 30)
        searchBar.Font = Enum.Font.Gotham
        searchBar.PlaceholderText = "Cari rak/placezone..."
        searchBar.Text = ""
        searchBar.TextColor3 = Color3.fromRGB(255, 255, 255)
        searchBar.PlaceholderColor3 = Color3.fromRGB(140, 140, 140)
        searchBar.TextSize = 11
        searchBar.ClearTextOnFocus = false
        Instance.new("UICorner", searchBar).CornerRadius = UDim.new(0, 6)
    
        local scrollingContent = Instance.new("ScrollingFrame", rackListPanel)
        scrollingContent.Size = UDim2.new(1, 0, 1, -38)
        scrollingContent.Position = UDim2.new(0, 0, 0, 38)
        scrollingContent.BackgroundTransparency = 1
        scrollingContent.BorderSizePixel = 0
        scrollingContent.ScrollBarThickness = 3
    
        local cachedRacks = {}
        local function updateRackListUI(filterText)
            for _, child in ipairs(scrollingContent:GetChildren()) do
                if child:IsA("TextButton") then child:Destroy() end
            end
            local filter = lower(filterText or "")
            local itemHeight = 32
            local itemSpacing = 4
            local yOffset = 5
    
            for _, rack in ipairs(cachedRacks) do
                if filter == "" or string.find(lower(rack.Name), filter, 1, true) then
                    local rackBtn = Instance.new("TextButton")
                    rackBtn.Size = UDim2.new(1, -10, 0, itemHeight)
                    rackBtn.Position = UDim2.new(0, 5, 0, yOffset)
                    rackBtn.BackgroundColor3 = Color3.fromRGB(25, 45, 65)
                    rackBtn.BackgroundTransparency = 0.2
                    rackBtn.BorderSizePixel = 0
                    rackBtn.Font = Enum.Font.GothamSemibold
                    rackBtn.Text = "  " .. rack.Name
                    rackBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                    rackBtn.TextSize = 11
                    rackBtn.TextXAlignment = Enum.TextXAlignment.Left
                    rackBtn.Parent = scrollingContent
                    Instance.new("UICorner", rackBtn).CornerRadius = UDim.new(0, 6)
    
                    rackBtn.MouseButton1Click:Connect(function()
                        local character = LocalPlayer.Character
                        local rootPart = character and character:FindFirstChild("HumanoidRootPart")
                        if rootPart and rack.Part and rack.Part.Parent then
                            pcall(function()
                                local targetCFrame = rack.Part.CFrame
                                local safePos = targetCFrame + (targetCFrame.LookVector * -3.5) + Vector3.new(0, 0.5, 0)
                                rootPart.CFrame = CFrame.new(safePos.Position, targetCFrame.Position)
                            end)
                        end
                    end)
                    yOffset = yOffset + itemHeight + itemSpacing
                end
            end
            scrollingContent.CanvasSize = UDim2.new(0, 0, 0, yOffset + 10)
        end
    
        putBtn.MouseButton1Click:Connect(function()
            rackListPanel.Visible = not rackListPanel.Visible
            if rackListPanel.Visible then
                cachedRacks = getAllMapBRacks()
                searchBar.Text = ""
                updateRackListUI("")
            end
        end)
    
        searchBar:GetPropertyChangedSignal("Text"):Connect(function() updateRackListUI(searchBar.Text) end)
    
        local function triggerGrabMapB()
            if textBox.Text ~= "" then getgenv().ExecutePreciseGrabMapB(textBox.Text, maxBox.Text) end
        end
        btn.MouseButton1Click:Connect(triggerGrabMapB)
        textBox.FocusLost:Connect(function(enter) if enter then triggerGrabMapB() end end)
        maxBox.FocusLost:Connect(function(enter) if enter then triggerGrabMapB() end end)
        print("[Map B] Berhasil dimuat!")
    end
    
    -- ================================================================
    -- [BAGIAN 3] MENU UTAMA PEMILIHAN MAP (SELECTOR GUI)
    -- ================================================================
    local selectorGui = Instance.new("ScreenGui")
    selectorGui.Name = "MapSelectorGui"
    selectorGui.ResetOnSpawn = false
    pcall(function() selectorGui.Parent = CoreGui end)
    if not selectorGui.Parent then selectorGui.Parent = playerGui end
    
    local selectorFrame = Instance.new("Frame", selectorGui)
    selectorFrame.Size = UDim2.new(0, 260, 0, 150)
    selectorFrame.Position = UDim2.new(0.5, -130, 0.4, -75)
    selectorFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    selectorFrame.BorderSizePixel = 0
    selectorFrame.Active = true
    selectorFrame.Draggable = true
    Instance.new("UICorner", selectorFrame).CornerRadius = UDim.new(0, 8)
    
    local selTopBar = Instance.new("Frame", selectorFrame)
    selTopBar.Size = UDim2.new(1, 0, 0, 28)
    selTopBar.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    Instance.new("UICorner", selTopBar).CornerRadius = UDim.new(0, 8)
    
    local selTitle = Instance.new("TextLabel", selTopBar)
    selTitle.Size = UDim2.new(1, 0, 1, 0)
    selTitle.BackgroundTransparency = 1
    selTitle.Font = Enum.Font.GothamBold
    selTitle.Text = "🎮 PILIH MAP SCRIPT"
    selTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    selTitle.TextSize = 12
    
    -- Tombol Map A
    local btnMapA = Instance.new("TextButton", selectorFrame)
    btnMapA.Size = UDim2.new(1, -20, 0, 38)
    btnMapA.Position = UDim2.new(0, 10, 0, 42)
    btnMapA.BackgroundColor3 = Color3.fromRGB(0, 150, 90)
    btnMapA.Font = Enum.Font.GothamBold
    btnMapA.Text = "Map A (Store / Tycoon)"
    btnMapA.TextColor3 = Color3.fromRGB(255, 255, 255)
    btnMapA.TextSize = 11
    Instance.new("UICorner", btnMapA).CornerRadius = UDim.new(0, 6)
    
    -- Tombol Map B
    local btnMapB = Instance.new("TextButton", selectorFrame)
    btnMapB.Size = UDim2.new(1, -20, 0, 38)
    btnMapB.Position = UDim2.new(0, 10, 0, 90)
    btnMapB.BackgroundColor3 = Color3.fromRGB(50, 110, 200)
    btnMapB.Font = Enum.Font.GothamBold
    btnMapB.Text = "Map B (Library / Buku 1-N)"
    btnMapB.TextColor3 = Color3.fromRGB(255, 255, 255)
    btnMapB.TextSize = 11
    Instance.new("UICorner", btnMapB).CornerRadius = UDim.new(0, 6)
    
    -- Event Pilih Map A
    btnMapA.MouseButton1Click:Connect(function()
        selectorGui:Destroy()
        loadMapA()
    end)
    
    -- Event Pilih Map B
    btnMapB.MouseButton1Click:Connect(function()
        selectorGui:Destroy()
        loadMapB()
    end)
    
    print("[Universal Loader] Silakan pilih map yang ingin dimainkan!")
    
end
function Feature.Start()
    if started then
        local gui = game:GetService("CoreGui"):FindFirstChild("MapSelectorGui")
        if gui then gui.Enabled = true end
        return true
    end
    started = true
    local ok, err = pcall(runLegacy)
    if not ok then
        started = false
        warn("[Tryo TPitem] "..tostring(err))
        return false, err
    end
    return true
end
function Feature.Stop()
    started = false
    local player = game:GetService("Players").LocalPlayer
    local roots = {game:GetService("CoreGui"), player and player:FindFirstChildOfClass("PlayerGui")}
    for _, root in ipairs(roots) do
        if root then
            for _, name in ipairs({"MapSelectorGui","PreciseGrabGui","MapBLibraryGui"}) do
                local gui = root:FindFirstChild(name)
                if gui then pcall(function() gui:Destroy() end) end
            end
        end
    end
    pcall(function()
        if type(getgenv) == "function" then
            local env = getgenv()
            env.ExecutePreciseGrab = nil
            env.ExecutePreciseGrabMapB = nil
        end
    end)
    return true
end
return Feature
