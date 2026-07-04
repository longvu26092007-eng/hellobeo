-- CoorPicker.lua
-- UI lấy toạ độ đứng hiện tại, ghi vào coor.txt (ghi đè)
-- Yêu cầu executor có: writefile, readfile, makefolder, isfolder

local lp = game.Players.LocalPlayer
local playerGui = lp:WaitForChild("PlayerGui")

-- ============== CONFIG ==============
local FILE_NAME = "coor.txt"
local FILE_FOLDER = ""          -- để trống = thư mục workspace root
-- ====================================

-- tạo folder nếu cần
if FILE_FOLDER ~= "" and not isfolder(FILE_FOLDER) then
    makefolder(FILE_FOLDER)
end
local FILE_PATH = FILE_FOLDER == "" and FILE_NAME or (FILE_FOLDER .. "/" .. FILE_NAME)

-- ============== STATE ==============
local lastSaved = nil
local totalSaved = 0
-- ===================================

-- tạo ScreenGui
local gui = Instance.new("ScreenGui")
gui.Name = "CoorPickerGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

-- khung chính
local frame = Instance.new("Frame")
frame.Name = "Main"
frame.Size = UDim2.new(0, 280, 0, 150)
frame.Position = UDim2.new(0, 24, 0, 24)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

-- title
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -16, 0, 26)
title.Position = UDim2.new(0, 8, 0, 6)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "Coor Picker  -  ghi vào coor.txt"
title.TextColor3 = Color3.fromRGB(230, 230, 230)
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

-- dòng toạ độ hiện tại
local coordLabel = Instance.new("TextLabel")
coordLabel.Name = "Coord"
coordLabel.Size = UDim2.new(1, -16, 0, 22)
coordLabel.Position = UDim2.new(0, 8, 0, 36)
coordLabel.BackgroundTransparency = 1
coordLabel.Font = Enum.Font.Code
coordLabel.TextColor3 = Color3.fromRGB(140, 220, 140)
coordLabel.TextSize = 13
coordLabel.TextWrapped = true
coordLabel.TextXAlignment = Enum.TextXAlignment.Left
coordLabel.Parent = frame

-- hint nhỏ
local hint = Instance.new("TextLabel")
hint.Size = UDim2.new(1, -16, 0, 16)
hint.Position = UDim2.new(0, 8, 0, 60)
hint.BackgroundTransparency = 1
hint.Font = Enum.Font.Gotham
hint.TextColor3 = Color3.fromRGB(160, 160, 170)
hint.TextSize = 11
hint.Text = "định dạng: CFrame.new(X, Y, Z)"
hint.TextXAlignment = Enum.TextXAlignment.Left
hint.Parent = frame

-- nút TAKE
local btn = Instance.new("TextButton")
btn.Name = "TakeBtn"
btn.Size = UDim2.new(0, 120, 0, 34)
btn.Position = UDim2.new(0, 8, 0, 84)
btn.BackgroundColor3 = Color3.fromRGB(70, 140, 240)
btn.BorderSizePixel = 0
btn.Font = Enum.Font.GothamBold
btn.Text = "TAKE"
btn.TextColor3 = Color3.fromRGB(255, 255, 255)
btn.TextSize = 15
btn.AutoButtonColor = true
btn.Parent = frame
Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

-- nút đóng
local close = Instance.new("TextButton")
close.Name = "Close"
close.Size = UDim2.new(0, 32, 0, 32)
close.Position = UDim2.new(1, -40, 0, 8)
close.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
close.BorderSizePixel = 0
close.Font = Enum.Font.GothamBold
close.Text = "X"
close.TextColor3 = Color3.fromRGB(255, 255, 255)
close.TextSize = 16
close.Parent = frame
Instance.new("UICorner", close).CornerRadius = UDim.new(1, 0)

-- nút mở file (đọc lại nội dung)
local readBtn = Instance.new("TextButton")
readBtn.Name = "ReadBtn"
readBtn.Size = UDim2.new(0, 120, 0, 34)
readBtn.Position = UDim2.new(0, 136, 0, 84)
readBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 90)
readBtn.BorderSizePixel = 0
readBtn.Font = Enum.Font.GothamBold
readBtn.Text = "READ"
readBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
readBtn.TextSize = 15
readBtn.Parent = frame
Instance.new("UICorner", readBtn).CornerRadius = UDim.new(0, 6)

-- status bar dưới
local status = Instance.new("TextLabel")
status.Name = "Status"
status.Size = UDim2.new(1, -16, 0, 16)
status.Position = UDim2.new(0, 8, 1, -22)
status.BackgroundTransparency = 1
status.Font = Enum.Font.Gotham
status.TextColor3 = Color3.fromRGB(200, 200, 210)
status.TextSize = 11
status.TextXAlignment = Enum.TextXAlignment.Left
status.Text = "saved: 0"
status.Parent = frame

-- ============ helpers =============
local function getHRP()
    local char = lp.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

local function formatCF(cf)
    return string.format("CFrame.new(%.6f, %.6f, %.6f)", cf.X, cf.Y, cf.Z)
end

local function refreshLabel()
    local hrp = getHRP()
    if not hrp then
        coordLabel.Text = "(chưa có nhân vật)"
        return
    end
    coordLabel.Text = formatCF(hrp.CFrame)
end

local function saveCoord()
    local hrp = getHRP()
    if not hrp then
        status.Text = "ERR: chưa có HumanoidRootPart"
        status.TextColor3 = Color3.fromRGB(240, 100, 100)
        return
    end
    local line = formatCF(hrp.CFrame) .. "\n"
    local ok, err = pcall(function() writefile(FILE_PATH, line) end)
    if ok then
        lastSaved = line
        totalSaved = totalSaved + 1
        status.Text = "saved: " .. totalSaved .. "  ->  " .. FILE_PATH
        status.TextColor3 = Color3.fromRGB(140, 220, 140)
        refreshLabel()
    else
        status.Text = "ERR writefile: " .. tostring(err)
        status.TextColor3 = Color3.fromRGB(240, 100, 100)
    end
end

local function readFile()
    local ok, content = pcall(readfile, FILE_PATH)
    if ok then
        status.Text = "read ok: " .. #content .. " bytes  ->  " .. FILE_PATH
        status.TextColor3 = Color3.fromRGB(140, 220, 140)
    else
        status.Text = "ERR readfile: " .. tostring(content)
        status.TextColor3 = Color3.fromRGB(240, 100, 100)
    end
end

-- ============ hook nút ============
btn.MouseButton1Click:Connect(saveCoord)
readBtn.MouseButton1Click:Connect(readFile)
close.MouseButton1Click:Connect(function()
    gui:Destroy()
end)

-- ============ loop refresh ===========
task.spawn(function()
    while gui.Parent do
        refreshLabel()
        task.wait(0.4)
    end
end)

-- info khởi tạo
status.Text = "ready  ->  " .. FILE_PATH
status.TextColor3 = Color3.fromRGB(200, 200, 210)
refreshLabel()
