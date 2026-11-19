--!strict
--[[
    CharacterRegistry.lua
    Central registry and lookup system for all playable heroes.
    Provides extensible registration for future characters.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local StormforgeValenConfig = require(Shared:WaitForChild("StormforgeValenConfig"))

local CharacterRegistry = {}
local characters: { [Types.CharacterId]: Types.CharacterConfig } = {}

-- Register core launch character
characters[StormforgeValenConfig.id] = StormforgeValenConfig

-- Registry API
function CharacterRegistry.RegisterCharacter(config: Types.CharacterConfig)
    assert(config.id, "[CharacterRegistry] Character must have a unique ID.")
    characters[config.id] = config
    print(string.format("[CharacterRegistry] Registered hero: %s (%s)", config.name, config.id))
end

function CharacterRegistry.GetCharacter(id: Types.CharacterId): Types.CharacterConfig?
    return characters[id]
end

function CharacterRegistry.GetAllCharacters(): { [Types.CharacterId]: Types.CharacterConfig }
    return characters
end

function CharacterRegistry.GetCharacterList(): { Types.CharacterConfig }
    local list = {}
    for _, config in pairs(characters) do
        table.insert(list, config)
    end
    return list
end

-- Stubs for planned expansion heroes
CharacterRegistry.RoadmapHeroes = {
    "SolarWarrior",
    "ShadowNinja",
    "TechGuardian",
    "VoidTitan",
}

return CharacterRegistry
