--[[
  UNIVERSAL SPEED TEST — works in any Roblox game (Potassium)

  Auto-finds speed remotes + stats, tries apply/add + WalkSpeed + bursts.
  No treadmill required (optional if game has one).

  loadstring(game:HttpGet("https://raw.githubusercontent.com/aguy55409-commits/script/main/speed-test.luau", true))()
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

if RunService:IsServer() and not Players.LocalPlayer then
	error("Run on client while in-game.")
end

local player = Players.LocalPlayer
if not player then
	error("Join a game first.")
end

local GUI_NAME = "UniversalSpeedTest"

local SKIP_REMOTE = {
	"admin", "kick", "ban", "hdadmin", "prompt", "gamepass", "purchase",
	"product", "devproduct", "robux", "shop", "verify", "anticheat", "ac_",
	"chat", "teleport", "spectate", "revive", "slap", "party", "iris",
}

local SPEED_REMOTE_KEYWORDS = {
	"speed", "walk", "sprint", "run", "velocity", "fast", "slow",
	"treadmill", "boost", "mult", "pace", "move", "dash",
}

local SPEED_STAT_NAMES = {
	"Speed", "WalkSpeed", "Sprint", "Velocity", "MoveSpeed", "RunSpeed",
}

local running = false
local ticksPerBurst = 25
local burstDelay = 0.05
local targetSpeed = 100
local stepSpeed = 500
local useClientWalk = true

local discoveredRemotes = {}
local discoveredStats = {}
local workingRemotes = {}
local logLines = {}
local statusLabel
local contextLabel
local liveLabel
local rateLabel
local logLabel
local ticksBox
local delayBox
local targetBox
local stepBox
local heartbeatConn = nil

local fireTouch = firetouchinterest
	or (syn and syn.firetouchinterest)
	or (fluxus and fluxus.firetouchinterest)

local function log(text)
	table.insert(logLines, text)
	if #logLines > 70 then
		table.remove(logLines, 1)
	end
	print("[SpeedTest] " .. text)
	if logLabel then
		logLabel.Text = table.concat(logLines, "\n")
	end
end

local function shouldSkip(name, path)
	local s = string.lower(name .. " " .. path)
	for _, w in SKIP_REMOTE do
		if string.find(s, w, 1, true) then
			return true
		end
	end
	return false
end

local function looksLikeSpeedRemote(name)
	local n = string.lower(name)
	for _, kw in SPEED_REMOTE_KEYWORDS do
		if string.find(n, kw, 1, true) then
			return true
		end
	end
	return false
end

local function parseNum(v)
	if type(v) == "number" then
		return v
	end
	if type(v) == "string" then
		return tonumber(v:gsub(",", ""))
	end
	return nil
end

-- === Discover stats (leaderstats, humanoid, attributes) ===
local function readStat(entry)
	if entry.kind == "leaderstat" then
		local ls = player:FindFirstChild("leaderstats")
		local s = ls and ls:FindFirstChild(entry.name)
		if s and (s:IsA("NumberValue") or s:IsA("IntValue") or s:IsA("StringValue")) then
			return s.Value
		end
	elseif entry.kind == "humanoid" then
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			return hum[entry.name]
		end
	elseif entry.kind == "attr" then
		return player:GetAttribute(entry.name) or (player.Character and player.Character:GetAttribute(entry.name))
	end
	return nil
end

local function snapshotStats()
	local snap = {}
	for _, entry in discoveredStats do
		snap[entry.id] = readStat(entry)
	end
	return snap
end

local function scanStats()
	table.clear(discoveredStats)
	local id = 0

	local ls = player:FindFirstChild("leaderstats")
	if ls then
		for _, child in ls:GetChildren() do
			if child:IsA("NumberValue") or child:IsA("IntValue") or child:IsA("StringValue") then
				local n = string.lower(child.Name)
				for _, want in SPEED_STAT_NAMES do
					if string.find(n, string.lower(want), 1, true) or n == "speed" then
						id += 1
						table.insert(discoveredStats, {
							id = id,
							kind = "leaderstat",
							name = child.Name,
							label = "leaderstats." .. child.Name,
						})
						break
					end
				end
			end
		end
	end

	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		id += 1
		table.insert(discoveredStats, { id = id, kind = "humanoid", name = "WalkSpeed", label = "Humanoid.WalkSpeed" })
		id += 1
		table.insert(discoveredStats, { id = id, kind = "humanoid", name = "JumpPower", label = "Humanoid.JumpPower" })
	end

	for _, name in ipairs({ "Speed", "WalkSpeed", "MoveSpeed", "SprintSpeed" }) do
		local v = player:GetAttribute(name)
		if v ~= nil then
			id += 1
			table.insert(discoveredStats, { id = id, kind = "attr", name = name, label = "attr." .. name })
		end
	end

	return #discoveredStats
end

-- === Discover remotes in common containers ===
local function scanRemotes()
	table.clear(discoveredRemotes)
	local roots = { ReplicatedStorage, game:GetService("ReplicatedFirst") }

	for _, root in roots do
		for _, inst in root:GetDescendants() do
			if inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") then
				local path = inst:GetFullName()
				if not shouldSkip(inst.Name, path) and looksLikeSpeedRemote(inst.Name) then
					table.insert(discoveredRemotes, {
						instance = inst,
						name = inst.Name,
						path = path,
						kind = inst.ClassName,
					})
				end
			end
		end
	end

	-- Always try well-known names if present (your game + common patterns)
	local known = {
		"ReplicatedStorage.Remotes.TreadmillSignal",
		"ReplicatedStorage.Remotes.SetCustomSpeed",
		"ReplicatedStorage.Remotes.UpdateSpeed",
		"ReplicatedStorage.Remotes.CheckGoldTreadmill",
	}
	for _, p in known do
		local parts = string.split(p, ".")
		local obj = game
		for i = 2, #parts do
			obj = obj and obj:FindFirstChild(parts[i])
		end
		if obj and (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")) then
			local found = false
			for _, r in discoveredRemotes do
				if r.instance == obj then
					found = true
					break
				end
			end
			if not found then
				table.insert(discoveredRemotes, {
					instance = obj,
					name = obj.Name,
					path = obj:GetFullName(),
					kind = obj.ClassName,
				})
			end
		end
	end

	return #discoveredRemotes
end

local function formatSnapshot(snap)
	local parts = {}
	for _, entry in discoveredStats do
		local v = snap[entry.id]
		if v ~= nil then
			table.insert(parts, entry.label .. "=" .. tostring(v))
		end
	end
	return #parts > 0 and table.concat(parts, " | ") or "no stats"
end

local function anyStatChanged(before, after)
	for _, entry in discoveredStats do
		if tostring(before[entry.id]) ~= tostring(after[entry.id]) then
			return true, entry.label, before[entry.id], after[entry.id]
		end
	end
	return false
end

local function updateLiveUI(extra)
	local snap = snapshotStats()
	if liveLabel then
		liveLabel.Text = formatSnapshot(snap)
	end
	if contextLabel then
		contextLabel.Text = string.format(
			"Game: %s | Remotes: %d | Stats: %d%s",
			game.Name,
			#discoveredRemotes,
			#discoveredStats,
			extra and (" | " .. extra) or ""
		)
	end
end

local function fireRemote(inst, args)
	if inst:IsA("RemoteEvent") then
		inst:FireServer(table.unpack(args))
	else
		inst:InvokeServer(table.unpack(args))
	end
end

local function buildPayloads(amount)
	local n, s = amount, tostring(amount)
	return {
		{ label = "n", args = { n } },
		{ label = "str", args = { s } },
		{ label = "Speed,n", args = { "Speed", n } },
		{ label = "speed,n", args = { "speed", n } },
		{ label = "set,n", args = { "set", n } },
		{ label = "Add,n", args = { "Add", n } },
		{ label = "true", args = { true } },
		{ label = "empty", args = {} },
		{ label = "tick", args = { "tick" } },
	}
end

local function applyClientSpeed(amount)
	if not useClientWalk then
		return
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = math.clamp(amount, 0, 500)
		hum.JumpPower = math.clamp(amount / 4, 50, 500)
	end
end

local function runScan()
	scanStats()
	scanRemotes()
	log("=== SCAN (any game) ===")
	log(string.format("Stats: %d | Remotes: %d", #discoveredStats, #discoveredRemotes))

	for _, entry in discoveredStats do
		log("  stat: " .. entry.label .. " = " .. tostring(readStat(entry)))
	end
	for i, r in ipairs(discoveredRemotes) do
		if i <= 12 then
			log(string.format("  remote: %s (%s)", r.name, r.kind))
		end
	end
	if #discoveredRemotes > 12 then
		log(string.format("  ... +%d more remotes", #discoveredRemotes - 12))
	end

	updateLiveUI()
end

local function runProbe()
	targetSpeed = tonumber(targetBox.Text) or targetSpeed
	stepSpeed = tonumber(stepBox.Text) or stepSpeed
	ticksPerBurst = math.clamp(tonumber(ticksBox.Text) or 15, 1, 100)

	runScan()
	table.clear(workingRemotes)

	log("=== PROBE (find what moves stats) ===")
	if #discoveredRemotes == 0 then
		log("No speed remotes found — will use client WalkSpeed only.")
	end

	for _, remote in discoveredRemotes do
		local bestGain = -1
		local bestTrial = nil

		for _, trial in buildPayloads(targetSpeed) do
			local before = snapshotStats()
			local ok, err = pcall(function()
				for _ = 1, math.min(ticksPerBurst, 10) do
					fireRemote(remote.instance, trial.args)
				end
			end)
			if ok then
				task.wait(0.2)
				local after = snapshotStats()
				local changed, label, oldV, newV = anyStatChanged(before, after)
				if changed then
					local gain = 1
					local ob, oa = parseNum(oldV), parseNum(newV)
					if ob and oa then
						gain = oa - ob
					end
					if gain > bestGain then
						bestGain = gain
						bestTrial = trial
						log(string.format("  OK %s [%s] %s %s->%s", remote.name, trial.label, label, oldV, newV))
					end
				end
			else
				log("  err " .. remote.name .. ": " .. tostring(err))
			end
			task.wait(0.05)
		end

		if bestTrial then
			table.insert(workingRemotes, { remote = remote, trial = bestTrial })
		end
	end

	-- Client-only test
	local before = snapshotStats()
	applyClientSpeed(targetSpeed)
	task.wait(0.15)
	local after = snapshotStats()
	local changed = anyStatChanged(before, after)
	log(changed and "  OK client WalkSpeed changed a stat" or "  .. client WalkSpeed (movement only, stat may not change)")

	log(string.format("Working remotes: %d — press Start", #workingRemotes))
	updateLiveUI(#workingRemotes .. " working")
end

local function stopBoost()
	running = false
	if heartbeatConn then
		heartbeatConn:Disconnect()
		heartbeatConn = nil
	end
end

local function runBoostLoop()
	if running then
		return
	end

	runScan()
	if #discoveredRemotes == 0 and #discoveredStats == 0 then
		log("Nothing found — wait for character/leaderstats to load.")
		return
	end

	running = true
	ticksPerBurst = math.clamp(tonumber(ticksBox.Text) or 25, 1, 200)
	burstDelay = math.clamp(tonumber(delayBox.Text) or 0.05, 0, 2)
	targetSpeed = tonumber(targetBox.Text) or targetSpeed
	stepSpeed = tonumber(stepBox.Text) or stepSpeed
	local useMax = burstDelay <= 0
	local amount = targetSpeed
	local burstNum = 0

	log("=== BOOST (everywhere mode) ===")
	log(string.format("Target %s | +%s/tick | %d remotes", amount, stepSpeed, math.max(#workingRemotes, #discoveredRemotes)))

	local function doBoost()
		applyClientSpeed(amount)

		local remotesToFire = #workingRemotes > 0 and workingRemotes or discoveredRemotes
		for _, item in remotesToFire do
			local remote = item.remote or item
			local trial = item.trial
			local args
			if trial then
				args = {}
				for _, v in trial.args do
					if type(v) == "number" then
						table.insert(args, amount)
					elseif type(v) == "string" and v ~= "Speed" and v ~= "speed" and v ~= "set" and v ~= "Add" and v ~= "tick" then
						table.insert(args, tostring(amount))
					else
						table.insert(args, v)
					end
				end
			else
				args = { amount }
			end

			pcall(function()
				for _ = 1, ticksPerBurst do
					if not running then
						break
					end
					fireRemote(remote.instance, args)
				end
			end)
		end

		-- Treadmill / touch games
		if fireTouch then
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp then
				for _, inst in Workspace:GetDescendants() do
					if inst:IsA("BasePart") then
						local n = string.lower(inst.Name)
						if string.find(n, "treadmill", 1, true) or string.find(n, "belt", 1, true) then
							pcall(fireTouch, inst, hrp, 0)
							pcall(fireTouch, inst, hrp, 1)
						end
					end
				end
			end
		end
	end

	stopBoost()
	if useMax then
		heartbeatConn = RunService.Heartbeat:Connect(function()
			if running then
				doBoost()
			end
		end)
	end

	while running do
		if not player.Parent then
			break
		end

		burstNum += 1
		local before = snapshotStats()

		if not useMax then
			doBoost()
			if burstDelay > 0 then
				task.wait(burstDelay)
			end
		else
			task.wait(0.4)
		end

		local after = snapshotStats()
		local changed, label, o, n = anyStatChanged(before, after)

		if burstNum % 4 == 0 or changed then
			log(string.format("burst %d | %s%s", burstNum, changed and (label .. " " .. tostring(o) .. "->" .. tostring(n) .. " | ") or "", formatSnapshot(after)))
		end

		statusLabel.Text = string.format("Boost %d | target %s | %s", burstNum, amount, changed and "CHANGED" or "firing...")
		updateLiveUI()

		amount = math.min(amount + stepSpeed, 1e15)
	end

	stopBoost()
	log("Stopped. " .. formatSnapshot(snapshotStats()))
	statusLabel.Text = "Stopped"
end

-- === GUI ===
for _, root in ipairs({ CoreGui, player:FindFirstChild("PlayerGui") }) do
	local old = root and root:FindFirstChild(GUI_NAME)
	if old then
		old:Destroy()
	end
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = GUI_NAME
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 99998
screenGui.Parent = (gethui and gethui()) or CoreGui
if syn and syn.protect_gui then
	pcall(syn.protect_gui, screenGui)
end

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(440, 500)
panel.BackgroundColor3 = Color3.fromRGB(24, 26, 34)
panel.Parent = screenGui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(12, 8)
title.Size = UDim2.new(1, -24, 0, 22)
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Universal Speed Test"
title.Parent = panel

contextLabel = Instance.new("TextLabel")
contextLabel.BackgroundTransparency = 1
contextLabel.Position = UDim2.fromOffset(12, 30)
contextLabel.Size = UDim2.new(1, -24, 0, 28)
contextLabel.Font = Enum.Font.Gotham
contextLabel.TextSize = 10
contextLabel.TextWrapped = true
contextLabel.TextColor3 = Color3.fromRGB(160, 210, 255)
contextLabel.TextXAlignment = Enum.TextXAlignment.Left
contextLabel.Text = "Works in any game — auto scan"
contextLabel.Parent = panel

liveLabel = Instance.new("TextLabel")
liveLabel.BackgroundTransparency = 1
liveLabel.Position = UDim2.fromOffset(12, 58)
liveLabel.Size = UDim2.new(1, -24, 0, 36)
liveLabel.Font = Enum.Font.Code
liveLabel.TextSize = 10
liveLabel.TextWrapped = true
liveLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
liveLabel.TextXAlignment = Enum.TextXAlignment.Left
liveLabel.Text = "..."
liveLabel.Parent = panel

statusLabel = Instance.new("TextLabel")
statusLabel.BackgroundTransparency = 1
statusLabel.Position = UDim2.fromOffset(12, 96)
statusLabel.Size = UDim2.new(1, -24, 0, 22)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 10
statusLabel.TextColor3 = Color3.fromRGB(180, 190, 210)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Text = "Scan → Probe → Start (no treadmill needed)"
statusLabel.Parent = panel

local function numBox(label, y, default)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromOffset(12, y)
	l.Size = UDim2.fromOffset(120, 18)
	l.Font = Enum.Font.Gotham
	l.TextSize = 10
	l.TextColor3 = Color3.fromRGB(180, 185, 200)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = label
	l.Parent = panel

	local b = Instance.new("TextBox")
	b.Position = UDim2.fromOffset(138, y - 2)
	b.Size = UDim2.fromOffset(290, 22)
	b.BackgroundColor3 = Color3.fromRGB(14, 16, 22)
	b.TextColor3 = Color3.fromRGB(255, 255, 255)
	b.Font = Enum.Font.Code
	b.TextSize = 11
	b.Text = tostring(default)
	b.ClearTextOnFocus = false
	b.Parent = panel
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
	return b
end

targetBox = numBox("Target speed", 122, targetSpeed)
stepBox = numBox("Add per burst", 148, stepSpeed)
ticksBox = numBox("Ticks/burst", 174, ticksPerBurst)
delayBox = numBox("Burst delay", 200, burstDelay)

local scroll = Instance.new("ScrollingFrame")
scroll.Position = UDim2.fromOffset(12, 228)
scroll.Size = UDim2.new(1, -24, 1, -168)
scroll.BackgroundColor3 = Color3.fromRGB(12, 14, 20)
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 8
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent = panel
Instance.new("UICorner", scroll).CornerRadius = UDim.new(0, 6)

logLabel = Instance.new("TextLabel")
logLabel.BackgroundTransparency = 1
logLabel.Size = UDim2.new(1, -8, 0, 0)
logLabel.Font = Enum.Font.Code
logLabel.TextSize = 10
logLabel.TextColor3 = Color3.fromRGB(200, 210, 225)
logLabel.TextXAlignment = Enum.TextXAlignment.Left
logLabel.TextYAlignment = Enum.TextYAlignment.Top
logLabel.TextWrapped = true
logLabel.AutomaticSize = Enum.AutomaticSize.Y
logLabel.Parent = scroll

local function btn(text, x, w, fn, col)
	local b = Instance.new("TextButton")
	b.Position = UDim2.fromOffset(x, 458)
	b.Size = UDim2.fromOffset(w, 34)
	b.BackgroundColor3 = col or Color3.fromRGB(45, 120, 70)
	b.TextColor3 = Color3.fromRGB(255, 255, 255)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 11
	b.Text = text
	b.Parent = panel
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
	b.MouseButton1Click:Connect(fn)
end

btn("Scan", 8, 50, runScan, Color3.fromRGB(60, 100, 160))
btn("Probe", 62, 50, function()
	task.spawn(runProbe)
end, Color3.fromRGB(80, 130, 90))
btn("Start", 116, 50, function()
	task.spawn(runBoostLoop)
end)
btn("Stop", 170, 50, function()
	stopBoost()
	log("Stop")
end, Color3.fromRGB(180, 70, 70))
btn("Walk", 224, 50, function()
	useClientWalk = not useClientWalk
	log(useClientWalk and "Client WalkSpeed ON" or "Client WalkSpeed OFF")
end, Color3.fromRGB(90, 90, 140))
btn("X", 278, 50, function()
	stopBoost()
	screenGui:Destroy()
end, Color3.fromRGB(80, 85, 100))

player.CharacterAdded:Connect(function()
	task.wait(1)
	runScan()
end)

task.spawn(function()
	while screenGui.Parent do
		updateLiveUI()
		task.wait(0.35)
	end
end)

runScan()
log("Universal mode: any game, any map.")
log("Scan finds remotes/stats | Probe finds what works | Start boosts.")
log("Delay 0 = max speed (every frame). Walk = toggle client speed.")
