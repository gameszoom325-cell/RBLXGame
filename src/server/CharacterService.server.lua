--!strict
--[[
    CharacterService.server.lua
    Server-authoritative modular character loader and hero manager.
    Connects to CharacterLoader to spawn, morph, and equip heroes.
    Uses static ReplicatedStorage.Network architecture.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Systems = ReplicatedStorage:WaitForChild("Systems")
local Types = require(Shared:WaitForChild("Types"))
local CharacterRegistry = require(Shared:WaitForChild("CharacterRegistry"))
local CharacterLoader = require(Shared:WaitForChild("CharacterLoader"))
local EnemyManager = require(Systems:WaitForChild("EnemyManager"))

local CharacterService = {}
local activePlayerCharacters: { [Player]: Types.CharacterId } = {}
local playerAttackDebounce: { [number]: number } = {}
local WEAPON_ATTACK_COOLDOWN = 0.55
local WEAPON_MAX_RANGE = 9.0
local WEAPON_BASE_DAMAGE = 65

-- Static Network Architecture
local networkFolder = ReplicatedStorage:WaitForChild("Network")
local selectHeroFunction = networkFolder:WaitForChild("SelectHero") :: RemoteFunction
local heroLoadedEvent = networkFolder:WaitForChild("HeroLoaded") :: RemoteEvent
local weaponAttackEvent = networkFolder:WaitForChild("WeaponAttack") :: RemoteEvent
local abilityVFXEvent = networkFolder:WaitForChild("ReplicateAbilityVFX") :: RemoteEvent

-- Core Character Loading Pipeline
function CharacterService.LoadHero(player: Player, heroId: Types.CharacterId): boolean
    local config = CharacterRegistry.GetCharacter(heroId)
    if not config then
        warn(string.format("[CharacterService] Hero ID %s not found in registry.", heroId))
        return false
    end

    local character = CharacterLoader.SpawnHero(player, heroId)
    if not character then
        return false
    end

    activePlayerCharacters[player] = heroId
    heroLoadedEvent:FireClient(player, heroId)
    return true
end

-- Handle remote hero selection
selectHeroFunction.OnServerInvoke = function(player: Player, heroId: any)
    if typeof(heroId) ~= "string" then return false end
    return CharacterService.LoadHero(player, heroId)
end

-- Server-authoritative Warhammer basic attack handler
weaponAttackEvent.OnServerEvent:Connect(function(player: Player)
    local character = player.Character
    if not character then return end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not humanoid or humanoid.Health <= 0 or not hrp then return end

    -- Verify player has the Warhammer equipped
    local equippedTool = character:FindFirstChild("Stormforge Warhammer") :: Tool?
    if not equippedTool then return end

    -- Enforce server-side attack debounce
    local now = os.clock()
    local lastAttack = playerAttackDebounce[player.UserId] or 0
    if now - lastAttack < WEAPON_ATTACK_COOLDOWN then return end
    playerAttackDebounce[player.UserId] = now

    local attackOrigin = hrp.Position
    local lookVector = hrp.CFrame.LookVector
    local hitCount = 0

    for _, item in ipairs(Workspace:GetDescendants()) do
        if item:IsA("Model") and item:FindFirstChildOfClass("Humanoid") then
            if not Players:GetPlayerFromCharacter(item) then
                local enemyRoot = item.PrimaryPart or item:FindFirstChild("HumanoidRootPart") or item:FindFirstChild("Torso") :: BasePart?
                if enemyRoot then
                    local offset = enemyRoot.Position - attackOrigin
                    local distance = offset.Magnitude
                    if distance <= WEAPON_MAX_RANGE then
                        -- Check forward cone (dot product > -0.25)
                        local dot = offset.Unit:Dot(lookVector)
                        if dot > -0.25 then
                            EnemyManager.TakeDamage(item, WEAPON_BASE_DAMAGE, player)
                            hitCount += 1
                        end
                    end
                end
            end
        end
    end

    if hitCount > 0 then
        abilityVFXEvent:FireAllClients("ThunderHammerSlam", {
            caster = character,
            origin = attackOrigin + (lookVector * 3),
            color = Color3.fromRGB(120, 240, 255),
            radius = 6,
        })
    end
end)

Players.PlayerRemoving:Connect(function(player)
    activePlayerCharacters[player] = nil
    playerAttackDebounce[player.UserId] = nil
end)

return CharacterService
