# script.luau — execute in your game

One file. Copy the whole thing, run it on the **server**, popup shows **immediately**.

## Roblox Studio (your place)

1. Open your game in Studio and press **Play** (or Play Here).
2. **View → Command Bar**
3. Click **Server** (not Client) in the command bar.
4. Open `script.luau`, copy **everything**, paste into the command bar, press **Enter**.

The GUI should pop up right away for everyone in the server.

**Permanent install:** ServerScriptService → Insert **Script** → paste `script.luau` → stop/restart play. It runs every session.

## Inject (your own game)

Use a **server-side** run (Studio Server command bar, or an executor that runs server scripts in **your** place). Client-only inject cannot drive a true server GUI.

## Buttons

- **Send to Server** — server reads your text and updates the label
- **Close** / **Open Menu** — hide or show the popup (still server-side)
