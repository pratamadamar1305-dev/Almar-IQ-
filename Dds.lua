-- Drag Drive Simulator — All-in-One Mobile v2.0
-- Target game: Beta V1.1.9
-- Executor: Arceus X, Delta, Fluxus, Codex, Hydrogen
-- Changelog v2.0 (dari v1.8):
--   [+] Host resolver berlapis: gethui() → CoreGui → PlayerGui → Workspace
--   [+] Wait camera ready sebelum build (anti viewport 0)
--   [+] Validate ScreenGui.Parent setelah assign
--   [+] Panel default hidden, verify posisi/size, baru show
--   [+] FAB fallback posisi absolut (selalu muncul)
--   [+] Diagnostic log ke console
--   [+] Auto-retry host fallback setelah 3s
--   [+] Fix slider drag di touch (InputChanged global)
--   [+] Fix shadow 0x0, applyLayout timing, tab warna reset
--   [+] Label adaptif di compact mode (tidak truncate)

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInput         = game:GetService("UserInputService")
local Lighting          = game:GetService("Lighting")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser       = game:GetService("VirtualUser")
local VIM               = game:GetService("VirtualInputManager")
local TweenService      = game:GetService("TweenService")
local GuiService        = game:GetService("GuiService")

local LP = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local PlayerGui = LP:WaitForChild("PlayerGui")

-- ============================================================
-- CONFIG
-- ============================================================
local Config = {
    PerfectStart=false, LaunchRPM=0.62, LaunchRampTime=0.45, LaunchDelay=0.05,
    UseClutch=true, UseGear1=true, UseWheelieHold=false,
    SpeedEnabled=false, CarTargetKmh=180, BikeTargetKmh=160,
    MaxTargetKmh=320, MinTargetKmh=40,
    AccelRate=0.10, DecelRate=0.25, HysteresisKmh=2.0,
    MaxDeltaKmhPerFrame=6, MinCurrentKmh=5, StudsToKmh=1.008,
    AutoShift=false, ShiftPoint=0.92,
    ESP=false, ESPColor=Color3.fromRGB(0,255,180), Fullbright=false, NoFog=false,
    FOV=80, NoDrag=false, CameraLock=false, AutoWin=false, AntiAFK=true,
    AutoCourier=false, AutoBarista=false, AutoOffice=false, FarmQueueMode=false,
    FarmRadius=60, FarmInterval=0.6, TeleportFarm=true,
    TeleportOffset=Vector3.new(0,3,0), ScanAllMaps=true,
    AutoUpgrade=false, UpgradeCheck=3.0,
    UpgradePriority={"Engine","Turbo","Weight","Grip","Transmission"},
    AutoRedeem=false,
    RedeemCodes={
        "DDSWHEELIESTYLEUPDATE","NEWGATSUMAPNEWMODIFICATION","WHEELIESTYLEBIGUPDATE",
        "HBDADVGAMERSTEAM26","DELAYDIKITLAGIFREESTYLE","DRAGDRIVESIMULATORSEPTEMBER26",
    },
    RedeemInterval=5.0,
    MathSolver=false, MathInterval=1.2, MathSubmit=true,
    GearProbe=false, WheelieProbe=false,
}

local State = {
    Vehicle=nil, VehicleRoot=nil, IsBike=false, VehicleName="",
    RpmValue=nil, RpmMax=8000, Ready=false,
    GearValues={}, WheelieValues={},
    Connections={}, ESPObjects={},
    UI={},
    LastFarm=0, LastUpgrade=0, LastRedeem=0, LastMath=0,
    UpgradeBusy=false, RedeemIndex=1, RedeemBusy=false, MathBusy=false,
    MathLastQ="", MathOK=0, MathFail=0,
    FarmQueue={"office","barista","courier"}, FarmQueueIdx=1,
    SpeedCurrentKmh=0,
}
local function track(c) table.insert(State.Connections, c) return c end

-- ============================================================
-- VEHICLE
-- ============================================================
local BIKE_HINTS={"bike","motor","moto","r1","r6","cbr","ninja","gsxr","ducati","harley",
    "scooter","vixion","beat","nmax","pcx","aerox","vario","satria","sonic"}
local CAR_HINTS={"car","mobil","sedan","coupe","truck","supra","skyline","gt","ferrari",
    "lambo","civic","jazz","avanza","gatsu","wheelie","wide","rim","limited"}

local function classifyVehicle(model)
    if not model then return false, "" end
    local name=model.Name:lower()
    for _,h in ipairs(BIKE_HINTS) do if name:find(h) then return true, model.Name end end
    for _,h in ipairs(CAR_HINTS) do if name:find(h) then return false, model.Name end end
    local c=0; for _,d in ipairs(model:GetDescendants()) do if d:IsA("BasePart") then c+=1 end end
    return c<40, model.Name
end

local function cacheVehicleParts(model)
    State.RpmValue=nil; State.RpmMax=8000; State.VehicleRoot=nil
    State.GearValues={}; State.WheelieValues={}
    if not model then return end
    for _,d in ipairs(model:GetDescendants()) do
        if d:IsA("NumberValue") then
            local n=d.Name:lower()
            if n:find("rpm") and not State.RpmValue then State.RpmValue=d end
            if n:find("gear") or n:find("ratio") then table.insert(State.GearValues,{name=d.Name,value=d.Value}) end
            if n:find("wheelie") then table.insert(State.WheelieValues,{name=d.Name,value=d.Value}) end
        end
    end
    local mx=model:FindFirstChild("MaxRPM") or model:FindFirstChild("Redline")
    if mx and mx:IsA("NumberValue") then State.RpmMax=mx.Value end
    local drive=model:FindFirstChild("DriveSeat")
    if drive and drive:IsA("BasePart") then State.VehicleRoot=drive
    elseif model.PrimaryPart then State.VehicleRoot=model.PrimaryPart end
end

local function findVehicle()
    local char=LP.Character; if not char then return nil end
    local hum=char:FindFirstChildOfClass("Humanoid"); if not hum then return nil end
    local seat=hum.SeatPart
    if seat and seat:IsA("VehicleSeat") then return seat.Parent end
    return nil
end
task.spawn(function()
    while task.wait(0.4) do
        local v=findVehicle()
        if v~=State.Vehicle then
            State.Vehicle=v
            State.IsBike, State.VehicleName=classifyVehicle(v)
            cacheVehicleParts(v)
            State.Ready=(v~=nil and State.VehicleRoot~=nil)
        end
    end
end)

local function getRPM()
    if State.RpmValue then return State.RpmValue.Value, State.RpmMax end
    local root=State.VehicleRoot
    if root then return root.AssemblyAngularVelocity.Magnitude*60/(2*math.pi), State.RpmMax end
    return 0,0
end

