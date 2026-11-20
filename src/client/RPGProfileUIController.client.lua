--!strict
--[[
    RPGProfileUIController.client.lua
    Master Client RPG Interface Orchestrator:
    - HUD XP progress bar and Level badge
    - Level-up fanfare banner and celebratory animations
    - Loot pickup notification toast stack
    - Dynamic Equipment paperdoll and 6-category Inventory window (Keybind: [I] or [Tab])
    - Full Character Stats Profile window (Keybind: [P])
    - Interactive Sanctuary Merchant Shop interface (Buy, Sell, Repair)
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProgressionTypes = require(Shared:WaitForChild("ProgressionTypes"))
local ItemDatabase = require(Shared:WaitForChild("ItemDatabase"))

local networkFolder = ReplicatedStorage:WaitForChild("Network")
local levelUpEvent = networkFolder:WaitForChild("LevelUpEvent") :: RemoteEvent
local inventoryActionEvent = networkFolder:WaitForChild("InventoryAction") :: RemoteEvent
local inventoryUpdatedEvent = networkFolder:WaitForChild("InventoryUpdated") :: RemoteEvent
local openShopEvent = networkFolder:WaitForChild("OpenShop") :: RemoteEvent
local shopActionEvent = networkFolder:WaitForChild("ShopAction") :: RemoteEvent
local shopResponseEvent = networkFolder:WaitForChild("ShopResponse") :: RemoteEvent
local playerStatsUpdatedEvent = networkFolder:WaitForChild("PlayerStatsUpdated") :: RemoteEvent

-- =============================================================================
-- COLOR PALETTES & RARITY STYLES
-- =============================================================================

local RARITY_COLORS = {
    Common = Color3.fromRGB(190, 190, 195),
    Uncommon = Color3.fromRGB(90, 220, 100),
    Rare = Color3.fromRGB(65, 180, 255),
    Epic = Color3.fromRGB(185, 75, 255),
    Legendary = Color3.fromRGB(255, 175, 30),
}

-- Client Cache
local clientInventory: { ProgressionTypes.InventoryItem } = {}
local clientEquipped: ProgressionTypes.EquippedGear = {}
local clientStats = {
    Level = 1,
    MaxHealth = 200,
    AttackPower = 25,
    Defense = 10,
    WalkSpeed = 16,
    CritChance = 0.05,
    CritDamage = 1.50,
    LightningDamage = 0,
    CooldownReduction = 0.0,
}

local selectedInventoryItemUUID: string? = nil
local activeMerchantId: string? = nil
local activeMerchantData: any = nil

-- Master ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RPGProgressionGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- =============================================================================
-- 1. HUD: XP BAR & LEVEL BADGE (BOTTOM CENTER)
-- =============================================================================

local hudFrame = Instance.new("Frame")
hudFrame.Name = "ProgressionHUD"
hudFrame.Size = UDim2.new(0, 360, 0, 36)
hudFrame.Position = UDim2.new(0.5, -180, 1, -50)
hudFrame.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
hudFrame.BorderSizePixel = 0
hudFrame.Parent = screenGui

local hudCorner = Instance.new("UICorner")
hudCorner.CornerRadius = UDim.new(0, 8)
hudCorner.Parent = hudFrame

local hudStroke = Instance.new("UIStroke")
hudStroke.Color = Color3.fromRGB(60, 140, 220)
hudStroke.Thickness = 1.5
hudStroke.Parent = hudFrame

local levelBadge = Instance.new("TextLabel")
levelBadge.Name = "LevelBadge"
levelBadge.Size = UDim2.new(0, 75, 1, 0)
levelBadge.Position = UDim2.new(0, 0, 0, 0)
levelBadge.BackgroundColor3 = Color3.fromRGB(25, 40, 65)
levelBadge.BorderSizePixel = 0
levelBadge.Text = "LV. 1"
levelBadge.TextColor3 = Color3.fromRGB(255, 220, 60)
levelBadge.Font = Enum.Font.GothamBlack
levelBadge.TextSize = 14
levelBadge.Parent = hudFrame

local badgeCorner = Instance.new("UICorner")
badgeCorner.CornerRadius = UDim.new(0, 8)
badgeCorner.Parent = levelBadge

local xpBarBg = Instance.new("Frame")
xpBarBg.Name = "XPBarBg"
xpBarBg.Size = UDim2.new(1, -85, 0, 14)
xpBarBg.Position = UDim2.new(0, 80, 0.5, -7)
xpBarBg.BackgroundColor3 = Color3.fromRGB(25, 30, 42)
xpBarBg.BorderSizePixel = 0
xpBarBg.Parent = hudFrame

local xpBarBgCorner = Instance.new("UICorner")
xpBarBgCorner.CornerRadius = UDim.new(0, 6)
xpBarBgCorner.Parent = xpBarBg

local xpBarFill = Instance.new("Frame")
xpBarFill.Name = "XPBarFill"
xpBarFill.Size = UDim2.new(0, 0, 1, 0)
xpBarFill.BackgroundColor3 = Color3.fromRGB(65, 215, 255)
xpBarFill.BorderSizePixel = 0
xpBarFill.Parent = xpBarBg

local xpFillCorner = Instance.new("UICorner")
xpFillCorner.CornerRadius = UDim.new(0, 6)
xpFillCorner.Parent = xpBarFill

local xpText = Instance.new("TextLabel")
xpText.Name = "XPText"
xpText.Size = UDim2.new(1, 0, 1, 0)
xpText.BackgroundTransparency = 1
xpText.Text = "0 / 100 XP"
xpText.TextColor3 = Color3.fromRGB(255, 255, 255)
xpText.Font = Enum.Font.GothamBold
xpText.TextSize = 10
xpText.Parent = xpBarBg

local function updateHUD()
    local level = player:GetAttribute("Level") or 1
    local xp = player:GetAttribute("XP") or 0
    local reqXP = player:GetAttribute("RequiredXP") or 100

    levelBadge.Text = string.format("LV. %d", level)
    xpText.Text = string.format("%d / %d XP", math.floor(xp), math.floor(reqXP))

    local ratio = math.clamp(xp / reqXP, 0, 1)
    TweenService:Create(xpBarFill, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.new(ratio, 0, 1, 0)
    }):Play()
end

player:GetAttributeChangedSignal("Level"):Connect(updateHUD)
player:GetAttributeChangedSignal("XP"):Connect(updateHUD)
player:GetAttributeChangedSignal("RequiredXP"):Connect(updateHUD)

-- =============================================================================
-- 2. LEVEL UP FANFARE BANNER
-- =============================================================================

local fanfareFrame = Instance.new("Frame")
fanfareFrame.Name = "LevelUpFanfare"
fanfareFrame.Size = UDim2.new(0, 480, 0, 100)
fanfareFrame.Position = UDim2.new(0.5, -240, 0.25, -50)
fanfareFrame.BackgroundColor3 = Color3.fromRGB(20, 25, 40)
fanfareFrame.BorderSizePixel = 0
fanfareFrame.Visible = false
fanfareFrame.Parent = screenGui

local fanfareCorner = Instance.new("UICorner")
fanfareCorner.CornerRadius = UDim.new(0, 12)
fanfareCorner.Parent = fanfareFrame

local fanfareStroke = Instance.new("UIStroke")
fanfareStroke.Color = Color3.fromRGB(255, 215, 50)
fanfareStroke.Thickness = 2.5
fanfareStroke.Parent = fanfareFrame

local fanfareTitle = Instance.new("TextLabel")
fanfareTitle.Size = UDim2.new(1, 0, 0, 48)
fanfareTitle.BackgroundTransparency = 1
fanfareTitle.Text = "★ LEVEL UP! ★"
fanfareTitle.TextColor3 = Color3.fromRGB(255, 220, 60)
fanfareTitle.Font = Enum.Font.GothamBlack
fanfareTitle.TextSize = 26
fanfareTitle.Parent = fanfareFrame

local fanfareSubtitle = Instance.new("TextLabel")
fanfareSubtitle.Size = UDim2.new(1, 0, 0, 36)
fanfareSubtitle.Position = UDim2.new(0, 0, 0, 50)
fanfareSubtitle.BackgroundTransparency = 1
fanfareSubtitle.Text = "+25 Max HP | +5 Attack | +3 Defense"
fanfareSubtitle.TextColor3 = Color3.fromRGB(180, 230, 255)
fanfareSubtitle.Font = Enum.Font.GothamBold
fanfareSubtitle.TextSize = 14
fanfareSubtitle.Parent = fanfareFrame

levelUpEvent.OnClientEvent:Connect(function(newLevel: number, statsGained: any)
    fanfareTitle.Text = string.format("★ LEVEL %d REACHED! ★", newLevel)
    if statsGained then
        fanfareSubtitle.Text = string.format("+%d Max HP  |  +%d Attack  |  +%d Defense",
            statsGained.health or 25, statsGained.attack or 5, statsGained.defense or 3)
    end

    fanfareFrame.Visible = true
    fanfareFrame.Position = UDim2.new(0.5, -240, 0.20, -50)
    fanfareFrame.BackgroundTransparency = 0.5

    TweenService:Create(fanfareFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -240, 0.25, -50),
        BackgroundTransparency = 0,
    }):Play()

    task.delay(2.6, function()
        local outTween = TweenService:Create(fanfareFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(0.5, -240, 0.20, -50),
            BackgroundTransparency = 1,
        })
        outTween:Play()
        outTween.Completed:Connect(function()
            fanfareFrame.Visible = false
        end)
    end)
