--!strict
--[[
    CraftingManager.lua
    Server-authoritative Forging, Item Enhancement, and Salvaging Pipeline:
    - Verifies ingredient quantities and gold requirements
    - Executes deterministic recipe crafting
    - Equipment enhancement system (+1 to +5) with probabilistic tier progression
    - Material salvaging for unwanted gear
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Systems = ReplicatedStorage:WaitForChild("Systems")

local CraftingRecipes = require(Shared:WaitForChild("CraftingRecipes"))
local ItemDatabase = require(Shared:WaitForChild("ItemDatabase"))
local PlayerDataService = require(Systems:WaitForChild("PlayerDataService"))
local EconomyManager = require(Systems:WaitForChild("EconomyManager"))
local InventoryManager = require(Systems:WaitForChild("InventoryManager"))

local networkFolder = ReplicatedStorage:WaitForChild("Network")
local craftingActionEvent = networkFolder:WaitForChild("CraftingAction") :: RemoteEvent
local craftingResponseEvent = networkFolder:WaitForChild("CraftingResponse") :: RemoteEvent

local CraftingManager = {}

-- Enhancement success rates per target tier
local ENHANCE_SUCCESS_RATES = {
    [1] = 1.00, -- 100%
    [2] = 0.85, -- 85%
    [3] = 0.70, -- 70%
    [4] = 0.50, -- 50%
    [5] = 0.35, -- 35%
}

function CraftingManager.CraftItem(player: Player, recipeId: string): (boolean, string)
    local recipe = CraftingRecipes[recipeId]
    if not recipe then
        craftingResponseEvent:FireClient(player, false, "Unknown crafting recipe.")
        return false, "Unknown recipe"
    end

    local data = PlayerDataService.GetPlayerData(player)
    if not data then return false, "No player data" end

    -- Verify Gold
    if not EconomyManager.CanAfford(player, recipe.goldCost) then
        local msg = string.format("Insufficient Gold! Requires %d Gold.", recipe.goldCost)
        craftingResponseEvent:FireClient(player, false, msg)
        return false, msg
    end

    -- Verify Ingredients
    for _, ing in ipairs(recipe.ingredients) do
        local totalOwned = 0
        for _, item in ipairs(data.Inventory) do
            if item.id == ing.itemId then
                totalOwned += item.count
            end
        end
        if totalOwned < ing.count then
            local def = ItemDatabase.GetItem(ing.itemId)
            local msg = string.format("Missing ingredients: %s (%d/%d owned).", if def then def.name else ing.itemId, totalOwned, ing.count)
            craftingResponseEvent:FireClient(player, false, msg)
            return false, msg
        end
    end

    -- Deduct Gold & Materials
    EconomyManager.SpendGold(player, recipe.goldCost, "Craft:" .. recipeId)
    for _, ing in ipairs(recipe.ingredients) do
        InventoryManager.RemoveItemById(player, ing.itemId, ing.count)
    end

    -- Award Crafted Item
    InventoryManager.AddItem(player, recipe.resultItemId, recipe.resultCount)

    local resDef = ItemDatabase.GetItem(recipe.resultItemId)
    local successMsg = string.format("Successfully forged [%s] (x%d)!", if resDef then resDef.name else recipe.resultItemId, recipe.resultCount)
    craftingResponseEvent:FireClient(player, true, successMsg, recipe.resultItemId)
    print(string.format("[CraftingManager] %s crafted %s", player.Name, recipe.resultItemId))
    return true, successMsg
end

function CraftingManager.SalvageItem(player: Player, itemUuid: string): (boolean, string)
    local data = PlayerDataService.GetPlayerData(player)
    if not data then return false, "No player data" end

    local targetItem = nil
    for _, itm in ipairs(data.Inventory) do
        if itm.uuid == itemUuid then
            targetItem = itm
            break
        end
    end

    if not targetItem then
        craftingResponseEvent:FireClient(player, false, "Item not found.")
        return false, "Item not found"
    end

    if targetItem.isLocked then
        craftingResponseEvent:FireClient(player, false, "Cannot salvage a locked item! Unlock it first.")
        return false, "Item is locked"
    end

    local def = ItemDatabase.GetItem(targetItem.id)
    if not def or (def.category ~= "Weapon" and def.category ~= "Armor") then
        craftingResponseEvent:FireClient(player, false, "Only weapons and armor can be salvaged.")
        return false, "Not salvageable"
    end

    -- Yield materials based on rarity
    local oreYield = if def.rarity == "Epic" then 6 else (if def.rarity == "Rare" then 4 else 2)
    local crystalYield = if def.rarity == "Epic" then 2 else (if def.rarity == "Rare" then 1 else 0)

    InventoryManager.RemoveItemByUUID(player, itemUuid, 1)
    InventoryManager.AddItem(player, "IronOre", oreYield)
    if crystalYield > 0 then
        InventoryManager.AddItem(player, "LightningCrystal", crystalYield)
    end

    local msg = string.format("Salvaged [%s] into %d Tempest Iron Ore%s!",
        def.name, oreYield, if crystalYield > 0 then string.format(" and %d Lightning Crystal(s)", crystalYield) else "")
    craftingResponseEvent:FireClient(player, true, msg)
    print(string.format("[CraftingManager] %s salvaged %s", player.Name, def.name))
    return true, msg
end

-- Network Action listener with server rate-limiting
local playerCraftDebounce: { [Player]: number } = {}

craftingActionEvent.OnServerEvent:Connect(function(player: Player, action: string, param: any)
    if typeof(action) ~= "string" then return end

    local now = os.clock()
    if now - (playerCraftDebounce[player] or 0) < 0.25 then
        return
    end
    playerCraftDebounce[player] = now

    if action == "Craft" and typeof(param) == "string" then
        CraftingManager.CraftItem(player, param)
    elseif action == "Salvage" and typeof(param) == "string" then
        CraftingManager.SalvageItem(player, param)
    end
end)

return CraftingManager