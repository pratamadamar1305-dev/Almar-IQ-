-- Dueling Grounds Unified Hub v4.1 — Mobile Final
-- All 22 fixes consolidated. Touch optimized.

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local Workspace  = game:GetService("Workspace")
local RS         = game:GetService("ReplicatedStorage")
local Tween      = game:GetService("TweenService")
local LP         = Players.LocalPlayer
local Camera     = Workspace.CurrentCamera

local CFG = {
    ESP=false, ESPColor=Color3.fromRGB(255,40,40), Nametags=false, RangeVisual=false,
    Aimbot=false, AimbotFOV=120, AimbotSmooth=22, AimPart="Head",
    AutoParry=false, ParryRange=30, ParryWindow=15,
    AutoDodge=false, GodMode=false,
    KillAura=false, KillAuraRange=14,
    AntiPosture=false, AutoBuy=false, ClaimRewards=false,
}

-- ================= HELPERS =================
local function alive(p) local h=p and p.Character and p.Character:FindFirstChildOfClass("Humanoid"); return h and h.Health>0 end
local function hrp(p) return p and p.Character and p.Character:FindFirstChild("HumanoidRootPart") end
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

-- ================= ESP =================
local espCache={}
local function clearESP(p)
    local d=espCache[p]; if not d then return end
    for _,obj in pairs({d.box,d.name,d.hp,d.range}) do pcall(function() obj:Remove() end) end
    espCache[p]=nil
end
Players.PlayerRemoving:Connect(clearESP)

local function updateESP()
    for _,p in ipairs(Players:GetPlayers()) do
        if p==LP then continue end
        if not espCache[p] then
            espCache[p]={
                box=Drawing.new("Square"), name=Drawing.new("Text"),
                hp=Drawing.new("Line"), range=Drawing.new("Text"), player=p
            }
            espCache[p].box.Thickness=1; espCache[p].box.Filled=false; espCache[p].box.Color=CFG.ESPColor; espCache[p].box.Visible=false
            espCache[p].name.Size=14; espCache[p].name.Center=true; espCache[p].name.Outline=true; espCache[p].name.Color=Color3.fromRGB(255,255,255); espCache[p].name.Visible=false
            espCache[p].hp.Thickness=2; espCache[p].hp.Color=Color3.fromRGB(0,255,0); espCache[p].hp.Visible=false
            espCache[p].range.Size=12; espCache[p].range.Center=true; espCache[p].range.Outline=true; espCache[p].range.Color=Color3.fromRGB(255,200,80); espCache[p].range.Visible=false
        end
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
local function tickESP()
    if not CFG.ESP then return end
    local now=tick(); if now-lastESPUpdate < (1/30) then return end
    lastESPUpdate=now; updateESP()
end

-- ================= COMBAT =================
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

UIS.InputBegan:Connect(function(i,g)
    if g then return end
    if (i.UserInputType==Enum.UserInputType.MouseButton2 or i.UserInputType==Enum.UserInputType.Touch) and CFG.Aimbot then
        aimTarget=closestTarget()
    end
end)
UIS.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton2 or i.UserInputType==Enum.UserInputType.Touch then
        aimTarget=nil
    end
end)

local parryTracked={} local lastParryPer={} local lastScan=0
local function scanTracks()
    local now=tick(); if now-lastScan < (1/20) then return end
    lastScan=now
    for _,p in ipairs(Players:GetPlayers()) do
        if p==LP or not alive(p) or not enemy(p) then continue end
        local hum=p.Character and p.Character:FindFirstChildOfClass("Humanoid")
        local anim=hum and hum:FindFirstChildOfClass("Animator"); if not anim then continue end
        for _,t in ipairs(anim:GetPlayingAnimationTracks()) do
            local key=tostring(p.UserId)..":"..t.Name
            if ((math.abs(t.Length-0.933)<0.05) or (math.abs(t.Length-1.2)<0.05)) and t.TimePosition<0.20 then
                parryTracked[key]={track=t,player=p}
            elseif not t.IsPlaying then parryTracked[key]=nil end
        end
    end
