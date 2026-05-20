--[[
  POPUP GUI — paste or loadstring this WHOLE file while IN PLAY MODE

  Works when you execute on CLIENT (executor / Studio Client bar) or SERVER.

  Loadstring:
    local ok, err = pcall(function()
      loadstring(game:HttpGet("https://raw.githubusercontent.com/aguy55409-commits/script/main/script.luau", true))()
    end)
    if not ok then warn("[ServerPopupGui] ", err) end
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GUI_NAME = "ServerPopupGui"
local REMOTE_FOLDER_NAME = "ServerPopupGui_Remotes"
local REMOTE_EVENT_NAME = "Action"

local function getOrCreateRemotes()
	local folder = ReplicatedStorage:FindFirstChild(REMOTE_FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = REMOTE_FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end

	local remote = folder:FindFirstChild(REMOTE_EVENT_NAME)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = REMOTE_EVENT_NAME
		remote.Parent = folder
	end

	return remote
end

local function createPopupGui(playerGui)
	local existing = playerGui:FindFirstChild(GUI_NAME)
	if existing then
		existing:Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = GUI_NAME
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

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
	status.Text = "Ready."
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

local function startServer()
	if _G.__ServerPopupGui_Server then
		return
	end
	_G.__ServerPopupGui_Server = true

	local remote = getOrCreateRemotes()

	remote.OnServerEvent:Connect(function(player, action, payload)
		if action == "submit" then
			local message = payload
			if type(message) ~= "string" or message == "" then
				remote:FireClient(player, "Server: please enter a message first.")
				return
			end

			local reply = string.format("Server received from %s: %s", player.Name, message)
			print("[ServerPopupGui]", reply)
			remote:FireClient(player, reply)
		elseif action == "close" then
			remote:FireClient(player, "Popup closed on the server.")
		elseif action == "open" then
			remote:FireClient(player, "Popup reopened from the server.")
		end
	end)

	print("[ServerPopupGui] Server handler running.")
end

local function startClient()
	if _G.__ServerPopupGui_Client then
		return
	end
	_G.__ServerPopupGui_Client = true

	local player = Players.LocalPlayer
	if not player then
		warn("[ServerPopupGui] Press PLAY first, then execute the script.")
		return
	end

	local playerGui = player:FindFirstChild("PlayerGui") or player:WaitForChild("PlayerGui", 10)
	if not playerGui then
		warn("[ServerPopupGui] PlayerGui not found. Are you in Play mode?")
		return
	end

	local remote = ReplicatedStorage:WaitForChild(REMOTE_FOLDER_NAME, 8)
	if remote then
		remote = remote:WaitForChild(REMOTE_EVENT_NAME, 5)
	end

	local screenGui = createPopupGui(playerGui)
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

	local function fire(action, payload)
		if remote and remote:IsA("RemoteEvent") then
			remote:FireServer(action, payload)
			return true
		end
		return false
	end

	if remote and remote:IsA("RemoteEvent") then
		remote.OnClientEvent:Connect(function(message)
			status.Text = message
		end)
		status.Text = "Connected to server."
	else
		status.Text = "GUI open (server not loaded — buttons work locally only)."
	end

	submit.Activated:Connect(function()
		local message = input.Text
		if message == "" then
			status.Text = "Please enter a message first."
			return
		end

		if fire("submit", message) then
			input.Text = ""
		else
			status.Text = "Local: " .. message
			input.Text = ""
		end
	end)

	close.Activated:Connect(function()
		setOpen(false)
		if not fire("close") then
			status.Text = "Closed (local)."
		end
	end)

	reopen.Activated:Connect(function()
		setOpen(true)
		if not fire("open") then
			status.Text = "Reopened (local)."
		end
	end)

	setOpen(true)
	print("[ServerPopupGui] Client GUI opened.")
end

if RunService:IsServer() then
	startServer()
end

if RunService:IsClient() then
	startClient()
end

-- Studio "Play Solo" runs this file on both server and client when executed once from a shared context.
-- Executor usually runs client only: GUI still appears; run server half in ServerScriptService for real server replies.
