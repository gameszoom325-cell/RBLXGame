--!strict
--[[
    CombatService.server.lua
    Master Server-Authoritative RPG Combat Pipeline:
    - Listens to ReplicatedStorage.Network.AttackRequest
    - Enforces 0.8s attack cooldown & 1.5s combo reset window
    - Tracks 3-hit Warhammer combo (Lightning Slash -> Storm Reverse Swing -> Thunder Breaker Slam)
    - Employs workspace:GetPartBoundsInBox() spatial query (8x8x10 studs, 5-stud forward offset)
    - Applies server-authoritative damage via EnemyManager.DamageEnemy
    - Zero trust of client damage or target parameters
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Systems = ReplicatedStorage:WaitForChild("Systems")
local EnemyManager = require(Systems:WaitForChild("EnemyManager"))

local networkFolder = ReplicatedStorage:WaitForChild("Network")
local attackRequestEvent = networkFolder:WaitForChild("AttackRequest") :: RemoteEvent
local abilityVFXEvent = networkFolder:WaitForChild("ReplicateAbilityVFX") :: RemoteEvent

-- Optional backward compatibility remote
local legacyWeaponAttack = networkFolder:FindFirstChild("WeaponAttack") :: RemoteEvent?

-- 3-Hit Combo Specification
type ComboAttack = {
    name: string,
    damage: number,
    vfxColor: Color3,
}

local COMBO_CHAIN: { [number]: ComboAttack } = {
    [1] = {
        name = "Lightning Slash",
        damage = 25,
        vfxColor = Color3.fromRGB(100, 220, 255),
    },
    [2] = {
        name = "Storm Reverse Swing",
        damage = 35,
        vfxColor = Color3.fromRGB(80, 240, 255),
    },
    [3] = {
        name = "Thunder Breaker Slam",
        damage = 60,
        vfxColor = Color3.fromRGB(255, 220, 80),
    },
}

local ATTACK_COOLDOWN = 0.80
local COMBO_RESET_WINDOW = 1.50
local HITBOX_SIZE = Vector3.new(8, 8, 10)
local HITBOX_FORWARD_OFFSET = 5.0

-- Per-player combo states: [UserId] = { currentStep, lastAttackTime }
type PlayerComboState = {
    currentStep: number,
    lastAttackTime: number,
}
local playerCombos: { [number]: PlayerComboState } = {}

local CombatService = {}

local function processAttack(player: Player)
    local character = player.Character
    if not character then return end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not humanoid or humanoid.Health <= 0 or not hrp then return end

    -- Verify the player actually has the Stormforge Warhammer equipped
    local equippedTool = character:FindFirstChild("Stormforge Warhammer") :: Tool?
    if not equippedTool then return end

    local userId = player.UserId
    local now = os.clock()
    local state = playerCombos[userId]

    if not state then
        state = { currentStep = 0, lastAttackTime = 0 }
        playerCombos[userId] = state
    end

    -- Enforce 0.8s attack cooldown
    if now - state.lastAttackTime < ATTACK_COOLDOWN then
        return
    end

    -- Determine next combo step (1 -> 2 -> 3 -> 1, or reset to 1 if > 1.5s idle)
    if (now - state.lastAttackTime) > COMBO_RESET_WINDOW or state.currentStep >= 3 then
        state.currentStep = 1
    else
        state.currentStep += 1
    end
    state.lastAttackTime = now

    local attackData = COMBO_CHAIN[state.currentStep]
    character:SetAttribute("CurrentComboStep", state.currentStep)
    character:SetAttribute("CurrentAttackName", attackData.name)

    -- Step 4: Server-Authoritative Hitbox via GetPartBoundsInBox
    -- Hitbox CFrame: 5 studs directly in front of HumanoidRootPart (-Z is forward in Roblox)
    local hitboxCFrame = hrp.CFrame * CFrame.new(0, 0, -HITBOX_FORWARD_OFFSET)

    local overlapParams = OverlapParams.new()
    overlapParams.FilterDescendantsInstances = { character }
    overlapParams.FilterType = Enum.RaycastFilterType.Exclude
    overlapParams.CollisionGroup = "Default"
    overlapParams.MaxParts = 50

    local partsInHitbox = Workspace:GetPartBoundsInBox(hitboxCFrame, HITBOX_SIZE, overlapParams)
    local hitModels: { [Model]: boolean } = {}
    local totalHits = 0

    for _, part in ipairs(partsInHitbox) do
        local targetModel = part:FindFirstAncestorOfClass("Model")
        if targetModel and not hitModels[targetModel] and targetModel ~= character then
            local targetHumanoid = targetModel:FindFirstChildOfClass("Humanoid")
            -- Verify it is not a player character
            if targetHumanoid and targetHumanoid.Health > 0 and not Players:GetPlayerFromCharacter(targetModel) then
                hitModels[targetModel] = true
                totalHits += 1

                -- Apply damage server-side via EnemyManager
                EnemyManager.DamageEnemy(targetModel, attackData.damage, player)
            end
        end
    end

    -- Replicate swing impact and weapon VFX to clients
    abilityVFXEvent:FireAllClients("ThunderHammerSlam", {
        caster = character,
        origin = hitboxCFrame.Position,
        color = attackData.vfxColor,
        radius = if state.currentStep == 3 then 8 else 5,
    })

    print(string.format("[CombatService] %s executed [%s] (Combo %d/3) - %d DMG across %d hit(s)",
        player.Name, attackData.name, state.currentStep, attackData.damage, totalHits))
end

-- Hook primary AttackRequest
attackRequestEvent.OnServerEvent:Connect(function(player: Player)
    processAttack(player)
end)

-- Hook legacy WeaponAttack if present
if legacyWeaponAttack then
    legacyWeaponAttack.OnServerEvent:Connect(function(player: Player)
        processAttack(player)
    end)
end

Players.PlayerRemoving:Connect(function(player)
    playerCombos[player.UserId] = nil
end)

print("[CombatService] Initialized with 3-hit combo and GetPartBoundsInBox hitbox.")

return CombatService
