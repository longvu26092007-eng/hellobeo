--[[
    RACE V4 TITLE CHECKER - STANDALONE

    CONFIG:
    getgenv().Team = "Pirates" -- hoặc "Marines"

    getgenv().RaceCheck = {
        angel = false,
        rabbit = false,
        human = false,
        shark = false,
        cyborg = false,
        ghoul = false,
    }

    Khi tất cả race bật true đều có V4:
      1 race -> Completed-1racev4
      2 race -> Completed-2racev4
      3 race -> Completed-3racev4
      ...
      6 race -> Completed-6racev4

    File:
      <PlayerName>.txt
]]

repeat task.wait(0.2) until game:IsLoaded()
    and game:GetService("Players").LocalPlayer
    and game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local CommF_ = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_")

-- ============================================================
-- CONFIG
-- ============================================================

getgenv().Team = getgenv().Team or "Pirates"

local defaults = {
    angel = false,
    rabbit = false,
    human = false,
    shark = false,
    cyborg = false,
    ghoul = false,
}

local RaceCheck = getgenv().RaceCheck or getgenv().racecheck
if type(RaceCheck) ~= "table" then
    RaceCheck = {}
end

for key, value in pairs(defaults) do
    if RaceCheck[key] == nil then
        RaceCheck[key] = value
    end
end

-- hỗ trợ cả RaceCheck và racecheck
getgenv().RaceCheck = RaceCheck
getgenv().racecheck = RaceCheck

-- tránh execute trùng
if type(getgenv().__RACE_V4_CHECKER_STOP) == "function" then
    pcall(getgenv().__RACE_V4_CHECKER_STOP)
end

local running = true
local completed = false
local completionWritten = false
local statusText = "Starting..."

getgenv().__RACE_V4_CHECKER_STOP = function()
    running = false
end

-- ============================================================
-- TEAM
-- ============================================================

local function NormalizeTeam(value)
    local s = tostring(value or "Pirates"):lower():gsub("[^%a]", "")
    if s == "marine" or s == "marines" then
        return "Marines"
    end
    return "Pirates"
end

local wantedTeam = NormalizeTeam(getgenv().Team)
getgenv().Team = wantedTeam

local function HasCorrectTeam()
    return LocalPlayer.Team ~= nil
        and tostring(LocalPlayer.Team.Name) == wantedTeam
end

local function TryClickTeamButton()
    local main = PlayerGui:FindFirstChild("Main")
        or PlayerGui:FindFirstChild("Main (minimal)")

    local choose = main and main:FindFirstChild("ChooseTeam", true)
    if not choose then
        return false
    end

    local wantedWord = wantedTeam == "Marines" and "marine" or "pirate"

    for _, obj in ipairs(choose:GetDescendants()) do
        if obj:IsA("GuiButton") then
            local label = string.lower(tostring(obj.Name or ""))
            if obj:IsA("TextButton") then
                label = label .. " " .. string.lower(tostring(obj.Text or ""))
            end

            if string.find(label, wantedWord, 1, true) then
                local ok = pcall(function()
                    if type(firesignal) == "function" then
                        firesignal(obj.Activated)
                    else
                        obj:Activate()
                    end
                end)

                if ok then
                    return true
                end
            end
        end
    end

    return false
end

local function ChooseTeam()
    if HasCorrectTeam() then
        return true
    end

    for attempt = 1, 20 do
        if not running then
            return false
        end

        statusText = string.format(
            "Choosing team %s (%d/20)",
            wantedTeam,
            attempt
        )

        pcall(function()
            CommF_:InvokeServer("SetTeam", wantedTeam)
        end)

        task.wait(0.5)

        if HasCorrectTeam() then
            return true
        end

        pcall(TryClickTeamButton)
        task.wait(0.5)

        if HasCorrectTeam() then
            return true
        end
    end

    return HasCorrectTeam()
end

-- ============================================================
-- V4 TITLE MAP
-- ============================================================

