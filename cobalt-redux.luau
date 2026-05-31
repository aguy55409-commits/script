--[[
    Cobalt Redux — Semi-blatant combat module (Randomizer Redux)
    GUI: Linoria-style linear init (loads immediately)
    Legit: Camera aim + mouse fallback | Rage: auto-fire wallbang desync
]]

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")

local VirtualInputManager = nil
pcall(function()
    VirtualInputManager = game:GetService("VirtualInputManager")
end)

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    LocalPlayer = Players.PlayerAdded:Wait()
end

-- Re-run safe: destroy previous instances
local GuiParent = nil
pcall(function()
    if gethui then GuiParent = gethui() end
end)
if not GuiParent then
    GuiParent = (cloneref and cloneref(CoreGui)) or CoreGui
end
if not GuiParent then
    pcall(function()
        GuiParent = LocalPlayer:WaitForChild("PlayerGui", 5)
    end)
end
if not GuiParent then
    GuiParent = CoreGui
end
do
    local old = GuiParent:FindFirstChild("CobaltRedux")
    if old then old:Destroy() end
    old = GuiParent:FindFirstChild("CobaltReduxOverlay")
    if old then old:Destroy() end
    old = GuiParent:FindFirstChild("CobaltReduxToast")
    if old then old:Destroy() end
    old = workspace.CurrentCamera and workspace.CurrentCamera:FindFirstChild("CobaltEsp")
    if old then old:Destroy() end
end

local AIM_MODES = { "Always", "Toggle", "Hold" }
local HIT_PARTS = { "Head", "UpperTorso", "HumanoidRootPart", "LowerTorso" }
local TARGET_PRIORITIES = { "Crosshair", "Distance" }
local MAP_FOLDERS = { "Map", "Terrain", "Buildings", "Geometry", "KillParts", "Barriers", "Obstacles" }
local BARRIER_KEYWORDS = { "kill", "death", "void", "lava", "barrier", "deadzone", "oob", "hurt", "damage" }
local BARRIER_FOLDERS = { "Map", "KillParts", "Barriers", "Terrain" }
local HIDE_KEYS = { Enum.KeyCode.RightShift, Enum.KeyCode.Insert }
local SNAP_DIST = 15

local CONFIG_DIR = "CobaltRedux/config"
local PROFILES_DIR = CONFIG_DIR .. "/profiles"
local META_PATH = CONFIG_DIR .. "/meta.json"
local ACCENTS = {
    Cobalt = Color3.fromRGB(0, 85, 255),
    Pink = Color3.fromRGB(255, 105, 180),
    Midnight = Color3.fromRGB(130, 90, 255),
    Nebula = Color3.fromRGB(180, 90, 255),
}
local R6_BONES = {
    {"Head", "Torso"}, {"Torso", "Left Arm"}, {"Torso", "Right Arm"},
    {"Torso", "Left Leg"}, {"Torso", "Right Leg"},
}
local R15_BONES = {
    {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"},
}


local St = {
    running = true,
    uiHidden = false,
    -- Legit
    aimbot = false,
    aimMode = 3,
    aimKey = Enum.KeyCode.E,
    aimBindType = "key",
    aimMouse = Enum.UserInputType.MouseButton2,
    aimToggled = false,
    aimHold = false,
    aimOnShoot = true,
    silentAim = false,
    showFov = true,
    fov = 120,
    smooth = 0.25,
    visibleCheck = true,
    hitPart = 1,
    teamCheck = false,
    targetPriority = 1,
    rebinding = nil,
    -- Rage
    ragebot = false,
    rageKey = Enum.KeyCode.X,
    rageMode = 2,
    rageToggled = false,
    rageHold = false,
    wallbang = false,
    autoFire = false,
    desyncOrbit = false,
    orbitRadius = 14,
    orbitSpeed = 6,
    barrierDisable = false,
    -- ESP
    espEnabled = false,
    espBoxes = false,
    espTracers = false,
    espNames = false,
    espHealth = false,
    espChams = false,
    espTags = true,
    espMaxDist = 2000,
    espColor = Color3.fromRGB(0, 170, 255),
    chamColor = Color3.fromRGB(255, 60, 120),
    -- Camera / chams
    thirdPerson = false,
    thirdPersonDist = 12,
    camFovOverride = false,
    camFov = 70,
    selfChams = false,
    selfChamColor = Color3.fromRGB(0, 140, 255),
    -- Triggerbot
    triggerbot = false,
    triggerDelay = 0.08,
    triggerRandom = 0.03,
    triggerMaxDist = 500,
    triggerRadius = 32,
    -- Extended ESP
    espSkeleton = false,
    espHeadCircle = false,
    espViewLine = false,
    espSnaplines = false,
    espOffscreen = false,
    espToolName = false,
    espTeamColor = false,
    espVisColor = false,
    espVisibleCol = Color3.fromRGB(80, 255, 120),
    espHiddenCol = Color3.fromRGB(255, 80, 80),
    -- Rage extras
    rageSpin = false,
    rageSpinSpeed = 18,
    rageSpeedBoost = false,
    rageSpeedMult = 2.5,
    -- Movement
    walkSpeed = false,
    walkSpeedVal = 24,
    jumpPower = false,
    jumpPowerVal = 50,
    fly = false,
    flySpeed = 80,
    noclip = false,
    -- Misc / UI
    priorityUserId = nil,
    hideWatermark = false,
    showFps = false,
    themeName = "Cobalt",
    autoSaveProfiles = false,
}

local Ref = {}
local Connections = {}
local ThemeParts = { toggles = {}, fills = {}, highlights = {}, tabs = {} }
local EspStore = {}
local DisabledBarriers = {}
local OrbitAngle = 0
local OrbitTarget = nil
local LastCombatCF = nil
local SavedOrbitZoomMin = nil
local SavedOrbitZoomMax = nil
local LastFire = 0
local LastCombat = 0
local DefaultFov = 70
local SelfHighlight = nil
local EspFolder = nil
local ScreenGui = nil
local OverlayGui = nil
local WindowOuter = nil
local WindowInner = nil
local FovRing = nil
local FovStroke = nil
local FovCircle = nil

local ToastGui = nil
local WmOuter = nil
local ProfileNameBox = nil
local ConfigStatusLbl = nil
local ProfileListFrame = nil
local PlayerListFrame = nil
local VisualSliders = {}
local VisualToggles = {}
local ConfigMeta = { lastProfile = "default", profiles = { "default" } }
local VisualState = {
    worldTintHue = 0, worldTintStrength = 0,
    saturation = 0, contrast = 0, brightness = 0,
    blurAmount = 0, bloomAmount = 0,
    fullbright = false, noShadows = false,
    clockOverride = false, clockTime = 14,
}
local OriginalLighting = {}
local VisualCC, VisualBlur, VisualBloom, ScreenTint = nil, nil, nil, nil
local DefaultWalkSpeed = 16
local DefaultJumpPower = 50
local DefaultGravity = workspace.Gravity
local SpinAngle = 0
local LastTrigger = 0
local NoclipParts = {}
local Stats = { fps = 0, fpsTick = 0, start = tick() }
local saveProfile, loadProfile, deleteProfile, refreshProfileList
local exportProfileToClipboard, importProfileFromClipboard
local applyVisualEffects, resetAllVisuals, syncVisualControls
local serializeSettings, applySettings
local updatePlayerList, rebuildPlayerList
local updateMovement, updateRageExtras
local triggerbotStep, notify, applyAccent, getThemeName


local FONT = Enum.Font.Code
local BLACK = Color3.new(0, 0, 0)
local MAIN = Color3.fromRGB(28, 28, 28)
local BG = Color3.fromRGB(20, 20, 20)
local OUTLINE = Color3.fromRGB(50, 50, 50)
local TEXT = Color3.fromRGB(255, 255, 255)
local Accent = ACCENTS.Cobalt

local DrawingLib = Drawing or (syn and syn.drawing) or (getgenv and getgenv().Drawing)
local HasDrawing = false
pcall(function()
    HasDrawing = type(DrawingLib) == "table" and type(DrawingLib.new) == "function"
end)

local mouseMoveRel = mousemoverel
local mouseMoveAbs = mousemoveabs
if not mouseMoveRel then
    pcall(function() mouseMoveRel = mousemoverel end)
end
if not mouseMoveAbs then
    pcall(function() mouseMoveAbs = mousemoveabs end)
end

if HasDrawing then
    pcall(function()
        FovCircle = DrawingLib.new("Circle")
        FovCircle.Thickness = 1
        FovCircle.NumSides = 64
        FovCircle.Filled = false
        FovCircle.Visible = false
    end)
end

function darker(c)
    local h, s, v = Color3.toHSV(c)
    return Color3.fromHSV(h, s, v / 1.5)
end

function clamp(n, lo, hi)
    return math.max(lo, math.min(hi, n))
end


-- ═══════════════════════════════════════════════════════════════
-- UTILITY LIBRARY
-- ═══════════════════════════════════════════════════════════════

function serializeColor(c)
    if typeof(c) ~= "Color3" then return { 255, 255, 255 } end
    return { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) }
end

function deserializeColor(t)
    if type(t) ~= "table" then return Color3.new(1, 1, 1) end
    return Color3.fromRGB(t[1] or 255, t[2] or 255, t[3] or 255)
end

function deepCopy(src)
    if type(src) ~= "table" then return src end
    local dst = {}
    for k, v in pairs(src) do dst[k] = deepCopy(v) end
    return dst
end

function tableMerge(base, extra)
    local out = deepCopy(base)
    if type(extra) == "table" then
        for k, v in pairs(extra) do out[k] = v end
    end
    return out
end

function fmtDist(m)
    if m >= 1000 then return string.format("%.1fkm", m / 1000) end
    return string.format("%dm", math.floor(m))
end

