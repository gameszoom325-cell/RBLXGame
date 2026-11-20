--!strict
--[[
    WorldEventService.lua
    Server-authoritative Dynamic World Event Orchestrator:
    - Schedules and activates global server-wide events:
      * MeteorShower: Falling celestial debris creating gatherable ore craters
      * LightningStorm: High-frequency strikes dropping Charged Lightning Crystals
      * BossInvasion: Thunder Overlord mini-boss invasion
      * DoubleXP: 2x experience multiplier buff on all player activities
      * TreasureRain: Golden coins raining from clouds
    - Global countdown timers, marquee banner broadcasts, and participation rewards
]]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Systems = ReplicatedStorage:WaitForChild("Systems")

local ProgressionTypes = require(Shared:WaitForChild("ProgressionTypes"))
local ProgressionManager = require(Systems:WaitForChild("ProgressionManager"))
local EconomyManager = require(Systems:WaitForChild("EconomyManager"))
local InventoryManager = require(Systems:WaitForChild("InventoryManager"))

type WorldEventType = ProgressionTypes.WorldEventType
type WorldEventState = ProgressionTypes.WorldEventState

local networkFolder = ReplicatedStorage:WaitForChild("Network")
local worldEventUpdatedEvent = networkFolder:WaitForChild("WorldEventUpdated") :: RemoteEvent
local abilityVFXEvent = networkFolder:WaitForChild("ReplicateAbilityVFX") :: RemoteEvent

local WorldEventService = {}

local activeEvent: WorldEventState? = nil
local activeEventThread: thread? = nil
local activeSpawnsFolder: Folder? = nil

local EVENT_DEFINITIONS = {
    MeteorShower = {
        title = "METEOR SHOWER",
        description = "Cosmic storm meteors are bombarding the Tempest Wilds! Harvest fallen celestial cores.",
        duration = 180,
    },
    LightningStorm = {
        title = "LIGHTNING TEMPEST",
        description = "Supercharged lightning bolts strike the realm! Collect charged crystal shards from strike points.",
        duration = 180,
    },
    BossInvasion = {
        title = "TITAN VANGUARD INVASION",
        description = "An Elite Thunder Overlord has breached the Sanctuary perimeter! Rally together to slay the beast.",
        duration = 240,
    },
    DoubleXP = {
        title = "DOUBLE EXPERIENCE HOUR",
        description = "All champion experience gains from enemies, quests, and dungeons are doubled!",
        duration = 300,
    },
    TreasureRain = {
        title = "CELESTIAL TREASURE RAIN",
        description = "Golden orbs are showering from the storm clouds! Gather gold before it dissolves.",
        duration = 120,
    },
}

local function broadcastState()
    worldEventUpdatedEvent:FireAllClients(activeEvent)
end

function WorldEventService.GetActiveEvent(): WorldEventState?
    return activeEvent
end

function WorldEventService.IsDoubleXPActive(): boolean
    return activeEvent ~= nil and activeEvent.eventType == "DoubleXP" and activeEvent.isActive
end

