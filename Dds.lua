-- Drag Drive Simulator — v2.6 (Final Build)
-- Fix: UI toggle (FAB hides when panel open, X button shows FAB, hotkey syncs)
-- Stealth: No print/warn, no firesignal, marker-based GUI cleanup
-- Target: Roblox (Delta PC + Delta Mobile / Arceus / Krnl / Wave / Xeno)

if _G.DDS_Connections then
    for _, c in ipairs(_G.DDS_Connections) do pcall(function() c:Disconnect() end) end
end
_G.DDS_Connections = {}

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInput         = game:GetService("UserInputService")
local Lighting          = game:GetService("Lighting")
local Workspace         = game:GetService("Workspace")
local VirtualUser       = game:GetService("VirtualUser")
local VIM               = game:GetService("VirtualInputManager")
local TweenService      = game:GetService("TweenService")
local CoreGui           = game:GetService("CoreGui")
local HttpService       = game:GetService("HttpService")
local Stats             = game:GetService("Stats")

local LP        = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")

local function track(c) table.insert(_G.DDS_Connections, c); return c end

do
    if _G.DDS_Gui and _G.DDS_Gui.Parent then pcall(function() _G.DDS_Gui:Destroy() end) end
    if _G.DDS_Hud and _G.DDS_Hud.Parent then pcall(function() _G.DDS_Hud:Destroy() end) end
    _G.DDS_Gui = nil
    _G.DDS_Hud = nil
    for _, host in ipairs({CoreGui, PlayerGui}) do
        if host then
            for _, old in ipairs(host:GetChildren()) do
                if old:IsA("ScreenGui") then
                    if old:FindFirstChild("_Signature") then
                        pcall(function() old:Destroy() end)
                    elseif old.Name:sub(1,4) == "DDS_" then
                        pcall(function() old:Destroy() end)
                    end
                end
            end
        end
    end
end

local HasWritefile = (type(writefile) == "function" and type(readfile) == "function")
local IsMobileHardware = UserInput.TouchEnabled and not UserInput.KeyboardEnabled

local Config = {
    InputMode = "Auto",
    HumanizeInput = true,
    PerfectStart = false, LaunchRPM = 0.62, LaunchRampTime = 0.45, LaunchDelay = 0.05,
    ManualClutchMode = true,
    UseGear1 = true, UseWheelieHold = false, SafeWheelieBikeOnly = true,
    AutoShift = false, ShiftPoint = 0.93, NoDrag = false,
    SpeedEnabled = false, CarTargetKmh = 180, BikeTargetKmh = 160,
    MaxTargetKmh = 320, MinTargetKmh = 40,
    AccelRate = 0.10, DecelRate = 0.25, HysteresisKmh = 2.0,
    MaxDeltaKmhPerFrame = 6, MinCurrentKmh = 5, StudsToKmh = 1.008,
    SpeedMethod = "LinearVelocity",
    ESP = false, ESPNames = false, ESPHealth = true, ESPDistance = true,
    ESPColor = Color3.fromRGB(0, 255, 180),
    Fullbright = false, NoFog = false, FOV = 80, CameraLock = false,
    CameraLerpAlpha = 0.25,
    AntiAFK = true,
    AutoCourier = false, AutoBarista = false, AutoOffice = false,
    FarmQueueMode = false, FarmRadius = 120, FarmInterval = 0.8,
    TeleportFarm = true, TeleportOffset = Vector3.new(0, 3, 0),
    ScanAllMaps = true, PromptHold = 0.15,
    OfficeMathLinked = true,
    MathSolver = false, MathInterval = 1.5, MathSubmit = true,
    MathRetryLimit = 4, MathCacheTTL = 8.0,
    AutoUpgrade = false, UpgradeCheck = 3.0,
    UpgradePriority = {"Engine", "Turbo", "Weight", "Grip", "Transmission"},
    AutoRedeem = false,
    RedeemCodes = {
        "DRAGDRIVESIMULATORSEPTEMBER26",
        "DRAGDRIVESIMULATORAUGUST26",
        "DDSSPECIALMERDEKA2026",
        "NEWLIGHTSMODIFICATION",
        "DDSTHX175KROADTO200KLIKES",
        "DRAGDRIVESIMULATORJULY26",
        "DDSSLAMETRIYADIUPDATE",
        "DELAYDIKITBARULOMBA",
    },
    RedeemInterval = 5.0,
    VisualSafetyInterval = 2.0,
    LogEnabled = false,
    HotkeyToggle = Enum.KeyCode.RightControl,
    SaveConfigOnChange = true,
}
local ConfigDefaults = table.clone(Config)

local CONFIG_PATH = ".cache_settings.json"

local function saveConfig()
    if not HasWritefile then return false end
    return pcall(function()
        local data = {}
        for k, v in pairs(Config) do
            local t = type(v)
            if t == "number" or t == "string" or t == "boolean" then
                data[k] = v
            elseif typeof(v) == "Color3" then
                data[k] = {__color = true, r = v.R, g = v.G, b = v.B}
            elseif typeof(v) == "EnumItem" and v.EnumType == Enum.KeyCode then
                data[k] = {__keycode = v.Name}
            end
        end
        writefile(CONFIG_PATH, HttpService:JSONEncode(data))
    end)
end

local function loadConfig()
    if not HasWritefile then return end
    if not isfile(CONFIG_PATH) then return end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(CONFIG_PATH))
    end)
    if not ok or type(data) ~= "table" then return end
    for k, v in pairs(data) do
        if ConfigDefaults[k] ~= nil then
            local tDef = type(ConfigDefaults[k])
            if tDef == "number" or tDef == "string" or tDef == "boolean" then
                if type(v) == tDef then Config[k] = v end
            elseif typeof(ConfigDefaults[k]) == "Color3" and type(v) == "table" and v.__color then
                Config[k] = Color3.new(v.r, v.g, v.b)
            elseif typeof(ConfigDefaults[k]) == "EnumItem" and type(v) == "table" and v.__keycode then
                local okE, kc = pcall(function() return Enum.KeyCode[v.__keycode] end)
                if okE and kc then Config[k] = kc end
            end
        end
    end
end

local saveDebounce = 0
local function requestSave()
    if not Config.SaveConfigOnChange then return end
    local now = os.clock()
    if now - saveDebounce < 1.0 then return end
    saveDebounce = now
    task.spawn(saveConfig)
end

local State = {
    Vehicle = nil, VehicleRoot = nil, IsBike = false, VehicleName = "",
    RpmValue = nil, RpmMax = 8000, Ready = false,
    GearValues = {}, WheelieValues = {}, ESPObjects = {}, UI = {},
    LastUpgrade = 0, LastRedeem = 0, LastMath = 0,
    UpgradeBusy = false, RedeemIndex = 1, RedeemBusy = false,
    RedeemOK = 0, RedeemFail = 0, RedeemCycleDone = false,
    MathBusy = false, MathSeen = {},
    MathOK = 0, MathFail = 0,
    MathSolverIntent = nil,
    FarmQueueIdx = 1, SpeedCurrentKmh = 0,
    CurrentJob = nil,
    NoDragLastMag = 0,
    CameraLockedByUs = false,
    LastLaunchTime = 0,
    LastRpmRefresh = 0,
    LastGearShift = 0,
    LastSpeedMethod = "LinearVelocity",
    LVConstraint = nil, LVAttachment = nil,
    PromptCache = {},
    Log = {},
    FPS = 0, Ping = 0,
    HeldKeys = {},
    MobileHolds = {},
    LaunchPhase = "idle",
    LaunchStart = 0,
    CachedInputMode = nil,
    ManualClutchOn = false,
}

loadConfig()

local function LogRing(msg, lvl)
    if not Config.LogEnabled then return end
    msg = tostring(msg):gsub("DDS", "SYS"):gsub("Exploit", "Info")
    lvl = lvl or "I"
    table.insert(State.Log, {t = os.clock(), lvl = lvl, msg = msg})
    if #State.Log > 50 then table.remove(State.Log, 1) end
end
_G.DDS_Log = function() return State.Log end

local function watchdog(name, fn, interval)
    local function getInterval()
        if type(interval) == "function" then return interval() end
        return interval
    end
    task.spawn(function()
        local waitT = getInterval()
        while true do
            local ok, _ = pcall(fn)
            if not ok then
                waitT = math.min(waitT * 2, 10)
                task.wait(waitT)
            else
                waitT = getInterval()
                task.wait(waitT)
            end
        end
    end)
end

local function normName(s)
    if not s or s == "" then return "" end
    s = s:gsub("(%l)(%u)", "%1 %2")
    s = s:gsub("(%u)(%u%l)", "%1 %2")
    s = s:gsub("[_%-]", " ")
    return s:lower()
end

local GuiScanCache = { cache = {}, lastScan = 0, TTL = 0.2 }
local function guiCacheKey(keywords) return table.concat(keywords, "|") end

local function isAncestorChainVisible(g)
    if not g or not g.Parent then return false end
    local cur = g
    while cur and cur ~= PlayerGui do
        if cur:IsA("GuiObject") then
            local ok, v = pcall(function() return cur.Visible end)
            if not ok or not v then return false end
        end
        cur = cur.Parent
    end
    return true
end

