-- El Paso BR | logic module (bundle -> el-paso-br.lua)

local M = {}

local F = {}

local PLACE_ID = 14502598369
local CONFIG_FILE = "el-paso-br-config.json"
local BUILD = "v0.15.5"

local CARGO_ITEMS = {
	"Hot Dog",
	"Taco",
	"Bloxy Cola",
	"Fake Designer Bag",
	"Fake Watch",
	"Sarsaparilla",
}
local MAX_SELECTED_CARGO_ITEMS = 3
local CARGO_ITEM_SET = {}
for _, itemName in ipairs(CARGO_ITEMS) do
	CARGO_ITEM_SET[itemName] = true
end

local SMUGGLER_KEYWORDS = {
	"smuggl", "contraband", "illegal", "cartel", "runner", "dealer", "traffick", "contrabando",
}
local SMUGGLE_BUY_COUNT_PER_ITEM = 3
local PERF = {
	promptHoldZeroInterval = 1.0,
	promptHoldZeroActionWindow = 4.0,
	boostRetuneInterval = 0.35,
	noclipUpdateIntervalIdle = 0.16,
	noclipUpdateIntervalRoute = 0.07,
	espRefreshInterval = 0.14,
	firstPersonRefreshInterval = 0.08,
	antiCrashFrameSpike = 0.9,
	antiCrashStrikesToStop = 3,
	antiCrashCooldown = 25,
	sellConfirmTimeoutFast = 1.25,
	sellRetryDelayFast = 0.05,
}

local mounted = false
local conns = {}
local threads = {}
local noclipSaved = {}
local teleportBusy = false
local trackedVehicle = nil
local routeNoclipActive = false
local gatePartState = {}
local driveTuneSaved = {}
local smugglePromptSaved = {}
local emergencyStopRequested = false
local firstPersonAutoActive = false
local savedCameraState = nil
local lastNoclipUpdateAt = 0
local lastBoostRetuneAt = 0
local Runtime = {
	lastEspRefreshAt = 0,
	lastFirstPersonApplyAt = 0,
	lastPromptHoldZeroPulseAt = 0,
	promptHoldZeroActiveUntil = 0,
	lastHeartbeatAt = 0,
	heartbeatSpikeStrikes = 0,
	lastAntiCrashAt = 0,
	visiblePrompts = {},
}

local DRIVE_BOOST_MUL_KEYS = {
	Horsepower = true,
	RevAccel = true,
	PeakRPM = true,
	Redline = true,
	FinalDrive = true,
	FDMult = true,
}

local Config = {
	stepSize = 0.20,
	stepsPerFrame = 10,
	climbHeight = 45,
	descendStepMult = 0.32,
	finalHoldSeconds = 0.50,
	smuggleHoldSeconds = 2,
	vehicleHoverWait = 2,
	vehicleTpMode = "air_step", -- air_step | fast | legit
	vehicleStepSize = 0.4,
	footMoveTimeout = 8,
	footTpMode = "elevated", -- step | elevated
	cargoItems = { "Fake Watch" },
	cargoItem = "Fake Watch", -- legacy fallback (single item)
	uiLanguage = "ru",
	teleportMode = "foot",
	vehicleOnlyTeleport = false,
	noclipFoot = false,
	noclipVehicles = false,
	noclipDuringRoute = true,
	gatesRemoved = false,
	espEnabled = false,
	espMaxDistance = 1200,
	vehicleBoostMaxSpeed = 60,
	vehicleBoostEnabled = false,
	vehicleStopOnS = false,
	vehicleFlingEnabled = false,
	vehicleFlingHoldSeconds = 2.4,
	vehicleFlingRegrabDelay = 0.2,
	vehicleFlingOrbitSpeed = 20,
	vehicleFlingForeAft = 12,
	vehicleFlingSide = 3.6,
	vehicleFlingHeightOffset = -0.8,
	vehicleFlingBobAmplitude = 3.2,
	vehicleFlingLinearPower = 900,
	vehicleFlingSpinPower = 1800,
	vehicleFlingUltraMult = 2.0,
	forcePromptHoldZero = true,
	autoSmuggle = false,
	autoWork = false,
	waypoints = {
		pickup = nil,
		dropoff = nil,
		footZone = nil,
		carSeat = nil,
		carPickup = nil,
		carDropoff = nil,
	},
}

local State = { status = "готов", phase = "idle" }

local ctxRef = {}
local statusValueLabel
local phaseValueLabel
local pickupValueLabel
local dropoffValueLabel
local footZoneValueLabel
local cargoValueLabel

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local moduleCache = {}

function F.getModulePaths(fileName)
	local paths = {}
	local genv = typeof(getgenv) == "function" and getgenv() or _G
	local customRoot = genv and genv.EPBRLocalRoot
	if type(customRoot) == "string" and customRoot ~= "" then
		table.insert(paths, customRoot .. "/" .. fileName)
	end
	table.insert(paths, "el-paso-br/" .. fileName)
	table.insert(paths, fileName)
	return paths
end

function F.loadOptionalModule(fileName)
	if moduleCache[fileName] ~= nil then
		return moduleCache[fileName] or nil
	end
	local loader = loadstring or load
	if type(loader) ~= "function" then
		moduleCache[fileName] = false
		return nil
	end

	local embedded = rawget(_G, "__EPBR_EMBEDDED")
	if type(embedded) == "table" then
		local src = embedded[fileName]
		if type(src) == "string" and src ~= "" then
			local chunk = loader(src, "@" .. fileName)
			if chunk then
				local okRun, mod = pcall(chunk)
				if okRun and type(mod) == "function" then
					moduleCache[fileName] = mod
					return mod
				end
			end
		end
	end

	if typeof(readfile) ~= "function" or typeof(isfile) ~= "function" then
		moduleCache[fileName] = false
		return nil
	end

	for _, path in ipairs(F.getModulePaths(fileName)) do
		local okFile, exists = pcall(isfile, path)
		if okFile and exists then
			local okRead, src = pcall(readfile, path)
			if okRead and type(src) == "string" and src ~= "" then
				local chunk, cerr = loader(src, "@" .. path)
				if chunk then
					local okRun, mod = pcall(chunk)
					if okRun and type(mod) == "function" then
						moduleCache[fileName] = mod
						return mod
					end
				else
					moduleCache[fileName] = false
					return nil
				end
			end
		end
	end

	moduleCache[fileName] = false
	return nil
end

function F.trackConn(c)
	if c then table.insert(conns, c) end
	return c
end

function F.stopThread(name) threads[name] = false end

function F.startThread(name, fn)
	threads[name] = true
	task.spawn(fn)
end

function F.notify(_msg) end

function F.isActionCancelled()
	return emergencyStopRequested or not mounted
end

function F.waitInterruptible(seconds)
	local untilTime = os.clock() + math.max(0, seconds or 0)
	while os.clock() < untilTime do
		if F.isActionCancelled() then
			return false
		end
		task.wait(0.03)
	end
	return true
end

function F.clearEmergencyStop()
	emergencyStopRequested = false
end

function F.getLocalPlayer() return ctxRef.player or Players.LocalPlayer end

function F.getCharacter()
	local lp = F.getLocalPlayer()
	return lp and lp.Character
end

function F.getHumanoid(char)
	char = char or F.getCharacter()
	return char and char:FindFirstChildOfClass("Humanoid")
end

function F.applyFirstPersonCamera()
	local lp = F.getLocalPlayer()
	if not lp then return end
	local cam = Workspace.CurrentCamera
	if not savedCameraState then
		savedCameraState = {
			cameraMode = lp.CameraMode,
			minZoom = lp.CameraMinZoomDistance,
			maxZoom = lp.CameraMaxZoomDistance,
			cameraType = cam and cam.CameraType or nil,
		}
	end

	pcall(function()
		lp.CameraMode = Enum.CameraMode.LockFirstPerson
		lp.CameraMinZoomDistance = 0.5
		lp.CameraMaxZoomDistance = 0.5
	end)

	local hum = F.getHumanoid()
	if cam then
		pcall(function()
			cam.CameraType = Enum.CameraType.Custom
			if hum then cam.CameraSubject = hum end
		end)
	end
end

function F.restoreCameraState()
	local saved = savedCameraState
	if not saved then return end
	local lp = F.getLocalPlayer()
	if lp then
		pcall(function()
			if saved.cameraMode ~= nil then lp.CameraMode = saved.cameraMode end
			if saved.minZoom ~= nil then lp.CameraMinZoomDistance = saved.minZoom end
			if saved.maxZoom ~= nil then lp.CameraMaxZoomDistance = saved.maxZoom end
		end)
	end
	local cam = Workspace.CurrentCamera
	if cam and saved.cameraType ~= nil then
		pcall(function() cam.CameraType = saved.cameraType end)
	end
	savedCameraState = nil
end

function F.setAutoSmuggleFirstPerson(on)
	firstPersonAutoActive = on == true
	if firstPersonAutoActive then
		F.applyFirstPersonCamera()
	else
		F.restoreCameraState()
	end
end

function F.getRootPart(char)
	char = char or F.getCharacter()
	if not char then return nil end
	return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChildWhichIsA("BasePart")
end

function F.normalizeLang(lang)
	if type(lang) == "string" and lang:lower() == "en" then
		return "en"
	end
	return "ru"
end

function F.trRuntime(key, fallback)
	local mod = F.loadOptionalModule("modules/locale.lua")
	if type(mod) == "table" and type(mod.t) == "function" then
		local ok, text = pcall(mod.t, F.normalizeLang(Config.uiLanguage), key, fallback)
		if ok and type(text) == "string" and text ~= "" then
			return text
		end
	end
	return fallback or key
end

local STATUS_TEXT_TO_KEY = {
	["готов"] = "status_ready",
}

function F.localizeStatusText(text)
	if type(text) ~= "string" then
		return text
	end
	local key = STATUS_TEXT_TO_KEY[text]
	if key then
		return F.trRuntime(key, text)
	end
	return text
end

function F.setStatus(text)
	State.status = text
	if statusValueLabel and statusValueLabel.Parent then
		statusValueLabel.Text = F.localizeStatusText(text)
	end
end

function F.setPhase(text)
	State.phase = text
	if phaseValueLabel and phaseValueLabel.Parent then phaseValueLabel.Text = text end
end

function F.vecToTable(v) return { x = v.X, y = v.Y, z = v.Z } end

function F.tableToVec3(t)
	if not t or type(t) ~= "table" then return nil end
	local x = t.x or t.X
	local y = t.y or t.Y
	local z = t.z or t.Z
	if x == nil or y == nil or z == nil then return nil end
	return Vector3.new(x, y, z)
end

function F.isValidCargoItemName(name)
	return type(name) == "string" and CARGO_ITEM_SET[name] == true
end

function F.sanitizeCargoSelection(rawSelection)
	local out, seen = {}, {}
	if type(rawSelection) == "table" then
		for _, itemName in ipairs(rawSelection) do
			if F.isValidCargoItemName(itemName) and not seen[itemName] then
				table.insert(out, itemName)
				seen[itemName] = true
				if #out >= MAX_SELECTED_CARGO_ITEMS then
					break
				end
			end
		end
	end
	if #out == 0 then
		local fallback = F.isValidCargoItemName(Config.cargoItem) and Config.cargoItem or CARGO_ITEMS[1]
		table.insert(out, fallback)
	end
	return out
end

function F.getSelectedCargoItems()
	local items = F.sanitizeCargoSelection(Config.cargoItems)
	Config.cargoItems = items
	Config.cargoItem = items[1]
	return items
end

function F.saveConfig()
	if typeof(writefile) ~= "function" then return end
	local ok, json = pcall(function()
		return game:GetService("HttpService"):JSONEncode(Config)
	end)
	if ok then writefile(CONFIG_FILE, json) end
end

function F.loadConfig()
	if typeof(readfile) ~= "function" or typeof(isfile) ~= "function" then return end
	if not isfile(CONFIG_FILE) then return end
	local ok, data = pcall(function()
		return game:GetService("HttpService"):JSONDecode(readfile(CONFIG_FILE))
	end)
	if not ok or type(data) ~= "table" then return end
	for k, v in pairs(data) do Config[k] = v end
	if type(Config.waypoints) ~= "table" then
		Config.waypoints = { pickup = nil, dropoff = nil, footZone = nil, carSeat = nil, carPickup = nil, carDropoff = nil }
	end
	if Config.waypoints.carPickup == nil then Config.waypoints.carPickup = nil end
	if Config.waypoints.carDropoff == nil then Config.waypoints.carDropoff = nil end
	Config.cargoItems = F.sanitizeCargoSelection(Config.cargoItems)
	Config.cargoItem = Config.cargoItems[1]
	if Config.footTpMode ~= "step" and Config.footTpMode ~= "elevated" then
		Config.footTpMode = "elevated"
	end
	if type(Config.smuggleHoldSeconds) ~= "number" then Config.smuggleHoldSeconds = 2 end
	if type(Config.descendStepMult) ~= "number" then Config.descendStepMult = 0.32 end
	if type(Config.finalHoldSeconds) ~= "number" then Config.finalHoldSeconds = 0.50 end
	if type(Config.vehicleBoostMaxSpeed) ~= "number" then
		local legacyMult = tonumber(Config.vehicleSpeedMult)
		if legacyMult and legacyMult > 0 then
			Config.vehicleBoostMaxSpeed = math.max(20, math.floor((legacyMult * 25) + 0.5))
		else
			Config.vehicleBoostMaxSpeed = 60
		end
	end
	Config.vehicleBoostMaxSpeed = math.clamp(Config.vehicleBoostMaxSpeed, 20, 500)
	if type(Config.vehicleFlingEnabled) ~= "boolean" then Config.vehicleFlingEnabled = false end
	if type(Config.vehicleFlingHoldSeconds) ~= "number" then Config.vehicleFlingHoldSeconds = 2.4 end
	if type(Config.vehicleFlingRegrabDelay) ~= "number" then Config.vehicleFlingRegrabDelay = 0.2 end
	if type(Config.vehicleFlingOrbitSpeed) ~= "number" then Config.vehicleFlingOrbitSpeed = 20 end
	if type(Config.vehicleFlingForeAft) ~= "number" then Config.vehicleFlingForeAft = 12 end
	if type(Config.vehicleFlingSide) ~= "number" then Config.vehicleFlingSide = 3.6 end
	if type(Config.vehicleFlingHeightOffset) ~= "number" then Config.vehicleFlingHeightOffset = -0.8 end
	if type(Config.vehicleFlingBobAmplitude) ~= "number" then Config.vehicleFlingBobAmplitude = 3.2 end
	if type(Config.vehicleFlingLinearPower) ~= "number" then Config.vehicleFlingLinearPower = 900 end
	if type(Config.vehicleFlingSpinPower) ~= "number" then Config.vehicleFlingSpinPower = 1800 end
	if type(Config.vehicleFlingUltraMult) ~= "number" then Config.vehicleFlingUltraMult = 2.0 end
	Config.vehicleFlingHoldSeconds = math.clamp(Config.vehicleFlingHoldSeconds, 0.3, 10)
	Config.vehicleFlingRegrabDelay = math.clamp(Config.vehicleFlingRegrabDelay, 0, 0.5)
	Config.vehicleFlingOrbitSpeed = math.clamp(Config.vehicleFlingOrbitSpeed, 2, 60)
	Config.vehicleFlingForeAft = math.clamp(Config.vehicleFlingForeAft, 0.5, 12)
	Config.vehicleFlingSide = math.clamp(Config.vehicleFlingSide, 0.5, 12)
	Config.vehicleFlingHeightOffset = math.clamp(Config.vehicleFlingHeightOffset, -4, 3)
	Config.vehicleFlingBobAmplitude = math.clamp(Config.vehicleFlingBobAmplitude, 0, 4)
	Config.vehicleFlingLinearPower = math.clamp(Config.vehicleFlingLinearPower, 40, 900)
	Config.vehicleFlingSpinPower = math.clamp(Config.vehicleFlingSpinPower, 60, 1800)
	Config.vehicleFlingUltraMult = math.clamp(Config.vehicleFlingUltraMult, 0.5, 3.5)
	Config.vehicleSpeedMult = nil
	if type(Config.forcePromptHoldZero) ~= "boolean" then Config.forcePromptHoldZero = true end
	if Config.vehicleTpMode == "fast" then
		Config.vehicleTpMode = "air_step"
	end
	if Config.vehicleTpMode ~= "air_step" and Config.vehicleTpMode ~= "legit" and Config.vehicleTpMode ~= "fast" then
		Config.vehicleTpMode = "air_step"
	end
	if type(Config.climbHeight) ~= "number" then Config.climbHeight = 45 end
	if type(Config.stepSize) ~= "number" then Config.stepSize = 0.20 end
	if type(Config.stepsPerFrame) ~= "number" then Config.stepsPerFrame = 10 end
	Config.stepsPerFrame = math.clamp(math.floor(Config.stepsPerFrame + 0.5), 1, 12)
