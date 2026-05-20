--[[
  SPEED TEST — turbo treadmill ticks -> leaderstats.Speed (like Wins).

  Stand on treadmill, set Ticks/burst + Burst delay, Start.
  Spams TreadmillSignal fast so speed climbs faster than normal.

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
local TREADMILL_PATH = "ReplicatedStorage.Remotes.TreadmillSignal"
local SPEED_STAT_NAME = "Speed"

local running = false
local ticksPerBurst = 40
local burstDelay = 0.03
local logEveryNBursts = 5

local logLines = {}
local statusLabel
local liveSpeedLabel
local logLabel
local ticksBox
local delayBox
local bestTreadmillPayload = { label = "empty", args = {} }
local updateSpeedHooked = false
local lastLoggedSpeed = nil

local function log(text)
	table.insert(logLines, text)
	if #logLines > 60 then
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

local function getSpeedStat()
	local ls = player:FindFirstChild("leaderstats")
	if not ls then
		return nil
	end
	local stat = ls:FindFirstChild(SPEED_STAT_NAME)
	if not stat then
		return nil
	end
	if stat:IsA("NumberValue") or stat:IsA("IntValue") or stat:IsA("StringValue") then
		return stat.Value
	end
	return nil
end

local function parseStatNumber(value)
	if type(value) == "number" then
		return value
	end
	if type(value) == "string" then
		return tonumber(value:gsub(",", ""))
	end
	return nil
end

local function formatLiveStats()
	local speed = getSpeedStat()
	if speed == nil then
		return "leaderstats.Speed not found"
	end
	return "leaderstats.Speed = " .. tostring(speed)
end

local function speedDelta(before, after)
	local b, a = parseStatNumber(before), parseStatNumber(after)
	if b and a then
		return a - b, tostring(a - b)
	end
	if tostring(before) ~= tostring(after) then
		return nil, tostring(before) .. " -> " .. tostring(after)
	end
	return 0, "0"
end

local function updateLiveSpeedLabel(extra)
	if not liveSpeedLabel then
		return
	end
	local line = formatLiveStats()
	if extra then
		line ..= " | " .. extra
	end
	liveSpeedLabel.Text = line
end

local function discoverSpeedStats()
	log("=== DISCOVER ===")
	local speed = getSpeedStat()
	if speed == nil then
		log("No leaderstats.Speed — join game first.")
	else
		log("Speed = " .. tostring(speed))
		lastLoggedSpeed = speed
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
			updateLiveSpeedLabel("server synced")
		end)
		updateSpeedHooked = true
	end
end

local function getTreadmillRemote()
	return resolvePath(TREADMILL_PATH)
end

local function fireTreadmillBurst(remote, args, count)
	for _ = 1, count do
		if not running then
			break
		end
		remote:FireServer(table.unpack(args))
	end
end

local TREADMILL_TRIALS = {
	{ label = "empty tick", args = {} },
	{ label = "true", args = { true } },
	{ label = "1", args = { 1 } },
	{ label = "tick string", args = { "tick" } },
	{ label = "run", args = { "run" } },
}

local function runProbeOnce()
	ticksPerBurst = math.clamp(tonumber(ticksBox.Text) or 20, 1, 200)

	log("=== PROBE treadmill (stand on treadmill!) ===")
	local remote = getTreadmillRemote()
	if not remote then
		log("TreadmillSignal not found.")
		return
	end

	hookUpdateSpeedListener()
	local bestGain = 0
	local bestTrial = TREADMILL_TRIALS[1]

	for _, trial in ipairs(TREADMILL_TRIALS) do
		local before = getSpeedStat()
		local ok, err = pcall(function()
			fireTreadmillBurst(remote, trial.args, ticksPerBurst)
		end)
		if not ok then
			log("  FAIL " .. trial.label .. ": " .. tostring(err))
		else
			task.wait(0.35)
			local after = getSpeedStat()
			local numDelta = speedDelta(before, after)
			local gain = 0
			if type(numDelta) == "number" then
				gain = numDelta
			elseif numDelta == nil and before ~= after then
				gain = 1
			end
			log(string.format("  %s x%d -> gain %s", trial.label, ticksPerBurst, tostring(numDelta or (before .. "->" .. after))))
			if gain > bestGain then
				bestGain = gain
				bestTrial = trial
			end
		end
		task.wait(0.15)
	end

	bestTreadmillPayload = bestTrial
	log(string.format("Best: %s (gain %s). Hit Start.", bestTrial.label, tostring(bestGain)))
	updateLiveSpeedLabel("probe: " .. bestTrial.label)
end

local function runTurboLoop()
	if running then
		return
	end

	local remote = getTreadmillRemote()
	if not remote then
		log("TreadmillSignal missing.")
		return
	end

	running = true
	ticksPerBurst = math.clamp(tonumber(ticksBox.Text) or 40, 1, 500)
	burstDelay = math.clamp(tonumber(delayBox.Text) or 0.03, 0, 2)

	hookUpdateSpeedListener()
	log("=== TURBO TREADMILL ===")
	log(string.format("%d ticks/burst | %.3fs between bursts", ticksPerBurst, burstDelay))
	log("STAND ON TREADMILL. Watching leaderstats.Speed.")

	local burstCount = 0
	local totalGain = 0
	local sessionStart = getSpeedStat()

	while running do
		if not player.Parent then
			log("Kicked or left.")
			break
		end

		burstCount += 1
		local before = getSpeedStat()

		local ok, err = pcall(function()
			fireTreadmillBurst(remote, bestTreadmillPayload.args, ticksPerBurst)
		end)

		if not ok then
			log("Burst error: " .. tostring(err))
			break
		end

		if burstDelay > 0 then
			task.wait(burstDelay)
		end

		local after = getSpeedStat()
		local numDelta, deltaStr = speedDelta(before, after)

		if type(numDelta) == "number" and numDelta > 0 then
			totalGain += numDelta
		end

		if burstCount % logEveryNBursts == 0 or (numDelta and numDelta ~= 0) then
			local rate = ""
			if type(numDelta) == "number" and burstDelay > 0 then
				rate = string.format(" (~%.0f/s)", numDelta / burstDelay)
			end
			log(string.format("burst %d | +%s | Speed=%s%s", burstCount, deltaStr, tostring(after), rate))
			lastLoggedSpeed = after
		end

		statusLabel.Text = string.format(
			"Turbo x%d | burst %d | Speed=%s | +%s total",
			ticksPerBurst,
			burstCount,
			tostring(after),
			tostring(totalGain)
		)
		updateLiveSpeedLabel(string.format("+%s last burst", deltaStr))

		-- No gain for many bursts = probably not on treadmill or server blocking
		if burstCount == 10 and totalGain == 0 and sessionStart == after then
			log("WARN: Speed not moving — are you ON the treadmill?")
		end
	end

	running = false
	local finalSpeed = getSpeedStat()
	log(string.format("=== STOPPED | %d bursts | Speed %s -> %s ===", burstCount, tostring(sessionStart), tostring(finalSpeed)))
	statusLabel.Text = "Stopped."
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
panel.Size = UDim2.fromOffset(420, 440)
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
title.Text = "Turbo Treadmill Speed Test"
title.Parent = panel

statusLabel = Instance.new("TextLabel")
statusLabel.BackgroundTransparency = 1
statusLabel.Position = UDim2.fromOffset(12, 32)
statusLabel.Size = UDim2.new(1, -24, 0, 40)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 11
statusLabel.TextWrapped = true
statusLabel.TextColor3 = Color3.fromRGB(160, 210, 255)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Text = "Spam TreadmillSignal bursts — must stand on treadmill."
statusLabel.Parent = panel

liveSpeedLabel = Instance.new("TextLabel")
liveSpeedLabel.BackgroundTransparency = 1
liveSpeedLabel.Position = UDim2.fromOffset(12, 72)
liveSpeedLabel.Size = UDim2.new(1, -24, 0, 32)
liveSpeedLabel.Font = Enum.Font.Code
liveSpeedLabel.TextSize = 10
liveSpeedLabel.TextWrapped = true
liveSpeedLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
liveSpeedLabel.TextXAlignment = Enum.TextXAlignment.Left
liveSpeedLabel.Text = "..."
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
	b.Size = UDim2.fromOffset(258, 24)
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

ticksBox = numBox("Ticks/burst", 108, ticksPerBurst)
delayBox = numBox("Burst delay", 136, burstDelay)

local scroll = Instance.new("ScrollingFrame")
scroll.Position = UDim2.fromOffset(12, 168)
scroll.Size = UDim2.new(1, -24, 1, -108)
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
	b.Position = UDim2.fromOffset(x, 398)
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
	task.spawn(runTurboLoop)
end)
btn("Stop", 252, 72, function()
	running = false
	log("Stop.")
end, Color3.fromRGB(180, 70, 70))
btn("Close", 332, 72, function()
	running = false
	screenGui:Destroy()
end, Color3.fromRGB(80, 85, 100))

task.spawn(function()
	while screenGui.Parent do
		updateLiveSpeedLabel()
		task.wait(0.25)
	end
end)

hookUpdateSpeedListener()
discoverSpeedStats()
log("Turbo = many TreadmillSignal fires per burst.")
log("Try: Ticks/burst 50-100, Burst delay 0.01-0.03")
log("Stand on treadmill -> Probe -> Start")
