--!strict
--[[
    AbilityService.server.lua
    Server-authoritative hero ability pipeline.
    Production security fixes:
      - Lightning Strike: Maximum 60-stud server range validation check.
      - Lightning Dash: Safe raycasted translation preventing wall-clipping and teleport exploits.
      - Static Network architecture (no dynamic creation race conditions).
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local AbilityConfig = require(Shared:WaitForChild("AbilityConfig"))
local CharacterRegistry = require(Shared:WaitForChild("CharacterRegistry"))

local networkFolder = ReplicatedStorage:WaitForChild("Network")
local castAbilityEvent = networkFolder:WaitForChild("CastAbility") :: RemoteEvent
local abilityVFXEvent = networkFolder:WaitForChild("ReplicateAbilityVFX") :: RemoteEvent

-- Track player ability cooldown timestamps: [UserId][AbilityId] = lastUsedTime
local playerCooldowns: { [number]: { [string]: number } } = {}

-- Security Constants
local MAX_LIGHTNING_STRIKE_DISTANCE = 60.0
local MAX_LIGHTNING_DASH_DISTANCE = 30.0

-- Secure validation of ability request
local function validateAbilityCast(player: Player, abilityId: Types.AbilityId): (boolean, Types.AbilitySpec?)
    local spec = AbilityConfig[abilityId]
    if not spec then
        warn(string.format("[AbilityService] Player %s requested unknown ability %s", player.Name, tostring(abilityId)))
        return false, nil
    end

    local character = player.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then
        return false, nil
    end

    local humanoid = character:FindFirstChild("Humanoid") :: Humanoid
    if not humanoid or humanoid.Health <= 0 then
        return false, nil
    end

    -- Verify player has this hero equipped
    local heroId = character:GetAttribute("HeroId")
    if not heroId then return false, nil end

    local heroConfig = CharacterRegistry.GetCharacter(heroId)
    if not heroConfig or not table.find(heroConfig.abilities, abilityId) then
        warn(string.format("[AbilityService] Exploitation attempt: Player %s does not own ability %s", player.Name, abilityId))
        return false, nil
    end

    -- Verify server-side cooldown
    local userId = player.UserId
    playerCooldowns[userId] = playerCooldowns[userId] or {}
    local lastCast = playerCooldowns[userId][abilityId] or 0
    local now = os.clock()

    if now - lastCast < spec.cooldown then
        -- Cooldown not ready
        return false, nil
    end

    -- Update timestamp
    playerCooldowns[userId][abilityId] = now
    return true, spec
end

-- Ability Execution Handlers with Security Checks
local AbilityExecutors: { [Types.AbilityId]: (player: Player, character: Model, spec: Types.AbilitySpec, targetPos: Vector3?) -> () } = {
    LightningStrike = function(player, character, spec, targetPos)
        local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart
        local strikePos: Vector3

        if targetPos and typeof(targetPos) == "Vector3" then
            local offset = targetPos - hrp.Position
            if offset.Magnitude > MAX_LIGHTNING_STRIKE_DISTANCE then
                -- Clamp to maximum server range
                strikePos = hrp.Position + (offset.Unit * MAX_LIGHTNING_STRIKE_DISTANCE)
            else
                strikePos = targetPos
            end
        else
            strikePos = hrp.Position + (hrp.CFrame.LookVector * 20)
        end

        -- Replicate VFX to all nearby clients
        abilityVFXEvent:FireAllClients("LightningStrike", {
            caster = character,
            origin = hrp.Position,
            target = strikePos,
            color = Color3.fromRGB(65, 225, 255),
        })

        print(string.format("[AbilityService] %s cast %s at validated position %s", player.Name, spec.name, tostring(strikePos)))
    end,

    ThunderHammerSlam = function(player, character, spec)
        local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart

        abilityVFXEvent:FireAllClients("ThunderHammerSlam", {
            caster = character,
            origin = hrp.Position,
            color = Color3.fromRGB(80, 240, 255),
            radius = 16,
        })

        print(string.format("[AbilityService] %s cast %s", player.Name, spec.name))
    end,

    StormShield = function(player, character, spec)
        abilityVFXEvent:FireAllClients("StormShield", {
            caster = character,
            duration = 4.0,
            color = Color3.fromRGB(65, 225, 255),
        })

        print(string.format("[AbilityService] %s activated %s", player.Name, spec.name))
    end,

    LightningDash = function(player, character, spec)
        local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart
        local forwardVector = hrp.CFrame.LookVector

        -- Raycast obstacle detection to prevent wall-clipping and out-of-bounds exploits
        local raycastParams = RaycastParams.new()
        raycastParams.FilterDescendantsInstances = { character }
        raycastParams.FilterType = Enum.RaycastFilterType.Exclude
        raycastParams.IgnoreWater = true

        local forwardRay = Workspace:Raycast(hrp.Position, forwardVector * MAX_LIGHTNING_DASH_DISTANCE, raycastParams)
        local destination: Vector3

        if forwardRay then
            -- Stop 2 studs before the detected wall/obstacle
            local safeDistance = math.max(0, forwardRay.Distance - 2.0)
            destination = hrp.Position + (forwardVector * safeDistance)
        else
            destination = hrp.Position + (forwardVector * MAX_LIGHTNING_DASH_DISTANCE)
        end

        -- Downward raycast to snap destination cleanly to ground level
        local groundRay = Workspace:Raycast(destination + Vector3.new(0, 5, 0), Vector3.new(0, -15, 0), raycastParams)
        if groundRay then
            destination = groundRay.Position + Vector3.new(0, hrp.Size.Y / 2, 0)
        end

        abilityVFXEvent:FireAllClients("LightningDash", {
            caster = character,
            startPos = hrp.Position,
            endPos = destination,
            color = Color3.fromRGB(110, 240, 255),
        })

        -- Safely update CFrame to validated destination
        hrp.CFrame = CFrame.new(destination, destination + forwardVector)
        print(string.format("[AbilityService] %s safely dashed to %s", player.Name, tostring(destination)))
    end,
}

-- Listen for client cast requests
castAbilityEvent.OnServerEvent:Connect(function(player: Player, abilityId: any, targetPos: any)
    if typeof(abilityId) ~= "string" then return end

    local valid, spec = validateAbilityCast(player, abilityId)
    if valid and spec then
        local executor = AbilityExecutors[abilityId]
        if executor and player.Character then
            executor(player, player.Character, spec, if typeof(targetPos) == "Vector3" then targetPos else nil)
        end
    end
end)

Players.PlayerRemoving:Connect(function(player)
    playerCooldowns[player.UserId] = nil
end)

print("[AbilityService] Initialized with strict server-side range validation and raycasted dash security.")
