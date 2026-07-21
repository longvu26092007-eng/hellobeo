--[[
    BLOX FRUITS - SERVER TIME / CHEST STATUS DEBUG LITE
    ===================================================

    GIU LAI:
      1) Server uptime that:
           Workspace._WorldOrigin.Locations.<Location>.@TimeIn
           Workspace:GetServerTimeNow() - TimeIn

      2) Cua so khong hop, lap moi 4 gio:
           03:50 -> 04:20
           07:50 -> 08:20
           11:50 -> 12:20
           ...

      3) Debug trong TOAN BO cua so tren:
           - Status/Text thay doi trong PlayerGui
           - Strange item / God's Chalice / Fist of Darkness
           - Tool vao/ra Backpack va Character
           - Player.Data / leaderstats thay doi
           - RemoteEvent co du lieu lien quan
           - Object/Attribute/Value lien quan den chest/spawn/item

      4) Nut DEEP STATUS:
           - OFF: chi ghi tin hieu lien quan
           - ON : ghi moi TEXT THAY DOI trong PlayerGui
                  (khong ghi text tinh ban dau, khong quet CoreGui,
                   khong tu ghi UI debugger)

      5) Pickup Transition Probe:
           - Giu bo nho cac thay doi truoc luc nhat.
           - Tu kich hoat khi co strange item / Chalice / Fist,
             Tool lien quan duoc them hoac chest/object lien quan bien mat.
           - Ghi ro ready/enabled/visible/active true -> false,
             prompt bi tat, UI bi an, object bi xoa va Value/Attribute doi.
           - Co nut kich hoat thu cong de bam ngay truoc khi nhat.

      6) Log tu chia Part001, Part002...; khong dung vi cham gioi han.

    DA BO:
      - Quet CoreGui
      - getgc/getconstants
      - CollectionService tags
      - Ghi tat ca UI tinh luc bat dau
      - Tu khoa qua rong: status/message/earned/active/state
      - Quet lai toan bo UI lien tuc moi 0.25 giay
      - Nhieu snapshot trung lap

    HOP:
      - Mac dinh OFF neu khong khai bao.
      - Bat: getgenv().turn = "on" hoac true
      - Tat: getgenv().turn = "off" hoac false
]]

repeat task.wait() until game:IsLoaded()

-- ============================================================
-- SERVICES
-- ============================================================
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService   = game:GetService("TeleportService")
local StarterGui        = game:GetService("StarterGui")
local GuiService        = game:GetService("GuiService")
local Workspace         = game:GetService("Workspace")
local CoreGui           = game:GetService("CoreGui")
local UserInputService  = game:GetService("UserInputService")
local HttpService       = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
repeat task.wait() until LocalPlayer

local PlaceId = game.PlaceId
local JobId = game.JobId

-- ============================================================
-- CONFIG
-- ============================================================
getgenv().ServerTimeChestDebugConfig =
    getgenv().ServerTimeChestDebugConfig or {}

local USER_CONFIG = getgenv().ServerTimeChestDebugConfig

local function parseOnOff(value, defaultValue)
    if value == nil then
        return defaultValue
    end

    if value == true or value == 1 then
        return true
    end

    if value == false or value == 0 then
        return false
    end

    local text = string.lower(tostring(value))

    if text == "on" or text == "true" or text == "1"
        or text == "yes" or text == "enable"
        or text == "enabled" then
        return true
    end

    if text == "off" or text == "false" or text == "0"
        or text == "no" or text == "disable"
        or text == "disabled" then
        return false
    end

    return defaultValue
end

local HOP_ENABLED = parseOnOff(getgenv().turn, false)

local CONFIG = {
    PeriodHours = USER_CONFIG.PeriodHours or 4,
    BeforeMinutes = USER_CONFIG.BeforeMinutes or 10,
    AfterMinutes = USER_CONFIG.AfterMinutes or 20,

    HoldCharacter = USER_CONFIG.HoldCharacter ~= false,

    -- Hop
    MaxPlayers = USER_CONFIG.MaxPlayers or 4,
    ForcedRegion = USER_CONFIG.ForcedRegion,
    MaxPages = USER_CONFIG.MaxPages or 100,
    ConcurrentWorkers = USER_CONFIG.ConcurrentWorkers or 6,
    CandidateTarget = USER_CONFIG.CandidateTarget or 18,
    BrowserTimeout = USER_CONFIG.BrowserTimeout or 8,
    RetryDelay = USER_CONFIG.RetryDelay or 1.5,
    BestServerPool = USER_CONFIG.BestServerPool or 8,

    -- TimeIn
    TimeInTimeout = USER_CONFIG.TimeInTimeout or 20,
    TimeInRetry = USER_CONFIG.TimeInRetry or 0.5,

    -- Debug
    DebugEnabled = USER_CONFIG.DebugEnabled ~= false,
    DeepDefault = USER_CONFIG.DeepDefault == true,
    FlushInterval = USER_CONFIG.FlushInterval or 1,
    PartLines = USER_CONFIG.PartLines or 2500,
    DedupSeconds = USER_CONFIG.DedupSeconds or 0.8,
    TargetScanInterval = USER_CONFIG.TargetScanInterval or 2,
    MaxTextLength = USER_CONFIG.MaxTextLength or 700,

    -- Pickup transition probe
    PickupProbeSeconds = USER_CONFIG.PickupProbeSeconds or 20,
    PickupHistorySeconds = USER_CONFIG.PickupHistorySeconds or 8,
    PickupHistoryMax = USER_CONFIG.PickupHistoryMax or 350,
    PickupPromptDistance = USER_CONFIG.PickupPromptDistance or 250,

    -- Files/UI
    GuiName = "ServerTimeChestDebugLite_UI",
    VisitedFile = "ServerTimeChestDebug_Visited.json",
    VisitedExpire = USER_CONFIG.VisitedExpire or 1800,
}

local PERIOD_SECONDS = CONFIG.PeriodHours * 3600
local BEFORE_SECONDS = CONFIG.BeforeMinutes * 60
local AFTER_SECONDS = CONFIG.AfterMinutes * 60

-- ============================================================
-- STATE
-- ============================================================
local State = {
    destroyed = false,
    startedAt = nil,
    uptime = 0,
    source = "not-found",
    sourceCount = 0,

    matched = false,
    holding = false,
    hopping = false,
    hopAttempt = 0,
    pagesScanned = 0,
    candidates = 0,

    originalMovement = nil,
}

local Debug = {
    active = false,
    deep = CONFIG.DeepDefault,
    boundary = nil,

    baseFile = nil,
    fileName = nil,
    part = 1,
    lines = {},
    dirty = false,

    events = 0,
    special = 0,
    lastSpecial = "none",

    connections = {},
    watchedGui = setmetatable({}, { __mode = "k" }),
    watchedValues = setmetatable({}, { __mode = "k" }),
    watchedRemotes = setmetatable({}, { __mode = "k" }),

    guiBaseline = setmetatable({}, { __mode = "k" }),
    valueBaseline = setmetatable({}, { __mode = "k" }),
    inventory = {},
    lastLog = {},

    pickup = {
        active = false,
        id = 0,
        untilClock = 0,
        trigger = "none",
        history = {},
        watched = setmetatable({}, { __mode = "k" }),
        propertyBaseline = setmetatable({}, { __mode = "k" }),
        attributeBaseline = setmetatable({}, { __mode = "k" }),
    },
}

getgenv().ServerTimeTargetFound = false
getgenv().ServerTimeCurrentUptime = 0
getgenv().ServerTimeCurrentJobId = JobId

-- ============================================================
-- HELPERS
-- ============================================================
local function formatDuration(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))

    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60

    if days > 0 then
        return string.format(
            "%dd %02dh %02dm %02ds",
            days,
            hours,
            minutes,
            secs
        )
    end

    return string.format("%02dh %02dm %02ds", hours, minutes, secs)
end

local function formatFileTime(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))

    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60

    return string.format("%02dh%02dm%02ds", hours, minutes, secs)
end

local function shortJobId(value)
    value = tostring(value or "")

    if #value <= 22 then
        return value
    end

    return value:sub(1, 9) .. "..." .. value:sub(-9)
end

local function safeFullName(instance)
    local ok, value = pcall(function()
        return instance:GetFullName()
    end)

    return ok and value or tostring(instance)
end

local function trimText(value)
    local text = tostring(value or "")
    text = text:gsub("[%c\r\n\t]+", " ")
    text = text:gsub("%s+", " ")
    text = text:match("^%s*(.-)%s*$") or ""

    if #text > CONFIG.MaxTextLength then
        text = text:sub(1, CONFIG.MaxTextLength) .. "...[truncated]"
    end

    return text
end

local function getServerNow()
    local ok, value = pcall(function()
        return Workspace:GetServerTimeNow()
    end)

    if ok and type(value) == "number" then
        return value
    end

    return nil
end

local function notify(title, text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = 7,
        })
    end)
end

local function serialize(value, depth, seen)
    depth = depth or 0
    seen = seen or {}

    local valueType = typeof(value)

    if valueType == "nil" then
        return "nil"
    end

    if valueType == "string" then
        return string.format("%q", trimText(value))
    end

    if valueType == "number" or valueType == "boolean" then
        return tostring(value)
    end

    if valueType == "Instance" then
        return "<" .. value.ClassName .. ":" .. safeFullName(value) .. ">"
    end

    if valueType == "table" then
        if seen[value] then
            return "<cycle>"
        end

        if depth >= 3 then
            return "<table:max-depth>"
        end

        seen[value] = true

        local output = {}
        local count = 0

        for key, item in pairs(value) do
            count = count + 1

            if count > 25 then
                table.insert(output, "...more")
                break
            end

            table.insert(
                output,
                "[" .. serialize(key, depth + 1, seen) .. "]="
                    .. serialize(item, depth + 1, seen)
            )
        end

        seen[value] = nil
        return "{" .. table.concat(output, ", ") .. "}"
    end

    return "<" .. valueType .. ":" .. tostring(value) .. ">"
end

local function addConnection(connection)
    if connection then
        table.insert(Debug.connections, connection)
    end

    return connection
end

