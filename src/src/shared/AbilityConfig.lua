--!strict
--[[
    AbilityConfig.lua
    Central registry and configuration for hero abilities.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))

local AbilityConfig: { [Types.AbilityId]: Types.AbilitySpec } = {
    LightningStrike = {
        id = "LightningStrike",
        name = "Lightning Strike",
        description = "Calls down a high-voltage thunderbolt from the sky to electrocute target area, dealing instant damage.",
        cooldown = 4.0,
        energyCost = 25,
        castDuration = 0.4,
        animationKey = "AbilityCast",
        inputKey = Enum.KeyCode.E,
        vfxName = "VFX_LightningStrike",
    },

    ThunderHammerSlam = {
        id = "ThunderHammerSlam",
        name = "Thunder Hammer Slam",
        description = "Leaps forward and drives the Stormforge Warhammer into the earth, producing a shockwave with electric fissures.",
        cooldown = 7.5,
        energyCost = 40,
        castDuration = 0.8,
        animationKey = "HeavyAttack",
        inputKey = Enum.KeyCode.Q,
        vfxName = "VFX_HammerSlam",
    },

    StormShield = {
        id = "StormShield",
        name = "Storm Shield",
        description = "Envelops Valen in an electrostatic barrier that absorbs incoming attacks and deflects projectiles for 4 seconds.",
        cooldown = 12.0,
        energyCost = 35,
        castDuration = 0.2,
        animationKey = "VictoryPose",
        inputKey = Enum.KeyCode.F,
        vfxName = "VFX_StormShield",
    },

    LightningDash = {
        id = "LightningDash",
        name = "Lightning Dash",
        description = "Transforms into a bolt of pure lightning, instantly surging forward 30 studs and leaving a shock trail.",
        cooldown = 5.0,
        energyCost = 20,
        castDuration = 0.15,
        animationKey = "Run",
        inputKey = Enum.KeyCode.LeftShift,
        vfxName = "VFX_LightningDash",
    },
}

return AbilityConfig
