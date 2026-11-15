-- // Obsidian UI - Rod And Reef Beta (Custom Keybind System)

local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/deividcomsono/Obsidian/main/Library.lua"))()
local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local mouse = player:GetMouse()

local Window = Library:CreateWindow({
	Title = "Rod And Reef Beta",
	Footer = "Auto Cast + Insta Catch • Combined",
	Center = true,
	AutoShow = true,
	NotifySide = "Right",
})

local AutoFarmTab = Window:AddTab("Auto Farm", "zap")
local PlayerTab = Window:AddTab("Player", "user")
local SettingsTab = Window:AddTab("Settings", "settings")

-- ============================================================
-- // AUTO FARM TAB
-- ============================================================
local SettingsGroup = AutoFarmTab:AddGroupbox({ Side = "Left", Name = "Auto Fish" })

local castThread = nil
local targetModules = {"TensionMinigame", "CircularMinigame"}
local hooks = {}

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

SettingsGroup:AddLabel("🎯 Smart Water Detection:", true)
SettingsGroup:AddLabel("Automatically finds water and aims", true)
SettingsGroup:AddLabel("⚡ Insta Catch: Auto-completes minigames", true)
SettingsGroup:AddDivider()
SettingsGroup:AddSlider("ChargeTime", { Text = "Charge Time (Seconds)", Default = 1.2, Min = 0.5, Max = 2.5, Rounding = 1 })
SettingsGroup:AddSlider("Cooldown", { Text = "Cooldown After Cast (Seconds)", Default = 1.0, Min = 0.5, Max = 3.0, Rounding = 1 })
SettingsGroup:AddDivider()

SettingsGroup:AddToggle("AutoFisher", {
	Text = "Enable Auto Fisher (Cast + Insta Catch)",
	Tooltip = "Auto-casts and instantly completes minigames",
	Default = false,
	Risky = true,
	Callback = function(Value)
		if Value then
			hookModules()
			castThread = task.spawn(function()
				Library:Notify({ Title = "Auto Fisher On", Description = "Casting + Insta Catch enabled!", Time = 3 })
				while Library.Toggles.AutoFisher.Value do
					if not hasActiveBobber() then
						local x, y = getWaterScreenPos()
						local charge = Library.Options.ChargeTime.Value
						pcall(function() VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1) end)
						task.wait(charge)
						pcall(function() VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1) end)
					end
					task.wait(Library.Options.Cooldown.Value)
				end
			end)
		else
			if castThread then task.cancel(castThread) castThread = nil end
			unhookModules()
			Library:Notify({ Title = "Auto Fisher Off", Description = "Stopped casting and catching.", Time = 2 })
		end
	end,
})

-- // CUSTOM KEYBIND SYSTEM
SettingsGroup:AddDivider()
SettingsGroup:AddLabel("⌨️ Quick Toggle Shortcut:", true)

local autoFishKey = Enum.KeyCode.F -- Default key
local isListeningForKey = false

SettingsGroup:AddButton({
	Text = "Set Auto Fisher Shortcut",
	Tooltip = "Click this, then press any key on your keyboard.",
	Func = function()
		if not isListeningForKey then
			isListeningForKey = true
			Library:Notify({ 
				Title = "Listening...", 
				Description = "Press any key to set as your shortcut!", 
				Time = 5 
			})
		end
	end,
})

SettingsGroup:AddLabel("💡 Tip: Works even when the UI is closed!", true)

-- Global Input Listener (Handles both setting the key and triggering it)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if UserInputService:GetFocusedTextBox() then return end

	-- 1. Check if we are waiting for a key to be set
	if isListeningForKey then
		if input.UserInputType == Enum.UserInputType.Keyboard then
			autoFishKey = input.KeyCode
			isListeningForKey = false
			Library:Notify({
				Title = "Shortcut Updated!",
				Description = "Auto Fisher key is now: " .. autoFishKey.Name,
				Time = 3
			})
		end
		return -- Don't trigger the toggle while setting the key
	end

	-- 2. Check if the pressed key matches our saved key
	if input.KeyCode == autoFishKey then
		local currentState = Library.Toggles.AutoFisher.Value
		Library.Toggles.AutoFisher:SetValue(not currentState)
	end
end)

-- ============================================================
-- // PLAYER TAB
-- ============================================================
local PlayerGroup = PlayerTab:AddGroupbox({ Side = "Left", Name = "Movement" })

PlayerGroup:AddSlider("WalkSpeed", {
	Text = "Walkspeed", Default = 16, Min = 16, Max = 200, Rounding = 0,
	Callback = function(Value)
		if player.Character and player.Character:FindFirstChild("Humanoid") then
			player.Character.Humanoid.WalkSpeed = Value
		end
	end,
})

PlayerGroup:AddSlider("JumpPower", {
	Text = "Jump Power", Default = 50, Min = 50, Max = 200, Rounding = 0,
	Callback = function(Value)
		if player.Character and player.Character:FindFirstChild("Humanoid") then
			player.Character.Humanoid.UseJumpPower = true
			player.Character.Humanoid.JumpPower = Value
		end
	end,
})

PlayerGroup:AddDivider()

local flyThread = nil
local flyBody = nil