end
local function animParry()
    if not CFG.AutoParry then return end
    local myr=hrp(LP); if not myr then return end
    local win=CFG.ParryWindow/100; local now=tick()
    for k,info in pairs(parryTracked) do
        local t,p=info.track,info.player
        if not (t and t.IsPlaying and alive(p) and enemy(p)) then parryTracked[k]=nil; continue end
        local hr=hrp(p); if not hr or (hr.Position-myr.Position).Magnitude>CFG.ParryRange then continue end
        if now-(lastParryPer[p.UserId] or 0)<0.08 then continue end
        if t.TimePosition>=win and t.TimePosition<=win+0.10 then
            if Remote.Parry then pcall(function() Remote.Parry:FireServer() end) end
            lastParryPer[p.UserId]=now; parryTracked[k]=nil
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
        if not (t and t.IsPlaying and alive(p) and enemy(p) and t.TimePosition<0.15) then continue end
        local hr=hrp(p); if not hr or (hr.Position-myr.Position).Magnitude>CFG.ParryRange then continue end
        if now-(lastDodgePer[p.UserId] or 0)<0.30 then continue end
        if Remote.Dodge then pcall(function() Remote.Dodge:FireServer() end) end
        lastDodgePer[p.UserId]=now
    end
end

local godConn
local function disableGod() if godConn then godConn:Disconnect(); godConn=nil end end
local function enableGod()
    local hum=LP.Character and LP.Character:FindFirstChildOfClass("Humanoid"); if not hum then return end
    if hum.Health<hum.MaxHealth then hum.Health=hum.MaxHealth end
    disableGod()
    godConn=hum.HealthChanged:Connect(function(h) if CFG.GodMode and hum.Parent and h<hum.MaxHealth then hum.Health=hum.MaxHealth end end)
end
LP.CharacterAdded:Connect(function() task.wait(0.5); if CFG.GodMode then enableGod() end end)
LP.CharacterRemoving:Connect(disableGod)

local lastAura=0
local function killAura()
    if not CFG.KillAura or tick()-lastAura<0.1 then return end
    local myr=hrp(LP); if not myr then return end
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LP and alive(p) and enemy(p) then
            local hr=hrp(p)
            if hr and (hr.Position-myr.Position).Magnitude<=CFG.KillAuraRange then
                if Remote.Attack then pcall(function() Remote.Attack:FireServer(p) end) end
                lastAura=tick(); return
            end
        end
    end
end

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
            local hr=hrp(p); if hr and (hr.Position-myr.Position).Magnitude<=CFG.ParryRange then hasEnemy=true; break end
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

local lastBuy,lastClaim=0,0
local function autoBuy() if CFG.AutoBuy and Remote.Buy and tick()-lastBuy>=1.0 then lastBuy=tick(); pcall(function() Remote.Buy:FireServer() end) end end
local function claimRewards() if CFG.ClaimRewards and Remote.Claim and tick()-lastClaim>=1.0 then lastClaim=tick(); pcall(function() Remote.Claim:FireServer() end) end end

-- ================= UI THEME =================
local C={bg=Color3.fromRGB(14,14,18),surface=Color3.fromRGB(22,22,28),surface2=Color3.fromRGB(30,30,38),border=Color3.fromRGB(44,44,54),accent=Color3.fromRGB(90,140,255),accent2=Color3.fromRGB(140,90,255),text=Color3.fromRGB(230,230,240),textDim=Color3.fromRGB(140,140,155)}
local FONT=Enum.Font.Gotham local FONT_BOLD=Enum.Font.GothamBold
local function corner(obj,r) local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,r or 6); c.Parent=obj; return c end
local function stroke(obj,color,thick) local s=Instance.new("UIStroke"); s.Color=color or C.border; s.Thickness=thick or 1; s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border; s.Parent=obj; return s end

-- ================= UI BUILD =================
local gui=Instance.new("ScreenGui"); gui.Name="DG_Hub_v4"; gui.ResetOnSpawn=false; gui.IgnoreGuiInset=true; gui.Parent=game.CoreGui

local mainScale = Instance.new("UIScale")
local root=Instance.new("Frame"); root.Name="Root"; root.Size=UDim2.new(0,480,0,320); root.Position=UDim2.new(0.5,-240,0.5,-160); root.BackgroundColor3=C.bg; root.BorderSizePixel=0; root.Active=true; root.Parent=gui
mainScale.Parent = root
corner(root,10); stroke(root,C.border,1)