local function matchesKeyword(name, kw)
    if not name or name == "" then return false end
    local l = normName(name)
    kw = normName(kw)
    if kw == "" then return false end
    if l == kw then return true end
    if l:sub(1, #kw + 1) == kw .. " " then return true end
    if l:sub(-(#kw + 1)) == " " .. kw then return true end
    if l:find("%f[%w]" .. kw .. "%f[%W]") then return true end
    return false
end

local function safeText(g)
    if not g then return "" end
    local ok, t = pcall(function() return g.Text end)
    if ok and type(t) == "string" then return t end
    return ""
end

local function findGuiByKeywords(keywords)
    local key = guiCacheKey(keywords)
    local now = os.clock()
    if (now - GuiScanCache.lastScan) > GuiScanCache.TTL then
        table.clear(GuiScanCache.cache)
        GuiScanCache.lastScan = now
    end
    local cached = GuiScanCache.cache[key]
    if cached and cached.Parent and cached:IsDescendantOf(PlayerGui) and isAncestorChainVisible(cached) then
        return cached
    end
    local sorted = table.clone(keywords)
    table.sort(sorted, function(a, b) return #a > #b end)
    for _, g in ipairs(PlayerGui:GetDescendants()) do
        if g:IsA("GuiButton") and isAncestorChainVisible(g) then
            for _, k in ipairs(sorted) do
                if matchesKeyword(g.Name, k) or matchesKeyword(safeText(g), k) then
                    GuiScanCache.cache[key] = g
                    return g
                end
            end
        end
    end
    return nil
end

local function findInteractButton() return findGuiByKeywords({"interact","talk","work","mulai","start","ambil","deliver","serve","kerja"}) end
local function findRedeemInput()    return findGuiByKeywords({"redeem input","code input","kode","enter code"}) end
local function findRedeemButton()   return findGuiByKeywords({"redeem","tukar","klaim"}) end
local function findShopButton()     return findGuiByKeywords({"shop","store","toko","upgrade","garage"}) end
local function findSubmitButton()   return findGuiByKeywords({"submit","kirim","answer","jawab","confirm","ok"}) end

local function resolveInputMode()
    if Config.InputMode == "Keyboard" or Config.InputMode == "GUI" then
        return Config.InputMode
    end
    if State.CachedInputMode then return State.CachedInputMode end
    State.CachedInputMode = IsMobileHardware and "GUI" or "Keyboard"
    return State.CachedInputMode
end

track(UserInput:GetPropertyChangedSignal("KeyboardEnabled"):Connect(function()
    State.CachedInputMode = nil
end))
track(UserInput:GetPropertyChangedSignal("TouchEnabled"):Connect(function()
    State.CachedInputMode = nil
end))

local function setKeyHeld(keyCode, held)
    if State.HeldKeys[keyCode] == held then return end
    State.HeldKeys[keyCode] = held
    pcall(function()
        VIM:SendKeyEvent(held, keyCode, false, game)
    end)
end

local function tapKey(keyCode, hold)
    hold = hold or 0.05
    pcall(function()
        VIM:SendKeyEvent(true, keyCode, false, game)
        task.wait(hold)
        VIM:SendKeyEvent(false, keyCode, false, game)
    end)
end

local function fireClick(btn, hold)
    if not btn or not btn.Parent then return false end
    hold = hold or 0.02
    local posX, posY
    local okRead = pcall(function()
        local p = btn.AbsolutePosition + btn.AbsoluteSize * 0.5
        if Config.HumanizeInput then
            local bs = btn.AbsoluteSize
            local maxJx = math.min(bs.X * 0.3, 16)
            local maxJy = math.min(bs.Y * 0.3, 16)
            if bs.X < 30 then maxJx = math.min(bs.X * 0.2, 8) end
            if bs.Y < 30 then maxJy = math.min(bs.Y * 0.2, 8) end
            posX = p.X + (math.random() - 0.5) * maxJx
            posY = p.Y + (math.random() - 0.5) * maxJy
        else
            posX = p.X; posY = p.Y
        end
    end)
    if not okRead or not posX then return false end
    local cam = Workspace.CurrentCamera
    if cam then
        local vp = cam.ViewportSize
        if posX < 0 or posY < 0 or posX > vp.X or posY > vp.Y then return false end
    end
    local actualHold = hold
    if Config.HumanizeInput then
        actualHold = math.max(0.01, hold * (1 + (math.random() - 0.5) * 0.30))
    end
    return pcall(function()
        VIM:SendMouseButtonEvent(posX, posY, 0, true, game, 0)
        task.wait(actualHold)
        VIM:SendMouseButtonEvent(posX, posY, 0, false, game, 0)
    end)
end

local function mobileHoldStart(key, btn)
    if not btn or not btn.Parent then return false end
    local existing = State.MobileHolds[key]
    if existing and existing.btn == btn then return true end
    if existing then
        pcall(function()
            VIM:SendMouseButtonEvent(existing.x, existing.y, 0, false, game, 0)
        end)
        State.MobileHolds[key] = nil
    end
    local ok, p = pcall(function()
        local base = btn.AbsolutePosition + btn.AbsoluteSize * 0.5
        if Config.HumanizeInput then
            local bs = btn.AbsoluteSize
            local maxJx = math.min(bs.X * 0.3, 16)
            local maxJy = math.min(bs.Y * 0.3, 16)
            return Vector2.new(
                base.X + (math.random() - 0.5) * maxJx,
                base.Y + (math.random() - 0.5) * maxJy
            )
        end
        return base
    end)
    if not ok or not p then return false end
    pcall(function()
        VIM:SendMouseButtonEvent(p.X, p.Y, 0, true, game, 0)
    end)
    State.MobileHolds[key] = { btn = btn, x = p.X, y = p.Y }
    return true
end

local function mobileHoldEnd(key)
    local h = State.MobileHolds[key]
    if not h then return end
    local x, y = h.x, h.y
    State.MobileHolds[key] = nil
    pcall(function()
        VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end)
end

local function releaseAllInput()
    for k, held in pairs(State.HeldKeys) do
        if held then
            pcall(function() VIM:SendKeyEvent(false, k, false, game) end)
        end
    end
    table.clear(State.HeldKeys)
    local keys = {}
    for k in pairs(State.MobileHolds) do table.insert(keys, k) end
    for _, k in ipairs(keys) do mobileHoldEnd(k) end
end

local function actionAccelerate(hold)
    if resolveInputMode() == "Keyboard" then
        if hold then tapKey(Enum.KeyCode.W, hold)
        else setKeyHeld(Enum.KeyCode.W, true) end
    else
        local btn = findGuiByKeywords({"gas","throttle","accelerate","injak","maju"})
        if btn then
            if hold then fireClick(btn, hold)
            else mobileHoldStart("gas", btn) end
        end
    end
end

local function actionReleaseAccelerate()
    if resolveInputMode() == "Keyboard" then
        setKeyHeld(Enum.KeyCode.W, false)
    else
        mobileHoldEnd("gas")
    end
end

local function actionShiftUp()
    if resolveInputMode() == "Keyboard" then
        tapKey(Enum.KeyCode.E, 0.03)
    else
        local btn = findGuiByKeywords({"shift up","gear up","naik","gigi naik","up"})
        if btn then fireClick(btn, 0.03) end
    end
end

local function actionShiftDown()
    if resolveInputMode() == "Keyboard" then
        tapKey(Enum.KeyCode.Q, 0.03)
    else
        local btn = findGuiByKeywords({"shift down","gear down","turun","down"})
        if btn then fireClick(btn, 0.03) end
    end
end

local function actionEnableManualClutch()
    if State.ManualClutchOn then return true end
    if resolveInputMode() == "Keyboard" then
        tapKey(Enum.KeyCode.M, 0.04)
        State.ManualClutchOn = true
        return true
    else
        local btn = findGuiByKeywords({"clutch mode","manual clutch","clutch toggle","mode clutch"})
        if btn then
            fireClick(btn, 0.08)
            State.ManualClutchOn = true
            return true
        end
        State.ManualClutchOn = true
        return false
    end
end

local function actionClutchHold(held)
    if resolveInputMode() == "Keyboard" then
        setKeyHeld(Enum.KeyCode.LeftShift, held)
    else
        if held then
            local btn = findGuiByKeywords({"clutch hold","clutch","kopling"})
            if btn then mobileHoldStart("clutch", btn) end
        else
            mobileHoldEnd("clutch")
        end
    end
end

local function actionNeutral()
    for _ = 1, 5 do actionShiftDown() end
end

local function actionTopGear()
    for _ = 1, 5 do actionShiftUp() end
end

local function actionWheelieHold(held)
    if resolveInputMode() == "Keyboard" then
        setKeyHeld(Enum.KeyCode.T, held)
    else
        if held then
            local btn = findGuiByKeywords({"wheelie","angkat","stunt","trick","lean"})
            if btn then mobileHoldStart("wheelie", btn) end
        else
            mobileHoldEnd("wheelie")
        end
    end
end

local BIKE_HINTS = {"bike","motor","moto","r1","r6","cbr","ninja","gsxr","ducati","harley","scooter","vixion","beat","nmax","pcx","aerox","vario","satria","sonic"}
local CAR_HINTS  = {"car","mobil","sedan","coupe","truck","supra","skyline","gt","ferrari","lambo","civic","jazz","avanza","gatsu","wheelie","wide","rim","limited"}

local function classifyVehicle(model)
    if not model then return false, "" end
    local name = model.Name:lower()
    for _, h in ipairs(BIKE_HINTS) do if name:find(h) then return true, model.Name end end
    for _, h in ipairs(CAR_HINTS)  do if name:find(h) then return false, model.Name end end
    local c = 0
    for _, d in ipairs(model:GetDescendants()) do if d:IsA("BasePart") then c += 1 end end
    return c < 40, model.Name
end

local function teardownLinearVelocity()
    if State.LVConstraint and State.LVConstraint.Parent then State.LVConstraint:Destroy() end
    if State.LVAttachment and State.LVAttachment.Parent then State.LVAttachment:Destroy() end
    State.LVConstraint = nil; State.LVAttachment = nil
end

local function cacheVehicleParts(model)
    teardownLinearVelocity()
    State.RpmValue = nil; State.RpmMax = 8000
    State.VehicleRoot = nil; State.GearValues = {}; State.WheelieValues = {}
    if not model then return end
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("NumberValue") then
            local n = d.Name:lower()
            if n:find("rpm") and not State.RpmValue then State.RpmValue = d end
            if n:find("gear") or n:find("ratio") then table.insert(State.GearValues, {name=d.Name, value=d.Value}) end
            if n:find("wheelie") then table.insert(State.WheelieValues, {name=d.Name, value=d.Value}) end
        end
    end
    local mx = model:FindFirstChild("MaxRPM") or model:FindFirstChild("Redline")
    if mx and mx:IsA("NumberValue") then State.RpmMax = mx.Value end
    local drive = model:FindFirstChild("DriveSeat") or model:FindFirstChild("VehicleSeat")
    if drive and drive:IsA("BasePart") then State.VehicleRoot = drive
    elseif model.PrimaryPart then State.VehicleRoot = model.PrimaryPart end
end

local function findVehicle()
    local char = LP.Character; if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return nil end
    local seat = hum.SeatPart
    if seat and (seat:IsA("VehicleSeat") or seat:IsA("Seat")) then return seat.Parent end
    return nil
end

task.spawn(function()
    while task.wait(0.4) do
        local v = findVehicle()
        if v ~= State.Vehicle then
            releaseAllInput()
            State.Vehicle = v
            State.IsBike, State.VehicleName = classifyVehicle(v)
            cacheVehicleParts(v)
            State.Ready = (v ~= nil and State.VehicleRoot ~= nil)
            State.NoDragLastMag = 0
            State.LaunchPhase = "idle"
            State.ManualClutchOn = false
            State.LastSpeedMethod = Config.SpeedMethod
            table.clear(State.PromptCache)
        end
    end
end)

local function refreshRpmValue()
    if not State.Vehicle or not State.Vehicle.Parent then State.RpmValue = nil; return end
    State.RpmValue = nil
    for _, d in ipairs(State.Vehicle:GetDescendants()) do
        if d:IsA("NumberValue") and d.Name:lower():find("rpm") then
            State.RpmValue = d; return
        end
    end
end

local function getRPM()
    if State.RpmValue and State.RpmValue.Parent then
        local ok, v = pcall(function() return State.RpmValue.Value end)
        if ok and type(v) == "number" then return v, State.RpmMax end
    end
    if State.Vehicle and os.clock() - State.LastRpmRefresh > 2.0 then
        State.LastRpmRefresh = os.clock()
        refreshRpmValue()
        if State.RpmValue and State.RpmValue.Parent then
            local ok, v = pcall(function() return State.RpmValue.Value end)
            if ok and type(v) == "number" then return v, State.RpmMax end
        end
    end
    local root = State.VehicleRoot
    if root and root.Parent then
        local ok, angVel = pcall(function() return root.AssemblyAngularVelocity end)
        if ok and angVel and angVel.Magnitude > 1 then
            return angVel.Magnitude * 60 / (2 * math.pi), State.RpmMax
        end
    end
    return 0, State.RpmMax
end

local guiSnap = { last = 0, list = {} }
local function getGuiSnapshot()
    local now = os.clock()
    if now - guiSnap.last < 0.1 then return guiSnap.list end
    guiSnap.last = now
    local list = {}
    local ok, desc = pcall(function() return PlayerGui:GetDescendants() end)
    if not ok or not desc then return list end
    for _, g in ipairs(desc) do
        if g:IsA("TextLabel") and isAncestorChainVisible(g) then
            local t = safeText(g)
            if t ~= "" then table.insert(list, t) end
        end
    end
    guiSnap.list = list
    return list
end

local function countdownVisible(digit)
    local target = tostring(digit)
    for _, t in ipairs(getGuiSnapshot()) do
        local stripped = t:gsub("%s+", ""):gsub("[^%d]", "")
        if stripped == target then return true end
        local first = t:match("^%s*(%d)")
        if first == target and not t:match("%d%d") then return true end
    end
    return false
end

local function greenVisible()
    for _, t in ipairs(getGuiSnapshot()) do
        local l = t:lower():gsub("%s+", "")
        if l == "go" or l == "go!" or l == "start" or l == "mulai" then return true end
    end
    return false
end

track(RunService.Heartbeat:Connect(function()
    if not Config.PerfectStart or not State.Ready then
        if State.LaunchPhase ~= "idle"
            or State.HeldKeys[Enum.KeyCode.W]
            or State.MobileHolds.gas
        then
            State.LaunchPhase = "idle"
            actionClutchHold(false)
            actionReleaseAccelerate()
            actionWheelieHold(false)
        end
        return
    end
    local ok = pcall(function()
        local rpm, max = getRPM()
        local ratio = max > 0 and rpm / max or 0

        if State.LaunchPhase == "idle" and countdownVisible(3) then
            if os.clock() - State.LastLaunchTime < 10 then return end
            State.LastLaunchTime = os.clock()
            State.LaunchPhase = "prep"; State.LaunchStart = os.clock()

            if Config.ManualClutchMode then actionEnableManualClutch() end
            actionNeutral()
            task.wait(0.05)
            if Config.UseGear1 then actionShiftUp() end
            if Config.ManualClutchMode then actionClutchHold(true) end
            local doWheelie = Config.UseWheelieHold and (State.IsBike or not Config.SafeWheelieBikeOnly)
            if doWheelie then actionWheelieHold(true) end
        end

        if State.LaunchPhase == "prep" then
            local elapsed = os.clock() - State.LaunchStart
            if ratio < Config.LaunchRPM - 0.03 then actionAccelerate(false) end
            if ratio > 0.98 then actionReleaseAccelerate() end
            if elapsed >= Config.LaunchRampTime then
                State.LaunchPhase = "hold"; State.LaunchStart = os.clock()
            end
            return
        end

        if State.LaunchPhase == "hold" then
            if ratio < Config.LaunchRPM - 0.04 then actionAccelerate(false) end
            if ratio > 0.98 then actionReleaseAccelerate() end
            if greenVisible() then
                State.LaunchPhase = "launch"; State.LaunchStart = os.clock()
                actionClutchHold(false)
            elseif os.clock() - State.LaunchStart > 2.5 then
                State.LaunchPhase = "idle"
                actionClutchHold(false)
                actionReleaseAccelerate()
                actionWheelieHold(false)
            end
            return
        end

        if State.LaunchPhase == "launch" then
            if os.clock() - State.LaunchStart >= Config.LaunchDelay then
                State.LaunchPhase = "idle"
            end
        end
    end)
    if not ok then
        State.LaunchPhase = "idle"
        actionClutchHold(false)
        actionReleaseAccelerate()
        actionWheelieHold(false)
    end
end))

track(RunService.Heartbeat:Connect(function()
    if not Config.AutoShift or not State.Ready then return end
    if State.LaunchPhase ~= "idle" then return end
    if os.clock() - State.LastGearShift < 0.5 then return end
    local rpm, max = getRPM(); if max <= 0 then return end
    if rpm / max >= Config.ShiftPoint then
        actionShiftUp()
        State.LastGearShift = os.clock()
    end
end))

local function easeSine(t) return math.sin(math.clamp(t, 0, 1) * math.pi * 0.5) end

local function setupLinearVelocity()
    local root = State.VehicleRoot
    if not root or not root.Parent then return end
    if State.LVConstraint and State.LVConstraint.Parent then return end
    local att = Instance.new("Attachment")
    att.Name = "A"; att.Parent = root
    local lv = Instance.new("LinearVelocity")
    lv.Name = "V"; lv.Attachment0 = att
    lv.MaxForce = math.huge; lv.VectorVelocity = Vector3.zero
    lv.Parent = root
    State.LVAttachment = att; State.LVConstraint = lv
end

track(RunService.Stepped:Connect(function()
    if State.LastSpeedMethod ~= Config.SpeedMethod then
        teardownLinearVelocity()
        State.LastSpeedMethod = Config.SpeedMethod
    end
    if not Config.SpeedEnabled or not State.Ready then
        State.SpeedCurrentKmh = 0
        if State.LVConstraint then teardownLinearVelocity() end
        return
    end
    local root = State.VehicleRoot
    if not root or not root.Parent then
        if State.LVConstraint then teardownLinearVelocity() end
        return
    end
    local targetKmh = State.IsBike and Config.BikeTargetKmh or Config.CarTargetKmh
    targetKmh = math.clamp(targetKmh, Config.MinTargetKmh, Config.MaxTargetKmh)
    local vel = root.AssemblyLinearVelocity
    local mag = vel.Magnitude
    if mag < 0.5 then return end
    local currentKmh = mag * Config.StudsToKmh
    if currentKmh < Config.MinCurrentKmh then return end
    local diff = targetKmh - currentKmh
    if math.abs(diff) < Config.HysteresisKmh then State.SpeedCurrentKmh = currentKmh; return end
    local rate = (diff > 0) and Config.AccelRate or Config.DecelRate
    local proximity = 1 - math.clamp(math.abs(diff) / targetKmh, 0, 1)
    local easedRate = math.max(rate * easeSine(proximity), rate * 0.2)
    local deltaKmh = math.clamp(diff * easedRate, -Config.MaxDeltaKmhPerFrame, Config.MaxDeltaKmhPerFrame)
    local deltaStuds = deltaKmh / Config.StudsToKmh
    local newMag = mag + deltaStuds
    if diff > 0 and newMag * Config.StudsToKmh > targetKmh then newMag = targetKmh / Config.StudsToKmh
    elseif diff < 0 and newMag * Config.StudsToKmh < targetKmh then newMag = targetKmh / Config.StudsToKmh end
    if newMag <= 0 then return end

    if Config.SpeedMethod == "LinearVelocity" then
        setupLinearVelocity()
        if State.LVConstraint and State.LVConstraint.Parent then
            local dir = vel.Magnitude > 0.01 and vel.Unit or root.CFrame.LookVector
            State.LVConstraint.VectorVelocity = dir * newMag
        end
    elseif Config.SpeedMethod == "Velocity" then
        local dir = vel.Magnitude > 0.01 and vel.Unit or root.CFrame.LookVector
        root.AssemblyLinearVelocity = dir * newMag
    elseif Config.SpeedMethod == "CFrame" then
        root.CFrame = root.CFrame + root.CFrame.LookVector * deltaStuds
    end
    State.SpeedCurrentKmh = newMag * Config.StudsToKmh
end))

track(RunService.Stepped:Connect(function()
    if not Config.NoDrag or not State.Ready or Config.SpeedEnabled then State.NoDragLastMag = 0; return end
    local root = State.VehicleRoot
    if not root or not root.Parent then State.NoDragLastMag = 0; return end
    local ok, vel = pcall(function() return root.AssemblyLinearVelocity end)
    if not ok or not vel then State.NoDragLastMag = 0; return end
    local mag = vel.Magnitude
    if mag > 1 and State.NoDragLastMag > 0 and mag < State.NoDragLastMag * 0.995 then
        pcall(function() root.AssemblyLinearVelocity = vel.Unit * State.NoDragLastMag end)
        mag = State.NoDragLastMag
    end
    State.NoDragLastMag = mag
end))

local function applyFullbright(on)
    if on then
        Lighting.Ambient = Color3.fromRGB(180, 180, 180)
        Lighting.OutdoorAmbient = Color3.fromRGB(180, 180, 180)
        Lighting.Brightness = 3; Lighting.ClockTime = 14
    else
        Lighting.Ambient = Color3.fromRGB(70, 70, 70)
        Lighting.OutdoorAmbient = Color3.fromRGB(70, 70, 70)
    end
end
local function applyNoFog(on) if on then Lighting.FogEnd = 1e9; Lighting.FogStart = 1e9 end end
local function applyFOV(v)
    local cam = Workspace.CurrentCamera
    if cam then cam.FieldOfView = v end
end

task.spawn(function()
    while task.wait(Config.VisualSafetyInterval) do
        if Config.Fullbright then applyFullbright(true) end
        if Config.NoFog then applyNoFog(true) end
        local cam = Workspace.CurrentCamera
        if cam and cam.FieldOfView ~= Config.FOV then applyFOV(Config.FOV) end
    end
end)

track(RunService.RenderStepped:Connect(function()
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local function restore()
        if State.CameraLockedByUs and cam.CameraType == Enum.CameraType.Scriptable then
            cam.CameraType = Enum.CameraType.Custom
        end
        State.CameraLockedByUs = false
    end
    if not Config.CameraLock then restore(); return end
    local root = State.VehicleRoot
    if not State.Ready or not root or not root.Parent then restore(); return end
    if not State.CameraLockedByUs then
        cam.CameraType = Enum.CameraType.Scriptable
        State.CameraLockedByUs = true
    end
    local look = root.CFrame.LookVector
    local targetCF = CFrame.lookAt(
        root.Position - look * 18 + Vector3.new(0, 8, 0),
        root.Position + look * 10)
    cam.CFrame = cam.CFrame:Lerp(targetCF, math.clamp(Config.CameraLerpAlpha, 0.05, 1))
end))

local function clearESP()
    for _, o in pairs(State.ESPObjects) do if o and o.Parent then o:Destroy() end end
    table.clear(State.ESPObjects)
end

local function addESP(plr)
    if plr == LP or not Config.ESP then return end
    local char = plr.Character; if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local old = State.ESPObjects[plr]; if old and old.Parent then old:Destroy() end
    local oldName = State.ESPObjects["name_" .. plr.Name]
    if oldName and oldName.Parent then oldName:Destroy() end

    local box = Instance.new("BoxHandleAdornment")
    box.Name = "A" .. plr.Name
    box.Adornee = hrp; box.AlwaysOnTop = true; box.ZIndex = 5
    box.Size = hrp.Size + Vector3.new(0.4, 0.4, 0.4)
    box.Color3 = Config.ESPColor; box.Transparency = 0.35
    box.Parent = hrp
    State.ESPObjects[plr] = box

    if Config.ESPNames or Config.ESPHealth or Config.ESPDistance then
        local bb = Instance.new("BillboardGui")
        bb.Name = "B" .. plr.Name
        bb.Adornee = hrp; bb.AlwaysOnTop = true
        bb.Size = UDim2.new(0, 160, 0, 46)
        bb.StudsOffset = Vector3.new(0, 3, 0)

        local nameLbl = Instance.new("TextLabel")
        nameLbl.Name = "N"
        nameLbl.Size = UDim2.new(1, 0, 0, 18); nameLbl.Position = UDim2.new(0, 0, 0, 0)
        nameLbl.BackgroundTransparency = 1
        nameLbl.TextColor3 = Config.ESPColor; nameLbl.Font = Enum.Font.GothamBold
        nameLbl.TextSize = 12; nameLbl.TextStrokeTransparency = 0.4
        nameLbl.Text = plr.Name; nameLbl.Visible = Config.ESPNames
        nameLbl.Parent = bb

        local hb = Instance.new("Frame")
        hb.Name = "H"
        hb.Size = UDim2.new(0.8, 0, 0, 4); hb.Position = UDim2.new(0.1, 0, 0, 20)
        hb.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        hb.BorderSizePixel = 0; hb.Visible = Config.ESPHealth; hb.Parent = bb
        local hbar = Instance.new("Frame")
        hbar.Name = "P"
        hbar.Size = UDim2.new(1, 0, 1, 0)
        hbar.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
        hbar.BorderSizePixel = 0; hbar.Parent = hb

        local dl = Instance.new("TextLabel")
        dl.Name = "D"
        dl.Size = UDim2.new(1, 0, 0, 16); dl.Position = UDim2.new(0, 0, 0, 26)
        dl.BackgroundTransparency = 1
        dl.TextColor3 = Color3.fromRGB(255, 220, 100); dl.Font = Enum.Font.Gotham
        dl.TextSize = 11; dl.TextStrokeTransparency = 0.4
        dl.Text = "-"; dl.Visible = Config.ESPDistance; dl.Parent = bb

        bb.Parent = hrp
        State.ESPObjects["name_" .. plr.Name] = bb
        State.ESPObjects["hrp_" .. plr.Name] = hrp
        State.ESPObjects["hum_" .. plr.Name] = hum
    end
end

track(RunService.RenderStepped:Connect(function()
    if not Config.ESP then return end
    local lpChar = LP.Character
    local lpHrp = lpChar and lpChar:FindFirstChild("HumanoidRootPart")
    local lpPos = lpHrp and lpHrp.Parent and lpHrp.Position
    for key, bb in pairs(State.ESPObjects) do
        if type(key) == "string" and key:sub(1, 5) == "name_" then
            local plrName = key:sub(6)
            if bb and bb.Parent then
                local hum = State.ESPObjects["hum_" .. plrName]
                local hrp = State.ESPObjects["hrp_" .. plrName]
                local hb = bb:FindFirstChild("H")
                if hb then
                    local bar = hb:FindFirstChild("P")
                    if bar and hum then
                        local okH, h = pcall(function() return hum.Health end)
                        local okM, m = pcall(function() return hum.MaxHealth end)
                        if okH and okM then
                            local pct = math.clamp(h / math.max(m, 1), 0, 1)
                            bar.Size = UDim2.new(pct, 0, 1, 0)
                            bar.BackgroundColor3 = Color3.fromRGB(
                                math.floor(255 * (1 - pct)), math.floor(255 * pct), 50)
                        end
                    end
                end
                local dl = bb:FindFirstChild("D")
                if dl and hrp and hrp.Parent and lpPos then
                    local okP, hrpPos = pcall(function() return hrp.Position end)
                    if okP and hrpPos then
                        dl.Text = string.format("%d studs", math.floor((hrpPos - lpPos).Magnitude))
                    end
                end
            end
        end
    end
end))

track(Players.PlayerAdded:Connect(function(plr)
    track(plr.CharacterAdded:Connect(function()
        if Config.ESP then task.wait(0.3); addESP(plr) end
    end))
end))
for _, p in ipairs(Players:GetPlayers()) do
    track(p.CharacterAdded:Connect(function()
        if Config.ESP then task.wait(0.3); addESP(p) end
    end))
    if p.Character and Config.ESP then addESP(p) end
end
track(Players.PlayerRemoving:Connect(function(p)
    local box = State.ESPObjects[p]
    if box and box.Parent then box:Destroy() end
    State.ESPObjects[p] = nil
    local nm = State.ESPObjects["name_" .. p.Name]
    if nm and nm.Parent then nm:Destroy() end
    State.ESPObjects["name_" .. p.Name] = nil
    State.ESPObjects["hrp_" .. p.Name] = nil
    State.ESPObjects["hum_" .. p.Name] = nil
end))

local function refreshESPAll()
    if Config.ESP then
        for _, p in ipairs(Players:GetPlayers()) do if p ~= LP then addESP(p) end end
    else
        clearESP()
    end
end

track(LP.Idled:Connect(function()
    if not Config.AntiAFK then return end
    releaseAllInput()
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new(math.random(50, 200), math.random(50, 200)))
    end)
    local char = LP.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.WalkSpeed > 0 then
            hum:Move(Vector3.new(math.random() - 0.5, 0, math.random() - 0.5), false)
            task.delay(0.3, function() pcall(function() hum:Move(Vector3.zero, false) end) end)
        end
    end
end))

local JOB_KEYWORDS = {
    courier = {"courier","package","delivery","kurir","paket","ridego","driver","ojek"},
    barista = {"barista","coffee","cafe","kopi","coffeeshop","kasir"},
    office  = {"office","kantor","desk","worker","receptionist","resepsionis","admin","computer","komputer","meja"},
}

local NpcCache = { List = {}, LastScan = 0, ScanCooldown = 3.0 }
local lastNpcInvalidate = 0
track(Workspace.ChildAdded:Connect(function()
    if os.clock() - lastNpcInvalidate < 1.0 then return end
    lastNpcInvalidate = os.clock()
    NpcCache.LastScan = 0
end))

local function getSearchRoots()
    if Config.ScanAllMaps then return {Workspace} end
    local roots = {Workspace}
    local ok, children = pcall(function() return Workspace:GetChildren() end)
    if not ok or not children then return roots end
    for _, d in ipairs(children) do
        if d:IsA("Folder") or d:IsA("Model") then
            local n = d.Name:lower()
            if n:find("map") or n:find("surakarta") or n:find("gatsu") or n:find("world") or n:find("city") or n:find("npc") then
                table.insert(roots, d)
            end
        end
    end
    return roots
end

local function scanNpcs()
    local now = os.clock()
    if (now - NpcCache.LastScan) < NpcCache.ScanCooldown then return NpcCache.List end
    NpcCache.LastScan = now
    local found = {}
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp or not hrp.Parent then NpcCache.List = found; return found end
    local okO, origin = pcall(function() return hrp.Position end)
    if not okO or not origin then NpcCache.List = found; return found end
    local budget = IsMobileHardware and 3000 or math.huge
    local scanned = 0

    for _, root in ipairs(getSearchRoots()) do
        local ok, items = pcall(function()
            if Config.ScanAllMaps then return root:GetDescendants() else return root:GetChildren() end
        end)
        if ok and items then
            for _, obj in ipairs(items) do
                scanned = scanned + 1
                if scanned > budget then break end
                if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") then
                    local nameLower = obj.Name:lower()
                    local matchedJob = nil
                    for job, kws in pairs(JOB_KEYWORDS) do
                        for _, kw in ipairs(kws) do
                            if nameLower:find(kw) then matchedJob = job; break end
                        end
                        if matchedJob then break end
                    end
                    if matchedJob then
                        local npcHrp = obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart
                        if npcHrp then
                            local okP, npcPos = pcall(function() return npcHrp.Position end)
                            if okP and npcPos then
                                local dist = (npcPos - origin).Magnitude
                                if dist < Config.FarmRadius then
                                    table.insert(found, {npc = obj, hrp = npcHrp, job = matchedJob, dist = dist})
                                end
                            end
                        end
                    end
                end
            end
        end
        if scanned > budget then break end
    end
    table.sort(found, function(a, b) return a.dist < b.dist end)
    NpcCache.List = found
    return found
end

local PromptCache = { list = {}, lastScan = 0, cooldown = 3.0 }
local function getAllPrompts()
    if os.clock() - PromptCache.lastScan < PromptCache.cooldown then
        return PromptCache.list
    end
    PromptCache.lastScan = os.clock()
    local list = {}
    local budget = IsMobileHardware and 5000 or 30000
    local scanned = 0
    local queue = {Workspace}
    local qi = 1
    while qi <= #queue do
        if scanned > budget then break end
        local node = queue[qi]; qi = qi + 1
        scanned = scanned + 1
        if node:IsA("ProximityPrompt") and node.Parent and node.Parent:IsA("BasePart") then
            local okP, pos = pcall(function() return node.Parent.Position end)
            if okP and pos then
                table.insert(list, {prompt = node, pos = pos})
            end
        end
        local okC, kids = pcall(function() return node:GetChildren() end)
        if okC and kids then
            for _, k in ipairs(kids) do
                table.insert(queue, k)
            end
        end
    end
    PromptCache.list = list
    return list
end

local function findPromptNear(pos, radius)
    local best, bestD = nil, radius or 15
    for _, item in ipairs(getAllPrompts()) do
        if item.prompt.Enabled and item.prompt.Parent then
            local dist = (item.pos - pos).Magnitude
            if dist < bestD then bestD, best = dist, item.prompt end
        end
    end
    return best
end

local function firePrompt(prompt)
    if not prompt or not prompt.Parent then return false end
    return pcall(function()
        prompt:InputHoldBegin()
        task.wait(Config.PromptHold)
        prompt:InputHoldEnd()
    end)
end

local function teleportAndInteract(target)
    if not target or not target.npc.Parent or not target.hrp or not target.hrp.Parent then return false end
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    if Config.TeleportFarm and target.dist > 10 then
        local okP, tPos = pcall(function() return target.hrp.Position end)
        if okP and tPos then
            pcall(function() hrp.CFrame = CFrame.new(tPos + Config.TeleportOffset) end)
            task.wait(0.08)
        end
    end
    local prompt = State.PromptCache[target.npc]
    if not prompt or not prompt.Parent then
        prompt = target.npc:FindFirstChildWhichIsA("ProximityPrompt", true)
        if not prompt then
            local okP, tPos = pcall(function() return target.hrp.Position end)
            if okP and tPos then prompt = findPromptNear(tPos, 15) end
        end
        if prompt then State.PromptCache[target.npc] = prompt end
    end
    if prompt and firePrompt(prompt) then return true end
    local btn = findInteractButton()
    if btn then fireClick(btn, 0.1); return true end
    return false
end

local function farmTick()
    local jobsToScan = {}
    if Config.FarmQueueMode then
        jobsToScan = {"office", "barista", "courier"}
    else
        if Config.AutoCourier then table.insert(jobsToScan, "courier") end
        if Config.AutoBarista then table.insert(jobsToScan, "barista") end
        if Config.AutoOffice  then table.insert(jobsToScan, "office") end
    end
    if #jobsToScan == 0 then return end
    local npcs = scanNpcs()
    if #npcs == 0 then return end
    if Config.FarmQueueMode then
        local count = #jobsToScan
        for i = 0, count - 1 do
            local idx = ((State.FarmQueueIdx - 1 + i) % count) + 1
            local wantJob = jobsToScan[idx]
            for _, npc in ipairs(npcs) do
                if npc.job == wantJob then
                    State.FarmQueueIdx = (idx % count) + 1
                    teleportAndInteract(npc)
                    State.CurrentJob = wantJob
                    return
                end
            end
        end
    else
        for _, npc in ipairs(npcs) do
            if table.find(jobsToScan, npc.job) then
                teleportAndInteract(npc)
                State.CurrentJob = npc.job
                return
            end
        end
    end
end

task.spawn(function()
    while true do
        local shouldRun = Config.AutoCourier or Config.AutoBarista or Config.AutoOffice or Config.FarmQueueMode
        if shouldRun then
            local ok, _ = pcall(farmTick)
            if not ok then
                task.wait(math.max(2, Config.FarmInterval * 2))
            else
                task.wait(Config.FarmInterval)
            end
        else
            State.CurrentJob = nil
            task.wait(Config.FarmInterval)
        end
    end
end)

local SYMBOL_OPS = {
    ["×"] = "*", ["÷"] = "/",
    ["−"] = "-", ["–"] = "-", ["—"] = "-",
    ["％"] = "%", ["²"] = "^2", ["³"] = "^3", [","] = ".",
}
local WORD_OPS = {
    {pat = "%f[%a]multiplied by%f[%A]", rep = "*"},
    {pat = "%f[%a]multiply%f[%A]",     rep = "*"},
    {pat = "%f[%a]times%f[%A]",        rep = "*"},
    {pat = "%f[%a]added to%f[%A]",     rep = "+"},
    {pat = "%f[%a]plus%f[%A]",         rep = "+"},
    {pat = "%f[%a]subtracted by%f[%A]",rep = "-"},
    {pat = "%f[%a]subtract%f[%A]",     rep = "-"},
    {pat = "%f[%a]minus%f[%A]",        rep = "-"},
    {pat = "%f[%a]divided by%f[%A]",   rep = "/"},
    {pat = "%f[%a]divide by%f[%A]",    rep = "/"},
    {pat = "%f[%a]divide%f[%A]",       rep = "/"},
    {pat = "%f[%a]dikali%f[%A]",       rep = "*"},
    {pat = "%f[%a]kali%f[%A]",         rep = "*"},
    {pat = "%f[%a]ditambah%f[%A]",     rep = "+"},
    {pat = "%f[%a]tambah%f[%A]",       rep = "+"},
    {pat = "%f[%a]dikurang%f[%A]",     rep = "-"},
    {pat = "%f[%a]kurang%f[%A]",       rep = "-"},
    {pat = "%f[%a]dibagi%f[%A]",       rep = "/"},
    {pat = "%f[%a]bagi%f[%A]",         rep = "/"},
}
local function normalize(text)
    if not text or text == "" then return "" end
    local s = text:gsub("%s+", " "):lower()
    for f, t in pairs(SYMBOL_OPS) do s = s:gsub(f, t) end
    for _, w in ipairs(WORD_OPS) do s = s:gsub(w.pat, w.rep) end
    s = s:gsub("(%d)%s*[xX]%s*(%d)", "%1*%2")
    return s
end

local function looksLikeQuestion(txt)
    if not txt or txt == "" then return false end
    local low = txt:lower()
    if txt:find("%?") then return true end
    if low:find("_") then return true end
    if low:find("= %?") or low:find("=%?") then return true end
    for _, kw in ipairs({"what is","how much","calculate","solve","compute","evaluate",
                         "hasil","berapa","hitung","jumlah","tentukan"}) do
        if low:find(kw) then return true end
    end
    return false
end

local function extractExpression(text)
    local s = normalize(text)
    if not s or s == "" then return nil end
    local pat = "(-?%s*[%d%.%(][%s%d%.%+%-%*/%%%^%(%)]*[%d%)])"
    local matches = {}
    local init = 1
    while true do
        local startP, endP = s:find(pat, init)
        if not startP then break end
        local e = s:sub(startP, endP)
        if e:find("[%+%-%*/%%%^]") and (#(e:gsub("%D","")) >= 2) then
            table.insert(matches, {pos = startP, expr = e:gsub("%s+","")})
        end
        init = endP + 1
    end
    if #matches == 0 then return nil end
    local qpos = s:find("%?[^%?]*$")
    if qpos then
        local best = nil
        for _, m in ipairs(matches) do
            if m.pos < qpos and (not best or m.pos > best.pos) then best = m end
        end
        if best then return best.expr end
    end
    return matches[#matches].expr
end

local function evalMath(expr)
    if not expr or expr == "" then return nil end
    if not expr:find("%d") then return nil end
    local pos = 1
    local depth = 0
    local MAX_DEPTH = 50
    local function peek() return expr:sub(pos, pos) end
    local function consume() pos = pos + 1 end
    local function skipSpaces() while peek() == " " do consume() end end
    local parseExpression, parseTerm, parseFactor, parsePower

    parseFactor = function()
        depth = depth + 1
        if depth > MAX_DEPTH then depth = depth - 1; return nil end
        skipSpaces()
        local sign = 1
        while peek() == "-" or peek() == "+" do
            if peek() == "-" then sign = sign * -1 end
            consume(); skipSpaces()
        end
        local result
        if peek() == "(" then
            consume()
            result = parseExpression()
            if result == nil then depth = depth - 1; return nil end
            skipSpaces()
            if peek() == ")" then consume() end
        else
            local numStr = ""
            while peek():match("[%d%.]") do numStr = numStr .. peek(); consume() end
            result = tonumber(numStr)
            if result == nil then depth = depth - 1; return nil end
        end
        depth = depth - 1
        return result * sign
    end

    parsePower = function()
        local base = parseFactor()
        if base == nil then return nil end
        skipSpaces()
        if peek() == "^" then
            consume()
            local exp = parsePower()
            if exp == nil then return nil end
            return base ^ exp
        end
        return base
    end

    parseTerm = function()
        local result = parsePower()
        if result == nil then return nil end
        while true do
            skipSpaces()
            local op = peek()
            if op == "*" or op == "/" or op == "%" then
                consume()
                local nv = parsePower()
                if nv == nil then return nil end
                if op == "*" then result = result * nv
                elseif op == "/" then
                    if nv == 0 then return nil end
                    result = result / nv
                elseif op == "%" then
                    if nv == 0 then return nil end
                    result = result % nv
                end
            else break end
        end
        return result
    end

    parseExpression = function()
        local result = parseTerm()
        if result == nil then return nil end
        while true do
            skipSpaces()
            local op = peek()
            if op == "+" or op == "-" then
                consume()
                local nv = parseTerm()
                if nv == nil then return nil end
                if op == "+" then result = result + nv
                else result = result - nv end
            else break end
        end
        return result
    end

    local ok, r = pcall(parseExpression)
    if not ok or r == nil then return nil end
    if r ~= r or r == math.huge or r == -math.huge then return nil end
    return r
end

local function trimDecimal(s)
    s = s:gsub("0+$", "")
    s = s:gsub("%.$", "")
    return s
end
local function formatCandidates(n)
    if not n or n ~= n or n == math.huge or n == -math.huge then return {"0"} end
    local out, seen = {}, {}
    local function add(s)
        if s and s ~= "" and #s < 30 and not seen[s] then
            seen[s] = true; table.insert(out, s)
        end
    end
    local r = math.floor(n + 0.5)
    if math.abs(n - r) < 1e-6 then add(tostring(r)) end
    add(trimDecimal(string.format("%.6f", n)))
    add(trimDecimal(string.format("%.2f", n)))
    add(trimDecimal(string.format("%.1f", n)))
    if #out == 0 then add(tostring(n)) end
    return out
end

local lastScanTime = 0
local function scanForQuestion()
    local cacheTime = math.max(0.4, math.min(1.2, Config.MathInterval * 0.8))
    if os.clock() - lastScanTime < cacheTime then return {} end
    lastScanTime = os.clock()
    local out, seen = {}, {}
    local ok, list = pcall(function() return PlayerGui:GetDescendants() end)
    if not ok or not list then return out end
    for _, g in ipairs(list) do
        if isAncestorChainVisible(g)
           and (g:IsA("TextLabel") or g:IsA("TextButton") or g:IsA("TextBox")) then
            local txt = safeText(g)
            if txt ~= "" and not seen[txt] and looksLikeQuestion(txt) then
                seen[txt] = true
                local expr = extractExpression(txt)
                if expr then
                    local ans = evalMath(expr)
                    if ans and ans == ans then
                        table.insert(out, {text = txt, expr = expr, answer = ans})
                    end
                end
            end
        end
    end
    return out
end

local function clickAnswer(ansStr)
    if not ansStr or ansStr == "" then return nil end
    local tb = nil
    for _, g in ipairs(PlayerGui:GetDescendants()) do
        if g:IsA("TextBox") and g.TextEditable and isAncestorChainVisible(g) then tb = g; break end
    end
    if tb then
        local okFill = pcall(function()
            tb:CaptureFocus(); task.wait(0.05)
            tb.Text = ansStr; task.wait(0.05)
            tb:ReleaseFocus(false)
        end)
        if okFill then
            if Config.MathSubmit then
                task.wait(0.1)
                local submit = findSubmitButton()
                if submit then
                    pcall(function() fireClick(submit, 0.08) end)
                else
                    pcall(function()
                        VIM:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
                        task.wait(0.03)
                        VIM:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
                    end)
                end
            end
            return "textbox"
        end
    end

    local ansNorm = ansStr:gsub("%s+", ""):gsub("[^%d%.%-]", "")
    if ansNorm ~= "" then
        for _, g in ipairs(PlayerGui:GetDescendants()) do
            if g:IsA("TextButton") and isAncestorChainVisible(g) then
                local btn = safeText(g):gsub("%s+", ""):gsub("[^%d%.%-]", "")
                if btn ~= "" and btn == ansNorm then
                    pcall(function() fireClick(g, 0.1) end)
                    return "button"
                end
            end
        end
    end

    if ansNorm:match("^%-?%d+$") then
        local clickedAny = false
        for i = 1, #ansNorm do
            local ch = ansNorm:sub(i, i)
            local found = false
            for _, g in ipairs(PlayerGui:GetDescendants()) do
                if g:IsA("TextButton") and isAncestorChainVisible(g) then
                    if safeText(g):gsub("%s+", "") == ch then
                        pcall(function() fireClick(g, 0.08) end)
                        task.wait(0.06)
                        clickedAny = true; found = true; break
                    end
                end
            end
            if not found then return clickedAny and "digits_partial" or nil end
        end
        if clickedAny and Config.MathSubmit then
            local submit = findSubmitButton()
            if submit then pcall(function() fireClick(submit, 0.05) end) end
        end
        return clickedAny and "digits" or nil
    end
    return nil
end

local function mathTick()
    if not Config.MathSolver then return end
    if os.clock() - State.LastMath < Config.MathInterval then return end
    if State.MathBusy then return end
    State.LastMath = os.clock()

    local okScan, candidates = pcall(scanForQuestion)
    if not okScan or not candidates or #candidates == 0 then return end

    local now = os.clock()
    for q, v in pairs(State.MathSeen) do
        if (now - v.lastTry) > Config.MathCacheTTL then State.MathSeen[q] = nil end
    end

    local target = nil
    for _, c in ipairs(candidates) do
        local v = State.MathSeen[c.text]
        if not v then target = c; break end
        if v.attempts < Config.MathRetryLimit and (now - v.lastTry) > 1.5 then
            target = c; break
        end
    end
    if not target then return end

    State.MathBusy = true

    local entry = State.MathSeen[target.text]
    if not entry then
        entry = {attempts = 0, lastTry = 0, formatIdx = 0}
        State.MathSeen[target.text] = entry
    end

    local fmts = formatCandidates(target.answer)
    local fidx = math.clamp(entry.attempts + 1, 1, #fmts)
    local ansStr = fmts[fidx]

    local okFull = pcall(function()
        task.wait(0.2)
        local path = clickAnswer(ansStr)
        if path then
            entry.attempts = entry.attempts + 1
            entry.lastTry = now
            entry.formatIdx = math.min(fidx, #fmts - 1)
            State.MathOK = State.MathOK + 1
        else
            State.MathFail = State.MathFail + 1
            entry.lastTry = 0
        end
        task.wait(0.35)
    end)
    if not okFull then State.MathFail = State.MathFail + 1 end
    State.MathBusy = false
end

task.spawn(function()
    while true do
        pcall(mathTick)
        task.wait(math.max(0.1, math.min(0.5, Config.MathInterval * 0.5)))
    end
end)

local function upgradeTick()
    if not Config.AutoUpgrade then return end
    if os.clock() - State.LastUpgrade < Config.UpgradeCheck then return end
    State.LastUpgrade = os.clock()
    if State.UpgradeBusy then return end
    local prioMap = {}
    for i, p in ipairs(Config.UpgradePriority) do prioMap[p:lower()] = i end
    local candidates = {}
    for _, g in ipairs(PlayerGui:GetDescendants()) do
        if g:IsA("GuiButton") and isAncestorChainVisible(g) and g.Active then
            local n = (g.Name .. " " .. safeText(g)):lower()
            if n:find("buy") or n:find("upgrade") or n:find("beli") then
                for _, part in ipairs(Config.UpgradePriority) do
                    if n:find(part:lower()) then
                        table.insert(candidates, {btn = g, rank = prioMap[part:lower()]})
                        break
                    end
                end
            end
        end
    end
    if #candidates == 0 then
        local shopBtn = findShopButton()
        if shopBtn then pcall(function() fireClick(shopBtn, 0.1) end) end
        return
    end
    table.sort(candidates, function(a, b) return a.rank < b.rank end)
    State.UpgradeBusy = true
    pcall(function() fireClick(candidates[1].btn, 0.1) end)
    task.wait(0.3)
    State.UpgradeBusy = false
end

task.spawn(function()
    while task.wait(0.5) do pcall(upgradeTick) end
end)

local function redeemOne()
    if State.RedeemCycleDone then return end
    if State.RedeemIndex > #Config.RedeemCodes then
        State.RedeemCycleDone = true
        return
    end
    local code = Config.RedeemCodes[State.RedeemIndex]
    local shopBtn = findShopButton()
    if shopBtn then pcall(function() fireClick(shopBtn, 0.1) end); task.wait(0.3) end
    local input = findRedeemInput()
    if input and input:IsA("TextBox") then
        pcall(function()
            input:CaptureFocus(); task.wait(0.05)
            input.Text = code; task.wait(0.05)
            input:ReleaseFocus(false)
        end)
    end
    task.wait(0.2)
    local redeemBtn = findRedeemButton()
    if redeemBtn then pcall(function() fireClick(redeemBtn, 0.1) end) end
    task.wait(0.6)
    local inputAfter = findRedeemInput()
    if inputAfter and inputAfter:IsA("TextBox") and inputAfter.Text == "" then
        State.RedeemOK = State.RedeemOK + 1
    else
        State.RedeemFail = State.RedeemFail + 1
    end
    State.RedeemIndex = State.RedeemIndex + 1
end

watchdog("redeem", function()
    if not Config.AutoRedeem then return end
    if os.clock() - State.LastRedeem < Config.RedeemInterval then return end
    State.LastRedeem = os.clock()
    if State.RedeemBusy then return end
    State.RedeemBusy = true
    pcall(redeemOne)
    task.wait(0.3)
    State.RedeemBusy = false
end, 0.5)

local GuiHost = nil
do
    local ok = pcall(function()
        local test = Instance.new("ScreenGui")
        test.Name = "Cfg_T"
        test.Parent = CoreGui
        if test.Parent then GuiHost = CoreGui end
        test:Destroy()
    end)
    if not GuiHost then
        local ok2, pg = pcall(function() return LP:WaitForChild("PlayerGui", 3) end)
        if ok2 and pg then GuiHost = pg end
    end
    if not GuiHost then return end
end

local THEME = {
    bg = Color3.fromRGB(18, 20, 26), bgLight = Color3.fromRGB(28, 30, 38),
    bgRow = Color3.fromRGB(32, 34, 44),
    accent = Color3.fromRGB(0, 220, 160), accentDim = Color3.fromRGB(0, 140, 100),
    accentBeta = Color3.fromRGB(255, 160, 60), accentBetaDim = Color3.fromRGB(100, 60, 20),
    text = Color3.fromRGB(230, 232, 240), textDim = Color3.fromRGB(150, 155, 170),
    stroke = Color3.fromRGB(0, 200, 140), danger = Color3.fromRGB(180, 50, 60),
}
local TAB_META = {
    DRIVE    = {label = "DRIVE",  icon = "⚡"},
    VISUAL   = {label = "VISUAL", icon = "👁"},
    FARM     = {label = "FARM",   icon = "⛏"},
    TELEPORT = {label = "TP",     icon = "📍"},
    SHOP     = {label = "SHOP",   icon = "🛒"},
    BETA     = {label = "BETA",   icon = "⚠"},
}

local function makeCorner(p, r)
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 8); c.Parent = p; return c
end
local function makeStroke(p, col, th, tr)
    local s = Instance.new("UIStroke")
    s.Color = col or THEME.stroke; s.Thickness = th or 1; s.Transparency = tr or 0.5
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; s.Parent = p; return s
end
local function makeGradient(p, c1, c2)
    local g = Instance.new("UIGradient"); g.Color = ColorSequence.new(c1, c2); g.Rotation = 90; g.Parent = p; return g
end

local Teleport = { ScanCache = {}, LastScan = 0, Cooldown = 2.0, Busy = false }
local LandmarkCache = { t = 0, map = {} }

local KNOWN_LANDMARKS = {
    {name = "Spawn",             keys = {"spawn"}},
    {name = "Slamet Riyadi",     keys = {"slamet", "riyadi"}},
    {name = "Gatsu Street",      keys = {"gatsu"}},
    {name = "Surakarta City",    keys = {"surakarta"}},
    {name = "Sentul Circuit",    keys = {"sentul"}},
    {name = "Pettarani",         keys = {"pettarani"}},
    {name = "Mandalika",         keys = {"mandalika"}},
    {name = "Bandung Soreang",   keys = {"bandung", "soreang"}},
    {name = "Drag Race Zone",    keys = {"drag race", "dragrace", "drag strip"}},
    {name = "Coffee Shop",       keys = {"coffee", "cafe", "kopi", "barista"}},
    {name = "Police Station",    keys = {"police", "polsek", "kantor polisi"}},
    {name = "Office",            keys = {"office", "kantor", "desk"}},
    {name = "Courier",           keys = {"courier", "kurir", "delivery"}},
    {name = "RideGO",            keys = {"ridego", "ojek", "taxi"}},
    {name = "Yahamax",           keys = {"yahamax"}},
    {name = "Motorbike Dealer",  keys = {"motorbike", "dealer motor"}},
    {name = "Hando",             keys = {"hando"}},
    {name = "Piazzo",            keys = {"piazzo"}},
    {name = "Car Dealership",    keys = {"car dealer", "dealer mobil"}},
    {name = "Kawzaki",           keys = {"kawzaki"}},
    {name = "Truck Dealer",      keys = {"truck", "truk"}},
    {name = "Bus Dealer",        keys = {"bus", "adi putro"}},
    {name = "Vespero",           keys = {"vespero"}},
    {name = "Helmet Shop",       keys = {"helmet", "helm"}},
    {name = "Gas Station",       keys = {"gas station", "spbu", "pom bensin"}},
    {name = "Modification Shop", keys = {"modification", "modif", "bengkel"}},
}

local function tpGetHRP()
    local char = LP.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp or not hrp:IsA("BasePart") then return nil end
    return hrp
end

local function tpSafePos(part)
    if not part or not part.Parent then return nil end
    local ok, pos = pcall(function() return part.Position end)
    if ok and typeof(pos) == "Vector3" then return pos end
    return nil
end

local function tpFindRoot(model)
    if not model or not model.Parent then return nil end
    local hrp = model:FindFirstChild("HumanoidRootPart")
    if hrp and hrp:IsA("BasePart") then return hrp end
    if model.PrimaryPart then return model.PrimaryPart end
    local torso = model:FindFirstChild("Torso") or model:FindFirstChild("UpperTorso")
    if torso and torso:IsA("BasePart") then return torso end
    local count = 0
    local ok, desc = pcall(function() return model:GetDescendants() end)
    if not ok or not desc then return nil end
    for _, d in ipairs(desc) do
        count = count + 1
        if count > 200 then break end
        if d:IsA("BasePart") then return d end
    end
    return nil
end

local function tpTeleport(position, label)
    if not position then return false end
    local hrp = tpGetHRP()
    if not hrp then return false end
    local hum = hrp.Parent and hrp.Parent:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health <= 0 then return false end
    local off = Config.TeleportOffset or Vector3.new(0, 3, 0)
    local target = position + off
    if target.Y < -500 or target.Y > 100000 then return false end
    local ok = pcall(function() hrp.CFrame = CFrame.new(target) end)
    if ok then LogRing("tp -> " .. tostring(label or "?")) end
    return ok
end

local function tpMatchLandmark(modelName)
    if not modelName or modelName == "" then return nil end
    local low = normName(modelName)
    for _, lm in ipairs(KNOWN_LANDMARKS) do
        for _, k in ipairs(lm.keys) do
            if low:find(normName(k), 1, true) then return lm.name end
        end
    end
    return nil
end

local function tpFindLandmark(landmarkName)
    local now = os.clock()
    if now - LandmarkCache.t > 5.0 then
        LandmarkCache.map = {}
        LandmarkCache.t = now
    end
    local cached = LandmarkCache.map[landmarkName]
    if cached == false then return nil end
    if cached ~= nil then
        if cached.Parent then
            local p = tpSafePos(cached)
            if p then return p end
        end
        LandmarkCache.map[landmarkName] = nil
    end
    local hrp = tpGetHRP()
    local origin = hrp and tpSafePos(hrp) or Vector3.zero
    local bestPos, bestRoot, bestDist = nil, nil, math.huge
    local budget = IsMobileHardware and 4000 or 30000
    local scanned = 0
    local queue = {Workspace}
    local qi = 1
    while qi <= #queue do
        if scanned > budget then break end
        local node = queue[qi]; qi = qi + 1
        scanned = scanned + 1
        if node:IsA("Model") and tpMatchLandmark(node.Name) == landmarkName then
            local root = tpFindRoot(node)
            local pos = root and tpSafePos(root)
            if pos then
                local d = (pos - origin).Magnitude
                if d < bestDist then
                    bestDist = d; bestPos = pos; bestRoot = root
                end
            end
        end
        local okC, kids = pcall(function() return node:GetChildren() end)
        if okC and kids then
            for _, k in ipairs(kids) do
                if k:IsA("Model") or k:IsA("Folder") then
                    table.insert(queue, k)
                end
            end
        end
    end
    if bestRoot then
        LandmarkCache.map[landmarkName] = bestRoot
    else
        LandmarkCache.map[landmarkName] = false
    end
    return bestPos
end

local function tpDeepScan()
    local now = os.clock()
    if now - Teleport.LastScan < Teleport.Cooldown then return Teleport.ScanCache end
    Teleport.LastScan = now
    local hrp = tpGetHRP()
    local origin = hrp and tpSafePos(hrp) or Vector3.zero
    local results, seen = {}, {}
    local budget = IsMobileHardware and 5000 or 50000
    local scanned = 0
    local queue = {Workspace}
    local qi = 1

    local function consider(model)
        if not model or not model.Parent then return end
        if not model:IsA("Model") then return end
        if #model.Name < 2 then return end
        if model.Name:sub(1, 4) == "DDS_" then return end
        if Players:GetPlayerFromCharacter(model) then return end
        local okSeat = pcall(function()
            return model:FindFirstChildWhichIsA("VehicleSeat", true) ~= nil
        end)
        if okSeat then return end
        local root = tpFindRoot(model)
        local pos = root and tpSafePos(root)
        if not pos then return end
        local key = model.Name .. "@" .. tostring(math.floor(pos.X)) .. ":" .. tostring(math.floor(pos.Z))
        if seen[key] then return end
        seen[key] = true
        table.insert(results, {
            name = model.Name, model = model, pos = pos,
            dist = (pos - origin).Magnitude,
        })
    end

    while qi <= #queue do
        if scanned > budget then break end
        local node = queue[qi]; qi = qi + 1
        scanned = scanned + 1
        if node:IsA("Model") then
            consider(node)
        end
        local okC, kids = pcall(function() return node:GetChildren() end)
        if okC and kids then
            for _, k in ipairs(kids) do
                if k:IsA("Model") or k:IsA("Folder") then
                    table.insert(queue, k)
                end
            end
        end
    end

    table.sort(results, function(a, b) return a.dist < b.dist end)
    if #results > 300 then
        local trimmed = {}
        for i = 1, 300 do trimmed[i] = results[i] end
        results = trimmed
    end
    Teleport.ScanCache = results
    return results
end

local function buildTeleportPage(parent)
    local hdr = Instance.new("TextLabel")
    hdr.Size = UDim2.new(1, 0, 0, 20)
    hdr.BackgroundTransparency = 1
    hdr.Text = "QUICK TELEPORT"
    hdr.TextColor3 = THEME.accent
    hdr.Font = Enum.Font.GothamBold
    hdr.TextSize = 10
    hdr.TextXAlignment = Enum.TextXAlignment.Left
    hdr.LayoutOrder = 1
    hdr.Parent = parent

    local grid = Instance.new("Frame")
    grid.Size = UDim2.new(1, 0, 0, 0)
    grid.AutomaticSize = Enum.AutomaticSize.Y
    grid.BackgroundTransparency = 1
    grid.LayoutOrder = 2
    grid.Parent = parent
    local gl = Instance.new("UIGridLayout")
    gl.CellSize = UDim2.new(0.5, -3, 0, 26)
    gl.CellPadding = UDim2.new(0, 4, 0, 4)
    gl.SortOrder = Enum.SortOrder.LayoutOrder
    gl.Parent = grid

    for i, lm in ipairs(KNOWN_LANDMARKS) do
        local btn = Instance.new("TextButton")
        btn.Name = "T" .. i
        btn.BackgroundColor3 = THEME.bgRow
        btn.BackgroundTransparency = 0.2
        btn.BorderSizePixel = 0
        btn.Text = lm.name
        btn.TextColor3 = THEME.text
        btn.Font = Enum.Font.GothamMedium
        btn.TextSize = 9
        btn.LayoutOrder = i
        btn.AutoButtonColor = false
        btn.TextTruncate = Enum.TextTruncate.AtEnd
        btn.Parent = grid
        makeCorner(btn, 6)
        makeStroke(btn, THEME.bgLight, 1, 0.6)
        track(btn.MouseButton1Click:Connect(function()
            btn.TextColor3 = THEME.accentBeta
            local pos = tpFindLandmark(lm.name)
            if not pos then
                btn.TextColor3 = THEME.danger
                LogRing("tp miss: " .. lm.name, "W")
                task.delay(1.2, function()
                    if btn and btn.Parent then btn.TextColor3 = THEME.text end
                end)
                return
            end
            local ok = tpTeleport(pos, lm.name)
            btn.TextColor3 = ok and THEME.accent or THEME.danger
            task.delay(0.8, function()
                if btn and btn.Parent then btn.TextColor3 = THEME.text end
            end)
        end))
    end

    local sh = Instance.new("TextLabel")
    sh.Size = UDim2.new(1, 0, 0, 24)
    sh.BackgroundTransparency = 1
    sh.Text = "DEEP SCAN"
    sh.TextColor3 = THEME.accentBeta
    sh.Font = Enum.Font.GothamBold
    sh.TextSize = 10
    sh.TextXAlignment = Enum.TextXAlignment.Left
    sh.LayoutOrder = 3
    sh.Parent = parent

    local scanBtn = Instance.new("TextButton")
    scanBtn.Size = UDim2.new(1, 0, 0, 30)
    scanBtn.BackgroundColor3 = THEME.accentDim
    scanBtn.BackgroundTransparency = 0.2
    scanBtn.BorderSizePixel = 0
    scanBtn.Text = "SCAN MAP"
    scanBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    scanBtn.Font = Enum.Font.GothamBold
    scanBtn.TextSize = 11
    scanBtn.LayoutOrder = 4
    scanBtn.Parent = parent
    makeCorner(scanBtn, 8)
    makeStroke(scanBtn, THEME.accent, 1, 0.4)

    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, 0, 0, 18)
    status.BackgroundTransparency = 1
    status.Text = "Belum scan."
    status.TextColor3 = THEME.textDim
    status.Font = Enum.Font.Gotham
    status.TextSize = 9
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.LayoutOrder = 5
    status.Parent = parent

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, 0, 0, 200)
    scroll.BackgroundColor3 = THEME.bgLight
    scroll.BackgroundTransparency = 0.4
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 2
    scroll.ScrollBarImageColor3 = THEME.accent
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.ScrollingDirection = Enum.ScrollingDirection.Y
    scroll.LayoutOrder = 6
    scroll.Parent = parent
    makeCorner(scroll, 8)
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 4); pad.PaddingRight = UDim.new(0, 4)
    pad.PaddingTop = UDim.new(0, 4); pad.PaddingBottom = UDim.new(0, 4)
    pad.Parent = scroll
    local ll = Instance.new("UIListLayout")
    ll.Padding = UDim.new(0, 3)
    ll.SortOrder = Enum.SortOrder.LayoutOrder
    ll.Parent = scroll

    local function clearRows()
        for _, c in ipairs(scroll:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
    end

    track(scanBtn.MouseButton1Click:Connect(function()
        if Teleport.Busy then return end
        Teleport.Busy = true
        scanBtn.Text = "SCANNING..."
        status.Text = "Scanning..."
        clearRows()
        task.spawn(function()
            local ok, results = pcall(tpDeepScan)
            if not ok or not results then
                status.Text = "Scan error."
                scanBtn.Text = "SCAN MAP"
                Teleport.Busy = false
                return
            end
            status.Text = string.format("%d model", #results)
            for i = 1, math.min(#results, 100) do
                local r = results[i]
                local row = Instance.new("TextButton")
                row.Size = UDim2.new(1, 0, 0, 22)
                row.BackgroundColor3 = THEME.bgRow
                row.BackgroundTransparency = 0.15
                row.BorderSizePixel = 0
                row.Text = ""
                row.AutoButtonColor = false
                row.LayoutOrder = i
                row.Parent = scroll
                makeCorner(row, 4)
                local nm = Instance.new("TextLabel")
                nm.Size = UDim2.new(1, -66, 1, 0)
                nm.Position = UDim2.new(0, 6, 0, 0)
                nm.BackgroundTransparency = 1
                nm.Text = r.name
                nm.TextColor3 = THEME.text
                nm.Font = Enum.Font.Gotham
                nm.TextSize = 10
                nm.TextXAlignment = Enum.TextXAlignment.Left
                nm.TextTruncate = Enum.TextTruncate.AtEnd
                nm.Parent = row
                local dl = Instance.new("TextLabel")
                dl.Size = UDim2.new(0, 60, 1, 0)
                dl.Position = UDim2.new(1, -60, 0, 0)
                dl.BackgroundTransparency = 1
                dl.Text = string.format("%dm", math.floor(r.dist))
                dl.TextColor3 = THEME.accent
                dl.Font = Enum.Font.GothamBold
                dl.TextSize = 9
                dl.TextXAlignment = Enum.TextXAlignment.Right
                dl.Parent = row
                track(row.MouseButton1Click:Connect(function()
                    if not r.model or not r.model.Parent then
                        nm.TextColor3 = THEME.danger
                        return
                    end
                    local root = tpFindRoot(r.model)
                    local pos = root and tpSafePos(root)
                    if not pos then
                        nm.TextColor3 = THEME.danger
                        return
                    end
                    local okTp = tpTeleport(pos, r.name)
                    nm.TextColor3 = okTp and THEME.accent or THEME.danger
                    task.delay(0.8, function()
                        if nm and nm.Parent then nm.TextColor3 = THEME.text end
                    end)
                end))
            end
            scanBtn.Text = "SCAN MAP"
            Teleport.Busy = false
        end)
    end))
end

State.UI.ActiveSlider = nil
State.UI.ActiveSliderSetFn = nil
track(UserInput.InputChanged:Connect(function(input)
    if not State.UI.ActiveSlider then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        if State.UI.ActiveSliderSetFn then pcall(State.UI.ActiveSliderSetFn, input.Position.X) end
    end
end))
track(UserInput.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        State.UI.ActiveSlider = nil
        State.UI.ActiveSliderSetFn = nil
    end
end))

local function setToggleVisual(key, on)
    local t = State.UI.Toggles and State.UI.Toggles[key]
    if not t then return end
    TweenService:Create(t.track, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
        BackgroundColor3 = on and THEME.accentDim or Color3.fromRGB(60, 62, 72)
    }):Play()
    TweenService:Create(t.knob, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
        Position = on and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
    }):Play()
    if t.grad then
        t.grad.Color = on and ColorSequence.new(THEME.accentDim, THEME.accent)
                    or ColorSequence.new(Color3.fromRGB(50, 52, 62), Color3.fromRGB(70, 72, 84))
    end
end

local function createToggleSwitch(parent, key, label, order, callback, isBeta)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 40)
    row.BackgroundColor3 = THEME.bgRow; row.BackgroundTransparency = 0.15
    row.BorderSizePixel = 0; row.LayoutOrder = order; row.Parent = parent
    makeCorner(row, 10)
    makeStroke(row, isBeta and THEME.accentBetaDim or THEME.bgLight, 1, 0.7)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -70, 1, 0); lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1; lbl.TextColor3 = THEME.text
    lbl.Font = Enum.Font.GothamMedium; lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.TextTruncate = Enum.TextTruncate.AtEnd
    lbl.Text = (isBeta and "⚠ " or "") .. label; lbl.Parent = row
    local track2 = Instance.new("Frame")
    track2.Size = UDim2.new(0, 40, 0, 20); track2.Position = UDim2.new(1, -52, 0.5, -10)
    track2.BackgroundColor3 = Config[key] and THEME.accentDim or Color3.fromRGB(60, 62, 72)
    track2.BorderSizePixel = 0; track2.Parent = row
    makeCorner(track2, 10)
    local trackGrad = makeGradient(track2,
        Config[key] and THEME.accentDim or Color3.fromRGB(50, 52, 62),
        Config[key] and THEME.accent or Color3.fromRGB(70, 72, 84))
    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = Config[key] and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
    knob.BackgroundColor3 = Color3.fromRGB(220, 222, 230); knob.BorderSizePixel = 0; knob.Parent = track2
    makeCorner(knob, 8)
    State.UI.Toggles = State.UI.Toggles or {}
    State.UI.Toggles[key] = { track = track2, knob = knob, grad = trackGrad }
    local click = Instance.new("TextButton")
    click.Size = UDim2.new(1, 0, 1, 0); click.BackgroundTransparency = 1
    click.Text = ""; click.Parent = row
    track(click.MouseButton1Click:Connect(function()
        Config[key] = not Config[key]
        local on = Config[key]
        if key == "MathSolver" then
            State.MathSolverIntent = on
        end
        if key == "AutoRedeem" and on then
            State.RedeemIndex = 1
            State.RedeemCycleDone = false
        end
        setToggleVisual(key, on)
        if callback then callback(on) end
        requestSave()
    end))
    return row
