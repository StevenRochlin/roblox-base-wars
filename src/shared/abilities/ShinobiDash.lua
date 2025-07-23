local Players = game:GetService("Players")

local ShinobiDash = {}

-- Ability parameters
ShinobiDash.Cooldown       = 3        -- seconds between uses
ShinobiDash.PeakSpeed      = 225      -- studs/second (2/3 of previous)
ShinobiDash.Duration       = 0.4      -- dash time (half of previous)
ShinobiDash.Damage         = 60       -- damage dealt to each enemy hit
ShinobiDash.HitboxRadius   = 4        -- radius of spherical hitbox around the player whilst dashing

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local hitEvent = ReplicatedStorage:FindFirstChild("DashHitMarker")
if not hitEvent then
    hitEvent = Instance.new("RemoteEvent")
    hitEvent.Name = "DashHitMarker"
    hitEvent.Parent = ReplicatedStorage
end

-- Optional animation asset id
ShinobiDash.AnimationId    = "96455131735328"

-- Internal state: last time each player used the dash
local lastUse: {[number]: number} = {}

local PhysicsService = game:GetService("PhysicsService")
local DASH_GROUP     = "ShinobiDash"

-- Ensure group exists (created elsewhere but safe)
pcall(function() PhysicsService:CreateCollisionGroup(DASH_GROUP) end)

-- =========================================================
-- Helper functions
-- =========================================================
local function canUse(player)
    local now = tick()
    local uid = player.UserId
    if (not lastUse[uid]) or (now - lastUse[uid] >= ShinobiDash.Cooldown) then
        lastUse[uid] = now
        return true
    end
    return false
end

local function resetCooldown(player)
    lastUse[player.UserId] = nil
end

-- ---------------------------------------------------------
-- Figure out dash direction (same logic as base Dash ability)
-- ---------------------------------------------------------
local function computeDirection(hrp, payload)
    local direction
    if payload then
        if typeof(payload) == "Vector3" and payload.Magnitude > 0.05 then
            direction = payload.Unit
        elseif typeof(payload) == "table" and payload.lookDir and payload.moveDir then
            local lookDir = payload.lookDir
            local moveDir = payload.moveDir

            local horizLook = Vector3.new(lookDir.X, 0, lookDir.Z)
            local horizMove = Vector3.new(moveDir.X, 0, moveDir.Z)

            if horizMove.Magnitude < 0.05 then
                horizMove = horizLook
            end

            local dot = 0
            if horizLook.Magnitude > 0.001 and horizMove.Magnitude > 0.001 then
                dot = horizMove.Unit:Dot(horizLook.Unit)
            end
            local verticalY = lookDir.Y * dot
            direction = Vector3.new(horizMove.X, verticalY, horizMove.Z)
            if direction.Magnitude > 0 then
                direction = direction.Unit
            else
                direction = nil
            end
        end
    end
    if not direction then
        direction = hrp.CFrame.LookVector.Unit
    end
    return direction
end

-- =========================================================
-- Main activation entry point (server-side)
-- =========================================================
function ShinobiDash.ServerActivate(player, payload)
    if not canUse(player) then return end

    local character = player.Character
    if not character then return end

    local hrp      = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid then return end

    -- Switch collision group for all character parts to DASH_GROUP to pass through others
    local originalGroups = {}
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            originalGroups[part] = PhysicsService:GetCollisionGroupName(part.CollisionGroupId)
            PhysicsService:SetPartCollisionGroup(part, DASH_GROUP)
        end
    end

    local direction = computeDirection(hrp, payload)

    -- Apply initial velocity using a BodyVelocity
    local bv = Instance.new("BodyVelocity")
    bv.Name      = "ShinobiDashVelocity"
    bv.MaxForce  = Vector3.new(1e5, 1e5, 1e5)
    bv.Velocity  = direction * ShinobiDash.PeakSpeed
    bv.Parent    = hrp

    -- Create spherical hitbox welded to the root part
    local hitbox = Instance.new("Part")
    hitbox.Name          = "ShinobiDashHitbox"
    hitbox.Shape         = Enum.PartType.Ball
    hitbox.Size          = Vector3.new(ShinobiDash.HitboxRadius*2, ShinobiDash.HitboxRadius*2, ShinobiDash.HitboxRadius*2)
    hitbox.Transparency  = 1
    hitbox.CanCollide    = false
    hitbox.CanTouch      = true
    hitbox.Massless      = true
    hitbox.CFrame        = hrp.CFrame
    hitbox.Parent        = character

    -- Weld hitbox to root part so it travels with the player
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = hitbox
    weld.Part1 = hrp
    weld.Parent = hitbox

    local damaged: {[Humanoid]: boolean} = {}
    local connection
    connection = hitbox.Touched:Connect(function(part)
        local otherHumanoid = part.Parent and part.Parent:FindFirstChildOfClass("Humanoid")
        if otherHumanoid and otherHumanoid ~= humanoid and otherHumanoid.Health > 0 then
            local otherPlayer = Players:GetPlayerFromCharacter(part.Parent)
            if otherPlayer ~= player then
                if not damaged[otherHumanoid] then
                    damaged[otherHumanoid] = true

                    -- Tag the humanoid so kill credit is awarded
                    local tag = Instance.new("ObjectValue")
                    tag.Name  = "creator"
                    tag.Value = player
                    tag.Parent = otherHumanoid
                    game.Debris:AddItem(tag, 2)

                    otherHumanoid:TakeDamage(ShinobiDash.Damage)

                    -- Fire client-side hitmarker for immediate feedback
                    hitEvent:FireClient(player)

                    -- If this hit kills the target, reset cooldown immediately after Died event fires
                    if otherHumanoid.Health - ShinobiDash.Damage <= 0 then
                        local diedConn
                        diedConn = otherHumanoid.Died:Connect(function()
                            resetCooldown(player)
                            if diedConn then
                                diedConn:Disconnect()
                            end
                        end)
                    end
                end
            end
        end
    end)

    -- Cleanup after dash ends
    task.delay(ShinobiDash.Duration, function()
        -- Restore collision groups
        for p, grpName in pairs(originalGroups) do
            if p and p.Parent then
                PhysicsService:SetPartCollisionGroup(p, grpName)
            end
        end
        if connection then connection:Disconnect() end
        if hitbox and hitbox.Parent then hitbox:Destroy() end
        if bv and bv.Parent then bv:Destroy() end
        if hrp and hrp.Parent then
            hrp.AssemblyLinearVelocity = Vector3.new()
        end
    end)
end

return ShinobiDash 