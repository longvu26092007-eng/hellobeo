-- ============================================================
-- MM2 SUMMER 2026 KAITUN - NEAREST COIN + SMART PATHFINDING v2
--   * Chọn Coin gần nhất thay vì FIFO
--   * Chỉ xét Coin trong bán kính cấu hình
--   * Kiểm tra đường đi trước khi chọn Coin
--   * Thử nhiều điểm tiếp cận quanh Coin
--   * Tự tính lại đường khi bị chắn hoặc đứng kẹt
--   * Blacklist tạm Coin không thể tới
--   * Tăng WalkSpeed có giới hạn
--   * Không teleport HumanoidRootPart bằng CFrame
-- Có thể cấu hình ngoài bằng getgenv().MM2_KAITUN_CONFIG
-- ============================================================

repeat task.wait() until game:IsLoaded()
repeat task.wait() until game:GetService("Players").LocalPlayer

local DEFAULT_CONFIG = {
    FarmCoins = true,
    AllowedCoinTypes = {
        Coin = true,
    },

    AutoOpenBox = true,
    BoxId = "Summer2026Box",
    ShellId = "SummerKey2026",
    BoxCostFallback = 120,
    BoxCompleteDelay = 1.2,
    BoxOpenDelay = 1.4,

    TargetItems = {
        "Icecream",
        "Ice Cream",
        "Chroma Icecream",
        "Chroma Ice Cream",
    },
    NotifyAllUnboxes = false,
    NotifyRarities = {
        Godly = true,
        Ancient = true,
        Unique = true,
    },
    StopWhenTargetFound = true,

    Webhook = "",
    WebhookMention = "",
    MaskUsername = true,

    AutoHop = true,
    HopAfterBagFull = true,
    HopDelayAfterFull = 3,
    HopIfNoCoinActivityFor = 55,
    HopCooldown = 12,
    MinServerPlayers = 2,
    MaxServerPlayers = 8,
    MaxServerPages = 3,
    RememberServersFor = 7200,

    FPSCap = 10,
    Disable3DRendering = false,
    LowGraphics = true,
    CollectDelay = 0.14,
    TouchAttempts = 3,
    CoinRetryDelay = 0.35,
    MaxCoinRetries = 4,
    TouchHoldTime = 1.1,
    TouchPulseDelay = 0.10,
    TouchVerticalOffsets = {0, -0.8, 0.8, 0},
    FallbackScanDelay = 2,

    -- SMART COIN SELECTION + PATHFINDING
    UseSafeMovement = true,
    CoinWalkSpeed = 22,             -- Khuyến nghị 20-24.
    CoinScanRadius = 220,           -- Chỉ ưu tiên Coin trong bán kính này.
    AllowFarCoinFallback = false,   -- false = không chạy tới Coin quá xa.
    NearestCoinCandidates = 6,      -- Số Coin gần nhất được kiểm tra đường.
    CoinBlacklistTime = 12,         -- Tạm bỏ Coin không có đường đi.
    ApproachRadius = 6,             -- Thử đứng quanh Coin trong bán kính này.
    ArrivalDistance = 5.5,
    TouchDistance = 9,
    WaypointArrivalDistance = 3.5,
    WaypointTimeout = 4.5,
    DirectMoveTimeout = 6,
    PathRecomputeAttempts = 3,
    PathWaypointSpacing = 3,
    StuckCheckInterval = 0.15,
    StuckTimeout = 1.6,
    StuckMinProgress = 1.1,
    MaxCoinDistance = 0,            -- 0 = dùng CoinScanRadius làm giới hạn.

    AntiAFK = true,
    ShowStatus = true,
}

local Config = getgenv().MM2_KAITUN_CONFIG or {}
for key, value in pairs(DEFAULT_CONFIG) do
    if Config[key] == nil then
        Config[key] = value
    end
end
getgenv().MM2_KAITUN_CONFIG = Config

local Previous = getgenv().__MM2_SUMMER_2026_KAITUN
if type(Previous) == "table" then
    Previous.Stopped = true
    if Previous.Gui then
        pcall(function()
            Previous.Gui:Destroy()
        end)
    end
    if type(Previous.Connections) == "table" then
        for _, connection in ipairs(Previous.Connections) do
            pcall(function()
                connection:Disconnect()
            end)
        end
    end
    task.wait(0.2)
end

local State = {
    Stopped = false,
    TargetFound = false,
    Hopping = false,
    HopPending = false,
    Opening = false,
    RoundActive = false,
    BagCurrent = 0,
    BagLimit = 40,
    BagFull = false,
    Shells = 0,
    BoxesOpened = 0,
    CoinsCollected = 0,
    CollectionSerial = 0,
    LastItem = "N/A",
    LastRarity = "N/A",
    Status = "Initializing",
    LastCoinActivity = os.clock(),
    LastHopAttempt = 0,
    Connections = {},
}
getgenv().__MM2_SUMMER_2026_KAITUN = State

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GameplayRemotes = Remotes:WaitForChild("Gameplay")
local ShopRemotes = Remotes:WaitForChild("Shop")
local CoinCollectedRemote = GameplayRemotes:WaitForChild("CoinCollected")
local CoinsStartedRemote = GameplayRemotes:WaitForChild("CoinsStarted")
local OpenCrateRemote = ShopRemotes:WaitForChild("OpenCrate")
local CrateCompleteRemote = ShopRemotes:WaitForChild("CrateComplete")

local function addConnection(connection)
    table.insert(State.Connections, connection)
    return connection
end

local function setStatus(text)
    State.Status = tostring(text)
    warn("[MM2 KAITUN] " .. State.Status)
end

local function mergeRequestFunction()
    if syn and syn.request then
        return syn.request
    end
    if http_request then
        return http_request
    end
    if request then
        return request
    end
    if http and http.request then
        return http.request
    end
    if fluxus and fluxus.request then
        return fluxus.request
    end
    return nil
end

