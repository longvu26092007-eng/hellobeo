-- checkcoor.lua
-- Hiển thị chính xác vị trí nhân vật đang đứng (HumanoidRootPart).
-- Cập nhật liên tục mỗi 0.1s. Có nút COPY để copy CFrame vào clipboard.

local lp = game.Players.LocalPlayer
local playerGui = lp:WaitForChild("PlayerGui")

-- ============ UI ============
local gui = Instance.new("ScreenGui")
gui.Name = "CheckCoorGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 320, 0, 180)
frame.Position = UDim2.new(0, 24, 0, 24)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -16, 0, 26)
title.Position = UDim2.new(0, 8, 0, 6)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "CheckCoor  -  vị trí nhân vật đang đứng"
title.TextColor3 = Color3.fromRGB(230, 230, 230)
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local coordLabel = Instance.new("TextLabel")
coordLabel.Name = "Coord"
coordLabel.Size = UDim2.new(1, -16, 0, 48)
coordLabel.Position = UDim2.new(0, 8, 0, 34)
coordLabel.BackgroundTransparency = 1
coordLabel.Font = Enum.Font.Code
coordLabel.TextColor3 = Color3.fromRGB(140, 220, 140)
coordLabel.TextSize = 14
coordLabel.TextWrapped = true
coordLabel.TextXAlignment = Enum.TextXAlignment.Left
coordLabel.TextYAlignment = Enum.TextYAlignment.Top
coordLabel.Parent = frame

local posLabel = Instance.new("TextLabel")
posLabel.Name = "Pos"
posLabel.Size = UDim2.new(1, -16, 0, 40)
posLabel.Position = UDim2.new(0, 8, 0, 84)
posLabel.BackgroundTransparency = 1
posLabel.Font = Enum.Font.Code
posLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
posLabel.TextSize = 12
posLabel.TextWrapped = true
posLabel.TextXAlignment = Enum.TextXAlignment.Left
posLabel.TextYAlignment = Enum.TextYAlignment.Top
posLabel.Parent = frame

-- nút COPY
local copyBtn = Instance.new("TextButton")
copyBtn.Size = UDim2.new(0, 140, 0, 32)
copyBtn.Position = UDim2.new(0, 8, 0, 130)
copyBtn.BackgroundColor3 = Color3.fromRGB(70, 140, 240)
copyBtn.BorderSizePixel = 0
copyBtn.Font = Enum.Font.GothamBold
copyBtn.Text = "COPY CFrame"
copyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
copyBtn.TextSize = 14
copyBtn.Parent = frame
Instance.new("UICorner", copyBtn).CornerRadius = UDim.new(0, 6)

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -16, 0, 16)
status.Position = UDim2.new(0, 8, 1, -20)
status.BackgroundTransparency = 1
status.Font = Enum.Font.Gotham
status.TextColor3 = Color3.fromRGB(180, 180, 190)
status.TextSize = 11
status.TextXAlignment = Enum.TextXAlignment.Left
status.Text = "ready"
status.Parent = frame

-- nút đóng
local close = Instance.new("TextButton")
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

close.MouseButton1Click:Connect(function() gui:Destroy() end)

-- ============ STATE ============
local currentCF = CFrame.new(0, 0, 0)
local currentStr = ""
local updateTick = 0

local function getHRP()
    local char = lp.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

local function formatCF(cf)
    -- format chuẩn để paste vào code
    return string.format("CFrame.new(%.6f, %.6f, %.6f)", cf.X, cf.Y, cf.Z)
end

-- ============ LOOP ============
task.spawn(function()
    while gui.Parent do
        local hrp = getHRP()
        if hrp then
            currentCF = hrp.CFrame
            currentStr = formatCF(currentCF)
            coordLabel.Text = currentStr
            posLabel.Text = string.format(
                "X=%.3f  Y=%.3f  Z=%.3f\nLookVector=(%.3f, %.3f, %.3f)",
                currentCF.X, currentCF.Y, currentCF.Z,
                currentCF.LookVector.X, currentCF.LookVector.Y, currentCF.LookVector.Z
            )
            updateTick = updateTick + 1
        else
            coordLabel.Text = "(chưa có nhân vật)"
            posLabel.Text = "đợi HumanoidRootPart load..."
        end
        task.wait(0.1)
    end
end)

-- ============ COPY ============
copyBtn.MouseButton1Click:Connect(function()
    local hrp = getHRP()
    if not hrp then
        status.Text = "ERR: chưa có nhân vật"
        status.TextColor3 = Color3.fromRGB(240, 100, 100)
        return
    end
    local text = formatCF(hrp.CFrame)
    -- thử setclipboard (nhiều executor có)
    local ok, err = pcall(function() setclipboard(text) end)
    if ok then
        status.Text = "copied: " .. text
        status.TextColor3 = Color3.fromRGB(140, 220, 140)
    else
        status.Text = "ERR setclipboard: " .. tostring(err)
        status.TextColor3 = Color3.fromRGB(240, 100, 100)
    end
end)

-- hiển thị ngay khi mở
local hrp0 = getHRP()
if hrp0 then
    currentCF = hrp0.CFrame
    currentStr = formatCF(currentCF)
    coordLabel.Text = currentStr
    posLabel.Text = string.format(
        "X=%.3f  Y=%.3f  Z=%.3f",
        currentCF.X, currentCF.Y, currentCF.Z
    )
end
