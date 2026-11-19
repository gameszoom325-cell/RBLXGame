--!strict
--[[
    EnemyAI.lua
    Server-authoritative State Machine AI for hostile NPCs:
    States: IDLE -> CHASE -> ATTACK -> RETURN
    Uses RunService.Heartbeat throttled to 5 Hz (0.2s) to avoid frame-budget waste.
    Handles flying drone projectiles and storm beast ground slams with StormShield reduction.
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Systems = ReplicatedStorage:WaitForChild("Systems")
local EnemyManager = require(Systems:WaitForChild("EnemyManager"))

export type AIState = "IDLE" | "CHASE" | "ATTACK" | "RETURN"

type EnemyAIState = {
    state: AIState,
    lastAttackTime: number,
    homePosition: Vector3,
}

local EnemyAI = {}
local enemyStates: { [Model]: EnemyAIState } = {}

-- AI Tuning Constants
local AI_TICK_RATE = 0.20 -- 5 updates per second, high efficiency
local DRONE_DETECTION_RADIUS = 40.0
local DRONE_ATTACK_RADIUS = 24.0
local DRONE_ATTACK_COOLDOWN = 2.4
local DRONE_PROJECTILE_DAMAGE = 18

local BEAST_DETECTION_RADIUS = 35.0
local BEAST_ATTACK_RADIUS = 8.0
local BEAST_ATTACK_COOLDOWN = 1.8
local BEAST_SLAM_DAMAGE = 28

local MAX_LEASH_DISTANCE = 55.0

-- Utility to find closest living player character within a radius
local function findNearestPlayer(position: Vector3, maxRadius: number): (Player?, Model?, number)
    local closestPlayer: Player? = nil
    local closestChar: Model? = nil
    local closestDist = maxRadius

    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        if character and character.Parent then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
            if humanoid and humanoid.Health > 0 and hrp then
                local dist = (hrp.Position - position).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    closestPlayer = player
                    closestChar = character
                end
            end
        end
    end

    return closestPlayer, closestChar, closestDist
end

-- Apply damage to a player character respecting StormShield reduction
local function damagePlayer(character: Model, baseDamage: number, sourceName: string)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    local finalDamage = baseDamage
    if character:GetAttribute("StormShieldActive") == true then
        finalDamage = math.floor(baseDamage * 0.8) -- 20% incoming damage reduction
    end

    humanoid:TakeDamage(finalDamage)
end

-- Tempest Drone: Shoots an electrostatic lightning projectile at player
local function executeDroneAttack(drone: Model, targetHrp: BasePart)
    local droneHrp = drone:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not droneHrp then return end

    local startPos = droneHrp.Position
    local endPos = targetHrp.Position

    -- Create high-voltage visual bolt beam
    local bolt = Instance.new("Part")
    bolt.Name = "DroneLightningBolt"
    bolt.Size = Vector3.new(0.4, 0.4, (endPos - startPos).Magnitude)
    bolt.CFrame = CFrame.new(startPos:Lerp(endPos, 0.5), endPos)
    bolt.Color = Color3.fromRGB(80, 220, 255)
    bolt.Material = Enum.Material.Neon
    bolt.Anchored = true
    bolt.CanCollide = false
    bolt.Parent = Workspace

    task.delay(0.2, function()
        bolt:Destroy()
    end)

    -- Impact burst
    local char = targetHrp.Parent :: Model?
    if char then
        damagePlayer(char, DRONE_PROJECTILE_DAMAGE, "TempestDrone")
    end
end

-- Storm Beast: Executes a ground shockwave slam
local function executeBeastAttack(beast: Model, targetHrp: BasePart)
    local beastHrp = beast:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not beastHrp then return end

    local origin = beastHrp.Position

    -- Ground shockwave visual ring
    local wave = Instance.new("Part")
    wave.Name = "BeastShockwave"
    wave.Shape = Enum.PartType.Cylinder
    wave.Size = Vector3.new(0.3, 2, 2)
    wave.CFrame = CFrame.new(origin.X, origin.Y - 1, origin.Z) * CFrame.Angles(0, 0, math.rad(90))
    wave.Color = Color3.fromRGB(255, 90, 60)
    wave.Material = Enum.Material.Neon
    wave.Anchored = true
    wave.CanCollide = false
    wave.Parent = Workspace

    local tween = TweenService:Create(wave, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(0.1, 16, 16),
        Transparency = 1,
    })
    tween:Play()
    tween.Completed:Connect(function()
        wave:Destroy()
    end)

    -- Area damage check
    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
        if character and hrp and (hrp.Position - origin).Magnitude <= 10.0 then
            damagePlayer(character, BEAST_SLAM_DAMAGE, "StormBeast")
        end
    end
end

-- Throttled Heartbeat state loop
local lastTick = 0
RunService.Heartbeat:Connect(function()
    local now = os.clock()
    if now - lastTick < AI_TICK_RATE then return end
    lastTick = now

    local activeEnemies = EnemyManager.GetActiveEnemies()

    for enemyModel, data in pairs(activeEnemies) do
        if not enemyModel.Parent or enemyModel:GetAttribute("IsDead") then
            enemyStates[enemyModel] = nil
            continue
        end

        local hrp = enemyModel:FindFirstChild("HumanoidRootPart") :: BasePart?
        local bodyPos = hrp and hrp:FindFirstChildOfClass("BodyPosition")
        if not hrp or not bodyPos then continue end

        local ai = enemyStates[enemyModel]
        if not ai then
            ai = {
                state = "IDLE",
                lastAttackTime = 0,
                homePosition = data.respawnNode,
            }
            enemyStates[enemyModel] = ai
        end

        local isDrone = (data.enemyType == "TempestDrone")
        local detectRadius = if isDrone then DRONE_DETECTION_RADIUS else BEAST_DETECTION_RADIUS
        local attackRadius = if isDrone then DRONE_ATTACK_RADIUS else BEAST_ATTACK_RADIUS
        local attackCooldown = if isDrone then DRONE_ATTACK_COOLDOWN else BEAST_ATTACK_COOLDOWN

        local _, targetChar, distToTarget = findNearestPlayer(hrp.Position, MAX_LEASH_DISTANCE)
        local distFromHome = (hrp.Position - ai.homePosition).Magnitude

        -- State Transitions
        if distFromHome > MAX_LEASH_DISTANCE or not targetChar then
            ai.state = if distFromHome > 4.0 then "RETURN" else "IDLE"
        elseif distToTarget <= attackRadius then
            ai.state = "ATTACK"
        elseif distToTarget <= detectRadius then
            ai.state = "CHASE"
        else
            ai.state = if distFromHome > 4.0 then "RETURN" else "IDLE"
        end

        enemyModel:SetAttribute("AIState", ai.state)

        -- State Execution
        if ai.state == "CHASE" and targetChar then
            local targetHrp = targetChar:FindFirstChild("HumanoidRootPart") :: BasePart?
            if targetHrp then
                local targetPos = targetHrp.Position
                if isDrone then
                    -- Flying movement: hover 5 studs above ground / target
                    bodyPos.Position = targetPos + Vector3.new(0, 5, 0)
                else
                    -- Ground pursuit
                    bodyPos.Position = Vector3.new(targetPos.X, ai.homePosition.Y + 1.5, targetPos.Z)
                end
                hrp.CFrame = CFrame.new(hrp.Position, Vector3.new(targetPos.X, hrp.Position.Y, targetPos.Z))
            end

        elseif ai.state == "ATTACK" and targetChar then
            local targetHrp = targetChar:FindFirstChild("HumanoidRootPart") :: BasePart?
            if targetHrp then
                hrp.CFrame = CFrame.new(hrp.Position, Vector3.new(targetHrp.Position.X, hrp.Position.Y, targetHrp.Position.Z))

                if now - ai.lastAttackTime >= attackCooldown then
                    ai.lastAttackTime = now
                    if isDrone then
                        executeDroneAttack(enemyModel, targetHrp)
                    else
                        executeBeastAttack(enemyModel, targetHrp)
                    end
                end
            end

        elseif ai.state == "RETURN" then
            -- Return back to home node
            if isDrone then
                bodyPos.Position = ai.homePosition + Vector3.new(0, 4, 0)
            else
                bodyPos.Position = ai.homePosition + Vector3.new(0, 1.5, 0)
            end
            hrp.CFrame = CFrame.new(hrp.Position, ai.homePosition)

        elseif ai.state == "IDLE" then
            -- Hover / idle at home anchor
            if isDrone then
                local hoverY = ai.homePosition.Y + 3.5 + math.sin(now * 2) * 0.8
                bodyPos.Position = Vector3.new(ai.homePosition.X, hoverY, ai.homePosition.Z)
            else
                bodyPos.Position = ai.homePosition + Vector3.new(0, 1.5, 0)
            end
        end
    end
end)

function EnemyAI.Init()
    print("[EnemyAI] Heartbeat 4-state AI machine (IDLE/CHASE/ATTACK/RETURN) initialized successfully.")
end

return EnemyAI