end)

-- =============================================================================
-- 3. LOOT PICKUP TOAST NOTIFICATIONS (RIGHT SIDE STACK)
-- =============================================================================

local toastContainer = Instance.new("Frame")
toastContainer.Name = "ToastContainer"
toastContainer.Size = UDim2.new(0, 260, 0, 300)
toastContainer.Position = UDim2.new(1, -280, 0.6, -150)
toastContainer.BackgroundTransparency = 1
toastContainer.Parent = screenGui

local toastLayout = Instance.new("UIListLayout")
toastLayout.SortOrder = Enum.SortOrder.LayoutOrder
toastLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
toastLayout.Padding = UDim.new(0, 6)
toastLayout.Parent = toastContainer

local function showToast(message: string, color: Color3)
    local toast = Instance.new("Frame")
    toast.Size = UDim2.new(1, 0, 0, 34)
    toast.BackgroundColor3 = Color3.fromRGB(20, 24, 35)
    toast.BorderSizePixel = 0
    toast.Parent = toastContainer

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = toast

    local stroke = Instance.new("UIStroke")
    stroke.Color = color
    stroke.Thickness = 1.2
    stroke.Parent = toast

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -12, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = message
    label.TextColor3 = color
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = toast

    toast.Position = UDim2.new(0.2, 0, 0, 0)
    toast.BackgroundTransparency = 1
    label.TextTransparency = 1

    TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 0,
    }):Play()
    TweenService:Create(label, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        TextTransparency = 0
    }):Play()

    task.delay(2.4, function()
        local fade = TweenService:Create(toast, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            BackgroundTransparency = 1
        })
        TweenService:Create(label, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            TextTransparency = 1
        }):Play()
        fade:Play()
        fade.Completed:Connect(function()
            toast:Destroy()
        end)
    end)
end

-- =============================================================================
-- 4. INVENTORY & EQUIPMENT WINDOW ([I] OR [TAB])
-- =============================================================================

local inventoryWindow = Instance.new("Frame")
inventoryWindow.Name = "InventoryWindow"
inventoryWindow.Size = UDim2.new(0, 680, 0, 440)
inventoryWindow.Position = UDim2.new(0.5, -340, 0.5, -220)
inventoryWindow.BackgroundColor3 = Color3.fromRGB(18, 24, 36)
inventoryWindow.BorderSizePixel = 0
inventoryWindow.Visible = false
inventoryWindow.Parent = screenGui

local invCorner = Instance.new("UICorner")
invCorner.CornerRadius = UDim.new(0, 10)
invCorner.Parent = inventoryWindow

