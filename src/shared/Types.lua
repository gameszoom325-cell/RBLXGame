--!strict
--[[
    Types.lua
    Central type definitions for Hero Roleplay Character Pipeline.
]]

export type CharacterId = string
export type AbilityId = string

export type CharacterStats = {
    health: number,
    walkSpeed: number,
    jumpPower: number,
    power: number,
    armor: number,
}

export type R15Scaling = {
    height: number,
    width: number,
    depth: number,
    head: number,
    bodyType: number,
    proportions: number,
}

export type AccessoryType = "Hat" | "Hair" | "Shoulder" | "Back" | "Front" | "Waist"

export type AccessorySpec = {
    id: string,
    name: string,
    attachmentPoint: string,
    parentPart: string,
    accessoryType: AccessoryType,
    offset: CFrame?,
    color: Color3?,
    material: Enum.Material?,
    meshId: string?,
    textureId: string?,
}

export type WeaponSpec = {
    id: string,
    name: string,
    gripAttachment: string,
    damage: number,
    range: number,
    modelName: string,
    glowColor: Color3,
}

export type AbilitySpec = {
    id: AbilityId,
    name: string,
    description: string,
    cooldown: number,
    energyCost: number,
    castDuration: number,
    animationKey: string,
    inputKey: Enum.KeyCode,
    vfxName: string,
}

export type AnimationMap = {
    Idle: string,
    Walk: string,
    Run: string,
    Jump: string,
    Attack: string,
    HeavyAttack: string,
    AbilityCast: string,
    VictoryPose: string,
}

export type CharacterConfig = {
    id: CharacterId,
    name: string,
    title: string,
    role: string,
    description: string,
    stats: CharacterStats,
    scaling: R15Scaling,
    colors: { [string]: Color3 },
    accessories: { [string]: AccessorySpec },
    weapon: WeaponSpec,
    abilities: { AbilityId },
    animations: AnimationMap,
}

return {}
