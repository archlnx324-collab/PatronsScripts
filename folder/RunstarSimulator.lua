-- // Multi-World Auto Farm — Matte Dark Two-Column Pro UI (Rounded Edition)
-- // FIXED: All treadmill loops now use dedicated boolean flags for 100% stability

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- // Cleanup previous UI on re-execute
local GUI_NAME = "MultiWorldFarm_MatteProUI"
local function getGuiParent()
	if type(gethui) == "function" then
		local ok, res = pcall(gethui)
		if ok and res then return res end
	end
	local ok, cg = pcall(function() return CoreGui end)
	if ok and cg then return cg end
	return player:WaitForChild("PlayerGui")
end

local guiParent = getGuiParent()
local oldGui = guiParent:FindFirstChild(GUI_NAME)
if oldGui then oldGui:Destroy() end

-- // Helpers
local connections = {}
local function trackConn(conn)
	table.insert(connections, conn)
	return conn
end

local function tween(obj, dur, props, style, dir)
	local t = TweenService:Create(
		obj,
		TweenInfo.new(dur or 0.2, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out),
		props
	)
	t:Play()
	return t
end

local function roundify(obj, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or UDim.new(1, 0)
	c.Parent = obj
	return c
end

-- // Theme Palette
local Themes = {
	["Monochrome"] = Color3.fromRGB(255, 255, 255),
	["Cyan"]       = Color3.fromRGB(56, 189, 248),
	["Violet"]     = Color3.fromRGB(167, 139, 250),
	["Emerald"]    = Color3.fromRGB(52, 211, 153),
	["Crimson"]    = Color3.fromRGB(248, 113, 113),
	["Amber"]      = Color3.fromRGB(251, 191, 36),
}

local Palette = {
	WindowBg   = Color3.fromRGB(15, 15, 17),
	CardBg     = Color3.fromRGB(19, 19, 22),
	RowBg      = Color3.fromRGB(24, 24, 28),
	RowHover   = Color3.fromRGB(32, 32, 38),
	InputBg    = Color3.fromRGB(16, 16, 19),
	Border     = Color3.fromRGB(40, 40, 46),
	BorderSoft = Color3.fromRGB(58, 58, 66),
	Text       = Color3.fromRGB(244, 244, 246),
	SubText    = Color3.fromRGB(161, 161, 170),
	MutedText  = Color3.fromRGB(110, 110, 120),
	Accent     = Themes["Monochrome"],
}

local accentListeners = {}
local function onAccent(fn)
	table.insert(accentListeners, fn)
	fn(Palette.Accent)
end

local function setTheme(name)
	local c = Themes[name]
	if not c then return end
	Palette.Accent = c
	for _, fn in ipairs(accentListeners) do
		pcall(fn, c)
	end
end

-- // Icons
local function buildIcon(parent, kind, color)
	local holder = Instance.new("Frame")
	holder.Size = UDim2.new(0, 16, 0, 16)
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.new(0.5, 0, 0.5, 0)
	holder.BackgroundTransparency = 1
	holder.Parent = parent

	local parts = {}
	local function addPart(props)
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = color
		for k, v in pairs(props) do
			if k ~= "Corner" and k ~= "Stroke" then f[k] = v end
		end
		if props.Corner then roundify(f, UDim.new(1, 0)) end
		if props.Stroke then
			local s = Instance.new("UIStroke")
			s.Color = color
			s.Thickness = props.Stroke
			s.Parent = f
		end
		f.Parent = holder
		table.insert(parts, f)
		return f
	end

	if kind == "search" then
		addPart({ Size = UDim2.new(0, 9, 0, 9), Position = UDim2.new(0, 2, 0, 2), BackgroundTransparency = 1, Corner = true, Stroke = 1.6 })
		addPart({ Size = UDim2.new(0, 6, 0, 2), Position = UDim2.new(0, 9, 0, 11), Rotation = 45, Corner = true })
	elseif kind == "collapse" then
		addPart({ Size = UDim2.new(0, 10, 0, 2), Position = UDim2.new(0, 3, 0, 7), Corner = true })
	elseif kind == "close" then
		addPart({ Size = UDim2.new(0, 12, 0, 1.8), Position = UDim2.new(0, 2, 0, 7), Rotation = 45, Corner = true })
		addPart({ Size = UDim2.new(0, 12, 0, 1.8), Position = UDim2.new(0, 2, 0, 7), Rotation = -45, Corner = true })
	elseif kind == "farm" then
		addPart({ Size = UDim2.new(0, 11, 0, 2), Position = UDim2.new(0, 2, 0, 3), Corner = true })
		addPart({ Size = UDim2.new(0, 7, 0, 2), Position = UDim2.new(0, 2, 0, 7), Corner = true })
		addPart({ Size = UDim2.new(0, 11, 0, 2), Position = UDim2.new(0, 2, 0, 11), Corner = true })
	elseif kind == "configs" then
		addPart({ Size = UDim2.new(0, 11, 0, 11), Position = UDim2.new(0, 2, 0, 2), BackgroundTransparency = 1, Corner = true, Stroke = 1.6 })
		addPart({ Size = UDim2.new(0, 3, 0, 3), Position = UDim2.new(0, 6, 0, 6), Corner = true })
	end

	return {
		SetColor = function(_, newCol)
			for _, p in ipairs(parts) do
				if p.BackgroundTransparency < 1 then tween(p, 0.15, { BackgroundColor3 = newCol }) end
				local s = p:FindFirstChildOfClass("UIStroke")
				if s then tween(s, 0.15, { Color = newCol }) end
			end
		end,
	}
end

-- // Root ScreenGui
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = GUI_NAME
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = guiParent

-- // Toast Notifications
local ToastHolder = Instance.new("Frame")
ToastHolder.AnchorPoint = Vector2.new(1, 1)
ToastHolder.Position = UDim2.new(1, -20, 1, -20)
ToastHolder.Size = UDim2.new(0, 300, 1, -40)
ToastHolder.BackgroundTransparency = 1
ToastHolder.Parent = ScreenGui

local ToastLayout = Instance.new("UIListLayout")
ToastLayout.SortOrder = Enum.SortOrder.LayoutOrder
ToastLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
ToastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
ToastLayout.Padding = UDim.new(0, 8)
ToastLayout.Parent = ToastHolder

local function notify(title, desc, duration)
	duration = duration or 2.8
	local wrap = Instance.new("Frame")
	wrap.Size = UDim2.new(1, 0, 0, 64)
	wrap.BackgroundTransparency = 1
	wrap.Parent = ToastHolder

	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 1, 0)
	card.Position = UDim2.new(1, 340, 0, 0)
	card.BackgroundColor3 = Palette.WindowBg
	card.ClipsDescendants = true
	card.Parent = wrap
	roundify(card, UDim.new(0, 16))

	local stroke = Instance.new("UIStroke")
	stroke.Color = Palette.Border
	stroke.Thickness = 1
	stroke.Parent = card

	local orb = Instance.new("Frame")
	orb.Size = UDim2.new(0, 22, 0, 22)
	orb.Position = UDim2.new(0, 12, 0.5, -12)
	orb.BackgroundColor3 = Palette.Accent
	orb.BackgroundTransparency = 0.86
	orb.BorderSizePixel = 0
	orb.Parent = card
	roundify(orb, UDim.new(1, 0))

	local orbCore = Instance.new("Frame")
	orbCore.AnchorPoint = Vector2.new(0.5, 0.5)
	orbCore.Position = UDim2.new(0.5, 0, 0.5, 0)
	orbCore.Size = UDim2.new(0, 8, 0, 8)
	orbCore.BackgroundColor3 = Palette.Accent
	orbCore.BorderSizePixel = 0
	orbCore.Parent = orb
	roundify(orbCore, UDim.new(1, 0))

	local tLbl = Instance.new("TextLabel")
	tLbl.BackgroundTransparency = 1
	tLbl.Position = UDim2.new(0, 44, 0, 10)
	tLbl.Size = UDim2.new(1, -56, 0, 16)
	tLbl.Font = Enum.Font.GothamBold
	tLbl.Text = title
	tLbl.TextColor3 = Palette.Text
	tLbl.TextSize = 12.5
	tLbl.TextXAlignment = Enum.TextXAlignment.Left
	tLbl.TextTruncate = Enum.TextTruncate.AtEnd
	tLbl.Parent = card

	local dLbl = Instance.new("TextLabel")
	dLbl.BackgroundTransparency = 1
	dLbl.Position = UDim2.new(0, 44, 0, 28)
	dLbl.Size = UDim2.new(1, -56, 0, 18)
	dLbl.Font = Enum.Font.Gotham
	dLbl.Text = desc
	dLbl.TextColor3 = Palette.SubText
	dLbl.TextSize = 11
	dLbl.TextXAlignment = Enum.TextXAlignment.Left
	dLbl.TextTruncate = Enum.TextTruncate.AtEnd
	dLbl.Parent = card

	local progTrack = Instance.new("Frame")
	progTrack.Size = UDim2.new(1, -28, 0, 3)
	progTrack.Position = UDim2.new(0, 14, 1, -7)
	progTrack.BackgroundColor3 = Palette.RowBg
	progTrack.BorderSizePixel = 0
	progTrack.Parent = card
	roundify(progTrack, UDim.new(1, 0))

	local prog = Instance.new("Frame")
	prog.Size = UDim2.new(1, 0, 1, 0)
	prog.BackgroundColor3 = Palette.Accent
	prog.BorderSizePixel = 0
	prog.Parent = progTrack
	roundify(prog, UDim.new(1, 0))

	tween(card, 0.34, { Position = UDim2.new(0, 0, 0, 0) }, Enum.EasingStyle.Back)
	tween(prog, duration, { Size = UDim2.new(0, 0, 1, 0) }, Enum.EasingStyle.Linear)

	task.delay(duration, function()
		if not wrap.Parent then return end
		local t = tween(card, 0.22, { Position = UDim2.new(1, 340, 0, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		t.Completed:Wait()
		if wrap.Parent then wrap:Destroy() end
	end)
end

-- // Main Window Frame
local WIN_W, WIN_H = 710, 470
local HEADER_H = 48
local SIDEBAR_W = 176

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainWindow"
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
MainFrame.Size = UDim2.new(0, WIN_W, 0, WIN_H)
MainFrame.BackgroundColor3 = Palette.WindowBg
MainFrame.Active = true
MainFrame.Parent = ScreenGui
roundify(MainFrame, UDim.new(0, 20))

local MainScale = Instance.new("UIScale")
MainScale.Scale = 0.92
MainScale.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Palette.Border
MainStroke.Thickness = 1.1
MainStroke.Parent = MainFrame

local Shadow = Instance.new("ImageLabel")
Shadow.AnchorPoint = Vector2.new(0.5, 0.5)
Shadow.Position = UDim2.new(0.5, 0, 0.5, 6)
Shadow.Size = UDim2.new(1, 52, 1, 52)
Shadow.BackgroundTransparency = 1
Shadow.Image = "rbxassetid://6014261993"
Shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
Shadow.ImageTransparency = 0.35
Shadow.ScaleType = Enum.ScaleType.Slice
Shadow.SliceCenter = Rect.new(49, 49, 450, 450)
Shadow.ZIndex = 0
Shadow.Parent = MainFrame

local Inner = Instance.new("Frame")
Inner.Size = UDim2.new(1, 0, 1, 0)
Inner.BackgroundTransparency = 1
Inner.ClipsDescendants = true
Inner.ZIndex = 2
Inner.Parent = MainFrame
roundify(Inner, UDim.new(0, 20))

-- // Header Bar
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, HEADER_H)
Header.BackgroundColor3 = Palette.WindowBg
Header.BackgroundTransparency = 0.12
Header.BorderSizePixel = 0
Header.ZIndex = 4
Header.Parent = Inner

local HeaderLine = Instance.new("Frame")
HeaderLine.Size = UDim2.new(1, -28, 0, 1)
HeaderLine.Position = UDim2.new(0, 14, 1, -1)
HeaderLine.BackgroundColor3 = Palette.Border
HeaderLine.BorderSizePixel = 0
HeaderLine.Parent = Header
roundify(HeaderLine, UDim.new(1, 0))

local LogoHalo = Instance.new("Frame")
LogoHalo.Size = UDim2.new(0, 26, 0, 26)
LogoHalo.Position = UDim2.new(0, 14, 0.5, -13)
LogoHalo.BackgroundColor3 = Palette.RowBg
LogoHalo.BorderSizePixel = 0
LogoHalo.Parent = Header
roundify(LogoHalo, UDim.new(1, 0))

local LogoHaloStroke = Instance.new("UIStroke")
LogoHaloStroke.Color = Palette.Border
LogoHaloStroke.Thickness = 1
LogoHaloStroke.Parent = LogoHalo

local LogoCircle = Instance.new("Frame")
LogoCircle.Size = UDim2.new(0, 16, 0, 16)
LogoCircle.AnchorPoint = Vector2.new(0.5, 0.5)
LogoCircle.Position = UDim2.new(0.5, 0, 0.5, 0)
LogoCircle.BackgroundColor3 = Palette.Accent
LogoCircle.BorderSizePixel = 0
LogoCircle.Parent = LogoHalo
roundify(LogoCircle, UDim.new(1, 0))

local LogoCut = Instance.new("Frame")
LogoCut.Size = UDim2.new(0, 11, 0, 11)
LogoCut.Position = UDim2.new(0, 5, 0, 1)
LogoCut.BackgroundColor3 = Palette.RowBg
LogoCut.BorderSizePixel = 0
LogoCut.Parent = LogoCircle
roundify(LogoCut, UDim.new(1, 0))

onAccent(function(c) tween(LogoCircle, 0.25, { BackgroundColor3 = c }) end)

local HeaderMeta = Instance.new("TextLabel")
HeaderMeta.Position = UDim2.new(0, 48, 0, 0)
HeaderMeta.Size = UDim2.new(1, -214, 1, 0)
HeaderMeta.BackgroundTransparency = 1
HeaderMeta.Font = Enum.Font.GothamMedium
HeaderMeta.RichText = true
HeaderMeta.Text = "<b>Multi-World Farm</b>   <font color='#3F3F46'>|</font>   <font color='#A1A1AA'>Treadmill, Race, Hatchery</font>"
HeaderMeta.TextColor3 = Palette.Text
HeaderMeta.TextSize = 12.5
HeaderMeta.TextXAlignment = Enum.TextXAlignment.Left
HeaderMeta.TextTruncate = Enum.TextTruncate.AtEnd
HeaderMeta.Parent = Header

local function makeHeaderAction(iconKind, xOffset)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, 28, 0, 28)
	b.Position = UDim2.new(1, xOffset, 0.5, -14)
	b.BackgroundColor3 = Palette.RowBg
	b.BackgroundTransparency = 0.45
	b.Text = ""
	b.AutoButtonColor = false
	b.Parent = Header
	roundify(b, UDim.new(1, 0))

	local bStroke = Instance.new("UIStroke")
	bStroke.Color = Palette.Border
	bStroke.Thickness = 1
	bStroke.Transparency = 0.5
	bStroke.Parent = b

	local ico = buildIcon(b, iconKind, Palette.SubText)
	b.MouseEnter:Connect(function()
		tween(b, 0.14, { BackgroundTransparency = 0, BackgroundColor3 = Palette.RowHover })
		tween(bStroke, 0.14, { Transparency = 0 })
		ico:SetColor(Palette.Text)
	end)
	b.MouseLeave:Connect(function()
		tween(b, 0.14, { BackgroundTransparency = 0.45, BackgroundColor3 = Palette.RowBg })
		tween(bStroke, 0.14, { Transparency = 0.5 })
		ico:SetColor(Palette.SubText)
	end)
	return b
end

local SearchHeaderBtn   = makeHeaderAction("search", -102)
local CollapseHeaderBtn = makeHeaderAction("collapse", -69)
local CloseHeaderBtn    = makeHeaderAction("close", -36)

-- // Body Container
local Body = Instance.new("Frame")
Body.Position = UDim2.new(0, 0, 0, HEADER_H)
Body.Size = UDim2.new(1, 0, 1, -HEADER_H)
Body.BackgroundTransparency = 1
Body.ZIndex = 2
Body.Parent = Inner

-- // Left Sidebar
local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, SIDEBAR_W, 1, 0)
Sidebar.BackgroundTransparency = 1
Sidebar.BorderSizePixel = 0
Sidebar.Parent = Body

