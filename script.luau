--[[
  REMOTE MANIPULATION PROBE — Potassium, in-game only.

  loadstring(game:HttpGet("https://raw.githubusercontent.com/aguy55409-commits/script/main/script.luau", true))()
]]

local PROBE_TIMEOUT = 1.25

local function main()
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local CoreGui = game:GetService("CoreGui")

	if RunService:IsServer() and not Players.LocalPlayer then
		error("Execute from Potassium while in-game (client).")
	end

	local player = Players.LocalPlayer
	if not player then
		error("Join the game first, then execute.")
	end

	local GUI_NAME = "ServerExploitProbe"
	local PROBE_TAG = "__AC_PROBE__"

	_G.__ServerExploitProbeLoaded = nil
	for _, root in ipairs({ CoreGui, player:FindFirstChild("PlayerGui") }) do
		if root then
			local old = root:FindFirstChild(GUI_NAME)
			if old then
				old:Destroy()
			end
		end
	end

	local Report = { lines = {}, allRemotes = {}, manipulable = {} }
	local screenGui, statusLabel, reportLabel, scrollFrame, pathInput
	local lineCount = 0

	local function reportLine(text)
		table.insert(Report.lines, text)
		lineCount += 1
		print("[ExploitProbe] " .. text)
	end

	local function flushDisplay(scrollBottom)
		if reportLabel then
			reportLabel.Text = table.concat(Report.lines, "\n")
		end
		if scrollBottom and scrollFrame then
			task.defer(function()
				scrollFrame.CanvasPosition = Vector2.new(0, scrollFrame.AbsoluteCanvasSize.Y)
			end)
		end
	end

	local function getFullReportText()
		return table.concat(Report.lines, "\n")
	end

	local function copyText()
		local text = getFullReportText()
		if text == "" then
			return false, 0
		end
		for _, fn in ipairs({ setclipboard, toclipboard }) do
			if fn then
				local ok = pcall(function()
					fn(text)
				end)
				if ok then
					return true, #text
				end
			end
		end
		return false, #text
	end

	-- One attempt per remote. Timeout = stop waiting (cannot manipulate). No spam, no retries.
	local function tryManipulate(remote)
		local finished = false
		local canManipulate = false
		local reason = "unknown"

		task.spawn(function()
			local ok, err = pcall(function()
				if remote:IsA("RemoteEvent") then
					remote:FireServer(PROBE_TAG, "manipulate_test")
				else
					remote:InvokeServer(PROBE_TAG, "manipulate_test")
				end
			end)
			canManipulate = ok
			reason = ok and "probe accepted" or tostring(err)
			finished = true
		end)

		local start = tick()
		while not finished and tick() - start < PROBE_TIMEOUT do
			task.wait(0.05)
		end

		if not finished then
			return false, "timeout — stopped (not manipulable)"
		end

		if canManipulate then
			return true, reason
		end
		return false, reason
	end

	local function collectRemotes()
		local list = {}
		pcall(function()
			for _, inst in ipairs(game:GetDescendants()) do
				if inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") then
					table.insert(list, inst)
				end
			end
		end)
		table.sort(list, function(a, b)
			return a:GetFullName() < b:GetFullName()
		end)
		return list
	end

	local function mountGui()
		screenGui = Instance.new("ScreenGui")
		screenGui.Name = GUI_NAME
		screenGui.ResetOnSpawn = false
		screenGui.IgnoreGuiInset = true
		screenGui.DisplayOrder = 99999
		screenGui.Parent = (gethui and gethui()) or CoreGui
		if syn and syn.protect_gui then
			pcall(syn.protect_gui, screenGui)
		end
		if not screenGui.Parent then
			screenGui.Parent = player:WaitForChild("PlayerGui")
		end

		local panel = Instance.new("Frame")
		panel.AnchorPoint = Vector2.new(0.5, 0.5)
		panel.Position = UDim2.fromScale(0.5, 0.5)
		panel.Size = UDim2.fromOffset(520, 500)
		panel.BackgroundColor3 = Color3.fromRGB(22, 24, 32)
		panel.Parent = screenGui
		Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)

		local title = Instance.new("TextLabel")
		title.BackgroundTransparency = 1
		title.Position = UDim2.fromOffset(12, 8)
		title.Size = UDim2.new(1, -24, 0, 24)
		title.Font = Enum.Font.GothamBold
		title.TextSize = 17
		title.TextColor3 = Color3.fromRGB(255, 255, 255)
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Text = "Remote Manipulation Probe"
		title.Parent = panel

		statusLabel = Instance.new("TextLabel")
		statusLabel.BackgroundTransparency = 1
		statusLabel.Position = UDim2.fromOffset(12, 34)
		statusLabel.Size = UDim2.new(1, -24, 0, 36)
		statusLabel.Font = Enum.Font.Gotham
		statusLabel.TextSize = 12
		statusLabel.TextWrapped = true
		statusLabel.TextColor3 = Color3.fromRGB(160, 210, 255)
		statusLabel.TextXAlignment = Enum.TextXAlignment.Left
		statusLabel.Text = "One probe per remote — stops each if not manipulable."
		statusLabel.Parent = panel

		pathInput = Instance.new("TextBox")
		pathInput.Position = UDim2.fromOffset(12, 74)
		pathInput.Size = UDim2.new(1, -24, 0, 28)
		pathInput.BackgroundColor3 = Color3.fromRGB(12, 14, 20)
		pathInput.TextColor3 = Color3.fromRGB(255, 255, 255)
		pathInput.PlaceholderText = "Optional: ReplicatedStorage.Folder.RemoteName"
		pathInput.Font = Enum.Font.Code
		pathInput.TextSize = 12
		pathInput.Parent = panel
		Instance.new("UICorner", pathInput).CornerRadius = UDim.new(0, 6)

		scrollFrame = Instance.new("ScrollingFrame")
		scrollFrame.Position = UDim2.fromOffset(12, 110)
		scrollFrame.Size = UDim2.new(1, -24, 1, -158)
		scrollFrame.BackgroundColor3 = Color3.fromRGB(10, 12, 18)
		scrollFrame.BorderSizePixel = 0
		scrollFrame.ScrollBarThickness = 10
		scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scrollFrame.Parent = panel
		Instance.new("UICorner", scrollFrame).CornerRadius = UDim.new(0, 6)

		local content = Instance.new("Frame")
		content.BackgroundTransparency = 1
		content.Size = UDim2.new(1, -8, 0, 0)
		content.AutomaticSize = Enum.AutomaticSize.Y
		content.Parent = scrollFrame

		reportLabel = Instance.new("TextLabel")
		reportLabel.BackgroundTransparency = 1
		reportLabel.Size = UDim2.new(1, 0, 0, 0)
		reportLabel.Font = Enum.Font.Code
		reportLabel.TextSize = 11
		reportLabel.TextColor3 = Color3.fromRGB(200, 210, 225)
		reportLabel.TextXAlignment = Enum.TextXAlignment.Left
		reportLabel.TextYAlignment = Enum.TextYAlignment.Top
		reportLabel.TextWrapped = true
		reportLabel.AutomaticSize = Enum.AutomaticSize.Y
		reportLabel.Text = ""
		reportLabel.Parent = content

		local function btn(text, x, w, fn, col)
			local b = Instance.new("TextButton")
			b.Position = UDim2.fromOffset(x, 458)
			b.Size = UDim2.fromOffset(w, 32)
			b.BackgroundColor3 = col or Color3.fromRGB(45, 100, 220)
			b.TextColor3 = Color3.fromRGB(255, 255, 255)
			b.Font = Enum.Font.GothamBold
			b.TextSize = 12
			b.Text = text
			b.Parent = panel
			Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
			b.MouseButton1Click:Connect(fn)
		end

		return btn
	end

	local function probeOneRemote(remote, index)
		local path = remote:GetFullName()
		local className = remote.ClassName

		local probeOk, canManipulate, detail = pcall(function()
			return tryManipulate(remote)
		end)

		local status
		if not probeOk then
			status = "PROBE ERROR — " .. tostring(canManipulate)
			canManipulate = false
			detail = status
		elseif canManipulate then
			status = "MANIPULABLE — " .. tostring(detail)
			Report.manipulable[path] = true
		else
			status = "NOT MANIPULABLE — " .. tostring(detail)
		end

		Report.allRemotes[path] = {
			index = index,
			path = path,
			className = className,
			status = status,
		}

		reportLine(string.format("[%d] %s (%s)", index, path, className))
		reportLine("     → " .. status)
		return canManipulate == true
	end

	local function runScan()
		Report.lines = {}
		Report.allRemotes = {}
		Report.manipulable = {}
		lineCount = 0

		reportLine("=== REMOTE MANIPULATION PROBE ===")
		reportLine("Player: " .. player.Name .. " | PlaceId: " .. game.PlaceId)
		reportLine("Rule: 1 attempt per remote, " .. PROBE_TIMEOUT .. "s max, then stop that remote.")
		reportLine("")

		local remotes = collectRemotes()
		reportLine("Found " .. #remotes .. " remotes. Probing...")
		reportLine("")

		if #remotes == 0 then
			reportLine("No remotes in game.")
			flushDisplay(true)
			statusLabel.Text = "No remotes found."
			return
		end

		local manipCount = 0
		local safeCount = 0

		for i, remote in ipairs(remotes) do
			if statusLabel then
				statusLabel.Text = string.format("Probing %d/%d...", i, #remotes)
			end

			local ok, result = pcall(function()
				return probeOneRemote(remote, i)
			end)

			if not ok then
				local path = remote:GetFullName()
				reportLine(string.format("[%d] %s — SKIPPED (probe crashed: %s)", i, path, tostring(result)))
				Report.allRemotes[path] = {
					index = i,
					path = path,
					className = remote.ClassName,
					status = "SKIPPED — " .. tostring(result),
				}
				safeCount += 1
			elseif result then
				manipCount += 1
			else
				safeCount += 1
			end

			if i % 15 == 0 then
				flushDisplay(false)
			end
		end

		-- Optional custom remote
		if pathInput and pathInput.Text ~= "" then
			reportLine("")
			reportLine("Custom: " .. pathInput.Text)
			local obj = game
			local resolveOk = pcall(function()
				for part in string.gmatch(pathInput.Text, "[^%.]+") do
					obj = obj:WaitForChild(part, 2)
				end
			end)
			if resolveOk and (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")) then
				probeOneRemote(obj, #remotes + 1)
			else
				reportLine("     → NOT FOUND or not a remote")
			end
		end

		reportLine("")
		reportLine("========== SUMMARY ==========")
		reportLine(string.format("Manipulable: %d", manipCount))
		reportLine(string.format("Not manipulable / stopped: %d", safeCount))
		reportLine("")

		if manipCount > 0 then
			reportLine("========== PATCH THESE (MANIPULABLE) ==========")
			for path, info in pairs(Report.allRemotes) do
				if Report.manipulable[path] then
					reportLine("• " .. path .. " (" .. info.className .. ")")
				end
			end
		else
			reportLine("No manipulable remotes from this probe (AC may be working).")
		end

		flushDisplay(true)

		local chars = #getFullReportText()
		statusLabel.Text = string.format("Done — %d manipulable / %d total. Report %d chars. Press Copy All.", manipCount, #remotes, chars)
	end

	local makeBtn = mountGui()

	makeBtn("Probe All", 10, 95, function()
		task.spawn(runScan)
	end)

	makeBtn("Copy All", 111, 95, function()
		flushDisplay(true)
		local copied, chars = copyText()
		statusLabel.Text = copied and ("Copied " .. chars .. " chars.") or ("Copy failed — " .. chars .. " chars in log.")
	end)

	makeBtn("Close", 212, 70, function()
		screenGui:Destroy()
		_G.__ServerExploitProbeLoaded = nil
	end, Color3.fromRGB(80, 85, 100))

	_G.__ServerExploitProbeLoaded = true

	task.spawn(function()
		task.wait(0.2)
		runScan()
	end)

	return "OK"
end

local ok, result = xpcall(main, function(err)
	return debug.traceback(tostring(err), 2)
end)

if not ok then
	warn("[ExploitProbe] CRASHED:\n" .. tostring(result))
end