local RequestFunction = mergeRequestFunction()

local function normalizeName(value)
    return string.lower(tostring(value or "")):gsub("[%s%p_]", "")
end

local TargetLookup = {}
for _, itemName in ipairs(Config.TargetItems or {}) do
    TargetLookup[normalizeName(itemName)] = true
end

local function isTargetItem(rewardId, displayName)
    return TargetLookup[normalizeName(rewardId)] == true
        or TargetLookup[normalizeName(displayName)] == true
end

local function maskUsername(username)
    username = tostring(username or "Unknown")
    if not Config.MaskUsername then
        return username
    end
    if #username <= 4 then
        return username:sub(1, 1) .. "***"
    end
    return username:sub(1, 4) .. "***"
end

local function imageToHttpUrl(image)
    local text = tostring(image or "")
    local assetId = text:match("rbxassetid://(%d+)")
        or text:match("[?&]id=(%d+)")
        or text:match("assetId=(%d+)")
        or text:match("id=(%d+)")

    if not assetId then
        return nil
    end

    return "https://www.roblox.com/asset-thumbnail/image?assetId="
        .. assetId
        .. "&width=420&height=420&format=png"
end

local function sendWebhook(rewardId, displayName, rarity, image, isTarget)
    if type(Config.Webhook) ~= "string" or Config.Webhook == "" then
        return false
    end
    if not RequestFunction then
        setStatus("Webhook unsupported by executor")
        return false
    end

    local fields = {
        {
            name = "Username",
            value = "`" .. maskUsername(LocalPlayer.Name) .. "`",
            inline = false,
        },
        {
            name = "Item",
            value = "`" .. tostring(displayName) .. "`",
            inline = false,
        },
        {
            name = "Rarity",
            value = "`" .. tostring(rarity) .. "`",
            inline = false,
        },
        {
            name = "Shells left",
            value = "`" .. tostring(State.Shells) .. "`",
            inline = true,
        },
        {
            name = "Boxes opened",
            value = "`" .. tostring(State.BoxesOpened) .. "`",
            inline = true,
        },
    }

    local embed = {
        title = "MM2",
        description = isTarget and "Target item found" or "Rare item found",
        color = isTarget and 5763719 or 10181046,
        fields = fields,
        footer = {
            text = "MM2 Summer 2026 Kaitun",
        },
        timestamp = DateTime.now():ToIsoDate(),
    }

    local thumbnailUrl = imageToHttpUrl(image)
    if thumbnailUrl then
        embed.thumbnail = {
            url = thumbnailUrl,
        }
    end

    local content = "Found: " .. tostring(displayName)
    if type(Config.WebhookMention) == "string" and Config.WebhookMention ~= "" then
        content = Config.WebhookMention .. "\n" .. content
    end

    local body = HttpService:JSONEncode({
        content = content,
        embeds = { embed },
    })

    local ok, response = pcall(function()
        return RequestFunction({
            Url = Config.Webhook,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
            },
            Body = body,
        })
    end)

    if not ok then
        warn("[MM2 KAITUN] Webhook failed:", response)
        return false
    end

    return true
end

local Sync
local ProfileData
local ItemService

local function requireWithRetry(moduleScript, label)
    local lastError
    for _ = 1, 40 do
        if State.Stopped then
            return nil
        end
        local ok, result = pcall(require, moduleScript)
        if ok and result then
            return result
        end
        lastError = result
        task.wait(0.25)
    end
    warn("[MM2 KAITUN] Failed to require " .. label .. ":", lastError)
    return nil
end

Sync = requireWithRetry(
    ReplicatedStorage:WaitForChild("Database"):WaitForChild("Sync"),
    "Sync"
)
ProfileData = requireWithRetry(
    ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ProfileData"),
    "ProfileData"
)
ItemService = requireWithRetry(
    ReplicatedStorage:WaitForChild("ClientServices"):WaitForChild("ItemService"),
    "ItemService"
)

if not Sync or not ProfileData or not ItemService then
    State.Stopped = true
    setStatus("Required MM2 modules were not found")
    return
end

local function getShellCount()
    local materials = ProfileData.Materials
        and ProfileData.Materials.Owned
    local amount = materials and materials[Config.ShellId]
    return tonumber(amount) or 0
end

local function getBoxCost()
    local ok, price = pcall(function()
        local shopItem = Sync.NewShop and Sync.NewShop[Config.BoxId]
        return shopItem
            and shopItem.Price
            and shopItem.Price[Config.ShellId]
    end)

    if ok and tonumber(price) then
        return tonumber(price)
    end

    return tonumber(Config.BoxCostFallback) or 120
end

local function getRewardInfo(rewardId)
    local itemInfo
    local displayInfo

    pcall(function()
        itemInfo = ItemService:FindItemInfo(rewardId, "Weapons")
    end)

    pcall(function()
        displayInfo = ItemService:GetDisplayInfo(rewardId, "Weapons")
    end)

    itemInfo = itemInfo or {}
    displayInfo = displayInfo or {}

    local displayName = displayInfo.Name
        or itemInfo.Name
        or itemInfo.DisplayName
        or itemInfo.ItemName
        or rewardId

    if itemInfo.Chroma == true
        and not string.find(string.lower(tostring(displayName)), "chroma", 1, true)
    then
        displayName = "Chroma " .. tostring(displayName)
    end

    local rarity = itemInfo.Rarity or "Unknown"
    local image = displayInfo.Image or itemInfo.Image or itemInfo.Icon or ""

    return tostring(displayName), tostring(rarity), image, itemInfo
end

local Gui
local StatusLabel

