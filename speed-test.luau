--[[
  FAKE TREADMILL + RAKNET REPLAY (Potassium)

  1) RECORD — stand on treadmill 5 sec (captures real network packets via raknet hook)
  2) START — replays those packets anywhere + FireServer backup

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

local GUI_NAME = "FakeTreadmillRakNet"
local hasRaknet = type(raknet) == "table" and type(raknet.add_send_hook) == "function" and type(raknet.send) == "function"

local REMOTE_PATHS = {
	TreadmillSignal = "ReplicatedStorage.Remotes.TreadmillSignal",
	CheckGoldTreadmill = "ReplicatedStorage.Remotes.CheckGoldTreadmill",
	SetCustomSpeed = "ReplicatedStorage.Remotes.SetCustomSpeed",
}

local running = false
local recording = false
local replayPerFrame = 3
local applyAmount = 100
local stepAmount = 500

local capturedPackets = {}
local sendHookFn = nil
local heartbeatConn = nil
local captureUntil = 0
local logLines = {}
local fakeStatusLabel
local liveLabel
local statusLabel
local logLabel
local replayBox
local targetBox

local fireTouch = firetouchinterest
	or (syn and syn.firetouchinterest)
	or (fluxus and fluxus.firetouchinterest)

local function log(msg)
	table.insert(logLines, msg)
	if #logLines > 70 then
		table.remove(logLines, 1)
	end
	print("[SpeedTest] " .. msg)
	if logLabel then
		logLabel.Text = table.concat(logLines, "\n")
	end
end

local function getRemote(path)
	local obj = game
	for part in string.gmatch(path, "[^%.]+") do
		obj = obj and obj:FindFirstChild(part)
	end
	return obj
end

local function getSpeed()
	local ls = player:FindFirstChild("leaderstats")
	if not ls then
		return nil
	end
	local s = ls:FindFirstChild("Speed")
	if s and (s:IsA("NumberValue") or s:IsA("IntValue") or s:IsA("StringValue")) then
		return s.Value
	end
	return nil
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
	local out = {}
	for i, v in arr do
		out[i] = v
	end
	return out
end

local function packetKey(packet)
	local arr = packet.AsArray
	if type(arr) == "table" and #arr > 0 then
		return string.format("%d:%d:%s", packet.PacketId or 0, packet.Size or 0, tostring(arr[1]))
	end
	return tostring(packet.PacketId) .. ":" .. tostring(packet.Size)
end

local function storePacket(packet)
	if not packet then
		return
	end
	local key = packetKey(packet)
	for _, p in capturedPackets do
		if p.key == key then
			return
		end
	end
	local data = cloneArray(packet.AsArray)
	if not data and packet.AsString and #packet.AsString > 0 then
		data = packet.AsString
	end
	if not data then
		return
	end
	table.insert(capturedPackets, {
		key = key,
		data = data,
		priority = packet.Priority or 1,
		reliability = packet.Reliability or 0,
		ordering = packet.OrderingChannel or 0,
		packetId = packet.PacketId,
		size = packet.Size,
	})
	if #capturedPackets > 40 then
		table.remove(capturedPackets, 1)
	end
end

local function setupRaknetHook()
	if not hasRaknet or sendHookFn then
		return
	end
	sendHookFn = function(packet)
		if recording or os.clock() < captureUntil then
			storePacket(packet)
		end
	end
	raknet.add_send_hook(sendHookFn)
	log("RakNet send hook active.")
end

