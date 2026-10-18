-- Drag Drive Simulator — All-in-One Mobile v1.4
-- Target game: Beta V1.1.9 (Wheelie Style x Big Update)
-- Executor: Delta / Fluxus / Hydrogen / Codex / Arceus X
-- Changelog v1.4 (dari v1.3):
--   [+] Tab BETA — Math Solver (Office Worker), Gear Ratio Probe, Wheelie Probe
--   [+] Math Solver terintegrasi — parser + evaluator, toggle, counter OK/Fail
--   [~] Fitur beta diberi label [BETA] di UI dan dipisah dari tab produksi
--   [~] Gear/Wheelie probe dipindah dari DRIVE ke BETA

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInput         = game:GetService("UserInputService")
local Lighting          = game:GetService("Lighting")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser       = game:GetService("VirtualUser")
local VIM               = game:GetService("VirtualInputManager")

local LP        = Players.LocalPlayer
local Camera    = Workspace.CurrentCamera
local PlayerGui = LP:WaitForChild("PlayerGui")

-- ============================================================
-- CONFIG
-- ============================================================
local Config = {
    -- Perfect Start
    PerfectStart     = false,
    LaunchRPM        = 0.62,
    LaunchRampTime   = 0.45,
    LaunchDelay      = 0.05,
    UseClutch        = true,
    UseGear1         = true,
    UseWheelieHold   = false,

    -- Speed
    SpeedEnabled     = false,
    CarMultiplier    = 1.30,
    BikeMultiplier   = 1.55,
    MaxRatio         = 1.85,
    ApplyBias        = 0.85,

    -- AutoShift
    AutoShift        = false,
    ShiftPoint       = 0.92,

    -- Visual
    ESP              = false,
    ESPColor         = Color3.fromRGB(0, 255, 180),
    Fullbright       = false,
    NoFog            = false,
    FOV              = 80,
    NoDrag           = false,
    CameraLock       = false,
    AutoWin          = false,
    AntiAFK          = true,

    -- Farm
    AutoCourier      = false,
    AutoBarista      = false,
    AutoOffice       = false,
    FarmQueueMode    = false,
    FarmRadius       = 60,
    FarmInterval     = 0.6,
    TeleportFarm     = true,
    TeleportOffset   = Vector3.new(0, 3, 0),
    ScanAllMaps      = true,

    -- Upgrade
    AutoUpgrade      = false,
    UpgradeCheck     = 3.0,
    UpgradePriority  = {"Engine", "Turbo", "Weight", "Grip", "Transmission"},

    -- Redeem
    AutoRedeem       = false,
    RedeemCodes      = {
        "DDSWHEELIESTYLEUPDATE",
        "NEWGATSUMAPNEWMODIFICATION",
        "WHEELIESTYLEBIGUPDATE",
        "HBDADVGAMERSTEAM26",
        "DELAYDIKITLAGIFREESTYLE",
        "DRAGDRIVESIMULATORSEPTEMBER26",
    },
    RedeemInterval   = 5.0,

    -- BETA features
    MathSolver       = false,   -- [BETA] Office Worker auto-solve
    MathInterval     = 1.2,
    MathSubmit       = true,
    GearProbe        = false,   -- [BETA] read-only scan
    WheelieProbe     = false,   -- [BETA] read-only scan
}

-- ============================================================
-- STATE
-- ============================================================
local State = {
    Vehicle = nil, VehicleRoot = nil, IsBike = false, VehicleName = "",
    RpmValue = nil, RpmMax = 8000, Ready = false,
    GearValues = {}, WheelieValues = {},
    Connections = {}, ESPObjects = {},
    UI = {},
    LastFarm = 0, LastUpgrade = 0, LastRedeem = 0, LastMath = 0,
    UpgradeBusy = false, RedeemIndex = 1, RedeemBusy = false, MathBusy = false,
    MathLastQ = "", MathOK = 0, MathFail = 0,
    FarmQueue = {"office", "barista", "courier"}, FarmQueueIdx = 1,
}
local function track(c) table.insert(State.Connections, c) return c end

-- ============================================================
-- VEHICLE
-- ============================================================
local BIKE_HINTS = {
    "bike","motor","moto","r1","r6","cbr","ninja","gsxr","ducati","harley",
    "scooter","vixion","beat","nmax","pcx","aerox","vario","satria","sonic",
}
local CAR_HINTS  = {
    "car","mobil","sedan","coupe","truck","supra","skyline","gt","ferrari",
    "lambo","civic","jazz","avanza","gatsu","wheelie","wide","rim","limited",
}

local function classifyVehicle(model)
    if not model then return false, "" end
    local name = model.Name:lower()
    for _, h in ipairs(BIKE_HINTS) do if name:find(h) then return true, model.Name end end
    for _, h in ipairs(CAR_HINTS) do if name:find(h) then return false, model.Name end end
    local count = 0
    for _, d in ipairs(model:GetDescendants()) do if d:IsA("BasePart") then count += 1 end end
    return count < 40, model.Name
end

