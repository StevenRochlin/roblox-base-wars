local Roll = {}

Roll.Cooldown = 3 -- seconds

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
    if not canUse(player) then return end

    local character = player.Character
    if not character then return end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid then return end

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
    bv.Velocity = direction * 100 -- adjust speed here
    bv.Parent = hrp

    -- Optional: small invulnerability or animation could be inserted here

    -- Clean up after a short duration
    task.delay(0.3, function()
        if bv and bv.Parent then
            bv:Destroy()
        end
    end)
end

return Roll 