--!nocheck
-- MatchReturn.server.lua
-- Teleports all players back to the lobby 5 seconds after they arrive in the match place.

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Place IDs (keep in sync with matchmaking constants)
local LOBBY_PLACE_ID = 119_674_697_265_678 -- lobby place id (hard-coded)
local MATCH_PLACE_ID = 118_743_202_306_745 -- match place id (hard-coded)

-- Only run in the match place
if game.PlaceId ~= MATCH_PLACE_ID then
	return
end

-- Create or find RemoteEvent for countdown
local COUNTDOWN_EVENT_NAME = "MatchReturnCountdown"
local countdownEvent: RemoteEvent = ReplicatedStorage:FindFirstChild(COUNTDOWN_EVENT_NAME) :: RemoteEvent
if not countdownEvent then
	countdownEvent = Instance.new("RemoteEvent")
	countdownEvent.Name = COUNTDOWN_EVENT_NAME
	countdownEvent.Parent = ReplicatedStorage
end

print("[MatchReturn] Match server started; players will return to lobby in 10 seconds.")

local DELAY_SECONDS = 10

-- Broadcast countdown each second
task.spawn(function()
	for remaining = DELAY_SECONDS, 0, -1 do
		countdownEvent:FireAllClients(remaining)
		task.wait(1)
	end
end)

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