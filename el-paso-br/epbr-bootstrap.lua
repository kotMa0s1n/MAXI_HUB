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

	local credScroll = makeScrollPage(contentPages[4])
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