end

function F.hookSession(evt)
	local g = typeof(getgenv) == "function" and getgenv() or _G
	if type(g) ~= "table" then return end
	local hook = rawget(g, "EPBR_SessionHook")
	if type(hook) ~= "table" then return end
	local fn = hook[evt]
	if type(fn) == "function" then
		pcall(fn)
	end
end

function F.refreshWaypointLabels()
	local notSetText = F.trRuntime("value_not_set", "не задан")
	if pickupValueLabel and pickupValueLabel.Parent then
		local wp = Config.waypoints.pickup
		pickupValueLabel.Text = wp and string.format("%.0f, %.0f, %.0f", wp.x, wp.y, wp.z) or notSetText
	end
	if dropoffValueLabel and dropoffValueLabel.Parent then
		local wp = Config.waypoints.dropoff
		dropoffValueLabel.Text = wp and string.format("%.0f, %.0f, %.0f", wp.x, wp.y, wp.z) or notSetText
	end
	if footZoneValueLabel and footZoneValueLabel.Parent then
		local wp = Config.waypoints.footZone
		footZoneValueLabel.Text = wp and string.format("%.0f, %.0f, %.0f", wp.x, wp.y, wp.z) or notSetText
	end
	if cargoValueLabel and cargoValueLabel.Parent then
		local cargoText = table.concat(F.getSelectedCargoItems(), ", ")
		if #cargoText > 34 then
			cargoText = cargoText:sub(1, 31) .. "..."
		end
		cargoValueLabel.Text = cargoText
	end
end

function F.getVehicle()
	local hum = F.getHumanoid()
	if not hum or not hum.SeatPart or not hum.SeatPart:IsA("VehicleSeat") then
		return nil, nil
	end
	local seat = hum.SeatPart
	return seat:FindFirstAncestorOfClass("Model"), seat
end

function F.trackVehicleFromSeat(seat)
	if seat and seat:IsA("VehicleSeat") then
		local model = seat:FindFirstAncestorOfClass("Model")
		if model then trackedVehicle = model end
	end
end

