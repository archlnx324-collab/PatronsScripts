-- // Services & setup
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")

local plr = Players.LocalPlayer
repeat task.wait() until game:IsLoaded() and plr.PlayerGui:FindFirstChild("Main")
plr:WaitForChild("Data")

local CommF_ = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_")
local Net = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net")
local RegisterAttack = Net:WaitForChild("RE/RegisterAttack")
local RegisterHit = Net:WaitForChild("RE/RegisterHit")

local Quests = require(ReplicatedStorage:WaitForChild("Quests"))
local okGuide, GuideModule = pcall(function()
	return require(ReplicatedStorage:WaitForChild("GuideModule"))
end)
if not okGuide then GuideModule = nil end

local World1 = game.PlaceId == 2753915549 or game.PlaceId == 85211729168715
local World2 = game.PlaceId == 4442272183 or game.PlaceId == 79091703265657
local World3 = game.PlaceId == 7449423635 or game.PlaceId == 100117331123089

-- // Config (everything the toggles/sliders control)
local Config = {
	FarmLevel = false,
	FarmNearest = false,
	BringMobs = true,
	FastAttack = true,
	AutoBuso = true,
	WeaponType = "Melee",
	SelectWeapon = nil,
	TweenSpeed = 150,
	FarmHeight = 10,
	Sec = 0.1,
}
local submergedDone = false

-- Anti AFK (from the script, always on)
plr.Idled:Connect(function()
	VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
	task.wait(1)
	VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
end)

-- // Basic helpers (ports of t9.Alive / EquipWeapon / weaponSc)
local function GetRoot()
	local char = plr.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function Alive(model)
	if not model then return false end
	local hum = model:FindFirstChildOfClass("Humanoid")
	return hum and hum.Health > 0
end

local function EquipWeapon(name)
	if not name then return end
	local tool = plr.Backpack:FindFirstChild(name)
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if tool and hum then
		hum:EquipTool(tool)
	end
end

-- weapon picker loop (Select Weapon dropdown in the original)
task.spawn(function()
	while task.wait(0.5) do
		pcall(function()
			for _, tool in pairs(plr.Backpack:GetChildren()) do
				if tool:IsA("Tool") and tool.ToolTip == Config.WeaponType then
					Config.SelectWeapon = tool.Name
				end
			end
		end)
	end
end)

-- // Movement system (port of the Rip_Indra part + _tp + BodyClip watcher)
local FarmPart = Instance.new("Part")
FarmPart.Name = "FarmAnchor"
FarmPart.Size = Vector3.new(1, 1, 1)
FarmPart.Anchored = true
FarmPart.CanCollide = false
FarmPart.CanTouch = false
FarmPart.Transparency = 1
FarmPart.Parent = workspace

local currentTween = nil

local function isFarming()
	return Config.FarmLevel or Config.FarmNearest
end

-- keeps your character glued to the tweened part (this is what bypasses movement checks)
task.spawn(function()
	while task.wait() do
		pcall(function()
			local char = plr.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if not root then return end
			if isFarming() then
				if (root.Position - FarmPart.Position).Magnitude <= 200 then
					root.CFrame = FarmPart.CFrame
				else
					FarmPart.CFrame = root.CFrame
				end
				if not root:FindFirstChild("BodyClip") then
					local bv = Instance.new("BodyVelocity")
					bv.Name = "BodyClip"
					bv.MaxForce = Vector3.new(100000, 100000, 100000)
					bv.Velocity = Vector3.zero
					bv.Parent = root
				end
				for _, p in ipairs(char:GetDescendants()) do
					if p:IsA("BasePart") then p.CanCollide = false end
				end
			else
				local bc = root:FindFirstChild("BodyClip")
				if bc then bc:Destroy() end
				if currentTween and currentTween.PlaybackState == Enum.PlaybackState.Playing then
					currentTween:Cancel()
				end
			end
		end)
	end
end)

local function _tp(cf)
	local root = GetRoot()
	if not root then return end
	if typeof(cf) == "Vector3" then cf = CFrame.new(cf) end
	if (FarmPart.Position - root.Position).Magnitude > 200 then
		FarmPart.CFrame = root.CFrame
	end
	if currentTween then pcall(function() currentTween:Cancel() end) end
	local dist = (cf.Position - FarmPart.Position).Magnitude
	local speed = dist <= 15 and 180 or Config.TweenSpeed
	currentTween = TweenService:Create(FarmPart, TweenInfo.new(dist / speed, Enum.EasingStyle.Linear), {
		CFrame = CFrame.new(cf.Position)
	})
	currentTween:Play()
	return currentTween
end

-- // BringEnemy (port — pulls same-name mobs to your target)
local function OwnsPart(part)
	if isnetworkowner then return isnetworkowner(part) end
	return part.ReceiveAge == 0
end

local function BringEnemy(target)
	if not Config.BringMobs or not target then return end
	pcall(function()
		if sethiddenproperty then
			sethiddenproperty(plr, "SimulationRadius", math.huge)
		end
		local pos = target.HumanoidRootPart.Position
		for _, e in ipairs(workspace.Enemies:GetChildren()) do
			if e ~= target and e.Name == target.Name then
				local hum = e:FindFirstChildOfClass("Humanoid")
				local hrp = e:FindFirstChild("HumanoidRootPart")
				if hum and hrp and hum.Health > 0 and (hrp.Position - pos).Magnitude <= 3000 then
					if not hrp:FindFirstChild("BodyVelocity") then
						local bv = Instance.new("BodyVelocity")
						bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
						bv.Velocity = Vector3.zero
						bv.Parent = hrp
					end
					if OwnsPart(hrp) then
						hrp.CFrame = CFrame.new(pos)
					end
					hrp.CanCollide = false
					hum.WalkSpeed = 0
					hum.JumpPower = 0
				end
			end
		end
		target.HumanoidRootPart.CanCollide = false
		target.Humanoid.WalkSpeed = 0
		target.Humanoid.JumpPower = 0
	end)
end

-- // Kill (port of t9.Kill — positions you above the mob; damage comes from Fast Attack)
local function Kill(enemy)
	if not Alive(enemy) then return end
	local hrp = enemy:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	BringEnemy(enemy)
	EquipWeapon(Config.SelectWeapon)
	local tool = plr.Character and plr.Character:FindFirstChildOfClass("Tool")
	local tip = tool and tool.ToolTip or ""
	local height = tip == "Blox Fruit" and 30 or Config.FarmHeight
	_tp(hrp.CFrame * CFrame.new(0, height, 0))
end

-- // Fast Attack (port of the RegisterAttack/RegisterHit loop at the bottom of the script)
task.spawn(function()
	while task.wait(Config.Sec) do
		if Config.FastAttack then
			pcall(function()
				local char = plr.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				if not root or not char:FindFirstChildOfClass("Tool") then return end
				local hits, firstHead = {}, nil
				for _, e in ipairs(workspace.Enemies:GetChildren()) do
					local hum = e:FindFirstChildOfClass("Humanoid")
					local hrp = e:FindFirstChild("HumanoidRootPart")
					if hum and hrp and hum.Health > 0 and (hrp.Position - root.Position).Magnitude <= 60 then
						firstHead = firstHead or e:FindFirstChild("Head")
						for _, part in ipairs(e:GetChildren()) do
							if part:IsA("BasePart") then
								table.insert(hits, {e, part})
							end
						end
					end
				end
				if #hits > 0 and firstHead then
					RegisterAttack:FireServer(2e-09)
					RegisterHit:FireServer(firstHead, hits, {})
				end
			end)
		end
	end
end)

-- // Auto Buso (from Settings tab of the original)
task.spawn(function()
	while task.wait(0.5) do
		if Config.AutoBuso then
			pcall(function()
				if plr.Character and not plr.Character:FindFirstChild("HasBuso") then
					CommF_:InvokeServer("Buso")
				end
			end)
		end
	end
end)

-- // Quest system (ports of GetQuests / GetQuestPoint / CheckQuestVisible / StartQuest retry)
local EXCLUDED_QUESTS = {"MarineQuest", "BartiloQuest", "CitizenQuest", "Trainees"}

local function CheckSea(n)
	return (World1 and n == 1) or (World2 and n == 2) or (World3 and n == 3)
end

local function GetQuests()
	local level = plr.Data.Level.Value
	local best, result = 0, {}
	if level >= 700 and CheckSea(1) then
		result = {Mob = "Galley Captain", NameQuest = "FountainQuest", ID = 2}
	elseif level >= 1500 and CheckSea(2) then
		result = {Mob = "Water Fighter", NameQuest = "ForgottenQuest", ID = 2}
	else
		for questName, quest in pairs(Quests) do
			for id, data in pairs(quest) do
				local lvl = data.LevelReq
				for mobName, count in pairs(data.Task) do
					if lvl <= level and best <= lvl and count > 1 and not table.find(EXCLUDED_QUESTS, questName) then
						best = lvl
						result = {Mob = mobName, NameQuest = questName, ID = id}
					end
				end
			end
		end
	end
	return result
end

local function GetQuestPoint()
	if not (GuideModule and GuideModule.Data and GuideModule.Data.LastClosestNPC) then return nil end
	local name = GuideModule.Data.LastClosestNPC
	for _, folder in ipairs({workspace:FindFirstChild("NPCs"), ReplicatedStorage:FindFirstChild("NPCs")}) do
		if folder then
			for _, npc in pairs(folder:GetChildren()) do
				if npc.Name == name and npc:FindFirstChild("HumanoidRootPart") then
					return npc.HumanoidRootPart.CFrame
				end
			end
		end
	end
	return nil
end

local function GetQuestTitle()
	local gui = plr.PlayerGui
	local main = gui:FindFirstChild("Main")
	local quest = main and main:FindFirstChild("Quest")
	if quest and quest.Visible then
		local ok, text = pcall(function() return quest.Container.QuestTitle.Title.Text end)
		return true, ok and text or ""
	end
	local tracked = gui:FindFirstChild("TrackedQuestFrame")
	if tracked and tracked.Enabled then
		local ok, text = pcall(function() return tracked.Frame.header.textLabel.Text end)
		if ok and text ~= "" then return true, text end
		local ok2, text2 = pcall(function() return tracked.Frame.header.textLabel.textLabel.Text end)
		return true, ok2 and text2 or ""
	end
	return false, ""
end

local function HasQuestFor(mobName)
	local visible, title = GetQuestTitle()
	if not visible or title == "" then return false end
	return string.find(string.lower(title), string.lower(mobName), 1, true) ~= nil
end

local function StartQuest(name, id, mobName)
	if HasQuestFor(mobName) then return true end
	pcall(function() CommF_:InvokeServer("StartQuest", name, id) end)
	local deadline = os.clock() + 3
	repeat
		if HasQuestFor(mobName) then return true end
		task.wait(0.25)
	until os.clock() >= deadline
	return HasQuestFor(mobName)
end

-- // Main auto farm loop (port of the Auto Farm Level loop)
task.spawn(function()
	while task.wait(Config.Sec) do
		if Config.FarmLevel then
			pcall(function()
				local root = GetRoot()
				if not root then return end
				local level = plr.Data.Level.Value

				-- Sea 3, level 2600+: travel to Submerged Island once
				if World3 and level >= 2600 and not submergedDone then
					local flat = Vector3.new(root.Position.X, 0, root.Position.Z)
					local nearSub = root.Position.Y < -1000 or (flat - Vector3.new(10533.28, 0, 9940.48)).Magnitude < 4500
					if not nearSub then
						local dock = CFrame.new(-16269.7041, 25.2288494, 1373.65955)
						_tp(dock)
						local t0 = os.clock()
						repeat task.wait(0.1)
						until (root.Position - dock.Position).Magnitude <= 8 or os.clock() - t0 > 20 or not Config.FarmLevel
						pcall(function()
							Net:FindFirstChild("RF/SubmarineWorkerSpeak"):InvokeServer("TravelToSubmergedIsland")
						end)
						task.wait(2)
					end
					submergedDone = true
				end

				local quest = GetQuests()
				if not quest.Mob then task.wait(1) return end

				-- wrong quest? abandon it
				local visible = GetQuestTitle()
				if visible and not HasQuestFor(quest.Mob) then
					CommF_:InvokeServer("AbandonQuest")
					task.wait(0.2)
					return
				end

				-- no quest? walk to quest NPC and accept it
				if not HasQuestFor(quest.Mob) then
					local npcCF = GetQuestPoint()
					if npcCF then
						_tp(npcCF)
						local t0 = os.clock()
						repeat task.wait(0.1)
						until (root.Position - npcCF.Position).Magnitude <= 10 or os.clock() - t0 > 15 or not Config.FarmLevel
					end
					StartQuest(quest.NameQuest, quest.ID, quest.Mob)
					return
				end

				-- 1) mob alive in workspace.Enemies -> farm it
				local target
				for _, e in ipairs(workspace.Enemies:GetChildren()) do
					if string.find(e.Name, quest.Mob) and Alive(e) then
						target = e
						break
					end
				end
				if target then
					repeat
						task.wait(Config.Sec)
						Kill(target)
					until not Config.FarmLevel or not target.Parent or not Alive(target) or not (GetQuestTitle())
					return
				end

				-- 2) mob in ReplicatedStorage cache -> tween to it
				for _, e in ipairs(ReplicatedStorage:GetChildren()) do
					if e:IsA("Model") and string.find(e.Name, quest.Mob) and Alive(e) and e:FindFirstChild("HumanoidRootPart") then
						_tp(e.HumanoidRootPart.CFrame * CFrame.new(0, 20, 0))
						return
					end
				end

				-- 3) nothing spawned -> sit on its spawn point
				local origin = workspace:FindFirstChild("_WorldOrigin")
				local spawns = origin and origin:FindFirstChild("EnemySpawns")
				if spawns then
					for _, s in ipairs(spawns:GetChildren()) do
						if string.find(s.Name, quest.Mob) then
							_tp(s.CFrame * CFrame.new(0, 20, 0))
							break
						end
					end
				end
			end)
		end
	end
end)

-- // Auto Farm Nearest (port of ClosetMons)
task.spawn(function()
	while task.wait(Config.Sec) do
		if Config.FarmNearest and not Config.FarmLevel then
			pcall(function()
				local root = GetRoot()
				if not root then return end
				local best, bestDist = nil, math.huge
				for _, e in ipairs(workspace.Enemies:GetChildren()) do
					local hrp = e:FindFirstChild("HumanoidRootPart")
					if Alive(e) and hrp then
						local d = (hrp.Position - root.Position).Magnitude
						if d < bestDist then best, bestDist = e, d end
					end
				end
				if best then
					repeat
						task.wait(Config.Sec)
						Kill(best)
					until not Config.FarmNearest or not best.Parent or not Alive(best)
				end
			end)
		end
	end
end)

-- // YOUR UI
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/archlnx324-collab/PatronsScripts/refs/heads/main/library.lua"))()

local Window = Library:CreateWindow({
	Name = "Quest Farm",
	Size = UDim2.fromOffset(710, 470),
	Theme = "Monochrome",
	ToggleKey = Enum.KeyCode.RightShift
})

local Tab = Window:CreateTab({ Name = "Farming", Icon = "farm" })

local FarmGroup = Tab:AddGroup("Left", "Auto Farm")
FarmGroup:AddToggle({
	Text = "Auto Farm Level + Quest",
	Desc = "Picks quest by level, accepts it, farms the mobs",
	Default = false,
	Callback = function(state)
		Config.FarmLevel = state
		if not state then submergedDone = false end
	end
})
FarmGroup:AddToggle({
	Text = "Auto Farm Nearest",
	Desc = "Kills closest enemies (no quest)",
	Default = false,
	Callback = function(state) Config.FarmNearest = state end
})
FarmGroup:AddToggle({
	Text = "Bring Mobs",
	Desc = "Pulls same-name mobs to your target",
	Default = true,
	Callback = function(state) Config.BringMobs = state end
})
FarmGroup:AddToggle({
	Text = "Fast Attack",
	Desc = "RegisterAttack + RegisterHit spam (needed to deal damage)",
	Default = true,
	Callback = function(state) Config.FastAttack = state end
})

local WeaponGroup = Tab:AddGroup("Left", "Weapon")
WeaponGroup:AddDropdown({
	Text = "Select Weapon",
	Options = {"Melee", "Sword", "Blox Fruit", "Gun"},
	Default = "Melee",
	Callback = function(selected) Config.WeaponType = selected end
})
WeaponGroup:AddToggle({
	Text = "Auto Buso Haki",
	Default = true,
	Callback = function(state) Config.AutoBuso = state end
})

local SettingsGroup = Tab:AddGroup("Right", "Settings")
SettingsGroup:AddSlider({
	Text = "Tween Speed",
	Suffix = "",
	Min = 50, Max = 350, Step = 5, Decimals = 0, Default = 150,
	Callback = function(value) Config.TweenSpeed = value end
})
SettingsGroup:AddSlider({
	Text = "Farm Height",
	Suffix = " studs",
	Min = 0, Max = 40, Step = 1, Decimals = 0, Default = 10,
	Callback = function(value) Config.FarmHeight = value end
})
SettingsGroup:AddButton({
	Text = "Abandon Quest",
	Callback = function()
		pcall(function() CommF_:InvokeServer("AbandonQuest") end)
	end
})


-- // ================= TELEPORT TAB (TWEEN VERSION) =================
do
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local TweenService = game:GetService("TweenService")

	local plr = Players.LocalPlayer
	local CommF_ = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_")

	local World1 = game.PlaceId == 2753915549 or game.PlaceId == 85211729168715
	local World2 = game.PlaceId == 4442272183 or game.PlaceId == 79091703265657

	local TpTab = Window:CreateTab({ Name = "Teleport", Icon = "teleport" }) -- swap icon if unsupported

	-- ===== Tween engine (anchor part + character follow, like the farm's system) =====
	local Anchor = Instance.new("Part")
	Anchor.Name = "TeleportAnchor"
	Anchor.Size = Vector3.new(1, 1, 1)
	Anchor.Anchored = true
	Anchor.CanCollide = false
	Anchor.CanTouch = false
	Anchor.Transparency = 1
	Anchor.Parent = workspace

	local currentTween = nil
	local flying = false
	local tweenSpeed = 150
	local instantMode = false

	local function getRoot()
		local char = plr.Character
		return char and char:FindFirstChild("HumanoidRootPart")
	end

	local function stopTween()
		flying = false
		if currentTween then
			pcall(function() currentTween:Cancel() end)
			currentTween = nil
		end
		pcall(function()
			local root = getRoot()
			if not root then return end
			local bv = root:FindFirstChild("TpBodyVelocity")
			if bv then bv:Destroy() end
			for _, p in ipairs(plr.Character:GetDescendants()) do
				if p:IsA("BasePart") then p.CanCollide = true end
			end
		end)
	end

	local function tweenTo(cf)
		local root = getRoot()
		if not root then return end
		if typeof(cf) == "Vector3" then cf = CFrame.new(cf) end
		stopTween()
		Anchor.CFrame = root.CFrame
		flying = true
		local dist = (cf.Position - root.Position).Magnitude
		local speed = dist <= 15 and 180 or tweenSpeed
		currentTween = TweenService:Create(Anchor, TweenInfo.new(dist / speed, Enum.EasingStyle.Linear), {
			CFrame = CFrame.new(cf.Position)
		})
		currentTween.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed then
				pcall(function()
					local r = getRoot()
					if r then r.CFrame = cf end
				end)
				stopTween()
			end
		end)
		currentTween:Play()
	end

	local function go(cf)
		if typeof(cf) == "Vector3" then cf = CFrame.new(cf) end
		if instantMode then
			stopTween()
			local root = getRoot()
			if root then
				root.CFrame = cf
				root.AssemblyLinearVelocity = Vector3.zero
			end
		else
			tweenTo(cf)
		end
	end

	-- keeps your character glued to the flying anchor (noclip + no falling)
	task.spawn(function()
		while task.wait() do
			pcall(function()
				local root = getRoot()
				if not root then return end
				if flying then
					if (root.Position - Anchor.Position).Magnitude <= 200 then
						root.CFrame = Anchor.CFrame
					else
						Anchor.CFrame = root.CFrame
					end
					if not root:FindFirstChild("TpBodyVelocity") then
						local bv = Instance.new("BodyVelocity")
						bv.Name = "TpBodyVelocity"
						bv.MaxForce = Vector3.new(100000, 100000, 100000)
						bv.Velocity = Vector3.zero
						bv.Parent = root
					end
					for _, p in ipairs(plr.Character:GetDescendants()) do
						if p:IsA("BasePart") then p.CanCollide = false end
					end
				else
					local bv = root:FindFirstChild("TpBodyVelocity")
					if bv then bv:Destroy() end
				end
			end)
		end
	end)

	plr.CharacterRemoving:Connect(stopTween)

	-- ===== Travel - Worlds =====
	local WorldsGroup = TpTab:AddGroup("Left", "Travel - Worlds")

	WorldsGroup:AddButton({
		Text = "Travel East Blue (Sea 1)",
		Danger = true,
		Callback = function()
			pcall(function() CommF_:InvokeServer("TravelMain") end)
		end
	})

	WorldsGroup:AddButton({
		Text = "Travel Dressrosa (Sea 2)",
		Danger = true,
		Callback = function()
			pcall(function() CommF_:InvokeServer("TravelDressrosa") end)
		end
	})

	WorldsGroup:AddButton({
		Text = "Travel Zou (Sea 3)",
		Danger = true,
		Callback = function()
			pcall(function() CommF_:InvokeServer("TravelZou") end)
		end
	})

	-- ===== Travel - Islands =====
	local IslandsGroup = TpTab:AddGroup("Left", "Travel - Islands")

	local islandNames = {}
	local origin = workspace:FindFirstChild("_WorldOrigin")
	local locations = origin and origin:FindFirstChild("Locations")
	if locations then
		for _, loc in ipairs(locations:GetChildren()) do
			if loc.Name ~= "Sea" then
				table.insert(islandNames, loc.Name)
			end
		end
	end
	if #islandNames == 0 then islandNames = {"None"} end

	local selIsland = islandNames[1]
	IslandsGroup:AddDropdown({
		Text = "Select Island",
		Options = islandNames,
		Default = islandNames[1],
		Callback = function(selected) selIsland = selected end
	})

	IslandsGroup:AddButton({
		Text = "Tween to Island",
		Primary = true,
		Callback = function()
			if not locations then return end
			local loc = locations:FindFirstChild(selIsland)
			if loc then
				go(loc.CFrame * CFrame.new(0, 30, 0))
			end
		end
	})

	-- ===== Travel - Portals (server-side, always instant) =====
	local PortalsGroup = TpTab:AddGroup("Right", "Travel - Portals")

	local portals
	if World1 then
		portals = {
			{"Sky Island", Vector3.new(-7894, 5547, -380)},
			{"Sky Island Exit", Vector3.new(-4607, 874, -1667)},
			{"Underwater City", Vector3.new(61163, 11, 1819)},
			{"Underwater Exit", Vector3.new(4050, -1, -1814)},
			{"Pirate Village", Vector3.new(-1242.4625, 4.787, 3901.283)},
		}
	elseif World2 then
		portals = {
			{"Swan Mansion", Vector3.new(-390, 332, 673)},
			{"Swan Room", Vector3.new(2285, 15, 905)},
			{"Cursed Ship", Vector3.new(923, 126, 32852)},
			{"Zombie Island", Vector3.new(-6509, 83, -133)},
		}
	else
		portals = {
			{"Hydra Island", Vector3.new(5657.886, 1013.079, -335.500)},
			{"Mansion", Vector3.new(-12462, 375, -7552)},
			{"Castle on the Sea", Vector3.new(-5036, 315, -3179)},
			{"Temple of Time", Vector3.new(28286, 14897, 103)},
			{"Great Tree", Vector3.new(3024.1709, 2280.69434, -7325.12793)},
		}
	end

	local portalNames = {}
	for _, p in ipairs(portals) do table.insert(portalNames, p[1]) end

	local selPortal = portalNames[1]
	PortalsGroup:AddDropdown({
		Text = "Select Portal",
		Options = portalNames,
		Default = portalNames[1],
		Callback = function(selected) selPortal = selected end
	})

	PortalsGroup:AddButton({
		Text = "Use Portal",
		Primary = true,
		Callback = function()
			for _, p in ipairs(portals) do
				if p[1] == selPortal then
					pcall(function() CommF_:InvokeServer("requestEntrance", p[2]) end)
					break
				end
			end
		end
	})

	-- ===== Travel - NPCs =====
	local NpcGroup = TpTab:AddGroup("Right", "Travel - NPCs")

	local npcNames = {}
	local rsNPCs = ReplicatedStorage:FindFirstChild("NPCs")
	if rsNPCs then
		for _, npc in ipairs(rsNPCs:GetChildren()) do
			table.insert(npcNames, npc.Name)
		end
	end
	if #npcNames == 0 then npcNames = {"None"} end

	local selNPC = npcNames[1]
	NpcGroup:AddDropdown({
		Text = "Select NPC",
		Options = npcNames,
		Default = npcNames[1],
		Callback = function(selected) selNPC = selected end
	})

	NpcGroup:AddButton({
		Text = "Tween to NPC",
		Primary = true,
		Callback = function()
			for _, folder in ipairs({workspace:FindFirstChild("NPCs"), rsNPCs}) do
				if folder then
					local npc = folder:FindFirstChild(selNPC)
					if npc and npc:FindFirstChild("HumanoidRootPart") then
						go(npc.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3))
						return
					end
				end
			end
		end
	})

	-- ===== Settings =====
	local SettingsGroup = TpTab:AddGroup("Right", "Teleport Settings")

	SettingsGroup:AddSlider({
		Text = "Tween Speed",
		Suffix = "",
		Min = 50, Max = 350, Step = 5, Decimals = 0, Default = 150,
		Callback = function(value) tweenSpeed = value end
	})

	SettingsGroup:AddToggle({
		Text = "Instant Mode",
		Desc = "Skip tweening and teleport instantly",
		Default = false,
		Callback = function(state) instantMode = state end
	})

	SettingsGroup:AddButton({
		Text = "Stop Tween",
		Danger = true,
		Callback = function() stopTween() end
	})
end

