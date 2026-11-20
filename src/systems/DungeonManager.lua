--!strict
--[[
    DungeonManager.lua
    Server-authoritative Modular Dungeon Framework:
    - Coordinates dungeon instances, party entry, objective states, and countdown timers
    - First Dungeon: "Temple of Storms"
    - Objectives:
      1. Defeat 4 Storm Guardians in Chamber 1
      2. Overload 2 Lightning Conduits in Chamber 2
      3. Slay the Storm Titan in Chamber 3
    - Tracks team respawns (5 lives) and 10-minute time limit
    - Grants completion rewards: 2,500 XP, 1,000 Gold, Epic Gear, Title & Achievement
]]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Systems = ReplicatedStorage:WaitForChild("Systems")
local World = ReplicatedStorage:WaitForChild("World")

local ProgressionTypes = require(Shared:WaitForChild("ProgressionTypes"))
local TempleOfStorms = require(World:WaitForChild("Dungeons"):WaitForChild("TempleOfStorms"))
local BossManager = require(Systems:WaitForChild("BossManager"))
local ProgressionManager = require(Systems:WaitForChild("ProgressionManager"))
local EconomyManager = require(Systems:WaitForChild("EconomyManager"))
local InventoryManager = require(Systems:WaitForChild("InventoryManager"))
local PlayerDataService = require(Systems:WaitForChild("PlayerDataService"))
local PartyService = require(Systems:WaitForChild("PartyService"))

type DungeonState = ProgressionTypes.DungeonState

local networkFolder = ReplicatedStorage:WaitForChild("Network")
local dungeonActionEvent = networkFolder:WaitForChild("DungeonAction") :: RemoteEvent
local dungeonStateUpdatedEvent = networkFolder:WaitForChild("DungeonStateUpdated") :: RemoteEvent
local dungeonResultsEvent = networkFolder:WaitForChild("DungeonResults") :: RemoteEvent
local playCinematicEvent = networkFolder:WaitForChild("PlayCinematic") :: RemoteEvent

local DungeonManager = {}

local activeDungeon: DungeonState? = nil
local activeDungeonParty: { Player } = {}
local activeGuardianModels: { Model } = {}
local activeBossModel: Model? = nil
local dungeonStartTime = 0
local timerThread: thread? = nil

local function broadcastState()
    if not activeDungeon then
        for _, p in ipairs(Players:GetPlayers()) do
            dungeonStateUpdatedEvent:FireClient(p, nil)
        end
        return
    end

    for _, player in ipairs(activeDungeonParty) do
        dungeonStateUpdatedEvent:FireClient(player, activeDungeon)
    end
end

-- Progress a dungeon objective
function DungeonManager.ProgressObjective(objectiveId: string, amount: number)
    if not activeDungeon or activeDungeon.status ~= "Active" then return end

    for _, obj in ipairs(activeDungeon.objectives) do
        if obj.id == objectiveId and not obj.isCompleted then
            obj.currentCount = math.clamp(obj.currentCount + amount, 0, obj.targetCount)
            if obj.currentCount >= obj.targetCount then
                obj.isCompleted = true
                print(string.format("[DungeonManager] Dungeon Objective Complete: %s", obj.description))

                if objectiveId == "Guardians" then
                    -- Unlocks Chamber 2
                    print("[DungeonManager] Guardian Antechamber cleared. Lightning Conduits now accessible!")
                elseif objectiveId == "Conduits" then
                    -- Spawns Storm Titan in Chamber 3
                    print("[DungeonManager] Conduits overloaded! Storm Titan awakened in Sovereign Arena!")
                    local bossPos = TempleOfStorms.GetBossSpawnPosition()
                    activeBossModel = BossManager.SpawnStormTitan(bossPos)
                    activeDungeon.bossSpawned = true

                    -- Trigger Boss Cinematic for party members
                    for _, p in ipairs(activeDungeonParty) do
                        playCinematicEvent:FireClient(p, "BossIntro", { bossName = "Storm Titan" })
                    end
                elseif objectiveId == "StormTitan" then
                    -- Dungeon Victory!
                    DungeonManager.CompleteDungeon(true)
                end
            end
            break
        end
    end

    broadcastState()
