--!strict
--[[
    NPCConfig.lua
    Configuration for friendly NPCs, quest givers, and roleplay merchants.
]]

export type NPCSpec = {
    id: string,
    name: string,
    title: string,
    role: "QuestGiver" | "Guide" | "Merchant",
    position: Vector3,
    lookDirection: Vector3,
    dialogueGreeting: string,
    color: Color3,
}

local NPCConfig: { [string]: NPCSpec } = {
    ArchivistOrin = {
        id = "ArchivistOrin",
        name = "Archivist Orin",
        title = "Keeper of the Storm Records",
        role = "QuestGiver",
        position = Vector3.new(-18, 1, 10),
        lookDirection = Vector3.new(1, 0, 0),
        dialogueGreeting = "Greetings, Champion of the Storm. The outer wilds grow turbulent. Review the Quest Board when you are ready.",
        color = Color3.fromRGB(65, 140, 215),
    },

    InstructorKael = {
        id = "InstructorKael",
        name = "Instructor Kael",
        title = "Master-at-Arms",
        role = "Guide",
        position = Vector3.new(38, 1, 0),
        lookDirection = Vector3.new(-1, 0, 0),
        dialogueGreeting = "Welcome, Stormforge Valen. Test your hammer swings and lightning abilities against the dummies before entering the portals.",
        color = Color3.fromRGB(200, 160, 40),
    },

    WeaponMerchant = {
        id = "WeaponMerchant",
        name = "Weaponsmith Garrick",
        title = "Grand Armorer",
        role = "Merchant",
        position = Vector3.new(-45, 1, 25),
        lookDirection = Vector3.new(1, 0, 0),
        dialogueGreeting = "Need steel to smash through rogue drones? My warhammers and blades are balanced to perfection.",
        color = Color3.fromRGB(180, 80, 50),
    },

    ArmorMerchant = {
        id = "ArmorMerchant",
        name = "Vanguard Vane",
        title = "Plate Master",
        role = "Merchant",
        position = Vector3.new(-45, 1, 40),
        lookDirection = Vector3.new(1, 0, 0),
        dialogueGreeting = "A single lightning surge from a Storm Beast will tear unshielded flesh. Suit up before heading out.",
        color = Color3.fromRGB(80, 110, 190),
    },

    PotionMerchant = {
        id = "PotionMerchant",
        name = "Alchemist Lyra",
        title = "Apothecary of the Mists",
        role = "Merchant",
        position = Vector3.new(45, 1, 25),
        lookDirection = Vector3.new(-1, 0, 0),
        dialogueGreeting = "Brewed from tempest condensation and wild flora! Guaranteed to keep your heart pumping in the storm.",
        color = Color3.fromRGB(60, 180, 120),
    },

    Blacksmith = {
        id = "Blacksmith",
        name = "Forge Master Keith",
        title = "Master of the Spark",
        role = "Merchant",
        position = Vector3.new(45, 1, 40),
        lookDirection = Vector3.new(-1, 0, 0),
        dialogueGreeting = "Bring me crystals, beast pelts, and relics. I will refine them or supply raw ingots for your journey.",
        color = Color3.fromRGB(190, 140, 40),
    },
}

return NPCConfig
