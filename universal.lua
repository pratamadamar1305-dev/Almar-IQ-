--!strict
-- language: Lua (Luau), Roblox executor LocalScript, target: Android (Delta / Fluxus / Arceus X)
-- Requires: Drawing API, Rayfield, writefile/readfile (optional for scan cache)
-- Auto-scans track for path nodes -> generates RRR3-style racing line -> autopilot ready.
-- No manual recording required: tap SCAN, line appears, autopilot can engage.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")

local lp = Players.LocalPlayer
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

-- ─── types ──────────────────────────────────────────────────────
type Vec3 = Vector3
type Vehicle = { seat: VehicleSeat, position: Vec3 }
type SplinePoint = { pos: Vec3, speed: number }
type Preset = { amp: number, look: number, thr: number, wet: number }

-- ─── constants ─────────────────────────────────────────────────
local NAME_PATTERNS: {string} = {
    "^%s*[Ww]aypoint", "^%s*[Cc]heckpoint", "^%s*[Cc][Pp]%d",
    "^%s*[Nn]ode",     "^%s*[Rr]oute",      "^%s*[Pp]ath",
    "^%s*[Mm]arker",   "^%s*[Gg]ate",       "^%s*[Ff]inish",
}

local TAG_CANDIDATES: {string} = {
    "Checkpoint", "Waypoint", "Node", "Route", "Path", "TrackNode", "RaceNode",
}

local ATTR_CANDIDATES: {string} = {
    "CheckpointNumber", "WaypointIndex", "Order", "Index", "Number", "LapNumber",
}

local PRESETS: {[string]: Preset} = {
    ["Pine Forest"]      = { amp = 8,  look = 8,  thr = 12, wet = 1.00 },
    ["Alpine Pass"]      = { amp = 12, look = 11, thr = 16, wet = 0.85 },
    ["Frozen Lake"]      = { amp = 5,  look = 13, thr = 10, wet = 0.70 },
    ["Costa Limone"]     = { amp = 10, look = 10, thr = 14, wet = 0.80 },
    ["Sakura Pass"]      = { amp = 9,  look = 9,  thr = 13, wet = 0.90 },
    ["Riverbend Canyon"] = { amp = 14, look = 12, thr = 15, wet = 0.90 },
}

local SPS = 8                    -- Catmull-Rom samples per segment
local NEAREST_WINDOW = 60        -- local search radius in spline points
local FAR_JUMP = 500             -- studs — trigger full rescan of spline
local MAX_WAYPOINTS = 2000       -- cap manual add growth
local SCAN_COOLDOWN = 1.5        -- seconds between SCAN taps
local SCAN_YIELD_EVERY = 200     -- parts scanned before task.wait()

-- ─── state ─────────────────────────────────────────────────────
local waypoints: {Vec3} = {}
local spline: {SplinePoint} = {}
local drawings: {any} = {}
local autopilot: boolean = false
local lookahead: number = 9
local amp: number = 10
local curveThresh: number = math.rad(13)
local wetFactor: number = 1.0
local useGenerated: boolean = true
local reverseDirection: boolean = false
local lastSplineIdx: number = 1
local lastScanAt: number = 0
local connections: {RBXScriptConnection} = {}
local currentStage: string = "Pine Forest"

