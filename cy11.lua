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
    ["Hop Max Pages"] = 500;          -- Tá»•ng sá»‘ page tá»‘i Ä‘a Ä‘Æ°á»£c duyá»‡t
    ["Hop Pages Per Batch"] = 150;    -- Sá»‘ page yÃªu cáº§u trong má»—i láº§n hop
    ["Hop Max Players"] = 8;          -- Chá»‰ láº¥y server cÃ³ player <= giÃ¡ trá»‹ nÃ y
    ["Hop Forced Region"] = nil;      -- VD: "Singapore"; nil = má»i region
    ["Hop Scan Concurrency"] = 70;  -- Sá»‘ page gá»i song song (khÃ´ng pháº£i tá»•ng page)
    ["Hop Batch Timeout"] = 18;     -- Giá»›i háº¡n thá»i gian chá» má»™t batch

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

StarterGui:SetCore("SendNotification", {Title = "Executed", Text = "Loadingâ€¦ Please wait", Duration = 5})
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

-- Status text cÅ© váº«n giá»¯ Ä‘á»ƒ khÃ´ng lÃ m gÃ£y logic SetText hiá»‡n táº¡i.
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
        RequestedPages = 0,
        CompletedPages = 0,
        FailedPages = 0,
        TimedOut = false,
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
Panel.Size = UDim2.fromOffset(660, 330)
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
TitleLabel.Text = "CYBORG AUTOMATION â€” TIME WINDOW FIX v2"
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
    131, 38,
    "Sea: waiting | Race: waiting | Fragments: waiting",
    13,
    Color3.fromRGB(229, 233, 240),
    true
)

local ItemLabel = makeDashboardLabel(
    "CyborgItems",
    170, 54,
    "State: waiting | Fist: no | Microchip: no | Core Brain: no | Order: no",
    12,
    Color3.fromRGB(205, 216, 228),
    false
)

local StatusLabel = makeDashboardLabel(
    "CurrentStatus",
    225, 46,
    "Status: Loading...",
    13,
    Color3.fromRGB(255, 255, 255),
    true
)

local HopLabel = makeDashboardLabel(
    "HopStatus",
    272, 48,
    "Hop: idle",
    11,
    Color3.fromRGB(145, 205, 255),
    false
)

-- Cho phÃ©p kÃ©o panel báº±ng header.
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
                    and "ÄÃ£ Báº¬T mÃ n hÃ¬nh Ä‘en (Táº¯t Render 3D)"
                    or "ÄÃ£ Táº®T mÃ n hÃ¬nh Ä‘en (Báº­t Render 3D)",
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
local progressfile = LocalPlayer.Name .. "_cyborg_progress.txt"
local ownershipfile = LocalPlayer.Name .. "_cyborg_owned.txt"

local function safeReadFile(path)
    if type(isfile) ~= "function" or type(readfile) ~= "function" then
        return nil
    end

    local okExists, exists = pcall(isfile, path)
    if not okExists or not exists then
        return nil
    end

    local ok, result = pcall(readfile, path)
    if ok and result ~= nil then
        return tostring(result)
    end

    return nil
end

local function safeWriteFile(path, content)
    if type(writefile) ~= "function" then
        return false
    end

    return pcall(writefile, path, tostring(content))
end

-- TÃ¡ch file tiáº¿n trÃ¬nh Get Cyborg khá»i file káº¿t quáº£ cuá»‘i.
-- PlayerName.txt chá»‰ Ä‘Æ°á»£c ghi Completed-done khi Ä‘Ã£ xÃ¡c nháº­n cáº£ Cyborg V1 vÃ  Ghoul V1.
do
    local legacy = safeReadFile(mainfile)

    if legacy == "unlock" or legacy == "chest" or legacy == "NaN" then
        safeWriteFile(progressfile, legacy)
        safeWriteFile(mainfile, "Pending")
    elseif legacy == "Completed-cyborg" then
        safeWriteFile(ownershipfile, "cyborg-owned")
        safeWriteFile(mainfile, "Pending")
    end

    if not safeReadFile(progressfile) then
        safeWriteFile(progressfile, "NaN")
    end
end

local function readMainState()
    return safeReadFile(progressfile)
        or tostring(CyborgBlockPartUnlocked or "NaN")
end

local RaceFlow = {
    CyborgOwnedRuntime = false,
    GhoulStarted = false,     -- da khoi dong module Ghoul chua (chay 1 lan)
    GhoulRunning = false,     -- module Ghoul dang chay
    GhoulStatus = "idle",     -- trang thai hien tai cua module Ghoul (hien UI)
    Completed = safeReadFile(mainfile) == "Completed-done",
}

local function getCurrentRaceName()
    local data = LocalPlayer and LocalPlayer:FindFirstChild("Data")
    local race = data and data:FindFirstChild("Race")
    return race and tostring(race.Value) or ""
end

-- Ghi proof Cyborg 1 LAN (truoc day ghi moi 0.5s -> I/O lien tuc).
-- Chi ghi file khi runtime chua danh dau + noi dung file chua dung.
local function markCyborgOwned()
    if RaceFlow.CyborgOwnedRuntime then return end
    RaceFlow.CyborgOwnedRuntime = true
    if safeReadFile(ownershipfile) ~= "cyborg-owned" then
        safeWriteFile(ownershipfile, "cyborg-owned")
    end
end

local function hasCyborgV1()
    if RaceFlow.CyborgOwnedRuntime then
        return true
    end

    if getCurrentRaceName():lower() == "cyborg" then
        markCyborgOwned()
        return true
    end

    if safeReadFile(ownershipfile) == "cyborg-owned" then
        RaceFlow.CyborgOwnedRuntime = true
        return true
    end

    return false
end

-- Ghoul hoan tat khi race hien tai == "Ghoul".
local function hasGhoulV1()
    return getCurrentRaceName():lower() == "ghoul"
end

local function writeCompletedDone()
    if RaceFlow.Completed then
        return true
    end

    if hasCyborgV1() and hasGhoulV1() then
        safeWriteFile(mainfile, "Completed-done")
        RaceFlow.Completed = true
        return true
    end

    return false
end

