--!strict
--[[
    SpawnService.server.lua
    Manages player connection lifecycles, initial spawn sequences,
    and hero selection triggers.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local CharacterRegistry = require(Shared:WaitForChild("CharacterRegistry"))

local networkFolder = ReplicatedStorage:WaitForChild("Network")
local openHeroSelectionEvent = networkFolder:FindFirstChild("OpenHeroSelection") :: RemoteEvent
if not openHeroSelectionEvent then
    openHeroSelectionEvent = Instance.new("RemoteEvent")
    openHeroSelectionEvent.Name = "OpenHeroSelection"
    openHeroSelectionEvent.Parent = networkFolder
end

-- Default spawn handling
local function onPlayerAdded(player: Player)
    print(string.format("[SpawnService] Player %s (%d) joined the game.", player.Name, player.UserId))

    player.CharacterAdded:Connect(function(character)
        character:WaitForChild("HumanoidRootPart")

        -- Delay slightly to check if auto-spawner has already claimed the character
        task.delay(0.6, function()
            if not character or not character.Parent then return end
            local currentHero = character:GetAttribute("HeroId")
            if not currentHero then
                openHeroSelectionEvent:FireClient(player)
            end
        end)
    end)
end

Players.PlayerAdded:Connect(onPlayerAdded)

for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(onPlayerAdded, player)
end

print("[SpawnService] Initialized successfully.")