local function disconnectDebugConnections()
    for _, connection in ipairs(Debug.connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end

    table.clear(Debug.connections)

    Debug.watchedGui = setmetatable({}, { __mode = "k" })
    Debug.watchedValues = setmetatable({}, { __mode = "k" })
    Debug.watchedRemotes = setmetatable({}, { __mode = "k" })
    Debug.pickup.watched = setmetatable({}, { __mode = "k" })
    Debug.pickup.propertyBaseline = setmetatable({}, { __mode = "k" })
    Debug.pickup.attributeBaseline = setmetatable({}, { __mode = "k" })
end

-- ============================================================
-- TARGET KEYWORDS
-- ============================================================
local TARGET_PHRASES = {
    "you have found a strange item in the chest",
    "found a strange item",
    "strange item",
    "god's chalice",
    "gods chalice",
    "god chalice",
    "sweet chalice",
    "fist of darkness",
    "dark fist",
    "the chosen one",
    "new title unlocked",
    "title color unlocked",
}

local RELEVANT_WORDS = {
    "chalice",
    "chest",
    "treasure",
    "fist of darkness",
    "dark fist",
    "strange item",
    "chosen one",
    "title unlocked",
    "title color",
    "hidden key",
    "library key",
    "water key",
    "hallow essence",
    "fire essence",
    "holy torch",
    "item spawn",
    "itemspawn",
    "pickup",
    "picked up",
    "reward",
    "loot",
}

local STATUS_PATH_WORDS = {
    "notification",
    "notifications",
    "announcement",
    "announce",
    "message",
    "messages",
    "title",
    "dialogue",
    "dialog",
    "quest",
    "reward",
    "chest",
}

local PICKUP_STATE_WORDS = {
    "ready",
    "available",
    "enabled",
    "active",
    "spawned",
    "claimed",
    "collected",
    "picked",
    "pickup",
    "opened",
    "open",
    "used",
    "cooldown",
    "next",
    "expire",
    "disabled",
    "unavailable",
    "not ready",
}

local ATTRIBUTE_WORDS = {
    "chalice",
    "chest",
    "fist",
    "darkness",
    "key",
    "item",
    "loot",
    "reward",
    "pickup",
    "spawnat",
    "spawntime",
    "nextspawn",
    "expires",
    "expiretime",
    "ready",
    "available",
    "enabled",
    "active",
    "claimed",
    "collected",
    "opened",
    "used",
    "cooldown",
}

local function containsPhrase(text, phrases)
    text = string.lower(tostring(text or ""))

    for _, phrase in ipairs(phrases) do
        if string.find(text, phrase, 1, true) then
            return true, phrase
        end
    end

    return false, nil
end

local function isSpecialText(text)
    return containsPhrase(text, TARGET_PHRASES)
end

local function isRelevantText(text)
    return containsPhrase(text, RELEVANT_WORDS)
end

local function isStatusPath(path)
    return containsPhrase(path, STATUS_PATH_WORDS)
end

local function isRelevantAttribute(name)
    return containsPhrase(name, ATTRIBUTE_WORDS)
end

local function isPickupStateName(name)
    return containsPhrase(name, PICKUP_STATE_WORDS)
end

local function valueIsRelevant(value, depth, seen)
    depth = depth or 0
    seen = seen or {}

    if depth > 3 then
        return false
    end

    local valueType = typeof(value)

    if valueType == "string" then
        return isRelevantText(value) or isSpecialText(value)
    end

    if valueType == "Instance" then
        return isRelevantText(value.Name)
            or isRelevantText(safeFullName(value))
    end

    if valueType == "table" then
        if seen[value] then
            return false
        end

        seen[value] = true

        local count = 0

        for key, item in pairs(value) do
            count = count + 1

            if count > 60 then
                break
            end

            if valueIsRelevant(key, depth + 1, seen)
                or valueIsRelevant(item, depth + 1, seen) then
                seen[value] = nil
                return true
            end
        end

        seen[value] = nil
    end

    return false
end

local function tableHasString(value, depth, seen)
    depth = depth or 0
    seen = seen or {}

    if depth > 3 then
        return false
    end

    local valueType = typeof(value)

    if valueType == "string" then
        return trimText(value) ~= ""
    end

    if valueType == "table" then
        if seen[value] then
            return false
        end

        seen[value] = true

        local count = 0

        for key, item in pairs(value) do
            count = count + 1

            if count > 60 then
                break
            end

            if tableHasString(key, depth + 1, seen)
                or tableHasString(item, depth + 1, seen) then
                seen[value] = nil
                return true
            end
        end

        seen[value] = nil
    end

    return false
end

-- ============================================================
-- WINDOW / SERVER TIME
-- ============================================================
local function evaluateWindow(uptime)
    uptime = math.max(0, tonumber(uptime) or 0)

    local completed = math.floor(uptime / PERIOD_SECONDS)
    local remainder = uptime - completed * PERIOD_SECONDS

    local before = remainder >= PERIOD_SECONDS - BEFORE_SECONDS
        and remainder < PERIOD_SECONDS

    local after = uptime >= PERIOD_SECONDS
        and remainder <= AFTER_SECONDS

    local boundary

    if after then
        boundary = completed * PERIOD_SECONDS
    else
        boundary = (completed + 1) * PERIOD_SECONDS
    end

    local startTime = boundary - BEFORE_SECONDS
    local endTime = boundary + AFTER_SECONDS

    return {
        matched = before or after,
        before = before,
        after = after,
        boundary = boundary,
        startTime = startTime,
        endTime = endTime,
        untilStart = math.max(0, startTime - uptime),
        untilEnd = math.max(0, endTime - uptime),
    }
end

local PRIORITY_LOCATIONS = {
    "Ancient Clock",
    "Castle on the Sea",
    "Temple of Time",
    "Floating Turtle",
    "Mansion",
    "Port Town",
    "Sea",
}

local function getLocations()
    local worldOrigin = Workspace:FindFirstChild("_WorldOrigin")

    if not worldOrigin then
        return nil
    end

    return worldOrigin:FindFirstChild("Locations")
end

local function validTimeIn(value)
    if type(value) ~= "number" or value < 1000000000 then
        return false
    end

    local now = getServerNow()

    if not now then
        return true
    end

    local age = now - value
    return age >= -10 and age < 31536000
end

local function detectServerStart()
    local locations = getLocations()

    if not locations then
        return nil, nil, 0
    end

    for _, name in ipairs(PRIORITY_LOCATIONS) do
        local location = locations:FindFirstChild(name)

        if location then
            local timeIn = location:GetAttribute("TimeIn")

            if validTimeIn(timeIn) then
                local rounded = math.floor(timeIn + 0.5)
                local count = 0

                for _, other in ipairs(locations:GetChildren()) do
                    local value = other:GetAttribute("TimeIn")

                    if type(value) == "number"
                        and math.floor(value + 0.5) == rounded then
                        count = count + 1
                    end
                end

                return timeIn,
                    "Workspace._WorldOrigin.Locations."
                        .. name
                        .. ".@TimeIn",
                    count
            end
        end
    end

    local groups = {}

    for _, location in ipairs(locations:GetChildren()) do
        local value = location:GetAttribute("TimeIn")

        if validTimeIn(value) then
            local rounded = math.floor(value + 0.5)

            groups[rounded] = groups[rounded] or {
                count = 0,
                total = 0,
                example = location.Name,
            }

            groups[rounded].count = groups[rounded].count + 1
            groups[rounded].total = groups[rounded].total + value
        end
    end

    local best

    for _, group in pairs(groups) do
        if not best or group.count > best.count then
            best = group
        end
    end

    if not best then
        return nil, nil, 0
    end

    return best.total / best.count,
        "Workspace._WorldOrigin.Locations."
            .. best.example
            .. ".@TimeIn",
        best.count
end

local function waitForServerStart()
    local deadline = os.clock() + CONFIG.TimeInTimeout

    repeat
        local startedAt, source, count = detectServerStart()

        if startedAt then
            return startedAt, source, count
        end

        task.wait(CONFIG.TimeInRetry)
    until os.clock() >= deadline or State.destroyed

    return nil, nil, 0
end

-- ============================================================
-- UI REFERENCES
-- ============================================================
local UI = {}

local function updateDebugInfo(text, color)
    if UI.DebugStatus then
        UI.DebugStatus.Text = text or "Debug idle"

        if color then
            UI.DebugStatus.TextColor3 = color
        end
    end

    if UI.DebugInfo then
        local file = Debug.fileName or "chưa tạo"

        if #file > 62 then
            file = "..." .. file:sub(-59)
        end

        UI.DebugInfo.Text = string.format(
            "Events: %d | Special: %d | Deep: %s | Part: %03d\n%s",
            Debug.events,
            Debug.special,
            Debug.deep and "ON" or "OFF",
            Debug.part,
            file
        )
    end
end

-- ============================================================
-- ROTATING LOG
-- ============================================================
local flushLog

local function partFileName(baseFile, part)
    local stem = tostring(baseFile or "ServerChestDebug")
        :gsub("%.txt$", "")

    return string.format("%s_Part%03d.txt", stem, part)
end

local function writeCurrentPart()
    if not Debug.fileName or type(writefile) ~= "function" then
        return false
    end

    local content = table.concat(Debug.lines, "\n") .. "\n"

    local ok, err = pcall(function()
        writefile(Debug.fileName, content)
    end)

    if not ok then
        warn("[CHEST DEBUG] writefile failed:", err)
        updateDebugInfo(
            "LỖI GHI FILE",
            Color3.fromRGB(238, 104, 104)
        )
        return false
    end

    Debug.dirty = false
    return true
end

flushLog = function(force)
    if not Debug.active and not force then
        return
    end

    if not Debug.dirty and not force then
        return
    end

    writeCurrentPart()
end

local function rotatePart()
    flushLog(true)

    local previous = Debug.fileName

    Debug.part = Debug.part + 1
    Debug.fileName = partFileName(Debug.baseFile, Debug.part)
    Debug.lines = {
        "BLOX FRUITS CHEST STATUS DEBUG - CONTINUATION",
        "Generated: " .. os.date("%Y-%m-%d %H:%M:%S"),
        "PlaceId: " .. tostring(PlaceId),
        "JobId: " .. tostring(JobId),
        "ServerUptime: " .. formatDuration(State.uptime),
        "Part: " .. tostring(Debug.part),
        "PreviousPart: " .. tostring(previous),
        string.rep("=", 88),
    }
    Debug.dirty = true

    updateDebugInfo(
        "ĐANG GHI — CHUYỂN PART " .. tostring(Debug.part),
        Color3.fromRGB(107, 221, 159)
    )
end

local function logEvent(category, message, dedupKey, immediate)
    if not Debug.active then
        return
    end

    if #Debug.lines >= CONFIG.PartLines then
        rotatePart()
    end

    local now = os.clock()
    local key = tostring(dedupKey or (category .. "|" .. message))
    local last = Debug.lastLog[key]

    if last and now - last < CONFIG.DedupSeconds then
        return
    end

    Debug.lastLog[key] = now
    Debug.events = Debug.events + 1

    local line = string.format(
        "[%s][UPTIME %s][%s] %s",
        os.date("%H:%M:%S"),
        formatDuration(State.uptime),
        tostring(category),
        tostring(message)
    )

    table.insert(Debug.lines, line)
    Debug.dirty = true

    if immediate then
        flushLog(true)
    end

    updateDebugInfo(
        "ĐANG GHI DỮ LIỆU",
        Color3.fromRGB(107, 221, 159)
    )
end

-- ============================================================
-- PICKUP TRANSITION PROBE
-- Luu thay doi gan nhat trong RAM. Khi phat hien nhat vat pham,
-- ghi lai ca thay doi truoc va sau su kien.
-- Category co the xuat hien:
--   PICKUP_DISABLED / PICKUP_HIDDEN / PICKUP_INACTIVE
--   PICKUP_REMOVED / PICKUP_BECAME_FALSE / PICKUP_NOT_READY
-- ============================================================
local triggerPickupProbe

local function pickupValue(value)
    if value == nil then
        return "nil"
    end

    return serialize(value)
end

local function classifyPickupChange(propertyName, oldValue, newValue)
    local property = string.lower(tostring(propertyName or ""))
    local oldText = string.lower(tostring(oldValue or ""))
    local newText = string.lower(tostring(newValue or ""))

    if property == "enabled"
        and oldText == "true"
        and newText == "false" then
        return "DISABLED"
    end

    if property == "visible"
        and oldText == "true"
        and newText == "false" then
        return "HIDDEN"
    end

    if property == "active"
        and oldText == "true"
        and newText == "false" then
        return "INACTIVE"
    end

    if property == "parent"
        and oldText ~= "nil"
        and newText == "nil" then
        return "REMOVED"
    end

    if (property:find("ready", 1, true)
            or property:find("available", 1, true)
            or property:find("active", 1, true)
            or property:find("enabled", 1, true))
        and oldText == "true"
        and newText == "false" then
        return "BECAME_FALSE"
    end

    if newText:find("not ready", 1, true)
        or newText:find("unavailable", 1, true)
        or newText:find("cooldown", 1, true)
        or newText:find("disabled", 1, true) then
        return "NOT_READY"
    end

    return "CHANGED"
end

local function prunePickupHistory()
    local now = os.clock()
    local history = Debug.pickup.history
    local firstValid = 1

    while firstValid <= #history do
        if now - history[firstValid].clock
            <= CONFIG.PickupHistorySeconds then
            break
        end
        firstValid = firstValid + 1
    end

    if firstValid > 1 then
        local compact = {}

        for index = firstValid, #history do
            table.insert(compact, history[index])
        end

        Debug.pickup.history = compact
        history = compact
    end

    while #history > CONFIG.PickupHistoryMax do
        table.remove(history, 1)
    end
end

local function recordPickupTransition(
    instance,
    propertyName,
    oldValue,
    newValue,
    source
)
    if not Debug.active then
        return
    end

    local oldSerialized = pickupValue(oldValue)
    local newSerialized = pickupValue(newValue)

    if oldSerialized == newSerialized then
        return
    end

    local path = safeFullName(instance)
    local changeType = classifyPickupChange(
        propertyName,
        oldSerialized,
        newSerialized
    )

    local entry = {
        clock = os.clock(),
        uptime = State.uptime,
        changeType = changeType,
        path = path,
        className = instance.ClassName,
        property = tostring(propertyName),
        oldValue = oldSerialized,
        newValue = newSerialized,
        source = tostring(source or "watcher"),
    }

    table.insert(Debug.pickup.history, entry)
    prunePickupHistory()

    if Debug.pickup.active then
        local immediate = changeType == "DISABLED"
            or changeType == "HIDDEN"
            or changeType == "INACTIVE"
            or changeType == "REMOVED"
            or changeType == "BECAME_FALSE"
            or changeType == "NOT_READY"

        logEvent(
            "PICKUP_" .. changeType,
            string.format(
                "Probe#%d | %s (%s) | %s: %s -> %s | source=%s",
                Debug.pickup.id,
                path,
                instance.ClassName,
                tostring(propertyName),
                oldSerialized,
                newSerialized,
                tostring(source)
            ),
            "pickup|" .. tostring(Debug.pickup.id)
                .. "|" .. path
                .. "|" .. tostring(propertyName)
                .. "|" .. newSerialized,
            immediate
        )
    end
end

local function flushPickupPreHistory(triggerReason)
    prunePickupHistory()

    local history = Debug.pickup.history

    logEvent(
        "PICKUP_PREHISTORY",
        string.format(
            "Probe#%d | trigger=%s | bufferedChanges=%d | history=%ss",
            Debug.pickup.id,
            tostring(triggerReason),
            #history,
            tostring(CONFIG.PickupHistorySeconds)
        ),
        nil,
        true
    )

    for index, entry in ipairs(history) do
        local age = math.max(0, os.clock() - entry.clock)

        logEvent(
            "PICKUP_BEFORE_" .. entry.changeType,
            string.format(
                "Probe#%d | %.2fs before trigger | uptime=%s | %s (%s) | %s: %s -> %s | source=%s",
                Debug.pickup.id,
                age,
                formatDuration(entry.uptime),
                entry.path,
                entry.className,
                entry.property,
                entry.oldValue,
                entry.newValue,
                entry.source
            ),
            "pickup-pre|" .. tostring(Debug.pickup.id)
                .. "|" .. tostring(index)
                .. "|" .. entry.path
                .. "|" .. entry.property
        )
    end
end

triggerPickupProbe = function(reason, details)
    if not Debug.active then
        return
    end

    local now = os.clock()

    if Debug.pickup.active then
        Debug.pickup.untilClock = math.max(
            Debug.pickup.untilClock,
            now + CONFIG.PickupProbeSeconds
        )

        logEvent(
            "PICKUP_PROBE_EXTENDED",
            string.format(
                "Probe#%d | reason=%s | details=%s | +%ss",
                Debug.pickup.id,
                tostring(reason),
                tostring(details or ""),
                tostring(CONFIG.PickupProbeSeconds)
            ),
            nil,
            true
        )

        return
    end

    Debug.pickup.id = Debug.pickup.id + 1
    Debug.pickup.active = true
    Debug.pickup.untilClock = now + CONFIG.PickupProbeSeconds
    Debug.pickup.trigger = tostring(reason or "unknown")

    flushPickupPreHistory(reason)

    logEvent(
        "PICKUP_PROBE_START",
        string.format(
            "Probe#%d | trigger=%s | details=%s | watchAfter=%ss",
            Debug.pickup.id,
            tostring(reason),
            tostring(details or ""),
            tostring(CONFIG.PickupProbeSeconds)
        ),
        nil,
        true
    )

    updateDebugInfo(
        "PICKUP PROBE ACTIVE — "
            .. tostring(CONFIG.PickupProbeSeconds)
            .. " GIÂY",
        Color3.fromRGB(255, 186, 73)
    )
end

local function watchPickupAttribute(instance, attributeName)
    local baselineTable = Debug.pickup.attributeBaseline[instance]

    if not baselineTable then
        baselineTable = {}
        Debug.pickup.attributeBaseline[instance] = baselineTable
    end

    baselineTable[attributeName] = instance:GetAttribute(attributeName)

    addConnection(
        instance:GetAttributeChangedSignal(attributeName):Connect(function()
            if not Debug.active then
                return
            end

            local oldValue = baselineTable[attributeName]
            local newValue = instance:GetAttribute(attributeName)
            baselineTable[attributeName] = newValue

            recordPickupTransition(
                instance,
                "Attribute@" .. tostring(attributeName),
                oldValue,
                newValue,
                "AttributeChanged"
            )
        end)
    )
end

local function watchPickupProperty(instance, propertyName)
    local baselineTable = Debug.pickup.propertyBaseline[instance]

    if not baselineTable then
        baselineTable = {}
        Debug.pickup.propertyBaseline[instance] = baselineTable
    end

    local ok, initial = pcall(function()
        return instance[propertyName]
    end)

    if not ok then
        return
    end

    baselineTable[propertyName] = initial

    addConnection(
        instance:GetPropertyChangedSignal(propertyName):Connect(function()
            if not Debug.active then
                return
            end

            local success, newValue = pcall(function()
                return instance[propertyName]
            end)

            if not success then
                return
            end

            local oldValue = baselineTable[propertyName]
            baselineTable[propertyName] = newValue

            recordPickupTransition(
                instance,
                propertyName,
                oldValue,
                newValue,
                "PropertyChanged"
            )
        end)
    )
end

local function instanceNearPlayer(instance)
    local character = LocalPlayer.Character
    local root = character
        and character:FindFirstChild("HumanoidRootPart")

    if not root then
        return false
    end

    local parent = instance.Parent
    local position

    while parent and parent ~= Workspace do
        if parent:IsA("BasePart") then
            position = parent.Position
            break
        end

        if parent:IsA("Model") and parent.PrimaryPart then
            position = parent.PrimaryPart.Position
            break
        end

        parent = parent.Parent
    end

    if not position then
        return false
    end

    return (root.Position - position).Magnitude
        <= CONFIG.PickupPromptDistance
end

local function watchPickupInstance(instance)
    if not Debug.active
        or Debug.pickup.watched[instance] then
        return
    end

    local path = safeFullName(instance)

    -- Khong theo doi chinh UI debugger. Dung truc tiep CONFIG.GuiName
    -- vi ham nay duoc khai bao truoc shouldIgnoreGui().
    if string.find(path, CONFIG.GuiName, 1, true) then
        return
    end

    local relevantPath = isRelevantText(path)
        or isSpecialText(path)
        or isStatusPath(path)

    local relevantValue = instance:IsA("ValueBase")
        and (
            relevantPath
            or isPickupStateName(instance.Name)
        )

    local shouldWatch = relevantPath
        or instance:IsA("ProximityPrompt")
        or relevantValue

    if instance:IsA("ProximityPrompt")
        and not relevantPath
        and not instanceNearPlayer(instance) then
        shouldWatch = false
    end

    if not shouldWatch then
        return
    end

    Debug.pickup.watched[instance] = true

    if instance:IsA("ProximityPrompt") then
        watchPickupProperty(instance, "Enabled")
        watchPickupProperty(instance, "ActionText")
        watchPickupProperty(instance, "ObjectText")
        watchPickupProperty(instance, "HoldDuration")
    end

    if instance:IsA("GuiObject")
        and (relevantPath or Debug.deep) then
        watchPickupProperty(instance, "Visible")
        watchPickupProperty(instance, "Active")
    end

    if instance:IsA("BasePart") and relevantPath then
        watchPickupProperty(instance, "Transparency")
        watchPickupProperty(instance, "CanTouch")
        watchPickupProperty(instance, "CanQuery")
    end

    if instance:IsA("ValueBase")
        and (relevantPath or isPickupStateName(instance.Name)) then
        local baselineTable = Debug.pickup.propertyBaseline[instance]

        if not baselineTable then
            baselineTable = {}
            Debug.pickup.propertyBaseline[instance] = baselineTable
        end

        baselineTable.Value = instance.Value

        addConnection(instance.Changed:Connect(function()
            if not Debug.active then
                return
            end

            local oldValue = baselineTable.Value
            local newValue = instance.Value
            baselineTable.Value = newValue

            recordPickupTransition(
                instance,
                "Value",
                oldValue,
                newValue,
                "ValueBase.Changed"
            )
        end))
    end

    local ok, attributes = pcall(function()
        return instance:GetAttributes()
    end)

    if ok and type(attributes) == "table" then
        for attributeName in pairs(attributes) do
            if relevantPath
                or isRelevantAttribute(attributeName)
                or isPickupStateName(attributeName) then
                watchPickupAttribute(instance, attributeName)
            end
        end
    end

    local previousParent = instance.Parent

    addConnection(instance.AncestryChanged:Connect(function()
        if not Debug.active then
            return
        end

        local newParent = instance.Parent

        if previousParent ~= newParent then
            recordPickupTransition(
                instance,
                "Parent",
                previousParent and safeFullName(previousParent) or nil,
                newParent and safeFullName(newParent) or nil,
                "AncestryChanged"
            )

            if newParent == nil and relevantPath then
                triggerPickupProbe(
                    "Relevant object removed",
                    path
                )
            end

            previousParent = newParent
        end
    end))
end

local function attachPickupTransitionWatchers()
    local roots = {
        LocalPlayer:FindFirstChildOfClass("PlayerGui"),
        LocalPlayer:FindFirstChild("Data"),
        LocalPlayer:FindFirstChild("leaderstats"),
        LocalPlayer:FindFirstChild("Backpack"),
        LocalPlayer.Character,
        Workspace,
        ReplicatedStorage,
    }

    for _, root in ipairs(roots) do
        if root then
            for index, instance in ipairs(root:GetDescendants()) do
                watchPickupInstance(instance)

                if index % 1000 == 0 then
                    task.wait()
                end
            end

            addConnection(root.DescendantAdded:Connect(function(instance)
                task.defer(watchPickupInstance, instance)
            end))
        end
    end

    logEvent(
        "PICKUP_WATCHERS_READY",
        "Transition watchers attached | history="
            .. tostring(CONFIG.PickupHistorySeconds)
            .. "s | after="
            .. tostring(CONFIG.PickupProbeSeconds)
            .. "s | nearbyPromptDistance="
            .. tostring(CONFIG.PickupPromptDistance),
        nil,
        true
    )
end

-- ============================================================
-- GUI STATUS WATCH
-- ============================================================
local function isTextGui(instance)
    return instance:IsA("TextLabel")
        or instance:IsA("TextButton")
        or instance:IsA("TextBox")
end

local function shouldIgnoreGui(instance)
    return string.find(
        safeFullName(instance),
        CONFIG.GuiName,
        1,
        true
    ) ~= nil
end

local function processGuiText(instance, reason)
    if not Debug.active
        or not isTextGui(instance)
        or shouldIgnoreGui(instance) then
        return
    end

    local ok, rawText = pcall(function()
        return instance.Text
    end)

    if not ok then
        return
    end

    local text = trimText(rawText)
    local previous = Debug.guiBaseline[instance]
    Debug.guiBaseline[instance] = text

    if reason ~= "baseline" and text ~= previous then
        recordPickupTransition(
            instance,
            "Text",
            previous,
            text,
            "PlayerGui." .. tostring(reason)
        )
    end

    -- Khi moi gan watcher, chi tao baseline; khong spam text tinh.
    if reason == "baseline" then
        return
    end

    if text == "" or text == previous then
        return
    end

    local path = safeFullName(instance)
    local special = isSpecialText(text)
    local relevant = special
        or isRelevantText(text)
        or isStatusPath(path)

    -- Deep ON: ghi moi Text THAY DOI trong PlayerGui.
    if Debug.deep then
        relevant = true
    end

    if not relevant then
        return
    end

    local category = special
        and "SPECIAL_CHEST_STATUS"
        or "UI_TEXT_CHANGED"

    if special then
        Debug.special = Debug.special + 1
        Debug.lastSpecial = text
    end

    logEvent(
        category,
        string.format(
            "%s | old=%q | new=%q | visible=%s | reason=%s",
            path,
            tostring(previous or ""),
            text,
            tostring(instance.Visible),
            tostring(reason)
        ),
        "gui|" .. path .. "|" .. text,
        special
    )

    if special then
        triggerPickupProbe(
            "Special chest/status text",
            text
        )
    elseif Debug.pickup.active then
        local lowered = string.lower(text)

        if lowered:find("not ready", 1, true)
            or lowered:find("unavailable", 1, true)
            or lowered:find("cooldown", 1, true)
            or lowered:find("disabled", 1, true) then
            logEvent(
                "PICKUP_NOT_READY_TEXT",
                path .. " | text=" .. string.format("%q", text),
                "pickup-not-ready|" .. path .. "|" .. text,
                true
            )
        end
    end
end

local function watchGui(instance)
    if not Debug.active
        or not isTextGui(instance)
        or shouldIgnoreGui(instance)
        or Debug.watchedGui[instance] then
        return
    end

    Debug.watchedGui[instance] = true
    processGuiText(instance, "baseline")

    addConnection(
        instance:GetPropertyChangedSignal("Text"):Connect(function()
            processGuiText(instance, "TextChanged")
        end)
    )

    local previousVisible = instance.Visible

    addConnection(
        instance:GetPropertyChangedSignal("Visible"):Connect(function()
            local newVisible = instance.Visible

            recordPickupTransition(
                instance,
                "Visible",
                previousVisible,
                newVisible,
                "PlayerGui.Visible"
            )

            previousVisible = newVisible

            if newVisible then
                processGuiText(instance, "Visible=true")
            end
        end)
    )
end

local function attachPlayerGuiWatchers()
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")

    if not playerGui then
        return
    end

    for index, instance in ipairs(playerGui:GetDescendants()) do
        if isTextGui(instance) then
            watchGui(instance)
        end

        if index % 600 == 0 then
            task.wait()
        end
    end

    addConnection(playerGui.DescendantAdded:Connect(function(instance)
        if isTextGui(instance) then
            task.defer(watchGui, instance)
        end
    end))
end

-- ============================================================
-- VALUE / PLAYER DATA WATCH
-- ============================================================
local function watchValueBase(instance, category)
    if not Debug.active
        or not instance:IsA("ValueBase")
        or Debug.watchedValues[instance] then
        return
    end

    Debug.watchedValues[instance] = true
    Debug.valueBaseline[instance] = serialize(instance.Value)

    addConnection(instance.Changed:Connect(function()
        if not Debug.active then
            return
        end

        local newValue = serialize(instance.Value)
        local oldValue = Debug.valueBaseline[instance]

        if newValue == oldValue then
            return
        end

        Debug.valueBaseline[instance] = newValue

        recordPickupTransition(
            instance,
            "Value",
            oldValue,
            newValue,
            tostring(category or "VALUE_CHANGED")
        )

        logEvent(
            category or "VALUE_CHANGED",
            string.format(
                "%s | old=%s | new=%s",
                safeFullName(instance),
                tostring(oldValue),
                tostring(newValue)
            ),
            "value|" .. safeFullName(instance) .. "|" .. newValue
        )
    end))
end

local function attachPlayerDataWatchers()
    local roots = {
        LocalPlayer:FindFirstChild("Data"),
        LocalPlayer:FindFirstChild("leaderstats"),
    }

    for _, root in ipairs(roots) do
        if root then
            for _, instance in ipairs(root:GetDescendants()) do
                if instance:IsA("ValueBase") then
                    watchValueBase(instance, "PLAYER_DATA_CHANGED")
                end
            end

            addConnection(root.DescendantAdded:Connect(function(instance)
                if instance:IsA("ValueBase") then
                    task.defer(
                        watchValueBase,
                        instance,
                        "PLAYER_DATA_CHANGED"
                    )
                end
            end))
        end
    end
end

-- ============================================================
-- INVENTORY WATCH
-- ============================================================
local function inventorySnapshot(reason)
    if not Debug.active then
        return
    end

    local current = {}
    local roots = {
        LocalPlayer:FindFirstChild("Backpack"),
        LocalPlayer.Character,
    }

    for _, root in ipairs(roots) do
        if root then
            for _, item in ipairs(root:GetChildren()) do
                if item:IsA("Tool") then
                    current[item] = safeFullName(item)
                end
            end
        end
    end

    for item, path in pairs(current) do
        if not Debug.inventory[item] then
            local relevant = isRelevantText(item.Name)
                or isSpecialText(item.Name)
                or Debug.deep

            if relevant then
                logEvent(
                    "TOOL_ADDED",
                    path .. " | reason=" .. tostring(reason),
                    "tool-add|" .. tostring(item),
                    true
                )

                recordPickupTransition(
                    item,
                    "Inventory",
                    "absent",
                    path,
                    tostring(reason)
                )

                triggerPickupProbe(
                    "Relevant Tool added",
                    item.Name .. " | " .. path
                )
            end
        end
    end

    for item, oldPath in pairs(Debug.inventory) do
        if not current[item] then
            local relevant = isRelevantText(item.Name)
                or isSpecialText(item.Name)
                or Debug.deep

            if relevant then
                logEvent(
                    "TOOL_REMOVED",
                    oldPath .. " | reason=" .. tostring(reason),
                    "tool-remove|" .. tostring(item),
                    true
                )

                recordPickupTransition(
                    item,
                    "Inventory",
                    oldPath,
                    "absent",
                    tostring(reason)
                )
            end
        end
    end

    Debug.inventory = current
end

local function attachInventoryWatchers()
    local backpack = LocalPlayer:WaitForChild("Backpack", 10)

    if backpack then
        addConnection(backpack.ChildAdded:Connect(function()
            task.defer(inventorySnapshot, "Backpack.ChildAdded")
        end))

        addConnection(backpack.ChildRemoved:Connect(function()
            task.defer(inventorySnapshot, "Backpack.ChildRemoved")
        end))
    end

    local function attachCharacter(character)
        if not character then
            return
        end

        addConnection(character.ChildAdded:Connect(function()
            task.defer(inventorySnapshot, "Character.ChildAdded")
        end))

        addConnection(character.ChildRemoved:Connect(function()
            task.defer(inventorySnapshot, "Character.ChildRemoved")
        end))

        task.defer(inventorySnapshot, "Character attached")
    end

    attachCharacter(LocalPlayer.Character)

    addConnection(LocalPlayer.CharacterAdded:Connect(function(character)
        task.wait(0.5)
        attachCharacter(character)
    end))

    inventorySnapshot("baseline")
end

-- ============================================================
-- REMOTE EVENT WATCH
-- ============================================================
local function argsRelevant(remote, packed)
    if isRelevantText(remote.Name)
        or isRelevantText(safeFullName(remote)) then
        return true
    end

    for index = 1, packed.n or #packed do
        if valueIsRelevant(packed[index]) then
            return true
        end
    end

    return false
end

local function formatArgs(packed)
    local output = {}
    local count = packed.n or #packed

    for index = 1, math.min(count, 15) do
        table.insert(
            output,
            "[" .. index .. "]=" .. serialize(packed[index])
        )
    end

    if count > 15 then
        table.insert(output, "...more")
    end

    return table.concat(output, ", ")
end

local function watchRemote(remote)
    if not Debug.active
        or not remote:IsA("RemoteEvent")
        or Debug.watchedRemotes[remote] then
        return
    end

    Debug.watchedRemotes[remote] = true

    addConnection(remote.OnClientEvent:Connect(function(...)
        if not Debug.active then
            return
        end

        local packed = table.pack(...)

        if argsRelevant(remote, packed)
            or (Debug.deep and tableHasString(packed)) then
            local details = formatArgs(packed)

            logEvent(
                "REMOTE_IN",
                safeFullName(remote) .. " | " .. details,
                "remote-in|" .. safeFullName(remote) .. "|" .. details
            )
        end
    end))
end

local function attachRemoteWatchers()
    for index, instance in ipairs(ReplicatedStorage:GetDescendants()) do
        if instance:IsA("RemoteEvent") then
            watchRemote(instance)
        end

        if index % 800 == 0 then
            task.wait()
        end
    end

    addConnection(ReplicatedStorage.DescendantAdded:Connect(function(instance)
        if instance:IsA("RemoteEvent") then
            task.defer(watchRemote, instance)
        end
    end))
end

-- ============================================================
-- TARGETED OBJECT / ATTRIBUTE SCAN
-- ============================================================
local function inspectTargetObject(instance, reason)
    if not Debug.active then
        return
    end

    local path = safeFullName(instance)
    local objectRelevant = isRelevantText(path)
        or isSpecialText(path)

    local ok, attributes = pcall(function()
        return instance:GetAttributes()
    end)

    if ok and type(attributes) == "table" then
        for attributeName, value in pairs(attributes) do
            if objectRelevant
                or isRelevantAttribute(attributeName)
                or valueIsRelevant(value) then
                logEvent(
                    "ATTRIBUTE",
                    string.format(
                        "%s | @%s=%s | reason=%s",
                        path,
                        tostring(attributeName),
                        serialize(value),
                        tostring(reason)
                    ),
                    "attr|" .. path .. "|" .. tostring(attributeName)
                        .. "|" .. serialize(value)
                )
            end
        end
    end

    if instance:IsA("ValueBase") then
        local valueRelevant = objectRelevant
            or valueIsRelevant(instance.Value)

        if valueRelevant then
            logEvent(
                "TARGET_VALUE",
                string.format(
                    "%s | value=%s | reason=%s",
                    path,
                    serialize(instance.Value),
                    tostring(reason)
                ),
                "target-value|" .. path .. "|" .. serialize(instance.Value)
            )

            watchValueBase(instance, "TARGET_VALUE_CHANGED")
        end
    end
end

local function scanTargetRoots(reason)
    local roots = {
        Workspace,
        ReplicatedStorage,
    }

    for _, root in ipairs(roots) do
        for index, instance in ipairs(root:GetDescendants()) do
            local path = safeFullName(instance)

            if isRelevantText(path)
                or isSpecialText(path) then
                inspectTargetObject(instance, reason)
            else
                local ok, attributes = pcall(function()
                    return instance:GetAttributes()
                end)

                if ok and type(attributes) == "table" then
                    for attributeName, value in pairs(attributes) do
                        if isRelevantAttribute(attributeName)
                            or valueIsRelevant(value) then
                            inspectTargetObject(instance, reason)
                            break
                        end
                    end
                end
            end

            if index % 1000 == 0 then
                task.wait()
            end
        end
    end
end

local function attachTargetRootSignals()
    local function onAdded(instance)
        if isRelevantText(safeFullName(instance))
            or isSpecialText(safeFullName(instance)) then
            logEvent(
                "OBJECT_ADDED",
                instance.ClassName
                    .. " | "
                    .. safeFullName(instance),
                "object-added|" .. tostring(instance),
                true
            )

            task.defer(
                inspectTargetObject,
                instance,
                "DescendantAdded"
            )
        end
    end

    local function onRemoving(instance)
        if isRelevantText(safeFullName(instance))
            or isSpecialText(safeFullName(instance)) then
            local removedPath = safeFullName(instance)

            logEvent(
                "OBJECT_REMOVING",
                instance.ClassName
                    .. " | "
                    .. removedPath,
                "object-remove|" .. tostring(instance),
                true
            )

            recordPickupTransition(
                instance,
                "Parent",
                instance.Parent and safeFullName(instance.Parent) or nil,
                nil,
                "DescendantRemoving"
            )

            triggerPickupProbe(
                "Relevant object removing",
                removedPath
            )
        end
    end

    addConnection(Workspace.DescendantAdded:Connect(onAdded))
    addConnection(Workspace.DescendantRemoving:Connect(onRemoving))
    addConnection(ReplicatedStorage.DescendantAdded:Connect(onAdded))
    addConnection(ReplicatedStorage.DescendantRemoving:Connect(onRemoving))
end

-- ============================================================
-- OUTGOING REMOTE HOOK — OPTIONAL, FILTERED
-- ============================================================
local outgoingHookInstalled = false

local function installOutgoingHook()
    if outgoingHookInstalled
        or type(hookmetamethod) ~= "function"
        or type(getnamecallmethod) ~= "function"
        or type(newcclosure) ~= "function" then
        return
    end

    local oldNamecall

    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()

        if Debug.active
            and typeof(self) == "Instance"
            and (method == "FireServer" or method == "InvokeServer") then
            local packed = table.pack(...)

            if argsRelevant(self, packed)
                or (Debug.deep and tableHasString(packed)) then
                local details = formatArgs(packed)

                logEvent(
                    "REMOTE_OUT",
                    method
                        .. " "
                        .. safeFullName(self)
                        .. " | "
                        .. details,
                    "remote-out|" .. safeFullName(self)
                        .. "|" .. details
                )
            end
        end

        return oldNamecall(self, ...)
    end))

    outgoingHookInstalled = true