-- // ================= MISC TAB =================
do
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local TeleportService = game:GetService("TeleportService")
	local HttpService = game:GetService("HttpService")
	local Lighting = game:GetService("Lighting")
	local StarterGui = game:GetService("StarterGui")
	local TweenService = game:GetService("TweenService")

	local plr = Players.LocalPlayer
	local CommF_ = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_")

	local MiscTab = Window:CreateTab({ Name = "Misc", Icon = "misc" }) -- change icon if your library doesn't have "misc"

	local function getServers()
		local ok, data = pcall(function()
			return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
		end)
		if ok and data and data.data then return data.data end
		return {}
	end

	-- ===== Server - Function =====
	local ServerGroup = MiscTab:AddGroup("Left", "Server")

	ServerGroup:AddButton({
		Text = "Redeem All Codes",
		Primary = true,
		Callback = function()
			task.spawn(function()
				local codes = {
					"LIGHTNINGABUSE", "1LOSTADMIN", "ADMINFIGHT", "GIFTING_HOURS", "NOMOREHACK",
					"BANEXPLOIT", "WildDares", "BossBuild", "GetPranked", "EARN_FRUITS",
					"SUB2GAMERROBOT_RESET1", "KITT_RESET", "Bignews", "CHANDLER", "Fudd10",
					"fudd10_v2", "Sub2UncleKizaru", "FIGHT4FRUIT", "kittgaming", "TRIPLEABUSE",
					"Sub2CaptainMaui", "Sub2Fer999", "Enyu_is_Pro", "Magicbus", "JCWK",
					"Starcodeheo", "Bluxxy", "SUB2GAMERROBOT_EXP1", "Sub2NoobMaster123",
					"Sub2Daigrock", "Axiore", "TantaiGaming", "StrawHatMaine", "Sub2OfficialNoobie",
					"TheGreatAce", "JULYUPDATE_RESET", "ADMINHACKED", "SEATROLLING", "24NOADMIN",
					"ADMIN_TROLL", "NEWTROLL", "SECRET_ADMIN", "staffbattle", "NOEXPLOIT",
					"NOOB2ADMIN", "CODESLIDE", "fruitconcepts", "krazydares"
				}
				local Redeem = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("Redeem")
				if not Redeem then return end
				for _, code in ipairs(codes) do
					pcall(function()
						if Redeem:IsA("RemoteFunction") then
							Redeem:InvokeServer(code)
						else
							Redeem:FireServer(code)
						end
					end)
					task.wait(0.1)
				end
			end)
		end
	})

	ServerGroup:AddButton({
		Text = "Rejoin Server",
		Danger = true,
		Callback = function()
			TeleportService:Teleport(game.PlaceId, plr)
		end
	})

	ServerGroup:AddButton({
		Text = "Hop Server",
		Danger = true,
		Callback = function()
			for _, s in ipairs(getServers()) do
				if s.playing < s.maxPlayers and s.id ~= game.JobId then
					TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, plr)
					return
				end
			end
		end
	})

	ServerGroup:AddButton({
		Text = "Hop to Lowest Players",
		Danger = true,
		Callback = function()
			local best
			for _, s in ipairs(getServers()) do
				if s.id ~= game.JobId and s.playing < s.maxPlayers then
					if not best or s.playing < best.playing then best = s end
				end
			end
			if best then TeleportService:TeleportToPlaceInstance(game.PlaceId, best.id, plr) end
		end
	})

	ServerGroup:AddButton({
		Text = "Hop to Lowest Ping",
		Danger = true,
		Callback = function()
			local best
			for _, s in ipairs(getServers()) do
				if s.id ~= game.JobId and s.playing < s.maxPlayers then
					if not best or s.ping < best.ping then best = s end
				end
			end
			if best then TeleportService:TeleportToPlaceInstance(game.PlaceId, best.id, plr) end
		end
	})

	ServerGroup:AddButton({
		Text = "Copy Job ID",
		Callback = function()
			if setclipboard then setclipboard(tostring(game.JobId)) end
		end
	})

	-- your library has no text input, so this reads the Job ID from your clipboard
	ServerGroup:AddButton({
		Text = "Join Job ID (Clipboard)",
		Callback = function()
			if not getclipboard then return end
			local id = getclipboard()
			if id and id ~= "" then
				pcall(function()
					TeleportService:TeleportToPlaceInstance(game.PlaceId, id, plr)
				end)
			end
		end
	})

	-- ===== Player Gui / Others =====
	local GuiGroup = MiscTab:AddGroup("Left", "Player / GUI")

	GuiGroup:AddButton({
		Text = "Open Awakenings Expert",
		Callback = function()
			pcall(function() plr.PlayerGui.Main.AwakeningToggler.Visible = true end)
		end
	})

	GuiGroup:AddButton({
		Text = "Open Title Selection",
		Callback = function()
			pcall(function()
				CommF_:InvokeServer("getTitles", true)
				plr.PlayerGui.Main.Titles.Visible = true
			end)
		end
	})

	GuiGroup:AddToggle({
		Text = "Disable Chat GUI",
		Default = false,
		Callback = function(state)
			pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, not state) end)
		end
	})

	GuiGroup:AddToggle({
		Text = "Disable Leaderboard GUI",
		Default = false,
		Callback = function(state)
			pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, not state) end)
		end
	})

	GuiGroup:AddButton({
		Text = "Set Pirate Team",
		Callback = function()
			pcall(function() CommF_:InvokeServer("SetTeam", "Pirates") end)
		end
	})

	GuiGroup:AddButton({
		Text = "Set Marine Team",
		Callback = function()
			pcall(function() CommF_:InvokeServer("SetTeam", "Marines") end)
		end
	})

	-- fixed version: original referenced undefined position vars, rebuilt with the portal coords from the script
	local portalsOn = false
	local PORTALS = {
		Vector3.new(-12471.169921875, 374.94024658203, -7551.677734375), -- Mansion
		Vector3.new(-5072.08984375, 314.5412902832, -3151.1098632812),   -- Castle
		Vector3.new(5748.7587890625, 610.44982910156, -267.81704711914), -- Hydra
	}
	GuiGroup:AddToggle({
		Text = "Unlock All Portals",
		Desc = "Auto requestEntrance when standing near a portal",
		Default = false,
		Callback = function(state) portalsOn = state end
	})
	task.spawn(function()
		while task.wait(0.2) do
			if portalsOn then
				pcall(function()
					local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
					if not root then return end
					for _, pos in ipairs(PORTALS) do
						if (root.Position - pos).Magnitude <= 10 then
							CommF_:InvokeServer("requestEntrance", pos)
							task.wait(1)
						end
					end
				end)
			end
		end
	end)

	-- ===== Graphics / Haki Stats =====
	local GfxGroup = MiscTab:AddGroup("Right", "Graphics / Haki")

	local hakiState = 0
	GfxGroup:AddDropdown({
		Text = "Select Haki State",
		Options = {"State 0", "State 1", "State 2", "State 3", "State 4", "State 5"},
		Default = "State 0",
		Callback = function(selected)
			hakiState = tonumber(selected:match("%d+")) or 0
		end
	})

	GfxGroup:AddButton({
		Text = "Change Buso Stage",
		Callback = function()
			pcall(function() CommF_:InvokeServer("ChangeBusoStage", hakiState) end)
		end
	})

	local rtxOn = false
	local rtxOld = {}
	GfxGroup:AddToggle({
		Text = "RTX Mode",
		Default = false,
		Callback = function(state)
			rtxOn = state
			for _, e in ipairs(Lighting:GetChildren()) do
				if e.Name == "RTXColorCorrection" or e.Name == "RTXTint" then e:Destroy() end
			end
			if state then
				rtxOld = {Ambient = Lighting.Ambient, Brightness = Lighting.Brightness, FogEnd = Lighting.FogEnd}
				local cc = Instance.new("ColorCorrectionEffect")
				cc.Name = "RTXColorCorrection"
				cc.Brightness = 0.176
				cc.Contrast = 0.39
				cc.TintColor = Color3.fromRGB(217, 145, 57)
				cc.Parent = Lighting
				local tint = Instance.new("ColorCorrectionEffect")
				tint.Name = "RTXTint"
				tint.TintColor = Color3.fromRGB(217, 145, 57)
				tint.Parent = Lighting
				Lighting.FogEnd = 999
				task.spawn(function()
					while rtxOn do
						Lighting.Ambient = Color3.fromRGB(33, 33, 33)
						Lighting.Brightness = 0.3
						pcall(function()
							local hrp = plr.Character.HumanoidRootPart
							if not hrp:FindFirstChild("RTXPointLight") then
								local l = Instance.new("PointLight")
								l.Name = "RTXPointLight"
								l.Range = 15
								l.Color = Color3.fromRGB(217, 145, 57)
								l.Parent = hrp
							end
						end)
						task.wait(0.5)
					end
				end)
			else
				if rtxOld.Ambient then Lighting.Ambient = rtxOld.Ambient end
				if rtxOld.Brightness then Lighting.Brightness = rtxOld.Brightness end
				Lighting.FogEnd = rtxOld.FogEnd or 2500
				pcall(function() plr.Character.HumanoidRootPart.RTXPointLight:Destroy() end)
			end
		end
	})

	GfxGroup:AddButton({
		Text = "Fast Mode (Plastic Textures)",
		Callback = function()
			for _, d in ipairs(workspace:GetDescendants()) do
				if d:IsA("BasePart") and not d:IsA("Terrain") then
					pcall(function() d.Material = Enum.Material.Plastic end)
				end
			end
		end
	})

	GfxGroup:AddButton({
		Text = "Low CPU Mode",
		Callback = function()
			pcall(function()
				local t = workspace.Terrain
				t.WaterWaveSize = 0
				t.WaterWaveSpeed = 0
				t.WaterReflectance = 0
				t.WaterTransparency = 0
			end)
			Lighting.GlobalShadows = false
			Lighting.FogEnd = 9e9
			Lighting.Brightness = 0
			pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
			for _, d in ipairs(game:GetDescendants()) do
				pcall(function()
					if d:IsA("ParticleEmitter") or d:IsA("Trail") then
						d.Lifetime = NumberRange.new(0)
					elseif d:IsA("Explosion") then
						d.BlastPressure = 1
						d.BlastRadius = 1
					elseif d:IsA("Fire") or d:IsA("SpotLight") or d:IsA("Smoke") or d:IsA("Sparkles") then
						d.Enabled = false
					elseif d:IsA("Decal") or d:IsA("Texture") then
						d.Transparency = 1
					elseif d:IsA("MeshPart") then
						d.Material = Enum.Material.Plastic
						d.Reflectance = 0
						d.TextureID = ""
					elseif d:IsA("BasePart") and not d:IsA("Terrain") then
						d.Material = Enum.Material.Plastic
						d.Reflectance = 0
					end
				end)
			end
			for _, e in ipairs(Lighting:GetChildren()) do
				if e:IsA("PostEffect") then e.Enabled = false end
			end
		end
	})

	GfxGroup:AddButton({
		Text = "Increase Boat Speed",
		Callback = function()
			pcall(function()
				for _, boat in pairs(workspace.Boats:GetChildren()) do
					if tostring(boat.Owner.Value) == tostring(plr.Name) then
						for _, d in pairs(boat:GetDescendants()) do
							if d:IsA("VehicleSeat") then
								d.MaxSpeed = 350
								d.Torque = 0.2
								d.TurnSpeed = 5
								d.HeadsUpDisplay = true
							end
						end
					end
				end
			end)
		end
	})

	GfxGroup:AddButton({
		Text = "Remove Sky Fog",
		Danger = true,
		Callback = function()
			for _, e in ipairs(Lighting:GetChildren()) do
				if e.Name == "Sky" or e.Name == "LightingLayers" or e.Name == "SeaTerrorCC" or e.Name == "FantasySky" then
					e:Destroy()
				end
			end
		end
	})

	-- ===== Configure - God =====
	local GodGroup = MiscTab:AddGroup("Right", "World / God")

	GodGroup:AddButton({
		Text = "Rain Fruits (Client)",
		Callback = function()
			pcall(function()
				local models = ReplicatedStorage.Assets.Models
				local root = plr.Character.HumanoidRootPart
				for _, m in ipairs(models:GetChildren()) do
					if m:IsA("Model") and m.Name ~= "IceSpikes4" then
						local clone = m:Clone()
						local float = clone:FindFirstChild("Float")
						if float then float:Destroy() end
						clone.Parent = workspace
						clone:PivotTo(CFrame.new(root.Position + Vector3.new(math.random(-50, 50), 100, math.random(-50, 50))))
					end
				end
			end)
		end
	})

	-- fixed: the original Full Bright toggle didn't actually do anything, this one works
	local fbOld = {}
	GodGroup:AddToggle({
		Text = "Full Bright",
		Default = false,
		Callback = function(state)
			if state then
				fbOld = {
					Brightness = Lighting.Brightness,
					ClockTime = Lighting.ClockTime,
					GlobalShadows = Lighting.GlobalShadows,
					FogEnd = Lighting.FogEnd,
					OutdoorAmbient = Lighting.OutdoorAmbient
				}
				Lighting.Brightness = 2
				Lighting.ClockTime = 14
				Lighting.GlobalShadows = false
				Lighting.FogEnd = 1e9
				Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
			else
				for k, v in pairs(fbOld) do Lighting[k] = v end
			end
		end
	})

	local timeChoice = "Day"
	local timeOn = false
	GodGroup:AddDropdown({
		Text = "Select Time",
		Options = {"Day", "Night"},
		Default = "Day",
		Callback = function(selected) timeChoice = selected end
	})
	GodGroup:AddToggle({
		Text = "Lock Time",
		Default = false,
		Callback = function(state) timeOn = state end
	})
	task.spawn(function()
		while task.wait(0.5) do
			if timeOn then
				Lighting.ClockTime = timeChoice == "Day" and 12 or 0
			end
		end
	end)

	local function setWalkWater(on)
		pcall(function()
			workspace.Map["WaterBase-Plane"].Size = on and Vector3.new(1000, 112, 1000) or Vector3.new(1000, 80, 1000)
		end)
	end
	GodGroup:AddToggle({
		Text = "Walk on Water",
		Default = true,
		Callback = function(state) setWalkWater(state) end
	})
	setWalkWater(true) -- apply the default state once

	local iceWalk = false
	GodGroup:AddToggle({
		Text = "Ice Walk",
		Default = false,
		Callback = function(state) iceWalk = state end
	})
	task.spawn(function()
		while task.wait(0.1) do
			if iceWalk then
				pcall(function()
					local char = plr.Character
					if char and char:FindFirstChild("Head") then
						local spike = ReplicatedStorage.Assets.Models.IceSpikes4:Clone()
						spike.Parent = workspace
						spike.Size = Vector3.new(3 + math.random(10, 12), 1.7, 3 + math.random(10, 12))
						spike.Color = Color3.fromRGB(128, 187, 219)
						spike.CFrame = CFrame.new(char.Head.Position.X, -3.8, char.Head.Position.Z) * CFrame.Angles((math.random() - 0.5) * 0.06, math.random() * 7, (math.random() - 0.5) * 0.07)
						local tw = TweenService:Create(spike, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = Vector3.new(0, 0.3, 0)})
						tw.Completed:Connect(function() spike:Destroy() end)
						tw:Play()
					end
				end)
			end
		end
	end)
end

-- // ================= STATS TAB =================
do
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local CollectionService = game:GetService("CollectionService")

	local plr = Players.LocalPlayer
	local CommF_ = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_")

	local StatsTab = Window:CreateTab({ Name = "Stats & Esp", Icon = "stats" }) -- swap icon if unsupported

	-- ===== Stats Upgrade (port of statsSetings + the Auto stat toggles) =====
	local StatsGroup = StatsTab:AddGroup("Left", "Stats Upgrade")

	local pointsPerTick = 10
	local autoStats = {Melee = false, Defense = false, Sword = false, Gun = false, Devil = false}
	-- note: the game's remote name for fruit stats is "Demon Fruit"
	local REMOTE_NAME = {Melee = "Melee", Defense = "Defense", Sword = "Sword", Gun = "Gun", Devil = "Demon Fruit"}

	StatsGroup:AddSlider({
		Text = "Points Per Tick",
		Suffix = " pts",
		Min = 1, Max = 1000, Step = 1, Decimals = 0, Default = 10,
		Callback = function(value) pointsPerTick = value end
	})

	local function addStatToggle(group, text, key, desc)
		group:AddToggle({
			Text = text,
			Desc = desc,
			Default = false,
			Callback = function(state) autoStats[key] = state end
		})
	end

	addStatToggle(StatsGroup, "Auto Melee", "Melee")
	addStatToggle(StatsGroup, "Auto Defense", "Defense")
	addStatToggle(StatsGroup, "Auto Sword", "Sword")
	addStatToggle(StatsGroup, "Auto Gun", "Gun")
	addStatToggle(StatsGroup, "Auto Blox Fruit", "Devil")

	task.spawn(function()
		while task.wait(0.1) do
			for key, on in pairs(autoStats) do
				if on then
					pcall(function()
						if plr.Data.Points.Value > 0 then
							CommF_:InvokeServer("AddPoint", REMOTE_NAME[key], pointsPerTick)
						end
					end)
				end
			end
		end
	end)

	StatsGroup:AddButton({
		Text = "Refund Stats (2500 Fragments)",
		Danger = true,
		Callback = function()
			pcall(function() CommF_:InvokeServer("BlackbeardReward", "Refund", "2") end)
		end
	})

	-- ===== ESP engine (one loop for every category instead of 11 separate ones) =====
	local espEnabled, espCache, proxies = {}, {}, {}

	local COLORS = {
		enemy = Color3.fromRGB(255, 80, 80),
		ally = Color3.fromRGB(80, 120, 255),
		island = Color3.fromRGB(98, 252, 252),
		fruit = Color3.fromRGB(255, 255, 255),
		object = Color3.fromRGB(80, 245, 245),
		flower = Color3.fromRGB(88, 214, 252),
	}

	local function dist(pos)
		local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
		if not root then return 0 end
		return math.floor((root.Position - pos).Magnitude / 3)
	end

	local function firstPart(obj)
		if obj:IsA("BasePart") then return obj end
		if obj:IsA("Model") then
			return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
		end
		return nil
	end

	local function makeLabel(adornee)
		local bb = Instance.new("BillboardGui")
		bb.Name = "PatronsESP"
		bb.Size = UDim2.new(0, 200, 0, 30)
		bb.ExtentsOffset = Vector3.new(0, 1, 0)
		bb.AlwaysOnTop = true
		bb.Adornee = adornee
		bb.Parent = adornee
		local lbl = Instance.new("TextLabel")
		lbl.BackgroundTransparency = 1
		lbl.Size = UDim2.new(1, 0, 1, 0)
		lbl.Font = Enum.Font.Code
		lbl.TextSize = 14
		lbl.TextWrapped = true
		lbl.TextStrokeTransparency = 0.5
		lbl.TextYAlignment = Enum.TextYAlignment.Top
		lbl.Parent = bb
		return bb
	end

	local function updateCategory(cat, entries)
		local cache = espCache[cat]
		if not cache then cache = {}; espCache[cat] = cache end
		local seen = {}
		for _, e in ipairs(entries) do
			local obj = e.adornee
			if obj and obj.Parent then
				seen[obj] = true
				local bb = cache[obj]
				if not bb or not bb.Parent then
					bb = makeLabel(obj)
					cache[obj] = bb
				end
				bb.TextLabel.Text = e.text
				bb.TextLabel.TextColor3 = e.color
			end
		end
		for obj, bb in pairs(cache) do
			if not seen[obj] then
				pcall(function() bb:Destroy() end)
				cache[obj] = nil
			end
		end
	end

	local function clearCategory(cat)
		if espCache[cat] then
			for _, bb in pairs(espCache[cat]) do pcall(function() bb:Destroy() end) end
			espCache[cat] = nil
		end
		if proxies[cat] then
			pcall(function() proxies[cat]:Destroy() end)
			proxies[cat] = nil
		end
	end

	local builders = {}

	builders.Player = function()
		local out = {}
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= plr and p.Character then
				local head = p.Character:FindFirstChild("Head")
				local hum = p.Character:FindFirstChildOfClass("Humanoid")
				if head and hum and hum.Health > 0 then
					local hp = math.floor(hum.Health / hum.MaxHealth * 100)
					table.insert(out, {
						adornee = head,
						text = string.format("%s | %d M\nHP: %d%%", p.Name, dist(head.Position), hp),
						color = (p.Team == plr.Team) and COLORS.ally or COLORS.enemy
					})
				end
			end
		end
		return out
	end

	local function locationEntries(filter)
		local out = {}
		local origin = workspace:FindFirstChild("_WorldOrigin")
		local locs = origin and origin:FindFirstChild("Locations")
		if locs then
			for _, loc in ipairs(locs:GetChildren()) do
				if loc:IsA("BasePart") and loc.Name ~= "Sea" and (not filter or filter[loc.Name]) then
					table.insert(out, {adornee = loc, text = loc.Name .. " | " .. dist(loc.Position) .. " M", color = COLORS.island})
				end
			end
		end
		return out
	end

	builders.Island = function() return locationEntries(nil) end
	builders.EventIsland = function()
		return locationEntries({["Mirage Island"] = true, ["Prehistoric Island"] = true, ["Kitsune Island"] = true, ["Frozen Dimension"] = true})
	end

	builders.Fruit = function()
		local out = {}
		for _, obj in ipairs(workspace:GetChildren()) do
			if string.find(obj.Name, "Fruit") then
				local handle = obj:FindFirstChild("Handle")
				if handle then
					table.insert(out, {adornee = handle, text = "[" .. obj.Name .. "] " .. dist(handle.Position) .. " M", color = COLORS.fruit})
				end
			end
		end
		return out
	end

	builders.Chest = function()
		local out = {}
		for _, chest in ipairs(CollectionService:GetTagged("_ChestTagged")) do
			if not chest:GetAttribute("IsDisabled") then
				local part = firstPart(chest)
				if part then
					local label = chest.Name:gsub("Label", "")
					table.insert(out, {adornee = part, text = label .. " | " .. dist(part.Position) .. " M", color = COLORS.object})
				end
			end
		end
		return out
	end

	builders.Flower = function()
		local out = {}
		for _, name in ipairs({"Flower1", "Flower2"}) do
			local f = workspace:FindFirstChild(name)
			if f and f:IsA("BasePart") then
				local nice = name == "Flower1" and "Blue Flower" or "Red Flower"
				table.insert(out, {adornee = f, text = nice .. " | " .. dist(f.Position) .. " M", color = COLORS.flower})
			end
		end
		return out
	end

	builders.Berry = function()
		local out = {}
		for _, bush in ipairs(CollectionService:GetTagged("BerryBush")) do
			local part = firstPart(bush) or (bush.Parent and firstPart(bush.Parent))
			if part then
				local names = {}
				for attr, val in pairs(bush:GetAttributes()) do
					if val then table.insert(names, attr) end
				end
				table.sort(names)
				table.insert(out, {adornee = part, text = "[" .. table.concat(names, ", ") .. "] " .. dist(part.Position) .. " M", color = COLORS.object})
			end
		end
		return out
	end

	builders.Gear = function()
		local out = {}
		local map = workspace:FindFirstChild("Map")
		local mi = map and map:FindFirstChild("MysticIsland")
		if mi then
			for _, d in ipairs(mi:GetDescendants()) do
				if d:IsA("BasePart") and d.Name == "Part" and d.Material == Enum.Material.Neon then
					table.insert(out, {adornee = d, text = "Gear | " .. dist(d.Position) .. " M", color = COLORS.object})
				end
			end
		end
		return out
	end

	-- dealer NPCs live in ReplicatedStorage, so we mirror them with an invisible part (like the source did)
	local NPC_ESP = {
		LegendarySword = "Legendary Sword Dealer",
		HakiColor = "Barista Cousin",
		AdvancedDealer = "Advanced Fruit Dealer",
	}

	local function npcEntries(cat)
		local name = NPC_ESP[cat]
		local wsNPCs = workspace:FindFirstChild("NPCs")
		local rsNPCs = ReplicatedStorage:FindFirstChild("NPCs")
		local npc = (wsNPCs and wsNPCs:FindFirstChild(name))
			or (rsNPCs and (rsNPCs:FindFirstChild(name) or rsNPCs:FindFirstChild(name .. " ")))
		local hrp = npc and npc:FindFirstChild("HumanoidRootPart")
		if not hrp then
			if proxies[cat] then
				pcall(function() proxies[cat]:Destroy() end)
				proxies[cat] = nil
			end
			return {}
		end
		local proxy = proxies[cat]
		if not proxy or not proxy.Parent then
			proxy = Instance.new("Part")
			proxy.Name = "PatronsESP_" .. cat
			proxy.Size = Vector3.new(1, 1, 1)
			proxy.Anchored = true
			proxy.CanCollide = false
			proxy.CanTouch = false
			proxy.Transparency = 1
			proxy.Parent = workspace
			proxies[cat] = proxy
		end
		proxy.CFrame = hrp.CFrame
		return {{adornee = proxy, text = name .. " | " .. dist(hrp.Position) .. " M", color = COLORS.object}}
	end

	for cat in pairs(NPC_ESP) do
		builders[cat] = function() return npcEntries(cat) end
	end

	task.spawn(function()
		while task.wait(0.5) do
			for cat, builder in pairs(builders) do
				if espEnabled[cat] then
					pcall(function() updateCategory(cat, builder()) end)
				end
			end
		end
	end)

	-- ===== ESP toggles =====
	local EspWorld = StatsTab:AddGroup("Right", "ESP - World")
	local EspObjects = StatsTab:AddGroup("Right", "ESP - Objects / NPCs")

	local function addEspToggle(group, text, cat, desc)
		group:AddToggle({
			Text = text,
			Desc = desc,
			Default = false,
			Callback = function(state)
				espEnabled[cat] = state
				if not state then clearCategory(cat) end
			end
		})
	end

	addEspToggle(EspWorld, "ESP Players", "Player", "Name, distance and health %")
	addEspToggle(EspWorld, "ESP Islands", "Island")
	addEspToggle(EspWorld, "ESP Event Islands", "EventIsland", "Mirage / Kitsune / Prehistoric / Frozen")
	addEspToggle(EspWorld, "ESP Fruits", "Fruit")
	addEspToggle(EspWorld, "ESP Chests", "Chest")

	addEspToggle(EspObjects, "ESP Flowers", "Flower", "Blue / Red flower for race V2")
	addEspToggle(EspObjects, "ESP Berries", "Berry")
	addEspToggle(EspObjects, "ESP Gears", "Gear", "Mirage Island gears")
	addEspToggle(EspObjects, "ESP Legendary Sword Dealer", "LegendarySword")
	addEspToggle(EspObjects, "ESP Haki Color Dealer", "HakiColor")
	addEspToggle(EspObjects, "ESP Advanced Fruit Dealer", "AdvancedDealer")
end

