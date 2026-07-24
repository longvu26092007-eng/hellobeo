-- Chỉ nhập "Ghoul" hoặc "Cyborg"
repeat task.wait() until game:IsLoaded() 
local TargetRace = "Ghoul"
local RetryDelay = 3

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local CommF = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_")

local Running = true
local IsBuying = false

local function GetRaceValue()
    local data = LocalPlayer:FindFirstChild("Data")
    local race = data and data:FindFirstChild("Race")

    if race then
        return tostring(race.Value)
    end

    return nil
end

local function NormalizeRaceName(raceName)
    raceName = tostring(raceName or ""):lower()

    if raceName == "ghoul" then
        return "Ghoul"
    elseif raceName == "cyborg" then
        return "Cyborg"
    end

    return nil
end

local function CheckRace()
    local currentRace = GetRaceValue()

    if not currentRace then
        return "Unknown"
    end

    local character = LocalPlayer.Character

    if character and character:FindFirstChild("RaceTransformed") then
        return currentRace .. "-V4"
    end

    local wenlockResult
    local alchemistResult

    pcall(function()
        wenlockResult = CommF:InvokeServer("Wenlocktoad", "1")
    end)

    if wenlockResult == -2 then
        return currentRace .. "-V3"
    end

    pcall(function()
        alchemistResult = CommF:InvokeServer("Alchemist", "1")
    end)

    if alchemistResult == -2 then
        return currentRace .. "-V2"
    end

    return currentRace .. "-V1"
end

local function BuyGhoul()
    if IsBuying then
        return
    end

    IsBuying = true

    local success, err = pcall(function()
        CommF:InvokeServer("Ectoplasm", "BuyCheck", 4)
        task.wait(0.5)
        CommF:InvokeServer("Ectoplasm", "Change", 4)
    end)

    IsBuying = false

    if not success then
        warn("[Race Buyer] Lỗi mua Ghoul:", err)
    end
end

local function BuyCyborg()
    if IsBuying then
        return
    end

    IsBuying = true

    local success, err = pcall(function()
        CommF:InvokeServer("CyborgTrainer", "Buy")
    end)

    task.wait(0.5)
    IsBuying = false

    if not success then
        warn("[Race Buyer] Lỗi mua Cyborg:", err)
    end
end

TargetRace = NormalizeRaceName(TargetRace)

if not TargetRace then
    Running = false
    error('[Race Buyer] TargetRace chỉ được đặt là "Ghoul" hoặc "Cyborg".')
end

repeat
    task.wait()
until LocalPlayer:FindFirstChild("Data")
    and LocalPlayer.Data:FindFirstChild("Race")

print("[Race Buyer] Tộc mục tiêu:", TargetRace)
print("[Race Buyer] Tộc hiện tại:", CheckRace())

while Running do
    local CurrentRace = GetRaceValue()

    if CurrentRace == TargetRace then
        Running = false
        print("[Race Buyer] Đã đúng tộc:", CheckRace())
        print("[Race Buyer] Script đã dừng.")
        break
    end

    if TargetRace == "Ghoul" then
        BuyGhoul()
    elseif TargetRace == "Cyborg" then
        BuyCyborg()
    end

    task.wait(1)

    CurrentRace = GetRaceValue()

    if CurrentRace == TargetRace then
        Running = false
        print("[Race Buyer] Mua thành công:", CheckRace())
        print("[Race Buyer] Script đã dừng.")
        break
    end

    task.wait(RetryDelay)
end
