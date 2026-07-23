getgenv().Settings = {
    ["Max Chests"] = 30;
    ["Skip Chest Delay"] = 1;
    ["Reset After Collect Chests"] = 15;
    ["Katakuri Progress"] = 100;
    ["Fragments"] = 1000;
    ["Black Screen"] = false;
    ["Chest Tween Speed"] = 325;
    ["Chest Touch Radius"] = 8;

    -- Server hop scanner
    ["Hop Max Pages"] = 500;          -- Tổng số page tối đa được duyệt
    ["Hop Pages Per Batch"] = 150;     -- Số page quét trong mỗi lần hop
    ["Hop Max Players"] = 5;          -- Chỉ lấy server có player <= giá trị này
    ["Hop Forced Region"] = nil;      -- VD: "Singapore"; nil = mọi region

    -- Server uptime chest window: every 4 hours, active for 2 hours
    ["Chest Server Period"] = 4 * 60 * 60;
    ["Chest Server Grace"] = 2 * 60 * 60;
}

repeat task.wait(0.5) until game:IsLoaded() and game.Players.LocalPlayer and game.Players.LocalPlayer:FindFirstChildWhichIsA("PlayerGui")
if getgenv().WARCLOADER then
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Execution Blocked",
            Text = "The script is already running. Please wait 10 seconds",
            Duration = 5
        })
    end)
    return
end
getgenv().WARCLOADER = true
task.delay(10, function() getgenv().WARCLOADER = nil end)

local _cloneref = cloneref or clonereference or function(x) return x end
local _isnetworkowner = isnetworkowner or isNetworkOwner or function() return true end
cloneref = _cloneref
isnetworkowner = _isnetworkowner
getgenv().cloneref = _cloneref
getgenv().isnetworkowner = _isnetworkowner

workspace = _cloneref(workspace)
    or _cloneref(Workspace)
    or (getrenv and (getrenv().workspace or getrenv().Workspace))
    or _cloneref(game:GetService("Workspace"))
