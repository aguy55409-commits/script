--[[
  EXPLOIT PROBE — Potassium. Join game FIRST, then execute.

  loadstring(game:HttpGet("https://raw.githubusercontent.com/aguy55409-commits/script/main/script.luau", true))()

  If HttpGet fails, paste this whole file into Potassium instead.
]]

local function main()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")
	local ServerStorage = game:GetService("ServerStorage")
	local RunService = game:GetService("RunService")
	local CoreGui = game:GetService("CoreGui")

	-- Only block pure-server context (no local player). Executors run as client.
	if RunService:IsServer() and not Players.LocalPlayer then
		error("Run from Potassium while you are IN the game (client), not Studio server-only.")
	end

	local player = Players.LocalPlayer
	if not player then
		error("No LocalPlayer — you are in the menu. JOIN the game, then execute.")
	end

	local GUI_NAME = "ServerExploitProbe"
	local PROBE_TAG = "__AC_PROBE__"
	local DISPLAY_FLUSH_EVERY = 40

	-- Remove old UI so re-execute works
	_G.__ServerExploitProbeLoaded = nil
	for _, root in ipairs({ CoreGui, player:FindFirstChild("PlayerGui") }) do
		if root then
			local old = root:FindFirstChild(GUI_NAME)
			if old then
				old:Destroy()
			end
		end
	end

	local Report = {
		lines = {},
		vulnerableRemotes = {},
		linkedScripts = {},
		allRemotes = {},
	}

	local screenGui
	local statusLabel
	local reportLabel
	local scrollFrame
	local pathInput

	local lineCount = 0

	local function reportLine(text, skipPrint)
		table.insert(Report.lines, text)
		lineCount += 1
		if not skipPrint then
			print("[ExploitProbe] " .. text)
		end
	end

	local function flushDisplay(scrollToBottom)
		if not reportLabel then
			return
		end
		reportLabel.Text = table.concat(Report.lines, "\n")
		if scrollFrame and scrollToBottom then
			task.defer(function()
				scrollFrame.CanvasPosition = Vector2.new(0, scrollFrame.AbsoluteCanvasSize.Y)
			end)
		end
	end

	local function getGuiRoot()
		if gethui then
			return gethui()
		end
		return CoreGui
	end

	local function mountGui()
		screenGui = Instance.new("ScreenGui")
		screenGui.Name = GUI_NAME
		screenGui.ResetOnSpawn = false
		screenGui.IgnoreGuiInset = true
		screenGui.DisplayOrder = 99999
		screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

		local root = getGuiRoot()
		screenGui.Parent = root

		if syn and syn.protect_gui then
			pcall(function()
				syn.protect_gui(screenGui)
			end)
		end

		-- Fallback if CoreGui blocked
		if not screenGui.Parent then
			screenGui.Parent = player:WaitForChild("PlayerGui")
		end

		local panel = Instance.new("Frame")
		panel.Name = "Panel"
		panel.AnchorPoint = Vector2.new(0.5, 0.5)
		panel.Position = UDim2.fromScale(0.5, 0.5)
		panel.Size = UDim2.fromOffset(520, 500)
		panel.BackgroundColor3 = Color3.fromRGB(22, 24, 32)
		panel.BorderSizePixel = 0
		panel.Parent = screenGui

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = panel

		local title = Instance.new("TextLabel")
		title.BackgroundTransparency = 1
		title.Position = UDim2.fromOffset(12, 8)
		title.Size = UDim2.new(1, -24, 0, 24)
		title.Font = Enum.Font.GothamBold
		title.TextSize = 18
		title.TextColor3 = Color3.fromRGB(255, 255, 255)
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Text = "Exploit Probe — WORKING"
		title.Parent = panel

		statusLabel = Instance.new("TextLabel")
		statusLabel.BackgroundTransparency = 1
		statusLabel.Position = UDim2.fromOffset(12, 34)
		statusLabel.Size = UDim2.new(1, -24, 0, 36)
		statusLabel.Font = Enum.Font.Gotham
		statusLabel.TextSize = 13
		statusLabel.TextWrapped = true
		statusLabel.TextColor3 = Color3.fromRGB(160, 210, 255)
		statusLabel.TextXAlignment = Enum.TextXAlignment.Left
		statusLabel.Text = "GUI loaded. Scan starting automatically..."
		statusLabel.Parent = panel

		pathInput = Instance.new("TextBox")
		pathInput.Position = UDim2.fromOffset(12, 74)
		pathInput.Size = UDim2.new(1, -24, 0, 28)
		pathInput.BackgroundColor3 = Color3.fromRGB(12, 14, 20)
		pathInput.TextColor3 = Color3.fromRGB(255, 255, 255)
		pathInput.PlaceholderText = "Optional remote: ReplicatedStorage.Remotes.Shop"
		pathInput.PlaceholderColor3 = Color3.fromRGB(100, 105, 120)
		pathInput.Font = Enum.Font.Code
		pathInput.TextSize = 12
		pathInput.Text = ""
		pathInput.ClearTextOnFocus = false
		pathInput.Parent = panel

		local pathCorner = Instance.new("UICorner")
		pathCorner.CornerRadius = UDim.new(0, 6)
		pathCorner.Parent = pathInput

		scrollFrame = Instance.new("ScrollingFrame")
		scrollFrame.Position = UDim2.fromOffset(12, 110)
		scrollFrame.Size = UDim2.new(1, -24, 1, -158)
		scrollFrame.BackgroundColor3 = Color3.fromRGB(10, 12, 18)
		scrollFrame.BorderSizePixel = 0
		scrollFrame.ScrollBarThickness = 10
		scrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
		scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
		scrollFrame.Parent = panel

		local scrollCorner = Instance.new("UICorner")
		scrollCorner.CornerRadius = UDim.new(0, 6)
		scrollCorner.Parent = scrollFrame

		local scrollContent = Instance.new("Frame")
		scrollContent.Name = "Content"
		scrollContent.BackgroundTransparency = 1
		scrollContent.Size = UDim2.new(1, -8, 0, 0)
		scrollContent.AutomaticSize = Enum.AutomaticSize.Y
		scrollContent.Parent = scrollFrame

		reportLabel = Instance.new("TextLabel")
		reportLabel.BackgroundTransparency = 1
		reportLabel.Size = UDim2.new(1, 0, 0, 0)
		reportLabel.Font = Enum.Font.Code
		reportLabel.TextSize = 11
		reportLabel.TextColor3 = Color3.fromRGB(200, 210, 225)
		reportLabel.TextXAlignment = Enum.TextXAlignment.Left
		reportLabel.TextYAlignment = Enum.TextYAlignment.Top
		reportLabel.TextWrapped = true
		reportLabel.Text = "Loading..."
		reportLabel.AutomaticSize = Enum.AutomaticSize.Y
		reportLabel.Parent = scrollContent

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
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0, 6)
			c.Parent = b
			b.MouseButton1Click:Connect(fn)
		end

		return btn
	end

	local function getFullReportText()
		return table.concat(Report.lines, "\n")
	end

	local function copyText()
		local text = getFullReportText()
		if text == "" then
			return false, 0
		end
		if setclipboard then
			local ok = pcall(function()
				setclipboard(text)
			end)
			if ok then
				return true, #text
			end
		end
		if toclipboard then
			local ok = pcall(function()
				toclipboard(text)
			end)
			if ok then
				return true, #text
			end
		end
		return false, #text
	end

	local function collectRemotes()
		local list = {}
		local ok, err = pcall(function()
			for _, inst in ipairs(game:GetDescendants()) do
				if inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") then
					table.insert(list, inst)
				end
			end
		end)
		if not ok then
			reportLine("ERROR collecting remotes: " .. tostring(err))
		end
		table.sort(list, function(a, b)
			return a:GetFullName() < b:GetFullName()
		end)
		return list
	end

	local function linkScriptsOnce()
		reportLine("")
		reportLine("Scanning client-readable scripts (one pass)...")

		local scanRoots = {
			ReplicatedStorage,
			game:GetService("StarterGui"),
			game:GetService("StarterPack"),
			game:GetService("Workspace"),
		}

		local remoteNames = {}
		for path, info in pairs(Report.vulnerableRemotes) do
			local name = path:match("%.([^%.]+)$")
			if name then
				remoteNames[name] = path
			end
		end

		for _, root in ipairs(scanRoots) do
			if root then
				for _, inst in ipairs(root:GetDescendants()) do
					if inst:IsA("LuaSourceContainer") then
						local ok, src = pcall(function()
							return inst.Source
						end)
						if ok and type(src) == "string" and #src > 0 then
							for name, remotePath in pairs(remoteNames) do
								if string.find(src, name, 1, true) then
									local spath = inst:GetFullName()
									if not Report.linkedScripts[spath] then
										Report.linkedScripts[spath] = {
											path = spath,
											reason = "mentions " .. name,
											remote = remotePath,
										}
										reportLine("Linked script: " .. spath, true)
									end
								end
							end
						end
					end
				end
			end
		end
	end

	local function addVulnerable(remote, detail)
		local path = remote:GetFullName()
		if not Report.vulnerableRemotes[path] then
			Report.vulnerableRemotes[path] = {
				path = path,
				className = remote.ClassName,
				detail = detail,
			}
		end
	end

	local function listAllRemotes(remotes)
		reportLine("")
		reportLine("========== ALL REMOTES IN GAME (" .. #remotes .. ") ==========")

		if #remotes == 0 then
			reportLine("(none found)")
			return
		end

		local eventCount, funcCount = 0, 0
		for i, remote in ipairs(remotes) do
			local path = remote:GetFullName()
			local className = remote.ClassName
			if className == "RemoteEvent" then
				eventCount += 1
			else
				funcCount += 1
			end

			Report.allRemotes[path] = {
				index = i,
				path = path,
				className = className,
				status = "pending",
			}

			reportLine(string.format("[%d] %s (%s)", i, path, className), true)
			if i % DISPLAY_FLUSH_EVERY == 0 then
				flushDisplay(false)
				if statusLabel then
					statusLabel.Text = "Listing remotes... " .. i .. "/" .. #remotes
				end
			end
		end

		reportLine("")
		reportLine(string.format("Total: %d RemoteEvent, %d RemoteFunction", eventCount, funcCount))
		flushDisplay(true)
	end

	local function appendRemoteResults()
		reportLine("")
		reportLine("========== REMOTE LIST + PROBE RESULT ==========")

		local paths = {}
		for path in pairs(Report.allRemotes) do
			table.insert(paths, path)
		end
		table.sort(paths)

		if #paths == 0 then
			reportLine("(no remotes)")
			return
		end

		for _, path in ipairs(paths) do
			local info = Report.allRemotes[path]
			reportLine(string.format("[%d] %s (%s) — %s", info.index, path, info.className, info.status), true)
		end
		flushDisplay(true)
	end

	local function runScan()
		Report.lines = {}
		Report.vulnerableRemotes = {}
		Report.linkedScripts = {}
		Report.allRemotes = {}
		lineCount = 0

		reportLine("=== EXPLOIT PROBE ===")
		reportLine("Player: " .. player.Name)
		reportLine("PlaceId: " .. game.PlaceId)
		reportLine("GUI parent: " .. screenGui.Parent:GetFullName())
		reportLine("")

		-- 1) Client remote
		local ok1, err1 = pcall(function()
			local f = Instance.new("Folder")
			f.Name = "ExploitProbe_Test"
			f.Parent = ReplicatedStorage
			local ev = Instance.new("RemoteEvent")
			ev.Name = "Probe"
			ev.Parent = f
			ev:FireServer(PROBE_TAG, "test")
			task.wait(0.05)
			f:Destroy()
		end)
		reportLine(ok1 and "Client RemoteEvent FireServer: SENT (check server ignores)" or ("Client remote: BLOCKED " .. tostring(err1)))

		-- 2) SSS
		local ok2, res2 = pcall(function()
			local s = Instance.new("Script")
			s.Name = "ExploitProbe_SSS"
			s.Source = "warn('sss')"
			s.Parent = ServerScriptService
			task.wait(0.08)
			local g = ServerScriptService:FindFirstChild("ExploitProbe_SSS")
			if g then
				g:Destroy()
				return "STAYED"
			end
			return "gone"
		end)
		reportLine("SSS inject: " .. tostring(res2))
		if res2 == "STAYED" then
			reportLine(">>> VULNERABLE: SSS inject not blocked")
		end

		-- 3) ServerStorage
		local ok3, res3 = pcall(function()
			local p = Instance.new("Part")
			p.Name = "ExploitProbe_P"
			p.Parent = ServerStorage
			task.wait(0.08)
			local g = ServerStorage:FindFirstChild("ExploitProbe_P")
			if g then
				g:Destroy()
				return "STAYED"
			end
			return "gone"
		end)
		reportLine("ServerStorage inject: " .. tostring(res3))
		if res3 == "STAYED" then
			reportLine(">>> VULNERABLE: ServerStorage not blocked")
		end

		-- 4) List + fire all remotes
		local remotes = collectRemotes()
		listAllRemotes(remotes)

		if #remotes == 0 then
			reportLine("")
			reportLine("WARNING: This game has ZERO remotes. Nothing to fire.")
			reportLine("Your game may load remotes later — re-run after joining.")
		else
			reportLine("")
			reportLine("========== FIRING REMOTES (probe) ==========")
		end

		local sent, blocked = 0, 0
		local total = #remotes
		for i, remote in ipairs(remotes) do
			local path = remote:GetFullName()
			local entry = Report.allRemotes[path]

			if statusLabel and i % 10 == 0 then
				statusLabel.Text = string.format("Probing remotes %d/%d...", i, total)
			end

			local ok, err = pcall(function()
				if remote:IsA("RemoteEvent") then
					remote:FireServer(PROBE_TAG, "probe", i)
				else
					remote:InvokeServer(PROBE_TAG, "probe", i)
				end
			end)

			if ok then
				sent += 1
				if entry then
					entry.status = "REACHABLE"
				end
				addVulnerable(remote, "FireServer/InvokeServer returned no error")
			else
				blocked += 1
				if entry then
					entry.status = "BLOCKED — " .. tostring(err)
				end
			end
		end
		reportLine("")
		reportLine(string.format("Probe: %d reachable, %d blocked (of %d total)", sent, blocked, total))
		flushDisplay(false)

		appendRemoteResults()

		-- 5) Custom path
		if pathInput and pathInput.Text ~= "" then
			local customOk, customErr = pcall(function()
				local obj = game
				for part in string.gmatch(pathInput.Text, "[^%.]+") do
					obj = obj:WaitForChild(part, 2)
				end
				if obj:IsA("RemoteEvent") then
					obj:FireServer(PROBE_TAG, "custom")
				elseif obj:IsA("RemoteFunction") then
					obj:InvokeServer(PROBE_TAG, "custom")
				else
					error("not a remote")
				end
			end)
			if customOk then
				reportLine("Custom OK: " .. pathInput.Text)
			else
				reportLine("Custom FAIL: " .. tostring(customErr))
			end
		end

		linkScriptsOnce()

		reportLine("")
		reportLine("========== PATCH IN STUDIO ==========")
		local n = 0
		for path, info in pairs(Report.vulnerableRemotes) do
			n += 1
			reportLine(n .. ". " .. path .. " (" .. info.className .. ")")
			reportLine("   " .. info.detail)
		end
		if n == 0 then
			reportLine("No reachable remotes OR game has no remotes yet.")
		end

		flushDisplay(true)

		local totalRemotes = 0
		for _ in pairs(Report.allRemotes) do
			totalRemotes += 1
		end
		local chars = #getFullReportText()
		statusLabel.Text = string.format(
			"Done — %d remotes, %d lines, %d reachable. Copy = FULL report (%d chars).",
			totalRemotes,
			lineCount,
			n,
			chars
		)

		-- Auto-copy full report so nothing is lost
		local copied, _ = copyText()
		if copied then
			statusLabel.Text = statusLabel.Text .. " Auto-copied!"
		end
	end

	local makeBtn = mountGui()

	makeBtn("Run Scan", 10, 90, function()
		statusLabel.Text = "Scanning..."
		task.spawn(runScan)
	end)

	makeBtn("Copy All", 108, 88, function()
		flushDisplay(true)
		local copied, chars = copyText()
		if copied then
			statusLabel.Text = string.format("Copied ALL %d lines (%d chars) to clipboard.", lineCount, chars)
		else
			statusLabel.Text = string.format("Copy failed. Scroll log, Ctrl+A/C. Report has %d chars.", chars)
		end
	end)

	makeBtn("Close", 184, 70, function()
		screenGui:Destroy()
		_G.__ServerExploitProbeLoaded = nil
	end, Color3.fromRGB(80, 85, 100))

	_G.__ServerExploitProbeLoaded = true

	-- AUTO RUN so user sees it DO something immediately
	task.spawn(function()
		task.wait(0.3)
		runScan()
	end)

	return "OK"
end

-- Top-level error catcher — shows why loadstring "does nothing"
local ok, result = xpcall(main, function(err)
	return debug.traceback(tostring(err), 2)
end)

if not ok then
	warn("[ExploitProbe] CRASHED:\n" .. tostring(result))
	if gethui or game:GetService("CoreGui") then
		local sg = Instance.new("ScreenGui")
		sg.Name = "ExploitProbe_Error"
		sg.ResetOnSpawn = false
		sg.DisplayOrder = 99999
		sg.Parent = gethui and gethui() or game:GetService("CoreGui")
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromOffset(500, 200)
		t.Position = UDim2.fromScale(0.5, 0.5)
		t.AnchorPoint = Vector2.new(0.5, 0.5)
		t.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
		t.TextColor3 = Color3.fromRGB(255, 100, 100)
		t.TextWrapped = true
		t.Font = Enum.Font.Code
		t.TextSize = 14
		t.Text = "[ExploitProbe ERROR]\n" .. tostring(result)
		t.Parent = sg
	end
else
	print("[ExploitProbe] Started:", result)
end
