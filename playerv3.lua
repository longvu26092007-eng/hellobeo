-- =============================================================
-- DRACO ANTI-STALKER V15.6 - FULL NEW BLACKLIST REPLACEMENT
-- =============================================================
repeat task.wait() until game:IsLoaded()
repeat task.wait() until game.Players and game.Players.LocalPlayer
repeat task.wait() until game.Players.LocalPlayer:FindFirstChild("PlayerGui")

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- [ PHẦN 0 ] AUTO CHỌN TEAM
-- ==========================================
getgenv().Team = getgenv().Team or "Marines"

if LocalPlayer.Team == nil then
    repeat
        task.wait()
        for _, v in pairs(LocalPlayer.PlayerGui:GetChildren()) do
            if string.find(v.Name, "Main") then
                pcall(function()
                    local teamBtn = v.ChooseTeam.Container[getgenv().Team].Frame.TextButton
                    teamBtn.Size = UDim2.new(0, 10000, 0, 10000)
                    teamBtn.Position = UDim2.new(-4, 0, -5, 0)
                    teamBtn.BackgroundTransparency = 1

                    task.wait(0.5)

                    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                    task.wait(0.05)
                    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
                    task.wait(0.05)
                end)
            end
        end
    until LocalPlayer.Team ~= nil and game:IsLoaded()

    task.wait(3)
end

repeat task.wait() until LocalPlayer.Character
    and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

-- ==========================================
-- [ PHẦN 1 ] DANH SÁCH BLACKLIST MỚI NHẤT
-- ==========================================
local RawBlacklist = {
    "oraings7",
    "DuckSilverStormy2008",
    "BillyKhaki143",
    "NovaFire201584",
    "tBLVshN9QY2joawg",
    "CrystalRasmussen00",
    "CandaceAcevedo85341",
    "RyanLara66452",
    "DevinBaker0141",
    "JuanVance6",
    "MartinHogan8536",
    "TrevorDouglas6",
    "AnaYang62429",
    "FrederickMaxwell2",
    "TommyCrawford1",
    "CathyLynch73",
    "JimSandel03",
    "JamesDarkFox86",
    "ChristianHinton51570",
    "zclarer7",
    "AvaHyp3rGam3r2018",
    "slimxnate9",
    "AndresIvory7917",
    "TamaraJuarez77",
    "DaisyNavarro8",
    "RocketDawnGolden2020",
    "RitaChung94",
    "P0w3r_INF3RN090",
    "KristinaIndigo7491",
    "V3nomByt3Hunt3r",
    "1nstendli9",
    "WilliamGhostAce2022",
    "JackAqua28428",
    "marvili18",
    "JackHyperRift50",
    "PhillipSanchez628",
    "KaylaPineda7434",
    "SonicBacon202064",
    "GigaMagicHyper2013",
    "LukeCodeHyper200552",
    "CatKelley7286",
    "ecompuo7",
    "JellyFlickMaster25",
    "SkySt0rmyIce2008",
    "XxDuckCraz3Slim3xX",
    "TravisEnglish06",
    "King_Zenith2464",
    "Aria_Pixelated200453",
    "XxZ3r0Eagl3StarryxX",
    "GloriaChanmayba",
    "SlimeN0va202464",
    "Grays0nFr0stHunt3r90",
    "CliffordUmber06986",
    "R0cketFlash15",
    "GraysonPixel202431",
    "JaxonFlash201790",
    "Cynthia_Neon1056",
    "DarkStorm201778",
    "BrooklynnBaconAqua_Y",
    "PrimalBac0nW0lf2011",
    "SophiaBlade201475",
    "EllaAc3Ech0",
    "SkyNovaJelly2021",
    "Orb1t_1x5c",
    "Auriccrimson4603",
    "BrooklynChaos6lcm",
    "EV3LYN_RAV3NJWOASJM",
    "XxMinerStormyShadowx",
    "ScarlettCircuitCode2",
    "StormTurboNeon38",
    "VictoriaStorm201550",
    "MoonZoomGhost55",
    "Aubr3yPix3lat3d42",
    "Build3rBlad3Lion2013",
    "DavidGlide3398",
    "KristyTurner1108",
    "DodsonKaiserr40",
    "HyperChillGlitch2018",
    "Maeve_NebulaX4075",
    "Puls3CircuitSonic15",
    "XxDragonDuckxX35YT",
    "CrazyHamza95087",
    "Cha0sBlastGalaxy2015",
    "Craz3Arrow9784",
    "LegendBlade202019",
    "RileyHawkqg6db1i",
    "Brooklynn_Prim1lbte",
    "dencielz8",
    "Blitz_MysticHunt3r65",
    "VoidDarkCraft2012",
    "Rock3t_Sparkly33",
    "M3chaEagl37607",
    "Rock3tAc3202017",
    "XxPr0GalaxyLightxXYT",
    "LiamRogueHexu9m2",
    "H3r0AquaBl0ck11YT",
    "XxSkat3r_NIGHTXX2020",
    "Arrow_Eagl38204",
    "RaymondHouse15",
    "Rock3tPlayzOrbit96",
}

