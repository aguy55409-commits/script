--[[
  REMOTE MANIPULATION PROBE — Potassium, in-game only.

  Kicked when the scan FINISHES? That's your anti-cheat punishing the whole batch
  (delayed kick) — NOT one bad remote. Report is auto-copied before that happens.

  loadstring(game:HttpGet("https://raw.githubusercontent.com/aguy55409-commits/script/main/script.luau", true))()
]]

local USE_STEALTH_PAYLOAD = true

-- Paste exact paths here after you see them in the log (e.g. the #32 remote):
local SKIP_EXACT_PATHS = {
	-- "ReplicatedStorage.SomeFolder.TheRemoteThatKicksYou",
}

local function main()
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local CoreGui = game:GetService("CoreGui")

	if RunService:IsServer() and not Players.LocalPlayer then
		error("Execute from Potassium while in-game (client).")
	end

	local player = Players.LocalPlayer
	if not player then
		error("Join the game first, then execute.")
	end

	local GUI_NAME = "ServerExploitProbe"

	_G.__ServerExploitProbeLoaded = nil
	for _, root in ipairs({ CoreGui, player:FindFirstChild("PlayerGui") }) do
		if root then
			local old = root:FindFirstChild(GUI_NAME)
			if old then
				old:Destroy()
			end
		end
	end

	local SPEED_PRESETS = {
		slow = {
			label = "Slow",
			delay = 2.0,
			timeout = 1.5,
			skipRemoteFunctions = false,
			autoCopyEvery = 5,
			flushEvery = 5,
			securityLevel = "full",
		},
		medium = {
			label = "Medium",
			delay = 0.65,
			timeout = 1.0,
			skipRemoteFunctions = true,
			autoCopyEvery = 8,
			flushEvery = 10,
			securityLevel = "normal",
		},
		fast = {
			label = "Fast",
			delay = 0,
			timeout = 0.35,
			skipRemoteFunctions = false,
			autoCopyEvery = 12,
			flushEvery = 25,
			securityLevel = "quick",
		},
	}

	local PATCH_ADVICE = {
		reachable = "Handler must treat every client call as hostile — validate at entry.",
		malformed = "Add arg type/shape checks at the TOP of OnServerEvent (before deep logic).",
		trusted_client = "Never trust client userid/currency/items — use server-authoritative state only.",
		no_rate_limit = "Add per-player rate limits / cooldowns on this remote.",
		replay = "Add nonce or timestamp replay protection (reject duplicate payloads).",
		numeric = "Sanity-check all numbers (range, NaN, negatives where invalid).",
		impossible = "Reject impossible state transitions server-side (preconditions first).",
		fire_only = "Don't only check that the remote fired — validate args and game state.",
	}

	local SCRIPT_PATCH_ADVICE = {
		readable_source = "Source is copyable — move secrets/logic to ServerScriptService; keep client minimal.",
		localscript_exposed = "LocalScript runs on client — never trust it for economy/combat/admin.",
		module_in_rs = "ModuleScript in ReplicatedStorage can be required/hooked — no secret logic there.",
		fireserver_in_client = "Client calls FireServer — server must validate everything sent.",
		client_currency = "Currency/cash logic on client — must be server-authoritative only.",
		client_admin = "Admin/rank checks on client — easy to bypass; verify on server.",
		client_stats = "WalkSpeed/JumpPower/Humanoid tweaks on client — server should enforce stats.",
		hook_patterns = "Uses hook/debug patterns — assume exploiters can modify this script.",
	}

	local SCRIPT_SOURCE_PATTERNS = {
		{ id = "fireserver_in_client", pat = "FireServer" },
		{ id = "client_stats", pat = "WalkSpeed" },
		{ id = "client_stats", pat = "JumpPower" },
		{ id = "hook_patterns", pat = "getrawmetatable" },
		{ id = "hook_patterns", pat = "hookfunction" },
		{ id = "hook_patterns", pat = "getfenv" },
	}

	-- Remotes matching these are NOT probed (likely to kick / ban / flag you)
	local SKIP_NAME_KEYWORDS = {
		"kick",
		"ban",
		"boot",
		"eject",
		"punish",
		"moderation",
		"modkick",
		"anticheat",
		"antiexploit",
		"anti_cheat",
		"acban",
		"acdetect",
		"ac_kick",
		"security",
		"exploitdetect",
		"cheatdetect",
		"detection",
		"detected",
		"flagplayer",
		"reportplayer",
		"playerreport",
		"votekick",
		"removeplayer",
		"tempban",
		"permban",
		"permaban",
		"strike",
		"disconnect",
		"ping",
		"heartbeat",
		"validate",
		"verify",
		"integrity",
		"sanity",
		"moderate",
		"262",
		"267",
	}

	local SKIP_PATH_KEYWORDS = {
		"anticheat",
		"antiexploit",
		"anti.cheat",
		"moderation",
		"admin",
		"security",
		"punish",
		"kick",
		"ban",
		"detection",
		"acservice",
		"exploit",
	}

	_G.__ExploitProbe_SkipRemotes = _G.__ExploitProbe_SkipRemotes or {}
	_G.__ExploitProbe_KickCulprits = _G.__ExploitProbe_KickCulprits or {}

	local function placeKey()
		return tostring(game.PlaceId)
	end

	local function rememberKickCulprit(path)
		if not path then
			return
		end
		_G.__ExploitProbe_SkipRemotes[path] = true
		local culprits = _G.__ExploitProbe_KickCulprits[placeKey()] or {}
		culprits[path] = true
		_G.__ExploitProbe_KickCulprits[placeKey()] = culprits
	end

	local function isRememberedCulprit(path)
		local culprits = _G.__ExploitProbe_KickCulprits[placeKey()]
		return culprits and culprits[path]
	end

	local Report = {
		lines = {},
		allRemotes = {},
		manipulable = {},
		vulnFindings = {},
		clientScripts = {},
	}
	local screenGui, statusLabel, reportLabel, scrollFrame, pathInput
	local lineCount = 0
	local scanRunning = false
	local activeConfig = SPEED_PRESETS.medium
	local lastProbedPath = nil

	local function matchesKeyword(text, keywords)
		text = string.lower(text)
		for _, kw in ipairs(keywords) do
			if string.find(text, kw, 1, true) then
				return kw
			end
		end
		return nil
	end

	local function shouldSkipRemote(remote)
		local path = remote:GetFullName()

		for _, exact in ipairs(SKIP_EXACT_PATHS) do
			if path == exact then
				return "manual SKIP_EXACT_PATHS list"
			end
		end

		if _G.__ExploitProbe_SkipRemotes[path] then
			return "blacklist (kicked you before when this was probed)"
		end

		if isRememberedCulprit(path) then
			return "remembered kick remote for this game"
		end

		local nameHit = matchesKeyword(remote.Name, SKIP_NAME_KEYWORDS)
		if nameHit then
			return "kick-risk name contains '" .. nameHit .. "'"
		end

		local pathHit = matchesKeyword(path, SKIP_PATH_KEYWORDS)
		if pathHit then
			return "kick-risk path contains '" .. pathHit .. "'"
		end

		return nil
	end

	local function reportLine(text)
		table.insert(Report.lines, text)
		lineCount += 1
		print("[ExploitProbe] " .. text)
	end

	local function flushDisplay(scrollBottom)
		if reportLabel then
			reportLabel.Text = table.concat(Report.lines, "\n")
		end
		if scrollBottom and scrollFrame then
			task.defer(function()
				scrollFrame.CanvasPosition = Vector2.new(0, scrollFrame.AbsoluteCanvasSize.Y)
			end)
		end
	end

	local function copyText()
		local text = table.concat(Report.lines, "\n")
		if text == "" then
			return false, 0
		end
		for _, fn in ipairs({ setclipboard, toclipboard }) do
			if fn then
				local ok = pcall(function()
					fn(text)
				end)
				if ok then
					return true, #text
				end
			end
		end
		return false, #text
	end

	local function fireRemote(remote, timeout, ...)
		local args = { ... }
		local finished = false
		local ok, err = false, "unknown"

		task.spawn(function()
			local callOk, callErr = pcall(function()
				if remote:IsA("RemoteEvent") then
					remote:FireServer(table.unpack(args))
				else
					remote:InvokeServer(table.unpack(args))
				end
			end)
			ok = callOk
			err = callErr
			finished = true
		end)

		local start = tick()
		local poll = activeConfig.delay == 0 and 0 or 0.03
		while not finished and tick() - start < timeout do
			task.wait(poll)
		end

		if not finished then
			return false, "timeout"
		end
		if ok then
			return true, "sent"
		end
		return false, tostring(err)
	end

	local function runSecurityAudit(remote)
		local timeout = activeConfig.timeout
		local level = activeConfig.securityLevel or "normal"
		local issues = {}
		local lines = {}

		local function flag(id, detail)
			table.insert(issues, id)
			table.insert(lines, "  [VULN] " .. detail)
		end

		local function pass(detail)
			table.insert(lines, "  [OK]   " .. detail)
		end

		-- 1) Reachable from client
		local okReach, reachErr = fireRemote(remote, timeout, "probe_reach")
		if okReach then
			flag("reachable", "Remote exists & client can FireServer/InvokeServer")
		else
			pass("Not reachable from client (" .. tostring(reachErr) .. ")")
			return { issues = issues, lines = lines, reachable = false }
		end

		if level == "quick" then
			pass("Quick mode — run Slow for full malformed/rate/replay/impossible checks")
			return { issues = issues, lines = lines, reachable = true }
		end

		-- 2) Malformed / wrong-shaped args (client-side fire — server may still reject later)
		local malformedTests = {
			{ "nil", { nil } },
			{ "empty", {} },
			{ "wrong_types", { true, {}, function() end, "string", math.huge } },
			{ "negative_id", { -1, -999999 } },
		}
		local malformedHits = 0
		for _, t in ipairs(malformedTests) do
			local ok = fireRemote(remote, timeout, table.unpack(t[2]))
			if ok then
				malformedHits += 1
			end
		end
		if malformedHits > 0 then
			flag(
				"malformed",
				"Malformed calls not instantly rejected at client (" .. malformedHits .. "/" .. #malformedTests .. " sent)"
			)
		else
			pass("Malformed arg shapes blocked or failed at client")
		end

		-- 3) Numeric sanity (currency-style probes)
		if level == "full" or level == "normal" then
			local okNum = fireRemote(remote, timeout, math.huge, -math.huge, 999999999, 0.001, -1)
			if okNum then
				flag("numeric", "Extreme numbers sent (huge/negative) — add server numeric sanity checks")
			else
				pass("Extreme numeric payload blocked at client")
			end
		end

		-- 4) Trusted client-provided values (userid, name, fake admin)
		if level == "full" or level == "normal" then
			local fakeId = player.UserId + 99999
			local okTrust = fireRemote(remote, timeout, fakeId, player.Name, "admin", 999999999, "give", "cash")
			if okTrust then
				flag("trusted_client", "Client-provided identity/currency-style values accepted from client")
			else
				pass("Spoofed identity/currency probe blocked at client")
			end
		end

		-- 5) Per-player rate limiting
		local burst = (level == "full") and 8 or 5
		local burstOk = 0
		for _ = 1, burst do
			if fireRemote(remote, timeout, "rate_test", tick()) then
				burstOk += 1
			end
		end
		if burstOk >= burst - 1 then
			flag("no_rate_limit", "Rapid repeat fires: " .. burstOk .. "/" .. burst .. " sent — add rate limits")
		else
			pass("Rate limit signal: only " .. burstOk .. "/" .. burst .. " rapid fires sent")
		end

		-- 6) Replay protection
		if level == "full" or level == "normal" then
			local payload = { nonce = "probe_fixed_nonce", action = "buy", amount = 99999, t = 12345 }
			local r1 = fireRemote(remote, timeout, payload)
			task.wait(0.05)
			local r2 = fireRemote(remote, timeout, payload)
			if r1 and r2 then
				flag("replay", "Identical payload sent twice — add nonce/replay rejection")
			else
				pass("Replay probe did not fully send duplicate payloads")
			end
		end

		-- 7) Impossible state transition probes
		if level == "full" then
			local okImp = fireRemote(
				remote,
				timeout,
				"buy",
				-1,
				999999999,
				"impossible_item",
				{ owned = false, equipped = true, cooldown = 0 }
			)
			if okImp then
				flag("impossible", "Impossible game-state payload sent — reject bad transitions server-side")
			else
				pass("Impossible-state payload blocked at client")
			end
		end

		if #issues == 0 then
			pass("No client-side red flags — still verify server rejects bad args in Studio")
		end

		return { issues = issues, lines = lines, reachable = true }
	end

	local function collectRemotes()
		local toProbe = {}
		local skipped = {}

		pcall(function()
			for _, inst in ipairs(game:GetDescendants()) do
				if inst:IsA("RemoteEvent") or (inst:IsA("RemoteFunction") and not activeConfig.skipRemoteFunctions) then
					local skipReason = shouldSkipRemote(inst)
					if skipReason then
						table.insert(skipped, { remote = inst, reason = skipReason })
					else
						table.insert(toProbe, inst)
					end
				end
			end
		end)

		table.sort(toProbe, function(a, b)
			return a:GetFullName() < b:GetFullName()
		end)
		table.sort(skipped, function(a, b)
			return a.remote:GetFullName() < b.remote:GetFullName()
		end)

		return toProbe, skipped
	end

	local function scanSourcePatterns(sourceLower, issues, issueSet)
		for _, entry in ipairs(SCRIPT_SOURCE_PATTERNS) do
			if string.find(sourceLower, string.lower(entry.pat), 1, true) and not issueSet[entry.id] then
				issueSet[entry.id] = true
				table.insert(issues, entry.id)
			end
		end
		if string.find(sourceLower, "invokeServer", 1, true) and not issueSet.fireserver_in_client then
			issueSet.fireserver_in_client = true
			table.insert(issues, "fireserver_in_client")
		end
		if
			string.find(sourceLower, "cash", 1, true)
			or string.find(sourceLower, "money", 1, true)
			or string.find(sourceLower, "coins", 1, true)
			or string.find(sourceLower, "gems", 1, true)
			or string.find(sourceLower, "currency", 1, true)
		then
			if not issueSet.client_currency then
				issueSet.client_currency = true
				table.insert(issues, "client_currency")
			end
		end
		if
			string.find(sourceLower, "admin", 1, true)
			or string.find(sourceLower, "moderator", 1, true)
			or string.find(sourceLower, "rank", 1, true)
		then
			if not issueSet.client_admin then
				issueSet.client_admin = true
				table.insert(issues, "client_admin")
			end
		end
	end

	local function auditClientScript(inst, location)
		local path = inst:GetFullName()
		local ok, source = pcall(function()
			return inst.Source
		end)

		if not ok or type(source) ~= "string" or #source == 0 then
			return nil
		end

		local issues = {}
		local issueSet = {}

		table.insert(issues, "readable_source")
		issueSet.readable_source = true

		if inst:IsA("LocalScript") then
			table.insert(issues, "localscript_exposed")
			issueSet.localscript_exposed = true
		end

		if inst:IsA("ModuleScript") and string.find(path, "ReplicatedStorage", 1, true) then
			table.insert(issues, "module_in_rs")
			issueSet.module_in_rs = true
		end

		scanSourcePatterns(string.lower(source), issues, issueSet)

		local lineCount = 1
		for _ in string.gmatch(source, "\n") do
			lineCount += 1
		end

		return {
			path = path,
			className = inst.ClassName,
			location = location,
			lines = lineCount,
			chars = #source,
			issues = issues,
		}
	end

	local function scanClientScripts()
		reportLine("========== CLIENT SCRIPT AUDIT (player-modifiable) ==========")
		reportLine("Checks LocalScripts/ModuleScripts executors can read, copy, and hook.")
		reportLine("Readable Source = exploiter can study/modify/replace client behavior.")
		reportLine("")

		local roots = {}
		local function addRoot(name, inst)
			if inst then
				table.insert(roots, { name = name, inst = inst })
			end
		end

		addRoot("ReplicatedStorage", ReplicatedStorage)
		addRoot("StarterGui", game:GetService("StarterGui"))
		addRoot("StarterPack", game:GetService("StarterPack"))
		addRoot("Workspace", workspace)

		local starterPlayer = game:GetService("StarterPlayer")
		if starterPlayer then
			addRoot("StarterPlayer", starterPlayer)
		end

		addRoot("PlayerGui", player:FindFirstChild("PlayerGui"))
		addRoot("PlayerScripts", player:FindFirstChild("PlayerScripts"))
		addRoot("Character", player.Character)

		local SCRIPT_CAP = 120
		local scanned, flagged, readable = 0, 0, 0

		for _, root in ipairs(roots) do
			reportLine("--- " .. root.name .. " ---")
			local rootCount = 0

			pcall(function()
				for _, inst in ipairs(root.inst:GetDescendants()) do
					if inst:IsA("LocalScript") or inst:IsA("ModuleScript") then
						if scanned >= SCRIPT_CAP then
							break
						end
						scanned += 1
						rootCount += 1

						local audit = auditClientScript(inst, root.name)
						if audit then
							readable += 1
							Report.clientScripts[audit.path] = audit

							if #audit.issues > 1 then
								flagged += 1
								reportLine(string.format("  [VULN] %s (%s) — %d lines", audit.path, audit.className, audit.lines))
								for _, issueId in ipairs(audit.issues) do
									reportLine("         • " .. issueId)
								end
								reportLine("         PATCH:")
								for _, issueId in ipairs(audit.issues) do
									if SCRIPT_PATCH_ADVICE[issueId] then
										reportLine("           - " .. SCRIPT_PATCH_ADVICE[issueId])
									end
								end
							else
								reportLine(
									string.format(
										"  [ok]   %s (%s) — readable but no risky patterns",
										audit.path,
										audit.className
									)
								)
							end
						end
					end
				end
			end)

			if rootCount == 0 then
				reportLine("  (no LocalScripts/ModuleScripts)")
			end
		end

		reportLine("")
		reportLine(string.format("Scripts scanned: %d | Readable: %d | Flagged risky: %d", scanned, readable, flagged))
		reportLine("")
		reportLine("========== CLIENT SCRIPT PATCH RULES ==========")
		reportLine("  • Economy/combat/admin ONLY in ServerScriptService")
		reportLine("  • Client scripts: UI + input only, FireServer with minimal args")
		reportLine("  • Never store secrets in ReplicatedStorage ModuleScripts")
		reportLine("  • Assume readable LocalScripts WILL be modified by executors")
		reportLine("")

		if flagged > 0 then
			reportLine("========== PRIORITY CLIENT SCRIPTS TO HARDEN ==========")
			for path, audit in pairs(Report.clientScripts) do
				if #audit.issues > 1 then
					reportLine("• " .. path)
				end
			end
			reportLine("")
		end

		flushDisplay(false)
		copyText()
	end

	local function mountGui()
		screenGui = Instance.new("ScreenGui")
		screenGui.Name = GUI_NAME
		screenGui.ResetOnSpawn = false
		screenGui.IgnoreGuiInset = true
		screenGui.DisplayOrder = 99999
		screenGui.Parent = (gethui and gethui()) or CoreGui
		if syn and syn.protect_gui then
			pcall(syn.protect_gui, screenGui)
		end
		if not screenGui.Parent then
			screenGui.Parent = player:WaitForChild("PlayerGui")
		end

		local panel = Instance.new("Frame")
		panel.AnchorPoint = Vector2.new(0.5, 0.5)
		panel.Position = UDim2.fromScale(0.5, 0.5)
		panel.Size = UDim2.fromOffset(520, 500)
		panel.BackgroundColor3 = Color3.fromRGB(22, 24, 32)
		panel.Parent = screenGui
		Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)

		local title = Instance.new("TextLabel")
		title.BackgroundTransparency = 1
		title.Position = UDim2.fromOffset(12, 8)
		title.Size = UDim2.new(1, -24, 0, 24)
		title.Font = Enum.Font.GothamBold
		title.TextSize = 17
		title.TextColor3 = Color3.fromRGB(255, 255, 255)
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Text = "Game Security Audit"
		title.Parent = panel

		statusLabel = Instance.new("TextLabel")
		statusLabel.BackgroundTransparency = 1
		statusLabel.Position = UDim2.fromOffset(12, 34)
		statusLabel.Size = UDim2.new(1, -24, 0, 48)
		statusLabel.Font = Enum.Font.Gotham
		statusLabel.TextSize = 11
		statusLabel.TextWrapped = true
		statusLabel.TextColor3 = Color3.fromRGB(160, 210, 255)
		statusLabel.TextXAlignment = Enum.TextXAlignment.Left
		statusLabel.Text = "Audits client scripts + remotes. Report copies when done."
		statusLabel.Parent = panel

		pathInput = Instance.new("TextBox")
		pathInput.Position = UDim2.fromOffset(12, 86)
		pathInput.Size = UDim2.new(1, -24, 0, 28)
		pathInput.BackgroundColor3 = Color3.fromRGB(12, 14, 20)
		pathInput.TextColor3 = Color3.fromRGB(255, 255, 255)
		pathInput.PlaceholderText = "Optional: ReplicatedStorage.Folder.RemoteName"
		pathInput.Font = Enum.Font.Code
		pathInput.TextSize = 12
		pathInput.Parent = panel
		Instance.new("UICorner", pathInput).CornerRadius = UDim.new(0, 6)

		scrollFrame = Instance.new("ScrollingFrame")
		scrollFrame.Position = UDim2.fromOffset(12, 122)
		scrollFrame.Size = UDim2.new(1, -24, 1, -170)
		scrollFrame.BackgroundColor3 = Color3.fromRGB(10, 12, 18)
		scrollFrame.BorderSizePixel = 0
		scrollFrame.ScrollBarThickness = 10
		scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scrollFrame.Parent = panel
		Instance.new("UICorner", scrollFrame).CornerRadius = UDim.new(0, 6)

		local content = Instance.new("Frame")
		content.BackgroundTransparency = 1
		content.Size = UDim2.new(1, -8, 0, 0)
		content.AutomaticSize = Enum.AutomaticSize.Y
		content.Parent = scrollFrame

		reportLabel = Instance.new("TextLabel")
		reportLabel.BackgroundTransparency = 1
		reportLabel.Size = UDim2.new(1, 0, 0, 0)
		reportLabel.Font = Enum.Font.Code
		reportLabel.TextSize = 11
		reportLabel.TextColor3 = Color3.fromRGB(200, 210, 225)
		reportLabel.TextXAlignment = Enum.TextXAlignment.Left
		reportLabel.TextYAlignment = Enum.TextYAlignment.Top
		reportLabel.TextWrapped = true
		reportLabel.AutomaticSize = Enum.AutomaticSize.Y
		reportLabel.Text = "Press Slow, Medium, or Fast to start."
		reportLabel.Parent = content

		local function btn(text, x, w, fn, col)
			local b = Instance.new("TextButton")
			b.Position = UDim2.fromOffset(x, 458)
			b.Size = UDim2.fromOffset(w, 32)
			b.BackgroundColor3 = col or Color3.fromRGB(45, 100, 220)
			b.TextColor3 = Color3.fromRGB(255, 255, 255)
			b.Font = Enum.Font.GothamBold
			b.TextSize = 12
			b.Text = text
			b.Parent = panel
			Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
			b.MouseButton1Click:Connect(fn)
		end

		return btn
	end

	local function probeOneRemote(remote, index)
		local path = remote:GetFullName()
		local className = remote.ClassName

		reportLine(string.format("[%d] %s (%s)", index, path, className))
		reportLine("  --- security audit (client-side fire; server must reject bad data) ---")

		local auditOk, audit = pcall(function()
			return runSecurityAudit(remote)
		end)

		if not auditOk then
			reportLine("  [ERR]  Audit crashed: " .. tostring(audit))
			Report.allRemotes[path] = {
				index = index,
				path = path,
				className = className,
				status = "AUDIT ERROR",
				issues = {},
			}
			return false
		end

		for _, line in ipairs(audit.lines) do
			reportLine(line)
		end

		if #audit.issues > 0 then
			Report.manipulable[path] = true
			Report.vulnFindings[path] = audit.issues
			reportLine("  PATCH:")
			for _, issueId in ipairs(audit.issues) do
				local advice = PATCH_ADVICE[issueId]
				if advice then
					reportLine("    • " .. advice)
				end
			end
		end

		local status = (#audit.issues > 0) and ("VULNERABLE (" .. #audit.issues .. " checks)") or "LOOKS OK (client probes)"
		Report.allRemotes[path] = {
			index = index,
			path = path,
			className = className,
			status = status,
			issues = audit.issues,
		}

		return audit.reachable and #audit.issues > 0
	end

	local function runScan(speedKey)
		if scanRunning then
			return
		end
		scanRunning = true

		activeConfig = SPEED_PRESETS[speedKey] or SPEED_PRESETS.medium

		Report.lines = {}
		Report.allRemotes = {}
		Report.manipulable = {}
		Report.vulnFindings = {}
		Report.clientScripts = {}
		lineCount = 0

		reportLine("=== GAME SECURITY AUDIT (remotes + client scripts) ===")
		reportLine("Player: " .. player.Name .. " | PlaceId: " .. game.PlaceId)
		reportLine("Speed: " .. activeConfig.label)
		reportLine("Delay: " .. activeConfig.delay .. "s | Timeout: " .. activeConfig.timeout .. "s per remote")
		if activeConfig.skipRemoteFunctions then
			reportLine("Mode: RemoteEvent only (skips RemoteFunction — less kicks)")
		else
			reportLine("Mode: RemoteEvent + RemoteFunction")
		end
		if USE_STEALTH_PAYLOAD then
			reportLine("Payload: stealth (no __AC_PROBE__ tag)")
		end
		reportLine("")
		reportLine("NOTE: Kick AFTER scan ends = delayed batch kick (AC counted all probes).")
		reportLine("      This script does NOT call Kick. Report copies when scan finishes.")
		reportLine("")

		scanClientScripts()

		if not player.Parent then
			reportLine("Kicked during client script scan — partial report copied.")
			copyText()
			scanRunning = false
			flushDisplay(true)
			return
		end

		local remotes, skippedRemotes = collectRemotes()

		reportLine("Safe to probe: " .. #remotes .. " remotes")
		reportLine("Skipped (kick-risk, NOT probed): " .. #skippedRemotes)
		reportLine("")

		if #skippedRemotes > 0 then
			reportLine("========== SKIPPED — KICK / BAN / AC REMOTES ==========")
			for i, entry in ipairs(skippedRemotes) do
				local path = entry.remote:GetFullName()
				Report.allRemotes[path] = {
					index = i,
					path = path,
					className = entry.remote.ClassName,
					status = "SKIPPED — " .. entry.reason,
				}
				reportLine(string.format("[skip %d] %s (%s)", i, path, entry.remote.ClassName))
				reportLine("     → " .. entry.reason)
			end
			reportLine("")
		end

		if #remotes == 0 then
			reportLine("No safe remotes left to probe (all were kick-risk or none exist).")
			flushDisplay(true)
			statusLabel.Text = "Nothing safe to probe."
			scanRunning = false
			return
		end

		reportLine("========== PROBE ORDER ==========")
		for i, remote in ipairs(remotes) do
			local path = remote:GetFullName()
			reportLine(string.format("[%d] %s (%s)", i, path, remote.ClassName))
		end
		reportLine("")
		flushDisplay(false)
		copyText()

		reportLine("========== PROBING (watch for >>> PROBING NOW lines) ==========")
		reportLine("")

		local manipCount = 0
		local safeCount = 0

		for i, remote in ipairs(remotes) do
			local path = remote:GetFullName()
			lastProbedPath = path

			if not player.Parent then
				reportLine("")
				reportLine("!!!!!!!!!! KICKED — CULPRIT REMOTE !!!!!!!!!!")
				reportLine("This remote was firing when you got Error 267:")
				reportLine(">>> " .. path)
				reportLine("Index: [" .. i .. "/" .. #remotes .. "]")
				rememberKickCulprit(path)
				reportLine("Auto-blacklisted for this game + session. Won't probe again.")
				copyText()
				scanRunning = false
				flushDisplay(true)
				statusLabel.Text = "KICKED by: " .. path
				return
			end

			local waitText = activeConfig.delay > 0 and string.format(" (%.1fs wait)", activeConfig.delay) or ""
			statusLabel.Text = string.format("[%s] %d/%d%s\n%s", activeConfig.label, i, #remotes, waitText, path)

			reportLine(">>> PROBING NOW [" .. i .. "/" .. #remotes .. "]: " .. path)
			flushDisplay(false)

			if i == #remotes or i % 5 == 0 then
				copyText()
			end

			local ok, result = pcall(function()
				return probeOneRemote(remote, i)
			end)

			if not player.Parent then
				reportLine("     → KICKED while probing this remote (Error 267)")
				rememberKickCulprit(path)
				copyText()
				flushDisplay(true)
				statusLabel.Text = "KICKED by: " .. path
				scanRunning = false
				return
			end

			if not ok then
				local path = remote:GetFullName()
				reportLine(string.format("[%d] %s — SKIPPED (%s)", i, path, tostring(result)))
				safeCount += 1
			elseif result then
				manipCount += 1
			else
				safeCount += 1
			end

			if i % activeConfig.flushEvery == 0 or i == #remotes then
				flushDisplay(false)
			end

			if activeConfig.autoCopyEvery > 0 and i % activeConfig.autoCopyEvery == 0 then
				local copied = copyText()
				if copied and statusLabel then
					statusLabel.Text = string.format("Auto-saved report to clipboard (%d/%d)", i, #remotes)
				end
			end

			if i < #remotes and activeConfig.delay > 0 then
				task.wait(activeConfig.delay)
			end
		end

		reportLine("")
		reportLine("========== SECURITY FINDINGS SUMMARY ==========")
		reportLine("Legend: [VULN] = client could send it — server MUST reject in handler.")
		reportLine("")

		local issueCounts = {}
		for path, issueList in pairs(Report.vulnFindings) do
			for _, issueId in ipairs(issueList) do
				issueCounts[issueId] = (issueCounts[issueId] or 0) + 1
			end
		end

		for issueId, count in pairs(issueCounts) do
			reportLine(string.format("  %s: %d remotes", issueId, count))
			if PATCH_ADVICE[issueId] then
				reportLine("    → " .. PATCH_ADVICE[issueId])
			end
		end

		if manipCount == 0 then
			reportLine("  (no vulnerability flags from client probes)")
		end

		reportLine("")
		reportLine("========== GLOBAL PATCH CHECKLIST ==========")
		reportLine("  • Server-authoritative currency/rewards/inventory")
		reportLine("  • Validate arg types at handler entry (before deep execution)")
		reportLine("  • Sanity-check numeric ranges on every number from client")
		reportLine("  • Per-player rate limits / cooldowns per remote")
		reportLine("  • Replay protection (nonce/timestamp/idempotency)")
		reportLine("  • Reject impossible state transitions with preconditions")
		reportLine("  • Never trust client userid, items, cash, or admin flags")
		reportLine("")

		-- Save report NOW — before AC's delayed "scan finished" kick (Error 267)
		reportLine("========== SCAN FINISHED ==========")
		reportLine("Probed " .. #remotes .. " remotes. Flagged: " .. manipCount)
		reportLine("")
		reportLine("!!! If you get kicked in a few seconds, that's your AC reacting to")
		reportLine("!!! the ENTIRE scan (batch kick) — NOT the last remote you probed.")
		reportLine("!!! Error 267 after 'done' = anti-cheat is WORKING as intended.")

		flushDisplay(true)
		local copied, chars = copyText()

		if copied then
			statusLabel.Text = string.format(
				"DONE — %d/%d manipulable. Report COPIED (%d chars). Kick may happen now (batch AC).",
				manipCount,
				#remotes,
				chars
			)
		else
			statusLabel.Text = "DONE — Press Copy All NOW before kick (batch AC may fire)."
		end

		-- Summary after clipboard save (kick may interrupt this — report already safe)
		if pathInput and pathInput.Text ~= "" then
			reportLine("")
			reportLine("Custom: " .. pathInput.Text)
			local obj = game
			local resolveOk = pcall(function()
				for part in string.gmatch(pathInput.Text, "[^%.]+") do
					obj = obj:WaitForChild(part, 2)
				end
			end)
			if resolveOk and (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")) then
				local skipReason = shouldSkipRemote(obj)
				if skipReason then
					reportLine("     → SKIPPED — " .. skipReason)
				else
					probeOneRemote(obj, #remotes + 1)
				end
			else
				reportLine("     → NOT FOUND")
			end
		end

		reportLine("")
		reportLine("========== SUMMARY ==========")
		reportLine("Manipulable: " .. manipCount)
		reportLine("Not manipulable: " .. safeCount)

		if manipCount > 0 then
			reportLine("")
			reportLine("========== REMOTES TO PATCH (open in Studio) ==========")
			for path, info in pairs(Report.allRemotes) do
				if Report.manipulable[path] then
					reportLine("• " .. path .. " (" .. info.className .. ") — " .. tostring(info.status))
				end
			end
		end

		copyText()
		flushDisplay(true)
		scanRunning = false
	end

	local makeBtn = mountGui()

	makeBtn("Slow", 8, 98, function()
		task.spawn(function()
			runScan("slow")
		end)
	end, Color3.fromRGB(35, 110, 65))

	makeBtn("Medium", 112, 98, function()
		task.spawn(function()
			runScan("medium")
		end)
	end, Color3.fromRGB(45, 100, 200))

	makeBtn("Fast", 216, 98, function()
		task.spawn(function()
			runScan("fast")
		end)
	end, Color3.fromRGB(200, 90, 45))

	makeBtn("Copy All", 320, 95, function()
		flushDisplay(true)
		local copied, chars = copyText()
		statusLabel.Text = copied and ("Copied " .. chars .. " chars.") or "Copy failed."
	end)

	makeBtn("Close", 421, 91, function()
		screenGui:Destroy()
		_G.__ServerExploitProbeLoaded = nil
	end, Color3.fromRGB(80, 85, 100))

	_G.__ServerExploitProbeLoaded = true
	-- No auto-start — you choose when to probe (less surprise kicks)

	return "OK"
end

local ok, result = xpcall(main, function(err)
	return debug.traceback(tostring(err), 2)
end)

if not ok then
	warn("[ExploitProbe] CRASHED:\n" .. tostring(result))
end
