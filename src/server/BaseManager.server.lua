-- BaseManager (ServerScriptService)
print("BaseManager loaded")
print("BaseManager.luau loaded")
local Players                   = game:GetService("Players")
local ReplicatedStorage         = game:GetService("ReplicatedStorage")
local Workspace                 = game:GetService("Workspace")
local RunService                = game:GetService("RunService")

-- Remote events
local RequestBaseCreation       = ReplicatedStorage:WaitForChild("RequestBaseCreation")
local BasePlacementError        = ReplicatedStorage:FindFirstChild("BasePlacementError") or Instance.new("RemoteEvent")
BasePlacementError.Name = "BasePlacementError"
BasePlacementError.Parent = ReplicatedStorage

local BaseStolenWarning         = ReplicatedStorage:FindFirstChild("BaseStolenWarning") or Instance.new("RemoteEvent")
BaseStolenWarning.Name = "BaseStolenWarning"
BaseStolenWarning.Parent = ReplicatedStorage
local UpdateBaseEntryGUI        = ReplicatedStorage:WaitForChild("UpdateBaseEntryGUI")
local OpenBaseShop              = ReplicatedStorage:WaitForChild("OpenBaseShop")
local ChangeStealAmount         = ReplicatedStorage:WaitForChild("ChangeStealSpeed")  -- uses ChangeStealSpeed remote event
local ChangeMineSpeed           = ReplicatedStorage:WaitForChild("ChangeMineSpeed")   -- uses ChangeMineSpeed remote event
local ChangeEntryTime           = ReplicatedStorage:WaitForChild("ChangeEntryTime")   -- uses ChangeEntryTime remote event
local ChangeStorageSize         = ReplicatedStorage:WaitForChild("ChangeStorageSize") -- uses ChangeStorageSize remote event
local ChangeKillBounty          = ReplicatedStorage:FindFirstChild("ChangeKillBounty") or Instance.new("RemoteEvent")
ChangeKillBounty.Name = "ChangeKillBounty"
ChangeKillBounty.Parent = ReplicatedStorage

-- Constants and state
local BASE_FOLDER_NAME          = "PlayerBases"
local BASE_ENTRY_SECONDS        = 3
local UPGRADE_COST              = 50
local stealBaseIncrement        = 10
local stealUpgradeCosts         = {30, 50, 80}
local mineBaseIncrement         = 1
local mineUpgradeCosts          = {40, 60, 90}
local storageLevels             = {100, 150, 230, 350}
local entryTimeDecrement       = 0.5
local entryUpgradeCosts        = {80, 160, 320}
local playerBasesFolder         = Workspace:FindFirstChild(BASE_FOLDER_NAME)
if not playerBasesFolder then
	playerBasesFolder = Instance.new("Folder")
	playerBasesFolder.Name = BASE_FOLDER_NAME
	playerBasesFolder.Parent = Workspace
end

-- Data tables
-- [ userId ] = { basePart, billboardGui, storedCash, ownerName, stealPrompt }
local playerBasesData  = {}
-- [ userId ] = { isTouchingBase, touchStartTime, isInDefinitiveBaseState, character, originalTransparency }
local playerBaseStates = {}

-- [ userId ] = current steal‐amount for that player (what they steal per hit)
local playerStealAmounts = {}
-- [ userId ] = current auto-mine rate (gold per second)
local playerMineSpeeds   = {}
-- [ userId ] = current storage level
local playerStorageLevels = {}
-- [ userId ] = current entry time upgrade level
local playerEntryLevels = {}

-- [ userId ] = current kill bounty level (0 default)
local playerKillBountyLevels = {}

local killBountyRewards = {30, 60, 90, 120, 150, 180}
local killBountyCosts   = {60, 120, 240, 480, 960, 1920}

