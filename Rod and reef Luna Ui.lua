-- // Luna UI - Rod And Reef Beta (Fixed)

local function loadLuna()
	local urls = {
		"https://raw.nebulasoftworks.xyz/luna",
		"https://raw.githubusercontent.com/Nebula-Softworks/Luna-Interface-Suite/refs/heads/master/source.lua"
	}
	for _, url in ipairs(urls) do
		local ok, res = pcall(function()
			return loadstring(game:HttpGet(url, true))()
		end)
		if ok and res then
			return res
		end
	end
	return nil
end

local Luna = loadLuna()
if not Luna then
	warn("[Rod And Reef] Failed to load Luna UI library.")
	return
end

local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local mouse = player:GetMouse()

local function notify(title, content, icon)
	pcall(function()
		Luna:Notification({
			Title = title,
			Icon = icon or "notifications_active",
			ImageSource = "Material",
			Content = content
		})
	end)
end

local Window = Luna:CreateWindow({
	Name = "Rod And Reef Beta",
	Subtitle = "Auto Cast + Insta Catch",
	LogoID = nil,
	LoadingEnabled = false,
	LoadingTitle = "Rod And Reef Beta",
	LoadingSubtitle = "Auto Cast + Insta Catch",
	ConfigSettings = {
		RootFolder = nil,
		ConfigFolder = "RodAndReefBeta"
	},
	KeySystem = false,
	KeySettings = {
		Title = "Rod And Reef Beta",
		Subtitle = "Key System",
		Note = "Disabled",
		SaveInRoot = false,
		SaveKey = false,
		Key = {"None"}
	}
})

local AutoFarmTab = Window:CreateTab({
	Name = "Auto Farm",
	Icon = "view_in_ar",
	ImageSource = "Material",
	ShowTitle = true
})

local PlayerTab = Window:CreateTab({
	Name = "Player",
	Icon = "star",
	ImageSource = "Material",
	ShowTitle = true
})

local TeleportTab = Window:CreateTab({
	Name = "Teleport",
	Icon = "location_searching",
	ImageSource = "Material",
	ShowTitle = true
})

local SettingsTab = Window:CreateTab({
	Name = "Settings",
	Icon = "settings",
	ImageSource = "Material",
	ShowTitle = true
})

-- ============================================================
-- // AUTO FARM TAB
-- ============================================================
AutoFarmTab:CreateSection("Auto Fish")

local castThread = nil
local targetModules = {"TensionMinigame", "CircularMinigame"}
local hooks = {}

local chargeTime = 1.2
local castCooldown = 1.0
local autoFisherEnabled = false

local function hasActiveBobber()
	for _, child in ipairs(Workspace:GetChildren()) do
		if child:IsA("BasePart") and child.Name == "bobber" then
			if child:GetAttribute("Owner") == player.UserId then
				return true
			end
		end
	end
	return false
end

local function findWaterParts()
	local waterParts = {}
	local waterNames = {"Water", "Ocean", "Lake", "Sea", "River", "Pond"}
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("BasePart") then
			for _, name in ipairs(waterNames) do
				if string.find(descendant.Name:lower(), name:lower()) then
					table.insert(waterParts, descendant)
					break
				end
			end
		end
	end
	return waterParts
end

local function getWaterScreenPos()
	local camera = Workspace.CurrentCamera
	if not camera or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
		return camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2
	end
	local playerPos = player.Character.HumanoidRootPart.Position
	local waterParts = findWaterParts()
	local closestWater = nil
	local shortestDistance = math.huge
	for _, waterPart in ipairs(waterParts) do
		local distance = (waterPart.Position - playerPos).Magnitude
		if distance < shortestDistance and distance < 200 then
			shortestDistance = distance
			closestWater = waterPart
		end
	end
	if closestWater then
		local screenPos, onScreen = camera:WorldToViewportPoint(closestWater.Position)
		if onScreen then return screenPos.X, screenPos.Y end
	end
	local origin = camera.CFrame.Position
	local direction = (camera.CFrame.LookVector * 100) + Vector3.new(0, -30, 0)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {player.Character}
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	local result = Workspace:Raycast(origin, direction, raycastParams)
	if result then
		local screenPos, onScreen = camera:WorldToViewportPoint(result.Position)
		if onScreen then return screenPos.X, screenPos.Y end
	end
	return camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2
end

