-- DG Hub v7.3 — Scan & Fix Patch
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local Workspace  = game:GetService("Workspace")
local RS         = game:GetService("ReplicatedStorage")
local Tween      = game:GetService("TweenService")
local LP         = Players.LocalPlayer
local Camera     = Workspace.CurrentCamera
local PGui       = LP:WaitForChild("PlayerGui")

-- [FIX 1] REMOTE SCAN (BUG KRITIS: GetDescendants sering nge-lag/crash)
-- Pakai pcall di setiap remote dan cek method IsA dengan aman.
local Remote = {}
local function scanRemotes()
    local ok, err = pcall(function()
        for _,obj in ipairs(RS:GetDescendants()) do
            if obj and obj:IsA("RemoteEvent") then
                local n = string.lower(obj.Name)
                if n:find("parry") or n:find("block") or n:find("combat") then Remote.Parry = obj end
                if n:find("dodge") or n:find("roll") then Remote.Dodge = obj end
                if n:find("attack") or n:find("swing") or n:find("hit") then Remote.Attack = obj end
                if n:find("buy") or n:find("purchase") then Remote.Buy = obj end
                if n:find("claim") or n:find("reward") then Remote.Claim = obj end
            end
        end
    end)
    if not ok then print("[DG] Remote scan error:", err) end
end
scanRemotes()

local CFG = {
    ESP=false, Nametags=false,
    Aimbot=false, AimbotFOV=120, AimbotSmooth=22,
    AutoParry=false, ParryRange=30, ParryWindow=15,
    AutoDodge=false, GodMode=false, KillAura=false, KillAuraRange=14,
    AntiPosture=false, AutoBuy=false, ClaimRewards=false,
}

local function alive(p) local h=p and p.Character and p.Character:FindFirstChildOfClass("Humanoid"); return h and h.Health>0 end
local function hrp(p) return p and p.Character and p.Character:FindFirstChild("HumanoidRootPart") end
local function enemy(p) if p==LP then return false end local t,mt=p:GetAttribute("Team"),LP:GetAttribute("Team") if t and mt then return t~=mt end return true end

-- [FIX 2] ESP GC (BUG UI: Memory leak tiap pemain keluar)
local espCache={}
local function clearESP(p)
    local d=espCache[p]; if not d then return end
    for k,obj in pairs(d) do if typeof(obj)=="userdata" then pcall(function() obj:Remove() end) end end
    espCache[p]=nil
end
Players.PlayerRemoving:Connect(clearESP)

local function updateESP()
    if not CFG.ESP then return end
    for _,p in ipairs(Players:GetPlayers()) do
        if p==LP then continue end
        local r=hrp(p); local head=p.Character and p.Character:FindFirstChild("Head")
        local hum=p.Character and p.Character:FindFirstChildOfClass("Humanoid")
        if r and head and hum and hum.Health>0 and enemy(p) then
            local hpos,on1=Camera:WorldToViewportPoint(head.Position+Vector3.new(0,0.5,0))
            local rpos,on2=Camera:WorldToViewportPoint(r.Position)
            if on1 and on2 then
                pcall(function()
                    if not espCache[p] then
                        espCache[p]={ box=Drawing.new("Square"), name=Drawing.new("Text"), hp=Drawing.new("Line") }
                        espCache[p].box.Thickness=1; espCache[p].box.Filled=false; espCache[p].box.Color=Color3.fromRGB(255,40,40)
                        espCache[p].name.Size=14; espCache[p].name.Center=true; espCache[p].name.Outline=true; espCache[p].name.Color=Color3.fromRGB(255,255,255)
                        espCache[p].hp.Thickness=2; espCache[p].hp.Color=Color3.fromRGB(0,255,0)
                    end
                    local d=espCache[p]
                    local h=math.abs(hpos.Y-rpos.Y)*1.6; local w=h*0.6
                    d.box.Size=Vector2.new(w,h); d.box.Position=Vector2.new(hpos.X-w/2,hpos.Y); d.box.Visible=true
                    if CFG.Nametags then d.name.Text=string.format("%s [%d]",p.Name,math.floor(hum.Health)); d.name.Position=Vector2.new(hpos.X,hpos.Y-18); d.name.Visible=true else d.name.Visible=false end
                    local pct=hum.Health/hum.MaxHealth
                    d.hp.From=Vector2.new(hpos.X-w/2-6,hpos.Y+h); d.hp.To=Vector2.new(hpos.X-w/2-6,hpos.Y+h-h*pct); d.hp.Visible=true
                end)
            else
                if espCache[p] then pcall(function() espCache[p].box.Visible=false espCache[p].name.Visible=false espCache[p].hp.Visible=false end) end
            end
        else
            if espCache[p] then pcall(function() espCache[p].box.Visible=false espCache[p].name.Visible=false espCache[p].hp.Visible=false end) end
        end
    end
