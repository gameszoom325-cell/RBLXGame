--!strict
--[[
    BossManager.lua
    Server-authoritative Multi-Phase Boss Encounter Pipeline:
    - First Boss: Storm Titan (5,000 HP, 3 Combat Phases, Level 15)
    - Phase Transitions:
      * Phase 1 (100%-66%): Melee Cleave & Lightning Nova AOE
      * Phase 2 (66%-33%): Ground Fissures & Minion Summons
      * Phase 3 (33%-0%): Enraged Cataclysm (90s Enrage Timer, +50% ATK)
    - Threat/Aggro Table: Dynamic target selection based on player damage
    - Broadcasts BossStateUpdated for cinematic client boss health UI
    - Unique Legendary loot distribution and achievement triggers
]]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Systems = ReplicatedStorage:WaitForChild("Systems")

local ProgressionTypes = require(Shared:WaitForChild("ProgressionTypes"))
local ItemDatabase = require(Shared:WaitForChild("ItemDatabase"))
local LootDatabase = require(Shared:WaitForChild("LootDatabase"))
local ProgressionManager = require(Systems:WaitForChild("ProgressionManager"))
local EconomyManager = require(Systems:WaitForChild("EconomyManager"))
local InventoryManager = require(Systems:WaitForChild("InventoryManager"))
local PlayerDataService = require(Systems:WaitForChild("PlayerDataService"))
local QuestManager = require(Systems:WaitForChild("QuestManager"))

type BossPhase = ProgressionTypes.BossPhase

local networkFolder = ReplicatedStorage:WaitForChild("Network")
local bossStateUpdatedEvent = networkFolder:WaitForChild("BossStateUpdated") :: RemoteEvent
local abilityVFXEvent = networkFolder:WaitForChild("ReplicateAbilityVFX") :: RemoteEvent
local damageDealtEvent = networkFolder:WaitForChild("DamageDealt") :: RemoteEvent

local BossManager = {}

export type ActiveBoss = {
    id: string,
    model: Model,
    name: string,
    title: string,
    maxHp: number,
    currentHp: number,
    phase: BossPhase,
    isEnraged: boolean,
    enrageTime: number,
    threatTable: { [number]: number }, -- [UserId] = threat
    lastAbilityTime: number,
    lastAttackTime: number,
    homePosition: Vector3,
}

local activeBosses: { [Model]: ActiveBoss } = {}

-- Utility to get highest threat player
local function getTopThreatTarget(boss: ActiveBoss): (Player?, Model?)
    local topPlayer: Player? = nil
    local topThreat = -1

    for userId, threat in pairs(boss.threatTable) do
        local p = Players:GetPlayerByUserId(userId)
        if p and p.Character then
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 and threat > topThreat then
                topThreat = threat
                topPlayer = p
            end
        end
    end

    if topPlayer and topPlayer.Character then
        return topPlayer, topPlayer.Character
    end

    -- Fallback: closest living player within 80 studs
    local bossHrp = boss.model.PrimaryPart
    if not bossHrp then return nil, nil end

    local closestP: Player? = nil
    local closestDist = 80.0
    for _, p in ipairs(Players:GetPlayers()) do
        local c = p.Character
        local hrp = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
        local hum = c and c:FindFirstChildOfClass("Humanoid")
        if hrp and hum and hum.Health > 0 then
            local dist = (hrp.Position - bossHrp.Position).Magnitude
            if dist < closestDist then
                closestDist = dist
                closestP = p
            end
        end
    end

    return closestP, if closestP then closestP.Character else nil
end

local function broadcastBossState(boss: ActiveBoss?)
    if boss then
        bossStateUpdatedEvent:FireAllClients({
            id = boss.id,
            name = boss.name,
            title = boss.title,
            maxHealth = boss.maxHp,
            currentHealth = boss.currentHp,
            phase = boss.phase,
            isEnraged = boss.isEnraged,
            enrageTimeRemaining = math.max(0, math.floor(boss.enrageTime - os.clock())),
        })
    else
        bossStateUpdatedEvent:FireAllClients(nil)
    end
end

-- =============================================================================
-- BOSS ABILITIES & SPECIAL MOVES
-- =============================================================================

