-- Dueling Grounds Unified Hub v3.1 — final consolidated
-- v2 Modern UI + 15 fix pass 1-3 + pass 4 (god race, Drawing close)
-- + 3 fix v3 (scan throttle, ParryWindow min, close iter safety).

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local Workspace  = game:GetService("Workspace")
local RS         = game:GetService("ReplicatedStorage")
local Tween      = game:GetService("TweenService")
local LP         = Players.LocalPlayer
local Camera     = Workspace.CurrentCamera
local Mouse      = LP:GetMouse()

local CFG = {
    ESP=false, ESPColor=Color3.fromRGB(255,40,40), Nametags=false, RangeVisual=false,
    Aimbot=false, AimbotFOV=120, AimbotSmooth=22, AimPart="Head",
    AutoParry=false, ParryRange=30, ParryWindow=15,
    AutoDodge=false, GodMode=false,
    KillAura=false, KillAuraRange=14,
    AntiPosture=false, AutoBuy=false, ClaimRewards=false,
}

local function alive(p) local h=p and p.Character and p.Character:FindFirstChildOfClass("Humanoid"); return h and h.Health>0 end
local function hrp(p)   return p and p.Character and p.Character:FindFirstChild("HumanoidRootPart") end
local function enemy(p) if p==LP then return false end local t,mt=p:GetAttribute("Team"),LP:GetAttribute("Team") if t and mt then return t~=mt end return true end
local function findRemote(names,kind) kind=kind or "RemoteEvent" for _,n in ipairs(names) do local r=RS:FindFirstChild(n,true) if r and r:IsA(kind) then return r end end end
local Remote = {
    Parry=findRemote({"Parry","ParryEvent","Combat","CombatEvent","Block"}),
    Dodge=findRemote({"Dodge","DodgeEvent","Roll","RollEvent"}),
    Attack=findRemote({"Attack","Swing","Hit","Combat"}),
    Duel=findRemote({"RequestDuel","SendDuel","DuelRequest","Challenge"}),
    Buy=findRemote({"Buy","Purchase","BuyWeapon"}),
    Claim=findRemote({"Claim","ClaimReward","Reward"}),
}

-- ESP
local espCache={}
local function makeESP(p)
    local box=Drawing.new("Square"); box.Thickness=1; box.Filled=false; box.Color=CFG.ESPColor; box.Visible=false
    local nm=Drawing.new("Text"); nm.Size=14; nm.Center=true; nm.Outline=true; nm.Color=Color3.fromRGB(255,255,255); nm.Visible=false
    local hp=Drawing.new("Line"); hp.Thickness=2; hp.Color=Color3.fromRGB(0,255,0); hp.Visible=false
    local rng=Drawing.new("Text"); rng.Size=12; rng.Center=true; rng.Outline=true; rng.Color=Color3.fromRGB(255,200,80); rng.Visible=false
    return {box=box,name=nm,hp=hp,range=rng,player=p}
end
local function clearESP(p)
    local d=espCache[p]; if not d then return end
    for _,obj in pairs({d.box,d.name,d.hp,d.range}) do pcall(function() obj:Remove() end) end
    espCache[p]=nil
