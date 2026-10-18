-- DG Hub v30 — Absolute Mobile Target Tap
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local Workspace  = game:GetService("Workspace")
local VIM        = game:GetService("VirtualInputManager")
local Tween      = game:GetService("TweenService")
local LP         = Players.LocalPlayer
local Camera     = Workspace.CurrentCamera
local PGui       = LP:WaitForChild("PlayerGui")

local CFG = {
    AutoParry = false,
    ParryChance = 100,
}

-- Koordinat default ngikutin screenshot lo (kanan layar, di atas Dodge)
local targetX, targetY = 1250, 450 
local isCalibrating = false

local function tapParry()
    pcall(function()
        -- 1. Tembak pakai VIM Mouse Click
        VIM:SendMouseButtonEvent(targetX, targetY, 0, true, game, 0)
        task.wait(0.03)
        VIM:SendMouseButtonEvent(targetX, targetY, 0, false, game, 0)
    end)
end

-- [2] COMBAT ENGINE
local parryCooldown={}
RunService.PreSimulation:Connect(function()
    if not CFG.AutoParry then return end
    local myChar = LP.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end
    
    local function alive(p) local h=p and p.Character and p.Character:FindFirstChildOfClass("Humanoid"); return h and h.Health>0 end
    local function enemy(p) if p==LP then return false end local t,mt=p:GetAttribute("Team"),LP:GetAttribute("Team") if t and mt then return t~=mt end return true end
    
    for _,p in ipairs(Players:GetPlayers()) do
        if p==LP or not alive(p) or not enemy(p) then continue end
        local eHRP = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
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
                            tapParry() 
                        end
                        parryCooldown[p.UserId] = true
                        task.delay(0.6, function() parryCooldown[p.UserId] = nil end)
                    end
                end
            end
        end
    end
end)

-- [3] UI DENGAN SLIDER KALIBRASI (Biar Ga Meleset)
local C={bg=Color3.fromRGB(14,14,18),s=Color3.fromRGB(22,22,28),s2=Color3.fromRGB(30,30,38),a=Color3.fromRGB(90,140,255),t=Color3.fromRGB(230,230,240)}
local F=Enum.Font.Gotham; local FB=Enum.Font.GothamBold
local function c(o,r) local x=Instance.new("UICorner"); x.CornerRadius=UDim.new(0,r or 6); x.Parent=o end
local function bindClick(btn, cb) btn.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then cb() end end) end

local guiMain=Instance.new("ScreenGui"); guiMain.Name="DG_Main_v30"; guiMain.ResetOnSpawn=false; guiMain.DisplayOrder=999; guiMain.Parent=PGui
local root=Instance.new("Frame"); root.Size=UDim2.new(0,280,0,220); root.Position=UDim2.new(0.5,-140,0.2,0); root.BackgroundColor3=C.bg; root.BorderSizePixel=0; root.Active=true; root.Parent=guiMain; c(root,10)

local hdr=Instance.new("Frame"); hdr.Size=UDim2.new(1,0,0,40); hdr.BackgroundTransparency=1; hdr.Parent=root
local title=Instance.new("TextLabel"); title.Size=UDim2.new(1,-40,1,0); title.Position=UDim2.new(0,12,0,0); title.BackgroundTransparency=1; title.Text="DG Hub v30 (Coord Tap)"; title.TextColor3=C.t; title.Font=FB; title.TextSize=14; title.TextXAlignment=Enum.TextXAlignment.Left; title.Parent=hdr

local function drag(frame, btn)
    local dragging, start, startPos
    btn.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=true; start=i.Position; startPos=frame.Position end end)
    UIS.InputChanged:Connect(function(i) if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then local d=i.Position-start; frame.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y) end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=false end end)
end
drag(root, title)

local cls=Instance.new("TextButton"); cls.Size=UDim2.new(0,30,0,30); cls.Position=UDim2.new(1,-40,0,5); cls.BackgroundColor3=C.s2; cls.Text="×"; cls.TextColor3=C.t; cls.Font=FB; cls.TextSize=18; cls.Parent=hdr; c(cls,6)
bindClick(cls, function() guiMain:Destroy() end)

-- Fungsi Tombol Set Koordinat (Cuma nyimpen, ga nge-tap game)
local btnSet = Instance.new("TextButton"); btnSet.Size=UDim2.new(1,-20,0,40); btnSet.Position=UDim2.new(0,10,0,50); btnSet.BackgroundColor3=C.s2; btnSet.Text="Tap di sini pas lo mau nembak Parry"; btnSet.TextColor3=C.t; btnSet.Font=FB; btnSet.TextSize=13; btnSet.Parent=root; c(btnSet,6)

local tx, ty = Instance.new("TextBox"), Instance.new("TextBox")
tx.Size = UDim2.new(0, 60, 0, 30); tx.Position = UDim2.new(0, 10, 0, 100); tx.BackgroundColor3 = C.s; tx.Text = tostring(targetX); tx.TextColor3 = C.t; tx.Parent = root
ty.Size = UDim2.new(0, 60, 0, 30); ty.Position = UDim2.new(0, 80, 0, 100); ty.BackgroundColor3 = C.s; ty.Text = tostring(targetY); ty.TextColor3 = C.t; ty.Parent = root

local tgl = Instance.new("TextButton"); tgl.Size=UDim2.new(1,-20,0,40); tgl.Position=UDim2.new(0,10,0,145); tgl.BackgroundColor3=C.s; tgl.Text="Auto-Parry [OFF]"; tgl.TextColor3=C.t; tgl.Font=FB; tgl.TextSize=14; tgl.Parent=root; c(tgl,6)

-- KALIBRASI OTOMATIS TANPA GANGGU GAME
local tapMode = false
bindClick(btnSet, function()
    tapMode = true
    btnSet.Text = "Silakan tap tombol PARRY di layar game"
    btnSet.BackgroundColor3 = Color3.fromRGB(200, 100, 0)
end)

UIS.InputBegan:Connect(function(input)
    if tapMode and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) then
        targetX = input.Position.X
        targetY = input.Position.Y
        tx.Text = tostring(math.floor(targetX))
        ty.Text = tostring(math.floor(targetY))
        tapMode = false
        btnSet.Text = "Koordinat Diset! Tekan Auto-Parry"
        btnSet.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
        print("[DG] Target diset ke X:"..targetX.." Y:"..targetY)
    end
end)

tx.FocusLost:Connect(function() targetX = tonumber(tx.Text) or targetX end)
ty.FocusLost:Connect(function() targetY = tonumber(ty.Text) or targetY end)

bindClick(tgl, function() 
    CFG.AutoParry = not CFG.AutoParry
    tgl.Text = "Auto-Parry ["..(CFG.AutoParry and "ON" or "OFF").."]"
    tgl.BackgroundColor3 = CFG.AutoParry and C.a or C.s
end)