local function cacheVehicleParts(model)
    State.RpmValue = nil
    State.RpmMax = 8000
    State.VehicleRoot = nil
    State.GearValues = {}
    State.WheelieValues = {}
    if not model then return end
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("NumberValue") then
            local n = d.Name:lower()
            if n:find("rpm") and not State.RpmValue then State.RpmValue = d end
            if n:find("gear") or n:find("ratio") then
                table.insert(State.GearValues, {name = d.Name, value = d.Value})
            end
            if n:find("wheelie") then
                table.insert(State.WheelieValues, {name = d.Name, value = d.Value})
            end
        end
    end
    local mx = model:FindFirstChild("MaxRPM") or model:FindFirstChild("Redline")
    if mx and mx:IsA("NumberValue") then State.RpmMax = mx.Value end
    local drive = model:FindFirstChild("DriveSeat")
    if drive and drive:IsA("BasePart") then
        State.VehicleRoot = drive
    elseif model.PrimaryPart then
        State.VehicleRoot = model.PrimaryPart
    end
end

local function findVehicle()
    local char = LP.Character
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return nil end
    local seat = hum.SeatPart
    if seat and seat:IsA("VehicleSeat") then return seat.Parent end
    return nil
end

task.spawn(function()
    while task.wait(0.4) do
        local v = findVehicle()
        if v ~= State.Vehicle then
            State.Vehicle = v
            State.IsBike, State.VehicleName = classifyVehicle(v)
            cacheVehicleParts(v)
            State.Ready = (v ~= nil and State.VehicleRoot ~= nil)
        end
    end
end)

local function getRPM()
    if State.RpmValue then return State.RpmValue.Value, State.RpmMax end
    local root = State.VehicleRoot
    if root then return root.AssemblyAngularVelocity.Magnitude * 60 / (2 * math.pi), State.RpmMax end
    return 0, 0
end

-- ============================================================
-- GUI MATCHER
-- ============================================================
local function matchesKeyword(name, kw)
    local lower = name:lower()
    if lower == kw then return true end
    if lower:sub(1, #kw + 1) == kw .. " " then return true end
    if lower:sub(-(#kw + 1)) == " " .. kw then return true end
    if lower:find("^" .. kw .. "$") then return true end
    if lower:find("%f[%w]" .. kw .. "%f[%W]") then return true end
    return false
end

local function findGuiByKeywords(keywords)
    for _, g in ipairs(PlayerGui:GetDescendants()) do
        if g:IsA("GuiButton") and g.Visible then
            for _, k in ipairs(keywords) do
                if matchesKeyword(g.Name, k) or (g:IsA("TextButton") and matchesKeyword(g.Text, k)) then
                    return g
                end
            end
        end
    end
end

local function findGasButton()      return findGuiByKeywords({"gas","throttle","accelerate","pedal"}) end
local function findGearButton()     return findGuiByKeywords({"shift","gear","naik"}) end
local function findGear1Button()    return findGuiByKeywords({"gear 1","gigi 1","first","1"}) end
local function findClutchButton()   return findGuiByKeywords({"clutch","kopling"}) end
local function findWheelieButton()  return findGuiByKeywords({"wheelie","angkat","stunt","trick"}) end
local function findInteractButton() return findGuiByKeywords({"interact","talk","work","mulai","start","ambil","deliver","serve","serve customer","take order"}) end
local function findRedeemInput()    return findGuiByKeywords({"redeem input","code input","kode"}) end
local function findRedeemButton()   return findGuiByKeywords({"redeem","tukar","klaim"}) end
local function findShopButton()     return findGuiByKeywords({"shop","store","toko","upgrade","garage"}) end
local function findSubmitButton()
    return findGuiByKeywords({"submit","kirim","answer","jawab","confirm","ok"})
end

local function tapButton(btn, hold)
    if not btn then return false end
    local pos = btn.AbsolutePosition + btn.AbsoluteSize * 0.5
    local ok = pcall(function()
        VIM:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 0)
        task.wait(hold or 0.02)
        VIM:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 0)
    end)
    if not ok then pcall(function() btn:Activated() end) end
    return ok
end

-- ============================================================
-- PERFECT START
-- ============================================================
local function isExactVisible(label)
    for _, g in ipairs(PlayerGui:GetDescendants()) do
        if g.Visible then
            if g:IsA("TextLabel") then
                local t = g.Text:gsub("%s+", "")
                if t == label then return true end
            elseif g:IsA("ImageLabel") and g.Name:lower():find(label:lower()) then
                return true
            end
        end
    end
    return false
end

local function isGreenVisible()
    for _, g in ipairs(PlayerGui:GetDescendants()) do
        if g.Visible and g:IsA("TextLabel") then
            local t = g.Text:lower():gsub("%s+", "")
            if t == "go" or t == "go!" or t == "start" or t == "mulai" then return true end
        end
    end
    return false
end

local launchPhase, launchStart = "idle", 0

track(RunService.Heartbeat:Connect(function()
    if not Config.PerfectStart or not State.Ready then launchPhase = "idle" return end
    local rpm, max = getRPM()
    local ratio = max > 0 and rpm / max or 0
    local gas = findGasButton()

    if launchPhase == "idle" and isExactVisible("3") then
        launchPhase = "prep"; launchStart = os.clock()
        if Config.UseGear1 then
            local g1 = findGear1Button()
            if g1 then tapButton(g1, 0.05) end
        end
        if Config.UseClutch then
            local cl = findClutchButton()
            if cl then tapButton(cl, 0.1) end
        end
        if Config.UseWheelieHold then
            local wh = findWheelieButton()
            if wh then tapButton(wh, 0.1) end
        end
    end
    if launchPhase == "prep" then
        local elapsed = os.clock() - launchStart
        if ratio < Config.LaunchRPM - 0.03 then tapButton(gas, 0.03) end
        if elapsed >= Config.LaunchRampTime then launchPhase = "hold"; launchStart = os.clock() end
        return
    end
    if launchPhase == "hold" then
        if ratio < Config.LaunchRPM - 0.04 then tapButton(gas, 0.03) end
        if isGreenVisible() then launchPhase = "launch"; launchStart = os.clock()
        elseif os.clock() - launchStart > 2.5 then launchPhase = "idle" end
        return
    end
    if launchPhase == "launch" then
        if os.clock() - launchStart >= Config.LaunchDelay then
            tapButton(gas, 0.25); launchPhase = "idle"
        end
    end
end))

-- ============================================================
-- AUTOSHIFT / SPEED / NODRAG
-- ============================================================
track(RunService.Heartbeat:Connect(function()
    if not Config.AutoShift or not State.Ready then return end
    local rpm, max = getRPM()
    if max <= 0 then return end
    if rpm / max >= Config.ShiftPoint then tapButton(findGearButton(), 0.03) end
end))

track(RunService.Stepped:Connect(function()
    if not Config.SpeedEnabled or not State.Ready then return end
    local root = State.VehicleRoot
    if not root or not root.Parent then return end
    local base = State.IsBike and Config.BikeMultiplier or Config.CarMultiplier
    base = math.min(base, Config.MaxRatio)
    local vel = root.AssemblyLinearVelocity
    if vel.Magnitude < 2 then return end
    local target = vel.Magnitude * base
    local newMag = vel.Magnitude + (target - vel.Magnitude) * Config.ApplyBias
    root.AssemblyLinearVelocity = vel.Unit * newMag
end))

track(RunService.Stepped:Connect(function()
    if not Config.NoDrag then return end
    local root = State.VehicleRoot
    if root and root.Parent then
        root.CustomPhysicalProperties = PhysicalProperties.new(0.01, 0, 0)
    end
end))

-- ============================================================
-- ESP / LIGHTING / CAMERA
-- ============================================================
local function clearESP()
    for _, o in pairs(State.ESPObjects) do if o and o.Parent then o:Destroy() end end
    table.clear(State.ESPObjects)
end
local function addESP(plr)
    if plr == LP then return end
    local char = plr.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local box = Instance.new("BoxHandleAdornment")
    box.Name = "DDS_ESP_" .. plr.Name; box.Adornee = hrp
    box.AlwaysOnTop = true; box.ZIndex = 5
    box.Size = hrp.Size + Vector3.new(0.4, 0.4, 0.4)
    box.Color3 = Config.ESPColor; box.Transparency = 0.35
    box.Parent = hrp; State.ESPObjects[plr] = box
end
track(RunService.RenderStepped:Connect(function()
    if not Config.ESP then return end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and not State.ESPObjects[p] then addESP(p) end
    end
end))
track(Players.PlayerRemoving:Connect(function(p)
    local box = State.ESPObjects[p]
    if box and box.Parent then box:Destroy() end
    State.ESPObjects[p] = nil
end))

track(RunService.RenderStepped:Connect(function()
    if Config.Fullbright then
        Lighting.Ambient = Color3.fromRGB(180,180,180)
        Lighting.OutdoorAmbient = Color3.fromRGB(180,180,180)
        Lighting.Brightness = 3; Lighting.ClockTime = 14
    end
    if Config.NoFog then Lighting.FogEnd = 1e9; Lighting.FogStart = 1e9 end
    Camera.FieldOfView = Config.FOV
end))

local function nearestDragNpc()
    local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local best, bestD = nil, math.huge
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChild("Humanoid") and obj.Name:lower():find("drag") then
            local hrp = obj:FindFirstChild("HumanoidRootPart")
            if hrp then
                local d = (hrp.Position - root.Position).Magnitude
                if d < bestD then bestD, best = d, hrp end
            end
        end
    end
    return best
end
track(RunService.RenderStepped:Connect(function()
    if not Config.CameraLock then return end
    local t = nearestDragNpc()
    if t then Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, t.Position) end
end))