end
Players.PlayerRemoving:Connect(clearESP)
local function updateESP()
    for _,p in ipairs(Players:GetPlayers()) do
        if p==LP then continue end
        if not espCache[p] then espCache[p]=makeESP(p) end
        local d=espCache[p]
        local r=hrp(p); local head=p.Character and p.Character:FindFirstChild("Head")
        local hum=p.Character and p.Character:FindFirstChildOfClass("Humanoid")
        if CFG.ESP and r and head and hum and hum.Health>0 and enemy(p) then
            local hpos,on1=Camera:WorldToViewportPoint(head.Position+Vector3.new(0,0.5,0))
            local rpos,on2=Camera:WorldToViewportPoint(r.Position)
            if on1 and on2 then
                local h=math.abs(hpos.Y-rpos.Y)*1.6; local w=h*0.6
                d.box.Size=Vector2.new(w,h); d.box.Position=Vector2.new(hpos.X-w/2,hpos.Y); d.box.Visible=true
                if CFG.Nametags then d.name.Text=string.format("%s [%d]",p.Name,math.floor(hum.Health)); d.name.Position=Vector2.new(hpos.X,hpos.Y-18); d.name.Visible=true else d.name.Visible=false end
                local pct=hum.Health/hum.MaxHealth
                d.hp.From=Vector2.new(hpos.X-w/2-6,hpos.Y+h); d.hp.To=Vector2.new(hpos.X-w/2-6,hpos.Y+h-h*pct); d.hp.Visible=true
                if CFG.RangeVisual then local myr=hrp(LP) if myr then d.range.Text=string.format("%d st",math.floor((myr.Position-r.Position).Magnitude)) d.range.Position=Vector2.new(hpos.X,hpos.Y+h+2) d.range.Visible=true end else d.range.Visible=false end
            else d.box.Visible=false d.name.Visible=false d.hp.Visible=false d.range.Visible=false end
        else d.box.Visible=false d.name.Visible=false d.hp.Visible=false d.range.Visible=false end
    end
end
local lastESPUpdate=0
local function tickESP(now)
    if not CFG.ESP then return end
    if now-lastESPUpdate < (1/30) then return end
    lastESPUpdate=now; updateESP()
end

-- Aimbot
local aimTarget
local function closestTarget()
    local best,bestD=nil,math.huge
    local sc=Vector2.new(Camera.ViewportSize.X/2,Camera.ViewportSize.Y/2)
    for _,p in ipairs(Players:GetPlayers()) do
        if p==LP or not alive(p) or not enemy(p) then continue end
        local part=p.Character:FindFirstChild(CFG.AimPart) or p.Character:FindFirstChild("HumanoidRootPart")
        if not part then continue end
        local sp,on=Camera:WorldToViewportPoint(part.Position); if not on then continue end
        local d=(Vector2.new(sp.X,sp.Y)-sc).Magnitude
        if d<CFG.AimbotFOV and d<bestD then bestD=d; best=part end
    end
    return best
end
local function aimTargetValid()
    if not aimTarget or not aimTarget.Parent then return false end
    local char=aimTarget:FindFirstAncestorOfClass("Model"); if not char then return false end
    local pl=Players:GetPlayerFromCharacter(char)
    if pl and not alive(pl) then return false end
    return true
end
local function aimAlpha() return math.clamp(CFG.AimbotSmooth,1,100)/100 end
UIS.InputBegan:Connect(function(i,g) if not g and i.UserInputType==Enum.UserInputType.MouseButton2 and CFG.Aimbot then aimTarget=closestTarget() end end)
UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton2 then aimTarget=nil end end)

-- Scan + parry + dodge
local parryTracked={}
local lastParryPer={}
local lastScan=0
local function scanTracks()
    local now=tick()
    if now-lastScan < (1/20) then return end
    lastScan=now
    for _,p in ipairs(Players:GetPlayers()) do
        if p==LP or not alive(p) or not enemy(p) then continue end
        local hum=p.Character and p.Character:FindFirstChildOfClass("Humanoid")
        local anim=hum and hum:FindFirstChildOfClass("Animator"); if not anim then continue end
        for _,t in ipairs(anim:GetPlayingAnimationTracks()) do
            local key=tostring(p.UserId)..":"..t.Name
            local isAtk=(math.abs(t.Length-0.933)<0.05) or (math.abs(t.Length-1.2)<0.05)
            if isAtk and t.TimePosition<0.20 then
                parryTracked[key]={track=t,player=p}
            elseif not isAtk or not t.IsPlaying then
                parryTracked[key]=nil
            end
        end
    end
    for k,info in pairs(parryTracked) do if not info.track.IsPlaying then parryTracked[k]=nil end end
