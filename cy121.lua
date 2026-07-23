-- EDIT KEY HERE, THEN EXECUTE THIS FILE DIRECTLY.
getgenv = getgenv or function() return _G end
local __env = getgenv()
if __env.Key == nil then
    __env.Key = "PUT_BANANA_KEY_HERE"
end

-- ============================================================
-- EXECUTOR / STARTUP COMPATIBILITY BOOTSTRAP
-- Prevents early "attempt to call a nil value" crashes.
-- ============================================================
getgenv = getgenv or function()
    return _G
end

local ENV = getgenv()
local unpackArgs = unpack or table.unpack
unpack = unpackArgs
cloneref = cloneref or clonereference or function(value)
    return value
end
isnetworkowner = isnetworkowner or isNetworkOwner or function()
    return true
end
newcclosure = newcclosure or function(callback)
    return callback
end
local compileSource = loadstring or load
local safeWarn = warn or print

local function SafeHttpGet(url)
    if type(url) ~= "string" or url == "" then
        return false, "invalid_url"
    end

    local ok, body = pcall(function()
        return game:HttpGet(url)
    end)
    if ok and type(body) == "string" and body ~= "" then
        return true, body
    end

    local requestFunction = nil
    if type(request) == "function" then
        requestFunction = request
    elseif type(http_request) == "function" then
        requestFunction = http_request
    elseif type(syn) == "table" and type(syn.request) == "function" then
        requestFunction = syn.request
    end

    if requestFunction then
        local requestOk, response = pcall(requestFunction, {
            Url = url,
            Method = "GET",
        })
        if requestOk and type(response) == "table" then
            local responseBody = response.Body or response.body
            if type(responseBody) == "string" and responseBody ~= "" then
                return true, responseBody
            end
            return false, tostring(response.StatusMessage or response.status_message or response.StatusCode or "empty_response")
        end
        return false, tostring(response)
    end

    return false, tostring(body or "HttpGet/request unavailable")
end

local function SafeNotify(title, text, duration)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = tostring(title or "Script"),
            Text = tostring(text or ""),
            Duration = tonumber(duration) or 5,
        })
    end)
end

local DEFAULT_SETTINGS = {
    ["Max Chests"] = 50,
    ["Skip Chest Delay"] = 1,
    ["Reset After Collect Chests"] = 7,
    ["Katakuri Progress"] = 100,
    ["Fragments"] = 1000,
    ["Black Screen"] = false,
    ["Chest Tween Speed"] = 325,
    ["Chest Touch Radius"] = 8,
    ["Chest Server Period"] = 4 * 60 * 60,
    ["Chest Server Grace"] = 2 * 60 * 60,
}

ENV.Settings = type(ENV.Settings) == "table" and ENV.Settings or {}
for key, value in pairs(DEFAULT_SETTINGS) do
    if ENV.Settings[key] == nil then
        ENV.Settings[key] = value
    end
end

repeat task.wait(0.5) until game:IsLoaded()
    and game:GetService("Players").LocalPlayer
    and game:GetService("Players").LocalPlayer:FindFirstChildWhichIsA("PlayerGui")

if ENV.WARCLOADER then
    SafeNotify("Execution Blocked", "The script is already running. Please wait 10 seconds", 5)
    return
end
ENV.WARCLOADER = true
task.delay(10, function()
    ENV.WARCLOADER = nil
end)

ENV.cloneref = cloneref
ENV.isnetworkowner = isnetworkowner

local WorkspaceService = game:GetService("Workspace")
workspace = cloneref(WorkspaceService)
PlaceId, JobId = game.PlaceId, game.JobId
getfenv = getfenv or function()
    return _G
end
IsOnMobile = false
Services = setmetatable({}, {__index = function(self, name)
    local success, service = pcall(function()
        return cloneref(game:GetService(name))
    end)
    if success and service then
        rawset(self, name, service)
        return service
    end
    error("Invalid Roblox Service: " .. tostring(name))
end})
COREGUI = Services.CoreGui
RunService = Services.RunService
VirtualUser = Services.VirtualUser
TweenService = Services.TweenService
HttpService = Services.HttpService
Players = Services.Players
ReplicatedStorage = Services.ReplicatedStorage
Lighting = Services.Lighting
CollectionService = Services.CollectionService
UserInputService = Services.UserInputService
VirtualInputManager = Services.VirtualInputManager
ReplicatedFirst = Services.ReplicatedFirst
StarterGui = Services.StarterGui
GuiService = Services.GuiService
TeleportService = Services.TeleportService
COMMF_ = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_")
LocalPlayer = Players.LocalPlayer
LocalPlayer.CharacterAdded:Connect(function(character)
    Character = character
    Humanoid = character:WaitForChild("Humanoid")
    HumanoidRootPart = character:WaitForChild("HumanoidRootPart")
end)
if LocalPlayer.Character then
    Character = LocalPlayer.Character
    Humanoid = Character:FindFirstChild("Humanoid") or Character:WaitForChild("Humanoid")
    HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart") or Character:WaitForChild("HumanoidRootPart")
end

SafeNotify("Executed", "Loading... Please wait", 5)
if not game:IsLoaded() or workspace.DistributedGameTime <= 10 then
    local WFGTL = COREGUI:FindFirstChild("WFGTL") or Instance.new("Hint", COREGUI)
    WFGTL.Text = "Just a moment... Waiting while the game loads - This won't take long!"
    task.wait(math.max(0, 10 - workspace.DistributedGameTime))
    WFGTL:Destroy()
end

-- gethui/hookfunction are optional. The main UI is parented to PlayerGui,
-- so unsupported executor APIs must never stop the script.
task.spawn(function()
    if type(gethui) == "function" then
        pcall(function()
            local targetGui = gethui()
            if targetGui then
                targetGui.IgnoreGuiInset = true
            end
        end)
    end
end)

-- Team selection is independent and protected from executor-specific APIs.
task.spawn(function()
    local ok, err = xpcall(function()
        if not LocalPlayer.Team then
            if LocalPlayer.PlayerGui:FindFirstChild("LoadingScreen") then
                repeat task.wait(1) until not LocalPlayer.PlayerGui:FindFirstChild("LoadingScreen")
            end
            local selected = pcall(function()
                COMMF_:InvokeServer("SetTeam", "Pirates")
            end)
            if not selected and type(firesignal) == "function" then
                pcall(function()
                    firesignal(LocalPlayer.PlayerGui["Main (minimal)"].ChooseTeam.Container.Pirates)
                end)
            end
            task.wait(2)
        end
    end, function(message)
        return tostring(message)
    end)
    if not ok then
        safeWarn("[Startup] Team selection error:", err)
    end
end)

repeat task.wait(0.5) until LocalPlayer.Team ~= nil
repeat task.wait(0.5) until Character
    and Character:FindFirstChild("HumanoidRootPart")
    and Character:FindFirstChildWhichIsA("Humanoid")
    and workspace:FindFirstChild("Characters")
    and Character:IsDescendantOf(workspace.Characters)

pcall(function()
    local previous = LocalPlayer.PlayerGui:FindFirstChild("Blank")
    if previous then
        previous:Destroy()
    end
end)
local BlankScreen = LocalPlayer.PlayerGui:FindFirstChild("Blank") or Instance.new("ScreenGui", LocalPlayer.PlayerGui)
BlankScreen.Name = "Blank"
BlankScreen.ResetOnSpawn = false
BlankScreen.DisplayOrder = -math.huge
BlankScreen.IgnoreGuiInset = true
local Black = BlankScreen:FindFirstChild("Black Screen") or Instance.new("Frame", BlankScreen)
Black.Name = "Black Screen"
Black.Size = UDim2.new(1, 0, 1, 0)
Black.BackgroundColor3 = Color3.new(0, 0, 0)
Black.ZIndex = -math.huge
Black.Visible = ENV.Settings["Black Screen"] or false

