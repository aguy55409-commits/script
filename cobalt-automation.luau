--[[
    Cobalt Automation â€” Linoria-style GUI
]]

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer

-- â”€â”€ State (single table to save local registers) â”€â”€
local St = {
    running = true,
    click = false,
    upgrade = false,
    antiAfk = false,
    autoTower = false,
    rebirthPriority = false,
    hideWatermark = false,
    autoSaveProfiles = true,
    autoTowerOnStart = false,
    towerInterval = 7 * 60,
    clickThrottle = 0,
    clickBurst = 3,
    upgradeDelay = 0.15,
    turboUpgrades = false,
    detailedWatermark = true,
    autoClickOnStart = false,
    autoUpgradeOnStart = false,
    uiHidden = false,
    lastClickTime = 0,
    speed = false,
    speedVal = 100,
    fly = false,
    flySpeed = 150,
    noclip = false,
    infJump = false,
    lowGrav = false,
    spin = false,
    spinSpeed = 12,
    chaosPulse = false,
    sparkleTrail = false,
    roundRobin = false,
    autoHideOnClick = false,
    milestoneStep = 10000,
    showFps = true,
    charScale = 1,
    headless = false,
    invisible = false,
    rainbowBody = false,
    flameHead = false,
    upsideDown = false,
    billboard = false,
    billboardText = "silly",
    bigHead = false,
    highlightOthers = false,
    rainbowOthers = false,
    spinOthers = false,
    giantOthers = false,
    otherScale = 2,
}
local CharExtras = { fire = nil, billboard = nil, sparkles = nil, others = {}, lastScale = 1 }
local Ref = {}
local ProfileNameBox, ConfigStatusLbl, ProfileListFrame
local VisualHuePreview
local applyVisualEffects, resetAllVisuals, applyWeirdPreset
local runAutoTower
local saveProfile, loadProfile, deleteProfile, exportProfileToClipboard, importProfileFromClipboard, refreshProfileList

local MIN_THROTTLE, MAX_THROTTLE = 0, 0.5
local MIN_CLICK_BURST, MAX_CLICK_BURST = 1, 8
local MIN_UPGRADE_DELAY, MAX_UPGRADE_DELAY = 0.03, 2
local SNAP_DIST = 15
local HIDE_KEYS = { Enum.KeyCode.RightShift, Enum.KeyCode.Insert }
local CLICK_HOTKEY = Enum.KeyCode.F
local PANIC_KEY = Enum.KeyCode.End
local UPGRADE_HOTKEY = Enum.KeyCode.G
local TOWER_HOTKEY = Enum.KeyCode.T
local AFK_HOTKEY = Enum.KeyCode.H
local CONFIG_DIR = "cobalt-automation"
local PROFILES_DIR = CONFIG_DIR .. "/profiles"
local META_PATH = CONFIG_DIR .. "/meta.json"
local LEGACY_CONFIG_PATH = "cobalt-automation.json"
local TOWER_POS = Vector3.new(229, 278, -215)
local W_HOLD_TIME = 1.0
local MIN_TOWER_MINUTES, MAX_TOWER_MINUTES = 1, 15

local Stats = {
    start = tick(), clicks = 0, cps = 0, cpsTick = 0, upgrades = 0,
    fps = 0, fpsTick = 0, rrIndex = 1, nextMilestone = 10000, flashUntil = 0,
    defaultGravity = workspace.Gravity,
}
local UpgradeChoices = { Rebirth = true, ClickMulti = true, AutoclickPower = true }
local Connections = {}
local ConfigMeta = { lastProfile = "default", profiles = { "default" } }
local VisualSliders, VisualToggles

local VisualState = {
    worldTintHue = 0,
    worldTintStrength = 0,
    saturation = 0,
    contrast = 0,
    brightness = 0,
    blurAmount = 0,
    bloomAmount = 0,
    fullbright = false,
    fovOverride = false,
    fov = 70,
    clockOverride = false,
    clockTime = 14,
    guiHue = 0.58,
    customGuiColor = false,
    rainbowGui = false,
    rainbowWorld = false,
    rainbowSpeed = 1,
    drunkCam = false,
    charHighlight = false,
    charHighlightHue = 0.85,
    noShadows = false,
}
local OriginalLighting = {}
local VisualCC, VisualBlur, VisualBloom, ScreenTint, CharHighlight
local RainbowHue = 0

local WEIRD_PRESETS = {
    Acid = {
        worldTintHue = 0.33, worldTintStrength = 0.55, saturation = 0.9, contrast = 0.35,
        brightness = 0.05, fovOverride = true, fov = 105, clockOverride = true, clockTime = 15,
        bloomAmount = 0.4, drunkCam = true,
    },
    ["Blood Moon"] = {
        worldTintHue = 0.98, worldTintStrength = 0.5, saturation = 0.2, contrast = 0.55,
        brightness = -0.15, clockOverride = true, clockTime = 20.5, bloomAmount = 0.6,
    },
    Dream = {
        worldTintHue = 0.82, worldTintStrength = 0.4, saturation = -0.45, contrast = -0.1,
        blurAmount = 18, bloomAmount = 1.2, fovOverride = true, fov = 95,
    },
    Void = {
        worldTintHue = 0.72, worldTintStrength = 0.65, saturation = -0.85, contrast = 0.75,
        brightness = -0.25, clockOverride = true, clockTime = 0, noShadows = true,
    },
    Disco = {
        rainbowGui = true, rainbowWorld = true, rainbowSpeed = 2.5,
        saturation = 0.65, bloomAmount = 0.9, drunkCam = true, fovOverride = true, fov = 90,
    },
    ["Deep Fried"] = {
        worldTintHue = 0.12, worldTintStrength = 0.35, saturation = 1, contrast = 0.85,
        brightness = 0.25, fovOverride = true, fov = 115, bloomAmount = 0.5,
    },
    Inverted = {
        worldTintHue = 0.5, worldTintStrength = 0.25, saturation = -1, contrast = 1, brightness = 0.1,
    },
    Fullbright = {
        fullbright = true, saturation = -0.6, contrast = 0.15, worldTintStrength = 0.1, worldTintHue = 0.15,
    },
}

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ClickEvent = Remotes:WaitForChild("ClickAction")
local UpgradeEvent = Remotes:WaitForChild("PurchaseClickUpgrade")
local Upgrades = {"Rebirth", "ClickMulti", "AutoclickPower"}
local UpgradeLabels = { Rebirth = "Rebirth", ClickMulti = "Click Multi", AutoclickPower = "Autoclick Power" }

local GuiParent = (cloneref and cloneref(CoreGui)) or CoreGui
local old = GuiParent:FindFirstChild("CobaltAuto")
if old then old:Destroy() end
local oldVis = GuiParent:FindFirstChild("CobaltVisualOverlay")
if oldVis then oldVis:Destroy() end

-- â”€â”€ Linoria palette â”€â”€
local FONT = Enum.Font.Code
local BLACK = Color3.new(0, 0, 0)
local MAIN = Color3.fromRGB(28, 28, 28)
local BG = Color3.fromRGB(20, 20, 20)
local OUTLINE = Color3.fromRGB(50, 50, 50)
local TEXT = Color3.fromRGB(255, 255, 255)

local ACCENTS = {
    Cobalt = Color3.fromRGB(0, 85, 255),
    Pink = Color3.fromRGB(255, 105, 180),
    Midnight = Color3.fromRGB(130, 90, 255),
    Nebula = Color3.fromRGB(180, 90, 255),
}
local Accent = ACCENTS.Cobalt

local ThemeParts = { toggles = {}, fills = {}, highlights = {}, tabs = {}, wmParts = {} }

function darker(c)
    local h, s, v = Color3.toHSV(c)
    return Color3.fromHSV(h, s, v / 1.5)
end

function clamp(n, lo, hi)
    return math.max(lo, math.min(hi, n))
end

function fmtTime(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor(seconds % 3600 / 60)
    local s = math.floor(seconds % 60)
    return string.format("%02d:%02d:%02d", h, m, s)
end

function fmtThrottle(t)
    return t <= 0 and "MAX" or string.format("%.3fs", t)
end

function fmtDelay(t)
    return string.format("%.2fs", t)
end

function fmtMinutes(seconds)
    return string.format("%.0fm", seconds / 60)
end

function getThemeName()
    for name, color in pairs(ACCENTS) do
        if color == Accent then return name end
    end
    return "Cobalt"
end

function sanitizeProfileName(name)
    name = string.gsub(string.lower(name or ""), "%s+", "-")
    name = string.gsub(name, "[^%w%-_]", "")
    if name == "" then return "default" end
    return name:sub(1, 32)
end

function hasFileApi()
    return writefile and readfile and isfile
end

function ensureConfigDirs()
    if not makefolder then return end
    pcall(function()
        if isfolder and not isfolder(CONFIG_DIR) then makefolder(CONFIG_DIR) end
        if isfolder and not isfolder(PROFILES_DIR) then makefolder(PROFILES_DIR) end
    end)
end

function setConfigStatus(msg)
    if ConfigStatusLbl then ConfigStatusLbl.Text = msg end
end

function readMeta()
    if not (hasFileApi() and isfile(META_PATH)) then return end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(META_PATH))
    end)
    if ok and type(data) == "table" then
        ConfigMeta.lastProfile = data.lastProfile or ConfigMeta.lastProfile
        if type(data.profiles) == "table" then
            ConfigMeta.profiles = data.profiles
        end
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
    local names = {}
    local seen = {}
    if listfiles and isfolder and isfolder(PROFILES_DIR) then
        for _, file in ipairs(listfiles(PROFILES_DIR)) do
            local name = file:match("([^/\\]+)%.json$")
            if name and not seen[name] then
                seen[name] = true
                table.insert(names, name)
            end
        end
    end
    for _, name in ipairs(ConfigMeta.profiles) do
        if not seen[name] then
            seen[name] = true
            table.insert(names, name)
        end
    end
    table.sort(names)
    return names
end

