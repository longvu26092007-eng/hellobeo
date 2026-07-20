--[[
    BANANAHUB RACE V2-V3 TITLE CONTROLLER
    Build: TITLE-CONTROLLER-R1

    Chức năng:
      1. Chọn/load team trước khi gọi BananaHub.
      2. Truyền getgenv().Key và getgenv().Config vào BananaHub.
      3. Check V3 bằng đúng phương pháp Title Name từ getTitles.
      4. Race true + chưa V3: dừng reroll để BananaHub làm V2-V3.
      5. Race false hoặc đã V3: tiếp tục reroll khi đủ 3000 fragments.
      6. Khi tất cả race true đều V3:
         tạo <PlayerName>.txt với nội dung "Completed".
]]

-- ============================================================
-- [ CONFIG BÊN NGOÀI - CHỈ SỬA PHẦN NÀY ]
-- ============================================================

getgenv().Team = "Pirate"

-- Nhập key BananaHub tại đây.
getgenv().Key = ""

-- true  = cần làm V3 race này.
-- false = không dừng khi reroll trúng race này.
getgenv().Races = {
    ["Human"] = true,
    ["Mink"] = true,
    ["Fishman"] = true,
    ["Skypiea"] = true,
    ["Cyborg"] = false,
    ["Ghoul"] = false,
}

-- ============================================================
-- [ WAIT GAME ]
-- ============================================================

repeat
    wait()
until game:IsLoaded() and game.Players.LocalPlayer

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local CommF_ =
    ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_")

repeat
    task.wait(0.2)
until LocalPlayer:FindFirstChild("Data")
    and LocalPlayer.Data:FindFirstChild("Race")
    and LocalPlayer.Data:FindFirstChild("Fragments")

-- Dừng controller cũ nếu người dùng execute lại file.
if getgenv().__BANANA_RACE_V3_CONTROLLER_STOP then
    pcall(getgenv().__BANANA_RACE_V3_CONTROLLER_STOP)
end

local controllerRunning = true
local controllerCompleted = false
local lastStatus = nil

getgenv().__BANANA_RACE_V3_CONTROLLER_STOP = function()
    controllerRunning = false
end

local function SetControllerStatus(text)
    text = tostring(text)

    if lastStatus == text then
        return
    end

    lastStatus = text
    warn("[Race V3 Controller] " .. text)

    getgenv().BananaRaceV3ControllerStatus = text
end

-- ============================================================
-- [ TEAM ]
-- BananaHub dùng Pirate/Marine.
-- Remote SetTeam dùng Pirates/Marines.
-- ============================================================

local function NormalizeBananaTeam(value)
    local normalized =
        tostring(value or "Pirate"):lower():gsub("[^%a]", "")

    if normalized == "marine" or normalized == "marines" then
        return "Marine", "Marines"
    end

    return "Pirate", "Pirates"
end

local bananaTeam, remoteTeam = NormalizeBananaTeam(getgenv().Team)
getgenv().Team = bananaTeam

local function ChooseTeam()
    if LocalPlayer.Team then
        return true
    end

    for attempt = 1, 20 do
        if LocalPlayer.Team then
            return true
        end

        pcall(function()
            CommF_:InvokeServer("SetTeam", remoteTeam)
        end)

        task.wait(0.5)

        if LocalPlayer.Team then
            return true
        end

        pcall(function()
            local main =
                PlayerGui:FindFirstChild("Main")
                or PlayerGui:FindFirstChild("Main (minimal)")
            local choose =
                main and main:FindFirstChild("ChooseTeam", true)
            local container =
                choose and choose:FindFirstChild("Container")
            local teamFrame =
                container and container:FindFirstChild(remoteTeam)
            local button =
                teamFrame
                and teamFrame:FindFirstChildWhichIsA(
                    "GuiButton",
                    true
                )

            if button then
                if firesignal then
                    firesignal(button.Activated)
                else
                    button:Activate()
                end
            end
        end)

        task.wait(0.5)
    end

    return LocalPlayer.Team ~= nil
