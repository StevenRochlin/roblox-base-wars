-- CharacterCollisionGroups.server.lua
-- Sets up collision groups so Shinobi dashes pass through other characters but still collide with the world.

local PhysicsService = game:GetService("PhysicsService")
local Players        = game:GetService("Players")

local PLAYER_GROUP = "PlayerCharacter"
local DASH_GROUP   = "ShinobiDash"

-- Utility to safely create a group only if it doesn't already exist
local function ensureGroup(name)
    local ok = pcall(function()
        PhysicsService:CreateCollisionGroup(name)
    end)
end

ensureGroup(PLAYER_GROUP)
ensureGroup(DASH_GROUP)

-- Configure group collisions
PhysicsService:CollisionGroupSetCollidable(PLAYER_GROUP, PLAYER_GROUP, true)
PhysicsService:CollisionGroupSetCollidable(DASH_GROUP, DASH_GROUP, true)
PhysicsService:CollisionGroupSetCollidable(PLAYER_GROUP, DASH_GROUP, false)
PhysicsService:CollisionGroupSetCollidable(DASH_GROUP, PLAYER_GROUP, false)
-- Both groups should still collide with the default world
PhysicsService:CollisionGroupSetCollidable(PLAYER_GROUP, "Default", true)
PhysicsService:CollisionGroupSetCollidable(DASH_GROUP, "Default", true)

local function setGroupRecursive(model: Model, groupName: string)
    for _, desc in ipairs(model:GetDescendants()) do
        if desc:IsA("BasePart") then
            PhysicsService:SetPartCollisionGroup(desc, groupName)
        end
    end
end

local function onCharacterAdded(player: Player, character: Model)
    -- Assign existing parts immediately
    setGroupRecursive(character, PLAYER_GROUP)

    -- Ensure future parts (accessories etc.) are assigned
    character.DescendantAdded:Connect(function(desc)
        if desc:IsA("BasePart") then
            PhysicsService:SetPartCollisionGroup(desc, PLAYER_GROUP)
        end
    end)
end

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(char)
        onCharacterAdded(player, char)
    end)
    if player.Character then
        onCharacterAdded(player, player.Character)
    end
end)

-- For studio play test: assign to players already present
for _, plr in ipairs(Players:GetPlayers()) do
    if plr.Character then
        onCharacterAdded(plr, plr.Character)
    end
end 