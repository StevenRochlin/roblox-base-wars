local Deflect = {}

-- Duration (seconds) the deflect is active
Deflect.Duration = 6 -- extended for debugging
-- Cooldown between uses
Deflect.Cooldown = 1 -- short cooldown for rapid testing
-- Optional animation played via ClassManager when ability fires
-- We'll play animation manually; leave nil so ClassManager doesn't auto-play
Deflect.AnimationId = nil

-- simple table tracking last-use times
local lastUse = {}

local function canUse(player)
    local now = tick()
    local uid = player.UserId
    if (not lastUse[uid]) or (now - lastUse[uid]) >= Deflect.Cooldown then
        lastUse[uid] = now
        return true
    end
    return false
end

function Deflect.ServerActivate(player)
    if not canUse(player) then return false end

    local char = player.Character
    if not char then return false end

    -- Tag character so weapons/bullets can recognise deflecting state
    char:SetAttribute("Deflecting", true)

    -- Play deflect animation manually
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid then
        local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
        local anim = Instance.new("Animation")
        anim.AnimationId = "rbxassetid://120698851973690"
        local track
        pcall(function()
            track = animator:LoadAnimation(anim)
        end)
        anim:Destroy()
        if track then
            track.Priority = Enum.AnimationPriority.Action4
            track.Looped = true
            track:Play()
            -- Stop after duration
            task.delay(Deflect.Duration, function()
                if track.IsPlaying then track:Stop() end
                track:Destroy()
            end)
        end
    end

    -- Auto-clear after duration
    task.delay(Deflect.Duration, function()
        if char and char:GetAttribute("Deflecting") then
            char:SetAttribute("Deflecting", nil)
        end
    end)

    return true -- ability activated
end

return Deflect 