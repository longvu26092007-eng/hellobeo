--[[
    Ghoul.lua  -  Auto Get Ghoul Race (Blox Fruits)
    Flow:
      1. Wait Game Load
      2. Choose Team / Load Team
      3. Check Sea & travel to Sea 2
      4. Check material (Ectoplasm >= 100). Neu thieu -> farm Ectoplasm (ra thuyen Ship)
      5. Du nguyen lieu -> fetch API cursedcaptain, join theo jobid (10 sv gan nhat, cach nhau 1.5s)
         de detect + farm boss Cursed Captain
      6. Trong luc farm boss -> lien tuc check "Hellfire Torch" de nop / doi race

    Tham khao: V3.txt (gom quai + FastAttack), Kaitun_Cyborg (wait load + choose team),
               PullLever_BanGoc (fetch API + join theo jobid), script goc (entrance + doi race)
--]]

--==================================================================
--  CONFIG
--==================================================================
getgenv().GhoulConfig = getgenv().GhoulConfig or {
    ["Team"]                = "Pirates",     -- Team chon khi load
    ["Ectoplasm Needed"]    = 100,           -- so Ectoplasm can co truoc khi di boss
    ["Boss API"]            = "http://fi12.bot-hosting.cloud:20112/api/name=cursedcaptain",
    ["Boss Name"]           = "Cursed Captain",
    ["Fetch Count"]         = 10,            -- lay 10 sv gan nhat moi lan fetch
    ["Hop Delay"]           = 1.5,           -- moi sv cach nhau 1.5s
    ["Detect Timeout"]      = 20,            -- sau khi join, cho toi da bao lau de detect boss (s)
    ["Api Freshness"]       = 120,           -- chi lay sv co timestamp/update trong vong 120s (neu API co field)
    ["Torch Mode"]          = 1,             -- 1 = Melee, 2 = Fruit  (khi doi race co "1 Hellfire Torch")
    ["Ectoplasm MPos"]      = CFrame.new(911.35827636719, 125.95812988281, 33159.5390625),
    ["Ship Entrance"]       = Vector3.new(923.21252441406, 126.9760055542, 32852.83203125),
    ["Ship Mobs"]           = {"Ship Deckhand", "Ship Engineer", "Ship Steward", "Ship Officer"},
    ["Boss Pos"]            = CFrame.new(916.928589, 181.092773, 33422),
    -- Boss Cursed Captain o thuyen ma Sea 2, dung chung requestEntrance voi thuyen Ship
    ["Boss Entrance"]       = Vector3.new(923.21252441406, 126.9760055542, 32852.83203125),
    ["Boss Near Dist"]      = 250,   -- <= gia tri nay coi la da gan boss (tween thang)
    ["Boss Entrance Dist"]  = 2000,  -- >= gia tri nay thi request entrance ra thuyen truoc
}

local CFG = getgenv().GhoulConfig

--==================================================================
--  STEP 1: WAIT GAME LOAD  (tham khao Kaitun_Cyborg / V3)
--==================================================================
repeat task.wait(0.5) until game:IsLoaded() and time() >= 10

cloneref = cloneref or clonereference or function(x) return x end
isnetworkowner = isnetworkowner or isNetworkOwner or function() return true end
workspace = cloneref(workspace) or cloneref(Workspace)
    or (getrenv and (getrenv().workspace or getrenv().Workspace))
    or cloneref(game:GetService("Workspace"))

local Services = setmetatable({}, {__index = function(self, name)
    local s, c = pcall(function() return cloneref(game:GetService(name)) end)
    if s then rawset(self, name, c) return c else error("Invalid Service: " .. tostring(name)) end
end})

local RunService        = Services.RunService
local TweenService      = Services.TweenService
local HttpService       = Services.HttpService
local Players           = Services.Players
local ReplicatedStorage = Services.ReplicatedStorage
local Lighting          = Services.Lighting
local StarterGui        = Services.StarterGui
local TeleportService   = Services.TeleportService
local CoreGui           = Services.CoreGui

local LocalPlayer = Players.LocalPlayer
local COMMF_ = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_")

