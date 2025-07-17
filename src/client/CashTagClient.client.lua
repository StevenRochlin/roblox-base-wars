-- CashTagClient (StarterPlayerScripts)
print("GoldTagClient loaded")

local Players = game:GetService("Players")

local function createBillboard(character, player)
    local head = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
    if not head then return end

    local tagGui = Instance.new("BillboardGui")
    tagGui.Name = "CashTag"
    tagGui.Adornee = head
    tagGui.Size = UDim2.new(0, 120, 0, 40)
    tagGui.StudsOffset = Vector3.new(0, 2, 0)
    tagGui.AlwaysOnTop = true
    tagGui.Parent = character

    -- Name label colored by base color
    local basePart = workspace:FindFirstChild(player.Name .. "_Base")
    local nameColor = basePart and basePart.Color or Color3.new(1,1,1)
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0, 20)
    nameLabel.Position = UDim2.new(0, 0, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = player.Name
    nameLabel.Font = Enum.Font.SourceSansBold
    nameLabel.TextScaled = true
    nameLabel.TextColor3 = nameColor
    nameLabel.TextStrokeColor3 = Color3.new(0,0,0)
    nameLabel.TextStrokeTransparency = 0
    nameLabel.Parent = tagGui

    -- Gold amount label
    local goldLabel = Instance.new("TextLabel")
    goldLabel.Size = UDim2.new(1, 0, 0, 20)
    goldLabel.Position = UDim2.new(0, 0, 0, 20)
    goldLabel.BackgroundTransparency = 1
    goldLabel.Text = ""
    goldLabel.Font = Enum.Font.SourceSansBold
    goldLabel.TextScaled = true
    goldLabel.TextColor3 = Color3.fromRGB(255,215,0)
    goldLabel.TextStrokeColor3 = Color3.new(0,0,0)
    goldLabel.TextStrokeTransparency = 0
    goldLabel.Parent = tagGui

    local leaderstats = player:WaitForChild("leaderstats")
    local goldStat = leaderstats:WaitForChild("Gold")

    local function updateGold()
        goldLabel.Text = "Gold: " .. tostring(goldStat.Value)
    end

    updateGold()
    goldStat.Changed:Connect(updateGold)
end

local function onCharacterAdded(player, character)
    createBillboard(character, player)
end

local function onPlayerAdded(player)
    player.CharacterAdded:Connect(function(character)
        onCharacterAdded(player, character)
    end)
    if player.Character then
        onCharacterAdded(player, player.Character)
    end
end

for _, player in ipairs(Players:GetPlayers()) do
    onPlayerAdded(player)
end

Players.PlayerAdded:Connect(onPlayerAdded) 