end

SetControllerStatus("Choosing team: " .. remoteTeam)
ChooseTeam()

-- ============================================================
-- [ BANANAHUB CONFIG ]
-- Key được đọc trực tiếp từ getgenv().Key ở trên.
-- ============================================================

getgenv().Config = {
    ["Select Team"] = bananaTeam,
    ["Auto Upgrade Race V2-V3"] = true,
}

-- ============================================================
-- [ TITLE NAME V3 CHECKER - METHOD 02 ]
--
-- Chỉ kiểm tra exact title name trong getTitles:
--   Full Power
--   Godspeed
--   Warrior of the Sea
--   Perfect Being
--   Hell Hound
--   War Machine
--
-- Không dùng STT, obtainment, GUI, Wenlock hoặc scoring.
-- Cache 30 giây.
-- ============================================================

local TITLE_SCAN_INTERVAL = 30

local TITLE_TARGETS = {
    {
        title = "Full Power",
        configRace = "Human",
        raceV3 = "Human V3",
    },
    {
        title = "Godspeed",
        configRace = "Mink",
        raceV3 = "Rabbit V3",
    },
    {
        title = "Warrior of the Sea",
        configRace = "Fishman",
        raceV3 = "Shark V3",
    },
    {
        title = "Perfect Being",
        configRace = "Skypiea",
        raceV3 = "Angel V3",
    },
    {
        title = "War Machine",
        configRace = "Cyborg",
        raceV3 = "Cyborg V3",
    },
    {
        title = "Hell Hound",
        configRace = "Ghoul",
        raceV3 = "Ghoul V3",
    },
}

local TITLE_FIELDS = {
    title = true,
    name = true,
    titlename = true,
    displayname = true,
}

local titleCache = {
    initialized = false,
    scanning = false,
    lastScan = 0,
    map = {},
    status = {},
    paths = {},
    remoteOk = false,
    remoteError = nil,
}

local function NormalizeText(value)
    return tostring(value or ""):lower():gsub("[^%w]", "")
end

local function ExactTitleMatch(targetTitle, value)
    return NormalizeText(targetTitle) == NormalizeText(value)
end

local function WalkTables(value, path, depth, visited, callback)
    if type(value) ~= "table" or depth > 10 then
        return
    end

    if visited[value] then
        return
    end

    visited[value] = true
    callback(value, path)

    for key, child in pairs(value) do
        if type(child) == "table" then
            WalkTables(
                child,
                path .. "[" .. tostring(key) .. "]",
                depth + 1,
                visited,
                callback
            )
        end
    end
end

local function NodeHasExactTitle(node, targetTitle)
    for key, value in pairs(node) do
        local normalizedKey = NormalizeText(key)

        if type(value) ~= "table"
            and TITLE_FIELDS[normalizedKey]
            and ExactTitleMatch(targetTitle, value)
        then
            return true
        end

        if type(key) == "string"
            and ExactTitleMatch(targetTitle, key)
        then
            return true
        end
    end

    return false
end

local function InvokeGetTitles(timeoutSeconds)
    local completed = false
    local okResult = false
    local dataResult = nil
    local errorResult = nil

    task.spawn(function()
        local ok, data = pcall(function()
            return CommF_:InvokeServer("getTitles")
        end)

        okResult = ok
        dataResult = ok and data or nil
        errorResult = ok and nil or tostring(data)
        completed = true
    end)

    local deadline = tick() + (tonumber(timeoutSeconds) or 2)

    repeat
        task.wait(0.05)
    until completed or tick() >= deadline

    if not completed then
        return false, nil, "getTitles timeout"
    end

    return okResult, dataResult, errorResult
end