-- Module Ghoul (build ben duoi - dinh nghia sau vi can dung FastAttack/BringMonster/Tween...).
-- Forward-declare: GhoulModuleRun se duoc gan o phan MODULE GHOUL phia duoi.
GhoulModuleRun = GhoulModuleRun or nil

-- Khoi dong module Ghoul tu-build (thay cho BananaHub):
--   farm Ectoplasm -> farm boss Cursed Captain (hop API) -> mua qua NPC Experimic.
-- Chi chay khi da co Cyborg V1, chua thanh Ghoul, va chay 1 lan duy nhat.
local function startGhoulModule()
    if RaceFlow.Completed or hasGhoulV1() then
        return false
    end

    -- Chi doi sang Ghoul khi dang la Cyborg (dung y: Cyborg xong -> doi luon Ghoul).
    if getCurrentRaceName():lower() ~= "cyborg" then
        return false
    end

    if RaceFlow.GhoulRunning or RaceFlow.GhoulStarted then
        return true
    end

    if type(GhoulModuleRun) ~= "function" then
        RaceFlow.GhoulStatus = "module chua san sang"
        return false
    end

    RaceFlow.GhoulStarted = true
    RaceFlow.GhoulRunning = true
    RaceFlow.GhoulStatus = "starting"

    task.spawn(function()
        local ok, err = xpcall(GhoulModuleRun, function(m) return tostring(m) end)
        RaceFlow.GhoulRunning = false
        if not ok then
            RaceFlow.GhoulStarted = false   -- cho phep thu lai
            RaceFlow.GhoulStatus = "error: " .. tostring(err)
            warn("[Ghoul Module] " .. tostring(err))
        end
    end)

    return true
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

        -- TimeIn pháº£i lÃ  Unix timestamp há»£p lá»‡.
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

    -- Quy táº¯c chÃ­nh xÃ¡c:
    --   dÆ°á»›i 4h       -> HOP
    --   4h00-6h00     -> GIá»®
    --   trÃªn 6h-8h    -> HOP
    --   8h00-10h00    -> GIá»®
    --   trÃªn 10h-12h  -> HOP ...
    -- NghÄ©a lÃ  cá»­a sá»• Ä‘áº§u tiÃªn báº¯t Ä‘áº§u táº¡i 4h, sau Ä‘Ã³ láº·p láº¡i má»—i 4h,
    -- má»—i cá»­a sá»• chá»‰ kÃ©o dÃ i thÃªm 2h.
    local period = math.max(
        1,
        tonumber(getgenv().Settings["Chest Server Period"])
            or (4 * 60 * 60)
    )
    local grace = math.max(
        0,
        tonumber(getgenv().Settings["Chest Server Grace"])
            or (2 * 60 * 60)
    )

    local firstWindowStart = period

    if uptime < firstWindowStart then
        return false, uptime, source, {
            Phase = "BEFORE_FIRST_WINDOW",
            Offset = uptime,
            CycleStart = firstWindowStart,
            CycleEnd = firstWindowStart + grace,
            NextBoundary = firstWindowStart,
            Remaining = firstWindowStart - uptime,
        }
    end

    local windowIndex = math.floor((uptime - firstWindowStart) / period)
    local cycleStart = firstWindowStart + (windowIndex * period)
    local cycleEnd = cycleStart + grace
    local offset = uptime - cycleStart

    -- ÄÃºng vÃ­ dá»¥: 6h00 vÃ  10h00 váº«n giá»¯; chá»‰ sau má»‘c Ä‘Ã³ má»›i hop.
    local inWindow = uptime <= cycleEnd
    local nextBoundary = inWindow and cycleEnd or (cycleStart + period)

    return inWindow, uptime, source, {
        Phase = inWindow and "ACTIVE" or "OUTSIDE",
        Offset = offset,
        CycleStart = cycleStart,
        CycleEnd = cycleEnd,
        NextBoundary = nextBoundary,
        Remaining = math.max(0, nextBoundary - uptime),
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
                local startText = FormatUptime(timeInfo.CycleStart)
                local endText = FormatUptime(timeInfo.CycleEnd)
                local nextText = FormatUptime(timeInfo.NextBoundary)
                local remainingText = FormatUptime(timeInfo.Remaining)

                if inWindow then
                    WindowLabel.Text =
                        "Cyborg 4h + 2h Window: ACTIVE"
                        .. " | keep "
                        .. startText
                        .. " -> "
                        .. endText
                        .. " | closes "
                        .. nextText
                    WindowLabel.TextColor3 = Color3.fromRGB(109, 222, 161)
                else
                    WindowLabel.Text =
                        "Cyborg 4h + 2h Window: HOP"
                        .. " | next valid "
                        .. nextText
                        .. " | remaining "
                        .. remainingText
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
            "Sea: %s | Race: %s | Fragments: %s | Cyborg V1: %s | Ghoul V1: %s",
            getSeaText(),
            race and tostring(race.Value) or "waiting",
            fragments and tostring(fragments.Value) or "waiting",
            hasCyborgV1() and "yes" or "no",
            hasGhoulV1() and "yes" or "no"
        )

        local orderExists =
            (workspace:FindFirstChild("Enemies")
                and workspace.Enemies:FindFirstChild("Order"))
            or ReplicatedStorage:FindFirstChild("Order")

        ItemLabel.Text = string.format(
            "State: %s | Fist: %s | Microchip: %s | Core Brain: %s | Order: %s\nGhoul module: %s",
            tostring(CyborgBlockPartUnlocked or readMainState()),
            hasToolForUI("Fist of Darkness") and "yes" or "no",
            hasToolForUI("Microchip") and "yes" or "no",
            hasToolForUI("Core Brain") and "yes" or "no",
            orderExists and "yes" or "no",
            tostring(RaceFlow.GhoulStatus or "idle")
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
            "Hop: %s | pages %s-%s | requested %s | done %s | failed %s | candidates %s | selected %s\nConfig: maxPages=%s, pagesPerBatch=%s, concurrency=%s, timeout=%ss, maxPlayers=%s, region=%s",
            tostring(hop.Status or "Idle"),
            tostring(hop.StartPage or 0),
            tostring(hop.EndPage or 0),
            tostring(hop.RequestedPages or 0),
            tostring(hop.CompletedPages or hop.ScannedPages or 0),
            tostring(hop.FailedPages or 0),
            tostring(hop.Candidates or 0),
            selected,
            tostring(getgenv().Settings["Hop Max Pages"]),
            tostring(getgenv().Settings["Hop Pages Per Batch"]),
            tostring(getgenv().Settings["Hop Scan Concurrency"] or 25),
            tostring(getgenv().Settings["Hop Batch Timeout"] or 18),
            tostring(getgenv().Settings["Hop Max Players"]),
            tostring(getgenv().Settings["Hop Forced Region"] or "any")
        )

        task.wait(1)
    end
