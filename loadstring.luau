-- Potassium: paste while IN GAME (not menu). Shows error if load fails.
local ok, err = pcall(function()
	loadstring(game:HttpGet("https://raw.githubusercontent.com/aguy55409-commits/script/main/script.luau", true))()
end)
if not ok then
	warn("[ExploitProbe] ", err)
end
