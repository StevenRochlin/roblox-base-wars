-- AbilityController.client.lua
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local DamageBillboardHandler = require(ReplicatedStorage:WaitForChild("WeaponsSystem"):WaitForChild("Libraries"):WaitForChild("DamageBillboardHandler"))

local player = Players.LocalPlayer

-- Wait for remotes folder and events
local remotesFolder = ReplicatedStorage:WaitForChild("ClassRemotes", 10)
if not remotesFolder then
    warn("[AbilityController] ClassRemotes folder not found")
    return
end

local FireAbility = remotesFolder:WaitForChild("FireAbility")
-- Connect to billboard remote when available
local function hookBillboardRemote(remote)
    if not remote or not remote:IsA("RemoteEvent") then return end
    local signal = (remote :: any).OnClientEvent
    if signal then
        (signal :: any):Connect(function(damage, headPart)
            if DamageBillboardHandler and headPart then
                DamageBillboardHandler:ShowDamageBillboard(damage, headPart)
            end
        end)
    end
end

-- Attempt immediate fetch
local billboardRemote = remotesFolder:FindFirstChild("ShowDamageBillboard")
if billboardRemote then
    hookBillboardRemote(billboardRemote)
end

-- Listen for remote added later
remotesFolder.ChildAdded:Connect(function(child)
    if child.Name == "ShowDamageBillboard" then
        hookBillboardRemote(child)
    end
end)

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
        elseif abilityName == "PowderBomb" then
            -- Use camera direction so player can aim up/down
            local camLook = workspace.CurrentCamera and workspace.CurrentCamera.CFrame.LookVector or Vector3.new(0, 0, -1)
            payloadDir = camLook
        end

        FireAbility:FireServer(abilityName, payloadDir)
    end
end) 