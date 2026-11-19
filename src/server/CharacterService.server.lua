--!strict
--[[
    CharacterService.server.lua
    Server-authoritative modular character loader and hero manager.
    Connects to CharacterLoader to spawn, morph, and equip heroes.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local CharacterRegistry = require(Shared:WaitForChild("CharacterRegistry"))
local CharacterLoader = require(Shared:WaitForChild("CharacterLoader"))

local CharacterService = {}
local activePlayerCharacters: { [Player]: Types.CharacterId } = {}

-- Ensure Network folder and RemoteEvents exist
local networkFolder = ReplicatedStorage:FindFirstChild("Network")
if not networkFolder then
    networkFolder = Instance.new("Folder")
    networkFolder.Name = "Network"
    networkFolder.Parent = ReplicatedStorage
end

local function getOrCreateRemoteEvent(name: string): RemoteEvent
    local event = networkFolder:FindFirstChild(name) :: RemoteEvent
    if not event then
        event = Instance.new("RemoteEvent")
        event.Name = name
        event.Parent = networkFolder
    end
    return event
end

local function getOrCreateRemoteFunction(name: string): RemoteFunction
    local remoteFunc = networkFolder:FindFirstChild(name) :: RemoteFunction
    if not remoteFunc then
        remoteFunc = Instance.new("RemoteFunction")
        remoteFunc.Name = name
        remoteFunc.Parent = networkFolder
    end
    return remoteFunc
end

local selectHeroFunction = getOrCreateRemoteFunction("SelectHero")
local heroLoadedEvent = getOrCreateRemoteEvent("HeroLoaded")

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
