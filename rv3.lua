--[[
    RACE V3 CHECKER - ONE METHOD ONLY
    METHOD: 02 - CHECK BY TITLE NAME

    This file intentionally does NOT combine evidence from other methods.
    Auto joins team and scans every 3 seconds by default.
]]

if getgenv().__RACE_V3_SINGLE_CHECKER_STOP then
    pcall(getgenv().__RACE_V3_SINGLE_CHECKER_STOP)
end

repeat task.wait(0.5) until game:IsLoaded()
    and game:GetService("Players").LocalPlayer
    and game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local CommF_ = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_")

local Config = getgenv().RaceV3SingleCheckerConfig or {}
Config.Team = Config.Team or getgenv().Team or "Pirates"
Config.Interval = tonumber(Config.Interval) or 3
Config.OpenTitlesForScan = Config.OpenTitlesForScan ~= false
Config.RestoreTitlesVisibility = Config.RestoreTitlesVisibility ~= false

if Config.Team ~= "Pirates" and Config.Team ~= "Marines" then
    Config.Team = "Pirates"
end
if Config.Interval < 1 then
    Config.Interval = 1
end


local TARGETS = {
    {number = 8,  numberText = "#008", race = "Human",  title = "Full Power",         obtainment = "Unlock Human V3."},
    {number = 9,  numberText = "#009", race = "Rabbit", title = "Godspeed",           obtainment = "Unlock Rabbit V3."},
    {number = 10, numberText = "#010", race = "Shark",  title = "Warrior of the Sea", obtainment = "Unlock Shark V3."},
    {number = 11, numberText = "#011", race = "Angel",  title = "Perfect Being",      obtainment = "Unlock Angel V3."},
    {number = 12, numberText = "#012", race = "Ghoul",  title = "Hell Hound",          obtainment = "Unlock Ghoul V3."},
    {number = 13, numberText = "#013", race = "Cyborg", title = "War Machine",         obtainment = "Unlock Cyborg V3."},
    {number = 15, numberText = "#015", race = "Draco",  title = "Ancient Flame",       obtainment = "Unlock Draco V3."},
}


local METHOD_ID = "REMOTE_TITLE"
local METHOD_LABEL = "02 - CHECK BY TITLE NAME"
local METHOD_DESCRIPTION = "Only checks exact title names such as Full Power or Godspeed inside getTitles. FOUND proves the title record exists, not ownership."

local running = true
local scanning = false
local scanCount = 0
local rows = {}
local statusLabel
local timerLabel
local gui

local function trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function normalize(value)
    return tostring(value or ""):lower():gsub("[^%w]", "")
end

local function safePath(instance)
    local parts = {}
    local current = instance
    local limit = 0
    while current and limit < 12 do
        table.insert(parts, 1, current.Name)
        current = current.Parent
        limit = limit + 1
    end
    return table.concat(parts, ".")
end

local function strictBool(value)
    if value == true then return true end
    if value == false then return false end

    if type(value) == "number" then
        if value == 1 then return true end
        if value == 0 then return false end
        return nil
    end

    if type(value) == "string" then
        local n = normalize(value)
        if n == "true" or n == "yes" or n == "owned"
            or n == "unlocked" or n == "obtained"
            or n == "acquired" or n == "claimed"
        then
            return true
        end

        if n == "false" or n == "no" or n == "locked"
            or n == "notowned" or n == "notunlocked"
        then
            return false
        end
    end

    return nil
end

local function walkTables(value, path, depth, visited, callback)
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
            walkTables(
                child,
                path .. "[" .. tostring(key) .. "]",
                depth + 1,
                visited,
                callback
            )
        end
    end
end

local function invokeGetTitles()
    local completed = false
    local okResult = false
    local dataResult
    local errorResult

    task.spawn(function()
        local ok, data = pcall(function()
            return CommF_:InvokeServer("getTitles")
        end)

        okResult = ok
        dataResult = ok and data or nil
        errorResult = ok and nil or tostring(data)
        completed = true
    end)

    local deadline = tick() + 2
    repeat task.wait(0.05) until completed or tick() >= deadline

    if not completed then
        return false, nil, "getTitles timeout"
    end

    return okResult, dataResult, errorResult
