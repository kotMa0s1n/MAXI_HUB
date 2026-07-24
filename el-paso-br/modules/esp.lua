return function(deps)
	deps = deps or {}
	local Players = deps.Players or game:GetService("Players")
	local Workspace = deps.Workspace or game:GetService("Workspace")
	local Config = deps.Config or {}
	local getLocalPlayer = deps.getLocalPlayer or function() return Players.LocalPlayer end
	local trackConn = deps.trackConn

	local espObjects = {}

	local function keepConn(conn)
		if type(trackConn) == "function" then
			return trackConn(conn)
		end
		return conn
	end

	local function getPlayerTeamName(player)
		if player and player.Team then return player.Team.Name end
		return "No Team"
	end

	local function getEspColor(player)
		if getPlayerTeamName(player) == "Civilian" then
			return Color3.fromRGB(255, 70, 70)
		end
		return Color3.fromRGB(70, 130, 255)
	end

	local function removeEspPlayer(userId)
		local objs = espObjects[userId]
		if not objs then return end
		for _, obj in ipairs(objs) do
			pcall(function() obj:Destroy() end)
		end
		espObjects[userId] = nil
	end

	local function setupEspForCharacter(player, char)
		if not (Config.espEnabled == true) or player == getLocalPlayer() or not char then return end
		removeEspPlayer(player.UserId)

		local color = getEspColor(player)
		local teamName = getPlayerTeamName(player)
		local objs = {}

		local highlight = Instance.new("Highlight")
		highlight.Name = "EPBR_ESP"
		highlight.Adornee = char
		highlight.FillColor = color
		highlight.OutlineColor = color
		highlight.FillTransparency = 0.5
		highlight.OutlineTransparency = 0
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.Parent = char
		table.insert(objs, highlight)

		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp then
			local bb = Instance.new("BillboardGui")
			bb.Name = "EPBR_ESPName"
			bb.Size = UDim2.new(0, 140, 0, 44)
			bb.StudsOffset = Vector3.new(0, 2.8, 0)
			bb.AlwaysOnTop = true
			bb.Parent = hrp

			local label = Instance.new("TextLabel")
			label.Size = UDim2.new(1, 0, 1, 0)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.GothamBold
			label.TextSize = 13
			label.TextStrokeTransparency = 0.4
			label.TextColor3 = color
			label.Text = player.DisplayName .. "\n[" .. teamName .. "]"
			label.Parent = bb
			table.insert(objs, bb)
		end

		espObjects[player.UserId] = objs
	end

	local function clear()
		for userId in pairs(espObjects) do
			removeEspPlayer(userId)
		end
	end

	local function refresh()
		if Config.espEnabled ~= true then
			clear()
			return
		end

		local camera = Workspace.CurrentCamera
		local camPos = camera and camera.CFrame.Position
		local maxDist = Config.espMaxDistance or 1200
		local lp = getLocalPlayer()

		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= lp then
				local char = player.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				if char and hrp and (not camPos or (hrp.Position - camPos).Magnitude <= maxDist) then
					if not espObjects[player.UserId] then
						setupEspForCharacter(player, char)
					else
						local color = getEspColor(player)
						local objs = espObjects[player.UserId]
						for _, obj in ipairs(objs) do
							if obj:IsA("Highlight") then
								obj.FillColor = color
								obj.OutlineColor = color
								obj.Adornee = char
							elseif obj:IsA("BillboardGui") then
								local tl = obj:FindFirstChildOfClass("TextLabel")
								if tl then
									tl.TextColor3 = color
									tl.Text = player.DisplayName .. "\n[" .. getPlayerTeamName(player) .. "]"
								end
							end
						end
					end
				else
					removeEspPlayer(player.UserId)
				end
			end
		end
	end

	local function bind(player)
		if player == getLocalPlayer() then return end
		keepConn(player.CharacterAdded:Connect(function(char)
			if Config.espEnabled == true then
				task.wait(0.2)
				setupEspForCharacter(player, char)
			end
		end))

		if player.Character and Config.espEnabled == true then
			setupEspForCharacter(player, player.Character)
		end

		keepConn(player:GetPropertyChangedSignal("Team"):Connect(function()
			if player.Character then
				setupEspForCharacter(player, player.Character)
			end
		end))
	end

	return {
		clear = clear,
		refresh = refresh,
		bind = bind,
	}
end
