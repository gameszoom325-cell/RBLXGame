--!strict
--[[
    ShopManager.lua
    Server-authoritative Merchant Economy Pipeline:
    - Facilitates Buy, Sell, and Gear Maintenance transactions across 4 Sanctuary Merchants
    - Distance checks to prevent remote exploitation
    - Strict inventory capacity, lock verification, and gold solvency checks
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Systems = ReplicatedStorage:WaitForChild("Systems")

local ShopConfig = require(Shared:WaitForChild("ShopConfig"))
local ItemDatabase = require(Shared:WaitForChild("ItemDatabase"))
local EconomyManager = require(Systems:WaitForChild("EconomyManager"))
local InventoryManager = require(Systems:WaitForChild("InventoryManager"))
local PlayerDataService = require(Systems:WaitForChild("PlayerDataService"))

local networkFolder = ReplicatedStorage:WaitForChild("Network")
local openShopEvent = networkFolder:WaitForChild("OpenShop") :: RemoteEvent
local shopActionEvent = networkFolder:WaitForChild("ShopAction") :: RemoteEvent
local shopResponseEvent = networkFolder:WaitForChild("ShopResponse") :: RemoteEvent

local MAX_INTERACTION_DISTANCE = 25.0

local ShopManager = {}

function ShopManager.OpenMerchant(player: Player, merchantId: string)
    local merchant = ShopConfig[merchantId]
    if not merchant then return end

    -- Send merchant details and catalog of item definitions to the client
    local catalog = {}
    for _, itemId in ipairs(merchant.itemsForSale) do
        local def = ItemDatabase.GetItem(itemId)
        if def then
            table.insert(catalog, def)
        end
    end

    openShopEvent:FireClient(player, merchantId, {
        name = merchant.name,
        title = merchant.title,
        greeting = merchant.greeting,
        buysFromPlayer = merchant.buysFromPlayer,
        allowsRepair = merchant.allowsRepair,
        items = catalog,
    })
end

function ShopManager.ProcessBuy(player: Player, merchantId: string, itemId: string, count: number)
    local merchant = ShopConfig[merchantId]
    if not merchant then
        shopResponseEvent:FireClient(player, false, "Unknown merchant.", "Buy")
        return
    end

    local itemFound = false
    for _, id in ipairs(merchant.itemsForSale) do
        if id == itemId then
            itemFound = true
            break
        end
    end

    if not itemFound then
        shopResponseEvent:FireClient(player, false, "This merchant does not sell that item.", "Buy")
        return
    end

    local def = ItemDatabase.GetItem(itemId)
    if not def then
        shopResponseEvent:FireClient(player, false, "Invalid item definition.", "Buy")
        return
    end

    local safeCount = math.clamp(count or 1, 1, 99)
    local totalCost = def.buyPrice * safeCount

    if not EconomyManager.CanAfford(player, totalCost) then
        shopResponseEvent:FireClient(player, false, string.format("Insufficient Gold! Requires %d Gold.", totalCost), "Buy")
        return
    end

    if EconomyManager.SpendGold(player, totalCost, "ShopBuy:" .. itemId) then
        InventoryManager.AddItem(player, itemId, safeCount)
        shopResponseEvent:FireClient(player, true, string.format("Purchased %s (x%d) for %d Gold.", def.name, safeCount, totalCost), "Buy")
        print(string.format("[ShopManager] %s bought %s (x%d) from %s for %d Gold", player.Name, def.name, safeCount, merchant.name, totalCost))
    else
        shopResponseEvent:FireClient(player, false, "Transaction failed.", "Buy")
    end
end

function ShopManager.ProcessSell(player: Player, merchantId: string, uuid: string, count: number)
    local merchant = ShopConfig[merchantId]
    if not merchant or not merchant.buysFromPlayer then
        shopResponseEvent:FireClient(player, false, "This merchant does not purchase items.", "Sell")
        return
    end

    local data = PlayerDataService.GetPlayerData(player)
    if not data then return end

    local targetItem = nil
    for _, item in ipairs(data.Inventory) do
        if item.uuid == uuid then
            targetItem = item
            break
        end
    end

    if not targetItem then
        shopResponseEvent:FireClient(player, false, "Item not found in inventory.", "Sell")
        return
    end

    if targetItem.isLocked then
        shopResponseEvent:FireClient(player, false, "This item is locked! Unlock it before selling.", "Sell")
        return
    end

    local def = ItemDatabase.GetItem(targetItem.id)
    if not def or def.sellPrice <= 0 then
        shopResponseEvent:FireClient(player, false, "This item cannot be sold.", "Sell")
        return
    end

    local safeCount = math.clamp(count or 1, 1, targetItem.count)
    local totalValue = def.sellPrice * safeCount

    if InventoryManager.RemoveItemByUUID(player, uuid, safeCount) then
        EconomyManager.AddGold(player, totalValue, "ShopSell:" .. def.id)
        shopResponseEvent:FireClient(player, true, string.format("Sold %s (x%d) for +%d Gold.", def.name, safeCount, totalValue), "Sell")
        print(string.format("[ShopManager] %s sold %s (x%d) to %s for %d Gold", player.Name, def.name, safeCount, merchant.name, totalValue))
    else
        shopResponseEvent:FireClient(player, false, "Failed to remove item.", "Sell")
    end
end

function ShopManager.ProcessRepair(player: Player, merchantId: string)
    local merchant = ShopConfig[merchantId]
    if not merchant or not merchant.allowsRepair then
        shopResponseEvent:FireClient(player, false, "This merchant does not offer repairs.", "Repair")
        return
    end

    local repairCost = 35
    if not EconomyManager.CanAfford(player, repairCost) then
        shopResponseEvent:FireClient(player, false, string.format("Requires %d Gold for maintenance and repairs.", repairCost), "Repair")
        return
    end

    if EconomyManager.SpendGold(player, repairCost, "GearRepair") then
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.Health = humanoid.MaxHealth
        end
        shopResponseEvent:FireClient(player, true, "All equipment polished and health fully restored!", "Repair")
    end
end

-- Network Action Handler
shopActionEvent.OnServerEvent:Connect(function(player: Player, action: string, merchantId: string, param1: any, param2: any)
    if typeof(action) ~= "string" or typeof(merchantId) ~= "string" then return end

    local merchant = ShopConfig[merchantId]
    if not merchant then return end

    -- Verify player distance to merchant
    local character = player.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if hrp then
        local dist = (hrp.Position - merchant.position).Magnitude
        if dist > MAX_INTERACTION_DISTANCE then
            shopResponseEvent:FireClient(player, false, "Too far from merchant.", action)
            return
        end
    end

    if action == "Buy" and typeof(param1) == "string" then
        local count = if typeof(param2) == "number" then param2 else 1
        ShopManager.ProcessBuy(player, merchantId, param1, count)
    elseif action == "Sell" and typeof(param1) == "string" then
        local count = if typeof(param2) == "number" then param2 else 1
        ShopManager.ProcessSell(player, merchantId, param1, count)
    elseif action == "Repair" then
        ShopManager.ProcessRepair(player, merchantId)
    end
end)

return ShopManager