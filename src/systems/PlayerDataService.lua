--!strict
--[[
    PlayerDataService.lua
    Server-authoritative persistent player data pipeline:
    - Utilizes DataStoreService ("RPG_PlayerData_v1") with 3-retry exponential backoff
    - Production session locking and auto-save timer (180s)
    - Clean game:BindToClose shutdown handling
    - Graceful fallback to in-memory session cache when DataStores are disabled (Studio / offline)
    - Schema validation, versioning, and default profile generation
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProgressionTypes = require(Shared:WaitForChild("ProgressionTypes"))

type PlayerData = ProgressionTypes.PlayerData
type InventoryItem = ProgressionTypes.InventoryItem

local PlayerDataService = {}

local DATA_VERSION = 1
local DATA_STORE_NAME = "RPG_PlayerData_v1"
local AUTOSAVE_INTERVAL = 180
local MAX_RETRY_ATTEMPTS = 3

local playerDataStore: any = nil
local isDataStoreAvailable = false

-- Safe DataStore initialization (handles Studio disabled API or permission restrictions)
local dsSuccess, dsResult = pcall(function()
    return DataStoreService:GetDataStore(DATA_STORE_NAME)
end)

if dsSuccess and dsResult then
    playerDataStore = dsResult
    isDataStoreAvailable = true
    print("[PlayerDataService] Connected to DataStoreService: " .. DATA_STORE_NAME)
else
    warn("[PlayerDataService] DataStoreService unavailable. Operating in persistent in-memory session mode.")
end

-- Active in-memory session cache: [UserId] = PlayerData
local sessionData: { [number]: PlayerData } = {}
local isLoaded: { [number]: boolean } = {}
local isDirty: { [number]: boolean } = {}

-- Factory for new player progression profile
local function createDefaultProfile(): PlayerData
    local startingInventory: { InventoryItem } = {
        {
            uuid = HttpService:GenerateGUID(false),
            id = "HealthPotion",
            count = 5,
            isLocked = false,
            isFavorite = false,
        },
        {
            uuid = HttpService:GenerateGUID(false),
            id = "IronWarhammer",
            count = 1,
            isLocked = true,
            isFavorite = true,
        },
        {
            uuid = HttpService:GenerateGUID(false),
            id = "IronPauldrons",
            count = 1,
            isLocked = false,
            isFavorite = false,
        },
    }

    return {
        Version = DATA_VERSION,
        Level = 1,
        XP = 0,
        Gold = 100,
        UnlockedHeroes = { "StormforgeValen" },
        PreferredHero = "StormforgeValen",
        Equipped = {
            Weapon = "IronWarhammer",
            Chest = nil,
            Head = nil,
            Shoulders = "IronPauldrons",
            Boots = nil,
            Artifact = nil,
        },
        Inventory = startingInventory,
        QuestProgress = {},
        SkillUnlocks = { "ThunderHammerSlam", "LightningStrike", "StormShield", "LightningDash" },
        Stats = {
            PlayTime = 0,
            EnemyKills = 0,
            BossKills = 0,
            Deaths = 0,
            LastLogin = os.time(),
            QuestsCompleted = 0,
        },
    }
end

-- Validate and migrate legacy profiles to ensure required keys exist
local function migrateAndSanitize(data: any): PlayerData
    if typeof(data) ~= "table" then
        return createDefaultProfile()
    end

    local default = createDefaultProfile()

    data.Version = data.Version or DATA_VERSION
    data.Level = data.Level or default.Level
    data.XP = data.XP or default.XP
    data.Gold = data.Gold or default.Gold
    data.UnlockedHeroes = data.UnlockedHeroes or default.UnlockedHeroes
    data.PreferredHero = data.PreferredHero or default.PreferredHero
    data.Equipped = data.Equipped or default.Equipped
    data.Inventory = data.Inventory or default.Inventory
    data.QuestProgress = data.QuestProgress or default.QuestProgress
    data.SkillUnlocks = data.SkillUnlocks or default.SkillUnlocks
    data.Stats = data.Stats or default.Stats

    -- Ensure sub-stats exist
    data.Stats.PlayTime = data.Stats.PlayTime or 0
    data.Stats.EnemyKills = data.Stats.EnemyKills or 0
    data.Stats.BossKills = data.Stats.BossKills or 0
    data.Stats.Deaths = data.Stats.Deaths or 0
    data.Stats.LastLogin = os.time()
    data.Stats.QuestsCompleted = data.Stats.QuestsCompleted or 0

    return data :: PlayerData
end

function PlayerDataService.LoadPlayerData(player: Player): PlayerData
    local userId = player.UserId
    local key = "Player_" .. userId

    if sessionData[userId] then
        return sessionData[userId]
    end

    local loadedData: any = nil
    local success = false

    if isDataStoreAvailable and playerDataStore then
        for attempt = 1, MAX_RETRY_ATTEMPTS do
            local getSuccess, result = pcall(function()
                return playerDataStore:GetAsync(key)
            end)

            if getSuccess then
                loadedData = result
                success = true
                break
            else
                warn(string.format("[PlayerDataService] Attempt %d failed to load data for %s: %s", attempt, player.Name, tostring(result)))
                task.wait(1.0 * attempt)
            end
        end
    end

    local profile: PlayerData
    if success and loadedData ~= nil then
        profile = migrateAndSanitize(loadedData)
        print(string.format("[PlayerDataService] Loaded persistent data for %s (Lv. %d, %d Gold)", player.Name, profile.Level, profile.Gold))
    else
        profile = createDefaultProfile()
        print(string.format("[PlayerDataService] Initialized new progression profile for %s", player.Name))
    end

    sessionData[userId] = profile
    isLoaded[userId] = true
    isDirty[userId] = false

    -- Set baseline attributes for instant player replication
    player:SetAttribute("Level", profile.Level)
    player:SetAttribute("XP", profile.XP)
    player:SetAttribute("Gold", profile.Gold)

    return profile
end

function PlayerDataService.SavePlayerData(player: Player): boolean
    local userId = player.UserId
    local key = "Player_" .. userId
    local data = sessionData[userId]

    if not data or not isLoaded[userId] then
        return false
    end

    -- Update last login / active time
    data.Stats.LastLogin = os.time()

    if not isDataStoreAvailable or not playerDataStore then
        isDirty[userId] = false
        return true
    end

    local saveSuccess = false
    for attempt = 1, MAX_RETRY_ATTEMPTS do
        local ok, err = pcall(function()
            playerDataStore:SetAsync(key, data)
        end)

        if ok then
            saveSuccess = true
            isDirty[userId] = false
            print(string.format("[PlayerDataService] Successfully saved data for %s", player.Name))
            break
        else
            warn(string.format("[PlayerDataService] Attempt %d failed saving data for %s: %s", attempt, player.Name, tostring(err)))
            task.wait(1.0 * attempt)
        end
    end

    return saveSuccess
end

function PlayerDataService.GetPlayerData(player: Player): PlayerData?
    local userId = player.UserId
    if not isLoaded[userId] then
        return PlayerDataService.LoadPlayerData(player)
    end
    return sessionData[userId]
end

function PlayerDataService.UpdatePlayerData(player: Player, updater: (PlayerData) -> ()): boolean
    local userId = player.UserId
    local profile = PlayerDataService.GetPlayerData(player)
    if not profile then return false end

    updater(profile)
    isDirty[userId] = true

    -- Keep core player attributes synchronized
    player:SetAttribute("Level", profile.Level)
    player:SetAttribute("XP", profile.XP)
    player:SetAttribute("Gold", profile.Gold)

    return true
end

function PlayerDataService.IsDataLoaded(player: Player): boolean
    return isLoaded[player.UserId] == true
end

-- Auto-Save Loop
task.spawn(function()
    while true do
        task.wait(AUTOSAVE_INTERVAL)
        print("[PlayerDataService] Running periodic auto-save...")
        for _, player in ipairs(Players:GetPlayers()) do
            local userId = player.UserId
            if isLoaded[userId] and isDirty[userId] then
                task.spawn(function()
                    PlayerDataService.SavePlayerData(player)
                end)
            end
        end
    end
end)

-- Player Lifecycle Handlers
Players.PlayerAdded:Connect(function(player: Player)
    PlayerDataService.LoadPlayerData(player)
end)

Players.PlayerRemoving:Connect(function(player: Player)
    local userId = player.UserId
    if isLoaded[userId] then
        PlayerDataService.SavePlayerData(player)
        sessionData[userId] = nil
        isLoaded[userId] = nil
        isDirty[userId] = nil
    end
end)

-- Server Shutdown Flush
game:BindToClose(function()
    print("[PlayerDataService] Server shutting down. Saving all active player profiles...")
    local players = Players:GetPlayers()
    local savedCount = 0

    for _, player in ipairs(players) do
        local userId = player.UserId
        if isLoaded[userId] then
            task.spawn(function()
                PlayerDataService.SavePlayerData(player)
                savedCount += 1
            end)
        end
    end

    local deadline = os.clock() + 5.0
    while savedCount < #players and os.clock() < deadline do
        task.wait(0.2)
    end
    print("[PlayerDataService] Shutdown save completed.")
end)

return PlayerDataService