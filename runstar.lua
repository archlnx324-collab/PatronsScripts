-- // Obsidian UI - Multi-World Auto Farm Controller (Complete)

-- // 1. Load the core Obsidian UI Library
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/deividcomsono/Obsidian/main/Library.lua"))()
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ============================================================
-- // WORLD 1 REMOTES & MAPPINGS
-- ============================================================
local W1_AddSpeedRemote, W1_RacePrepare, W1_RaceStart, W1_RaceEnd, W1_RaceReward, W1_EggHatchRemote = nil, nil, nil, nil, nil, nil

pcall(function()
	local Remotes = ReplicatedStorage:WaitForChild("Remotes", 3)
	
	local TrainFolder = Remotes:WaitForChild("Train", 3)
	W1_AddSpeedRemote = TrainFolder:WaitForChild("AddSpeed", 3)
	
	local RaceFolder = Remotes:WaitForChild("Race", 3)
	W1_RacePrepare = RaceFolder:WaitForChild("RacePrepare", 3)
	W1_RaceStart = RaceFolder:WaitForChild("RaceStart", 3)
	W1_RaceEnd = RaceFolder:WaitForChild("RaceEnd", 3)
	W1_RaceReward = RaceFolder:WaitForChild("RaceReward", 3)
	
	local HatchFolder = Remotes:WaitForChild("Hatch", 3)
	W1_EggHatchRemote = HatchFolder:WaitForChild("EggHatch", 3)
end)

local W1_LABEL_TO_ID = {["+1 Speed"]="1", ["+5 Speed"]="2", ["+10 Speed"]="3", ["+20 Speed"]="4", ["+25 Speed"]="5", ["+30 Speed"]="6"}
local W1_SORTED_LABELS = { "+1 Speed", "+5 Speed", "+10 Speed", "+20 Speed", "+25 Speed", "+30 Speed" }

local W1_RACE_TYPES = {["More Wins Race"] = {true, 1, 1}, ["Standard Race"] = {true, 1, 3}}
local W1_SORTED_RACE_TYPES = { "More Wins Race", "Standard Race" }

local W1_EGG_REMOTE_ARGS = {["Common Egg"] = {1, "Open1", {}}, ["Uncommon Egg"] = {1, "Open3", {}}, ["Rare Egg"] = {3, "Open1", {}}, ["Epic Egg"] = {4, "Open1", {}}}
local W1_SORTED_EGGS = { "Common Egg", "Uncommon Egg", "Rare Egg", "Epic Egg" }

-- ============================================================
-- // WORLD 2 REMOTES & MAPPINGS
-- ============================================================
local W2_AddSpeedRemote, W2_RacePrepare, W2_RaceStart, W2_RaceEnd, W2_RaceReward, W2_EggHatchRemote = nil, nil, nil, nil, nil, nil

pcall(function()
	local Remotes = ReplicatedStorage:WaitForChild("Remotes", 3)
	
	local TrainFolder = Remotes:WaitForChild("Train", 3)
	W2_AddSpeedRemote = TrainFolder:WaitForChild("AddSpeed", 3)
	
	local RaceFolder = Remotes:WaitForChild("Race", 3)
	W2_RacePrepare = RaceFolder:WaitForChild("RacePrepare", 3)
	W2_RaceStart = RaceFolder:WaitForChild("RaceStart", 3)
	W2_RaceEnd = RaceFolder:WaitForChild("RaceEnd", 3)
	W2_RaceReward = RaceFolder:WaitForChild("RaceReward", 3)
	
	local HatchFolder = Remotes:WaitForChild("Hatch", 3)
	W2_EggHatchRemote = HatchFolder:WaitForChild("EggHatch", 3)
end)

local W2_LABEL_TO_ID = {
    ["+40 Speed"] = "8", ["+60 Speed"] = "9", ["+80 Speed"] = "10",
    ["+100 Speed"] = "11", ["+150 Speed"] = "12", ["+200 Speed"] = "13"
}
local W2_SORTED_LABELS = { "+40 Speed", "+60 Speed", "+80 Speed", "+100 Speed", "+150 Speed", "+200 Speed" }