pcall(function()
    RunService:Set3dRenderingEnabled(not Black.Visible)
end)

local label = BlankScreen:FindFirstChild("CenteredLabel") or Instance.new("TextLabel", BlankScreen)
label.Name = "CenteredLabel"
label.AnchorPoint = Vector2.new(0.5, 0.5)
label.Position = UDim2.new(0.5, 0, 0.5, 0)
label.Size = UDim2.new(0.6, 0, 0.15, 0)
label.Text = "Loading..."
label.TextScaled = true
label.TextWrapped = true
label.TextXAlignment = Enum.TextXAlignment.Center
label.TextYAlignment = Enum.TextYAlignment.Center
label.BackgroundTransparency = 1
label.Font = Enum.Font.GothamSemibold
label.TextSize = 48
label.TextColor3 = Color3.fromRGB(255, 255, 255)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.F4 then
        Black.Visible = not Black.Visible
        pcall(function()
            RunService:Set3dRenderingEnabled(not Black.Visible)
        end)
        SafeNotify(
            "Black Screen",
            Black.Visible and "Da BAT man hinh den" or "Da TAT man hinh den",
            2
        )
    end
end)

local function SetText(newText)
    if label then
        label.Text = tostring(newText or "")
    end
end

local mainfile = LocalPlayer.Name .. ".txt"
local FILE_API_AVAILABLE = type(isfile) == "function"
    and type(readfile) == "function"
    and type(writefile) == "function"

local function SafeIsFile(path)
    if not FILE_API_AVAILABLE then
        return false
    end
    local ok, result = pcall(isfile, path)
    return ok and result == true
end

local function SafeReadFile(path, fallback)
    fallback = fallback == nil and "NaN" or fallback
    if not FILE_API_AVAILABLE or not SafeIsFile(path) then
        return fallback
    end
    local ok, result = pcall(readfile, path)
    if not ok then
        return fallback
    end
    return tostring(result or fallback)
end

local function SafeWriteFile(path, value)
    if not FILE_API_AVAILABLE then
        safeWarn("[File] writefile/isfile/readfile unavailable; completion file cannot be written")
        return false
    end
    local ok, err = pcall(writefile, path, tostring(value))
    if not ok then
        safeWarn("[File] write failed:", err)
    end
    return ok
end

if not SafeIsFile(mainfile) then
    SafeWriteFile(mainfile, "NaN")
end

local function SafeClickDetector(detector)
    if not detector or type(fireclickdetector) ~= "function" then
        return false
    end
    return pcall(fireclickdetector, detector)
end

local function SafeTouch(partA, partB, state)
    if not partA or not partB or type(firetouchinterest) ~= "function" then
        return false
    end
    return pcall(firetouchinterest, partA, partB, state or 0)
end

-- GuideModule is optional here; later helpers require it directly when available.
local GuideModule = ReplicatedStorage:FindFirstChild("GuideModule")

-- ============================================================
-- REAL SERVER UPTIME + 4H PERIOD / 2H ACTIVE WINDOW
-- Uses:
-- workspace:GetServerTimeNow() - Workspace._WorldOrigin.Locations.<Location>:GetAttribute("TimeIn")
-- ============================================================
local function GetRealServerUptime()
    local ok, uptime, locationName = pcall(function()
        local worldOrigin = workspace:FindFirstChild("_WorldOrigin")
        local locations = worldOrigin and worldOrigin:FindFirstChild("Locations")
        if not locations then
            return nil, "Locations not found"
        end

        local currentLocation = LocalPlayer:GetAttribute("CurrentLocation")
        local location = currentLocation and locations:FindFirstChild(currentLocation)

        if not location then
            for _, obj in next, locations:GetChildren() do
                local timeIn = obj:GetAttribute("TimeIn")
                if type(timeIn) == "number" then
                    location = obj
                    break
                end
            end
        end

        if not location then
            return nil, "Location with TimeIn not found"
        end

        local timeIn = location:GetAttribute("TimeIn")
        if type(timeIn) ~= "number" then
            return nil, "TimeIn not found"
        end

        return math.max(0, workspace:GetServerTimeNow() - timeIn), location.Name
    end)

    if not ok then
        return nil, tostring(uptime)
    end

    return uptime, locationName
end