local Character, Humanoid, HumanoidRootPart
local function BindChar(c)
    Character = c
    Humanoid = c:WaitForChild("Humanoid")
    HumanoidRootPart = c:WaitForChild("HumanoidRootPart")
end
LocalPlayer.CharacterAdded:Connect(BindChar)
if LocalPlayer.Character then BindChar(LocalPlayer.Character) end

pcall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "Ghoul.lua", Text = "Loading... please wait", Duration = 5,
    })
end)

if not game:IsLoaded() or workspace.DistributedGameTime <= 10 then
    pcall(function() task.wait(math.max(0, 10 - workspace.DistributedGameTime)) end)
end

--==================================================================
--  SIMPLE STATUS UI
--==================================================================
local StatusLabel
local function MakeUI()
    pcall(function()
        local old = CoreGui:FindFirstChild("GhoulStatus")
        if old then old:Destroy() end
        local gui = Instance.new("ScreenGui")
        gui.Name = "GhoulStatus"
        gui.ResetOnSpawn = false
        gui.DisplayOrder = 999999
        gui.Parent = (gethui and gethui()) or CoreGui
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 360, 0, 34)
        frame.Position = UDim2.new(0.5, -180, 0, 8)
        frame.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
        frame.BackgroundTransparency = 0.15
        frame.BorderSizePixel = 0
        frame.Parent = gui
        Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
        StatusLabel = Instance.new("TextLabel")
        StatusLabel.Size = UDim2.new(1, -12, 1, 0)
        StatusLabel.Position = UDim2.new(0, 6, 0, 0)
        StatusLabel.BackgroundTransparency = 1
        StatusLabel.Font = Enum.Font.GothamMedium
        StatusLabel.TextSize = 13
        StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
        StatusLabel.TextColor3 = Color3.fromRGB(120, 255, 160)
        StatusLabel.Text = "Ghoul: starting..."
        StatusLabel.Parent = frame
    end)
end
MakeUI()

local function SetStatus(t)
    t = tostring(t or "")
    print("[Ghoul] " .. t)
    if StatusLabel then StatusLabel.Text = "Ghoul: " .. t end
end

--==================================================================
--  STEP 2: CHOOSE TEAM / LOAD TEAM  (tham khao Kaitun_Cyborg)
--==================================================================
local function ChooseTeam()
    if LocalPlayer.Team then return true end
    SetStatus("Choosing team " .. tostring(CFG.Team))
    -- cho loading screen bien mat
    if LocalPlayer.PlayerGui:FindFirstChild("LoadingScreen") then
        repeat task.wait(1) until not LocalPlayer.PlayerGui:FindFirstChild("LoadingScreen")
    end
    for _ = 1, 30 do
        if LocalPlayer.Team then break end
        xpcall(function()
            COMMF_:InvokeServer("SetTeam", CFG.Team)
        end, function()
            pcall(function()
                firesignal(LocalPlayer.PlayerGui["Main (minimal)"].ChooseTeam.Container[CFG.Team])
            end)
        end)
        task.wait(2)
    end
    return LocalPlayer.Team ~= nil
end
ChooseTeam()

-- cho spawn nhan vat xong
repeat task.wait(1) until Character
    and Character:FindFirstChild("HumanoidRootPart")
    and Character:FindFirstChildWhichIsA("Humanoid")
    and Character:IsDescendantOf(workspace.Characters)
SetStatus("Team loaded, character ready")

--==================================================================
--  CORE HELPERS  (gom quai + attack, tham khao V3.txt)
--==================================================================
local plr = LocalPlayer

local function IsDied(v)
    local ok, r = pcall(function()
        if not v then return true end
        local h = v:FindFirstChildWhichIsA("Humanoid")
        local hrp = v:FindFirstChild("HumanoidRootPart")
        if not h or not hrp then return true end
        return h.Health <= 0
    end)
    return (not ok) or r
end