local invStroke = Instance.new("UIStroke")
invStroke.Color = Color3.fromRGB(60, 150, 235)
invStroke.Thickness = 2
invStroke.Parent = inventoryWindow

-- Window Header
local invHeader = Instance.new("TextLabel")
invHeader.Size = UDim2.new(1, -40, 0, 40)
invHeader.Position = UDim2.new(0, 20, 0, 0)
invHeader.BackgroundTransparency = 1
invHeader.Text = "HERO ARSENAL & INVENTORY  [I / Tab]"
invHeader.TextColor3 = Color3.fromRGB(240, 245, 255)
invHeader.Font = Enum.Font.GothamBlack
invHeader.TextSize = 16
invHeader.TextXAlignment = Enum.TextXAlignment.Left
invHeader.Parent = inventoryWindow

local invCloseBtn = Instance.new("TextButton")
invCloseBtn.Size = UDim2.new(0, 30, 0, 30)
invCloseBtn.Position = UDim2.new(1, -38, 0, 6)
invCloseBtn.BackgroundColor3 = Color3.fromRGB(45, 30, 35)
invCloseBtn.Text = "X"
invCloseBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
invCloseBtn.Font = Enum.Font.GothamBold
invCloseBtn.TextSize = 14
invCloseBtn.Parent = inventoryWindow
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = invCloseBtn

invCloseBtn.MouseButton1Click:Connect(function()
    inventoryWindow.Visible = false
end)

-- Left Column: Equipment Paperdoll Slots
local paperdollFrame = Instance.new("Frame")
paperdollFrame.Name = "PaperdollFrame"
paperdollFrame.Size = UDim2.new(0, 220, 1, -55)
paperdollFrame.Position = UDim2.new(0, 15, 0, 45)
paperdollFrame.BackgroundColor3 = Color3.fromRGB(12, 16, 26)
paperdollFrame.BorderSizePixel = 0
paperdollFrame.Parent = inventoryWindow

local pdCorner = Instance.new("UICorner")
pdCorner.CornerRadius = UDim.new(0, 8)
pdCorner.Parent = paperdollFrame

local pdTitle = Instance.new("TextLabel")
pdTitle.Size = UDim2.new(1, 0, 0, 30)
pdTitle.BackgroundTransparency = 1
pdTitle.Text = "EQUIPPED GEAR"
pdTitle.TextColor3 = Color3.fromRGB(65, 215, 255)
pdTitle.Font = Enum.Font.GothamBold
pdTitle.TextSize = 13
pdTitle.Parent = paperdollFrame

local GEAR_SLOTS = { "Weapon", "Chest", "Head", "Shoulders", "Boots", "Artifact" }
local gearSlotButtons: { [string]: TextButton } = {}

for idx, slotName in ipairs(GEAR_SLOTS) do
    local slotBtn = Instance.new("TextButton")
    slotBtn.Name = "Slot_" .. slotName
    slotBtn.Size = UDim2.new(1, -20, 0, 46)
    slotBtn.Position = UDim2.new(0, 10, 0, 30 + (idx - 1) * 52)
    slotBtn.BackgroundColor3 = Color3.fromRGB(20, 26, 42)
    slotBtn.BorderSizePixel = 0
    slotBtn.Text = slotName .. ": Empty"
    slotBtn.TextColor3 = Color3.fromRGB(160, 170, 190)
    slotBtn.Font = Enum.Font.GothamMedium
    slotBtn.TextSize = 11
    slotBtn.Parent = paperdollFrame

    local sCorner = Instance.new("UICorner")
    sCorner.CornerRadius = UDim.new(0, 6)
    sCorner.Parent = slotBtn

    local sStroke = Instance.new("UIStroke")
    sStroke.Color = Color3.fromRGB(45, 60, 90)
    sStroke.Thickness = 1
    sStroke.Parent = slotBtn

    slotBtn.MouseButton1Click:Connect(function()
        -- Unequip when clicked
        inventoryActionEvent:FireServer("Unequip", slotName)
    end)

    gearSlotButtons[slotName] = slotBtn
end

-- Center & Right: Category Filter & Inventory Grid
local gridContainer = Instance.new("Frame")
gridContainer.Name = "GridContainer"
gridContainer.Size = UDim2.new(1, -260, 1, -55)
gridContainer.Position = UDim2.new(0, 245, 0, 45)
gridContainer.BackgroundColor3 = Color3.fromRGB(12, 16, 26)
gridContainer.BorderSizePixel = 0
gridContainer.Parent = inventoryWindow

local gcCorner = Instance.new("UICorner")
gcCorner.CornerRadius = UDim.new(0, 8)
gcCorner.Parent = gridContainer

-- Category Tabs
local categoryFilter = "All"
local CATEGORIES = { "All", "Weapon", "Armor", "Artifact", "Consumable", "Material" }
local tabButtons: { [string]: TextButton } = {}

local tabFrame = Instance.new("Frame")
tabFrame.Size = UDim2.new(1, -10, 0, 28)
tabFrame.Position = UDim2.new(0, 5, 0, 6)
tabFrame.BackgroundTransparency = 1
tabFrame.Parent = gridContainer

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 4)
tabLayout.Parent = tabFrame

local itemScroll = Instance.new("ScrollingFrame")
itemScroll.Name = "ItemScroll"
itemScroll.Size = UDim2.new(1, -12, 1, -120)
itemScroll.Position = UDim2.new(0, 6, 0, 40)
itemScroll.BackgroundTransparency = 1
itemScroll.BorderSizePixel = 0
itemScroll.ScrollBarThickness = 4
itemScroll.ScrollBarImageColor3 = Color3.fromRGB(60, 140, 220)
itemScroll.Parent = gridContainer

local itemGridLayout = Instance.new("UIGridLayout")
itemGridLayout.CellSize = UDim2.new(0, 56, 0, 56)
itemGridLayout.CellPadding = UDim2.new(0, 6, 0, 6)
itemGridLayout.Parent = itemScroll

