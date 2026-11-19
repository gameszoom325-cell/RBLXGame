--!strict
--[[
    TestCharacterSpawner.server.lua
    Developer Testing Suite: Automatically spawns Stormforge Valen when Play starts in Studio.
    Uses the existing CharacterLoader pipeline without duplicating any logic.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterLoader = require(Shared:WaitForChild("CharacterLoader"))
local CharacterRegistry = require(Shared:WaitForChild("CharacterRegistry"))

local networkFolder = ReplicatedStorage:WaitForChild("Network")
local heroLoadedEvent = networkFolder:WaitForChild("HeroLoaded") :: RemoteEvent

local AUTO_SPAWN_HERO_ID = "StormforgeValen"

local function onPlayerSpawn(player: Player)
    -- Verify hero exists in registry
    local heroConfig = CharacterRegistry.GetCharacter(AUTO_SPAWN_HERO_ID)
    if not heroConfig then
        warn(string.format("[TestSpawner] Hero %s not found in registry.", AUTO_SPAWN_HERO_ID))
        return
    end

    print(string.format("[TestSpawner] Initiating test spawn for %s as %s...", player.Name, heroConfig.name))

    -- Small delay to let default character load and settle
    task.delay(0.2, function()
        if not player or not player.Parent then return end

        local character = CharacterLoader.SpawnHero(player, AUTO_SPAWN_HERO_ID)
        if character then
            -- Position character above test spawn platform
            local hrp = character:WaitForChild("HumanoidRootPart") :: BasePart
            hrp.CFrame = CFrame.new(0, 5, 0)

            -- Notify client systems that hero is loaded
            heroLoadedEvent:FireClient(player, AUTO_SPAWN_HERO_ID)
            print(string.format("[TestSpawner] Hero %s successfully initialized for %s.", AUTO_SPAWN_HERO_ID, player.Name))
        else
            warn(string.format("[TestSpawner] Failed to spawn hero %s for %s.", AUTO_SPAWN_HERO_ID, player.Name))
        end
    end)
end

local function onPlayerAdded(player: Player)
    player.CharacterAdded:Connect(function()
        onPlayerSpawn(player)
    end)

    if player.Character then
        onPlayerSpawn(player)
    end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(onPlayerAdded, player)
end

print("[TestCharacterSpawner] Active: Auto-spawning Stormforge Valen on player connect.")
