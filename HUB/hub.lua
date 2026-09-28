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
		tab_games_sub = "MAXI HUB scripts",
		tab_universal = "Universal",
		tab_universal_sub = "Works in any game",
		tab_credits = "About",
		tab_credits_sub = "Script info & support",
		about = "MAXI HUB\nThis game has no dedicated script.\nPick one below — the menu closes after inject.",
		discord = "Discord",
		discord_copied = "Copied!",
		busy = "Injecting…",
		run = "Run",
		search = "Search scripts…",
		empty = "Nothing found",
		hide_hint = "RightCtrl — hide",
		hide_open = "RightCtrl — open menu",
		hide_mobile = "Menu — open",
		mobile_btn_menu = "Menu",
	},
	ru = {
		tab_games = "Игры",
		tab_games_sub = "Скрипты MAXI HUB",
		tab_universal = "Универсал",
		tab_universal_sub = "Работает в любой игре",
		tab_credits = "О скрипте",
		tab_credits_sub = "Инфо и поддержка",
		about = "MAXI HUB\nДля этой игры нет своего скрипта.\nВыбери ниже — меню закроется после запуска.",
		discord = "Дискорд",
		discord_copied = "Скопировано!",
		busy = "Запуск…",
		run = "Запуск",
		search = "Поиск скриптов…",
		empty = "Ничего не найдено",
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
		{ name = "British Railway", short = "Autopilot, doors, AWS", emoji = "🚂", url = RAW .. "BR/loader.lua" },
		{ name = "Stepford County Railway", short = "Autopilot, doors, AWS", emoji = "🚃", url = RAW .. "SCR/loader.lua" },
		{ name = "El Paso BR", short = "Border RP autopilot", emoji = "🌵", url = RAW .. "el-paso-br/loader.lua" },
		{ name = "MAXI HUB Farm", short = "AFK farm", emoji = "🌲", url = "https://raw.githubusercontent.com/kotMa0s1n/maxi-hub/master/loader.lua" },
	},
	universal = {
		{ name = "Anti AFK", short = "Stops idle kick", emoji = "🛡️", url = "https://raw.githubusercontent.com/kotMa0s1n/maxkiti01/main/anti-afk.lua" },
		{ name = "Infinite Yield", short = "Admin commands", emoji = "⚡", url = "https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source" },
		{ name = "Dex Explorer", short = "Instance explorer", emoji = "🔍", url = "https://raw.githubusercontent.com/infyiff/backup/main/dex.lua" },
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

local function inject(entry)
	if injecting or type(entry) ~= "table" or type(entry.url) ~= "string" or entry.url == "" then
		return
	end
	injecting = true
	local url = entry.url
	local name = entry.name or "script"
	if uiInstance and typeof(uiInstance.Destroy) == "function" then
		pcall(uiInstance.Destroy)
	end
	uiInstance = nil
	task.defer(function()
		local src = httpGet(url)
		if type(src) ~= "string" or src == "" then
			return
		end
		local fn = loadstring(src, "@" .. name)
		if fn then
			fn()
		end
	end)
end

local function matchesQuery(entry, query)
	if query == "" then
		return true
	end
	local hay = string.lower((entry.name or "") .. " " .. (entry.short or ""))
	return hay:find(query, 1, true) ~= nil
end

local function makeCard(parent, entry, order)
	local card = Instance.new("TextButton")
	card.Name = "Card"
	card.Size = UDim2.new(1, 0, 0, 72)
	card.BackgroundColor3 = COLORS.card or COLORS.panel
	card.BorderSizePixel = 0
	card.AutoButtonColor = false
	card.Text = ""
	card.LayoutOrder = order
	card.Parent = parent
	addCorner(card, 10)

	local stroke = Instance.new("UIStroke")
	stroke.Color = COLORS.line
	stroke.Thickness = 1
	stroke.Transparency = 0.35
	stroke.Parent = card

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.Parent = card

	local icon = Instance.new("ImageLabel")
	icon.Size = UDim2.new(0, 52, 0, 52)
	icon.Position = UDim2.new(0, 0, 0.5, -26)
	icon.BackgroundColor3 = COLORS.bg
	icon.BorderSizePixel = 0
	icon.ScaleType = Enum.ScaleType.Crop
	icon.Image = (type(entry.icon) == "string" and entry.icon) or ""
	icon.Parent = card
	addCorner(icon, 8)

	if icon.Image == "" then
		local em = Instance.new("TextLabel")
		em.Size = UDim2.new(1, 0, 1, 0)
		em.BackgroundTransparency = 1
		em.Font = Enum.Font.GothamBold
		em.TextSize = 22
		em.Text = entry.emoji or "▶"
		em.Parent = icon
	end

	local run = Instance.new("TextLabel")
	run.Size = UDim2.new(0, 58, 0, 28)
	run.Position = UDim2.new(1, -58, 0.5, -14)
	run.BackgroundColor3 = COLORS.accent
	run.BorderSizePixel = 0
	run.Font = Enum.Font.GothamBold
	run.TextSize = 12
	run.TextColor3 = COLORS.bg
	run.Text = L("run")
	run.Parent = card
	addCorner(run, 7)

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, -130, 0, 20)
	name.Position = UDim2.new(0, 64, 0, 6)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBold
	name.TextSize = 14
	name.TextColor3 = COLORS.text
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.Text = entry.name or "Script"
	name.Parent = card

	local short = Instance.new("TextLabel")
	short.Size = UDim2.new(1, -130, 0, 28)
	short.Position = UDim2.new(0, 64, 0, 28)
	short.BackgroundTransparency = 1
	short.Font = Enum.Font.Gotham
	short.TextSize = 11
	short.TextColor3 = COLORS.muted
	short.TextXAlignment = Enum.TextXAlignment.Left
	short.TextYAlignment = Enum.TextYAlignment.Top
	short.TextWrapped = true
	short.Text = entry.short or ""
	short.Parent = card

	card.MouseEnter:Connect(function()
		stroke.Color = COLORS.accent
		stroke.Transparency = 0
		card.BackgroundColor3 = COLORS.panel
	end)
	card.MouseLeave:Connect(function()
		stroke.Color = COLORS.line
		stroke.Transparency = 0.35
		card.BackgroundColor3 = COLORS.card or COLORS.panel
	end)
	card.MouseButton1Click:Connect(function()
		run.Text = L("busy")
		inject(entry)
	end)
