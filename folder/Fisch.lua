-- =========================================================================
-- 1. LOAD UI LIBRARY & CREATE WINDOW
-- =========================================================================
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/archlnx324-collab/PatronsScripts/refs/heads/main/library.lua"))()

local Window = Library:CreateWindow({
    Name = "Fisch Auto - Optimized",
    Size = UDim2.fromOffset(710, 470),
    Theme = "Monochrome",
    ToggleKey = Enum.KeyCode.RightShift
})

-- =========================================================================
-- 2. SERVICES & DECOMPILED PATHS SETUP
-- =========================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild('PlayerGui')

local Net = require(ReplicatedStorage.packages.Net)
local EquipBaitRemote = Net:RemoteEvent("Bait/Equip", -1)

local ok_rc, ReelController = pcall(function()
    return require(ReplicatedStorage.client.legacyControllers.ReelController)
end)
if not ok_rc or type(ReelController) ~= 'table' then
    warn('[fish] failed to require ReelController')
end

-- =========================================================================
-- 3. CONFIGURATION & STATE
-- =========================================================================
local config = {
    enabled = false,
    lookahead = 0.15,
    instantCatch = true,
}

local active_rod = nil
local running = false
local generation = 0
local cast_loop_active = false
local shaking = false
local SHAKE_INTERVAL = 0.26

-- =========================================================================
-- 4. HELPER FUNCTIONS
-- =========================================================================
-- ⚡ INSTANT TELEPORT (NO TWEENING) ⚡
local function topos(pos)
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local hrp = char.HumanoidRootPart
    hrp.CFrame = pos -- Instantly sets position without tweening
end

local function equip_bait(bait_name)
    pcall(function()
        EquipBaitRemote:FireServer(bait_name or "None")
    end)
end

local function get_best_bait()
    local ok, legacyLocalPlayerData = pcall(function()
        return require(ReplicatedStorage.client.modules.legacyLocalPlayerData)
    end)
    if not ok then return "None" end

    local player_data = legacyLocalPlayerData.fetch()
    local stats = player_data:WaitForChild("Stats", 5)
    if not stats then return "None" end

    local bait_folder = stats:WaitForChild("bait", 5)
    if not bait_folder then return "None" end

    local bait_priority = {
        "Magnet", "Truffle Worm", "Squid", "Flakes", "Mystery Bait", "Worm", "Maggot", "None"
    }

    for _, bait_name in ipairs(bait_priority) do
        local bait_child = bait_folder:FindFirstChild("bait_" .. bait_name)
        if bait_child and bait_child:IsA("NumberValue") and bait_child.Value > 0 then
            return bait_name
        end
    end
    return "None"
end

local function find_shake_button()
    local gui = PlayerGui:FindFirstChild('shakeui', true)
    if not (gui and gui:IsA('ScreenGui') and gui.Enabled) then return nil end
    local safe = gui:FindFirstChild('safezone')
    if not safe then return nil end
    for _, c in ipairs(safe:GetChildren()) do
        if c:IsA('GuiButton') then return c end
        if c:FindFirstChild('consoleStroke') then return c end
    end
    return nil
end

local function shake_ui_active()
    return find_shake_button() ~= nil
end

local function shake_start()
    if shaking then return end
    shaking = true
    task.spawn(function()
        while shaking do
            local btn = find_shake_button()
            if btn then
                local ok = pcall(function() btn:Activate() end)
                if not ok then
                    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
                end
            end
            task.wait(SHAKE_INTERVAL)
        end
    end)
end

local function shake_stop() 
    shaking = false 
end

local function is_rod(tool)
    return tool ~= nil and tool:IsA('Tool')
        and tool:FindFirstChild('rodClient') ~= nil
        and tool:FindFirstChild('values') ~= nil
end

local ROD_STATE_EQUIPPED = 3
local ROD_STATE_SEARCHING = 5
local ROD_STATE_LURING = 6
local ROD_STATE_PRE_REEL = 7

local function get_values(tool)
    return tool and tool:FindFirstChild('values')
end

local function is_green_zone(tool)
    local values = get_values(tool)
    if not values then return false end
    local zone = values:FindFirstChild('bobberzone')
    return zone ~= nil and zone.Value == true
end

local function has_bobber(tool)
    return tool ~= nil and tool:FindFirstChild('bobber') ~= nil
end

local FishingRodClient = require(ReplicatedStorage.client.legacyControllers.FishingRodController.FishingRodClient)

