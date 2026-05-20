--[[
  SERVER-SIDED EXPLOIT PROBE — client executor only (Potassium, etc.)

  Use this to test YOUR anti server-sided exploit protections in YOUR game.
  Does NOT use ServerScriptService. Runs 100% from client inject while in-game.

  Loadstring (Potassium):
    loadstring(game:HttpGet("https://raw.githubusercontent.com/aguy55409-commits/script/main/script.luau", true))()
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

if RunService:IsServer() then
	warn("[ExploitProbe] Client-only. Execute from Potassium while in-game, not on the server.")
	return
end

if _G.__ServerExploitProbeLoaded then
	return
end
_G.__ServerExploitProbeLoaded = true

local player = Players.LocalPlayer
if not player then
	warn("[ExploitProbe] Join the game first, then execute from Potassium.")
	return
end

local GUI_NAME = "ServerExploitProbe"
local PROBE_TAG = "__AC_PROBE__"

local function log(lines, text, color)
	color = color or Color3.fromRGB(200, 205, 220)
	table.insert(lines, { text = text, color = color })
	print("[ExploitProbe]", text)
end

local function tryCall(label, fn, lines)
	local ok, result = pcall(fn)
	if ok then
		log(lines, label .. " → SENT/OK: " .. tostring(result), Color3.fromRGB(80, 220, 120))
	else
		log(lines, label .. " → BLOCKED: " .. tostring(result), Color3.fromRGB(255, 100, 100))
	end
	return ok, result
end

local function collectRemotes()
	local list = {}
	for _, inst in ipairs(game:GetDescendants()) do
		if inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") then
			table.insert(list, inst)
		end
	end
	return list
end

-- === exploit-style probes (what anti-cheat should catch) ===

local function probeClientRemote(lines)
	tryCall("Create client RemoteEvent + FireServer", function()
		local folder = Instance.new("Folder")
		folder.Name = "ExploitProbe_ClientRemotes"
		folder.Parent = ReplicatedStorage

		local ev = Instance.new("RemoteEvent")
		ev.Name = "ProbeEvent"
		ev.Parent = folder

		ev:FireServer(PROBE_TAG, "client_created_remote", os.clock())
		task.wait(0.15)
		folder:Destroy()
		return "fired"
	end, lines)
end

local function probeAllRemotes(lines)
	local remotes = collectRemotes()
	log(lines, "Found " .. #remotes .. " remotes in game.", Color3.fromRGB(140, 180, 255))

	local fired, blocked = 0, 0
	for i, remote in ipairs(remotes) do
		if i > 25 then
			log(lines, "Stopped at 25 remotes (safety cap).", Color3.fromRGB(255, 200, 80))
			break
		end

		local path = remote:GetFullName()
		local ok = pcall(function()
			if remote:IsA("RemoteEvent") then
				remote:FireServer(PROBE_TAG, "probe", i, { exploit = true })
			else
				remote:InvokeServer(PROBE_TAG, "probe", i)
			end
		end)

		if ok then
			fired += 1
			log(lines, "FireServer OK: " .. path, Color3.fromRGB(255, 180, 80))
		else
			blocked += 1
			log(lines, "Blocked: " .. path, Color3.fromRGB(80, 220, 120))
		end
	end

	log(lines, string.format("Remote scan: %d sent, %d blocked.", fired, blocked), Color3.fromRGB(255, 255, 255))
end

local function probeRemoteSpam(lines)
	local remotes = collectRemotes()
	local target = remotes[1]
	if not target then
		log(lines, "Remote spam: no remotes found.", Color3.fromRGB(255, 100, 100))
		return
	end

	tryCall("Remote spam x30 on " .. target.Name, function()
		for _ = 1, 30 do
			if target:IsA("RemoteEvent") then
				target:FireServer(PROBE_TAG, "spam")
			else
				pcall(function()
					target:InvokeServer(PROBE_TAG, "spam")
				end)
			end
		end
		return target:GetFullName()
	end, lines)
end

local function probeInvalidArgs(lines)
	local remotes = collectRemotes()
	local target = remotes[1]
	if not target then
		log(lines, "Invalid args: no remotes found.", Color3.fromRGB(255, 100, 100))
		return
	end

	tryCall("Invalid/large args on " .. target.Name, function()
		local junk = {}
		for i = 1, 200 do
			junk[i] = string.rep("x", 50)
		end
		if target:IsA("RemoteEvent") then
			target:FireServer(nil, junk, math.huge, { __index = game })
		else
			target:InvokeServer(nil, junk)
		end
		return "sent junk payload"
	end, lines)
end

local function probeSSSInject(lines)
	tryCall("Inject Script into ServerScriptService", function()
		local s = Instance.new("Script")
		s.Name = "ExploitProbe_Injected"
		s.Source = 'print("[ExploitProbe] If you see this, SSS inject was NOT blocked")'
		s.Parent = ServerScriptService
		task.wait(0.1)
		local stillThere = ServerScriptService:FindFirstChild("ExploitProbe_Injected")
		if stillThere then
			stillThere:Destroy()
			return "script parented to SSS (BAD - not blocked)"
		end
		return "script removed or never replicated"
	end, lines)
end

local function probeServerStorage(lines)
	tryCall("Parent part to ServerStorage", function()
		local p = Instance.new("Part")
		p.Name = "ExploitProbe_Part"
		p.Parent = ServerStorage
		task.wait(0.1)
		local found = ServerStorage:FindFirstChild("ExploitProbe_Part")
		if found then
			found:Destroy()
			return "part in ServerStorage (BAD - not blocked)"
		end
		return "part not on server"
	end, lines)
end

local function probeCustomRemote(path, lines)
	if path == "" then
		log(lines, "Enter a remote path e.g. ReplicatedStorage.Remotes.Shop", Color3.fromRGB(255, 200, 80))
		return
	end

	tryCall("Custom FireServer: " .. path, function()
		local obj = game
		for part in string.gmatch(path, "[^%.]+") do
			obj = obj:WaitForChild(part, 2)
		end
		if not obj:IsA("RemoteEvent") and not obj:IsA("RemoteFunction") then
			error("not a remote")
		end
		if obj:IsA("RemoteEvent") then
			obj:FireServer(PROBE_TAG, "custom")
		else
			obj:InvokeServer(PROBE_TAG, "custom")
		end
		return obj.ClassName
	end, lines)
end

local function refreshLog(scrollFrame, lines)
	for _, child in ipairs(scrollFrame:GetChildren()) do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end

	local y = 0
	for _, entry in ipairs(lines) do
		local row = Instance.new("TextLabel")
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, -8, 0, 22)
		row.Position = UDim2.fromOffset(4, y)
		row.Font = Enum.Font.Code
		row.TextSize = 13
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = entry.color
		row.Text = entry.text
		row.TextWrapped = true
		row.AutomaticSize = Enum.AutomaticSize.Y
		row.Parent = scrollFrame
		y += row.AbsoluteSize.Y + 2
	end

	scrollFrame.CanvasSize = UDim2.fromOffset(0, y + 8)
end

local function runProbeList(statusLabel, scrollFrame, probes, pathInput)
	local lines = {}
	log(lines, "=== Probe run ===", Color3.fromRGB(255, 255, 255))

	for _, probe in ipairs(probes) do
		probe(lines)
	end

	if pathInput and pathInput.Text ~= "" then
		probeCustomRemote(pathInput.Text, lines)
	end

	refreshLog(scrollFrame, lines)
	statusLabel.Text = "Done. Green = blocked (good). Orange = call went through — check AC logs."
end

local function runAllProbes(statusLabel, scrollFrame, pathInput)
	runProbeList(statusLabel, scrollFrame, {
		probeClientRemote,
		probeSSSInject,
		probeServerStorage,
		probeInvalidArgs,
		probeRemoteSpam,
		probeAllRemotes,
	}, pathInput)
end

-- === GUI ===

local playerGui = player:WaitForChild("PlayerGui")
local old = playerGui:FindFirstChild(GUI_NAME)
if old then
	old:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = GUI_NAME
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(420, 400)
panel.BackgroundColor3 = Color3.fromRGB(28, 30, 38)
panel.Parent = screenGui

Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 36)
title.Position = UDim2.fromOffset(10, 8)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Server Exploit Probe (Potassium)"
title.Parent = panel

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -20, 0, 40)
status.Position = UDim2.fromOffset(10, 44)
status.BackgroundTransparency = 1
status.Font = Enum.Font.Gotham
status.TextSize = 13
status.TextWrapped = true
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextColor3 = Color3.fromRGB(180, 185, 200)
status.Text = "Tests server interaction from client inject. No ServerScriptService."
status.Parent = panel

