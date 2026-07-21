--[[
    SERVER TIME HUNTER - Blox Fruits
    ------------------------------------------------------------
    Muc tieu:
      - Lay uptime that cua JobId bang:
          Workspace._WorldOrigin.Locations.<Location>.@TimeIn
          Workspace:GetServerTimeNow() - TimeIn

      - Giu server trong cua so 10 phut truoc va 20 phut sau moi moc 4 gio:
          03:50:00 -> 04:20:00
          07:50:00 -> 08:20:00
          11:50:00 -> 12:20:00
          ...

      - Khi qua cuoi cua so (VD: sau 04:20:00):
          Tu dong bo giu nhan vat va hop tim server khac.

      - Neu khong nam trong cua so:
          Tim server it nguoi va hop nhanh bang __ServerBrowser.

      - Khi tim dung server:
          Khong hop nua, giu nhan vat dung im, tiep tuc hien UI.

      - Focused spawn debugger:
          Chi bat dau ghi file trong 2 phut truoc moc 4h.
          Tiep tuc ghi 2 phut sau moc de bat tin hieu spawn.
          Tim Chalice/Fist/Chest/Key/Spawn trong objects, attributes,
          ValueBase, tags, RemoteEvent, outgoing remotes va getgc constants.
          File duoc ghi truc tiep vao workspace cua executor,
          ten file co day du JobId + boundary + uptime bat dau.

    Luu y:
      - Script KHONG dung workspace.DistributedGameTime.
      - Nen cho file vao auto-execute de no tu chay lai sau moi lan hop.
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
local CollectionService   = game:GetService("CollectionService")

local LocalPlayer = Players.LocalPlayer
repeat task.wait() until LocalPlayer

local PlaceId = game.PlaceId
local JobId   = game.JobId

-- ============================================================
-- CONFIG
-- ============================================================
getgenv().ServerTimeHunterConfig = getgenv().ServerTimeHunterConfig or {}

local USER_CONFIG = getgenv().ServerTimeHunterConfig

local CONFIG = {
    -- Cua so thoi gian
    PeriodHours          = USER_CONFIG.PeriodHours or 4,
    WindowMinutes        = USER_CONFIG.WindowMinutes or 10,

    -- So giay khong hop sau moi moc 4 gio.
    -- Mac dinh 20 phut: 04:00 -> 04:20, 08:00 -> 08:20...
    AfterBoundaryGrace   = USER_CONFIG.AfterBoundaryGrace or (20 * 60),

    -- Dung im khi tim dung server
    HoldCharacter        = USER_CONFIG.HoldCharacter ~= false,

    -- Hop
    MaxPlayers           = USER_CONFIG.MaxPlayers or 4, -- chap nhan <= 4 nguoi
    ForcedRegion         = USER_CONFIG.ForcedRegion,     -- nil, "US", "EU", "AP"...
    MaxPages             = USER_CONFIG.MaxPages or 500,
    ConcurrentWorkers    = USER_CONFIG.ConcurrentWorkers or 6,
    CandidateTarget      = USER_CONFIG.CandidateTarget or 18,
    BrowserTimeout       = USER_CONFIG.BrowserTimeout or 8,
    RetryDelay           = USER_CONFIG.RetryDelay or 1.5,
    MaxHopRetries        = USER_CONFIG.MaxHopRetries or 8,
    DecisionDelay        = USER_CONFIG.DecisionDelay or 1.2,

    -- Random trong nhom server it nguoi nhat de tranh cac may cung chon 1 server
    BestServerPool       = USER_CONFIG.BestServerPool or 8,

    -- TimeIn
    TimeInWaitTimeout    = USER_CONFIG.TimeInWaitTimeout or 20,
    TimeInRetryInterval  = USER_CONFIG.TimeInRetryInterval or 0.5,

    -- Debug spawn Chalice / Fist / Chest / Key
    DebugEnabled          = USER_CONFIG.DebugEnabled ~= false,
    DebugBeforeBoundary   = USER_CONFIG.DebugBeforeBoundary or 120,
    DebugAfterBoundary    = USER_CONFIG.DebugAfterBoundary or 120,
    DebugDeepScanInterval = USER_CONFIG.DebugDeepScanInterval or 1.5,
    DebugFlushInterval    = USER_CONFIG.DebugFlushInterval or 2,
    DebugMaxLines         = USER_CONFIG.DebugMaxLines or 12000,
    DebugDedupSeconds     = USER_CONFIG.DebugDedupSeconds or 0.6,
    DebugCaptureRemotes   = USER_CONFIG.DebugCaptureRemotes ~= false,
    DebugCaptureOutgoing  = USER_CONFIG.DebugCaptureOutgoing ~= false,
    DebugScanGC           = USER_CONFIG.DebugScanGC ~= false,
    DebugMaxGCHits        = USER_CONFIG.DebugMaxGCHits or 250,

    -- UI / log
    GuiName              = "ServerTimeHunter_Debug_UI",
    SaveMatchedLog       = USER_CONFIG.SaveMatchedLog == true,
    VisitedFile          = "ServerTimeHunter_Visited.json",
    VisitedExpire        = USER_CONFIG.VisitedExpire or 1800,
}

local PERIOD_SECONDS = CONFIG.PeriodHours * 3600
local WINDOW_SECONDS = CONFIG.WindowMinutes * 60

-- ============================================================
-- STATE
-- ============================================================
local State = {
    serverStartedAt = nil,
    sourcePath = nil,
    sourceCount = 0,

    uptime = 0,
    matched = false,
    hopping = false,
    destroyed = false,

    pagesScanned = 0,
    candidatesFound = 0,
    hopAttempt = 0,
    selectedJob = nil,
    selectedPlayers = nil,
    selectedRegion = nil,

    debugActive = false,
    debugEvents = 0,
    debugFile = nil,
    debugBoundary = nil,
    debugLastBoundary = nil,

    holdOriginal = nil,
}

getgenv().ServerTimeTargetFound = false
getgenv().ServerTimeCurrentUptime = 0
getgenv().ServerTimeCurrentJobId = JobId

-- ============================================================
-- HELPERS
-- ============================================================
local function safeNotify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = duration or 6,
        })
    end)
end

local function formatDuration(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))

    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60

    if days > 0 then
        return string.format("%dd %02dh %02dm %02ds", days, hours, minutes, secs)
    end

    return string.format("%02dh %02dm %02ds", hours, minutes, secs)
end

local function formatClock(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))

    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60

    return string.format("%02d:%02d:%02d", hours, minutes, secs)
end

local function shortJobId(value)
    value = tostring(value or "")
    if #value <= 22 then
        return value
    end
    return value:sub(1, 9) .. "..." .. value:sub(-9)
end

local function getServerNow()
    local ok, result = pcall(function()
        return Workspace:GetServerTimeNow()
    end)

    if ok and type(result) == "number" then
        return result
    end

    return nil
end