track(RunService.Heartbeat:Connect(function()
    if not Config.AutoWin then return end
    for _, ev in ipairs(ReplicatedStorage:GetDescendants()) do
        if ev:IsA("RemoteEvent") then
            local n = ev.Name:lower()
            if n:find("finish") or n:find("win") or n:find("reward") then
                pcall(function() ev:FireServer() end)
            end
        end
    end
end))

track(LP.Idled:Connect(function()
    if not Config.AntiAFK then return end
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end))

-- ============================================================
-- AUTOFARM
-- ============================================================
local JOB_KEYWORDS = {
    courier = {"courier","package","delivery","kurir","paket"},
    barista = {"barista","coffee","cafe","kopi","coffeeshop"},
    office  = {"office","kantor","desk","receptionist","resepsionis","admin","computer","komputer"},
}

local function getSearchRoots()
    if not Config.ScanAllMaps then return {Workspace} end
    local roots = {Workspace}
    for _, d in ipairs(Workspace:GetChildren()) do
        if d:IsA("Folder") or d:IsA("Model") then
            local n = d.Name:lower()
            if n:find("map") or n:find("surakarta") or n:find("gatsu") or n:find("world") then
                table.insert(roots, d)
            end
        end
    end
    return roots
end

local function findFarmTarget(job)
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local keywords = JOB_KEYWORDS[job]
    if not keywords then return nil end
    local best, bestD = nil, Config.FarmRadius
    for _, root in ipairs(getSearchRoots()) do
        for _, obj in ipairs(root:GetDescendants()) do
            if obj:IsA("Model") then
                local n = obj.Name:lower()
                local matched = false
                for _, kw in ipairs(keywords) do if n:find(kw) then matched = true break end end
                if matched then
                    local hrpNpc = obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart
                    if hrpNpc then
                        local d = (hrpNpc.Position - hrp.Position).Magnitude
                        if d < bestD then bestD, best = d, hrpNpc end
                    end
                end
            end
        end
    end
    return best
