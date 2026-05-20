--[[
  TURBO TREADMILL SPEED TEST

  Detects when you are ON a treadmill (touch / distance / game flags).
  Then spams TreadmillSignal + CheckGoldTreadmill to speed up ticks.

  loadstring(game:HttpGet("https://raw.githubusercontent.com/aguy55409-commits/script/main/speed-test.luau", true))()
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")

if RunService:IsServer() and not Players.LocalPlayer then
	error("Run on client (Potassium) while in-game.")
end

local player = Players.LocalPlayer
if not player then
	error("Join the game first.")
end

local GUI_NAME = "SpeedExploitTest"
local TREADMILL_PATH = "ReplicatedStorage.Remotes.TreadmillSignal"
local CHECK_GOLD_PATH = "ReplicatedStorage.Remotes.CheckGoldTreadmill"
local SET_SPEED_PATH = "ReplicatedStorage.Remotes.SetCustomSpeed"
local SPEED_STAT_NAME = "Speed"

local fireTouch = firetouchinterest
		or (syn and syn.firetouchinterest)
		or (fluxus and fluxus.firetouchinterest)

local running = false
local ticksPerBurst = 40
local burstDelay = 0.03
local requireOnTreadmill = true
local logEveryNBursts = 5

local treadmillParts = {}
local treadmillStatusLabel
local logLines = {}
local statusLabel
local liveSpeedLabel
local logLabel
local ticksBox
local delayBox
local bestTreadmillPayload = { label = "empty", args = {} }
local updateSpeedHooked = false
local lastOnTreadmill = false
local lastDetectReason = "unknown"
local speedRateLabel
local baselineRate = 0
local boostRate = 0
local heartbeatBoostConn = nil

local ATTR_NAMES = {
	"OnTreadmill",
	"onTreadmill",
	"Running",
	"Treadmill",
	"OnTreadmillBelt",
	"IsRunning",
	"TreadmillActive",
}

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

local function nameLooksLikeTreadmill(name, parentName)
	local n = string.lower(name or "")
	local p = string.lower(parentName or "")
	return string.find(n, "treadmill", 1, true)
		or string.find(n, "tread", 1, true)
		or string.find(n, "belt", 1, true)
		or string.find(n, "runner", 1, true)
		or string.find(p, "treadmill", 1, true)
		or string.find(p, "tread", 1, true)
end

local function scanTreadmills()
	table.clear(treadmillParts)
	local count = 0

	for _, inst in Workspace:GetDescendants() do
		if inst:IsA("BasePart") then
			local parentName = inst.Parent and inst.Parent.Name or ""
			if nameLooksLikeTreadmill(inst.Name, parentName) then
				table.insert(treadmillParts, inst)
				count += 1
			end
		end
	end

	-- Player plot / tagged areas (common in simulators)
	local plotNames = { player.Name, player.DisplayName }
	for _, plotName in ipairs(plotNames) do
		local plot = Workspace:FindFirstChild(plotName)
		if plot then
			for _, inst in plot:GetDescendants() do
				if inst:IsA("BasePart") and not table.find(treadmillParts, inst) then
					if nameLooksLikeTreadmill(inst.Name, inst.Parent and inst.Parent.Name) then
						table.insert(treadmillParts, inst)
						count += 1
					end
				end
			end
		end
	end

	return count
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

local function checkPlayerFlags()
	for _, name in ipairs(ATTR_NAMES) do
		local v = player:GetAttribute(name)
		if v == true or v == 1 or v == "true" then
			return true, "player attr: " .. name
		end
	end

	local char = player.Character
	if char then
		for _, name in ipairs(ATTR_NAMES) do
			local v = char:GetAttribute(name)
			if v == true or v == 1 or v == "true" then
				return true, "character attr: " .. name
			end
		end
		for _, child in char:GetDescendants() do
			if (child:IsA("BoolValue") or child:IsA("NumberValue")) and nameLooksLikeTreadmill(child.Name, "") then
				if child:IsA("BoolValue") and child.Value then
					return true, "value: " .. child:GetFullName()
				end
				if child:IsA("NumberValue") and child.Value ~= 0 then
					return true, "value: " .. child:GetFullName()
				end
			end
		end
	end

	return false, nil
end

local function checkTouching()
	local char = player.Character
	if not char then
		return false, nil
	end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return false, nil
	end

	local touching = hrp:GetTouchingParts()
	for _, part in touching do
		if nameLooksLikeTreadmill(part.Name, part.Parent and part.Parent.Name) then
			return true, "touching: " .. part.Name
		end
		for _, tracked in treadmillParts do
			if part == tracked or part:IsDescendantOf(tracked.Parent) then
				return true, "touching tracked: " .. part.Name
			end
		end
	end

	-- Feet / legs sometimes touch belt instead of HRP
	for _, limb in char:GetChildren() do
		if limb:IsA("BasePart") and limb ~= hrp then
			for _, part in limb:GetTouchingParts() do
				if nameLooksLikeTreadmill(part.Name, part.Parent and part.Parent.Name) then
					return true, "touching (limb): " .. part.Name
				end
			end
		end
	end

	return false, nil
end

local function checkProximity()
	local char = player.Character
	if not char then
		return false, nil
	end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return false, nil
	end

	local bestDist = math.huge
	local bestPart = nil

	for _, part in treadmillParts do
		if part.Parent and part:IsDescendantOf(Workspace) then
			local offset = hrp.Position - part.Position
			local flatDist = Vector3.new(offset.X, 0, offset.Z).Magnitude
			local maxFlat = math.max(part.Size.X, part.Size.Z) * 0.55 + 3
			local yOk = math.abs(offset.Y) <= math.max(part.Size.Y, 6) + 8
			if flatDist < maxFlat and yOk and flatDist < bestDist then
				bestDist = flatDist
				bestPart = part
			end
		end
	end

	if bestPart then
		return true, string.format("near %s (%.1f studs)", bestPart.Name, bestDist)
	end
	return false, nil
end

local function isOnTreadmill()
	local flagOk, flagReason = checkPlayerFlags()
	if flagOk then
		return true, flagReason
	end

	local touchOk, touchReason = checkTouching()
	if touchOk then
		return true, touchReason
	end

	local nearOk, nearReason = checkProximity()
	if nearOk then
		return true, nearReason
	end

	return false, "not on treadmill (stand on belt)"
end

local function updateTreadmillStatusUI()
	local on, reason = isOnTreadmill()
	lastOnTreadmill = on
	lastDetectReason = reason or "off"

	if treadmillStatusLabel then
		if on then
			treadmillStatusLabel.Text = "ON TREADMILL ✓  " .. reason
			treadmillStatusLabel.TextColor3 = Color3.fromRGB(80, 255, 120)
		else
			treadmillStatusLabel.Text = "OFF TREADMILL ✗  " .. reason
			treadmillStatusLabel.TextColor3 = Color3.fromRGB(255, 90, 90)
		end
	end
end

local function updateLiveSpeedLabel()
	if not liveSpeedLabel then
		return
	end
	local speed = getSpeedStat()
	local speedText = speed and ("Speed = " .. tostring(speed)) or "Speed = ?"
	liveSpeedLabel.Text = speedText
	if speedRateLabel then
		speedRateLabel.Text = string.format(
			"Gain rate: normal ~%s/s | boost ~%s/s",
			tostring(baselineRate),
			tostring(boostRate)
		)
	end
end

local function getNearestTreadmillPart()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return nil
	end
	local best, bestDist = nil, math.huge
	for _, part in treadmillParts do
		if part.Parent then
			local d = (hrp.Position - part.Position).Magnitude
			if d < bestDist then
				bestDist = d
				best = part
			end
		end
	end
	return best
end

local function snapToBelt()
	scanTreadmills()
	local part = getNearestTreadmillPart()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not part or not hrp then
		log("Snap failed — no treadmill part or character.")
		return false
	end
	local y = part.Size.Y / 2 + hrp.Size.Y / 2 + 0.5
	hrp.CFrame = part.CFrame * CFrame.new(0, y, 0)
	log("Snapped onto: " .. part:GetFullName())
	task.wait(0.15)
	updateTreadmillStatusUI()
	return true
end

local function fireTouchBurst()
	if not fireTouch then
		return false
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return false
	end
	local hit = 0
	for _, part in treadmillParts do
		if part.Parent and part.CanTouch ~= false then
			pcall(fireTouch, part, hrp, 0)
			pcall(fireTouch, part, hrp, 1)
			hit += 1
		end
	end
	return hit > 0
end

local function measureGainPerSecond(seconds, useBoost)
	local s0 = parseStatNumber(getSpeedStat())
	if not s0 then
		return 0
	end
	local t0 = os.clock()
	local remote = getTreadmillRemote()
	local args = bestTreadmillPayload.args

	while os.clock() - t0 < seconds do
		if useBoost and remote then
			registerWithServer()
			fireTouchBurst()
			pcall(fireTreadmillBurst, remote, args, 5)
			fireRemote(SET_SPEED_PATH, { 2 })
			fireRemote(SET_SPEED_PATH, { "2" })
		end
		task.wait(0.05)
	end

	local s1 = parseStatNumber(getSpeedStat()) or s0
	return (s1 - s0) / seconds
end

local function discoverAll()
	log("=== SCAN ===")
	local n = scanTreadmills()
	log(string.format("Found %d treadmill parts in workspace", n))
	if n > 0 and n <= 8 then
		for i, part in ipairs(treadmillParts) do
			log(string.format("  [%d] %s", i, part:GetFullName()))
		end
	elseif n > 8 then
		for i = 1, 5 do
			log("  " .. treadmillParts[i]:GetFullName())
		end
		log(string.format("  ... +%d more", n - 5))
	end

	local speed = getSpeedStat()
	if speed then
		log("leaderstats.Speed = " .. tostring(speed))
	else
		log("leaderstats.Speed missing")
	end

	updateTreadmillStatusUI()
	local on, reason = isOnTreadmill()
	log(on and ("You ARE detected: " .. reason) or ("NOT detected: " .. reason))
	updateLiveSpeedLabel()
end

local function hookUpdateSpeedListener()
	if updateSpeedHooked then
		return
	end
	local remote = resolvePath("ReplicatedStorage.Remotes.UpdateSpeed")
	if remote and remote:IsA("RemoteEvent") then
		remote.OnClientEvent:Connect(function()
			updateLiveSpeedLabel()
		end)
		updateSpeedHooked = true
	end
end

local function getTreadmillRemote()
	return resolvePath(TREADMILL_PATH)
end

local function fireRemote(path, args)
	local remote = resolvePath(path)
	if not remote then
		return false
	end
	if remote:IsA("RemoteEvent") then
		remote:FireServer(table.unpack(args))
	elseif remote:IsA("RemoteFunction") then
		remote:InvokeServer(table.unpack(args))
	end
	return true
end

local function fireTreadmillBurst(remote, args, count)
	for _ = 1, count do
		if not running then
			break
		end
		remote:FireServer(table.unpack(args))
	end
end

local function registerWithServer()
	fireRemote(CHECK_GOLD_PATH, {})
	fireRemote(CHECK_GOLD_PATH, { true })
	fireRemote(CHECK_GOLD_PATH, { player.UserId })
end

local function runFullBoostPacket(remote, args, multiplier)
	registerWithServer()
	fireTouchBurst()
	if remote then
		fireTreadmillBurst(remote, args, ticksPerBurst)
	end
	-- multiplier / boost amount (some games use SetCustomSpeed as speed mult)
	fireRemote(SET_SPEED_PATH, { multiplier })
	fireRemote(SET_SPEED_PATH, { tostring(multiplier) })
	fireRemote(SET_SPEED_PATH, { "Speed", multiplier })
end

local TREADMILL_TRIALS = {
	{ label = "empty", args = {} },
	{ label = "true", args = { true } },
	{ label = "on true", args = { true, true } },
	{ label = "1", args = { 1 } },
	{ label = "tick", args = { "tick" } },
}

local function runProbeOnce()
	ticksPerBurst = math.clamp(tonumber(ticksBox.Text) or 20, 1, 200)
	scanTreadmills()
	updateTreadmillStatusUI()

	local on, reason = isOnTreadmill()
	if not on then
		log("WARNING: Not on treadmill — " .. reason)
		log("Stand on the belt, click Scan, then Probe again.")
	end

	log("=== PROBE ===")
	local remote = getTreadmillRemote()
	if not remote then
		log("TreadmillSignal missing.")
		return
	end

	registerWithServer()
	hookUpdateSpeedListener()

	local bestGain = 0
	local bestTrial = TREADMILL_TRIALS[1]

	for _, trial in ipairs(TREADMILL_TRIALS) do
		if not isOnTreadmill() then
			updateTreadmillStatusUI()
		end
		registerWithServer()

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
			local gain = (type(numDelta) == "number" and numDelta) or (before ~= after and 1) or 0
			log(string.format("  %s x%d | on=%s | gain %s", trial.label, ticksPerBurst, tostring(isOnTreadmill()), tostring(numDelta or (before .. "->" .. after))))
			if gain > bestGain then
				bestGain = gain
				bestTrial = trial
			end
		end
		task.wait(0.12)
	end

	bestTreadmillPayload = bestTrial
	log(string.format("Best payload: %s | Click Start", bestTrial.label))
end

local function stopHeartbeatBoost()
	if heartbeatBoostConn then
		heartbeatBoostConn:Disconnect()
		heartbeatBoostConn = nil
	end
end

local function runCompareRates()
	log("=== RATE TEST (3 sec normal, 3 sec boost) ===")
	log("Stay ON treadmill (green). Don't move.")

	snapToBelt()
	task.wait(0.5)
	if not isOnTreadmill() then
		log("Still OFF treadmill — fix position then retry.")
		return
	end

	baselineRate = math.floor(measureGainPerSecond(3, false) + 0.5)
	log(string.format("Normal speed gain: ~%s / second", tostring(baselineRate)))

	boostRate = math.floor(measureGainPerSecond(3, true) + 0.5)
	log(string.format("Boost speed gain: ~%s / second", tostring(boostRate)))

	if boostRate <= baselineRate * 1.1 then
		log("RESULT: Boost did NOT beat normal — server ignores client spam.")
		log("Your anti-cheat is WORKING (server controls Speed).")
		statusLabel.Text = "AC OK — server blocks faster ticks"
	else
		log(string.format("RESULT: Boost is ~%.0f%% faster — VULNERABLE", ((boostRate / math.max(baselineRate, 1)) - 1) * 100))
		statusLabel.Text = "VULN — boost increased gain rate"
	end
	updateLiveSpeedLabel()
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

	scanTreadmills()
	snapToBelt()

	running = true
	ticksPerBurst = math.clamp(tonumber(ticksBox.Text) or 40, 1, 500)
	burstDelay = math.clamp(tonumber(delayBox.Text) or 0.03, 0, 2)
	local useMaxMode = burstDelay <= 0

	hookUpdateSpeedListener()
	log("=== BOOST START ===")
	log("Uses: touch sim + TreadmillSignal + SetCustomSpeed mult")
	if fireTouch then
		log("firetouchinterest: YES")
	else
		log("firetouchinterest: NO (executor may not support)")
	end
	if useMaxMode then
		log("MAX mode: firing every frame on Heartbeat")
	end

	local burstCount = 0
	local sessionStart = getSpeedStat()
	local skippedOff = 0
	local mult = 5

	stopHeartbeatBoost()
	if useMaxMode then
		heartbeatBoostConn = RunService.Heartbeat:Connect(function()
			if not running then
				return
			end
			if requireOnTreadmill and not isOnTreadmill() then
				return
			end
			runFullBoostPacket(remote, bestTreadmillPayload.args, mult)
		end)
	end

	while running do
		if not player.Parent then
			log("Kicked or left.")
			break
		end

		updateTreadmillStatusUI()
		local on, reason = isOnTreadmill()

		if requireOnTreadmill and not on then
			skippedOff += 1
			if skippedOff == 1 or skippedOff % 15 == 0 then
				log("OFF treadmill — click Snap or step on belt")
			end
			task.wait(0.2)
			continue
		end

		skippedOff = 0

		if not useMaxMode then
			burstCount += 1
			local before = getSpeedStat()
			local t0 = os.clock()

			pcall(function()
				runFullBoostPacket(remote, bestTreadmillPayload.args, mult)
			end)

			if burstDelay > 0 then
				task.wait(burstDelay)
			end

			local after = getSpeedStat()
			local numDelta, deltaStr = speedDelta(before, after)
			local elapsed = math.max(os.clock() - t0, 0.001)
			boostRate = math.floor(((parseStatNumber(after) or 0) - (parseStatNumber(before) or 0)) / elapsed + 0.5)

			if burstCount % logEveryNBursts == 0 then
				log(string.format("burst %d | +%s/s est | Speed=%s", burstCount, tostring(boostRate), tostring(after)))
			end

			statusLabel.Text = string.format("+%s/s | Speed=%s", tostring(boostRate), tostring(after))
			updateLiveSpeedLabel()
		else
			task.wait(0.5)
			boostRate = math.floor(measureGainPerSecond(0.5, false) + 0.5)
			statusLabel.Text = string.format("MAX frame boost | Speed=%s | ~%s/s", tostring(getSpeedStat()), tostring(boostRate))
			updateLiveSpeedLabel()
		end

		mult = math.min(mult + 1, 50)
	end

	stopHeartbeatBoost()
	running = false
	log(string.format("STOPPED | Speed %s -> %s", sessionStart, getSpeedStat()))
	if boostRate <= 0 and baselineRate <= 0 then
		log("If Speed never moved: server-only treadmill = good security.")
	end
	statusLabel.Text = "Stopped."
	updateTreadmillStatusUI()
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
panel.Size = UDim2.fromOffset(430, 500)
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

treadmillStatusLabel = Instance.new("TextLabel")
treadmillStatusLabel.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
treadmillStatusLabel.Position = UDim2.fromOffset(12, 32)
treadmillStatusLabel.Size = UDim2.new(1, -24, 0, 36)
treadmillStatusLabel.Font = Enum.Font.GothamBold
treadmillStatusLabel.TextSize = 13
treadmillStatusLabel.TextWrapped = true
treadmillStatusLabel.TextColor3 = Color3.fromRGB(255, 90, 90)
treadmillStatusLabel.Text = "Scanning..."
treadmillStatusLabel.Parent = panel
Instance.new("UICorner", treadmillStatusLabel).CornerRadius = UDim.new(0, 6)

statusLabel = Instance.new("TextLabel")
statusLabel.BackgroundTransparency = 1
statusLabel.Position = UDim2.fromOffset(12, 72)
statusLabel.Size = UDim2.new(1, -24, 0, 28)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 10
statusLabel.TextWrapped = true
statusLabel.TextColor3 = Color3.fromRGB(160, 210, 255)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Text = "Green = on treadmill. Red = step onto belt."
statusLabel.Parent = panel

liveSpeedLabel = Instance.new("TextLabel")
liveSpeedLabel.BackgroundTransparency = 1
liveSpeedLabel.Position = UDim2.fromOffset(12, 100)
liveSpeedLabel.Size = UDim2.new(1, -24, 0, 18)

speedRateLabel = Instance.new("TextLabel")
speedRateLabel.BackgroundTransparency = 1
speedRateLabel.Position = UDim2.fromOffset(12, 118)
speedRateLabel.Size = UDim2.new(1, -24, 0, 18)
speedRateLabel.Font = Enum.Font.Code
speedRateLabel.TextSize = 10
speedRateLabel.TextColor3 = Color3.fromRGB(140, 200, 255)
speedRateLabel.TextXAlignment = Enum.TextXAlignment.Left
speedRateLabel.Text = "Gain rate: run Compare to measure"
speedRateLabel.Parent = panel
liveSpeedLabel.Font = Enum.Font.Code
liveSpeedLabel.TextSize = 10
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
	b.Size = UDim2.fromOffset(268, 24)
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

ticksBox = numBox("Ticks/burst", 140, ticksPerBurst)
delayBox = numBox("Burst delay", 168, burstDelay)

local scroll = Instance.new("ScrollingFrame")
scroll.Position = UDim2.fromOffset(12, 200)
scroll.Size = UDim2.new(1, -24, 1, -140)
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
	b.Position = UDim2.fromOffset(x, 458)
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

btn("Scan", 8, 42, discoverAll, Color3.fromRGB(60, 100, 160))
btn("Snap", 54, 42, snapToBelt, Color3.fromRGB(100, 80, 160))
btn("Probe", 100, 42, function()
	task.spawn(runProbeOnce)
end, Color3.fromRGB(80, 130, 90))
btn("Cmp", 146, 42, function()
	task.spawn(runCompareRates)
end, Color3.fromRGB(60, 130, 150))
btn("Start", 192, 42, function()
	task.spawn(runTurboLoop)
end)
btn("Stop", 238, 42, function()
	running = false
	stopHeartbeatBoost()
	log("Stop.")
end, Color3.fromRGB(180, 70, 70))
btn("Force", 284, 42, function()
	requireOnTreadmill = not requireOnTreadmill
	log(requireOnTreadmill and "Must be ON treadmill" or "FORCE mode")
end, Color3.fromRGB(120, 90, 50))
btn("X", 330, 42, function()
	running = false
	stopHeartbeatBoost()
	screenGui:Destroy()
end, Color3.fromRGB(80, 85, 100))

RunService.Heartbeat:Connect(function()
	if screenGui.Parent then
		updateTreadmillStatusUI()
	end
end)

task.spawn(function()
	while screenGui.Parent do
		updateLiveSpeedLabel()
		task.wait(0.3)
	end
end)

hookUpdateSpeedListener()
scanTreadmills()
discoverAll()
log("Snap = teleport onto belt. Compare = normal vs boost /s.")
log("Burst delay 0 = MAX (every frame). If Compare says AC OK = server blocks.")
