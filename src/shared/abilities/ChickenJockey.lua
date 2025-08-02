local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local ChickenJockey = {}

ChickenJockey.Cooldown  = 15 -- seconds between uses
ChickenJockey.Duration  = 25 -- lifetime of the summon
ChickenJockey.Damage    = 16 -- damage per hit
ChickenJockey.HitRadius = 5  -- studs for melee hit
ChickenJockey.Health    = 125
ChickenJockey.Speed     = 20  -- walk speed

-- /////////////////////////////////////////////////////////////////
local lastUse = {}
local function canUse(player)
    local t = tick()
    local uid = player.UserId
    if not lastUse[uid] or (t - lastUse[uid]) >= ChickenJockey.Cooldown then
        lastUse[uid] = t
        return true
    end
    return false
end

-- Utility to get nearest enemy character
local function getNearestEnemy(player, originPos, maxDist)
    local closest, distSq
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character then
            local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health > 0 then
                local d2 = (hrp.Position - originPos).Magnitude
                if d2 <= maxDist and (not distSq or d2 < distSq) then
                    closest = plr.Character
                    distSq = d2
                end
            end
        end
    end
    return closest
end

function ChickenJockey.ServerActivate(player)
    if not canUse(player) then return end

    local char = player.Character
    if not char then return end

    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    -- Locate template
    local template = ReplicatedStorage:FindFirstChild("ClassItems")
        and ReplicatedStorage.ClassItems:FindFirstChild("Chicken Jockey")
    if not template then
        warn("[ChickenJockey] Missing Chicken Jockey template under ReplicatedStorage.ClassItems")
        return
    end

    local summon = template:Clone()
    summon.Name = player.Name .. "_Jockey"
    summon.Parent = workspace

    -- Remove any Tools or attack scripts that could harm the summoner
    for _, d in ipairs(summon:GetDescendants()) do
        if d:IsA("Tool") then
            d:Destroy()
        elseif d:IsA("Script") or d:IsA("ModuleScript") then
            -- Disable scripts that might perform default damage logic
            d.Disabled = true
        end
    end

    -- Determine primary/root part first so Died handler can reference it
    local primary = summon.PrimaryPart or summon:FindFirstChild("HumanoidRootPart") or summon:FindFirstChildWhichIsA("BasePart")

    -- Assume model with Humanoid
    local humanoid = summon:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.MaxHealth = ChickenJockey.Health
        humanoid.Health = ChickenJockey.Health
        humanoid.WalkSpeed = ChickenJockey.Speed

        -- Play death sound when jockey is defeated
        humanoid.Died:Connect(function()
            local snd = Instance.new("Sound")
            snd.SoundId = "rbxassetid://6845870387"
            snd.Volume = 1
            snd.RollOffMode = Enum.RollOffMode.Inverse
            snd.RollOffMaxDistance = 80
            if primary and primary:IsA("BasePart") then
                snd.Parent = primary
            else
                snd.Parent = summon
            end
            snd:Play()
            Debris:AddItem(snd, 4)
        end)
    end

    -- Move to spawn position slightly in front of player
    if primary then
        primary.CFrame = root.CFrame * CFrame.new(2, 0, -2)
    end

    -- Simple AI coroutine
    local alive = true
    local hitCool = 0
    local lastDamageTime = 0
    local startTime = tick()
    local lastPos = primary and primary.Position or Vector3.new()
    local lastMoveCheck = tick()

    -- damage function
    local function tryDamage(targetChar)
        if not targetChar or targetChar == char then return end
        local targetHum = targetChar:FindFirstChildOfClass("Humanoid")
        local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
        if targetHum and targetRoot and targetHum.Health > 0 then
            local offset = targetRoot.Position - primary.Position
            local horizDist = Vector3.new(offset.X,0,offset.Z).Magnitude
            local vertDiff = math.abs(offset.Y)
            if horizDist <= ChickenJockey.HitRadius and vertDiff <= 6 then
                -- Tag for kill attribution
                local existing = targetHum:FindFirstChild("creator")
                if not existing then
                    local tag = Instance.new("ObjectValue")
                    tag.Name = "creator"
                    tag.Value = player
                    tag.Parent = targetHum
                    Debris:AddItem(tag, 2) -- auto-remove after short duration
                elseif existing.Value ~= player then
                    existing.Value = player
                end

                targetHum:TakeDamage(ChickenJockey.Damage)
                lastDamageTime = tick()
            end
        end
    end

    coroutine.wrap(function()
        while alive and summon.Parent do
            RunService.Heartbeat:Wait()
            if humanoid and humanoid.Health <= 0 then break end
            local now = tick()
            if now - startTime >= ChickenJockey.Duration then break end

            -- Choose target: nearest enemy within 60 studs else follow player
            local targetChar = getNearestEnemy(player, primary.Position, 60)
            local goalPos
            if targetChar then
                local trgRoot = targetChar:FindFirstChild("HumanoidRootPart")
                goalPos = trgRoot and trgRoot.Position
                -- Try melee damage cooling every 0.5s
                if now - hitCool >= 0.5 then
                    hitCool = now
                    tryDamage(targetChar)
                end
            else
                goalPos = root.Position
            end
            if goalPos and humanoid then
                humanoid:MoveTo(goalPos)
            end

            -- Stuck detection every 0.4s
            if primary and tick() - lastMoveCheck >= 0.4 then
                local distMoved = (primary.Position - lastPos).Magnitude
                if distMoved < 0.8 and (tick() - lastDamageTime) > 0.4 then
                    humanoid.Jump = true
                end
                lastPos = primary.Position
                lastMoveCheck = tick()
            end
        end
        alive = false
        if summon and summon.Parent then
            summon:Destroy()
        end
    end)()

    -- Auto cleanup
    Debris:AddItem(summon, ChickenJockey.Duration + 2)

    return true
end

return ChickenJockey 