local Defaults = {
    Enabled = true,

    -- BodyVelocity di chuyển thật; Tween điều khiển độ tăng tốc,
    -- CFrame:Lerp-style smoothing được áp dụng lên vector Velocity mỗi Heartbeat.
    VelocitySpeed = 48,
    VelocityMinSpeed = 40,
    VelocityMaxSpeed = 55,
    VelocityAccelerationTime = 0.18,
    VelocityLerpResponse = 12.0,
    VelocityBrakeDistance = 9,
    VelocityMinBrakeMultiplier = 0.16,
    VelocityArrivalDistance = 0.90,
    VelocityTargetYOffset = -1.05,

    -- Tới đúng coin, dừng hẳn trong thời gian rất ngắn để coin được tính,
    -- sau đó mới chọn coin gần nhất tiếp theo. Không giữ quán tính giữa 2 coin.
    StopAtEveryCoin = true,
    CoinStopTime = 0.035,
    CoinSnapDistance = 2.40,
    PendingCoinTime = 0.45,

    -- Khi tới coin, tạm tăng FPS và phát touch bằng nhiều part cho tới khi
    -- nhận CoinCollected. Chỉ đứng lâu khi server thực sự chưa xác nhận.
    PickupFPSCap = 30,
    PickupConfirmTimeout = 0.46,
    PickupPulseInterval = 0.035,
    PickupContactHold = 0.028,
    PickupPostConfirmDelay = 0.025,
    PickupMicroSweepDistance = 0.18,
    PickupMaxTouchParts = 10,

    -- Chống bay ra ngoài map: nếu vận tốc làm nhân vật đi xa mục tiêu bất thường
    -- hoặc tụt quá sâu so với coin, dừng ngay và quay về vị trí an toàn gần nhất.
    SafetyMaxTargetError = 24,
    SafetyMaxVerticalDrop = 28,
    VelocityTimeoutPadding = 4,
    VelocityMaxTimeout = 22,
    VelocityP = 14000,
    VelocityMaxForce = 1e9,
    GyroP = 18000,
    GyroD = 700,

    MaxTargetDistance = 650,
    TouchCount = 1,
    TouchInterval = 0.025,
    TouchSettleTime = 0.045,
    RetryPerCoin = 2,
    FailedCoinCooldown = 0.75,
    NoCoinDelay = 0.30,
    FullBagDelay = 1,

    RoundStartDelay = 1.20,
    CharacterSpawnDelay = 1.00,
    StopWhenDailyCompleted = true,
    DailyTargetFallback = 960,

    Noclip = true,
    LockCharacterPose = true,
    AntiAFK = true,
    FPSCap = 5,
    ShowStatusGUI = true,
    Debug = false,
}

getgenv().MM2_SUMMER_2026 = getgenv().MM2_SUMMER_2026 or {}
local Config = getgenv().MM2_SUMMER_2026

for key, value in pairs(Defaults) do
    if Config[key] == nil then
        Config[key] = value
    end
end

if Config.ScriptVersion ~= "14.0-confirmed-multitouch" then
    for key, value in pairs(Defaults) do
        Config[key] = value
    end
end
Config.ScriptVersion = "14.0-confirmed-multitouch"

local RunToken = {}
getgenv().MM2_SUMMER_2026_TOKEN = RunToken
getgenv().MM2_SUMMER_2026_RUNNING = true

local function isRunning()
    return getgenv().MM2_SUMMER_2026_TOKEN == RunToken
        and getgenv().MM2_SUMMER_2026_RUNNING
        and Config.Enabled
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GameplayRemotes = Remotes:WaitForChild("Gameplay")
local CoinCollectedRemote = GameplayRemotes:WaitForChild("CoinCollected")
local CoinsStartedRemote = GameplayRemotes:WaitForChild("CoinsStarted")
local RoundStartRemote = GameplayRemotes:WaitForChild("RoundStart")
local VictoryScreenRemote = GameplayRemotes:WaitForChild("VictoryScreen")

local function log(...)
    if Config.Debug then
        warn("[MM2 AutoDaily v14]", ...)
    end
end

if setfpscap then
    pcall(setfpscap, Config.FPSCap)
end

if Config.AntiAFK then
    LocalPlayer.Idled:Connect(function()
        pcall(function()
            VirtualUser:Button2Down(Vector2.zero, workspace.CurrentCamera.CFrame)
            task.wait(0.05)
            VirtualUser:Button2Up(Vector2.zero, workspace.CurrentCamera.CFrame)
        end)
    end)
end

local Character
local Humanoid
local RootPart
local CharacterReadyAt = math.huge
local CharacterParts = {}
local OriginalCollision = setmetatable({}, { __mode = "k" })
local CharacterDescendantConnection

local FarmActive = false
local MovementActive = false
local VelocityMover
local PoseGyro
local SpeedScale = Instance.new("NumberValue")
SpeedScale.Name = "MM2VelocityScale"
SpeedScale.Value = 0
local CurrentSpeedTween
local SmoothedVelocity = Vector3.zero
local CurrentAction = "Initializing"
local SessionCollected = 0
local LastSafeCFrame

local OriginalAutoRotate
local OriginalWalkSpeed
local OriginalJumpPower
local OriginalJumpHeight
local OriginalPlatformStand
local AnimateScript
local OriginalAnimateDisabled

local RoundState = {
    Active = false,
    PlayerAlive = false,
    Phase = "WAITING",
    Role = "Unknown",
    FarmUnlockAt = math.huge,
    ReceivedRoundStart = false,
}