end

local function ensureTeam()
    if LocalPlayer.Team then
        return true
    end

    pcall(function()
        CommF_:InvokeServer("SetTeam", Config.Team)
    end)

    task.wait(0.7)

    if LocalPlayer.Team then
        return true
    end

    pcall(function()
        local main = PlayerGui:FindFirstChild("Main")
            or PlayerGui:FindFirstChild("Main (minimal)")
        local choose = main and main:FindFirstChild("ChooseTeam", true)
        local container = choose and choose:FindFirstChild("Container")
        local teamFrame = container and container:FindFirstChild(Config.Team)
        local button = teamFrame and teamFrame:FindFirstChildWhichIsA("GuiButton", true)

        if button then
            if firesignal then
                firesignal(button.Activated)
            else
                button:Activate()
            end
        end
    end)

    return LocalPlayer.Team ~= nil
end

local function targetNumberMatches(target, value)
    if type(value) == "number" then
        return value == target.number
    end

    local raw = trim(value)
    local cleaned = (raw:gsub("#", ""))
    return tonumber(cleaned) == target.number
end

local function targetTitleMatches(target, value)
    return normalize(value) == normalize(target.title)
end

local function targetObtainmentMatches(target, value)
    return normalize(value) == normalize(target.obtainment)
end

local ID_FIELDS = {
    id = true,
    index = true,
    number = true,
    titlenumber = true,
    titleid = true,
}

local TITLE_FIELDS = {
    title = true,
    name = true,
    titlename = true,
    displayname = true,
}

local OBTAIN_FIELDS = {
    obtainment = true,
    requirement = true,
    description = true,
    obtain = true,
}

local TRUE_FIELDS = {
    unlocked = true,
    isunlocked = true,
    owned = true,
    isowned = true,
    obtained = true,
    isobtained = true,
    acquired = true,
    isacquired = true,
    hastitle = true,
    claimed = true,
    isclaimed = true,
}

local LOCK_FIELDS = {
    locked = true,
    islocked = true,
}

local function nodeMatchesTarget(node, target)
    local matches = {
        number = false,
        title = false,
        obtainment = false,
    }

    for key, value in pairs(node) do
        local keyName = normalize(key)

        if type(value) ~= "table" then
            if ID_FIELDS[keyName] and targetNumberMatches(target, value) then
                matches.number = true
            end
            if TITLE_FIELDS[keyName] and targetTitleMatches(target, value) then
                matches.title = true
            end
            if OBTAIN_FIELDS[keyName] and targetObtainmentMatches(target, value) then
                matches.obtainment = true
            end
        end

        if type(key) == "number" and key == target.number then
            matches.number = true
        elseif type(key) == "string" then
            if targetNumberMatches(target, key) then
                matches.number = true
            end
            if targetTitleMatches(target, key) then
                matches.title = true
            end
            if targetObtainmentMatches(target, key) then
                matches.obtainment = true
            end
        end
    end

    return matches
end

local function result(status, detail, raw)
    return {
        status = status,
        detail = detail or "",
        raw = raw,
    }
end

local function findTextItems(root)
    local items = {}
    for _, descendant in ipairs(root:GetDescendants()) do
        if descendant:IsA("TextLabel")
            or descendant:IsA("TextButton")
            or descendant:IsA("TextBox")
        then
            local text = trim(descendant.Text)
            if text ~= "" then
                table.insert(items, {
                    object = descendant,
                    text = text,
                })
            end
        end
    end
    return items
end

local function isDescendantOrSelf(object, ancestor)
    return object == ancestor or object:IsDescendantOf(ancestor)
end

