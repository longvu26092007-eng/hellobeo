-- TYRANT SPAWN + FARM ONLY
-- Standalone bootstrap.
-- Build: kaituncdkmm fast attack/tween + buy+farmtalon purchase logic + BFNEW compatibility.

if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes", 30)
local CommF_ = remotes and remotes:WaitForChild("CommF_", 30)

if not LocalPlayer then error("[K4 Tyrant] LocalPlayer not found") end
if not CommF_ then error("[K4 Tyrant] CommF_ remote not found after update") end

local function status(text)
    getgenv().K4TyrantStatus = tostring(text or "")
    print("[K4 Tyrant] " .. getgenv().K4TyrantStatus)
end


-- ============================================================================
-- FRAGMENT + RACE COMPLETION CONTROLLER
-- Cấu hình ngoài cần thiết:
--   getgenv().fragmenttarget = 8000
--   getgenv().race = "mink" -- mink/shark/angel/human/ghoul/cyborg/off
--
-- Chỉ tạo <PlayerName>.txt = "Completed-fragment" khi:
--   1) Fragment hiện tại >= fragmenttarget
--   2) Race hiện tại đúng getgenv().race
-- Với race="off", bỏ qua điều kiện race và không gọi remote đổi race.
-- ============================================================================
local K4ENV = (type(getgenv) == "function" and getgenv()) or _G
K4ENV.fragmenttarget = K4ENV.fragmenttarget or 8000
K4ENV.race = K4ENV.race or "off"

local K4_RACE_ALIASES = {
    rabbit = "Mink",
    mink = "Mink",
    shark = "Fishman",
    fishman = "Fishman",
    angel = "Skypiea",
    skypiea = "Skypiea",
    human = "Human",
    ghoul = "Ghoul",
    cyborg = "Cyborg",
}

local K4_REROLLABLE_RACES = {
    Mink = true,
    Fishman = true,
    Skypiea = true,
    Human = true,
}

local K4_RACE_DISPLAY = {
    Mink = "Mink/Rabbit",
    Fishman = "Shark/Fishman",
    Skypiea = "Angel/Skypiea",
    Human = "Human",
    Ghoul = "Ghoul",
    Cyborg = "Cyborg",
}

local K4Completion = {
    Started = false,
    Completed = false,
    RaceReady = false,
    TargetRace = false,
    CurrentRace = nil,
    CurrentFragments = 0,
    TargetFragments = 0,
    RaceAttempts = 0,
    LastRaceActionAt = 0,
    LastLogAt = 0,
    Status = "Initializing",
    FileName = nil,
}

local function K4NormalizeRaceConfig(value)
    local key = tostring(value or "")
        :lower()
        :gsub("^%s+", "")
        :gsub("%s+$", "")
        :gsub("[^%a]", "")

    if key == "" or key == "off" then
        return false
    end

    local mapped = K4_RACE_ALIASES[key]
    if not mapped then
        warn(("[K4 Completion] Race config không hợp lệ: %s -> coi như off"):format(tostring(value)))
        return false
    end
    return mapped
end

local function K4GetRaceTarget()
    return K4NormalizeRaceConfig(K4ENV.race)
end

local function K4GetCurrentRace()
    local data = LocalPlayer:FindFirstChild("Data")
    local raceValue = data and data:FindFirstChild("Race")
    return raceValue and tostring(raceValue.Value) or nil
end

local function K4GetCurrentFragments()
    local data = LocalPlayer:FindFirstChild("Data")
    local fragments = data and data:FindFirstChild("Fragments")
    return tonumber(fragments and fragments.Value) or 0
end

local function K4GetFragmentTarget()
    local target = tonumber(K4ENV.fragmenttarget)
    if not target or target <= 0 then
        return nil
    end
    return math.floor(target)
end

local function K4RaceMatchesTarget(targetRace)
    if not targetRace then
        return true
    end
    return K4GetCurrentRace() == targetRace
end

local function K4RaceDisplay(race)
    if race == false or race == nil then
        return "OFF"
    end
    return K4_RACE_DISPLAY[race] or tostring(race)
end

local function K4WriteCompletedFragment()
    if K4Completion.Completed then
        return true
    end

    local targetFragments = K4GetFragmentTarget()
    local targetRace = K4GetRaceTarget()
    local currentFragments = K4GetCurrentFragments()
    local currentRace = K4GetCurrentRace()
    local raceReady = K4RaceMatchesTarget(targetRace)

    K4Completion.TargetFragments = targetFragments or 0
    K4Completion.TargetRace = targetRace
    K4Completion.CurrentFragments = currentFragments
    K4Completion.CurrentRace = currentRace
    K4Completion.RaceReady = raceReady

    if not targetFragments then
        K4Completion.Status = "fragmenttarget invalid"
        return false
    end

    if currentFragments < targetFragments or not raceReady then
        return false
    end

    if type(writefile) ~= "function" then
        K4Completion.Status = "writefile unsupported"
        warn("[K4 Completion] Executor không hỗ trợ writefile")
        return false
    end

    -- Kiểm tra lại ngay trước lúc ghi để không tạo file khi vừa bị đổi race/tiêu Fragment.
    currentFragments = K4GetCurrentFragments()
    currentRace = K4GetCurrentRace()
    raceReady = (not targetRace) or currentRace == targetRace
    if currentFragments < targetFragments or not raceReady then
        return false
    end

    local fileName = tostring(LocalPlayer.Name) .. ".txt"
    local ok, err = pcall(function()
        writefile(fileName, "Completed-fragment")
    end)

    if not ok then
        K4Completion.Status = "write failed"
        warn("[K4 Completion] Lỗi ghi " .. fileName .. ": " .. tostring(err))
        return false
    end

    K4Completion.Completed = true
    K4Completion.FileName = fileName
    K4Completion.Status = "Completed-fragment"

    K4ENV.CompletedFragment = true
    K4ENV.CompletedFragmentFile = fileName
    K4ENV.CompletedFragmentRace = currentRace
    K4ENV.CompletedFragmentValue = currentFragments
    K4ENV.CompletedFragmentTarget = targetFragments

    warn(string.format(
        "[K4 Completion] Đã ghi %s = Completed-fragment | Race=%s | Fragment=%d/%d",
        fileName,
        tostring(currentRace or "off"),
        currentFragments,
        targetFragments
    ))
    return true
end

local function K4DoRaceAction(targetRace)
    if not targetRace then
        return
    end

    local currentRace = K4GetCurrentRace()
    if currentRace == targetRace then
        return
    end

    local now = tick()
    if now - (K4Completion.LastRaceActionAt or 0) < 3 then
        return
    end

    if K4_REROLLABLE_RACES[targetRace] then
        local fragments = K4GetCurrentFragments()
        if fragments < 2500 then
            K4Completion.Status = "Waiting 2500 fragments for reroll"
            return
        end

        K4Completion.LastRaceActionAt = now
        K4Completion.RaceAttempts = K4Completion.RaceAttempts + 1
        K4Completion.Status = "Rerolling race"

        warn(string.format(
            "[K4 Race] Reroll #%d | current=%s | target=%s | fragments=%d",
            K4Completion.RaceAttempts,
            tostring(currentRace),
            tostring(targetRace),
            fragments
        ))

        pcall(function()
            CommF_:InvokeServer("BlackbeardReward", "Reroll", "1")
        end)

        task.wait(0.30)
        if K4GetCurrentRace() == targetRace then
            return
        end

        pcall(function()
            CommF_:InvokeServer("BlackbeardReward", "Reroll", "2")
        end)
        task.wait(1.50)
        return
    end

    if targetRace == "Ghoul" then
        K4Completion.LastRaceActionAt = now
        K4Completion.RaceAttempts = K4Completion.RaceAttempts + 1
        K4Completion.Status = "Changing to Ghoul"
        pcall(function()
            CommF_:InvokeServer("Ectoplasm", "BuyCheck", 4)
        end)
        task.wait(0.50)
        if K4GetCurrentRace() ~= targetRace then
            pcall(function()
                CommF_:InvokeServer("Ectoplasm", "Change", 4)
            end)
        end
        task.wait(1.50)
        return
    end

    if targetRace == "Cyborg" then
        K4Completion.LastRaceActionAt = now
        K4Completion.RaceAttempts = K4Completion.RaceAttempts + 1
        K4Completion.Status = "Changing to Cyborg"
        pcall(function()
            CommF_:InvokeServer("CyborgTrainer", "Buy")
        end)
        task.wait(1.50)
    end
end

local function K4StartFragmentRaceController()
    if K4Completion.Started then
        return
    end
    K4Completion.Started = true

    -- Race driver: sai target thì tiếp tục gọi remote; đúng target thì dừng gọi.
    task.spawn(function()
        while not K4Completion.Completed do
            local targetRace = K4GetRaceTarget()
            local currentRace = K4GetCurrentRace()
            local currentFragments = K4GetCurrentFragments()

            K4Completion.TargetRace = targetRace
            K4Completion.CurrentRace = currentRace
            K4Completion.CurrentFragments = currentFragments
            K4Completion.TargetFragments = K4GetFragmentTarget() or 0
            K4Completion.RaceReady = (not targetRace) or currentRace == targetRace

            if not targetRace then
                K4Completion.Status = "Race gate OFF"
                task.wait(1)
            elseif currentRace == targetRace then
                K4Completion.Status = "Race ready"
                task.wait(1)
            else
                K4Completion.Status = "Waiting target race"
                K4DoRaceAction(targetRace)
                task.wait(0.50)
            end
        end
    end)

    -- Completion checker: phải đạt đồng thời Fragment + Race mới ghi file.
    task.spawn(function()
        while not K4Completion.Completed do
            K4WriteCompletedFragment()

            if not K4Completion.Completed and tick() - (K4Completion.LastLogAt or 0) >= 15 then
                K4Completion.LastLogAt = tick()
                warn(string.format(
                    "[K4 Completion] Fragment=%d/%s | Race=%s/%s | Ready=%s",
                    K4GetCurrentFragments(),
                    tostring(K4GetFragmentTarget() or "invalid"),
                    tostring(K4GetCurrentRace() or "loading"),
                    K4RaceDisplay(K4GetRaceTarget()),
                    tostring(K4RaceMatchesTarget(K4GetRaceTarget()))
                ))
            end

            task.wait(1)
        end
    end)
end

local AttackConfig = {
    AttackDistance = 105,
    AttackMobs = true,
    AttackPlayers = false,
    AutoClickEnabled = true,
    BringMobs = true,
    PreGrabDistance = 1500
}

local module = {}
local activeMoveTarget = nil
local activeMoveOptions = {}
local activeMoveEnabled = false
local activeMoveRoot = nil
local activeMoveVelocity = Vector3.zero
local activeMoveSmoothedPosition = nil
local activeMoveLastCommandAt = 0
local lastEquipAttempt = 0
local selectedCombatToolName = nil
local lastRegisteredAttack = 0

local K4_MOVE_VELOCITY_NAME = "K4SmoothMoveVelocity"
local K4_MOVE_GYRO_NAME = "K4SmoothMoveGyro"

local function K4GetCharacterParts()
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    return character, humanoid, root
end

local function K4SetCharacterNoclip(character)
    if not character then return end
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
end

