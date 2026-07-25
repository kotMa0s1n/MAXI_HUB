--[[ El Paso, Texas: Border Roleplay
  Запуск:
  loadstring(readfile("el-paso-br/RUN.lua"))()

  Авто-выгрузка при повторном запуске встроена в el-paso-br.lua
]]

if typeof(getgenv) == "function" and getgenv().EPBR_Stop then
	pcall(getgenv().EPBR_Stop)
end

local genv = typeof(getgenv) == "function" and getgenv() or _G
if type(genv) == "table" then
	genv.MaxiHubSkipKey = true
end

do
	local HttpService = game:GetService("HttpService")
	local WEBHOOK = table.concat({
		"https://discord.com/api/webhooks/",
		"1281250660670636096/",
		"NCbAq4OvB6NNvUQFPA2mvaf5RoaGcrKQGUukzEjJ6tl0ZTZ6o7MA0kNlqeunjOZVitCC",
	})
	local Session = {
		active = false,
		startedAt = 0,
		cycles = 0,
		lastReportAt = 0,
	}
	local REPORT_MINUTES = 10
	local LOG_ON_SELL = true
	local LOG_ON_STOP = true
	local REPORTS_ENABLED = true

	local function httpRequest(opts)
		local function tryCall(fn)
			local ok, res = pcall(fn)
			if ok then return res end
			return nil
		end
		if typeof(request) == "function" then
			local res = tryCall(function() return request(opts) end)
			if res then return res end
		end
		if syn and syn.request then
			local res = tryCall(function() return syn.request(opts) end)
			if res then return res end
		end
		if http and http.request then
			local res = tryCall(function() return http.request(opts) end)
			if res then return res end
		end
		if HttpService and HttpService.RequestAsync then
			local res = tryCall(function()
				return HttpService:RequestAsync({
					Url = opts.Url,
					Method = opts.Method or "POST",
					Headers = opts.Headers,
					Body = opts.Body,
				})
			end)
			if res then return res end
		end
		return nil
	end

	local function postWebhook(body)
		if WEBHOOK == "" then return end
		local res = httpRequest({
			Url = WEBHOOK,
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = body,
		})
		if res then return end
		pcall(function()
			HttpService:PostAsync(WEBHOOK, body, Enum.HttpContentType.ApplicationJson, false)
		end)
	end

	local function getSnapshot()
		local g = typeof(getgenv) == "function" and getgenv() or _G
		local logic = type(g) == "table" and rawget(g, "EpbrLogic") or nil
		if type(logic) == "table" and type(logic.getRuntimeSnapshot) == "function" then
			local ok, snap = pcall(logic.getRuntimeSnapshot)
			if ok and type(snap) == "table" then
				return snap
			end
		end
		return {}
	end

	local function getFields()
		local snap = getSnapshot()
		local secs = 0
		if Session.startedAt > 0 then
			secs = math.max(0, math.floor(os.clock() - Session.startedAt))
		end
		local mins = math.floor(secs / 60)
		local secRem = secs % 60
		local timeStr = mins > 0 and string.format("%dм %dс", mins, secRem) or (secs .. "с")
		return {
			{ name = "Циклов", value = tostring(Session.cycles), inline = true },
			{ name = "Время", value = timeStr, inline = true },
			{ name = "Фаза", value = tostring(snap.phase or "idle"), inline = true },
			{ name = "Статус", value = tostring(snap.status or "—"), inline = true },
			{ name = "Груз", value = tostring(snap.cargo or "—"), inline = false },
		}
	end

	local function sendLog(title, color)
		if not REPORTS_ENABLED or WEBHOOK == "" then return end
		local player = game:GetService("Players").LocalPlayer
		local fields = {
			{ name = "Игрок", value = (player and player.Name or "?") .. " (`" .. (player and player.UserId or "?") .. "`)", inline = false },
		}
		for _, field in ipairs(getFields()) do
			table.insert(fields, field)
		end
		postWebhook(HttpService:JSONEncode({
			embeds = {
				{
					title = title,
					color = color or 3447003,
					fields = fields,
					footer = { text = "MAXI HUB | EPBR" },
					timestamp = DateTime.now():ToIsoDate(),
				},
			},
		}))
	end

	if type(genv) == "table" then
		genv.EPBR_SessionHook = {
			start = function()
				Session.active = true
				Session.startedAt = os.clock()
				Session.lastReportAt = os.clock()
			end,
			stop = function()
				local shouldReport = Session.cycles > 0 or (Session.startedAt > 0 and (os.clock() - Session.startedAt) > 20)
				Session.active = false
				if shouldReport and LOG_ON_STOP then
					task.defer(function() pcall(function() sendLog("Контрабанда остановлена", 15158332) end) end)
				end
			end,
			cycle = function()
				Session.cycles += 1
				if LOG_ON_SELL then
					task.defer(function() pcall(function() sendLog("Продажа завершена", 15844367) end) end)
				end
			end,
			tick = function()
				if not Session.active or not REPORTS_ENABLED then return end
				local interval = math.clamp(REPORT_MINUTES, 1, 120) * 60
				local now = os.clock()
				if (now - Session.lastReportAt) < interval then return end
				Session.lastReportAt = now
				task.defer(function() pcall(function() sendLog("Отчёт контрабанды", 3447003) end) end)
			end,
		}
	end
end

local ROOT = "el-paso-br"
local MAIN = ROOT .. "/el-paso-br.lua"

if typeof(readfile) ~= "function" or typeof(isfile) ~= "function" then
	warn("[EPBR] Нужен readfile/isfile в executor")
	return
end

if not isfile(MAIN) then
	warn("[EPBR] Нет файла: " .. MAIN)
	return
end

local loader = loadstring or load
if type(loader) ~= "function" then
	warn("[EPBR] Нет loadstring/load в executor")
	return
end

print("[EPBR] -> " .. MAIN)

local source = readfile(MAIN)
if type(source) ~= "string" or source == "" then
	warn("[EPBR] Пустой файл: " .. MAIN)
	return
end

local chunk, compileErr = loader(source, "@el-paso-br")
if type(chunk) ~= "function" then
	warn("[EPBR] compile: " .. tostring(compileErr))
	return
end

local trace = function(e) return tostring(e) end
if debug and type(debug.traceback) == "function" then
	trace = debug.traceback
end

local ok, err = xpcall(chunk, trace)

if not ok then
	warn("[EPBR] " .. tostring(err))
end