function copyToClipboard(text)
    if setclipboard then
        setclipboard(text)
        return true
    end
    if toclipboard then
        toclipboard(text)
        return true
    end
    return false
end

function readClipboard()
    if getclipboard then return getclipboard() end
    if fromclipboard then return fromclipboard() end
    return nil
end

function fmtHue(h)
    return string.format("hue %.0f%%", (h % 1) * 100)
end

function hueColor(h, s, v)
    return Color3.fromHSV(h % 1, s or 1, v or 1)
end

function colorToTable(c)
    return { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) }
end

function tableToColor(t)
    if type(t) ~= "table" then return nil end
    return Color3.fromRGB(t[1] or 255, t[2] or 255, t[3] or 255)
end

function fmtCount(n)
    if n >= 1e6 then return string.format("%.1fm", n / 1e6) end
    if n >= 1e3 then return string.format("%.1fk", n / 1e3) end
    return tostring(n)
end

function connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(Connections, c)
    return c
end

function textBounds(text, size)
    local s = TextService:GetTextSize(text, size, FONT, Vector2.new(1920, 1080))
    return s.X, s.Y
end

function passthrough(obj)
    obj.Active = false
end

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
    for name, tab in pairs(ThemeParts.tabs) do
        local active = tab.active
        tab.btnInner.BackgroundColor3 = active and MAIN or BG
        tab.btnInner.BorderColor3 = active and Accent or OUTLINE
    end
    if ThemeParts.windowInner then
        ThemeParts.windowInner.BorderColor3 = Accent
    end
    if ThemeParts.wmInner then
        ThemeParts.wmInner.BorderColor3 = Accent
    end
    if ThemeParts.wmGrad then
        ThemeParts.wmGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, darker(MAIN)),
            ColorSequenceKeypoint.new(1, MAIN),
        })
    end
end

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
-- SCREEN GUI
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "CobaltAuto"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = GuiParent

if syn and syn.protect_gui then
    syn.protect_gui(ScreenGui, GuiParent)
elseif protectgui then
    protectgui(ScreenGui, GuiParent)
end

local VisualOverlayGui = Instance.new("ScreenGui")
VisualOverlayGui.Name = "CobaltVisualOverlay"
VisualOverlayGui.ResetOnSpawn = false
VisualOverlayGui.IgnoreGuiInset = true
VisualOverlayGui.DisplayOrder = -100
VisualOverlayGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
VisualOverlayGui.Parent = GuiParent

if syn and syn.protect_gui then
    syn.protect_gui(VisualOverlayGui, GuiParent)
elseif protectgui then
    protectgui(VisualOverlayGui, GuiParent)
end

ScreenTint = Instance.new("Frame")
ScreenTint.Name = "WorldTint"
ScreenTint.Size = UDim2.fromScale(1, 1)
ScreenTint.BackgroundColor3 = Color3.new(1, 1, 1)
ScreenTint.BackgroundTransparency = 1
ScreenTint.BorderSizePixel = 0
ScreenTint.Active = false
ScreenTint.ZIndex = 1
ScreenTint.Parent = VisualOverlayGui

function captureLightingDefaults()
    if OriginalLighting.captured then return end
    OriginalLighting = {
        captured = true,
        Ambient = Lighting.Ambient,
        OutdoorAmbient = Lighting.OutdoorAmbient,
        Brightness = Lighting.Brightness,
        ClockTime = Lighting.ClockTime,
        GlobalShadows = Lighting.GlobalShadows,
        ColorShift_Top = Lighting.ColorShift_Top,
        ColorShift_Bottom = Lighting.ColorShift_Bottom,
        EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
        EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
    }
end

captureLightingDefaults()

VisualCC = Instance.new("ColorCorrectionEffect")
VisualCC.Name = "CobaltCC"
VisualCC.Enabled = true
VisualCC.Parent = Lighting

VisualBlur = Instance.new("BlurEffect")
VisualBlur.Name = "CobaltBlur"
VisualBlur.Size = 0
VisualBlur.Parent = Lighting

VisualBloom = Instance.new("BloomEffect")
VisualBloom.Name = "CobaltBloom"
VisualBloom.Intensity = 0
VisualBloom.Size = 24
VisualBloom.Threshold = 0.8
VisualBloom.Parent = Lighting

function updateCharHighlight()
    local char = LocalPlayer.Character
    if not CharHighlight then
        CharHighlight = Instance.new("Highlight")
        CharHighlight.Name = "CobaltCharHighlight"
        CharHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    end
    if VisualState.charHighlight and char then
        local c = hueColor(VisualState.charHighlightHue, 1, 1)
        CharHighlight.FillColor = c
        CharHighlight.OutlineColor = c
        CharHighlight.FillTransparency = 0.55
        CharHighlight.OutlineTransparency = 0
        CharHighlight.Parent = char
    else
        CharHighlight.Parent = nil
    end
end

function clearVisualEffects()
    if ScreenTint then
        ScreenTint.BackgroundTransparency = 1
    end
    if VisualCC then
        VisualCC.Enabled = false
        VisualCC.TintColor = Color3.new(1, 1, 1)
        VisualCC.Saturation = 0
        VisualCC.Contrast = 0
        VisualCC.Brightness = 0
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
    updateCharHighlight()
end

function anyVisualsActive()
    return VisualState.worldTintStrength > 0
        or VisualState.saturation ~= 0
        or VisualState.contrast ~= 0
        or VisualState.brightness ~= 0
        or VisualState.blurAmount > 0
        or VisualState.bloomAmount > 0
        or VisualState.fullbright
        or VisualState.noShadows
        or VisualState.clockOverride
        or VisualState.customGuiColor
        or VisualState.rainbowGui
        or VisualState.rainbowWorld
        or VisualState.charHighlight
        or VisualState.fovOverride
        or VisualState.drunkCam
end

applyVisualEffects = function()
    if not anyVisualsActive() then
        clearVisualEffects()
        return
    end

    captureLightingDefaults()

    local tint = hueColor(VisualState.worldTintHue, 0.95, 1)
    local useOverlay = VisualState.worldTintStrength > 0 or VisualState.rainbowWorld
    local useColorGrade = useOverlay
        or VisualState.saturation ~= 0
        or VisualState.contrast ~= 0
        or VisualState.brightness ~= 0

    if ScreenTint then
        if useOverlay then
            ScreenTint.BackgroundColor3 = tint
            ScreenTint.BackgroundTransparency = 1 - clamp(VisualState.worldTintStrength, 0, 0.85)
        else
            ScreenTint.BackgroundTransparency = 1
        end
    end

    if VisualCC then
        if useColorGrade then
            VisualCC.Enabled = true
            VisualCC.TintColor = tint
            VisualCC.Saturation = clamp(VisualState.saturation, -1, 1)
            VisualCC.Contrast = clamp(VisualState.contrast, -1, 1)
            VisualCC.Brightness = clamp(VisualState.brightness, -1, 1)
        else
            VisualCC.Enabled = false
            VisualCC.TintColor = Color3.new(1, 1, 1)
            VisualCC.Saturation = 0
            VisualCC.Contrast = 0
            VisualCC.Brightness = 0
        end
    end

    if VisualBlur then
        VisualBlur.Size = VisualState.blurAmount > 0 and clamp(VisualState.blurAmount, 0, 56) or 0
    end

    if VisualBloom then
        VisualBloom.Intensity = VisualState.bloomAmount > 0 and clamp(VisualState.bloomAmount, 0, 2) or 0
    end

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

    if VisualState.noShadows and not VisualState.fullbright then
        Lighting.GlobalShadows = false
    end

    if VisualState.clockOverride then
        Lighting.ClockTime = VisualState.clockTime
    elseif OriginalLighting.captured then
        Lighting.ClockTime = OriginalLighting.ClockTime
    end

    if VisualState.customGuiColor and not VisualState.rainbowGui then
        applyAccent(hueColor(VisualState.guiHue, 0.85, 1))
    end

    if VisualHuePreview then
        VisualHuePreview.BackgroundColor3 = hueColor(VisualState.worldTintHue, 1, 1)
    end

    updateCharHighlight()
end

function syncVisualControls()
    if not VisualSliders then return end
    for key, slider in pairs(VisualSliders) do
        if VisualState[key] ~= nil then slider.Set(VisualState[key]) end
    end
    if VisualToggles then
        for key, toggle in pairs(VisualToggles) do
            if VisualState[key] ~= nil then toggle.Set(VisualState[key]) end
        end
        if VisualToggles.worldOverlay then
            VisualToggles.worldOverlay.Set(VisualState.worldTintStrength > 0)
        end
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
    VisualState.fovOverride = false
    VisualState.fov = 70
    VisualState.clockOverride = false
    VisualState.clockTime = 14
    VisualState.guiHue = 0.58
    VisualState.customGuiColor = false
    VisualState.rainbowGui = false
    VisualState.rainbowWorld = false
    VisualState.rainbowSpeed = 1
    VisualState.drunkCam = false
    VisualState.charHighlight = false
    VisualState.charHighlightHue = 0.85
    VisualState.noShadows = false
    syncVisualControls()
    applyAccent(ACCENTS.Cobalt)
    clearVisualEffects()
    local cam = workspace.CurrentCamera
    if cam then cam.FieldOfView = 70 end
end

applyWeirdPreset = function(name)
    local preset = WEIRD_PRESETS[name]
    if not preset then return end
    for key, val in pairs(preset) do
        VisualState[key] = val
    end
    syncVisualControls()
    applyVisualEffects()
end

connect(LocalPlayer.CharacterAdded, function(char)
    task.wait(0.2)
    updateCharHighlight()
end)

-- â”€â”€ Linoria window â”€â”€
local WindowOuter = Instance.new("Frame")
WindowOuter.Name = "Window"
WindowOuter.Size = UDim2.fromOffset(420, 540)
WindowOuter.Position = UDim2.fromOffset(120, 80)
WindowOuter.BackgroundColor3 = BLACK
WindowOuter.BorderSizePixel = 0
WindowOuter.Parent = ScreenGui

