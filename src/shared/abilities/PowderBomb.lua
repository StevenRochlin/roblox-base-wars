local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local PowderBomb = {}

-- Public config read by client cooldown UI
PowderBomb.Cooldown = 6 -- seconds
-- Animation asset to play when throwing the bomb
PowderBomb.AnimationId = "90285123596433"

-- Tuning values
-- Launch parameters
PowderBomb.ThrowForce = 100           -- studs/sec (slower travel)
-- Additional upward force (initial)
PowderBomb.VerticalBoost = 10         -- studs/sec
-- Gravity scaling (1 = normal gravity, 0.6 = 40% less gravity)
PowderBomb.GravityScale = 0.6
PowderBomb.ExplosionRadius = 30      -- studs
PowderBomb.Damage = 60               -- hit points dealt to enemy players

-- /////////////////////////////////////////////////////////////////
-- Internal helpers
-- /////////////////////////////////////////////////////////////////
local lastUse = {}

local function canUse(player)
    local t = tick()
    local uid = player.UserId
    if not lastUse[uid] or (t - lastUse[uid]) >= PowderBomb.Cooldown then
        lastUse[uid] = t
        return true
    end
    return false
end

local function getGrenadeTemplate()
    local ws = ReplicatedStorage:FindFirstChild("WeaponsSystem")
    if not ws then return nil end
    local assets = ws:FindFirstChild("Assets")
    local effects = assets and assets:FindFirstChild("Effects")
    local shots = effects and effects:FindFirstChild("Shots")
    return shots and shots:FindFirstChild("Grenade") or nil
end

-- /////////////////////////////////////////////////////////////////
-- Public API (required by AbilityRegistry)
-- /////////////////////////////////////////////////////////////////
function PowderBomb.ServerActivate(player, payload)
    if not canUse(player) then return end

    local character = player.Character
    if not character then return end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- Grab template (warn and abort if missing)
    local template = getGrenadeTemplate()
    if not template then
        warn("[PowderBomb] Grenade template missing under ReplicatedStorage.WeaponsSystem.Assets.Effects.Shots")
        return
    end

    -- Clone grenade template (could be a Model OR a single Part)
    local grenade = template:Clone()
    grenade.Name = "PowderBomb"
    grenade.Parent = workspace

    -- Determine the actual physics part that will be thrown (root)
    local rootPart
    if grenade:IsA("Model") then
        -- Ensure model is unanchored and collidable
        for _, obj in ipairs(grenade:GetDescendants()) do
            if obj:IsA("BasePart") then
                obj.Anchored = false
                obj.CanCollide = true
            end
        end
        rootPart = grenade.PrimaryPart or grenade:FindFirstChildWhichIsA("BasePart")
    elseif grenade:IsA("BasePart") then
        -- Single part asset
        rootPart = grenade
        rootPart.Anchored = false
        rootPart.CanCollide = true
    end

    if not rootPart then
        grenade:Destroy()
        warn("[PowderBomb] No movable part found on grenade asset")
        return
    end

    -- Position a bit in front of the character
    rootPart.CFrame = hrp.CFrame * CFrame.new(0, 1.5, -2)

    -- Determine aim direction: use payload from client if valid, else fallback to character look
    local aimDir
    if payload and typeof(payload) == "Vector3" and payload.Magnitude > 0.001 then
        aimDir = payload.Unit
    else
        aimDir = hrp.CFrame.LookVector.Unit
    end

    -- Apply velocity along aim direction, with optional vertical boost
    local velocity = aimDir * PowderBomb.ThrowForce
    if PowderBomb.VerticalBoost ~= 0 then
        velocity = velocity + Vector3.new(0, PowderBomb.VerticalBoost, 0)
    end
    rootPart.AssemblyLinearVelocity = velocity

    -- Prepare anti-gravity holders (defined later)
    local att, vForce

    local exploded = false
    local function explode()
        if exploded then return end
        exploded = true

        local pos = rootPart.Position

        -- Visual explosion (optional pressure disabled to avoid physics chaos)
        local exp = Instance.new("Explosion")
        exp.Position = pos
        exp.BlastRadius = PowderBomb.ExplosionRadius
        exp.BlastPressure = 0
        exp.DestroyJointRadiusPercent = 0
        exp.Parent = workspace

        -- Custom damage application (server-authoritative)
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= player and plr.Character then
                local hum = plr.Character:FindFirstChildOfClass("Humanoid")
                local root = plr.Character:FindFirstChild("HumanoidRootPart")
                if hum and root then
                    local dist = (root.Position - pos).Magnitude
                    if dist <= PowderBomb.ExplosionRadius then
                        hum:TakeDamage(PowderBomb.Damage)
                    end
                end
            end
        end

        -- Clean up grenade pieces
        grenade:Destroy()

        -- Cleanup anti-gravity helpers if they exist
        if vForce and vForce.Parent then vForce:Destroy() end
        if att and att.Parent then att:Destroy() end
    end

    -- /////////////////////////////////////////////////////////////
    -- Apply VectorForce to reduce effective gravity (after explode defined)
    -- /////////////////////////////////////////////////////////////
    if PowderBomb.GravityScale < 1 then
        local mass = rootPart.AssemblyMass
        local g = workspace.Gravity
        local offset = (1 - PowderBomb.GravityScale) * mass * g

        att = Instance.new("Attachment")
        att.Name = "PowderBombAttach"
        att.Parent = rootPart

        vForce = Instance.new("VectorForce")
        vForce.Name = "AntiGravityForce"
        vForce.Force = Vector3.new(0, offset, 0)
        vForce.Attachment0 = att
        vForce.RelativeTo = Enum.ActuatorRelativeTo.World
        vForce.Parent = rootPart
    end

    -- Explode on first touch with non-ally object (ignore thrower)
    local touchConn
    touchConn = rootPart.Touched:Connect(function(hit)
        if hit and hit:IsDescendantOf(character) then return end
        if touchConn then touchConn:Disconnect() end
        explode()
    end)

    -- Safety fuse: explode after 4 seconds if not already
    task.delay(4, explode)

    -- Cleanup in case something goes wrong
    Debris:AddItem(grenade, 6)

    return true -- signal successful activation
end

return PowderBomb 