local RACE_ORDER = {
    "human",
    "rabbit",
    "shark",
    "angel",
    "cyborg",
    "ghoul",
}

local RACE_INFO = {
    human = {
        display = "Human V4",
        title = "Berserker",
    },
    rabbit = {
        display = "Rabbit V4",
        title = "Thunderbolt",
    },
    shark = {
        display = "Shark V4",
        title = "Leviathan",
    },
    angel = {
        display = "Angel V4",
        title = "His Majesty",
    },
    cyborg = {
        display = "Cyborg V4",
        title = "Genesis",
    },
    ghoul = {
        display = "Ghoul V4",
        title = "Nightwalker",
    },
}

local TITLE_FIELDS = {
    title = true,
    name = true,
    titlename = true,
    displayname = true,
}

local FAST_SCAN_INTERVAL = 5
local FAST_SCAN_LIMIT = 3
local NORMAL_SCAN_INTERVAL = 30

local titleCache = {
    initialized = false,
    scanning = false,
    scanCount = 0,
    lastScanAt = 0,
    nextScanAt = 0,
    remoteOk = false,
    remoteError = nil,
    map = {},
    paths = {},
}

local function NormalizeText(value)
    return tostring(value or ""):lower():gsub("[^%w]", "")
end

local function ExactTitleMatch(a, b)
    return NormalizeText(a) == NormalizeText(b)
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

local function InvokeGetTitles(timeoutSeconds)
    local finished = false
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
        finished = true
    end)

    local deadline = tick() + (tonumber(timeoutSeconds) or 3)

    repeat
        task.wait(0.05)
    until finished or tick() >= deadline

    if not finished then
        return false, nil, "getTitles timeout"
    end

    if not okResult then
        return false, nil, errorResult or "getTitles error"
    end

    if type(dataResult) ~= "table" then
        return false, nil, "getTitles returned non-table"
    end

    return true, dataResult, nil
end

local function GetNextInterval()
    if titleCache.scanCount < FAST_SCAN_LIMIT then
        return FAST_SCAN_INTERVAL
    end

    return NORMAL_SCAN_INTERVAL
end

local function ScanV4Titles(force)
    if titleCache.scanning then
        return titleCache.map
    end

    if not force
        and titleCache.initialized
        and tick() < titleCache.nextScanAt
    then
        return titleCache.map
    end

    titleCache.scanning = true
    statusText = "Scanning getTitles..."

    local foundMap = {}
    local foundPaths = {}

    local remoteOk, remoteData, remoteError = InvokeGetTitles(3)

    titleCache.remoteOk = remoteOk
    titleCache.remoteError = remoteError

    for _, raceKey in ipairs(RACE_ORDER) do
        local info = RACE_INFO[raceKey]
        local firstPath = nil

        if remoteOk then
            WalkTables(
                remoteData,
                "getTitles",
                0,
                {},
                function(node, path)
                    if firstPath == nil
                        and NodeHasExactTitle(node, info.title)
                    then
                        firstPath = path
                    end
                end
            )
        end

        foundMap[raceKey] = firstPath ~= nil
        foundPaths[raceKey] = firstPath
    end

    titleCache.map = foundMap
    titleCache.paths = foundPaths
    titleCache.initialized = true
    titleCache.scanCount = titleCache.scanCount + 1
    titleCache.lastScanAt = tick()
    titleCache.nextScanAt = tick() + GetNextInterval()
    titleCache.scanning = false

    getgenv().RaceV4TitleDebug = {
        scanCount = titleCache.scanCount,
        remoteOk = titleCache.remoteOk,
        remoteError = titleCache.remoteError,
        map = titleCache.map,
        paths = titleCache.paths,
        lastScanAt = titleCache.lastScanAt,
        nextScanAt = titleCache.nextScanAt,
    }

    if remoteOk then
        statusText = "V4 title scan completed"
    else
        statusText = "getTitles error: " .. tostring(remoteError)
    end

    return titleCache.map
end

