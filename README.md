# Server Popup GUI (Luau)

A Roblox popup GUI that is **created and controlled entirely on the server**. No LocalScripts are required.

## What it does

- When a player spawns, the server builds a `ScreenGui` in their `PlayerGui`
- **Send to Server** — reads the text box and updates the status label on the server (also prints to the output)
- **Close** — hides the popup; a small **Open Menu** button stays so they can reopen it
- All button handlers use `Activated` connections on the **server**

## Setup in Roblox Studio

### Option A — Rojo (recommended for this repo)

1. Install [Rojo](https://rojo.space/docs/v7/installation/)
2. Open this folder in a terminal and run:

   ```bash
   rojo serve
   ```

3. In Studio: install the Rojo plugin → **Connect** → playtest

### Option B — Manual copy

1. Open your place in Roblox Studio
2. In **ServerScriptService**, create a **Script** named `ServerPopupGui`
3. Paste the contents of `src/ServerScriptService/ServerPopupGui.server.luau`
4. Playtest

## Push to GitHub

From this folder, after you have files to commit:

```bash
git add .
git commit -m "Add server-side popup GUI in Luau"
git push -u origin main
```

You will be prompted to sign in to GitHub (PAT or browser) if not already authenticated.
