--[[
  FAKE TREADMILL — no RakNet. Simulates recorded treadmill ticks via FireServer.

  Record = finds which remote payloads raise leaderstats.Speed (saved profile)
  START = replays that profile constantly anywhere

  loadstring(game:HttpGet("https://raw.githubusercontent.com/aguy55409-commits/script/main/speed-test.luau", true))()
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
if not player then
	error("Join a game first.")
end

local GUI_NAME = "FakeTreadmillSim"

local running = false
local savedActions = {} -- simulated "recording": { name, args }
local cachedBelts = {}
local loopConns = {}
local watchConns = {}
local applyAmount = 100
local stepAmount = 1000
local firesPerTick = 8

local logLines = {}
local fakeLabel
local speedLabel
local rateLabel
local logLabel
local firesBox
local targetBox
local screenGui

local fireTouch = firetouchinterest or (syn and syn.firetouchinterest)

-- Default simulation if Record finds nothing (your game's likely shapes)
local DEFAULT_ACTIONS = {
	{ name = "CheckGoldTreadmill", args = {} },
	{ name = "CheckGoldTreadmill", args = { true } },
	{ name = "TreadmillSignal", args = {} },
	{ name = "TreadmillSignal", args = { true } },
	{ name = "SetCustomSpeed", args = { 100 }, dynamic = true },
}

local TRIAL_ACTIONS = {
	{ name = "TreadmillSignal", args = {} },
	{ name = "TreadmillSignal", args = { true } },
	{ name = "TreadmillSignal", args = { 1 } },
	{ name = "TreadmillSignal", args = { "tick" } },
	{ name = "CheckGoldTreadmill", args = {} },
	{ name = "CheckGoldTreadmill", args = { true } },
	{ name = "SetCustomSpeed", args = { 100 }, dynamic = true },
	{ name = "SetCustomSpeed", args = { "100" }, dynamic = true },
}

local function log(msg)
	table.insert(logLines, msg)
	if #logLines > 50 then
		table.remove(logLines, 1)
	end
	print("[Speed] " .. msg)
	if logLabel then
		logLabel.Text = table.concat(logLines, "\n")
	end
end

-- FIX: gsub returns 2 values — must not pass count as tonumber base
local function parseNum(v)
	if type(v) == "number" then
		return v
	end
	if type(v) == "string" then
		local cleaned = string.gsub(v, ",", "")
		return tonumber(cleaned)
	end
	return nil
end

local function getSpeedValue()
	local ls = player:FindFirstChild("leaderstats")
	if not ls then
		return nil, nil
	end
	local s = ls:FindFirstChild("Speed")
	if s and (s:IsA("NumberValue") or s:IsA("IntValue") or s:IsA("StringValue")) then
		return s, s.Value
	end
	return nil, nil
end

local function getSpeedNum()
	local _, v = getSpeedValue()
	return parseNum(v)
end

local function getRemote(name)
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	return folder and folder:FindFirstChild(name)
end

local function fireAction(action, amount)
	local remote = getRemote(action.name)
	if not remote then
		return false
	end
	local args = {}
	for _, v in ipairs(action.args) do
		if action.dynamic and type(v) == "number" then
			table.insert(args, amount)
		elseif action.dynamic and type(v) == "string" and tonumber(v) then
			table.insert(args, tostring(amount))
		else
			table.insert(args, v)
		end
	end
	local ok = pcall(function()
		if remote:IsA("RemoteEvent") then
			remote:FireServer(table.unpack(args))
		else
			remote:InvokeServer(table.unpack(args))
		end
	end)
	return ok
end

local function scanBelts()
	table.clear(cachedBelts)
	for _, inst in Workspace:GetDescendants() do
		if inst:IsA("BasePart") then
			local n = string.lower(inst.Name)
			if string.find(n, "treadmill", 1, true) or string.find(n, "belt", 1, true) then
				table.insert(cachedBelts, inst)
				if #cachedBelts >= 15 then
					break
				end
			end
		end
	end
end

local function touchBelts()
	if not fireTouch then
		return
	end
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	for _, p in cachedBelts do
		if p.Parent then
			pcall(fireTouch, p, hrp, 0)
			pcall(fireTouch, p, hrp, 1)
		end
	end
end

local function getActiveActions()
	if #savedActions > 0 then
		return savedActions
	end
	return DEFAULT_ACTIONS
end

-- Simulate one treadmill "tick" — replay saved profile
local function simulateTreadmillTick(amount)
	for _, action in ipairs(getActiveActions()) do
		fireAction(action, amount)
	end
	touchBelts()
end

local function stopLoops()
	running = false
	for _, c in loopConns do
		pcall(function()
			c:Disconnect()
		end)
	end
	table.clear(loopConns)
end

local function hookSpeedWatchers()
	for _, c in watchConns do
		pcall(function()
			c:Disconnect()
		end)
	end
	table.clear(watchConns)

	local inst = getSpeedValue()
	if inst then
		table.insert(watchConns, inst.Changed:Connect(function(new)
			if speedLabel then
				speedLabel.Text = "leaderstats.Speed = " .. tostring(new)
			end
		end))
	end
end

-- Record = test payloads, save ones that changed Speed (simulated recording)
local function runRecord()
	local ok, err = pcall(function()
		stopLoops()
		table.clear(savedActions)
		scanBelts()

		log("RECORD — testing payloads on treadmill...")
		if fakeLabel then
			fakeLabel.Text = "RECORDING — stand on treadmill!"
		end

		applyAmount = tonumber(targetBox and targetBox.Text) or applyAmount
		local before = getSpeedNum()

		for _, trial in ipairs(TRIAL_ACTIONS) do
			local spBefore = getSpeedNum()
			fireAction(trial, applyAmount)
			touchBelts()
			task.wait(0.25)
			local spAfter = getSpeedNum()
			if spBefore and spAfter and spAfter > spBefore then
				table.insert(savedActions, {
					name = trial.name,
					args = trial.args,
					dynamic = trial.dynamic,
				})
				log(string.format("  saved %s %s (+%s)", trial.name, table.concat(trial.args, ","), spAfter - spBefore))
			end
		end

		if #savedActions == 0 then
			log("No payload moved Speed — using default simulation")
			for _, a in ipairs(DEFAULT_ACTIONS) do
				table.insert(savedActions, a)
			end
		end

		local after = getSpeedNum()
		log(string.format("Profile: %d actions | Speed %s -> %s", #savedActions, tostring(before), tostring(after)))
		if fakeLabel then
			fakeLabel.Text = string.format("Saved %d ticks — press START", #savedActions)
		end
	end)

	if not ok then
		log("RECORD ERROR: " .. tostring(err))
		warn(err)
	end
end

local function runConstant()
	local ok, err = pcall(function()
		stopLoops()
		scanBelts()
		applyAmount = tonumber(targetBox and targetBox.Text) or applyAmount
		firesPerTick = math.clamp(tonumber(firesBox and firesBox.Text) or 8, 1, 30)

		running = true
		local frame = 0
		local lastNum = getSpeedNum() or 0
		local lastTime = os.clock()
		local totalGain = 0

		log("START — simulating " .. #getActiveActions() .. " saved ticks")
		if fakeLabel then
			fakeLabel.Text = "SIMULATING treadmill anywhere"
		end

		local function tick()
			if not running or not player.Parent then
				stopLoops()
				return
			end

			frame += 1
			applyAmount = tonumber(targetBox and targetBox.Text) or applyAmount

			for _ = 1, firesPerTick do
				simulateTreadmillTick(applyAmount)
			end

			local now = os.clock()
			local cur = getSpeedNum()
			if cur and lastNum and cur > lastNum then
				totalGain += cur - lastNum
				lastNum = cur
			end

			if now - lastTime >= 0.5 then
				local perSec = totalGain / math.max(now - lastTime, 0.001)
				local _, sv = getSpeedValue()
				if speedLabel then
					speedLabel.Text = "Speed = " .. tostring(sv)
				end
				if rateLabel then
					rateLabel.Text = string.format("+%.0f/s | frame %d", perSec, frame)
				end
				if fakeLabel then
					fakeLabel.Text = perSec > 0 and "SPEED RISING" or "Simulating (server may block off-belt)"
					fakeLabel.TextColor3 = perSec > 0 and Color3.fromRGB(80, 255, 120) or Color3.fromRGB(255, 190, 80)
				end
				totalGain = 0
				lastTime = now
			end

			if frame % 300 == 0 then
				applyAmount = math.min(applyAmount + stepAmount, 1e15)
			end
		end

		table.insert(loopConns, RunService.Heartbeat:Connect(tick))
	end)

	if not ok then
		stopLoops()
		log("START ERROR: " .. tostring(err))
		warn(err)
	end
end

-- === GUI ===
local function buildGui()
	local guiParent = CoreGui
	pcall(function()
		if gethui then
			guiParent = gethui()
		end
	end)

	for _, g in ipairs({ CoreGui, player:FindFirstChild("PlayerGui") }) do
		if g and g:FindFirstChild(GUI_NAME) then
			g[GUI_NAME]:Destroy()
		end
	end

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = GUI_NAME
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Enabled = true
	screenGui.DisplayOrder = 99999
	screenGui.Parent = guiParent
	if syn and syn.protect_gui then
		pcall(syn.protect_gui, screenGui)
	end

	local p = Instance.new("Frame")
	p.Size = UDim2.fromOffset(450, 400)
	p.Position = UDim2.fromScale(0.5, 0.5)
	p.AnchorPoint = Vector2.new(0.5, 0.5)
	p.BackgroundColor3 = Color3.fromRGB(22, 24, 32)
	p.Parent = screenGui
	Instance.new("UICorner", p).CornerRadius = UDim.new(0, 10)

	fakeLabel = Instance.new("TextLabel")
	fakeLabel.Size = UDim2.new(1, -20, 0, 44)
	fakeLabel.Position = UDim2.fromOffset(10, 10)
	fakeLabel.BackgroundColor3 = Color3.fromRGB(35, 28, 20)
	fakeLabel.Font = Enum.Font.GothamBold
	fakeLabel.TextSize = 12
	fakeLabel.TextWrapped = true
	fakeLabel.TextColor3 = Color3.fromRGB(255, 190, 80)
	fakeLabel.Text = "No RakNet — simulates FireServer ticks from Record"
	fakeLabel.Parent = p
	Instance.new("UICorner", fakeLabel).CornerRadius = UDim.new(0, 6)

	speedLabel = Instance.new("TextLabel")
	speedLabel.BackgroundTransparency = 1
	speedLabel.Position = UDim2.fromOffset(10, 58)
	speedLabel.Size = UDim2.new(1, -20, 0, 20)
	speedLabel.Font = Enum.Font.Code
	speedLabel.TextSize = 12
	speedLabel.TextColor3 = Color3.fromRGB(255, 230, 120)
	speedLabel.TextXAlignment = Enum.TextXAlignment.Left
	speedLabel.Text = "leaderstats.Speed = ?"
	speedLabel.Parent = p

	rateLabel = Instance.new("TextLabel")
	rateLabel.BackgroundTransparency = 1
	rateLabel.Position = UDim2.fromOffset(10, 80)
	rateLabel.Size = UDim2.new(1, -20, 0, 18)
	rateLabel.Font = Enum.Font.Gotham
	rateLabel.TextSize = 11
	rateLabel.TextColor3 = Color3.fromRGB(140, 200, 255)
	rateLabel.TextXAlignment = Enum.TextXAlignment.Left
	rateLabel.Text = "+0/s"
	rateLabel.Parent = p

	local function box(lbl, y, val)
		local l = Instance.new("TextLabel")
		l.Text = lbl
		l.Size = UDim2.fromOffset(95, 18)
		l.Position = UDim2.fromOffset(10, y)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.Gotham
		l.TextSize = 10
		l.TextColor3 = Color3.fromRGB(180, 185, 200)
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.Parent = p
		local b = Instance.new("TextBox")
		b.Size = UDim2.fromOffset(335, 22)
		b.Position = UDim2.fromOffset(105, y - 2)
		b.Text = tostring(val)
		b.BackgroundColor3 = Color3.fromRGB(12, 14, 20)
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Font = Enum.Font.Code
		b.TextSize = 11
		b.ClearTextOnFocus = false
		b.Parent = p
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
		return b
	end

	targetBox = box("Speed send", 104, applyAmount)
	firesBox = box("Ticks/frame", 130, firesPerTick)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Position = UDim2.fromOffset(10, 158)
	scroll.Size = UDim2.new(1, -20, 1, -200)
	scroll.BackgroundColor3 = Color3.fromRGB(10, 12, 18)
	scroll.BorderSizePixel = 0
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = p
	Instance.new("UICorner", scroll)

	logLabel = Instance.new("TextLabel")
	logLabel.Size = UDim2.new(1, -8, 0, 0)
	logLabel.AutomaticSize = Enum.AutomaticSize.Y
	logLabel.BackgroundTransparency = 1
	logLabel.Font = Enum.Font.Code
	logLabel.TextSize = 10
	logLabel.TextColor3 = Color3.fromRGB(190, 200, 215)
	logLabel.TextXAlignment = Enum.TextXAlignment.Left
	logLabel.TextWrapped = true
	logLabel.Parent = scroll

	local function mkbtn(t, x, w, fn, col)
		local b = Instance.new("TextButton")
		b.Text = t
		b.Size = UDim2.fromOffset(w, 34)
		b.Position = UDim2.fromOffset(x, 358)
		b.BackgroundColor3 = col
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Font = Enum.Font.GothamBold
		b.TextSize = 11
		b.Parent = p
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
		b.MouseButton1Click:Connect(fn)
	end

	mkbtn("Record", 8, 72, function()
		task.spawn(runRecord)
	end, Color3.fromRGB(180, 90, 40))
	mkbtn("START", 88, 72, function()
		task.spawn(runConstant)
	end, Color3.fromRGB(40, 150, 70))
	mkbtn("Stop", 168, 55, function()
		stopLoops()
		log("Stopped")
	end, Color3.fromRGB(180, 60, 60))
	mkbtn("X", 230, 55, function()
		stopLoops()
		screenGui:Destroy()
	end, Color3.fromRGB(70, 75, 90))
end

buildGui()
hookSpeedWatchers()
for _, a in ipairs(DEFAULT_ACTIONS) do
	table.insert(savedActions, a)
end
log("No RakNet — uses FireServer simulation.")
log("Record on treadmill saves working payloads.")
log("START replays them constantly. (START crash fixed)")