local function castLightningNova(boss: ActiveBoss)
    local root = boss.model.PrimaryPart
    if not root then return end

    local origin = root.Position

    -- Visual Nova Shockwave
    abilityVFXEvent:FireAllClients("ThunderHammerSlam", {
        caster = boss.model,
        origin = origin,
        color = Color3.fromRGB(80, 240, 255),
        radius = 28,
    })

    -- Deal 50 Lightning Damage in 26-stud radius
    for _, player in ipairs(Players:GetPlayers()) do
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hrp and hum and hum.Health > 0 then
            local dist = (hrp.Position - origin).Magnitude
            if dist <= 26.0 then
                local dmg = if boss.isEnraged then 75 else 50
                if char:GetAttribute("StormShieldActive") == true then
                    dmg = math.floor(dmg * 0.8)
                end
                hum:TakeDamage(dmg)
                damageDealtEvent:FireAllClients(dmg, hrp.Position, "EnemyDamage")
            end
        end
    end
    print(string.format("[BossManager] %s unleashed [Lightning Nova]!", boss.name))
end

local function castGroundFissure(boss: ActiveBoss, targetHrp: BasePart)
    local root = boss.model.PrimaryPart
    if not root then return end

    local origin = root.Position
    local dir = (targetHrp.Position - origin).Unit

    for i = 1, 4 do
        task.delay(i * 0.15, function()
            local stepPos = origin + (dir * (i * 10))
            abilityVFXEvent:FireAllClients("ThunderHammerSlam", {
                caster = boss.model,
                origin = stepPos,
                color = Color3.fromRGB(255, 120, 50),
                radius = 8,
            })

            -- Hit detection at fissure step
            for _, player in ipairs(Players:GetPlayers()) do
                local char = player.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hrp and hum and (hrp.Position - stepPos).Magnitude <= 8.0 then
                    local dmg = if boss.isEnraged then 90 else 65
                    if char:GetAttribute("StormShieldActive") == true then
                        dmg = math.floor(dmg * 0.8)
                    end
                    hum:TakeDamage(dmg)
                    damageDealtEvent:FireAllClients(dmg, hrp.Position, "EnemyDamage")
                end
            end
        end)
    end
    print(string.format("[BossManager] %s erupted [Ground Fissure] towards target!", boss.name))
end

local function spawnTempestMinions(boss: ActiveBoss)
    local root = boss.model.PrimaryPart
    if not root then return end

    print(string.format("[BossManager] %s summoned 2 Tempest Minions!", boss.name))
    local offsets = { Vector3.new(-12, 0, -10), Vector3.new(12, 0, -10) }

    for _, offset in ipairs(offsets) do
        local spawnPos = root.Position + offset
        local enemyManagerModule = Systems:FindFirstChild("EnemyManager")
        if enemyManagerModule then
            local EnemyManager = require(enemyManagerModule) :: any
            if EnemyManager.SpawnEnemy then
                EnemyManager.SpawnEnemy("TempestDrone", spawnPos)
            end
        end
    end
end

-- =============================================================================
-- SPAWN STORM TITAN
-- =============================================================================