-- // ================= QUEST & ITEMS + FRUIT & RAID TABS =================
do
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local TweenService = game:GetService("TweenService")
	local RunService = game:GetService("RunService")
	local CollectionService = game:GetService("CollectionService")

	local plr = Players.LocalPlayer
	local CommF_ = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_")
	local CommE = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommE")
	local Net = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net")
	local RegisterAttack = Net:WaitForChild("RE/RegisterAttack")
	local RegisterHit = Net:WaitForChild("RE/RegisterHit")

	local World1 = game.PlaceId == 2753915549 or game.PlaceId == 85211729168715
	local World2 = game.PlaceId == 4442272183 or game.PlaceId == 79091703265657
	local World3 = game.PlaceId == 7449423635 or game.PlaceId == 100117331123089

	-- ===== Shared helpers for these two tabs =====
	local QI = {
		WeaponType = "Melee",
		Height = 25,
		Speed = 180,
		Attack = true,
	}

	local activeUsers = {}
	local currentTween = nil

	local function setActive(id, on)
		activeUsers[id] = on or nil
	end

	local function anyActive()
		return next(activeUsers) ~= nil
	end

	local function getRoot()
		local char = plr.Character
		return char and char:FindFirstChild("HumanoidRootPart")
	end

	local function alive(model)
		if not model then return false end
		local hum = model:FindFirstChildOfClass("Humanoid")
		return hum and hum.Health > 0
	end

	local function getBP(name)
		return plr.Backpack:FindFirstChild(name) or (plr.Character and plr.Character:FindFirstChild(name))
	end

	local function getEnemy(nameOrTable)
		local names = type(nameOrTable) == "table" and nameOrTable or {nameOrTable}
		local folder = workspace:FindFirstChild("Enemies")
		if not folder then return nil end
		for _, e in ipairs(folder:GetChildren()) do
			if e:IsA("Model") and table.find(names, e.Name) and alive(e) and e:FindFirstChild("HumanoidRootPart") then
				return e
			end
		end
		return nil
	end

	local function getReplicatedEnemy(nameOrTable)
		local names = type(nameOrTable) == "table" and nameOrTable or {nameOrTable}
		for _, e in ipairs(ReplicatedStorage:GetChildren()) do
			if e:IsA("Model") and table.find(names, e.Name) and alive(e) and e:FindFirstChild("HumanoidRootPart") then
				return e
			end
		end
		return nil
	end

	local function equipType(toolTip)
		local char = plr.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hum then return end
		local current = char:FindFirstChildOfClass("Tool")
		if current and current.ToolTip == toolTip then return end
		for _, tool in ipairs(plr.Backpack:GetChildren()) do
			if tool:IsA("Tool") and tool.ToolTip == toolTip then
				hum:EquipTool(tool)
				return
			end
		end
	end

	local function equipName(name)
		local tool = plr.Backpack:FindFirstChild(name)
		local char = plr.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if tool and hum then
			hum:EquipTool(tool)
		end
	end

	local Anchor = Instance.new("Part")
	Anchor.Name = "QuestFruitAnchor"
	Anchor.Size = Vector3.new(1, 1, 1)
	Anchor.Anchored = true
	Anchor.CanCollide = false
	Anchor.CanTouch = false
	Anchor.Transparency = 1
	Anchor.Parent = workspace

	local function move(cf, waitArrive, timeout)
		local root = getRoot()
		if not root then return end
		if typeof(cf) == "Vector3" then cf = CFrame.new(cf) end
		if currentTween then
			pcall(function() currentTween:Cancel() end)
		end
		Anchor.CFrame = root.CFrame
		local dist = (cf.Position - root.Position).Magnitude
		local speed = dist <= 15 and 180 or QI.Speed
		currentTween = TweenService:Create(Anchor, TweenInfo.new(math.max(dist / speed, 0.05), Enum.EasingStyle.Linear), {
			CFrame = CFrame.new(cf.Position)
		})
		currentTween:Play()
		if waitArrive then
			local t0 = os.clock()
			repeat
				task.wait(0.1)
				local r = getRoot()
				if not r or not anyActive() then break end
				if (r.Position - cf.Position).Magnitude <= 8 then break end
			until os.clock() - t0 > (timeout or 20)
		end
	end

	local function goButton(cf)
		setActive("QI_Button", true)
		move(cf, true, 25)
		setActive("QI_Button", false)
	end

	task.spawn(function()
		while task.wait() do
			pcall(function()
				local root = getRoot()
				if not root then return end
				if anyActive() then
					if (root.Position - Anchor.Position).Magnitude > 200 then
						Anchor.CFrame = root.CFrame
					end
					root.CFrame = Anchor.CFrame
					if not root:FindFirstChild("QI_BodyClip") then
						local bv = Instance.new("BodyVelocity")
						bv.Name = "QI_BodyClip"
						bv.MaxForce = Vector3.new(100000, 100000, 100000)
						bv.Velocity = Vector3.zero
						bv.Parent = root
					end
					for _, p in ipairs(plr.Character:GetDescendants()) do
						if p:IsA("BasePart") then p.CanCollide = false end
					end
				else
					local bv = root:FindFirstChild("QI_BodyClip")
					if bv then bv:Destroy() end
				end
			end)
		end
	end)

	local function attack()
		if not QI.Attack then return end
		pcall(function()
			local char = plr.Character
			local root = getRoot()
			if not char or not root then return end
			equipType(QI.WeaponType)
			if not char:FindFirstChildOfClass("Tool") then return end
			local hits, firstHead = {}, nil
			local folder = workspace:FindFirstChild("Enemies")
			if not folder then return end
			for _, e in ipairs(folder:GetChildren()) do
				local hum = e:FindFirstChildOfClass("Humanoid")
				local hrp = e:FindFirstChild("HumanoidRootPart")
				if hum and hrp and hum.Health > 0 and (hrp.Position - root.Position).Magnitude <= 60 then
					firstHead = firstHead or e:FindFirstChild("Head")
					for _, part in ipairs(e:GetChildren()) do
						if part:IsA("BasePart") then
							table.insert(hits, {e, part})
						end
					end
				end
			end
			if #hits > 0 and firstHead then
				RegisterAttack:FireServer(2e-09)
				RegisterHit:FireServer(firstHead, hits, {})
			end
		end)
	end

	local function kill(enemy)
		if not alive(enemy) then return end
		local hrp = enemy:FindFirstChild("HumanoidRootPart")
		if not hrp then return end
		equipType(QI.WeaponType)
		move(hrp.CFrame * CFrame.new(0, QI.Height, 0), false)
		attack()
	end

	local function getQuestTitle()
		local gui = plr.PlayerGui
		local main = gui:FindFirstChild("Main")
		local quest = main and main:FindFirstChild("Quest")
		if quest and quest.Visible then
			local ok, text = pcall(function() return quest.Container.QuestTitle.Title.Text end)
			return true, ok and text or ""
		end
		local tracked = gui:FindFirstChild("TrackedQuestFrame")
		if tracked and tracked.Enabled then
			local ok, text = pcall(function() return tracked.Frame.header.textLabel.Text end)
			if ok and text ~= "" then return true, text end
			local ok2, text2 = pcall(function() return tracked.Frame.header.textLabel.textLabel.Text end)
			return true, ok2 and text2 or ""
		end
		return false, ""
	end

	local function questHas(name)
		local visible, title = getQuestTitle()
		if not visible or title == "" then return false end
		return string.find(string.lower(title), string.lower(name), 1, true) ~= nil
	end

	local function getMaterial(name)
		local ok, inv = pcall(function() return CommF_:InvokeServer("getInventory") end)
		if not ok or type(inv) ~= "table" then return 0 end
		for _, item in pairs(inv) do
			if type(item) == "table" and item.Type == "Material" and item.Name == name then
				return item.Count or 0
			end
		end
		return 0
	end

	local function loop(sec, fn)
		task.spawn(function()
			while task.wait(sec) do
				pcall(fn)
			end
		end)
	end

	-- =========================================================
	-- QUEST & ITEMS TAB
	-- =========================================================
	local QuestTab = Window:CreateTab({ Name = "Quest & Items", Icon = "quest" })

	local Q = {
		Sea2 = false, Sea3 = false, Bartilo = false, Citizen = false,
		Observation = false, Rainbow = false, Elite = false,
		ItemFarm = false, LegendaryDealer = false,
	}

	-- ===== Sea Quests =====
	local SeaGroup = QuestTab:AddGroup("Left", "Sea Quests")

	SeaGroup:AddToggle({
		Text = "Auto Quest Sea 2",
		Desc = "Level 700+, Ice Admiral / Dressrosa travel",
		Default = false,
		Callback = function(state)
			Q.Sea2 = state
			setActive("Q_Sea2", state)
		end
	})

	SeaGroup:AddToggle({
		Text = "Auto Quest Sea 3",
		Desc = "Level 1500+, Don Swan / rip_indra / TravelZou",
		Default = false,
		Callback = function(state)
			Q.Sea3 = state
			setActive("Q_Sea3", state)
		end
	})

	SeaGroup:AddToggle({
		Text = "Auto Bartilo Quest",
		Desc = "Sea 2, level 850+",
		Default = false,
		Callback = function(state)
			Q.Bartilo = state
			setActive("Q_Bartilo", state)
		end
	})

	SeaGroup:AddToggle({
		Text = "Auto Citizen Quest",
		Desc = "Sea 3, level 1800+",
		Default = false,
		Callback = function(state)
			Q.Citizen = state
			setActive("Q_Citizen", state)
		end
	})

	SeaGroup:AddToggle({
		Text = "Auto Farm Observation",
		Desc = "Dodges near mobs to farm Ken",
		Default = false,
		Callback = function(state)
			Q.Observation = state
			setActive("Q_Obs", state)
		end
	})

	SeaGroup:AddToggle({
		Text = "Auto Rainbow Haki",
		Desc = "HornedMan quest + boss kills",
		Default = false,
		Callback = function(state)
			Q.Rainbow = state
			setActive("Q_Rainbow", state)
		end
	})

	SeaGroup:AddToggle({
		Text = "Auto Farm Elite",
		Desc = "Diablo / Deandre / Urban",
		Default = false,
		Callback = function(state)
			Q.Elite = state
			setActive("Q_Elite", state)
		end
	})

	-- ===== Item / Boss Farm =====
	local ItemGroup = QuestTab:AddGroup("Right", "Item / Boss Farm")

	local ITEM_FARMS = {
		{"Pole V1", "Thunder God", CFrame.new(-7994.984375, 5761.025390625, -2088.6479492188)},
		{"Saw Sword", "The Saw", CFrame.new(-784.89715576172, 72.427383422852, 1603.5822753906)},
		{"Saber Expert", "Saber Expert", CFrame.new(-1458.89502, 29.8870335, -50.633564)},
		{"Warden Sword", "Chief Warden", CFrame.new(5206.92578, 0.997753382, 814.976746)},
		{"Marine Coat", "Vice Admiral", CFrame.new(-5006.5454101563, 88.032081604004, 4353.162109375)},
		{"Swan Coat", "Swan", CFrame.new(5325.09619, 7.03906584, 719.570679)},
		{"Rengoku", "Awakened Ice Admiral", CFrame.new(6403.5439453125, 340.29766845703, -6894.5595703125)},
		{"Dragon Trident", "Tide Keeper", CFrame.new(-3795.6423339844, 105.88877105713, -11421.307617188)},
		{"Long Sword", "Diamond", CFrame.new(-1576.7166748047, 198.59265136719, 13.724286079407)},
		{"Black Spikey", "Jeremy", CFrame.new(2006.9261474609, 448.95666503906, 853.98284912109)},
		{"Darkbeard", "Darkbeard", CFrame.new(3677.08203125, 62.751937866211, -3144.8332519531)},
		{"Swan Glasses", "Don Swan", CFrame.new(2286.2004394531, 15.177839279175, 863.8388671875)},
		{"Bisento V2", "Greybeard", CFrame.new(-5023.38330078125, 28.652032852172852, 4332.3818359375)},
		{"Serpent Bow", "Hydra Leader", CFrame.new(5821.89794921875, 1019.0950927734375, -73.719230651855469)},
		{"Lei Accessory", "Kilo Admiral", CFrame.new(2764.2233886719, 432.46154785156, -7144.4580078125)},
		{"Twin Hooks", "Captain Elephant", CFrame.new(-13376.7578125, 433.28689575195, -8071.392578125)},
		{"Cavendish Sword", "Beautiful Pirate", CFrame.new(5283.609375, 22.56223487854, -110.78285217285)},
		{"Bigmom", "Cake Queen", CFrame.new(-709.31329345703125, 381.6005859375, -11011.396484375)},
		{"Longma", "Longma", CFrame.new(-10238.875976563, 389.7912902832, -9549.7939453125)},
		{"Soul Reaper", "Soul Reaper", CFrame.new(-9524.7890625, 315.80429077148, 6655.7192382813)},
		{"Cake Prince", "Cake Prince", CFrame.new(-2151.82, 149.32, -12404.91)},
		{"Dough King", "Dough King", CFrame.new(-1943.6765, 251.5095, -12337.8809)},
		{"rip_indra", "rip_indra", CFrame.new(-5344.822265625, 423.98541259766, -2725.0930175781)},
		{"Tyrant of the Skies", "Tyrant of the Skies", CFrame.new(-16268.287, 152.616, 1390.773)},
	}

	local itemNames = {}
	for _, v in ipairs(ITEM_FARMS) do table.insert(itemNames, v[1]) end
	local selectedItem = itemNames[1]

	ItemGroup:AddDropdown({
		Text = "Select Item / Boss",
		Options = itemNames,
		Default = itemNames[1],
		Callback = function(selected) selectedItem = selected end
	})

	ItemGroup:AddToggle({
		Text = "Auto Farm Selected",
		Desc = "Tween + kill the selected boss/item mob",
		Default = false,
		Callback = function(state)
			Q.ItemFarm = state
			setActive("Q_Item", state)
		end
	})

	ItemGroup:AddDropdown({
		Text = "Quest Weapon",
		Options = {"Melee", "Sword", "Blox Fruit", "Gun"},
		Default = "Melee",
		Callback = function(selected) QI.WeaponType = selected end
	})

	ItemGroup:AddSlider({
		Text = "Quest Tween Speed",
		Suffix = "",
		Min = 50, Max = 350, Step = 5, Decimals = 0, Default = 180,
		Callback = function(value) QI.Speed = value end
	})

	ItemGroup:AddSlider({
		Text = "Quest Farm Height",
		Suffix = " studs",
		Min = 0, Max = 60, Step = 1, Decimals = 0, Default = 25,
		Callback = function(value) QI.Height = value end
	})

	-- ===== Special Items / Dealers =====
	local SpecialGroup = QuestTab:AddGroup("Right", "Special Items")

	SpecialGroup:AddButton({
		Text = "Buy Legendary Swords",
		Callback = function()
			task.spawn(function()
				for i = 1, 3 do
					pcall(function() CommF_:InvokeServer("LegendarySwordDealer", tostring(i)) end)
					task.wait(0.3)
				end
			end)
		end
	})

	SpecialGroup:AddButton({
		Text = "Buy True Triple Katana",
		Callback = function()
			pcall(function() CommF_:InvokeServer("MysteriousMan", "2") end)
		end
	})

	SpecialGroup:AddButton({
		Text = "Buy Buso Colors",
		Callback = function()
			pcall(function() CommF_:InvokeServer("ColorsDealer", "2") end)
		end
	})

	SpecialGroup:AddToggle({
		Text = "Tween to Legendary Dealer",
		Default = false,
		Callback = function(state)
			Q.LegendaryDealer = state
			setActive("Q_Lgd", state)
		end
	})

	SpecialGroup:AddButton({
		Text = "Tween to Barista Cousin",
		Callback = function()
			local npc = (workspace:FindFirstChild("NPCs") and workspace.NPCs:FindFirstChild("Barista Cousin"))
				or (ReplicatedStorage:FindFirstChild("NPCs") and ReplicatedStorage.NPCs:FindFirstChild("Barista Cousin"))
			if npc and npc:FindFirstChild("HumanoidRootPart") then
				goButton(npc.HumanoidRootPart.CFrame)
			end
		end
	})

	SpecialGroup:AddButton({
		Text = "Talk With Stone",
		Callback = function()
			pcall(function()
				CommF_:InvokeServer("RaceV4Progress", "Begin")
				CommF_:InvokeServer("RaceV4Progress", "Check")
				CommF_:InvokeServer("RaceV4Progress", "Teleport")
			end)
		end
	})

	-- ===== Melee Styles (buy helpers) =====
	local MeleeGroup = QuestTab:AddGroup("Left", "Melee Styles")

	local function buyButton(text, remote, arg1, arg2)
		MeleeGroup:AddButton({
			Text = text,
			Callback = function()
				pcall(function()
					if arg1 ~= nil then
						CommF_:InvokeServer(remote, arg1, arg2)
					else
						CommF_:InvokeServer(remote)
					end
				end)
			end
		})
	end

	buyButton("Buy Black Leg", "BuyBlackLeg")
	buyButton("Buy Electro", "BuyElectro")
	buyButton("Buy Fishman Karate", "BuyFishmanKarate")
	buyButton("Buy Dragon Claw", "BlackbeardReward", "DragonClaw", "2")
	buyButton("Buy Superhuman", "BuySuperhuman")
	buyButton("Buy Death Step", "BuyDeathStep")
	buyButton("Buy Sharkman Karate", "BuySharkmanKarate")
	buyButton("Buy Electric Claw", "BuyElectricClaw")
	buyButton("Buy Dragon Talon", "BuyDragonTalon")
	buyButton("Buy Godhuman", "BuyGodhuman")
	buyButton("Buy Sanguine Art", "BuySanguineArt")

	-- ===== Quest loops =====
	loop(0.1, function()
		if not Q.ItemFarm then return end
		local data
		for _, v in ipairs(ITEM_FARMS) do
			if v[1] == selectedItem then data = v break end
		end
		if not data then return end
		local enemy = getEnemy(data[2])
		if enemy then
			kill(enemy)
		else
			local rep = getReplicatedEnemy(data[2])
			if rep and rep:FindFirstChild("HumanoidRootPart") then
				move(rep.HumanoidRootPart.CFrame * CFrame.new(0, 30, 0), false)
			else
				move(data[3] * CFrame.new(0, 30, 0), false)
			end
		end
	end)

	loop(0.2, function()
		if not Q.LegendaryDealer then return end
		local npc = (workspace:FindFirstChild("NPCs") and (workspace.NPCs:FindFirstChild("Legendary Sword Dealer") or workspace.NPCs:FindFirstChild("Legendary Sword Dealer ")))
			or (ReplicatedStorage:FindFirstChild("NPCs") and (ReplicatedStorage.NPCs:FindFirstChild("Legendary Sword Dealer") or ReplicatedStorage.NPCs:FindFirstChild("Legendary Sword Dealer ")))
		if npc and npc:FindFirstChild("HumanoidRootPart") then
			move(npc.HumanoidRootPart.CFrame, false)
		end
	end)

	loop(0.2, function()
		if not Q.Sea2 or not World1 then return end
		if plr.Data.Level.Value < 700 then return end
		local door = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Ice") and workspace.Map.Ice:FindFirstChild("Door")
		if door and door.CanCollide == true and door.Transparency == 0 then
			CommF_:InvokeServer("DressrosaQuestProgress", "Detective")
			equipName("Key")
			move(CFrame.new(1347.7124, 37.3751602, -1325.6488), false)
		else
			local enemy = getEnemy("Ice Admiral")
			if enemy then
				kill(enemy)
			else
				move(CFrame.new(1347.7124, 37.3751602, -1325.6488), false)
			end
			pcall(function() CommF_:InvokeServer("TravelDressrosa") end)
		end
	end)

	loop(0.2, function()
		if not Q.Sea3 or not World2 then return end
		if plr.Data.Level.Value < 1500 then return end
		local unlock = CommF_:InvokeServer("GetUnlockables")
		if type(unlock) == "table" and unlock.FlamingoAccess == nil then
			pcall(function() CommF_:InvokeServer("Cousin", "Buy") end)
			pcall(function() CommF_:InvokeServer("F_", "TalkTrevor", "1") end)
			pcall(function() CommF_:InvokeServer("F_", "TalkTrevor", "2") end)
			pcall(function() CommF_:InvokeServer("F_", "TalkTrevor", "3") end)
			return
		end
		local z = CommF_:InvokeServer("ZQuestProgress", "Check")
		if z == 0 then
			local enemy = getEnemy("rip_indra")
			if enemy then
				kill(enemy)
			else
				pcall(function() CommF_:InvokeServer("F_", "ZQuestProgress", "Begin") end)
			end
		elseif z == 1 then
			pcall(function() CommF_:InvokeServer("F_", "TravelZou") end)
		else
			local enemy = getEnemy("Don Swan")
			if enemy then
				kill(enemy)
			else
				move(CFrame.new(2288.802, 15.1870775, 863.034607), false)
			end
		end
	end)

	loop(0.2, function()
		if not Q.Bartilo or not World2 then return end
		if plr.Data.Level.Value < 850 then return end
		local progress = CommF_:InvokeServer("BartiloQuestProgress", "Bartilo")
		if progress == 0 then
			if not questHas("Swan Pirate") then
				move(CFrame.new(-461.533203, 72.3478546, 300.311096), false)
				pcall(function() CommF_:InvokeServer("StartQuest", "BartiloQuest", 1) end)
			else
				local enemy = getEnemy("Swan Pirate")
				if enemy then kill(enemy) else move(CFrame.new(1057.92761, 137.614319, 1242.08069), false) end
			end
		elseif progress == 1 then
			local enemy = getEnemy("Jeremy")
			if enemy then kill(enemy) else move(CFrame.new(2158.97412, 449.056244, 705.411682), false) end
		elseif progress == 2 then
			local plates = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Dressrosa") and workspace.Map.Dressrosa:FindFirstChild("BartiloPlates")
			if plates then
				for i = 1, 8 do
					local plate = plates:FindFirstChild("Plate" .. i)
					if plate then
						local root = getRoot()
						if root then root.CFrame = plate.CFrame end
						task.wait(0.5)
					end
				end
			end
		end
	end)

	loop(0.2, function()
		if not Q.Citizen or not World3 then return end
		if plr.Data.Level.Value < 1800 then return end
		if questHas("Forest Pirate") then
			local enemy = getEnemy("Forest Pirate")
			if enemy then kill(enemy) else move(CFrame.new(-13206.452148438, 425.89199829102, -7964.5537109375), false) end
		elseif questHas("Captain Elephant") then
			local enemy = getEnemy("Captain Elephant")
			if enemy then kill(enemy) else move(CFrame.new(-13374.889648438, 421.27752685547, -8225.208984375), false) end
		else
			move(CFrame.new(-12443.8671875, 332.40396118164, -7675.4892578125), false)
			pcall(function() CommF_:InvokeServer("CitizenQuestProgress", "Citizen") end)
			pcall(function() CommF_:InvokeServer("StartQuest", "CitizenQuest", 1) end)
		end
	end)

	loop(0.2, function()
		if not Q.Observation then return end
		pcall(function() CommE:FireServer("Ken", true) end)
		local mob, pos
		if World1 then
			mob, pos = "Galley Captain", CFrame.new(5533.29785, 88.1079102, 4852.3916)
		elseif World2 then
			mob, pos = "Lava Pirate", CFrame.new(-5478.39209, 15.9775667, -5246.9126)
		else
			mob, pos = "Venomous Assailant", CFrame.new(4530.3540039063, 656.75695800781, -131.60952758789)
		end
		local enemy = getEnemy(mob)
		if enemy and enemy:FindFirstChild("HumanoidRootPart") then
			local dodges = plr:GetAttribute("KenDodgesLeft") or 0
			if dodges > 0 then
				move(enemy.HumanoidRootPart.CFrame * CFrame.new(3, 0, 0), false)
			else
				move(enemy.HumanoidRootPart.CFrame * CFrame.new(0, 50, 0), false)
			end
		else
			move(pos, false)
		end
	end)

	loop(0.2, function()
		if not Q.Rainbow or not World3 then return end
		local visible, title = getQuestTitle()
		if not visible then
			move(CFrame.new(-11892.0703125, 930.57672119141, -8760.1591796875), false)
			pcall(function() CommF_:InvokeServer("HornedMan", "Bet") end)
			return
		end
		local boss, pos
		if string.find(title, "Stone") then
			boss, pos = "Stone", CFrame.new(-1086.11621, 38.8425903, 6768.71436)
		elseif string.find(title, "Hydra Leader") then
			boss, pos = "Hydra Leader", CFrame.new(5821.89794921875, 1019.0950927734375, -73.719230651855469)
		elseif string.find(title, "Kilo Admiral") then
			boss, pos = "Kilo Admiral", CFrame.new(2877.61743, 423.558685, -7207.31006)
		elseif string.find(title, "Captain Elephant") then
			boss, pos = "Captain Elephant", CFrame.new(-13376.7578125, 433.28689575195, -8071.392578125)
		elseif string.find(title, "Beautiful Pirate") then
			boss, pos = "Beautiful Pirate", CFrame.new(5283.609375, 22.56223487854, -110.78285217285)
		end
		if boss then
			local enemy = getEnemy(boss)
			if enemy then kill(enemy) else move(pos, false) end
		end
	end)

	loop(0.5, function()
		if not Q.Elite then return end
		local visible, title = getQuestTitle()
		if not visible then
			pcall(function() CommF_:InvokeServer("EliteHunter") end)
			return
		end
		local boss
		for _, name in ipairs({"Diablo", "Urban", "Deandre"}) do
			if string.find(title, name) then boss = name break end
		end
		if not boss then
			pcall(function() CommF_:InvokeServer("AbandonQuest") end)
			return
		end
		local enemy = getEnemy(boss)
		if enemy then
			kill(enemy)
		else
			local rep = getReplicatedEnemy(boss)
			if rep and rep:FindFirstChild("HumanoidRootPart") then
				move(rep.HumanoidRootPart.CFrame * CFrame.new(0, 30, 0), false)
			end
		end
	end)

	-- =========================================================
	-- FRUIT & RAID TAB
	-- =========================================================
	local FruitTab = Window:CreateTab({ Name = "Fruit & Raid", Icon = "fruit" })

	local F = {
		Random = false, Store = false, Drop = false, TweenFruit = false, CollectFruit = false,
		BuyFruit = false, ChipBeli = false, ChipFruit = false, StartRaid = false,
		Raid = false, Awaken = false, Lab = false,
		LawChip = false, LawStart = false, LawKill = false,
		Dungeon = false, DungeonExit = false,
	}

	local FruitGroup = FruitTab:AddGroup("Left", "Fruits")

	FruitGroup:AddToggle({
		Text = "Auto Random Fruit",
		Desc = "Cousin Buy",
		Default = false,
		Callback = function(state) F.Random = state end
	})

	FruitGroup:AddToggle({
		Text = "Auto Store Fruit",
		Default = false,
		Callback = function(state) F.Store = state end
	})

	FruitGroup:AddToggle({
		Text = "Auto Drop Fruit",
		Default = false,
		Callback = function(state) F.Drop = state end
	})

	FruitGroup:AddToggle({
		Text = "Auto Tween to Fruit",
		Default = false,
		Callback = function(state)
			F.TweenFruit = state
			setActive("F_TweenFruit", state)
		end
	})

	FruitGroup:AddToggle({
		Text = "Auto Collect Fruit",
		Desc = "Brings fruit handles to you",
		Default = false,
		Callback = function(state) F.CollectFruit = state end
	})

	local fruitList = {
		"Rocket-Rocket","Spin-Spin","Blade-Blade","Spring-Spring","Bomb-Bomb","Smoke-Smoke","Spike-Spike",
		"Flame-Flame","Ice-Ice","Sand-Sand","Dark-Dark","Eagle-Eagle","Diamond-Diamond","Light-Light",
		"Rubber-Rubber","Ghost-Ghost","Magma-Magma","Quake-Quake","Buddha-Buddha","Love-Love",
		"Creation-Creation","Spider-Spider","Sound-Sound","Phoenix-Phoenix","Portal-Portal",
		"Lightning-Lightning","Pain-Pain","Blizzard-Blizzard","Gravity-Gravity","T-Rex-T-Rex",
		"Mammoth-Mammoth","Dough-Dough","Shadow-Shadow","Venom-Venom","Gas-Gas","Control-Control",
		"Spirit-Spirit","Leopard-Leopard","Yeti-Yeti","Kitsune-Kitsune","Dragon-Dragon"
	}
	local selectedFruit = fruitList[1]

	FruitGroup:AddDropdown({
		Text = "Select Fruit Shop",
		Options = fruitList,
		Default = fruitList[1],
		Callback = function(selected) selectedFruit = selected end
	})

	FruitGroup:AddToggle({
		Text = "Auto Buy Fruit Shop",
		Default = false,
		Callback = function(state) F.BuyFruit = state end
	})

	-- ===== Raids =====
	local RaidGroup = FruitTab:AddGroup("Right", "Raids")

	local chips = {"Flame","Ice","Quake","Light","Dark","String","Rumble","Magma","Human: Buddha","Sand","Bird: Phoenix","Dough"}
	local selectedChip = chips[1]

	RaidGroup:AddDropdown({
		Text = "Select Chip",
		Options = chips,
		Default = chips[1],
		Callback = function(selected) selectedChip = selected end
	})

	RaidGroup:AddToggle({
		Text = "Auto Buy Chip [Beli]",
		Default = false,
		Callback = function(state) F.ChipBeli = state end
	})

	RaidGroup:AddToggle({
		Text = "Auto Buy Chip [Devil Fruit]",
		Default = false,
		Callback = function(state) F.ChipFruit = state end
	})

	RaidGroup:AddToggle({
		Text = "Auto Start Raid",
		Default = false,
		Callback = function(state)
			F.StartRaid = state
			setActive("F_StartRaid", state)
		end
	})

	RaidGroup:AddToggle({
		Text = "Auto Raid + Next Island",
		Default = false,
		Callback = function(state)
			F.Raid = state
			setActive("F_Raid", state)
		end
	})

	RaidGroup:AddToggle({
		Text = "Auto Awakening",
		Default = false,
		Callback = function(state) F.Awaken = state end
	})

	RaidGroup:AddToggle({
		Text = "Auto Teleport To Lab",
		Default = false,
		Callback = function(state)
			F.Lab = state
			setActive("F_Lab", state)
		end
	})

	-- ===== Law / Dungeon =====
	local LawGroup = FruitTab:AddGroup("Right", "Law / Dungeon")

	LawGroup:AddToggle({
		Text = "Auto Buy Law Microchip",
		Default = false,
		Callback = function(state) F.LawChip = state end
	})

	LawGroup:AddToggle({
		Text = "Auto Start Law Raids",
		Default = false,
		Callback = function(state) F.LawStart = state end
	})

	LawGroup:AddToggle({
		Text = "Auto Kill Law",
		Default = false,
		Callback = function(state)
			F.LawKill = state
			setActive("F_LawKill", state)
		end
	})

	LawGroup:AddToggle({
		Text = "Auto Farm Dungeon",
		Desc = "Kills enemies inside dungeon",
		Default = false,
		Callback = function(state)
			F.Dungeon = state
			setActive("F_Dungeon", state)
		end
	})

	local exitMethod = "Nearest Exit"
	LawGroup:AddDropdown({
		Text = "Dungeon Exit Method",
		Options = {"Nearest Exit", "Entrance -> Exit", "Highest Floor"},
		Default = "Nearest Exit",
		Callback = function(selected) exitMethod = selected end
	})

	LawGroup:AddToggle({
		Text = "Auto TP Exit",
		Default = false,
		Callback = function(state) F.DungeonExit = state end
	})

	-- ===== Fruit loops =====
	loop(0.5, function()
		if F.Random then
			pcall(function() CommF_:InvokeServer("Cousin", "Buy") end)
		end
	end)

	loop(0.5, function()
		if not F.Store then return end
		for _, tool in ipairs(plr.Backpack:GetChildren()) do
			local eat = tool:FindFirstChild("EatRemote", true)
			if eat then
				pcall(function()
					CommF_:InvokeServer("StoreFruit", eat.Parent:GetAttribute("OriginalName"), tool)
				end)
			end
		end
	end)

	loop(0.5, function()
		if not F.Drop then return end
		for _, tool in ipairs(plr.Backpack:GetChildren()) do
			if string.find(tool.Name, "Fruit") then
				pcall(function()
					equipName(tool.Name)
					task.wait(0.1)
					local equipped = plr.Character:FindFirstChild(tool.Name)
					if equipped and equipped:FindFirstChild("EatRemote") then
						equipped.EatRemote:InvokeServer("Drop")
					end
				end)
			end
		end
	end)

	loop(0.2, function()
		if F.TweenFruit then
			for _, obj in ipairs(workspace:GetChildren()) do
				if string.find(obj.Name, "Fruit") and obj:FindFirstChild("Handle") then
					move(obj.Handle.CFrame, false)
					break
				end
			end
		end
		if F.CollectFruit then
			local root = getRoot()
			if not root then return end
			for _, obj in ipairs(workspace:GetChildren()) do
				if string.find(obj.Name, "Fruit") and obj:FindFirstChild("Handle") then
					pcall(function() obj.Handle.CFrame = root.CFrame end)
				end
			end
		end
	end)

	loop(0.2, function()
		if not F.BuyFruit then return end
		pcall(function() CommF_:InvokeServer("GetFruits") end)
		pcall(function() CommF_:InvokeServer("PurchaseRawFruit", selectedFruit) end)
	end)

	-- ===== Raid loops =====
	loop(1, function()
		if F.ChipBeli and not getBP("Special Microchip") then
			pcall(function() CommF_:InvokeServer("RaidsNpc", "Select", selectedChip) end)
		end
		if F.ChipFruit and not getBP("Special Microchip") then
			local ok, fruits = pcall(function() return CommF_:InvokeServer("GetFruits") end)
			if ok and type(fruits) == "table" then
				for _, fruit in pairs(fruits) do
					if fruit.Price and fruit.Price <= 490000 then
						pcall(function() CommF_:InvokeServer("LoadFruit", fruit.Name) end)
						pcall(function() CommF_:InvokeServer("RaidsNpc", "Select", selectedChip) end)
						break
					end
				end
			end
		end
	end)

	loop(0.5, function()
		if not F.StartRaid then return end
		local raidTimer = plr.PlayerGui:FindFirstChild("Main")
			and plr.PlayerGui.Main:FindFirstChild("TopHUDList")
			and plr.PlayerGui.Main.TopHUDList:FindFirstChild("RaidTimer")
		if raidTimer and raidTimer.Visible then return end
		if not getBP("Special Microchip") then return end
		if World2 then
			move(CFrame.new(-6438.73535, 250.645355, -4501.50684), true, 15)
			pcall(function()
				if fireclickdetector then
					fireclickdetector(workspace.Map.CircleIsland.RaidSummon2.Button.Main.ClickDetector)
				end
			end)
		elseif World3 then
			move(CFrame.new(-5046, 314, -2960), true, 15)
			pcall(function()
				if fireclickdetector then
					fireclickdetector(workspace.Map["Boat Castle"].RaidSummon2.Button.Main.ClickDetector)
				end
			end)
		end
	end)

	loop(0.3, function()
		if not F.Raid then return end
		local raidTimer = plr.PlayerGui:FindFirstChild("Main")
			and plr.PlayerGui.Main:FindFirstChild("TopHUDList")
			and plr.PlayerGui.Main.TopHUDList:FindFirstChild("RaidTimer")
		if not raidTimer or not raidTimer.Visible then return end
		local root = getRoot()
		if not root then return end
		local locations = workspace:FindFirstChild("_WorldOrigin") and workspace._WorldOrigin:FindFirstChild("Locations")
		if not locations then return end
		local islands = {"Island 1", "Island 2", "Island 3", "Island 4", "Island 5"}
		local nearest, nearestDist
		for _, name in ipairs(islands) do
			local loc = locations:FindFirstChild(name)
			if loc then
				local d = (root.Position - loc.Position).Magnitude
				if not nearestDist or d < nearestDist then
					nearest, nearestDist = name, d
				end
			end
		end
		if not nearest then return end
		local loc = locations:FindFirstChild(nearest)
		local folder = workspace:FindFirstChild("Enemies")
		if folder and loc then
			for _, e in ipairs(folder:GetChildren()) do
				local hrp = e:FindFirstChild("HumanoidRootPart")
				if alive(e) and hrp and (hrp.Position - loc.Position).Magnitude < 450 then
					kill(e)
					return
				end
			end
		end
		local idx = table.find(islands, nearest)
		if idx and islands[idx + 1] then
			local nextLoc = locations:FindFirstChild(islands[idx + 1])
			if nextLoc then
				move(nextLoc.CFrame * CFrame.new(0, 45, 120), false)
			end
		end
	end)

	loop(0.5, function()
		if F.Awaken then
			pcall(function() CommF_:InvokeServer("Awakener", "Check") end)
			pcall(function() CommF_:InvokeServer("Awakener", "Awaken") end)
		end
	end)

	loop(0.5, function()
		if not F.Lab then return end
		if World2 then
			move(CFrame.new(-6438.73535, 250.645355, -4501.50684), false)
		elseif World3 then
			move(CFrame.new(-5046, 314, -2960), false)
		end
	end)

	-- ===== Law / Dungeon loops =====
	loop(1, function()
		if F.LawChip then
			pcall(function() CommF_:InvokeServer("BlackbeardReward", "Microchip", "2") end)
		end
		if F.LawStart then
			pcall(function()
				if fireclickdetector then
					fireclickdetector(workspace.Map.CircleIsland.RaidSummon.Button.Main.ClickDetector)
				end
			end)
		end
	end)

	loop(0.2, function()
		if not F.LawKill then return end
		local enemy = getEnemy("Order")
		if enemy then
			kill(enemy)
		else
			move(CFrame.new(-6217.2021484375, 28.047645568848, -5053.1357421875), false)
		end
	end)

	loop(0.15, function()
		if not F.Dungeon then return end
		local root = getRoot()
		if not root then return end
		local folder = workspace:FindFirstChild("Enemies")
		if not folder then return end
		for _, e in ipairs(folder:GetChildren()) do
			local hrp = e:FindFirstChild("HumanoidRootPart")
			if alive(e) and hrp and (hrp.Position - root.Position).Magnitude <= 5000 then
				kill(e)
				return
			end
		end
	end)

	loop(0.5, function()
		if not F.DungeonExit then return end
		local root = getRoot()
		local dungeon = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Dungeon")
		if not root or not dungeon then return end
		local target
		if exitMethod == "Nearest Exit" then
			local best, bestDist
			for _, child in pairs(dungeon:GetChildren()) do
				local exit = child:FindFirstChild("ExitTeleporter")
				local exitRoot = exit and exit:FindFirstChild("Root")
				if exitRoot then
					local d = (root.Position - exitRoot.Position).Magnitude
					if not bestDist or d < bestDist then best, bestDist = exitRoot, d end
				end
			end
			target = best
		elseif exitMethod == "Entrance -> Exit" then
			for _, child in pairs(dungeon:GetChildren()) do
				local entrance = child:FindFirstChild("EntranceTeleporter")
				local exit = child:FindFirstChild("ExitTeleporter")
				local entranceRoot = entrance and entrance:FindFirstChild("Root")
				local exitRoot = exit and exit:FindFirstChild("Root")
				if entranceRoot and exitRoot and (root.Position - entranceRoot.Position).Magnitude < 100 then
					target = exitRoot
					break
				end
			end
		elseif exitMethod == "Highest Floor" then
			local highest
			for _, child in pairs(dungeon:GetChildren()) do
				local n = tonumber(child.Name)
				if n and (not highest or n > tonumber(highest.Name)) then
					highest = child
				end
			end
			target = highest and highest:FindFirstChild("ExitTeleporter") and highest.ExitTeleporter:FindFirstChild("Root")
		end
		if target then
			root.CFrame = target.CFrame * CFrame.new(0, 3, 0)
		end
	end)