PlayerGroup:AddSlider("FlySpeed", {
	Text = "Fly Speed", Default = 50, Min = 10, Max = 300, Rounding = 0,
	Tooltip = "How fast you fly when Fly is enabled.",
})

PlayerGroup:AddToggle("Fly", {
	Text = "Enable Fly",
	Tooltip = "WASD to move, Space up, LeftCtrl down. Follows your camera!",
	Default = false,
	Risky = true,
	Callback = function(Value)
		local char = player.Character
		local hum = char and char:FindFirstChild("Humanoid")
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not (hrp and hum) then
			Library:Notify({ Title = "Error", Description = "Character not found!", Time = 3 })
			Library.Toggles.Fly:SetValue(false)
			return
		end

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
				while Library.Toggles.Fly.Value and flyBody and flyBody.Parent do
					local move = Vector3.new(0, 0, 0)
					if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + camera.CFrame.LookVector end
					if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - camera.CFrame.LookVector end
					if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - camera.CFrame.RightVector end
					if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + camera.CFrame.RightVector end
					if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0, 1, 0) end
					if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move = move - Vector3.new(0, 1, 0) end

					if move.Magnitude > 0 then move = move.Unit end
					flyBody.Velocity = move * Library.Options.FlySpeed.Value
					task.wait()
				end

				if flyBody then flyBody:Destroy() flyBody = nil end
				if hum and hum.Parent then
					hum.WalkSpeed = Library.Options.WalkSpeed.Value
					hum.JumpPower = Library.Options.JumpPower.Value
				end
			end)
			Library:Notify({ Title = "Fly On", Description = "WASD + Space/Ctrl to move!", Time = 3 })
		else
			if flyThread then task.cancel(flyThread) flyThread = nil end
			if flyBody then flyBody:Destroy() flyBody = nil end
			if hum then
				hum.WalkSpeed = Library.Options.WalkSpeed.Value
				hum.JumpPower = Library.Options.JumpPower.Value
			end
			Library:Notify({ Title = "Fly Off", Description = "Movement restored.", Time = 2 })
		end
	end,
})

PlayerGroup:AddDivider()

PlayerGroup:AddToggle("Teleport", {
	Text = "Enable Teleport (Ctrl + Click)",
	Tooltip = "Hold Left Ctrl and click anywhere to teleport there.",
	Default = false,
	Risky = false,
	Callback = function(Value)
		Library:Notify({
			Title = Value and "Teleport On" or "Teleport Off",
			Description = Value and "Hold CTRL and click to teleport!" or "Teleport disabled.",
			Time = 2
		})
	end,
})

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if Library.Toggles.Teleport.Value and input.UserInputType == Enum.UserInputType.MouseButton1 then
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) then
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp then
				local targetPos = mouse.Hit.Position + Vector3.new(0, 4, 0)
				hrp.CFrame = CFrame.new(targetPos)
				Library:Notify({ Title = "Teleported", Description = "Moved to cursor location!", Time = 1.5 })
			end
		end
	end
end)

player.CharacterAdded:Connect(function(char)
	task.wait(1)
	local hum = char:FindFirstChild("Humanoid")
	if hum then
		hum.WalkSpeed = Library.Options.WalkSpeed.Value
		hum.JumpPower = Library.Options.JumpPower.Value
		hum.UseJumpPower = true
	end
	if Library.Toggles.Fly.Value then
		Library.Toggles.Fly:SetValue(false)
		task.wait(0.1)
		Library.Toggles.Fly:SetValue(true)
	end
end)

-- ============================================================
-- // SETTINGS TAB
-- ============================================================
local ThemeGroup = SettingsTab:AddGroupbox({ Side = "Left", Name = "Appearance" })

ThemeGroup:AddDropdown("ThemeSelect", {
	Values = {"Default (Gray)", "Red", "Blue", "Green", "Purple", "Pink", "Orange"},
	Default = "Default (Gray)",
	Multi = false,
	Text = "UI Theme Color",
	Tooltip = "Changes the accent color of the UI.",
	Callback = function(Value)
		local colors = {
			["Default (Gray)"] = Color3.fromRGB(99, 99, 99),
			["Red"] = Color3.fromRGB(255, 50, 50),
			["Blue"] = Color3.fromRGB(50, 150, 255),
			["Green"] = Color3.fromRGB(50, 255, 100),
			["Purple"] = Color3.fromRGB(150, 50, 255),
			["Pink"] = Color3.fromRGB(255, 105, 180),
			["Orange"] = Color3.fromRGB(255, 165, 0),
		}
		local color = colors[Value]
		local applied = false

		pcall(function() if Library.SetAccent then Library:SetAccent(color) applied = true end end)
		pcall(function() if Window.SetAccent then Window:SetAccent(color) applied = true end end)
		pcall(function() if Window.SetColor then Window:SetColor(color) applied = true end end)
		pcall(function() if Library.Color then Library.Color = color applied = true end end)

		if applied then
			Library:Notify({ Title = "Theme Changed", Description = "Applied " .. Value .. "!", Time = 2 })
		else
			Library:Notify({ Title = "Theme", Description = "This Obsidian version has no theme API.", Time = 3 })
		end
	end,
})

Library:Notify({ Title = "Rod And Reef Beta Loaded", Description = "Custom Keybind system ready!", Time = 4 })