local function FormatUptime(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    return string.format("%02d:%02d:%02d", hours, minutes, secs)
end

local function CheckChestTimeWindow()
    local uptime, source = GetRealServerUptime()
    if not uptime then
        return false, nil, source, nil
    end

    local period =
        tonumber(getgenv().Settings["Chest Server Period"])
        or (4 * 60 * 60)

    local grace =
        tonumber(getgenv().Settings["Chest Server Grace"])
        or (2 * 60 * 60)

    local offset = uptime % period
    local inWindow = offset < grace
    local cycleStart = uptime - offset
    local cycleEnd = cycleStart + grace
    local nextBoundary = inWindow and cycleEnd or (cycleStart + period)

    return inWindow, uptime, source, {
        Offset = offset,
        CycleStart = cycleStart,
        CycleEnd = cycleEnd,
        NextBoundary = nextBoundary,
    }
end

-- ============================================================
-- INDEPENDENT RACE OWNERSHIP FLOW
-- Order: Cyborg V1 -> Ghoul V1 -> Completed-done
-- This module does not change the current race just to check ownership.
-- ============================================================
local GHOUL_LOADER_URL = "https:" .. string.char(47, 47) .. "raw.githubusercontent.com/obiiyeuem/vthangsitink/main/BananaHub.lua"
local CYBORG_BUY_COOLDOWN = 3
local OWNERSHIP_RECHECK_DELAY = 5
local SEA_TRAVEL_COOLDOWN = 8

local RaceFlow = {
    ready = false,
    busy = false,
    mode = "BOOT", -- BOOT | GET_CYBORG | GET_GHOUL | COMPLETED
    cyborgOwned = false,
    ghoulOwned = false,
    cyborgCheckRaw = nil,
    ghoulCheckRaw = nil,
    ghoulEverConfirmed = false,
    ghoulConfirmedAt = nil,
    completedWritten = false,
    lastCyborgBuyAttempt = 0,
    lastSeaTravelAttempt = 0,
    sea2Ready = false,
    legacyCyborgOwned = false,
    banana = {
        started = false,
        running = false,
        lastAttempt = 0,
        lastError = nil,
    },
}

local function ReadMainFileState()
    return SafeReadFile(mainfile, "NaN")
end

-- Old markers are never trusted as final completion. Completed-cyborg is kept
-- only as legacy evidence for Cyborg; Completed-done is cleared and rechecked.
do
    local oldState = ReadMainFileState():lower()
    if oldState == "completed-cyborg" then
        RaceFlow.legacyCyborgOwned = true
        SafeWriteFile(mainfile, "NaN")
    elseif oldState == "completed-done" then
        SafeWriteFile(mainfile, "NaN")
    end
end

local function GetCurrentRace()
    local data = LocalPlayer and LocalPlayer:FindFirstChild("Data")
    local race = data and data:FindFirstChild("Race")
    if not race then
        return "Unknown", nil
    end

    local value = tostring(race.Value or "Unknown")
    if value == "" then
        value = "Unknown"
    end
    return value, race
end

local function SafeCommF(...)
    local args = {...}
    if not COMMF_ or type(COMMF_.InvokeServer) ~= "function" then
        return false, "CommF_ unavailable"
    end
    local ok, result = pcall(function()
        return COMMF_:InvokeServer(unpackArgs(args))
    end)
    if not ok then
        return false, result
    end
    return true, result
end

local function ContainsNegativeOwnershipText(text)
    for _, token in ipairs({
        "not enough", "do not have", "don't have", "dont have", "need ",
        "missing", "required", "requires", "cannot", "can't", "cant",
        "not unlocked", "not purchased", "not bought", "come back"
    }) do
        if text:find(token, 1, true) then
            return true
        end
    end
    return false
end

local function TableHasOwnedFlag(result)
    if type(result) ~= "table" then
        return false
    end
    for _, key in ipairs({
        "Owned", "owned", "Unlocked", "unlocked", "Bought", "bought",
        "Purchased", "purchased", "Has", "has", "Completed", "completed"
    }) do
        if result[key] == true or result[key] == 1 or result[key] == 2 then
            return true
        end
    end
    return false
end

local function CyborgResultIsOwned(result)
    if result == 2 or tostring(result) == "2" then
        return true
    end
    if TableHasOwnedFlag(result) then
        return true
    end
    if type(result) ~= "string" then
        return false
    end
    local text = result:lower()
    if ContainsNegativeOwnershipText(text) then
        return false
    end
    return (text:find("cyborg", 1, true) and (
        text:find("already", 1, true)
        or text:find("owned", 1, true)
        or text:find("unlocked", 1, true)
        or text:find("purchased", 1, true)
    )) and true or false
end

-- Conservative on purpose: true/1 from BuyCheck is NOT enough to write
-- Completed-done. Ghoul must be the current race, return explicit state 2,
-- or return an unambiguous owned/already result from the Ghoul check itself.
local function GhoulResultIsOwned(result)
    if result == 2 or tostring(result) == "2" then
        return true
    end
    if TableHasOwnedFlag(result) then
        return true
    end
    if type(result) ~= "string" then
        return false
    end

    local text = result:lower()
    if ContainsNegativeOwnershipText(text) then
        return false
    end

    local ownershipWord = text:find("already", 1, true)
        or text:find("owned", 1, true)
        or text:find("unlocked", 1, true)
        or text:find("purchased", 1, true)
        or text:find("bought", 1, true)

    local ghoulContext = text:find("ghoul", 1, true)
        or text:find("this race", 1, true)
        or text:find("change race", 1, true)

    return ownershipWord ~= nil and ghoulContext ~= nil
end

local function CheckCyborgOwned()
    local raceName = GetCurrentRace()
    if raceName:lower() == "cyborg" or RaceFlow.legacyCyborgOwned then
        RaceFlow.cyborgOwned = true
        RaceFlow.legacyCyborgOwned = true
        RaceFlow.cyborgCheckRaw = raceName:lower() == "cyborg"
            and "current_race"
            or "legacy_confirmed"
        return true, RaceFlow.cyborgCheckRaw
    end

    local ok, result = SafeCommF("CyborgTrainer", "Check")
    RaceFlow.cyborgCheckRaw = ok and result or ("remote_error:" .. tostring(result))
    RaceFlow.cyborgOwned = ok and CyborgResultIsOwned(result) or false
    if RaceFlow.cyborgOwned then
        RaceFlow.legacyCyborgOwned = true
    end
    return RaceFlow.cyborgOwned, RaceFlow.cyborgCheckRaw
end

local function CheckGhoulOwned()
    local raceName = GetCurrentRace()
    if raceName:lower() == "ghoul" then
        RaceFlow.ghoulOwned = true
        RaceFlow.ghoulEverConfirmed = true
        RaceFlow.ghoulConfirmedAt = tick()
        RaceFlow.ghoulCheckRaw = "current_race"
        return true, RaceFlow.ghoulCheckRaw
    end

    if RaceFlow.ghoulEverConfirmed and RaceFlow.ghoulConfirmedAt then
        RaceFlow.ghoulOwned = true
        RaceFlow.ghoulCheckRaw = "previously_runtime_confirmed"
        return true, RaceFlow.ghoulCheckRaw
    end

    -- Check only. Never calls Ectoplasm Change here.
    local ok, result = SafeCommF("Ectoplasm", "BuyCheck", 4)
    RaceFlow.ghoulCheckRaw = ok and result or ("remote_error:" .. tostring(result))
    RaceFlow.ghoulOwned = ok and GhoulResultIsOwned(result) or false
    if RaceFlow.ghoulOwned then
        RaceFlow.ghoulEverConfirmed = true
        RaceFlow.ghoulConfirmedAt = tick()
    end
    return RaceFlow.ghoulOwned, RaceFlow.ghoulCheckRaw
end

local function WriteCompletedDone()
    -- Hard gate: no stale file and no BananaHub finish can mark completion.
    -- Only the independent Ghoul ownership check can open this gate.
    if RaceFlow.cyborgOwned ~= true
        or RaceFlow.ghoulOwned ~= true
        or not RaceFlow.ghoulConfirmedAt then
        return false
    end

    if ReadMainFileState():lower() ~= "completed-done" then
        if not SafeWriteFile(mainfile, "Completed-done") then
            return false
        end
    end
    RaceFlow.completedWritten = true
    return true
end

local function GetSeaNumber()
    local placeId = game.PlaceId
    if placeId == 2753915549 then
        return 1
    elseif placeId == 4442272183 then
        return 2
    elseif placeId == 7449423635 then
        return 3
    end

    local map = workspace:GetAttribute("MAP")
    local number = tostring(map or ""):match("%d+")
    return tonumber(number)
end

local function EnsureSea2ForCyborg()
    local sea = GetSeaNumber()
    RaceFlow.sea2Ready = sea == 2
    if RaceFlow.sea2Ready then
        return true
    end

    local now = tick()
    if now - RaceFlow.lastSeaTravelAttempt >= SEA_TRAVEL_COOLDOWN then
        RaceFlow.lastSeaTravelAttempt = now
        SetText("Cyborg V1: missing\nCurrent Sea: " .. tostring(sea or "Unknown") .. "\nTeleporting to Sea 2...")
        SafeCommF("TravelDressrosa")
    end
    return false
end

local BANANA_RETRY_COOLDOWN = 15

local function StartGhoulLoader()
    local banana = RaceFlow.banana
    if banana.running or banana.started then
        return true
    end

    local externalKey = ENV.Key
    if externalKey == nil or tostring(externalKey) == "" then
        SetText("Cyborg V1: owned\nGhoul V1: missing\nSet getgenv().Key outside the loader")
        return false
    end

    if type(compileSource) ~= "function" then
        banana.lastError = "Executor does not provide loadstring/load"
        SetText("BananaHub cannot start:\nloadstring/load is unavailable")
        safeWarn("[BananaGhoul]", banana.lastError)
        return false
    end

    local now = tick()
    if now - banana.lastAttempt < BANANA_RETRY_COOLDOWN then
        return false
    end

    banana.lastAttempt = now
    banana.started = true
    banana.running = true
    banana.lastError = nil

    SetText("Cyborg V1: owned\nGhoul V1: missing\nBananaHub Get Ghoul running independently...")

    -- Completely independent worker: its errors never stop Get Cyborg or the
    -- ownership checker, and it can never write Completed-done by itself.
    task.spawn(function()
        local ok, err = xpcall(function()
            ENV.Key = externalKey
            ENV.Config = {
                ["Hop Server Get Ghoul"] = true,
                ["Auto Get Ghoul"] = true,
            }

            local httpOk, sourceOrError = SafeHttpGet(GHOUL_LOADER_URL)
            if not httpOk then
                error("BananaHub download failed: " .. tostring(sourceOrError))
            end
            local loader, compileError = compileSource(sourceOrError)
            if type(loader) ~= "function" then
                error("BananaHub compile failed: " .. tostring(compileError or "unknown"))
            end
            loader()
        end, function(message)
            return tostring(message)
        end)

        banana.running = false
        if not ok then
            banana.started = false
            banana.lastError = err
            SetText("BananaHub Get Ghoul error:\n" .. tostring(err))
            safeWarn("[BananaGhoul] independent worker error:", err)
        end
    end)

    return true
end

local function RefreshRaceFlow()
    if RaceFlow.busy then
        return RaceFlow.mode
    end
    RaceFlow.busy = true

    -- Required order: always check Cyborg ownership first.
    local hasCyborg = CheckCyborgOwned()
    if not hasCyborg then
        RaceFlow.mode = "GET_CYBORG"
        RaceFlow.ghoulOwned = false
        EnsureSea2ForCyborg()
        if RaceFlow.sea2Ready then
            SetText("Cyborg V1: missing\nGhoul check: waiting\nRunning Get Cyborg...")
        end
        RaceFlow.busy = false
        return RaceFlow.mode
    end

    -- Only check Ghoul after Cyborg V1 is confirmed.
    local hasGhoul = CheckGhoulOwned()
    if not hasGhoul then
        RaceFlow.mode = "GET_GHOUL"
        Tween(false)
        StartGhoulLoader()
        RaceFlow.busy = false
        return RaceFlow.mode
    end

    RaceFlow.mode = "COMPLETED"
    RaceFlow.sea2Ready = true
    Tween(false)
    local wrote = WriteCompletedDone()
    if wrote then
        SetText("Cyborg V1: owned\nGhoul V1: verified\nCompleted-done")
    else
        RaceFlow.mode = "GET_GHOUL"
        SetText("Ghoul verification not complete; file not written")
    end
    RaceFlow.busy = false
    return RaceFlow.mode
end

local function TryBuyCyborg(force)
    if RaceFlow.mode ~= "GET_CYBORG" then
        return RaceFlow.cyborgOwned, "not_in_get_cyborg_mode"
    end

    local raceName = GetCurrentRace()
    if raceName:lower() == "cyborg" then
        RaceFlow.legacyCyborgOwned = true
        RefreshRaceFlow()
        return true, "current_race"
    end

    local now = tick()
    if now - RaceFlow.lastCyborgBuyAttempt < CYBORG_BUY_COOLDOWN then
        return false, "cooldown"
    end

    local data = LocalPlayer and LocalPlayer:FindFirstChild("Data")
    local fragments = data and data:FindFirstChild("Fragments")
    if not force and (not fragments or tonumber(fragments.Value) < 2500) then
        return false, "not_enough_fragments"
    end

    RaceFlow.lastCyborgBuyAttempt = now
    local ok, result = SafeCommF("CyborgTrainer", "Buy")
    task.wait(0.25)

    local newRace = GetCurrentRace()
    if newRace:lower() == "cyborg" then
        RaceFlow.legacyCyborgOwned = true
        RefreshRaceFlow()
        return true, result
    end

    return false, ok and result or "remote_error"
end

-- Wait for the game, Team, Character and Data.Race before any Sea or race check.
task.spawn(function()
    repeat task.wait(0.5) until game:IsLoaded()
    repeat task.wait(0.5) until LocalPlayer and LocalPlayer.Team ~= nil
    repeat task.wait(0.5) until Character
        and Character:IsDescendantOf(workspace)
        and Character:FindFirstChild("HumanoidRootPart")
        and Character:FindFirstChildWhichIsA("Humanoid")
    local data = LocalPlayer:WaitForChild("Data")
    local race = data:WaitForChild("Race")

    RaceFlow.ready = true
    -- Never trust an old completion file. Runtime ownership checks decide.
    RefreshRaceFlow()

    if race then
        race:GetPropertyChangedSignal("Value"):Connect(function()
            task.defer(RefreshRaceFlow)
        end)
    end

    while task.wait(OWNERSHIP_RECHECK_DELAY) do
        if RaceFlow.mode ~= "COMPLETED" then
            RefreshRaceFlow()
        elseif RaceFlow.ghoulOwned and RaceFlow.ghoulConfirmedAt then
            WriteCompletedDone()
        else
            RaceFlow.mode = "GET_GHOUL"
            RefreshRaceFlow()
        end
    end
end)

function CheckSea(v: number)
    return tonumber(v) == GetSeaNumber()
end

local canPress = true
PressKeyEvent = (function(k, d)
    if not canPress then return end
    canPress = false
    task.spawn(function()
        VirtualInputManager:SendKeyEvent(true, k, false, game) task.wait(d or 0)
        VirtualInputManager:SendKeyEvent(false, k, false, game)
        canPress = true
    end)
end)

local remoteAttack, idremote
local seed = 0
pcall(function()
    local net = ReplicatedStorage:FindFirstChild("Modules")
        and ReplicatedStorage.Modules:FindFirstChild("Net")
    local seedRemote = net and net:FindFirstChild("seed")
    if seedRemote and type(seedRemote.InvokeServer) == "function" then
        seed = tonumber(seedRemote:InvokeServer()) or 0
    end
end)
task.spawn((function() for _, v in next, ({ReplicatedStorage.Util, ReplicatedStorage.Common, ReplicatedStorage.Remotes, ReplicatedStorage.Assets, ReplicatedStorage.FX}) do
    for _, n in next, v:GetChildren() do if n:IsA("RemoteEvent") and n:GetAttribute("Id") then remoteAttack, idremote = n, n:GetAttribute("Id") end
    end v.ChildAdded:Connect(function(n) if n:IsA("RemoteEvent") and n:GetAttribute("Id") then remoteAttack, idremote = n, n:GetAttribute("Id")
    end end) end
end))

CheckLocation = (function(v)return LocalPlayer:GetAttribute("CurrentLocation") == v end)
CheckMap = (function(v) return workspace.Map:FindFirstChild(v) or false end)
CheckTool = (function(v)
    for _, x in next, {LocalPlayer.Backpack, Character} do
    for _, v2 in next, x:GetChildren() do if v2:IsA("Tool") and (v2.Name == v or v2.Name:find(v)) then return true end
    end end return false
end)
CheckMaterial = (function(x)
    for _, v in pairs(COMMF_:InvokeServer("getInventory")) do if v.Type == "Material" then if v.Name == x then return v.Count end end
    end return 0
end)
CheckInventory = (function(...)
    for _, v in pairs(COMMF_:InvokeServer("getInventory")) do
    for _, n in next, {...} do if v.Name == n then return true end end
    end return false
end)

IsDied = function(v)
    local ok, r = xpcall(function()
        if not v then return true end
        local h = v:FindFirstChild("Humanoid") or v:FindFirstChildWhichIsA("Humanoid")
        local hrp = v:FindFirstChild("HumanoidRootPart")
        if not h or not hrp then return true end
        if h:IsA("Humanoid") then return h.Health <= 0 end
        if h:IsA("ValueBase") and type(h.Value) == "number" then return h.Value <= 0 end
        return false
    end, function() return false end)
    return ok and r or false
end

KillAura = (function(vName)
    pcall(function() setscriptable(LocalPlayer, "SimulationRadius", true) end)
    pcall(function() sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge) end)
    for _, v in next, workspace.Enemies:GetChildren() do
        pcall(function()
            local hrp = v:FindFirstChild("HumanoidRootPart") or false
            if hrp and HumanoidRootPart and (hrp.Position - HumanoidRootPart.Position).Magnitude <= 1250 then
                local cond = (vName and v.Name == vName) or not vName
                if cond then
                    v:FindFirstChildOfClass("Humanoid"):ChangeState(Enum.HumanoidStateType.Dead)
                end
            end
        end)
    end
end)