end

local function teleportNear(target)
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp or not target then return false end
    hrp.CFrame = CFrame.new(target.Position + Config.TeleportOffset)
    return true
end

local function farmOne(job)
    local target = findFarmTarget(job)
    if not target then return false end
    if Config.TeleportFarm then teleportNear(target) end
    task.wait(0.08)
    local btn = findInteractButton()
    if btn then
        tapButton(btn, 0.1)
    else
        local char = LP.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp and (target.Position - hrp.Position).Magnitude < 10 then
            local pp = target.Parent and target.Parent:FindFirstChildWhichIsA("ProximityPrompt", true)
            if pp then pcall(function() fireproximityprompt(pp) end) end
        end
    end
    return true
end

track(RunService.Heartbeat:Connect(function()
    if os.clock() - State.LastFarm < Config.FarmInterval then return end
    local anyJob = Config.AutoCourier or Config.AutoBarista or Config.AutoOffice or Config.FarmQueueMode
    if not anyJob then return end

    if Config.FarmQueueMode then
        local job = State.FarmQueue[State.FarmQueueIdx]
        if farmOne(job) then
            State.LastFarm = os.clock()
            State.FarmQueueIdx = State.FarmQueueIdx + 1
            if State.FarmQueueIdx > #State.FarmQueue then State.FarmQueueIdx = 1 end
        end
    else
        local job = nil
        if Config.AutoCourier then job = "courier"
        elseif Config.AutoBarista then job = "barista"
        elseif Config.AutoOffice then job = "office" end
        if job and farmOne(job) then State.LastFarm = os.clock() end
    end
end))

-- ============================================================
-- AUTOUPGRADE / AUTO REDEEM
-- ============================================================
track(RunService.Heartbeat:Connect(function()
    if not Config.AutoUpgrade then return end
    if os.clock() - State.LastUpgrade < Config.UpgradeCheck then return end
    State.LastUpgrade = os.clock()
    if State.UpgradeBusy then return end
    local prioMap = {}
    for i, p in ipairs(Config.UpgradePriority) do prioMap[p:lower()] = i end
    local candidates = {}
    for _, g in ipairs(PlayerGui:GetDescendants()) do
        if g:IsA("GuiButton") and g.Visible and g.Active then
            local n = (g.Name .. " " .. (g:IsA("TextButton") and g.Text or "")):lower()
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
    if #candidates == 0 then return end
    table.sort(candidates, function(a, b) return a.rank < b.rank end)
    State.UpgradeBusy = true
    pcall(function() tapButton(candidates[1].btn, 0.1) end)
    task.wait(0.3)
    State.UpgradeBusy = false
end))

local function redeemOne()
    if State.RedeemIndex > #Config.RedeemCodes then State.RedeemIndex = 1 return end
    local shopBtn = findShopButton()
    if shopBtn then tapButton(shopBtn, 0.1) end
    task.wait(0.3)
    local input = findRedeemInput()
    if input and input:IsA("TextBox") then
        input.Text = Config.RedeemCodes[State.RedeemIndex]
        input:CaptureFocus()
        task.wait(0.1)
        input:ReleaseFocus(true)
    end
    task.wait(0.2)
    local redeemBtn = findRedeemButton()
    if redeemBtn then tapButton(redeemBtn, 0.1) end
    State.RedeemIndex = State.RedeemIndex + 1
end

track(RunService.Heartbeat:Connect(function()
    if not Config.AutoRedeem then return end
    if os.clock() - State.LastRedeem < Config.RedeemInterval then return end
    State.LastRedeem = os.clock()
    if State.RedeemBusy then return end
    State.RedeemBusy = true
    pcall(redeemOne)
    task.wait(0.3)
    State.RedeemBusy = false
end))

-- ============================================================
-- BETA: MATH SOLVER
-- ============================================================
local OP_MAP = {
    ["×"] = "*", ["x"] = "*", ["X"] = "*",
    ["÷"] = "/", ["−"] = "-", ["–"] = "-", ["—"] = "-",
    ["％"] = "%", ["²"] = "^2", ["³"] = "^3",
}

local function normalize(text)
    if not text or text == "" then return "" end
    local s = text:gsub("%s+", " ")
    for from, to in pairs(OP_MAP) do s = s:gsub(from, to) end
    return s
end

local function extractExpression(text)
    local s = normalize(text)
    if s == "" then return nil end
    local withEq = s:match("([%d%.]+[%s]?[%+%-%*/%%%^][%s]?[%d%.]+[%s%+%-%*/%%%^%d%.]*)[%s]*=[%s]*[%?]?")
    if withEq then
        local c = withEq:gsub("[^%d%+%-%*/%%%^%.]", "")
        if c:find("%d") then return c end
    end
    local berapa = s:match("[Bb]erapa%s+([%d%.]+[%s%+%-%*/%%%^]+[%d%.]+)")
    if berapa then
        local c = berapa:gsub("[^%d%+%-%*/%%%^%.]", "")
        if #c > 0 then return c end
    end
    local plain = s:match("([%d%.]+[%s%+%-%*/%%%^]+[%d%.]+)")
    if plain then
        local c = plain:gsub("[^%d%+%-%*/%%%^%.]", "")
        if #c > 0 then return c end
    end
    local paren = s:match("%(([%d%.]+[%s%+%-%*/%%%^]+[%d%.]+)%)")
    if paren then
        local c = paren:gsub("[^%d%+%-%*/%%%^%.]", "")
        if #c > 0 then return c end
    end
    return nil