local function evaluateWindow(uptime)
    uptime = math.max(0, tonumber(uptime) or 0)

    local completedPeriods = math.floor(uptime / PERIOD_SECONDS)
    local remainder = uptime - completedPeriods * PERIOD_SECONDS

    local nextBoundary = (completedPeriods + 1) * PERIOD_SECONDS

    local inPreWindow =
        remainder >= (PERIOD_SECONDS - WINDOW_SECONDS)
        and remainder < PERIOD_SECONDS

    local inPostWindow = false
    if CONFIG.AfterBoundaryGrace > 0 and uptime >= PERIOD_SECONDS then
        inPostWindow = remainder <= CONFIG.AfterBoundaryGrace
    end

    local matched = inPreWindow or inPostWindow

    local targetBoundary
    if inPostWindow then
        targetBoundary = completedPeriods * PERIOD_SECONDS
    else
        targetBoundary = nextBoundary
    end

    local targetStart = targetBoundary - WINDOW_SECONDS
    local targetEnd = targetBoundary + CONFIG.AfterBoundaryGrace

    local untilWindow = math.max(0, targetStart - uptime)
    local untilBoundary = math.max(0, targetBoundary - uptime)
    local untilWindowEnd = math.max(0, targetEnd - uptime)

    return {
        matched = matched,
        remainder = remainder,
        targetBoundary = targetBoundary,
        targetStart = targetStart,
        targetEnd = targetEnd,
        untilWindow = untilWindow,
        untilBoundary = untilBoundary,
        untilWindowEnd = untilWindowEnd,
        inPreWindow = inPreWindow,
        inPostWindow = inPostWindow,
        -- Giu alias cu de khong pha code/debug neu co tham chieu.
        inGrace = inPostWindow,
    }
end

-- ============================================================
-- DETECT SERVER START FROM TimeIn
-- ============================================================
local PRIORITY_LOCATIONS = {
    "Ancient Clock",
    "Castle on the Sea",
    "Temple of Time",
    "Floating Turtle",
    "Mansion",
    "Port Town",
    "Sea",
}

local function getLocationsFolder()
    local worldOrigin = Workspace:FindFirstChild("_WorldOrigin")
    if not worldOrigin then
        return nil
    end

    return worldOrigin:FindFirstChild("Locations")
end

local function validTimeIn(value)
    if type(value) ~= "number" then
        return false
    end

    local now = getServerNow()
    if not now then
        return value > 1000000000
    end

    local age = now - value
    return value > 1000000000 and age >= -10 and age < 31536000
end

local function detectTimeIn()
    local locations = getLocationsFolder()
    if not locations then
        return nil, nil, 0
    end

    -- Duong nhanh: thu cac Location da biet truoc
    for _, name in ipairs(PRIORITY_LOCATIONS) do
        local location = locations:FindFirstChild(name)
        if location then
            local value = location:GetAttribute("TimeIn")
            if validTimeIn(value) then
                -- Van dem so Location cung timestamp de hien thi do tin cay
                local rounded = math.floor(value + 0.5)
                local count = 0

                for _, other in ipairs(locations:GetChildren()) do
                    local otherValue = other:GetAttribute("TimeIn")
                    if type(otherValue) == "number"
                        and math.floor(otherValue + 0.5) == rounded then
                        count += 1
                    end
                end

                return value,
                    "Workspace._WorldOrigin.Locations." .. name .. ".@TimeIn",
                    count
            end
        end
    end

    -- Fallback: chon cum TimeIn xuat hien nhieu nhat
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

            groups[rounded].count += 1
            groups[rounded].total += value
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
        "Workspace._WorldOrigin.Locations." .. best.example .. ".@TimeIn",
        best.count
end

local function waitForTimeIn(timeout)
    local deadline = os.clock() + timeout

    repeat
        local startedAt, sourcePath, count = detectTimeIn()

        if startedAt then
            return startedAt, sourcePath, count
        end

        task.wait(CONFIG.TimeInRetryInterval)
    until os.clock() >= deadline or State.destroyed

    return nil, nil, 0
end

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
        writefile(CONFIG.VisitedFile, HttpService:JSONEncode(Visited))
    end)
end

local function markVisited(id)
    if type(id) ~= "string" or id == "" then
        return
    end

    Visited[id] = os.time()
    saveVisited()
end

loadVisited()
pruneVisited()
markVisited(JobId)

