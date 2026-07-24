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
	local canUseConfigFile = deps.canUseConfigFile == true
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

	local webhookBox = Instance.new("Frame")
	webhookBox.Size = UDim2.new(1, 0, 0, 74)
	webhookBox.BackgroundColor3 = COLORS.card
	webhookBox.BorderSizePixel = 0
	webhookBox.LayoutOrder = 1
	webhookBox.Parent = wrap
	addCorner(webhookBox, 10)

	local webhookTitle = Instance.new("TextLabel")
	webhookTitle.Size = UDim2.new(1, -20, 0, 18)
	webhookTitle.Position = UDim2.new(0, 10, 0, 8)
	webhookTitle.BackgroundTransparency = 1
	webhookTitle.Font = Enum.Font.GothamBold
	webhookTitle.TextSize = 11
	webhookTitle.TextColor3 = COLORS.text
	webhookTitle.TextXAlignment = Enum.TextXAlignment.Left
	webhookTitle.Text = tr("webhook_title", "Webhook URL")
	webhookTitle.Parent = webhookBox
	reg(webhookTitle, "webhook_title")

	local webhookInput = Instance.new("TextBox")
	webhookInput.Size = UDim2.new(1, -20, 0, 30)
	webhookInput.Position = UDim2.new(0, 10, 0, 32)
	webhookInput.BackgroundColor3 = COLORS.panel
	webhookInput.BorderSizePixel = 0
	webhookInput.ClearTextOnFocus = false
	webhookInput.Font = Enum.Font.Gotham
	webhookInput.TextSize = 10
	webhookInput.TextColor3 = COLORS.text
	webhookInput.PlaceholderText = "https://discord.com/api/webhooks/..."
	webhookInput.PlaceholderColor3 = COLORS.muted
	webhookInput.Text = Config.userDiscordWebhook or ""
	webhookInput.TextXAlignment = Enum.TextXAlignment.Left
	webhookInput.Parent = webhookBox
	addCorner(webhookInput, 8)

	local discordStatus = Instance.new("TextLabel")
	discordStatus.Size = UDim2.new(1, 0, 0, 16)
	discordStatus.BackgroundTransparency = 1
	discordStatus.Font = Enum.Font.Gotham
	discordStatus.TextSize = 10
	discordStatus.TextColor3 = COLORS.muted
	discordStatus.TextXAlignment = Enum.TextXAlignment.Left
	discordStatus.Text = canUseConfigFile and tr("webhook_saved_ok", "Сохраняется в el-paso-br-config.json")
		or tr("webhook_saved_bad", "Файлы недоступны — webhook до перезапуска")
	discordStatus.LayoutOrder = 2
	discordStatus.Parent = wrap
	reg(discordStatus, canUseConfigFile and "webhook_saved_ok" or "webhook_saved_bad")

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
	hint.LayoutOrder = 3
	hint.Parent = wrap
	reg(hint, "discord_hint")

	local discordOpts = Instance.new("Frame")
	discordOpts.Size = UDim2.new(1, 0, 0, 210)
	discordOpts.BackgroundColor3 = COLORS.card
	discordOpts.BorderSizePixel = 0
	discordOpts.LayoutOrder = 4
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
	discordBtns.LayoutOrder = 5
	discordBtns.Parent = wrap

	local testBtn = Instance.new("TextButton")
	testBtn.Size = UDim2.new(0.48, 0, 1, 0)
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

	local saveBtn = Instance.new("TextButton")
	saveBtn.Size = UDim2.new(0.48, 0, 1, 0)
	saveBtn.Position = UDim2.new(0.52, 0, 0, 0)
	saveBtn.BackgroundColor3 = COLORS.panel
	saveBtn.BorderSizePixel = 0
	saveBtn.Font = Enum.Font.GothamBold
	saveBtn.TextSize = 11
	saveBtn.TextColor3 = COLORS.text
	saveBtn.Text = tr("btn_save", "Сохранить")
	saveBtn.AutoButtonColor = false
	saveBtn.Parent = discordBtns
	addCorner(saveBtn, 8)
	reg(saveBtn, "btn_save")

	local function applyWebhookFromInput()
		local url = webhookInput.Text:gsub("^%s+", ""):gsub("%s+$", "")
		Config.userDiscordWebhook = url
		if discordApi and type(discordApi.setUserWebhook) == "function" then
			discordApi.setUserWebhook(url)
		else
			saveConfig()
		end
	end

	webhookInput.FocusLost:Connect(function()
		applyWebhookFromInput()
	end)

	saveBtn.MouseButton1Click:Connect(function()
		applyWebhookFromInput()
		discordStatus.Text = tr("discord_saved", "Сохранено")
		discordStatus.TextColor3 = COLORS.accent
		task.delay(2, function()
			if discordStatus.Parent then
				discordStatus.Text = canUseConfigFile and tr("webhook_saved_ok", "Сохраняется в el-paso-br-config.json")
					or tr("webhook_saved_bad", "Файлы недоступны — webhook до перезапуска")
				discordStatus.TextColor3 = COLORS.muted
			end
		end)
	end)

	testBtn.MouseButton1Click:Connect(function()
		applyWebhookFromInput()
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
