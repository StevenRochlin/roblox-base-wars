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

-- Simple binding: Q -> Roll ability
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.Q then
        FireAbility:FireServer("Roll")
    end
end) 