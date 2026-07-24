--[[
    StopAll.lua  -  KILL SWITCH + HOOK DEBUG (khong di chuyen, khong farm)
    Muc dich:
      1. DUNG het cac script Ghoul/Buy dang chay loan (Ghoul.lua, BuyGhoul.lua...)
         - bat co dung cho moi vong lap cua chung
         - huy Tween/BodyVelocity/noclip dang keo nhan vat
         - xoa UI cua chung
      2. Cai HOOK DEBUG sach: dung IM, chi IN ra call khi BAN bam tay
         - hook CA CommF_ (RemoteFunction) VA Modules.Net (RF/... nhu Draco)
         - loc bot spam "Ectoplasm/Check" de de doc

    HUONG DAN:
      - Chay file NAY (khong cần tat tay script cu - no se tu dung).
      - Doi vai giay cho nhan vat ngung bay.
      - Mo dialog NPC Experimic, bam nut trade Ghoul BANG TAY 1 lan.
      - Copy cac dong [HOOK] (nhat la dong co "Change"/"Interact"/"Buy") gui lai.
--]]

--==================================================================
--  0. KILL SWITCH: dung cac script cu
--==================================================================
-- Cac script Ghoul.lua/BuyGhoul.lua deu doc getgenv().GhoulConfig / co cac co _G.
-- Ta bat het cac co "stop" pho bien + set raceDone de vong lap while thoat.
getgenv().GHOUL_STOP = true
getgenv().STOP_ALL   = true

-- Neu script cu dung cac bien global de dieu khien -> tat het
for _, k in ipairs({
    "GhoulGet", "Ectoplasm", "Complete_Trials", "CyborgGet",
    "AutoFarm", "AutoBoss", "FarmMaterial", "Running",
}) do
    pcall(function() getgenv()[k] = false end)
    pcall(function() _G[k] = false end)
end

-- danh dau raceDone neu script cu expose (mot so ban co)
pcall(function() getgenv().raceDone = true end)

local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local CoreGui     = game:GetService("CoreGui")
local RS          = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

--==================================================================
--  1. HUY MOI THU DANG KEO NHAN VAT (tween ghost, BodyVelocity, noclip)
--==================================================================
local function StopMovement()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")

    -- xoa cac BodyMover thuong dung de bay
    if hrp then
        for _, n in ipairs({
            "DracoAntiGravity", "BodyClip", "BodyVelocity",
            "BodyPosition", "BodyGyro", "AlignPosition", "LinearVelocity",
        }) do
            local m = hrp:FindFirstChild(n)
            if m then pcall(function() m:Destroy() end) end
        end
        pcall(function()
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end)
    end

    -- xoa part ghost cua tween (ten hay dung trong cac script)
    for _, nm in ipairs({"GhoulTweenGhost", "TweenGhost", "TouchTweenGhost", "TweenGhost0"}) do
        local g = workspace:FindFirstChild(nm)
        if g then pcall(function() g:Destroy() end) end
    end
end

-- chay lien tuc vai giay de dap moi tween/velocity script cu lai tao ra
task.spawn(function()
    local t0 = tick()
    while tick() - t0 < 8 do
        StopMovement()
        task.wait(0.1)
    end
    StopMovement()
end)

--==================================================================
--  2. XOA UI cua script cu
--==================================================================
for _, guiName in ipairs({"GhoulStatus", "DracoAutoUI", "PullLeverUI", "KaitunRacesBF", "Status"}) do
    local parents = { CoreGui }
    pcall(function() if gethui then table.insert(parents, gethui()) end end)
    for _, p in ipairs(parents) do
        local g = p:FindFirstChild(guiName)
        if g then pcall(function() g:Destroy() end) end
    end
end

--==================================================================
--  3. UI nho bao trang thai
--==================================================================
local gui = Instance.new("ScreenGui")
gui.Name = "StopAllUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 9999999
gui.Parent = (gethui and gethui()) or CoreGui
local lbl = Instance.new("TextLabel")
lbl.Size = UDim2.new(0, 420, 0, 40)
lbl.Position = UDim2.new(0.5, -210, 0, 6)
lbl.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
lbl.BackgroundTransparency = 0.1
lbl.TextColor3 = Color3.fromRGB(120, 255, 160)
lbl.Font = Enum.Font.GothamBold
lbl.TextSize = 13
lbl.Text = "STOPPED. Bam trade Ghoul bang tay -> xem console (F9)"
lbl.Parent = gui
Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 8)

