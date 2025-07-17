-- ClassManager.server.lua
print("ClassManager loaded")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Remote events setup
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

-- Shared modules
local ClassConfig      = require(ReplicatedStorage:WaitForChild("ClassConfig"))
local AbilityRegistry  = require(ReplicatedStorage:WaitForChild("AbilityRegistry"))
local ClassItemsFolder = ReplicatedStorage:WaitForChild("ClassItems")

-- Equip class tier
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

    -- Give starter tool from class Loadout
    if tierData.Loadout and tierData.Loadout.Tool then
        local toolName = tierData.Loadout.Tool
        local template = ClassItemsFolder:FindFirstChild(toolName)
        if template then
            template:Clone().Parent = player.Backpack
        else
            warn("[ClassManager] Missing tool template: " .. toolName)
        end
    end

    -- Tag player attributes
    player:SetAttribute("ClassName", className)
    player:SetAttribute("ClassTier", tier)
end

-- Player setup: auto-equip
local function onPlayerAdded(player)
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

-- Handle equip requests
RequestClassEquip.OnServerEvent:Connect(function(player, className, tier)
    equipClass(player, className, tier)
end)

-- Ability handling
FireAbility.OnServerEvent:Connect(function(player, abilityName, payload)
    local ability = AbilityRegistry[abilityName]
    if ability and ability.ServerActivate then
        ability.ServerActivate(player, payload)
    end
end) 