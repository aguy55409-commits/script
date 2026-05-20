--[[
  FAKE TREADMILL — makes the game think you're on the belt gaining speed, anywhere.

  Ghost-touch belt + spoof flags + spam TreadmillSignal / CheckGoldTreadmill constantly.

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

local GUI_NAME = "FakeTreadmillSpeed"

local TREADMILL_REMOTE_NAMES = {
	"TreadmillSignal",
	"CheckGoldTreadmill",
	"TreadmillTick",
	"TreadmillRun",
	"TreadmillStart",
	"TreadmillStop",
	"SetCustomSpeed",
}

local SPOOF_ATTRS = {
	"OnTreadmill",
	"onTreadmill",
	"Running",
	"Treadmill",
	"OnTreadmillBelt",
	"IsRunning",
	"TreadmillActive",
	"IsOnTreadmill",
}

local TICK_PAYLOADS = {
	{ label = "tick", args = {} },
	{ label = "true", args = { true } },
	{ label = "on", args = { true, true } },
	{ label = "1", args = { 1 } },
	{ label = "run", args = { "run" } },
	{ label = "start", args = { "start" } },
	{ label = "tick str", args = { "tick" } },
	{ label = "uid", args = { player.UserId } },
	{ label = "uid+true", args = { player.UserId, true } },
}

local running = false
local ticksPerFrame = 8
local targetSpeed = 100
local stepSpeed = 500
local useGhostTouch = true
local useSpoofAttrs = true
local useClientWalk = true

local treadmillRemotes = {}
local treadmillBelts = {}
local speedStatName = "Speed"
local logLines = {}
local statusLabel
local fakeStatusLabel
local liveLabel
local logLabel
local ticksBox
local targetBox
local stepBox
local heartbeatConn = nil
local tickCount = 0
local applyAmount = 100

local fireTouch = firetouchinterest
	or (syn and syn.firetouchinterest)
	or (fluxus and fluxus.firetouchinterest)

local function log(text)
	table.insert(logLines, text)
	if #logLines > 65 then
		table.remove(logLines, 1)
	end
	print("[FakeTreadmill] " .. text)
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

local function getSpeed()
	local ls = player:FindFirstChild("leaderstats")
	if not ls then
		return nil
	end
	local s = ls:FindFirstChild(speedStatName) or ls:FindFirstChild("Speed")
	if s and (s:IsA("NumberValue") or s:IsA("IntValue") or s:IsA("StringValue")) then
		return s.Value
	end
	return nil
end

local function isTreadmillRemote(name)
	local n = string.lower(name)
	if string.find(n, "prompt", 1, true) then
		return false
	end
	for _, want in TREADMILL_REMOTE_NAMES do
		if string.find(n, string.lower(want), 1, true) then
			return true
		end
	end
	return string.find(n, "treadmill", 1, true) ~= nil
end

local function isBeltPart(inst)
	if not inst:IsA("BasePart") then
		return false
	end
	local n = string.lower(inst.Name)
	local p = inst.Parent and string.lower(inst.Parent.Name) or ""
	return string.find(n, "treadmill", 1, true)
		or string.find(n, "belt", 1, true)
		or string.find(n, "runner", 1, true)
		or string.find(p, "treadmill", 1, true)
end

local function scanGame()
	table.clear(treadmillRemotes)
	table.clear(treadmillBelts)

	for _, inst in ReplicatedStorage:GetDescendants() do
		if (inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction")) and isTreadmillRemote(inst.Name) then
			table.insert(treadmillRemotes, inst)
		end
	end

	-- Hardcoded paths for your game
	local paths = {
		"ReplicatedStorage.Remotes.TreadmillSignal",
		"ReplicatedStorage.Remotes.CheckGoldTreadmill",
		"ReplicatedStorage.Remotes.SetCustomSpeed",
	}
	for _, path in paths do
		local obj = game
		for part in string.gmatch(path, "[^%.]+") do
			if part ~= "game" then
				obj = obj and obj:FindFirstChild(part)
			end
		end
		if obj and (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")) then
			local dup = false
			for _, r in treadmillRemotes do
				if r == obj then
					dup = true
					break
				end
			end
			if not dup then
				table.insert(treadmillRemotes, obj)
			end
		end
	end

	for _, inst in Workspace:GetDescendants() do
		if isBeltPart(inst) then
			table.insert(treadmillBelts, inst)
		end
	end

	local plot = Workspace:FindFirstChild(player.Name) or Workspace:FindFirstChild(player.DisplayName)
	if plot then
		for _, inst in plot:GetDescendants() do
			if isBeltPart(inst) and not table.find(treadmillBelts, inst) then
				table.insert(treadmillBelts, inst)
			end
		end
	end

	return #treadmillRemotes, #treadmillBelts
end

local function getBestBelt()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp or #treadmillBelts == 0 then
		return treadmillBelts[1]
	end
	local best, bestD = treadmillBelts[1], math.huge
	for _, part in treadmillBelts do
		if part.Parent then
			local d = (hrp.Position - part.Position).Magnitude
			if d < bestD then
				bestD = d
				best = part
			end
		end
	end
	return best
end

local function spoofTreadmillState()
	if not useSpoofAttrs then
		return
	end
	for _, name in SPOOF_ATTRS do
		pcall(function()
			player:SetAttribute(name, true)
		end)
		local char = player.Character
		if char then
			pcall(function()
				char:SetAttribute(name, true)
			end)
		end
	end
end

local function fireRemote(inst, args)
	if inst:IsA("RemoteEvent") then
		inst:FireServer(table.unpack(args))
	else
		inst:InvokeServer(table.unpack(args))
	end
end

local function fireAllTreadmillRemotes(amount)
	for _, remote in treadmillRemotes do
		local n = string.lower(remote.Name)
		-- Registration / check remotes
		if string.find(n, "check", 1, true) or string.find(n, "gold", 1, true) then
			pcall(fireRemote, remote, {})
			pcall(fireRemote, remote, { true })
			pcall(fireRemote, remote, { player.UserId })
		elseif string.find(n, "setcustom", 1, true) or string.find(n, "setspeed", 1, true) then
			pcall(fireRemote, remote, { amount })
			pcall(fireRemote, remote, { tostring(amount) })
		else
			-- TreadmillSignal — every "on treadmill" payload
			for _, pack in TICK_PAYLOADS do
				pcall(fireRemote, remote, pack.args)
			end
		end
	end
end

-- Teleport to belt for 1 frame, touch, fire remotes, teleport back (game thinks you're on belt)
local function ghostTouchBelt()
	if not useGhostTouch then
		return
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local belt = getBestBelt()
	if not hrp or not belt or not belt.Parent then
		return
	end

	local saved = hrp.CFrame
	local y = belt.Size.Y / 2 + hrp.Size.Y / 2 + 0.3
	local onBelt = belt.CFrame * CFrame.new(0, y, 0)

	pcall(function()
		hrp.CFrame = onBelt
		if fireTouch and belt.CanTouch ~= false then
			fireTouch(belt, hrp, 0)
			fireTouch(belt, hrp, 1)
		end
		fireAllTreadmillRemotes(applyAmount)
		hrp.CFrame = saved
	end)
end

local function applyClientSpeed()
	if not useClientWalk then
		return
	end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = math.clamp(applyAmount / 10, 16, 500)
	end
end

local function fakeTreadmillTick()
	tickCount += 1
	spoofTreadmillState()
	applyClientSpeed()

	local n = math.clamp(tonumber(ticksBox and ticksBox.Text) or ticksPerFrame, 1, 30)
	for _ = 1, n do
		ghostTouchBelt()
		fireAllTreadmillRemotes(applyAmount)
	end

	-- Also touch ALL belts from current position (some executors register touch at distance)
	if fireTouch then
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if hrp then
			for _, belt in treadmillBelts do
				if belt.Parent and belt.CanTouch ~= false then
					pcall(fireTouch, belt, hrp, 0)
					pcall(fireTouch, belt, hrp, 1)
				end
			end
		end
	end
end

local function stopFake()
	running = false
	if heartbeatConn then
		heartbeatConn:Disconnect()
		heartbeatConn = nil
	end
end

local function startFakeTreadmill()
	if running then
		return
	end

	local nr, nb = scanGame()
	applyAmount = tonumber(targetBox.Text) or targetSpeed
	stepSpeed = tonumber(stepBox.Text) or stepSpeed

	if nr == 0 then
		log("No treadmill remotes — scan when in-game.")
	end
	if nb == 0 then
		log("No belt parts found — ghost touch uses remotes only.")
	end

	running = true
	tickCount = 0

	log("=== FAKE TREADMILL ON (anywhere) ===")
	log(string.format("Remotes: %d | Belts: %d | ghost=%s", nr, nb, tostring(useGhostTouch)))
	for _, r in treadmillRemotes do
		log("  -> " .. r.Name)
	end

	stopFake()
	heartbeatConn = RunService.Heartbeat:Connect(function()
		if not running or not player.Parent then
			stopFake()
			return
		end
		fakeTreadmillTick()

		if tickCount % 120 == 0 then
			applyAmount = math.min(applyAmount + stepSpeed, 1e15)
			scanGame()
		end

		if tickCount % 60 == 0 then
			local sp = getSpeed()
			log(string.format("tick %d | fake ON | Speed=%s", tickCount, tostring(sp)))
			if fakeStatusLabel then
				fakeStatusLabel.Text = "FAKE TREADMILL ACTIVE — gaining anywhere | Speed=" .. tostring(sp)
			end
			if statusLabel then
				statusLabel.Text = string.format("Running tick %d | apply %s", tickCount, applyAmount)
			end
			if liveLabel and sp then
				liveLabel.Text = "leaderstats.Speed = " .. tostring(sp)
			end
		end
	end)

	log("Constant fake treadmill loop started. Walk anywhere.")
end

local function runScan()
	local nr, nb = scanGame()
	log("=== SCAN ===")
	log(string.format("Treadmill remotes: %d", nr))
	for _, r in treadmillRemotes do
		log("  " .. r:GetFullName())
	end
	log(string.format("Belt parts: %d", nb))
	for i, b in ipairs(treadmillBelts) do
		if i <= 5 then
			log("  " .. b:GetFullName())
		end
	end
	if nb > 5 then
		log("  ... +" .. (nb - 5) .. " more")
	end
	log("Speed = " .. tostring(getSpeed()))
	if fakeStatusLabel then
		fakeStatusLabel.Text = nr > 0 and "Ready — press START to fake treadmill anywhere" or "No remotes found"
	end
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
panel.Size = UDim2.fromOffset(440, 460)
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
title.Text = "Fake Treadmill (speed anywhere)"
title.Parent = panel

fakeStatusLabel = Instance.new("TextLabel")
fakeStatusLabel.BackgroundColor3 = Color3.fromRGB(30, 22, 18)
fakeStatusLabel.Position = UDim2.fromOffset(12, 32)
fakeStatusLabel.Size = UDim2.new(1, -24, 0, 40)
fakeStatusLabel.Font = Enum.Font.GothamBold
fakeStatusLabel.TextSize = 12
fakeStatusLabel.TextWrapped = true
fakeStatusLabel.TextColor3 = Color3.fromRGB(255, 180, 80)
fakeStatusLabel.Text = "Press START — game thinks you're on treadmill 24/7"
fakeStatusLabel.Parent = panel
Instance.new("UICorner", fakeStatusLabel).CornerRadius = UDim.new(0, 6)

liveLabel = Instance.new("TextLabel")
liveLabel.BackgroundTransparency = 1
liveLabel.Position = UDim2.fromOffset(12, 78)
liveLabel.Size = UDim2.new(1, -24, 0, 20)
liveLabel.Font = Enum.Font.Code
liveLabel.TextSize = 10
liveLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
liveLabel.TextXAlignment = Enum.TextXAlignment.Left
liveLabel.Text = "leaderstats.Speed = ?"
liveLabel.Parent = panel

statusLabel = Instance.new("TextLabel")
statusLabel.BackgroundTransparency = 1
statusLabel.Position = UDim2.fromOffset(12, 100)
statusLabel.Size = UDim2.new(1, -24, 0, 32)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 10
statusLabel.TextWrapped = true
statusLabel.TextColor3 = Color3.fromRGB(160, 210, 255)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Text = "Ghost-touch belt + spoof OnTreadmill + spam TreadmillSignal every frame."
statusLabel.Parent = panel

local function numBox(label, y, default)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromOffset(12, y)
	l.Size = UDim2.fromOffset(110, 18)
	l.Font = Enum.Font.Gotham
	l.TextSize = 10
	l.TextColor3 = Color3.fromRGB(180, 185, 200)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = label
	l.Parent = panel

	local b = Instance.new("TextBox")
	b.Position = UDim2.fromOffset(128, y - 2)
	b.Size = UDim2.fromOffset(300, 22)
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

targetBox = numBox("Speed send", 138, targetSpeed)
stepBox = numBox("Add / tick", 164, stepSpeed)
ticksBox = numBox("Loops/frame", 190, ticksPerFrame)

local scroll = Instance.new("ScrollingFrame")
scroll.Position = UDim2.fromOffset(12, 218)
scroll.Size = UDim2.new(1, -24, 1, -158)
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
	b.Position = UDim2.fromOffset(x, 418)
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

btn("Scan", 8, 52, runScan, Color3.fromRGB(60, 100, 160))
btn("START", 66, 72, function()
	task.spawn(startFakeTreadmill)
end, Color3.fromRGB(200, 90, 40))
btn("Stop", 144, 52, function()
	stopFake()
	log("Stopped fake treadmill.")
	if fakeStatusLabel then
		fakeStatusLabel.Text = "Stopped"
	end
end, Color3.fromRGB(180, 70, 70))
btn("Ghost", 200, 52, function()
	useGhostTouch = not useGhostTouch
	log("Ghost touch: " .. tostring(useGhostTouch))
end, Color3.fromRGB(90, 70, 140))
btn("Attrs", 256, 52, function()
	useSpoofAttrs = not useSpoofAttrs
	log("Spoof attrs: " .. tostring(useSpoofAttrs))
end, Color3.fromRGB(70, 110, 130))
btn("X", 312, 52, function()
	stopFake()
	screenGui:Destroy()
end, Color3.fromRGB(80, 85, 100))

player.CharacterAdded:Connect(function()
	task.wait(1.5)
	scanGame()
end)

task.spawn(function()
	while screenGui.Parent do
		local sp = getSpeed()
		if liveLabel and sp and not running then
			liveLabel.Text = "leaderstats.Speed = " .. tostring(sp)
		end
		task.wait(0.4)
	end
end)

runScan()
log("Fake treadmill = game thinks you're on belt while you walk anywhere.")
log("START runs every frame until Stop.")
