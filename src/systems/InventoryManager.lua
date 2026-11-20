--!strict
--[[
    InventoryManager.lua
    Server-authoritative Inventory, Equipment, and Dynamic Stat Computation Pipeline:
    - Enforces 6 item categories: Weapon, Armor, Artifact, Consumable, QuestItem, Material
    - Handles stacking, locking, favoriting, equipping, unequipping, using, and dropping
    - Dynamically calculates derived character stats (Base + Level Bonuses + Equipped Gear Stats)
    - Applies MaxHealth, WalkSpeed, and combat attributes to Humanoid and character
    - Synchronizes state via InventoryAction and InventoryUpdated remotes
]]

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Systems = ReplicatedStorage:WaitForChild("Systems")

local ProgressionTypes = require(Shared:WaitForChild("ProgressionTypes"))
local ItemDatabase = require(Shared:WaitForChild("ItemDatabase"))
local PlayerDataService = require(Systems:WaitForChild("PlayerDataService"))
local ProgressionManager = require(Systems:WaitForChild("ProgressionManager"))

type InventoryItem = ProgressionTypes.InventoryItem
type EquippedGear = ProgressionTypes.EquippedGear
type EquipSlot = ProgressionTypes.EquipSlot

local networkFolder = ReplicatedStorage:WaitForChild("Network")
local inventoryActionEvent = networkFolder:WaitForChild("InventoryAction") :: RemoteEvent
local inventoryUpdatedEvent = networkFolder:WaitForChild("InventoryUpdated") :: RemoteEvent
local playerStatsUpdatedEvent = networkFolder:WaitForChild("PlayerStatsUpdated") :: RemoteEvent

local InventoryManager = {}

-- =============================================================================
-- INVENTORY MANIPULATION
-- =============================================================================

function InventoryManager.SyncClient(player: Player)
    local data = PlayerDataService.GetPlayerData(player)
    if not data then return end
    inventoryUpdatedEvent:FireClient(player, data.Inventory, data.Equipped)
end

function InventoryManager.AddItem(player: Player, itemId: string, count: number): boolean
    if count <= 0 then return false end
    local def = ItemDatabase.GetItem(itemId)
    if not def then
        warn("[InventoryManager] Attempted to add invalid item ID: " .. tostring(itemId))
        return false
    end

    local success = false
    PlayerDataService.UpdatePlayerData(player, function(data)
        -- Check if stackable and existing stack has capacity
        if def.maxStack > 1 then
            for _, item in ipairs(data.Inventory) do
                if item.id == itemId and item.count < def.maxStack then
                    local space = def.maxStack - item.count
                    local addCount = math.min(space, count)
                    item.count += addCount
                    count -= addCount
                    if count <= 0 then
                        success = true
                        return
                    end
                end
            end
        end

        -- Add new stacks for remaining count
        while count > 0 do
            local stackCount = math.min(def.maxStack, count)
            table.insert(data.Inventory, {
                uuid = HttpService:GenerateGUID(false),
                id = itemId,
                count = stackCount,
                isLocked = false,
                isFavorite = false,
            })
            count -= stackCount
        end
        success = true
    end)

    if success then
        InventoryManager.SyncClient(player)
        print(string.format("[InventoryManager] %s acquired [%s] (x%d)", player.Name, def.name, count))
    end

    return success
end

function InventoryManager.RemoveItemByUUID(player: Player, uuid: string, count: number): boolean
    local success = false
    PlayerDataService.UpdatePlayerData(player, function(data)
        for i, item in ipairs(data.Inventory) do
            if item.uuid == uuid then
                if item.count > count then
                    item.count -= count
                    success = true
                else
                    table.remove(data.Inventory, i)
                    success = true
                end
                break
            end
        end
    end)

    if success then
        InventoryManager.SyncClient(player)
    end
    return success
end

function InventoryManager.RemoveItemById(player: Player, itemId: string, count: number): boolean
    local success = false
    PlayerDataService.UpdatePlayerData(player, function(data)
        local remaining = count
        local i = #data.Inventory
        while i >= 1 and remaining > 0 do
            local item = data.Inventory[i]
            if item.id == itemId then
                if item.count > remaining then
                    item.count -= remaining
                    remaining = 0
                else
                    remaining -= item.count
                    table.remove(data.Inventory, i)
                end
            end
            i -= 1
        end
        success = (remaining == 0)
    end)

    if success then
        InventoryManager.SyncClient(player)
    end
    return success
end

function InventoryManager.ToggleLock(player: Player, uuid: string)
    PlayerDataService.UpdatePlayerData(player, function(data)
        for _, item in ipairs(data.Inventory) do
            if item.uuid == uuid then
                item.isLocked = not item.isLocked
                break
            end
        end
    end)
    InventoryManager.SyncClient(player)
end

