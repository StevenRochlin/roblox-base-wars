--!nocheck
-- PesticideCloud.server.lua
-- Creates a damaging pesticide cloud around the base of each Toxic Farmer.
-- Players (other than the owner) who stand inside the cloud take 5 damage per second.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DAMAGE_PER_SEC = 5
local CLOUD_RADIUS = 12        -- studs (distance from centre of base)

-- Folder that holds player bases (created by BaseManager)
local BASES_FOLDER = Workspace:WaitForChild("PlayerBases")

-- Track pesticide cloud instances by owner userId
local clouds: {[number]: Instance} = {}

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------
-- Template to clone (placed by developer in ReplicatedStorage)
local cloudTemplate: Instance? = ReplicatedStorage:FindFirstChild("ToxicCloud")

if not cloudTemplate then
    warn("[PesticideCloud] Missing template 'ToxicCloud' in ReplicatedStorage.")
end

-- Create (or refresh) a pesticide cloud part for the given player
local function ensureCloud(player: Player)
    local uid = player.UserId
    if clouds[uid] and clouds[uid].Parent then
        return clouds[uid]
    end

    local basePart = BASES_FOLDER:FindFirstChild(player.Name .. "_Base")
    if not basePart then
        return nil -- base not created yet
    end

    if not cloudTemplate then
        return nil
    end

    local instance = cloudTemplate:Clone()
    instance.Name = "PesticideCloud"
    instance.Parent = BASES_FOLDER

    -- Position at base
    if instance:IsA("Model") and instance.PrimaryPart then
        instance:PivotTo(CFrame.new(basePart.Position))
    elseif instance:IsA("BasePart") then
        instance.Position = basePart.Position
        instance.Anchored = true
        instance.CanCollide = false
    end

    clouds[uid] = instance
    return instance
end

local function removeCloudFor(player: Player)
    local uid = player.UserId
    local inst = clouds[uid]
    if inst then
        inst:Destroy()
        clouds[uid] = nil
    end
end

-- Cleanup when player leaves
Players.PlayerRemoving:Connect(removeCloudFor)

---------------------------------------------------------------------
-- Main loop: create clouds & apply damage
---------------------------------------------------------------------
RunService.Heartbeat:Connect(function(dt)
    -- Manage cloud existence / positioning
    for _, player in ipairs(Players:GetPlayers()) do
        local isToxic = player:GetAttribute("ClassName") == "ToxicFarmer"

        if isToxic then
            local cloud = ensureCloud(player)
            if cloud then
                -- update position each frame in case base moves
                local basePart = BASES_FOLDER:FindFirstChild(player.Name .. "_Base")
                if basePart then
                    cloud.Position = basePart.Position
                end
            end
        else
            -- remove cloud if player changed class away from ToxicFarmer
            removeCloudFor(player)
        end
    end

    -- Apply damage to any players inside clouds
    for ownerId, cloud in pairs(clouds) do
        if cloud and cloud.Parent then
            local centre: Vector3

            if cloud:IsA("Model") and cloud.PrimaryPart then
                centre = cloud.PrimaryPart.Position
            elseif cloud:IsA("BasePart") then
                centre = cloud.Position
            else
                continue
            end

            for _, target in ipairs(Players:GetPlayers()) do
                if target.UserId ~= ownerId then
                    local char = target.Character
                    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    if humanoid and hrp and humanoid.Health > 0 then
                        if (hrp.Position - centre).Magnitude <= CLOUD_RADIUS then
                            humanoid:TakeDamage(DAMAGE_PER_SEC * dt)
                        end
                    end
                end
            end
        end
    end
end) 