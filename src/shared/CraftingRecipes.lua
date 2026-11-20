--!strict
--[[
    CraftingRecipes.lua
    Catalog of forging blueprints, component requirements, and enhancement tiers.
]]

export type Ingredient = {
    itemId: string,
    count: number,
}

export type CraftRecipe = {
    id: string,
    resultItemId: string,
    resultCount: number,
    goldCost: number,
    ingredients: { Ingredient },
    category: "Weapon" | "Armor" | "Consumable" | "Artifact",
}

local CraftingRecipes: { [string]: CraftRecipe } = {
    Craft_StormGlaive = {
        id = "Craft_StormGlaive",
        resultItemId = "StormGlaive",
        resultCount = 1,
        goldCost = 250,
        ingredients = {
            { itemId = "IronWarhammer", count = 1 },
            { itemId = "IronOre", count = 6 },
            { itemId = "LightningCrystal", count = 2 },
        },
        category = "Weapon",
    },

    Craft_ThunderClaymore = {
        id = "Craft_ThunderClaymore",
        resultItemId = "ThunderClaymore",
        resultCount = 1,
        goldCost = 800,
        ingredients = {
            { itemId = "IronOre", count = 12 },
            { itemId = "StormCore", count = 3 },
            { itemId = "LegendaryHammerPart", count = 1 },
        },
        category = "Weapon",
    },

    Craft_StormPlate = {
        id = "Craft_StormPlate",
        resultItemId = "StormPlate",
        resultCount = 1,
        goldCost = 500,
        ingredients = {
            { itemId = "IronPauldrons", count = 1 },
            { itemId = "BeastHide", count = 8 },
            { itemId = "StormCore", count = 2 },
        },
        category = "Armor",
    },

    Craft_VanguardGreaves = {
        id = "Craft_VanguardGreaves",
        resultItemId = "VanguardGreaves",
        resultCount = 1,
        goldCost = 250,
        ingredients = {
            { itemId = "IronOre", count = 6 },
            { itemId = "BeastHide", count = 4 },
            { itemId = "LightningCrystal", count = 1 },
        },
        category = "Armor",
    },

    Craft_StormHelmet = {
        id = "Craft_StormHelmet",
        resultItemId = "StormHelmet",
        resultCount = 1,
        goldCost = 300,
        ingredients = {
            { itemId = "IronOre", count = 8 },
            { itemId = "LightningCrystal", count = 2 },
        },
        category = "Armor",
    },

    Craft_HealthPotions = {
        id = "Craft_HealthPotions",
        resultItemId = "HealthPotion",
        resultCount = 3,
        goldCost = 35,
        ingredients = {
            { itemId = "BeastHide", count = 2 },
            { itemId = "IronOre", count = 2 },
        },
        category = "Consumable",
    },

    Craft_StormSurgeFlask = {
        id = "Craft_StormSurgeFlask",
        resultItemId = "StormSurgeFlask",
        resultCount = 1,
        goldCost = 80,
        ingredients = {
            { itemId = "LightningCrystal", count = 2 },
            { itemId = "StormCore", count = 1 },
        },
        category = "Consumable",
    },

    Craft_GlacialPlate = {
        id = "Craft_GlacialPlate",
        resultItemId = "GlacialPlate",
        resultCount = 1,
        goldCost = 450,
        ingredients = {
            { itemId = "IronOre", count = 10 },
            { itemId = "FrostShard", count = 4 },
        },
        category = "Armor",
    },

    Craft_MoltenSaber = {
        id = "Craft_MoltenSaber",
        resultItemId = "MoltenSaber",
        resultCount = 1,
        goldCost = 600,
        ingredients = {
            { itemId = "IronOre", count = 8 },
            { itemId = "VolcanicCore", count = 3 },
            { itemId = "BeastHide", count = 4 },
        },
        category = "Weapon",
    },
}

return CraftingRecipes