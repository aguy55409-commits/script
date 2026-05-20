--[[
  CONSTANT SPEED / FAKE TREADMILL (Potassium + RakNet)

  START = non-stop treadmill ticks + raknet replay until you Stop.
  Watches leaderstats.Speed every frame.

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
local hasRaknet = type(raknet) == "table" and type(raknet.send) == "function" and type(raknet.add_send_hook) == "function"

local running = false
local recording = false
local capturedPackets = {}
local sendHookFn = nil
local conns = {}
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

local function parseNum(v)
	if type(v) == "number" then
		return v
	end
	if type(v) == "string" then
		return tonumber(v:gsub(",", ""))
	end
	return nil
end

local function cloneArray(arr)
	if type(arr) ~= "table" then
		return nil
	end
	local t = {}
	for i, v in arr do
		t[i] = v
	end
	return t
end

local function storePacket(packet)
	if not packet then
		return
	end
	local arr = cloneArray(packet.AsArray)
	if not arr then
		return
	end
	local key = tostring(packet.PacketId) .. ":" .. tostring(packet.Size) .. ":" .. tostring(arr[1])
	for _, p in capturedPackets do
		if p.key == key then
			return
		end
	end
	table.insert(capturedPackets, {
		key = key,
		data = arr,
		priority = packet.Priority or 1,
		reliability = packet.Reliability or 0,
		ordering = packet.OrderingChannel or 0,
	})
	if #capturedPackets > 80 then
		table.remove(capturedPackets, 1)
	end
end

local function setupRaknet()
	if not hasRaknet or sendHookFn then
		return
	end
	sendHookFn = function(packet)
		if recording or os.clock() < captureUntil then
			storePacket(packet)
		end
	end
	pcall(raknet.add_send_hook, sendHookFn)
end

local function getRemotes()
	return {
		TreadmillSignal = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("TreadmillSignal"),
		CheckGold = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("CheckGoldTreadmill"),
		SetCustom = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("SetCustomSpeed"),
	}
end

-- One full "treadmill tick" burst — this is what must run CONSTANTLY
local function fireTreadmillTick(amount)
	local r = getRemotes()
	captureUntil = os.clock() + 0.15

	if r.CheckGold and r.CheckGold:IsA("RemoteEvent") then
		r.CheckGold:FireServer()
		r.CheckGold:FireServer(true)
		r.CheckGold:FireServer(player.UserId)
	end

	if r.TreadmillSignal and r.TreadmillSignal:IsA("RemoteEvent") then
		-- Every payload shape games use for "on treadmill, gain speed"
		r.TreadmillSignal:FireServer()
		r.TreadmillSignal:FireServer(true)
		r.TreadmillSignal:FireServer(1)
		r.TreadmillSignal:FireServer("tick")
		r.TreadmillSignal:FireServer("run")
		r.TreadmillSignal:FireServer(true, true)
	end

	if r.SetCustom and r.SetCustom:IsA("RemoteEvent") then
		r.SetCustom:FireServer(amount)
		r.SetCustom:FireServer(tostring(amount))
	end

	-- RakNet replay captured treadmill packets
	if hasRaknet and #capturedPackets > 0 then
		for _, pkt in capturedPackets do
			pcall(raknet.send, pkt.data, pkt.priority, pkt.reliability, pkt.ordering)
		end
	end

	-- Fake touch all belts (from anywhere)
	if fireTouch then
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if hrp then
			for _, p in Workspace:GetDescendants() do
				if p:IsA("BasePart") then
					local n = string.lower(p.Name)
					if string.find(n, "treadmill", 1, true) or string.find(n, "belt", 1, true) then
						pcall(fireTouch, p, hrp, 0)
						pcall(fireTouch, p, hrp, 1)
					end
				end
			end
		end
	end
end

local function hookSpeedWatchers()
	for _, c in conns do
		pcall(function()
			c:Disconnect()
		end)
	end
	table.clear(conns)

	local inst, val = getSpeedValue()
	if inst then
		table.insert(conns, inst.Changed:Connect(function(new)
			if speedLabel then
				speedLabel.Text = "leaderstats.Speed = " .. tostring(new) .. "  (CHANGED)"
			end
		end))
	end

	local upd = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("UpdateSpeed")
	if upd and upd:IsA("RemoteEvent") then
		table.insert(conns, upd.OnClientEvent:Connect(function(...)
			local args = { ... }
			log("<< UpdateSpeed from server: " .. table.concat(args, ", "))
			if speedLabel then
				speedLabel.Text = "Speed synced: " .. tostring(args[1] or args[2] or "?")
			end
		end))
	end
end

local function stopAll()
	running = false
	recording = false
	for _, c in conns do
		pcall(function()
			c:Disconnect()
		end)
	end
	table.clear(conns)
end

local function runRecord()
	setupRaknet()
	stopAll()
	recording = true
	table.clear(capturedPackets)
	log("RECORD 5s — walk on treadmill!")
	fakeLabel.Text = "RECORDING — on treadmill!"

	local t0 = os.clock()
	while os.clock() - t0 < 5 do
		fireTreadmillTick(applyAmount)
		task.wait(0.1)
	end
	recording = false
	log("Captured " .. #capturedPackets .. " packets")
	fakeLabel.Text = #capturedPackets > 0 and ("Got " .. #capturedPackets .. " pkts — press START") or "Record failed — 0 packets"
end

local function runConstant()
	if running then
		return
	end

	setupRaknet()
	hookSpeedWatchers()
	applyAmount = tonumber(targetBox.Text) or applyAmount
	firesPerTick = math.clamp(tonumber(firesBox.Text) or 15, 1, 50)

	running = true
	local frame = 0
	local lastNum = getSpeedNum() or 0
	local lastTime = os.clock()
	local totalGain = 0
	local staleFrames = 0

	log("=== CONSTANT SPEED ON ===")
	log("Fires/tick: " .. firesPerTick .. " | pkts: " .. #capturedPackets)
	if #capturedPackets == 0 then
		log("Tip: Record on treadmill first for raknet packets")
	end
	fakeLabel.Text = "CONSTANT — spamming treadmill ticks"

	local function tick()
		if not running or not player.Parent then
			stopAll()
			return
		end

		frame += 1
		applyAmount = tonumber(targetBox.Text) or applyAmount

		-- MAIN: repeat treadmill tick many times per frame
		for _ = 1, firesPerTick do
			fireTreadmillTick(applyAmount)
		end

		-- Also try client write (tests if stat is client-trusted — usually isn't)
		local inst = getSpeedValue()
		if inst and (inst:IsA("NumberValue") or inst:IsA("IntValue")) then
			pcall(function()
				inst.Value = applyAmount
			end)
		end

		local now = os.clock()
		local cur = getSpeedNum()
		if cur and cur > lastNum then
			totalGain += cur - lastNum
			lastNum = cur
			staleFrames = 0
		else
			staleFrames += 1
		end

		if now - lastTime >= 0.5 then
			local perSec = totalGain / math.max(now - lastTime, 0.001)
			if speedLabel then
				local _, sv = getSpeedValue()
				speedLabel.Text = string.format("Speed = %s | +%.0f/s", tostring(sv), perSec)
			end
			if rateLabel then
				rateLabel.Text = string.format("+%.0f/s | frame %d | stale %d", perSec, frame, staleFrames)
			end
			if perSec > 0 then
				fakeLabel.Text = "SPEED RISING"
				fakeLabel.TextColor3 = Color3.fromRGB(80, 255, 120)
			elseif staleFrames > 120 then
				fakeLabel.Text = "Server not adding Speed (AC blocking)"
				fakeLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
				if frame % 300 == 0 then
					log("Speed stuck — server ignores client ticks. Patch server treadmill.")
				end
			else
				fakeLabel.Text = "Firing... waiting for server"
				fakeLabel.TextColor3 = Color3.fromRGB(255, 190, 90)
			end
			totalGain = 0
			lastTime = now
		end

		if frame % 200 == 0 then
			applyAmount = math.min(applyAmount + stepAmount, 1e15)
			-- Keep recording new packets while running on treadmill
			if hasRaknet then
				recording = true
				task.delay(0.1, function()
					recording = false
				end)
			end
		end
	end

	-- Heartbeat + RenderStepped = maximum fire rate
	table.insert(conns, RunService.Heartbeat:Connect(tick))
	table.insert(conns, RunService.RenderStepped:Connect(tick))
end

-- === GUI (must not error or nothing shows) ===
local sg
local guiParent = CoreGui
pcall(function()
	if gethui then
		guiParent = gethui()
	end
end)
if not guiParent then
	guiParent = CoreGui
end

for _, g in ipairs({ CoreGui, player:FindFirstChild("PlayerGui") }) do
	if g then
		local o = g:FindFirstChild(GUI_NAME)
		if o then
			o:Destroy()
		end
	end
end

sg = Instance.new("ScreenGui")
sg.Name = GUI_NAME
sg.ResetOnSpawn = false
sg.IgnoreGuiInset = true
sg.Enabled = true
sg.DisplayOrder = 99999
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.Parent = guiParent
if syn and syn.protect_gui then
	pcall(syn.protect_gui, sg)
end

local p = Instance.new("Frame")
p.Size = UDim2.fromOffset(460, 420)
p.Position = UDim2.fromScale(0.5, 0.5)
p.AnchorPoint = Vector2.new(0.5, 0.5)
p.BackgroundColor3 = Color3.fromRGB(22, 24, 32)
p.BorderSizePixel = 0
p.Active = true
p.Parent = sg
Instance.new("UICorner", p).CornerRadius = UDim.new(0, 10)

fakeLabel = Instance.new("TextLabel")
fakeLabel.Size = UDim2.new(1, -20, 0, 40)
fakeLabel.Position = UDim2.fromOffset(10, 10)
fakeLabel.BackgroundColor3 = Color3.fromRGB(35, 28, 20)
fakeLabel.Font = Enum.Font.GothamBold
fakeLabel.TextSize = 13
fakeLabel.TextColor3 = Color3.fromRGB(255, 190, 80)
fakeLabel.TextWrapped = true
fakeLabel.Text = "START = constant treadmill ticks (anywhere)"
fakeLabel.Parent = p
Instance.new("UICorner", fakeLabel).CornerRadius = UDim.new(0, 6)

speedLabel = Instance.new("TextLabel")
speedLabel.BackgroundTransparency = 1
speedLabel.Position = UDim2.fromOffset(10, 56)
speedLabel.Size = UDim2.new(1, -20, 0, 22)
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
logLabel.Text = "Ready."

local function mkbtn(t, x, w, fn, c)
	local b = Instance.new("TextButton")
	b.Text = t
	b.Size = UDim2.fromOffset(w, 34)
	b.Position = UDim2.fromOffset(x, 378)
	b.BackgroundColor3 = c
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
	stopAll()
	log("Stopped")
	fakeLabel.Text = "Stopped"
end, Color3.fromRGB(180, 60, 60))
mkbtn("X", 236, 50, function()
	stopAll()
	sg:Destroy()
end, Color3.fromRGB(70, 75, 90))

pcall(setupRaknet)
pcall(hookSpeedWatchers)
log("GUI loaded.")
log(hasRaknet and "RakNet ready" or "No raknet — FireServer only")
log("START = constant treadmill ticks")
