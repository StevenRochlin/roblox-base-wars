-- BaseInputClient.lua (StarterPlayerScripts)
print("BaseInputClient loaded")

-- =========================================================================--
-- 1) SERVICES & REMOTES
-- =========================================================================--
print("BaseInputClient.luau loaded")
local UserInputService    = game:GetService("UserInputService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local Players             = game:GetService("Players")
local RunService          = game:GetService("RunService")

local player              = Players.LocalPlayer
local playerGui           = player:WaitForChild("PlayerGui")

-- existing remotes
local RequestBaseCreation = ReplicatedStorage:WaitForChild("RequestBaseCreation")
local DisplayBasePrompt   = ReplicatedStorage:WaitForChild("DisplayBasePrompt")
local UpdateBaseEntryGUI  = ReplicatedStorage:WaitForChild("UpdateBaseEntryGUI")
local BasePlacementError = ReplicatedStorage:WaitForChild("BasePlacementError")
local BaseStolenWarning  = ReplicatedStorage:WaitForChild("BaseStolenWarning")

-- new shop remotes
local OpenBaseShop        = ReplicatedStorage:WaitForChild("OpenBaseShop")
local ChangeStealSpeed    = ReplicatedStorage:WaitForChild("ChangeStealSpeed")
local ChangeMineSpeed     = ReplicatedStorage:WaitForChild("ChangeMineSpeed")
local ChangeEntryTime     = ReplicatedStorage:WaitForChild("ChangeEntryTime")
local ChangeStorageSize   = ReplicatedStorage:WaitForChild("ChangeStorageSize")
local ChangeKillBounty    = ReplicatedStorage:WaitForChild("ChangeKillBounty")
-- Class equip remote
local classRemotes         = ReplicatedStorage:WaitForChild("ClassRemotes")
local RequestClassEquip   = classRemotes:WaitForChild("RequestClassEquip")

-- upgrade configuration
local stealBaseIncrement = 10
local stealUpgradeCosts = {100, 200, 400, 800, 1600, 3200}
local purpleColor = Color3.fromRGB(128, 0, 128)
local orangeColor = Color3.fromRGB(255, 165, 0)
local mineBaseIncrement = 2
local mineUpgradeCosts = {60, 120, 240, 480, 960, 1920} -- unchanged
local skyBlueColor = Color3.fromRGB(135, 206, 235)
local entryTimeDecrement  = 0.5
local entryUpgradeCosts   = {80, 160, 320}
local turquoiseColor      = Color3.fromRGB(64, 224, 208)
local storageLevels       = {100, 250, 500, 1000, 2500, 5000, 10000}
local storageColors       = {
	[1] = Color3.new(1,1,1),
	[2] = Color3.fromRGB(0,255,0),
	[3] = Color3.fromRGB(0, 242, 255),
	[4] = Color3.fromRGB(21, 0, 255),
	[5] = Color3.fromRGB(140, 0, 255),
	[6] = Color3.fromRGB(255, 0, 0),
	[7] = Color3.fromRGB(0, 0, 0),
}
local goldColor           = Color3.fromRGB(255, 215, 0)
local redColor            = Color3.fromRGB(255,0,0)
local killBountyRewards   = {15,45,90,135,180,225,270}
local killBountyCosts     = {0,120,240,480,960,1920,3840} -- index matches level

-- =========================================================================--
-- 2) STATE VARIABLES
-- =========================================================================--
local baseCreationAttempted = false
local promptGui             = nil

-- timer state
local entryTimerConnection    = nil
local serverEntryStartTime    = 0
local entryDuration           = 0

-- =========================================================================--
-- 3) GUI CREATION
-- =========================================================================--

-- 3A) Base-entry GUI (timer + status)
local baseEntryGui = Instance.new("ScreenGui")
baseEntryGui.Name            = "BaseEntryGui"
baseEntryGui.ResetOnSpawn    = false
baseEntryGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
baseEntryGui.DisplayOrder    = 10
baseEntryGui.Parent          = playerGui

local entryTimerLabel = Instance.new("TextLabel")
entryTimerLabel.Name             = "EntryTimerLabel"
entryTimerLabel.Size             = UDim2.new(0.25,0,0.05,0)
entryTimerLabel.Position         = UDim2.new(0.5,0,0.85,0)
entryTimerLabel.AnchorPoint      = Vector2.new(0.5,0.5)
entryTimerLabel.BackgroundColor3 = Color3.fromRGB(30,30,30)
entryTimerLabel.BackgroundTransparency = 0.2
entryTimerLabel.TextColor3       = Color3.fromRGB(220,220,220)
entryTimerLabel.Font             = Enum.Font.SourceSansSemibold
entryTimerLabel.TextScaled       = true
entryTimerLabel.Visible          = false
entryTimerLabel.Text             = "Entering Base: 0.0s"
entryTimerLabel.Parent           = baseEntryGui

local baseStatusLabel = Instance.new("TextLabel")
baseStatusLabel.Name             = "BaseStatusLabel"
baseStatusLabel.Size             = UDim2.new(0.3,0,0.08,0)
baseStatusLabel.Position         = UDim2.new(0.5,0,0.88,0) -- moved lower
baseStatusLabel.AnchorPoint      = Vector2.new(0.5,0.5)
baseStatusLabel.BackgroundColor3 = Color3.fromRGB(20,80,20)
baseStatusLabel.BackgroundTransparency = 0.1
baseStatusLabel.TextColor3       = Color3.fromRGB(180,255,180)
baseStatusLabel.Font             = Enum.Font.SourceSansBold
baseStatusLabel.TextScaled       = true
baseStatusLabel.Visible          = false
baseStatusLabel.Text             = "You have entered your base"
baseStatusLabel.Parent           = baseEntryGui

