--[[
    SERVER TIME DETECTOR / DEBUGGER (CLIENT-EXECUTOR)
    -------------------------------------------------
    Muc dich:
      * Tim tin hieu co the dai dien cho UPTIME that cua JobId/server hien tai.
      * KHONG danh dong workspace.DistributedGameTime la server uptime.
      * Quet ValueBase, Attribute, RemoteEvent va cac timestamp/counter duoc replicate.
      * Hien UI, xep hang ung vien, ghi log va cho phep copy debug.

    Luu y quan trong:
      * Script client khong the tu biet thoi diem JobId duoc tao neu game khong replicate
        timestamp/counter tu server xuong.
      * "DETECTED" chi xuat hien khi co ung vien du do tin cay.
      * InvokeServer response hook co the xung dot voi script khac, mac dinh TAT.

    Bat hook debug response RemoteFunction (tuy chon, rui ro hon):
      getgenv().ServerTimeDetectorConfig = {
          EnableInvokeResponseHook = true
      }
      -- Sau do chay file nay.
--]]

repeat task.wait() until game:IsLoaded() and game:GetService("Players").LocalPlayer

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local ENV = (getgenv and getgenv()) or _G

-- Dung ban cu neu re-run.
if type(ENV.ServerTimeDetector) == "table" and type(ENV.ServerTimeDetector.Stop) == "function" then
    pcall(ENV.ServerTimeDetector.Stop)
end

local defaults = {
    SampleInterval = 1,
    FullRescanInterval = 15,
    MaxScanObjects = 45000,
    MaxDisplayedCandidates = 10,
    MaxLogLines = 1200,
    MaxPlausibleUptime = 60 * 60 * 24 * 30, -- 30 ngay
    MinimumDisplayScore = 10,
    MinimumPossibleScore = 60,
    MinimumConfirmedScore = 82,
    LogToFile = true,
    AutoSaveLogInterval = 20,
    WatchRelevantRemoteEvents = true,
    WatchAllRemoteEvents = false,
    EnableInvokeResponseHook = false,
    ScanPlayerGui = true,
    ScanLighting = true,
    ScanWorkspace = true,
    ScanReplicatedStorage = true,
}

local Config = {}
for key, value in pairs(defaults) do
    Config[key] = value
end
if type(ENV.ServerTimeDetectorConfig) == "table" then
    for key, value in pairs(ENV.ServerTimeDetectorConfig) do
        Config[key] = value
    end
end

local Runtime = {
    Active = true,
    Connections = {},
    Candidates = {},
    CandidateOrder = {},
    RemoteSignals = {},
    Logs = {},
    Gui = nil,
    LastBest = nil,
    LastFullScan = 0,
    LastLogSave = 0,
    ObjectsScanned = 0,
    RemoteHookInstalled = false,
}
ENV.ServerTimeDetector = Runtime

local detectorStartedServerNow
local detectorStartedClock = os.clock()
local okServerNow, initialServerNow = pcall(function()
    return Workspace:GetServerTimeNow()
end)
detectorStartedServerNow = okServerNow and initialServerNow or os.time()

local keywordList = {
    "server", "uptime", "runtime", "start", "started", "created", "creation",
    "boot", "born", "age", "elapsed", "session", "time", "timer", "clock",
    "worldtime", "gametime", "serverage", "servertime", "serverstart",
    "fist", "chalice", "darkness", "spawn", "cycle"
}

local strongServerWords = {
    "serveruptime", "serverage", "serverstart", "serverstarted", "servercreated",
    "starttimestamp", "startedat", "createdat", "boottime", "serverruntime",
    "uptime", "jobstart", "jobcreated"
}

local function lower(value)
    return string.lower(tostring(value or ""))
end

local function normalizeName(value)
    return lower(value):gsub("[^%w]", "")
end

local function containsKeyword(value)
    local text = normalizeName(value)
    for _, word in ipairs(keywordList) do
        if string.find(text, normalizeName(word), 1, true) then
            return true
        end
    end
    return false
end

local function containsStrongServerWord(value)
    local text = normalizeName(value)
    for _, word in ipairs(strongServerWords) do
        if string.find(text, normalizeName(word), 1, true) then
            return true
        end
    end
    return false
end

local function safeServerNow()
    local ok, value = pcall(function()
        return Workspace:GetServerTimeNow()
    end)
    if ok and type(value) == "number" then
        return value
    end
    return os.time()
end

local function safeDistributedTime()
    local ok, value = pcall(function()
        return Workspace.DistributedGameTime
    end)
    return ok and tonumber(value) or 0
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

local function shortNumber(value)
    value = tonumber(value)
    if not value then
        return tostring(value)
    end
    if math.abs(value) >= 1000000 then
        return string.format("%.3f", value)
    end
    return string.format("%.2f", value)
end

