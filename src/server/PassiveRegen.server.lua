--!nocheck
-- PassiveRegen.server.lua
-- Custom out-of-combat regeneration: begins 5 s after last damage, heals 10 HP + 5% max per second.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local OUT_OF_COMBAT_DELAY = 5
local BASE_HEAL_PER_SEC = 10
local PERCENT_HEAL_PER_SEC = 0.05 -- 5% of MaxHealth per second

-- Tracks last time a player took damage
local lastDamageTime: {[Player]: number} = {}

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid")

	-- Initialize timer
	lastDamageTime[player] = tick()
	local lastHealth = humanoid.Health

	-- Track damage events
	humanoid.HealthChanged:Connect(function(newHealth)
		if newHealth < lastHealth then
			lastDamageTime[player] = tick()
		end
		lastHealth = newHealth
	end)

	-- Clear entry on death
	humanoid.Died:Connect(function()
		lastDamageTime[player] = tick()
	end)
end

-- Handle new players
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		onCharacterAdded(player, char)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end)

-- Heartbeat loop for healing
RunService.Heartbeat:Connect(function(dt)
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local humanoid = char and char:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			-- Only when outside base (CanDealDamage attribute true or nil)
			if player:GetAttribute("CanDealDamage") ~= false then
				local last = lastDamageTime[player] or 0
				if tick() - last >= OUT_OF_COMBAT_DELAY then
					local healPerSec = BASE_HEAL_PER_SEC + humanoid.MaxHealth * PERCENT_HEAL_PER_SEC
					humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + healPerSec * dt)
				end
			end
		end
	end
end) 