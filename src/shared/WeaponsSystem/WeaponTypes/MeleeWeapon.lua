local RunService = game:GetService("RunService")

local WeaponsSystemFolder = script.Parent.Parent
local Libraries = WeaponsSystemFolder:WaitForChild("Libraries")
local BaseWeapon = require(Libraries:WaitForChild("BaseWeapon"))

local IsServer = RunService:IsServer()

local MeleeWeapon = {}
MeleeWeapon.__index = MeleeWeapon
setmetatable(MeleeWeapon, BaseWeapon)

-- Melee weapons don't aim down sights or reload, but we still want the camera & crosshair.
MeleeWeapon.CanAimDownSights = false
MeleeWeapon.CanBeReloaded = false
MeleeWeapon.CanBeFired = false -- Firing handled by default Tool scripts or animations
MeleeWeapon.CanHit = true

local Players = game:GetService("Players")

-- Utility to get humanoid from part.
local function getHumanoidFromPart(part)
    while part and part ~= workspace do
        if part:IsA("Model") and part:FindFirstChildOfClass("Humanoid") then
            return part:FindFirstChildOfClass("Humanoid")
        end
        part = part.Parent
    end
end

-- Default damage dealt per melee swing if no configuration provided
local DEFAULT_MELEE_DAMAGE = 25

-- Duration (seconds) the touch connection remains active after a swing begins
local DEFAULT_SWING_DURATION = 0.3

function MeleeWeapon.new(weaponsSystem, instance)
    local self = BaseWeapon.new(weaponsSystem, instance)
    setmetatable(self, MeleeWeapon)

    -- No special config needed, but ensure a basic CrosshairScale value exists for consistency
    self.configValues["CrosshairScale"] = 1

    -- For melee weapons we do not want the root-joint stabilisation used by guns
    self.configValues["DisableRootJointFix"] = true

    -- Finish standard weapon setup
    self:doInitialSetup()

    -- Melee-specific runtime state
    self.comboList = {"SideSwipe", "LeftSlash"}
    self.comboWindow = 1 -- seconds between swings to chain combo

    self.canSlash = false
    self.canDmg = false
    self.comboIndex = 1
    self.lastSlash = 0
    self.hitEnemies = {}

    -- Server-side touch listener to apply damage
    if IsServer then
        local handle = instance:FindFirstChild("Handle")
        if handle then
            handle.Touched:Connect(function(part)
                self:_onHandleTouched(part)
            end)
        end
    end

    return self
end

-- Override equip / unequip events to mirror original script behaviour
function MeleeWeapon:onEquippedChanged()
    BaseWeapon.onEquippedChanged(self)

    local handle = self.instance:FindFirstChild("Handle")

    if self.equipped then
        self.canSlash = true
        self.canDmg = false
        self.comboIndex = 1
        self.lastSlash = 0
        self.hitEnemies = {}

        if handle and handle:FindFirstChild("Equip") then
            handle.Equip:Play()
        end

        -- Disable shoulder camera zoom while melee weapon is equipped
        if self.weaponsSystem and self.weaponsSystem.camera then
            self._prevCanZoom = self.weaponsSystem.camera.canZoom
            self.weaponsSystem.camera.canZoom = false
            self.weaponsSystem.camera:updateZoomState()
        end

        -- Bind right-click for deflect ability on local client
        if self.player == Players.LocalPlayer then
            local UserInputService = game:GetService("UserInputService")
            self._deflectInputConn = UserInputService.InputBegan:Connect(function(input, processed)
                if input.UserInputType == Enum.UserInputType.MouseButton2 then
                    -- Fire ability to server
                    local RS = game:GetService("ReplicatedStorage")
                    local remotes = RS:WaitForChild("ClassRemotes",10)
                    local fireAbility = remotes and remotes:FindFirstChild("FireAbility")
                    if fireAbility then
                        fireAbility:FireServer("Deflect")
                    end
                end
            end)
        end
    else
        self.canSlash = false
        self.canDmg = false

        if handle and handle:FindFirstChild("UnEquip") then
            handle.UnEquip:Play()
        end

        -- Restore camera zoom ability when weapon unequipped
        if self.weaponsSystem and self.weaponsSystem.camera then
            self.weaponsSystem.camera.canZoom = (self._prevCanZoom ~= nil) and self._prevCanZoom or true
            self.weaponsSystem.camera:updateZoomState()
            self._prevCanZoom = nil
        end

        -- Disconnect right-click binding if exists
        if self._deflectInputConn then
            self._deflectInputConn:Disconnect()
            self._deflectInputConn = nil
        end
    end
end

-- Runs when the player clicks / taps to attack
function MeleeWeapon:onActivatedChanged()
    BaseWeapon.onActivatedChanged(self)
    -- Notify server to cancel Shinobi invis if they attack with melee
    if not IsServer and self.player == Players.LocalPlayer and self.activated and self.player:GetAttribute("ClassName") == "Shinobi" then
        local remote = self.weaponsSystem.getRemoteEvent("WeaponActivated")
        if remote then
            remote:FireServer(self.instance, true)
        end
    end

    if not self.activated or not self.canSlash then
        return
    end

    -- Launch the swing sequence in a coroutine so we don't block
    coroutine.wrap(function()
        self:executeSwing()
    end)()