-- Update the on-base billboard
local function updateBillboard(userId)
	local data = playerBasesData[userId]
	if data and data.billboardGui then
		local lbl = data.billboardGui:FindFirstChild("InfoLabel")
		if lbl then
			lbl.Text = string.format("%s - Base Gold: %d", data.ownerName, data.storedGold)
			-- color text gold, turn red when full
			local maxStorage = data.maxStorage or storageLevels[1]
			if data.storedGold >= maxStorage then
				lbl.TextColor3 = Color3.fromRGB(255,0,0)
			else
				lbl.TextColor3 = Color3.fromRGB(255,215,0)
			end
			-- black stroke
			lbl.TextStrokeColor3 = Color3.new(0,0,0)
			lbl.TextStrokeTransparency = 0
		end
	end
end

-- Helper: save and restore transparency
local function setCharacterTransparency(character, transparency, userId)
	local state = playerBaseStates[userId]
	if not state or not character then return end
	if transparency < 1 then
		state.originalTransparency = {}
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") or part:IsA("Decal") then
				state.originalTransparency[part] = part.Transparency
				part.Transparency = transparency
			end
		end
	else
		for part, orig in pairs(state.originalTransparency) do
			if part and part.Parent then
				part.Transparency = orig
			end
		end
		state.originalTransparency = {}
	end
end

-- Enter base workflow
local function enterBase(player, character)
	local userId = player.UserId
	local state  = playerBaseStates[userId]
	local data   = playerBasesData[userId]
	if not state or state.isInDefinitiveBaseState or not data then return end

	state.isInDefinitiveBaseState = true
	setCharacterTransparency(character, 0.7, userId)
	player:SetAttribute("CanDealDamage", false)

	-- deposit carried gold
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		local goldStat = stats:FindFirstChild("Gold")
		local baseGoldStat = stats:FindFirstChild("BaseGold")
		if goldStat and baseGoldStat then
			local carried = goldStat.Value
			if carried > 0 then
				local maxStorage = data.maxStorage or storageLevels[1]
				local spaceLeft = maxStorage - data.storedGold
				if spaceLeft > 0 then
					local deposit = math.min(carried, spaceLeft)
					data.storedGold = data.storedGold + deposit
					goldStat.Value = carried - deposit
					baseGoldStat.Value = data.storedGold
					updateBillboard(userId)
				end
			end
		end
	end

	UpdateBaseEntryGUI:FireClient(player, "EnteredBase")
end

-- Leave base workflow
local function leaveBase(player)
	local userId = player.UserId
	local state  = playerBaseStates[userId]
	if not state or not state.isInDefinitiveBaseState then return end

	state.isInDefinitiveBaseState = false
	setCharacterTransparency(state.character or player.Character, 1, userId)
	player:SetAttribute("CanDealDamage", true)
	state.character = nil

	UpdateBaseEntryGUI:FireClient(player, "LeftBase")
end

-- Update base color by storage level
local function updateBaseColor(userId)
	local level = playerStorageLevels[userId] or 1
	local colorMap = {
		[1] = Color3.new(1,1,1),
		[2] = Color3.fromRGB(0,255,0),
		[3] = Color3.fromRGB(0,0,255),
		[4] = Color3.fromRGB(128,0,128),
	}
	local data = playerBasesData[userId]
	if data and data.basePart and data.baseCore then
		-- color the main base part according to storage level
		local color = colorMap[level] or colorMap[1]
		data.basePart.Color = color
		-- always keep the inner core gold
		data.baseCore.Color = Color3.fromRGB(255,215,0)
	end
end

