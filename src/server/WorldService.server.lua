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
local ProximityPromptService = game:GetService("ProximityPromptService")

local World = ReplicatedStorage:WaitForChild("World")
local Systems = ReplicatedStorage:WaitForChild("Systems")

local LobbyBuilder = require(World:WaitForChild("Lobby"):WaitForChild("LobbyBuilder"))
local TempestWildsBuilder = require(World:WaitForChild("Zones"):WaitForChild("TempestWildsBuilder"))
local AtmosphereController = require(World:WaitForChild("Environment"):WaitForChild("AtmosphereController"))
local NPCConfig = require(World:WaitForChild("NPCs"):WaitForChild("NPCConfig"))
local ZoneManager = require(Systems:WaitForChild("ZoneManager"))
local EnemyManager = require(Systems:WaitForChild("EnemyManager"))
local EnemyAI = require(Systems:WaitForChild("EnemyAI"))
local QuestManager = require(Systems:WaitForChild("QuestManager"))
local ShopManager = require(Systems:WaitForChild("ShopManager"))

local networkFolder = ReplicatedStorage:WaitForChild("Network")
local showDialogueEvent = networkFolder:WaitForChild("ShowDialogue") :: RemoteEvent

-- Server hook for NPC and Quest Board interactions
local function hookNPCInteractions()
    ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, player: Player)
        local parentModel = prompt.Parent and prompt.Parent.Parent
        local modelName = parentModel and parentModel.Name

        local merchantId = parentModel and parentModel:GetAttribute("MerchantId") :: string?
        if merchantId then
            ShopManager.OpenMerchant(player, merchantId)
            print(string.format("[WorldService] %s opened shop for %s", player.Name, merchantId))
            return
        end

        if modelName == "Archivist Orin" then
            local npcData = NPCConfig.ArchivistOrin
            showDialogueEvent:FireClient(player, npcData.name, npcData.dialogueGreeting, "Keeper of Records")
            print(string.format("[WorldService] %s interacted with %s", player.Name, npcData.name))
        elseif modelName == "Instructor Kael" then
            local npcData = NPCConfig.InstructorKael
            showDialogueEvent:FireClient(player, npcData.name, npcData.dialogueGreeting, "Master-at-Arms")
            print(string.format("[WorldService] %s interacted with %s", player.Name, npcData.name))
        elseif prompt.ObjectText == "Grand Quest Board" or (prompt.Parent and prompt.Parent.Name == "BoardPost") then
            -- Review and claim any ready quest rewards
            local msg = "All active assignments are synchronized. Defeat Tempest Drones and channel your storm abilities to earn XP and Gold!"
            showDialogueEvent:FireClient(player, "Grand Quest Board", msg, "Sanctuary Bulletin")
            print(string.format("[WorldService] %s reviewed the Grand Quest Board", player.Name))
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
        EnemyAI.Init()
    end)

    -- 6. Hook NPC and Quest Board ProximityPrompt interactions
    hookNPCInteractions()

    print("[WorldService] World foundation and game loop successfully active.")
end

task.spawn(initWorld)