end
local function animParry()
    if not CFG.AutoParry then return end
    local myr=hrp(LP); if not myr then return end
    local win=CFG.ParryWindow/100; local now=tick()
    for k,info in pairs(parryTracked) do
        local t,p=info.track,info.player
        if not (t and t.IsPlaying and alive(p) and enemy(p)) then parryTracked[k]=nil; continue end
        local hr=hrp(p); if not hr then continue end
        if (hr.Position-myr.Position).Magnitude>CFG.ParryRange then continue end
        local uid=p.UserId
        if now-(lastParryPer[uid] or 0)<0.08 then continue end
        if t.TimePosition>=win and t.TimePosition<=win+0.10 then
            if Remote.Parry then pcall(function() Remote.Parry:FireServer() end) end
            lastParryPer[uid]=now; parryTracked[k]=nil
        end
    end
end
local lastDodgePer={}
local function autoDodge()
    if not CFG.AutoDodge then return end
    local myr=hrp(LP); if not myr then return end
    local now=tick()
    for _,info in pairs(parryTracked) do
        local t,p=info.track,info.player
        if not (t and t.IsPlaying and alive(p) and enemy(p)) then continue end
        if t.TimePosition>=0.15 then continue end
        local hr=hrp(p); if not hr then continue end
        if (hr.Position-myr.Position).Magnitude>CFG.ParryRange then continue end
        local uid=p.UserId
        if now-(lastDodgePer[uid] or 0)<0.30 then continue end
        if Remote.Dodge then pcall(function() Remote.Dodge:FireServer() end) end
        lastDodgePer[uid]=now
    end
end

-- God mode
local godConn
local function disableGod() if godConn then godConn:Disconnect(); godConn=nil end end
local function enableGod()
    local hum=LP.Character and LP.Character:FindFirstChildOfClass("Humanoid"); if not hum then return end
    if hum.Health<hum.MaxHealth then hum.Health=hum.MaxHealth end
    disableGod()
    godConn=hum.HealthChanged:Connect(function(h)
        if CFG.GodMode and hum.Parent and h<hum.MaxHealth then hum.Health=hum.MaxHealth end
    end)
end
LP.CharacterAdded:Connect(function()
    local hum=LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health<=0 then hum.HealthChanged:Wait() end
    task.wait(0.1)
    if CFG.GodMode then enableGod() end
end)
LP.CharacterRemoving:Connect(disableGod)

-- Kill aura
local lastAura=0
local function killAura()
    if not CFG.KillAura or tick()-lastAura<0.1 then return end
    local myr=hrp(LP); if not myr then return end
    for _,p in ipairs(Players:GetPlayers()) do
        if p==LP or not alive(p) or not enemy(p) then continue end
        local hr=hrp(p)
        if hr and (hr.Position-myr.Position).Magnitude<=CFG.KillAuraRange then
            if Remote.Attack then pcall(function() Remote.Attack:FireServer(p) end) end
            lastAura=tick(); return
        end
    end
end

-- Anti posture
local lastAntiPosture=0
local ANTI_POSTURE_ANIMS={["posture"]=true,["guardbreak"]=true,["stagger"]=true,["posturebreak"]=true}
local function antiPosture()
    if not CFG.AntiPosture then return end
    local now=tick(); if now-lastAntiPosture<0.25 then return end
    local myr=hrp(LP); if not myr then return end
    local hum=LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    local anim=hum and hum:FindFirstChildOfClass("Animator"); if not anim then return end
    local hasEnemy=false
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LP and alive(p) and enemy(p) then
            local hr=hrp(p)
            if hr and (hr.Position-myr.Position).Magnitude<=CFG.ParryRange then hasEnemy=true; break end
        end
    end
    if not hasEnemy then return end
    for _,t in ipairs(anim:GetPlayingAnimationTracks()) do
        if not t.IsPlaying then continue end
        local lname=string.lower(t.Name)
        local matchesDur=(math.abs(t.Length-0.7)<0.1) or (math.abs(t.Length-0.8)<0.1)
        local matchesName=false
        for kw in pairs(ANTI_POSTURE_ANIMS) do if string.find(lname,kw,1,true) then matchesName=true; break end end
        if matchesDur and matchesName and t.TimePosition>t.Length-0.15 then
            if Remote.Parry then pcall(function() Remote.Parry:FireServer() end) end
            lastAntiPosture=now; return
        end
    end
