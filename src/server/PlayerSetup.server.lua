--PlayerSetup (ServerScriptServices)
print("PlayerSetup loaded")
print("Updated")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local DisplayBasePrompt = ReplicatedStorage:WaitForChild("DisplayBasePrompt")
local KillGoldIndicator = ReplicatedStorage:FindFirstChild("KillGoldIndicator")
if not KillGoldIndicator then
    KillGoldIndicator = Instance.new("RemoteEvent")
    KillGoldIndicator.Name = "KillGoldIndicator"
    KillGoldIndicator.Parent = ReplicatedStorage
end

local GOLD_DROP_FOLDER_NAME = "GoldDrops"
local goldDropFolder = Workspace:FindFirstChild(GOLD_DROP_FOLDER_NAME)
if not goldDropFolder then
    goldDropFolder = Instance.new("Folder")
    goldDropFolder.Name = GOLD_DROP_FOLDER_NAME
    goldDropFolder.Parent = Workspace
end

local function onPlayerAdded(player)
    print("PlayerSetup: onPlayerAdded for", player.Name)
    local leaderstats = Instance.new("Folder")
    leaderstats.Name = "leaderstats"
    leaderstats.Parent = player

    local gold = Instance.new("IntValue")
    gold.Name = "Gold"
    gold.Value = 2000 -- Initial gold amount
    gold.Parent = leaderstats

    local baseGold = Instance.new("IntValue")
    baseGold.Name = "BaseGold"
    baseGold.Value = 0 -- Initial base gold
    baseGold.Parent = leaderstats

    -- Create and give a "Rod" tool for testing
    local rod = Instance.new("Tool")
    rod.Name = "Rod"
    rod.ToolTip = "A simple test rod."

    local handle = Instance.new("Part")
    handle.Name = "Handle"
    handle.Size = Vector3.new(1, 1, 5)
    handle.BrickColor = BrickColor.new("Brown")
    handle.Parent = rod

    rod.Parent = player:WaitForChild("StarterGear")

	-- Immediately show the prompt on join
	task.defer(function()
		task.wait(0.2)
		if not player:GetAttribute("HasBase") then
			DisplayBasePrompt:FireClient(player)
		end
	end)

	-- Also show it on every respawn
	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		if not player:GetAttribute("HasBase") then
			DisplayBasePrompt:FireClient(player)
		end
	end)



    player.CharacterAdded:Connect(function(character)
        local humanoid = character:WaitForChild("Humanoid")
        humanoid.Died:Connect(function()
            local playerGold = gold.Value
            if playerGold > 0 then
                local rootPart = character:FindFirstChild("HumanoidRootPart")
                if rootPart then
                    local goldSphere = Instance.new("Part")
                    goldSphere.Name = player.Name .. "_GoldDrop"
                    goldSphere.Shape = Enum.PartType.Ball
                    -- Determine sphere color and size based on gold amount
                    local amount = playerGold
                    local tierColor, sizeStuds
                    if amount <= 25 then
                        tierColor = Color3.fromRGB(0, 255, 0) -- Green
                        sizeStuds = 2
                    elseif amount <= 100 then
                        tierColor = Color3.fromRGB(0, 255, 255) -- Turquoise
                        sizeStuds = 3
                    elseif amount <= 250 then
                        tierColor = Color3.fromRGB(0, 85, 255) -- Blue
                        sizeStuds = 4
                    elseif amount <= 750 then
                        tierColor = Color3.fromRGB(128, 0, 255) -- Purple (matches old 5-stud sphere)
                        sizeStuds = 5
                    else
                        tierColor = Color3.fromRGB(255, 0, 0) -- Red
                        sizeStuds = 6
                    end

                    goldSphere.Size = Vector3.new(sizeStuds, sizeStuds, sizeStuds)
                    goldSphere.Color = tierColor
                    goldSphere.Transparency = 0.5
                    goldSphere.Anchored = true
                    goldSphere.CanCollide = false
                    goldSphere.Position = rootPart.Position
                    goldSphere.Parent = goldDropFolder

                    local goldValue = Instance.new("IntValue")
                    goldValue.Name = "GoldAmount"
                    goldValue.Value = playerGold
                    goldValue.Parent = goldSphere

                    gold.Value = 0 -- Player loses all carried gold

                    local connection
                    connection = goldSphere.Touched:Connect(function(hit)
                        local hitModel = hit.Parent
                        if hitModel then
                            local hitPlayer = Players:GetPlayerFromCharacter(hitModel)
                            -- Allow any player, including the one who dropped it, to pick it up
                            if hitPlayer then 
                                local humanoidOfPicker = hitModel:FindFirstChildOfClass("Humanoid")
                                if humanoidOfPicker and humanoidOfPicker.Health > 0 then
                                    local pickedUpGold = goldValue.Value
                                    hitPlayer.leaderstats.Gold.Value = hitPlayer.leaderstats.Gold.Value + pickedUpGold
                                    
                                    if connection then
                                        connection:Disconnect()
                                    end
                                    goldSphere:Destroy()
                                end
                            end
                        end
                    end)
                    
                    -- Auto-destroy gold sphere after some time if not picked up
                    task.delay(180, function()
                        if goldSphere and goldSphere.Parent then
                            goldSphere:Destroy()
                        end
                    end)
                end
            end
            -- Award kill bounty to killer
            local creatorTag = humanoid:FindFirstChild("creator")
            if creatorTag and creatorTag.Value and creatorTag.Value:IsA("Player") then
                local killer = creatorTag.Value
                if killer ~= player then
                    local bountyReward = killer:GetAttribute("KillBountyReward") or 15
                    local mult = killer:GetAttribute("KillGoldMultiplier") or 1
                    local finalReward = math.floor(bountyReward * mult)
                    local killerStats = killer:FindFirstChild("leaderstats")
                    local killerGold = killerStats and killerStats:FindFirstChild("Gold")
                    if killerGold then
                        killerGold.Value = killerGold.Value + finalReward

                        -- Notify client for colored kill indicator
                        if KillGoldIndicator then
                            KillGoldIndicator:FireClient(killer, finalReward)
                        end
                    end
                end
            end
        end)
    end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
    onPlayerAdded(player)
end

