return function(deps, ctx)
	deps = deps or {}
	local ui = ctx and ctx.ui
	local page = ctx and ctx.pages and ctx.pages.discord
	if not ui or not page then return end

	local COLORS = ui.COLORS
	local addCorner = ui.addCorner
	local makeScrollPage = ui.makeScrollPage
	local makeListWrap = ui.makeListWrap
	local makeFlowToggle = ui.makeFlowToggle
	local makeSlider = ui.makeSlider
	local Config = deps.Config or {}
	local saveConfig = deps.saveConfig or function() end
	local discordApi = deps.discordApi

	local function tr(key, fallback)
		local fn = deps.translate
		if type(fn) == "function" then
			local ok, value = pcall(fn, key, fallback)
			if ok and type(value) == "string" and value ~= "" then
				return value
			end
		end
		return fallback or key
	end

	local function reg(el, key)
		if type(deps.registerLocale) == "function" and el and key then
			deps.registerLocale(el, key)
		end
	end

	local scroll = makeScrollPage(page)
	local wrap = makeListWrap(scroll)

	local hint = Instance.new("TextLabel")
	hint.Size = UDim2.new(1, 0, 0, 36)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.Gotham
	hint.TextSize = 10
	hint.TextColor3 = COLORS.muted
	hint.TextWrapped = true
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.TextYAlignment = Enum.TextYAlignment.Top
	hint.Text = tr("discord_hint", "Логи контрабанды: циклы, продажи, время, груз.")
	hint.LayoutOrder = 1
	hint.Parent = wrap
	reg(hint, "discord_hint")

	local discordStatus = Instance.new("TextLabel")
	discordStatus.Size = UDim2.new(1, 0, 0, 16)
	discordStatus.BackgroundTransparency = 1
	discordStatus.Font = Enum.Font.Gotham
	discordStatus.TextSize = 10
	discordStatus.TextColor3 = COLORS.muted
	discordStatus.TextXAlignment = Enum.TextXAlignment.Left
	discordStatus.Text = ""
	discordStatus.LayoutOrder = 2
	discordStatus.Parent = wrap

	local discordOpts = Instance.new("Frame")
	discordOpts.Size = UDim2.new(1, 0, 0, 210)
	discordOpts.BackgroundColor3 = COLORS.card
	discordOpts.BorderSizePixel = 0
	discordOpts.LayoutOrder = 3
	discordOpts.Parent = wrap
	addCorner(discordOpts, 10)

	local discordOptsLayout = Instance.new("UIListLayout")
	discordOptsLayout.Padding = UDim.new(0, 4)
	discordOptsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	discordOptsLayout.Parent = discordOpts

	local discordPad = Instance.new("UIPadding")
	discordPad.PaddingTop = UDim.new(0, 8)
	discordPad.PaddingBottom = UDim.new(0, 8)
	discordPad.PaddingLeft = UDim.new(0, 4)
	discordPad.PaddingRight = UDim.new(0, 4)
	discordPad.Parent = discordOpts

	makeFlowToggle(discordOpts, tr("toggle_discord_reports", "Отчёты в Discord"), Config.discordReportsEnabled ~= false, function(state)
		Config.discordReportsEnabled = state
		saveConfig()
	end, 1, nil, "toggle_discord_reports")

	makeFlowToggle(discordOpts, tr("toggle_discord_stop", "Лог при остановке"), Config.discordLogOnStop ~= false, function(state)
		Config.discordLogOnStop = state
		saveConfig()
	end, 2, nil, "toggle_discord_stop")

	makeFlowToggle(discordOpts, tr("toggle_discord_sell", "Лог после продажи"), Config.discordLogOnSell ~= false, function(state)
		Config.discordLogOnSell = state
		saveConfig()
	end, 3, nil, "toggle_discord_sell")

	local intervalBox = Instance.new("Frame")
	intervalBox.Size = UDim2.new(1, -8, 0, 52)
	intervalBox.BackgroundTransparency = 1
	intervalBox.LayoutOrder = 4
	intervalBox.Parent = discordOpts

	makeSlider(intervalBox, 0, tr("slider_discord_interval", "Интервал (мин)"), 1, 120, Config.discordReportMinutes or 10, function(v)
		Config.discordReportMinutes = math.floor(v)
		saveConfig()
	end, "slider_discord_interval")

	local discordBtns = Instance.new("Frame")
	discordBtns.Size = UDim2.new(1, 0, 0, 36)
	discordBtns.BackgroundTransparency = 1
	discordBtns.LayoutOrder = 4
	discordBtns.Parent = wrap

	local testBtn = Instance.new("TextButton")
	testBtn.Size = UDim2.new(1, 0, 1, 0)
	testBtn.BackgroundColor3 = COLORS.accent
	testBtn.BorderSizePixel = 0
	testBtn.Font = Enum.Font.GothamBold
	testBtn.TextSize = 11
	testBtn.TextColor3 = COLORS.bg
	testBtn.Text = tr("btn_test_webhook", "Тест webhook")
	testBtn.AutoButtonColor = false
	testBtn.Parent = discordBtns
	addCorner(testBtn, 8)
	reg(testBtn, "btn_test_webhook")

	testBtn.MouseButton1Click:Connect(function()
		local ok, msg
		if discordApi and type(discordApi.sendTest) == "function" then
			ok, msg = discordApi.sendTest()
		else
			ok, msg = false, "Discord API недоступен"
		end
		discordStatus.Text = msg or (ok and "OK" or "Ошибка")
		discordStatus.TextColor3 = ok and COLORS.accent or COLORS.red
	end)
end
