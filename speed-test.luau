--[[
  SPEED EXPLOIT TEST — apply + add speed, watch leaderstats.Speed (like Wins).

  Each tick: sends rising speed values to game remotes (apply/set + add amount).
  Only success = leaderstats.Speed actually changed.

  loadstring(game:HttpGet("https://raw.githubusercontent.com/aguy55409-commits/script/main/speed-test.luau", true))()
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

if RunService:IsServer() and not Players.LocalPlayer then
	error("Run on client (Potassium) while in-game.")
end

local player = Players.LocalPlayer
if not player then
	error("Join the game first.")
end

local GUI_NAME = "SpeedExploitTest"

local ACTION_REMOTES = {
	{ name = "SetCustomSpeed", path = "ReplicatedStorage.Remotes.SetCustomSpeed" },
	{ name = "UpdateSpeed", path = "ReplicatedStorage.Remotes.UpdateSpeed" },
	{ name = "TreadmillSignal", path = "ReplicatedStorage.Remotes.TreadmillSignal" },
}

local SPEED_STAT_NAME = "Speed"
local WINS_STAT_NAME = "Wins"

local running = false
local startSpeed = 1000
local stepSpeed = 10000
local maxSpeed = 1e15
local interval = 0.5

local logLines = {}
local statusLabel
local liveSpeedLabel
local logLabel
local startBox
local stepBox
local intervalBox
local bestApplyPayload = nil
local bestAddPayload = nil
local updateSpeedHooked = false

local function log(text)
	table.insert(logLines, text)
	if #logLines > 80 then
		table.remove(logLines, 1)
	end
	print("[SpeedTest] " .. text)
	if logLabel then
		logLabel.Text = table.concat(logLines, "\n")
	end
end

local function resolvePath(path)
	local obj = game
	for part in string.gmatch(path, "[^%.]+") do
		obj = obj:WaitForChild(part, 5)
		if not obj then
			return nil
		end
	end
	return obj
end

local function readLeaderstat(statName)
	local ls = player:FindFirstChild("leaderstats")
	if not ls then
		return nil
	end
	local stat = ls:FindFirstChild(statName)
	if not stat then
		return nil
	end
	if stat:IsA("NumberValue") or stat:IsA("IntValue") then
		return stat.Value
	end
	if stat:IsA("StringValue") then
		return stat.Value
	end
	return nil
end

local function getSpeedStat()
	return readLeaderstat(SPEED_STAT_NAME)
end

local function parseStatNumber(value)
	if type(value) == "number" then
		return value
	end
	if type(value) == "string" then
		local cleaned = value:gsub(",", ""):gsub("%s+", "")
		return tonumber(cleaned)
	end
	return nil
end

local function formatLiveStats()
	local speed = getSpeedStat()
	if speed == nil then
		return "(leaderstats.Speed not found yet)"
	end
	local wins = readLeaderstat(WINS_STAT_NAME)
	local line = string.format("leaderstats.Speed=%s", tostring(speed))
	if wins ~= nil then
		line ..= string.format(" | Wins=%s", tostring(wins))
	end
	return line
end

local function speedStatChanged(before, after)
	return tostring(before) ~= tostring(after)
end

local function speedStatIncreased(before, after)
	local b = parseStatNumber(before)
	local a = parseStatNumber(after)
	if b and a then
		return a > b, a - b
	end
	return speedStatChanged(before, after), nil
end

local function updateLiveSpeedLabel()
	if liveSpeedLabel then
		liveSpeedLabel.Text = "Tracking: " .. formatLiveStats()
	end
end

local function discoverSpeedStats()
	log("=== DISCOVER ===")
	local speed = getSpeedStat()
	if speed == nil then
		log("leaderstats.Speed not found — wait for stats to load.")
	else
		log(string.format("  leaderstats.Speed = %s", tostring(speed)))
	end
	local wins = readLeaderstat(WINS_STAT_NAME)
	if wins ~= nil then
		log(string.format("  leaderstats.Wins = %s", tostring(wins)))
	end
	updateLiveSpeedLabel()
end

local function hookUpdateSpeedListener()
	if updateSpeedHooked then
		return
	end
	local remote = resolvePath("ReplicatedStorage.Remotes.UpdateSpeed")
	if remote and remote:IsA("RemoteEvent") then
		remote.OnClientEvent:Connect(function(...)
			local args = { ... }
			local parts = {}
			for i, v in ipairs(args) do
				parts[i] = typeof(v) .. "=" .. tostring(v)
			end
			log("<< server UpdateSpeed: " .. table.concat(parts, ", "))
			updateLiveSpeedLabel()
		end)
		updateSpeedHooked = true
	end
end

-- Build payloads that APPLY a total speed or ADD an amount
local function buildApplyTrials(applyAmount)
	local n = applyAmount
	local s = tostring(n)
	return {
		{ label = "apply number", mode = "apply", args = { n } },
		{ label = "apply string", mode = "apply", args = { s } },
		{ label = "Speed, number", mode = "apply", args = { "Speed", n } },
		{ label = "speed, string", mode = "apply", args = { "speed", s } },
		{ label = "set, number", mode = "apply", args = { "set", n } },
	}
end

local function buildAddTrials(addAmount, applyAmount)
	local step = addAmount
	local total = applyAmount
	local cur = parseStatNumber(getSpeedStat()) or 0
	return {
		{ label = "add number", mode = "add", args = { step } },
		{ label = "add string", mode = "add", args = { tostring(step) } },
		{ label = "Add, number", mode = "add", args = { "Add", step } },
		{ label = "add speed key", mode = "add", args = { "Speed", step } },
		{ label = "apply total", mode = "apply", args = { total } },
		{ label = "apply cur+step", mode = "apply", args = { cur + step } },
	}
end

local function fireRemote(remote, args)
	if remote:IsA("RemoteEvent") then
		remote:FireServer(table.unpack(args))
	elseif remote:IsA("RemoteFunction") then
		remote:InvokeServer(table.unpack(args))
	end
end

local function tryPayload(remoteInfo, trial)
	local remote = resolvePath(remoteInfo.path)
	if not remote then
		return false, "remote missing"
	end

	local before = getSpeedStat()
	local ok, err = pcall(function()
		fireRemote(remote, trial.args)
	end)
	if not ok then
		return false, err
	end

	task.wait(0.2)
	local after = getSpeedStat()
	local changed = speedStatChanged(before, after)
	local increased, delta = speedStatIncreased(before, after)

	if trial.mode == "add" and increased then
		return true, string.format("ADDED +%s (%s -> %s)", tostring(delta or "?"), before, after), trial
	elseif trial.mode == "apply" and changed then
		return true, string.format("APPLIED (%s -> %s)", before, after), trial
	elseif changed then
		return true, string.format("CHANGED (%s -> %s)", before, after), trial
	end
	return false, "no change to leaderstats.Speed", nil
end

local function runProbeOnce()
	startSpeed = tonumber(startBox.Text) or startSpeed
	stepSpeed = tonumber(stepBox.Text) or stepSpeed

	log("=== PROBE (find apply + add payloads) ===")
	hookUpdateSpeedListener()
	bestApplyPayload = nil
	bestAddPayload = nil

	for _, info in ipairs(ACTION_REMOTES) do
		log("Probing " .. info.name .. " ...")

		for _, trial in ipairs(buildApplyTrials(startSpeed)) do
			local ok, msg, saved = tryPayload(info, trial)
			if ok then
				bestApplyPayload = { remote = info, trial = saved }
				log("  APPLY OK: " .. info.name .. " / " .. trial.label .. " — " .. msg)
				break
			else
				log("  .. apply " .. trial.label)
			end
			task.wait(0.08)
		end

		for _, trial in ipairs(buildAddTrials(stepSpeed, startSpeed)) do
			local ok, msg, saved = tryPayload(info, trial)
			if ok and trial.mode == "add" then
				bestAddPayload = { remote = info, trial = saved }
				log("  ADD OK: " .. info.name .. " / " .. trial.label .. " — " .. msg)
				break
			elseif ok then
				log("  .. " .. trial.label .. " changed stat but not pure add")
			else
				log("  .. add " .. trial.label)
			end
			task.wait(0.08)
		end
	end

	updateLiveSpeedLabel()
	if bestApplyPayload or bestAddPayload then
		log("Probe done — Start will use working apply/add payloads.")
	else
		log("Probe: nothing moved leaderstats.Speed. Server may be blocking.")
	end
end

local function rebuildTrialArgs(trial, applyAmount, addAmount)
	local mode = trial.mode
	local args = {}

	if mode == "add" then
		for _, v in ipairs(trial.args) do
			if type(v) == "number" then
				table.insert(args, addAmount)
			elseif type(v) == "string" and v ~= "Add" and v ~= "Speed" and v ~= "speed" and v ~= "add" then
				table.insert(args, tostring(addAmount))
			else
				table.insert(args, v)
			end
		end
	else
		for _, v in ipairs(trial.args) do
			if type(v) == "number" then
				table.insert(args, applyAmount)
			elseif type(v) == "string" and v ~= "Speed" and v ~= "speed" and v ~= "set" and v ~= "Add" and v ~= "add" then
				table.insert(args, tostring(applyAmount))
			else
				table.insert(args, v)
			end
		end
	end

	return args
end

local function runSpeedLoop()
	if running then
		return
	end
	running = true

	startSpeed = tonumber(startBox.Text) or startSpeed
	stepSpeed = tonumber(stepBox.Text) or stepSpeed
	interval = tonumber(intervalBox.Text) or interval

	hookUpdateSpeedListener()
	log("=== LOOP: apply rising speed + add step each tick ===")
	log(string.format("Start apply=%s | Add per tick=%s | Max=%s", startSpeed, stepSpeed, maxSpeed))

	local applyAmount = startSpeed
	local tickCount = 0

	while running do
		if not player.Parent then
			log("STOPPED — kicked or left.")
			break
		end

		tickCount += 1
		local before = getSpeedStat()
		log(string.format("--- tick %d | send apply=%s add=%s | Speed=%s ---", tickCount, applyAmount, stepSpeed, tostring(before)))

		local anyEffect = false
		local attempts = {}

		if bestApplyPayload then
			table.insert(attempts, {
				name = bestApplyPayload.remote.name,
				path = bestApplyPayload.remote.path,
				label = "apply " .. bestApplyPayload.trial.label,
				args = rebuildTrialArgs(bestApplyPayload.trial, applyAmount, stepSpeed),
			})
		end
		if bestAddPayload then
			table.insert(attempts, {
				name = bestAddPayload.remote.name,
				path = bestAddPayload.remote.path,
				label = "add " .. bestAddPayload.trial.label,
				args = rebuildTrialArgs(bestAddPayload.trial, applyAmount, stepSpeed),
			})
		end

		-- No probe yet: try default apply + add on main remotes
		if #attempts == 0 then
			for _, info in ipairs(ACTION_REMOTES) do
				if info.name ~= "TreadmillSignal" then
					table.insert(attempts, {
						name = info.name,
						path = info.path,
						label = "default apply",
						args = { applyAmount },
					})
					table.insert(attempts, {
						name = info.name,
						path = info.path,
						label = "default add",
						args = { stepSpeed },
					})
				end
			end
		end

		-- Treadmill tick + apply/add
		table.insert(attempts, {
			name = "TreadmillSignal",
			path = "ReplicatedStorage.Remotes.TreadmillSignal",
			label = "treadmill",
			args = {},
		})

		for _, attempt in ipairs(attempts) do
			local ok, err = pcall(function()
				local remote = resolvePath(attempt.path)
				fireRemote(remote, attempt.args)
			end)
			if ok then
				task.wait(0.12)
				local after = getSpeedStat()
				if speedStatChanged(before, after) then
					anyEffect = true
					local increased, delta = speedStatIncreased(before, after)
					if increased then
						log(string.format("  %s [%s] Speed %s -> %s (+%s)", attempt.name, attempt.label, before, after, tostring(delta or "?")))
					else
						log(string.format("  %s [%s] Speed %s -> %s", attempt.name, attempt.label, before, after))
					end
					before = after
				end
			else
				log(string.format("  FAIL %s: %s", attempt.name, tostring(err)))
			end
		end

		if not anyEffect then
			log("  NO CHANGE — server blocked or wrong payload (run Probe first).")
		end

		statusLabel.Text = string.format("Tick %d | apply %s | Speed=%s | %s", tickCount, applyAmount, tostring(before), anyEffect and "OK" or "blocked")
		updateLiveSpeedLabel()

		applyAmount = math.min(applyAmount + stepSpeed, maxSpeed)
		task.wait(interval)
	end

	running = false
	statusLabel.Text = "Stopped."
	log("=== LOOP END ===")
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
panel.Size = UDim2.fromOffset(440, 480)
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
title.Text = "Speed Test (apply + add)"
title.Parent = panel

statusLabel = Instance.new("TextLabel")
statusLabel.BackgroundTransparency = 1
statusLabel.Position = UDim2.fromOffset(12, 32)
statusLabel.Size = UDim2.new(1, -24, 0, 36)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 11
statusLabel.TextWrapped = true
statusLabel.TextColor3 = Color3.fromRGB(160, 210, 255)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Text = "Applies rising speed + adds step — checks leaderstats.Speed only."
statusLabel.Parent = panel

liveSpeedLabel = Instance.new("TextLabel")
liveSpeedLabel.BackgroundTransparency = 1
liveSpeedLabel.Position = UDim2.fromOffset(12, 68)
liveSpeedLabel.Size = UDim2.new(1, -24, 0, 36)
liveSpeedLabel.Font = Enum.Font.Code
liveSpeedLabel.TextSize = 10
liveSpeedLabel.TextWrapped = true
liveSpeedLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
liveSpeedLabel.TextXAlignment = Enum.TextXAlignment.Left
liveSpeedLabel.Text = "Tracking: ..."
liveSpeedLabel.Parent = panel

local function numBox(label, y, default)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromOffset(12, y)
	l.Size = UDim2.fromOffset(130, 20)
	l.Font = Enum.Font.Gotham
	l.TextSize = 11
	l.TextColor3 = Color3.fromRGB(180, 185, 200)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = label
	l.Parent = panel

	local b = Instance.new("TextBox")
	b.Position = UDim2.fromOffset(150, y - 2)
	b.Size = UDim2.fromOffset(278, 24)
	b.BackgroundColor3 = Color3.fromRGB(14, 16, 22)
	b.TextColor3 = Color3.fromRGB(255, 255, 255)
	b.Font = Enum.Font.Code
	b.TextSize = 12
	b.Text = tostring(default)
	b.ClearTextOnFocus = false
	b.Parent = panel
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
	return b
end

startBox = numBox("Apply speed", 108, startSpeed)
stepBox = numBox("Add per tick", 136, stepSpeed)
intervalBox = numBox("Seconds", 164, interval)

local scroll = Instance.new("ScrollingFrame")
scroll.Position = UDim2.fromOffset(12, 196)
scroll.Size = UDim2.new(1, -24, 1, -100)
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
logLabel.Text = "Ready."
logLabel.Parent = scroll

local function btn(text, x, w, fn, col)
	local b = Instance.new("TextButton")
	b.Position = UDim2.fromOffset(x, 438)
	b.Size = UDim2.fromOffset(w, 32)
	b.BackgroundColor3 = col or Color3.fromRGB(45, 120, 70)
	b.TextColor3 = Color3.fromRGB(255, 255, 255)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 11
	b.Text = text
	b.Parent = panel
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
	b.MouseButton1Click:Connect(fn)
end

btn("Discover", 12, 72, discoverSpeedStats, Color3.fromRGB(60, 100, 160))
btn("Probe", 92, 72, function()
	task.spawn(runProbeOnce)
end, Color3.fromRGB(80, 130, 90))
btn("Start", 172, 72, function()
	task.spawn(runSpeedLoop)
end)
btn("Stop", 252, 72, function()
	running = false
	log("Stop requested.")
end, Color3.fromRGB(180, 70, 70))
btn("Close", 332, 72, function()
	running = false
	screenGui:Destroy()
end, Color3.fromRGB(80, 85, 100))

task.spawn(function()
	while screenGui.Parent do
		updateLiveSpeedLabel()
		task.wait(0.5)
	end
end)

hookUpdateSpeedListener()
discoverSpeedStats()
log("Watches leaderstats.Speed only.")
log("Apply = set total speed | Add = +step per tick (both rise each loop).")
log("Probe -> Start. Remotes: SetCustomSpeed, UpdateSpeed, TreadmillSignal.")
