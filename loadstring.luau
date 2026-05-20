-- Paste THIS into your executor (one line). Requires Play mode + public GitHub raw URL.
local ok, err = pcall(function()
	loadstring(game:HttpGet("https://raw.githubusercontent.com/aguy55409-commits/script/main/script.luau", true))()
end)
if not ok then
	warn("[ServerPopupGui] Failed:", err)
else
	print("[ServerPopupGui] Ran OK")
end