-- ============================================================
-- CHARACTER HOLD
-- ============================================================
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

    if not State.holdOriginal then
        State.holdOriginal = {
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
end

local function releaseHold()
    local character = LocalPlayer.Character
    local original = State.holdOriginal

    if not character or not original then
        return
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")

    if humanoid then
        humanoid.WalkSpeed = original.WalkSpeed or 16
        humanoid.JumpPower = original.JumpPower or 50
        humanoid.JumpHeight = original.JumpHeight or 7.2
        humanoid.AutoRotate = original.AutoRotate ~= false
    end

    if root then
        root.Anchored = original.Anchored == true
    end

    State.holdOriginal = nil
end

LocalPlayer.CharacterAdded:Connect(function()
    State.holdOriginal = nil

    if State.matched and CONFIG.HoldCharacter then
        task.wait(1)
        applyHold()
    end
end)


-- ============================================================
-- FULL-WINDOW SPAWN DEBUGGER
-- Chi ghi file trong khoang gan moc 4 gio.
-- ============================================================
local DebugStatusLabel
local DebugInfoLabel

local DEBUG_KEYWORDS = {
    "god's chalice", "gods chalice", "god chalice", "godschalice", "chalice",
    "sweet chalice", "sweetchalice", "fist of darkness", "fistofdarkness",
    "dark fist", "darkfist", "fist",
    "darkness", "cup", "key", "chest", "legendary chest",
    "elite hunter", "elite", "loot", "drop", "pickup", "pickedup",
    "itemspawn", "item spawn", "spawn item", "spawned", "spawn",
    "hallow essence", "fire essence", "hidden key", "hiddenkey",
    "library key", "librarykey", "water key", "waterkey",
    "holy torch", "reward", "treasure"
}

local DEBUG_ATTRIBUTE_KEYWORDS = {
    "chalice", "fist", "darkness", "cup", "key", "chest",
    "spawn", "next", "cooldown", "expire", "destroyed", "created",
    "loot", "drop", "pickup", "reward", "ready", "active", "state"
}

local Debug = {
    active = false,
    stopping = false,
    boundary = nil,
    startedAtUptime = nil,
    fileName = nil,
    lines = {},
    dirty = false,
    eventCount = 0,
    droppedLines = 0,
    connections = {},
    watched = setmetatable({}, { __mode = "k" }),
    lastLogByKey = {},
    remoteWatched = setmetatable({}, { __mode = "k" }),
    lastInventory = {},
    lastSnapshot = {},
    objectSeen = setmetatable({}, { __mode = "k" }),
    gcHits = 0,
}

local function lower(value)
    return string.lower(tostring(value or ""))
end

local function containsAnyKeyword(value, list)
    local text = lower(value)
    local tokenText = " " .. text:gsub("[^%w]+", " ") .. " "
    local compactText = text:gsub("[^%w]", "")

    for _, keyword in ipairs(list or DEBUG_KEYWORDS) do
        local keywordText = lower(keyword)
        local compactKeyword = keywordText:gsub("[^%w]", "")
        local found = false

        -- Tu ngan nhu key/cup phai dung theo token de tranh match "monkey".
        if #compactKeyword <= 4 and not string.find(keywordText, " ", 1, true) then
            found = string.find(tokenText, " " .. keywordText .. " ", 1, true) ~= nil
        else
            found = string.find(text, keywordText, 1, true) ~= nil
                or (#compactKeyword >= 6
                    and string.find(compactText, compactKeyword, 1, true) ~= nil)
        end

        if found then
            return true, keyword
        end
    end

    return false, nil
end

local function isRelevantName(value)
    return containsAnyKeyword(value, DEBUG_KEYWORDS)
end

local function isRelevantAttribute(value)
    return containsAnyKeyword(value, DEBUG_ATTRIBUTE_KEYWORDS)
end

local function safeFullName(instance)
    local ok, result = pcall(function()
        return instance:GetFullName()
    end)

    if ok then
        return result
    end

    return tostring(instance)
end

local function sanitizeFilePart(value)
    return tostring(value or "unknown"):gsub("[^%w%-_]", "_")
end

local function formatBoundaryForFile(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    return string.format("%02dh%02dm%02ds", hours, minutes, secs)
end

local function serializeValue(value, depth, seen)
    depth = depth or 0
    seen = seen or {}

    local valueType = typeof(value)

    if valueType == "nil" then
        return "nil"
    elseif valueType == "string" then
        local text = value
        if #text > 500 then
            text = text:sub(1, 500) .. "...[truncated]"
        end
        return string.format("%q", text)
    elseif valueType == "number" or valueType == "boolean" then
        return tostring(value)
    elseif valueType == "Instance" then
        return string.format("<%s:%s>", value.ClassName, safeFullName(value))
    elseif valueType == "Vector3" or valueType == "Vector2"
        or valueType == "CFrame" or valueType == "Color3"
        or valueType == "UDim" or valueType == "UDim2"
        or valueType == "BrickColor" or valueType == "EnumItem" then
        return tostring(value)
    elseif valueType == "table" then
        if seen[value] then
            return "<cycle>"
        end

        if depth >= 3 then
            return "<table:max-depth>"
        end

        seen[value] = true
        local parts = {}
        local count = 0

        for key, item in pairs(value) do
            count += 1
            if count > 35 then
                table.insert(parts, "...more")
                break
            end

            table.insert(parts,
                "[" .. serializeValue(key, depth + 1, seen) .. "]="
                .. serializeValue(item, depth + 1, seen)
            )
        end

        seen[value] = nil
        return "{" .. table.concat(parts, ", ") .. "}"
    end

    return "<" .. valueType .. ":" .. tostring(value) .. ">"
end

local function valueContainsKeyword(value, depth, seen)
    depth = depth or 0
    seen = seen or {}

    if depth > 4 then
        return false
    end

    local valueType = typeof(value)

    if valueType == "string" then
        return isRelevantName(value)
    elseif valueType == "Instance" then
        return isRelevantName(value.Name) or isRelevantName(safeFullName(value))
    elseif valueType == "table" then
        if seen[value] then
            return false
        end

        seen[value] = true
        local count = 0

        for key, item in pairs(value) do
            count += 1
            if count > 100 then
                break
            end

            if valueContainsKeyword(key, depth + 1, seen)
                or valueContainsKeyword(item, depth + 1, seen) then
                seen[value] = nil
                return true
            end
        end

        seen[value] = nil
    end

    return false
end

local function updateDebugLabels(statusText, statusColor)
    if DebugStatusLabel then
        DebugStatusLabel.Text = statusText or "DEBUG: chờ cửa sổ"
        if statusColor then
            DebugStatusLabel.TextColor3 = statusColor
        end
    end

    if DebugInfoLabel then
        local fileText = Debug.fileName or "chưa tạo file"
        if #fileText > 60 then
            fileText = "..." .. fileText:sub(-57)
        end

        DebugInfoLabel.Text = string.format(
            "Events: %d | Dropped: %d | File: %s",
            Debug.eventCount,
            Debug.droppedLines,
            fileText
        )
    end
end

local function debugLog(category, message, dedupKey)
    if not Debug.active then
        return
    end

    if #Debug.lines >= CONFIG.DebugMaxLines then
        Debug.droppedLines += 1
        updateDebugLabels("DEBUG: ĐANG GHI — ĐÃ CHẠM GIỚI HẠN", Color3.fromRGB(238, 154, 74))
        return
    end

    local nowClock = os.clock()
    local key = tostring(dedupKey or (category .. "|" .. message))
    local last = Debug.lastLogByKey[key]

    if last and nowClock - last < CONFIG.DebugDedupSeconds then
        return
    end

    Debug.lastLogByKey[key] = nowClock
    Debug.eventCount += 1
    State.debugEvents = Debug.eventCount

    local uptime = State.uptime or 0
    local line = string.format(
        "[%s][UPTIME %s][%s] %s",
        os.date("%H:%M:%S"),
        formatDuration(uptime),
        tostring(category),
        tostring(message)
    )

    table.insert(Debug.lines, line)
    Debug.dirty = true
    updateDebugLabels("DEBUG: ĐANG GHI DỮ LIỆU", Color3.fromRGB(107, 221, 159))
end

local function flushDebug(force)
    if not Debug.fileName or type(writefile) ~= "function" then
        return
    end

    if not Debug.dirty and not force then
        return
    end

    local content = table.concat(Debug.lines, "\n") .. "\n"
    local ok, err = pcall(function()
        writefile(Debug.fileName, content)
    end)

    if ok then
        Debug.dirty = false
    else
        updateDebugLabels("DEBUG: LỖI GHI FILE", Color3.fromRGB(238, 104, 104))
        warn("[SPAWN DEBUG] writefile failed:", err)
    end
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
    Debug.watched = setmetatable({}, { __mode = "k" })
    Debug.remoteWatched = setmetatable({}, { __mode = "k" })
end

local function inspectAttributes(instance, reason)
    local fullName = safeFullName(instance)
    local objectRelevant = isRelevantName(fullName)
    local ok, attributes = pcall(function()
        return instance:GetAttributes()
    end)

    if not ok or type(attributes) ~= "table" then
        return objectRelevant
    end

    local foundRelevant = objectRelevant

    for attributeName, value in pairs(attributes) do
        local attrRelevant = isRelevantAttribute(attributeName)
        local valueRelevant = valueContainsKeyword(value)

        if objectRelevant or attrRelevant or valueRelevant then
            foundRelevant = true
            local serialized = serializeValue(value)
            local snapshotKey = "attr|" .. fullName .. "|" .. tostring(attributeName)

            if Debug.lastSnapshot[snapshotKey] ~= serialized then
                Debug.lastSnapshot[snapshotKey] = serialized
                debugLog(
                    "ATTRIBUTE_SNAPSHOT",
                    string.format(
                        "%s | @%s=%s | reason=%s",
                        fullName,
                        tostring(attributeName),
                        serialized,
                        tostring(reason)
                    ),
                    "attr-snap|" .. snapshotKey .. "|" .. serialized
                )
            end
        end
    end

    return foundRelevant
end

local function inspectValueBase(instance, reason)
    if not instance:IsA("ValueBase") then
        return false
    end

    local fullName = safeFullName(instance)
    local value = instance.Value
    local relevant = isRelevantName(fullName) or valueContainsKeyword(value)

    if relevant then
        local serialized = serializeValue(value)
        local snapshotKey = "value|" .. fullName

        if Debug.lastSnapshot[snapshotKey] ~= serialized then
            Debug.lastSnapshot[snapshotKey] = serialized
            debugLog(
                "VALUE_SNAPSHOT",
                string.format(
                    "%s (%s) = %s | reason=%s",
                    fullName,
                    instance.ClassName,
                    serialized,
                    tostring(reason)
                ),
                "value-snap|" .. snapshotKey .. "|" .. serialized
            )
        end
    end

    return relevant
end

local function inspectTags(instance, reason)
    local ok, tags = pcall(function()
        return CollectionService:GetTags(instance)
    end)

    if not ok or type(tags) ~= "table" then
        return false
    end

    local relevant = false

    for _, tag in ipairs(tags) do
        if isRelevantName(tag) then
            relevant = true
            debugLog(
                "TAG",
                string.format(
                    "%s | tag=%s | reason=%s",
                    safeFullName(instance),
                    tostring(tag),
                    tostring(reason)
                ),
                "tag|" .. safeFullName(instance) .. "|" .. tostring(tag)
            )
        end
    end

    return relevant
end

local function remoteArgsRelevant(remote, packedArgs)
    if isRelevantName(remote.Name) or isRelevantName(safeFullName(remote)) then
        return true
    end

    for index = 1, packedArgs.n or #packedArgs do
        if valueContainsKeyword(packedArgs[index]) then
            return true
        end
    end

    return false
end

local function formatPackedArgs(packedArgs)
    local parts = {}
    local count = packedArgs.n or #packedArgs

    for index = 1, math.min(count, 20) do
        table.insert(parts, "[" .. index .. "]=" .. serializeValue(packedArgs[index]))
    end

    if count > 20 then
        table.insert(parts, "...more args")
    end

    return table.concat(parts, ", ")
end

local watchInstance

local function watchRemoteEvent(remote)
    if not CONFIG.DebugCaptureRemotes
        or Debug.remoteWatched[remote]
        or not remote:IsA("RemoteEvent") then
        return
    end

    Debug.remoteWatched[remote] = true

    addConnection(remote.OnClientEvent:Connect(function(...)
        if not Debug.active then
            return
        end

        local args = table.pack(...)

        if remoteArgsRelevant(remote, args) then
            debugLog(
                "REMOTE_IN",
                safeFullName(remote) .. " | " .. formatPackedArgs(args),
                "remote-in|" .. safeFullName(remote) .. "|" .. formatPackedArgs(args)
            )
        end
    end))
end

watchInstance = function(instance, reason)
    if not Debug.active or Debug.watched[instance] then
        return
    end

    local fullName = safeFullName(instance)
    local nameRelevant = isRelevantName(fullName)
    local attrRelevant = inspectAttributes(instance, reason)
    local valueRelevant = inspectValueBase(instance, reason)
    local tagRelevant = inspectTags(instance, reason)
    local relevant = nameRelevant or attrRelevant or valueRelevant or tagRelevant

    if instance:IsA("RemoteEvent") then
        watchRemoteEvent(instance)
    end

    if not relevant then
        return
    end

    Debug.watched[instance] = true

    debugLog(
        "OBJECT_WATCH",
        string.format(
            "%s | class=%s | reason=%s",
            fullName,
            instance.ClassName,
            tostring(reason)
        ),
        "watch|" .. fullName
    )

    addConnection(instance.AttributeChanged:Connect(function(attributeName)
        if not Debug.active then
            return
        end

        local ok, value = pcall(function()
            return instance:GetAttribute(attributeName)
        end)

        if ok then
            debugLog(
                "ATTRIBUTE_CHANGED",
                string.format(
                    "%s | @%s=%s",
                    safeFullName(instance),
                    tostring(attributeName),
                    serializeValue(value)
                ),
                "attr-change|" .. safeFullName(instance) .. "|"
                    .. tostring(attributeName) .. "|" .. serializeValue(value)
            )
        end
    end))

    if instance:IsA("ValueBase") then
        addConnection(instance.Changed:Connect(function(value)
            if Debug.active then
                debugLog(
                    "VALUE_CHANGED",
                    string.format(
                        "%s (%s) = %s",
                        safeFullName(instance),
                        instance.ClassName,
                        serializeValue(value)
                    ),
                    "value-change|" .. safeFullName(instance) .. "|"
                        .. serializeValue(value)
                )
            end
        end))
    end
end

local function inspectInstance(instance, reason)
    if not Debug.active then
        return
    end

    local fullName = safeFullName(instance)

    if isRelevantName(fullName) and not Debug.objectSeen[instance] then
        Debug.objectSeen[instance] = true
        debugLog(
            "OBJECT_FOUND",
            string.format(
                "%s | class=%s | reason=%s",
                fullName,
                instance.ClassName,
                tostring(reason)
            ),
            "found|" .. fullName
        )
    end

    watchInstance(instance, reason)
end

local function scanRoot(root, reason)
    if not root or not Debug.active then
        return
    end

    inspectInstance(root, reason)

    local ok, descendants = pcall(function()
        return root:GetDescendants()
    end)

    if not ok then
        return
    end

    for index, instance in ipairs(descendants) do
        if not Debug.active then
            break
        end

        inspectInstance(instance, reason)

        if index % 400 == 0 then
            task.wait()
        end
    end
end

local function getDebugRoots()
    local roots = {
        Workspace,
        ReplicatedStorage,
        LocalPlayer:FindFirstChild("Backpack"),
        LocalPlayer.Character,
        LocalPlayer:FindFirstChildOfClass("PlayerGui"),
    }

    local compact = {}
    for _, root in ipairs(roots) do
        if root then
            table.insert(compact, root)
        end
    end
    return compact
end

local function attachRootSignals(root)
    addConnection(root.DescendantAdded:Connect(function(instance)
        if not Debug.active then
            return
        end

        local fullName = safeFullName(instance)
        if isRelevantName(fullName) then
            debugLog(
                "DESCENDANT_ADDED",
                string.format("%s | class=%s", fullName, instance.ClassName),
                "added|" .. fullName
            )
        end

        task.defer(inspectInstance, instance, "DescendantAdded")
    end))

    addConnection(root.DescendantRemoving:Connect(function(instance)
        if not Debug.active then
            return
        end

        local fullName = safeFullName(instance)
        if Debug.watched[instance] or isRelevantName(fullName) then
            debugLog(
                "DESCENDANT_REMOVING",
                string.format("%s | class=%s", fullName, instance.ClassName),
                "removing|" .. fullName
            )
        end
    end))
end

local function scanInventory(reason)
    if not Debug.active then
        return
    end

    local current = {}
    local containers = {
        LocalPlayer:FindFirstChild("Backpack"),
        LocalPlayer.Character,
    }

    for _, container in ipairs(containers) do
        if container then
            for _, item in ipairs(container:GetChildren()) do
                if isRelevantName(item.Name) then
                    local key = container.Name .. "|" .. item.Name
                    current[key] = true

                    if not Debug.lastInventory[key] then
                        debugLog(
                            "INVENTORY_APPEARED",
                            string.format(
                                "%s in %s | class=%s | reason=%s",
                                item.Name,
                                container.Name,
                                item.ClassName,
                                tostring(reason)
                            ),
                            "inventory-add|" .. key
                        )
                    end
                end
            end
        end
    end

    for key in pairs(Debug.lastInventory) do
        if not current[key] then
            debugLog(
                "INVENTORY_DISAPPEARED",
                key .. " | reason=" .. tostring(reason),
                "inventory-remove|" .. key
            )
        end
    end

    Debug.lastInventory = current
end

local function scanGetGC()
    if not CONFIG.DebugScanGC or type(getgc) ~= "function" then
        return
    end

    task.spawn(function()
        debugLog("GC_SCAN", "Starting getgc/constants keyword scan")

        local ok, objects = pcall(getgc, true)
        if not ok or type(objects) ~= "table" then
            debugLog("GC_SCAN", "getgc failed or unsupported")
            return
        end

        for index, object in ipairs(objects) do
            if not Debug.active or Debug.gcHits >= CONFIG.DebugMaxGCHits then
                break
            end

            local objectType = type(object)

            if objectType == "table" and valueContainsKeyword(object) then
                Debug.gcHits += 1
                debugLog(
                    "GC_TABLE_HIT",
                    "index=" .. index .. " value=" .. serializeValue(object),
                    "gc-table|" .. index
                )
            elseif objectType == "function" and type(getconstants) == "function" then
                local constantsOk, constants = pcall(getconstants, object)
                if constantsOk and type(constants) == "table" then
                    for _, constant in ipairs(constants) do
                        if typeof(constant) == "string" and isRelevantName(constant) then
                            Debug.gcHits += 1
                            debugLog(
                                "GC_CONSTANT_HIT",
                                string.format(
                                    "index=%d constant=%s",
                                    index,
                                    serializeValue(constant)
                                ),
                                "gc-constant|" .. index .. "|" .. tostring(constant)
                            )
                            break
                        end
                    end
                end
            end

            if index % 250 == 0 then
                task.wait()
            end
        end

        debugLog(
            "GC_SCAN",
            "Completed getgc scan | hits=" .. tostring(Debug.gcHits)
        )
    end)
end

local function getDebugWindow(uptime)
    uptime = math.max(0, tonumber(uptime) or 0)

    local window = evaluateWindow(uptime)

    if window.matched then
        local phase = window.inPreWindow and "before-boundary"
            or "after-boundary"

        local distance
        if window.inPreWindow then
            distance = math.max(0, window.targetBoundary - uptime)
        else
            distance = math.max(0, uptime - window.targetBoundary)
        end

        return true, window.targetBoundary, phase, distance, window
    end

    return false,
        window.targetBoundary,
        "waiting",
        math.max(0, window.targetStart - uptime),
        window
end

local function createDebugHeader(boundary)
    return {
        "BLOX FRUITS SPAWN DEBUG",
        "Purpose: detect Chalice / Fist of Darkness / Chest / Key / spawn signals",
        "Generated: " .. os.date("%Y-%m-%d %H:%M:%S"),
        "PlaceId: " .. tostring(PlaceId),
        "JobId: " .. tostring(JobId),
        "Player: " .. tostring(LocalPlayer.Name),
        "ServerStartTimestamp: " .. tostring(State.serverStartedAt),
        "ServerTimeSource: " .. tostring(State.sourcePath),
        "DebugStartUptime: " .. formatDuration(State.uptime),
        "TargetBoundary: " .. formatDuration(boundary),
        "CaptureWindow: "
            .. formatDuration(boundary - WINDOW_SECONDS)
            .. " -> "
            .. formatDuration(boundary + CONFIG.AfterBoundaryGrace),
        "IMPORTANT: File is written for the entire no-hop window.",
        string.rep("=", 90),
    }
end

local function startDebug(boundary, phase)
    if Debug.active or State.destroyed then
        return
    end

    if State.debugLastBoundary == boundary then
        return
    end

    if type(writefile) ~= "function" then
        updateDebugLabels("DEBUG: EXECUTOR KHÔNG HỖ TRỢ writefile", Color3.fromRGB(238, 104, 104))
        return
    end

    Debug.active = true
    Debug.stopping = false
    Debug.boundary = boundary
    Debug.startedAtUptime = State.uptime
    Debug.lines = createDebugHeader(boundary)
    Debug.dirty = true
    Debug.eventCount = 0
    Debug.droppedLines = 0
    Debug.connections = {}
    Debug.watched = setmetatable({}, { __mode = "k" })
    Debug.remoteWatched = setmetatable({}, { __mode = "k" })
    Debug.lastLogByKey = {}
    Debug.lastInventory = {}
    Debug.lastSnapshot = {}
    Debug.objectSeen = setmetatable({}, { __mode = "k" })
    Debug.gcHits = 0

    local fileName = string.format(
        "ServerSpawnDebug_FULL_%s_Window-%s_to_%s_Start-%s_%s.txt",
        sanitizeFilePart(JobId),
        formatBoundaryForFile(boundary - WINDOW_SECONDS),
        formatBoundaryForFile(boundary + CONFIG.AfterBoundaryGrace),
        formatBoundaryForFile(State.uptime),
        os.date("%Y%m%d_%H%M%S")
    )

    Debug.fileName = fileName
    State.debugActive = true
    State.debugBoundary = boundary
    State.debugFile = fileName

    updateDebugLabels(
        "DEBUG: BẮT ĐẦU KIỂM TRA DỮ — " .. string.upper(phase),
        Color3.fromRGB(107, 221, 159)
    )

    debugLog(
        "DEBUG_START",
        string.format(
            "boundary=%s phase=%s uptime=%s file=%s",
            formatDuration(boundary),
            tostring(phase),
            formatDuration(State.uptime),
            fileName
        )
    )

    for _, root in ipairs(getDebugRoots()) do
        attachRootSignals(root)
        task.spawn(scanRoot, root, "initial-deep-scan")
    end

    scanInventory("debug-start")
    scanGetGC()

    task.spawn(function()
        while Debug.active and not State.destroyed do
            task.wait(CONFIG.DebugFlushInterval)
            flushDebug(false)
        end
    end)

    task.spawn(function()
        while Debug.active and not State.destroyed do
            task.wait(CONFIG.DebugDeepScanInterval)

            scanInventory("full-window-poll")

            for _, root in ipairs(getDebugRoots()) do
                if not Debug.active then
                    break
                end
                scanRoot(root, "full-window-rescan")
            end
        end
    end)
end

local function stopDebug(reason)
    if not Debug.active or Debug.stopping then
        return
    end

    Debug.stopping = true
    debugLog(
        "DEBUG_STOP",
        string.format(
            "reason=%s events=%d dropped=%d finalUptime=%s",
            tostring(reason),
            Debug.eventCount,
            Debug.droppedLines,
            formatDuration(State.uptime)
        )
    )

    flushDebug(true)
    disconnectDebugConnections()

    State.debugLastBoundary = Debug.boundary
    State.debugActive = false
    State.debugEvents = Debug.eventCount
    State.debugFile = Debug.fileName

    Debug.active = false
    Debug.stopping = false

    updateDebugLabels(
        "DEBUG: HOÀN TẤT — ĐÃ GHI " .. tostring(Debug.eventCount) .. " EVENTS",
        Color3.fromRGB(129, 175, 224)
    )
end

-- Hook outgoing FireServer/InvokeServer; chi log khi debug dang active.
if CONFIG.DebugCaptureOutgoing
    and type(hookmetamethod) == "function"
    and type(getnamecallmethod) == "function"
    and type(newcclosure) == "function" then

    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = table.pack(...)

        if Debug.active
            and typeof(self) == "Instance"
            and (method == "FireServer" or method == "InvokeServer")
            and (self:IsA("RemoteEvent") or self:IsA("RemoteFunction"))
            and remoteArgsRelevant(self, args) then

            task.defer(function()
                debugLog(
                    "REMOTE_OUT_" .. string.upper(method),
                    safeFullName(self) .. " | " .. formatPackedArgs(args),
                    "remote-out|" .. method .. "|" .. safeFullName(self)
                        .. "|" .. formatPackedArgs(args)
                )
            end)
        end

        return oldNamecall(self, ...)
    end))
