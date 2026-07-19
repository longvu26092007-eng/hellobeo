--[[
    RACE TITLE MULTI-CHECKER - BLOX FRUITS
    Diagnostic checker for Race V2/V3 titles.

    Features:
      - Auto joins Pirates/Marines.
      - Scans every 3 seconds.
      - Checks title number, title name, obtainment text, getTitles return data,
        Player.Titles data, GUI card attributes, lock/equip/selected states.
      - Does NOT reroll race and does NOT spend Fragments.
      - Uses strict statuses to avoid treating mere text presence as ownership.
      - Writes diagnostic JSON/TXT files when executor supports writefile.

    Configure before executing:
      getgenv().RaceTitleCheckerConfig = {
          Team = "Pirates",       -- "Pirates" or "Marines"
          Interval = 3,
          SaveDebug = true,
          OpenTitlesForScan = true,
          RestoreTitlesVisibility = true,
      }
]]

if getgenv().__RACE_TITLE_CHECKER_STOP then
    pcall(getgenv().__RACE_TITLE_CHECKER_STOP)
end

repeat task.wait(0.5) until game:IsLoaded()
    and game:GetService("Players").LocalPlayer
    and game:GetService("Players").LocalPlayer:FindFirstChildWhichIsA("PlayerGui")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local CommF_ = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_")

local Config = getgenv().RaceTitleCheckerConfig or {}
Config.Team = Config.Team or getgenv().Team or "Pirates"
Config.Interval = tonumber(Config.Interval) or 3
Config.SaveDebug = Config.SaveDebug ~= false
Config.OpenTitlesForScan = Config.OpenTitlesForScan ~= false
Config.RestoreTitlesVisibility = Config.RestoreTitlesVisibility ~= false

if Config.Team ~= "Pirates" and Config.Team ~= "Marines" then
    Config.Team = "Pirates"
end
if Config.Interval < 1 then
    Config.Interval = 1
end