end

function DungeonManager.StartDungeon(partyMembers: { Player }, difficulty: string?): (boolean, string)
    if activeDungeon and activeDungeon.status == "Active" then
        return false, "A dungeon run is already in progress."
    end

    if #partyMembers == 0 then
        return false, "No valid party members to enter."
    end

    -- Construct map
    TempleOfStorms.BuildDungeon()

    local diff: "Normal" | "Heroic" = if difficulty == "Heroic" then "Heroic" else "Normal"
    local state: DungeonState = {
        dungeonId = "TempleOfStorms",
        name = "Temple of the Storm Sovereign",
        difficulty = diff,
        status = "Active",
        timeRemaining = 600, -- 10 minutes
        livesRemaining = 5,
        objectives = {
            { id = "Guardians", description = "Defeat the 4 Storm Guardians", currentCount = 0, targetCount = 4, isCompleted = false },
            { id = "Conduits", description = "Overload 2 Lightning Conduits", currentCount = 0, targetCount = 2, isCompleted = false },
            { id = "StormTitan", description = "Slay the Storm Titan", currentCount = 0, targetCount = 1, isCompleted = false },
        },
        bossSpawned = false,
    }

    activeDungeon = state
    activeDungeonParty = partyMembers
    dungeonStartTime = os.clock()

    -- Teleport party to Dungeon Spawn
    local spawnCFrame = TempleOfStorms.GetSpawnCFrame()
    for _, player in ipairs(partyMembers) do
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
        if hrp then
            hrp.CFrame = spawnCFrame + Vector3.new(math.random(-4, 4), 0, math.random(-4, 4))
        end
    end

    -- Spawn 4 Storm Guardians in Chamber 1
    local enemyManagerModule = Systems:FindFirstChild("EnemyManager")
    if enemyManagerModule then
        local EnemyManager = require(enemyManagerModule) :: any
        local guardianSpawns = {
            Vector3.new(-18, 1002, -15),
            Vector3.new(18, 1002, -15),
            Vector3.new(-18, 1002, 15),
            Vector3.new(18, 1002, 15),
        }
        for _, gPos in ipairs(guardianSpawns) do
            local g = EnemyManager.SpawnEnemy("TempestDrone", gPos)
            table.insert(activeGuardianModels, g)
        end
    end

    -- Hook Conduit Prompts in Chamber 2
    local dungeonModel = Workspace:FindFirstChild("Dungeon_TempleOfStorms")
    local conduits = dungeonModel and dungeonModel:FindFirstChild("Conduits")
    if conduits then
        for _, conduit in ipairs(conduits:GetChildren()) do
            local prompt = conduit:FindFirstChildOfClass("ProximityPrompt")
            if prompt then
                local conn: RBXScriptConnection? = nil
                conn = prompt.Triggered:Connect(function(player: Player)
                    if table.find(activeDungeonParty, player) then
                        prompt.Enabled = false
                        conduit.Color = Color3.fromRGB(255, 120, 50)
                        DungeonManager.ProgressObjective("Conduits", 1)
                        local questModule = Systems:FindFirstChild("QuestManager")
                        if questModule then
                            local QuestManager = require(questModule) :: any
                            if QuestManager.ProgressObjective then
                                QuestManager.ProgressObjective(player, "OverloadConduit", 1)
                            end
                        end
                        if conn then conn:Disconnect() end
                    end
                end)
            end
        end
    end

    -- Start 1-second countdown loop
    if timerThread then task.cancel(timerThread) end
    timerThread = task.spawn(function()
        while activeDungeon and activeDungeon.status == "Active" and activeDungeon.timeRemaining > 0 do
            task.wait(1.0)
            activeDungeon.timeRemaining -= 1
            broadcastState()
        end

        if activeDungeon and activeDungeon.status == "Active" and activeDungeon.timeRemaining <= 0 then
            DungeonManager.CompleteDungeon(false) -- Time expired!
        end
    end)

    broadcastState()
    print(string.format("[DungeonManager] Dungeon '%s' [%s] initiated with %d player(s).", state.name, diff, #partyMembers))
    return true, "Dungeon initiated!"
end

function DungeonManager.CompleteDungeon(isVictory: boolean)
    if not activeDungeon then return end

    activeDungeon.status = if isVictory then "Completed" else "Failed"
    local timeElapsed = math.floor(os.clock() - dungeonStartTime)

    if timerThread then
        task.cancel(timerThread)
        timerThread = nil
    end

    broadcastState()

    if isVictory then
        print(string.format("[DungeonManager] *** VICTORY in Temple of Storms! (Cleared in %ds) ***", timeElapsed))

        -- Show Exit Portal
        local dungeonModel = Workspace:FindFirstChild("Dungeon_TempleOfStorms")
        local exitPortal = dungeonModel and dungeonModel:FindFirstChild("DungeonExitPortal") :: BasePart?
        if exitPortal then
            exitPortal.Visible = true
            exitPortal.CanTouch = true
            local portalPrompt = Instance.new("ProximityPrompt")
            portalPrompt.ActionText = "Return to Sanctuary"
            portalPrompt.ObjectText = "Temple Exit Portal"
            portalPrompt.HoldDuration = 0.5
            portalPrompt.Parent = exitPortal
            portalPrompt.Triggered:Connect(function(player: Player)
                local char = player.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
                if hrp then
                    hrp.CFrame = CFrame.new(0, 4, 0) -- Sanctuary center
                end
            end)
        end

        -- Award Rewards to each party member
        for _, member in ipairs(activeDungeonParty) do
            ProgressionManager.AddXP(member, 2500, "DungeonCompletion")
            EconomyManager.AddGold(member, 1000, "DungeonCompletion")

            InventoryManager.AddItem(member, "StormPlate", 1)
            InventoryManager.AddItem(member, "StormCore", 3)
            InventoryManager.AddItem(member, "LegendaryHammerPart", 1)

            PlayerDataService.UpdatePlayerData(member, function(pData)
                pData.Stats.DungeonsCompleted = (pData.Stats.DungeonsCompleted or 0) + 1
            end)

            -- Achievement & Title Unlocks
            local achModule = Systems:FindFirstChild("AchievementManager")
            if achModule then
                local AchievementManager = require(achModule) :: any
                if AchievementManager.Unlock then
                    AchievementManager.Unlock(member, "DungeonMaster")
                end
            end

            -- Client Results Screen
            dungeonResultsEvent:FireClient(member, {
                victory = true,
                timeElapsed = timeElapsed,
                xpGained = 2500,
                goldGained = 1000,
                drops = { "StormPlate", "StormCore (x3)", "LegendaryHammerPart" },
                titleUnlocked = "Conqueror of the Tempest",
            })
        end
    else
        print("[DungeonManager] Dungeon Failed! Returning party to sanctuary...")
        for _, member in ipairs(activeDungeonParty) do
            dungeonResultsEvent:FireClient(member, {
                victory = false,
                timeElapsed = timeElapsed,
                xpGained = 0,
                goldGained = 0,
                drops = {},
            })

            local char = member.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
            if hrp then
                hrp.CFrame = CFrame.new(0, 4, 0)
            end
        end
    end

    -- Clean up after 45s
    task.delay(45.0, function()
        activeDungeon = nil
        activeDungeonParty = {}
        activeGuardianModels = {}
        activeBossModel = nil
        local dFolder = Workspace:FindFirstChild("Dungeon_TempleOfStorms")
        if dFolder then dFolder:Destroy() end
    end)
end

-- Network Action listener for dungeon requests
dungeonActionEvent.OnServerEvent:Connect(function(player: Player, action: string, param1: any)
    if typeof(action) ~= "string" then return end

    if action == "Enter" then
        local party = PartyService.GetParty(player)
        local partyMembers = if party then PartyService.GetPartyMembers(player) else { player }
        DungeonManager.StartDungeon(partyMembers, typeof(param1) == "string" and param1 or "Normal")
    elseif action == "Leave" then
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
        if hrp then
            hrp.CFrame = CFrame.new(0, 4, 0)
        end
    end
end)

return DungeonManager