local _, WindowInner = bordered(WindowOuter, MAIN, Accent, UDim2.fromScale(1, 1), UDim2.fromOffset(1, 1), 1)
ThemeParts.windowInner = WindowInner

label(WindowInner, "Cobalt Automation", 14, UDim2.fromOffset(7, 4), 3)

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

local TabArea = Instance.new("Frame")
TabArea.BackgroundTransparency = 1
TabArea.Position = UDim2.fromOffset(8, 8)
TabArea.Size = UDim2.new(1, -16, 0, 22)
TabArea.ZIndex = 3
TabArea.Parent = MainSection

local TabLayout = Instance.new("UIListLayout", TabArea)
TabLayout.Padding = UDim.new(0, 4)
TabLayout.FillDirection = Enum.FillDirection.Horizontal

local TabContainer = Instance.new("Frame")
TabContainer.BackgroundColor3 = MAIN
TabContainer.BorderColor3 = OUTLINE
TabContainer.BorderSizePixel = 1
TabContainer.Position = UDim2.fromOffset(8, 34)
TabContainer.Size = UDim2.new(1, -16, 1, -42)
TabContainer.ClipsDescendants = true
TabContainer.ZIndex = 3
TabContainer.Parent = MainSection

local TabPages = {}
local ActiveTab = nil

function makeTab(name)
    local tw, _ = textBounds(name, 14)
    local btnOuter, btnInner = bordered(TabArea, BG, OUTLINE, UDim2.fromOffset(tw + 12, 22), nil, 3)
    label(btnInner, name, 14, UDim2.fromOffset(4, 3), 5)

    local page = Instance.new("ScrollingFrame")
    page.Name = name
    page.Size = UDim2.fromScale(1, 1)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 2
    page.ScrollBarImageColor3 = Accent
    page.CanvasSize = UDim2.fromOffset(0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
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

    local function select()
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
    end

    local btn = Instance.new("TextButton")
    btn.BackgroundTransparency = 1
    btn.Size = UDim2.fromScale(1, 1)
    btn.Text = ""
    btn.ZIndex = 10
    btn.Parent = btnOuter
    btn.MouseButton1Click:Connect(select)

    TabPages[name] = tab
    return stack
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
    table.insert(ThemeParts.highlights, highlight)

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
    table.insert(ThemeParts.toggles, parts)

    local function display()
        tInner.BackgroundColor3 = on and Accent or MAIN
        tInner.BorderColor3 = on and darker(Accent) or OUTLINE
        parts.on = on
    end

    local function set(v)
        on = v
        display()
        if onChange then onChange(on) end
    end

    hit.MouseButton1Click:Connect(function() set(not on) end)
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
    table.insert(ThemeParts.fills, fill)

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
        if span <= 0 then applyAlpha(0) else applyAlpha((v - minV) / span) end
    end

    trackBtn.MouseButton1Down:Connect(function() sliding = true end)
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
        if i.UserInputType == Enum.UserInputType.MouseButton1 then sliding = false end
    end)

    applyValue(get())

    return { Set = applyValue, Refresh = function() valLbl.Text = fmt(get()); applyValue(get()) end }
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

function makeTextBox(container, placeholder, defaultText)
    local _, inner = bordered(container, MAIN, OUTLINE, UDim2.new(1, 0, 0, 22), nil, 7)
    local box = Instance.new("TextBox")
    box.BackgroundTransparency = 1
    box.BorderSizePixel = 0
    box.Size = UDim2.new(1, -6, 1, -4)
    box.Position = UDim2.fromOffset(3, 2)
    box.Font = FONT
    box.Text = defaultText or ""
    box.PlaceholderText = placeholder or ""
    box.PlaceholderColor3 = Color3.fromRGB(140, 140, 140)
    box.TextColor3 = TEXT
    box.TextSize = 14
    box.ClearTextOnFocus = false
    box.ZIndex = 8
    box.Parent = inner
    return box
end

function getHumanoid()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

function fmtBurst(n)
    return n <= 1 and "1x" or string.format("%dx", n)
end

function fireClicks()
    local burst = math.floor(St.clickBurst)
    for _ = 1, burst do
        ClickEvent:FireServer()
        Stats.clicks += 1
        Stats.cpsTick += 1
    end
    if Stats.clicks >= Stats.nextMilestone then
        Stats.flashUntil = tick() + 3
        Stats.nextMilestone += St.milestoneStep
    end
end

function purchaseUpgrade(name)
    local ok, result = pcall(function()
        return UpgradeEvent:InvokeServer(name)
    end)
    if not ok then return false end
    if result == false then return false end
    return true
end

function setNoclip(enabled)
    local char = LocalPlayer.Character
    if not char then return end
    for _, part in char:GetDescendants() do
        if part:IsA("BasePart") then
            part.CanCollide = not enabled
        end
    end
end

function enableChaosMode()
    St.rainbowBody = true
    St.flameHead = true
    St.bigHead = true
    St.sparkleTrail = true
    St.chaosPulse = true
    St.spin = true
    St.billboard = true
    St.billboardText = "CHAOS"
    if Ref.rainbowBodyToggle then Ref.rainbowBodyToggle.Set(true) end
    if Ref.flameHeadToggle then Ref.flameHeadToggle.Set(true) end
    if Ref.bigHeadToggle then Ref.bigHeadToggle.Set(true) end
    if Ref.sparkleTrailToggle then Ref.sparkleTrailToggle.Set(true) end
    if Ref.chaosPulseToggle then Ref.chaosPulseToggle.Set(true) end
    if Ref.spinToggle then Ref.spinToggle.Set(true) end
    if Ref.billboardToggle then Ref.billboardToggle.Set(true) end
    if Ref.billboardBox then Ref.billboardBox.Text = St.billboardText end
end

function getRootPart()
    local char = LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

function clearOtherHighlights()
    for _, h in CharExtras.others do
        pcall(function() h:Destroy() end)
    end
    table.clear(CharExtras.others)
end

function resetCharacterFun(syncUi)
    St.charScale = 1
    St.headless = false
    St.invisible = false
    St.rainbowBody = false
    St.flameHead = false
    St.upsideDown = false
    St.billboard = false
    St.bigHead = false
    St.chaosPulse = false
    St.sparkleTrail = false
    CharExtras.lastScale = 1
    local char = LocalPlayer.Character
    if char then
        pcall(function() char:ScaleTo(1) end)
        for _, p in char:GetDescendants() do
            if p:IsA("BasePart") then
                p.LocalTransparencyModifier = 0
                if p.Name == "Head" then
                    p.Size = Vector3.new(2, 1, 1)
                end
            end
        end
    end
    if CharExtras.fire then CharExtras.fire:Destroy(); CharExtras.fire = nil end
    if CharExtras.billboard then CharExtras.billboard:Destroy(); CharExtras.billboard = nil end
    if CharExtras.sparkles then CharExtras.sparkles:Destroy(); CharExtras.sparkles = nil end
    if syncUi and Ref.charScaleSlider then
        Ref.charScaleSlider.Set(1)
        Ref.headlessToggle.Set(false)
        Ref.invisibleToggle.Set(false)
        Ref.rainbowBodyToggle.Set(false)
        Ref.flameHeadToggle.Set(false)
        Ref.bigHeadToggle.Set(false)
        Ref.upsideDownToggle.Set(false)
        Ref.billboardToggle.Set(false)
        if Ref.sparkleTrailToggle then Ref.sparkleTrailToggle.Set(false) end
        if Ref.chaosPulseToggle then Ref.chaosPulseToggle.Set(false) end
        if Ref.spinToggle then Ref.spinToggle.Set(false); St.spin = false end
    end
end

function resetOthersFun(syncUi)
    St.highlightOthers = false
    St.rainbowOthers = false
    St.spinOthers = false
    St.giantOthers = false
    St.otherScale = 2
    clearOtherHighlights()
    if syncUi and Ref.highlightOthersToggle then
        Ref.highlightOthersToggle.Set(false)
        Ref.rainbowOthersToggle.Set(false)
        Ref.spinOthersToggle.Set(false)
        Ref.giantOthersToggle.Set(false)
        Ref.otherScaleSlider.Set(2)
    end
end

function applyCharacterFun()
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local head = char:FindFirstChild("Head")

    if St.charScale ~= CharExtras.lastScale and not St.chaosPulse then
        pcall(function() char:ScaleTo(St.charScale) end)
        CharExtras.lastScale = St.charScale
    end

    if St.chaosPulse then
        local pulse = 1 + math.sin(tick() * 4) * 0.35
        pcall(function() char:ScaleTo(St.charScale * pulse) end)
    end

    for _, part in char:GetDescendants() do
        if part:IsA("BasePart") then
            local hide = St.invisible or (St.headless and part.Name == "Head")
            part.LocalTransparencyModifier = hide and 1 or 0
            if St.rainbowBody then
                part.Color = hueColor(tick() * 0.8, 1, 1)
            end
            if St.bigHead and part.Name == "Head" then
                part.Size = Vector3.new(6, 6, 6)
            end
        end
    end

    if St.flameHead and head then
        if not CharExtras.fire or CharExtras.fire.Parent ~= head then
            if CharExtras.fire then CharExtras.fire:Destroy() end
            local f = Instance.new("Fire")
            f.Size = 24
            f.Heat = 18
            f.Parent = head
            CharExtras.fire = f
        end
    elseif CharExtras.fire then
        CharExtras.fire:Destroy()
        CharExtras.fire = nil
    end

    if St.sparkleTrail and root then
        if not CharExtras.sparkles or CharExtras.sparkles.Parent ~= root then
            if CharExtras.sparkles then CharExtras.sparkles:Destroy() end
            local s = Instance.new("Sparkles")
            s.SparkleColor = hueColor(tick() * 0.5, 1, 1)
            s.Parent = root
            CharExtras.sparkles = s
        else
            CharExtras.sparkles.SparkleColor = hueColor(tick() * 0.5, 1, 1)
        end
    elseif CharExtras.sparkles then
        CharExtras.sparkles:Destroy()
        CharExtras.sparkles = nil
    end

    if St.billboard and head then
        if not CharExtras.billboard or CharExtras.billboard.Parent ~= head then
            if CharExtras.billboard then CharExtras.billboard:Destroy() end
            local bg = Instance.new("BillboardGui")
            bg.Name = "CobaltBillboard"
            bg.Size = UDim2.fromOffset(220, 56)
            bg.StudsOffset = Vector3.new(0, 3.5, 0)
            bg.AlwaysOnTop = true
            bg.Parent = head
            local tl = Instance.new("TextLabel")
            tl.Size = UDim2.fromScale(1, 1)
            tl.BackgroundTransparency = 1
            tl.TextColor3 = Color3.new(1, 1, 1)
            tl.TextStrokeTransparency = 0
            tl.Font = Enum.Font.Code
            tl.TextSize = 20
            tl.Text = St.billboardText
            tl.Parent = bg
            CharExtras.billboard = bg
        else
            local tl = CharExtras.billboard:FindFirstChildOfClass("TextLabel")
            if tl then tl.Text = St.billboardText end
        end
    elseif CharExtras.billboard then
        CharExtras.billboard:Destroy()
        CharExtras.billboard = nil
    end

    if St.upsideDown and root then
        local cf = root.CFrame
        root.CFrame = CFrame.new(cf.Position) * CFrame.Angles(math.pi, 0, 0)
    end
