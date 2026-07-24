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
    ["Team"]                = "Marines",     -- Team chon khi load
    ["Ectoplasm Needed"]    = 100,           -- so Ectoplasm can co truoc khi di boss
    ["Boss API"]            = "http://fi12.bot-hosting.cloud:20112/api/name=cursedcaptain",
    ["Boss Name"]           = "Cursed Captain",
    ["Fetch Count"]         = 10,            -- lay 10 sv gan nhat moi lan fetch
    ["Hop Delay"]           = 1.5,           -- moi sv cach nhau 1.5s
    ["Detect Timeout"]      = 20,            -- sau khi join, cho toi da bao lau de detect boss (s)
    ["Api Freshness"]       = 120,           -- chi lay sv co timestamp/update trong vong 120s (neu API co field)
    ["Torch Mode"]          = 1,             -- 1 = Melee, 2 = Fruit (build sau khi thanh Ghoul)
    ["Ghoul Race Id"]       = 4,             -- id race Ghoul dung cho remote Ectoplasm/Change (script goc dung 4)
    ["Race NPC Keywords"]   = {"experim", "ghoul", "ecto"}, -- tu khoa ten NPC doi race Ghoul (match "Experimic"/"Experiment"...)
    ["Race NPC Pos"]        = nil,           -- toa do NPC (Vector3/CFrame). nil = tu quet trong workspace
    ["Race NPC Dist"]       = 12,            -- coi la "da dung gan NPC" khi trong khoang cach nay
    ["Attack Weapon"]       = "",            -- ten/ToolTip melee de equip khi danh boss ("" = equip tool bat ky)
    ["Ectoplasm MPos"]      = CFrame.new(911.35827636719, 125.95812988281, 33159.5390625),
    ["Ship Entrance"]       = Vector3.new(923.21252441406, 126.9760055542, 32852.83203125),
    -- TAT CA deu o tren Cursed Ship: NPC doi race + quai Ectoplasm + boss Cursed Captain.
    -- Chua o tren thuyen -> tu requestEntrance("Ship Entrance") de len.
    ["Ship Center"]         = Vector3.new(911.35827636719, 125.95812988281, 33159.5390625), -- tam thuyen (=MPos) de do khoang cach
    ["Ship Radius"]         = 3000,  -- <= ban kinh nay coi la "da o tren/gan Cursed Ship"; xa hon -> entrance len
    ["Ship Mobs"]           = {"Ship Deckhand", "Ship Engineer", "Ship Steward", "Ship Officer"},
    ["Boss Pos"]            = CFrame.new(916.928589, 181.092773, 33422),
    -- Boss Cursed Captain o thuyen ma Sea 2, dung chung requestEntrance voi thuyen Ship
    ["Boss Entrance"]       = Vector3.new(923.21252441406, 126.9760055542, 32852.83203125),
    ["Boss Near Dist"]      = 250,   -- <= gia tri nay coi la da gan boss (tween thang)
    ["Boss Entrance Dist"]  = 2000,  -- >= gia tri nay thi request entrance ra thuyen truoc
    ["Hover Height"]        = 18,    -- do cao hover tren dau boss (studs) khi da gan -> dung yen danh
    ["Hover Lock Dist"]     = 40,    -- <= gia tri nay thi bat che do "lam do" (pin CFrame, khong tween nua)
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
-- forward-declare (dinh nghia sau khi co HoverLock/Tween/EquipMelee)
local ResetMovement           -- huy hover+tween khi respawn
local ReEquipMeleeNow         -- ep cam lai melee ngay
local farmingBoss = false     -- true khi dang o vong danh boss (cho equip-keeper biet)
-- Nho ten melee luc moi vao (user xac nhan luc do cam chuan) -> sau die ep cam lai dung cai nay.
-- Uu tien CFG["Attack Weapon"] neu user set; khong thi tu dong lay tu tay luc dau.
local RememberedMelee = nil
local function BindChar(c)
    Character = c
    Humanoid = c:WaitForChild("Humanoid")
    HumanoidRootPart = c:WaitForChild("HumanoidRootPart")
    -- RESPAWN: huy khoa hover/tween cu (tranh giat/keo ve cho chet),
    -- roi cam lai melee ngay (fix loi chet xong khong tu cam vu khi de danh tiep)
    task.spawn(function()
        if ResetMovement then pcall(ResetMovement) end
        task.wait(0.5)  -- cho character on dinh
        if ReEquipMeleeNow then pcall(ReEquipMeleeNow) end
    end)
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
--  STOP FLAG: tat TAT CA func (nut Stop tren UI hoac getgenv().GHOUL_STOP=true).
--  Moi vong lap trong script deu check ShouldStop() -> thoat sach, dung bay/danh.
--==================================================================
getgenv().GHOUL_STOP = getgenv().GHOUL_STOP or false
local function ShouldStop()
    return getgenv().GHOUL_STOP == true
