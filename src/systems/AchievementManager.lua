--!strict
--[[
    AchievementManager.lua
    Server-authoritative Persistent Achievement Pipeline:
    - Tracks and persists unlocked achievements in PlayerData
    - Awards XP, Gold, and exclusive Titles upon completion
    - Broadcasts AchievementUnlocked event for animated client banners
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Systems = ReplicatedStorage:WaitForChild("Systems")

local ProgressionTypes = require(Shared:WaitForChild("ProgressionTypes"))
local PlayerDataService = require(Systems:WaitForChild("PlayerDataService"))
local ProgressionManager = require(Systems:WaitForChild("ProgressionManager"))
local EconomyManager = require(Systems:WaitForChild("EconomyManager"))

type AchievementSpec = ProgressionTypes.AchievementSpec

local networkFolder = ReplicatedStorage:WaitForChild("Network")
local achievementUnlockedEvent = networkFolder:WaitForChild("AchievementUnlocked") :: RemoteEvent

local AchievementManager = {}

local ACHIEVEMENTS: { [string]: AchievementSpec } = {
    FirstBlood = {
        id = "FirstBlood",
        title = "First Blood",
        description = "Slay your very first rogue enemy in the Storm World.",
        xpReward = 50,
        goldReward = 50,
        titleReward = "Storm Initiate",
    },

    StormHunter = {
        id = "StormHunter",
        title = "Storm Hunter",
        description = "Defeat 25 enemies roaming the Tempest Wilds.",
        xpReward = 250,
        goldReward = 150,
        titleReward = "Wilds Tracker",
    },

    Level10 = {
        id = "Level10",
        title = "Ascendant Champion",
        description = "Achieve Hero Progression Level 10.",
        xpReward = 500,
        goldReward = 300,
        titleReward = "Thunder Champion",
    },

    BossSlayer = {
        id = "BossSlayer",
        title = "Titan Slayer",
        description = "Slay the colossal Storm Titan in combat.",
        xpReward = 1000,
        goldReward = 500,
        titleReward = "Titan Slayer",
    },

    DungeonMaster = {
        id = "DungeonMaster",
        title = "Dungeon Master",
        description = "Conquer the Temple of the Storm Sovereign dungeon.",
        xpReward = 1500,
        goldReward = 750,
        titleReward = "Conqueror of the Tempest",
    },

    LegendaryDrop = {
        id = "LegendaryDrop",
        title = "Legendary Relic",
        description = "Acquire a Legendary item or crafting component.",
        xpReward = 500,
        goldReward = 500,
        titleReward = "Fortune Seeker",
    },

    Centurion = {
        id = "Centurion",
        title = "Centurion of the Tempest",
        description = "Obliterate 100 hostiles across all zones.",
        xpReward = 1000,
        goldReward = 1000,
        titleReward = "Centurion",
    },
}

function AchievementManager.Unlock(player: Player, achievementId: string): boolean
    local def = ACHIEVEMENTS[achievementId]
    if not def then return false end

    local data = PlayerDataService.GetPlayerData(player)
    if not data then return false end

    data.Achievements = data.Achievements or {}
    if table.find(data.Achievements, achievementId) then
        return false -- Already unlocked
    end

    table.insert(data.Achievements, achievementId)

    if def.titleReward then
        data.Titles = data.Titles or {}
        if not table.find(data.Titles, def.titleReward) then
            table.insert(data.Titles, def.titleReward)
        end
    end

    -- Distribute authoritative rewards
    ProgressionManager.AddXP(player, def.xpReward, "Achievement:" .. def.title)
    EconomyManager.AddGold(player, def.goldReward, "Achievement:" .. def.title)

    achievementUnlockedEvent:FireClient(player, def)
    print(string.format("[AchievementManager] *** %s unlocked [%s]! (+%d XP, +%d Gold) ***",
        player.Name, def.title, def.xpReward, def.goldReward))
    return true
end

function AchievementManager.CheckStatMilestones(player: Player)
    local data = PlayerDataService.GetPlayerData(player)
    if not data then return end

    local kills = data.Stats.EnemyKills or 0
    local level = data.Level or 1

    if kills >= 1 then
        AchievementManager.Unlock(player, "FirstBlood")
    end
    if kills >= 25 then
        AchievementManager.Unlock(player, "StormHunter")
    end
    if kills >= 100 then
        AchievementManager.Unlock(player, "Centurion")
    end
    if level >= 10 then
        AchievementManager.Unlock(player, "Level10")
    end
end

return AchievementManager