end

function applyOthersFun()
    if not (St.highlightOthers or St.rainbowOthers or St.spinOthers or St.giantOthers) then
        clearOtherHighlights()
        return
    end
    for _, plr in Players:GetPlayers() do
        if plr ~= LocalPlayer then
            local char = plr.Character
            if char then
                local root = char:FindFirstChild("HumanoidRootPart")
                if St.highlightOthers then
                    local key = tostring(plr.UserId)
                    if not CharExtras.others[key] or CharExtras.others[key].Parent ~= char then
                        if CharExtras.others[key] then CharExtras.others[key]:Destroy() end
                        local h = Instance.new("Highlight")
                        h.Name = "CobaltOtherHL"
                        h.FillColor = hueColor(plr.UserId * 0.01 % 1, 1, 1)
                        h.OutlineColor = Color3.new(1, 1, 1)
                        h.FillTransparency = 0.4
                        h.Parent = char
                        CharExtras.others[key] = h
                    end
                end
                if St.rainbowOthers then
                    for _, p in char:GetDescendants() do
                        if p:IsA("BasePart") then
                            p.Color = hueColor((tick() * 0.6 + plr.UserId * 0.01) % 1, 1, 1)
                        end
                    end
                end
                if St.spinOthers and root then
                    root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(14), 0)
                end
                if St.giantOthers then
                    pcall(function() char:ScaleTo(St.otherScale) end)
                end
            end
        end
    end
    if not St.highlightOthers then
        for key, h in CharExtras.others do
            if h and h:IsA("Highlight") then
                h:Destroy()
                CharExtras.others[key] = nil
            end
        end
    end
end

function flingCharacter()
    local root = getRootPart()
    local cam = workspace.CurrentCamera
    if root and cam then
        root.AssemblyLinearVelocity = cam.CFrame.LookVector * 320 + Vector3.new(0, 220, 0)
        root.AssemblyAngularVelocity = Vector3.new(math.random(-20, 20), math.random(-20, 20), math.random(-20, 20))
    end
end

-- Build tabs
local MainStack = makeTab("Main")
local UpgradesStack = makeTab("Upgrades")
local ConfigsStack = makeTab("Configs")
local FunStack = makeTab("Fun")
local VisualsStack = makeTab("Visuals")
local SettingsStack = makeTab("Settings")

local AutoBox = makeGroupbox(MainStack, "Automation")
Ref.clickToggle = makeToggle(AutoBox, "Autoclicker", function(v)
    St.click = v
    if v and St.autoHideOnClick then setUIVisible(false) end
end)
Ref.throttleSlider = makeSlider(AutoBox, "Click Throttle", {
    min = MIN_THROTTLE, max = MAX_THROTTLE,
    get = function() return St.clickThrottle end,
    set = function(v) St.clickThrottle = v end,
    fmt = fmtThrottle,
})
Ref.burstSlider = makeSlider(AutoBox, "Click Burst", {
    min = MIN_CLICK_BURST, max = MAX_CLICK_BURST,
    get = function() return St.clickBurst end,
    set = function(v) St.clickBurst = math.floor(v) end,
    fmt = fmtBurst,
})
Ref.antiAfkToggle = makeToggle(AutoBox, "Anti-AFK", function(v) St.antiAfk = v end)
Ref.autoTowerToggle = makeToggle(AutoBox, "Auto Tower", function(v) St.autoTower = v end)
Ref.towerIntervalSlider = makeSlider(AutoBox, "Tower Interval", {
    min = MIN_TOWER_MINUTES * 60, max = MAX_TOWER_MINUTES * 60,
    get = function() return St.towerInterval end,
    set = function(v) St.towerInterval = v end,
    fmt = fmtMinutes,
})
label(AutoBox, "TP to tower + hold W 1s", 13, UDim2.fromOffset(0, 0), 7)

local UpgradeBox = makeGroupbox(UpgradesStack, "Auto Upgrades")
Ref.upgradeToggle = makeToggle(UpgradeBox, "Enable Auto Upgrades", function(v) St.upgrade = v end)
Ref.turboUpgradeToggle = makeToggle(UpgradeBox, "Turbo Upgrades", function(v) St.turboUpgrades = v end)
Ref.upgradeDelaySlider = makeSlider(UpgradeBox, "Upgrade Delay", {
    min = MIN_UPGRADE_DELAY, max = MAX_UPGRADE_DELAY,
    get = function() return St.upgradeDelay end,
    set = function(v) St.upgradeDelay = v end,
    fmt = fmtDelay,
})
Ref.upgradeToggles = {}
for _, key in ipairs(Upgrades) do
    Ref.upgradeToggles[key] = makeToggle(UpgradeBox, UpgradeLabels[key], function(v) UpgradeChoices[key] = v end, true)
end
Ref.rebirthPriorityToggle = makeToggle(UpgradeBox, "Rebirth Priority", function(v) St.rebirthPriority = v end)
Ref.roundRobinToggle = makeToggle(UpgradeBox, "Round Robin Mode", function(v) St.roundRobin = v end)
label(UpgradeBox, "Turbo = no delay between successful buys", 13, UDim2.fromOffset(0, 0), 7)

local MoveBox = makeGroupbox(FunStack, "Movement")
Ref.speedToggle = makeToggle(MoveBox, "Speed Boost", function(v) St.speed = v end)
Ref.speedSlider = makeSlider(MoveBox, "Walk Speed", {
    min = 16, max = 400,
    get = function() return St.speedVal end,
    set = function(v) St.speedVal = v end,
    fmt = function(v) return string.format("%.0f", v) end,
})
Ref.flyToggle = makeToggle(MoveBox, "Fly (WASD + Space/Ctrl)", function(v)
    St.fly = v
    local hum = getHumanoid()
    if hum and not v then hum.PlatformStand = false end
end)
Ref.flySpeedSlider = makeSlider(MoveBox, "Fly Speed", {
    min = 50, max = 400,
    get = function() return St.flySpeed end,
    set = function(v) St.flySpeed = v end,
    fmt = function(v) return string.format("%.0f", v) end,
})
Ref.noclipToggle = makeToggle(MoveBox, "Noclip", function(v)
    St.noclip = v
    setNoclip(v)
end)
Ref.infJumpToggle = makeToggle(MoveBox, "Infinite Jump", function(v) St.infJump = v end)
Ref.lowGravToggle = makeToggle(MoveBox, "Low Gravity", function(v)
    St.lowGrav = v
    workspace.Gravity = v and 80 or Stats.defaultGravity
end)
Ref.spinToggle = makeToggle(MoveBox, "Spin Character", function(v) St.spin = v end)
Ref.spinSpeedSlider = makeSlider(MoveBox, "Spin Speed", {
    min = 2, max = 30,
    get = function() return St.spinSpeed end,
    set = function(v) St.spinSpeed = v end,
    fmt = function(v) return string.format("%.0f", v) end,
})

local ChaosBox = makeGroupbox(FunStack, "Character Chaos")
makeButton(ChaosBox, "Go Full Chaos", function() enableChaosMode() end)
Ref.chaosPulseToggle = makeToggle(ChaosBox, "Pulse Scale", function(v) St.chaosPulse = v end)
Ref.sparkleTrailToggle = makeToggle(ChaosBox, "Sparkle Trail", function(v) St.sparkleTrail = v end)
Ref.charScaleSlider = makeSlider(ChaosBox, "Body Scale", {
    min = 0.5, max = 3,
    get = function() return St.charScale end,
    set = function(v) St.charScale = v end,
    fmt = function(v) return string.format("%.1fx", v) end,
})
Ref.headlessToggle = makeToggle(ChaosBox, "Headless", function(v) St.headless = v end)
Ref.invisibleToggle = makeToggle(ChaosBox, "Invisible", function(v) St.invisible = v end)
Ref.rainbowBodyToggle = makeToggle(ChaosBox, "Rainbow Body", function(v) St.rainbowBody = v end)
Ref.flameHeadToggle = makeToggle(ChaosBox, "Flaming Head", function(v) St.flameHead = v end)
Ref.bigHeadToggle = makeToggle(ChaosBox, "Big Head", function(v) St.bigHead = v end)
Ref.upsideDownToggle = makeToggle(ChaosBox, "Upside Down", function(v) St.upsideDown = v end)
Ref.billboardToggle = makeToggle(ChaosBox, "Floating Label", function(v) St.billboard = v end)
Ref.billboardBox = makeTextBox(ChaosBox, "label text", St.billboardText)
Ref.billboardBox.FocusLost:Connect(function()
    St.billboardText = Ref.billboardBox.Text ~= "" and Ref.billboardBox.Text or "silly"
end)
makeButton(ChaosBox, "Fling Me", function() flingCharacter() end)
makeButton(ChaosBox, "Reset Character Look", function() resetCharacterFun(true) end)