end
-- forward-declare: dinh nghia day du sau khi co HoverLock/Tween (xem phia duoi).
local StopEverything = function() end  -- se duoc gan lai

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
        -- chua cho nut Stop ben phai (rong 70px)
        StatusLabel.Size = UDim2.new(1, -84, 1, 0)
        StatusLabel.Position = UDim2.new(0, 6, 0, 0)
        StatusLabel.BackgroundTransparency = 1
        StatusLabel.Font = Enum.Font.GothamMedium
        StatusLabel.TextSize = 13
        StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
        StatusLabel.TextColor3 = Color3.fromRGB(120, 255, 160)
        StatusLabel.Text = "Ghoul: starting..."
        StatusLabel.Parent = frame

        -- NUT STOP: bam de tat tat ca func
        local stopBtn = Instance.new("TextButton")
        stopBtn.Size = UDim2.new(0, 72, 0, 26)
        stopBtn.Position = UDim2.new(1, -78, 0.5, -13)
        stopBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        stopBtn.BorderSizePixel = 0
        stopBtn.Font = Enum.Font.GothamBold
        stopBtn.TextSize = 13
        stopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        stopBtn.Text = "STOP"
        stopBtn.AutoButtonColor = true
        stopBtn.Parent = frame
        Instance.new("UICorner", stopBtn).CornerRadius = UDim.new(0, 6)
        stopBtn.MouseButton1Click:Connect(function()
            pcall(StopEverything)
        end)
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

-- GHI NHO MELEE LUC MOI VAO: user xac nhan luc dau tay cam melee chuan.
-- Chup lai ten tool dang cam (khong phai Hellfire Torch) de sau khi die ep cam lai dung cai nay.
-- Neu user da set CFG["Attack Weapon"] thi uu tien cai do (WantedMeleeName xu ly).
task.spawn(function()
    -- doi 1 chut cho backpack/character on dinh roi chup
    for _ = 1, 10 do
        if RememberedMelee then break end
        local held = Character and Character:FindFirstChildWhichIsA("Tool")
        if held and not (held.Name == "Hellfire Torch" or (held.Name and held.Name:find("Hellfire"))) then
            RememberedMelee = held.Name
            SetStatus("Remembered melee: " .. tostring(RememberedMelee))
            break
        end
        task.wait(0.5)
    end
end)

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

-- Equip MELEE de danh boss. Goi lien tuc trong vong farm vi sau khi boss chet
-- (hoac respawn) game hay bo trang bi / doi slot -> phai cam lai.
--
-- CACH NHAN DIEN MELEE (theo V3.txt): trong Blox Fruits moi fighting-style deu co
--   tool.ToolTip == "Melee"   (con Name la ten rieng: "Sharkman Karate", "Godhuman"...)
-- -> chi can tim tool co ToolTip == "Melee" la chac chan dung melee. Dang tin hon
--    Name/attribute "Sub" (khong on dinh -> truoc day chet xong khong nhan ra melee).
-- Neu user set CFG["Attack Weapon"] thi uu tien cai do (match Name hoac ToolTip).

-- co phai Hellfire Torch khong (de KHONG bao gio cam no lam vu khi danh boss)
local function IsTorch(t)
    return t and (t.Name == "Hellfire Torch" or (t.Name and t.Name:find("Hellfire")))
end

-- tool nay co phai melee/fighting-style khong (ToolTip == "Melee")
local function IsMeleeTool(t)
    if not t or not t:IsA("Tool") or IsTorch(t) then return false end
    return t.ToolTip == "Melee"