-- Bottom Item Detail Bar
local detailFrame = Instance.new("Frame")
detailFrame.Name = "DetailFrame"
detailFrame.Size = UDim2.new(1, -12, 0, 70)
detailFrame.Position = UDim2.new(0, 6, 1, -74)
detailFrame.BackgroundColor3 = Color3.fromRGB(20, 28, 45)
detailFrame.BorderSizePixel = 0
detailFrame.Parent = gridContainer

local dfCorner = Instance.new("UICorner")
dfCorner.CornerRadius = UDim.new(0, 6)
dfCorner.Parent = detailFrame

local detailTitle = Instance.new("TextLabel")
detailTitle.Size = UDim2.new(0.65, 0, 0, 22)
detailTitle.Position = UDim2.new(0, 8, 0, 4)
detailTitle.BackgroundTransparency = 1
detailTitle.Text = "Select an item to view details"
detailTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
detailTitle.Font = Enum.Font.GothamBold
detailTitle.TextSize = 12
detailTitle.TextXAlignment = Enum.TextXAlignment.Left
detailTitle.Parent = detailFrame

local detailStats = Instance.new("TextLabel")
detailStats.Size = UDim2.new(0.65, 0, 0, 36)
detailStats.Position = UDim2.new(0, 8, 0, 26)
detailStats.BackgroundTransparency = 1
detailStats.Text = ""
detailStats.TextColor3 = Color3.fromRGB(180, 215, 255)
detailStats.Font = Enum.Font.Gotham
detailStats.TextSize = 10
detailStats.TextWrapped = true
detailStats.TextXAlignment = Enum.TextXAlignment.Left
detailStats.Parent = detailFrame

-- Action Buttons: Equip / Use / Lock
local equipBtn = Instance.new("TextButton")
equipBtn.Size = UDim2.new(0, 60, 0, 26)
equipBtn.Position = UDim2.new(1, -135, 0, 8)
equipBtn.BackgroundColor3 = Color3.fromRGB(40, 130, 220)
equipBtn.Text = "Equip"
equipBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
equipBtn.Font = Enum.Font.GothamBold
equipBtn.TextSize = 11
equipBtn.Visible = false
equipBtn.Parent = detailFrame
local eqCorner = Instance.new("UICorner")
eqCorner.CornerRadius = UDim.new(0, 5)
eqCorner.Parent = equipBtn

local lockBtn = Instance.new("TextButton")
lockBtn.Size = UDim2.new(0, 60, 0, 26)
lockBtn.Position = UDim2.new(1, -68, 0, 8)
lockBtn.BackgroundColor3 = Color3.fromRGB(60, 75, 100)
lockBtn.Text = "Lock"
lockBtn.TextColor3 = Color3.fromRGB(240, 240, 245)
lockBtn.Font = Enum.Font.GothamBold
lockBtn.TextSize = 11
lockBtn.Visible = false
lockBtn.Parent = detailFrame
local lkCorner = Instance.new("UICorner")
lkCorner.CornerRadius = UDim.new(0, 5)
lkCorner.Parent = lockBtn

local dropBtn = Instance.new("TextButton")
dropBtn.Size = UDim2.new(0, 60, 0, 26)
dropBtn.Position = UDim2.new(1, -68, 0, 38)
dropBtn.BackgroundColor3 = Color3.fromRGB(150, 45, 45)
dropBtn.Text = "Drop"
dropBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
dropBtn.Font = Enum.Font.GothamBold
dropBtn.TextSize = 11
dropBtn.Visible = false
dropBtn.Parent = detailFrame
local dpCorner = Instance.new("UICorner")
dpCorner.CornerRadius = UDim.new(0, 5)
dpCorner.Parent = dropBtn

