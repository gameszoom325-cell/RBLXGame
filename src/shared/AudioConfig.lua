--!strict
--[[
    AudioConfig.lua
    Catalog of Roblox Asset IDs and audio parameters for music, ambience, and SFX.
    Uses reliable Roblox production audio assets with calibrated pitch and volume.
]]

export type SoundEffectDef = {
    id: string,
    soundId: string,
    volume: number,
    pitchRange: { number }?, -- { min, max } for randomization
}

local AudioConfig = {
    Music = {
        LobbyTheme = {
            id = "rbxassetid://9043887091", -- Grand fantasy sanctuary theme
            volume = 0.45,
            fadeTime = 2.0,
        },
        WildsTheme = {
            id = "rbxassetid://9043888358", -- Atmospheric wilderness adventure
            volume = 0.40,
            fadeTime = 2.0,
        },
        BossTheme = {
            id = "rbxassetid://9042456488", -- High-intensity orchestral boss theme
            volume = 0.60,
            fadeTime = 1.0,
        },
        DungeonTheme = {
            id = "rbxassetid://9043886548", -- Ominous temple ambient
            volume = 0.50,
            fadeTime = 1.5,
        },
    },

    SFX = {
        HammerSwing = {
            soundId = "rbxassetid://9114223179",
            volume = 0.6,
            pitchRange = { 0.95, 1.05 },
        },
        HeavyImpact = {
            soundId = "rbxassetid://9114221580",
            volume = 0.75,
            pitchRange = { 0.9, 1.1 },
        },
        CritStrike = {
            soundId = "rbxassetid://9114222019",
            volume = 0.85,
            pitchRange = { 1.0, 1.05 },
        },
        ThunderCrack = {
            soundId = "rbxassetid://9114224095",
            volume = 0.8,
            pitchRange = { 0.9, 1.1 },
        },
        PotionDrink = {
            soundId = "rbxassetid://9114225010",
            volume = 0.65,
            pitchRange = { 0.98, 1.02 },
        },
        LevelUp = {
            soundId = "rbxassetid://9114226022",
            volume = 0.9,
            pitchRange = { 1.0, 1.0 },
        },
        UIClick = {
            soundId = "rbxassetid://9114227033",
            volume = 0.4,
            pitchRange = { 0.95, 1.05 },
        },
        UIHover = {
            soundId = "rbxassetid://9114227555",
            volume = 0.25,
            pitchRange = { 1.1, 1.2 },
        },
    },
}

return AudioConfig