-- ============================================================
-- ENABLED / COMPLETE
-- ============================================================

local function GetEnabledRaces()
    local result = {}

    for _, raceKey in ipairs(RACE_ORDER) do
        if RaceCheck[raceKey] == true then
            result[#result + 1] = raceKey
        end
    end

    return result
end

local function GetMissingEnabledRaces()
    local enabled = GetEnabledRaces()
    local missing = {}

    for _, raceKey in ipairs(enabled) do
        if titleCache.map[raceKey] ~= true then
            missing[#missing + 1] = raceKey
        end
    end

    return enabled, missing
end

local function GetCompletionContent()
    local enabled = GetEnabledRaces()
    local count = #enabled

    if count <= 0 then
        return nil
    end

    return "Completed-" .. tostring(count) .. "racev4"
end

local function WriteCompletedFile()
    if completionWritten then
        return true
    end

    local enabled, missing = GetMissingEnabledRaces()

    if #enabled == 0
        or #missing > 0
        or not titleCache.remoteOk
    then
        return false
    end

    local content = GetCompletionContent()
    if not content then
        return false
    end

    local fileName = tostring(LocalPlayer.Name) .. ".txt"

    local ok, err = pcall(function()
        assert(type(writefile) == "function", "writefile unsupported")
        writefile(fileName, content)
    end)

    if not ok then
        statusText = "Write file failed: " .. tostring(err)
        return false
    end

    completionWritten = true
    completed = true
    statusText = string.format(
        "COMPLETED | %s = %s",
        fileName,
        content
    )

    getgenv().RaceV4CheckerCompleted = true
    getgenv().RaceV4CheckerCompletionFile = fileName
    getgenv().RaceV4CheckerCompletionContent = content

    return true
end

-- ============================================================
-- UI
-- ============================================================

local UI = {
    gui = nil,
    frame = nil,
    teamLabel = nil,
    scanLabel = nil,
    summaryLabel = nil,
    statusLabel = nil,
    raceLabels = {},
}

local function GetGuiParent()
    local ok, parent = pcall(function()
        if type(gethui) == "function" then
            return gethui()
        end

        return game:GetService("CoreGui")
    end)

    if ok and parent then
        return parent
    end

    return PlayerGui
end

local function CreateUI()
    local parent = GetGuiParent()

    pcall(function()
        local old = parent:FindFirstChild("RaceV4TitleCheckerUI")
        if old then
            old:Destroy()
        end
    end)

    local gui = Instance.new("ScreenGui")
    gui.Name = "RaceV4TitleCheckerUI"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = false
    gui.DisplayOrder = 60
    gui.Parent = parent

    local frame = Instance.new("Frame")
    frame.Name = "Main"
    frame.AnchorPoint = Vector2.new(1, 0.5)
    frame.Position = UDim2.new(1, -18, 0.5, 0)
    frame.Size = UDim2.fromOffset(350, 414)
    frame.BackgroundColor3 = Color3.fromRGB(17, 18, 22)
    frame.BackgroundTransparency = 0.04
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    frame.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 11)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(105, 130, 255)
    stroke.Thickness = 2
    stroke.Parent = frame

    local title = Instance.new("TextLabel")
    title.Position = UDim2.fromOffset(12, 8)
    title.Size = UDim2.new(1, -56, 0, 30)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.Text = "RACE V4 TITLE CHECKER"
    title.TextSize = 18
    title.TextColor3 = Color3.fromRGB(175, 190, 255)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame

    local minimize = Instance.new("TextButton")
    minimize.AnchorPoint = Vector2.new(1, 0)
    minimize.Position = UDim2.new(1, -8, 0, 8)
    minimize.Size = UDim2.fromOffset(32, 28)
    minimize.BackgroundColor3 = Color3.fromRGB(36, 38, 47)
    minimize.BorderSizePixel = 0
    minimize.Font = Enum.Font.GothamBold
    minimize.Text = "—"
    minimize.TextSize = 18
    minimize.TextColor3 = Color3.fromRGB(240, 240, 245)
    minimize.Parent = frame

    local minimizeCorner = Instance.new("UICorner")
    minimizeCorner.CornerRadius = UDim.new(0, 6)
    minimizeCorner.Parent = minimize

    local content = Instance.new("Frame")
    content.Position = UDim2.fromOffset(10, 44)
    content.Size = UDim2.new(1, -20, 1, -54)
    content.BackgroundTransparency = 1
    content.Parent = frame

    local function NewInfo(name, y, text)
        local label = Instance.new("TextLabel")
        label.Name = name
        label.Position = UDim2.fromOffset(0, y)
        label.Size = UDim2.new(1, 0, 0, 22)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamSemibold
        label.Text = text
        label.TextSize = 13
        label.TextColor3 = Color3.fromRGB(225, 225, 232)
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = content
        return label
    end

    NewInfo("Player", 0, "Player: " .. tostring(LocalPlayer.Name))
    local teamLabel = NewInfo("Team", 23, "Team: ...")
    local scanLabel = NewInfo("Scan", 46, "Scan: ...")
    local summaryLabel = NewInfo("Summary", 69, "Enabled: ...")

    local divider = Instance.new("Frame")
    divider.Position = UDim2.fromOffset(0, 98)
    divider.Size = UDim2.new(1, 0, 0, 1)
    divider.BackgroundColor3 = Color3.fromRGB(72, 75, 88)
    divider.BorderSizePixel = 0
    divider.Parent = content

    local header = NewInfo("Header", 105, "V4 title status")
    header.Font = Enum.Font.GothamBold
    header.TextColor3 = Color3.fromRGB(175, 190, 255)

    local raceLabels = {}

    for index, raceKey in ipairs(RACE_ORDER) do
        local label = Instance.new("TextLabel")
        label.Name = raceKey
        label.Position = UDim2.fromOffset(
            0,
            132 + (index - 1) * 29
        )
        label.Size = UDim2.new(1, 0, 0, 25)
        label.BackgroundColor3 = Color3.fromRGB(28, 29, 35)
        label.BackgroundTransparency = 0.15
        label.BorderSizePixel = 0
        label.Font = Enum.Font.GothamSemibold
        label.Text = RACE_INFO[raceKey].display
        label.TextSize = 13
        label.TextColor3 = Color3.fromRGB(190, 190, 198)
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = content

        local pad = Instance.new("UIPadding")
        pad.PaddingLeft = UDim.new(0, 8)
        pad.Parent = label

        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 5)
        c.Parent = label

        raceLabels[raceKey] = label
    end

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "Status"
    statusLabel.Position = UDim2.fromOffset(0, 312)
    statusLabel.Size = UDim2.new(1, 0, 0, 46)
    statusLabel.BackgroundColor3 = Color3.fromRGB(28, 29, 35)
    statusLabel.BackgroundTransparency = 0.08
    statusLabel.BorderSizePixel = 0
    statusLabel.Font = Enum.Font.GothamSemibold
    statusLabel.Text = "Status: Starting..."
    statusLabel.TextSize = 12
    statusLabel.TextWrapped = true
    statusLabel.TextColor3 = Color3.fromRGB(240, 240, 245)
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.TextYAlignment = Enum.TextYAlignment.Center
    statusLabel.Parent = content

    local statusPad = Instance.new("UIPadding")
    statusPad.PaddingLeft = UDim.new(0, 8)
    statusPad.PaddingRight = UDim.new(0, 8)
    statusPad.Parent = statusLabel

    local statusCorner = Instance.new("UICorner")
    statusCorner.CornerRadius = UDim.new(0, 6)
    statusCorner.Parent = statusLabel

    local minimized = false

    minimize.MouseButton1Click:Connect(function()
        minimized = not minimized
        content.Visible = not minimized

        frame.Size = minimized
            and UDim2.fromOffset(350, 46)
            or UDim2.fromOffset(350, 414)

        minimize.Text = minimized and "+" or "—"
    end)

    UI.gui = gui
    UI.frame = frame
    UI.teamLabel = teamLabel
    UI.scanLabel = scanLabel
    UI.summaryLabel = summaryLabel
    UI.statusLabel = statusLabel
    UI.raceLabels = raceLabels