local BlacklistMap = {}
for _, name in ipairs(RawBlacklist) do
    BlacklistMap[name] = true
end

-- ==========================================
-- [ PHẦN 2 ] UI + LOGIC ĐỔI SERVER
-- ==========================================
local HopScriptURL = "https://raw.githubusercontent.com/longvu26092007-eng/Uiaauiaa/refs/heads/main/hopsever.lua"

local okGetHui, hui = pcall(function()
    return gethui()
end)

local SafeGuiParent = (okGetHui and hui)
    or CoreGui:FindFirstChild("RobloxGui")
    or CoreGui

if SafeGuiParent:FindFirstChild("AntiStalkerUI") then
    SafeGuiParent.AntiStalkerUI:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AntiStalkerUI"
ScreenGui.Parent = SafeGuiParent

local MiniFrame = Instance.new("Frame", ScreenGui)
MiniFrame.Size = UDim2.new(0, 220, 0, 40)
MiniFrame.Position = UDim2.new(1, -230, 1, -50)
MiniFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)

Instance.new("UIStroke", MiniFrame).Color = Color3.fromRGB(255, 0, 0)
Instance.new("UICorner", MiniFrame)

local Status = Instance.new("TextLabel", MiniFrame)
Status.Size = UDim2.new(1, 0, 1, 0)
Status.BackgroundTransparency = 1
Status.Text = "✅ Đang quét: " .. getgenv().Team
Status.TextColor3 = Color3.new(1, 1, 1)
Status.Font = Enum.Font.GothamBold
Status.TextSize = 11

local PlayerAddedConnection
local isHopping = false

local function DoHop(detectedName)
    if isHopping then return end
    isHopping = true

    if PlayerAddedConnection then
        PlayerAddedConnection:Disconnect()
    end

    Status.Text = "🚨 PHÁT HIỆN: " .. detectedName
    Status.TextColor3 = Color3.new(1, 0, 0)

    task.wait(0.5)

    pcall(function()
        loadstring(game:HttpGet(HopScriptURL))()
    end)
end

local function CheckPlayers()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and BlacklistMap[p.Name] then
            return p.Name
        end
    end

    return nil
end

local function DestructScript()
    if isHopping then return end

    Status.Text = "✅ An toàn! Tự hủy script..."
    Status.TextColor3 = Color3.new(0, 1, 0)

    if PlayerAddedConnection then
        PlayerAddedConnection:Disconnect()
    end

    task.wait(1)

    if ScreenGui then
        ScreenGui:Destroy()
    end
end

PlayerAddedConnection = Players.PlayerAdded:Connect(function(p)
    if p ~= LocalPlayer and BlacklistMap[p.Name] then
        DoHop(p.Name)
    end
end)

task.spawn(function()
    task.wait(1)

    for i = 1, 3 do
        if isHopping then break end

        Status.Text = "🔍 Quét Lần " .. i .. "/3..."

        local detected = CheckPlayers()
        if detected then
            DoHop(detected)
            return
        end

        if i < 3 then
            task.wait(5)
        end
    end

    DestructScript()
end)
