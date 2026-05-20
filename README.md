# Server Exploit Probe (Potassium)

Client-only script to test **your** anti server-sided exploit protections.  
**No ServerScriptService.** Execute from **Potassium** while you are in your game.

## Loadstring (Potassium)

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/aguy55409-commits/script/main/script.luau", true))()
```

With error output:

```lua
local ok, err = pcall(function()
	loadstring(game:HttpGet("https://raw.githubusercontent.com/aguy55409-commits/script/main/script.luau", true))()
end)
if not ok then warn("[ExploitProbe] ", err) end
```

## What it tests (from client inject)

| Button / test | What it simulates |
|---------------|-------------------|
| **Client RemoteEvent** | Executor creates a remote and `FireServer` |
| **SSS Inject** | Tries to parent a `Script` into `ServerScriptService` |
| **ServerStorage** | Tries to parent a `Part` into `ServerStorage` |
| **Invalid args** | Huge / bad payloads on a real remote |
| **Remote spam** | Rapid `FireServer` burst |
| **Fire Remotes** | Hits up to 25 `RemoteEvent` / `RemoteFunction` in your game |

## Reading results

- **BLOCKED** (green in log) — your protection stopped it (good).
- **SENT/OK** (orange) — call went through; check if your AC logged/kicked.
- If **SSS inject** says "script parented" — that path is **not** blocked.

## Custom remote

Optional text box: `ReplicatedStorage.SomeFolder.SomeRemote`

## Notes

- Repo must be **public** for HttpGet, or paste `script.luau` directly into Potassium.
- Only use on **your** game while building anti-exploit.