-- ============================================================
-- MATCHER / TAP
-- ============================================================
local function matchesKeyword(name, kw)
    local l=name:lower()
    if l==kw then return true end
    if l:sub(1,#kw+1)==kw.." " then return true end
    if l:sub(-(#kw+1))==" "..kw then return true end
    if l:find("%f[%w]"..kw.."%f[%W]") then return true end
    return false
end
local function findGuiByKeywords(keywords)
    for _,g in ipairs(PlayerGui:GetDescendants()) do
        if g:IsA("GuiButton") and g.Visible then
            for _,k in ipairs(keywords) do
                if matchesKeyword(g.Name,k) or (g:IsA("TextButton") and matchesKeyword(g.Text,k)) then return g end
            end
        end
    end
end
local function findGasButton()      return findGuiByKeywords({"gas","throttle","accelerate","pedal"}) end
local function findGearButton()     return findGuiByKeywords({"shift","gear","naik"}) end
local function findGear1Button()    return findGuiByKeywords({"gear 1","gigi 1","first","1"}) end
local function findClutchButton()   return findGuiByKeywords({"clutch","kopling"}) end
local function findWheelieButton()  return findGuiByKeywords({"wheelie","angkat","stunt","trick"}) end
local function findInteractButton() return findGuiByKeywords({"interact","talk","work","mulai","start","ambil","deliver","serve"}) end
local function findRedeemInput()    return findGuiByKeywords({"redeem input","code input","kode"}) end
local function findRedeemButton()   return findGuiByKeywords({"redeem","tukar","klaim"}) end
local function findShopButton()     return findGuiByKeywords({"shop","store","toko","upgrade","garage"}) end
local function findSubmitButton()   return findGuiByKeywords({"submit","kirim","answer","jawab","confirm","ok"}) end
local function tapButton(btn, hold)
    if not btn then return false end
    local pos=btn.AbsolutePosition+btn.AbsoluteSize*0.5
    local ok=pcall(function()
        VIM:SendMouseButtonEvent(pos.X,pos.Y,0,true,game,0)
        task.wait(hold or 0.02)
        VIM:SendMouseButtonEvent(pos.X,pos.Y,0,false,game,0)
    end)
    if not ok then pcall(function() btn:Activated() end) end
    return ok
end

-- ============================================================
-- PERFECT START
-- ============================================================
local function isExactVisible(label)
    for _,g in ipairs(PlayerGui:GetDescendants()) do
        if g.Visible then
            if g:IsA("TextLabel") then
                if g.Text:gsub("%s+","")==label then return true end
            elseif g:IsA("ImageLabel") and g.Name:lower():find(label:lower()) then return true end
        end
    end
    return false
end
local function isGreenVisible()
    for _,g in ipairs(PlayerGui:GetDescendants()) do
        if g.Visible and g:IsA("TextLabel") then
            local t=g.Text:lower():gsub("%s+","")
            if t=="go" or t=="go!" or t=="start" or t=="mulai" then return true end
        end
    end
    return false
end
local launchPhase, launchStart = "idle", 0
track(RunService.Heartbeat:Connect(function()
    if not Config.PerfectStart or not State.Ready then launchPhase="idle" return end
    local rpm, max=getRPM(); local ratio=max>0 and rpm/max or 0
    local gas=findGasButton()
    if launchPhase=="idle" and isExactVisible("3") then
        launchPhase="prep"; launchStart=os.clock()
        if Config.UseGear1 then local g1=findGear1Button() if g1 then tapButton(g1,0.05) end end
        if Config.UseClutch then local cl=findClutchButton() if cl then tapButton(cl,0.1) end end
        if Config.UseWheelieHold then local wh=findWheelieButton() if wh then tapButton(wh,0.1) end end
    end
    if launchPhase=="prep" then
        local elapsed=os.clock()-launchStart
        if ratio<Config.LaunchRPM-0.03 then tapButton(gas,0.03) end
        if elapsed>=Config.LaunchRampTime then launchPhase="hold"; launchStart=os.clock() end
        return
    end
    if launchPhase=="hold" then
        if ratio<Config.LaunchRPM-0.04 then tapButton(gas,0.03) end
        if isGreenVisible() then launchPhase="launch"; launchStart=os.clock()
        elseif os.clock()-launchStart>2.5 then launchPhase="idle" end
        return
    end
    if launchPhase=="launch" then
        if os.clock()-launchStart>=Config.LaunchDelay then tapButton(gas,0.25); launchPhase="idle" end
    end
end))

-- ============================================================
-- AUTOSHIFT
-- ============================================================
track(RunService.Heartbeat:Connect(function()
    if not Config.AutoShift or not State.Ready then return end
    local rpm, max=getRPM(); if max<=0 then return end
    if rpm/max>=Config.ShiftPoint then tapButton(findGearButton(),0.03) end
end))

-- ============================================================
-- SPEED CHANGER
-- ============================================================
local Easing = {
    linear=function(t) return t end,
    sine=function(t) return math.sin(t*math.pi*0.5) end,
    quad=function(t) return 1-(1-t)*(1-t) end,
    smooth=function(t) return t*t*(3-2*t) end,
}
local function ease(t) return Easing.sine(math.clamp(t,0,1)) end

track(RunService.Stepped:Connect(function()
    if not Config.SpeedEnabled or not State.Ready then
        State.SpeedCurrentKmh=0; return
    end
    local root=State.VehicleRoot
    if not root or not root.Parent then return end
    local targetKmh = State.IsBike and Config.BikeTargetKmh or Config.CarTargetKmh
    targetKmh = math.clamp(targetKmh, Config.MinTargetKmh, Config.MaxTargetKmh)
    local vel=root.AssemblyLinearVelocity; local mag=vel.Magnitude
    if mag<1 then return end
    local currentKmh=mag*Config.StudsToKmh
    if currentKmh<Config.MinCurrentKmh then return end
    local diff=targetKmh-currentKmh
    if math.abs(diff)<Config.HysteresisKmh then State.SpeedCurrentKmh=currentKmh; return end
    local rate=(diff>0) and Config.AccelRate or Config.DecelRate
    local proximity=1-math.clamp(math.abs(diff)/targetKmh,0,1)
    local easedRate=math.max(rate*ease(proximity), rate*0.2)
    local deltaKmh=math.clamp(diff*easedRate, -Config.MaxDeltaKmhPerFrame, Config.MaxDeltaKmhPerFrame)
    local deltaStuds=deltaKmh/Config.StudsToKmh
    local newMag=mag+deltaStuds
    if diff>0 and newMag*Config.StudsToKmh>targetKmh then newMag=targetKmh/Config.StudsToKmh
    elseif diff<0 and newMag*Config.StudsToKmh<targetKmh then newMag=targetKmh/Config.StudsToKmh end
    root.AssemblyLinearVelocity=vel.Unit*newMag
    State.SpeedCurrentKmh=newMag*Config.StudsToKmh
end))

track(RunService.Stepped:Connect(function()
    if not Config.NoDrag then return end
    local root=State.VehicleRoot
    if root and root.Parent then root.CustomPhysicalProperties=PhysicalProperties.new(0.01,0,0) end
end))

-- ============================================================
-- ESP / LIGHTING / CAMERA / WIN / AFK
-- ============================================================
local function clearESP()
    for _,o in pairs(State.ESPObjects) do if o and o.Parent then o:Destroy() end end
    table.clear(State.ESPObjects)
end
local function addESP(plr)
    if plr==LP then return end
    local char=plr.Character; if not char then return end
    local hrp=char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    local box=Instance.new("BoxHandleAdornment")
    box.Name="DDS_ESP_"..plr.Name; box.Adornee=hrp; box.AlwaysOnTop=true; box.ZIndex=5
    box.Size=hrp.Size+Vector3.new(0.4,0.4,0.4); box.Color3=Config.ESPColor; box.Transparency=0.35
    box.Parent=hrp; State.ESPObjects[plr]=box
end
track(RunService.RenderStepped:Connect(function()
    if not Config.ESP then return end
    for _,p in ipairs(Players:GetPlayers()) do if p~=LP and not State.ESPObjects[p] then addESP(p) end end
end))
track(Players.PlayerRemoving:Connect(function(p)
    local box=State.ESPObjects[p]; if box and box.Parent then box:Destroy() end
    State.ESPObjects[p]=nil
end))
track(RunService.RenderStepped:Connect(function()
    if Config.Fullbright then
        Lighting.Ambient=Color3.fromRGB(180,180,180)
        Lighting.OutdoorAmbient=Color3.fromRGB(180,180,180)
        Lighting.Brightness=3; Lighting.ClockTime=14
    end
    if Config.NoFog then Lighting.FogEnd=1e9; Lighting.FogStart=1e9 end
    Camera.FieldOfView=Config.FOV
end))
local function nearestDragNpc()
    local root=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local best, bestD = nil, math.huge
    for _,obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChild("Humanoid") and obj.Name:lower():find("drag") then
            local hrp=obj:FindFirstChild("HumanoidRootPart")
            if hrp then local d=(hrp.Position-root.Position).Magnitude if d<bestD then bestD,best=d,hrp end end
        end
    end
    return best
end
track(RunService.RenderStepped:Connect(function()
    if not Config.CameraLock then return end
    local t=nearestDragNpc()
    if t then Camera.CFrame=CFrame.lookAt(Camera.CFrame.Position,t.Position) end
end))
track(RunService.Heartbeat:Connect(function()
    if not Config.AutoWin then return end
    for _,ev in ipairs(ReplicatedStorage:GetDescendants()) do
        if ev:IsA("RemoteEvent") then
            local n=ev.Name:lower()
            if n:find("finish") or n:find("win") or n:find("reward") then pcall(function() ev:FireServer() end) end
        end
    end
end))
track(LP.Idled:Connect(function()
    if not Config.AntiAFK then return end
    VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new())
end))

-- ============================================================
-- AUTOFARM
-- ============================================================
local JOB_KEYWORDS={
    courier={"courier","package","delivery","kurir","paket"},
    barista={"barista","coffee","cafe","kopi","coffeeshop"},
    office ={"office","kantor","desk","receptionist","resepsionis","admin","computer","komputer"},
}
local function getSearchRoots()
    if not Config.ScanAllMaps then return {Workspace} end
    local roots={Workspace}
    for _,d in ipairs(Workspace:GetChildren()) do
        if d:IsA("Folder") or d:IsA("Model") then
            local n=d.Name:lower()
            if n:find("map") or n:find("surakarta") or n:find("gatsu") or n:find("world") then
                table.insert(roots,d)
            end
        end
    end
    return roots
end
local function findFarmTarget(job)
    local char=LP.Character; local hrp=char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local keywords=JOB_KEYWORDS[job]; if not keywords then return nil end
    local best, bestD = nil, Config.FarmRadius
    for _,root in ipairs(getSearchRoots()) do
        for _,obj in ipairs(root:GetDescendants()) do
            if obj:IsA("Model") then
                local n=obj.Name:lower(); local matched=false
                for _,kw in ipairs(keywords) do if n:find(kw) then matched=true break end end
                if matched then
                    local hrpNpc=obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart
                    if hrpNpc then local d=(hrpNpc.Position-hrp.Position).Magnitude if d<bestD then bestD,best=d,hrpNpc end end
                end
            end
        end
    end
    return best
end
local function teleportNear(target)
    local char=LP.Character; local hrp=char and char:FindFirstChild("HumanoidRootPart")
    if not hrp or not target then return false end
    hrp.CFrame=CFrame.new(target.Position+Config.TeleportOffset); return true
end
local function farmOne(job)
    local target=findFarmTarget(job); if not target then return false end
    if Config.TeleportFarm then teleportNear(target) end
    task.wait(0.08)
    local btn=findInteractButton()
    if btn then tapButton(btn,0.1)
    else
        local char=LP.Character; local hrp=char and char:FindFirstChild("HumanoidRootPart")
        if hrp and (target.Position-hrp.Position).Magnitude<10 then
            local pp=target.Parent and target.Parent:FindFirstChildWhichIsA("ProximityPrompt", true)
            if pp then pcall(function() fireproximityprompt(pp) end) end
        end
    end
    return true
end
track(RunService.Heartbeat:Connect(function()
    if os.clock()-State.LastFarm<Config.FarmInterval then return end
    local anyJob=Config.AutoCourier or Config.AutoBarista or Config.AutoOffice or Config.FarmQueueMode
    if not anyJob then return end
    if Config.FarmQueueMode then
        local job=State.FarmQueue[State.FarmQueueIdx]
        if farmOne(job) then
            State.LastFarm=os.clock(); State.FarmQueueIdx=State.FarmQueueIdx+1
            if State.FarmQueueIdx>#State.FarmQueue then State.FarmQueueIdx=1 end
        end
    else
        local job=nil
        if Config.AutoCourier then job="courier"
        elseif Config.AutoBarista then job="barista"
        elseif Config.AutoOffice then job="office" end
        if job and farmOne(job) then State.LastFarm=os.clock() end
    end
end))

-- ============================================================
-- AUTOUPGRADE / REDEEM
-- ============================================================
track(RunService.Heartbeat:Connect(function()
    if not Config.AutoUpgrade then return end
    if os.clock()-State.LastUpgrade<Config.UpgradeCheck then return end
    State.LastUpgrade=os.clock(); if State.UpgradeBusy then return end
    local prioMap={}
    for i,p in ipairs(Config.UpgradePriority) do prioMap[p:lower()]=i end
    local candidates={}
    for _,g in ipairs(PlayerGui:GetDescendants()) do
        if g:IsA("GuiButton") and g.Visible and g.Active then
            local n=(g.Name.." "..(g:IsA("TextButton") and g.Text or "")):lower()
            if n:find("buy") or n:find("upgrade") or n:find("beli") then
                for _,part in ipairs(Config.UpgradePriority) do
                    if n:find(part:lower()) then table.insert(candidates,{btn=g,rank=prioMap[part:lower()]}); break end
                end
            end
        end
    end
    if #candidates==0 then return end
    table.sort(candidates, function(a,b) return a.rank<b.rank end)
    State.UpgradeBusy=true
    pcall(function() tapButton(candidates[1].btn,0.1) end)
    task.wait(0.3); State.UpgradeBusy=false
end))
local function redeemOne()
    if State.RedeemIndex>#Config.RedeemCodes then State.RedeemIndex=1 return end
    local shopBtn=findShopButton(); if shopBtn then tapButton(shopBtn,0.1) end
    task.wait(0.3)
    local input=findRedeemInput()
    if input and input:IsA("TextBox") then
        input.Text=Config.RedeemCodes[State.RedeemIndex]
        input:CaptureFocus(); task.wait(0.1); input:ReleaseFocus(true)
    end
    task.wait(0.2)
    local redeemBtn=findRedeemButton(); if redeemBtn then tapButton(redeemBtn,0.1) end
    State.RedeemIndex=State.RedeemIndex+1
end
track(RunService.Heartbeat:Connect(function()
    if not Config.AutoRedeem then return end
    if os.clock()-State.LastRedeem<Config.RedeemInterval then return end
    State.LastRedeem=os.clock(); if State.RedeemBusy then return end
    State.RedeemBusy=true; pcall(redeemOne); task.wait(0.3); State.RedeemBusy=false
end))

-- ============================================================
-- MATH SOLVER
-- ============================================================
local OP_MAP={["×"]="*",["x"]="*",["X"]="*",["÷"]="/",["−"]="-",["–"]="-",["—"]="-",["％"]="%",["²"]="^2",["³"]="^3"}
local function normalize(text)
    if not text or text=="" then return "" end
    local s=text:gsub("%s+"," ")
    for f,t in pairs(OP_MAP) do s=s:gsub(f,t) end
    return s
end
local function extractExpression(text)
    local s=normalize(text); if s=="" then return nil end
    local eq=s:match("([%d%.]+[%s]?[%+%-%*/%%%^][%s]?[%d%.]+[%s%+%-%*/%%%^%d%.]*)[%s]*=[%s]*[%?]?")
    if eq then local c=eq:gsub("[^%d%+%-%*/%%%^%.]","") if c:find("%d") then return c end end
    local brp=s:match("[Bb]erapa%s+([%d%.]+[%s%+%-%*/%%%^]+[%d%.]+)")
    if brp then local c=brp:gsub("[^%d%+%-%*/%%%^%.]","") if #c>0 then return c end end
    local pl=s:match("([%d%.]+[%s%+%-%*/%%%^]+[%d%.]+)")
    if pl then local c=pl:gsub("[^%d%+%-%*/%%%^%.]","") if #c>0 then return c end end
    return nil
end
local function evalExpression(expr)
    if not expr or expr=="" then return nil end
    local tokens,i={},1
    while i<=#expr do
        local c=expr:sub(i,i)
        if c:match("%d") or c=="." then
            local num=expr:match("^[%d%.]+",i); table.insert(tokens,tonumber(num)); i=i+#num
        elseif c:match("[%+%-%*/%%%^]") then table.insert(tokens,c); i=i+1
        elseif c==" " then i=i+1 else return nil end
    end
    if #tokens<3 then return nil end
    local prec={["+"]=1,["-"]=1,["*"]=2,["/"]=2,["%"]=2,["^"]=3}
    local rightAssoc={["^"]=true}
    local output,ops={},{}
    for _,t in ipairs(tokens) do
        if type(t)=="number" then table.insert(output,t)
        elseif prec[t] then
            while #ops>0 do
                local top=ops[#ops]
                if prec[top] and (prec[top]>prec[t] or (prec[top]==prec[t] and not rightAssoc[t])) then
                    table.insert(output,table.remove(ops))
                else break end
            end
            table.insert(ops,t)
        end
    end
    while #ops>0 do table.insert(output,table.remove(ops)) end
    local stack={}
    for _,tok in ipairs(output) do
        if type(tok)=="number" then table.insert(stack,tok) else
            if #stack<2 then return nil end
            local b=table.remove(stack); local a=table.remove(stack); local r
            if tok=="+" then r=a+b elseif tok=="-" then r=a-b elseif tok=="*" then r=a*b
            elseif tok=="/" then if b==0 then return nil end r=a/b
            elseif tok=="%" then if b==0 then return nil end r=a%b
            elseif tok=="^" then r=a^b end
            if not r then return nil end; table.insert(stack,r)
        end
    end
    if #stack~=1 then return nil end
    return stack[1]
end
local function formatResult(n)
    if math.abs(n-math.floor(n+0.5))<0.001 then return tostring(math.floor(n+0.5)) end
    return string.format("%.2f",n)
end
local function scanForQuestion()
    local out={}
    for _,g in ipairs(PlayerGui:GetDescendants()) do
        if g:IsA("TextLabel") and g.Visible and g.Text and g.Text~="" then
            local text=g.Text
            if text:find("%d") and (text:find("[%+%-%*/]") or text:lower():find("berapa") or text:lower():find("what")) then
                local expr=extractExpression(text)
                if expr then local ans=evalExpression(expr) if ans then table.insert(out,{text=text,expr=expr,answer=ans}) end end
            end
        end
    end
    return out
end
local function findAnswerInput()
    for _,g in ipairs(PlayerGui:GetDescendants()) do
        if g:IsA("TextBox") and g.Visible and g.TextEditable and g:IsFocused() then return g end
    end
    for _,g in ipairs(PlayerGui:GetDescendants()) do
        if g:IsA("TextBox") and g.Visible and g.TextEditable then return g end
    end
    return nil
end
local function fillTextBox(tb, text)
    if not tb then return false end
    return pcall(function()
        tb:CaptureFocus(); task.wait(0.05); tb.Text=text; task.wait(0.05); tb:ReleaseFocus(true)
    end)
end
local function mathTick()
    if not Config.MathSolver then return end
    if os.clock()-State.LastMath<Config.MathInterval then return end
    State.LastMath=os.clock(); if State.MathBusy then return end
    local candidates=scanForQuestion(); if #candidates==0 then return end
    local target=nil
    for _,c in ipairs(candidates) do if c.text~=State.MathLastQ then target=c break end end
    if not target then return end
    State.MathBusy=true; State.MathLastQ=target.text
    local input=findAnswerInput()
    if not input then State.MathFail=State.MathFail+1; State.MathBusy=false; return end
    fillTextBox(input, formatResult(target.answer)); task.wait(0.1)
    if Config.MathSubmit then
        local submit=findSubmitButton()
        if submit then tapButton(submit,0.05)
        else
            VIM:SendKeyEvent(true, Enum.KeyCode.Return, false, game); task.wait(0.03)
            VIM:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
        end
    end
    State.MathOK=State.MathOK+1; task.wait(0.3); State.MathBusy=false
end
track(RunService.Heartbeat:Connect(mathTick))

task.spawn(function()
    while task.wait(2.0) do
        if Config.GearProbe and State.Ready and #State.GearValues>0 then
            local msg="[BETA Gear] "
            for _,g in ipairs(State.GearValues) do msg=msg..g.name.."="..tostring(g.value).." " end
            warn(msg)
        end
        if Config.WheelieProbe and State.Ready then
            local msg="[BETA Wheelie] "
            for _,w in ipairs(State.WheelieValues) do msg=msg..w.name.."="..tostring(w.value).." " end
            if #State.WheelieValues==0 then msg=msg.."none" end
            warn(msg)
        end
    end
end)

-- ============================================================
-- UI HOST RESOLVER
-- ============================================================
local function resolveGuiHost()
    local candidates = {}
    pcall(function()
        if gethui then
            local h = gethui()
            if h then table.insert(candidates, {name="gethui()", host=h}) end
        end
    end)
    pcall(function()
        local cg = game:GetService("CoreGui")
        if cg then table.insert(candidates, {name="CoreGui", host=cg}) end
    end)
    local pg = LP:FindFirstChild("PlayerGui") or LP:WaitForChild("PlayerGui", 3)
    if pg then table.insert(candidates, {name="PlayerGui", host=pg}) end
    table.insert(candidates, {name="Workspace", host=Workspace})
    for _, c in ipairs(candidates) do
        local ok = pcall(function()
            local test = Instance.new("ScreenGui")
            test.Name = "_DDS_Test_" .. tick()
            test.ResetOnSpawn = false
            test.Parent = c.host
            if not test.Parent then error("nil") end
            task.wait(0.05)
            test:Destroy()
        end)
        if ok then
            warn("[DDS] GUI host resolved: " .. c.name)
            return c.host
        else
            warn("[DDS] GUI host failed: " .. c.name)
        end
    end
    return pg
end

local GuiHost = resolveGuiHost()

local function waitCameraReady()
    local start = os.clock()
    while os.clock() - start < 5 do
        local cam = Workspace.CurrentCamera
        if cam and cam.ViewportSize.X > 0 and cam.ViewportSize.Y > 0 then
            warn(string.format("[DDS] Camera ready: %dx%d", cam.ViewportSize.X, cam.ViewportSize.Y))
            return true
        end
        task.wait(0.1)
    end
    warn("[DDS] Camera timeout, proceeding anyway")
    return false
end
waitCameraReady()

-- ============================================================
-- UI THEME & HELPERS
-- ============================================================
local THEME = {
    bg=Color3.fromRGB(18,20,26), bgLight=Color3.fromRGB(28,30,38), bgRow=Color3.fromRGB(32,34,44),
    accent=Color3.fromRGB(0,220,160), accentDim=Color3.fromRGB(0,140,100),
    accentBeta=Color3.fromRGB(255,160,60), accentBetaDim=Color3.fromRGB(100,60,20),
    text=Color3.fromRGB(230,232,240), textDim=Color3.fromRGB(150,155,170),
    stroke=Color3.fromRGB(0,200,140), danger=Color3.fromRGB(180,50,60),
}
local TAB_META={
    DRIVE={label="DRIVE",icon="⚡"}, VISUAL={label="VISUAL",icon="👁"},
    FARM={label="FARM",icon="⛏"}, SHOP={label="SHOP",icon="🛒"}, BETA={label="BETA",icon="⚠"},
}
local function getViewport()
    local vp=Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize
    if not vp or vp.X==0 then return Vector2.new(800,450) end
    return vp
end
local function getSafeArea()
    local top,bottom=0,16
    pcall(function() top=GuiService:GetGuiInset().Y end)
    return {top=top,bottom=bottom}
end
local function makeCorner(p,r)
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,r or 8); c.Parent=p; return c
end
local function makeStroke(p,col,th,tr)
    local s=Instance.new("UIStroke"); s.Color=col or THEME.stroke
    s.Thickness=th or 1; s.Transparency=tr or 0.5; s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
    s.Parent=p; return s
end
local function makeGradient(p,c1,c2)
    local g=Instance.new("UIGradient"); g.Color=ColorSequence.new(c1,c2); g.Rotation=90; g.Parent=p; return g
end

-- ============================================================
-- UI COMPONENTS
-- ============================================================
local function createToggleSwitch(parent,key,label,order,callback,isBeta)
    local row=Instance.new("Frame")
    row.Size=UDim2.new(1,0,0,40)
    row.BackgroundColor3=THEME.bgRow; row.BackgroundTransparency=0.15
    row.BorderSizePixel=0; row.LayoutOrder=order; row.Parent=parent
    row:SetAttribute("IsToggleRow",true)
    makeCorner(row,10)
    makeStroke(row, isBeta and THEME.accentBetaDim or THEME.bgLight,1,0.7)
    local lbl=Instance.new("TextLabel")
    lbl.Size=UDim2.new(1,-70,1,0); lbl.Position=UDim2.new(0,12,0,0)
    lbl.BackgroundTransparency=1; lbl.TextColor3=THEME.text
    lbl.Font=Enum.Font.GothamMedium; lbl.TextSize=12
    lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.TextTruncate=Enum.TextTruncate.AtEnd
    lbl.Text=(isBeta and "⚠ " or "")..label; lbl.Parent=row
    row:SetAttribute("Label", lbl)
    local track2=Instance.new("Frame")
    track2.Size=UDim2.new(0,40,0,20); track2.Position=UDim2.new(1,-52,0.5,-10)
    track2.BackgroundColor3=Color3.fromRGB(60,62,72); track2.BorderSizePixel=0; track2.Parent=row
    makeCorner(track2,10)
    local trackGrad=makeGradient(track2,Color3.fromRGB(50,52,62),Color3.fromRGB(70,72,84))
    local knob=Instance.new("Frame")
    knob.Size=UDim2.new(0,16,0,16); knob.Position=UDim2.new(0,2,0.5,-8)
    knob.BackgroundColor3=Color3.fromRGB(220,222,230); knob.BorderSizePixel=0; knob.Parent=track2
    makeCorner(knob,8)
    local click=Instance.new("TextButton")
    click.Size=UDim2.new(1,0,1,0); click.BackgroundTransparency=1; click.Text=""; click.Parent=row
    track(click.MouseButton1Click:Connect(function()
        Config[key]=not Config[key]; local on=Config[key]
        TweenService:Create(track2,TweenInfo.new(0.18,Enum.EasingStyle.Quad),{
            BackgroundColor3=on and THEME.accentDim or Color3.fromRGB(60,62,72)}):Play()
        TweenService:Create(knob,TweenInfo.new(0.18,Enum.EasingStyle.Quad),{
            Position=on and UDim2.new(1,-18,0.5,-8) or UDim2.new(0,2,0.5,-8)}):Play()
        if on then trackGrad.Color=ColorSequence.new(THEME.accentDim,THEME.accent)
        else trackGrad.Color=ColorSequence.new(Color3.fromRGB(50,52,62),Color3.fromRGB(70,72,84)) end
        if callback then callback(on) end
    end))
    return row
end

local function createDragSlider(parent,key,label,min,max,step,order,suffix)
    suffix=suffix or ""
    local row=Instance.new("Frame")
    row.Size=UDim2.new(1,0,0,56)
    row.BackgroundColor3=THEME.bgRow; row.BackgroundTransparency=0.15
    row.BorderSizePixel=0; row.LayoutOrder=order; row.Parent=parent
    row:SetAttribute("IsSliderRow",true)
    makeCorner(row,10); makeStroke(row,THEME.bgLight,1,0.7)
    local lbl=Instance.new("TextLabel")
    lbl.Size=UDim2.new(1,-60,0,20); lbl.Position=UDim2.new(0,12,0,6)
    lbl.BackgroundTransparency=1; lbl.TextColor3=THEME.textDim
    lbl.Font=Enum.Font.Gotham; lbl.TextSize=11
    lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Text=label; lbl.Parent=row
    row:SetAttribute("Label", lbl)
    local val=Instance.new("TextLabel")
    val.Size=UDim2.new(0,60,0,20); val.Position=UDim2.new(1,-72,0,6)
    val.BackgroundTransparency=1; val.TextColor3=THEME.accent
    val.Font=Enum.Font.GothamBold; val.TextSize=12
    val.TextXAlignment=Enum.TextXAlignment.Right
    val.Text=string.format("%.2f",Config[key])..suffix; val.Parent=row
    local trackBg=Instance.new("Frame")
    trackBg.Size=UDim2.new(1,-24,0,6); trackBg.Position=UDim2.new(0,12,0,34)
    trackBg.BackgroundColor3=Color3.fromRGB(50,52,62); trackBg.BorderSizePixel=0; trackBg.Parent=row
    makeCorner(trackBg,3)
    local fill=Instance.new("Frame")
    fill.Size=UDim2.new((Config[key]-min)/(max-min),0,1,0)
    fill.BackgroundColor3=THEME.accent; fill.BorderSizePixel=0; fill.Parent=trackBg
    makeCorner(fill,3); makeGradient(fill,THEME.accentDim,THEME.accent)
    local knob=Instance.new("Frame")
    knob.Size=UDim2.new(0,14,0,14)
    knob.Position=UDim2.new((Config[key]-min)/(max-min),-7,0.5,-7)
    knob.BackgroundColor3=Color3.fromRGB(240,242,248); knob.BorderSizePixel=0; knob.Parent=trackBg
    makeCorner(knob,7); makeStroke(knob,THEME.accent,2,0)
    local function setFromX(absX)
        local trackAbsX=trackBg.AbsolutePosition.X
        local trackW=trackBg.AbsoluteSize.X
        if trackW<=0 then return end
        local ratio=math.clamp((absX-trackAbsX)/trackW,0,1)
        local raw=min+ratio*(max-min)
        local snapped=math.floor(raw/step+0.5)*step
        Config[key]=math.clamp(snapped,min,max)
        local r=(Config[key]-min)/(max-min)
        fill.Size=UDim2.new(r,0,1,0); knob.Position=UDim2.new(r,-7,0.5,-7)
        val.Text=string.format("%.2f",Config[key])..suffix
    end
    local dragging=false
    local click=Instance.new("TextButton")
    click.Size=UDim2.new(1,0,0,40); click.Position=UDim2.new(0,0,0,16)
    click.BackgroundTransparency=1; click.Text=""; click.Parent=row
    track(click.MouseButton1Down:Connect(function(x) dragging=true; setFromX(x) end))
    track(UserInput.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType==Enum.UserInputType.MouseMovement
           or input.UserInputType==Enum.UserInputType.MouseButton1
           or input.UserInputType==Enum.UserInputType.Touch then
            setFromX(input.Position.X)
        end
    end))
    track(UserInput.InputEnded:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            dragging=false
        end
    end))
    track(click.MouseMoved:Connect(function(x) if dragging then setFromX(x) end end))
    return row
