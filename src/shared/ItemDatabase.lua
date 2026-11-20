--!strict
--[[
    ItemDatabase.lua
    Authoritative catalog of all items, gear, consumables, and materials.
    Matches ProgressionTypes.lua schema specifications.
]]

local ProgressionTypes = require(script.Parent:WaitForChild("ProgressionTypes"))

type ItemDefinition = ProgressionTypes.ItemDefinition

local ItemDatabase: { [string]: ItemDefinition } = {
    -- =========================================================================
    -- WEAPONS
    -- =========================================================================
    IronWarhammer = {
        id = "IronWarhammer",
        name = "Forged Iron Warhammer",
        category = "Weapon",
        slot = "Weapon",
        rarity = "Common",
        description = "A sturdy iron warhammer fashioned by sanctuary smiths. Reliable and heavy.",
        maxStack = 1,
        buyPrice = 100,
        sellPrice = 40,
        stats = {
            attack = 15,
        },
        iconColor = Color3.fromRGB(180, 180, 190),
    },

    StormGlaive = {
        id = "StormGlaive",
        name = "Tempest Storm Glaive",
        category = "Weapon",
        slot = "Weapon",
        rarity = "Rare",
        description = "A crackling polearm infused with condensed storm clouds. Pierces enemy armor with lightning.",
        maxStack = 1,
        buyPrice = 450,
        sellPrice = 180,
        stats = {
            attack = 35,
            critDamage = 0.15,
            lightningDamage = 15,
        },
        iconColor = Color3.fromRGB(70, 180, 255),
    },

    ThunderClaymore = {
        id = "ThunderClaymore",
        name = "Thunder Breaker Greatsword",
        category = "Weapon",
        slot = "Weapon",
        rarity = "Epic",
        description = "An ancient colossal blade humming with raw thunderbolt potential. Devastates tough beasts.",
        maxStack = 1,
        buyPrice = 1200,
        sellPrice = 500,
        stats = {
            attack = 55,
            critChance = 0.12,
            critDamage = 0.30,
            lightningDamage = 30,
        },
        iconColor = Color3.fromRGB(190, 85, 255),
    },

    -- =========================================================================
    -- ARMOR (CHEST, BOOTS, SHOULDERS, HEAD)
    -- =========================================================================
    StormPlate = {
        id = "StormPlate",
        name = "Stormforged Cuirass",
        category = "Armor",
        slot = "Chest",
        rarity = "Epic",
        description = "Heavy chest armor forged from electrified cobalt. Immensely bolsters vitality and armor.",
        maxStack = 1,
        buyPrice = 900,
        sellPrice = 380,
        stats = {
            health = 150,
            defense = 25,
            lightningDamage = 10,
        },
        iconColor = Color3.fromRGB(110, 140, 255),
    },

    VanguardGreaves = {
        id = "VanguardGreaves",
        name = "Vanguard Lightning Greaves",
        category = "Armor",
        slot = "Boots",
        rarity = "Rare",
        description = "Reinforced boots granting swift traversal across treacherous storm-blasted terrain.",
        maxStack = 1,
        buyPrice = 380,
        sellPrice = 150,
        stats = {
            health = 60,
            defense = 15,
            speed = 4,
        },
        iconColor = Color3.fromRGB(70, 200, 230),
    },

    IronPauldrons = {
        id = "IronPauldrons",
        name = "Tempered Iron Pauldrons",
        category = "Armor",
        slot = "Shoulders",
        rarity = "Uncommon",
        description = "Curved shoulder plates that deflect glancing blows from airborne drones.",
        maxStack = 1,
        buyPrice = 200,
        sellPrice = 75,
        stats = {
            health = 40,
            defense = 12,
        },
        iconColor = Color3.fromRGB(100, 210, 110),
    },

    StormHelmet = {
        id = "StormHelmet",
        name = "Helm of the Cloud Piercer",
        category = "Armor",
        slot = "Head",
        rarity = "Rare",
        description = "A crest helm that focuses cognitive energy, reducing ability cooldown periods.",
        maxStack = 1,
        buyPrice = 420,
        sellPrice = 170,
        stats = {
            health = 80,
            defense = 18,
            abilityCooldown = 0.08,
        },
        iconColor = Color3.fromRGB(80, 190, 255),
    },

    -- =========================================================================
    -- ARTIFACTS
    -- =========================================================================
    ThunderStone = {
        id = "ThunderStone",
        name = "Resonant Thunder Stone",
        category = "Artifact",
        slot = "Artifact",
        rarity = "Rare",
        description = "A glowing mineral relic recovered from a lightning crater. Amplifies all shock damage.",
        maxStack = 1,
        buyPrice = 500,
        sellPrice = 200,
        stats = {
            lightningDamage = 20,
            abilityCooldown = 0.05,
        },
        iconColor = Color3.fromRGB(90, 220, 255),
    },

    LightningRing = {
        id = "LightningRing",
        name = "Ring of Arcane Static",
        category = "Artifact",
        slot = "Artifact",
        rarity = "Epic",
        description = "An intricately etched gold ring that channels sparks into every critical strike.",
        maxStack = 1,
        buyPrice = 1100,
        sellPrice = 450,
        stats = {
            critChance = 0.10,
            critDamage = 0.25,
            lightningDamage = 15,
        },
        iconColor = Color3.fromRGB(220, 95, 255),
    },

    -- =========================================================================
    -- CONSUMABLES
    -- =========================================================================
    HealthPotion = {
        id = "HealthPotion",
        name = "Sanctuary Vitality Elixir",
        category = "Consumable",
        slot = nil,
        rarity = "Common",
        description = "Instantly heals 60 Health upon consumption. Essential for deep zone exploration.",
        maxStack = 20,
        buyPrice = 25,
        sellPrice = 10,
        stats = nil,
        usableEffect = "Heal:60",
        iconColor = Color3.fromRGB(255, 75, 75),
    },

    SpeedDraught = {
        id = "SpeedDraught",
        name = "Windrunner Tonic",
        category = "Consumable",
        slot = nil,
        rarity = "Uncommon",
        description = "Increases Movement Speed by +8 for 15 seconds.",
        maxStack = 10,
        buyPrice = 45,
        sellPrice = 18,
        stats = nil,
        usableEffect = "Speed:8:15",
        iconColor = Color3.fromRGB(110, 235, 120),
    },

    StormSurgeFlask = {
        id = "StormSurgeFlask",
        name = "Storm Surge Extract",
        category = "Consumable",
        slot = nil,
        rarity = "Rare",
        description = "Supercharges all lightning abilities with +25 bonus damage for 20 seconds.",
        maxStack = 5,
        buyPrice = 120,
        sellPrice = 50,
        stats = nil,
        usableEffect = "LightningBuff:25:20",
        iconColor = Color3.fromRGB(255, 220, 50),
    },

    -- =========================================================================
    -- MATERIALS
    -- =========================================================================
    IronOre = {
        id = "IronOre",
        name = "Tempest Iron Ore",
        category = "Material",
        slot = nil,
        rarity = "Common",
        description = "Dense raw metal extracted from rocky outcroppings and drone carcasses.",
        maxStack = 99,
        buyPrice = 15,
        sellPrice = 6,
        stats = nil,
        iconColor = Color3.fromRGB(160, 160, 175),
    },

    BeastHide = {
        id = "BeastHide",
        name = "Storm Beast Pelt",
        category = "Material",
        slot = nil,
        rarity = "Uncommon",
        description = "Thick weather-resistant hide harvested from ferocious storm beasts.",
        maxStack = 99,
        buyPrice = 30,
        sellPrice = 14,
        stats = nil,
        iconColor = Color3.fromRGB(175, 125, 75),
    },

    LightningCrystal = {
        id = "LightningCrystal",
        name = "Charged Lightning Crystal",
        category = "Material",
        slot = nil,
        rarity = "Rare",
        description = "A crystallized mineral vibrating with high electrical frequency.",
        maxStack = 50,
        buyPrice = 90,
        sellPrice = 40,
        stats = nil,
        iconColor = Color3.fromRGB(90, 220, 255),
    },

    StormCore = {
        id = "StormCore",
        name = "Pulsing Storm Core",
        category = "Material",
        slot = nil,
        rarity = "Epic",
        description = "The dense energy heart of a high-tier storm elemental or apex beast.",
        maxStack = 20,
        buyPrice = 250,
        sellPrice = 110,
        stats = nil,
        iconColor = Color3.fromRGB(195, 80, 255),
    },

    EpicCore = {
        id = "EpicCore",
        name = "Hyper-Charged Drone Core",
        category = "Material",
        slot = nil,
        rarity = "Epic",
        description = "Rare pristine power cell recovered from high-altitude surveillance drones.",
        maxStack = 20,
        buyPrice = 320,
        sellPrice = 150,
        stats = nil,
        iconColor = Color3.fromRGB(240, 110, 255),
    },

    LegendaryHammerPart = {
        id = "LegendaryHammerPart",
        name = "Ancient Stormforge Relic Fragment",
        category = "Material",
        slot = nil,
        rarity = "Legendary",
        description = "A mythical fragment of the original celestial warhammer forge.",
        maxStack = 10,
        buyPrice = 1500,
        sellPrice = 600,
        stats = nil,
        iconColor = Color3.fromRGB(255, 175, 35),
    },
}

-- Helper methods
function ItemDatabase.GetItem(id: string): ItemDefinition?
    return ItemDatabase[id]
end

function ItemDatabase.GetAllItems(): { [string]: ItemDefinition }
    return ItemDatabase
end

return ItemDatabase