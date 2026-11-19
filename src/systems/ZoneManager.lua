--!strict
--[[
    ZoneManager.lua
    Central World and Zone Management System:
    Tracks player locations, manages zone state transitions,
    and coordinates portal teleports between the Lobby, Wilds, and Training Arena.
    Uses static ReplicatedStorage.Network architecture.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WorldFolder = ReplicatedStorage:WaitForChild("World")
local ZoneConfig = require(WorldFolder:WaitForChild("Zones"):WaitForChild("ZoneConfig"))

local ZoneManager = {}
local playerCurrentZones: { [Player]: string } = {}
local playerTeleportDebounce: { [Player]: number } = {}
local TELEPORT_DEBOUNCE_TIME = 2.0

-- Static Network Architecture
local networkFolder = ReplicatedStorage:WaitForChild("Network")
local zoneChangedEvent = networkFolder:WaitForChild("ZoneChanged") :: RemoteEvent

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

    -- Safe teleportation with upward offset and velocity stabilization
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    hrp.CFrame = targetData.spawnCFrame + Vector3.new(0, 3, 0)

    playerCurrentZones[player] = targetZoneId
    player:SetAttribute("CurrentZone", targetZoneId)
    playerTeleportDebounce[player] = os.clock()

    -- Notify client of zone entry
    zoneChangedEvent:FireClient(player, targetData.displayName, targetData.description, targetData.isSafeZone)
    print(string.format("[ZoneManager] Teleported %s to %s", player.Name, targetData.displayName))
    return true
end

-- Automatic portal touch binding with robust debounce and multi-portal attribute detection
function ZoneManager.HookPortals()
    local function checkGate(descendant: Instance)
        if descendant:IsA("BasePart") and descendant:GetAttribute("TargetZone") ~= nil then
            local targetZone = descendant:GetAttribute("TargetZone") :: string
            descendant.Touched:Connect(function(hit)
                local character = hit.Parent
                local player = character and Players:GetPlayerFromCharacter(character)
                if player then
                    local now = os.clock()
                    local lastTeleport = playerTeleportDebounce[player] or 0
                    if now - lastTeleport < TELEPORT_DEBOUNCE_TIME then return end

                    if ZoneManager.GetPlayerZone(player) ~= targetZone then
                        ZoneManager.TeleportPlayer(player, targetZone)
                    end
                end
            end)
        end
    end

    Workspace.DescendantAdded:Connect(checkGate)
    for _, item in ipairs(Workspace:GetDescendants()) do
        checkGate(item)
    end
end

-- Reset zone state cleanly on character spawn / respawn after defeat
local function onPlayerAdded(player: Player)
    player.CharacterAdded:Connect(function()
        playerCurrentZones[player] = "Lobby"
        player:SetAttribute("CurrentZone", "Lobby")
        local lobbyData = ZoneConfig["Lobby"]
        if lobbyData then
            zoneChangedEvent:FireClient(player, lobbyData.displayName, lobbyData.description, lobbyData.isSafeZone)
        end
    end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
    task.spawn(onPlayerAdded, p)
end

Players.PlayerRemoving:Connect(function(player)
    playerCurrentZones[player] = nil
    playerTeleportDebounce[player] = nil
end)

return ZoneManager
