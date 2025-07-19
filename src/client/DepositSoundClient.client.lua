local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local player = Players.LocalPlayer

local SoundAssets = require(game:GetService("ReplicatedStorage"):WaitForChild("SoundAssets"))

local leaderstats = player:WaitForChild("leaderstats")
local goldStat    = leaderstats:WaitForChild("Gold")
local baseGoldStat= leaderstats:WaitForChild("BaseGold")

-- create sound objects once
local largeDepositSound = Instance.new("Sound")
largeDepositSound.SoundId = "rbxassetid://" .. tostring(SoundAssets.LargeDeposit)
largeDepositSound.Volume = 0.7
largeDepositSound.Parent = SoundService

local smallDepositSound = Instance.new("Sound")
smallDepositSound.SoundId = "rbxassetid://" .. tostring(SoundAssets.SmallDeposit)
smallDepositSound.Volume = 0.6
smallDepositSound.Parent = SoundService

local lastGold     = goldStat.Value
local lastBaseGold = baseGoldStat.Value

local function checkDeposit()
    local g = goldStat.Value
    local b = baseGoldStat.Value

    local gDiff = g - lastGold
    local bDiff = b - lastBaseGold

    -- deposit if Gold decreased and BaseGold increased by some amount
    if gDiff < 0 and bDiff > 0 then
        local depositAmt = math.min(-gDiff, bDiff)
        if depositAmt >= 100 then
            largeDepositSound:Play()
        elseif depositAmt > 0 then
            smallDepositSound:Play()
        end
    end

    lastGold = g
    lastBaseGold = b
end

goldStat:GetPropertyChangedSignal("Value"):Connect(checkDeposit)
baseGoldStat:GetPropertyChangedSignal("Value"):Connect(checkDeposit) 