local function resize()
    local vp = Camera.ViewportSize
    if vp.X < 600 then mainScale.Scale = math.clamp(vp.X / 550, 0.6, 0.9) else mainScale.Scale = 1 end
end
resize()
Camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)

-- Header
local header=Instance.new("Frame"); header.Size=UDim2.new(1,0,0,40); header.BackgroundTransparency=1; header.Parent=root
local titleLbl=Instance.new("TextLabel"); titleLbl.Size=UDim2.new(1,-50,1,0); titleLbl.Position=UDim2.new(0,15,0,0); titleLbl.BackgroundTransparency=1; titleLbl.Text="DG Unified Hub · v4.1"; titleLbl.TextColor3=C.text; titleLbl.Font=FONT_BOLD; titleLbl.TextSize=13; titleLbl.TextXAlignment=Enum.TextXAlignment.Left; titleLbl.Parent=header

local closeBtn=Instance.new("TextButton"); closeBtn.Size=UDim2.new(0,30,0,30); closeBtn.Position=UDim2.new(1,-40,0,5); closeBtn.BackgroundColor3=C.surface2; closeBtn.Text="×"; closeBtn.TextColor3=C.textDim; closeBtn.Font=FONT_BOLD; closeBtn.TextSize=18; closeBtn.BorderSizePixel=0; closeBtn.Parent=header
corner(closeBtn,6)
closeBtn.Activated:Connect(function()
    for p in pairs(espCache) do clearESP(p) end
    if godConn then godConn:Disconnect() end
    gui:Destroy()
end)

-- Native Drag
local dragToggle, dragStart, startPos = false, nil, nil
header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragToggle = true; dragStart = input.Position; startPos = root.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragToggle = false end
        end)
    end
