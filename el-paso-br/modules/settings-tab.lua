return function(deps, ctx)
	deps = deps or {}
	local values = deps.values or {}
	local ui = ctx and ctx.ui
	local page = ctx and ctx.pages and ctx.pages.settings
	if not ui or not page then return end

	local function set(key, value)
		if type(deps.onSet) == "function" then
			deps.onSet(key, value)
		end
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

	local scroll = ui.makeScrollPage(page)
	local wrap = ui.makeListWrap(scroll)
	local makeSectionTitle = ui.makeSectionTitle
	local makeSlider = ui.makeSlider

	makeSectionTitle(wrap, tr("sec_tp_foot", "телепорт ног"), 1, "sec_tp_foot")
	local tpBox = Instance.new("Frame")
	tpBox.Size = UDim2.new(1, 0, 0, 292)
	tpBox.BackgroundTransparency = 1
	tpBox.LayoutOrder = 2
	tpBox.Parent = wrap

	makeSlider(tpBox, 0, tr("slider_tp_step", "Длина шага ТП"), 0.05, 1, values.stepSize or 0.20, function(v)
		set("stepSize", v)
	end, "slider_tp_step")
	makeSlider(tpBox, 60, tr("slider_tp_steps_per_frame", "Шагов за кадр"), 1, 12, values.stepsPerFrame or 10, function(v)
		set("stepsPerFrame", v)
	end, "slider_tp_steps_per_frame")
	makeSlider(tpBox, 120, tr("slider_tp_height", "Высота полёта"), 10, 90, values.climbHeight or 45, function(v)
		set("climbHeight", v)
	end, "slider_tp_height")
	makeSlider(tpBox, 180, tr("slider_tp_descend", "Замедление спуска"), 0.2, 1, values.descendStepMult or 0.32, function(v)
		set("descendStepMult", v)
	end, "slider_tp_descend")
	makeSlider(tpBox, 240, tr("slider_tp_hold", "Фиксация на точке (сек)"), 0, 1.2, values.finalHoldSeconds or 0.50, function(v)
		set("finalHoldSeconds", v)
	end, "slider_tp_hold")

	makeSectionTitle(wrap, tr("sec_vehicle_opt", "машина (опц.)"), 3, "sec_vehicle_opt")
	local boostBox = Instance.new("Frame")
	boostBox.Size = UDim2.new(1, 0, 0, 52)
	boostBox.BackgroundTransparency = 1
	boostBox.LayoutOrder = 4
	boostBox.Parent = wrap

	makeSlider(boostBox, 0, tr("slider_boost_max_speed", "Лимит скорости буста"), 20, 500, values.vehicleBoostMaxSpeed or 60, function(v)
		set("vehicleBoostMaxSpeed", v)
	end, "slider_boost_max_speed")

	makeSectionTitle(wrap, tr("sec_fling_orbit", "флинг (орбита)"), 5, "sec_fling_orbit")
	local flingBox = Instance.new("Frame")
	flingBox.Size = UDim2.new(1, 0, 0, 652)
	flingBox.BackgroundTransparency = 1
	flingBox.LayoutOrder = 6
	flingBox.Parent = wrap

	makeSlider(flingBox, 0, tr("slider_fling_orbit_speed", "Fling: скорость вращения"), 2, 60, values.vehicleFlingOrbitSpeed or 20, function(v)
		set("vehicleFlingOrbitSpeed", v)
	end, "slider_fling_orbit_speed")
	makeSlider(flingBox, 60, tr("slider_fling_fore_aft", "Fling: длина вперёд/назад"), 0.5, 12, values.vehicleFlingForeAft or 12, function(v)
		set("vehicleFlingForeAft", v)
	end, "slider_fling_fore_aft")
	makeSlider(flingBox, 120, tr("slider_fling_side", "Fling: ширина орбиты"), 0.5, 12, values.vehicleFlingSide or 3.6, function(v)
		set("vehicleFlingSide", v)
	end, "slider_fling_side")
	makeSlider(flingBox, 180, tr("slider_fling_height", "Fling: высота (ниже/выше)"), -4, 3, values.vehicleFlingHeightOffset or -0.8, function(v)
		set("vehicleFlingHeightOffset", v)
	end, "slider_fling_height")
	makeSlider(flingBox, 240, tr("slider_fling_bob", "Fling: волна по высоте"), 0, 4, values.vehicleFlingBobAmplitude or 3.2, function(v)
		set("vehicleFlingBobAmplitude", v)
	end, "slider_fling_bob")
	makeSlider(flingBox, 300, tr("slider_fling_linear", "Fling: сила толчка"), 40, 900, values.vehicleFlingLinearPower or 900, function(v)
		set("vehicleFlingLinearPower", v)
	end, "slider_fling_linear")
	makeSlider(flingBox, 360, tr("slider_fling_spin", "Fling: сила вращения"), 60, 1800, values.vehicleFlingSpinPower or 1800, function(v)
		set("vehicleFlingSpinPower", v)
	end, "slider_fling_spin")
	makeSlider(flingBox, 420, tr("slider_fling_hold", "Fling: держать цель (сек)"), 0.3, 10, values.vehicleFlingHoldSeconds or 2.4, function(v)
		set("vehicleFlingHoldSeconds", v)
	end, "slider_fling_hold")
	makeSlider(flingBox, 480, tr("slider_fling_regrab", "Fling: пауза между целями"), 0, 0.5, values.vehicleFlingRegrabDelay or 0.2, function(v)
		set("vehicleFlingRegrabDelay", v)
	end, "slider_fling_regrab")
	makeSlider(flingBox, 540, tr("slider_fling_ultra", "Fling: УЛЬТРА множитель"), 0.5, 3.5, values.vehicleFlingUltraMult or 2.0, function(v)
		set("vehicleFlingUltraMult", v)
	end, "slider_fling_ultra")

	local presetRow = Instance.new("Frame")
	presetRow.Size = UDim2.new(1, 0, 0, 32)
	presetRow.Position = UDim2.new(0, 0, 0, 604)
	presetRow.BackgroundTransparency = 1
	presetRow.Parent = flingBox

	local function makePresetBtn(text, x, w, presetName, localeKey)
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0, w, 0, 28)
		b.Position = UDim2.new(0, x, 0, 0)
		b.BackgroundColor3 = ui.COLORS.accentSoft
		b.BorderSizePixel = 0
		b.Font = Enum.Font.GothamSemibold
		b.TextSize = 10
		b.TextColor3 = ui.COLORS.text
		b.Text = text
		b.Parent = presetRow
		if type(deps.registerLocale) == "function" and localeKey then
			deps.registerLocale(b, localeKey)
		end
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 8)
		c.Parent = b
		b.MouseButton1Click:Connect(function()
			set("applyFlingPreset", presetName)
		end)
		return b
	end

	local softBtn = makePresetBtn(tr("btn_fling_soft", "Fling: Мягкий"), 0, 130, "soft", "btn_fling_soft")
	local userBtn = makePresetBtn(tr("btn_fling_user", "Fling: Твой"), 136, 130, "user", "btn_fling_user")
	local ultraBtn = makePresetBtn(tr("btn_fling_ultra", "Fling: Ультра"), 272, 130, "ultra", "btn_fling_ultra")

	bindLocale(function()
		softBtn.Text = tr("btn_fling_soft", "Fling: Мягкий")
		userBtn.Text = tr("btn_fling_user", "Fling: Твой")
		ultraBtn.Text = tr("btn_fling_ultra", "Fling: Ультра")
	end)
end
