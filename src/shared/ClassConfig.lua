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
                    Tool = "NinjaStar",
                    Ability = "Dash"
                },
                Passive = {"DoubleJump"},
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
                    Ability = "PowderBomb"
                },
                StealGoldMultiplier = 1.5,
            },
        },
    },
    Farmer = {
        DisplayName = "Farmer",
        Tiers = {
            [0] = {
                Cost = 0,
                MaxHealth = 200,
                HumanoidProperties = {
                    UseJumpPower = true,
                    JumpPower = 50,
                    WalkSpeed = 16,
                },
                Loadout = {
                    Tools = {"Pitchfork", ".22 Rifle"}, -- Ensure these tools exist under ReplicatedStorage.ClassItems
                    Ability = "ChickenJockey", -- summon helper
                },
            },
        },
    },

    -- //////////////////////////////////////////////////////////
    -- Subclasses (cost: 500 gold each)
    -- These inherit passives from their base class; stats are placeholders for now
    -- //////////////////////////////////////////////////////////

    -- Pirate subclasses
    Outlaw = {
        DisplayName = "Outlaw",
        BaseClass = "Pirate",
        Tiers = {
            [0] = {
                Cost = 500,
                MaxHealth = 225,
                HumanoidProperties = {
                    UseJumpPower = true,
                    JumpPower = 55,
                    WalkSpeed = 16,
                },
                Loadout = {
                    Tool = "Revolver",
                    Ability = "PowderBomb",
                },
                KillGoldMultiplier = 1.3,
            },
        },
    },

    Buccaneer = {
        DisplayName = "Buccaneer",
        BaseClass = "Pirate",
        Tiers = {
            [0] = {
                Cost = 500,
                MaxHealth = 225,
                HumanoidProperties = {
                    UseJumpPower = true,
                    JumpPower = 50,
                    WalkSpeed = 16,
                },
                Loadout = {
                    Tools = {"Flintlock", "Saber", "Blunderbuss"},
                    Ability = "PowderBomb",
                },
                StealGoldMultiplier = 1.875,
            },
        },
    },

    -- Ninja subclasses
    Samurai = {
        DisplayName = "Samurai",
        BaseClass = "Ninja",
        Tiers = {
            [0] = {
                Cost = 500,
                MaxHealth = 225,
                HumanoidProperties = {
                    UseJumpPower = true,
                    JumpPower = 60,
                    WalkSpeed = 16,
                },
                Loadout = {
                    Tools = {"Katana", "NinjaStar"},
                    Ability = "Dash",
                },
                Passive = {"DoubleJump"},
            },
        },
    },

    Shinobi = {
        DisplayName = "Shinobi",
        BaseClass = "Ninja",
        Tiers = {
            [0] = {
                Cost = 500,
                MaxHealth = 200,
                HumanoidProperties = {
                    UseJumpPower = true,
                    JumpPower = 70,
                    WalkSpeed = 18,
                },
                Loadout = {
                    Tool = "Kunai",
                    Ability = "ShinobiDash",
                },
                Passive = {"DoubleJump"},
            },
        },
    },

    -- Archer subclasses
    Musketeer = {
        DisplayName = "Musketeer",
        BaseClass = "Archer",
        Tiers = {
            [0] = {
                Cost = 500,
                MaxHealth = 225,
                HumanoidProperties = {
                    UseJumpPower = true,
                    JumpPower = 50,
                    WalkSpeed = 16,
                },
                Loadout = {
                    Tools = {"Musket", "Saber"},
                    Ability = "Roll",
                },
            },
        },
    },

    Ranger = {
        DisplayName = "Ranger",
        BaseClass = "Archer",
        Tiers = {
            [0] = {
                Cost = 500,
                MaxHealth = 225,
                HumanoidProperties = {
                    UseJumpPower = true,
                    JumpPower = 60,
                    WalkSpeed = 16,
                },
                Loadout = {
                    Tool = "Crossbow",
                    Ability = "Roll",
                },
            },
        },
    },

    -- Farmer subclasses
    NiceFarmer = {
        DisplayName = "Nice Farmer",
        BaseClass = "Farmer",
        Tiers = {
            [0] = {
                Cost = 500,
                MaxHealth = 250,
                HumanoidProperties = {
                    UseJumpPower = true,
                    JumpPower = 50,
                    WalkSpeed = 16,
                },
                Loadout = {
                    Tools = {"Pitchfork", "Pump Shotgun"},
                    Ability = "ChickenJockey",
                },
            },
        },
    },

    ToxicFarmer = {
        DisplayName = "Toxic Farmer",
        BaseClass = "Farmer",
        Tiers = {
            [0] = {
                Cost = 500,
                MaxHealth = 225,
                HumanoidProperties = {
                    UseJumpPower = true,
                    JumpPower = 55,
                    WalkSpeed = 16,
                },
                Loadout = {
                    Tool = "Sprayer",
                    Ability = "ChickenJockey",
                },
                Passive = {"PesticideCloud"},
            },
        },
    },
} 