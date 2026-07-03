local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local plr = Players.LocalPlayer
local PlayerGui = plr:WaitForChild("PlayerGui")

local raceTitles = {
    ["Full Power"] = "Human V3",
    ["Godspeed"] = "Rabbit V3",
    ["Warrior of the Sea"] = "Shark V3",
    ["Perfect Being"] = "Angel V3",
    ["Hell Hound"] = "Ghoul V3",
    ["War Machine"] = "Cyborg V3",
    ["Ancient Flame"] = "Draco V3",

    ["Berserker"] = "Human V4",
    ["Thunderbolt"] = "Rabbit V4",
    ["Leviathan"] = "Shark V4",
    ["His Majesty"] = "Angel V4",
    ["Nightwalker"] = "Ghoul V4",
    ["Genesis"] = "Cyborg V4",
    ["Primordial Guardian"] = "Draco V4",
}

local allV3 = {
    "Human V3", "Rabbit V3", "Shark V3", "Angel V3",
    "Ghoul V3", "Cyborg V3", "Draco V3"
}

local allV4 = {
    "Human V4", "Rabbit V4", "Shark V4", "Angel V4",
    "Ghoul V4", "Cyborg V4", "Draco V4"
}

local raceColors = {
    ["Angel V3"]  = "#FFCC00",
    ["Angel V4"]  = "#FFCC00",

    ["Human V3"]  = "#FF1A1A",
    ["Human V4"]  = "#FF1A1A",

    ["Shark V3"]  = "#00A8FF",
    ["Shark V4"]  = "#00A8FF",

    ["Cyborg V3"] = "#CC00FF",
    ["Cyborg V4"] = "#CC00FF",

    ["Ghoul V3"]  = "#FF004D",
    ["Ghoul V4"]  = "#FF004D",

    ["Rabbit V3"] = "#00FF3C",
    ["Rabbit V4"] = "#00FF3C",

    ["Draco V3"]  = "#FF6A00",
    ["Draco V4"]  = "#FF6A00",
}

local oldGui = PlayerGui:FindFirstChild("RaceTrackerGUI")
if oldGui then
    oldGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RaceTrackerGUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = PlayerGui

local label = Instance.new("TextLabel")
label.Name = "MainLabel"
label.Parent = screenGui
label.Size = UDim2.new(0, 1000, 0, 170)
label.Position = UDim2.new(0.5, -500, 0.03, 0)
label.BackgroundTransparency = 1
label.BorderSizePixel = 0
label.RichText = true
label.TextWrapped = true
label.TextScaled = false
label.TextSize = 22
label.Font = Enum.Font.GothamBlack
label.TextColor3 = Color3.fromRGB(255, 255, 255)
label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
label.TextStrokeTransparency = 0
label.TextXAlignment = Enum.TextXAlignment.Center
label.TextYAlignment = Enum.TextYAlignment.Top
label.ZIndex = 999
label.Text = "Loading..."

local function colorRaceName(race)
    local hex = raceColors[race] or "#FFFFFF"
    return '<b><font color="' .. hex .. '">' .. race .. '</font></b>'
end

local function colorRaceList(list)
    local result = {}
    for _, race in ipairs(list) do
        result[#result + 1] = colorRaceName(race)
    end
    return table.concat(result, ", ")
end

local function getMissing(allList, ownedList)
    local ownedMap = {}
    for _, race in ipairs(ownedList) do
        ownedMap[race] = true
    end

    local missing = {}
    for _, race in ipairs(allList) do
        if not ownedMap[race] then
            missing[#missing + 1] = race
        end
    end
    return missing
end

local function GetUnlockedRaces()
    local unlocked = {
        V3 = {},
        V4 = {}
    }

    local added = {}

    local function addRace(raceVer)
        if not raceVer or added[raceVer] then
            return
        end
        added[raceVer] = true

        if string.find(raceVer, "V3") then
            table.insert(unlocked.V3, raceVer)
        elseif string.find(raceVer, "V4") then
            table.insert(unlocked.V4, raceVer)
        end
    end

    local ok, titles = pcall(function()
        return ReplicatedStorage.Remotes.CommF_:InvokeServer("getTitles")
    end)

    if ok and type(titles) == "table" then
        for _, t in pairs(titles) do
            local name = t.Name or t[1]
            local unlockedValue = tostring(t.Unlocked or t[2] or ""):lower()

            if name and raceTitles[name] then
                if unlockedValue == "true" or unlockedValue == "1" or string.find(unlockedValue, "unlock") then
                    addRace(raceTitles[name])
                end
            end
        end
    end

    local titlesFolder = plr:FindFirstChild("Titles")
    if titlesFolder then
        for _, inst in ipairs(titlesFolder:GetChildren()) do
            if raceTitles[inst.Name] then
                local okValue, valueText = pcall(function()
                    return tostring(inst.Value):lower()
                end)

                if okValue and (valueText == "true" or valueText == "1" or string.find(valueText, "unlock")) then
                    addRace(raceTitles[inst.Name])
                end
            end
        end
    end

    return unlocked
end

local function updateGUI()
    local unlocked = GetUnlockedRaces()

    local missingV3 = getMissing(allV3, unlocked.V3)
    local missingV4 = getMissing(allV4, unlocked.V4)

    local text = '<b>Character: <font color="#FFD700">' .. plr.Name .. '</font></b>\n'

    if #missingV3 == 0 then
        text = text .. '<b><font color="#00FF66">Complete all V3</font></b>\n'
    else
        text = text .. '<b>Miss V3 (' .. #missingV3 .. '/' .. #allV3 .. '):</b>\n'
        text = text .. colorRaceList(missingV3) .. '\n'
    end

    if #missingV4 == 0 then
        text = text .. '<b><font color="#00FF66">Complete all V4</font></b>'
    else
        text = text .. '<b>Miss V4 (' .. #missingV4 .. '/' .. #allV4 .. '):</b>\n'
        text = text .. colorRaceList(missingV4)
    end

    label.Text = text
end

task.spawn(function()
    while screenGui.Parent do
        pcall(updateGUI)
        task.wait(1.5)
    end
end)
