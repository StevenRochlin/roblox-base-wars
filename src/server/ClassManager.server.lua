-- ClassManager.server.lua
print("ClassManager loaded")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- /////////////////////////////////////////////////////////////////
-- Disable WeaponSystem movement modifiers globally
-- /////////////////////////////////////////////////////////////////
do
    local weaponsSystemFolder = ReplicatedStorage:FindFirstChild("WeaponsSystem")
    if weaponsSystemFolder then
        local configFolder = weaponsSystemFolder:FindFirstChild("Configuration")
        if configFolder then
            local sprintBool = configFolder:FindFirstChild("SprintEnabled")
            if sprintBool then sprintBool.Value = false end
            local slowZoomBool = configFolder:FindFirstChild("SlowZoomWalkEnabled")
            if slowZoomBool then slowZoomBool.Value = false end
        end
    end
end

-- /////////////////////////////////////////////////////////////////
-- Remote events setup
-- /////////////////////////////////////////////////////////////////
local remotesFolder = ReplicatedStorage:FindFirstChild("ClassRemotes")
if not remotesFolder then
    remotesFolder = Instance.new("Folder")
    remotesFolder.Name = "ClassRemotes"
    remotesFolder.Parent = ReplicatedStorage
end

local function getOrCreateRemote(name)
    local r = remotesFolder:FindFirstChild(name)
    if not r then
        r = Instance.new("RemoteEvent")
        r.Name = name
        r.Parent = remotesFolder
    end
    return r
end

local RequestClassEquip = getOrCreateRemote("RequestClassEquip")
local FireAbility       = getOrCreateRemote("FireAbility")

-- /////////////////////////////////////////////////////////////////
-- Shared modules
-- /////////////////////////////////////////////////////////////////
local ClassConfig       = require(ReplicatedStorage:WaitForChild("ClassConfig"))
local AbilityRegistry   = require(ReplicatedStorage:WaitForChild("AbilityRegistry"))
-- Folder where class items are stored
local ClassItemsFolder  = ReplicatedStorage:WaitForChild("ClassItems")

-- Folder that contains HumanoidDescription objects named after classes
local ClassAvatarsFolder = ReplicatedStorage:FindFirstChild("ClassAvatars")

-- NEW: Folder that contains full character models named after classes
local ClassCharactersFolder = ReplicatedStorage:FindFirstChild("ClassCharacters") or ReplicatedStorage:FindFirstChild("Characters")

-- /////////////////////////////////////////////////////////////////
-- Helper: apply avatar
-- /////////////////////////////////////////////////////////////////
local function applyAvatar(player, className)
	if not ClassAvatarsFolder then return end
	local desc = ClassAvatarsFolder:FindFirstChild(className)
	if not desc or not desc:IsA("HumanoidDescription") then return end

	local char = player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if humanoid then
		-- Apply the avatar description safely
		pcall(function()
			humanoid:ApplyDescription(desc)
		end)
	end
end

-- /////////////////////////////////////////////////////////////////
-- Helper: ensure Animate script exists on character
-- /////////////////////////////////////////////////////////////////
local function ensureAnimateScript(char)
	if char:FindFirstChild("Animate") then
		return
	end

	-- Try to clone from StarterPlayer
	local starterAnimate = game:GetService("StarterPlayer").StarterCharacterScripts:FindFirstChild("Animate")
	if starterAnimate then
		starterAnimate:Clone().Parent = char
	end
end

-- /////////////////////////////////////////////////////////////////
-- Helper: swap full character model (if provided)
-- /////////////////////////////////////////////////////////////////
local function swapCharacterModel(player, className)
	if not ClassCharactersFolder then
		return false -- no folder present
	end

	local template = ClassCharactersFolder:FindFirstChild(className)
	if not template then
		return false -- no matching model
	end

	local oldChar = player.Character
	if not oldChar or not oldChar.PrimaryPart then
		return false -- cannot determine spawn CFrame
	end

	local spawnCFrame = oldChar.PrimaryPart.CFrame

	local newChar = template:Clone()
	-- Ensure we have a primary part before assigning
	if newChar:FindFirstChild("HumanoidRootPart") then
		newChar.PrimaryPart = newChar.HumanoidRootPart
	elseif newChar.PrimaryPart == nil then
		warn("[ClassManager] Character model for " .. className .. " is missing HumanoidRootPart / PrimaryPart")
		return false
	end

	newChar.Name = player.Name
    -- Assign character BEFORE parenting to mimic original behaviour
	player:SetAttribute("IsClassSwapping", true)
	player.Character = newChar
	newChar.Parent = workspace
	-- Preserve yaw but reset roll/pitch to keep character upright
	local pos = spawnCFrame.Position
	local look = Vector3.new(spawnCFrame.LookVector.X, 0, spawnCFrame.LookVector.Z)
	if look.Magnitude < 1e-4 then look = Vector3.new(0,0,-1) end
	local uprightCFrame = CFrame.lookAt(pos, pos + look)
	newChar:SetPrimaryPartCFrame(uprightCFrame)

	-- Copy essential scripts/objects if the template is missing them
	if oldChar:FindFirstChild("Animate") and not newChar:FindFirstChild("Animate") then
		oldChar.Animate:Clone().Parent = newChar
	end
	if oldChar:FindFirstChild("Health") and not newChar:FindFirstChild("Health") then
		oldChar.Health:Clone().Parent = newChar
	end
	-- Fallback ensure animate exists
	ensureAnimateScript(newChar)

	-- Tell CharacterAdded listeners this is an intentional swap
	player:SetAttribute("IsClassSwapping", true)
	player.Character = newChar
	-- DO NOT clear here; CharacterAdded handler will clear after initialization

	-- Make sure nothing stays anchored
	for _, inst in ipairs(newChar:GetDescendants()) do
		if inst:IsA("BasePart") then
			inst.Anchored = false
		end
	end

	return true