-- 3B) Shop GUI (hidden until opened)
local shopGui = Instance.new("ScreenGui")
shopGui.Name         = "BaseShopGui"
shopGui.ResetOnSpawn = false
shopGui.Enabled      = false
shopGui.Parent       = playerGui

local shopFrame = Instance.new("Frame")
shopFrame.Size               = UDim2.new(0,760,0,400) -- extra space for cleaner layout
shopFrame.Position           = UDim2.new(0.5,-390,0.5,-180) -- shifted slightly left
shopFrame.BackgroundColor3   = Color3.fromRGB(30,30,30)
shopFrame.BackgroundTransparency = 0.3
shopFrame.Parent             = shopGui

-- Close button (top‐right corner)
local closeBtn = Instance.new("TextButton")
closeBtn.Name               = "CloseButton"
closeBtn.Size               = UDim2.new(0, 36, 0, 36)
closeBtn.Position           = UDim2.new(1, -30, 0, -10)
closeBtn.AnchorPoint        = Vector2.new(0, 0)
closeBtn.BackgroundColor3   = Color3.fromRGB(60, 60, 60)
closeBtn.TextColor3         = Color3.fromRGB(255, 255, 255)
closeBtn.Font               = Enum.Font.SourceSansBold
closeBtn.Text               = "✕"
closeBtn.AutoButtonColor    = true
closeBtn.Parent             = shopFrame

closeBtn.MouseButton1Click:Connect(function()
	shopGui.Enabled = false
end)


local title = Instance.new("TextLabel")
title.Size                 = UDim2.new(1,0,0,30)
title.BackgroundTransparency = 1
title.Text                 = "Base Shop"
title.Font                 = Enum.Font.SourceSansBold
title.TextScaled           = true
title.Parent               = shopFrame

-- Token label
local tokenLabel = Instance.new("TextLabel")
tokenLabel.Name = "TokenLabel"
tokenLabel.Size = UDim2.new(0, 100, 0, 20)
tokenLabel.Position = UDim2.new(0.5, -10, 0, 0)
tokenLabel.AnchorPoint = Vector2.new(0.5, 0)
tokenLabel.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
tokenLabel.BackgroundTransparency = 0.3
tokenLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
tokenLabel.TextScaled = true
tokenLabel.Font = Enum.Font.SourceSansBold
tokenLabel.Text = "Tokens: " .. (player:GetAttribute("ClassTokens") or 0)
tokenLabel.Parent = shopFrame

-- Forward-declare descriptions table so linter recognizes variable before first use
local descriptions

-- Forward declare selection helper for linter
local setSelectedItem

local function updateTokenLabel()
    tokenLabel.Text = "Tokens: " .. tostring(player:GetAttribute("ClassTokens") or 0)
end
updateTokenLabel()
player:GetAttributeChangedSignal("ClassTokens"):Connect(updateTokenLabel)

-- Class selection buttons (insert above upgrades)
local archerBtn = Instance.new("TextButton")
archerBtn.Name = "ArcherButton"
archerBtn.Size = UDim2.new(0, 100, 0, 45)
archerBtn.Position = UDim2.new(0, -20, 0, 180)
archerBtn.Text = "Archer"
archerBtn.TextScaled = true
archerBtn.Parent = shopFrame
archerBtn.MouseButton1Click:Connect(function()
    setSelectedItem("Archer", descriptions.Archer, function()
        RequestClassEquip:FireServer("Archer", 0)
    end)
end)

local ninjaBtn = Instance.new("TextButton")
ninjaBtn.Name = "NinjaButton"
ninjaBtn.Size = UDim2.new(0, 100, 0, 45)
ninjaBtn.Position = UDim2.new(0, 100, 0, 180)
ninjaBtn.Text = "Ninja"
ninjaBtn.TextScaled = true
ninjaBtn.Parent = shopFrame
ninjaBtn.MouseButton1Click:Connect(function()
    setSelectedItem("Ninja", descriptions.Ninja, function()
        RequestClassEquip:FireServer("Ninja", 0)
    end)
end)

-- Pirate class button
local pirateBtn = Instance.new("TextButton")
pirateBtn.Name = "PirateButton"
pirateBtn.Size = UDim2.new(0, 100, 0, 45)
pirateBtn.Position = UDim2.new(0, 220, 0, 180)
pirateBtn.Text = "Pirate"
pirateBtn.TextScaled = true
pirateBtn.Parent = shopFrame
pirateBtn.MouseButton1Click:Connect(function()
    setSelectedItem("Pirate", descriptions.Pirate, function()
        RequestClassEquip:FireServer("Pirate", 0)
    end)
end)

-- Farmer class button
local farmerBtn = Instance.new("TextButton")
farmerBtn.Name = "FarmerButton"
farmerBtn.Size = UDim2.new(0, 100, 0, 45)
farmerBtn.Position = UDim2.new(0, 340, 0, 180)
farmerBtn.Text = "Farmer"
farmerBtn.TextScaled = true
farmerBtn.Parent = shopFrame
farmerBtn.MouseButton1Click:Connect(function()
    setSelectedItem("Farmer", descriptions.Farmer, function()
        RequestClassEquip:FireServer("Farmer", 0)
    end)
end)

