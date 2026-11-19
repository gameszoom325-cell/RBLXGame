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
}

return ZoneConfig
