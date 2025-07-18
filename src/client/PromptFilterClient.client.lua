-- PromptFilterClient (StarterPlayerScripts)
local Players    = game:GetService("Players")
-- PromptFilterClient initialised

local RunService = game:GetService("RunService")
local localPlayer= Players.LocalPlayer


local function updateStealPromptText(prompt)
	if prompt.Name == "StealPrompt" then
		local ownerId = prompt:GetAttribute("OwnerUserId")
		-- Update for any prompt not owned by the local player (or when owner is unknown yet)
		if ownerId == nil or ownerId ~= localPlayer.UserId then
			-- read your personal steal amount (default to 10)
			local amt = localPlayer:GetAttribute("StealAmount") or 10
			-- Apply Pirate class passive bonus ( +50% steal amount ) to the displayed value
			if localPlayer:GetAttribute("ClassName") == "Pirate" then
				amt = math.floor(amt * 1.5)
			end
			prompt.ActionText = "Steal Gold (" .. amt .. ")"
		end
	end
end

local function updatePromptVisibility(prompt)
	if not prompt:IsA("ProximityPrompt") then return end
	local ownerId
	if typeof(prompt.GetAttribute) == "function" then
		ownerId = prompt:GetAttribute("OwnerUserId")
	end

	if prompt.Name == "ShopPrompt" then
		-- only owner ever sees it
		prompt.Enabled = (ownerId == localPlayer.UserId)
	elseif prompt.Name == "StealPrompt" then
		-- only non-owners ever see it
		prompt.Enabled = (ownerId and ownerId ~= localPlayer.UserId)
	else
		-- other prompts (e.g. default ones) stay as they are
		prompt.Enabled = true
	end
	updateStealPromptText(prompt)
end

-- initial scan
for _, desc in ipairs(workspace:GetDescendants()) do
	updatePromptVisibility(desc)
end

-- catch any new prompts
workspace.DescendantAdded:Connect(function(desc)
	if desc:IsA("ProximityPrompt") then
		-- wait a tick so Attributes are set
		RunService.Heartbeat:Wait()
		updatePromptVisibility(desc)
	end
end)

-- Update StealPrompt text when the player's StealAmount attribute changes
local function onStealAmountChanged()
	for _, desc in ipairs(workspace:GetDescendants()) do
		updateStealPromptText(desc)
	end
end
localPlayer:GetAttributeChangedSignal("StealAmount"):Connect(onStealAmountChanged)

-- Also refresh when the player's class changes so Pirate bonus is reflected immediately
localPlayer:GetAttributeChangedSignal("ClassName"):Connect(onStealAmountChanged)

-- Fallback: make sure ActionText is updated right when the prompt UI appears
local ProximityPromptService = game:GetService("ProximityPromptService")

ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
	if prompt.Name == "StealPrompt" then
		-- Update the text immediately before it's rendered
		local amt = localPlayer:GetAttribute("StealAmount") or 10
		if localPlayer:GetAttribute("ClassName") == "Pirate" then
			amt = math.floor(amt * 1.5)
		end
		prompt.ActionText = "Steal Gold (" .. amt .. ")"
	end
end)
