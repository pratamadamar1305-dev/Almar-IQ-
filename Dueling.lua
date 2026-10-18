-- DG Hub v34 — Fixed UI & Remote Test
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local RS         = game:GetService("ReplicatedStorage")
local Tween      = game:GetService("TweenService")
local LP         = Players.LocalPlayer

-- [1] AMBIL REMOTE ASLI
local Remotes = RS:WaitForChild("Remotes")
local PCRequest = Remotes:WaitForChild("PlayerCharacter"):WaitForChild("Request")

local StartBlock = PCRequest:WaitForChild("StartBlock")
local ReleaseBlock = PCRequest:WaitForChild("ReleaseBlock")

local CFG = {
    AutoParry = false,
    ParryChance = 100,
}

-- [2] FUNGSI PARRY
local function fireParry()
    pcall(function()
        StartBlock:FireServer()
        task.wait(0.05) 
        ReleaseBlock:FireServer()
    end)
end

-- [3] COMBAT ENGINE
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
                            fireParry() 
                        end
                        parryCooldown[p.UserId] = true
                        task.delay(0.6, function() parryCooldown[p.UserId] = nil end)
                    end
                end
            end
        end
    end
end)

-- [4] UI SIMPLE (ANTI GAGAL)
local C={bg=Color3.fromRGB(14,14,18),s=Color3.fromRGB(22,22,28),s2=Color3.fromRGB(30,30,38),a=Color3.fromRGB(90,140,255),t=Color3.fromRGB(230,230,240)}
local F=Enum.Font.GothamBold
local function c(o,r) local x=Instance.new("UICorner"); x.CornerRadius=UDim.new(0,r or 6); x.Parent=o end

local guiMain=Instance.new("ScreenGui"); guiMain.Name="DG_Main_v34"; guiMain.ResetOnSpawn=false; guiMain.DisplayOrder=999; guiMain.Parent=LP:WaitForChild("PlayerGui")

-- Frame utama dengan ukuran fix
local root=Instance.new("Frame")
root.Size=UDim2.new(0,260,0,200)
root.Position=UDim2.new(0.5,-130,0.3,0) -- Posisi agak ke atas biar ga ketutup
root.BackgroundColor3=C.bg
root.BorderSizePixel=0
root.Parent=guiMain
c(root,10)

local title=Instance.new("TextLabel")
title.Size=UDim2.new(1,0,0,40)
title.BackgroundColor3=C.s
title.Text="DG Hub v34 (Test Remote)"
title.TextColor3=C.t
title.Font=F
title.TextSize=14
title.Parent=root
c(title,6)

-- TOMBOL TEST MANUAL
local btnTest = Instance.new("TextButton")
btnTest.Size=UDim2.new(1,-20,0,40)
btnTest.Position=UDim2.new(0,10,0,50)
btnTest.BackgroundColor3=Color3.fromRGB(200, 100, 0) -- Warna Oranye
btnTest.Text="1. TES PARRY MANUAL (KLIK INI)"
btnTest.TextColor3=C.t
btnTest.Font=F
btnTest.TextSize=12
btnTest.Parent=root
c(btnTest,6)
btnTest.MouseButton1Click:Connect(function() fireParry() end)

-- TOGGLE AUTO
local tgl = Instance.new("TextButton")
tgl.Size=UDim2.new(1,-20,0,40)
tgl.Position=UDim2.new(0,10,0,100)
tgl.BackgroundColor3=C.s
tgl.Text="Auto-Parry [OFF]"
tgl.TextColor3=C.t
tgl.Font=F
tgl.TextSize=14
tgl.Parent=root
c(tgl,6)

tgl.MouseButton1Click:Connect(function() 
    CFG.AutoParry = not CFG.AutoParry
    tgl.Text = "Auto-Parry ["..(CFG.AutoParry and "ON" or "OFF").."]"
    tgl.BackgroundColor3 = CFG.AutoParry and C.a or C.s
end)

-- TOMBOL CLOSE
local cls=Instance.new("TextButton")
cls.Size=UDim2.new(1,-20,0,30)
cls.Position=UDim2.new(0,10,0,150)
cls.BackgroundColor3=C.s2
cls.Text="TUTUP MENU"
cls.TextColor3=C.t
cls.Font=F
cls.TextSize=12
cls.Parent=root
c(cls,6)
cls.MouseButton1Click:Connect(function() guiMain:Destroy() end)