PlaceId, JobId = game.PlaceId, game.JobId
getfenv = getfenv or _G or _ENV or shared or function() return {} end
IsOnMobile = false
Services = setmetatable({}, {__index = function(self, name)
    local s, c = pcall(function() return cloneref(game:GetService(name)) end)
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

StarterGui:SetCore("SendNotification", {Title = "Executed", Text = "Loading… Please wait", Duration = 5})
if not game:IsLoaded() then
    repeat task.wait() until game:IsLoaded()
end
if not COMMF_ then repeat task.wait(1) until COMMF_ end

local gmod = require(ReplicatedStorage.GuideModule) and ReplicatedStorage:FindFirstChild("GuideModule") and gmod ~= (nil and {}) and gmod.Data ~= (nil and {}) and gmod.Data.NPCList ~= (nil and {})
task.spawn((function()
    xpcall(function()
        gethui().IgnoreGuiInset = true
    end, (function(err)
        xpcall((function()
            local g = COREGUI:FindFirstChild("ScreenGUI") or Instance.new("ScreenGui", COREGUI)
            g.Name = "ScreenGUI" g.IgnoreGuiInset = true
            hookfunction(gethui, function() return g end)
            task.delay(5, (function()StarterGui:SetCore("SendNotification", {Title = "Incompatible Executor", Text = "This executor may cause errors while running the script\n[ERROR CODE: UIGE]", Duration = 20})end))
        end), (function() warn("???") end))
    end))
end))

task.spawn(function()
    xpcall(function()
        if not LocalPlayer.Team then
            if LocalPlayer.PlayerGui:FindFirstChild("LoadingScreen") then
                repeat task.wait(1) until not LocalPlayer.PlayerGui:FindFirstChild("LoadingScreen")
            end
            xpcall(function() COMMF_:InvokeServer("SetTeam", "Pirates")
            end, function() firesignal(LocalPlayer.PlayerGui["Main (minimal)"].ChooseTeam.Container.Pirates) end)
            task.wait(2)
        end
    end, function(err) warn("????", err) end)
end)
repeat task.wait(2) until Character and Character:FindFirstChild("HumanoidRootPart") and Character:FindFirstChildWhichIsA("Humanoid") and Character:IsDescendantOf(workspace.Characters)

pcall(function()
    local oldBlank = LocalPlayer.PlayerGui:FindFirstChild("Blank")
    if oldBlank then oldBlank:Destroy() end
end)

local BlankScreen = Instance.new("ScreenGui")
BlankScreen.Name = "Blank"
BlankScreen.ResetOnSpawn = false
BlankScreen.DisplayOrder = -100
BlankScreen.IgnoreGuiInset = true
BlankScreen.Parent = LocalPlayer.PlayerGui

local Black = Instance.new("Frame")
Black.Name = "Black Screen"
Black.Size = UDim2.new(1, 0, 1, 0)
Black.BackgroundColor3 = Color3.new(0, 0, 0)
Black.BorderSizePixel = 0
Black.ZIndex = 1
Black.Visible = getgenv().Settings["Black Screen"] or false
Black.Parent = BlankScreen

RunService:Set3dRenderingEnabled(not Black.Visible)

-- Status text cũ vẫn giữ để không làm gãy logic SetText hiện tại.
local label = Instance.new("TextLabel")
label.Name = "CenteredLabel"
label.AnchorPoint = Vector2.new(0.5, 0.5)
label.Position = UDim2.new(0.5, 0, 0.56, 0)
label.Size = UDim2.new(0.70, 0, 0.17, 0)
label.Text = "Loading..."
label.TextScaled = true
label.TextWrapped = true
label.TextXAlignment = Enum.TextXAlignment.Center
label.TextYAlignment = Enum.TextYAlignment.Center
label.BackgroundTransparency = 1
label.Font = Enum.Font.GothamSemibold
label.TextColor3 = Color3.fromRGB(255, 255, 255)
label.TextStrokeTransparency = 0.25
label.ZIndex = 2
label.Parent = BlankScreen

-- ============================================================
-- DETAILED UI: Server Time + Cyborg status + hop scanner
-- ============================================================
local DashboardState = {
    Status = "Loading...",
    Hop = {
        Status = "Idle",
        CurrentPage = 0,
        StartPage = 0,
        EndPage = 0,
        ScannedPages = 0,
        Candidates = 0,
        SelectedJobId = nil,
        SelectedPlayers = nil,
        SelectedRegion = nil,
        NextPage = 1,
    }
}

local oldDashboard
pcall(function()
    if type(gethui) == "function" then
        oldDashboard = gethui():FindFirstChild("CyborgDetailedStatusUI")
    end
end)
if not oldDashboard then
    oldDashboard = COREGUI:FindFirstChild("CyborgDetailedStatusUI")
end
if not oldDashboard and LocalPlayer.PlayerGui then
    oldDashboard = LocalPlayer.PlayerGui:FindFirstChild("CyborgDetailedStatusUI")
end
if oldDashboard then
    oldDashboard:Destroy()
end

local DashboardGui = Instance.new("ScreenGui")
DashboardGui.Name = "CyborgDetailedStatusUI"
DashboardGui.ResetOnSpawn = false
DashboardGui.IgnoreGuiInset = false
DashboardGui.DisplayOrder = 999999
DashboardGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local dashboardParented = false
pcall(function()
    if type(gethui) == "function" then
        DashboardGui.Parent = gethui()
        dashboardParented = true
    end
end)
if not dashboardParented then
    local ok = pcall(function()
        DashboardGui.Parent = COREGUI
    end)
    if not ok then
        DashboardGui.Parent = LocalPlayer.PlayerGui
    end
end

local Panel = Instance.new("Frame")
Panel.Name = "Panel"
Panel.AnchorPoint = Vector2.new(0.5, 0)
Panel.Position = UDim2.new(0.5, 0, 0, 42)
Panel.Size = UDim2.fromOffset(610, 285)
Panel.BackgroundColor3 = Color3.fromRGB(13, 18, 25)
Panel.BackgroundTransparency = 0.08
Panel.BorderSizePixel = 0
Panel.ZIndex = 20
Panel.Parent = DashboardGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 10)
panelCorner.Parent = Panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(87, 107, 130)
panelStroke.Thickness = 1.2
panelStroke.Transparency = 0.1
panelStroke.Parent = Panel

local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 34)
Header.BackgroundColor3 = Color3.fromRGB(25, 34, 45)
Header.BorderSizePixel = 0
Header.ZIndex = 21
Header.Parent = Panel

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 10)
headerCorner.Parent = Header

