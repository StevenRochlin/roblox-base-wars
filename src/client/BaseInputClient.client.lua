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
local stealUpgradeCosts = {30, 50, 80}
local purpleColor = Color3.fromRGB(128, 0, 128)
local orangeColor = Color3.fromRGB(255, 165, 0)
local mineBaseIncrement = 1
local mineUpgradeCosts = {40, 60, 90}
local skyBlueColor = Color3.fromRGB(135, 206, 235)
local entryTimeDecrement  = 0.5
local entryUpgradeCosts   = {80, 160, 320}
local turquoiseColor      = Color3.fromRGB(64, 224, 208)
local storageLevels       = {100, 150, 230, 350}
local storageColors       = {
	[1] = Color3.new(1,1,1),
	[2] = Color3.fromRGB(0,255,0),
	[3] = Color3.fromRGB(0,0,255),
	[4] = Color3.fromRGB(128,0,128),
}
local goldColor           = Color3.fromRGB(255, 215, 0)
local redColor            = Color3.fromRGB(255,0,0)
local killBountyRewards   = {15,30,60,90,120,150,180}
local killBountyCosts     = {0,60,120,240,480,960,1920} -- index matches level

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
baseStatusLabel.Position         = UDim2.new(0.5,0,0.78,0)
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
shopFrame.Size               = UDim2.new(0,420,0,360) -- increased height for subclass buttons
shopFrame.Position           = UDim2.new(0.5,-150,0.5,-130)
shopFrame.BackgroundColor3   = Color3.fromRGB(30,30,30)
shopFrame.BackgroundTransparency = 0.3
shopFrame.Parent             = shopGui

-- Close button (top‐right corner)
local closeBtn = Instance.new("TextButton")
closeBtn.Name               = "CloseButton"
closeBtn.Size               = UDim2.new(0, 24, 0, 24)
closeBtn.Position           = UDim2.new(1, -30, 0, 6)
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

-- Class selection buttons (insert above upgrades)
local archerBtn = Instance.new("TextButton")
archerBtn.Name = "ArcherButton"
archerBtn.Size = UDim2.new(0, 120, 0, 60)
archerBtn.Position = UDim2.new(0, 10, 0, 190)
archerBtn.Text = "Archer"
archerBtn.TextScaled = true
archerBtn.Parent = shopFrame
archerBtn.MouseButton1Click:Connect(function()
    RequestClassEquip:FireServer("Archer", 0)
end)

local ninjaBtn = Instance.new("TextButton")
ninjaBtn.Name = "NinjaButton"
ninjaBtn.Size = UDim2.new(0, 120, 0, 60)
ninjaBtn.Position = UDim2.new(0, 140, 0, 190)
ninjaBtn.Text = "Ninja"
ninjaBtn.TextScaled = true
ninjaBtn.Parent = shopFrame
ninjaBtn.MouseButton1Click:Connect(function()
    RequestClassEquip:FireServer("Ninja", 0)
end)

-- Pirate class button
local pirateBtn = Instance.new("TextButton")
pirateBtn.Name = "PirateButton"
pirateBtn.Size = UDim2.new(0, 120, 0, 60)
pirateBtn.Position = UDim2.new(0, 270, 0, 190)
pirateBtn.Text = "Pirate"
pirateBtn.TextScaled = true
pirateBtn.Parent = shopFrame
pirateBtn.MouseButton1Click:Connect(function()
    RequestClassEquip:FireServer("Pirate", 0)
end)

-- Farmer class button
local farmerBtn = Instance.new("TextButton")
farmerBtn.Name = "FarmerButton"
farmerBtn.Size = UDim2.new(0, 120, 0, 60)
farmerBtn.Position = UDim2.new(0, 400, 0, 190)
farmerBtn.Text = "Farmer"
farmerBtn.TextScaled = true
farmerBtn.Parent = shopFrame
farmerBtn.MouseButton1Click:Connect(function()
    RequestClassEquip:FireServer("Farmer", 0)
end)

-- /////////////////////////////////////////////////////////////////
-- Subclass purchase buttons (cost 500 Gold each)
-- Coordinates: align under each class column (x=10,140,270,400) 
-- First subclass row y=260, second y=330
-- Helper to create button
local function createSubclassButton(displayName, className, posX, posY)
    local btn = Instance.new("TextButton")
    btn.Name = className .. "Button"
    btn.Size = UDim2.new(0, 120, 0, 60)
    btn.Position = UDim2.new(0, posX, 0, posY)
    btn.Text = displayName .. "\n(500G)"
    btn.TextWrapped = true
    btn.TextScaled = true
    btn.Parent = shopFrame
    btn.MouseButton1Click:Connect(function()
        RequestClassEquip:FireServer(className, 0)
    end)
end

-- Archer subclasses
createSubclassButton("Musketeer", "Musketeer", 10, 260)
createSubclassButton("Ranger", "Ranger", 10, 330)

-- Ninja subclasses
createSubclassButton("Samurai", "Samurai", 140, 260)
createSubclassButton("Shinobi", "Shinobi", 140, 330)

-- Pirate subclasses
createSubclassButton("Outlaw", "Outlaw", 270, 260)
createSubclassButton("Buccaneer", "Buccaneer", 270, 330)

-- Farmer subclasses
createSubclassButton("Harvester", "FriendlyHarvester", 400, 260)
createSubclassButton("Toxic Grower", "ToxicGrower", 400, 330)

