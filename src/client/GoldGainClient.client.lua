local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SoundAssets = require(game:GetService("ReplicatedStorage"):WaitForChild("SoundAssets"))

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

-- Gold gain sound
local goldSound = Instance.new("Sound")
goldSound.Name = "GoldSound"
goldSound.SoundId = "rbxassetid://" .. SoundAssets.Gold
goldSound.Volume = 0.6
goldSound.Parent = gui

-- stack offset tracker
local activeCount = 0

-- When a kill indicator fires, we'll set this to suppress duplicate gold gain popup
local lastKillReward = 0
local lastKillTime = 0

-- forward declaration
local function showKillIndicator(_)
    -- will be overwritten later
end

-- Remote for kill indicator
local function connectKillRemote(remote)
    if remote and remote:IsA("RemoteEvent") then
        remote.OnClientEvent:Connect(function(reward)
            lastKillReward = reward
            lastKillTime = tick()
            showKillIndicator(reward)
        end)
    end
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local killRemote = ReplicatedStorage:FindFirstChild("KillGoldIndicator")
if killRemote then connectKillRemote(killRemote) end

ReplicatedStorage.ChildAdded:Connect(function(child)
    if child.Name == "KillGoldIndicator" then
        connectKillRemote(child)
    end
end)

function showKillIndicator(goldReward)
    activeCount += 1
    local basePosX = 0.55
    local basePosY = 0.35 -- slightly above gold gain labels
    local label = Instance.new("TextLabel")
    label.RichText = true
    label.AnchorPoint = Vector2.new(0.5, 0.5)
    label.Position = UDim2.fromScale(basePosX, basePosY - (activeCount-1)*0.06)
    label.Size = UDim2.fromScale(0.35, 0.06)
    label.BackgroundTransparency = 1
    label.Text = string.format('<font color="#FF0000">+1 kill</font> <font color="#FFD700">(+%d gold)</font>', goldReward)
    label.Font = Enum.Font.SourceSansBold
    label.TextScaled = true
    label.TextStrokeColor3 = Color3.new(0,0,0)
    label.TextStrokeTransparency = 0
    label.Parent = gui

    local tweenInfo = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.6)
    local endPos = UDim2.new(label.Position.X.Scale, label.Position.X.Offset, label.Position.Y.Scale - 0.05, label.Position.Y.Offset - 25)
    local goal = {Position = endPos, TextTransparency = 1, TextStrokeTransparency = 1}
    local tween = TweenService:Create(label, tweenInfo, goal)
    tween.Completed:Connect(function()
        activeCount -= 1
        label:Destroy()
    end)
    tween:Play()
end

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
        if (tick() - lastKillTime) < 1 and diff == lastKillReward then
            -- Suppress duplicate gold gain following kill indicator
            lastKillReward = 0
        else
            showGoldGain(diff)
        end
        goldSound:Play()
    end
    lastGold = newVal
end) 