local OthersBox = makeGroupbox(FunStack, "Other Players")
Ref.highlightOthersToggle = makeToggle(OthersBox, "Highlight Everyone", function(v)
    St.highlightOthers = v
    if not v then clearOtherHighlights() end
end)
Ref.rainbowOthersToggle = makeToggle(OthersBox, "Rainbow Others", function(v) St.rainbowOthers = v end)
Ref.spinOthersToggle = makeToggle(OthersBox, "Spin Others", function(v) St.spinOthers = v end)
Ref.giantOthersToggle = makeToggle(OthersBox, "Giant Others", function(v) St.giantOthers = v end)
Ref.otherScaleSlider = makeSlider(OthersBox, "Others Scale", {
    min = 1, max = 4,
    get = function() return St.otherScale end,
    set = function(v) St.otherScale = v end,
    fmt = function(v) return string.format("%.1fx", v) end,
})
makeButton(OthersBox, "Reset Others Effects", function() resetOthersFun(true) end)

local QoLBox = makeGroupbox(FunStack, "Quality of Life")
makeButton(QoLBox, "Teleport To Tower", function() task.spawn(runAutoTower) end)
makeButton(QoLBox, "Reset Character", function()
    local hum = getHumanoid()
    if hum then hum.Health = 0 end
end)
makeButton(QoLBox, "Toggle Menu + Watermark", function()
    local show = not WindowOuter.Visible
    setUIVisible(show)
    if ThemeParts.wmOuter then ThemeParts.wmOuter.Visible = show and not St.hideWatermark end
end)
Ref.milestoneSlider = makeSlider(QoLBox, "Click Milestone", {
    min = 1000, max = 100000,
    get = function() return St.milestoneStep end,
    set = function(v) St.milestoneStep = math.floor(v / 1000) * 1000 end,
    fmt = function(v) return fmtCount(math.floor(v / 1000) * 1000) end,
})

VisualSliders = {}
VisualToggles = {}

local WorldBox = makeGroupbox(VisualsStack, "World Color")
VisualToggles.worldOverlay = makeToggle(WorldBox, "World Tint Overlay", function(v)
    if v and VisualState.worldTintStrength <= 0 then
        VisualState.worldTintStrength = 0.35
        if VisualSliders.worldTintStrength then VisualSliders.worldTintStrength.Set(0.35) end
    elseif not v then
        VisualState.worldTintStrength = 0
        if VisualSliders.worldTintStrength then VisualSliders.worldTintStrength.Set(0) end
    end
    applyVisualEffects()
end, false)
VisualSliders.worldTintHue = makeSlider(WorldBox, "Tint Hue", {
    min = 0, max = 1,
    get = function() return VisualState.worldTintHue end,
    set = function(v) VisualState.worldTintHue = v; applyVisualEffects() end,
    fmt = fmtHue,
})
VisualSliders.worldTintStrength = makeSlider(WorldBox, "Tint Strength", {
    min = 0, max = 0.85,
    get = function() return VisualState.worldTintStrength end,
    set = function(v) VisualState.worldTintStrength = v; applyVisualEffects() end,
    fmt = function(v) return string.format("%.0f%%", v * 100) end,
})
VisualSliders.saturation = makeSlider(WorldBox, "Saturation", {
    min = -1, max = 1,
    get = function() return VisualState.saturation end,
    set = function(v) VisualState.saturation = v; applyVisualEffects() end,
    fmt = function(v) return string.format("%.0f%%", v * 100) end,
})
VisualSliders.contrast = makeSlider(WorldBox, "Contrast", {
    min = -1, max = 1,
    get = function() return VisualState.contrast end,
    set = function(v) VisualState.contrast = v; applyVisualEffects() end,
    fmt = function(v) return string.format("%.0f%%", v * 100) end,
})
VisualSliders.brightness = makeSlider(WorldBox, "Brightness", {
    min = -1, max = 1,
    get = function() return VisualState.brightness end,
    set = function(v) VisualState.brightness = v; applyVisualEffects() end,
    fmt = function(v) return string.format("%.0f%%", v * 100) end,
})
VisualSliders.blurAmount = makeSlider(WorldBox, "Blur", {
    min = 0, max = 56,
    get = function() return VisualState.blurAmount end,
    set = function(v) VisualState.blurAmount = v; applyVisualEffects() end,
    fmt = function(v) return string.format("%.0f", v) end,
})
VisualSliders.bloomAmount = makeSlider(WorldBox, "Bloom", {
    min = 0, max = 2,
    get = function() return VisualState.bloomAmount end,
    set = function(v) VisualState.bloomAmount = v; applyVisualEffects() end,
    fmt = function(v) return string.format("%.1f", v) end,
})

local CamBox = makeGroupbox(VisualsStack, "Camera & Time")
VisualToggles.fullbright = makeToggle(CamBox, "Fullbright", function(v)
    VisualState.fullbright = v; applyVisualEffects()
end)
VisualToggles.noShadows = makeToggle(CamBox, "No Shadows", function(v)
    VisualState.noShadows = v; applyVisualEffects()
end)
VisualToggles.fovOverride = makeToggle(CamBox, "Custom FOV", function(v)
    VisualState.fovOverride = v; applyVisualEffects()
end)
VisualSliders.fov = makeSlider(CamBox, "Field Of View", {
    min = 40, max = 120,
    get = function() return VisualState.fov end,
    set = function(v) VisualState.fov = v; applyVisualEffects() end,
    fmt = function(v) return string.format("%.0f", v) end,
})
VisualToggles.clockOverride = makeToggle(CamBox, "Lock Time Of Day", function(v)
    VisualState.clockOverride = v; applyVisualEffects()
end)
VisualSliders.clockTime = makeSlider(CamBox, "Clock Time", {
    min = 0, max = 24,
    get = function() return VisualState.clockTime end,
    set = function(v) VisualState.clockTime = v; applyVisualEffects() end,
    fmt = function(v) return string.format("%.1f", v) end,
})
VisualToggles.drunkCam = makeToggle(CamBox, "Wobble Camera", function(v)
    VisualState.drunkCam = v
    if not v and not VisualState.fovOverride then
        local cam = workspace.CurrentCamera
        if cam then cam.FieldOfView = 70 end
    end
end)

local GuiFxBox = makeGroupbox(VisualsStack, "GUI & Character")
VisualToggles.customGuiColor = makeToggle(GuiFxBox, "Custom GUI Accent", function(v)
    VisualState.customGuiColor = v; applyVisualEffects()
end, false)
VisualSliders.guiHue = makeSlider(GuiFxBox, "GUI Accent Hue", {
    min = 0, max = 1,
    get = function() return VisualState.guiHue end,
    set = function(v) VisualState.guiHue = v; if VisualState.customGuiColor then applyVisualEffects() end end,
    fmt = fmtHue,
})
VisualToggles.rainbowGui = makeToggle(GuiFxBox, "Rainbow GUI", function(v)
    VisualState.rainbowGui = v
    if not v and not VisualState.customGuiColor then
        applyAccent(ACCENTS[getThemeName()] or ACCENTS.Cobalt)
    else applyVisualEffects() end
end)
VisualToggles.rainbowWorld = makeToggle(GuiFxBox, "Rainbow World Tint", function(v)
    VisualState.rainbowWorld = v; applyVisualEffects()
end)
VisualSliders.rainbowSpeed = makeSlider(GuiFxBox, "Rainbow Speed", {
    min = 0.2, max = 4,
    get = function() return VisualState.rainbowSpeed end,
    set = function(v) VisualState.rainbowSpeed = v end,
    fmt = function(v) return string.format("%.1fx", v) end,
})
VisualToggles.charHighlight = makeToggle(GuiFxBox, "Character Glow", function(v)
    VisualState.charHighlight = v; applyVisualEffects()
end)
VisualSliders.charHighlightHue = makeSlider(GuiFxBox, "Glow Hue", {
    min = 0, max = 1,
    get = function() return VisualState.charHighlightHue end,
    set = function(v) VisualState.charHighlightHue = v; if VisualState.charHighlight then applyVisualEffects() end end,
    fmt = fmtHue,
})

local PresetBox = makeGroupbox(VisualsStack, "Weird Presets")
local previewRow = Instance.new("Frame")
previewRow.BackgroundTransparency = 1
previewRow.Size = UDim2.new(1, 0, 0, 18)
previewRow.ZIndex = 6
previewRow.Parent = PresetBox
label(previewRow, "Tint preview", 13, UDim2.fromOffset(0, 2), 7)
VisualHuePreview = Instance.new("Frame")
VisualHuePreview.BackgroundColor3 = hueColor(0, 1, 1)
VisualHuePreview.BorderColor3 = OUTLINE
VisualHuePreview.BorderSizePixel = 1
VisualHuePreview.Size = UDim2.fromOffset(52, 14)
VisualHuePreview.Position = UDim2.new(1, -56, 0, 2)
VisualHuePreview.ZIndex = 7
VisualHuePreview.Parent = previewRow
for name, _ in pairs(WEIRD_PRESETS) do
    makeButton(PresetBox, name, function() applyWeirdPreset(name) end)
end
makeButton(PresetBox, "Reset All Visuals", function() resetAllVisuals() end)

local ThemeBox = makeGroupbox(SettingsStack, "Theme")
for name, color in pairs(ACCENTS) do
    makeButton(ThemeBox, name, function()
        VisualState.customGuiColor = false
        if VisualToggles and VisualToggles.customGuiColor then
            VisualToggles.customGuiColor.Set(false)
        end
        applyAccent(color)
    end)
end