end

local function createDragSlider(parent, key, label, min, max, step, order, suffix, callback)
    suffix = suffix or ""
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 56)
    row.BackgroundColor3 = THEME.bgRow; row.BackgroundTransparency = 0.15
    row.BorderSizePixel = 0; row.LayoutOrder = order; row.Parent = parent
    makeCorner(row, 10); makeStroke(row, THEME.bgLight, 1, 0.7)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -60, 0, 20); lbl.Position = UDim2.new(0, 12, 0, 6)
    lbl.BackgroundTransparency = 1; lbl.TextColor3 = THEME.textDim
    lbl.Font = Enum.Font.Gotham; lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Text = label; lbl.Parent = row
    local val = Instance.new("TextLabel")
    val.Size = UDim2.new(0, 60, 0, 20); val.Position = UDim2.new(1, -72, 0, 6)
    val.BackgroundTransparency = 1; val.TextColor3 = THEME.accent
    val.Font = Enum.Font.GothamBold; val.TextSize = 12
    val.TextXAlignment = Enum.TextXAlignment.Right
    val.Text = string.format("%.2f", Config[key]) .. suffix; val.Parent = row
    local trackBg = Instance.new("Frame")
    trackBg.Size = UDim2.new(1, -24, 0, 6); trackBg.Position = UDim2.new(0, 12, 0, 34)
    trackBg.BackgroundColor3 = Color3.fromRGB(50, 52, 62)
    trackBg.BorderSizePixel = 0; trackBg.Parent = row
    makeCorner(trackBg, 3)
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((Config[key] - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = THEME.accent; fill.BorderSizePixel = 0; fill.Parent = trackBg
    makeCorner(fill, 3); makeGradient(fill, THEME.accentDim, THEME.accent)
    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = UDim2.new((Config[key] - min) / (max - min), -7, 0.5, -7)
    knob.BackgroundColor3 = Color3.fromRGB(240, 242, 248); knob.BorderSizePixel = 0; knob.Parent = trackBg
    makeCorner(knob, 7); makeStroke(knob, THEME.accent, 2, 0)

    local function setFromX(absX)
        local trackAbsX = trackBg.AbsolutePosition.X
        local trackW = trackBg.AbsoluteSize.X
        if trackW <= 0 then return end
        local ratio = math.clamp((absX - trackAbsX) / trackW, 0, 1)
        local raw = min + ratio * (max - min)
        local snapped = math.floor(raw / step + 0.5) * step
        Config[key] = math.clamp(snapped, min, max)
        local r = (Config[key] - min) / (max - min)
        fill.Size = UDim2.new(r, 0, 1, 0)
        knob.Position = UDim2.new(r, -7, 0.5, -7)
        val.Text = string.format("%.2f", Config[key]) .. suffix
        if callback then callback(Config[key]) end
        requestSave()
    end
    local click = Instance.new("TextButton")
    click.Size = UDim2.new(1, 0, 0, 40); click.Position = UDim2.new(0, 0, 0, 16)
    click.BackgroundTransparency = 1; click.Text = ""; click.Parent = row
    track(click.MouseButton1Down:Connect(function(x)
        State.UI.ActiveSlider = click
        State.UI.ActiveSliderSetFn = setFromX
        pcall(setFromX, x)
    end))
    return row
end

local function buildUI()
    local sg = Instance.new("ScreenGui")
    sg.Name = "UserPreferences"
    sg.ResetOnSpawn = false; sg.IgnoreGuiInset = true
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.DisplayOrder = 100; sg.Enabled = true

    local marker = Instance.new("StringValue")
    marker.Name = "_Signature"
    marker.Value = "sys_cfg"
    marker.Parent = sg

    local okParent = pcall(function() sg.Parent = GuiHost end)
    if not okParent or not sg.Parent then
        local fb = LP:FindFirstChild("PlayerGui")
        if fb then pcall(function() sg.Parent = fb end) end
    end
    if not sg.Parent then return end
    task.wait(0.1)
    State.UI.Gui = sg
    State.UI.Fab = nil
    _G.DDS_Gui = sg

    local fab = Instance.new("TextButton")
    fab.Name = "Cfg"; fab.Size = UDim2.new(0, 56, 0, 56)
    fab.Position = UDim2.new(0, 20, 0, 100)
    fab.BackgroundColor3 = THEME.accentDim; fab.BorderSizePixel = 0
    fab.Text = "⚙"; fab.TextColor3 = Color3.fromRGB(255, 255, 255)
    fab.Font = Enum.Font.GothamBold; fab.TextSize = 22; fab.ZIndex = 10
    fab.Visible = false; fab.Parent = sg
    makeCorner(fab, 28); makeStroke(fab, THEME.accent, 2, 0.3)
    makeGradient(fab, THEME.accentDim, THEME.accent)
    State.UI.Fab = fab

    local main = Instance.new("Frame")
    main.Name = "Cfg_MainPanel"
    main.AnchorPoint = Vector2.new(0, 0.5); main.Position = UDim2.new(0, 15, 0.5, 0)
    main.BackgroundColor3 = THEME.bg; main.BackgroundTransparency = 0.05
    main.BorderSizePixel = 0; main.Active = true; main.Draggable = true
    main.ZIndex = 1; main.Visible = true; main.Parent = sg
    makeCorner(main, 14); makeStroke(main, THEME.stroke, 1.5, 0.4)
    makeGradient(main, Color3.fromRGB(22, 24, 32), Color3.fromRGB(14, 16, 22))
    State.UI.MainPanel = main

    local shadow = Instance.new("Frame")
    shadow.Name = "Cfg_Shadow"; shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    shadow.BackgroundTransparency = 0.6; shadow.BorderSizePixel = 0
    shadow.ZIndex = 0; shadow.Visible = true; shadow.Parent = sg
    shadow.AnchorPoint = Vector2.new(0, 0.5); makeCorner(shadow, 16)
    State.UI.Shadow = shadow

    local function syncShadow()
        shadow.Size = UDim2.new(main.Size.X.Scale, main.Size.X.Offset + 8,
                                main.Size.Y.Scale, main.Size.Y.Offset + 8)
        shadow.Position = UDim2.new(main.Position.X.Scale, main.Position.X.Offset - 4,
                                    main.Position.Y.Scale, main.Position.Y.Offset)
    end
    track(main:GetPropertyChangedSignal("Size"):Connect(syncShadow))
    track(main:GetPropertyChangedSignal("Position"):Connect(syncShadow))
    syncShadow()

    local accentBar = Instance.new("Frame")
    accentBar.Size = UDim2.new(0, 3, 1, -20); accentBar.Position = UDim2.new(0, 0, 0, 10)
    accentBar.BackgroundColor3 = THEME.accent; accentBar.BorderSizePixel = 0
    accentBar.ZIndex = 2; accentBar.Parent = main
    makeCorner(accentBar, 2); makeGradient(accentBar, THEME.accent, THEME.accentDim)

    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, -8, 0, 40); header.Position = UDim2.new(0, 6, 0, 0)
    header.BackgroundTransparency = 1; header.ZIndex = 3; header.Parent = main

    local titleDot = Instance.new("Frame")
    titleDot.Size = UDim2.new(0, 8, 0, 8); titleDot.Position = UDim2.new(0, 14, 0.5, -4)
    titleDot.BackgroundColor3 = THEME.accent; titleDot.BorderSizePixel = 0; titleDot.Parent = header
    makeCorner(titleDot, 4)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -100, 1, 0); title.Position = UDim2.new(0, 28, 0, 0)
    title.BackgroundTransparency = 1; title.TextColor3 = THEME.text
    title.Font = Enum.Font.GothamBold; title.TextSize = 13
    title.TextXAlignment = Enum.TextXAlignment.Left; title.Text = "Preferences"
    title.Parent = header

    local badge = Instance.new("TextLabel")
    badge.Size = UDim2.new(0, 62, 0, 18); badge.Position = UDim2.new(1, -100, 0.5, -9)
    badge.BackgroundColor3 = THEME.accentDim; badge.BackgroundTransparency = 0.4
    badge.BorderSizePixel = 0; badge.TextColor3 = THEME.accent
    badge.Font = Enum.Font.GothamBold; badge.TextSize = 9
    badge.Text = resolveInputMode()
    badge.Parent = header
    makeCorner(badge, 4)
    State.UI.Badge = badge

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 26, 0, 26); closeBtn.Position = UDim2.new(1, -32, 0.5, -13)
    closeBtn.BackgroundColor3 = THEME.danger; closeBtn.BackgroundTransparency = 0.2
    closeBtn.BorderSizePixel = 0; closeBtn.Text = "×"; closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.Font = Enum.Font.GothamBold; closeBtn.TextSize = 16; closeBtn.Parent = header
    makeCorner(closeBtn, 6)
    track(closeBtn.MouseButton1Click:Connect(function()
        main.Visible = false
        shadow.Visible = false
        fab.Visible = true
    end))

    local contentArea = Instance.new("Frame")
    contentArea.Size = UDim2.new(1, -12, 1, -100); contentArea.Position = UDim2.new(0, 6, 0, 42)
    contentArea.BackgroundTransparency = 1; contentArea.ZIndex = 2
    contentArea.ClipsDescendants = true; contentArea.Parent = main

    local pages = {}
    local tabNames = {"DRIVE", "VISUAL", "FARM", "TELEPORT", "SHOP", "BETA"}

    local function selectTab(name)
        for n, pg in pairs(pages) do pg.Visible = (n == name) end
        local bar = State.UI.TabBar
        if bar then
            for _, c in ipairs(bar:GetChildren()) do
                if c:IsA("TextButton") and c:GetAttribute("IsTab") then
                    local active = (c.Name == name)
                    local beta = (c.Name == "BETA")
                    c.BackgroundColor3 = active and (beta and THEME.accentBetaDim or THEME.accentDim) or THEME.bgLight
                    c.BackgroundTransparency = active and 0.1 or 0.4
                    local lbl = c:FindFirstChild("TabLabel")
                    if lbl then lbl.TextColor3 = active and (beta and THEME.accentBeta or THEME.accent) or THEME.textDim end
                end
            end
        end
    end
    State.UI.SelectTab = selectTab

    local function makePage(name)
        local sf = Instance.new("ScrollingFrame")
        sf.Name = name; sf.Size = UDim2.new(1, 0, 1, 0)
        sf.BackgroundTransparency = 1; sf.BorderSizePixel = 0
        sf.ScrollBarThickness = 2; sf.ScrollBarImageColor3 = THEME.accent
        sf.ScrollBarImageTransparency = 0.6
        sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
        sf.CanvasSize = UDim2.new(0, 0, 0, 0)
        sf.ScrollingDirection = Enum.ScrollingDirection.Y
        sf.Visible = false; sf.ZIndex = 2; sf.Parent = contentArea
        local pad = Instance.new("UIPadding")
        pad.PaddingLeft = UDim.new(0, 10); pad.PaddingRight = UDim.new(0, 10)
        pad.PaddingTop = UDim.new(0, 4); pad.PaddingBottom = UDim.new(0, 4); pad.Parent = sf
        local ll = Instance.new("UIListLayout")
        ll.Padding = UDim.new(0, 5)
        ll.SortOrder = Enum.SortOrder.LayoutOrder; ll.Parent = sf
        pages[name] = sf; return sf
    end
    for _, name in ipairs(tabNames) do makePage(name) end

    local tabBar = Instance.new("Frame")
    tabBar.Name = "TabBar"; tabBar.Size = UDim2.new(1, -16, 0, 42)
    tabBar.Position = UDim2.new(0, 8, 1, -48)
    tabBar.BackgroundColor3 = THEME.bgLight; tabBar.BackgroundTransparency = 0.2
    tabBar.BorderSizePixel = 0; tabBar.ZIndex = 5; tabBar.Parent = main
    State.UI.TabBar = tabBar
    makeCorner(tabBar, 12); makeStroke(tabBar, THEME.bgLight, 1, 0.5)
    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    tabLayout.Padding = UDim.new(0, 3); tabLayout.Parent = tabBar

    for _, name in ipairs(tabNames) do
        local meta = TAB_META[name]
        local tb = Instance.new("TextButton")
        tb.Name = name; tb.Size = UDim2.new(0, 46, 0, 36)
        tb.BackgroundColor3 = THEME.bgLight; tb.BackgroundTransparency = 0.4
        tb.BorderSizePixel = 0; tb.Text = ""; tb.AutoButtonColor = false; tb.Parent = tabBar
        tb:SetAttribute("IsTab", true); makeCorner(tb, 8)
        local icon = Instance.new("TextLabel")
        icon.Size = UDim2.new(1, 0, 0, 16); icon.Position = UDim2.new(0, 0, 0, 3)
        icon.BackgroundTransparency = 1; icon.Text = meta.icon
        icon.TextColor3 = THEME.text; icon.Font = Enum.Font.GothamBold
        icon.TextSize = 12; icon.Parent = tb
        local lbl = Instance.new("TextLabel")
        lbl.Name = "TabLabel"; lbl.Size = UDim2.new(1, 0, 0, 12)
        lbl.Position = UDim2.new(0, 0, 0, 20)
        lbl.BackgroundTransparency = 1; lbl.Text = meta.label
        lbl.TextColor3 = THEME.textDim; lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 7; lbl.Parent = tb
        track(tb.MouseButton1Click:Connect(function() selectTab(name) end))
    end

    local layoutConn = { c = nil }
    local function applyLayout()
        local cam = Workspace.CurrentCamera
        if not cam then return end
        local vp = cam.ViewportSize
        local targetH = math.min(460, vp.Y - 40)
        main.Size = UDim2.new(0, 320, 0, targetH)
        contentArea.Size = UDim2.new(1, -12, 1, -100)
        syncShadow()
    end
    local function bindLayout()
        if layoutConn.c then
            pcall(function() layoutConn.c:Disconnect() end)
            layoutConn.c = nil
        end
        local cam = Workspace.CurrentCamera
        if cam then
            layoutConn.c = cam:GetPropertyChangedSignal("ViewportSize"):Connect(applyLayout)
            track(layoutConn.c)
        end
    end
    applyLayout()
    bindLayout()
    track(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        bindLayout()
        applyLayout()
    end))

    local pDrive = pages["DRIVE"]
    createToggleSwitch(pDrive, "PerfectStart", "Perfect Start", 1)
    createToggleSwitch(pDrive, "ManualClutchMode", "Manual Clutch (M)", 2)
    createToggleSwitch(pDrive, "UseGear1", "Gear 1 Start", 3)
    createToggleSwitch(pDrive, "UseWheelieHold", "Wheelie Hold (T)", 4, nil, true)
    createToggleSwitch(pDrive, "AutoShift", "Auto Shift (E)", 5)
    createToggleSwitch(pDrive, "SpeedEnabled", "Speed Changer (Target)", 6)
    createToggleSwitch(pDrive, "NoDrag", "No Drag", 7)
    createDragSlider(pDrive, "CarTargetKmh", "Mobil Target", 40, 320, 5, 8, " km/h")
    createDragSlider(pDrive, "BikeTargetKmh", "Motor Target", 40, 320, 5, 9, " km/h")
    createDragSlider(pDrive, "MaxTargetKmh", "Max Cap", 100, 500, 10, 10, " km/h")
    createDragSlider(pDrive, "AccelRate", "Akselerasi", 0.05, 0.30, 0.01, 11, "")
    createDragSlider(pDrive, "DecelRate", "Deselerasi", 0.05, 0.50, 0.01, 12, "")
    createDragSlider(pDrive, "HysteresisKmh", "Hysteresis", 0, 10, 0.5, 13, " km/h")

    local resetBtn = Instance.new("TextButton")
    resetBtn.Size = UDim2.new(1, 0, 0, 32); resetBtn.LayoutOrder = 98
    resetBtn.BackgroundColor3 = THEME.danger; resetBtn.BackgroundTransparency = 0.35
    resetBtn.BorderSizePixel = 0; resetBtn.Text = "RESET CONFIG"
    resetBtn.TextColor3 = Color3.fromRGB(255, 235, 235)
    resetBtn.Font = Enum.Font.GothamBold; resetBtn.TextSize = 11; resetBtn.Parent = pDrive
    makeCorner(resetBtn, 8); makeStroke(resetBtn, THEME.danger, 1, 0.4)
    track(resetBtn.MouseButton1Click:Connect(function()
        for k, v in pairs(ConfigDefaults) do
            if k ~= "UpgradePriority" and k ~= "RedeemCodes" and k ~= "HotkeyToggle" then Config[k] = v end
        end
        State.MathSolverIntent = nil
        State.RedeemIndex = 1
        State.RedeemCycleDone = false
        for k, _ in pairs(State.UI.Toggles or {}) do
            if Config[k] ~= nil then setToggleVisual(k, Config[k] and true or false) end
        end
        releaseAllInput()
        applyFullbright(false); applyNoFog(false)
        if Workspace.CurrentCamera then Workspace.CurrentCamera.FieldOfView = Config.FOV end
        if State.CameraLockedByUs and Workspace.CurrentCamera then
            Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
            State.CameraLockedByUs = false
        end
        clearESP(); teardownLinearVelocity()
        State.CachedInputMode = nil
        State.ManualClutchOn = false
        Teleport.LastScan = 0; Teleport.ScanCache = {}
        LandmarkCache.t = 0; LandmarkCache.map = {}
        task.spawn(saveConfig)
    end))

    local info = Instance.new("TextLabel")
    info.Size = UDim2.new(1, 0, 0, 40)
    info.BackgroundColor3 = THEME.bgLight; info.BackgroundTransparency = 0.3
    info.BorderSizePixel = 0; info.TextColor3 = THEME.accentBeta
    info.Font = Enum.Font.Gotham; info.TextSize = 10; info.TextWrapped = true
    info.LayoutOrder = 99; info.Text = " Kategori: -"
    info.TextXAlignment = Enum.TextXAlignment.Left; info.Parent = pDrive
    makeCorner(info, 8); makeStroke(info, THEME.accentBetaDim, 1, 0.7)
    State.UI.InfoLabel = info

    local pVis = pages["VISUAL"]
    createToggleSwitch(pVis, "ESP", "ESP Players", 1, function(v) refreshESPAll() end)
    createToggleSwitch(pVis, "ESPNames", "ESP Names", 2, function(v) refreshESPAll() end)
    createToggleSwitch(pVis, "ESPHealth", "ESP Health Bar", 3, function(v) refreshESPAll() end)
    createToggleSwitch(pVis, "ESPDistance", "ESP Distance", 4, function(v) refreshESPAll() end)
    createToggleSwitch(pVis, "Fullbright", "Fullbright", 5, function(v) applyFullbright(v) end)
    createToggleSwitch(pVis, "NoFog", "No Fog", 6, function(v) applyNoFog(v) end)
    createDragSlider(pVis, "FOV", "FOV", 40, 120, 5, 7, "", function(v) applyFOV(v) end)
    createToggleSwitch(pVis, "CameraLock", "Camera Lock", 8)

    local pFarm = pages["FARM"]
    createToggleSwitch(pFarm, "AutoOffice", "Auto Office (+Math)", 1, function(v)
        if v then Config.AutoBarista = false; Config.AutoCourier = false; Config.FarmQueueMode = false end
    end)
    createToggleSwitch(pFarm, "AutoBarista", "Auto Barista", 2, function(v)
        if v then Config.AutoOffice = false; Config.AutoCourier = false; Config.FarmQueueMode = false end
    end)
    createToggleSwitch(pFarm, "AutoCourier", "Auto Courier", 3, function(v)
        if v then Config.AutoOffice = false; Config.AutoBarista = false; Config.FarmQueueMode = false end
    end)
    createToggleSwitch(pFarm, "FarmQueueMode", "Farm Queue", 4, function(v)
        if v then Config.AutoOffice = false; Config.AutoBarista = false; Config.AutoCourier = false end
    end)
    createToggleSwitch(pFarm, "OfficeMathLinked", "Office → Math Link", 5)
    createToggleSwitch(pFarm, "TeleportFarm", "Teleport", 6)
    createToggleSwitch(pFarm, "ScanAllMaps", "Scan All Maps", 7)
    createDragSlider(pFarm, "FarmRadius", "Scan Radius", 20, 300, 10, 8, " st")
    createDragSlider(pFarm, "FarmInterval", "Interval", 0.2, 2.0, 0.1, 9, "s")
    createToggleSwitch(pFarm, "AntiAFK", "Anti AFK", 10)

    local farmStatus = Instance.new("TextLabel")
    farmStatus.Size = UDim2.new(1, 0, 0, 30)
    farmStatus.BackgroundColor3 = THEME.bgLight; farmStatus.BackgroundTransparency = 0.3
    farmStatus.BorderSizePixel = 0; farmStatus.TextColor3 = THEME.accent
    farmStatus.Font = Enum.Font.Gotham; farmStatus.TextSize = 10
    farmStatus.TextXAlignment = Enum.TextXAlignment.Left
    farmStatus.Text = " Job: idle | NPC: -"
    farmStatus.LayoutOrder = 11; farmStatus.Parent = pFarm
    makeCorner(farmStatus, 8)
    State.UI.FarmStatus = farmStatus

    buildTeleportPage(pages["TELEPORT"])

    local pShop = pages["SHOP"]
    createToggleSwitch(pShop, "AutoUpgrade", "Auto Upgrade", 1)
    createDragSlider(pShop, "UpgradeCheck", "Upgrade Check", 1.0, 10.0, 0.5, 2, "s")
    createToggleSwitch(pShop, "AutoRedeem", "Auto Redeem Code", 3)
    createDragSlider(pShop, "RedeemInterval", "Redeem Interval", 2.0, 15.0, 0.5, 4, "s")

    local pBeta = pages["BETA"]
    local notice = Instance.new("TextLabel")
    notice.Size = UDim2.new(1, 0, 0, 46)
    notice.BackgroundColor3 = THEME.accentBetaDim; notice.BackgroundTransparency = 0.3
    notice.BorderSizePixel = 0; notice.TextColor3 = THEME.accentBeta
    notice.Font = Enum.Font.GothamMedium; notice.TextSize = 10
    notice.TextWrapped = true; notice.LayoutOrder = 0
    notice.Text = " ⚠ BETA — MathSolver auto-aktif kalau Office / Farm Queue nyala."
    notice.TextXAlignment = Enum.TextXAlignment.Left; notice.Parent = pBeta
    makeCorner(notice, 8); makeStroke(notice, THEME.accentBeta, 1, 0.6)

    createToggleSwitch(pBeta, "MathSolver", "Auto Solve Math", 1, nil, true)
    createToggleSwitch(pBeta, "MathSubmit", "Auto Submit Answer", 2, nil, true)
    createDragSlider(pBeta, "MathInterval", "Solve Interval", 0.5, 5.0, 0.1, 3, "s")
    createDragSlider(pBeta, "MathRetryLimit", "Retry Limit", 1, 10, 1, 4, "x")

    local mathStats = Instance.new("TextLabel")
    mathStats.Size = UDim2.new(1, 0, 0, 30)
    mathStats.BackgroundColor3 = THEME.bgLight; mathStats.BackgroundTransparency = 0.3
    mathStats.BorderSizePixel = 0; mathStats.TextColor3 = THEME.accent
    mathStats.Font = Enum.Font.Gotham; mathStats.TextSize = 10
    mathStats.TextXAlignment = Enum.TextXAlignment.Left
    mathStats.Text = " OK:0 | Fail:0 | Queue:0"
    mathStats.LayoutOrder = 5; mathStats.Parent = pBeta
    makeCorner(mathStats, 8)
    State.UI.MathStats = mathStats

    selectTab("FARM")
    main.Visible = true
    shadow.Visible = true
    fab.Visible = false
    track(fab.MouseButton1Click:Connect(function()
        main.Visible = true
        shadow.Visible = true
        fab.Visible = false
    end))
