--!strict
--[[
    ShopConfig.lua
    Configuration and item listings for NPC merchants in the Grand Storm Sanctuary.
]]

export type ShopMerchant = {
    id: string,
    name: string,
    title: string,
    greeting: string,
    itemsForSale: { string }, -- Array of ItemDatabase IDs
    buysFromPlayer: boolean,
    allowsRepair: boolean,
    modelColor: Color3,
    position: Vector3,
    lookDirection: Vector3,
}

local ShopConfig: { [string]: ShopMerchant } = {
    WeaponMerchant = {
        id = "WeaponMerchant",
        name = "Weaponsmith Garrick",
        title = "Grand Armorer",
        greeting = "Need steel to smash through the rogue drones? My hammers and blades are balanced to perfection.",
        itemsForSale = { "IronWarhammer", "StormGlaive", "ThunderClaymore" },
        buysFromPlayer = true,
        allowsRepair = true,
        modelColor = Color3.fromRGB(180, 80, 50),
        position = Vector3.new(-45, 1, 25),
        lookDirection = Vector3.new(1, 0, 0),
    },

    ArmorMerchant = {
        id = "ArmorMerchant",
        name = "Vanguard Vane",
        title = "Plate Master",
        greeting = "A single lightning surge from a Storm Beast will tear unshielded flesh. Suit up before heading out.",
        itemsForSale = { "IronPauldrons", "VanguardGreaves", "StormHelmet", "StormPlate" },
        buysFromPlayer = true,
        allowsRepair = true,
        modelColor = Color3.fromRGB(80, 110, 190),
        position = Vector3.new(-45, 1, 40),
        lookDirection = Vector3.new(1, 0, 0),
    },

    PotionMerchant = {
        id = "PotionMerchant",
        name = "Alchemist Lyra",
        title = "Apothecary of the Mists",
        greeting = "Brewed from tempest condensation and wild flora! Guaranteed to keep your heart pumping in the storm.",
        itemsForSale = { "HealthPotion", "SpeedDraught", "StormSurgeFlask" },
        buysFromPlayer = true,
        allowsRepair = false,
        modelColor = Color3.fromRGB(60, 180, 120),
        position = Vector3.new(45, 1, 25),
        lookDirection = Vector3.new(-1, 0, 0),
    },

    Blacksmith = {
        id = "Blacksmith",
        name = "Forge Master Keith",
        title = "Master of the Spark",
        greeting = "Bring me crystals, beast pelts, and relics. I will refine them or supply raw ingots for your journey.",
        itemsForSale = { "IronOre", "BeastHide", "LightningCrystal", "StormCore", "ThunderStone", "LightningRing" },
        buysFromPlayer = true,
        allowsRepair = true,
        modelColor = Color3.fromRGB(190, 140, 40),
        position = Vector3.new(45, 1, 40),
        lookDirection = Vector3.new(-1, 0, 0),
    },
}

return ShopConfig