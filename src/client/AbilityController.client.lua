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

-- Simple binding: Shift -> class-specific ability
UserInputService.InputBegan:Connect(function(input, processed)
    -- Allow Shift ability even if processed by another action (e.g., sprint)
    if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
        local className = player:GetAttribute("ClassName") or "Archer"
        local tier = player:GetAttribute("ClassTier") or 0
        local tierData = ClassConfig[className] and ClassConfig[className].Tiers[tier]
        local abilityName = (tierData and tierData.Loadout and tierData.Loadout.Ability) or "Roll"
        local payloadDir = Vector3.new()

        if abilityName == "Roll" then
            -- Use movement direction for roll
            local char = player.Character
            local humanoid = char and char:FindFirstChildOfClass("Humanoid")
            if humanoid then
                payloadDir = humanoid.MoveDirection
            end
        elseif abilityName == "Dash" or abilityName == "ShinobiDash" then
            -- Use movement direction for dash
            local char = player.Character
            local humanoid = char and char:FindFirstChildOfClass("Humanoid")
            if humanoid then
                payloadDir = humanoid.MoveDirection
            end
            -- Combine camera look (for vertical component) with movement direction (for horizontal)
            local camLook = workspace.CurrentCamera and workspace.CurrentCamera.CFrame.LookVector or Vector3.new(0,0,-1)
            local moveDir = Vector3.new()
            local char = player.Character
            local humanoid = char and char:FindFirstChildOfClass("Humanoid")
            if humanoid then
                moveDir = humanoid.MoveDirection
            end
            payloadDir = {lookDir = camLook, moveDir = moveDir}
        end

        FireAbility:FireServer(abilityName, payloadDir)
    end
end) 