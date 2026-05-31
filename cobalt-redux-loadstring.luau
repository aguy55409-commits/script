-- Cobalt Redux loader — join a game first, then execute (Potassium / Synapse / etc.)

local URL = "https://raw.githubusercontent.com/aguy55409-commits/script/main/cobalt-redux.luau"

local ok, err = pcall(function()
	local body = game:HttpGet(URL, true)
	if not body or #body < 1000 then
		error("HttpGet failed or file too small — is the repo public?")
	end
	local fn = loadstring(body)
	if not fn then
		error("loadstring returned nil")
	end
	fn()
end)

if not ok then
	warn("[Cobalt Redux] Load failed:\n" .. tostring(err))
end