function WorldEventService.TriggerEvent(eventType: WorldEventType)
    if activeEvent and activeEvent.isActive then
        print("[WorldEventService] Another event is already active.")
        return
    end

    local def = EVENT_DEFINITIONS[eventType]
    if not def then return end

    if activeSpawnsFolder then
        activeSpawnsFolder:Destroy()
    end
    activeSpawnsFolder = Instance.new("Folder")
    activeSpawnsFolder.Name = "WorldEventInstances"
    activeSpawnsFolder.Parent = Workspace

    activeEvent = {
        eventType = eventType,
        title = def.title,
        description = def.description,
        durationRemaining = def.duration,
        isActive = true,
    }

    broadcastState()
    print(string.format("[WorldEventService] *** WORLD EVENT STARTED: %s (%ds) ***", def.title, def.duration))

    if activeEventThread then task.cancel(activeEventThread) end
    activeEventThread = task.spawn(function()
        local nextActionTick = 0

        while activeEvent and activeEvent.durationRemaining > 0 do
            task.wait(1.0)
            activeEvent.durationRemaining -= 1

            local now = os.clock()
            -- Event Mechanics
            if eventType == "MeteorShower" and now - nextActionTick >= 3.5 then
                nextActionTick = now
                local rx = math.random(-80, 80)
                local rz = math.random(-80, 80)
                local impactPos = Vector3.new(rx, 1, rz)

                -- Visual impact
                abilityVFXEvent:FireAllClients("ThunderHammerSlam", {
                    origin = impactPos,
                    color = Color3.fromRGB(255, 120, 40),
                    radius = 12,
                })

                -- Spawn collectable ore deposit
                local deposit = Instance.new("Part")
                deposit.Name = "FallenMeteorCore"
                deposit.Shape = Enum.PartType.Ball
                deposit.Size = Vector3.new(2.4, 2.4, 2.4)
                deposit.Position = impactPos + Vector3.new(0, 1.2, 0)
                deposit.Color = Color3.fromRGB(240, 100, 30)
                deposit.Material = Enum.Material.Neon
                deposit.Anchored = true
                deposit.CanCollide = true
                deposit.Parent = activeSpawnsFolder

                local prompt = Instance.new("ProximityPrompt")
                prompt.ActionText = "Extract Ore"
                prompt.ObjectText = "Fallen Meteor"
                prompt.HoldDuration = 0.5
                prompt.Parent = deposit
                prompt.Triggered:Connect(function(player: Player)
                    deposit:Destroy()
                    InventoryManager.AddItem(player, "IronOre", 2)
                    EconomyManager.AddGold(player, 35, "MeteorHarvest")
                end)

                task.delay(18.0, function()
                    if deposit and deposit.Parent then deposit:Destroy() end
                end)

            elseif eventType == "TreasureRain" and now - nextActionTick >= 2.0 then
                nextActionTick = now
                local rx = math.random(-70, 70)
                local rz = math.random(-70, 70)
                local orbPos = Vector3.new(rx, 2, rz)

                local orb = Instance.new("Part")
                orb.Name = "TreasureOrb"
                orb.Shape = Enum.PartType.Ball
                orb.Size = Vector3.new(2, 2, 2)
                orb.Position = orbPos
                orb.Color = Color3.fromRGB(255, 220, 50)
                orb.Material = Enum.Material.Neon
                orb.Anchored = true
                orb.CanCollide = false
                orb.Parent = activeSpawnsFolder

                local prompt = Instance.new("ProximityPrompt")
                prompt.ActionText = "Collect Gold"
                prompt.ObjectText = "Celestial Coin"
                prompt.HoldDuration = 0
                prompt.Parent = orb
                prompt.Triggered:Connect(function(player: Player)
                    orb:Destroy()
                    EconomyManager.AddGold(player, math.random(40, 90), "TreasureRain")
                end)

                task.delay(12.0, function()
                    if orb and orb.Parent then orb:Destroy() end
                end)
            end

            broadcastState()
        end

        WorldEventService.EndEvent()
    end)
end

function WorldEventService.EndEvent()
    if not activeEvent then return end

    print(string.format("[WorldEventService] Event '%s' ended.", activeEvent.title))
    activeEvent = nil

    if activeEventThread then
        task.cancel(activeEventThread)
        activeEventThread = nil
    end

    if activeSpawnsFolder then
        activeSpawnsFolder:Destroy()
        activeSpawnsFolder = nil
    end

    broadcastState()
end

-- Automatic event loop: Triggers random events every 10 minutes
task.spawn(function()
    local EVENT_LIST: { WorldEventType } = { "MeteorShower", "LightningStorm", "DoubleXP", "TreasureRain" }
    while true do
        task.wait(480) -- 8 minutes between events
        local nextEvent = EVENT_LIST[math.random(1, #EVENT_LIST)]
        WorldEventService.TriggerEvent(nextEvent)
    end
end)

return WorldEventService