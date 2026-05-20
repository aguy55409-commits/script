--[[
  CONSTANT SPEED / FAKE TREADMILL (Potassium + RakNet)

  Record = capture packets ONLY (no raknet replay during record — that caused crashes)
  START = constant treadmill ticks + replay

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

local GUI_NAME = "ConstantSpeedTest"
local hasRaknet = type(raknet) == "table"
	and type(raknet.send) == "function"
	and type(raknet.add_send_hook) == "function"

local running = false
local recording = false
local capturedPackets = {}
local cachedBelts = {}
local sendHookFn = nil
local loopConns = {}
local watchConns = {}
local applyAmount = 100
local stepAmount = 1000
local firesPerTick = 15
local captureUntil = 0

local logLines = {}
local fakeLabel
local speedLabel
local rateLabel
local logLabel
local firesBox
local targetBox
local screenGui

local fireTouch = firetouchinterest or (syn and syn.firetouchinterest)

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

local function parseNum(v)
	if type(v) == "number" then
		return v
	end
	if type(v) == "string" then
		return tonumber(v:gsub(",", ""))
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

local function safeClonePacketData(packet)
	local ok, arr = pcall(function()
		return packet.AsArray
	end)
	if ok and type(arr) == "table" then
		local t = {}
		for i, v in ipairs(arr) do
			t[i] = v
		end
		if #t > 0 then
			return t
		end
	end
	ok, arr = pcall(function()
		return packet.AsString
	end)
	if ok and type(arr) == "string" and #arr > 0 then
		return arr
	end
	return nil
end

local function storePacket(packet)
	local ok, err = pcall(function()
		if not packet then
			return
		end
		local data = safeClonePacketData(packet)
		if not data then
			return
		end
		local size = packet.Size or 0
		local key = tostring(packet.PacketId) .. ":" .. tostring(size)
		if type(data) == "table" then
			key ..= ":" .. tostring(data[1])
		end
		for _, p in capturedPackets do
			if p.key == key then
				return
			end
		end
		table.insert(capturedPackets, {
			key = key,
			data = data,
			priority = packet.Priority or 1,
			reliability = packet.Reliability or 0,
			ordering = packet.OrderingChannel or 0,
		})
		if #capturedPackets > 50 then
			table.remove(capturedPackets, 1)
		end
	end)
	if not ok then
		warn("[SpeedTest] storePacket: " .. tostring(err))
	end
end

local function setupRaknet()
	if not hasRaknet or sendHookFn then
		return true
	end
	sendHookFn = function(packet)
		-- Never call raknet.send from inside this hook
		if recording or os.clock() < captureUntil then
			storePacket(packet)
		end
	end
	local ok, err = pcall(raknet.add_send_hook, sendHookFn)
	if not ok then
		log("RakNet hook failed: " .. tostring(err))
		return false
	end
	log("RakNet hook OK")
	return true
end

local function scanBelts()
	table.clear(cachedBelts)
	for _, inst in Workspace:GetDescendants() do
		if inst:IsA("BasePart") then
			local n = string.lower(inst.Name)
			if string.find(n, "treadmill", 1, true) or string.find(n, "belt", 1, true) then
				table.insert(cachedBelts, inst)
			end
		end
	end
	return #cachedBelts
end

local function getRemotes()
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		return {}
	end
	return {
		TreadmillSignal = folder:FindFirstChild("TreadmillSignal"),
		CheckGold = folder:FindFirstChild("CheckGoldTreadmill"),
		SetCustom = folder:FindFirstChild("SetCustomSpeed"),
	}
end

-- FireServer only (safe during Record — no raknet.send replay)
local function fireRemotesOnly(amount)
	local r = getRemotes()
	captureUntil = os.clock() + 0.1

	pcall(function()
		if r.CheckGold and r.CheckGold:IsA("RemoteEvent") then
			r.CheckGold:FireServer()
			r.CheckGold:FireServer(true)
		end
		if r.TreadmillSignal and r.TreadmillSignal:IsA("RemoteEvent") then
			r.TreadmillSignal:FireServer()
			r.TreadmillSignal:FireServer(true)
		end
		if r.SetCustom and r.SetCustom:IsA("RemoteEvent") then
			r.SetCustom:FireServer(amount)
		end
	end)
end

local function touchCachedBelts()
	if not fireTouch then
		return
	end
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	for i = 1, math.min(#cachedBelts, 12) do
		local p = cachedBelts[i]
		if p and p.Parent then
			pcall(fireTouch, p, hrp, 0)
			pcall(fireTouch, p, hrp, 1)
		end
	end
end

local function replayRaknetOnce()
	if not hasRaknet or #capturedPackets == 0 or recording then
		return
	end
	for _, pkt in capturedPackets do
		pcall(raknet.send, pkt.data, pkt.priority, pkt.reliability, pkt.ordering)
	end
end

-- Full tick for START (includes replay)
local function fireFullTick(amount)
	fireRemotesOnly(amount)
	replayRaknetOnce()
	touchCachedBelts()
end

local function stopLoops()
	running = false
	recording = false
	captureUntil = 0
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

	local upd = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("UpdateSpeed")
	if upd and upd:IsA("RemoteEvent") then
		table.insert(watchConns, upd.OnClientEvent:Connect(function(a1, a2)
			log("<< UpdateSpeed: " .. tostring(a1) .. " " .. tostring(a2))
		end))
	end
end

local function runRecord()
	local ok, err = pcall(function()
		stopLoops()
		if not hasRaknet then
			log("No raknet — cannot record packets")
			return
		end
		if not setupRaknet() then
			return
		end

		scanBelts()
		table.clear(capturedPackets)
		recording = true

		log("RECORD 5s — walk on treadmill")
		if fakeLabel then
			fakeLabel.Text = "RECORDING — on treadmill!"
		end

		local t0 = os.clock()
		local n = 0
		while os.clock() - t0 < 5 and recording do
			n += 1
			-- ONLY FireServer during record (no raknet.send = no hook loop / crash)
			fireRemotesOnly(applyAmount)
			if n % 3 == 0 then
				touchCachedBelts()
			end
			if n % 5 == 0 then
				log("  recording... " .. #capturedPackets .. " pkts")
			end
			task.wait(0.2)
		end

		recording = false
		captureUntil = 0
		log("Done: " .. #capturedPackets .. " packets captured")
		if fakeLabel then
			fakeLabel.Text = #capturedPackets > 0
				and ("Got " .. #capturedPackets .. " pkts — press START")
				or "0 packets — walk on belt & Record again"
		end
	end)

	if not ok then
		recording = false
		captureUntil = 0
		log("RECORD CRASHED: " .. tostring(err))
		if fakeLabel then
			fakeLabel.Text = "Record error — see log"
		end
		warn(err)
	end
end

local function runConstant()
	if running then
		return
	end

	local ok, err = pcall(function()
		setupRaknet()
		scanBelts()
		applyAmount = tonumber(targetBox and targetBox.Text) or applyAmount
		firesPerTick = math.clamp(tonumber(firesBox and firesBox.Text) or 15, 1, 40)

		running = true
		local frame = 0
		local lastNum = getSpeedNum() or 0
		local lastTime = os.clock()
		local totalGain = 0

		log("START — constant ticks | pkts: " .. #capturedPackets)
		if #capturedPackets == 0 then
			log("No recorded packets — FireServer only")
		end
		if fakeLabel then
			fakeLabel.Text = "RUNNING"
		end

		local function tick()
			if not running or not player.Parent then
				stopLoops()
				return
			end

			frame += 1
			applyAmount = tonumber(targetBox and targetBox.Text) or applyAmount

			for _ = 1, firesPerTick do
				fireFullTick(applyAmount)
			end

			local now = os.clock()
			local cur = getSpeedNum()
			if cur and cur > lastNum then
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
					if perSec > 0 then
						fakeLabel.Text = "SPEED RISING"
						fakeLabel.TextColor3 = Color3.fromRGB(80, 255, 120)
					else
						fakeLabel.Text = "Running (server may block)"
						fakeLabel.TextColor3 = Color3.fromRGB(255, 190, 80)
					end
				end
				totalGain = 0
				lastTime = now
			end
		end

		table.insert(loopConns, RunService.Heartbeat:Connect(tick))
	end)

	if not ok then
		stopLoops()
		log("START CRASHED: " .. tostring(err))
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
		if g then
			local o = g:FindFirstChild(GUI_NAME)
			if o then
				o:Destroy()
			end
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
	p.Size = UDim2.fromOffset(460, 420)
	p.Position = UDim2.fromScale(0.5, 0.5)
	p.AnchorPoint = Vector2.new(0.5, 0.5)
	p.BackgroundColor3 = Color3.fromRGB(22, 24, 32)
	p.Parent = screenGui
	Instance.new("UICorner", p).CornerRadius = UDim.new(0, 10)

	fakeLabel = Instance.new("TextLabel")
	fakeLabel.Size = UDim2.new(1, -20, 0, 40)
	fakeLabel.Position = UDim2.fromOffset(10, 10)
	fakeLabel.BackgroundColor3 = Color3.fromRGB(35, 28, 20)
	fakeLabel.Font = Enum.Font.GothamBold
	fakeLabel.TextSize = 13
	fakeLabel.TextWrapped = true
	fakeLabel.TextColor3 = Color3.fromRGB(255, 190, 80)
	fakeLabel.Text = "Record on treadmill, then START anywhere"
	fakeLabel.Parent = p
	Instance.new("UICorner", fakeLabel).CornerRadius = UDim.new(0, 6)

	speedLabel = Instance.new("TextLabel")
	speedLabel.BackgroundTransparency = 1
	speedLabel.Position = UDim2.fromOffset(10, 56)
	speedLabel.Size = UDim2.new(1, -20, 0, 20)
	speedLabel.Font = Enum.Font.Code
	speedLabel.TextSize = 12
	speedLabel.TextColor3 = Color3.fromRGB(255, 230, 120)
	speedLabel.TextXAlignment = Enum.TextXAlignment.Left
	speedLabel.Text = "leaderstats.Speed = ?"
	speedLabel.Parent = p

	rateLabel = Instance.new("TextLabel")
	rateLabel.BackgroundTransparency = 1
	rateLabel.Position = UDim2.fromOffset(10, 78)
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
		l.Size = UDim2.fromOffset(100, 18)
		l.Position = UDim2.fromOffset(10, y)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.Gotham
		l.TextSize = 10
		l.TextColor3 = Color3.fromRGB(180, 185, 200)
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.Parent = p
		local b = Instance.new("TextBox")
		b.Size = UDim2.fromOffset(340, 22)
		b.Position = UDim2.fromOffset(110, y - 2)
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

	targetBox = box("Speed value", 102, applyAmount)
	firesBox = box("Fires/tick", 128, firesPerTick)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Position = UDim2.fromOffset(10, 158)
	scroll.Size = UDim2.new(1, -20, 1, -210)
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
		b.Position = UDim2.fromOffset(x, 378)
		b.BackgroundColor3 = col
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Font = Enum.Font.GothamBold
		b.TextSize = 11
		b.Parent = p
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
		b.MouseButton1Click:Connect(fn)
	end

	mkbtn("Record", 8, 70, function()
		task.spawn(runRecord)
	end, Color3.fromRGB(180, 90, 40))
	mkbtn("START", 84, 80, function()
		task.spawn(runConstant)
	end, Color3.fromRGB(40, 150, 70))
	mkbtn("Stop", 170, 60, function()
		stopLoops()
		log("Stopped")
		if fakeLabel then
			fakeLabel.Text = "Stopped"
		end
	end, Color3.fromRGB(180, 60, 60))
	mkbtn("X", 236, 50, function()
		stopLoops()
		if screenGui then
			screenGui:Destroy()
		end
	end, Color3.fromRGB(70, 75, 90))
end

buildGui()
hookSpeedWatchers()
scanBelts()
log("GUI ready.")
log(hasRaknet and "RakNet: Record captures packets safely" or "No raknet library")
log("Record = FireServer only | START = replay + FireServer")
