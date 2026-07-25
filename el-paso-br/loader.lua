-- EPBR | auto-loader (скачивает с GitHub → workspace/el-paso-br/)
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/kotMa0s1n/MAXI_HUB/main/el-paso-br/loader.lua"))()

local LOADER_VERSION = "1.0"

local BASES = {
	"https://raw.githubusercontent.com/kotMa0s1n/MAXI_HUB/main/el-paso-br/",
	"https://cdn.jsdelivr.net/gh/kotMa0s1n/MAXI_HUB@main/el-paso-br/",
}

local FILES = {
	"RUN.lua",
	"el-paso-br.lua",
}

local WORKSPACE_DIR = "el-paso-br"

local function getGenv()
	return typeof(getgenv) == "function" and getgenv() or _G
end

local function cacheBust()
	local t = (typeof(os) == "table" and os.time and os.time()) or 0
	local r = (typeof(math) == "table" and math.random and math.random(1000, 9999)) or 0
	return tostring(t) .. tostring(r)
end

local function httpGet(url)
	if typeof(game.HttpGet) == "function" then
		local ok, body = pcall(game.HttpGet, url, true)
		if ok and type(body) == "string" and body ~= "" then
			return body
		end
		ok, body = pcall(game.HttpGet, url)
		if ok and type(body) == "string" and body ~= "" then
			return body
		end
	end
	if typeof(request) == "function" then
		local ok, res = pcall(function()
			return request({ Url = url, Method = "GET" })
		end)
		if ok and type(res) == "table" and type(res.Body) == "string" and res.Body ~= "" then
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

local function isValidLua(fileName, src)
	src = stripBom(src)
	if type(src) ~= "string" or src == "" then
		return false
	end
	return loadstring(src, "@" .. fileName) ~= nil, src
end

local function fetchOfficial(fileName)
	local bust = cacheBust()
	for _, base in ipairs(BASES) do
		local url = base .. fileName .. "?v=" .. bust
		local src = httpGet(url)
		local ok, clean = isValidLua(fileName, src)
		if ok then
			return clean
		end
	end
	error("[EPBR] Не скачался: " .. fileName .. " (loader v" .. LOADER_VERSION .. ")")
end

if typeof(writefile) ~= "function" or typeof(readfile) ~= "function" or typeof(isfile) ~= "function" then
	error("[EPBR] Нужен executor с writefile/readfile/isfile")
end

local genv = getGenv()
genv.EPBR_OfficialRaw = BASES[1]
genv.EPBR_LoaderUrl = BASES[1] .. "loader.lua"
genv.EPBR_LoaderVersion = LOADER_VERSION
genv.MaxiHubSkipKey = true

if typeof(makefolder) == "function" then
	pcall(makefolder, WORKSPACE_DIR)
end

for _, name in ipairs(FILES) do
	writefile(WORKSPACE_DIR .. "/" .. name, fetchOfficial(name))
end

local runSrc = readfile(WORKSPACE_DIR .. "/RUN.lua")
local chunk, err = loadstring(runSrc, "@RUN.lua")
if not chunk then
	error("[EPBR] RUN.lua: " .. tostring(err))
end
chunk()