local function K4GetMoveActuators(root)
    if not root or not root.Parent then return nil, nil end

    local velocity = root:FindFirstChild(K4_MOVE_VELOCITY_NAME)
    if not velocity then
        velocity = Instance.new("BodyVelocity")
        velocity.Name = K4_MOVE_VELOCITY_NAME
        velocity.P = 1600
        velocity.MaxForce = Vector3.new(1e9, 1e9, 1e9)
        velocity.Velocity = Vector3.zero
        velocity.Parent = root
    end

    local gyro = root:FindFirstChild(K4_MOVE_GYRO_NAME)
    if not gyro then
        gyro = Instance.new("BodyGyro")
        gyro.Name = K4_MOVE_GYRO_NAME
        gyro.P = 5000
        gyro.D = 850
        -- Only rotate around Y. Pitch/roll changes were another source of shaking.
        gyro.MaxTorque = Vector3.new(0, 1e9, 0)
        gyro.CFrame = root.CFrame
        gyro.Parent = root
    end

    return velocity, gyro
end

local function K4MoveVectorTowards(current, target, maximumChange)
    local difference = target - current
    local magnitude = difference.Magnitude
    if magnitude <= maximumChange or magnitude <= 1e-4 then
        return target
    end
    return current + difference.Unit * maximumChange
end

local function K4ClampVectorMagnitude(vector, maximumMagnitude)
    local magnitude = vector.Magnitude
    if magnitude <= maximumMagnitude or magnitude <= 1e-4 then
        return vector
    end
    return vector.Unit * maximumMagnitude
end

local function K4CancelMoveTween(clearTarget)
    activeMoveEnabled = false
    activeMoveVelocity = Vector3.zero
    activeMoveSmoothedPosition = nil
    activeMoveLastCommandAt = 0

    local _, humanoid, root = K4GetCharacterParts()
    if humanoid then
        humanoid.AutoRotate = true
    end
    if root then
        local velocity = root:FindFirstChild(K4_MOVE_VELOCITY_NAME)
        if velocity then
            pcall(function() velocity:Destroy() end)
        end
        local gyro = root:FindFirstChild(K4_MOVE_GYRO_NAME)
        if gyro then
            pcall(function() gyro:Destroy() end)
        end
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end

    activeMoveRoot = nil
    if clearTarget ~= false then
        activeMoveTarget = nil
        activeMoveOptions = {}
    end
end

-- One persistent physics controller is used for every player movement.
-- Long-distance travel uses smooth acceleration/braking. While attacking a mob,
-- FollowPart mode continuously matches the mob velocity and corrects positional
-- error every Heartbeat, so the player stays attached without CFrame snapping.
RunService.Heartbeat:Connect(function(deltaTime)
    if not activeMoveEnabled or typeof(activeMoveTarget) ~= "CFrame" then return end

    local character, humanoid, root = K4GetCharacterParts()
    if not character or not humanoid or not root or humanoid.Health <= 0 then
        return
    end

    if activeMoveRoot ~= root then
        activeMoveRoot = root
        activeMoveVelocity = Vector3.zero
        activeMoveSmoothedPosition = activeMoveTarget.Position
    end

    K4SetCharacterNoclip(character)
    humanoid.Sit = false
    humanoid.AutoRotate = false

    local velocityMover, gyro = K4GetMoveActuators(root)
    if not velocityMover or not gyro then return end

    deltaTime = math.clamp(tonumber(deltaTime) or 0.016, 0.001, 0.10)
    local options = activeMoveOptions
    local followPart = options.FollowPart
    local followingPart = typeof(followPart) == "Instance"
        and followPart:IsA("BasePart")
        and followPart:IsDescendantOf(Workspace)

    local rawTargetPosition = activeMoveTarget.Position
    local targetVelocity = Vector3.zero
    local lookPosition = rawTargetPosition + activeMoveTarget.LookVector

    if followingPart then
        local followOffset = options.FollowOffset
        if typeof(followOffset) ~= "Vector3" then
            followOffset = Vector3.new(0, tonumber(options.FollowHeight) or 18, 0)
        end

        targetVelocity = followPart.AssemblyLinearVelocity
        local targetVelocityCap = math.max(tonumber(options.TargetVelocityCap) or 95, 1)
        targetVelocity = K4ClampVectorMagnitude(targetVelocity, targetVelocityCap)

        local prediction = math.clamp(tonumber(options.PredictionTime) or 0.08, 0, 0.25)
        rawTargetPosition = followPart.Position + followOffset + targetVelocity * prediction
        lookPosition = followPart.Position
    end

    local targetResponsiveness = math.max(
        tonumber(options.TargetResponsiveness) or (followingPart and 24 or 18),
        1
    )
    local targetAlpha = 1 - math.exp(-targetResponsiveness * deltaTime)

    if not activeMoveSmoothedPosition then
        activeMoveSmoothedPosition = rawTargetPosition
    else
        activeMoveSmoothedPosition = activeMoveSmoothedPosition:Lerp(rawTargetPosition, targetAlpha)
    end

    local offset = activeMoveSmoothedPosition - root.Position
    local distance = offset.Magnitude
    local maximumSpeed = math.max(tonumber(options.Speed) or 300, 1)
    local acceleration = math.max(tonumber(options.Acceleration) or 750, 50)
    local deceleration = math.max(tonumber(options.Deceleration) or 850, 50)
    local desiredVelocity = Vector3.zero

    if followingPart then
        -- Continuous follow: inside the dead zone, inherit the enemy velocity;
        -- outside it, add proportional correction instead of stopping/restarting.
        local deadZone = math.max(tonumber(options.FollowDeadZone) or 1.25, 0.25)
        local followGain = math.max(tonumber(options.FollowGain) or 7.5, 0.5)
        local correction = Vector3.zero

        if distance > deadZone and distance > 1e-3 then
            local correctedDistance = distance - deadZone
            correction = offset.Unit * math.min(maximumSpeed, correctedDistance * followGain)
        end

        desiredVelocity = K4ClampVectorMagnitude(targetVelocity + correction, maximumSpeed)
    else
        local arrivalDistance = math.max(tonumber(options.ArrivalDistance) or 5, 2)
        if distance > arrivalDistance and distance > 1e-3 then
            local brakingDistance = math.max(distance - arrivalDistance, 0)
            local brakingSpeed = math.sqrt(2 * deceleration * brakingDistance)
            local desiredSpeed = math.min(maximumSpeed, brakingSpeed)
            if distance > 30 then
                desiredSpeed = math.max(desiredSpeed, math.min(maximumSpeed, 45))
            end
            desiredVelocity = offset.Unit * desiredSpeed
        end
    end

    local velocityChangeRate = desiredVelocity.Magnitude < activeMoveVelocity.Magnitude
        and deceleration
        or acceleration
    activeMoveVelocity = K4MoveVectorTowards(
        activeMoveVelocity,
        desiredVelocity,
        velocityChangeRate * deltaTime
    )

    if not followingPart and desiredVelocity.Magnitude < 0.5 and activeMoveVelocity.Magnitude < 3 then
        activeMoveVelocity = Vector3.zero
    end

    velocityMover.Velocity = activeMoveVelocity
    root.AssemblyAngularVelocity = Vector3.zero

    local flatLook = Vector3.new(
        lookPosition.X - root.Position.X,
        0,
        lookPosition.Z - root.Position.Z
    )
    if flatLook.Magnitude > 0.05 then
        gyro.CFrame = CFrame.lookAt(root.Position, root.Position + flatLook.Unit)
    end
end)

function module:topos(targetCF, moveOptions)
    if typeof(targetCF) ~= "CFrame" then return false end

    local character, humanoid, root = K4GetCharacterParts()
    if not character or not humanoid or not root or humanoid.Health <= 0 then
        return false
    end

    moveOptions = type(moveOptions) == "table" and moveOptions or {}
    local targetPosition = targetCF.Position
    targetPosition = Vector3.new(targetPosition.X, math.max(targetPosition.Y, 5), targetPosition.Z)
    targetCF = CFrame.new(targetPosition) * (targetCF - targetCF.Position)

    local wasActive = activeMoveEnabled
    local previousTarget = activeMoveTarget
    activeMoveTarget = targetCF
    activeMoveOptions = moveOptions
    activeMoveEnabled = true
    activeMoveLastCommandAt = tick()

    if not wasActive or activeMoveRoot ~= root then
        activeMoveRoot = root
        activeMoveVelocity = Vector3.zero
        activeMoveSmoothedPosition = targetPosition
    elseif moveOptions.ResetVelocity == true then
        activeMoveVelocity = Vector3.zero
    elseif moveOptions.Follow ~= true
        and previousTarget
        and (previousTarget.Position - targetPosition).Magnitude > 250
    then
        -- A new long-distance destination should start immediately rather than
        -- smoothing through the old destination.
        activeMoveSmoothedPosition = targetPosition
    end

    humanoid.Sit = false
    humanoid.AutoRotate = false
    K4SetCharacterNoclip(character)
    K4GetMoveActuators(root)
    return true
end

function module:haki()
    local character = LocalPlayer.Character
    if character and not character:FindFirstChild("HasBuso") then
        pcall(function()
            CommF_:InvokeServer("Buso")
        end)
    end
end

function module:eq()
    local character, humanoid = K4GetCharacterParts()
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not character or not humanoid or humanoid.Health <= 0 or not backpack then
        return false
    end

    local config = getgenv().TyrantConfig
    local wanted = tostring(selectedCombatToolName or (config and config.Weapon) or "")
        :gsub("%s+", "")
        :lower()

    local equipped = character:FindFirstChildWhichIsA("Tool")
    if equipped then
        local equippedName = equipped.Name:gsub("%s+", ""):lower()
        if equippedName == wanted then
            return true
        end
    end

    if tick() - lastEquipAttempt < 0.8 then return false end
    lastEquipAttempt = tick()

    local meleeFallback = nil
    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") then
            local normalized = tool.Name:gsub("%s+", ""):lower()
            if normalized == wanted then
                selectedCombatToolName = tool.Name
                humanoid:EquipTool(tool)
                return true
            end
            if not meleeFallback then
                local tooltip = string.lower(tostring(tool.ToolTip or ""))
                local weaponType = string.lower(tostring(tool:GetAttribute("WeaponType") or ""))
                if tooltip == "melee" or weaponType == "melee" then
                    meleeFallback = tool
                end
            end
        end
    end

    if meleeFallback and not equipped then
        selectedCombatToolName = meleeFallback.Name
        humanoid:EquipTool(meleeFallback)
        return true
    end
    return false
end

local NetFolder = ReplicatedStorage:WaitForChild("Modules", 30)
NetFolder = NetFolder and NetFolder:WaitForChild("Net", 30)
local RegisterAttack = NetFolder and NetFolder:WaitForChild("RE/RegisterAttack", 30)
local RegisterHit = NetFolder and NetFolder:WaitForChild("RE/RegisterHit", 30)

local function K4IsCombatTool(tool)
    if not tool or not tool:IsA("Tool") then return false end
    local tooltip = string.lower(tostring(tool.ToolTip or ""))
    local weaponType = string.lower(tostring(tool:GetAttribute("WeaponType") or ""))
    return tooltip == "melee"
        or tooltip == "sword"
        or weaponType == "melee"
        or weaponType == "sword"
end

