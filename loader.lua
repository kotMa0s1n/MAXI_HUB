-- MAXI HUB | universal entry
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/kotMa0s1n/MAXI_HUB/main/loader.lua"))()

local LOADER_VERSION = "1.0"
local RAW = "https://raw.githubusercontent.com/kotMa0s1n/MAXI_HUB/main/"
local CDN = "https://cdn.jsdelivr.net/gh/kotMa0s1n/MAXI_HUB@main/"

local GAMES = {
	[10082031223] = { name = "British Railway", path = "BR/loader.lua" },
	[7049848150] = { name = "Stepford County Railway", path = "SCR/loader.lua" },
	[3647330858] = { name = "Stepford County Railway", path = "SCR/loader.lua" },
	[14502598369] = { name = "El Paso BR", path = "el-paso-br/loader.lua" },
}

local MIN_BYTES = 64
local genv = typeof(getgenv) == "function" and getgenv() or _G
genv.MaxiHubSkipKey = true
genv.MaxiHubUniversalVersion = LOADER_VERSION

local function cacheBust()
	return tostring(os.time()) .. tostring(math.random(1000, 9999))
end

local function httpGet(url)
	local function okBody(body)
		return type(body) == "string" and body ~= ""
	end
	if typeof(game.HttpGet) == "function" then
		local ok, body = pcall(game.HttpGet, game, url, true)
		if ok and okBody(body) then
			return body
		end
	end
	local requestFn = (typeof(syn) == "table" and syn.request) or request or http_request
	if typeof(requestFn) == "function" then
		local ok, res = pcall(requestFn, { Url = url, Method = "GET" })
		if ok and type(res) == "table" and okBody(res.Body) then
			return res.Body
		end
	end
	return nil
end

local function stripBom(src)
	if type(src) == "string" and src:sub(1, 3) == "\239\187\191" then
		return src:sub(4)
	end
	return src
end

local function acceptDownload(src)
	src = stripBom(src)
	if type(src) ~= "string" or #src < MIN_BYTES then
		return nil
	end
	local head = src:sub(1, 240):lower()
	if head:find("<!doctype", 1, true) or head:find("<html", 1, true) or head:find("404: not found", 1, true) then
		return nil
	end
	return src
end

local function fetchScript(relPath)
	local bust = cacheBust()
	for _, base in ipairs({ RAW, CDN }) do
		local body = acceptDownload(httpGet(base .. relPath .. "?v=" .. bust))
		if body then
			return body
		end
	end
	return nil
end

local function detectByGui()
	local player = game:GetService("Players").LocalPlayer
	local pg = player and player:FindFirstChild("PlayerGui")
	if not pg then
		return nil
	end
	local ui = pg:FindFirstChild("UI")
	if ui and (ui:FindFirstChild("Drive") or ui:FindFirstChild("Spawn") or ui:FindFirstChild("RoutePicker")) then
		return GAMES[10082031223]
	end
	if pg:FindFirstChild("DriveGui") then
		return GAMES[7049848150]
	end
	return nil
end

local function supportedList()
	local seen, names = {}, {}
	for _, g in pairs(GAMES) do
		if not seen[g.name] then
			seen[g.name] = true
			table.insert(names, g.name)
		end
	end
	table.sort(names)
	return table.concat(names, ", ")
end

local placeId = tonumber(game.PlaceId) or 0
local gameInfo = GAMES[placeId]
if not gameInfo then
	gameInfo = detectByGui()
end
if not gameInfo then
	error("[MAXI HUB] No script for this game (PlaceId " .. tostring(placeId) .. "). Supported: " .. supportedList())
end

local source = fetchScript(gameInfo.path)
if not source then
	error("[MAXI HUB] Failed to download " .. gameInfo.name .. " loader")
end

local chunk, err = loadstring(source, "@" .. gameInfo.path)
if not chunk then
	error("[MAXI HUB] Compile " .. gameInfo.name .. ": " .. tostring(err))
end

chunk()
