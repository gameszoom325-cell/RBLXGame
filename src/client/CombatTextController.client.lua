--!strict
--[[
    CombatTextController.client.lua
    Client-side Floating Combat Text and Animated Damage Numbers:
    - Listens to ReplicatedStorage.Network.DamageDealt
    - Renders 3D billboard text in 5 distinct RPG damage tiers:
      * White: Normal physical strikes
      * Yellow: Critical blows ("CRIT! 120") with enlarged text
      * Blue / Cyan: Lightning & Thunder ability elemental shock
      * Green: Health restoration ("+60")
      * Red: Damage sustained by player
    - Smooth TweenService floating arc and alpha fade-out
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local networkFolder = ReplicatedStorage:WaitForChild("Network")
local damageDealtEvent = networkFolder:WaitForChild("DamageDealt") :: RemoteEvent

-- Palette configuration for damage tiers
local DAMAGE_COLORS = {
    Normal = Color3.fromRGB(255, 255, 255),
    Critical = Color3.fromRGB(255, 220, 50),
    Lightning = Color3.fromRGB(70, 225, 255),
    Healing = Color3.fromRGB(80, 255, 120),
    EnemyDamage = Color3.fromRGB(255, 65, 65),
}

local function spawnDamageNumber(amount: number, worldPosition: Vector3, damageType: string?)
    local dtype = damageType or "Normal"
    local color = DAMAGE_COLORS[dtype] or DAMAGE_COLORS.Normal
    local isCrit = (dtype == "Critical")
    local isHeal = (dtype == "Healing")

    -- Anchor adornment part in workspace.Terrain so BillboardGui has a stable parent
    local attachPart = Instance.new("Part")
    attachPart.Name = "CombatTextAnchor"
    attachPart.Size = Vector3.new(0.1, 0.1, 0.1)
    attachPart.Transparency = 1
    attachPart.CanCollide = false
    attachPart.CanTouch = false
    attachPart.CanQuery = false
    attachPart.Anchored = true

    -- Introduce slight random horizontal jitter to separate multi-hit combo numbers
    local jitterX = (math.random() - 0.5) * 1.8
    local jitterZ = (math.random() - 0.5) * 1.8
    attachPart.Position = worldPosition + Vector3.new(jitterX, 0, jitterZ)
    attachPart.Parent = workspace.Terrain

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "DamageBillboard"
    billboard.Size = if isCrit then UDim2.new(0, 160, 0, 45) else UDim2.new(0, 120, 0, 35)
    billboard.StudsOffset = Vector3.new(0, 0.5, 0)
    billboard.AlwaysOnTop = true
    billboard.Adornee = attachPart
    billboard.Parent = attachPart

    local label = Instance.new("TextLabel")
    label.Name = "NumberLabel"
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = color
    label.TextStrokeColor3 = Color3.fromRGB(15, 15, 20)
    label.TextStrokeTransparency = 0.1
    label.Font = if isCrit then Enum.Font.GothamBlack else Enum.Font.GothamBold
    label.TextSize = if isCrit then 24 else 18
    label.TextScaled = false

    local displayStr = tostring(math.floor(amount))
    if isCrit then
        displayStr = "CRIT! " .. displayStr
    elseif isHeal then
        displayStr = "+" .. displayStr
    end
    label.Text = displayStr
    label.Parent = billboard

    -- Float upwards and fade out
    local floatDuration = if isCrit then 0.95 else 0.75
    local targetOffset = Vector3.new(0, if isCrit then 4.0 else 3.0, 0)

    local offsetTween = TweenService:Create(
        billboard,
        TweenInfo.new(floatDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { StudsOffset = targetOffset }
    )

    -- Delayed transparency fade
    task.delay(floatDuration * 0.4, function()
        local fadeTween = TweenService:Create(
            label,
            TweenInfo.new(floatDuration * 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            { TextTransparency = 1, TextStrokeTransparency = 1 }
        )
        fadeTween:Play()
    end)

    offsetTween:Play()
    offsetTween.Completed:Connect(function()
        attachPart:Destroy()
    end)
end

damageDealtEvent.OnClientEvent:Connect(function(amount: any, worldPos: any, damageType: any)
    if typeof(amount) == "number" and typeof(worldPos) == "Vector3" then
        spawnDamageNumber(amount, worldPos, if typeof(damageType) == "string" then damageType else "Normal")
    end
end)

print("[CombatTextController] Initialized with 5 damage number categories.")