--[[
  SPEED EXPLOIT TEST — interacts with YOUR game's real speed stat + treadmill remote.

  Tracks leaderstats.Speed only (same place as Wins) — NOT custom speed UI.
  Fires treadmill remotes, only logs when your Speed stat actually changes.

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

local SKIP_NAME_PATTERNS = {
	"prompt",
	"gamepass",
	"purchase",
	"product",
	"devproduct",
	"robux",
	"shop",
	"buy",
	"admin",
}

-- Remotes that can change leaderstats.Speed (not SetCustomSpeed — that's custom input UI)
local ACTION_REMOTES = {
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
local discoveredSpeedKeys = {}
local bestPayloadByRemote = {}
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

local function shouldSkipRemoteName(name)
	local lower = string.lower(name)
	for _, pat in ipairs(SKIP_NAME_PATTERNS) do
		if string.find(lower, pat, 1, true) then
			return true
		end
	end
	return false
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

-- leaderstats.Speed only — same folder as leaderstats.Wins
local function readLeaderstat(statName)
	local ls = player:FindFirstChild("leaderstats")
	if not ls then
		return nil, nil
	end
	local stat = ls:FindFirstChild(statName)
	if not stat then
		return nil, nil
	end
	if stat:IsA("NumberValue") or stat:IsA("IntValue") then
		return stat.Value, "leaderstats." .. statName
	end
	if stat:IsA("StringValue") then
		return stat.Value, "leaderstats." .. statName
	end
	return nil, nil
end

local function getSpeedStat()
	local value, _ = readLeaderstat(SPEED_STAT_NAME)
	return value
end

local function getWinsStat()
	local value, _ = readLeaderstat(WINS_STAT_NAME)
	return value
end

local function formatLiveStats()
	local speed, speedKey = readLeaderstat(SPEED_STAT_NAME)
	local wins = readLeaderstat(WINS_STAT_NAME)
	if speed == nil then
		return "(leaderstats.Speed not found — wait for leaderstats to load)"
	end
	local parts = { string.format("%s=%s", speedKey, tostring(speed)) }
	if wins ~= nil then
		table.insert(parts, string.format("leaderstats.%s=%s", WINS_STAT_NAME, tostring(wins)))
	end
	return table.concat(parts, " | ")
end

local function speedStatChanged(before, after)
	if before == nil and after == nil then
		return false
	end
	if before == nil or after == nil then
		return true
	end
	return tostring(before) ~= tostring(after)
end

local function updateLiveSpeedLabel()
	if not liveSpeedLabel then
		return
	end
	liveSpeedLabel.Text = "Tracking: " .. formatLiveStats()
end

local function discoverSpeedStats()
	discoveredSpeedKeys = {}
	log("=== DISCOVER (leaderstats.Speed like Wins) ===")
	local speed = getSpeedStat()
	if speed == nil then
		log("leaderstats.Speed not found yet. Join game / wait for stats to load.")
	else
		table.insert(discoveredSpeedKeys, "leaderstats.Speed")
		log(string.format("  leaderstats.Speed = %s", tostring(speed)))
	end
	local wins = getWinsStat()
	if wins ~= nil then
		log(string.format("  leaderstats.Wins = %s (reference only, not tested)", tostring(wins)))
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
			log("<< UpdateSpeed from server: " .. table.concat(parts, ", "))
			updateLiveSpeedLabel()
		end)
		updateSpeedHooked = true
		log("Listening to UpdateSpeed (server -> client) to learn real payload shape.")
	end
end

-- TreadmillSignal payloads (raises leaderstats.Speed while on treadmill)
local function buildPayloadTrials()
	return {
		{ label = "empty (treadmill tick)", args = {} },
		{ label = "true", args = { true } },
		{ label = "1", args = { 1 } },
		{ label = "false", args = { false } },
	}
end

local function fireRemote(remote, args)
	if remote:IsA("RemoteEvent") then
		remote:FireServer(table.unpack(args))
		return true
	elseif remote:IsA("RemoteFunction") then
		remote:InvokeServer(table.unpack(args))
		return true
	end
	return false
end

local function tryRemoteWithPayload(remoteInfo, trial)
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
	if speedStatChanged(before, after) then
		bestPayloadByRemote[remoteInfo.name] = trial
		return true, string.format("Speed %s -> %s (%s)", tostring(before), tostring(after), trial.label)
	end
	return false, "no change to leaderstats.Speed"
end

local function runProbeOnce()
	log("=== PROBE (finds working payload) ===")
	hookUpdateSpeedListener()

	for _, info in ipairs(ACTION_REMOTES) do
		log("Probing " .. info.name .. "...")
		for _, trial in ipairs(buildPayloadTrials()) do
			local ok, msg = tryRemoteWithPayload(info, trial)
			if ok then
				log("  OK " .. info.name .. " via " .. trial.label .. " — " .. msg)
				break
			else
				log("  .. " .. trial.label .. " — " .. tostring(msg))
			end
			task.wait(0.1)
		end
	end

	updateLiveSpeedLabel()
	log("Probe done. If nothing changed, stand on treadmill and Probe again.")
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
	log("=== LOOP START ===")
	log("Loop: TreadmillSignal — watching leaderstats.Speed only.")

	local tickCount = 0

	while running do
		if not player.Parent then
			log("STOPPED — kicked or left.")
			break
		end

		tickCount += 1
		local before = getSpeedStat()
		log(string.format("--- tick %d | leaderstats.Speed = %s ---", tickCount, tostring(before)))

		local anyEffect = false

		for _, info in ipairs(ACTION_REMOTES) do
			local trials = {}
			local saved = bestPayloadByRemote[info.name]
			if saved then
				table.insert(trials, saved)
			else
				table.insert(trials, { label = "treadmill tick", args = {} })
				table.insert(trials, { label = "true", args = { true } })
			end

			for _, trial in ipairs(trials) do
				local ok, msg = pcall(function()
					local remote = resolvePath(info.path)
					fireRemote(remote, trial.args)
				end)
				if ok then
					task.wait(0.15)
					local after = getSpeedStat()
					if speedStatChanged(before, after) then
						anyEffect = true
						log(string.format("  %s(%s) Speed %s -> %s", info.name, trial.label or "?", before, after))
						before = after
					end
				else
					log(string.format("  FAIL %s: %s", info.name, tostring(msg)))
				end
			end
		end

		if not anyEffect then
			log("  NO CHANGE to leaderstats.Speed — stand on treadmill or server blocked.")
		end

		statusLabel.Text = string.format("Tick %d | Speed=%s | %s", tickCount, tostring(before), anyEffect and "CHANGED" or "no change")
		updateLiveSpeedLabel()

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
title.Text = "Speed Test (leaderstats.Speed)"
title.Parent = panel

statusLabel = Instance.new("TextLabel")
statusLabel.BackgroundTransparency = 1
statusLabel.Position = UDim2.fromOffset(12, 32)
statusLabel.Size = UDim2.new(1, -24, 0, 32)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 11
statusLabel.TextWrapped = true
statusLabel.TextColor3 = Color3.fromRGB(160, 210, 255)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Text = "Only tracks leaderstats.Speed (like Wins). Ignores custom speed."
statusLabel.Parent = panel

liveSpeedLabel = Instance.new("TextLabel")
liveSpeedLabel.BackgroundTransparency = 1
liveSpeedLabel.Position = UDim2.fromOffset(12, 64)
liveSpeedLabel.Size = UDim2.new(1, -24, 0, 40)
liveSpeedLabel.Font = Enum.Font.Code
liveSpeedLabel.TextSize = 10
liveSpeedLabel.TextWrapped = true
liveSpeedLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
liveSpeedLabel.TextXAlignment = Enum.TextXAlignment.Left
liveSpeedLabel.Text = "Game state: ..."
liveSpeedLabel.Parent = panel

local function numBox(label, y, default)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromOffset(12, y)
	l.Size = UDim2.fromOffset(120, 20)
	l.Font = Enum.Font.Gotham
	l.TextSize = 11
	l.TextColor3 = Color3.fromRGB(180, 185, 200)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = label
	l.Parent = panel

	local b = Instance.new("TextBox")
	b.Position = UDim2.fromOffset(140, y - 2)
	b.Size = UDim2.fromOffset(288, 24)
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

startBox = numBox("Start speed", 108, startSpeed)
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
log("Stat: leaderstats.Speed (NOT SetCustomSpeed / custom UI).")
log("Remote: TreadmillSignal while on treadmill.")
log("1) Stand on treadmill  2) Discover  3) Probe  4) Start")