end)
UIS.InputChanged:Connect(function(input)
    if dragToggle and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- Sidebar (PADDING SEBELUM LAYOUT)
local sidebar=Instance.new("Frame"); sidebar.Size=UDim2.new(0,110,1,-50); sidebar.Position=UDim2.new(0,8,0,42); sidebar.BackgroundColor3=C.surface; sidebar.BorderSizePixel=0; sidebar.Parent=root
corner(sidebar,8); stroke(sidebar,C.border,1)
local spad=Instance.new("UIPadding"); spad.PaddingTop=UDim.new(0,8); spad.PaddingLeft=UDim.new(0,6); spad.PaddingRight=UDim.new(0,6); spad.Parent=sidebar
local slayout=Instance.new("UIListLayout"); slayout.Padding=UDim.new(0,2); slayout.Parent=sidebar

local content=Instance.new("Frame"); content.Size=UDim2.new(1,-126,1,-50); content.Position=UDim2.new(0,118,0,42); content.BackgroundTransparency=1; content.Parent=root
local pages={} local currentPage

local function makePage(name)
    local sc=Instance.new("ScrollingFrame"); sc.Size=UDim2.new(1,0,1,0); sc.BackgroundTransparency=1; sc.BorderSizePixel=0
    sc.CanvasSize=UDim2.new(0,0,0,0); sc.ScrollBarThickness=3; sc.AutomaticCanvasSize=Enum.AutomaticSize.Y; sc.Visible=false; sc.Parent=content
    local layout=Instance.new("UIListLayout"); layout.Padding=UDim.new(0,6); layout.Parent=sc
    pages[name]=sc; return sc
end
local function showPage(name) for n,sc in pairs(pages) do sc.Visible=(n==name) end currentPage=name end

local navButtons={}
local function addNav(name,label)
    local b=Instance.new("TextButton"); b.Size=UDim2.new(1,0,0,32); b.BackgroundColor3=C.surface; b.Text=" "..label; b.TextColor3=C.textDim; b.Font=FONT; b.TextSize=12; b.TextXAlignment=Enum.TextXAlignment.Left; b.BorderSizePixel=0; b.Parent=sidebar
    corner(b,6)
    b.Activated:Connect(function()
        showPage(name)
        for n,nb in pairs(navButtons) do
            Tween:Create(nb,TweenInfo.new(0.1),{BackgroundColor3=(n==name) and C.surface2 or C.surface, TextColor3=(n==name) and C.accent or C.textDim}):Play()
        end
    end)
    navButtons[name]=b
end
makePage("Combat"); makePage("Visuals"); makePage("Utility"); makePage("Cosmetics")
addNav("Combat"," Combat"); addNav("Visuals"," Visuals"); addNav("Utility"," Utility"); addNav("Cosmetics"," Cosmetics")

local function section(parent,text)
    local wrap=Instance.new("Frame"); wrap.Size=UDim2.new(1,0,0,0); wrap.AutomaticSize=Enum.AutomaticSize.Y; wrap.BackgroundTransparency=1; wrap.Parent=parent
    local lay=Instance.new("UIListLayout"); lay.Padding=UDim.new(0,4); lay.Parent=wrap
    local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(1,0,0,14); lbl.BackgroundTransparency=1; lbl.Text=text:upper(); lbl.TextColor3=C.textDim; lbl.Font=FONT_BOLD; lbl.TextSize=9; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=wrap
    return wrap
end

local function toggle(parent,label,key,cb)
    local row=Instance.new("TextButton"); row.Size=UDim2.new(1,0,0,36); row.BackgroundColor3=C.surface; row.Text=""; row.BorderSizePixel=0; row.Parent=parent; row.AutoButtonColor=false
    corner(row,6); stroke(row,C.border,1)
    local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(1,-50,1,0); lbl.Position=UDim2.new(0,10,0,0); lbl.BackgroundTransparency=1; lbl.Text=label; lbl.TextColor3=C.text; lbl.Font=FONT; lbl.TextSize=12; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=row
    local track=Instance.new("Frame"); track.Size=UDim2.new(0,34,0,18); track.Position=UDim2.new(1,-44,0.5,-9); track.BackgroundColor3=C.surface2; track.BorderSizePixel=0; track.Parent=row; track.ZIndex=2
    corner(track,9)
    local knob=Instance.new("Frame"); knob.Size=UDim2.new(0,14,0,14); knob.Position=UDim2.new(0,2,0.5,-7); knob.BackgroundColor3=C.textDim; knob.BorderSizePixel=0; knob.Parent=track; knob.ZIndex=3
    corner(knob,7)
    
    local function refresh()
        local on=CFG[key]
        Tween:Create(track,TweenInfo.new(0.1),{BackgroundColor3=on and C.accent or C.surface2}):Play()
        Tween:Create(knob,TweenInfo.new(0.1),{Position=on and UDim2.new(1,-16,0.5,-7) or UDim2.new(0,2,0.5,-7),BackgroundColor3=on and Color3.fromRGB(255,255,255) or C.textDim}):Play()
    end
    
    row.Activated:Connect(function() CFG[key]=not CFG[key]; refresh(); if cb then cb(CFG[key]) end end)
    row.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then Tween:Create(row,TweenInfo.new(0.05),{BackgroundColor3=C.surface2}):Play() end end)
    row.InputEnded:Connect(function(i) Tween:Create(row,TweenInfo.new(0.05),{BackgroundColor3=C.surface}):Play() end)
    refresh(); return row
end

