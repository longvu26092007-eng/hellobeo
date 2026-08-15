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
    "xnyconv7",
    "Robert_Silver8098",
    "SkaterSkyxueuqq",
    "CyberGhostll6cpq",
    "Drag0nDawn0zu25",
    "Sebastian_Maxrgj2srn",
    "R0cketEch0Hyper2005",
    "Ven0m_Blizzardwkscr",
    "DustSFRiderT119632",
    "aretixentx10",
    "osnoopwillows13",
    "medaveo7",
    "ToxicNovaMast3r2022",
    "xdubya6",
    "XxChaseFlameNinjaxX2",
    "picasez7",
    "freditellz10",
    "wakazxp7",
    "BearCode201639",
    "Br00klyn_B3ar2024",
    "zmstropte9",
    "alcohnet19",
    "zhnotic7",
    "DANCER_PANDAQNYMI",
    "uttergon19",
    "zchunky7",
    "abacol17",
    "reports1nath12",
    "XxBearStormyUltraxX",
    "entrights110",
    "xxactor7",
    "xinnoblue9",
    "thermandx9",
    "xrelaxo7",
    "AbigailClaw202270",
    "ElijahViperLucky2021",
    "oshabby7",
    "EliteMckennaFire250",
    "F0xMagic201324",
    "XxNoah_MoonxX65",
    "IsaacSonic2016YT",
    "ngoc148n",
    "EzraClawLight2009",
    "CamiloYoderux2m3",
    "batestal19",
    "inseci17",
    "ChillHer0Pixel201555",
    "1platinum9",
    "AvaRav3nAc3YT",
    "BrettRiddle01",
    "FlowerReyes0143",
    "Gam3rZ3roSilv3r2014",
    "ngoc168n",
    "JulianOrbit202014",
    "AquaKingGlitch2009",
    "FuryByte201575",
    "Sab3r_MOON2024YT",
    "cutieldex9",
    "Thunder_Fox2272",
    "RonnieRuby37520",
    "SnoopyBridges62",
    "ScarlettWolfPixel59",
    "XxZayd3nAquaByt3xX",
    "JacksonMax200923",
    "Will0wC0de202252",
    "XxNovaAceBlastxX2012",
    "EllieVenom200857",
    "MysticRunn3rLi0n9664",
    "np1p7sizxzzi4",
    "Addison_BLAST201723",
    "DragonBan338",
    "xygroleup9",
    "cteedz6",
    "AriaBl0ckOrbit202254",
    "EmmaDriftTiger2013",
    "GalaxyTigerPro30",
    "CinderCraft7739",
    "HawkChaseSaber2016",
    "XXLUNA_ClawxX79",
    "BrendanMoses541",
    "XxSilverMoonWolfxX20",
    "JenniferLucas96647",
    "RussellShaw667hi",
    "HectorSavage3",
    "YeseniaRodgers70765",
    "BobbyBoyle49027",
    "DinosaurHicks21783",
    "Profile12493251",
    "ErnestFrey411",
    "XxAquaFuryChaosxX",
    "Blake_Dev833",
    "DancerHunter200219",
    "Titan_Skat3r8274",
    "S0phiaSt3althThund3r",
    "XxFlameToxicMasterxX",
    "JulianClaw200546",
    "Cheryl_Nebula1711",
    "MechaBlock6450",
    "ADDISONCRAZ3Z3RO2006",
    "Luk3Knight200961",
    "Fury_Primal202460",
    "L0ganCrystalBlast35",
    "KnightRiderFlame57",
    "PixelSlimeTurbo2012",
    "Skater_Lavaf6n122",
    "N0ahnj4zv",
    "FlickSkater201740",
    "LucasFir3Spark2003",
    "Mia_Hexz03k3",
    "ManuelWilkerson74",
    "thien137ttt",
    "DuckPowerChaos2005",
    "Jelly6yghzbv",
    "DeltaTurbo7395",
    "EliLegend8298",
    "celibri18",
    "LeviChaosMax2008",
    "dungk369h",
    "dung759a",
    "STARRYHUNTERVCUTR0",
    "1estati7",
    "AnneBailey50142",
    "othouseba9",
    "odown5",
    "dungk220t",
    "Rob3rtFall3n5749",
    "dung506a",
    "XxZoomHyperSkaterxX",
    "OwenPixelFlash2022",
    "haika639m",
    "Kaylee_Cyberlr37rzs",
    "R0cketPrimalZ00m",
    "Inf3rn0C0d32013",
    "Power_Blade1215",
    "Charl0tte_Magi98imj",
    "I0n_King4775",
    "ChaosSolarRunner2319",
    "Jamal_Wolf8000",
    "LavaFox2389",
    "Wraith_Panda3293",
    "WillieWarden3833",
    "Ghost_FrostRunner493",
    "Turb0_Max200415",
    "Ne0n_C0de1652",
    "Phantom_Starry4542",
    "StormyVort3xRunn3r74",
    "zbeazante9",
    "oesavange9",
    "BlastClawUltra2024",
    "Surg3_Lion2943",
    "Chase_FUSI0N200386",
    "dung781a",
    "dung751a",
    "haika642m",
    "Elli3_Min3r17",
    "Sydney_Julianna98565",
    "ChloeNightThunder91",
    "CrazyRenata13324",
    "ChloePandaZero2003",
    "SalimCinderRunner169",
    "LiamNight4385",
    "Br00klynn_FUSI0N35YT",
    "Mahdi_Shadow5550",
    "thien341t",
    "Pixel_Quantum576",
    "King_Wolf202167",
    "Build3rRiftHunt3r637",
    "ProBlock201220",
    "XxChl0eDrag0nCrystal",
    "AndreaLunarRunner179",
    "Amal_RiftHunter3704",
    "LeenEcho1806",
    "Fire_Builder8069",
    "DonMorse8",
    "BrooklynnGamerh5cig",
    "dungk234k",
    "ZoomCraftStarry2006",
    "haika584m",
    "ElijahFusionVortex43",
    "RidhaBlock2392",
    "Abigail_Panda1818",
    "JeromeSuarez15",
    "haika410m",
    "Luke_xaf5p",
    "JustinNebulaHunter21",
    "DorothyWood25999",
    "Inferno_EchoX4920",
    "Wraith_Crimson9741",
    "EloraYT3771",
    "Ayman_Mirage3888",
    "xrectus7",
    "RogueQuantumRunner90",
    "Fr0stbiteSnare9693",
    "JosephSparkly2716",
    "UltraWraithRogu32013",
    "AidenBeast6770",
    "AsherShad0waev0y1",
    "SheliaContreras08988",
    "FloweredRomero3452",
    "Turbo_Delta5419",
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
