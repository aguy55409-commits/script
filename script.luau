--[[
  SERVER-SIDED EXPLOIT PROBE — Potassium / client executor only

  Loadstring:
    loadstring(game:HttpGet("https://raw.githubusercontent.com/aguy55409-commits/script/main/script.luau", true))()
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

if RunService:IsServer() then
	warn("[ExploitProbe] Client-only. Execute from Potassium in-game.")
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
local REMOTE_SCAN_CAP = 60

local Report = {
	lines = {},
	vulnerableRemotes = {},
	linkedScripts = {},
}

local function reportLine(text)
	table.insert(Report.lines, text)
	print("[ExploitProbe]", text)
end

local function linesToText()
	return table.concat(Report.lines, "\n")
end

local function tryCall(label, fn)
	local ok, result = pcall(fn)
	if ok then
		reportLine(label .. " → SENT/OK: " .. tostring(result))
	else
		reportLine(label .. " → BLOCKED: " .. tostring(result))
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
	table.sort(list, function(a, b)
		return a:GetFullName() < b:GetFullName()
	end)
	return list
end

local function getReadableSource(inst)
	if not inst:IsA("LuaSourceContainer") then
		return nil
	end
	local ok, src = pcall(function()
		return inst.Source
	end)
	if ok and type(src) == "string" and #src > 0 then
		return src
	end
	return nil
end

local function addLinkedScript(path, reason, remotePath)
	if Report.linkedScripts[path] then
		return
	end
	Report.linkedScripts[path] = {
		path = path,
		reason = reason,
		remote = remotePath,
	}
end

local function findScriptsForRemote(remote)
	local name = remote.Name
	local remotePath = remote:GetFullName()
	local patterns = {
		name,
		string.format('"%s"', name),
		string.format("'%s'", name),
		'WaitForChild("' .. name .. '")',
		"WaitForChild('" .. name .. "')",
	}

	local parent = remote.Parent
	if parent then
		for _, child in ipairs(parent:GetChildren()) do
			if child:IsA("LuaSourceContainer") then
				addLinkedScript(child:GetFullName(), "same folder as remote", remotePath)
			end
		end
	end

	-- Client-readable scripts that mention this remote by name
	for _, inst in ipairs(game:GetDescendants()) do
		if inst:IsA("LuaSourceContainer") then
			local src = getReadableSource(inst)
			if src then
				for _, pattern in ipairs(patterns) do
					if string.find(src, pattern, 1, true) or string.find(src, pattern) then
						addLinkedScript(inst:GetFullName(), "source mentions remote name", remotePath)
						break
					end
				end
			end
		end
	end
end

local function addVulnerableRemote(remote, detail)
	local path = remote:GetFullName()
	if Report.vulnerableRemotes[path] then
		return
	end
	Report.vulnerableRemotes[path] = {
		path = path,
		className = remote.ClassName,
		detail = detail,
	}
	findScriptsForRemote(remote)
end

local function appendVulnerabilitySection()
	reportLine("")
	reportLine("========== VULNERABLE REMOTES (PATCH SERVER HANDLERS) ==========")

	local count = 0
	for path, info in pairs(Report.vulnerableRemotes) do
		count += 1
		reportLine(string.format("[%d] %s (%s)", count, path, info.className))
		reportLine("     Why: " .. info.detail)
		reportLine("     Studio: search for '" .. path:match("%.([^%.]+)$") .. "' in ServerScriptService / ServerStorage")
	end

	if count == 0 then
		reportLine("None flagged — remotes blocked or AC kicked before log updated.")
	end

	reportLine("")
	reportLine("========== LINKED SCRIPTS (CLIENT-READABLE — CHECK IN STUDIO) ==========")

	local scriptCount = 0
	for path, info in pairs(Report.linkedScripts) do
		scriptCount += 1
		reportLine(string.format("[%d] %s", scriptCount, path))
		reportLine("     Reason: " .. info.reason)
		reportLine("     Remote: " .. info.remote)
	end

	if scriptCount == 0 then
		reportLine("No client-readable scripts found. In Studio, Ctrl+Shift+F search the remote names above.")
	end

	reportLine("")
	reportLine("========== PATCH CHECKLIST ==========")
	reportLine("• Server: validate player, rate-limit, whitelist args on every OnServerEvent/InvokeServer")
	reportLine("• Never trust client-created instances in ReplicatedStorage")
	reportLine("• Block/kick on PROBE_TAG or unknown payloads if you saw SENT/OK above")
	reportLine("• ServerScriptService / ServerStorage should reject client parenting")
	reportLine("• Re-run probe after patching; vulnerable list should shrink")
end

-- === probes ===

local function probeClientRemote()
	tryCall("Create client RemoteEvent + FireServer", function()
		local folder = Instance.new("Folder")
		folder.Name = "ExploitProbe_ClientRemotes"
		folder.Parent = ReplicatedStorage
		local ev = Instance.new("RemoteEvent")
		ev.Name = "ProbeEvent"
		ev.Parent = folder
		ev:FireServer(PROBE_TAG, "client_created_remote")
		task.wait(0.12)
		folder:Destroy()
		return "client remote fired (server should ignore client-created remotes)"
	end)
end

local function probeSSSInject()
	local ok, result = tryCall("Inject Script into ServerScriptService", function()
		local s = Instance.new("Script")
		s.Name = "ExploitProbe_Injected"
		s.Source = 'warn("SSS inject not blocked")'
		s.Parent = ServerScriptService
		task.wait(0.12)
		local stillThere = ServerScriptService:FindFirstChild("ExploitProbe_Injected")
		if stillThere then
			stillThere:Destroy()
			return "script stayed in SSS"
		end
		return "script not on server"
	end)
	if ok and string.find(tostring(result), "stayed", 1, true) then
		reportLine("VULNERABLE: Client can parent Scripts into ServerScriptService")
		addLinkedScript("ServerScriptService", "SSS inject succeeded — audit all ServerScriptService children", "N/A")
	end
end

local function probeServerStorage()
	local ok, result = tryCall("Parent part to ServerStorage", function()
		local p = Instance.new("Part")
		p.Name = "ExploitProbe_Part"
		p.Parent = ServerStorage
		task.wait(0.12)
		local found = ServerStorage:FindFirstChild("ExploitProbe_Part")
		if found then
			found:Destroy()
			return "part stayed in ServerStorage"
		end
		return "part not on server"
	end)
	if ok and string.find(tostring(result), "stayed", 1, true) then
		reportLine("VULNERABLE: Client can write to ServerStorage")
	end
end

local function probeInvalidArgs()
	local remotes = collectRemotes()
	local target = remotes[1]
	if not target then
		reportLine("Invalid args: no remotes in game.")
		return
	end

	local ok = tryCall("Invalid/large args on " .. target:GetFullName(), function()
		local junk = {}
		for i = 1, 200 do
			junk[i] = string.rep("x", 50)
		end
		if target:IsA("RemoteEvent") then
			target:FireServer(nil, junk, math.huge)
		else
			target:InvokeServer(nil, junk)
		end
		return "junk sent"
	end)
	if ok then
		addVulnerableRemote(target, "accepted invalid/large payload without error")
	end
end

local function probeRemoteSpam()
	local remotes = collectRemotes()
	local target = remotes[1]
	if not target then
		reportLine("Remote spam: no remotes found.")
		return
	end

	local ok = tryCall("Remote spam x30 on " .. target:GetFullName(), function()
		for _ = 1, 30 do
			if target:IsA("RemoteEvent") then
				target:FireServer(PROBE_TAG, "spam")
			else
				pcall(function()
					target:InvokeServer(PROBE_TAG, "spam")
				end)
			end
		end
		return "spam completed"
	end)
	if ok then
		addVulnerableRemote(target, "accepted spam burst (30 fires) — add rate limits")
	end
end

local function probeAllRemotes()
	local remotes = collectRemotes()
	reportLine("Scanning " .. #remotes .. " remotes (cap " .. REMOTE_SCAN_CAP .. ")...")

	local fired, blocked = 0, 0
	for i, remote in ipairs(remotes) do
		if i > REMOTE_SCAN_CAP then
			reportLine("Stopped at cap (" .. REMOTE_SCAN_CAP .. "). Run again or raise REMOTE_SCAN_CAP in script.")
			break
		end

		local path = remote:GetFullName()
		local ok, err = pcall(function()
			if remote:IsA("RemoteEvent") then
				remote:FireServer(PROBE_TAG, "probe", i, { exploit = true })
			else
				remote:InvokeServer(PROBE_TAG, "probe", i)
			end
		end)

		if ok then
			fired += 1
			reportLine("VULNERABLE REMOTE: " .. path .. " (" .. remote.ClassName .. ") — FireServer/InvokeServer OK")
			addVulnerableRemote(remote, "exploit probe payload accepted (no client-side error)")
		else
			blocked += 1
			reportLine("Blocked remote: " .. path .. " — " .. tostring(err))
		end
	end

	reportLine(string.format("Remote scan done: %d reachable, %d blocked/error.", fired, blocked))
end

local function probeCustomRemote(path)
	if path == "" then
		reportLine("Custom remote: enter path in the box (e.g. ReplicatedStorage.Remotes.Shop)")
		return
	end

	local ok, result = tryCall("Custom: " .. path, function()
		local obj = game
		for part in string.gmatch(path, "[^%.]+") do
			obj = obj:WaitForChild(part, 3)
		end
		if not obj:IsA("RemoteEvent") and not obj:IsA("RemoteFunction") then
			error("not a RemoteEvent/RemoteFunction")
		end
		if obj:IsA("RemoteEvent") then
			obj:FireServer(PROBE_TAG, "custom")
		else
			obj:InvokeServer(PROBE_TAG, "custom")
		end
		return obj.ClassName
	end)

	if ok then
		local obj = game
		for part in string.gmatch(path, "[^%.]+") do
			obj = obj:FindFirstChild(part)
			if not obj then
				break
			end
		end
		if obj and (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")) then
			addVulnerableRemote(obj, "custom probe path accepted")
		end
	end
end

local function resetReport()
	Report.lines = {}
	Report.vulnerableRemotes = {}
	Report.linkedScripts = {}
end

local function runProbes(probes, pathInput, reportBox, statusLabel)
	resetReport()
	reportLine("=== EXPLOIT PROBE REPORT ===")
	reportLine("Player: " .. player.Name)
	reportLine("PlaceId: " .. tostring(game.PlaceId))
	reportLine("Time: " .. os.date("%Y-%m-%d %H:%M:%S"))
	reportLine("")

	for _, probe in ipairs(probes) do
		probe()
	end

	if pathInput and pathInput.Text ~= "" then
		probeCustomRemote(pathInput.Text)
	end

	appendVulnerabilitySection()
	reportBox.Text = linesToText()
	statusLabel.Text = "Done — select report or press Copy Report."
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
panel.Size = UDim2.fromOffset(500, 480)
panel.BackgroundColor3 = Color3.fromRGB(28, 30, 38)
panel.Parent = screenGui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 28)
title.Position = UDim2.fromOffset(10, 8)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 17
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Server Exploit Probe"
title.Parent = panel

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -20, 0, 32)
status.Position = UDim2.fromOffset(10, 36)
status.BackgroundTransparency = 1
status.Font = Enum.Font.Gotham
status.TextSize = 12
status.TextWrapped = true
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextColor3 = Color3.fromRGB(170, 175, 190)
status.Text = "Copyable report + vulnerable remote/script list for patching."
status.Parent = panel

local pathInput = Instance.new("TextBox")
pathInput.Size = UDim2.new(1, -20, 0, 28)
pathInput.Position = UDim2.fromOffset(10, 72)
pathInput.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
pathInput.TextColor3 = Color3.fromRGB(255, 255, 255)
pathInput.PlaceholderText = "Optional: ReplicatedStorage.Folder.RemoteName"
pathInput.PlaceholderColor3 = Color3.fromRGB(110, 115, 130)
pathInput.Font = Enum.Font.Code
pathInput.TextSize = 12
pathInput.Text = ""
pathInput.Parent = panel
Instance.new("UICorner", pathInput).CornerRadius = UDim.new(0, 6)

local reportBox = Instance.new("TextBox")
reportBox.Name = "ReportBox"
reportBox.Size = UDim2.new(1, -20, 1, -150)
reportBox.Position = UDim2.fromOffset(10, 108)
reportBox.BackgroundColor3 = Color3.fromRGB(14, 16, 22)
reportBox.TextColor3 = Color3.fromRGB(210, 220, 235)
reportBox.PlaceholderText = "Press Run All — full report appears here (Ctrl+A, Ctrl+C)"
reportBox.PlaceholderColor3 = Color3.fromRGB(90, 95, 110)
reportBox.Font = Enum.Font.Code
reportBox.TextSize = 11
reportBox.TextXAlignment = Enum.TextXAlignment.Left
reportBox.TextYAlignment = Enum.TextYAlignment.Top
reportBox.TextWrapped = true
reportBox.MultiLine = true
reportBox.ClearTextOnFocus = false
reportBox.TextEditable = true
reportBox.Text = ""
reportBox.Parent = panel
Instance.new("UICorner", reportBox).CornerRadius = UDim.new(0, 6)

local reportPadding = Instance.new("UIPadding")
reportPadding.PaddingTop = UDim.new(0, 8)
reportPadding.PaddingBottom = UDim.new(0, 8)
reportPadding.PaddingLeft = UDim.new(0, 8)
reportPadding.PaddingRight = UDim.new(0, 8)
reportPadding.Parent = reportBox

local function makeButton(text, x, w, callback, color)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(w, 30)
	b.Position = UDim2.fromOffset(x, 438)
	b.BackgroundColor3 = color or Color3.fromRGB(50, 90, 200)
	b.TextColor3 = Color3.fromRGB(255, 255, 255)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
	b.Text = text
	b.Parent = panel
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
	b.Activated:Connect(callback)
end

local allProbes = {
	probeClientRemote,
	probeSSSInject,
	probeServerStorage,
	probeInvalidArgs,
	probeRemoteSpam,
	probeAllRemotes,
}

makeButton("Run All", 10, 88, function()
	runProbes(allProbes, pathInput, reportBox, status)
end)

makeButton("Scan Remotes", 104, 88, function()
	runProbes({ probeAllRemotes }, pathInput, reportBox, status)
end)

makeButton("Copy Report", 198, 100, function()
	local text = reportBox.Text
	if text == "" then
		status.Text = "Run a scan first."
		return
	end

	local copied = false
	if setclipboard then
		local ok = pcall(function()
			setclipboard(text)
		end)
		copied = ok
	end

	if copied then
		status.Text = "Copied to clipboard (Potassium/setclipboard)."
	else
		reportBox:CaptureFocus()
		reportBox.SelectionStart = 1
		reportBox.CursorPosition = #text + 1
		status.Text = "Select all (Ctrl+A) and copy (Ctrl+C)."
	end
end)

makeButton("Export", 304, 72, function()
	if reportBox.Text == "" then
		status.Text = "Nothing to export."
		return
	end
	reportLine("---")
	reportLine("END OF REPORT")
	reportBox.Text = linesToText()
	if setclipboard then
		pcall(function()
			setclipboard(reportBox.Text)
		end)
		status.Text = "Full report refreshed and copied if setclipboard works."
	else
		status.Text = "Report refreshed in box — Ctrl+A, Ctrl+C."
	end
end)

makeButton("Close", 382, 108, function()
	screenGui:Destroy()
	_G.__ServerExploitProbeLoaded = nil
end, Color3.fromRGB(70, 74, 88))

print("[ExploitProbe] Ready — Run All, then Copy Report.")