local W2_RACE_TYPES = {["World 2 Race"] = {true, 2, 3}}
local W2_SORTED_RACE_TYPES = { "World 2 Race" }

local W2_EGG_REMOTE_ARGS = {
    ["Common Egg"]    = {5, "Open1", {}},
    ["Uncommon Egg"]  = {6, "Open1", {}},
    ["Rare Egg"]      = {7, "Open1", {}},
    ["Epic Egg"]      = {8, "Open1", {}},
    ["Legendary Egg"] = {9, "Open1", {}},
    ["Mythic Egg"]    = {10, "Open1", {}}
}
local W2_SORTED_EGGS = { "Common Egg", "Uncommon Egg", "Rare Egg", "Epic Egg", "Legendary Egg", "Mythic Egg" }

-- ============================================================
-- // CREATE THE UI WINDOW
-- ============================================================
local Window = Library:CreateWindow({
	Title = "Multi-World Auto Farm",
	Footer = "World 1 & World 2 • Obsidian UI",
	Center = true,
	AutoShow = true,
	NotifySide = "Right",
})

local TabWorld1 = Window:AddTab("Auto Farm World 1", "globe")
local TabWorld2 = Window:AddTab("Auto Farm World 2", "globe-2")

-- ============================================================
-- // WORLD 1 UI CONTROLS
-- ============================================================
local W1_TreadmillGroup = TabWorld1:AddGroupbox({ Side = "Left", Name = "Treadmill Controls" })
W1_TreadmillGroup:AddDropdown("W1_SpeedSelect", { Values = W1_SORTED_LABELS, Default = "+1 Speed", Multi = false, Text = "Select Speed Amount", Searchable = false })
W1_TreadmillGroup:AddDivider()
W1_TreadmillGroup:AddSlider("W1_TreadmillBurst", { Text = "Burst Amount (Per Frame)", Default = 1, Min = 1, Max = 10, Rounding = 0 })
W1_TreadmillGroup:AddDivider()

local w1_treadmillThread = nil
W1_TreadmillGroup:AddToggle("W1_LoopSpeed", {
	Text = "Loop Add Speed (Burst)", Default = false, Risky = true,
	Callback = function(Value)
		if not W1_AddSpeedRemote then Library:Notify({ Title = "Error", Description = "W1 AddSpeed remote not found!", Time = 4 }); Library.Toggles.W1_LoopSpeed:SetValue(false); return end
		if Value then
			w1_treadmillThread = task.spawn(function()
				while Library.Toggles.W1_LoopSpeed.Value do
					local burst = Library.Options.W1_TreadmillBurst.Value
					local targetID = W1_LABEL_TO_ID[Library.Options.W1_SpeedSelect.Value]
					for i = 1, burst do task.spawn(function() pcall(function() W1_AddSpeedRemote:FireServer(targetID) end) end) end
					task.wait()
				end
			end)
			Library:Notify({ Title = "Loop Started", Description = "Farming " .. Library.Options.W1_SpeedSelect.Value, Time = 3 })
		else
			if w1_treadmillThread then task.cancel(w1_treadmillThread) w1_treadmillThread = nil end
			Library:Notify({ Title = "Loop Stopped", Description = "Treadmill loop terminated.", Time = 3 })
		end
	end,
})

local W1_RaceGroup = TabWorld1:AddGroupbox({ Side = "Right", Name = "Race Controls" })
W1_RaceGroup:AddDropdown("W1_RaceTypeSelect", { Values = W1_SORTED_RACE_TYPES, Default = "More Wins Race", Multi = false, Text = "Select Race Type", Searchable = false })
W1_RaceGroup:AddDivider()

