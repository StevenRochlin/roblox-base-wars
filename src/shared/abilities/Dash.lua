local TweenService = game:GetService("TweenService")

local Dash = {}

Dash.Cooldown = 3 -- seconds
Dash.PeakSpeed = 210  -- studs per second
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

            -- Scale vertical component by how much forward/back component exists
            local dot = 0
            if horizLook.Magnitude > 0.001 and horizMove.Magnitude > 0.001 then
                dot = horizMove.Unit:Dot(horizLook.Unit) -- -1 back, 1 forward, 0 side
            end
            local verticalY = lookDir.Y * dot -- side movement (dot~0) contributes no vertical, diagonal partial

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