-- /////////////////////////////////////////////////////////////////
-- Subclass purchase buttons (cost 500 Gold each)
-- Coordinates: align under each class column (x=10,140,270,400) 
-- First subclass row y=260, second y=330
-- Helper to create button
local subclassButtons = {}
local function createSubclassButton(displayName, className, posX, posY)
    local btn = Instance.new("TextButton")
    btn.Name = className .. "Button"
    btn.Size = UDim2.new(0, 100, 0, 65)
    btn.Position = UDim2.new(0, posX, 0, posY)
    btn.Text = displayName
    btn.TextWrapped = true
    btn.TextScaled = true
    -- cost label
    local costLbl = Instance.new("TextLabel")
    costLbl.Name = "CostLabel"
    costLbl.Size = UDim2.new(1,0,0,18)
    costLbl.Position = UDim2.new(0,0,1,-18) -- automatically adjusts with new height
    costLbl.BackgroundTransparency = 1
    costLbl.Font = Enum.Font.SourceSansBold
    costLbl.TextScaled = true
    costLbl.Text = "(1 Token)"
    costLbl.Parent = btn
    btn.Parent = shopFrame
    btn.MouseButton1Click:Connect(function()
        setSelectedItem(displayName, descriptions[className] or "Subclass description.", function()
            RequestClassEquip:FireServer(className, 0)
        end)
    end)
    table.insert(subclassButtons, {button = btn, costLabel = costLbl, ownedAttr = "Owned_" .. className .. "_T0"})
end

-- Archer subclasses
createSubclassButton("Musketeer", "Musketeer", -20, 230)
createSubclassButton("Ranger", "Ranger", -20, 310)

-- Ninja subclasses
createSubclassButton("Samurai", "Samurai", 100, 230)
createSubclassButton("Shinobi", "Shinobi", 100, 310)

-- Pirate subclasses
createSubclassButton("Outlaw", "Outlaw", 220, 230)
createSubclassButton("Buccaneer", "Buccaneer", 220, 310)

-- Farmer subclasses
createSubclassButton("Nice Farmer", "NiceFarmer", 340, 230)
createSubclassButton("Toxic Farmer", "ToxicFarmer", 340, 310)

-- Function to enable/disable subclass buttons based on tokens
local function updateSubclassButtons()
    local tokens = player:GetAttribute("ClassTokens") or 0
    for _, info in ipairs(subclassButtons) do
        local btn = info.button
        local owned = player:GetAttribute(info.ownedAttr) or false
        local enabled = owned or tokens > 0
        btn.AutoButtonColor = true
        btn.TextColor3 = Color3.new(1,1,1)
        if info.costLabel then
            info.costLabel.TextColor3 = tokens > 0 and Color3.fromRGB(0,255,0) or Color3.fromRGB(255,0,0)
        end
    end
end
updateSubclassButtons()
player:GetAttributeChangedSignal("ClassTokens"):Connect(updateSubclassButtons)

local fastStealBtn = Instance.new("TextButton")
fastStealBtn.Size = UDim2.new(0,120,0,60)
fastStealBtn.Position = UDim2.new(0,100,0,50)
fastStealBtn.BackgroundColor3 = purpleColor
fastStealBtn.BorderSizePixel = 0
fastStealBtn.Parent = shopFrame

local stealLabel = Instance.new("TextLabel")
stealLabel.Name = "StealUpgradeTitle"
stealLabel.Size = UDim2.new(1,0,0,20)
stealLabel.Position = UDim2.new(0,0,0,0)
stealLabel.BackgroundTransparency = 1
stealLabel.Text = "Gold Steal Amount"
stealLabel.Font = Enum.Font.SourceSansBold
stealLabel.TextColor3 = Color3.new(1,1,1)
stealLabel.TextStrokeColor3 = Color3.new(0,0,0)
stealLabel.TextStrokeTransparency = 0
stealLabel.TextScaled = true
stealLabel.Parent = fastStealBtn

local stealCostLabel = Instance.new("TextLabel")
stealCostLabel.Name = "StealUpgradeCost"
stealCostLabel.Size = UDim2.new(1,0,0,20)
stealCostLabel.Position = UDim2.new(0,0,1,-20)
stealCostLabel.BackgroundTransparency = 1
stealCostLabel.Text = ""
stealCostLabel.Font = Enum.Font.SourceSansBold
stealCostLabel.TextColor3 = orangeColor
stealCostLabel.TextStrokeColor3 = Color3.new(0,0,0)
stealCostLabel.TextStrokeTransparency = 0
stealCostLabel.TextScaled = true
stealCostLabel.Parent = fastStealBtn

-- New level label under title
local levelLabel = Instance.new("TextLabel")
levelLabel.Name = "StealUpgradeLevel"
levelLabel.Size = UDim2.new(1,0,0,20)
levelLabel.Position = UDim2.new(0,0,0,20)
levelLabel.BackgroundTransparency = 1
levelLabel.Text = "[Lvl 1]"
levelLabel.Font = Enum.Font.SourceSansBold
levelLabel.TextColor3 = Color3.new(1,1,1)
levelLabel.TextStrokeColor3 = Color3.new(0,0,0)
levelLabel.TextStrokeTransparency = 0
levelLabel.TextScaled = true
levelLabel.Parent = fastStealBtn

fastStealBtn.MouseButton1Click:Connect(function()
    setSelectedItem("Steal Amount", descriptions.StealUpgrade, function()
        ChangeStealSpeed:FireServer(stealBaseIncrement)
    end)
end)

