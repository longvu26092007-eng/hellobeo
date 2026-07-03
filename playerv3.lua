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
    "zchat16",
    "1eminerma9",
    "SaraZavala3220",
    "logordx7",
    "XXAIDEN_StarryxX2024",
    "JermainePruitt318",
    "zomadd6",
    "zmarsx6",
    "MiaHeroEchoYT",
    "TammieLang87768",
    "Ph03nixOrbit201029",
    "LynnForbes153",
    "KarinaMosley06815",
    "GeraldPurple19",
    "PamelaTodd548",
    "DaisyBarker009",
    "VincentDonovan0203",
    "GabriellaFuentes05",
    "ClaytonHenderson1",
    "TammyBecker0007",
    "AmyWalters0894",
    "StuartReid3161",
    "LoriHill615",
    "BrittneyBowers8",
    "BrucePope9",
    "JonathanKeith880",
    "TravisDodson26",
    "MarieHancock0",
    "SamuelSheppard8586",
    "DuaneMoreno7",
    "XxSonic_RavenxX63",
    "Flick_VORTEX201329",
    "Profile34628837",
    "BeastPh0enixRift2020",
    "KristiGreen53077",
    "GraceZero200292",
    "IsaacN30n64",
    "TinaNunez39706",
    "DaisyReynolds739",
    "BruceTravis3",
    "CoryRoy491",
    "AloeGuerrero82477",
    "StevenAvila957",
    "TroyPorter06",
    "JayKent984",
    "AshleeObrien51544",
    "CoreyPollard082",
    "SamuelMurillo210",
    "ConnieRitter9581",
    "RickIbarra8",
    "RandySharp460",
    "MalloryMoreno2648",
    "CathyMoss03",
    "PatriciaTran00",
    "RebekahBuckley814",
    "NatalieKnight8264",
    "SheenaRiddle7",
    "TamiWells8138",
    "JaclynSanders8839",
    "RobinAlvarado109",
    "AnnetteBronze18",
    "PerryTerry856",
    "AloeveraEstes38550",
    "EugeneDavies96",
    "RebeccaArmstrong4579",
    "MarieMcdaniel7",
    "RobertVelasquez859",
    "XxEliBeastxX57",
    "TonyHuang4713",
    "zshoes6",
    "GlendaSpencer66",
    "Samu3lVip3rSilv3r201",
    "RashadMysticRunn3r46",
    "1trexcelr9",
    "NebulaQueen682",
    "xanwingrx9",
    "intelomez9",
    "1folkie7",
    "1hott5",
    "DanaHubbard537",
    "JohnnyFox57708",
    "ngoc105n",
    "SherriRosales41766",
    "EricWilkerson9166",
    "AnaBronze8229",
    "AlyssaPaul3730",
    "LuisEstes7791",
    "HectorWalton2930",
    "CherylBlake50602",
    "KatelynSnow505",
    "RobynMeza3021",
    "KristinaGoodman799",
    "KathrynMedina0163",
    "StephanieDiaz1939",
    "CalvinWilkinson2782",
    "BrandonHull56981",
    "KuiporStanley2010",
    "YolandaKeller59454",
    "MelvinLyons7",
    "AbigailValencia2",
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