-- ─── vehicle accessor ──────────────────────────────────────────
local function getVehicle(): Vehicle?
    local char = lp.Character
    if not char or not char.Parent then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return nil end
    local seat = hum.SeatPart
    if not seat or not seat.Parent then return nil end
    local model = seat:FindFirstAncestorOfClass("Model")
    local prim = (model and (model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")))
        or seat
    if not prim or not prim.Parent then return nil end
    return { seat = seat, position = prim.Position }
end

-- ─── scan: name + tag matching ────────────────────────────────
local function matchesPattern(name: string): boolean
    for _, pat in ipairs(NAME_PATTERNS) do
        if name:match(pat) then return true end
    end
    return false
end

local function scanTrackNodes(): {BasePart}
    local results: {BasePart} = {}
    local found: {[Instance]: boolean} = {}
    local scanned = 0

    local function recurse(root: Instance)
        for _, child in ipairs(root:GetChildren()) do
            if child:IsA("BasePart") and matchesPattern(child.Name) and not found[child] then
                found[child] = true
                table.insert(results, child)
            end
            if #child:GetChildren() > 0 then
                recurse(child)
            end
            scanned = scanned + 1
            if scanned % SCAN_YIELD_EVERY == 0 then
                task.wait()
            end
        end
    end
    recurse(workspace)

    for _, tag in ipairs(TAG_CANDIDATES) do
        for _, obj in ipairs(CollectionService:GetTagged(tag)) do
            if obj:IsA("BasePart") and not found[obj] then
                found[obj] = true
                table.insert(results, obj)
            end
        end
    end
    return results
end

-- ─── ordering ─────────────────────────────────────────────────
local function extractOrder(part: BasePart): number?
    for _, attr in ipairs(ATTR_CANDIDATES) do
        local v = part:GetAttribute(attr)
        if typeof(v) == "number" then return v end
    end
    local m = part.Name:match("(%d+)%s*$") or part.Name:match("(%d+)")
    if m then return tonumber(m) end
    return nil
end

local function orderByAttribute(nodes: {BasePart}): {Vec3}?
    local keyed: {[number]: BasePart} = {}
    local count = 0
    for _, n in ipairs(nodes) do
        local ord = extractOrder(n)
        if ord ~= nil and keyed[ord] == nil then
            keyed[ord] = n
            count = count + 1
        end
    end
    if count ~= #nodes then return nil end

    local keys: {number} = {}
    for k in pairs(keyed) do table.insert(keys, k) end
    table.sort(keys)

    local out: {Vec3} = {}
    for _, k in ipairs(keys) do
        table.insert(out, keyed[k].Position)
    end
    return out
end

local function orderByProximity(nodes: {BasePart}, startPos: Vec3?): {Vec3}
    local pool: {BasePart} = {}
    for _, n in ipairs(nodes) do table.insert(pool, n) end

    local startI = 1
    if startPos then
        local best, bi = math.huge, 1
        for i, p in ipairs(pool) do
            local d = (p.Position - startPos).Magnitude
            if d < best then best, bi = d, i end
        end
        startI = bi
    end

    local chain: {Vec3} = {}
    local current = pool[startI].Position
    table.insert(chain, current)
    table.remove(pool, startI)

    while #pool > 0 do
        local best, bestI = math.huge, 1
        for i, p in ipairs(pool) do
            local d = (p.Position - current).Magnitude
            if d < best then best, bestI = d, i end
        end
        local nextNode = table.remove(pool, bestI)
        current = nextNode.Position
        table.insert(chain, current)
    end

    if reverseDirection then
        local rev: {Vec3} = {}
        for i = #chain, 1, -1 do table.insert(rev, chain[i]) end
        return rev
    end
    return chain
end

local function buildChain(nodes: {BasePart}, startPos: Vec3?): {Vec3}
    if #nodes < 4 then return {} end
    local ordered = orderByAttribute(nodes)
    if ordered and #ordered >= 4 then return ordered end
    return orderByProximity(nodes, startPos)
end

-- ─── Catmull-Rom ───────────────────────────────────────────────
local function catmullRom(p0: Vec3, p1: Vec3, p2: Vec3, p3: Vec3, t: number): Vec3
    local t2, t3 = t*t, t*t*t
    return (p1*2 + (p2-p0)*t + (p0*2 - p1*5 + p2*4 - p3)*t2 + (-p0 + p1*3 - p2*3 + p3)*t3) * 0.5
end

-- ─── generate racing line (outside-apex-outside) ───────────────
local function generateRacingLine(centerline: {Vec3}): {Vec3}
    local n = #centerline
    if n < 4 then return centerline end

    local curv: {number} = {}
    local signed: {number} = {}
    for i = 1, n do
        local a = centerline[i] - centerline[math.max(1, i-1)]
        local b = centerline[math.min(n, i+1)] - centerline[i]
        local ah = Vector3.new(a.X, 0, a.Z)
        local bh = Vector3.new(b.X, 0, b.Z)
        if ah.Magnitude < 1e-3 or bh.Magnitude < 1e-3 then
            curv[i] = 0; signed[i] = 0
        else
            curv[i] = math.acos(math.clamp(ah.Unit:Dot(bh.Unit), -1, 1))
            signed[i] = ah.Unit:Cross(bh.Unit).Y
        end
    end

    local smooth: {number} = {}
    for i = 1, n do
        local s, c = 0, 0
        for j = math.max(1, i-2), math.min(n, i+2) do s = s + curv[j]; c = c + 1 end
        smooth[i] = s / c
    end

    local corners: {{start: number, finish: number, sign: number, peak: number}} = {}
    local inC, startI, apexV = false, 0, 0
    local signSum, signCnt = 0, 0
    for i = 1, n do
        if smooth[i] > curveThresh then
            if not inC then
                inC, startI, apexV = true, i, smooth[i]
                signSum, signCnt = 0, 0
            end
            if smooth[i] > apexV then apexV = smooth[i] end
            signSum = signSum + signed[i]; signCnt = signCnt + 1
        elseif inC then
            inC = false
            local sign = (signSum / math.max(signCnt, 1)) > 0 and 1 or -1
            table.insert(corners, { start = startI, finish = i, sign = sign, peak = apexV })
        end
    end

    local racing: {Vec3} = {}
    for i = 1, n do racing[i] = centerline[i] end
    for _, cor in ipairs(corners) do
        local len = cor.finish - cor.start
        if len >= 3 then
            local scale = math.clamp(cor.peak / math.rad(50), 0.35, 1) * amp * wetFactor
            for i = cor.start, cor.finish do
                local phase = (i - cor.start) / len
                local mul = math.cos(2 * math.pi * phase) * scale
                local dir = centerline[math.min(n, i+1)] - centerline[math.max(1, i-1)]
                local dh = Vector3.new(dir.X, 0, dir.Z)
                if dh.Magnitude > 1e-3 then
                    local right = dh.Unit:Cross(Vector3.new(0, 1, 0))
                    racing[i] = centerline[i] + right * (-cor.sign * mul)
                end
            end
        end
    end
    return racing
end

-- ─── spline build ──────────────────────────────────────────────
local function buildSpline(src: {Vec3})
    local newSpline: {SplinePoint} = {}
    local n = #src
    if n < 4 then
        spline = {}
        return
    end
    for i = 1, n - 1 do
        local p0 = src[math.max(1, i-1)]
        local p1 = src[i]
        local p2 = src[i+1]
        local p3 = src[math.min(n, i+2)]
        for s = 0, SPS - 1 do
            table.insert(newSpline, { pos = catmullRom(p0, p1, p2, p3, s / SPS), speed = 1 })
        end
    end
    table.insert(newSpline, { pos = src[n], speed = 1 })

    for i = 1, #newSpline do
        local a = newSpline[i].pos - newSpline[math.max(1, i-1)].pos
        local b = newSpline[math.min(#newSpline, i+1)].pos - newSpline[i].pos
        local ah = Vector3.new(a.X, 0, a.Z)
        local bh = Vector3.new(b.X, 0, b.Z)
        if ah.Magnitude < 1e-3 or bh.Magnitude < 1e-3 then
            newSpline[i].speed = 1
        else
            local ang = math.acos(math.clamp(ah.Unit:Dot(bh.Unit), -1, 1))
            newSpline[i].speed = math.clamp(1 - ang / math.rad(60), 0.15, 1) * wetFactor
        end
    end
    spline = newSpline
    lastSplineIdx = 1
end

-- ─── color / draw ──────────────────────────────────────────────
local function speedColor(s: number): Color3
    if s > 0.75 then return Color3.fromRGB(60, 220, 60)
    elseif s > 0.50 then return Color3.fromRGB(230, 225, 60)
    elseif s > 0.30 then return Color3.fromRGB(255, 150, 40)
    else return Color3.fromRGB(255, 50, 50) end
end

local function clearDrawings()
    for _, d in ipairs(drawings) do
        if d then d:Remove() end
    end
    drawings = {}
end

local function redraw()
    clearDrawings()
    for i = 1, #spline - 1 do
        local l = Drawing.new("Line")
        l.From = spline[i].pos
        l.To = spline[i+1].pos
        l.Color = speedColor(spline[i].speed)
        l.Thickness = 3
        l.Transparency = 0.9
        l.Visible = true
        table.insert(drawings, l)
    end
end

local function rebuild()
    if #waypoints < 4 then
        spline = {}
        clearDrawings()
        return
    end
    if useGenerated then
        buildSpline(generateRacingLine(waypoints))
    else
        buildSpline(waypoints)
    end
    redraw()
end

-- ─── nearest + lookahead ──────────────────────────────────────
local function nearestIdx(p: Vec3): number
    local n = #spline
    if n == 0 then return 1 end
    local best, bi = math.huge, lastSplineIdx
    local lo = math.max(1, lastSplineIdx - NEAREST_WINDOW)
    local hi = math.min(n, lastSplineIdx + NEAREST_WINDOW)
    for i = lo, hi do
        local d = (spline[i].pos - p).Magnitude
        if d < best then best, bi = d, i end
    end
    if best > FAR_JUMP then
        for i = 1, n do
            local d = (spline[i].pos - p).Magnitude
            if d < best then best, bi = d, i end
        end
    end
    lastSplineIdx = bi
    return bi
end

local function lookaheadPoint(fromIdx: number, dist: number): (Vec3?, number)
    local n = #spline
    if n < 2 then return nil, fromIdx end
    local acc, i = 0, fromIdx
    while i < n do
        local seg = (spline[i+1].pos - spline[i].pos).Magnitude
        if acc + seg >= dist then
            return spline[i].pos:Lerp(spline[i+1].pos, (dist - acc) / seg), i
        end
        acc = acc + seg
        i = i + 1
    end
    return spline[n].pos, n
end

local function drive(v: Vehicle, target: Vec3, throttle: number)
    local seat = v.seat
    if not seat or not seat.Parent then return end
    local ok, lt = pcall(function()
        return seat.CFrame:PointToObjectSpace(target)
    end)
    if not ok then return end
    local steer = math.clamp(lt.X / math.max(math.abs(lt.Z), 1), -1, 1)
    seat.Steer = steer
    seat.Throttle = throttle
end

-- ─── scan pipeline ─────────────────────────────────────────────
local function performScan(): (boolean, string)
    local now = os.clock()
    if now - lastScanAt < SCAN_COOLDOWN then
        return false, "cooldown, wait a moment"
    end
    lastScanAt = now

    local veh = getVehicle()
    local startPos = veh and veh.position or nil
    local nodes = scanTrackNodes()
    if #nodes < 4 then
        return false, ("only %d candidate nodes — track may use unique names"):format(#nodes)
    end

    local chain = buildChain(nodes, startPos)
    if #chain < 4 then
        return false, "ordering failed — cannot chain nodes"
    end

    waypoints = chain
    useGenerated = true
    rebuild()
    return true, ("%d nodes chained"):format(#chain)
end

-- ─── Rayfield UI ───────────────────────────────────────────────
local Window = Rayfield:CreateWindow({
    Name = "Backseat Rally — Auto Racing Line",
    LoadingTitle = "Loading",
    LoadingSubtitle = "scan · generate · drive",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false,
})

local tabStage = Window:CreateTab("Stage", 4483362458)
tabStage:CreateSection("Preset")
local stageNames: {string} = {}
for k in pairs(PRESETS) do table.insert(stageNames, k) end
table.sort(stageNames)

for _, name in ipairs(stageNames) do
    tabStage:CreateButton({
        Name = name,
        Callback = function()
            local p = PRESETS[name]
            if not p then return end
            currentStage = name
            amp = p.amp
            lookahead = p.look
            curveThresh = math.rad(p.thr)
            wetFactor = p.wet
            Rayfield:Notify({ Title = "Stage", Content = name, Duration = 2 })
            if autopilot then
                Rayfield:Notify({ Title = "Note", Content = "preset changed — disable autopilot to apply cleanly", Duration = 3 })
            elseif #waypoints >= 4 and useGenerated then
                rebuild()
            end
        end,
    })
end

local tabScan = Window:CreateTab("Scan & Generate", 4483362458)
tabScan:CreateSection("Auto-detect track")

tabScan:CreateButton({
    Name = "SCAN NOW — find path nodes and generate",
    Callback = function()
        local ok, msg = performScan()
        Rayfield:Notify({
            Title = ok and "Ready" or "Scan failed",
            Content = msg,
            Duration = 4,
        })
    end,
})

tabScan:CreateToggle({
    Name = "Reverse direction (fallback only)",
    CurrentValue = false,
    Callback = function(v)
        reverseDirection = v
        if #waypoints >= 4 then
            local veh = getVehicle()
            local nodes = scanTrackNodes()
            local chain = buildChain(nodes, veh and veh.position or nil)
            if #chain >= 4 then
                waypoints = chain
                rebuild()
            end
        end
    end,
})

tabScan:CreateSection("Manual (fallback)")

tabScan:CreateButton({
    Name = "Add waypoint at current position",
    Callback = function()
        if #waypoints >= MAX_WAYPOINTS then
            Rayfield:Notify({ Title = "Cap", Content = ("max %d waypoints"):format(MAX_WAYPOINTS), Duration = 2 })
            return
        end
        local v = getVehicle()
        if not v then return end
        table.insert(waypoints, v.position)
        useGenerated = false
        if #waypoints >= 4 then rebuild() end
    end,
})

tabScan:CreateButton({
    Name = "Undo last waypoint",
    Callback = function()
        if #waypoints > 0 then
            table.remove(waypoints)
            rebuild()
        end
    end,
})

tabScan:CreateButton({
    Name = "Clear all",
    Callback = function()
        waypoints = {}
        rebuild()
    end,
})

tabScan:CreateSection("Cache")

tabScan:CreateButton({
    Name = "Save scan to file",
    Callback = function()
        if not writefile then
            Rayfield:Notify({ Title = "No writefile", Content = "executor lacks writefile", Duration = 3 })
            return
        end
        local out: {{number}} = {}
        for _, w in ipairs(waypoints) do
            table.insert(out, { w.X, w.Y, w.Z })
        end
        local fname = "rally_" .. currentStage:gsub("%s+", "_") .. ".json"
        writefile(fname, HttpService:JSONEncode(out))
        Rayfield:Notify({ Title = "Saved", Content = fname, Duration = 2 })
    end,
})

tabScan:CreateButton({
    Name = "Load scan from file",
    Callback = function()
        if not isfile or not readfile then
            Rayfield:Notify({ Title = "No readfile", Content = "executor lacks readfile", Duration = 3 })
            return
        end
        local fname = "rally_" .. currentStage:gsub("%s+", "_") .. ".json"
        if not isfile(fname) then
            Rayfield:Notify({ Title = "Empty", Content = fname, Duration = 3 })
            return
        end
        local ok, data = pcall(function()
            return HttpService:JSONDecode(readfile(fname))
        end)
        if not ok or type(data) ~= "table" then
            Rayfield:Notify({ Title = "Corrupt", Content = "file parse failed", Duration = 3 })
            return
        end
        local loaded: {Vec3} = {}
        for _, t in ipairs(data) do
            if type(t) == "table"
                and type(t[1]) == "number"
                and type(t[2]) == "number"
                and type(t[3]) == "number" then
                table.insert(loaded, Vector3.new(t[1], t[2], t[3]))
            end
        end
        waypoints = loaded
        useGenerated = true
        rebuild()
        Rayfield:Notify({ Title = "Loaded", Content = ("%d points"):format(#loaded), Duration = 2 })
    end,
})

local tabLine = Window:CreateTab("Racing Line", 4483362458)
tabLine:CreateToggle({
    Name = "Generate (RRR3 style)",
    CurrentValue = true,
    Callback = function(v)
        useGenerated = v
        if #waypoints >= 4 then rebuild() end
    end,
})
tabLine:CreateSlider({
    Name = "Amplitude",
    Range = { 2, 24 },
    Increment = 2,
    Suffix = " stud",
    CurrentValue = amp,
    Callback = function(v)
        amp = v
        if useGenerated and #waypoints >= 4 then rebuild() end
    end,
})
tabLine:CreateButton({
    Name = "Regenerate",
    Callback = function()
        if #waypoints >= 4 then rebuild() end
    end,
})

local tabAuto = Window:CreateTab("Autopilot", 4483362458)
tabAuto:CreateToggle({
    Name = "Autopilot",
    CurrentValue = false,
    Callback = function(v)
        if v and #spline < 2 then
            Rayfield:Notify({ Title = "Empty spline", Content = "SCAN first", Duration = 3 })
            return
        end
        autopilot = v
        if not v then
            local veh = getVehicle()
            if veh and veh.seat.Parent then
                veh.seat.Steer = 0
                veh.seat.Throttle = 0
            end
        end
    end,
})
tabAuto:CreateSlider({
    Name = "Lookahead",
    Range = { 4, 30 },
    Increment = 1,
    Suffix = " stud",
    CurrentValue = lookahead,
    Callback = function(v) lookahead = v end,
})

-- ─── main render loop ─────────────────────────────────────────
local function onRenderStep()
    if not autopilot then return end
    if #spline < 2 then return end
    local v = getVehicle()
    if not v then return end

    local idx = nearestIdx(v.position)
    local target, ti = lookaheadPoint(idx, lookahead)
    if not target then return end

    local sp = 1
    local hi = math.min(ti + 6, #spline)
    for j = idx, hi do
        if spline[j].speed < sp then sp = spline[j].speed end
    end
    drive(v, target, math.clamp(sp, -1, 1))
end

table.insert(connections, RunService.RenderStepped:Connect(onRenderStep))

-- ─── cleanup ──────────────────────────────────────────────────
local function cleanup()
    for _, c in ipairs(connections) do
        c:Disconnect()
    end
    connections = {}
    clearDrawings()
    spline = {}
    autopilot = false
    local veh = getVehicle()
    if veh and veh.seat.Parent then
        veh.seat.Steer = 0
        veh.seat.Throttle = 0
    end
end

getgenv().BackseatRallyCleanup = cleanup