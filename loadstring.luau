-- POTASSIUM: Join the game first (not menu), then paste this.

local URL = "https://raw.githubusercontent.com/aguy55409-commits/script/main/script.luau"

local ok, err = pcall(function()
	local body = game:HttpGet(URL, true)
	if not body or #body < 100 then
		error("HttpGet returned empty — is the repo public? Paste script.luau manually instead.")
	end
	local fn = loadstring(body)
	if not fn then
		error("loadstring returned nil — bad script source")
	end
	fn()
end)

if not ok then
	warn("========== EXPLOIT PROBE FAILED ==========")
	warn(tostring(err))
	warn("Fix: paste the full script.luau file into Potassium (no HttpGet).")
end