end

buildUI()

if UserInput.KeyboardEnabled then
    track(UserInput.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == Config.HotkeyToggle then
            local mp = State.UI.MainPanel
            local sh = State.UI.Shadow
            local fb = State.UI.Fab
            if mp then
                local newState = not mp.Visible
                mp.Visible = newState
                if sh then sh.Visible = newState end
                if fb then fb.Visible = not newState end
            end
        end
    end))
end

do
    local hudSg = Instance.new("ScreenGui")
    hudSg.Name = "UserPrefs_HUD"; hudSg.ResetOnSpawn = false
    hudSg.IgnoreGuiInset = true; hudSg.DisplayOrder = 99

    local marker = Instance.new("StringValue")
    marker.Name = "_Signature"
    marker.Value = "sys_hud"
    marker.Parent = hudSg

    pcall(function() hudSg.Parent = CoreGui end)
    if not hudSg.Parent then pcall(function() hudSg.Parent = PlayerGui end) end
    State.UI.HudGui = hudSg
    _G.DDS_Hud = hudSg

    local hud = Instance.new("Frame")
    local hudW = IsMobileHardware and 140 or 160
    hud.Size = UDim2.new(0, hudW, 0, 60)
    hud.Position = UDim2.new(1, -(hudW + 10), 0, 10)
    hud.BackgroundColor3 = THEME.bg; hud.BackgroundTransparency = 0.15
    hud.BorderSizePixel = 0; hud.Parent = hudSg
    makeCorner(hud, 8); makeStroke(hud, THEME.accentDim, 1, 0.5)

    local hudText = Instance.new("TextLabel")
    hudText.Size = UDim2.new(1, -16, 1, -12)
    hudText.Position = UDim2.new(0, 8, 0, 6)
    hudText.BackgroundTransparency = 1
    hudText.TextColor3 = THEME.text
    hudText.Font = Enum.Font.Code; hudText.TextSize = 10
    hudText.TextXAlignment = Enum.TextXAlignment.Left
    hudText.TextYAlignment = Enum.TextYAlignment.Top
    hudText.Text = ""; hudText.Parent = hud
    State.UI.HudText = hudText

    task.spawn(function()
        local frameAcc, frameCount = 0, 0
        track(RunService.RenderStepped:Connect(function(dt)
            frameAcc = frameAcc + dt; frameCount = frameCount + 1
            if frameAcc >= 1.0 then
                State.FPS = frameCount / frameAcc
                frameAcc = 0; frameCount = 0
            end
        end))
        while task.wait(1.0) do
            local okp, p = pcall(function()
                return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
            end)
            State.Ping = okp and p or 0
            if State.UI.HudText then
                State.UI.HudText.Text = string.format(
                    "FPS  %d\nPING %d ms\nMODE %s",
                    math.floor(State.FPS), math.floor(State.Ping),
                    resolveInputMode())
            end
        end
    end)
