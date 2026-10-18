-- DG Hub v24 — Visual Button Injector (Berdasarkan Screenshot)
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local Workspace  = game:GetService("Workspace")
local RS         = game:GetService("ReplicatedStorage")
local VIM        = game:GetService("VirtualInputManager")
local Tween      = game:GetService("TweenService")
local LP         = Players.LocalPlayer
local Camera     = Workspace.CurrentCamera
local PGui       = LP:WaitForChild("PlayerGui")
local CoreGui    = game:GetService("CoreGui")

local CFG = {
    ESP=false, Nametags=false,
    Aimbot=false, AimbotFOV=120, AimbotSmooth=22,
    AutoParry=false, ParryChance=100,
    AutoDodge=false, GodMode=false, KillAura=false, KillAuraRange=14,
}

local function alive(p) local h=p and p.Character and p.Character:FindFirstChildOfClass("Humanoid"); return h and h.Health>0 end
local function hrp(p) return p and p.Character and p.Character:FindFirstChild("HumanoidRootPart") end
local function enemy(p) if p==LP then return false end local t,mt=p:GetAttribute("Team"),LP:GetAttribute("Team") if t and mt then return t~=mt end return true end

-- [1] ESP (Sama kayak v23)
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
RunService.RenderStepped:Connect(function() if CFG.ESP then updateESP() end end)

-- [2] AUTO SCAN VISUAL BUTTON
local parryBtn = nil
local function findParryButtonByPosition()
    -- Scan semua GUI (PlayerGui & CoreGui) cari ImageButton atau TextButton
    local folders = {PGui, CoreGui}
    
    for _, folder in ipairs(folders) do
        for _, obj in ipairs(folder:GetDescendants()) do
            if obj:IsA("ImageButton") or obj:IsA("TextButton") then
                if obj.Visible and obj.AbsoluteSize.X > 0 then
                    -- Cek apakah ada di area kanan layar bagian tengah/bawah (tempat ikon parry di screenshot)
                    local pos = obj.AbsolutePosition
                    local screenSize = Camera.ViewportSize
                    
                    -- Area: X > 60% layar, Y > 40% layar
                    if pos.X > (screenSize.X * 0.6) and pos.Y > (screenSize.Y * 0.4) then
                        -- Kalo namanya ada text parry/block, langsung ambil
                        local name = string.lower(obj.Name)
                        if name:find("parry") or name:find("block") or name:find("guard") then
                            parryBtn = obj
                            print("[DG] FOUND BY NAME: " .. obj:GetFullName())
                            return
                        end
                    end
                end
            end
        end
    end
    
    -- Kalau nggak ketemu by name, kita tembak ImageButton pertama yang ada di area itu
    for _, folder in ipairs(folders) do
        for _, obj in ipairs(folder:GetDescendants()) do
            if obj:IsA("ImageButton") and obj.Visible and obj.AbsoluteSize.X > 0 then
                local pos = obj.AbsolutePosition
                local screenSize = Camera.ViewportSize
                if pos.X > (screenSize.X * 0.6) and pos.Y > (screenSize.Y * 0.4) then
                    parryBtn = obj
                    print("[DG] FOUND BY POSITION: " .. obj:GetFullName())
                    return
                end
            end
        end
    end
    
    print("[DG] PARRY BUTTON NOT FOUND. Coba pindah tab atau masuk arena dulu.")
end

-- Fungsi Tap Button
local function tapParryButton()
    if not parryBtn or not parryBtn.Parent then 
        findParryButtonByPosition() -- Coba scan ulang kalau tombolnya ilang (misal abis respawn)
        if not parryBtn or not parryBtn.Parent then return end
    end
    
    -- Trik pancing klik
    pcall(function() parryBtn.Activated:Fire() end)
    pcall(function() parryBtn.MouseButton1Click:Fire() end)
    pcall(function() parryBtn:InputBegan(Enum.UserInputType.Touch) end)
    pcall(function() 
        -- Simulasi Click lewat VIM
        local center = parryBtn.AbsolutePosition + (parryBtn.AbsoluteSize / 2)
        VIM:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 0)
        task.wait(0.05)
        VIM:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 0)
    end)
end

-- [3] COMBAT ENGINE (Auto Parry 0.933 / 1.2)
local parryCooldown={}
RunService.PreSimulation:Connect(function()
    if not CFG.AutoParry then return end
    local myChar = LP.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end
    
    for _,p in ipairs(Players:GetPlayers()) do
        if p==LP or not alive(p) or not enemy(p) then continue end
        local eHRP = hrp(p)
        if not eHRP or (eHRP.Position - myHRP.Position).Magnitude > 50 then continue end
        
        local animator = p.Character and p.Character:FindFirstChild("Animator")
        if not animator then continue end
        
        for _,t in ipairs(animator:GetPlayingAnimationTracks()) do
            if not t.IsPlaying then continue end
            
            local targetTime = nil
            if math.abs(t.Length - 0.933) < 0.05 then targetTime = 0.15
            elseif math.abs(t.Length - 1.2) < 0.05 then targetTime = 0.42 end
            
            if targetTime and t.TimePosition > 0 then
                if CFG.AutoParry and not parryCooldown[p.UserId] then
                    if t.TimePosition >= targetTime and t.TimePosition <= targetTime + 0.05 then
                        if math.random(1, 100) <= CFG.ParryChance then
                            tapParryButton()
                        end
                        parryCooldown[p.UserId] = true
                        task.delay(0.6, function() parryCooldown[p.UserId] = nil end)
                    end
                end
            end
        end
    end
end)

