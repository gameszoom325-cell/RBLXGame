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
export type EquipSlot = "Weapon" | "Offhand" | "Chest" | "Head" | "Legs" | "Shoulders" | "Gloves" | "Boots" | "Necklace" | "Ring" | "Artifact" | "Cape" | "Relic"
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
    setName: string?,
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
    Offhand: string?,
    Chest: string?,
    Head: string?,
    Legs: string?,
    Shoulders: string?,
    Gloves: string?,
    Boots: string?,
    Necklace: string?,
    Ring: string?,
    Artifact: string?,
    Cape: string?,
    Relic: string?,
}

export type PlayerStatistics = {
    PlayTime: number,
    EnemyKills: number,
    BossKills: number,
    Deaths: number,
    LastLogin: number,
    QuestsCompleted: number,
    DungeonsCompleted: number?,
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
    Achievements: { string }?,
    Titles: { string }?,
    Stats: PlayerStatistics,
}

export type DamageNumberType = "Normal" | "Critical" | "Lightning" | "Healing" | "EnemyDamage"

export type DamageNumberData = {
    amount: number,
    position: Vector3,
    damageType: DamageNumberType,
}

-- Phase 8 Types: Party, Dungeon, Boss, World Event & Achievements
export type PartyMember = {
    userId: number,
    name: string,
    level: number,
    health: number,
    maxHealth: number,
    isLeader: boolean,
    isDowned: boolean?,
}

export type PartyData = {
    id: string,
    leaderUserId: number,
    members: { [number]: PartyMember },
}

export type DungeonObjective = {
    id: string,
    description: string,
    currentCount: number,
    targetCount: number,
    isCompleted: boolean,
}

export type DungeonState = {
    dungeonId: string,
    name: string,
    difficulty: "Normal" | "Heroic",
    status: "Waiting" | "Active" | "Completed" | "Failed",
    timeRemaining: number,
    livesRemaining: number,
    objectives: { DungeonObjective },
    bossSpawned: boolean,
}

export type BossPhase = 1 | 2 | 3

export type BossState = {
    id: string,
    name: string,
    title: string,
    maxHealth: number,
    currentHealth: number,
    phase: BossPhase,
    isEnraged: boolean,
    enrageTimeRemaining: number,
}

export type WorldEventType = "MeteorShower" | "LightningStorm" | "BossInvasion" | "DoubleXP" | "TreasureRain"

export type WorldEventState = {
    eventType: WorldEventType,
    title: string,
    description: string,
    durationRemaining: number,
    isActive: boolean,
}

export type AchievementSpec = {
    id: string,
    title: string,
    description: string,
    xpReward: number,
    goldReward: number,
    titleReward: string?,
}

return {}
