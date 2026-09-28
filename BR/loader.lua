-- British Railway | auto-loader (GitHub → workspace/british-railway/)
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/kotMa0s1n/MAXI_HUB/main/BR/loader.lua"))()

local LOADER_VERSION = "1.1"

local BASES = {
	"https://raw.githubusercontent.com/kotMa0s1n/MAXI_HUB/main/BR/",
	"https://cdn.jsdelivr.net/gh/kotMa0s1n/MAXI_HUB@main/BR/",
}

local FILES = {
	"launcher.lua",
	"br-bootstrap.lua",
	"br-logic.lua",
	"br-locale.lua",
	"br-config.lua",
	"maxi-hub-ui.lua",
	"maxi-hub-notify.lua",
}

local WORKSPACE_DIR = "british-railway"
local MIN_BYTES = 64

local genv = typeof(getgenv) == "function" and getgenv() or _G

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

-- Encrypted blobs may fail loadstring here but run fine from workspace — do not require compile.
local function acceptDownload(src)
	src = stripBom(src)
	if type(src) ~= "string" or #src < MIN_BYTES then
		return nil, "too_small"
	end
	local head = src:sub(1, 240):lower()
	if head:find("<!doctype", 1, true) or head:find("<html", 1, true) or head:find("404: not found", 1, true) then
		return nil, "http_error"
	end
	return src, "ok"
end

local function fetchOfficial(fileName)
	local bust = cacheBust()
	local lastUrl, lastWhy = "", "no_response"
	for _, base in ipairs(BASES) do
		lastUrl = base .. fileName .. "?v=" .. bust
		local clean, why = acceptDownload(httpGet(lastUrl))
		lastWhy = why
		if clean then
			return clean
		end
	end
	error("[BR] Не скачался: " .. fileName .. " (loader v" .. LOADER_VERSION .. ", why=" .. lastWhy .. ", url=" .. lastUrl .. ")")
end

if typeof(writefile) ~= "function" or typeof(readfile) ~= "function" or typeof(isfile) ~= "function" then
	error("[BR] Нужен executor с writefile/readfile/isfile")
end

genv.BR_OfficialRaw = BASES[1]
genv.BR_LoaderVersion = LOADER_VERSION
genv.MaxiHubSkipKey = true
genv.MaxiHubGameScript = true


if typeof(makefolder) == "function" then
	pcall(makefolder, WORKSPACE_DIR)
end

for _, name in ipairs(FILES) do
	writefile(WORKSPACE_DIR .. "/" .. name, fetchOfficial(name))
end

local chunk, err = loadstring(readfile(WORKSPACE_DIR .. "/launcher.lua"), "@launcher.lua")
if not chunk then
	error("[BR] launcher compile: " .. tostring(err))
end

chunk()