local function hookModules()
	local success, modules = pcall(getloadedmodules)
	if not success then return end
	for _, module in ipairs(modules) do
		if table.find(targetModules, module.Name) then
			local reqSuccess, modTable = pcall(require, module)
			if reqSuccess and type(modTable) == "table" and modTable.start then
				hooks[module] = modTable.start
				modTable.start = function(biteData, callback, configCallback)
					if configCallback and type(configCallback) == "function" then pcall(configCallback, {}) end
					task.delay(0.05, function() if callback then callback(true) end end)
				end
			end
		end
	end
end

local function unhookModules()
	for module, originalStart in pairs(hooks) do
		if module and module.start then module.start = originalStart end
	end
	hooks = {}
end

local function setAutoFisherState(Value)
	if Value == autoFisherEnabled then return end
	autoFisherEnabled = Value

	if Value then
		hookModules()
		castThread = task.spawn(function()
			notify("Auto Fisher On", "Casting + Insta Catch enabled!")
			while autoFisherEnabled do
				if not hasActiveBobber() then
					local x, y = getWaterScreenPos()
					pcall(function() VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1) end)
					task.wait(chargeTime)
					pcall(function() VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1) end)
				end
				task.wait(castCooldown)
			end
		end)
	else
		if castThread then task.cancel(castThread) castThread = nil end
		unhookModules()
		notify("Auto Fisher Off", "Stopped casting and catching.")
	end
end

AutoFarmTab:CreateLabel({
	Text = "Smart Water Detection: Automatically finds water and aims",
	Style = 2
})

AutoFarmTab:CreateLabel({
	Text = "Insta Catch: Auto-completes minigames",
	Style = 2
})

AutoFarmTab:CreateDivider()

AutoFarmTab:CreateSlider({
	Name = "Charge Time (Seconds)",
	Range = {0.5, 2.5},
	Increment = 0.1,
	CurrentValue = 1.2,
	Callback = function(Value)
		chargeTime = Value
	end
}, "ChargeTime")

AutoFarmTab:CreateSlider({
	Name = "Cooldown After Cast (Seconds)",
	Range = {0.5, 3.0},
	Increment = 0.1,
	CurrentValue = 1.0,
	Callback = function(Value)
		castCooldown = Value
	end
}, "Cooldown")

AutoFarmTab:CreateDivider()

local AutoFisherToggle
AutoFisherToggle = AutoFarmTab:CreateToggle({
	Name = "Enable Auto Fisher (Cast + Insta Catch)",
	Description = "Automatically casts into nearest water and completes minigames",
	CurrentValue = false,
	Callback = function(Value)
		setAutoFisherState(Value)
	end
}, "AutoFisher")

AutoFarmTab:CreateDivider()

AutoFarmTab:CreateBind({
	Name = "Auto Fisher Shortcut",
	Description = "Quick toggle shortcut (works even when the UI is closed)",
	CurrentBind = "F",
	HoldToInteract = false,
	Callback = function()
		local nextState = not autoFisherEnabled
		pcall(function() AutoFisherToggle:Set({ CurrentValue = nextState }) end)
		setAutoFisherState(nextState)
	end
}, "AutoFisherBind")

-- ============================================================
-- // PLAYER TAB
-- ============================================================
PlayerTab:CreateSection("Movement")

local walkSpeedValue = 16
local jumpPowerValue = 50
local flySpeedValue = 50
local flyEnabled = false
local clickTeleportEnabled = false

local flyThread = nil
local flyBody = nil

PlayerTab:CreateSlider({
	Name = "Walkspeed",
	Range = {16, 200},
	Increment = 1,
	CurrentValue = 16,
	Callback = function(Value)
		walkSpeedValue = Value
		if player.Character and player.Character:FindFirstChild("Humanoid") then
			player.Character.Humanoid.WalkSpeed = Value
		end
	end
}, "WalkSpeed")

PlayerTab:CreateSlider({
	Name = "Jump Power",
	Range = {50, 200},
	Increment = 1,
	CurrentValue = 50,
	Callback = function(Value)
		jumpPowerValue = Value
		if player.Character and player.Character:FindFirstChild("Humanoid") then
			player.Character.Humanoid.UseJumpPower = true
			player.Character.Humanoid.JumpPower = Value
		end
	end
}, "JumpPower")

PlayerTab:CreateDivider()