function F.findMyVehicle()
	if trackedVehicle and trackedVehicle.Parent then
		local seat = trackedVehicle:FindFirstChild("DriveSeat", true)
		if seat and seat:IsA("VehicleSeat") then return trackedVehicle, seat end
	end

	local pickup = F.tableToVec3(Config.waypoints.carPickup) or F.tableToVec3(Config.waypoints.pickup)
	local root = F.getRootPart()
	local refPos = pickup or (root and root.Position)
	if not refPos then return nil, nil end

	local bestModel, bestSeat, bestDist
	local stack = { Workspace }
	local processed = 0
	while #stack > 0 and not F.isActionCancelled() do
		local inst = stack[#stack]
		stack[#stack] = nil
		if inst:IsA("VehicleSeat") and inst.Name == "DriveSeat" then
			local model = inst:FindFirstAncestorOfClass("Model")
			if model then
				local dist = (inst.Position - refPos).Magnitude
				if dist <= 200 and (not bestDist or dist < bestDist) then
					bestModel = model
					bestSeat = inst
					bestDist = dist
				end
			end
		end
		local children = inst:GetChildren()
		for i = 1, #children do
			stack[#stack + 1] = children[i]
		end
		processed += 1
		if processed % 220 == 0 then
			task.wait()
		end
	end
	if bestModel then trackedVehicle = bestModel end
	return bestModel, bestSeat
end

function F.getTeleportSubject(forceMode)
	local mode = forceMode or Config.teleportMode or "vehicle"
	if Config.vehicleOnlyTeleport and not forceMode then
		mode = "vehicle"
	end

	if mode == "vehicle" then
		local vehicle, seat = F.getVehicle()
		if vehicle then return vehicle, seat, "vehicle" end
		F.setStatus("садись в машину")
		F.notify("ТП машиной — сядь в DriveSeat")
		return nil, nil, nil
	end

	local char = F.getCharacter()
	local root = F.getRootPart(char)
	if not root then
		F.setStatus("нет персонажа")
		return nil, nil, nil
	end
	return root, root, "foot"
end

function F.zeroVelocities(inst)
	if inst:IsA("BasePart") then
		inst.AssemblyLinearVelocity = Vector3.zero
		inst.AssemblyAngularVelocity = Vector3.zero
		return
	end
	for _, part in ipairs(inst:GetDescendants()) do
		if part:IsA("BasePart") then
			part.AssemblyLinearVelocity = Vector3.zero
			part.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

function F.getSubjectPivot(subject, kind, anchor)
	if kind == "vehicle" then return subject:GetPivot() end
	return anchor.CFrame
end

function F.setSubjectPivot(subject, kind, cf)
	F.zeroVelocities(subject)
	if kind == "vehicle" then subject:PivotTo(cf) else subject.CFrame = cf end
end

function F.restoreNoclip(root)
	if not root then return end
	local saved = noclipSaved[root]
	if saved then
		for part, props in pairs(saved) do
			if part.Parent then part.CanCollide = props.CanCollide end
		end
		noclipSaved[root] = nil
	end
end

function F.hardRestoreCollision(root)
	if not root then return end
	noclipSaved[root] = nil
	for _, part in ipairs(root:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = true
		end
	end
end

function F.restoreCharacterCollision(char)
	if not char then return end
	F.restoreNoclip(char)
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
		end
	end
end

function F.setVehicleAnchored(vehicle, anchored)
	if not vehicle then return end
	for _, part in ipairs(vehicle:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = anchored
		end
	end
end

function F.liftVehicleIfUnderground(vehicle)
	if not vehicle then return end
	local pivot = vehicle:GetPivot()
	local char = F.getCharacter()
	local filter = { vehicle }
	if char then table.insert(filter, char) end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = filter
	local hit = Workspace:Raycast(pivot.Position + Vector3.new(0, 8, 0), Vector3.new(0, -500, 0), params)
	if not hit then return end
	local minY = hit.Position.Y + 3.5
	if pivot.Position.Y < minY - 0.5 then
		local _, yaw, _ = pivot:ToEulerAnglesYXZ()
		F.setVehicleAnchored(vehicle, true)
		vehicle:PivotTo(CFrame.new(pivot.Position.X, minY, pivot.Position.Z) * CFrame.Angles(0, yaw, 0))
		F.zeroVelocities(vehicle)
		F.setVehicleAnchored(vehicle, false)
		F.zeroVelocities(vehicle)
	end
end

function F.stabilizeVehicle(vehicle, frames)
	for _ = 1, (frames or 5) do
		if F.isActionCancelled() or not vehicle or not vehicle.Parent then break end
		F.zeroVelocities(vehicle)
		RunService.Heartbeat:Wait()
	end
end

function F.resetVehicleDriveState(vehicle)
	local tune = nil
	if type(F.getVehicleDriveTune) == "function" then
		tune = F.getVehicleDriveTune(vehicle)
	end
	if tune then
		pcall(function()
			if tune.RPM ~= nil then tune.RPM = tune.IdleRPM or 800 end
			if tune.Throttle ~= nil then tune.Throttle = 0 end
			if tune.Gear ~= nil then tune.Gear = 0 end
			if tune.Velocity ~= nil then tune.Velocity = 0 end
		end)
	end
	local seat = vehicle and vehicle:FindFirstChild("DriveSeat", true)
	if seat and seat:IsA("VehicleSeat") then
		pcall(function()
			seat.ThrottleFloat = 0
			seat.SteerFloat = 0
		end)
	end
end

function F.raycastGroundY(x, z, hintY, excludeList)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = excludeList or {}
	local originY = (hintY or 0) + 120
	local hit = Workspace:Raycast(Vector3.new(x, originY, z), Vector3.new(0, -400, 0), params)
	if hit then return hit.Position.Y + 3.5 end
	return hintY or 0
end

function F.resolveVehicleDestPos(targetPos, vehicle, useSavedY)
	local char = F.getCharacter()
	local exclude = { vehicle }
	if char then table.insert(exclude, char) end
	local groundY = F.raycastGroundY(targetPos.X, targetPos.Z, targetPos.Y, exclude)
	local y = groundY
	if useSavedY then
		y = targetPos.Y
	elseif math.abs(targetPos.Y - groundY) <= 10 then
		y = targetPos.Y
	end
	return Vector3.new(targetPos.X, y, targetPos.Z)
end

function F.buildVehicleDestCF(vehicle, destPos)
	local _, yaw, _ = vehicle:GetPivot():ToEulerAnglesYXZ()
	return CFrame.new(destPos) * CFrame.Angles(0, yaw, 0)
end

function F.safeVehiclePivot(vehicle, destCF)
	if not vehicle then return false end
	F.resetVehicleDriveState(vehicle)
	F.setVehicleAnchored(vehicle, true)
	F.zeroVelocities(vehicle)
	vehicle:PivotTo(destCF)
	F.zeroVelocities(vehicle)
	F.stabilizeVehicle(vehicle, 4)
	F.setVehicleAnchored(vehicle, false)
	F.stabilizeVehicle(vehicle, 12)
	F.liftVehicleIfUnderground(vehicle)
	F.resetVehicleDriveState(vehicle)
	F.stabilizeVehicle(vehicle, 4)
	return true
end

function F.getVehicleDriveTune(vehicle)
	if not vehicle then return nil end
	local drive = vehicle:FindFirstChild("Drive", true)
	if drive and drive:IsA("ModuleScript") then
		local ok, tune = pcall(require, drive)
		if ok and type(tune) == "table" then return tune, drive end
	end
	return nil
end

function F.instantStopVehicle()
	local vehicle = F.getVehicle() or trackedVehicle
	if not vehicle then return end
	F.resetVehicleDriveState(vehicle)
	F.setVehicleAnchored(vehicle, true)
	F.zeroVelocities(vehicle)
	F.stabilizeVehicle(vehicle, 3)
	F.setVehicleAnchored(vehicle, false)
	F.stabilizeVehicle(vehicle, 6)
	F.liftVehicleIfUnderground(vehicle)
end

function F.getDriveSeatFromVehicle(vehicle)
	if not vehicle then return nil end
	local seat = vehicle:FindFirstChild("DriveSeat", true)
	if seat and seat:IsA("VehicleSeat") then
		return seat
	end
	return vehicle:FindFirstChildWhichIsA("VehicleSeat", true)
end

function F.getSeatEnterPrompt(seat)
	if not seat then return nil end
	local attachment = seat:FindFirstChild("PromptAttachment") or seat:FindFirstChildWhichIsA("Attachment")
	local prompt = attachment and attachment:FindFirstChildWhichIsA("ProximityPrompt")
	if prompt then return prompt end
	return seat:FindFirstChildWhichIsA("ProximityPrompt", true)
end

function F.setVehicleFrozenState(vehicle, frozen)
	if not vehicle then return false end
	F.resetVehicleDriveState(vehicle)
	F.setVehicleAnchored(vehicle, frozen == true)
	F.zeroVelocities(vehicle)
	return true
end

function F.vehicleInstantTeleportToPos(vehicle, targetPos, keepFrozen)
	if not vehicle or not targetPos then return false end
	F.resetVehicleDriveState(vehicle)
	F.setVehicleAnchored(vehicle, true)
	vehicle:PivotTo(F.buildVehicleDestCF(vehicle, Vector3.new(targetPos.X, targetPos.Y, targetPos.Z)))
	F.zeroVelocities(vehicle)
	if not keepFrozen then
		F.setVehicleAnchored(vehicle, false)
	end
	return true
end

function F.forceExitVehicleNow()
	local hum = F.getHumanoid()
	if not hum then return false end
	if not hum.SeatPart then return true end
	F.exitVehicle()
	local deadline = os.clock() + 1.8
	while hum.SeatPart and os.clock() < deadline and not F.isActionCancelled() do
		hum.Sit = false
		pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
		task.wait(0.05)
	end
	return hum.SeatPart == nil
end

function F.tryEnterVehicleSeat(vehicle, seat, timeout)
	vehicle = vehicle or F.getVehicle() or trackedVehicle
	seat = seat or F.getDriveSeatFromVehicle(vehicle)
	local hum = F.getHumanoid()
	local root = F.getFootRoot()
	if not vehicle or not seat or not hum or not root then return false end

	local deadline = os.clock() + math.max(0.5, timeout or 3)
	while os.clock() < deadline and not F.isActionCancelled() do
		if hum.SeatPart == seat then
			F.trackVehicleFromSeat(seat)
			return true
		end

		local seatCf = seat.CFrame
		local approachPos = seatCf.Position + seatCf.LookVector * -2.2 + Vector3.new(0, 1.7, 0)
		root.CFrame = CFrame.new(approachPos, seatCf.Position + Vector3.new(0, 1.2, 0))
		F.zeroVelocities(root)

		local prompt = F.getSeatEnterPrompt(seat)
		if prompt then
			if typeof(fireproximityprompt) == "function" then
				pcall(function() fireproximityprompt(prompt, 0) end)
			else
				pcall(function()
					prompt:InputHoldBegin()
					task.wait(0.05)
					prompt:InputHoldEnd()
				end)
			end
		end

		if typeof(firetouchinterest) == "function" then
			pcall(function()
				firetouchinterest(root, seat, 0)
				firetouchinterest(root, seat, 1)
			end)
		end

		pcall(function() hum.Jump = true end)
		task.wait(0.06)
	end

	return hum.SeatPart == seat
end

function F.isVehicleFlingTarget(model)
	if not model or not model:IsA("Model") then return false end
	local seat = F.getDriveSeatFromVehicle(model)
	if not seat then return false end
	local body = model:FindFirstChild("Body")
	if body and (body:IsA("BasePart") or body:FindFirstChildWhichIsA("BasePart", true)) then
		return true
	end
	return model:FindFirstChildWhichIsA("BasePart", true) ~= nil
end

function F.getVehicleBodyPos(model)
	if not model then return nil end
	local body = model:FindFirstChild("Body")
	return F.getPartPosition(body or model)
end

function F.getVehicleFlingTargets(myVehicle)
	local targets = {}
	for _, inst in ipairs(Workspace:GetChildren()) do
		if inst ~= myVehicle and F.isVehicleFlingTarget(inst) then
			table.insert(targets, inst)
		end
	end
	table.sort(targets, function(a, b)
		local ap = F.getVehicleBodyPos(a)
		local bp = F.getVehicleBodyPos(b)
		local myPos = F.getVehicleBodyPos(myVehicle) or Vector3.zero
		local ad = ap and (ap - myPos).Magnitude or math.huge
		local bd = bp and (bp - myPos).Magnitude or math.huge
		return ad < bd
	end)
	return targets
end

function F.slamVehicleIntoTarget(myVehicle, targetVehicle, holdSeconds)
	if not myVehicle or not targetVehicle then return false end
	local targetPos = F.getVehicleBodyPos(targetVehicle)
	if not targetPos then return false end
	local startTime = os.clock()
	local _, baseYaw, _ = myVehicle:GetPivot():ToEulerAnglesYXZ()
	local holdUntil = os.clock() + math.max(0.4, holdSeconds or 1.8)
	local ultraMult = math.clamp(tonumber(Config.vehicleFlingUltraMult) or 1.0, 0.5, 3.5)
	local orbitSpeed = math.clamp(tonumber(Config.vehicleFlingOrbitSpeed) or 8.4, 2, 60) * ultraMult
	local foreAft = math.clamp(tonumber(Config.vehicleFlingForeAft) or 2.35, 0.5, 12)
	local side = math.clamp(tonumber(Config.vehicleFlingSide) or 2.35, 0.5, 12)
	local heightOffset = math.clamp(tonumber(Config.vehicleFlingHeightOffset) or -0.45, -4, 3)
	local bobAmp = math.clamp(tonumber(Config.vehicleFlingBobAmplitude) or 0.42, 0, 4)
	local linearPower = math.clamp(tonumber(Config.vehicleFlingLinearPower) or 165, 40, 900) * ultraMult
	local spinPower = math.clamp(tonumber(Config.vehicleFlingSpinPower) or 250, 60, 1800) * ultraMult
	local tiltPower = math.clamp(spinPower * 0.22, 14, 420)
	local yawBobDeg = math.clamp(spinPower * 0.08, 6, 95)
	local yKickBase = math.clamp(linearPower * 0.065, 3, 75)
	local yKickBob = math.clamp(linearPower * 0.18, 8, 130)

	F.resetVehicleDriveState(myVehicle)
	F.setVehicleAnchored(myVehicle, false)
	while mounted and not F.isActionCancelled() and threads.vehicleFling and Config.vehicleFlingEnabled and os.clock() < holdUntil do
		local center = F.getVehicleBodyPos(targetVehicle) or targetPos
		local t = os.clock() - startTime
		local orbit = t * orbitSpeed
		local sx = math.cos(orbit)
		local sz = math.sin(orbit)
		local bob = math.sin(t * (6.2 * math.min(2.2, 0.9 + (ultraMult * 0.4))))
		local jitterPos = center + Vector3.new(sx * side, heightOffset + bob * bobAmp, sz * foreAft)
		local yaw = baseYaw + orbit + math.rad(bob * yawBobDeg)
		myVehicle:PivotTo(CFrame.new(jitterPos) * CFrame.Angles(0, yaw, 0))

		local lin = Vector3.new(sx * linearPower, yKickBase + math.abs(bob) * yKickBob, sz * linearPower)
		local ang = Vector3.new(tiltPower * bob, spinPower + bob * (spinPower * 0.55), -tiltPower * bob)
		lin = F.clampVelocityVec(lin, math.min(linearPower, 220), 95)
		ang = Vector3.new(
			math.clamp(ang.X, -140, 140),
			math.clamp(ang.Y, -220, 220),
			math.clamp(ang.Z, -140, 140)
		)
		for _, part in ipairs(myVehicle:GetDescendants()) do
			if part:IsA("BasePart") then
				part.AssemblyLinearVelocity = lin
				part.AssemblyAngularVelocity = ang
			end
		end
		RunService.Heartbeat:Wait()
	end
	F.zeroVelocities(myVehicle)
	return true
end

function F.runVehicleFlingLoop()
	F.stopThread("vehicleFling")
	F.startThread("vehicleFling", function()
		while mounted and threads.vehicleFling and Config.vehicleFlingEnabled and not emergencyStopRequested do
			local myVehicle = F.getVehicle()
			if not myVehicle then
				F.setStatus("fling: сядь в машину")
				break
			end
			trackedVehicle = myVehicle
			local targets = F.getVehicleFlingTargets(myVehicle)
			if #targets == 0 then
				F.setStatus("fling: целей нет")
				if not F.waitInterruptible(0.16) then break end
			else
				for _, target in ipairs(targets) do
					if not mounted or not threads.vehicleFling or not Config.vehicleFlingEnabled or emergencyStopRequested then
						break
					end
					F.setPhase("fling")
					F.setStatus("fling -> " .. tostring(target.Name))
					F.slamVehicleIntoTarget(myVehicle, target, Config.vehicleFlingHoldSeconds or 1.8)
					if not F.waitInterruptible(Config.vehicleFlingRegrabDelay or 0.03) then
						break
					end
				end
			end
		end
		F.stopThread("vehicleFling")
		if Config.vehicleFlingEnabled then
			Config.vehicleFlingEnabled = false
			F.saveConfig()
		end
		F.setPhase("idle")
	end)
end

function F.setVehicleFlingEnabled(v)
	if not v then
		Config.vehicleFlingEnabled = false
		F.stopThread("vehicleFling")
		F.setStatus("fling: стоп")
		F.setPhase("idle")
		F.saveConfig()
		return false
	end

	local vehicle = F.getVehicle()
	if not vehicle then
		Config.vehicleFlingEnabled = false
		F.stopThread("vehicleFling")
		F.setStatus("fling: сядь в машину")
		F.saveConfig()
		return false
	end

	F.clearEmergencyStop()
	trackedVehicle = vehicle
	Config.vehicleFlingEnabled = true
	F.runVehicleFlingLoop()
	F.saveConfig()
	return true
end

function F.getVehicleBoostMaxSpeed()
	local speed = tonumber(Config.vehicleBoostMaxSpeed) or 60
	return math.clamp(speed, 20, 500)
end

function F.getVehicleBoostPowerMult()
	local maxSpeed = F.getVehicleBoostMaxSpeed()
	return math.clamp(0.9 + (maxSpeed / 22), 1.1, 24)
end

function F.applyVehicleDriveBoost(vehicle)
	if not vehicle or not Config.vehicleBoostEnabled then return false end
	local tune = F.getVehicleDriveTune(vehicle)
	if not tune then return false end

	if not driveTuneSaved[vehicle] then driveTuneSaved[vehicle] = {} end
	local saved = driveTuneSaved[vehicle]
	local mult = F.getVehicleBoostPowerMult()

	for key in pairs(DRIVE_BOOST_MUL_KEYS) do
		local val = tune[key]
		if type(val) == "number" then
			if saved[key] == nil then saved[key] = val end
			local keyMult = mult
			if key == "RevAccel" then
				keyMult = mult * 1.15
			elseif key == "FinalDrive" or key == "FDMult" then
				keyMult = 1 + ((mult - 1) * 0.65)
			elseif key == "PeakRPM" or key == "Redline" then
				keyMult = 1 + ((mult - 1) * 0.35)
			end
			tune[key] = saved[key] * keyMult
		end
	end

	for _, brakeKey in ipairs({ "Brakes", "BrakeForce", "BrakeTorque", "EBrakeForce" }) do
		local val = tune[brakeKey]
		if type(val) == "number" then
			if saved[brakeKey] == nil then saved[brakeKey] = val end
			tune[brakeKey] = saved[brakeKey] * (1 + ((mult - 1) * 0.7))
		end
	end

	return true
end

function F.clampVelocityVec(vel, maxFlat, maxY)
	maxFlat = math.max(40, tonumber(maxFlat) or 180)
	maxY = math.max(20, tonumber(maxY) or 90)
	local flat = Vector3.new(vel.X, 0, vel.Z)
	if flat.Magnitude > maxFlat then
		flat = flat.Unit * maxFlat
	end
	return Vector3.new(flat.X, math.clamp(vel.Y, -maxY, maxY), flat.Z)
end

function F.getVehicleMotionPart(vehicle)
	if not vehicle then return nil end
	local body = vehicle:FindFirstChild("Body")
	if body then
		if body:IsA("BasePart") then
			return body
		end
		local inner = body:FindFirstChildWhichIsA("BasePart", true)
		if inner then return inner end
	end
	local seat = vehicle:FindFirstChild("DriveSeat", true)
	if seat and seat:IsA("BasePart") then return seat end
	return vehicle.PrimaryPart or vehicle:FindFirstChildWhichIsA("BasePart", true)
end

function F.applyVehicleBoostAssist(vehicle)
	if not vehicle or not Config.vehicleBoostEnabled or teleportBusy then return end
	local seat = vehicle:FindFirstChild("DriveSeat", true)
	if not seat or not seat:IsA("VehicleSeat") then return end
	local part = F.getVehicleMotionPart(vehicle)
	if not part then return end

	local throttle = tonumber(seat.ThrottleFloat) or 0
	if throttle == 0 then
		throttle = tonumber(seat.Throttle) or 0
	end
	local vel = part.AssemblyLinearVelocity
	local flat = Vector3.new(vel.X, 0, vel.Z)
	local speed = flat.Magnitude
	local mult = F.getVehicleBoostPowerMult()
	local maxSpeed = F.getVehicleBoostMaxSpeed()
	local steer = tonumber(seat.SteerFloat) or 0
	if steer == 0 then
		steer = tonumber(seat.Steer) or 0
	end

	if speed > maxSpeed + 0.01 then
		local ratio = maxSpeed / speed
		flat = flat * ratio
		speed = flat.Magnitude
		part.AssemblyLinearVelocity = Vector3.new(flat.X, vel.Y, flat.Z)
	end

	if math.abs(throttle) < 0.05 then
		if speed <= 0.25 then
			part.AssemblyLinearVelocity = Vector3.new(0, vel.Y, 0)
			part.AssemblyAngularVelocity = part.AssemblyAngularVelocity * 0.25
			return
		end
		local damp = 1 - math.clamp(0.06 + (0.013 * mult), 0.22, 0.56)
		if speed < 10 then
			damp = damp * 0.75
		end
		local nextFlat = flat * damp
		if nextFlat.Magnitude < 3.2 then
			nextFlat = Vector3.zero
		end
		part.AssemblyLinearVelocity = Vector3.new(nextFlat.X, math.max(vel.Y, -14), nextFlat.Z)
		part.AssemblyAngularVelocity = part.AssemblyAngularVelocity * 0.55
		if nextFlat.Magnitude <= 0.25 then
			part.AssemblyLinearVelocity = Vector3.new(0, vel.Y, 0)
			F.resetVehicleDriveState(vehicle)
		end
		return
	end

	local look = seat.CFrame.LookVector
	local dir = Vector3.new(look.X, 0, look.Z)
	if dir.Magnitude <= 0.01 then return end
	dir = dir.Unit * (throttle > 0 and 1 or -1)

	local forwardSpeed = flat:Dot(dir)
	local lateralVec = flat - (dir * forwardSpeed)
	local lateralGrip = math.clamp(0.18 + (math.abs(steer) * 0.26), 0.14, 0.5)
	local lateralKept = math.max(0, 1 - lateralGrip)
	lateralVec = lateralVec * lateralKept

	local targetSpeed = maxSpeed
	local accelBlend = math.clamp(0.05 + (0.0045 * mult), 0.06, 0.22)
	if math.abs(forwardSpeed) < (maxSpeed * 0.35) then
		accelBlend = math.min(0.3, accelBlend + 0.08)
	end

	local desiredForwardSpeed = forwardSpeed + ((targetSpeed - forwardSpeed) * accelBlend)
	local maxDelta = math.max(3, maxSpeed * 0.045)
	local deltaSpeed = math.clamp(desiredForwardSpeed - forwardSpeed, -maxDelta, maxDelta)
	local nextForwardSpeed = forwardSpeed + deltaSpeed

	local nextFlat = (dir * nextForwardSpeed) + lateralVec
	if nextFlat.Magnitude > maxSpeed then
		nextFlat = nextFlat.Unit * maxSpeed
	end

	local downforce = math.clamp((nextFlat.Magnitude / math.max(1, maxSpeed)) * 7.5, 0, 7.5)
	local forcedY = math.max(vel.Y - (downforce * 0.22), -28)
	part.AssemblyLinearVelocity = F.clampVelocityVec(
		Vector3.new(nextFlat.X, forcedY, nextFlat.Z),
		maxSpeed + 35,
		70
	)

	if math.abs(steer) > 0.02 and nextFlat.Magnitude > 8 then
		local turnAssist = math.clamp(0.003 + ((nextFlat.Magnitude / math.max(1, maxSpeed)) * 0.02), 0.003, 0.03)
		local yawDelta = steer * turnAssist * (throttle >= 0 and 1 or -1)
		local pivot = vehicle:GetPivot()
		local _, yaw, _ = pivot:ToEulerAnglesYXZ()
		vehicle:PivotTo(CFrame.new(pivot.Position) * CFrame.Angles(0, yaw + yawDelta, 0))
		local ang = part.AssemblyAngularVelocity
		part.AssemblyAngularVelocity = Vector3.new(ang.X * 0.96, ang.Y + (steer * math.clamp(nextFlat.Magnitude * 0.09, 4, 28)), ang.Z * 0.96)
	end
end

function F.resetVehicleDriveBoost(vehicle)
	if not vehicle then return end
	local tune = F.getVehicleDriveTune(vehicle)
	local saved = driveTuneSaved[vehicle]
	if tune and saved then
		for key, val in pairs(saved) do
			tune[key] = val
		end
	end
	driveTuneSaved[vehicle] = nil
end

function F.forceRestoreAllNoclip()
	routeNoclipActive = false
	local vehicle = F.getVehicle() or trackedVehicle
	if vehicle then
		F.hardRestoreCollision(vehicle)
		F.setVehicleAnchored(vehicle, false)
		F.liftVehicleIfUnderground(vehicle)
	end
	local char = F.getCharacter()
	if char then F.restoreCharacterCollision(char) end
	for root in pairs(noclipSaved) do
		if root and root.Parent and root:FindFirstChildOfClass("Humanoid") then
			F.restoreCharacterCollision(root)
		else
			F.hardRestoreCollision(root)
		end
	end
end

function F.requestEmergencyStop(reason)
	emergencyStopRequested = true
	Config.autoSmuggle = false
	Config.vehicleFlingEnabled = false
	F.stopThread("autoSmuggle")
	F.stopThread("vehicleFling")
	F.stopThread("promptHoldZeroSweep")
	F.stopThread("autoWork")
	Runtime.promptHoldZeroActiveUntil = 0
	Runtime.heartbeatSpikeStrikes = 0
	table.clear(Runtime.visiblePrompts)
	F.setAutoSmuggleFirstPerson(false)
	teleportBusy = false
	F.forceRestoreAllNoclip()
	F.restoreSmugglePromptSettings()
	F.setPhase("stop")
	F.setStatus(reason or "экстренная остановка")
	F.saveConfig()
	F.notify("экстренная остановка")
end

Runtime.maybeTriggerAntiCrash = function(now, dt)
	local stressActive = Config.autoSmuggle or Config.vehicleFlingEnabled or teleportBusy
	if not stressActive then
		if Runtime.heartbeatSpikeStrikes > 0 and dt <= 0.35 then
			Runtime.heartbeatSpikeStrikes = math.max(0, Runtime.heartbeatSpikeStrikes - 1)
		end
		return false
	end

	if dt >= PERF.antiCrashFrameSpike then
		Runtime.heartbeatSpikeStrikes += 1
	elseif Runtime.heartbeatSpikeStrikes > 0 and dt <= 0.4 then
		Runtime.heartbeatSpikeStrikes -= 1
	end

	if Runtime.heartbeatSpikeStrikes >= PERF.antiCrashStrikesToStop
		and (now - Runtime.lastAntiCrashAt) >= PERF.antiCrashCooldown then
		Runtime.lastAntiCrashAt = now
		Runtime.heartbeatSpikeStrikes = 0
		Config.forcePromptHoldZero = false
		Config.espEnabled = false
		F.requestEmergencyStop("anti-crash: пойман фриз, авто остановлен")
		return true
	end
	return false
end

function F.isWheelMarkerName(name)
	local lower = string.lower(tostring(name or ""))
	if lower == "fl" or lower == "fr" or lower == "rl" or lower == "rr" then
		return true
	end
	return lower:find("wheel", 1, true) ~= nil
		or lower:find("tire", 1, true) ~= nil
		or lower:find("tyre", 1, true) ~= nil
end

function F.isVehicleWheelPart(vehicleModel, part)
	if not vehicleModel or not part then return false end
	local node = part
	while node and node ~= vehicleModel do
		if F.isWheelMarkerName(node.Name) then
			return true
		end
		node = node.Parent
	end
	return false
end

function F.applyNoclip(root, enabled, fullBody)
	if not root then return end
	if not enabled then F.restoreNoclip(root) return end
	local keepVehicleWheelsClip = (not fullBody) and root:FindFirstChild("DriveSeat", true) ~= nil
	if not noclipSaved[root] then noclipSaved[root] = {} end
	for _, part in ipairs(root:GetDescendants()) do
		if part:IsA("BasePart") then
			if noclipSaved[root][part] == nil then
				noclipSaved[root][part] = { CanCollide = part.CanCollide }
			end
			if fullBody then
				part.CanCollide = false
			else
				if keepVehicleWheelsClip and F.isVehicleWheelPart(root, part) then
					part.CanCollide = true
				else
					part.CanCollide = false
				end
			end
		end
	end
end

function F.endRouteNoclipNow()
	F.forceRestoreAllNoclip()
	if Config.noclipVehicles then
		local vehicle = F.getVehicle() or trackedVehicle
		if vehicle then F.applyNoclip(vehicle, true, false) end
	end
	if Config.noclipFoot then
		local char = F.getCharacter()
		if char then F.applyNoclip(char, true, true) end
	end
end

function F.beginRouteNoclip()
	if not Config.noclipDuringRoute then return end
	routeNoclipActive = true
	local vehicle = F.getVehicle() or trackedVehicle
	if vehicle then
		trackedVehicle = vehicle
		F.applyNoclip(vehicle, true, false)
	end
	local char = F.getCharacter()
	if char and not (F.getHumanoid() and F.getHumanoid().SeatPart) then
		F.applyNoclip(char, true, true)
	end
end

function F.beginFootTeleportNoclip()
	routeNoclipActive = true
	local char = F.getCharacter()
	if char then
		F.applyNoclip(char, true, true)
	end
end

function F.setRouteNoclip(on)
	if on then
		F.beginRouteNoclip()
	else
		F.endRouteNoclipNow()
	end
end

function F.updateNoclip()
	if routeNoclipActive and teleportBusy then
		local char = F.getCharacter()
		if char then F.applyNoclip(char, true, true) end
		local vehicle = F.getVehicle() or trackedVehicle
		if vehicle then F.applyNoclip(vehicle, true, false) end
		return
	elseif routeNoclipActive and not teleportBusy then
		F.forceRestoreAllNoclip()
	end

	local vehicle = F.getVehicle() or trackedVehicle
	if Config.noclipVehicles and vehicle then
		F.applyNoclip(vehicle, true, false)
	elseif vehicle then
		F.restoreNoclip(vehicle)
	end

	local char = F.getCharacter()
	if Config.noclipFoot and char then
		F.applyNoclip(char, true, true)
	elseif char then
		F.restoreNoclip(char)
	end
end

function F.getFootRoot()
	local char = F.getCharacter()
	return char and F.getRootPart(char)
end

function F.exitVehicle()
	local hum = F.getHumanoid()
	if not hum then return end
	F.trackVehicleFromSeat(hum.SeatPart)
	if not hum.SeatPart then return end
	hum.Sit = false
	task.wait(0.15)
	pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
	task.wait(0.35)
end

function F.waitNearPosition(target, radius, timeout)
	radius = radius or 4
	timeout = timeout or (Config.footMoveTimeout or 8)
	local deadline = os.clock() + timeout
	while not F.isActionCancelled() and os.clock() < deadline do
		local root = F.getFootRoot()
		if not root then return false end
		if (root.Position - target).Magnitude <= radius then
			return true
		end
		task.wait(0.05)
	end
	return false
end

-- Как в игре: Character:MoveTo / Humanoid:MoveTo (без якоря и PlatformStand)
function F.footMoveGame(pos)
	local char = F.getCharacter()
	local hum = F.getHumanoid(char)
	local root = F.getRootPart(char)
	if not char or not hum or not root then return false end

	pcall(function()
		hum.PlatformStand = false
		hum.Sit = false
		hum:ChangeState(Enum.HumanoidStateType.Running)
	end)

	local moved = pcall(function() char:MoveTo(pos) end)
	if not moved then
		pcall(function() hum:MoveTo(pos) end)
	end

	return F.waitNearPosition(pos, 5, 3)
end

-- Запасной быстрый ТП: только HRP, микрошаги, без Anchored
function F.footSnapTo(pos, snapOpts)
	snapOpts = snapOpts or {}
	local root = F.getFootRoot()
	if not root then return false end

	local hum = F.getHumanoid()
	if hum then
		pcall(function()
			hum.PlatformStand = false
			hum.Sit = false
		end)
	end

	local startPos = root.Position
	local delta = pos - startPos
	local dist = delta.Magnitude
	if dist < 0.5 then return true end

	local step = math.max(0.03, snapOpts.stepSize or Config.stepSize)
	local perFrame = math.max(1, math.floor(snapOpts.stepsPerFrame or Config.stepsPerFrame))
	local dir = delta.Unit
	local rotation = root.CFrame - root.CFrame.Position
	local traveled = 0

	while traveled < dist and not F.isActionCancelled() do
		for _ = 1, perFrame do
			if F.isActionCancelled() then return false end
			traveled = math.min(traveled + step, dist)
			root = F.getFootRoot()
			if not root then return false end
			root.CFrame = CFrame.new(startPos + dir * traveled) * rotation
			F.zeroVelocities(root)
			if traveled >= dist then break end
		end
		RunService.Heartbeat:Wait()
	end
	return true
end

function F.holdFootAtPosition(pos, seconds)
	local root = F.getFootRoot()
	if not root then return false end
	local duration = math.max(0, seconds or Config.finalHoldSeconds or 0)
	if duration <= 0 then return true end
	local rot = root.CFrame - root.CFrame.Position
	local untilTime = os.clock() + duration
	while not F.isActionCancelled() and os.clock() < untilTime do
		root = F.getFootRoot()
		if not root then return false end
		root.CFrame = CFrame.new(pos) * rot
		F.zeroVelocities(root)
		RunService.Heartbeat:Wait()
	end
	return true
end

function F.footTeleportElevated(targetPos)
	local root = F.getFootRoot()
	if not root then return false end

	local startPos = root.Position
	local dest = Vector3.new(targetPos.X, targetPos.Y, targetPos.Z)
	local cruiseY = math.max(startPos.Y, dest.Y) + (Config.climbHeight or 35)
	local descendStep = math.max(0.03, (Config.stepSize or 0.25) * (Config.descendStepMult or 0.45))

	if not F.footSnapTo(Vector3.new(startPos.X, cruiseY, startPos.Z)) then return false end
	if not F.footSnapTo(Vector3.new(dest.X, cruiseY, dest.Z)) then return false end
	if not F.footSnapTo(dest, { stepSize = descendStep, stepsPerFrame = 1 }) then return false end
	return true
end

function F.footTeleportByMode(targetPos, mode)
	mode = mode or Config.footTpMode or "elevated"
	local dest = Vector3.new(targetPos.X, targetPos.Y, targetPos.Z)
	F.setStatus("ноги [" .. mode .. "]...")

	if mode == "step" then
		return F.footSnapTo(dest)
	end
	if mode == "elevated" then
		return F.footTeleportElevated(dest)
	end
	return F.footTeleportElevated(dest)
end

function F.footTeleportTo(_subject, _anchor, targetPos, opts)
	opts = opts or {}
	F.exitVehicle()
	if not F.waitInterruptible(0.2) then return false end

	if not F.getFootRoot() then
		F.setStatus("нет персонажа")
		return false
	end

	local mode = opts.footMode or Config.footTpMode or "elevated"
	local ok = F.footTeleportByMode(targetPos, mode)
	if ok then
		F.holdFootAtPosition(Vector3.new(targetPos.X, targetPos.Y, targetPos.Z), Config.finalHoldSeconds or 0.35)
	end
	if ok then
		F.setStatus("ноги готово [" .. mode .. "]")
		F.notify("ТП ноги: " .. mode .. " — ок")
	else
		F.setStatus("ноги fail [" .. mode .. "]")
		F.notify("ТП ноги: " .. mode .. " — fail")
	end
	return ok
end

function F.holdE(duration, prompt)
	duration = duration or 1.5

	if prompt and prompt.Parent and prompt:IsA("ProximityPrompt") then
		pcall(function()
			F.lookCameraDown()
			prompt:InputHoldBegin()
			local untilTime = os.clock() + math.max(0.03, duration)
			while os.clock() < untilTime and not F.isActionCancelled() do
				F.lookCameraDown()
				task.wait(0.03)
			end
			prompt:InputHoldEnd()
		end)
	end

	if VirtualInputManager then
		local sentDown = false
		pcall(function()
			F.lookCameraDown()
			VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
			sentDown = true
			local untilTime = os.clock() + math.max(0.03, duration)
			while os.clock() < untilTime and not F.isActionCancelled() do
				F.lookCameraDown()
				task.wait(0.03)
			end
		end)
		if sentDown then
			pcall(function()
				VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
			end)
		end
	elseif typeof(keypress) == "function" then
		local pressed = false
		pcall(function()
			F.lookCameraDown()
			keypress(0x45)
			pressed = true
			local untilTime = os.clock() + math.max(0.03, duration)
			while os.clock() < untilTime and not F.isActionCancelled() do
				F.lookCameraDown()
				task.wait(0.03)
			end
		end)
		if pressed and typeof(keyrelease) == "function" then
			pcall(function() keyrelease(0x45) end)
		end
	end
	return not F.isActionCancelled()
end

function F.usePrompt(prompt, duration)
	if not prompt or not prompt.Parent then return false end
	duration = duration or 0.12
	local ok = pcall(function()
		F.lookCameraDown()
		prompt:InputHoldBegin()
		local untilTime = os.clock() + math.max(0.03, duration)
		while os.clock() < untilTime and not F.isActionCancelled() do
			F.lookCameraDown()
			task.wait(0.03)
		end
		prompt:InputHoldEnd()
	end)
	if not ok and typeof(fireproximityprompt) == "function" then
		pcall(function()
			fireproximityprompt(prompt, duration)
		end)
	end
	return not F.isActionCancelled()
end

function F.tapPrompt(prompt)
	return F.usePrompt(prompt, 0.12)
end

function F.holdPrompt(prompt, duration)
	return F.usePrompt(prompt, duration or 5)
end

function F.forcePromptHoldZero(prompt)
	if not prompt or not prompt.Parent or not prompt:IsA("ProximityPrompt") then return end
	pcall(function()
		if prompt.HoldDuration ~= 0 then
			prompt.HoldDuration = 0
		end
	end)
end

Runtime.trackVisiblePrompt = function(prompt, shouldKeep)
	if not prompt or not prompt:IsA("ProximityPrompt") then return end
	if shouldKeep == false then
		Runtime.visiblePrompts[prompt] = nil
		return
	end
	Runtime.visiblePrompts[prompt] = true
end

Runtime.armPromptHoldZeroWindow = function(seconds)
	if not Config.forcePromptHoldZero then return end
	local window = math.max(0.6, tonumber(seconds) or PERF.promptHoldZeroActionWindow)
	local untilAt = os.clock() + window
	if untilAt > Runtime.promptHoldZeroActiveUntil then
		Runtime.promptHoldZeroActiveUntil = untilAt
	end
end

Runtime.pulsePromptHoldZeroVisible = function()
	if not Config.forcePromptHoldZero then return end
	local now = os.clock()
	if (now - Runtime.lastPromptHoldZeroPulseAt) < PERF.promptHoldZeroInterval then
		return
	end
	Runtime.lastPromptHoldZeroPulseAt = now
	local applied = 0
	for prompt in pairs(Runtime.visiblePrompts) do
		if not prompt or not prompt.Parent then
			Runtime.visiblePrompts[prompt] = nil
		else
			F.forcePromptHoldZero(prompt)
			applied += 1
			if applied >= 160 then
				break
			end
		end
	end
end

function F.applyPromptHoldZeroSweep()
	Runtime.armPromptHoldZeroWindow(PERF.promptHoldZeroActionWindow)
	Runtime.pulsePromptHoldZeroVisible()
end

function F.runPromptHoldZeroLoop()
	F.stopThread("promptHoldZero")
	F.startThread("promptHoldZero", function()
		while mounted and threads.promptHoldZero do
			if Config.forcePromptHoldZero and os.clock() <= Runtime.promptHoldZeroActiveUntil then
				Runtime.pulsePromptHoldZeroVisible()
			end
			if not F.waitInterruptible(PERF.promptHoldZeroInterval) then
				break
			end
		end
	end)
end

function F.activatePromptSmart(prompt, fallbackHold)
	if not prompt or not prompt.Parent then return false end
	Runtime.trackVisiblePrompt(prompt, true)
	Runtime.armPromptHoldZeroWindow(2.5)
	Runtime.pulsePromptHoldZeroVisible()
	F.lookCameraDown()
	local hold = tonumber(prompt.HoldDuration) or 0
	if hold <= 0.05 then
		return F.tapPrompt(prompt)
	end
	return F.holdPrompt(prompt, math.max(hold + 0.08, fallbackHold or hold))
end

function F.restoreSmugglePromptSettings()
	for prompt, saved in pairs(smugglePromptSaved) do
		if prompt and prompt.Parent and saved then
			pcall(function()
				prompt.HoldDuration = saved.HoldDuration
				prompt.MaxActivationDistance = saved.MaxActivationDistance
			end)
		end
		smugglePromptSaved[prompt] = nil
	end
end

function F.normalizeText(text)
	local s = string.lower(tostring(text or ""))
	s = s:gsub("[%s%p_]+", "")
	return s
end

function F.promptMatchesQuery(prompt, query)
	if not prompt or not query then return false end
	local q = F.normalizeText(query)
	if q == "" then return false end
	local merged = F.normalizeText((prompt.ActionText or "") .. " " .. (prompt.ObjectText or "") .. " " .. (prompt.Name or ""))
	return merged:find(q, 1, true) ~= nil
end

function F.findNearestPromptByText(query, nearPos, maxDistance)
	local bestPrompt, bestPos, bestDist
	local fallbackPrompt, fallbackPos, fallbackDist
	local root = F.getRootPart()
	local refPos = nearPos or (root and root.Position)

	for prompt in pairs(Runtime.visiblePrompts) do
		if not prompt or not prompt.Parent then
			Runtime.visiblePrompts[prompt] = nil
		elseif prompt.Enabled and F.promptMatchesQuery(prompt, query) then
			local pos = F.getPromptWorldPos(prompt)
			if pos then
				local ref = refPos or pos
				local dist = (pos - ref).Magnitude
				if not fallbackDist or dist < fallbackDist then
					fallbackPrompt, fallbackPos, fallbackDist = prompt, pos, dist
				end
				if (not maxDistance or dist <= maxDistance) and (not bestDist or dist < bestDist) then
					bestPrompt, bestPos, bestDist = prompt, pos, dist
				end
			end
		end
	end
	if bestPrompt or fallbackPrompt then
		return bestPrompt or fallbackPrompt, bestPos or fallbackPos, bestDist or fallbackDist
	end

	local stack = { Workspace }
	local processed = 0
	while #stack > 0 and not F.isActionCancelled() do
		local inst = stack[#stack]
		stack[#stack] = nil
		if inst:IsA("ProximityPrompt") and inst.Enabled and F.promptMatchesQuery(inst, query) then
			local pos = F.getPromptWorldPos(inst)
			if pos then
				local ref = refPos or pos
				local dist = (pos - ref).Magnitude
				if not fallbackDist or dist < fallbackDist then
					fallbackPrompt, fallbackPos, fallbackDist = inst, pos, dist
				end
				if (not maxDistance or dist <= maxDistance) and (not bestDist or dist < bestDist) then
					bestPrompt, bestPos, bestDist = inst, pos, dist
				end
			end
		end
		local children = inst:GetChildren()
		for i = 1, #children do
			stack[#stack + 1] = children[i]
		end
		processed += 1
		if processed % 220 == 0 then
			task.wait()
		end
	end
	return bestPrompt or fallbackPrompt, bestPos or fallbackPos, bestDist or fallbackDist
end

function F.findNearestSellPrompt(nearPos, maxDistance)
	local queries = { "sell all smuggle", "sell smuggle", "sell all" }
	local bestPrompt, bestPos, bestDist
	for _, q in ipairs(queries) do
		local prompt, pos, dist = F.findNearestPromptByText(q, nearPos, maxDistance or 90)
		if prompt and pos then
			local d = dist
			if d == nil then
				local root = F.getRootPart()
				local ref = nearPos or (root and root.Position) or pos
				d = (pos - ref).Magnitude
			end
			if not bestDist or d < bestDist then
				bestPrompt, bestPos, bestDist = prompt, pos, d
			end
		end
	end
	return bestPrompt, bestPos, bestDist
end

function F.findNearestSmugglePurchasePrompt(itemName, nearPos)
	local smuggling = Workspace:FindFirstChild("Smuggling")
	local items = smuggling and smuggling:FindFirstChild("Items")
	if not items then return nil, nil end

	-- Все SmugglePurchasePrompt: HoldDuration = 0.
	-- У выбранного предмета MaxActivationDistance = 100, у остальных = 0.
	local bestPrompt, bestPos, bestDist
	local root = F.getRootPart()
	local refPos = nearPos or (root and root.Position)
	for _, inst in ipairs(items:GetDescendants()) do
		if inst:IsA("ProximityPrompt") and inst.Name == "SmugglePurchasePrompt" then
			if smugglePromptSaved[inst] == nil then
				smugglePromptSaved[inst] = {
					HoldDuration = inst.HoldDuration,
					MaxActivationDistance = inst.MaxActivationDistance,
				}
			end
			local selected = inst:FindFirstAncestor(itemName) ~= nil
			pcall(function()
				inst.HoldDuration = 0
				inst.MaxActivationDistance = selected and 100 or 0
			end)
			if not inst.Enabled then
				continue
			end
			local itemRoot = inst:FindFirstAncestor(itemName)
			if itemRoot then
				local pos = F.getPromptWorldPos(inst)
				if pos then
					local ref = refPos or pos
					local dist = (pos - ref).Magnitude
					if not bestDist or dist < bestDist then
						bestPrompt, bestPos, bestDist = inst, pos, dist
					end
				end
			end
		end
	end
	return bestPrompt, bestPos, bestDist
end

function F.countNamedItemsInContainer(container, itemName)
	if not container or not itemName or itemName == "" then return 0 end
	local count = 0
	for _, child in ipairs(container:GetChildren()) do
		if child.Name == itemName then
			count += 1
		end
	end
	return count
end

function F.forceToolsBackToBackpack()
	local hum = F.getHumanoid()
	if hum then
		pcall(function() hum:UnequipTools() end)
	end
end

local STACK_HINT_KEYS = {
	"Amount", "Quantity", "Count", "Stack", "Stacks",
}

function F.getBackpackContainer()
	local lp = F.getLocalPlayer()
	return lp and lp:FindFirstChild("Backpack")
end

function F.readToolStackUnits(tool)
	if not tool then return 0 end
	local best = 0
	for _, key in ipairs(STACK_HINT_KEYS) do
		local attr = tool:GetAttribute(key)
		if type(attr) == "number" and attr > best then
			best = attr
		end
		local child = tool:FindFirstChild(key)
		if child and (child:IsA("IntValue") or child:IsA("NumberValue")) then
			local v = tonumber(child.Value) or 0
			if v > best then best = v end
		end
	end
	return math.max(0, best)
end

function F.getBackpackItemSnapshot(itemName)
	local backpack = F.getBackpackContainer()
	if not backpack then
		return { count = 0, stack = 0 }
	end
	F.forceToolsBackToBackpack()
	local count = 0
	local stack = 0
	for _, child in ipairs(backpack:GetChildren()) do
		if child.Name == itemName then
			count += 1
			stack += F.readToolStackUnits(child)
		end
	end
	return { count = count, stack = stack }
end

function F.getBackpackNamedCount(itemName)
	local backpack = F.getBackpackContainer()
	return F.countNamedItemsInContainer(backpack, itemName)
end

function F.snapshotUnits(snapshot)
	local count = snapshot and snapshot.count or 0
	local stack = snapshot and snapshot.stack or 0
	if count <= 0 then return 0 end
	if stack <= 0 then return count end
	-- Если stack выглядит как "реальное количество", используем его.
	-- Если значение слишком большое (например цена), остаёмся на count.
	if (stack / count) <= 20 then
		return stack
	end
	return count
end

function F.hasSnapshotProgress(before, after)
	if not before or not after then return false end
	if (after.count or 0) > (before.count or 0) then return true end
	if (after.count or 0) == (before.count or 0) and F.snapshotUnits(after) > F.snapshotUnits(before) + 0.001 then
		return true
	end
	return false
end

function F.waitForBackpackProgress(itemName, beforeSnapshot, timeout)
	local deadline = os.clock() + math.max(0.1, timeout or 1.0)
	local current = F.getBackpackItemSnapshot(itemName)
	while os.clock() < deadline and not F.isActionCancelled() do
		current = F.getBackpackItemSnapshot(itemName)
		if F.hasSnapshotProgress(beforeSnapshot, current) then
			return true, current
		end
		task.wait(0.05)
	end
	return false, current
end

function F.activateBuyPromptRobust(prompt)
	if not prompt or not prompt.Parent then return false end
	Runtime.trackVisiblePrompt(prompt, true)
	Runtime.armPromptHoldZeroWindow(3.0)
	Runtime.pulsePromptHoldZeroVisible()
	F.lookCameraDown()
	if typeof(fireproximityprompt) == "function" then
		pcall(function() fireproximityprompt(prompt, 0) end)
	end
	if not F.activatePromptSmart(prompt, Config.smuggleHoldSeconds or 2) then
		return false
	end
	if not F.waitInterruptible(0.04) then return false end
	if typeof(fireproximityprompt) == "function" then
		F.lookCameraDown()
		pcall(function() fireproximityprompt(prompt, 0) end)
	end
	F.holdE(0.12, prompt)
	return true
end

function F.activateSellPromptFast(prompt)
	if not prompt or not prompt.Parent then return false end
	Runtime.trackVisiblePrompt(prompt, true)
	Runtime.armPromptHoldZeroWindow(2.5)
	Runtime.pulsePromptHoldZeroVisible()
	F.lookCameraDown()
	pcall(function()
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = math.max(tonumber(prompt.MaxActivationDistance) or 0, 100)
	end)
	if typeof(fireproximityprompt) == "function" then
		pcall(function() fireproximityprompt(prompt, 0) end)
		task.wait(0.01)
		pcall(function() fireproximityprompt(prompt, 0) end)
		return true
	end
	if F.activatePromptSmart(prompt, 0.08) then
		return true
	end
	return F.tapPrompt(prompt)
end

function F.buySmuggleItemTimes(itemName, nearPos, times)
	local desired = math.max(1, math.floor((times or 3) + 0.5))
	local startSnapshot = F.getBackpackItemSnapshot(itemName)
	local maxAttemptsPerItem = 10

	for idx = 1, desired do
		local bought = false

		for attempt = 1, maxAttemptsPerItem do
			if F.isActionCancelled() then return false, nil end
			Runtime.armPromptHoldZeroWindow(2.5)

			local prompt, pos = F.findNearestSmugglePurchasePrompt(itemName, nearPos)
			if not prompt then
				F.setStatus("нет prompt покупки")
				return false, nil
			end

			local root = F.getRootPart()
			if pos and root and (root.Position - pos).Magnitude > 4.6 then
				if not F.smartTeleportTo(pos, { forceMode = "foot", routeNoclip = true, footMode = "step" }) then
					return false, nil
				end
				if not F.waitInterruptible(0.14) then return false, nil end
				Runtime.pulsePromptHoldZeroVisible()
			end

			if pos then
				F.holdFootAtPosition(Vector3.new(pos.X, pos.Y, pos.Z), 0.28)
			end

			local beforeSnapshot = F.getBackpackItemSnapshot(itemName)
			F.setStatus(string.format("покупка %d/%d (попытка %d)", idx, desired, attempt))
			if not F.activateBuyPromptRobust(prompt) then
				return false, nil
			end

			local got, afterSnapshot = F.waitForBackpackProgress(itemName, beforeSnapshot, 2.2)
			if got then
				F.setStatus(string.format("взято %d/%d", idx, desired))
				bought = true
				break
			end

			F.notify(string.format("%s не взялся (%d/%d), повтор", tostring(itemName), idx, desired))
			if not F.waitInterruptible(0.16) then return false, nil end
		end

		if not bought then
			local current = F.getBackpackItemSnapshot(itemName)
			local have = math.max(0, F.snapshotUnits(current) - F.snapshotUnits(startSnapshot))
			F.setStatus(string.format("взято %d/%d", have, desired))
			F.notify(string.format("не удалось взять %d/%d %s", have, desired, tostring(itemName)))
			return false, nil
		end

		if not F.waitInterruptible(0.12) then return false, nil end
	end

	local endSnapshot = F.getBackpackItemSnapshot(itemName)
	return true, {
		itemName = itemName,
		boughtCount = desired,
		startSnapshot = startSnapshot,
		endSnapshot = endSnapshot,
	}
end

function F.getBackpackUnitsByItems(itemNames)
	local map = {}
	for _, itemName in ipairs(itemNames or {}) do
		if map[itemName] == nil then
			map[itemName] = F.snapshotUnits(F.getBackpackItemSnapshot(itemName))
		end
	end
	return map
end

function F.computeSellRemovedProgress(itemNames, unitsBeforeByItem, expectedRemovedByItem, unitsNowByItem)
	local removedOk = true
	local removedTotal = 0
	for _, itemName in ipairs(itemNames or {}) do
		local beforeUnits = unitsBeforeByItem[itemName] or 0
		local nowUnits = unitsNowByItem[itemName] or 0
		local expected = math.max(0, expectedRemovedByItem[itemName] or 0)
		local removed = math.max(0, beforeUnits - nowUnits)
		removedTotal += removed
		if removed < expected then
			removedOk = false
		end
	end
	return removedOk, removedTotal
end

function F.waitForSellConfirmation(itemNames, unitsBeforeByItem, briefcaseBefore, expectedRemovedByItem, timeout)
	local deadline = os.clock() + math.max(0.12, timeout or PERF.sellConfirmTimeoutFast)
	local currentUnitsByItem = F.getBackpackUnitsByItems(itemNames)
	local lastRemovedTotal = 0
	local lastRemovedOk = false
	local lastBriefcase = F.getBackpackNamedCount("Briefcase")
	while os.clock() < deadline and not F.isActionCancelled() do
		currentUnitsByItem = F.getBackpackUnitsByItems(itemNames)
		local removedOk, removedTotal = F.computeSellRemovedProgress(itemNames, unitsBeforeByItem, expectedRemovedByItem, currentUnitsByItem)
		lastRemovedTotal = removedTotal
		lastRemovedOk = removedOk

		local briefcaseNow = F.getBackpackNamedCount("Briefcase")
		lastBriefcase = briefcaseNow
		local briefcaseOk = briefcaseNow >= 1 and (briefcaseNow > briefcaseBefore or briefcaseBefore >= 1)
		if removedOk and briefcaseOk then
			return true, currentUnitsByItem, briefcaseNow, removedTotal, true
		end
		task.wait(0.03)
	end
	return false, currentUnitsByItem, lastBriefcase, lastRemovedTotal, lastRemovedOk
end

function F.sellSmuggleWithVerification(sellPrompt, sellPos, itemNames, expectedRemovedByItem)
	itemNames = itemNames or {}
	expectedRemovedByItem = expectedRemovedByItem or {}
	if #itemNames == 0 then return false end

	local beforeUnitsByItem = F.getBackpackUnitsByItems(itemNames)
	local beforeBriefcase = F.getBackpackNamedCount("Briefcase")
	local attempts = 4

	for attempt = 1, attempts do
		if F.isActionCancelled() then return false end
		local root = F.getRootPart()
		local refPos = (root and root.Position) or sellPos
		local refreshedPrompt, refreshedPos = F.findNearestSellPrompt(refPos, 90)
		if refreshedPrompt then
			sellPrompt = refreshedPrompt
			sellPos = refreshedPos or sellPos
		end
		if not sellPrompt then
			if not F.waitInterruptible(0.04) then return false end
			continue
		end

		pcall(function()
			sellPrompt.HoldDuration = 0
			sellPrompt.MaxActivationDistance = math.max(tonumber(sellPrompt.MaxActivationDistance) or 0, 100)
		end)

		root = F.getRootPart()
		if sellPos and root and (root.Position - sellPos).Magnitude > 6.8 then
			if not F.smartTeleportTo(sellPos, { forceMode = "foot", routeNoclip = true, footMode = "step" }) then
				return false
			end
			if not F.waitInterruptible(0.03) then return false end
		end
		if sellPos then
			F.holdFootAtPosition(Vector3.new(sellPos.X, sellPos.Y, sellPos.Z), 0.05)
		end

		F.setStatus(string.format("продажа (попытка %d)", attempt))
		if not F.activateSellPromptFast(sellPrompt) then
			return false
		end

		local sold, _unitsNowByItem, briefcaseNow, removedTotal, removedOk = F.waitForSellConfirmation(
			itemNames,
			beforeUnitsByItem,
			beforeBriefcase,
			expectedRemovedByItem,
			(attempt <= 2) and PERF.sellConfirmTimeoutFast or 1.7
		)
		if sold then
			F.setStatus(string.format("продано: -%d, кейс:%d", removedTotal, briefcaseNow))
			return true
		end
		if removedOk and removedTotal > 0 and attempt >= 2 then
			-- Иногда игра не даёт новый Briefcase при наличии старого; считаем продажу успешной по факту списания.
			F.setStatus(string.format("продано: -%d (без нового кейса)", removedTotal))
			return true
		end

		if not F.waitInterruptible(PERF.sellRetryDelayFast) then return false end
	end

	F.setStatus("продажа не подтверждена")
	return false
end

function F.findNearestSelectedCargoPrompt(nearPos)
	local bestPrompt, bestPos, bestDist, bestName
	for _, itemName in ipairs(F.getSelectedCargoItems()) do
		local prompt, pos, dist = F.findNearestSmugglePurchasePrompt(itemName, nearPos)
		if prompt and pos then
			local d = dist
			if d == nil then
				local root = F.getRootPart()
				local ref = nearPos or (root and root.Position) or pos
				d = (pos - ref).Magnitude
			end
			if not bestDist or d < bestDist then
				bestPrompt, bestPos, bestDist, bestName = prompt, pos, d, itemName
			end
		end
	end
	return bestPrompt, bestPos, bestName
end

function F.getCargoPosition()
	local pickup = F.tableToVec3(Config.waypoints and Config.waypoints.pickup)
	local _, pos = F.findNearestSelectedCargoPrompt(pickup)
	return pos
end

function F.teleportToCargo()
	local prompt, pos, itemName = F.findNearestSelectedCargoPrompt()
	if not prompt or not pos then
		F.setStatus("груз не найден")
		return false
	end
	F.setStatus("ТП к грузу: " .. tostring(itemName))
	return F.smartTeleportTo(pos, { forceMode = "foot", routeNoclip = true, footMode = "elevated" })
end

function F.getPartPosition(inst)
	if not inst then return nil end
	if inst:IsA("BasePart") then return inst.Position end
	if inst:IsA("Attachment") then return inst.WorldPosition end
	if inst:IsA("Model") then
		local p = inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
		return p and p.Position
	end
	local part = inst:FindFirstAncestorWhichIsA("BasePart")
	return part and part.Position
end

function F.getPromptWorldPos(prompt)
	if not prompt then return nil end
	local parent = prompt.Parent
	if not parent then return nil end
	if parent:IsA("Attachment") then
		return parent.WorldPosition
	end
	if parent:IsA("BasePart") then
		return parent.Position
	end
	return F.getPartPosition(parent)
end

function F.lookCameraDown()
	local cam = Workspace.CurrentCamera
	local root = F.getRootPart()
	if not cam then return end
	local camPos = cam.CFrame.Position
	local downTarget = camPos + Vector3.new(0, -200, 0)
	local upVec = root and root.CFrame.RightVector or Vector3.new(1, 0, 0)
	local ok = pcall(function()
		cam.CFrame = CFrame.lookAt(camPos, downTarget, upVec)
	end)
	if not ok then
		pcall(function()
			cam.CFrame = CFrame.new(camPos, downTarget)
		end)
	end
end

function F.stepMove(subject, kind, anchor, targetPos, onProgress)
	if kind == "foot" then
		subject = F.getFootRoot()
		anchor = subject
		if not subject then return false end
	end

	local startCF = F.getSubjectPivot(subject, kind, anchor)
	local startPos = startCF.Position
	local delta = targetPos - startPos
	local dist = delta.Magnitude
	if dist < 0.05 then return true end

	local step = math.max(0.05, Config.stepSize)
	local dir = delta.Unit
	local traveled = 0
	local rotation = startCF - startCF.Position

	while traveled < dist and not F.isActionCancelled() do
		for _ = 1, math.max(1, Config.stepsPerFrame) do
			if F.isActionCancelled() then return false end
			traveled = math.min(traveled + step, dist)
			local pos = startPos + dir * traveled
			if kind == "foot" then
				subject = F.getFootRoot()
				if not subject then return false end
				F.zeroVelocities(subject)
				subject.CFrame = CFrame.new(pos) * rotation
			else
				F.setSubjectPivot(subject, kind, CFrame.new(pos) * rotation)
			end
			if onProgress then onProgress(traveled / dist) end
			if traveled >= dist then break end
		end
		RunService.Heartbeat:Wait()
	end
	return true
end

function F.getRotation(subject, kind, anchor)
	local cf = F.getSubjectPivot(subject, kind, anchor)
	return cf - cf.Position
end

function F.instantMove(subject, kind, anchor, targetPos)
	local rotation = F.getRotation(subject, kind, anchor)
	F.setSubjectPivot(subject, kind, CFrame.new(targetPos) * rotation)
end

function F.vehicleStepMove(subject, anchor, targetPos, onProgress)
	local startCF = subject:GetPivot()
	local startPos = startCF.Position
	local _, yaw, _ = startCF:ToEulerAnglesYXZ()
	local rotation = CFrame.Angles(0, yaw, 0)
	local delta = targetPos - startPos
	local dist = delta.Magnitude
	if dist < 0.05 then return true end

	local step = math.max(0.05, Config.vehicleStepSize or 0.4)
	local dir = delta.Unit
	local traveled = 0

	while traveled < dist and not F.isActionCancelled() do
		for _ = 1, math.max(1, Config.stepsPerFrame) do
			if F.isActionCancelled() then return false end
			traveled = math.min(traveled + step, dist)
			local pos = startPos + dir * traveled
			subject:PivotTo(CFrame.new(pos) * rotation)
			F.zeroVelocities(subject)
			if onProgress then onProgress(traveled / dist) end
			if traveled >= dist then break end
		end
		RunService.Heartbeat:Wait()
	end
	return true
end

function F.vehicleMoveTo(subject, anchor, targetPos, onProgress)
	if Config.vehicleTpMode == "legit" then
		return F.vehicleStepMove(subject, anchor, targetPos, onProgress)
	end
	local destCF = F.buildVehicleDestCF(subject, targetPos)
	return F.safeVehiclePivot(subject, destCF)
end

function F.vehicleTeleportAirStep(subject, targetPos)
	if not subject or not subject.Parent then return false end
	local startPos = subject:GetPivot().Position
	local cruiseY = math.max(startPos.Y, targetPos.Y) + (Config.climbHeight or 35)
	local upPos = Vector3.new(startPos.X, cruiseY, startPos.Z)
	local flyPos = Vector3.new(targetPos.X, cruiseY, targetPos.Z)

	F.setStatus("машина: набор...")
	if not F.vehicleStepMove(subject, nil, upPos) then return false end

	F.setStatus("машина: долёт...")
	if not F.vehicleStepMove(subject, nil, flyPos, function(p)
		F.setStatus(string.format("машина: долёт %.0f%%", p * 100))
	end) then
		return false
	end

	-- Финал: отпускаем машину в воздухе, чтобы она падала сама.
	F.setStatus("машина: отпущена")
	F.zeroVelocities(subject)
	return true
end

function F.vehicleTeleportTo(subject, anchor, targetPos, useSavedY, instant, vehicleAirStep)
	F.setStatus("ТП машиной...")
	local useAirStep = vehicleAirStep == true or Config.vehicleTpMode == "air_step"
	if useAirStep and instant ~= true then
		return F.vehicleTeleportAirStep(subject, targetPos)
	end

	local destPos = F.resolveVehicleDestPos(targetPos, subject, useSavedY == true)
	local useLegit = Config.vehicleTpMode == "legit" and instant ~= true

	if useLegit then
		F.resetVehicleDriveState(subject)
		F.setVehicleAnchored(subject, true)
		F.vehicleStepMove(subject, anchor, destPos, function(p)
			F.setStatus(string.format("машина %.0f%%", p * 100))
		end)
		F.stabilizeVehicle(subject, 3)
		F.setVehicleAnchored(subject, false)
		F.stabilizeVehicle(subject, 12)
		F.liftVehicleIfUnderground(subject)
		F.resetVehicleDriveState(subject)
	else
		F.safeVehiclePivot(subject, F.buildVehicleDestCF(subject, destPos))
	end

	F.zeroVelocities(subject)
	return true
end

function F.smartTeleportTo(targetPos, opts)
	opts = opts or {}
	if not targetPos then
		F.notify("точка не задана")
		return false
	end
	if emergencyStopRequested then
		F.setStatus("остановлено")
		return false
	end
	if teleportBusy then F.notify("телепорт занят") return false end

	local forceMode = opts.forceMode
	local useSavedY = opts.useSavedY == true
	local withRouteNoclip = opts.routeNoclip ~= false

	local subject, anchor, kind = F.getTeleportSubject(forceMode)
	if not subject then return false end

	teleportBusy = true
	if kind == "foot" then
		F.beginFootTeleportNoclip()
	elseif withRouteNoclip then
		F.beginRouteNoclip()
	end

	local ok, result = pcall(function()
		if kind == "vehicle" then
			return F.vehicleTeleportTo(subject, anchor, targetPos, useSavedY, opts.instant == true, opts.vehicleAirStep == true)
		end
		return F.footTeleportTo(subject, anchor, targetPos, opts)
	end)

	teleportBusy = false
	if kind == "vehicle" and opts.skipVehicleStabilize ~= true then
		F.stabilizeVehicle(subject, 4)
	end
	F.forceRestoreAllNoclip()

	if not ok then
		F.notify("ошибка ТП: " .. tostring(result))
		return false
	end
	if emergencyStopRequested then
		return false
	end
	return result ~= false
end

function F.teleportToWaypoint(key, extraOpts)
	extraOpts = extraOpts or {}
	local pos = F.tableToVec3(Config.waypoints and Config.waypoints[key])
	if not pos then
		local label = string.upper(tostring(key))
		F.notify(label .. " не задан")
		F.setStatus(key .. " не задан")
		return false
	end

	local inVehicle = F.getVehicle() ~= nil
	local forceMode = extraOpts.forceMode
	if not forceMode then
		forceMode = inVehicle and "vehicle" or "foot"
	end

	local opts = {
		forceMode = forceMode,
		useSavedY = extraOpts.useSavedY == true,
		instant = extraOpts.instant == true,
		vehicleAirStep = extraOpts.vehicleAirStep == true,
		skipVehicleStabilize = extraOpts.skipVehicleStabilize == true,
		footMode = extraOpts.footMode or Config.footTpMode,
	}
	if extraOpts.routeNoclip ~= nil then
		opts.routeNoclip = extraOpts.routeNoclip
	elseif forceMode == "foot" then
		opts.routeNoclip = false
	end

	local ok = F.smartTeleportTo(pos, opts)
	if ok then
		Runtime.armPromptHoldZeroWindow(6.0)
		Runtime.pulsePromptHoldZeroVisible()
	end
	if not ok then
		F.notify("ТП → " .. string.upper(tostring(key)) .. " не удался")
	end
	return ok
end

function F.teleportToPosition(pos, opts)
	if not pos then
		F.setStatus("точка не задана")
		return false
	end
	opts = opts or {}
	local target = Vector3.new(pos.X, pos.Y, pos.Z)
	return F.smartTeleportTo(target, opts)
end

function F.getSmuggleWaypoints()
	local pickup = F.tableToVec3(Config.waypoints and Config.waypoints.pickup)
	local dropoff = F.tableToVec3(Config.waypoints and Config.waypoints.dropoff)
	local footZone = F.tableToVec3(Config.waypoints and Config.waypoints.footZone)
	if not pickup or not dropoff or not footZone then
		F.setStatus("задай PICKUP / DROPOFF / FOOT")
		return nil, nil, nil
	end
	return pickup, dropoff, footZone
end

function F.teleportFootForCycle(pos, phaseName, footMode)
	if F.isActionCancelled() then return false end
	F.setPhase(phaseName or "move")
	local ok = F.smartTeleportTo(pos, {
		forceMode = "foot",
		routeNoclip = true,
		footMode = footMode or "elevated",
	})
	if ok then
		Runtime.armPromptHoldZeroWindow(4.0)
		Runtime.pulsePromptHoldZeroVisible()
	end
	return ok
end

function F.runCargoPickupSequenceFoot()
	if emergencyStopRequested then
		F.setStatus("остановлено")
		return false
	end

	local pickup, dropoff, footZone = F.getSmuggleWaypoints()
	if not pickup or not dropoff or not footZone then
		return false
	end
	local selectedItems = F.getSelectedCargoItems()
	if #selectedItems == 0 then
		F.setStatus("грузы не выбраны")
		return false
	end

	if not F.teleportFootForCycle(pickup, "to-pickup", "elevated") then
		return false
	end
	if not F.waitInterruptible(0.1) then return false end

	local expectedRemovedByItem = {}
	for idx, itemName in ipairs(selectedItems) do
		F.setPhase(string.format("find-item %d/%d", idx, #selectedItems))
		local rootNow = F.getRootPart()
		local nearRef = rootNow and rootNow.Position or pickup
		local _, cargoPos = F.findNearestSmugglePurchasePrompt(itemName, nearRef)
		if not cargoPos then
			F.setStatus("нет предмета: " .. tostring(itemName))
			return false
		end

		if not F.teleportFootForCycle(cargoPos, string.format("to-item %d/%d", idx, #selectedItems), "step") then
			return false
		end
		if not F.waitInterruptible(0.1) then return false end

		F.setPhase(string.format("buy-item %d/%d", idx, #selectedItems))
		local buyOk, buyMeta = F.buySmuggleItemTimes(itemName, cargoPos, SMUGGLE_BUY_COUNT_PER_ITEM)
		if not buyOk then
			return false
		end
		local boughtNow = math.max(1, math.floor((buyMeta and buyMeta.boughtCount) or 1))
		expectedRemovedByItem[itemName] = (expectedRemovedByItem[itemName] or 0) + boughtNow
		if not F.waitInterruptible(0.12) then return false end
	end

	if not F.teleportFootForCycle(dropoff, "to-dropoff", "elevated") then
		return false
	end
	if not F.waitInterruptible(0.02) then return false end

	F.setPhase("sell-smuggle")
	local sellPrompt, sellPos = F.findNearestSellPrompt(dropoff, 90)
	if not sellPrompt then
		F.setStatus("нет Sell All Smuggle")
		F.notify("prompt Sell All Smuggle не найден")
		return false
	end
	if not F.sellSmuggleWithVerification(sellPrompt, sellPos, selectedItems, expectedRemovedByItem) then
		return false
	end
	if not F.waitInterruptible(0.02) then return false end

	if not F.teleportFootForCycle(footZone, "to-foot", "elevated") then
		return false
	end
	if not F.waitInterruptible(0.1) then return false end

	F.setPhase("laundry")
	local laundryPrompt, laundryPos = F.findNearestPromptByText("laundry dirty money", footZone, 90)
	if not laundryPrompt then
		F.setStatus("нет Laundry Dirty Money")
		F.notify("prompt Laundry Dirty Money не найден")
		return false
	end
	local root = F.getRootPart()
	if laundryPos and root and (root.Position - laundryPos).Magnitude > 5 then
		if not F.teleportFootForCycle(laundryPos, "to-laundry-prompt", "step") then return false end
	end
	if not F.activateBuyPromptRobust(laundryPrompt) then
		return false
	end
	if not F.waitInterruptible(0.15) then return false end

	F.setPhase("idle")
	F.setStatus("цикл завершён")
	F.hookSession("cycle")
	return true
end

function F.runCargoPickupSequence()
	return F.runCargoPickupSequenceFoot()
end

function F.runAutoSmuggleLoop()
	F.clearEmergencyStop()
	if Config.vehicleFlingEnabled then
		F.setVehicleFlingEnabled(false)
	end
	F.setAutoSmuggleFirstPerson(true)
	F.applyPromptHoldZeroSweep()
	F.stopThread("autoSmuggle")
	F.startThread("autoSmuggle", function()
		F.hookSession("start")
		while mounted and threads.autoSmuggle and Config.autoSmuggle and not emergencyStopRequested do
			Runtime.armPromptHoldZeroWindow(2.0)
			F.applyFirstPersonCamera()
			local ok, cycleOk = pcall(F.runCargoPickupSequence)
			if not ok then
				F.setStatus("ошибка цикла: " .. tostring(cycleOk))
				F.waitInterruptible(0.8)
			elseif not cycleOk then
				F.setStatus("цикл не завершён")
				F.waitInterruptible(0.8)
			else
				F.waitInterruptible(0.35)
			end
		end
		F.forceRestoreAllNoclip()
		F.restoreSmugglePromptSettings()
		F.setAutoSmuggleFirstPerson(false)
		F.setPhase("idle")
		F.hookSession("stop")
	end)
end

function F.getGateTargets()
	local map = Workspace:FindFirstChild("Map")
	if not map then return {} end
	local targets = {}
	local streetProps = map:FindFirstChild("Street Props")
	local barriers = streetProps and streetProps:FindFirstChild("Barriers")
	local borderInner = map:FindFirstChild("Border") and map.Border:FindFirstChild("Border")
	local vehicleGates = borderInner and borderInner:FindFirstChild("VehicleGates")
	if barriers then table.insert(targets, barriers) end
	if vehicleGates then table.insert(targets, vehicleGates) end
	return targets
end

function F.setPartGateHidden(part, hidden)
	if not part:IsA("BasePart") then return end
	if hidden then
		if not gatePartState[part] then
			gatePartState[part] = {
				Transparency = part.Transparency,
				LocalTransparencyModifier = part.LocalTransparencyModifier,
				CanCollide = part.CanCollide,
				CanQuery = part.CanQuery,
				CanTouch = part.CanTouch,
			}
		end
		part.Transparency = 1
		part.LocalTransparencyModifier = 1
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
	else
		local saved = gatePartState[part]
		if saved then
			part.Transparency = saved.Transparency
			part.LocalTransparencyModifier = saved.LocalTransparencyModifier
			part.CanCollide = saved.CanCollide
			part.CanQuery = saved.CanQuery
			part.CanTouch = saved.CanTouch
			gatePartState[part] = nil
		end
	end
end

function F.setGateFolderHidden(folder, hidden)
	if not folder then return end
	if folder:IsA("BasePart") then
		F.setPartGateHidden(folder, hidden)
	end
	for _, desc in ipairs(folder:GetDescendants()) do
		if desc:IsA("BasePart") then
			F.setPartGateHidden(desc, hidden)
		end
	end
end

function F.setGatesRemoved(removed)
	if not removed then
		Config.gatesRemoved = false
		F.saveConfig()
		F.notify("возврат гейтов невозможен без перезахода")
		return false
	end

	local targets = F.getGateTargets()
	if #targets == 0 then
		F.notify("гейты не найдены")
		return false
	end

	local deletedCount = 0
	for _, folder in ipairs(targets) do
		if folder and folder.Parent then
			local ok = pcall(function()
				folder:Destroy()
			end)
			if ok then
				deletedCount += 1
			end
		end
	end

	if deletedCount <= 0 then
		F.notify("не удалось удалить гейты")
		return false
	end

	Config.gatesRemoved = true
	F.saveConfig()
	F.notify("гейты удалены намертво (до перезахода)")
	return true
end

function F.toggleGates()
	if Config.gatesRemoved then
		F.notify("гейты уже удалены")
		return
	end
	F.setGatesRemoved(true)
end

-- ESP (module)
local espApi = {
	clear = function() end,
	refresh = function() end,
	bind = function() end,
}

function F.initEspApi()
	local factory = F.loadOptionalModule("modules/esp.lua")
	if type(factory) ~= "function" then
		return false
	end
	local ok, api = pcall(factory, {
		Players = Players,
		Workspace = Workspace,
		Config = Config,
		getLocalPlayer = F.getLocalPlayer,
		trackConn = F.trackConn,
	})
	if not ok or type(api) ~= "table" then
		return false
	end
	if type(api.clear) == "function" then espApi.clear = api.clear end
	if type(api.refresh) == "function" then espApi.refresh = api.refresh end
	if type(api.bind) == "function" then espApi.bind = api.bind end
	return true
end

function F.runAutoWorkLoop()
	F.stopThread("autoWork")
	F.startThread("autoWork", function()
		while mounted and threads.autoWork and Config.autoWork do
			F.setStatus("авто-работа: WIP")
			task.wait(2)
		end
	end)
end

function F.mountMain(ctx)
	local ui = ctx.ui
	local page = ctx.pages.main
	local makeFlowPanel = ui.makeFlowPanel
	local makeFlowToggle = ui.makeFlowToggle
	local makeStatRow = ui.makeStatRow
	local makeScrollPage = ui.makeScrollPage
	local COLORS = ui.COLORS
	local L = ctx.translate or tr
	local registerLocale = ctx.registerLocale

	local scroll = makeScrollPage(page)
	local wrap = ui.makeListWrap and ui.makeListWrap(scroll) or scroll

	local wrapPad = Instance.new("UIPadding")
	wrapPad.PaddingLeft = UDim.new(0, 4)
	wrapPad.PaddingRight = UDim.new(0, 10)
	wrapPad.Parent = wrap

	local BTN_W = 128
	local BTN_H = 30
	local ROW_GAP = 16

	local function mountAdaptivePanel(holder, title, height, bodyOffsetY, localeKey, setupBody)
		holder.Size = UDim2.new(1, 0, 0, height)
		holder.BackgroundTransparency = 1
		task.defer(function()
			if not holder.Parent then
				return
			end
			local w = math.floor(holder.AbsoluteSize.X + 0.5)
			if w < 80 then
				task.delay(0.05, function()
					mountAdaptivePanel(holder, title, height, bodyOffsetY, localeKey, setupBody)
				end)
				return
			end
			for _, child in ipairs(holder:GetChildren()) do
				child:Destroy()
			end
			local body = makeFlowPanel(holder, title, w, height, 0, 0, bodyOffsetY, localeKey)
			if setupBody then
				setupBody(body, w)
			end
		end)
	end

	local function makeBlockHost(order, height)
		local host = Instance.new("Frame")
		host.Size = UDim2.new(1, 0, 0, height)
		host.BackgroundTransparency = 1
		host.LayoutOrder = order
		host.Parent = wrap
		return host
	end

	local function makeSplitRow(parent, order, height)
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, height)
		row.BackgroundTransparency = 1
		row.LayoutOrder = order
		row.Parent = parent
		local lay = Instance.new("UIListLayout")
		lay.FillDirection = Enum.FillDirection.Horizontal
		lay.Padding = UDim.new(0, ROW_GAP)
		lay.SortOrder = Enum.SortOrder.LayoutOrder
		lay.Parent = row
		return row
	end

	local function makeHalfHolder(parent, order)
		local slot = Instance.new("Frame")
		slot.Size = UDim2.new(0.5, -8, 1, 0)
		slot.BackgroundTransparency = 1
		slot.LayoutOrder = order
		slot.Parent = parent
		local holder = Instance.new("Frame")
		holder.Size = UDim2.new(1, 0, 1, 0)
		holder.BackgroundTransparency = 1
		holder.Parent = slot
		return holder
	end

	local topRow = makeSplitRow(wrap, 1, 200)
	mountAdaptivePanel(makeHalfHolder(topRow, 1), L("panel_status", "Статус"), 200, nil, "panel_status", function(statusPanel)
		statusValueLabel = makeStatRow(statusPanel, L("stat_state", "Состояние"), 1, "stat_state")
		phaseValueLabel = makeStatRow(statusPanel, L("stat_phase", "Фаза"), 2, "stat_phase")
		statusValueLabel.Text = F.localizeStatusText(State.status)
		phaseValueLabel.Text = State.phase
	end)

	mountAdaptivePanel(makeHalfHolder(topRow, 2), L("panel_points", "Точки"), 200, 35, "panel_points", function(points)
		pickupValueLabel = makeStatRow(points, L("stat_pickup", "PICKUP"), 1, "stat_pickup")
		dropoffValueLabel = makeStatRow(points, L("stat_dropoff", "DROPOFF"), 2, "stat_dropoff")
		footZoneValueLabel = makeStatRow(points, L("stat_foot", "FOOT"), 3, "stat_foot")
		cargoValueLabel = makeStatRow(points, L("stat_cargo", "Груз"), 4, "stat_cargo")
		F.refreshWaypointLabels()
	end)

	local cargoHost = makeBlockHost(2, 166)
	mountAdaptivePanel(cargoHost, L("panel_cargo", "Выбор груза"), 166, 40, "panel_cargo", function(cargoPanel, panelW)
		local cargoCellW = math.max(120, math.floor((panelW - 16 - 6) / 2))
		local cargoRow = Instance.new("Frame")
		cargoRow.Size = UDim2.new(1, 0, 0, 106)
		cargoRow.BackgroundTransparency = 1
		cargoRow.LayoutOrder = 1
		cargoRow.Parent = cargoPanel

		local cargoGrid = Instance.new("UIGridLayout")
		cargoGrid.CellSize = UDim2.new(0, cargoCellW, 0, 28)
		cargoGrid.CellPadding = UDim2.new(0, 6, 0, 6)
		cargoGrid.HorizontalAlignment = Enum.HorizontalAlignment.Left
		cargoGrid.SortOrder = Enum.SortOrder.LayoutOrder
		cargoGrid.Parent = cargoRow

		local cargoBtns = {}
		local function getCargoIndex(items, itemName)
			for i, name in ipairs(items) do
				if name == itemName then return i end
			end
			return nil
		end
		local function refreshCargoBtns()
			local selected = F.getSelectedCargoItems()
			local selectedOrder = {}
			for i, name in ipairs(selected) do
				selectedOrder[name] = i
			end
			for _, b in ipairs(cargoBtns) do
				local itemName = b:GetAttribute("CargoName")
				local order = selectedOrder[itemName]
				local isSelected = order ~= nil
				b:SetAttribute("Selected", isSelected)
				b.BackgroundColor3 = isSelected and COLORS.accentSoft or COLORS.panel
				b.Text = isSelected and string.format("%d) %s", order, itemName) or itemName
			end
		end
		for i, name in ipairs(CARGO_ITEMS) do
			local btn = Instance.new("TextButton")
			btn.Size = UDim2.new(0, cargoCellW, 0, 28)
			btn.BackgroundColor3 = COLORS.panel
			btn.BorderSizePixel = 0
			btn.Font = Enum.Font.Gotham
			btn.TextSize = 10
			btn.TextColor3 = COLORS.text
			btn.Text = name
			btn.LayoutOrder = i
			btn.Parent = cargoRow
			local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = btn
			btn:SetAttribute("CargoName", name)
			btn:SetAttribute("Selected", false)
			btn.MouseButton1Click:Connect(function()
				local selected = F.getSelectedCargoItems()
				local idx = getCargoIndex(selected, name)
				if idx then
					if #selected > 1 then
						table.remove(selected, idx)
					end
				else
					if #selected >= MAX_SELECTED_CARGO_ITEMS then
						table.remove(selected, #selected)
					end
					table.insert(selected, name)
				end
				Config.cargoItems = F.sanitizeCargoSelection(selected)
				Config.cargoItem = Config.cargoItems[1]
				F.saveConfig()
				refreshCargoBtns()
				F.refreshWaypointLabels()
			end)
			table.insert(cargoBtns, btn)
		end
		refreshCargoBtns()
	end)

	local ctrlHost = makeBlockHost(3, 178)
	mountAdaptivePanel(ctrlHost, L("panel_cycle", "Телепорт и цикл"), 178, 40, "panel_cycle", function(ctrl)
		makeFlowToggle(ctrl, L("toggle_auto_smuggle", "Авто контрабанда (цикл)"), Config.autoSmuggle, function(v)
			Config.autoSmuggle = v
			if v then
				F.clearEmergencyStop()
				if Config.vehicleFlingEnabled then
					F.setVehicleFlingEnabled(false)
				end
				F.runAutoSmuggleLoop()
		else
			F.stopThread("autoSmuggle")
			F.hookSession("stop")
			F.forceRestoreAllNoclip()
				F.restoreSmugglePromptSettings()
				F.setAutoSmuggleFirstPerson(false)
				F.setPhase("idle")
			end
			F.saveConfig()
		end, 1, nil, "toggle_auto_smuggle")

		local btnRow = Instance.new("Frame")
		btnRow.Size = UDim2.new(1, 0, 0, 36)
		btnRow.BackgroundTransparency = 1
		btnRow.LayoutOrder = 2
		btnRow.Parent = ctrl

		local btnGrid = Instance.new("UIGridLayout")
		btnGrid.CellSize = UDim2.new(0, BTN_W, 0, BTN_H)
		btnGrid.CellPadding = UDim2.new(0, 8, 0, 6)
		btnGrid.HorizontalAlignment = Enum.HorizontalAlignment.Left
		btnGrid.SortOrder = Enum.SortOrder.LayoutOrder
		btnGrid.Parent = btnRow

		local function makeBtn(text, order, cb, localeKey)
			local b = Instance.new("TextButton")
			b.Size = UDim2.new(0, BTN_W, 0, BTN_H)
			b.BackgroundColor3 = COLORS.accentSoft
			b.BorderSizePixel = 0
			b.Font = Enum.Font.GothamSemibold
			b.TextSize = 10
			b.TextColor3 = COLORS.text
			b.Text = text
			b.LayoutOrder = order
			b.Parent = btnRow
			local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 8) c.Parent = b
			if type(registerLocale) == "function" and localeKey then
				registerLocale(b, localeKey)
			end
			b.MouseButton1Click:Connect(function()
				task.spawn(function()
					F.clearEmergencyStop()
					local ok, err = pcall(cb)
					if not ok then
						F.setStatus("ошибка кнопки")
						F.notify("ошибка кнопки: " .. tostring(err))
					end
				end)
			end)
		end

		makeBtn(L("btn_tp_pickup", "ТП -> PICKUP"), 1, function()
			F.teleportToWaypoint("pickup", {
				footMode = "elevated",
				instant = true,
				useSavedY = true,
				skipVehicleStabilize = true,
			})
		end, "btn_tp_pickup")
		makeBtn(L("btn_tp_dropoff", "ТП -> DROPOFF"), 2, function()
			F.teleportToWaypoint("dropoff", {
				footMode = "elevated",
				instant = true,
				useSavedY = true,
				skipVehicleStabilize = true,
			})
		end, "btn_tp_dropoff")
		makeBtn(L("btn_tp_foot", "ТП -> FOOT"), 3, function()
			F.teleportToWaypoint("footZone", {
				footMode = "elevated",
				instant = true,
				useSavedY = true,
				skipVehicleStabilize = true,
			})
		end, "btn_tp_foot")
	end)
end

function F.mountFeaturesBuiltin(deps, ctx)
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

	local function reg(el, key)
		if type(deps.registerLocale) == "function" and el and key then
			deps.registerLocale(el, key)
		end
	end

	local function makeActionBtn(parent, text, order, callback, localeKey)
		local host = Instance.new("Frame")
		host.Size = UDim2.new(1, 0, 0, 38)
		host.BackgroundTransparency = 1
		host.LayoutOrder = order
		host.Parent = parent

		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, 0, 0, 30)
		btn.BackgroundColor3 = ui.COLORS.accentSoft
		btn.BorderSizePixel = 0
		btn.Font = Enum.Font.GothamSemibold
		btn.TextSize = 10
		btn.TextColor3 = ui.COLORS.text
		btn.Text = text
		btn.Parent = host
		reg(btn, localeKey)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = btn
		btn.MouseButton1Click:Connect(function()
			call(callback)
		end)
		return btn
	end

	local scroll = ui.makeScrollPage(page)
	local wrap = ui.makeListWrap(scroll)
	local makeSectionTitle = ui.makeSectionTitle
	local makeFlowToggle = ui.makeFlowToggle

	makeSectionTitle(wrap, tr("sec_main", "основное"), 1, "sec_main")
	makeFlowToggle(wrap, tr("toggle_esp_players", "ESP игроков"), values.espEnabled == true, function(v)
		call(deps.onToggleEsp, v)
	end, 2, nil, "toggle_esp_players")
	makeFlowToggle(wrap, tr("toggle_noclip_foot", "Постоянный noclip (ноги)"), values.noclipFoot == true, function(v)
		call(deps.onToggleNoclipFoot, v)
	end, 3, nil, "toggle_noclip_foot")
	makeFlowToggle(wrap, tr("toggle_noclip_vehicle", "Постоянный noclip (машина)"), values.noclipVehicles == true, function(v)
		call(deps.onToggleNoclipVehicle, v)
	end, 4, nil, "toggle_noclip_vehicle")
	makeFlowToggle(wrap, tr("toggle_prompt_zero", "Убрать задержку E (везде)"), values.forcePromptHoldZero ~= false, function(v)
		call(deps.onTogglePromptHoldZero, v)
	end, 5, nil, "toggle_prompt_zero")

	makeSectionTitle(wrap, tr("sec_vehicle_opt", "машина (опц.)"), 6, "sec_vehicle_opt")
	makeFlowToggle(wrap, tr("toggle_vehicle_boost", "Буст машины"), values.vehicleBoostEnabled == true, function(v)
		call(deps.onToggleVehicleBoost, v)
	end, 7, nil, "toggle_vehicle_boost")
	makeFlowToggle(wrap, tr("toggle_vehicle_stop_s", "Мгновенный стоп на S"), values.vehicleStopOnS == true, function(v)
		call(deps.onToggleVehicleStopOnS, v)
	end, 8, nil, "toggle_vehicle_stop_s")
	makeFlowToggle(wrap, tr("toggle_vehicle_fling", "Fling по другим машинам (быстро)"), values.vehicleFlingEnabled == true, function(v)
		call(deps.onToggleVehicleFling, v)
	end, 9, nil, "toggle_vehicle_fling")
	makeActionBtn(wrap, tr("btn_vehicle_stop_now", "Остановить машину сейчас"), 10, deps.onInstantStopVehicle, "btn_vehicle_stop_now")

	makeSectionTitle(wrap, tr("sec_map", "карта"), 11, "sec_map")
	local gateBtn = makeActionBtn(
		wrap,
		values.gatesRemoved and tr("btn_gates_removed", "Гейты удалены") or tr("btn_delete_gates", "Удалить гейты НАМЕРТВО"),
		12,
		function()
			local removed = call(deps.onDeleteGates)
			if removed and gateBtn then
				gateBtn.Text = tr("btn_gates_removed", "Гейты удалены")
				gateBtn.BackgroundColor3 = ui.COLORS.panel
			end
		end,
		values.gatesRemoved and "btn_gates_removed" or "btn_delete_gates"
	)
	if values.gatesRemoved and gateBtn then
		gateBtn.BackgroundColor3 = ui.COLORS.panel
	end
end

function F.mountSettingsBuiltin(deps, ctx)
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

	local function reg(el, key)
		if type(deps.registerLocale) == "function" and el and key then
			deps.registerLocale(el, key)
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

	makeSlider(tpBox, 0, tr("slider_tp_step", "Длина шага ТП"), 0.05, 1, values.stepSize or 0.20, function(v) set("stepSize", v) end, "slider_tp_step")
	makeSlider(tpBox, 60, tr("slider_tp_steps_per_frame", "Шагов за кадр"), 1, 12, values.stepsPerFrame or 10, function(v) set("stepsPerFrame", v) end, "slider_tp_steps_per_frame")
	makeSlider(tpBox, 120, tr("slider_tp_height", "Высота полёта"), 10, 90, values.climbHeight or 45, function(v) set("climbHeight", v) end, "slider_tp_height")
	makeSlider(tpBox, 180, tr("slider_tp_descend", "Замедление спуска"), 0.2, 1, values.descendStepMult or 0.32, function(v) set("descendStepMult", v) end, "slider_tp_descend")
	makeSlider(tpBox, 240, tr("slider_tp_hold", "Фиксация на точке (сек)"), 0, 1.2, values.finalHoldSeconds or 0.50, function(v) set("finalHoldSeconds", v) end, "slider_tp_hold")

	makeSectionTitle(wrap, tr("sec_vehicle_opt", "машина (опц.)"), 3, "sec_vehicle_opt")
	local boostBox = Instance.new("Frame")
	boostBox.Size = UDim2.new(1, 0, 0, 52)
	boostBox.BackgroundTransparency = 1
	boostBox.LayoutOrder = 4
	boostBox.Parent = wrap

	makeSlider(boostBox, 0, tr("slider_boost_max_speed", "Лимит скорости буста"), 20, 500, values.vehicleBoostMaxSpeed or 60, function(v) set("vehicleBoostMaxSpeed", v) end, "slider_boost_max_speed")

	makeSectionTitle(wrap, tr("sec_fling_orbit", "флинг (орбита)"), 5, "sec_fling_orbit")
	local flingBox = Instance.new("Frame")
	flingBox.Size = UDim2.new(1, 0, 0, 652)
	flingBox.BackgroundTransparency = 1
	flingBox.LayoutOrder = 6
	flingBox.Parent = wrap

	makeSlider(flingBox, 0, tr("slider_fling_orbit_speed", "Fling: скорость вращения"), 2, 60, values.vehicleFlingOrbitSpeed or 20, function(v) set("vehicleFlingOrbitSpeed", v) end, "slider_fling_orbit_speed")
	makeSlider(flingBox, 60, tr("slider_fling_fore_aft", "Fling: длина вперёд/назад"), 0.5, 12, values.vehicleFlingForeAft or 12, function(v) set("vehicleFlingForeAft", v) end, "slider_fling_fore_aft")
	makeSlider(flingBox, 120, tr("slider_fling_side", "Fling: ширина орбиты"), 0.5, 12, values.vehicleFlingSide or 3.6, function(v) set("vehicleFlingSide", v) end, "slider_fling_side")
	makeSlider(flingBox, 180, tr("slider_fling_height", "Fling: высота (ниже/выше)"), -4, 3, values.vehicleFlingHeightOffset or -0.8, function(v) set("vehicleFlingHeightOffset", v) end, "slider_fling_height")
	makeSlider(flingBox, 240, tr("slider_fling_bob", "Fling: волна по высоте"), 0, 4, values.vehicleFlingBobAmplitude or 3.2, function(v) set("vehicleFlingBobAmplitude", v) end, "slider_fling_bob")
	makeSlider(flingBox, 300, tr("slider_fling_linear", "Fling: сила толчка"), 40, 900, values.vehicleFlingLinearPower or 900, function(v) set("vehicleFlingLinearPower", v) end, "slider_fling_linear")
	makeSlider(flingBox, 360, tr("slider_fling_spin", "Fling: сила вращения"), 60, 1800, values.vehicleFlingSpinPower or 1800, function(v) set("vehicleFlingSpinPower", v) end, "slider_fling_spin")
	makeSlider(flingBox, 420, tr("slider_fling_hold", "Fling: держать цель (сек)"), 0.3, 10, values.vehicleFlingHoldSeconds or 2.4, function(v) set("vehicleFlingHoldSeconds", v) end, "slider_fling_hold")
	makeSlider(flingBox, 480, tr("slider_fling_regrab", "Fling: пауза между целями"), 0, 0.5, values.vehicleFlingRegrabDelay or 0.2, function(v) set("vehicleFlingRegrabDelay", v) end, "slider_fling_regrab")
	makeSlider(flingBox, 540, tr("slider_fling_ultra", "Fling: УЛЬТРА множитель"), 0.5, 3.5, values.vehicleFlingUltraMult or 2.0, function(v) set("vehicleFlingUltraMult", v) end, "slider_fling_ultra")

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
		reg(b, localeKey)
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 8)
		c.Parent = b
		b.MouseButton1Click:Connect(function()
			set("applyFlingPreset", presetName)
		end)
	end

	makePresetBtn(tr("btn_fling_soft", "Fling: Мягкий"), 0, 130, "soft", "btn_fling_soft")
	makePresetBtn(tr("btn_fling_user", "Fling: Твой"), 136, 130, "user", "btn_fling_user")
	makePresetBtn(tr("btn_fling_ultra", "Fling: Ультра"), 272, 130, "ultra", "btn_fling_ultra")
end

function F.shouldUseExternalUiModules()
	local genv = typeof(getgenv) == "function" and getgenv() or _G
	return type(genv) == "table" and genv.EPBRUseExternalUiModules == true
end

function F.mountFeatures(ctx)
	local extMount = F.mountFeaturesBuiltin
	if F.shouldUseExternalUiModules() then
		local mod = F.loadOptionalModule("modules/features-tab.lua")
		if type(mod) == "function" then
			extMount = mod
		end
	end

	local ok, err = pcall(extMount, {
		values = {
			espEnabled = Config.espEnabled,
			noclipFoot = Config.noclipFoot,
			noclipVehicles = Config.noclipVehicles,
			forcePromptHoldZero = Config.forcePromptHoldZero,
			vehicleBoostEnabled = Config.vehicleBoostEnabled,
			vehicleStopOnS = Config.vehicleStopOnS,
			vehicleFlingEnabled = Config.vehicleFlingEnabled,
			gatesRemoved = Config.gatesRemoved,
		},
		onToggleEsp = function(v)
			Config.espEnabled = v
			if not v then espApi.clear() else espApi.refresh() end
			F.saveConfig()
		end,
		onToggleNoclipFoot = function(v)
			Config.noclipFoot = v
			if not v then
				local c = F.getCharacter()
				if c then F.restoreCharacterCollision(c) end
			end
			F.saveConfig()
		end,
		onToggleNoclipVehicle = function(v)
			Config.noclipVehicles = v
			if not v then
				local vh = F.findMyVehicle()
				if vh then F.restoreNoclip(vh) end
			end
			F.saveConfig()
		end,
		onTogglePromptHoldZero = function(v)
			Config.forcePromptHoldZero = v
			if v then
				F.applyPromptHoldZeroSweep()
			else
				Runtime.promptHoldZeroActiveUntil = 0
				table.clear(Runtime.visiblePrompts)
			end
			F.saveConfig()
		end,
		onToggleVehicleBoost = function(v)
			Config.vehicleBoostEnabled = v
			local vehicle = F.getVehicle() or trackedVehicle
			if v then
				if vehicle then F.applyVehicleDriveBoost(vehicle) end
			elseif vehicle then
				F.resetVehicleDriveBoost(vehicle)
			end
			F.saveConfig()
		end,
		onToggleVehicleStopOnS = function(v)
			Config.vehicleStopOnS = v
			F.saveConfig()
		end,
		onToggleVehicleFling = function(v)
			F.setVehicleFlingEnabled(v)
		end,
		onInstantStopVehicle = function()
			F.instantStopVehicle()
			F.notify("машина остановлена")
		end,
		onDeleteGates = function()
			local removed = F.setGatesRemoved(true)
			return removed or Config.gatesRemoved
		end,
		translate = ctx.translate or function(key, fallback) return fallback or key end,
		registerLocale = ctx.registerLocale,
	}, ctx)
	if not ok then
		warn("[EPBR] mountFeatures failed: " .. tostring(err))
	end
end

function F.mountSettings(ctx)
	local extMount = F.mountSettingsBuiltin
	if F.shouldUseExternalUiModules() then
		local mod = F.loadOptionalModule("modules/settings-tab.lua")
		if type(mod) == "function" then
			extMount = mod
		end
	end

	local function onSet(key, v)
		if key == "stepSize" then
			Config.stepSize = math.clamp(v, 0.05, 1)
		elseif key == "stepsPerFrame" then
			Config.stepsPerFrame = math.clamp(math.floor(v + 0.5), 1, 12)
		elseif key == "climbHeight" then
			Config.climbHeight = math.clamp(v, 10, 90)
		elseif key == "descendStepMult" then
			Config.descendStepMult = math.clamp(v, 0.2, 1)
		elseif key == "finalHoldSeconds" then
			Config.finalHoldSeconds = math.clamp(v, 0, 1.2)
		elseif key == "vehicleBoostMaxSpeed" then
			Config.vehicleBoostMaxSpeed = math.clamp(math.floor(v + 0.5), 20, 500)
			local vehicle = F.getVehicle() or trackedVehicle
			if vehicle and Config.vehicleBoostEnabled then
				F.resetVehicleDriveBoost(vehicle)
				F.applyVehicleDriveBoost(vehicle)
			end
		elseif key == "vehicleFlingOrbitSpeed" then
			Config.vehicleFlingOrbitSpeed = math.clamp(v, 2, 60)
		elseif key == "vehicleFlingForeAft" then
			Config.vehicleFlingForeAft = math.clamp(v, 0.5, 12)
		elseif key == "vehicleFlingSide" then
			Config.vehicleFlingSide = math.clamp(v, 0.5, 12)
		elseif key == "vehicleFlingHeightOffset" then
			Config.vehicleFlingHeightOffset = math.clamp(v, -4, 3)
		elseif key == "vehicleFlingBobAmplitude" then
			Config.vehicleFlingBobAmplitude = math.clamp(v, 0, 4)
		elseif key == "vehicleFlingLinearPower" then
			Config.vehicleFlingLinearPower = math.clamp(v, 40, 900)
		elseif key == "vehicleFlingSpinPower" then
			Config.vehicleFlingSpinPower = math.clamp(v, 60, 1800)
		elseif key == "vehicleFlingHoldSeconds" then
			Config.vehicleFlingHoldSeconds = math.clamp(v, 0.3, 10)
		elseif key == "vehicleFlingRegrabDelay" then
			Config.vehicleFlingRegrabDelay = math.clamp(v, 0, 0.5)
		elseif key == "vehicleFlingUltraMult" then
			Config.vehicleFlingUltraMult = math.clamp(v, 0.5, 3.5)
		elseif key == "applyFlingPreset" then
			local presets = {
				soft = { orbitSpeed = 8, foreAft = 4, side = 3, heightOffset = -0.4, bobAmplitude = 0.9, linearPower = 220, spinPower = 320, holdSeconds = 1.8, regrabDelay = 0.06, ultraMult = 1.0 },
				user = { orbitSpeed = 20, foreAft = 12, side = 3.6, heightOffset = -0.8, bobAmplitude = 3.2, linearPower = 900, spinPower = 1800, holdSeconds = 2.4, regrabDelay = 0.2, ultraMult = 2.0 },
				ultra = { orbitSpeed = 42, foreAft = 12, side = 8, heightOffset = -1.2, bobAmplitude = 3.8, linearPower = 900, spinPower = 1800, holdSeconds = 3.6, regrabDelay = 0.02, ultraMult = 3.0 },
			}
			local p = presets[tostring(v or "")]
			if not p then return end
			Config.vehicleFlingOrbitSpeed = math.clamp(p.orbitSpeed, 2, 60)
			Config.vehicleFlingForeAft = math.clamp(p.foreAft, 0.5, 12)
			Config.vehicleFlingSide = math.clamp(p.side, 0.5, 12)
			Config.vehicleFlingHeightOffset = math.clamp(p.heightOffset, -4, 3)
			Config.vehicleFlingBobAmplitude = math.clamp(p.bobAmplitude, 0, 4)
			Config.vehicleFlingLinearPower = math.clamp(p.linearPower, 40, 900)
			Config.vehicleFlingSpinPower = math.clamp(p.spinPower, 60, 1800)
			Config.vehicleFlingHoldSeconds = math.clamp(p.holdSeconds, 0.3, 10)
			Config.vehicleFlingRegrabDelay = math.clamp(p.regrabDelay, 0, 0.5)
			Config.vehicleFlingUltraMult = math.clamp(p.ultraMult, 0.5, 3.5)
			F.saveConfig()
			F.setStatus("fling preset: " .. tostring(v))
			return
		else
			return
		end
		F.saveConfig()
	end

	pcall(extMount, {
		values = {
			stepSize = Config.stepSize,
			stepsPerFrame = Config.stepsPerFrame,
			climbHeight = Config.climbHeight,
			descendStepMult = Config.descendStepMult or 0.45,
			finalHoldSeconds = Config.finalHoldSeconds or 0.35,
			vehicleBoostMaxSpeed = Config.vehicleBoostMaxSpeed or 60,
			vehicleFlingOrbitSpeed = Config.vehicleFlingOrbitSpeed or 20,
			vehicleFlingForeAft = Config.vehicleFlingForeAft or 12,
			vehicleFlingSide = Config.vehicleFlingSide or 3.6,
			vehicleFlingHeightOffset = Config.vehicleFlingHeightOffset or -0.8,
			vehicleFlingBobAmplitude = Config.vehicleFlingBobAmplitude or 3.2,
			vehicleFlingLinearPower = Config.vehicleFlingLinearPower or 900,
			vehicleFlingSpinPower = Config.vehicleFlingSpinPower or 1800,
			vehicleFlingHoldSeconds = Config.vehicleFlingHoldSeconds or 2.4,
			vehicleFlingRegrabDelay = Config.vehicleFlingRegrabDelay or 0.2,
			vehicleFlingUltraMult = Config.vehicleFlingUltraMult or 2.0,
		},
		onSet = onSet,
		translate = ctx.translate or function(key, fallback) return fallback or key end,
		registerLocale = ctx.registerLocale,
	}, ctx)
end

function M.getRuntimeSnapshot()
	local cargoText = table.concat(F.getSelectedCargoItems(), ", ")
	if cargoText == "" then
		cargoText = "—"
	end
	return {
		status = F.localizeStatusText(State.status or ""),
		phase = State.phase or "idle",
		cargo = cargoText,
	}
end

function M.getUiLanguage()
	return F.normalizeLang(Config.uiLanguage)
end

function M.setUiLanguage(lang)
	Config.uiLanguage = F.normalizeLang(lang)
	F.saveConfig()
	if statusValueLabel and statusValueLabel.Parent then
		statusValueLabel.Text = F.localizeStatusText(State.status)
	end
	F.refreshWaypointLabels()
end

function M.stop()
	emergencyStopRequested = true
	mounted = false
	Config.autoSmuggle = false
	Config.vehicleFlingEnabled = false
	F.setAutoSmuggleFirstPerson(false)
	F.forceRestoreAllNoclip()
	F.restoreSmugglePromptSettings()
	F.stopThread("autoSmuggle")
	F.stopThread("vehicleFling")
	F.stopThread("promptHoldZero")
	F.stopThread("promptHoldZeroSweep")
	F.stopThread("autoWork")
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	table.clear(conns)
	espApi.clear()
	local vehicle = F.findMyVehicle()
	if vehicle then
		F.resetVehicleDriveBoost(vehicle)
		F.hardRestoreCollision(vehicle)
		F.setVehicleAnchored(vehicle, false)
		F.liftVehicleIfUnderground(vehicle)
	end
	local char = F.getCharacter()
	if char then F.restoreCharacterCollision(char) end
	teleportBusy = false
	Runtime.promptHoldZeroActiveUntil = 0
	Runtime.lastPromptHoldZeroPulseAt = 0
	Runtime.heartbeatSpikeStrikes = 0
	Runtime.lastAntiCrashAt = 0
	table.clear(Runtime.visiblePrompts)
	F.notify("выгружен")
end

function M.mount(ctx)
	if mounted then return end
	mounted = true
	F.clearEmergencyStop()
	F.setAutoSmuggleFirstPerson(false)
	ctxRef.player = ctx.player
	F.loadConfig()
	F.initEspApi()
	local startupChar = F.getCharacter()
	if startupChar then F.restoreCharacterCollision(startupChar) end
	if Config.gatesRemoved then F.setGatesRemoved(true) end
	table.clear(Runtime.visiblePrompts)
	Runtime.promptHoldZeroActiveUntil = 0
	Runtime.lastPromptHoldZeroPulseAt = 0
	Runtime.lastEspRefreshAt = 0
	Runtime.lastFirstPersonApplyAt = 0
	Runtime.heartbeatSpikeStrikes = 0
	Runtime.lastAntiCrashAt = 0
	Runtime.lastHeartbeatAt = os.clock()

	for _, player in ipairs(Players:GetPlayers()) do
		espApi.bind(player)
	end
	F.trackConn(Players.PlayerAdded:Connect(function(player)
		espApi.bind(player)
	end))
	F.trackConn(ProximityPromptService.PromptShown:Connect(function(prompt)
		Runtime.trackVisiblePrompt(prompt, true)
		if Config.forcePromptHoldZero then
			Runtime.armPromptHoldZeroWindow(PERF.promptHoldZeroActionWindow)
			F.forcePromptHoldZero(prompt)
		end
	end))
	F.trackConn(ProximityPromptService.PromptHidden:Connect(function(prompt)
		Runtime.trackVisiblePrompt(prompt, false)
	end))

	F.trackConn(UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.KeyCode == Enum.KeyCode.End then
			F.requestEmergencyStop("END: экстренная остановка")
			return
		end
		if input.KeyCode == Enum.KeyCode.S and Config.vehicleStopOnS and F.getVehicle() then
			F.instantStopVehicle()
		end
	end))

	local hum = F.getHumanoid()
	if hum then
		F.trackConn(hum:GetPropertyChangedSignal("SeatPart"):Connect(function()
			F.trackVehicleFromSeat(hum.SeatPart)
			local vehicle = F.getVehicle()
			if vehicle and Config.vehicleBoostEnabled then
				F.applyVehicleDriveBoost(vehicle)
			end
		end))
		F.trackVehicleFromSeat(hum.SeatPart)
	end

	F.mountMain(ctx)
	F.mountFeatures(ctx)
	F.mountSettings(ctx)
	F.applyPromptHoldZeroSweep()
	F.runPromptHoldZeroLoop()

	F.trackConn(RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local dt = now - (Runtime.lastHeartbeatAt > 0 and Runtime.lastHeartbeatAt or now)
		Runtime.lastHeartbeatAt = now
		if Runtime.maybeTriggerAntiCrash(now, dt) then
			return
		end
		if firstPersonAutoActive then
			if (now - Runtime.lastFirstPersonApplyAt) >= PERF.firstPersonRefreshInterval then
				F.applyFirstPersonCamera()
				Runtime.lastFirstPersonApplyAt = now
			end
		end
		if Config.noclipFoot or Config.noclipVehicles or routeNoclipActive then
			local interval = (routeNoclipActive or teleportBusy) and PERF.noclipUpdateIntervalRoute or PERF.noclipUpdateIntervalIdle
			if (now - lastNoclipUpdateAt) >= interval then
				F.updateNoclip()
				lastNoclipUpdateAt = now
			end
		end
		if Config.espEnabled and (now - Runtime.lastEspRefreshAt) >= PERF.espRefreshInterval then
			espApi.refresh()
			Runtime.lastEspRefreshAt = now
		end
		if Config.vehicleBoostEnabled then
			local vehicle = F.getVehicle()
			if vehicle then
				if (now - lastBoostRetuneAt) >= PERF.boostRetuneInterval then
					F.applyVehicleDriveBoost(vehicle)
					lastBoostRetuneAt = now
				end
				F.applyVehicleBoostAssist(vehicle)
			end
		end
		if Config.autoSmuggle then
			F.hookSession("tick")
		end
	end))

	F.setStatus("готов")
	F.setPhase("idle")
	F.notify("загружен " .. BUILD)
end

return M