end

-- Tool dang cam co "dung y muon" khong (theo config, hoac la melee ToolTip)
local function IsWantedTool(t)
    if not t or IsTorch(t) then return false end
    local want = tostring(CFG["Attack Weapon"] or "")
    if want ~= "" then
        return t.Name == want or t.ToolTip == want
    end
    -- khong chi dinh -> melee ToolTip la dung; neu chua co melee nao thi chap nhan ten da nho
    if IsMeleeTool(t) then return true end
    if RememberedMelee and t.Name == RememberedMelee then return true end
    return false
end

-- Tim tool muc tieu trong Backpack + Character
local function FindWantedTool()
    local want = tostring(CFG["Attack Weapon"] or "")
    -- pass 1: uu tien khop chinh xac (config, hoac melee ToolTip, hoac ten da nho)
    for _, cont in next, {Character, LocalPlayer.Backpack} do
        if cont then
            for _, x in next, cont:GetChildren() do
                if x:IsA("Tool") and not IsTorch(x) then
                    if want ~= "" then
                        if x.Name == want or x.ToolTip == want then return x end
                    else
                        if IsMeleeTool(x) then return x end
                    end
                end
            end
        end
    end
    -- pass 2 (chi khi config rong): dung ten melee da nho
    if want == "" and RememberedMelee then
        for _, cont in next, {Character, LocalPlayer.Backpack} do
            if cont then
                for _, x in next, cont:GetChildren() do
                    if x:IsA("Tool") and not IsTorch(x) and x.Name == RememberedMelee then return x end
                end
            end
        end
    end
    return nil
end

local function EquipMelee()
    if not Character or not Humanoid then return end
    local cur = Character:FindFirstChildWhichIsA("Tool")

    -- dang cam dung roi -> thoi
    if IsWantedTool(cur) then return end

    -- tim melee dung y va cam lai
    local tool = FindWantedTool()
    if tool then
        pcall(function() Humanoid:EquipTool(tool) end)
        return
    end

    -- fallback cuoi cung: neu tay dang trong -> cam bat ky tool nao TRU torch
    if not cur then
        for _, x in next, LocalPlayer.Backpack:GetChildren() do
            if x:IsA("Tool") and not IsTorch(x) then
                pcall(function() Humanoid:EquipTool(x) end)
                return
            end
        end
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

--==================================================================
--  HOVER LOCK: "lam do player" khi hover tren dau boss.
--  Thay vi lien tuc tween/TP moi frame (gay giat len giat xuong), ta:
--   - pin root.CFrame ve dung 1 vi tri co dinh moi Heartbeat
--   - zero velocity + Sit=false de trong luc/knockback khong keo player
--  -> player dung im tuyet doi, khong rung.
--  HoverLock(cf)  : bat/khoa tai vi tri cf (vi tri se giu nguyen den khi doi/tat)
--  HoverLock(nil) : tat khoa (tra lai dieu khien binh thuong)
--==================================================================
local hoverConn, hoverCF = nil, nil
local function HoverLock(cf)
    -- tat khoa
    if cf == nil then
        if hoverConn then hoverConn:Disconnect() hoverConn = nil end
        hoverCF = nil
        return
    end
    if typeof(cf) == "Vector3" then cf = CFrame.new(cf) end
    hoverCF = cf  -- cap nhat diem giu (co the goi lai voi cf moi khi boss di chuyen)

    if hoverConn then return end  -- da co loop -> chi can update hoverCF o tren
    hoverConn = RunService.Heartbeat:Connect(function()
        if not hoverCF then return end
        if not Character then return end
        local root = Character:FindFirstChild("HumanoidRootPart")
        local hum = Character:FindFirstChildWhichIsA("Humanoid")
        if not root or not hum or hum.Health <= 0 then return end
        -- lam do: chong knockback/trong luc keo player -> khong giat
        pcall(function()
            hum.Sit = false
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end)
        -- pin cung vi tri (khong cong them offset moi frame -> khong rung)
        root.CFrame = hoverCF
    end)
end

-- Gan cho forward-declare o dau file (dung sau khi respawn - xem BindChar).
-- ResetMovement: huy hover + tween dang chay (tranh keo character moi ve cho chet).
ResetMovement = function()
    HoverLock(nil)
    Tween(false)
