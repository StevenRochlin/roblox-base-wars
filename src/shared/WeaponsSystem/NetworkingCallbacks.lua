local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local IsServer = RunService:IsServer()
local LocalPlayer = (not IsServer) and Players.LocalPlayer or nil

local NetworkingCallbacks = {}
NetworkingCallbacks.WeaponsSystem = nil

function NetworkingCallbacks.WeaponFired(player, instance, fireInfo)
	local WeaponsSystem = NetworkingCallbacks.WeaponsSystem
	if not WeaponsSystem then
		return
	end

	local weapon = WeaponsSystem.getWeaponForInstance(instance)
	local weaponType = getmetatable(weapon)

	if weapon and weaponType then
		if weapon.instance == instance and weaponType.CanBeFired and weapon.player == player then
			weapon:onFired(player, fireInfo, true)
		end
	end
end

function NetworkingCallbacks.WeaponReloadRequest(player, instance)
	local WeaponsSystem = NetworkingCallbacks.WeaponsSystem
	if not WeaponsSystem then
		return
	end

	local weapon = WeaponsSystem.getWeaponForInstance(instance)
	local weaponType = getmetatable(weapon)
	if weapon then
		if weapon.instance == instance and weaponType.CanBeReloaded then
			weapon:reload(player, true)
		end
	end
end

function NetworkingCallbacks.WeaponReloaded(player, instance)
	local WeaponsSystem = NetworkingCallbacks.WeaponsSystem
	if not WeaponsSystem then
		return
	end

	local weapon = WeaponsSystem.getWeaponForInstance(instance)
	local weaponType = getmetatable(weapon)
	if weapon then
		if weapon.instance == instance and weaponType.CanBeReloaded and player ~= nil and player ~= LocalPlayer then
			weapon:onReloaded(player, true)
		end
	end
end

function NetworkingCallbacks.WeaponReloadCanceled(player, instance)
	local WeaponsSystem = NetworkingCallbacks.WeaponsSystem
	if not WeaponsSystem then
		return
	end

	local weapon = WeaponsSystem.getWeaponForInstance(instance)
	local weaponType = getmetatable(weapon)
	if weapon then
		if weapon.instance == instance and weaponType.CanBeReloaded and player ~= LocalPlayer then
			weapon:cancelReload(player, true)
		end
	end
end

function NetworkingCallbacks.WeaponHit(playerOrInstance, maybeInstance, maybeHitInfo)
	local WeaponsSystem = NetworkingCallbacks.WeaponsSystem
	if not WeaponsSystem then return end

	local instance, hitInfo
	if IsServer then
		instance = maybeInstance
		hitInfo  = maybeHitInfo
	else
		-- On client the RemoteEvent does NOT include the player argument.
		instance = playerOrInstance
		hitInfo  = maybeInstance
	end

	local weapon = WeaponsSystem.getWeaponForInstance(instance)
	local weaponType = getmetatable(weapon)
	if not weapon or not weaponType or not weaponType.CanHit then return end

	if IsServer then
		weapon:onHit(hitInfo)
	else
		if weapon.onRemoteHitClient then
			weapon:onRemoteHitClient(hitInfo)
		end
	end
end

function NetworkingCallbacks.WeaponActivated(player, instance, activated)
	local WeaponsSystem = NetworkingCallbacks.WeaponsSystem
	if not WeaponsSystem then
		return
	end

	local weapon = WeaponsSystem.getWeaponForInstance(instance)
	local weaponType = getmetatable(weapon)

	if weapon and weaponType then
		if weapon.instance == instance and weapon.player == player then
			weapon:setActivated(activated, true)
		end
	end
end

return NetworkingCallbacks