function BossManager.SpawnStormTitan(position: Vector3): Model
    local bossModel = Instance.new("Model")
    bossModel.Name = "Storm Titan"

    -- Colossal RootPart
    local hrp = Instance.new("Part")
    hrp.Name = "HumanoidRootPart"
    hrp.Size = Vector3.new(8, 14, 8)
    hrp.CFrame = CFrame.new(position)
    hrp.Transparency = 1
    hrp.CanCollide = false
    hrp.Anchored = false
    hrp.Parent = bossModel
    bossModel.PrimaryPart = hrp

    -- Armored Colossus Torso (4x scale)
    local torso = Instance.new("Part")
    torso.Name = "Torso"
    torso.Size = Vector3.new(10, 12, 8)
    torso.CFrame = CFrame.new(position)
    torso.Color = Color3.fromRGB(30, 42, 64)
    torso.Material = Enum.Material.DiamondPlate
    torso.CanCollide = true
    torso.Anchored = false
    torso.Parent = bossModel

    local tWeld = Instance.new("WeldConstraint")
    tWeld.Part0 = hrp
    tWeld.Part1 = torso
    tWeld.Parent = torso

    -- Electrified Golem Core
    local core = Instance.new("Part")
    core.Name = "StormCore"
    core.Shape = Enum.PartType.Ball
    core.Size = Vector3.new(4, 4, 4)
    core.CFrame = CFrame.new(position)
    core.Color = Color3.fromRGB(65, 230, 255)
    core.Material = Enum.Material.Neon
    core.CanCollide = false
    core.Parent = bossModel

    local cWeld = Instance.new("WeldConstraint")
    cWeld.Part0 = torso
    cWeld.Part1 = core
    cWeld.Parent = core

    -- Crowned Helm Head
    local head = Instance.new("Part")
    head.Name = "Head"
    head.Size = Vector3.new(4, 4, 4)
    head.CFrame = CFrame.new(position + Vector3.new(0, 8, 0))
    head.Color = Color3.fromRGB(45, 55, 80)
    head.Material = Enum.Material.Metal
    head.CanCollide = false
    head.Parent = bossModel

    local hWeld = Instance.new("WeldConstraint")
    hWeld.Part0 = torso
    hWeld.Part1 = head
    hWeld.Parent = head

    -- Massive Titan Hammer Weapon Part
    local hammer = Instance.new("Part")
    hammer.Name = "ColossalWarhammer"
    hammer.Size = Vector3.new(3, 16, 3)
    hammer.CFrame = CFrame.new(position + Vector3.new(6, 4, -4))
    hammer.Color = Color3.fromRGB(65, 215, 255)
    hammer.Material = Enum.Material.Neon
    hammer.CanCollide = false
    hammer.Parent = bossModel

    local hwWeld = Instance.new("WeldConstraint")
    hwWeld.Part0 = torso
    hwWeld.Part1 = hammer
    hwWeld.Parent = hammer

    -- Humanoid Specs: 5,000 HP
    local humanoid = Instance.new("Humanoid")
    humanoid.MaxHealth = 5000
    humanoid.Health = 5000
    humanoid.DisplayName = "STORM TITAN [Boss]"
    humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.AlwaysOn
    humanoid.Parent = bossModel

    bossModel:SetAttribute("EnemyType", "Boss")
    bossModel:SetAttribute("MaxHealth", 5000)
    bossModel:SetAttribute("CurrentHealth", 5000)
    bossModel:SetAttribute("Phase", 1)

    -- Loosely bound BodyPosition for smooth tracking
    local bodyPos = Instance.new("BodyPosition")
    bodyPos.Position = position + Vector3.new(0, 7, 0)
    bodyPos.MaxForce = Vector3.new(100000, 100000, 100000)
    bodyPos.D = 400
    bodyPos.Parent = hrp

    bossModel.Parent = Workspace

    local activeData: ActiveBoss = {
        id = "StormTitan",
        model = bossModel,
        name = "Storm Titan",
        title = "The Tempest Colossus",
        maxHp = 5000,
        currentHp = 5000,
        phase = 1,
        isEnraged = false,
        enrageTime = os.clock() + 300, -- 5 minute hard enrage window
        threatTable = {},
        lastAbilityTime = os.clock(),
        lastAttackTime = os.clock(),
        homePosition = position,
    }

    activeBosses[bossModel] = activeData
    broadcastBossState(activeData)

    humanoid.Died:Connect(function()
        BossManager.OnBossDefeated(bossModel)
    end)

    print(string.format("[BossManager] Spawned %s (5,000 HP, Level 15) at %s", activeData.name, tostring(position)))
    return bossModel
end

-- =============================================================================
-- BOSS COMBAT & DAMAGE PIPELINE
-- =============================================================================

function BossManager.DamageBoss(bossModel: Model, damage: number, attacker: Player)
    local boss = activeBosses[bossModel]
    if not boss then return end

    local humanoid = bossModel:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    -- Update threat
    boss.threatTable[attacker.UserId] = (boss.threatTable[attacker.UserId] or 0) + damage

    humanoid:TakeDamage(damage)
    boss.currentHp = humanoid.Health
    bossModel:SetAttribute("CurrentHealth", boss.currentHp)

    -- Phase Transitions
    local hpPercent = boss.currentHp / boss.maxHp
    if hpPercent <= 0.33 and boss.phase < 3 then
        boss.phase = 3
        boss.isEnraged = true
        boss.enrageTime = os.clock() + 90 -- 90s soft enrage timer
        bossModel:SetAttribute("Phase", 3)
        print("[BossManager] *** PHASE 3: ENRAGED CATACLYSM ACTIVATED! ***")
        castLightningNova(boss)
    elseif hpPercent <= 0.66 and boss.phase < 2 then
        boss.phase = 2
        bossModel:SetAttribute("Phase", 2)
        print("[BossManager] *** PHASE 2: STORM SURGE & SUMMONS ACTIVATED! ***")
        spawnTempestMinions(boss)
    end

    broadcastBossState(boss)