local PrefBox = makeGroupbox(SettingsStack, "Preferences")
local PrefToggles = {}
PrefToggles.detailed = makeToggle(PrefBox, "Detailed Watermark", function(v) St.detailedWatermark = v end, St.detailedWatermark)
PrefToggles.autoClick = makeToggle(PrefBox, "Auto-Start Autoclicker", function(v) St.autoClickOnStart = v end, St.autoClickOnStart)
PrefToggles.autoUpgrade = makeToggle(PrefBox, "Auto-Start Upgrades", function(v) St.autoUpgradeOnStart = v end, St.autoUpgradeOnStart)
PrefToggles.autoTower = makeToggle(PrefBox, "Auto-Start Tower", function(v) St.autoTowerOnStart = v end, St.autoTowerOnStart)
PrefToggles.hideWm = makeToggle(PrefBox, "Hide Watermark", function(v)
    St.hideWatermark = v
    if ThemeParts.wmOuter then ThemeParts.wmOuter.Visible = not v end
end, St.hideWatermark)
PrefToggles.autoSave = makeToggle(PrefBox, "Auto-Save Profile", function(v) St.autoSaveProfiles = v end, St.autoSaveProfiles)
PrefToggles.autoHide = makeToggle(PrefBox, "Auto-Hide Menu On Click", function(v) St.autoHideOnClick = v end, St.autoHideOnClick)
PrefToggles.showFps = makeToggle(PrefBox, "Show FPS In Watermark", function(v) St.showFps = v end, St.showFps)

local MiscBox = makeGroupbox(SettingsStack, "Session")
makeButton(MiscBox, "Reset Session Stats", function()
    Stats.start = tick()
    Stats.clicks = 0
    Stats.cps = 0
    Stats.cpsTick = 0
    Stats.upgrades = 0
    setConfigStatus("Session stats reset")
end)
makeButton(MiscBox, "Unload Script", function() unloadScript() end)

Ref.clickToggle.Set(false)
Ref.upgradeToggle.Set(false)

TabPages.Main.active = true
TabPages.Main.page.Visible = true
TabPages.Main.btnInner.BackgroundColor3 = MAIN
TabPages.Main.btnInner.BorderColor3 = Accent
ActiveTab = TabPages.Main

ensureConfigDirs()
readMeta()

function serializeSettings()
    return {
        version = 1,
        clickThrottle = St.clickThrottle,
        clickBurst = St.clickBurst,
        upgradeDelay = St.upgradeDelay,
        turboUpgrades = St.turboUpgrades,
        upgradeChoices = UpgradeChoices,
        theme = getThemeName(),
        detailedWatermark = St.detailedWatermark,
        autoClickOnStart = St.autoClickOnStart,
        autoUpgradeOnStart = St.autoUpgradeOnStart,
        autoTowerOnStart = St.autoTowerOnStart,
        autoSaveProfiles = St.autoSaveProfiles,
        hideWatermark = St.hideWatermark,
        rebirthPriority = St.rebirthPriority,
        towerInterval = St.towerInterval,
        antiAfk = St.antiAfk,
        autoTower = St.autoTower,
        clickEnabled = St.click,
        upgradeEnabled = St.upgrade,
        visuals = VisualState,
        fun = {
            speed = St.speed, speedVal = St.speedVal, fly = St.fly, flySpeed = St.flySpeed,
            noclip = St.noclip, infJump = St.infJump, lowGrav = St.lowGrav,
            spin = St.spin, spinSpeed = St.spinSpeed, chaosPulse = St.chaosPulse,
            sparkleTrail = St.sparkleTrail,
            roundRobin = St.roundRobin, autoHideOnClick = St.autoHideOnClick,
            milestoneStep = St.milestoneStep, showFps = St.showFps,
            charScale = St.charScale, headless = St.headless, invisible = St.invisible,
            rainbowBody = St.rainbowBody, flameHead = St.flameHead, upsideDown = St.upsideDown,
            billboard = St.billboard, billboardText = St.billboardText, bigHead = St.bigHead,
            highlightOthers = St.highlightOthers, rainbowOthers = St.rainbowOthers,
            spinOthers = St.spinOthers, giantOthers = St.giantOthers, otherScale = St.otherScale,
        },
    }
end

function applySettings(data, opts)
    opts = opts or {}
    if type(data) ~= "table" then return false end

    if type(data.clickThrottle) == "number" then
        St.clickThrottle = clamp(data.clickThrottle, MIN_THROTTLE, MAX_THROTTLE)
        Ref.throttleSlider.Set(St.clickThrottle)
    end
    if type(data.clickBurst) == "number" then
        St.clickBurst = clamp(math.floor(data.clickBurst), MIN_CLICK_BURST, MAX_CLICK_BURST)
        Ref.burstSlider.Set(St.clickBurst)
    end
    if type(data.upgradeDelay) == "number" then
        St.upgradeDelay = clamp(data.upgradeDelay, MIN_UPGRADE_DELAY, MAX_UPGRADE_DELAY)
        Ref.upgradeDelaySlider.Set(St.upgradeDelay)
    end
    if type(data.towerInterval) == "number" then
        St.towerInterval = clamp(data.towerInterval, MIN_TOWER_MINUTES * 60, MAX_TOWER_MINUTES * 60)
        Ref.towerIntervalSlider.Set(St.towerInterval)
    end
    if type(data.upgradeChoices) == "table" then
        for key, val in pairs(data.upgradeChoices) do
            if UpgradeChoices[key] ~= nil and type(val) == "boolean" then
                UpgradeChoices[key] = val
                if Ref.upgradeToggles[key] then Ref.upgradeToggles[key].Set(val) end
            end
        end
    end
    if type(data.theme) == "string" and ACCENTS[data.theme] then
        applyAccent(ACCENTS[data.theme])
    end
    if type(data.detailedWatermark) == "boolean" then
        St.detailedWatermark = data.detailedWatermark
        PrefToggles.detailed.Set(St.detailedWatermark)
    end
    if type(data.autoClickOnStart) == "boolean" then
        St.autoClickOnStart = data.autoClickOnStart
        PrefToggles.autoClick.Set(St.autoClickOnStart)
    end
    if type(data.autoUpgradeOnStart) == "boolean" then
        St.autoUpgradeOnStart = data.autoUpgradeOnStart
        PrefToggles.autoUpgrade.Set(St.autoUpgradeOnStart)
    end
    if type(data.autoTowerOnStart) == "boolean" then
        St.autoTowerOnStart = data.autoTowerOnStart
        PrefToggles.autoTower.Set(St.autoTowerOnStart)
    end
    if type(data.autoSaveProfiles) == "boolean" then
        St.autoSaveProfiles = data.autoSaveProfiles
        PrefToggles.autoSave.Set(St.autoSaveProfiles)
    end
    if type(data.hideWatermark) == "boolean" then
        St.hideWatermark = data.hideWatermark
        PrefToggles.hideWm.Set(St.hideWatermark)
    end
    if type(data.turboUpgrades) == "boolean" then
        St.turboUpgrades = data.turboUpgrades
        Ref.turboUpgradeToggle.Set(St.turboUpgrades)
    end
    if type(data.rebirthPriority) == "boolean" then
        St.rebirthPriority = data.rebirthPriority
        Ref.rebirthPriorityToggle.Set(St.rebirthPriority)
    end
    if type(data.antiAfk) == "boolean" and Ref.antiAfkToggle then
        Ref.antiAfkToggle.Set(data.antiAfk)
    end
    if type(data.autoTower) == "boolean" then
        Ref.autoTowerToggle.Set(data.autoTower)
    end
    if type(data.visuals) == "table" then
        for key, val in pairs(data.visuals) do
            if VisualState[key] ~= nil and type(val) == type(VisualState[key]) then
                VisualState[key] = val
            end
        end
        syncVisualControls()
        applyVisualEffects()
    end
    if type(data.fun) == "table" then
        local f = data.fun
        if type(f.speed) == "boolean" then St.speed = f.speed; Ref.speedToggle.Set(St.speed) end
        if type(f.speedVal) == "number" then St.speedVal = clamp(f.speedVal, 16, 400); Ref.speedSlider.Set(St.speedVal) end
        if type(f.fly) == "boolean" then St.fly = f.fly; Ref.flyToggle.Set(St.fly) end
        if type(f.flySpeed) == "number" then St.flySpeed = clamp(f.flySpeed, 50, 400); Ref.flySpeedSlider.Set(St.flySpeed) end
        if type(f.noclip) == "boolean" then St.noclip = f.noclip; Ref.noclipToggle.Set(St.noclip); setNoclip(St.noclip) end
        if type(f.infJump) == "boolean" then St.infJump = f.infJump; Ref.infJumpToggle.Set(St.infJump) end
        if type(f.lowGrav) == "boolean" then
            St.lowGrav = f.lowGrav
            Ref.lowGravToggle.Set(St.lowGrav)
            workspace.Gravity = St.lowGrav and 80 or Stats.defaultGravity
        end
        if type(f.spin) == "boolean" then St.spin = f.spin; Ref.spinToggle.Set(St.spin) end
        if type(f.spinSpeed) == "number" then St.spinSpeed = clamp(f.spinSpeed, 2, 30); Ref.spinSpeedSlider.Set(St.spinSpeed) end
        if type(f.chaosPulse) == "boolean" then St.chaosPulse = f.chaosPulse; Ref.chaosPulseToggle.Set(St.chaosPulse) end
        if type(f.sparkleTrail) == "boolean" then St.sparkleTrail = f.sparkleTrail; Ref.sparkleTrailToggle.Set(St.sparkleTrail) end
        if type(f.roundRobin) == "boolean" then St.roundRobin = f.roundRobin; Ref.roundRobinToggle.Set(St.roundRobin) end
        if type(f.autoHideOnClick) == "boolean" then St.autoHideOnClick = f.autoHideOnClick; PrefToggles.autoHide.Set(St.autoHideOnClick) end
        if type(f.milestoneStep) == "number" then St.milestoneStep = f.milestoneStep; Ref.milestoneSlider.Set(St.milestoneStep) end
        if type(f.showFps) == "boolean" then St.showFps = f.showFps; PrefToggles.showFps.Set(St.showFps) end
        if type(f.charScale) == "number" then St.charScale = clamp(f.charScale, 0.5, 3); Ref.charScaleSlider.Set(St.charScale) end
        if type(f.headless) == "boolean" then St.headless = f.headless; Ref.headlessToggle.Set(St.headless) end
        if type(f.invisible) == "boolean" then St.invisible = f.invisible; Ref.invisibleToggle.Set(St.invisible) end
        if type(f.rainbowBody) == "boolean" then St.rainbowBody = f.rainbowBody; Ref.rainbowBodyToggle.Set(St.rainbowBody) end
        if type(f.flameHead) == "boolean" then St.flameHead = f.flameHead; Ref.flameHeadToggle.Set(St.flameHead) end
        if type(f.upsideDown) == "boolean" then St.upsideDown = f.upsideDown; Ref.upsideDownToggle.Set(St.upsideDown) end
        if type(f.billboard) == "boolean" then St.billboard = f.billboard; Ref.billboardToggle.Set(St.billboard) end
        if type(f.billboardText) == "string" then St.billboardText = f.billboardText; Ref.billboardBox.Text = St.billboardText end
        if type(f.bigHead) == "boolean" then St.bigHead = f.bigHead; Ref.bigHeadToggle.Set(St.bigHead) end
        if type(f.highlightOthers) == "boolean" then St.highlightOthers = f.highlightOthers; Ref.highlightOthersToggle.Set(St.highlightOthers) end
        if type(f.rainbowOthers) == "boolean" then St.rainbowOthers = f.rainbowOthers; Ref.rainbowOthersToggle.Set(St.rainbowOthers) end
        if type(f.spinOthers) == "boolean" then St.spinOthers = f.spinOthers; Ref.spinOthersToggle.Set(St.spinOthers) end
        if type(f.giantOthers) == "boolean" then St.giantOthers = f.giantOthers; Ref.giantOthersToggle.Set(St.giantOthers) end
        if type(f.otherScale) == "number" then St.otherScale = clamp(f.otherScale, 1, 4); Ref.otherScaleSlider.Set(St.otherScale) end
    end

    if opts.applyRuntime then
        if type(data.clickEnabled) == "boolean" then Ref.clickToggle.Set(data.clickEnabled) end
        if type(data.upgradeEnabled) == "boolean" then Ref.upgradeToggle.Set(data.upgradeEnabled) end
    elseif opts.autoStart then
        if St.autoClickOnStart then Ref.clickToggle.Set(true) end
        if St.autoUpgradeOnStart then Ref.upgradeToggle.Set(true) end
        if St.autoTowerOnStart then Ref.autoTowerToggle.Set(true) end
    end

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
    if not hasFileApi() then
        setConfigStatus("File API unavailable")
        return false
    end
    ensureConfigDirs()
    name = registerProfile(name or (ProfileNameBox and ProfileNameBox.Text) or ConfigMeta.lastProfile)
    local ok = pcall(writefile, profilePath(name), HttpService:JSONEncode(serializeSettings()))
    if ok then
        if ProfileNameBox then ProfileNameBox.Text = name end
        refreshProfileList()
        setConfigStatus("Saved profile: " .. name)
    else
        setConfigStatus("Failed to save profile")
    end
    return ok
