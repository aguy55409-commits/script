--[[
  SPEED EXPLOIT TEST — interacts with YOUR game's real speed stat + treadmill remote.

  This game uses treadmill speed (leaderstats/attributes), NOT WalkSpeed.
  Fires remotes, reads speed before/after, only logs when something actually changes.

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

-- Real gameplay remotes (not gamepass prompts, not server-only sync names we skip later)
local ACTION_REMOTES = {
	{ name = "SetCustomSpeed", path = "ReplicatedStorage.Remotes.SetCustomSpeed" },
	{ name = "TreadmillSignal", path = "ReplicatedStorage.Remotes.TreadmillSignal" },
}

local running = false
local startSpeed = 1000
local stepSpeed = 10000
local maxSpeed = 1e15
local interval = 0.5
local useTreadmill = true
local useSetCustom = true

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

-- Collect every number that might be "your speed" in this game
local function collectSpeedSnapshot()
	local snap = {}

	local function add(key, value)
		if type(value) == "number" then
			snap[key] = value
		end
	end

	local ls = player:FindFirstChild("leaderstats")
	if ls then
		for _, child in ipairs(ls:GetChildren()) do
			if child:IsA("NumberValue") or child:IsA("IntValue") then
				add("leaderstats." .. child.Name, child.Value)
			end
		end
	end

	for _, name in ipairs({ "Speed", "WalkSpeed", "CustomSpeed", "CurrentSpeed", "TreadmillSpeed", "MaxSpeed" }) do
		local v = player:GetAttribute(name)
		if v ~= nil then
			add("attr." .. name, tonumber(v) or v)
		end
	end

	for _, desc in ipairs(player:GetDescendants()) do
		if desc:IsA("NumberValue") or desc:IsA("IntValue") then
			local n = string.lower(desc.Name)
			if string.find(n, "speed", 1, true) or n == "wins" or n == "win" then
				add(desc:GetFullName(), desc.Value)
			end
		end
	end

	local char = player.Character
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			add("humanoid.WalkSpeed", hum.WalkSpeed)
		end
	end

	return snap
end

local function formatSnapshot(snap)
	local keys = {}
	for k in pairs(snap) do
		table.insert(keys, k)
	end
	table.sort(keys)
	local parts = {}
	for _, k in ipairs(keys) do
		table.insert(parts, string.format("%s=%s", k, tostring(snap[k])))
	end
	return table.concat(parts, " | ")
end

local function snapshotChanged(before, after)
	for k, v in pairs(after) do
		local prev = before[k]
		if prev == nil or prev ~= v then
			return true, k, prev, v
		end
	end
	for k, v in pairs(before) do
		if after[k] == nil then
			return true, k, v, nil
		end
	end
	return false
end

local function updateLiveSpeedLabel()
	if not liveSpeedLabel then
		return
	end
	local snap = collectSpeedSnapshot()
	liveSpeedLabel.Text = "Game state: " .. (formatSnapshot(snap) ~= "" and formatSnapshot(snap) or "(no speed stats found yet)")
end

local function discoverSpeedStats()
	discoveredSpeedKeys = {}
	local snap = collectSpeedSnapshot()
	log("=== DISCOVER (stand on treadmill if speed is 0) ===")
	if next(snap) == nil then
		log("No speed leaderstats/attributes found. Walk on your treadmill, then Discover again.")
	else
		for k, v in pairs(snap) do
			table.insert(discoveredSpeedKeys, k)
			log(string.format("  %s = %s", k, tostring(v)))
		end
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

-- Payload shapes common in treadmill / big-number games
local function buildPayloadTrials(speed)
	local s = speed
	local str = tostring(s)
	local bigStr = string.format("%.0e", s):gsub("+", "")
	return {
		{ label = "number", args = { s } },
		{ label = "string", args = { str } },
		{ label = "scientific string", args = { bigStr } },
		{ label = '"speed", number', args = { "speed", s } },
		{ label = '"Speed", string', args = { "Speed", str } },
		{ label = "number, true", args = { s, true } },
		{ label = "empty (treadmill tick)", args = {} },
		{ label = "true", args = { true } },
		{ label = "1", args = { 1 } },
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

	local before = collectSpeedSnapshot()
	local ok, err = pcall(function()
		fireRemote(remote, trial.args)
	end)
	if not ok then
		return false, err
	end

	task.wait(0.2)
	local after = collectSpeedSnapshot()
	local changed, key, oldV, newV = snapshotChanged(before, after)
	if changed then
		bestPayloadByRemote[remoteInfo.name] = trial
		return true, string.format("CHANGED %s: %s -> %s (%s)", key, tostring(oldV), tostring(newV), trial.label)
	end
	return false, "no change"
end

local function runProbeOnce()
	log("=== PROBE (finds working payload) ===")
	hookUpdateSpeedListener()

	for _, info in ipairs(ACTION_REMOTES) do
		if info.name == "TreadmillSignal" and not useTreadmill then
			continue
		end
		if info.name == "SetCustomSpeed" and not useSetCustom then
			continue
		end

		log("Probing " .. info.name .. "...")
		for _, trial in ipairs(buildPayloadTrials(startSpeed)) do
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
	log("Using remotes that actually move your speed stat (not gamepass, not WalkSpeed-only).")

	local speed = startSpeed
	local tickCount = 0

	while running do
		if not player.Parent then
			log("STOPPED — kicked or left.")
			break
		end

		tickCount += 1
		local before = collectSpeedSnapshot()
		log(string.format("--- tick %d | sending %s ---", tickCount, speed))

		local anyEffect = false

		for _, info in ipairs(ACTION_REMOTES) do
			if info.name == "TreadmillSignal" and not useTreadmill then
				continue
			end
			if info.name == "SetCustomSpeed" and not useSetCustom then
				continue
			end

			local trials = {}
			local saved = bestPayloadByRemote[info.name]
			if saved then
				table.insert(trials, saved)
			else
				-- default: number for SetCustomSpeed, empty/true for treadmill ticks
				if info.name == "TreadmillSignal" then
					table.insert(trials, { label = "treadmill tick", args = {} })
					table.insert(trials, { label = "true", args = { true } })
				else
					table.insert(trials, { label = "number", args = { speed } })
					table.insert(trials, { label = "string", args = { tostring(speed) } })
				end
			end

			for _, trial in ipairs(trials) do
				local args = trial.args
				if info.name == "SetCustomSpeed" and trial.label ~= "empty (treadmill tick)" and trial.label ~= "true" and trial.label ~= "1" then
					-- replace speed in first numeric/string slot
					if #args >= 1 and type(args[1]) == "number" then
						args = { speed, select(2, table.unpack(args)) }
					elseif #args >= 2 and type(args[2]) == "number" then
						args = { args[1], speed }
					elseif #args == 1 and type(args[1]) == "string" and args[1] ~= "speed" and args[1] ~= "Speed" then
						args = { tostring(speed) }
					elseif #args == 2 and (args[1] == "speed" or args[1] == "Speed") then
						args = { args[1], speed }
					end
				end

				local ok, msg = pcall(function()
					local remote = resolvePath(info.path)
					fireRemote(remote, args)
				end)
				if ok then
					task.wait(0.15)
					local after = collectSpeedSnapshot()
					local changed, key, oldV, newV = snapshotChanged(before, after)
					if changed then
						anyEffect = true
						log(string.format("  %s(%s) -> %s %s->%s", info.name, trial.label or "?", key, oldV, newV))
						before = after
					end
				else
					log(string.format("  FAIL %s: %s", info.name, tostring(msg)))
				end
			end
		end

		if not anyEffect then
			log("  NO EFFECT this tick — wrong args or server blocked. Try Probe, or stand on treadmill.")
		end

		statusLabel.Text = string.format("Tick %d | target %s | %s", tickCount, speed, anyEffect and "CHANGED" or "no change")
		updateLiveSpeedLabel()

		speed = math.min(speed + stepSpeed, maxSpeed)
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
title.Text = "Speed Exploit Test (real stats)"
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
statusLabel.Text = "Reads leaderstats/attributes — only logs when speed actually changes."
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
log("Targets: SetCustomSpeed + TreadmillSignal (treadmill gameplay).")
log("UpdateSpeed is listen-only (server pushes speed to you).")
log("1) Stand on treadmill  2) Discover  3) Probe  4) Start loop")