end

-- Cosmetics
local function equipCosmetic(name)
    local remote=findRemote({"Equip","EquipSkin","SetSkin","Cosmetic"})
    if remote then pcall(function() remote:FireServer(name) end) return end
    local bp=LP:FindFirstChildOfClass("Backpack"); if not bp then return end
    local lname=string.lower(name)
    for _,t in ipairs(bp:GetChildren()) do
        if t:IsA("Tool") and string.find(string.lower(t.Name),lname,1,true) then
            local hum=LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum:EquipTool(t) end
            return
        end
    end
end

-- Buy/claim
local lastBuy,lastClaim=0,0
local function autoBuy()
    if not CFG.AutoBuy or not Remote.Buy then return end
    local now=tick(); if now-lastBuy<1.0 then return end
    lastBuy=now; pcall(function() Remote.Buy:FireServer() end)
end
local function claimRewards()
    if not CFG.ClaimRewards or not Remote.Claim then return end
    local now=tick(); if now-lastClaim<1.0 then return end
    lastClaim=now; pcall(function() Remote.Claim:FireServer() end)
end

-- THEME
local C={bg=Color3.fromRGB(14,14,18),surface=Color3.fromRGB(22,22,28),surface2=Color3.fromRGB(30,30,38),
    border=Color3.fromRGB(44,44,54),accent=Color3.fromRGB(90,140,255),accent2=Color3.fromRGB(140,90,255),
    text=Color3.fromRGB(230,230,240),textDim=Color3.fromRGB(140,140,155),
    danger=Color3.fromRGB(255,90,90),success=Color3.fromRGB(90,220,140)}
local FONT=Enum.Font.Gotham local FONT_BOLD=Enum.Font.GothamBold
local function corner(obj,r) local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,r or 6); c.Parent=obj; return c end
local function stroke(obj,color,thick) local s=Instance.new("UIStroke"); s.Color=color or C.border; s.Thickness=thick or 1; s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border; s.Parent=obj; return s end
local function gradient(obj,c1,c2,rot) local g=Instance.new("UIGradient"); g.Color=ColorSequence.new(c1,c2); g.Rotation=rot or 0; g.Parent=obj; return g end

