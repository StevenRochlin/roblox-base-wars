-- ClassManager.server.lua
print("ClassManager loaded")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

    local char = player.Character or player.CharacterAdded:Wait()
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.MaxHealth = tierData.MaxHealth or humanoid.MaxHealth
        humanoid.Health = humanoid.MaxHealth
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

    -- apply avatar/skin
    applyAvatar(player, className)

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
        equipClass(player, "Archer", 0)
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