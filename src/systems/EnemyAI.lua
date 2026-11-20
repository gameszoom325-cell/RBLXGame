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

export type AIState = "IDLE" | "PATROL" | "CHASE" | "ATTACK" | "RETREAT" | "RETURN"

type EnemyAIState = {
    state: AIState,
    lastAttackTime: number,
    lastAbilityTime: number,
    lastDodgeTime: number,
    dodgeOffset: Vector3,
    homePosition: Vector3,
    patrolTarget: Vector3?,
    lastPatrolSwitch: number,
    threatStartTime: number?,
}

local EnemyAI = {}
local enemyStates: { [Model]: EnemyAIState } = {}

-- Zero-allocation cached RaycastParams for Line of Sight
local cachedRaycastParams = RaycastParams.new()
cachedRaycastParams.FilterType = Enum.RaycastFilterType.Exclude
cachedRaycastParams.IgnoreWater = true

-- Utility for Line of Sight Raycasting
local function hasLineOfSight(origin: Vector3, targetPos: Vector3, enemyModel: Model, targetChar: Model): boolean
    cachedRaycastParams.FilterDescendantsInstances = { enemyModel, targetChar }
    local dir = (targetPos - origin)
    local result = Workspace:Raycast(origin, dir, cachedRaycastParams)
    return result == nil or result.Instance == nil or result.Instance.CanCollide == false
end

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

-- Frost Golem: Executes a glacial ground freeze slam
local function executeFrostGolemAttack(golem: Model, targetHrp: BasePart)
    local golemHrp = golem:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not golemHrp then return end
    local origin = golemHrp.Position

    local frostWave = Instance.new("Part")
    frostWave.Name = "FrostShockwave"
    frostWave.Shape = Enum.PartType.Cylinder
    frostWave.Size = Vector3.new(0.3, 3, 3)
    frostWave.CFrame = CFrame.new(origin.X, origin.Y - 1, origin.Z) * CFrame.Angles(0, 0, math.rad(90))
    frostWave.Color = Color3.fromRGB(130, 225, 255)
    frostWave.Material = Enum.Material.Ice
    frostWave.Anchored = true
    frostWave.CanCollide = false
    frostWave.Parent = Workspace

    local tween = TweenService:Create(frostWave, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(0.1, 18, 18),
        Transparency = 1,
    })
    tween:Play()
    tween.Completed:Connect(function()
        frostWave:Destroy()
    end)

    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
        if character and hrp and (hrp.Position - origin).Magnitude <= 12.0 then
            damagePlayer(character, 36, "FrostGolem")
        end
    end
end

