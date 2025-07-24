local PesticideCloud = {}

-- Passive ability; server-side logic handled by PesticideCloud.server script
function PesticideCloud.ServerActivate(player)
    -- No direct activation required for passive pesticide cloud
    return false
end

return PesticideCloud 