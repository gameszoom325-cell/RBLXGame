--!strict
--[[
    EnemyManager.lua
    Server-authoritative Enemy AI and NPC Spawning Pipeline:
    Spawns enemies at world nodes, manages health bars and hitboxes,
    awards rewards on defeat, and triggers automated respawn cycles.
]]

local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Systems = ReplicatedStorage:WaitForChild("Systems")

local LootDatabase = require(Shared:WaitForChild("LootDatabase"))
local QuestManager = require(Systems:WaitForChild("QuestManager"))
local ProgressionManager = require(Systems:WaitForChild("ProgressionManager"))
local EconomyManager = require(Systems:WaitForChild("EconomyManager"))
local InventoryManager = require(Systems:WaitForChild("InventoryManager"))
local PlayerDataService = require(Systems:WaitForChild("PlayerDataService"))
local PartyService = require(Systems:WaitForChild("PartyService"))

local networkFolder = ReplicatedStorage:WaitForChild("Network")
local damageDealtEvent = networkFolder:WaitForChild("DamageDealt") :: RemoteEvent

local EnemyManager = {}

local activeEnemies: { [Model]: { enemyType: string, maxHp: number, currentHp: number, respawnNode: Vector3 } } = {}

-- Utility to create floating overhead health bar
local function attachHealthBar(enemyModel: Model, maxHealth: number): BillboardGui
    local head = enemyModel:FindFirstChild("Head") or enemyModel.PrimaryPart
    if not head then return Instance.new("BillboardGui") end

    local bb = Instance.new("BillboardGui")
    bb.Name = "EnemyHealthBar"
    bb.Size = UDim2.new(0, 120, 0, 18)
    bb.StudsOffset = Vector3.new(0, 2.5, 0)
    bb.AlwaysOnTop = true

    local bg = Instance.new("Frame")
    bg.Name = "Background"
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    bg.BorderSizePixel = 0
    bg.Parent = bb

    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.new(1, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
    fill.BorderSizePixel = 0
    fill.Parent = bg

    bb.Parent = head
    return bb
end

function EnemyManager.SpawnEnemy(enemyType: string, position: Vector3): Model
    local enemy = Instance.new("Model")
    enemy.Name = enemyType

    local hrp = Instance.new("Part")
    hrp.Name = "HumanoidRootPart"
    hrp.Size = Vector3.new(2, 2, 2)
    hrp.CFrame = CFrame.new(position)
    hrp.Transparency = 1
    hrp.CanCollide = false
    hrp.Anchored = false
    hrp.Parent = enemy
    enemy.PrimaryPart = hrp

    local body = Instance.new("Part")
    body.Name = "Torso"
    body.Size = Vector3.new(2.4, 2.4, 2.4)
    body.CFrame = CFrame.new(position)
    body.Color = if enemyType == "TempestDrone" then Color3.fromRGB(45, 55, 75) else Color3.fromRGB(120, 35, 45)
    body.Material = Enum.Material.Metal
    body.CanCollide = true
    body.Anchored = false
    body.Parent = enemy

    local bodyWeld = Instance.new("WeldConstraint")
    bodyWeld.Part0 = hrp
    bodyWeld.Part1 = body
    bodyWeld.Parent = body

    -- Glowing core
    local core = Instance.new("Part")
    core.Name = "Core"
    core.Shape = Enum.PartType.Ball
    core.Size = Vector3.new(1.2, 1.2, 1.2)
    core.CFrame = CFrame.new(position)
    core.Color = Color3.fromRGB(255, 75, 75)
    core.Material = Enum.Material.Neon
    core.CanCollide = false
    core.Anchored = false
    core.Parent = enemy

    local coreWeld = Instance.new("WeldConstraint")
    coreWeld.Part0 = body
    coreWeld.Part1 = core
    coreWeld.Parent = core

    local isDrone = (enemyType == "TempestDrone")
    local level = if isDrone then 3 else 6
    local maxHp = if isDrone then 120 else 300
    local xpReward = if isDrone then 50 else 150
    local goldReward = if isDrone then 25 else 100

    -- 15% Chance to roll an Elite Variant
    local isElite = (math.random() <= 0.15)
    local elitePrefixes = { "Electrified", "Thunderforged", "Tempest-Crowned" }
    local elitePrefix = if isElite then elitePrefixes[math.random(1, #elitePrefixes)] else nil

    if isElite and elitePrefix then
        maxHp = math.floor(maxHp * 2.5)
        xpReward = math.floor(xpReward * 3.0)
        goldReward = math.floor(goldReward * 3.0)
        level += 2

        enemy:SetAttribute("IsElite", true)
        enemy:SetAttribute("ElitePrefix", elitePrefix)

        -- Distinctive Elite Glowing Particle Aura
        local aura = Instance.new("ParticleEmitter")
        aura.Color = ColorSequence.new(Color3.fromRGB(255, 215, 60), Color3.fromRGB(65, 225, 255))
        aura.Size = NumberSequence.new(0.6, 1.2)
        aura.Rate = 25
        aura.Speed = NumberRange.new(2, 5)
        aura.Parent = body

        print(string.format("[EnemyManager] *** ELITE SIGHTED! *** A %s %s [Lv. %d] appeared!", elitePrefix, enemyType, level))
    end

    enemy:SetAttribute("EnemyType", enemyType)
    enemy:SetAttribute("Level", level)
    enemy:SetAttribute("MaxHealth", maxHp)
    enemy:SetAttribute("CurrentHealth", maxHp)
    enemy:SetAttribute("XPReward", xpReward)
    enemy:SetAttribute("GoldReward", goldReward)

    local humanoid = Instance.new("Humanoid")
    humanoid.MaxHealth = maxHp
    humanoid.Health = maxHp
    humanoid.DisplayName = if isElite and elitePrefix
        then string.format("[Elite] %s %s [Lv. %d]", elitePrefix, enemyType, level)
        else string.format("%s [Lv. %d]", enemyType, level)
    humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.AlwaysOn
    humanoid.Parent = enemy

    attachHealthBar(enemy, maxHp)

    -- Anchor loosely to prevent falling off world while idling
    local bodyPos = Instance.new("BodyPosition")
    bodyPos.Position = position + Vector3.new(0, 1.5, 0)
    bodyPos.MaxForce = Vector3.new(4000, 4000, 4000)
    bodyPos.D = 250
    bodyPos.Parent = hrp

    enemy.Parent = Workspace

    activeEnemies[enemy] = {
        enemyType = enemyType,
        maxHp = maxHp,
        currentHp = maxHp,
        respawnNode = position,
    }

    -- Listen for health depletion
    humanoid.Died:Connect(function()
        EnemyManager.OnEnemyDefeated(enemy)
    end)

    return enemy
end

function EnemyManager.DamageEnemy(enemy: Model, damage: number, player: Player?, damageType: string?)
    local humanoid = enemy:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    -- Check if target is a Boss (e.g. Storm Titan)
    if enemy:GetAttribute("EnemyType") == "Boss" then
        local bossManagerModule = Systems:FindFirstChild("BossManager")
        if bossManagerModule then
            local BossManager = require(bossManagerModule) :: any
            if BossManager.DamageBoss and player then
                BossManager.DamageBoss(enemy, damage, player)
            end
        end
        return
    end

    local data = activeEnemies[enemy]
    local hitPart = enemy.PrimaryPart or enemy:FindFirstChild("Torso") or enemy:FindFirstChild("HumanoidRootPart")
    local hitPos = if hitPart and hitPart:IsA("BasePart") then hitPart.Position + Vector3.new(0, 1.5, 0) else Vector3.new(0, 5, 0)

    humanoid:TakeDamage(damage)
    enemy:SetAttribute("CurrentHealth", humanoid.Health)

    -- Broadcast floating combat text to all clients
    damageDealtEvent:FireAllClients(damage, hitPos, damageType or "Normal")

    -- Group Aggro: Alert nearby allies within 35 studs
    if player and player.Character and player.Character.PrimaryPart then
        for otherModel, _ in pairs(activeEnemies) do
            if otherModel ~= enemy and otherModel.Parent and not otherModel:GetAttribute("IsDead") then
                local oRoot = otherModel.PrimaryPart
                if oRoot and (oRoot.Position - hitPos).Magnitude <= 35.0 then
                    otherModel:SetAttribute("AggroTarget", player.Name)
                end
            end
        end
    end

    if data then
        data.currentHp = humanoid.Health

        -- Update health bar fill
        local bb = enemy:FindFirstChild("EnemyHealthBar", true) :: BillboardGui?
        if bb then
            local bg = bb:FindFirstChild("Background") :: Frame?
            local fill = bg and bg:FindFirstChild("Fill") :: Frame?
            if fill then
                fill.Size = UDim2.new(math.clamp(humanoid.Health / data.maxHp, 0, 1), 0, 1, 0)
            end
        end

        -- Ensure kill objective progress, rewards, and defeat sequence fire exactly once
        if humanoid.Health <= 0 and not enemy:GetAttribute("IsDead") then
            enemy:SetAttribute("IsDead", true)
            if player then
                local xpGain = enemy:GetAttribute("XPReward") or data.maxHp
                local baseGold = enemy:GetAttribute("GoldReward") or 25

                -- Award Shared Party XP (with +15% per nearby party member bonus)
                PartyService.DistributeSharedXP(player, xpGain, data.enemyType)

                -- Roll and distribute weighted drops from LootDatabase to party
                local rolledLoot = LootDatabase.RollLoot(data.enemyType)
                local totalGold = baseGold + rolledLoot.gold
                PartyService.DistributeSharedLoot(player, totalGold, rolledLoot.items, data.enemyType)

                -- Track statistics in persistent PlayerDataService
                PlayerDataService.UpdatePlayerData(player, function(pData)
                    pData.Stats.EnemyKills += 1
                end)

                -- Check milestone achievements
                local achModule = Systems:FindFirstChild("AchievementManager")
                if achModule then
                    local AchievementManager = require(achModule) :: any
                    if AchievementManager.CheckStatMilestones then
                        AchievementManager.CheckStatMilestones(player)
                    end
                end

                -- Dungeon Guardian Objective Check
                if enemy:GetAttribute("IsGuardian") == true then
                    local dungeonModule = Systems:FindFirstChild("DungeonManager")
                    if dungeonModule then
                        local DungeonManager = require(dungeonModule) :: any
                        if DungeonManager.ProgressObjective then
                            DungeonManager.ProgressObjective("Guardians", 1)
                        end
                    end
                end

                -- Update quest objectives
                QuestManager.ProgressObjective(player, "KillEnemy", 1)
                print(string.format("[EnemyManager] %s defeated %s! (+%d XP, +%d Gold, %d item drops)",
                    player.Name, data.enemyType, xpGain, totalGold, #rolledLoot.items))
            end
            EnemyManager.OnEnemyDefeated(enemy)
        end
    else
        -- Support for Training Dummies or non-node targets in workspace
        if humanoid.Health <= 0 then
            task.delay(1.5, function()
                if humanoid and humanoid.Parent then
                    humanoid.Health = humanoid.MaxHealth
                    enemy:SetAttribute("CurrentHealth", humanoid.MaxHealth)
                end
            end)
        end
    end
end

-- Backward compatibility alias
EnemyManager.TakeDamage = EnemyManager.DamageEnemy

function EnemyManager.GetActiveEnemies(): { [Model]: { enemyType: string, maxHp: number, currentHp: number, respawnNode: Vector3 } }
    return activeEnemies
end

function EnemyManager.OnEnemyDefeated(enemy: Model)
    local data = activeEnemies[enemy]
    if not data then return end

    local respawnPos = data.respawnNode
    local enemyType = data.enemyType
    activeEnemies[enemy] = nil

    -- Defeat particle explosion
    local root = enemy.PrimaryPart
    if root then
        local emitter = Instance.new("ParticleEmitter")
        emitter.Color = ColorSequence.new(Color3.fromRGB(255, 80, 80))
        emitter.LightEmission = 1
        emitter.Rate = 100
        emitter.Speed = NumberRange.new(5, 12)
        emitter.Lifetime = NumberRange.new(0.3, 0.6)
        emitter.Parent = root
        task.delay(0.5, function()
            enemy:Destroy()
        end)
    else
        enemy:Destroy()
    end

    -- Respawn timer
    task.delay(8.0, function()
        EnemyManager.SpawnEnemy(enemyType, respawnPos)
    end)
end

-- Initialize spawning at marked nodes
function EnemyManager.InitNodes()
    local wilds = Workspace:FindFirstChild("Zone_TempestWilds")
    local nodesFolder = wilds and wilds:FindFirstChild("EnemySpawnNodes")
    if nodesFolder then
        for _, node in ipairs(nodesFolder:GetChildren()) do
            if node:IsA("BasePart") then
                local eType = node:GetAttribute("EnemyType") or "TempestDrone"
                EnemyManager.SpawnEnemy(eType, node.Position)
            end
        end
    end
end

return EnemyManager