function InventoryManager.ToggleFavorite(player: Player, uuid: string)
    PlayerDataService.UpdatePlayerData(player, function(data)
        for _, item in ipairs(data.Inventory) do
            if item.uuid == uuid then
                item.isFavorite = not item.isFavorite
                break
            end
        end
    end)
    InventoryManager.SyncClient(player)
end

function InventoryManager.SortInventory(player: Player, sortType: string?)
    PlayerDataService.UpdatePlayerData(player, function(data)
        table.sort(data.Inventory, function(a, b)
            local defA = ItemDatabase.GetItem(a.id)
            local defB = ItemDatabase.GetItem(b.id)
            if not defA or not defB then return false end

            if a.isFavorite ~= b.isFavorite then
                return a.isFavorite
            end

            if sortType == "Rarity" then
                local rarityOrder = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5 }
                local rA = rarityOrder[defA.rarity] or 1
                local rB = rarityOrder[defB.rarity] or 1
                if rA ~= rB then return rA > rB end
            elseif sortType == "Value" then
                if defA.sellPrice ~= defB.sellPrice then
                    return defA.sellPrice > defB.sellPrice
                end
            end

            -- Default fallback: sort by Category then Name
            if defA.category ~= defB.category then
                return defA.category < defB.category
            end
            return defA.name < defB.name
        end)
    end)
    InventoryManager.SyncClient(player)
end

-- =============================================================================
-- EQUIPMENT & STAT COMPUTATION
-- =============================================================================

function InventoryManager.EquipItem(player: Player, uuid: string): boolean
    local data = PlayerDataService.GetPlayerData(player)
    if not data then return false end

    local targetItem: InventoryItem? = nil
    for _, item in ipairs(data.Inventory) do
        if item.uuid == uuid then
            targetItem = item
            break
        end
    end

    if not targetItem then return false end
    local def = ItemDatabase.GetItem(targetItem.id)
    if not def or not def.slot then return false end

    local slot = def.slot :: EquipSlot
    local previousEquippedId = (data.Equipped :: any)[slot]

    PlayerDataService.UpdatePlayerData(player, function(pData)
        (pData.Equipped :: any)[slot] = def.id
    end)

    -- If previous gear was equipped, it remains in inventory or was replaced
    InventoryManager.ApplyStatsToCharacter(player)
    InventoryManager.SyncClient(player)
    print(string.format("[InventoryManager] %s equipped [%s] in slot %s", player.Name, def.name, slot))
    return true
end

function InventoryManager.UnequipSlot(player: Player, slot: string): boolean
    local data = PlayerDataService.GetPlayerData(player)
    if not data then return false end

    local currentEquippedId = (data.Equipped :: any)[slot]
    if not currentEquippedId then return false end

    PlayerDataService.UpdatePlayerData(player, function(pData)
        (pData.Equipped :: any)[slot] = nil
    end)

    InventoryManager.ApplyStatsToCharacter(player)
    InventoryManager.SyncClient(player)
    print(string.format("[InventoryManager] %s unequipped slot %s", player.Name, slot))
    return true
end

function InventoryManager.UseConsumable(player: Player, uuid: string): boolean
    local data = PlayerDataService.GetPlayerData(player)
    if not data then return false end

    local targetItem: InventoryItem? = nil
    for _, item in ipairs(data.Inventory) do
        if item.uuid == uuid then
            targetItem = item
            break
        end
    end

    if not targetItem then return false end
    local def = ItemDatabase.GetItem(targetItem.id)
    if not def or not def.usableEffect then return false end

    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end

    local effectParts = string.split(def.usableEffect, ":")
    local effectType = effectParts[1]

    if effectType == "Heal" then
        local amount = tonumber(effectParts[2]) or 50
        humanoid.Health = math.clamp(humanoid.Health + amount, 0, humanoid.MaxHealth)

        -- Fire healing damage number (Green)
        local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
        if root then
            local dmgDealtRemote = networkFolder:FindFirstChild("DamageDealt") :: RemoteEvent?
            if dmgDealtRemote then
                dmgDealtRemote:FireAllClients(amount, root.Position + Vector3.new(0, 2, 0), "Healing")
            end
        end
    elseif effectType == "Speed" then
        local bonusSpeed = tonumber(effectParts[2]) or 8
        local duration = tonumber(effectParts[3]) or 15
        local baseSpeed = character:GetAttribute("BaseWalkSpeed") or 16
        humanoid.WalkSpeed = baseSpeed + bonusSpeed
        task.delay(duration, function()
            if humanoid and humanoid.Parent then
                InventoryManager.ApplyStatsToCharacter(player)
            end
        end)
    elseif effectType == "LightningBuff" then
        local bonus = tonumber(effectParts[2]) or 25
        local duration = tonumber(effectParts[3]) or 20
        local currentBonus = character:GetAttribute("BonusLightningDamage") or 0
        character:SetAttribute("BonusLightningDamage", currentBonus + bonus)
        task.delay(duration, function()
            if character and character.Parent then
                InventoryManager.ApplyStatsToCharacter(player)
            end
        end)
    end

    InventoryManager.RemoveItemByUUID(player, uuid, 1)
    print(string.format("[InventoryManager] %s used consumable [%s] (%s)", player.Name, def.name, def.usableEffect))
    return true
