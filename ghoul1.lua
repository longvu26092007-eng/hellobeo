--[[
    BuyGhoul.lua  -  Tim DUNG cach mua/doi race Ghoul qua NPC Experimic
    ------------------------------------------------------------------
    Van de: CommF_:InvokeServer("Ectoplasm","Change",4) tra ve NIL -> khong doi duoc.
    => Remote/arg dung da khac. Ban DANG DUNG GAN NPC Experimic roi.

    Script co 2 che do (chay ca hai):
      [HOOK]  theo doi moi remote game GUI DI. Khi ban TU BAM nut trade Ghoul
              trong dialog NPC bang tay -> script in ra DUNG remote + args that.
              => Day la cach chac chan 100%.
      [PROBE] tu dong thu vai bien the pho bien (Ectoplasm/Change so & chuoi,
              InteractNPC...) va in ket qua tung cai.

    HUONG DAN:
      1. Chay script khi dang dung gan NPC Experimic.
      2. Doi 2s cho PROBE chay xong (xem console co dong nao "=> race doi thanh cong" khong).
      3. Neu chua duoc: MO DIALOG NPC va TU BAM nut trade Ghoul bang tay 1 lan.
         Console se in "[HOOK] <ten remote> <args>" -> COPY dong do gui lai cho minh.
--]]

repeat task.wait() until game:IsLoaded()

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer       = Players.LocalPlayer
local CommF             = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_")

repeat task.wait() until LocalPlayer:FindFirstChild("Data")
    and LocalPlayer.Data:FindFirstChild("Race")

local function log(...)
    local parts = {}
    for _, v in ipairs({...}) do parts[#parts + 1] = tostring(v) end
    local msg = "[BuyGhoul] " .. table.concat(parts, " ")
    print(msg)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification",
            { Title = "BuyGhoul", Text = table.concat(parts, " "), Duration = 4 })
    end)
end

local function GetRace()
    local ok, v = pcall(function() return tostring(LocalPlayer.Data.Race.Value) end)
    return ok and v or "?"
end

local function GetEcto()
    local ok, n = pcall(function() return tonumber(CommF:InvokeServer("Ectoplasm", "Check")) end)
    return ok and (n or 0) or 0
end

--==================================================================
--  serialize args (de in ra doc duoc)
--==================================================================
local function ser(v, depth)
    depth = depth or 0
    local t = typeof(v)
    if t == "string" then return string.format("%q", v)
    elseif t == "number" or t == "boolean" then return tostring(v)
    elseif t == "Instance" then return "<Instance:" .. v.ClassName .. " " .. v.Name .. ">"
    elseif t == "Vector3" then return "Vector3(" .. tostring(v) .. ")"
    elseif t == "table" then
        if depth > 3 then return "{...}" end
        local parts = {}
        for k, val in pairs(v) do
            parts[#parts + 1] = "[" .. ser(k, depth + 1) .. "]=" .. ser(val, depth + 1)
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    else
        return "<" .. t .. ">"
    end
end

--==================================================================
--  [HOOK] bat moi remote game gui di (chi in cac call NGHI la doi race)
--==================================================================
local KEYWORDS = {"ecto", "ghoul", "race", "change", "buycheck", "experim", "trade", "dialog", "interact", "npc"}
local function looksInteresting(name, args)
    local blob = tostring(name):lower() .. " " .. tostring(ser(args)):lower()
    for _, kw in ipairs(KEYWORDS) do
        if blob:find(kw) then return true end
    end
    return false
end

local hookInstalled = false
local function installHook()
    if hookInstalled then return end
    if not hookmetamethod or not getnamecallmethod then
        log("Executor khong ho tro hookmetamethod -> bo qua HOOK, chi dung PROBE")
        return
    end
    hookInstalled = true
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        local args = {...}
        if (method == "InvokeServer" or method == "FireServer") then
            local nm = tostring(self.Name)
            if looksInteresting(nm, args) or nm == "CommF_" or nm:find("Craft")
                or nm:find("Interact") or nm:find("Dialogue") then
                print("[HOOK] " .. method .. " -> " .. self:GetFullName() .. "  ARGS: " .. ser(args))
            end
        end
        return oldNamecall(self, ...)
    end)
    log("HOOK da cai. Gio MO DIALOG NPC va BAM trade Ghoul bang tay -> xem console dong [HOOK].")
end

--==================================================================
--  [PROBE] tu thu vai bien the pho bien
--==================================================================
local function tryCall(desc, fn)
    local before = GetRace()
    local ok, res = pcall(fn)
    task.wait(1)
    local after = GetRace()
    print(("[PROBE] %s | ok=%s res=%s | race %s->%s"):format(
        desc, tostring(ok), tostring(res), before, after))
    if after == "Ghoul" then
        log("=> race doi THANH CONG bang: " .. desc)
        return true
    end
    return false
end

local function runProbe()
    log("Race:", GetRace(), "| Ecto:", GetEcto())
    if GetRace() == "Ghoul" then log("Da la Ghoul. Dung.") return true end

    -- 1) cach cu: so 4
    if tryCall('Ectoplasm/BuyCheck+Change (number 4)', function()
        CommF:InvokeServer("Ectoplasm", "BuyCheck", 4)
        task.wait(0.4)
        return CommF:InvokeServer("Ectoplasm", "Change", 4)
    end) then return true end

    -- 2) chuoi "4"
    if tryCall('Ectoplasm/Change (string "4")', function()
        CommF:InvokeServer("Ectoplasm", "BuyCheck", "4")
        task.wait(0.4)
        return CommF:InvokeServer("Ectoplasm", "Change", "4")
    end) then return true end

    -- 3) chi Change khong BuyCheck
    if tryCall('Ectoplasm/Change only (4)', function()
        return CommF:InvokeServer("Ectoplasm", "Change", 4)
    end) then return true end

    -- 4) khong so
    if tryCall('Ectoplasm/Change (no id)', function()
        return CommF:InvokeServer("Ectoplasm", "Change")
    end) then return true end

    -- 5) InteractNPC kieu Experiment (dang giong Draco InteractDragonQuest)
    for _, remoteName in ipairs({"RF/InteractNPC", "RF/Interact", "RF/InteractDragonQuest"}) do
        local RF = ReplicatedStorage:FindFirstChild("Modules")
            and ReplicatedStorage.Modules:FindFirstChild("Net")
            and ReplicatedStorage.Modules.Net:FindFirstChild(remoteName)
        if RF then
            for _, cmd in ipairs({"ExperimicRace", "GhoulRace", "BuyGhoul", "ChangeRace"}) do
                if tryCall(remoteName .. " NPC=Experiment cmd=" .. cmd, function()
                    return RF:InvokeServer({[1] = {NPC = "Experiment", Command = cmd}})
                end) then return true end
            end
        end
    end

    log("PROBE het cach ma chua doi duoc. Hay dung HOOK: bam trade Ghoul bang tay.")
    return false
end

--==================================================================
--  chay: cai hook TRUOC (de bat neu ban bam tay), roi chay probe
--==================================================================
installHook()
task.wait(0.5)
task.spawn(runProbe)

log("San sang. Neu PROBE khong an -> mo dialog NPC Experimic va bam trade Ghoul bang tay 1 lan.")
