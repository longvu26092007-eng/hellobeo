--[[
    SERVER TIME UI - Blox Fruits
    Nguon duy nhat:
        Workspace._WorldOrigin.Locations.<Location>:GetAttribute("TimeIn")

    Cong thuc:
        ServerUptime = Workspace:GetServerTimeNow() - TimeIn

    Khong dung:
        workspace.DistributedGameTime
        tick()
        os.clock()
        time()
]]

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
repeat task.wait() until LocalPlayer

local CONFIG = {
    UpdateInterval = 1,
    GuiName = "ServerTime_TimeIn_UI",
    Title = "SERVER TIME",
}

-- Xoa UI cu neu chay lai script
local oldGui = CoreGui:FindFirstChild(CONFIG.GuiName)
if oldGui then
    oldGui:Destroy()
end

local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
if playerGui then
    local oldPlayerGui = playerGui:FindFirstChild(CONFIG.GuiName)
    if oldPlayerGui then
        oldPlayerGui:Destroy()
    end
end

local function formatDuration(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))

    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60

    if days > 0 then
        return string.format("%dd %02dh %02dm %02ds", days, hours, minutes, secs)
    end

    return string.format("%02dh %02dm %02ds", hours, minutes, secs)
end

local function shortJobId(jobId)
    jobId = tostring(jobId or "")
    if #jobId <= 18 then
        return jobId
    end
    return string.sub(jobId, 1, 8) .. "..." .. string.sub(jobId, -8)
end

local function getLocationsFolder()
    local worldOrigin = Workspace:FindFirstChild("_WorldOrigin")
    if not worldOrigin then
        return nil
    end

    return worldOrigin:FindFirstChild("Locations")
end

-- Chon cum TimeIn xuat hien nhieu nhat.
-- Cach nay tranh lay nham mot Location co TimeIn bat thuong.
local function detectServerStartTime()
    local locations = getLocationsFolder()
    if not locations then
        return nil, nil, "Không tìm thấy Workspace._WorldOrigin.Locations"
    end

    local groups = {}

    for _, location in ipairs(locations:GetChildren()) do
        local value = location:GetAttribute("TimeIn")

        if type(value) == "number" and value > 1000000000 then
            local rounded = math.floor(value + 0.5)

            groups[rounded] = groups[rounded] or {
                count = 0,
                total = 0,
                names = {},
            }

            local group = groups[rounded]
            group.count += 1
            group.total += value
            table.insert(group.names, location.Name)
        end
    end

    local bestRounded
    local bestGroup

    for rounded, group in pairs(groups) do
        if not bestGroup or group.count > bestGroup.count then
            bestRounded = rounded
            bestGroup = group
        elseif group.count == bestGroup.count and rounded < bestRounded then
            bestRounded = rounded
            bestGroup = group
        end
    end

    if not bestGroup then
        return nil, nil, "Không tìm thấy Attribute TimeIn hợp lệ"
    end

    local averageTimeIn = bestGroup.total / bestGroup.count
    local exampleName = bestGroup.names[1] or "Unknown"

    return averageTimeIn, {
        count = bestGroup.count,
        exampleName = exampleName,
        path = "Workspace._WorldOrigin.Locations." .. exampleName .. ".@TimeIn",
    }
end

local function getServerNow()
    local ok, result = pcall(function()
        return Workspace:GetServerTimeNow()
    end)

    if ok and type(result) == "number" then
        return result
    end

    return nil
end

-- Tao UI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = CONFIG.GuiName
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local parented = false

pcall(function()
    if type(gethui) == "function" then
        ScreenGui.Parent = gethui()
        parented = true
    end
end)

if not parented then
    local ok = pcall(function()
        ScreenGui.Parent = CoreGui
    end)

    if not ok and playerGui then
        ScreenGui.Parent = playerGui
    end
end

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.fromOffset(430, 190)
Main.Position = UDim2.new(0.5, -215, 0.16, 0)
Main.BackgroundColor3 = Color3.fromRGB(19, 25, 33)
Main.BorderSizePixel = 0
Main.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = Main

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(61, 74, 90)
MainStroke.Thickness = 1
MainStroke.Parent = Main

local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 38)
Header.BackgroundColor3 = Color3.fromRGB(27, 35, 45)
Header.BorderSizePixel = 0
Header.Parent = Main

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 10)
HeaderCorner.Parent = Header

local HeaderFix = Instance.new("Frame")
HeaderFix.Size = UDim2.new(1, 0, 0, 10)
HeaderFix.Position = UDim2.new(0, 0, 1, -10)
HeaderFix.BackgroundColor3 = Header.BackgroundColor3
HeaderFix.BorderSizePixel = 0
HeaderFix.Parent = Header

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -90, 1, 0)
Title.Position = UDim2.fromOffset(14, 0)
Title.BackgroundTransparency = 1
Title.Font = Enum.Font.GothamBold
Title.Text = CONFIG.Title
Title.TextColor3 = Color3.fromRGB(109, 222, 161)
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local Minimize = Instance.new("TextButton")
Minimize.Size = UDim2.fromOffset(30, 26)
Minimize.Position = UDim2.new(1, -70, 0, 6)
Minimize.BackgroundColor3 = Color3.fromRGB(48, 59, 73)
Minimize.BorderSizePixel = 0
Minimize.Font = Enum.Font.GothamBold
Minimize.Text = "—"
Minimize.TextColor3 = Color3.fromRGB(230, 235, 240)
Minimize.TextSize = 15
Minimize.Parent = Header