end

local function evalExpression(expr)
    if not expr or expr == "" then return nil end
    local tokens, i = {}, 1
    while i <= #expr do
        local c = expr:sub(i, i)
        if c:match("%d") or c == "." then
            local num = expr:match("^[%d%.]+", i)
            table.insert(tokens, tonumber(num)); i = i + #num
        elseif c:match("[%+%-%*/%%%^]") then
            table.insert(tokens, c); i = i + 1
        elseif c == " " then i = i + 1
        else return nil end
    end
    if #tokens < 3 then return nil end
    local prec = { ["+"]=1, ["-"]=1, ["*"]=2, ["/"]=2, ["%"]=2, ["^"]=3 }
    local rightAssoc = { ["^"] = true }
    local output, ops = {}, {}
    for _, t in ipairs(tokens) do
        if type(t) == "number" then table.insert(output, t)
        elseif prec[t] then
            while #ops > 0 do
                local top = ops[#ops]
                if prec[top] and (prec[top] > prec[t] or (prec[top] == prec[t] and not rightAssoc[t])) then
                    table.insert(output, table.remove(ops))
                else break end
            end
            table.insert(ops, t)
        end
    end
    while #ops > 0 do table.insert(output, table.remove(ops)) end
    local stack = {}
    for _, tok in ipairs(output) do
        if type(tok) == "number" then table.insert(stack, tok)
        else
            if #stack < 2 then return nil end
            local b = table.remove(stack)
            local a = table.remove(stack)
            local r
            if tok == "+" then r = a + b
            elseif tok == "-" then r = a - b
            elseif tok == "*" then r = a * b
            elseif tok == "/" then if b == 0 then return nil end r = a / b
            elseif tok == "%" then if b == 0 then return nil end r = a % b
            elseif tok == "^" then r = a ^ b end
            if not r then return nil end
            table.insert(stack, r)
        end
    end
    if #stack ~= 1 then return nil end
    return stack[1]
end

local function formatResult(n)
    if math.abs(n - math.floor(n + 0.5)) < 0.001 then return tostring(math.floor(n + 0.5)) end
    return string.format("%.2f", n)
end

local function scanForQuestion()
    local out = {}
    for _, g in ipairs(PlayerGui:GetDescendants()) do
        if g:IsA("TextLabel") and g.Visible and g.Text and g.Text ~= "" then
            local text = g.Text
            if text:find("%d") and (text:find("[%+%-%*/]") or text:lower():find("berapa") or text:lower():find("what")) then
                local expr = extractExpression(text)
                if expr then
                    local ans = evalExpression(expr)
                    if ans then table.insert(out, {text=text, expr=expr, answer=ans}) end
                end
            end
        end
    end
    return out
end

local function findAnswerInput()
    for _, g in ipairs(PlayerGui:GetDescendants()) do
        if g:IsA("TextBox") and g.Visible and g.TextEditable and g:IsFocused() then return g end
    end
    for _, g in ipairs(PlayerGui:GetDescendants()) do
        if g:IsA("TextBox") and g.Visible and g.TextEditable then return g end
    end
    return nil
end

local function fillTextBox(tb, text)
    if not tb then return false end
    return pcall(function()
        tb:CaptureFocus(); task.wait(0.05)
        tb.Text = text; task.wait(0.05)
        tb:ReleaseFocus(true)
    end)
end

local function mathTick()
    if not Config.MathSolver then return end
    if os.clock() - State.LastMath < Config.MathInterval then return end
    State.LastMath = os.clock()
    if State.MathBusy then return end

    local candidates = scanForQuestion()
    if #candidates == 0 then return end
    local target = nil
    for _, c in ipairs(candidates) do
        if c.text ~= State.MathLastQ then target = c break end
    end
    if not target then return end

    State.MathBusy = true
    State.MathLastQ = target.text
    local ansStr = formatResult(target.answer)

    local input = findAnswerInput()
    if not input then
        State.MathFail = State.MathFail + 1
        State.MathBusy = false
        return
    end
    fillTextBox(input, ansStr)
    task.wait(0.1)
    if Config.MathSubmit then
        local submit = findSubmitButton()
        if submit then tapButton(submit, 0.05)
        else
            VIM:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
            task.wait(0.03)
            VIM:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
        end
    end
    State.MathOK = State.MathOK + 1
    task.wait(0.3)
    State.MathBusy = false
end
track(RunService.Heartbeat:Connect(mathTick))

-- ============================================================
-- BETA: PROBE (read-only)
-- ============================================================
task.spawn(function()
    while task.wait(2.0) do
        if Config.GearProbe and State.Ready and #State.GearValues > 0 then
            local msg = "[BETA Gear] "
            for _, g in ipairs(State.GearValues) do msg = msg .. g.name .. "=" .. tostring(g.value) .. " " end
            warn(msg)
        end
        if Config.WheelieProbe and State.Ready then
            local msg = "[BETA Wheelie] "
            for _, w in ipairs(State.WheelieValues) do msg = msg .. w.name .. "=" .. tostring(w.value) .. " " end
            if #State.WheelieValues == 0 then msg = msg .. "none" end
            warn(msg)
        end
    end
end)

-- ============================================================
-- UI — 5 tab, BETA dipisah
-- ============================================================
local function createToggle(parent, key, label, order, callback, isBeta)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, 34)
    b.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
    b.BorderSizePixel = 0
    b.TextColor3 = Color3.fromRGB(220, 220, 220)
    b.Font = Enum.Font.Gotham
    b.TextSize = 13
    b.Text = "  " .. (isBeta and "[BETA] " or "") .. label
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.LayoutOrder = order
    b.Parent = parent
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = b
    local indicator = Instance.new("Frame")
    indicator.Size = UDim2.new(0, 6, 0, 20)
    indicator.Position = UDim2.new(1, -14, 0.5, -10)
    indicator.BackgroundColor3 = Color3.fromRGB(80, 80, 90)
    indicator.BorderSizePixel = 0
    indicator.Parent = b
    local ic = Instance.new("UICorner"); ic.CornerRadius = UDim.new(0, 3); ic.Parent = indicator
    track(b.MouseButton1Click:Connect(function()
        Config[key] = not Config[key]
        indicator.BackgroundColor3 = Config[key] and Color3.fromRGB(0, 220, 140) or Color3.fromRGB(80, 80, 90)
        if callback then callback(Config[key]) end
    end))
    return b
