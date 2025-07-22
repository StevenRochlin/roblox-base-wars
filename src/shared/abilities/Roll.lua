local Roll = {}

Roll.Cooldown = 3 -- seconds

-- ADD: animation asset id (string or number)
Roll.AnimationId = "83072450499671" -- roll animation asset

-- adjust speed multiplier (studs/sec) – half previous (was 100)
Roll.Speed = 50

-- Utility: simple cooldown tracking table (not stored here in production)
local lastUse = {}

local function canUse(player)
    local t = tick()
    local uid = player.UserId
    if not lastUse[uid] or (t - lastUse[uid]) >= Roll.Cooldown then
        lastUse[uid] = t
        return true
    end
    return false
end

function Roll.ServerActivate(player, payload)
    if not canUse(player) then return false end

    local character = player.Character
    if not character then return end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid then return end

    -- Temporarily unequip any held tool to avoid weapon hold offsets interfering with the roll animation
    local equippedTool = character:FindFirstChildOfClass("Tool")
    if equippedTool then
        humanoid:UnequipTools()
    end

    -- Determine roll direction: use client-provided movement vector if valid, else face forward
    local direction = nil
    if payload and typeof(payload) == "Vector3" and payload.Magnitude > 0.05 then
        direction = Vector3.new(payload.X, 0, payload.Z).Unit
    end
    if not direction then
        direction = hrp.CFrame.LookVector.Unit
    end

    -- Create BodyVelocity to override movement briefly
    local bv = Instance.new("BodyVelocity")
    bv.Name = "RollVelocity"
    bv.MaxForce = Vector3.new(1e5, 0, 1e5) -- ignore Y so gravity still applies
    bv.Velocity = direction * Roll.Speed -- adjust speed here
    bv.Parent = hrp

    -- Optional: small invulnerability or animation could be inserted here

    -- Clean up after a short duration
    task.delay(0.3, function()
        -- Clean up velocity
        if bv and bv.Parent then
            bv:Destroy()
        end

        -- Re-equip tool after roll completes, if it is still in backpack
        if equippedTool and equippedTool.Parent == player.Backpack then
            humanoid:EquipTool(equippedTool)
        end
    end)

    return true -- successfully activated
end

return Roll 