local function updateStealUpgradeButton()
	local amt = player:GetAttribute("StealAmount") or stealBaseIncrement
	local level = amt / stealBaseIncrement
	local cost = stealUpgradeCosts[level] or stealUpgradeCosts[#stealUpgradeCosts]
	stealCostLabel.Text = cost .. " Gold"
	levelLabel.Text = "[Lvl " .. level .. "]"
end
updateStealUpgradeButton()
player:GetAttributeChangedSignal("StealAmount"):Connect(updateStealUpgradeButton)

-- New auto miner upgrade button
local autoMineBtn = Instance.new("TextButton")
autoMineBtn.Size = UDim2.new(0,120,0,60)
autoMineBtn.Position = UDim2.new(0,240,0,50)
autoMineBtn.BackgroundColor3 = skyBlueColor
autoMineBtn.BorderSizePixel = 0
autoMineBtn.Parent = shopFrame

local autoMineTitle = Instance.new("TextLabel")
autoMineTitle.Name = "AutoMineTitle"
autoMineTitle.Size = UDim2.new(1,0,0,20)
autoMineTitle.Position = UDim2.new(0,0,0,0)
autoMineTitle.BackgroundTransparency = 1
autoMineTitle.Text = "Auto Gold Miner (+2)"
autoMineTitle.Font = Enum.Font.SourceSansBold
autoMineTitle.TextColor3 = Color3.new(1,1,1)
autoMineTitle.TextStrokeColor3 = Color3.new(0,0,0)
autoMineTitle.TextStrokeTransparency = 0
autoMineTitle.TextScaled = true
autoMineTitle.Parent = autoMineBtn

local autoMineLevelLabel = Instance.new("TextLabel")
autoMineLevelLabel.Name = "AutoMineLevel"
autoMineLevelLabel.Size = UDim2.new(1,0,0,20)
autoMineLevelLabel.Position = UDim2.new(0,0,0,20)
autoMineLevelLabel.BackgroundTransparency = 1
autoMineLevelLabel.Text = "[Lvl 1]"
autoMineLevelLabel.Font = Enum.Font.SourceSansBold
autoMineLevelLabel.TextColor3 = Color3.new(1,1,1)
autoMineLevelLabel.TextStrokeColor3 = Color3.new(0,0,0)
autoMineLevelLabel.TextStrokeTransparency = 0
autoMineLevelLabel.TextScaled = true
autoMineLevelLabel.Parent = autoMineBtn

local autoMineCostLabel = Instance.new("TextLabel")
autoMineCostLabel.Name = "AutoMineCost"
autoMineCostLabel.Size = UDim2.new(1,0,0,20)
autoMineCostLabel.Position = UDim2.new(0,0,1,-20)
autoMineCostLabel.BackgroundTransparency = 1
autoMineCostLabel.Text = ""
autoMineCostLabel.Font = Enum.Font.SourceSansBold
autoMineCostLabel.TextColor3 = orangeColor
autoMineCostLabel.TextStrokeColor3 = Color3.new(0,0,0)
autoMineCostLabel.TextStrokeTransparency = 0
autoMineCostLabel.TextScaled = true
autoMineCostLabel.Parent = autoMineBtn

autoMineBtn.MouseButton1Click:Connect(function()
    setSelectedItem("Auto Miner", descriptions.AutoMine, function()
        ChangeMineSpeed:FireServer(mineBaseIncrement)
    end)
end)

local function updateAutoMineButton()
	local rate = player:GetAttribute("MineSpeed") or 0
	local level = rate / mineBaseIncrement -- 0-based upgrade count
	local costIndex = level + 1
	local cost = mineUpgradeCosts[costIndex] or mineUpgradeCosts[#mineUpgradeCosts]
	autoMineLevelLabel.Text = "[Lvl " .. (level + 1) .. "]"
	autoMineCostLabel.Text = cost .. " Gold"
end
updateAutoMineButton()
player:GetAttributeChangedSignal("MineSpeed"):Connect(updateAutoMineButton)

-- Entry Time upgrade button
local entryBtn = Instance.new("TextButton")
entryBtn.Size = UDim2.new(0,120,0,60)
entryBtn.Position = UDim2.new(0,-20,0,120)
entryBtn.BackgroundColor3 = turquoiseColor
entryBtn.BorderSizePixel = 0
entryBtn.Parent = shopFrame

local entryTitle = Instance.new("TextLabel")
entryTitle.Name = "EntryUpgradeTitle"
entryTitle.Size = UDim2.new(1,0,0,20)
entryTitle.Position = UDim2.new(0,0,0,0)
entryTitle.BackgroundTransparency = 1
entryTitle.Text = "Entry Time"
entryTitle.Font = Enum.Font.SourceSansBold
entryTitle.TextColor3 = Color3.new(1,1,1)
entryTitle.TextStrokeColor3 = Color3.new(0,0,0)
entryTitle.TextStrokeTransparency = 0
entryTitle.TextScaled = true
entryTitle.Parent = entryBtn

local entryLevelLabel = Instance.new("TextLabel")
entryLevelLabel.Name = "EntryUpgradeLevel"
entryLevelLabel.Size = UDim2.new(1,0,0,20)
entryLevelLabel.Position = UDim2.new(0,0,0,20)
entryLevelLabel.BackgroundTransparency = 1
entryLevelLabel.Text = "[Lvl 1]"
entryLevelLabel.Font = Enum.Font.SourceSansBold
entryLevelLabel.TextColor3 = Color3.new(1,1,1)
entryLevelLabel.TextStrokeColor3 = Color3.new(0,0,0)
entryLevelLabel.TextStrokeTransparency = 0
entryLevelLabel.TextScaled = true
entryLevelLabel.Parent = entryBtn

local entryCostLabel = Instance.new("TextLabel")
entryCostLabel.Name = "EntryUpgradeCost"
entryCostLabel.Size = UDim2.new(1,0,0,20)
entryCostLabel.Position = UDim2.new(0,0,1,-20)
entryCostLabel.BackgroundTransparency = 1
entryCostLabel.Text = ""
entryCostLabel.Font = Enum.Font.SourceSansBold
entryCostLabel.TextColor3 = orangeColor
entryCostLabel.TextStrokeColor3 = Color3.new(0,0,0)
entryCostLabel.TextStrokeTransparency = 0
entryCostLabel.TextScaled = true
entryCostLabel.Parent = entryBtn

entryBtn.MouseButton1Click:Connect(function()
    setSelectedItem("Entry Timer", descriptions.EntryTime, function()
        ChangeEntryTime:FireServer(entryTimeDecrement)
    end)
end)

local function updateEntryButton()
	local level = player:GetAttribute("EntryLevel") or 0
	local cost = entryUpgradeCosts[level + 1] or entryUpgradeCosts[#entryUpgradeCosts]
	entryLevelLabel.Text = "[Lvl " .. (level + 1) .. "]"
	entryCostLabel.Text = cost .. " Gold"
end
updateEntryButton()
player:GetAttributeChangedSignal("EntryLevel"):Connect(updateEntryButton)

-- Gold Storage upgrade button
local storageBtn = Instance.new("TextButton")
storageBtn.Size = UDim2.new(0,120,0,60)
storageBtn.Position = UDim2.new(0,100,0,120)
storageBtn.BackgroundColor3 = goldColor
storageBtn.BorderSizePixel = 0
storageBtn.Parent = shopFrame

local storageTitle = Instance.new("TextLabel")
storageTitle.Name = "StorageUpgradeTitle"
storageTitle.Size = UDim2.new(1,0,0,20)
storageTitle.Position = UDim2.new(0,0,0,0)
storageTitle.BackgroundTransparency = 1
storageTitle.Text = "Max Storage"
storageTitle.Font = Enum.Font.SourceSansBold
storageTitle.TextColor3 = Color3.new(1,1,1)
storageTitle.TextStrokeColor3 = Color3.new(0,0,0)
storageTitle.TextStrokeTransparency = 0
storageTitle.TextScaled = true
storageTitle.Parent = storageBtn

local storageLevelLabel = Instance.new("TextLabel")
storageLevelLabel.Name = "StorageUpgradeLevel"
storageLevelLabel.Size = UDim2.new(1,0,0,20)
storageLevelLabel.Position = UDim2.new(0,0,0,20)
storageLevelLabel.BackgroundTransparency = 1
storageLevelLabel.Text = "[Lvl 1]"
storageLevelLabel.Font = Enum.Font.SourceSansBold
storageLevelLabel.TextColor3 = Color3.new(1,1,1)
storageLevelLabel.TextStrokeColor3 = Color3.new(0,0,0)
storageLevelLabel.TextStrokeTransparency = 0
storageLevelLabel.TextScaled = true
storageLevelLabel.Parent = storageBtn

local storageCostLabel = Instance.new("TextLabel")
storageCostLabel.Name = "StorageUpgradeCost"
storageCostLabel.Size = UDim2.new(1,0,0,20)
storageCostLabel.Position = UDim2.new(0,0,1,-20)
storageCostLabel.BackgroundTransparency = 1
storageCostLabel.Text = ""
storageCostLabel.Font = Enum.Font.SourceSansBold
storageCostLabel.TextColor3 = orangeColor
storageCostLabel.TextStrokeColor3 = Color3.new(0,0,0)
storageCostLabel.TextStrokeTransparency = 0
storageCostLabel.TextScaled = true
storageCostLabel.Parent = storageBtn

storageBtn.MouseButton1Click:Connect(function()
    setSelectedItem("Max Storage", descriptions.Storage, function()
        ChangeStorageSize:FireServer()
    end)
end)

local function updateStorageButton()
	local level = player:GetAttribute("StorageLevel") or 1
	local cost = storageLevels[level] or storageLevels[#storageLevels]
	storageLevelLabel.Text = "[Lvl " .. level .. "]"
	storageCostLabel.Text = cost .. " Gold"

	-- Update button color to reflect current storage level if a mapping exists
	storageBtn.BackgroundColor3 = goldColor  -- keep gold regardless of level
end
updateStorageButton()
player:GetAttributeChangedSignal("StorageLevel"):Connect(updateStorageButton)

-- Kill bounty upgrade button
local bountyBtn = Instance.new("TextButton")
bountyBtn.Size = UDim2.new(0,120,0,60)
bountyBtn.Position = UDim2.new(0,-20,0,50)
bountyBtn.BackgroundColor3 = redColor
bountyBtn.BorderSizePixel = 0
bountyBtn.Parent = shopFrame

local bountyTitle = Instance.new("TextLabel")
bountyTitle.Name = "BountyTitle"
bountyTitle.Size = UDim2.new(1,0,0,20)
bountyTitle.Position = UDim2.new(0,0,0,0)
bountyTitle.BackgroundTransparency = 1
bountyTitle.Text = "Kill Bounty"
bountyTitle.Font = Enum.Font.SourceSansBold
bountyTitle.TextColor3 = Color3.new(1,1,1)
bountyTitle.TextStrokeColor3 = Color3.new(0,0,0)
bountyTitle.TextStrokeTransparency = 0
bountyTitle.TextScaled = true
bountyTitle.Parent = bountyBtn

local bountyLevelLabel = Instance.new("TextLabel")
bountyLevelLabel.Name = "BountyLevel"
bountyLevelLabel.Size = UDim2.new(1,0,0,20)
bountyLevelLabel.Position = UDim2.new(0,0,0,20)
bountyLevelLabel.BackgroundTransparency = 1
bountyLevelLabel.Text = "[Lvl 1]"
bountyLevelLabel.Font = Enum.Font.SourceSansBold
bountyLevelLabel.TextColor3 = Color3.new(1,1,1)
bountyLevelLabel.TextStrokeColor3 = Color3.new(0,0,0)
bountyLevelLabel.TextStrokeTransparency = 0
bountyLevelLabel.TextScaled = true
bountyLevelLabel.Parent = bountyBtn

local bountyCostLabel = Instance.new("TextLabel")
bountyCostLabel.Name = "BountyCost"
bountyCostLabel.Size = UDim2.new(1,0,0,20)
bountyCostLabel.Position = UDim2.new(0,0,1,-20)
bountyCostLabel.BackgroundTransparency = 1
bountyCostLabel.Text = ""
bountyCostLabel.Font = Enum.Font.SourceSansBold
bountyCostLabel.TextColor3 = orangeColor
bountyCostLabel.TextStrokeColor3 = Color3.new(0,0,0)
bountyCostLabel.TextStrokeTransparency = 0
bountyCostLabel.TextScaled = true
bountyCostLabel.Parent = bountyBtn

bountyBtn.MouseButton1Click:Connect(function()
    setSelectedItem("Kill Bounty", descriptions.KillBounty, function()
        ChangeKillBounty:FireServer()
    end)
end)

local function updateBountyButton()
	local reward = player:GetAttribute("KillBountyReward") or 15
	local level = 0
	for idx, val in ipairs(killBountyRewards) do
		if val == reward then level = idx-1 break end
	end
	bountyLevelLabel.Text = "[Lvl "..(level+1).."]"
	bountyCostLabel.Text = (killBountyCosts[level+2] or "Max") .. " Gold"
end
updateBountyButton()
player:GetAttributeChangedSignal("KillBountyReward"):Connect(updateBountyButton)

-- =========================================================================--
-- 4) HELPER FUNCTIONS
-- =========================================================================--

-- update the on-screen entry timer each frame
local function updateClientTimer()
	if not entryTimerLabel.Visible then
		if entryTimerConnection then
			entryTimerConnection:Disconnect()
			entryTimerConnection = nil
		end
		return
	end

	local elapsed = tick() - serverEntryStartTime
	local left    = math.max(0, entryDuration - elapsed)
	entryTimerLabel.Text = string.format("Entering Base: %.1fs", left)

	if left <= 0 and entryTimerConnection then
		entryTimerConnection:Disconnect()
		entryTimerConnection = nil
	end
end

local function stopClientTimer()
	if entryTimerConnection then
		entryTimerConnection:Disconnect()
		entryTimerConnection = nil
	end
	entryTimerLabel.Visible = false
end

-- show/hide the base-creation prompt
local function showPrompt()
	if promptGui and promptGui.Parent then return end

	promptGui = Instance.new("ScreenGui")
	promptGui.Name         = "BaseCreationPromptGui"
	promptGui.ResetOnSpawn = false
	promptGui.DisplayOrder = 5
	promptGui.Parent       = playerGui

	local promptLabel = Instance.new("TextLabel")
	promptLabel.Size              = UDim2.new(0.4,0,0.1,0)
	promptLabel.Position          = UDim2.new(0.5,0,0.7,0)
	promptLabel.AnchorPoint       = Vector2.new(0.5,0.5)
	promptLabel.BackgroundColor3  = Color3.fromRGB(50,50,50)
	promptLabel.BackgroundTransparency = 0.3
	promptLabel.TextColor3        = Color3.fromRGB(255,255,255)
	promptLabel.TextScaled        = true
	promptLabel.Text              = "Press F to make your base"
	promptLabel.Font              = Enum.Font.SourceSansBold
	promptLabel.Parent            = promptGui
end

local function hidePrompt()
	if promptGui then
		promptGui:Destroy()
		promptGui = nil
	end
end

-- Warning prompt when your base is stolen
local function showStolenWarning()
	local warnGui = Instance.new("ScreenGui")
	warnGui.Name = "StolenWarnGui"
	warnGui.ResetOnSpawn = false
	warnGui.DisplayOrder = 7
	warnGui.Parent = playerGui

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(0.8,0,0.08,0)
	lbl.Position = UDim2.new(0.5,0,0.1,0)
	lbl.AnchorPoint = Vector2.new(0.5,0.5)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = Color3.fromRGB(255,0,0)
	lbl.TextStrokeColor3 = Color3.new(0,0,0)
	lbl.TextStrokeTransparency = 0
	lbl.TextScaled = true
	lbl.Font = Enum.Font.SourceSansBold
	lbl.Text = "A player has stolen from your base!"
	lbl.Parent = warnGui

	task.delay(3, function()
		if warnGui then warnGui:Destroy() end
	end)
end

BaseStolenWarning.OnClientEvent:Connect(function(reason)
	showStolenWarning()
end)

-- =========================================================================--
-- 5) REMOTE EVENT CONNECTIONS
-- =========================================================================--

-- Error prompt for invalid placement
local function showError(msg)
	local errGui = Instance.new("ScreenGui")
	errGui.Name = "BaseErrorGui"
	errGui.ResetOnSpawn = false
	errGui.DisplayOrder = 6
	errGui.Parent = playerGui

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(0.7,0,0.12,0) -- slightly wider and taller
	lbl.Position = UDim2.new(0.5,0,0.6,0) -- move a bit higher on screen
	lbl.AnchorPoint = Vector2.new(0.5,0.5)
	lbl.TextColor3 = Color3.fromRGB(255,0,0)
	lbl.BackgroundTransparency = 1
	lbl.TextScaled = true
	lbl.Font = Enum.Font.SourceSansBold
	lbl.Text = msg or "Error"
	lbl.Parent = errGui

	-- auto-destroy after 2 seconds
	task.delay(2, function()
		if errGui then errGui:Destroy() end
	end)

	-- re-show placement prompt and allow retry
	showPrompt()
	baseCreationAttempted = false
end

BasePlacementError.OnClientEvent:Connect(function(reason)
	if reason == "TooClose" then
		showError("This Spot is Too Close to an Enemy Base")
	elseif reason == "NoGold" then
		showError("Base has no gold")
	end
end)

-- A) Open shop UI when server tells us
OpenBaseShop.OnClientEvent:Connect(function()
	updateStealUpgradeButton()
	updateAutoMineButton()
	updateEntryButton()
	updateStorageButton()
	shopGui.Enabled = true
end)

-- B) Update entry GUI & toggle shop prompt
UpdateBaseEntryGUI.OnClientEvent:Connect(function(status, p1, p2)
	if status == "StartTimer" then
		entryDuration        = p1
		serverEntryStartTime = tick() -- use local clock to avoid offset issues
		stopClientTimer()
		entryTimerLabel.Text = string.format("Entering Base: %.1fs", entryDuration)
		entryTimerLabel.Visible = true
		baseStatusLabel.Visible = false
		entryTimerConnection = RunService.RenderStepped:Connect(updateClientTimer)

	elseif status == "EnteredBase" then
		stopClientTimer()
		entryTimerLabel.Visible  = false
		baseStatusLabel.Text     = "You have entered your base"
		baseStatusLabel.Visible  = true

		if not _G._baseToolDisable then _G._baseToolDisable = {} end
		-- capture currently equipped tool (if any) BEFORE unequipping
		local equippedBefore, equippedName = nil, nil
		local char = player.Character
		if char then
			for _, child in ipairs(char:GetChildren()) do
				if child:IsA("Tool") then
					equippedBefore = child
					equippedName   = child.Name
					break
				end
			end
		end

		-- Disable the ability to fire weapons while inside base without destroying them
		local humanoid = char and char:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:UnequipTools()
		end

		local state = { tools = {}, conns = {}, class = player:GetAttribute("ClassName"), equipped = equippedBefore, equippedName = equippedName }
		_G._baseToolDisable[player.UserId] = state

		local function disableTool(tool)
			if tool:IsA("Tool") then
				if tool.Enabled then
					table.insert(state.tools, tool)
				end
				tool.Enabled = false
			end
		end

		-- Disable existing tools
		for _, t in ipairs(player.Backpack:GetChildren()) do disableTool(t) end
		if player.Character then
			for _, t in ipairs(player.Character:GetChildren()) do disableTool(t) end
		end

		-- Listen for new tools granted while inside base (e.g., class switch)
		state.conns.backpack = player.Backpack.ChildAdded:Connect(disableTool)
		if player.Character then
			state.conns.char = player.Character.ChildAdded:Connect(disableTool)
		end

		-- enable owner-only shop prompt
		for _, desc in ipairs(workspace:GetDescendants()) do
			if desc:IsA("ProximityPrompt")
				and desc.Name == "ShopPrompt"
				and desc:GetAttribute("OwnerUserId") == player.UserId then
				desc.Enabled = true
			end
		end

	elseif status == "LeftBase" then
		stopClientTimer()
		entryTimerLabel.Visible = false
		baseStatusLabel.Visible = false

		-- Re-enable tools and clean up
		local char = player.Character
		local humanoid = char and char:FindFirstChildOfClass("Humanoid")

		-- Capture what the player is currently holding (may be nil)
		local currentlyEquipped, currentName = nil, nil
		if char then
			for _, child in ipairs(char:GetChildren()) do
				if child:IsA("Tool") then
					currentlyEquipped = child
					currentName = child.Name
					break
				end
			end
		end

		local restore = _G._baseToolDisable and _G._baseToolDisable[player.UserId]
		if restore then
			-- Prefer the tool the player is actually holding when exiting
			if currentlyEquipped then
				restore.equipped = currentlyEquipped
				restore.equippedName = currentName
			end
			-- Disconnect listeners
			for _, c in pairs(restore.conns) do if c.Connected then c:Disconnect() end end

			-- Re-enable any stored tools that still exist
			for _, tool in ipairs(restore.tools) do
				if tool and tool.Parent then
					tool.Enabled = true
				end
			end
			-- Re-equip a tool so player can fire immediately
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				local toEquip = nil
				if restore.equipped and restore.equipped.Parent and restore.equipped.Enabled then
					toEquip = restore.equipped
				elseif restore.equippedName then
					-- try to find tool with same name
					for _, container in ipairs({player.Backpack, player.Character}) do
						for _, t in ipairs(container:GetChildren()) do
							if t:IsA("Tool") and t.Enabled and t.Name == restore.equippedName then
								toEquip = t
								break
							end
						end
						if toEquip then break end
					end
				end

				-- fallback: first enabled tool if still nil
				if not toEquip then
					for _, t in ipairs(player.Backpack:GetChildren()) do
						if t:IsA("Tool") and t.Enabled then
							toEquip = t
							break
						end
					end
				end
				if toEquip then
					humanoid:EquipTool(toEquip)
				end
			end
			_G._baseToolDisable[player.UserId] = nil
		end

		-- Close shop GUI when leaving
		shopGui.Enabled = false

		-- disable it again when leaving
		for _, desc in ipairs(workspace:GetDescendants()) do
			if desc:IsA("ProximityPrompt")
				and desc.Name == "ShopPrompt"
				and desc:GetAttribute("OwnerUserId") == player.UserId then
				desc.Enabled = false
			end
		end

	elseif status == "CancelTimer" then
		stopClientTimer()
		entryTimerLabel.Visible = false
		baseStatusLabel.Visible = false
	end
end)

