# Game Security Tools (Potassium)

For **your** Roblox game. Run in-game with Potassium.

## Cobalt Redux — combat module (`cobalt-redux.luau`)

Legit aimbot, rage orbit, ESP, triggerbot. Menu: **RightShift** / **Insert**.

**Private repo (recommended)** — `game:HttpGet` cannot read private GitHub files. Use a PAT:

```lua
local T = "YOUR_GITHUB_TOKEN" -- repo Contents: Read
local U = "https://api.github.com/repos/aguy55409-commits/script/contents/cobalt-redux.luau?ref=main"
local R = (syn and syn.request or http and http.request or request)({
	Url = U,
	Headers = { Authorization = "Bearer " .. T, Accept = "application/vnd.github.raw", ["User-Agent"] = "CobaltRedux" },
})
loadstring(R.Body)()
```

**Public repo one-liner:**

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/aguy55409-commits/script/main/cobalt-redux.luau", true))()
```

**Loader file** — open `cobalt-redux-loadstring.luau`, paste your token into `GITHUB_TOKEN`, then execute that file in your executor (do not HttpGet the loader from a private repo).

**No token?** Load `cobalt-redux.luau` directly from your executor file browser.

---

## 1. Full security audit (`script.luau`)

Remotes + client script scan + per-remote security checks.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/aguy55409-commits/script/main/script.luau", true))()
```

## 2. Speed exploit test (`speed-test.luau`)

**Fake treadmill simulation** (no RakNet). **Record** on treadmill saves which `FireServer` payloads raised `leaderstats.Speed`. **START** replays that profile constantly anywhere.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/aguy55409-commits/script/main/speed-test.luau", true))()
```

**Controls:** Start speed, add per tick, interval. **Start** / **Stop**.

If speed only changes briefly or only on your screen → server validation is working. If speed sticks or goes crazy → patch `SetCustomSpeed` / `UpdateSpeed` handlers in Studio.

## Notes

- Repo is **private** — use a GitHub PAT or load the `.luau` file locally. Public repos can use plain `HttpGet`.
- `[VULN]` on the probe = client *can send* — server must reject in the handler.
