# Game Security Tools (Potassium)

For **your** Roblox game. Run in-game with Potassium.

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

- Repo must be **public** for HttpGet, or paste files directly.
- `[VULN]` on the probe = client *can send* — server must reject in the handler.