local function runW1Race()
	pcall(function() W1_RacePrepare:InvokeServer() end)
	pcall(function() W1_RaceStart:FireServer() end)
	pcall(function() W1_RaceEnd:InvokeServer(0) end)
	local raceArgs = W1_RACE_TYPES[Library.Options.W1_RaceTypeSelect.Value]
	pcall(function() W1_RaceReward:FireServer(table.unpack(raceArgs)) end)
end

W1_RaceGroup:AddButton({ Text = "Run Race Once", Func = function()
	if not (W1_RacePrepare and W1_RaceStart and W1_RaceEnd and W1_RaceReward) then Library:Notify({ Title = "Error", Description = "Race remotes not found!", Time = 4 }); return end
	runW1Race(); Library:Notify({ Title = "Race", Description = Library.Options.W1_RaceTypeSelect.Value .. " executed!", Time = 2 })
end })
W1_RaceGroup:AddDivider()

local w1_raceThread = nil
W1_RaceGroup:AddToggle("W1_LoopRace", {
	Text = "Loop Race", Default = false, Risky = true,
	Callback = function(Value)
		if not (W1_RacePrepare and W1_RaceStart and W1_RaceEnd and W1_RaceReward) then Library:Notify({ Title = "Error", Description = "Race remotes not found!", Time = 4 }); Library.Toggles.W1_LoopRace:SetValue(false); return end
		if Value then
			w1_raceThread = task.spawn(function()
				while Library.Toggles.W1_LoopRace.Value do runW1Race(); task.wait() end
			end)
			Library:Notify({ Title = "Race Loop", Description = "Started farming: " .. Library.Options.W1_RaceTypeSelect.Value, Time = 2 })
		else
			if w1_raceThread then task.cancel(w1_raceThread) w1_raceThread = nil end
			Library:Notify({ Title = "Race Loop", Description = "Stopped.", Time = 2 })
		end
	end,
})

local W1_HatchGroup = TabWorld1:AddGroupbox({ Side = "Right", Name = "Hatchery Controls" })
W1_HatchGroup:AddLabel("🥚 Common = 5 Wins"); W1_HatchGroup:AddLabel("🥚 Uncommon = 50 Wins"); W1_HatchGroup:AddLabel("🥚 Rare = 250 Wins"); W1_HatchGroup:AddLabel("🥚 Epic = 3,000 Wins"); W1_HatchGroup:AddDivider()
W1_HatchGroup:AddDropdown("W1_EggSelect", { Values = W1_SORTED_EGGS, Default = "Common Egg", Multi = false, Text = "Select Egg to Hatch", Searchable = false }); W1_HatchGroup:AddDivider()
W1_HatchGroup:AddButton({ Text = "🥚 Hatch Once", Func = function()
	if not W1_EggHatchRemote then Library:Notify({ Title = "Error", Description = "EggHatch remote not found!", Time = 4 }); return end
	local args = W1_EGG_REMOTE_ARGS[Library.Options.W1_EggSelect.Value]
	pcall(function() W1_EggHatchRemote:InvokeServer(table.unpack(args)) end)
	Library:Notify({ Title = "Hatched", Description = "Opened: " .. Library.Options.W1_EggSelect.Value, Time = 2 })
end }); W1_HatchGroup:AddDivider()

local w1_hatchThread = nil
W1_HatchGroup:AddToggle("W1_LoopHatch", {
	Text = "Auto Hatch Loop", Default = false, Risky = true,
	Callback = function(Value)
		if not W1_EggHatchRemote then Library:Notify({ Title = "Error", Description = "EggHatch remote not found!", Time = 4 }); Library.Toggles.W1_LoopHatch:SetValue(false); return end
		if Value then
			w1_hatchThread = task.spawn(function()
				while Library.Toggles.W1_LoopHatch.Value do
					local args = W1_EGG_REMOTE_ARGS[Library.Options.W1_EggSelect.Value]
					pcall(function() W1_EggHatchRemote:InvokeServer(table.unpack(args)) end)
					task.wait(0.1)
				end
			end)
			Library:Notify({ Title = "Hatch Loop Started", Description = "Spamming: " .. Library.Options.W1_EggSelect.Value, Time = 2 })
		else
			if w1_hatchThread then task.cancel(w1_hatchThread) w1_hatchThread = nil end
			Library:Notify({ Title = "Hatch Loop Stopped", Description = "Stopped hatching.", Time = 2 })
		end
	end,
})

