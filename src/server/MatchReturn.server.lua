--!nocheck
-- MatchReturn.server.lua
-- Teleports all players back to the lobby 5 seconds after they arrive in the match place.

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")

-- Place IDs (keep in sync with matchmaking constants)
local LOBBY_PLACE_ID = 119_674_697_265_678 -- lobby place id (hard-coded)
local MATCH_PLACE_ID = 118_743_202_306_745 -- match place id (hard-coded)

-- Only run in the match place
if game.PlaceId ~= MATCH_PLACE_ID then
	return
end

print("[MatchReturn] Match server started; players will return to lobby in 5 seconds.")

local DELAY_SECONDS = 5

task.delay(DELAY_SECONDS, function()
	local players = Players:GetPlayers()
	if #players == 0 then
		return
	end

	print(string.format("[MatchReturn] Teleporting %d players back to lobby...", #players))

	if RunService:IsStudio() then
		print("[MatchReturn] (Studio) Skipping teleport.")
		return
	end

	local ok, err = pcall(function()
		TeleportService:TeleportAsync(LOBBY_PLACE_ID, players)
	end)

	if not ok then
		warn("[MatchReturn] Teleport failed:", err)
	end
end) 