end

-- ============================================================
-- DEBUG START / STOP / DEEP MODE
-- ============================================================
local function buildBaseFile(boundary)
    local startTime = boundary - BEFORE_SECONDS
    local endTime = boundary + AFTER_SECONDS

    return string.format(
        "ChestStatusDebug_%s_Window-%s_to_%s_Start-%s_%s.txt",
        tostring(JobId):gsub("[^%w%-]", "_"),
        formatFileTime(startTime),
        formatFileTime(endTime),
        formatFileTime(State.uptime),
        os.date("%Y%m%d_%H%M%S")
    )
end

local function startDebug(boundary)
    if Debug.active or not CONFIG.DebugEnabled then
        return
    end

    Debug.active = true
    Debug.boundary = boundary
    Debug.baseFile = buildBaseFile(boundary)
    Debug.part = 1
    Debug.fileName = partFileName(Debug.baseFile, Debug.part)
    Debug.lines = {
        "BLOX FRUITS CHEST STATUS DEBUG LITE",
        "Generated: " .. os.date("%Y-%m-%d %H:%M:%S"),
        "PlaceId: " .. tostring(PlaceId),
        "JobId: " .. tostring(JobId),
        "ServerUptimeAtStart: " .. formatDuration(State.uptime),
        "ServerStartSource: " .. tostring(State.source),
        "MatchingLocations: " .. tostring(State.sourceCount),
        "Window: "
            .. formatDuration(boundary - BEFORE_SECONDS)
            .. " -> "
            .. formatDuration(boundary + AFTER_SECONDS),
        "AutoHop: " .. tostring(HOP_ENABLED),
        "DeepAtStart: " .. tostring(Debug.deep),
        "PartLines: " .. tostring(CONFIG.PartLines),
        "PickupHistorySeconds: "
            .. tostring(CONFIG.PickupHistorySeconds),
        "PickupProbeSeconds: "
            .. tostring(CONFIG.PickupProbeSeconds),
        "PickupPromptDistance: "
            .. tostring(CONFIG.PickupPromptDistance),
        string.rep("=", 88),
    }
    Debug.dirty = true
    Debug.events = 0
    Debug.special = 0
    Debug.lastSpecial = "none"
    Debug.lastLog = {}
    Debug.guiBaseline = setmetatable({}, { __mode = "k" })
    Debug.valueBaseline = setmetatable({}, { __mode = "k" })
    Debug.inventory = {}
    Debug.pickup.active = false
    Debug.pickup.untilClock = 0
    Debug.pickup.trigger = "none"
    Debug.pickup.history = {}
    Debug.pickup.watched = setmetatable({}, { __mode = "k" })
    Debug.pickup.propertyBaseline = setmetatable({}, { __mode = "k" })
    Debug.pickup.attributeBaseline = setmetatable({}, { __mode = "k" })

    attachPlayerGuiWatchers()
    attachPlayerDataWatchers()
    attachInventoryWatchers()
    attachRemoteWatchers()
    attachTargetRootSignals()
    installOutgoingHook()
    task.spawn(attachPickupTransitionWatchers)

    task.spawn(scanTargetRoots, "debug-start")

    logEvent(
        "DEBUG_START",
        "Deep=" .. tostring(Debug.deep)
            .. " | File=" .. tostring(Debug.fileName),
        nil,
        true
    )

    updateDebugInfo(
        "DEBUG ĐÃ BẮT ĐẦU",
        Color3.fromRGB(107, 221, 159)
    )
