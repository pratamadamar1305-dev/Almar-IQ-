-- DG Hub v37 — Auto-Execute Parry (No UI)
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS         = game:GetService("ReplicatedStorage")
local LP         = Players.LocalPlayer

-- [1] AMBIL REMOTE ASLI DARI HASIL SCAN
local Remotes = RS:WaitForChild("Remotes")
local PCRequest = Remotes:WaitForChild("PlayerCharacter"):WaitForChild("Request")
local StartBlock = PCRequest:WaitForChild("StartBlock")
local ReleaseBlock = PCRequest:WaitForChild("ReleaseBlock")

-- [2] FUNGSI PARRY INSTAN
local function fireParry()
    pcall(function()
        StartBlock:FireServer()
        task.wait(0.05) 
        ReleaseBlock:FireServer()
    end)
end

-- [3] COMBAT ENGINE (Langsung Jalan)
local parryCooldown={}
RunService.PreSimulation:Connect(function()
    -- Cek karakter kita sendiri
    local myChar = LP.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end
    
    -- Fungsi bantu
    local function alive(p) local h=p and p.Character and p.Character:FindFirstChildOfClass("Humanoid"); return h and h.Health>0 end
    local function enemy(p) if p==LP then return false end local t,mt=p:GetAttribute("Team"),LP:GetAttribute("Team") if t and mt then return t~=mt end return true end
    
    -- Loop semua pemain
    for _,p in ipairs(Players:GetPlayers()) do
        if p==LP or not alive(p) or not enemy(p) then continue end
        
        local eHRP = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
        -- Jarak maksimal 50 studs
        if not eHRP or (eHRP.Position - myHRP.Position).Magnitude > 50 then continue end
        
        local animator = p.Character and p.Character:FindFirstChild("Animator")
        if not animator then continue end
        
        -- Cek animasi lawan
        for _,t in ipairs(animator:GetPlayingAnimationTracks()) do
            if not t.IsPlaying then continue end
            
            local targetTime = nil
            -- Timing Parry berdasarkan durasi animasi (0.933s & 1.2s)
            if math.abs(t.Length - 0.933) < 0.05 then 
                targetTime = 0.15
            elseif math.abs(t.Length - 1.2) < 0.05 then 
                targetTime = 0.42 
            end
            
            -- Eksekusi Parry
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

print("[DG] Auto-Parry v37 Aktif! Silakan masuk duel.")