local function ScanV3Titles(force)
    if titleCache.scanning then
        return titleCache.map
    end

    if not force
        and titleCache.initialized
        and tick() - titleCache.lastScan < TITLE_SCAN_INTERVAL
    then
        return titleCache.map
    end

    titleCache.scanning = true

    local foundMap = {}
    local foundStatus = {}
    local foundPaths = {}

    local remoteOk, remoteData, remoteError =
        InvokeGetTitles(2)

    titleCache.remoteOk = remoteOk
    titleCache.remoteError = remoteError

    for _, target in ipairs(TITLE_TARGETS) do
        local paths = {}

        if remoteOk and type(remoteData) == "table" then
            WalkTables(
                remoteData,
                "getTitles",
                0,
                {},
                function(node, path)
                    if NodeHasExactTitle(node, target.title) then
                        table.insert(paths, path)
                    end
                end
            )
        end

        if #paths > 0 then
            foundMap[target.configRace] = true
            foundStatus[target.configRace] = "FOUND"
            foundPaths[target.configRace] = paths[1]
        else
            foundMap[target.configRace] = false
            foundStatus[target.configRace] = "NOT_FOUND"
        end
    end

    titleCache.map = foundMap
    titleCache.status = foundStatus
    titleCache.paths = foundPaths
    titleCache.lastScan = tick()
    titleCache.initialized = true
    titleCache.scanning = false

    getgenv().BananaRaceV3TitleDebug = {
        method = "EXACT_CHECKER_02_TITLE_NAME",
        interval = TITLE_SCAN_INTERVAL,
        lastScan = titleCache.lastScan,
        map = titleCache.map,
        status = titleCache.status,
        paths = titleCache.paths,
        remoteOk = titleCache.remoteOk,
        remoteError = titleCache.remoteError,
    }

    return titleCache.map
end

-- ============================================================
-- [ RACE CONTROLLER ]
-- ============================================================

local RACE_ORDER = {
    "Human",
    "Mink",
    "Fishman",
    "Skypiea",
    "Cyborg",
    "Ghoul",
}

local RACE_ALIASES = {
    human = "Human",
    mink = "Mink",
    rabbit = "Mink",
    fishman = "Fishman",
    shark = "Fishman",
    skypiea = "Skypiea",
    angel = "Skypiea",
    cyborg = "Cyborg",
    ghoul = "Ghoul",
}

local function NormalizeRaceName(value)
    local normalized =
        tostring(value or ""):lower():gsub("[^%a]", "")

    return RACE_ALIASES[normalized] or tostring(value or "")
end

local function GetCurrentRace()
    local raceValue =
        LocalPlayer.Data
        and LocalPlayer.Data:FindFirstChild("Race")

    return NormalizeRaceName(raceValue and raceValue.Value or "")
end

local function GetFragments()
    local value =
        LocalPlayer.Data
        and LocalPlayer.Data:FindFirstChild("Fragments")

    return tonumber(value and value.Value) or 0
end

local function GetEnabledRaces()
    local result = {}

    for _, raceName in ipairs(RACE_ORDER) do
        if getgenv().Races[raceName] == true then
            table.insert(result, raceName)
        end
    end

    return result
end

local function GetMissingEnabledRaces(titleMap)
    local enabled = GetEnabledRaces()
    local missing = {}

    for _, raceName in ipairs(enabled) do
        if titleMap[raceName] ~= true then
            table.insert(missing, raceName)
        end
    end

    return enabled, missing
end

local completionFileWritten = false

local function WriteCompletedFile()
    if completionFileWritten then
        return true
    end

    local fileName = LocalPlayer.Name .. ".txt"

    local ok, err = pcall(function()
        assert(
            type(writefile) == "function",
            "Executor does not support writefile"
        )

        writefile(fileName, "Completed")
    end)

    if ok then
        completionFileWritten = true
        controllerCompleted = true

        SetControllerStatus(
            "ALL ENABLED RACES COMPLETED | "
            .. fileName
            .. " = Completed"
        )

        getgenv().BananaRaceV3ControllerCompleted = true
        return true
    end

    SetControllerStatus(
        "Failed to create completion file: " .. tostring(err)
    )

    return false
