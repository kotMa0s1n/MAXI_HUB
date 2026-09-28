-- MAXI HUB | universal entry
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/kotMa0s1n/MAXI_HUB/main/loader.lua"))()

local LOADER_VERSION = "1.2"
local RAW = "https://raw.githubusercontent.com/kotMa0s1n/MAXI_HUB/main/"
local CDN = "https://cdn.jsdelivr.net/gh/kotMa0s1n/MAXI_HUB@main/"

local GAMES = {
	[10082031223] = { name = "British Railway", path = "BR/loader.lua" },
	[7049848150] = { name = "Stepford County Railway", path = "SCR/loader.lua" },
	[3647330858] = { name = "Stepford County Railway", path = "SCR/loader.lua" },
	[14502598369] = { name = "El Paso BR", path = "el-paso-br/loader.lua" },
	[2668101271] = { name = "MAXI HUB Farm", url = "https://raw.githubusercontent.com/kotMa0s1n/maxi-hub/master/loader.lua" },
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

local function fetchPath(relPath)
	local bust = cacheBust()
	for _, base in ipairs({ RAW, CDN }) do
		local body = acceptDownload(httpGet(base .. relPath .. "?v=" .. bust))
		if body then
			return body
		end
	end
	return nil
end

local function fetchUrl(url)
	local bust = cacheBust()
	local sep = string.find(url, "?", 1, true) and "&" or "?"
	return acceptDownload(httpGet(url .. sep .. "v=" .. bust))
end

local function runSource(source, chunkName)
	if type(source) ~= "string" then
		return false
	end
	local chunk, err = loadstring(source, chunkName)
	if not chunk then
		return false, err
	end
	chunk()
	return true
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

local function showPicker()
	local HttpService = game:GetService("HttpService")
	local uiSrc = fetchPath("HUB/maxi-hub-ui.lua") or fetchPath("BR/maxi-hub-ui.lua")
	local hubSrc = fetchPath("HUB/hub.lua")
	if not uiSrc or not hubSrc then
		return false
	end
	local uiFn, uiErr = loadstring(uiSrc, "@maxi-hub-ui.lua")
	if not uiFn then
		return false, uiErr
	end
	genv._MaxiHubUILibrary = uiFn()
	local json = fetchPath("HUB/scripts.json")
	if json then
		local ok, data = pcall(function()
			return HttpService:JSONDecode(json)
		end)
		if ok and type(data) == "table" then
			genv.MaxiHubScriptCatalog = data
		end
	end
	return runSource(hubSrc, "@hub.lua")
end

local placeId = tonumber(game.PlaceId) or 0
local gameInfo = GAMES[placeId]
if not gameInfo then
	gameInfo = detectByGui()
end

if gameInfo then
	local source
	if type(gameInfo.url) == "string" then
		source = fetchUrl(gameInfo.url)
	else
		source = fetchPath(gameInfo.path)
	end
	if source then
		runSource(source, "@" .. (gameInfo.path or gameInfo.name or "game"))
		return
	end
end

showPicker()