end

local function stopDebug(reason)
    if not Debug.active then
        return
    end

    logEvent(
        "DEBUG_STOP",
        "Reason=" .. tostring(reason)
            .. " | Events=" .. tostring(Debug.events)
            .. " | Special=" .. tostring(Debug.special)
            .. " | Parts=" .. tostring(Debug.part),
        nil,
        true
    )

    flushLog(true)
    disconnectDebugConnections()

    Debug.pickup.active = false
    Debug.pickup.untilClock = 0
    Debug.active = false

    updateDebugInfo(
        "DEBUG ĐÃ DỪNG — " .. tostring(reason),
        Color3.fromRGB(143, 158, 178)
    )
end

local function setDeepMode(enabled)
    Debug.deep = enabled == true

    if UI.DeepButton then
        UI.DeepButton.Text = Debug.deep
            and "DEEP STATUS SCAN: ON"
            or "DEEP STATUS SCAN: OFF"

        UI.DeepButton.BackgroundColor3 = Debug.deep
            and Color3.fromRGB(42, 126, 83)
            or Color3.fromRGB(91, 63, 126)
    end

    if Debug.active then
        -- Tao baseline moi; chi ghi cac thay doi ke tu luc bat.
        local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")

        if playerGui then
            for _, instance in ipairs(playerGui:GetDescendants()) do
                if isTextGui(instance)
                    and not shouldIgnoreGui(instance) then
                    Debug.guiBaseline[instance] = trimText(instance.Text)
                    watchGui(instance)
                    watchPickupInstance(instance)
                end
            end
        end

        inventorySnapshot("deep-toggle")
        logEvent(
            "DEEP_TOGGLE",
            "Deep=" .. tostring(Debug.deep),
            nil,
            true
        )
    end

    updateDebugInfo(
        Debug.deep
            and "DEEP ON — GHI MỌI TEXT THAY ĐỔI"
            or "DEEP OFF — CHỈ GHI TÍN HIỆU LIÊN QUAN",
        Debug.deep
            and Color3.fromRGB(107, 221, 159)
            or Color3.fromRGB(143, 158, 178)
    )
