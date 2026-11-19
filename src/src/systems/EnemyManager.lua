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

local Systems = ReplicatedStorage:WaitForChild("Systems")
local QuestManager = require(Systems:WaitForChild("QuestManager"))

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

    local humanoid = Instance.new("Humanoid")
    local maxHp = if enemyType == "TempestDrone" then 120 else 300
    humanoid.MaxHealth = maxHp
    humanoid.Health = maxHp
    humanoid.DisplayName = string.format("%s [Lv. %d]", enemyType, if enemyType == "TempestDrone" then 3 else 6)
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

function EnemyManager.TakeDamage(enemy: Model, damage: number, attacker: Player?)
    local data = activeEnemies[enemy]
    if not data then return end

    local humanoid = enemy:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    humanoid:TakeDamage(damage)
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

    if humanoid.Health <= 0 and attacker then
        QuestManager.ProgressObjective(attacker, "KillEnemy", 1)
        print(string.format("[EnemyManager] %s defeated %s!", attacker.Name, data.enemyType))
    end
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
