--!nocheck
-- DisableHealthGui.client.lua
-- Disables Roblox default health bar as we use a custom one.

local StarterGui = game:GetService("StarterGui")
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false) 