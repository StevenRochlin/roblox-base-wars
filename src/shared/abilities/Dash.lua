local TweenService = game:GetService("TweenService")

local Dash = {}

Dash.Cooldown = 3 -- seconds
Dash.PeakSpeed = 160  -- studs per second
Dash.Duration = 0.85  -- total dash time

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
        direction = Vector3.new(payload.X, 0, payload.Z).Unit
    end
    if not direction then
        direction = hrp.CFrame.LookVector.Unit
    end

    -- Apply BodyVelocity for immediate acceleration then tween it to zero
    local bv = Instance.new("BodyVelocity")
    bv.Name = "DashVelocity"
    bv.MaxForce = Vector3.new(1e5, 0, 1e5)
    bv.Velocity = direction * Dash.PeakSpeed
    bv.Parent = hrp

    -- Tween velocity to zero over Duration with ease-out
    local tween = TweenService:Create(bv, TweenInfo.new(Dash.Duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Velocity = Vector3.new()})
    tween:Play()

    tween.Completed:Connect(function()
        if bv and bv.Parent then
            bv:Destroy()
        end
    end)
end

return Dash 