end

-- ============================================================
-- CHARACTER HOLD
-- ============================================================
local function releaseHold()
    if not State.holding then
        return
    end

    local character = LocalPlayer.Character
    local original = State.originalMovement

    if character and original then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local root = character:FindFirstChild("HumanoidRootPart")

        if humanoid then
            humanoid.WalkSpeed = original.WalkSpeed
            humanoid.JumpPower = original.JumpPower
            humanoid.JumpHeight = original.JumpHeight
            humanoid.AutoRotate = original.AutoRotate
        end

        if root then
            root.Anchored = original.Anchored
        end
    end

    State.holding = false
    State.originalMovement = nil
end

local function applyHold()
    if not CONFIG.HoldCharacter or not State.matched then
        return
    end

    local character = LocalPlayer.Character

    if not character then
        return
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")

    if not humanoid or not root then
        return
    end

    if not State.holding then
        State.originalMovement = {
            WalkSpeed = humanoid.WalkSpeed,
            JumpPower = humanoid.JumpPower,
            JumpHeight = humanoid.JumpHeight,
            AutoRotate = humanoid.AutoRotate,
            Anchored = root.Anchored,
        }
    end

    humanoid.WalkSpeed = 0
    humanoid.JumpPower = 0
    humanoid.JumpHeight = 0
    humanoid.AutoRotate = false

    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    root.Anchored = true

    State.holding = true