local function createStatusGui()
    if not Config.ShowStatus then
        return
    end

    local parent
    local ok, hiddenGui = pcall(function()
        return gethui and gethui()
    end)
    if ok and hiddenGui then
        parent = hiddenGui
    else
        parent = game:GetService("CoreGui")
    end

    pcall(function()
        local oldGui = parent:FindFirstChild("MM2Summer2026Kaitun")
        if oldGui then
            oldGui:Destroy()
        end
    end)

    Gui = Instance.new("ScreenGui")
    Gui.Name = "MM2Summer2026Kaitun"
    Gui.ResetOnSpawn = false
    Gui.IgnoreGuiInset = true
    Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    StatusLabel = Instance.new("TextLabel")
    StatusLabel.Name = "Status"
    StatusLabel.AnchorPoint = Vector2.new(0.5, 0)
    StatusLabel.Position = UDim2.new(0.5, 0, 0.03, 0)
    StatusLabel.Size = UDim2.new(0, 620, 0, 62)
    StatusLabel.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
    StatusLabel.BackgroundTransparency = 0.2
    StatusLabel.BorderSizePixel = 0
    StatusLabel.Font = Enum.Font.GothamBold
    StatusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    StatusLabel.TextStrokeTransparency = 0.75
    StatusLabel.TextSize = 16
    StatusLabel.TextWrapped = true
    StatusLabel.Parent = Gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = StatusLabel

    local parented = pcall(function()
        Gui.Parent = parent
    end)
    if not parented then
        Gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
    State.Gui = Gui
end

createStatusGui()

task.spawn(function()
    while not State.Stopped do
        State.Shells = getShellCount()
        if StatusLabel and StatusLabel.Parent then
            StatusLabel.Text = string.format(
                "MM2 SUMMER 2026 | %s\nCoin: %d/%d | Shells: %d | Boxes: %d | Last: %s (%s)",
                State.Status,
                State.BagCurrent,
                State.BagLimit,
                State.Shells,
                State.BoxesOpened,
                State.LastItem,
                State.LastRarity
            )
        end
        task.wait(0.5)
    end
end)

local function optimizeObject(object)
    pcall(function()
        if object:IsA("ParticleEmitter")
            or object:IsA("Trail")
            or object:IsA("Beam")
            or object:IsA("Smoke")
            or object:IsA("Fire")
            or object:IsA("Sparkles")
        then
            object.Enabled = false
        elseif object:IsA("PostEffect") then
            object.Enabled = false
        elseif object:IsA("PointLight")
            or object:IsA("SpotLight")
            or object:IsA("SurfaceLight")
        then
            object.Enabled = false
        elseif object:IsA("BasePart") then
            object.CastShadow = false
            object.Reflectance = 0
        end
    end)
end

local function applyLowGraphics()
    if not Config.LowGraphics then
        return
    end

    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    end)
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 1000000
        Lighting.Brightness = 1
    end)
    pcall(function()
        sethiddenproperty(workspace.Terrain, "Decoration", false)
    end)

    for _, object in ipairs(workspace:GetDescendants()) do
        optimizeObject(object)
    end
    for _, object in ipairs(Lighting:GetChildren()) do
        optimizeObject(object)
    end

    addConnection(workspace.DescendantAdded:Connect(optimizeObject))
    addConnection(Lighting.ChildAdded:Connect(optimizeObject))
end

if setfpscap and tonumber(Config.FPSCap) then
    pcall(setfpscap, math.max(3, tonumber(Config.FPSCap)))
end

if Config.Disable3DRendering then
    pcall(function()
        RunService:Set3dRenderingEnabled(false)
    end)
end

applyLowGraphics()

if Config.AntiAFK then
    addConnection(LocalPlayer.Idled:Connect(function()
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            task.wait(0.5)
            VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        end)
    end))
end

-- Không tắt CanCollide toàn bộ nhân vật.
-- Di chuyển bằng Humanoid/Pathfinding để tránh lệch vị trí client-server.

local function getCharacterParts()
    local character = LocalPlayer.Character
    if not character then
        return nil, nil, nil
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
        or character:FindFirstChild("UpperTorso")
        or character:FindFirstChild("Torso")

    if not humanoid or humanoid.Health <= 0 or not root then
        return character, nil, humanoid
    end

    return character, root, humanoid
end

local CoinQueue = {}
local CoinQueueHead = 1
local QueuedTargets = setmetatable({}, { __mode = "k" })
local RetryCount = setmetatable({}, { __mode = "k" })
local CoinBlacklist = setmetatable({}, { __mode = "k" })
local buildMovePlan

local function allowedCoinType(coinType)
    return Config.AllowedCoinTypes
        and Config.AllowedCoinTypes[tostring(coinType)] == true
end

local function resolveCoinTarget(instance)
    if not instance or not instance.Parent then
        return nil, nil, nil
    end

    local visual = instance
    local target

    if instance.Name == "Coin_Server" and instance:IsA("BasePart") then
        target = instance
        visual = instance:FindFirstChild("CoinVisual") or instance
    elseif instance.Name == "CoinVisual" then
        if instance.Parent and instance.Parent.Name == "Coin_Server" and instance.Parent:IsA("BasePart") then
            target = instance.Parent
        elseif instance:IsA("BasePart") then
            target = instance
        end
    elseif instance:IsA("BasePart") then
        target = instance
    end

    if not target or not target:IsA("BasePart") then
        return nil, nil, nil
    end

    local coinType = visual:GetAttribute("CoinID")
        or target:GetAttribute("CoinID")
        or "Coin"

    return target, visual, tostring(coinType)
end

local function isCoinUsable(target, visual, coinType)
    if not target or not target.Parent then
        return false
    end
    if not allowedCoinType(coinType) then
        return false
    end
    if State.BagFull then
        return false
    end
    if visual and visual ~= target then
        if visual:GetAttribute("Delete") == true
            or visual:GetAttribute("Collected") == true
        then
            return false
        end
    end
    return true
end

local function enqueueCoin(instance)
    local target, visual, coinType = resolveCoinTarget(instance)
    if not isCoinUsable(target, visual, coinType) then
        return
    end
    if QueuedTargets[target] then
        return
    end

    QueuedTargets[target] = true
    table.insert(CoinQueue, {
        Target = target,
        Visual = visual,
        CoinType = coinType,
    })