local function wait_until_castable(tool, gen, timeout)
    local rod = FishingRodClient.Active
    local deadline = tick() + (timeout or 60)

    while config.enabled and running and generation == gen and tick() < deadline do
        if tool.Parent == nil then return false end
        if ReelController.ActiveReel ~= nil then return false end

        rod = FishingRodClient.Active
        local state
        if rod and rod.Tool == tool then
            state = rod.State
        else
            local values = get_values(tool)
            local sv = values and values:FindFirstChild('state')
            state = sv and sv.Value
        end
        if state == nil then task.wait(0.05); continue end

        if state >= ROD_STATE_PRE_REEL then
            task.wait(0.1)
            continue
        end

        if not has_bobber(tool) then
            if state == ROD_STATE_EQUIPPED or state == ROD_STATE_LURING then
                return true
            end
        else
            if (state == ROD_STATE_SEARCHING or state == ROD_STATE_LURING) and is_green_zone(tool) then
                return true
            end
        end
        task.wait(0.05)
    end
    return false
end

local function wait_for_rod_init(tool, timeout)
    local deadline = tick() + (timeout or 2)
    while tick() < deadline do
        if tool.Parent == nil then return false end
        if tool:FindFirstChild('events') and tool:FindFirstChild('values') then
            return true
        end
        task.wait(0.05)
    end
    return false
end

local function start_cast_loop(gen)
    if cast_loop_active then return end
    cast_loop_active = true

    task.spawn(function()
        while config.enabled and running and generation == gen do
            while ReelController.ActiveReel ~= nil and generation == gen do task.wait(0.1) end
            if generation ~= gen then break end

            task.wait(0.2)
            if generation ~= gen then break end

            if not wait_until_castable(active_rod, gen, 60) then
                if generation ~= gen or not config.enabled then break end
                task.wait(0.5)
                continue
            end

            local CastRemote = Net:RemoteFunction("FishingRod/Cast", -1)
            task.wait(0.1)
            
            local success = CastRemote:InvokeServer(95, true)
            if not success then
                warn("[fish] cast rejected by server")
            end
            
            if generation ~= gen then break end

            local deadline = tick() + 30
            while tick() < deadline and generation == gen do
                if ReelController.ActiveReel ~= nil then break end
                if shake_ui_active() then
                    while shake_ui_active() and tick() < deadline and generation == gen do
                        task.wait(0.1)
                    end
                    break
                end
                task.wait(0.1)
            end
            if generation ~= gen then break end

            while ReelController.ActiveReel == nil and tick() < deadline and generation == gen do task.wait(0.1) end
            if generation ~= gen then break end
            while ReelController.ActiveReel ~= nil and generation == gen do task.wait(0.1) end
            if generation ~= gen then break end

            task.wait(1)
        end
        cast_loop_active = false
    end)
end

local function begin_rod(tool)
    if not is_rod(tool) then return end
    if active_rod == tool then return end
    active_rod = tool
    generation += 1
    local gen = generation

    local best_bait = get_best_bait()
    equip_bait(best_bait)
    print("[fish] auto-equipped best available bait: " .. best_bait)

    task.delay(0.3, function()
        if not config.enabled then return end
        if generation ~= gen or active_rod ~= tool or tool.Parent == nil then return end
        if not wait_for_rod_init(tool, 2) then
            warn('[fish] rod did not initialize in time')
            return
        end
        if generation ~= gen then return end
        running = true
        start_cast_loop(gen)
    end)
end

local equip_conn, unequip_conn

local function enable()
    if config.enabled then return end
    config.enabled = true

    local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    for _, t in Character:GetChildren() do
        if is_rod(t) then begin_rod(t); break end
    end

    equip_conn = ContextActionService.LocalToolEquipped:Connect(begin_rod)
    unequip_conn = ContextActionService.LocalToolUnequipped:Connect(function(tool)
        if active_rod ~= tool then return end
        active_rod = nil
        running = false
        generation += 1
        shake_stop()
    end)
end

local function disable()
    if not config.enabled then return end
    config.enabled = false
    running = false
    active_rod = nil
    generation += 1
    shake_stop()
    if equip_conn then equip_conn:Disconnect(); equip_conn = nil end
    if unequip_conn then unequip_conn:Disconnect(); unequip_conn = nil end
end

-- =========================================================================
-- 5. UI SETUP
-- =========================================================================
local FishingTab = Window:CreateTab({
    Name = "Fishing",
    Icon = "farm"
})

local ControlsGroup = FishingTab:AddGroup("Left", "Controls")
local TuningGroup = FishingTab:AddGroup("Right", "Tuning")

ControlsGroup:AddButton({
    Text = "Teleport to Nearest Treasure",
    Callback = function()
        print("Teleporting to treasure...")
    end
})

ControlsGroup:AddToggle({
    Text = "Fishing Auto",
    Default = config.enabled,
    Callback = function(state)
        if state then
            enable()
            print('[fish] enabled')
        else
            disable()
            print('[fish] disabled')
        end
    end
})