-- GUI
local gui=Instance.new("ScreenGui"); gui.Name="DG_Hub"; gui.ResetOnSpawn=false; gui.IgnoreGuiInset=true; gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; gui.Parent=game.CoreGui
local root=Instance.new("Frame"); root.Name="Root"; root.Size=UDim2.new(0,600,0,420); root.Position=UDim2.new(0.5,-300,0.5,-210); root.BackgroundColor3=C.bg; root.BorderSizePixel=0; root.Active=true; root.ClipsDescendants=true; root.Parent=gui
corner(root,12); stroke(root,C.border,1); gradient(root,Color3.fromRGB(20,20,26),Color3.fromRGB(10,10,14),90)
local accentBar=Instance.new("Frame"); accentBar.Size=UDim2.new(1,0,0,2); accentBar.BorderSizePixel=0; accentBar.Parent=root; gradient(accentBar,C.accent,C.accent2,0)
local header=Instance.new("Frame"); header.Size=UDim2.new(1,0,0,54); header.BackgroundTransparency=1; header.Parent=root
local logo=Instance.new("Frame"); logo.Size=UDim2.new(0,32,0,32); logo.Position=UDim2.new(0,18,0,11); logo.BackgroundColor3=C.accent; logo.BorderSizePixel=0; logo.Parent=header; corner(logo,8); gradient(logo,C.accent,C.accent2,45)
local logoText=Instance.new("TextLabel"); logoText.Size=UDim2.new(1,0,1,0); logoText.BackgroundTransparency=1; logoText.Text="DG"; logoText.TextColor3=Color3.fromRGB(255,255,255); logoText.Font=FONT_BOLD; logoText.TextSize=15; logoText.Parent=logo
local titleLbl=Instance.new("TextLabel"); titleLbl.Size=UDim2.new(0,300,0,20); titleLbl.Position=UDim2.new(0,60,0,10); titleLbl.BackgroundTransparency=1; titleLbl.Text="Dueling Grounds"; titleLbl.TextColor3=C.text; titleLbl.Font=FONT_BOLD; titleLbl.TextSize=15; titleLbl.TextXAlignment=Enum.TextXAlignment.Left; titleLbl.Parent=header
local subtitle=Instance.new("TextLabel"); subtitle.Size=UDim2.new(0,300,0,16); subtitle.Position=UDim2.new(0,60,0,28); subtitle.BackgroundTransparency=1; subtitle.Text="Unified Hub · v3.1"; subtitle.TextColor3=C.textDim; subtitle.Font=FONT; subtitle.TextSize=11; subtitle.TextXAlignment=Enum.TextXAlignment.Left; subtitle.Parent=header
local closeBtn=Instance.new("TextButton"); closeBtn.Size=UDim2.new(0,28,0,28); closeBtn.Position=UDim2.new(1,-40,0,13); closeBtn.BackgroundColor3=C.surface2; closeBtn.Text="×"; closeBtn.TextColor3=C.textDim; closeBtn.Font=FONT_BOLD; closeBtn.TextSize=18; closeBtn.BorderSizePixel=0; closeBtn.Parent=header
corner(closeBtn,8)
closeBtn.MouseEnter:Connect(function() Tween:Create(closeBtn,TweenInfo.new(0.15),{BackgroundColor3=C.danger,TextColor3=Color3.fromRGB(255,255,255)}):Play() end)
closeBtn.MouseLeave:Connect(function() Tween:Create(closeBtn,TweenInfo.new(0.15),{BackgroundColor3=C.surface2,TextColor3=C.textDim}):Play() end)
closeBtn.MouseButton1Click:Connect(function()
    local keys={}
    for p in pairs(espCache) do keys[#keys+1]=p end
    for _,p in ipairs(keys) do clearESP(p) end
    if godConn then godConn:Disconnect(); godConn=nil end
    gui:Destroy()
end)
do
    local drag=false local start,startPos
    header.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=true; start=i.Position; startPos=root.Position end end)
    UIS.InputChanged:Connect(function(i) if drag and i.UserInputType==Enum.UserInputType.MouseMovement then local delta=i.Position-start root.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+delta.X,startPos.Y.Scale,startPos.Y.Offset+delta.Y) end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end end)
end
local div=Instance.new("Frame"); div.Size=UDim2.new(1,-36,0,1); div.Position=UDim2.new(0,18,0,54); div.BackgroundColor3=C.border; div.BorderSizePixel=0; div.Parent=root
local sidebar=Instance.new("Frame"); sidebar.Size=UDim2.new(0,150,1,-80); sidebar.Position=UDim2.new(0,12,0,66); sidebar.BackgroundColor3=C.surface; sidebar.BorderSizePixel=0; sidebar.Parent=root
corner(sidebar,10); stroke(sidebar,C.border,1)
local sidebarLayout=Instance.new("UIListLayout"); sidebarLayout.Padding=UDim.new(0,4); sidebarLayout.Parent=sidebar
local spad=Instance.new("UIPadding"); spad.PaddingTop=UDim.new(0,10); spad.PaddingLeft=UDim.new(0,8); spad.PaddingRight=UDim.new(0,8); spad.Parent=sidebar
local content=Instance.new("Frame"); content.Size=UDim2.new(1,-180,1,-80); content.Position=UDim2.new(0,168,0,66); content.BackgroundTransparency=1; content.Parent=root
local pages={} local currentPage
local function makePage(name)
    local sc=Instance.new("ScrollingFrame"); sc.Size=UDim2.new(1,0,1,0); sc.BackgroundTransparency=1; sc.BorderSizePixel=0
    sc.CanvasSize=UDim2.new(0,0,0,0); sc.ScrollBarThickness=4; sc.ScrollBarImageColor3=C.accent
    sc.AutomaticCanvasSize=Enum.AutomaticSize.Y; sc.Visible=false; sc.Parent=content
    local pad=Instance.new("UIPadding"); pad.PaddingRight=UDim.new(0,8); pad.Parent=sc
    local layout=Instance.new("UIListLayout"); layout.Padding=UDim.new(0,10); layout.SortOrder=Enum.SortOrder.LayoutOrder; layout.Parent=sc
    pages[name]=sc; return sc
