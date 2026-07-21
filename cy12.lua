--[[
    KAITUN CYBORG - SOUL GUITAR CHEST + REAL SERVER TIME
    ----------------------------------------------------
    - Thay routine auto chest Cyborg bang routine chest cua Soul Guitar.
    - Farm chest theo cua so LAP MOI 4 GIO, moi cua so dai 1 gio:
        04:00:00 -> truoc 05:00:00
        08:00:00 -> truoc 09:00:00
        12:00:00 -> truoc 13:00:00
        16:00:00 -> truoc 17:00:00
        ...
      Vi du 04:59 van farm; 05:10 hop.
      07:59 hop; 08:00 bat dau farm lai.
    - Uptime dung Locations.@TimeIn + Workspace:GetServerTimeNow().
    - Hop server toi da 500 page, quet song song, loc server it nguoi,
      tranh JobId hien tai va JobId vua thu.
]]

local ENV

if type(getgenv) == "function" then
    local ok, result = pcall(getgenv)

    if ok and type(result) == "table" then
        ENV = result
    end
end

ENV = ENV
    or (type(shared) == "table" and shared)
    or (type(_G) == "table" and _G)
    or {}

print("[KAITUN BOOT] env-ready")

ENV.Settings = {
    -- Soul Guitar chest defaults
    ["Max Chests"] = 30;
    ["Skip Chest Delay"] = 2;
    ["Reset After Collect Chests"] = 10;

    ["Katakuri Progress"] = 100;
    ["Fragments"] = 1000;
    ["Black Screen"] = false;

    -- Cua so lap moi 4 gio, keo dai 1 gio:
    -- 04:00-05:00, 08:00-09:00, 12:00-13:00...
    ["Chest Server Period Seconds"] = 4 * 60 * 60;
    ["Chest Server Grace Seconds"] = 1 * 60 * 60;
    ["Server Time Wait Timeout"] = 20;
    ["Server Time Retry Interval"] = 0.5;

    -- Hop server cai tien.
    ["Hop Max Pages"] = 500;
    ["Hop Workers"] = 10;
    ["Hop Timeout"] = 15;
    ["Hop Candidate Target"] = 60;
    ["Hop Best Pool"] = 10;
    ["Hop Visited Expire"] = 1800;
}
-- ============================================================
-- EXECUTOR COMPATIBILITY
-- Khong de script dung neu Volt/executor thieu mot API optional.
-- ============================================================
local MemoryFiles = ENV.__KaitunCyborgMemoryFiles or {}
ENV.__KaitunCyborgMemoryFiles = MemoryFiles

local RawIsFile = type(isfile) == "function" and isfile or nil
local RawReadFile = type(readfile) == "function" and readfile or nil
local RawWriteFile = type(writefile) == "function" and writefile or nil

local function SafeIsFile(path)
    if MemoryFiles[path] ~= nil then
        return true
    end

    if RawIsFile then
        local ok, result = pcall(RawIsFile, path)
        return ok and result == true
    end

    return false
end

local function SafeReadFile(path)
    if RawReadFile then
        local ok, result = pcall(RawReadFile, path)

        if ok and result ~= nil then
            MemoryFiles[path] = result
            return result
        end
    end

    return MemoryFiles[path]
end

local function SafeWriteFile(path, content)
    content = tostring(content or "")
    MemoryFiles[path] = content

    if RawWriteFile then
        local ok, err = pcall(RawWriteFile, path, content)

        if not ok then
            warn("[Compatibility] writefile failed:", err)
        end

        return ok
    end

    warn(
        "[Compatibility] Executor has no writefile; using memory only:",
        path
    )
    return false
end

local function SafeNotify(title, text, duration)
    pcall(function()
        game:GetService("StarterGui"):SetCore(
            "SendNotification",
            {
                Title = tostring(title or "Kaitun"),
                Text = tostring(text or ""),
                Duration = tonumber(duration) or 5,
            }
        )
    end)
end

local function BootStage(name)
    print("[KAITUN BOOT]", tostring(name))
end

local function SafeSet3DRendering(enabled)
    local method = RunService
        and RunService.Set3dRenderingEnabled

    if type(method) == "function" then
        local ok, err = pcall(method, RunService, enabled)

        if not ok then
            warn("[Compatibility] Set3dRenderingEnabled failed:", err)
        end

        return ok
    end

    warn("[Compatibility] Set3dRenderingEnabled unavailable")
    return false
end

local function SafeFireSignal(signal)
    if type(firesignal) ~= "function" or not signal then
        return false
    end

    local ok, err = pcall(firesignal, signal)

    if not ok then
        warn("[Compatibility] firesignal failed:", err)
    end

    return ok
end

local function SafeFireClick(clickDetector)
    if type(fireclickdetector) ~= "function"
        or not clickDetector then
        return false
    end

    local ok, err = pcall(fireclickdetector, clickDetector)

    if not ok then
        warn("[Compatibility] fireclickdetector failed:", err)
    end

    return ok
end

local function SafeFireTouch(part1, part2, state)
    if type(firetouchinterest) ~= "function"
        or not part1
        or not part2 then
        return false
    end

    local ok, err = pcall(
        firetouchinterest,
        part1,
        part2,
        state or 0
    )

    if not ok then
        warn("[Compatibility] firetouchinterest failed:", err)
    end

    return ok
end

BootStage("compatibility-ready")

repeat task.wait(0.5) until game:IsLoaded() and game.Players.LocalPlayer and game.Players.LocalPlayer:FindFirstChildWhichIsA("PlayerGui")
if ENV.WARCLOADER then
    SafeNotify(
        "Execution Blocked",
        "The script is already running. Please wait 10 seconds",
        5
    )
    return
end

ENV.WARCLOADER = true

task.spawn(function()
    task.wait(10)
    ENV.WARCLOADER = nil
end)

local SafeCloneRef =
    (type(cloneref) == "function" and cloneref)
    or (type(clonereference) == "function" and clonereference)
    or function(x) return x end

