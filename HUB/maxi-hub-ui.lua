--[[
  MAXI HUB UI Library (maxi-hub-ui.lua)
  ====================================

  Do not edit copies in per-game folders (maxi-hub-scr, maxi-hub-<game>, …).
  Copy this file from the canonical maxi-hub\ folder only.
  UI style changes — only in this canonical file.

  Tab and panel layout: maxi-hub\.cursor\rules\ui-layout.mdc

  Load:
    local MaxiHubUI = loadstring(readfile("maxi-hub-ui.lua"))()
    local Window = MaxiHubUI.CreateLib("MAXI HUB", { guiName = "UniqueName" })
    Window:Finalize()
]]

do
	local genv = typeof(getgenv) == "function" and getgenv() or _G
	if genv.MaxiHubSkipKey ~= true then
		local Auth = genv._MaxiHubAuthLib
		if not Auth then
			local src
			local paths = { "maxi-hub/maxi-hub-auth.lua", "maxi-hub-auth.lua" }
			if type(genv.MaxiHubLocalRoot) == "string" and genv.MaxiHubLocalRoot ~= "" then
				table.insert(paths, 1, genv.MaxiHubLocalRoot .. "/maxi-hub-auth.lua")
			end
			if typeof(readfile) == "function" and typeof(isfile) == "function" then
				for _, p in ipairs(paths) do
					if isfile(p) then
						src = readfile(p)
						break
					end
				end
			end
			if not src then
				local base = genv.MaxiHubOfficialRaw or genv.MaxiHubRemoteBase
				if base and typeof(game.HttpGet) == "function" then
					pcall(function()
						src = game:HttpGet(base .. "maxi-hub-auth.lua?v=" .. tostring(os.time()), true)
					end)
				end
			end
			if not src then
				if genv.MaxiHubRequireAuth == true then
					error("[MAXI HUB] Missing maxi-hub-auth.lua (ui)")
				end
				genv.MaxiHubSkipKey = true
			else
				local chunk, cerr = loadstring(src, "@maxi-hub-auth.lua")
				if not chunk then
					error("[MAXI HUB] auth compile: " .. tostring(cerr))
				end
				local okAuth, lib = pcall(chunk)
				if not okAuth then
					error("[MAXI HUB] auth: " .. tostring(lib))
				end
				Auth = lib
				genv._MaxiHubAuthLib = Auth
			end
		end
		if genv.MaxiHubSkipKey ~= true and Auth then
			Auth.guard("ui")
		end
	end
end

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local MaxiHubUI = {}
MaxiHubUI.VERSION = "1.0.0"

