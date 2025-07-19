local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local leaderstats = player:WaitForChild("leaderstats")
local goldValue = leaderstats:WaitForChild("Gold")

-- UI setup
local gui = Instance.new("ScreenGui")
gui.Name = "GoldGainGui"
gui.ResetOnSpawn = false

-- Ensure PlayerGui exists (it resets each respawn)
local function parentGui()
    local pg = player:WaitForChild("PlayerGui")
    gui.Parent = pg
end
parentGui()
player.CharacterAdded:Connect(parentGui)

-- stack offset tracker
local activeCount = 0

local function showGoldGain(amount)
    activeCount += 1
    local basePosX = 0.55  -- further right of center
    local basePosY = 0.42 -- a bit higher above crosshair
    local label = Instance.new("TextLabel")
    label.AnchorPoint = Vector2.new(0.5, 0.5)
    label.Position = UDim2.fromScale(basePosX, basePosY - (activeCount-1)*0.05)
    label.Size = UDim2.fromScale(0.25, 0.05)
    label.BackgroundTransparency = 1
    label.Text = string.format("+%d Gold", amount)
    label.Font = Enum.Font.SourceSansBold
    label.TextScaled = true
    label.TextColor3 = Color3.fromRGB(255, 215, 0) -- gold color
    label.TextStrokeColor3 = Color3.new(0,0,0)
    label.TextStrokeTransparency = 0
    label.Parent = gui

    local tweenInfo = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.5) -- 0.5s delay before fade
    local endPos = UDim2.new(label.Position.X.Scale, label.Position.X.Offset, label.Position.Y.Scale - 0.05, label.Position.Y.Offset - 20)
    local goal = {Position = endPos, TextTransparency = 1, TextStrokeTransparency = 1}
    local tween = TweenService:Create(label, tweenInfo, goal)
    tween.Completed:Connect(function()
        activeCount -= 1
        label:Destroy()
    end)
    tween:Play()
end

local lastGold = goldValue.Value

goldValue:GetPropertyChangedSignal("Value"):Connect(function()
    local newVal = goldValue.Value
    local diff = newVal - lastGold
    if diff > 0 then
        showGoldGain(diff)
    end
    lastGold = newVal
end) 