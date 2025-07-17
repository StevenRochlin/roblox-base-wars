-- AbilityController.client.lua
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

-- Wait for remotes folder and events
local remotesFolder = ReplicatedStorage:WaitForChild("ClassRemotes", 10)
if not remotesFolder then
    warn("[AbilityController] ClassRemotes folder not found")
    return
end

local FireAbility = remotesFolder:WaitForChild("FireAbility")
local ClassConfig = require(ReplicatedStorage:WaitForChild("ClassConfig"))

-- Simple binding: Q -> class-specific ability
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.Q then
        local className = player:GetAttribute("ClassName") or "Archer"
        local tier = player:GetAttribute("ClassTier") or 0
        local tierData = ClassConfig[className] and ClassConfig[className].Tiers[tier]
        local abilityName = (tierData and tierData.Loadout and tierData.Loadout.Ability) or "Roll"
        FireAbility:FireServer(abilityName)
    end
end) 