end
local lastESP=0
RunService.RenderStepped:Connect(function()
    if CFG.ESP and tick()-lastESP>0.03 then lastESP=tick(); updateESP() end
end)

-- [FIX 3] AIMBOT (BUG KRITIS: Camera lerp nabrak GUI / lag di HP)
-- Teleport camera dengan aimAlpha agar responsif di frame rate rendah.
local aimTarget
local function closestTarget()
    local best,bestD=nil,math.huge
    local sc=Vector2.new(Camera.ViewportSize.X/2,Camera.ViewportSize.Y/2)
    for _,p in ipairs(Players:GetPlayers()) do
        if p==LP or not alive(p) or not enemy(p) then continue end
        local part=p.Character:FindFirstChild("Head") or p.Character:FindFirstChild("HumanoidRootPart")
        if not part then continue end
        local sp,on=Camera:WorldToViewportPoint(part.Position); if not on then continue end
        local d=(Vector2.new(sp.X,sp.Y)-sc).Magnitude
        if d<CFG.AimbotFOV and d<bestD then bestD=d; best=part end
    end
    return best
end
UIS.InputBegan:Connect(function(i,g) if not g and (i.UserInputType==Enum.UserInputType.MouseButton2 or i.UserInputType==Enum.UserInputType.Touch) and CFG.Aimbot then aimTarget=closestTarget() end end)
UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton2 or i.UserInputType==Enum.UserInputType.Touch then aimTarget=nil end end)
RunService.RenderStepped:Connect(function()
    if CFG.Aimbot and aimTarget and aimTarget.Parent then
        local alpha = math.clamp(CFG.AimbotSmooth, 1, 100) / 100
        Camera.CFrame = Camera.CFrame:Lerp(CFrame.lookAt(Camera.CFrame.Position, aimTarget.Position), alpha)
    end
end)

-- [FIX 4] COMBAT (BUG LOGIC: GetPlayingAnimationTracks sering return track yg udah selesai)
-- Pakai t.IsPlaying dan bypass animasi track yang ga punya TimePosition valid.
local parryCooldown={} local dodgeCooldown={}
local function getMyPos() local my=hrp(LP); return my and my.Position end
local function getEnemyPos(p) local e=hrp(p); return e and e.Position end

RunService.PreSimulation:Connect(function()
    if not CFG.AutoParry and not CFG.AutoDodge then return end
    local myPos = getMyPos(); if not myPos then return end
    for _,p in ipairs(Players:GetPlayers()) do
        if p==LP or not alive(p) or not enemy(p) then continue end
        local ePos = getEnemyPos(p)
        if not ePos or (ePos-myPos).Magnitude > CFG.ParryRange then continue end
        
        local animator = p.Character and p.Character:FindFirstChild("Animator")
        if not animator then continue end
        
        local tracks = animator:GetPlayingAnimationTracks()
        for _,t in ipairs(tracks) do
            if not t.IsPlaying then continue end -- Skip track mati
            local isSwing = math.abs(t.Length-0.933)<0.1 or math.abs(t.Length-1.2)<0.1
            local tName = string.lower(t.Name)
            if tName:find("slash") or tName:find("swing") or tName:find("attack") then isSwing = true end
            
            if isSwing and t.TimePosition > 0 then
                -- Auto Parry Logic
                if CFG.AutoParry and not parryCooldown[p.UserId] then
                    local winStart = t.Length * (CFG.ParryWindow/100)
                    if t.TimePosition >= winStart and t.TimePosition <= winStart + 0.15 then
                        if Remote.Parry then pcall(function() Remote.Parry:FireServer() end) end
                        parryCooldown[p.UserId] = true
                        task.delay(0.5, function() parryCooldown[p.UserId] = nil end)
                    end
                end
                -- Auto Dodge Logic
                if CFG.AutoDodge and not dodgeCooldown[p.UserId] then
                    if t.TimePosition < 0.25 then
                        if Remote.Dodge then pcall(function() Remote.Dodge:FireServer() end) end
                        dodgeCooldown[p.UserId] = true
                        task.delay(0.6, function() dodgeCooldown[p.UserId] = nil end)
                    end
                end
            end
        end
    end
end)

