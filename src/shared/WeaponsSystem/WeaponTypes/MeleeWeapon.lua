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

function MeleeWeapon.new(weaponsSystem, instance)
    local self = BaseWeapon.new(weaponsSystem, instance)
    setmetatable(self, MeleeWeapon)

    -- No special config needed, but ensure a basic CrosshairScale value exists for consistency
    self.configValues["CrosshairScale"] = 1

    -- For melee weapons we do not want the root-joint stabilisation used by guns
    self.configValues["DisableRootJointFix"] = true

    -- Finish standard weapon setup
    self:doInitialSetup()

    return self
end

return MeleeWeapon 