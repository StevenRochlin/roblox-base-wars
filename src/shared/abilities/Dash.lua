local Dash = {}

Dash.Cooldown = 3 -- seconds

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

function Dash.ServerActivate(player)
    if not canUse(player) then return end

    local character = player.Character
    if not character then return end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid then return end

    local direction = hrp.CFrame.LookVector.Unit
    local bv = Instance.new("BodyVelocity")
    bv.Name = "DashVelocity"
    bv.MaxForce = Vector3.new(1e5, 0, 1e5)
    bv.Velocity = direction * 100
    bv.Parent = hrp

    task.delay(0.3, function()
        if bv and bv.Parent then bv:Destroy() end
    end)
end

return Dash 