end
local function showPage(name) for n,sc in pairs(pages) do sc.Visible=(n==name) end currentPage=name end
local navButtons={}
local function addNav(name,label)
    local b=Instance.new("TextButton"); b.Size=UDim2.new(1,0,0,34); b.BackgroundColor3=C.surface
    b.Text="  "..label; b.TextColor3=C.textDim; b.Font=FONT; b.TextSize=13; b.TextXAlignment=Enum.TextXAlignment.Left
    b.BorderSizePixel=0; b.Parent=sidebar; corner(b,6)
    b.MouseEnter:Connect(function() if currentPage~=name then Tween:Create(b,TweenInfo.new(0.12),{BackgroundColor3=C.surface2,TextColor3=C.text}):Play() end end)
    b.MouseLeave:Connect(function() if currentPage~=name then Tween:Create(b,TweenInfo.new(0.12),{BackgroundColor3=C.surface,TextColor3=C.textDim}):Play() end end)
    b.MouseButton1Click:Connect(function()
        showPage(name)
        for n,nb in pairs(navButtons) do Tween:Create(nb,TweenInfo.new(0.15),{BackgroundColor3=(n==name) and C.surface2 or C.surface,TextColor3=(n==name) and C.accent or C.textDim}):Play() end
    end)
    navButtons[name]=b
end
makePage("Combat"); makePage("Visuals"); makePage("Utility"); makePage("Cosmetics")
addNav("Combat"," Combat"); addNav("Visuals"," Visuals"); addNav("Utility"," Utility"); addNav("Cosmetics"," Cosmetics")
local function section(parent,text)
    local wrap=Instance.new("Frame"); wrap.Size=UDim2.new(1,0,0,0); wrap.AutomaticSize=Enum.AutomaticSize.Y; wrap.BackgroundTransparency=1; wrap.Parent=parent
    local lay=Instance.new("UIListLayout"); lay.Padding=UDim.new(0,8); lay.Parent=wrap
    local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(1,0,0,16); lbl.BackgroundTransparency=1; lbl.Text=text:upper(); lbl.TextColor3=C.textDim; lbl.Font=FONT_BOLD; lbl.TextSize=10; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=wrap
    return wrap
end
local function toggle(parent,label,key,cb)
    local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,40); row.BackgroundColor3=C.surface; row.BorderSizePixel=0; row.Parent=parent
    corner(row,8); stroke(row,C.border,1)
    local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(1,-70,1,0); lbl.Position=UDim2.new(0,14,0,0); lbl.BackgroundTransparency=1; lbl.Text=label; lbl.TextColor3=C.text; lbl.Font=FONT; lbl.TextSize=13; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=row
    local track=Instance.new("Frame"); track.Size=UDim2.new(0,40,0,22); track.Position=UDim2.new(1,-54,0.5,-11); track.BackgroundColor3=C.surface2; track.BorderSizePixel=0; track.Parent=row
    corner(track,11); stroke(track,C.border,1)
    local knob=Instance.new("Frame"); knob.Size=UDim2.new(0,16,0,16); knob.Position=UDim2.new(0,3,0.5,-8); knob.BackgroundColor3=C.textDim; knob.BorderSizePixel=0; knob.Parent=track
    corner(knob,8)
    local function refresh()
        local on=CFG[key]
        Tween:Create(track,TweenInfo.new(0.18),{BackgroundColor3=on and C.accent or C.surface2}):Play()
        Tween:Create(knob,TweenInfo.new(0.18),{Position=on and UDim2.new(1,-19,0.5,-8) or UDim2.new(0,3,0.5,-8),BackgroundColor3=on and Color3.fromRGB(255,255,255) or C.textDim}):Play()
    end
    local btn=Instance.new("TextButton"); btn.Size=UDim2.new(1,0,1,0); btn.BackgroundTransparency=1; btn.Text=""; btn.Parent=track
    btn.MouseButton1Click:Connect(function() CFG[key]=not CFG[key]; refresh(); if cb then cb(CFG[key]) end end)
    row.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then CFG[key]=not CFG[key]; refresh(); if cb then cb(CFG[key]) end end end)
    refresh(); return row
