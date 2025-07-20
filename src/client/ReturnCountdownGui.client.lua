--!nocheck
-- ReturnCountdownGui.client.lua
-- Displays countdown until players are teleported back to lobby.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Place ID for match place
local MATCH_PLACE_ID = 118_743_202_306_745

local ENABLE_GUI = false

if not ENABLE_GUI then
	return
end

if game.PlaceId ~= MATCH_PLACE_ID then
	return -- Only active in match place
end

local COUNTDOWN_EVENT_NAME = "MatchReturnCountdown"
local countdownEvent: RemoteEvent = ReplicatedStorage:WaitForChild(COUNTDOWN_EVENT_NAME)

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "ReturnCountdownGui"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.Parent = playerGui

local label = Instance.new("TextLabel")
label.Name = "CountdownLabel"
label.Size = UDim2.new(0, 250, 0, 60)
label.Position = UDim2.new(0.5, -125, 0, 30)
label.BackgroundTransparency = 0.25
label.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
label.BorderSizePixel = 0
label.TextColor3 = Color3.new(1, 1, 1)
label.Font = Enum.Font.SourceSansBold
label.TextScaled = true
label.Text = "10"
label.Parent = gui

local function updateText(remaining)
	if remaining <= 0 then
		label.Text = "Teleporting..."
	else
		label.Text = string.format("Returning in %d", remaining)
	end
end

countdownEvent.OnClientEvent:Connect(updateText) 