-- C) Show base-creation prompt
DisplayBasePrompt.OnClientEvent:Connect(showPrompt)

-- =========================================================================--
-- 6) INPUT HANDLERS & CLEANUP
-- =========================================================================--

-- Press F to request base creation
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.F then
		if not baseCreationAttempted then
			baseCreationAttempted = true
			hidePrompt()
			RequestBaseCreation:FireServer()
		end
	end
end)

-- Hide GUIs on character reset
player.CharacterRemoving:Connect(function()
	stopClientTimer()
	entryTimerLabel.Visible = false
	baseStatusLabel.Visible = false
	shopGui.Enabled = false
end)

-- =========================================================================--
-- 7) SHOP BUTTON CALLBACKS
-- =========================================================================--
-- Double-jump passive for Ninja (max 2 air jumps, with cooldown)
do
    local maxJumps = 2
    local jumpCooldown = 0.1
    local jumpCount = 0
    local canJump = false

    local function onStateChanged(_, newState)
        local cls = player:GetAttribute("ClassName")
        if cls ~= "Ninja" and cls ~= "Shinobi" and cls ~= "Samurai" then return end
        if newState == Enum.HumanoidStateType.Landed then
            jumpCount = 0
            canJump = false
        elseif newState == Enum.HumanoidStateType.Freefall then
            wait(jumpCooldown)
            canJump = true
        elseif newState == Enum.HumanoidStateType.Jumping then
            canJump = false
            jumpCount = jumpCount + 1
        end
    end

    local function onJumpRequest()
        local cls = player:GetAttribute("ClassName")
        if cls ~= "Ninja" and cls ~= "Shinobi" and cls ~= "Samurai" then return end
        if canJump and jumpCount < maxJumps then
            local char = player.Character
            local humanoid = char and char:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
    end

    player.CharacterAdded:Connect(function(char)
        jumpCount = 0
        canJump = false
        local humanoid = char:WaitForChild("Humanoid")
        humanoid.StateChanged:Connect(onStateChanged)
    end)

    UserInputService.JumpRequest:Connect(onJumpRequest)