function MaxiHubUI.create(config)
	config = config or {}

	local player = config.player or Players.LocalPlayer
	local playerGui = config.playerGui or player:WaitForChild("PlayerGui")
	local genv = config.genv or (typeof(getgenv) == "function" and getgenv() or _G)

	local WINDOW_W = config.windowWidth or 580
	local WINDOW_H = config.windowHeight or 540
	local SIDEBAR_W = config.sidebarWidth or 150
	local DEFAULT_POS = config.defaultPosition or UDim2.new(0, 16, 0.5, -270)
	local savedPos = config.savedPosition
	local guiName = config.guiName or "MaxiHub"
	local titleText = config.title or "MAXI HUB"
	local titleHintText = config.titleHint or "RightCtrl — hide"
	local versionText = config.version or ""
	local tabs = config.tabs
	if tabs == nil then
		tabs = {
			{ name = "Home", title = "Home", subtitle = "" },
		}
	end
	local onSavePosition = config.onSavePosition
	local onDestroy = config.onDestroy
	local onCameraStart = config.onCameraStart
	local keyStatusText = config.keyStatusText
	local displayOrder = config.displayOrder or 999
	local onLanguageChange = config.onLanguageChange
	local currentLanguage = config.language or "en"
	if type(currentLanguage) == "string" then
		currentLanguage = currentLanguage:lower()
		if currentLanguage ~= "ru" and currentLanguage ~= "en" then
			currentLanguage = "en"
		end
	end
	local registerLocale = config.registerLocale
	local hideHintMessage = config.hideHintText or "RightCtrl — open menu"
	local onMobileMenuToggle = config.onMobileMenuToggle
	local activeTabId = 1

	local MOBILE_TAB_BAR_H = 48
	local MOBILE_DOCK_H = 48

	local function getViewportMetrics()
		local cam = workspace.CurrentCamera
		local vp = cam and cam.ViewportSize or Vector2.new(400, 800)
		local inset = GuiService:GetGuiInset()
		return vp, inset
	end

	local function isMobileDevice()
		local platform = UserInputService:GetPlatform()
		if platform == Enum.Platform.IOS or platform == Enum.Platform.Android then
			return true
		end
		local vp = select(1, getViewportMetrics())
		if vp.X <= 520 and UserInputService.TouchEnabled then
			return true
		end
		return false
	end

	local mobileMode = config.forceMobile == true or isMobileDevice()
	local mobileCompact = config.mobileCompact ~= false

	if mobileMode then
		local vp, inset = getViewportMetrics()
		local dockReserve = MOBILE_DOCK_H + 14 + inset.Y
		if type(config.windowWidth) == "number" and type(config.windowHeight) == "number" then
			WINDOW_W = math.floor(config.windowWidth)
			WINDOW_H = math.floor(config.windowHeight)
			DEFAULT_POS = UDim2.new(0.5, -math.floor(WINDOW_W / 2), 1, -(WINDOW_H + dockReserve))
		elseif mobileCompact then
			WINDOW_W = math.clamp(math.floor(vp.X * 0.94), 320, 420)
			WINDOW_H = math.clamp(math.floor(vp.Y * 0.58), 340, 480)
			DEFAULT_POS = UDim2.new(0.5, -math.floor(WINDOW_W / 2), 1, -(WINDOW_H + dockReserve))
		else
			local margin = 8
			WINDOW_W = math.max(280, math.floor(vp.X - margin * 2))
			WINDOW_H = math.max(
				320,
				math.floor(vp.Y - inset.Y - MOBILE_TAB_BAR_H - MOBILE_DOCK_H - margin * 2)
			)
			DEFAULT_POS = UDim2.new(0, margin, 0, inset.Y + margin)
		end
		SIDEBAR_W = 0
		savedPos = nil
		titleHintText = config.titleHintMobile or config.titleHint or "Menu — open"
		hideHintMessage = config.hideHintMobile or config.hideHintText or "Menu — open"
	elseif type(config.windowWidth) == "number" and type(config.windowHeight) == "number" then
		WINDOW_W = math.floor(config.windowWidth)
		WINDOW_H = math.floor(config.windowHeight)
	end

	local COLORS = config.colors or {
		bg = Color3.fromRGB(14, 16, 18),
		sidebar = Color3.fromRGB(20, 24, 26),
		panel = Color3.fromRGB(26, 30, 33),
		accent = Color3.fromRGB(0, 198, 178),
		accentSoft = Color3.fromRGB(0, 158, 142),
		tabIdle = Color3.fromRGB(24, 30, 32),
		text = Color3.fromRGB(242, 246, 248),
		muted = Color3.fromRGB(125, 135, 142),
		green = Color3.fromRGB(52, 199, 89),
		red = Color3.fromRGB(220, 75, 75),
		line = Color3.fromRGB(40, 48, 52),
		status = Color3.fromRGB(120, 235, 215),
		toggleOff = Color3.fromRGB(42, 48, 54),
		card = Color3.fromRGB(22, 26, 29),
	}

	local tabPageScrolls = {}
	local mobilePageScrollRefs = {}

	local function enhanceScrollFrame(scroll)
		scroll.ScrollingEnabled = true
		scroll.Active = true
		scroll.BorderSizePixel = 0
		scroll.BackgroundTransparency = 1
		scroll.ScrollBarImageColor3 = COLORS.accent
		scroll.ScrollBarThickness = mobileMode and 6 or 4
		scroll.ElasticBehavior = Enum.ElasticBehavior.Always
		scroll.ScrollingDirection = Enum.ScrollingDirection.Y
		scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	end

	local function isMobilePageHolder(frame)
		return frame and frame.Name == "MobilePageHolder"
	end

	local function bindMobilePageScroll(scroll, holder)
		if not scroll or not holder then
			return
		end
		local relayoutToken = 0
		local function relayout()
			relayoutToken += 1
			local token = relayoutToken
			task.defer(function()
				if token ~= relayoutToken or not scroll.Parent or not holder.Parent then
					return
				end
				local minH = math.max(scroll.AbsoluteSize.Y, 280)
				for _, ch in ipairs(holder:GetChildren()) do
					if ch:IsA("GuiObject") then
						local bottom = ch.Position.Y.Offset + ch.AbsoluteSize.Y
						if bottom > minH then
							minH = bottom
						end
					end
				end
				holder.Size = UDim2.new(1, 0, 0, minH + 16)
			end)
		end
		table.insert(mobilePageScrollRefs, { scroll = scroll, holder = holder, relayout = relayout })
		scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)
		holder.ChildAdded:Connect(function(ch)
			relayout()
			if ch:IsA("GuiObject") then
				ch:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)
				ch:GetPropertyChangedSignal("Position"):Connect(relayout)
				ch:GetPropertyChangedSignal("Size"):Connect(relayout)
			end
		end)
		for _, ch in ipairs(holder:GetChildren()) do
			if ch:IsA("GuiObject") then
				ch:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)
			end
		end
		relayout()
		task.delay(0.15, relayout)
		task.delay(0.5, relayout)
	end

	local function refreshMobilePageScrolls()
		for _, pair in ipairs(mobilePageScrollRefs) do
			if pair.relayout and pair.scroll.Parent and pair.holder.Parent then
				pair.relayout()
			end
		end
	end

	local contentPages = {}
	local tabButtons = {}
	local tabMeta = {}
	local pageTitle
	local pageSubtitle
	local screenGui
	local uiRoot
	local uiBody
	local titleBar
	local titleFix
	local title
	local titleHint
	local langRu
	local langEn
	local hideBtn
	local extraInputHandler

	local function addCorner(parent, r)
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, r or 8)
		c.Parent = parent
	end

	local function bindSliderTrack(track, setFromX)
		local active = false
		local moveConn
		local endConn

		local function stopDrag()
			active = false
			if moveConn then
				moveConn:Disconnect()
				moveConn = nil
			end
			if endConn then
				endConn:Disconnect()
				endConn = nil
			end
		end

		local function startDrag(input)
			if active then
				return
			end
			active = true
			setFromX(input.Position.X)
			moveConn = UserInputService.InputChanged:Connect(function(inp)
				if inp.UserInputType == Enum.UserInputType.MouseMovement
					or inp.UserInputType == Enum.UserInputType.Touch then
					setFromX(inp.Position.X)
				end
			end)
			endConn = UserInputService.InputEnded:Connect(function(inp)
				if inp.UserInputType == Enum.UserInputType.MouseButton1
					or inp.UserInputType == Enum.UserInputType.Touch then
					stopDrag()
				end
			end)
		end

		track.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				startDrag(input)
			end
		end)
	end

	local function calcContentWidth()
		if mobileMode then
			return WINDOW_W - 16
		end
		return WINDOW_W - 16 - (SIDEBAR_W + 10) - 2
	end

	local contentWidth = calcContentWidth()

	local function makeCollapsibleSection(parent, text, order, localeKey, startCollapsed)
		local section = Instance.new("Frame")
		section.Size = UDim2.new(1, 0, 0, 0)
		section.AutomaticSize = Enum.AutomaticSize.Y
		section.BackgroundTransparency = 1
		section.LayoutOrder = order
		section.Parent = parent

		local sectionLayout = Instance.new("UIListLayout")
		sectionLayout.Padding = UDim.new(0, 4)
		sectionLayout.SortOrder = Enum.SortOrder.LayoutOrder
		sectionLayout.Parent = section

		local header = Instance.new("TextButton")
		header.Size = UDim2.new(1, 0, 0, 28)
		header.BackgroundTransparency = 1
		header.BorderSizePixel = 0
		header.Text = ""
		header.AutoButtonColor = false
		header.LayoutOrder = 1
		header.Parent = section

		local arrow = Instance.new("TextLabel")
		arrow.Size = UDim2.new(0, 16, 1, 0)
		arrow.BackgroundTransparency = 1
		arrow.Font = Enum.Font.GothamBold
		arrow.TextSize = 10
		arrow.TextColor3 = COLORS.muted
		arrow.TextXAlignment = Enum.TextXAlignment.Left
		arrow.Text = "▼"
		arrow.Parent = header

		local titleLbl = Instance.new("TextLabel")
		titleLbl.Size = UDim2.new(1, -18, 1, 0)
		titleLbl.Position = UDim2.new(0, 16, 0, 0)
		titleLbl.BackgroundTransparency = 1
		titleLbl.Font = Enum.Font.GothamBold
		titleLbl.TextSize = 11
		titleLbl.TextColor3 = COLORS.muted
		titleLbl.TextXAlignment = Enum.TextXAlignment.Left
		titleLbl.Text = string.upper(text)
		titleLbl.Parent = header
		if registerLocale and type(localeKey) == "string" and localeKey ~= "" then
			registerLocale(titleLbl, localeKey)
		end

		local body = Instance.new("Frame")
		body.Size = UDim2.new(1, 0, 0, 0)
		body.AutomaticSize = Enum.AutomaticSize.Y
		body.BackgroundTransparency = 1
		body.LayoutOrder = 2
		body.Parent = section

		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 6)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = body

		local collapsed = startCollapsed == true
		local function paint()
			arrow.Text = collapsed and "▶" or "▼"
			body.Visible = not collapsed
		end

		header.MouseButton1Click:Connect(function()
			collapsed = not collapsed
			paint()
		end)
		paint()
		return body
	end

	local function makeDraggable(frame, handle)
		local dragging = false
		local dragStart
		local startPos

		handle.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			dragging = true
			dragStart = input.Position
			startPos = frame.Position
		end)

		local moveConn = UserInputService.InputChanged:Connect(function(input)
			if not dragging then return end
			if input.UserInputType ~= Enum.UserInputType.MouseMovement
				and input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			local d = input.Position - dragStart
			frame.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + d.X,
				startPos.Y.Scale, startPos.Y.Offset + d.Y
			)
		end)

		local endConn = UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
				if typeof(onSavePosition) == "function" then
					onSavePosition()
				end
			end
		end)

		frame.Destroying:Connect(function()
			moveConn:Disconnect()
			endConn:Disconnect()
		end)
	end

	local function makeResizable(frame, minW, minH, maxW, maxH, onResizeEnd)
		local grip = Instance.new("TextButton")
		grip.Name = "ResizeGrip"
		grip.Size = UDim2.new(0, 18, 0, 18)
		grip.Position = UDim2.new(1, -16, 1, -16)
		grip.BackgroundColor3 = COLORS.panel
		grip.BorderSizePixel = 0
		grip.Text = ""
		grip.AutoButtonColor = false
		grip.ZIndex = 30
		grip.Parent = frame
		addCorner(grip, 5)

		local gripIcon = Instance.new("TextLabel")
		gripIcon.Size = UDim2.new(1, 0, 1, 0)
		gripIcon.BackgroundTransparency = 1
		gripIcon.Font = Enum.Font.GothamBold
		gripIcon.TextSize = 11
		gripIcon.TextColor3 = COLORS.muted
		gripIcon.Text = "⋱"
		gripIcon.ZIndex = 31
		gripIcon.Parent = grip

		local resizing = false
		local dragStart
		local startSize

		local function stopResize(input)
			if not resizing then
				return
			end
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				resizing = false
				if typeof(onResizeEnd) == "function" then
					onResizeEnd()
				end
			end
		end

		grip.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			resizing = true
			dragStart = input.Position
			startSize = frame.Size
		end)

		local moveConn = UserInputService.InputChanged:Connect(function(input)
			if not resizing then
				return
			end
			if input.UserInputType ~= Enum.UserInputType.MouseMovement
				and input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			local dx = input.Position.X - dragStart.X
			local dy = input.Position.Y - dragStart.Y
			local newW = math.clamp(startSize.X.Offset + dx, minW, maxW)
			local newH = math.clamp(startSize.Y.Offset + dy, minH, maxH)
			frame.Size = UDim2.new(0, newW, 0, newH)
		end)

		local endConn = UserInputService.InputEnded:Connect(stopResize)

		frame.Destroying:Connect(function()
			moveConn:Disconnect()
			endConn:Disconnect()
		end)

		return grip
	end

	local function switchTab(id)
		activeTabId = id
		for i, page in ipairs(contentPages) do
			local visible = i == id
			if mobileMode and tabPageScrolls[i] then
				tabPageScrolls[i].Visible = visible
			else
				page.Visible = visible
			end
			tabButtons[i].BackgroundColor3 = visible and COLORS.accent or COLORS.tabIdle
			tabButtons[i].TextColor3 = visible and COLORS.bg or COLORS.muted
		end
		local meta = tabMeta[id]
		if pageTitle then
			if registerLocale and meta and type(meta.titleKey) == "string" then
				registerLocale(pageTitle, meta.titleKey)
			else
				pageTitle.Text = meta and meta.title or titleText
			end
		end
		if pageSubtitle then
			if registerLocale and meta and type(meta.subtitleKey) == "string" then
				registerLocale(pageSubtitle, meta.subtitleKey)
			else
				pageSubtitle.Text = meta and meta.subtitle or ""
			end
		end
	end

	local function makeSectionTitle(parent, text, order, localeKey)
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 20)
		row.BackgroundTransparency = 1
		row.LayoutOrder = order
		row.ClipsDescendants = true
		row.Parent = parent

		local bar = Instance.new("Frame")
		bar.Size = UDim2.new(0, 3, 0, 12)
		bar.Position = UDim2.new(0, 0, 0.5, -6)
		bar.BackgroundColor3 = COLORS.accent
		bar.BorderSizePixel = 0
		bar.Parent = row
		addCorner(bar, 2)

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, -10, 1, 0)
		lbl.Position = UDim2.new(0, 10, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.GothamBold
		lbl.TextSize = 11
		lbl.TextColor3 = COLORS.muted
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Text = string.upper(text)
		lbl.Parent = row
		if registerLocale and type(localeKey) == "string" and localeKey ~= "" then
			registerLocale(lbl, localeKey, nil, true)
		end
		return lbl
	end

	local function makeToggle(parent, y, label, initial, onChange, debounce, localeKey)
		local row = Instance.new("TextButton")
		row.Size = UDim2.new(1, 0, 0, 38)
		row.Position = UDim2.new(0, 0, 0, y)
		row.BackgroundColor3 = COLORS.panel
		row.BorderSizePixel = 0
		row.Text = ""
		row.AutoButtonColor = false
		row.ClipsDescendants = true
		row.Parent = parent
		addCorner(row, 8)

		local name = Instance.new("TextLabel")
		name.Size = UDim2.new(1, -56, 1, 0)
		name.Position = UDim2.new(0, 12, 0, 0)
		name.BackgroundTransparency = 1
		name.Font = Enum.Font.Gotham
		name.TextSize = 13
		name.TextColor3 = COLORS.text
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Text = label
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.Parent = row
		if registerLocale and type(localeKey) == "string" and localeKey ~= "" then
			registerLocale(name, localeKey)
		end

		local track = Instance.new("Frame")
		track.Size = UDim2.new(0, 40, 0, 20)
		track.Position = UDim2.new(1, -48, 0.5, -10)
		track.BackgroundColor3 = initial and COLORS.accent or COLORS.toggleOff
		track.BorderSizePixel = 0
		track.Parent = row
		addCorner(track, 10)

		local knob = Instance.new("Frame")
		knob.Size = UDim2.new(0, 16, 0, 16)
		knob.Position = initial and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
		knob.BackgroundColor3 = COLORS.text
		knob.BorderSizePixel = 0
		knob.Parent = track
		addCorner(knob, 8)

		local state = initial
		local lastClick = 0

		local function paint()
			track.BackgroundColor3 = state and COLORS.accent or COLORS.toggleOff
			TweenService:Create(knob, TweenInfo.new(0.12), {
				Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8),
			}):Play()
		end

		local function setState(value, silent)
			state = value
			paint()
			if not silent and onChange then
				onChange(state)
			end
		end

		row.MouseButton1Click:Connect(function()
			if debounce and tick() - lastClick < debounce then return end
			lastClick = tick()
			setState(not state)
		end)

		paint()
		return setState, function() return state end
	end

	local function makeSlider(parent, y, label, min, max, initial, onChange, localeKey)
		local box = Instance.new("Frame")
		box.Size = UDim2.new(1, 0, 0, 52)
		box.Position = UDim2.new(0, 0, 0, y)
		box.BackgroundColor3 = COLORS.panel
		box.BorderSizePixel = 0
		box.ClipsDescendants = true
		box.Parent = parent
		addCorner(box, 8)

		local name = Instance.new("TextLabel")
		name.Size = UDim2.new(0.65, 0, 0, 20)
		name.Position = UDim2.new(0, 12, 0, 6)
		name.BackgroundTransparency = 1
		name.Font = Enum.Font.Gotham
		name.TextSize = 12
		name.TextColor3 = COLORS.text
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Text = label
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.Parent = box
		if registerLocale and type(localeKey) == "string" and localeKey ~= "" then
			registerLocale(name, localeKey)
		end

		local valueLbl = Instance.new("TextLabel")
		valueLbl.Size = UDim2.new(0.35, -12, 0, 20)
		valueLbl.Position = UDim2.new(0.65, 0, 0, 6)
		valueLbl.BackgroundTransparency = 1
		valueLbl.Font = Enum.Font.GothamBold
		valueLbl.TextSize = 12
		valueLbl.TextColor3 = COLORS.accent
		valueLbl.TextXAlignment = Enum.TextXAlignment.Right
		valueLbl.Parent = box

		local track = Instance.new("TextButton")
		track.Size = UDim2.new(1, -24, 0, 8)
		track.Position = UDim2.new(0, 12, 1, -18)
		track.BackgroundColor3 = COLORS.line
		track.BorderSizePixel = 0
		track.Text = ""
		track.AutoButtonColor = false
		track.Parent = box
		addCorner(track, 4)

		local fill = Instance.new("Frame")
		fill.Size = UDim2.new(0, 0, 1, 0)
		fill.BackgroundColor3 = COLORS.accent
		fill.BorderSizePixel = 0
		fill.Parent = track
		addCorner(fill, 4)

		local val = initial
		local function paint()
			local alpha = (val - min) / math.max(max - min, 0.001)
			alpha = math.clamp(alpha, 0, 1)
			fill.Size = UDim2.new(alpha, 0, 1, 0)
			local decimals = (max - min) <= 3 and 1 or 0
			valueLbl.Text = decimals == 0 and tostring(math.floor(val)) or string.format("%.1f", val)
		end

		local function setFromX(x)
			local rel = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
			val = min + (max - min) * rel
			val = math.floor(val * 10 + 0.5) / 10
			paint()
			onChange(val)
		end

		bindSliderTrack(track, setFromX)

		paint()
		return function(v) val = v; paint() end
	end

	local function makeFlowSlider(parent, label, min, max, initial, onChange, layoutOrder, localeKey)
		local box = Instance.new("Frame")
		box.Size = UDim2.new(1, 0, 0, 52)
		box.BackgroundColor3 = COLORS.panel
		box.BorderSizePixel = 0
		box.LayoutOrder = layoutOrder or 0
		box.ClipsDescendants = true
		box.Parent = parent
		addCorner(box, 8)

		local name = Instance.new("TextLabel")
		name.Size = UDim2.new(0.65, 0, 0, 20)
		name.Position = UDim2.new(0, 12, 0, 6)
		name.BackgroundTransparency = 1
		name.Font = Enum.Font.Gotham
		name.TextSize = 12
		name.TextColor3 = COLORS.text
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Text = label
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.Parent = box
		if registerLocale and type(localeKey) == "string" and localeKey ~= "" then
			registerLocale(name, localeKey)
		end

		local valueLbl = Instance.new("TextLabel")
		valueLbl.Size = UDim2.new(0.35, -12, 0, 20)
		valueLbl.Position = UDim2.new(0.65, 0, 0, 6)
		valueLbl.BackgroundTransparency = 1
		valueLbl.Font = Enum.Font.GothamBold
		valueLbl.TextSize = 12
		valueLbl.TextColor3 = COLORS.accent
		valueLbl.TextXAlignment = Enum.TextXAlignment.Right
		valueLbl.Parent = box

		local track = Instance.new("TextButton")
		track.Size = UDim2.new(1, -24, 0, 8)
		track.Position = UDim2.new(0, 12, 1, -18)
		track.BackgroundColor3 = COLORS.line
		track.BorderSizePixel = 0
		track.Text = ""
		track.AutoButtonColor = false
		track.Parent = box
		addCorner(track, 4)

		local fill = Instance.new("Frame")
		fill.Size = UDim2.new(0, 0, 1, 0)
		fill.BackgroundColor3 = COLORS.accent
		fill.BorderSizePixel = 0
		fill.Parent = track
		addCorner(fill, 4)

		local val = initial
		local function paint()
			local alpha = (val - min) / math.max(max - min, 0.001)
			alpha = math.clamp(alpha, 0, 1)
			fill.Size = UDim2.new(alpha, 0, 1, 0)
			local decimals = (max - min) <= 3 and 1 or 0
			valueLbl.Text = decimals == 0 and tostring(math.floor(val)) or string.format("%.1f", val)
		end

		local function setFromX(x)
			local rel = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
			val = min + (max - min) * rel
			val = math.floor(val * 10 + 0.5) / 10
			paint()
			onChange(val)
		end

		bindSliderTrack(track, setFromX)

		paint()
		return function(v) val = v; paint() end
	end

	local function makeScrollPage(parent)
		if mobileMode and isMobilePageHolder(parent) then
			local stack = Instance.new("Frame")
			stack.Name = "MobileScrollStack"
			stack.Size = UDim2.new(1, 0, 0, 0)
			stack.AutomaticSize = Enum.AutomaticSize.Y
			stack.BackgroundTransparency = 1
			stack.Parent = parent

			local layout = Instance.new("UIListLayout")
			layout.SortOrder = Enum.SortOrder.LayoutOrder
			layout.Padding = UDim.new(0, 8)
			layout.Parent = stack

			local pad = Instance.new("UIPadding")
			pad.PaddingTop = UDim.new(0, 4)
			pad.PaddingBottom = UDim.new(0, 12)
			pad.PaddingLeft = UDim.new(0, 2)
			pad.PaddingRight = UDim.new(0, 6)
			pad.Parent = stack

			local pageScroll = parent.Parent
			if pageScroll and pageScroll:IsA("ScrollingFrame") then
				bindMobilePageScroll(pageScroll, parent)
			end
			return stack
		end

		local scroll = Instance.new("ScrollingFrame")
		scroll.Size = UDim2.new(1, 0, 1, 0)
		scroll.BackgroundTransparency = 1
		scroll.BorderSizePixel = 0
		scroll.ScrollBarThickness = 4
		scroll.ScrollBarImageColor3 = COLORS.accent
		scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		enhanceScrollFrame(scroll)
		scroll.Parent = parent

		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, 8)
		layout.Parent = scroll

		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 4)
		pad.PaddingBottom = UDim.new(0, 12)
		pad.PaddingLeft = UDim.new(0, 2)
		pad.PaddingRight = UDim.new(0, 6)
		pad.Parent = scroll

		return scroll
	end

	local function makeListWrap(scroll)
		local wrap = Instance.new("Frame")
		wrap.Size = UDim2.new(1, 0, 0, 0)
		wrap.AutomaticSize = Enum.AutomaticSize.Y
		wrap.BackgroundTransparency = 1
		wrap.LayoutOrder = 1
		wrap.Parent = scroll
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 6)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = wrap
		return wrap
	end

	local function makeFlowPanel(parent, title, width, height, posX, posY, bodyOffsetY, localeKey)
		local panel = Instance.new("Frame")
		panel.Size = UDim2.new(0, width, 0, height)
		panel.Position = UDim2.new(0, posX or 0, 0, posY or 0)
		panel.BackgroundColor3 = COLORS.card
		panel.BorderSizePixel = 0
		panel.ClipsDescendants = true
		panel.Parent = parent
		addCorner(panel, 10)

		local stroke = Instance.new("UIStroke")
		stroke.Color = COLORS.line
		stroke.Thickness = 1
		stroke.Transparency = 0.35
		stroke.Parent = panel

		local head = Instance.new("TextLabel")
		head.Size = UDim2.new(1, -20, 0, 22)
		head.Position = UDim2.new(0, 10, 0, 10)
		head.BackgroundTransparency = 1
		head.Font = Enum.Font.GothamBold
		head.TextSize = 12
		head.TextColor3 = COLORS.text
		head.TextXAlignment = Enum.TextXAlignment.Left
		head.Text = title
		head.Parent = panel
		if registerLocale and type(localeKey) == "string" and localeKey ~= "" then
			registerLocale(head, localeKey)
		end

		local bodyY = bodyOffsetY or 36
		local body = Instance.new("Frame")
		body.Size = UDim2.new(1, -16, 1, -bodyY - 8)
		body.Position = UDim2.new(0, 8, 0, bodyY)
		body.BackgroundTransparency = 1
		body.Parent = panel

		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 6)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = body

		return body
	end

	local function makeStatRow(parent, label, layoutOrder, localeKey)
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 22)
		row.BackgroundTransparency = 1
		row.LayoutOrder = layoutOrder or 0
		row.ClipsDescendants = true
		row.Parent = parent

		local name = Instance.new("TextLabel")
		name.Size = UDim2.new(0.55, 0, 1, 0)
		name.BackgroundTransparency = 1
		name.Font = Enum.Font.Gotham
		name.TextSize = 11
		name.TextColor3 = COLORS.muted
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Text = label
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.Parent = row
		if registerLocale and type(localeKey) == "string" and localeKey ~= "" then
			registerLocale(name, localeKey)
		end

		local value = Instance.new("TextLabel")
		value.Size = UDim2.new(0.45, -4, 1, 0)
		value.Position = UDim2.new(0.55, 0, 0, 0)
		value.BackgroundTransparency = 1
		value.Font = Enum.Font.GothamBold
		value.TextSize = 11
		value.TextColor3 = COLORS.text
		value.TextXAlignment = Enum.TextXAlignment.Right
		value.Text = "—"
		value.Parent = row

		return value
	end

	local function resolveToggleLocale(debounceOrKey, localeKeyOrNil)
		local debounce = nil
		local localeKey = nil
		if type(debounceOrKey) == "string" then
			localeKey = debounceOrKey
			if type(localeKeyOrNil) == "number" then
				debounce = localeKeyOrNil
			end
		elseif type(debounceOrKey) == "number" then
			debounce = debounceOrKey
			if type(localeKeyOrNil) == "string" then
				localeKey = localeKeyOrNil
			end
		elseif debounceOrKey == nil and type(localeKeyOrNil) == "string" then
			localeKey = localeKeyOrNil
		end
		return debounce, localeKey
	end

	local function makeFlowToggle(parent, label, initial, onChange, layoutOrder, debounceOrKey, localeKeyOrNil)
		local debounce, localeKey = resolveToggleLocale(debounceOrKey, localeKeyOrNil)
		local cardStyle = parent:GetAttribute("MaxiHubCardToggles") == true
		local row = Instance.new("TextButton")
		row.Size = UDim2.new(1, 0, 0, cardStyle and 38 or 34)
		row.BackgroundTransparency = cardStyle and 0 or 1
		row.BackgroundColor3 = cardStyle and COLORS.panel or COLORS.bg
		row.BorderSizePixel = 0
		row.Text = ""
		row.AutoButtonColor = false
		row.LayoutOrder = layoutOrder or 0
		row.ClipsDescendants = true
		row.Parent = parent
		if cardStyle then
			addCorner(row, 8)
		end

		local name = Instance.new("TextLabel")
		name.Size = UDim2.new(1, -54, 1, 0)
		name.Position = UDim2.new(0, cardStyle and 12 or 4, 0, 0)
		name.BackgroundTransparency = 1
		name.Font = Enum.Font.Gotham
		name.TextSize = 12
		name.TextColor3 = COLORS.text
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Text = label
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.Parent = row
		if registerLocale and type(localeKey) == "string" and localeKey ~= "" then
			registerLocale(name, localeKey)
		end

		local track = Instance.new("Frame")
		track.Size = UDim2.new(0, 44, 0, 22)
		track.Position = UDim2.new(1, -48, 0.5, -11)
		track.BackgroundColor3 = initial and COLORS.accent or COLORS.toggleOff
		track.BorderSizePixel = 0
		track.Parent = row
		addCorner(track, 11)

		local knob = Instance.new("Frame")
		knob.Size = UDim2.new(0, 18, 0, 18)
		knob.Position = initial and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
		knob.BackgroundColor3 = COLORS.text
		knob.BorderSizePixel = 0
		knob.Parent = track
		addCorner(knob, 9)

		local state = initial
		local lastClick = 0

		local function paint()
			track.BackgroundColor3 = state and COLORS.accent or COLORS.toggleOff
			TweenService:Create(knob, TweenInfo.new(0.12), {
				Position = state and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9),
			}):Play()
		end

		local function setState(value, silent)
			state = value
			paint()
			if not silent and onChange then
				onChange(state)
			end
		end

		row.MouseButton1Click:Connect(function()
			if debounce and tick() - lastClick < debounce then return end
			lastClick = tick()
			setState(not state)
		end)

		paint()
		return setState, function() return state end
	end

	-- ===== SHELL (window + sidebar + tabs) =====
	genv._MaxiHubGuiRegistry = genv._MaxiHubGuiRegistry or {}
	genv._MaxiHubInputConn = genv._MaxiHubInputConn or {}

	local prevGui = genv._MaxiHubGuiRegistry[guiName]
	if prevGui then
		pcall(function()
			if typeof(prevGui) == "Instance" and prevGui.Parent then
				prevGui:Destroy()
			end
		end)
		genv._MaxiHubGuiRegistry[guiName] = nil
	end

	local prevInput = genv._MaxiHubInputConn[guiName]
	if prevInput then
		pcall(function() prevInput:Disconnect() end)
		genv._MaxiHubInputConn[guiName] = nil
	end

	local oldGui = playerGui:FindFirstChild(guiName)
	if oldGui then oldGui:Destroy() end

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = guiName
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder = displayOrder
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = playerGui
	genv._MaxiHubGuiRegistry[guiName] = screenGui

	if typeof(onCameraStart) == "function" then
		pcall(onCameraStart)
	end

	screenGui.Destroying:Connect(function()
		genv._MaxiHubGuiRegistry[guiName] = nil
		local conn = genv._MaxiHubInputConn[guiName]
		if conn then
			pcall(function() conn:Disconnect() end)
			genv._MaxiHubInputConn[guiName] = nil
		end
		if typeof(onDestroy) == "function" then
			pcall(onDestroy)
		end
	end)

	uiRoot = Instance.new("Frame")
	uiRoot.Size = UDim2.new(0, WINDOW_W, 0, WINDOW_H)
	uiRoot.BackgroundColor3 = COLORS.bg
	uiRoot.BorderSizePixel = 0
	uiRoot.Active = true
	uiRoot.ZIndex = 5
	uiRoot.Parent = screenGui
	uiRoot.Position = savedPos or DEFAULT_POS
	uiRoot.ClipsDescendants = true
	addCorner(uiRoot, 12)

	local rootStroke = Instance.new("UIStroke")
	rootStroke.Color = COLORS.accent
	rootStroke.Thickness = 1.5
	rootStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rootStroke.Parent = uiRoot

	titleBar = Instance.new("Frame")
	titleBar.Size = UDim2.new(1, 0, 0, 42)
	titleBar.BackgroundColor3 = COLORS.panel
	titleBar.BorderSizePixel = 0
	titleBar.Active = true
	titleBar.Parent = uiRoot
	addCorner(titleBar, 12)

	titleFix = Instance.new("Frame")
	titleFix.Size = UDim2.new(1, 0, 0, 10)
	titleFix.Position = UDim2.new(0, 0, 1, -10)
	titleFix.BackgroundColor3 = COLORS.panel
	titleFix.BorderSizePixel = 0
	titleFix.Parent = titleBar

	title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -140, 0, 22)
	title.Position = UDim2.new(0, 14, 0, 6)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 15
	title.TextColor3 = COLORS.text
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = titleText
	title.Parent = titleBar

	titleHint = Instance.new("TextLabel")
	titleHint.Size = UDim2.new(1, -140, 0, 12)
	titleHint.Position = UDim2.new(0, 14, 1, -14)
	titleHint.BackgroundTransparency = 1
	titleHint.Font = Enum.Font.Gotham
	titleHint.TextSize = 9
	titleHint.TextColor3 = COLORS.muted
	titleHint.TextXAlignment = Enum.TextXAlignment.Left
	titleHint.Text = titleHintText
	titleHint.Parent = titleBar

	local function paintLanguageButtons()
		if not langRu or not langEn then
			return
		end
		if currentLanguage == "ru" then
			langRu.BackgroundColor3 = COLORS.accent
			langRu.TextColor3 = COLORS.bg
			langEn.BackgroundColor3 = COLORS.tabIdle
			langEn.TextColor3 = COLORS.text
		else
			langEn.BackgroundColor3 = COLORS.accent
			langEn.TextColor3 = COLORS.bg
			langRu.BackgroundColor3 = COLORS.tabIdle
			langRu.TextColor3 = COLORS.text
		end
	end

	langRu = Instance.new("TextButton")
	langRu.Size = UDim2.new(0, 28, 0, 28)
	langRu.Position = UDim2.new(1, -104, 0.5, -14)
	langRu.BackgroundColor3 = COLORS.tabIdle
	langRu.BorderSizePixel = 0
	langRu.Font = Enum.Font.GothamBold
	langRu.TextSize = 14
	langRu.TextColor3 = COLORS.text
	langRu.Text = "🇷🇺"
	langRu.AutoButtonColor = false
	langRu.Parent = titleBar
	addCorner(langRu, 6)

	langEn = Instance.new("TextButton")
	langEn.Size = UDim2.new(0, 28, 0, 28)
	langEn.Position = UDim2.new(1, -72, 0.5, -14)
	langEn.BackgroundColor3 = COLORS.tabIdle
	langEn.BorderSizePixel = 0
	langEn.Font = Enum.Font.GothamBold
	langEn.TextSize = 14
	langEn.TextColor3 = COLORS.text
	langEn.Text = "🇬🇧"
	langEn.AutoButtonColor = false
	langEn.Parent = titleBar
	addCorner(langEn, 6)

	paintLanguageButtons()

	langRu.MouseButton1Click:Connect(function()
		if currentLanguage == "ru" then
			return
		end
		currentLanguage = "ru"
		paintLanguageButtons()
		if typeof(onLanguageChange) == "function" then
			onLanguageChange("ru")
		end
	end)

	langEn.MouseButton1Click:Connect(function()
		if currentLanguage == "en" then
			return
		end
		currentLanguage = "en"
		paintLanguageButtons()
		if typeof(onLanguageChange) == "function" then
			onLanguageChange("en")
		end
	end)

	hideBtn = Instance.new("TextButton")
	hideBtn.Size = UDim2.new(0, 28, 0, 28)
	hideBtn.Position = UDim2.new(1, -36, 0.5, -14)
	hideBtn.BackgroundColor3 = COLORS.tabIdle
	hideBtn.BorderSizePixel = 0
	hideBtn.Font = Enum.Font.GothamBold
	hideBtn.TextSize = 16
	hideBtn.TextColor3 = COLORS.text
	hideBtn.Text = "—"
	hideBtn.AutoButtonColor = false
	hideBtn.Parent = titleBar
	addCorner(hideBtn, 6)

	uiBody = Instance.new("Frame")
	uiBody.Size = UDim2.new(1, -16, 1, -50)
	uiBody.Position = UDim2.new(0, 8, 0, 46)
	uiBody.BackgroundTransparency = 1
	uiBody.Parent = uiRoot

	local sidebar
	local sideTop
	local mobileTabBar
	local contentHost

	if mobileMode then
		contentHost = Instance.new("Frame")
		contentHost.Size = UDim2.new(1, -8, 1, -(MOBILE_TAB_BAR_H + 4))
		contentHost.Position = UDim2.new(0, 4, 0, 0)
		contentHost.BackgroundTransparency = 1
		contentHost.ClipsDescendants = true
		contentHost.Parent = uiBody

		mobileTabBar = Instance.new("Frame")
		mobileTabBar.Name = "MobileTabBar"
		mobileTabBar.Size = UDim2.new(1, -8, 0, MOBILE_TAB_BAR_H)
		mobileTabBar.Position = UDim2.new(0, 4, 1, -MOBILE_TAB_BAR_H)
		mobileTabBar.BackgroundColor3 = COLORS.sidebar
		mobileTabBar.BorderSizePixel = 0
		mobileTabBar.Parent = uiBody
		addCorner(mobileTabBar, 10)

		sideTop = Instance.new("ScrollingFrame")
		sideTop.Size = UDim2.new(1, -8, 1, -8)
		sideTop.Position = UDim2.new(0, 4, 0, 4)
		sideTop.BackgroundTransparency = 1
		sideTop.BorderSizePixel = 0
		sideTop.ScrollBarThickness = 2
		sideTop.ScrollBarImageColor3 = COLORS.accent
		sideTop.ScrollingDirection = Enum.ScrollingDirection.X
		sideTop.CanvasSize = UDim2.new(0, 0, 0, 0)
		sideTop.AutomaticCanvasSize = Enum.AutomaticSize.X
		sideTop.Parent = mobileTabBar

		local mobileTabLayout = Instance.new("UIListLayout")
		mobileTabLayout.FillDirection = Enum.FillDirection.Horizontal
		mobileTabLayout.Padding = UDim.new(0, 6)
		mobileTabLayout.SortOrder = Enum.SortOrder.LayoutOrder
		mobileTabLayout.Parent = sideTop

		local mobileTabPad = Instance.new("UIPadding")
		mobileTabPad.PaddingLeft = UDim.new(0, 4)
		mobileTabPad.PaddingRight = UDim.new(0, 4)
		mobileTabPad.Parent = sideTop

		sidebar = Instance.new("Frame")
		sidebar.Visible = false
		sidebar.Parent = uiBody
	else
		sidebar = Instance.new("Frame")
		sidebar.Size = UDim2.new(0, SIDEBAR_W, 1, 0)
		sidebar.BackgroundColor3 = COLORS.sidebar
		sidebar.BorderSizePixel = 0
		sidebar.Parent = uiBody
		addCorner(sidebar, 10)

		sideTop = Instance.new("ScrollingFrame")
		sideTop.Size = UDim2.new(1, 0, 1, -110)
		sideTop.Position = UDim2.new(0, 0, 0, 0)
		sideTop.BackgroundTransparency = 1
		sideTop.BorderSizePixel = 0
		sideTop.ScrollBarThickness = 3
		sideTop.ScrollBarImageColor3 = COLORS.accent
		sideTop.ScrollingDirection = Enum.ScrollingDirection.Y
		sideTop.CanvasSize = UDim2.new(0, 0, 0, 0)
		sideTop.AutomaticCanvasSize = Enum.AutomaticSize.Y
		sideTop.Parent = sidebar

		local sideLayout = Instance.new("UIListLayout")
		sideLayout.Padding = UDim.new(0, 6)
		sideLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		sideLayout.SortOrder = Enum.SortOrder.LayoutOrder
		sideLayout.Parent = sideTop

		local sidePad = Instance.new("UIPadding")
		sidePad.PaddingTop = UDim.new(0, 8)
		sidePad.PaddingBottom = UDim.new(0, 8)
		sidePad.PaddingLeft = UDim.new(0, 0)
		sidePad.PaddingRight = UDim.new(0, 4)
		sidePad.Parent = sideTop
	end

	local userCard
	local userAvatar
	local userName
	local userKeyCaption
	local userKey
	local userVersion

	if mobileMode then
		userCard = Instance.new("Frame")
		userCard.Visible = false
		userCard.Parent = uiBody
		userAvatar = Instance.new("ImageLabel")
		userAvatar.Visible = false
		userAvatar.Parent = userCard
		userName = Instance.new("TextLabel")
		userName.Visible = false
		userName.Parent = userCard
		userKeyCaption = Instance.new("TextLabel")
		userKeyCaption.Visible = false
		userKeyCaption.Parent = userCard
		userKey = Instance.new("TextLabel")
		userKey.Visible = false
		userKey.Parent = userCard
		userVersion = Instance.new("TextLabel")
		userVersion.Visible = false
		userVersion.Parent = userCard
	else
		userCard = Instance.new("Frame")
		userCard.Size = UDim2.new(1, -12, 0, 104)
		userCard.Position = UDim2.new(0, 6, 1, -110)
		userCard.BackgroundColor3 = COLORS.card
		userCard.BorderSizePixel = 0
		userCard.Parent = sidebar
		addCorner(userCard, 10)

		local userStroke = Instance.new("UIStroke")
		userStroke.Color = COLORS.line
		userStroke.Thickness = 1
		userStroke.Transparency = 0.4
		userStroke.Parent = userCard

		userAvatar = Instance.new("ImageLabel")
		userAvatar.Size = UDim2.new(0, 36, 0, 36)
		userAvatar.Position = UDim2.new(0, 8, 0.5, -18)
		userAvatar.BackgroundColor3 = COLORS.panel
		userAvatar.BorderSizePixel = 0
		userAvatar.Parent = userCard
		addCorner(userAvatar, 18)

		userName = Instance.new("TextLabel")
		userName.Size = UDim2.new(1, -54, 0, 16)
		userName.Position = UDim2.new(0, 50, 0, 10)
		userName.BackgroundTransparency = 1
		userName.Font = Enum.Font.GothamBold
		userName.TextSize = 11
		userName.TextColor3 = COLORS.text
		userName.TextXAlignment = Enum.TextXAlignment.Left
		userName.TextTruncate = Enum.TextTruncate.AtEnd
		userName.Text = player.DisplayName
		userName.Parent = userCard

		userKeyCaption = Instance.new("TextLabel")
		userKeyCaption.Size = UDim2.new(1, -54, 0, 12)
		userKeyCaption.Position = UDim2.new(0, 50, 0, 28)
		userKeyCaption.BackgroundTransparency = 1
		userKeyCaption.Font = Enum.Font.Gotham
		userKeyCaption.TextSize = 8
		userKeyCaption.TextColor3 = COLORS.muted
		userKeyCaption.TextXAlignment = Enum.TextXAlignment.Left
		userKeyCaption.Text = ""
		userKeyCaption.Parent = userCard
		if registerLocale then
			registerLocale(userKeyCaption, "key_activation_label")
		end

		userKey = Instance.new("TextLabel")
		userKey.Size = UDim2.new(1, -54, 0, 22)
		userKey.Position = UDim2.new(0, 50, 0, 42)
		userKey.BackgroundTransparency = 1
		userKey.Font = Enum.Font.Gotham
		userKey.TextSize = 9
		userKey.TextColor3 = COLORS.muted
		userKey.TextXAlignment = Enum.TextXAlignment.Left
		userKey.TextYAlignment = Enum.TextYAlignment.Top
		userKey.TextWrapped = true
		userKey.Parent = userCard

		userVersion = Instance.new("TextLabel")
		userVersion.Size = UDim2.new(1, -54, 0, 14)
		userVersion.Position = UDim2.new(0, 50, 1, -18)
		userVersion.BackgroundTransparency = 1
		userVersion.Font = Enum.Font.GothamBold
		userVersion.TextSize = 9
		userVersion.TextColor3 = COLORS.accent
		userVersion.TextXAlignment = Enum.TextXAlignment.Left
		userVersion.TextYAlignment = Enum.TextYAlignment.Bottom
		userVersion.Text = versionText
		userVersion.Visible = versionText ~= ""
		userVersion.Parent = userCard
	end

	local function refreshKeyStatus()
		if typeof(keyStatusText) == "function" then
			userKey.Text = keyStatusText() or ""
		end
	end
	if typeof(keyStatusText) == "function" then
		refreshKeyStatus()
	elseif not mobileMode then
		userKey.Visible = false
		userKeyCaption.Visible = false
		userName.Position = UDim2.new(0, 50, 0, 16)
	end

	task.spawn(function()
		local ok, thumb = pcall(function()
			return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
		end)
		if ok and thumb and userAvatar then
			userAvatar.Image = thumb
		end
		refreshKeyStatus()
	end)

	if not mobileMode then
		local contentOffset = SIDEBAR_W + 10
		contentHost = Instance.new("Frame")
		contentHost.Size = UDim2.new(1, -(contentOffset + 2), 1, 0)
		contentHost.Position = UDim2.new(0, contentOffset, 0, 0)
		contentHost.BackgroundTransparency = 1
		contentHost.ClipsDescendants = true
		contentHost.Parent = uiBody
	end

	contentWidth = calcContentWidth()

	local contentHeader = Instance.new("Frame")
	contentHeader.Size = UDim2.new(1, 0, 0, 48)
	contentHeader.BackgroundTransparency = 1
	contentHeader.Parent = contentHost

	pageTitle = Instance.new("TextLabel")
	pageTitle.Size = UDim2.new(1, -8, 0, 22)
	pageTitle.BackgroundTransparency = 1
	pageTitle.Font = Enum.Font.GothamBold
	pageTitle.TextSize = 16
	pageTitle.TextColor3 = COLORS.text
	pageTitle.TextXAlignment = Enum.TextXAlignment.Left
	pageTitle.Text = tabs[1] and tabs[1].title or "Home"
	pageTitle.Parent = contentHeader

	pageSubtitle = Instance.new("TextLabel")
	pageSubtitle.Size = UDim2.new(1, -8, 0, 16)
	pageSubtitle.Position = UDim2.new(0, 0, 0, 24)
	pageSubtitle.BackgroundTransparency = 1
	pageSubtitle.Font = Enum.Font.Gotham
	pageSubtitle.TextSize = 10
	pageSubtitle.TextColor3 = COLORS.muted
	pageSubtitle.TextXAlignment = Enum.TextXAlignment.Left
	pageSubtitle.Text = tabs[1] and tabs[1].subtitle or ""
	pageSubtitle.Parent = contentHeader

	local pagesHost = Instance.new("Frame")
	pagesHost.Size = UDim2.new(1, 0, 1, -52)
	pagesHost.Position = UDim2.new(0, 0, 0, 52)
	pagesHost.BackgroundTransparency = 1
	pagesHost.ClipsDescendants = true
	pagesHost.Parent = contentHost

	local function registerTab(def)
		local i = #tabButtons + 1
		local tabDef = {
			name = def.name or ("Tab " .. i),
			title = def.title or def.name or ("Tab " .. i),
			subtitle = def.subtitle or "",
			localeKey = def.localeKey,
			titleKey = def.titleKey,
			subtitleKey = def.subtitleKey,
		}
		tabMeta[i] = tabDef

		local btn = Instance.new("TextButton")
		if mobileMode then
			btn.Size = UDim2.new(0, 0, 0, 36)
			btn.AutomaticSize = Enum.AutomaticSize.X
			local btnPad = Instance.new("UIPadding")
			btnPad.PaddingLeft = UDim.new(0, 12)
			btnPad.PaddingRight = UDim.new(0, 12)
			btnPad.Parent = btn
		else
			btn.Size = UDim2.new(1, -16, 0, 34)
		end
		btn.BackgroundColor3 = i == 1 and COLORS.accent or COLORS.tabIdle
		btn.BorderSizePixel = 0
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 11
		btn.TextColor3 = i == 1 and COLORS.bg or COLORS.muted
		btn.Text = tabDef.name
		btn.TextTruncate = Enum.TextTruncate.AtEnd
		btn.AutoButtonColor = false
		btn.LayoutOrder = i
		btn.Parent = sideTop
		addCorner(btn, 8)
		tabButtons[i] = btn
		if registerLocale and type(tabDef.localeKey) == "string" then
			registerLocale(btn, tabDef.localeKey)
		end

		local page
		if mobileMode then
			local pageScroll = Instance.new("ScrollingFrame")
			pageScroll.Name = "TabPageScroll"
			pageScroll.Size = UDim2.new(1, 0, 1, 0)
			pageScroll.Visible = (i == 1)
			pageScroll.Parent = pagesHost
			enhanceScrollFrame(pageScroll)
			tabPageScrolls[i] = pageScroll

			page = Instance.new("Frame")
			page.Name = "MobilePageHolder"
			page.Size = UDim2.new(1, 0, 0, 0)
			page.BackgroundTransparency = 1
			page.Parent = pageScroll
			bindMobilePageScroll(pageScroll, page)
		else
			page = Instance.new("Frame")
			page.Size = UDim2.new(1, 0, 1, 0)
			page.BackgroundTransparency = 1
			page.Visible = (i == 1)
			page.Parent = pagesHost
		end
		contentPages[i] = page

		btn.MouseButton1Click:Connect(function()
			switchTab(i)
		end)

		return { Page = page, Index = i }
	end

	for _, def in ipairs(tabs) do
		registerTab(def)
	end

	local ui = {
		COLORS = COLORS,
		screenGui = screenGui,
		uiRoot = uiRoot,
		uiBody = uiBody,
		contentPages = contentPages,
		tabButtons = tabButtons,
		windowWidth = WINDOW_W,
		windowHeight = WINDOW_H,
		sidebarWidth = SIDEBAR_W,
		contentWidth = contentWidth,
		pageTitle = pageTitle,
		pageSubtitle = pageSubtitle,
		userKey = userKey,
		userKeyCaption = userKeyCaption,
		refreshKeyStatus = refreshKeyStatus,
		addCorner = addCorner,
		switchTab = switchTab,
		makeSectionTitle = makeSectionTitle,
		makeToggle = makeToggle,
		makeSlider = makeSlider,
		makeScrollPage = makeScrollPage,
		makeListWrap = makeListWrap,
		makeFlowPanel = makeFlowPanel,
		makeStatRow = makeStatRow,
		makeFlowToggle = makeFlowToggle,
		makeFlowSlider = makeFlowSlider,
		makeCollapsibleSection = makeCollapsibleSection,
		isMobile = function() return mobileMode end,
		refreshMobilePageScrolls = refreshMobilePageScrolls,
		makeDraggable = makeDraggable,
	}

	function ui.NewFlowPanel(_, parent, title, width, height, posX, posY, bodyOffsetY)
		return makeFlowPanel(parent, title, width, height, posX, posY, bodyOffsetY)
	end

	function ui.NewFlowToggle(_, parent, label, initial, onChange, layoutOrder, debounce)
		return makeFlowToggle(parent, label, initial, onChange, layoutOrder, debounce)
	end

	function ui.NewToggle(_, parent, y, label, initial, onChange, debounce)
		return makeToggle(parent, y, label, initial, onChange, debounce)
	end

	function ui.NewSlider(_, parent, y, label, min, max, initial, onChange)
		return makeSlider(parent, y, label, min, max, initial, onChange)
	end

	function ui.NewScrollPage(_, parent)
		return makeScrollPage(parent)
	end

	function ui.NewListWrap(_, scroll)
		return makeListWrap(scroll)
	end

	function ui.NewSectionTitle(_, parent, text, order)
		return makeSectionTitle(parent, text, order)
	end

	function ui.NewStatRow(_, parent, label, layoutOrder)
		return makeStatRow(parent, label, layoutOrder)
	end

	function ui.NewTab(name, subtitleOrDef)
		local def
		if typeof(name) == "table" then
			def = name
		elseif typeof(subtitleOrDef) == "table" then
			def = subtitleOrDef
			def.name = def.name or name
		else
			def = {
				name = name,
				title = name,
				subtitle = subtitleOrDef or "",
			}
		end
		return registerTab(def)
	end

	function ui.ToggleUI()
		if uiRoot then
			uiRoot.Visible = not uiRoot.Visible
		end
	end

	function ui.Destroy()
		if screenGui and screenGui.Parent then
			screenGui:Destroy()
		end
		genv._MaxiHubGuiRegistry[guiName] = nil
		local conn = genv._MaxiHubInputConn[guiName]
		if conn then
			pcall(function() conn:Disconnect() end)
			genv._MaxiHubInputConn[guiName] = nil
		end
	end

	local function showHideHintOnce()
		local hideHintKey = "MaxiHubHideHint_" .. guiName
		if genv[hideHintKey] then return end
		genv[hideHintKey] = true

		local toast = Instance.new("TextLabel")
		toast.Name = "HideHint"
		toast.AnchorPoint = Vector2.new(0.5, 0)
		toast.Size = UDim2.new(0, 240, 0, 22)
		toast.Position = UDim2.new(0.5, 0, 0, 50)
		toast.BackgroundTransparency = 1
		toast.BorderSizePixel = 0
		toast.Font = Enum.Font.Gotham
		toast.TextSize = 11
		toast.TextColor3 = COLORS.muted
		toast.Text = hideHintMessage
		toast.TextTransparency = 1
		toast.ZIndex = 20
		toast.Parent = screenGui

		TweenService:Create(toast, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			TextTransparency = 0.35,
		}):Play()

		task.delay(3, function()
			if not toast.Parent then return end
			local fade = TweenService:Create(toast, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				TextTransparency = 1,
			})
			fade:Play()
			fade.Completed:Connect(function()
				toast:Destroy()
			end)
		end)
	end

	function ui.recalcLayoutMetrics()
		if uiRoot then
			WINDOW_W = uiRoot.Size.X.Offset
			WINDOW_H = uiRoot.Size.Y.Offset
		end
		contentWidth = calcContentWidth()
		ui.windowWidth = WINDOW_W
		ui.windowHeight = WINDOW_H
		ui.contentWidth = contentWidth
		ui.sidebarWidth = SIDEBAR_W
	end

	function ui.finalize()
		makeDraggable(uiRoot, titleBar)

		local vp, inset = getViewportMetrics()
		local maxW = math.max(320, math.floor(vp.X - 12))
		local maxH = math.max(300, math.floor(vp.Y - inset.Y - (mobileMode and (MOBILE_DOCK_H + 16) or 12)))
		makeResizable(uiRoot, 280, 300, maxW, maxH, function()
			ui.recalcLayoutMetrics()
			refreshMobilePageScrolls()
			if typeof(onSavePosition) == "function" then
				onSavePosition()
			end
		end)

		local titleBarExpandedSize = UDim2.new(1, 0, 0, 42)
		local titleBarExpandedPos = UDim2.new(0, 0, 0, 0)
		local uiBodyExpandedSize = UDim2.new(1, -16, 1, -50)
		local uiBodyExpandedPos = UDim2.new(0, 8, 0, 46)

		local minimized = false
		local savedSize = uiRoot.Size
		hideBtn.MouseButton1Click:Connect(function()
			minimized = not minimized
			if minimized then
				savedSize = uiRoot.Size
				uiRoot.Size = UDim2.new(0, WINDOW_W, 0, 40)
				uiBody.Visible = false
				if mobileTabBar then
					mobileTabBar.Visible = false
				end
				titleFix.Visible = false
				titleBar.Size = UDim2.new(1, 0, 1, 0)
				titleBar.Position = UDim2.new(0, 0, 0, 0)
				title.Size = UDim2.new(1, -140, 1, 0)
				title.Position = UDim2.new(0, 14, 0, 0)
				title.TextYAlignment = Enum.TextYAlignment.Center
				titleHint.Visible = false
				hideBtn.Text = "+"
				showHideHintOnce()
			else
				uiRoot.Size = savedSize
				uiBody.Visible = true
				if mobileTabBar then
					mobileTabBar.Visible = true
				end
				titleFix.Visible = true
				titleBar.Size = titleBarExpandedSize
				titleBar.Position = titleBarExpandedPos
				title.Size = UDim2.new(1, -140, 0, 22)
				title.Position = UDim2.new(0, 14, 0, 6)
				title.TextYAlignment = Enum.TextYAlignment.Center
				titleHint.Visible = true
				uiBody.Size = uiBodyExpandedSize
				uiBody.Position = uiBodyExpandedPos
				hideBtn.Text = "—"
			end
		end)

		genv._MaxiHubInputConn[guiName] = UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if gameProcessed then return end

			if not mobileMode and input.KeyCode == Enum.KeyCode.RightControl then
				local willHide = uiRoot.Visible
				uiRoot.Visible = not uiRoot.Visible
				if willHide then
					showHideHintOnce()
				end
				return
			end

			if typeof(extraInputHandler) == "function" then
				extraInputHandler(input, gameProcessed)
			end
		end)

		switchTab(1)

		if mobileMode then
			local dock = Instance.new("Frame")
			dock.Name = "MobileDock"
			dock.Size = UDim2.new(0, 88, 0, MOBILE_DOCK_H + 4)
			dock.Position = UDim2.new(0.5, -44, 1, -(MOBILE_DOCK_H + 12 + inset.Y))
			dock.BackgroundTransparency = 1
			dock.ZIndex = 100
			dock.Active = false
			dock.Parent = screenGui

			local menuBtn = Instance.new("TextButton")
			menuBtn.Size = UDim2.new(0, 80, 0, MOBILE_DOCK_H)
			menuBtn.Position = UDim2.new(0, 4, 0, 0)
			menuBtn.BackgroundColor3 = COLORS.panel
			menuBtn.BorderSizePixel = 0
			menuBtn.Font = Enum.Font.GothamBold
			menuBtn.TextSize = 13
			menuBtn.TextColor3 = COLORS.text
			menuBtn.Text = config.mobileMenuText or "Menu"
			menuBtn.AutoButtonColor = false
			menuBtn.ZIndex = 101
			menuBtn.Active = true
			menuBtn.Selectable = true
			menuBtn.Parent = dock
			addCorner(menuBtn, 10)
			if registerLocale and type(config.mobileMenuLocaleKey) == "string" then
				registerLocale(menuBtn, config.mobileMenuLocaleKey)
			end
			menuBtn.MouseButton1Click:Connect(function()
				if typeof(onMobileMenuToggle) == "function" then
					onMobileMenuToggle()
				elseif uiRoot then
					uiRoot.Visible = not uiRoot.Visible
				end
			end)
		end

		if mobileMode then
			refreshMobilePageScrolls()
			task.delay(0.2, refreshMobilePageScrolls)
			task.delay(0.6, refreshMobilePageScrolls)
		end
	end

	function ui.onInputBegan(handler)
		extraInputHandler = handler
	end

	ui.OnInputBegan = ui.onInputBegan
	ui.Finalize = ui.finalize

	function ui.setLanguage(lang)
		if type(lang) ~= "string" then
			return
		end
		local code = lang:lower()
		if code ~= "ru" and code ~= "en" then
			return
		end
		if currentLanguage == code then
			return
		end
		currentLanguage = code
		paintLanguageButtons()
	end

	function ui.setTitleHint(text)
		if titleHint then
			titleHint.Text = text or ""
		end
	end

	function ui.setVersion(text)
		if userVersion then
			userVersion.Text = text or ""
			userVersion.Visible = text ~= nil and text ~= ""
		end
	end

	function ui.setHideHintText(text)
		hideHintMessage = text or hideHintMessage
	end

	function ui.refreshTabLabels(defs)
		if type(defs) ~= "table" then return end
		for i, def in ipairs(defs) do
			if tabMeta[i] and tabButtons[i] then
				tabMeta[i].name = def.name or tabMeta[i].name
				tabMeta[i].title = def.title or def.name or tabMeta[i].title
				tabMeta[i].subtitle = def.subtitle or ""
				tabMeta[i].localeKey = def.localeKey or tabMeta[i].localeKey
				tabMeta[i].titleKey = def.titleKey or tabMeta[i].titleKey
				tabMeta[i].subtitleKey = def.subtitleKey or tabMeta[i].subtitleKey
				if registerLocale and type(tabMeta[i].localeKey) == "string" then
					registerLocale(tabButtons[i], tabMeta[i].localeKey)
				else
					tabButtons[i].Text = tabMeta[i].name
				end
			end
		end
		switchTab(activeTabId)
	end

	return ui