end

LocalPlayer.CharacterAdded:Connect(function()
    State.holding = false
    State.originalMovement = nil

    if State.matched then
        task.wait(1)
        applyHold()
    end
end)

-- ============================================================
-- VISITED SERVER CACHE
-- ============================================================
local Visited = {}

local function loadVisited()
    if type(isfile) ~= "function"
        or type(readfile) ~= "function"
        or not isfile(CONFIG.VisitedFile) then
        return
    end

    local ok, decoded = pcall(function()
        return HttpService:JSONDecode(readfile(CONFIG.VisitedFile))
    end)

    if ok and type(decoded) == "table" then
        Visited = decoded
    end
end

local function pruneVisited()
    local now = os.time()

    for id, timestamp in pairs(Visited) do
        if type(timestamp) ~= "number"
            or now - timestamp > CONFIG.VisitedExpire then
            Visited[id] = nil
        end
    end
end

local function saveVisited()
    if type(writefile) ~= "function" then
        return
    end

    pruneVisited()

    pcall(function()
        writefile(
            CONFIG.VisitedFile,
            HttpService:JSONEncode(Visited)
        )
    end)
end

local function markVisited(id)
    if type(id) == "string" and id ~= "" then
        Visited[id] = os.time()
        saveVisited()
    end
end

loadVisited()
pruneVisited()
markVisited(JobId)

-- ============================================================
-- FAST HOP
-- ============================================================
local ServerBrowser =
    ReplicatedStorage:WaitForChild("__ServerBrowser", 20)

local function shuffle(array)
    for index = #array, 2, -1 do
        local other = math.random(1, index)
        array[index], array[other] = array[other], array[index]
    end
end

local function fetchServers()
    if not ServerBrowser then
        return {}
    end

    State.pagesScanned = 0
    State.candidates = 0

    local pages = {}

    for page = 1, CONFIG.MaxPages do
        pages[page] = page
    end

    shuffle(pages)

    local output = {}
    local known = {}
    local nextIndex = 1
    local workersDone = 0
    local stopped = false
    local deadline = os.clock() + CONFIG.BrowserTimeout

    local workerCount = math.max(
        1,
        math.min(CONFIG.ConcurrentWorkers, CONFIG.MaxPages)
    )

    local function accept(id, data)
        if type(id) ~= "string"
            or id == ""
            or id == JobId
            or known[id]
            or Visited[id]
            or type(data) ~= "table" then
            return
        end

        local playerCount = tonumber(data.Count)

        if not playerCount
            or playerCount > CONFIG.MaxPlayers then
            return
        end

        if CONFIG.ForcedRegion
            and data.Region ~= CONFIG.ForcedRegion then
            return
        end

        known[id] = true

        table.insert(output, {
            JobId = id,
            Players = playerCount,
            Region = data.Region,
        })

        State.candidates = #output

        if #output >= CONFIG.CandidateTarget then
            stopped = true
        end
    end

    for _ = 1, workerCount do
        task.spawn(function()
            while not stopped
                and not State.destroyed
                and os.clock() < deadline do
                local index = nextIndex
                nextIndex = nextIndex + 1

                local page = pages[index]

                if not page then
                    break
                end

                local ok, data = pcall(function()
                    return ServerBrowser:InvokeServer(page)
                end)

                State.pagesScanned = State.pagesScanned + 1

                if ok and type(data) == "table" then
                    for id, serverData in pairs(data) do
                        accept(id, serverData)
                    end
                end
            end

            workersDone = workersDone + 1
        end)
    end

    while workersDone < workerCount
        and not State.destroyed
        and os.clock() < deadline do
        task.wait(0.05)
    end

    table.sort(output, function(left, right)
        return left.Players < right.Players
    end)

    return output
end

local HopServer

HopServer = function(reason)
    if not HOP_ENABLED then
        State.hopping = false

        if UI.Status then
            UI.Status.Text = "AUTO HOP OFF — GIỮ SERVER ĐỂ TEST"
            UI.Status.TextColor3 = Color3.fromRGB(247, 198, 89)
        end

        return
    end

    if State.hopping or State.destroyed then
        return
    end

    State.hopping = true
    State.hopAttempt = State.hopAttempt + 1

    if Debug.active then
        logEvent(
            "HOP_START",
            tostring(reason),
            nil,
            true
        )
        flushLog(true)
    end

    local servers = fetchServers()

    if #servers == 0 then
        State.hopping = false

        task.delay(CONFIG.RetryDelay, function()
            HopServer("Không tìm thấy server phù hợp")
        end)

        return
    end

    local pool = math.min(CONFIG.BestServerPool, #servers)
    local selected = servers[math.random(1, pool)]

    markVisited(selected.JobId)

    if UI.Status then
        UI.Status.Text = "ĐANG TELEPORT — "
            .. tostring(selected.Players)
            .. " PLAYERS"
        UI.Status.TextColor3 = Color3.fromRGB(110, 194, 244)
    end

    local ok = pcall(function()
        ServerBrowser:InvokeServer("teleport", selected.JobId)
    end)

    if not ok then
        State.hopping = false

        task.delay(CONFIG.RetryDelay, function()
            HopServer("Invoke teleport lỗi")
        end)
    end
end

TeleportService.TeleportInitFailed:Connect(function(
    player,
    result,
    message
)
    if player ~= LocalPlayer or not HOP_ENABLED then
        return
    end

    State.hopping = false

    warn(
        "[SERVER TIME DEBUG] Teleport failed:",
        tostring(result),
        tostring(message)
    )

    task.delay(CONFIG.RetryDelay, function()
        HopServer("TeleportInitFailed")
    end)
end)

GuiService.ErrorMessageChanged:Connect(function()
    if not HOP_ENABLED then
        return
    end

    local ok, errorType = pcall(function()
        return GuiService:GetErrorType()
    end)

    if ok
        and errorType
            == Enum.ConnectionError.DisconnectErrors then
        pcall(function()
            TeleportService:TeleportToPlaceInstance(
                PlaceId,
                JobId,
                LocalPlayer
            )
        end)
    end
end)

-- ============================================================
-- UI
-- ============================================================
local oldGui = CoreGui:FindFirstChild(CONFIG.GuiName)

if oldGui then
    oldGui:Destroy()
end

local PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")

if PlayerGui then
    local oldPlayerGui = PlayerGui:FindFirstChild(CONFIG.GuiName)

    if oldPlayerGui then
        oldPlayerGui:Destroy()
    end
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = CONFIG.GuiName
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local parented = false

pcall(function()
    if type(gethui) == "function" then
        ScreenGui.Parent = gethui()
        parented = true
    end
end)

if not parented then
    local ok = pcall(function()
        ScreenGui.Parent = CoreGui
    end)

    if not ok and PlayerGui then
        ScreenGui.Parent = PlayerGui
    end
end

local Main = Instance.new("Frame")
Main.Size = UDim2.fromOffset(520, 445)
Main.Position = UDim2.new(0.5, -260, 0.08, 0)
Main.BackgroundColor3 = Color3.fromRGB(18, 24, 32)
Main.BorderSizePixel = 0
Main.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = Main

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(60, 74, 91)
MainStroke.Thickness = 1
MainStroke.Parent = Main

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 42)
Header.BackgroundColor3 = Color3.fromRGB(27, 35, 46)
Header.BorderSizePixel = 0
Header.Parent = Main

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 10)
HeaderCorner.Parent = Header

