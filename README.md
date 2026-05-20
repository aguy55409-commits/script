# script.luau

Popup GUI for **your** Roblox game. Run while **Play** is active.

## Why it did nothing before

1. **Not in Play mode** — `LocalPlayer` only exists after you press Play.
2. **Ran on Server tab only** — old version quit on client; most executors run **client**.
3. **HttpGet failed** — private repo or HTTP off → loadstring never ran. Use `loadstring.luau` (shows errors) or paste `script.luau` directly.

## Executor (client) — GUI shows immediately

1. Press **Play** in your game.
2. Paste and run **`loadstring.luau`** (or the block below).

```lua
local ok, err = pcall(function()
	loadstring(game:HttpGet("https://raw.githubusercontent.com/aguy55409-commits/script/main/script.luau", true))()
end)
if not ok then warn("[ServerPopupGui] Failed:", err) end
```

3. For **Send to Server** to hit the real server: also run the same script on the server once —
   - Studio: Command Bar → **Server** → paste full `script.luau`, Enter  
   - Or: **ServerScriptService** → Script → paste `script.luau` → Play

## Studio without executor

1. **Play**
2. Command Bar → **Client** → paste all of `script.luau` → Enter  
   Popup should appear right away.

## Paste instead of HttpGet

If loadstring fails, paste the entire `script.luau` into the executor (no HttpGet).