end

-- Forward declarations for linter
local clearSelection, updateBuyButton

-- =============================================================
-- Descriptions placeholder (replace later)
-- =============================================================

descriptions = {
    Archer       = "A skilled ranged attacker.",
    Ninja        = "Fast and agile melee fighter.",
    Pirate       = "Balanced fighter with firearms.",
    Farmer       = "Utility class with farming tricks.",
    Musketeer    = "Long-range firearm specialist.",
    Ranger       = "Rapid-fire crossbow expert.",
    Samurai      = "Armoured melee warrior.",
    Shinobi      = "Stealth assassin.",
    Outlaw       = "Quick-draw gunslinger.",
    Buccaneer    = "Close-range demolisher.",
    NiceFarmer   = "Supportive subclass that boosts allies.",
    ToxicFarmer  = "Spreads poisonous clouds.",
    StealUpgrade = "Increase how much gold you steal from enemy bases per hit.",
    AutoMine     = "Boost the passive gold generated by your miner each second.",
    EntryTime    = "Shorten the countdown to safely enter your base.",
    Storage      = "Raise the maximum gold your base can store.",
    KillBounty   = "Earn more gold for defeating opponents.",
}

-- =============================================================
-- Info panel + Buy button UI
-- =============================================================

local infoPanel = Instance.new("Frame")
infoPanel.Name = "InfoPanel"
infoPanel.Size = UDim2.new(0, 260, 1, -40)
infoPanel.Position = UDim2.new(0, 480, 0, 30) -- shifted right again
infoPanel.BackgroundColor3 = Color3.fromRGB(40,40,40)
infoPanel.BackgroundTransparency = 0.1
infoPanel.Parent = shopFrame