end

-- // ================= VOLCANO EVENT + MIRAGE & RACE TABS =================
do
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local TweenService = game:GetService("TweenService")
	local Lighting = game:GetService("Lighting")
	local CollectionService = game:GetService("CollectionService")
	local VIM = game:GetService("VirtualInputManager")

	local plr = Players.LocalPlayer
	local CommF_ = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_")
	local CommE = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommE")
	local Net = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net")
	local RegisterAttack = Net:WaitForChild("RE/RegisterAttack")
	local RegisterHit = Net:WaitForChild("RE/RegisterHit")

	local Cfg = {WeaponType = "Melee", Speed = 220, Height = 30, Boat = "Guardian"}

	-- ===== Helpers =====
	local function getRoot()
		local c = plr.Character
		return c and c:FindFirstChild("HumanoidRootPart")
	end
	local function getHum()
		local c = plr.Character
		return c and c:FindFirstChildOfClass("Humanoid")
	end
	local function alive(m)
		if not m then return false end
		local h = m:FindFirstChildOfClass("Humanoid")
		return h and h.Health > 0
	end
	local function enemyFolder() return workspace:FindFirstChild("Enemies") end
	local function getEnemy(names)
		if type(names) == "string" then names = {names} end
		local f = enemyFolder()
		if not f then return nil end
		for _, e in ipairs(f:GetChildren()) do
			if table.find(names, e.Name) and alive(e) and e:FindFirstChild("HumanoidRootPart") then return e end
		end
		return nil
	end
	local function getRepEnemy(names)
		if type(names) == "string" then names = {names} end
		for _, e in ipairs(ReplicatedStorage:GetChildren()) do
			if e:IsA("Model") and table.find(names, e.Name) and alive(e) and e:FindFirstChild("HumanoidRootPart") then return e end
		end
		return nil
	end
	local function equipType(tip)
		local hum = getHum()
		if not hum then return end
		local cur = plr.Character:FindFirstChildOfClass("Tool")
		if cur and cur.ToolTip == tip then return end
		for _, t in ipairs(plr.Backpack:GetChildren()) do
			if t:IsA("Tool") and t.ToolTip == tip then hum:EquipTool(t) return end
		end
	end
	local function getMaterial(name)
		local ok, inv = pcall(function() return CommF_:InvokeServer("getInventory") end)
		if not ok or type(inv) ~= "table" then return 0 end
		for _, i in pairs(inv) do
			if type(i) == "table" and i.Type == "Material" and i.Name == name then return i.Count or 0 end
		end
		return 0
	end
	local function questTitle()
		local gui = plr.PlayerGui
		local main = gui:FindFirstChild("Main")
		local q = main and main:FindFirstChild("Quest")
		if q and q.Visible then
			local ok, t = pcall(function() return q.Container.QuestTitle.Title.Text end)
			return true, ok and t or ""
		end
		local tr = gui:FindFirstChild("TrackedQuestFrame")
		if tr and tr.Enabled then
			local ok, t = pcall(function() return tr.Frame.header.textLabel.Text end)
			if ok and t ~= "" then return true, t end
			local ok2, t2 = pcall(function() return tr.Frame.header.textLabel.textLabel.Text end)
			return true, ok2 and t2 or ""
		end
		return false, ""
	end
	local function raceName()
		local ok, r = pcall(function() return tostring(plr.Data.Race.Value) end)
		return ok and r or ""
	end
	local function loop(sec, fn)
		task.spawn(function()
			while task.wait(sec) do pcall(fn) end
		end)
	end
	local function pressKey(k, hold)
		pcall(function()
			VIM:SendKeyEvent(true, k, false, game)
			task.wait(hold or 0.05)
			VIM:SendKeyEvent(false, k, false, game)
		end)
	end
	local function useSkills(tip, keys)
		equipType(tip)
		for _, k in ipairs(keys) do
			pressKey(k)
			task.wait(0.15)
		end
	end
	local function skillBurst()
		useSkills("Melee", {"Z", "X", "C"})
		useSkills("Sword", {"Z", "X"})
		useSkills("Blox Fruit", {"Z", "X", "C"})
		useSkills("Gun", {"Z", "X"})
	end
	local function prompt(obj)
		pcall(function()
			if fireproximityprompt then fireproximityprompt(obj, math.huge) end
		end)
	end

	-- ===== Movement engine =====
	local Anchor = Instance.new("Part")
	Anchor.Name = "VolcanoMirageAnchor"
	Anchor.Size = Vector3.new(1, 1, 1)
	Anchor.Anchored = true
	Anchor.CanCollide = false
	Anchor.CanTouch = false
	Anchor.Transparency = 1
	Anchor.Parent = workspace

	local users, currentTween = {}, nil
	local function setActive(id, on) users[id] = on or nil end
	local function anyActive() return next(users) ~= nil end

	local function move(cf, waitArrive, timeout)
		local root = getRoot()
		if not root then return end
		if typeof(cf) == "Vector3" then cf = CFrame.new(cf) end
		if currentTween then pcall(function() currentTween:Cancel() end) end
		if (Anchor.Position - root.Position).Magnitude > 200 then Anchor.CFrame = root.CFrame end
		local dist = (cf.Position - Anchor.Position).Magnitude
		currentTween = TweenService:Create(Anchor, TweenInfo.new(math.max(dist / Cfg.Speed, 0.05), Enum.EasingStyle.Linear), {
			CFrame = CFrame.new(cf.Position)
		})
		currentTween:Play()
		if waitArrive then
			local t0 = os.clock()
			repeat
				task.wait(0.1)
				local r = getRoot()
				if not r or not anyActive() then break end
				if (r.Position - cf.Position).Magnitude <= 8 then break end
			until os.clock() - t0 > (timeout or 25)
		end
	end
	local function notween(cf)
		local root = getRoot()
		if root then
			if typeof(cf) == "Vector3" then cf = CFrame.new(cf) end
			root.CFrame = cf
		end
	end
	local function goButton(cf)
		setActive("VM_Button", true)
		move(cf, true, 25)
		setActive("VM_Button", false)
	end

	task.spawn(function()
		while task.wait() do
			pcall(function()
				local root = getRoot()
				if not root then return end
				if anyActive() then
					if (root.Position - Anchor.Position).Magnitude <= 200 then
						root.CFrame = Anchor.CFrame
					else
						Anchor.CFrame = root.CFrame
					end
					if not root:FindFirstChild("VM_BodyClip") then
						local bv = Instance.new("BodyVelocity")
						bv.Name = "VM_BodyClip"
						bv.MaxForce = Vector3.new(100000, 100000, 100000)
						bv.Velocity = Vector3.zero
						bv.Parent = root
					end
					for _, p in ipairs(plr.Character:GetDescendants()) do
						if p:IsA("BasePart") then p.CanCollide = false end
					end
				else
					local bv = root:FindFirstChild("VM_BodyClip")
					if bv then bv:Destroy() end
				end
			end)
		end
	end)

	-- ===== Combat =====
	local function attack(includePlayers)
		pcall(function()
			local char, root = plr.Character, getRoot()
			if not char or not root or not char:FindFirstChildOfClass("Tool") then return end
			local hits, head = {}, nil
			local function scan(folder)
				if not folder then return end
				for _, e in ipairs(folder:GetChildren()) do
					if e ~= char and alive(e) then
						local hrp = e:FindFirstChild("HumanoidRootPart")
						if hrp and (hrp.Position - root.Position).Magnitude <= 60 then
							head = head or e:FindFirstChild("Head")
							for _, p in ipairs(e:GetChildren()) do
								if p:IsA("BasePart") then table.insert(hits, {e, p}) end
							end
						end
					end
				end
			end
			scan(enemyFolder())
			if includePlayers then scan(workspace:FindFirstChild("Characters")) end
			if head and #hits > 0 then
				RegisterAttack:FireServer(2e-09)
				RegisterHit:FireServer(head, hits, {})
			end
		end)
	end
	local function kill(enemy, pvp)
		if not alive(enemy) then return end
		local hrp = enemy:FindFirstChild("HumanoidRootPart")
		if not hrp then return end
		equipType(Cfg.WeaponType)
		move(hrp.CFrame * CFrame.new(0, Cfg.Height, 0), false)
		attack(pvp)
	end

	-- ===== Boat / sailing =====
	local DOCK = CFrame.new(-16927.451, 9.086, 433.864)
	local OPEN_SEA = Vector3.new(-10000000, 31, 37016.25)

	local function myBoat()
		local boats = workspace:FindFirstChild("Boats")
		if not boats then return nil end
		for _, b in ipairs(boats:GetChildren()) do
			local o = b:FindFirstChild("Owner")
			if o and tostring(o.Value) == plr.Name then return b end
		end
		return nil
	end
	local function seaThreat()
		local f = enemyFolder()
		if not f then return false end
		for _, m in ipairs(f:GetChildren()) do
			if m.Name == "FishBoat" or m.Name == "PirateGrandBrigade" or m.Name == "PirateBrigade" or m.Name == "Terrorshark" then
				local h = m:FindFirstChild("Health")
				if (h and h.Value > 0) or alive(m) then return true end
			end
		end
		return false
	end
	local function sailTo(pos)
		local root, hum = getRoot(), getHum()
		if not root or not hum then return end
		local boat = myBoat()
		if not boat then
			move(DOCK, false)
			if (root.Position - DOCK.Position).Magnitude <= 12 then
				pcall(function() CommF_:InvokeServer("BuyBoat", Cfg.Boat) end)
			end
			return
		end
		local seat = boat:FindFirstChildWhichIsA("VehicleSeat")
		if not seat then return end
		if not hum.Sit then
			move(seat.CFrame * CFrame.new(0, 1, 0), false)
		else
			local y = seaThreat() and (pos.Y + 150) or pos.Y
			move(CFrame.new(pos.X, y, pos.Z), false)
		end
	end
	local function seaBeast()
		local f = workspace:FindFirstChild("SeaBeasts")
		if not f then return nil end
		for _, b in ipairs(f:GetChildren()) do
			local h = b:FindFirstChild("Health")
			if h and h.Value > 0 and b:FindFirstChild("HumanoidRootPart") then return b end
		end
		return nil
	end
	local function killSeaBeast()
		local b = seaBeast()
		if not b then return false end
		local water = workspace.Map:FindFirstChild("WaterBase-Plane")
		local y = water and (water.Position.Y + 250) or 300
		move(CFrame.new(b.HumanoidRootPart.Position.X, y, b.HumanoidRootPart.Position.Z), false)
		skillBurst()
		return true
	end

	-- =========================================================
	-- VOLCANO EVENT TAB
	-- =========================================================
	local VolcanoTab = Window:CreateTab({ Name = "Volcano", Icon = "volcano" })

	local V = {
		Find = false, Start = false, Patch = false, Bones = false, Eggs = false,
		Reset = false, KillAura = false, Dojo = false, Hunter = false, Ember = false,
		DragoV1 = false, DragoV2 = false, DragoV3 = false, Relic = false, TrainV4 = false, TpTrial = false,
	}

	local function mapFolder() return workspace:FindFirstChild("Map") end
	local function prehistoric() local m = mapFolder() return m and m:FindFirstChild("PrehistoricIsland") end
	local function location(name)
		local o = workspace:FindFirstChild("_WorldOrigin")
		local l = o and o:FindFirstChild("Locations")
		return l and l:FindFirstChild(name)
	end

	local function findPrehistoric()
		local loc = location("Prehistoric Island")
		if loc then
			local head = loc:FindFirstChild("HeadTeleport", true) or loc:FindFirstChild("Teleport_Head", true) or loc:FindFirstChild("Head", true)
			if head then
				move(head.CFrame.Position - head.CFrame.LookVector * 40 + Vector3.new(0, 20, 0), false)
			else
				move(loc.CFrame * CFrame.new(0, 60, 0), false)
			end
		else
			sailTo(OPEN_SEA)
		end
	end
	local function startEvent()
		local p = prehistoric()
		local core = p and p:FindFirstChild("Core")
		local ap = core and core:FindFirstChild("ActivationPrompt", true)
		if not ap then return end
		move(ap.CFrame, false)
		local pp = ap:FindFirstChild("ProximityPrompt")
		if pp then
			prompt(pp)
			pressKey("E", 1.2)
		end
	end
	local function patchEvent()
		local p = prehistoric()
		if not p then return end
		local trial = p:FindFirstChild("TrialTeleport")
		for _, d in ipairs(p:GetDescendants()) do
			pcall(function()
				if (d:IsA("BasePart") or d:IsA("MeshPart")) and d.Name:lower():find("lava") then
					d:Destroy()
				elseif d.Name == "TouchInterest" and (not trial or not d:IsDescendantOf(trial)) then
					d.Parent:Destroy()
				end
			end)
		end
		local golem = getEnemy("Lava Golem")
		if golem then
			kill(golem)
			return
		end
		local core = p:FindFirstChild("Core")
		local rocks = core and core:FindFirstChild("VolcanoRocks")
		if rocks then
			for _, r in ipairs(rocks:GetChildren()) do
				local vfx = r:FindFirstChild("VFXLayer")
				local at0 = vfx and vfx:FindFirstChild("At0")
				local glow = at0 and at0:FindFirstChild("Glow")
				if glow and glow.Enabled then
					move(vfx.CFrame, false)
					skillBurst()
					return
				end
			end
		end
	end
	local function collectBones()
		for _, c in ipairs(workspace:GetChildren()) do
			if c.Name == "DinoBone" and c:IsA("BasePart") then
				move(c.CFrame, false)
				return
			end
		end
	end
	local function collectEggs()
		local p = prehistoric()
		local core = p and p:FindFirstChild("Core")
		local spawned = core and core:FindFirstChild("SpawnedDragonEggs")
		local egg = spawned and spawned:FindFirstChild("DragonEgg")
		local molten = egg and egg:FindFirstChild("Molten")
		if molten then
			move(molten.CFrame, false)
			local pp = molten:FindFirstChild("ProximityPrompt")
			if pp then prompt(pp) end
		end
	end

	-- ===== Prehistoric Island group =====
	local PrehisGroup = VolcanoTab:AddGroup("Left", "Prehistoric Island")

	PrehisGroup:AddDropdown({
		Text = "Select Boat",
		Options = {"Guardian", "PirateGrandBrigade", "MarineGrandBrigade", "PirateBrigade", "MarineBrigade", "PirateSloop", "MarineSloop", "Beast Hunter"},
		Default = "Guardian",
		Callback = function(s) Cfg.Boat = s end
	})
	PrehisGroup:AddToggle({
		Text = "Auto Find Prehistoric Island",
		Desc = "Buys boat, sails open sea until it spawns",
		Default = false,
		Callback = function(s) V.Find = s setActive("V_Find", s) end
	})
	PrehisGroup:AddToggle({
		Text = "Auto Start Event",
		Desc = "Activates the volcano core prompt",
		Default = false,
		Callback = function(s) V.Start = s setActive("V_Start", s) end
	})
	PrehisGroup:AddToggle({
		Text = "Auto Patch Event",
		Desc = "Removes lava, kills Golems, breaks glowing rocks",
		Default = false,
		Callback = function(s) V.Patch = s setActive("V_Patch", s) end
	})
	PrehisGroup:AddToggle({
		Text = "Auto Collect Dino Bones",
		Default = false,
		Callback = function(s) V.Bones = s setActive("V_Bones", s) end
	})
	PrehisGroup:AddToggle({
		Text = "Auto Collect Dragon Eggs",
		Default = false,
		Callback = function(s) V.Eggs = s setActive("V_Eggs", s) end
	})
	PrehisGroup:AddToggle({
		Text = "Auto Reset When Volcano Done",
		Default = false,
		Callback = function(s) V.Reset = s end
	})
	PrehisGroup:AddToggle({
		Text = "Kill Aura (Client)",
		Desc = "Client-side only, may not register on server",
		Default = false,
		Callback = function(s) V.KillAura = s end
	})
	PrehisGroup:AddButton({
		Text = "Craft Volcanic Magnet",
		Callback = function()
			pcall(function() Net["RF/Craft"]:InvokeServer("PossibleHardcode", "Volcanic Magnet") end)
		end
	})

	-- ===== Dojo / Dragon Hunter =====
	local DojoGroup = VolcanoTab:AddGroup("Left", "Dojo / Dragon Hunter")
	local DOJO = CFrame.new(5814.42724609375, 1208.3267822265625, 884.57855224609375)
	local DOJO_NPC = CFrame.new(5865.0234375, 1208.3154296875, 871.15185546875)

	DojoGroup:AddButton({
		Text = "Teleport to Dojo",
		Primary = true,
		Callback = function()
			pcall(function() CommF_:InvokeServer("requestEntrance", Vector3.new(5661.5322265625, 1013.0907592773438, -334.96499633789062)) end)
			goButton(DOJO)
		end
	})
	DojoGroup:AddToggle({
		Text = "Auto Dojo Trainer",
		Desc = "Belt quests: White/Purple/Black + sea belts",
		Default = false,
		Callback = function(s) V.Dojo = s setActive("V_Dojo", s) end
	})
	DojoGroup:AddToggle({
		Text = "Auto Dragon Hunter",
		Desc = "Kill / bamboo quests + ember pickup",
		Default = false,
		Callback = function(s) V.Hunter = s setActive("V_Hunter", s) end
	})
	DojoGroup:AddToggle({
		Text = "Auto Collect Ember",
		Default = false,
		Callback = function(s) V.Ember = s setActive("V_Ember", s) end
	})

	-- ===== Drago Trial =====
	local DragoGroup = VolcanoTab:AddGroup("Right", "Drago Trial")

	DragoGroup:AddToggle({
		Text = "Auto Drago V1 (Dragon Egg)",
		Desc = "Runs volcano event until you get an egg",
		Default = false,
		Callback = function(s) V.DragoV1 = s setActive("V_D1", s) end
	})
	DragoGroup:AddToggle({
		Text = "Auto Drago V2 (Fire Flowers)",
		Default = false,
		Callback = function(s) V.DragoV2 = s setActive("V_D2", s) end
	})
	DragoGroup:AddToggle({
		Text = "Auto Drago V3 (Terror Shark)",
		Desc = "Sails open sea and kills Terrorsharks",
		Default = false,
		Callback = function(s) V.DragoV3 = s setActive("V_D3", s) end
	})
	DragoGroup:AddToggle({
		Text = "Auto Relic Drago Trial",
		Default = false,
		Callback = function(s) V.Relic = s setActive("V_Relic", s) end
	})
	DragoGroup:AddToggle({
		Text = "Auto Train Drago V4",
		Default = false,
		Callback = function(s) V.TrainV4 = s setActive("V_Train4", s) end
	})
	DragoGroup:AddToggle({
		Text = "Tween to Drago Trials",
		Default = false,
		Callback = function(s) V.TpTrial = s setActive("V_TpTrial", s) end
	})
	DragoGroup:AddButton({
		Text = "Swap to Drago Race",
		Callback = function()
			task.spawn(function()
				setActive("V_Btn2", true)
				move(DOJO, true, 25)
				pcall(function()
					Net["RF/InteractDragonQuest"]:InvokeServer({NPC = "Dragon Wizard", Command = "DragonRace"})
				end)
				setActive("V_Btn2", false)
			end)
		end
	})
	DragoGroup:AddButton({
		Text = "Upgrade Drago Trial",
		Callback = function()
			task.spawn(function()
				setActive("V_Btn3", true)
				move(DOJO, true, 25)
				pcall(function()
					Net["RF/InteractDragonQuest"]:InvokeServer({NPC = "Dragon Wizard", Command = "Upgrade"})
				end)
				setActive("V_Btn3", false)
			end)
		end
	})
	DragoGroup:AddButton({
		Text = "Upgrade Dragon Talon (Uzoth)",
		Callback = function()
			task.spawn(function()
				setActive("V_Btn4", true)
				local uz = CFrame.new(5661.89014, 1211.31909, 864.836731)
				move(uz, true, 25)
				pcall(function()
					Net["RF/InteractDragonQuest"]:InvokeServer({NPC = "Uzoth", Command = "Upgrade"})
				end)
				setActive("V_Btn4", false)
			end)
		end
	})

	-- ===== Crafting + settings =====
	local CraftGroup = VolcanoTab:AddGroup("Right", "Volcanic Crafting / Settings")
	local function craftBtn(text, item)
		CraftGroup:AddButton({
			Text = text,
			Callback = function()
				pcall(function() CommF_:InvokeServer("CraftItem", "Craft", item) end)
			end
		})
	end
	craftBtn("Craft Dragonheart", "Dragonheart")
	craftBtn("Craft Dragonstorm", "Dragonstorm")
	craftBtn("Craft Dino Hood", "DinoHood")
	craftBtn("Craft T-Rex Skull", "TRexSkull")

	CraftGroup:AddDropdown({
		Text = "Weapon Type",
		Options = {"Melee", "Sword", "Blox Fruit", "Gun"},
		Default = "Melee",
		Callback = function(s) Cfg.WeaponType = s end
	})
	CraftGroup:AddSlider({
		Text = "Tween Speed", Suffix = "", Min = 50, Max = 400, Step = 5, Decimals = 0, Default = 220,
		Callback = function(v) Cfg.Speed = v end
	})
	CraftGroup:AddSlider({
		Text = "Farm Height", Suffix = " studs", Min = 0, Max = 60, Step = 1, Decimals = 0, Default = 30,
		Callback = function(v) Cfg.Height = v end
	})

	-- ===== Volcano loops =====
	loop(0.3, function()
		if V.Find then findPrehistoric() end
		if V.Start and location("Prehistoric Island") then startEvent() end
		if V.Patch then patchEvent() end
		if V.Bones then collectBones() end
		if V.Eggs then collectEggs() end
		if V.Ember then
			local et = workspace:FindFirstChild("EmberTemplate")
			local part = et and et:FindFirstChild("Part")
			if part then notween(part.CFrame) end
		end
		if V.Reset then
			local p = prehistoric()
			local trial = p and p:FindFirstChild("TrialTeleport")
			if trial and trial:FindFirstChild("TouchInterest") then
				local hum = getHum()
				if hum then hum.Health = 0 end
			else
				collectBones()
			end
		end
	end)

	loop(2, function()
		if not V.KillAura then return end
		local root = getRoot()
		if not root then return end
		if sethiddenproperty then pcall(function() sethiddenproperty(plr, "SimulationRadius", math.huge) end) end
		local f = enemyFolder()
		if not f then return end
		for _, e in ipairs(f:GetChildren()) do
			local hum = e:FindFirstChildOfClass("Humanoid")
			local hrp = e:FindFirstChild("HumanoidRootPart")
			if hum and hrp and hum.Health > 0 and (hrp.Position - root.Position).Magnitude <= 500 then
				pcall(function()
					hum.Health = 0
					hrp.CanCollide = false
					e:BreakJoints()
				end)
			end
		end
	end)

	loop(0.4, function()
		if not V.Dojo then return end
		local rf = Net:FindFirstChild("RF/InteractDragonQuest")
		if not rf then return end
		local res = rf:InvokeServer({NPC = "Dojo Trainer", Command = "RequestQuest"})
		local belt = type(res) == "table" and res.Quest and res.Quest.BeltName
		if not belt then
			move(DOJO_NPC, false)
			rf:InvokeServer({NPC = "Dojo Trainer", Command = "ClaimQuest"})
			return
		end
		if belt == "White" then
			local e = getEnemy("Skull Slayer")
			if e then kill(e) else move(CFrame.new(-16759.58984375, 71.283767700195312, 1595.3399658203125), false) end
		elseif belt == "Purple" then
			local vis, title = questTitle()
			if not vis then
				CommF_:InvokeServer("EliteHunter")
			else
				local boss
				for _, n in ipairs({"Diablo", "Urban", "Deandre"}) do
					if string.find(title, n) then boss = n break end
				end
				local e = boss and (getEnemy(boss) or getRepEnemy(boss))
				if e then kill(e) end
			end
		elseif belt == "Black" then
			findPrehistoric()
			if location("Prehistoric Island") then
				startEvent()
				patchEvent()
			end
		else -- Yellow / Green / Red: sea content
			sailTo(OPEN_SEA)
			local e = getEnemy({"Terrorshark", "Shark", "Piranha", "Fish Crew Member", "Haunted Crew Member"})
			if e then kill(e) elseif not killSeaBeast() then
				local f = enemyFolder()
				if f then
					for _, b in ipairs(f:GetChildren()) do
						local h = b:FindFirstChild("Health")
						local eng = b:FindFirstChild("Engine")
						if h and h.Value > 0 and eng then
							move(eng.CFrame * CFrame.new(0, -40, -20), false)
							skillBurst()
							break
						end
					end
				end
			end
		end
	end)

	loop(0.4, function()
		if not V.Hunter then return end
		local rf = Net:FindFirstChild("RF/DragonHunter")
		if not rf then return end
		pcall(function() rf:InvokeServer({Context = "RequestQuest"}) end)
		local res = rf:InvokeServer({Context = "Check"})
		local text = type(res) == "table" and res.Text or nil
		if not text then
			move(CFrame.new(5813, 1208, 884), false)
			return
		end
		if string.find(text, "Defeat") then
			local mob = string.find(text, "Hydra Enforcer") and "Hydra Enforcer" or "Venomous Assailant"
			local e = getEnemy(mob)
			if e then kill(e) else move(CFrame.new(4620.61572265625, 1002.2954711914062, 399.08688354492188), false) end
		elseif string.find(text, "Destroy") then
			local map = mapFolder()
			local wf = map and map:FindFirstChild("Waterfall")
			local im = wf and wf:FindFirstChild("IslandModel")
			local tree = im and im:FindFirstChild("Meshes/bambootree", true)
			if tree then
				move(tree.CFrame * CFrame.new(4, 0, 0), false)
				skillBurst()
			end
		end
	end)

	loop(0.4, function()
		if V.DragoV1 then
			if getMaterial("Dragon Egg") >= 1 then return end
			findPrehistoric()
			if location("Prehistoric Island") then
				startEvent()
				patchEvent()
				collectEggs()
			end
		end
		if V.DragoV2 then
			local flowers = workspace:FindFirstChild("FireFlowers")
			if flowers then
				for _, f in ipairs(flowers:GetChildren()) do
					if f:IsA("Model") and f.PrimaryPart then
						move(f.PrimaryPart.CFrame, false)
						pressKey("E", 1.5)
						break
					end
				end
			else
				local e = getEnemy("Forest Pirate")
				if e then kill(e) else move(CFrame.new(-13206.452148438, 425.89199829102, -7964.5537109375), false) end
			end
		end
		if V.DragoV3 then
			local e = getEnemy("Terrorshark")
			if e then
				local hrp = e.HumanoidRootPart
				move(hrp.CFrame * CFrame.new(0, 60, 0), false)
				skillBurst()
				attack()
			else
				sailTo(OPEN_SEA)
			end
		end
		if V.TpTrial then
			local p = prehistoric()
			local tt = p and p:FindFirstChild("TrialTeleport")
			if tt and tt:IsA("BasePart") then move(tt.CFrame, false) end
		end
	end)

	loop(0.5, function()
		if not V.Relic then return end
		local map = mapFolder()
		if not map or not map:FindFirstChild("DracoTrial") then
			local p = prehistoric()
			local tt = p and p:FindFirstChild("TrialTeleport")
			if tt and tt:IsA("BasePart") then move(tt.CFrame, false) end
			return
		end
		pcall(function() ReplicatedStorage.Remotes.DracoTrial:InvokeServer() end)
		task.wait(0.5)
		local points = {
			CFrame.new(-39934.9765625, 10685.359375, 22999.34375),
			CFrame.new(-40511.25390625, 9376.4013671875, 23458.37890625),
			CFrame.new(-39914.65625, 10685.384765625, 23000.177734375),
			CFrame.new(-40045.83203125, 9376.3984375, 22791.287109375),
			CFrame.new(-39908.5, 10685.4052734375, 22990.04296875),
			CFrame.new(-39609.5, 9376.400390625, 23472.94335975),
		}
		for i, cf in ipairs(points) do
			if not V.Relic then break end
			move(cf, true, 25)
			if i % 2 == 0 then task.wait(2.5) end
		end
	end)

	loop(0.3, function()
		if not V.TrainV4 then return end
		local char = plr.Character
		if not char then return end
		local energy = char:FindFirstChild("RaceEnergy")
		if energy and energy.Value == 1 then
			pressKey("Y")
			pcall(function() CommF_:InvokeServer("UpgradeRace", "Buy", 2) end)
			move(CFrame.new(4620.61572265625, 1002.2954711914062, 399.08688354492188), false)
			return
		end
		local e = getEnemy({"Venomous Assailant", "Hydra Enforcer"})
		if e then kill(e) else move(CFrame.new(4620.61572265625, 1002.2954711914062, 399.08688354492188), false) end
	end)

	-- boat noclip while sailing
	loop(0.5, function()
		local sailing = V.Find or V.DragoV3 or V.DragoV1 or V.Dojo
		local boats = workspace:FindFirstChild("Boats")
		if not boats then return end
		for _, b in ipairs(boats:GetChildren()) do
			for _, d in ipairs(b:GetDescendants()) do
				if d:IsA("BasePart") then
					pcall(function() d.CanCollide = not sailing end)
				end
			end
		end
	end)

	-- =========================================================
	-- MIRAGE & RACE TAB
	-- =========================================================
	local RaceTab = Window:CreateTab({ Name = "Mirage & Race", Icon = "race" })

	local M = {
		FindMirage = false, TweenMirage = false, Highest = false, Gear = false, Reveal = false,
		Chests = false, Dealer = false, LookMoon = false, MoonV3 = false,
		Mink = false, Human = false, Angel = false, Fish = false,
		Lever = false, TrainV4 = false, Doors = false, Trial = false, KillAfter = false,
	}

	local function mystic() local m = mapFolder() return m and m:FindFirstChild("MysticIsland") end
	local MOON_IDS = {
		["9709135895"] = "0/8", ["9709139597"] = "1/8", ["9709143733"] = "2/8",
		["9709149052"] = "3/8 (next night)", ["9709149431"] = "4/8 FULL MOON",
		["9709149680"] = "5/8 (last night)", ["9709150086"] = "6/8", ["9709150401"] = "7/8",
	}
	local function moonPhase()
		local sky = Lighting:FindFirstChild("Sky") or Lighting:FindFirstChild("FantasySky")
		if not sky then return "unknown" end
		local id = tostring(sky.MoonTextureId):match("%d+")
		return id and (MOON_IDS[id] or "unknown") or "unknown"
	end
	local function lookAtMoon()
		local cam = workspace.CurrentCamera
		local dir = Lighting:GetMoonDirection()
		cam.CFrame = CFrame.new(cam.CFrame.Position, cam.CFrame.Position + dir)
		local root = getRoot()
		if root then root.CFrame = CFrame.new(root.Position, root.Position + dir) end
	end
	local function nearestChest(filterFolder)
		local root = getRoot()
		if not root then return nil end
		local best, bestDist
		for _, c in ipairs(CollectionService:GetTagged("_ChestTagged")) do
			if not c:GetAttribute("IsDisabled") and (not filterFolder or c:IsDescendantOf(filterFolder)) then
				local ok, pos = pcall(function() return c:GetPivot().Position end)
				if ok then
					local d = (pos - root.Position).Magnitude
					if not bestDist or d < bestDist then best, bestDist = c, d end
				end
			end
		end
		return best
	end

	-- ===== Mirage group =====
	local MirageGroup = RaceTab:AddGroup("Left", "Mirage Island")

	MirageGroup:AddToggle({
		Text = "Auto Find Mirage Island",
		Desc = "Buys boat + sails until Mirage spawns",
		Default = false,
		Callback = function(s) M.FindMirage = s setActive("M_Find", s) end
	})
	MirageGroup:AddToggle({
		Text = "Tween to Mirage Island",
		Default = false,
		Callback = function(s) M.TweenMirage = s setActive("M_Tween", s) end
	})
	MirageGroup:AddToggle({
		Text = "Tween to Highest Point",
		Default = false,
		Callback = function(s) M.Highest = s setActive("M_High", s) end
	})
	MirageGroup:AddToggle({
		Text = "Auto Collect Gear",
		Default = false,
		Callback = function(s) M.Gear = s setActive("M_Gear", s) end
	})
	MirageGroup:AddToggle({
		Text = "Reveal Gears (Transparency)",
		Default = false,
		Callback = function(s) M.Reveal = s end
	})
	MirageGroup:AddToggle({
		Text = "Auto Mirage Chests",
		Default = false,
		Callback = function(s) M.Chests = s setActive("M_Chest", s) end
	})
	MirageGroup:AddToggle({
		Text = "Tween Advanced Fruit Dealer",
		Default = false,
		Callback = function(s) M.Dealer = s setActive("M_Dealer", s) end
	})
	MirageGroup:AddButton({
		Text = "Print Mirage / Moon Status",
		Callback = function()
			print("[Mirage] Spawned:", location("Mirage Island") ~= nil, "| Moon:", moonPhase(), "| Race:", raceName())
		end
	})
	MirageGroup:AddButton({
		Text = "Talk With Stone",
		Primary = true,
		Callback = function()
			pcall(function()
				CommF_:InvokeServer("RaceV4Progress", "Begin")
				CommF_:InvokeServer("RaceV4Progress", "Check")
				CommF_:InvokeServer("RaceV4Progress", "Teleport")
			end)
		end
	})

	-- ===== Moon group =====
	local MoonGroup = RaceTab:AddGroup("Left", "Moon / Race V3")

	MoonGroup:AddToggle({
		Text = "Auto Look At Moon",
		Default = false,
		Callback = function(s) M.LookMoon = s setActive("M_Moon", s) end
	})
	MoonGroup:AddToggle({
		Text = "Look Moon + Auto V3",
		Desc = "Looks at moon and activates race ability",
		Default = false,
		Callback = function(s) M.MoonV3 = s setActive("M_MoonV3", s) end
	})

	-- ===== Race V2/V3 =====
	local UpgradeGroup = RaceTab:AddGroup("Right", "Race V2 / V3 Upgrades")

	local function addRaceToggle(text, key, desc)
		UpgradeGroup:AddToggle({
			Text = text, Desc = desc, Default = false,
			Callback = function(s) M[key] = s setActive("M_" .. key, s) end
		})
	end
	addRaceToggle("Auto Upgrade Mink", "Mink", "Flowers V2 + chests V3")
	addRaceToggle("Auto Upgrade Human", "Human", "Flowers V2 + Fajita/Jeremy/Diamond")
	addRaceToggle("Auto Upgrade Angel", "Angel", "Flowers V2 + Skypiea player")
	addRaceToggle("Auto Upgrade Fishman", "Fish", "Flowers V2 + Sea Beast")

	-- ===== V4 Trials =====
	local TrialGroup = RaceTab:AddGroup("Right", "Race V4 Trials")

	TrialGroup:AddToggle({
		Text = "Auto Pull Lever",
		Default = false,
		Callback = function(s) M.Lever = s end
	})
	TrialGroup:AddToggle({
		Text = "Auto Train V4",
		Desc = "Bone mobs + transform + UpgradeRace",
		Default = false,
		Callback = function(s) M.TrainV4 = s setActive("M_Train4", s) end
	})
	TrialGroup:AddToggle({
		Text = "Auto Teleport to Race Doors",
		Default = false,
		Callback = function(s) M.Doors = s setActive("M_Doors", s) end
	})
	TrialGroup:AddToggle({
		Text = "Auto Complete Trial",
		Default = false,
		Callback = function(s) M.Trial = s setActive("M_Trial", s) end
	})
	TrialGroup:AddToggle({
		Text = "Auto Kill Player After Trial",
		Danger = true,
		Default = false,
		Callback = function(s) M.KillAfter = s setActive("M_KillAfter", s) end
	})
	TrialGroup:AddButton({
		Text = "TP Temple of Time",
		Callback = function() goButton(CFrame.new(-7754.033203125, 2998.953857421875, -404.75357055664062)) end
	})
	TrialGroup:AddButton({
		Text = "TP Ancient One",
		Callback = function() goButton(CFrame.new(-5071.541015625, 314.5412902832, -3151.1098632812)) end
	})
	TrialGroup:AddButton({
		Text = "TP Ancient Clock",
		Callback = function() goButton(CFrame.new(-12471.169921875, 374.94024658203, -7551.677734375)) end
	})

	-- ===== Mirage loops =====
	loop(0.3, function()
		if M.FindMirage then
			local loc = location("Mirage Island")
			local mi = mystic()
			if loc and mi and mi:FindFirstChild("Center") then
				move(mi.Center.CFrame * CFrame.new(0, 300, 0), false)
			else
				sailTo(OPEN_SEA)
			end
		end
		if M.TweenMirage then
			local loc = location("Mirage Island")
			if loc then move(loc.CFrame * CFrame.new(0, 333, 0), false) end
		end
		if M.Highest then
			local mi = mystic()
			if mi and mi:FindFirstChild("Center") then
				move(mi.Center.CFrame * CFrame.new(0, 400, 0), false)
			end
		end
		if M.Gear then
			local mi = mystic()
			if mi then
				for _, c in ipairs(mi:GetChildren()) do
					if c.Name == "Part" and (c:IsA("MeshPart") or (c:IsA("BasePart") and c.Material == Enum.Material.Neon)) then
						move(c.CFrame, false)
						break
					end
				end
			end
		end
		if M.Chests then
			local mi = mystic()
			local chest = nearestChest(mi)
			if chest then
				local ok, pivot = pcall(function() return chest:GetPivot() end)
				if ok then move(pivot, false) end
			end
		end
		if M.Dealer then
			local npcs = ReplicatedStorage:FindFirstChild("NPCs")
			local d = npcs and npcs:FindFirstChild("Advanced Fruit Dealer")
			if d and d:FindFirstChild("HumanoidRootPart") then move(d.HumanoidRootPart.CFrame, false) end
		end
	end)

	loop(0.2, function()
		if M.LookMoon then lookAtMoon() end
		if M.MoonV3 then
			lookAtMoon()
			pcall(function() CommE:FireServer("ActivateAbility") end)
			pressKey("T", 0.5)
		end
		if M.Reveal then
			local mi = mystic()
			if mi then
				for _, c in ipairs(mi:GetChildren()) do
					if c.Name == "Part" and c:IsA("BasePart") then
						pcall(function() c.Transparency = c:IsA("MeshPart") and 0 or 1 end)
					end
				end
			end
		end
	end)

	-- ===== Race V2/V3 logic =====
	local function flowerStage()
		-- returns true when the flower quest stage is handled
		local state = CommF_:InvokeServer("Alchemist", "1")
		if state == 0 then
			CommF_:InvokeServer("Alchemist", "2")
			return true
		elseif state == 1 then
			local has = function(n) return plr.Backpack:FindFirstChild(n) or (plr.Character and plr.Character:FindFirstChild(n)) end
			if not has("Flower 1") then
				local f = workspace:FindFirstChild("Flower1")
				if f then move(f.CFrame, false) end
			elseif not has("Flower 2") then
				local f = workspace:FindFirstChild("Flower2")
				if f then move(f.CFrame, false) end
			elseif not has("Flower 3") then
				local e = getEnemy("Swan Pirate")
				if e then kill(e) else move(CFrame.new(980.0985107421875, 121.331298828125, 1287.2093505859375), false) end
			end
			return true
		elseif state == 2 then
			CommF_:InvokeServer("Alchemist", "3")
			return true
		end
		return false
	end

	local function raceV3(key)
		local state = CommF_:InvokeServer("Wenlocktoad", "1")
		if state == 0 then
			CommF_:InvokeServer("Wenlocktoad", "2")
			return
		end
		if key == "Mink" then
			local chest = nearestChest(nil)
			if chest then
				local ok, pivot = pcall(function() return chest:GetPivot() end)
				if ok then move(pivot, false) end
			end
		elseif key == "Human" then
			for _, n in ipairs({"Fajita", "Jeremy", "Diamond"}) do
				local e = getEnemy(n)
				if e then kill(e) return end
			end
			move(CFrame.new(-2172.7399902344, 103.32216644287, -4015.025390625), false)
		elseif key == "Angel" then
			local chars = workspace:FindFirstChild("Characters")
			if not chars then return end
			for _, c in ipairs(chars:GetChildren()) do
				if c.Name ~= plr.Name and alive(c) and c:FindFirstChild("HumanoidRootPart") then
					local p = Players:FindFirstChild(c.Name)
					local ok, r = pcall(function() return tostring(p.Data.Race.Value) end)
					if ok and r == "Skypiea" then
						equipType(Cfg.WeaponType)
						move(c.HumanoidRootPart.CFrame * CFrame.new(0, 8, 0), false)
						attack(true)
						return
					end
				end
			end
		elseif key == "Fish" then
			if not killSeaBeast() then sailTo(OPEN_SEA) end
		end
	end

	loop(0.4, function()
		for _, key in ipairs({"Mink", "Human", "Angel", "Fish"}) do
			if M[key] then
				if not flowerStage() then raceV3(key) end
				break
			end
		end
	end)

	-- ===== V4 loops =====
	local RACE_DOORS = {
		Mink = CFrame.new(29020.66015625, 14889.4267578125, -379.26828002929688),
		Fishman = CFrame.new(28224.056640625, 14889.4267578125, -210.58720397949219),
		Cyborg = CFrame.new(28492.4140625, 14894.4267578125, -422.11001586914062),
		Skypiea = CFrame.new(28967.408203125, 14918.0751953125, 234.31198120117188),
		Ghoul = CFrame.new(28672.720703125, 14889.1279296875, 454.59616088867188),
		Human = CFrame.new(29237.294921875, 14889.4267578125, -206.94955444335938),
	}

	loop(0.4, function()
		if M.Lever then
			local map = mapFolder()
			local temple = map and map:FindFirstChild("Temple of Time")
			if temple then
				for _, d in ipairs(temple:GetDescendants()) do
					if d:IsA("ProximityPrompt") then prompt(d) end
				end
			end
		end
		if M.Doors then
			local cf = RACE_DOORS[raceName()]
			if cf then move(cf, false) end
		end
		if M.TrainV4 then
			local char = plr.Character
			local energy = char and char:FindFirstChild("RaceEnergy")
			if energy and energy.Value == 1 then
				pressKey("Y")
				pcall(function() CommF_:InvokeServer("UpgradeRace", "Buy") end)
				move(CFrame.new(-8987.041015625, 215.862060546875, 5886.71044921875), false)
				return
			end
			local e = getEnemy({"Reborn Skeleton", "Living Zombie", "Demonic Soul", "Posessed Mummy"})
			if e then kill(e) else move(CFrame.new(-9495.6806640625, 453.58624267578125, 5977.3486328125), false) end
		end
	end)

	loop(0.3, function()
		if not M.Trial then return end
		local race = raceName()
		local map = mapFolder()
		if not map then return end
		if race == "Mink" then
			local t = map:FindFirstChild("MinkTrial")
			if t and t:FindFirstChild("Ceiling") then notween(t.Ceiling.CFrame * CFrame.new(0, -20, 0)) end
		elseif race == "Cyborg" then
			local t = map:FindFirstChild("CyborgTrial")
			if t and t:FindFirstChild("Floor") then move(t.Floor.CFrame * CFrame.new(0, 500, 0), false) end
		elseif race == "Skypiea" then
			local t = map:FindFirstChild("SkyTrial")
			local fin = t and t:FindFirstChild("Model") and t.Model:FindFirstChild("FinishPart")
			if fin then notween(fin.CFrame) end
		elseif race == "Fishman" then
			if not killSeaBeast() then
				local loc = location("Trial of Water")
				if loc then move(loc.CFrame * CFrame.new(0, 200, 0), false) end
			end
		elseif race == "Human" or race == "Ghoul" then
			local e = getEnemy({"Ancient Vampire", "Ancient Zombie"})
			if e then kill(e) end
		end
	end)

	loop(0.2, function()
		if not M.KillAfter then return end
		local root = getRoot()
		local chars = workspace:FindFirstChild("Characters")
		if not root or not chars then return end
		if sethiddenproperty then pcall(function() sethiddenproperty(plr, "SimulationRadius", math.huge) end) end
		for _, c in ipairs(chars:GetChildren()) do
			if c.Name ~= plr.Name and alive(c) and c:FindFirstChild("HumanoidRootPart") then
				if (c.HumanoidRootPart.Position - root.Position).Magnitude <= 250 then
					equipType(Cfg.WeaponType)
					move(c.HumanoidRootPart.CFrame * CFrame.new(0, 0, 15), false)
					attack(true)
					return
				end
			end
		end
	end)