end

loadProfile = function(name)
    if not hasFileApi() then
        setConfigStatus("File API unavailable")
        return false
    end
    name = sanitizeProfileName(name or (ProfileNameBox and ProfileNameBox.Text) or ConfigMeta.lastProfile)
    local path = profilePath(name)
    if not isfile(path) then
        setConfigStatus("Profile not found: " .. name)
        return false
    end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(path))
    end)
    if not ok or not applySettings(data, { applyRuntime = true }) then
        setConfigStatus("Failed to load profile")
        return false
    end
    registerProfile(name)
    if ProfileNameBox then ProfileNameBox.Text = name end
    setConfigStatus("Loaded profile: " .. name)
    return true
end

deleteProfile = function(name)
    if not hasFileApi() then return false end
    name = sanitizeProfileName(name or (ProfileNameBox and ProfileNameBox.Text) or "")
    if name == "" then return false end
    if delfile and isfile(profilePath(name)) then
        pcall(delfile, profilePath(name))
    end
    for i, existing in ipairs(ConfigMeta.profiles) do
        if existing == name then
            table.remove(ConfigMeta.profiles, i)
            break
        end
    end
    if ConfigMeta.lastProfile == name then
        ConfigMeta.lastProfile = ConfigMeta.profiles[1] or "default"
    end
    writeMeta()
    refreshProfileList()
    setConfigStatus("Deleted profile: " .. name)
    return true
end

exportProfileToClipboard = function()
    local json = HttpService:JSONEncode(serializeSettings())
    if copyToClipboard(json) then
        setConfigStatus("Config copied to clipboard")
        return true
    end
    setConfigStatus("Clipboard unavailable")
    return false
end

importProfileFromClipboard = function(saveAs)
    local raw = readClipboard()
    if not raw or raw == "" then
        setConfigStatus("Clipboard is empty")
        return false
    end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(raw)
    end)
    if not ok or not applySettings(data, { applyRuntime = true }) then
        setConfigStatus("Invalid config in clipboard")
        return false
    end
    local name = sanitizeProfileName(saveAs or (ProfileNameBox and ProfileNameBox.Text) or ("import-" .. os.date("%H%M%S")))
    if ProfileNameBox then ProfileNameBox.Text = name end
    saveProfile(name)
    setConfigStatus("Imported profile: " .. name)
    return true
end

function migrateLegacyConfig()
    if not (hasFileApi() and isfile(LEGACY_CONFIG_PATH)) then return end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(LEGACY_CONFIG_PATH))
    end)
    if ok and type(data) == "table" then
        applySettings(data, { autoStart = true })
        saveProfile("default")
    end
end

function saveCurrentProfile()
    if St.autoSaveProfiles then
        saveProfile(ProfileNameBox and ProfileNameBox.Text or ConfigMeta.lastProfile)
    end
end

local ProfileBox = makeGroupbox(ConfigsStack, "Profile Manager")
ProfileNameBox = makeTextBox(ProfileBox, "profile name", ConfigMeta.lastProfile)
makeButton(ProfileBox, "Save Profile", function() saveProfile() end)
makeButton(ProfileBox, "Load Profile", function() loadProfile() end)
makeButton(ProfileBox, "Delete Profile", function() deleteProfile() end)

local ImportBox = makeGroupbox(ConfigsStack, "Import / Export")
makeButton(ImportBox, "Export to Clipboard", function() exportProfileToClipboard() end)
makeButton(ImportBox, "Import from Clipboard", function() importProfileFromClipboard() end)
makeButton(ImportBox, "Refresh Profile List", function() refreshProfileList() end)

local ListBox = makeGroupbox(ConfigsStack, "Saved Profiles")
ProfileListFrame = Instance.new("Frame")
ProfileListFrame.BackgroundTransparency = 1
ProfileListFrame.Size = UDim2.new(1, 0, 0, 0)
ProfileListFrame.AutomaticSize = Enum.AutomaticSize.Y
ProfileListFrame.ZIndex = 6
ProfileListFrame.Parent = ListBox
Instance.new("UIListLayout", ProfileListFrame).Padding = UDim.new(0, 4)

ConfigStatusLbl = label(ListBox, "Ready", 13, UDim2.fromOffset(0, 0), 7)
ConfigStatusLbl.TextColor3 = Color3.fromRGB(180, 180, 180)

-- â”€â”€ Linoria watermark â”€â”€
local WmOuter, WmInner = bordered(ScreenGui, MAIN, Accent, UDim2.fromOffset(120, 22), UDim2.fromOffset(100, 12), 200)
ThemeParts.wmOuter = WmOuter
WmOuter.Visible = not St.hideWatermark
WmOuter.Active = true
ThemeParts.wmInner = WmInner

local WmGradientFrame = Instance.new("Frame")
WmGradientFrame.BackgroundColor3 = Color3.new(1, 1, 1)
WmGradientFrame.BorderSizePixel = 0
WmGradientFrame.Size = UDim2.new(1, -2, 1, -2)
WmGradientFrame.Position = UDim2.fromOffset(1, 1)
WmGradientFrame.ZIndex = 202
WmGradientFrame.Parent = WmInner

local WmGrad = Instance.new("UIGradient", WmGradientFrame)
WmGrad.Rotation = -90
WmGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, darker(MAIN)),
    ColorSequenceKeypoint.new(1, MAIN),
})
ThemeParts.wmGrad = WmGrad

local Watermark = label(WmGradientFrame, "00:00:00", 14, UDim2.fromOffset(5, 2), 203)
Watermark.Size = UDim2.new(1, -10, 1, -4)
passthrough(Watermark)

local WmDragBtn = Instance.new("TextButton")
WmDragBtn.BackgroundTransparency = 1
WmDragBtn.Size = UDim2.fromScale(1, 1)
WmDragBtn.Text = ""
WmDragBtn.ZIndex = 204
WmDragBtn.Parent = WmGradientFrame

function buildWatermarkText()
    if tick() < Stats.flashUntil then
        return ">> " .. fmtCount(Stats.clicks) .. " clicks! <<"
    end
    local elapsed = fmtTime(tick() - Stats.start)
    local tags = {}
    if St.click then table.insert(tags, "AC") end
    if St.clickBurst > 1 then table.insert(tags, St.clickBurst .. "x") end
    if St.upgrade then table.insert(tags, St.turboUpgrades and "TURBO" or "UP") end
    if St.antiAfk then table.insert(tags, "AFK") end
    if St.autoTower then table.insert(tags, "TWR") end
    if St.fly then table.insert(tags, "FLY") end

    if St.detailedWatermark then
        local parts = { elapsed, fmtCount(Stats.clicks) .. " clicks", Stats.cps .. " cps", fmtCount(Stats.upgrades) .. " ups" }
        if St.showFps then table.insert(parts, Stats.fps .. " fps") end
        if #tags > 0 then table.insert(parts, table.concat(tags, " ")) end
        return table.concat(parts, " | ")
    end

    if #tags > 0 then
        return elapsed .. " | " .. table.concat(tags, " ")
    end
    return elapsed
