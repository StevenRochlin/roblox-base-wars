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
local SharedFolder = ReplicatedStorage:WaitForChild("Shared")
local ClassConfig  = require(SharedFolder:WaitForChild("ClassConfig"))
local AbilityRegistry = require(SharedFolder:WaitForChild("AbilityRegistry"))

-- /////////////////////////////////////////////////////////////////
-- Helper: give tool from ReplicatedStorage.Assets.Tools
-- /////////////////////////////////////////////////////////////////
local function giveTool(player, toolName)
    local assets = ReplicatedStorage:FindFirstChild("Assets")
    if not assets then
        assets = Instance.new("Folder")
        assets.Name = "Assets"
        assets.Parent = ReplicatedStorage
    end
    local toolsFolder = assets:FindFirstChild("Tools")
    if not toolsFolder then
        toolsFolder = Instance.new("Folder")
        toolsFolder.Name = "Tools"
        toolsFolder.Parent = assets
    end

    local template = toolsFolder:FindFirstChild(toolName)
    if not template then
        -- create placeholder tool so at least something equips
        template = Instance.new("Tool")
        template.Name = toolName
        template.RequiresHandle = false
        template.Parent = toolsFolder
    end

    local tool = template:Clone()
    tool.Parent = player.Backpack

    -- also place a copy into StarterGear so it persists on respawn
    local starterGear = player:FindFirstChild("StarterGear")
    if not starterGear then
        starterGear = Instance.new("Folder")
        starterGear.Name = "StarterGear"
        starterGear.Parent = player
    end
    tool:Clone().Parent = starterGear
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
    if loadout and loadout.Tool then
        giveTool(player, loadout.Tool)
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