-- Handle base creation request
RequestBaseCreation.OnServerEvent:Connect(function(player)
	print("BaseManager: RequestBaseCreation by", player.Name)
	local userId = player.UserId
	if playerBasesData[userId] then
		warn("[BaseManager] "..player.Name.." already has a base.")
		return
	end

	-- Check minimal distance to other bases BEFORE creating base
	local MIN_EXTRA_SEPARATION = 15
	local BASE_RADIUS = 9 -- diameter 18
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local desiredPos = hrp.Position

	for otherId, data in pairs(playerBasesData) do
		if data.basePart then
			local dist = (data.basePart.Position - desiredPos).Magnitude
			if dist < (BASE_RADIUS*2 + MIN_EXTRA_SEPARATION) then
				-- too close
				BasePlacementError:FireClient(player, "TooClose")
				return
			end
		end
	end

	-- Init data/state AFTER passing proximity check
	playerBasesData[userId]  = { storedGold = 0, ownerName = player.Name }
	playerBaseStates[userId] = { isTouchingBase = false, touchStartTime = 0,
		isInDefinitiveBaseState = false, character = nil, originalTransparency = {} }

	local char = player.Character
	local hrp  = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- Determine placement position: if player is in the air, drop base to ground below
	local BASE_DIAMETER = 18
	local BASE_RADIUS   = BASE_DIAMETER/2
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {char}
	local rayResult = Workspace:Raycast(hrp.Position, Vector3.new(0,-1000,0), rayParams)
	local basePosition = hrp.Position
	if rayResult then
		-- lower by roughly one character height plus an extra stud (~6)
		basePosition = rayResult.Position + Vector3.new(0, BASE_RADIUS - 6, 0)
	end

	-- Outer base
	local basePart = Instance.new("Part")
	basePart.Name         = player.Name .. "_Base"
	basePart.Shape        = Enum.PartType.Ball
	basePart.Size         = Vector3.new(BASE_DIAMETER, BASE_DIAMETER, BASE_DIAMETER)
	basePart.Color        = Color3.fromRGB(128,0,128)
	basePart.Transparency = 0.5
	basePart.Anchored     = true
	basePart.CanCollide   = false
	basePart.Position     = basePosition
	basePart.Parent       = playerBasesFolder
	playerBasesData[userId].basePart = basePart

	-- Billboard
	local billboard = Instance.new("BillboardGui")
	billboard.Name        = "BaseInfoGui"
	billboard.Adornee     = basePart
	billboard.Size        = UDim2.new(0,250,0,60)
	billboard.StudsOffset = Vector3.new(0,12,0)
	billboard.AlwaysOnTop = true
	billboard.Parent      = basePart
	playerBasesData[userId].billboardGui = billboard

	local label = Instance.new("TextLabel")
	label.Name                   = "InfoLabel"
	label.Size                   = UDim2.new(1,0,1,0)
	label.BackgroundTransparency = 1
	label.TextColor3             = Color3.new(1,1,1)
	label.TextScaled             = true
	label.Font                   = Enum.Font.SourceSansBold
	label.Parent                 = billboard

	updateBillboard(userId)

	-- Inner core
	local baseCore = Instance.new("Part")
	baseCore.Name         = player.Name .. "_BaseCore"
	baseCore.Shape        = Enum.PartType.Ball
	baseCore.Size         = Vector3.new(4,4,4)
	baseCore.Color        = Color3.fromRGB(51,61,128)
	baseCore.Transparency = 0.5
	baseCore.Anchored     = true
	baseCore.CanCollide   = false
	baseCore.Position     = basePosition + Vector3.new(0,-3,0)
	baseCore.Parent       = playerBasesFolder
	playerBasesData[userId].baseCore = baseCore

	-- Steal prompt for others
	local stealPrompt = Instance.new("ProximityPrompt")
	stealPrompt.Name                  = "StealPrompt"
	stealPrompt.ActionText            = "Steal Gold"
	stealPrompt.ObjectText            = player.Name .. "'s Base"
	stealPrompt.KeyboardKeyCode       = Enum.KeyCode.E
	stealPrompt.HoldDuration          = 2
	stealPrompt.MaxActivationDistance = 8
	stealPrompt.RequiresLineOfSight   = false
	stealPrompt:SetAttribute("OwnerUserId", userId)
	stealPrompt:SetAttribute("StealAmount",     10)
	stealPrompt.ActionText = "Steal Gold (10)"
	stealPrompt.Parent                = baseCore
	playerBasesData[userId].stealPrompt = stealPrompt

	stealPrompt.Triggered:Connect(function(stealer)
		local sid = stealer.UserId
		if sid == userId then return end
		local data = playerBasesData[userId]
		if not data then return end
		if data.storedGold <= 0 then
			BasePlacementError:FireClient(stealer, "NoGold")
			return
		end

		local sid     = stealer.UserId
		local stealV  = playerStealAmounts[sid] or 10

		-- Apply subclass-specific steal multiplier
		local stealMult = stealer:GetAttribute("StealGoldMultiplier") or 1
		stealV = math.floor(stealV * stealMult)

		local amount  = math.min(data.storedGold, stealV)
		data.storedGold = data.storedGold - amount

		-- 1) Update the floating label above the base
		updateBillboard(userId)
		-- 2) Sync the owner's leaderboard BaseGold stat
		local ownerPlayer = Players:GetPlayerByUserId(userId)
		if ownerPlayer then
			local ownerStats = ownerPlayer:FindFirstChild("leaderstats")
			local bsStat     = ownerStats and ownerStats:FindFirstChild("BaseGold")
			if bsStat then
				bsStat.Value = data.storedGold
			end
		end

		-- 3) Finally, give the gold to the stealer
		local goldStat = stealer:FindFirstChild("leaderstats")
			and stealer.leaderstats:FindFirstChild("Gold")
		if goldStat then
			goldStat.Value = goldStat.Value + amount
		end

		-- 4) Notify owner about the theft
		if ownerPlayer then
			BaseStolenWarning:FireClient(ownerPlayer, "Stolen")
		end
	end)
	-- after playerStealAmounts[userId] = 10
	playerStealAmounts[userId] = 10
	playerMineSpeeds[userId] = 0
	playerEntryLevels[userId] = 0
	playerStorageLevels[userId] = 1
	playerBasesData[userId].maxStorage = storageLevels[1]
	updateBaseColor(userId)

	-- Shop prompt for owner
	local shopPrompt = Instance.new("ProximityPrompt")
	shopPrompt.Name                  = "ShopPrompt"
	shopPrompt.ActionText            = "Open Shop"
	shopPrompt.ObjectText            = player.Name .. "'s Shop"
	shopPrompt.KeyboardKeyCode       = Enum.KeyCode.E
	shopPrompt.HoldDuration          = 0
	shopPrompt.MaxActivationDistance = 8
	shopPrompt.RequiresLineOfSight   = false
	shopPrompt:SetAttribute("OwnerUserId", userId)
	shopPrompt.Enabled               = false
	shopPrompt.Parent                = baseCore
	shopPrompt.Triggered:Connect(function(who)
		if who.UserId == userId then
			OpenBaseShop:FireClient(who)
		end
	end)

	-- Touch enter/exit logic
	basePart.Touched:Connect(function(hit)
		if hit.Name == "HumanoidRootPart" then
			local toucher = Players:GetPlayerFromCharacter(hit.Parent)
			if toucher and toucher.UserId == userId then
				local state = playerBaseStates[userId]
				if not state.isInDefinitiveBaseState and not state.isTouchingBase then
					state.isTouchingBase = true
					state.touchStartTime = tick()
					state.character      = toucher.Character
					local level = playerEntryLevels[userId] or 0
					local duration = BASE_ENTRY_SECONDS - level * entryTimeDecrement
					UpdateBaseEntryGUI:FireClient(toucher, "StartTimer", duration, state.touchStartTime)
				end
			end
		end
	end)
	basePart.TouchEnded:Connect(function(hit)
		if hit.Name == "HumanoidRootPart" then
			local toucher = Players:GetPlayerFromCharacter(hit.Parent)
			if toucher and toucher.UserId == userId then
				local state = playerBaseStates[userId]

				-- Only treat this as leaving the base if the player is actually outside the
				-- base radius. Touch events can briefly disconnect when equipping/unequipping
				-- tools, which used to reset the entry timer unnecessarily.
				local char = toucher.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				local stillInside = false
				if hrp then
					local dist = (hrp.Position - basePart.Position).Magnitude
					stillInside = dist <= (basePart.Size.X/2 + 1)
				end

				if not stillInside then
					if state.isTouchingBase and not state.isInDefinitiveBaseState then
						UpdateBaseEntryGUI:FireClient(toucher, "CancelTimer")
					end
					state.isTouchingBase = false
					if state.isInDefinitiveBaseState then
						leaveBase(toucher)
					end
				end
			end
		end
	end)

	print("[BaseManager] Base created for " .. player.Name)
	-- mark that player now has a base (successful)
	player:SetAttribute("HasBase", true)
	playerKillBountyLevels[userId] = 0
	player:SetAttribute("KillBountyReward", 15)