end

local function syncOfficeMath()
    if not Config.OfficeMathLinked then return end
    local officeActive = Config.AutoOffice or Config.FarmQueueMode
    if officeActive then
        if State.MathSolverIntent == false then
            if Config.MathSolver then
                Config.MathSolver = false
                setToggleVisual("MathSolver", false)
            end
        else
            if not Config.MathSolver then
                Config.MathSolver = true
                setToggleVisual("MathSolver", true)
            end
        end
    else
        if State.MathSolverIntent == true then
            if not Config.MathSolver then
                Config.MathSolver = true
                setToggleVisual("MathSolver", true)
            end
        else
            if Config.MathSolver then
                Config.MathSolver = false
                setToggleVisual("MathSolver", false)
            end
        end
    end
end
task.spawn(function() while task.wait(1.0) do pcall(syncOfficeMath) end end)

task.spawn(function()
    while task.wait(0.5) do
        pcall(function()
            local now = os.clock()
            for q, v in pairs(State.MathSeen) do
                if (now - v.lastTry) > Config.MathCacheTTL then State.MathSeen[q] = nil end
            end
            if State.UI.MathStats then
                local queueCount = 0
                for _, v in pairs(State.MathSeen) do
                    if v.attempts < Config.MathRetryLimit then queueCount = queueCount + 1 end
                end
                State.UI.MathStats.Text = string.format(
                    " OK:%d | Fail:%d | Queue:%d — %s",
                    State.MathOK, State.MathFail, queueCount,
                    Config.MathSolver and "running" or "idle")
            end
            if State.UI.InfoLabel then
                if State.Ready then
                    local target = State.IsBike and Config.BikeTargetKmh or Config.CarTargetKmh
                    State.UI.InfoLabel.Text = string.format(
                        " %s · %.0f/%.0f km/h · Gear:%d · %s",
                        State.IsBike and "MOTOR" or "MOBIL",
                        State.SpeedCurrentKmh or 0, target,
                        #State.GearValues, State.LaunchPhase)
                else
                    State.UI.InfoLabel.Text = " Kategori: - (belum duduk)"
                end
            end
            if State.UI.FarmStatus then
                State.UI.FarmStatus.Text = string.format(" Job: %s | NPC: %d | Redeem OK:%d/F:%d%s",
                    State.CurrentJob or "idle", #NpcCache.List, State.RedeemOK, State.RedeemFail,
                    State.RedeemCycleDone and " [done]" or "")
            end
            if State.UI.Badge then
                State.UI.Badge.Text = resolveInputMode()
            end
        end)
    end
end)

track(LP.CharacterAdded:Connect(function()
    releaseAllInput()
    clearESP()
    refreshESPAll()
    teardownLinearVelocity()
    State.LaunchPhase = "idle"
    State.ManualClutchOn = false
    Teleport.LastScan = 0
    Teleport.ScanCache = {}
    LandmarkCache.t = 0
    LandmarkCache.map = {}
end))

if Config.SaveConfigOnChange then task.spawn(saveConfig) end
