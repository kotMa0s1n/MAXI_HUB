-- MAXI HUB | picker (unknown PlaceId)
-- Loaded by loader.lua. Click injects a script and closes this menu.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local DISCORD_LINK = "https://discord.gg/CYJ26HW6BU"
local RAW = "https://raw.githubusercontent.com/kotMa0s1n/MAXI_HUB/main/"
local CDN = "https://cdn.jsdelivr.net/gh/kotMa0s1n/MAXI_HUB@main/"

local genv = typeof(getgenv) == "function" and getgenv() or _G
local MaxiHubUI = genv._MaxiHubUILibrary
if type(MaxiHubUI) ~= "table" or typeof(MaxiHubUI.create) ~= "function" then
	return
end

if genv.MaxiHubPickerStop then
	pcall(genv.MaxiHubPickerStop)
end

local TEXT = {
	en = {
		tab_games = "Games",
		tab_games_sub = "Click to inject",
		tab_universal = "Universal",
		tab_universal_sub = "Works in any game",
		tab_credits = "About",
		tab_credits_sub = "Script info & support",
		about = "MAXI HUB\nThis game has no dedicated script.\nPick one below — the menu closes after inject.",
		discord = "Discord",
		discord_copied = "Copied!",
		busy = "Injecting…",
		hide_hint = "RightCtrl — hide",
		hide_open = "RightCtrl — open menu",
		hide_mobile = "Menu — open",
		mobile_btn_menu = "Menu",
	},
	ru = {
		tab_games = "Игры",
		tab_games_sub = "Нажми, чтобы запустить",
		tab_universal = "Универсал",
		tab_universal_sub = "Работает в любой игре",
		tab_credits = "О скрипте",
		tab_credits_sub = "Инфо и поддержка",
		about = "MAXI HUB\nДля этой игры нет своего скрипта.\nВыбери ниже — меню закроется после запуска.",
		discord = "Дискорд",
		discord_copied = "Скопировано!",
		busy = "Запуск…",
		hide_hint = "RightCtrl — скрыть",
		hide_open = "RightCtrl — открыть меню",
		hide_mobile = "Меню — открыть",
		mobile_btn_menu = "Меню",
	},
}

local lang = (type(genv.MaxiHubUiLanguage) == "string" and genv.MaxiHubUiLanguage:lower() == "ru") and "ru" or "en"
local function L(key)
	local bucket = TEXT[lang] or TEXT.en
	return (bucket and bucket[key]) or TEXT.en[key] or key
end

local FALLBACK = {
	games = {
		{ name = "British Railway", url = RAW .. "BR/loader.lua" },
		{ name = "Stepford County Railway", url = RAW .. "SCR/loader.lua" },
		{ name = "El Paso BR", url = RAW .. "el-paso-br/loader.lua" },
	},
	universal = {
		{ name = "Anti AFK", url = "https://raw.githubusercontent.com/kotMa0s1n/maxkiti01/main/anti-afk.lua" },
		{ name = "Infinite Yield", url = "https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source" },
		{ name = "Dex Explorer", url = "https://raw.githubusercontent.com/infyiff/backup/main/dex.lua" },
	},
}

local function httpGet(url)
	if type(url) ~= "string" or url == "" then
		return nil
	end
	if typeof(game.HttpGet) == "function" then
		local ok, body = pcall(game.HttpGet, game, url, true)
		if ok and type(body) == "string" and body ~= "" then
			return body
		end
	end
	local requestFn = (typeof(syn) == "table" and syn.request) or request or http_request
	if typeof(requestFn) == "function" then
		local ok, res = pcall(requestFn, { Url = url, Method = "GET" })
		if ok and type(res) == "table" and type(res.Body) == "string" and res.Body ~= "" then
			return res.Body
		end
	end
	return nil
end

local function loadCatalog()
	local data = genv.MaxiHubScriptCatalog
	if type(data) ~= "table" then
		local bust = tostring(os.time()) .. tostring(math.random(1000, 9999))
		local raw = httpGet(RAW .. "HUB/scripts.json?v=" .. bust) or httpGet(CDN .. "HUB/scripts.json?v=" .. bust)
		if raw then
			local ok, decoded = pcall(function()
				return HttpService:JSONDecode(raw)
			end)
			if ok and type(decoded) == "table" then
				data = decoded
			end
		end
	end
	if type(data) ~= "table" then
		data = FALLBACK
	end
	if type(data.games) ~= "table" then
		data.games = FALLBACK.games
	end
	if type(data.universal) ~= "table" then
		data.universal = FALLBACK.universal
	end
	return data
end

if not game:IsLoaded() then
	game.Loaded:Wait()
end
local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local playerGui = player:FindFirstChild("PlayerGui") or player:WaitForChild("PlayerGui", 30)
if not playerGui then
	return