local function renderInventory()
    -- Clear current grid slots
    for _, child in ipairs(itemScroll:GetChildren()) do
        if child:IsA("GuiObject") and child ~= itemGridLayout then
            child:Destroy()
        end
    end

    -- Update Paperdoll Slots
    for _, slotName in ipairs(GEAR_SLOTS) do
        local btn = gearSlotButtons[slotName]
        local equippedItemId = (clientEquipped :: any)[slotName]
        if equippedItemId then
            local def = ItemDatabase.GetItem(equippedItemId)
            if def then
                local rColor = RARITY_COLORS[def.rarity] or Color3.fromRGB(255, 255, 255)
                btn.Text = string.format("[%s]\n%s", slotName, def.name)
                btn.TextColor3 = rColor
            else
                btn.Text = slotName .. ": Equipped"
                btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            end
        else
            btn.Text = slotName .. "\n(Empty)"
            btn.TextColor3 = Color3.fromRGB(130, 140, 160)
        end
    end

    -- Populate Grid
    for _, item in ipairs(clientInventory) do
        local def = ItemDatabase.GetItem(item.id)
        if def and (categoryFilter == "All" or def.category == categoryFilter) then
            local slot = Instance.new("TextButton")
            slot.Name = "Item_" .. item.uuid
            slot.BackgroundColor3 = Color3.fromRGB(24, 32, 50)
            slot.BorderSizePixel = 0
            slot.Text = ""
            slot.Parent = itemScroll

            local sCorner = Instance.new("UICorner")
            sCorner.CornerRadius = UDim.new(0, 6)
            sCorner.Parent = slot

            local sStroke = Instance.new("UIStroke")
            sStroke.Color = RARITY_COLORS[def.rarity] or Color3.fromRGB(80, 100, 140)
            sStroke.Thickness = if item.uuid == selectedInventoryItemUUID then 2.5 else 1.2
            sStroke.Parent = slot

            local icon = Instance.new("Frame")
            icon.Size = UDim2.new(0.65, 0, 0.65, 0)
            icon.Position = UDim2.new(0.175, 0, 0.1, 0)
            icon.BackgroundColor3 = def.iconColor or Color3.fromRGB(150, 180, 220)
            icon.BorderSizePixel = 0
            icon.Parent = slot

            local iCorner = Instance.new("UICorner")
            iCorner.CornerRadius = UDim.new(0, 4)
            iCorner.Parent = icon

            if item.count > 1 then
                local countLabel = Instance.new("TextLabel")
                countLabel.Size = UDim2.new(1, -4, 0, 14)
                countLabel.Position = UDim2.new(0, 0, 1, -14)
                countLabel.BackgroundTransparency = 1
                countLabel.Text = "x" .. tostring(item.count)
                countLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                countLabel.Font = Enum.Font.GothamBold
                countLabel.TextSize = 10
                countLabel.TextXAlignment = Enum.TextXAlignment.Right
                countLabel.Parent = slot
            end

            if item.isLocked then
                local lockIcon = Instance.new("TextLabel")
                lockIcon.Size = UDim2.new(0, 14, 0, 14)
                lockIcon.Position = UDim2.new(0, 2, 0, 2)
                lockIcon.BackgroundTransparency = 1
                lockIcon.Text = "🔒"
                lockIcon.TextSize = 9
                lockIcon.Parent = slot
            end

            -- Hover effect
            slot.MouseEnter:Connect(function()
                if item.uuid ~= selectedInventoryItemUUID then
                    slot.BackgroundColor3 = Color3.fromRGB(36, 48, 72)
                    sStroke.Thickness = 1.8
                end
            end)
            slot.MouseLeave:Connect(function()
                if item.uuid ~= selectedInventoryItemUUID then
                    slot.BackgroundColor3 = Color3.fromRGB(24, 32, 50)
                    sStroke.Thickness = 1.2
                end
            end)

            slot.MouseButton1Click:Connect(function()
                selectedInventoryItemUUID = item.uuid
                renderInventory()

                detailTitle.Text = string.format("%s  [%s]", def.name, def.rarity)
                detailTitle.TextColor3 = RARITY_COLORS[def.rarity] or Color3.fromRGB(255, 255, 255)

                local statsDesc = def.description
                if def.stats then
                    local s = def.stats
                    local bonusList = {}
                    if s.attack then table.insert(bonusList, "+" .. s.attack .. " ATK") end
                    if s.health then table.insert(bonusList, "+" .. s.health .. " HP") end
                    if s.defense then table.insert(bonusList, "+" .. s.defense .. " DEF") end
                    if s.speed then table.insert(bonusList, "+" .. s.speed .. " Speed") end
                    if s.lightningDamage then table.insert(bonusList, "+" .. s.lightningDamage .. " Shock") end
                    if s.critChance then table.insert(bonusList, string.format("+%d%% Crit", s.critChance * 100)) end
                    if #bonusList > 0 then
                        statsDesc = table.concat(bonusList, " | ") .. "\n" .. def.description
                    end
                end

                -- Equipment Comparison Tooltip
                if def.slot then
                    local equippedId = (clientEquipped :: any)[def.slot]
                    if equippedId then
                        local curDef = ItemDatabase.GetItem(equippedId)
                        if curDef then
                            local diffs = {}
                            local statKeys = { "attack", "health", "defense", "speed", "lightningDamage", "critChance" }
                            local statNames = {
                                attack = "ATK",
                                health = "HP",
                                defense = "DEF",
                                speed = "Speed",
                                lightningDamage = "Shock",
                                critChance = "Crit %",
                            }

                            for _, k in ipairs(statKeys) do
                                local oldVal = (curDef.stats and (curDef.stats :: any)[k]) or 0
                                local newVal = (def.stats and (def.stats :: any)[k]) or 0
                                local diff = newVal - oldVal
                                if diff ~= 0 then
                                    local sign = if diff > 0 then "+" else ""
                                    local formattedDiff = if k == "critChance" then string.format("%s%d%%", sign, diff * 100) else string.format("%s%d", sign, diff)
                                    local tag = if diff > 0 then "▲" else "▼"
                                    table.insert(diffs, string.format("%s %s (%s vs Equipped)", tag, statNames[k] or k, formattedDiff))
                                end
                            end

                            if #diffs > 0 then
                                statsDesc = statsDesc .. "\n\n--- COMPARE vs " .. curDef.name .. " ---\n" .. table.concat(diffs, "\n")
                            else
                                statsDesc = statsDesc .. "\n\n--- COMPARE vs " .. curDef.name .. " ---\n= Identical Baseline Stats"
                            end
                        end
                    else
                        statsDesc = statsDesc .. "\n\n--- [Slot Empty: Full Stat Gain] ---"
                    end
                end

                detailStats.Text = statsDesc

                lockBtn.Visible = true
                lockBtn.Text = if item.isLocked then "Unlock" else "Lock"
                dropBtn.Visible = not item.isLocked

                if def.slot then
                    equipBtn.Visible = true
                    equipBtn.Text = "Equip"
                    equipBtn.BackgroundColor3 = Color3.fromRGB(40, 130, 220)
                elseif def.category == "Consumable" then
                    equipBtn.Visible = true
                    equipBtn.Text = "Use"
                    equipBtn.BackgroundColor3 = Color3.fromRGB(45, 175, 90)
                else
                    equipBtn.Visible = false
                end
            end)
        end
    end
end

-- Hook Inventory Action Buttons
equipBtn.MouseButton1Click:Connect(function()
    if not selectedInventoryItemUUID then return end
    for _, itm in ipairs(clientInventory) do
        if itm.uuid == selectedInventoryItemUUID then
            local def = ItemDatabase.GetItem(itm.id)
            if def and def.slot then
                inventoryActionEvent:FireServer("Equip", selectedInventoryItemUUID)
            elseif def and def.category == "Consumable" then
                inventoryActionEvent:FireServer("Use", selectedInventoryItemUUID)
            end
            break
        end
    end
end)

lockBtn.MouseButton1Click:Connect(function()
    if selectedInventoryItemUUID then
        inventoryActionEvent:FireServer("Lock", selectedInventoryItemUUID)
    end
end)

dropBtn.MouseButton1Click:Connect(function()
    if selectedInventoryItemUUID then
        inventoryActionEvent:FireServer("Drop", selectedInventoryItemUUID, 1)
    end
end)

