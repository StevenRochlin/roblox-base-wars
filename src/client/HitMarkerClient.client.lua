-- HitMarkerClient.client.lua
-- Plays local hitmarker sound when DashHitMarker remote fires.

local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

local SOUND_ID = "rbxassetid://9116483270" -- bodyshot hitmarker
local player   = Players.LocalPlayer

local event = ReplicatedStorage:WaitForChild("DashHitMarker")

-- Cached sound instance per-character for lower latency
local function getOrCreateSound()
    local char = player.Character or player.CharacterAdded:Wait()
    local hrp  = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local existing = hrp:FindFirstChild("DashHitSound")
    if existing and existing:IsA("Sound") then
        return existing
    end

    local s = Instance.new("Sound")
    s.Name = "DashHitSound"
    s.SoundId = SOUND_ID
    s.Volume = 1
    s.RollOffMaxDistance = 80
    s.Parent = hrp
    return s
end

event.OnClientEvent:Connect(function()
    local sound = getOrCreateSound()
    if sound then
        -- Restart from beginning for consecutive hits
        sound.TimePosition = 0
        sound:Play()
    end
end) 