local function status(t)
    print("[StopAll] " .. tostring(t))
    if lbl then lbl.Text = tostring(t) end
end
status("STOPPED cac script cu. Cai hook debug...")

--==================================================================
--  4. HOOK DEBUG (dung im, chi log)
--     Hook __namecall de bat MOI RemoteFunction/RemoteEvent:
--       - CommF_ (Remotes.CommF_)
--       - Modules.Net "RF/..." (kieu Draco dung de Craft / InteractDragonQuest)
--     Loc spam: bo qua Ectoplasm/Check va cac call lap vo nghia.
--==================================================================
local function argsToStr(...)
    local n = select("#", ...)
    local parts = {}
    for i = 1, n do
        local v = select(i, ...)
        local tv = typeof(v)
        if tv == "string" then
            parts[i] = string.format("[%d]=%q", i, v)
        elseif tv == "number" or tv == "boolean" then
            parts[i] = string.format("[%d]=%s", i, tostring(v))
        elseif tv == "table" then
            -- in nong 1 lop cho table (vd {NPC=..., Command=...})
            local inner = {}
            pcall(function()
                for k, vv in pairs(v) do
                    inner[#inner + 1] = string.format("%s=%s", tostring(k),
                        (type(vv) == "string") and string.format("%q", vv) or tostring(vv))
                end
            end)
            parts[i] = string.format("[%d]={%s}", i, table.concat(inner, ", "))
        elseif tv == "Instance" then
            parts[i] = string.format("[%d]=<%s:%s>", i, v.ClassName, v.Name)
        else
            parts[i] = string.format("[%d]=<%s>", i, tv)
        end
    end
    return "{" .. table.concat(parts, ", ") .. "}"
end

-- co bo qua cac call spam (chi loc khi la Ectoplasm/Check)
local function shouldSkip(method, firstArg, secondArg)
    if method ~= "InvokeServer" and method ~= "FireServer" then return true end
    -- bo qua doc chi so lien tuc
    if firstArg == "Ectoplasm" and secondArg == "Check" then return true end
    if firstArg == "getInventory" then return true end
    if firstArg == "getFruits" or firstArg == "GetFruits" then return true end
    if firstArg == "SetLastSpawnPoint" then return true end
    return false
end

local hooked = false
if hookmetamethod and getnamecallmethod then
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        if method == "InvokeServer" or method == "FireServer" then
            local ok, path = pcall(function() return self:GetFullName() end)
            path = ok and path or tostring(self)
            local a1, a2 = ...
            -- CHI log remote lien quan doi race / craft / interact / buy
            -- + luon log neu la Modules.Net (RF/...) vi Draco dung cho doi race
            local isNet   = path:find("Modules.Net") ~= nil
            local isCommF = path:find("CommF_") ~= nil
            if (isNet or isCommF) and not shouldSkip(method, a1, a2) then
                print(string.format("[HOOK] %s -> %s\n        ARGS: %s",
                    method, path, argsToStr(...)))
            end
        end
        return old(self, ...)
    end)
    hooked = true
end

if hooked then
    status("HOOK ON. Bam trade Ghoul bang tay -> copy dong [HOOK] gui lai.")
    print("[StopAll] ================================================")
    print("[StopAll] Da cai hook. Bay gio HAY BAM NUT TRADE GHOUL BANG TAY.")
    print("[StopAll] Da LOC bot spam (Ectoplasm/Check, getInventory...).")
    print("[StopAll] Chu y dong nao co: Change / Buy / Interact / Craft / DragonRace.")
    print("[StopAll] ================================================")
else
    status("Executor KHONG ho tro hookmetamethod - khong hook duoc.")
    warn("[StopAll] Executor khong ho tro hookmetamethod/getnamecallmethod.")
end