end

-- // ================= INFO & STATUS TAB =================
do
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Lighting = game:GetService("Lighting")
	local LocalizationService = game:GetService("LocalizationService")
	local UserInputService = game:GetService("UserInputService")
	local Stats = game:GetService("Stats")

	local plr = Players.LocalPlayer
	local CommF_ = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_")

	local W1 = game.PlaceId == 2753915549 or game.PlaceId == 85211729168715
	local W2 = game.PlaceId == 4442272183 or game.PlaceId == 79091703265657
	local W3 = game.PlaceId == 7449423635 or game.PlaceId == 100117331123089

	local Cfg = {Rate = 1, RemoteRate = 5, Remote = true, Width = 300, TextSize = 13, Trans = 15, Side = "Left"}

	local InfoTab = Window:CreateTab({ Name = "Info", Icon = "info" }) -- swap icon if unsupported

	-- ===== helpers =====
	local function locations()
		local o = workspace:FindFirstChild("_WorldOrigin")
		return o and o:FindFirstChild("Locations")
	end
	local function hasLoc(name)
		local l = locations()
		return l ~= nil and l:FindFirstChild(name) ~= nil
	end
	local function hasMap(name)
		local m = workspace:FindFirstChild("Map")
		return m ~= nil and m:FindFirstChild(name) ~= nil
	end
	local function yesNo(b) return b and "Yes" or "No" end

	local region
	task.spawn(function()
		local ok, r = pcall(function() return LocalizationService:GetCountryRegionForPlayerAsync(plr) end)
		region = ok and r or "Unknown"
	end)

	local function realTime()
		local t = os.date("*t")
		local h = t.hour % 12
		if h == 0 then h = 12 end
		return string.format("%02d/%02d/%04d %02d:%02d:%02d %s [%s]",
			t.day, t.month, t.year, h, t.min, t.sec, t.hour < 12 and "AM" or "PM", region or "...")
	end

	local function gameTime()
		local s = math.floor(workspace.DistributedGameTime + 0.5)
		return string.format("%dh %dm %ds", math.floor(s / 3600) % 24, math.floor(s / 60) % 60, s % 60)
	end

	local MOON = {
		["9709135895"] = "0/8", ["9709139597"] = "1/8", ["9709143733"] = "2/8",
		["9709149052"] = "3/8 (next night)", ["9709149431"] = "4/8 FULL MOON",
		["9709149680"] = "5/8 (last night)", ["9709150086"] = "6/8", ["9709150401"] = "7/8",
	}
	local function moonPhase()
		local sky = Lighting:FindFirstChild("Sky") or Lighting:FindFirstChild("FantasySky")
		if not sky then return "unknown" end
		local id = tostring(sky.MoonTextureId):match("%d+")
		return id and (MOON[id] or "unknown") or "unknown"
	end

	local function bossExists(names)
		if type(names) == "string" then names = {names} end
		local e = workspace:FindFirstChild("Enemies")
		for _, n in ipairs(names) do
			if ReplicatedStorage:FindFirstChild(n) or (e and e:FindFirstChild(n)) then return true end
		end
		return false
	end

	local function cakeStatus()
		local ok, res = pcall(function() return CommF_:InvokeServer("CakePrinceSpawner") end)
		if not ok then return "error" end
		local n = type(res) == "string" and string.match(res, "%d+")
		if n then return string.format("Killed %d / 500", 500 - tonumber(n)) end
		return "Ready / spawned"
	end

	local function legendarySword()
		for i, name in ipairs({"Shisui", "Wando", "Saddi"}) do
			local ok, res = pcall(function() return CommF_:InvokeServer("LegendarySwordDealer", tostring(i)) end)
			if ok and res then return name .. " in stock" end
		end
		return "Not found"
	end

	local function boneCount()
		local ok, res = pcall(function() return CommF_:InvokeServer("Bones", "Check") end)
		return ok and tostring(res or 0) .. " bones" or "error"
	end

	local function ping()
		local ok, v = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValueString() end)
		return ok and v or "?"
	end

	-- ===== readout definitions (slow = uses remotes, throttled) =====
	local defs = {
		{name = "Time", get = realTime},
		{name = "Server Uptime", get = gameTime},
		{name = "Players", get = function() return #Players:GetPlayers() .. " / " .. Players.MaxPlayers end},
		{name = "Ping", get = ping},
		{name = "Sea", get = function() return W1 and "1 - East Blue" or W2 and "2 - Dressrosa" or W3 and "3 - Zou" or "?" end},
		{name = "Mirage Island", get = function() return yesNo(hasLoc("Mirage Island")) end},
		{name = "Kitsune Island", get = function() return yesNo(hasMap("KitsuneIsland") or hasLoc("Kitsune Island")) end},
		{name = "Prehistoric Island", get = function() return yesNo(hasLoc("Prehistoric Island") or hasMap("PrehistoricIsland")) end},
		{name = "Frozen Dimension", get = function() return yesNo(hasLoc("Frozen Dimension")) end},
		{name = "Full Moon", get = moonPhase},
		{name = "Elite Boss", get = function() return yesNo(bossExists({"Diablo", "Deandre", "Urban"})) end},
		{name = "Rip Indra", get = function() return yesNo(bossExists({"rip_indra", "rip_indra True Form"})) end},
		{name = "Dough King", get = function() return yesNo(bossExists("Dough King")) end},
		{name = "Tyrant of the Skies", get = function() return yesNo(bossExists("Tyrant of the Skies")) end},
		{name = "Cake Prince", get = cakeStatus, slow = true},
		{name = "Legendary Sword", get = legendarySword, slow = true},
		{name = "Bones", get = boneCount, slow = true},
	}

	-- ===== panel =====
	local gui = Instance.new("ScreenGui")
	gui.Name = "PatronsStatus"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	gui.Enabled = false
	gui.Parent = (gethui and gethui()) or plr:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.BackgroundColor3 = Color3.fromRGB(16, 16, 16)
	frame.BackgroundTransparency = Cfg.Trans / 100
	frame.BorderSizePixel = 0
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.Size = UDim2.fromOffset(Cfg.Width, 0)
	frame.Position = UDim2.new(0, 12, 0, 120)
	frame.Active = true
	frame.Parent = gui

	local corner = Instance.new("UICorner", frame)
	corner.CornerRadius = UDim.new(0, 6)
	local stroke = Instance.new("UIStroke", frame)
	stroke.Color = Color3.fromRGB(70, 70, 70)
	stroke.Thickness = 1
	local pad = Instance.new("UIPadding", frame)
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	local list = Instance.new("UIListLayout", frame)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 2)

	local header = Instance.new("TextLabel")
	header.Name = "Header"
	header.LayoutOrder = 0
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, 20)
	header.Font = Enum.Font.GothamBold
	header.TextSize = 14
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.TextColor3 = Color3.fromRGB(255, 255, 255)
	header.Text = "STATUS  -  drag to move"
	header.Parent = frame

	for i, r in ipairs(defs) do
		local l = Instance.new("TextLabel")
		l.Name = r.name
		l.LayoutOrder = i
		l.BackgroundTransparency = 1
		l.Size = UDim2.new(1, 0, 0, Cfg.TextSize + 6)
		l.Font = Enum.Font.Code
		l.TextSize = Cfg.TextSize
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextColor3 = Color3.fromRGB(235, 235, 235)
		l.RichText = true
		l.Text = '<font color="#8ab4f8">' .. r.name .. '</font>: ...'
		l.Parent = frame
		r.label = l
		r.value = "..."
	end

	-- dragging
	local dragging, dragStart, startPos = false, nil, nil
	frame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging, dragStart, startPos = true, input.Position, frame.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - dragStart
			frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)

	local function applySide()
		if Cfg.Side == "Left" then
			frame.Position = UDim2.new(0, 12, 0, 120)
		else
			frame.Position = UDim2.new(1, -Cfg.Width - 12, 0, 120)
		end
	end

	-- ===== refresh =====
	local function setRow(r)
		local ok, v = pcall(r.get)
		r.value = ok and tostring(v) or "error"
		if r.label then
			r.label.Text = '<font color="#8ab4f8">' .. r.name .. '</font>: ' .. r.value
		end
	end
	local function refresh(all)
		for _, r in ipairs(defs) do
			if all or not r.slow then setRow(r) end
		end
	end
	local function statusText(filter)
		local lines = {"=== Status ==="}
		for _, r in ipairs(defs) do
			if not filter or table.find(filter, r.name) then
				table.insert(lines, r.name .. ": " .. (r.value or "?"))
			end
		end
		return table.concat(lines, "\n")
	end

	task.spawn(function()
		local lastSlow = 0
		while true do
			if gui.Enabled then
				refresh(false)
				if Cfg.Remote and os.clock() - lastSlow >= Cfg.RemoteRate then
					lastSlow = os.clock()
					for _, r in ipairs(defs) do
						if r.slow then setRow(r) end
					end
				end
			end
			task.wait(Cfg.Rate)
		end
	end)

	-- ===== UI =====
	local PanelGroup = InfoTab:AddGroup("Left", "Status Panel")

	PanelGroup:AddToggle({
		Text = "Show Status Panel",
		Desc = "Live readouts on screen (drag to move)",
		Default = true,
		Callback = function(state)
			gui.Enabled = state
			if state then refresh(true) end
		end
	})
	gui.Enabled = true
	task.spawn(function() refresh(true) end)

	PanelGroup:AddDropdown({
		Text = "Panel Side",
		Options = {"Left", "Right"},
		Default = "Left",
		Callback = function(selected)
			Cfg.Side = selected
			applySide()
		end
	})

	PanelGroup:AddSlider({
		Text = "Panel Width", Suffix = " px", Min = 220, Max = 460, Step = 10, Decimals = 0, Default = 300,
		Callback = function(v)
			Cfg.Width = v
			frame.Size = UDim2.fromOffset(v, 0)
		end
	})
	PanelGroup:AddSlider({
		Text = "Text Size", Suffix = "", Min = 10, Max = 20, Step = 1, Decimals = 0, Default = 13,
		Callback = function(v)
			Cfg.TextSize = v
			for _, r in ipairs(defs) do
				if r.label then
					r.label.TextSize = v
					r.label.Size = UDim2.new(1, 0, 0, v + 6)
				end
			end
		end
	})
	PanelGroup:AddSlider({
		Text = "Background Transparency", Suffix = "%", Min = 0, Max = 100, Step = 5, Decimals = 0, Default = 15,
		Callback = function(v) frame.BackgroundTransparency = v / 100 end
	})
	PanelGroup:AddButton({
		Text = "Reset Panel Position",
		Callback = function() applySide() end
	})

	local RefreshGroup = InfoTab:AddGroup("Left", "Refresh")

	RefreshGroup:AddSlider({
		Text = "Update Rate", Suffix = " s", Min = 0.5, Max = 5, Step = 0.5, Decimals = 1, Default = 1,
		Callback = function(v) Cfg.Rate = v end
	})
	RefreshGroup:AddToggle({
		Text = "Remote Readouts",
		Desc = "Cake Prince / Legendary Sword / Bones",
		Default = true,
		Callback = function(state) Cfg.Remote = state end
	})
	RefreshGroup:AddSlider({
		Text = "Remote Refresh", Suffix = " s", Min = 3, Max = 30, Step = 1, Decimals = 0, Default = 5,
		Callback = function(v) Cfg.RemoteRate = v end
	})

	local OutGroup = InfoTab:AddGroup("Right", "Console / Clipboard")

	local function printBtn(text, filter)
		OutGroup:AddButton({
			Text = text,
			Callback = function()
				task.spawn(function()
					refresh(true)
					print(statusText(filter))
				end)
			end
		})
	end

	printBtn("Print Full Status", nil)
	printBtn("Print Islands", {"Mirage Island", "Kitsune Island", "Prehistoric Island", "Frozen Dimension"})
	printBtn("Print Bosses", {"Elite Boss", "Rip Indra", "Dough King", "Tyrant of the Skies", "Cake Prince"})
	printBtn("Print Moon / Sword / Bones", {"Full Moon", "Legendary Sword", "Bones"})

	OutGroup:AddButton({
		Text = "Copy Full Status",
		Primary = true,
		Callback = function()
			task.spawn(function()
				refresh(true)
				if setclipboard then setclipboard(statusText(nil)) end
			end)
		end
	})

	local ExtraGroup = InfoTab:AddGroup("Right", "Extra Readouts")

	ExtraGroup:AddButton({
		Text = "Print Elite / Eyes / Race",
		Callback = function()
			task.spawn(function()
				local ok1, elite = pcall(function() return CommF_:InvokeServer("EliteHunter", "Progress") end)
				local ok2, eyes = pcall(function()
					local m = workspace.Map.TikiOutpost.IslandModel
					local c = 0
					for _, e in ipairs({m.Eye1, m.Eye2, m.IslandChunks.E.Eye3, m.IslandChunks.E.Eye4}) do
						if e and e.Transparency ~= 1 then c = c + 1 end
					end
					return c
				end)
				local ok3, tier = pcall(function() return plr.Data.Race.C.Value end)
				local ok4, race = pcall(function() return tostring(plr.Data.Race.Value) end)
				print("[Elite] Killed:", ok1 and elite or "?")
				print("[TOTS] Eyes:", ok2 and eyes or "?", "/4")
				print("[Race]", ok4 and race or "?", "| V4 Tiers:", ok3 and tier or "?")
			end)
		end
	})
	ExtraGroup:AddButton({
		Text = "Print Current Area",
		Callback = function()
			local l = locations()
			local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
			if not l or not root then return end
			local best, bd
			for _, loc in ipairs(l:GetChildren()) do
				if loc:IsA("BasePart") and loc.Name ~= "Sea" then
					local d = (loc.Position - root.Position).Magnitude
					if not bd or d < bd then best, bd = loc.Name, d end
				end
			end
			print("[Area]", best or "?", "| Distance:", bd and math.floor(bd / 3) .. " M" or "?")
		end
	})
