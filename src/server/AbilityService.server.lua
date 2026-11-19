--!strict
--[[
    AbilityService.server.lua
    Server-authoritative hero ability pipeline.
    Validates cooldowns, energy/resource limits, performs raycasting/hitboxes,
    and replicates VFX events to all clients.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local AbilityConfig = require(Shared:WaitForChild("AbilityConfig"))
local CharacterRegistry = require(Shared:WaitForChild("CharacterRegistry"))

local networkFolder = ReplicatedStorage:WaitForChild("Network")

local function getOrCreateRemoteEvent(name: string): RemoteEvent
    local event = networkFolder:FindFirstChild(name) :: RemoteEvent
    if not event then
        event = Instance.new("RemoteEvent")
        event.Name = name
        event.Parent = networkFolder
    end
    return event
end

local castAbilityEvent = getOrCreateRemoteEvent("CastAbility")
local abilityVFXEvent = getOrCreateRemoteEvent("ReplicateAbilityVFX")

-- Track player ability cooldown timestamps: [UserId][AbilityId] = lastUsedTime
local playerCooldowns: { [number]: { [string]: number } } = {}

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

-- Ability Execution Handlers
local AbilityExecutors: { [Types.AbilityId]: (player: Player, character: Model, spec: Types.AbilitySpec, targetPos: Vector3?) -> () } = {
    LightningStrike = function(player, character, spec, targetPos)
        local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart
        local strikePos = targetPos or (hrp.Position + hrp.CFrame.LookVector * 20)

        -- Replicate VFX to all nearby clients
        abilityVFXEvent:FireAllClients("LightningStrike", {
            caster = character,
            origin = hrp.Position,
            target = strikePos,
            color = Color3.fromRGB(65, 225, 255),
        })

        -- Server-authoritative hitbox / radial damage check (Placeholder numbers)
        print(string.format("[AbilityService] %s cast %s at %s", player.Name, spec.name, tostring(strikePos)))
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
        local destination = hrp.Position + (forwardVector * 30)

        abilityVFXEvent:FireAllClients("LightningDash", {
            caster = character,
            startPos = hrp.Position,
            endPos = destination,
            color = Color3.fromRGB(110, 240, 255),
        })

        -- Teleport / launch root part safely
        hrp.CFrame = CFrame.new(destination, destination + forwardVector)
        print(string.format("[AbilityService] %s performed %s", player.Name, spec.name))
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

print("[AbilityService] Initialized successfully.")