end

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
Main.Size = UDim2.fromOffset(480, 370)
Main.Position = UDim2.new(0.5, -240, 0.12, 0)
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
Title.Text = "SERVER TIME HUNTER"
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

local Status = Instance.new("TextLabel")
Status.Size = UDim2.new(1, 0, 0, 24)
Status.BackgroundTransparency = 1
Status.Font = Enum.Font.GothamBold
Status.Text = "ĐANG ĐỌC SERVER TIME..."
Status.TextColor3 = Color3.fromRGB(247, 198, 89)
Status.TextSize = 13
Status.TextXAlignment = Enum.TextXAlignment.Left
Status.Parent = Content

local Timer = Instance.new("TextLabel")
Timer.Size = UDim2.new(1, 0, 0, 42)
Timer.Position = UDim2.fromOffset(0, 27)
Timer.BackgroundTransparency = 1
Timer.Font = Enum.Font.GothamBold
Timer.Text = "Server Timer: --h --m --s"
Timer.TextColor3 = Color3.fromRGB(240, 244, 248)
Timer.TextSize = 25
Timer.TextXAlignment = Enum.TextXAlignment.Left
Timer.Parent = Content

local WindowInfo = Instance.new("TextLabel")
WindowInfo.Size = UDim2.new(1, 0, 0, 38)
WindowInfo.Position = UDim2.fromOffset(0, 72)
WindowInfo.BackgroundTransparency = 1
WindowInfo.Font = Enum.Font.Gotham
WindowInfo.Text = "Không hop: --:--:-- → --:--:--"
WindowInfo.TextColor3 = Color3.fromRGB(177, 188, 202)
WindowInfo.TextSize = 12
WindowInfo.TextXAlignment = Enum.TextXAlignment.Left
WindowInfo.TextYAlignment = Enum.TextYAlignment.Top
WindowInfo.Parent = Content

