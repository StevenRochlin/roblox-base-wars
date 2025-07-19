local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- /////////////////////////////////////////////////////////////////
-- Remote & shared data
-- /////////////////////////////////////////////////////////////////
local remotesFolder = ReplicatedStorage:WaitForChild("ClassRemotes", 10)
local FireAbility    = remotesFolder and remotesFolder:FindFirstChild("FireAbility")

local ClassConfig     = require(ReplicatedStorage:WaitForChild("ClassConfig"))
local AbilityRegistry = require(ReplicatedStorage:WaitForChild("AbilityRegistry"))

-- /////////////////////////////////////////////////////////////////
-- UI setup
-- /////////////////////////////////////////////////////////////////
local gui = Instance.new("ScreenGui")
gui.Name = "AbilityCooldownGui"
-- Preserve after respawn so we don't recreate frames every time
gui.ResetOnSpawn = false
-- Parent AFTER properties set to avoid flicker
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Name = "Container"
frame.AnchorPoint = Vector2.new(0.5, 1)
frame.Position = UDim2.new(0.5, 0, 1, -80)
frame.Size = UDim2.new(0, 220, 0, 36)
frame.BackgroundTransparency = 0.25
frame.BackgroundColor3 = Color3.new(0, 0, 0)
frame.BorderSizePixel = 0
frame.Parent = gui

local label = Instance.new("TextLabel")
label.Name = "AbilityLabel"
label.Size = UDim2.new(1, 0, 1, 0)
label.BackgroundTransparency = 1
label.Font = Enum.Font.GothamBold
label.TextScaled = true
label.TextColor3 = Color3.new(1, 1, 1)
label.TextStrokeTransparency = 0
label.TextStrokeColor3 = Color3.new(0, 0, 0)
label.Parent = frame

-- /////////////////////////////////////////////////////////////////
-- State helpers
-- /////////////////////////////////////////////////////////////////
local currentAbilityName = nil
local abilityCooldown    = 0 -- seconds
local lastUseTime        = -math.huge -- time when ability was last used

-- Determine which ability the player currently has equipped via class attributes
local function resolveCurrentAbility()
    local className = player:GetAttribute("ClassName") or "Archer"
    local tier      = player:GetAttribute("ClassTier") or 0

    -- Guard against missing config
    local classCfg = ClassConfig[className]
    if not classCfg then
        return
    end
    local tierCfg = classCfg.Tiers[tier]
    if not tierCfg then
        return
    end

    -- Ability name can be stored either as Loadout.Ability or default to "Roll"
    local abilityName = (tierCfg.Loadout and tierCfg.Loadout.Ability) or "Roll"

    -- Update cached data if ability changed
    if abilityName ~= currentAbilityName then
        currentAbilityName = abilityName
        local abilityModule = AbilityRegistry[abilityName]
        abilityCooldown = (abilityModule and abilityModule.Cooldown) or 0
    end
end

-- Update state every heartbeat (aligned with physics for consistent timing)
RunService.Heartbeat:Connect(function()
    resolveCurrentAbility()

    if not currentAbilityName then
        label.Text = "No Ability"
        label.TextColor3 = Color3.new(1, 1, 1)
        return
    end

    -- Compute remaining time
    local now       = tick()
    local remaining = math.clamp(abilityCooldown - (now - lastUseTime), 0, abilityCooldown)

    if remaining <= 0.05 then
        -- Ready
        label.Text = currentAbilityName .. " : READY"
        label.TextColor3 = Color3.fromRGB(0, 255, 0)
    else
        label.Text = string.format("%s : %.1fs", currentAbilityName, remaining)
        label.TextColor3 = Color3.fromRGB(255, 80, 80)
    end
end)

-- Detect ability usage (Shift keys) to start cooldown timer.
-- We purposely mimic the logic inside AbilityController so timings stay consistent
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then
        -- Let Shift ability activate even when processed (sprint etc.)
        -- So we intentionally IGNORE gameProcessed here
    end

    if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
        -- Only record usage if the ability is currently ready (prevents resetting timer when spamming)
        if (tick() - lastUseTime) >= abilityCooldown - 0.05 then
            lastUseTime = tick()
        end
    end
end)

-- Optional: Reset lastUseTime after character spawns (helps prevent persisting cooldown through deaths)
player.CharacterAdded:Connect(function()
    lastUseTime = -math.huge
end) 