local TARGETS = {
    {number = 1,  numberText = "#001", race = "Human",   version = 2, title = "The Unleashed",       obtainment = "Unlock Human V2."},
    {number = 2,  numberText = "#002", race = "Rabbit",  version = 2, title = "Unmatched Speed",     obtainment = "Unlock Rabbit V2."},
    {number = 3,  numberText = "#003", race = "Shark",   version = 2, title = "Sea Monster",         obtainment = "Unlock Shark V2."},
    {number = 4,  numberText = "#004", race = "Angel",   version = 2, title = "Sacred Warrior",      obtainment = "Unlock Angel V2."},
    {number = 5,  numberText = "#005", race = "Ghoul",   version = 2, title = "The Ghoul",           obtainment = "Unlock Ghoul V2."},
    {number = 6,  numberText = "#006", race = "Cyborg",  version = 2, title = "The Cyborg",          obtainment = "Unlock Cyborg V2."},
    {number = 7,  numberText = "#007", race = "Draco",   version = 2, title = "Elder Wyrm",          obtainment = "Unlock Draco V2."},

    {number = 8,  numberText = "#008", race = "Human",   version = 3, title = "Full Power",          obtainment = "Unlock Human V3."},
    {number = 9,  numberText = "#009", race = "Rabbit",  version = 3, title = "Godspeed",            obtainment = "Unlock Rabbit V3."},
    {number = 10, numberText = "#010", race = "Shark",   version = 3, title = "Warrior of the Sea",  obtainment = "Unlock Shark V3."},
    {number = 11, numberText = "#011", race = "Angel",   version = 3, title = "Perfect Being",       obtainment = "Unlock Angel V3."},
    {number = 12, numberText = "#012", race = "Ghoul",   version = 3, title = "Hell Hound",          obtainment = "Unlock Ghoul V3."},
    {number = 13, numberText = "#013", race = "Cyborg",  version = 3, title = "War Machine",         obtainment = "Unlock Cyborg V3."},
    {number = 15, numberText = "#015", race = "Draco",   version = 3, title = "Ancient Flame",       obtainment = "Unlock Draco V3."},
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

local OWNED_WORDS = {
    ["equipped"] = true,
    ["selected"] = true,
    ["owned"] = true,
    ["unlocked"] = true,
    ["obtained"] = true,
    ["acquired"] = true,
    ["use title"] = true,
    ["equip"] = true,
}

local LOCKED_WORDS = {
    ["locked"] = true,
    ["not owned"] = true,
    ["not unlocked"] = true,
    ["???"] = true,
}

local running = true
local scanBusy = false
local scanCount = 0
local lastSavedSignature = ""
local rows = {}
local statusLabel
local timerLabel
local summaryLabel
local gui

local function normalize(value)
    local text = tostring(value or ""):lower()
    -- All target identifiers are English/ASCII. Keeping only letters and digits
    -- avoids punctuation/spacing differences such as "#008" and "Unlock Human V3.".
    text = text:gsub("[^%w]", "")
    return text
end

local function trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$")
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

local function addEvidence(result, code, detail, weight, polarity)
    result.evidence = result.evidence or {}
    result.seenEvidence = result.seenEvidence or {}

    local signature = tostring(code) .. "|" .. tostring(detail)
    if result.seenEvidence[signature] then
        return
    end
    result.seenEvidence[signature] = true

    table.insert(result.evidence, {
        code = tostring(code),
        detail = tostring(detail or ""),
        weight = tonumber(weight) or 0,
        polarity = polarity or "info",
    })

    if polarity == "owned" then
        result.ownedScore = result.ownedScore + (tonumber(weight) or 0)
    elseif polarity == "locked" then
        result.lockedScore = result.lockedScore + (tonumber(weight) or 0)
    else
        result.infoScore = result.infoScore + (tonumber(weight) or 0)
    end
end

local function newResult(target)
    return {
        target = target,
        ownedScore = 0,
        lockedScore = 0,
        infoScore = 0,
        remoteExplicitOwned = false,
        remoteExplicitLocked = false,
        guiExplicitOwned = false,
        guiExplicitLocked = false,
        playerExplicitOwned = false,
        playerExplicitLocked = false,
        evidence = {},
        seenEvidence = {},
        status = "UNKNOWN",
        reason = "No reliable ownership flag",
    }
end

local function targetMatchesScalar(target, value, fieldKind)
    local raw = trim(value)
    local n = normalize(raw)

    if fieldKind == "number" then
        local asNumber = tonumber(raw:gsub("#", ""))
        return asNumber == target.number
    elseif fieldKind == "title" then
        return n == normalize(target.title)
    elseif fieldKind == "obtainment" then
        return n == normalize(target.obtainment)
    end

    if n == normalize(target.title) or n == normalize(target.obtainment) then
        return true
    end

    if raw == target.numberText then
        return true
    end

    return false
end

local function boolLike(value)
    if value == true then
        return true
    end
    if value == false then
        return false
    end
    if type(value) == "number" then
        if value == 1 then return true end
        if value == 0 then return false end
    end
    if type(value) == "string" then
        local n = normalize(value)
        if n == "true" or n == "yes" or n == "owned" or n == "unlocked" or n == "obtained" then
            return true
        end
        if n == "false" or n == "no" or n == "locked" or n == "notowned" or n == "notunlocked" then
            return false
        end
    end
    return nil
end

local function tableNodeMatchesTarget(node, target)
    if type(node) ~= "table" then
        return false, {}
    end

    local matched = {}
    for key, value in pairs(node) do
        local keyName = normalize(key)

        if type(value) ~= "table" then
            if ID_FIELDS[keyName] and targetMatchesScalar(target, value, "number") then
                matched.number = true
            elseif TITLE_FIELDS[keyName] and targetMatchesScalar(target, value, "title") then
                matched.title = true
            elseif OBTAIN_FIELDS[keyName] and targetMatchesScalar(target, value, "obtainment") then
                matched.obtainment = true
            else
                if targetMatchesScalar(target, value) then
                    matched.generic = true
                end
            end
        end

        if type(key) == "number" and key == target.number then
            matched.numberKey = true
        elseif type(key) == "string" then
            if targetMatchesScalar(target, key, "title") then
                matched.titleKey = true
            elseif targetMatchesScalar(target, key, "obtainment") then
                matched.obtainmentKey = true
            elseif targetMatchesScalar(target, key, "number") then
                matched.numberKey = true
            end
        end
    end

    return next(matched) ~= nil, matched
end

local function inspectRemoteNode(node, path, depth, results, visited)
    if depth > 8 then
        return
    end

    if type(node) ~= "table" then
        return
    end

    if visited[node] then
        return
    end
    visited[node] = true

    for _, result in ipairs(results) do
        local target = result.target
        local related, matched = tableNodeMatchesTarget(node, target)

        if related then
            if matched.number or matched.numberKey then
                addEvidence(result, "REMOTE_NUMBER", path, 1, "info")
            end
            if matched.title or matched.titleKey then
                addEvidence(result, "REMOTE_TITLE", path, 1, "info")
            end
            if matched.obtainment or matched.obtainmentKey then
                addEvidence(result, "REMOTE_OBTAINMENT", path, 1, "info")
            end
            if matched.generic then
                addEvidence(result, "REMOTE_TEXT", path, 1, "info")
            end

            for key, value in pairs(node) do
                local keyName = normalize(key)

                if TRUE_FIELDS[keyName] then
                    local state = boolLike(value)
                    if state == true then
                        result.remoteExplicitOwned = true
                        addEvidence(result, "REMOTE_" .. string.upper(tostring(key)), path .. "=" .. tostring(value), 10, "owned")
                    elseif state == false then
                        result.remoteExplicitLocked = true
                        addEvidence(result, "REMOTE_" .. string.upper(tostring(key)), path .. "=" .. tostring(value), 10, "locked")
                    end
                elseif LOCK_FIELDS[keyName] then
                    local state = boolLike(value)
                    if state == true then
                        result.remoteExplicitLocked = true
                        addEvidence(result, "REMOTE_" .. string.upper(tostring(key)), path .. "=" .. tostring(value), 10, "locked")
                    elseif state == false then
                        result.remoteExplicitOwned = true
                        addEvidence(result, "REMOTE_NOT_LOCKED", path .. "=" .. tostring(value), 8, "owned")
                    end
                end
            end
        end
    end

    for key, value in pairs(node) do
        local childPath = path .. "[" .. tostring(key) .. "]"

        for _, result in ipairs(results) do
            local target = result.target
            local keyName = normalize(key)
            local parentContext = normalize(path)

            if type(value) ~= "table" then
                local state = boolLike(value)

                local keyIsTarget =
                    targetMatchesScalar(target, key, "number")
                    or targetMatchesScalar(target, key, "title")
                    or targetMatchesScalar(target, key, "obtainment")

                if keyIsTarget and state ~= nil then
                    if state then
                        result.remoteExplicitOwned = true
                        addEvidence(result, "REMOTE_KEY_TRUE", childPath, 10, "owned")
                    else
                        result.remoteExplicitLocked = true
                        addEvidence(result, "REMOTE_KEY_FALSE", childPath, 10, "locked")
                    end
                end

                local valueMatches =
                    targetMatchesScalar(target, value, "number")
                    or targetMatchesScalar(target, value, "title")
                    or targetMatchesScalar(target, value, "obtainment")

                if valueMatches then
                    if parentContext:find("unlock", 1, true)
                        or parentContext:find("owned", 1, true)
                        or parentContext:find("obtain", 1, true)
                        or keyName:find("unlock", 1, true)
                        or keyName:find("owned", 1, true)
                    then
                        result.remoteExplicitOwned = true
                        addEvidence(result, "REMOTE_UNLOCKED_LIST", childPath .. "=" .. tostring(value), 9, "owned")
                    else
                        addEvidence(result, "REMOTE_LIST_MATCH", childPath .. "=" .. tostring(value), 2, "info")
                    end
                end
            end
        end

        if type(value) == "table" then
            inspectRemoteNode(value, childPath, depth + 1, results, visited)
        end
    end
end

local function inspectPlayerTitles(results)
    local folder = LocalPlayer:FindFirstChild("Titles")
    if not folder then
        return
    end

    for _, instance in ipairs(folder:GetDescendants()) do
        local name = instance.Name
        local value
        local hasValue = false

        if instance:IsA("ValueBase") then
            local ok, readValue = pcall(function()
                return instance.Value
            end)
            if ok then
                value = readValue
                hasValue = true
            end
        end

        for _, result in ipairs(results) do
            local target = result.target
            local nameMatches =
                targetMatchesScalar(target, name, "number")
                or targetMatchesScalar(target, name, "title")
                or targetMatchesScalar(target, name, "obtainment")

            local valueMatches = false
            if hasValue then
                valueMatches =
                    targetMatchesScalar(target, value, "number")
                    or targetMatchesScalar(target, value, "title")
                    or targetMatchesScalar(target, value, "obtainment")
            end

            if nameMatches or valueMatches then
                addEvidence(result, "PLAYER_TITLES_MATCH", safePath(instance), 2, "info")

                if instance:IsA("BoolValue") then
                    if instance.Value == true then
                        result.playerExplicitOwned = true
                        addEvidence(result, "PLAYER_BOOL_TRUE", safePath(instance), 9, "owned")
                    else
                        result.playerExplicitLocked = true
                        addEvidence(result, "PLAYER_BOOL_FALSE", safePath(instance), 9, "locked")
                    end
                elseif instance:IsA("IntValue") or instance:IsA("NumberValue") then
                    if tonumber(instance.Value) == 1 then
                        result.playerExplicitOwned = true
                        addEvidence(result, "PLAYER_VALUE_1", safePath(instance), 7, "owned")
                    elseif tonumber(instance.Value) == 0 then
                        result.playerExplicitLocked = true
                        addEvidence(result, "PLAYER_VALUE_0", safePath(instance), 7, "locked")
                    end
                else
                    addEvidence(result, "PLAYER_INSTANCE_PRESENT", safePath(instance), 3, "info")
                end
            end

            for attributeName, attributeValue in pairs(instance:GetAttributes()) do
                local attrKey = normalize(attributeName)
                if nameMatches or valueMatches then
                    if TRUE_FIELDS[attrKey] then
                        local state = boolLike(attributeValue)
                        if state == true then
                            result.playerExplicitOwned = true
                            addEvidence(result, "PLAYER_ATTR_" .. string.upper(attributeName), safePath(instance), 9, "owned")
                        elseif state == false then
                            result.playerExplicitLocked = true
                            addEvidence(result, "PLAYER_ATTR_" .. string.upper(attributeName), safePath(instance), 9, "locked")
                        end
                    elseif LOCK_FIELDS[attrKey] then
                        local state = boolLike(attributeValue)
                        if state == true then
                            result.playerExplicitLocked = true
                            addEvidence(result, "PLAYER_ATTR_LOCKED", safePath(instance), 9, "locked")
                        elseif state == false then
                            result.playerExplicitOwned = true
                            addEvidence(result, "PLAYER_ATTR_NOT_LOCKED", safePath(instance), 7, "owned")
                        end
                    end
                end
            end
        end
    end
end

local function textOf(instance)
    if instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") then
        return trim(instance.Text)
    end
    return ""
end

local function collectTextDescendants(root, limit)
    local texts = {}
    local count = 0

    for _, descendant in ipairs(root:GetDescendants()) do
        local text = textOf(descendant)
        if text ~= "" then
            table.insert(texts, {
                text = text,
                object = descendant,
                path = safePath(descendant),
            })
            count = count + 1
            if limit and count >= limit then
                break
            end
        end
    end

    return texts
end

local function markerHitsInRoot(root, target)
    local hits = {
        number = false,
        title = false,
        obtainment = false,
    }

    for _, item in ipairs(collectTextDescendants(root, 250)) do
        if targetMatchesScalar(target, item.text, "number") then
            hits.number = true
        end
        if targetMatchesScalar(target, item.text, "title") then
            hits.title = true
        end
        if targetMatchesScalar(target, item.text, "obtainment") then
            hits.obtainment = true
        end
    end

    return hits
end

local function hitCount(hits)
    local count = 0
    for _, value in pairs(hits) do
        if value then
            count = count + 1
        end
    end
    return count
end

local function findCandidateCards(titlesFrame, target)
    local seedObjects = {}

    for _, descendant in ipairs(titlesFrame:GetDescendants()) do
        local text = textOf(descendant)
        if text ~= "" then
            if targetMatchesScalar(target, text, "number")
                or targetMatchesScalar(target, text, "title")
                or targetMatchesScalar(target, text, "obtainment")
            then
                table.insert(seedObjects, descendant)
            end
        end
    end

    local candidates = {}
    local seen = {}

    for _, seed in ipairs(seedObjects) do
        local current = seed
        local depth = 0

        while current and current ~= titlesFrame and depth < 7 do
            if current:IsA("GuiObject") and not seen[current] then
                local hits = markerHitsInRoot(current, target)
                if hitCount(hits) >= 2 then
                    seen[current] = true
                    table.insert(candidates, {
                        root = current,
                        hits = hits,
                        descendants = #current:GetDescendants(),
                    })
                end
            end
            current = current.Parent
            depth = depth + 1
        end
    end

    table.sort(candidates, function(a, b)
        if hitCount(a.hits) == hitCount(b.hits) then
            return a.descendants < b.descendants
        end
        return hitCount(a.hits) > hitCount(b.hits)
    end)

    return candidates
end

local function exactStateWord(text)
    local normalized = trim(text):lower()
    normalized = normalized:gsub("^%s+", ""):gsub("%s+$", "")
    return OWNED_WORDS[normalized] == true, LOCKED_WORDS[normalized] == true
end

local function inspectGuiCard(cardInfo, result)
    local root = cardInfo.root
    local target = result.target

    if cardInfo.hits.number then
        addEvidence(result, "GUI_NUMBER", safePath(root), 1, "info")
    end
    if cardInfo.hits.title then
        addEvidence(result, "GUI_TITLE", safePath(root), 1, "info")
    end
    if cardInfo.hits.obtainment then
        addEvidence(result, "GUI_OBTAINMENT", safePath(root), 1, "info")
    end

    local interactableButtons = 0
    local connectedButtons = 0

    local inspectList = {root}
    for _, descendant in ipairs(root:GetDescendants()) do
        table.insert(inspectList, descendant)
    end

    for _, instance in ipairs(inspectList) do
        local nameNormalized = normalize(instance.Name)
        local visible = true
        if instance:IsA("GuiObject") then
            visible = instance.Visible
        end

        local text = textOf(instance)
        if text ~= "" and visible then
            local ownedWord, lockedWord = exactStateWord(text)
            if ownedWord then
                result.guiExplicitOwned = true
                addEvidence(result, "GUI_STATE_TEXT", safePath(instance) .. "=" .. text, 9, "owned")
            elseif lockedWord then
                result.guiExplicitLocked = true
                addEvidence(result, "GUI_LOCK_TEXT", safePath(instance) .. "=" .. text, 9, "locked")
            end
        end

        if visible and (nameNormalized == "locked"
            or nameNormalized == "lock"
            or nameNormalized == "lockicon"
            or nameNormalized == "lockedicon")
        then
            result.guiExplicitLocked = true
            addEvidence(result, "GUI_LOCK_OBJECT", safePath(instance), 8, "locked")
        end

        if visible and (nameNormalized == "equipped"
            or nameNormalized == "selected"
            or nameNormalized == "owned"
            or nameNormalized == "unlocked")
        then
            result.guiExplicitOwned = true
            addEvidence(result, "GUI_OWNED_OBJECT", safePath(instance), 8, "owned")
        end

        for attributeName, attributeValue in pairs(instance:GetAttributes()) do
            local attrKey = normalize(attributeName)
            if TRUE_FIELDS[attrKey] then
                local state = boolLike(attributeValue)
                if state == true then
                    result.guiExplicitOwned = true
                    addEvidence(result, "GUI_ATTR_" .. string.upper(attributeName), safePath(instance), 10, "owned")
                elseif state == false then
                    result.guiExplicitLocked = true
                    addEvidence(result, "GUI_ATTR_" .. string.upper(attributeName), safePath(instance), 10, "locked")
                end
            elseif LOCK_FIELDS[attrKey] then
                local state = boolLike(attributeValue)
                if state == true then
                    result.guiExplicitLocked = true
                    addEvidence(result, "GUI_ATTR_LOCKED", safePath(instance), 10, "locked")
                elseif state == false then
                    result.guiExplicitOwned = true
                    addEvidence(result, "GUI_ATTR_NOT_LOCKED", safePath(instance), 8, "owned")
                end
            end
        end

        if instance:IsA("BoolValue") then
            local key = normalize(instance.Name)
            if TRUE_FIELDS[key] then
                if instance.Value then
                    result.guiExplicitOwned = true
                    addEvidence(result, "GUI_BOOL_TRUE", safePath(instance), 9, "owned")
                else
                    result.guiExplicitLocked = true
                    addEvidence(result, "GUI_BOOL_FALSE", safePath(instance), 9, "locked")
                end
            elseif LOCK_FIELDS[key] then
                if instance.Value then
                    result.guiExplicitLocked = true
                    addEvidence(result, "GUI_LOCK_BOOL_TRUE", safePath(instance), 9, "locked")
                else
                    result.guiExplicitOwned = true
                    addEvidence(result, "GUI_LOCK_BOOL_FALSE", safePath(instance), 7, "owned")
                end
            end
        end

        if instance:IsA("GuiButton") and visible then
            local active = false
            pcall(function()
                active = instance.Active and instance.Selectable
            end)

            if active then
                interactableButtons = interactableButtons + 1
            end

            if getconnections then
                local connectionCount = 0
                pcall(function()
                    connectionCount = #getconnections(instance.Activated)
                end)
                if connectionCount > 0 then
                    connectedButtons = connectedButtons + 1
                end
            end
        end
    end

    if interactableButtons > 0 then
        addEvidence(result, "GUI_ACTIVE_BUTTON", safePath(root) .. " count=" .. tostring(interactableButtons), 2, "info")
    end
    if connectedButtons > 0 then
        addEvidence(result, "GUI_CONNECTED_BUTTON", safePath(root) .. " count=" .. tostring(connectedButtons), 2, "info")
    end

    if cardInfo.hits.number and cardInfo.hits.title and cardInfo.hits.obtainment then
        addEvidence(result, "GUI_FULL_ROW_MATCH", safePath(root), 3, "info")
    end
end

local function inspectGui(results)
    local main = PlayerGui:FindFirstChild("Main")
    local titlesFrame = main and main:FindFirstChild("Titles")
    if not titlesFrame then
        return false, "PlayerGui.Main.Titles not found"
    end

    for _, result in ipairs(results) do
        local candidates = findCandidateCards(titlesFrame, result.target)
        if #candidates > 0 then
            inspectGuiCard(candidates[1], result)

            if #candidates > 1 then
                addEvidence(result, "GUI_CANDIDATES", tostring(#candidates), 1, "info")
            end
        end
    end

    return true, "GUI scanned"
end

local function finalizeResult(result)
    if result.remoteExplicitOwned or result.guiExplicitOwned or result.playerExplicitOwned then
        result.status = "CONFIRMED"
        result.reason = "Explicit owned/unlocked state detected"
        return
    end

    if result.remoteExplicitLocked or result.guiExplicitLocked or result.playerExplicitLocked then
        if result.ownedScore > result.lockedScore then
            result.status = "PROBABLE"
            result.reason = "Conflicting evidence; owned score is higher"
        else
            result.status = "LOCKED"
            result.reason = "Explicit locked/false state detected"
        end
        return
    end

    if result.ownedScore >= 8 then
        result.status = "CONFIRMED"
        result.reason = "Strong independent ownership evidence"
    elseif result.ownedScore >= 4 or result.infoScore >= 8 then
        result.status = "PROBABLE"
        result.reason = "Multiple matches, but no explicit ownership flag"
    elseif result.infoScore > 0 then
        result.status = "FOUND_ONLY"
        result.reason = "Title row/text exists; ownership is not proven"
    else
        result.status = "UNKNOWN"
        result.reason = "No matching title data found"
    end
end

local function sanitize(value, depth, visited)
    depth = depth or 0
    visited = visited or {}

    if depth > 7 then
        return "<max-depth>"
    end

    local valueType = typeof(value)
    if valueType == "nil" or valueType == "boolean" or valueType == "number" or valueType == "string" then
        return value
    end

    if valueType == "Instance" then
        return {
            __type = "Instance",
            class = value.ClassName,
            name = value.Name,
            path = safePath(value),
        }
    end

    if type(value) == "table" then
        if visited[value] then
            return "<cycle>"
        end
        visited[value] = true

        local output = {}
        local count = 0
        for key, child in pairs(value) do
            count = count + 1
            if count > 500 then
                output.__truncated = true
                break
            end
            output[tostring(key)] = sanitize(child, depth + 1, visited)
        end
        return output
    end

    return tostring(value)
end

local function compactEvidence(result)
    local output = {}
    for _, evidence in ipairs(result.evidence) do
        table.insert(output, {
            code = evidence.code,
            detail = evidence.detail,
            weight = evidence.weight,
            polarity = evidence.polarity,
        })
    end
    return output
end

local function buildSerializable(results, remoteOk, remoteData, remoteError, guiMessage)
    local outputResults = {}

    for _, result in ipairs(results) do
        table.insert(outputResults, {
            number = result.target.number,
            numberText = result.target.numberText,
            race = result.target.race,
            version = result.target.version,
            title = result.target.title,
            obtainment = result.target.obtainment,
            status = result.status,
            reason = result.reason,
            ownedScore = result.ownedScore,
            lockedScore = result.lockedScore,
            infoScore = result.infoScore,
            evidence = compactEvidence(result),
        })
    end

    return {
        checker = "Race Title Multi-Checker",
        version = "2.0-fast-safe",
        player = {
            name = LocalPlayer.Name,
            userId = LocalPlayer.UserId,
            race = LocalPlayer:FindFirstChild("Data")
                and LocalPlayer.Data:FindFirstChild("Race")
                and tostring(LocalPlayer.Data.Race.Value)
                or "Unknown",
            team = LocalPlayer.Team and LocalPlayer.Team.Name or "None",
        },
        scan = {
            count = scanCount,
            timestamp = os.time(),
            interval = Config.Interval,
            remoteOk = remoteOk,
            remoteError = remoteError,
            remoteType = typeof(remoteData),
            guiMessage = guiMessage,
        },
        results = outputResults,
        rawGetTitles = sanitize(remoteData),
    }
end

local function makefolderSafe(path)
    if not makefolder or not isfolder then
        return false
    end

    if not isfolder(path) then
        local ok = pcall(function()
            makefolder(path)
        end)
        return ok
    end

    return true
end

local function saveDebug(serializable)
    if not Config.SaveDebug or not writefile then
        return
    end

    local folder = "RaceTitleChecker"
    if makefolder and isfolder then
        makefolderSafe(folder)
    else
        folder = ""
    end

    local baseName = LocalPlayer.Name .. "-" .. tostring(LocalPlayer.UserId)
    local jsonName = (folder ~= "" and (folder .. "/") or "") .. baseName .. "-latest.json"
    local textName = (folder ~= "" and (folder .. "/") or "") .. baseName .. "-summary.txt"

    local okJson, encoded = pcall(function()
        return HttpService:JSONEncode(serializable)
    end)

    if okJson then
        local signature = encoded
        if signature ~= lastSavedSignature then
            lastSavedSignature = signature
            pcall(function()
                writefile(jsonName, encoded)
            end)
        end
    end

    local lines = {
        "RACE TITLE MULTI-CHECKER",
        "Player: " .. LocalPlayer.Name .. " (" .. tostring(LocalPlayer.UserId) .. ")",
        "Scan: " .. tostring(scanCount),
        "Time: " .. tostring(os.time()),
        "Remote: " .. tostring(serializable.scan.remoteOk) .. " / " .. tostring(serializable.scan.remoteType),
        "",
    }

    for _, result in ipairs(serializable.results) do
        table.insert(lines,
            result.numberText .. " | "
            .. result.race .. " V" .. tostring(result.version) .. " | "
            .. result.title .. " | "
            .. result.status
            .. " | owned=" .. tostring(result.ownedScore)
            .. " locked=" .. tostring(result.lockedScore)
            .. " info=" .. tostring(result.infoScore)
        )

        for _, evidence in ipairs(result.evidence) do
            table.insert(lines, "  - " .. evidence.code .. " | " .. evidence.polarity .. " | " .. evidence.detail)
        end
    end

    pcall(function()
        writefile(textName, table.concat(lines, "\n"))
    end)
end

local function statusColor(status)
    if status == "CONFIRMED" then
        return Color3.fromRGB(90, 255, 120)
    elseif status == "LOCKED" then
        return Color3.fromRGB(255, 90, 90)
    elseif status == "PROBABLE" then
        return Color3.fromRGB(255, 205, 80)
    elseif status == "FOUND_ONLY" then
        return Color3.fromRGB(110, 190, 255)
    end
    return Color3.fromRGB(185, 185, 195)
end

local function evidencePreview(result)
    local parts = {}

    for _, evidence in ipairs(result.evidence) do
        if #parts >= 3 then
            break
        end
        table.insert(parts, evidence.code)
    end

    if #parts == 0 then
        return result.reason
    end

    return table.concat(parts, " + ")
end

local function updateUi(results, remoteOk, remoteData, guiMessage)
    local confirmed = 0
    local locked = 0
    local probable = 0
    local unknown = 0

    for _, result in ipairs(results) do
        if result.status == "CONFIRMED" then
            confirmed = confirmed + 1
        elseif result.status == "LOCKED" then
            locked = locked + 1
        elseif result.status == "PROBABLE" then
            probable = probable + 1
        else
            unknown = unknown + 1
        end

        local row = rows[result.target.number]
        if row then
            row.status.Text = result.status
            row.status.TextColor3 = statusColor(result.status)
            row.detail.Text = evidencePreview(result)
            row.detail.TextColor3 = statusColor(result.status)
        end
    end

    summaryLabel.Text =
        "Confirmed: " .. tostring(confirmed)
        .. " | Locked: " .. tostring(locked)
        .. " | Probable: " .. tostring(probable)
        .. " | Other: " .. tostring(unknown)

    statusLabel.Text =
        "Scan #" .. tostring(scanCount)
        .. " | getTitles: " .. (remoteOk and ("OK/" .. typeof(remoteData)) or "ERROR")
        .. " | " .. tostring(guiMessage)
end

local function ensureTeam()
    if LocalPlayer.Team then
        return true
    end

    pcall(function()
        CommF_:InvokeServer("SetTeam", Config.Team)
    end)

    task.wait(0.8)

    if LocalPlayer.Team then
        return true
    end

    pcall(function()
        local main = PlayerGui:FindFirstChild("Main")
            or PlayerGui:FindFirstChild("Main (minimal)")
        local chooseTeam = main and main:FindFirstChild("ChooseTeam", true)
        local container = chooseTeam and chooseTeam:FindFirstChild("Container")
        local teamFrame = container and container:FindFirstChild(Config.Team)

        if teamFrame then
            local button = teamFrame:FindFirstChildWhichIsA("GuiButton", true)
            if button then
                if firesignal then
                    firesignal(button.Activated)
                else
                    button:Activate()
                end
            end
        end
    end)

    return LocalPlayer.Team ~= nil
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

-- Lightweight GUI scanner:
-- Collects the title menu text once, then finds the smallest shared card for
-- number/title/obtainment. This avoids rescanning the entire menu many times.
local function inspectGuiFast(results)
    local main = PlayerGui:FindFirstChild("Main")
    local titlesFrame = main and main:FindFirstChild("Titles")
    if not titlesFrame then
        return false, "PlayerGui.Main.Titles not found"
    end

    local textItems = {}
    for _, descendant in ipairs(titlesFrame:GetDescendants()) do
        if descendant:IsA("TextLabel")
            or descendant:IsA("TextButton")
            or descendant:IsA("TextBox")
        then
            local value = trim(descendant.Text)
            if value ~= "" then
                table.insert(textItems, {
                    object = descendant,
                    text = value,
                })
            end
        end
    end

    for _, result in ipairs(results) do
        local target = result.target
        local numberObject
        local titleObject
        local obtainmentObject

        for _, item in ipairs(textItems) do
            if not numberObject and targetMatchesScalar(target, item.text, "number") then
                numberObject = item.object
                addEvidence(result, "GUI_NUMBER", safePath(item.object), 1, "info")
            end

            if not titleObject and targetMatchesScalar(target, item.text, "title") then
                titleObject = item.object
                addEvidence(result, "GUI_TITLE", safePath(item.object), 1, "info")
            end

            if not obtainmentObject and targetMatchesScalar(target, item.text, "obtainment") then
                obtainmentObject = item.object
                addEvidence(result, "GUI_OBTAINMENT", safePath(item.object), 1, "info")
            end
        end

        local markerObjects = {}
        if numberObject then table.insert(markerObjects, numberObject) end
        if titleObject then table.insert(markerObjects, titleObject) end
        if obtainmentObject then table.insert(markerObjects, obtainmentObject) end

        if #markerObjects >= 2 then
            local card = commonAncestor(markerObjects, titlesFrame)
            if card and card ~= titlesFrame then
                local hits = {
                    number = numberObject ~= nil,
                    title = titleObject ~= nil,
                    obtainment = obtainmentObject ~= nil,
                }
                inspectGuiCard({
                    root = card,
                    hits = hits,
                    descendants = #card:GetDescendants(),
                }, result)
            elseif #markerObjects == 3 then
                addEvidence(result, "GUI_FULL_ROW_TEXT", "All 3 markers found but card unresolved", 3, "info")
            end
        end
    end

    return true, "Fast GUI scan: " .. tostring(#textItems) .. " text objects"
end

local remoteRequest = {
    inFlight = false,
    ok = false,
    data = nil,
    error = "not requested",
    completedAt = 0,
}

local function startGetTitlesRequest()
    if remoteRequest.inFlight then
        return
    end

    remoteRequest.inFlight = true

    task.spawn(function()
        local ok, result = pcall(function()
            return CommF_:InvokeServer("getTitles")
        end)

        remoteRequest.ok = ok
        remoteRequest.data = ok and result or nil
        remoteRequest.error = ok and nil or tostring(result)
        remoteRequest.completedAt = tick()
        remoteRequest.inFlight = false
    end)
end

-- InvokeServer cannot be forcibly cancelled. Run it in a separate task and let
-- the checker continue after a short timeout. If it returns later, the next scan
-- will use the cached result.
local function invokeGetTitles(timeoutSeconds)
    timeoutSeconds = tonumber(timeoutSeconds) or 1.5
    local previousCompletedAt = remoteRequest.completedAt

    startGetTitlesRequest()

    local deadline = tick() + timeoutSeconds
    repeat
        task.wait(0.05)
    until remoteRequest.completedAt ~= previousCompletedAt
        or not remoteRequest.inFlight
        or tick() >= deadline

    if remoteRequest.completedAt ~= previousCompletedAt then
        return remoteRequest.ok, remoteRequest.data, remoteRequest.error
    end

    if remoteRequest.completedAt > 0 then
        return remoteRequest.ok, remoteRequest.data,
            remoteRequest.error or "using cached getTitles response"
    end

    return false, nil, "getTitles timeout; GUI scan continued"
end

local function scanErrorHandler(err)
    local message = tostring(err)
    pcall(function()
        if debug and debug.traceback then
            message = debug.traceback(message, 2)
        end
    end)
    return message
end

local function doScan()
    if scanBusy or not running then
        return
    end

    scanBusy = true
    scanCount = scanCount + 1

    local scanOk, scanError = xpcall(function()
        statusLabel.Text = "Scan #" .. tostring(scanCount) .. " | Step 1/5: joining team..."
        pcall(ensureTeam)

        local results = {}
        for _, target in ipairs(TARGETS) do
            table.insert(results, newResult(target))
        end

        statusLabel.Text = "Scan #" .. tostring(scanCount) .. " | Step 2/5: requesting getTitles..."
        local remoteOk, remoteData, remoteError = invokeGetTitles(1.5)

        statusLabel.Text = "Scan #" .. tostring(scanCount) .. " | Step 3/5: parsing title data..."
        if remoteOk and type(remoteData) == "table" then
            inspectRemoteNode(remoteData, "getTitles", 0, results, {})
        end
        inspectPlayerTitles(results)

        local previousVisible = nil
        local titlesFrame = nil
        local main = PlayerGui:FindFirstChild("Main")
        if main then
            titlesFrame = main:FindFirstChild("Titles")
        end

        statusLabel.Text = "Scan #" .. tostring(scanCount) .. " | Step 4/5: scanning title GUI..."
        if titlesFrame and Config.OpenTitlesForScan then
            previousVisible = titlesFrame.Visible
            pcall(function()
                titlesFrame.Visible = true
            end)
            task.wait(0.35)
        end

        local guiOk, guiMessage = inspectGuiFast(results)
        if not guiOk then
            guiMessage = "GUI unavailable: " .. tostring(guiMessage)
        end

        if titlesFrame
            and Config.OpenTitlesForScan
            and Config.RestoreTitlesVisibility
            and previousVisible ~= nil
        then
            pcall(function()
                titlesFrame.Visible = previousVisible
            end)
        end

        statusLabel.Text = "Scan #" .. tostring(scanCount) .. " | Step 5/5: finalizing..."
        for _, result in ipairs(results) do
            finalizeResult(result)
        end

        updateUi(results, remoteOk, remoteData, guiMessage)

        local serializable = buildSerializable(
            results,
            remoteOk,
            remoteData,
            remoteError,
            guiMessage
        )

        saveDebug(serializable)
        getgenv().RaceTitleCheckerLastResults = serializable
    end, scanErrorHandler)

    if not scanOk then
        local shortError = tostring(scanError):gsub("\n", " | ")
        if #shortError > 210 then
            shortError = shortError:sub(1, 210) .. "..."
        end

        statusLabel.Text = "SCAN ERROR #" .. tostring(scanCount) .. ": " .. shortError
        statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        warn("[RaceTitleChecker] Scan error:", scanError)

        pcall(function()
            if writefile then
                local fileName =
                    LocalPlayer.Name .. "-"
                    .. tostring(LocalPlayer.UserId)
                    .. "-RaceTitleChecker-error.txt"
                writefile(fileName, tostring(scanError))
            end
        end)
    else
        statusLabel.TextColor3 = Color3.fromRGB(170, 180, 205)
    end

    scanBusy = false
end

local function createGui()
    local old = CoreGui:FindFirstChild("RaceTitleMultiChecker")
    if old then
        old:Destroy()
    end

    gui = Instance.new("ScreenGui")
    gui.Name = "RaceTitleMultiChecker"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local guiParent = CoreGui
    if gethui then
        pcall(function()
            guiParent = gethui()
        end)
    end

    local parentOk = pcall(function()
        gui.Parent = guiParent
    end)
    if not parentOk or not gui.Parent then
        gui.Parent = PlayerGui
    end

    local main = Instance.new("Frame")
    main.Name = "Main"
    main.Size = UDim2.fromOffset(620, 520)
    main.Position = UDim2.new(0.5, -310, 0.5, -260)
    main.BackgroundColor3 = Color3.fromRGB(17, 18, 24)
    main.BorderSizePixel = 0
    main.Active = true
    main.Draggable = true
    main.Parent = gui

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 10)
    mainCorner.Parent = main

    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = Color3.fromRGB(100, 150, 255)
    mainStroke.Thickness = 2
    mainStroke.Parent = main

    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 42)
    header.BackgroundColor3 = Color3.fromRGB(25, 28, 38)
    header.BorderSizePixel = 0
    header.Parent = main

    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 10)
    headerCorner.Parent = header

    local headerFix = Instance.new("Frame")
    headerFix.Size = UDim2.new(1, 0, 0, 10)
    headerFix.Position = UDim2.new(0, 0, 1, -10)
    headerFix.BackgroundColor3 = header.BackgroundColor3
    headerFix.BorderSizePixel = 0
    headerFix.Parent = header

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -150, 1, 0)
    title.Position = UDim2.fromOffset(14, 0)
    title.BackgroundTransparency = 1
    title.Text = "RACE TITLE MULTI-CHECKER"
    title.TextColor3 = Color3.fromRGB(225, 235, 255)
    title.TextSize = 17
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header

    local scanButton = Instance.new("TextButton")
    scanButton.Size = UDim2.fromOffset(82, 28)
    scanButton.Position = UDim2.new(1, -126, 0, 7)
    scanButton.BackgroundColor3 = Color3.fromRGB(55, 90, 155)
    scanButton.BorderSizePixel = 0
    scanButton.Text = "SCAN NOW"
    scanButton.TextColor3 = Color3.new(1, 1, 1)
    scanButton.TextSize = 11
    scanButton.Font = Enum.Font.GothamBold
    scanButton.Parent = header
    Instance.new("UICorner", scanButton).CornerRadius = UDim.new(0, 6)

    local closeButton = Instance.new("TextButton")
    closeButton.Size = UDim2.fromOffset(28, 28)
    closeButton.Position = UDim2.new(1, -36, 0, 7)
    closeButton.BackgroundColor3 = Color3.fromRGB(145, 55, 60)
    closeButton.BorderSizePixel = 0
    closeButton.Text = "X"
    closeButton.TextColor3 = Color3.new(1, 1, 1)
    closeButton.TextSize = 13
    closeButton.Font = Enum.Font.GothamBold
    closeButton.Parent = header
    Instance.new("UICorner", closeButton).CornerRadius = UDim.new(0, 6)

    statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, -20, 0, 22)
    statusLabel.Position = UDim2.fromOffset(10, 47)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "Waiting for first scan..."
    statusLabel.TextColor3 = Color3.fromRGB(170, 180, 205)
    statusLabel.TextSize = 11
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Parent = main

    summaryLabel = Instance.new("TextLabel")
    summaryLabel.Size = UDim2.new(1, -20, 0, 20)
    summaryLabel.Position = UDim2.fromOffset(10, 69)
    summaryLabel.BackgroundTransparency = 1
    summaryLabel.Text = "Confirmed: 0 | Locked: 0 | Probable: 0 | Other: 14"
    summaryLabel.TextColor3 = Color3.fromRGB(210, 215, 225)
    summaryLabel.TextSize = 11
    summaryLabel.Font = Enum.Font.GothamSemibold
    summaryLabel.TextXAlignment = Enum.TextXAlignment.Left
    summaryLabel.Parent = main

    local column = Instance.new("Frame")
    column.Size = UDim2.new(1, -20, 0, 24)
    column.Position = UDim2.fromOffset(10, 92)
    column.BackgroundColor3 = Color3.fromRGB(30, 33, 43)
    column.BorderSizePixel = 0
    column.Parent = main
    Instance.new("UICorner", column).CornerRadius = UDim.new(0, 5)

    local columnText = Instance.new("TextLabel")
    columnText.Size = UDim2.new(1, -12, 1, 0)
    columnText.Position = UDim2.fromOffset(6, 0)
    columnText.BackgroundTransparency = 1
    columnText.Text = "NUMBER / RACE / TITLE                         STATUS              EVIDENCE"
    columnText.TextColor3 = Color3.fromRGB(150, 160, 185)
    columnText.TextSize = 10
    columnText.Font = Enum.Font.GothamBold
    columnText.TextXAlignment = Enum.TextXAlignment.Left
    columnText.Parent = column

    local scrolling = Instance.new("ScrollingFrame")
    scrolling.Size = UDim2.new(1, -20, 1, -156)
    scrolling.Position = UDim2.fromOffset(10, 120)
    scrolling.BackgroundColor3 = Color3.fromRGB(13, 14, 19)
    scrolling.BorderSizePixel = 0
    scrolling.ScrollBarThickness = 6
    scrolling.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scrolling.CanvasSize = UDim2.new()
    scrolling.Parent = main
    Instance.new("UICorner", scrolling).CornerRadius = UDim.new(0, 7)

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 4)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = scrolling

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 5)
    padding.PaddingBottom = UDim.new(0, 5)
    padding.PaddingLeft = UDim.new(0, 5)
    padding.PaddingRight = UDim.new(0, 5)
    padding.Parent = scrolling

    for order, target in ipairs(TARGETS) do
        local row = Instance.new("Frame")
        row.Name = "Title_" .. tostring(target.number)
        row.Size = UDim2.new(1, -10, 0, 48)
        row.BackgroundColor3 = Color3.fromRGB(24, 26, 34)
        row.BorderSizePixel = 0
        row.LayoutOrder = order
        row.Parent = scrolling
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(0.49, -8, 0, 22)
        nameLabel.Position = UDim2.fromOffset(8, 3)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text =
            target.numberText .. "  "
            .. target.race .. " V" .. tostring(target.version)
            .. "  |  " .. target.title
        nameLabel.TextColor3 = Color3.fromRGB(230, 230, 235)
        nameLabel.TextSize = 11
        nameLabel.Font = Enum.Font.GothamSemibold
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
        nameLabel.Parent = row

        local obtainLabel = Instance.new("TextLabel")
        obtainLabel.Size = UDim2.new(0.49, -8, 0, 18)
        obtainLabel.Position = UDim2.fromOffset(8, 25)
        obtainLabel.BackgroundTransparency = 1
        obtainLabel.Text = target.obtainment
        obtainLabel.TextColor3 = Color3.fromRGB(135, 140, 155)
        obtainLabel.TextSize = 9
        obtainLabel.Font = Enum.Font.Gotham
        obtainLabel.TextXAlignment = Enum.TextXAlignment.Left
        obtainLabel.Parent = row

        local stateLabel = Instance.new("TextLabel")
        stateLabel.Size = UDim2.new(0.19, 0, 0, 22)
        stateLabel.Position = UDim2.new(0.5, 0, 0, 3)
        stateLabel.BackgroundTransparency = 1
        stateLabel.Text = "UNKNOWN"
        stateLabel.TextColor3 = statusColor("UNKNOWN")
        stateLabel.TextSize = 10
        stateLabel.Font = Enum.Font.GothamBold
        stateLabel.TextXAlignment = Enum.TextXAlignment.Left
        stateLabel.Parent = row

        local detailLabel = Instance.new("TextLabel")
        detailLabel.Size = UDim2.new(0.31, -8, 1, -6)
        detailLabel.Position = UDim2.new(0.69, 0, 0, 3)
        detailLabel.BackgroundTransparency = 1
        detailLabel.Text = "No evidence"
        detailLabel.TextColor3 = Color3.fromRGB(150, 155, 170)
        detailLabel.TextSize = 9
        detailLabel.Font = Enum.Font.Gotham
        detailLabel.TextWrapped = true
        detailLabel.TextXAlignment = Enum.TextXAlignment.Left
        detailLabel.TextYAlignment = Enum.TextYAlignment.Center
        detailLabel.Parent = row

        rows[target.number] = {
            root = row,
            status = stateLabel,
            detail = detailLabel,
        }
    end

    timerLabel = Instance.new("TextLabel")
    timerLabel.Size = UDim2.new(1, -20, 0, 24)
    timerLabel.Position = UDim2.new(0, 10, 1, -30)
    timerLabel.BackgroundTransparency = 1
    timerLabel.Text = "Next scan: " .. tostring(Config.Interval) .. "s | RightShift: hide/show"
    timerLabel.TextColor3 = Color3.fromRGB(130, 140, 165)
    timerLabel.TextSize = 10
    timerLabel.Font = Enum.Font.Gotham
    timerLabel.TextXAlignment = Enum.TextXAlignment.Left
    timerLabel.Parent = main

    scanButton.MouseButton1Click:Connect(function()
        task.spawn(doScan)
    end)

    closeButton.MouseButton1Click:Connect(function()
        running = false
        if gui then
            gui:Destroy()
        end
    end)
end

createGui()

task.spawn(function()
    while running and not LocalPlayer.Team do
        ensureTeam()
        task.wait(1)
    end
end)

task.spawn(function()
    while running do
        doScan()

        for remaining = Config.Interval, 1, -1 do
            if not running then
                return
            end
            timerLabel.Text =
                "Next scan: " .. tostring(remaining)
                .. "s | Team: " .. tostring(Config.Team)
                .. " | RightShift: hide/show"
            task.wait(1)
        end
    end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.RightShift then
        if gui then
            gui.Enabled = not gui.Enabled
        end
    end
end)

getgenv().__RACE_TITLE_CHECKER_STOP = function()
    running = false
    pcall(function()
        if gui then
            gui:Destroy()
        end
    end)
end

print("[RaceTitleChecker] Started v2 fast-safe")
print("[RaceTitleChecker] Team:", Config.Team)
print("[RaceTitleChecker] Interval:", Config.Interval)
print("[RaceTitleChecker] Results: getgenv().RaceTitleCheckerLastResults")
print("[RaceTitleChecker] Debug folder: RaceTitleChecker/")
