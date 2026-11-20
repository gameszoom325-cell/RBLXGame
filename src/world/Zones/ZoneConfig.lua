--!strict
--[[
    ZoneConfig.lua
    Configuration and metadata for all world regions and zones.
]]

export type ZoneData = {
    id: string,
    name: string,
    displayName: string,
    description: string,
    spawnCFrame: CFrame,
    isSafeZone: boolean,
    ambientColor: Color3,
}

local ZoneConfig: { [string]: ZoneData } = {
    Lobby = {
        id = "Lobby",
        name = "Lobby",
        displayName = "Grand Storm Sanctuary",
        description = "The central citadel for heroes. Rest, accept quests, and prepare for battle.",
        spawnCFrame = CFrame.new(0, 3, 0),
        isSafeZone = true,
        ambientColor = Color3.fromRGB(45, 60, 85),
    },

    TempestWilds = {
        id = "TempestWilds",
        name = "TempestWilds",
        displayName = "The Tempest Wilds",
        description = "A turbulent frontier overrun by rogue electrostatic drones and storm beasts.",
        spawnCFrame = CFrame.new(200, 3, 200),
        isSafeZone = false,
        ambientColor = Color3.fromRGB(20, 45, 75),
    },

    TrainingSanctuary = {
        id = "TrainingSanctuary",
        name = "TrainingSanctuary",
        displayName = "Hero Combat Proving Grounds",
        description = "Reinforced testing arena featuring automated target dummies and range markers.",
        spawnCFrame = CFrame.new(0, 3, -180),
        isSafeZone = true,
        ambientColor = Color3.fromRGB(30, 40, 60),
    },

    FrozenPeaks = {
        id = "FrozenPeaks",
        name = "FrozenPeaks",
        displayName = "The Frozen Peaks",
        description = "Permafrost mountains swept by blinding blizzards and glacial behemoths.",
        spawnCFrame = CFrame.new(-300, 24, -250),
        isSafeZone = false,
        ambientColor = Color3.fromRGB(180, 215, 255),
    },

    VolcanicWastes = {
        id = "VolcanicWastes",
        name = "VolcanicWastes",
        displayName = "The Volcanic Wastes",
        description = "A scorched volcanic crater brimming with molten fury and subterranean predators.",
        spawnCFrame = CFrame.new(300, 19, -250),
        isSafeZone = false,
        ambientColor = Color3.fromRGB(220, 80, 40),
    },
}

return ZoneConfig
