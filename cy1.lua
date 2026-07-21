getgenv().Settings = {
    ["Max Chests"] = 50;
    ["Skip Chest Delay"] = 1;
    ["Reset After Collect Chests"] = 7;
    ["Katakuri Progress"] = 100;
    ["Fragments"] = 1000;
    ["Black Screen"] = false;
    ["Chest Tween Speed"] = 325;
    ["Chest Touch Radius"] = 8;

    -- Server uptime chest window: every 4 hours, active for 2 hours
    ["Chest Server Period"] = 4 * 60 * 60;
    ["Chest Server Grace"] = 2 * 60 * 60;
}

repeat task.wait(0.5) until game:IsLoaded() and game.Players.LocalPlayer and game.Players.LocalPlayer:FindFirstChildWhichIsA("PlayerGui")
if getgenv().WARCLOADER then StarterGui:SetCore("SendNotification", {Title = "Execution Blocked", Text = "The script is already running. Please wait 10 seconds", Duration = 5}) return end getgenv().WARCLOADER = true task.delay(10, (function() getgenv().WARCLOADER = nil end))

getgenv().cloneref = cloneref or clonereference or function(x) return x end
getgenv().isnetworkowner = isnetworkowner or isNetworkOwner or function() return true end
workspace = cloneref(workspace) or cloneref(Workspace) or (getrenv and (getrenv().workspace or getrenv().Workspace)) or cloneref(game:GetService("Workspace"))
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
if not game:IsLoaded() or workspace.DistributedGameTime <= 10 then
    local WFGTL = COREGUI:FindFirstChild("WFGTL") or Instance.new("Hint", COREGUI)
    WFGTL.Text = "Just a moment... Waiting while the game loads - This won't take long!"
    task.wait(10 - workspace.DistributedGameTime)
    WFGTL:Destroy()
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

pcall(function() LocalPlayer.PlayerGui:FindFirstChild("Blank"):Destroy() end)
local BlankScreen = LocalPlayer.PlayerGui:FindFirstChild("Blank") or Instance.new("ScreenGui", LocalPlayer.PlayerGui)
BlankScreen.Name = "Blank" BlankScreen.ResetOnSpawn = false BlankScreen.DisplayOrder = -math.huge BlankScreen.IgnoreGuiInset = true
local Black = BlankScreen:FindFirstChild("Black Screen") or Instance.new("Frame", BlankScreen)
Black.Name = "Black Screen" Black.Size = UDim2.new(1, 0, 1, 0) Black.BackgroundColor3 = Color3.new(0, 0, 0) Black.ZIndex = -math.huge
Black.Visible = getgenv().Settings["Black Screen"] or false

RunService:Set3dRenderingEnabled(not Black.Visible)

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
        RunService:Set3dRenderingEnabled(not Black.Visible)
        StarterGui:SetCore("SendNotification", {
            Title = "Black Screen",
            Text = Black.Visible and "Đã BẬT màn hình đen (Tắt Render 3D)" or "Đã TẮT màn hình đen (Bật Render 3D)",
            Duration = 2
        })
    end
end)

local function SetText(newText) label.Text = newText end
local mainfile = LocalPlayer.Name .. ".txt"
if not isfile(mainfile) then writefile(mainfile, "NaN") end

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
    for _ in j do
        return true
    end
end

local LastServersDataPulled, CachedServers
function GetServers()
    if LastServersDataPulled then
        if os.time() - LastServersDataPulled < 60 then
            return CachedServers
        end
    end

    for i = 1, 100, 1 do
        local data = game:GetService("ReplicatedStorage"):WaitForChild("__ServerBrowser"):InvokeServer(i)
        if IfTableHaveIndex(data) then
            LastServersDataPulled = os.time()
            CachedServers = data
            return data
        end
    end
end

HopServer = function(MaxPlayers, ForcedRegion)
    MaxPlayers = MaxPlayers or 8
    SetText("Fetching Server...")
    local Servers = GetServers()
    local ArrayServers = {}

    for i, v in next, Servers do
        if v.Count <= MaxPlayers then
            table.insert(ArrayServers, {
                JobId = i,
                Players = v.Count,
                LastUpdate = v.__LastUpdate,
                Region = v.Region
            })
        end
    end
    SetText(#ArrayServers, 'servers received')
    local ServerData
    for i = 1, #ArrayServers do
        while task.wait(1) do
            local Index = math.random(1, #ArrayServers)
            ServerData = ArrayServers[Index]
            if ServerData then
                if not ForcedRegion or ServerData.Regoin == ForcedRegion then
                    SetText("Found Server:", ServerData.JobId, 'Player Count:', ServerData.Players, "Region:", ServerData.Region)
                    break
                end
            end
        end

        print('Teleporting to', ServerData.JobId, '...')
        game:GetService("ReplicatedStorage"):WaitForChild("__ServerBrowser"):InvokeServer('teleport', ServerData.JobId)
    end
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
