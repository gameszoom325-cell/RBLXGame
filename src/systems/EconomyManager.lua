--!strict
--[[
    EconomyManager.lua
    Server-authoritative Gold Currency System:
    - Provides safe AddGold, SpendGold, CanAfford, and GetGold APIs
    - Guarantees zero client exploitability for currency mutations
    - Logs transactions and syncs with player attributes and DataStore
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Systems = ReplicatedStorage:WaitForChild("Systems")
local PlayerDataService = require(Systems:WaitForChild("PlayerDataService"))

local EconomyManager = {}

function EconomyManager.GetGold(player: Player): number
    local data = PlayerDataService.GetPlayerData(player)
    return if data then data.Gold else 0
end

function EconomyManager.CanAfford(player: Player, amount: number): boolean
    if amount <= 0 then return true end
    return EconomyManager.GetGold(player) >= amount
end

function EconomyManager.AddGold(player: Player, amount: number, source: string?): number
    if amount <= 0 then return EconomyManager.GetGold(player) end

    local newGold = 0
    PlayerDataService.UpdatePlayerData(player, function(data)
        data.Gold = math.clamp(data.Gold + amount, 0, 999999999)
        newGold = data.Gold
    end)

    player:SetAttribute("Gold", newGold)
    print(string.format("[EconomyManager] %s gained +%d Gold from %s (Total: %d)", player.Name, amount, source or "Action", newGold))
    return newGold
end

function EconomyManager.SpendGold(player: Player, amount: number, reason: string?): boolean
    if amount < 0 then return false end
    if amount == 0 then return true end

    local currentGold = EconomyManager.GetGold(player)
    if currentGold < amount then
        warn(string.format("[EconomyManager] %s cannot afford %d Gold (Balance: %d) for %s", player.Name, amount, currentGold, reason or "Transaction"))
        return false
    end

    local success = false
    local newGold = currentGold
    PlayerDataService.UpdatePlayerData(player, function(data)
        if data.Gold >= amount then
            data.Gold -= amount
            newGold = data.Gold
            success = true
        end
    end)

    if success then
        player:SetAttribute("Gold", newGold)
        print(string.format("[EconomyManager] %s spent %d Gold on %s (Remaining: %d)", player.Name, amount, reason or "Transaction", newGold))
    end

    return success
end

-- Initialize attribute on join
local function onPlayerAdded(player: Player)
    task.spawn(function()
        local gold = EconomyManager.GetGold(player)
        player:SetAttribute("Gold", gold)
    end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
    task.spawn(onPlayerAdded, p)
end

return EconomyManager