PlayerTab:CreateSlider({
	Name = "Fly Speed",
	Range = {10, 300},
	Increment = 1,
	CurrentValue = 50,
	Callback = function(Value)
		flySpeedValue = Value
	end
}, "FlySpeed")

local FlyToggle
local function setFlyState(Value)
	if Value == flyEnabled then return end

	local char = player.Character
	local hum = char and char:FindFirstChild("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")

	if Value and not (hrp and hum) then
		notify("Error", "Character not found!")
		pcall(function() FlyToggle:Set({ CurrentValue = false }) end)
		return
	end

	flyEnabled = Value

	if Value then
		hum.WalkSpeed = 0
		hum.JumpPower = 0
		flyBody = Instance.new("BodyVelocity")
		flyBody.Name = "RR_FlyBody"
		flyBody.MaxForce = Vector3.new(1e4, 1e4, 1e4)
		flyBody.Velocity = Vector3.new(0, 0, 0)
		flyBody.Parent = hrp
		flyThread = task.spawn(function()
			local camera = Workspace.CurrentCamera
			while flyEnabled and flyBody and flyBody.Parent do
				local move = Vector3.new(0, 0, 0)
				if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + camera.CFrame.LookVector end
				if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - camera.CFrame.LookVector end
				if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - camera.CFrame.RightVector end
				if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + camera.CFrame.RightVector end
				if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0, 1, 0) end
				if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move = move - Vector3.new(0, 1, 0) end
				if move.Magnitude > 0 then move = move.Unit end
				flyBody.Velocity = move * flySpeedValue
				task.wait()
			end
			if flyBody then flyBody:Destroy() flyBody = nil end
			if hum and hum.Parent then
				hum.WalkSpeed = walkSpeedValue
				hum.JumpPower = jumpPowerValue
			end
		end)
		notify("Fly On", "WASD + Space/Ctrl to move!")
	else
		if flyThread then task.cancel(flyThread) flyThread = nil end
		if flyBody then flyBody:Destroy() flyBody = nil end
		if hum then
			hum.WalkSpeed = walkSpeedValue
			hum.JumpPower = jumpPowerValue
		end
		notify("Fly Off", "Movement restored.")
	end
end

FlyToggle = PlayerTab:CreateToggle({
	Name = "Enable Fly",
	Description = "Fly around using WASD + Space / Left Ctrl",
	CurrentValue = false,
	Callback = function(Value)
		setFlyState(Value)
	end
}, "Fly")

PlayerTab:CreateDivider()

PlayerTab:CreateToggle({
	Name = "Enable Teleport (Ctrl + Click)",
	Description = "Hold CTRL and left click anywhere to teleport",
	CurrentValue = false,
	Callback = function(Value)
		clickTeleportEnabled = Value
		notify(
			Value and "Teleport On" or "Teleport Off",
			Value and "Hold CTRL and click to teleport!" or "Teleport disabled."
		)
	end
}, "ClickTeleport")

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if clickTeleportEnabled and input.UserInputType == Enum.UserInputType.MouseButton1 then
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) then
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp then
				local targetPos = mouse.Hit.Position + Vector3.new(0, 4, 0)
				hrp.CFrame = CFrame.new(targetPos)
				notify("Teleported", "Moved to cursor location!")
			end
		end
	end
end)

player.CharacterAdded:Connect(function(char)
	task.wait(1)
	local hum = char:FindFirstChild("Humanoid")
	if hum then
		hum.WalkSpeed = walkSpeedValue
		hum.JumpPower = jumpPowerValue
		hum.UseJumpPower = true
	end
	if flyEnabled then
		setFlyState(false)
		task.wait(0.1)
		setFlyState(true)
	end
end)

-- ============================================================
-- // TELEPORT TAB (ISLANDS + NPC SEARCH)
-- ============================================================
TeleportTab:CreateSection("Island Teleports")

local teleportLocations = {
	["Corvane"] = Vector3.new(3766.02, 17.36, 64.31),
	["Verdant Isle"] = Vector3.new(-104.94, 35.89, 11.76)
}

local locationNames = {}
for name, _ in pairs(teleportLocations) do
	table.insert(locationNames, name)
end
table.sort(locationNames)

local selectedIsland = "Verdant Isle"

TeleportTab:CreateLabel({
	Text = "Quick Travel: Select an island to instantly travel.",
	Style = 1
})