end

local function createSlider(parent, key, label, min, max, step, order, suffix)
    suffix = suffix or ""
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, 0, 0, 52)
    holder.BackgroundTransparency = 1
    holder.LayoutOrder = order
    holder.Parent = parent
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 20)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.fromRGB(180, 180, 190)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = label .. ": " .. string.format("%.2f", Config[key]) .. suffix
    lbl.Parent = holder
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 26)
    row.Position = UDim2.new(0, 0, 0, 22)
    row.BackgroundTransparency = 1
    row.Parent = holder
    local minus = Instance.new("TextButton")
    minus.Size = UDim2.new(0, 40, 1, 0); minus.BackgroundColor3 = Color3.fromRGB(50,50,58)
    minus.BorderSizePixel = 0; minus.Text = "−"; minus.TextColor3 = Color3.fromRGB(255,255,255)
    minus.Font = Enum.Font.GothamBold; minus.TextSize = 18; minus.Parent = row
    local mc = Instance.new("UICorner"); mc.CornerRadius = UDim.new(0, 8); mc.Parent = minus
    local plus = minus:Clone(); plus.Position = UDim2.new(1, -40, 0, 0); plus.Text = "+"; plus.Parent = row
    local pc = Instance.new("UICorner"); pc.CornerRadius = UDim.new(0, 8); pc.Parent = plus
    local val = Instance.new("TextLabel")
    val.Size = UDim2.new(1, -90, 1, 0); val.Position = UDim2.new(0, 45, 0, 0)
    val.BackgroundColor3 = Color3.fromRGB(24, 24, 30); val.BorderSizePixel = 0
    val.Text = string.format("%.2f", Config[key]); val.TextColor3 = Color3.fromRGB(0, 220, 160)
    val.Font = Enum.Font.GothamBold; val.TextSize = 14; val.Parent = row
    local vc = Instance.new("UICorner"); vc.CornerRadius = UDim.new(0, 8); vc.Parent = val
    local function refresh()
        Config[key] = math.clamp(math.floor(Config[key]/step + 0.5) * step, min, max)
        val.Text = string.format("%.2f", Config[key])
        lbl.Text = label .. ": " .. string.format("%.2f", Config[key]) .. suffix
    end
    track(minus.MouseButton1Click:Connect(function() Config[key] = Config[key] - step; refresh() end))
    track(plus.MouseButton1Click:Connect(function() Config[key] = Config[key] + step; refresh() end))
end