-- ============================================================
-- // WORLD 2 UI CONTROLS
-- ============================================================
local W2_TreadmillGroup = TabWorld2:AddGroupbox({ Side = "Left", Name = "Treadmill Controls" })
W2_TreadmillGroup:AddDropdown("W2_SpeedSelect", { Values = W2_SORTED_LABELS, Default = "+40 Speed", Multi = false, Text = "Select Speed Amount", Searchable = false })
W2_TreadmillGroup:AddDivider()
W2_TreadmillGroup:AddSlider("W2_TreadmillBurst", { Text = "Burst Amount (Per Frame)", Default = 1, Min = 1, Max = 10, Rounding = 0 })
W2_TreadmillGroup:AddDivider()

local w2_treadmillThread = nil
W2_TreadmillGroup:AddToggle("W2_LoopSpeed", {
	Text = "Loop Add Speed (Burst)", Default = false, Risky = true,
	Callback = function(Value)
		if not W2_AddSpeedRemote then Library:Notify({ Title = "Error", Description = "W2 AddSpeed remote not found!", Time = 4 }); Library.Toggles.W2_LoopSpeed:SetValue(false); return end
		if Value then
			w2_treadmillThread = task.spawn(function()
				while Library.Toggles.W2_LoopSpeed.Value do
					local burst = Library.Options.W2_TreadmillBurst.Value
					local targetID = W2_LABEL_TO_ID[Library.Options.W2_SpeedSelect.Value]
					for i = 1, burst do task.spawn(function() pcall(function() W2_AddSpeedRemote:FireServer(targetID) end) end) end
					task.wait()
				end
			end)
			Library:Notify({ Title = "Loop Started", Description = "Farming " .. Library.Options.W2_SpeedSelect.Value, Time = 3 })
		else
			if w2_treadmillThread then task.cancel(w2_treadmillThread) w2_treadmillThread = nil end
			Library:Notify({ Title = "Loop Stopped", Description = "Treadmill loop terminated.", Time = 3 })
		end
	end,
})

local W2_RaceGroup = TabWorld2:AddGroupbox({ Side = "Right", Name = "Race Controls" })
W2_RaceGroup:AddDropdown("W2_RaceTypeSelect", { Values = W2_SORTED_RACE_TYPES, Default = "World 2 Race", Multi = false, Text = "Select Race Type", Searchable = false })
W2_RaceGroup:AddDivider()
W2_RaceGroup:AddSlider("W2_RaceBurst", { Text = "Burst Amount (Per Frame)", Default = 1, Min = 1, Max = 10, Rounding = 0, Tooltip = "Higher = faster races!" })
W2_RaceGroup:AddDivider()

local function runW2Race()
    pcall(function() W2_RacePrepare:InvokeServer() end)
    pcall(function() W2_RaceStart:FireServer() end)
    pcall(function() W2_RaceEnd:InvokeServer(0) end)
    local raceArgs = W2_RACE_TYPES[Library.Options.W2_RaceTypeSelect.Value]
    pcall(function() W2_RaceReward:FireServer(table.unpack(raceArgs)) end)
end

W2_RaceGroup:AddButton({ Text = "Run Race Once", Func = function()
    if not (W2_RacePrepare and W2_RaceStart and W2_RaceEnd and W2_RaceReward) then Library:Notify({ Title = "Error", Description = "W2 Race remotes not found!", Time = 4 }); return end
    runW2Race(); Library:Notify({ Title = "Race", Description = Library.Options.W2_RaceTypeSelect.Value .. " executed!", Time = 2 })
end })
W2_RaceGroup:AddDivider()

