-- ============================================================
--  BuyGhoul.lua  -  Mua/doi race Ghoul (hoac Cyborg) - co DEBUG
--  Sua tu ban goc: THEM check dieu kien + DOC ket qua server tra ve
--  de biet CHINH XAC vi sao "loi mua race".
-- ============================================================

repeat task.wait() until game:IsLoaded()

local TargetRace = "Ghoul"   -- "Ghoul" hoac "Cyborg"
local RetryDelay = 3

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer       = Players.LocalPlayer
local CommF             = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_")

local Running   = true
local IsBuying  = false

-- id race trong remote Ectoplasm/Change (Ghoul = 4 theo tat ca script goc)
local GHOUL_ID  = 4

--------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------
local function log(...)
    print("[BuyGhoul]", ...)
end

local function GetRaceValue()
    local data = LocalPlayer:FindFirstChild("Data")
    local race = data and data:FindFirstChild("Race")
    if race then return tostring(race.Value) end
    return nil
end

local function NormalizeRaceName(raceName)
    raceName = tostring(raceName or ""):lower()
    if raceName == "ghoul" then return "Ghoul"
    elseif raceName == "cyborg" then return "Cyborg" end
    return nil
end

-- so Ectoplasm dang co (remote Ectoplasm/Check tra ve so luong)
local function GetEctoplasm()
    local ok, n = pcall(function()
        return CommF:InvokeServer("Ectoplasm", "Check")
    end)
    if ok then return tonumber(n) or 0 end
    return 0
end

-- co Hellfire Torch trong backpack/character khong (vat MO KHOA doi Ghoul)
local function HasHellfireTorch()
    for _, cont in ipairs({ LocalPlayer:FindFirstChild("Backpack"), LocalPlayer.Character }) do
        if cont then
            for _, x in ipairs(cont:GetChildren()) do
                if x:IsA("Tool") and (x.Name == "Hellfire Torch" or x.Name:find("Hellfire")) then
                    return true
                end
            end
        end
    end
    return false
end

--------------------------------------------------------------------
-- Mua Ghoul: DOC ket qua tung buoc de biet vi sao fail
--------------------------------------------------------------------
local function BuyGhoul()
    if IsBuying then return end
    IsBuying = true

    -- 1) DIEU KIEN: du 100 Ectoplasm
    local ecto = GetEctoplasm()
    log("Ectoplasm hien co:", ecto, "/ 100")
    if ecto < 100 then
        log("THIEU Ectoplasm -> khong the doi race. Di farm them.")
        IsBuying = false
        return
    end

    -- 2) DIEU KIEN: co Hellfire Torch (vat mo khoa)
    if not HasHellfireTorch() then
        log("CHUA co 'Hellfire Torch' -> can danh boss lay torch truoc khi doi Ghoul.")
        -- van thu BuyCheck de doc phan hoi server (co the game khong yeu cau torch cho V1)
    end

    -- 3) BuyCheck -> DOC ket qua
    local okCheck, checkRes = pcall(function()
        return CommF:InvokeServer("Ectoplasm", "BuyCheck", GHOUL_ID)
    end)
    log("BuyCheck tra ve:", okCheck, checkRes)

    task.wait(0.5)

    -- 4) Change -> DOC ket qua
    local okChange, changeRes = pcall(function()
        return CommF:InvokeServer("Ectoplasm", "Change", GHOUL_ID)
    end)
    log("Change tra ve:", okChange, changeRes)

    IsBuying = false
end

--------------------------------------------------------------------
-- Mua Cyborg
--------------------------------------------------------------------
local function BuyCyborg()
    if IsBuying then return end
    IsBuying = true
    local ok, res = pcall(function()
        return CommF:InvokeServer("CyborgTrainer", "Buy")
    end)
    log("CyborgTrainer/Buy tra ve:", ok, res)
    task.wait(0.5)
    IsBuying = false
end

--------------------------------------------------------------------
-- Main
--------------------------------------------------------------------
TargetRace = NormalizeRaceName(TargetRace)
if not TargetRace then
    Running = false
    error('[BuyGhoul] TargetRace chi duoc "Ghoul" hoac "Cyborg".')
end

repeat task.wait()
until LocalPlayer:FindFirstChild("Data") and LocalPlayer.Data:FindFirstChild("Race")

log("Toc muc tieu:", TargetRace)
log("Toc hien tai:", GetRaceValue())

while Running do
    if GetRaceValue() == TargetRace then
        Running = false
        log("Da dung toc:", GetRaceValue(), "-> DUNG.")
        break
    end

    if TargetRace == "Ghoul" then
        BuyGhoul()
    else
        BuyCyborg()
    end

    task.wait(1)

    if GetRaceValue() == TargetRace then
        Running = false
        log("Mua thanh cong:", GetRaceValue(), "-> DUNG.")
        break
    end

    log("Chua doi duoc race, thu lai sau", RetryDelay, "giay...")
    task.wait(RetryDelay)
end
