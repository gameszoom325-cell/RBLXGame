--!strict
--[[
    QuestManager.lua
    Server-authoritative Quest & Objective Tracking System:
    Handles quest assignment, progress tracking for kills and ability usage,
    and distributing gold and experience rewards.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type QuestDefinition = {
    id: string,
    title: string,
    description: string,
    giver: string,
    objectiveType: "KillEnemy" | "CastAbility" | "VisitZone",
    targetCount: number,
    rewards: { xp: number, gold: number },
}

export type PlayerQuestProgress = {
    id: string,
    currentCount: number,
    targetCount: number,
    isCompleted: boolean,
    isClaimed: boolean,
}

local QuestManager = {}

local Quests: { [string]: QuestDefinition } = {
    Q_TRIAL_LIGHTNING = {
        id = "Q_TRIAL_LIGHTNING",
        title = "Trial of the Lightning Warrior",
        description = "Channel your storm abilities 5 times to master the electrical flow.",
        giver = "Archivist Orin",
        objectiveType = "CastAbility",
        targetCount = 5,
        rewards = { xp = 150, gold = 75 },
    },

    Q_TEMPEST_DRONES = {
        id = "Q_TEMPEST_DRONES",
        title = "Purge the Tempest Wilds",
        description = "Enter the Tempest Wilds via the portal and destroy 3 rogue Tempest Drones.",
        giver = "Instructor Kael",
        objectiveType = "KillEnemy",
        targetCount = 3,
        rewards = { xp = 300, gold = 150 },
    },
}

-- Player states: [UserId][QuestId] = PlayerQuestProgress
local playerQuests: { [number]: { [string]: PlayerQuestProgress } } = {}
local playerStats: { [number]: { gold: number, xp: number, level: number } } = {}

-- Ensure Network Remotes exist
local networkFolder = ReplicatedStorage:WaitForChild("Network")

local function getOrCreateRemoteEvent(name: string): RemoteEvent
    local ev = networkFolder:FindFirstChild(name) :: RemoteEvent
    if not ev then
        ev = Instance.new("RemoteEvent")
        ev.Name = name
        ev.Parent = networkFolder
    end
    return ev
end

local questUpdatedEvent = getOrCreateRemoteEvent("QuestUpdated")
local rewardClaimedEvent = getOrCreateRemoteEvent("RewardClaimed")

local function initPlayer(player: Player)
    local userId = player.UserId
    playerQuests[userId] = playerQuests[userId] or {}
    playerStats[userId] = playerStats[userId] or { gold = 0, xp = 0, level = 1 }

    -- Auto-assign introductory quest
    QuestManager.AcceptQuest(player, "Q_TRIAL_LIGHTNING")
    QuestManager.AcceptQuest(player, "Q_TEMPEST_DRONES")
end

function QuestManager.AcceptQuest(player: Player, questId: string): boolean
    local def = Quests[questId]
    if not def then return false end

    local userId = player.UserId
    playerQuests[userId] = playerQuests[userId] or {}

    if playerQuests[userId][questId] then
        return false -- Already accepted
    end

    playerQuests[userId][questId] = {
        id = questId,
        currentCount = 0,
        targetCount = def.targetCount,
        isCompleted = false,
        isClaimed = false,
    }

    questUpdatedEvent:FireClient(player, questId, def.title, 0, def.targetCount, false)
    print(string.format("[QuestManager] Player %s accepted quest '%s'", player.Name, def.title))
    return true
end

function QuestManager.ProgressObjective(player: Player, objectiveType: string, amount: number)
    local userId = player.UserId
    local userQuests = playerQuests[userId]
    if not userQuests then return end

    for questId, progress in pairs(userQuests) do
        local def = Quests[questId]
        if def and def.objectiveType == objectiveType and not progress.isCompleted then
            progress.currentCount = math.clamp(progress.currentCount + amount, 0, progress.targetCount)
            if progress.currentCount >= progress.targetCount then
                progress.isCompleted = true
                print(string.format("[QuestManager] Player %s completed objective for '%s'!", player.Name, def.title))
            end
            questUpdatedEvent:FireClient(player, questId, def.title, progress.currentCount, progress.targetCount, progress.isCompleted)
        end
    end
end

function QuestManager.ClaimReward(player: Player, questId: string): boolean
    local userId = player.UserId
    local userQuests = playerQuests[userId]
    if not userQuests or not userQuests[questId] then return false end

    local progress = userQuests[questId]
    local def = Quests[questId]
    if not progress.isCompleted or progress.isClaimed or not def then return false end

    progress.isClaimed = true
    local stats = playerStats[userId]
    stats.gold += def.rewards.gold
    stats.xp += def.rewards.xp

    -- Level calculation
    if stats.xp >= (stats.level * 200) then
        stats.level += 1
        print(string.format("[QuestManager] %s leveled up to Level %d!", player.Name, stats.level))
    end

    player:SetAttribute("Gold", stats.gold)
    player:SetAttribute("XP", stats.xp)
    player:SetAttribute("Level", stats.level)

    rewardClaimedEvent:FireClient(player, def.title, def.rewards.gold, def.rewards.xp, stats.level)
    print(string.format("[QuestManager] Player %s claimed rewards for '%s' (+%d Gold, +%d XP)", player.Name, def.title, def.rewards.gold, def.rewards.xp))
    return true
end

Players.PlayerAdded:Connect(initPlayer)
for _, p in ipairs(Players:GetPlayers()) do
    task.spawn(initPlayer, p)
end

Players.PlayerRemoving:Connect(function(player)
    playerQuests[player.UserId] = nil
    playerStats[player.UserId] = nil
end)

return QuestManager
