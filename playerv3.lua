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
    "XxStorm_OrbitxX2002", "LindsayMcdonald02", "SonicSilv3r201320", "oillear7", "MikeMueller1",
    "PaulaWagner706", "srundero8", "ShannonBush750", "AliceHubbard05", "LeviStormyZap2008",
    "WilliamKaiser47905", "TaylorMcdonald981", "JasminHowe7251", "Micha3lTurboMystic20", "BethMann13073",
    "DarinWebb4", "GlenCardenas967", "CodyGilbert026", "NancyBranch081", "DaleAlvarado34462",
    "KimMcintosh62846", "RickyBlush61971", "BobbyEllison323", "GinaHoward01356", "DaleDiaz908",
    "DorothyGraves2989", "HaileyKhan5", "AntonioBlair842", "JocelynFrost7537", "TimConway216",
    "RileyKline51", "YvetteBurton21", "JoannRiley83", "SallyAguilar507", "GlendaWaller43",
    "AnthonyWells1822", "DeannaDonovan89021", "WoodsWeaver8", "MadelineAqua624", "AndresHeath261",
    "LarryMcpherson940", "KaitlynWalton9992", "MelissaDark57", "CindyKhan655", "SaraJoyce56000",
    "OscarOsborn58803", "ErinSand03", "JosephDuncan45686", "KathyHuang6818", "KristinaTodd59",
    "BunnyWarm7", "1titagene9", "Viper_Ghost200786", "Vip3rSky201963", "Samantha_Frost7637",
    "Turb0Craft201641", "xtrainz7", "RafatRiftRunn3r5819", "H3roChaosGiga201886", "RogueLionStarry20093",
    "Philip_Byte617", "MagicOrbitHero77", "ZeroChaseInferno2019", "HenryHer0Light2006", "GraceBlazeBac0n2012",
    "WraithBuilderFlash72", "Patrick_NovaHunter72", "EchoHunter_Blaze362", "Cooki3_Slim36137", "Fusi0nDark200224",
    "Munir_A3th3rHunt3r12", "AuroraSpark200356", "AubreyEcho201154", "KingLi0n201153", "XxNoraDanc3rNightxX",
    "ShaimaaNovaStrik3517", "xemdera7", "GabrielShadowNinja33", "XxDragonFusionxX95", "oellerata9",
    "XxLunaKingStarxXYT", "TeresaAqua4328", "nellahix8", "LukeGigaStealth2014", "moonAuric6898",
    "CODE_Max200324", "JacksonBearGhost57", "haselez7", "irisioro8", "ngoc064n",
    "xoswarere9", "Guerra3y74", "orteklyti9", "xnverixpo9", "FusionMoonRocket2014",
    "MaxZoomRift85", "DarkSkater201822", "SparkBlizzardZ3ro202", "xterium7", "ossiver7"
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
