local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

-- Number of extra jumps allowed (1 means double jump)
local EXTRA_JUMPS = 1

local function characterHasDoubleJump(char)
    return char and char:GetAttribute("CanDoubleJump") == true
end

local function setUpCharacter(char)
    local humanoid = char:WaitForChild("Humanoid", 5)
    if not humanoid then return end

    if not characterHasDoubleJump(char) then
        -- watch for attribute being added later (e.g., class switch)
        local conn
        conn = char.AttributeChanged:Connect(function(attr)
            if attr == "CanDoubleJump" and characterHasDoubleJump(char) then
                conn:Disconnect()
                setUpCharacter(char) -- re-run setup with ability enabled
            end
        end)
        return
    end

    local jumpsLeft = EXTRA_JUMPS -- extra jumps available while airborne

    local function onStateChanged(_, new)
        if new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running then
            jumpsLeft = EXTRA_JUMPS
        end
    end
    humanoid.StateChanged:Connect(onStateChanged)

    UserInputService.JumpRequest:Connect(function()
        if jumpsLeft <= 0 then return end

        local state = humanoid:GetState()
        if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall then
            jumpsLeft -= 1
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end)
end

player.CharacterAdded:Connect(setUpCharacter)
if player.Character then setUpCharacter(player.Character) end 