end
-- ReEquipMeleeNow: ep cam lai melee ngay (fix loi chet xong khong tu cam vu khi).
ReEquipMeleeNow = function()
    pcall(EquipMelee)
end

-- STOP ALL: tat toan bo func - nha hover/tween, huy body-mover, zero velocity.
-- Gan cho forward-declare (nut Stop tren UI + ham StopEverything goi cai nay).
StopEverything = function()
    getgenv().GHOUL_STOP = true
    pcall(function() HoverLock(nil) end)
    pcall(function() Tween(false) end)
    -- don sach cac thu keo nhan vat (neu co)
    pcall(function()
        local c = Character or LocalPlayer.Character
        local root = c and c:FindFirstChild("HumanoidRootPart")
        if root then
            for _, n in ipairs({"DracoAntiGravity", "BodyClip", "GhoulTweenGhost"}) do
                local o = root:FindFirstChild(n)
                if o then o:Destroy() end
            end
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
    end)
    SetStatus("STOPPED (all func off)")
end

-- EQUIP-KEEPER: chay nen suot phien. Khi dang danh boss (farmingBoss) -> LUON goi
-- EquipMelee. EquipMelee tu biet: dang cam dung melee -> return; dang cam sai/torch/trong
-- -> EP cam lai dung melee. Nho vay chet xong / game doi slot sai deu duoc sua ngay.
-- Fix trung: "chet xong khong tu cam melee de danh lai" (du tay van dang cam tool khac).
task.spawn(function()
    while not ShouldStop() do
        task.wait(0.3)
        if farmingBoss and Character and Humanoid and Humanoid.Health > 0 then
            pcall(EquipMelee)   -- goi vo dieu kien; EquipMelee tu no-op neu da dung
        end
    end
end)

-- Tim quai SONG theo ten. CHI tim trong workspace.Enemies.
-- KHONG scan ReplicatedStorage: trong Blox Fruits, boss (vd "Cursed Captain") co san
-- 1 model template trong RS -> neu scan RS se luon "thay boss" (false positive) gay
-- ket vong "Boss gone" ma khong bao gio fetch. Quai/boss THUC SU song luon o Enemies.
local function FindEnemy(...)
    local args = {...}
    for _, m in next, workspace.Enemies:GetChildren() do
        if m:IsA("Model") and not IsDied(m) then
            for _, n in next, args do
                if m.Name == n then return m end
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

