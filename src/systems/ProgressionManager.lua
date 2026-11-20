--!strict
--[[
    ProgressionManager.lua
    Server-authoritative Experience and Level Progression System:
    - Precise scaling curve: Lv1=100, Lv2=175, Lv3=275, Lv4=400, Lv5=550...
    - Per-level stat bonuses: +25 MaxHealth, +5 Attack, +3 Defense
    - Handles level up event notification, visual fanfare, and dynamic character stat re-computation
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Systems = ReplicatedStorage:WaitForChild("Systems")
local PlayerDataService = require(Systems:WaitForChild("PlayerDataService"))

local networkFolder = ReplicatedStorage:WaitForChild("Network")
local levelUpEvent = networkFolder:WaitForChild("LevelUpEvent") :: RemoteEvent

local ProgressionManager = {}

-- Mathematical formula for required XP per level
function ProgressionManager.GetRequiredXP(level: number): number
    if level <= 1 then
        return 100
    end
    local prev = level - 1
    return 100 + (50 * prev) + math.floor((25 * prev * level) / 2)
end

-- Baseline stat bonuses contributed exclusively by player level
function ProgressionManager.GetLevelStatBonus(level: number)
    local bonusLevels = math.max(0, level - 1)
    return {
        healthBonus = bonusLevels * 25,
        attackBonus = bonusLevels * 5,
        defenseBonus = bonusLevels * 3,
    }
end

function ProgressionManager.AddXP(player: Player, amount: number, source: string?)
    if amount <= 0 then return end

    -- Check for World Event Double XP buff
    local worldEventModule = Systems:FindFirstChild("WorldEventService")
    local effectiveAmount = amount
    if worldEventModule then
        local WorldEventService = require(worldEventModule) :: any
        if WorldEventService.IsDoubleXPActive and WorldEventService.IsDoubleXPActive() then
            effectiveAmount = amount * 2
        end
    end

    local data = PlayerDataService.GetPlayerData(player)
    if not data then return end

    local currentLevel = data.Level
    local currentXP = data.XP + effectiveAmount
    local leveledUp = false
    local startLevel = currentLevel

    local requiredXP = ProgressionManager.GetRequiredXP(currentLevel)
    while currentXP >= requiredXP do
        currentXP -= requiredXP
        currentLevel += 1
        leveledUp = true
        requiredXP = ProgressionManager.GetRequiredXP(currentLevel)
    end

    data.Level = currentLevel
    data.XP = currentXP

    -- Update attributes for immediate replication
    player:SetAttribute("Level", currentLevel)
    player:SetAttribute("XP", currentXP)
    player:SetAttribute("RequiredXP", requiredXP)

    print(string.format("[ProgressionManager] %s gained +%d XP from %s (Level %d, %d/%d XP)",
        player.Name, amount, source or "Action", currentLevel, currentXP, requiredXP))

    if leveledUp then
        local levelsGained = currentLevel - startLevel
        local statsGained = {
            levels = levelsGained,
            health = levelsGained * 25,
            attack = levelsGained * 5,
            defense = levelsGained * 3,
        }

        print(string.format("[ProgressionManager] *** LEVEL UP! *** %s reached Level %d (+%d HP, +%d ATK, +%d DEF)",
            player.Name, currentLevel, statsGained.health, statsGained.attack, statsGained.defense))

        -- Fire client event for celebratory banner, sound effects, and fanfare
        levelUpEvent:FireClient(player, currentLevel, statsGained)

        -- Refresh character attributes and humanoid health
        task.spawn(function()
            local invModule = Systems:FindFirstChild("InventoryManager")
            if invModule then
                local InventoryManager = require(invModule) :: any
                if InventoryManager.ApplyStatsToCharacter then
                    InventoryManager.ApplyStatsToCharacter(player)
                end
            end

            local achModule = Systems:FindFirstChild("AchievementManager")
            if achModule then
                local AchievementManager = require(achModule) :: any
                if AchievementManager.CheckStatMilestones then
                    AchievementManager.CheckStatMilestones(player)
                end
            end
        end)
    end
end

function ProgressionManager.GetLevel(player: Player): number
    local data = PlayerDataService.GetPlayerData(player)
    return if data then data.Level else 1
end

function ProgressionManager.GetXP(player: Player): (number, number)
    local data = PlayerDataService.GetPlayerData(player)
    local level = if data then data.Level else 1
    local xp = if data then data.XP else 0
    return xp, ProgressionManager.GetRequiredXP(level)
end

-- Initialize attributes when player joins
local function onPlayerAdded(player: Player)
    task.spawn(function()
        local data = PlayerDataService.GetPlayerData(player)
        if data then
            player:SetAttribute("Level", data.Level)
            player:SetAttribute("XP", data.XP)
            player:SetAttribute("RequiredXP", ProgressionManager.GetRequiredXP(data.Level))
        end
    end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
    task.spawn(onPlayerAdded, p)
end

return ProgressionManager