TuningGroup:AddSlider({
    Text = "Reel Lead (Lookahead)",
    Min = 0.00,
    Max = 0.50,
    Step = 0.01,
    Decimals = 2,
    Default = config.lookahead,
    Callback = function(v)
        config.lookahead = v
    end
})

TuningGroup:AddToggle({
    Text = "Instant Catch",
    Default = config.instantCatch,
    Callback = function(state)
        config.instantCatch = state
        print("[fish] Instant Catch " .. (state and "Enabled" or "Disabled"))
    end
})

-- =========================================================================
-- 6. TELEPORT TAB SETUP (WITH SEARCH)
-- =========================================================================
local TeleportTab = Window:CreateTab({
    Name = "Teleport",
    Icon = "teleport"
})

local ZoneGroup = TeleportTab:AddGroup("Left", "Zone Teleports")

-- Full list of zones (scanned once)
local allZones = {}
local function getZones()
    local list = {}
    local zonesFolder = workspace:FindFirstChild("zones") or workspace:FindFirstChild("Zones")
    if zonesFolder then
        local playerZones = zonesFolder:FindFirstChild("player") or zonesFolder:FindFirstChild("Player")
        if playerZones then
            for _, zone in ipairs(playerZones:GetChildren()) do
                if zone:IsA("BasePart") or zone:IsA("Model") then
                    table.insert(list, zone.Name)
                end
            end
        end
    end
    table.sort(list)
    if #list == 0 then table.insert(list, "No Zones Found") end
    return list
end

allZones = getZones()
_G.SelectedZone = allZones[1]

-- 🔍 SEARCH INPUT (filters the dropdown as you type)
local ZoneDropdown
ZoneGroup:AddInput({
    Label = "Search Zone",
    Placeholder = "type to filter...",
    Default = "",
    Callback = function(text)
        local query = text:lower():gsub("^%s*(.-)%s*$", "%1")
        local filtered = {}
        
        if query == "" then
            filtered = allZones
        else
            for _, name in ipairs(allZones) do
                if name:lower():find(query, 1, true) then
                    table.insert(filtered, name)
                end
            end
        end
        
        if #filtered == 0 then filtered = {"No Matches"} end
        
        -- Update the dropdown with filtered results
        if ZoneDropdown then
            ZoneDropdown:SetOptions(filtered, filtered[1])
            _G.SelectedZone = filtered[1]
        end
    end
})

-- The actual dropdown (gets updated by the search box)
ZoneDropdown = ZoneGroup:AddDropdown({
    Text = "Select Zone",
    Options = allZones,
    Default = allZones[1],
    Callback = function(value)
        _G.SelectedZone = value
    end
})

ZoneGroup:AddButton({
    Text = "Refresh Zone List",
    Callback = function()
        allZones = getZones()
        ZoneDropdown:SetOptions(allZones, allZones[1])
        _G.SelectedZone = allZones[1]
        print("✅ Zone list refreshed! Found: " .. #allZones .. " zones.")
    end
})

ZoneGroup:AddButton({
    Text = "Teleport to Selected Zone",
    Primary = true,
    Callback = function()
        local targetName = _G.SelectedZone
        if not targetName or targetName == "No Zones Found" or targetName == "No Matches" then
            print("⚠️ Please select a valid zone.")
            return
        end

        local teleported = false
        local zonesFolder = workspace:FindFirstChild("zones") or workspace:FindFirstChild("Zones")
        if zonesFolder then
            local playerZones = zonesFolder:FindFirstChild("player") or zonesFolder:FindFirstChild("Player")
            if playerZones then
                local target = playerZones:FindFirstChild(targetName)
                if target then
                    local cf
                    if target:IsA("BasePart") then
                        cf = target.CFrame
                    elseif target:IsA("Model") then
                        cf = target:GetPivot()
                    end
                    
                    if cf then
                        topos(cf + Vector3.new(0, 5, 0))
                        print("✅ Teleported to: " .. targetName)
                        teleported = true
                    end
                end
            end
        end
        
        -- Fallback search
        if not teleported then
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("BasePart") and obj.Name == targetName then
                    topos(obj.CFrame + Vector3.new(0, 5, 0))
                    print("✅ Teleported (fallback) to: " .. targetName)
                    teleported = true
                    break
                end
            end
        end
        
        if not teleported then
            print("❌ Could not find: " .. tostring(targetName))
        end
    end
})
-- =========================================================================
-- 7. MISC TAB SETUP
-- =========================================================================
local MiscTab = Window:CreateTab({
    Name = "Misc",
    Icon = "configs"
})

local MovementGroup = MiscTab:AddGroup("Left", "Movement")
local TeleportGroup = MiscTab:AddGroup("Right", "Teleport")

MovementGroup:AddToggle({
    Text = "Fly",
    Default = false,
    Callback = function(state)
        _G.FlyEnabled = state
        local char = LocalPlayer.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        if state then
            local bv = Instance.new("BodyVelocity")
            bv.MaxForce = Vector3.new(100000, 100000, 100000)
            bv.Velocity = Vector3.new(0, 0, 0)
            bv.Parent = hrp
            
            local bg = Instance.new("BodyGyro")
            bg.MaxTorque = Vector3.new(100000, 100000, 100000)
            bg.P = 10000
            bg.Parent = hrp
            
            _G.flyBV = bv
            _G.flyBG = bg
            char.Humanoid.PlatformStand = true
            
            task.spawn(function()
                while _G.FlyEnabled and char.Parent do
                    local camera = workspace.CurrentCamera
                    local moveDir = Vector3.new(0, 0, 0)
                    if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + camera.CFrame.LookVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - camera.CFrame.LookVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - camera.CFrame.RightVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + camera.CFrame.RightVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0, 1, 0) end
                    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir = moveDir - Vector3.new(0, 1, 0) end
                    
                    moveDir = moveDir.Unit * 100
                    bv.Velocity = moveDir
                    bg.CFrame = camera.CFrame
                    task.wait()
                end
                if _G.flyBV then _G.flyBV:Destroy() end
                if _G.flyBG then _G.flyBG:Destroy() end
                if char and char:FindFirstChild("Humanoid") then char.Humanoid.PlatformStand = false end
            end)
        else
            if _G.flyBV then _G.flyBV:Destroy() end
            if _G.flyBG then _G.flyBG:Destroy() end
            if char and char:FindFirstChild("Humanoid") then char.Humanoid.PlatformStand = false end
        end
    end
})