ENV.cloneref = SafeCloneRef
ENV.isnetworkowner =
    (type(isnetworkowner) == "function" and isnetworkowner)
    or (type(isNetworkOwner) == "function" and isNetworkOwner)
    or function() return true end

local EnvWorkspace
if type(getrenv) == "function" then
    local ok, env = pcall(getrenv)
    if ok and type(env) == "table" then
        EnvWorkspace = env.workspace or env.Workspace
    end
end

workspace = SafeCloneRef(
    workspace
    or Workspace
    or EnvWorkspace
    or game:GetService("Workspace")
)
PlaceId, JobId = game.PlaceId, game.JobId
getfenv = getfenv or _G or _ENV or shared or function() return {} end
IsOnMobile = false
Services = setmetatable({}, {__index = function(self, name)
    local s, c = pcall(function() return SafeCloneRef(game:GetService(name)) end)
    if s then rawset(self, name, c) return c
    else error("Invalid Roblox Service: " .. tostring(name))
    end
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
COMMF_ = ReplicatedStorage:WaitForChild("Remotes") and ReplicatedStorage.Remotes:WaitForChild("CommF_")
LocalPlayer = Players.LocalPlayer
LocalPlayer.CharacterAdded:Connect(function(v)
    Character = v Humanoid = v:WaitForChild("Humanoid")
    HumanoidRootPart = v:WaitForChild("HumanoidRootPart")
end)
if LocalPlayer.Character then
    Character = LocalPlayer.Character
    Humanoid = Character:FindFirstChild("Humanoid") or Character:WaitForChild("Humanoid")
    HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart") or Character:WaitForChild("HumanoidRootPart")
end

BootStage("services-ready")
SafeNotify("Executed", "Loading... Please wait", 5)
if not game:IsLoaded() or workspace.DistributedGameTime <= 10 then
    local WFGTL = COREGUI:FindFirstChild("WFGTL") or Instance.new("Hint", COREGUI)
    WFGTL.Text = "Just a moment... Waiting while the game loads - This won't take long!"
    task.wait(10 - workspace.DistributedGameTime)
    WFGTL:Destroy()
end
if not COMMF_ then repeat task.wait(1) until COMMF_ end

local GuideModuleInstance =
    ReplicatedStorage:FindFirstChild("GuideModule")
local gmod

if GuideModuleInstance then
    local ok, result = pcall(require, GuideModuleInstance)
    if ok and type(result) == "table" then
        gmod = result
    else
        warn("[Compatibility] GuideModule require failed:", result)
    end
end

task.spawn(function()
    if type(gethui) == "function" then
        local ok, hui = pcall(gethui)

        if ok and hui then
            pcall(function()
                hui.IgnoreGuiInset = true
            end)
        end
    else
        warn("[Compatibility] gethui unavailable; using normal GUI parent")
    end
end)

task.spawn(function()
    xpcall(function()
        if not LocalPlayer.Team then
            if LocalPlayer.PlayerGui:FindFirstChild("LoadingScreen") then
                repeat task.wait(1) until not LocalPlayer.PlayerGui:FindFirstChild("LoadingScreen")
            end
            xpcall(
                function()
                    COMMF_:InvokeServer("SetTeam", "Pirates")
                end,
                function()
                    local gui = LocalPlayer.PlayerGui
                    local minimal = gui
                        and gui:FindFirstChild("Main (minimal)")
                    local chooseTeam = minimal
                        and minimal:FindFirstChild("ChooseTeam")
                    local container = chooseTeam
                        and chooseTeam:FindFirstChild("Container")
                    local pirates = container
                        and container:FindFirstChild("Pirates")

                    if pirates then
                        SafeFireSignal(pirates.MouseButton1Click)
                    end
                end
            )
            task.wait(2)
        end
    end, function(err) warn("????", err) end)
end)
repeat task.wait(2) until Character and Character:FindFirstChild("HumanoidRootPart") and Character:FindFirstChildWhichIsA("Humanoid") and Character:IsDescendantOf(workspace.Characters)

pcall(function() LocalPlayer.PlayerGui:FindFirstChild("Blank"):Destroy() end)
local BlankScreen = LocalPlayer.PlayerGui:FindFirstChild("Blank") or Instance.new("ScreenGui", LocalPlayer.PlayerGui)
BlankScreen.Name = "Blank" BlankScreen.ResetOnSpawn = false BlankScreen.DisplayOrder = -math.huge BlankScreen.IgnoreGuiInset = true
local Black = BlankScreen:FindFirstChild("Black Screen") or Instance.new("Frame", BlankScreen)
Black.Name = "Black Screen" Black.Size = UDim2.new(1, 0, 1, 0) Black.BackgroundColor3 = Color3.new(0, 0, 0) Black.ZIndex = -math.huge
Black.Visible = ENV.Settings["Black Screen"] or false

SafeSet3DRendering(not Black.Visible)

local label = Instance.new("TextLabel", BlankScreen)
label.Name = "CenteredLabel"
label.AnchorPoint = Vector2.new(0.5, 0.5)
label.Position = UDim2.new(0.5, 0, 0.5, 0)
label.Size = UDim2.new(0.6, 0, 0.15, 0)
label.Text = string.rep("Nil ", 20)
label.TextScaled = true;
label.TextWrapped = true;
label.TextXAlignment = Enum.TextXAlignment.Center;
label.TextYAlignment = Enum.TextYAlignment.Center;
label.BackgroundTransparency = 1;
label.Font = Enum.Font.GothamSemibold;
label.TextSize = 48;
label.TextColor3 = Color3.fromRGB(255, 255, 255)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.F4 then
        Black.Visible = not Black.Visible
        SafeSet3DRendering(not Black.Visible)
        StarterGui:SetCore("SendNotification", {
            Title = "Black Screen",
            Text = Black.Visible and "Đã BẬT màn hình đen (Tắt Render 3D)" or "Đã TẮT màn hình đen (Bật Render 3D)",
            Duration = 2
        })
    end
end)

local function SetText(newText) label.Text = newText end

-- ============================================================
-- REAL SERVER UPTIME
-- Source: Workspace._WorldOrigin.Locations.<Location>.@TimeIn
-- Uptime: Workspace:GetServerTimeNow() - TimeIn
-- ============================================================
local SERVER_TIME_PRIORITY_LOCATIONS = {
    "Ancient Clock",
    "Castle on the Sea",
    "Temple of Time",
    "Floating Turtle",
    "Mansion",
    "Port Town",
    "Sea",
}

local ServerTimeState = {
    StartedAt = nil,
    Source = nil,
    MatchingLocations = 0,
    LastDetectAttempt = 0,
    LastUptime = nil,
}

local function FormatServerUptime(seconds)
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

local function GetRealServerNow()
    local ok, value = pcall(function()
        return workspace:GetServerTimeNow()
    end)

    if ok and type(value) == "number" then
        return value
    end

    return nil
end

local function GetLocationsFolder()
    local worldOrigin = workspace:FindFirstChild("_WorldOrigin")
    return worldOrigin and worldOrigin:FindFirstChild("Locations") or nil
end

local function IsValidTimeIn(value)
    if type(value) ~= "number" or value < 1000000000 then
        return false
    end

    local now = GetRealServerNow()
    if not now then
        return true
    end

    local age = now - value
    return age >= -10 and age < 31536000
end

local function DetectServerStartTime()
    local locations = GetLocationsFolder()
    if not locations then
        return nil, nil, 0
    end

    -- Fast path: cac Location da xac nhan co TimeIn.
    for _, name in ipairs(SERVER_TIME_PRIORITY_LOCATIONS) do
        local location = locations:FindFirstChild(name)

        if location then
            local value = location:GetAttribute("TimeIn")

            if IsValidTimeIn(value) then
                local rounded = math.floor(value + 0.5)
                local count = 0

                for _, other in ipairs(locations:GetChildren()) do
                    local otherValue = other:GetAttribute("TimeIn")

                    if type(otherValue) == "number"
                        and math.floor(otherValue + 0.5) == rounded then
                        count = count + 1
                    end
                end

                return value,
                    "Workspace._WorldOrigin.Locations."
                        .. name
                        .. ".@TimeIn",
                    count
            end
        end
    end

    -- Fallback: lay cum TimeIn duoc nhieu Location dung chung nhat.
    local groups = {}

    for _, location in ipairs(locations:GetChildren()) do
        local value = location:GetAttribute("TimeIn")

        if IsValidTimeIn(value) then
            local rounded = math.floor(value + 0.5)

            groups[rounded] = groups[rounded] or {
                Count = 0,
                Total = 0,
                Example = location.Name,
            }

            groups[rounded].Count = groups[rounded].Count + 1
            groups[rounded].Total = groups[rounded].Total + value
        end
    end

    local best

    for _, group in pairs(groups) do
        if not best or group.Count > best.Count then
            best = group
        end
    end

    if not best then
        return nil, nil, 0
    end

    return best.Total / best.Count,
        "Workspace._WorldOrigin.Locations."
            .. best.Example
            .. ".@TimeIn",
        best.Count
end

local function EnsureServerStartTime(timeout)
    if ServerTimeState.StartedAt then
        return true
    end

    timeout = tonumber(timeout)
        or tonumber(ENV.Settings["Server Time Wait Timeout"])
        or 20

    local retryInterval =
        tonumber(ENV.Settings["Server Time Retry Interval"])
        or 0.5

    local deadline = os.clock() + math.max(0, timeout)

    repeat
        local startedAt, source, count = DetectServerStartTime()

        if startedAt then
            ServerTimeState.StartedAt = startedAt
            ServerTimeState.Source = source
            ServerTimeState.MatchingLocations = count
            ServerTimeState.LastDetectAttempt = os.clock()

            print(
                "[ServerTime] Source:",
                source,
                "| Matching:",
                count
            )

            return true
        end

        task.wait(retryInterval)
    until os.clock() >= deadline

    ServerTimeState.LastDetectAttempt = os.clock()
    return false
end

local function GetRealServerUptime(forceDetect)
    if not ServerTimeState.StartedAt then
        local waitTime = forceDetect
            and (
                tonumber(
                    ENV.Settings["Server Time Wait Timeout"]
                ) or 20
            )
            or 0

        if not EnsureServerStartTime(waitTime) then
            return nil
        end
    end

    local now = GetRealServerNow()
    if not now then
        return nil
    end

    local uptime = math.max(0, now - ServerTimeState.StartedAt)
    ServerTimeState.LastUptime = uptime

    ENV.CyborgChestServerUptime = uptime
    ENV.CyborgChestServerTimeSource = ServerTimeState.Source

    return uptime
end

local function CheckCyborgChestServerTime()
    local uptime = GetRealServerUptime(true)

    if not uptime then
        return false,
            nil,
            "Khong doc duoc TimeIn/GetServerTimeNow",
            nil
    end

    local periodSeconds =
        math.max(
            1,
            tonumber(
                ENV.Settings["Chest Server Period Seconds"]
            ) or (4 * 60 * 60)
        )

    local graceSeconds =
        math.max(
            1,
            tonumber(
                ENV.Settings["Chest Server Grace Seconds"]
            ) or (1 * 60 * 60)
        )

    -- Moc dau tien chi bat dau khi server dat du 4 gio.
    local completedPeriods = math.floor(uptime / periodSeconds)
    local remainder = uptime - completedPeriods * periodSeconds

    local currentBoundary = completedPeriods * periodSeconds
    local nextBoundary = (completedPeriods + 1) * periodSeconds
    local currentWindowEnd = currentBoundary + graceSeconds

    local info = {
        PeriodSeconds = periodSeconds,
        GraceSeconds = graceSeconds,
        CompletedPeriods = completedPeriods,
        Remainder = remainder,
        CurrentBoundary = currentBoundary,
        CurrentWindowEnd = currentWindowEnd,
        NextBoundary = nextBoundary,
        InWindow = completedPeriods >= 1
            and remainder < graceSeconds,
    }

    ENV.CyborgChestTimeWindow = info

    if completedPeriods < 1 then
        return false,
            uptime,
            "Server chua du moc 4 gio dau tien",
            info
    end

    if remainder >= graceSeconds then
        return false,
            uptime,
            "Ngoai cua so "
                .. FormatServerUptime(currentBoundary)
                .. "-"
                .. FormatServerUptime(currentWindowEnd)
                .. " | Moc ke tiep "
                .. FormatServerUptime(nextBoundary),
            info
    end

    return true,
        uptime,
        "Server hop le "
            .. FormatServerUptime(currentBoundary)
            .. "-"
            .. FormatServerUptime(currentWindowEnd),
        info
end

-- Doc truoc de lan dau vao nhanh chest khong bi cho lau.
task.spawn(function()
    EnsureServerStartTime(
        tonumber(ENV.Settings["Server Time Wait Timeout"])
        or 20
    )

    local uptime = GetRealServerUptime(false)
    if uptime then
        print(
            "[ServerTime] Current uptime:",
            FormatServerUptime(uptime)
        )
    end
end)
BootStage("server-time-ready")
local mainfile = LocalPlayer.Name .. ".txt"
if not SafeIsFile(mainfile) then
    SafeWriteFile(mainfile, "NaN")
end
BootStage("state-file-ready")
function CheckSea(v) return v == tonumber(workspace:GetAttribute("MAP"):match("%d+")) end

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
local seed = ReplicatedStorage.Modules.Net.seed:InvokeServer()
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
    if not HumanoidRootPart or not Character:FindFirstChildWhichIsA("Humanoid") or Character.Humanoid.Health <= 0 or not Character:FindFirstChildWhichIsA("Tool") then return end
    local FAD = 0.01 -- throttle
    if FAD ~= 0 and tick() - lastCallFA <= FAD then return end
    local t = {}
    for _, e in next, workspace.Enemies:GetChildren() do
        local h = e:FindFirstChild("Humanoid") local hrp = e:FindFirstChild("HumanoidRootPart")
        if e ~= Character and (x and e.Name == x or not x) and h and hrp and not IsDied(e) and (hrp.Position - HumanoidRootPart.Position).Magnitude <= 65 then t[#t + 1] = e end
    end
    local n = ReplicatedStorage.Modules.Net
    local h = {[2] = {}}
    local last
    for i = 1, #t do local v = t[i]
        local part = v:FindFirstChild("Head") or v:FindFirstChild("HumanoidRootPart")
        if not h[1] then h[1] = part end
        h[2][#h[2] + 1] = {v, part} last = v
    end
    n:FindFirstChild("RE/RegisterAttack"):FireServer()
    n:FindFirstChild("RE/RegisterHit"):FireServer(unpack(h))
    SafeCloneRef(remoteAttack):FireServer(string.gsub("RE/RegisterHit", ".",function(c)
        return string.char(bit32.bxor(string.byte(c), math.floor(workspace:GetServerTimeNow()/10%10)+1))
    end), bit32.bxor(idremote+909090, seed*2), unpack(h))
    lastCallFA = tick()
end)

local lastHop, inHopPP = tick(), false

-- ============================================================
-- FAST SERVER HOP - 500 PAGES
-- ============================================================
local ServerBrowser = ReplicatedStorage:WaitForChild("__ServerBrowser")
local CYBORG_VISITED_FILE = "CyborgChest_VisitedServers.json"
local CyborgVisitedServers = {}
local CyborgHopLock = false
local CyborgLastHopArgs = nil

local function LoadCyborgVisitedServers()
    if not SafeIsFile(CYBORG_VISITED_FILE) then
        return
    end

    local ok, decoded = pcall(function()
        return HttpService:JSONDecode(
            SafeReadFile(CYBORG_VISITED_FILE)
        )
    end)

    if ok and type(decoded) == "table" then
        CyborgVisitedServers = decoded
    end
end

local function PruneCyborgVisitedServers()
    local now = os.time()
    local expire =
        tonumber(ENV.Settings["Hop Visited Expire"])
        or 1800

    for id, timestamp in pairs(CyborgVisitedServers) do
        if type(timestamp) ~= "number"
            or now - timestamp > expire then
            CyborgVisitedServers[id] = nil
        end
    end
end

local function SaveCyborgVisitedServers()
    PruneCyborgVisitedServers()

    pcall(function()
        SafeWriteFile(
            CYBORG_VISITED_FILE,
            HttpService:JSONEncode(CyborgVisitedServers)
        )
    end)
end

local function MarkCyborgServerVisited(id)
    if type(id) ~= "string" or id == "" then
        return
    end

    CyborgVisitedServers[id] = os.time()
    SaveCyborgVisitedServers()
end

local function ShufflePages(array)
    for index = #array, 2, -1 do
        local other = math.random(1, index)
        array[index], array[other] =
            array[other], array[index]
    end
end

LoadCyborgVisitedServers()
PruneCyborgVisitedServers()
MarkCyborgServerVisited(JobId)

function GetServers(MaxPlayers, ForcedRegion)
    MaxPlayers = tonumber(MaxPlayers) or 8

    local maxPages =
        math.max(
            1,
            tonumber(ENV.Settings["Hop Max Pages"])
                or 500
        )

    local workerCount =
        math.max(
            1,
            math.min(
                tonumber(ENV.Settings["Hop Workers"])
                    or 10,
                maxPages
            )
        )

    local timeout =
        math.max(
            3,
            tonumber(ENV.Settings["Hop Timeout"])
                or 15
        )

    local candidateTarget =
        math.max(
            1,
            tonumber(
                ENV.Settings["Hop Candidate Target"]
            ) or 60
        )

    local pages = {}
    for page = 1, maxPages do
        pages[page] = page
    end
    ShufflePages(pages)

    local candidates = {}
    local known = {}
    local nextIndex = 1
    local workersDone = 0
    local pagesScanned = 0
    local stop = false
    local deadline = os.clock() + timeout

    local function AddCandidate(id, data)
        if type(id) ~= "string"
            or id == ""
            or id == JobId
            or known[id]
            or CyborgVisitedServers[id]
            or type(data) ~= "table" then
            return
        end

        local playerCount = tonumber(data.Count)

        if not playerCount
            or playerCount > MaxPlayers then
            return
        end

        if ForcedRegion
            and tostring(data.Region) ~= tostring(ForcedRegion) then
            return
        end

        known[id] = true

        table.insert(candidates, {
            JobId = id,
            Players = playerCount,
            LastUpdate = data.__LastUpdate,
            Region = data.Region,
        })

        if #candidates >= candidateTarget then
            stop = true
        end
    end

    for _ = 1, workerCount do
        task.spawn(function()
            while not stop
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

                pagesScanned = pagesScanned + 1

                if ok and type(data) == "table" then
                    for id, serverData in pairs(data) do
                        AddCandidate(id, serverData)
                    end
                end
            end

            workersDone = workersDone + 1
        end)
    end

    while workersDone < workerCount
        and os.clock() < deadline do
        SetText(
            string.format(
                "Fetching Server... %d/%d pages | %d candidates",
                pagesScanned,
                maxPages,
                #candidates
            )
        )
        task.wait(0.05)
    end

    table.sort(candidates, function(a, b)
        if a.Players == b.Players then
            return tostring(a.JobId) < tostring(b.JobId)
        end

        return a.Players < b.Players
    end)

    print(
        "[HopServer] Pages:",
        pagesScanned,
        "/",
        maxPages,
        "| Candidates:",
        #candidates
    )

    return candidates
end

HopServer = function(MaxPlayers, ForcedRegion, Reason)
    if CyborgHopLock then
        return false
    end

    MaxPlayers = tonumber(MaxPlayers) or 8
    Reason = tostring(Reason or "Khong co ly do")

    CyborgHopLock = true
    CyborgLastHopArgs = {
        MaxPlayers = MaxPlayers,
        ForcedRegion = ForcedRegion,
        Reason = Reason,
    }

    Tween(false)

    SetText(
        "Hop Server | "
            .. Reason
            .. "\nScanning up to "
            .. tostring(
                ENV.Settings["Hop Max Pages"] or 500
            )
            .. " pages..."
    )

    local servers = GetServers(MaxPlayers, ForcedRegion)

    -- Neu cache visited lam het candidate, xoa cache cu va thu lai 1 lan.
    if #servers == 0 then
        CyborgVisitedServers = {
            [JobId] = os.time(),
        }
        SaveCyborgVisitedServers()
        servers = GetServers(MaxPlayers, ForcedRegion)
    end

    if #servers == 0 then
        CyborgHopLock = false
        SetText("Hop Server | Khong tim thay server phu hop")

        task.delay(2, function()
            HopServer(MaxPlayers, ForcedRegion, Reason)
        end)

        return false
    end

    local bestPool =
        math.max(
            1,
            math.min(
                tonumber(ENV.Settings["Hop Best Pool"])
                    or 10,
                #servers
            )
        )

    -- Uu tien nhom it nguoi nhat, random trong nhom de tranh nhieu acc
    -- cung chon mot JobId.
    local selected = servers[math.random(1, bestPool)]

    MarkCyborgServerVisited(selected.JobId)

    SetText(
        string.format(
            "Found Server | %d players | %s\n%s",
            selected.Players,
            tostring(selected.Region or "Unknown"),
            selected.JobId
        )
    )

    print(
        "[HopServer] Teleporting:",
        selected.JobId,
        "| Players:",
        selected.Players,
        "| Region:",
        selected.Region,
        "| Reason:",
        Reason
    )

    local ok, result = pcall(function()
        return ServerBrowser:InvokeServer(
            "teleport",
            selected.JobId
        )
    end)

    if not ok then
        warn("[HopServer] Teleport invoke failed:", result)
        CyborgHopLock = false

        task.delay(2, function()
            HopServer(MaxPlayers, ForcedRegion, Reason)
        end)

        return false
    end

    return true
end

TeleportService.TeleportInitFailed:Connect(function(
    player,
    result,
    message
)
    if player ~= LocalPlayer then
        return
    end

    warn(
        "[HopServer] TeleportInitFailed:",
        tostring(result),
        tostring(message)
    )

    CyborgHopLock = false

    local args = CyborgLastHopArgs
    if args then
        task.delay(2, function()
            HopServer(
                args.MaxPlayers,
                args.ForcedRegion,
                "Teleport fail: " .. tostring(message)
            )
        end)
    end
end)

local connection, tween, pathPart, isTweening = nil, nil, nil, false
function Tween(targetCFrame, target)
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

-- Old Cyborg chest tween helper removed; Soul Guitar routine is used below.
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
                local duplicatePosition = false
                for _, chosen in ipairs(mob) do
                    local chosenRoot = chosen:FindFirstChild("HumanoidRootPart")
                    if chosenRoot
                        and (hrp.Position - chosenRoot.Position).Magnitude <= 5 then
                        duplicatePosition = true
                        break
                    end
                end

                if not duplicatePosition then
                    mob[#mob + 1] = v
                    t = t or hrp.CFrame
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
    local npcList =
        gmod
        and gmod.Data
        and gmod.Data.NPCList
        or {}

    for _, x in next, npcList do
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

local function HandleCyborgNotification(message)
    local args = tostring(message or "")
    local lowered = string.lower(args)

    if not CheckSea(2) then
        return
    end

    if lowered:find("supply a <core brain>", 1, true)
        or lowered:find(
            "<fist of darkness> has been",
            1,
            true
        ) then
        CyborgBlockPartUnlocked = "unlock"
        SafeWriteFile(mainfile, "unlock")
    elseif lowered:find("microchip not found", 1, true) then
        CyborgBlockPartUnlocked = "chest"
        SafeWriteFile(mainfile, "chest")
    end
end

-- Cach an toan: bat Notify tu server gui xuong.
local CommERemote =
    ReplicatedStorage:FindFirstChild("Remotes")
    and ReplicatedStorage.Remotes:FindFirstChild("CommE")

if CommERemote and CommERemote:IsA("RemoteEvent") then
    CommERemote.OnClientEvent:Connect(function(...)
        local args = {...}

        if args[1] == "Notify" then
            HandleCyborgNotification(args[2])
        else
            for _, value in ipairs(args) do
                if type(value) == "string" then
                    HandleCyborgNotification(value)
                end
            end
        end
    end)
end

-- Fallback hook chi bat khi executor thuc su ho tro.
local NotificationInstance =
    ReplicatedStorage:FindFirstChild("Notification")
local NotificationModule
local OriginalNotificationNew

if NotificationInstance then
    local ok, result = pcall(require, NotificationInstance)
    if ok and type(result) == "table" then
        NotificationModule = result
    end
end

if NotificationModule
    and type(NotificationModule.new) == "function"
    and type(hookfunction) == "function"
    and type(newcclosure) == "function" then

    local ok, originalOrError = pcall(function()
        OriginalNotificationNew = hookfunction(
            NotificationModule.new,
            newcclosure(function(...)
                local first = ({...})[1]
                HandleCyborgNotification(first)
                return OriginalNotificationNew(...)
            end)
        )

        return OriginalNotificationNew
    end)

    if ok then
        print("[Compatibility] Notification hook enabled")
    else
        warn(
            "[Compatibility] Notification hook failed; "
                .. "RemoteEvent detector remains active:",
            originalOrError
        )
    end
else
    print(
        "[Compatibility] hookfunction/newcclosure unavailable; "
            .. "using RemoteEvent notification detector"
    )
end

BootStage("notification-detector-ready")
local all = 0
local fragok = false;
task.spawn(function()
    while task.wait(0.5) do
        xpcall(function()
            if LocalPlayer.Data.Race.Value ~= "Cyborg" and LocalPlayer.Data.Fragments.Value >= 2500 then COMMF_:InvokeServer("CyborgTrainer", "Buy") end
            CyborgBlockPartUnlocked = SafeReadFile(mainfile) or "NaN"
            SafeFireClick(workspace.Map.CircleIsland.RaidSummon.Button.Main.ClickDetector)
            if LocalPlayer.Data.Race.Value == "Cyborg" then
                if COMMF_:InvokeServer("Wenlocktoad") == nil then
                    if CheckSea(2) then
                        if not LocalPlayer.Data.Race:FindFirstChild("Evolved") then
                            SetText("Upgrading Race to V2")
                            if COMMF_:InvokeServer("Alchemist", "2") == "Come back when you find them." then
                                if not CheckTool("Flower 1") and workspace.Flower1.Transparency == 0 then
                                    Tween(false)
                                    SetText("Upgrade Race V2 | Collecting Flower 1")
                                    repeat
                                        task.wait(0.1)
                                        Character:SetPrimaryPartCFrame(workspace.Flower1.CFrame)
                                    until (CheckTool("Flower 1") or workspace.Flower1.Transparency ~= 0)
                                elseif not CheckTool("Flower 2") and workspace.Flower2.Transparency == 0 then
                                    Tween(false)
                                    SetText("Upgrade Race V2 | Collecting Flower 2")
                                    repeat
                                        task.wait(0.1)
                                        Character:SetPrimaryPartCFrame(workspace.Flower2.CFrame)
                                    until (CheckTool("Flower 2") or workspace.Flower2.Transparency ~= 0)
                                elseif not CheckTool("Flower 3") then
                                    for _, v in next, workspace.Enemies:GetChildren() do
                                        if v.Name == "Swan Pirate" then
                                            if v:FindFirstChildWhichIsA("Humanoid") and v.Humanoid.Health > 0 and v.HumanoidRootPart then
                                                repeat task.wait() KillMonster(v.Name)
                                                until not v or not v:FindFirstChildWhichIsA("Humanoid") or v.Humanoid.Health <= 0 or not v.HumanoidRootPart or CheckTool("Flower 3")
                                            end
                                        else
                                            Tween(CFrame.new(980.0985107421875, 121.331298828125, 1287.2093505859375))
                                        end
                                    end
                                else
                                    if CheckTool("Flower 1") and CheckTool("Flower 2") and CheckTool("Flower 3") then
                                        COMMF_:InvokeServer("Alchemist", "3")
                                    end
                                end
                            end
                        elseif COMMF_:InvokeServer("Wenlocktoad") == nil then
                            local venlock = COMMF_:InvokeServer("Wenlocktoad", "2")
                            if typeof(venlock) == "string" then SetText("Upgrade Race V3")
                                if venlock:find("haven't completed") ~= nil or venlock:find("Talk to me again") ~= nil then
                                    local t = math.huge local n;
                                    for _, v in next, COMMF_:InvokeServer("getInventory") do if v.Type == "Blox Fruit" then if v.Value < t then t = v.Value n = v.Name end end end
                                    COMMF_:InvokeServer("LoadFruit", n) COMMF_:InvokeServer("Wenlocktoad", "3")
                                end
                            end
                        else
                            SetText("IDK WHAT I AM DOING NOW")
                        end
                    else SetText("Travel to sea 2") task.wait(1) COMMF_:InvokeServer("TravelDressrosa")
                    end
                else
                    if CheckSea(3) then
                        SafeWriteFile(mainfile, "Completed-Cyborg")
                        SetText("DONE V3")
                    else SetText("Teleport to Sea 3") task.wait(3) COMMF_:InvokeServer("TravelZou") task.wait(10)
                    end
                end
            elseif CyborgBlockPartUnlocked == "unlock" or game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("CyborgTrainer", "Check") == true then
                local have, need = LocalPlayer.Data.Fragments.Value, ENV.Settings.Fragments
                if fragok then
                    if have < 2500 then fragok = false
                    end
                else
                    if have >= need then fragok = true
                    end
                end
                if fragok or CheckMonster("Order") or CheckTool("Microchip") then print("CC")
                    if CheckSea(2) then
                        if fragok == false and LocalPlayer.Data.Fragments.Value >= ENV.Settings.Fragments then
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
                            SafeFireClick(workspace.Map.CircleIsland.RaidSummon.Button.Main.ClickDetector)
                            game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("CyborgTrainer", "Buy")
                        end
                    else SetText("Travel to Dressrosa") task.wait(3) COMMF_:InvokeServer("TravelDressrosa")
                    end
                else print("CX[1]")
                    if CheckSea(3) then print("CX")
                        if CheckMonster("Dough King") or CheckMonster("rip_indra") or CheckMonster("Cake Prince") then
                            for _, v2 in next, {workspace.Enemies, ReplicatedStorage} do
                                for _, v in next, v2:GetChildren() do
                                    if v.Name == "Dough King" or v.Name == "Cake Prince" or v.Name:find("rip_indra") then
                                        if v.Name ~= "rip_indra" then if not CheckLocation("Dimensional Shift") then SafeFireTouch(LocalPlayer.Character.HumanoidRootPart, workspace.Map.CakeLoaf.BigMirror.Main, 0) task.wait(3) end end
                                        if v:FindFirstChildWhichIsA("Humanoid") and v.Humanoid.Health > 0 and v.HumanoidRootPart then
                                            repeat task.wait() KillMonster(v.Name)
                                            until not v or not v:FindFirstChildWhichIsA("Humanoid") or v.Humanoid.Health <= 0 or not v.HumanoidRootPart
                                        end
                                    end
                                end
                            end
                        else currentProgress = tonumber(COMMF_:InvokeServer("CakePrinceSpawner"):match("%d+") or 500) print(currentProgress)
                            if currentProgress <= ENV.Settings["Katakuri Progress"] then
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
                        SafeFireClick(workspace.Map.CircleIsland.RaidSummon.Button.Main.ClickDetector)
                    else
                        -- ====================================================
                        -- SOUL GUITAR CHEST ROUTINE + SERVER TIME GATE
                        -- Cua so lap moi 4 gio va dai 1 gio:
                        -- 04:00-05:00, 08:00-09:00, 12:00-13:00...
                        -- 04:59 van farm; 05:10 hop.
                        -- 07:59 hop; 08:00 farm lai.
                        -- ====================================================
                        local timeOK, uptime, timeReason =
                            CheckCyborgChestServerTime()

                        if not timeOK then
                            Tween(false)

                            SetText(
                                "Cyborg Chest | "
                                    .. tostring(timeReason)
                                    .. "\nUptime: "
                                    .. (
                                        uptime
                                        and FormatServerUptime(uptime)
                                        or "Unknown"
                                    )
                                    .. "
Windows: 04-05, 08-09, 12-13..."
                            )

                            task.wait(1)

                            HopServer(
                                8,
                                nil,
                                tostring(timeReason)
                                    .. " | Uptime "
                                    .. (
                                        uptime
                                        and FormatServerUptime(uptime)
                                        or "Unknown"
                                    )
                            )

                            return
                        end

                        local chests = {}
                        local c = 0

                        if not Character
                            or IsDied(Character)
                            or not HumanoidRootPart then
                            SetText("Soul Guitar Chest | Waiting character")
                            task.wait(2)
                            return
                        end

                        Tween(false)

                        for _, chest in next,
                            CollectionService:GetTagged("_ChestTagged") do
                            if chest
                                and chest:IsA("BasePart")
                                and chest.Parent
                                and chest.CanTouch
                                and chest.Name:find("Chest") then
                                local distance =
                                    (
                                        chest.Position
                                        - HumanoidRootPart.Position
                                    ).Magnitude

                                table.insert(chests, {
                                    obj = chest,
                                    dist = distance,
                                })
                            end
                        end

                        table.sort(chests, function(a, b)
                            return a.dist < b.dist
                        end)

                        local serverTimeExpired = false

                        if #chests > 0
                            and all
                                < ENV.Settings["Max Chests"]
                            and not CheckTool("Fist of Darkness") then

                            for index, entry in ipairs(chests) do
                                local chest = entry.obj

                                if chest
                                    and chest.Parent
                                    and chest.CanTouch
                                    and not CheckTool("Fist of Darkness") then

                                local skipScheduled = false

                                SetText(
                                    "Soul Guitar Chest | Server "
                                        .. FormatServerUptime(uptime)
                                )

                                repeat
                                    task.wait()

                                    local stillTimeOK, liveUptime =
                                        CheckCyborgChestServerTime()

                                    if not stillTimeOK then
                                        serverTimeExpired = true
                                        uptime = liveUptime or uptime
                                    end

                                    SetText(
                                        "Soul Guitar Chest | Collected: "
                                            .. tostring(c)
                                            .. "/"
                                            .. tostring(all)
                                            .. "/"
                                            .. tostring(
                                                ENV.Settings["Max Chests"]
                                            )
                                            .. "\nServer: "
                                            .. FormatServerUptime(
                                                GetRealServerUptime(false)
                                                    or uptime
                                            )
                                    )

                                    if Character
                                        and Character.Parent
                                        and Character:FindFirstChildOfClass(
                                            "Humanoid"
                                        )
                                        and Character.Humanoid.Health > 0
                                        and chest
                                        and chest.Parent then
                                        -- Logic chest cua Soul Guitar:
                                        -- dua nhan vat thang vao CFrame cua chest.
                                        local moved = pcall(function()
                                            Character:SetPrimaryPartCFrame(
                                                chest.CFrame
                                            )
                                        end)

                                        if not moved then
                                            pcall(function()
                                                Character:PivotTo(chest.CFrame)
                                            end)
                                        end

                                        -- Soul Guitar bo qua chest ghost sau delay.
                                        -- Chi schedule 1 lan/chest de tranh tao hang tram task.
                                        if not skipScheduled then
                                            skipScheduled = true

                                            task.spawn(function()
                                                task.wait(
                                                    tonumber(
                                                        ENV.Settings[
                                                            "Skip Chest Delay"
                                                        ]
                                                    ) or 2
                                                )
                                                if chest
                                                        and chest.Parent
                                                        and chest.CanTouch
                                                        and not CheckTool(
                                                            "Fist of Darkness"
                                                        ) then
                                                        chest.CanTouch = false
                                                    end
                                            end)
                                        end
                                    end

                                    pcall(function()
                                        local humanoid =
                                            Character
                                            and Character:FindFirstChildOfClass(
                                                "Humanoid"
                                            )

                                        if humanoid
                                            and (
                                                humanoid.FloorMaterial
                                                    ~= Enum.Material.Air
                                                or not table.find(
                                                    {
                                                        Enum.HumanoidStateType.Jumping,
                                                        Enum.HumanoidStateType.Dead,
                                                    },
                                                    humanoid:GetState()
                                                )
                                            ) then
                                            humanoid:ChangeState(
                                                Enum.HumanoidStateType.Jumping
                                            )
                                        end
                                    end)
                                until serverTimeExpired
                                    or not chest
                                    or not chest.Parent
                                    or not chest.CanTouch
                                    or CheckTool("Fist of Darkness")
                                    or IsDied(Character)

                                if serverTimeExpired then
                                    SetText(
                                        "Soul Guitar Chest | Server reached "
                                            .. FormatServerUptime(uptime)
                                            .. " - hopping"
                                    )
                                    break
                                end

                                if CheckTool("Fist of Darkness") then
                                    SetText(
                                        "Soul Guitar Chest | Found Fist of Darkness"
                                    )
                                    break
                                end

                                if not IsDied(Character) then
                                    c = c + 1
                                    all = all + 1
                                else
                                    break
                                end

                                if all
                                    >= ENV.Settings["Max Chests"] then
                                    SetText(
                                        "Soul Guitar Chest | Max chests reached"
                                    )
                                    break
                                end

                                if c
                                    >= ENV.Settings[
                                        "Reset After Collect Chests"
                                    ]
                                    and not CheckTool(
                                        "Fist of Darkness"
                                    ) then
                                    local humanoid =
                                        Character
                                        and Character:FindFirstChildOfClass(
                                            "Humanoid"
                                        )

                                    if humanoid then
                                        humanoid:ChangeState(
                                            Enum.HumanoidStateType.Dead
                                        )

                                        SetText(
                                            "Soul Guitar Chest | Reset after "
                                                .. tostring(c)
                                                .. " chests"
                                        )
                                    end

                                    c = 0
                                    task.wait(1)
                                end

                                if index % 250 == 0 then
                                    task.wait(0.01)
                                end
                                end -- valid chest
                            end
                        end

                        if not CheckTool("Fist of Darkness") then
                            local latestUptime =
                                GetRealServerUptime(false) or uptime

                            local hopReason = serverTimeExpired
                                and (
                                    "Server left current 1h chest window | Uptime "
                                    .. FormatServerUptime(latestUptime)
                                )
                                or (
                                    "Soul Guitar chest finished | Uptime "
                                    .. FormatServerUptime(latestUptime)
                                )

                            HopServer(
                                8,
                                nil,
                                hopReason
                            )
                        end
                    end
                else
                    SetText("Travel to sea 2")
                    task.wait(3)
                    COMMF_:InvokeServer("TravelDressrosa")
                end
            else
                if CheckSea(2) then
                    SafeFireClick(workspace.Map.CircleIsland.RaidSummon.Button.Main.ClickDetector)
                else SetText("Travel to sea 2") task.wait(3) COMMF_:InvokeServer("TravelDressrosa")
                end
            end
        end, function(err) warn(err)
            StarterGui:SetCore("SendNotification", {Title = "ERROR", Text = err})
        end)
    end
end)

task.spawn(function()
    while task.wait(4) do
        xpcall(function()
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

-- TeleportInitFailed da duoc xu ly trong Fast Server Hop o tren.
-- Khi Roblox hien loi disconnect, mo khoa hop de lan chay tiep theo co the retry.
GuiService.ErrorMessageChanged:Connect(function()
    local ok, errorType = pcall(function()
        return GuiService:GetErrorType()
    end)

    if ok and errorType == Enum.ConnectionError.DisconnectErrors then
        CyborgHopLock = false
        warn("[HopServer] Roblox disconnect error detected")
    end
end)

print("[Cyborg SoulGuitar Chest] Windows: 04-05, 08-09, 12-13, ...")
print("[Cyborg SoulGuitar Chest] Hop max pages:", ENV.Settings["Hop Max Pages"])
print(
    "[Cyborg SoulGuitar Chest] Time windows: every",
    (ENV.Settings["Chest Server Period Seconds"] or 14400) / 3600,
    "hours, grace",
    (ENV.Settings["Chest Server Grace Seconds"] or 3600) / 3600,
    "hour"
)

BootStage("script-loaded")
print("[Compatibility] Nil-call protection active")

print("[FULL FIX] ENV source:", type(ENV))
print("[FULL FIX] getgenv available:", type(getgenv) == "function")
print("[FULL FIX] fireclickdetector:", type(fireclickdetector))
print("[FULL FIX] firetouchinterest:", type(firetouchinterest))
print("[FULL FIX] firesignal:", type(firesignal))