end

function MeleeWeapon:executeSwing()
    local now = tick()

    -- Determine combo step
    if now - self.lastSlash <= self.comboWindow then
        self.comboIndex = (self.comboIndex % #self.comboList) + 1
    else
        self.comboIndex = 1
    end
    self.lastSlash = now
    self.canSlash = false

    -- Play selected animation (client side only)
    if not IsServer then
        local animFolder = self.instance:FindFirstChild("Animations")
        if animFolder then
            local animObj = animFolder:FindFirstChild(self.comboList[self.comboIndex])
            if animObj and self.player and self.player.Character then
                local hum = self.player.Character:FindFirstChildOfClass("Humanoid")
                if hum then
                    local track = hum:LoadAnimation(animObj)
                    track.Priority = Enum.AnimationPriority.Action
                    track:Play()
                end
            end
        end
    end

    -- Wind-up before damage window opens
    task.wait(0.15)

    -- First damage window
    self.hitEnemies = {}
    self.canDmg = true

    local handle = self.instance:FindFirstChild("Handle")
    if handle then
        if handle:FindFirstChild("Swing") then handle.Swing:Play() end
        if handle:FindFirstChild("SlashTrail") then handle.SlashTrail.Enabled = true end
    end

    if self.comboIndex == 2 then
        -- Combo swing has two hit windows
        task.wait(0.36)
        self.canDmg = false

        task.wait(0.18)

        self.hitEnemies = {}
        self.canDmg = true
        task.wait(0.36)
    else
        -- Single hit swing
        task.wait(0.25)
    end

    -- End of damage windows
    self.canDmg = false
    if handle and handle:FindFirstChild("SlashTrail") then
        handle.SlashTrail.Enabled = false
    end

    task.wait(0.06)
    self.canSlash = true
end

-- Server-side touch damage + client hit feedback
function MeleeWeapon:_onHandleTouched(part)
    if not IsServer then
        return
    end

    if not self.canDmg then
        return
    end

    local humanoid = getHumanoidFromPart(part)
    if not humanoid then
        return
    end

    -- Ignore self and duplicate hits in the same window
    if humanoid == (self.player and self.player.Character and self.player.Character:FindFirstChildOfClass("Humanoid")) then
        return
    end
    if self.hitEnemies[humanoid] then
        return
    end
    self.hitEnemies[humanoid] = true

    -- Calculate damage
    local dmgValObj = self.instance:FindFirstChild("Dmg")
    local damageAmount = dmgValObj and dmgValObj.Value or self:getConfigValue("HitDamage", DEFAULT_MELEE_DAMAGE)

    -- Tag humanoid for kill credit
    local existingTag = humanoid:FindFirstChild("creator")
    if not existingTag then
        local tag = Instance.new("ObjectValue")
        tag.Name = "creator"
        tag.Value = self.player
        tag.Parent = humanoid
        game.Debris:AddItem(tag, 2)
    elseif existingTag.Value ~= self.player then
        existingTag.Value = self.player
    end

    humanoid:TakeDamage(damageAmount)

    -- Play hit / stop swing sounds on server so other clients hear
    local handle = self.instance:FindFirstChild("Handle")
    if handle then
        if handle:FindFirstChild("Swing") then handle.Swing:Stop() end
        if handle:FindFirstChild("Hit") then handle.Hit:Play() end
    end

    -- Send event back to attacker so their client shows hit markers & numbers
    if self.player then
        local remote = self.weaponsSystem.getRemoteEvent("WeaponHit")
        if remote then
            remote:FireClient(self.player, self.instance, { h = humanoid, dmg = damageAmount })
        end
    end
end

-- Client-side response when server confirms a hit
function MeleeWeapon:onRemoteHitClient(hitInfo)
    if self.player ~= Players.LocalPlayer then
        return
    end

    local humanoid = hitInfo and hitInfo.h
    if not humanoid or not self.weaponsSystem or not self.weaponsSystem.gui then
        return
    end

    local damage = hitInfo.dmg or DEFAULT_MELEE_DAMAGE
    self.weaponsSystem.gui:OnHitOtherPlayer(damage, humanoid, 1)
end

-- Melee weapons never reload; override to no-op so BaseWeapon doesn’t start a reload coroutine
function MeleeWeapon:reload()
    -- Do nothing
end

-- Report non-zero ammo so BaseWeapon’s equip check doesn’t attempt a reload,
-- and return nil to WeaponsGui so ammo label stays hidden.
function MeleeWeapon:getAmmoInWeapon()
    return 1 -- melee weapons conceptually have infinite ammo; prevents reload logic and keeps GUI harmless
end

return MeleeWeapon 