end

local function fillScriptPage(page, list)
	local scroll = uiInstance.makeScrollPage(page)
	local wrap = uiInstance.makeListWrap(scroll)
	if wrap:FindFirstChildOfClass("UIListLayout") then
		wrap:FindFirstChildOfClass("UIListLayout").Padding = UDim.new(0, 8)
	end

	local search = Instance.new("TextBox")
	search.Size = UDim2.new(1, 0, 0, 36)
	search.BackgroundColor3 = COLORS.panel
	search.BorderSizePixel = 0
	search.Font = Enum.Font.Gotham
	search.TextSize = 13
	search.TextColor3 = COLORS.text
	search.PlaceholderText = L("search")
	search.PlaceholderColor3 = COLORS.muted
	search.ClearTextOnFocus = false
	search.Text = ""
	search.LayoutOrder = 0
	search.Parent = wrap
	addCorner(search, 8)
	local searchPad = Instance.new("UIPadding")
	searchPad.PaddingLeft = UDim.new(0, 12)
	searchPad.PaddingRight = UDim.new(0, 12)
	searchPad.Parent = search

	local empty = Instance.new("TextLabel")
	empty.Size = UDim2.new(1, 0, 0, 40)
	empty.BackgroundTransparency = 1
	empty.Font = Enum.Font.Gotham
	empty.TextSize = 12
	empty.TextColor3 = COLORS.muted
	empty.Text = L("empty")
	empty.Visible = false
	empty.LayoutOrder = 999
	empty.Parent = wrap

	local function paint()
		local query = string.lower((search.Text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
		for _, ch in ipairs(wrap:GetChildren()) do
			if ch.Name == "Card" then
				ch:Destroy()
			end
		end
		local n = 0
		for _, entry in ipairs(list) do
			if matchesQuery(entry, query) then
				n = n + 1
				makeCard(wrap, entry, n)
			end
		end
		empty.Visible = n == 0
	end

	search:GetPropertyChangedSignal("Text"):Connect(paint)
	paint()
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