local headerFix = Instance.new("Frame")
headerFix.Size = UDim2.new(1, 0, 0, 10)
headerFix.Position = UDim2.new(0, 0, 1, -10)
headerFix.BackgroundColor3 = Header.BackgroundColor3
headerFix.BorderSizePixel = 0
headerFix.ZIndex = 21
headerFix.Parent = Header

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -24, 1, 0)
TitleLabel.Position = UDim2.fromOffset(12, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.Text = "CYBORG AUTOMATION — DETAILED STATUS"
TitleLabel.TextColor3 = Color3.fromRGB(116, 227, 169)
TitleLabel.TextSize = 15
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.ZIndex = 22
TitleLabel.Parent = Header

local function makeDashboardLabel(name, y, height, text, size, color, bold)
    local item = Instance.new("TextLabel")
    item.Name = name
    item.Position = UDim2.fromOffset(14, y)
    item.Size = UDim2.new(1, -28, 0, height)
    item.BackgroundTransparency = 1
    item.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
    item.Text = text
    item.TextColor3 = color
    item.TextSize = size
    item.TextWrapped = true
    item.TextXAlignment = Enum.TextXAlignment.Left
    item.TextYAlignment = Enum.TextYAlignment.Top
    item.TextStrokeTransparency = 0.6
    item.ZIndex = 22
    item.Parent = Panel
    return item
end

local ServerTimeLabel = makeDashboardLabel(
    "ServerTime",
    44, 28,
    "Server Time (TimeIn): waiting...",
    21,
    Color3.fromRGB(255, 232, 133),
    true
)

local WindowLabel = makeDashboardLabel(
    "Window",
    73, 24,
    "Cyborg 4h + 2h Window: waiting...",
    14,
    Color3.fromRGB(183, 207, 232),
    true
)

local SourceLabel = makeDashboardLabel(
    "TimeInSource",
    98, 32,
    "TimeIn source: Workspace._WorldOrigin.Locations.<Location>.@TimeIn",
    11,
    Color3.fromRGB(142, 164, 187),
    false
)

local RaceLabel = makeDashboardLabel(
    "RaceAndSea",
    131, 24,
    "Sea: waiting | Race: waiting | Fragments: waiting",
    13,
    Color3.fromRGB(229, 233, 240),
    true
)

local ItemLabel = makeDashboardLabel(
    "CyborgItems",
    156, 40,
    "State: waiting | Fist: no | Microchip: no | Core Brain: no | Order: no",
    12,
    Color3.fromRGB(205, 216, 228),
    false
)

local StatusLabel = makeDashboardLabel(
    "CurrentStatus",
    197, 42,
    "Status: Loading...",
    13,
    Color3.fromRGB(255, 255, 255),
    true
)

local HopLabel = makeDashboardLabel(
    "HopStatus",
    240, 34,
    "Hop: idle",
    11,
    Color3.fromRGB(145, 205, 255),
    false
)

-- Cho phép kéo panel bằng header.
do
    local dragging = false
    local dragStart
    local startPosition

    Header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPosition = Panel.Position
        end
    end)

    Header.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        local delta = input.Position - dragStart
        Panel.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.F4 then
        Black.Visible = not Black.Visible
        RunService:Set3dRenderingEnabled(not Black.Visible)
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = "Black Screen",
                Text = Black.Visible
                    and "Đã BẬT màn hình đen (Tắt Render 3D)"
                    or "Đã TẮT màn hình đen (Bật Render 3D)",
                Duration = 2
            })
        end)
    end