end

local function blacklistCoin(target, seconds)
    if not target then
        return
    end

    CoinBlacklist[target] = os.clock()
        + math.max(1, tonumber(seconds) or tonumber(Config.CoinBlacklistTime) or 12)
end

local function isCoinBlacklisted(target)
    local expiresAt = target and CoinBlacklist[target]
    if not expiresAt then
        return false
    end

    if os.clock() >= expiresAt then
        CoinBlacklist[target] = nil
        return false
    end

    return true
end

local function removeQueueIndex(index)
    local entry = CoinQueue[index]
    table.remove(CoinQueue, index)

    if entry and entry.Target then
        QueuedTargets[entry.Target] = nil
    end

    return entry
end

local function pruneCoinQueue()
    for index = #CoinQueue, 1, -1 do
        local entry = CoinQueue[index]
        if not entry
            or not isCoinUsable(entry.Target, entry.Visual, entry.CoinType)
        then
            removeQueueIndex(index)
        end
    end
end

local function popCoin()
    local _, root = getCharacterParts()
    if not root then
        return nil
    end

    pruneCoinQueue()

    local scanRadius = math.max(20, tonumber(Config.CoinScanRadius) or 220)
    local maxDistance = tonumber(Config.MaxCoinDistance) or 0
    if maxDistance > 0 then
        scanRadius = math.min(scanRadius, maxDistance)
    end

    local candidates = {}
    local farCandidates = {}

    for index, entry in ipairs(CoinQueue) do
        local target = entry and entry.Target
        if target
            and target.Parent
            and not isCoinBlacklisted(target)
            and isCoinUsable(target, entry.Visual, entry.CoinType)
        then
            local distance = (root.Position - target.Position).Magnitude
            local item = {
                Index = index,
                Entry = entry,
                Distance = distance,
            }

            if distance <= scanRadius then
                table.insert(candidates, item)
            else
                table.insert(farCandidates, item)
            end
        end
    end

    local function sortNearest(list)
        table.sort(list, function(a, b)
            if a.Distance == b.Distance then
                return tostring(a.Entry.Target) < tostring(b.Entry.Target)
            end
            return a.Distance < b.Distance
        end)
    end

    sortNearest(candidates)

    if #candidates == 0 and Config.AllowFarCoinFallback == true then
        sortNearest(farCandidates)
        candidates = farCandidates
    end

    if #candidates == 0 then
        return nil
    end

    local checks = math.max(1, tonumber(Config.NearestCoinCandidates) or 6)
    checks = math.min(checks, #candidates)

    local bestCandidate
    local bestPlan
    local bestScore = math.huge

    for i = 1, checks do
        local candidate = candidates[i]
        local target = candidate.Entry.Target
        local plan = buildMovePlan and buildMovePlan(target, root.Position)

        if plan then
            -- Đường đi thực tế quan trọng hơn khoảng cách thẳng.
            local score = plan.Length + (candidate.Distance * 0.05)
            if score < bestScore then
                bestScore = score
                bestCandidate = candidate
                bestPlan = plan
            end
        else
            blacklistCoin(target)
        end
    end

    if not bestCandidate then
        return nil
    end

    -- Tìm lại index vì table có thể đã được dọn trước đó.
    local selectedIndex
    for index, entry in ipairs(CoinQueue) do
        if entry == bestCandidate.Entry then
            selectedIndex = index
            break
        end
    end

    if not selectedIndex then
        return nil
    end

    local entry = removeQueueIndex(selectedIndex)
    if entry then
        entry.Distance = bestCandidate.Distance
        entry.MovePlan = bestPlan
    end

    return entry
end

local function scanTaggedCoins()
    for _, visual in ipairs(CollectionService:GetTagged("CoinVisual")) do
        enqueueCoin(visual)
    end
end

local function scanMapCoinContainers()
    for _, map in ipairs(workspace:GetChildren()) do
        local container = map:FindFirstChild("CoinContainer")
        if container then
            for _, coinServer in ipairs(container:GetChildren()) do
                if coinServer.Name == "Coin_Server" and coinServer:IsA("BasePart") then
                    enqueueCoin(coinServer)
                end
            end
        end
    end
end

addConnection(CollectionService:GetInstanceAddedSignal("CoinVisual"):Connect(function(visual)
    State.LastCoinActivity = os.clock()
    enqueueCoin(visual)
end))

local function getTouchParts(character, root)
    local parts = {}
    local preferredNames = {
        "HumanoidRootPart",
        "LowerTorso",
        "UpperTorso",
        "Torso",
        "Head",
        "LeftFoot",
        "RightFoot",
        "Left Leg",
        "Right Leg",
    }

    local added = {}
    for _, name in ipairs(preferredNames) do
        local part = character and character:FindFirstChild(name)
        if part and part:IsA("BasePart") and not added[part] then
            added[part] = true
            table.insert(parts, part)
        end
    end

    if root and not added[root] then
        table.insert(parts, 1, root)
    end

    return parts
end

local function coinWasCollected(entry, serialBefore, bagBefore)
    if State.CollectionSerial ~= serialBefore or State.BagCurrent > bagBefore then
        return true
    end

    local target = entry and entry.Target
    local visual = entry and entry.Visual

    if not target or not target.Parent then
        return true
    end

    if visual then
        if not visual.Parent
            or visual:GetAttribute("Collected") == true
            or visual:GetAttribute("Delete") == true
        then
            return true
        end
    end

    return false
end

local function pulseTouch(parts, touchTargets)
    for _, bodyPart in ipairs(parts) do
        if bodyPart and bodyPart.Parent then
            pcall(function()
                bodyPart.CanTouch = true
            end)

            for _, touchTarget in ipairs(touchTargets) do
                if touchTarget and touchTarget.Parent then
                    pcall(function()
                        touchTarget.CanTouch = true
                    end)

                    if firetouchinterest then
                        pcall(function()
                            firetouchinterest(bodyPart, touchTarget, 0)
                        end)
                    end
                end
            end
        end
    end

    task.wait(math.max(0.05, tonumber(Config.TouchPulseDelay) or 0.10))

    if firetouchinterest then
        for _, bodyPart in ipairs(parts) do
            if bodyPart and bodyPart.Parent then
                for _, touchTarget in ipairs(touchTargets) do
                    if touchTarget and touchTarget.Parent then
                        pcall(function()
                            firetouchinterest(bodyPart, touchTarget, 1)
                        end)
                    end
                end
            end
        end
    end
end

local function isFiniteNumber(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function isValidPosition(position)
    if typeof(position) ~= "Vector3" then
        return false
    end

    if not isFiniteNumber(position.X)
        or not isFiniteNumber(position.Y)
        or not isFiniteNumber(position.Z)
    then
        return false
    end

    return math.abs(position.X) <= 100000
        and math.abs(position.Y) <= 100000
        and math.abs(position.Z) <= 100000
end

local function movementCancelled()
    return State.Stopped
        or State.TargetFound
        or State.BagFull
        or State.Hopping
end

local function makeRayParams(character, target)
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude

    local excluded = {}
    if character then
        table.insert(excluded, character)
    end
    if target then
        table.insert(excluded, target)
    end

    rayParams.FilterDescendantsInstances = excluded
    rayParams.IgnoreWater = false
    return rayParams
end

local function projectToGround(position, character, target)
    if not isValidPosition(position) then
        return nil
    end

    local result = workspace:Raycast(
        position + Vector3.new(0, 24, 0),
        Vector3.new(0, -90, 0),
        makeRayParams(character, target)
    )

    if not result or not isValidPosition(result.Position) then
        return nil
    end

    return result.Position + Vector3.new(0, 3, 0)
end

local function getApproachPositions(target, character)
    if not target or not target.Parent or not target:IsA("BasePart") then
        return {}
    end

    local radius = math.clamp(tonumber(Config.ApproachRadius) or 6, 3, 8)
    local diagonal = radius * 0.70710678
    local offsets = {
        Vector3.zero,
        Vector3.new(radius, 0, 0),
        Vector3.new(-radius, 0, 0),
        Vector3.new(0, 0, radius),
        Vector3.new(0, 0, -radius),
        Vector3.new(diagonal, 0, diagonal),
        Vector3.new(-diagonal, 0, diagonal),
        Vector3.new(diagonal, 0, -diagonal),
        Vector3.new(-diagonal, 0, -diagonal),
    }

    local positions = {}
    for _, offset in ipairs(offsets) do
        local grounded = projectToGround(target.Position + offset, character, target)
        if grounded
            and (grounded - target.Position).Magnitude
                <= (tonumber(Config.TouchDistance) or 9) + 4
        then
            local duplicate = false
            for _, existing in ipairs(positions) do
                if (existing - grounded).Magnitude <= 1 then
                    duplicate = true
                    break
                end
            end

            if not duplicate then
                table.insert(positions, grounded)
            end
        end
    end

    return positions
end

local function computePathPlan(origin, destination)
    if not isValidPosition(origin) or not isValidPosition(destination) then
        return nil
    end

    local path = PathfindingService:CreatePath({
        AgentRadius = 2.2,
        AgentHeight = 5,
        AgentCanJump = true,
        AgentCanClimb = true,
        WaypointSpacing = math.max(2, tonumber(Config.PathWaypointSpacing) or 3),
    })

    local ok = pcall(function()
        path:ComputeAsync(origin, destination)
    end)

    if not ok or path.Status ~= Enum.PathStatus.Success then
        return nil
    end

    local waypoints = path:GetWaypoints()
    if #waypoints == 0 then
        return nil
    end

    local length = 0
    local previous = origin
    for _, waypoint in ipairs(waypoints) do
        length += (waypoint.Position - previous).Magnitude
        previous = waypoint.Position
    end

    return {
        Path = path,
        Waypoints = waypoints,
        Destination = destination,
        Length = length,
    }
end

buildMovePlan = function(target, origin)
    local character, root = getCharacterParts()
    if not character or not root or not target or not target.Parent then
        return nil
    end

    origin = origin or root.Position
    local positions = getApproachPositions(target, character)
    local bestPlan
    local bestScore = math.huge

    for _, destination in ipairs(positions) do
        local plan = computePathPlan(origin, destination)
        if plan then
            local score = plan.Length
                + ((destination - target.Position).Magnitude * 0.10)

            if score < bestScore then
                bestScore = score
                bestPlan = plan
            end
        end
    end

    return bestPlan
end

local function applyFarmWalkSpeed(humanoid)
    if not humanoid then
        return
    end

    pcall(function()
        humanoid.WalkSpeed = math.clamp(
            tonumber(Config.CoinWalkSpeed) or 22,
            16,
            26
        )
    end)
end

local function hasClearRoute(origin, destination, character, target)
    local direction = destination - origin
    if direction.Magnitude <= 1 then
        return true
    end

    local result = workspace:Raycast(
        origin,
        direction,
        makeRayParams(character, target)
    )

    return result == nil
end

local function followPlan(plan, target)
    local character, root, humanoid = getCharacterParts()
    if not character or not root or not humanoid or not plan then
        return false
    end

    applyFarmWalkSpeed(humanoid)

    local blockedAt
    local blockedConnection
    if plan.Path then
        blockedConnection = plan.Path.Blocked:Connect(function(index)
            blockedAt = index
        end)
    end

    local function cleanup()
        if blockedConnection then
            blockedConnection:Disconnect()
            blockedConnection = nil
        end
    end

    for index, waypoint in ipairs(plan.Waypoints or {}) do
        if movementCancelled() then
            cleanup()
            return false
        end

        if not target or not target.Parent then
            cleanup()
            return true
        end

        character, root, humanoid = getCharacterParts()
        if not character or not root or not humanoid then
            cleanup()
            return false
        end

        applyFarmWalkSpeed(humanoid)

        if blockedAt and blockedAt >= index then
            cleanup()
            return false
        end

        if waypoint.Action == Enum.PathWaypointAction.Jump then
            humanoid.Jump = true
        end

        pcall(function()
            humanoid.Sit = false
            humanoid.AutoRotate = true
            humanoid:MoveTo(waypoint.Position)
        end)

        local waypointDistance = (root.Position - waypoint.Position).Magnitude
        local walkSpeed = math.max(8, tonumber(humanoid.WalkSpeed) or 22)
        local dynamicTimeout = math.clamp(
            (waypointDistance / walkSpeed) + 2,
            2,
            tonumber(Config.WaypointTimeout) or 4.5
        )

        local deadline = os.clock() + dynamicTimeout
        local arrivalDistance = math.max(
            2.5,
            tonumber(Config.WaypointArrivalDistance) or 3.5
        )
        local lastCommand = os.clock()
        local lastProgressPosition = root.Position
        local lastProgressTime = os.clock()

        while os.clock() < deadline do
            if movementCancelled() then
                cleanup()
                return false
            end

            if not target or not target.Parent then
                cleanup()
                return true
            end

            character, root, humanoid = getCharacterParts()
            if not character or not root or not humanoid then
                cleanup()
                return false
            end

            if blockedAt and blockedAt >= index then
                cleanup()
                return false
            end

            if (root.Position - waypoint.Position).Magnitude <= arrivalDistance then
                break
            end

            local progress = (root.Position - lastProgressPosition).Magnitude
            if progress >= (tonumber(Config.StuckMinProgress) or 1.1) then
                lastProgressPosition = root.Position
                lastProgressTime = os.clock()
            elseif os.clock() - lastProgressTime
                >= (tonumber(Config.StuckTimeout) or 1.6)
            then
                cleanup()
                return false
            end

            if os.clock() - lastCommand >= 0.55 then
                lastCommand = os.clock()
                applyFarmWalkSpeed(humanoid)
                pcall(function()
                    humanoid.Sit = false
                    humanoid:MoveTo(waypoint.Position)
                end)
            end

            task.wait(math.max(
                0.08,
                tonumber(Config.StuckCheckInterval) or 0.15
            ))
        end

        if (root.Position - waypoint.Position).Magnitude > arrivalDistance + 1 then
            cleanup()
            return false
        end
    end

    cleanup()

    character, root, humanoid = getCharacterParts()
    if not character or not root or not humanoid then
        return false
    end

    local touchDistance = math.max(4, tonumber(Config.TouchDistance) or 9)
    if target and target.Parent
        and (root.Position - target.Position).Magnitude <= touchDistance
    then
        return true
    end

    -- Chỉ đi thẳng đoạn cuối nếu raycast xác nhận không có tường chắn.
    if target and target.Parent
        and hasClearRoute(root.Position, target.Position, character, target)
    then
        humanoid:MoveTo(target.Position)
        local deadline = os.clock() + math.max(
            1,
            tonumber(Config.DirectMoveTimeout) or 6
        )

        while os.clock() < deadline do
            if movementCancelled() then
                return false
            end
            if not target.Parent then
                return true
            end
            if (root.Position - target.Position).Magnitude <= touchDistance then
                return true
            end
            task.wait(0.10)
        end
    end

    return target
        and target.Parent
        and (root.Position - target.Position).Magnitude <= touchDistance
end

local function moveSafelyToCoin(entry)
    local target = entry and entry.Target
    if not target or not target.Parent then
        return false
    end

    local attempts = math.max(1, tonumber(Config.PathRecomputeAttempts) or 3)
    local plan = entry.MovePlan

    for _ = 1, attempts do
        if movementCancelled() then
            return false
        end

        if not target.Parent then
            return true
        end

        local _, root = getCharacterParts()
        if not root then
            return false
        end

        plan = plan or buildMovePlan(target, root.Position)
        if not plan then
            return false
        end

        if followPlan(plan, target) then
            return true
        end

        plan = nil
        task.wait(0.10)
    end

    return false
end

local function touchCoin(entry)
    local character, root, humanoid = getCharacterParts()
    local target = entry and entry.Target
    local visual = entry and entry.Visual

    if not character
        or not root
        or not humanoid
        or not target
        or not target.Parent
        or not target:IsA("BasePart")
    then
        return false
    end

    if not isValidPosition(target.Position) then
        blacklistCoin(target)
        warn("[MM2 KAITUN] Skipped coin: invalid position")
        return false
    end

    local serialBefore = State.CollectionSerial
    local bagBefore = State.BagCurrent

    setStatus(string.format(
        "Walking to nearest %s | %.0f studs",
        tostring(entry.CoinType or "Coin"),
        tonumber(entry.Distance) or (root.Position - target.Position).Magnitude
    ))

    if not moveSafelyToCoin(entry) then
        blacklistCoin(target)
        warn("[MM2 KAITUN] Coin unreachable - blacklisted temporarily")
        return false
    end

    character, root, humanoid = getCharacterParts()
    if not character or not root or not humanoid then
        return false
    end
    if not target.Parent then
        return true
    end

    local touchDistance = math.max(4, tonumber(Config.TouchDistance) or 9)
    if (root.Position - target.Position).Magnitude > touchDistance then
        blacklistCoin(target)
        return false
    end

    local touchParts = getTouchParts(character, root)
    local touchTargets = { target }

    if visual
        and visual:IsA("BasePart")
        and visual ~= target
        and visual.Parent
    then
        table.insert(touchTargets, visual)
    end

    local attempts = math.max(1, tonumber(Config.TouchAttempts) or 3)
    for _ = 1, attempts do
        if movementCancelled() then
            return false
        end
        if coinWasCollected(entry, serialBefore, bagBefore) then
            return true
        end
        if not target.Parent then
            return true
        end
        if (root.Position - target.Position).Magnitude > touchDistance + 2 then
            blacklistCoin(target)
            return false
        end

        pulseTouch(touchParts, touchTargets)
        task.wait(math.max(0.05, tonumber(Config.CollectDelay) or 0.14))
    end

    local collected = coinWasCollected(entry, serialBefore, bagBefore)
    if not collected then
        blacklistCoin(target, 5)
    end
    return collected
end

local function retryCoin(entry)
    if not entry or not entry.Target or not entry.Target.Parent then
        return
    end

    local count = (RetryCount[entry.Target] or 0) + 1
    RetryCount[entry.Target] = count

    if count <= (tonumber(Config.MaxCoinRetries) or 3) then
        task.delay(tonumber(Config.CoinRetryDelay) or 0.35, function()
            if not State.Stopped and not State.BagFull then
                enqueueCoin(entry.Visual or entry.Target)
            end
        end)
    end
end

local function cleanCoinQueue()
    CoinQueue = {}
    CoinQueueHead = 1
    QueuedTargets = setmetatable({}, { __mode = "k" })
    RetryCount = setmetatable({}, { __mode = "k" })
    CoinBlacklist = setmetatable({}, { __mode = "k" })
end

local VisitedFile = "MM2_Summer2026_VisitedServers.json"
local VisitedServers = {}

local function loadVisitedServers()
    if not readfile or not isfile or not isfile(VisitedFile) then
        return
    end

    local ok, decoded = pcall(function()
        return HttpService:JSONDecode(readfile(VisitedFile))
    end)
    if ok and type(decoded) == "table" then
        VisitedServers = decoded
    end
end

local function saveVisitedServers()
    if not writefile then
        return
    end
    pcall(function()
        writefile(VisitedFile, HttpService:JSONEncode(VisitedServers))
    end)
end

local function cleanupVisitedServers()
    local now = os.time()
    local lifetime = tonumber(Config.RememberServersFor) or 7200
    for serverId, timestamp in pairs(VisitedServers) do
        if type(timestamp) ~= "number" or now - timestamp > lifetime then
            VisitedServers[serverId] = nil
        end
    end
end

loadVisitedServers()
cleanupVisitedServers()
VisitedServers[game.JobId] = os.time()
saveVisitedServers()

local function fetchServerPage(cursor)
    local url = "https://games.roblox.com/v1/games/"
        .. tostring(game.PlaceId)
        .. "/servers/Public?sortOrder=Asc&excludeFullGames=true&limit=100"

    if cursor and cursor ~= "" then
        url = url .. "&cursor=" .. HttpService:UrlEncode(cursor)
    end

    local body
    local ok = pcall(function()
        body = game:HttpGet(url)
    end)

    if not ok or type(body) ~= "string" then
        return nil
    end

    local decoded
    ok = pcall(function()
        decoded = HttpService:JSONDecode(body)
    end)

    if not ok or type(decoded) ~= "table" then
        return nil
    end

    return decoded
end

local function findServer()
    cleanupVisitedServers()

    local candidates = {}
    local cursor = nil
    local maxPages = math.max(1, tonumber(Config.MaxServerPages) or 3)
    local minPlayers = math.max(0, tonumber(Config.MinServerPlayers) or 2)
    local maxPlayers = math.max(minPlayers, tonumber(Config.MaxServerPlayers) or 8)

    for _ = 1, maxPages do
        local page = fetchServerPage(cursor)
        if not page then
            break
        end

        for _, server in ipairs(page.data or {}) do
            local playing = tonumber(server.playing) or 0
            local capacity = tonumber(server.maxPlayers) or 0
            if server.id
                and server.id ~= game.JobId
                and not VisitedServers[server.id]
                and playing >= minPlayers
                and playing <= maxPlayers
                and playing < capacity
            then
                table.insert(candidates, server)
            end
        end

        cursor = page.nextPageCursor
        if not cursor or cursor == "" then
            break
        end
    end

    table.sort(candidates, function(a, b)
        local aPlaying = tonumber(a.playing) or 999
        local bPlaying = tonumber(b.playing) or 999
        if aPlaying == bPlaying then
            return tostring(a.id) < tostring(b.id)
        end
        return aPlaying < bPlaying
    end)

    if #candidates > 0 then
        return candidates[math.random(1, math.min(#candidates, 8))]
    end

    return nil
end

local function hopServer(reason)
    if State.Stopped or State.TargetFound or not Config.AutoHop then
        return false
    end
    if State.Hopping or State.Opening then
        return false
    end

    local now = os.clock()
    if now - State.LastHopAttempt < (tonumber(Config.HopCooldown) or 12) then
        return false
    end

    State.LastHopAttempt = now
    State.Hopping = true
    setStatus("Finding server: " .. tostring(reason))

    local server = findServer()
    if not server then
        VisitedServers = {
            [game.JobId] = os.time(),
        }
        saveVisitedServers()
        server = findServer()
    end

    if not server then
        State.Hopping = false
        setStatus("No suitable server found")
        return false
    end

    VisitedServers[server.id] = os.time()
    saveVisitedServers()
    setStatus("Hopping to " .. tostring(server.playing) .. " player server")

    local ok, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer)
    end)

    if not ok then
        State.Hopping = false
        warn("[MM2 KAITUN] Teleport failed:", err)
        return false
    end

    task.delay(10, function()
        if not State.Stopped then
            State.Hopping = false
        end
    end)

    return true
end

local function scheduleHop(reason, delaySeconds)
    if not Config.AutoHop or State.HopPending or State.Hopping or State.TargetFound then
        return
    end

    State.HopPending = true
    task.spawn(function()
        task.wait(math.max(0, tonumber(delaySeconds) or 0))

        while State.Opening and not State.Stopped and not State.TargetFound do
            task.wait(0.5)
        end

        State.HopPending = false
        if not State.Stopped and not State.TargetFound then
            hopServer(reason)
        end
    end)
end

addConnection(CoinsStartedRemote.OnClientEvent:Connect(function(activeCoinTypes)
    State.RoundActive = true
    State.BagCurrent = 0
    State.BagFull = false
    State.LastCoinActivity = os.clock()
    cleanCoinQueue()
    setStatus("Round started - scanning coins")

    task.defer(function()
        scanTaggedCoins()
        scanMapCoinContainers()
    end)
end))

addConnection(CoinCollectedRemote.OnClientEvent:Connect(function(coinType, current, limit)
    coinType = tostring(coinType)
    if not allowedCoinType(coinType) then
        return
    end

    local oldCurrent = State.BagCurrent
    State.CollectionSerial += 1
    State.BagCurrent = tonumber(current) or State.BagCurrent
    State.BagLimit = tonumber(limit) or State.BagLimit
    State.CoinsCollected += math.max(0, State.BagCurrent - oldCurrent)
    State.LastCoinActivity = os.clock()

    if State.BagCurrent >= State.BagLimit then
        State.BagFull = true
        cleanCoinQueue()
        setStatus("Coin bag full")

        if Config.HopAfterBagFull then
            scheduleHop("bag full", Config.HopDelayAfterFull)
        end
    else
        setStatus("Collecting coins")
    end
end))

addConnection(TeleportService.TeleportInitFailed:Connect(function(player, result, message)
    if player == LocalPlayer then
        State.Hopping = false
        setStatus("Teleport failed: " .. tostring(result))
        warn("[MM2 KAITUN]", message)
    end
end))

task.spawn(function()
    task.wait(1)
    scanTaggedCoins()
    scanMapCoinContainers()

    while not State.Stopped do
        if Config.FarmCoins
            and not State.TargetFound
            and not State.BagFull
            and not State.Hopping
        then
            if #CoinQueue == 0 then
                scanTaggedCoins()
                scanMapCoinContainers()
            end

            local entry = popCoin()
            if entry and isCoinUsable(entry.Target, entry.Visual, entry.CoinType) then
                local collected = touchCoin(entry)

                if not collected
                    and isCoinUsable(entry.Target, entry.Visual, entry.CoinType)
                then
                    setStatus("Nearest Coin unreachable - selecting another")
                    blacklistCoin(entry.Target)
                    task.wait(0.08)
                end
            else
                setStatus("No reachable Coin nearby - rescanning")
                task.wait(0.18)
            end
        else
            task.wait(0.25)
        end
    end
end)

task.spawn(function()
    while not State.Stopped do
        if Config.FarmCoins and not State.TargetFound and not State.BagFull then
            scanTaggedCoins()
            scanMapCoinContainers()
        end
        task.wait(math.max(0.5, tonumber(Config.FallbackScanDelay) or 2))
    end
end)

local function processReward(rewardId)
    local displayName, rarity, image = getRewardInfo(rewardId)
    local target = isTargetItem(rewardId, displayName)
    local notifyByRarity = Config.NotifyRarities
        and Config.NotifyRarities[rarity] == true
    local shouldNotify = Config.NotifyAllUnboxes == true
        or target
        or notifyByRarity

    State.LastItem = displayName
    State.LastRarity = rarity
    State.Shells = getShellCount()

    print(string.format(
        "[MM2 KAITUN] Opened: %s | ID: %s | Rarity: %s",
        displayName,
        tostring(rewardId),
        rarity
    ))

    if shouldNotify then
        sendWebhook(rewardId, displayName, rarity, image, target)
    end

    if target then
        State.TargetFound = true
        cleanCoinQueue()
        setStatus("TARGET FOUND: " .. displayName)

        if Config.StopWhenTargetFound then
            Config.FarmCoins = false
            Config.AutoOpenBox = false
            Config.AutoHop = false
        end
    else
        setStatus("Opened " .. displayName)
    end
end

local function openOneBox()
    if State.Opening or State.TargetFound or State.Hopping then
        return false
    end

    State.Opening = true
    setStatus("Opening Summer Box '26")

    local ok, reward = pcall(function()
        return OpenCrateRemote:InvokeServer(
            Config.BoxId,
            "MysteryBox",
            Config.ShellId
        )
    end)

    if not ok or type(reward) ~= "string" or reward == "" then
        State.Opening = false
        if not ok then
            warn("[MM2 KAITUN] OpenCrate failed:", reward)
        end
        task.wait(1.5)
        return false
    end

    State.BoxesOpened += 1
    task.wait(math.max(0.2, tonumber(Config.BoxCompleteDelay) or 1.2))

    pcall(function()
        CrateCompleteRemote:FireServer(reward)
    end)

    task.wait(0.25)
    State.Shells = getShellCount()
    processReward(reward)
    task.wait(math.max(0.3, tonumber(Config.BoxOpenDelay) or 1.4))
    State.Opening = false

    if State.BagFull
        and Config.AutoHop
        and Config.HopAfterBagFull
        and not State.TargetFound
    then
        scheduleHop("bag full after box", 1)
    end

    return true
end

task.spawn(function()
    while not State.Stopped do
        State.Shells = getShellCount()

        if Config.AutoOpenBox
            and not State.TargetFound
            and not State.Hopping
        then
            local cost = getBoxCost()
            if State.Shells >= cost then
                openOneBox()
            else
                task.wait(0.8)
            end
        else
            task.wait(0.8)
        end
    end
end)

task.spawn(function()
    while not State.Stopped do
        if Config.AutoHop
            and not State.TargetFound
            and not State.Hopping
            and not State.Opening
            and not State.HopPending
        then
            local inactivity = os.clock() - State.LastCoinActivity
            local timeout = tonumber(Config.HopIfNoCoinActivityFor) or 55
            if inactivity >= timeout then
                scheduleHop("no coin activity", 0)
                State.LastCoinActivity = os.clock()
            end
        end
        task.wait(4)
    end
end)

setStatus("Ready - waiting for coins")
