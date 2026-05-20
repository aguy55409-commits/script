--[[
  REMOTE MANIPULATION PROBE — Potassium, in-game only.

  Kicked at the end? That's YOUR anti-cheat — not this script.
  It fires many remotes quickly; AC often kicks after the batch finishes.

  loadstring(game:HttpGet("https://raw.githubusercontent.com/aguy55409-commits/script/main/script.luau", true))()
]]

local USE_STEALTH_PAYLOAD = true

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

	_G.__ServerExploitProbeLoaded = nil
	for _, root in ipairs({ CoreGui, player:FindFirstChild("PlayerGui") }) do
		if root then
			local old = root:FindFirstChild(GUI_NAME)
			if old then
				old:Destroy()
			end
		end
	end

	local SPEED_PRESETS = {
		slow = {
			label = "Slow",
			delay = 2.0,
			timeout = 1.5,
			skipRemoteFunctions = false,
			autoCopyEvery = 5,
			flushEvery = 5,
		},
		medium = {
			label = "Medium",
			delay = 0.65,
			timeout = 1.0,
			skipRemoteFunctions = true,
			autoCopyEvery = 8,
			flushEvery = 10,
		},
		fast = {
			label = "Fast",
			delay = 0,
			timeout = 0.35,
			skipRemoteFunctions = false,
			autoCopyEvery = 12,
			flushEvery = 25,
		},
	}

	local Report = { lines = {}, allRemotes = {}, manipulable = {} }
	local screenGui, statusLabel, reportLabel, scrollFrame, pathInput
	local lineCount = 0
	local scanRunning = false
	local activeConfig = SPEED_PRESETS.medium

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

	local function copyText()
		local text = table.concat(Report.lines, "\n")
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

	local function getProbePayload()
		if USE_STEALTH_PAYLOAD then
			return "test"
		end
		return "__AC_PROBE__", "manipulate_test"
	end

	local function tryManipulate(remote)
		local finished = false
		local canManipulate = false
		local reason = "unknown"

		task.spawn(function()
			local ok, err = pcall(function()
				if remote:IsA("RemoteEvent") then
					remote:FireServer(getProbePayload())
				else
					remote:InvokeServer(getProbePayload())
				end
			end)
			canManipulate = ok
			reason = ok and "probe accepted" or tostring(err)
			finished = true
		end)

		local start = tick()
		local timeout = activeConfig.timeout
		local poll = activeConfig.delay == 0 and 0 or 0.05
		while not finished and tick() - start < timeout do
			task.wait(poll)
		end

		if not finished then
			return false, "timeout — stopped"
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
				if inst:IsA("RemoteEvent") then
					table.insert(list, inst)
				elseif inst:IsA("RemoteFunction") and not activeConfig.skipRemoteFunctions then
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
		statusLabel.Size = UDim2.new(1, -24, 0, 48)
		statusLabel.Font = Enum.Font.Gotham
		statusLabel.TextSize = 11
		statusLabel.TextWrapped = true
		statusLabel.TextColor3 = Color3.fromRGB(160, 210, 255)
		statusLabel.TextXAlignment = Enum.TextXAlignment.Left
		statusLabel.Text = "Pick a speed: Slow (safest), Medium, Fast (most kicks). Report auto-copies during scan."
		statusLabel.Parent = panel

		pathInput = Instance.new("TextBox")
		pathInput.Position = UDim2.fromOffset(12, 86)
		pathInput.Size = UDim2.new(1, -24, 0, 28)
		pathInput.BackgroundColor3 = Color3.fromRGB(12, 14, 20)
		pathInput.TextColor3 = Color3.fromRGB(255, 255, 255)
		pathInput.PlaceholderText = "Optional: ReplicatedStorage.Folder.RemoteName"
		pathInput.Font = Enum.Font.Code
		pathInput.TextSize = 12
		pathInput.Parent = panel
		Instance.new("UICorner", pathInput).CornerRadius = UDim.new(0, 6)

		scrollFrame = Instance.new("ScrollingFrame")
		scrollFrame.Position = UDim2.fromOffset(12, 122)
		scrollFrame.Size = UDim2.new(1, -24, 1, -170)
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
		reportLabel.Text = "Press Slow, Medium, or Fast to start."
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

	local function runScan(speedKey)
		if scanRunning then
			return
		end
		scanRunning = true

		activeConfig = SPEED_PRESETS[speedKey] or SPEED_PRESETS.medium

		Report.lines = {}
		Report.allRemotes = {}
		Report.manipulable = {}
		lineCount = 0

		reportLine("=== REMOTE MANIPULATION PROBE ===")
		reportLine("Player: " .. player.Name .. " | PlaceId: " .. game.PlaceId)
		reportLine("Speed: " .. activeConfig.label)
		reportLine("Delay: " .. activeConfig.delay .. "s | Timeout: " .. activeConfig.timeout .. "s per remote")
		if activeConfig.skipRemoteFunctions then
			reportLine("Mode: RemoteEvent only (skips RemoteFunction — less kicks)")
		else
			reportLine("Mode: RemoteEvent + RemoteFunction")
		end
		if USE_STEALTH_PAYLOAD then
			reportLine("Payload: stealth (no __AC_PROBE__ tag)")
		end
		reportLine("")
		reportLine("NOTE: Kicked when scan ends? Your anti-cheat flagged the batch — script does NOT call Kick.")
		reportLine("")

		local remotes = collectRemotes()
		reportLine("Found " .. #remotes .. " remotes to probe.")
		reportLine("")

		if #remotes == 0 then
			reportLine("No remotes found.")
			flushDisplay(true)
			statusLabel.Text = "No remotes."
			scanRunning = false
			return
		end

		local manipCount = 0
		local safeCount = 0

		for i, remote in ipairs(remotes) do
			if not player.Parent then
				reportLine("")
				reportLine("STOPPED: You were kicked/disconnected (anti-cheat). Partial report saved to clipboard.")
				copyText()
				scanRunning = false
				flushDisplay(true)
				return
			end

			local waitText = activeConfig.delay > 0 and string.format(" (%.1fs wait)", activeConfig.delay) or " (no delay)"
			statusLabel.Text = string.format("[%s] Probing %d/%d%s", activeConfig.label, i, #remotes, waitText)

			local ok, result = pcall(function()
				return probeOneRemote(remote, i)
			end)

			if not ok then
				local path = remote:GetFullName()
				reportLine(string.format("[%d] %s — SKIPPED (%s)", i, path, tostring(result)))
				safeCount += 1
			elseif result then
				manipCount += 1
			else
				safeCount += 1
			end

			if i % activeConfig.flushEvery == 0 or i == #remotes then
				flushDisplay(false)
			end

			if activeConfig.autoCopyEvery > 0 and i % activeConfig.autoCopyEvery == 0 then
				local copied = copyText()
				if copied and statusLabel then
					statusLabel.Text = string.format("Auto-saved report to clipboard (%d/%d)", i, #remotes)
				end
			end

			if i < #remotes and activeConfig.delay > 0 then
				task.wait(activeConfig.delay)
			end
		end

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
				reportLine("     → NOT FOUND")
			end
		end

		reportLine("")
		reportLine("========== SUMMARY ==========")
		reportLine("Manipulable: " .. manipCount)
		reportLine("Not manipulable: " .. safeCount)
		reportLine("")

		if manipCount > 0 then
			reportLine("========== PATCH THESE ==========")
			for path, info in pairs(Report.allRemotes) do
				if Report.manipulable[path] then
					reportLine("• " .. path .. " (" .. info.className .. ")")
				end
			end
		end

		flushDisplay(true)
		local copied, chars = copyText()
		statusLabel.Text = copied
			and string.format("Done — %d manipulable. Copied %d chars.", manipCount, chars)
			or string.format("Done — %d manipulable. Copy All if kicked.", manipCount)

		scanRunning = false
	end

	local makeBtn = mountGui()

	makeBtn("Slow", 8, 98, function()
		task.spawn(function()
			runScan("slow")
		end)
	end, Color3.fromRGB(35, 110, 65))

	makeBtn("Medium", 112, 98, function()
		task.spawn(function()
			runScan("medium")
		end)
	end, Color3.fromRGB(45, 100, 200))

	makeBtn("Fast", 216, 98, function()
		task.spawn(function()
			runScan("fast")
		end)
	end, Color3.fromRGB(200, 90, 45))

	makeBtn("Copy All", 320, 95, function()
		flushDisplay(true)
		local copied, chars = copyText()
		statusLabel.Text = copied and ("Copied " .. chars .. " chars.") or "Copy failed."
	end)

	makeBtn("Close", 421, 91, function()
		screenGui:Destroy()
		_G.__ServerExploitProbeLoaded = nil
	end, Color3.fromRGB(80, 85, 100))

	_G.__ServerExploitProbeLoaded = true
	-- No auto-start — you choose when to probe (less surprise kicks)

	return "OK"
end

local ok, result = xpcall(main, function(err)
	return debug.traceback(tostring(err), 2)
end)

if not ok then
	warn("[ExploitProbe] CRASHED:\n" .. tostring(result))
end
