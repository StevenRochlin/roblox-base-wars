-- ShinobiStealth.server.lua
-- Gradually turns Shinobi players invisible while standing still outside their base.

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local STAND_STILL_THRESHOLD = 0.5   -- studs/s velocity considered "standing"
local IDLE_TIME_FOR_FADE     = 1.5  -- seconds to wait before starting fade
local FADE_DURATION          = 1.5  -- seconds to fully fade
local TARGET_TRANSPARENCY    = 1     -- full invis

-- Track per-player state
local stateMap: {[number]: {
    lastMove: number,
    currentAlpha: number,
}} = {}

local function setCharacterTransparency(character: Model, alpha: number)
    for _, obj in ipairs(character:GetDescendants()) do
        if obj:IsA("BasePart") or obj:IsA("Decal") then
            -- Keep HumanoidRootPart permanently invisible
            if obj.Name == "HumanoidRootPart" then
                obj.Transparency = 1
            else
                obj.Transparency = alpha
            end
        end
    end
end

RunService.Heartbeat:Connect(function()
    local now = tick()
    for _, player in ipairs(Players:GetPlayers()) do
        local uid = player.UserId
        local cls = player:GetAttribute("ClassName")
        local canInvis = cls == "Shinobi" and (player:GetAttribute("CanDealDamage") ~= false)

        local char = player.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")

        local entry = stateMap[uid]
        if not entry then
            entry = {lastMove = now, currentAlpha = 0}
            stateMap[uid] = entry
        end

        if not canInvis or not hrp then
            -- Reset transparency if any
            if entry.currentAlpha > 0 and char then
                setCharacterTransparency(char, 0)
            end
            entry.currentAlpha = 0
            entry.lastMove = now
            continue
        end

        -- Calculate speed and idle time
        local speed = hrp.AssemblyLinearVelocity.Magnitude
        if speed > STAND_STILL_THRESHOLD then
            -- Moving: reset idle timer and transparency
            if entry.currentAlpha > 0 then
                setCharacterTransparency(char, 0)
                entry.currentAlpha = 0
            end
            entry.lastMove = now
        else
            -- Standing still
            local idle = now - entry.lastMove
            if idle >= IDLE_TIME_FOR_FADE then
                local progress = math.clamp((idle - IDLE_TIME_FOR_FADE) / FADE_DURATION, 0, 1)
                local alpha = progress * TARGET_TRANSPARENCY
                if math.abs(alpha - entry.currentAlpha) > 0.05 then
                    setCharacterTransparency(char, alpha)
                    entry.currentAlpha = alpha
                end
            end
        end
    end
end) 