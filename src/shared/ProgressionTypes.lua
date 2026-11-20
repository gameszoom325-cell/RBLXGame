--!strict
--[[
    ProgressionTypes.lua
    Data schemas and type definitions for Phase 7 RPG Progression:
    - Persistent Player Data (DataStore v1)
    - Item Database specifications
    - Equipment Stat modifiers
    - Inventory and Shop transactions
]]

export type ItemCategory = "Weapon" | "Armor" | "Artifact" | "Consumable" | "QuestItem" | "Material"
export type EquipSlot = "Weapon" | "Chest" | "Head" | "Shoulders" | "Boots" | "Artifact"
export type ItemRarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"

export type EquipmentStats = {
    health: number?,
    attack: number?,
    defense: number?,
    speed: number?,
    critChance: number?,      -- e.g. 0.05 = +5%
    critDamage: number?,      -- e.g. 0.25 = +25%
    lightningDamage: number?, -- flat or multiplier bonus
    abilityCooldown: number?, -- e.g. 0.10 = -10% cooldown
}

export type ItemDefinition = {
    id: string,
    name: string,
    category: ItemCategory,
    slot: EquipSlot?,
    rarity: ItemRarity,
    description: string,
    maxStack: number,
    buyPrice: number,
    sellPrice: number,
    stats: EquipmentStats?,
    usableEffect: string?,
    iconColor: Color3?,
}

export type InventoryItem = {
    uuid: string,
    id: string,
    count: number,
    isLocked: boolean,
    isFavorite: boolean,
}

export type EquippedGear = {
    Weapon: string?,
    Chest: string?,
    Head: string?,
    Shoulders: string?,
    Boots: string?,
    Artifact: string?,
}

export type PlayerStatistics = {
    PlayTime: number,
    EnemyKills: number,
    BossKills: number,
    Deaths: number,
    LastLogin: number,
    QuestsCompleted: number,
}

export type PlayerData = {
    Version: number,
    Level: number,
    XP: number,
    Gold: number,
    UnlockedHeroes: { string },
    PreferredHero: string,
    Equipped: EquippedGear,
    Inventory: { InventoryItem },
    QuestProgress: { [string]: { currentCount: number, isCompleted: boolean, isClaimed: boolean } },
    SkillUnlocks: { string },
    Stats: PlayerStatistics,
}

export type DamageNumberType = "Normal" | "Critical" | "Lightning" | "Healing" | "EnemyDamage"

export type DamageNumberData = {
    amount: number,
    position: Vector3,
    damageType: DamageNumberType,
}

return {}