end

function MaxiHubUI.CreateLib(title, options)
	options = options or {}
	if typeof(title) == "string" then
		options.title = options.title or title
	end
	return MaxiHubUI.create(options)
end

MaxiHubUI.CreateWindow = MaxiHubUI.CreateLib

local ERROR_PANEL_COLORS = {
	bg = Color3.fromRGB(14, 16, 18),
	panel = Color3.fromRGB(26, 30, 33),
	accent = Color3.fromRGB(0, 198, 178),
	text = Color3.fromRGB(242, 246, 248),
	muted = Color3.fromRGB(125, 135, 142),
	red = Color3.fromRGB(220, 75, 75),
	line = Color3.fromRGB(40, 48, 52),
}

function MaxiHubUI.formatError(err, level)
	local message = tostring(err)
	if debug and typeof(debug.traceback) == "function" then
		message = debug.traceback(message, level or 2)
	end
	return message
end

function MaxiHubUI.showError(err, opts)
	opts = opts or {}
	local message = tostring(err)
	if type(err) == "table" then
		message = err.trace or err.message or tostring(err)
	end
	if opts.trace and type(opts.trace) == "string" then
		message = message .. "\n\n" .. opts.trace
	end
	if opts.header and type(opts.header) == "string" then
		message = opts.header .. "\n" .. message
	end

	local discordUrl = opts.discordUrl or "https://discord.gg/CYJ26HW6BU"
	local guiName = opts.guiName or "MaxiHubError"
	local titleText = opts.title or "🔰MAXI HUB"

	local player = opts.player
	if not player then
		player = Players.LocalPlayer
	end
	if not player then
		return nil
	end
	local playerGui = opts.playerGui or player:FindFirstChild("PlayerGui")
	if not playerGui then
		return nil
	end

	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(800, 600)
	local inset = GuiService:GetGuiInset()
	local isMobile = UserInputService.TouchEnabled and vp.X <= 520

	local old = playerGui:FindFirstChild(guiName)
	if old then
		old:Destroy()
	end

	local sg = Instance.new("ScreenGui")
	sg.Name = guiName
	sg.ResetOnSpawn = false
	sg.IgnoreGuiInset = true
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sg.DisplayOrder = opts.displayOrder or 1000000
	sg.Parent = playerGui

	local panelW = isMobile and math.clamp(math.floor(vp.X * 0.92), 280, 400) or 440
	local maxPanelH = math.max(220, math.floor(vp.Y - inset.Y - 24))

	local root = Instance.new("Frame")
	root.Size = UDim2.new(0, panelW, 0, 180)
	root.Position = UDim2.new(0.5, -math.floor(panelW / 2), 0.5, -90)
	root.BackgroundColor3 = ERROR_PANEL_COLORS.bg
	root.BorderSizePixel = 0
	root.Active = true
	root.ZIndex = 2
	root.Parent = sg

	local rootCorner = Instance.new("UICorner")
	rootCorner.CornerRadius = UDim.new(0, 10)
	rootCorner.Parent = root

	local rootStroke = Instance.new("UIStroke")
	rootStroke.Color = ERROR_PANEL_COLORS.line
	rootStroke.Thickness = 1
	rootStroke.Parent = root

	local titleBar = Instance.new("Frame")
	titleBar.Size = UDim2.new(1, 0, 0, 36)
	titleBar.BackgroundColor3 = ERROR_PANEL_COLORS.panel
	titleBar.BorderSizePixel = 0
	titleBar.ZIndex = 3
	titleBar.Parent = root

	local titleBarCorner = Instance.new("UICorner")
	titleBarCorner.CornerRadius = UDim.new(0, 10)
	titleBarCorner.Parent = titleBar

	local titleBarFix = Instance.new("Frame")
	titleBarFix.Size = UDim2.new(1, 0, 0, 10)
	titleBarFix.Position = UDim2.new(0, 0, 1, -10)
	titleBarFix.BackgroundColor3 = ERROR_PANEL_COLORS.panel
	titleBarFix.BorderSizePixel = 0
	titleBarFix.ZIndex = 3
	titleBarFix.Parent = titleBar

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.new(1, -72, 1, 0)
	titleLbl.Position = UDim2.new(0, 12, 0, 0)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Font = Enum.Font.GothamBold
	titleLbl.TextSize = 13
	titleLbl.TextColor3 = ERROR_PANEL_COLORS.red
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.Text = titleText
	titleLbl.ZIndex = 4
	titleLbl.Parent = titleBar

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 28, 0, 28)
	closeBtn.Position = UDim2.new(1, -34, 0.5, -14)
	closeBtn.BackgroundColor3 = ERROR_PANEL_COLORS.bg
	closeBtn.BorderSizePixel = 0
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 16
	closeBtn.TextColor3 = ERROR_PANEL_COLORS.text
	closeBtn.Text = "×"
	closeBtn.AutoButtonColor = false
	closeBtn.ZIndex = 4
	closeBtn.Parent = titleBar

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 6)
	closeCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		sg:Destroy()
	end)

	local dragging = false
	local dragStart
	local startPos

	titleBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = root.Position
		end
	end)

	titleBar.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if not dragging then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement
			and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local delta = input.Position - dragStart
		root.Position = UDim2.new(
			startPos.X.Scale,
			startPos.X.Offset + delta.X,
			startPos.Y.Scale,
			startPos.Y.Offset + delta.Y
		)
	end)

	local body = Instance.new("Frame")
	body.Size = UDim2.new(1, -16, 0, 0)
	body.Position = UDim2.new(0, 8, 0, 44)
	body.AutomaticSize = Enum.AutomaticSize.Y
	body.BackgroundTransparency = 1
	body.ZIndex = 3
	body.Parent = root

	local bodyLayout = Instance.new("UIListLayout")
	bodyLayout.Padding = UDim.new(0, 8)
	bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
	bodyLayout.Parent = body

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, 0, 0, 120)
	scroll.BackgroundColor3 = ERROR_PANEL_COLORS.panel
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = isMobile and 6 or 4
	scroll.ScrollBarImageColor3 = ERROR_PANEL_COLORS.accent
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollingEnabled = true
	scroll.Active = true
	scroll.LayoutOrder = 1
	scroll.ZIndex = 3
	scroll.Parent = body

	local scrollCorner = Instance.new("UICorner")
	scrollCorner.CornerRadius = UDim.new(0, 8)
	scrollCorner.Parent = scroll

	local scrollPad = Instance.new("UIPadding")
	scrollPad.PaddingTop = UDim.new(0, 6)
	scrollPad.PaddingBottom = UDim.new(0, 8)
	scrollPad.PaddingLeft = UDim.new(0, 6)
	scrollPad.PaddingRight = UDim.new(0, 6)
	scrollPad.Parent = scroll

	local msg = Instance.new("TextLabel")
	msg.Size = UDim2.new(1, 0, 0, 0)
	msg.AutomaticSize = Enum.AutomaticSize.Y
	msg.BackgroundTransparency = 1
	msg.Font = Enum.Font.Code
	msg.TextSize = isMobile and 11 or 12
	msg.TextColor3 = ERROR_PANEL_COLORS.text
	msg.TextWrapped = true
	msg.TextXAlignment = Enum.TextXAlignment.Left
	msg.TextYAlignment = Enum.TextYAlignment.Top
	msg.Text = message
	msg.ZIndex = 4
	msg.Parent = scroll

	local btnRow = Instance.new("Frame")
	btnRow.Size = UDim2.new(1, 0, 0, 36)
	btnRow.BackgroundTransparency = 1
	btnRow.LayoutOrder = 2
	btnRow.ZIndex = 3
	btnRow.Parent = body

	local btnLayout = Instance.new("UIListLayout")
	btnLayout.FillDirection = Enum.FillDirection.Horizontal
	btnLayout.Padding = UDim.new(0, 8)
	btnLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	btnLayout.Parent = btnRow

	local function makeBtn(text, bg, textColor)
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0, 0, 0, 32)
		b.AutomaticSize = Enum.AutomaticSize.X
		b.BackgroundColor3 = bg
		b.BorderSizePixel = 0
		b.Font = Enum.Font.GothamBold
		b.TextSize = 12
		b.TextColor3 = textColor
		b.Text = text
		b.AutoButtonColor = false
		b.ZIndex = 4
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 12)
		pad.PaddingRight = UDim.new(0, 12)
		pad.Parent = b
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 8)
		c.Parent = b
		b.Parent = btnRow
		return b
	end

	local copyBtn = makeBtn("Copy error", ERROR_PANEL_COLORS.accent, ERROR_PANEL_COLORS.bg)
	copyBtn.MouseButton1Click:Connect(function()
		pcall(function()
			if typeof(setclipboard) == "function" then
				setclipboard(message)
			end
		end)
		copyBtn.Text = "Copied!"
		task.delay(1.2, function()
			if copyBtn.Parent then
				copyBtn.Text = "Copy error"
			end
		end)
	end)

	local discordBtn = makeBtn("Discord", ERROR_PANEL_COLORS.panel, ERROR_PANEL_COLORS.text)
	discordBtn.MouseButton1Click:Connect(function()
		pcall(function()
			if typeof(setclipboard) == "function" then
				setclipboard(discordUrl)
			end
		end)
		discordBtn.Text = "Copied!"
		task.delay(1.2, function()
			if discordBtn.Parent then
				discordBtn.Text = "Discord"
			end
		end)
	end)

	task.defer(function()
		if not scroll.Parent then
			return
		end
		local contentH = math.max(48, scroll.AbsoluteCanvasSize.Y + 4)
		local capped = math.clamp(contentH, 48, math.min(320, maxPanelH - 120))
		scroll.Size = UDim2.new(1, 0, 0, capped)
		task.defer(function()
			if not root.Parent then
				return
			end
			local totalH = math.min(body.AbsoluteSize.Y + 52, maxPanelH)
			root.Size = UDim2.new(0, panelW, 0, totalH)
			root.Position = UDim2.new(0.5, -math.floor(panelW / 2), 0.5, -math.floor(totalH / 2))
		end)
	end)

	return sg
end

return MaxiHubUI