local Countdown = Instance.new("TextLabel")
Countdown.Size = UDim2.new(1, 0, 0, 24)
Countdown.Position = UDim2.fromOffset(0, 111)
Countdown.BackgroundTransparency = 1
Countdown.Font = Enum.Font.GothamMedium
Countdown.Text = "Còn lại: đang tính..."
Countdown.TextColor3 = Color3.fromRGB(129, 175, 224)
Countdown.TextSize = 13
Countdown.TextXAlignment = Enum.TextXAlignment.Left
Countdown.Parent = Content

local Source = Instance.new("TextLabel")
Source.Size = UDim2.new(1, 0, 0, 34)
Source.Position = UDim2.fromOffset(0, 140)
Source.BackgroundTransparency = 1
Source.Font = Enum.Font.Gotham
Source.Text = "Source: Workspace._WorldOrigin.Locations.<Location>.@TimeIn"
Source.TextColor3 = Color3.fromRGB(142, 155, 173)
Source.TextSize = 10
Source.TextWrapped = true
Source.TextXAlignment = Enum.TextXAlignment.Left
Source.TextYAlignment = Enum.TextYAlignment.Top
Source.Parent = Content

local ServerStats = Instance.new("TextLabel")
ServerStats.Size = UDim2.new(1, 0, 0, 42)
ServerStats.Position = UDim2.fromOffset(0, 178)
ServerStats.BackgroundTransparency = 1
ServerStats.Font = Enum.Font.Code
ServerStats.Text = "JobId: " .. shortJobId(JobId)
ServerStats.TextColor3 = Color3.fromRGB(130, 146, 165)
ServerStats.TextSize = 11
ServerStats.TextWrapped = true
ServerStats.TextXAlignment = Enum.TextXAlignment.Left
ServerStats.TextYAlignment = Enum.TextYAlignment.Top
ServerStats.Parent = Content