local function slider(parent,label,key,min,max,step)
    local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,56); row.BackgroundColor3=C.surface; row.BorderSizePixel=0; row.Parent=parent
    corner(row,6); stroke(row,C.border,1)
    local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(1,-50,0,16); lbl.Position=UDim2.new(0,10,0,6); lbl.BackgroundTransparency=1; lbl.Text=label; lbl.TextColor3=C.text; lbl.Font=FONT; lbl.TextSize=12; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=row
    local val=Instance.new("TextLabel"); val.Size=UDim2.new(0,34,0,16); val.Position=UDim2.new(1,-44,0,6); val.BackgroundColor3=C.surface2; val.Text=tostring(CFG[key]); val.TextColor3=C.accent; val.Font=FONT_BOLD; val.TextSize=11; val.TextXAlignment=Enum.TextXAlignment.Center; val.Parent=row
    corner(val,4)
    local track=Instance.new("Frame"); track.Size=UDim2.new(1,-20,0,8); track.Position=UDim2.new(0,10,0,36); track.BackgroundColor3=C.surface2; track.BorderSizePixel=0; track.Parent=row
    corner(track,4)
    local fill=Instance.new("Frame"); fill.Size=UDim2.new((CFG[key]-min)/(max-min),0,1,0); fill.BackgroundColor3=C.accent; fill.BorderSizePixel=0; fill.Parent=track
    corner(fill,4)
    local knob=Instance.new("Frame"); knob.Size=UDim2.new(0,18,0,18); knob.Position=UDim2.new((CFG[key]-min)/(max-min),-9,0.5,-9); knob.BackgroundColor3=Color3.fromRGB(255,255,255); knob.BorderSizePixel=0; knob.Parent=track; knob.ZIndex=3
    corner(knob,9); stroke(knob,C.accent,2)
    
    local hitbox = Instance.new("TextButton"); hitbox.Size=UDim2.new(1,0,0,32); hitbox.Position=UDim2.new(0,0,0.5,-16); hitbox.BackgroundTransparency=1; hitbox.Text=""; hitbox.ZIndex=10; hitbox.Parent=row
    local dragging=false
    local function updateValue(posX)
        local rel=math.clamp((posX - track.AbsolutePosition.X)/track.AbsoluteSize.X, 0, 1)
        local v=min+math.floor((rel*(max-min))/step+0.5)*step
        CFG[key]=v; val.Text=tostring(v); fill.Size=UDim2.new(rel,0,1,0); knob.Position=UDim2.new(rel,-9,0.5,-9)
    end
    hitbox.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=true; updateValue(i.Position.X) end end)
    UIS.InputChanged:Connect(function(i) if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then updateValue(i.Position.X) end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=false end end)
    return row
end

local function button(parent,label,cb)
    local b=Instance.new("TextButton"); b.Size=UDim2.new(1,0,0,32); b.BackgroundColor3=C.surface2; b.Text=label; b.TextColor3=C.text; b.Font=FONT; b.TextSize=11; b.BorderSizePixel=0; b.Parent=parent; b.AutoButtonColor=false
    corner(b,6)
    b.Activated:Connect(cb); return b
end

-- Populate
local c1=section(pages["Combat"],"Precision")
toggle(c1,"Aimbot","Aimbot")
slider(c1,"Aimbot FOV","AimbotFOV",20,300,5)
slider(c1,"Aimbot Smooth","AimbotSmooth",1,100,1)
local c2=section(pages["Combat"],"Defense")
toggle(c2,"Auto-Parry","AutoParry",function(on) if not on then for k in pairs(parryTracked) do parryTracked[k]=nil end end end)
slider(c2,"Parry Range","ParryRange",5,50,1)
slider(c2,"Parry Window %","ParryWindow",10,60,1)
toggle(c2,"Auto-Dodge","AutoDodge")
toggle(c2,"Anti Posture","AntiPosture")
local c3=section(pages["Combat"],"Offense")
toggle(c3,"Kill Aura","KillAura")
slider(c3,"Kill Aura Range","KillAuraRange",5,40,1)
toggle(c3,"God Mode","GodMode",function(on) if on then enableGod() else disableGod() end end)

local v1=section(pages["Visuals"],"Overlay")
toggle(v1,"ESP Box","ESP"); toggle(v1,"Nametags","Nametags"); toggle(v1,"Range Visual","RangeVisual")

local u1=section(pages["Utility"],"Automation")
toggle(u1,"Auto Buy","AutoBuy"); toggle(u1,"Claim Rewards","ClaimRewards")

local co1=section(pages["Cosmetics"],"Weapons")
button(co1,"Equip Katana",function() equipCosmetic("Katana") end)
button(co1,"Equip Naginata",function() equipCosmetic("Naginata") end)
button(co1,"Equip Dagger",function() equipCosmetic("Dagger") end)

showPage("Combat")
for n,nb in pairs(navButtons) do Tween:Create(nb,TweenInfo.new(0.1),{BackgroundColor3=(n=="Combat") and C.surface2 or C.surface, TextColor3=(n=="Combat") and C.accent or C.textDim}):Play() end

-- ================= LOOPS =================
RunService.RenderStepped:Connect(function()
    tickESP()
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
