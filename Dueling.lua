-- DG Hub v44 — Direct UI Button Bypass (No VIM)
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local LP         = Players.LocalPlayer
local PGui       = LP:WaitForChild("PlayerGui")
local CoreGui    = game:GetService("CoreGui")

-- [1] CARI TOMBOL PARRY YANG ASLI DI LAYAR
local parryBtn = nil
local function findRealParryButton()
    for _, folder in ipairs({PGui, CoreGui}) do
        for _, obj in ipairs(folder:GetDescendants()) do
            if (obj:IsA("TextButton") or obj:IsA("ImageButton")) and obj.Visible then
                -- Kita cari yang teksnya PARRY, atau namanya ada PARRY, atau posisinya di atas Dodge
                local isParry = false
                if obj:IsA("TextButton") and string.find(string.upper(obj.Text), "PARRY") then isParry = true end
                if string.find(string.upper(obj.Name), "PARRY") then isParry = true end
                
                -- Pengecualian: jangan pilih tombol pencapaian
                if string.find(string.upper(obj:GetFullName()), "ACHIEVEMENT") then isParry = false end

                if isParry then
                    parryBtn = obj
                    print("[DG] Tombol PARRY ketemu: " .. obj:GetFullName())
                    return
                end
            end
        end
    end
end
findRealParryButton()

-- [2] FUNGSI NEMBAK TOMBOL (Tanpa VIM)
local function fireParry()
    if not parryBtn or not parryBtn.Parent then
        findRealParryButton() -- Scan ulang kalau belum dapet
        if not parryBtn then return end
    end
    
    -- Paksa tombolnya nganggep dia baru aja disentuh
    pcall(function()
        local touchInput = Instance.new("Touch")
        touchInput.Position = parryBtn.AbsolutePosition + (parryBtn.AbsoluteSize / 2)
        
        -- Panggil event InputBegan dan InputEnded langsung ke objek tombolnya
        parryBtn:InputBegan(touchInput, false)
        task.wait(0.02)
        parryBtn:InputEnded(touchInput, false)
    end)
    
    -- Tembak event klik utamanya
    pcall(function() parryBtn.Activated:Fire() end)
end

-- [3] ENGINE (Langsung nyala)
local parryCooldown={}
RunService.PreSimulation:Connect(function()
    local myChar = LP.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end
    
    local function alive(p) local h=p and p.Character and p.Character:FindFirstChildOfClass("Humanoid"); return h and h.Health>0 end
    
    for _,p in ipairs(Players:GetPlayers()) do
        if p==LP or not alive(p) then continue end
        
        local eHRP = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
        if not eHRP or (eHRP.Position - myHRP.Position).Magnitude > 20 then continue end
        
        -- Pastikan lawan ngadep ke kita
        if eHRP.CFrame.LookVector:Dot((myHRP.Position - eHRP.Position).Unit) < 0.5 then continue end
        
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

print("[DG] v44 Aktif. Lo tinggal masuk duel, script bakal nekan tombol UI PARRY lo secara langsung.")