end)

-- RunService loop to complete base entry
RunService.Heartbeat:Connect(function()
	for userId, state in pairs(playerBaseStates) do
		-- Case 1: Player is in the process of entering (timer running)
		if state.isTouchingBase and not state.isInDefinitiveBaseState then
			local player   = Players:GetPlayerByUserId(userId)
			local character= state.character or (player and player.Character)
			if player and character and character:FindFirstChild("HumanoidRootPart") then
				local baseData = playerBasesData[userId]
				local basePart = baseData and baseData.basePart
				if basePart then
					local dist = (character.HumanoidRootPart.Position - basePart.Position).Magnitude
					if dist <= (basePart.Size.X/2 + 3) then
						local level = playerEntryLevels[userId] or 0
						local duration = BASE_ENTRY_SECONDS - level * entryTimeDecrement
						if tick() - state.touchStartTime >= duration then
							enterBase(player, character)
						end
					else
						state.isTouchingBase = false
						UpdateBaseEntryGUI:FireClient(player, "CancelTimer")
					end
				end
			else
				if player then UpdateBaseEntryGUI:FireClient(player, "CancelTimer") end
				state.isTouchingBase = false
			end
		end

		-- Heal player while inside the base
		if state.isInDefinitiveBaseState then
			local player = Players:GetPlayerByUserId(userId)
			local character = player and (state.character or player.Character)
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				local HEAL_PER_SEC = 25
				humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + HEAL_PER_SEC/60)
			end
		end

		-- Additional safeguard: if player has already entered the base but moves away and
		-- TouchEnded failed to fire, force a clean leave.
		if state.isInDefinitiveBaseState then
			local player = Players:GetPlayerByUserId(userId)
			local character = player and (state.character or player.Character)
			local baseData = playerBasesData[userId]
			local basePart = baseData and baseData.basePart
			if player and character and basePart and character:FindFirstChild("HumanoidRootPart") then
				local dist = (character.HumanoidRootPart.Position - basePart.Position).Magnitude
				local radiusOut = (basePart.Size.X/2 + 1)
				if dist > radiusOut then
					state.isTouchingBase = false -- ensure consistent state
					leaveBase(player)
				end
			end
		end
	end