local function commonAncestor(objects, stopAt)
    if #objects == 0 then
        return nil
    end

    local current = objects[1]
    while current and current ~= stopAt.Parent do
        local allInside = true
        for index = 2, #objects do
            if not isDescendantOrSelf(objects[index], current) then
                allInside = false
                break
            end
        end

        if allInside then
            return current
        end

        if current == stopAt then
            break
        end
        current = current.Parent
    end

    return nil
end

local function findGuiCard(titlesFrame, target)
    local textItems = findTextItems(titlesFrame)
    local numberObject
    local titleObject
    local obtainmentObject

    for _, item in ipairs(textItems) do
        if not numberObject and targetNumberMatches(target, item.text) then
            numberObject = item.object
        end
        if not titleObject and targetTitleMatches(target, item.text) then
            titleObject = item.object
        end
        if not obtainmentObject and targetObtainmentMatches(target, item.text) then
            obtainmentObject = item.object
        end
    end

    local objects = {}
    if numberObject then table.insert(objects, numberObject) end
    if titleObject then table.insert(objects, titleObject) end
    if obtainmentObject then table.insert(objects, obtainmentObject) end

    local card = nil
    if #objects >= 2 then
        card = commonAncestor(objects, titlesFrame)
        if card == titlesFrame then
            card = nil
        end
    end

    return card, {
        number = numberObject ~= nil,
        title = titleObject ~= nil,
        obtainment = obtainmentObject ~= nil,
    }
end

local function colorFor(status)
    if status == "OWNED" or status == "FOUND" or status == "V3" then
        return Color3.fromRGB(80, 255, 115)
    elseif status == "LOCKED" or status == "NOT_FOUND"
        or status == "NOT_V3" or status == "FALSE"
    then
        return Color3.fromRGB(255, 85, 95)
    elseif status == "CONFLICT" then
        return Color3.fromRGB(255, 175, 55)
    elseif status == "NO_FLAG" or status == "ROW_ONLY"
        or status == "PRESENT_NO_FLAG" or status == "N/A"
    then
        return Color3.fromRGB(90, 185, 255)
    end

    return Color3.fromRGB(190, 190, 200)
end

local function scanTarget(target, remoteData)
    
    if type(remoteData) ~= "table" then
        return result("ERROR", "getTitles did not return table")
    end

    local paths = {}

    walkTables(remoteData, "getTitles", 0, {}, function(node, path)
        local matches = nodeMatchesTarget(node, target)
        if matches.title then
            table.insert(paths, path)
        end
    end)

    if #paths > 0 then
        return result(
            "FOUND",
            "Title name found at " .. tostring(paths[1])
                .. " | proves record exists only"
        )
    end

    return result("NOT_FOUND", "No exact title name matched")

end

local function updateRow(target, scanResult)
    local row = rows[target.number]
    if not row then return end

    row.status.Text = tostring(scanResult.status)
    row.status.TextColor3 = colorFor(scanResult.status)
    row.detail.Text = tostring(scanResult.detail or "")
    row.detail.TextColor3 = colorFor(scanResult.status)
end

local function doScan()
    if scanning or not running then
        return
    end

    scanning = true
    scanCount = scanCount + 1
    statusLabel.Text = "Scan #" .. tostring(scanCount) .. " | joining team..."
    pcall(ensureTeam)

    local remoteOk, remoteData, remoteError = true, nil, nil

    if METHOD_ID ~= "PLAYER_TITLES"
        and METHOD_ID ~= "GUI_STATE"
        and METHOD_ID ~= "WENLOCK_CURRENT"
    then
        statusLabel.Text = "Scan #" .. tostring(scanCount) .. " | getTitles..."
        remoteOk, remoteData, remoteError = invokeGetTitles()
    end

    local main = PlayerGui:FindFirstChild("Main")
    local titlesFrame = main and main:FindFirstChild("Titles")
    local previousVisible = nil

    if METHOD_ID == "GUI_STATE" and titlesFrame and Config.OpenTitlesForScan then
        previousVisible = titlesFrame.Visible
        pcall(function()
            titlesFrame.Visible = true
        end)
        task.wait(0.4)
    end

    for _, target in ipairs(TARGETS) do
        local ok, scanResult = pcall(function()
            return scanTarget(target, remoteData)
        end)

        if ok and type(scanResult) == "table" then
            updateRow(target, scanResult)
        else
            updateRow(target, result("ERROR", tostring(scanResult)))
        end
    end

    if METHOD_ID == "GUI_STATE"
        and titlesFrame
        and Config.RestoreTitlesVisibility
        and previousVisible ~= nil
    then
        pcall(function()
            titlesFrame.Visible = previousVisible
        end)
    end

    if remoteOk then
        statusLabel.Text =
            "Scan #" .. tostring(scanCount)
            .. " | " .. METHOD_LABEL
            .. " | OK"
    else
        statusLabel.Text =
            "Scan #" .. tostring(scanCount)
            .. " | " .. METHOD_LABEL
            .. " | " .. tostring(remoteError)
    end

    scanning = false