DebugStatusLabel = Instance.new("TextLabel")
DebugStatusLabel.Size = UDim2.new(1, 0, 0, 22)
DebugStatusLabel.Position = UDim2.fromOffset(0, 220)
DebugStatusLabel.BackgroundTransparency = 1
DebugStatusLabel.Font = Enum.Font.GothamBold
DebugStatusLabel.Text = "DEBUG: chờ còn 2 phút trước mốc 4 giờ"
DebugStatusLabel.TextColor3 = Color3.fromRGB(247, 198, 89)
DebugStatusLabel.TextSize = 12
DebugStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
DebugStatusLabel.Parent = Content

DebugInfoLabel = Instance.new("TextLabel")
DebugInfoLabel.Size = UDim2.new(1, 0, 0, 34)
DebugInfoLabel.Position = UDim2.fromOffset(0, 244)
DebugInfoLabel.BackgroundTransparency = 1
DebugInfoLabel.Font = Enum.Font.Code
DebugInfoLabel.Text = "Events: 0 | File: chưa tạo file"
DebugInfoLabel.TextColor3 = Color3.fromRGB(143, 158, 178)
DebugInfoLabel.TextSize = 10
DebugInfoLabel.TextWrapped = true
DebugInfoLabel.TextXAlignment = Enum.TextXAlignment.Left
DebugInfoLabel.TextYAlignment = Enum.TextYAlignment.Top
DebugInfoLabel.Parent = Content

local HopNow = Instance.new("TextButton")
HopNow.Size = UDim2.new(0.5, -5, 0, 32)
HopNow.Position = UDim2.new(0, 0, 1, -35)
HopNow.BackgroundColor3 = Color3.fromRGB(46, 94, 139)
HopNow.BorderSizePixel = 0
HopNow.Font = Enum.Font.GothamBold
HopNow.Text = "HOP SERVER NGAY"
HopNow.TextColor3 = Color3.fromRGB(240, 247, 255)
HopNow.TextSize = 12
HopNow.Parent = Content

local HopCorner = Instance.new("UICorner")
HopCorner.CornerRadius = UDim.new(0, 7)
HopCorner.Parent = HopNow

local Release = Instance.new("TextButton")
Release.Size = UDim2.new(0.5, -5, 0, 32)
Release.Position = UDim2.new(0.5, 5, 1, -35)
Release.BackgroundColor3 = Color3.fromRGB(72, 78, 89)
Release.BorderSizePixel = 0
Release.Font = Enum.Font.GothamBold
Release.Text = "BỎ GIỮ NHÂN VẬT"
Release.TextColor3 = Color3.fromRGB(235, 239, 244)
Release.TextSize = 12
Release.Parent = Content

local ReleaseCorner = Instance.new("UICorner")
ReleaseCorner.CornerRadius = UDim.new(0, 7)
ReleaseCorner.Parent = Release

-- Drag UI
do
    local dragging = false
    local dragStart
    local startPosition

    Header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPosition = Main.Position
        end
    end)

    Header.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging then
            return
        end

        if input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input.UserInputType ~= Enum.UserInputType.Touch then
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
    Main.Size = minimized and UDim2.fromOffset(480, 42)
        or UDim2.fromOffset(480, 370)
    Minimize.Text = minimized and "+" or "—"
end)

Close.MouseButton1Click:Connect(function()
    if Debug.active then
        stopDebug("UI closed")
    end
    State.destroyed = true
    releaseHold()
    ScreenGui:Destroy()
end)

Release.MouseButton1Click:Connect(function()
    CONFIG.HoldCharacter = false
    releaseHold()
    Release.Text = "ĐÃ BỎ GIỮ NHÂN VẬT"
end)

-- ============================================================
-- FAST SERVER BROWSER
-- ============================================================
local ServerBrowser = ReplicatedStorage:WaitForChild("__ServerBrowser", 20)

local function serverPasses(data)
    if type(data) ~= "table" then
        return false
    end

    local count = tonumber(data.Count)
    if not count then
        return false
    end

    if count > CONFIG.MaxPlayers then
        return false
    end

    if CONFIG.ForcedRegion and data.Region ~= CONFIG.ForcedRegion then
        return false
    end

    return true
end

local function shuffle(array)
    for i = #array, 2, -1 do
        local j = math.random(1, i)
        array[i], array[j] = array[j], array[i]
    end
end

