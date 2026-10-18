-- DG Hub v43 — Smart Parry (Anti-Salah Tangkis)
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS         = game:GetService("ReplicatedStorage")
local LP         = Players.LocalPlayer

-- [1] REMOTE ASLI
local Remotes = RS:WaitForChild("Remotes")
local PCRequest = Remotes:WaitForChild("PlayerCharacter"):WaitForChild("Request")
local StartBlock = PCRequest:WaitForChild("StartBlock")
local ReleaseBlock = PCRequest:WaitForChild("ReleaseBlock")

-- [2] FUNGSI PARRY
local function fireParry()
    pcall(function()
        StartBlock:FireServer()
        task.wait(0.03) 
        ReleaseBlock:FireServer()
    end)
end

-- [3] AUTO-PARRY ENGINE
local parryCooldown={}
RunService.PreSimulation:Connect(function()
    local myChar = LP.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end
    
    local function alive(p) local h=p and p.Character and p.Character:FindFirstChildOfClass("Humanoid"); return h and h.Health>0 end
    
    for _,p in ipairs(Players:GetPlayers()) do
        if p==LP or not alive(p) then continue end
        
        local eHRP = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
        if not eHRP then continue end
        
        -- [LOGIKA 1] JARAK: Cuma nangkis kalau jarak di bawah 15 studs (1 tebasan pedang)
        local distance = (eHRP.Position - myHRP.Position).Magnitude
        if distance > 15 then continue end
        
        -- [LOGIKA 2] ARAH HADAP: Pastiin lawan ngadep ke kita (Bukan kita yang ngadep lawan)
        local lookVector = eHRP.CFrame.LookVector
        local directionToMe = (myHRP.Position - eHRP.Position).Unit
        local dotProduct = lookVector:Dot(directionToMe)
        
        -- Dot Product > 0.5 artinya lawan beneran ngehadapin kita (60 derajat)
        if dotProduct < 0.5 then continue end
        
        -- LOGIKA ANIMASI
        local animator = p.Character and p.Character:FindFirstChild("Animator")
        if not animator then continue end
        
        for _,t in ipairs(animator:GetPlayingAnimationTracks()) do
            if not t.IsPlaying then continue end
            
            local targetTime = nil
            if math.abs(t.Length - 0.933) < 0.05 then targetTime = 0.15
            elseif math.abs(t.Length - 1.2) < 0.05 then targetTime = 0.42 end
            
            if targetTime and t.TimePosition > 0 then
                if not parryCooldown[p.UserId] then
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

print("[DG] Smart Auto-Parry v43 Aktif di background.")