end

local lastRerollAt = 0
local REROLL_COOLDOWN = 3
local REROLL_COST = 3000

local function RerollRace(reason)
    if tick() - lastRerollAt < REROLL_COOLDOWN then
        return false
    end

    local fragments = GetFragments()

    if fragments < REROLL_COST then
        SetControllerStatus(
            tostring(reason)
            .. " | Need "
            .. tostring(REROLL_COST)
            .. " fragments | Current: "
            .. tostring(fragments)
        )
        return false
    end

    local oldRace = GetCurrentRace()
    lastRerollAt = tick()

    SetControllerStatus(
        tostring(reason)
        .. " | Rerolling "
        .. tostring(oldRace)
    )

    local ok, result = pcall(function()
        return CommF_:InvokeServer(
            "BlackbeardReward",
            "Reroll",
            "2"
        )
    end)

    if not ok then
        SetControllerStatus(
            "Reroll error: " .. tostring(result)
        )
        return false
    end

    local deadline = tick() + 8

    repeat
        task.wait(0.25)
    until not controllerRunning
        or GetCurrentRace() ~= oldRace
        or tick() >= deadline

    local newRace = GetCurrentRace()

    SetControllerStatus(
        "Reroll result: "
        .. tostring(oldRace)
        .. " -> "
        .. tostring(newRace)
    )

    return newRace ~= oldRace
end

local function ControllerTick()
    local titleMap = ScanV3Titles(false)
    local enabled, missing =
        GetMissingEnabledRaces(titleMap)

    if #enabled == 0 then
        SetControllerStatus(
            "No race is enabled in getgenv().Races"
        )
        return
    end

    if #missing == 0 then
        WriteCompletedFile()
        return
    end

    local currentRace = GetCurrentRace()
    local currentEnabled =
        getgenv().Races[currentRace] == true
    local currentDone =
        titleMap[currentRace] == true

    getgenv().BananaRaceV3ControllerDebug = {
        currentRace = currentRace,
        currentEnabled = currentEnabled,
        currentDone = currentDone,
        enabled = enabled,
        missing = missing,
        fragments = GetFragments(),
        titleMap = titleMap,
    }

    if currentEnabled and not currentDone then
        SetControllerStatus(
            "TARGET RACE: "
            .. tostring(currentRace)
            .. " | Missing V3 | BananaHub upgrading"
        )
        return
    end

    if not currentEnabled then
        RerollRace(
            "Current race "
            .. tostring(currentRace)
            .. " is FALSE"
        )
        return
    end

    if currentDone then
        RerollRace(
            "Current race "
            .. tostring(currentRace)
            .. " already has V3"
        )
    end
end

pcall(function()
    ScanV3Titles(true)
end)

-- ============================================================
-- [ LOAD BANANAHUB ]
-- ============================================================

task.spawn(function()
    SetControllerStatus(
        "Loading BananaHub | Team: "
        .. bananaTeam
    )

    local ok, err = pcall(function()
        local source = game:HttpGet(
            "https://raw.githubusercontent.com/obiiyeuem/vthangsitink/main/BananaHub.lua"
        )
        local loader, loadError = loadstring(source)

        assert(loader, tostring(loadError))
        loader()
    end)

    if ok then
        SetControllerStatus("BananaHub loaded")
    else
        SetControllerStatus(
            "BananaHub load error: " .. tostring(err)
        )
    end
end)

task.wait(3)

task.spawn(function()
    while controllerRunning and not controllerCompleted do
        local ok, err = xpcall(
            ControllerTick,
            function(message)
                return debug.traceback(tostring(message))
            end
        )

        if not ok then
            SetControllerStatus(
                "Controller error: " .. tostring(err)
            )
        end

        task.wait(1)
    end
end)