local HeaderFix = Instance.new("Frame")
HeaderFix.Size = UDim2.new(1, 0, 0, 10)
HeaderFix.Position = UDim2.new(0, 0, 1, -10)
HeaderFix.BackgroundColor3 = Header.BackgroundColor3
HeaderFix.BorderSizePixel = 0
HeaderFix.Parent = Header

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -86, 1, 0)
Title.Position = UDim2.fromOffset(14, 0)
Title.BackgroundTransparency = 1
Title.Font = Enum.Font.GothamBold
Title.Text = "CHEST / STATUS DEBUG LITE"
Title.TextColor3 = Color3.fromRGB(107, 221, 159)
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local Minimize = Instance.new("TextButton")
Minimize.Size = UDim2.fromOffset(30, 28)
Minimize.Position = UDim2.new(1, -70, 0, 7)
Minimize.BackgroundColor3 = Color3.fromRGB(48, 60, 75)
Minimize.BorderSizePixel = 0
Minimize.Font = Enum.Font.GothamBold
Minimize.Text = "—"
Minimize.TextColor3 = Color3.fromRGB(235, 239, 244)
Minimize.TextSize = 15
Minimize.Parent = Header

local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 6)
MinCorner.Parent = Minimize

local Close = Instance.new("TextButton")
Close.Size = UDim2.fromOffset(30, 28)
Close.Position = UDim2.new(1, -36, 0, 7)
Close.BackgroundColor3 = Color3.fromRGB(127, 58, 58)
Close.BorderSizePixel = 0
Close.Font = Enum.Font.GothamBold
Close.Text = "X"
Close.TextColor3 = Color3.fromRGB(255, 236, 236)
Close.TextSize = 13
Close.Parent = Header

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = Close

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -24, 1, -54)
Content.Position = UDim2.fromOffset(12, 48)
Content.BackgroundTransparency = 1
Content.Parent = Main

UI.Status = Instance.new("TextLabel")
UI.Status.Size = UDim2.new(1, 0, 0, 24)
UI.Status.BackgroundTransparency = 1
UI.Status.Font = Enum.Font.GothamBold
UI.Status.Text = "ĐANG ĐỌC SERVER TIME..."
UI.Status.TextColor3 = Color3.fromRGB(247, 198, 89)
UI.Status.TextSize = 13
UI.Status.TextXAlignment = Enum.TextXAlignment.Left
UI.Status.Parent = Content

UI.Timer = Instance.new("TextLabel")
UI.Timer.Size = UDim2.new(1, 0, 0, 40)
UI.Timer.Position = UDim2.fromOffset(0, 27)
UI.Timer.BackgroundTransparency = 1
UI.Timer.Font = Enum.Font.GothamBold
UI.Timer.Text = "Server Timer: --h --m --s"
UI.Timer.TextColor3 = Color3.fromRGB(240, 244, 248)
UI.Timer.TextSize = 24
UI.Timer.TextXAlignment = Enum.TextXAlignment.Left
UI.Timer.Parent = Content

UI.Window = Instance.new("TextLabel")
UI.Window.Size = UDim2.new(1, 0, 0, 36)
UI.Window.Position = UDim2.fromOffset(0, 69)
UI.Window.BackgroundTransparency = 1
UI.Window.Font = Enum.Font.Gotham
UI.Window.Text = "Không hop: -- → --"
UI.Window.TextColor3 = Color3.fromRGB(177, 188, 202)
UI.Window.TextSize = 12
UI.Window.TextXAlignment = Enum.TextXAlignment.Left
UI.Window.TextYAlignment = Enum.TextYAlignment.Top
UI.Window.Parent = Content

UI.Countdown = Instance.new("TextLabel")
UI.Countdown.Size = UDim2.new(1, 0, 0, 24)
UI.Countdown.Position = UDim2.fromOffset(0, 105)
UI.Countdown.BackgroundTransparency = 1
UI.Countdown.Font = Enum.Font.GothamMedium
UI.Countdown.Text = "Đang tính..."
UI.Countdown.TextColor3 = Color3.fromRGB(129, 175, 224)
UI.Countdown.TextSize = 12
UI.Countdown.TextXAlignment = Enum.TextXAlignment.Left
UI.Countdown.Parent = Content

UI.Source = Instance.new("TextLabel")
UI.Source.Size = UDim2.new(1, 0, 0, 32)
UI.Source.Position = UDim2.fromOffset(0, 132)
UI.Source.BackgroundTransparency = 1
UI.Source.Font = Enum.Font.Gotham
UI.Source.Text = "Source: chưa xác định"
UI.Source.TextColor3 = Color3.fromRGB(142, 155, 173)
UI.Source.TextSize = 10
UI.Source.TextWrapped = true
UI.Source.TextXAlignment = Enum.TextXAlignment.Left
UI.Source.TextYAlignment = Enum.TextYAlignment.Top
UI.Source.Parent = Content

UI.DebugStatus = Instance.new("TextLabel")
UI.DebugStatus.Size = UDim2.new(1, 0, 0, 22)
UI.DebugStatus.Position = UDim2.fromOffset(0, 169)
UI.DebugStatus.BackgroundTransparency = 1
UI.DebugStatus.Font = Enum.Font.GothamBold
UI.DebugStatus.Text = "DEBUG: CHỜ CỬA SỔ"
UI.DebugStatus.TextColor3 = Color3.fromRGB(143, 158, 178)
UI.DebugStatus.TextSize = 11
UI.DebugStatus.TextXAlignment = Enum.TextXAlignment.Left
UI.DebugStatus.Parent = Content

UI.DebugInfo = Instance.new("TextLabel")
UI.DebugInfo.Size = UDim2.new(1, 0, 0, 38)
UI.DebugInfo.Position = UDim2.fromOffset(0, 193)
UI.DebugInfo.BackgroundTransparency = 1
UI.DebugInfo.Font = Enum.Font.Code
UI.DebugInfo.Text = "Events: 0 | Special: 0 | Deep: OFF"
UI.DebugInfo.TextColor3 = Color3.fromRGB(130, 146, 165)
UI.DebugInfo.TextSize = 10
UI.DebugInfo.TextWrapped = true
UI.DebugInfo.TextXAlignment = Enum.TextXAlignment.Left
UI.DebugInfo.TextYAlignment = Enum.TextYAlignment.Top
UI.DebugInfo.Parent = Content

UI.Mode = Instance.new("TextLabel")
UI.Mode.Size = UDim2.new(1, 0, 0, 20)
UI.Mode.Position = UDim2.fromOffset(0, 235)
UI.Mode.BackgroundTransparency = 1
UI.Mode.Font = Enum.Font.GothamBold
UI.Mode.Text = "AUTO HOP: "
    .. (HOP_ENABLED and "ON" or "OFF (TEST MODE)")
UI.Mode.TextColor3 = HOP_ENABLED
    and Color3.fromRGB(107, 221, 159)
    or Color3.fromRGB(247, 198, 89)
UI.Mode.TextSize = 11
UI.Mode.TextXAlignment = Enum.TextXAlignment.Left
UI.Mode.Parent = Content

UI.DeepButton = Instance.new("TextButton")
UI.DeepButton.Size = UDim2.new(1, 0, 0, 34)
UI.DeepButton.Position = UDim2.fromOffset(0, 258)
UI.DeepButton.BackgroundColor3 = Debug.deep
    and Color3.fromRGB(42, 126, 83)
    or Color3.fromRGB(91, 63, 126)
UI.DeepButton.BorderSizePixel = 0
UI.DeepButton.Font = Enum.Font.GothamBold
UI.DeepButton.Text = Debug.deep
    and "DEEP STATUS SCAN: ON"
    or "DEEP STATUS SCAN: OFF"
UI.DeepButton.TextColor3 = Color3.fromRGB(245, 240, 255)
UI.DeepButton.TextSize = 12
UI.DeepButton.Parent = Content

local DeepCorner = Instance.new("UICorner")
DeepCorner.CornerRadius = UDim.new(0, 7)
DeepCorner.Parent = UI.DeepButton

UI.ProbeStatus = Instance.new("TextLabel")
UI.ProbeStatus.Size = UDim2.new(1, 0, 0, 19)
UI.ProbeStatus.Position = UDim2.fromOffset(0, 297)
UI.ProbeStatus.BackgroundTransparency = 1
UI.ProbeStatus.Font = Enum.Font.GothamBold
UI.ProbeStatus.Text = "PICKUP PROBE: ARMED — AUTO"
UI.ProbeStatus.TextColor3 = Color3.fromRGB(255, 186, 73)
UI.ProbeStatus.TextSize = 10
UI.ProbeStatus.TextXAlignment = Enum.TextXAlignment.Left
UI.ProbeStatus.Parent = Content

UI.ProbeButton = Instance.new("TextButton")
UI.ProbeButton.Size = UDim2.new(1, 0, 0, 32)
UI.ProbeButton.Position = UDim2.fromOffset(0, 319)
UI.ProbeButton.BackgroundColor3 = Color3.fromRGB(137, 83, 42)
UI.ProbeButton.BorderSizePixel = 0
UI.ProbeButton.Font = Enum.Font.GothamBold
UI.ProbeButton.Text = "KÍCH HOẠT PICKUP PROBE THỦ CÔNG"
UI.ProbeButton.TextColor3 = Color3.fromRGB(255, 244, 230)
UI.ProbeButton.TextSize = 11
UI.ProbeButton.Parent = Content

