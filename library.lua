-- // Custom Matte Dark Rounded UI Library

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer

local Library = {}

Library.Themes = {
	["Monochrome"] = Color3.fromRGB(255, 255, 255),
	["Cyan"]       = Color3.fromRGB(56, 189, 248),
	["Violet"]     = Color3.fromRGB(167, 139, 250),
	["Emerald"]    = Color3.fromRGB(52, 211, 153),
	["Crimson"]    = Color3.fromRGB(248, 113, 113),
	["Amber"]      = Color3.fromRGB(251, 191, 36),
}

local function getGuiParent()
	if type(gethui) == "function" then
		local ok, res = pcall(gethui)
		if ok and res then return res end
	end
	local ok, cg = pcall(function() return CoreGui end)
	if ok and cg then return cg end
	return player:WaitForChild("PlayerGui")
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
			if k ~= "Corner" and k ~= "Stroke" then
				f[k] = v
			end
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
	elseif kind == "player" then
		addPart({ Size = UDim2.new(0, 6, 0, 6), Position = UDim2.new(0, 5, 0, 2), BackgroundTransparency = 1, Corner = true, Stroke = 1.5 })
		addPart({ Size = UDim2.new(0, 11, 0, 5), Position = UDim2.new(0, 2, 0, 10), BackgroundTransparency = 1, Corner = true, Stroke = 1.5 })
	elseif kind == "teleport" then
		addPart({ Size = UDim2.new(0, 11, 0, 11), Position = UDim2.new(0, 2, 0, 2), BackgroundTransparency = 1, Corner = true, Stroke = 1.5 })
		addPart({ Size = UDim2.new(0, 4, 0, 4), Position = UDim2.new(0, 6, 0, 6), Corner = true })
	elseif kind == "configs" then
		addPart({ Size = UDim2.new(0, 11, 0, 11), Position = UDim2.new(0, 2, 0, 2), BackgroundTransparency = 1, Corner = true, Stroke = 1.6 })
		addPart({ Size = UDim2.new(0, 3, 0, 3), Position = UDim2.new(0, 6, 0, 6), Corner = true })
	else
		addPart({ Size = UDim2.new(0, 10, 0, 10), Position = UDim2.new(0, 3, 0, 3), BackgroundTransparency = 1, Corner = true, Stroke = 1.5 })
		addPart({ Size = UDim2.new(0, 4, 0, 4), Position = UDim2.new(0, 6, 0, 6), Corner = true })
	end

	return {
		SetColor = function(_, newCol)
			for _, p in ipairs(parts) do
				if p.BackgroundTransparency < 1 then
					tween(p, 0.15, { BackgroundColor3 = newCol })
				end
				local s = p:FindFirstChildOfClass("UIStroke")
				if s then tween(s, 0.15, { Color = newCol }) end
			end
		end,
	}
end