-- [4] UTILITY & UI (Sama kayak v23)
-- (UI disederhanakan biar lo bisa langsung nyoba, kita skip God mode & Aim buat ngetes parry dulu)
local C={bg=Color3.fromRGB(14,14,18),s=Color3.fromRGB(22,22,28),s2=Color3.fromRGB(30,30,38),a=Color3.fromRGB(90,140,255),t=Color3.fromRGB(230,230,240)}
local F=Enum.Font.Gotham; local FB=Enum.Font.GothamBold
local function c(o,r) local x=Instance.new("UICorner"); x.CornerRadius=UDim.new(0,r or 6); x.Parent=o end
local function bindClick(btn, cb) btn.Activated:Connect(cb) end

local guiToggle=Instance.new("ScreenGui"); guiToggle.Name="DG_Toggle_v24"; guiToggle.ResetOnSpawn=false; guiToggle.DisplayOrder=2147483647; guiToggle.Parent=PGui
local floatBtn = Instance.new("TextButton"); floatBtn.Size = UDim2.new(0, 100, 0, 40); floatBtn.Position = UDim2.new(0.5, -50, 0, 10); floatBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 0); floatBtn.Text = "OPEN MENU"; floatBtn.TextSize = 14; floatBtn.TextColor3 = Color3.new(1,1,1); floatBtn.Font = FB; floatBtn.BorderSizePixel = 0; floatBtn.Visible = false; floatBtn.Parent = guiToggle; c(floatBtn, 6)

local guiMain=Instance.new("ScreenGui"); guiMain.Name="DG_Main_v24"; guiMain.ResetOnSpawn=false; guiMain.DisplayOrder=999; guiMain.Parent=PGui
local root=Instance.new("Frame"); root.Size=UDim2.new(0,260,0,160); root.Position=UDim2.new(0.5,-130,0.5,-80); root.BackgroundColor3=C.bg; root.BorderSizePixel=0; root.Active=true; root.Parent=guiMain; c(root,10)

local hdr=Instance.new("Frame"); hdr.Size=UDim2.new(1,0,0,40); hdr.BackgroundTransparency=1; hdr.Parent=root
local title=Instance.new("TextLabel"); title.Size=UDim2.new(1,-40,1,0); title.Position=UDim2.new(0,12,0,0); title.BackgroundTransparency=1; title.Text="DG Hub v24 (Visual Inject)"; title.TextColor3=C.t; title.Font=FB; title.TextSize=14; title.TextXAlignment=Enum.TextXAlignment.Left; title.Parent=hdr

local function drag(frame, btn)
    local dragging, start, startPos
    btn.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=true; start=i.Position; startPos=frame.Position end end)
    UIS.InputChanged:Connect(function(i) if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then local d=i.Position-start; frame.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y) end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=false end end)
end
drag(root, title)

local cls=Instance.new("TextButton"); cls.Size=UDim2.new(0,30,0,30); cls.Position=UDim2.new(1,-40,0,5); cls.BackgroundColor3=C.s2; cls.Text="×"; cls.TextColor3=C.t; cls.Font=FB; cls.TextSize=18; cls.Parent=hdr; c(cls,6)

local uiOpen = true
local function toggleUI() uiOpen = not uiOpen; root.Visible = uiOpen; floatBtn.Visible = not uiOpen end
bindClick(floatBtn, toggleUI)
bindClick(cls, function() guiMain:Destroy(); guiToggle:Destroy() end)

local function addBtn(parent,label,cb)
    local b=Instance.new("TextButton"); b.Size=UDim2.new(1,-20,0,40); b.Position=UDim2.new(0,10,0,50); b.BackgroundColor3=C.s2; b.Text=label; b.TextColor3=C.t; b.Font=FB; b.TextSize=14; b.Parent=parent; c(b,6); bindClick(b, cb)
end
local function addBtn2(parent,label,cb)
    local b=Instance.new("TextButton"); b.Size=UDim2.new(1,-20,0,40); b.Position=UDim2.new(0,10,0,100); b.BackgroundColor3=Color3.fromRGB(0,150,0); b.Text=label; b.TextColor3=C.t; b.Font=FB; b.TextSize=14; b.Parent=parent; c(b,6); bindClick(b, cb)
end

addBtn(root, "1. SCAN PARRY BUTTON", findParryButtonByPosition)
local tgl = Instance.new("TextButton"); tgl.Size=UDim2.new(1,-20,0,40); tgl.Position=UDim2.new(0,10,0,100); tgl.BackgroundColor3=C.s; tgl.Text="Auto-Parry [OFF]"; tgl.TextColor3=C.t; tgl.Font=FB; tgl.TextSize=14; tgl.Parent=root; c(tgl,6)
bindClick(tgl, function() 
    CFG.AutoParry = not CFG.AutoParry
    tgl.Text = "Auto-Parry ["..(CFG.AutoParry and "ON" or "OFF").."]"
    tgl.BackgroundColor3 = CFG.AutoParry and C.a or C.s
end)