CheckMonster = (function(...) local args = {...}
    local v2 = {workspace.Enemies, ReplicatedStorage}
    for i = 1, #args do local n = args[i]
        local m = workspace.Enemies:FindFirstChild(n) or ReplicatedStorage:FindFirstChild(n)
        if m and m:IsA("Model") and m.Name ~= "Blank Buddy" then
            local h = m:FindFirstChild("Humanoid") local r = m:FindFirstChild("HumanoidRootPart")
            if h and r and not IsDied(m) then return m end
        end
    end
    for c = 1, #v2 do local container = v2[c] local ms = container:GetChildren()
        for m = 1, #ms do local m = ms[m] local h = m:FindFirstChild("Humanoid")
            local r = m:FindFirstChild("HumanoidRootPart")
            if m:IsA("Model") and h and r and not IsDied(m) and m.Name ~= "Blank Buddy" then
                for i = 1, #args do local n = args[i]
                    if m.Name == n or m.Name:lower():find(n:lower()) then
                        return m
                    end
                end
            end
        end
    end
    return false
end)

EquipWeapon = (function(v)
    if not Character then return end
    local tool = Character:FindFirstChildWhichIsA("Tool")
    if tool and (tool.ToolTip and tool.ToolTip == v) then return end
    for _, x in next, LocalPlayer.Backpack:GetChildren() do
        if x:IsA("Tool") and x.ToolTip == v then
            Humanoid:EquipTool(x)
            return
        end
    end
end)