end

function BossManager.OnBossDefeated(bossModel: Model)
    local boss = activeBosses[bossModel]
    if not boss then return end

    activeBosses[bossModel] = nil
    broadcastBossState(nil)

    print(string.format("[BossManager] *** %s DEFEATED! ***", boss.name))

    -- Distribute massive completion rewards across all attackers
    for userId, threat in pairs(boss.threatTable) do
        local p = Players:GetPlayerByUserId(userId)
        if p then
            -- Award 2,000 XP & 1,000 Gold
            ProgressionManager.AddXP(p, 2000, "Boss:" .. boss.name)
            EconomyManager.AddGold(p, 1000, "Boss:" .. boss.name)

            -- Drop guaranteed Epic / Legendary rewards
            InventoryManager.AddItem(p, "StormCore", 2)
            InventoryManager.AddItem(p, "ThunderClaymore", 1)
            InventoryManager.AddItem(p, "LegendaryHammerPart", 1)

            -- Update persistent stats
            PlayerDataService.UpdatePlayerData(p, function(pData)
                pData.Stats.BossKills += 1
            end)

            -- Progress Boss Quests
            QuestManager.ProgressObjective(p, "KillBoss", 1)

            -- Trigger Achievement
            local achModule = Systems:FindFirstChild("AchievementManager")
            if achModule then
                local AchievementManager = require(achModule) :: any
                if AchievementManager.Unlock then
                    AchievementManager.Unlock(p, "BossSlayer")
                end
            end
        end
    end

    -- Defeat explosion VFX
    local root = bossModel.PrimaryPart
    if root then
        abilityVFXEvent:FireAllClients("ThunderHammerSlam", {
            caster = bossModel,
            origin = root.Position,
            color = Color3.fromRGB(255, 220, 50),
            radius = 35,
        })
    end

    task.delay(1.5, function()
        bossModel:Destroy()
    end)
end

-- =============================================================================
-- BOSS AI HEARTBEAT LOOP (5 HZ)
-- =============================================================================

task.spawn(function()
    while true do
        task.wait(0.2)
        local now = os.clock()

        for bossModel, boss in pairs(activeBosses) do
            if not bossModel.Parent or boss.currentHp <= 0 then
                activeBosses[bossModel] = nil
                continue
            end

            local hrp = bossModel.PrimaryPart
            local bodyPos = hrp and hrp:FindFirstChildOfClass("BodyPosition")
            if not hrp or not bodyPos then continue end

            local targetPlayer, targetChar = getTopThreatTarget(boss)
            if targetChar and targetChar.PrimaryPart then
                local tPos = targetChar.PrimaryPart.Position
                local dist = (tPos - hrp.Position).Magnitude

                -- Face target
                hrp.CFrame = CFrame.new(hrp.Position, Vector3.new(tPos.X, hrp.Position.Y, tPos.Z))

                -- Move towards target
                if dist > 14.0 then
                    bodyPos.Position = Vector3.new(tPos.X, boss.homePosition.Y + 7, tPos.Z)
                end

                -- Melee Attack
                local atkCooldown = if boss.phase == 3 then 1.5 else (if boss.phase == 2 then 2.0 else 2.6)
                if now - boss.lastAttackTime >= atkCooldown and dist <= 16.0 then
                    boss.lastAttackTime = now
                    local hum = targetChar:FindFirstChildOfClass("Humanoid")
                    if hum then
                        local dmg = if boss.isEnraged then 55 else 35
                        hum:TakeDamage(dmg)
                        damageDealtEvent:FireAllClients(dmg, tPos, "EnemyDamage")
                    end
                end

                -- Special Ability Rotation
                local abilityCooldown = if boss.phase == 3 then 6.0 else 10.0
                if now - boss.lastAbilityTime >= abilityCooldown then
                    boss.lastAbilityTime = now
                    if boss.phase == 1 then
                        castLightningNova(boss)
                    elseif boss.phase == 2 then
                        castGroundFissure(boss, targetChar.PrimaryPart)
                    elseif boss.phase == 3 then
                        if math.random() > 0.5 then
                            castLightningNova(boss)
                        else
                            castGroundFissure(boss, targetChar.PrimaryPart)
                        end
                    end
                end
            end
        end
    end
end)

return BossManager