local function replayPackets(count)
	if not hasRaknet or #capturedPackets == 0 then
		return 0
	end
	local n = math.min(count or 1, #capturedPackets)
	for i = 1, n do
		local pkt = capturedPackets[(i % #capturedPackets) + 1]
		pcall(function()
			raknet.send(pkt.data, pkt.priority, pkt.reliability, pkt.ordering)
		end)
	end
	return n
end

local function fireRemotes()
	applyAmount = tonumber(targetBox.Text) or applyAmount
	local sig = getRemote(REMOTE_PATHS.TreadmillSignal)
	local check = getRemote(REMOTE_PATHS.CheckGoldTreadmill)
	local custom = getRemote(REMOTE_PATHS.SetCustomSpeed)

	if check and check:IsA("RemoteEvent") then
		pcall(function()
			check:FireServer()
			check:FireServer(true)
		end)
	end
	if sig and sig:IsA("RemoteEvent") then
		captureUntil = os.clock() + 0.08
		pcall(function()
			sig:FireServer()
			sig:FireServer(true)
		end)
	end
	if custom and custom:IsA("RemoteEvent") then
		pcall(function()
			custom:FireServer(applyAmount)
			custom:FireServer(tostring(applyAmount))
		end)
	end
end

local function ghostTouchBelts()
	if not fireTouch then
		return
	end
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
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

local function stopAll()
	running = false
	recording = false
	captureUntil = 0
	if heartbeatConn then
		heartbeatConn:Disconnect()
		heartbeatConn = nil
	end
end

local function runRecord()
	if not hasRaknet then
		log("No raknet library — use Potassium with raknet enabled.")
		return
	end
	setupRaknetHook()
	stopAll()
	recording = true
	capturedPackets = {}
	log("=== RECORD 5 sec ===")
	log("STAND ON TREADMILL NOW — walk on belt!")
	fakeStatusLabel.Text = "RECORDING... stand on treadmill!"

	local t0 = os.clock()
	while os.clock() - t0 < 5 do
		fireRemotes()
		ghostTouchBelts()
		task.wait(0.15)
	end

	recording = false
	log(string.format("Captured %d unique packets.", #capturedPackets))
	for i, p in ipairs(capturedPackets) do
		if i <= 6 then
			log(string.format("  [%d] id=%s size=%s", i, tostring(p.packetId), tostring(p.size)))
		end
	end
	if #capturedPackets == 0 then
		log("No packets captured. Walk on belt while recording.")
		fakeStatusLabel.Text = "Record failed — no packets"
	else
		fakeStatusLabel.Text = string.format("Got %d packets — press START anywhere", #capturedPackets)
	end
end

local function runReplay()
	if running then
		return
	end
	setupRaknetHook()
	applyAmount = tonumber(targetBox.Text) or applyAmount
	replayPerFrame = math.clamp(tonumber(replayBox.Text) or 3, 1, 20)

	if #capturedPackets == 0 and not hasRaknet then
		log("Record first (needs raknet), or no packets stored.")
	end

	running = true
	local tickNum = 0
	local lastSpeed = getSpeed()

	log("=== REPLAY (anywhere) ===")
	log(string.format("Packets: %d | replay/frame: %d", #capturedPackets, replayPerFrame))
	fakeStatusLabel.Text = "REPLAY ACTIVE — fake treadmill anywhere"

	stopAll()
	heartbeatConn = RunService.Heartbeat:Connect(function()
		if not running then
			return
		end
		tickNum += 1

		replayPackets(replayPerFrame)
		fireRemotes()
		ghostTouchBelts()

		if tickNum % 90 == 0 then
			applyAmount = math.min(applyAmount + stepAmount, 1e15)
			local sp = getSpeed()
			local b, a = parseNum(lastSpeed), parseNum(sp)
			local delta = (b and a) and (a - b) or 0
			lastSpeed = sp
			log(string.format("tick %d | Speed=%s | +%s | pkts=%d", tickNum, tostring(sp), tostring(delta), #capturedPackets))
			if liveLabel then
				liveLabel.Text = "leaderstats.Speed = " .. tostring(sp)
			end
			if delta > 0 then
				fakeStatusLabel.Text = "WORKING — Speed rising anywhere"
			elseif #capturedPackets > 0 then
				fakeStatusLabel.Text = "Replaying packets (server may block)"
			else
				fakeStatusLabel.Text = "No packets — Record on treadmill first"
			end
		end
	end)
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
panel.Size = UDim2.fromOffset(450, 480)
panel.BackgroundColor3 = Color3.fromRGB(24, 26, 34)
panel.Parent = screenGui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(12, 8)
title.Size = UDim2.new(1, -24, 0, 22)
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Fake Treadmill + RakNet Replay"
title.Parent = panel

fakeStatusLabel = Instance.new("TextLabel")
fakeStatusLabel.BackgroundColor3 = Color3.fromRGB(28, 22, 18)
fakeStatusLabel.Position = UDim2.fromOffset(12, 32)
fakeStatusLabel.Size = UDim2.new(1, -24, 0, 44)
fakeStatusLabel.Font = Enum.Font.GothamBold
fakeStatusLabel.TextSize = 12
fakeStatusLabel.TextWrapped = true
fakeStatusLabel.TextColor3 = Color3.fromRGB(255, 190, 90)
fakeStatusLabel.Text = hasRaknet and "Step 1: RECORD on treadmill  |  Step 2: START anywhere" or "raknet missing — FireServer only (weak)"
fakeStatusLabel.Parent = panel
Instance.new("UICorner", fakeStatusLabel).CornerRadius = UDim.new(0, 6)

liveLabel = Instance.new("TextLabel")
liveLabel.BackgroundTransparency = 1
liveLabel.Position = UDim2.fromOffset(12, 82)
liveLabel.Size = UDim2.new(1, -24, 0, 18)
liveLabel.Font = Enum.Font.Code
liveLabel.TextSize = 10
liveLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
liveLabel.TextXAlignment = Enum.TextXAlignment.Left
liveLabel.Text = "leaderstats.Speed = " .. tostring(getSpeed())
liveLabel.Parent = panel

statusLabel = Instance.new("TextLabel")
statusLabel.BackgroundTransparency = 1
statusLabel.Position = UDim2.fromOffset(12, 102)
statusLabel.Size = UDim2.new(1, -24, 0, 36)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 10
statusLabel.TextWrapped = true
statusLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Text = "RakNet replays REAL packets from when you were on the belt."
statusLabel.Parent = panel

local function numBox(label, y, default)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromOffset(12, y)
	l.Size = UDim2.fromOffset(115, 18)
	l.Font = Enum.Font.Gotham
	l.TextSize = 10
	l.TextColor3 = Color3.fromRGB(180, 185, 200)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = label
	l.Parent = panel

	local b = Instance.new("TextBox")
	b.Position = UDim2.fromOffset(132, y - 2)
	b.Size = UDim2.fromOffset(306, 22)
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

targetBox = numBox("Speed send", 142, applyAmount)
replayBox = numBox("Replay/frame", 168, replayPerFrame)

local scroll = Instance.new("ScrollingFrame")
scroll.Position = UDim2.fromOffset(12, 198)
scroll.Size = UDim2.new(1, -24, 1, -150)
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
	b.Position = UDim2.fromOffset(x, 438)
	b.Size = UDim2.fromOffset(w, 36)
	b.BackgroundColor3 = col or Color3.fromRGB(45, 120, 70)
	b.TextColor3 = Color3.fromRGB(255, 255, 255)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 11
	b.Text = text
	b.Parent = panel
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
	b.MouseButton1Click:Connect(fn)
end

btn("Record", 8, 72, function()
	task.spawn(runRecord)
end, Color3.fromRGB(180, 100, 40))
btn("START", 86, 72, function()
	task.spawn(runReplay)
end, Color3.fromRGB(50, 140, 80))
btn("Stop", 164, 52, function()
	stopAll()
	log("Stopped.")
	fakeStatusLabel.Text = "Stopped"
end, Color3.fromRGB(180, 70, 70))
btn("Fire", 220, 52, function()
	fireRemotes()
	log("Fired remotes once.")
end, Color3.fromRGB(70, 100, 150))
btn("X", 276, 52, function()
	stopAll()
	screenGui:Destroy()
end, Color3.fromRGB(80, 85, 100))

setupRaknetHook()
log(hasRaknet and "RakNet OK — record on treadmill first!" or "WARNING: raknet not found in executor")
log("Record = capture real packets | START = replay anywhere")