function fmtTime(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor(seconds % 3600 / 60)
    local s = math.floor(seconds % 60)
    return string.format("%02d:%02d:%02d", h, m, s)
end

function hueColor(h, s, v)
    return Color3.fromHSV(h % 1, s or 1, v or 1)
end

function lerpColor(a, b, t)
    t = clamp(t, 0, 1)
    return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end

function worldToScreen(pos)
    local cam = workspace.CurrentCamera
    if not cam then return nil, false end
    local sp, on = cam:WorldToViewportPoint(pos)
    return Vector2.new(sp.X, sp.Y), on and sp.Z > 0
end

function getRigType(char)
    if not char then return "Unknown" end
    if char:FindFirstChild("UpperTorso") then return "R15" end
    if char:FindFirstChild("Torso") then return "R6" end
    return "Unknown"
end

function getLimbPositions(char, bonePair)
    if not char or not bonePair then return nil, nil end
    local a = char:FindFirstChild(bonePair[1])
    local b = char:FindFirstChild(bonePair[2])
    if not a or not b then return nil, nil end
    return a.Position, b.Position
end

function getToolName(plr)
    local char = getChar(plr)
    if not char then return "" end
    local tool = char:FindFirstChildOfClass("Tool")
    return tool and tool.Name or "None"
end

function espColorFor(plr, visible)
    if St.espTeamColor and St.teamCheck and plr.Team and LocalPlayer.Team then
        if plr.Team == LocalPlayer.Team then
            return Color3.fromRGB(80, 255, 120)
        end
        return Color3.fromRGB(255, 80, 80)
    end
    if St.espVisColor then
        return visible and St.espVisibleCol or St.espHiddenCol
    end
    return St.espColor
end

function hasFileApi()
    return writefile and readfile and isfile
end

function sanitizeProfileName(name)
    name = string.gsub(string.lower(name or ""), "%s+", "-")
    name = string.gsub(name, "[^%w%-_]", "")
    if name == "" then return "default" end
    return name:sub(1, 32)
end

function ensureConfigDirs()
    if not makefolder then return end
    pcall(function()
        if isfolder and not isfolder(CONFIG_DIR) then makefolder(CONFIG_DIR) end
        if isfolder and not isfolder(PROFILES_DIR) then makefolder(PROFILES_DIR) end
    end)
end

function getThemeName()
    for name, color in pairs(ACCENTS) do
        if color == Accent then return name end
    end
    return St.themeName or "Cobalt"
end

function copyToClipboard(text)
    if setclipboard then setclipboard(text) return true end
    if toclipboard then toclipboard(text) return true end
    return false
end

function readClipboard()
    if getclipboard then return getclipboard() end
    if fromclipboard then return fromclipboard() end
    return nil
end

function getExecutorName()
    if identifyexecutor then
        local ok, n = pcall(identifyexecutor)
        if ok and n then return tostring(n) end
    end
    if syn then return "Synapse" end
    if fluxus then return "Fluxus" end
    return "Unknown"
end

function captureLightingDefaults()
    if OriginalLighting.captured then return end
    OriginalLighting = {
        captured = true,
        Ambient = Lighting.Ambient,
        OutdoorAmbient = Lighting.OutdoorAmbient,
        Brightness = Lighting.Brightness,
        ClockTime = Lighting.ClockTime,
        GlobalShadows = Lighting.GlobalShadows,
    }
end

captureLightingDefaults()

function connect(signal, fn)
    local c = signal:Connect(fn)
    Connections[#Connections + 1] = c
    return c
end

function textBounds(text, size)
    local s = TextService:GetTextSize(text, size, FONT, Vector2.new(1920, 1080))
    return s.X, s.Y
end

function passthrough(obj)
    obj.Active = false
end

function keyLabel(k)
    return k and tostring(k):gsub("Enum.KeyCode.", "") or "?"
end

function mouseBindLabel(t)
    if t == Enum.UserInputType.MouseButton1 then return "LMB" end
    if t == Enum.UserInputType.MouseButton2 then return "RMB" end
    if t == Enum.UserInputType.MouseButton3 then return "MMB" end
    return t and tostring(t):gsub("Enum.UserInputType.", "") or "?"
end

function aimBindLabel()
    if St.aimBindType == "mouse" then
        return mouseBindLabel(St.aimMouse)
    end
    return keyLabel(St.aimKey)
end

function inputMatchesAimBind(input)
    if St.aimBindType == "mouse" then
        return input.UserInputType == St.aimMouse
    end
    return input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == St.aimKey
end

function isMouseBindInput(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.MouseButton2
        or input.UserInputType == Enum.UserInputType.MouseButton3
end

function handleAimBindBegan()
    if not St.aimbot or rageActive() then return end
    if St.aimMode == 2 then
        St.aimToggled = not St.aimToggled
    elseif St.aimMode == 3 then
        St.aimHold = true
    end
    updateStatusLabels()
end

function handleAimBindEnded()
    if St.aimMode == 3 then
        St.aimHold = false
        updateStatusLabels()
    end
end

function refreshAimHoldState()
    if not St.aimbot or St.aimMode ~= 3 or rageActive() then return end
    if St.aimBindType == "mouse" then
        St.aimHold = UserInputService:IsMouseButtonPressed(St.aimMouse)
    else
        St.aimHold = UserInputService:IsKeyDown(St.aimKey)
    end
end

function getChar(plr)
    return plr and plr.Character
end

function getHum(char)
    return char and char:FindFirstChildOfClass("Humanoid")
end

function getRoot(char)
    return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
end

function getHitPart(char)
    if not char then return nil end
    local name = HIT_PARTS[St.hitPart] or "Head"
    return char:FindFirstChild(name) or char:FindFirstChild("Head") or getRoot(char)
end

function isEnemy(plr)
    if not plr or plr == LocalPlayer then return false end
    local char = getChar(plr)
    local hum = getHum(char)
    if not char or not hum or hum.Health <= 0 then return false end
    if St.teamCheck and plr.Team and LocalPlayer.Team and plr.Team == LocalPlayer.Team then
        return false
    end
    return true
end

function mousePos()
    return UserInputService:GetMouseLocation()
end

function isShooting()
    return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
        or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
end

function isFiring()
    return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
end

function rageActive()
    if not St.ragebot then return false end
    if St.rageMode == 1 then return true end
    if St.rageMode == 2 then return St.rageToggled end
    if St.rageMode == 3 then return St.rageHold end
    return false
end

function aimActive()
    if rageActive() then return true end
    if not St.aimbot then return false end
    if St.aimMode == 1 then return true end
    if St.aimMode == 2 then return St.aimToggled end
    if St.aimMode == 3 then return St.aimHold end
    return false
end

function canAim()
    if rageActive() then return true end
    if not aimActive() then return false end
    if St.silentAim then return isFiring() end
    if St.aimOnShoot and not isShooting() then return false end
    return true
end

function ignoreList()
    local t = {}
    if LocalPlayer.Character then
        t[#t + 1] = LocalPlayer.Character
    end
    if St.wallbang or rageActive() then
        for _, n in ipairs(MAP_FOLDERS) do
            local f = workspace:FindFirstChild(n)
            if f then t[#t + 1] = f end
        end
    end
    return t
end

function isVisible(origin, part, char)
    if not part then return false end
    local p = RaycastParams.new()
    p.FilterType = Enum.RaycastFilterType.Exclude
    p.FilterDescendantsInstances = ignoreList()
    p.IgnoreWater = true
    local hit = workspace:Raycast(origin, part.Position - origin, p)
    if not hit then return true end
    return hit.Instance:IsDescendantOf(char)
end

function screenDist(part)
    local cam = workspace.CurrentCamera
    if not cam or not part then return math.huge end
    local sp, on = cam:WorldToViewportPoint(part.Position)
    if not on or sp.Z < 0 then return math.huge end
    local mp = mousePos()
    return (Vector2.new(sp.X, sp.Y) - Vector2.new(mp.X, mp.Y)).Magnitude
end

function worldDist(plr, origin)
    local root = getRoot(getChar(plr))
    if not root or not origin then return math.huge end
    return (root.Position - origin).Magnitude
end

function bestTarget()
    local cam = workspace.CurrentCamera
    if not cam then return nil end
    if St.priorityUserId then
        local pri = Players:GetPlayerByUserId(St.priorityUserId)
        if pri and isEnemy(pri) then
            local part = getHitPart(getChar(pri))
            if part then
                local sd = screenDist(part)
                local maxFov = rageActive() and math.huge or St.fov
                if sd <= maxFov then return pri end
            end
        end
    end
    local maxFov = rageActive() and math.huge or St.fov
    local needVis = St.visibleCheck and not rageActive() and not (St.wallbang or rageActive())
    local myRoot = getRoot(getChar(LocalPlayer))
    local origin = myRoot and myRoot.Position or cam.CFrame.Position
    local best, bestScore = nil, math.huge
    local useDist = St.targetPriority == 2
    for _, plr in ipairs(Players:GetPlayers()) do
        if isEnemy(plr) then
            local part = getHitPart(getChar(plr))
            if part then
                local sd = rageActive() and 0 or screenDist(part)
                if sd <= maxFov then
                    if not needVis or isVisible(cam.CFrame.Position, part, getChar(plr)) then
                        local score = useDist and worldDist(plr, origin) or sd
                        if score < bestScore then
                            bestScore = score
                            best = plr
                        end
                    end
                end
            end
        end
    end
    return best
end


function getAimPoint()
    return UserInputService:GetMouseLocation()
end

function sendMouseDelta(dx, dy, absX, absY)
    local moved = false
    pcall(function()
        if mouseMoveRel then
            mouseMoveRel(dx, dy)
            moved = true
        elseif mouseMoveAbs and absX and absY then
            mouseMoveAbs(absX, absY)
            moved = true
        elseif VirtualInputManager then
            local mp = getAimPoint()
            VirtualInputManager:SendMouseMoveEvent(mp.X + dx, mp.Y + dy, game)
            moved = true
        end
    end)
    return moved
end

function aimAtTarget(part, snap)
    local cam = workspace.CurrentCamera
    if not cam or not part then return false end
    local targetPos = part.Position
    local instant = snap or rageActive() or St.silentAim

    local function aimViaMouse()
        local sp, on = cam:WorldToViewportPoint(targetPos)
        if not on or sp.Z < 0 then return false end
        local ap = getAimPoint()
        local dx, dy = sp.X - ap.X, sp.Y - ap.Y
        if math.abs(dx) < 0.25 and math.abs(dy) < 0.25 then return true end
        if instant then
            return sendMouseDelta(dx, dy, sp.X, sp.Y)
        end
        local sens = math.max(0.05, St.smooth) * 6
        return sendMouseDelta(dx / sens, dy / sens, ap.X + dx / sens, ap.Y + dy / sens)
    end

    -- Rage never snaps camera CFrame — that breaks mouse look / orbit view
    if rageActive() then
        return aimViaMouse()
    end

    if St.thirdPerson then
        return aimViaMouse()
    end

    local goal = CFrame.new(cam.CFrame.Position, targetPos)
    if instant then
        cam.CFrame = goal
    else
        local alpha = clamp(1 - St.smooth, 0.08, 1)
        cam.CFrame = cam.CFrame:Lerp(goal, alpha)
    end

    local sp, on = cam:WorldToViewportPoint(targetPos)
    if on and sp.Z > 0 then
        local ap = getAimPoint()
        local dx, dy = sp.X - ap.X, sp.Y - ap.Y
        if math.abs(dx) > 0.5 or math.abs(dy) > 0.5 then
            if instant then
                sendMouseDelta(dx, dy, sp.X, sp.Y)
            else
                local sens = math.max(0.05, St.smooth) * 6
                sendMouseDelta(dx / sens, dy / sens, ap.X + dx / sens, ap.Y + dy / sens)
            end
        end
    end
    return true
end

function fireClick()
    pcall(function()
        if mouse1click then
            mouse1click()
        else
            VirtualUser:ClickButton1(Vector2.new(0, 0))
        end
    end)
end

function disableBarriers()
    if not St.barrierDisable then return end
    for _, folderName in ipairs(BARRIER_FOLDERS) do
        local folder = workspace:FindFirstChild(folderName)
        if folder then
            for _, d in ipairs(folder:GetDescendants()) do
                if d:IsA("BasePart") and not DisabledBarriers[d] then
                    local n = string.lower(d.Name)
                    for _, kw in ipairs(BARRIER_KEYWORDS) do
                        if string.find(n, kw, 1, true) then
                            DisabledBarriers[d] = { CanTouch = d.CanTouch, CanCollide = d.CanCollide }
                            d.CanTouch = false
                            if string.find(n, "barrier", 1, true) or string.find(n, "kill", 1, true) then
                                d.CanCollide = false
                            end
                            break
                        end
                    end
                end
            end
        end
    end
end

function restoreBarriers()
    for part, state in pairs(DisabledBarriers) do
        if part and part.Parent then
            part.CanTouch = state.CanTouch
            if state.CanCollide ~= nil then
                part.CanCollide = state.CanCollide
            end
        end
    end
    table.clear(DisabledBarriers)
end

function rescanBarriers()
    restoreBarriers()
    if St.barrierDisable then
        disableBarriers()
    end
end

function ensureEspFolder()
    local cam = workspace.CurrentCamera
    if not cam then return nil end
    if EspFolder and EspFolder.Parent == cam then return EspFolder end
    local existing = cam:FindFirstChild("CobaltEsp")
    if existing then existing:Destroy() end
    EspFolder = Instance.new("Folder")
    EspFolder.Name = "CobaltEsp"
    EspFolder.Parent = cam
    return EspFolder
end

function newDraw(className, props)
    if not HasDrawing then return nil end
    local ok, o = pcall(function()
        local d = DrawingLib.new(className)
        for k, v in pairs(props or {}) do
            d[k] = v
        end
        return d
    end)
    return ok and o or nil
end

function hideEspDrawings(e)
    if not e then return end
    if e.box then for _, l in ipairs(e.box) do if l then l.Visible = false end end end
    if e.tracer then e.tracer.Visible = false end
    if e.name then e.name.Visible = false end
    if e.dist then e.dist.Visible = false end
    if e.hpBg then e.hpBg.Visible = false end
    if e.hpFg then e.hpFg.Visible = false end
    if e.headCircle then e.headCircle.Visible = false end
    if e.viewLine then e.viewLine.Visible = false end
    if e.snapline then e.snapline.Visible = false end
    if e.offscreenArrow then e.offscreenArrow.Visible = false end
    if e.skeleton then
        for _, l in ipairs(e.skeleton) do if l then l.Visible = false end end
    end
end

function clearEspEntry(plr)
    local e = EspStore[plr]
    if not e then return end
    if e.highlight then pcall(function() e.highlight:Destroy() end) end
    if e.billboard then pcall(function() e.billboard:Destroy() end) end
    hideEspDrawings(e)
    EspStore[plr] = nil
end

function clearAllEsp()
    for plr, _ in pairs(EspStore) do clearEspEntry(plr) end
    if EspFolder then pcall(function() EspFolder:Destroy() end) EspFolder = nil end
end

function ensureSkeletonLines(e, count)
    e.skeleton = e.skeleton or {}
    while #e.skeleton < count do
        e.skeleton[#e.skeleton + 1] = newDraw("Line", { Thickness = 1, Color = St.espColor, Visible = false })
    end
    for i = count + 1, #e.skeleton do
        if e.skeleton[i] then e.skeleton[i].Visible = false end
    end
end

function ensureEsp(plr)
    if EspStore[plr] then return EspStore[plr] end
    local e = {
        box = {},
        tracer = newDraw("Line", { Thickness = 1, Color = St.espColor, Visible = false }),
        name = newDraw("Text", { Size = 14, Center = true, Outline = true, Color = TEXT, Visible = false }),
        dist = newDraw("Text", { Size = 12, Center = true, Outline = true, Color = Color3.fromRGB(180, 180, 180), Visible = false }),
        hpBg = newDraw("Line", { Thickness = 4, Color = Color3.fromRGB(30, 30, 30), Visible = false }),
        hpFg = newDraw("Line", { Thickness = 3, Color = Color3.fromRGB(0, 255, 100), Visible = false }),
        headCircle = newDraw("Circle", { Radius = 8, Filled = false, Thickness = 1, Visible = false }),
        viewLine = newDraw("Line", { Thickness = 1, Visible = false }),
        snapline = newDraw("Line", { Thickness = 1, Visible = false }),
        offscreenArrow = newDraw("Triangle", { Filled = true, Visible = false }),
        skeleton = {},
    }
    for i = 1, 4 do
        e.box[i] = newDraw("Line", { Thickness = 1, Color = St.espColor, Visible = false })
    end
    EspStore[plr] = e
    return e
end

function ensureBillboard(e, char, plr)
    if e.billboard and e.billboard.Parent and e.billboard.Adornee then
        if e.bbTool and St.espToolName then
            e.bbTool.Text = getToolName(plr)
            e.bbTool.Visible = true
        elseif e.bbTool then
            e.bbTool.Visible = false
        end
        return
    end
    local head = char:FindFirstChild("Head") or getRoot(char)
    if not head then return end
    local folder = ensureEspFolder()
    if not folder then return end
    if e.billboard then e.billboard:Destroy() end

    local bb = Instance.new("BillboardGui")
    bb.Name = "CobaltTag_" .. plr.Name
    bb.Adornee = head
    bb.AlwaysOnTop = true
    bb.Size = UDim2.fromOffset(150, St.espToolName and 68 or 52)
    bb.StudsOffset = Vector3.new(0, 2.4, 0)
    bb.MaxDistance = St.espMaxDist
    bb.LightInfluence = 0
    bb.Parent = char

    local frame = Instance.new("Frame")
    frame.BackgroundTransparency = 1
    frame.Size = UDim2.fromScale(1, 1)
    frame.Parent = bb

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Name = "Name"
    nameLbl.BackgroundTransparency = 1
    nameLbl.Size = UDim2.new(1, 0, St.espToolName and 0.28 or 0.38, 0)
    nameLbl.Font = FONT
    nameLbl.TextSize = 14
    nameLbl.TextColor3 = St.espColor
    nameLbl.TextStrokeTransparency = 0.35
    nameLbl.Text = plr.DisplayName
    nameLbl.Parent = frame

    local distLbl = Instance.new("TextLabel")
    distLbl.Name = "Distance"
    distLbl.BackgroundTransparency = 1
    distLbl.Size = UDim2.new(1, 0, 0.24, 0)
    distLbl.Position = UDim2.new(0, 0, St.espToolName and 0.28 or 0.38, 0)
    distLbl.Font = FONT
    distLbl.TextSize = 12
    distLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
    distLbl.TextStrokeTransparency = 0.35
    distLbl.Text = ""
    distLbl.Parent = frame

    local hpLbl = Instance.new("TextLabel")
    hpLbl.Name = "Health"
    hpLbl.BackgroundTransparency = 1
    hpLbl.Size = UDim2.new(1, 0, 0.22, 0)
    hpLbl.Position = UDim2.new(0, 0, St.espToolName and 0.52 or 0.70, 0)
    hpLbl.Font = FONT
    hpLbl.TextSize = 11
    hpLbl.TextColor3 = Color3.fromRGB(100, 255, 130)
    hpLbl.TextStrokeTransparency = 0.35
    hpLbl.Text = ""
    hpLbl.Parent = frame

    local toolLbl = Instance.new("TextLabel")
    toolLbl.Name = "Tool"
    toolLbl.BackgroundTransparency = 1
    toolLbl.Size = UDim2.new(1, 0, 0.22, 0)
    toolLbl.Position = UDim2.new(0, 0, 0.74, 0)
    toolLbl.Font = FONT
    toolLbl.TextSize = 10
    toolLbl.TextColor3 = Color3.fromRGB(255, 200, 100)
    toolLbl.TextStrokeTransparency = 0.35
    toolLbl.Text = getToolName(plr)
    toolLbl.Visible = St.espToolName
    toolLbl.Parent = frame

    e.billboard = bb
    e.bbName = nameLbl
    e.bbDist = distLbl
    e.bbHealth = hpLbl
    e.bbTool = toolLbl
end

function ensureChams(e, char, col)
    col = col or St.chamColor
    if not St.espChams then
        if e.highlight then e.highlight:Destroy() e.highlight = nil end
        return
    end
    if e.highlight and e.highlight.Parent == char then
        e.highlight.FillColor = col
        return
    end
    if e.highlight then e.highlight:Destroy() end
    local h = Instance.new("Highlight")
    h.Name = "CobaltCham"
    h.Adornee = char
    h.FillColor = col
    h.OutlineColor = Color3.new(1, 1, 1)
    h.FillTransparency = 0.35
    h.OutlineTransparency = 0
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.Parent = char
    e.highlight = h
end

function drawLine(line, a, b, col, vis)
    if not line then return end
    line.From = a
    line.To = b
    if col then line.Color = col end
    line.Visible = vis
end

function drawBox(lines, tl, br, col, vis)
    if not lines[1] then return end
    local tr = Vector2.new(br.X, tl.Y)
    local bl = Vector2.new(tl.X, br.Y)
    drawLine(lines[1], tl, tr, col, vis)
    drawLine(lines[2], tr, br, col, vis)
    drawLine(lines[3], br, bl, col, vis)
    drawLine(lines[4], bl, tl, col, vis)
end

function drawOffscreenArrow(arrow, screenPos, vp, col)
    if not arrow then return end
    local cx, cy = vp.X / 2, vp.Y / 2
    local dir = (screenPos - Vector2.new(cx, cy))
    if dir.Magnitude < 1 then arrow.Visible = false return end
    dir = dir.Unit
    local pad = 28
    local edgeX = clamp(cx + dir.X * (vp.X / 2 - pad), pad, vp.X - pad)
    local edgeY = clamp(cy + dir.Y * (vp.Y / 2 - pad), pad, vp.Y - pad)
    local tip = Vector2.new(edgeX, edgeY)
    local perp = Vector2.new(-dir.Y, dir.X) * 10
    local back = tip - dir * 16
    arrow.PointA = tip
    arrow.PointB = back + perp
    arrow.PointC = back - perp
    arrow.Color = col
    arrow.Visible = true
end

function drawSkeleton(e, char, cam, col, vis)
    if not St.espSkeleton or not vis then
        if e.skeleton then for _, l in ipairs(e.skeleton) do if l then l.Visible = false end end end
        return
    end
    local bones = getRigType(char) == "R15" and R15_BONES or R6_BONES
    ensureSkeletonLines(e, #bones)
    for i, pair in ipairs(bones) do
        local pa, pb = getLimbPositions(char, pair)
        local line = e.skeleton[i]
        if pa and pb and line then
            local a, aOn = cam:WorldToViewportPoint(pa)
            local b, bOn = cam:WorldToViewportPoint(pb)
            if aOn and bOn and a.Z > 0 and b.Z > 0 then
                drawLine(line, Vector2.new(a.X, a.Y), Vector2.new(b.X, b.Y), col, true)
            elseif line then
                line.Visible = false
            end
        elseif line then
            line.Visible = false
        end
    end
end

function refreshEspForPlayer(plr)
    if not plr or plr == LocalPlayer then return end
    clearEspEntry(plr)
    if St.espEnabled or St.espChams then
        local char = getChar(plr)
        if char and isEnemy(plr) then
            local e = ensureEsp(plr)
            if St.espChams then ensureChams(e, char) end
            if St.espTags and St.espEnabled then ensureBillboard(e, char, plr) end
        end
    end
end

function hookPlayerEsp(plr)
    if plr == LocalPlayer then return end
    connect(plr.CharacterAdded, function(char)
        task.wait(0.35)
        refreshEspForPlayer(plr)
        local hum = getHum(char)
        if hum then
            connect(hum.Died, function()
                task.defer(function() clearEspEntry(plr) end)
            end)
        end
    end)
    if plr.Character then
        refreshEspForPlayer(plr)
        local hum = getHum(plr.Character)
        if hum then
            connect(hum.Died, function()
                task.defer(function() clearEspEntry(plr) end)
            end)
        end
    end
end

function updateEsp()
    if not St.espEnabled and not St.espChams then
        clearAllEsp()
        return
    end
    local cam = workspace.CurrentCamera
    if not cam then return end
    ensureEspFolder()
    local myRoot = getRoot(getChar(LocalPlayer))
    local origin = myRoot and myRoot.Position or cam.CFrame.Position
    local seen = {}
    local vp = cam.ViewportSize

    for _, plr in ipairs(Players:GetPlayers()) do
        if isEnemy(plr) then
            seen[plr] = true
            local char = getChar(plr)
            local root = getRoot(char)
            local hum = getHum(char)
            if char and root then
                local dist = (root.Position - origin).Magnitude
                if dist <= St.espMaxDist then
                    local e = ensureEsp(plr)
                    local head = char:FindFirstChild("Head") or root
                    local visible = isVisible(cam.CFrame.Position, head, char)
                    local col = espColorFor(plr, visible)

                    if St.espChams then
                        ensureChams(e, char, col)
                    elseif e.highlight then
                        e.highlight:Destroy()
                        e.highlight = nil
                    end

                    if St.espEnabled then
                        ensureBillboard(e, char, plr)
                        if e.bbName then
                            e.bbName.Text = plr.DisplayName
                            e.bbName.TextColor3 = col
                        end
                        if e.bbDist then e.bbDist.Text = fmtDist(dist) end
                        if e.bbHealth and hum then
                            local pct = clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                            e.bbHealth.Text = string.format("HP %d/%d", math.floor(hum.Health), math.floor(hum.MaxHealth))
                            e.bbHealth.TextColor3 = Color3.fromRGB(255 * (1 - pct), 255 * pct, 60)
                        end
                        if e.bbTool then
                            e.bbTool.Text = getToolName(plr)
                            e.bbTool.Visible = St.espToolName
                        end
                    elseif e.billboard then
                        e.billboard:Destroy()
                        e.billboard = nil
                        e.bbName, e.bbDist, e.bbHealth, e.bbTool = nil, nil, nil, nil
                    end

                    if St.espEnabled and HasDrawing then
                        local hPos, hOn = cam:WorldToViewportPoint(head.Position + Vector3.new(0, 0.8, 0))
                        local fPos, fOn = cam:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))
                        local onScreen = (hOn or fOn) and hPos.Z > 0

                        if St.espBoxes and onScreen then
                            local height = math.max(math.abs(fPos.Y - hPos.Y), 28)
                            local width = height * 0.55
                            local tl = Vector2.new(hPos.X - width / 2, hPos.Y)
                            local br = Vector2.new(hPos.X + width / 2, fPos.Y)
                            drawBox(e.box, tl, br, col, true)
                        else
                            drawBox(e.box, Vector2.zero, Vector2.zero, col, false)
                        end

                        local tracerFrom = St.espSnaplines and Vector2.new(vp.X / 2, vp.Y) or Vector2.new(vp.X / 2, vp.Y)
                        if St.espTracers and onScreen then
                            drawLine(e.tracer, tracerFrom, Vector2.new(fPos.X, fPos.Y), col, true)
                        elseif e.tracer then e.tracer.Visible = false end

                        if St.espSnaplines and onScreen and e.snapline then
                            drawLine(e.snapline, Vector2.new(vp.X / 2, vp.Y), Vector2.new(fPos.X, fPos.Y), col, true)
                        elseif e.snapline then e.snapline.Visible = false end

                        if St.espHeadCircle and onScreen and e.headCircle then
                            e.headCircle.Position = Vector2.new(hPos.X, hPos.Y)
                            e.headCircle.Color = col
                            e.headCircle.Visible = true
                        elseif e.headCircle then e.headCircle.Visible = false end

                        if St.espViewLine and onScreen and e.viewLine then
                            local look = head.CFrame.LookVector * 4
                            local lookPos, lookOn = cam:WorldToViewportPoint(head.Position + look)
                            if lookOn and lookPos.Z > 0 then
                                drawLine(e.viewLine, Vector2.new(hPos.X, hPos.Y), Vector2.new(lookPos.X, lookPos.Y), col, true)
                            else e.viewLine.Visible = false end
                        elseif e.viewLine then e.viewLine.Visible = false end

                        drawSkeleton(e, char, cam, col, onScreen)

                        if St.espOffscreen and not onScreen and e.offscreenArrow then
                            local sp, _ = cam:WorldToViewportPoint(root.Position)
                            drawOffscreenArrow(e.offscreenArrow, Vector2.new(sp.X, sp.Y), vp, col)
                        elseif e.offscreenArrow then e.offscreenArrow.Visible = false end

                        if St.espNames and not St.espTags and e.name then
                            e.name.Text = plr.DisplayName
                            e.name.Color = col
                            e.name.Position = Vector2.new(hPos.X, hPos.Y - 18)
                            e.name.Visible = onScreen
                        elseif e.name then e.name.Visible = false end

                        if St.espHealth and hum and onScreen then
                            local pct = clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                            local barY = fPos.Y + 10
                            drawLine(e.hpBg, Vector2.new(hPos.X - 28, barY), Vector2.new(hPos.X + 28, barY), nil, true)
                            drawLine(e.hpFg, Vector2.new(hPos.X - 28, barY), Vector2.new(hPos.X - 28 + 56 * pct, barY),
                                Color3.fromRGB(255 * (1 - pct), 255 * pct, 60), true)
                        else
                            if e.hpBg then e.hpBg.Visible = false end
                            if e.hpFg then e.hpFg.Visible = false end
                        end
                    end
                else
                    clearEspEntry(plr)
                end
            else
                clearEspEntry(plr)
            end
        else
            clearEspEntry(plr)
        end
    end

    for plr, _ in pairs(EspStore) do
        if not seen[plr] then clearEspEntry(plr) end
    end
end

function applyAccent(color)
    Accent = color
    for _, t in ipairs(ThemeParts.toggles) do
        if t.on then
            t.inner.BackgroundColor3 = Accent
            t.inner.BorderColor3 = darker(Accent)
        end
        t.outer.BorderColor3 = BLACK
    end
    for _, f in ipairs(ThemeParts.fills) do
        f.BackgroundColor3 = Accent
        f.BorderColor3 = darker(Accent)
    end
    for _, h in ipairs(ThemeParts.highlights) do
        h.BackgroundColor3 = Accent
    end
    for _, tab in pairs(ThemeParts.tabs) do
        tab.btnInner.BackgroundColor3 = tab.active and MAIN or BG
        tab.btnInner.BorderColor3 = tab.active and Accent or OUTLINE
    end
    if ThemeParts.windowInner then ThemeParts.windowInner.BorderColor3 = Accent end
    if ThemeParts.wmInner then ThemeParts.wmInner.BorderColor3 = Accent end
    if FovStroke then FovStroke.Color = Accent end
end

function notify(text, col)
    col = col or Accent
    if not ToastGui then
        ToastGui = Instance.new("ScreenGui")
        ToastGui.Name = "CobaltReduxToast"
        ToastGui.ResetOnSpawn = false
        ToastGui.IgnoreGuiInset = true
        ToastGui.DisplayOrder = 1001
        ToastGui.Parent = GuiParent
    end
    local toastOuter, toastInner = bordered(ToastGui, MAIN, col, UDim2.fromOffset(260, 36), UDim2.new(1, -280, 1, -50), 50)
    toastOuter.AnchorPoint = Vector2.new(0, 1)
    label(toastInner, text, 13, UDim2.fromOffset(6, 10), 52)
    task.delay(2.5, function()
        if toastOuter and toastOuter.Parent then toastOuter:Destroy() end
    end)
end

function setConfigStatus(msg)
    if ConfigStatusLbl then ConfigStatusLbl.Text = msg end
end

function readMeta()
    if not (hasFileApi() and isfile(META_PATH)) then return end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(META_PATH)) end)
    if ok and type(data) == "table" then
        ConfigMeta.lastProfile = data.lastProfile or ConfigMeta.lastProfile
        if type(data.profiles) == "table" then ConfigMeta.profiles = data.profiles end
    end
end

function writeMeta()
    if not writefile then return end
    pcall(writefile, META_PATH, HttpService:JSONEncode(ConfigMeta))
end

function registerProfile(name)
    name = sanitizeProfileName(name)
    for _, existing in ipairs(ConfigMeta.profiles) do
        if existing == name then
            ConfigMeta.lastProfile = name
            writeMeta()
            return name
        end
    end
    table.insert(ConfigMeta.profiles, name)
    ConfigMeta.lastProfile = name
    writeMeta()
    return name
end

function profilePath(name)
    return PROFILES_DIR .. "/" .. sanitizeProfileName(name) .. ".json"
end

function listProfileNames()
    local names, seen = {}, {}
    if listfiles and isfolder and isfolder(PROFILES_DIR) then
        for _, file in ipairs(listfiles(PROFILES_DIR)) do
            local n = file:match("([^/\\]+)%.json$")
            if n and not seen[n] then seen[n] = true table.insert(names, n) end
        end
    end
    for _, n in ipairs(ConfigMeta.profiles) do
        if not seen[n] then seen[n] = true table.insert(names, n) end
    end
    table.sort(names)
    return names
end

function keyCodeToName(k)
    if typeof(k) == "EnumItem" then return tostring(k):gsub("Enum.KeyCode.", "") end
    return nil
end

function mouseTypeToName(t)
    if typeof(t) == "EnumItem" then return tostring(t):gsub("Enum.UserInputType.", "") end
    return nil
end

function serializeSettings()
    return {
        version = 2,
        theme = getThemeName(),
        priorityUserId = St.priorityUserId,
        hideWatermark = St.hideWatermark,
        showFps = St.showFps,
        autoSaveProfiles = St.autoSaveProfiles,
        aimbot = St.aimbot, aimMode = St.aimMode,
        aimKey = keyCodeToName(St.aimKey), aimBindType = St.aimBindType,
        aimMouse = mouseTypeToName(St.aimMouse),
        aimOnShoot = St.aimOnShoot, silentAim = St.silentAim,
        showFov = St.showFov, fov = St.fov, smooth = St.smooth,
        visibleCheck = St.visibleCheck, hitPart = St.hitPart,
        teamCheck = St.teamCheck, targetPriority = St.targetPriority,
        ragebot = St.ragebot, rageKey = keyCodeToName(St.rageKey), rageMode = St.rageMode,
        wallbang = St.wallbang, autoFire = St.autoFire,
        desyncOrbit = St.desyncOrbit, orbitRadius = St.orbitRadius, orbitSpeed = St.orbitSpeed,
        barrierDisable = St.barrierDisable,
        rageSpin = St.rageSpin, rageSpinSpeed = St.rageSpinSpeed,
        rageSpeedBoost = St.rageSpeedBoost, rageSpeedMult = St.rageSpeedMult,
        triggerbot = St.triggerbot,
        triggerDelay = St.triggerDelay, triggerRandom = St.triggerRandom,
        triggerMaxDist = St.triggerMaxDist, triggerRadius = St.triggerRadius,
        espEnabled = St.espEnabled, espBoxes = St.espBoxes, espTracers = St.espTracers,
        espNames = St.espNames, espHealth = St.espHealth, espChams = St.espChams, espTags = St.espTags,
        espMaxDist = St.espMaxDist, espColor = serializeColor(St.espColor), chamColor = serializeColor(St.chamColor),
        espSkeleton = St.espSkeleton, espHeadCircle = St.espHeadCircle, espViewLine = St.espViewLine,
        espSnaplines = St.espSnaplines, espOffscreen = St.espOffscreen, espToolName = St.espToolName,
        espTeamColor = St.espTeamColor, espVisColor = St.espVisColor,
        espVisibleCol = serializeColor(St.espVisibleCol), espHiddenCol = serializeColor(St.espHiddenCol),
        thirdPerson = St.thirdPerson, thirdPersonDist = St.thirdPersonDist,
        camFovOverride = St.camFovOverride, camFov = St.camFov,
        selfChams = St.selfChams, selfChamColor = serializeColor(St.selfChamColor),
        walkSpeed = St.walkSpeed, walkSpeedVal = St.walkSpeedVal,
        jumpPower = St.jumpPower, jumpPowerVal = St.jumpPowerVal,
        fly = St.fly, flySpeed = St.flySpeed, noclip = St.noclip,
        visuals = deepCopy(VisualState),
    }
end

function applyKeyFromName(name, fallback)
    if not name then return fallback end
    local ok, k = pcall(function() return Enum.KeyCode[name] end)
    return ok and k or fallback
end

function applyMouseFromName(name, fallback)
    if not name then return fallback end
    local ok, t = pcall(function() return Enum.UserInputType[name] end)
    return ok and t or fallback
end

function applyBoolField(data, key, refToggle)
    if type(data[key]) == "boolean" then
        St[key] = data[key]
        if refToggle and refToggle.Set then refToggle.Set(St[key]) end
    end
end

function applyNumField(data, key, lo, hi, refSlider)
    if type(data[key]) == "number" then
        St[key] = clamp(data[key], lo, hi)
        if refSlider and refSlider.Set then refSlider.Set(St[key]) end
    end
end

function applySettings(data, opts)
    opts = opts or {}
    if type(data) ~= "table" then return false end
    if type(data.theme) == "string" and ACCENTS[data.theme] then
        St.themeName = data.theme
        applyAccent(ACCENTS[data.theme])
    end
    if data.priorityUserId ~= nil then St.priorityUserId = data.priorityUserId end
    applyBoolField(data, "hideWatermark", Ref.hideWmToggle)
    applyBoolField(data, "showFps", Ref.showFpsToggle)
    applyBoolField(data, "autoSaveProfiles", Ref.autoSaveToggle)
    applyBoolField(data, "aimbot", Ref.aimbotToggle)
    applyNumField(data, "aimMode", 1, 3)
    if type(data.aimKey) == "string" then St.aimKey = applyKeyFromName(data.aimKey, St.aimKey) end
    if type(data.aimBindType) == "string" then St.aimBindType = data.aimBindType end
    if type(data.aimMouse) == "string" then St.aimMouse = applyMouseFromName(data.aimMouse, St.aimMouse) end
    applyBoolField(data, "aimOnShoot")
    applyBoolField(data, "silentAim", Ref.silentToggle)
    applyBoolField(data, "showFov")
    applyNumField(data, "fov", 20, 400)
    applyNumField(data, "smooth", 0.05, 1)
    applyBoolField(data, "visibleCheck")
    applyNumField(data, "hitPart", 1, #HIT_PARTS)
    applyBoolField(data, "teamCheck")
    applyNumField(data, "targetPriority", 1, 2)
    applyBoolField(data, "ragebot", Ref.ragebotToggle)
    if type(data.rageKey) == "string" then St.rageKey = applyKeyFromName(data.rageKey, St.rageKey) end
    applyNumField(data, "rageMode", 1, 3)
    applyBoolField(data, "wallbang")
    applyBoolField(data, "autoFire")
    applyBoolField(data, "desyncOrbit")
    applyNumField(data, "orbitRadius", 4, 40)
    applyNumField(data, "orbitSpeed", 1, 20)
    applyBoolField(data, "barrierDisable")
    applyBoolField(data, "rageSpin", Ref.rageSpinToggle)
    applyNumField(data, "rageSpinSpeed", 2, 40)
    applyBoolField(data, "rageSpeedBoost", Ref.rageSpeedToggle)
    applyNumField(data, "rageSpeedMult", 1, 5)
    applyBoolField(data, "triggerbot", Ref.triggerToggle)
    applyNumField(data, "triggerDelay", 0, 1)
    applyNumField(data, "triggerRandom", 0, 0.5)
    applyNumField(data, "triggerMaxDist", 50, 2000)
    applyNumField(data, "triggerRadius", 8, 80)
    applyBoolField(data, "espEnabled", Ref.espEnableToggle)
    applyBoolField(data, "espBoxes")
    applyBoolField(data, "espTracers")
    applyBoolField(data, "espNames")
    applyBoolField(data, "espHealth")
    applyBoolField(data, "espChams")
    applyBoolField(data, "espTags")
    applyNumField(data, "espMaxDist", 100, 5000)
    if type(data.espColor) == "table" then St.espColor = deserializeColor(data.espColor) end
    if type(data.chamColor) == "table" then St.chamColor = deserializeColor(data.chamColor) end
    applyBoolField(data, "espSkeleton", Ref.espSkelToggle)
    applyBoolField(data, "espHeadCircle", Ref.espHeadToggle)
    applyBoolField(data, "espViewLine", Ref.espViewToggle)
    applyBoolField(data, "espSnaplines", Ref.espSnapToggle)
    applyBoolField(data, "espOffscreen", Ref.espOffToggle)
    applyBoolField(data, "espToolName", Ref.espToolToggle)
    applyBoolField(data, "espTeamColor", Ref.espTeamToggle)
    applyBoolField(data, "espVisColor", Ref.espVisToggle)
    if type(data.espVisibleCol) == "table" then St.espVisibleCol = deserializeColor(data.espVisibleCol) end
    if type(data.espHiddenCol) == "table" then St.espHiddenCol = deserializeColor(data.espHiddenCol) end
    applyBoolField(data, "thirdPerson")
    applyNumField(data, "thirdPersonDist", 4, 30)
    applyBoolField(data, "camFovOverride")
    applyNumField(data, "camFov", 30, 120)
    applyBoolField(data, "selfChams")
    if type(data.selfChamColor) == "table" then St.selfChamColor = deserializeColor(data.selfChamColor) end
    applyBoolField(data, "fly", Ref.flyToggle)
    applyNumField(data, "flySpeed", 20, 400)
    applyBoolField(data, "noclip", Ref.noclipToggle)
    if type(data.visuals) == "table" then
        for k, v in pairs(data.visuals) do
            if VisualState[k] ~= nil and type(v) == type(VisualState[k]) then VisualState[k] = v end
        end
        syncVisualControls()
    end
    if applyProfileBoolFields then applyProfileBoolFields(data) end
    if applyProfileNumFields then applyProfileNumFields(data) end
    updateStatusLabels()
    updatePlayerList()
    if Ref.featureCheckLbl then Ref.featureCheckLbl.Text = getFeatureChecklistText() end
    return true
end

refreshProfileList = function()
    if not ProfileListFrame then return end
    for _, child in ProfileListFrame:GetChildren() do
        if child:IsA("TextButton") then child:Destroy() end
    end
    for _, name in ipairs(listProfileNames()) do
        makeButton(ProfileListFrame, name, function()
            if ProfileNameBox then ProfileNameBox.Text = name end
            loadProfile(name)
        end)
    end
end

saveProfile = function(name)
    if not hasFileApi() then setConfigStatus("File API unavailable") notify("File API unavailable", Color3.fromRGB(255, 100, 100)) return false end
    ensureConfigDirs()
    name = registerProfile(name or (ProfileNameBox and ProfileNameBox.Text) or ConfigMeta.lastProfile)
    local ok = pcall(writefile, profilePath(name), HttpService:JSONEncode(serializeSettings()))
    if ok then
        if ProfileNameBox then ProfileNameBox.Text = name end
        refreshProfileList()
        setConfigStatus("Saved: " .. name)
        notify("Profile saved: " .. name, Color3.fromRGB(80, 255, 120))
    else
        setConfigStatus("Save failed")
        notify("Save failed", Color3.fromRGB(255, 100, 100))
    end
    return ok
end

loadProfile = function(name)
    if not hasFileApi() then setConfigStatus("File API unavailable") return false end
    name = sanitizeProfileName(name or (ProfileNameBox and ProfileNameBox.Text) or ConfigMeta.lastProfile)
    local path = profilePath(name)
    if not isfile(path) then setConfigStatus("Not found: " .. name) return false end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
    if not ok or not applySettings(data) then setConfigStatus("Load failed") return false end
    registerProfile(name)
    if ProfileNameBox then ProfileNameBox.Text = name end
    setConfigStatus("Loaded: " .. name)
    notify("Profile loaded: " .. name, Accent)
    return true
end

deleteProfile = function(name)
    if not hasFileApi() then return false end
    name = sanitizeProfileName(name or (ProfileNameBox and ProfileNameBox.Text) or "")
    if name == "" then return false end
    if delfile and isfile(profilePath(name)) then pcall(delfile, profilePath(name)) end
    for i, existing in ipairs(ConfigMeta.profiles) do
        if existing == name then table.remove(ConfigMeta.profiles, i) break end
    end
    if ConfigMeta.lastProfile == name then ConfigMeta.lastProfile = ConfigMeta.profiles[1] or "default" end
    writeMeta()
    refreshProfileList()
    setConfigStatus("Deleted: " .. name)
    notify("Deleted profile: " .. name, Color3.fromRGB(255, 180, 80))
    return true
end

exportProfileToClipboard = function()
    local json = HttpService:JSONEncode(serializeSettings())
    if copyToClipboard(json) then
        setConfigStatus("Exported to clipboard")
        notify("Config copied to clipboard", Accent)
        return true
    end
    setConfigStatus("Clipboard unavailable")
    return false
end

importProfileFromClipboard = function(saveAs)
    local raw = readClipboard()
    if not raw or raw == "" then setConfigStatus("Clipboard empty") return false end
    local ok, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok or not applySettings(data) then setConfigStatus("Import failed") return false end
    if saveAs then saveProfile(ProfileNameBox and ProfileNameBox.Text or "imported") end
    setConfigStatus("Imported from clipboard")
    notify("Imported from clipboard", Accent)
    return true
end

function crosshairTarget()
    local cam = workspace.CurrentCamera
    if not cam then return nil end
    local origin = cam.CFrame.Position
    local mp = mousePos()

    local ray = cam:ViewportPointToRay(mp.X, mp.Y)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { LocalPlayer.Character }
    params.IgnoreWater = true
    local hit = workspace:Raycast(ray.Origin, ray.Direction * St.triggerMaxDist, params)
    if hit then
        local model = hit.Instance:FindFirstAncestorOfClass("Model")
        if model then
            local plr = Players:GetPlayerFromCharacter(model)
            if plr and isEnemy(plr) then
                local part = hit.Instance:IsA("BasePart") and hit.Instance or getHitPart(model)
                if part and isVisible(origin, part, model) then
                    return plr
                end
            end
        end
    end

    local radius = St.triggerRadius or 32
    local best, bestDist = nil, radius
    for _, plr in ipairs(Players:GetPlayers()) do
        if isEnemy(plr) then
            local char = getChar(plr)
            local root = getRoot(char)
            if root then
                local wd = worldDist(plr, getRoot(getChar(LocalPlayer)) and getRoot(getChar(LocalPlayer)).Position or origin)
                if wd <= St.triggerMaxDist then
                    local part = getHitPart(char)
                    if part then
                        local sd = screenDist(part)
                        if sd <= bestDist and isVisible(origin, part, char) then
                            bestDist = sd
                            best = plr
                        end
                    end
                end
            end
        end
    end
    return best
end

function triggerbotStep()
    if not St.running or not St.triggerbot then return end
    if rageActive() then return end
    local target = crosshairTarget()
    if not target then return end
    local now = tick()
    local delay = St.triggerDelay + (math.random() * St.triggerRandom)
    if now - LastTrigger >= delay then
        LastTrigger = now
        fireClick()
    end
end

function setNoclip(on)
    local char = getChar(LocalPlayer)
    if not char then return end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then
            if on then
                if not NoclipParts[p] then NoclipParts[p] = p.CanCollide end
                p.CanCollide = false
            elseif NoclipParts[p] ~= nil then
                p.CanCollide = NoclipParts[p]
                NoclipParts[p] = nil
            end
        end
    end
end

function restoreMovement()
    local hum = getHum(getChar(LocalPlayer))
    if hum then
        hum.WalkSpeed = DefaultWalkSpeed
        hum.JumpPower = DefaultJumpPower
    end
    workspace.Gravity = DefaultGravity
    setNoclip(false)
    table.clear(NoclipParts)
    St.fly = false
end

function updateMovement(dt)
    local char = getChar(LocalPlayer)
    local hum = getHum(char)
    local root = getRoot(char)
    if not hum or not root then return end
    if St.noclip then setNoclip(true) else setNoclip(false) end
    if St.fly then
        local cam = workspace.CurrentCamera
        if not cam then return end
        local move = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then move -= cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move -= Vector3.new(0, 1, 0) end
        if move.Magnitude > 0 then
            root.Velocity = move.Unit * St.flySpeed
        else
            root.Velocity = Vector3.zero
        end
        hum:ChangeState(Enum.HumanoidStateType.Physics)
    end
end

function updateRageExtras(dt)
    if not rageActive() then return end
    local root = getRoot(getChar(LocalPlayer))
    local hum = getHum(getChar(LocalPlayer))
    if not root or not hum then return end
    if St.rageSpin then
        root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(St.rageSpinSpeed * dt * 60), 0)
    end
    if St.rageSpeedBoost then
        hum.WalkSpeed = DefaultWalkSpeed * St.rageSpeedMult
    end
end

function clearVisualEffects()
    if ScreenTint then ScreenTint.BackgroundTransparency = 1 end
    if VisualCC then
        VisualCC.Enabled = false
        VisualCC.TintColor = Color3.new(1, 1, 1)
        VisualCC.Saturation, VisualCC.Contrast, VisualCC.Brightness = 0, 0, 0
    end
    if VisualBlur then VisualBlur.Size = 0 end
    if VisualBloom then VisualBloom.Intensity = 0 end
    if OriginalLighting.captured then
        Lighting.Ambient = OriginalLighting.Ambient
        Lighting.OutdoorAmbient = OriginalLighting.OutdoorAmbient
        Lighting.Brightness = OriginalLighting.Brightness
        Lighting.ClockTime = OriginalLighting.ClockTime
        Lighting.GlobalShadows = OriginalLighting.GlobalShadows
    end
end

function anyVisualsActive()
    return VisualState.worldTintStrength > 0 or VisualState.saturation ~= 0
        or VisualState.contrast ~= 0 or VisualState.brightness ~= 0
        or VisualState.blurAmount > 0 or VisualState.bloomAmount > 0
        or VisualState.fullbright or VisualState.noShadows or VisualState.clockOverride
end

applyVisualEffects = function()
    if not anyVisualsActive() then clearVisualEffects() return end
    captureLightingDefaults()
    if not VisualCC then
        VisualCC = Instance.new("ColorCorrectionEffect")
        VisualCC.Name = "CobaltReduxCC"
        VisualCC.Parent = Lighting
    end
    if not VisualBlur then
        VisualBlur = Instance.new("BlurEffect")
        VisualBlur.Name = "CobaltReduxBlur"
        VisualBlur.Parent = Lighting
    end
    if not VisualBloom then
        VisualBloom = Instance.new("BloomEffect")
        VisualBloom.Name = "CobaltReduxBloom"
        VisualBloom.Parent = Lighting
    end
    if not ScreenTint and OverlayGui then
        ScreenTint = Instance.new("Frame")
        ScreenTint.Name = "WorldTint"
        ScreenTint.Size = UDim2.fromScale(1, 1)
        ScreenTint.BackgroundTransparency = 1
        ScreenTint.BorderSizePixel = 0
        ScreenTint.Active = false
        ScreenTint.ZIndex = 0
        ScreenTint.Parent = OverlayGui
    end
    local tint = hueColor(VisualState.worldTintHue, 0.95, 1)
    if ScreenTint and VisualState.worldTintStrength > 0 then
        ScreenTint.BackgroundColor3 = tint
        ScreenTint.BackgroundTransparency = 1 - clamp(VisualState.worldTintStrength, 0, 0.85)
    elseif ScreenTint then ScreenTint.BackgroundTransparency = 1 end
    VisualCC.Enabled = true
    VisualCC.TintColor = tint
    VisualCC.Saturation = clamp(VisualState.saturation, -1, 1)
    VisualCC.Contrast = clamp(VisualState.contrast, -1, 1)
    VisualCC.Brightness = clamp(VisualState.brightness, -1, 1)
    VisualBlur.Size = VisualState.blurAmount > 0 and clamp(VisualState.blurAmount, 0, 56) or 0
    VisualBloom.Intensity = VisualState.bloomAmount > 0 and clamp(VisualState.bloomAmount, 0, 2) or 0
    if VisualState.fullbright then
        Lighting.Ambient = Color3.new(1, 1, 1)
        Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
        Lighting.Brightness = 2.5
        Lighting.GlobalShadows = false
    elseif OriginalLighting.captured then
        Lighting.Ambient = OriginalLighting.Ambient
        Lighting.OutdoorAmbient = OriginalLighting.OutdoorAmbient
        Lighting.Brightness = OriginalLighting.Brightness
        Lighting.GlobalShadows = VisualState.noShadows and false or OriginalLighting.GlobalShadows
    end
    if VisualState.noShadows and not VisualState.fullbright then Lighting.GlobalShadows = false end
    if VisualState.clockOverride then Lighting.ClockTime = VisualState.clockTime
    elseif OriginalLighting.captured then Lighting.ClockTime = OriginalLighting.ClockTime end
end

syncVisualControls = function()
    for key, slider in pairs(VisualSliders) do
        if VisualState[key] ~= nil and slider.Set then slider.Set(VisualState[key]) end
    end
    for key, toggle in pairs(VisualToggles) do
        if VisualState[key] ~= nil and toggle.Set then toggle.Set(VisualState[key]) end
    end
end

resetAllVisuals = function()
    VisualState.worldTintHue = 0
    VisualState.worldTintStrength = 0
    VisualState.saturation = 0
    VisualState.contrast = 0
    VisualState.brightness = 0
    VisualState.blurAmount = 0
    VisualState.bloomAmount = 0
    VisualState.fullbright = false
    VisualState.noShadows = false
    VisualState.clockOverride = false
    VisualState.clockTime = 14
    syncVisualControls()
    clearVisualEffects()
end

function updatePlayerList()
    if not PlayerListFrame then return end
    local cam = workspace.CurrentCamera
    local myRoot = getRoot(getChar(LocalPlayer))
    local origin = myRoot and myRoot.Position or (cam and cam.CFrame.Position)
    for _, row in ipairs(PlayerListFrame:GetChildren()) do
        if row:IsA("TextButton") and row:GetAttribute("UserId") then
            local plr = Players:GetPlayerByUserId(row:GetAttribute("UserId"))
            if plr and plr ~= LocalPlayer then
                local hum = getHum(getChar(plr))
                local dist = origin and worldDist(plr, origin) or 0
                local hp = hum and string.format("%d/%d", math.floor(hum.Health), math.floor(hum.MaxHealth)) or "?"
                local pri = St.priorityUserId == plr.UserId and " [PRI]" or ""
                row.Text = string.format("  %s  %s  %s%s", plr.DisplayName, fmtDist(dist), hp, pri)
                row.TextColor3 = St.priorityUserId == plr.UserId and Accent or TEXT
            end
        end
    end
end

function rebuildPlayerList()
    if not PlayerListFrame then return end
    for _, c in ipairs(PlayerListFrame:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, 0, 0, 20)
            btn.BackgroundColor3 = BG
            btn.BorderColor3 = OUTLINE
            btn.BorderSizePixel = 1
            btn.AutoButtonColor = false
            btn.Font = FONT
            btn.TextSize = 12
            btn.TextXAlignment = Enum.TextXAlignment.Left
            btn.TextColor3 = TEXT
            btn:SetAttribute("UserId", plr.UserId)
            btn.Parent = PlayerListFrame
            btn.MouseButton1Click:Connect(function()
                if St.priorityUserId == plr.UserId then
                    St.priorityUserId = nil
                    notify("Priority cleared", Color3.fromRGB(200, 200, 200))
                else
                    St.priorityUserId = plr.UserId
                    notify("Priority: " .. plr.DisplayName, Accent)
                end
                updatePlayerList()
            end)
        end
    end
    updatePlayerList()
end

function updateFov()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local show = St.showFov
    local cx, cy = cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2
    local r = St.fov

    if FovCircle then
        FovCircle.Visible = show
        if show then
            FovCircle.Position = Vector2.new(cx, cy)
            FovCircle.Radius = r
            FovCircle.Color = Accent
            FovCircle.Transparency = 0.35
        end
    end

    if FovRing then
        FovRing.Visible = show
        if show then
            FovRing.Size = UDim2.fromOffset(r * 2, r * 2)
            FovRing.Position = UDim2.fromOffset(cx, cy)
            if FovStroke then
                FovStroke.Color = Accent
            end
        end
    end
end

function updateSelfChams()
    local char = getChar(LocalPlayer)
    if St.selfChams and char then
        if not SelfHighlight or SelfHighlight.Parent ~= char then
            if SelfHighlight then SelfHighlight:Destroy() end
            SelfHighlight = Instance.new("Highlight")
            SelfHighlight.Name = "CobaltSelfCham"
            SelfHighlight.Adornee = char
            SelfHighlight.FillColor = St.selfChamColor
            SelfHighlight.OutlineColor = Color3.new(1, 1, 1)
            SelfHighlight.FillTransparency = 0.3
            SelfHighlight.OutlineTransparency = 0
            SelfHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            SelfHighlight.Parent = char
        else
            SelfHighlight.FillColor = St.selfChamColor
        end
    elseif SelfHighlight then
        SelfHighlight:Destroy()
        SelfHighlight = nil
    end
end

function updateThirdPerson()
    if not St.thirdPerson then return end
    local cam = workspace.CurrentCamera
    local root = getRoot(getChar(LocalPlayer))
    if not cam or not root then return end
    cam.CameraType = Enum.CameraType.Scriptable
    local back = root.CFrame.LookVector * -St.thirdPersonDist
    cam.CFrame = CFrame.new(root.Position + Vector3.new(0, 2, 0) + back, root.Position + Vector3.new(0, 1.5, 0))
end

function lockOrbitTarget()
    if OrbitTarget and isEnemy(OrbitTarget) then
        return OrbitTarget
    end
    OrbitTarget = bestTarget()
    OrbitAngle = 0
    return OrbitTarget
end

function getRageTarget()
    if not rageActive() then return nil end
    if OrbitTarget and isEnemy(OrbitTarget) then
        return OrbitTarget
    end
    local next = lockOrbitTarget()
    if next and Ref.rageBanner then
        notify("New target: " .. next.DisplayName, Color3.fromRGB(255, 160, 80))
    end
    return next
end

function clearOrbitTarget()
    OrbitTarget = nil
    OrbitAngle = 0
    LastCombatCF = nil
    disableRageOrbitView()
end

function enableRageOrbitView()
    local hum = getHum(getChar(LocalPlayer))
    local cam = workspace.CurrentCamera
    if hum then
        if SavedOrbitZoomMin == nil then
            SavedOrbitZoomMin = hum.CameraMinZoomDistance
            SavedOrbitZoomMax = hum.CameraMaxZoomDistance
        end
        local dist = math.max(St.thirdPersonDist, 10)
        hum.CameraMinZoomDistance = dist
        hum.CameraMaxZoomDistance = dist
    end
    if cam then
        cam.CameraType = Enum.CameraType.Custom
        if hum then cam.CameraSubject = hum end
    end
end

function disableRageOrbitView()
    local hum = getHum(getChar(LocalPlayer))
    if hum and SavedOrbitZoomMin ~= nil then
        hum.CameraMinZoomDistance = SavedOrbitZoomMin
        hum.CameraMaxZoomDistance = SavedOrbitZoomMax
        SavedOrbitZoomMin = nil
        SavedOrbitZoomMax = nil
    end
    restoreCamera()
end

function restoreCamera()
    local cam = workspace.CurrentCamera
    if not cam then return end
    if St.camFovOverride then
        cam.FieldOfView = St.camFov
    else
        cam.FieldOfView = DefaultFov
    end
    if not St.thirdPerson then
        local hum = getHum(getChar(LocalPlayer))
        if hum and cam.CameraType == Enum.CameraType.Scriptable then
            cam.CameraType = Enum.CameraType.Custom
            cam.CameraSubject = hum
        end
    end
end

function updateOrbit(dt)
    if not rageActive() then
        disableRageOrbitView()
        return
    end

    if not St.desyncOrbit then
        disableRageOrbitView()
        return
    end

    enableRageOrbitView()

    local myRoot = getRoot(getChar(LocalPlayer))
    if not myRoot then return end

    local target = getRageTarget()
    if not target then return end

    local tRoot = getRoot(getChar(target))
    if not tRoot then return end

    OrbitAngle = OrbitAngle + St.orbitSpeed * dt
    local off = Vector3.new(math.cos(OrbitAngle), 1.2, math.sin(OrbitAngle)) * St.orbitRadius
    LastCombatCF = CFrame.new(tRoot.Position + off, tRoot.Position)
    myRoot.CFrame = LastCombatCF
    myRoot.AssemblyLinearVelocity = Vector3.zero
    myRoot.AssemblyAngularVelocity = Vector3.zero
end

function aimStatusText()
    if rageActive() then return "RAGE", Color3.fromRGB(255, 120, 80) end
    if not St.aimbot then return "OFF", Color3.fromRGB(255, 90, 90) end
    if St.aimMode == 1 then return "ON", Color3.fromRGB(80, 255, 120) end
    if St.aimToggled or St.aimHold then return "ON", Color3.fromRGB(80, 255, 120) end
    return "OFF", Color3.fromRGB(255, 90, 90)
end

function rageStatusText()
    if not St.ragebot then return "OFF", Color3.fromRGB(255, 90, 90) end
    if St.rageMode == 1 then return "ON", Color3.fromRGB(255, 100, 100) end
    if St.rageToggled or St.rageHold then return "ON", Color3.fromRGB(255, 100, 100) end
    return "OFF", Color3.fromRGB(255, 90, 90)
end

function updateStatusLabels()
    if Ref.aimKeyLbl then
        Ref.aimKeyLbl.Text = "Aim Hold Key: [" .. aimBindLabel() .. "]"
    end
    if Ref.aimStatus then
        local t, c = aimStatusText()
        Ref.aimStatus.Text = t
        Ref.aimStatus.TextColor3 = c
    end
    if Ref.aimModeLbl then
        Ref.aimModeLbl.Text = "Activation: " .. (AIM_MODES[St.aimMode] or "?")
    end
    if Ref.aimBindHelp then
        if St.aimMode == 1 then
            Ref.aimBindHelp.Text = "Aim locks whenever Aimbot is enabled (no key)"
        elseif St.aimMode == 2 then
            Ref.aimBindHelp.Text = "Press [" .. aimBindLabel() .. "] to toggle aim on/off"
        else
            Ref.aimBindHelp.Text = "Hold [" .. aimBindLabel() .. "] to lock onto targets"
        end
    end
    if Ref.visCheckLbl then
        Ref.visCheckLbl.Text = "Visible Check: " .. (St.visibleCheck and "ON" or "OFF")
        Ref.visCheckLbl.TextColor3 = St.visibleCheck and Color3.fromRGB(80, 255, 120) or Color3.fromRGB(160, 160, 160)
    end
    if Ref.silentLbl then
        Ref.silentLbl.Text = "Silent Aim: " .. (St.silentAim and "ON (LMB)" or "OFF")
        Ref.silentLbl.TextColor3 = St.silentAim and Color3.fromRGB(80, 255, 120) or Color3.fromRGB(160, 160, 160)
    end

    if Ref.rageKeyLbl then
        Ref.rageKeyLbl.Text = "Rage Key: [" .. keyLabel(St.rageKey) .. "]"
    end
    if Ref.rageStatus then
        local t, c = rageStatusText()
        Ref.rageStatus.Text = t
        Ref.rageStatus.TextColor3 = c
    end
    if Ref.rageModeLbl then
        Ref.rageModeLbl.Text = "Rage Mode: " .. (AIM_MODES[St.rageMode] or "?")
    end

    if Ref.rageBanner then
        local parts = {}
        if rageActive() then parts[#parts + 1] = "RAGEBOT ACTIVE" end
        if rageActive() and OrbitTarget and isEnemy(OrbitTarget) then
            parts[#parts + 1] = "LOCK: " .. OrbitTarget.DisplayName
        end
        if St.wallbang and rageActive() then parts[#parts + 1] = "WALLBANG" end
        if St.autoFire and rageActive() then parts[#parts + 1] = "AUTO FIRE" end
        if St.desyncOrbit and rageActive() then parts[#parts + 1] = "ORBIT VIEW" end
        if St.barrierDisable then parts[#parts + 1] = "BARRIERS OFF" end
        Ref.rageBanner.Text = #parts > 0
            and table.concat(parts, "  |  ")
            or "No rage features active — enable toggles below, press [" .. keyLabel(St.rageKey) .. "] to toggle ragebot"
    end

    if Ref.espStatus then
        local mode = HasDrawing and "Drawing + Tags" or "Tags/Chams only"
        Ref.espStatus.Text = "ESP: " .. (St.espEnabled and "ON" or "OFF") .. "  (" .. mode .. ")"
        Ref.espStatus.TextColor3 = St.espEnabled and Color3.fromRGB(80, 255, 120) or Color3.fromRGB(160, 160, 160)
    end

    if Ref.drawingStatus then
        Ref.drawingStatus.Text = HasDrawing and "Drawing API: available" or "Drawing API: unavailable (GUI ring + Billboard ESP active)"
    end
    if Ref.featureCheckLbl and getFeatureChecklistText then
        Ref.featureCheckLbl.Text = getFeatureChecklistText()
    end
end

function combatStep()
    if not St.running then return end

    if rageActive() then
        local target = getRageTarget()
        if target then
            aimAtTarget(getHitPart(getChar(target)), true)
        end
        local now = tick()
        if now - LastFire >= 1 / 30 then
            LastFire = now
            fireClick()
        end
        return
    end

    if not aimActive() then return end
    local target = bestTarget()
    if canAim() and target then
        aimAtTarget(getHitPart(getChar(target)), false)
    end
end

function silentAimStep()
    if not St.running or not St.silentAim then return end
    if not isFiring() then return end
    local target = bestTarget()
    if not target then return end
    local part = getHitPart(getChar(target))
    if part then
        aimAtTarget(part, true)
    end
end

function unload()
    St.running = false
    clearOrbitTarget()
    disableRageOrbitView()
    restoreBarriers()
    clearAllEsp()
    resetAllVisuals()
    restoreMovement()
    if SelfHighlight then SelfHighlight:Destroy() SelfHighlight = nil end
    if VisualCC then pcall(function() VisualCC:Destroy() end) VisualCC = nil end
    if VisualBlur then pcall(function() VisualBlur:Destroy() end) VisualBlur = nil end
    if VisualBloom then pcall(function() VisualBloom:Destroy() end) VisualBloom = nil end
    if ScreenTint then pcall(function() ScreenTint:Destroy() end) ScreenTint = nil end
    if FovCircle then pcall(function() FovCircle:Remove() end) FovCircle = nil end
    if ToastGui then ToastGui:Destroy() ToastGui = nil end
    if OverlayGui then OverlayGui:Destroy() end
    if ScreenGui then ScreenGui:Destroy() end
    for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
    table.clear(Connections)
    print("[Cobalt Redux] Unloaded.")
end

-- ═══════════════════════════════════════════════════════════════
-- PROFILE SERIALIZATION HELPERS (extended field registry)
-- ═══════════════════════════════════════════════════════════════
local PROFILE_BOOL_FIELDS = {
    "aimbot",
    "aimOnShoot",
    "silentAim",
    "showFov",
    "visibleCheck",
    "teamCheck",
    "ragebot",
    "wallbang",
    "autoFire",
    "desyncOrbit",
    "barrierDisable",
    "rageSpin",
    "rageSpeedBoost",
    "triggerbot",
    "espEnabled",
    "espBoxes",
    "espTracers",
    "espNames",
    "espHealth",
    "espChams",
    "espTags",
    "espSkeleton",
    "espHeadCircle",
    "espViewLine",
    "espSnaplines",
    "espOffscreen",
    "espToolName",
    "espTeamColor",
    "espVisColor",
    "thirdPerson",
    "camFovOverride",
    "selfChams",
    "walkSpeed",
    "jumpPower",
    "fly",
    "noclip",
    "hideWatermark",
    "showFps",
    "autoSaveProfiles",
}

local PROFILE_NUM_FIELDS = {
    { name = "aimMode", min = 1, max = 3 },
    { name = "fov", min = 20, max = 400 },
    { name = "smooth", min = 0.05, max = 1 },
    { name = "hitPart", min = 1, max = 4 },
    { name = "targetPriority", min = 1, max = 2 },
    { name = "rageMode", min = 1, max = 3 },
    { name = "orbitRadius", min = 4, max = 40 },
    { name = "orbitSpeed", min = 1, max = 20 },
    { name = "rageSpinSpeed", min = 2, max = 40 },
    { name = "rageSpeedMult", min = 1, max = 5 },
    { name = "triggerDelay", min = 0, max = 1 },
    { name = "triggerRandom", min = 0, max = 0.5 },
    { name = "triggerMaxDist", min = 50, max = 2000 },
    { name = "triggerRadius", min = 8, max = 80 },
    { name = "espMaxDist", min = 100, max = 5000 },
    { name = "thirdPersonDist", min = 4, max = 30 },
    { name = "camFov", min = 30, max = 120 },
    { name = "walkSpeedVal", min = 16, max = 200 },
    { name = "jumpPowerVal", min = 20, max = 200 },
    { name = "flySpeed", min = 20, max = 400 },
}

function applyProfileBoolFields(data)
    for _, key in ipairs(PROFILE_BOOL_FIELDS) do
        if type(data[key]) == "boolean" then St[key] = data[key] end
    end
end

function applyProfileNumFields(data)
    for _, spec in ipairs(PROFILE_NUM_FIELDS) do
        local key = spec.name
        if type(data[key]) == "number" then
            St[key] = clamp(data[key], spec.min, spec.max)
        end
    end
end

function describeProfileField(key)
    if St[key] == nil then return key .. "=nil" end
    return key .. "=" .. tostring(St[key])
end

function dumpProfileSummary()
    local parts = {}
    if St.aimbot then parts[#parts + 1] = "aimbot" end
    if St.aimOnShoot then parts[#parts + 1] = "aimOnShoot" end
    if St.silentAim then parts[#parts + 1] = "silentAim" end
    if St.showFov then parts[#parts + 1] = "showFov" end
    if St.visibleCheck then parts[#parts + 1] = "visibleCheck" end
    if St.teamCheck then parts[#parts + 1] = "teamCheck" end
    if St.ragebot then parts[#parts + 1] = "ragebot" end
    if St.wallbang then parts[#parts + 1] = "wallbang" end
    if St.autoFire then parts[#parts + 1] = "autoFire" end
    if St.desyncOrbit then parts[#parts + 1] = "desyncOrbit" end
    if St.barrierDisable then parts[#parts + 1] = "barrierDisable" end
    if St.rageSpin then parts[#parts + 1] = "rageSpin" end
    if St.rageSpeedBoost then parts[#parts + 1] = "rageSpeedBoost" end
    if St.triggerbot then parts[#parts + 1] = "triggerbot" end
    if St.espEnabled then parts[#parts + 1] = "espEnabled" end
    if St.espBoxes then parts[#parts + 1] = "espBoxes" end
    if St.espTracers then parts[#parts + 1] = "espTracers" end
    if St.espNames then parts[#parts + 1] = "espNames" end
    if St.espHealth then parts[#parts + 1] = "espHealth" end
    if St.espChams then parts[#parts + 1] = "espChams" end
    if St.espTags then parts[#parts + 1] = "espTags" end
    if St.espSkeleton then parts[#parts + 1] = "espSkeleton" end
    if St.espHeadCircle then parts[#parts + 1] = "espHeadCircle" end
    if St.espViewLine then parts[#parts + 1] = "espViewLine" end
    if St.espSnaplines then parts[#parts + 1] = "espSnaplines" end
    if St.espOffscreen then parts[#parts + 1] = "espOffscreen" end
    if St.espToolName then parts[#parts + 1] = "espToolName" end
    if St.espTeamColor then parts[#parts + 1] = "espTeamColor" end
    if St.espVisColor then parts[#parts + 1] = "espVisColor" end
    if St.thirdPerson then parts[#parts + 1] = "thirdPerson" end
    if St.camFovOverride then parts[#parts + 1] = "camFovOverride" end
    if St.selfChams then parts[#parts + 1] = "selfChams" end
    if St.walkSpeed then parts[#parts + 1] = "walkSpeed" end
    if St.jumpPower then parts[#parts + 1] = "jumpPower" end
    if St.fly then parts[#parts + 1] = "fly" end
    if St.noclip then parts[#parts + 1] = "noclip" end
    if St.hideWatermark then parts[#parts + 1] = "hideWatermark" end
    if St.showFps then parts[#parts + 1] = "showFps" end
    if St.autoSaveProfiles then parts[#parts + 1] = "autoSaveProfiles" end
    return table.concat(parts, ", ")
end

function profileFieldCount() return 0 end

function getProfile_aimbot() return St.aimbot end
function setProfile_aimbot(v) if type(v) == "boolean" then St.aimbot = v end end
function getProfile_aimOnShoot() return St.aimOnShoot end
function setProfile_aimOnShoot(v) if type(v) == "boolean" then St.aimOnShoot = v end end
function getProfile_silentAim() return St.silentAim end
function setProfile_silentAim(v) if type(v) == "boolean" then St.silentAim = v end end
function getProfile_showFov() return St.showFov end
function setProfile_showFov(v) if type(v) == "boolean" then St.showFov = v end end
function getProfile_visibleCheck() return St.visibleCheck end
function setProfile_visibleCheck(v) if type(v) == "boolean" then St.visibleCheck = v end end
function getProfile_teamCheck() return St.teamCheck end
function setProfile_teamCheck(v) if type(v) == "boolean" then St.teamCheck = v end end
function getProfile_ragebot() return St.ragebot end
function setProfile_ragebot(v) if type(v) == "boolean" then St.ragebot = v end end
function getProfile_wallbang() return St.wallbang end
function setProfile_wallbang(v) if type(v) == "boolean" then St.wallbang = v end end
function getProfile_autoFire() return St.autoFire end
function setProfile_autoFire(v) if type(v) == "boolean" then St.autoFire = v end end
function getProfile_desyncOrbit() return St.desyncOrbit end
function setProfile_desyncOrbit(v) if type(v) == "boolean" then St.desyncOrbit = v end end
function getProfile_barrierDisable() return St.barrierDisable end
function setProfile_barrierDisable(v) if type(v) == "boolean" then St.barrierDisable = v end end
function getProfile_rageSpin() return St.rageSpin end
function setProfile_rageSpin(v) if type(v) == "boolean" then St.rageSpin = v end end
function getProfile_rageSpeedBoost() return St.rageSpeedBoost end
function setProfile_rageSpeedBoost(v) if type(v) == "boolean" then St.rageSpeedBoost = v end end
function getProfile_triggerbot() return St.triggerbot end
function setProfile_triggerbot(v) if type(v) == "boolean" then St.triggerbot = v end end
function getProfile_espEnabled() return St.espEnabled end
function setProfile_espEnabled(v) if type(v) == "boolean" then St.espEnabled = v end end
function getProfile_espBoxes() return St.espBoxes end
function setProfile_espBoxes(v) if type(v) == "boolean" then St.espBoxes = v end end
function getProfile_espTracers() return St.espTracers end
function setProfile_espTracers(v) if type(v) == "boolean" then St.espTracers = v end end
function getProfile_espNames() return St.espNames end
function setProfile_espNames(v) if type(v) == "boolean" then St.espNames = v end end
function getProfile_espHealth() return St.espHealth end
function setProfile_espHealth(v) if type(v) == "boolean" then St.espHealth = v end end
function getProfile_espChams() return St.espChams end
function setProfile_espChams(v) if type(v) == "boolean" then St.espChams = v end end
function getProfile_espTags() return St.espTags end
function setProfile_espTags(v) if type(v) == "boolean" then St.espTags = v end end
function getProfile_espSkeleton() return St.espSkeleton end
function setProfile_espSkeleton(v) if type(v) == "boolean" then St.espSkeleton = v end end
function getProfile_espHeadCircle() return St.espHeadCircle end
function setProfile_espHeadCircle(v) if type(v) == "boolean" then St.espHeadCircle = v end end
function getProfile_espViewLine() return St.espViewLine end
function setProfile_espViewLine(v) if type(v) == "boolean" then St.espViewLine = v end end
function getProfile_espSnaplines() return St.espSnaplines end
function setProfile_espSnaplines(v) if type(v) == "boolean" then St.espSnaplines = v end end
function getProfile_espOffscreen() return St.espOffscreen end
function setProfile_espOffscreen(v) if type(v) == "boolean" then St.espOffscreen = v end end
function getProfile_espToolName() return St.espToolName end
function setProfile_espToolName(v) if type(v) == "boolean" then St.espToolName = v end end
function getProfile_espTeamColor() return St.espTeamColor end
function setProfile_espTeamColor(v) if type(v) == "boolean" then St.espTeamColor = v end end
function getProfile_espVisColor() return St.espVisColor end
function setProfile_espVisColor(v) if type(v) == "boolean" then St.espVisColor = v end end
function getProfile_thirdPerson() return St.thirdPerson end
function setProfile_thirdPerson(v) if type(v) == "boolean" then St.thirdPerson = v end end
function getProfile_camFovOverride() return St.camFovOverride end
function setProfile_camFovOverride(v) if type(v) == "boolean" then St.camFovOverride = v end end
function getProfile_selfChams() return St.selfChams end
function setProfile_selfChams(v) if type(v) == "boolean" then St.selfChams = v end end
function getProfile_walkSpeed() return St.walkSpeed end
function setProfile_walkSpeed(v) if type(v) == "boolean" then St.walkSpeed = v end end
function getProfile_jumpPower() return St.jumpPower end
function setProfile_jumpPower(v) if type(v) == "boolean" then St.jumpPower = v end end
function getProfile_fly() return St.fly end
function setProfile_fly(v) if type(v) == "boolean" then St.fly = v end end
function getProfile_noclip() return St.noclip end
function setProfile_noclip(v) if type(v) == "boolean" then St.noclip = v end end
function getProfile_hideWatermark() return St.hideWatermark end
function setProfile_hideWatermark(v) if type(v) == "boolean" then St.hideWatermark = v end end
function getProfile_showFps() return St.showFps end
function setProfile_showFps(v) if type(v) == "boolean" then St.showFps = v end end
function getProfile_autoSaveProfiles() return St.autoSaveProfiles end
function setProfile_autoSaveProfiles(v) if type(v) == "boolean" then St.autoSaveProfiles = v end end
function getProfile_aimMode() return St.aimMode end
function setProfile_aimMode(v) if type(v) == "number" then St.aimMode = clamp(v, 1, 3) end end
function getProfile_fov() return St.fov end
function setProfile_fov(v) if type(v) == "number" then St.fov = clamp(v, 20, 400) end end
function getProfile_smooth() return St.smooth end
function setProfile_smooth(v) if type(v) == "number" then St.smooth = clamp(v, 0.05, 1) end end
function getProfile_hitPart() return St.hitPart end
function setProfile_hitPart(v) if type(v) == "number" then St.hitPart = clamp(v, 1, 4) end end
function getProfile_targetPriority() return St.targetPriority end
function setProfile_targetPriority(v) if type(v) == "number" then St.targetPriority = clamp(v, 1, 2) end end
function getProfile_rageMode() return St.rageMode end
function setProfile_rageMode(v) if type(v) == "number" then St.rageMode = clamp(v, 1, 3) end end
function getProfile_orbitRadius() return St.orbitRadius end
function setProfile_orbitRadius(v) if type(v) == "number" then St.orbitRadius = clamp(v, 4, 40) end end
function getProfile_orbitSpeed() return St.orbitSpeed end
function setProfile_orbitSpeed(v) if type(v) == "number" then St.orbitSpeed = clamp(v, 1, 20) end end
function getProfile_rageSpinSpeed() return St.rageSpinSpeed end
function setProfile_rageSpinSpeed(v) if type(v) == "number" then St.rageSpinSpeed = clamp(v, 2, 40) end end
function getProfile_rageSpeedMult() return St.rageSpeedMult end
function setProfile_rageSpeedMult(v) if type(v) == "number" then St.rageSpeedMult = clamp(v, 1, 5) end end
function getProfile_triggerDelay() return St.triggerDelay end
function setProfile_triggerDelay(v) if type(v) == "number" then St.triggerDelay = clamp(v, 0, 1) end end
function getProfile_triggerRandom() return St.triggerRandom end
function setProfile_triggerRandom(v) if type(v) == "number" then St.triggerRandom = clamp(v, 0, 0.5) end end
function getProfile_triggerMaxDist() return St.triggerMaxDist end
function setProfile_triggerMaxDist(v) if type(v) == "number" then St.triggerMaxDist = clamp(v, 50, 2000) end end
function getProfile_espMaxDist() return St.espMaxDist end
function setProfile_espMaxDist(v) if type(v) == "number" then St.espMaxDist = clamp(v, 100, 5000) end end
function getProfile_thirdPersonDist() return St.thirdPersonDist end
function setProfile_thirdPersonDist(v) if type(v) == "number" then St.thirdPersonDist = clamp(v, 4, 30) end end
function getProfile_camFov() return St.camFov end
function setProfile_camFov(v) if type(v) == "number" then St.camFov = clamp(v, 30, 120) end end
function getProfile_walkSpeedVal() return St.walkSpeedVal end
function setProfile_walkSpeedVal(v) if type(v) == "number" then St.walkSpeedVal = clamp(v, 16, 200) end end
function getProfile_jumpPowerVal() return St.jumpPowerVal end
function setProfile_jumpPowerVal(v) if type(v) == "number" then St.jumpPowerVal = clamp(v, 20, 200) end end
function getProfile_flySpeed() return St.flySpeed end
function setProfile_flySpeed(v) if type(v) == "number" then St.flySpeed = clamp(v, 20, 400) end end

function validateLoadedProfile(data)
    if type(data) ~= "table" then return false, "not a table" end
    if type(data.version) ~= "number" then return true, "legacy" end
    return true, "ok"
end

function mergeProfileDefaults(data)
    local defaults = serializeSettings()
    return tableMerge(defaults, data)
end

function listR6BoneNames()
    local t = {}
    for i, pair in ipairs(R6_BONES) do t[i] = pair[1] .. "-" .. pair[2] end
    return t
end

function listR15BoneNames()
    local t = {}
    for i, pair in ipairs(R15_BONES) do t[i] = pair[1] .. "-" .. pair[2] end
    return t
end

function countEspFeaturesEnabled()
    local n = 0
    if St.espEnabled then n += 1 end
    if St.espBoxes then n += 1 end
    if St.espTracers then n += 1 end
    if St.espNames then n += 1 end
    if St.espHealth then n += 1 end
    if St.espChams then n += 1 end
    if St.espTags then n += 1 end
    if St.espSkeleton then n += 1 end
    if St.espHeadCircle then n += 1 end
    if St.espViewLine then n += 1 end
    if St.espSnaplines then n += 1 end
    if St.espOffscreen then n += 1 end
    if St.espToolName then n += 1 end
    if St.espTeamColor then n += 1 end
    if St.espVisColor then n += 1 end
    return n
end

function countCombatFeaturesEnabled()
    local n = 0
    if St.aimbot then n += 1 end
    if St.silentAim then n += 1 end
    if St.triggerbot then n += 1 end
    if St.ragebot then n += 1 end
    if St.autoFire then n += 1 end
    if St.wallbang then n += 1 end
    if St.desyncOrbit then n += 1 end
    return n
end

function countMovementFeaturesEnabled()
    local n = 0
    if St.walkSpeed then n += 1 end
    if St.jumpPower then n += 1 end
    if St.fly then n += 1 end
    if St.noclip then n += 1 end
    return n
end

function getFeatureChecklistText()
    return string.format(
        "Combat:%d ESP:%d Move:%d World:%s",
        countCombatFeaturesEnabled(),
        countEspFeaturesEnabled(),
        countMovementFeaturesEnabled(),
        anyVisualsActive() and "ON" or "OFF"
    )
end

local ST_DOCS = {
    aimbot = { type = "boolean", desc = "Enable mouse aimbot", default = "false" },
    aimMode = { type = "number", desc = "1=Always 2=Toggle 3=Hold", default = "2" },
    silentAim = { type = "boolean", desc = "Snap crosshair on LMB via RenderStepped", default = "false" },
    triggerbot = { type = "boolean", desc = "Auto fire when crosshair on enemy in FOV", default = "false" },
    ragebot = { type = "boolean", desc = "Enable rage combat mode", default = "false" },
    wallbang = { type = "boolean", desc = "Ignore map in visibility raycasts when raging", default = "false" },
    autoFire = { type = "boolean", desc = "VirtualUser click while raging and shooting", default = "false" },
    desyncOrbit = { type = "boolean", desc = "Orbit around rage target HRP", default = "false" },
    barrierDisable = { type = "boolean", desc = "Disable kill barriers in map folders", default = "false" },
    rageSpin = { type = "boolean", desc = "Rotate local HRP while rage active", default = "false" },
    rageSpeedBoost = { type = "boolean", desc = "Multiply walkspeed while rage active", default = "false" },
    espEnabled = { type = "boolean", desc = "Master ESP drawing toggle", default = "false" },
    espSkeleton = { type = "boolean", desc = "Draw R6/R15 bone lines", default = "false" },
    espHeadCircle = { type = "boolean", desc = "Circle at head viewport pos", default = "false" },
    espViewLine = { type = "boolean", desc = "Line showing head look vector", default = "false" },
    espSnaplines = { type = "boolean", desc = "Lines from bottom screen center", default = "false" },
    espOffscreen = { type = "boolean", desc = "Edge arrows pointing to off-screen enemies", default = "false" },
    espToolName = { type = "boolean", desc = "Show equipped tool on billboard", default = "false" },
    espTeamColor = { type = "boolean", desc = "Green team red enemy when team check on", default = "false" },
    espVisColor = { type = "boolean", desc = "Green visible red hidden via raycast", default = "false" },
    walkSpeed = { type = "boolean", desc = "Override humanoid WalkSpeed", default = "false" },
    jumpPower = { type = "boolean", desc = "Override humanoid JumpPower", default = "false" },
    fly = { type = "boolean", desc = "WASD fly on Heartbeat", default = "false" },
    noclip = { type = "boolean", desc = "Disable character part collision", default = "false" },
    thirdPerson = { type = "boolean", desc = "Scriptable camera behind player", default = "false" },
    selfChams = { type = "boolean", desc = "Highlight on local character", default = "false" },
    showFps = { type = "boolean", desc = "Show FPS in Misc tab", default = "false" },
    hideWatermark = { type = "boolean", desc = "Hide Cobalt Redux watermark", default = "false" },
    autoSaveProfiles = { type = "boolean", desc = "Auto-save profile on setting change", default = "false" },
    priorityUserId = { type = "number", desc = "Optional aimbot priority player UserId", default = "nil" },
}

function getSettingDoc(key)
    return ST_DOCS[key]
end

function listDocumentedSettings()
    local keys = {}
    for k, _ in pairs(ST_DOCS) do keys[#keys + 1] = k end
    table.sort(keys)
    return keys
end

function doc_aimbot() return ST_DOCS.aimbot.desc end
function doc_aimMode() return ST_DOCS.aimMode.desc end
function doc_silentAim() return ST_DOCS.silentAim.desc end
function doc_triggerbot() return ST_DOCS.triggerbot.desc end
function doc_ragebot() return ST_DOCS.ragebot.desc end
function doc_wallbang() return ST_DOCS.wallbang.desc end
function doc_autoFire() return ST_DOCS.autoFire.desc end
function doc_desyncOrbit() return ST_DOCS.desyncOrbit.desc end
function doc_barrierDisable() return ST_DOCS.barrierDisable.desc end
function doc_rageSpin() return ST_DOCS.rageSpin.desc end
function doc_rageSpeedBoost() return ST_DOCS.rageSpeedBoost.desc end
function doc_espEnabled() return ST_DOCS.espEnabled.desc end
function doc_espSkeleton() return ST_DOCS.espSkeleton.desc end
function doc_espHeadCircle() return ST_DOCS.espHeadCircle.desc end
function doc_espViewLine() return ST_DOCS.espViewLine.desc end
function doc_espSnaplines() return ST_DOCS.espSnaplines.desc end
function doc_espOffscreen() return ST_DOCS.espOffscreen.desc end
function doc_espToolName() return ST_DOCS.espToolName.desc end
function doc_espTeamColor() return ST_DOCS.espTeamColor.desc end
function doc_espVisColor() return ST_DOCS.espVisColor.desc end
function doc_walkSpeed() return ST_DOCS.walkSpeed.desc end
function doc_jumpPower() return ST_DOCS.jumpPower.desc end
function doc_fly() return ST_DOCS.fly.desc end
function doc_noclip() return ST_DOCS.noclip.desc end
function doc_thirdPerson() return ST_DOCS.thirdPerson.desc end
function doc_selfChams() return ST_DOCS.selfChams.desc end
function doc_showFps() return ST_DOCS.showFps.desc end
function doc_hideWatermark() return ST_DOCS.hideWatermark.desc end
function doc_autoSaveProfiles() return ST_DOCS.autoSaveProfiles.desc end
function doc_priorityUserId() return ST_DOCS.priorityUserId.desc end

function formatSettingValue(key)
    local v = St[key]
    if v == nil then return "nil" end
    if typeof(v) == "Color3" then
        return string.format("rgb(%d,%d,%d)", v.R * 255, v.G * 255, v.B * 255)
    end
    return tostring(v)
end

function exportSettingsSummary()
    local lines = {}
    for _, k in ipairs(listDocumentedSettings()) do
        lines[#lines + 1] = k .. "=" .. formatSettingValue(k)
    end
    return table.concat(lines, "\n")
end

local VIS_DOCS = {
    worldTintHue = { type = "number", desc = "HSV hue for world tint overlay" },
    worldTintStrength = { type = "number", desc = "Tint overlay alpha strength" },
    saturation = { type = "number", desc = "ColorCorrection saturation -1 to 1" },
    contrast = { type = "number", desc = "ColorCorrection contrast -1 to 1" },
    brightness = { type = "number", desc = "ColorCorrection brightness -1 to 1" },
    blurAmount = { type = "number", desc = "BlurEffect size 0-56" },
    bloomAmount = { type = "number", desc = "Bloom intensity 0-2" },
    fullbright = { type = "boolean", desc = "Max ambient lighting" },
    noShadows = { type = "boolean", desc = "Disable global shadows" },
    clockOverride = { type = "boolean", desc = "Override Lighting clock" },
    clockTime = { type = "number", desc = "Clock time 0-24" },
}

function docVisual_worldTintHue() return VIS_DOCS.worldTintHue.desc end
function getVisual_worldTintHue() return VisualState.worldTintHue end
function setVisual_worldTintHue(v) VisualState.worldTintHue = v applyVisualEffects() end
function docVisual_worldTintStrength() return VIS_DOCS.worldTintStrength.desc end
function getVisual_worldTintStrength() return VisualState.worldTintStrength end
function setVisual_worldTintStrength(v) VisualState.worldTintStrength = v applyVisualEffects() end
function docVisual_saturation() return VIS_DOCS.saturation.desc end
function getVisual_saturation() return VisualState.saturation end
function setVisual_saturation(v) VisualState.saturation = v applyVisualEffects() end
function docVisual_contrast() return VIS_DOCS.contrast.desc end
function getVisual_contrast() return VisualState.contrast end
function setVisual_contrast(v) VisualState.contrast = v applyVisualEffects() end
function docVisual_brightness() return VIS_DOCS.brightness.desc end
function getVisual_brightness() return VisualState.brightness end
function setVisual_brightness(v) VisualState.brightness = v applyVisualEffects() end
function docVisual_blurAmount() return VIS_DOCS.blurAmount.desc end
function getVisual_blurAmount() return VisualState.blurAmount end
function setVisual_blurAmount(v) VisualState.blurAmount = v applyVisualEffects() end
function docVisual_bloomAmount() return VIS_DOCS.bloomAmount.desc end
function getVisual_bloomAmount() return VisualState.bloomAmount end
function setVisual_bloomAmount(v) VisualState.bloomAmount = v applyVisualEffects() end
function docVisual_fullbright() return VIS_DOCS.fullbright.desc end
function getVisual_fullbright() return VisualState.fullbright end
function setVisual_fullbright(v) VisualState.fullbright = v applyVisualEffects() end
function docVisual_noShadows() return VIS_DOCS.noShadows.desc end
function getVisual_noShadows() return VisualState.noShadows end
function setVisual_noShadows(v) VisualState.noShadows = v applyVisualEffects() end
function docVisual_clockOverride() return VIS_DOCS.clockOverride.desc end
function getVisual_clockOverride() return VisualState.clockOverride end
function setVisual_clockOverride(v) VisualState.clockOverride = v applyVisualEffects() end
function docVisual_clockTime() return VIS_DOCS.clockTime.desc end
function getVisual_clockTime() return VisualState.clockTime end
function setVisual_clockTime(v) VisualState.clockTime = v applyVisualEffects() end

function applyWorldPreset_Sunset()
    VisualState.worldTintHue = 0.08
    VisualState.worldTintStrength = 0.35
    VisualState.saturation = 0.2
    VisualState.contrast = 0.1
    VisualState.brightness = 0.05
    VisualState.blurAmount = 0
    VisualState.bloomAmount = 0.3
    VisualState.fullbright = false
    VisualState.noShadows = false
    VisualState.clockOverride = true
    VisualState.clockTime = 19
    syncVisualControls()
    applyVisualEffects()
    notify("Preset: Sunset", Accent)
end

function applyWorldPreset_Night()
    VisualState.worldTintHue = 0.65
    VisualState.worldTintStrength = 0.45
    VisualState.saturation = -0.3
    VisualState.contrast = 0.2
    VisualState.brightness = -0.1
    VisualState.blurAmount = 0
    VisualState.bloomAmount = 0.5
    VisualState.fullbright = false
    VisualState.noShadows = true
    VisualState.clockOverride = true
    VisualState.clockTime = 2
    syncVisualControls()
    applyVisualEffects()
    notify("Preset: Night", Accent)
end

function applyWorldPreset_Neon()
    VisualState.worldTintHue = 0.78
    VisualState.worldTintStrength = 0.55
    VisualState.saturation = 0.6
    VisualState.contrast = 0.35
    VisualState.brightness = 0.1
    VisualState.blurAmount = 8
    VisualState.bloomAmount = 1.2
    VisualState.fullbright = false
    VisualState.noShadows = false
    VisualState.clockOverride = true
    VisualState.clockTime = 22
    syncVisualControls()
    applyVisualEffects()
    notify("Preset: Neon", Accent)
end

function applyWorldPreset_Muted()
    VisualState.worldTintHue = 0.15
    VisualState.worldTintStrength = 0.2
    VisualState.saturation = -0.4
    VisualState.contrast = 0.05
    VisualState.brightness = -0.05
    VisualState.blurAmount = 4
    VisualState.bloomAmount = 0
    VisualState.fullbright = false
    VisualState.noShadows = false
    VisualState.clockOverride = false
    VisualState.clockTime = 14
    syncVisualControls()
    applyVisualEffects()
    notify("Preset: Muted", Accent)
end

function snapshotCombatState()
    return {
        aimbot = St.aimbot,
        silentAim = St.silentAim,
        triggerbot = St.triggerbot,
        ragebot = St.ragebot,
        autoFire = St.autoFire,
        wallbang = St.wallbang,
        desyncOrbit = St.desyncOrbit,
        rageSpin = St.rageSpin,
        rageSpeedBoost = St.rageSpeedBoost,
    }
end

function snapshotEspState()
    return {
        espEnabled = St.espEnabled,
        espBoxes = St.espBoxes,
        espTracers = St.espTracers,
        espNames = St.espNames,
        espHealth = St.espHealth,
        espChams = St.espChams,
        espTags = St.espTags,
        espSkeleton = St.espSkeleton,
        espHeadCircle = St.espHeadCircle,
        espViewLine = St.espViewLine,
        espSnaplines = St.espSnaplines,
        espOffscreen = St.espOffscreen,
        espToolName = St.espToolName,
        espTeamColor = St.espTeamColor,
        espVisColor = St.espVisColor,
    }
end

function snapshotMoveState()
    return { walkSpeed = St.walkSpeed, jumpPower = St.jumpPower, fly = St.fly, noclip = St.noclip }
end

function pair_aimbot_aimMode()
    return St.aimbot, St.aimMode
end

function pair_aimbot_fov()
    return St.aimbot, St.fov
end

function pair_aimbot_smooth()
    return St.aimbot, St.smooth
end

function pair_aimbot_hitPart()
    return St.aimbot, St.hitPart
end

function pair_aimbot_targetPriority()
    return St.aimbot, St.targetPriority
end

function pair_aimbot_rageMode()
    return St.aimbot, St.rageMode
end

function pair_aimbot_orbitRadius()
    return St.aimbot, St.orbitRadius
end

function pair_aimbot_orbitSpeed()
    return St.aimbot, St.orbitSpeed
end

function pair_aimbot_rageSpinSpeed()
    return St.aimbot, St.rageSpinSpeed
end

function pair_aimbot_rageSpeedMult()
    return St.aimbot, St.rageSpeedMult
end

function pair_aimbot_triggerDelay()
    return St.aimbot, St.triggerDelay
end

function pair_aimbot_triggerRandom()
    return St.aimbot, St.triggerRandom
end

function pair_aimbot_triggerMaxDist()
    return St.aimbot, St.triggerMaxDist
end

function pair_aimbot_espMaxDist()
    return St.aimbot, St.espMaxDist
end

function pair_aimbot_thirdPersonDist()
    return St.aimbot, St.thirdPersonDist
end

function pair_aimbot_camFov()
    return St.aimbot, St.camFov
end

function pair_aimbot_walkSpeedVal()
    return St.aimbot, St.walkSpeedVal
end

function pair_aimbot_jumpPowerVal()
    return St.aimbot, St.jumpPowerVal
end

function pair_aimbot_flySpeed()
    return St.aimbot, St.flySpeed
end

function pair_aimOnShoot_aimMode()
    return St.aimOnShoot, St.aimMode
end

function pair_aimOnShoot_fov()
    return St.aimOnShoot, St.fov
end

function pair_aimOnShoot_smooth()
    return St.aimOnShoot, St.smooth
end

function pair_aimOnShoot_hitPart()
    return St.aimOnShoot, St.hitPart
end

function pair_aimOnShoot_targetPriority()
    return St.aimOnShoot, St.targetPriority
end

function pair_aimOnShoot_rageMode()
    return St.aimOnShoot, St.rageMode
end

function pair_aimOnShoot_orbitRadius()
    return St.aimOnShoot, St.orbitRadius
end

function pair_aimOnShoot_orbitSpeed()
    return St.aimOnShoot, St.orbitSpeed
end

function pair_aimOnShoot_rageSpinSpeed()
    return St.aimOnShoot, St.rageSpinSpeed
end

function pair_aimOnShoot_rageSpeedMult()
    return St.aimOnShoot, St.rageSpeedMult
end

function pair_aimOnShoot_triggerDelay()
    return St.aimOnShoot, St.triggerDelay
end

function pair_aimOnShoot_triggerRandom()
    return St.aimOnShoot, St.triggerRandom
end

function pair_aimOnShoot_triggerMaxDist()
    return St.aimOnShoot, St.triggerMaxDist
end

function pair_aimOnShoot_espMaxDist()
    return St.aimOnShoot, St.espMaxDist
end

function pair_aimOnShoot_thirdPersonDist()
    return St.aimOnShoot, St.thirdPersonDist
end

function pair_aimOnShoot_camFov()
    return St.aimOnShoot, St.camFov
end

function pair_aimOnShoot_walkSpeedVal()
    return St.aimOnShoot, St.walkSpeedVal
end

function pair_aimOnShoot_jumpPowerVal()
    return St.aimOnShoot, St.jumpPowerVal
end

function pair_aimOnShoot_flySpeed()
    return St.aimOnShoot, St.flySpeed
end

function pair_silentAim_aimMode()
    return St.silentAim, St.aimMode
end

function pair_silentAim_fov()
    return St.silentAim, St.fov
end

function pair_silentAim_smooth()
    return St.silentAim, St.smooth
end

function pair_silentAim_hitPart()
    return St.silentAim, St.hitPart
end

function pair_silentAim_targetPriority()
    return St.silentAim, St.targetPriority
end

function pair_silentAim_rageMode()
    return St.silentAim, St.rageMode
end

function pair_silentAim_orbitRadius()
    return St.silentAim, St.orbitRadius
end

function pair_silentAim_orbitSpeed()
    return St.silentAim, St.orbitSpeed
end

function pair_silentAim_rageSpinSpeed()
    return St.silentAim, St.rageSpinSpeed
end

function pair_silentAim_rageSpeedMult()
    return St.silentAim, St.rageSpeedMult
end

function pair_silentAim_triggerDelay()
    return St.silentAim, St.triggerDelay
end

function pair_silentAim_triggerRandom()
    return St.silentAim, St.triggerRandom
end

function pair_silentAim_triggerMaxDist()
    return St.silentAim, St.triggerMaxDist
end

function pair_silentAim_espMaxDist()
    return St.silentAim, St.espMaxDist
end

function pair_silentAim_thirdPersonDist()
    return St.silentAim, St.thirdPersonDist
end

function pair_silentAim_camFov()
    return St.silentAim, St.camFov
end

function pair_silentAim_walkSpeedVal()
    return St.silentAim, St.walkSpeedVal
end

function pair_silentAim_jumpPowerVal()
    return St.silentAim, St.jumpPowerVal
end

function pair_silentAim_flySpeed()
    return St.silentAim, St.flySpeed
end

function pair_showFov_aimMode()
    return St.showFov, St.aimMode
end

function pair_showFov_fov()
    return St.showFov, St.fov
end

function pair_showFov_smooth()
    return St.showFov, St.smooth
end

function pair_showFov_hitPart()
    return St.showFov, St.hitPart
end

function pair_showFov_targetPriority()
    return St.showFov, St.targetPriority
end

function pair_showFov_rageMode()
    return St.showFov, St.rageMode
end

function pair_showFov_orbitRadius()
    return St.showFov, St.orbitRadius
end

function pair_showFov_orbitSpeed()
    return St.showFov, St.orbitSpeed
end

function pair_showFov_rageSpinSpeed()
    return St.showFov, St.rageSpinSpeed
end

function pair_showFov_rageSpeedMult()
    return St.showFov, St.rageSpeedMult
end

function pair_showFov_triggerDelay()
    return St.showFov, St.triggerDelay
end

function pair_showFov_triggerRandom()
    return St.showFov, St.triggerRandom
end

function pair_showFov_triggerMaxDist()
    return St.showFov, St.triggerMaxDist
end

function pair_showFov_espMaxDist()
    return St.showFov, St.espMaxDist
end

function pair_showFov_thirdPersonDist()
    return St.showFov, St.thirdPersonDist
end

function pair_showFov_camFov()
    return St.showFov, St.camFov
end

function pair_showFov_walkSpeedVal()
    return St.showFov, St.walkSpeedVal
end

function pair_showFov_jumpPowerVal()
    return St.showFov, St.jumpPowerVal
end

function pair_showFov_flySpeed()
    return St.showFov, St.flySpeed
end

function pair_visibleCheck_aimMode()
    return St.visibleCheck, St.aimMode
end

function pair_visibleCheck_fov()
    return St.visibleCheck, St.fov
end

function pair_visibleCheck_smooth()
    return St.visibleCheck, St.smooth
end

function pair_visibleCheck_hitPart()
    return St.visibleCheck, St.hitPart
end

function pair_visibleCheck_targetPriority()
    return St.visibleCheck, St.targetPriority
end

function pair_visibleCheck_rageMode()
    return St.visibleCheck, St.rageMode
end

function pair_visibleCheck_orbitRadius()
    return St.visibleCheck, St.orbitRadius
end

function pair_visibleCheck_orbitSpeed()
    return St.visibleCheck, St.orbitSpeed
end

function pair_visibleCheck_rageSpinSpeed()
    return St.visibleCheck, St.rageSpinSpeed
end

function pair_visibleCheck_rageSpeedMult()
    return St.visibleCheck, St.rageSpeedMult
end

function pair_visibleCheck_triggerDelay()
    return St.visibleCheck, St.triggerDelay
end

function pair_visibleCheck_triggerRandom()
    return St.visibleCheck, St.triggerRandom
end

function pair_visibleCheck_triggerMaxDist()
    return St.visibleCheck, St.triggerMaxDist
end

function pair_visibleCheck_espMaxDist()
    return St.visibleCheck, St.espMaxDist
end

function pair_visibleCheck_thirdPersonDist()
    return St.visibleCheck, St.thirdPersonDist
end

function pair_visibleCheck_camFov()
    return St.visibleCheck, St.camFov
end

function pair_visibleCheck_walkSpeedVal()
    return St.visibleCheck, St.walkSpeedVal
end

function pair_visibleCheck_jumpPowerVal()
    return St.visibleCheck, St.jumpPowerVal
end

function pair_visibleCheck_flySpeed()
    return St.visibleCheck, St.flySpeed
end

function pair_teamCheck_aimMode()
    return St.teamCheck, St.aimMode
end

function pair_teamCheck_fov()
    return St.teamCheck, St.fov
end

function pair_teamCheck_smooth()
    return St.teamCheck, St.smooth
end

function pair_teamCheck_hitPart()
    return St.teamCheck, St.hitPart
end

function pair_teamCheck_targetPriority()
    return St.teamCheck, St.targetPriority
end

function pair_teamCheck_rageMode()
    return St.teamCheck, St.rageMode
end

function pair_teamCheck_orbitRadius()
    return St.teamCheck, St.orbitRadius
end

function pair_teamCheck_orbitSpeed()
    return St.teamCheck, St.orbitSpeed
end

function pair_teamCheck_rageSpinSpeed()
    return St.teamCheck, St.rageSpinSpeed
end

function pair_teamCheck_rageSpeedMult()
    return St.teamCheck, St.rageSpeedMult
end

function pair_teamCheck_triggerDelay()
    return St.teamCheck, St.triggerDelay
end

function pair_teamCheck_triggerRandom()
    return St.teamCheck, St.triggerRandom
end

function pair_teamCheck_triggerMaxDist()
    return St.teamCheck, St.triggerMaxDist
end

function pair_teamCheck_espMaxDist()
    return St.teamCheck, St.espMaxDist
end

function pair_teamCheck_thirdPersonDist()
    return St.teamCheck, St.thirdPersonDist
end

function pair_teamCheck_camFov()
    return St.teamCheck, St.camFov
end

function pair_teamCheck_walkSpeedVal()
    return St.teamCheck, St.walkSpeedVal
end

function pair_teamCheck_jumpPowerVal()
    return St.teamCheck, St.jumpPowerVal
end

function pair_teamCheck_flySpeed()
    return St.teamCheck, St.flySpeed
end

function pair_ragebot_aimMode()
    return St.ragebot, St.aimMode
end

function pair_ragebot_fov()
    return St.ragebot, St.fov
end

function pair_ragebot_smooth()
    return St.ragebot, St.smooth
end

function pair_ragebot_hitPart()
    return St.ragebot, St.hitPart
end

function pair_ragebot_targetPriority()
    return St.ragebot, St.targetPriority
end

function pair_ragebot_rageMode()
    return St.ragebot, St.rageMode
end

function pair_ragebot_orbitRadius()
    return St.ragebot, St.orbitRadius
end

function pair_ragebot_orbitSpeed()
    return St.ragebot, St.orbitSpeed
end

function pair_ragebot_rageSpinSpeed()
    return St.ragebot, St.rageSpinSpeed
end

function pair_ragebot_rageSpeedMult()
    return St.ragebot, St.rageSpeedMult
end

function pair_ragebot_triggerDelay()
    return St.ragebot, St.triggerDelay
end

function pair_ragebot_triggerRandom()
    return St.ragebot, St.triggerRandom
end

function pair_ragebot_triggerMaxDist()
    return St.ragebot, St.triggerMaxDist
end

function pair_ragebot_espMaxDist()
    return St.ragebot, St.espMaxDist
end

function pair_ragebot_thirdPersonDist()
    return St.ragebot, St.thirdPersonDist
end

function pair_ragebot_camFov()
    return St.ragebot, St.camFov
end

function pair_ragebot_walkSpeedVal()
    return St.ragebot, St.walkSpeedVal
end

function pair_ragebot_jumpPowerVal()
    return St.ragebot, St.jumpPowerVal
end

function pair_ragebot_flySpeed()
    return St.ragebot, St.flySpeed
end

function pair_wallbang_aimMode()
    return St.wallbang, St.aimMode
end

function pair_wallbang_fov()
    return St.wallbang, St.fov
end

function pair_wallbang_smooth()
    return St.wallbang, St.smooth
end

function pair_wallbang_hitPart()
    return St.wallbang, St.hitPart
end

function pair_wallbang_targetPriority()
    return St.wallbang, St.targetPriority
end

function pair_wallbang_rageMode()
    return St.wallbang, St.rageMode
end

function pair_wallbang_orbitRadius()
    return St.wallbang, St.orbitRadius
end

function pair_wallbang_orbitSpeed()
    return St.wallbang, St.orbitSpeed
end

function pair_wallbang_rageSpinSpeed()
    return St.wallbang, St.rageSpinSpeed
end

function pair_wallbang_rageSpeedMult()
    return St.wallbang, St.rageSpeedMult
end

function pair_wallbang_triggerDelay()
    return St.wallbang, St.triggerDelay
end

function pair_wallbang_triggerRandom()
    return St.wallbang, St.triggerRandom
end

function pair_wallbang_triggerMaxDist()
    return St.wallbang, St.triggerMaxDist
end

function pair_wallbang_espMaxDist()
    return St.wallbang, St.espMaxDist
end

function pair_wallbang_thirdPersonDist()
    return St.wallbang, St.thirdPersonDist
end

function pair_wallbang_camFov()
    return St.wallbang, St.camFov
end

function pair_wallbang_walkSpeedVal()
    return St.wallbang, St.walkSpeedVal
end

function pair_wallbang_jumpPowerVal()
    return St.wallbang, St.jumpPowerVal
end

function pair_wallbang_flySpeed()
    return St.wallbang, St.flySpeed
end

function pair_autoFire_aimMode()
    return St.autoFire, St.aimMode
end

function pair_autoFire_fov()
    return St.autoFire, St.fov
end

function pair_autoFire_smooth()
    return St.autoFire, St.smooth
end

function pair_autoFire_hitPart()
    return St.autoFire, St.hitPart
end

function pair_autoFire_targetPriority()
    return St.autoFire, St.targetPriority
end

function pair_autoFire_rageMode()
    return St.autoFire, St.rageMode
end

function pair_autoFire_orbitRadius()
    return St.autoFire, St.orbitRadius
end

function pair_autoFire_orbitSpeed()
    return St.autoFire, St.orbitSpeed
end

function pair_autoFire_rageSpinSpeed()
    return St.autoFire, St.rageSpinSpeed
end

function pair_autoFire_rageSpeedMult()
    return St.autoFire, St.rageSpeedMult
end

function pair_autoFire_triggerDelay()
    return St.autoFire, St.triggerDelay
end

function pair_autoFire_triggerRandom()
    return St.autoFire, St.triggerRandom
end

function pair_autoFire_triggerMaxDist()
    return St.autoFire, St.triggerMaxDist
end

function pair_autoFire_espMaxDist()
    return St.autoFire, St.espMaxDist
end

function pair_autoFire_thirdPersonDist()
    return St.autoFire, St.thirdPersonDist
end

function pair_autoFire_camFov()
    return St.autoFire, St.camFov
end

function pair_autoFire_walkSpeedVal()
    return St.autoFire, St.walkSpeedVal
end

function pair_autoFire_jumpPowerVal()
    return St.autoFire, St.jumpPowerVal
end

function pair_autoFire_flySpeed()
    return St.autoFire, St.flySpeed
end

function pair_desyncOrbit_aimMode()
    return St.desyncOrbit, St.aimMode
end

function pair_desyncOrbit_fov()
    return St.desyncOrbit, St.fov
end

function pair_desyncOrbit_smooth()
    return St.desyncOrbit, St.smooth
end

function pair_desyncOrbit_hitPart()
    return St.desyncOrbit, St.hitPart
end

function pair_desyncOrbit_targetPriority()
    return St.desyncOrbit, St.targetPriority
end

function pair_desyncOrbit_rageMode()
    return St.desyncOrbit, St.rageMode
end

function pair_desyncOrbit_orbitRadius()
    return St.desyncOrbit, St.orbitRadius
end

function pair_desyncOrbit_orbitSpeed()
    return St.desyncOrbit, St.orbitSpeed
end

function pair_desyncOrbit_rageSpinSpeed()
    return St.desyncOrbit, St.rageSpinSpeed
end

function pair_desyncOrbit_rageSpeedMult()
    return St.desyncOrbit, St.rageSpeedMult
end

function pair_desyncOrbit_triggerDelay()
    return St.desyncOrbit, St.triggerDelay
end

function pair_desyncOrbit_triggerRandom()
    return St.desyncOrbit, St.triggerRandom
end

function pair_desyncOrbit_triggerMaxDist()
    return St.desyncOrbit, St.triggerMaxDist
end

function pair_desyncOrbit_espMaxDist()
    return St.desyncOrbit, St.espMaxDist
end

function pair_desyncOrbit_thirdPersonDist()
    return St.desyncOrbit, St.thirdPersonDist
end

function pair_desyncOrbit_camFov()
    return St.desyncOrbit, St.camFov
end

function pair_desyncOrbit_walkSpeedVal()
    return St.desyncOrbit, St.walkSpeedVal
end

function pair_desyncOrbit_jumpPowerVal()
    return St.desyncOrbit, St.jumpPowerVal
end

function pair_desyncOrbit_flySpeed()
    return St.desyncOrbit, St.flySpeed
end

function pair_barrierDisable_aimMode()
    return St.barrierDisable, St.aimMode
end

function pair_barrierDisable_fov()
    return St.barrierDisable, St.fov
end

function pair_barrierDisable_smooth()
    return St.barrierDisable, St.smooth
end

function pair_barrierDisable_hitPart()
    return St.barrierDisable, St.hitPart
end

function pair_barrierDisable_targetPriority()
    return St.barrierDisable, St.targetPriority
end

function pair_barrierDisable_rageMode()
    return St.barrierDisable, St.rageMode
end

function pair_barrierDisable_orbitRadius()
    return St.barrierDisable, St.orbitRadius
end

function pair_barrierDisable_orbitSpeed()
    return St.barrierDisable, St.orbitSpeed
end

function pair_barrierDisable_rageSpinSpeed()
    return St.barrierDisable, St.rageSpinSpeed
end

function pair_barrierDisable_rageSpeedMult()
    return St.barrierDisable, St.rageSpeedMult
end

function pair_barrierDisable_triggerDelay()
    return St.barrierDisable, St.triggerDelay
end

function pair_barrierDisable_triggerRandom()
    return St.barrierDisable, St.triggerRandom
end

function pair_barrierDisable_triggerMaxDist()
    return St.barrierDisable, St.triggerMaxDist
end

function pair_barrierDisable_espMaxDist()
    return St.barrierDisable, St.espMaxDist
end

function pair_barrierDisable_thirdPersonDist()
    return St.barrierDisable, St.thirdPersonDist
end

function pair_barrierDisable_camFov()
    return St.barrierDisable, St.camFov
end

function pair_barrierDisable_walkSpeedVal()
    return St.barrierDisable, St.walkSpeedVal
end

function pair_barrierDisable_jumpPowerVal()
    return St.barrierDisable, St.jumpPowerVal
end

function pair_barrierDisable_flySpeed()
    return St.barrierDisable, St.flySpeed
end

function pair_rageSpin_aimMode()
    return St.rageSpin, St.aimMode
end

function pair_rageSpin_fov()
    return St.rageSpin, St.fov
end

function pair_rageSpin_smooth()
    return St.rageSpin, St.smooth
end

function pair_rageSpin_hitPart()
    return St.rageSpin, St.hitPart
end

function pair_rageSpin_targetPriority()
    return St.rageSpin, St.targetPriority
end

function pair_rageSpin_rageMode()
    return St.rageSpin, St.rageMode
end

function pair_rageSpin_orbitRadius()
    return St.rageSpin, St.orbitRadius
end

function pair_rageSpin_orbitSpeed()
    return St.rageSpin, St.orbitSpeed
end

function pair_rageSpin_rageSpinSpeed()
    return St.rageSpin, St.rageSpinSpeed
end

function pair_rageSpin_rageSpeedMult()
    return St.rageSpin, St.rageSpeedMult
end

function pair_rageSpin_triggerDelay()
    return St.rageSpin, St.triggerDelay
end

function pair_rageSpin_triggerRandom()
    return St.rageSpin, St.triggerRandom
end

function pair_rageSpin_triggerMaxDist()
    return St.rageSpin, St.triggerMaxDist
end

function pair_rageSpin_espMaxDist()
    return St.rageSpin, St.espMaxDist
end

function pair_rageSpin_thirdPersonDist()
    return St.rageSpin, St.thirdPersonDist
end

function pair_rageSpin_camFov()
    return St.rageSpin, St.camFov
end

function pair_rageSpin_walkSpeedVal()
    return St.rageSpin, St.walkSpeedVal
end

function pair_rageSpin_jumpPowerVal()
    return St.rageSpin, St.jumpPowerVal
end

function pair_rageSpin_flySpeed()
    return St.rageSpin, St.flySpeed
end

function pair_rageSpeedBoost_aimMode()
    return St.rageSpeedBoost, St.aimMode
end

function pair_rageSpeedBoost_fov()
    return St.rageSpeedBoost, St.fov
end

function pair_rageSpeedBoost_smooth()
    return St.rageSpeedBoost, St.smooth
end

function pair_rageSpeedBoost_hitPart()
    return St.rageSpeedBoost, St.hitPart
end

function pair_rageSpeedBoost_targetPriority()
    return St.rageSpeedBoost, St.targetPriority
end

function pair_rageSpeedBoost_rageMode()
    return St.rageSpeedBoost, St.rageMode
end

function pair_rageSpeedBoost_orbitRadius()
    return St.rageSpeedBoost, St.orbitRadius
end

function pair_rageSpeedBoost_orbitSpeed()
    return St.rageSpeedBoost, St.orbitSpeed
end

function pair_rageSpeedBoost_rageSpinSpeed()
    return St.rageSpeedBoost, St.rageSpinSpeed
end

function pair_rageSpeedBoost_rageSpeedMult()
    return St.rageSpeedBoost, St.rageSpeedMult
end

function pair_rageSpeedBoost_triggerDelay()
    return St.rageSpeedBoost, St.triggerDelay
end

function pair_rageSpeedBoost_triggerRandom()
    return St.rageSpeedBoost, St.triggerRandom
end

function pair_rageSpeedBoost_triggerMaxDist()
    return St.rageSpeedBoost, St.triggerMaxDist
end

function pair_rageSpeedBoost_espMaxDist()
    return St.rageSpeedBoost, St.espMaxDist
end

function pair_rageSpeedBoost_thirdPersonDist()
    return St.rageSpeedBoost, St.thirdPersonDist
end

function pair_rageSpeedBoost_camFov()
    return St.rageSpeedBoost, St.camFov
end

function pair_rageSpeedBoost_walkSpeedVal()
    return St.rageSpeedBoost, St.walkSpeedVal
end

function pair_rageSpeedBoost_jumpPowerVal()
    return St.rageSpeedBoost, St.jumpPowerVal
end

function pair_rageSpeedBoost_flySpeed()
    return St.rageSpeedBoost, St.flySpeed
end

function pair_triggerbot_aimMode()
    return St.triggerbot, St.aimMode
end

function pair_triggerbot_fov()
    return St.triggerbot, St.fov
end

function pair_triggerbot_smooth()
    return St.triggerbot, St.smooth
end

function pair_triggerbot_hitPart()
    return St.triggerbot, St.hitPart
end

function pair_triggerbot_targetPriority()
    return St.triggerbot, St.targetPriority
end

function pair_triggerbot_rageMode()
    return St.triggerbot, St.rageMode
end

function pair_triggerbot_orbitRadius()
    return St.triggerbot, St.orbitRadius
end

function pair_triggerbot_orbitSpeed()
    return St.triggerbot, St.orbitSpeed
end

function pair_triggerbot_rageSpinSpeed()
    return St.triggerbot, St.rageSpinSpeed
end

function pair_triggerbot_rageSpeedMult()
    return St.triggerbot, St.rageSpeedMult
end

function pair_triggerbot_triggerDelay()
    return St.triggerbot, St.triggerDelay
end

function pair_triggerbot_triggerRandom()
    return St.triggerbot, St.triggerRandom
end

function pair_triggerbot_triggerMaxDist()
    return St.triggerbot, St.triggerMaxDist
end

function pair_triggerbot_espMaxDist()
    return St.triggerbot, St.espMaxDist
end

function pair_triggerbot_thirdPersonDist()
    return St.triggerbot, St.thirdPersonDist
end

function pair_triggerbot_camFov()
    return St.triggerbot, St.camFov
end

function pair_triggerbot_walkSpeedVal()
    return St.triggerbot, St.walkSpeedVal
end

function pair_triggerbot_jumpPowerVal()
    return St.triggerbot, St.jumpPowerVal
end

function pair_triggerbot_flySpeed()
    return St.triggerbot, St.flySpeed
end

function pair_espEnabled_aimMode()
    return St.espEnabled, St.aimMode
end

function pair_espEnabled_fov()
    return St.espEnabled, St.fov
end

function pair_espEnabled_smooth()
    return St.espEnabled, St.smooth
end

function pair_espEnabled_hitPart()
    return St.espEnabled, St.hitPart
end

function pair_espEnabled_targetPriority()
    return St.espEnabled, St.targetPriority
end

function pair_espEnabled_rageMode()
    return St.espEnabled, St.rageMode
end

function pair_espEnabled_orbitRadius()
    return St.espEnabled, St.orbitRadius
end

function pair_espEnabled_orbitSpeed()
    return St.espEnabled, St.orbitSpeed
end

function pair_espEnabled_rageSpinSpeed()
    return St.espEnabled, St.rageSpinSpeed
end

function pair_espEnabled_rageSpeedMult()
    return St.espEnabled, St.rageSpeedMult
end

function pair_espEnabled_triggerDelay()
    return St.espEnabled, St.triggerDelay
end

function pair_espEnabled_triggerRandom()
    return St.espEnabled, St.triggerRandom
end

function pair_espEnabled_triggerMaxDist()
    return St.espEnabled, St.triggerMaxDist
end

function pair_espEnabled_espMaxDist()
    return St.espEnabled, St.espMaxDist
end

function pair_espEnabled_thirdPersonDist()
    return St.espEnabled, St.thirdPersonDist
end

function pair_espEnabled_camFov()
    return St.espEnabled, St.camFov
end

function pair_espEnabled_walkSpeedVal()
    return St.espEnabled, St.walkSpeedVal
end

function pair_espEnabled_jumpPowerVal()
    return St.espEnabled, St.jumpPowerVal
end

function pair_espEnabled_flySpeed()
    return St.espEnabled, St.flySpeed
end

function pair_espBoxes_aimMode()
    return St.espBoxes, St.aimMode
end

function pair_espBoxes_fov()
    return St.espBoxes, St.fov
end

function pair_espBoxes_smooth()
    return St.espBoxes, St.smooth
end

function pair_espBoxes_hitPart()
    return St.espBoxes, St.hitPart
end

function pair_espBoxes_targetPriority()
    return St.espBoxes, St.targetPriority
end

function pair_espBoxes_rageMode()
    return St.espBoxes, St.rageMode
end

function pair_espBoxes_orbitRadius()
    return St.espBoxes, St.orbitRadius
end

function pair_espBoxes_orbitSpeed()
    return St.espBoxes, St.orbitSpeed
end

function pair_espBoxes_rageSpinSpeed()
    return St.espBoxes, St.rageSpinSpeed
end

function pair_espBoxes_rageSpeedMult()
    return St.espBoxes, St.rageSpeedMult
end

function pair_espBoxes_triggerDelay()
    return St.espBoxes, St.triggerDelay
end

function pair_espBoxes_triggerRandom()
    return St.espBoxes, St.triggerRandom
end

function pair_espBoxes_triggerMaxDist()
    return St.espBoxes, St.triggerMaxDist
end

function pair_espBoxes_espMaxDist()
    return St.espBoxes, St.espMaxDist
end

function pair_espBoxes_thirdPersonDist()
    return St.espBoxes, St.thirdPersonDist
end

function pair_espBoxes_camFov()
    return St.espBoxes, St.camFov
end

function pair_espBoxes_walkSpeedVal()
    return St.espBoxes, St.walkSpeedVal
end

function pair_espBoxes_jumpPowerVal()
    return St.espBoxes, St.jumpPowerVal
end

function pair_espBoxes_flySpeed()
    return St.espBoxes, St.flySpeed
end

function pair_espTracers_aimMode()
    return St.espTracers, St.aimMode
end

function pair_espTracers_fov()
    return St.espTracers, St.fov
end

function pair_espTracers_smooth()
    return St.espTracers, St.smooth
end

function pair_espTracers_hitPart()
    return St.espTracers, St.hitPart
end

function pair_espTracers_targetPriority()
    return St.espTracers, St.targetPriority
end

function pair_espTracers_rageMode()
    return St.espTracers, St.rageMode
end

function pair_espTracers_orbitRadius()
    return St.espTracers, St.orbitRadius
end

function pair_espTracers_orbitSpeed()
    return St.espTracers, St.orbitSpeed
end

function pair_espTracers_rageSpinSpeed()
    return St.espTracers, St.rageSpinSpeed
end

function pair_espTracers_rageSpeedMult()
    return St.espTracers, St.rageSpeedMult
end

function pair_espTracers_triggerDelay()
    return St.espTracers, St.triggerDelay
end

function pair_espTracers_triggerRandom()
    return St.espTracers, St.triggerRandom
end

function pair_espTracers_triggerMaxDist()
    return St.espTracers, St.triggerMaxDist
end

function pair_espTracers_espMaxDist()
    return St.espTracers, St.espMaxDist
end

function pair_espTracers_thirdPersonDist()
    return St.espTracers, St.thirdPersonDist
end

function pair_espTracers_camFov()
    return St.espTracers, St.camFov
end

function pair_espTracers_walkSpeedVal()
    return St.espTracers, St.walkSpeedVal
end

function pair_espTracers_jumpPowerVal()
    return St.espTracers, St.jumpPowerVal
end

function pair_espTracers_flySpeed()
    return St.espTracers, St.flySpeed
end

function pair_espNames_aimMode()
    return St.espNames, St.aimMode
end

function pair_espNames_fov()
    return St.espNames, St.fov
end

function pair_espNames_smooth()
    return St.espNames, St.smooth
end

function pair_espNames_hitPart()
    return St.espNames, St.hitPart
end

function pair_espNames_targetPriority()
    return St.espNames, St.targetPriority
end

function pair_espNames_rageMode()
    return St.espNames, St.rageMode
end

function pair_espNames_orbitRadius()
    return St.espNames, St.orbitRadius
end

function pair_espNames_orbitSpeed()
    return St.espNames, St.orbitSpeed
end

function pair_espNames_rageSpinSpeed()
    return St.espNames, St.rageSpinSpeed
end

function pair_espNames_rageSpeedMult()
    return St.espNames, St.rageSpeedMult
end

function pair_espNames_triggerDelay()
    return St.espNames, St.triggerDelay
end

function pair_espNames_triggerRandom()
    return St.espNames, St.triggerRandom
end

function pair_espNames_triggerMaxDist()
    return St.espNames, St.triggerMaxDist
end

function pair_espNames_espMaxDist()
    return St.espNames, St.espMaxDist
end

function pair_espNames_thirdPersonDist()
    return St.espNames, St.thirdPersonDist
end

function pair_espNames_camFov()
    return St.espNames, St.camFov
end

function pair_espNames_walkSpeedVal()
    return St.espNames, St.walkSpeedVal
end

function pair_espNames_jumpPowerVal()
    return St.espNames, St.jumpPowerVal
end

function pair_espNames_flySpeed()
    return St.espNames, St.flySpeed
end

function pair_espHealth_aimMode()
    return St.espHealth, St.aimMode
end

function pair_espHealth_fov()
    return St.espHealth, St.fov
end

function pair_espHealth_smooth()
    return St.espHealth, St.smooth
end

function pair_espHealth_hitPart()
    return St.espHealth, St.hitPart
end

function pair_espHealth_targetPriority()
    return St.espHealth, St.targetPriority
end

function pair_espHealth_rageMode()
    return St.espHealth, St.rageMode
end

function pair_espHealth_orbitRadius()
    return St.espHealth, St.orbitRadius
end

function pair_espHealth_orbitSpeed()
    return St.espHealth, St.orbitSpeed
end

function pair_espHealth_rageSpinSpeed()
    return St.espHealth, St.rageSpinSpeed
end

function pair_espHealth_rageSpeedMult()
    return St.espHealth, St.rageSpeedMult
end

function pair_espHealth_triggerDelay()
    return St.espHealth, St.triggerDelay
end

function pair_espHealth_triggerRandom()
    return St.espHealth, St.triggerRandom
end

function pair_espHealth_triggerMaxDist()
    return St.espHealth, St.triggerMaxDist
end

function pair_espHealth_espMaxDist()
    return St.espHealth, St.espMaxDist
end

function pair_espHealth_thirdPersonDist()
    return St.espHealth, St.thirdPersonDist
end

function pair_espHealth_camFov()
    return St.espHealth, St.camFov
end

function pair_espHealth_walkSpeedVal()
    return St.espHealth, St.walkSpeedVal
end

function pair_espHealth_jumpPowerVal()
    return St.espHealth, St.jumpPowerVal
end

function pair_espHealth_flySpeed()
    return St.espHealth, St.flySpeed
end

function pair_espChams_aimMode()
    return St.espChams, St.aimMode
end

function pair_espChams_fov()
    return St.espChams, St.fov
end

function pair_espChams_smooth()
    return St.espChams, St.smooth
end

function pair_espChams_hitPart()
    return St.espChams, St.hitPart
end

function pair_espChams_targetPriority()
    return St.espChams, St.targetPriority
end

function pair_espChams_rageMode()
    return St.espChams, St.rageMode
end

function pair_espChams_orbitRadius()
    return St.espChams, St.orbitRadius
end

function pair_espChams_orbitSpeed()
    return St.espChams, St.orbitSpeed
end

function pair_espChams_rageSpinSpeed()
    return St.espChams, St.rageSpinSpeed
end

function pair_espChams_rageSpeedMult()
    return St.espChams, St.rageSpeedMult
end

function pair_espChams_triggerDelay()
    return St.espChams, St.triggerDelay
end

function pair_espChams_triggerRandom()
    return St.espChams, St.triggerRandom
end

function pair_espChams_triggerMaxDist()
    return St.espChams, St.triggerMaxDist
end

function pair_espChams_espMaxDist()
    return St.espChams, St.espMaxDist
end

function pair_espChams_thirdPersonDist()
    return St.espChams, St.thirdPersonDist
end

function pair_espChams_camFov()
    return St.espChams, St.camFov
end

function pair_espChams_walkSpeedVal()
    return St.espChams, St.walkSpeedVal
end

function pair_espChams_jumpPowerVal()
    return St.espChams, St.jumpPowerVal
end

function pair_espChams_flySpeed()
    return St.espChams, St.flySpeed
end

function pair_espTags_aimMode()
    return St.espTags, St.aimMode
end

function pair_espTags_fov()
    return St.espTags, St.fov
end

function pair_espTags_smooth()
    return St.espTags, St.smooth
end

function pair_espTags_hitPart()
    return St.espTags, St.hitPart
end

function pair_espTags_targetPriority()
    return St.espTags, St.targetPriority
end

function pair_espTags_rageMode()
    return St.espTags, St.rageMode
end

function pair_espTags_orbitRadius()
    return St.espTags, St.orbitRadius
end

function pair_espTags_orbitSpeed()
    return St.espTags, St.orbitSpeed
end

function pair_espTags_rageSpinSpeed()
    return St.espTags, St.rageSpinSpeed
end

function pair_espTags_rageSpeedMult()
    return St.espTags, St.rageSpeedMult
end

function pair_espTags_triggerDelay()
    return St.espTags, St.triggerDelay
end

function pair_espTags_triggerRandom()
    return St.espTags, St.triggerRandom
end

function pair_espTags_triggerMaxDist()
    return St.espTags, St.triggerMaxDist
end

function pair_espTags_espMaxDist()
    return St.espTags, St.espMaxDist
end

function pair_espTags_thirdPersonDist()
    return St.espTags, St.thirdPersonDist
end

function pair_espTags_camFov()
    return St.espTags, St.camFov
end

function pair_espTags_walkSpeedVal()
    return St.espTags, St.walkSpeedVal
end

function pair_espTags_jumpPowerVal()
    return St.espTags, St.jumpPowerVal
end

function pair_espTags_flySpeed()
    return St.espTags, St.flySpeed
end

function pair_espSkeleton_aimMode()
    return St.espSkeleton, St.aimMode
end

function pair_espSkeleton_fov()
    return St.espSkeleton, St.fov
end

function pair_espSkeleton_smooth()
    return St.espSkeleton, St.smooth
end

function pair_espSkeleton_hitPart()
    return St.espSkeleton, St.hitPart
end

function pair_espSkeleton_targetPriority()
    return St.espSkeleton, St.targetPriority
end

function pair_espSkeleton_rageMode()
    return St.espSkeleton, St.rageMode
end

function pair_espSkeleton_orbitRadius()
    return St.espSkeleton, St.orbitRadius
end

function pair_espSkeleton_orbitSpeed()
    return St.espSkeleton, St.orbitSpeed
end

function pair_espSkeleton_rageSpinSpeed()
    return St.espSkeleton, St.rageSpinSpeed
end

function pair_espSkeleton_rageSpeedMult()
    return St.espSkeleton, St.rageSpeedMult
end

function pair_espSkeleton_triggerDelay()
    return St.espSkeleton, St.triggerDelay
end

function pair_espSkeleton_triggerRandom()
    return St.espSkeleton, St.triggerRandom
end

function pair_espSkeleton_triggerMaxDist()
    return St.espSkeleton, St.triggerMaxDist
end

function pair_espSkeleton_espMaxDist()
    return St.espSkeleton, St.espMaxDist
end

function pair_espSkeleton_thirdPersonDist()
    return St.espSkeleton, St.thirdPersonDist
end

function pair_espSkeleton_camFov()
    return St.espSkeleton, St.camFov
end

function pair_espSkeleton_walkSpeedVal()
    return St.espSkeleton, St.walkSpeedVal
end

function pair_espSkeleton_jumpPowerVal()
    return St.espSkeleton, St.jumpPowerVal
end

function pair_espSkeleton_flySpeed()
    return St.espSkeleton, St.flySpeed
end

function pair_espHeadCircle_aimMode()
    return St.espHeadCircle, St.aimMode
end

function pair_espHeadCircle_fov()
    return St.espHeadCircle, St.fov
end

function pair_espHeadCircle_smooth()
    return St.espHeadCircle, St.smooth
end

function pair_espHeadCircle_hitPart()
    return St.espHeadCircle, St.hitPart
end

function pair_espHeadCircle_targetPriority()
    return St.espHeadCircle, St.targetPriority
end

function pair_espHeadCircle_rageMode()
    return St.espHeadCircle, St.rageMode
end

function pair_espHeadCircle_orbitRadius()
    return St.espHeadCircle, St.orbitRadius
end

function pair_espHeadCircle_orbitSpeed()
    return St.espHeadCircle, St.orbitSpeed
end

function pair_espHeadCircle_rageSpinSpeed()
    return St.espHeadCircle, St.rageSpinSpeed
end

function pair_espHeadCircle_rageSpeedMult()
    return St.espHeadCircle, St.rageSpeedMult
end

function pair_espHeadCircle_triggerDelay()
    return St.espHeadCircle, St.triggerDelay
end

function pair_espHeadCircle_triggerRandom()
    return St.espHeadCircle, St.triggerRandom
end

function pair_espHeadCircle_triggerMaxDist()
    return St.espHeadCircle, St.triggerMaxDist
end

function pair_espHeadCircle_espMaxDist()
    return St.espHeadCircle, St.espMaxDist
end

function pair_espHeadCircle_thirdPersonDist()
    return St.espHeadCircle, St.thirdPersonDist
end

function pair_espHeadCircle_camFov()
    return St.espHeadCircle, St.camFov
end

function pair_espHeadCircle_walkSpeedVal()
    return St.espHeadCircle, St.walkSpeedVal
end

function pair_espHeadCircle_jumpPowerVal()
    return St.espHeadCircle, St.jumpPowerVal
end

function pair_espHeadCircle_flySpeed()
    return St.espHeadCircle, St.flySpeed
end

function pair_espViewLine_aimMode()
    return St.espViewLine, St.aimMode
end

function pair_espViewLine_fov()
    return St.espViewLine, St.fov
end

function pair_espViewLine_smooth()
    return St.espViewLine, St.smooth
end

function pair_espViewLine_hitPart()
    return St.espViewLine, St.hitPart
end

function pair_espViewLine_targetPriority()
    return St.espViewLine, St.targetPriority
end

function pair_espViewLine_rageMode()
    return St.espViewLine, St.rageMode
end

function pair_espViewLine_orbitRadius()
    return St.espViewLine, St.orbitRadius
end

function pair_espViewLine_orbitSpeed()
    return St.espViewLine, St.orbitSpeed
end

function pair_espViewLine_rageSpinSpeed()
    return St.espViewLine, St.rageSpinSpeed
end

function pair_espViewLine_rageSpeedMult()
    return St.espViewLine, St.rageSpeedMult
end

function pair_espViewLine_triggerDelay()
    return St.espViewLine, St.triggerDelay
end

function pair_espViewLine_triggerRandom()
    return St.espViewLine, St.triggerRandom
end

function pair_espViewLine_triggerMaxDist()
    return St.espViewLine, St.triggerMaxDist
end

function pair_espViewLine_espMaxDist()
    return St.espViewLine, St.espMaxDist
end

function pair_espViewLine_thirdPersonDist()
    return St.espViewLine, St.thirdPersonDist
end

function pair_espViewLine_camFov()
    return St.espViewLine, St.camFov
end

function pair_espViewLine_walkSpeedVal()
    return St.espViewLine, St.walkSpeedVal
end

function pair_espViewLine_jumpPowerVal()
    return St.espViewLine, St.jumpPowerVal
end

function pair_espViewLine_flySpeed()
    return St.espViewLine, St.flySpeed
end

function pair_espSnaplines_aimMode()
    return St.espSnaplines, St.aimMode
end

function pair_espSnaplines_fov()
    return St.espSnaplines, St.fov
end

function pair_espSnaplines_smooth()
    return St.espSnaplines, St.smooth
end

function pair_espSnaplines_hitPart()
    return St.espSnaplines, St.hitPart
end

function pair_espSnaplines_targetPriority()
    return St.espSnaplines, St.targetPriority
end

function pair_espSnaplines_rageMode()
    return St.espSnaplines, St.rageMode
end

function pair_espSnaplines_orbitRadius()
    return St.espSnaplines, St.orbitRadius
end

function pair_espSnaplines_orbitSpeed()
    return St.espSnaplines, St.orbitSpeed
end

function pair_espSnaplines_rageSpinSpeed()
    return St.espSnaplines, St.rageSpinSpeed
end

function pair_espSnaplines_rageSpeedMult()
    return St.espSnaplines, St.rageSpeedMult
end

function pair_espSnaplines_triggerDelay()
    return St.espSnaplines, St.triggerDelay
end

function pair_espSnaplines_triggerRandom()
    return St.espSnaplines, St.triggerRandom
end

function pair_espSnaplines_triggerMaxDist()
    return St.espSnaplines, St.triggerMaxDist
end

function pair_espSnaplines_espMaxDist()
    return St.espSnaplines, St.espMaxDist
end

function pair_espSnaplines_thirdPersonDist()
    return St.espSnaplines, St.thirdPersonDist
end

function pair_espSnaplines_camFov()
    return St.espSnaplines, St.camFov
end

function pair_espSnaplines_walkSpeedVal()
    return St.espSnaplines, St.walkSpeedVal
end

function pair_espSnaplines_jumpPowerVal()
    return St.espSnaplines, St.jumpPowerVal
end

function pair_espSnaplines_flySpeed()
    return St.espSnaplines, St.flySpeed
end

function pair_espOffscreen_aimMode()
    return St.espOffscreen, St.aimMode
end

function pair_espOffscreen_fov()
    return St.espOffscreen, St.fov
end

function pair_espOffscreen_smooth()
    return St.espOffscreen, St.smooth
end

function pair_espOffscreen_hitPart()
    return St.espOffscreen, St.hitPart
end

function pair_espOffscreen_targetPriority()
    return St.espOffscreen, St.targetPriority
end

function pair_espOffscreen_rageMode()
    return St.espOffscreen, St.rageMode
end

function pair_espOffscreen_orbitRadius()
    return St.espOffscreen, St.orbitRadius
end

function pair_espOffscreen_orbitSpeed()
    return St.espOffscreen, St.orbitSpeed
end

function pair_espOffscreen_rageSpinSpeed()
    return St.espOffscreen, St.rageSpinSpeed
end

function pair_espOffscreen_rageSpeedMult()
    return St.espOffscreen, St.rageSpeedMult
end

function pair_espOffscreen_triggerDelay()
    return St.espOffscreen, St.triggerDelay
end

function pair_espOffscreen_triggerRandom()
    return St.espOffscreen, St.triggerRandom
end

function pair_espOffscreen_triggerMaxDist()
    return St.espOffscreen, St.triggerMaxDist
end

function pair_espOffscreen_espMaxDist()
    return St.espOffscreen, St.espMaxDist
end

function pair_espOffscreen_thirdPersonDist()
    return St.espOffscreen, St.thirdPersonDist
end

function pair_espOffscreen_camFov()
    return St.espOffscreen, St.camFov
end

function pair_espOffscreen_walkSpeedVal()
    return St.espOffscreen, St.walkSpeedVal
end

function pair_espOffscreen_jumpPowerVal()
    return St.espOffscreen, St.jumpPowerVal
end

function pair_espOffscreen_flySpeed()
    return St.espOffscreen, St.flySpeed
end

function pair_espToolName_aimMode()
    return St.espToolName, St.aimMode
end

function pair_espToolName_fov()
    return St.espToolName, St.fov
end

function pair_espToolName_smooth()
    return St.espToolName, St.smooth
end

function pair_espToolName_hitPart()
    return St.espToolName, St.hitPart
end

function pair_espToolName_targetPriority()
    return St.espToolName, St.targetPriority
end

function pair_espToolName_rageMode()
    return St.espToolName, St.rageMode
end

function pair_espToolName_orbitRadius()
    return St.espToolName, St.orbitRadius
end

function pair_espToolName_orbitSpeed()
    return St.espToolName, St.orbitSpeed
end

function pair_espToolName_rageSpinSpeed()
    return St.espToolName, St.rageSpinSpeed
end

function pair_espToolName_rageSpeedMult()
    return St.espToolName, St.rageSpeedMult
end

function pair_espToolName_triggerDelay()
    return St.espToolName, St.triggerDelay
end

function pair_espToolName_triggerRandom()
    return St.espToolName, St.triggerRandom
end

function pair_espToolName_triggerMaxDist()
    return St.espToolName, St.triggerMaxDist
end

function pair_espToolName_espMaxDist()
    return St.espToolName, St.espMaxDist
end

function pair_espToolName_thirdPersonDist()
    return St.espToolName, St.thirdPersonDist
end

function pair_espToolName_camFov()
    return St.espToolName, St.camFov
end

function pair_espToolName_walkSpeedVal()
    return St.espToolName, St.walkSpeedVal
end

function pair_espToolName_jumpPowerVal()
    return St.espToolName, St.jumpPowerVal
end

function pair_espToolName_flySpeed()
    return St.espToolName, St.flySpeed
end

function pair_espTeamColor_aimMode()
    return St.espTeamColor, St.aimMode
end

function pair_espTeamColor_fov()
    return St.espTeamColor, St.fov
end

function pair_espTeamColor_smooth()
    return St.espTeamColor, St.smooth
end

function pair_espTeamColor_hitPart()
    return St.espTeamColor, St.hitPart
end

function pair_espTeamColor_targetPriority()
    return St.espTeamColor, St.targetPriority
end

function pair_espTeamColor_rageMode()
    return St.espTeamColor, St.rageMode
end

function pair_espTeamColor_orbitRadius()
    return St.espTeamColor, St.orbitRadius
end

function pair_espTeamColor_orbitSpeed()
    return St.espTeamColor, St.orbitSpeed
end

function pair_espTeamColor_rageSpinSpeed()
    return St.espTeamColor, St.rageSpinSpeed
end

function pair_espTeamColor_rageSpeedMult()
    return St.espTeamColor, St.rageSpeedMult
end

function pair_espTeamColor_triggerDelay()
    return St.espTeamColor, St.triggerDelay
end

function pair_espTeamColor_triggerRandom()
    return St.espTeamColor, St.triggerRandom
end

function pair_espTeamColor_triggerMaxDist()
    return St.espTeamColor, St.triggerMaxDist
end

function pair_espTeamColor_espMaxDist()
    return St.espTeamColor, St.espMaxDist
end

function pair_espTeamColor_thirdPersonDist()
    return St.espTeamColor, St.thirdPersonDist
end

function pair_espTeamColor_camFov()
    return St.espTeamColor, St.camFov
end

function pair_espTeamColor_walkSpeedVal()
    return St.espTeamColor, St.walkSpeedVal
end

function pair_espTeamColor_jumpPowerVal()
    return St.espTeamColor, St.jumpPowerVal
end

function pair_espTeamColor_flySpeed()
    return St.espTeamColor, St.flySpeed
end

function pair_espVisColor_aimMode()
    return St.espVisColor, St.aimMode
end

function pair_espVisColor_fov()
    return St.espVisColor, St.fov
end

function pair_espVisColor_smooth()
    return St.espVisColor, St.smooth
end

function pair_espVisColor_hitPart()
    return St.espVisColor, St.hitPart
end

function pair_espVisColor_targetPriority()
    return St.espVisColor, St.targetPriority
end

function pair_espVisColor_rageMode()
    return St.espVisColor, St.rageMode
end

function pair_espVisColor_orbitRadius()
    return St.espVisColor, St.orbitRadius
end

function pair_espVisColor_orbitSpeed()
    return St.espVisColor, St.orbitSpeed
end

function pair_espVisColor_rageSpinSpeed()
    return St.espVisColor, St.rageSpinSpeed
end

function pair_espVisColor_rageSpeedMult()
    return St.espVisColor, St.rageSpeedMult
end

function pair_espVisColor_triggerDelay()
    return St.espVisColor, St.triggerDelay
end

function pair_espVisColor_triggerRandom()
    return St.espVisColor, St.triggerRandom
end

function pair_espVisColor_triggerMaxDist()
    return St.espVisColor, St.triggerMaxDist
end

function pair_espVisColor_espMaxDist()
    return St.espVisColor, St.espMaxDist
end

function pair_espVisColor_thirdPersonDist()
    return St.espVisColor, St.thirdPersonDist
end

function pair_espVisColor_camFov()
    return St.espVisColor, St.camFov
end

function pair_espVisColor_walkSpeedVal()
    return St.espVisColor, St.walkSpeedVal
end

function pair_espVisColor_jumpPowerVal()
    return St.espVisColor, St.jumpPowerVal
end

function pair_espVisColor_flySpeed()
    return St.espVisColor, St.flySpeed
end

function pair_thirdPerson_aimMode()
    return St.thirdPerson, St.aimMode
end

function pair_thirdPerson_fov()
    return St.thirdPerson, St.fov
end

function pair_thirdPerson_smooth()
    return St.thirdPerson, St.smooth
end

function pair_thirdPerson_hitPart()
    return St.thirdPerson, St.hitPart
end

function pair_thirdPerson_targetPriority()
    return St.thirdPerson, St.targetPriority
end

function pair_thirdPerson_rageMode()
    return St.thirdPerson, St.rageMode
end

function pair_thirdPerson_orbitRadius()
    return St.thirdPerson, St.orbitRadius
end

function pair_thirdPerson_orbitSpeed()
    return St.thirdPerson, St.orbitSpeed
end

function pair_thirdPerson_rageSpinSpeed()
    return St.thirdPerson, St.rageSpinSpeed
end

function pair_thirdPerson_rageSpeedMult()
    return St.thirdPerson, St.rageSpeedMult
end

function pair_thirdPerson_triggerDelay()
    return St.thirdPerson, St.triggerDelay
end

function pair_thirdPerson_triggerRandom()
    return St.thirdPerson, St.triggerRandom
end

function pair_thirdPerson_triggerMaxDist()
    return St.thirdPerson, St.triggerMaxDist
end

function pair_thirdPerson_espMaxDist()
    return St.thirdPerson, St.espMaxDist
end

function pair_thirdPerson_thirdPersonDist()
    return St.thirdPerson, St.thirdPersonDist
end

function pair_thirdPerson_camFov()
    return St.thirdPerson, St.camFov
end

function pair_thirdPerson_walkSpeedVal()
    return St.thirdPerson, St.walkSpeedVal
end

function pair_thirdPerson_jumpPowerVal()
    return St.thirdPerson, St.jumpPowerVal
end

function pair_thirdPerson_flySpeed()
    return St.thirdPerson, St.flySpeed
end

function pair_camFovOverride_aimMode()
    return St.camFovOverride, St.aimMode
end

function pair_camFovOverride_fov()
    return St.camFovOverride, St.fov
end

function pair_camFovOverride_smooth()
    return St.camFovOverride, St.smooth
end

function pair_camFovOverride_hitPart()
    return St.camFovOverride, St.hitPart
end

function pair_camFovOverride_targetPriority()
    return St.camFovOverride, St.targetPriority
end

function pair_camFovOverride_rageMode()
    return St.camFovOverride, St.rageMode
end

function pair_camFovOverride_orbitRadius()
    return St.camFovOverride, St.orbitRadius
end

function pair_camFovOverride_orbitSpeed()
    return St.camFovOverride, St.orbitSpeed
end

function pair_camFovOverride_rageSpinSpeed()
    return St.camFovOverride, St.rageSpinSpeed
end

function pair_camFovOverride_rageSpeedMult()
    return St.camFovOverride, St.rageSpeedMult
end

function pair_camFovOverride_triggerDelay()
    return St.camFovOverride, St.triggerDelay
end

function pair_camFovOverride_triggerRandom()
    return St.camFovOverride, St.triggerRandom
end

function pair_camFovOverride_triggerMaxDist()
    return St.camFovOverride, St.triggerMaxDist
end

function pair_camFovOverride_espMaxDist()
    return St.camFovOverride, St.espMaxDist
end

function pair_camFovOverride_thirdPersonDist()
    return St.camFovOverride, St.thirdPersonDist
end

function pair_camFovOverride_camFov()
    return St.camFovOverride, St.camFov
end

function pair_camFovOverride_walkSpeedVal()
    return St.camFovOverride, St.walkSpeedVal
end

function pair_camFovOverride_jumpPowerVal()
    return St.camFovOverride, St.jumpPowerVal
end

function pair_camFovOverride_flySpeed()
    return St.camFovOverride, St.flySpeed
end

function pair_selfChams_aimMode()
    return St.selfChams, St.aimMode
end

function pair_selfChams_fov()
    return St.selfChams, St.fov
end

function pair_selfChams_smooth()
    return St.selfChams, St.smooth
end

function pair_selfChams_hitPart()
    return St.selfChams, St.hitPart
end

function pair_selfChams_targetPriority()
    return St.selfChams, St.targetPriority
end

function pair_selfChams_rageMode()
    return St.selfChams, St.rageMode
end

function pair_selfChams_orbitRadius()
    return St.selfChams, St.orbitRadius
end

function pair_selfChams_orbitSpeed()
    return St.selfChams, St.orbitSpeed
end

function pair_selfChams_rageSpinSpeed()
    return St.selfChams, St.rageSpinSpeed
end

function pair_selfChams_rageSpeedMult()
    return St.selfChams, St.rageSpeedMult
end

function pair_selfChams_triggerDelay()
    return St.selfChams, St.triggerDelay
end

function pair_selfChams_triggerRandom()
    return St.selfChams, St.triggerRandom
end

function pair_selfChams_triggerMaxDist()
    return St.selfChams, St.triggerMaxDist
end

function pair_selfChams_espMaxDist()
    return St.selfChams, St.espMaxDist
end

function pair_selfChams_thirdPersonDist()
    return St.selfChams, St.thirdPersonDist
end

function pair_selfChams_camFov()
    return St.selfChams, St.camFov
end

function pair_selfChams_walkSpeedVal()
    return St.selfChams, St.walkSpeedVal
end

function pair_selfChams_jumpPowerVal()
    return St.selfChams, St.jumpPowerVal
end

function pair_selfChams_flySpeed()
    return St.selfChams, St.flySpeed
end

function pair_walkSpeed_aimMode()
    return St.walkSpeed, St.aimMode
end

function pair_walkSpeed_fov()
    return St.walkSpeed, St.fov
end

function pair_walkSpeed_smooth()
    return St.walkSpeed, St.smooth
end

function pair_walkSpeed_hitPart()
    return St.walkSpeed, St.hitPart
end

function pair_walkSpeed_targetPriority()
    return St.walkSpeed, St.targetPriority
end

function pair_walkSpeed_rageMode()
    return St.walkSpeed, St.rageMode
end

function pair_walkSpeed_orbitRadius()
    return St.walkSpeed, St.orbitRadius
end

function pair_walkSpeed_orbitSpeed()
    return St.walkSpeed, St.orbitSpeed
end

function pair_walkSpeed_rageSpinSpeed()
    return St.walkSpeed, St.rageSpinSpeed
end

function pair_walkSpeed_rageSpeedMult()
    return St.walkSpeed, St.rageSpeedMult
end

function pair_walkSpeed_triggerDelay()
    return St.walkSpeed, St.triggerDelay
end

function pair_walkSpeed_triggerRandom()
    return St.walkSpeed, St.triggerRandom
end

function pair_walkSpeed_triggerMaxDist()
    return St.walkSpeed, St.triggerMaxDist
end

function pair_walkSpeed_espMaxDist()
    return St.walkSpeed, St.espMaxDist
end

function pair_walkSpeed_thirdPersonDist()
    return St.walkSpeed, St.thirdPersonDist
end

function pair_walkSpeed_camFov()
    return St.walkSpeed, St.camFov
end

function pair_walkSpeed_walkSpeedVal()
    return St.walkSpeed, St.walkSpeedVal
end

function pair_walkSpeed_jumpPowerVal()
    return St.walkSpeed, St.jumpPowerVal
end

function pair_walkSpeed_flySpeed()
    return St.walkSpeed, St.flySpeed
end

function pair_jumpPower_aimMode()
    return St.jumpPower, St.aimMode
end

function pair_jumpPower_fov()
    return St.jumpPower, St.fov
end

function pair_jumpPower_smooth()
    return St.jumpPower, St.smooth
end

function pair_jumpPower_hitPart()
    return St.jumpPower, St.hitPart
end

function pair_jumpPower_targetPriority()
    return St.jumpPower, St.targetPriority
end

function pair_jumpPower_rageMode()
    return St.jumpPower, St.rageMode
end

function pair_jumpPower_orbitRadius()
    return St.jumpPower, St.orbitRadius
end

function pair_jumpPower_orbitSpeed()
    return St.jumpPower, St.orbitSpeed
end

function pair_jumpPower_rageSpinSpeed()
    return St.jumpPower, St.rageSpinSpeed
end

function pair_jumpPower_rageSpeedMult()
    return St.jumpPower, St.rageSpeedMult
end

function pair_jumpPower_triggerDelay()
    return St.jumpPower, St.triggerDelay
end

function pair_jumpPower_triggerRandom()
    return St.jumpPower, St.triggerRandom
end

function pair_jumpPower_triggerMaxDist()
    return St.jumpPower, St.triggerMaxDist
end

function pair_jumpPower_espMaxDist()
    return St.jumpPower, St.espMaxDist
end

function pair_jumpPower_thirdPersonDist()
    return St.jumpPower, St.thirdPersonDist
end

function pair_jumpPower_camFov()
    return St.jumpPower, St.camFov
end

function pair_jumpPower_walkSpeedVal()
    return St.jumpPower, St.walkSpeedVal
end

function pair_jumpPower_jumpPowerVal()
    return St.jumpPower, St.jumpPowerVal
end

function pair_jumpPower_flySpeed()
    return St.jumpPower, St.flySpeed
end

function pair_fly_aimMode()
    return St.fly, St.aimMode
end

function pair_fly_fov()
    return St.fly, St.fov
end

function pair_fly_smooth()
    return St.fly, St.smooth
end

function pair_fly_hitPart()
    return St.fly, St.hitPart
end

function pair_fly_targetPriority()
    return St.fly, St.targetPriority
end

function pair_fly_rageMode()
    return St.fly, St.rageMode
end

function pair_fly_orbitRadius()
    return St.fly, St.orbitRadius
end

function pair_fly_orbitSpeed()
    return St.fly, St.orbitSpeed
end

function pair_fly_rageSpinSpeed()
    return St.fly, St.rageSpinSpeed
end

function pair_fly_rageSpeedMult()
    return St.fly, St.rageSpeedMult
end

function pair_fly_triggerDelay()
    return St.fly, St.triggerDelay
end

function pair_fly_triggerRandom()
    return St.fly, St.triggerRandom
end

function pair_fly_triggerMaxDist()
    return St.fly, St.triggerMaxDist
end

function pair_fly_espMaxDist()
    return St.fly, St.espMaxDist
end

function pair_fly_thirdPersonDist()
    return St.fly, St.thirdPersonDist
end

function pair_fly_camFov()
    return St.fly, St.camFov
end

function pair_fly_walkSpeedVal()
    return St.fly, St.walkSpeedVal
end

function pair_fly_jumpPowerVal()
    return St.fly, St.jumpPowerVal
end

function pair_fly_flySpeed()
    return St.fly, St.flySpeed
end

function pair_noclip_aimMode()
    return St.noclip, St.aimMode
end

function pair_noclip_fov()
    return St.noclip, St.fov
end

function pair_noclip_smooth()
    return St.noclip, St.smooth
end

function pair_noclip_hitPart()
    return St.noclip, St.hitPart
end

function pair_noclip_targetPriority()
    return St.noclip, St.targetPriority
end

function pair_noclip_rageMode()
    return St.noclip, St.rageMode
end

function pair_noclip_orbitRadius()
    return St.noclip, St.orbitRadius
end

function pair_noclip_orbitSpeed()
    return St.noclip, St.orbitSpeed
end

function pair_noclip_rageSpinSpeed()
    return St.noclip, St.rageSpinSpeed
end

function pair_noclip_rageSpeedMult()
    return St.noclip, St.rageSpeedMult
end

function pair_noclip_triggerDelay()
    return St.noclip, St.triggerDelay
end

function pair_noclip_triggerRandom()
    return St.noclip, St.triggerRandom
end

function pair_noclip_triggerMaxDist()
    return St.noclip, St.triggerMaxDist
end

function pair_noclip_espMaxDist()
    return St.noclip, St.espMaxDist
end

function pair_noclip_thirdPersonDist()
    return St.noclip, St.thirdPersonDist
end

function pair_noclip_camFov()
    return St.noclip, St.camFov
end

function pair_noclip_walkSpeedVal()
    return St.noclip, St.walkSpeedVal
end

function pair_noclip_jumpPowerVal()
    return St.noclip, St.jumpPowerVal
end

function pair_noclip_flySpeed()
    return St.noclip, St.flySpeed
end

function pair_hideWatermark_aimMode()
    return St.hideWatermark, St.aimMode
end

function pair_hideWatermark_fov()
    return St.hideWatermark, St.fov
end

function pair_hideWatermark_smooth()
    return St.hideWatermark, St.smooth
end

function pair_hideWatermark_hitPart()
    return St.hideWatermark, St.hitPart
end

function pair_hideWatermark_targetPriority()
    return St.hideWatermark, St.targetPriority
end

function pair_hideWatermark_rageMode()
    return St.hideWatermark, St.rageMode
end

function pair_hideWatermark_orbitRadius()
    return St.hideWatermark, St.orbitRadius
end

function pair_hideWatermark_orbitSpeed()
    return St.hideWatermark, St.orbitSpeed
end

function pair_hideWatermark_rageSpinSpeed()
    return St.hideWatermark, St.rageSpinSpeed
end

function pair_hideWatermark_rageSpeedMult()
    return St.hideWatermark, St.rageSpeedMult
end

function pair_hideWatermark_triggerDelay()
    return St.hideWatermark, St.triggerDelay
end

function pair_hideWatermark_triggerRandom()
    return St.hideWatermark, St.triggerRandom
end

function pair_hideWatermark_triggerMaxDist()
    return St.hideWatermark, St.triggerMaxDist
end

function pair_hideWatermark_espMaxDist()
    return St.hideWatermark, St.espMaxDist
end

function pair_hideWatermark_thirdPersonDist()
    return St.hideWatermark, St.thirdPersonDist
end

function pair_hideWatermark_camFov()
    return St.hideWatermark, St.camFov
end

function pair_hideWatermark_walkSpeedVal()
    return St.hideWatermark, St.walkSpeedVal
end

function pair_hideWatermark_jumpPowerVal()
    return St.hideWatermark, St.jumpPowerVal
end

function pair_hideWatermark_flySpeed()
    return St.hideWatermark, St.flySpeed
end

function pair_showFps_aimMode()
    return St.showFps, St.aimMode
end

function pair_showFps_fov()
    return St.showFps, St.fov
end

function pair_showFps_smooth()
    return St.showFps, St.smooth
end

function pair_showFps_hitPart()
    return St.showFps, St.hitPart
end

function pair_showFps_targetPriority()
    return St.showFps, St.targetPriority
end

function pair_showFps_rageMode()
    return St.showFps, St.rageMode
end

function pair_showFps_orbitRadius()
    return St.showFps, St.orbitRadius
end

function pair_showFps_orbitSpeed()
    return St.showFps, St.orbitSpeed
end

function pair_showFps_rageSpinSpeed()
    return St.showFps, St.rageSpinSpeed
end

function pair_showFps_rageSpeedMult()
    return St.showFps, St.rageSpeedMult
end

function pair_showFps_triggerDelay()
    return St.showFps, St.triggerDelay
end

function pair_showFps_triggerRandom()
    return St.showFps, St.triggerRandom
end

function pair_showFps_triggerMaxDist()
    return St.showFps, St.triggerMaxDist
end

function pair_showFps_espMaxDist()
    return St.showFps, St.espMaxDist
end

function pair_showFps_thirdPersonDist()
    return St.showFps, St.thirdPersonDist
end

function pair_showFps_camFov()
    return St.showFps, St.camFov
end

function pair_showFps_walkSpeedVal()
    return St.showFps, St.walkSpeedVal
end

function pair_showFps_jumpPowerVal()
    return St.showFps, St.jumpPowerVal
end

function pair_showFps_flySpeed()
    return St.showFps, St.flySpeed
end

function pair_autoSaveProfiles_aimMode()
    return St.autoSaveProfiles, St.aimMode
end

function pair_autoSaveProfiles_fov()
    return St.autoSaveProfiles, St.fov
end

function pair_autoSaveProfiles_smooth()
    return St.autoSaveProfiles, St.smooth
end

function pair_autoSaveProfiles_hitPart()
    return St.autoSaveProfiles, St.hitPart
end

function pair_autoSaveProfiles_targetPriority()
    return St.autoSaveProfiles, St.targetPriority
end

function pair_autoSaveProfiles_rageMode()
    return St.autoSaveProfiles, St.rageMode
end

function pair_autoSaveProfiles_orbitRadius()
    return St.autoSaveProfiles, St.orbitRadius
end

function pair_autoSaveProfiles_orbitSpeed()
    return St.autoSaveProfiles, St.orbitSpeed
end

function pair_autoSaveProfiles_rageSpinSpeed()
    return St.autoSaveProfiles, St.rageSpinSpeed
end

function pair_autoSaveProfiles_rageSpeedMult()
    return St.autoSaveProfiles, St.rageSpeedMult
end

function pair_autoSaveProfiles_triggerDelay()
    return St.autoSaveProfiles, St.triggerDelay
end

function pair_autoSaveProfiles_triggerRandom()
    return St.autoSaveProfiles, St.triggerRandom
end

function pair_autoSaveProfiles_triggerMaxDist()
    return St.autoSaveProfiles, St.triggerMaxDist
end

function pair_autoSaveProfiles_espMaxDist()
    return St.autoSaveProfiles, St.espMaxDist
end

function pair_autoSaveProfiles_thirdPersonDist()
    return St.autoSaveProfiles, St.thirdPersonDist
end

function pair_autoSaveProfiles_camFov()
    return St.autoSaveProfiles, St.camFov
end

function pair_autoSaveProfiles_walkSpeedVal()
    return St.autoSaveProfiles, St.walkSpeedVal
end

function pair_autoSaveProfiles_jumpPowerVal()
    return St.autoSaveProfiles, St.jumpPowerVal
end

function pair_autoSaveProfiles_flySpeed()
    return St.autoSaveProfiles, St.flySpeed
end

function aimModeIsAlways() return St.aimMode == 1 end
function aimModeIsToggle() return St.aimMode == 2 end
function aimModeIsHold() return St.aimMode == 3 end

function hitPartIsHead() return St.hitPart == 1 end
function hitPartIsUpperTorso() return St.hitPart == 2 end
function hitPartIsHumanoidRootPart() return St.hitPart == 3 end
function hitPartIsLowerTorso() return St.hitPart == 4 end


-- ═══════════════════════════════════════════════════════════════
-- LINORIA UI HELPERS (cobalt-automation pattern)
-- ═══════════════════════════════════════════════════════════════

function bordered(parent, bg, border, size, pos, z)
    local outer = Instance.new("Frame")
    outer.BackgroundColor3 = BLACK
    outer.BorderColor3 = BLACK
    outer.BorderSizePixel = 1
    outer.Size = size
    outer.Position = pos or UDim2.fromOffset(0, 0)
    outer.ZIndex = z or 1
    outer.Parent = parent

    local inner = Instance.new("Frame")
    inner.BackgroundColor3 = bg
    inner.BorderColor3 = border
    inner.BorderSizePixel = 1
    inner.Size = UDim2.new(1, 0, 1, 0)
    inner.ZIndex = (z or 1) + 1
    inner.Parent = outer

    return outer, inner
end

function label(parent, text, size, pos, z, xAlign)
    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Font = FONT
    lbl.Text = text
    lbl.TextColor3 = TEXT
    lbl.TextSize = size or 14
    lbl.Size = UDim2.new(1, -8, 0, size or 14)
    lbl.Position = pos or UDim2.fromOffset(4, 0)
    lbl.TextXAlignment = xAlign or Enum.TextXAlignment.Left
    lbl.ZIndex = z or 5
    lbl.Parent = parent
    return lbl
end

function makeGroupbox(stack, title)
    local boxOuter = Instance.new("Frame")
    boxOuter.BackgroundColor3 = BG
    boxOuter.BorderColor3 = OUTLINE
    boxOuter.BorderSizePixel = 1
    boxOuter.Size = UDim2.new(1, 0, 0, 0)
    boxOuter.AutomaticSize = Enum.AutomaticSize.Y
    boxOuter.ZIndex = 4
    boxOuter.Parent = stack

    local boxInner = Instance.new("Frame")
    boxInner.BackgroundColor3 = BG
    boxInner.BorderColor3 = BLACK
    boxInner.BorderSizePixel = 1
    boxInner.Size = UDim2.new(1, -2, 0, 0)
    boxInner.Position = UDim2.fromOffset(1, 1)
    boxInner.AutomaticSize = Enum.AutomaticSize.Y
    boxInner.ZIndex = 5
    boxInner.Parent = boxOuter

    local highlight = Instance.new("Frame")
    highlight.BackgroundColor3 = Accent
    highlight.BorderSizePixel = 0
    highlight.Size = UDim2.new(1, 0, 0, 2)
    highlight.ZIndex = 6
    highlight.Parent = boxInner
    ThemeParts.highlights[#ThemeParts.highlights + 1] = highlight

    label(boxInner, title, 14, UDim2.fromOffset(4, 4), 6)

    local container = Instance.new("Frame")
    container.BackgroundTransparency = 1
    container.Position = UDim2.fromOffset(4, 22)
    container.Size = UDim2.new(1, -8, 0, 0)
    container.AutomaticSize = Enum.AutomaticSize.Y
    container.ZIndex = 5
    container.Parent = boxInner

    local layout = Instance.new("UIListLayout", container)
    layout.Padding = UDim.new(0, 7)

    local pad = Instance.new("UIPadding", boxInner)
    pad.PaddingBottom = UDim.new(0, 6)

    return container
end

function makeToggle(container, text, onChange, default)
    local row = Instance.new("Frame")
    row.BackgroundTransparency = 1
    row.Size = UDim2.new(1, 0, 0, 16)
    row.ZIndex = 6
    row.Parent = container

    local tOuter, tInner = bordered(row, MAIN, OUTLINE, UDim2.fromOffset(13, 13), UDim2.fromOffset(0, 1), 6)
    local lbl = label(row, text, 14, UDim2.fromOffset(22, 0), 7)
    passthrough(lbl)

    local hit = Instance.new("TextButton")
    hit.BackgroundTransparency = 1
    hit.Size = UDim2.new(1, 0, 1, 0)
    hit.Text = ""
    hit.ZIndex = 8
    hit.Parent = row

    local on = default or false
    local parts = { outer = tOuter, inner = tInner, on = on }
    ThemeParts.toggles[#ThemeParts.toggles + 1] = parts

    local function display()
        tInner.BackgroundColor3 = on and Accent or MAIN
        tInner.BorderColor3 = on and darker(Accent) or OUTLINE
        parts.on = on
    end

    local function set(v)
        on = v
        display()
        if onChange then onChange(on) end
        updateStatusLabels()
    end

    hit.MouseButton1Click:Connect(function()
        set(not on)
    end)
    display()

    return { Set = set, IsOn = function() return on end }
end

function makeSlider(container, title, opts)
    opts = opts or {}
    local minV = opts.min or 0
    local maxV = opts.max or 1
    local get = opts.get or function() return minV end
    local set = opts.set or function() end
    local fmt = opts.fmt or function(v) return tostring(v) end

    local wrap = Instance.new("Frame")
    wrap.BackgroundTransparency = 1
    wrap.Size = UDim2.new(1, 0, 0, 36)
    wrap.ZIndex = 6
    wrap.Parent = container

    label(wrap, title, 14, UDim2.fromOffset(0, 0), 7)

    local valLbl = label(wrap, fmt(get()), 14, UDim2.new(1, -80, 0, 0), 7, Enum.TextXAlignment.Right)
    valLbl.Size = UDim2.fromOffset(76, 14)

    local sOuter, sInner = bordered(wrap, MAIN, OUTLINE, UDim2.new(1, -4, 0, 13), UDim2.fromOffset(0, 20), 6)

    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = Accent
    fill.BorderColor3 = darker(Accent)
    fill.BorderSizePixel = 1
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.ZIndex = 8
    fill.Parent = sInner
    ThemeParts.fills[#ThemeParts.fills + 1] = fill

    local trackBtn = Instance.new("TextButton")
    trackBtn.BackgroundTransparency = 1
    trackBtn.Size = UDim2.new(1, 0, 1, 0)
    trackBtn.Text = ""
    trackBtn.ZIndex = 9
    trackBtn.Parent = sInner

    local sliding = false
    local span = maxV - minV

    local function applyAlpha(a)
        a = clamp(a, 0, 1)
        local v = minV + span * a
        set(v)
        fill.Size = UDim2.new(a, 0, 1, 0)
        valLbl.Text = fmt(v)
    end

    local function applyValue(v)
        if span <= 0 then
            applyAlpha(0)
        else
            applyAlpha((v - minV) / span)
        end
    end

    trackBtn.MouseButton1Down:Connect(function()
        sliding = true
    end)
    trackBtn.MouseButton1Click:Connect(function()
        local x = UserInputService:GetMouseLocation().X
        local tx, tw = sInner.AbsolutePosition.X, sInner.AbsoluteSize.X
        applyAlpha((x - tx) / tw)
    end)
    connect(UserInputService.InputChanged, function(i)
        if sliding and i.UserInputType == Enum.UserInputType.MouseMovement then
            local tx, tw = sInner.AbsolutePosition.X, sInner.AbsoluteSize.X
            applyAlpha((i.Position.X - tx) / tw)
        end
    end)
    connect(UserInputService.InputEnded, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            sliding = false
        end
    end)

    applyValue(get())

    return {
        Set = applyValue,
        Refresh = function()
            valLbl.Text = fmt(get())
            applyValue(get())
        end,
    }
end

function makeButton(container, text, onClick)
    local row = Instance.new("TextButton")
    row.BackgroundColor3 = BG
    row.BorderColor3 = OUTLINE
    row.BorderSizePixel = 1
    row.Size = UDim2.new(1, 0, 0, 22)
    row.AutoButtonColor = false
    row.Font = FONT
    row.Text = "  " .. text
    row.TextColor3 = TEXT
    row.TextSize = 14
    row.TextXAlignment = Enum.TextXAlignment.Left
    row.ZIndex = 7
    row.Parent = container
    row.MouseButton1Click:Connect(onClick)
    return row
end

function makeCycle(container, title, opts, getIndex, setIndex)
    local wrap = Instance.new("Frame")
    wrap.BackgroundTransparency = 1
    wrap.Size = UDim2.new(1, 0, 0, 20)
    wrap.ZIndex = 6
    wrap.Parent = container

    label(wrap, title, 14, UDim2.fromOffset(0, 2), 7)

    local tw = textBounds(opts[getIndex()] or "?", 14)
    local _, inner = bordered(wrap, MAIN, OUTLINE, UDim2.fromOffset(math.max(tw + 12, 100), 18), UDim2.new(1, -(math.max(tw + 16, 104)), 0, 1), 6)
    local valLbl = label(inner, opts[getIndex()], 14, UDim2.fromOffset(4, 1), 8)
    valLbl.Size = UDim2.new(1, -8, 1, 0)

    local hit = Instance.new("TextButton")
    hit.BackgroundTransparency = 1
    hit.Size = UDim2.fromScale(1, 1)
    hit.Text = ""
    hit.ZIndex = 9
    hit.Parent = inner

    hit.MouseButton1Click:Connect(function()
        local n = getIndex() % #opts + 1
        setIndex(n)
        valLbl.Text = opts[n]
        updateStatusLabels()
    end)

    return {
        Refresh = function()
            valLbl.Text = opts[getIndex()]
        end,
    }
end

function makeStatusRow(container, leftText, rightRefKey)
    local row = Instance.new("Frame")
    row.BackgroundTransparency = 1
    row.Size = UDim2.new(1, 0, 0, 16)
    row.ZIndex = 6
    row.Parent = container

    label(row, leftText, 13, UDim2.fromOffset(0, 0), 7)
    local status = label(row, "...", 13, UDim2.new(1, -60, 0, 0), 7, Enum.TextXAlignment.Right)
    status.Size = UDim2.fromOffset(56, 14)
    Ref[rightRefKey] = status
    return status
end

function setUIVisible(show)
    St.uiHidden = not show
    if WindowOuter then WindowOuter.Visible = show end
    if ScreenGui then ScreenGui.Enabled = true end
    if OverlayGui then OverlayGui.Enabled = true end
end

-- ═══════════════════════════════════════════════════════════════
-- SCREEN GUI (linear init — no pcall wrapper)
-- ═══════════════════════════════════════════════════════════════

ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "CobaltRedux"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 999
ScreenGui.Enabled = true
ScreenGui.Parent = GuiParent

if syn and syn.protect_gui then
    syn.protect_gui(ScreenGui, GuiParent)
elseif protectgui then
    protectgui(ScreenGui, GuiParent)
end

OverlayGui = Instance.new("ScreenGui")
OverlayGui.Name = "CobaltReduxOverlay"
OverlayGui.ResetOnSpawn = false
OverlayGui.IgnoreGuiInset = true
OverlayGui.DisplayOrder = 998
OverlayGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
OverlayGui.Parent = GuiParent

if syn and syn.protect_gui then
    syn.protect_gui(OverlayGui, GuiParent)
elseif protectgui then
    protectgui(OverlayGui, GuiParent)
end

FovRing = Instance.new("Frame")
FovRing.Name = "FovRing"
FovRing.AnchorPoint = Vector2.new(0.5, 0.5)
FovRing.BackgroundTransparency = 1
FovRing.Size = UDim2.fromOffset(240, 240)
FovRing.Position = UDim2.fromScale(0.5, 0.5)
FovRing.Visible = St.showFov
FovRing.Active = false
FovRing.ZIndex = 1
FovRing.Parent = OverlayGui

local fovCorner = Instance.new("UICorner")
fovCorner.CornerRadius = UDim.new(1, 0)
fovCorner.Parent = FovRing

FovStroke = Instance.new("UIStroke")
FovStroke.Color = Accent
FovStroke.Thickness = 2
FovStroke.Transparency = 0.35
FovStroke.Parent = FovRing

WindowOuter = Instance.new("Frame")
WindowOuter.Name = "Window"
WindowOuter.Size = UDim2.fromOffset(460, 620)
WindowOuter.Position = UDim2.fromOffset(120, 70)
WindowOuter.BackgroundColor3 = BLACK
WindowOuter.BorderSizePixel = 0
WindowOuter.Parent = ScreenGui

local _, WindowInner = bordered(WindowOuter, MAIN, Accent, UDim2.fromScale(1, 1), UDim2.fromOffset(1, 1), 1)
ThemeParts.windowInner = WindowInner

label(WindowInner, "Cobalt Redux", 14, UDim2.fromOffset(7, 4), 3)

local TitleDrag = Instance.new("TextButton")
TitleDrag.BackgroundTransparency = 1
TitleDrag.Position = UDim2.fromOffset(0, 0)
TitleDrag.Size = UDim2.new(1, 0, 0, 22)
TitleDrag.Text = ""
TitleDrag.ZIndex = 10
TitleDrag.Parent = WindowInner

local MainSection = Instance.new("Frame")
MainSection.BackgroundColor3 = BG
MainSection.BorderColor3 = OUTLINE
MainSection.BorderSizePixel = 1
MainSection.Position = UDim2.fromOffset(8, 25)
MainSection.Size = UDim2.new(1, -16, 1, -33)
MainSection.ZIndex = 2
MainSection.Parent = WindowInner

TabArea = Instance.new("Frame")
TabArea.BackgroundTransparency = 1
TabArea.Position = UDim2.fromOffset(8, 8)
TabArea.Size = UDim2.new(1, -16, 0, 48)
TabArea.ZIndex = 3
TabArea.Parent = MainSection

TabRow1 = Instance.new("Frame")
TabRow1.BackgroundTransparency = 1
TabRow1.Size = UDim2.new(1, 0, 0, 22)
TabRow1.ZIndex = 3
TabRow1.Parent = TabArea
local TabRow1Layout = Instance.new("UIListLayout")
TabRow1Layout.FillDirection = Enum.FillDirection.Horizontal
TabRow1Layout.Padding = UDim.new(0, 3)
TabRow1Layout.Parent = TabRow1

TabRow2 = Instance.new("Frame")
TabRow2.BackgroundTransparency = 1
TabRow2.Position = UDim2.fromOffset(0, 24)
TabRow2.Size = UDim2.new(1, 0, 0, 22)
TabRow2.ZIndex = 3
TabRow2.Parent = TabArea
local TabRow2Layout = Instance.new("UIListLayout")
TabRow2Layout.FillDirection = Enum.FillDirection.Horizontal
TabRow2Layout.Padding = UDim.new(0, 3)
TabRow2Layout.Parent = TabRow2

TabContainer = Instance.new("Frame")
TabContainer.BackgroundColor3 = MAIN
TabContainer.BorderColor3 = OUTLINE
TabContainer.BorderSizePixel = 1
TabContainer.Position = UDim2.fromOffset(8, 60)
TabContainer.Size = UDim2.new(1, -16, 1, -68)
TabContainer.ClipsDescendants = true
TabContainer.ZIndex = 3
TabContainer.Parent = MainSection

TabPages = {}
ActiveTab = nil

function makeTab(name, row)
    row = row or TabRow1
    local tw = textBounds(name, 13)
    local btnOuter, btnInner = bordered(row, BG, OUTLINE, UDim2.fromOffset(tw + 10, 20), nil, 3)
    label(btnInner, name, 13, UDim2.fromOffset(3, 2), 5)
    local page = Instance.new("ScrollingFrame")
    page.Name = name
    page.Size = UDim2.fromScale(1, 1)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 2
    page.ScrollBarImageColor3 = Accent
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.CanvasSize = UDim2.fromOffset(0, 0)
    page.Visible = false
    page.ZIndex = 4
    page.Parent = TabContainer
    local stack = Instance.new("Frame")
    stack.Size = UDim2.new(1, -8, 0, 0)
    stack.Position = UDim2.fromOffset(4, 4)
    stack.BackgroundTransparency = 1
    stack.AutomaticSize = Enum.AutomaticSize.Y
    stack.Parent = page
    Instance.new("UIListLayout", stack).Padding = UDim.new(0, 6)
    local tab = { outer = btnOuter, btnInner = btnInner, page = page, stack = stack, active = false }
    ThemeParts.tabs[name] = tab
    local btn = Instance.new("TextButton")
    btn.BackgroundTransparency = 1
    btn.Size = UDim2.fromScale(1, 1)
    btn.Text = ""
    btn.ZIndex = 10
    btn.Parent = btnOuter
    btn.MouseButton1Click:Connect(function()
        if ActiveTab == tab then return end
        for _, t in pairs(TabPages) do
            t.active = false
            t.page.Visible = false
            t.btnInner.BackgroundColor3 = BG
            t.btnInner.BorderColor3 = OUTLINE
        end
        tab.active = true
        tab.page.Visible = true
        tab.btnInner.BackgroundColor3 = MAIN
        tab.btnInner.BorderColor3 = Accent
        ActiveTab = tab
    end)
    TabPages[name] = tab
    return stack
end

local legitStack = makeTab("Legit", TabRow1)
local rageStack = makeTab("Rage", TabRow1)
local espStack = makeTab("ESP", TabRow1)
local worldStack = makeTab("World", TabRow1)
local moveStack = makeTab("Move", TabRow2)
local playersStack = makeTab("Players", TabRow2)
local configStack = makeTab("Config", TabRow2)
local miscStack = makeTab("Misc", TabRow2)

-- ── Legit tab ──
local legitGuide = makeGroupbox(legitStack, "Quick Start")
label(legitGuide, "1) Enable Aimbot + set your hold key below", 13, nil, 7)
label(legitGuide, "2) Set Aim Mode to Hold — hold your key to lock on", 13, nil, 7)
label(legitGuide, "3) Triggerbot: toggle ON = auto shoots visible enemies in crosshair", 13, nil, 7)

local legitKeys = makeGroupbox(legitStack, "Aimbot Keybinds")

local aimKeyRow = Instance.new("Frame")
aimKeyRow.BackgroundTransparency = 1
aimKeyRow.Size = UDim2.new(1, 0, 0, 16)
aimKeyRow.ZIndex = 6
aimKeyRow.Parent = legitKeys
Ref.aimKeyLbl = label(aimKeyRow, "Aim Hold Key: [" .. aimBindLabel() .. "]", 13, UDim2.fromOffset(0, 0), 7)
Ref.aimStatus = label(aimKeyRow, "OFF", 13, UDim2.new(1, -44, 0, 0), 7, Enum.TextXAlignment.Right)
Ref.aimStatus.Size = UDim2.fromOffset(40, 14)

Ref.aimModeLbl = label(legitKeys, "Activation: Hold", 13, nil, 7)
Ref.aimBindHelp = label(legitKeys, "Hold [E] to lock onto targets", 13, nil, 7)
Ref.visCheckLbl = label(legitKeys, "Visible Check: OFF", 13, nil, 7)
Ref.silentLbl = label(legitKeys, "Silent Aim: OFF (works standalone on LMB)", 13, nil, 7)

makeCycle(legitKeys, "Aim Mode", AIM_MODES, function() return St.aimMode end, function(v)
    St.aimMode = v
    if v ~= 2 then St.aimToggled = false end
    if v ~= 3 then St.aimHold = false end
    updateStatusLabels()
end)

makeButton(legitKeys, "Set Aim Hold Key (keyboard / LMB / RMB / MMB)", function()
    St.rebinding = "aim"
    if Ref.aimKeyLbl then
        Ref.aimKeyLbl.Text = "Aim Hold Key: [ press key or mouse button... ]"
    end
    if Ref.aimBindHelp then
        Ref.aimBindHelp.Text = "Listening for new bind..."
    end
end)

local legitSettings = makeGroupbox(legitStack, "Aimbot Settings")

Ref.aimbotToggle = makeToggle(legitSettings, "Enable Aimbot", function(v)
    St.aimbot = v
    if not v then
        St.aimToggled = false
        St.aimHold = false
    end
end, St.aimbot)

makeToggle(legitSettings, "Only Aim While Shooting", function(v)
    St.aimOnShoot = v
end, St.aimOnShoot)

makeToggle(legitSettings, "Visible Check", function(v)
    St.visibleCheck = v
end, St.visibleCheck)

Ref.silentToggle = makeToggle(legitSettings, "Silent Aim (snap on LMB while enabled)", function(v)
    St.silentAim = v
end, St.silentAim)

makeToggle(legitSettings, "Show FOV Circle", function(v)
    St.showFov = v
    if not v and FovCircle then FovCircle.Visible = false end
    if not v and FovRing then FovRing.Visible = false end
end, St.showFov)

makeToggle(legitSettings, "Team Check", function(v)
    St.teamCheck = v
end, St.teamCheck)

makeSlider(legitSettings, "FOV (pixels)", {
    min = 20,
    max = 400,
    get = function() return St.fov end,
    set = function(v) St.fov = v end,
    fmt = function(v) return math.floor(v) .. "px" end,
})

makeSlider(legitSettings, "Smoothing", {
    min = 0.05,
    max = 1,
    get = function() return St.smooth end,
    set = function(v) St.smooth = v end,
    fmt = function(v) return string.format("%.2f", v) end,
})

makeCycle(legitSettings, "Target Priority", TARGET_PRIORITIES, function() return St.targetPriority end, function(v)
    St.targetPriority = v
end)

makeCycle(legitSettings, "Hit Part", HIT_PARTS, function() return St.hitPart end, function(v)
    St.hitPart = v
end)

local triggerBox = makeGroupbox(legitStack, "Triggerbot")
label(triggerBox, "Toggle ON — auto fires when a visible enemy is in your crosshair", 12, nil, 7)
label(triggerBox, "No key bind needed. Uses raycast + visible check.", 12, nil, 7)
Ref.triggerToggle = makeToggle(triggerBox, "Enable Triggerbot", function(v) St.triggerbot = v end, St.triggerbot)
makeSlider(triggerBox, "Crosshair Radius (px)", {
    min = 8, max = 80,
    get = function() return St.triggerRadius end,
    set = function(v) St.triggerRadius = v end,
    fmt = function(v) return math.floor(v) .. "px" end,
})
makeSlider(triggerBox, "Delay (seconds)", {
    min = 0, max = 0.5,
    get = function() return St.triggerDelay end,
    set = function(v) St.triggerDelay = v end,
    fmt = function(v) return string.format("%.3fs", v) end,
})
makeSlider(triggerBox, "Randomization", {
    min = 0, max = 0.2,
    get = function() return St.triggerRandom end,
    set = function(v) St.triggerRandom = v end,
    fmt = function(v) return string.format("%.3fs", v) end,
})
makeSlider(triggerBox, "Max Distance", {
    min = 50, max = 2000,
    get = function() return St.triggerMaxDist end,
    set = function(v) St.triggerMaxDist = v end,
    fmt = function(v) return math.floor(v) .. " studs" end,
})

-- ── Rage tab ──
Ref.rageBanner = label(rageStack, "No rage features active", 13, UDim2.fromOffset(0, 0), 6)
Ref.rageBanner.TextWrapped = true
Ref.rageBanner.Size = UDim2.new(1, -4, 0, 32)

local rageGuide = makeGroupbox(rageStack, "Quick Start")
label(rageGuide, "1) Enable Ragebot — locks ONE target, orbits + wallbang", 13, nil, 7)
label(rageGuide, "2) Press X — orbit locked target (third-person zoom, normal camera)", 13, nil, 7)
label(rageGuide, "Stays on same target until they die, then picks next", 13, nil, 7)

local rageKeys = makeGroupbox(rageStack, "Rage Keybinds")

local rageKeyRow = Instance.new("Frame")
rageKeyRow.BackgroundTransparency = 1
rageKeyRow.Size = UDim2.new(1, 0, 0, 16)
rageKeyRow.ZIndex = 6
rageKeyRow.Parent = rageKeys
Ref.rageKeyLbl = label(rageKeyRow, "Rage Key: [" .. keyLabel(St.rageKey) .. "]", 13, UDim2.fromOffset(0, 0), 7)
Ref.rageStatus = label(rageKeyRow, "OFF", 13, UDim2.new(1, -44, 0, 0), 7, Enum.TextXAlignment.Right)
Ref.rageStatus.Size = UDim2.fromOffset(40, 14)

Ref.rageModeLbl = label(rageKeys, "Rage Mode: Toggle", 13, nil, 7)

makeCycle(rageKeys, "Rage Mode", AIM_MODES, function() return St.rageMode end, function(v)
    St.rageMode = v
    if v ~= 2 then St.rageToggled = false end
    if v ~= 3 then St.rageHold = false end
end)

makeButton(rageKeys, "Set Rage Keybind", function()
    St.rebinding = "rage"
    if Ref.rageKeyLbl then
        Ref.rageKeyLbl.Text = "Rage Key: [ press a key... ]"
    end
end)

local rageFeatures = makeGroupbox(rageStack, "Rage Features")

Ref.ragebotToggle = makeToggle(rageFeatures, "Enable Ragebot", function(v)
    St.ragebot = v
    if v then
        St.wallbang = true
        St.autoFire = true
        St.desyncOrbit = true
        notify("Rage armed — press X. Locks one target + orbit view.", Accent)
    else
        St.rageToggled = false
        St.rageHold = false
        clearOrbitTarget()
        disableRageOrbitView()
    end
end, St.ragebot)

makeToggle(rageFeatures, "Auto Fire", function(v)
    St.autoFire = v
end, St.autoFire)

makeToggle(rageFeatures, "Instant Wallbang (raycast ignore map)", function(v)
    St.wallbang = v
end, St.wallbang)

makeToggle(rageFeatures, "Orbit Camera (see yourself circle target)", function(v)
    St.desyncOrbit = v
    if not v then
        clearOrbitTarget()
        disableRageOrbitView()
    end
end, St.desyncOrbit)

makeToggle(rageFeatures, "Death Barrier Disabler", function(v)
    St.barrierDisable = v
    if v then
        disableBarriers()
    else
        restoreBarriers()
    end
end, St.barrierDisable)

makeSlider(rageFeatures, "Orbit Radius", {
    min = 4,
    max = 40,
    get = function() return St.orbitRadius end,
    set = function(v) St.orbitRadius = v end,
    fmt = function(v) return math.floor(v) .. " studs" end,
})

makeSlider(rageFeatures, "Orbit Speed", {
    min = 1,
    max = 20,
    get = function() return St.orbitSpeed end,
    set = function(v) St.orbitSpeed = v end,
    fmt = function(v) return math.floor(v) end,
})

Ref.rageSpinToggle = makeToggle(rageFeatures, "Spin Bot (while rage active)", function(v) St.rageSpin = v end, St.rageSpin)
makeSlider(rageFeatures, "Spin Speed", {
    min = 2, max = 40,
    get = function() return St.rageSpinSpeed end,
    set = function(v) St.rageSpinSpeed = v end,
    fmt = function(v) return math.floor(v) end,
})
Ref.rageSpeedToggle = makeToggle(rageFeatures, "Speed Boost (while rage active)", function(v) St.rageSpeedBoost = v end, St.rageSpeedBoost)
makeSlider(rageFeatures, "Speed Multiplier", {
    min = 1, max = 5,
    get = function() return St.rageSpeedMult end,
    set = function(v) St.rageSpeedMult = v end,
    fmt = function(v) return string.format("%.1fx", v) end,
})

-- ── ESP tab ──
local camBox = makeGroupbox(espStack, "Camera & Chams")

makeToggle(camBox, "Third Person", function(v)
    St.thirdPerson = v
    if not v then restoreCamera() end
end, St.thirdPerson)

makeSlider(camBox, "Third Person Distance", {
    min = 4,
    max = 30,
    get = function() return St.thirdPersonDist end,
    set = function(v) St.thirdPersonDist = v end,
    fmt = function(v) return math.floor(v) .. " studs" end,
})

makeToggle(camBox, "Custom Camera FOV", function(v)
    St.camFovOverride = v
end, St.camFovOverride)

makeSlider(camBox, "Camera FOV", {
    min = 30,
    max = 120,
    get = function() return St.camFov end,
    set = function(v) St.camFov = v end,
    fmt = function(v) return math.floor(v) end,
})

makeToggle(camBox, "Self Chams", function(v)
    St.selfChams = v
    updateSelfChams()
end, St.selfChams)

makeToggle(camBox, "Player Chams", function(v)
    St.espChams = v
    if not v then
        for plr, e in pairs(EspStore) do
            if e.highlight then
                e.highlight:Destroy()
                e.highlight = nil
            end
        end
    end
end, St.espChams)

local espBox = makeGroupbox(espStack, "ESP Dashboard")

Ref.espStatus = label(espBox, "ESP: OFF", 13, nil, 7)

Ref.espEnableToggle = makeToggle(espBox, "Enable ESP", function(v)
    St.espEnabled = v
    if v then
        St.espTags = true
        St.espChams = true
    end
    if not v then
        for plr, _ in pairs(EspStore) do
            clearEspEntry(plr)
        end
    else
        for _, plr in ipairs(Players:GetPlayers()) do
            refreshEspForPlayer(plr)
        end
    end
end, St.espEnabled)

makeToggle(espBox, "Name Tags (BillboardGui)", function(v)
    St.espTags = v
end, St.espTags)

makeToggle(espBox, "2D Boxes (Drawing API)", function(v)
    St.espBoxes = v
end, St.espBoxes)

makeToggle(espBox, "Tracers (Drawing API)", function(v)
    St.espTracers = v
end, St.espTracers)

makeToggle(espBox, "Name + Distance (Drawing)", function(v)
    St.espNames = v
end, St.espNames)

makeToggle(espBox, "Health Bars", function(v)
    St.espHealth = v
end, St.espHealth)

makeSlider(espBox, "Max Distance", {
    min = 100,
    max = 5000,
    get = function() return St.espMaxDist end,
    set = function(v) St.espMaxDist = v end,
    fmt = function(v) return math.floor(v) .. " studs" end,
})

makeButton(espBox, "Refresh ESP", function()
    clearAllEsp()
    for _, plr in ipairs(Players:GetPlayers()) do
        refreshEspForPlayer(plr)
    end
end)

local extEspBox = makeGroupbox(espStack, "Extended ESP")
Ref.espSkelToggle = makeToggle(extEspBox, "Skeleton (R6/R15)", function(v) St.espSkeleton = v end, St.espSkeleton)
Ref.espHeadToggle = makeToggle(extEspBox, "Head Circle", function(v) St.espHeadCircle = v end, St.espHeadCircle)
Ref.espViewToggle = makeToggle(extEspBox, "View Line (look dir)", function(v) St.espViewLine = v end, St.espViewLine)
Ref.espSnapToggle = makeToggle(extEspBox, "Snaplines (bottom center)", function(v) St.espSnaplines = v end, St.espSnaplines)
Ref.espOffToggle = makeToggle(extEspBox, "Offscreen Arrows", function(v) St.espOffscreen = v end, St.espOffscreen)
Ref.espToolToggle = makeToggle(extEspBox, "Tool Name (Billboard)", function(v) St.espToolName = v end, St.espToolName)
Ref.espTeamToggle = makeToggle(extEspBox, "Team Color ESP", function(v) St.espTeamColor = v end, St.espTeamColor)
Ref.espVisToggle = makeToggle(extEspBox, "Visible/Hidden Colors", function(v) St.espVisColor = v end, St.espVisColor)
label(extEspBox, "Visible=green Hidden=red (raycast)", 12, nil, 7)

-- ── World tab ──
local worldBox = makeGroupbox(worldStack, "World Visuals")
VisualToggles.fullbright = makeToggle(worldBox, "Fullbright", function(v) VisualState.fullbright = v applyVisualEffects() end, false)
VisualToggles.noShadows = makeToggle(worldBox, "No Shadows", function(v) VisualState.noShadows = v applyVisualEffects() end, false)
VisualToggles.clockOverride = makeToggle(worldBox, "Override Clock Time", function(v) VisualState.clockOverride = v applyVisualEffects() end, false)
VisualSliders.worldTintHue = makeSlider(worldBox, "World Tint Hue", {
    min = 0, max = 1, get = function() return VisualState.worldTintHue end,
    set = function(v) VisualState.worldTintHue = v applyVisualEffects() end,
    fmt = function(v) return string.format("%.0f%%", v * 100) end,
})
VisualSliders.worldTintStrength = makeSlider(worldBox, "Tint Strength", {
    min = 0, max = 0.85, get = function() return VisualState.worldTintStrength end,
    set = function(v) VisualState.worldTintStrength = v applyVisualEffects() end,
    fmt = function(v) return string.format("%.0f%%", v * 100) end,
})
VisualSliders.saturation = makeSlider(worldBox, "Saturation", {
    min = -1, max = 1, get = function() return VisualState.saturation end,
    set = function(v) VisualState.saturation = v applyVisualEffects() end,
    fmt = function(v) return string.format("%.2f", v) end,
})
VisualSliders.contrast = makeSlider(worldBox, "Contrast", {
    min = -1, max = 1, get = function() return VisualState.contrast end,
    set = function(v) VisualState.contrast = v applyVisualEffects() end,
    fmt = function(v) return string.format("%.2f", v) end,
})
VisualSliders.brightness = makeSlider(worldBox, "Brightness", {
    min = -1, max = 1, get = function() return VisualState.brightness end,
    set = function(v) VisualState.brightness = v applyVisualEffects() end,
    fmt = function(v) return string.format("%.2f", v) end,
})
VisualSliders.blurAmount = makeSlider(worldBox, "Blur", {
    min = 0, max = 56, get = function() return VisualState.blurAmount end,
    set = function(v) VisualState.blurAmount = v applyVisualEffects() end,
    fmt = function(v) return math.floor(v) .. "px" end,
})
VisualSliders.bloomAmount = makeSlider(worldBox, "Bloom", {
    min = 0, max = 2, get = function() return VisualState.bloomAmount end,
    set = function(v) VisualState.bloomAmount = v applyVisualEffects() end,
    fmt = function(v) return string.format("%.2f", v) end,
})
VisualSliders.clockTime = makeSlider(worldBox, "Clock Time", {
    min = 0, max = 24, get = function() return VisualState.clockTime end,
    set = function(v) VisualState.clockTime = v if VisualState.clockOverride then applyVisualEffects() end end,
    fmt = function(v) return string.format("%.1fh", v) end,
})
makeButton(worldBox, "Reset World Visuals", function() resetAllVisuals() notify("World visuals reset", Accent) end)
makeButton(worldBox, "Preset: Sunset", applyWorldPreset_Sunset)
makeButton(worldBox, "Preset: Night", applyWorldPreset_Night)
makeButton(worldBox, "Preset: Neon", applyWorldPreset_Neon)
makeButton(worldBox, "Preset: Muted", applyWorldPreset_Muted)

-- ── Move tab ──
local moveBox = makeGroupbox(moveStack, "Movement")
label(moveBox, "WalkSpeed / JumpPower removed — use game defaults", 12, nil, 7)
Ref.flyToggle = makeToggle(moveBox, "Fly (WASD + Space/Ctrl)", function(v) St.fly = v end, St.fly)
makeSlider(moveBox, "Fly Speed", {
    min = 20, max = 400, get = function() return St.flySpeed end,
    set = function(v) St.flySpeed = v end, fmt = function(v) return math.floor(v) end,
})
Ref.noclipToggle = makeToggle(moveBox, "Noclip", function(v) St.noclip = v if not v then setNoclip(false) end end, St.noclip)
makeButton(moveBox, "Restore Movement Defaults", restoreMovement)

-- ── Players tab ──
local playersBox = makeGroupbox(playersStack, "Player List")
label(playersBox, "Click player to set/clear priority target", 12, nil, 7)
PlayerListFrame = Instance.new("Frame")
PlayerListFrame.BackgroundTransparency = 1
PlayerListFrame.Size = UDim2.new(1, 0, 0, 0)
PlayerListFrame.AutomaticSize = Enum.AutomaticSize.Y
PlayerListFrame.ZIndex = 6
PlayerListFrame.Parent = playersBox
Instance.new("UIListLayout", PlayerListFrame).Padding = UDim.new(0, 4)
rebuildPlayerList()
connect(Players.PlayerAdded, rebuildPlayerList)
connect(Players.PlayerRemoving, rebuildPlayerList)

-- ── Config tab ──
local profileBox = makeGroupbox(configStack, "Profiles")
ConfigStatusLbl = label(profileBox, "Ready", 13, nil, 7)
local nameRow = Instance.new("Frame")
nameRow.BackgroundTransparency = 1
nameRow.Size = UDim2.new(1, 0, 0, 22)
nameRow.ZIndex = 6
nameRow.Parent = profileBox
label(nameRow, "Name:", 13, UDim2.fromOffset(0, 3), 7)
ProfileNameBox = Instance.new("TextBox")
ProfileNameBox.Size = UDim2.new(1, -50, 0, 18)
ProfileNameBox.Position = UDim2.fromOffset(46, 2)
ProfileNameBox.BackgroundColor3 = MAIN
ProfileNameBox.BorderColor3 = OUTLINE
ProfileNameBox.Font = FONT
ProfileNameBox.TextSize = 13
ProfileNameBox.TextColor3 = TEXT
ProfileNameBox.Text = ConfigMeta.lastProfile
ProfileNameBox.ClearTextOnFocus = false
ProfileNameBox.ZIndex = 7
ProfileNameBox.Parent = nameRow
ProfileListFrame = Instance.new("Frame")
ProfileListFrame.BackgroundTransparency = 1
ProfileListFrame.Size = UDim2.new(1, 0, 0, 0)
ProfileListFrame.AutomaticSize = Enum.AutomaticSize.Y
ProfileListFrame.ZIndex = 6
ProfileListFrame.Parent = profileBox
Instance.new("UIListLayout", ProfileListFrame).Padding = UDim.new(0, 4)
makeButton(profileBox, "Save Profile", function() saveProfile() end)
makeButton(profileBox, "Load Profile", function() loadProfile() end)
makeButton(profileBox, "Delete Profile", function() deleteProfile() end)
makeButton(profileBox, "Export to Clipboard", exportProfileToClipboard)
makeButton(profileBox, "Import from Clipboard", function() importProfileFromClipboard(true) end)
Ref.autoSaveToggle = makeToggle(profileBox, "Auto-Save on Change", function(v) St.autoSaveProfiles = v end, St.autoSaveProfiles)

local themeBox = makeGroupbox(configStack, "Theme Presets")
for name, color in pairs(ACCENTS) do
    makeButton(themeBox, name, function()
        St.themeName = name
        applyAccent(color)
        notify("Theme: " .. name, color)
    end)
end

-- ── Misc tab ──
local miscBox = makeGroupbox(miscStack, "Misc")
makeButton(miscBox, "Rescan Barriers", rescanBarriers)
makeButton(miscBox, "Unload Script", unload)
Ref.drawingStatus = label(miscBox, "", 13, nil, 7)
Ref.fpsLbl = label(miscBox, "FPS: --", 13, nil, 7)
Ref.execLbl = label(miscBox, "Executor: " .. getExecutorName(), 13, nil, 7)
Ref.showFpsToggle = makeToggle(miscBox, "Show FPS Counter", function(v) St.showFps = v end, St.showFps)
Ref.hideWmToggle = makeToggle(miscBox, "Hide Watermark", function(v)
    St.hideWatermark = v
    if WmOuter then WmOuter.Visible = not v end
end, St.hideWatermark)
Ref.featureCheckLbl = label(miscBox, "Feature checklist loads at runtime", 12, nil, 7)
label(miscBox, "RightShift / Insert — hide menu", 13, nil, 7)
label(miscBox, "Legit: E aim | Rage: X rage | Profiles in Config", 13, nil, 7)

-- Watermark
WmOuter, WmInner = bordered(ScreenGui, MAIN, Accent, UDim2.fromOffset(118, 22), UDim2.new(1, -128, 1, -32), 20)
WmOuter.AnchorPoint = Vector2.new(0, 1)
ThemeParts.wmInner = WmInner
label(WmInner, "Cobalt Redux", 12, UDim2.fromOffset(6, 3), 22)

ensureConfigDirs()
readMeta()
refreshProfileList()

-- Activate first tab
TabPages.Legit.active = true
TabPages.Legit.page.Visible = true
TabPages.Legit.btnInner.BackgroundColor3 = MAIN
TabPages.Legit.btnInner.BorderColor3 = Accent
ActiveTab = TabPages.Legit

updateStatusLabels()

-- Window drag (automation pattern)
local winDrag, winDragStart, winStart = false, nil, nil
TitleDrag.MouseButton1Down:Connect(function()
    winDrag = true
    winDragStart = UserInputService:GetMouseLocation()
    winStart = WindowOuter.AbsolutePosition
end)

connect(UserInputService.InputChanged, function(i)
    if i.UserInputType ~= Enum.UserInputType.MouseMovement then return end
    if not winDrag then return end
    local m = UserInputService:GetMouseLocation()
    local d = m - winDragStart
    WindowOuter.Position = UDim2.fromOffset(winStart.X + d.X, winStart.Y + d.Y)
end)

connect(UserInputService.InputEnded, function(i)
    if i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    if not winDrag then return end
    winDrag = false
    local cam = workspace.CurrentCamera
    if cam then
        local vp = cam.ViewportSize
        local abs = WindowOuter.AbsolutePosition
        local sz = WindowOuter.AbsoluteSize
        local x, y = abs.X, abs.Y
        if x < SNAP_DIST then x = 0 end
        if y < SNAP_DIST then y = 0 end
        if x + sz.X > vp.X - SNAP_DIST then x = vp.X - sz.X end
        if y + sz.Y > vp.Y - SNAP_DIST then y = vp.Y - sz.Y end
        WindowOuter.Position = UDim2.fromOffset(x, y)
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- INPUT
-- ═══════════════════════════════════════════════════════════════

connect(UserInputService.InputBegan, function(input, gp)
    if St.rebinding == "aim" then
        if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode ~= Enum.KeyCode.Unknown then
            St.aimBindType = "key"
            St.aimKey = input.KeyCode
            St.rebinding = nil
            updateStatusLabels()
            notify("Aim hold key: " .. keyLabel(St.aimKey), Accent)
        elseif isMouseBindInput(input) then
            St.aimBindType = "mouse"
            St.aimMouse = input.UserInputType
            St.rebinding = nil
            updateStatusLabels()
            notify("Aim hold key: " .. mouseBindLabel(St.aimMouse), Accent)
        end
        return
    end
    if St.rebinding == "rage" and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode ~= Enum.KeyCode.Unknown then
        St.rageKey = input.KeyCode
        St.rebinding = nil
        updateStatusLabels()
        return
    end

    if input.UserInputType == Enum.UserInputType.Keyboard then
        for _, key in ipairs(HIDE_KEYS) do
            if input.KeyCode == key then
                setUIVisible(St.uiHidden)
                return
            end
        end
    end

    if inputMatchesAimBind(input) then
        handleAimBindBegan()
        return
    end

    if gp then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

    if input.KeyCode == St.rageKey and St.ragebot then
        if St.rageMode == 2 then
            St.rageToggled = not St.rageToggled
            if St.rageToggled then
                local t = lockOrbitTarget()
                if t then
                    notify("Locked: " .. t.DisplayName, Color3.fromRGB(255, 120, 80))
                end
            else
                clearOrbitTarget()
                disableRageOrbitView()
            end
        elseif St.rageMode == 3 then
            St.rageHold = true
            local t = lockOrbitTarget()
            if t then
                notify("Locked: " .. t.DisplayName, Color3.fromRGB(255, 120, 80))
            end
        end
        updateStatusLabels()
        if rageActive() then
            notify("Rage ON — orbiting locked target", Color3.fromRGB(255, 120, 80))
        end
    end
end)

connect(UserInputService.InputEnded, function(input, gp)
    if inputMatchesAimBind(input) then
        handleAimBindEnded()
        return
    end
    if gp then return end
    if input.KeyCode == St.rageKey and St.rageMode == 3 then
        St.rageHold = false
        clearOrbitTarget()
        disableRageOrbitView()
        updateStatusLabels()
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- ESP HOOKS
-- ═══════════════════════════════════════════════════════════════

connect(Players.PlayerAdded, hookPlayerEsp)
connect(Players.PlayerRemoving, function(plr)
    clearEspEntry(plr)
end)

for _, plr in ipairs(Players:GetPlayers()) do
    hookPlayerEsp(plr)
end

connect(LocalPlayer.CharacterAdded, function()
    task.wait(0.35)
    local hum = getHum(getChar(LocalPlayer))
    if hum then
        DefaultWalkSpeed = hum.WalkSpeed
        DefaultJumpPower = hum.JumpPower
    end
    updateSelfChams()
    DefaultFov = workspace.CurrentCamera and workspace.CurrentCamera.FieldOfView or DefaultFov
end)

connect(workspace:GetPropertyChangedSignal("CurrentCamera"), function()
    if EspFolder and EspFolder.Parent ~= workspace.CurrentCamera then
        ensureEspFolder()
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- LOOPS (throttled)
-- ═══════════════════════════════════════════════════════════════

local espTick = 0
local camTick = 0
local uiTick = 0

connect(RunService.Heartbeat, function(dt)
    if not St.running then return end

    refreshAimHoldState()
    updateOrbit(dt)
    updateMovement(dt)
    updateRageExtras(dt)
    triggerbotStep()

    if St.barrierDisable then
        disableBarriers()
    end
end)

connect(RunService.RenderStepped, function(dt)
    if not St.running then return end

    combatStep()
    silentAimStep()
    applyVisualEffects()

    if St.showFov then
        updateFov()
    elseif FovCircle then
        FovCircle.Visible = false
    end

    espTick = espTick + dt
    if espTick >= 0.125 then
        espTick = 0
        if St.espEnabled or St.espChams then
            updateEsp()
        end
    end

    camTick = camTick + dt
    if camTick >= 1 / 30 then
        camTick = 0
        if St.thirdPerson and not (rageActive() and St.desyncOrbit) then
            updateThirdPerson()
        else
            local cam = workspace.CurrentCamera
            local hum = getHum(getChar(LocalPlayer))
            if cam and hum and cam.CameraType == Enum.CameraType.Scriptable then
                cam.CameraType = Enum.CameraType.Custom
                cam.CameraSubject = hum
            end
        end
        if St.camFovOverride then
            local cam = workspace.CurrentCamera
            if cam then cam.FieldOfView = St.camFov end
        end
        if St.selfChams then
            updateSelfChams()
        end
    end

    uiTick = uiTick + dt
    if uiTick >= 0.15 then
        uiTick = 0
        updateStatusLabels()
        updatePlayerList()
        if Ref.fpsLbl and St.showFps then
            Ref.fpsLbl.Text = string.format("FPS: %d", math.floor(Stats.fps))
        end
    end
    Stats.fpsTick = Stats.fpsTick + dt
    if Stats.fpsTick >= 0.5 then
        Stats.fps = 1 / math.max(dt, 0.001)
        Stats.fpsTick = 0
    end
end)

task.defer(function()
    local cam = workspace.CurrentCamera
    if cam then
        DefaultFov = cam.FieldOfView
    end
    updateFov()
end)


print("[Cobalt Redux] Loaded - Legit/Rage/ESP/World/Move/Players/Config/Misc tabs ready.")
task.defer(function()
    notify("Menu loaded — RightShift to hide | E = aim | X = rage", Accent)
end)
