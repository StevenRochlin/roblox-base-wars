local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

if RunService:IsServer() then return {} end

local localPlayer = Players.LocalPlayer
while not localPlayer do
	Players.PlayerAdded:Wait()
	localPlayer = Players.LocalPlayer
end

local adorneeToBillboardGui = {}
local comboState = {} -- adornee -> {comboDamage, lastHitTime, damageLabel}
local damageQueue = {} -- A queue to hold damage requests from a single frame

local DamageBillboardHandler = {}

-- CONFIGURATION
-- Time windows (seconds)
local MERGE_WINDOW  = 0.5  -- hits within this window are combined
local FADE_DELAY    = 0.5   -- after this time the label begins fading

-- (fade animation length still uses FADE_DELAY)

function DamageBillboardHandler:CreateBillboardForAdornee(adornee)
	local billboard = adorneeToBillboardGui[adornee]
	if billboard then
		return billboard
	end

	billboard = Instance.new("BillboardGui")
	billboard.Name = "DamageBillboardGui"
	billboard.Adornee = adornee
	billboard.AlwaysOnTop = true
	billboard.ExtentsOffsetWorldSpace = Vector3.new(0,18,0)
	billboard.Size = UDim2.new(0.42,20,15,0)
	billboard.ResetOnSpawn = false
	billboard.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	billboard.Parent = localPlayer.PlayerGui
	adorneeToBillboardGui[adornee] = billboard

	local ancestorCon
	ancestorCon = adornee.AncestryChanged:Connect(function(child, parent)
		if parent == nil then
			ancestorCon:Disconnect()
			ancestorCon = nil

			local adorneeBillboard = adorneeToBillboardGui[adornee]
			if adorneeBillboard then
				adorneeBillboard:Destroy()
			end
			adorneeToBillboardGui[adornee] = nil
			comboState[adornee] = nil
		end
	end)

	return billboard
end

function DamageBillboardHandler:CreateDamageNumber(adornee, damage, color)
	local billboard = self:CreateBillboardForAdornee(adornee)
	local randomXPos = math.random(-10,10)/30

	local damageNumber = Instance.new("TextLabel")
	damageNumber.AnchorPoint = Vector2.new(0.5, 1)
	damageNumber.BackgroundTransparency = 1
	damageNumber.BorderSizePixel = 0
	damageNumber.Position = UDim2.fromScale(0.5 + randomXPos,1)
	damageNumber.Size = UDim2.fromScale(0,0.25)
	damageNumber.Font = Enum.Font.GothamBlack
	damageNumber.Text = tostring(damage)
	damageNumber.TextScaled = true
	damageNumber.TextStrokeTransparency = 0
	damageNumber.TextTransparency = 0
	damageNumber.TextXAlignment = Enum.TextXAlignment.Center
	damageNumber.TextYAlignment = Enum.TextYAlignment.Bottom
	damageNumber.Parent = billboard

	return damageNumber
end

function DamageBillboardHandler:ShowDamageBillboard(damageAmount, adornee, textColor)
	table.insert(damageQueue, {
		damage = math.ceil(damageAmount),
		adornee = adornee,
		color = textColor
	})
end

function DamageBillboardHandler:AnimateHit(damageNumber, textColor, isCombo)
	local initialColor, targetColor
	if textColor then
		initialColor = Color3.new(textColor.R * 0.7, textColor.G * 0.7, textColor.B * 0.7)
		targetColor = textColor
	else
		initialColor = Color3.new(0.7, 0.7, 0.7)
		targetColor = Color3.new(1, 1, 1)
	end

	damageNumber.TextColor3 = initialColor
	damageNumber.TextTransparency = 0
	damageNumber.TextStrokeTransparency = 0
	damageNumber.Rotation = 0
	damageNumber.Size = UDim2.fromScale(0.8, 0.25)

	local appearTime = isCombo and 0.15 or 0.4
	local appearStyle = isCombo and Enum.EasingStyle.Quad or Enum.EasingStyle.Elastic

	local appearTweenInfo = TweenInfo.new(appearTime, appearStyle, Enum.EasingDirection.Out)
	local appearTween = TweenService:Create(damageNumber, appearTweenInfo, {
		Size = UDim2.fromScale(1.2, 0.25),
		TextColor3 = targetColor,
		Rotation = math.random(-8, 8)
	})
	appearTween:Play()