TeleportTab:CreateDropdown({
	Name = "Select Destination",
	Description = "Choose an island to teleport to",
	Options = locationNames,
	CurrentOption = {"Verdant Isle"},
	MultipleOptions = false,
	SpecialType = nil,
	Callback = function(Option)
		selectedIsland = type(Option) == "table" and Option[1] or Option
	end
}, "IslandSelect")

TeleportTab:CreateButton({
	Name = "Teleport to Island",
	Description = "Teleport directly to the selected island",
	Callback = function()
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			local targetPos = teleportLocations[selectedIsland]
			if targetPos then
				hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 5, 0))
				notify("Teleported!", "Successfully moved to " .. selectedIsland .. ".")
			else
				notify("Error", "Coordinates not found for " .. tostring(selectedIsland))
			end
		else
			notify("Error", "Character not found! Make sure you are alive.")
		end
	end
})

-- // NPC TELEPORT SCANNER WITH SEARCH
TeleportTab:CreateSection("NPC Teleports")

local npcFolder = Workspace:FindFirstChild("DialogueNPCs") or Workspace:WaitForChild("DialogueNPCs", 3)
local npcDatabase = {}

if npcFolder then
	for _, model in ipairs(npcFolder:GetChildren()) do
		if model:IsA("Model") then
			local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
			if root then
				table.insert(npcDatabase, { Name = model.Name, Pos = root.Position })
			end
		end
	end
end

table.sort(npcDatabase, function(a, b) return a.Name < b.Name end)

local allNpcNames = {}
for _, npc in ipairs(npcDatabase) do
	table.insert(allNpcNames, npc.Name)
end
if #allNpcNames == 0 then
	allNpcNames = {"None"}
end

local selectedNPC = allNpcNames[1]
local NPCDropdown = nil

TeleportTab:CreateLabel({
	Text = "Found " .. #npcDatabase .. " NPCs - Type below to search, then teleport.",
	Style = 2
})

TeleportTab:CreateInput({
	Name = "Search NPC",
	Description = "Live-filters the NPC dropdown below",
	PlaceholderText = "Type to filter NPCs...",
	CurrentValue = "",
	Numeric = false,
	MaxCharacters = nil,
	Enter = false,
	Callback = function(Value)
		local filter = string.lower(Value or "")
		local filtered = {}
		if filter == "" then
			for _, n in ipairs(allNpcNames) do table.insert(filtered, n) end
		else
			for _, name in ipairs(allNpcNames) do
				if string.find(string.lower(name), filter, 1, true) then
					table.insert(filtered, name)
				end
			end
		end
		if #filtered == 0 then filtered = {"No NPCs found"} end

		selectedNPC = filtered[1]
		if NPCDropdown then
			local ok = pcall(function()
				NPCDropdown:Set({
					Options = filtered,
					CurrentOption = {filtered[1]}
				})
			end)
			if not ok then
				pcall(function()
					NPCDropdown:Set({
						Options = filtered,
						CurrentOption = filtered[1]
					})
				end)
			end
		end
	end
}, "NPCSearch")

NPCDropdown = TeleportTab:CreateDropdown({
	Name = "Select NPC",
	Description = "Choose an NPC from the filtered list",
	Options = allNpcNames,
	CurrentOption = {allNpcNames[1]},
	MultipleOptions = false,
	SpecialType = nil,
	Callback = function(Option)
		selectedNPC = type(Option) == "table" and Option[1] or Option
	end
}, "NPCSelect")

TeleportTab:CreateButton({
	Name = "Teleport to NPC",
	Description = "Teleport directly to the selected NPC",
	Callback = function()
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp then
			notify("Error", "Character not found!")
			return
		end
		for _, npc in ipairs(npcDatabase) do
			if npc.Name == selectedNPC then
				hrp.CFrame = CFrame.new(npc.Pos + Vector3.new(0, 5, 0))
				notify("Teleported!", "Moved to " .. selectedNPC)
				return
			end
		end
		notify("Error", "NPC '" .. tostring(selectedNPC) .. "' not found.")
	end
})

-- ============================================================
-- // SETTINGS TAB
-- ============================================================
SettingsTab:CreateSection("Interface")

pcall(function()
	SettingsTab:BuildThemeSection()
end)

pcall(function()
	SettingsTab:BuildConfigSection()
end)

notify("Rod And Reef Beta Loaded", "Scanned " .. #npcDatabase .. " NPCs! Use the search box.")