local SidebarLine = Instance.new("Frame")
SidebarLine.Size = UDim2.new(0, 1, 1, -24)
SidebarLine.Position = UDim2.new(1, -1, 0, 12)
SidebarLine.BackgroundColor3 = Palette.Border
SidebarLine.BorderSizePixel = 0
SidebarLine.Parent = Sidebar
roundify(SidebarLine, UDim.new(1, 0))

local ProfileBlock = Instance.new("Frame")
ProfileBlock.Size = UDim2.new(1, -20, 0, 52)
ProfileBlock.Position = UDim2.new(0, 10, 0, 10)
ProfileBlock.BackgroundColor3 = Palette.CardBg
ProfileBlock.BackgroundTransparency = 0.25
ProfileBlock.Parent = Sidebar
roundify(ProfileBlock, UDim.new(0, 16))

local ProfStroke = Instance.new("UIStroke")
ProfStroke.Color = Palette.Border
ProfStroke.Thickness = 1
ProfStroke.Parent = ProfileBlock

local AvatarCircle = Instance.new("Frame")
AvatarCircle.Size = UDim2.new(0, 32, 0, 32)
AvatarCircle.Position = UDim2.new(0, 10, 0.5, -16)
AvatarCircle.BackgroundColor3 = Palette.RowBg
AvatarCircle.BorderSizePixel = 0
AvatarCircle.Parent = ProfileBlock
roundify(AvatarCircle, UDim.new(1, 0))