end
local function slider(parent,label,key,min,max,step)
    local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,56); row.BackgroundColor3=C.surface; row.BorderSizePixel=0; row.Parent=parent
    corner(row,8); stroke(row,C.border,1)
    local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(1,-80,0,20); lbl.Position=UDim2.new(0,14,0,8); lbl.BackgroundTransparency=1; lbl.Text=label; lbl.TextColor3=C.text; lbl.Font=FONT; lbl.TextSize=13; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=row
    local val=Instance.new("TextLabel"); val.Size=UDim2.new(0,60,0,20); val.Position=UDim2.new(1,-74,0,8); val.BackgroundColor3=C.surface2; val.Text=tostring(CFG[key]); val.TextColor3=C.accent; val.Font=FONT_BOLD; val.TextSize=12; val.TextXAlignment=Enum.TextXAlignment.Center; val.Parent=row
    corner(val,4)
    local track=Instance.new("Frame"); track.Size=UDim2.new(1,-28,0,6); track.Position=UDim2.new(0,14,0,38); track.BackgroundColor3=C.surface2; track.BorderSizePixel=0; track.Parent=row
    corner(track,3)
    local fill=Instance.new("Frame"); fill.Size=UDim2.new((CFG[key]-min)/(max-min),0,1,0); fill.BackgroundColor3=C.accent; fill.BorderSizePixel=0; fill.Parent=track
    corner(fill,3); gradient(fill,C.accent,C.accent2,0)
    local knob=Instance.new("Frame"); knob.Size=UDim2.new(0,14,0,14); knob.Position=UDim2.new((CFG[key]-min)/(max-min),-7,0.5,-7); knob.BackgroundColor3=Color3.fromRGB(255,255,255); knob.BorderSizePixel=0; knob.Parent=track
    corner(knob,7); stroke(knob,C.accent,2)
    local dragging=false
    track.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end end)
    UIS.InputChanged:Connect(function(i)
        if dragging and i.UserInputType==Enum.UserInputType.MouseMovement then
            local rel=math.clamp((Mouse.X-track.AbsolutePosition.X)/track.AbsoluteSize.X,0,1)
            local v=min+math.floor((rel*(max-min))/step+0.5)*step
            CFG[key]=v; val.Text=tostring(v); fill.Size=UDim2.new(rel,0,1,0); knob.Position=UDim2.new(rel,-7,0.5,-7)
        end
    end)
    return row
end
local function button(parent,label,cb,danger)
    local b=Instance.new("TextButton"); b.Size=UDim2.new(1,0,0,38); b.BackgroundColor3=C.surface; b.Text=label; b.TextColor3=C.text; b.Font=FONT_BOLD; b.TextSize=13; b.BorderSizePixel=0; b.Parent=parent
    corner(b,8); stroke(b,C.border,1)
    local baseColor=C.surface
    b.MouseEnter:Connect(function() Tween:Create(b,TweenInfo.new(0.15),{BackgroundColor3=danger and C.danger or C.accent,TextColor3=Color3.fromRGB(255,255,255)}):Play() end)
    b.MouseLeave:Connect(function() Tween:Create(b,TweenInfo.new(0.15),{BackgroundColor3=baseColor,TextColor3=C.text}):Play() end)
    b.MouseButton1Click:Connect(cb); return b
end