end)

-- Handle steal amount upgrade with cost
ChangeStealAmount.OnServerEvent:Connect(function(player, amountToAdd)
	local userId = player.UserId
	local data   = playerBasesData[userId]
	local stats  = player:FindFirstChild("leaderstats")
	local baseGold = stats and stats:FindFirstChild("BaseGold")
	if not data or not baseGold then
		return  -- no base
	end

	local baseIncrement = amountToAdd
	local currentAmt = playerStealAmounts[userId] or baseIncrement
	local level = currentAmt / baseIncrement
	local cost = stealUpgradeCosts[level] or stealUpgradeCosts[#stealUpgradeCosts]
	if baseGold.Value < cost then
		return  -- insufficient funds
	end

	-- Deduct cost
	baseGold.Value = baseGold.Value - cost
	data.storedGold = data.storedGold - cost
	updateBillboard(userId)

	-- Auto-deposit extra carried gold up to base capacity
	local goldStat = stats:FindFirstChild("Gold")
	local spaceLeft = data.maxStorage - data.storedGold
	if goldStat and spaceLeft > 0 then
		local deposit = math.min(goldStat.Value, spaceLeft)
		data.storedGold = data.storedGold + deposit
		baseGold.Value = data.storedGold
		goldStat.Value = goldStat.Value - deposit
		updateBillboard(userId)
	end

	-- Increase steal amount
	local newAmt = currentAmt + baseIncrement
	playerStealAmounts[userId] = newAmt

	-- Sync to client
	player:SetAttribute("StealAmount", newAmt)
end)

-- Handle auto gold miner upgrade with cost
ChangeMineSpeed.OnServerEvent:Connect(function(player, amountToAdd)
	local userId = player.UserId
	local data   = playerBasesData[userId]
	local stats  = player:FindFirstChild("leaderstats")
	local baseGold = stats and stats:FindFirstChild("BaseGold")
	if not data or not baseGold then return end

	local current = playerMineSpeeds[userId] or 0
	local nextLevel = current + amountToAdd
	local cost = mineUpgradeCosts[nextLevel] or mineUpgradeCosts[#mineUpgradeCosts]
	if baseGold.Value < cost then return end

	-- Deduct cost
	baseGold.Value = baseGold.Value - cost
	data.storedGold = data.storedGold - cost
	updateBillboard(userId)

	-- Auto-deposit extra carried gold up to base capacity
	local goldStat = stats:FindFirstChild("Gold")
	local spaceLeft = data.maxStorage - data.storedGold
	if goldStat and spaceLeft > 0 then
		local deposit = math.min(goldStat.Value, spaceLeft)
		data.storedGold = data.storedGold + deposit
		baseGold.Value = data.storedGold
		goldStat.Value = goldStat.Value - deposit
		updateBillboard(userId)
	end

	-- Increase mine speed
	playerMineSpeeds[userId] = nextLevel

	-- Sync to client
	player:SetAttribute("MineSpeed", nextLevel)
end)

-- Handle entry time upgrade with cost
ChangeEntryTime.OnServerEvent:Connect(function(player)
	local userId = player.UserId
	local data   = playerBasesData[userId]
	local stats  = player:FindFirstChild("leaderstats")
	local baseGold = stats and stats:FindFirstChild("BaseGold")
	if not data or not baseGold then return end

	local currentLevel = playerEntryLevels[userId] or 0
	local nextLevel = currentLevel + 1
	local cost = entryUpgradeCosts[nextLevel] or entryUpgradeCosts[#entryUpgradeCosts]
	if baseGold.Value < cost then return end

	-- Deduct cost
	baseGold.Value = baseGold.Value - cost
	data.storedGold = data.storedGold - cost
	updateBillboard(userId)

	-- Auto-deposit extra carried gold up to base capacity
	local goldStat = stats:FindFirstChild("Gold")
	local spaceLeft = data.maxStorage - data.storedGold
	if goldStat and spaceLeft > 0 then
		local deposit = math.min(goldStat.Value, spaceLeft)
		data.storedGold = data.storedGold + deposit
		baseGold.Value = data.storedGold
		goldStat.Value = goldStat.Value - deposit
		updateBillboard(userId)
	end

	-- Upgrade entry level
	playerEntryLevels[userId] = nextLevel

	-- Sync to client
	player:SetAttribute("EntryLevel", nextLevel)
end)

-- Handle gold storage upgrade with cost
ChangeStorageSize.OnServerEvent:Connect(function(player)
	local userId = player.UserId
	local data   = playerBasesData[userId]
	local stats  = player:FindFirstChild("leaderstats")
	local baseGold = stats and stats:FindFirstChild("BaseGold")
	if not data or not baseGold then return end

	local currentLevel = playerStorageLevels[userId] or 1
	local nextLevel = math.min(currentLevel + 1, #storageLevels)
	local cost = storageLevels[currentLevel]
	if baseGold.Value < cost then return end

	-- Deduct cost
	baseGold.Value = baseGold.Value - cost
	data.storedGold = data.storedGold - cost
	updateBillboard(userId)

	-- Upgrade storage level
	playerStorageLevels[userId] = nextLevel
	data.maxStorage = storageLevels[nextLevel]
	updateBaseColor(userId)

	-- Sync to client
	player:SetAttribute("StorageLevel", nextLevel)

	-- Auto-deposit any extra personal gold up to new capacity
	local goldStat = stats:FindFirstChild("Gold")
	local baseStat = stats:FindFirstChild("BaseGold")
	if goldStat and baseStat then
		local carried = goldStat.Value
		local spaceLeft = data.maxStorage - data.storedGold
		if spaceLeft > 0 and carried > 0 then
			local deposit = math.min(carried, spaceLeft)
			data.storedGold = data.storedGold + deposit
			goldStat.Value = carried - deposit
			baseStat.Value = data.storedGold
			updateBillboard(userId)
		end
	end
end)

-- Handle kill bounty upgrade with cost
ChangeKillBounty.OnServerEvent:Connect(function(player)
	local userId = player.UserId
	local data   = playerBasesData[userId]
	local stats  = player:FindFirstChild("leaderstats")
	local baseGold = stats and stats:FindFirstChild("BaseGold")
	if not data or not baseGold then return end

	local currentLevel = playerKillBountyLevels[userId] or 0
	local nextLevel = currentLevel + 1
	if nextLevel > #killBountyRewards then return end
	local cost = killBountyCosts[nextLevel]
	if baseGold.Value < cost then return end

	baseGold.Value = baseGold.Value - cost
	data.storedGold = data.storedGold - cost
	updateBillboard(userId)

	-- Auto-deposit extra carried gold up to base capacity
	local goldStat = stats:FindFirstChild("Gold")
	local spaceLeft = data.maxStorage - data.storedGold
	if goldStat and spaceLeft > 0 then
		local deposit = math.min(goldStat.Value, spaceLeft)
		data.storedGold = data.storedGold + deposit
		baseGold.Value = data.storedGold
		goldStat.Value = goldStat.Value - deposit
		updateBillboard(userId)
	end

	-- increase level
	playerKillBountyLevels[userId] = nextLevel
	player:SetAttribute("KillBountyReward", killBountyRewards[nextLevel])
end)

-- Passive auto-mining loop
task.spawn(function()
	while true do
		task.wait(1)
		for userId, speed in pairs(playerMineSpeeds) do
			if speed and speed > 0 then
				local data = playerBasesData[userId]
				if data then
					local maxStorage = data.maxStorage or storageLevels[1]
					local spaceLeft = maxStorage - data.storedGold
					if spaceLeft > 0 then
						local add = math.min(speed, spaceLeft)
						-- Farmer class passive: +50% gold from auto miner
						local owner = Players:GetPlayerByUserId(userId)
						if owner and owner:GetAttribute("ClassName") == "Farmer" then
							add = add * 1.5
						end
						data.storedGold = data.storedGold + add
						updateBillboard(userId)
						local owner = Players:GetPlayerByUserId(userId)
						if owner then
							local bs = owner:FindFirstChild("leaderstats")
								and owner.leaderstats:FindFirstChild("BaseGold")
							if bs then bs.Value = data.storedGold end
						end
					end
				end
			end
		end
	end
end)

-- Cleanup on leave
Players.PlayerRemoving:Connect(function(player)
	playerBaseStates[player.UserId] = nil
	playerBasesData[player.UserId]  = nil
end)

-- /////////////////////////////////////////////////////////////////
-- Player respawn handling: spawn at own base if it exists
-- /////////////////////////////////////////////////////////////////
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		-- small delay to ensure HumanoidRootPart exists and physics ready
		char:WaitForChild("HumanoidRootPart", 3)
		task.wait(0.1)
		local data = playerBasesData[player.UserId]
		if data and data.basePart then
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if hrp then
				-- spawn roughly at the centre of the base (inside the sphere)
				local hrp = char:FindFirstChild("HumanoidRootPart")
				if hrp then
					hrp.CFrame = CFrame.new(data.basePart.Position)
				end

				-- ensure player is marked as inside base
				local state = playerBaseStates[player.UserId]
				if state then
					state.isTouchingBase = true
					state.touchStartTime = tick()
					state.character = char
				end
				-- directly enter base (invincibility etc.)
				enterBase(player, char)
			end
		end
	end)
end)