local w2_raceThread = nil
W2_RaceGroup:AddToggle("W2_LoopRace", {
    Text = "Loop Race (Burst)", Default = false, Risky = true,
    Callback = function(Value)
        if not (W2_RacePrepare and W2_RaceStart and W2_RaceEnd and W2_RaceReward) then Library:Notify({ Title = "Error", Description = "W2 Race remotes not found!", Time = 4 }); Library.Toggles.W2_LoopRace:SetValue(false); return end
        if Value then
            w2_raceThread = task.spawn(function()
                while Library.Toggles.W2_LoopRace.Value do
                    local burst = Library.Options.W2_RaceBurst.Value
                    for i = 1, burst do task.spawn(runW2Race) end
                    task.wait()
                end
            end)
            Library:Notify({ Title = "Race Loop", Description = "Started BURST farming: " .. Library.Options.W2_RaceTypeSelect.Value, Time = 2 })
        else
            if w2_raceThread then task.cancel(w2_raceThread) w2_raceThread = nil end
            Library:Notify({ Title = "Race Loop", Description = "Stopped.", Time = 2 })
        end
    end,
})

-- WORLD 2 HATCHERY CONTROLS
local W2_HatchGroup = TabWorld2:AddGroupbox({ Side = "Right", Name = "Hatchery Controls" })
W2_HatchGroup:AddLabel("🥚 Common Egg")
W2_HatchGroup:AddLabel("🥚 Uncommon Egg")
W2_HatchGroup:AddLabel("🥚 Rare Egg")
W2_HatchGroup:AddLabel("🥚 Epic Egg")
W2_HatchGroup:AddLabel("🥚 Legendary Egg")
W2_HatchGroup:AddLabel("🥚 Mythic Egg")
W2_HatchGroup:AddDivider()

W2_HatchGroup:AddDropdown("W2_EggSelect", { 
    Values = W2_SORTED_EGGS, Default = "Common Egg", Multi = false, 
    Text = "Select Egg to Hatch", Searchable = false 
})
W2_HatchGroup:AddDivider()

W2_HatchGroup:AddButton({ Text = "🥚 Hatch Once", Func = function()
    if not W2_EggHatchRemote then Library:Notify({ Title = "Error", Description = "W2 EggHatch remote not found!", Time = 4 }); return end
    local args = W2_EGG_REMOTE_ARGS[Library.Options.W2_EggSelect.Value]
    pcall(function() W2_EggHatchRemote:InvokeServer(table.unpack(args)) end)
    Library:Notify({ Title = "Hatched", Description = "Opened: " .. Library.Options.W2_EggSelect.Value, Time = 2 })
end })
W2_HatchGroup:AddDivider()

local w2_hatchThread = nil
W2_HatchGroup:AddToggle("W2_LoopHatch", {
    Text = "Auto Hatch Loop", Default = false, Risky = true,
    Callback = function(Value)
        if not W2_EggHatchRemote then Library:Notify({ Title = "Error", Description = "W2 EggHatch remote not found!", Time = 4 }); Library.Toggles.W2_LoopHatch:SetValue(false); return end
        if Value then
            w2_hatchThread = task.spawn(function()
                while Library.Toggles.W2_LoopHatch.Value do
                    local args = W2_EGG_REMOTE_ARGS[Library.Options.W2_EggSelect.Value]
                    pcall(function() W2_EggHatchRemote:InvokeServer(table.unpack(args)) end)
                    task.wait(0.1)
                end
            end)
            Library:Notify({ Title = "Hatch Loop Started", Description = "Spamming: " .. Library.Options.W2_EggSelect.Value, Time = 2 })
        else
            if w2_hatchThread then task.cancel(w2_hatchThread) w2_hatchThread = nil end
            Library:Notify({ Title = "Hatch Loop Stopped", Description = "Stopped hatching.", Time = 2 })
        end
    end,
})

-- // Initial Notification
Library:Notify({ Title = "Loaded", Description = "World 1 & World 2 (Treadmill, Race, Hatchery) fully ready!", Time = 4 })