-- Category Tab Builder
for _, cat in ipairs(CATEGORIES) do
    local tBtn = Instance.new("TextButton")
    tBtn.Name = "Tab_" .. cat
    tBtn.Size = UDim2.new(0, 64, 1, 0)
    tBtn.BackgroundColor3 = if cat == "All" then Color3.fromRGB(50, 120, 200) else Color3.fromRGB(22, 28, 42)
    tBtn.BorderSizePixel = 0
    tBtn.Text = cat
    tBtn.TextColor3 = Color3.fromRGB(240, 240, 250)
    tBtn.Font = Enum.Font.GothamBold
    tBtn.TextSize = 10
    tBtn.Parent = tabFrame

    local tCorner = Instance.new("UICorner")
    tCorner.CornerRadius = UDim.new(0, 5)
    tCorner.Parent = tBtn

    tBtn.MouseButton1Click:Connect(function()
        categoryFilter = cat
        for cName, btn in pairs(tabButtons) do
            btn.BackgroundColor3 = if cName == cat then Color3.fromRGB(50, 120, 200) else Color3.fromRGB(22, 28, 42)
        end
        renderInventory()
    end)

    tabButtons[cat] = tBtn
end

inventoryUpdatedEvent.OnClientEvent:Connect(function(inv: any, equipped: any)
    if typeof(inv) == "table" then clientInventory = inv end
    if typeof(equipped) == "table" then clientEquipped = equipped end
    renderInventory()
end)

-- =============================================================================
-- 5. STATS PROFILE WINDOW ([P])
-- =============================================================================

local profileWindow = Instance.new("Frame")
profileWindow.Name = "ProfileWindow"
profileWindow.Size = UDim2.new(0, 380, 0, 420)
profileWindow.Position = UDim2.new(0.5, -190, 0.5, -210)
profileWindow.BackgroundColor3 = Color3.fromRGB(18, 24, 36)
profileWindow.BorderSizePixel = 0
profileWindow.Visible = false
profileWindow.Parent = screenGui

local profCorner = Instance.new("UICorner")
profCorner.CornerRadius = UDim.new(0, 10)
profCorner.Parent = profileWindow

local profStroke = Instance.new("UIStroke")
profStroke.Color = Color3.fromRGB(65, 215, 255)
profStroke.Thickness = 2
profStroke.Parent = profileWindow

local profHeader = Instance.new("TextLabel")
profHeader.Size = UDim2.new(1, -40, 0, 40)
profHeader.Position = UDim2.new(0, 18, 0, 0)
profHeader.BackgroundTransparency = 1
profHeader.Text = "CHAMPION PROFILE & STATS  [P]"
profHeader.TextColor3 = Color3.fromRGB(240, 245, 255)
profHeader.Font = Enum.Font.GothamBlack
profHeader.TextSize = 15
profHeader.TextXAlignment = Enum.TextXAlignment.Left
profHeader.Parent = profileWindow

local profCloseBtn = Instance.new("TextButton")
profCloseBtn.Size = UDim2.new(0, 28, 0, 28)
profCloseBtn.Position = UDim2.new(1, -36, 0, 6)
profCloseBtn.BackgroundColor3 = Color3.fromRGB(45, 30, 35)
profCloseBtn.Text = "X"
profCloseBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
profCloseBtn.Font = Enum.Font.GothamBold
profCloseBtn.TextSize = 13
profCloseBtn.Parent = profileWindow
local pCloseCorner = Instance.new("UICorner")
pCloseCorner.CornerRadius = UDim.new(0, 6)
pCloseCorner.Parent = profCloseBtn

profCloseBtn.MouseButton1Click:Connect(function()
    profileWindow.Visible = false
end)

local statsListFrame = Instance.new("Frame")
statsListFrame.Size = UDim2.new(1, -30, 1, -55)
statsListFrame.Position = UDim2.new(0, 15, 0, 45)
statsListFrame.BackgroundColor3 = Color3.fromRGB(12, 16, 26)
statsListFrame.BorderSizePixel = 0
statsListFrame.Parent = profileWindow

local slCorner = Instance.new("UICorner")
slCorner.CornerRadius = UDim.new(0, 8)
slCorner.Parent = statsListFrame

local statLabels: { [string]: TextLabel } = {}
local STAT_ROWS = {
    { key = "Hero", label = "Hero Class" },
    { key = "Level", label = "Current Level" },
    { key = "Gold", label = "Sanctuary Gold" },
    { key = "MaxHealth", label = "Max Health" },
    { key = "AttackPower", label = "Attack Power" },
    { key = "Defense", label = "Physical Defense" },
    { key = "WalkSpeed", label = "Movement Speed" },
    { key = "CritChance", label = "Critical Strike Chance" },
    { key = "CritDamage", label = "Critical Strike Damage" },
    { key = "LightningDamage", label = "Lightning Damage Bonus" },
    { key = "CooldownReduction", label = "Cooldown Reduction" },
}

