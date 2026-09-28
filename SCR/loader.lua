-- SCR | auto-loader (GitHub → workspace/stepford-county-railway/)
-- Encrypt before push (entry: HttpGet this file + loadstring).
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/kotMa0s1n/MAXI_HUB/main/SCR/loader.lua"))()

local LOADER_VERSION = "1.4"

local BASES = {
	"https://raw.githubusercontent.com/kotMa0s1n/MAXI_HUB/main/SCR/",
	"https://raw.githubusercontent.com/kotMa0s1n/MAXI_HUB/main/scr/",
	"https://cdn.jsdelivr.net/gh/kotMa0s1n/MAXI_HUB@main/SCR/",
	"https://cdn.jsdelivr.net/gh/kotMa0s1n/MAXI_HUB@main/scr/",
}

local FILES = {
	"launcher.lua",
	"scr-bootstrap.lua",
	"scr-logic.lua",
	"scr-locale.lua",
	"scr-config.lua",
	"maxi-hub-ui.lua",
	"maxi-hub-notify.lua",
}

local WORKSPACE_DIR = "stepford-county-railway"
local MIN_BYTES = 64

local function getGenv()
	return typeof(getgenv) == "function" and getgenv() or _G
end

local function cacheBust()
	local t = (typeof(os) == "table" and os.time and os.time()) or 0
	local r = (typeof(math) == "table" and math.random and math.random(1000, 9999)) or 0
	return tostring(t) .. tostring(r)
end

local function httpGet(url)
	local function okBody(body)
		return type(body) == "string" and body ~= ""
	end

	if typeof(game.HttpGet) == "function" then
		local ok, body = pcall(game.HttpGet, url, true)
		if ok and okBody(body) then
			return body
		end
		ok, body = pcall(game.HttpGet, url)
		if ok and okBody(body) then
			return body
		end
	end

	local hs = game:GetService("HttpService")
	if hs and typeof(hs.GetAsync) == "function" then
		local ok, body = pcall(hs.GetAsync, hs, url, true)
		if ok and okBody(body) then
			return body
		end
		ok, body = pcall(hs.GetAsync, hs, url)
		if ok and okBody(body) then
			return body
		end
	end

	if typeof(syn) == "table" and typeof(syn.request) == "function" then
		local ok, res = pcall(syn.request, { Url = url, Method = "GET" })
		if ok and type(res) == "table" and okBody(res.Body) then
			return res.Body
		end
	end

	if typeof(request) == "function" then
		local ok, res = pcall(function()
			return request({ Url = url, Method = "GET" })
		end)
		if ok and type(res) == "table" and okBody(res.Body) then
			return res.Body
		end
	end

	if typeof(http_request) == "function" then
		local ok, res = pcall(http_request, { Url = url, Method = "GET" })
		if ok and type(res) == "table" and okBody(res.Body) then
			return res.Body
		end
	end

	return nil
end

local function stripBom(src)
	if type(src) ~= "string" or src == "" then
		return src
	end
	if src:sub(1, 3) == "\239\187\191" then
		return src:sub(4)
	end
	return src
end

local function looksLikeHttpError(src)
	if type(src) ~= "string" or src == "" then
		return true
	end
	local head = src:sub(1, 240):lower()
	return head:find("<!doctype", 1, true) ~= nil
		or head:find("<html", 1, true) ~= nil
		or head:find("404: not found", 1, true) ~= nil
		or head:find("404 not found", 1, true) ~= nil
end

-- Encrypted blobs may fail loadstring here but run fine from workspace — do not require compile.
local function acceptDownload(fileName, src)
	src = stripBom(src)
	if looksLikeHttpError(src) then
		return false, nil, "http_error"
	end
	if type(src) ~= "string" or #src < MIN_BYTES then
		return false, nil, "too_small"
	end
	return true, src, "ok"
end

local function fetchOfficial(fileName)
	local bust = cacheBust()
	local lastUrl = ""
	local lastLen = 0
	local lastWhy = "no_response"

	for _, base in ipairs(BASES) do
		local url = base .. fileName .. "?v=" .. bust
		lastUrl = url
		local src = httpGet(url)
		lastLen = type(src) == "string" and #src or 0
		local ok, clean, why = acceptDownload(fileName, src)
		lastWhy = why or "reject"
		if ok then
			return clean
		end
	end

	error(
		"[SCR] Не скачался: "
			.. fileName
			.. " (loader v"
			.. LOADER_VERSION
			.. ", why="
			.. lastWhy
			.. ", len="
			.. tostring(lastLen)
			.. ", url="
			.. lastUrl
	)
end

if typeof(writefile) ~= "function" or typeof(readfile) ~= "function" or typeof(isfile) ~= "function" then
	error("[SCR] Нужен executor с writefile/readfile/isfile")
end

local genv = getGenv()
genv.SCR_OfficialRaw = BASES[1]
genv.SCR_LoaderUrl = BASES[1] .. "loader.lua"
genv.SCR_LoaderVersion = LOADER_VERSION
genv.SCR_RepoOnly = true
genv.MaxiHubSkipKey = true
genv.MaxiHubGameScript = true

if typeof(makefolder) == "function" then
	pcall(makefolder, WORKSPACE_DIR)
end

for _, name in ipairs(FILES) do
	writefile(WORKSPACE_DIR .. "/" .. name, fetchOfficial(name))
end

local launcher = readfile(WORKSPACE_DIR .. "/launcher.lua")
local chunk, err = loadstring(launcher, "@launcher.lua")
if not chunk then
	error("[SCR] launcher compile: " .. tostring(err))
end

chunk()