local function vectorIsValid(vector)
    return vector
        and vector.X == vector.X
        and vector.Y == vector.Y
        and vector.Z == vector.Z
        and math.abs(vector.X) < 100000
        and math.abs(vector.Y) < 100000
        and math.abs(vector.Z) < 100000
end

local function cacheCharacterPart(object)
    if object:IsA("BasePart") then
        CharacterParts[#CharacterParts + 1] = object
    end
end

local function applyNoclip()
    if not Config.Noclip or not FarmActive then return end

    for index = #CharacterParts, 1, -1 do
        local part = CharacterParts[index]
        if not part or not part.Parent then
            table.remove(CharacterParts, index)
        else
            if OriginalCollision[part] == nil then
                OriginalCollision[part] = part.CanCollide
            end
            part.CanCollide = false
        end
    end
end

local function restoreCollision()
    for part, oldValue in pairs(OriginalCollision) do
        if part and part.Parent then
            pcall(function()
                part.CanCollide = oldValue
            end)
        end
    end
    table.clear(OriginalCollision)
end

local function lockPose()
    if not Config.LockCharacterPose or not Humanoid then return end

    if OriginalAutoRotate == nil then
        OriginalAutoRotate = Humanoid.AutoRotate
        OriginalWalkSpeed = Humanoid.WalkSpeed
        OriginalJumpPower = Humanoid.JumpPower
        OriginalJumpHeight = Humanoid.JumpHeight
        OriginalPlatformStand = Humanoid.PlatformStand
    end

    Humanoid.AutoRotate = false
    Humanoid.WalkSpeed = 0
    Humanoid.JumpPower = 0
    Humanoid.JumpHeight = 0
    Humanoid.Sit = false
    Humanoid.PlatformStand = true

    AnimateScript = Character and Character:FindFirstChild("Animate")
    if AnimateScript and AnimateScript:IsA("LocalScript") then
        if OriginalAnimateDisabled == nil then
            OriginalAnimateDisabled = AnimateScript.Disabled
        end
        AnimateScript.Disabled = true
    end

    pcall(function()
        for _, track in ipairs(Humanoid:GetPlayingAnimationTracks()) do
            track:Stop(0.05)
        end
    end)
end

local function restorePose()
    if Humanoid then
        if OriginalAutoRotate ~= nil then Humanoid.AutoRotate = OriginalAutoRotate end
        if OriginalWalkSpeed ~= nil then Humanoid.WalkSpeed = OriginalWalkSpeed end
        if OriginalJumpPower ~= nil then Humanoid.JumpPower = OriginalJumpPower end
        if OriginalJumpHeight ~= nil then Humanoid.JumpHeight = OriginalJumpHeight end
        if OriginalPlatformStand ~= nil then Humanoid.PlatformStand = OriginalPlatformStand end
    end

    if AnimateScript and AnimateScript.Parent and OriginalAnimateDisabled ~= nil then
        pcall(function()
            AnimateScript.Disabled = OriginalAnimateDisabled
        end)
    end

    OriginalAutoRotate = nil
    OriginalWalkSpeed = nil
    OriginalJumpPower = nil
    OriginalJumpHeight = nil
    OriginalPlatformStand = nil
    AnimateScript = nil
    OriginalAnimateDisabled = nil
end

local function ensureVelocityMover()
    if not RootPart or not RootPart.Parent then return nil end

    if not VelocityMover or VelocityMover.Parent ~= RootPart then
        if VelocityMover then pcall(function() VelocityMover:Destroy() end) end
        VelocityMover = Instance.new("BodyVelocity")
        VelocityMover.Name = "MM2_TweenLerpVelocity"
        VelocityMover.MaxForce = Vector3.new(
            Config.VelocityMaxForce,
            Config.VelocityMaxForce,
            Config.VelocityMaxForce
        )
        VelocityMover.P = Config.VelocityP
        VelocityMover.Velocity = Vector3.zero
        VelocityMover.Parent = RootPart
    end

    return VelocityMover
end

local function ensurePoseGyro()
    if not RootPart or not RootPart.Parent then return nil end

    if not PoseGyro or PoseGyro.Parent ~= RootPart then
        if PoseGyro then pcall(function() PoseGyro:Destroy() end) end
        PoseGyro = Instance.new("BodyGyro")
        PoseGyro.Name = "MM2_VelocityPoseGyro"
        PoseGyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
        PoseGyro.P = Config.GyroP
        PoseGyro.D = Config.GyroD
        PoseGyro.CFrame = RootPart.CFrame - RootPart.Position
        PoseGyro.Parent = RootPart
    end

    return PoseGyro
end

local function startFarmPhysics()
    if not RootPart or not RootPart.Parent then return false end
    FarmActive = true
    applyNoclip()
    lockPose()
    ensureVelocityMover()
    ensurePoseGyro()
    return true
end

local function stopMovement()
    MovementActive = false

    if CurrentSpeedTween then
        pcall(function() CurrentSpeedTween:Cancel() end)
        CurrentSpeedTween = nil
    end

    SpeedScale.Value = 0
    SmoothedVelocity = Vector3.zero

    if VelocityMover and VelocityMover.Parent then
        VelocityMover.Velocity = Vector3.zero
    end
end

local function destroyMovers()
    if VelocityMover then
        pcall(function() VelocityMover:Destroy() end)
        VelocityMover = nil
    end
    if PoseGyro then
        pcall(function() PoseGyro:Destroy() end)
        PoseGyro = nil
    end
end

local function stopFarmPhysics()
    stopMovement()
    destroyMovers()
    FarmActive = false
    restorePose()
    restoreCollision()
end

RunService.Stepped:Connect(function()
    if not FarmActive then return end

    applyNoclip()
    lockPose()
    ensureVelocityMover()
    ensurePoseGyro()

    if RootPart and RootPart.Parent then
        pcall(function()
            if not MovementActive then
                RootPart.AssemblyLinearVelocity = Vector3.zero
            end
            RootPart.AssemblyAngularVelocity = Vector3.zero
        end)
    end
end)

local function setupCharacter(character)
    stopFarmPhysics()

    if CharacterDescendantConnection then
        CharacterDescendantConnection:Disconnect()
        CharacterDescendantConnection = nil
    end

    Character = character
    Humanoid = character:WaitForChild("Humanoid", 10)
    RootPart = character:WaitForChild("HumanoidRootPart", 10)
    if RootPart then
        LastSafeCFrame = RootPart.CFrame
    end
    CharacterReadyAt = os.clock() + Config.CharacterSpawnDelay
    table.clear(CharacterParts)

    for _, object in ipairs(character:GetDescendants()) do
        cacheCharacterPart(object)
    end
    CharacterDescendantConnection = character.DescendantAdded:Connect(cacheCharacterPart)

    if Humanoid then
        Humanoid.Died:Connect(function()
            RoundState.PlayerAlive = false
            RoundState.Phase = RoundState.Active and "SPECTATING" or RoundState.Phase
            CurrentAction = "Character died"
            stopFarmPhysics()
        end)
    end
end

if LocalPlayer.Character then
    task.spawn(setupCharacter, LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(setupCharacter)

local function characterReady()
    return Character and Character.Parent
        and Humanoid and Humanoid.Parent and Humanoid.Health > 0
        and RootPart and RootPart.Parent
        and os.clock() >= CharacterReadyAt
end

local GameFrame
local function getRoundUIState()
    if not GameFrame or not GameFrame.Parent then
        local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if playerGui then
            for _, object in ipairs(playerGui:GetDescendants()) do
                if object.Name == "Game"
                    and object:FindFirstChild("Waiting")
                    and object:FindFirstChild("RoleSelector") then
                    GameFrame = object
                    break
                end
            end
        end
    end

    if not GameFrame then return false, false end

    local waiting = GameFrame:FindFirstChild("Waiting")
    local roleSelector = GameFrame:FindFirstChild("RoleSelector")
    return waiting and waiting:IsA("GuiObject") and waiting.Visible or false,
        roleSelector and roleSelector:IsA("GuiObject") and roleSelector.Visible or false
end

local CurrentRoundClient
pcall(function()
    CurrentRoundClient = require(
        ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CurrentRoundClient")
    )
end)

local function updatePlayerRoundData()
    if not CurrentRoundClient then return nil end

    local data
    if type(CurrentRoundClient.GetLatestPlayerData) == "function" then
        pcall(function()
            data = CurrentRoundClient.GetLatestPlayerData()
        end)
    end
    if type(data) ~= "table" and type(CurrentRoundClient.PlayerData) == "table" then
        data = CurrentRoundClient.PlayerData
    end

    local localData = type(data) == "table" and data[LocalPlayer.Name] or nil
    if type(localData) == "table" then
        if localData.Role ~= nil then RoundState.Role = tostring(localData.Role) end
        RoundState.PlayerAlive = localData.Dead ~= true
        return localData
    end
    return nil
end

local function canFarmNow()
    if not RoundState.Active or not RoundState.PlayerAlive then return false end
    if os.clock() < RoundState.FarmUnlockAt then return false end
    if not characterReady() then return false end

    local waiting, roleSelector = getRoundUIState()
    if waiting or roleSelector then return false end

    local localData = updatePlayerRoundData()
    if localData and localData.Dead == true then
        RoundState.PlayerAlive = false
        return false
    end
    return true
end

local function setRoundInactive(phase, role)
    RoundState.Active = false
    RoundState.PlayerAlive = false
    RoundState.Phase = phase or "WAITING"
    RoundState.Role = role or RoundState.Role
    RoundState.FarmUnlockAt = math.huge
    CurrentAction = "Waiting for round"
    stopFarmPhysics()
end

local function connectOptionalRemote(name, callback)
    local remote = GameplayRemotes:FindFirstChild(name)
    if remote and remote:IsA("RemoteEvent") then
        remote.OnClientEvent:Connect(callback)
    end
end

connectOptionalRemote("LoadingMap", function()
    setRoundInactive("LOADING MAP", "Unknown")
end)
connectOptionalRemote("ShowRoleSelect", function()
    setRoundInactive("ROLE SELECT", RoundState.Role)
end)
connectOptionalRemote("ShowRoleSelectNew", function()
    setRoundInactive("ROLE SELECT", RoundState.Role)
end)
connectOptionalRemote("RoleSelect", function(role)
    RoundState.Active = false
    RoundState.PlayerAlive = true
    RoundState.Phase = "STARTING"
    RoundState.Role = tostring(role or "Unknown")
    RoundState.FarmUnlockAt = math.huge
    CurrentAction = "Waiting for round start"
    stopFarmPhysics()
end)

RoundStartRemote.OnClientEvent:Connect(function(_, playerData)
    RoundState.ReceivedRoundStart = true
    local localData = type(playerData) == "table" and playerData[LocalPlayer.Name] or nil

    if type(localData) ~= "table" then
        setRoundInactive("SPECTATING", "Spectator")
        return
    end

    RoundState.Role = tostring(localData.Role or "Unknown")
    RoundState.PlayerAlive = localData.Dead ~= true
    RoundState.Active = RoundState.PlayerAlive
    RoundState.Phase = RoundState.PlayerAlive and "FARMING" or "SPECTATING"
    RoundState.FarmUnlockAt = os.clock() + Config.RoundStartDelay
    CurrentAction = RoundState.PlayerAlive and "Preparing" or "Spectating"
end)

VictoryScreenRemote.OnClientEvent:Connect(function()
    setRoundInactive("ROUND END", RoundState.Role)
end)

local EventInfoService
local MainEvent
local ProfileData
local DailyProgress = 0
local DailyTarget = Config.DailyTargetFallback
local DailyQuestName = "DailyCoins"
local EventCurrencyName = "SummerKey2026"

pcall(function()
    EventInfoService = require(
        ReplicatedStorage:WaitForChild("SharedServices"):WaitForChild("EventInfoService")
    )
    EventInfoService:WaitForInitializedAsync()
    MainEvent = EventInfoService:GetMainEvent()
    ProfileData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ProfileData"))

    if MainEvent and MainEvent.EventStartInfo then
        EventCurrencyName = MainEvent.EventStartInfo.CurrencyName or EventCurrencyName
        local questInfo = MainEvent.EventStartInfo.Quests
            and MainEvent.EventStartInfo.Quests[DailyQuestName]
        if questInfo and questInfo.Quests and #questInfo.Quests > 0 then
            DailyTarget = questInfo.Quests[#questInfo.Quests].ChallengeAmount or DailyTarget
        end
    end
end)

local function getDailyProgress()
    if MainEvent and ProfileData then
        local eventData = ProfileData[MainEvent.Title]
        local daily = eventData and eventData.Quests and eventData.Quests[DailyQuestName]
        if daily and type(daily.Progress) == "number" then
            DailyProgress = daily.Progress
        end
    end
    return DailyProgress
end

local function getShellAmount()
    local owned = ProfileData and ProfileData.Materials and ProfileData.Materials.Owned
    if type(owned) ~= "table" then return 0 end
    return tonumber(owned[EventCurrencyName]) or tonumber(owned.SummerKey2026) or 0
end

pcall(function()
    local eventsFolder = Remotes:FindFirstChild("Events")
    local eventRemotes = eventsFolder and MainEvent
        and eventsFolder:FindFirstChild(MainEvent.Title .. "Remotes")
    eventRemotes = eventRemotes or (eventsFolder and eventsFolder:FindFirstChild("Summer2026Remotes"))
    local progressed = eventRemotes and eventRemotes:FindFirstChild("EventQuestProgressed")
    if progressed then
        progressed.OnClientEvent:Connect(function(questName, progress)
            if questName == DailyQuestName then
                DailyProgress = tonumber(progress) or DailyProgress
            end
        end)
    end
end)

local BagFull = {}
local CoinEventCount = {}
local BagAmounts = {}

CoinsStartedRemote.OnClientEvent:Connect(function(activeBags)
    table.clear(BagFull)
    table.clear(CoinEventCount)
    table.clear(BagAmounts)
    if type(activeBags) == "table" then
        for coinType in pairs(activeBags) do
            BagFull[tostring(coinType)] = false
        end
    end
end)

CoinCollectedRemote.OnClientEvent:Connect(function(coinType, currentAmount, maximumAmount)
    coinType = tostring(coinType)
    CoinEventCount[coinType] = (CoinEventCount[coinType] or 0) + 1
    SessionCollected = SessionCollected + 1
    BagAmounts[coinType] = {
        Current = tonumber(currentAmount) or 0,
        Maximum = tonumber(maximumAmount) or 0,
    }
    BagFull[coinType] = BagAmounts[coinType].Current >= BagAmounts[coinType].Maximum
end)

local FailedUntil = setmetatable({}, { __mode = "k" })
local PendingUntil = setmetatable({}, { __mode = "k" })
local FallbackCoins = {}
local LastFallbackScan = 0
local CachedMapName = "Waiting..."

local function normalizeCoin(instance)
    if not instance or not instance.Parent then return nil end

    if instance:IsA("BasePart") and instance.Name == "Coin_Server" then
        return instance
    end

    -- mm5 dùng CollectionService tag "CoinVisual". CoinVisual là part con
    -- được weld vào Coin_Server; part server mới là mục tiêu touch ổn định.
    if instance.Name == "CoinVisual" then
        local parent = instance.Parent
        if parent and parent:IsA("BasePart") and parent.Name == "Coin_Server" then
            return parent
        end
    end

    return nil
end

local function getCoinVisual(coin)
    if not coin or not coin.Parent then return nil end
    local visual = coin:FindFirstChild("CoinVisual")
    return visual and visual:IsA("BasePart") and visual or nil
end

local function getCoinType(coin)
    if not coin then return "Coin" end
    local visual = getCoinVisual(coin)
    return tostring(
        coin:GetAttribute("CoinID")
        or (visual and visual:GetAttribute("CoinID"))
        or "Coin"
    )
end

local function coinWasCollected(coin)
    if not coin or not coin.Parent then return true end
    local visual = getCoinVisual(coin)
    return coin:GetAttribute("Collected") == true
        or coin:GetAttribute("Delete") == true
        or (visual and (
            visual:GetAttribute("Collected") == true
            or visual:GetAttribute("Delete") == true
        ))
end

local function coinExists(coin)
    return coin and coin.Parent and coin:IsA("BasePart")
        and coin.Name == "Coin_Server"
        and coin:IsDescendantOf(workspace)
        and not coinWasCollected(coin)
        and vectorIsValid(coin.Position)
end

local function isUsableCoin(coin)
    if not coinExists(coin) then return false end

    local coinType = getCoinType(coin)
    if BagFull[coinType] then return false end

    local now = os.clock()
    local failedUntil = FailedUntil[coin]
    if failedUntil and failedUntil > now then return false end

    local pendingUntil = PendingUntil[coin]
    if pendingUntil and pendingUntil > now then return false end

    return true
end

local function getAllCoins()
    local result = {}
    local seen = {}

    local function add(instance)
        local coin = normalizeCoin(instance)
        if coin and not seen[coin] and coinExists(coin) then
            seen[coin] = true
            result[#result + 1] = coin
        end
    end

    -- Source mm5 quét CoinVisual; giữ thêm tag Coin để tương thích server khác.
    for _, tagged in ipairs(CollectionService:GetTagged("CoinVisual")) do
        add(tagged)
    end
    for _, tagged in ipairs(CollectionService:GetTagged("Coin")) do
        add(tagged)
    end

    for _, coin in ipairs(FallbackCoins) do
        add(coin)
    end

    if #result == 0 and os.clock() - LastFallbackScan >= 1.25 then
        LastFallbackScan = os.clock()
        table.clear(FallbackCoins)

        for _, object in ipairs(workspace:GetDescendants()) do
            if object.Name == "Coin_Server" then
                local coin = normalizeCoin(object)
                if coin then
                    FallbackCoins[#FallbackCoins + 1] = coin
                    add(coin)
                end
            end
        end
    end

    return result
end

local function getNearestCoin(originPosition, excludedCoin)
    if not characterReady() then return nil end

    originPosition = originPosition or RootPart.Position
    local nearest
    local nearestDistance = math.huge

    for _, coin in ipairs(getAllCoins()) do
        if coin ~= excludedCoin and isUsableCoin(coin) then
            local distance = (originPosition - coin.Position).Magnitude
            if distance < nearestDistance and distance <= Config.MaxTargetDistance then
                nearest = coin
                nearestDistance = distance
            end
        end
    end

    return nearest, nearestDistance
end

local function getVelocitySpeed()
    local minimum = math.min(Config.VelocityMinSpeed, Config.VelocityMaxSpeed)
    local maximum = math.max(Config.VelocityMinSpeed, Config.VelocityMaxSpeed)
    return math.clamp(Config.VelocitySpeed, minimum, maximum)
end

local function tweenSpeedScale(target, duration)
    if CurrentSpeedTween then
        pcall(function() CurrentSpeedTween:Cancel() end)
        CurrentSpeedTween = nil
    end

    CurrentSpeedTween = TweenService:Create(
        SpeedScale,
        TweenInfo.new(
            math.max(tonumber(duration) or 0.05, 0.03),
            Enum.EasingStyle.Sine,
            Enum.EasingDirection.Out
        ),
        { Value = math.clamp(target, 0, 1) }
    )
    CurrentSpeedTween:Play()
end

local function zeroCharacterVelocity()
    if CurrentSpeedTween then
        pcall(function() CurrentSpeedTween:Cancel() end)
        CurrentSpeedTween = nil
    end

    SpeedScale.Value = 0
    SmoothedVelocity = Vector3.zero

    if VelocityMover and VelocityMover.Parent then
        VelocityMover.Velocity = Vector3.zero
    end

    if RootPart and RootPart.Parent then
        pcall(function()
            RootPart.AssemblyLinearVelocity = Vector3.zero
            RootPart.AssemblyAngularVelocity = Vector3.zero
        end)
    end
end

local function holdStillAt(position, duration, saveAsSafe)
    if not RootPart or not RootPart.Parent then return end

    MovementActive = false
    zeroCharacterVelocity()

    if position and vectorIsValid(position) then
        local distance = (RootPart.Position - position).Magnitude
        if distance <= math.max(Config.CoinSnapDistance, 0.5) then
            pcall(function()
                local rotation = RootPart.CFrame - RootPart.Position
                RootPart.CFrame = CFrame.new(position) * rotation
            end)
        end
    end

    local started = os.clock()
    local holdTime = math.max(tonumber(duration) or 0, 0)
    while isRunning() and canFarmNow() and os.clock() - started < holdTime do
        zeroCharacterVelocity()
        RunService.Heartbeat:Wait()
    end

    zeroCharacterVelocity()
    if saveAsSafe and RootPart and RootPart.Parent then
        LastSafeCFrame = RootPart.CFrame
    end
end

local function restoreLastSafePosition()
    zeroCharacterVelocity()
    MovementActive = false

    if RootPart and RootPart.Parent and LastSafeCFrame then
        pcall(function()
            RootPart.CFrame = LastSafeCFrame
            RootPart.AssemblyLinearVelocity = Vector3.zero
            RootPart.AssemblyAngularVelocity = Vector3.zero
        end)
    end
end

local function brakeVelocity()
    if not RootPart or not RootPart.Parent then return end

    tweenSpeedScale(0, 0.07)
    local started = os.clock()
    while isRunning() and os.clock() - started < 0.10 do
        local dt = RunService.Heartbeat:Wait()
        dt = math.clamp(tonumber(dt) or 0.03, 1 / 240, 0.25)
        local alpha = 1 - math.exp(-Config.VelocityLerpResponse * dt)
        SmoothedVelocity = SmoothedVelocity:Lerp(Vector3.zero, alpha)
        if VelocityMover and VelocityMover.Parent then
            VelocityMover.Velocity = SmoothedVelocity
        end
    end

    zeroCharacterVelocity()
end

local function setTemporaryFPS(value)
    if setfpscap then
        pcall(setfpscap, math.max(tonumber(value) or Config.FPSCap, 1))
    end
end

local function getPickupTouchParts()
    local result = {}
    local seen = {}
    local maximum = math.max(tonumber(Config.PickupMaxTouchParts) or 10, 1)

    local function add(part)
        if #result >= maximum then return end
        if part and part.Parent and part:IsA("BasePart") and not seen[part] then
            seen[part] = true
            result[#result + 1] = part
        end
    end

    add(RootPart)
    if Character then
        local preferredNames = {
            "LowerTorso", "UpperTorso", "Torso", "Head",
            "LeftFoot", "RightFoot", "LeftLowerLeg", "RightLowerLeg",
            "Left Leg", "Right Leg"
        }
        for _, name in ipairs(preferredNames) do
            add(Character:FindFirstChild(name))
        end
    end

    for _, part in ipairs(CharacterParts) do
        add(part)
        if #result >= maximum then break end
    end

    return result
end

local function coinPickupConfirmed(coin, coinType, beforeEvents)
    return not coinExists(coin)
        or coinWasCollected(coin)
        or (CoinEventCount[coinType] or 0) > beforeEvents
end

local function placeRootAtPickupPoint(targetPosition, offset)
    if not RootPart or not RootPart.Parent or not vectorIsValid(targetPosition) then return end

    offset = offset or Vector3.zero
    zeroCharacterVelocity()
    pcall(function()
        local rotation = RootPart.CFrame - RootPart.Position
        RootPart.CFrame = CFrame.new(targetPosition + offset) * rotation
        RootPart.AssemblyLinearVelocity = Vector3.zero
        RootPart.AssemblyAngularVelocity = Vector3.zero
    end)
end

local function pulseCoinTouch(parts, coin, visual)
    for _, part in ipairs(parts) do
        if part and part.Parent then
            pcall(firetouchinterest, part, coin, 0)
            if visual and visual.Parent then
                pcall(firetouchinterest, part, visual, 0)
            end
        end
    end

    task.wait(math.max(tonumber(Config.PickupContactHold) or 0.028, 0.01))

    for _, part in ipairs(parts) do
        if part and part.Parent then
            pcall(firetouchinterest, part, coin, 1)
            if visual and visual.Parent then
                pcall(firetouchinterest, part, visual, 1)
            end
        end
    end
end

local function touchCoinStationary(coin, targetPosition)
    if not firetouchinterest or not RootPart or not coinExists(coin) then
        return not coinExists(coin)
    end

    local now = os.clock()
    if PendingUntil[coin] and PendingUntil[coin] > now then
        return true
    end

    local coinType = getCoinType(coin)
    local beforeEvents = CoinEventCount[coinType] or 0
    local touchParts = getPickupTouchParts()
    local visual = getCoinVisual(coin)
    local timeout = math.max(tonumber(Config.PickupConfirmTimeout) or 0.46, 0.12)
    local sweep = math.max(tonumber(Config.PickupMicroSweepDistance) or 0.18, 0)
    local offsets = {
        Vector3.zero,
        Vector3.new(sweep, 0, 0),
        Vector3.new(-sweep, 0, 0),
        Vector3.new(0, 0, sweep),
        Vector3.new(0, 0, -sweep),
    }

    setTemporaryFPS(Config.PickupFPSCap)
    placeRootAtPickupPoint(targetPosition, Vector3.zero)

    local started = os.clock()
    local pulseIndex = 1
    local confirmed = coinPickupConfirmed(coin, coinType, beforeEvents)

    while isRunning() and canFarmNow() and not confirmed and os.clock() - started < timeout do
        local offset = offsets[pulseIndex]
        pulseIndex = pulseIndex % #offsets + 1

        -- Dịch cực nhỏ quanh tâm hitbox để tạo chu kỳ ngoài -> trong ngay cả
        -- khi client đang chạy FPS thấp. Nhìn ngoài vẫn là đứng yên tại coin.
        placeRootAtPickupPoint(targetPosition, offset)
        pulseCoinTouch(touchParts, coin, visual)
        placeRootAtPickupPoint(targetPosition, Vector3.zero)

        confirmed = coinPickupConfirmed(coin, coinType, beforeEvents)
        if not confirmed then
            task.wait(math.max(tonumber(Config.PickupPulseInterval) or 0.035, 0.01))
        end
    end

    placeRootAtPickupPoint(targetPosition, Vector3.zero)
    zeroCharacterVelocity()

    if confirmed then
        PendingUntil[coin] = os.clock() + Config.PendingCoinTime
        LastSafeCFrame = RootPart.CFrame
        task.wait(math.max(tonumber(Config.PickupPostConfirmDelay) or 0.025, 0))
    end

    setTemporaryFPS(Config.FPSCap)
    return confirmed
end

local function moveTweenLerpVelocity(targetPosition, watchedCoin)
    if not characterReady() or not canFarmNow() or not vectorIsValid(targetPosition) then
        return false
    end
    if not startFarmPhysics() then return false end

    local mover = ensureVelocityMover()
    local gyro = ensurePoseGyro()
    if not mover then return false end

    -- Mỗi coin là một chặng riêng. Luôn bắt đầu chặng mới từ vận tốc 0 để
    -- không mang quán tính của coin trước sang và bay xuyên khỏi map.
    MovementActive = true
    zeroCharacterVelocity()
    MovementActive = true
    tweenSpeedScale(1, Config.VelocityAccelerationTime)

    local initialDistance = (targetPosition - RootPart.Position).Magnitude
    local timeout = math.clamp(
        initialDistance / math.max(getVelocitySpeed() * 0.55, 1) + Config.VelocityTimeoutPadding,
        2.5,
        Config.VelocityMaxTimeout
    )
    local started = os.clock()
    local arrived = false
    local targetGone = false
    local previousDelta = targetPosition - RootPart.Position

    while isRunning() and MovementActive do
        if not canFarmNow() or not characterReady() then break end

        -- Coin biến mất giữa đường có thể do người khác nhặt. Dừng ngay,
        -- tuyệt đối không giữ hướng bay cũ.
        if watchedCoin and not coinExists(watchedCoin) then
            targetGone = true
            break
        end

        if os.clock() - started > timeout then
            log("Velocity timeout", math.floor(initialDistance))
            break
        end

        local delta = targetPosition - RootPart.Position
        local distance = delta.Magnitude

        if distance <= Config.VelocityArrivalDistance then
            arrived = true
            break
        end

        -- Chặn trường hợp BodyVelocity bị văng sai hướng hoặc tụt khỏi map.
        local tooFar = distance > initialDistance + math.max(Config.SafetyMaxTargetError, 5)
        local tooLow = RootPart.Position.Y < targetPosition.Y - math.max(Config.SafetyMaxVerticalDrop, 8)
        if tooFar or tooLow then
            CurrentAction = "Safety return"
            restoreLastSafePosition()
            return false
        end

        local dt = RunService.Heartbeat:Wait()
        dt = math.clamp(tonumber(dt) or 0.03, 1 / 240, 0.25)

        delta = targetPosition - RootPart.Position
        distance = delta.Magnitude

        -- Ở FPS rất thấp có thể đi từ trước coin sang sau coin chỉ trong một
        -- Heartbeat mà không lọt đúng ArrivalDistance. Dot <= 0 nghĩa là đã
        -- cắt qua mặt phẳng mục tiêu: snap về coin và dừng thay vì tiếp tục lao.
        if previousDelta.Magnitude > 0.001 and previousDelta:Dot(delta) <= 0 then
            arrived = true
            break
        end

        if distance <= Config.VelocityArrivalDistance then
            arrived = true
            break
        end

        if distance <= 0.001 then
            arrived = true
            break
        end

        local brakeMultiplier = 1
        if distance < Config.VelocityBrakeDistance then
            brakeMultiplier = math.clamp(
                distance / math.max(Config.VelocityBrakeDistance, 0.1),
                Config.VelocityMinBrakeMultiplier,
                1
            )
        end

        local desiredVelocity = delta.Unit
            * getVelocitySpeed()
            * brakeMultiplier
            * SpeedScale.Value

        local alpha = 1 - math.exp(-Config.VelocityLerpResponse * dt)
        SmoothedVelocity = SmoothedVelocity:Lerp(desiredVelocity, alpha)
        mover.Velocity = SmoothedVelocity

        if gyro and gyro.Parent then
            local flat = Vector3.new(delta.X, 0, delta.Z)
            if flat.Magnitude > 0.05 then
                gyro.CFrame = CFrame.lookAt(Vector3.zero, flat.Unit)
            end
        end

        pcall(function()
            RootPart.AssemblyAngularVelocity = Vector3.zero
        end)

        previousDelta = delta
    end

    -- Dù tới coin, coin biến mất hay timeout, chặng này luôn kết thúc ở vận tốc 0.
    if arrived then
        holdStillAt(targetPosition, Config.CoinStopTime, false)
    else
        holdStillAt(nil, 0.04, false)
    end

    MovementActive = false
    return arrived or targetGone
end

local function TweenToCoin(coin)
    if not canFarmNow() or not isUsableCoin(coin) then return false end
    if not startFarmPhysics() then return false end

    local targetPosition = coin.Position + Vector3.new(0, Config.VelocityTargetYOffset, 0)

    CurrentAction = "Flying to nearest coin"
    local reached = moveTweenLerpVelocity(targetPosition, coin)
    if not reached or not canFarmNow() then
        zeroCharacterVelocity()
        return false
    end

    if coinExists(coin) then
        CurrentAction = "Confirming coin pickup"
        return touchCoinStationary(coin, targetPosition)
    else
        -- Coin đã biến mất thì vẫn phải dừng hoàn toàn trước khi chọn coin mới.
        holdStillAt(nil, 0.03, false)
        return true
    end
end

local function collectCoin(coin)
    if not canFarmNow() or not isUsableCoin(coin) then return false end

    for _ = 1, Config.RetryPerCoin do
        if not canFarmNow() then return false end

        if TweenToCoin(coin) then
            return true
        end

        if not coinExists(coin) or coinWasCollected(coin) then
            return true
        end

        -- Lần đầu server chưa xác nhận thì giữ nguyên tại coin và thử lại ngay,
        -- không bay sang mục tiêu khác rồi quay lại sau.
        CurrentAction = "Retrying coin touch"
        holdStillAt(coin.Position + Vector3.new(0, Config.VelocityTargetYOffset, 0), 0.025, false)
    end

    if coin and coin.Parent then
        FailedUntil[coin] = os.clock() + Config.FailedCoinCooldown
    end
    return false
end

local StatusGui
local StatusText
local function createStatusGUI()
    if not Config.ShowStatusGUI then return end

    local parent = CoreGui
    if gethui then pcall(function() parent = gethui() end) end
    local old = parent:FindFirstChild("MM2Summer2026Status")
    if old then old:Destroy() end

    StatusGui = Instance.new("ScreenGui")
    StatusGui.Name = "MM2Summer2026Status"
    StatusGui.ResetOnSpawn = false
    StatusGui.Parent = parent

    local frame = Instance.new("Frame")
    frame.Position = UDim2.fromOffset(8, 28)
    frame.Size = UDim2.fromOffset(320, 116)
    frame.BackgroundColor3 = Color3.fromRGB(10, 12, 16)
    frame.BackgroundTransparency = 0.18
    frame.BorderSizePixel = 0
    frame.Parent = StatusGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 7)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1.4
    stroke.Color = Color3.fromRGB(0, 190, 255)
    stroke.Parent = frame

    StatusText = Instance.new("TextLabel")
    StatusText.BackgroundTransparency = 1
    StatusText.Position = UDim2.fromOffset(10, 7)
    StatusText.Size = UDim2.new(1, -20, 1, -14)
    StatusText.Font = Enum.Font.GothamSemibold
    StatusText.TextSize = 14
    StatusText.TextColor3 = Color3.fromRGB(240, 240, 240)
    StatusText.TextXAlignment = Enum.TextXAlignment.Left
    StatusText.TextYAlignment = Enum.TextYAlignment.Top
    StatusText.RichText = true
    StatusText.Parent = frame
end

local function getMapAndCoinCount()
    local coins = getAllCoins()
    if coins[1] then
        local node = coins[1].Parent
        while node and node ~= workspace and node.Name ~= "CoinContainer" do
            node = node.Parent
        end
        if node and node.Parent and node.Parent ~= workspace then
            CachedMapName = node.Parent.Name
        end
    elseif not RoundState.Active then
        CachedMapName = "Waiting..."
    end
    return CachedMapName, #coins
end

createStatusGUI()
task.spawn(function()
    while isRunning() do
        if StatusText and StatusText.Parent then
            local mapName, coinCount = getMapAndCoinCount()
            local progress = getDailyProgress()
            StatusText.Text = string.format(
                '<font color="#4BD4FF">MM2 Auto Daily v14 · Confirmed MultiTouch · FPS 5/30</font>\nMap: %s | Phase: %s\nRole: %s | %s\nShells: %s | Coins: %s | Daily: %s/%s | Picked: %s',
                tostring(mapName), tostring(RoundState.Phase), tostring(RoundState.Role),
                tostring(CurrentAction), tostring(getShellAmount()), tostring(coinCount),
                tostring(progress), tostring(DailyTarget), tostring(SessionCollected)
            )
        end
        task.wait(0.50)
    end
end)

while isRunning() do
    while isRunning() and not characterReady() do
        CurrentAction = "Waiting for character"
        task.wait(0.25)
    end
    if not isRunning() then break end

    local progress = getDailyProgress()
    if Config.StopWhenDailyCompleted and progress >= DailyTarget then
        CurrentAction = "Daily completed"
        break
    end

    if not canFarmNow() then
        local waiting, roleSelector = getRoundUIState()
        if waiting and not RoundState.Active then
            RoundState.Phase = "WAITING"
            CurrentAction = "Waiting for your turn"
        elseif roleSelector then
            CurrentAction = "Waiting for round start"
        elseif not RoundState.PlayerAlive then
            CurrentAction = "Spectating"
        end
        stopFarmPhysics()
        task.wait(0.25)
        continue
    end

    local coin = getNearestCoin(RootPart.Position)
    if coin then
        -- Tới coin, dừng hẳn rất ngắn, chạm coin rồi vòng lặp lập tức
        -- tính coin gần nhất mới từ đúng vị trí coin vừa nhặt.
        collectCoin(coin)
    else
        -- Không có coin phải giữ nhân vật đứng yên; không để BodyVelocity
        -- tiếp tục mang hướng cũ ra ngoài map.
        if MovementActive or SmoothedVelocity.Magnitude > 0.05 then
            brakeVelocity()
        else
            zeroCharacterVelocity()
        end
        MovementActive = false

        local anyBagFull = false
        for _, full in pairs(BagFull) do
            if full then
                anyBagFull = true
                break
            end
        end
        CurrentAction = anyBagFull and "Bag full / waiting" or "Waiting for coins"
        task.wait(anyBagFull and Config.FullBagDelay or Config.NoCoinDelay)
    end
end

stopFarmPhysics()
if CharacterDescendantConnection then CharacterDescendantConnection:Disconnect() end
if StatusGui then StatusGui:Destroy() end
if getgenv().MM2_SUMMER_2026_TOKEN == RunToken then
    getgenv().MM2_SUMMER_2026_RUNNING = false
end
log("Stopped")