for i, row in ipairs(STAT_ROWS) do
    local rFrame = Instance.new("Frame")
    rFrame.Size = UDim2.new(1, -16, 0, 28)
    rFrame.Position = UDim2.new(0, 8, 0, 6 + (i - 1) * 31)
    rFrame.BackgroundColor3 = Color3.fromRGB(18, 24, 38)
    rFrame.BorderSizePixel = 0
    rFrame.Parent = statsListFrame

    local rCorner = Instance.new("UICorner")
    rCorner.CornerRadius = UDim.new(0, 4)
    rCorner.Parent = rFrame

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(0.6, 0, 1, 0)
    nameLbl.Position = UDim2.new(0, 8, 0, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = row.label
    nameLbl.TextColor3 = Color3.fromRGB(180, 195, 215)
    nameLbl.Font = Enum.Font.GothamMedium
    nameLbl.TextSize = 11
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.Parent = rFrame

    local valLbl = Instance.new("TextLabel")
    valLbl.Size = UDim2.new(0.38, -8, 1, 0)
    valLbl.Position = UDim2.new(0.62, 0, 0, 0)
    valLbl.BackgroundTransparency = 1
    valLbl.Text = "--"
    valLbl.TextColor3 = Color3.fromRGB(65, 220, 255)
    valLbl.Font = Enum.Font.GothamBold
    valLbl.TextSize = 11
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.Parent = rFrame

    statLabels[row.key] = valLbl
end

local function refreshProfileStats()
    local s = clientStats
    if statLabels.Hero then statLabels.Hero.Text = "Stormforge Valen" end
    if statLabels.Level then statLabels.Level.Text = "Level " .. tostring(s.Level or 1) end
    if statLabels.Gold then statLabels.Gold.Text = tostring(player:GetAttribute("Gold") or 0) .. " G" end
    if statLabels.MaxHealth then statLabels.MaxHealth.Text = tostring(s.MaxHealth or 200) .. " HP" end
    if statLabels.AttackPower then statLabels.AttackPower.Text = tostring(s.AttackPower or 25) end
    if statLabels.Defense then statLabels.Defense.Text = tostring(s.Defense or 10) end
    if statLabels.WalkSpeed then statLabels.WalkSpeed.Text = tostring(s.WalkSpeed or 16) end
    if statLabels.CritChance then statLabels.CritChance.Text = string.format("%.1f%%", (s.CritChance or 0.05) * 100) end
    if statLabels.CritDamage then statLabels.CritDamage.Text = string.format("%d%%", (s.CritDamage or 1.50) * 100) end
    if statLabels.LightningDamage then statLabels.LightningDamage.Text = "+" .. tostring(s.LightningDamage or 0) end
    if statLabels.CooldownReduction then statLabels.CooldownReduction.Text = string.format("%.1f%%", (s.CooldownReduction or 0) * 100) end
end

playerStatsUpdatedEvent.OnClientEvent:Connect(function(stats: any)
    if typeof(stats) == "table" then
        clientStats = stats
        refreshProfileStats()
    end
end)

-- =============================================================================
-- 6. MERCHANT SHOP WINDOW
-- =============================================================================

local shopWindow = Instance.new("Frame")
shopWindow.Name = "MerchantShopWindow"
shopWindow.Size = UDim2.new(0, 640, 0, 420)
shopWindow.Position = UDim2.new(0.5, -320, 0.5, -210)
shopWindow.BackgroundColor3 = Color3.fromRGB(18, 24, 36)
shopWindow.BorderSizePixel = 0
shopWindow.Visible = false
shopWindow.Parent = screenGui

local shCorner = Instance.new("UICorner")
shCorner.CornerRadius = UDim.new(0, 10)
shCorner.Parent = shopWindow

local shStroke = Instance.new("UIStroke")
shStroke.Color = Color3.fromRGB(240, 180, 50)
shStroke.Thickness = 2
shStroke.Parent = shopWindow

local shHeader = Instance.new("TextLabel")
shHeader.Size = UDim2.new(1, -40, 0, 40)
shHeader.Position = UDim2.new(0, 18, 0, 0)
shHeader.BackgroundTransparency = 1
shHeader.Text = "MERCHANT BAZAAR"
shHeader.TextColor3 = Color3.fromRGB(255, 220, 70)
shHeader.Font = Enum.Font.GothamBlack
shHeader.TextSize = 16
shHeader.TextXAlignment = Enum.TextXAlignment.Left
shHeader.Parent = shopWindow

local shCloseBtn = Instance.new("TextButton")
shCloseBtn.Size = UDim2.new(0, 28, 0, 28)
shCloseBtn.Position = UDim2.new(1, -36, 0, 6)
shCloseBtn.BackgroundColor3 = Color3.fromRGB(45, 30, 35)
shCloseBtn.Text = "X"
shCloseBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
shCloseBtn.Font = Enum.Font.GothamBold
shCloseBtn.TextSize = 13
shCloseBtn.Parent = shopWindow
local shcCorner = Instance.new("UICorner")
shcCorner.CornerRadius = UDim.new(0, 6)
shcCorner.Parent = shCloseBtn

shCloseBtn.MouseButton1Click:Connect(function()
    shopWindow.Visible = false
end)

local shGreeting = Instance.new("TextLabel")
shGreeting.Size = UDim2.new(1, -36, 0, 30)
shGreeting.Position = UDim2.new(0, 18, 0, 36)
shGreeting.BackgroundTransparency = 1
shGreeting.Text = "Welcome to the shop!"
shGreeting.TextColor3 = Color3.fromRGB(200, 210, 230)
shGreeting.Font = Enum.Font.Gotham
shGreeting.TextSize = 11
shGreeting.TextWrapped = true
shGreeting.TextXAlignment = Enum.TextXAlignment.Left
shGreeting.Parent = shopWindow

local shopScroll = Instance.new("ScrollingFrame")
shopScroll.Name = "ShopItemsScroll"
shopScroll.Size = UDim2.new(1, -36, 1, -120)
shopScroll.Position = UDim2.new(0, 18, 0, 70)
shopScroll.BackgroundColor3 = Color3.fromRGB(12, 16, 26)
shopScroll.BorderSizePixel = 0
shopScroll.ScrollBarThickness = 4
shopScroll.ScrollBarImageColor3 = Color3.fromRGB(240, 180, 50)
shopScroll.Parent = shopWindow

local shScCorner = Instance.new("UICorner")
shScCorner.CornerRadius = UDim.new(0, 6)
shScCorner.Parent = shopScroll

local shopListLayout = Instance.new("UIListLayout")
shopListLayout.Padding = UDim.new(0, 6)
shopListLayout.Parent = shopScroll

-- Repair / Maintenance Footer Bar
local repairBtn = Instance.new("TextButton")
repairBtn.Size = UDim2.new(0, 180, 0, 32)
repairBtn.Position = UDim2.new(1, -198, 1, -40)
repairBtn.BackgroundColor3 = Color3.fromRGB(50, 110, 180)
repairBtn.Text = "Repair All Gear (35 G)"
repairBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
repairBtn.Font = Enum.Font.GothamBold
repairBtn.TextSize = 11
repairBtn.Visible = false
repairBtn.Parent = shopWindow

local rpCorner = Instance.new("UICorner")
rpCorner.CornerRadius = UDim.new(0, 6)
rpCorner.Parent = repairBtn

repairBtn.MouseButton1Click:Connect(function()
    if activeMerchantId then
        shopActionEvent:FireServer("Repair", activeMerchantId)
    end
end)

local function renderShop(merchantId: string, data: any)
    activeMerchantId = merchantId
    activeMerchantData = data

    shHeader.Text = string.format("%s — %s", data.name, data.title)
    shGreeting.Text = data.greeting or "What supplies do you seek?"
    repairBtn.Visible = (data.allowsRepair == true)

    -- Clear previous listings
    for _, child in ipairs(shopScroll:GetChildren()) do
        if child:IsA("GuiObject") and child ~= shopListLayout then
            child:Destroy()
        end
    end

    for _, def in ipairs(data.items or {}) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -8, 0, 50)
        row.BackgroundColor3 = Color3.fromRGB(22, 28, 42)
        row.BorderSizePixel = 0
        row.Parent = shopScroll

        local rCorner = Instance.new("UICorner")
        rCorner.CornerRadius = UDim.new(0, 6)
        rCorner.Parent = row

        local rStroke = Instance.new("UIStroke")
        rStroke.Color = RARITY_COLORS[def.rarity] or Color3.fromRGB(60, 80, 110)
        rStroke.Thickness = 1
        rStroke.Parent = row

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(0.55, 0, 0, 22)
        nameLabel.Position = UDim2.new(0, 10, 0, 4)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = def.name
        nameLabel.TextColor3 = RARITY_COLORS[def.rarity] or Color3.fromRGB(255, 255, 255)
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextSize = 12
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.Parent = row

        local descLabel = Instance.new("TextLabel")
        descLabel.Size = UDim2.new(0.55, 0, 0, 20)
        descLabel.Position = UDim2.new(0, 10, 0, 24)
        descLabel.BackgroundTransparency = 1
        descLabel.Text = def.description
        descLabel.TextColor3 = Color3.fromRGB(160, 175, 195)
        descLabel.Font = Enum.Font.Gotham
        descLabel.TextSize = 10
        descLabel.TextTruncate = Enum.TextTruncate.AtEnd
        descLabel.TextXAlignment = Enum.TextXAlignment.Left
        descLabel.Parent = row

        local priceLabel = Instance.new("TextLabel")
        priceLabel.Size = UDim2.new(0.2, 0, 1, 0)
        priceLabel.Position = UDim2.new(0.58, 0, 0, 0)
        priceLabel.BackgroundTransparency = 1
        priceLabel.Text = string.format("%d Gold", def.buyPrice)
        priceLabel.TextColor3 = Color3.fromRGB(255, 215, 60)
        priceLabel.Font = Enum.Font.GothamBold
        priceLabel.TextSize = 12
        priceLabel.Parent = row

        local buyBtn = Instance.new("TextButton")
        buyBtn.Size = UDim2.new(0, 75, 0, 30)
        buyBtn.Position = UDim2.new(1, -85, 0.5, -15)
        buyBtn.BackgroundColor3 = Color3.fromRGB(40, 140, 80)
        buyBtn.Text = "Buy"
        buyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        buyBtn.Font = Enum.Font.GothamBold
        buyBtn.TextSize = 11
        buyBtn.Parent = row

        local bCorner = Instance.new("UICorner")
        bCorner.CornerRadius = UDim.new(0, 5)
        bCorner.Parent = buyBtn

        buyBtn.MouseButton1Click:Connect(function()
            shopActionEvent:FireServer("Buy", merchantId, def.id, 1)
        end)
    end

    shopWindow.Visible = true