end


-- // ================= FARMING TAB — FULL EXPANSION =================
do
	local Players = game:GetService("Players")
	local RS = game:GetService("ReplicatedStorage")
	local TS = game:GetService("TweenService")
	local CS = game:GetService("CollectionService")
	local HS = game:GetService("HttpService")
	local TPS = game:GetService("TeleportService")
	local VIM = game:GetService("VirtualInputManager")

	local plr = Players.LocalPlayer
	local CommF_ = RS:WaitForChild("Remotes"):WaitForChild("CommF_")
	local Net = RS:WaitForChild("Modules"):WaitForChild("Net")
	local RegAttack = Net:WaitForChild("RE/RegisterAttack")
	local RegHit = Net:WaitForChild("RE/RegisterHit")

	local W1 = game.PlaceId == 2753915549 or game.PlaceId == 85211729168715
	local W2 = game.PlaceId == 4442272183 or game.PlaceId == 79091703265657
	local W3 = game.PlaceId == 7449423635 or game.PlaceId == 100117331123089

	-- uses your existing Farming tab if it's named `Tab`, otherwise makes one
	local FarmTab = Tab or Window:CreateTab({ Name = "Farming", Icon = "farm" })

	local X = {Weapon = "Melee", Speed = 200, Height = 25, MasteryPct = 70, Skills = {Z = true, X = true, C = true, V = true, F = true}}

	-- ===== helpers =====
	local function root() local c = plr.Character return c and c:FindFirstChild("HumanoidRootPart") end
	local function hum() local c = plr.Character return c and c:FindFirstChildOfClass("Humanoid") end
	local function alive(m) if not m then return false end local h = m:FindFirstChildOfClass("Humanoid") return h and h.Health > 0 end
	local function eFolder() return workspace:FindFirstChild("Enemies") end
	local function getBP(n) return plr.Backpack:FindFirstChild(n) or (plr.Character and plr.Character:FindFirstChild(n)) end
	local function getEnemy(names)
		if type(names) == "string" then names = {names} end
		local f = eFolder() if not f then return nil end
		for _, e in ipairs(f:GetChildren()) do
			if table.find(names, e.Name) and alive(e) and e:FindFirstChild("HumanoidRootPart") then return e end
		end
	end
	local function getRep(names)
		if type(names) == "string" then names = {names} end
		for _, e in ipairs(RS:GetChildren()) do
			if e:IsA("Model") and table.find(names, e.Name) and alive(e) and e:FindFirstChild("HumanoidRootPart") then return e end
		end
	end
	local function equipType(tip)
		local h = hum() if not h then return end
		local cur = plr.Character:FindFirstChildOfClass("Tool")
		if cur and cur.ToolTip == tip then return end
		for _, t in ipairs(plr.Backpack:GetChildren()) do
			if t:IsA("Tool") and t.ToolTip == tip then h:EquipTool(t) return end
		end
	end
	local function equipName(n)
		local t = plr.Backpack:FindFirstChild(n)
		local h = hum()
		if t and h then h:EquipTool(t) end
	end
	local function getM(name)
		local ok, inv = pcall(function() return CommF_:InvokeServer("getInventory") end)
		if not ok or type(inv) ~= "table" then return 0 end
		for _, i in pairs(inv) do
			if type(i) == "table" and i.Type == "Material" and i.Name == name then return i.Count or 0 end
		end
		return 0
	end
	local function questTitle()
		local gui = plr.PlayerGui
		local main = gui:FindFirstChild("Main")
		local q = main and main:FindFirstChild("Quest")
		if q and q.Visible then
			local ok, t = pcall(function() return q.Container.QuestTitle.Title.Text end)
			return true, ok and t or ""
		end
		local tr = gui:FindFirstChild("TrackedQuestFrame")
		if tr and tr.Enabled then
			local ok, t = pcall(function() return tr.Frame.header.textLabel.Text end)
			if ok and t ~= "" then return true, t end
			local ok2, t2 = pcall(function() return tr.Frame.header.textLabel.textLabel.Text end)
			return true, ok2 and t2 or ""
		end
		return false, ""
	end
	local function hop()
		pcall(function()
			local d = HS:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
			for _, s in pairs(d.data) do
				if s.playing < s.maxPlayers and s.id ~= game.JobId then
					TPS:TeleportToPlaceInstance(game.PlaceId, s.id, plr) return
				end
			end
		end)
	end
	local function loop(sec, fn)
		task.spawn(function() while task.wait(sec) do pcall(fn) end end)
	end
	local function press(k)
		pcall(function() VIM:SendKeyEvent(true, k, false, game) task.wait(0.04) VIM:SendKeyEvent(false, k, false, game) end)
	end
	local function useSkill(tip, k) equipType(tip) press(k) task.wait(0.12) end
	local function skillBurst()
		for _, k in ipairs({"Z", "X", "C"}) do useSkill("Melee", k) end
		for _, k in ipairs({"Z", "X"}) do useSkill("Sword", k) end
		for _, k in ipairs({"Z", "X", "C"}) do useSkill("Blox Fruit", k) end
		for _, k in ipairs({"Z", "X"}) do useSkill("Gun", k) end
	end
	local function prompt(o) pcall(function() if fireproximityprompt then fireproximityprompt(o, math.huge) end end) end
	local function entrance(v) pcall(function() CommF_:InvokeServer("requestEntrance", v) end) end

	-- ===== movement + combat engine =====
	local Anchor = Instance.new("Part")
	Anchor.Name = "FarmXAnchor"
	Anchor.Size = Vector3.new(1, 1, 1)
	Anchor.Anchored = true Anchor.CanCollide = false Anchor.CanTouch = false Anchor.Transparency = 1
	Anchor.Parent = workspace

	local users, tween = {}, nil
	local function setActive(id, on) users[id] = on or nil end
	local function active() return next(users) ~= nil end

	local function move(cf, waitArrive, timeout)
		local r = root() if not r then return end
		if typeof(cf) == "Vector3" then cf = CFrame.new(cf) end
		if tween then pcall(function() tween:Cancel() end) end
		if (Anchor.Position - r.Position).Magnitude > 200 then Anchor.CFrame = r.CFrame end
		local d = (cf.Position - Anchor.Position).Magnitude
		tween = TS:Create(Anchor, TweenInfo.new(math.max(d / X.Speed, 0.05), Enum.EasingStyle.Linear), {CFrame = CFrame.new(cf.Position)})
		tween:Play()
		if waitArrive then
			local t0 = os.clock()
			repeat task.wait(0.1)
				local rr = root()
				if not rr or not active() then break end
				if (rr.Position - cf.Position).Magnitude <= 8 then break end
			until os.clock() - t0 > (timeout or 20)
		end
	end
	local function notween(cf)
		local r = root() if not r then return end
		if typeof(cf) == "Vector3" then cf = CFrame.new(cf) end
		r.CFrame = cf
	end

	task.spawn(function()
		while task.wait() do
			pcall(function()
				local r = root() if not r then return end
				if active() then
					if (r.Position - Anchor.Position).Magnitude <= 200 then r.CFrame = Anchor.CFrame else Anchor.CFrame = r.CFrame end
					if not r:FindFirstChild("FX_Clip") then
						local bv = Instance.new("BodyVelocity")
						bv.Name = "FX_Clip" bv.MaxForce = Vector3.new(1e5, 1e5, 1e5) bv.Velocity = Vector3.zero bv.Parent = r
					end
					for _, p in ipairs(plr.Character:GetDescendants()) do
						if p:IsA("BasePart") then p.CanCollide = false end
					end
				else
					local bv = r:FindFirstChild("FX_Clip") if bv then bv:Destroy() end
				end
			end)
		end
	end)

	local function attack(pos)
		pcall(function()
			local c, r = plr.Character, root()
			if not c or not r or not c:FindFirstChildOfClass("Tool") then return end
			local hits, head = {}, nil
			local f = eFolder() if not f then return end
			for _, e in ipairs(f:GetChildren()) do
				local h = e:FindFirstChildOfClass("Humanoid")
				local hrp = e:FindFirstChild("HumanoidRootPart")
				if h and hrp and h.Health > 0 and (hrp.Position - r.Position).Magnitude <= 60 then
					head = head or e:FindFirstChild("Head")
					for _, p in ipairs(e:GetChildren()) do
						if p:IsA("BasePart") then table.insert(hits, {e, p}) end
					end
				end
			end
			if head and #hits > 0 then
				RegAttack:FireServer(2e-09)
				RegHit:FireServer(head, hits, {})
			end
		end)
	end
	local function kill(e)
		if not alive(e) then return end
		local hrp = e:FindFirstChild("HumanoidRootPart") if not hrp then return end
		equipType(X.Weapon)
		move(hrp.CFrame * CFrame.new(0, X.Height, 0))
		attack()
	end
	local function spawnPoint(name)
		local o = workspace:FindFirstChild("_WorldOrigin")
		local s = o and o:FindFirstChild("EnemySpawns")
		if not s then return nil end
		for _, p in ipairs(s:GetChildren()) do
			if string.find(p.Name, name) then return p.CFrame end
		end
	end

	-- ===== data =====
	local MOBS = W1 and {"Bandit","Monkey","Gorilla","Pirate","Brute","Desert Bandit","Desert Officer","Snow Bandit","Snowman","Chief Petty Officer","Sky Bandit","Dark Master","Toga Warrior","Gladiator","Military Soldier","Military Spy","Fishman Warrior","Fishman Commando","God's Guard","Shanda","Royal Squad","Royal Soldier","Galley Pirate","Galley Captain"}
		or W2 and {"Raider","Mercenary","Swan Pirate","Factory Staff","Marine Lieutenant","Marine Captain","Zombie","Vampire","Snow Trooper","Winter Warrior","Lab Subordinate","Horned Warrior","Magma Ninja","Lava Pirate","Ship Deckhand","Ship Engineer","Ship Steward","Ship Officer","Arctic Warrior","Snow Lurker","Sea Soldier","Water Fighter"}
		or {"Pirate Millionaire","Dragon Crew Warrior","Dragon Crew Archer","Female Islander","Giant Islander","Marine Commodore","Marine Rear Admiral","Fishman Raider","Fishman Captain","Forest Pirate","Mythological Pirate","Jungle Pirate","Musketeer Pirate","Reborn Skeleton","Living Zombie","Demonic Soul","Posessed Mummy","Peanut Scout","Peanut President","Ice Cream Chef","Ice Cream Commander","Cookie Crafter","Cake Guard","Baking Staff","Head Baker","Cocoa Warrior","Chocolate Bar Battler","Sweet Thief","Candy Rebel","Candy Pirate","Snow Demon","Isle Outlaw","Island Boy","Sun-kissed Warrior","Isle Champion"}

	local ISLANDS = W1 and {
		{"Jungle", CFrame.new(-1600, 36, 150), {"Monkey", "Gorilla"}},
		{"Pirate Village", CFrame.new(-1100, 4, 3850), {"Pirate", "Brute"}},
		{"Desert", CFrame.new(1090, 7, 4370), {"Desert Bandit", "Desert Officer"}},
		{"Frozen Village", CFrame.new(1200, 28, -1500), {"Snow Bandit", "Snowman"}},
		{"Marine Fortress", CFrame.new(-4500, 20, 4250), {"Chief Petty Officer"}},
		{"Prison", CFrame.new(4875, 6, 735), {"Prisoner", "Dangerous Prisoner"}},
		{"Colosseum", CFrame.new(-1500, 60, -290), {"Toga Warrior", "Gladiator"}},
		{"Magma Village", CFrame.new(-5200, 8, 8400), {"Military Soldier", "Military Spy"}},
		{"Underwater City", CFrame.new(61160, 5, 1819), {"Fishman Warrior", "Fishman Commando"}},
		{"Skylands Upper", CFrame.new(-7880, 5545, -380), {"Shanda", "Royal Squad", "Royal Soldier"}},
	} or W2 and {
		{"Kingdom of Rose", CFrame.new(-321, 73, 297), {"Raider", "Mercenary", "Swan Pirate", "Factory Staff"}},
		{"Green Zone", CFrame.new(-2447, 73, -3211), {"Marine Lieutenant", "Marine Captain"}},
		{"Graveyard", CFrame.new(-9515, 142, 5536), {"Zombie", "Vampire"}},
		{"Snow Mountain", CFrame.new(561, 401, -5306), {"Snow Trooper", "Winter Warrior"}},
		{"Hot and Cold (Cold)", CFrame.new(-6026, 15, -5062), {"Lab Subordinate", "Horned Warrior"}},
		{"Hot and Cold (Hot)", CFrame.new(-5478, 15, -5240), {"Magma Ninja", "Lava Pirate"}},
		{"Cursed Ship", CFrame.new(902, 126, 33071), {"Ship Deckhand", "Ship Engineer", "Ship Steward", "Ship Officer"}},
		{"Ice Castle", CFrame.new(6137, 294, -6747), {"Arctic Warrior", "Snow Lurker"}},
		{"Forgotten Island", CFrame.new(-3043, 238, -10191), {"Sea Soldier", "Water Fighter"}},
	} or {
		{"Port Town", CFrame.new(-290, 44, 5450), {"Pirate Millionaire", "Pistol Billionaire"}},
		{"Hydra Island", CFrame.new(5228, 604, 345), {"Dragon Crew Warrior", "Dragon Crew Archer", "Female Islander", "Giant Islander", "Training Dummy"}},
		{"Great Tree", CFrame.new(2682, 1682, -7190), {"Marine Commodore", "Marine Rear Admiral"}},
		{"Floating Turtle", CFrame.new(-12000, 331, -8500), {"Forest Pirate", "Mythological Pirate", "Jungle Pirate", "Musketeer Pirate", "Fishman Raider", "Fishman Captain"}},
		{"Haunted Castle", CFrame.new(-9515, 142, 5536), {"Reborn Skeleton", "Living Zombie", "Demonic Soul", "Posessed Mummy"}},
		{"Sea of Treats", CFrame.new(-1145, 13, -14450), {"Peanut Scout", "Peanut President", "Ice Cream Commander", "Cookie Crafter", "Cake Guard", "Baking Staff", "Head Baker", "Cocoa Warrior", "Chocolate Bar Battler", "Sweet Thief", "Candy Rebel"}},
		{"Tiki Outpost", CFrame.new(-16200, 90, -17300), {"Isle Outlaw", "Island Boy", "Sun-kissed Warrior", "Isle Champion"}},
		{"Submerged Island", CFrame.new(-3200, -10, -10000), {"Reef Bandit", "Coral Pirate", "Sea Chanter", "Ocean Prophet", "High Disciple", "Grand Devotee"}},
	}

	local MATERIALS = W1 and {
		{"Angel Wings", {"Shanda", "Royal Squad", "Royal Soldier", "Wysper", "Thunder God"}, CFrame.new(-4698, 845, -1912), Vector3.new(-4607.82, 872.54, -1667.56)},
		{"Leather + Scrap Metal", {"Brute", "Pirate"}, CFrame.new(-1145, 15, 4350)},
		{"Magma Ore", {"Military Soldier", "Military Spy", "Magma Admiral"}, CFrame.new(-5815, 84, 8820)},
		{"Fish Tail", {"Fishman Warrior", "Fishman Commando", "Fishman Lord"}, CFrame.new(61123, 19, 1569), Vector3.new(61163.85, 5.34, 1819.78)},
	} or W2 and {
		{"Leather + Scrap Metal", {"Marine Captain"}, CFrame.new(-2010.5, 73, -3326.62)},
		{"Magma Ore", {"Magma Ninja", "Lava Pirate"}, CFrame.new(-5428, 78, -5959)},
		{"Ectoplasm", {"Ship Deckhand", "Ship Engineer", "Ship Steward", "Ship Officer"}, CFrame.new(911.36, 125.96, 33159.54), Vector3.new(923.21, 126.98, 32852.83)},
		{"Mystic Droplet", {"Water Fighter"}, CFrame.new(-3385, 239, -10542)},
		{"Radioactive Material", {"Factory Staff"}, CFrame.new(295, 73, -56)},
		{"Vampire Fang", {"Vampire"}, CFrame.new(-6033, 7, -1317)},
	} or {
		{"Scrap Metal", {"Jungle Pirate", "Forest Pirate"}, CFrame.new(-11975.79, 331.77, -10620.03)},
		{"Fish Tail", {"Fishman Raider", "Fishman Captain"}, CFrame.new(-10993, 332, -8940)},
		{"Conjured Cocoa", {"Chocolate Bar Battler", "Cocoa Warrior"}, CFrame.new(620.63, 78.94, -12581.37)},
		{"Dragon Scale", {"Dragon Crew Archer", "Dragon Crew Warrior"}, CFrame.new(6594, 383, 139)},
		{"Gunpowder", {"Pistol Billionaire"}, CFrame.new(-84.86, 85.62, 6132.01)},
		{"Mini Tusk", {"Mythological Pirate"}, CFrame.new(-13545, 470, -6917)},
		{"Demonic Wisp", {"Demonic Soul"}, CFrame.new(-9495.68, 453.59, 5977.35)},
	}

	-- {questName, questId, questPos, bossPos}
	local BOSS_DATA = {
		["The Gorilla King"] = {"JungleQuest", 3, CFrame.new(-1601.66, 36.85, 153.39), CFrame.new(-1088.76, 8.13, -488.56)},
		["Bobby"] = {"BuggyQuest1", 3, CFrame.new(-1140.18, 4.75, 3827.41), CFrame.new(-1087.38, 46.95, 4040.15)},
		["The Saw"] = {nil, nil, nil, CFrame.new(-784.90, 72.43, 1603.58)},
		["Yeti"] = {"SnowQuest", 3, CFrame.new(1386.81, 87.27, -1298.36), CFrame.new(1218.80, 138.01, -1488.03)},
		["Mob Leader"] = {nil, nil, nil, CFrame.new(-2844.73, 7.42, 5356.67)},
		["Vice Admiral"] = {"MarineQuest2", 2, CFrame.new(-5036.25, 28.68, 4324.57), CFrame.new(-5006.55, 88.03, 4353.16)},
		["Saber Expert"] = {nil, nil, nil, CFrame.new(-1458.90, 29.89, -50.63)},
		["Warden"] = {"ImpelQuest", 1, CFrame.new(5191.86, 2.84, 686.44), CFrame.new(5278.05, 2.15, 944.10)},
		["Chief Warden"] = {"ImpelQuest", 2, CFrame.new(5191.86, 2.84, 686.44), CFrame.new(5206.93, 1.00, 814.98)},
		["Swan"] = {"ImpelQuest", 3, CFrame.new(5191.86, 2.84, 686.44), CFrame.new(5325.10, 7.04, 719.57)},
		["Magma Admiral"] = {"MagmaQuest", 3, CFrame.new(-5314.62, 12.26, 8517.28), CFrame.new(-5765.90, 82.92, 8718.30)},
		["Fishman Lord"] = {"FishmanQuest", 3, CFrame.new(61122.65, 18.50, 1569.40), CFrame.new(61260.15, 30.95, 1193.43)},
		["Wysper"] = {"SkyExp1Quest", 3, CFrame.new(-7861.95, 5545.52, -379.86), CFrame.new(-7866.13, 5576.43, -546.75)},
		["Thunder God"] = {"SkyExp2Quest", 3, CFrame.new(-7903.38, 5635.99, -1410.92), CFrame.new(-7994.98, 5761.03, -2088.65)},
		["Cyborg"] = {"FountainQuest", 3, CFrame.new(5258.28, 38.53, 4050.04), CFrame.new(6094.02, 73.77, 3825.73)},
		["Ice Admiral"] = {nil, nil, nil, CFrame.new(1266.09, 26.18, -1399.58)},
		["Greybeard"] = {nil, nil, nil, CFrame.new(-5081.35, 85.22, 4257.36)},
		["Diamond"] = {"Area1Quest", 3, CFrame.new(-427.57, 73.31, 1835.42), CFrame.new(-1576.72, 198.59, 13.72)},
		["Jeremy"] = {"Area2Quest", 3, CFrame.new(636.80, 73.41, 918.00), CFrame.new(2006.93, 448.96, 853.98)},
		["Orbitus"] = {"MarineQuest3", 3, CFrame.new(-2441.99, 73.36, -3217.53), CFrame.new(-2172.74, 103.32, -4015.03)},
		["Don Swan"] = {nil, nil, nil, CFrame.new(2286.20, 15.18, 863.84)},
		["Smoke Admiral"] = {"IceSideQuest", 3, CFrame.new(-5429.05, 15.98, -5297.96), CFrame.new(-5275.20, 20.76, -5260.67)},
		["Awakened Ice Admiral"] = {"FrostQuest", 3, CFrame.new(5668.98, 28.52, -6483.35), CFrame.new(6403.54, 340.30, -6894.56)},
		["Tide Keeper"] = {"ForgottenQuest", 3, CFrame.new(-3053.98, 237.19, -10145.04), CFrame.new(-3795.64, 105.89, -11421.31)},
		["Darkbeard"] = {nil, nil, nil, CFrame.new(3677.08, 62.75, -3144.83)},
		["Cursed Captain"] = {nil, nil, nil, CFrame.new(916.93, 181.09, 33422)},
		["Order"] = {nil, nil, nil, CFrame.new(-6217.20, 28.05, -5053.14)},
		["Stone"] = {"PiratePortQuest", 3, CFrame.new(-289.77, 43.82, 5579.94), CFrame.new(-1027.65, 92.40, 6578.85)},
		["Hydra Leader"] = {"VenomCrewQuest", 3, CFrame.new(5211.02, 1004.36, 758.18), CFrame.new(5821.90, 1019.10, -73.72)},
		["Kilo Admiral"] = {"MarineTreeIsland", 3, CFrame.new(2179.30, 28.73, -6739.97), CFrame.new(2764.22, 432.46, -7144.46)},
		["Captain Elephant"] = {"DeepForestIsland", 3, CFrame.new(-13232.68, 332.40, -7626.01), CFrame.new(-13376.76, 433.29, -8071.39)},
		["Beautiful Pirate"] = {"DeepForestIsland2", 3, CFrame.new(-12682.10, 390.89, -9902.12), CFrame.new(5283.61, 22.56, -110.78)},
		["Cake Queen"] = {"IceCreamIslandQuest", 3, CFrame.new(-819.38, 64.93, -10967.28), CFrame.new(-678.65, 381.35, -11114.20)},
		["Longma"] = {nil, nil, nil, CFrame.new(-10238.88, 389.79, -9549.79)},
		["Soul Reaper"] = {nil, nil, nil, CFrame.new(-9524.79, 315.80, 6655.72)},
		["Dough King"] = {nil, nil, nil, CFrame.new(-1943.68, 251.51, -12337.88)},
		["rip_indra"] = {nil, nil, nil, CFrame.new(-5344.82, 423.99, -2725.09)},
		["Tyrant of the Skies"] = {nil, nil, nil, CFrame.new(-16268.29, 152.62, 1390.77)},
	}
	local BOSS_LIST = {}
	for name in pairs(BOSS_DATA) do
		if (W1 and table.find({"The Gorilla King","Bobby","The Saw","Yeti","Mob Leader","Vice Admiral","Saber Expert","Warden","Chief Warden","Swan","Magma Admiral","Fishman Lord","Wysper","Thunder God","Cyborg","Ice Admiral","Greybeard"}, name))
			or (W2 and table.find({"Diamond","Jeremy","Orbitus","Don Swan","Smoke Admiral","Awakened Ice Admiral","Tide Keeper","Darkbeard","Cursed Captain","Order"}, name))
			or (W3 and table.find({"Stone","Hydra Leader","Kilo Admiral","Captain Elephant","Beautiful Pirate","Cake Queen","Longma","Soul Reaper","Dough King","rip_indra","Tyrant of the Skies"}, name)) then
			table.insert(BOSS_LIST, name)
		end
	end
	table.sort(BOSS_LIST)
	if #BOSS_LIST == 0 then BOSS_LIST = {"None"} end

	local BONE_MOBS = {"Reborn Skeleton", "Living Zombie", "Demonic Soul", "Posessed Mummy"}
	local CAKE_MOBS = {"Cookie Crafter", "Cake Guard", "Baking Staff", "Head Baker"}
	local BONE_POS = CFrame.new(-9495.6806640625, 453.58624267578125, 5977.3486328125)
	local CAKE_POS = CFrame.new(-1943.676513671875, 251.50956726074219, -12337.880859375)

	-- ===== flags =====
	local F = {}
	local function tog(group, text, key, desc)
		group:AddToggle({Text = text, Desc = desc, Default = false, Callback = function(s)
			F[key] = s
			setActive("FX_" .. key, s)
		end})
	end
	local function btn(group, text, fn, danger)
		group:AddButton({Text = text, Danger = danger, Callback = function() task.spawn(fn) end})
	end

	-- ================= GROUPS =================
	local gFarm = FarmTab:AddGroup("Left", "Farming")
	tog(gFarm, "Auto Factory Raid", "Factory", "Core / Factory")
	tog(gFarm, "Auto Pirate Raid", "Castle", "Castle on the Sea raid")
	tog(gFarm, "Auto Farm Ectoplasm", "Ecto", "Cursed Ship mobs")

	local gChest = FarmTab:AddGroup("Left", "Chest")
	tog(gChest, "Auto Farm Chest", "Chest", "Tween to nearest chest")
	tog(gChest, "Auto Chest Bypass", "ChestBP", "Instant TP chests")
	tog(gChest, "Stop When Chalice / Fist", "StopChalice")

	local gBerry = FarmTab:AddGroup("Left", "Berry")
	tog(gBerry, "Auto Farm Berry", "Berry")
	tog(gBerry, "Auto Farm Berry + Hop", "BerryHop", "Hops when no berries left")

	local gMob = FarmTab:AddGroup("Left", "Farm Mob")
	local selMob = MOBS[1]
	gMob:AddDropdown({Text = "Select Mob", Options = MOBS, Default = MOBS[1], Callback = function(s) selMob = s end})
	tog(gMob, "Auto Kill Mob", "Mob")

	local gIsland = FarmTab:AddGroup("Left", "Farm Island")
	local islandNames = {}
	for _, v in ipairs(ISLANDS) do table.insert(islandNames, v[1]) end
	local selIsland = islandNames[1]
	gIsland:AddDropdown({Text = "Select Island", Options = islandNames, Default = islandNames[1], Callback = function(s) selIsland = s end})
	tog(gIsland, "Auto Farm All Island", "Island")

	local gElite = FarmTab:AddGroup("Left", "Elite Hunter")
	tog(gElite, "Auto Farm Elite", "Elite")
	tog(gElite, "Auto Farm Elite + Hop", "EliteHop")
	btn(gElite, "Print Elite Progress", function()
		print("[Elite] Killed:", CommF_:InvokeServer("EliteHunter", "Progress"))
	end)

	local gRip = FarmTab:AddGroup("Left", "Rip Indra")
	tog(gRip, "Auto Attack Rip Indra", "Rip")
	tog(gRip, "Auto Unlock Haki (Summoner)", "UnHaki", "Boat Castle aura circle")

	local gCake = FarmTab:AddGroup("Right", "Cake Prince / Dough King")
	tog(gCake, "Auto Farm Cake Prince", "Cake")
	tog(gCake, "Accept Cake Quests", "CakeQuest")
	tog(gCake, "Auto Summon Cake Prince", "CakeSummon")
	tog(gCake, "Auto Dough King [Fully]", "DoughFull", "Chalice + cocoa + elite chain")
	tog(gCake, "Auto Farm Dough King", "Dough")
	tog(gCake, "Auto Dough King + Hop", "DoughHop")
	btn(gCake, "Print Cake Prince Progress", function()
		print("[Cake]", CommF_:InvokeServer("CakePrinceSpawner"))
	end)

	local gBone = FarmTab:AddGroup("Right", "Bone")
	tog(gBone, "Auto Farm Bone", "Bone")
	tog(gBone, "Accept Bone Quests", "BoneQuest")
	tog(gBone, "Auto Soul Reaper", "Reaper")
	tog(gBone, "Auto Random Bones", "RandBone")
	tog(gBone, "Auto Try Luck Gravestone", "Luck")
	tog(gBone, "Auto Pray Gravestone", "Pray")
	btn(gBone, "Print Bones", function()
		print("[Bones]", CommF_:InvokeServer("Bones", "Check"))
	end)

	local gTyrant = FarmTab:AddGroup("Right", "Tyrant of the Skies")
	tog(gTyrant, "Auto Farm Boss TOTS", "Tyrant")
	tog(gTyrant, "Auto Summon Boss", "TyrantSummon", "Activates the 4 eyes")
	btn(gTyrant, "Print Eye Count", function()
		local ok, n = pcall(function()
			local m = workspace.Map.TikiOutpost.IslandModel
			local c = 0
			for _, e in ipairs({m.Eye1, m.Eye2, m.IslandChunks.E.Eye3, m.IslandChunks.E.Eye4}) do
				if e and e.Transparency ~= 1 then c = c + 1 end
			end
			return c
		end)
		print("[TOTS] Eyes:", ok and n or "?", "/4")
	end)

	local gMat = FarmTab:AddGroup("Right", "Farm Material")
	local matNames = {}
	for _, v in ipairs(MATERIALS) do table.insert(matNames, v[1]) end
	local selMat = matNames[1]
	gMat:AddDropdown({Text = "Choose Material", Options = matNames, Default = matNames[1], Callback = function(s) selMat = s end})
	tog(gMat, "Auto Farm Materials", "Material")

	local gBoss = FarmTab:AddGroup("Right", "Farm Boss")
	local selBoss = BOSS_LIST[1]
	gBoss:AddDropdown({Text = "Select Boss", Options = BOSS_LIST, Default = BOSS_LIST[1], Callback = function(s) selBoss = s end})
	tog(gBoss, "Auto Farm Boss", "Boss")
	tog(gBoss, "Accept Boss Quests", "BossQuest")
	tog(gBoss, "Auto Farm All Boss", "AllBoss", "Nearest boss in the sea")

	local gMas = FarmTab:AddGroup("Right", "Farming Mastery")
	local masIsland = "Cake"
	gMas:AddDropdown({Text = "Choose Island", Options = {"Cake", "Bone"}, Default = "Cake", Callback = function(s) masIsland = s end})
	gMas:AddSlider({Text = "NPC Health % To Use Skill", Suffix = "%", Min = 10, Max = 95, Step = 1, Decimals = 0, Default = 70,
		Callback = function(v) X.MasteryPct = v end})
	for _, k in ipairs({"Z", "X", "C", "V", "F", "Y"}) do
		gMas:AddToggle({Text = "Skill " .. k, Default = k ~= "Y", Callback = function(s) X.Skills[k] = s end})
	end
	tog(gMas, "Auto Mastery Fruits", "MasFruit")
	tog(gMas, "Auto Mastery Gun", "MasGun")
	tog(gMas, "Auto Mastery All Sword", "MasSword")

	local gMagnet = FarmTab:AddGroup("Right", "Magnet Token")
	tog(gMagnet, "Auto Farm Magnet Token", "Magnet", "Patrols spawns for magnetized mobs")

	local gSet = FarmTab:AddGroup("Right", "Farm Settings")
	gSet:AddDropdown({Text = "Weapon Type", Options = {"Melee", "Sword", "Blox Fruit", "Gun"}, Default = "Melee",
		Callback = function(s) X.Weapon = s end})
	gSet:AddSlider({Text = "Tween Speed", Suffix = "", Min = 50, Max = 400, Step = 5, Decimals = 0, Default = 200,
		Callback = function(v) X.Speed = v end})
	gSet:AddSlider({Text = "Farm Height", Suffix = " studs", Min = 0, Max = 60, Step = 1, Decimals = 0, Default = 25,
		Callback = function(v) X.Height = v end})

	-- ================= LOOPS =================
	loop(0.2, function()
		if F.Factory then
			local e = getEnemy("Core") or getRep("Core")
			if e then kill(e) else move(CFrame.new(448.46756, 199.356781, -441.389252)) end
		end
		if F.Castle then
			local r = root() if not r then return end
			if (Vector3.new(-5539.31, 313.80, -2972.37) - r.Position).Magnitude <= 500 then
				local f = eFolder()
				if f then
					for _, e in ipairs(f:GetChildren()) do
						local hrp = e:FindFirstChild("HumanoidRootPart")
						if alive(e) and hrp and (hrp.Position - r.Position).Magnitude <= 2000 then kill(e) return end
					end
				end
			else
				move(CFrame.new(-5496.17432, 313.768921, -2841.53027))
			end
		end
		if F.Ecto then
			local e = getEnemy({"Ship Deckhand", "Ship Engineer", "Ship Steward", "Ship Officer", "Arctic Warrior"})
			if e then kill(e) else entrance(Vector3.new(923.21252441406, 126.9760055542, 32852.83203125)) end
		end
	end)

	local function nearestChest()
		local r = root() if not r then return nil end
		local best, bd
		for _, c in ipairs(CS:GetTagged("_ChestTagged")) do
			if not c:GetAttribute("IsDisabled") then
				local ok, piv = pcall(function() return c:GetPivot() end)
				if ok then
					local d = (piv.Position - r.Position).Magnitude
					if not bd or d < bd then best, bd = c, d end
				end
			end
		end
		return best
	end
	loop(0.2, function()
		if F.StopChalice and (F.Chest or F.ChestBP) then
			if getBP("God's Chalice") or getBP("Sweet Chalice") or getBP("Fist of Darkness") then
				F.Chest, F.ChestBP = false, false
				setActive("FX_Chest", false) setActive("FX_ChestBP", false)
				print("[Chest] Stopped — special item found")
			end
		end
		if F.Chest then
			local c = nearestChest()
			if c then local ok, piv = pcall(function() return c:GetPivot() end) if ok then move(piv) end end
		end
	end)
	loop(0.1, function()
		if not F.ChestBP then return end
		local r = root() if not r then return end
		local best, bd
		for _, d in ipairs(workspace:GetDescendants()) do
			if d:IsA("BasePart") and d.Name:find("Chest") and d:FindFirstChild("TouchInterest") then
				local dist = (d.Position - r.Position).Magnitude
				if not bd or dist < bd then best, bd = d, dist end
			end
		end
		if best then notween(best.CFrame) end
	end)

	local function doBerry()
		local tagged = CS:GetTagged("BerryBush")
		if #tagged == 0 then return false end
		for _, bush in ipairs(tagged) do
			pcall(function()
				if bush.Parent then move(bush.Parent:GetPivot()) end
				for _, child in ipairs(bush:GetChildren()) do
					local pp = child:FindFirstChild("ProximityPrompt")
					if pp then
						move(child.WorldPivot)
						prompt(pp)
					end
				end
			end)
		end
		return true
	end
	loop(0.5, function()
		if F.Berry then doBerry() end
		if F.BerryHop and not doBerry() then hop() end
	end)

	loop(0.2, function()
		if F.Mob then
			local e = getEnemy(selMob)
			if e then kill(e) else
				local sp = spawnPoint(selMob)
				if sp then move(sp * CFrame.new(0, 20, 0)) end
			end
		end
		if F.Island then
			local data
			for _, v in ipairs(ISLANDS) do if v[1] == selIsland then data = v break end end
			if not data then return end
			local e = getEnemy(data[3])
			if e then kill(e) else move(data[2]) end
		end
	end)

	local function eliteLogic(doHop)
		local vis, title = questTitle()
		if not vis then
			local res = CommF_:InvokeServer("EliteHunter")
			if (res == nil or tostring(res):find("Cooldown")) and doHop then hop() end
			return
		end
		local boss
		for _, n in ipairs({"Diablo", "Urban", "Deandre"}) do
			if string.find(title, n) then boss = n break end
		end
		if not boss then CommF_:InvokeServer("AbandonQuest") return end
		local e = getEnemy(boss) or getRep(boss)
		if e and e:FindFirstChild("HumanoidRootPart") then
			kill(e)
		elseif doHop then
			task.wait(3)
			if not getEnemy(boss) then hop() end
		end
	end
	loop(0.5, function()
		if F.Elite then eliteLogic(false) end
		if F.EliteHop then eliteLogic(true) end
	end)

	loop(0.2, function()
		if F.Rip then
			local e = getEnemy("rip_indra") or getRep("rip_indra")
			if e then kill(e) else
				entrance(Vector3.new(-5097.93, 316.45, -3142.67))
				move(CFrame.new(-5344.822265625, 423.98541259766, -2725.0930175781))
			end
		end
		if F.UnHaki then
			local map = workspace:FindFirstChild("Map")
			local bc = map and map:FindFirstChild("Boat Castle")
			local sum = bc and bc:FindFirstChild("Summoner")
			local circle = sum and sum:FindFirstChild("Circle")
			if not circle then return end
			local map3 = {["Really red"] = "Pure Red", Oyster = "Snow White", ["Hot pink"] = "Winter Sky"}
			for _, p in ipairs(circle:GetChildren()) do
				if p.Name == "Part" then
					local inner = p:FindFirstChild("Part")
					if inner and tostring(inner.BrickColor) ~= "Lime green" then
						local skin = map3[tostring(inner.BrickColor)]
						if skin then
							pcall(function()
								Net["RF/FruitCustomizerRF"]:InvokeServer({StorageName = skin, Type = "AuraSkin", Context = "Equip"})
							end)
						end
						move(p.CFrame)
						return
					end
				end
			end
		end
	end)

	-- Cake / Dough
	loop(0.3, function()
		local map = workspace:FindFirstChild("Map")
		local loaf = map and map:FindFirstChild("CakeLoaf")
		local mirror = loaf and loaf:FindFirstChild("BigMirror")
		if F.Cake then
			if F.CakeQuest then
				local vis = questTitle()
				if not vis then
					move(CFrame.new(-1927.92, 37.8, -12842.54), true, 20)
					local q = {{"StartQuest","CakeQuest2",2},{"StartQuest","CakeQuest2",1},{"StartQuest","CakeQuest1",1},{"StartQuest","CakeQuest1",2}}
					pcall(function() CommF_:InvokeServer(unpack(q[math.random(1, 4)])) end)
				end
			end
			if not loaf then move(CFrame.new(-2077, 252, -12373)) return end
			local prince = getEnemy("Cake Prince") or getRep("Cake Prince")
			if (mirror and mirror:FindFirstChild("Other") and mirror.Other.Transparency == 0) or prince then
				if prince then kill(prince) else move(CFrame.new(-2151.82, 149.32, -12404.91)) end
			else
				local e = getEnemy(CAKE_MOBS)
				if e then kill(e) else move(CFrame.new(-2077, 252, -12373)) end
			end
		end
		if F.Dough then
			local e = getEnemy("Dough King") or getRep("Dough King")
			if e then kill(e) else move(CFrame.new(-1943.6765, 251.5095, -12337.8809)) end
		end
		if F.DoughFull then
			local dk = getEnemy("Dough King") or getRep("Dough King")
			if dk then kill(dk) return end
			if getBP("Sweet Chalice") then
				pcall(function() CommF_:InvokeServer("CakePrinceSpawner", true) end)
				return
			end
			if getBP("God's Chalice") and getM("Conjured Cocoa") >= 10 then
				pcall(function() CommF_:InvokeServer("SweetChaliceNpc") end)
				return
			end
			if getM("Conjured Cocoa") < 10 then
				local e = getEnemy({"Cocoa Warrior", "Chocolate Bar Battler"})
				if e then kill(e) else move(CFrame.new(402.72, 81.06, -12259.54)) end
				return
			end
			if not getBP("God's Chalice") then eliteLogic(false) end
		end
	end)
	loop(2, function()
		if F.CakeSummon then
			pcall(function()
				local mirror = workspace.Map.CakeLoaf:FindFirstChild("BigMirror")
				if not mirror or getEnemy("Cake Prince") then return end
				if mirror.Other.Transparency == 0 then return end
				CommF_:InvokeServer("CakePrinceSpawner", true)
			end)
		end
		if F.DoughHop and not getEnemy("Dough King") and not getRep("Dough King") then hop() end
	end)

	-- Bone
	loop(0.3, function()
		if F.Bone then
			if F.BoneQuest then
				local vis = questTitle()
				if not vis then
					move(CFrame.new(-9516.99316, 172.01718, 6078.46533), true, 20)
					local q = {{"StartQuest","HauntedQuest2",2},{"StartQuest","HauntedQuest2",1},{"StartQuest","HauntedQuest1",1},{"StartQuest","HauntedQuest1",2}}
					pcall(function() CommF_:InvokeServer(unpack(q[math.random(1, 4)])) end)
				end
			end
			local e = getEnemy(BONE_MOBS)
			if e then kill(e) else move(BONE_POS) end
		end
		if F.Reaper then
			local e = getEnemy("Soul Reaper") or getRep("Soul Reaper")
			if e then kill(e)
			elseif getBP("Hallow Essence") then
				move(CFrame.new(-8932.322265625, 146.83154296875, 6062.55078125), true, 20)
				equipName("Hallow Essence")
			else
				pcall(function() CommF_:InvokeServer("Bones", "Buy", 1, 1) end)
			end
		end
		if F.RandBone then pcall(function() CommF_:InvokeServer("Bones", "Buy", 1, 1) end) end
		if F.Luck or F.Pray then
			local gs = CFrame.new(-8761.3154296875, 164.85829162598, 6161.1567382813)
			move(gs, true, 20)
			local r = root()
			if r and (r.Position - gs.Position).Magnitude <= 10 then
				pcall(function() CommF_:InvokeServer("gravestoneEvent", F.Luck and 1 or 2) end)
			end
		end
	end)

	-- Tyrant
	local EYES = {
		CFrame.new(-16332.526, 158.072, 1440.325), CFrame.new(-16288.609, 158.167, 1470.368),
		CFrame.new(-16245.412, 158.437, 1463.366), CFrame.new(-16212.469, 158.167, 1466.344),
		CFrame.new(-16211.946, 158.072, 1322.398), CFrame.new(-16260.922, 154.921, 1323.616),
		CFrame.new(-16297.060, 159.323, 1317.224), CFrame.new(-16335.097, 159.334, 1324.886),
	}
	loop(0.3, function()
		if not F.Tyrant then return end
		local boss = getEnemy("Tyrant of the Skies")
		if boss then kill(boss) return end
		local e = getEnemy({"Serpent Hunter", "Skull Slayer", "Isle Champion", "Sun-kissed Warrior"})
		if e then kill(e) else move(CFrame.new(-16268.287, 152.616, 1390.773)) end
	end)
	loop(0.5, function()
		if not F.TyrantSummon then return end
		for _, cf in ipairs(EYES) do
			if not F.TyrantSummon then break end
			move(cf, true, 12)
			local r = root()
			if r and (r.Position - cf.Position).Magnitude <= 6 then
				for _, tip in ipairs({"Melee", "Sword", "Gun"}) do
					equipType(tip)
					for _, k in ipairs({"Z", "X", "C", "V", "F"}) do press(k) task.wait(0.1) end
				end
			end
		end
	end)

	-- Material
	loop(0.3, function()
		if not F.Material then return end
		local data
		for _, v in ipairs(MATERIALS) do if v[1] == selMat then data = v break end end
		if not data then return end
		if data[4] then
			local r = root()
			if r and (r.Position - data[4]).Magnitude > 10000 then entrance(data[4]) end
		end
		local e = getEnemy(data[2])
		if e then kill(e) else move(data[3]) end
	end)

	-- Boss
	loop(0.3, function()
		if F.Boss then
			local data = BOSS_DATA[selBoss]
			if not data then return end
			if F.BossQuest and data[1] then
				local vis, title = questTitle()
				if vis and not string.find(title, selBoss) then
					pcall(function() CommF_:InvokeServer("AbandonQuest") end)
				elseif not vis then
					move(data[3], true, 20)
					local r = root()
					if r and (r.Position - data[3].Position).Magnitude <= 12 then
						pcall(function() CommF_:InvokeServer("StartQuest", data[1], data[2]) end)
					end
					return
				end
			end
			local e = getEnemy(selBoss) or getRep(selBoss)
			if e then kill(e) else move(data[4] * CFrame.new(0, 20, 0)) end
		end
		if F.AllBoss then
			local r = root() if not r then return end
			local best, bd
			local f = eFolder() if not f then return end
			for _, e in ipairs(f:GetChildren()) do
				local hrp = e:FindFirstChild("HumanoidRootPart")
				if alive(e) and hrp and table.find(BOSS_LIST, e.Name) then
					local d = (hrp.Position - r.Position).Magnitude
					if not bd or d < bd then best, bd = e, d end
				end
			end
			if best then kill(best) end
		end
	end)

	-- Mastery
	local function masteryTarget()
		if masIsland == "Cake" then return getEnemy(CAKE_MOBS), CAKE_POS end
		return getEnemy(BONE_MOBS), BONE_POS
	end
	local function masterySkills(tip)
		for k, on in pairs(X.Skills) do
			if on then useSkill(tip, k) end
		end
	end
	loop(0.2, function()
		if not (F.MasFruit or F.MasGun) then return end
		local e, pos = masteryTarget()
		if not e then move(pos) return end
		local h = e:FindFirstChildOfClass("Humanoid")
		local hrp = e.HumanoidRootPart
		local threshold = h.MaxHealth * (X.MasteryPct / 100)
		if h.Health <= threshold then
			local tip = F.MasFruit and "Blox Fruit" or "Gun"
			equipType(tip)
			move(hrp.CFrame * CFrame.new(0, F.MasFruit and 20 or 35, 8))
			masterySkills(tip)
			if F.MasGun then
				pcall(function()
					local tool = plr.Character:FindFirstChildOfClass("Tool")
					if not tool then return end
					if tool.Name == "Skull Guitar" then
						tool.RemoteEvent:FireServer("TAP", hrp.Position)
					else
						Net["RE/ShootGunEvent"]:FireServer(hrp.Position, {hrp})
					end
					VIM:SendMouseButtonEvent(0, 0, 0, true, game, 1)
					task.wait(0.05)
					VIM:SendMouseButtonEvent(0, 0, 0, false, game, 1)
				end)
			end
		else
			equipType("Melee")
			move(hrp.CFrame * CFrame.new(0, 30, 0))
			attack()
		end
	end)
	loop(0.5, function()
		if not F.MasSword then return end
		local ok, inv = pcall(function() return CommF_:InvokeServer("getInventory") end)
		if not ok or type(inv) ~= "table" then return end
		for _, item in pairs(inv) do
			if type(item) == "table" and item.Type == "Sword" and tonumber(item.Mastery or 0) < 600 then
				if not getBP(item.Name) then
					pcall(function() CommF_:InvokeServer("LoadItem", item.Name) end)
					return
				end
				local e, pos = masteryTarget()
				if e then
					equipName(item.Name)
					move(e.HumanoidRootPart.CFrame * CFrame.new(0, 30, 0))
					attack()
				else
					move(pos)
				end
				return
			end
		end
	end)

	-- Magnet Token
	local magnetRoute, magnetIdx = {}, 1
	local function buildRoute()
		local o = workspace:FindFirstChild("_WorldOrigin")
		local s = o and o:FindFirstChild("EnemySpawns")
		if not s then return {} end
		local out = {}
		for _, p in ipairs(s:GetChildren()) do
			local n = string.lower(p.Name)
			if not (n:find("sky") or n:find("underwater") or n:find("fishman") or n:find("sewer")) then
				table.insert(out, p.CFrame * CFrame.new(0, 40, 0))
			end
		end
		return out
	end
	loop(0.3, function()
		if not F.Magnet then return end
		local f = eFolder()
		if f then
			for _, e in ipairs(f:GetChildren()) do
				if alive(e) and (e:GetAttribute("MagnetEnemy") == true or string.find(string.lower(e.Name), "magnetized")) then
					kill(e)
					return
				end
			end
		end
		if #magnetRoute == 0 then magnetRoute = buildRoute() magnetIdx = 1 end
		if #magnetRoute == 0 then return end
		move(magnetRoute[magnetIdx], true, 10)
		magnetIdx = magnetIdx % #magnetRoute + 1
	end)