end

-- /////////////////////////////////////////////////////////////////
-- Helper: give tool from ClassItems folder instead of Assets.Tools
-- /////////////////////////////////////////////////////////////////
local function giveTool(player, toolName)
    local template = ClassItemsFolder:FindFirstChild(toolName)
    if not template then
        warn("[ClassManager] Missing class item: " .. toolName)
        return
    end

    local tool = template:Clone()
    tool.Parent = player.Backpack

    local starterGear = player:FindFirstChild("StarterGear")
    if not starterGear then
        starterGear = Instance.new("Folder")
        starterGear.Name = "StarterGear"
        starterGear.Parent = player
    end
    template:Clone().Parent = starterGear
end

-- /////////////////////////////////////////////////////////////////
-- Equip class tier (only Archer tier 0 for now)
-- /////////////////////////////////////////////////////////////////
local function equipClass(player, className, tier)
    tier = tier or 0
    local config = ClassConfig[className]
    if not config then
        warn("[ClassManager] Unknown class: " .. tostring(className))
        return
    end
    local tierData = config.Tiers[tier]
    if not tierData then
        warn("[ClassManager] Tier " .. tier .. " missing for class " .. className)
        return
    end

    -- Attempt to swap full character model first. If unavailable, fallback to avatar description.
    local swapped = swapCharacterModel(player, className)
    if not swapped then
        -- apply avatar via HumanoidDescription when no dedicated model
        applyAvatar(player, className)
    end

    -- Ensure we operate on the (possibly) new character
    local char = player.Character or player.CharacterAdded:Wait()
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.MaxHealth = tierData.MaxHealth or humanoid.MaxHealth
        humanoid.Health = humanoid.MaxHealth
        -- Apply other humanoid settings if specified
        if tierData.HumanoidProperties then
            for prop, value in pairs(tierData.HumanoidProperties) do
                if humanoid[prop] ~= nil then
                    humanoid[prop] = value
                end
            end
        end
    end

    -- clear existing tools
    for _, tool in ipairs(player.Backpack:GetChildren()) do
        if tool:IsA("Tool") then tool:Destroy() end
    end
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") then tool:Destroy() end
    end

    -- give new tool(s)
    local loadout = tierData.Loadout
    if loadout then
        if loadout.Tool then
            giveTool(player, loadout.Tool)
        elseif loadout.Tools then
            for _, toolName in ipairs(loadout.Tools) do
                giveTool(player, toolName)
            end
        end
    end

    -- Tag player attributes
    player:SetAttribute("ClassName", className)
    player:SetAttribute("ClassTier", tier)
end

-- /////////////////////////////////////////////////////////////////
-- Player setup
-- /////////////////////////////////////////////////////////////////
local function onPlayerAdded(player)
    -- auto-equip Archer tier 0 for now
    player.CharacterAdded:Connect(function()
        if player:GetAttribute("IsClassSwapping") then
            -- internal model swap; clear flag and skip auto-equip
            player:SetAttribute("IsClassSwapping", false)
            return
        end

        local savedClass = player:GetAttribute("ClassName") or "Archer"
        local savedTier  = player:GetAttribute("ClassTier") or 0
        equipClass(player, savedClass, savedTier)
    end)

    if player.Character then
        equipClass(player, "Archer", 0)
    end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
    onPlayerAdded(p)
end

-- /////////////////////////////////////////////////////////////////
-- Handle equip requests (future-proof)
-- /////////////////////////////////////////////////////////////////
RequestClassEquip.OnServerEvent:Connect(function(player, className, tier)
    equipClass(player, className, tier or 0)
end)

-- /////////////////////////////////////////////////////////////////
-- Ability handling (simple proxy to registry)
-- /////////////////////////////////////////////////////////////////
local playerCooldowns = {}

FireAbility.OnServerEvent:Connect(function(player, abilityName, payload)
    local ability = AbilityRegistry[abilityName]
    if not ability then return end

    -- cooldown handling in ability module (Roll.lua) already, but keep placeholder
    if ability.ServerActivate then
        ability.ServerActivate(player, payload)
    end
end) 