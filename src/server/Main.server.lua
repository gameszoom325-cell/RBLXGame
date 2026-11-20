--!strict
--[[
    Main.server.lua
    Server Entry Point for Roblox RPG
    Initializes core gameplay services, progression pipeline, economy, and world systems.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Systems = ReplicatedStorage:WaitForChild("Systems")

local function init()
    print("[Server] Bootstrapping RBLXGame RPG Systems...")

    -- Authoritative progression and persistence pipeline
    local PlayerDataService = require(Systems:WaitForChild("PlayerDataService"))
    local ProgressionManager = require(Systems:WaitForChild("ProgressionManager"))
    local EconomyManager = require(Systems:WaitForChild("EconomyManager"))
    local InventoryManager = require(Systems:WaitForChild("InventoryManager"))
    local ShopManager = require(Systems:WaitForChild("ShopManager"))
    local QuestManager = require(Systems:WaitForChild("QuestManager"))
    local EnemyManager = require(Systems:WaitForChild("EnemyManager"))

    -- Phase 8: Multiplayer, Boss, Dungeon, World Events, and Achievements
    local PartyService = require(Systems:WaitForChild("PartyService"))
    local BossManager = require(Systems:WaitForChild("BossManager"))
    local DungeonManager = require(Systems:WaitForChild("DungeonManager"))
    local WorldEventService = require(Systems:WaitForChild("WorldEventService"))
    local AchievementManager = require(Systems:WaitForChild("AchievementManager"))

    print("[Server] All RPG Progression Systems, Inventory, Economy, Parties, Dungeons, and Bosses initialized successfully.")
end

init()