local function fetchServersFast()
    if not ServerBrowser then
        return {}
    end

    State.pagesScanned = 0
    State.candidatesFound = 0

    local pages = {}
    for i = 1, CONFIG.MaxPages do
        pages[i] = i
    end
    shuffle(pages)

    local results = {}
    local resultMap = {}
    local nextIndex = 1
    local finishedWorkers = 0
    local stop = false
    local deadline = os.clock() + CONFIG.BrowserTimeout

    local workerCount = math.max(
        1,
        math.min(CONFIG.ConcurrentWorkers, CONFIG.MaxPages)
    )

    local function addServer(id, data)
        if type(id) ~= "string"
            or id == ""
            or id == JobId
            or resultMap[id]
            or Visited[id] then
            return
        end

        if not serverPasses(data) then
            return
        end

        resultMap[id] = true
        table.insert(results, {
            JobId = id,
            Players = tonumber(data.Count) or 99,
            Region = data.Region,
            LastUpdate = data.__LastUpdate,
        })

        State.candidatesFound = #results

        if #results >= CONFIG.CandidateTarget then
            stop = true
        end
    end

    for _ = 1, workerCount do
        task.spawn(function()
            while not stop
                and not State.destroyed
                and os.clock() < deadline do

                local index = nextIndex
                nextIndex += 1

                local page = pages[index]
                if not page then
                    break
                end

                local ok, data = pcall(function()
                    return ServerBrowser:InvokeServer(page)
                end)

                State.pagesScanned += 1

                if ok and type(data) == "table" then
                    for id, serverData in pairs(data) do
                        addServer(id, serverData)
                    end
                end
            end

            finishedWorkers += 1
        end)
    end

    while finishedWorkers < workerCount
        and not State.destroyed
        and os.clock() < deadline do
        task.wait(0.05)
    end

    table.sort(results, function(a, b)
        if a.Players == b.Players then
            return tostring(a.JobId) < tostring(b.JobId)
        end
        return a.Players < b.Players
    end)

    return results
end