-- [FIX 5] GOD MODE & KILL AURA
local godConn
local function disableGod() if godConn then godConn:Disconnect(); godConn=nil end end
local function enableGod()
    local hum=LP.Character and LP.Character:FindFirstChildOfClass("Humanoid"); if not hum then return end
    hum.Health=hum.MaxHealth; disableGod()
    godConn=hum.HealthChanged:Connect(function(h) if CFG.GodMode and hum.Parent and h<hum.MaxHealth then hum.Health=hum.MaxHealth end end)
end
LP.CharacterAdded:Connect(function() task.wait(1); if CFG.GodMode then enableGod() end end)
LP.CharacterRemoving:Connect(disableGod)

local lastAura=0
RunService.Heartbeat:Connect(function()
    if CFG.KillAura and tick()-lastAura>0.1 then
        local myPos = getMyPos()
        if myPos then
            for _,p in ipairs(Players:GetPlayers()) do
                if p~=LP and alive(p) and enemy(p) then
                    local ePos = getEnemyPos(p)
                    if ePos and (ePos-myPos).Magnitude <= CFG.KillAuraRange then
                        if Remote.Attack then pcall(function() Remote.Attack:FireServer(p) end) end
                        lastAura=tick(); break
                    end
                end
            end
        end
    end
    if CFG.AntiPosture then
        local hum=LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        local anim=hum and hum:FindFirstChild("Animator")
        if anim then
            for _,t in ipairs(anim:GetPlayingAnimationTracks()) do
                if t.IsPlaying and string.find(string.lower(t.Name), "posture") and t.TimePosition > t.Length-0.15 then
                    if Remote.Parry then pcall(function() Remote.Parry:FireServer() end) end
                end
            end
        end
    end
    if CFG.AutoBuy and Remote.Buy then pcall(function() Remote.Buy:FireServer() end) end
    if CFG.ClaimRewards and Remote.Claim then pcall(function() Remote.Claim:FireServer() end) end
end)

-- [FIX 6] UI BUILD (Anti-Crash Arceus X)
local C={bg=Color3.fromRGB(14,14,18),s=Color3.fromRGB(22,22,28),s2=Color3.fromRGB(30,30,38),a=Color3.fromRGB(90,140,255),t=Color3.fromRGB(230,230,240)}
local F=Enum.Font.Gotham; local FB=Enum.Font.GothamBold
local function c(o,r) local x=Instance.new("UICorner"); x.CornerRadius=UDim.new(0,r or 6); x.Parent=o end

local gui=Instance.new("ScreenGui"); gui.Name="DG_Hub_v7_3"; gui.ResetOnSpawn=false; gui.IgnoreGuiInset=true; gui.Parent=PGui
local root=Instance.new("Frame"); root.Size=UDim2.new(0,320,0,360); root.Position=UDim2.new(0.5,-160,0.5,-180); root.BackgroundColor3=C.bg; root.BorderSizePixel=0; root.Active=true; root.Parent=gui
c(root,10)

local hdr=Instance.new("Frame"); hdr.Size=UDim2.new(1,0,0,40); hdr.BackgroundTransparency=1; hdr.Parent=root
local title=Instance.new("TextLabel"); title.Size=UDim2.new(1,-40,1,0); title.Position=UDim2.new(0,12,0,0); title.BackgroundTransparency=1; title.Text="DG Hub v7.3"; title.TextColor3=C.t; title.Font=FB; title.TextSize=14; title.TextXAlignment=Enum.TextXAlignment.Left; title.Parent=hdr

local function drag(frame, btn)
    local dragging, start, startPos
    btn.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=true; start=i.Position; startPos=frame.Position end end)
    UIS.InputChanged:Connect(function(i) if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then local d=i.Position-start; frame.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y) end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=false end end)
end
drag(root, title)

local cls=Instance.new("TextButton"); cls.Size=UDim2.new(0,30,0,30); cls.Position=UDim2.new(1,-40,0,5); cls.BackgroundColor3=C.s2; cls.Text="×"; cls.TextColor3=C.t; cls.Font=FB; cls.TextSize=18; cls.Parent=hdr
c(cls,6); cls.Activated:Connect(function() for p in pairs(espCache) do clearESP(p) end; gui:Destroy() end)