end

local function RaceListText(list)
    if type(list) ~= "table" or #list == 0 then
        return "none"
    end

    local names = {}

    for _, raceKey in ipairs(list) do
        names[#names + 1] =
            RACE_INFO[raceKey].display:gsub(" V4$", "")
    end

    return table.concat(names, ", ")
end

local function UpdateUI()
    if not UI.gui or not UI.gui.Parent then
        CreateUI()
    end

    local enabled, missing = GetMissingEnabledRaces()

    if UI.teamLabel then
        UI.teamLabel.Text =
            "Team: "
            .. tostring(
                LocalPlayer.Team
                and LocalPlayer.Team.Name
                or "NONE"
            )
            .. " | target "
            .. wantedTeam
    end

    if UI.scanLabel then
        local remain =
            math.max(
                0,
                math.ceil(titleCache.nextScanAt - tick())
            )

        UI.scanLabel.Text = string.format(
            "Scan #%d | getTitles=%s | next=%ds",
            titleCache.scanCount,
            titleCache.remoteOk and "OK" or "ERR/WAIT",
            remain
        )
    end

    if UI.summaryLabel then
        UI.summaryLabel.Text = string.format(
            "Enabled: %d | Missing: %d | %s",
            #enabled,
            #missing,
            RaceListText(missing)
        )
    end

    for _, raceKey in ipairs(RACE_ORDER) do
        local label = UI.raceLabels[raceKey]

        if label then
            local on = RaceCheck[raceKey] == true
            local done = titleCache.map[raceKey] == true

            label.Text = string.format(
                "%s | %s | %s | title=%s",
                RACE_INFO[raceKey].display,
                on and "ON" or "OFF",
                done and "DONE" or "MISSING",
                RACE_INFO[raceKey].title
            )

            if done then
                label.TextColor3 =
                    Color3.fromRGB(90, 255, 135)
            elseif on then
                label.TextColor3 =
                    Color3.fromRGB(255, 110, 110)
            else
                label.TextColor3 =
                    Color3.fromRGB(160, 160, 170)
            end
        end
    end

    if UI.statusLabel then
        UI.statusLabel.Text =
            "Status: " .. tostring(statusText)

        UI.statusLabel.TextColor3 =
            completed
            and Color3.fromRGB(100, 255, 145)
            or Color3.fromRGB(240, 240, 245)
    end
end

CreateUI()

task.spawn(function()
    while running do
        pcall(UpdateUI)
        task.wait(0.5)
    end

    pcall(UpdateUI)
end)

-- ============================================================
-- MAIN LOOP
-- ============================================================

statusText = "Choosing team: " .. wantedTeam
ChooseTeam()

if HasCorrectTeam() then
    statusText = "Team ready: " .. wantedTeam
else
    statusText = "Team choose failed - checker continues"
end

pcall(function()
    ScanV4Titles(true)
end)

while running and not completed do
    local enabled, missing = GetMissingEnabledRaces()

    if #enabled == 0 then
        statusText =
            "No race enabled in getgenv().RaceCheck"
    else
        if tick() >= titleCache.nextScanAt then
            pcall(function()
                ScanV4Titles(true)
            end)

            enabled, missing = GetMissingEnabledRaces()
        end

        if titleCache.remoteOk then
            if #missing == 0 then
                WriteCompletedFile()
            else
                statusText = string.format(
                    "Waiting V4 | enabled=%d | missing=%d: %s",
                    #enabled,
                    #missing,
                    RaceListText(missing)
                )
            end
        end
    end

    getgenv().RaceV4CheckerStatus = statusText
    task.wait(0.5)
end

getgenv().RaceV4CheckerStatus = statusText
