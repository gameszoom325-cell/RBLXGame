--!strict
--[[
    CharacterService.server.lua
    Server-authoritative modular character loader and hero manager.
    Connects to CharacterLoader to spawn, morph, and equip heroes.
    Uses static ReplicatedStorage.Network architecture.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local CharacterRegistry = require(Shared:WaitForChild("CharacterRegistry"))
local CharacterLoader = require(Shared:WaitForChild("CharacterLoader"))

local CharacterService = {}
local activePlayerCharacters: { [Player]: Types.CharacterId } = {}

-- Static Network Architecture
local networkFolder = ReplicatedStorage:WaitForChild("Network")
local selectHeroFunction = networkFolder:WaitForChild("SelectHero") :: RemoteFunction
local heroLoadedEvent = networkFolder:WaitForChild("HeroLoaded") :: RemoteEvent

-- Core Character Loading Pipeline
function CharacterService.LoadHero(player: Player, heroId: Types.CharacterId): boolean
    local config = CharacterRegistry.GetCharacter(heroId)
    if not config then
        warn(string.format("[CharacterService] Hero ID %s not found in registry.", heroId))
        return false
    end

    local character = CharacterLoader.SpawnHero(player, heroId)
    if not character then
        return false
    end

    activePlayerCharacters[player] = heroId
    heroLoadedEvent:FireClient(player, heroId)
    return true
end

-- Handle remote hero selection
selectHeroFunction.OnServerInvoke = function(player: Player, heroId: any)
    if typeof(heroId) ~= "string" then return false end
    return CharacterService.LoadHero(player, heroId)
end

Players.PlayerRemoving:Connect(function(player)
    activePlayerCharacters[player] = nil
end)

return CharacterService