local floatBtn = Instance.new("TextButton")
floatBtn.Size = UDim2.new(0, 45, 0, 45)
floatBtn.Position = UDim2.new(1, -60, 1, -60)
floatBtn.BackgroundColor3 = C.a
floatBtn.Text = "⚙️"
floatBtn.TextSize = 24
floatBtn.TextColor3 = Color3.new(1,1,1)
floatBtn.BorderSizePixel = 0
floatBtn.Visible = false
floatBtn.Parent = gui
c(floatBtn, 22)

local uiOpen = true
local function toggleUI()
    uiOpen = not uiOpen
    root.Visible = uiOpen
    floatBtn.Visible = not uiOpen
end
floatBtn.Activated:Connect(toggleUI)

UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.RightShift then toggleUI() end
end)

local nav=Instance.new("Frame"); nav.Size=UDim2.new(1,-20,0,30); nav.Position=UDim2.new(0,10,0,45); nav.BackgroundColor3=C.s; nav.Parent=root
c(nav,6)
local nl=Instance.new("UIListLayout"); nl.FillDirection=Enum.FillDirection.Horizontal; nl.HorizontalAlignment=Enum.HorizontalAlignment.Center; nl.VerticalAlignment=Enum.VerticalAlignment.Center; nl.Padding=UDim.new(0,4); nl.Parent=nav

local pages={} local currPage
local content=Instance.new("ScrollingFrame"); content.Size=UDim2.new(1,-20,1,-90); content.Position=UDim2.new(0,10,0,80); content.BackgroundTransparency=1; content.BorderSizePixel=0; content.ScrollBarThickness=2; content.AutomaticCanvasSize=Enum.AutomaticSize.Y; content.CanvasSize=UDim2.new(0,0,0,0); content.Parent=root
local cl=Instance.new("UIListLayout"); cl.Padding=UDim.new(0,6); cl.Parent=content

local function showPage(name) for n,v in pairs(pages) do v.Visible = (n==name) end; currPage=name end
local function addPage(name, btnText)
    local btn=Instance.new("TextButton"); btn.Size=UDim2.new(0,65,0,22); btn.BackgroundColor3=C.s; btn.Text=btnText; btn.TextColor3=C.t; btn.Font=F; btn.TextSize=11; btn.Parent=nav; c(btn,4)
    local pg=Instance.new("Frame"); pg.Size=UDim2.new(1,0,0,0); pg.AutomaticSize=Enum.AutomaticSize.Y; pg.BackgroundTransparency=1; pg.Visible=false; pg.Parent=content
    local pl=Instance.new("UIListLayout"); pl.Padding=UDim.new(0,6); pl.Parent=pg
    pages[name]=pg
    btn.Activated:Connect(function() showPage(name); for n,b in pairs(nav:GetChildren()) do if b:IsA("TextButton") then b.BackgroundColor3 = (b.Text==btnText) and C.a or C.s end end end)
    if name=="Combat" then btn.BackgroundColor3=C.a end
end
addPage("Combat","Combat"); addPage("Visuals","Visuals"); addPage("Utility","Utility"); addPage("Cosmetics","Cos")
showPage("Combat")

local function addToggle(parent,label,key,cb)
    local b=Instance.new("TextButton"); b.Size=UDim2.new(1,0,0,40); b.BackgroundColor3=C.s; b.Text="  "..label; b.TextColor3=C.t; b.Font=F; b.TextSize=13; b.TextXAlignment=Enum.TextXAlignment.Left; b.Parent=parent; b.AutoButtonColor=false; c(b,6)
    local ind=Instance.new("Frame"); ind.Size=UDim2.new(0,36,0,18); ind.Position=UDim2.new(1,-46,0.5,-9); ind.BackgroundColor3=C.s2; ind.Parent=b; c(ind,9)
    local kb=Instance.new("Frame"); kb.Size=UDim2.new(0,14,0,14); kb.Position=UDim2.new(0,2,0.5,-7); kb.BackgroundColor3=C.t; kb.Parent=ind; c(kb,7)
    local function ref() Tween:Create(ind,TweenInfo.new(0.1),{BackgroundColor3=CFG[key] and C.a or C.s2}):Play(); Tween:Create(kb,TweenInfo.new(0.1),{Position=CFG[key] and UDim2.new(1,-16,0.5,-7) or UDim2.new(0,2,0.5,-7)}):Play() end
    b.Activated:Connect(function() CFG[key]=not CFG[key]; ref(); if cb then cb(CFG[key]) end end)
    ref()