MovementGroup:AddSlider({
    Text = "Walk Speed",
    Min = 16,
    Max = 200,
    Step = 1,
    Decimals = 0,
    Default = 16,
    Callback = function(v)
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.WalkSpeed = v
        end
    end
})

MovementGroup:AddSlider({
    Text = "Jump Power",
    Min = 50,
    Max = 300,
    Step = 1,
    Decimals = 0,
    Default = 50,
    Callback = function(v)
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.JumpPower = v
        end
    end
})

MovementGroup:AddToggle({
    Text = "No Clip",
    Default = false,
    Callback = function(state)
        _G.NoClip = state
    end
})

TeleportGroup:AddToggle({
    Text = "Ctrl + Click Teleport",
    Default = false,
    Callback = function(state)
        _G.CtrlClickTP = state
    end
})

RunService.Stepped:Connect(function()
    if _G.NoClip and LocalPlayer.Character then
        for _, v in pairs(LocalPlayer.Character:GetDescendants()) do
            if v:IsA("BasePart") then
                v.CanCollide = false
            end
        end
    end
end)

local Mouse = LocalPlayer:GetMouse()
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if _G.CtrlClickTP and input.KeyCode == Enum.KeyCode.LeftControl then
        _G.isCtrlPressed = true
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if _G.CtrlClickTP and input.KeyCode == Enum.KeyCode.LeftControl then
        _G.isCtrlPressed = false
    end
end)

Mouse.Button1Down:Connect(function()
    if _G.CtrlClickTP and _G.isCtrlPressed then
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            local targetPos = Mouse.Hit.Position
            topos(CFrame.new(targetPos.X, targetPos.Y + 3, targetPos.Z))
        end
    end
end)

-- =========================================================================
-- 8. CORE EVENT CONNECTIONS & INFINITE PROGRESS SPEED
-- =========================================================================
PlayerGui.DescendantAdded:Connect(function(d)
    if d.Name == 'shakeui' and d:IsA('ScreenGui') then shake_start() end
end)
PlayerGui.DescendantRemoving:Connect(function(d)
    if d.Name == 'shakeui' and d:IsA('ScreenGui') then shake_stop() end
end)

RunService.RenderStepped:Connect(function()
    if not (config.enabled and running) then
        if shaking then shake_stop() end
        return
    end
    if shaking and not shake_ui_active() then shake_stop() end
end)

RunService.RenderStepped:Connect(function(dt)
    if not (config.enabled and running) then return end
    local reel = ReelController.ActiveReel
    
    if not reel or not reel.ready or not reel.active then return end

    local fishc = reel.core and reel.core.fish
    if fishc then
        local fish = reel.fishPosition
        local fishv = fishc.CurrentVelocity or 0
        local pf = math.clamp(fish + fishv * config.lookahead, 0, 1)
        reel.barPosition = pf
        reel.onbar = true
    end

    if config.instantCatch and not reel.progressLocked then
        reel.progress = 100 
    end
end)

LocalPlayer.Idled:Connect(function()
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new(0, 0))
    end)
end)

pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Fisch Auto",
        Text = "Script Loaded! (Instant Teleport Active)",
        Duration = 3
    })
end)