end

openShopEvent.OnClientEvent:Connect(function(merchantId: any, data: any)
    if typeof(merchantId) == "string" and typeof(data) == "table" then
        renderShop(merchantId, data)
    end
end)

shopResponseEvent.OnClientEvent:Connect(function(success: any, message: any, actionType: any)
    local msgColor = if success == true then Color3.fromRGB(80, 255, 120) else Color3.fromRGB(255, 80, 80)
    showToast(tostring(message or "Transaction processed."), msgColor)
end)

-- Attribute change listeners for Gold notifications
local lastGold = player:GetAttribute("Gold") or 0
player:GetAttributeChangedSignal("Gold"):Connect(function()
    local newGold = player:GetAttribute("Gold") or 0
    local diff = newGold - lastGold
    if diff > 0 then
        showToast(string.format("+%d Gold", diff), Color3.fromRGB(255, 220, 60))
    end
    lastGold = newGold
    refreshProfileStats()
end)

-- =============================================================================
-- 7. KEYBOARD SHORTCUTS ([I], [TAB], [P])
-- =============================================================================

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
    if gameProcessed then return end

    if input.KeyCode == Enum.KeyCode.I or input.KeyCode == Enum.KeyCode.Tab or input.KeyCode == Enum.KeyCode.ButtonY or input.KeyCode == Enum.KeyCode.ButtonSelect then
        inventoryWindow.Visible = not inventoryWindow.Visible
        if inventoryWindow.Visible then
            inventoryActionEvent:FireServer("RequestSync")
            task.delay(0.1, function()
                local firstSlot = itemScroll:FindFirstChildWhichIsA("TextButton")
                if firstSlot then
                    GuiService.SelectedObject = firstSlot
                end
            end)
        else
            GuiService.SelectedObject = nil
        end
    elseif input.KeyCode == Enum.KeyCode.P or input.KeyCode == Enum.KeyCode.ButtonL3 then
        profileWindow.Visible = not profileWindow.Visible
        if profileWindow.Visible then
            refreshProfileStats()
        end
    end
end)

-- Request initial inventory and character stats
task.spawn(function()
    task.wait(1.0)
    inventoryActionEvent:FireServer("RequestSync")
    updateHUD()
end)

print("[RPGProfileUIController] Initialized: Inventory [I/Tab], Profile [P], HUD XP Bar, and Merchant Shop.")