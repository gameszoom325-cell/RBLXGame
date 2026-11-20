--!strict
--[[
    LootDatabase.lua
    Weighted loot drop tables for enemies, world bosses, and treasure caches.
]]

export type LootEntry = {
    itemId: string,
    minCount: number,
    maxCount: number,
    chance: number, -- 0.0 to 1.0 (e.g. 0.40 = 40%)
}

export type EnemyLootTable = {
    goldMin: number,
    goldMax: number,
    goldChance: number,
    drops: { LootEntry },
}

local LootDatabase = {}

local LOOT_TABLES: { [string]: EnemyLootTable } = {
    TempestDrone = {
        goldMin = 10,
        goldMax = 25,
        goldChance = 0.80, -- 80% Gold
        drops = {
            { itemId = "IronOre", minCount = 1, maxCount = 2, chance = 0.40 },          -- 40% Iron Ore
            { itemId = "LightningCrystal", minCount = 1, maxCount = 1, chance = 0.15 }, -- 15% Lightning Crystal
            { itemId = "EpicCore", minCount = 1, maxCount = 1, chance = 0.02 },         -- 2% Epic Core
        },
    },

    StormBeast = {
        goldMin = 50,
        goldMax = 100,
        goldChance = 1.00, -- 100% Gold
        drops = {
            { itemId = "BeastHide", minCount = 1, maxCount = 3, chance = 0.50 },           -- 50% Beast Hide
            { itemId = "StormCore", minCount = 1, maxCount = 1, chance = 0.25 },           -- 25% Storm Core
            { itemId = "LegendaryHammerPart", minCount = 1, maxCount = 1, chance = 0.05 }, -- 5% Legendary Hammer Part
        },
    },
}

export type RolledLoot = {
    gold: number,
    items: { { id: string, count: number } },
}

function LootDatabase.RollLoot(enemyType: string): RolledLoot
    local tableData = LOOT_TABLES[enemyType]
    local result: RolledLoot = {
        gold = 0,
        items = {},
    }

    if not tableData then
        -- Default small gold drop if unknown enemy
        result.gold = math.random(5, 15)
        return result
    end

    -- Roll Gold
    if math.random() <= tableData.goldChance then
        result.gold = math.random(tableData.goldMin, tableData.goldMax)
    end

    -- Roll Items
    for _, drop in ipairs(tableData.drops) do
        if math.random() <= drop.chance then
            local count = math.random(drop.minCount, drop.maxCount)
            if count > 0 then
                table.insert(result.items, {
                    id = drop.itemId,
                    count = count,
                })
            end
        end
    end

    return result
end

function LootDatabase.GetTable(enemyType: string): EnemyLootTable?
    return LOOT_TABLES[enemyType]
end

return LootDatabase