-- DG Hub v36 — UI Full Kontras
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local RS         = game:GetService("ReplicatedStorage")
local LP         = Players.LocalPlayer

local Remotes = RS:WaitForChild("Remotes")
local PCRequest = Remotes:WaitForChild("PlayerCharacter"):WaitForChild("Request")
local StartBlock = PCRequest:WaitForChild("StartBlock")
local ReleaseBlock = PCRequest:WaitForChild("ReleaseBlock")

local CFG = { AutoParry = false }

local function fireParry()
    pcall(function()
        StartBlock:FireServer()
        task.wait(0.05) 
        ReleaseBlock:FireServer()
    end)
end

-- COMBAT ENGINE
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

-- UI PRIMITIF (ANTI GAGAL)
local gui = Instance.new("ScreenGui")
gui.Name = "DG_UI_Simple"
gui.ResetOnSpawn = false
gui.Parent = LP:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 200, 0, 100)
frame.Position = UDim2.new(0.5, -100, 0.2, 0) -- Di tengah atas
frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0) -- Hitam pekat
frame.BorderSizePixel = 2
frame.BorderColor3 = Color3.fromRGB(255, 255, 255)
frame.Parent = gui

-- Pake TextBox biar pasti muncul teksnya
local toggleBtn = Instance.new("TextBox")
toggleBtn.Size = UDim2.new(1, -20, 0, 40)
toggleBtn.Position = UDim2.new(0, 10, 0, 10)
toggleBtn.BackgroundColor3 = Color3.fromRGB(200, 0, 0) -- Merah = OFF
toggleBtn.Text = "PARRY: OFF"
toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 16
toggleBtn.TextEditable = false -- Biar ga bisa diketik
toggleBtn.Parent = frame

local testBtn = Instance.new("TextBox")
testBtn.Size = UDim2.new(1, -20, 0, 30)
testBtn.Position = UDim2.new(0, 10, 0, 55)
testBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
testBtn.Text = "TES MANUAL"
testBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
testBtn.Font = Enum.Font.GothamBold
testBtn.TextSize = 14
testBtn.TextEditable = false
testBtn.Parent = frame

-- LOGIKA KLIK (Pake InputBegan biar respon di HP)
toggleBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        CFG.AutoParry = not CFG.AutoParry
        if CFG.AutoParry then
            toggleBtn.Text = "PARRY: ON"
            toggleBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 0) -- Hijau = ON
        else
            toggleBtn.Text = "PARRY: OFF"
            toggleBtn.BackgroundColor3 = Color3.fromRGB(200, 0, 0) -- Merah = OFF
        end
    end
end)

testBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        testBtn.Text = "MUKUL!"
        fireParry()
        task.wait(0.5)
        testBtn.Text = "TES MANUAL"
    end
end)