function Library:CreateWindow(opts)
	opts = opts or {}
	local winTitle = opts.Name or "New Window"
	local winSub = opts.Subtitle
	local badgeText = opts.Badge
	if badgeText == nil then badgeText = "BETA" end

	local size = opts.Size or UDim2.fromOffset(710, 470)
	local WIN_W = size.X.Offset > 0 and size.X.Offset or 710
	local WIN_H = size.Y.Offset > 0 and size.Y.Offset or 470
	local HEADER_H = 48
	local SIDEBAR_W = 176

	local startAccent = Library.Themes.Monochrome
	if type(opts.Theme) == "string" and Library.Themes[opts.Theme] then
		startAccent = Library.Themes[opts.Theme]
	elseif typeof(opts.Theme) == "Color3" then
		startAccent = opts.Theme
	end

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
		Accent     = startAccent,
	}

	local GUI_NAME = "MatteRoundedUILibrary"
	local guiParent = getGuiParent()
	local oldGui = guiParent:FindFirstChild(GUI_NAME)
	if oldGui then oldGui:Destroy() end

	local connections = {}
	local function trackConn(conn)
		table.insert(connections, conn)
		return conn
	end

	local accentListeners = {}
	local function onAccent(fn)
		table.insert(accentListeners, fn)
		fn(Palette.Accent)
	end

	local ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = GUI_NAME
	ScreenGui.ResetOnSpawn = false
	ScreenGui.IgnoreGuiInset = true
	ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	ScreenGui.Parent = guiParent

	ScreenGui.Destroying:Connect(function()
		for _, conn in ipairs(connections) do
			pcall(function() conn:Disconnect() end)
		end
		table.clear(connections)
	end)

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
		duration = duration or 2.6
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
		tLbl.Text = title or ""
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
		dLbl.Text = desc or ""
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

	-- // Ambient Rounded Shapes Layer
	local DecorLayer = Instance.new("Frame")
	DecorLayer.Size = UDim2.new(1, 0, 1, 0)
	DecorLayer.BackgroundTransparency = 1
	DecorLayer.ClipsDescendants = true
	DecorLayer.ZIndex = 1
	DecorLayer.Parent = Inner

	local function addRoundedBlob(bSize, pos, transparency, isAccent, strokeThickness, rotation)
		local shape = Instance.new("Frame")
		shape.Size = bSize
		shape.Position = pos
		shape.Rotation = rotation or 0
		shape.BorderSizePixel = 0
		shape.BackgroundColor3 = isAccent and Palette.Accent or Color3.fromRGB(255, 255, 255)
		shape.BackgroundTransparency = strokeThickness and 1 or transparency
		shape.Parent = DecorLayer
		roundify(shape, UDim.new(1, 0))

		local st
		if strokeThickness then
			st = Instance.new("UIStroke")
			st.Color = isAccent and Palette.Accent or Color3.fromRGB(255, 255, 255)
			st.Thickness = strokeThickness
			st.Transparency = transparency
			st.Parent = shape
		end

		if isAccent then
			onAccent(function(c)
				if strokeThickness and st then
					tween(st, 0.3, { Color = c })
				else
					tween(shape, 0.3, { BackgroundColor3 = c })
				end
			end)
		end
	end

	addRoundedBlob(UDim2.new(0, 230, 0, 230), UDim2.new(1, -135, 0, -90), 0.955, true)
	addRoundedBlob(UDim2.new(0, 180, 0, 180), UDim2.new(1, -95, 1, -105), 0.91, true, 1.5)
	addRoundedBlob(UDim2.new(0, 140, 0, 140), UDim2.new(0, -55, 1, -75), 0.965, false)
	addRoundedBlob(UDim2.new(0, 94, 0, 28), UDim2.new(0, 195, 1, -42), 0.96, true, nil, -18)
	addRoundedBlob(UDim2.new(0, 64, 0, 20), UDim2.new(1, -210, 0, 62), 0.965, false, nil, 14)
	addRoundedBlob(UDim2.new(0, 22, 0, 22), UDim2.new(0.5, 40, 0.5, -10), 0.93, true, 1.2)

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

	onAccent(function(c)
		tween(LogoCircle, 0.25, { BackgroundColor3 = c })
	end)

	local HeaderMeta = Instance.new("TextLabel")
	HeaderMeta.Position = UDim2.new(0, 48, 0, 0)
	HeaderMeta.Size = UDim2.new(1, -214, 1, 0)
	HeaderMeta.BackgroundTransparency = 1
	HeaderMeta.Font = Enum.Font.GothamMedium
	HeaderMeta.RichText = true
	if winSub and winSub ~= "" then
		HeaderMeta.Text = "<b>" .. winTitle .. "</b>   <font color='#3F3F46'>|</font>   <font color='#A1A1AA'>" .. winSub .. "</font>"
	else
		HeaderMeta.Text = "<b>" .. winTitle .. "</b>"
	end
	HeaderMeta.TextColor3 = Palette.Text
	HeaderMeta.TextSize = 12.5
	HeaderMeta.TextXAlignment = Enum.TextXAlignment.Left
	HeaderMeta.TextTruncate = Enum.TextTruncate.AtEnd
	HeaderMeta.Parent = Header

	if badgeText and badgeText ~= "" and badgeText ~= false then
		local BetaPill = Instance.new("Frame")
		BetaPill.Size = UDim2.new(0, 48, 0, 20)
		BetaPill.Position = UDim2.new(1, -158, 0.5, -10)
		BetaPill.BackgroundColor3 = Palette.RowBg
		BetaPill.BorderSizePixel = 0
		BetaPill.Parent = Header
		roundify(BetaPill, UDim.new(1, 0))

		local BetaStroke = Instance.new("UIStroke")
		BetaStroke.Color = Palette.BorderSoft
		BetaStroke.Thickness = 1
		BetaStroke.Parent = BetaPill

		local BetaLbl = Instance.new("TextLabel")
		BetaLbl.Size = UDim2.new(1, 0, 1, 0)
		BetaLbl.BackgroundTransparency = 1
		BetaLbl.Font = Enum.Font.GothamBold
		BetaLbl.Text = tostring(badgeText)
		BetaLbl.TextColor3 = Palette.Accent
		BetaLbl.TextSize = 9.5
		BetaLbl.Parent = BetaPill

		onAccent(function(c)
			tween(BetaLbl, 0.25, { TextColor3 = c })
		end)
	end

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

	-- // Quick Search Drawer
	local QuickSearchBar = Instance.new("Frame")
	QuickSearchBar.Position = UDim2.new(0, 0, 0, HEADER_H)
	QuickSearchBar.Size = UDim2.new(1, 0, 0, 0)
	QuickSearchBar.BackgroundColor3 = Palette.CardBg
	QuickSearchBar.BackgroundTransparency = 0.15
	QuickSearchBar.ClipsDescendants = true
	QuickSearchBar.BorderSizePixel = 0
	QuickSearchBar.Visible = false
	QuickSearchBar.ZIndex = 4
	QuickSearchBar.Parent = Inner

	local QuickSearchBox = Instance.new("TextBox")
	QuickSearchBox.Position = UDim2.new(0, 14, 0, 6)
	QuickSearchBox.Size = UDim2.new(1, -28, 0, 28)
	QuickSearchBox.BackgroundColor3 = Palette.InputBg
	QuickSearchBox.Font = Enum.Font.Gotham
	QuickSearchBox.PlaceholderText = "Search features..."
	QuickSearchBox.PlaceholderColor3 = Palette.MutedText
	QuickSearchBox.Text = ""
	QuickSearchBox.TextColor3 = Palette.Text
	QuickSearchBox.TextSize = 12
	QuickSearchBox.TextXAlignment = Enum.TextXAlignment.Left
	QuickSearchBox.ClearTextOnFocus = false
	QuickSearchBox.Parent = QuickSearchBar
	roundify(QuickSearchBox, UDim.new(1, 0))

	local qsPad = Instance.new("UIPadding")
	qsPad.PaddingLeft = UDim.new(0, 14)
	qsPad.PaddingRight = UDim.new(0, 14)
	qsPad.Parent = QuickSearchBox

	local qsStroke = Instance.new("UIStroke")
	qsStroke.Color = Palette.Border
	qsStroke.Thickness = 1
	qsStroke.Parent = QuickSearchBox

	local qsLine = Instance.new("Frame")
	qsLine.Size = UDim2.new(1, -28, 0, 1)
	qsLine.Position = UDim2.new(0, 14, 1, -1)
	qsLine.BackgroundColor3 = Palette.Border
	qsLine.BorderSizePixel = 0
	qsLine.Parent = QuickSearchBar
	roundify(qsLine, UDim.new(1, 0))

	-- // Body & Sidebar
	local Body = Instance.new("Frame")
	Body.Position = UDim2.new(0, 0, 0, HEADER_H)
	Body.Size = UDim2.new(1, 0, 1, -HEADER_H)
	Body.BackgroundTransparency = 1
	Body.ZIndex = 2
	Body.Parent = Inner

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

	local AvatarStroke = Instance.new("UIStroke")
	AvatarStroke.Color = Palette.BorderSoft
	AvatarStroke.Thickness = 1
	AvatarStroke.Parent = AvatarCircle

	local AvatarInitial = Instance.new("TextLabel")
	AvatarInitial.Size = UDim2.new(1, 0, 1, 0)
	AvatarInitial.BackgroundTransparency = 1
	AvatarInitial.Font = Enum.Font.GothamBold
	AvatarInitial.Text = string.upper(string.sub(player.DisplayName, 1, 1))
	AvatarInitial.TextColor3 = Palette.Text
	AvatarInitial.TextSize = 13
	AvatarInitial.Parent = AvatarCircle

	local StatusDot = Instance.new("Frame")
	StatusDot.Size = UDim2.new(0, 8, 0, 8)
	StatusDot.Position = UDim2.new(1, -8, 1, -8)
	StatusDot.BackgroundColor3 = Palette.Accent
	StatusDot.BorderSizePixel = 0
	StatusDot.Parent = AvatarCircle
	roundify(StatusDot, UDim.new(1, 0))

	onAccent(function(c)
		tween(StatusDot, 0.25, { BackgroundColor3 = c })
	end)

	local ProfTitle = Instance.new("TextLabel")
	ProfTitle.Position = UDim2.new(0, 50, 0, 9)
	ProfTitle.Size = UDim2.new(1, -58, 0, 17)
	ProfTitle.BackgroundTransparency = 1
	ProfTitle.Font = Enum.Font.GothamBold
	ProfTitle.Text = opts.ProfileTitle or "User"
	ProfTitle.TextColor3 = Palette.Text
	ProfTitle.TextSize = 12.5
	ProfTitle.TextXAlignment = Enum.TextXAlignment.Left
	ProfTitle.Parent = ProfileBlock

	local ProfSub = Instance.new("TextLabel")
	ProfSub.Position = UDim2.new(0, 50, 0, 26)
	ProfSub.Size = UDim2.new(1, -58, 0, 14)
	ProfSub.BackgroundTransparency = 1
	ProfSub.Font = Enum.Font.Gotham
	ProfSub.Text = opts.ProfileSub or player.DisplayName
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
	ActivePill.Visible = false
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

	onAccent(function(c)
		tween(ActiveBar, 0.25, { BackgroundColor3 = c })
	end)

	local NavList = Instance.new("Frame")
	NavList.Size = UDim2.new(1, 0, 1, 0)
	NavList.BackgroundTransparency = 1
	NavList.ZIndex = 3
	NavList.Parent = NavHolder

	local ContentArea = Instance.new("Frame")
	ContentArea.Position = UDim2.new(0, SIDEBAR_W, 0, 0)
	ContentArea.Size = UDim2.new(1, -SIDEBAR_W, 1, 0)
	ContentArea.BackgroundTransparency = 1
	ContentArea.ClipsDescendants = true
	ContentArea.Parent = Body

	-- // Dragging
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

	-- // Visibility, Collapse & Quick Search
	local isCollapsed = false
	local isUiVisible = true
	local toggleUiKey = opts.ToggleKey or Enum.KeyCode.RightShift

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

	trackConn(UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or UserInputService:GetFocusedTextBox() then return end
		if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == toggleUiKey then
			setUiVisible(not isUiVisible)
		end
	end))

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

	local isSearchOpen = false
	SearchHeaderBtn.MouseButton1Click:Connect(function()
		isSearchOpen = not isSearchOpen
		if isSearchOpen then
			QuickSearchBar.Visible = true
			tween(QuickSearchBar, 0.22, { Size = UDim2.new(1, 0, 0, 40) })
			tween(Body, 0.22, { Position = UDim2.new(0, 0, 0, HEADER_H + 40), Size = UDim2.new(1, 0, 1, -(HEADER_H + 40)) })
			QuickSearchBox:CaptureFocus()
		else
			QuickSearchBox.Text = ""
			local t = tween(QuickSearchBar, 0.18, { Size = UDim2.new(1, 0, 0, 0) })
			tween(Body, 0.18, { Position = UDim2.new(0, 0, 0, HEADER_H), Size = UDim2.new(1, 0, 1, -HEADER_H) })
			t.Completed:Connect(function()
				if not isSearchOpen then QuickSearchBar.Visible = false end
			end)
		end
	end)

	-- // Window API
	local Window = {}
	local tabs = {}
	local activeTab = nil
	local allSearchables = {}

	QuickSearchBox:GetPropertyChangedSignal("Text"):Connect(function()
		local q = string.lower(QuickSearchBox.Text or "")
		if q == "" then return end
		for _, entry in ipairs(allSearchables) do
			if string.find(entry.Keywords, q, 1, true) then
				entry.Tab.Activate()
				break
			end
		end
	end)

	function Window:Notify(title, desc, duration)
		notify(title, desc, duration)
	end

	function Window:SetTheme(theme)
		local c = nil
		if type(theme) == "string" then
			c = Library.Themes[theme]
		elseif typeof(theme) == "Color3" then
			c = theme
		end
		if not c then return end
		Palette.Accent = c
		for _, fn in ipairs(accentListeners) do
			pcall(fn, c)
		end
	end

	function Window:SetToggleKey(keyCode)
		toggleUiKey = keyCode
	end

	function Window:Destroy()
		local t = tween(MainScale, 0.18, { Scale = 0.88 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		t.Completed:Wait()
		ScreenGui:Destroy()
	end

	function Window:CreateTab(tabOpts, iconArg)
		local name = type(tabOpts) == "table" and (tabOpts.Name or "New Tab") or tostring(tabOpts or "New Tab")
		local iconKind = type(tabOpts) == "table" and (tabOpts.Icon or "default") or (iconArg or "default")

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
			Index = idx,
			Name = name,
			Icon = ico,
			NameLbl = nameLbl,
			Page = page,
			RefreshLayout = refreshPageLayout,
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
			ActivePill.Visible = true
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
			local isRight = string.lower(tostring(side or "left")) == "right"
			local parentCol = isRight and rightCol or leftCol

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
			pad.PaddingTop = UDim.new(0, 11)
			pad.PaddingBottom = UDim.new(0, 11)
			pad.PaddingLeft = UDim.new(0, 11)
			pad.PaddingRight = UDim.new(0, 11)
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

				onAccent(function(c)
					tween(dot, 0.25, { BackgroundColor3 = c })
				end)

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

			local function registerSearch(keywords)
				table.insert(allSearchables, {
					Keywords = string.lower(keywords),
					Tab = tabObj,
				})
			end

			function groupObj:AddNote(text)
				local wrap = Instance.new("Frame")
				wrap.Size = UDim2.new(1, 0, 0, 36)
				wrap.AutomaticSize = Enum.AutomaticSize.Y
				wrap.BackgroundColor3 = Palette.RowBg
				wrap.BackgroundTransparency = 0.45
				wrap.Parent = card
				roundify(wrap, UDim.new(0, 12))

				local wPad = Instance.new("UIPadding")
				wPad.PaddingTop = UDim.new(0, 8)
				wPad.PaddingBottom = UDim.new(0, 8)
				wPad.PaddingLeft = UDim.new(0, 22)
				wPad.PaddingRight = UDim.new(0, 10)
				wPad.Parent = wrap

				local dot = Instance.new("Frame")
				dot.Size = UDim2.new(0, 6, 0, 6)
				dot.Position = UDim2.new(0, -12, 0, 4)
				dot.BackgroundColor3 = Palette.SubText
				dot.BorderSizePixel = 0
				dot.Parent = wrap
				roundify(dot, UDim.new(1, 0))

				local lbl = Instance.new("TextLabel")
				lbl.Size = UDim2.new(1, 0, 0, 0)
				lbl.AutomaticSize = Enum.AutomaticSize.Y
				lbl.BackgroundTransparency = 1
				lbl.Font = Enum.Font.Gotham
				lbl.Text = text or ""
				lbl.TextColor3 = Palette.MutedText
				lbl.TextSize = 11
				lbl.TextWrapped = true
				lbl.TextXAlignment = Enum.TextXAlignment.Left
				lbl.Parent = wrap

				syncCardHeight()
				return {
					Set = function(_, txt)
						lbl.Text = txt or ""
						syncCardHeight()
					end,
				}
			end

			function groupObj:AddToggle(tOpts)
				tOpts = tOpts or {}
				local labelText = tOpts.Text or tOpts.Name or "New Toggle"
				local descText = tOpts.Desc or tOpts.Description
				local value = tOpts.Default or false
				local hasDesc = descText ~= nil and descText ~= ""

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
				tLbl.Text = labelText
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
					dLbl.Text = descText
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
					if not silent and tOpts.Callback then tOpts.Callback(value) end
				end
				function api:Get() return value end

				row.MouseEnter:Connect(function() tween(row, 0.12, { BackgroundColor3 = Palette.RowHover }) end)
				row.MouseLeave:Connect(function() tween(row, 0.12, { BackgroundColor3 = Palette.RowBg }) end)
				row.MouseButton1Click:Connect(function() api:Set(not value) end)

				syncCardHeight()
				registerSearch(labelText .. " " .. (descText or ""))
				return api
			end

			function groupObj:AddSlider(sOpts)
				sOpts = sOpts or {}
				local labelText = sOpts.Text or sOpts.Name or "New Slider"
				local minVal = sOpts.Min or 0
				local maxVal = sOpts.Max or 100
				local step = sOpts.Step or 1
				local decimals = sOpts.Decimals or 0
				local value = math.clamp(sOpts.Default or minVal, minVal, maxVal)

				local box = Instance.new("Frame")
				box.Size = UDim2.new(1, 0, 0, 46)
				box.BackgroundTransparency = 1
				box.Parent = card

				local tLbl = Instance.new("TextLabel")
				tLbl.Size = UDim2.new(1, -55, 0, 16)
				tLbl.Position = UDim2.new(0, 2, 0, 2)
				tLbl.BackgroundTransparency = 1
				tLbl.Font = Enum.Font.GothamMedium
				tLbl.Text = labelText
				tLbl.TextColor3 = Palette.Text
				tLbl.TextSize = 12
				tLbl.TextXAlignment = Enum.TextXAlignment.Left
				tLbl.Parent = box

				local vLbl = Instance.new("TextLabel")
				vLbl.Size = UDim2.new(0, 50, 0, 16)
				vLbl.Position = UDim2.new(1, -52, 0, 2)
				vLbl.BackgroundTransparency = 1
				vLbl.Font = Enum.Font.GothamBold
				vLbl.TextColor3 = Palette.SubText
				vLbl.TextSize = 12
				vLbl.TextXAlignment = Enum.TextXAlignment.Right
				vLbl.Parent = box

				local hit = Instance.new("TextButton")
				hit.Size = UDim2.new(1, -4, 0, 22)
				hit.Position = UDim2.new(0, 2, 0, 22)
				hit.BackgroundTransparency = 1
				hit.Text = ""
				hit.AutoButtonColor = false
				hit.Parent = box

				local track = Instance.new("Frame")
				track.Size = UDim2.new(1, 0, 0, 5)
				track.Position = UDim2.new(0, 0, 0.5, -2)
				track.BackgroundColor3 = Color3.fromRGB(50, 50, 58)
				track.BorderSizePixel = 0
				track.Parent = hit
				roundify(track, UDim.new(1, 0))

				local fill = Instance.new("Frame")
				fill.Size = UDim2.new(0, 0, 1, 0)
				fill.BackgroundColor3 = Palette.Accent
				fill.BorderSizePixel = 0
				fill.Parent = track
				roundify(fill, UDim.new(1, 0))

				local thumbRing = Instance.new("Frame")
				thumbRing.AnchorPoint = Vector2.new(0.5, 0.5)
				thumbRing.Size = UDim2.new(0, 20, 0, 20)
				thumbRing.Position = UDim2.new(0, 0, 0.5, 0)
				thumbRing.BackgroundColor3 = Palette.Accent
				thumbRing.BackgroundTransparency = 0.84
				thumbRing.BorderSizePixel = 0
				thumbRing.Parent = track
				roundify(thumbRing, UDim.new(1, 0))

				local thumb = Instance.new("Frame")
				thumb.AnchorPoint = Vector2.new(0.5, 0.5)
				thumb.Size = UDim2.new(0, 12, 0, 12)
				thumb.Position = UDim2.new(0.5, 0, 0.5, 0)
				thumb.BackgroundColor3 = Palette.Accent
				thumb.BorderSizePixel = 0
				thumb.Parent = thumbRing
				roundify(thumb, UDim.new(1, 0))

				onAccent(function(c)
					tween(fill, 0.25, { BackgroundColor3 = c })
					tween(thumbRing, 0.25, { BackgroundColor3 = c })
					tween(thumb, 0.25, { BackgroundColor3 = c })
				end)

				local function fmt(n)
					return decimals == 0 and tostring(math.floor(n + 0.5)) or string.format("%." .. decimals .. "f", n)
				end

				local function apply(newVal, silent)
					local snapped = math.floor((newVal - minVal) / step + 0.5) * step + minVal
					snapped = math.clamp(snapped, minVal, maxVal)
					value = tonumber(fmt(snapped)) or snapped
					local pct = (maxVal > minVal) and ((value - minVal) / (maxVal - minVal)) or 0
					vLbl.Text = fmt(value) .. (sOpts.Suffix or "")
					tween(fill, 0.06, { Size = UDim2.new(pct, 0, 1, 0) })
					tween(thumbRing, 0.06, { Position = UDim2.new(pct, 0, 0.5, 0) })
					if not silent and sOpts.Callback then sOpts.Callback(value) end
				end

				apply(value, true)

				local dragging = false
				local function slideTo(pos)
					local w = track.AbsoluteSize.X
					if w <= 0 then return end
					local pct = math.clamp((pos.X - track.AbsolutePosition.X) / w, 0, 1)
					apply(minVal + pct * (maxVal - minVal))
				end

				hit.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						dragging = true
						tween(thumbRing, 0.1, { Size = UDim2.new(0, 24, 0, 24) })
						tween(thumb, 0.1, { Size = UDim2.new(0, 14, 0, 14) })
						slideTo(input.Position)
					end
				end)
				trackConn(UserInputService.InputChanged:Connect(function(input)
					if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
						slideTo(input.Position)
					end
				end))
				trackConn(UserInputService.InputEnded:Connect(function(input)
					if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
						dragging = false
						tween(thumbRing, 0.12, { Size = UDim2.new(0, 20, 0, 20) })
						tween(thumb, 0.12, { Size = UDim2.new(0, 12, 0, 12) })
					end
				end))

				syncCardHeight()
				registerSearch(labelText)
				return {
					Get = function() return value end,
					Set = function(_, v, silent) apply(v, silent) end,
				}
			end

			function groupObj:AddSegmented(segOpts)
				segOpts = segOpts or {}
				local choices = segOpts.Options or {"Option 1", "Option 2"}
				local selected = segOpts.Default or choices[1]

				local wrap = Instance.new("Frame")
				wrap.Size = UDim2.new(1, 0, 0, segOpts.Label and 58 or 36)
				wrap.BackgroundTransparency = 1
				wrap.Parent = card

				if segOpts.Label then
					local topLbl = Instance.new("TextLabel")
					topLbl.Size = UDim2.new(1, 0, 0, 16)
					topLbl.BackgroundTransparency = 1
					topLbl.Font = Enum.Font.Gotham
					topLbl.Text = segOpts.Label
					topLbl.TextColor3 = Palette.SubText
					topLbl.TextSize = 11
					topLbl.TextXAlignment = Enum.TextXAlignment.Center
					topLbl.Parent = wrap
				end

				local bar = Instance.new("Frame")
				bar.Size = UDim2.new(1, 0, 0, 36)
				bar.Position = UDim2.new(0, 0, 0, segOpts.Label and 20 or 0)
				bar.BackgroundColor3 = Palette.InputBg
				bar.Parent = wrap
				roundify(bar, UDim.new(1, 0))

				local bStroke = Instance.new("UIStroke")
				bStroke.Color = Palette.Border
				bStroke.Thickness = 1
				bStroke.Parent = bar

				local innerBar = Instance.new("Frame")
				innerBar.Size = UDim2.new(1, -6, 1, -6)
				innerBar.Position = UDim2.new(0, 3, 0, 3)
				innerBar.BackgroundTransparency = 1
				innerBar.Parent = bar

				local btns = {}
				local count = math.max(#choices, 1)
				for i, ch in ipairs(choices) do
					local b = Instance.new("TextButton")
					b.Size = UDim2.new(1 / count, 0, 1, 0)
					b.Position = UDim2.new((i - 1) / count, 0, 0, 0)
					b.BackgroundColor3 = Palette.RowHover
					b.BackgroundTransparency = (ch == selected) and 0 or 1
					b.Font = (ch == selected) and Enum.Font.GothamBold or Enum.Font.GothamMedium
					b.Text = ch
					b.TextColor3 = (ch == selected) and Palette.Text or Palette.SubText
					b.TextSize = 12
					b.AutoButtonColor = false
					b.Parent = innerBar
					roundify(b, UDim.new(1, 0))
					btns[ch] = b

					b.MouseButton1Click:Connect(function()
						selected = ch
						for k, btnRef in pairs(btns) do
							local on = (k == selected)
							tween(btnRef, 0.16, {
								BackgroundTransparency = on and 0 or 1,
								TextColor3 = on and Palette.Text or Palette.SubText,
							})
							btnRef.Font = on and Enum.Font.GothamBold or Enum.Font.GothamMedium
						end
						if segOpts.Callback then segOpts.Callback(selected) end
					end)
				end

				syncCardHeight()
				registerSearch((segOpts.Label or "") .. " " .. table.concat(choices, " "))
			end

			function groupObj:AddDropdown(dOpts)
				dOpts = dOpts or {}
				local labelText = dOpts.Text or dOpts.Name or "New Dropdown"
				local options = dOpts.Options or dOpts.Items or {"Option 1", "Option 2"}
				local selected = dOpts.Default or options[1] or "None"
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
				lbl.Text = labelText
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
							if dOpts.Callback then dOpts.Callback(selected) end
						end)
					end
					scroll.CanvasSize = UDim2.new(0, 0, 0, sLayout.AbsoluteContentSize.Y + 4)
				end

				buildList()
				topBtn.MouseButton1Click:Connect(function() setOpenState(not open) end)

				syncCardHeight()
				registerSearch(labelText)
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

			function groupObj:AddInput(iOpts)
				iOpts = iOpts or {}
				local wrap = Instance.new("Frame")
				wrap.Size = UDim2.new(1, 0, 0, iOpts.Label and 56 or 36)
				wrap.BackgroundTransparency = 1
				wrap.Parent = card

				if iOpts.Label then
					local l = Instance.new("TextLabel")
					l.Size = UDim2.new(1, 0, 0, 16)
					l.Position = UDim2.new(0, 2, 0, 0)
					l.BackgroundTransparency = 1
					l.Font = Enum.Font.GothamMedium
					l.Text = iOpts.Label
					l.TextColor3 = Palette.Text
					l.TextSize = 12
					l.TextXAlignment = Enum.TextXAlignment.Left
					l.Parent = wrap
				end

				local boxFrame = Instance.new("Frame")
				boxFrame.Position = UDim2.new(0, 0, 0, iOpts.Label and 20 or 0)
				boxFrame.Size = UDim2.new(1, 0, 0, 34)
				boxFrame.BackgroundColor3 = Palette.InputBg
				boxFrame.Parent = wrap
				roundify(boxFrame, UDim.new(1, 0))

				local fStroke = Instance.new("UIStroke")
				fStroke.Color = Palette.Border
				fStroke.Thickness = 1
				fStroke.Parent = boxFrame

				local tb = Instance.new("TextBox")
				tb.Position = UDim2.new(0, 14, 0, 0)
				tb.Size = UDim2.new(1, -44, 1, 0)
				tb.BackgroundTransparency = 1
				tb.Font = Enum.Font.Gotham
				tb.PlaceholderText = iOpts.Placeholder or "Type here..."
				tb.PlaceholderColor3 = Palette.MutedText
				tb.Text = iOpts.Default or ""
				tb.TextColor3 = Palette.Text
				tb.TextSize = 12
				tb.TextXAlignment = Enum.TextXAlignment.Left
				tb.ClearTextOnFocus = false
				tb.Parent = boxFrame

				local clr = Instance.new("TextButton")
				clr.Size = UDim2.new(0, 20, 0, 20)
				clr.Position = UDim2.new(1, -28, 0.5, -10)
				clr.BackgroundColor3 = Palette.RowBg
				clr.Font = Enum.Font.GothamBold
				clr.Text = "x"
				clr.TextColor3 = Palette.SubText
				clr.TextSize = 11
				clr.Visible = (tb.Text ~= "")
				clr.AutoButtonColor = false
				clr.Parent = boxFrame
				roundify(clr, UDim.new(1, 0))

				tb.Focused:Connect(function() tween(fStroke, 0.15, { Color = Palette.Accent }) end)
				tb.FocusLost:Connect(function() tween(fStroke, 0.15, { Color = Palette.Border }) end)
				tb:GetPropertyChangedSignal("Text"):Connect(function()
					clr.Visible = (tb.Text ~= "")
					if iOpts.Callback then iOpts.Callback(tb.Text) end
				end)
				clr.MouseButton1Click:Connect(function() tb.Text = "" end)

				syncCardHeight()
				registerSearch((iOpts.Label or "") .. " " .. (iOpts.Placeholder or ""))
				return {
					Get = function() return tb.Text end,
					Set = function(_, v) tb.Text = v or "" end,
				}
			end

			function groupObj:AddButton(bOpts)
				bOpts = bOpts or {}
				local labelText = bOpts.Text or bOpts.Name or "New Button"

				local b = Instance.new("TextButton")
				b.Size = UDim2.new(1, 0, 0, 36)
				b.BackgroundColor3 = bOpts.Primary and Palette.Accent or Palette.RowBg
				b.BackgroundTransparency = bOpts.Primary and 0.9 or 0
				b.Text = ""
				b.AutoButtonColor = false
				b.Parent = card
				roundify(b, UDim.new(1, 0))

				local bStroke = Instance.new("UIStroke")
				bStroke.Color = bOpts.Danger and Color3.fromRGB(220, 75, 85) or (bOpts.Primary and Palette.Accent or Palette.Border)
				bStroke.Thickness = 1
				bStroke.Transparency = bOpts.Primary and 0.35 or 0
				bStroke.Parent = b

				local lbl = Instance.new("TextLabel")
				lbl.Size = UDim2.new(1, -20, 1, 0)
				lbl.Position = UDim2.new(0, 10, 0, 0)
				lbl.BackgroundTransparency = 1
				lbl.Font = Enum.Font.GothamBold
				lbl.Text = labelText
				lbl.TextColor3 = bOpts.Danger and Color3.fromRGB(248, 113, 113) or (bOpts.Primary and Palette.Accent or Palette.Text)
				lbl.TextSize = 12
				lbl.Parent = b

				if bOpts.Primary then
					onAccent(function(c)
						tween(b, 0.25, { BackgroundColor3 = c })
						tween(bStroke, 0.25, { Color = c })
						tween(lbl, 0.25, { TextColor3 = c })
					end)
				end

				b.MouseEnter:Connect(function()
					if bOpts.Primary then
						tween(b, 0.14, { BackgroundTransparency = 0.8 })
					else
						tween(b, 0.14, { BackgroundColor3 = Palette.RowHover })
					end
				end)
				b.MouseLeave:Connect(function()
					if bOpts.Primary then
						tween(b, 0.14, { BackgroundTransparency = 0.9 })
					else
						tween(b, 0.14, { BackgroundColor3 = Palette.RowBg })
					end
				end)
				b.MouseButton1Click:Connect(function()
					if bOpts.Callback then bOpts.Callback() end
				end)

				syncCardHeight()
				registerSearch(labelText)
				return b
			end

			function groupObj:AddKeybind(kOpts)
				kOpts = kOpts or {}
				local labelText = kOpts.Text or kOpts.Name or "New Keybind"
				local currentKey = kOpts.Default or Enum.KeyCode.F
				local listening = false

				local row = Instance.new("Frame")
				row.Size = UDim2.new(1, 0, 0, 42)
				row.BackgroundColor3 = Palette.RowBg
				row.Parent = card
				roundify(row, UDim.new(0, 14))

				local rStroke = Instance.new("UIStroke")
				rStroke.Color = Palette.Border
				rStroke.Thickness = 1
				rStroke.Parent = row

				local tLbl = Instance.new("TextLabel")
				tLbl.Position = UDim2.new(0, 14, 0, 0)
				tLbl.Size = UDim2.new(1, -108, 1, 0)
				tLbl.BackgroundTransparency = 1
				tLbl.Font = Enum.Font.GothamMedium
				tLbl.Text = labelText
				tLbl.TextColor3 = Palette.Text
				tLbl.TextSize = 12.5
				tLbl.TextXAlignment = Enum.TextXAlignment.Left
				tLbl.Parent = row

				local kBtn = Instance.new("TextButton")
				kBtn.Size = UDim2.new(0, 82, 0, 24)
				kBtn.Position = UDim2.new(1, -90, 0.5, -12)
				kBtn.BackgroundColor3 = Palette.InputBg
				kBtn.Font = Enum.Font.GothamBold
				kBtn.Text = currentKey.Name
				kBtn.TextColor3 = Palette.Text
				kBtn.TextSize = 11
				kBtn.AutoButtonColor = false
				kBtn.Parent = row
				roundify(kBtn, UDim.new(1, 0))

				local kStroke = Instance.new("UIStroke")
				kStroke.Color = Palette.Border
				kStroke.Thickness = 1
				kStroke.Parent = kBtn

				kBtn.MouseButton1Click:Connect(function()
					listening = true
					kBtn.Text = "..."
					tween(kStroke, 0.14, { Color = Palette.Accent })
				end)

				trackConn(UserInputService.InputBegan:Connect(function(input, gameProcessed)
					if listening and input.UserInputType == Enum.UserInputType.Keyboard then
						listening = false
						currentKey = input.KeyCode
						kBtn.Text = currentKey.Name
						tween(kStroke, 0.14, { Color = Palette.Border })
						if kOpts.OnChanged then kOpts.OnChanged(currentKey) end
						return
					end
					if gameProcessed or UserInputService:GetFocusedTextBox() then return end
					if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == currentKey then
						if kOpts.Callback then kOpts.Callback() end
					end
				end))

				syncCardHeight()
				registerSearch(labelText)
				return { Get = function() return currentKey end }
			end

			return groupObj
		end

		-- // Convenience shortcuts if you call Tab:AddButton(...) directly without AddGroup
		local defaultGroup = nil
		local function getDefaultGroup()
			if not defaultGroup then
				defaultGroup = tabObj:AddGroup("Left")
			end
			return defaultGroup
		end
		for _, method in ipairs({"AddNote", "AddToggle", "AddSlider", "AddSegmented", "AddDropdown", "AddInput", "AddButton", "AddKeybind"}) do
			tabObj[method] = function(_, ...)
				local g = getDefaultGroup()
				return g[method](g, ...)
			end
		end

		if #tabs == 1 then activate() end
		task.defer(refreshPageLayout)
		return tabObj
	end

	tween(MainScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	return Window
end

return Library