local infoTitle = Instance.new("TextLabel")
infoTitle.Size = UDim2.new(1,0,0,28)
infoTitle.BackgroundTransparency = 1
infoTitle.TextColor3 = Color3.new(1,1,1)
infoTitle.Font = Enum.Font.SourceSansBold
infoTitle.TextScaled = true
infoTitle.Text = "Select an item"
infoTitle.Parent = infoPanel

local infoText = Instance.new("TextLabel")
infoText.Size = UDim2.new(1,-10,1,-90)
infoText.Position = UDim2.new(0,5,0,32)
infoText.BackgroundTransparency = 1
infoText.TextWrapped = true
infoText.TextYAlignment = Enum.TextYAlignment.Top
infoText.Font = Enum.Font.SourceSans
infoText.TextColor3 = Color3.new(0.9,0.9,0.9)
infoText.TextSize = 16
infoText.Text = "Click an item on the left to see details."
infoText.Parent = infoPanel

local buyBtn = Instance.new("TextButton")
buyBtn.Size = UDim2.new(1,-20,0,40)
buyBtn.Position = UDim2.new(0,10,1,-48)
buyBtn.BackgroundColor3 = Color3.fromRGB(80,80,80)
buyBtn.BorderSizePixel = 0
buyBtn.TextColor3 = Color3.new(0.7,0.7,0.7)
buyBtn.Text = "BUY"
buyBtn.Font = Enum.Font.SourceSansBold
buyBtn.TextScaled = true
buyBtn.AutoButtonColor = false
buyBtn.Parent = infoPanel