-- Remote attack (encrypted) - tham khao V3.txt
local remoteAttack, idremote
local seed = 0
pcall(function() seed = ReplicatedStorage.Modules.Net.seed:InvokeServer() end)
task.spawn(function()
    pcall(function()
        for _, v in next, ({ReplicatedStorage.Util, ReplicatedStorage.Common, ReplicatedStorage.Remotes, ReplicatedStorage.Assets, ReplicatedStorage.FX}) do
            for _, n in next, v:GetChildren() do
                if n:IsA("RemoteEvent") and n:GetAttribute("Id") then
                    remoteAttack, idremote = n, n:GetAttribute("Id")
                end
            end
            v.ChildAdded:Connect(function(n)
                if n:IsA("RemoteEvent") and n:GetAttribute("Id") then
                    remoteAttack, idremote = n, n:GetAttribute("Id")
                end
            end)
        end
    end)
end)

local lastEquip = tick()
local function EquipWeapon(v)
    if tick() - lastEquip <= 0.2 then return end
    lastEquip = tick()
    if not Character then return end
    local tool = Character:FindFirstChildWhichIsA("Tool")
    if tool and tool.ToolTip == v then return end
    for _, x in next, LocalPlayer.Backpack:GetChildren() do
        if x:IsA("Tool") and x.ToolTip == v then
            Humanoid:EquipTool(x)
            return
        end
    end
    -- fallback: equip bat ky tool nao (de FastAttack chay)
    if not Character:FindFirstChildWhichIsA("Tool") then
        for _, x in next, LocalPlayer.Backpack:GetChildren() do
            if x:IsA("Tool") then Humanoid:EquipTool(x) return end
        end
    end
end

local function EquipAnyTool()
    if Character and Character:FindFirstChildWhichIsA("Tool") then return end
    for _, x in next, LocalPlayer.Backpack:GetChildren() do
        if x:IsA("Tool") then Humanoid:EquipTool(x) return end
    end
end

