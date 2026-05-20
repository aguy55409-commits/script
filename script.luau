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
	local REMOTE_SCAN_CAP = 80

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
	}

	local screenGui
	local statusLabel
	local reportLabel
	local scrollFrame
	local pathInput

	local function reportLine(text)
		table.insert(Report.lines, text)
		print("[ExploitProbe] " .. text)
		if reportLabel then
			reportLabel.Text = table.concat(Report.lines, "\n")
			if scrollFrame then
				scrollFrame.CanvasPosition = Vector2.new(0, math.max(0, scrollFrame.AbsoluteCanvasSize.Y))
			end
		end
		task.wait()
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
		scrollFrame.ScrollBarThickness = 8
		scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
		scrollFrame.Parent = panel

		local scrollCorner = Instance.new("UICorner")
		scrollCorner.CornerRadius = UDim.new(0, 6)
		scrollCorner.Parent = scrollFrame

		reportLabel = Instance.new("TextLabel")
		reportLabel.BackgroundTransparency = 1
		reportLabel.Size = UDim2.new(1, -12, 0, 0)
		reportLabel.Position = UDim2.fromOffset(6, 6)
		reportLabel.Font = Enum.Font.Code
		reportLabel.TextSize = 11
		reportLabel.TextColor3 = Color3.fromRGB(200, 210, 225)
		reportLabel.TextXAlignment = Enum.TextXAlignment.Left
		reportLabel.TextYAlignment = Enum.TextYAlignment.Top
		reportLabel.TextWrapped = true
		reportLabel.Text = "Loading..."
		reportLabel.AutomaticSize = Enum.AutomaticSize.Y
		reportLabel.Parent = scrollFrame

		reportLabel:GetPropertyChangedSignal("TextBounds"):Connect(function()
			scrollFrame.CanvasSize = UDim2.fromOffset(0, reportLabel.TextBounds.Y + 16)
		end)

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

	local function copyText()
		local text = table.concat(Report.lines, "\n")
		if text == "" then
			return false
		end
		if setclipboard then
			local ok = pcall(function()
				setclipboard(text)
			end)
			if ok then
				return true
			end
		end
		if toclipboard then
			local ok = pcall(function()
				toclipboard(text)
			end)
			if ok then
				return true
			end
		end
		return false
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
										reportLine("Linked script: " .. spath)
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

	local function runScan()
		Report.lines = {}
		Report.vulnerableRemotes = {}
		Report.linkedScripts = {}

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

		-- 4) All remotes
		reportLine("")
		reportLine("Firing remotes...")
		local remotes = collectRemotes()
		reportLine("Found " .. #remotes .. " remotes")

		if #remotes == 0 then
			reportLine("WARNING: This game has ZERO remotes. Nothing to fire.")
			reportLine("Your game may load remotes later — re-run after joining.")
		end

		local sent, blocked = 0, 0
		for i, remote in ipairs(remotes) do
			if i > REMOTE_SCAN_CAP then
				break
			end
			local path = remote:GetFullName()
			local ok, err = pcall(function()
				if remote:IsA("RemoteEvent") then
					remote:FireServer(PROBE_TAG, "probe", i)
				else
					remote:InvokeServer(PROBE_TAG, "probe", i)
				end
			end)
			if ok then
				sent += 1
				addVulnerable(remote, "FireServer/InvokeServer returned no error")
				reportLine("REACHABLE: " .. path)
			else
				blocked += 1
				reportLine("BLOCKED: " .. path .. " | " .. tostring(err))
			end
			if i % 5 == 0 then
				task.wait()
			end
		end
		reportLine("")
		reportLine(string.format("Result: %d reachable, %d blocked/errors", sent, blocked))

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

		statusLabel.Text = "Scan done. " .. n .. " vulnerable remotes. Press Copy."
	end

	local makeBtn = mountGui()

	makeBtn("Run Scan", 10, 90, function()
		statusLabel.Text = "Scanning..."
		task.spawn(runScan)
	end)

	makeBtn("Copy", 108, 70, function()
		if copyText() then
			statusLabel.Text = "Copied to clipboard!"
		else
			statusLabel.Text = "Copy failed — select text in box manually."
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