-- Tim NPC doi race Ghoul (Experimic) tren Cursed Ship theo tu khoa ten.
-- Quet workspace.NPCs (va fallback ca workspace) tim model co ten khop keyword.
local function FindRaceNPC()
    local kws = CFG["Race NPC Keywords"] or {"experim"}
    local containers = {}
    for _, nm in ipairs({"NPCs", "Npcs", "NPC"}) do
        local f = workspace:FindFirstChild(nm)
        if f then containers[#containers + 1] = f end
    end
    if #containers == 0 then containers = {workspace} end
    for _, cont in ipairs(containers) do
        for _, m in ipairs(cont:GetChildren()) do
            if m:IsA("Model") then
                local lname = m.Name:lower()
                for _, kw in ipairs(kws) do
                    if lname:find(kw) then
                        local part = m:FindFirstChild("HumanoidRootPart")
                            or m:FindFirstChildWhichIsA("BasePart")
                        if part then return m, part end
                    end
                end
            end
        end
    end
    return nil, nil
end

-- Da o tren/gan Cursed Ship chua? (do khoang cach toi tam thuyen)
local function OnCursedShip()
    if not HumanoidRootPart then return false end
    local d = (HumanoidRootPart.Position - CFG["Ship Center"]).Magnitude
    return d <= (CFG["Ship Radius"] or 3000)
end

-- Dam bao dang o tren Cursed Ship: chua o thi requestEntrance len roi cho.
-- TAT CA (farm ecto / farm boss / doi race) deu dien ra tren thuyen nay.
local function EnsureOnCursedShip()
    if OnCursedShip() then return true end
    SetStatus("Not on Cursed Ship -> requestEntrance")
    for _ = 1, 15 do
        if ShouldStop() then return false end
        if OnCursedShip() then return true end
        pcall(function() COMMF_:InvokeServer("requestEntrance", CFG["Ship Entrance"]) end)
        task.wait(1)
        -- sau entrance thuong da o gan; neu van xa thi tween lai tam thuyen
        if not OnCursedShip() and HumanoidRootPart then
            Tween(CFrame.new(CFG["Ship Center"]) * CFrame.new(0, 12, 0))
            task.wait(0.5)
        end
    end
    return OnCursedShip()
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

-- Tien toi khu farm ecto: o xa -> requestEntrance ra thuyen Ship roi tween toi (khong TP thang).
-- Tra ve true khi da o gan (trong tam danh), false khi con dang di chuyen.
local function ApproachShip(targetCF)
    if not HumanoidRootPart then return false end
    targetCF = targetCF or CFG["Ectoplasm MPos"]
    local dist = (HumanoidRootPart.Position - targetCF.Position).Magnitude

    -- da gan -> tween sat vao
    if dist <= CFG["Boss Near Dist"] then
        Tween(targetCF * CFrame.new(0, 12, 0))
        return true
    end

    -- con xa -> qua xa thi requestEntrance ra thuyen truoc
    if dist >= CFG["Boss Entrance Dist"] then
        SetStatus(("Far from ship (%d) -> requestEntrance"):format(math.floor(dist)))
        pcall(function() COMMF_:InvokeServer("requestEntrance", CFG["Ship Entrance"]) end)
        task.wait(1)
    end

    -- tween tien toi khu farm (khong TP)
    SetStatus(("Tween to ship (%d studs)"):format(math.floor(dist)))
    Tween(targetCF * CFrame.new(0, 12, 0))
    return false
end

local function FarmEctoplasm()
    -- chay den khi du Ectoplasm
    farmingMaterial = true
    SetStatus("Farming Ectoplasm...")
    -- BAT BUOC len Cursed Ship truoc: quai Ectoplasm o ngay tren thuyen nay
    EnsureOnCursedShip()
    while farmingMaterial do
        if ShouldStop() then farmingMaterial = false break end
        if GetEctoplasm() >= CFG["Ectoplasm Needed"] then break end
        pcall(function()
            EquipMelee()   -- keeper nen cung lo, day chi de chac chan cam melee
            local mob = FindEnemy(table.unpack(CFG["Ship Mobs"]))
            if mob and mob:FindFirstChild("HumanoidRootPart") then
                -- CHECK gan quai chua: xa -> requestEntrance ra thuyen + tween; gan -> danh
                local near = ApproachShip(mob.HumanoidRootPart.CFrame)
                if near then
                    FastAttack(mob.Name)
                end
            else
                -- khong thay quai -> tien ve khu farm (xa thi entrance ra thuyen + tween)
                ApproachShip(CFG["Ectoplasm MPos"])
            end
        end)
        task.wait()   -- moi frame (~60/s) thay vi 0.1s (10/s) -> danh nhanh hon nhieu
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

-- Boss CO THUC SU trong server hien tai chua? Chi tin workspace.Enemies (boss song).
-- KHONG check ReplicatedStorage (template luon ton tai -> false positive).
local function BossPresent()
    local m = workspace.Enemies:FindFirstChild(CFG["Boss Name"])
    if m and not IsDied(m) then return true end
    return FindEnemy(CFG["Boss Name"]) ~= nil
end

--==================================================================
--  STEP 6: FARM BOSS + CHECK HELLFIRE TORCH -> DOI RACE
--==================================================================
local raceDone = false
local busyFarming = false  -- khoa tranh 2 vong lap farm boss chay cung luc

-- Da la Ghoul chua?
local function IsGhoul()
    local ok, r = pcall(function() return plr.Data.Race.Value == "Ghoul" end)
    return ok and r
end

-- Mua/doi race Ghoul V1.
-- Hellfire Torch la vat MO KHOA (drop tu boss) -> co no roi moi buy duoc.
-- Cach doi (theo script goc "Change To Ghoul Race"): Ectoplasm/BuyCheck (check) -> Ectoplasm/Change.
-- Ghoul Race Id = 4. Ecto se bi server tru (100).
-- Tien toi SAT NPC Experimic (bat buoc: co Hellfire Torch thi phai dung gan NPC
-- nay thi Change moi an - neu goi tu xa server tra ve nil -> khong doi duoc).
-- Uu tien toa do quet duoc tu NPC; fallback CFG["Race NPC Pos"] neu user set.
local function ApproachRaceNPC()
    if not HumanoidRootPart then return false end
    local _, part = FindRaceNPC()
    local npcCF = part and part.CFrame
    if not npcCF and CFG["Race NPC Pos"] then
        local p = CFG["Race NPC Pos"]
        npcCF = (typeof(p) == "CFrame") and p or CFrame.new(p)
    end
    if not npcCF then
        SetStatus("Race NPC (Experimic) not found on ship")
        return false
    end
    local dist = (HumanoidRootPart.Position - npcCF.Position).Magnitude
    if dist <= (CFG["Race NPC Dist"] or 12) then
        return true  -- da dung sat NPC
    end
    -- tween toi dung truoc mat NPC (khong TP xuyen)
    SetStatus(("Move to Experimic NPC (%d studs)"):format(math.floor(dist)))
    Tween(npcCF * CFrame.new(0, 3, 4))
    task.wait(0.4)
    return (HumanoidRootPart.Position - npcCF.Position).Magnitude <= (CFG["Race NPC Dist"] or 12)
end

local function TryBuyGhoulRace()
    if IsGhoul() then return true end
    if not HasHellfireTorch() then return false end
    local id = CFG["Ghoul Race Id"]

    -- BAT BUOC: len Cursed Ship + dung SAT NPC Experimic truoc khi Change.
    EnsureOnCursedShip()
    -- tien toi NPC (thu vai lan cho toi khi du gan)
    local nearNPC = false
    for _ = 1, 8 do
        if ShouldStop() then return false end
        if ApproachRaceNPC() then nearNPC = true break end
        task.wait(0.4)
    end
    if not nearNPC then
        SetStatus("Cannot reach Experimic NPC -> retry later")
        return false
    end

    SetStatus("Near Experimic + have Torch -> buy Ghoul (check then change)")
    -- goi va CAPTURE ket qua de biet server co xu ly khong
    local resCheck, resChange
    pcall(function()
        resCheck = COMMF_:InvokeServer("Ectoplasm", "BuyCheck", id)
        task.wait(0.6)
        resChange = COMMF_:InvokeServer("Ectoplasm", "Change", id)
    end)
    print("[Ghoul] BuyCheck ->", tostring(resCheck), "| Change ->", tostring(resChange))
    task.wait(1.2)
    local ghoul = IsGhoul()
    if ghoul then SetStatus("Changed to Ghoul race!") end
    return ghoul
end

-- Tien toi gan boss: check khoang cach -> xa thi requestEntrance ra thuyen -> tween toi.
-- Tra ve true khi da o gan (trong tam danh), false khi con dang di chuyen.
-- KHI DA GAN: dung HoverLock (lam do player) de dung yen tren dau boss, KHONG giat len xuong.
local function ApproachBoss(bossPart)
    if not HumanoidRootPart then return false end
    local targetCF = bossPart and bossPart.CFrame or CFG["Boss Pos"]
    local dist = (HumanoidRootPart.Position - targetCF.Position).Magnitude

    -- da gan -> HOVER LOCK ngay tren dau boss (do player, khong tween lap -> het giat)
    if dist <= CFG["Boss Near Dist"] then
        Tween(false)  -- huy tween dang chay (neu co) truoc khi khoa
        local h = tonumber(CFG["Hover Height"]) or 18
        HoverLock(targetCF * CFrame.new(0, h, 0))  -- pin dung tren dau boss
        return true
    end

    -- roi xa -> nha khoa hover de di chuyen
    HoverLock(nil)

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

-- vong lap farm boss trong 1 server: detect -> danh.
-- QUAN TRONG: ngay khi co Hellfire Torch -> DUNG farm boss, di mua race (khong fetch nua).
local function _FarmBossBody()
    -- neu vao day ma da co torch san -> mua race luon, khoi farm
    if HasHellfireTorch() then
        if TryBuyGhoulRace() then raceDone = true return "DONE" end
        -- co torch nhung chua mua duoc (thieu ecto?) -> bao de main flow xu ly, khong farm boss
        return "HAS_TORCH"
    end

    -- BAT BUOC len Cursed Ship TRUOC khi detect: boss Cursed Captain o TREN thuyen.
    -- Neu vua sang Sea 2 / vua join (spawn xa thuyen) thi Enemies chua load boss ->
    -- detect nham "khong co boss" -> hop server oan. Len thuyen roi moi ket luan.
    EnsureOnCursedShip()

    local deadline = tick() + CFG["Detect Timeout"]
    -- cho detect boss
    SetStatus("Detecting boss in server...")
    while tick() < deadline do
        if ShouldStop() then return "STOPPED" end
        if HasHellfireTorch() then
            if TryBuyGhoulRace() then raceDone = true return "DONE" end
            return "HAS_TORCH"
        end
        if BossPresent() then break end
        task.wait(0.5)
    end

    if not BossPresent() then
        SetStatus("No boss here -> next server")
        return "NO_BOSS"
    end

    -- co boss -> farm den khi chet / co torch / mat boss
    SetStatus("Boss found! Farming " .. CFG["Boss Name"])
    while true do
        if ShouldStop() then return "STOPPED" end
        -- co torch bat cu luc nao -> dung farm ngay, di mua race
        if HasHellfireTorch() then
            SetStatus("Got Hellfire Torch -> stop farming boss")
            if TryBuyGhoulRace() then raceDone = true return "DONE" end
            return "HAS_TORCH"
        end

        local boss = FindEnemy(CFG["Boss Name"])
        if not boss then
            -- da vao vong farm (boss tung song o Enemies) ma gio khong tim thay boss SONG
            -- -> boss vua chet/despawn. Cho 1 nhip roi confirm; van khong co -> "Boss gone" de
            --    main flow FETCH server moi (khong ket vong vi da bo check RS template).
            task.wait(0.3)
            if not BossPresent() then
                SetStatus("Boss gone -> will fetch new server")
                break
            end
        else
            if IsDied(boss) then
                SetStatus("Boss killed")
                break
            end
            local bhrp = boss:FindFirstChild("HumanoidRootPart")
            -- CHECK gan boss chua: chua gan -> requestEntrance + tween toi; gan roi -> danh
            local near = ApproachBoss(bhrp)
            if near then
                EquipMelee()   -- chac chan dang cam melee (keeper nen cung lo, day chi de chac)
                FastAttack(CFG["Boss Name"])
            end
        end
        -- danh moi frame (nhu V3) de toc do toi da; KHONG wait(0.1) (truoc day chi 10 don/giay)
        task.wait()
    end

    -- sau khi boss chet, cho 1 chut roi check torch (drop co the roi vao inv sau vai giay)
    for _ = 1, 6 do
        if HasHellfireTorch() then
            if TryBuyGhoulRace() then raceDone = true return "DONE" end
            return "HAS_TORCH"
        end
        task.wait(0.5)
    end
    return "KILLED"
end

local function FarmBossInServer()
    if busyFarming then return "BUSY" end
    busyFarming = true
    farmingBoss = true   -- bat equip-keeper: re-equip melee lien tuc trong khi danh boss
    -- boc pcall + reset khoa du co loi hay return giua chung
    local ok, result = pcall(_FarmBossBody)
    -- cleanup du thoat kieu nao: tat keeper, nha khoa hover, huy tween
    farmingBoss = false
    busyFarming = false
    pcall(function() HoverLock(nil) end)  -- nha "lam do" khi roi vong danh boss
    pcall(function() Tween(false) end)
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
    while not raceDone and not ShouldStop() do
        -- ==== UU TIEN 1: da co Hellfire Torch -> DUNG fetch/farm, di mua race ngay ====
        if HasHellfireTorch() then
            SetStatus("Have Hellfire Torch -> stop fetching, buy Ghoul race")
            -- neu thieu ecto thi refarm truoc khi doi
            if GetEctoplasm() < CFG["Ectoplasm Needed"] then
                SetStatus("Need Ectoplasm to change race -> refarm")
                GoToSea2()
                FarmEctoplasm()
            end
            if TryBuyGhoulRace() then raceDone = true break end
            -- chua mua duoc (co the do delay server) -> thu lai, tuyet doi KHONG fetch
            task.wait(1.5)
            -- quay lai dau vong (van con torch -> lai vao nhanh nay, khong fetch)
            -- tiep tuc
        else
            -- ==== chua co torch: dam bao du nguyen lieu ====
            if GetEctoplasm() < CFG["Ectoplasm Needed"] then
                SetStatus("Ectoplasm dropped below needed -> refarm")
                GoToSea2()
                FarmEctoplasm()
            end

            -- ==== BAT BUOC: requestEntrance LEN Cursed Ship TRUOC khi detect/farm boss. ====
            -- Boss Cursed Captain o TREN thuyen. Neu chua len (vua travel Sea 2 / vua join sv)
            -- thi workspace.Enemies CHUA co boss -> BossPresent() = false -> hop nham du sv co boss.
            -- Len thuyen roi cho 1 nhip cho Enemies load truoc khi quyet dinh.
            EnsureOnCursedShip()
            task.wait(0.5)

            -- ==== UU TIEN 2: server dang dung da co boss -> farm luon, khoi hop ====
            if BossPresent() then
                SetStatus("Boss present in CURRENT server -> farm now (no fetch)")
                local r = FarmBossInServer()
                if r == "DONE" or raceDone then break end
                -- neu farm xong ma co torch (HAS_TORCH) -> vong lai se vao nhanh mua race o tren
                if r == "HAS_TORCH" then
                    -- khong fetch, quay lai dau de mua race
                else
                    -- boss chet/mat, khong torch -> vong lai; neu van khong co boss se fetch
                end
            elseif not HasHellfireTorch() then
                -- ==== server hien tai khong co boss & chua co torch -> fetch de hop di tim ====
                if raceDone then break end
                local servers = FetchBossServers()
                if #servers == 0 then
                    SetStatus("No servers from API, retry in 3s")
                    task.wait(3)
                else
                    -- spam join tung server, moi server cach nhau Hop Delay(1.5s)
                    -- Luu y: sau teleport script se reload -> can persist qua queue_on_teleport
                    for i, s in ipairs(servers) do
                        if raceDone or ShouldStop() or HasHellfireTorch() then break end
                        SetStatus(("Join server %d/%d (players %d)"):format(i, #servers, s.Players or 0))
                        JoinJobId(s.JobId, s.PlaceId)
                        task.wait(CFG["Hop Delay"])
                    end
                    -- het 10 server ma van chua roi khoi (khong teleport duoc) -> fetch lai
                    SetStatus("Fetched 10 servers done, re-fetch")
                    task.wait(2)
                end
            end
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
    -- detector song song: uu tien torch, roi moi den boss
    while not raceDone and not ShouldStop() do
        task.wait(1)
        -- 1) co Hellfire Torch bat cu luc nao -> mua race ngay, KHONG fetch/farm
        if HasHellfireTorch() then
            if TryBuyGhoulRace() then raceDone = true end
        -- 2) chua co torch: thay boss trong server hien tai + du ecto -> farm luon
        elseif not farmingMaterial and BossPresent() and GetEctoplasm() >= CFG["Ectoplasm Needed"] then
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

  - Doi race Ghoul V1: Hellfire Torch la vat MO KHOA (drop tu boss). Co torch roi:
    COMMF_:InvokeServer("Ectoplasm","BuyCheck", 4)  -- CHECK truoc
    COMMF_:InvokeServer("Ectoplasm","Change",   4)  -- roi CHANGE (ton 100 ecto)
    Ghoul Race Id = 4 (theo script goc "Change To Ghoul Race"). Chinh trong ham TryBuyGhoulRace().
  - Torch Mode: 1 = Melee, 2 = Fruit (chi anh huong build sau khi thanh Ghoul). Doi trong config.
  - Khi da co Hellfire Torch -> KHONG fetch server nua, chuyen sang mua race.
  - Khi da thanh Ghoul -> raceDone = true, bao DONE va dung han (khong fetch).
  - Farm boss: LUON EquipMelee() lai moi vong (sau khi boss chet/respawn game hay bo trang bi).
    Chi dinh melee cu the qua getgenv().GhoulConfig["Attack Weapon"] (ten hoac ToolTip).
--]]