local AvatarInitial = Instance.new("TextLabel")
AvatarInitial.Size = UDim2.new(1, 0, 1, 0)
AvatarInitial.BackgroundTransparency = 1
AvatarInitial.Font = Enum.Font.GothamBold
AvatarInitial.Text = string.upper(string.sub(player.DisplayName, 1, 1))
AvatarInitial.TextColor3 = Palette.Text
AvatarInitial.TextSize = 13
AvatarInitial.Parent = AvatarCircle

local ProfTitle = Instance.new("TextLabel")
ProfTitle.Position = UDim2.new(0, 50, 0, 9)
ProfTitle.Size = UDim2.new(1, -58, 0, 17)
ProfTitle.BackgroundTransparency = 1
ProfTitle.Font = Enum.Font.GothamBold
ProfTitle.Text = "Auto Farm"
ProfTitle.TextColor3 = Palette.Text
ProfTitle.TextSize = 12.5
ProfTitle.TextXAlignment = Enum.TextXAlignment.Left
ProfTitle.Parent = ProfileBlock

local ProfSub = Instance.new("TextLabel")
ProfSub.Position = UDim2.new(0, 50, 0, 26)
ProfSub.Size = UDim2.new(1, -58, 0, 14)
ProfSub.BackgroundTransparency = 1
ProfSub.Font = Enum.Font.Gotham
ProfSub.Text = player.DisplayName
ProfSub.TextColor3 = Palette.MutedText
ProfSub.TextSize = 11
ProfSub.TextXAlignment = Enum.TextXAlignment.Left
ProfSub.TextTruncate = Enum.TextTruncate.AtEnd
ProfSub.Parent = ProfileBlock

local NavHolder = Instance.new("Frame")
NavHolder.Position = UDim2.new(0, 10, 0, 72)
NavHolder.Size = UDim2.new(1, -20, 1, -82)
NavHolder.BackgroundTransparency = 1
NavHolder.Parent = Sidebar

local ActivePill = Instance.new("Frame")
ActivePill.Size = UDim2.new(1, 0, 0, 36)
ActivePill.Position = UDim2.new(0, 0, 0, 0)
ActivePill.BackgroundColor3 = Palette.RowBg
ActivePill.ZIndex = 1
ActivePill.Parent = NavHolder
roundify(ActivePill, UDim.new(1, 0))

local ActivePillStroke = Instance.new("UIStroke")
ActivePillStroke.Color = Palette.BorderSoft
ActivePillStroke.Thickness = 1
ActivePillStroke.Parent = ActivePill

local ActiveBar = Instance.new("Frame")
ActiveBar.Size = UDim2.new(0, 4, 0, 14)
ActiveBar.Position = UDim2.new(0, 6, 0.5, -7)
ActiveBar.BackgroundColor3 = Palette.Accent
ActiveBar.BorderSizePixel = 0
ActiveBar.Parent = ActivePill
roundify(ActiveBar, UDim.new(1, 0))

onAccent(function(c) tween(ActiveBar, 0.25, { BackgroundColor3 = c }) end)

local NavList = Instance.new("Frame")
NavList.Size = UDim2.new(1, 0, 1, 0)
NavList.BackgroundTransparency = 1
NavList.ZIndex = 3
NavList.Parent = NavHolder

-- // Content Area
local ContentArea = Instance.new("Frame")
ContentArea.Position = UDim2.new(0, SIDEBAR_W, 0, 0)
ContentArea.Size = UDim2.new(1, -SIDEBAR_W, 1, 0)
ContentArea.BackgroundTransparency = 1
ContentArea.ClipsDescendants = true
ContentArea.Parent = Body

-- // Dragging, Collapse, Hide
do
	local dragging, dragStart, startPos = false, nil, nil
	Header.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = MainFrame.Position
		end
	end)
	trackConn(UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - dragStart
			MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end))
	trackConn(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end))
end

local isCollapsed = false
local isUiVisible = true
local toggleUiKey = Enum.KeyCode.RightShift