end

-- // ================= SEA EVENT + SETTINGS TABS =================
do
	local Players = game:GetService("Players")
	local RS = game:GetService("ReplicatedStorage")
	local TS = game:GetService("TweenService")
	local RunService = game:GetService("RunService")
	local Lighting = game:GetService("Lighting")
	local VIM = game:GetService("VirtualInputManager")
	local VU = game:GetService("VirtualUser")
	local TPS = game:GetService("TeleportService")
	local HS = game:GetService("HttpService")

	local plr = Players.LocalPlayer
	local CommF_ = RS:WaitForChild("Remotes"):WaitForChild("CommF_")
	local CommE = RS:WaitForChild("Remotes"):WaitForChild("CommE")
	local Net = RS:WaitForChild("Modules"):WaitForChild("Net")
	local RegAttack = Net:WaitForChild("RE/RegisterAttack")
	local RegHit = Net:WaitForChild("RE/RegisterHit")

	local C = {Weapon = "Melee", Speed = 250, Height = 25, Boat = "Guardian", Zone = "Lv 6", BoatSpeed = 300, SafeHP = 25, HopDelay = 30}
	local S = {}

	-- ===== helpers =====
	local function root() local c = plr.Character return c and c:FindFirstChild("HumanoidRootPart") end
	local function hum() local c = plr.Character return c and c:FindFirstChildOfClass("Humanoid") end
	local function alive(m) if not m then return false end local h = m:FindFirstChildOfClass("Humanoid") return h and h.Health > 0 end
	local function eFolder() return workspace:FindFirstChild("Enemies") end
	local function GetBP(n) return plr.Backpack:FindFirstChild(n) or (plr.Character and plr.Character:FindFirstChild(n)) end
	local function net(n) return Net:FindFirstChild(n) end
	local function findEnemy(names)
		if type(names) == "string" then names = {names} end
		local f = eFolder() if not f then return nil end
		for _, e in ipairs(f:GetChildren()) do
			if table.find(names, e.Name) and alive(e) and e:FindFirstChild("HumanoidRootPart") then return e end
		end
	end
	local function equipType(tip)
		local h = hum() if not h then return end
		local cur = plr.Character:FindFirstChildOfClass("Tool")
		if cur and cur.ToolTip == tip then return end
		for _, t in ipairs(plr.Backpack:GetChildren()) do
			if t:IsA("Tool") and t.ToolTip == tip then h:EquipTool(t) return end
		end
	end
	local function loop(sec, fn)
		task.spawn(function() while task.wait(sec) do pcall(fn) end end)
	end
	local function press(k)
		pcall(function() VIM:SendKeyEvent(true, k, false, game) task.wait(0.04) VIM:SendKeyEvent(false, k, false, game) end)
	end
	local function useSkills(tip, keys)
		equipType(tip)
		for _, k in ipairs(keys) do press(k) task.wait(0.12) end
	end
	local function skillBurst()
		useSkills("Melee", {"Z", "X", "C"})
		useSkills("Sword", {"Z", "X"})
		useSkills("Blox Fruit", {"Z", "X", "C"})
		useSkills("Gun", {"Z", "X"})
	end
	local function aimAt(pos)
		pcall(function()
			local cam = workspace.CurrentCamera
			cam.CFrame = CFrame.new(cam.CFrame.Position, pos)
		end)
	end
	local function hasBigFruit()
		return GetBP("Dragon-Dragon") or GetBP("Gas-Gas") or GetBP("Yeti-Yeti") or GetBP("Kitsune-Kitsune") or GetBP("T-Rex-T-Rex")
	end
	local function hop()
		pcall(function()
			local d = HS:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
			for _, s in pairs(d.data) do
				if s.playing < s.maxPlayers and s.id ~= game.JobId then
					TPS:TeleportToPlaceInstance(game.PlaceId, s.id, plr) return
				end
			end
		end)
	end

	-- ===== movement engine =====
	local Anchor = Instance.new("Part")
	Anchor.Name = "SeaSetAnchor"
	Anchor.Size = Vector3.new(1, 1, 1)
	Anchor.Anchored = true Anchor.CanCollide = false Anchor.CanTouch = false Anchor.Transparency = 1
	Anchor.Parent = workspace

	local users, tween = {}, nil
	local function setActive(id, on) users[id] = on or nil end
	local function active() return next(users) ~= nil end

	local function move(cf, waitArrive, timeout)
		local r = root() if not r then return end
		if typeof(cf) == "Vector3" then cf = CFrame.new(cf) end
		if tween then pcall(function() tween:Cancel() end) end
		if (Anchor.Position - r.Position).Magnitude > 200 then Anchor.CFrame = r.CFrame end
		local d = (cf.Position - Anchor.Position).Magnitude
		tween = TS:Create(Anchor, TweenInfo.new(math.max(d / C.Speed, 0.05), Enum.EasingStyle.Linear), {CFrame = CFrame.new(cf.Position)})
		tween:Play()
		if waitArrive then
			local t0 = os.clock()
			repeat task.wait(0.1)
				local rr = root()
				if not rr or not active() then break end
				if (rr.Position - cf.Position).Magnitude <= 8 then break end
			until os.clock() - t0 > (timeout or 25)
		end
	end
	local function notween(cf)
		local r = root() if not r then return end
		if typeof(cf) == "Vector3" then cf = CFrame.new(cf) end
		r.CFrame = cf
	end

	task.spawn(function()
		while task.wait() do
			pcall(function()
				local r = root() if not r then return end
				if active() then
					if (r.Position - Anchor.Position).Magnitude <= 200 then r.CFrame = Anchor.CFrame else Anchor.CFrame = r.CFrame end
					if not r:FindFirstChild("SS_Clip") then
						local bv = Instance.new("BodyVelocity")
						bv.Name = "SS_Clip" bv.MaxForce = Vector3.new(1e5, 1e5, 1e5) bv.Velocity = Vector3.zero bv.Parent = r
					end
					for _, p in ipairs(plr.Character:GetDescendants()) do
						if p:IsA("BasePart") then p.CanCollide = false end
					end
				else
					local bv = r:FindFirstChild("SS_Clip") if bv then bv:Destroy() end
				end
			end)
		end
	end)

	-- ===== combat =====
	local function attack()
		pcall(function()
			local c, r = plr.Character, root()
			if not c or not r or not c:FindFirstChildOfClass("Tool") then return end
			local hits, head = {}, nil
			local f = eFolder() if not f then return end
			for _, e in ipairs(f:GetChildren()) do
				local h = e:FindFirstChildOfClass("Humanoid")
				local hrp = e:FindFirstChild("HumanoidRootPart")
				if h and hrp and h.Health > 0 and (hrp.Position - r.Position).Magnitude <= 60 then
					head = head or e:FindFirstChild("Head")
					for _, p in ipairs(e:GetChildren()) do
						if p:IsA("BasePart") then table.insert(hits, {e, p}) end
					end
				end
			end
			if head and #hits > 0 then
				RegAttack:FireServer(2e-09)
				RegHit:FireServer(head, hits, {})
			end
		end)
	end
	local SPIN = {Vector3.new(0, 30, 25), Vector3.new(25, 30, 0), Vector3.new(-25, 30, 0)}
	local spinIdx = 0
	local function kill(e)
		if not alive(e) then return end
		local hrp = e:FindFirstChild("HumanoidRootPart") if not hrp then return end
		equipType(C.Weapon)
		local off = Vector3.new(0, C.Height, 0)
		if S.Spin then spinIdx = spinIdx % #SPIN + 1 off = SPIN[spinIdx] end
		move(hrp.CFrame * CFrame.new(off))
		attack()
	end
	local function killSea(e)
		local hrp = e and e:FindFirstChild("HumanoidRootPart") if not hrp then return end
		equipType(C.Weapon)
		notween(hrp.CFrame * CFrame.new(0, 50, 8))
		attack()
		task.wait(0.85)
		notween(hrp.CFrame * CFrame.new(0, 400, 0))
		task.wait(1)
	end

	-- ===== boat / sea helpers =====
	local DOCK = CFrame.new(-16927.451, 9.086, 433.864)
	local ZONES = {
		["Lv 1"] = CFrame.new(-21998.375, 30.0006084, -682.309143),
		["Lv 2"] = CFrame.new(-26779.5215, 30.0005474, -822.858032),
		["Lv 3"] = CFrame.new(-31171.957, 30.0001011, -2256.93774),
		["Lv 4"] = CFrame.new(-34054.6875, 30.2187767, -2560.12012),
		["Lv 5"] = CFrame.new(-38887.5547, 30.0004578, -2162.99023),
		["Lv 6"] = CFrame.new(-44541.7617, 30.0003204, -1244.8584),
		["Lv Infinite"] = CFrame.new(-10000000, 31, 37016.25),
	}
	local function myBoat()
		local b = workspace:FindFirstChild("Boats") if not b then return nil end
		for _, v in ipairs(b:GetChildren()) do
			local o = v:FindFirstChild("Owner")
			if o and tostring(o.Value) == plr.Name then return v end
		end
	end
	local function enemyBoat(names)
		local f = eFolder() if not f then return nil end
		for _, v in ipairs(f:GetChildren()) do
			if table.find(names, v.Name) then
				local h = v:FindFirstChild("Health")
				if h and h.Value > 0 and v:FindFirstChild("Engine") then return v end
			end
		end
	end
	local function seaBeast()
		local f = workspace:FindFirstChild("SeaBeasts") if not f then return nil end
		for _, v in ipairs(f:GetChildren()) do
			local h = v:FindFirstChild("Health")
			if v.Name ~= "Leviathan" and h and h.Value > 0 and v:FindFirstChild("HumanoidRootPart") then return v end
		end
	end
	local function leviathan()
		local f = workspace:FindFirstChild("SeaBeasts")
		local v = f and f:FindFirstChild("Leviathan")
		local h = v and v:FindFirstChild("Health")
		if v and h and h.Value > 0 then return v end
	end
	local function anyThreat()
		return enemyBoat({"FishBoat", "PirateGrandBrigade", "PirateBrigade"}) ~= nil or findEnemy("Terrorshark") ~= nil
	end
	-- is something we WANT to kill currently spawned? then stop sailing and fight it
	local function targetUp()
		if S.Shark and findEnemy("Shark") then return true end
		if S.Piranha and findEnemy("Piranha") then return true end
		if S.Terror and findEnemy("Terrorshark") then return true end
		if S.Crew and findEnemy("Fish Crew Member") then return true end
		if S.Haunted and findEnemy("Haunted Crew Member") then return true end
		if S.PGB and enemyBoat({"PirateGrandBrigade", "PirateBrigade"}) then return true end
		if S.FishBoat and enemyBoat({"FishBoat"}) then return true end
		if S.SeaBeast and seaBeast() then return true end
		if S.Leviathan and leviathan() then return true end
		return false
	end
	local function sailTo(cf)
		local r, h = root(), hum()
		if not r or not h then return end
		local boat = myBoat()
		if not boat then
			move(DOCK)
			if (r.Position - DOCK.Position).Magnitude <= 12 then
				pcall(function() CommF_:InvokeServer("BuyBoat", C.Boat) end)
			end
			return
		end
		local seat = boat:FindFirstChildWhichIsA("VehicleSeat")
		if not seat then return end
		if not h.Sit then
			move(seat.CFrame * CFrame.new(0, 1, 0))
		elseif not targetUp() then
			local y = (anyThreat() and cf.Position.Y + 150) or cf.Position.Y
			move(CFrame.new(cf.Position.X, y, cf.Position.Z))
		end
	end
	local function attackSeaBeast(b, seg)
		local hrp = b:FindFirstChild("HumanoidRootPart") if not hrp then return end
		local water = workspace.Map:FindFirstChild("WaterBase-Plane")
		local y = (water and water.Position.Y or 0) + 200
		move(CFrame.new(hrp.Position.X, y, hrp.Position.Z))
		local t = (seg and b:FindFirstChild(seg)) or hrp
		aimAt(t.Position)
		if hasBigFruit() then useSkills("Blox Fruit", {"Z", "X", "C"}) else skillBurst() end
	end
	local function attackBoat(b)
		local eng = b:FindFirstChild("Engine") if not eng then return end
		local off = Vector3.new(0, -50, -25)
		if b.Name == "PirateBrigade" then off = Vector3.new(0, -30, -10)
		elseif b.Name == "PirateGrandBrigade" then off = Vector3.new(0, -50, -50) end
		move(eng.CFrame * CFrame.new(off))
		aimAt(eng.Position)
		if hasBigFruit() then useSkills("Blox Fruit", {"Z", "X", "C"}) else skillBurst() end
	end
	local function loc(n)
		local o = workspace:FindFirstChild("_WorldOrigin")
		local l = o and o:FindFirstChild("Locations")
		return l and l:FindFirstChild(n)
	end

	-- =========================================================
	-- SEA EVENT TAB
	-- =========================================================
	local SeaTab = Window:CreateTab({ Name = "Sea Event", Icon = "sea" })

	local SailGroup = SeaTab:AddGroup("Left", "Sail Settings")
	SailGroup:AddDropdown({Text = "Weapon Type", Options = {"Melee", "Sword", "Blox Fruit", "Gun"}, Default = "Melee",
		Callback = function(v) C.Weapon = v end})
	SailGroup:AddSlider({Text = "Tween Speed", Suffix = "", Min = 50, Max = 400, Step = 5, Decimals = 0, Default = 250,
		Callback = function(v) C.Speed = v end})
	SailGroup:AddToggle({Text = "Ship Speed Modifier", Default = false, Callback = function(v) S.SpeedBoat = v end})
	SailGroup:AddSlider({Text = "Ship Speed", Suffix = "", Min = 0, Max = 1000, Step = 10, Decimals = 0, Default = 300,
		Callback = function(v) C.BoatSpeed = v end})
	SailGroup:AddToggle({Text = "Auto Press W", Default = false, Callback = function(v) S.AutoW = v end})
	SailGroup:AddToggle({Text = "No Clip Ship", Default = false, Callback = function(v) S.NoClipShip = v end})
	SailGroup:AddButton({Text = "Remove Lighting Effect", Callback = function()
		pcall(function() Lighting.BaseAtmosphere:Destroy() end)
	end})

	local BoatGroup = SeaTab:AddGroup("Left", "Boat / Danger Zone")
	BoatGroup:AddDropdown({
		Text = "Select Boat",
		Options = {"Guardian", "PirateGrandBrigade", "MarineGrandBrigade", "PirateBrigade", "MarineBrigade", "PirateSloop", "MarineSloop", "Beast Hunter"},
		Default = "Guardian", Callback = function(v) C.Boat = v end
	})
	BoatGroup:AddDropdown({
		Text = "Select Sea Level",
		Options = {"Lv 1", "Lv 2", "Lv 3", "Lv 4", "Lv 5", "Lv 6", "Lv Infinite"},
		Default = "Lv 6", Callback = function(v) C.Zone = v end
	})
	BoatGroup:AddButton({Text = "Buy Boat", Primary = true, Callback = function()
		pcall(function() CommF_:InvokeServer("BuyBoat", C.Boat) end)
	end})
	BoatGroup:AddToggle({Text = "Auto Sail Boat", Desc = "Buys boat, sits, sails to the zone", Default = false,
		Callback = function(v) S.Sail = v setActive("SS_Sail", v) end})

	local EntGroup = SeaTab:AddGroup("Left", "Sea Entities")
	local function entToggle(text, key, desc)
		EntGroup:AddToggle({Text = text, Desc = desc, Default = false, Callback = function(v)
			S[key] = v setActive("SS_" .. key, v)
		end})
	end
	entToggle("Auto Shark", "Shark")
	entToggle("Auto Piranha", "Piranha")
	entToggle("Auto Terror Shark", "Terror")
	entToggle("Auto Fish Crew Member", "Crew")
	entToggle("Auto Haunted Crew Member", "Haunted")
	entToggle("Auto PirateGrandBrigade", "PGB")
	entToggle("Auto Fish Boat", "FishBoat")
	entToggle("Auto Sea Beast", "SeaBeast")

	-- Kitsune
	local KitGroup = SeaTab:AddGroup("Right", "Kitsune Island")
	KitGroup:AddToggle({Text = "Auto Find Kitsune Island", Default = false,
		Callback = function(v) S.FindKit = v setActive("SS_FindKit", v) end})
	KitGroup:AddToggle({Text = "Auto Tween to Shrine", Default = false,
		Callback = function(v) S.Shrine = v setActive("SS_Shrine", v) end})
	KitGroup:AddToggle({Text = "Auto Collect Azure Ember", Default = false,
		Callback = function(v) S.Ember = v setActive("SS_Ember", v) end})
	KitGroup:AddToggle({Text = "Auto Trade Azure Ember", Default = false, Callback = function(v) S.Trade = v end})
	KitGroup:AddButton({Text = "Trade Items Azure", Callback = function()
		pcall(function() net("RF/KitsuneStatuePray"):InvokeServer() end)
	end})
	KitGroup:AddButton({Text = "Talk with Kitsune Statue", Callback = function()
		pcall(function() net("RE/TouchKitsuneStatue"):FireServer() end)
	end})
	KitGroup:AddButton({Text = "Print Kitsune Status", Callback = function()
		print("[Kitsune] Spawned:", loc("Kitsune Island") ~= nil or (workspace.Map:FindFirstChild("KitsuneIsland") ~= nil))
	end})

	-- Frozen
	local FrozenGroup = SeaTab:AddGroup("Right", "Frozen Dimension")
	FrozenGroup:AddToggle({Text = "Auto Teleport Frozen Dimension", Default = false,
		Callback = function(v) S.Frozen = v setActive("SS_Frozen", v) end})
	FrozenGroup:AddToggle({Text = "Auto Drive To Hydra Island", Default = false,
		Callback = function(v) S.Hydra = v setActive("SS_Hydra", v) end})
	FrozenGroup:AddToggle({Text = "Auto Attack Leviathan", Default = false,
		Callback = function(v) S.Leviathan = v setActive("SS_Lev", v) end})
	FrozenGroup:AddButton({Text = "Buy Spy", Callback = function()
		pcall(function() CommF_:InvokeServer("InfoLeviathan", "2") end)
	end})
	FrozenGroup:AddButton({Text = "Print Spy / Frozen Status", Callback = function()
		local ok, res = pcall(function() return CommF_:InvokeServer("InfoLeviathan", "1") end)
		local n = ok and tostring(res):match("%d+")
		print("[Leviathan Spy]", n and (tonumber(n) >= 5 and "Already done" or (n .. "/5")) or "?",
			"| Frozen:", loc("Frozen Dimension") ~= nil)
	end})

	-- Crafting
	local CraftGroup = SeaTab:AddGroup("Right", "Sea Crafting")
	for _, item in ipairs({"SharkTooth", "TerrorJaw", "SharkAnchor", "LeviathanCrown", "LeviathanShield", "LeviathanBoat", "LegendaryScroll", "MythicalScroll"}) do
		CraftGroup:AddButton({Text = "Craft " .. item, Callback = function()
			pcall(function() CommF_:InvokeServer("CraftItem", "Craft", item) end)
		end})
	end

	-- ===== sea loops =====
	loop(0.25, function()
		if S.SpeedBoat then
			local h = hum()
			if h and h.Sit then
				local b = workspace:FindFirstChild("Boats")
				if b then
					for _, v in ipairs(b:GetChildren()) do
						local seat = v:FindFirstChildWhichIsA("VehicleSeat")
						if seat then seat.MaxSpeed = C.BoatSpeed end
					end
				end
			end
		end
		if S.AutoW then
			local h = hum()
			if h and h.Sit then
				VIM:SendKeyEvent(true, "W", false, game)
				task.wait(0.1)
				VIM:SendKeyEvent(false, "W", false, game)
			end
		end
	end)

	loop(0.5, function()
		local b = workspace:FindFirstChild("Boats") if not b then return end
		local off = S.NoClipShip or S.Sail or S.FindKit or S.Hydra
		for _, boat in ipairs(b:GetChildren()) do
			for _, d in ipairs(boat:GetDescendants()) do
				if d:IsA("BasePart") then pcall(function() d.CanCollide = not off end) end
			end
		end
	end)

	loop(0.3, function()
		if S.Sail then sailTo(ZONES[C.Zone] or ZONES["Lv 6"]) end
		if S.Hydra then sailTo(CFrame.new(5433, 35, 290)) end
		if S.FindKit then
			local l = loc("Kitsune Island")
			if l then move(l.CFrame * CFrame.new(0, 500, 0)) else sailTo(ZONES["Lv Infinite"]) end
		end
	end)

	loop(0.2, function()
		if S.Shark then local e = findEnemy("Shark") if e then kill(e) end end
		if S.Piranha then local e = findEnemy("Piranha") if e then kill(e) end end
		if S.Crew then local e = findEnemy("Fish Crew Member") if e then kill(e) end end
		if S.Haunted then local e = findEnemy("Haunted Crew Member") if e then kill(e) end end
		if S.Terror then local e = findEnemy("Terrorshark") if e then killSea(e) end end
		if S.PGB then local b = enemyBoat({"PirateGrandBrigade", "PirateBrigade"}) if b then attackBoat(b) end end
		if S.FishBoat then local b = enemyBoat({"FishBoat"}) if b then attackBoat(b) end end
		if S.SeaBeast then local b = seaBeast() if b then attackSeaBeast(b) end end
		if S.Leviathan then local b = leviathan() if b then attackSeaBeast(b, "Leviathan Segment") end end
	end)

	loop(0.3, function()
		if S.Shrine then
			local map = workspace:FindFirstChild("Map")
			local kit = map and map:FindFirstChild("KitsuneIsland")
			local shrine = kit and kit:FindFirstChild("ShrineActive")
			if shrine then
				for _, d in ipairs(shrine:GetDescendants()) do
					if d:IsA("BasePart") and d.Name:find("NeonShrinePart") then
						pcall(function() net("RE/TouchKitsuneStatue"):FireServer() end)
						move(d.CFrame * CFrame.new(0, 2, 0))
						return
					end
				end
			else
				local l = loc("Kitsune Island")
				if l then move(l.CFrame * CFrame.new(0, 500, 0)) end
			end
		end
		if S.Ember then
			local et = workspace:FindFirstChild("EmberTemplate")
			local part = et and et:FindFirstChild("Part")
			if part then
				notween(part.CFrame)
			else
				local l = loc("Kitsune Island")
				if l then
					move(l.CFrame * CFrame.new(0, 500, 0))
					pcall(function() net("RF/KitsuneStatuePray"):InvokeServer() end)
				end
			end
		end
		if S.Trade and loc("Kitsune Island") then
			pcall(function() net("RF/KitsuneStatuePray"):InvokeServer() end)
		end
		if S.Frozen then
			local map = workspace:FindFirstChild("Map")
			local gate = map and map:FindFirstChild("LeviathanGate")
			if gate then
				move(gate.CFrame)
				pcall(function() CommF_:InvokeServer("OpenLeviathanGate") end)
			end
		end
	end)

	-- =========================================================
	-- SETTINGS TAB
	-- =========================================================
	local SetTab = Window:CreateTab({ Name = "Settings", Icon = "settings" })

	local CombatGroup = SetTab:AddGroup("Left", "Combat / Farm")
	CombatGroup:AddToggle({Text = "Fast Attack", Desc = "Also in your Farming tab — use one", Default = true,
		Callback = function(v) S.FastAttack = v end})
	CombatGroup:AddToggle({Text = "Bring Mobs", Default = true, Callback = function(v) S.Bring = v end})
	CombatGroup:AddToggle({Text = "Spin XYZ (circle target)", Default = false, Callback = function(v) S.Spin = v end})
	CombatGroup:AddToggle({Text = "Safe Mode", Desc = "Fly up when HP drops low", Default = false, Callback = function(v) S.Safe = v end})
	CombatGroup:AddSlider({Text = "Safe Mode HP %", Suffix = "%", Min = 5, Max = 80, Step = 1, Decimals = 0, Default = 25,
		Callback = function(v) C.SafeHP = v end})

	local AbilityGroup = SetTab:AddGroup("Left", "Auto Abilities")
	AbilityGroup:AddToggle({Text = "Auto Buso Haki", Default = true, Callback = function(v) S.Buso = v end})
	AbilityGroup:AddToggle({Text = "Auto Haki Observation", Default = false, Callback = function(v) S.Ken = v end})
	AbilityGroup:AddToggle({Text = "Auto Race V3", Desc = "Activates every 30s", Default = false, Callback = function(v) S.V3 = v end})
	AbilityGroup:AddToggle({Text = "Auto Race V4", Desc = "Presses Y at full energy", Default = false, Callback = function(v) S.V4 = v end})

	local ServerGroup = SetTab:AddGroup("Left", "Server")
	ServerGroup:AddToggle({Text = "Auto Hop Server (timer)", Default = false, Callback = function(v)
		S.AutoHop = v
		S.HopTimer = v and os.clock() or nil
	end})
	ServerGroup:AddSlider({Text = "Hop Delay", Suffix = " min", Min = 5, Max = 120, Step = 1, Decimals = 0, Default = 30,
		Callback = function(v) C.HopDelay = v end})
	ServerGroup:AddToggle({Text = "Anti-Admin Join (hop)", Default = true, Callback = function(v) S.AntiAdmin = v end})
	ServerGroup:AddToggle({Text = "Anti AFK", Default = true, Callback = function(v) S.AFK = v end})
	ServerGroup:AddToggle({Text = "Auto Set Spawn Point", Default = false, Callback = function(v)
		S.Spawn = v
		if v then pcall(function() CommF_:InvokeServer("SetSpawnPoint") end) end
	end})
	ServerGroup:AddButton({Text = "Set Spawn Point Now", Callback = function()
		pcall(function() CommF_:InvokeServer("SetSpawnPoint") end)
	end})

	local VisualGroup = SetTab:AddGroup("Right", "Visuals / Performance")
	VisualGroup:AddToggle({Text = "Remove Hit VFX", Default = false, Callback = function(v) S.NoHit = v end})
	VisualGroup:AddToggle({Text = "Remove Death / Respawn VFX", Default = false, Callback = function(v) S.NoDeath = v end})
	VisualGroup:AddToggle({Text = "Disable Notifications", Default = false, Callback = function(v) S.NoNotify = v end})
	VisualGroup:AddToggle({Text = "No Clip", Default = false, Callback = function(v)
		S.NoClip = v
		if not v then
			pcall(function()
				for _, d in ipairs(plr.Character:GetDescendants()) do
					if d:IsA("BasePart") then d.CanCollide = true end
				end
			end)
		end
	end})

	-- ===== settings loops =====
	loop(0.1, function()
		if S.FastAttack then attack() end
		if S.Ken then pcall(function() CommE:FireServer("Ken", true) end) end
		if S.V4 then
			local c = plr.Character
			local e = c and c:FindFirstChild("RaceEnergy")
			if e and e.Value == 1 then press("Y") end
		end
		if S.Safe then
			local h, r = hum(), root()
			if h and r and h.MaxHealth > 0 and (h.Health / h.MaxHealth * 100) < C.SafeHP then
				setActive("SS_Safe", true)
				move(r.CFrame * CFrame.new(0, 500, 0))
			else
				setActive("SS_Safe", false)
			end
		end
	end)

	loop(0.5, function()
		if S.Buso and plr.Character and not plr.Character:FindFirstChild("HasBuso") then
			pcall(function() CommF_:InvokeServer("Buso") end)
		end
		if S.Bring then
			local r = root() if not r then return end
			if sethiddenproperty then pcall(function() sethiddenproperty(plr, "SimulationRadius", math.huge) end) end
			local f = eFolder() if not f then return end
			local best, bd
			for _, e in ipairs(f:GetChildren()) do
				local hrp = e:FindFirstChild("HumanoidRootPart")
				if alive(e) and hrp then
					local d = (hrp.Position - r.Position).Magnitude
					if not bd or d < bd then best, bd = e, d end
				end
			end
			if not best then return end
			local pos = best.HumanoidRootPart.Position
			for _, e in ipairs(f:GetChildren()) do
				if e ~= best and e.Name == best.Name then
					local h = e:FindFirstChildOfClass("Humanoid")
					local hrp = e:FindFirstChild("HumanoidRootPart")
					if h and hrp and h.Health > 0 and (hrp.Position - pos).Magnitude <= 3000 then
						pcall(function()
							if not hrp:FindFirstChild("BodyVelocity") then
								local bv = Instance.new("BodyVelocity")
								bv.MaxForce = Vector3.new(1e9, 1e9, 1e9) bv.Velocity = Vector3.zero bv.Parent = hrp
							end
							if not isnetworkowner or isnetworkowner(hrp) then hrp.CFrame = CFrame.new(pos) end
							hrp.CanCollide = false h.WalkSpeed = 0 h.JumpPower = 0
						end)
					end
				end
			end
		end
	end)

	local lastV3 = 0
	loop(1, function()
		if S.V3 and os.clock() - lastV3 >= 30 then
			lastV3 = os.clock()
			pcall(function() CommE:FireServer("ActivateAbility") end)
		end
		if S.NoHit then
			local o = workspace:FindFirstChild("_WorldOrigin")
			if o then
				for _, v in ipairs(o:GetChildren()) do
					if table.find({"SlashHit", "CurvedRing", "SwordSlash", "SlashTail"}, v.Name) then v:Destroy() end
				end
			end
		end
		if S.NoDeath then
			pcall(function()
				local c = RS.Effect.Container
				if c:FindFirstChild("Death") then c.Death:Destroy() end
				if c:FindFirstChild("Respawn") then c.Respawn:Destroy() end
			end)
		end
		pcall(function()
			RS.Assets.GUI.DamageCounter.Enabled = not S.NoNotify
			plr.PlayerGui.Notifications.Enabled = not S.NoNotify
		end)
		if S.AutoHop then
			S.HopTimer = S.HopTimer or os.clock()
			if os.clock() - S.HopTimer >= C.HopDelay * 60 then
				S.HopTimer = os.clock()
				TPS:Teleport(game.PlaceId, plr)
			end
		end
		if S.AntiAdmin then
			local admins = {"red_game43","rip_indra","Axiore","Polkster","wenlocktoad","Daigrock","toilamvidamme",
				"oofficialnoobie","Uzoth","Azarth","arlthmetic","Death_King","Lunoven","TheGreateAced","rip_fud",
				"drip_mama","layandikit12","Hingoi"}
			for _, p in ipairs(Players:GetPlayers()) do
				if table.find(admins, p.Name) then hop() return end
			end
		end
	end)

	loop(30, function()
		if S.Spawn then pcall(function() CommF_:InvokeServer("SetSpawnPoint") end) end
	end)

	plr.Idled:Connect(function()
		if not S.AFK then return end
		VU:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
		task.wait(1)
		VU:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
	end)

	RunService.Stepped:Connect(function()
		if not S.NoClip then return end
		pcall(function()
			for _, d in ipairs(plr.Character:GetDescendants()) do
				if d:IsA("BasePart") then d.CanCollide = false end
			end
		end)
	end)