end

local function createGui()
    local old = CoreGui:FindFirstChild("RaceV3SingleMethodChecker")
    if old then
        old:Destroy()
    end

    gui = Instance.new("ScreenGui")
    gui.Name = "RaceV3SingleMethodChecker"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local parentTarget = CoreGui
    if gethui then
        pcall(function()
            parentTarget = gethui()
        end)
    end

    local parentOk = pcall(function()
        gui.Parent = parentTarget
    end)
    if not parentOk or not gui.Parent then
        gui.Parent = PlayerGui
    end

    local main = Instance.new("Frame")
    main.Size = UDim2.fromOffset(670, 455)
    main.Position = UDim2.new(0.5, -335, 0.5, -227)
    main.BackgroundColor3 = Color3.fromRGB(17, 18, 24)
    main.BorderSizePixel = 0
    main.Active = true
    main.Draggable = true
    main.Parent = gui
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(90, 145, 255)
    stroke.Thickness = 2
    stroke.Parent = main

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -50, 0, 34)
    title.Position = UDim2.fromOffset(12, 5)
    title.BackgroundTransparency = 1
    title.Text = METHOD_LABEL
    title.TextColor3 = Color3.fromRGB(225, 235, 255)
    title.TextSize = 16
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = main

    local close = Instance.new("TextButton")
    close.Size = UDim2.fromOffset(28, 28)
    close.Position = UDim2.new(1, -36, 0, 7)
    close.BackgroundColor3 = Color3.fromRGB(145, 55, 60)
    close.BorderSizePixel = 0
    close.Text = "X"
    close.TextColor3 = Color3.new(1, 1, 1)
    close.Font = Enum.Font.GothamBold
    close.Parent = main
    Instance.new("UICorner", close).CornerRadius = UDim.new(0, 6)

    local description = Instance.new("TextLabel")
    description.Size = UDim2.new(1, -24, 0, 44)
    description.Position = UDim2.fromOffset(12, 39)
    description.BackgroundTransparency = 1
    description.Text = METHOD_DESCRIPTION
    description.TextColor3 = Color3.fromRGB(160, 170, 195)
    description.TextSize = 11
    description.TextWrapped = true
    description.TextXAlignment = Enum.TextXAlignment.Left
    description.TextYAlignment = Enum.TextYAlignment.Top
    description.Font = Enum.Font.Gotham
    description.Parent = main

    statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, -24, 0, 22)
    statusLabel.Position = UDim2.fromOffset(12, 84)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "Waiting for first scan..."
    statusLabel.TextColor3 = Color3.fromRGB(175, 185, 205)
    statusLabel.TextSize = 11
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.Parent = main

    local header = Instance.new("TextLabel")
    header.Size = UDim2.new(1, -24, 0, 24)
    header.Position = UDim2.fromOffset(12, 108)
    header.BackgroundColor3 = Color3.fromRGB(30, 33, 43)
    header.BorderSizePixel = 0
    header.Text = "RACE / TITLE                         RESULT                  EXACT DETAIL"
    header.TextColor3 = Color3.fromRGB(155, 165, 190)
    header.TextSize = 10
    header.Font = Enum.Font.GothamBold
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.Parent = main
    Instance.new("UICorner", header).CornerRadius = UDim.new(0, 5)

    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, -24, 0, 275)
    holder.Position = UDim2.fromOffset(12, 138)
    holder.BackgroundTransparency = 1
    holder.Parent = main

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 5)
    layout.Parent = holder

    for order, target in ipairs(TARGETS) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 34)
        row.BackgroundColor3 = Color3.fromRGB(24, 26, 34)
        row.BorderSizePixel = 0
        row.LayoutOrder = order
        row.Parent = holder
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 5)

        local name = Instance.new("TextLabel")
        name.Size = UDim2.new(0.43, -8, 1, 0)
        name.Position = UDim2.fromOffset(8, 0)
        name.BackgroundTransparency = 1
        name.Text =
            target.numberText .. " "
            .. target.race .. " | "
            .. target.title
        name.TextColor3 = Color3.fromRGB(230, 230, 235)
        name.TextSize = 10
        name.Font = Enum.Font.GothamSemibold
        name.TextXAlignment = Enum.TextXAlignment.Left
        name.TextTruncate = Enum.TextTruncate.AtEnd
        name.Parent = row

        local state = Instance.new("TextLabel")
        state.Size = UDim2.new(0.20, 0, 1, 0)
        state.Position = UDim2.new(0.43, 0, 0, 0)
        state.BackgroundTransparency = 1
        state.Text = "WAIT"
        state.TextColor3 = colorFor("WAIT")
        state.TextSize = 10
        state.Font = Enum.Font.GothamBold
        state.TextXAlignment = Enum.TextXAlignment.Left
        state.Parent = row

        local detail = Instance.new("TextLabel")
        detail.Size = UDim2.new(0.37, -8, 1, 0)
        detail.Position = UDim2.new(0.63, 0, 0, 0)
        detail.BackgroundTransparency = 1
        detail.Text = ""
        detail.TextColor3 = Color3.fromRGB(165, 170, 185)
        detail.TextSize = 9
        detail.Font = Enum.Font.Gotham
        detail.TextXAlignment = Enum.TextXAlignment.Left
        detail.TextWrapped = true
        detail.TextTruncate = Enum.TextTruncate.AtEnd
        detail.Parent = row

        rows[target.number] = {
            status = state,
            detail = detail,
        }
    end

    timerLabel = Instance.new("TextLabel")
    timerLabel.Size = UDim2.new(1, -24, 0, 22)
    timerLabel.Position = UDim2.new(0, 12, 1, -28)
    timerLabel.BackgroundTransparency = 1
    timerLabel.Text =
        "Next scan: " .. tostring(Config.Interval)
        .. "s | RightShift: hide/show"
    timerLabel.TextColor3 = Color3.fromRGB(130, 140, 165)
    timerLabel.TextSize = 10
    timerLabel.Font = Enum.Font.Gotham
    timerLabel.TextXAlignment = Enum.TextXAlignment.Left
    timerLabel.Parent = main

    close.MouseButton1Click:Connect(function()
        running = false
        if gui then gui:Destroy() end
    end)
end

createGui()

task.spawn(function()
    while running and not LocalPlayer.Team do
        pcall(ensureTeam)
        task.wait(1)
    end
end)

task.spawn(function()
    while running do
        doScan()

        for remaining = Config.Interval, 1, -1 do
            if not running then return end

            timerLabel.Text =
                "Next scan: " .. tostring(remaining)
                .. "s | " .. METHOD_ID
                .. " | RightShift: hide/show"
            task.wait(1)
        end
    end
end)

UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.RightShift then
        if gui then
            gui.Enabled = not gui.Enabled
        end
    end
end)

getgenv().__RACE_V3_SINGLE_CHECKER_STOP = function()
    running = false
    pcall(function()
        if gui then gui:Destroy() end
    end)
end

print("[RaceV3SingleChecker]", METHOD_ID, METHOD_LABEL)