local function selectServer(servers)
    if #servers == 0 then
        return nil
    end

    local poolSize = math.min(CONFIG.BestServerPool, #servers)

    -- Uu tien nhom it nguoi nhat, sau do random trong nhom
    return servers[math.random(1, poolSize)]
end

local function updateHopStats()
    ServerStats.Text = string.format(
        "JobId: %s\nPages: %d | Candidates: %d | Hop attempt: %d",
        shortJobId(JobId),
        State.pagesScanned,
        State.candidatesFound,
        State.hopAttempt
    )
end

local HopServer

HopServer = function(reason)
    if State.hopping or State.destroyed then
        return
    end

    State.hopping = true
    State.hopAttempt += 1
    updateHopStats()

    Status.Text = "ĐANG TÌM SERVER ÍT NGƯỜI..."
    Status.TextColor3 = Color3.fromRGB(247, 198, 89)
    Countdown.Text = "Lý do: " .. tostring(reason or "Không đúng cửa sổ thời gian")

    local servers = fetchServersFast()
    local selected = selectServer(servers)

    if not selected then
        Status.Text = "KHÔNG TÌM THẤY SERVER PHÙ HỢP"
        Status.TextColor3 = Color3.fromRGB(238, 104, 104)

        if State.hopAttempt < CONFIG.MaxHopRetries then
            State.hopping = false
            task.delay(CONFIG.RetryDelay, function()
                HopServer("Retry tìm server")
            end)
            return
        end

        warn("[SERVER TIME HUNTER] Hết retry, dùng TeleportService random.")
        State.selectedJob = "RANDOM"
        markVisited(JobId)

        pcall(function()
            TeleportService:Teleport(PlaceId, LocalPlayer)
        end)

        return
    end

    State.selectedJob = selected.JobId
    State.selectedPlayers = selected.Players
    State.selectedRegion = selected.Region

    markVisited(selected.JobId)

    Status.Text = "ĐÃ CHỌN SERVER — ĐANG TELEPORT"
    Status.TextColor3 = Color3.fromRGB(110, 194, 244)

    Countdown.Text = string.format(
        "Players: %s | Region: %s | Reason: %s",
        tostring(selected.Players),
        tostring(selected.Region),
        tostring(reason or "Hop")
    )

    print(
        "[SERVER TIME HUNTER] Teleport:",
        selected.JobId,
        "| Players:", selected.Players,
        "| Region:", selected.Region,
        "| Reason:", reason
    )

    local ok, err = pcall(function()
        ServerBrowser:InvokeServer("teleport", selected.JobId)
    end)

    if not ok then
        warn("[SERVER TIME HUNTER] Invoke teleport lỗi:", err)
        State.hopping = false

        task.delay(CONFIG.RetryDelay, function()
            HopServer("Invoke teleport lỗi")
        end)
    end
end

HopNow.MouseButton1Click:Connect(function()
    if not State.hopping then
        releaseHold()
        State.matched = false
        getgenv().ServerTimeTargetFound = false
        HopServer("Người dùng bấm Hop Now")
    end
end)

-- ============================================================
-- TELEPORT ERROR HANDLING
-- ============================================================
TeleportService.TeleportInitFailed:Connect(function(
    player,
    teleportResult,
    message
)
    if player ~= LocalPlayer then
        return
    end

    warn(
        "[SERVER TIME HUNTER] TeleportInitFailed:",
        tostring(teleportResult),
        tostring(message)
    )

    State.hopping = false

    if State.selectedJob then
        Visited[State.selectedJob] = os.time()
        saveVisited()
    end

    local delayTime = CONFIG.RetryDelay

    if teleportResult == Enum.TeleportResult.GameFull then
        delayTime = 0.8
    elseif teleportResult == Enum.TeleportResult.IsTeleporting then
        delayTime = 3
    end

    task.delay(delayTime, function()
        HopServer("Retry sau TeleportInitFailed")
    end)
end)

GuiService.ErrorMessageChanged:Connect(function()
    local ok, errorType = pcall(function()
        return GuiService:GetErrorType()
    end)

    if ok and errorType == Enum.ConnectionError.DisconnectErrors then
        task.spawn(function()
            while not State.destroyed do
                pcall(function()
                    TeleportService:TeleportToPlaceInstance(
                        PlaceId,
                        JobId,
                        LocalPlayer
                    )
                end)
                task.wait(5)
            end
        end)
    end
end)

-- ============================================================
-- SAVE MATCH LOG
-- ============================================================
local function saveMatchedLog()
    if not CONFIG.SaveMatchedLog or type(writefile) ~= "function" then
        return
    end

    local content = table.concat({
        "SERVER TIME TARGET FOUND",
        "Generated: " .. os.date("%Y-%m-%d %H:%M:%S"),
        "PlaceId: " .. tostring(PlaceId),
        "JobId: " .. tostring(JobId),
        "Uptime: " .. formatDuration(State.uptime),
        "UptimeSeconds: " .. tostring(State.uptime),
        "Source: " .. tostring(State.sourcePath),
        "MatchingLocations: " .. tostring(State.sourceCount),
    }, "\n")

    pcall(function()
        writefile(
            "ServerTimeFound_" .. tostring(JobId):gsub("[^%w%-]", "_") .. ".txt",
            content
        )
    end)
end

-- ============================================================
-- MAIN
-- ============================================================
task.spawn(function()
    Status.Text = "ĐANG CHỜ TimeIn TỪ SERVER..."
    Status.TextColor3 = Color3.fromRGB(247, 198, 89)

    local startedAt, sourcePath, sourceCount =
        waitForTimeIn(CONFIG.TimeInWaitTimeout)

    if State.destroyed then
        return
    end

    if not startedAt then
        Status.Text = "KHÔNG TÌM THẤY TimeIn — SẼ HOP"
        Status.TextColor3 = Color3.fromRGB(238, 104, 104)
        Countdown.Text = "Không thể xác định uptime server hiện tại"

        task.wait(CONFIG.DecisionDelay)
        HopServer("Không tìm thấy TimeIn")
        return
    end

    State.serverStartedAt = startedAt
    State.sourcePath = sourcePath
    State.sourceCount = sourceCount

    Source.Text = string.format(
        "Source: %s | Khớp %d Location",
        tostring(sourcePath),
        sourceCount
    )

    local now = getServerNow()
    if not now then
        Status.Text = "KHÔNG ĐỌC ĐƯỢC GetServerTimeNow()"
        Status.TextColor3 = Color3.fromRGB(238, 104, 104)

        task.wait(CONFIG.DecisionDelay)
        HopServer("Không đọc được server clock")
        return
    end

    State.uptime = math.max(0, now - startedAt)
    getgenv().ServerTimeCurrentUptime = State.uptime

    local window = evaluateWindow(State.uptime)

    Timer.Text = "Server Timer: " .. formatDuration(State.uptime)
    WindowInfo.Text = string.format(
        "Không hop: %s → %s (mốc %s, mỗi %d giờ)",
        formatClock(window.targetStart),
        formatClock(window.targetEnd),
        formatClock(window.targetBoundary),
        CONFIG.PeriodHours
    )

    if window.matched then
        State.matched = true
        getgenv().ServerTimeTargetFound = true

        Status.Text = "ĐÚNG CỬA SỔ — GIỮ SERVER NÀY"
        Status.TextColor3 = Color3.fromRGB(107, 221, 159)
        Countdown.Text = "Đã tìm thấy server mục tiêu, không hop nữa."

        safeNotify(
            "Server Time Hunter",
            "Đã tìm thấy server: " .. formatDuration(State.uptime),
            8
        )

        applyHold()
        saveMatchedLog()
    else
        State.matched = false
        getgenv().ServerTimeTargetFound = false

        Status.Text = "SAI CỬA SỔ — CHUẨN BỊ HOP"
        Status.TextColor3 = Color3.fromRGB(247, 198, 89)

        Countdown.Text = "Còn "
            .. formatDuration(window.untilWindow)
            .. " mới đến cửa sổ gần nhất"

        task.wait(CONFIG.DecisionDelay)

        if not State.destroyed then
            HopServer(
                "Uptime "
                    .. formatDuration(State.uptime)
                    .. " không thuộc cửa sổ "
                    .. formatClock(window.targetStart)
                    .. "-"
                    .. formatClock(window.targetEnd)
            )
        end
    end
end)

-- Cap nhat UI lien tuc; khi matched thi ep nhan vat dung im
task.spawn(function()
    while not State.destroyed and ScreenGui.Parent do
        if State.serverStartedAt then
            local now = getServerNow()

            if now then
                State.uptime = math.max(0, now - State.serverStartedAt)
                getgenv().ServerTimeCurrentUptime = State.uptime

                local window = evaluateWindow(State.uptime)

                Timer.Text = "Server Timer: " .. formatDuration(State.uptime)

                WindowInfo.Text = string.format(
                    "Không hop: %s → %s (mốc %s, mỗi %d giờ)",
                    formatClock(window.targetStart),
                    formatClock(window.targetEnd),
                    formatClock(window.targetBoundary),
                    CONFIG.PeriodHours
                )

                if State.matched then
                    if window.matched then
                        Countdown.Text =
                            "Đang giữ server | Còn "
                            .. formatDuration(window.untilWindowEnd)
                            .. " đến hết cửa sổ"

                        if CONFIG.HoldCharacter then
                            applyHold()
                        end
                    elseif not State.hopping then
                        -- Da qua moc VD 04:20 / 08:20: bo giu va hop tiep.
                        State.matched = false
                        getgenv().ServerTimeTargetFound = false
                        releaseHold()

                        Status.Text = "ĐÃ HẾT CỬA SỔ — CHUẨN BỊ HOP"
                        Status.TextColor3 = Color3.fromRGB(247, 198, 89)
                        Countdown.Text = "Đã qua cuối cửa sổ, đang tìm server khác..."

                        task.spawn(function()
                            HopServer(
                                "Đã qua cuối cửa sổ không-hop tại "
                                    .. formatClock(window.targetEnd)
                            )
                        end)
                    end
                elseif not State.hopping then
                    Countdown.Text =
                        "Còn "
                        .. formatDuration(window.untilWindow)
                        .. " mới đến cửa sổ gần nhất"
                end
            end
        end

        updateHopStats()
        task.wait(1)
    end
end)


-- Full-window debug monitor:
-- Bat dau ghi ngay tu 03:50 va dung sau 04:20.
-- Lap lai tuong tu cho 07:50-08:20, 11:50-12:20...
task.spawn(function()
    while not State.destroyed and ScreenGui.Parent do
        if CONFIG.DebugEnabled and State.serverStartedAt then
            local active, boundary, phase, distance, window =
                getDebugWindow(State.uptime)

            if active and State.matched then
                if not Debug.active
                    and State.debugLastBoundary ~= boundary then
                    startDebug(boundary, phase)
                end

                if Debug.active then
                    if phase == "before-boundary" then
                        updateDebugLabels(
                            "DEBUG: ĐANG GHI TOÀN CỬA SỔ — CÒN "
                                .. formatDuration(distance)
                                .. " ĐẾN MỐC",
                            Color3.fromRGB(107, 221, 159)
                        )
                    else
                        updateDebugLabels(
                            "DEBUG: ĐANG GHI TOÀN CỬA SỔ — SAU MỐC "
                                .. formatDuration(distance)
                                .. " | CÒN "
                                .. formatDuration(window.untilWindowEnd),
                            Color3.fromRGB(107, 221, 159)
                        )
                    end
                end
            else
                if Debug.active then
                    stopDebug("Đã ra khỏi cửa sổ không-hop")
                elseif State.matched then
                    updateDebugLabels(
                        "DEBUG: ĐANG CHỜ KHỞI TẠO",
                        Color3.fromRGB(247, 198, 89)
                    )
                else
                    local remaining = math.max(
                        0,
                        window.targetStart - State.uptime
                    )

                    updateDebugLabels(
                        "DEBUG: CHỜ "
                            .. formatDuration(remaining)
                            .. " ĐẾN CỬA SỔ KIỂM TRA",
                        Color3.fromRGB(143, 158, 178)
                    )
                end
            end
        end

        task.wait(0.15)
    end

    if Debug.active then
        stopDebug("Script stopped")
    end
end)

-- Flush ngay truoc khi teleport bat dau neu executor phat event nay.
pcall(function()
    LocalPlayer.OnTeleport:Connect(function(teleportState)
        if Debug.active then
            debugLog("TELEPORT_STATE", tostring(teleportState))
            flushDebug(true)
        end
    end)
end)

print("[SERVER TIME HUNTER] Started")
print("[SERVER TIME HUNTER] JobId:", JobId)
print(
    "[SERVER TIME HUNTER] No-hop windows:",
    CONFIG.WindowMinutes,
    "minutes before and",
    math.floor(CONFIG.AfterBoundaryGrace / 60),
    "minutes after every",
    CONFIG.PeriodHours,
    "hours"
)