local function safeFullName(instance)
    local ok, result = pcall(function()
        return instance:GetFullName()
    end)
    return ok and result or tostring(instance)
end

local function serialize(value, depth, seen)
    depth = depth or 0
    seen = seen or {}
    if depth > 4 then
        return "<max-depth>"
    end

    local valueType = typeof(value)
    if valueType == "string" then
        return string.format("%q", value)
    elseif valueType == "number" or valueType == "boolean" or valueType == "nil" then
        return tostring(value)
    elseif valueType == "Instance" then
        return "<" .. value.ClassName .. ":" .. safeFullName(value) .. ">"
    elseif valueType ~= "table" then
        return "<" .. valueType .. ":" .. tostring(value) .. ">"
    end

    if seen[value] then
        return "<cycle>"
    end
    seen[value] = true

    local parts = {}
    local count = 0
    for key, item in pairs(value) do
        count = count + 1
        if count > 80 then
            table.insert(parts, "...")
            break
        end
        table.insert(parts, "[" .. serialize(key, depth + 1, seen) .. "]=" .. serialize(item, depth + 1, seen))
    end
    seen[value] = nil
    return "{" .. table.concat(parts, ",") .. "}"
end

local function log(message)
    if not Runtime.Active then
        return
    end
    local stamp = os.date("%H:%M:%S")
    local line = "[" .. stamp .. "] " .. tostring(message)
    table.insert(Runtime.Logs, line)
    while #Runtime.Logs > Config.MaxLogLines do
        table.remove(Runtime.Logs, 1)
    end
    print("[ServerTimeDetector] " .. tostring(message))
end

local function logFileName()
    local job = tostring(game.JobId or "unknown"):gsub("[^%w%-_]", "_")
    return "ServerTimeDetector_" .. job .. ".txt"
end