-- POPULATE
local combatPage=pages["Combat"]
local c1=section(combatPage,"Precision")
toggle(c1,"Aimbot (RMB)","Aimbot")
slider(c1,"Aimbot FOV","AimbotFOV",20,300,5)
slider(c1,"Aimbot Smooth","AimbotSmooth",1,100,1)
local c2=section(combatPage,"Defense")
toggle(c2,"Auto-Parry","AutoParry",function(on) if not on then for k in pairs(parryTracked) do parryTracked[k]=nil end for k in pairs(lastParryPer) do lastParryPer[k]=nil end end end)
slider(c2,"Parry Range","ParryRange",5,50,1)
slider(c2,"Parry Window %","ParryWindow",10,60,1)
toggle(c2,"Auto-Dodge","AutoDodge",function(on) if not on then for k in pairs(lastDodgePer) do lastDodgePer[k]=nil end end end)
toggle(c2,"Anti Posture Break","AntiPosture")
local c3=section(combatPage,"Offense")
toggle(c3,"Kill Aura","KillAura")
slider(c3,"Kill Aura Range","KillAuraRange",5,40,1)
toggle(c3,"God Mode","GodMode",function(on) if on then enableGod() else disableGod() end end)

local visualPage=pages["Visuals"]
local v1=section(visualPage,"Overlay")
toggle(v1,"ESP Box","ESP"); toggle(v1,"Nametags","Nametags"); toggle(v1,"Range Visual","RangeVisual")

local utilPage=pages["Utility"]
local u1=section(utilPage,"Automation")
toggle(u1,"Auto Buy Weapon","AutoBuy"); toggle(u1,"Claim Rewards","ClaimRewards")

local cosPage=pages["Cosmetics"]
local co1=section(cosPage,"Weapons")
button(co1,"Equip Katana",function() equipCosmetic("Katana") end)
button(co1,"Equip Naginata",function() equipCosmetic("Naginata") end)
button(co1,"Equip Dagger",function() equipCosmetic("Dagger") end)

-- FOOTER
local footer=Instance.new("Frame"); footer.Size=UDim2.new(1,-36,0,24); footer.Position=UDim2.new(0,18,1,-32); footer.BackgroundTransparency=1; footer.Parent=root
local statusDot=Instance.new("Frame"); statusDot.Size=UDim2.new(0,8,0,8); statusDot.Position=UDim2.new(0,0,0.5,-4); statusDot.BackgroundColor3=C.success; statusDot.BorderSizePixel=0; statusDot.Parent=footer; corner(statusDot,4)
local statusText=Instance.new("TextLabel"); statusText.Size=UDim2.new(0,200,1,0); statusText.Position=UDim2.new(0,16,0,0); statusText.BackgroundTransparency=1; statusText.Text="Connected · "..LP.Name; statusText.TextColor3=C.textDim; statusText.Font=FONT; statusText.TextSize=11; statusText.TextXAlignment=Enum.TextXAlignment.Left; statusText.Parent=footer
local hint=Instance.new("TextLabel"); hint.Size=UDim2.new(0,200,1,0); hint.Position=UDim2.new(1,-200,0,0); hint.BackgroundTransparency=1; hint.Text="drag header · × to close"; hint.TextColor3=C.textDim; hint.Font=FONT; hint.TextSize=11; hint.TextXAlignment=Enum.TextXAlignment.Right; hint.Parent=footer

showPage("Combat")
for n,nb in pairs(navButtons) do Tween:Create(nb,TweenInfo.new(0.15),{BackgroundColor3=(n=="Combat") and C.surface2 or C.surface,TextColor3=(n=="Combat") and C.accent or C.textDim}):Play() end

-- LOOPS
RunService.RenderStepped:Connect(function()
    tickESP(tick())
    if CFG.Aimbot and aimTargetValid() then
        Camera.CFrame=Camera.CFrame:Lerp(CFrame.lookAt(Camera.CFrame.Position,aimTarget.Position),aimAlpha())
    elseif aimTarget and not aimTargetValid() then
        aimTarget=nil
    end
end)
RunService.Heartbeat:Connect(function()
    if CFG.AutoParry or CFG.AutoDodge then scanTracks() end
    if CFG.AutoParry then animParry() end
    if CFG.AutoDodge then autoDodge() end
    if CFG.AntiPosture then antiPosture() end
    if CFG.KillAura then killAura() end
    autoBuy(); claimRewards()
end)
if CFG.GodMode then enableGod() end