--[[
  SPEED EXPLOIT TEST — for YOUR game (Potassium, in-game)

  Uses remotes from your security audit. Tries to push speed higher constantly
  so you can see if server-side validation / anti-cheat blocks it.

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

-- ONLY real speed handlers — NOT gamepass Prompt* remotes (those open purchase UI)
local SPEED_REMOTES = {
	{ path = "ReplicatedStorage.Remotes.SetCustomSpeed", name = "SetCustomSpeed" },
	{ path = "ReplicatedStorage.Remotes.UpdateSpeed", name = "UpdateSpeed" },
}

-- Names we never touch (monetization / UI / admin)
local SKIP_NAME_PATTERNS = {
	"prompt",
	"gamepass",
	"purchase",
	"product",
	"devproduct",
	"robux",
	"shop",
	"buy",
}

local running = false
local startSpeed = 100
local stepSpeed = 500
local maxSpeed = 50000000
local interval = 0.35
local tryClientWalkSpeed = true

local logLines = {}
local statusLabel
local logLabel
local startBox
local stepBox
local intervalBox

local function log(text)
	table.insert(logLines, text)
	print("[SpeedTest] " .. text)
	if logLabel then
		logLabel.Text = table.concat(logLines, "\n")
	end
end

local function resolvePath(path)
	local obj = game
	for part in string.gmatch(path, "[^%.]+") do
		obj = obj:WaitForChild(part, 3)
	end
	return obj
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

local function fireSpeedRemote(remoteInfo, speed)
	local remote = resolvePath(remoteInfo.path)
	if remote:IsA("RemoteEvent") then
		remote:FireServer(speed)
		return true
	elseif remote:IsA("RemoteFunction") then
		remote:InvokeServer(speed)
		return true
	end
	return false
end

local function applyClientWalkSpeed(speed)
	local char = player.Character
	if not char then
		return false
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = speed
		return true
	end
	return false
end

local function runSpeedLoop()
	if running then
		return
	end
	running = true

	startSpeed = tonumber(startBox.Text) or startSpeed
	stepSpeed = tonumber(stepBox.Text) or stepSpeed
	interval = tonumber(intervalBox.Text) or interval

	log("=== SPEED TEST START ===")
	log(string.format("Start: %s | Step: %s | Max: %s | Interval: %ss", startSpeed, stepSpeed, maxSpeed, interval))

	local speed = startSpeed
	local tickCount = 0

	while running do
		if not player.Parent then
			log("STOPPED — kicked or left game.")
			break
		end

		tickCount += 1
		log(string.format("--- tick %d | target speed: %s ---", tickCount, speed))

		-- 1) Real speed remotes only (not gamepass prompts)
		for _, info in ipairs(SPEED_REMOTES) do
			local ok, err = pcall(function()
				fireSpeedRemote(info, speed)
			end)
			if ok then
				log(string.format("  Fired %s(%s)", info.name, speed))
			else
				log(string.format("  FAIL %s — %s", info.name, tostring(err)))
			end
		end

		-- 2) Client WalkSpeed (tests if only client stat changes — server should override if protected)
		if tryClientWalkSpeed then
			local ok = applyClientWalkSpeed(speed)
			log(ok and ("  Client WalkSpeed set to " .. speed) or "  Client WalkSpeed failed (no humanoid)")
		end

		statusLabel.Text = string.format("Running — speed %s (tick %d). Stop to end.", speed, tickCount)

		speed = math.min(speed + stepSpeed, maxSpeed)
		task.wait(interval)
	end

	running = false
	statusLabel.Text = "Stopped."
	log("=== SPEED TEST END ===")
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
panel.Size = UDim2.fromOffset(400, 420)
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
title.Text = "Speed Exploit Test"
title.Parent = panel

statusLabel = Instance.new("TextLabel")
statusLabel.BackgroundTransparency = 1
statusLabel.Position = UDim2.fromOffset(12, 32)
statusLabel.Size = UDim2.new(1, -24, 0, 36)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 12
statusLabel.TextWrapped = true
statusLabel.TextColor3 = Color3.fromRGB(160, 210, 255)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Text = "Only SetCustomSpeed + UpdateSpeed (no gamepass Prompt remotes)."
statusLabel.Parent = panel

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
	b.Size = UDim2.fromOffset(248, 24)
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

startBox = numBox("Start speed", 72, startSpeed)
stepBox = numBox("Add per tick", 100, stepSpeed)
intervalBox = numBox("Seconds", 128, interval)

local scroll = Instance.new("ScrollingFrame")
scroll.Position = UDim2.fromOffset(12, 160)
scroll.Size = UDim2.new(1, -24, 1, -110)
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
	b.Position = UDim2.fromOffset(x, 378)
	b.Size = UDim2.fromOffset(w, 32)
	b.BackgroundColor3 = col or Color3.fromRGB(45, 120, 70)
	b.TextColor3 = Color3.fromRGB(255, 255, 255)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
	b.Text = text
	b.Parent = panel
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
	b.MouseButton1Click:Connect(fn)
end

btn("Start", 12, 90, function()
	task.spawn(runSpeedLoop)
end)

btn("Stop", 108, 90, function()
	running = false
	log("Stop requested.")
end, Color3.fromRGB(180, 70, 70))

btn("Close", 204, 90, function()
	running = false
	screenGui:Destroy()
end, Color3.fromRGB(80, 85, 100))

log("Loaded. ONLY tests:")
log("  • ReplicatedStorage.Remotes.SetCustomSpeed")
log("  • ReplicatedStorage.Remotes.UpdateSpeed")
log("Skipped: Prompt*Speed (gamepass purchase prompts).")
