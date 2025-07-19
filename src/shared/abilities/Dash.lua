local TweenService = game:GetService("TweenService")

local Dash = {}

Dash.Cooldown = 3 -- seconds
Dash.PeakSpeed = 200  -- studs per second
Dash.Duration = 0.5  -- total dash time 

local lastUse = {}

local function canUse(player)
    local t = tick()
    local uid = player.UserId
    if not lastUse[uid] or (t - lastUse[uid]) >= Dash.Cooldown then
        lastUse[uid] = t
        return true
    end
    return false
end

function Dash.ServerActivate(player, payload)
    if not canUse(player) then return end

    local character = player.Character
    if not character then return end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid then return end

    -- Determine dash direction (horizontal plane)
    local direction = nil
    if payload and typeof(payload) == "Vector3" and payload.Magnitude > 0.05 then
        direction = payload.Unit
    end
    if not direction then
        direction = hrp.CFrame.LookVector.Unit
    end

    -- Apply BodyVelocity for immediate acceleration; we'll cut it off instantly later
    local bv = Instance.new("BodyVelocity")
    bv.Name = "DashVelocity"
    bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bv.Velocity = direction * Dash.PeakSpeed
    bv.Parent = hrp

    -- After the set duration, instantly stop by removing BodyVelocity and clearing momentum
    task.delay(Dash.Duration, function()
        if bv and bv.Parent then
            bv:Destroy()
        end
        -- Zero out all velocity so momentum doesn't carry after dash
        if hrp and hrp.Parent then
            hrp.AssemblyLinearVelocity = Vector3.new()
        end
    end)
end

return Dash 