end

function DamageBillboardHandler:AnimateFadeOut(damageNumber)
	local fadeOutTweenInfo = TweenInfo.new(FADE_DELAY, Enum.EasingStyle.Linear)
	local fadeOutTween = TweenService:Create(damageNumber, fadeOutTweenInfo, {
		Size = UDim2.fromScale(0.6, 0.125),
		TextTransparency = 1,
		TextStrokeTransparency = 1
	})
	
	fadeOutTween.Completed:Connect(function()
		if damageNumber and damageNumber.Parent then
			damageNumber:Destroy()
		end
	end)

	fadeOutTween:Play()
end


-- Main processing loop on Heartbeat
RunService.Heartbeat:Connect(function()
	-- 1. Process all damage requests from the current frame
	local combinedDamage = {}
	if #damageQueue > 0 then
		for _, req in ipairs(damageQueue) do
			if not combinedDamage[req.adornee] then
				combinedDamage[req.adornee] = {totalDamage = 0, color = req.color}
			end
			local data = combinedDamage[req.adornee]
			data.totalDamage = data.totalDamage + req.damage
			if req.color then data.color = req.color end
		end
		damageQueue = {}
	end

	-- 2. Update combos with the newly processed damage
	for adornee, data in pairs(combinedDamage) do
		local state = comboState[adornee]
		
		if state then
			local elapsed = tick() - state.lastHitTime
			if elapsed <= MERGE_WINDOW and not state.isFadingOut then
				-- Merge into existing combo: destroy old label, show new combined number
				if state.damageLabel then
					state.damageLabel:Destroy()
				end
				state.comboDamage = state.comboDamage + data.totalDamage
				state.lastHitTime = tick()

				local newDamageNumber = DamageBillboardHandler:CreateDamageNumber(adornee, state.comboDamage, data.color)
				state.damageLabel = newDamageNumber
				DamageBillboardHandler:AnimateHit(newDamageNumber, data.color, true)
			else
				-- Old combo expired for merging but not yet faded: let it fade, start new combo
				if not state.isFadingOut then
					state.isFadingOut = true
					DamageBillboardHandler:AnimateFadeOut(state.damageLabel)
				end
				-- Create a brand-new combo for the new damage (do NOT merge)
				local damageNumber = DamageBillboardHandler:CreateDamageNumber(adornee, data.totalDamage, data.color)
				comboState[adornee] = {
					comboDamage = data.totalDamage,
					lastHitTime = tick(),
					damageLabel = damageNumber,
					isFadingOut = false,
				}
				DamageBillboardHandler:AnimateHit(damageNumber, data.color, false)
				-- processing for this adornee done
			end
		else -- Start a new combo (no previous state)
			local damageNumber = DamageBillboardHandler:CreateDamageNumber(adornee, data.totalDamage, data.color)
			comboState[adornee] = {
				comboDamage = data.totalDamage,
				lastHitTime = tick(),
				damageLabel = damageNumber,
				isFadingOut = false,
			}
			DamageBillboardHandler:AnimateHit(damageNumber, data.color, false)
		end
	end

	-- 3. Check for expired combos and start their fade-out
	for adornee, state in pairs(comboState) do
		if state and state.damageLabel and (tick() - state.lastHitTime >= FADE_DELAY) then
			comboState[adornee] = nil
			DamageBillboardHandler:AnimateFadeOut(state.damageLabel)
		end
	end
end)

return DamageBillboardHandler