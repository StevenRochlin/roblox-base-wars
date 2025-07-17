return {
    Archer = {
        DisplayName = "Archer",
        -- Base tier (0) definition
        Tiers = {
            [0] = {
                Cost = 0,               -- free for now
                MaxHealth = 100,
                -- Loadout maps slot names to asset names/ids (Tools or Abilities)
                -- Use simple string names for Tools that exist in ReplicatedStorage.Assets.Tools
                Loadout = {
                    Tool = "Crossbow",      -- Tool name under ReplicatedStorage.Assets.Tools
                    Ability = "Roll"        -- Ability name handled by AbilityRegistry
                },
            },
        },
        -- Icon or other UI data can be added later
    },
} 