-- Magma Stalker: Executes a flaming lunging swipe
local function executeMagmaStalkerAttack(stalker: Model, targetHrp: BasePart)
    local sHrp = stalker:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not sHrp then return end
    local origin = sHrp.Position

    local flameBurst = Instance.new("Part")
    flameBurst.Name = "MagmaBurst"
    flameBurst.Shape = Enum.PartType.Ball
    flameBurst.Size = Vector3.new(4, 4, 4)
    flameBurst.CFrame = CFrame.new(origin:Lerp(targetHrp.Position, 0.5))
    flameBurst.Color = Color3.fromRGB(255, 95, 25)
    flameBurst.Material = Enum.Material.Neon
    flameBurst.Anchored = true
    flameBurst.CanCollide = false
    flameBurst.Parent = Workspace

    local tween = TweenService:Create(flameBurst, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(9, 9, 9),
        Transparency = 1,
    })
    tween:Play()
    tween.Completed:Connect(function()
        flameBurst:Destroy()
    end)

    local char = targetHrp.Parent :: Model?
    if char then
        damagePlayer(char, 32, "MagmaStalker")
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
                lastAbilityTime = 0,
                lastDodgeTime = 0,
                dodgeOffset = Vector3.zero,
                homePosition = data.respawnNode,
                patrolTarget = nil,
                lastPatrolSwitch = now,
                threatStartTime = nil,
            }
            enemyStates[enemyModel] = ai
        end

        local isDrone = (data.enemyType == "TempestDrone")
        local isElite = (enemyModel:GetAttribute("IsElite") == true)
        local detectRadius = if isDrone then DRONE_DETECTION_RADIUS else BEAST_DETECTION_RADIUS
        local attackRadius = if isDrone then DRONE_ATTACK_RADIUS else BEAST_ATTACK_RADIUS
        local attackCooldown = if isDrone then (if isElite then 1.8 else DRONE_ATTACK_COOLDOWN) else (if isElite then 1.3 else BEAST_ATTACK_COOLDOWN)

        -- Group Aggro & Threat Decay
        local aggroName = enemyModel:GetAttribute("AggroTarget") :: string?
        if aggroName then
            if not ai.threatStartTime then
                ai.threatStartTime = now
            elseif now - ai.threatStartTime > 7.0 then
                -- Threat decay: reset aggro target after 7 seconds without refreshed hostility
                enemyModel:SetAttribute("AggroTarget", nil)
                ai.threatStartTime = nil
                aggroName = nil
            end
        end

        local aggroPlayer = if aggroName then Players:FindFirstChild(aggroName) else nil
        local targetChar: Model? = nil
        local distToTarget = 999.0

        if aggroPlayer and aggroPlayer:IsA("Player") and aggroPlayer.Character then
            local aHrp = aggroPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
            local aHum = aggroPlayer.Character:FindFirstChildOfClass("Humanoid")
            if aHrp and aHum and aHum.Health > 0 then
                targetChar = aggroPlayer.Character
                distToTarget = (aHrp.Position - hrp.Position).Magnitude
            else
                enemyModel:SetAttribute("AggroTarget", nil)
                ai.threatStartTime = nil
            end
        end

        if not targetChar then
            local _, nearestChar, nDist = findNearestPlayer(hrp.Position, MAX_LEASH_DISTANCE)
            targetChar = nearestChar
            distToTarget = nDist
        end

        local distFromHome = (hrp.Position - ai.homePosition).Magnitude
        local hpRatio = data.currentHp / data.maxHp

        -- Line of sight verification
        local hasLOS = true
        if targetChar and targetChar.PrimaryPart then
            hasLOS = hasLineOfSight(hrp.Position, targetChar.PrimaryPart.Position, enemyModel, targetChar)
        end

        -- State Machine Transitions
        if distFromHome > MAX_LEASH_DISTANCE or not targetChar then
            ai.state = if distFromHome > 4.0 then "RETURN" else "PATROL"
        elseif hpRatio <= 0.20 and distToTarget < 12.0 and not isDrone then
            ai.state = "RETREAT"
        elseif distToTarget <= attackRadius and hasLOS then
            ai.state = "ATTACK"
        elseif distToTarget <= detectRadius then
            ai.state = "CHASE"
        else
            ai.state = if distFromHome > 4.0 then "RETURN" else "PATROL"
        end

        enemyModel:SetAttribute("AIState", ai.state)

        -- State Execution
        -- Tactical Dodge Step Calculation
        if (ai.state == "CHASE" or ai.state == "ATTACK") and distToTarget < 16.0 then
            if now - ai.lastDodgeTime > 5.5 and math.random() <= 0.30 then
                ai.lastDodgeTime = now
                local dodgeDir = if math.random() > 0.5 then 1 else -1
                local lateral = Vector3.new(-hrp.CFrame.LookVector.Z, 0, hrp.CFrame.LookVector.X).Unit
                ai.dodgeOffset = lateral * (dodgeDir * 6.5)
            end
        end
        if now - ai.lastDodgeTime > 0.35 then
            ai.dodgeOffset = Vector3.zero
        end

        -- Smooth Orbital Circle Strafing / Flanking
        local strafeAngle = (now * 1.1)
        local strafeOffset = Vector3.new(math.cos(strafeAngle) * (if isDrone then 5.0 else 3.0), 0, math.sin(strafeAngle) * (if isDrone then 5.0 else 3.0))

        if ai.state == "CHASE" and targetChar then
            local targetHrp = targetChar:FindFirstChild("HumanoidRootPart") :: BasePart?
            if targetHrp then
                local targetPos = targetHrp.Position
                if isDrone then
                    bodyPos.Position = targetPos + Vector3.new(0, 5, 0) + strafeOffset + ai.dodgeOffset
                else
                    bodyPos.Position = Vector3.new(targetPos.X, ai.homePosition.Y + 1.5, targetPos.Z) + strafeOffset + ai.dodgeOffset
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
                    elseif data.enemyType == "FrostGolem" then
                        executeFrostGolemAttack(enemyModel, targetHrp)
                    elseif data.enemyType == "MagmaStalker" then
                        executeMagmaStalkerAttack(enemyModel, targetHrp)
                    else
                        executeBeastAttack(enemyModel, targetHrp)
                    end
                end

                -- Elite Special Ability Pulse
                if isElite and now - ai.lastAbilityTime >= 5.0 then
                    ai.lastAbilityTime = now
                    local char = targetHrp.Parent :: Model?
                    if char then
                        damagePlayer(char, 20, "EliteElectrifiedPulse")
                    end
                end
            end

        elseif ai.state == "RETREAT" and targetChar then
            -- Backpedal away from player
            local targetHrp = targetChar:FindFirstChild("HumanoidRootPart") :: BasePart?
            if targetHrp then
                local awayDir = (hrp.Position - targetHrp.Position).Unit
                bodyPos.Position = hrp.Position + (awayDir * 8)
                hrp.CFrame = CFrame.new(hrp.Position, Vector3.new(targetHrp.Position.X, hrp.Position.Y, targetHrp.Position.Z))
            end

        elseif ai.state == "RETURN" then
            -- Return back to home node
            if isDrone then
                bodyPos.Position = ai.homePosition + Vector3.new(0, 4, 0)
            else
                bodyPos.Position = ai.homePosition + Vector3.new(0, 1.5, 0)
            end
            hrp.CFrame = CFrame.new(hrp.Position, ai.homePosition)

        elseif ai.state == "PATROL" then
            -- Wanders slowly in radius around spawn node
            if not ai.patrolTarget or (now - ai.lastPatrolSwitch > 6.0) then
                local pAngle = math.random() * math.pi * 2
                local pDist = math.random(4, 14)
                ai.patrolTarget = ai.homePosition + Vector3.new(math.cos(pAngle) * pDist, if isDrone then 4 else 1.5, math.sin(pAngle) * pDist)
                ai.lastPatrolSwitch = now
            end

            if ai.patrolTarget then
                bodyPos.Position = ai.patrolTarget
                hrp.CFrame = CFrame.new(hrp.Position, ai.patrolTarget)
            end
    end
end)

function EnemyAI.Init()
    print("[EnemyAI] Heartbeat 4-state AI machine (IDLE/CHASE/ATTACK/RETURN) initialized successfully.")
end

return EnemyAI