end

local function addSlider(parent,label,key,min,max,step)
    local b=Instance.new("Frame"); b.Size=UDim2.new(1,0,0,50); b.BackgroundColor3=C.s; b.Parent=parent; c(b,6)
    local tl=Instance.new("TextLabel"); tl.Size=UDim2.new(1,-50,0,15); tl.Position=UDim2.new(0,10,0,5); tl.BackgroundTransparency=1; tl.Text=label; tl.TextColor3=C.t; tl.Font=F; tl.TextSize=12; tl.TextXAlignment=Enum.TextXAlignment.Left; tl.Parent=b
    local vl=Instance.new("TextLabel"); vl.Size=UDim2.new(0,34,0,15); vl.Position=UDim2.new(1,-44,0,5); vl.BackgroundColor3=C.s2; vl.Text=tostring(CFG[key]); vl.TextColor3=C.a; vl.Font=FB; vl.TextSize=11; vl.Parent=b; c(vl,4)
    local tb=Instance.new("Frame"); tb.Size=UDim2.new(1,-20,0,8); tb.Position=UDim2.new(0,10,0,32); tb.BackgroundColor3=C.s2; tb.Parent=b; c(tb,4)
    local fl=Instance.new("Frame"); fl.Size=UDim2.new((CFG[key]-min)/(max-min),0,1,0); fl.BackgroundColor3=C.a; fl.Parent=tb; c(fl,4)
    local kb=Instance.new("Frame"); kb.Size=UDim2.new(0,18,0,18); kb.Position=UDim2.new((CFG[key]-min)/(max-min),-9,0.5,-9); kb.BackgroundColor3=Color3.new(1,1,1); kb.Parent=tb; c(kb,9)
    local hit=Instance.new("TextButton"); hit.Size=UDim2.new(1,0,0,36); hit.Position=UDim2.new(0,0,0,22); hit.BackgroundTransparency=1; hit.Text=""; hit.ZIndex=5; hit.Parent=b
    local drag=false
    local function upd(x) local r=math.clamp((x-tb.AbsolutePosition.X)/tb.AbsoluteSize.X,0,1); local v=min+math.floor((r*(max-min))/step+0.5)*step; CFG[key]=v; vl.Text=tostring(v); fl.Size=UDim2.new(r,0,1,0); kb.Position=UDim2.new(r,-9,0.5,-9) end
    hit.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then drag=true; upd(i.Position.X) end end)
    UIS.InputChanged:Connect(function(i) if drag and (i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseMovement) then upd(i.Position.X) end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end end)
end

local function addBtn(parent,label,cb)
    local b=Instance.new("TextButton"); b.Size=UDim2.new(1,0,0,36); b.BackgroundColor3=C.s2; b.Text=label; b.TextColor3=C.t; b.Font=F; b.TextSize=12; b.Parent=parent; c(b,6); b.Activated:Connect(cb)
end

addToggle(pages["Combat"],"Aimbot","Aimbot"); addSlider(pages["Combat"],"Aimbot FOV","AimbotFOV",20,300,5); addSlider(pages["Combat"],"Aimbot Smooth","AimbotSmooth",1,100,1)
addToggle(pages["Combat"],"Auto-Parry","AutoParry"); addSlider(pages["Combat"],"Parry Range","ParryRange",5,50,1); addSlider(pages["Combat"],"Parry Window","ParryWindow",10,60,1)
addToggle(pages["Combat"],"Auto-Dodge","AutoDodge"); addToggle(pages["Combat"],"Kill Aura","KillAura"); addSlider(pages["Combat"],"Kill Aura Range","KillAuraRange",5,40,1)
addToggle(pages["Combat"],"God Mode","GodMode",function(on) if on then enableGod() else disableGod() end end)
addToggle(pages["Visuals"],"ESP Box","ESP"); addToggle(pages["Visuals"],"Nametags","Nametags"); addToggle(pages["Visuals"],"Anti Posture","AntiPosture")
addToggle(pages["Utility"],"Auto Buy","AutoBuy"); addToggle(pages["Utility"],"Claim Rewards","ClaimRewards")
