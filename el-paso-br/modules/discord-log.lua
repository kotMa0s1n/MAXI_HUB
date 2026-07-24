-- EPBR Discord webhook logging (MAXI HUB style)

local DEFAULT_KEY_WEBHOOK = "https://discord.com/api/webhooks/YOUR_WEBHOOK_HERE"

return function(deps)
	deps = deps or {}
	local HttpService = deps.HttpService or game:GetService("HttpService")
	local Config = deps.Config or {}
	local saveConfig = deps.saveConfig or function() end
	local getPlayer = deps.getLocalPlayer or function()
		return game:GetService("Players").LocalPlayer
	end
	local getSessionFields = deps.getSessionFields
	local BUILD = deps.BUILD or "EPBR"
	local Session = deps.Session

	local lastReportAt = 0

	local function normalizeWebhook(url)
		if type(url) ~= "string" then
			return ""
		end
		return url:gsub("^%s+", ""):gsub("%s+$", "")
	end

	local function getWebhook()
		local user = normalizeWebhook(Config.userDiscordWebhook)
		if user ~= "" then
			return user
		end
		return normalizeWebhook(DEFAULT_KEY_WEBHOOK)
	end

	local function getReportInterval()
		local mins = tonumber(Config.discordReportMinutes) or 10
		return math.clamp(math.floor(mins), 1, 120) * 60
	end

	local function httpRequest(opts)
		local function tryCall(fn)
			local ok, res = pcall(fn)
			if ok then
				return res
			end
			return nil
		end

		if typeof(request) == "function" then
			local res = tryCall(function()
				return request(opts)
			end)
			if res then return res end
		end
		if syn and syn.request then
			local res = tryCall(function()
				return syn.request(opts)
			end)
			if res then return res end
		end
		if http and http.request then
			local res = tryCall(function()
				return http.request(opts)
			end)
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

	local function postDiscordWebhook(webhook, body)
		webhook = normalizeWebhook(webhook)
		if webhook == "" then
			return false, "Webhook пустой"
		end

		local res = httpRequest({
			Url = webhook,
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = body,
		})

		if res then
			local code = res.StatusCode or res.status or res.Status
			if code and tonumber(code) then
				local n = tonumber(code)
				if n >= 200 and n < 300 then
					return true, "Отправлено"
				end
				return false, "HTTP " .. tostring(code)
			end
			if res.Success == true then
				return true, "Отправлено"
			end
			if res.Success == false then
				return false, "HTTP ошибка"
			end
			return true, "Отправлено"
		end

		local ok, err = pcall(function()
			HttpService:PostAsync(webhook, body, Enum.HttpContentType.ApplicationJson, false)
		end)
		if ok then
			return true, "Отправлено"
		end

		return false, tostring(err or "Ошибка отправки"):sub(1, 96)
	end

	local function sendDiscordEmbed(webhook, title, color, extraFields)
		if not webhook or webhook == "" then
			return false, "Webhook пустой"
		end
		local player = getPlayer()
		local playerName = player and player.Name or "?"
		local playerId = player and tostring(player.UserId) or "?"
		local fields = {
			{ name = "Игрок", value = playerName .. " (`" .. playerId .. "`)", inline = false },
		}
		if extraFields then
			for _, field in ipairs(extraFields) do
				table.insert(fields, field)
			end
		end
		local body = HttpService:JSONEncode({
			embeds = {
				{
					title = title,
					color = color or 3447003,
					fields = fields,
					footer = { text = "MAXI HUB | EPBR " .. tostring(BUILD) },
					timestamp = DateTime.now():ToIsoDate(),
				},
			},
		})
		return postDiscordWebhook(webhook, body)
	end

	local function logSession(title, color)
		if Config.discordReportsEnabled == false then
			return false, "Отчёты выключены"
		end
		local webhook = getWebhook()
		if webhook == "" then
			return false, "Webhook пустой"
		end
		local fields = {}
		if type(getSessionFields) == "function" then
			local ok, extra = pcall(getSessionFields)
			if ok and type(extra) == "table" then
				for _, field in ipairs(extra) do
					table.insert(fields, field)
				end
			end
		end
		return sendDiscordEmbed(webhook, title, color, fields)
	end

	local function onCycleComplete()
		if type(Session) ~= "table" then
			return
		end
		Session.cyclesCompleted = (Session.cyclesCompleted or 0) + 1
		Session.sellsCompleted = (Session.sellsCompleted or 0) + 1
		if Config.discordLogOnSell ~= false then
			task.defer(function()
				pcall(function()
					logSession("Продажа завершена", 15844367)
				end)
			end)
		end
	end

	local function onSmuggleStart()
		if type(Session) ~= "table" then
			return
		end
		Session.smugglingActive = true
		Session.startedAt = os.clock()
		lastReportAt = os.clock()
	end

	local function onSmuggleStop()
		if type(Session) ~= "table" then
			return
		end
		local shouldReport = (Session.cyclesCompleted or 0) > 0
			or ((Session.startedAt or 0) > 0 and (os.clock() - Session.startedAt) > 20)
		Session.smugglingActive = false
		if shouldReport and Config.discordLogOnStop ~= false then
			task.defer(function()
				pcall(function()
					logSession("Контрабанда остановлена", 15158332)
				end)
			end)
		end
	end

	local function maybePeriodicReport()
		if type(Session) ~= "table" or not Session.smugglingActive then
			return
		end
		if Config.discordReportsEnabled == false then
			return
		end
		local now = os.clock()
		if (now - lastReportAt) < getReportInterval() then
			return
		end
		lastReportAt = now
		task.defer(function()
			pcall(function()
				logSession("Отчёт контрабанды", 3447003)
			end)
		end)
	end

	local function sendTest()
		return logSession("Тест EPBR", 3447003)
	end

	local function setUserWebhook(url)
		Config.userDiscordWebhook = normalizeWebhook(url)
		saveConfig()
	end

	return {
		getWebhook = getWebhook,
		setUserWebhook = setUserWebhook,
		sendTest = sendTest,
		logSession = logSession,
		onCycleComplete = onCycleComplete,
		onSmuggleStart = onSmuggleStart,
		onSmuggleStop = onSmuggleStop,
		maybePeriodicReport = maybePeriodicReport,
	}
end
