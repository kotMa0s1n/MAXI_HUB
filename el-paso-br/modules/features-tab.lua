return function(deps, ctx)
	deps = deps or {}
	local values = deps.values or {}
	local ui = ctx and ctx.ui
	local page = ctx and ctx.pages and ctx.pages.features
	if not ui or not page then return end

	local function call(fn, ...)
		if type(fn) == "function" then
			return fn(...)
		end
		return nil
	end

	local function tr(key, fallback)
		local fn = deps.translate
		if type(fn) == "function" then
			local ok, value = pcall(fn, key, fallback)
			if ok and type(value) == "string" and value ~= "" then
				return value
			end
		end
		return fallback or key
	end

	local function bindLocale(fn)
		if type(deps.onLocaleChanged) == "function" and type(fn) == "function" then
			deps.onLocaleChanged(fn)
		end
	end

	local function makeFeatureBox(parent, height, order)
		local box = Instance.new("Frame")
		box.Size = UDim2.new(1, 0, 0, height)
		box.BackgroundTransparency = 1
		box.LayoutOrder = order
		box.Parent = parent
		return box
	end

	local scroll = ui.makeScrollPage(page)
	local wrap = ui.makeListWrap(scroll)
	local makeSectionTitle = ui.makeSectionTitle
	local makeToggle = ui.makeToggle

	makeSectionTitle(wrap, tr("sec_main", "основное"), 1, "sec_main")
	local mainBox = makeFeatureBox(wrap, 176, 2)
	makeToggle(mainBox, 0, tr("toggle_esp_players", "ESP игроков"), values.espEnabled == true, function(v)
		call(deps.onToggleEsp, v)
	end, nil, "toggle_esp_players")
	makeToggle(mainBox, 44, tr("toggle_noclip_foot", "Постоянный noclip (ноги)"), values.noclipFoot == true, function(v)
		call(deps.onToggleNoclipFoot, v)
	end, nil, "toggle_noclip_foot")
	makeToggle(mainBox, 88, tr("toggle_noclip_vehicle", "Постоянный noclip (машина)"), values.noclipVehicles == true, function(v)
		call(deps.onToggleNoclipVehicle, v)
	end, nil, "toggle_noclip_vehicle")
	makeToggle(mainBox, 132, tr("toggle_prompt_zero", "Убрать задержку E (везде)"), values.forcePromptHoldZero ~= false, function(v)
		call(deps.onTogglePromptHoldZero, v)
	end, nil, "toggle_prompt_zero")

	makeSectionTitle(wrap, tr("sec_vehicle_opt", "машина (опц.)"), 3, "sec_vehicle_opt")
	local vehicleBox = makeFeatureBox(wrap, 176, 4)
	makeToggle(vehicleBox, 0, tr("toggle_vehicle_boost", "Буст машины"), values.vehicleBoostEnabled == true, function(v)
		call(deps.onToggleVehicleBoost, v)
	end, nil, "toggle_vehicle_boost")
	makeToggle(vehicleBox, 44, tr("toggle_vehicle_stop_s", "Мгновенный стоп на S"), values.vehicleStopOnS == true, function(v)
		call(deps.onToggleVehicleStopOnS, v)
	end, nil, "toggle_vehicle_stop_s")
	makeToggle(vehicleBox, 88, tr("toggle_vehicle_fling", "Fling по другим машинам (быстро)"), values.vehicleFlingEnabled == true, function(v)
		call(deps.onToggleVehicleFling, v)
	end, nil, "toggle_vehicle_fling")

	local stopBtn = Instance.new("TextButton")
	stopBtn.Size = UDim2.new(1, -8, 0, 30)
	stopBtn.Position = UDim2.new(0, 0, 0, 132)
	stopBtn.BackgroundColor3 = ui.COLORS.accentSoft
	stopBtn.BorderSizePixel = 0
	stopBtn.Font = Enum.Font.GothamSemibold
	stopBtn.TextSize = 10
	stopBtn.TextColor3 = ui.COLORS.text
	stopBtn.Text = tr("btn_vehicle_stop_now", "Остановить машину сейчас")
	stopBtn.Parent = vehicleBox
	local stopCorner = Instance.new("UICorner")
	stopCorner.CornerRadius = UDim.new(0, 8)
	stopCorner.Parent = stopBtn
	stopBtn.MouseButton1Click:Connect(function()
		call(deps.onInstantStopVehicle)
	end)

	makeSectionTitle(wrap, tr("sec_map", "карта"), 5, "sec_map")
	local gateBox = makeFeatureBox(wrap, 44, 6)
	local gateBtn = Instance.new("TextButton")
	gateBtn.Size = UDim2.new(1, -8, 0, 30)
	gateBtn.BackgroundColor3 = ui.COLORS.accentSoft
	gateBtn.BorderSizePixel = 0
	gateBtn.Font = Enum.Font.GothamSemibold
	gateBtn.TextSize = 11
	gateBtn.TextColor3 = ui.COLORS.text
	gateBtn.Parent = gateBox
	local gateCorner = Instance.new("UICorner")
	gateCorner.CornerRadius = UDim.new(0, 8)
	gateCorner.Parent = gateBtn

	local gatesRemoved = values.gatesRemoved == true
	local function paintGateButton()
		gateBtn.Text = gatesRemoved
			and tr("btn_gates_removed", "Гейты удалены")
			or tr("btn_delete_gates", "Удалить гейты НАМЕРТВО")
		gateBtn.BackgroundColor3 = gatesRemoved and ui.COLORS.panel or ui.COLORS.accentSoft
	end
	paintGateButton()

	gateBtn.MouseButton1Click:Connect(function()
		local removed = call(deps.onDeleteGates)
		if removed then
			gatesRemoved = true
			paintGateButton()
		end
	end)

	bindLocale(function()
		stopBtn.Text = tr("btn_vehicle_stop_now", "Остановить машину сейчас")
		paintGateButton()
	end)
end