local function setUiVisible(state)
	isUiVisible = state
	if state then
		MainFrame.Visible = true
		MainScale.Scale = 0.92
		tween(MainScale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	else
		local t = tween(MainScale, 0.16, { Scale = 0.92 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		t.Completed:Connect(function()
			if not isUiVisible then MainFrame.Visible = false end
		end)
	end
end

CollapseHeaderBtn.MouseButton1Click:Connect(function()
	isCollapsed = not isCollapsed
	if isCollapsed then
		tween(MainFrame, 0.24, { Size = UDim2.new(0, WIN_W, 0, HEADER_H) })
	else
		tween(MainFrame, 0.25, { Size = UDim2.new(0, WIN_W, 0, WIN_H) })
	end
end)

CloseHeaderBtn.MouseButton1Click:Connect(function()
	setUiVisible(false)
	notify("UI Hidden", "Press " .. toggleUiKey.Name .. " to reopen.", 2.2)
end)

-- // Tab & Component Builder
local tabs = {}
local activeTab = nil

local function createTab(name, iconKind)
	local idx = #tabs
	local navBtn = Instance.new("TextButton")
	navBtn.Size = UDim2.new(1, 0, 0, 36)
	navBtn.Position = UDim2.new(0, 0, 0, idx * 42)
	navBtn.BackgroundTransparency = 1
	navBtn.Text = ""
	navBtn.AutoButtonColor = false
	navBtn.ZIndex = 4
	navBtn.Parent = NavList

	local iconSlot = Instance.new("Frame")
	iconSlot.Size = UDim2.new(0, 20, 0, 20)
	iconSlot.Position = UDim2.new(0, 16, 0.5, -10)
	iconSlot.BackgroundTransparency = 1
	iconSlot.Parent = navBtn

	local ico = buildIcon(iconSlot, iconKind, Palette.SubText)

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Position = UDim2.new(0, 44, 0, 0)
	nameLbl.Size = UDim2.new(1, -50, 1, 0)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Font = Enum.Font.GothamMedium
	nameLbl.Text = name
	nameLbl.TextColor3 = Palette.SubText
	nameLbl.TextSize = 12.5
	nameLbl.TextXAlignment = Enum.TextXAlignment.Left
	nameLbl.Parent = navBtn

	local page = Instance.new("ScrollingFrame")
	page.Name = name .. "_Page"
	page.Size = UDim2.new(1, 0, 1, 0)
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.ScrollBarThickness = 3
	page.ScrollBarImageColor3 = Palette.BorderSoft
	page.CanvasSize = UDim2.new(0, 0, 0, 0)
	page.Visible = false
	page.Parent = ContentArea

	local colsWrap = Instance.new("Frame")
	colsWrap.Position = UDim2.new(0, 12, 0, 12)
	colsWrap.Size = UDim2.new(1, -26, 0, 400)
	colsWrap.BackgroundTransparency = 1
	colsWrap.Parent = page

	local leftCol = Instance.new("Frame")
	leftCol.Position = UDim2.new(0, 0, 0, 0)
	leftCol.Size = UDim2.new(0.5, -6, 0, 0)
	leftCol.BackgroundTransparency = 1
	leftCol.Parent = colsWrap

	local leftLayout = Instance.new("UIListLayout")
	leftLayout.SortOrder = Enum.SortOrder.LayoutOrder
	leftLayout.Padding = UDim.new(0, 10)
	leftLayout.Parent = leftCol

	local rightCol = Instance.new("Frame")
	rightCol.Position = UDim2.new(0.5, 6, 0, 0)
	rightCol.Size = UDim2.new(0.5, -6, 0, 0)
	rightCol.BackgroundTransparency = 1
	rightCol.Parent = colsWrap

	local rightLayout = Instance.new("UIListLayout")
	rightLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rightLayout.Padding = UDim.new(0, 10)
	rightLayout.Parent = rightCol

	local cardRefreshes = {}
	local function refreshPageLayout()
		for _, fn in ipairs(cardRefreshes) do fn() end
		local lh = leftLayout.AbsoluteContentSize.Y
		local rh = rightLayout.AbsoluteContentSize.Y
		leftCol.Size = UDim2.new(0.5, -6, 0, lh)
		rightCol.Size = UDim2.new(0.5, -6, 0, rh)
		local maxH = math.max(lh, rh)
		colsWrap.Size = UDim2.new(1, -26, 0, maxH)
		page.CanvasSize = UDim2.new(0, 0, 0, maxH + 28)
	end

	leftLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(refreshPageLayout)
	rightLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(refreshPageLayout)

	local tabObj = {
		Index = idx, Name = name, Icon = ico, NameLbl = nameLbl, Page = page, RefreshLayout = refreshPageLayout,
	}
	table.insert(tabs, tabObj)

	local function activate()
		if activeTab == tabObj then return end
		if activeTab then
			activeTab.Page.Visible = false
			activeTab.Icon:SetColor(Palette.SubText)
			tween(activeTab.NameLbl, 0.16, { TextColor3 = Palette.SubText })
			activeTab.NameLbl.Font = Enum.Font.GothamMedium
		end
		activeTab = tabObj
		tween(ActivePill, 0.24, { Position = UDim2.new(0, 0, 0, tabObj.Index * 42) })
		ico:SetColor(Palette.Text)
		tween(nameLbl, 0.16, { TextColor3 = Palette.Text })
		nameLbl.Font = Enum.Font.GothamBold

		page.Visible = true
		refreshPageLayout()
		colsWrap.Position = UDim2.new(0, 22, 0, 12)
		tween(colsWrap, 0.22, { Position = UDim2.new(0, 12, 0, 12) })
	end

	tabObj.Activate = activate

	navBtn.MouseEnter:Connect(function()
		if activeTab ~= tabObj then
			ico:SetColor(Palette.Text)
			tween(nameLbl, 0.14, { TextColor3 = Palette.Text })
		end
	end)
	navBtn.MouseLeave:Connect(function()
		if activeTab ~= tabObj then
			ico:SetColor(Palette.SubText)
			tween(nameLbl, 0.14, { TextColor3 = Palette.SubText })
		end
	end)
	navBtn.MouseButton1Click:Connect(activate)

	function tabObj:AddGroup(side, groupTitle)
		local parentCol = (side == "Right") and rightCol or leftCol

		local card = Instance.new("Frame")
		card.Size = UDim2.new(1, 0, 0, 40)
		card.BackgroundColor3 = Palette.CardBg
		card.BackgroundTransparency = 0.08
		card.Parent = parentCol
		roundify(card, UDim.new(0, 16))

		local cardStroke = Instance.new("UIStroke")
		cardStroke.Color = Palette.Border
		cardStroke.Thickness = 1
		cardStroke.Parent = card

		local pad = Instance.new("UIPadding")
		pad.PaddingTop, pad.PaddingBottom, pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 11), UDim.new(0, 11), UDim.new(0, 11), UDim.new(0, 11)
		pad.Parent = card

		local list = Instance.new("UIListLayout")
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Padding = UDim.new(0, 8)
		list.Parent = card

		local function syncCardHeight()
			card.Size = UDim2.new(1, 0, 0, list.AbsoluteContentSize.Y + 22)
		end
		list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(syncCardHeight)
		table.insert(cardRefreshes, syncCardHeight)

		if groupTitle and groupTitle ~= "" then
			local hdrWrap = Instance.new("Frame")
			hdrWrap.Size = UDim2.new(1, 0, 0, 16)
			hdrWrap.BackgroundTransparency = 1
			hdrWrap.Parent = card

			local dot = Instance.new("Frame")
			dot.Size = UDim2.new(0, 6, 0, 6)
			dot.Position = UDim2.new(0, 2, 0.5, -3)
			dot.BackgroundColor3 = Palette.Accent
			dot.BorderSizePixel = 0
			dot.Parent = hdrWrap
			roundify(dot, UDim.new(1, 0))

			onAccent(function(c) tween(dot, 0.25, { BackgroundColor3 = c }) end)

			local hdr = Instance.new("TextLabel")
			hdr.Position = UDim2.new(0, 13, 0, 0)
			hdr.Size = UDim2.new(1, -13, 1, 0)
			hdr.BackgroundTransparency = 1
			hdr.Font = Enum.Font.GothamBold
			hdr.Text = groupTitle
			hdr.TextColor3 = Palette.MutedText
			hdr.TextSize = 10.5
			hdr.TextXAlignment = Enum.TextXAlignment.Left
			hdr.Parent = hdrWrap
		end

		local groupObj = {}

		function groupObj:AddNote(text)
			local wrap = Instance.new("Frame")
			wrap.Size = UDim2.new(1, 0, 0, 36)
			wrap.AutomaticSize = Enum.AutomaticSize.Y
			wrap.BackgroundColor3 = Palette.RowBg
			wrap.BackgroundTransparency = 0.45
			wrap.Parent = card
			roundify(wrap, UDim.new(0, 12))

			local wPad = Instance.new("UIPadding")
			wPad.PaddingTop, wPad.PaddingBottom, wPad.PaddingLeft, wPad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8), UDim.new(0, 22), UDim.new(0, 10)
			wPad.Parent = wrap

			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.new(1, 0, 0, 0)
			lbl.AutomaticSize = Enum.AutomaticSize.Y
			lbl.BackgroundTransparency = 1
			lbl.Font = Enum.Font.Gotham
			lbl.Text = text
			lbl.TextColor3 = Palette.MutedText
			lbl.TextSize = 11
			lbl.TextWrapped = true
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.Parent = wrap

			syncCardHeight()
			return { Set = function(_, txt) lbl.Text = txt; syncCardHeight() end }
		end

		function groupObj:AddToggle(opts)
			local value = opts.Default or false
			local hasDesc = opts.Desc ~= nil and opts.Desc ~= ""

			local row = Instance.new("TextButton")
			row.Size = UDim2.new(1, 0, 0, hasDesc and 56 or 42)
			row.BackgroundColor3 = Palette.RowBg
			row.Text = ""
			row.AutoButtonColor = false
			row.Parent = card
			roundify(row, UDim.new(0, 14))

			local rStroke = Instance.new("UIStroke")
			rStroke.Color = Palette.Border
			rStroke.Thickness = 1
			rStroke.Parent = row

			local tLbl = Instance.new("TextLabel")
			tLbl.BackgroundTransparency = 1
			tLbl.Position = UDim2.new(0, 14, 0, hasDesc and 8 or 0)
			tLbl.Size = UDim2.new(1, -68, 0, hasDesc and 17 or 42)
			tLbl.Font = Enum.Font.GothamMedium
			tLbl.Text = opts.Text
			tLbl.TextColor3 = Palette.Text
			tLbl.TextSize = 12.5
			tLbl.TextXAlignment = Enum.TextXAlignment.Left
			tLbl.TextTruncate = Enum.TextTruncate.AtEnd
			tLbl.Parent = row

			if hasDesc then
				local dLbl = Instance.new("TextLabel")
				dLbl.BackgroundTransparency = 1
				dLbl.Position = UDim2.new(0, 14, 0, 27)
				dLbl.Size = UDim2.new(1, -68, 0, 22)
				dLbl.Font = Enum.Font.Gotham
				dLbl.Text = opts.Desc
				dLbl.TextColor3 = Palette.MutedText
				dLbl.TextSize = 10.5
				dLbl.TextWrapped = true
				dLbl.TextXAlignment = Enum.TextXAlignment.Left
				dLbl.Parent = row
			end

			local track = Instance.new("Frame")
			track.Size = UDim2.new(0, 38, 0, 20)
			track.Position = UDim2.new(1, -48, 0.5, -10)
			track.BackgroundColor3 = value and Palette.Accent or Palette.InputBg
			track.Parent = row
			roundify(track, UDim.new(1, 0))

			local trackStroke = Instance.new("UIStroke")
			trackStroke.Color = value and Palette.Accent or Color3.fromRGB(115, 115, 125)
			trackStroke.Thickness = 1.2
			trackStroke.Parent = track

			local knob = Instance.new("Frame")
			knob.Size = UDim2.new(0, 14, 0, 14)
			knob.Position = value and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
			knob.BackgroundColor3 = value and Color3.fromRGB(18, 18, 22) or Color3.fromRGB(238, 238, 242)
			knob.BorderSizePixel = 0
			knob.Parent = track
			roundify(knob, UDim.new(1, 0))

			local function syncVisual()
				tween(track, 0.18, { BackgroundColor3 = value and Palette.Accent or Palette.InputBg })
				tween(trackStroke, 0.18, { Color = value and Palette.Accent or Color3.fromRGB(115, 115, 125) })
				tween(knob, 0.2, {
					Position = value and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7),
					BackgroundColor3 = value and Color3.fromRGB(18, 18, 22) or Color3.fromRGB(238, 238, 242)
				}, Enum.EasingStyle.Back)
			end

			onAccent(function()
				if value then
					tween(track, 0.25, { BackgroundColor3 = Palette.Accent })
					tween(trackStroke, 0.25, { Color = Palette.Accent })
				end
			end)

			local api = {}
			function api:Set(newVal, silent)
				if value == newVal then return end
				value = newVal
				syncVisual()
				if not silent and opts.Callback then opts.Callback(value) end
			end
			function api:Get() return value end

			row.MouseEnter:Connect(function() tween(row, 0.12, { BackgroundColor3 = Palette.RowHover }) end)
			row.MouseLeave:Connect(function() tween(row, 0.12, { BackgroundColor3 = Palette.RowBg }) end)
			row.MouseButton1Click:Connect(function() api:Set(not value) end)

			syncCardHeight()
			return api
		end

		function groupObj:AddDropdown(opts)
			local options = opts.Options or {}
			local selected = opts.Default or options[1] or "None"
			local open = false

			local holder = Instance.new("Frame")
			holder.Size = UDim2.new(1, 0, 0, 56)
			holder.BackgroundTransparency = 1
			holder.ClipsDescendants = true
			holder.Parent = card

			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.new(1, 0, 0, 16)
			lbl.Position = UDim2.new(0, 2, 0, 0)
			lbl.BackgroundTransparency = 1
			lbl.Font = Enum.Font.GothamMedium
			lbl.Text = opts.Text
			lbl.TextColor3 = Palette.Text
			lbl.TextSize = 12
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.Parent = holder

			local box = Instance.new("Frame")
			box.Position = UDim2.new(0, 0, 0, 20)
			box.Size = UDim2.new(1, 0, 0, 34)
			box.BackgroundColor3 = Palette.InputBg
			box.ClipsDescendants = true
			box.Parent = holder
			roundify(box, UDim.new(0, 14))

			local bStroke = Instance.new("UIStroke")
			bStroke.Color = Palette.Border
			bStroke.Thickness = 1
			bStroke.Parent = box

			local topBtn = Instance.new("TextButton")
			topBtn.Size = UDim2.new(1, 0, 0, 34)
			topBtn.BackgroundTransparency = 1
			topBtn.Text = ""
			topBtn.AutoButtonColor = false
			topBtn.Parent = box

			local valLbl = Instance.new("TextLabel")
			valLbl.Position = UDim2.new(0, 14, 0, 0)
			valLbl.Size = UDim2.new(1, -44, 1, 0)
			valLbl.BackgroundTransparency = 1
			valLbl.Font = Enum.Font.Gotham
			valLbl.Text = tostring(selected)
			valLbl.TextColor3 = Palette.SubText
			valLbl.TextSize = 12
			valLbl.TextXAlignment = Enum.TextXAlignment.Left
			valLbl.TextTruncate = Enum.TextTruncate.AtEnd
			valLbl.Parent = topBtn

			local chevBadge = Instance.new("Frame")
			chevBadge.Size = UDim2.new(0, 20, 0, 20)
			chevBadge.Position = UDim2.new(1, -28, 0.5, -10)
			chevBadge.BackgroundColor3 = Palette.RowBg
			chevBadge.BorderSizePixel = 0
			chevBadge.Parent = topBtn
			roundify(chevBadge, UDim.new(1, 0))

			local chev = Instance.new("TextLabel")
			chev.Size = UDim2.new(1, 0, 1, 0)
			chev.BackgroundTransparency = 1
			chev.Font = Enum.Font.GothamBold
			chev.Text = "v"
			chev.TextColor3 = Palette.MutedText
			chev.TextSize = 10
			chev.Parent = chevBadge

			local scroll = Instance.new("ScrollingFrame")
			scroll.Position = UDim2.new(0, 5, 0, 36)
			scroll.Size = UDim2.new(1, -10, 0, 0)
			scroll.BackgroundTransparency = 1
			scroll.BorderSizePixel = 0
			scroll.ScrollBarThickness = 3
			scroll.ScrollBarImageColor3 = Palette.BorderSoft
			scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
			scroll.Parent = box

			local sLayout = Instance.new("UIListLayout")
			sLayout.SortOrder = Enum.SortOrder.LayoutOrder
			sLayout.Padding = UDim.new(0, 3)
			sLayout.Parent = scroll

			local function listHeight()
				local n = math.max(#options, 1)
				return math.min(n * 28 + (n - 1) * 3, 130)
			end

			local function setOpenState(state)
				open = state
				if open then
					local h = listHeight()
					scroll.Size = UDim2.new(1, -10, 0, h)
					tween(chev, 0.18, { Rotation = 180 })
					box.Size = UDim2.new(1, 0, 0, 40 + h)
					holder.Size = UDim2.new(1, 0, 0, 62 + h)
					tween(bStroke, 0.18, { Color = Palette.BorderSoft })
				else
					tween(chev, 0.18, { Rotation = 0 })
					box.Size = UDim2.new(1, 0, 0, 34)
					holder.Size = UDim2.new(1, 0, 0, 56)
					tween(bStroke, 0.18, { Color = Palette.Border })
				end
				refreshPageLayout()
			end

			local function buildList()
				for _, ch in ipairs(scroll:GetChildren()) do
					if ch:IsA("TextButton") then ch:Destroy() end
				end
				for _, opt in ipairs(options) do
					local it = Instance.new("TextButton")
					it.Size = UDim2.new(1, -4, 0, 28)
					it.BackgroundColor3 = (opt == selected) and Palette.RowHover or Palette.RowBg
					it.BackgroundTransparency = (opt == selected) and 0 or 0.35
					it.Text = ""
					it.AutoButtonColor = false
					it.Parent = scroll
					roundify(it, UDim.new(0, 10))

					local iLbl = Instance.new("TextLabel")
					iLbl.Position = UDim2.new(0, 12, 0, 0)
					iLbl.Size = UDim2.new(1, -18, 1, 0)
					iLbl.BackgroundTransparency = 1
					iLbl.Font = (opt == selected) and Enum.Font.GothamBold or Enum.Font.Gotham
					iLbl.Text = tostring(opt)
					iLbl.TextColor3 = (opt == selected) and Palette.Text or Palette.SubText
					iLbl.TextSize = 11.5
					iLbl.TextXAlignment = Enum.TextXAlignment.Left
					iLbl.TextTruncate = Enum.TextTruncate.AtEnd
					iLbl.Parent = it

					it.MouseEnter:Connect(function()
						if opt ~= selected then
							tween(it, 0.1, { BackgroundColor3 = Palette.RowHover, BackgroundTransparency = 0 })
							tween(iLbl, 0.1, { TextColor3 = Palette.Text })
						end
					end)
					it.MouseLeave:Connect(function()
						if opt ~= selected then
							tween(it, 0.1, { BackgroundColor3 = Palette.RowBg, BackgroundTransparency = 0.35 })
							tween(iLbl, 0.1, { TextColor3 = Palette.SubText })
						end
					end)
					it.MouseButton1Click:Connect(function()
						selected = opt
						valLbl.Text = tostring(selected)
						setOpenState(false)
						buildList()
						if opts.Callback then opts.Callback(selected) end
					end)
				end
				scroll.CanvasSize = UDim2.new(0, 0, 0, sLayout.AbsoluteContentSize.Y + 4)
			end

			buildList()
			topBtn.MouseButton1Click:Connect(function() setOpenState(not open) end)
			syncCardHeight()
			return {
				Get = function() return selected end,
				SetOptions = function(_, newOpts, newSel)
					options = newOpts or {}
					selected = newSel or options[1] or "None"
					valLbl.Text = tostring(selected)
					buildList()
					if open then setOpenState(true) end
				end,
			}
		end

		function groupObj:AddButton(opts)
			local b = Instance.new("TextButton")
			b.Size = UDim2.new(1, 0, 0, 36)
			b.BackgroundColor3 = opts.Primary and Palette.Accent or Palette.RowBg
			b.BackgroundTransparency = opts.Primary and 0.9 or 0
			b.Text = ""
			b.AutoButtonColor = false
			b.Parent = card
			roundify(b, UDim.new(1, 0))

			local bStroke = Instance.new("UIStroke")
			bStroke.Color = opts.Danger and Color3.fromRGB(220, 75, 85) or (opts.Primary and Palette.Accent or Palette.Border)
			bStroke.Thickness = 1
			bStroke.Transparency = opts.Primary and 0.35 or 0
			bStroke.Parent = b

			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.new(1, -20, 1, 0)
			lbl.Position = UDim2.new(0, 10, 0, 0)
			lbl.BackgroundTransparency = 1
			lbl.Font = Enum.Font.GothamBold
			lbl.Text = opts.Text
			lbl.TextColor3 = opts.Danger and Color3.fromRGB(248, 113, 113) or (opts.Primary and Palette.Accent or Palette.Text)
			lbl.TextSize = 12
			lbl.Parent = b

			if opts.Primary then
				onAccent(function(c)
					tween(b, 0.25, { BackgroundColor3 = c })
					tween(bStroke, 0.25, { Color = c })
					tween(lbl, 0.25, { TextColor3 = c })
				end)
			end

			b.MouseEnter:Connect(function()
				if opts.Primary then tween(b, 0.14, { BackgroundTransparency = 0.8 })
				else tween(b, 0.14, { BackgroundColor3 = Palette.RowHover }) end
			end)
			b.MouseLeave:Connect(function()
				if opts.Primary then tween(b, 0.14, { BackgroundTransparency = 0.9 })
				else tween(b, 0.14, { BackgroundColor3 = Palette.RowBg }) end
			end)
			b.MouseButton1Click:Connect(function() if opts.Callback then opts.Callback() end end)

			syncCardHeight()
			return b
		end

		return groupObj
	end

	if #tabs == 1 then activate() end
	return tabObj
end

-- ============================================================
-- // GAME LOGIC & MAPPINGS
-- ============================================================
local W1_AddSpeedRemote, W1_RacePrepare, W1_RaceStart, W1_RaceEnd, W1_RaceReward, W1_EggHatchRemote = nil, nil, nil, nil, nil, nil
local W2_AddSpeedRemote, W2_RacePrepare, W2_RaceStart, W2_RaceEnd, W2_RaceReward, W2_EggHatchRemote = nil, nil, nil, nil, nil, nil
local W3_AddSpeedRemote, W3_RacePrepare, W3_RaceStart, W3_RaceEnd, W3_RaceReward = nil, nil, nil, nil, nil

pcall(function()
	local Remotes = ReplicatedStorage:WaitForChild("Remotes", 3)
	local TrainFolder = Remotes:WaitForChild("Train", 3)
	W1_AddSpeedRemote = TrainFolder:WaitForChild("AddSpeed", 3)
	W2_AddSpeedRemote = TrainFolder:WaitForChild("AddSpeed", 3)
	W3_AddSpeedRemote = TrainFolder:WaitForChild("AddSpeed", 3)
	
	local RaceFolder = Remotes:WaitForChild("Race", 3)
	W1_RacePrepare, W1_RaceStart, W1_RaceEnd, W1_RaceReward = RaceFolder:WaitForChild("RacePrepare", 3), RaceFolder:WaitForChild("RaceStart", 3), RaceFolder:WaitForChild("RaceEnd", 3), RaceFolder:WaitForChild("RaceReward", 3)
	W2_RacePrepare, W2_RaceStart, W2_RaceEnd, W2_RaceReward = RaceFolder:WaitForChild("RacePrepare", 3), RaceFolder:WaitForChild("RaceStart", 3), RaceFolder:WaitForChild("RaceEnd", 3), RaceFolder:WaitForChild("RaceReward", 3)
	W3_RacePrepare, W3_RaceStart, W3_RaceEnd, W3_RaceReward = RaceFolder:WaitForChild("RacePrepare", 3), RaceFolder:WaitForChild("RaceStart", 3), RaceFolder:WaitForChild("RaceEnd", 3), RaceFolder:WaitForChild("RaceReward", 3)
	
	local HatchFolder = Remotes:WaitForChild("Hatch", 3)
	W1_EggHatchRemote = HatchFolder:WaitForChild("EggHatch", 3)
	W2_EggHatchRemote = HatchFolder:WaitForChild("EggHatch", 3)
end)

local W1_LABEL_TO_ID = {["+1 Speed"]="1", ["+5 Speed"]="2", ["+10 Speed"]="3", ["+20 Speed"]="4", ["+25 Speed"]="5", ["+30 Speed"]="6"}
local W1_SORTED_LABELS = { "+1 Speed", "+5 Speed", "+10 Speed", "+20 Speed", "+25 Speed", "+30 Speed" }
local W1_RACE_TYPES = {["More Wins Race"] = {true, 1, 1}, ["Standard Race"] = {true, 1, 3}}
local W1_SORTED_RACE_TYPES = { "More Wins Race", "Standard Race" }
local W1_EGG_REMOTE_ARGS = {["Common Egg"] = {1, "Open1", {}}, ["Uncommon Egg"] = {1, "Open3", {}}, ["Rare Egg"] = {3, "Open1", {}}, ["Epic Egg"] = {4, "Open1", {}}}
local W1_SORTED_EGGS = { "Common Egg", "Uncommon Egg", "Rare Egg", "Epic Egg" }

local W2_LABEL_TO_ID = {["+40 Speed"] = "8", ["+60 Speed"] = "9", ["+80 Speed"] = "10", ["+100 Speed"] = "11", ["+150 Speed"] = "12", ["+200 Speed"] = "13"}
local W2_SORTED_LABELS = { "+40 Speed", "+60 Speed", "+80 Speed", "+100 Speed", "+150 Speed", "+200 Speed" }
local W2_RACE_TYPES = {["World 2 Race"] = {true, 2, 1}}
local W2_SORTED_RACE_TYPES = { "World 2 Race" }
local W2_EGG_REMOTE_ARGS = {["Common Egg"] = {5, "Open1", {}}, ["Uncommon Egg"] = {6, "Open1", {}}, ["Rare Egg"] = {7, "Open1", {}}, ["Epic Egg"] = {8, "Open1", {}}, ["Legendary Egg"] = {9, "Open1", {}}, ["Mythic Egg"] = {10, "Open1", {}}}
local W2_SORTED_EGGS = { "Common Egg", "Uncommon Egg", "Rare Egg", "Epic Egg", "Legendary Egg", "Mythic Egg" }

local W3_LABEL_TO_ID = {["+1000 Speed"] = "15", ["+1500 Speed"] = "16"}
local W3_SORTED_LABELS = { "+1000 Speed", "+1500 Speed" }
local W3_RACE_TYPES = {["World 3 Race"] = {true, 3, 1}}
local W3_SORTED_RACE_TYPES = { "World 3 Race" }

-- ============================================================
-- // CREATE TABS
-- ============================================================
local TabWorld1 = createTab("World 1", "farm")
local TabWorld2 = createTab("World 2", "farm")
local TabWorld3 = createTab("World 3", "farm")
local TabConfig = createTab("Configs", "configs")

-- ============================================================
-- // WORLD 1 UI
-- ============================================================
local W1_TreadmillGroup = TabWorld1:AddGroup("Left", "Treadmill Controls")
local W1_SpeedSelect = W1_TreadmillGroup:AddDropdown({ Text = "Select Speed Amount", Options = W1_SORTED_LABELS, Default = "+1 Speed" })

local w1_treadmillThread = nil
local isW1TreadmillLooping = false
local W1_LoopSpeed
W1_LoopSpeed = W1_TreadmillGroup:AddToggle({
	Text = "Loop Add Speed",
	Desc = "Continuously adds speed (0s cooldown)",
	Default = false,
	Callback = function(Value)
		if not W1_AddSpeedRemote then notify("Error", "W1 AddSpeed remote not found!", 3); W1_LoopSpeed:Set(false); return end
		isW1TreadmillLooping = Value
		if Value then
			w1_treadmillThread = task.spawn(function()
				while isW1TreadmillLooping do
					local targetID = W1_LABEL_TO_ID[W1_SpeedSelect:Get()]
					if targetID then pcall(function() W1_AddSpeedRemote:FireServer(targetID) end) end
					task.wait()
				end
			end)
			notify("Loop Started", "Farming " .. W1_SpeedSelect:Get(), 2)
		else
			if w1_treadmillThread then task.cancel(w1_treadmillThread) w1_treadmillThread = nil end
			notify("Loop Stopped", "Treadmill loop terminated.", 2)
		end
	end
})

local W1_RaceGroup = TabWorld1:AddGroup("Right", "Race Controls")
local W1_RaceTypeSelect = W1_RaceGroup:AddDropdown({ Text = "Select Race Type", Options = W1_SORTED_RACE_TYPES, Default = "More Wins Race" })

local function runW1Race()
	pcall(function() W1_RacePrepare:InvokeServer() end)
	pcall(function() W1_RaceStart:FireServer() end)
	pcall(function() W1_RaceEnd:InvokeServer(0) end)
	local raceArgs = W1_RACE_TYPES[W1_RaceTypeSelect:Get()]
	if raceArgs then pcall(function() W1_RaceReward:FireServer(table.unpack(raceArgs)) end) end
end

W1_RaceGroup:AddButton({ Text = "Run Race Once", Primary = true, Callback = function()
	if not (W1_RacePrepare and W1_RaceStart and W1_RaceEnd and W1_RaceReward) then notify("Error", "Race remotes not found!", 3); return end
	runW1Race(); notify("Race", W1_RaceTypeSelect:Get() .. " executed!", 2)
end })

local w1_raceThread = nil
local isW1RaceLooping = false
local W1_LoopRace
W1_LoopRace = W1_RaceGroup:AddToggle({
	Text = "Loop Race (Win Loop)",
	Desc = "0s cooldown win loop",
	Default = false,
	Callback = function(Value)
		if not (W1_RacePrepare and W1_RaceStart and W1_RaceEnd and W1_RaceReward) then notify("Error", "Race remotes not found!", 3); W1_LoopRace:Set(false); return end
		isW1RaceLooping = Value
		if Value then
			w1_raceThread = task.spawn(function()
				while isW1RaceLooping do runW1Race(); task.wait() end
			end)
			notify("Race Loop", "Started W1 Win Loop!", 2)
		else
			if w1_raceThread then task.cancel(w1_raceThread) w1_raceThread = nil end
			notify("Race Loop", "Stopped.", 2)
		end
	end
})

local W1_HatchGroup = TabWorld1:AddGroup("Left", "Hatchery Controls")
W1_HatchGroup:AddNote("🥚 Common = 5 | Uncommon = 50 | Rare = 250 | Epic = 3,000")
local W1_EggSelect = W1_HatchGroup:AddDropdown({ Text = "Select Egg to Hatch", Options = W1_SORTED_EGGS, Default = "Common Egg" })

W1_HatchGroup:AddButton({ Text = "🥚 Hatch Once", Callback = function()
	if not W1_EggHatchRemote then notify("Error", "EggHatch remote not found!", 3); return end
	local args = W1_EGG_REMOTE_ARGS[W1_EggSelect:Get()]
	if args then pcall(function() W1_EggHatchRemote:InvokeServer(table.unpack(args)) end) end
	notify("Hatched", "Opened: " .. W1_EggSelect:Get(), 2)
end })

local w1_hatchThread = nil
local isW1HatchLooping = false
local W1_LoopHatch
W1_LoopHatch = W1_HatchGroup:AddToggle({
	Text = "Auto Hatch Loop",
	Desc = "0s cooldown hatch spam",
	Default = false,
	Callback = function(Value)
		if not W1_EggHatchRemote then notify("Error", "EggHatch remote not found!", 3); W1_LoopHatch:Set(false); return end
		isW1HatchLooping = Value
		if Value then
			w1_hatchThread = task.spawn(function()
				while isW1HatchLooping do
					local args = W1_EGG_REMOTE_ARGS[W1_EggSelect:Get()]
					if args then pcall(function() W1_EggHatchRemote:InvokeServer(table.unpack(args)) end) end
					task.wait()
				end
			end)
			notify("Hatch Loop Started", "Spamming: " .. W1_EggSelect:Get(), 2)
		else
			if w1_hatchThread then task.cancel(w1_hatchThread) w1_hatchThread = nil end
			notify("Hatch Loop Stopped", "Stopped hatching.", 2)
		end
	end
})

-- ============================================================
-- // WORLD 2 UI
-- ============================================================
local W2_TreadmillGroup = TabWorld2:AddGroup("Left", "Treadmill Controls")
local W2_SpeedSelect = W2_TreadmillGroup:AddDropdown({ Text = "Select Speed Amount", Options = W2_SORTED_LABELS, Default = "+40 Speed" })

local w2_treadmillThread = nil
local isW2TreadmillLooping = false
local W2_LoopSpeed
W2_LoopSpeed = W2_TreadmillGroup:AddToggle({
	Text = "Loop Add Speed",
	Desc = "Continuously adds speed (0s cooldown)",
	Default = false,
	Callback = function(Value)
		if not W2_AddSpeedRemote then notify("Error", "W2 AddSpeed remote not found!", 3); W2_LoopSpeed:Set(false); return end
		isW2TreadmillLooping = Value
		if Value then
			w2_treadmillThread = task.spawn(function()
				while isW2TreadmillLooping do
					local targetID = W2_LABEL_TO_ID[W2_SpeedSelect:Get()]
					if targetID then pcall(function() W2_AddSpeedRemote:FireServer(targetID) end) end
					task.wait()
				end
			end)
			notify("Loop Started", "Farming " .. W2_SpeedSelect:Get(), 2)
		else
			if w2_treadmillThread then task.cancel(w2_treadmillThread) w2_treadmillThread = nil end
			notify("Loop Stopped", "Treadmill loop terminated.", 2)
		end
	end
})

local W2_RaceGroup = TabWorld2:AddGroup("Right", "Race Controls")
local W2_RaceTypeSelect = W2_RaceGroup:AddDropdown({ Text = "Select Race Type", Options = W2_SORTED_RACE_TYPES, Default = "World 2 Race" })

local function runW2Race()
	pcall(function() W2_RacePrepare:InvokeServer() end)
	pcall(function() W2_RaceStart:FireServer() end)
	pcall(function() W2_RaceEnd:InvokeServer(0) end)
	local raceArgs = W2_RACE_TYPES[W2_RaceTypeSelect:Get()]
	if raceArgs then pcall(function() W2_RaceReward:FireServer(table.unpack(raceArgs)) end) end
end

W2_RaceGroup:AddButton({ Text = "Run Race Once", Primary = true, Callback = function()
	if not (W2_RacePrepare and W2_RaceStart and W2_RaceEnd and W2_RaceReward) then notify("Error", "W2 Race remotes not found!", 3); return end
	runW2Race(); notify("Race", W2_RaceTypeSelect:Get() .. " executed!", 2)
end })

local w2_raceThread = nil
local isW2RaceLooping = false
local W2_LoopRace
W2_LoopRace = W2_RaceGroup:AddToggle({
	Text = "Loop Race (Win Loop)",
	Desc = "0s cooldown win loop",
	Default = false,
	Callback = function(Value)
		if not (W2_RacePrepare and W2_RaceStart and W2_RaceEnd and W2_RaceReward) then notify("Error", "W2 Race remotes not found!", 3); W2_LoopRace:Set(false); return end
		isW2RaceLooping = Value
		if Value then
			w2_raceThread = task.spawn(function()
				while isW2RaceLooping do runW2Race(); task.wait() end
			end)
			notify("Race Loop", "Started W2 Win Loop!", 2)
		else
			if w2_raceThread then task.cancel(w2_raceThread) w2_raceThread = nil end
			notify("Race Loop", "Stopped.", 2)
		end
	end
})

local W2_HatchGroup = TabWorld2:AddGroup("Left", "Hatchery Controls")
W2_HatchGroup:AddNote("🥚 Common | Uncommon | Rare | Epic | Legendary | Mythic")
local W2_EggSelect = W2_HatchGroup:AddDropdown({ Text = "Select Egg to Hatch", Options = W2_SORTED_EGGS, Default = "Common Egg" })

W2_HatchGroup:AddButton({ Text = "🥚 Hatch Once", Callback = function()
	if not W2_EggHatchRemote then notify("Error", "W2 EggHatch remote not found!", 3); return end
	local args = W2_EGG_REMOTE_ARGS[W2_EggSelect:Get()]
	if args then pcall(function() W2_EggHatchRemote:InvokeServer(table.unpack(args)) end) end
	notify("Hatched", "Opened: " .. W2_EggSelect:Get(), 2)
end })

local w2_hatchThread = nil
local isW2HatchLooping = false
local W2_LoopHatch
W2_LoopHatch = W2_HatchGroup:AddToggle({
	Text = "Auto Hatch Loop",
	Desc = "0s cooldown hatch spam",
	Default = false,
	Callback = function(Value)
		if not W2_EggHatchRemote then notify("Error", "W2 EggHatch remote not found!", 3); W2_LoopHatch:Set(false); return end
		isW2HatchLooping = Value
		if Value then
			w2_hatchThread = task.spawn(function()
				while isW2HatchLooping do
					local args = W2_EGG_REMOTE_ARGS[W2_EggSelect:Get()]
					if args then pcall(function() W2_EggHatchRemote:InvokeServer(table.unpack(args)) end) end
					task.wait()
				end
			end)
			notify("Hatch Loop Started", "Spamming: " .. W2_EggSelect:Get(), 2)
		else
			if w2_hatchThread then task.cancel(w2_hatchThread) w2_hatchThread = nil end
			notify("Hatch Loop Stopped", "Stopped hatching.", 2)
		end
	end
})

-- ============================================================
-- // WORLD 3 UI (TREADMILL & WIN LOOP ONLY)
-- ============================================================
local W3_TreadmillGroup = TabWorld3:AddGroup("Left", "Treadmill Controls")
local W3_SpeedSelect = W3_TreadmillGroup:AddDropdown({ Text = "Select Speed Amount", Options = W3_SORTED_LABELS, Default = "+1000 Speed" })

local w3_treadmillThread = nil
local isW3TreadmillLooping = false
local W3_LoopSpeed

-- FIXED: Using dedicated boolean flag for 100% reliable loop execution
W3_LoopSpeed = W3_TreadmillGroup:AddToggle({
	Text = "Loop Add Speed",
	Desc = "Continuously adds speed (0s cooldown)",
	Default = false,
	Callback = function(Value)
		if not W3_AddSpeedRemote then 
            notify("Error", "W3 AddSpeed remote not found!", 3)
            W3_LoopSpeed:Set(false)
            return 
        end
		
        isW3TreadmillLooping = Value
		if Value then
			w3_treadmillThread = task.spawn(function()
				while isW3TreadmillLooping do
					local selectedSpeed = W3_SpeedSelect:Get()
					local targetID = W3_LABEL_TO_ID[selectedSpeed]
					if targetID then 
                        pcall(function() W3_AddSpeedRemote:FireServer(targetID) end) 
                    end
					task.wait()
				end
			end)
			notify("Loop Started", "Farming " .. W3_SpeedSelect:Get(), 2)
		else
			if w3_treadmillThread then 
                task.cancel(w3_treadmillThread) 
                w3_treadmillThread = nil 
            end
			notify("Loop Stopped", "Treadmill loop terminated.", 2)
		end
	end
})

local W3_RaceGroup = TabWorld3:AddGroup("Right", "Win Loop / Race Controls")
local W3_RaceTypeSelect = W3_RaceGroup:AddDropdown({ Text = "Select Race Type", Options = W3_SORTED_RACE_TYPES, Default = "World 3 Race" })

local function runW3Race()
	pcall(function() W3_RacePrepare:InvokeServer() end)
	pcall(function() W3_RaceStart:FireServer() end)
	pcall(function() W3_RaceEnd:InvokeServer(0) end)
	local raceArgs = W3_RACE_TYPES[W3_RaceTypeSelect:Get()]
	if raceArgs then pcall(function() W3_RaceReward:FireServer(table.unpack(raceArgs)) end) end
end

W3_RaceGroup:AddButton({ Text = "Run Race Once", Primary = true, Callback = function()
	if not (W3_RacePrepare and W3_RaceStart and W3_RaceEnd and W3_RaceReward) then notify("Error", "W3 Race remotes not found!", 3); return end
	runW3Race(); notify("Race", W3_RaceTypeSelect:Get() .. " executed!", 2)
end })

local w3_raceThread = nil
local isW3RaceLooping = false
local W3_LoopRace
W3_LoopRace = W3_RaceGroup:AddToggle({
	Text = "Loop Race (Win Loop)",
	Desc = "0s cooldown win loop",
	Default = false,
	Callback = function(Value)
		if not (W3_RacePrepare and W3_RaceStart and W3_RaceEnd and W3_RaceReward) then notify("Error", "W3 Race remotes not found!", 3); W3_LoopRace:Set(false); return end
		isW3RaceLooping = Value
		if Value then
			w3_raceThread = task.spawn(function()
				while isW3RaceLooping do runW3Race(); task.wait() end
			end)
			notify("Race Loop", "Started W3 Win Loop!", 2)
		else
			if w3_raceThread then task.cancel(w3_raceThread) w3_raceThread = nil end
			notify("Race Loop", "Stopped W3 Win Loop.", 2)
		end
	end
})

-- ============================================================
-- // CONFIGS UI
-- ============================================================
local CfgLeft = TabConfig:AddGroup("Left", "Appearance")
CfgLeft:AddDropdown({
	Text = "Accent Color",
	Options = {"Monochrome", "Cyan", "Violet", "Emerald", "Crimson", "Amber"},
	Default = "Monochrome",
	Callback = function(themeName)
		setTheme(themeName)
		notify("Theme Updated", "Applied " .. themeName .. " accent.", 2)
	end,
})

local CfgRight = TabConfig:AddGroup("Right", "Interface")
CfgRight:AddButton({
	Text = "Unload & Destroy UI",
	Danger = true,
	Callback = function()
		if W1_LoopSpeed then W1_LoopSpeed:Set(false) end
		if W1_LoopRace then W1_LoopRace:Set(false) end
		if W1_LoopHatch then W1_LoopHatch:Set(false) end
		if W2_LoopSpeed then W2_LoopSpeed:Set(false) end
		if W2_LoopRace then W2_LoopRace:Set(false) end
		if W2_LoopHatch then W2_LoopHatch:Set(false) end
		if W3_LoopSpeed then W3_LoopSpeed:Set(false) end
		if W3_LoopRace then W3_LoopRace:Set(false) end
		
		notify("Unloaded", "All loops stopped. Destroying UI...", 2)
		task.wait(0.5)
		for _, conn in ipairs(connections) do pcall(function() conn:Disconnect() end) end
		local t = tween(MainScale, 0.18, { Scale = 0.88 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		t.Completed:Wait()
		ScreenGui:Destroy()
	end,
})
CfgRight:AddNote("Drag the top bar to move. Press RightShift anytime to toggle visibility.")

-- // Initial Layout Pass + Intro Animation
task.defer(function()
	for _, t in ipairs(tabs) do t.RefreshLayout() end
end)

tween(MainScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
notify("Multi-World Auto Farm", "Loaded successfully at MAX SPEED (0s cooldown)!", 3.2)