local ProbeCorner = Instance.new("UICorner")
ProbeCorner.CornerRadius = UDim.new(0, 7)
ProbeCorner.Parent = UI.ProbeButton

UI.HopButton = Instance.new("TextButton")
UI.HopButton.Size = UDim2.new(0.5, -5, 0, 32)
UI.HopButton.Position = UDim2.new(0, 0, 1, -35)
UI.HopButton.BackgroundColor3 = Color3.fromRGB(46, 94, 139)
UI.HopButton.BorderSizePixel = 0
UI.HopButton.Font = Enum.Font.GothamBold
UI.HopButton.Text = HOP_ENABLED
    and "HOP SERVER NGAY"
    or "HOP OFF (getgenv().turn)"
UI.HopButton.TextColor3 = Color3.fromRGB(240, 247, 255)
UI.HopButton.TextSize = 11
UI.HopButton.Parent = Content

local HopCorner = Instance.new("UICorner")
HopCorner.CornerRadius = UDim.new(0, 7)
HopCorner.Parent = UI.HopButton

UI.ReleaseButton = Instance.new("TextButton")
UI.ReleaseButton.Size = UDim2.new(0.5, -5, 0, 32)
UI.ReleaseButton.Position = UDim2.new(0.5, 5, 1, -35)
UI.ReleaseButton.BackgroundColor3 = Color3.fromRGB(72, 78, 89)
UI.ReleaseButton.BorderSizePixel = 0
UI.ReleaseButton.Font = Enum.Font.GothamBold
UI.ReleaseButton.Text = "BỎ GIỮ NHÂN VẬT"
UI.ReleaseButton.TextColor3 = Color3.fromRGB(235, 239, 244)
UI.ReleaseButton.TextSize = 11
UI.ReleaseButton.Parent = Content

local ReleaseCorner = Instance.new("UICorner")
ReleaseCorner.CornerRadius = UDim.new(0, 7)
ReleaseCorner.Parent = UI.ReleaseButton

-- Drag
do
    local dragging = false
    local dragStart
    local startPosition

    Header.InputBegan:Connect(function(input)
        if input.UserInputType
                == Enum.UserInputType.MouseButton1
            or input.UserInputType
                == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPosition = Main.Position
        end
    end)

    Header.InputEnded:Connect(function(input)
        if input.UserInputType
                == Enum.UserInputType.MouseButton1
            or input.UserInputType
                == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging then
            return
        end

        if input.UserInputType
                ~= Enum.UserInputType.MouseMovement
            and input.UserInputType
                ~= Enum.UserInputType.Touch then
            return
        end

        local delta = input.Position - dragStart

        Main.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end)
end

local minimized = false

Minimize.MouseButton1Click:Connect(function()
    minimized = not minimized
    Content.Visible = not minimized
    Main.Size = minimized
        and UDim2.fromOffset(520, 42)
        or UDim2.fromOffset(520, 445)
    Minimize.Text = minimized and "+" or "—"
end)

Close.MouseButton1Click:Connect(function()
    State.destroyed = true

    if Debug.active then
        stopDebug("UI closed")
    end

    releaseHold()
    ScreenGui:Destroy()
end)

UI.DeepButton.MouseButton1Click:Connect(function()
    setDeepMode(not Debug.deep)
end)

UI.ProbeButton.MouseButton1Click:Connect(function()
    if not Debug.active then
        notify(
            "Pickup Probe",
            "Debug chưa hoạt động vì server chưa nằm trong cửa sổ."
        )
        return
    end

    triggerPickupProbe(
        "Manual button",
        "User armed probe before/after pickup"
    )
end)

UI.ReleaseButton.MouseButton1Click:Connect(function()
    CONFIG.HoldCharacter = false
    releaseHold()
    UI.ReleaseButton.Text = "ĐÃ BỎ GIỮ"
end)

UI.HopButton.MouseButton1Click:Connect(function()
    if HOP_ENABLED then
        releaseHold()
        State.matched = false
        HopServer("Người dùng bấm Hop")
    else
        notify(
            "Auto Hop đang OFF",
            'Bật bằng getgenv().turn = "on" trước khi chạy.'
        )
    end
end)

-- ============================================================
-- MAIN
-- ============================================================
task.spawn(function()
    local startedAt, source, count = waitForServerStart()

    if not startedAt then
        UI.Status.Text = "KHÔNG TÌM THẤY TimeIn"
        UI.Status.TextColor3 = Color3.fromRGB(238, 104, 104)

        if HOP_ENABLED then
            HopServer("Không tìm thấy TimeIn")
        end

        return
    end

    State.startedAt = startedAt
    State.source = source
    State.sourceCount = count

    UI.Source.Text = string.format(
        "Source: %s | Khớp %d Location",
        source,
        count
    )

    while not State.destroyed and ScreenGui.Parent do
        local now = getServerNow()

        if now then
            State.uptime = math.max(0, now - State.startedAt)
            getgenv().ServerTimeCurrentUptime = State.uptime

            local window = evaluateWindow(State.uptime)

            UI.Timer.Text =
                "Server Timer: " .. formatDuration(State.uptime)

            UI.Window.Text = string.format(
                "Không hop: %s → %s | Mốc: %s",
                formatDuration(window.startTime),
                formatDuration(window.endTime),
                formatDuration(window.boundary)
            )

            if window.matched then
                if not State.matched then
                    State.matched = true
                    getgenv().ServerTimeTargetFound = true

                    UI.Status.Text =
                        "ĐÚNG CỬA SỔ — GIỮ SERVER"
                    UI.Status.TextColor3 =
                        Color3.fromRGB(107, 221, 159)

                    applyHold()

                    if CONFIG.DebugEnabled then
                        startDebug(window.boundary)
                    end

                    notify(
                        "Server mục tiêu",
                        formatDuration(State.uptime)
                    )
                end

                UI.Countdown.Text =
                    "Còn "
                    .. formatDuration(window.untilEnd)
                    .. " đến hết cửa sổ"

                if CONFIG.HoldCharacter then
                    applyHold()
                end
            else
                if State.matched then
                    State.matched = false
                    getgenv().ServerTimeTargetFound = false

                    releaseHold()

                    if Debug.active then
                        stopDebug("Ra khỏi cửa sổ")
                    end
                end

                UI.Countdown.Text =
                    "Còn "
                    .. formatDuration(window.untilStart)
                    .. " đến cửa sổ gần nhất"

                if HOP_ENABLED and not State.hopping then
                    UI.Status.Text =
                        "SAI CỬA SỔ — ĐANG TÌM SERVER"
                    UI.Status.TextColor3 =
                        Color3.fromRGB(247, 198, 89)

                    task.spawn(
                        HopServer,
                        "Uptime ngoài cửa sổ"
                    )
                elseif not HOP_ENABLED then
                    UI.Status.Text =
                        "AUTO HOP OFF — ĐANG TEST SERVER NÀY"
                    UI.Status.TextColor3 =
                        Color3.fromRGB(247, 198, 89)
                end
            end

            if Debug.active then
                updateDebugInfo(
                    Debug.deep
                        and "DEBUG ACTIVE — DEEP ON"
                        or "DEBUG ACTIVE — FILTERED",
                    Debug.deep
                        and Color3.fromRGB(107, 221, 159)
                        or Color3.fromRGB(129, 175, 224)
                )
            end
        end

        task.wait(1)
    end
end)

-- Pickup probe lifecycle.
task.spawn(function()
    while not State.destroyed do
        if Debug.active then
            prunePickupHistory()

            if Debug.pickup.active then
                local remaining = math.max(
                    0,
                    Debug.pickup.untilClock - os.clock()
                )

                if UI.ProbeStatus then
                    UI.ProbeStatus.Text = string.format(
                        "PICKUP PROBE #%d: ACTIVE — CÒN %.1fs | %s",
                        Debug.pickup.id,
                        remaining,
                        Debug.pickup.trigger
                    )
                    UI.ProbeStatus.TextColor3 =
                        Color3.fromRGB(107, 221, 159)
                end

                if remaining <= 0 then
                    logEvent(
                        "PICKUP_PROBE_STOP",
                        string.format(
                            "Probe#%d | trigger=%s | finalUptime=%s",
                            Debug.pickup.id,
                            Debug.pickup.trigger,
                            formatDuration(State.uptime)
                        ),
                        nil,
                        true
                    )

                    Debug.pickup.active = false
                    Debug.pickup.untilClock = 0

                    if UI.ProbeStatus then
                        UI.ProbeStatus.Text =
                            "PICKUP PROBE: ARMED — AUTO"
                        UI.ProbeStatus.TextColor3 =
                            Color3.fromRGB(255, 186, 73)
                    end
                end
            elseif UI.ProbeStatus then
                UI.ProbeStatus.Text =
                    "PICKUP PROBE: ARMED — AUTO | HISTORY "
                    .. tostring(#Debug.pickup.history)
                UI.ProbeStatus.TextColor3 =
                    Color3.fromRGB(255, 186, 73)
            end
        elseif UI.ProbeStatus then
            UI.ProbeStatus.Text =
                "PICKUP PROBE: CHỜ DEBUG BẮT ĐẦU"
            UI.ProbeStatus.TextColor3 =
                Color3.fromRGB(143, 158, 178)
        end

        task.wait(0.1)
    end
end)

-- Flush log định kỳ.
task.spawn(function()
    while not State.destroyed do
        if Debug.active then
            flushLog(false)
        end

        task.wait(CONFIG.FlushInterval)
    end
end)

-- Quét object/attribute có mục tiêu theo chu kỳ chậm.
task.spawn(function()
    while not State.destroyed do
        if Debug.active then
            scanTargetRoots("periodic")
        end

        task.wait(CONFIG.TargetScanInterval)
    end
end)

print("[CHEST DEBUG LITE] Started")
print("[CHEST DEBUG LITE] Auto Hop:", HOP_ENABLED and "ON" or "OFF")
print("[CHEST DEBUG LITE] JobId:", JobId)

print(
    "[PICKUP PROBE] History:",
    CONFIG.PickupHistorySeconds,
    "seconds | After trigger:",
    CONFIG.PickupProbeSeconds,
    "seconds"
)