local lastCallFA = tick()
FastAttack = (function(x)
    if not HumanoidRootPart
        or not Character
        or not Character:FindFirstChildWhichIsA("Humanoid")
        or Character.Humanoid.Health <= 0
        or not Character:FindFirstChildWhichIsA("Tool") then
        return
    end

    local FAD = 0.01
    if FAD ~= 0 and tick() - lastCallFA <= FAD then
        return
    end

    local targets = {}
    local enemies = workspace:FindFirstChild("Enemies")
    if not enemies then
        return
    end

    for _, enemy in next, enemies:GetChildren() do
        local humanoid = enemy:FindFirstChild("Humanoid")
        local root = enemy:FindFirstChild("HumanoidRootPart")
        if enemy ~= Character
            and ((x and enemy.Name == x) or not x)
            and humanoid
            and root
            and not IsDied(enemy)
            and (root.Position - HumanoidRootPart.Position).Magnitude <= 65 then
            targets[#targets + 1] = enemy
        end
    end

    if #targets == 0 then
        return
    end

    local net = ReplicatedStorage:FindFirstChild("Modules")
        and ReplicatedStorage.Modules:FindFirstChild("Net")
    if not net then
        return
    end

    local hitData = {[2] = {}}
    for _, enemy in ipairs(targets) do
        local part = enemy:FindFirstChild("Head") or enemy:FindFirstChild("HumanoidRootPart")
        if part then
            hitData[1] = hitData[1] or part
            hitData[2][#hitData[2] + 1] = {enemy, part}
        end
    end

    if not hitData[1] or #hitData[2] == 0 then
        return
    end

    local registerAttack = net:FindFirstChild("RE/RegisterAttack")
    local registerHit = net:FindFirstChild("RE/RegisterHit")
    if registerAttack then
        pcall(function()
            registerAttack:FireServer()
        end)
    end
    if registerHit then
        pcall(function()
            registerHit:FireServer(unpackArgs(hitData))
        end)
    end

    if remoteAttack and idremote ~= nil then
        pcall(function()
            cloneref(remoteAttack):FireServer(
                string.gsub("RE/RegisterHit", ".", function(character)
                    return string.char(bit32.bxor(
                        string.byte(character),
                        math.floor(workspace:GetServerTimeNow() / 10 % 10) + 1
                    ))
                end),
                bit32.bxor((tonumber(idremote) or 0) + 909090, (tonumber(seed) or 0) * 2),
                unpackArgs(hitData)
            )
        end)
    end

    lastCallFA = tick()
end)

local lastHop, inHopPP = tick(), false
function IfTableHaveIndex(j)
    for _ in j do
        return true
    end
end

local LastServersDataPulled, CachedServers
function GetServers()
    if LastServersDataPulled and CachedServers then
        if os.time() - LastServersDataPulled < 60 then
            return CachedServers
        end
    end

    local browser = ReplicatedStorage:FindFirstChild("__ServerBrowser")
    if not browser then
        return {}
    end

    for page = 1, 100 do
        local ok, data = pcall(function()
            return browser:InvokeServer(page)
        end)
        if ok and type(data) == "table" and IfTableHaveIndex(data) then
            LastServersDataPulled = os.time()
            CachedServers = data
            return data
        end
    end

    return CachedServers or {}
end

HopServer = function(MaxPlayers, ForcedRegion)
    MaxPlayers = tonumber(MaxPlayers) or 8
    SetText("Fetching Server...")

    local servers = GetServers() or {}
    local candidates = {}
    for jobId, server in next, servers do
        if type(server) == "table"
            and jobId ~= game.JobId
            and tonumber(server.Count)
            and tonumber(server.Count) <= MaxPlayers
            and (not ForcedRegion or server.Region == ForcedRegion) then
            candidates[#candidates + 1] = {
                JobId = jobId,
                Players = tonumber(server.Count) or math.huge,
                LastUpdate = server.__LastUpdate,
                Region = server.Region,
            }
        end
    end

    table.sort(candidates, function(a, b)
        return a.Players < b.Players
    end)

    if #candidates == 0 then
        SetText("No matching server found. Retrying later...")
        return false
    end

    local serverData = candidates[math.random(1, #candidates)]
    SetText(
        "Found Server: " .. tostring(serverData.JobId)
        .. " | Players: " .. tostring(serverData.Players)
        .. " | Region: " .. tostring(serverData.Region or "Unknown")
    )

    local browser = ReplicatedStorage:FindFirstChild("__ServerBrowser")
    if not browser then
        return false
    end

    local ok, err = pcall(function()
        browser:InvokeServer("teleport", serverData.JobId)
    end)
    if not ok then
        safeWarn("[HopServer]", err)
    end
    return ok
end

local connection, tween, pathPart, isTweening = nil, nil, nil, false
function Tween(targetCFrame: CFrame | boolean, target: CFrame)
    pcall(function() Character.Humanoid.Sit = false end)
    if not Character.Humanoid or Character.Humanoid.Health <= 0 then pcall(function() workspace.TweenGhost:Destroy() end) connection, tween, pathPart, isTweening = nil, nil, nil, false return end
    if targetCFrame == false then
        if tween then pcall(function() tween:Cancel() end) tween = nil end
        if connection then connection:Disconnect() connection = nil end
        if pathPart then pathPart:Destroy() pathPart = nil end
        isTweening = false
        return
    end
    if isTweening or not targetCFrame then return end
    isTweening = true
    local char = game.Players.LocalPlayer and game.Players.LocalPlayer.Character
    if not char then isTweening = false return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid then isTweening = false return end
    humanoid.Sit = false
    target = target or root
    local distance = (targetCFrame.Position - target.Position).Magnitude
    pathPart = Instance.new("Part")
    pathPart.Name = "TweenGhost"
    pathPart.Transparency = 1
    pathPart.Anchored = true
    pathPart.CanCollide = false
    pathPart.CFrame = target.CFrame
    pathPart.Size = Vector3.new(50, 50, 50)
    pathPart.Parent = workspace
    tween = game:GetService("TweenService"):Create(pathPart, TweenInfo.new(distance / 250, Enum.EasingStyle.Linear), {CFrame = targetCFrame * (function()
        if target ~= root then
            return CFrame.new(0, 30, 0)
        end
        return CFrame.new(0, 5, 0)
    end)()})
    connection = game:GetService("RunService").Heartbeat:Connect(function()
        if target and pathPart then
            target.CFrame = pathPart.CFrame * (function()
                if target ~= root then
                    return CFrame.new(0, 30, 0)
                end
                return CFrame.new(0, 5, 0)
            end)()
        end
    end)
    tween.Completed:Connect(function()
        if connection then connection:Disconnect() connection = nil end
        if pathPart then pathPart:Destroy() pathPart = nil end
        tween = nil
        isTweening = false
    end)
    tween:Play()
end

-- ===== [ FIX GHOST CHEST ] Tween toi part roi firetouchinterest de cham THAT SU =====
-- Chest touch implementation. Replaces SetPrimaryPartCFrame + PressKeyEvent("Space") which did not collect
-- duoc chest (ghost) vua de loi khi PrimaryPart chua set.
local function TweenTouchPart(part, text, speedSetting, radiusSetting, stopCondition)
    if not part or not part:IsA("BasePart") or not part.Parent then
        return false
    end
    if not Character or IsDied(Character) or not HumanoidRootPart then
        return false
    end

    Tween(false)

    local root = Character:FindFirstChild("HumanoidRootPart")
    local humanoid = Character:FindFirstChildWhichIsA("Humanoid")
    if not root or not humanoid or humanoid.Health <= 0 then
        return false
    end

    humanoid.Sit = false
    pcall(function()
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end)

    local speed = tonumber(getgenv().Settings[speedSetting or "Chest Tween Speed"]) or 325
    local touchRadius = tonumber(getgenv().Settings[radiusSetting or "Chest Touch Radius"]) or 8
    local distance = (root.Position - part.Position).Magnitude
    local travelTime = math.max(distance / speed, 0.05)
    local timeout = travelTime + 3
    local startTick = tick()

    local ghost = Instance.new("Part")
    ghost.Name = "TouchTweenGhost"
    ghost.Transparency = 1
    ghost.Anchored = true
    ghost.CanCollide = false
    ghost.Size = Vector3.new(4, 4, 4)
    ghost.CFrame = root.CFrame
    ghost.Parent = workspace

    local touchTween = TweenService:Create(
        ghost,
        TweenInfo.new(travelTime, Enum.EasingStyle.Linear),
        {CFrame = part.CFrame * CFrame.new(0, 2, 0)}
    )

    local heartbeat
    heartbeat = RunService.Heartbeat:Connect(function()
        if not Character or IsDied(Character) or not root or not ghost or not ghost.Parent then
            return
        end
        humanoid.Sit = false
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        root.CFrame = ghost.CFrame
    end)

    touchTween:Play()

    local touched = false
    repeat
        task.wait()
        if text then
            if type(text) == "function" then
                pcall(function() SetText(text()) end)
            else
                SetText(text)
            end
        end
        if not part or not part.Parent then
            break
        end
        if stopCondition and stopCondition() then
            break
        end
        if IsDied(Character) then
            break
        end
        if (root.Position - part.Position).Magnitude <= touchRadius then
            touched = true
            pcall(function()
                SafeTouch(root, part, 0)
                task.wait(0.08)
                SafeTouch(root, part, 1)
            end)
            task.wait(0.15)
        end
    until touched or tick() - startTick > timeout

    pcall(function() touchTween:Cancel() end)
    if heartbeat then heartbeat:Disconnect() end
    if ghost then ghost:Destroy() end

    return touched
end

local function TweenChest(chest, stopCondition)
    if not chest or not chest:IsA("BasePart") or not chest.Parent or not chest.CanTouch then
        return false
    end

    return TweenTouchPart(
        chest,
        nil,
        "Chest Tween Speed",
        "Chest Touch Radius",
        function()
            return not chest.Parent or not chest.CanTouch or (stopCondition and stopCondition())
        end
    )
end

local lastGhost = tick()
BringMonster = (function(name, count) count = count or 3
    if count < 2 then return end
    pcall(function() setscriptable(LocalPlayer, "SimulationRadius", true) end)
    pcall(function() sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge) end)
    xpcall((function()
        local mob, t = {}, nil
        for _, v in next, workspace.Enemies:GetChildren() do
            local h = v:FindFirstChild("Humanoid")
            local hrp = v:FindFirstChild("HumanoidRootPart")
            if h and hrp and h.Health > 0 and (not name or v.Name == name)
                and (HumanoidRootPart.Position - hrp.Position).Magnitude <= ((count or 3) * 250) then
                if not table.find(mob, function(chosen)
                    local chrp = chosen:FindFirstChild("HumanoidRootPart")
                    return chrp and (hrp.Position - chrp.Position).Magnitude <= 5
                end) then mob[#mob+1], t = v, t or hrp.CFrame
                end
                if #mob >= (count or 3) then break end
            end
        end
        if not t then return end
        for i = 1, #mob do
            local hrp = mob[i]:FindFirstChild("HumanoidRootPart")
            local h = mob[i]:FindFirstChild("Humanoid")
            if hrp and (not isnetworkowner or isnetworkowner(hrp)) then
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
                hrp.CFrame = t * CFrame.new((i-1) * 2, 0, 0)
            end
        end
    end), (function(r) warn("Modules Error [BM]: ".. r) end))
end)

local lastKenCall=tick()
KillMonster=(function(x)
    xpcall(function()
        if workspace.Enemies:FindFirstChild(x) then
            for _,v in next,workspace.Enemies:GetChildren() do
                local vh=v:FindFirstChild("Humanoid") local vhrp=v:FindFirstChild("HumanoidRootPart")
                if vh and vh.Health > 0 and vhrp and v.Name==x then
                    local dx,dy,dz=HumanoidRootPart.Position.X-vhrp.Position.X, HumanoidRootPart.Position.Y-vhrp.Position.Y, HumanoidRootPart.Position.Z-vhrp.Position.Z
                    local sqrMag=dx*dx+dy*dy+dz*dz
                    if sqrMag<=4900 then
                        BringMonster(x, 3)
                        FastAttack(x)
                        if tick()-lastKenCall>=10 then lastKenCall=tick() ReplicatedStorage.Remotes.CommE:FireServer("Ken",true) end
                        Tween(CFrame.new(vhrp.Position + (vhrp.CFrame.LookVector * 20) + Vector3.new(0, vhrp.Position.Y > 60 and -20 or 20, 0)))
                        EquipWeapon("Melee")
                        return
                    end
                    Tween(vhrp.CFrame) return
                end
            end
        end
        for _,v in next,ReplicatedStorage:GetChildren() do
            local vhrp=v:FindFirstChild("HumanoidRootPart")
            if v:IsA("Model") and vhrp and v.Name==x then Tween(vhrp.CFrame) return end
        end
    end,function(e) warn("Modules ERROR:",e) end)
end)

TableQuests = setmetatable({}, {__index = function(_, k)
    local p, d, m, raw = HumanoidRootPart.Position
    for _, x in next, require(ReplicatedStorage.GuideModule).Data.NPCList do
        if x.InternalQuestName == k then
            local pos = x.Position
            if typeof(pos) == "Vector3" then
                local dist = (pos - p).Magnitude
                if not d or dist < d then d = dist m = pos raw = x.NPCName end
            elseif typeof(pos) == "table" then
                for _, v in next, pos do
                    if typeof(v) == "Vector3" then
                        local dist = (v - p).Magnitude
                        if not d or dist < d then d = dist m = v raw = x.NPCName end
                    end
                end
            end
        end
    end
    return m and {Position = m, Meters = d, RawNPCName = raw} or nil
end})

local hookedNotification

do
    local okModule, notificationModule = pcall(function()
        return require(ReplicatedStorage:WaitForChild("Notification"))
    end)
    local originalNew = okModule and notificationModule and notificationModule.new

    if type(hookfunction) == "function" and type(originalNew) == "function" then
        local callback = newcclosure(function(...)
            local args = ({...})[1]
            if type(args) == "string"
                and not RaceFlow.completedWritten
                and RaceFlow.mode ~= "COMPLETED"
                and CheckSea(2) then
                local lower = args:lower()
                if lower:find("supply a <core brain>", 1, true)
                    or args:find("<Fist of Darkness> has been", 1, true) then
                    CyborgBlockPartUnlocked = "unlock"
                    SafeWriteFile(mainfile, "unlock")
                elseif args:find("Microchip not found", 1, true) then
                    CyborgBlockPartUnlocked = "chest"
                    SafeWriteFile(mainfile, "chest")
                end
            end

            if type(hookedNotification) == "function" then
                return hookedNotification(...)
            end
            return nil
        end)

        local okHook, original = pcall(hookfunction, originalNew, callback)
        if okHook and type(original) == "function" then
            hookedNotification = original
        else
            safeWarn("[Notification] hook unavailable; continuing with polling mode")
        end
    else
        safeWarn("[Notification] hookfunction unavailable; continuing with polling mode")
    end
end

local all = 0
local fragok = false;
task.spawn(function()
    while task.wait(0.5) do
        xpcall(function()
            if not RaceFlow.ready then
                SetText("Waiting for game, Team, Character and Race data...")
                return
            end

            if RaceFlow.mode == "COMPLETED" then
                Tween(false)
                WriteCompletedDone()
                SetText("Cyborg V1: owned\nGhoul V1: owned\nCompleted-done")
                return
            elseif RaceFlow.mode == "GET_GHOUL" then
                Tween(false)
                StartGhoulLoader()
                return
            elseif RaceFlow.mode ~= "GET_CYBORG" then
                return
            end

            if not EnsureSea2ForCyborg() then
                return
            end

            -- Get Cyborg runs exactly as before when Cyborg V1 is missing.
            local currentRace = GetCurrentRace()
            if currentRace:lower() ~= "cyborg" and LocalPlayer.Data.Fragments.Value >= 2500 then
                TryBuyCyborg(false)
                if RaceFlow.mode ~= "GET_CYBORG" then
                    return
                end
            end

            CyborgBlockPartUnlocked = ReadMainFileState()
            pcall(function() SafeClickDetector(workspace.Map.CircleIsland.RaidSummon.Button.Main.ClickDetector) end)

            local _, cyborgProgressCheck = SafeCommF("CyborgTrainer", "Check")
            if CyborgBlockPartUnlocked == "unlock" or cyborgProgressCheck == true then
                local have, need = LocalPlayer.Data.Fragments.Value, getgenv().Settings.Fragments
                if fragok then
                    if have < 2500 then fragok = false
                    end
                else
                    if have >= need then fragok = true
                    end
                end
                if fragok or CheckMonster("Order") or CheckTool("Microchip") then print("CC")
                    if CheckSea(2) then
                        if fragok == false and LocalPlayer.Data.Fragments.Value >= getgenv().Settings.Fragments then
                            fragok = true
                        end
                        if CheckMonster("Order") then
                            for _, v in next, workspace.Enemies:GetChildren() do
                                if v.Name == "Order" then
                                    if v:FindFirstChildWhichIsA("Humanoid") and v.Humanoid.Health > 0 and v.HumanoidRootPart then
                                        repeat task.wait()
                                            KillMonster(v.Name)
                                        until not v or not v:FindFirstChildWhichIsA("Humanoid") or v.Humanoid.Health <= 0 or not v.HumanoidRootPart or not Character.Humanoid or Character.Humanoid.Health <= 0
                                    end
                                end
                            end
                            pcall(function() Tween(ReplicatedStorage.Order:GetPivot()) end)
                        else
                            if not CheckTool("Microchip") and not CheckTool("Core Brain") then COMMF_:InvokeServer("BlackbeardReward", "Microchip", "2") task.wait(1) end
                            SafeClickDetector(workspace.Map.CircleIsland.RaidSummon.Button.Main.ClickDetector)
                            TryBuyCyborg(true)
                        end
                    else SetText("Travel to Dressrosa") task.wait(3) COMMF_:InvokeServer("TravelDressrosa")
                    end
                else print("CX[1]")
                    if CheckSea(3) then print("CX")
                        if CheckMonster("Dough King") or CheckMonster("rip_indra") or CheckMonster("Cake Prince") then
                            for _, v2 in next, {workspace.Enemies, ReplicatedStorage} do
                                for _, v in next, v2:GetChildren() do
                                    if v.Name == "Dough King" or v.Name == "Cake Prince" or v.Name:find("rip_indra") then
                                        if v.Name ~= "rip_indra" then if not CheckLocation("Dimensional Shift") then SafeTouch(LocalPlayer.Character.HumanoidRootPart, workspace.Map.CakeLoaf.BigMirror.Main, 0) task.wait(3) end end
                                        if v:FindFirstChildWhichIsA("Humanoid") and v.Humanoid.Health > 0 and v.HumanoidRootPart then
                                            repeat task.wait() KillMonster(v.Name)
                                            until not v or not v:FindFirstChildWhichIsA("Humanoid") or v.Humanoid.Health <= 0 or not v.HumanoidRootPart
                                        end
                                    end
                                end
                            end
                        else currentProgress = tonumber(COMMF_:InvokeServer("CakePrinceSpawner"):match("%d+") or 500) print(currentProgress)
                            if currentProgress <= getgenv().Settings["Katakuri Progress"] then
                                if LocalPlayer.Data.Level.Value >= 2200 and (LocalPlayer.PlayerGui.Main.Quest.Visible and (function(q)
                                    for _, n in next, {"Cookie Crafter", "Cake Guard", "Baking Staff", "Head Baker"} do
                                        if q:find(n) then return true end
                                    end
                                end)(LocalPlayer.PlayerGui.Main.Quest.Container.QuestTitle.Title.Text)) or LocalPlayer.Data.Level.Value < 2200 then
                                    xpcall(function()
                                        Tween(workspace.Map.CakeLoaf.RespawnPart.CFrame)
                                    end, function()
                                        Tween(CFrame.new(-2100, 70, -12130))
                                    end)
                                    for _, v in next, workspace.Enemies:GetChildren() do
                                        if table.find({"Cookie Crafter", "Cake Guard", "Baking Staff", "Head Baker"}, v.Name) then
                                            if v:FindFirstChild("HumanoidRootPart") and v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 then
                                                repeat task.wait()
                                                    SetText("Killing 500 monsters| Killing: ".. v.Name.. "\nCurrent progress: ".. currentProgress.. "/500")
                                                    KillMonster(v.Name)
                                                until (LocalPlayer.Data.Level.Value >= 2200 and not LocalPlayer.PlayerGui.Main.Quest.Visible) or not v or not v:FindFirstChildWhichIsA("Humanoid") or v.Humanoid.Health <= 0
                                            end
                                        end
                                    end
                                else
                                    pcall(function()
                                        if (TableQuests["CakeQuest2"].Position - Character.HumanoidRootPart.Position).Magnitude > 30 then
                                            task.defer(function()
                                                SetText("Tweening To Katakuri Island | Get Quest: Cake Quest Giver")
                                                Tween(false)
                                                Tween(CFrame.new(TableQuests["CakeQuest2"].Position))
                                            end)
                                        else
                                            SetText("Get Quest Cake Prince: " .. TableQuests["CakeQuest2"].RawNPCName) task.wait(0.5)
                                            COMMF_:InvokeServer("StartQuest", LocalPlayer.Data.Level.Value >= 2275 and "CakeQuest2" or tostring(GetQuest().NameQuest), LocalPlayer.Data.Level.Value >= 2275 and 2 or GetQuest().ID)
                                        end
                                    end)
                                end
                            else SetText("Hop for lower enemies for Katakuri") task.wait(5) HopServer()
                            end
                        end
                    else
                        SetText("Teleport to Sea 3") task.wait(3) COMMF_:InvokeServer("TravelZou") task.wait(10)
                     end
                end
            elseif CyborgBlockPartUnlocked == "chest" then
                if CheckSea(2) then
                    if CheckTool("Fist of Darkness") then
                        EquipWeapon("Fist of Darkness")
                        SafeClickDetector(workspace.Map.CircleIsland.RaidSummon.Button.Main.ClickDetector)
                    else
                        local inWindow, uptime, uptimeSource, timeInfo = CheckChestTimeWindow()

                        if not uptime then
                            SetText(
                                "Cyborg Chest | Cannot read server uptime\n"
                                .. tostring(uptimeSource)
                            )
                            task.wait(3)
                            return
                        elseif not inWindow then
                            local nextText =
                                timeInfo
                                and FormatUptime(timeInfo.NextBoundary)
                                or "unknown"

                            SetText(
                                "Cyborg Chest | Outside 4h + 2h window\n"
                                .. "Uptime: "
                                .. FormatUptime(uptime)
                                .. " | Next: "
                                .. nextText
                                .. "\nHop server..."
                            )

                            task.wait(1)
                            HopServer(8)
                            return
                        end

                        local chests, c = {}, 0
                        if not Character or IsDied(Character) then
                            print("Not found character")
                            task.wait(3)
                            return
                        end
                        Tween(false)
                        for _, v in next, CollectionService:GetTagged("_ChestTagged") do
                            if v and v.CanTouch then
                                local dist = (v.Position - HumanoidRootPart.Position).Magnitude
                                table.insert(chests, {obj = v, dist = dist})
                            end
                        end
                        
                        if #chests > 0 and all < getgenv().Settings["Max Chests"] and not CheckTool("Fist of Darkness") then
                            table.sort(chests, function(a, b) return a.dist < b.dist end)
                            for i, t in next, chests do local v = t.obj
                                if v:IsA("BasePart") and v.Name:find("Chest") then
                                    if v.CanTouch then
                                        repeat task.wait()
                                            SetText("Collect Chests | Collected: " .. c.."/"..all .. "/"..getgenv().Settings["Max Chests"].." Chests")
                                            TweenChest(v, function()
                                                return CheckTool("Fist of Darkness") or IsDied(Character)
                                            end)
                                            -- Chest VAN con ton tai sau khi da cham = ghost/khong an duoc -> moi ep bo qua
                                            if v and v.Parent and v.CanTouch then
                                                task.wait(tonumber(getgenv().Settings["Skip Chest Delay"]) or 1)
                                                if v and v.Parent and v.CanTouch then
                                                    v.CanTouch = false
                                                end
                                            end
                                        until not v.Parent or not v.CanTouch or CheckTool("Fist of Darkness") or IsDied(Character)
                                        
                                        if all >= getgenv().Settings["Max Chests"] then 
                                            SetText("Stopped: Max Chests reached") HopServer(8) break
                                        elseif CheckTool("Fist of Darkness") then 
                                            SetText("Stopped: Fist of Darkness detected") break
                                        elseif CheckMonster("Darkbeard") then 
                                            break
                                        end
                                        
                                        if not IsDied(Character) then
                                            c += 1 all += 1
                                            if c >= getgenv().Settings["Reset After Collect Chests"] and not CheckTool("Fist of Darkness") then
                                                if Character and Character:FindFirstChildWhichIsA("Humanoid") then
                                                    Character:FindFirstChildWhichIsA("Humanoid"):ChangeState(Enum.HumanoidStateType.Dead)
                                                    SetText("Collect Chests | Reset: Collected: "..tostring(getgenv().Settings["Reset After Collect Chests"]) .." Chests")
                                                end
                                                c = 0 task.wait(1)
                                            end
                                        else
                                            break
                                        end
                                    end
                                    if i % 250 == 0 then task.wait(0.1) end
                                end
                            end
                        else
                            if not CheckTool("Fist of Darkness") and not CheckMonster("Darkbeard") then HopServer(10) end
                        end
                    end
                else SetText("Travel to sea 2") task.wait(3) COMMF_:InvokeServer("TravelDressrosa")
                end
            else
                if CheckSea(2) then
                    SafeClickDetector(workspace.Map.CircleIsland.RaidSummon.Button.Main.ClickDetector)
                else SetText("Travel to sea 2") task.wait(3) COMMF_:InvokeServer("TravelDressrosa")
                end
            end
        end, function(err)
            safeWarn("[MainLoop]", err)
            SafeNotify("ERROR", tostring(err), 5)
            return tostring(err)
        end)
    end
end)

task.spawn(function()
    while task.wait(4) do
        xpcall(function()
            if RaceFlow.mode ~= "GET_CYBORG" then
                return
            end
            if not Character.Humanoid or Character.Humanoid.Health <= 0 then pcall(function() workspace.TweenGhost:Destroy() end) connection, tween, pathPart, isTweening = nil, nil, nil, false return end
            if not Character:FindFirstChild("HasBuso") then COMMF_:InvokeServer("Buso") end
            for _, v in next, {"Buso", "Geppo", "Soru"} do
                if not CollectionService:HasTag(Character, v) then
                    if LocalPlayer.Data.Beli.Value >= ((function(t)
                        return t == "Geppo" and 1e4 or t == "Buso" and 2.5e4 or t == "Soru" and 1e5 or 0
                    end)(v)) then SetText("Buy Abilies: ".. v) COMMF_:InvokeServer("BuyHaki", v)
                    end
                end
            end
        end, function(err) warn("LL: ".. err) end)
    end
end)

TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, message)
    if teleportResult == Enum.TeleportResult.GameFull then inHopPP = false
    elseif teleportResult == Enum.TeleportResult.IsTeleporting
        and type(message) == "string"
        and message:find("previous teleport", 1, true) then
        SafeNotify("Death Hop Found", message, 8)
        task.delay(10, function() game:Shutdown() end)
    end
end)

GuiService.ErrorMessageChanged:Connect(newcclosure(function()
    if GuiService:GetErrorType() == Enum.ConnectionError.DisconnectErrors then
        while true do ReplicatedStorage:WaitForChild("__ServerBrowser"):InvokeServer('teleport', JobId) task.wait(5) end
    end
end))