local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 6)
MinCorner.Parent = Minimize

local Close = Instance.new("TextButton")
Close.Size = UDim2.fromOffset(30, 26)
Close.Position = UDim2.new(1, -36, 0, 6)
Close.BackgroundColor3 = Color3.fromRGB(126, 58, 58)
Close.BorderSizePixel = 0
Close.Font = Enum.Font.GothamBold
Close.Text = "X"
Close.TextColor3 = Color3.fromRGB(255, 235, 235)
Close.TextSize = 13
Close.Parent = Header

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = Close

local Content = Instance.new("Frame")
Content.Name = "Content"
Content.Size = UDim2.new(1, -24, 1, -52)
Content.Position = UDim2.fromOffset(12, 44)
Content.BackgroundTransparency = 1
Content.Parent = Main

local Status = Instance.new("TextLabel")
Status.Size = UDim2.new(1, 0, 0, 22)
Status.BackgroundTransparency = 1
Status.Font = Enum.Font.GothamBold
Status.Text = "Đang tìm Attribute TimeIn..."
Status.TextColor3 = Color3.fromRGB(246, 197, 88)
Status.TextSize = 13
Status.TextXAlignment = Enum.TextXAlignment.Left
Status.Parent = Content

local Uptime = Instance.new("TextLabel")
Uptime.Size = UDim2.new(1, 0, 0, 42)
Uptime.Position = UDim2.fromOffset(0, 26)
Uptime.BackgroundTransparency = 1
Uptime.Font = Enum.Font.GothamBold
Uptime.Text = "Server Timer: --h --m --s"
Uptime.TextColor3 = Color3.fromRGB(240, 244, 248)
Uptime.TextSize = 24
Uptime.TextXAlignment = Enum.TextXAlignment.Left
Uptime.Parent = Content

local Source = Instance.new("TextLabel")
Source.Size = UDim2.new(1, 0, 0, 40)
Source.Position = UDim2.fromOffset(0, 72)
Source.BackgroundTransparency = 1
Source.Font = Enum.Font.Gotham
Source.Text = "Source: chưa xác định"
Source.TextColor3 = Color3.fromRGB(168, 180, 194)
Source.TextSize = 11
Source.TextWrapped = true
Source.TextXAlignment = Enum.TextXAlignment.Left
Source.TextYAlignment = Enum.TextYAlignment.Top
Source.Parent = Content

local Job = Instance.new("TextLabel")
Job.Size = UDim2.new(1, 0, 0, 20)
Job.Position = UDim2.fromOffset(0, 116)
Job.BackgroundTransparency = 1
Job.Font = Enum.Font.Code
Job.Text = "JobId: " .. shortJobId(game.JobId)
Job.TextColor3 = Color3.fromRGB(126, 145, 166)
Job.TextSize = 11
Job.TextXAlignment = Enum.TextXAlignment.Left
Job.Parent = Content

-- Keo UI
do
    local dragging = false
    local dragStart
    local startPosition

    Header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPosition = Main.Position
        end
    end)

    Header.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging then
            return
        end

        if input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        local delta = input.Position - dragStart
        Main.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end)
end

local minimized = false

Minimize.MouseButton1Click:Connect(function()
    minimized = not minimized
    Content.Visible = not minimized
    Main.Size = minimized and UDim2.fromOffset(430, 38) or UDim2.fromOffset(430, 190)
    Minimize.Text = minimized and "+" or "—"
end)

Close.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)

-- Tim TimeIn. Chi quet lai neu chua tim thay.
local serverStartedAt
local sourceInfo

task.spawn(function()
    while ScreenGui.Parent do
        if not serverStartedAt then
            local detectedTime, detectedInfo, errorText = detectServerStartTime()

            if detectedTime then
                serverStartedAt = detectedTime
                sourceInfo = detectedInfo

                Status.Text = "ĐÃ PHÁT HIỆN SERVER START TIME"
                Status.TextColor3 = Color3.fromRGB(109, 222, 161)

                Source.Text = string.format(
                    "Source: %s\nKhớp %d Location có cùng TimeIn",
                    sourceInfo.path,
                    sourceInfo.count
                )
            else
                Status.Text = errorText or "Chưa tìm thấy TimeIn"
                Status.TextColor3 = Color3.fromRGB(246, 197, 88)
                Uptime.Text = "Server Timer: đang chờ..."
                Source.Text = "Source: Workspace._WorldOrigin.Locations.<Location>.@TimeIn"
            end
        end

        if serverStartedAt then
            local serverNow = getServerNow()

            if serverNow then
                local uptimeSeconds = serverNow - serverStartedAt

                if uptimeSeconds >= 0 and uptimeSeconds < 31536000 then
                    Uptime.Text = "Server Timer: " .. formatDuration(uptimeSeconds)
                else
                    Status.Text = "TimeIn không hợp lệ hoặc vượt giới hạn"
                    Status.TextColor3 = Color3.fromRGB(239, 104, 104)
                    Uptime.Text = "Server Timer: không xác định"
                end
            else
                Status.Text = "Không đọc được Workspace:GetServerTimeNow()"
                Status.TextColor3 = Color3.fromRGB(239, 104, 104)
            end
        end

        task.wait(CONFIG.UpdateInterval)
    end
end)