end)

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

    -- Config Ä‘Æ°á»£c Æ°u tiÃªn Ä‘á»ƒ má»i call HopServer(8/10) Ä‘á»u dÃ¹ng cÃ¹ng má»™t giÃ¡ trá»‹.
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

    local concurrency = math.max(1, math.floor(tonumber(settings["Hop Scan Concurrency"]) or 25))
    concurrency = math.min(concurrency, pagesPerBatch)

    local batchTimeout = math.max(3, tonumber(settings["Hop Batch Timeout"]) or 18)

    return {
        MaxPages = maxPages,
        PagesPerBatch = pagesPerBatch,
        MaxPlayers = maxPlayers,
        ForcedRegion = forcedRegion,
        Concurrency = concurrency,
        BatchTimeout = batchTimeout,
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

    local pages = {}
    for offset = 0, config.PagesPerBatch - 1 do
        pages[#pages + 1] = ((startPage - 1 + offset) % config.MaxPages) + 1
    end

    local candidates = {}
    local seenJobs = {}
    local cursor = 0
    local completed = 0
    local failed = 0
    local workersDone = 0
    local active = true
    local workerCount = math.min(config.Concurrency, #pages)
    local scanStartedAt = tick()

    DashboardState.Hop.Status = "Scanning parallel"
    DashboardState.Hop.StartPage = pages[1] or startPage
    DashboardState.Hop.EndPage = pages[#pages] or startPage
    DashboardState.Hop.CurrentPage = pages[1] or startPage
    DashboardState.Hop.ScannedPages = 0
    DashboardState.Hop.RequestedPages = #pages
    DashboardState.Hop.CompletedPages = 0
    DashboardState.Hop.FailedPages = 0
    DashboardState.Hop.TimedOut = false
    DashboardState.Hop.Candidates = 0
    DashboardState.Hop.SelectedJobId = nil
    DashboardState.Hop.SelectedPlayers = nil
    DashboardState.Hop.SelectedRegion = nil

    local function processPageData(pageData)
        if type(pageData) ~= "table" then
            return
        end

        for jobId, info in pairs(pageData) do
            local jobKey = tostring(jobId)
            if type(info) == "table"
                and jobKey ~= tostring(game.JobId)
                and not seenJobs[jobKey] then
                local players = tonumber(info.Count)
                local region = info.Region or info.Regoin
                local regionOk =
                    not config.ForcedRegion
                    or normalizeRegion(region) == normalizeRegion(config.ForcedRegion)

                if players and players <= config.MaxPlayers and regionOk then
                    seenJobs[jobKey] = true
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

    local function worker()
        while active do
            cursor = cursor + 1
            local index = cursor
            local page = pages[index]
            if not page then
                break
            end

            DashboardState.Hop.CurrentPage = page
            local ok, pageData = pcall(function()
                return serverBrowser:InvokeServer(page)
            end)

            if not active then
                break
            end

            if ok and type(pageData) == "table" then
                processPageData(pageData)
            else
                failed = failed + 1
            end

            completed = completed + 1
            DashboardState.Hop.ScannedPages = completed
            DashboardState.Hop.CompletedPages = completed
            DashboardState.Hop.FailedPages = failed
            DashboardState.Hop.Candidates = #candidates
            DashboardState.Hop.Status = string.format(
                "Scanning %d/%d pages (%d workers)",
                completed,
                #pages,
                workerCount
            )
        end

        workersDone = workersDone + 1
    end

    for _ = 1, workerCount do
        task.spawn(worker)
    end

    repeat
        task.wait(0.05)
    until workersDone >= workerCount
        or (tick() - scanStartedAt) >= config.BatchTimeout

    if workersDone < workerCount then
        active = false
        DashboardState.Hop.TimedOut = true
        DashboardState.Hop.Status = string.format(
            "Batch timeout: %d/%d pages completed",
            completed,
            #pages
        )
    else
        DashboardState.Hop.Status = "Scan complete"
    end

    local lastRequestedPage = pages[#pages] or startPage
    DashboardState.Hop.NextPage = ((lastRequestedPage - 1 + 1) % config.MaxPages) + 1

    -- Best server: Ã­t player nháº¥t; náº¿u báº±ng nhau, Æ°u tiÃªn dá»¯ liá»‡u má»›i hÆ¡n.
    table.sort(candidates, function(a, b)
        if a.Players ~= b.Players then
            return a.Players < b.Players
        end

        if a.LastUpdate ~= b.LastUpdate then
            return a.LastUpdate > b.LastUpdate
        end

        return tostring(a.JobId) < tostring(b.JobId)
    end)

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

    -- Náº¿u teleport khÃ´ng cháº¡y do lá»—i im láº·ng, cho phÃ©p thá»­ láº¡i sau.
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
            safeWriteFile(progressfile, "unlock")
        elseif args:find("Microchip not found") then
            CyborgBlockPartUnlocked = "chest"
            safeWriteFile(progressfile, "chest")
        end
    end
    return hookedNotification(...)
end))

local all = 0
local fragok = false;
task.spawn(function()
    while task.wait(0.5) do
        xpcall(function()
            local currentRace = getCurrentRaceName()

            -- Completed: chi doc runtime state (da doc file 1 lan luc startup).
            -- KHONG safeReadFile moi 0.5s tick (giam file I/O - quan trong khi 25 tab/1 may).
            if RaceFlow.Completed then
                Tween(false)
                SetText("Completed-done | Cyborg V1 + Ghoul V1 confirmed")
                return
            end

            -- Sau khi module Ghoul doi race sang Ghoul, marker Cyborg da luu tu truoc
            -- se cho phep xac nhan du ca hai race va ghi file ket qua cuoi.
            if writeCompletedDone() then
                Tween(false)
                SetText("Completed-done | Cyborg V1 + Ghoul V1 confirmed")
                return
            end

            -- CO Cyborg V1 roi -> DOI LUON sang Ghoul bang module tu-build
            -- (farm ecto -> boss Cursed Captain -> NPC Experimic mua Ectoplasm/Buy/4).
            if currentRace == "Cyborg" then
                markCyborgOwned()
                -- Khoi dong module Ghoul 1 lan. QUAN TRONG: khi module dang chay thi
                -- main loop TUYET DOI khong dung toi chuyen dong (KHONG Tween(false)),
                -- vi module dung Tween de di chuyen -> neu main loop huy moi 0.5s se ket.
                if not RaceFlow.GhoulStarted then
                    Tween(false)          -- chi huy tween Cyborg 1 lan truoc khi giao cho module
                    startGhoulModule()
                end
                -- module tu lo toan bo flow + status; main loop chi doi, khong can thiep
                return
            end

            if currentRace ~= "Cyborg"
                and LocalPlayer.Data.Fragments.Value >= 2500 then
                COMMF_:InvokeServer("CyborgTrainer", "Buy")
            end

            CyborgBlockPartUnlocked = readMainState()
            pcall(function()
                fireclickdetector(workspace.Map.CircleIsland.RaidSummon.Button.Main.ClickDetector)
            end)

            if CyborgBlockPartUnlocked == "unlock"
                or game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("CyborgTrainer", "Check") == true then
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
                                "Cyborg Chest | Outside valid 4h + 2h window\n"
                                .. "Uptime: "
                                .. FormatUptime(uptime)
                                .. " | Next valid: "
                                .. nextText
                                .. "\nHop server..."
                            )

                            task.wait(1)
                            HopServer(getgenv().Settings["Hop Max Players"])
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
                    end)(v)) then
                        -- KHONG de status khi module Ghoul dang chay (tranh nhap nhay UI)
                        if not RaceFlow.GhoulRunning then SetText("Buy Abilies: ".. v) end
                        COMMF_:InvokeServer("BuyHaki", v)
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

--==================================================================
--  MODULE GHOUL v2  (tu-build, KHONG dung BananaHub)
--  Refactor: giam lag/giat, tach remote khoi combat loop, movement controller
--  ben vung (1 Heartbeat pin CFrame -> khong tao tween moi moi tick).
--  Flow: Cyborg V1 -> doi Ghoul: farm Ectoplasm -> boss Cursed Captain ->
--        co Hellfire Torch -> toi NPC Experimic -> Ectoplasm/BuyCheck + Buy(4).
--  Remote GIU NGUYEN (bat tu hook): CommF_("Ectoplasm","Buy",4).
--==================================================================
GhoulModuleRun = function()
    local GC = getgenv().GhoulConfig or {}
    local ECTO_NEEDED   = tonumber(GC["Ectoplasm Needed"]) or 100
    local RACE_ID       = tonumber(GC["Ghoul Race Id"]) or 4
    local BOSS_NAME     = GC["Boss Name"] or "Cursed Captain"
    local BOSS_API      = GC["Boss API"] or "http://fi12.bot-hosting.cloud:20112/api/name=cursedcaptain"
    local FETCH_COUNT   = tonumber(GC["Fetch Count"]) or 10
    local HOP_DELAY     = tonumber(GC["Hop Delay"]) or 1.5
    local DETECT_TO     = tonumber(GC["Detect Timeout"]) or 6
    local SHIP_ENTRANCE = GC["Ship Entrance"] or Vector3.new(923.21252441406, 126.9760055542, 32852.83203125)
    local SHIP_CENTER   = GC["Ship Center"] or Vector3.new(911.35827636719, 125.95812988281, 33159.5390625)
    local SHIP_RADIUS   = tonumber(GC["Ship Radius"]) or 3000
    local SHIP_MOBS     = GC["Ship Mobs"] or {"Ship Deckhand", "Ship Engineer", "Ship Steward", "Ship Officer"}
    local NPC_KEYWORDS  = GC["Race NPC Keywords"] or {"experim", "ghoul", "ecto"}
    local NPC_POS       = GC["Race NPC Pos"]
    local NPC_DIST      = tonumber(GC["Race NPC Dist"]) or 12

    -- ==== interval config (default an toan, cho 25 tab/1 may) ====
    local MAIN_TICK        = tonumber(GC["Ghoul Main Tick"]) or 0.10
    local BOSS_TICK        = tonumber(GC["Ghoul Boss Combat Tick"]) or 0.06
    local MOB_TICK         = tonumber(GC["Ghoul Mob Combat Tick"]) or 0.08
    local BRING_INTERVAL   = tonumber(GC["Ghoul Bring Mob Interval"]) or 0.60
    local ECTO_REFRESH     = tonumber(GC["Ghoul Ectoplasm Refresh"]) or 2.00
    local INV_REFRESH      = tonumber(GC["Ghoul Inventory Refresh"]) or 5.00
    local BOSS_DETECT_INT  = tonumber(GC["Ghoul Boss Detect Interval"]) or 0.35
    local STATUS_INT       = tonumber(GC["Ghoul Status Update Interval"]) or 0.50
    local ENTRANCE_RETRY   = tonumber(GC["Ghoul Entrance Retry Interval"]) or 2.00
    local REACQUIRE_INT    = tonumber(GC["Ghoul Target Reacquire Interval"]) or 0.35
    local DEBUG            = GC["Ghoul Debug"] == true

    -- token: khi module chay lai (respawn/hop re-exec) token cu khac -> worker cu tu thoat
    local RUN_TOKEN = {}
    _G.__GhoulRunToken = RUN_TOKEN
    local function alive() return _G.__GhoulRunToken == RUN_TOKEN and not getgenv().GHOUL_STOP end

    -- ==== char refs (doc fresh, an toan sau respawn) ====
    local function curChar() return LocalPlayer.Character end
    local function curHRP()  local c = LocalPlayer.Character return c and c:FindFirstChild("HumanoidRootPart") end
    local function curHum()  local c = LocalPlayer.Character return c and c:FindFirstChildWhichIsA("Humanoid") end
    local function charAlive()
        local h = curHum()
        return h and h.Health > 0 and curHRP() ~= nil
    end

    -- ==== status (chi cap nhat khi doi + throttle) ====
    local _lastStatusText, _lastStatusAt = nil, 0
    local function GStatus(t)
        t = tostring(t)
        RaceFlow.GhoulStatus = t
        if t ~= _lastStatusText and (tick() - _lastStatusAt) >= STATUS_INT then
            _lastStatusAt = tick()
            _lastStatusText = t
            SetText("Ghoul: " .. t)
            print("[Ghoul] " .. t)
        end
    end

    -- ==== ECTOPLASM cache (worker nen, combat chi doc) ====
    local Runtime = { Ectoplasm = 0, TorchLocal = false, TorchInv = false }
    local _ectoReqNow = false
    task.spawn(function()
        while alive() do
            local ok, n = pcall(function() return tonumber(COMMF_:InvokeServer("Ectoplasm", "Check")) end)
            if ok and n then Runtime.Ectoplasm = n end
            -- cho ECTO_REFRESH giay, nhung neu co yeu cau refresh uu tien thi thoat som
            local waited = 0
            while alive() and waited < ECTO_REFRESH and not _ectoReqNow do
                task.wait(0.2) waited = waited + 0.2
            end
            _ectoReqNow = false
        end
    end)
    local function GetEcto() return Runtime.Ectoplasm end
    local function RequestEctoRefresh() _ectoReqNow = true end

    -- ==== TORCH: local qua event (nhanh) + inv qua worker (cham, khong chan combat) ====
    local torchConns = {}
    local function isTorchTool(x)
        return x and x:IsA("Tool") and (x.Name == "Hellfire Torch" or x.Name:find("Hellfire"))
    end
    local function scanLocalTorch()
        for _, cont in ipairs({ LocalPlayer:FindFirstChild("Backpack"), LocalPlayer.Character }) do
            if cont then
                for _, x in ipairs(cont:GetChildren()) do
                    if isTorchTool(x) then return true end
                end
            end
        end
        return false
    end
    local function bindTorchEvents()
        for _, c in ipairs(torchConns) do pcall(function() c:Disconnect() end) end
        torchConns = {}
        Runtime.TorchLocal = scanLocalTorch()
        local function watch(container)
            if not container then return end
            torchConns[#torchConns+1] = container.ChildAdded:Connect(function(x)
                if isTorchTool(x) then Runtime.TorchLocal = true end
            end)
            torchConns[#torchConns+1] = container.ChildRemoved:Connect(function()
                Runtime.TorchLocal = scanLocalTorch()
            end)
        end
        watch(LocalPlayer:FindFirstChild("Backpack"))
        watch(LocalPlayer.Character)
    end
    bindTorchEvents()
    torchConns[#torchConns+1] = LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.5) if alive() then bindTorchEvents() end
    end)
    -- inv worker: chi de fallback xac nhan (cooldown INV_REFRESH), KHONG chan combat
    task.spawn(function()
        while alive() do
            if not Runtime.TorchLocal then
                local ok, inv = pcall(function() return COMMF_:InvokeServer("getInventory") end)
                if ok and type(inv) == "table" then
                    local found = false
                    for _, v in pairs(inv) do
                        if type(v) == "table" and v.Name and tostring(v.Name):find("Hellfire") then found = true break end
                    end
                    Runtime.TorchInv = found
                end
            end
            local waited = 0
            while alive() and waited < INV_REFRESH do task.wait(0.5) waited = waited + 0.5 end
        end
    end)
    local function HasTorchLocal() return Runtime.TorchLocal end
    local function HasTorch() return Runtime.TorchLocal or Runtime.TorchInv end

    local function IsGhoul() return getCurrentRaceName():lower() == "ghoul" end

    -- ==== enemy helpers (snapshot 1 lan/tick khi can) ====
    local function AliveModel(m)
        if not m or not m:IsA("Model") then return nil end
        if IsDied(m) then return nil end
        return m
    end
    local function FindBoss()
        local en = workspace:FindFirstChild("Enemies")
        if not en then return nil end
        local m = en:FindFirstChild(BOSS_NAME)
        return AliveModel(m)
    end
    local function CountShipMobsAlive(snapshot)
        local n = 0
        for _, m in ipairs(snapshot) do
            if m:IsA("Model") and not IsDied(m) then
                for _, nm in ipairs(SHIP_MOBS) do
                    if m.Name == nm then n = n + 1 break end
                end
            end
        end
        return n
    end
    local function FirstAliveShipMob(snapshot)
        for _, m in ipairs(snapshot) do
            if m:IsA("Model") and not IsDied(m) then
                for _, nm in ipairs(SHIP_MOBS) do
                    if m.Name == nm then return m end
                end
            end
        end
        return nil
    end

    -- ==== ATTACK: cache remote, hit packet cho target da biet (khong scan full) ====
    local Net = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("Net")
    local RA = Net and Net:FindFirstChild("RE/RegisterAttack")
    local RH = Net and Net:FindFirstChild("RE/RegisterHit")
    local function sendHitPacket(h)
        pcall(function() if RA then RA:FireServer() end end)
        pcall(function() if RH then RH:FireServer(unpack(h)) end end)
        pcall(function()
            if remoteAttack and idremote and seed then
                cloneref(remoteAttack):FireServer(string.gsub("RE/RegisterHit", ".", function(c)
                    return string.char(bit32.bxor(string.byte(c), math.floor(workspace:GetServerTimeNow()/10%10)+1))
                end), bit32.bxor(idremote + 909090, seed * 2), unpack(h))
            end
        end)
    end
    -- danh 1 target da cache (boss). Khong quet workspace.
    local _lastAtkT = 0
    local function FastAttackTarget(target, interval)
        if tick() - _lastAtkT < (interval or BOSS_TICK) then return end
        if not charAlive() then return end
        local hrp = curHRP()
        if not (curChar() and curChar():FindFirstChildWhichIsA("Tool")) then return end
        if not target or not target.Parent then return end
        local h2 = target:FindFirstChild("Humanoid")
        local part = target:FindFirstChild("Head") or target:FindFirstChild("HumanoidRootPart")
        if not h2 or h2.Health <= 0 or not part then return end
        if (part.Position - hrp.Position).Magnitude > 80 then return end
        _lastAtkT = tick()
        sendHitPacket({ part, { { target, part } } })
    end
    -- danh nhieu quai gan (farm ecto) - snapshot 1 lan
    local _lastMobAtkT = 0
    local function FastAttackNearby(snapshot, interval)
        if tick() - _lastMobAtkT < (interval or MOB_TICK) then return end
        if not charAlive() then return end
        local hrp = curHRP()
        if not (curChar() and curChar():FindFirstChildWhichIsA("Tool")) then return end
        local list = {}
        for _, e in ipairs(snapshot) do
            if e:IsA("Model") and not IsDied(e) then
                local h2 = e:FindFirstChild("Humanoid")
                local ehrp = e:FindFirstChild("HumanoidRootPart")
                if h2 and ehrp and h2.Health > 0 and (ehrp.Position - hrp.Position).Magnitude <= 65 then
                    list[#list+1] = e
                end
            end
        end
        if #list == 0 then return end
        _lastMobAtkT = tick()
        local h = { nil, {} }
        for i = 1, #list do
            local v = list[i]
            local part = v:FindFirstChild("Head") or v:FindFirstChild("HumanoidRootPart")
            if not h[1] then h[1] = part end
            h[2][#h[2]+1] = { v, part }
        end
        sendHitPacket(h)
    end

    -- ==== EQUIP melee (cache, chi equip khi can) ====
    local _lastEquipT = 0
    local function EnsureMelee()
        local c = curChar()
        if not c then return end
        local tool = c:FindFirstChildWhichIsA("Tool")
        if tool and tool.ToolTip == "Melee" then return end
        if tick() - _lastEquipT < 1 then return end
        _lastEquipT = tick()
        pcall(function() EquipWeapon("Melee") end)
    end

    -- ==== BRING MOB (chi cho quai thuong, throttle; KHONG dung cho boss) ====
    local _lastBringT = 0
    local function BringShipMobs(anchorHRP)
        if tick() - _lastBringT < BRING_INTERVAL then return end
        _lastBringT = tick()
        pcall(function() setscriptable(LocalPlayer, "SimulationRadius", true) end)
        pcall(function() sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge) end)
        local hrp = curHRP()
        if not hrp or not anchorHRP then return end
        local anchor = anchorHRP.CFrame
        local i = 0
        for _, m in ipairs(workspace.Enemies:GetChildren()) do
            if m:IsA("Model") and not IsDied(m) then
                local isShip = false
                for _, nm in ipairs(SHIP_MOBS) do if m.Name == nm then isShip = true break end end
                if isShip then
                    local mh = m:FindFirstChild("HumanoidRootPart")
                    if mh and (hrp.Position - mh.Position).Magnitude <= 1500 then
                        if not isnetworkowner or isnetworkowner(mh) then
                            pcall(function()
                                mh.AssemblyLinearVelocity = Vector3.zero
                                mh.AssemblyAngularVelocity = Vector3.zero
                                mh.CFrame = anchor * CFrame.new(i * 2, 0, 0)
                            end)
                        end
                        i = i + 1
                        if i >= 6 then break end
                    end
                end
            end
        end
    end

    -- ==== MOVEMENT CONTROLLER: 1 Heartbeat pin CFrame (khong tao tween moi/tick) ====
    local Move = { conn = nil, desired = nil }
    function Move.Start()
        if Move.conn then return end
        Move.conn = RunService.Heartbeat:Connect(function()
            local d = Move.desired
            if not d then return end
            local hrp = curHRP()
            local hum = curHum()
            if not hrp or not hum or hum.Health <= 0 then return end
            pcall(function()
                hum.Sit = false
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
                hrp.CFrame = d
            end)
        end)
    end
    function Move.SetDesired(cf) Move.desired = cf end
    function Move.Stop()
        if Move.conn then pcall(function() Move.conn:Disconnect() end) Move.conn = nil end
        Move.desired = nil
    end

    -- ==== CLEANUP (goi khi chuyen phase quan trong / stop / xong) ====
    local function CleanupMovement()
        Move.Stop()
        pcall(function() Tween(false) end)
    end

    -- ==== SHIP: len Cursed Ship (dau hieu thuc te + debounce entrance) ====
    local ExperimicModel, ExperimicPart
    local function FindNPC()
        if ExperimicPart and ExperimicPart.Parent and ExperimicModel and ExperimicModel.Parent then
            return ExperimicModel, ExperimicPart
        end
        ExperimicModel, ExperimicPart = nil, nil
        local containers = {}
        for _, nm in ipairs({"NPCs", "Npcs", "NPC"}) do
            local f = workspace:FindFirstChild(nm)
            if f then containers[#containers+1] = f end
        end
        if #containers == 0 then containers = { workspace } end
        for _, cont in ipairs(containers) do
            for _, m in ipairs(cont:GetChildren()) do
                if m:IsA("Model") then
                    local lname = m.Name:lower()
                    for _, kw in ipairs(NPC_KEYWORDS) do
                        if lname:find(kw) then
                            local part = m:FindFirstChild("HumanoidRootPart") or m:FindFirstChildWhichIsA("BasePart")
                            if part then ExperimicModel, ExperimicPart = m, part return m, part end
                        end
                    end
                end
            end
        end
        return nil, nil
    end
    local function OnShip()
        local hrp = curHRP()
        if not hrp then return false end
        if (hrp.Position - SHIP_CENTER).Magnitude <= SHIP_RADIUS then return true end
        -- dau hieu thuc te: thay boss / ship mob / NPC gan
        local pos = hrp.Position
        local en = workspace:FindFirstChild("Enemies")
        if en then
            for _, m in ipairs(en:GetChildren()) do
                if m:IsA("Model") then
                    local ok = (m.Name == BOSS_NAME)
                    if not ok then for _, nm in ipairs(SHIP_MOBS) do if m.Name == nm then ok = true break end end end
                    if ok then
                        local mh = m:FindFirstChild("HumanoidRootPart")
                        if mh and (mh.Position - pos).Magnitude <= 900 then return true end
                    end
                end
            end
        end
        local _, np = FindNPC()
        if np and (np.Position - pos).Magnitude <= 900 then return true end
        return false
    end
    -- len ship: debounce entrance, tween tiep can 1 lan, timeout ngan
    local function EnsureOnShip(timeout)
        if OnShip() then return true end
        timeout = timeout or 22
        local startT = tick()
        local lastEntrance = 0
        while alive() and (tick() - startT) < timeout do
            if OnShip() then CleanupMovement() return true end
            if tick() - lastEntrance >= ENTRANCE_RETRY then
                lastEntrance = tick()
                GStatus("Len Cursed Ship...")
                pcall(function() COMMF_:InvokeServer("requestEntrance", SHIP_ENTRANCE) end)
            end
            -- tween tiep can (Tween tu chong tao lai neu dang chay)
            pcall(function() Tween(CFrame.new(SHIP_CENTER) * CFrame.new(0, 12, 0)) end)
            task.wait(0.35)
        end
        CleanupMovement()
        return OnShip()
    end

    -- ==== di chuyen toi 1 CFrame roi cho (dung cho tiep can NPC) ====
    local function MoveToAndWait(targetCF, stopDist, timeout)
        stopDist = stopDist or NPC_DIST
        timeout = timeout or 8
        local startT = tick()
        pcall(function() Tween(targetCF) end)
        while alive() and (tick() - startT) < timeout do
            local hrp = curHRP()
            if hrp and (hrp.Position - targetCF.Position).Magnitude <= stopDist then
                CleanupMovement()
                return true
            end
            if not charAlive() then break end
            task.wait(0.1)
        end
        CleanupMovement()
        local hrp = curHRP()
        return hrp and (hrp.Position - targetCF.Position).Magnitude <= stopDist
    end

    -- ==== MUA GHOUL: toi sat NPC Experimic -> BuyCheck + Buy ====
    local function TryBuyGhoul()
        if IsGhoul() then return true end
        if not HasTorch() then return false end
        EnsureOnShip()
        local _, part = FindNPC()
        local npcCF = part and part.CFrame
        if not npcCF and NPC_POS then
            npcCF = (typeof(NPC_POS) == "CFrame") and NPC_POS or CFrame.new(NPC_POS)
        end
        if not npcCF then GStatus("Khong thay NPC Experimic") return false end
        GStatus("Toi NPC Experimic")
        MoveToAndWait(npcCF * CFrame.new(0, 3, 4), NPC_DIST, 8)
        local hrp = curHRP()
        if not hrp or (hrp.Position - npcCF.Position).Magnitude > NPC_DIST + 5 then
            GStatus("Chua toi duoc NPC -> retry")
            return false
        end
        GStatus("Mua Ghoul (BuyCheck + Buy)")
        local rC, rB
        pcall(function()
            rC = COMMF_:InvokeServer("Ectoplasm", "BuyCheck", RACE_ID)
            task.wait(0.6)
            rB = COMMF_:InvokeServer("Ectoplasm", "Buy", RACE_ID)
        end)
        print("[Ghoul] BuyCheck ->", tostring(rC), "| Buy ->", tostring(rB))
        task.wait(1.2)
        RequestEctoRefresh()
        return IsGhoul()
    end

    -- ==== FARM ECTOPLASM: len ship, gom + danh quai ship, giet sach moi doi cho ====
    local function FarmEcto()
        GStatus("Farm Ectoplasm")
        if not EnsureOnShip() then return end
        Move.Start()
        while alive() do
            if IsGhoul() or HasTorchLocal() then break end
            if GetEcto() >= ECTO_NEEDED then break end
            if not charAlive() then task.wait(0.2) end

            local snapshot = workspace.Enemies:GetChildren()
            local mob = FirstAliveShipMob(snapshot)
            if not mob then
                -- het quai -> ve tam thuyen cho spawn (chi den day khi giet sach)
                Move.SetDesired(CFrame.new(SHIP_CENTER) * CFrame.new(0, 12, 0))
                GStatus("Cho quai Ship spawn... (" .. GetEcto() .. "/" .. ECTO_NEEDED .. ")")
                task.wait(0.4)
            else
                local mh = mob:FindFirstChild("HumanoidRootPart")
                if mh then
                    Move.SetDesired(mh.CFrame * CFrame.new(0, 14, 0))  -- pin tren dau cum quai
                    EnsureMelee()
                    BringShipMobs(mh)                                   -- gom (throttle)
                    FastAttackNearby(snapshot, MOB_TICK)               -- danh ca cum
                    GStatus("Farm Ectoplasm " .. GetEcto() .. "/" .. ECTO_NEEDED)
                end
                task.wait(MOB_TICK)
            end
        end
        CleanupMovement()
        RequestEctoRefresh()
        GStatus("Ectoplasm: " .. GetEcto() .. "/" .. ECTO_NEEDED)
    end

    -- ==== FETCH server co boss (API) + join ====
    local _lastFetch = 0
    local function HttpReq(url)
        local req = request or http_request or (syn and syn.request) or (fluxus and fluxus.request)
        if type(req) ~= "function" then return nil end
        for _ = 1, 3 do
            local ok, res = pcall(function()
                return req({ Url = url, Method = "GET",
                    Headers = { ["Accept"] = "application/json", ["User-Agent"] = "Roblox/WinInet" } })
            end)
            if ok and type(res) == "table" then return res.Body or res.body end
            task.wait(1)
        end
        return nil
    end
    -- Port tu Ghoul.lua (chuan): CHI lay server trung PlaceId (tranh Error 773),
    -- SORT theo timestamp MOI NHAT (server boss vua spawn) -> khong join server boss da chet.
    -- API khong co timestamp -> DAO mang (phan tu cuoi thuong la moi nhat).
    local function FetchBossServers()
        GStatus("Fetch server co boss...")
        local body = HttpReq(BOSS_API)
        if not body then return {} end
        local data
        pcall(function() data = HttpService:JSONDecode(body) end)
        if type(data) ~= "table" then return {} end
        local list = data.data or data.servers or data
        if type(list) ~= "table" then return {} end
        local cur = tonumber(game.PlaceId)
        local servers, skipped = {}, 0
        for _, v in ipairs(list) do
            if type(v) == "table" then
                local jobId = v.jobid or v.JobId or v.id
                local placeId = tonumber(v.placeid or v.PlaceId or v.place)
                local ts = tonumber(v.timestamp or v.time or v.updated_at)
                if jobId and placeId and placeId == cur then
                    servers[#servers+1] = { JobId = tostring(jobId), Timestamp = ts }
                elseif jobId and placeId and placeId ~= cur then
                    skipped = skipped + 1
                end
            end
        end
        if skipped > 0 then print("[Ghoul] Skipped " .. skipped .. " server khac PlaceId (current=" .. tostring(cur) .. ")") end

        -- uu tien server MOI NHAT
        local hasTs = false
        for _, s in ipairs(servers) do if s.Timestamp then hasTs = true break end end
        if hasTs then
            table.sort(servers, function(a, b) return (a.Timestamp or 0) > (b.Timestamp or 0) end)
        else
            local rev = {}
            for i = #servers, 1, -1 do rev[#rev+1] = servers[i] end
            servers = rev
        end

        -- loai jobid dang o + dedup
        local seen, out = {}, {}
        for _, s in ipairs(servers) do
            local jid = tostring(s.JobId)
            if jid ~= tostring(game.JobId) and not seen[jid] then
                seen[jid] = true
                out[#out+1] = jid
                if #out >= FETCH_COUNT then break end
            end
        end
        GStatus("API: " .. #out .. " server moi nhat")
        return out
    end
    -- Port tu Ghoul.lua (chuan): join bang __ServerBrowser (teleport TRONG place
    -- hien tai -> giu PlaceId -> tranh Error 773). Fallback TeleportToPlaceInstance
    -- CHI khi trung place hien tai. Tra ve true neu da phat lenh teleport.
    local function JoinJob(jobId)
        if not jobId or tostring(jobId) == "" or tostring(jobId) == tostring(game.JobId) then return false end
        local sb = ReplicatedStorage:FindFirstChild("__ServerBrowser")
        if sb then
            local ok = pcall(function() sb:InvokeServer("teleport", tostring(jobId)) end)
            if ok then return true end
        end
        local cur = tonumber(game.PlaceId)
        local okTp = pcall(function()
            TeleportService:TeleportToPlaceInstance(cur, tostring(jobId), LocalPlayer)
        end)
        return okTp
    end

    -- ==== FIGHT BOSS: pin tren dau boss (movement controller), danh target da cache ====
    local function FightBoss(boss)
        GStatus("Danh boss " .. BOSS_NAME)
        EnsureMelee()
        Move.Start()
        local lastReacquire = tick()
        while alive() do
            if HasTorchLocal() then break end
            if not charAlive() then task.wait(0.15) end
            -- reacquire boss neu target cu mat
            if (not boss or not boss.Parent or IsDied(boss)) and (tick() - lastReacquire) >= REACQUIRE_INT then
                lastReacquire = tick()
                boss = FindBoss()
            end
            if not boss then break end  -- boss chet/mat
            local bhrp = boss:FindFirstChild("HumanoidRootPart")
            if bhrp then
                Move.SetDesired(bhrp.CFrame * CFrame.new(0, 14, 0))  -- pin tren dau boss (on dinh)
                FastAttackTarget(boss, BOSS_TICK)                    -- danh target da biet
            end
            task.wait(BOSS_TICK)
        end
        CleanupMovement()
    end

    -- ==== FARM BOSS: len ship -> detect -> fight; khong co thi hop ====
    local function FarmBoss()
        if not EnsureOnShip() then return end
        -- detect boss (0.35s/lan cho toi timeout)
        GStatus("Tim boss trong server...")
        local deadline = tick() + DETECT_TO
        local boss = FindBoss()
        while alive() and not boss and tick() < deadline do
            if HasTorchLocal() then return end
            task.wait(BOSS_DETECT_INT)
            boss = FindBoss()
        end

        if boss then
            FightBoss(boss)
            -- boss xong: cho vai giay xem torch roi vao inv (local event se bat)
            for _ = 1, 8 do
                if not alive() or HasTorch() then return end
                task.wait(0.4)
            end
        else
            -- khong co boss -> hop (fetch co cooldown; dung loop khi teleport bat dau)
            if tick() - _lastFetch < 5 then task.wait(2) return end
            _lastFetch = tick()
            GStatus("Server khong co boss -> hop")
            local servers = FetchBossServers()
            if #servers == 0 then task.wait(3) return end
            -- join server MOI NHAT dau tien. Khi da phat lenh teleport -> phien se reset,
            -- DUNG loop ngay (khong join server khac de tranh huy teleport dang chay).
            for _, jid in ipairs(servers) do
                if not alive() or HasTorchLocal() then break end
                GStatus("Join server tim boss...")
                if JoinJob(jid) then
                    -- teleport da phat -> cho reset, khong join tiep
                    for _ = 1, 20 do
                        if not alive() then break end
                        task.wait(0.5)
                    end
                    return
                end
                task.wait(HOP_DELAY)   -- join loi -> thu server ke tiep
            end
            task.wait(2)
        end
    end

    -- ==== MAIN STATE LOOP ====
    GStatus("start")
    while alive() do
        if IsGhoul() then
            CleanupMovement()
            GStatus("DONE - da thanh Ghoul")
            return
        end

        if HasTorch() then
            if GetEcto() < ECTO_NEEDED then
                FarmEcto()
            elseif TryBuyGhoul() then
                CleanupMovement()
                GStatus("DONE - da thanh Ghoul")
                return
            else
                task.wait(1.2)
            end
        else
            if GetEcto() < ECTO_NEEDED then
                FarmEcto()
            else
                FarmBoss()
            end
        end
        task.wait(MAIN_TICK)
    end

    CleanupMovement()
    GStatus("stopped")
end