local function buildUI()
    local sg = Instance.new("ScreenGui")
    sg.Name = "DDS_v14"; sg.ResetOnSpawn = false; sg.IgnoreGuiInset = true
    sg.Parent = PlayerGui; State.UI.Gui = sg

    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, 300, 0, 460)
    main.Position = UDim2.new(0, 12, 0.5, -230)
    main.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
    main.BackgroundTransparency = 0.05
    main.BorderSizePixel = 0; main.Active = true; main.Draggable = true
    main.Parent = sg
    local mc = Instance.new("UICorner"); mc.CornerRadius = UDim.new(0, 14); mc.Parent = main
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 200, 140); stroke.Thickness = 1; stroke.Transparency = 0.6
    stroke.Parent = main

    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 44); header.BackgroundTransparency = 1; header.Parent = main
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -60, 0, 30); title.Position = UDim2.new(0, 16, 0, 7)
    title.BackgroundTransparency = 1; title.TextColor3 = Color3.fromRGB(0, 230, 160)
    title.Font = Enum.Font.GothamBold; title.TextSize = 15
    title.TextXAlignment = Enum.TextXAlignment.Left; title.Text = "DDS v1.4 | V1.1.9"; title.Parent = header
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 0, 30); closeBtn.Position = UDim2.new(1, -38, 0, 7)
    closeBtn.BackgroundColor3 = Color3.fromRGB(160, 40, 50); closeBtn.BorderSizePixel = 0
    closeBtn.Text = "×"; closeBtn.TextColor3 = Color3.fromRGB(255,255,255)
    closeBtn.Font = Enum.Font.GothamBold; closeBtn.TextSize = 18; closeBtn.Parent = header
    local cc = Instance.new("UICorner"); cc.CornerRadius = UDim.new(0, 8); cc.Parent = closeBtn
    track(closeBtn.MouseButton1Click:Connect(function() main.Visible = not main.Visible end))

    local tabBar = Instance.new("Frame")
    tabBar.Size = UDim2.new(1, -24, 0, 32); tabBar.Position = UDim2.new(0, 12, 0, 44)
    tabBar.BackgroundColor3 = Color3.fromRGB(24, 24, 30); tabBar.BorderSizePixel = 0; tabBar.Parent = main
    local tbc = Instance.new("UICorner"); tbc.CornerRadius = UDim.new(0, 8); tbc.Parent = tabBar
    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    tabLayout.Padding = UDim.new(0, 2); tabLayout.Parent = tabBar

    local pages = {}
    local tabNames = {"DRIVE", "VISUAL", "FARM", "SHOP", "BETA"}
    local function selectTab(name)
        for n, pg in pairs(pages) do pg.Visible = (n == name) end
        for _, c in ipairs(tabBar:GetChildren()) do
            if c:IsA("TextButton") then
                if c.Name == "BETA" then
                    c.BackgroundColor3 = (c.Name == name) and Color3.fromRGB(200, 120, 20) or Color3.fromRGB(60, 40, 20)
                else
                    c.BackgroundColor3 = (c.Name == name) and Color3.fromRGB(0, 140, 100) or Color3.fromRGB(30, 30, 38)
                end
            end
        end
    end
    for _, name in ipairs(tabNames) do
        local tb = Instance.new("TextButton")
        tb.Name = name; tb.Size = UDim2.new(0, 52, 0, 26)
        tb.BackgroundColor3 = name == "BETA" and Color3.fromRGB(60, 40, 20) or Color3.fromRGB(30, 30, 38)
        tb.BorderSizePixel = 0
        tb.Text = name; tb.TextColor3 = name == "BETA" and Color3.fromRGB(255, 200, 100) or Color3.fromRGB(220,220,220)
        tb.Font = Enum.Font.Gotham; tb.TextSize = 10; tb.Parent = tabBar
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = tb
        track(tb.MouseButton1Click:Connect(function() selectTab(name) end))
    end

    local pageFrame = Instance.new("Frame")
    pageFrame.Size = UDim2.new(1, -24, 1, -88); pageFrame.Position = UDim2.new(0, 12, 0, 80)
    pageFrame.BackgroundTransparency = 1; pageFrame.Parent = main

    local function makePage(name)
        local sf = Instance.new("ScrollingFrame")
        sf.Name = name; sf.Size = UDim2.new(1, 0, 1, 0)
        sf.BackgroundTransparency = 1; sf.BorderSizePixel = 0
        sf.ScrollBarThickness = 4; sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
        sf.CanvasSize = UDim2.new(0, 0, 0, 0); sf.Visible = false; sf.Parent = pageFrame
        local ll = Instance.new("UIListLayout")
        ll.Padding = UDim.new(0, 6); ll.SortOrder = Enum.SortOrder.LayoutOrder; ll.Parent = sf
        pages[name] = sf
        return sf
    end

    local pDrive = makePage("DRIVE")
    createToggle(pDrive, "PerfectStart", "Perfect Start", 1)
    createToggle(pDrive, "UseClutch", "Deteksi Clutch", 2)
    createToggle(pDrive, "UseGear1", "Deteksi Gear 1", 3)
    createToggle(pDrive, "UseWheelieHold", "Wheelie Hold Launch", 4, nil, true)
    createToggle(pDrive, "AutoShift", "Auto Shift", 5)
    createToggle(pDrive, "SpeedEnabled", "Speed Changer", 6)
    createSlider(pDrive, "CarMultiplier", "Car Multiplier", 1.00, 2.50, 0.05, 7, "x")
    createSlider(pDrive, "BikeMultiplier", "Bike Multiplier", 1.00, 2.50, 0.05, 8, "x")
    createSlider(pDrive, "MaxRatio", "Max Cap", 1.20, 3.00, 0.05, 9, "x")
    createSlider(pDrive, "ApplyBias", "Smoothing", 0.30, 1.00, 0.05, 10, "")
    createToggle(pDrive, "NoDrag", "No Drag", 11)

    local pVisual = makePage("VISUAL")
    createToggle(pVisual, "ESP", "ESP Players", 1, function(v) if not v then clearESP() end end)
    createToggle(pVisual, "Fullbright", "Fullbright", 2, function(v)
        if not v then
            Lighting.Ambient = Color3.fromRGB(70,70,70)
            Lighting.OutdoorAmbient = Color3.fromRGB(70,70,70)
        end
    end)
    createToggle(pVisual, "NoFog", "No Fog", 3)
    createSlider(pVisual, "FOV", "FOV", 40, 120, 5, 4, "")
    createToggle(pVisual, "CameraLock", "Camera Lock", 5)
    createToggle(pVisual, "AutoWin", "Auto Win", 6)

    local pFarm = makePage("FARM")
    createToggle(pFarm, "AutoOffice", "Auto Office", 1, function(v) if v then Config.AutoBarista = false; Config.AutoCourier = false; Config.FarmQueueMode = false end end)
    createToggle(pFarm, "AutoBarista", "Auto Barista", 2, function(v) if v then Config.AutoOffice = false; Config.AutoCourier = false; Config.FarmQueueMode = false end end)
    createToggle(pFarm, "AutoCourier", "Auto Courier", 3, function(v) if v then Config.AutoOffice = false; Config.AutoBarista = false; Config.FarmQueueMode = false end end)
    createToggle(pFarm, "FarmQueueMode", "Farm Queue (rotate)", 4, function(v)
        if v then Config.AutoOffice = false; Config.AutoBarista = false; Config.AutoCourier = false end
    end)
    createToggle(pFarm, "TeleportFarm", "Teleport to Target", 5)
    createToggle(pFarm, "ScanAllMaps", "Scan All Maps", 6)
    createSlider(pFarm, "FarmRadius", "Scan Radius", 20, 200, 10, 7, " st")
    createSlider(pFarm, "FarmInterval", "Interval", 0.2, 2.0, 0.1, 8, "s")
    createToggle(pFarm, "AntiAFK", "Anti AFK", 9)

    local pShop = makePage("SHOP")
    createToggle(pShop, "AutoUpgrade", "Auto Upgrade", 1)
    createSlider(pShop, "UpgradeCheck", "Upgrade Check", 1.0, 10.0, 0.5, 2, "s")
    createToggle(pShop, "AutoRedeem", "Auto Redeem Code", 3)
    createSlider(pShop, "RedeemInterval", "Redeem Interval", 2.0, 15.0, 0.5, 4, "s")

    local pBeta = makePage("BETA")
    -- Header notice
    local notice = Instance.new("TextLabel")
    notice.Size = UDim2.new(1, 0, 0, 44)
    notice.BackgroundColor3 = Color3.fromRGB(60, 40, 20)
    notice.BorderSizePixel = 0
    notice.TextColor3 = Color3.fromRGB(255, 200, 100)
    notice.Font = Enum.Font.Gotham
    notice.TextSize = 11
    notice.TextWrapped = true
    notice.LayoutOrder = 0
    notice.Text = "  BETA — fitur di sini belum stabil. Hasil bisa bervariasi tergantung UI game, format soal, dan struktur model kendaraan. Baca log console sebelum lapor bug."
    notice.TextXAlignment = Enum.TextXAlignment.Left
    notice.Parent = pBeta
    local nc = Instance.new("UICorner"); nc.CornerRadius = UDim.new(0, 8); nc.Parent = notice

    -- Math Solver group
    local mathHeader = Instance.new("TextLabel")
    mathHeader.Size = UDim2.new(1, 0, 0, 20)
    mathHeader.BackgroundTransparency = 1
    mathHeader.TextColor3 = Color3.fromRGB(255, 200, 100)
    mathHeader.Font = Enum.Font.GothamBold
    mathHeader.TextSize = 12
    mathHeader.TextXAlignment = Enum.TextXAlignment.Left
    mathHeader.Text = "  OFFICE MATH SOLVER"
    mathHeader.LayoutOrder = 1
    mathHeader.Parent = pBeta

    createToggle(pBeta, "MathSolver", "Auto Solve Math", 2, nil, true)
    createToggle(pBeta, "MathSubmit", "Auto Submit Answer", 3, nil, true)
    createSlider(pBeta, "MathInterval", "Solve Interval", 0.5, 5.0, 0.1, 4, "s")

    local mathStats = Instance.new("TextLabel")
    mathStats.Size = UDim2.new(1, 0, 0, 30)
    mathStats.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
    mathStats.BorderSizePixel = 0
    mathStats.TextColor3 = Color3.fromRGB(0, 220, 160)
    mathStats.Font = Enum.Font.Gotham
    mathStats.TextSize = 11
    mathStats.TextXAlignment = Enum.TextXAlignment.Left
    mathStats.Text = "  OK:0 Fail:0 — belum jalan"
    mathStats.LayoutOrder = 5
    mathStats.Parent = pBeta
    local msc = Instance.new("UICorner"); msc.CornerRadius = UDim.new(0, 6); msc.Parent = mathStats
    State.UI.MathStats = mathStats

    -- Probe group
    local probeHeader = Instance.new("TextLabel")
    probeHeader.Size = UDim2.new(1, 0, 0, 20)
    probeHeader.BackgroundTransparency = 1
    probeHeader.TextColor3 = Color3.fromRGB(255, 200, 100)
    probeHeader.Font = Enum.Font.GothamBold
    probeHeader.TextSize = 12
    probeHeader.TextXAlignment = Enum.TextXAlignment.Left
    probeHeader.Text = "  READ-ONLY PROBES"
    probeHeader.LayoutOrder = 10
    probeHeader.Parent = pBeta

    createToggle(pBeta, "GearProbe", "Gear Ratio Probe (console)", 11, nil, true)
    createToggle(pBeta, "WheelieProbe", "Wheelie State Probe (console)", 12, nil, true)

    selectTab("DRIVE")

    local reopen = Instance.new("TextButton")
    reopen.Size = UDim2.new(0, 48, 0, 48); reopen.Position = UDim2.new(0, 12, 0, 70)
    reopen.BackgroundColor3 = Color3.fromRGB(0, 140, 100); reopen.BackgroundTransparency = 0.15
    reopen.BorderSizePixel = 0; reopen.Text = "DDS"; reopen.TextColor3 = Color3.fromRGB(255,255,255)
    reopen.Font = Enum.Font.GothamBold; reopen.TextSize = 13; reopen.Parent = sg
    local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0, 24); rc.Parent = reopen
    track(reopen.MouseButton1Click:Connect(function() main.Visible = not main.Visible end))
end

buildUI()

-- Update stats label
task.spawn(function()
    while task.wait(0.5) do
        if State.UI.MathStats then
            local status = Config.MathSolver and "running" or "idle"
            State.UI.MathStats.Text = string.format("  OK:%d Fail:%d — %s", State.MathOK, State.MathFail, status)
        end
    end
end)

LP.CharacterAdded:Connect(function() clearESP() end)