-- BaseShopClient.client.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local OpenBaseShop      = ReplicatedStorage:WaitForChild("OpenBaseShop")
local remotesFolder     = ReplicatedStorage:WaitForChild("ClassRemotes")
local RequestClassEquip = remotesFolder:WaitForChild("RequestClassEquip")
local ChangeStealSpeed  = ReplicatedStorage:WaitForChild("ChangeStealSpeed")
local ChangeMineSpeed   = ReplicatedStorage:WaitForChild("ChangeMineSpeed")
local ChangeEntryTime   = ReplicatedStorage:WaitForChild("ChangeEntryTime")
local ChangeStorageSize = ReplicatedStorage:WaitForChild("ChangeStorageSize")

local playerGui = player:WaitForChild("PlayerGui")

-- Build shop GUI
local shopGui = Instance.new("ScreenGui")
shopGui.Name = "BaseShopGui"
shopGui.ResetOnSpawn = false

local frame = Instance.new("Frame")
frame.Name = "ShopFrame"
frame.Size = UDim2.new(0, 300, 0, 260)
frame.Position = UDim2.new(0.5, -150, 0.5, -130)
frame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
frame.BorderSizePixel = 0
frame.Parent = shopGui

-- Class selection buttons
local archerBtn = Instance.new("TextButton")
archerBtn.Name = "ArcherButton"
archerBtn.Size = UDim2.new(0.5, -6, 0, 40)
archerBtn.Position = UDim2.new(0, 6, 0, 6)
archerBtn.Text = "Archer"
archerBtn.TextScaled = true
archerBtn.Parent = frame

local ninjaBtn = Instance.new("TextButton")
ninjaBtn.Name = "NinjaButton"
ninjaBtn.Size = UDim2.new(0.5, -6, 0, 40)
ninjaBtn.Position = UDim2.new(0.5, 6, 0, 6)
ninjaBtn.Text = "Ninja"
ninjaBtn.TextScaled = true
ninjaBtn.Parent = frame

-- Helper to create upgrade buttons
local function createUpgradeBtn(name, text, posY, onClick)
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Size = UDim2.new(1, -12, 0, 40)
    btn.Position = UDim2.new(0, 6, 0, posY)
    btn.Text = text
    btn.TextScaled = true
    btn.Parent = frame
    btn.MouseButton1Click:Connect(function()
        onClick()
        shopGui.Enabled = false
    end)
    return btn
end

-- Upgrade buttons under class row
createUpgradeBtn("StealUpgradeButton", "Upgrade Steal Speed",   56, function()
    ChangeStealSpeed:FireServer(10)
end)
createUpgradeBtn("MineUpgradeButton",  "Upgrade Mine Speed",    102, function()
    ChangeMineSpeed:FireServer(1)
end)
createUpgradeBtn("EntryUpgradeButton", "Upgrade Entry Time",    148, function()
    ChangeEntryTime:FireServer()
end)
createUpgradeBtn("StorageUpgradeButton","Upgrade Storage Size", 194, function()
    ChangeStorageSize:FireServer()
end)

-- Wire up class selection
archerBtn.MouseButton1Click:Connect(function()
    RequestClassEquip:FireServer("Archer", 0)
    shopGui.Enabled = false
end)

ninjaBtn.MouseButton1Click:Connect(function()
    RequestClassEquip:FireServer("Ninja", 0)
    shopGui.Enabled = false
end)

-- Close with Escape key
UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.Escape and shopGui.Enabled then
        shopGui.Enabled = false
    end
end)

-- Show shop when server fires event
OpenBaseShop.OnClientEvent:Connect(function()
    if not shopGui.Parent then shopGui.Parent = playerGui end
    shopGui.Enabled = true
end) 