local fastStealBtn = Instance.new("TextButton")
fastStealBtn.Size = UDim2.new(0,120,0,60)
fastStealBtn.Position = UDim2.new(0,140,0,50)
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
stealLabel.TextColor3 = purpleColor
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
	ChangeStealSpeed:FireServer(stealBaseIncrement)
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
autoMineBtn.Position = UDim2.new(0,280,0,50)
autoMineBtn.BackgroundColor3 = skyBlueColor
autoMineBtn.BorderSizePixel = 0
autoMineBtn.Parent = shopFrame

local autoMineTitle = Instance.new("TextLabel")
autoMineTitle.Name = "AutoMineTitle"
autoMineTitle.Size = UDim2.new(1,0,0,20)
autoMineTitle.Position = UDim2.new(0,0,0,0)
autoMineTitle.BackgroundTransparency = 1
autoMineTitle.Text = "Auto Gold Miner"
autoMineTitle.Font = Enum.Font.SourceSansBold
autoMineTitle.TextColor3 = skyBlueColor
autoMineTitle.TextStrokeColor3 = Color3.new(0,0,0)
autoMineTitle.TextStrokeTransparency = 0
autoMineTitle.TextScaled = true
autoMineTitle.Parent = autoMineBtn

local autoMineLevelLabel = Instance.new("TextLabel")
autoMineLevelLabel.Name = "AutoMineLevel"
autoMineLevelLabel.Size = UDim2.new(1,0,0,20)
autoMineLevelLabel.Position = UDim2.new(0,0,0,20)
autoMineLevelLabel.BackgroundTransparency = 1
autoMineLevelLabel.Text = "[Lvl 0]"
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
	ChangeMineSpeed:FireServer(mineBaseIncrement)
end)

local function updateAutoMineButton()
	local rate = player:GetAttribute("MineSpeed") or 0
	local level = rate
	local costIndex = level + 1
	local cost = mineUpgradeCosts[costIndex] or mineUpgradeCosts[#mineUpgradeCosts]
	autoMineLevelLabel.Text = "[Lvl " .. level .. "]"
	autoMineCostLabel.Text = cost .. " Gold"
end
updateAutoMineButton()
player:GetAttributeChangedSignal("MineSpeed"):Connect(updateAutoMineButton)

-- Entry Time upgrade button
local entryBtn = Instance.new("TextButton")
entryBtn.Size = UDim2.new(0,120,0,60)
entryBtn.Position = UDim2.new(0,0,0,120)
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
entryTitle.TextColor3 = turquoiseColor
entryTitle.TextStrokeColor3 = Color3.new(0,0,0)
entryTitle.TextStrokeTransparency = 0
entryTitle.TextScaled = true
entryTitle.Parent = entryBtn

local entryLevelLabel = Instance.new("TextLabel")
entryLevelLabel.Name = "EntryUpgradeLevel"
entryLevelLabel.Size = UDim2.new(1,0,0,20)
entryLevelLabel.Position = UDim2.new(0,0,0,20)
entryLevelLabel.BackgroundTransparency = 1
entryLevelLabel.Text = "[Lvl 0]"
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
	ChangeEntryTime:FireServer(entryTimeDecrement)
end)

local function updateEntryButton()
	local level = player:GetAttribute("EntryLevel") or 0
	local cost = entryUpgradeCosts[level + 1] or entryUpgradeCosts[#entryUpgradeCosts]
	entryLevelLabel.Text = "[Lvl " .. level .. "]"
	entryCostLabel.Text = cost .. " Gold"
end
updateEntryButton()
player:GetAttributeChangedSignal("EntryLevel"):Connect(updateEntryButton)

-- Gold Storage upgrade button
local storageBtn = Instance.new("TextButton")
storageBtn.Size = UDim2.new(0,120,0,60)
storageBtn.Position = UDim2.new(0,140,0,120)
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
	ChangeStorageSize:FireServer()
end)

local function updateStorageButton()
	local level = player:GetAttribute("StorageLevel") or 1
	local cost = storageLevels[level] or storageLevels[#storageLevels]
	storageLevelLabel.Text = "[Lvl " .. level .. "]"
	storageCostLabel.Text = cost .. " Gold"
	storageBtn.BackgroundColor3 = goldColor
end
updateStorageButton()
player:GetAttributeChangedSignal("StorageLevel"):Connect(updateStorageButton)

-- Kill bounty upgrade button
local bountyBtn = Instance.new("TextButton")
bountyBtn.Size = UDim2.new(0,120,0,60)
bountyBtn.Position = UDim2.new(0,0,0,50)
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
bountyTitle.TextColor3 = redColor
bountyTitle.TextStrokeColor3 = Color3.new(0,0,0)
bountyTitle.TextStrokeTransparency = 0
bountyTitle.TextScaled = true
bountyTitle.Parent = bountyBtn

local bountyLevelLabel = Instance.new("TextLabel")
bountyLevelLabel.Name = "BountyLevel"
bountyLevelLabel.Size = UDim2.new(1,0,0,20)
bountyLevelLabel.Position = UDim2.new(0,0,0,20)
bountyLevelLabel.BackgroundTransparency = 1
bountyLevelLabel.Text = "[Lvl 0]"
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
	ChangeKillBounty:FireServer()
end)

local function updateBountyButton()
	local reward = player:GetAttribute("KillBountyReward") or 15
	local level = 0
	for idx, val in ipairs(killBountyRewards) do
		if val == reward then level = idx-1 break end
	end
	bountyLevelLabel.Text = "[Lvl "..level.."]"
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
        if player:GetAttribute("ClassName") ~= "Ninja" then return end
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
        if player:GetAttribute("ClassName") ~= "Ninja" then return end
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