end

-- ============================================================
-- BUILD UI
-- ============================================================
local function buildUI()
    pcall(function()
        for _, old in ipairs(GuiHost:GetChildren()) do
            if old.Name:sub(1, 4) == "DDS_" then old:Destroy() end
        end
    end)
    local vp = getViewport()
    warn(string.format("[DDS] Building UI. Viewport: %dx%d. Host: %s", vp.X, vp.Y, tostring(GuiHost)))

    local sg = Instance.new("ScreenGui")
    sg.Name="DDS_v20"; sg.ResetOnSpawn=false; sg.IgnoreGuiInset=true
    sg.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; sg.DisplayOrder=9999
    sg.Enabled=true; sg.Parent=GuiHost
    if not sg.Parent then
        warn("[DDS] ScreenGui.Parent nil — fallback to PlayerGui")
        local fb = LP:FindFirstChild("PlayerGui")
        if fb then sg.Parent = fb; GuiHost = fb else return end
    end
    task.wait(0.1)
    if not sg.Parent then warn("[DDS] ScreenGui hilang setelah 1 frame — abort") return end
    State.UI.Gui = sg

    -- FAB dulu (fallback jika panel gagal)
    local fab=Instance.new("TextButton")
    fab.Name="DDS_FAB"
    fab.Size=UDim2.new(0,56,0,56); fab.Position=UDim2.new(0,20,0,100)
    fab.BackgroundColor3=THEME.accentDim; fab.BorderSizePixel=0
    fab.Text="⚡"; fab.TextColor3=Color3.fromRGB(255,255,255)
    fab.Font=Enum.Font.GothamBold; fab.TextSize=22; fab.ZIndex=100
    fab.Visible=true; fab.Parent=sg
    makeCorner(fab,28)
    local fabStroke=makeStroke(fab,THEME.accent,2,0.3)
    makeGradient(fab,THEME.accentDim,THEME.accent)

    local shadow=Instance.new("Frame")
    shadow.Name="DDS_Shadow"
    shadow.BackgroundColor3=Color3.fromRGB(0,0,0); shadow.BackgroundTransparency=0.6
    shadow.BorderSizePixel=0; shadow.ZIndex=0
    shadow.Size=UDim2.new(0,328,0,488); shadow.Position=UDim2.new(0,12,0.5,-244)
    shadow.Visible=false; shadow.Parent=sg
    makeCorner(shadow,16)

    local main=Instance.new("Frame")
    main.Name="DDS_MainPanel"
    main.AnchorPoint=Vector2.new(0,0.5); main.Position=UDim2.new(0,16,0.5,0)
    main.Size=UDim2.new(0,320,0,480)
    main.BackgroundColor3=THEME.bg; main.BackgroundTransparency=0.05
    main.BorderSizePixel=0; main.Active=true; main.Draggable=true
    main.ZIndex=1; main.Visible=false; main.Parent=sg
    makeCorner(main,14); makeStroke(main,THEME.stroke,1.5,0.4)
    makeGradient(main,Color3.fromRGB(22,24,32),Color3.fromRGB(14,16,22))

    local accentBar=Instance.new("Frame")
    accentBar.Size=UDim2.new(0,3,1,-20); accentBar.Position=UDim2.new(0,0,0,10)
    accentBar.BackgroundColor3=THEME.accent; accentBar.BorderSizePixel=0
    accentBar.ZIndex=2; accentBar.Parent=main
    makeCorner(accentBar,2); makeGradient(accentBar,THEME.accent,THEME.accentDim)

    local header=Instance.new("Frame")
    header.Size=UDim2.new(1,-8,0,40); header.Position=UDim2.new(0,6,0,0)
    header.BackgroundTransparency=1; header.ZIndex=3; header.Parent=main

    local titleDot=Instance.new("Frame")
    titleDot.Size=UDim2.new(0,8,0,8); titleDot.Position=UDim2.new(0,14,0.5,-4)
    titleDot.BackgroundColor3=THEME.accent; titleDot.BorderSizePixel=0; titleDot.Parent=header
    makeCorner(titleDot,4)

    local title=Instance.new("TextLabel")
    title.Size=UDim2.new(1,-100,1,0); title.Position=UDim2.new(0,28,0,0)
    title.BackgroundTransparency=1; title.TextColor3=THEME.text
    title.Font=Enum.Font.GothamBold; title.TextSize=13
    title.TextXAlignment=Enum.TextXAlignment.Left; title.Text="DDS v2.0"; title.Parent=header

    local badge=Instance.new("TextLabel")
    badge.Size=UDim2.new(0,52,0,18); badge.Position=UDim2.new(1,-90,0.5,-9)
    badge.BackgroundColor3=THEME.accentDim; badge.BackgroundTransparency=0.4
    badge.BorderSizePixel=0; badge.TextColor3=THEME.accent
    badge.Font=Enum.Font.GothamBold; badge.TextSize=9; badge.Text="V1.1.9"; badge.Parent=header
    makeCorner(badge,4)

    local closeBtn=Instance.new("TextButton")
    closeBtn.Size=UDim2.new(0,26,0,26); closeBtn.Position=UDim2.new(1,-32,0.5,-13)
    closeBtn.BackgroundColor3=THEME.danger; closeBtn.BackgroundTransparency=0.2
    closeBtn.BorderSizePixel=0; closeBtn.Text="×"; closeBtn.TextColor3=Color3.fromRGB(255,255,255)
    closeBtn.Font=Enum.Font.GothamBold; closeBtn.TextSize=16; closeBtn.Parent=header
    makeCorner(closeBtn,6)
    track(closeBtn.MouseButton1Click:Connect(function()
        main.Visible=not main.Visible; shadow.Visible=main.Visible
    end))

    local contentArea=Instance.new("Frame")
    contentArea.Size=UDim2.new(1,-12,1,-100); contentArea.Position=UDim2.new(0,6,0,42)
    contentArea.BackgroundTransparency=1; contentArea.ZIndex=2
    contentArea.ClipsDescendants=true; contentArea.Parent=main

    local pages={}
    local tabNames={"DRIVE","VISUAL","FARM","SHOP","BETA"}
    local function selectTab(name)
        for n,pg in pairs(pages) do pg.Visible=(n==name) end
        local bar=State.UI.TabBar
        if bar then
            for _,c in ipairs(bar:GetChildren()) do
                if c:IsA("TextButton") and c:GetAttribute("IsTab") then
                    local active=(c.Name==name); local beta=(c.Name=="BETA")
                    c.BackgroundColor3=active and (beta and THEME.accentBetaDim or THEME.accentDim) or THEME.bgLight
                    c.BackgroundTransparency=active and 0.1 or 0.4
                    local lbl=c:FindFirstChild("TabLabel")
                    if lbl then lbl.TextColor3=active and (beta and THEME.accentBeta or THEME.accent) or THEME.textDim end
                end
            end
        end
    end
    State.UI.SelectTab=selectTab

    local function makePage(name)
        local sf=Instance.new("ScrollingFrame")
        sf.Name=name; sf.Size=UDim2.new(1,0,1,0)
        sf.BackgroundTransparency=1; sf.BorderSizePixel=0
        sf.ScrollBarThickness=2; sf.ScrollBarImageColor3=THEME.accent; sf.ScrollBarImageTransparency=0.6
        sf.AutomaticCanvasSize=Enum.AutomaticSize.Y; sf.CanvasSize=UDim2.new(0,0,0,0)
        sf.ScrollingDirection=Enum.ScrollingDirection.Y; sf.Visible=false; sf.ZIndex=2; sf.Parent=contentArea
        local pad=Instance.new("UIPadding")
        pad.PaddingLeft=UDim.new(0,10); pad.PaddingRight=UDim.new(0,10)
        pad.PaddingTop=UDim.new(0,4); pad.PaddingBottom=UDim.new(0,4); pad.Parent=sf
        local ll=Instance.new("UIListLayout")
        ll.Padding=UDim.new(0,5); ll.SortOrder=Enum.SortOrder.LayoutOrder; ll.Parent=sf
        pages[name]=sf; return sf
    end
    for _,name in ipairs(tabNames) do makePage(name) end

    local tabBar=Instance.new("Frame")
    tabBar.Name="TabBar"; tabBar.Size=UDim2.new(1,-16,0,42)
    tabBar.Position=UDim2.new(0,8,1,-48)
    tabBar.BackgroundColor3=THEME.bgLight; tabBar.BackgroundTransparency=0.2
    tabBar.BorderSizePixel=0; tabBar.ZIndex=3; tabBar.Parent=main
    State.UI.TabBar=tabBar
    makeCorner(tabBar,12); makeStroke(tabBar,THEME.bgLight,1,0.5)
    local tabLayout=Instance.new("UIListLayout")
    tabLayout.FillDirection=Enum.FillDirection.Horizontal
    tabLayout.HorizontalAlignment=Enum.HorizontalAlignment.Center
    tabLayout.VerticalAlignment=Enum.VerticalAlignment.Center
    tabLayout.Padding=UDim.new(0,4); tabLayout.Parent=tabBar

    for _,name in ipairs(tabNames) do
        local meta=TAB_META[name]
        local tb=Instance.new("TextButton")
        tb.Name=name; tb.Size=UDim2.new(0,52,0,36)
        tb.BackgroundColor3=THEME.bgLight; tb.BackgroundTransparency=0.4
        tb.BorderSizePixel=0; tb.Text=""; tb.AutoButtonColor=false; tb.Parent=tabBar
        tb:SetAttribute("IsTab",true); makeCorner(tb,8)
        local icon=Instance.new("TextLabel")
        icon.Size=UDim2.new(1,0,0,16); icon.Position=UDim2.new(0,0,0,3)
        icon.BackgroundTransparency=1; icon.Text=meta.icon
        icon.TextColor3=THEME.text; icon.Font=Enum.Font.GothamBold; icon.TextSize=12; icon.Parent=tb
        local lbl=Instance.new("TextLabel")
        lbl.Name="TabLabel"; lbl.Size=UDim2.new(1,0,0,12); lbl.Position=UDim2.new(0,0,0,20)
        lbl.BackgroundTransparency=1; lbl.Text=meta.label
        lbl.TextColor3=THEME.textDim; lbl.Font=Enum.Font.GothamBold; lbl.TextSize=8; lbl.Parent=tb
        track(tb.MouseButton1Click:Connect(function() selectTab(name) end))
    end

    local function applyLayout()
        local vp2=getViewport(); local sa=getSafeArea()
        local vw=vp2.X; local vh=vp2.Y-sa.top-sa.bottom
        local panelW=math.min(320,vw-32)
        local panelH=math.max(260,math.min(480,vh-24))
        main.Size=UDim2.new(0,panelW,0,panelH)
        shadow.Size=UDim2.new(0,panelW+8,0,panelH+8)
        shadow.Position=UDim2.new(0,12,0.5,-panelH/2-4)
        contentArea.Size=UDim2.new(1,-12,1,-100)
        contentArea.Position=UDim2.new(0,6,0,42)
        local compact=vh<400
        local toggleH = compact and 34 or 40
        local sliderH = compact and 50 or 56
        local labelSize = compact and 11 or 12
        local sliderLabelSize = compact and 10 or 11
        for _,item in ipairs(contentArea:GetDescendants()) do
            if item:IsA("Frame") and item:GetAttribute("IsToggleRow") then
                item.Size=UDim2.new(1,0,0,toggleH)
                local lbl=item:GetAttribute("Label")
                if lbl and lbl:IsA("TextLabel") then lbl.TextSize=labelSize end
            elseif item:IsA("Frame") and item:GetAttribute("IsSliderRow") then
                item.Size=UDim2.new(1,0,0,sliderH)
                local lbl=item:GetAttribute("Label")
                if lbl and lbl:IsA("TextLabel") then lbl.TextSize=sliderLabelSize end
            end
        end
    end
    State.UI.ApplyLayout=applyLayout

    -- DRIVE
    local pDrive=pages["DRIVE"]
    createToggleSwitch(pDrive,"PerfectStart","Perfect Start",1)
    createToggleSwitch(pDrive,"UseClutch","Deteksi Clutch",2)
    createToggleSwitch(pDrive,"UseGear1","Deteksi Gear 1",3)
    createToggleSwitch(pDrive,"UseWheelieHold","Wheelie Hold",4,nil,true)
    createToggleSwitch(pDrive,"AutoShift","Auto Shift",5)
    createToggleSwitch(pDrive,"SpeedEnabled","Speed Changer (Target)",6)
    createDragSlider(pDrive,"CarTargetKmh","Mobil Target",40,320,5,7," km/h")
    createDragSlider(pDrive,"BikeTargetKmh","Motor Target",40,320,5,8," km/h")
    createDragSlider(pDrive,"MaxTargetKmh","Max Cap",100,500,10,9," km/h")
    createDragSlider(pDrive,"AccelRate","Akselerasi",0.05,0.30,0.01,10,"")
    createDragSlider(pDrive,"DecelRate","Deselerasi",0.05,0.50,0.01,11,"")
    createDragSlider(pDrive,"HysteresisKmh","Hysteresis",0,10,0.5,12," km/h")
    createToggleSwitch(pDrive,"NoDrag","No Drag",13)

    local info=Instance.new("TextLabel")
    info.Size=UDim2.new(1,0,0,40); info.BackgroundColor3=THEME.bgLight
    info.BackgroundTransparency=0.3; info.BorderSizePixel=0
    info.TextColor3=THEME.accentBeta; info.Font=Enum.Font.Gotham
    info.TextSize=10; info.TextWrapped=true; info.LayoutOrder=99
    info.Text="  Kategori: -"; info.TextXAlignment=Enum.TextXAlignment.Left
    info.Parent=pDrive; makeCorner(info,8); makeStroke(info,THEME.accentBetaDim,1,0.7)
    State.UI.InfoLabel=info

    -- VISUAL
    local pVis=pages["VISUAL"]
    createToggleSwitch(pVis,"ESP","ESP Players",1,function(v) if not v then clearESP() end end)
    createToggleSwitch(pVis,"Fullbright","Fullbright",2,function(v)
        if not v then Lighting.Ambient=Color3.fromRGB(70,70,70); Lighting.OutdoorAmbient=Color3.fromRGB(70,70,70) end
    end)
    createToggleSwitch(pVis,"NoFog","No Fog",3)
    createDragSlider(pVis,"FOV","FOV",40,120,5,4,"")
    createToggleSwitch(pVis,"CameraLock","Camera Lock",5)
    createToggleSwitch(pVis,"AutoWin","Auto Win",6)

    -- FARM
    local pFarm=pages["FARM"]
    createToggleSwitch(pFarm,"AutoOffice","Auto Office",1,function(v) if v then Config.AutoBarista=false; Config.AutoCourier=false; Config.FarmQueueMode=false end end)
    createToggleSwitch(pFarm,"AutoBarista","Auto Barista",2,function(v) if v then Config.AutoOffice=false; Config.AutoCourier=false; Config.FarmQueueMode=false end end)
    createToggleSwitch(pFarm,"AutoCourier","Auto Courier",3,function(v) if v then Config.AutoOffice=false; Config.AutoBarista=false; Config.FarmQueueMode=false end end)
    createToggleSwitch(pFarm,"FarmQueueMode","Farm Queue",4,function(v) if v then Config.AutoOffice=false; Config.AutoBarista=false; Config.AutoCourier=false end end)
    createToggleSwitch(pFarm,"TeleportFarm","Teleport",5)
    createToggleSwitch(pFarm,"ScanAllMaps","Scan All Maps",6)
    createDragSlider(pFarm,"FarmRadius","Scan Radius",20,200,10,7," st")
    createDragSlider(pFarm,"FarmInterval","Interval",0.2,2.0,0.1,8,"s")
    createToggleSwitch(pFarm,"AntiAFK","Anti AFK",9)

    -- SHOP
    local pShop=pages["SHOP"]
    createToggleSwitch(pShop,"AutoUpgrade","Auto Upgrade",1)
    createDragSlider(pShop,"UpgradeCheck","Upgrade Check",1.0,10.0,0.5,2,"s")
    createToggleSwitch(pShop,"AutoRedeem","Auto Redeem Code",3)
    createDragSlider(pShop,"RedeemInterval","Redeem Interval",2.0,15.0,0.5,4,"s")

    -- BETA
    local pBeta=pages["BETA"]
    local notice=Instance.new("TextLabel")
    notice.Size=UDim2.new(1,0,0,46); notice.BackgroundColor3=THEME.accentBetaDim
    notice.BackgroundTransparency=0.3; notice.BorderSizePixel=0
    notice.TextColor3=THEME.accentBeta; notice.Font=Enum.Font.GothamMedium
    notice.TextSize=10; notice.TextWrapped=true; notice.LayoutOrder=0
    notice.Text="  ⚠  BETA — fitur eksperimental. Cek console sebelum lapor bug."
    notice.TextXAlignment=Enum.TextXAlignment.Left; notice.Parent=pBeta
    makeCorner(notice,8); makeStroke(notice,THEME.accentBeta,1,0.6)
    createToggleSwitch(pBeta,"MathSolver","Auto Solve Math",1,nil,true)
    createToggleSwitch(pBeta,"MathSubmit","Auto Submit Answer",2,nil,true)
    createDragSlider(pBeta,"MathInterval","Solve Interval",0.5,5.0,0.1,3,"s")
    local mathStats=Instance.new("TextLabel")
    mathStats.Size=UDim2.new(1,0,0,30); mathStats.BackgroundColor3=THEME.bgLight
    mathStats.BackgroundTransparency=0.3; mathStats.BorderSizePixel=0
    mathStats.TextColor3=THEME.accent; mathStats.Font=Enum.Font.Gotham; mathStats.TextSize=10
    mathStats.TextXAlignment=Enum.TextXAlignment.Left
    mathStats.Text="  OK:0 | Fail:0 — idle"; mathStats.LayoutOrder=4; mathStats.Parent=pBeta
    makeCorner(mathStats,8); State.UI.MathStats=mathStats
    createToggleSwitch(pBeta,"GearProbe","Gear Ratio Probe",5,nil,true)
    createToggleSwitch(pBeta,"WheelieProbe","Wheelie State Probe",6,nil,true)

    applyLayout()
    State.UI.ViewportConn=track(Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(applyLayout))
    track(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        task.wait(0.1); if Workspace.CurrentCamera then applyLayout() end
    end))

    selectTab("DRIVE")
    task.defer(function() task.wait(0.1); selectTab("DRIVE") end)

    -- Verify & force position
    task.wait(0.2)
    local vpCheck=getViewport()
    local mainAbsPos=main.AbsolutePosition; local mainAbsSize=main.AbsoluteSize
    warn(string.format("[DDS] Panel check: pos=(%.0f,%.0f) size=(%.0f,%.0f)",
        mainAbsPos.X, mainAbsPos.Y, mainAbsSize.X, mainAbsSize.Y))
    if mainAbsSize.X<=0 or mainAbsSize.Y<=0 or mainAbsPos.X<-100 or mainAbsPos.Y<-100 then
        warn("[DDS] Panel off-screen or zero, forcing reposition")
        main.AnchorPoint=Vector2.new(0,0)
        main.Position=UDim2.new(0,20,0,80)
        main.Size=UDim2.new(0,320,0,math.min(480,vpCheck.Y-100))
        shadow.AnchorPoint=Vector2.new(0,0)
        shadow.Position=UDim2.new(0,16,0,76)
        shadow.Size=UDim2.new(0,328,0,math.min(488,vpCheck.Y-96))
    end
    main.Visible=true; shadow.Visible=true

    track(fab.MouseButton1Click:Connect(function()
        main.Visible=not main.Visible; shadow.Visible=main.Visible
    end))

    -- Diagnostic
    task.spawn(function()
        task.wait(1)
        warn("[DDS] === DIAGNOSTIC ===")
        warn("[DDS] ScreenGui parent: "..tostring(sg.Parent))
        warn("[DDS] ScreenGui.Enabled: "..tostring(sg.Enabled))
        warn("[DDS] ScreenGui children: "..tostring(#sg:GetChildren()))
        warn("[DDS] Main visible: "..tostring(main.Visible))
        warn("[DDS] Main AbsolutePosition: "..tostring(main.AbsolutePosition))
        warn("[DDS] Main AbsoluteSize: "..tostring(main.AbsoluteSize))
        warn("[DDS] FAB AbsolutePosition: "..tostring(fab.AbsolutePosition))
        warn("[DDS] Viewport: "..tostring(getViewport()))
        warn("[DDS] =================")
    end)
end

task.spawn(function()
    task.wait(3)
    if not State.UI.Gui or not State.UI.Gui.Parent then
        warn("[DDS] Retry: ScreenGui not parented after 3s, rebuild with PlayerGui")
        GuiHost = LP:FindFirstChild("PlayerGui")
        if GuiHost then buildUI() end
    end
    task.wait(1)
    local mainPanel = State.UI.Gui and State.UI.Gui:FindFirstChild("DDS_MainPanel")
    if mainPanel and (not mainPanel.Visible or mainPanel.AbsoluteSize.X <= 0) then
        warn("[DDS] Main panel not visible after build — force reposition")
        mainPanel.AnchorPoint=Vector2.new(0,0)
        mainPanel.Position=UDim2.new(0,20,0,80)
        mainPanel.Size=UDim2.new(0,320,0,400)
        mainPanel.Visible=true
    end
end)

buildUI()

task.spawn(function()
    while task.wait(0.5) do
        if State.UI.MathStats then
            State.UI.MathStats.Text=string.format("  OK:%d | Fail:%d — %s",
                State.MathOK, State.MathFail, Config.MathSolver and "running" or "idle")
        end
        if State.UI.InfoLabel then
            if State.Ready then
                local target=State.IsBike and Config.BikeTargetKmh or Config.CarTargetKmh
                local actual=State.SpeedCurrentKmh or 0
                State.UI.InfoLabel.Text=string.format(
                    "  %s · Target %.0f km/h · Aktual %.0f km/h · Gear:%d",
                    State.IsBike and "MOTOR" or "MOBIL", target, actual, #State.GearValues)
            else
                State.UI.InfoLabel.Text="  Kategori: - (belum duduk)"
            end
        end
    end
end)

LP.CharacterAdded:Connect(function() clearESP() end)