end

-- // ================= SIDEBAR SCROLL FIX =================
-- Paste this at the VERY BOTTOM of your script
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local plr = Players.LocalPlayer

-- Names of your tabs (add any new ones here)
local TAB_NAMES = {
	"Farming", "Teleport", "Misc", "Stats & Esp", "Quest & Items", 
	"Fruit & Raid", "Volcano", "Mirage & Race", "Info", "Settings", 
	"Sea Event", "Fishing", "Local Player", "Shopping"
}

local function findSidebar()
	local roots = {plr:WaitForChild("PlayerGui")}
	pcall(function() table.insert(roots, gethui()) end)

	for _, root in ipairs(roots) do
		for _, obj in ipairs(root:GetDescendants()) do
			if obj:IsA("Frame") or obj:IsA("ScrollingFrame") then
				local matches = 0
				for _, child in ipairs(obj:GetChildren()) do
					-- Check if child is a tab button (Frame with TextLabel or just TextButton)
					local textLabel = child:FindFirstChildWhichIsA("TextLabel")
					if not textLabel and child:IsA("TextButton") then textLabel = child end

					if textLabel and table.find(TAB_NAMES, textLabel.Text) then
						matches += 1
					end
				end
				-- If we found at least 4 tabs, this is the sidebar container
				if matches >= 4 then
					return obj
				end
			end
		end
	end
	return nil
end

local sidebar = findSidebar()
if sidebar then
	print("[ScrollFix] Found sidebar:", sidebar:GetFullName())

	-- If it's already a ScrollingFrame, just fix properties
	if sidebar:IsA("ScrollingFrame") then
		sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
		sidebar.ScrollBarThickness = 4
		sidebar.ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255)
		sidebar.ScrollBarImageTransparency = 0.8
	else
		-- It's a Frame, we need to wrap it in a ScrollingFrame
		local scrollFrame = Instance.new("ScrollingFrame")
		scrollFrame.Name = "TabScrollContainer"
		scrollFrame.BackgroundTransparency = 1
		scrollFrame.BorderSizePixel = 0
		scrollFrame.Size = UDim2.fromScale(1, 1)
		scrollFrame.Position = UDim2.fromScale(0, 0)
		scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scrollFrame.ScrollBarThickness = 4
		scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255)
		scrollFrame.ScrollBarImageTransparency = 0.8
		scrollFrame.ClipsDescendants = true
		scrollFrame.Parent = sidebar

		-- Move all tab buttons into the scroll frame
		for _, child in ipairs(sidebar:GetChildren()) do
			if child ~= scrollFrame and not child:IsA("UIListLayout") and not child:IsA("UIPadding") and not child:IsA("UICorner") then
				child.Parent = scrollFrame
			end
		end

		-- Keep UIListLayout in the scroll frame
		local layout = sidebar:FindFirstChildWhichIsA("UIListLayout")
		if layout then
			layout.Parent = scrollFrame
		end
	end

	-- Mouse wheel support
	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			local scroll = sidebar:FindFirstChild("TabScrollContainer") or (sidebar:IsA("ScrollingFrame") and sidebar)
			if scroll and scroll:IsA("ScrollingFrame") then
				local mousePos = UserInputService:GetMouseLocation()
				local absPos = scroll.AbsolutePosition
				local absSize = scroll.AbsoluteSize
				if mousePos.X >= absPos.X and mousePos.X <= absPos.X + absSize.X and
				   mousePos.Y >= absPos.Y and mousePos.Y <= absPos.Y + absSize.Y then
					scroll.CanvasPosition = Vector2.new(0, scroll.CanvasPosition.Y - input.Position.Z * 50)
				end
			end
		end
	end)
else
	warn("[ScrollFix] Could not find the tab sidebar. Make sure all tabs are created before running this.")
end
