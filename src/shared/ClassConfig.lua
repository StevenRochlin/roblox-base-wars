return {
    Archer = {
        DisplayName = "Archer",
        -- Base tier (0) definition
        Tiers = {
            [0] = {
                Cost = 0,               -- free for now
                MaxHealth = 100,
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
                MaxHealth = 100,
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
                MaxHealth = 100,
                Loadout = {
                    Tools = {"Flintlock", "Saber"},
                    Ability = "Roll"
                },
            },
        },
    },
} 