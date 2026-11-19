--!strict
--[[
    ZoneManager.lua
    Central World and Zone Management System:
    Tracks player locations, manages zone state transitions,
    and coordinates portal teleports between the Lobby, Wilds, and Training Arena.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WorldFolder = ReplicatedStorage:WaitForChild("World")
local ZoneConfig = require(WorldFolder:WaitForChild("Zones"):WaitForChild("ZoneConfig"))

local ZoneManager = {}
local playerCurrentZones: { [Player]: string } = {}

-- Ensure Network RemoteEvent exists for Zone transitions
local networkFolder = ReplicatedStorage:WaitForChild("Network")
local zoneChangedEvent = networkFolder:FindFirstChild("ZoneChanged") :: RemoteEvent
if not zoneChangedEvent then
    zoneChangedEvent = Instance.new("RemoteEvent")
    zoneChangedEvent.Name = "ZoneChanged"
    zoneChangedEvent.Parent = networkFolder
end

function ZoneManager.GetPlayerZone(player: Player): string
    return playerCurrentZones[player] or "Lobby"
end

function ZoneManager.TeleportPlayer(player: Player, targetZoneId: string): boolean
    local targetData = ZoneConfig[targetZoneId]
    if not targetData then
        warn(string.format("[ZoneManager] Target zone %s does not exist.", targetZoneId))
        return false
    end

    local character = player.Character
    if not character then return false end

    local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not hrp then return false end

    -- Safe teleportation with upward offset
    hrp.CFrame = targetData.spawnCFrame + Vector3.new(0, 3, 0)
    playerCurrentZones[player] = targetZoneId
    player:SetAttribute("CurrentZone", targetZoneId)

    -- Notify client of zone entry
    zoneChangedEvent:FireClient(player, targetData.displayName, targetData.description, targetData.isSafeZone)
    print(string.format("[ZoneManager] Teleported %s to %s", player.Name, targetData.displayName))
    return true
end

-- Automatic portal touch binding
function ZoneManager.HookPortals()
    local function checkGate(descendant: Instance)
        if descendant.Name == "TeleportGatePart" and descendant:IsA("BasePart") then
            local targetZone = descendant:GetAttribute("TargetZone") :: string?
            if targetZone then
                descendant.Touched:Connect(function(hit)
                    local character = hit.Parent
                    local player = character and Players:GetPlayerFromCharacter(character)
                    if player and ZoneManager.GetPlayerZone(player) ~= targetZone then
                        -- Debounce via current zone check
                        ZoneManager.TeleportPlayer(player, targetZone)
                    end
                end)
            end
        end
    end

    Workspace.DescendantAdded:Connect(checkGate)
    for _, item in ipairs(Workspace:GetDescendants()) do
        checkGate(item)
    end
end

Players.PlayerRemoving:Connect(function(player)
    playerCurrentZones[player] = nil
end)

return ZoneManager