local pathInput = Instance.new("TextBox")
pathInput.Size = UDim2.new(1, -20, 0, 32)
pathInput.Position = UDim2.fromOffset(10, 88)
pathInput.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
pathInput.TextColor3 = Color3.fromRGB(255, 255, 255)
pathInput.PlaceholderText = "Optional: ReplicatedStorage.YourRemote"
pathInput.PlaceholderColor3 = Color3.fromRGB(120, 125, 140)
pathInput.Font = Enum.Font.Code
pathInput.TextSize = 13
pathInput.Text = ""
pathInput.Parent = panel
Instance.new("UICorner", pathInput).CornerRadius = UDim.new(0, 6)

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -20, 1, -200)
scroll.Position = UDim2.fromOffset(10, 128)
scroll.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 6
scroll.CanvasSize = UDim2.new()
scroll.Parent = panel
Instance.new("UICorner", scroll).CornerRadius = UDim.new(0, 6)

local function makeButton(text, x, y, w, callback)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(w, 32)
	b.Position = UDim2.fromOffset(x, y)
	b.BackgroundColor3 = Color3.fromRGB(50, 90, 200)
	b.TextColor3 = Color3.fromRGB(255, 255, 255)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.Text = text
	b.Parent = panel
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
	b.Activated:Connect(callback)
	return b
end

local yBtn = 360
makeButton("Run All", 10, yBtn, 95, function()
	runAllProbes(status, scroll, pathInput)
end)
makeButton("Fire Remotes", 112, yBtn, 95, function()
	runProbeList(status, scroll, { probeAllRemotes }, pathInput)
end)
makeButton("SSS Inject", 214, yBtn, 95, function()
	runProbeList(status, scroll, { probeSSSInject }, pathInput)
end)
makeButton("Close", 316, yBtn, 94, function()
	screenGui:Destroy()
	_G.__ServerExploitProbeLoaded = nil
end)

print("[ExploitProbe] Ready — GUI open. Use buttons to test your anti server exploit protections.")
