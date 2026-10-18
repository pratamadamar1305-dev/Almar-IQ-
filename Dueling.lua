-- DG Hub v38 — UI Fix & Auto Parry
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS         = game:GetService("ReplicatedStorage")
local LP         = Players.LocalPlayer
local PGui       = LP:WaitForChild("PlayerGui")

-- [1] AMBIL REMOTE
local Remotes = RS:WaitForChild("Remotes")
local PCRequest = Remotes:WaitForChild("PlayerCharacter"):WaitForChild("Request")
local StartBlock = PCRequest:WaitForChild("StartBlock")
local ReleaseBlock = PCRequest:WaitForChild("ReleaseBlock")

local CFG = { AutoParry = false } -- Default mati biar aman

local function fireParry()
    pcall(function()
        StartBlock:FireServer()
        task.wait(0.05) 
        ReleaseBlock:FireServer()
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
                        fireParry() 
                        parryCooldown[p.UserId] = true
                        task.delay(0.6, function() parryCooldown[p.UserId] = nil end)
                    end
                end
            end
        end
    end
end)

-- [3] UI SUPER SEDERHANA (PASTI MUNCUL)
local gui = Instance.new("ScreenGui")
gui.Name = "DG_UI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999
gui.Parent = PGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 150, 0, 50)
frame.Position = UDim2.new(0, 20, 0, 100) -- Kiri atas biar ga ketutup
frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0) -- Hitam
frame.BorderSizePixel = 0
frame.Parent = gui

local btn = Instance.new("TextButton")
btn.Size = UDim2.new(1, 0, 1, 0)
btn.BackgroundColor3 = Color3.fromRGB(200, 0, 0) -- Merah (OFF)
btn.Text = "PARRY: OFF"
btn.TextColor3 = Color3.fromRGB(255, 255, 255)
btn.Font = Enum.Font.SourceSansBold
btn.TextSize = 18
btn.Parent = frame

btn.MouseButton1Click:Connect(function()
    CFG.AutoParry = not CFG.AutoParry
    if CFG.AutoParry then
        btn.Text = "PARRY: ON"
        btn.BackgroundColor3 = Color3.fromRGB(0, 200, 0) -- Hijau (ON)
    else
        btn.Text = "PARRY: OFF"
        btn.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
    end
end)

print("[DG] UI v38 berhasil dimuat. Cari tombol PARRY di kiri atas layar.")
