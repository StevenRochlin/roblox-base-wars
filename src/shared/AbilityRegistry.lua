local abilitiesFolder = script:FindFirstChild("abilities") or script.Parent:FindFirstChild("abilities")
local Registry = {}

if abilitiesFolder then
    for _, moduleScript in ipairs(abilitiesFolder:GetChildren()) do
        if moduleScript:IsA("ModuleScript") then
            Registry[moduleScript.Name] = require(moduleScript)
        end
    end
end

return Registry 