end)

local function joinText(...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[#parts + 1] = tostring(select(i, ...))
    end
    return table.concat(parts, " ")
end

local function SetText(...)
    local newText = joinText(...)
    label.Text = newText
    DashboardState.Status = newText
    if StatusLabel and StatusLabel.Parent then
        StatusLabel.Text = "Status: " .. newText
    end
end

local mainfile = LocalPlayer.Name .. ".txt"
if type(isfile) == "function" and type(writefile) == "function" then
    if not isfile(mainfile) then
        writefile(mainfile, "NaN")
    end
end

local function readMainState()
    if type(readfile) ~= "function" then
        return tostring(CyborgBlockPartUnlocked or "NaN")
    end

    local ok, result = pcall(function()
        return readfile(mainfile)
    end)

    if ok and result then
        return tostring(result)
    end

    return tostring(CyborgBlockPartUnlocked or "NaN")
end

local function hasToolForUI(toolName)
    for _, container in ipairs({LocalPlayer.Backpack, Character}) do
        if container then
            for _, item in ipairs(container:GetChildren()) do
                if item:IsA("Tool")
                    and (item.Name == toolName or item.Name:find(toolName, 1, true)) then
                    return true
                end
            end
        end
    end
    return false
end

local function getSeaText()
    if game.PlaceId == 2753915549 then return "Sea 1" end
    if game.PlaceId == 4442272183 then return "Sea 2" end
    if game.PlaceId == 7449423635 then return "Sea 3" end

    local mapValue = workspace:GetAttribute("MAP")
    local number = mapValue and tostring(mapValue):match("%d+")
    return number and ("Sea " .. number) or "Unknown Sea"
end

-- ============================================================
-- REAL SERVER UPTIME + 4H PERIOD / 2H ACTIVE WINDOW
-- Uses:
-- workspace:GetServerTimeNow() - Workspace._WorldOrigin.Locations.<Location>:GetAttribute("TimeIn")
-- ============================================================
local ServerTimeRuntime = {
    StartTime = nil,
    SourcePath = nil,
    MatchedLocations = 0,
    LastError = nil,
}

local function DetectServerStartTimeFromTimeIn()
    local worldOrigin = workspace:FindFirstChild("_WorldOrigin")
    local locations = worldOrigin and worldOrigin:FindFirstChild("Locations")
    if not locations then
        return nil, nil, "Workspace._WorldOrigin.Locations not found"
    end

    local groups = {}

    for _, location in ipairs(locations:GetChildren()) do
        local value = location:GetAttribute("TimeIn")

        -- TimeIn phải là Unix timestamp hợp lệ.
        if type(value) == "number" and value > 1000000000 then
            local rounded = math.floor(value + 0.5)
            groups[rounded] = groups[rounded] or {
                Count = 0,
                Total = 0,
                Names = {},
            }

            local group = groups[rounded]
            group.Count = group.Count + 1
            group.Total = group.Total + value
            group.Names[#group.Names + 1] = location.Name
        end
    end

    local bestRounded
    local bestGroup

    for rounded, group in pairs(groups) do
        if not bestGroup
            or group.Count > bestGroup.Count
            or (group.Count == bestGroup.Count and rounded < bestRounded) then
            bestRounded = rounded
            bestGroup = group
        end
    end

    if not bestGroup then
        return nil, nil, "No valid TimeIn attribute found"
    end

    local averageTimeIn = bestGroup.Total / bestGroup.Count
    local exampleName = bestGroup.Names[1] or "Unknown"

    return averageTimeIn, {
        Count = bestGroup.Count,
        Path = "Workspace._WorldOrigin.Locations."
            .. exampleName
            .. ".@TimeIn",
    }
end

local function GetRealServerUptime()
    if not ServerTimeRuntime.StartTime then
        local detected, info, err = DetectServerStartTimeFromTimeIn()

        if not detected then
            ServerTimeRuntime.LastError = err
            return nil, err
        end

        ServerTimeRuntime.StartTime = detected
        ServerTimeRuntime.SourcePath = info.Path
        ServerTimeRuntime.MatchedLocations = info.Count
        ServerTimeRuntime.LastError = nil
    end

    local ok, serverNow = pcall(function()
        return workspace:GetServerTimeNow()
    end)

    if not ok or type(serverNow) ~= "number" then
        ServerTimeRuntime.LastError = "Workspace:GetServerTimeNow() failed"
        return nil, ServerTimeRuntime.LastError
    end

    local uptime = serverNow - ServerTimeRuntime.StartTime

    if uptime < 0 or uptime >= 31536000 then
        ServerTimeRuntime.LastError = "TimeIn is invalid"
        return nil, ServerTimeRuntime.LastError
    end

    local source = string.format(
        "%s | matched %d Locations",
        tostring(ServerTimeRuntime.SourcePath),
        tonumber(ServerTimeRuntime.MatchedLocations) or 0
    )

    return uptime, source
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


task.spawn(function()
    while DashboardGui and DashboardGui.Parent do
        local uptime, source = GetRealServerUptime()

        if uptime then
            ServerTimeLabel.Text = "Server Time (TimeIn): " .. FormatUptime(uptime)
            SourceLabel.Text = "TimeIn source: " .. tostring(source)

            local inWindow, _, _, timeInfo = CheckChestTimeWindow()
            if timeInfo then
                local nextBoundary = FormatUptime(timeInfo.NextBoundary)
                local offsetText = FormatUptime(timeInfo.Offset)

                if inWindow then
                    WindowLabel.Text =
                        "Cyborg 4h + 2h Window: ACTIVE"
                        .. " | cycle offset "
                        .. offsetText
                        .. " | end "
                        .. nextBoundary
                    WindowLabel.TextColor3 = Color3.fromRGB(109, 222, 161)
                else
                    WindowLabel.Text =
                        "Cyborg 4h + 2h Window: WAIT"
                        .. " | cycle offset "
                        .. offsetText
                        .. " | next "
                        .. nextBoundary
                    WindowLabel.TextColor3 = Color3.fromRGB(246, 197, 88)
                end
            end
        else
            ServerTimeLabel.Text = "Server Time (TimeIn): waiting..."
            SourceLabel.Text =
                "TimeIn source error: "
                .. tostring(source or ServerTimeRuntime.LastError or "unknown")
            WindowLabel.Text = "Cyborg 4h + 2h Window: cannot evaluate"
            WindowLabel.TextColor3 = Color3.fromRGB(239, 104, 104)
        end

        local data = LocalPlayer:FindFirstChild("Data")
        local race = data and data:FindFirstChild("Race")
        local fragments = data and data:FindFirstChild("Fragments")

        RaceLabel.Text = string.format(
            "Sea: %s | Race: %s | Fragments: %s",
            getSeaText(),
            race and tostring(race.Value) or "waiting",
            fragments and tostring(fragments.Value) or "waiting"
        )

        local orderExists =
            (workspace:FindFirstChild("Enemies")
                and workspace.Enemies:FindFirstChild("Order"))
            or ReplicatedStorage:FindFirstChild("Order")

        ItemLabel.Text = string.format(
            "State: %s | Fist: %s | Microchip: %s | Core Brain: %s | Order: %s",
            tostring(CyborgBlockPartUnlocked or readMainState()),
            hasToolForUI("Fist of Darkness") and "yes" or "no",
            hasToolForUI("Microchip") and "yes" or "no",
            hasToolForUI("Core Brain") and "yes" or "no",
            orderExists and "yes" or "no"
        )

        StatusLabel.Text = "Status: " .. tostring(DashboardState.Status)

        local hop = DashboardState.Hop
        local selected = hop.SelectedJobId
            and string.format(
                "%s | %s players | %s",
                tostring(hop.SelectedJobId),
                tostring(hop.SelectedPlayers or "?"),
                tostring(hop.SelectedRegion or "?")
            )
            or "none"

        HopLabel.Text = string.format(
            "Hop: %s | pages %s-%s (%s scanned) | candidates %s | selected %s\nConfig: maxPages=%s, pagesPerBatch=%s, maxPlayers=%s, region=%s",
            tostring(hop.Status or "Idle"),
            tostring(hop.StartPage or 0),
            tostring(hop.EndPage or 0),
            tostring(hop.ScannedPages or 0),
            tostring(hop.Candidates or 0),
            selected,
            tostring(getgenv().Settings["Hop Max Pages"]),
            tostring(getgenv().Settings["Hop Pages Per Batch"]),
            tostring(getgenv().Settings["Hop Max Players"]),
            tostring(getgenv().Settings["Hop Forced Region"] or "any")
        )

        task.wait(1)
    end
end)

local completedCyborgWritten = false
local function WriteCompletedCyborg()
    if completedCyborgWritten then
        return
    end

    local race =
        LocalPlayer
        and LocalPlayer:FindFirstChild("Data")
        and LocalPlayer.Data:FindFirstChild("Race")

    if race and tostring(race.Value):lower() == "cyborg" then
        pcall(function()
            writefile(mainfile, "Completed-cyborg")
        end)
        completedCyborgWritten = true
    end
end

function CheckSea(v: number) return v == tonumber(workspace:GetAttribute("MAP"):match("%d+")) end

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
    cloneref(remoteAttack):FireServer(string.gsub("RE/RegisterHit", ".",function(c)
        return string.char(bit32.bxor(string.byte(c), math.floor(workspace:GetServerTimeNow()/10%10)+1))
    end), bit32.bxor(idremote+909090, seed*2), unpack(h))
    lastCallFA = tick()
end)

local lastHop, inHopPP = tick(), false

function IfTableHaveIndex(j)
    if type(j) ~= "table" then
        return false
    end

    for _ in pairs(j) do
        return true
    end

    return false
end

local function getHopConfig(maxPlayersArg, forcedRegionArg)
    local settings = getgenv().Settings or {}

    local maxPages = math.max(
        1,
        math.floor(tonumber(settings["Hop Max Pages"]) or 100)
    )

    local pagesPerBatch = math.max(
        1,
        math.floor(tonumber(settings["Hop Pages Per Batch"]) or 20)
    )
    pagesPerBatch = math.min(pagesPerBatch, maxPages)

    -- Config được ưu tiên để mọi call HopServer(8/10) đều dùng cùng một giá trị.
    local maxPlayers =
        tonumber(settings["Hop Max Players"])
        or tonumber(maxPlayersArg)
        or 8

    local forcedRegion = settings["Hop Forced Region"]
    if forcedRegion == nil or tostring(forcedRegion) == "" then
        forcedRegion = forcedRegionArg
    end
    if forcedRegion ~= nil and tostring(forcedRegion) == "" then
        forcedRegion = nil
    end

    return {
        MaxPages = maxPages,
        PagesPerBatch = pagesPerBatch,
        MaxPlayers = maxPlayers,
        ForcedRegion = forcedRegion,
    }
end

local function normalizeRegion(value)
    if value == nil then return "" end
    return tostring(value):lower()
end

function GetServers(MaxPlayers, ForcedRegion)
    local config = getHopConfig(MaxPlayers, ForcedRegion)
    local serverBrowser = ReplicatedStorage:WaitForChild("__ServerBrowser")

    local startPage = tonumber(DashboardState.Hop.NextPage) or 1
    if startPage < 1 or startPage > config.MaxPages then
        startPage = 1
    end

    local candidates = {}
    local seenJobs = {}
    local lastPage = startPage
    local scanned = 0

    DashboardState.Hop.Status = "Scanning"
    DashboardState.Hop.StartPage = startPage
    DashboardState.Hop.EndPage = startPage
    DashboardState.Hop.ScannedPages = 0
    DashboardState.Hop.Candidates = 0
    DashboardState.Hop.SelectedJobId = nil
    DashboardState.Hop.SelectedPlayers = nil
    DashboardState.Hop.SelectedRegion = nil

    for offset = 0, config.PagesPerBatch - 1 do
        local page = ((startPage - 1 + offset) % config.MaxPages) + 1
        lastPage = page
        scanned = scanned + 1

        DashboardState.Hop.CurrentPage = page
        DashboardState.Hop.EndPage = page
        DashboardState.Hop.ScannedPages = scanned
        DashboardState.Hop.Status =
            "Scanning page "
            .. tostring(page)
            .. "/"
            .. tostring(config.MaxPages)

        local ok, pageData = pcall(function()
            return serverBrowser:InvokeServer(page)
        end)

        if ok and type(pageData) == "table" then
            for jobId, info in pairs(pageData) do
                if type(info) == "table"
                    and tostring(jobId) ~= tostring(game.JobId)
                    and not seenJobs[jobId] then
                    local players = tonumber(info.Count)
                    local region = info.Region or info.Regoin

                    local regionOk =
                        not config.ForcedRegion
                        or normalizeRegion(region)
                            == normalizeRegion(config.ForcedRegion)

                    if players
                        and players <= config.MaxPlayers
                        and regionOk then
                        seenJobs[jobId] = true
                        candidates[#candidates + 1] = {
                            JobId = jobId,
                            Players = players,
                            LastUpdate = tonumber(info.__LastUpdate) or 0,
                            Region = region or "Unknown",
                        }
                    end
                end
            end
        end

        DashboardState.Hop.Candidates = #candidates
        task.wait()
    end

    DashboardState.Hop.NextPage =
        ((lastPage - 1 + 1) % config.MaxPages) + 1

    -- "Best server": ít player nhất; nếu bằng nhau thì ưu tiên data mới hơn.
    table.sort(candidates, function(a, b)
        if a.Players ~= b.Players then
            return a.Players < b.Players
        end

        if a.LastUpdate ~= b.LastUpdate then
            return a.LastUpdate > b.LastUpdate
        end

        return tostring(a.JobId) < tostring(b.JobId)
    end)

    DashboardState.Hop.Status = "Scan complete"
    DashboardState.Hop.Candidates = #candidates

    return candidates, config
end

HopServer = function(MaxPlayers, ForcedRegion)
    if inHopPP then
        DashboardState.Hop.Status = "Teleport already in progress"
        return false
    end

    local candidates, config = GetServers(MaxPlayers, ForcedRegion)

    if not candidates or #candidates == 0 then
        DashboardState.Hop.Status = "No eligible server in this batch"
        SetText(
            "Hop | no eligible server"
            .. " | pages "
            .. tostring(DashboardState.Hop.StartPage)
            .. "-"
            .. tostring(DashboardState.Hop.EndPage)
            .. " | maxPlayers "
            .. tostring(config.MaxPlayers)
        )
        return false
    end

    local best = candidates[1]

    DashboardState.Hop.SelectedJobId = best.JobId
    DashboardState.Hop.SelectedPlayers = best.Players
    DashboardState.Hop.SelectedRegion = best.Region
    DashboardState.Hop.Status = "Teleporting to best server"

    SetText(
        "Hop | Best server"
        .. " | Players: "
        .. tostring(best.Players)
        .. " | Region: "
        .. tostring(best.Region)
        .. " | JobId: "
        .. tostring(best.JobId)
    )

    inHopPP = true
    lastHop = tick()

    local ok = pcall(function()
        ReplicatedStorage
            :WaitForChild("__ServerBrowser")
            :InvokeServer("teleport", best.JobId)
    end)

    if not ok then
        inHopPP = false
        DashboardState.Hop.Status = "Teleport call failed"
        return false
    end

    -- Nếu teleport không chạy do lỗi im lặng, cho phép thử lại sau.
    task.delay(12, function()
        inHopPP = false
    end)

    return true
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
-- (port tu V3.txt). Thay cho SetPrimaryPartCFrame + PressKeyEvent("Space") vua khong an
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
                firetouchinterest(root, part, 0)
                task.wait(0.08)
                firetouchinterest(root, part, 1)
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

local hookedNotification;
hookedNotification = hookfunction(require(ReplicatedStorage.Notification).new, newcclosure(function(...)
    local args = ({...})[1]
    if CheckSea(2) then
        if args:lower():find("supply a <core brain>") or args:find("<Fist of Darkness> has been") then
            CyborgBlockPartUnlocked = "unlock"
            writefile(mainfile, "unlock")
        elseif args:find("Microchip not found") then
            CyborgBlockPartUnlocked = "chest"
            writefile(mainfile, "chest")
        end
    end
    return hookedNotification(...)
end))

local all = 0
local fragok = false;
task.spawn(function()
    while task.wait(0.5) do
        xpcall(function()
            WriteCompletedCyborg()
            if LocalPlayer.Data.Race.Value ~= "Cyborg" and LocalPlayer.Data.Fragments.Value >= 2500 then COMMF_:InvokeServer("CyborgTrainer", "Buy") end
            CyborgBlockPartUnlocked = readfile(mainfile) or "NaN"
            pcall(function() fireclickdetector(workspace.Map.CircleIsland.RaidSummon.Button.Main.ClickDetector) end)
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
                        writefile(mainfile, "Completed-cyborg")
                        SetText("DONE V3")
                    else SetText("Teleport to Sea 3") task.wait(3) COMMF_:InvokeServer("TravelZou") task.wait(10)
                    end
                end
            elseif CyborgBlockPartUnlocked == "unlock" or game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("CyborgTrainer", "Check") == true then
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
                            fireclickdetector(workspace.Map.CircleIsland.RaidSummon.Button.Main.ClickDetector)
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
                                        if v.Name ~= "rip_indra" then if not CheckLocation("Dimensional Shift") then firetouchinterest(LocalPlayer.Character.HumanoidRootPart, workspace.Map.CakeLoaf.BigMirror.Main, 0) task.wait(3) end end
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
                        fireclickdetector(workspace.Map.CircleIsland.RaidSummon.Button.Main.ClickDetector)
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
                    fireclickdetector(workspace.Map.CircleIsland.RaidSummon.Button.Main.ClickDetector)
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

TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, message)
    if teleportResult == Enum.TeleportResult.GameFull then inHopPP = false
    elseif teleportResult == Enum.TeleportResult.IsTeleporting and (message:find("previous teleport")) then
        StarterGui:SetCore("SendNotification", {Title = "Death Hop Found", Text = message, Duration = 8})
        task.delay(10, function() game:Shutdown() end)
    end
end)

GuiService.ErrorMessageChanged:Connect(newcclosure(function()
    if GuiService:GetErrorType() == Enum.ConnectionError.DisconnectErrors then
        while true do ReplicatedStorage:WaitForChild("__ServerBrowser"):InvokeServer('teleport', JobId) task.wait(5) end
    end
end))