local function buildDebugDump()
    local lines = {
        "SERVER TIME DETECTOR DEBUG",
        "Generated: " .. os.date("%Y-%m-%d %H:%M:%S"),
        "PlaceId: " .. tostring(game.PlaceId),
        "JobId: " .. tostring(game.JobId),
        "Player: " .. tostring(LocalPlayer.Name),
        "Detector session: " .. formatDuration(safeServerNow() - detectorStartedServerNow),
        "DistributedGameTime(client): " .. formatDuration(safeDistributedTime()),
        "GetServerTimeNow: " .. tostring(safeServerNow()),
        "Objects scanned: " .. tostring(Runtime.ObjectsScanned),
        "Candidates: " .. tostring(#Runtime.CandidateOrder),
        "",
        "TOP CANDIDATES:",
    }

    local sorted = {}
    for _, candidate in pairs(Runtime.Candidates) do
        if candidate.LastNumeric ~= nil then
            table.insert(sorted, candidate)
        end
    end
    table.sort(sorted, function(a, b)
        if (a.Score or 0) == (b.Score or 0) then
            return tostring(a.Path) < tostring(b.Path)
        end
        return (a.Score or 0) > (b.Score or 0)
    end)

    for index, candidate in ipairs(sorted) do
        if index > 40 then
            break
        end
        table.insert(lines, string.format(
            "#%d score=%d class=%s value=%s rate=%s uptime=%s source=%s path=%s",
            index,
            math.floor(candidate.Score or 0),
            tostring(candidate.Classification or "unknown"),
            shortNumber(candidate.LastNumeric),
            shortNumber(candidate.Rate or 0),
            candidate.UptimeEstimate and formatDuration(candidate.UptimeEstimate) or "n/a",
            tostring(candidate.Source),
            tostring(candidate.Path)
        ))
    end

    table.insert(lines, "")
    table.insert(lines, "LOG:")
    for _, line in ipairs(Runtime.Logs) do
        table.insert(lines, line)
    end

    return table.concat(lines, "\n")
end

local function saveLog(force)
    if not Config.LogToFile and not force then
        return false, "LogToFile disabled"
    end
    if type(writefile) ~= "function" then
        return false, "writefile unsupported"
    end
    local ok, err = pcall(function()
        writefile(logFileName(), buildDebugDump())
    end)
    if ok then
        Runtime.LastLogSave = os.clock()
        return true, logFileName()
    end
    return false, tostring(err)
end

local function parseDurationString(text)
    if type(text) ~= "string" then
        return nil
    end

    local stripped = text:gsub(",", ""):gsub("%s+", " ")
    local numberOnly = tonumber(stripped)
    if numberOnly then
        return numberOnly
    end

    local d, h, m, s = stripped:match("(%d+)%s*[dD].-(%d+)%s*[hH].-(%d+)%s*[mM].-(%d+)%s*[sS]")
    if d then
        return tonumber(d) * 86400 + tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(s)
    end

    h, m, s = stripped:match("(%d+)%s*[hH].-(%d+)%s*[mM].-(%d+)%s*[sS]")
    if h then
        return tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(s)
    end

    h, m, s = stripped:match("(%d+):(%d+):(%d+)")
    if h then
        return tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(s)
    end

    m, s = stripped:match("(%d+):(%d+)")
    if m then
        return tonumber(m) * 60 + tonumber(s)
    end

    return nil
end

local function numericFromValue(value)
    if type(value) == "number" then
        return value, "number"
    elseif type(value) == "string" then
        local parsed = parseDurationString(value)
        if parsed then
            return parsed, "string-duration"
        end
    end
    return nil, nil
end

local function isPlausibleTimestamp(value)
    local now = safeServerNow()
    if value > 1000000000000 and value < 9999999999999 then
        local seconds = value / 1000
        return math.abs(now - seconds) < 60 * 60 * 24 * 365 * 15
    end
    if value > 1000000000 and value < 9999999999 then
        return math.abs(now - value) < 60 * 60 * 24 * 365 * 15
    end
    return false
end

local function candidateKey(source, path)
    return tostring(source) .. "|" .. tostring(path)
end

local function registerCandidate(source, path, reader, initialValue)
    local key = candidateKey(source, path)
    local existing = Runtime.Candidates[key]
    if existing then
        if reader then
            existing.Reader = reader
        end
        if initialValue ~= nil then
            existing.LastRaw = initialValue
        end
        return existing
    end

    local candidate = {
        Key = key,
        Source = source,
        Path = path,
        Reader = reader,
        FirstRaw = initialValue,
        LastRaw = initialValue,
        FirstNumeric = nil,
        LastNumeric = nil,
        LastSampleClock = nil,
        Rate = 0,
        RateSamples = 0,
        Score = 0,
        Classification = "new",
        UptimeEstimate = nil,
        ValueKind = nil,
        StableSamples = 0,
        IncreasingSamples = 0,
        DecreasingSamples = 0,
        SeenAt = safeServerNow(),
        LastLoggedClass = nil,
    }
    Runtime.Candidates[key] = candidate
    table.insert(Runtime.CandidateOrder, key)
    log("Candidate found: " .. tostring(source) .. " -> " .. tostring(path))
    return candidate
end

local function evaluateCandidate(candidate, numeric, valueKind, sampleClock)
    local previous = candidate.LastNumeric
    local previousClock = candidate.LastSampleClock
    local rate = candidate.Rate or 0

    if candidate.FirstNumeric == nil then
        candidate.FirstNumeric = numeric
    end

    if previous ~= nil and previousClock ~= nil then
        local dt = sampleClock - previousClock
        if dt > 0.05 then
            local instantRate = (numeric - previous) / dt
            candidate.RateSamples = math.min((candidate.RateSamples or 0) + 1, 30)
            local alpha = candidate.RateSamples <= 3 and 0.55 or 0.25
            rate = rate * (1 - alpha) + instantRate * alpha
            candidate.Rate = rate

            if math.abs(instantRate) <= 0.08 then
                candidate.StableSamples = candidate.StableSamples + 1
            elseif instantRate >= 0.65 and instantRate <= 1.35 then
                candidate.IncreasingSamples = candidate.IncreasingSamples + 1
            elseif instantRate <= -0.65 and instantRate >= -1.35 then
                candidate.DecreasingSamples = candidate.DecreasingSamples + 1
            end
        end
    end

    candidate.LastNumeric = numeric
    candidate.LastSampleClock = sampleClock
    candidate.ValueKind = valueKind
    candidate.UptimeEstimate = nil

    local pathText = lower(candidate.Path)
    local normalizedPath = normalizeName(candidate.Path)
    local relevantName = containsKeyword(pathText)
    local strongName = containsStrongServerWord(pathText)
    local isDistributed = string.find(normalizedPath, "distributedgametime", 1, true) ~= nil
    local now = safeServerNow()
    local distributed = safeDistributedTime()
    local maxUptime = Config.MaxPlausibleUptime
    local score = 0
    local classification = "unknown numeric value"

    local unixSeconds
    local timestampKind
    if numeric > 1000000000000 and numeric < 9999999999999 then
        unixSeconds = numeric / 1000
        timestampKind = "unix-ms"
    elseif numeric > 1000000000 and numeric < 9999999999 then
        unixSeconds = numeric
        timestampKind = "unix-seconds"
    end

    if unixSeconds then
        local age = now - unixSeconds
        local movingLikeClock = candidate.RateSamples >= 2 and rate >= 0.65 and rate <= 1.35

        if movingLikeClock then
            classification = "current synchronized clock (not uptime)"
            score = relevantName and 18 or 8
        elseif age >= 0 and age <= maxUptime then
            candidate.UptimeEstimate = age
            classification = "possible server start timestamp (" .. timestampKind .. ")"
            if strongName then
                score = 96
            elseif relevantName then
                score = 82
            else
                score = 62
            end
            if candidate.StableSamples >= 3 then
                score = math.min(100, score + 4)
            end
        else
            classification = "timestamp, but implausible as current server start"
            score = relevantName and 20 or 5
        end
    elseif isDistributed then
        candidate.UptimeEstimate = numeric
        classification = "client-connected timer (DistributedGameTime; not confirmed server uptime)"
        score = 8
    elseif candidate.RateSamples >= 2 and rate >= 0.68 and rate <= 1.32 then
        candidate.UptimeEstimate = numeric

        if strongName then
            classification = "server uptime-like increasing counter"
            score = 88
        elseif relevantName and numeric > distributed + 8 then
            classification = "possible replicated server-age counter"
            score = 72
        elseif relevantName and math.abs(numeric - distributed) <= 6 then
            classification = "likely client/play timer (matches DistributedGameTime)"
            score = 20
        elseif relevantName then
            classification = "generic increasing timer; needs verification"
            score = 52
        else
            classification = "increasing counter without server-time name"
            score = numeric > distributed + 8 and 42 or 18
        end

        if candidate.IncreasingSamples >= 5 then
            score = math.min(100, score + 4)
        end
    elseif candidate.RateSamples >= 2 and rate <= -0.68 and rate >= -1.32 then
        classification = "countdown decreasing about 1/sec (not uptime)"
        score = relevantName and 25 or 8
    elseif candidate.StableSamples >= 2 then
        classification = "stable numeric value"
        score = strongName and 38 or (relevantName and 18 or 4)
    else
        classification = "collecting samples"
        score = strongName and 30 or (relevantName and 12 or 2)
    end

    -- Gia tri qua lon/qua nho khong hop ly voi uptime counter.
    if candidate.UptimeEstimate and candidate.UptimeEstimate > maxUptime then
        candidate.UptimeEstimate = nil
        score = math.min(score, 25)
        classification = classification .. " [outside configured range]"
    end

    candidate.Score = score
    candidate.Classification = classification

    if candidate.LastLoggedClass ~= classification then
        candidate.LastLoggedClass = classification
        log(string.format(
            "Classified [%d%%] %s -> %s",
            math.floor(score),
            tostring(candidate.Path),
            classification
        ))
    end
end

local function sampleCandidate(candidate)
    local raw
    if type(candidate.Reader) == "function" then
        local ok, result = pcall(candidate.Reader)
        if not ok then
            return
        end
        raw = result
    else
        raw = candidate.LastRaw
    end

    candidate.LastRaw = raw
    local numeric, kind = numericFromValue(raw)
    if numeric == nil then
        return
    end
    evaluateCandidate(candidate, numeric, kind, os.clock())
end

local function shouldRegisterValue(path, value)
    if containsKeyword(path) then
        return true
    end
    local numeric = numericFromValue(value)
    if numeric and isPlausibleTimestamp(numeric) then
        return true
    end
    return false
end

local function inspectPayload(prefix, payload, depth, visited)
    depth = depth or 0
    visited = visited or {}
    if depth > 4 then
        return
    end

    local payloadType = typeof(payload)
    if payloadType == "number" or payloadType == "string" then
        if shouldRegisterValue(prefix, payload) then
            local signalKey = prefix
            Runtime.RemoteSignals[signalKey] = payload
            registerCandidate("RemoteSignal", signalKey, function()
                return Runtime.RemoteSignals[signalKey]
            end, payload)
            log("Remote time-like signal: " .. signalKey .. " = " .. tostring(payload))
        end
        return
    elseif payloadType ~= "table" then
        return
    end

    if visited[payload] then
        return
    end
    visited[payload] = true

    local count = 0
    for key, value in pairs(payload) do
        count = count + 1
        if count > 120 then
            break
        end
        local childPath = prefix .. "." .. tostring(key)
        inspectPayload(childPath, value, depth + 1, visited)
    end

    visited[payload] = nil
end

local function connect(connection)
    table.insert(Runtime.Connections, connection)
    return connection
end

local function watchRemoteEvent(remote)
    local path = safeFullName(remote)
    local watch = Config.WatchAllRemoteEvents or containsKeyword(path)
    if not Config.WatchRelevantRemoteEvents or not watch then
        return
    end
    if remote:GetAttribute("__STD_WATCHED") then
        return
    end
    pcall(function()
        remote:SetAttribute("__STD_WATCHED", true)
    end)

    connect(remote.OnClientEvent:Connect(function(...)
        local args = table.pack(...)
        log("OnClientEvent: " .. path .. " args=" .. serialize(args))
        inspectPayload("OnClientEvent:" .. path, args)
    end))
end

local function inspectInstance(instance)
    if not Runtime.Active then
        return
    end

    Runtime.ObjectsScanned = Runtime.ObjectsScanned + 1
    local path = safeFullName(instance)

    if instance:IsA("NumberValue") or instance:IsA("IntValue") or instance:IsA("StringValue") then
        local ok, currentValue = pcall(function()
            return instance.Value
        end)
        if ok and shouldRegisterValue(path, currentValue) then
            registerCandidate("ValueBase", path, function()
                if instance.Parent == nil then
                    return nil
                end
                return instance.Value
            end, currentValue)
        end
    elseif instance:IsA("RemoteEvent") then
        watchRemoteEvent(instance)
    end

    local okAttributes, attributes = pcall(function()
        return instance:GetAttributes()
    end)
    if okAttributes then
        for attributeName, attributeValue in pairs(attributes) do
            local attributePath = path .. ".@" .. tostring(attributeName)
            if shouldRegisterValue(attributePath, attributeValue) then
                registerCandidate("Attribute", attributePath, function()
                    if instance.Parent == nil and instance ~= game then
                        return nil
                    end
                    return instance:GetAttribute(attributeName)
                end, attributeValue)
            end
        end
    end
end

local roots = {}
if Config.ScanWorkspace then
    table.insert(roots, Workspace)
end
if Config.ScanReplicatedStorage then
    table.insert(roots, ReplicatedStorage)
end
if Config.ScanLighting then
    table.insert(roots, Lighting)
end
if Config.ScanPlayerGui and LocalPlayer:FindFirstChild("PlayerGui") then
    table.insert(roots, LocalPlayer.PlayerGui)
end

-- Them cac gia tri he thong vao bang debug. DistributedGameTime bi ha diem co chu dich.
registerCandidate("BuiltIn", "Workspace.DistributedGameTime", function()
    return safeDistributedTime()
end, safeDistributedTime())

registerCandidate("BuiltIn", "Workspace.GetServerTimeNow()", function()
    return safeServerNow()
end, safeServerNow())

local function fullScan()
    if not Runtime.Active then
        return
    end

    Runtime.LastFullScan = os.clock()
    Runtime.ObjectsScanned = 0
    log("Starting full scan...")

    for _, root in ipairs(roots) do
        inspectInstance(root)
        local ok, descendants = pcall(function()
            return root:GetDescendants()
        end)
        if ok then
            for index, instance in ipairs(descendants) do
                if not Runtime.Active then
                    return
                end
                if Runtime.ObjectsScanned >= Config.MaxScanObjects then
                    log("Scan object limit reached: " .. tostring(Config.MaxScanObjects))
                    break
                end
                inspectInstance(instance)
                if index % 600 == 0 then
                    task.wait()
                end
            end
        end
    end

    log("Full scan complete. Objects=" .. tostring(Runtime.ObjectsScanned) .. " Candidates=" .. tostring(#Runtime.CandidateOrder))
end

local function installDescendantWatchers()
    for _, root in ipairs(roots) do
        connect(root.DescendantAdded:Connect(function(instance)
            task.defer(function()
                inspectInstance(instance)
            end)
        end))
    end
end

local function installInvokeResponseHook()
    if not Config.EnableInvokeResponseHook then
        return
    end
    if Runtime.RemoteHookInstalled then
        return
    end
    if type(hookmetamethod) ~= "function" or type(getnamecallmethod) ~= "function" or type(newcclosure) ~= "function" then
        log("Invoke response hook unsupported by executor.")
        return
    end

    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if Runtime.Active and method == "InvokeServer" and typeof(self) == "Instance" and self:IsA("RemoteFunction") then
            local packed = table.pack(oldNamecall(self, ...))
            local remotePath = safeFullName(self)
            task.defer(function()
                log("InvokeServer response: " .. remotePath .. " => " .. serialize(packed))
                inspectPayload("InvokeResponse:" .. remotePath, packed)
            end)
            return table.unpack(packed, 1, packed.n)
        end
        return oldNamecall(self, ...)
    end))

    Runtime.RemoteHookInstalled = true
    log("InvokeServer response hook ENABLED. It cannot be cleanly unhooked on every executor.")
end

local function sortedCandidates()
    local result = {}
    for _, candidate in pairs(Runtime.Candidates) do
        if candidate.LastNumeric ~= nil and (candidate.Score or 0) >= Config.MinimumDisplayScore then
            table.insert(result, candidate)
        end
    end
    table.sort(result, function(a, b)
        if (a.Score or 0) == (b.Score or 0) then
            if (a.UptimeEstimate ~= nil) ~= (b.UptimeEstimate ~= nil) then
                return a.UptimeEstimate ~= nil
            end
            return tostring(a.Path) < tostring(b.Path)
        end
        return (a.Score or 0) > (b.Score or 0)
    end)
    return result
end

local function selectBestCandidate()
    local candidates = sortedCandidates()
    for _, candidate in ipairs(candidates) do
        if candidate.UptimeEstimate and (candidate.Score or 0) >= Config.MinimumPossibleScore then
            return candidate
        end
    end
    return nil
end

local function create(className, properties, parent)
    local object = Instance.new(className)
    for key, value in pairs(properties or {}) do
        object[key] = value
    end
    object.Parent = parent
    return object
end

local function addCorner(parent, radius)
    return create("UICorner", {
        CornerRadius = UDim.new(0, radius or 6)
    }, parent)
end

local function addStroke(parent, transparency)
    return create("UIStroke", {
        Color = Color3.fromRGB(72, 82, 105),
        Thickness = 1,
        Transparency = transparency or 0.25,
    }, parent)
end

local guiParent
local okGuiParent, resolvedParent = pcall(function()
    if type(gethui) == "function" then
        return gethui()
    end
    return CoreGui
end)
guiParent = okGuiParent and resolvedParent or LocalPlayer:WaitForChild("PlayerGui")

pcall(function()
    local oldGui = guiParent:FindFirstChild("ServerTimeDetectorUI")
    if oldGui then
        oldGui:Destroy()
    end
end)

local ScreenGui = create("ScreenGui", {
    Name = "ServerTimeDetectorUI",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset = false,
}, guiParent)
Runtime.Gui = ScreenGui

pcall(function()
    if syn and syn.protect_gui then
        syn.protect_gui(ScreenGui)
    end
end)

local Main = create("Frame", {
    Name = "Main",
    Size = UDim2.fromOffset(680, 520),
    Position = UDim2.new(0.5, -340, 0.5, -260),
    BackgroundColor3 = Color3.fromRGB(17, 20, 28),
    BorderSizePixel = 0,
    ClipsDescendants = true,
}, ScreenGui)
addCorner(Main, 10)
addStroke(Main, 0.05)

local TitleBar = create("Frame", {
    Name = "TitleBar",
    Size = UDim2.new(1, 0, 0, 42),
    BackgroundColor3 = Color3.fromRGB(27, 31, 43),
    BorderSizePixel = 0,
    Active = true,
}, Main)

local Title = create("TextLabel", {
    Size = UDim2.new(1, -100, 1, 0),
    Position = UDim2.fromOffset(14, 0),
    BackgroundTransparency = 1,
    Text = "SERVER TIME DETECTOR / DEBUGGER",
    TextColor3 = Color3.fromRGB(235, 239, 248),
    TextSize = 16,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
}, TitleBar)

local MinimizeButton = create("TextButton", {
    Size = UDim2.fromOffset(34, 28),
    Position = UDim2.new(1, -76, 0, 7),
    BackgroundColor3 = Color3.fromRGB(44, 50, 68),
    BorderSizePixel = 0,
    Text = "—",
    TextColor3 = Color3.fromRGB(235, 239, 248),
    TextSize = 18,
    Font = Enum.Font.GothamBold,
}, TitleBar)
addCorner(MinimizeButton, 6)

local CloseButton = create("TextButton", {
    Size = UDim2.fromOffset(34, 28),
    Position = UDim2.new(1, -38, 0, 7),
    BackgroundColor3 = Color3.fromRGB(95, 42, 48),
    BorderSizePixel = 0,
    Text = "X",
    TextColor3 = Color3.fromRGB(255, 235, 235),
    TextSize = 14,
    Font = Enum.Font.GothamBold,
}, TitleBar)
addCorner(CloseButton, 6)

local Body = create("Frame", {
    Name = "Body",
    Size = UDim2.new(1, 0, 1, -42),
    Position = UDim2.fromOffset(0, 42),
    BackgroundTransparency = 1,
}, Main)

local Summary = create("Frame", {
    Size = UDim2.new(1, -20, 0, 158),
    Position = UDim2.fromOffset(10, 10),
    BackgroundColor3 = Color3.fromRGB(23, 27, 37),
    BorderSizePixel = 0,
}, Body)
addCorner(Summary, 8)
addStroke(Summary, 0.5)

local DetectionStatus = create("TextLabel", {
    Size = UDim2.new(1, -20, 0, 28),
    Position = UDim2.fromOffset(10, 8),
    BackgroundTransparency = 1,
    Text = "Scanning...",
    TextColor3 = Color3.fromRGB(255, 207, 104),
    TextSize = 17,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
}, Summary)

local UptimeLabel = create("TextLabel", {
    Size = UDim2.new(1, -20, 0, 30),
    Position = UDim2.fromOffset(10, 36),
    BackgroundTransparency = 1,
    Text = "Server uptime: chua detect",
    TextColor3 = Color3.fromRGB(235, 239, 248),
    TextSize = 20,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
}, Summary)

local SourceLabel = create("TextLabel", {
    Size = UDim2.new(1, -20, 0, 36),
    Position = UDim2.fromOffset(10, 68),
    BackgroundTransparency = 1,
    Text = "Source: -",
    TextColor3 = Color3.fromRGB(174, 184, 205),
    TextSize = 13,
    Font = Enum.Font.Gotham,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
}, Summary)

local BaselineLabel = create("TextLabel", {
    Size = UDim2.new(1, -20, 0, 46),
    Position = UDim2.fromOffset(10, 106),
    BackgroundTransparency = 1,
    Text = "",
    TextColor3 = Color3.fromRGB(148, 159, 183),
    TextSize = 12,
    Font = Enum.Font.Code,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
}, Summary)

local CandidateHeader = create("TextLabel", {
    Size = UDim2.new(1, -20, 0, 26),
    Position = UDim2.fromOffset(10, 176),
    BackgroundTransparency = 1,
    Text = "TOP SIGNALS / CANDIDATES",
    TextColor3 = Color3.fromRGB(213, 220, 236),
    TextSize = 13,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
}, Body)

local CandidateFrame = create("ScrollingFrame", {
    Size = UDim2.new(1, -20, 1, -260),
    Position = UDim2.fromOffset(10, 204),
    BackgroundColor3 = Color3.fromRGB(13, 16, 23),
    BorderSizePixel = 0,
    ScrollBarThickness = 6,
    CanvasSize = UDim2.fromOffset(0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, Body)
addCorner(CandidateFrame, 8)
addStroke(CandidateFrame, 0.55)

local CandidateText = create("TextLabel", {
    Size = UDim2.new(1, -16, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    Position = UDim2.fromOffset(8, 8),
    BackgroundTransparency = 1,
    Text = "Waiting for samples...",
    TextColor3 = Color3.fromRGB(185, 194, 214),
    TextSize = 12,
    Font = Enum.Font.Code,
    TextWrapped = false,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
}, CandidateFrame)

local Buttons = create("Frame", {
    Size = UDim2.new(1, -20, 0, 42),
    Position = UDim2.new(0, 10, 1, -50),
    BackgroundTransparency = 1,
}, Body)

local ButtonLayout = create("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    HorizontalAlignment = Enum.HorizontalAlignment.Left,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    Padding = UDim.new(0, 8),
}, Buttons)

local function makeButton(text, width)
    local button = create("TextButton", {
        Size = UDim2.fromOffset(width or 130, 34),
        BackgroundColor3 = Color3.fromRGB(39, 46, 63),
        BorderSizePixel = 0,
        Text = text,
        TextColor3 = Color3.fromRGB(231, 236, 247),
        TextSize = 12,
        Font = Enum.Font.GothamBold,
    }, Buttons)
    addCorner(button, 7)
    return button
end

local ScanButton = makeButton("SCAN NOW", 110)
local CopyButton = makeButton("COPY DEBUG", 125)
local SaveButton = makeButton("SAVE LOG", 110)
local HookStatusButton = makeButton(Config.EnableInvokeResponseHook and "INVOKE HOOK: ON" or "INVOKE HOOK: OFF", 145)

-- Drag window.
do
    local dragging = false
    local dragStart
    local startPosition

    connect(TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPosition = Main.Position
        end
    end))

    connect(TitleBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))

    connect(game:GetService("UserInputService").InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            Main.Position = UDim2.new(
                startPosition.X.Scale,
                startPosition.X.Offset + delta.X,
                startPosition.Y.Scale,
                startPosition.Y.Offset + delta.Y
            )
        end
    end))
