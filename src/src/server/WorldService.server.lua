--!strict
--[[
    WorldService.server.lua
    Master World Orchestrator:
    Bootstraps the Main Lobby, environmental atmosphere, zone portals,
    enemy spawners, and combat-to-quest event routing.
]]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = ReplicatedStorage:WaitForChild("World")
local Systems = ReplicatedStorage:WaitForChild("Systems")

local LobbyBuilder = require(World:WaitForChild("Lobby"):WaitForChild("LobbyBuilder"))
local TempestWildsBuilder = require(World:WaitForChild("Zones"):WaitForChild("TempestWildsBuilder"))
local AtmosphereController = require(World:WaitForChild("Environment"):WaitForChild("AtmosphereController"))
local ZoneManager = require(Systems:WaitForChild("ZoneManager"))
local EnemyManager = require(Systems:WaitForChild("EnemyManager"))
local QuestManager = require(Systems:WaitForChild("QuestManager"))

local networkFolder = ReplicatedStorage:WaitForChild("Network")
local castAbilityEvent = networkFolder:WaitForChild("CastAbility") :: RemoteEvent

-- Radius damage utility for abilities against enemies in Workspace
local function applyRadiusDamage(centerPos: Vector3, radius: number, damage: number, attacker: Player)
    for _, item in ipairs(Workspace:GetChildren()) do
        if item:IsA("Model") and item:FindFirstChildOfClass("Humanoid") then
            -- Skip player characters
            if not Players:GetPlayerFromCharacter(item) then
                local root = item.PrimaryPart or item:FindFirstChild("Torso") :: BasePart?
                if root and (root.Position - centerPos).Magnitude <= radius then
                    EnemyManager.TakeDamage(item, damage, attacker)
                end
            end
        end
    end
end

local function hookCombatToQuests()
    -- Listen to ability casts to trigger radius damage & quest progress
    castAbilityEvent.OnServerEvent:Connect(function(player: Player, abilityId: any, targetPos: any)
        if typeof(abilityId) ~= "string" then return end

        -- Progress ability casting quest
        QuestManager.ProgressObjective(player, "CastAbility", 1)

        local character = player.Character
        local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
        if not hrp then return end

        if abilityId == "LightningStrike" then
            local strikeLoc = if typeof(targetPos) == "Vector3" then targetPos else (hrp.Position + hrp.CFrame.LookVector * 20)
            task.delay(0.1, function()
                applyRadiusDamage(strikeLoc, 14, 90, player)
            end)
        elseif abilityId == "ThunderHammerSlam" then
            task.delay(0.2, function()
                applyRadiusDamage(hrp.Position, 16, 125, player)
            end)
        end
    end)
end

local function initWorld()
    print("[WorldService] Initializing RBLXGame Core World Foundation...")

    -- 1. Apply Fantasy Lighting & Atmosphere
    AtmosphereController.ApplyFantasyPreset()

    -- 2. Build Main Lobby (Grand Storm Sanctuary)
    LobbyBuilder.BuildLobby()

    -- 3. Build Zone 1: The Tempest Wilds
    TempestWildsBuilder.BuildZone()

    -- 4. Hook Teleport Portals between Sanctuary and Wilds
    ZoneManager.HookPortals()

    -- 5. Spawn Ambient Enemies in the Wilds
    task.delay(1.0, function()
        EnemyManager.InitNodes()
    end)

    -- 6. Hook Combat & Ability events to Quests
    hookCombatToQuests()

    print("[WorldService] World foundation and game loop successfully active.")
end

task.spawn(initWorld)