-- Helpers
local selectedPurchaseFunc = nil

-- Warning label (defined early so referenced later)
local warningLabel = Instance.new("TextLabel")
warningLabel.Size = UDim2.new(1,-10,0,20)
warningLabel.Position = UDim2.new(0,5,1,-60)
warningLabel.BackgroundTransparency = 1
warningLabel.TextColor3 = Color3.fromRGB(255,0,0)
warningLabel.TextScaled = true
warningLabel.Font = Enum.Font.SourceSansBold
warningLabel.Text = ""
warningLabel.Parent = infoPanel

function setSelectedItem(titleStr, descStr, purchaseFunc)
    selectedPurchaseFunc = purchaseFunc
    infoTitle.Text = titleStr
    infoText.Text  = descStr or "(No description)"
    -- show warning if not enough tokens and title indicates subclass
    local tokens = player:GetAttribute("ClassTokens") or 0
    if string.find((descStr or ""):lower(), "subclass", 1, true) and tokens == 0 then
        warningLabel.Text = "Class Tokens are earned from base storage upgrades past level 3"
    else
        warningLabel.Text = ""
    end
    updateBuyButton()
end

function clearSelection()
    selectedPurchaseFunc = nil
    infoTitle.Text = "Select an item"
    infoText.Text  = "Click an item on the left to see details."
    updateBuyButton()
end

buyBtn.MouseButton1Click:Connect(function()
    if selectedPurchaseFunc then
        selectedPurchaseFunc()
        clearSelection()
    end
end)

updateBuyButton()

--- END selection system implementation