local function K4CollectAttackTargets(folder, character, origin, hits)
    local firstPart = nil
    if not folder then return nil end

    for _, target in ipairs(folder:GetChildren()) do
        if target ~= character then
            local humanoid = target:FindFirstChildOfClass("Humanoid")
            local hitPart = target:FindFirstChild("Head") or target:FindFirstChild("HumanoidRootPart")
            if humanoid
                and humanoid.Health > 0
                and hitPart
                and hitPart:IsA("BasePart")
                and (hitPart.Position - origin).Magnitude <= (tonumber(AttackConfig.AttackDistance) or 65)
            then
                firstPart = firstPart or hitPart
                hits[#hits + 1] = { target, hitPart }
            end
        end
    end
    return firstPart
end

-- Fast attack copied from kaituncdkmm and made standalone for Tyrant.
-- RegisterHit argument #1 is always a BasePart, matching BFNEW's combat path.
local AttackInstance = {}
function AttackInstance:Attack()
    if AttackConfig.AutoClickEnabled == false then return false end

    local character, humanoid, root = K4GetCharacterParts()
    if not character or not humanoid or humanoid.Health <= 0 or not root then
        return false
    end

    local tool = character:FindFirstChildWhichIsA("Tool")
    if not tool then
        module:eq()
        tool = character:FindFirstChildWhichIsA("Tool")
    end
    if not K4IsCombatTool(tool) then return false end

    local config = getgenv().TyrantConfig
    local delay = math.max(tonumber(config and config.AttackDelay) or 0.03, 0.01)
    if tick() - lastRegisteredAttack < delay then return false end

    if RegisterAttack and RegisterHit then
        local hits = {}
        local basePart = nil

        if AttackConfig.AttackMobs ~= false then
            basePart = K4CollectAttackTargets(
                Workspace:FindFirstChild("Enemies"),
                character,
                root.Position,
                hits
            )
        end

        -- Player hits stay disabled by default to avoid attacking nearby users.
        if AttackConfig.AttackPlayers == true then
            local playerPart = K4CollectAttackTargets(
                Workspace:FindFirstChild("Characters"),
                character,
                root.Position,
                hits
            )
            basePart = basePart or playerPart
        end

        if basePart and basePart:IsA("BasePart") and #hits > 0 then
            local ok = pcall(function()
                RegisterAttack:FireServer(0)
                RegisterHit:FireServer(basePart, hits)
            end)
            if ok then
                lastRegisteredAttack = tick()
                return true
            end
        end
    end

    pcall(function()
        tool:Activate()
    end)
    return false
end

local function K4LockMob(mob)
    if not mob or not mob.Parent then return end
    local humanoid = mob:FindFirstChildOfClass("Humanoid")
    local root = mob:FindFirstChild("HumanoidRootPart")
    if not humanoid or humanoid.Health <= 0 or not root then return end

    root.CanCollide = false
    if not root:FindFirstChild("K4KaitunMobLock") then
        local bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.Name = "K4KaitunMobLock"
        bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
        bodyVelocity.Velocity = Vector3.zero
        bodyVelocity.Parent = root
    end

    for _, part in ipairs(mob:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
end

-- Kaitun-style mob grouping, with zero-count/network-owner guards added.
local function GrabMobs(mobName)
    local enemies = Workspace:FindFirstChild("Enemies")
    local _, _, playerRoot = K4GetCharacterParts()
    if not enemies or not playerRoot or tostring(mobName or "") == "" then
        return false
    end

    pcall(function()
        if type(sethiddenproperty) == "function" then
            sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge)
        end
    end)

    local nearestRoot = nil
    local nearestDistance = math.huge
    for _, mob in ipairs(enemies:GetChildren()) do
        local humanoid = mob:FindFirstChildOfClass("Humanoid")
        local root = mob:FindFirstChild("HumanoidRootPart")
        if mob.Name == mobName and humanoid and humanoid.Health > 0 and root then
            local distance = (root.Position - playerRoot.Position).Magnitude
            if distance < nearestDistance then
                nearestDistance = distance
                nearestRoot = root
            end
        end
    end
    if not nearestRoot then return false end

    local maxDistance = tonumber(AttackConfig.PreGrabDistance) or 1500
    local entries = {}
    local total = Vector3.zero

    for _, mob in ipairs(enemies:GetChildren()) do
        local humanoid = mob:FindFirstChildOfClass("Humanoid")
        local root = mob:FindFirstChild("HumanoidRootPart")
        if mob.Name == mobName
            and humanoid
            and humanoid.Health > 0
            and root
            and (root.Position - playerRoot.Position).Magnitude <= maxDistance
            and (root.Position - nearestRoot.Position).Magnitude <= 250
        then
            local owned = true
            if type(isnetworkowner) == "function" then
                local ok, result = pcall(isnetworkowner, root)
                owned = ok and result == true
            end
            if owned then
                entries[#entries + 1] = mob
                total = total + root.Position
            end
        end
    end

    if #entries == 0 then return false end
    local midpoint = total / #entries

    for _, mob in ipairs(entries) do
        local root = mob:FindFirstChild("HumanoidRootPart")
        if root and root.Parent then
            root.CFrame = CFrame.new(midpoint)
            K4LockMob(mob)
        end
    end
    return true
end

-- Persistent Kaitun noclip/stabilizer. It does not force an artificial cruise
-- altitude, so it cannot fight with boss hover or vase skill positioning.
RunService.Stepped:Connect(function()
    local character, humanoid, root = K4GetCharacterParts()
    if character and humanoid and humanoid.Health > 0 and root then
        K4SetCharacterNoclip(character)
        root.AssemblyAngularVelocity = Vector3.zero
        local head = character:FindFirstChild("Head")
        local bodyVelocity = head and head:FindFirstChild("K4KaitunBodyVelocity")
        if bodyVelocity then
            pcall(function() bodyVelocity:Destroy() end)
        end
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    K4CancelMoveTween()
    lastEquipAttempt = 0
    selectedCombatToolName = nil
end)

getgenv().TyrantConfig = getgenv().TyrantConfig or {}
for key, value in pairs({
    Team = "Marines",
    Weapon = "Dragon Talon",
    AutoBuyDragonTalon = true,
    DragonTalonBuyRetry = 30,
    DragonTalonNoMoneyRetry = 300,
    DragonTalonRequirementRetry = 180,
    DragonTalonBuyMaxAttempts = 8,
    AutoBuso = true,
    TweenSpeed = 300,
    FarmFollowSpeed = 300,
    FarmArrivalDistance = 7,
    FarmFollowDeadZone = 1.25,
    FarmFollowGain = 7.5,
    FarmFollowPrediction = 0.08,
    FarmTargetVelocityCap = 95,
    FarmHeight = 18,
    BossHeight = 25,
    AttackDistance = 105,
    AttackDelay = 0.03,
    BringMobs = true,

    -- Tyrant 4 logic: wait for all four real eyes to turn red, then break
    -- the twelve fixed vases with Z/X/C using the existing Kaitun tween/attack.
    UseSkillsForVases = true,
    VaseSkillKeys = { "Z", "X", "C" },
    VaseSkillHoldTime = 0.12,
    VaseSkillReleaseDelay = 0.45,
    VaseSkillRetryDelay = 0.18,
    VaseTargetTimeout = 45,

    BringMobInterval = 0.15,
    BringDistance = 1500,
    BringTweenSpeed = 300,
    TyrantScanInterval = 0.15
}) do
    if getgenv().TyrantConfig[key] == nil then
        getgenv().TyrantConfig[key] = value
    end
end
getgenv().TyrantConfig.VaseSkillKeys = { "Z", "X", "C" }
TyrantConfig = getgenv().TyrantConfig

K4TyrantFarmController = (function()
local TyrState = {
    Farming = false,
    CurrentMode = "IDLE",
    CurrentTarget = nil,
    SkillCasting = false,
    SkillInputBusy = false,
    VaseSkillIndex = 0,
    CachedTyrant = nil,
    LastTyrantScan = 0,
    CachedEyesReady = false,
    CachedActiveEyeCount = 0,
    EyeReadySince = nil,
    CachedEye1 = nil,
    CachedEye2 = nil,
    CachedEye3 = nil,
    CachedEye4 = nil,
    EyeConnections = {},
    LastEyeBindAttempt = 0,
    InternalSkillReadyAt = {},
    BringTweens = setmetatable({}, { __mode = "k" })
}

local TIKI_CENTER = CFrame.new(
    -16490.9727, 98.1144867, 1245.58984,
    -0.034969449, 0, 0.999388516,
    0, 1, 0,
    -0.999388516, 0, -0.034969449
)

local ARENA_CENTER = Vector3.new(-16335, 174, 1397)
local DRAGON_TALON_BUY_POS = CFrame.new(5661.616211, 1211.299438, 865.999451)

-- 12 vá»‹ trÃ­ bÃ¬nh tháº­t tá»« auto_farm_tyrant4. KhÃ´ng dá»±a vÃ o GetChildren()[index]
-- vÃ¬ thá»© tá»± child cÃ³ thá»ƒ thay Ä‘á»•i giá»¯a cÃ¡c server.
local STATIC_VASE_CENTER = Vector3.new(-16275.984642, 157.838229, 1390.372659)
local STATIC_VASE_TARGETS = {
    { Name = "Vase01", Mesh = "Meshes/brokenurns_Cylinder.010", SourceIndex = 19, CFrame = CFrame.new(-16332.5264, 158.071655, 1440.32507, 0.999388874, 0, 0.0349550731, 0, 1, 0, -0.0349550731, 0, 0.999388874) },
    { Name = "Vase02", Mesh = "Meshes/brokenurns_Cylinder.009", SourceIndex = 18, CFrame = CFrame.new(-16335.1641, 158.166733, 1465.64404, 0.999388874, 0, 0.0349550731, 0, 1, 0, -0.0349550731, 0, 0.999388874) },
    { Name = "Vase03", Mesh = "Meshes/brokenurns_Cylinder.009", SourceIndex = 17, CFrame = CFrame.new(-16288.6094, 158.166733, 1470.36816, 0.999388874, 0, 0.0349550731, 0, 1, 0, -0.0349550731, 0, 0.999388874) },
    { Name = "Vase04", Mesh = "Meshes/brokenurns_Cylinder.009", SourceIndex = 16, CFrame = CFrame.new(-16258.001, 156.760635, 1461.40356, 0.999388874, 0, 0.0349550731, 0, 1, 0, -0.0349550731, 0, 0.999388874) },
    { Name = "Vase05", Mesh = "Meshes/brokenurns_Cylinder.014", SourceIndex = 14, CFrame = CFrame.new(-16245.4121, 158.437012, 1463.36597, -0.993159413, 0, 0.116766132, 0, 1, 0, -0.116766132, 0, -0.993159413) },
    { Name = "Vase06", Mesh = "Meshes/brokenurns_Cylinder.009", SourceIndex = 15, CFrame = CFrame.new(-16212.4688, 158.166733, 1466.34387, 0.999388874, 0, 0.0349550731, 0, 1, 0, -0.0349550731, 0, 0.999388874) },
    { Name = "Vase07", Mesh = "Meshes/brokenurns_Cylinder.010", SourceIndex = -1, IsTree = true, CFrame = CFrame.new(-16211.9463, 158.071655, 1322.39807, -0.466439605, 0, -0.884553134, 0, 1, 0, 0.884553134, 0, -0.466439605) },
    { Name = "Vase08", Mesh = "Meshes/brokenurns_Cylinder.009", SourceIndex = 13, CFrame = CFrame.new(-16250.2354, 158.166733, 1313.01941, 0.999388874, 0, 0.0349550731, 0, 1, 0, -0.0349550731, 0, 0.999388874) },
    { Name = "Vase09", Mesh = "Meshes/brokenurns_Cylinder.009", SourceIndex = 12, CFrame = CFrame.new(-16260.2803, 158.166733, 1320.45532, 0.999388874, 0, 0.0349550731, 0, 1, 0, -0.0349550731, 0, 0.999388874) },
    { Name = "Vase10", Mesh = "Meshes/brokenurns_Cylinder.010", SourceIndex = 22, CFrame = CFrame.new(-16296.1162, 157.767914, 1315.79407, -0.463313937, 0, 0.886194229, 0, 1, 0, -0.886194229, 0, -0.463313937) },
    { Name = "Vase11", Mesh = "Meshes/brokenurns_Cylinder.009", SourceIndex = 21, CFrame = CFrame.new(-16286.0586, 155.949478, 1323.83765, 0.999388874, 0, 0.0349550731, 0, 1, 0, -0.0349550731, 0, 0.999388874) },
    { Name = "Vase12", Mesh = "Meshes/brokenurns_Cylinder.009", SourceIndex = 20, CFrame = CFrame.new(-16334.9971, 158.166733, 1321.51672, 0.999388874, 0, 0.0349550731, 0, 1, 0, -0.0349550731, 0, 0.999388874) }
}

local VASE_SKILL_HOLD_TIME = {
    Z = 0.035,
    X = 0.12,
    C = 0.05
}

local VASE_SKILL_RELEASE_WAIT = {
    Z = 0.65,
    X = 0.50,
    C = 1.45
}

local TikiMobs = {
    ["Isle Outlaw"] = true,
    ["Island Boy"] = true,
    ["Sun-kissed Warrior"] = true,
    ["Isle Champion"] = true,
    ["Serpent Hunter"] = true,
    ["Skull Slayer"] = true
}

local function TyrCharacter()
    return LocalPlayer.Character
end

local function TyrHumanoid()
    local char = TyrCharacter()
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function TyrRoot()
    local char = TyrCharacter()
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function TyrNormalizeName(name)
    return tostring(name or ""):gsub("%s+", ""):lower()
end

local function TyrFindTool(name)
    local wanted = TyrNormalizeName(name)
    local char = TyrCharacter()
    local backpack = LocalPlayer:FindFirstChild("Backpack")

    if char then
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") and TyrNormalizeName(tool.Name) == wanted then
                return tool
            end
        end
    end

    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") and TyrNormalizeName(tool.Name) == wanted then
                return tool
            end
        end
    end

    return nil
end

local function TyrMoveTo(targetCF, waitForArrival, timeout)
    if typeof(targetCF) ~= "CFrame" then return false end
    local root = TyrRoot()
    if not root then return false end

    local initialDistance = (root.Position - targetCF.Position).Magnitude
    local configuredSpeed = math.max(tonumber(TyrantConfig and TyrantConfig.TweenSpeed) or 300, 1)
    local minimumTimeout = math.max(5, initialDistance / configuredSpeed + 10)
    timeout = math.max(tonumber(timeout) or 0, minimumTimeout)

    local moveOptions = {
        Speed = configuredSpeed,
        ArrivalDistance = 5,
        TargetResponsiveness = 30,
        Acceleration = 700,
        Deceleration = 800,
        Follow = false
    }
    module:topos(targetCF, moveOptions)
    if not waitForArrival then return true end

    local started = tick()
    local lastProgressAt = started
    local lastDistance = initialDistance

    repeat
        task.wait(0.10)
        root = TyrRoot()
        local humanoid = TyrHumanoid()
        if not root or not humanoid or humanoid.Health <= 0 then return false end

        local distance = (root.Position - targetCF.Position).Magnitude
        if distance <= 7 then
            K4CancelMoveTween(false)
            activeMoveTarget = targetCF
            return true
        end

        if distance < lastDistance - 1 then
            lastDistance = distance
            lastProgressAt = tick()
        elseif tick() - lastProgressAt > 3 then
            moveOptions.ResetVelocity = true
            module:topos(targetCF, moveOptions)
            moveOptions.ResetVelocity = nil
            lastProgressAt = tick()
            lastDistance = distance
        elseif not activeMoveEnabled then
            module:topos(targetCF, moveOptions)
        end
    until tick() - started >= timeout

    root = TyrRoot()
    if root and (root.Position - targetCF.Position).Magnitude <= 15 then
        K4CancelMoveTween(false)
        activeMoveTarget = targetCF
        return true
    end
    K4CancelMoveTween()
    return false
end

local function TyrGetEnemyFolders()
    local folders = {}
    local enemies = Workspace:FindFirstChild("Enemies")
    if enemies then folders[#folders + 1] = enemies end

    local origin = Workspace:FindFirstChild("_WorldOrigin")
    if origin and origin:FindFirstChild("Enemies") then
        folders[#folders + 1] = origin.Enemies
    end
    return folders
end

local function TyrBaseEnemyName(name)
    local clean = tostring(name or "")
    clean = clean:gsub("%s*%[Lv%.%s*%d+%]", "")
    clean = clean:gsub("%s*%[Lv%s*%d+%]", "")
    clean = clean:gsub("%s*%[Boss%]", "")
    clean = clean:gsub("%s*%[Raid Boss%]", "")
    return clean:gsub("%s+$", "")
end

local function TyrIsTikiMob(enemy)
    return enemy and TikiMobs[TyrBaseEnemyName(enemy.Name)] == true
end

local function TyrIsTyrant(enemy)
    return enemy ~= nil and string.find(string.lower(enemy.Name), "tyrant", 1, true) ~= nil
end

local function TyrFindTyrant(forceRefresh)
    local now = tick()
    if not forceRefresh and now - TyrState.LastTyrantScan < TyrantConfig.TyrantScanInterval then
        local cached = TyrState.CachedTyrant
        if cached and cached.Parent then
            local hum = cached:FindFirstChildOfClass("Humanoid")
            local root = cached:FindFirstChild("HumanoidRootPart")
            if hum and root and hum.Health > 0 then return cached end
        end
        return nil
    end

    TyrState.LastTyrantScan = now
    TyrState.CachedTyrant = nil

    for _, folder in ipairs(TyrGetEnemyFolders()) do
        for _, enemy in ipairs(folder:GetChildren()) do
            if TyrIsTyrant(enemy) then
                local hum = enemy:FindFirstChildOfClass("Humanoid")
                local root = enemy:FindFirstChild("HumanoidRootPart")
                if hum and root and hum.Health > 0 then
                    TyrState.CachedTyrant = enemy
                    return enemy
                end
            end
        end
    end
    return nil
end

local function TyrGetNearestTikiMob()
    local root = TyrRoot()
    if not root then return nil end

    local nearest = nil
    local nearestDistance = math.huge
    for _, folder in ipairs(TyrGetEnemyFolders()) do
        for _, enemy in ipairs(folder:GetChildren()) do
            local hum = enemy:FindFirstChildOfClass("Humanoid")
            local enemyRoot = enemy:FindFirstChild("HumanoidRootPart")
            if hum and enemyRoot and hum.Health > 0 and TyrIsTikiMob(enemy) then
                local distance = (root.Position - enemyRoot.Position).Magnitude
                if distance < nearestDistance then
                    nearest = enemy
                    nearestDistance = distance
                end
            end
        end
    end
    return nearest
end

local function TyrFindTikiIslandModel()
    local map = Workspace:FindFirstChild("Map")
    local tiki = map and map:FindFirstChild("TikiOutpost")
    return tiki and tiki:FindFirstChild("IslandModel")
end

-- ÄÃºng bá»‘n path máº¯t cá»§a Tyrant. Chá»‰ khi cáº£ 4 máº¯t Ä‘á» á»•n Ä‘á»‹nh má»›i phÃ¡ bÃ¬nh.
local TYRANT_FINAL_EYE_COLOR = Color3.fromRGB(255, 57, 57)
local TYRANT_EYE_COLOR_TOLERANCE = 10 / 255
local TYRANT_EYE_READY_STABLE_TIME = 0.75
local TYRANT_EXPECTED_EYE_POSITIONS = {
    Eye1 = Vector3.new(-16186.759766, 196.228531, 1440.732788),
    Eye2 = Vector3.new(-16192.060547, 196.052032, 1440.720825)
}

local function TyrGetEyeContainers()
    local islandModel = TyrFindTikiIslandModel()
    local islandChunks = islandModel and islandModel:FindFirstChild("IslandChunks")
    local chunkE = islandChunks and islandChunks:FindFirstChild("E")
    return islandModel, islandChunks, chunkE
end

local function TyrGetFourEyeParts()
    local islandModel, _, chunkE = TyrGetEyeContainers()
    if not islandModel then return nil, nil, nil, nil end
    return islandModel:FindFirstChild("Eye1"),
        islandModel:FindFirstChild("Eye2"),
        chunkE and chunkE:FindFirstChild("Eye3"),
        chunkE and chunkE:FindFirstChild("Eye4")
end

local function TyrIsCorrectEyePart(eye, expectedName)
    if not eye
        or not eye:IsA("BasePart")
        or eye.Name ~= expectedName
        or not eye:IsDescendantOf(Workspace)
    then
        return false
    end

    local islandModel, _, chunkE = TyrGetEyeContainers()
    if expectedName == "Eye1" or expectedName == "Eye2" then
        if eye.Parent ~= islandModel then return false end
        local expectedPosition = TYRANT_EXPECTED_EYE_POSITIONS[expectedName]
        return expectedPosition == nil or (eye.Position - expectedPosition).Magnitude <= 8
    end

    if expectedName == "Eye3" or expectedName == "Eye4" then
        return chunkE ~= nil and eye.Parent == chunkE
    end
    return false
end

local function TyrIsEyeFullyRed(eye, expectedName)
    if not TyrIsCorrectEyePart(eye, expectedName) then return false end
    local color = eye.Color
    local colorMatches = math.abs(color.R - TYRANT_FINAL_EYE_COLOR.R) <= TYRANT_EYE_COLOR_TOLERANCE
        and math.abs(color.G - TYRANT_FINAL_EYE_COLOR.G) <= TYRANT_EYE_COLOR_TOLERANCE
        and math.abs(color.B - TYRANT_FINAL_EYE_COLOR.B) <= TYRANT_EYE_COLOR_TOLERANCE
    return colorMatches and eye.Transparency <= 0.10
end

local function TyrUpdateEyeCache()
    local ready1 = TyrIsEyeFullyRed(TyrState.CachedEye1, "Eye1")
    local ready2 = TyrIsEyeFullyRed(TyrState.CachedEye2, "Eye2")
    local ready3 = TyrIsEyeFullyRed(TyrState.CachedEye3, "Eye3")
    local ready4 = TyrIsEyeFullyRed(TyrState.CachedEye4, "Eye4")

    TyrState.CachedActiveEyeCount = (ready1 and 1 or 0)
        + (ready2 and 1 or 0)
        + (ready3 and 1 or 0)
        + (ready4 and 1 or 0)
    TyrState.CachedEyesReady = TyrState.CachedActiveEyeCount == 4

    if TyrState.CachedEyesReady then
        TyrState.EyeReadySince = TyrState.EyeReadySince or tick()
    else
        TyrState.EyeReadySince = nil
    end
end

local function TyrDisconnectEyeWatchers()
    for _, connection in ipairs(TyrState.EyeConnections) do
        pcall(function() connection:Disconnect() end)
    end
    TyrState.EyeConnections = {}
end

local function TyrInvalidateEyeCache(immediate)
    TyrState.CachedEye1 = nil
    TyrState.CachedEye2 = nil
    TyrState.CachedEye3 = nil
    TyrState.CachedEye4 = nil
    TyrState.CachedActiveEyeCount = 0
    TyrState.CachedEyesReady = false
    TyrState.EyeReadySince = nil
    if immediate then TyrState.LastEyeBindAttempt = 0 end
end

local function TyrBindEyeWatchers(force)
    local now = tick()
    if not force and now - TyrState.LastEyeBindAttempt < 1 then return false end
    TyrState.LastEyeBindAttempt = now

    local islandModel, islandChunks, chunkE = TyrGetEyeContainers()
    if not islandModel or not islandChunks or not chunkE then
        TyrInvalidateEyeCache(false)
        return false
    end

    local eye1, eye2, eye3, eye4 = TyrGetFourEyeParts()
    if not TyrIsCorrectEyePart(eye1, "Eye1")
        or not TyrIsCorrectEyePart(eye2, "Eye2")
        or not TyrIsCorrectEyePart(eye3, "Eye3")
        or not TyrIsCorrectEyePart(eye4, "Eye4")
    then
        TyrInvalidateEyeCache(false)
        return false
    end

    if TyrState.CachedEye1 == eye1
        and TyrState.CachedEye2 == eye2
        and TyrState.CachedEye3 == eye3
        and TyrState.CachedEye4 == eye4
        and #TyrState.EyeConnections > 0
    then
        TyrUpdateEyeCache()
        return true
    end

    TyrDisconnectEyeWatchers()
    TyrState.CachedEye1 = eye1
    TyrState.CachedEye2 = eye2
    TyrState.CachedEye3 = eye3
    TyrState.CachedEye4 = eye4

    local function watchEye(eye)
        TyrState.EyeConnections[#TyrState.EyeConnections + 1] = eye:GetPropertyChangedSignal("Color"):Connect(TyrUpdateEyeCache)
        TyrState.EyeConnections[#TyrState.EyeConnections + 1] = eye:GetPropertyChangedSignal("Transparency"):Connect(TyrUpdateEyeCache)
        TyrState.EyeConnections[#TyrState.EyeConnections + 1] = eye.AncestryChanged:Connect(function()
            if not eye:IsDescendantOf(Workspace) then
                TyrDisconnectEyeWatchers()
                TyrInvalidateEyeCache(true)
            end
        end)
    end

    watchEye(eye1)
    watchEye(eye2)
    watchEye(eye3)
    watchEye(eye4)

    local function rebindOnEyeChange(child)
        if child.Name == "Eye1"
            or child.Name == "Eye2"
            or child.Name == "Eye3"
            or child.Name == "Eye4"
            or child.Name == "IslandChunks"
            or child.Name == "E"
        then
            task.defer(function() TyrBindEyeWatchers(true) end)
        end
    end

    TyrState.EyeConnections[#TyrState.EyeConnections + 1] = islandModel.ChildAdded:Connect(rebindOnEyeChange)
    TyrState.EyeConnections[#TyrState.EyeConnections + 1] = islandModel.ChildRemoved:Connect(rebindOnEyeChange)
    TyrState.EyeConnections[#TyrState.EyeConnections + 1] = islandChunks.ChildAdded:Connect(rebindOnEyeChange)
    TyrState.EyeConnections[#TyrState.EyeConnections + 1] = islandChunks.ChildRemoved:Connect(rebindOnEyeChange)
    TyrState.EyeConnections[#TyrState.EyeConnections + 1] = chunkE.ChildAdded:Connect(rebindOnEyeChange)
    TyrState.EyeConnections[#TyrState.EyeConnections + 1] = chunkE.ChildRemoved:Connect(function(child)
        if child == TyrState.CachedEye3 or child == TyrState.CachedEye4 then
            TyrDisconnectEyeWatchers()
            TyrInvalidateEyeCache(true)
        else
            rebindOnEyeChange(child)
        end
    end)

    TyrUpdateEyeCache()
    return true
end

local function TyrGetEyeProgress()
    if not TyrState.CachedEye1
        or not TyrState.CachedEye2
        or not TyrState.CachedEye3
        or not TyrState.CachedEye4
        or not TyrState.CachedEye1:IsDescendantOf(Workspace)
        or not TyrState.CachedEye2:IsDescendantOf(Workspace)
        or not TyrState.CachedEye3:IsDescendantOf(Workspace)
        or not TyrState.CachedEye4:IsDescendantOf(Workspace)
    then
        TyrBindEyeWatchers(false)
    end
    TyrUpdateEyeCache()
    return TyrState.CachedActiveEyeCount, 4
end

local function TyrAreEyesReady()
    local activeEyes = TyrGetEyeProgress()
    return activeEyes == 4
        and TyrState.CachedEyesReady
        and TyrState.EyeReadySince ~= nil
        and tick() - TyrState.EyeReadySince >= TYRANT_EYE_READY_STABLE_TIME
end

local function TyrBuyDragonTalon()
    local ownedTool = TyrFindTool("Dragon Talon") or TyrFindTool("DragonTalon")
    if ownedTool then
        TyrState.DragonTalonBuyFailed = false
        return true
    end
    if not TyrantConfig.AutoBuyDragonTalon then return false end

    local now = tick()
    local retryDelay = math.max(tonumber(TyrantConfig.DragonTalonBuyRetry) or 30, 5)
    if TyrState.NextDragonTalonBuyAt and now < TyrState.NextDragonTalonBuyAt then
        return false
    end
    if TyrState.LastDragonTalonBuyAttempt
        and now - TyrState.LastDragonTalonBuyAttempt < retryDelay
    then
        return false
    end
    TyrState.LastDragonTalonBuyAttempt = now
    TyrState.NextDragonTalonBuyAt = now + retryDelay
    TyrState.DragonTalonBuyFailed = false

    status("Tyrant: moving to Uzoth for Dragon Talon")
    local arrived = TyrMoveTo(DRAGON_TALON_BUY_POS, true, 90)
    if not arrived then
        TyrState.NextDragonTalonBuyAt = tick() + retryDelay
        status("Tyrant: could not reach Uzoth, will retry")
        return false
    end
    task.wait(0.75)

    local maxAttempts = math.max(tonumber(TyrantConfig.DragonTalonBuyMaxAttempts) or 8, 1)
    local lastResult = nil

    for attempt = 1, maxAttempts do
        if not TyrState.Farming or not TyrantConfig.AutoBuyDragonTalon then
            break
        end

        -- BFNEW uses this query form before the real purchase. It distinguishes
        -- already-owned/not-ready states without relying on old inventory data.
        local queryOk, queryResult = pcall(function()
            return CommF_:InvokeServer("BuyDragonTalon", true)
        end)

        if queryOk then
            lastResult = queryResult
            if typeof(queryResult) == "string" and queryResult ~= "" then
                status("Dragon Talon: " .. tostring(queryResult))
            elseif queryResult == 1 then
                status("Dragon Talon owned: switching fighting style")
            elseif queryResult == 3 then
                status("Dragon Talon: requirements not ready")
            else
                status(string.format("Dragon Talon: purchase attempt %d/%d", attempt, maxAttempts))
            end
        end

        local buyOk, buyResult = pcall(function()
            return CommF_:InvokeServer("BuyDragonTalon")
        end)
        if buyOk then
            lastResult = buyResult
        end

        local checkStarted = tick()
        repeat
            task.wait(0.20)
            ownedTool = TyrFindTool("Dragon Talon") or TyrFindTool("DragonTalon")
            if ownedTool then
                selectedCombatToolName = ownedTool.Name
                TyrState.DragonTalonBuyFailed = false
                TyrState.NextDragonTalonBuyAt = nil
                status("Dragon Talon ready")
                return true
            end
        until tick() - checkStarted >= 1.6

        if buyResult == 0 then
            TyrState.NextDragonTalonBuyAt = tick()
                + math.max(tonumber(TyrantConfig.DragonTalonNoMoneyRetry) or 300, retryDelay)
            status("Dragon Talon: not enough Beli or Fragments")
            break
        elseif buyResult == 3 or queryResult == 3 then
            TyrState.NextDragonTalonBuyAt = tick()
                + math.max(tonumber(TyrantConfig.DragonTalonRequirementRetry) or 180, retryDelay)
            status("Dragon Talon: missing mastery or Fire Essence requirement")
            break
        elseif typeof(buyResult) == "string" and buyResult ~= "" then
            TyrState.NextDragonTalonBuyAt = tick() + retryDelay
            status("Dragon Talon: " .. tostring(buyResult))
            break
        end

        local root = TyrRoot()
        if root and (root.Position - DRAGON_TALON_BUY_POS.Position).Magnitude > 15 then
            TyrMoveTo(DRAGON_TALON_BUY_POS, true, 30)
        end
        task.wait(0.6)
    end

    TyrState.DragonTalonBuyFailed = true
    TyrState.NextDragonTalonBuyAt = TyrState.NextDragonTalonBuyAt or (tick() + retryDelay)
    TyrState.LastDragonTalonBuyResult = lastResult
    return false
end

local function TyrEnsureWeapon()
    local hum = TyrHumanoid()
    local char = TyrCharacter()
    if not hum or not char then return nil end

    local requested = TyrFindTool(TyrantConfig.Weapon)
    if requested then
        if requested.Parent ~= char then
            hum:EquipTool(requested)
            task.wait(0.12)
        end
        return TyrFindTool(TyrantConfig.Weapon)
    end

    if TyrNormalizeName(TyrantConfig.Weapon) == TyrNormalizeName("Dragon Talon") then
        TyrBuyDragonTalon()
        requested = TyrFindTool("Dragon Talon") or TyrFindTool("DragonTalon")
        if requested then
            if requested.Parent ~= char then hum:EquipTool(requested) end
            return requested
        end
    end

    -- Kaitun Ä‘Ã£ cÃ³ logic chá»n Melee/Sword; dÃ¹ng láº¡i lÃ m fallback.
    pcall(function() module:eq() end)
    return char:FindFirstChildWhichIsA("Tool")
end

local function TyrGetAimPosition(target)
    if typeof(target) == "Vector3" then return target end
    if typeof(target) == "CFrame" then return target.Position end
    if typeof(target) == "Instance" then
        if target:IsA("BasePart") then return target.Position end
        local part = target:FindFirstChild("HumanoidRootPart") or target:FindFirstChildWhichIsA("BasePart", true)
        return part and part.Position or nil
    end
    return nil
end

local function TyrSetSkillAimTarget(target)
    getgenv().TyrantSkillAimTarget = TyrGetAimPosition(target)
end

local function TyrInstallSkillAimHook()
    if getgenv().TyrantSkillAimHookInstalled then return true end
    if type(getrawmetatable) ~= "function"
        or type(setreadonly) ~= "function"
        or type(newcclosure) ~= "function"
        or type(getnamecallmethod) ~= "function"
        or type(checkcaller) ~= "function"
    then
        warn("[K4 Tyrant] Executor lacks metamethod hook; vase skill aim may be less accurate")
        return false
    end

    local ok, err = pcall(function()
        local mt = getrawmetatable(game)
        local oldNamecall = mt.__namecall
        setreadonly(mt, false)
        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            local target = getgenv().TyrantSkillAimTarget
            if not checkcaller() and target and (method == "FireServer" or method == "InvokeServer") then
                local args = { ... }
                local changed = false
                for index = 1, #args do
                    if typeof(args[index]) == "Vector3" then
                        args[index] = target
                        changed = true
                        break
                    elseif typeof(args[index]) == "CFrame" then
                        args[index] = CFrame.new(target)
                        changed = true
                        break
                    end
                end
                if changed then return oldNamecall(self, unpack(args)) end
            end
            return oldNamecall(self, ...)
        end)
        setreadonly(mt, true)
    end)

    if ok then
        getgenv().TyrantSkillAimHookInstalled = true
        return true
    end
    warn("[K4 Tyrant] Skill aim hook failed: " .. tostring(err))
    return false
end

local TYRANT_DEFAULT_SKILL_COOLDOWNS = { Z = 6, X = 8, C = 12, V = 15, F = 10 }

local function TyrGetSkillFrame(tool, keyName)
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    local main = playerGui and playerGui:FindFirstChild("Main")
    local skills = main and main:FindFirstChild("Skills")
    if not skills or not tool then return nil end

    local toolSkills = skills:FindFirstChild(tool.Name)
        or skills:FindFirstChild(TyrantConfig.Weapon)
        or skills:FindFirstChild("Dragon Talon")
    return toolSkills and toolSkills:FindFirstChild(keyName) or nil
end

local function TyrSkillReady(tool, keyName)
    if tick() < (TyrState.InternalSkillReadyAt[keyName] or 0) then return false end
    local frame = TyrGetSkillFrame(tool, keyName)
    if not frame then return true end
    local cooldown = frame:FindFirstChild("Cooldown")
    if cooldown and cooldown:IsA("GuiObject") then
        return cooldown.Size.X.Scale <= 0.015 and cooldown.Size.X.Offset <= 2
    end
    return true
end

local function TyrMarkSkillUsed(keyName)
    TyrState.InternalSkillReadyAt[keyName] = tick() + (TYRANT_DEFAULT_SKILL_COOLDOWNS[keyName] or 7)
end

local function TyrSendSkillKey(keyName, isDown)
    local keyCode = Enum.KeyCode[keyName]
    local ok = pcall(function()
        VirtualInputManager:SendKeyEvent(isDown, keyName, false, game)
    end)
    if not ok and keyCode then
        ok = pcall(function()
            VirtualInputManager:SendKeyEvent(isDown, keyCode, false, game)
        end)
    end
    return ok
end

local function TyrCastVaseSkill(target, keyName)
    if not TyrantConfig.UseSkillsForVases or TyrState.SkillInputBusy or not TyrState.Farming then return false end
    keyName = string.upper(tostring(keyName or ""))
    if keyName ~= "Z" and keyName ~= "X" and keyName ~= "C" then return false end

    local targetPosition = TyrGetAimPosition(target)
    local tool = TyrEnsureWeapon()
    local char = TyrCharacter()
    local hum = TyrHumanoid()
    local root = TyrRoot()
    if not targetPosition or not tool or not char or tool.Parent ~= char or not hum or hum.Health <= 0 or not root then
        return false
    end
    if not TyrSkillReady(tool, keyName) then return false end

    TyrState.SkillInputBusy = true
    TyrState.SkillCasting = true
    TyrSetSkillAimTarget(targetPosition)
    TyrInstallSkillAimHook()

    local bodyClip = root:FindFirstChild("BodyClip")
    local previousForce = bodyClip and bodyClip.MaxForce
    local previousAutoClick = AttackConfig.AutoClickEnabled
    local keyDown = false
    local success = false
    AttackConfig.AutoClickEnabled = false

    local ok, err = pcall(function()
        hum.Sit = false
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero

        local flatLook = Vector3.new(targetPosition.X, root.Position.Y, targetPosition.Z)
        if (flatLook - root.Position).Magnitude > 0.1 then
            root.CFrame = CFrame.lookAt(root.Position, flatLook)
        end

        if bodyClip then
            bodyClip.MaxForce = Vector3.zero
            bodyClip.Velocity = Vector3.zero
        end

        task.wait(0.08)
        keyDown = TyrSendSkillKey(keyName, true)
        if not keyDown then return end
        task.wait(VASE_SKILL_HOLD_TIME[keyName] or TyrantConfig.VaseSkillHoldTime)
        TyrSendSkillKey(keyName, false)
        keyDown = false
        TyrMarkSkillUsed(keyName)
        task.wait(VASE_SKILL_RELEASE_WAIT[keyName] or TyrantConfig.VaseSkillReleaseDelay)
        success = true
    end)

    if keyDown then TyrSendSkillKey(keyName, false) end
    TyrSetSkillAimTarget(nil)
    if TyrState.Farming then
        AttackConfig.AutoClickEnabled = previousAutoClick
    end

    if bodyClip and bodyClip.Parent then
        bodyClip.MaxForce = previousForce or Vector3.new(100000, 100000, 100000)
        bodyClip.Velocity = Vector3.zero
    end

    TyrState.SkillCasting = false
    TyrState.SkillInputBusy = false

    if not ok then
        warn("[K4 Tyrant] Vase skill " .. tostring(keyName) .. " failed: " .. tostring(err))
        return false
    end
    if success then task.wait(TyrantConfig.VaseSkillRetryDelay) end
    return success
end

local function TyrStaticVaseAimPosition(target)
    return target.CFrame.Position + Vector3.new(0, 0.75, 0)
end

local function TyrStaticVaseStandCFrame(target, keyName)
    local vasePosition = target.CFrame.Position
    local aimPosition = TyrStaticVaseAimPosition(target)
    local inward = Vector3.new(STATIC_VASE_CENTER.X - vasePosition.X, 0, STATIC_VASE_CENTER.Z - vasePosition.Z)
    inward = inward.Magnitude < 0.1 and Vector3.new(0, 0, -1) or inward.Unit

    local standPosition
    if keyName == "Z" then
        standPosition = vasePosition + inward * 92 + Vector3.new(0, 3.0, 0)
    elseif keyName == "C" then
        standPosition = vasePosition + Vector3.new(0, 3.2, 0)
    else
        standPosition = vasePosition + inward * 14 + Vector3.new(0, 3.0, 0)
    end

    if keyName == "C" then
        return CFrame.lookAt(standPosition, standPosition + inward * 8)
    end
    return CFrame.lookAt(standPosition, aimPosition)
end

local function TyrWaitForVaseSkill(preferredKey, timeout)
    local started = tick()
    while TyrState.Farming and not TyrFindTyrant() and TyrAreEyesReady() do
        local tool = TyrEnsureWeapon()
        if tool then
            preferredKey = string.upper(tostring(preferredKey or ""))
            if preferredKey ~= "" and TyrSkillReady(tool, preferredKey) then return preferredKey end
            for _, keyName in ipairs(TyrantConfig.VaseSkillKeys) do
                keyName = string.upper(tostring(keyName))
                if TyrSkillReady(tool, keyName) then return keyName end
            end
        end
        if timeout and tick() - started >= timeout then return nil end
        task.wait(0.10)
    end
    return nil
end

local function TyrAttackStaticVase(target, preferredKey)
    if not target or not TyrState.Farming or TyrFindTyrant() or not TyrAreEyesReady() then return false end
    local keyName = TyrWaitForVaseSkill(preferredKey, 15)
    if not keyName then return false end

    local aimPosition = TyrStaticVaseAimPosition(target)
    local standCF = TyrStaticVaseStandCFrame(target, keyName)
    status(string.format("Tyrant vase %s | %s", target.Name, keyName))

    TyrMoveTo(standCF, true, TyrantConfig.VaseTargetTimeout)
    local root = TyrRoot()
    if not root then return false end

    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    task.wait(0.10)

    TyrSetSkillAimTarget(aimPosition)
    local used = TyrCastVaseSkill(aimPosition, keyName)
    TyrSetSkillAimTarget(nil)
    return used
end

local function TyrTargetCFrame(targetPart, height)
    local position = targetPart.Position + Vector3.new(0, height, 0)
    return CFrame.new(position, targetPart.Position)
end

local function TyrFarmEnemy(enemy, isBoss)
    local hum = enemy and enemy:FindFirstChildOfClass("Humanoid")
    local enemyRoot = enemy and enemy:FindFirstChild("HumanoidRootPart")
    if not hum or not enemyRoot or hum.Health <= 0 then return end

    TyrState.CurrentTarget = enemy
    TyrState.CurrentMode = isBoss and "BOSS" or "MOBS"
    local stuckAt = tick()
    local previousHealth = hum.Health
    local height = isBoss and TyrantConfig.BossHeight or TyrantConfig.FarmHeight

    -- Register the moving enemy once. Heartbeat reads enemyRoot every frame and
    -- continuously matches its velocity, so attacks keep sticking to the target.
    module:topos(TyrTargetCFrame(enemyRoot, height), {
        Speed = tonumber(TyrantConfig.FarmFollowSpeed) or 300,
        Follow = true,
        FollowPart = enemyRoot,
        FollowOffset = Vector3.new(0, height, 0),
        FollowDeadZone = tonumber(TyrantConfig.FarmFollowDeadZone) or 1.25,
        FollowGain = tonumber(TyrantConfig.FarmFollowGain) or 7.5,
        PredictionTime = tonumber(TyrantConfig.FarmFollowPrediction) or 0.08,
        TargetVelocityCap = tonumber(TyrantConfig.FarmTargetVelocityCap) or 95,
        TargetResponsiveness = isBoss and 20 or 24,
        Acceleration = isBoss and 720 or 820,
        Deceleration = isBoss and 880 or 980
    })

    while TyrState.Farming and enemy.Parent and hum.Parent and enemyRoot.Parent and hum.Health > 0 do
        local root = TyrRoot()
        local playerHum = TyrHumanoid()
        if not root or not playerHum or playerHum.Health <= 0 then break end

        TyrEnsureWeapon()
        if TyrantConfig.AutoBuso then pcall(function() module:haki() end) end

        -- Rebind only if the character respawned or the movement controller was
        -- interrupted. It is not recreated every frame.
        if not activeMoveEnabled
            or activeMoveRoot ~= root
            or activeMoveOptions.FollowPart ~= enemyRoot
        then
            module:topos(TyrTargetCFrame(enemyRoot, height), {
                Speed = tonumber(TyrantConfig.FarmFollowSpeed) or 300,
                Follow = true,
                FollowPart = enemyRoot,
                FollowOffset = Vector3.new(0, height, 0),
                FollowDeadZone = tonumber(TyrantConfig.FarmFollowDeadZone) or 1.25,
                FollowGain = tonumber(TyrantConfig.FarmFollowGain) or 7.5,
                PredictionTime = tonumber(TyrantConfig.FarmFollowPrediction) or 0.08,
                TargetVelocityCap = tonumber(TyrantConfig.FarmTargetVelocityCap) or 95,
                TargetResponsiveness = isBoss and 20 or 24,
                Acceleration = isBoss and 720 or 820,
                Deceleration = isBoss and 880 or 980
            })
        end

        pcall(function() AttackInstance:Attack() end)

        if hum.Health < previousHealth then
            previousHealth = hum.Health
            stuckAt = tick()
        elseif tick() - stuckAt > 15 then
            -- Reset only the accumulated velocity; keep the same follow target.
            activeMoveVelocity = Vector3.zero
            pcall(function() AttackInstance:Attack() end)
            stuckAt = tick()
        end
        task.wait(0.05)
    end

    K4CancelMoveTween()
    TyrState.CurrentTarget = nil
end

local function TyrBreakVases()
    TyrState.CurrentMode = "VASES"
    TyrState.CurrentTarget = nil
    status("Tyrant: 4/4 eyes red - breaking 12 vases with Z/X/C")

    local entryCF = CFrame.lookAt(STATIC_VASE_CENTER + Vector3.new(0, 8, 0), STATIC_VASE_CENTER)
    TyrMoveTo(entryCF, true, 20)
    task.wait(0.25)

    local pass = 0
    local keys = TyrantConfig.VaseSkillKeys
    while TyrState.Farming and TyrAreEyesReady() and not TyrFindTyrant() do
        pass = pass + 1
        for index, target in ipairs(STATIC_VASE_TARGETS) do
            if not TyrState.Farming or TyrFindTyrant() or not TyrAreEyesReady() then return end
            local preferredIndex = ((index + pass - 2) % #keys) + 1
            local preferredKey = string.upper(tostring(keys[preferredIndex]))
            TyrAttackStaticVase(target, preferredKey)
            task.wait(0.08)
        end
        status("Tyrant: scanned all 12 vases, pass " .. tostring(pass))
        task.wait(0.35)
    end
end

local function TyrTweenMobRoot(enemyRoot, targetCF)
    if not enemyRoot or not enemyRoot.Parent then return end
    local oldTween = TyrState.BringTweens[enemyRoot]
    if oldTween then pcall(function() oldTween:Cancel() end) end

    local distance = (targetCF.Position - enemyRoot.Position).Magnitude
    if distance <= 3 then
        enemyRoot.CFrame = targetCF
        TyrState.BringTweens[enemyRoot] = nil
        return
    end

    local duration = distance / math.max(tonumber(TyrantConfig.BringTweenSpeed) or 300, 1)
    local tween = TweenService:Create(
        enemyRoot,
        TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
        { CFrame = targetCF }
    )
    TyrState.BringTweens[enemyRoot] = tween
    tween.Completed:Connect(function()
        if TyrState.BringTweens[enemyRoot] == tween then TyrState.BringTweens[enemyRoot] = nil end
    end)
    tween:Play()
end

local function TyrSetupBringMobs()
    -- DÃ¹ng gom quÃ¡i chung tá»« kaituncdkmm, khÃ´ng dÃ¹ng tween gom riÃªng cá»§a báº£n Tyrant ná»¯a.
    if TyrState.BringStarted or not TyrantConfig.BringMobs then return end
    TyrState.BringStarted = true
    task.spawn(function()
        while task.wait(TyrantConfig.BringMobInterval or 0.15) do
            if TyrState.Farming and AttackConfig and AttackConfig.BringMobs ~= false then
                local target = TyrState.CurrentTarget or TyrFindTyrant(false) or TyrGetNearestTikiMob()
                if target
                    and target.Parent
                    and not TyrIsTyrant(target)
                    and target:FindFirstChild("HumanoidRootPart")
                then
                    pcall(GrabMobs, tostring(target.Name or ""))
                end
            end
        end
    end)
end

local tyrantFarmingActive = false
local tyrantFarmingTask = nil
local tyrantSetupDone = false
local function TyrEnableKaitunAttackForFarm()
    if TyrState.PreviousAttackConfig then return end
    TyrState.PreviousAttackConfig = {
        AttackDistance = AttackConfig.AttackDistance,
        AttackMobs = AttackConfig.AttackMobs,
        AttackPlayers = AttackConfig.AttackPlayers,
        AutoClickEnabled = AttackConfig.AutoClickEnabled,
        BringMobs = AttackConfig.BringMobs,
        PreGrabDistance = AttackConfig.PreGrabDistance
    }
    AttackConfig.AttackDistance = tonumber(TyrantConfig.AttackDistance) or 105
    AttackConfig.AttackMobs = true
    AttackConfig.AttackPlayers = false
    AttackConfig.AutoClickEnabled = true
    AttackConfig.BringMobs = true
    AttackConfig.PreGrabDistance = tonumber(TyrantConfig.BringDistance) or 1500
end

local function TyrRestoreKaitunAttack()
    local previous = TyrState.PreviousAttackConfig
    if not previous then return end
    AttackConfig.AttackDistance = previous.AttackDistance
    AttackConfig.AttackMobs = previous.AttackMobs
    AttackConfig.AttackPlayers = previous.AttackPlayers
    AttackConfig.AutoClickEnabled = previous.AutoClickEnabled
    AttackConfig.BringMobs = previous.BringMobs
    AttackConfig.PreGrabDistance = previous.PreGrabDistance
    TyrState.PreviousAttackConfig = nil
end

local function TyrCancelBringTweens()
    for object, tween in pairs(TyrState.BringTweens) do
        pcall(function() tween:Cancel() end)
        TyrState.BringTweens[object] = nil
    end
end

local function stopTyrantFarming()
    tyrantFarmingActive = false
    TyrState.Farming = false
    TyrState.CurrentMode = "IDLE"
    TyrState.CurrentTarget = nil
    TyrSetSkillAimTarget(nil)
    TyrCancelBringTweens()
    TyrRestoreKaitunAttack()
end

local function startTyrantFarming()
    if tyrantFarmingTask then return end

    tyrantFarmingActive = true
    TyrState.Farming = true
    TyrState.DragonTalonBuyFailed = false
    TyrState.LastDragonTalonBuyAttempt = 0
    TyrState.NextDragonTalonBuyAt = nil
    TyrEnableKaitunAttackForFarm()

    if not tyrantSetupDone then
        tyrantSetupDone = true
        TyrBindEyeWatchers(true)
        TyrSetupBringMobs()
        TyrInstallSkillAimHook()
    end

    tyrantFarmingTask = task.spawn(function()
        if TyrNormalizeName(TyrantConfig.Weapon) == TyrNormalizeName("Dragon Talon") then
            TyrBuyDragonTalon()
        end

        while tyrantFarmingActive and TyrState.Farming do

            local playerHum = TyrHumanoid()
            if not playerHum or playerHum.Health <= 0 then
                status("Tyrant: waiting character respawn")
                task.wait(1)
            else
                if TyrantConfig.AutoBuso then pcall(function() module:haki() end) end
                local moonSuffix = ""
                local tyrant = TyrFindTyrant()

                if tyrant then
                    status("Fighting Tyrant" .. moonSuffix)
                    TyrFarmEnemy(tyrant, true)
                elseif TyrAreEyesReady() then
                    TyrBreakVases()
                else
                    TyrState.CurrentMode = "MOBS"
                    TyrState.CurrentTarget = nil
                    local activeEyes = TyrGetEyeProgress()
                    status(string.format("Farming Tiki NPC | eyes %d/4%s", activeEyes, moonSuffix))
                    TyrEnsureWeapon()
                    local mob = TyrGetNearestTikiMob()
                    if mob then
                        TyrFarmEnemy(mob, false)
                    else
                        TyrMoveTo(TIKI_CENTER, true, 25)
                        task.wait(0.8)
                    end
                end
            end
            task.wait(0.05)
        end

        tyrantFarmingActive = false
        TyrState.Farming = false
        TyrState.CurrentMode = "IDLE"
        TyrState.CurrentTarget = nil
        TyrSetSkillAimTarget(nil)
        TyrCancelBringTweens()
        TyrRestoreKaitunAttack()
        tyrantFarmingTask = nil
    end)
end

    return {
        Start = function() startTyrantFarming() end,
        Stop = stopTyrantFarming,
        IsActive = function() return tyrantFarmingActive end,
        GetStatus = function()
            local target = TyrState.CurrentTarget
            return {
                Active = tyrantFarmingActive,
                Mode = TyrState.CurrentMode,
                Target = target and target.Name or "None",
                Eyes = TyrGetEyeProgress(),
                EyesReady = TyrAreEyesReady(),
                BossFound = TyrFindTyrant(false) ~= nil
            }
        end
    }
end)()

-- Random fruit + automatically store physical fruits.
-- BFNEW now uses the gacha type as the second Cousin argument instead of "Buy".
local K4FruitStatus = "Waiting"
local K4LastFruit = "None"
local K4NextFruitRollAt = 0
local K4FruitStoreAttemptAt = setmetatable({}, { __mode = "k" })
local K4BannerClient = nil
local K4GachaWindowController = nil
local K4SpinnerController = nil

pcall(function()
    K4BannerClient = require(ReplicatedStorage.Controllers.BannerClient)
end)
pcall(function()
    K4GachaWindowController = require(
        ReplicatedStorage:WaitForChild("Controllers")
            :WaitForChild("UI")
            :WaitForChild("GachaWindow")
    )
end)
pcall(function()
    K4SpinnerController = require(
        ReplicatedStorage:WaitForChild("Controllers")
            :WaitForChild("UI")
            :WaitForChild("Spinner")
    )
end)

local function K4CloseRandomFruitGui()
    local function closeOnce()
        if K4SpinnerController
            and type(K4SpinnerController.Close) == "function"
        then
            pcall(function()
                K4SpinnerController:Close()
            end)
        end

        if K4GachaWindowController
            and type(K4GachaWindowController.Close) == "function"
        then
            pcall(function()
                K4GachaWindowController:Close(true)
            end)
        end

        local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
        local gachaGui = playerGui and playerGui:FindFirstChild("GachaWindow")
        if gachaGui and gachaGui:IsA("ScreenGui") then
            gachaGui.Enabled = false
        end
    end

    -- Spinner/Gacha callbacks can reopen or finish one frame later, so close it
    -- again after the result animation has settled.
    closeOnce()
    task.delay(0.35, closeOnce)
    task.delay(1.25, closeOnce)
end

local function K4GetFruitOriginalName(item)
    if not item or not item:IsA("Tool") then return nil end
    local originalName = item:GetAttribute("OriginalName")
    if type(originalName) == "string" and originalName ~= "" then
        return originalName
    end
    return nil
end

local function K4IsPhysicalFruit(item)
    if not item or not item:IsA("Tool") then return false end
    if K4GetFruitOriginalName(item) then return true end

    local eatRemote = item:FindFirstChild("EatRemote", true)
    local name = string.lower(tostring(item.Name))
    local tooltip = string.lower(tostring(item.ToolTip or ""))
    return eatRemote ~= nil
        and (string.find(name, "fruit", 1, true) ~= nil
            or string.find(tooltip, "blox fruit", 1, true) ~= nil)
end

local function K4StoreFruit(item)
    if not K4IsPhysicalFruit(item) then return false end
    if tick() - (K4FruitStoreAttemptAt[item] or 0) < 60 then return false end
    K4FruitStoreAttemptAt[item] = tick()

    local originalName = K4GetFruitOriginalName(item) or item.Name
    K4FruitStatus = "Storing " .. tostring(item.Name)

    local character, humanoid = K4GetCharacterParts()
    if item.Parent == LocalPlayer:FindFirstChild("Backpack") and character and humanoid then
        pcall(function()
            humanoid:EquipTool(item)
        end)
        task.wait(0.12)
    end

    local ok, result = pcall(function()
        return CommF_:InvokeServer("StoreFruit", originalName, item)
    end)

    if ok and result == true then
        K4LastFruit = tostring(item.Name)
        K4FruitStatus = "Stored"
        return true
    end

    if ok and typeof(result) == "number" then
        K4FruitStatus = "Storage full (capacity " .. tostring(result) .. ")"
    elseif ok then
        K4FruitStatus = "Store rejected"
    else
        K4FruitStatus = "Store failed"
        warn("[K4 Fruit] StoreFruit failed: " .. tostring(result))
    end

    return false
end

local function K4StoreAllFruits()
    local storedAny = false
    local containers = {
        LocalPlayer.Character,
        LocalPlayer:FindFirstChild("Backpack")
    }

    for _, container in ipairs(containers) do
        if container then
            for _, item in ipairs(container:GetChildren()) do
                if K4IsPhysicalFruit(item) and K4StoreFruit(item) then
                    storedAny = true
                    task.wait(0.20)
                end
            end
        end
    end
    return storedAny
end

local function K4GetRandomFruitBoxType()
    local boxType = "DLCBoxData"
    if K4BannerClient and type(K4BannerClient.TryGetBannerItemIfActiveAsync) == "function" then
        local ok, bannerItem = pcall(K4BannerClient.TryGetBannerItemIfActiveAsync)
        if ok
            and type(bannerItem) == "table"
            and type(bannerItem.BoxName) == "string"
            and bannerItem.BoxName ~= ""
        then
            boxType = bannerItem.BoxName
        end
    end
    return boxType
end

local function K4WaitForRolledFruit(beforeTools, timeout)
    local started = tick()
    repeat
        local containers = {
            LocalPlayer.Character,
            LocalPlayer:FindFirstChild("Backpack")
        }
        for _, container in ipairs(containers) do
            if container then
                for _, item in ipairs(container:GetChildren()) do
                    if K4IsPhysicalFruit(item) and not beforeTools[item] then
                        return item
                    end
                end
            end
        end
        task.wait(0.15)
    until tick() - started >= (tonumber(timeout) or 8)
    return nil
end

local function K4RollRandomFruit()
    pcall(K4StoreAllFruits)

    local boxType = K4GetRandomFruitBoxType()
    K4FruitStatus = "Checking random fruit"

    local checkOk, price, level, cost = pcall(function()
        return CommF_:InvokeServer("Cousin", "Check", boxType)
    end)
    if not checkOk then
        K4FruitStatus = "Check failed"
        warn("[K4 Fruit] Cousin Check failed: " .. tostring(price))
        return false, 60
    end

    if tonumber(level) and tonumber(level) < 50 then
        K4FruitStatus = "Level 50 required"
        return false, 300
    end

    local timeOk, timeResult = pcall(function()
        return CommF_:InvokeServer("Cousin", "CheckTime", boxType)
    end)
    if not timeOk then
        K4FruitStatus = "Cooldown check failed"
        return false, 60
    end
    if timeResult ~= true then
        K4FruitStatus = tostring(timeResult or "Random fruit on cooldown")
        return false, 60
    end

    local canBuyOk, canBuy = pcall(function()
        return CommF_:InvokeServer("Cousin", "CheckCanBuyType", boxType)
    end)
    if canBuyOk and canBuy == false then
        K4FruitStatus = "Not enough money"
        return false, 60
    end

    local beforeTools = {}
    for _, container in ipairs({ LocalPlayer.Character, LocalPlayer:FindFirstChild("Backpack") }) do
        if container then
            for _, item in ipairs(container:GetChildren()) do
                if item:IsA("Tool") then beforeTools[item] = true end
            end
        end
    end

    K4FruitStatus = "Rolling random fruit"
    local rollOk, resultCode, resultInfo = pcall(function()
        return CommF_:InvokeServer("Cousin", boxType)
    end)
    if not rollOk then
        K4FruitStatus = "Roll failed"
        K4CloseRandomFruitGui()
        warn("[K4 Fruit] Random fruit call failed: " .. tostring(resultCode))
        return false, 60
    end

    if resultCode == 1 then
        local rolledFruit = K4WaitForRolledFruit(beforeTools, 8)
        if rolledFruit then
            K4LastFruit = tostring(rolledFruit.Name)
            K4FruitStatus = "Rolled " .. tostring(rolledFruit.Name)
            task.wait(0.15)
            K4StoreFruit(rolledFruit)
        else
            K4FruitStatus = "Roll succeeded - waiting fruit"
            pcall(K4StoreAllFruits)
        end
        K4CloseRandomFruitGui()
        return true, 7200
    end

    if resultCode == 2 then
        K4FruitStatus = "Need more money: " .. tostring(resultInfo or cost or price or "?")
        K4CloseRandomFruitGui()
        return false, 60
    end

    if resultCode == 3 then
        K4FruitStatus = "Level requirement not met"
        K4CloseRandomFruitGui()
        return false, 300
    end

    if typeof(resultCode) == "table" and typeof(resultCode[2]) == "string" then
        K4FruitStatus = resultCode[2]
    else
        K4FruitStatus = "Roll rejected: " .. tostring(resultCode)
    end
    K4CloseRandomFruitGui()
    return false, 60
end

task.spawn(function()
    while task.wait(3) do
        pcall(K4StoreAllFruits)
    end
end)

task.spawn(function()
    while LocalPlayer.Team == nil or not LocalPlayer.Character do
        K4FruitStatus = "Waiting for character/team"
        task.wait(1)
    end
    task.wait(2)

    while true do
        K4NextFruitRollAt = tick()
        local callOk, rolled, retryDelay = pcall(K4RollRandomFruit)
        if not callOk then
            K4FruitStatus = "Fruit loop error"
            warn("[K4 Fruit] Loop error: " .. tostring(rolled))
            retryDelay = 60
        end

        retryDelay = math.max(tonumber(retryDelay) or (rolled and 7200 or 60), 15)
        K4NextFruitRollAt = tick() + retryDelay
        while tick() < K4NextFruitRollAt do
            task.wait(1)
        end
    end
end)

-- Left-side Tyrant progress dashboard.
local function K4CreateTyrantDashboard()
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    local oldGui = playerGui:FindFirstChild("K4TyrantDashboard")
    if oldGui then oldGui:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "K4TyrantDashboard"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = playerGui

    local panel = Instance.new("Frame")
    panel.Name = "Panel"
    panel.AnchorPoint = Vector2.new(0, 0.5)
    panel.Position = UDim2.new(0, 12, 0.5, 0)
    panel.Size = UDim2.fromOffset(280, 330)
    panel.BackgroundColor3 = Color3.fromRGB(16, 19, 27)
    panel.BackgroundTransparency = 0.08
    panel.BorderSizePixel = 0
    panel.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = panel

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(205, 69, 82)
    stroke.Transparency = 0.2
    stroke.Thickness = 1.5
    stroke.Parent = panel

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Position = UDim2.fromOffset(14, 10)
    title.Size = UDim2.new(1, -28, 0, 30)
    title.Font = Enum.Font.GothamBold
    title.Text = "TYRANT FARM"
    title.TextColor3 = Color3.fromRGB(255, 102, 115)
    title.TextSize = 18
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = panel

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "Status"
    statusLabel.BackgroundTransparency = 1
    statusLabel.Position = UDim2.fromOffset(14, 48)
    statusLabel.Size = UDim2.new(1, -28, 1, -60)
    statusLabel.Font = Enum.Font.Code
    statusLabel.TextColor3 = Color3.fromRGB(232, 235, 244)
    statusLabel.TextSize = 15
    statusLabel.TextWrapped = true
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.TextYAlignment = Enum.TextYAlignment.Top
    statusLabel.Parent = panel

    task.spawn(function()
        while gui.Parent do
            local ok, state = pcall(K4TyrantFarmController.GetStatus)
            if ok and state then
                local fragments = 0
                local data = LocalPlayer:FindFirstChild("Data")
                local value = data and data:FindFirstChild("Fragments")
                if value then fragments = tonumber(value.Value) or 0 end

                local phase
                if state.BossFound or state.Mode == "BOSS" then
                    phase = "FARMING TYRANT"
                elseif state.Mode == "VASES" or state.EyesReady then
                    phase = "BREAKING 12 VASES"
                elseif state.Mode == "MOBS" then
                    phase = "FARMING TIKI MOBS"
                else
                    phase = state.Active and "SEARCHING" or "STOPPED"
                end

                local completionRace = K4GetCurrentRace() or "loading"
                local completionTargetRace = K4GetRaceTarget()
                local completionTargetFragments = K4GetFragmentTarget()

                statusLabel.Text = string.format(
                    "Fragments : %s / %s\nRace      : %s\nRace target: %s\nRace ready : %s\nCompleted  : %s\n\nStatus    : %s\nPhase     : %s\nEyes      : %d/4\nBoss      : %s\nTarget    : %s\n\nFruit     : %s\nLast fruit: %s\nNext roll : %02d:%02d:%02d",
                    tostring(fragments),
                    tostring(completionTargetFragments or "invalid"),
                    tostring(completionRace),
                    K4RaceDisplay(completionTargetRace),
                    tostring((not completionTargetRace) or completionRace == completionTargetRace),
                    K4Completion.Completed and "YES" or "NO",
                    state.Active and "RUNNING" or "STOPPED",
                    phase,
                    tonumber(state.Eyes) or 0,
                    state.BossFound and "FOUND" or "NOT SPAWNED",
                    tostring(state.Target),
                    K4FruitStatus,
                    K4LastFruit,
                    math.floor(math.max(0, K4NextFruitRollAt - tick()) / 3600),
                    math.floor((math.max(0, K4NextFruitRollAt - tick()) % 3600) / 60),
                    math.floor(math.max(0, K4NextFruitRollAt - tick()) % 60)
                )
            end
            task.wait(0.25)
        end
    end)
end

local function K4EnsureConfiguredTeam()
    if LocalPlayer.Team ~= nil then return true end

    local wantedTeam = tostring(TyrantConfig.Team or "Pirates")
    status("Joining team: " .. wantedTeam)

    local started = tick()
    repeat
        pcall(function()
            CommF_:InvokeServer("SetTeam2", wantedTeam)
        end)
        if LocalPlayer.Team ~= nil then return true end

        pcall(function()
            CommF_:InvokeServer("SetTeam", wantedTeam)
        end)
        task.wait(0.5)
    until LocalPlayer.Team ~= nil or tick() - started >= 20

    return LocalPlayer.Team ~= nil
end

local function K4EnsureSea3()
    local mapName = tostring(Workspace:GetAttribute("MAP") or "")
    local isSea3Place = game.PlaceId == 100117331123089 or game.PlaceId == 7449423635
    if mapName == "Sea3" or isSea3Place then
        return true
    end

    status("Tyrant requires Sea 3: travelling to Zou")
    pcall(function()
        CommF_:InvokeServer("TravelZou")
    end)
    return false
end

if K4EnsureSea3() then
    pcall(K4EnsureConfiguredTeam)
    K4StartFragmentRaceController()
    K4CreateTyrantDashboard()
    K4TyrantFarmController.Start()
end