end

-- Full stat computation: Base + Level bonuses + Equipped gear stats
function InventoryManager.GetComputedStats(player: Player)
    local data = PlayerDataService.GetPlayerData(player)
    local level = if data then data.Level else 1
    local lvlBonus = ProgressionManager.GetLevelStatBonus(level)

    local computed = {
        Level = level,
        MaxHealth = 200 + lvlBonus.healthBonus,
        AttackPower = 25 + lvlBonus.attackBonus,
        Defense = 10 + lvlBonus.defenseBonus,
        WalkSpeed = 16,
        CritChance = 0.05,       -- 5% base
        CritDamage = 1.50,       -- 150% base
        LightningDamage = 0,     -- flat bonus
        CooldownReduction = 0.0, -- percentage
    }

    if data and data.Equipped then
        for _, itemId in pairs(data.Equipped) do
            if itemId then
                local def = ItemDatabase.GetItem(itemId)
                if def and def.stats then
                    local s = def.stats
                    computed.MaxHealth += (s.health or 0)
                    computed.AttackPower += (s.attack or 0)
                    computed.Defense += (s.defense or 0)
                    computed.WalkSpeed += (s.speed or 0)
                    computed.CritChance += (s.critChance or 0)
                    computed.CritDamage += (s.critDamage or 0)
                    computed.LightningDamage += (s.lightningDamage or 0)
                    computed.CooldownReduction += (s.abilityCooldown or 0)
                end
            end
        end
    end

    computed.CooldownReduction = math.clamp(computed.CooldownReduction, 0, 0.40) -- Cap at 40% CDR
    return computed
end

function InventoryManager.ApplyStatsToCharacter(player: Player)
    local character = player.Character
    if not character then return end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    local stats = InventoryManager.GetComputedStats(player)

    -- Scale health proportionally to new MaxHealth
    local oldMax = humanoid.MaxHealth
    local oldHp = humanoid.Health
    local hpPercent = if oldMax > 0 then (oldHp / oldMax) else 1

    humanoid.MaxHealth = stats.MaxHealth
    humanoid.Health = math.clamp(math.floor(stats.MaxHealth * hpPercent), 1, stats.MaxHealth)
    humanoid.WalkSpeed = stats.WalkSpeed

    -- Apply server attributes for combat and ability services to read
    character:SetAttribute("BaseWalkSpeed", stats.WalkSpeed)
    character:SetAttribute("AttackPower", stats.AttackPower)
    character:SetAttribute("Defense", stats.Defense)
    character:SetAttribute("CritChance", stats.CritChance)
    character:SetAttribute("CritDamage", stats.CritDamage)
    character:SetAttribute("BonusLightningDamage", stats.LightningDamage)
    character:SetAttribute("CooldownReduction", stats.CooldownReduction)

    player:SetAttribute("AttackPower", stats.AttackPower)
    player:SetAttribute("Defense", stats.Defense)
    player:SetAttribute("MaxHealth", stats.MaxHealth)

    playerStatsUpdatedEvent:FireClient(player, stats)
end

-- =============================================================================
-- NETWORK LISTENER FOR INVENTORY ACTIONS
-- =============================================================================

inventoryActionEvent.OnServerEvent:Connect(function(player: Player, action: string, param1: any, param2: any)
    if typeof(action) ~= "string" then return end

    if action == "Equip" and typeof(param1) == "string" then
        InventoryManager.EquipItem(player, param1)
    elseif action == "Unequip" and typeof(param1) == "string" then
        InventoryManager.UnequipSlot(player, param1)
    elseif action == "Use" and typeof(param1) == "string" then
        InventoryManager.UseConsumable(player, param1)
    elseif action == "Lock" and typeof(param1) == "string" then
        InventoryManager.ToggleLock(player, param1)
    elseif action == "Favorite" and typeof(param1) == "string" then
        InventoryManager.ToggleFavorite(player, param1)
    elseif action == "Sort" then
        InventoryManager.SortInventory(player, typeof(param1) == "string" and param1 or nil)
    elseif action == "Drop" and typeof(param1) == "string" then
        local count = if typeof(param2) == "number" then param2 else 1
        InventoryManager.RemoveItemByUUID(player, param1, count)
    elseif action == "RequestSync" then
        InventoryManager.SyncClient(player)
        InventoryManager.ApplyStatsToCharacter(player)
    end
end)

-- Character Spawning Hook
Players.PlayerAdded:Connect(function(player: Player)
    player.CharacterAdded:Connect(function(character)
        task.wait(0.5)
        InventoryManager.ApplyStatsToCharacter(player)
        InventoryManager.SyncClient(player)
    end)
end)

return InventoryManager