local lastCallFA = tick()
local function FastAttack(x)
    if not HumanoidRootPart or not Character:FindFirstChildWhichIsA("Humanoid")
        or Character.Humanoid.Health <= 0 or not Character:FindFirstChildWhichIsA("Tool") then return end
    if tick() - lastCallFA <= 0.01 then return end
    local t = {}
    for _, u in next, {workspace.Characters, workspace.Enemies} do
        for _, e in next, u:GetChildren() do
            local h = e:FindFirstChildWhichIsA("Humanoid")
            local hrp = e:FindFirstChild("HumanoidRootPart")
            if e ~= Character and (x and e.Name == x or not x) and h and hrp
                and not IsDied(e) and (hrp.Position - HumanoidRootPart.Position).Magnitude <= 65 then
                t[#t + 1] = e
            end
        end
    end
    if #t == 0 then return end
    local ok = pcall(function()
        local n = ReplicatedStorage.Modules.Net
        local h = {[2] = {}}
        for i = 1, #t do
            local v = t[i]
            local part = v:FindFirstChild("Head") or v:FindFirstChild("HumanoidRootPart")
            if not h[1] then h[1] = part end
            h[2][#h[2] + 1] = {v, part}
        end
        n:FindFirstChild("RE/RegisterAttack"):FireServer()
        n:FindFirstChild("RE/RegisterHit"):FireServer(unpack(h))
        cloneref(remoteAttack):FireServer(string.gsub("RE/RegisterHit", ".", function(c)
            return string.char(bit32.bxor(string.byte(c), math.floor(workspace:GetServerTimeNow() / 10 % 10) + 1))
        end), bit32.bxor(idremote + 909090, seed * 2), unpack(h))
    end)
    lastCallFA = tick()
    return ok
end

-- Tween teleport (tham khao V3.txt, rut gon)
local connection, tween, pathPart, isTweening = nil, nil, nil, false
local function Tween(targetCFrame)
    if not Character or not Character:FindFirstChildWhichIsA("Humanoid") or Character.Humanoid.Health <= 0 then
        pcall(function() if pathPart then pathPart:Destroy() end end)
        connection, tween, pathPart, isTweening = nil, nil, nil, false
        return
    end
    if targetCFrame == false then
        if tween then pcall(function() tween:Cancel() end) tween = nil end
        if connection then connection:Disconnect() connection = nil end
        if pathPart then pathPart:Destroy() pathPart = nil end
        isTweening = false
        return
    end
    if typeof(targetCFrame) ~= "CFrame" then targetCFrame = CFrame.new(targetCFrame) end
    if isTweening then return end
    local root = Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local dist = (targetCFrame.Position - root.Position).Magnitude
    if dist <= 200 then
        if connection then connection:Disconnect() connection = nil end
        if tween then pcall(function() tween:Cancel() end) tween = nil end
        if pathPart then pathPart:Destroy() pathPart = nil end
        root.CFrame = targetCFrame * CFrame.new(0, 5, 0)
        isTweening = false
        return
    end
    isTweening = true
    pathPart = Instance.new("Part", workspace)
    pathPart.Name = "GhoulTweenGhost"
    pathPart.Transparency = 1
    pathPart.Anchored = true
    pathPart.CanCollide = false
    pathPart.CFrame = root.CFrame
    pathPart.Size = Vector3.new(50, 50, 50)
    tween = TweenService:Create(pathPart, TweenInfo.new(dist / 250, Enum.EasingStyle.Linear), {CFrame = targetCFrame * CFrame.new(0, 5, 0)})
    connection = RunService.Heartbeat:Connect(function()
        if Character and pathPart then
            local r = Character:FindFirstChild("HumanoidRootPart")
            if r then r.CFrame = pathPart.CFrame * CFrame.new(0, 5, 0) end
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

-- Teleport instant (dung cho farm)
local function TP(cf)
    if typeof(cf) == "Vector3" then cf = CFrame.new(cf) end
    if Character and Character:FindFirstChild("HumanoidRootPart") then
        Character.HumanoidRootPart.CFrame = cf
    end
end

-- Tim quai theo ten (workspace.Enemies + ReplicatedStorage)
local function FindEnemy(...)
    local args = {...}
    for _, container in next, {workspace.Enemies, ReplicatedStorage} do
        for _, m in next, container:GetChildren() do
            if m:IsA("Model") and not IsDied(m) then
                for _, n in next, args do
                    if m.Name == n then return m end
                end
            end
        end
    end
    return nil
end

--==================================================================
--  SEA / MATERIAL HELPERS
--==================================================================
local function GetSea()
    local ok, n = pcall(function()
        return tonumber(workspace:GetAttribute("MAP"):match("%d+"))
    end)
    return ok and n or nil
end

local function GetEctoplasm()
    local ok, n = pcall(function()
        return tonumber(COMMF_:InvokeServer("Ectoplasm", "Check")) or 0
    end)
    return ok and (n or 0) or 0
end

local function HasHellfireTorch()
    -- check backpack + character + inventory
    for _, cont in next, {LocalPlayer.Backpack, Character} do
        if cont then
            for _, x in next, cont:GetChildren() do
                if x:IsA("Tool") and (x.Name == "Hellfire Torch" or x.Name:find("Hellfire")) then
                    return true
                end
            end
        end
    end
    local ok, inv = pcall(function() return COMMF_:InvokeServer("getInventory") end)
    if ok and type(inv) == "table" then
        for _, v in pairs(inv) do
            if v.Name == "Hellfire Torch" then return true end
        end
    end
    return false
end

--==================================================================
--  STEP 3: CHECK SEA & TRAVEL TO SEA 2
--==================================================================
local function GoToSea2()
    local sea = GetSea()
    if sea == 2 then return true end
    SetStatus("At Sea " .. tostring(sea) .. " -> travel to Sea 2")
    -- Sea1 -> Sea2 : TravelDressrosa ; Sea3 -> Sea2 : TravelDressrosa cung duoc (di qua Cafe)
    for _ = 1, 30 do
        sea = GetSea()
        if sea == 2 then break end
        pcall(function()
            if sea == 1 then
                COMMF_:InvokeServer("TravelDressrosa")
            elseif sea == 3 then
                COMMF_:InvokeServer("TravelDressrosa")
            end
        end)
        task.wait(4)
    end
    return GetSea() == 2
end

--==================================================================
--  STEP 4: FARM ECTOPLASM  (ra thuyen Ship, tham khao script goc)
--==================================================================
local farmingMaterial = false
local function RequestShipEntrance()
    -- neu o xa thi request vao thuyen
    if not HumanoidRootPart then return end
    local d = (HumanoidRootPart.Position - CFG["Ship Entrance"]).Magnitude
    if d >= 18000 then
        pcall(function() COMMF_:InvokeServer("requestEntrance", CFG["Ship Entrance"]) end)
        task.wait(1)
    end
end

local function FarmEctoplasm()
    -- chay den khi du Ectoplasm
    farmingMaterial = true
    SetStatus("Farming Ectoplasm...")
    while farmingMaterial do
        if GetEctoplasm() >= CFG["Ectoplasm Needed"] then break end
        pcall(function()
            RequestShipEntrance()
            EquipAnyTool()
            local mob = FindEnemy(table.unpack(CFG["Ship Mobs"]))
            if mob and mob:FindFirstChild("HumanoidRootPart") then
                -- gom + danh
                TP(mob.HumanoidRootPart.CFrame * CFrame.new(0, 15, 0))
                EquipWeapon(Character and Character:FindFirstChildWhichIsA("Tool") and Character:FindFirstChildWhichIsA("Tool").ToolTip or "")
                FastAttack(mob.Name)
            else
                -- khong thay quai -> ve vi tri farm
                TP(CFG["Ectoplasm MPos"])
                RequestShipEntrance()
            end
        end)
        task.wait(0.1)
    end
    farmingMaterial = false
    SetStatus("Ectoplasm ready: " .. tostring(GetEctoplasm()))
end

--==================================================================
--  STEP 5: FETCH API + JOIN JOBID  (tham khao PullLever_BanGoc)
--==================================================================
local function HttpRequest(opts)
    local req = request or http_request or (syn and syn.request) or (fluxus and fluxus.request)
    if type(req) ~= "function" then return false, "executor khong ho tro request" end
    local lastErr
    for attempt = 1, 3 do
        local ok, res = pcall(function() return req(opts) end)
        if ok and type(res) == "table" then return true, res end
        lastErr = res
        task.wait(1.5)
    end
    return false, lastErr
end

-- Lay danh sach server tu API, uu tien server moi nhat, tra ve toi da Fetch Count jobid
local function FetchBossServers()
    SetStatus("Fetching boss servers from API...")
    local ok, res = HttpRequest({
        Url = CFG["Boss API"],
        Method = "GET",
        Headers = { ["Accept"] = "application/json", ["User-Agent"] = "Roblox/WinInet" },
    })
    if not ok then
        SetStatus("API request failed")
        return {}
    end
    local body = res.Body or res.body or ""
    local data = nil
    pcall(function() data = HttpService:JSONDecode(body) end)
    if type(data) ~= "table" then
        SetStatus("API decode failed")
        return {}
    end

    local list = data.data or data.servers or data
    if type(list) ~= "table" then return {} end

    local currentPlace = tonumber(game.PlaceId)
    local servers = {}
    local skippedOtherPlace = 0
    for _, v in ipairs(list) do
        if type(v) == "table" then
            local jobId = v.jobid or v.JobId or v.jobId or v.id
            local placeId = tonumber(v.placeid or v.PlaceId or v.placeId or v.place)
            local ts = tonumber(v.timestamp or v.time or v.updated_at)
            -- CHI lay server TRUNG dung PlaceId dang dung.
            -- API tra ve lan lon nhieu placeid (vd 79091703265657 la place khac -> teleport se bi
            -- Error 773 restricted). Bat buoc placeId == currentPlace.
            if jobId and placeId and placeId == currentPlace then
                table.insert(servers, {
                    JobId = tostring(jobId),
                    PlaceId = placeId,
                    Players = tonumber(v.player or v.players or v.Count or 0) or 0,
                    Timestamp = ts,
                })
            elseif jobId and placeId and placeId ~= currentPlace then
                skippedOtherPlace = skippedOtherPlace + 1
            end
        end
    end
    if skippedOtherPlace > 0 then
        print("[Ghoul] Skipped " .. skippedOtherPlace .. " server(s) with different PlaceId (current=" .. tostring(currentPlace) .. ")")
    end

    -- API tra ve theo thu tu, cac phan tu cuoi thuong la moi nhat -> uu tien cuoi mang
    -- neu co timestamp thi sort giam dan theo timestamp
    local hasTs = false
    for _, s in ipairs(servers) do if s.Timestamp then hasTs = true break end end
    if hasTs then
        table.sort(servers, function(a, b) return (a.Timestamp or 0) > (b.Timestamp or 0) end)
    else
        -- dao nguoc de lay cai moi (thuong o cuoi payload)
        local rev = {}
        for i = #servers, 1, -1 do rev[#rev + 1] = servers[i] end
        servers = rev
    end

    -- loai jobid dang o
    local out = {}
    for _, s in ipairs(servers) do
        if tostring(s.JobId) ~= tostring(game.JobId) then
            table.insert(out, s)
            if #out >= CFG["Fetch Count"] then break end
        end
    end
    SetStatus("API: got " .. tostring(#out) .. " fresh server(s)")
    return out
end

local function JoinJobId(jobId, placeId)
    if not jobId or tostring(jobId) == "" then return false end
    -- dang o dung server nay roi -> bo qua (tranh join lai chinh minh)
    if tostring(jobId) == tostring(game.JobId) then
        SetStatus("Already in this jobid -> skip")
        return false
    end

    -- CACH CHUAN: join bang __ServerBrowser cua Blox Fruits.
    -- No teleport TRONG place hien tai (giu nguyen PlaceId dang dung),
    -- chi doi jobid -> tranh Error 773 (place restricted) khi dung placeid la tu API.
    local sb = ReplicatedStorage:FindFirstChild("__ServerBrowser")
    if sb then
        local ok, err = pcall(function()
            sb:InvokeServer("teleport", tostring(jobId))
        end)
        if ok then
            return true
        end
        SetStatus("ServerBrowser join failed: " .. tostring(err))
    end

    -- Fallback: chi teleport bang placeid khi trung place hien tai (tranh 773).
    -- Neu placeid tu API khac place dang dung -> KHONG teleport (se bi restricted).
    local cur = tonumber(game.PlaceId)
    if placeId and tonumber(placeId) == cur then
        pcall(function()
            TeleportService:TeleportToPlaceInstance(cur, tostring(jobId), LocalPlayer)
        end)
        return true
    end

    SetStatus("No safe join method for this jobid -> skip")
    return false
end

-- detect boss: boss co trong workspace.Enemies hoac ReplicatedStorage
local function BossPresent()
    return FindEnemy(CFG["Boss Name"]) ~= nil
        or (workspace.Enemies:FindFirstChild(CFG["Boss Name"]) ~= nil)
        or (ReplicatedStorage:FindFirstChild(CFG["Boss Name"]) ~= nil)
end

--==================================================================
--  STEP 6: FARM BOSS + CHECK HELLFIRE TORCH -> DOI RACE
--==================================================================
local raceDone = false
local busyFarming = false  -- khoa tranh 2 vong lap farm boss chay cung luc

-- doi race Ghoul: nop Hellfire Torch. Torch Mode 1 = Melee, 2 = Fruit
local function TrySubmitTorch()
    if not HasHellfireTorch() then return false end
    SetStatus("Got Hellfire Torch! Submitting (mode " .. tostring(CFG["Torch Mode"]) .. ")")
    local mode = tostring(CFG["Torch Mode"]) -- "1" melee / "2" fruit
    local ok = pcall(function()
        -- buoc doi race: BuyCheck roi Change (nhu script goc), truyen so luong = 1 torch
        COMMF_:InvokeServer("Hellfire Torch", "BuyCheck", mode)
        task.wait(0.5)
        COMMF_:InvokeServer("Hellfire Torch", "Change", mode)
    end)
    task.wait(1)
    -- xac nhan da thanh Ghoul
    local isGhoul = false
    pcall(function() isGhoul = (plr.Data.Race.Value == "Ghoul") end)
    return isGhoul
end

-- Tien toi gan boss: check khoang cach -> xa thi requestEntrance ra thuyen -> tween toi.
-- Tra ve true khi da o gan (trong tam danh), false khi con dang di chuyen.
local function ApproachBoss(bossPart)
    if not HumanoidRootPart then return false end
    local targetCF = bossPart and bossPart.CFrame or CFG["Boss Pos"]
    local dist = (HumanoidRootPart.Position - targetCF.Position).Magnitude

    -- da gan -> tween sat vao (khong TP thang)
    if dist <= CFG["Boss Near Dist"] then
        Tween(targetCF * CFrame.new(3, 8, 2))
        return true
    end

    -- con xa -> neu qua xa thi request entrance ra dung thuyen gan boss truoc
    if dist >= CFG["Boss Entrance Dist"] then
        SetStatus(("Far from boss (%d) -> requestEntrance"):format(math.floor(dist)))
        pcall(function() COMMF_:InvokeServer("requestEntrance", CFG["Boss Entrance"]) end)
        task.wait(1)
    end

    -- tween tien toi boss (khong TP)
    SetStatus(("Tween to boss (%d studs)"):format(math.floor(dist)))
    Tween(targetCF * CFrame.new(3, 8, 2))
    return false
end

-- vong lap farm boss trong 1 server: detect -> danh; song song check torch
local function _FarmBossBody()
    local deadline = tick() + CFG["Detect Timeout"]
    -- cho detect boss
    SetStatus("Detecting boss in server...")
    while tick() < deadline do
        if BossPresent() then break end
        -- trong luc cho, van kiem tra torch (phong khi da co san)
        if HasHellfireTorch() then
            if TrySubmitTorch() then raceDone = true return "DONE" end
        end
        task.wait(0.5)
    end

    if not BossPresent() then
        SetStatus("No boss here -> next server")
        return "NO_BOSS"
    end

    -- co boss -> farm den khi chet / co torch / mat boss
    SetStatus("Boss found! Farming " .. CFG["Boss Name"])
    while true do
        local boss = FindEnemy(CFG["Boss Name"])
        if not boss then
            -- boss chua spawn / dang o storage -> tien lai gan cho spawn bang requestEntrance + tween
            local stor = ReplicatedStorage:FindFirstChild(CFG["Boss Name"])
            local waitPart = stor and stor:FindFirstChild("HumanoidRootPart")
            ApproachBoss(waitPart)   -- xa thi requestEntrance + tween, khong TP thang
            -- neu boss bien mat han va ko con o storage -> coi nhu het
            if not BossPresent() then
                SetStatus("Boss gone")
                break
            end
        else
            if IsDied(boss) then
                SetStatus("Boss killed")
                break
            end
            EquipAnyTool()
            local bhrp = boss:FindFirstChild("HumanoidRootPart")
            -- CHECK gan boss chua: chua gan -> requestEntrance + tween toi; gan roi -> danh
            local near = ApproachBoss(bhrp)
            if near then
                FastAttack(CFG["Boss Name"])
            end
        end

        -- STEP 6: check torch lien tuc trong khi farm
        if HasHellfireTorch() then
            if TrySubmitTorch() then
                raceDone = true
                return "DONE"
            end
        end
        task.wait(0.1)
    end

    -- sau khi boss chet, van check torch 1 lan (drop co the roi vao inv)
    task.wait(1)
    if HasHellfireTorch() then
        if TrySubmitTorch() then raceDone = true return "DONE" end
    end
    return "KILLED"
end

local function FarmBossInServer()
    if busyFarming then return "BUSY" end
    busyFarming = true
    -- boc pcall + reset khoa du co loi hay return giua chung
    local ok, result = pcall(_FarmBossBody)
    busyFarming = false
    if not ok then
        SetStatus("Farm boss error: " .. tostring(result))
        return "ERROR"
    end
    return result
end

--==================================================================
--  MAIN FLOW
--==================================================================
task.spawn(function()
    -- da la Ghoul roi thi thoi
    pcall(function()
        if plr.Data and plr.Data.Race and plr.Data.Race.Value == "Ghoul" then
            raceDone = true
        end
    end)
    if raceDone then
        SetStatus("Already Ghoul. Done.")
        return
    end

    -- STEP 3
    GoToSea2()

    -- STEP 4
    if GetEctoplasm() < CFG["Ectoplasm Needed"] then
        FarmEctoplasm()
    else
        SetStatus("Ectoplasm enough (" .. tostring(GetEctoplasm()) .. ")")
    end

    -- STEP 5 + 6: detect+farm boss, check torch. Fetch server CHI khi server hien tai KHONG co boss.
    while not raceDone do
        -- dam bao van du nguyen lieu (co the bi tru khi thu doi)
        if GetEctoplasm() < CFG["Ectoplasm Needed"] then
            SetStatus("Ectoplasm dropped below needed -> refarm")
            GoToSea2()
            FarmEctoplasm()
        end

        -- CHECK BOSS TRUOC KHI FETCH: neu server dang dung da co boss -> farm luon, khoi hop.
        if BossPresent() then
            SetStatus("Boss present in CURRENT server -> farm now (no fetch)")
            local r = FarmBossInServer()
            if r == "DONE" or raceDone then break end
            -- farm xong (boss chet / mat) -> vong lai check tiep, neu het boss se fetch
        end

        -- server hien tai khong co boss -> fetch danh sach server de hop di tim
        if raceDone then break end
        local servers = FetchBossServers()
        if #servers == 0 then
            SetStatus("No servers from API, retry in 3s")
            task.wait(3)
        else
            -- spam join tung server, moi server cach nhau Hop Delay(1.5s)
            -- neu detect duoc boss -> nhay vao FarmBossInServer (chay tai server hien tai sau khi teleport)
            -- Luu y: sau teleport script se reload -> can persist qua queue_on_teleport
            for i, s in ipairs(servers) do
                if raceDone then break end
                SetStatus(("Join server %d/%d (players %d)"):format(i, #servers, s.Players or 0))
                JoinJobId(s.JobId, s.PlaceId)
                task.wait(CFG["Hop Delay"])
            end
            -- neu het 10 server ma van chua roi khoi (khong teleport duoc) -> fetch lai
            SetStatus("Fetched 10 servers done, re-fetch")
            task.wait(2)
        end
    end

    SetStatus("=== GHOUL RACE DONE ===")
    pcall(function()
        StarterGui:SetCore("SendNotification", { Title = "Ghoul.lua", Text = "Race Ghoul completed!", Duration = 8 })
    end)
end)

--==================================================================
--  PERSIST QUA TELEPORT: sau khi teleport vao server moi, script chay lai
--  se tu detect boss + farm ngay. Dung queue_on_teleport de re-exec.
--==================================================================
local function GetSource()
    -- co gang lay lai chinh script nay de chay tiep sau teleport
    return nil
end

-- Neu executor ho tro queue_on_teleport_execute thi tu chay lai script sau khi hop
local qtp = (syn and syn.queue_on_teleport)
    or queue_on_teleport
    or (fluxus and fluxus.queue_on_teleport)
    or queueonteleport

-- Khi vao server moi (sau JoinJobId), chay 1 detector nhe de farm boss ngay.
-- (Chay ngay trong phien nay - vi teleport se reset, phan nay chi co tac dung
--  neu ban dan script bang loadstring co queue_on_teleport tu ben ngoai.)
task.spawn(function()
    -- detector song song: bat cu khi nao thay boss trong server hien tai -> farm luon
    while not raceDone do
        task.wait(1)
        if not farmingMaterial and BossPresent() and GetEctoplasm() >= CFG["Ectoplasm Needed"] then
            local r = FarmBossInServer()
            if r == "DONE" then raceDone = true end
        end
    end
end)

--[[
  GHI CHU QUAN TRONG:
  - De script tu chay lai sau moi lan teleport (server hop), ban nen nap script bang link
    va dung queue_on_teleport o file loader ben ngoai, vi du:

        local url = "PASTE_RAW_LINK_Ghoul.lua"
        local src = game:HttpGet(url)
        if syn and syn.queue_on_teleport then syn.queue_on_teleport(src)
        elseif queue_on_teleport then queue_on_teleport(src) end
        loadstring(src)()

    Nhu vay sau khi JoinJobId teleport sang server moi, script se tu exec lai,
    detector se detect boss va farm ngay. Neu server khong co boss -> flow lai
    fetch 10 server moi va tiep tuc hop.

  - Torch Mode: 1 = Melee, 2 = Fruit. Doi trong getgenv().GhoulConfig["Torch Mode"].
  - Remote doi race "Hellfire Torch" theo cach script goc dung ("BuyCheck" + "Change").
    Neu game cap nhat ten remote/arg khac, chinh trong ham TrySubmitTorch().
--]]
