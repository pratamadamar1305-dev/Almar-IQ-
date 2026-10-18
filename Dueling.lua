-- DG Hub v40 — Pure Background Parry (No UI)
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS         = game:GetService("ReplicatedStorage")
local LP         = Players.LocalPlayer

-- [1] AMBIL REMOTE
local Remotes = RS:WaitForChild("Remotes")
local PCRequest = Remotes:WaitForChild("PlayerCharacter"):WaitForChild("Request")
local StartBlock = PCRequest:WaitForChild("StartBlock")
local ReleaseBlock = PCRequest:WaitForChild("ReleaseBlock")

-- [2] FUNGSI PARRY (Nembak pakai Parameter)
local function fireParry()
    pcall(function()
        local myHRP = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        local myCFrame = myHRP and myHRP.CFrame or CFrame.new()
        
        -- 1. Tahan Block (StartBlock)
        StartBlock:FireServer()
        
        -- 2. Lepas Block (ReleaseBlock) setelah 0.06 detik
        -- Kita kasih parameter CFrame & tick() buat jaga-jaga kalau server minta
        task.wait(0.06) 
        ReleaseBlock:FireServer(myCFrame, tick())
    end)
end

-- [3] COMBAT ENGINE
local parryCooldown={}
RunService.PreSimulation:Connect(function()
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
            -- Timing (0.933s = 0.15 | 1.2s = 0.42)
            if math.abs(t.Length - 0.933) < 0.05 then targetTime = 0.15
            elseif math.abs(t.Length - 1.2) < 0.05 then targetTime = 0.42 end
            
            if targetTime and t.TimePosition > 0 then
                if not parryCooldown[p.UserId] then
                    if t.TimePosition >= targetTime and t.TimePosition <= targetTime + 0.05 then
                        -- LANGSUNG EKSEKUSI TANPA CEK UI
                        fireParry() 
                        parryCooldown[p.UserId] = true
                        task.delay(0.6, function() parryCooldown[p.UserId] = nil end)
                    end
                end
            end
        end
    end
end)

print("[DG] Auto-Parry Background Aktif! Silakan masuk duel.")
