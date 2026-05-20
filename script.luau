--[[
  SERVER POPUP GUI — single file, run as-is

  Studio (your game):
    1. View → Command Bar
    2. Switch to SERVER (not Client)
    3. Paste this entire file and press Enter — GUI shows right away

  Or: ServerScriptService → Insert Script → paste this file → Play

  Inject (your own game / server-side executor):
    Execute this script on the SERVER so buttons stay server-sided.
]]

if not game:GetService("RunService"):IsServer() then
	warn("[ServerPopupGui] Run on SERVER only (Studio Command Bar → Server tab).")
	return
end

if _G.__ServerPopupGuiLoaded then
	return
end
_G.__ServerPopupGuiLoaded = true

local Players = game:GetService("Players")
local GUI_NAME = "ServerPopupGui"

local function createPopupGui(player)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = GUI_NAME
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = player:WaitForChild("PlayerGui")

	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.45
	overlay.BorderSizePixel = 0
	overlay.Parent = screenGui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(360, 280)
	panel.BackgroundColor3 = Color3.fromRGB(32, 34, 42)
	panel.BorderSizePixel = 0
	panel.Parent = overlay

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(70, 120, 255)
	stroke.Thickness = 2
	stroke.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -24, 0, 44)
	title.Position = UDim2.fromOffset(12, 12)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 22
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "Server Popup"
	title.Parent = panel

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.Size = UDim2.new(1, -24, 0, 56)
	status.Position = UDim2.fromOffset(12, 60)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.Gotham
	status.TextSize = 16
	status.TextColor3 = Color3.fromRGB(200, 205, 220)
	status.TextWrapped = true
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.TextYAlignment = Enum.TextYAlignment.Top
	status.Text = "All actions run on the server."
	status.Parent = panel

	local input = Instance.new("TextBox")
	input.Name = "MessageInput"
	input.Size = UDim2.new(1, -24, 0, 40)
	input.Position = UDim2.fromOffset(12, 130)
	input.BackgroundColor3 = Color3.fromRGB(22, 24, 30)
	input.TextColor3 = Color3.fromRGB(255, 255, 255)
	input.PlaceholderText = "Type a message..."
	input.PlaceholderColor3 = Color3.fromRGB(130, 135, 150)
	input.Font = Enum.Font.Gotham
	input.TextSize = 16
	input.ClearTextOnFocus = false
	input.Text = ""
	input.Parent = panel

	local inputCorner = Instance.new("UICorner")
	inputCorner.CornerRadius = UDim.new(0, 8)
	inputCorner.Parent = input

	local inputPadding = Instance.new("UIPadding")
	inputPadding.PaddingLeft = UDim.new(0, 10)
	inputPadding.PaddingRight = UDim.new(0, 10)
	inputPadding.Parent = input

	local submit = Instance.new("TextButton")
	submit.Name = "SubmitButton"
	submit.Size = UDim2.new(0.5, -18, 0, 44)
	submit.Position = UDim2.fromOffset(12, 190)
	submit.BackgroundColor3 = Color3.fromRGB(55, 110, 255)
	submit.TextColor3 = Color3.fromRGB(255, 255, 255)
	submit.Font = Enum.Font.GothamBold
	submit.TextSize = 16
	submit.Text = "Send to Server"
	submit.AutoButtonColor = true
	submit.Parent = panel

	local submitCorner = Instance.new("UICorner")
	submitCorner.CornerRadius = UDim.new(0, 8)
	submitCorner.Parent = submit

	local close = Instance.new("TextButton")
	close.Name = "CloseButton"
	close.Size = UDim2.new(0.5, -18, 0, 44)
	close.Position = UDim2.new(0.5, 6, 0, 190)
	close.BackgroundColor3 = Color3.fromRGB(70, 74, 88)
	close.TextColor3 = Color3.fromRGB(255, 255, 255)
	close.Font = Enum.Font.GothamBold
	close.TextSize = 16
	close.Text = "Close"
	close.AutoButtonColor = true
	close.Parent = panel

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = close

	local reopen = Instance.new("TextButton")
	reopen.Name = "ReopenButton"
	reopen.Size = UDim2.fromOffset(120, 36)
	reopen.Position = UDim2.new(1, -132, 1, -48)
	reopen.BackgroundColor3 = Color3.fromRGB(45, 48, 58)
	reopen.TextColor3 = Color3.fromRGB(255, 255, 255)
	reopen.Font = Enum.Font.Gotham
	reopen.TextSize = 14
	reopen.Text = "Open Menu"
	reopen.Visible = false
	reopen.Parent = screenGui

	local reopenCorner = Instance.new("UICorner")
	reopenCorner.CornerRadius = UDim.new(0, 8)
	reopenCorner.Parent = reopen

	return screenGui
end

local function bindGui(player, screenGui)
	local overlay = screenGui:WaitForChild("Overlay")
	local panel = overlay:WaitForChild("Panel")
	local status = panel:WaitForChild("Status")
	local input = panel:WaitForChild("MessageInput")
	local submit = panel:WaitForChild("SubmitButton")
	local close = panel:WaitForChild("CloseButton")
	local reopen = screenGui:WaitForChild("ReopenButton")

	local function setOpen(isOpen)
		overlay.Visible = isOpen
		reopen.Visible = not isOpen
	end

	submit.Activated:Connect(function()
		local message = input.Text
		if message == "" then
			status.Text = "Server: please enter a message first."
			return
		end

		status.Text = string.format("Server received from %s: %s", player.Name, message)
		print(string.format("[ServerPopupGui] %s sent: %s", player.Name, message))
		input.Text = ""
	end)

	close.Activated:Connect(function()
		setOpen(false)
		status.Text = "Popup closed. Use Open Menu to show again."
	end)

	reopen.Activated:Connect(function()
		setOpen(true)
		status.Text = "Popup reopened from the server."
	end)

	setOpen(true)
end

local function giveGuiToPlayer(player)
	local playerGui = player:FindFirstChild("PlayerGui") or player:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild(GUI_NAME)
	if existing then
		existing:Destroy()
	end

	local screenGui = createPopupGui(player)
	bindGui(player, screenGui)
end

-- Runs immediately when you execute this script
for _, player in Players:GetPlayers() do
	task.spawn(giveGuiToPlayer, player)
end

Players.PlayerAdded:Connect(function(player)
	player:WaitForChild("PlayerGui")
	giveGuiToPlayer(player)
end)

print("[ServerPopupGui] Loaded — popup should be visible now.")
