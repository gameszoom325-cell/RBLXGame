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
}

return NPCConfig