end

local catalog = loadCatalog()
local injecting = false
local uiInstance

local function getTabDefs()
	return {
		{ localeKey = "tab_games", name = L("tab_games"), title = L("tab_games"), subtitle = L("tab_games_sub") },
		{ localeKey = "tab_universal", name = L("tab_universal"), title = L("tab_universal"), subtitle = L("tab_universal_sub") },
		{ localeKey = "tab_credits", name = L("tab_credits"), title = L("tab_credits"), subtitle = L("tab_credits_sub") },
	}
end

uiInstance = MaxiHubUI.create({
	player = player,
	playerGui = playerGui,
	genv = genv,
	guiName = "MaxiHubPicker",
	title = "🔰MAXI HUB",
	titleHint = L("hide_hint"),
	titleHintMobile = L("hide_mobile"),
	hideHintText = L("hide_open"),
	hideHintMobile = L("hide_mobile"),
	language = lang,
	forceMobile = genv.MaxiHubForceMobile == true,
	mobileCompact = true,
	tabs = getTabDefs(),
	onMobileMenuToggle = function()
		if uiInstance and uiInstance.uiRoot then
			uiInstance.uiRoot.Visible = not uiInstance.uiRoot.Visible
		end
	end,
	mobileMenuLocaleKey = "mobile_btn_menu",
	mobileMenuText = L("mobile_btn_menu"),
})

genv.MaxiHubPickerStop = function()
	if uiInstance and typeof(uiInstance.Destroy) == "function" then
		pcall(uiInstance.Destroy)
	end
	uiInstance = nil
end

local COLORS = uiInstance.COLORS
local addCorner = uiInstance.addCorner
local pages = uiInstance.contentPages

local function inject(entry, btn)
	if injecting or type(entry) ~= "table" or type(entry.url) ~= "string" or entry.url == "" then
		return
	end
	injecting = true
	if btn then
		btn.Text = L("busy")
	end
	local url = entry.url
	if uiInstance and typeof(uiInstance.Destroy) == "function" then
		pcall(uiInstance.Destroy)
	end
	uiInstance = nil
	task.defer(function()
		local src = httpGet(url)
		if type(src) ~= "string" or src == "" then
			return
		end
		local fn, err = loadstring(src, "@" .. (entry.name or "script"))
		if not fn then
			return
		end
		fn()
	end)
end

local function fillScriptPage(page, list)
	local scroll = uiInstance.makeScrollPage(page)
	local wrap = uiInstance.makeListWrap(scroll)
	for i, entry in ipairs(list) do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, 0, 0, 40)
		btn.BackgroundColor3 = COLORS.accent
		btn.BorderSizePixel = 0
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 13
		btn.TextColor3 = COLORS.bg
		btn.Text = entry.name or "Script"
		btn.AutoButtonColor = false
		btn.LayoutOrder = i
		btn.Parent = wrap
		addCorner(btn, 8)
		btn.MouseButton1Click:Connect(function()
			inject(entry, btn)
		end)
	end
end

fillScriptPage(pages[1], catalog.games)
fillScriptPage(pages[2], catalog.universal)

local credScroll = uiInstance.makeScrollPage(pages[3])
local credWrap = uiInstance.makeListWrap(credScroll)

local about = Instance.new("TextLabel")
about.Size = UDim2.new(1, 0, 0, 88)
about.BackgroundColor3 = COLORS.panel
about.BorderSizePixel = 0
about.Font = Enum.Font.Gotham
about.TextSize = 12
about.TextColor3 = COLORS.text
about.TextWrapped = true
about.Text = L("about")
about.LayoutOrder = 1
about.Parent = credWrap
addCorner(about, 8)

local discordBtn = Instance.new("TextButton")
discordBtn.Size = UDim2.new(1, 0, 0, 40)
discordBtn.BackgroundColor3 = COLORS.accent
discordBtn.BorderSizePixel = 0
discordBtn.Font = Enum.Font.GothamBold
discordBtn.TextSize = 13
discordBtn.TextColor3 = COLORS.bg
discordBtn.Text = L("discord")
discordBtn.AutoButtonColor = false
discordBtn.LayoutOrder = 2
discordBtn.Parent = credWrap
addCorner(discordBtn, 8)
discordBtn.MouseButton1Click:Connect(function()
	pcall(function()
		if typeof(setclipboard) == "function" then
			setclipboard(DISCORD_LINK)
		end
	end)
	discordBtn.Text = L("discord_copied")
	task.delay(1.5, function()
		if discordBtn.Parent then
			discordBtn.Text = L("discord")
		end
	end)
end)

if typeof(uiInstance.finalize) == "function" then
	uiInstance.finalize()
end