end

function resizeWatermark(text)
    local x = textBounds(text, 14)
    WmOuter.Size = UDim2.fromOffset(x + 15, 22)
end

function panicStop()
    Ref.clickToggle.Set(false)
    Ref.upgradeToggle.Set(false)
    Ref.autoTowerToggle.Set(false)
    Ref.flyToggle.Set(false)
    St.fly = false
    local hum = getHumanoid()
    if hum then hum.PlatformStand = false end
end

function holdKey(key, duration)
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, key, false, game)
    end)
    task.wait(duration)
    pcall(function()
        VirtualInputManager:SendKeyEvent(false, key, false, game)
    end)
end

runAutoTower = function()
    local root = getRootPart()
    if root then
        root.CFrame = CFrame.new(TOWER_POS)
        task.wait(0.08)
        root.CFrame = CFrame.new(TOWER_POS)
    end
    holdKey(Enum.KeyCode.W, W_HOLD_TIME)
end

function getUpgradeOrder()
    if not St.rebirthPriority then return Upgrades end
    local order = { "Rebirth" }
    for _, name in ipairs(Upgrades) do
        if name ~= "Rebirth" then table.insert(order, name) end
    end
    return order
end

function unloadScript()
    saveCurrentProfile()
    pcall(function()
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.W, false, game)
    end)
    St.fly = false
    St.noclip = false
    setNoclip(false)
    workspace.Gravity = Stats.defaultGravity
    local hum = getHumanoid()
    if hum then hum.PlatformStand = false; hum.WalkSpeed = 16 end
    resetAllVisuals()
    resetCharacterFun(false)
    resetOthersFun(false)
    if VisualCC then VisualCC:Destroy() end
    if VisualBlur then VisualBlur:Destroy() end
    if VisualBloom then VisualBloom:Destroy() end
    if CharHighlight then CharHighlight:Destroy() end
    if VisualOverlayGui then VisualOverlayGui:Destroy() end
    St.running = false
    for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
    table.clear(Connections)
    ScreenGui:Destroy()
end

function hookPlayerOthers(plr)
    plr.CharacterAdded:Connect(function()
        task.wait(0.3)
        if St.highlightOthers or St.rainbowOthers or St.spinOthers or St.giantOthers then
            applyOthersFun()
        end
    end)
end

connect(LocalPlayer.CharacterAdded, function()
    task.wait(0.3)
    CharExtras.lastScale = 0
    CharExtras.fire = nil
    CharExtras.billboard = nil
    CharExtras.sparkles = nil
    if St.noclip then setNoclip(true) end
    applyCharacterFun()
end)

for _, plr in Players:GetPlayers() do
    if plr ~= LocalPlayer then hookPlayerOthers(plr) end
end
connect(Players.PlayerAdded, hookPlayerOthers)

-- Window drag
local winDrag, winDragStart, winStart = false, nil, nil
TitleDrag.MouseButton1Down:Connect(function()
    winDrag = true
    winDragStart = UserInputService:GetMouseLocation()
    winStart = WindowOuter.AbsolutePosition
end)

local wmDrag, wmDragStart, wmStart = false, nil, nil
WmDragBtn.MouseButton1Down:Connect(function()
    wmDrag = true
    wmDragStart = UserInputService:GetMouseLocation()
    wmStart = WmOuter.AbsolutePosition
end)

connect(UserInputService.InputChanged, function(i)
    if i.UserInputType ~= Enum.UserInputType.MouseMovement then return end
    local m = UserInputService:GetMouseLocation()
    if winDrag then
        local d = m - winDragStart
        WindowOuter.Position = UDim2.fromOffset(winStart.X + d.X, winStart.Y + d.Y)
    elseif wmDrag then
        local d = m - wmDragStart
        WmOuter.Position = UDim2.fromOffset(wmStart.X + d.X, wmStart.Y + d.Y)
    end
end)

connect(UserInputService.InputEnded, function(i)
    if i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    if winDrag then
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
    end
    wmDrag = false
end)

function setUIVisible(show)
    St.uiHidden = not show
    WindowOuter.Visible = show
end

connect(UserInputService.InputBegan, function(input)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if input.KeyCode == CLICK_HOTKEY then
        Ref.clickToggle.Set(not St.click)
        return
    end
    if input.KeyCode == UPGRADE_HOTKEY then
        Ref.upgradeToggle.Set(not St.upgrade)
        return
    end
    if input.KeyCode == TOWER_HOTKEY then
        task.spawn(runAutoTower)
        return
    end
    if input.KeyCode == AFK_HOTKEY then
        Ref.antiAfkToggle.Set(not St.antiAfk)
        return
    end
    if input.KeyCode == PANIC_KEY then
        panicStop()
        return
    end
    for _, key in ipairs(HIDE_KEYS) do
        if input.KeyCode == key then
            setUIVisible(St.uiHidden)
            break
        end
    end
end)

task.spawn(function()
    while St.running do
        Stats.cps = Stats.cpsTick
        Stats.fps = Stats.fpsTick
        Stats.cpsTick = 0
        Stats.fpsTick = 0
        task.wait(1)
    end
end)

task.spawn(function()
    while St.running do
        local text = buildWatermarkText()
        Watermark.Text = text
        resizeWatermark(text)
        task.wait(0.25)
    end
end)

migrateLegacyConfig()
if not loadProfile(ConfigMeta.lastProfile) then
    loadProfile("default")
end
refreshProfileList()
clearVisualEffects()

-- AUTOMATION
connect(RunService.RenderStepped, function(dt)
    if not St.running then return end
    Stats.fpsTick += 1

    local hum = getHumanoid()
    local root = getRootPart()
    if hum then
        if St.speed then
            hum.WalkSpeed = St.speedVal
        elseif not St.fly then
            hum.WalkSpeed = 16
        end
    end

    if St.fly and root then
        local cam = workspace.CurrentCamera
        if cam then
            if hum then hum.PlatformStand = true end
            local move = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then move -= cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.yAxis end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move -= Vector3.yAxis end
            if move.Magnitude > 0 then
                root.CFrame += move.Unit * St.flySpeed * dt
            end
        end
    end

    if St.noclip then
        setNoclip(true)
    end

    if St.spin and root then
        root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(St.spinSpeed), 0)
    end

    applyCharacterFun()
    applyOthersFun()

    if not anyVisualsActive() then return end
    local cam = workspace.CurrentCamera
    if not cam then return end

    if VisualState.rainbowGui or VisualState.rainbowWorld then
        RainbowHue = (RainbowHue + (VisualState.rainbowSpeed * 0.015)) % 1
    end

    if VisualState.rainbowGui then
        applyAccent(hueColor(RainbowHue, 0.85, 1))
    end

    if VisualState.rainbowWorld then
        VisualState.worldTintHue = RainbowHue
        if ScreenTint then
            local c = hueColor(RainbowHue, 0.95, 1)
            ScreenTint.BackgroundColor3 = c
            if VisualCC then VisualCC.TintColor = c end
        end
        if VisualHuePreview then
            VisualHuePreview.BackgroundColor3 = hueColor(RainbowHue, 1, 1)
        end
    end

    if VisualState.fovOverride then
        local base = VisualState.fov
        if VisualState.drunkCam then
            base = base + math.sin(tick() * 3.5) * 12
        end
        cam.FieldOfView = base
    elseif VisualState.drunkCam then
        cam.FieldOfView = 70 + math.sin(tick() * 3.5) * 12
    end
end)

connect(RunService.Heartbeat, function()
    if not St.running or not St.click then return end
    local now = tick()
    if St.clickThrottle > 0 and (now - St.lastClickTime) < St.clickThrottle then return end
    St.lastClickTime = now
    fireClicks()
end)

connect(UserInputService.JumpRequest, function()
    if not St.running or not St.infJump then return end
    local hum = getHumanoid()
    if hum then
        hum.JumpPower = 120
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)

task.spawn(function()
    while St.running do
        if St.upgrade then
            local didAny = false
            if St.roundRobin then
                local order = getUpgradeOrder()
                local count = #order
                for _ = 1, count do
                    if not St.running or not St.upgrade then break end
                    local name = order[Stats.rrIndex]
                    Stats.rrIndex = Stats.rrIndex % count + 1
                    if UpgradeChoices[name] then
                        if purchaseUpgrade(name) then
                            didAny = true
                            Stats.upgrades += 1
                            if St.turboUpgrades then
                                task.wait()
                                continue
                            end
                        end
                        break
                    end
                end
                if not St.turboUpgrades or not didAny then
                    task.wait(St.upgradeDelay)
                end
            else
                for _, upgradeName in ipairs(getUpgradeOrder()) do
                    if not St.running or not St.upgrade then break end
                    if UpgradeChoices[upgradeName] then
                        if purchaseUpgrade(upgradeName) then
                            didAny = true
                            Stats.upgrades += 1
                            if St.turboUpgrades then
                                task.wait()
                                continue
                            end
                        end
                        task.wait(St.upgradeDelay)
                    end
                end
            end
            task.wait(didAny and (St.turboUpgrades and 0.05 or St.upgradeDelay) or 0.15)
        else
            task.wait(0.5)
        end
    end
end)

pcall(function() VirtualUser:CaptureController() end)

task.spawn(function()
    while St.running do
        if St.antiAfk then
            pcall(function() VirtualUser:ClickButton2(Vector2.new(0, 0)) end)
            pcall(function() VirtualUser:CaptureController() end)
            task.wait(25)
        else
            task.wait(1)
        end
    end
end)

task.spawn(function()
    while St.running do
        if St.autoTower then
            task.wait(St.towerInterval)
            if St.running and St.autoTower then
                runAutoTower()
            end
        else
            task.wait(1)
        end
    end
end)

task.spawn(function()
    while St.running do
        task.wait(60)
        if St.running and St.autoSaveProfiles then
            saveCurrentProfile()
        end
    end
end)
