return {
    Archer = {
        DisplayName = "Archer",
        -- Base tier (0) definition
        Tiers = {
            [0] = {
                Cost = 0,               -- free for now
                MaxHealth = 200,
                HumanoidProperties = {
                    UseJumpPower = true,
                    JumpPower     = 50,
                    WalkSpeed     = 16,
                },
                -- Loadout maps slot names to asset names/ids (Tools or Abilities)
                Loadout = {
                    Tool = "Crossbow",      -- Tool name under ReplicatedStorage.ClassItems
                    Ability = "Roll"        -- Ability name handled by AbilityRegistry
                },
            },
        },
        -- Icon or other UI data can be added later
    },
    Ninja = {
        DisplayName = "Ninja",
        -- Base tier (0) definition
        Tiers = {
            [0] = {
                Cost = 0,               -- free for now
                MaxHealth = 175,
                -- Override humanoid defaults when this class is equipped
                HumanoidProperties = {
                    UseJumpPower = true, -- ensure JumpPower is respected
                    JumpPower     = 65,  
                    WalkSpeed     = 18,  
                },
                Loadout = {
                    Tool = "NinjaStar",      -- Tool name under ReplicatedStorage.ClassItems
                    Ability = "Dash"         -- Use Dash ability for now
                },
            },
        },
        -- Additional UI data can be added later
    },
    Pirate = {
        DisplayName = "Pirate",
        Tiers = {
            [0] = {
                Cost = 0,
                MaxHealth = 200,
                HumanoidProperties = {
                    UseJumpPower = true,
                    JumpPower     = 50,
                    WalkSpeed     = 16,
                },
                Loadout = {
                    Tools = {"Flintlock", "Saber"},
                    Ability = "Roll"
                },
            },
        },
    },
    Farmer = {
        DisplayName = "Farmer",
        Tiers = {
            [0] = {
                Cost = 0,
                MaxHealth = 225,
                HumanoidProperties = {
                    UseJumpPower = true,
                    JumpPower = 50,
                    WalkSpeed = 16,
                },
                Loadout = {
                    Tools = {"Pitchfork", "Rifle22"}, -- Ensure these tools exist under ReplicatedStorage.ClassItems
                    Ability = "Roll", -- reuse roll for now
                },
            },
        },
    },
} 