end

local minimized = false
MinimizeButton.MouseButton1Click:Connect(function()
    minimized = not minimized
    Body.Visible = not minimized
    Main.Size = minimized and UDim2.fromOffset(680, 42) or UDim2.fromOffset(680, 520)
    MinimizeButton.Text = minimized and "+" or "—"
end)

local function stopRuntime()
    if not Runtime.Active then
        return
    end
    Runtime.Active = false
    pcall(function()
        saveLog(true)
    end)
    for _, connection in ipairs(Runtime.Connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    Runtime.Connections = {}
    if Runtime.Gui then
        pcall(function()
            Runtime.Gui:Destroy()
        end)
    end
    print("[ServerTimeDetector] stopped")
end
Runtime.Stop = stopRuntime

CloseButton.MouseButton1Click:Connect(stopRuntime)

ScanButton.MouseButton1Click:Connect(function()
    task.spawn(fullScan)
end)

CopyButton.MouseButton1Click:Connect(function()
    local dump = buildDebugDump()
    if type(setclipboard) == "function" then
        local ok = pcall(setclipboard, dump)
        CopyButton.Text = ok and "COPIED" or "COPY FAILED"
    else
        CopyButton.Text = "NO CLIPBOARD"
    end
    task.delay(1.5, function()
        if CopyButton.Parent then
            CopyButton.Text = "COPY DEBUG"
        end
    end)
end)

SaveButton.MouseButton1Click:Connect(function()
    local ok, result = saveLog(true)
    SaveButton.Text = ok and "SAVED" or "SAVE FAILED"
    log((ok and "Log saved: " or "Log save failed: ") .. tostring(result))
    task.delay(1.5, function()
        if SaveButton.Parent then
            SaveButton.Text = "SAVE LOG"
        end
    end)
end)

HookStatusButton.MouseButton1Click:Connect(function()
    if Config.EnableInvokeResponseHook then
        HookStatusButton.Text = Runtime.RemoteHookInstalled and "HOOK ACTIVE" or "HOOK UNSUPPORTED"
    else
        HookStatusButton.Text = "EDIT CONFIG TO ENABLE"
    end
    task.delay(1.8, function()
        if HookStatusButton.Parent then
            HookStatusButton.Text = Config.EnableInvokeResponseHook and "INVOKE HOOK: ON" or "INVOKE HOOK: OFF"
        end
    end)
end)

local function updateUI()
    if not Runtime.Active or not ScreenGui.Parent then
        return
    end

    local best = selectBestCandidate()
    Runtime.LastBest = best

    if best then
        local score = math.floor(best.Score or 0)
        if score >= Config.MinimumConfirmedScore then
            DetectionStatus.Text = "DETECTED — HIGH CONFIDENCE (" .. score .. "%)"
            DetectionStatus.TextColor3 = Color3.fromRGB(99, 224, 146)
        else
            DetectionStatus.Text = "POSSIBLE SERVER TIME SIGNAL (" .. score .. "%)"
            DetectionStatus.TextColor3 = Color3.fromRGB(255, 207, 104)
        end
        UptimeLabel.Text = "Server uptime estimate: " .. formatDuration(best.UptimeEstimate)
        SourceLabel.Text = "Source: " .. tostring(best.Source) .. " | " .. tostring(best.Path) .. "\nClass: " .. tostring(best.Classification)
    else
        DetectionStatus.Text = "NOT FOUND — GAME MAY NOT REPLICATE SERVER START/UPTIME"
        DetectionStatus.TextColor3 = Color3.fromRGB(244, 126, 126)
        UptimeLabel.Text = "Server uptime: chua detect duoc"
        SourceLabel.Text = "DistributedGameTime van duoc hien de doi chieu, nhung khong duoc coi la uptime that o client."
    end

    BaselineLabel.Text = string.format(
        "JobId: %s\nClient connected (DistributedGameTime): %s | Detector running: %s | Server clock: %.3f",
        tostring(game.JobId),
        formatDuration(safeDistributedTime()),
        formatDuration(safeServerNow() - detectorStartedServerNow),
        safeServerNow()
    )

    local lines = {}
    local candidates = sortedCandidates()
    for index, candidate in ipairs(candidates) do
        if index > Config.MaxDisplayedCandidates then
            break
        end
        local uptimeText = candidate.UptimeEstimate and formatDuration(candidate.UptimeEstimate) or "n/a"
        table.insert(lines, string.format(
            "[%02d] SCORE %3d%% | value=%-14s | rate=%7s/s | uptime=%s\n     %s\n     %s\n",
            index,
            math.floor(candidate.Score or 0),
            shortNumber(candidate.LastNumeric),
            shortNumber(candidate.Rate or 0),
            uptimeText,
            tostring(candidate.Classification),
            tostring(candidate.Path)
        ))
    end

    if #lines == 0 then
        CandidateText.Text = "No time-like signals yet. Full scan and sampling are still running..."
    else
        CandidateText.Text = table.concat(lines, "\n")
    end
end

Runtime.GetBest = function()
    return selectBestCandidate()
end
Runtime.Dump = buildDebugDump
Runtime.Rescan = function()
    task.spawn(fullScan)
end
Runtime.SaveLog = function()
    return saveLog(true)
end

installDescendantWatchers()
installInvokeResponseHook()

-- Quet lan dau trong task rieng de UI hien ngay.
task.spawn(fullScan)

-- Sampling/update loop.
task.spawn(function()
    while Runtime.Active do
        local sampleStart = os.clock()
        for _, key in ipairs(Runtime.CandidateOrder) do
            local candidate = Runtime.Candidates[key]
            if candidate then
                sampleCandidate(candidate)
            end
        end

        updateUI()

        if os.clock() - Runtime.LastFullScan >= Config.FullRescanInterval then
            task.spawn(fullScan)
        end

        if Config.LogToFile and os.clock() - Runtime.LastLogSave >= Config.AutoSaveLogInterval then
            saveLog(false)
        end

        local spent = os.clock() - sampleStart
        task.wait(math.max(0.05, Config.SampleInterval - spent))
    end
end)

log("Detector started. PlaceId=" .. tostring(game.PlaceId) .. " JobId=" .. tostring(game.JobId))
log("IMPORTANT: DistributedGameTime is shown only as a client baseline, not accepted as true server uptime.")
