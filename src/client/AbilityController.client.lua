--!strict
--[[
    AbilityController.client.lua
    Client-side ability trigger handling, cooldown prediction, and visual effect rendering.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local AbilityConfig = require(Shared:WaitForChild("AbilityConfig"))
local CharacterRegistry = require(Shared:WaitForChild("CharacterRegistry"))

local player = Players.LocalPlayer
local networkFolder = ReplicatedStorage:WaitForChild("Network")
local castAbilityEvent = networkFolder:WaitForChild("CastAbility") :: RemoteEvent
local abilityVFXEvent = networkFolder:WaitForChild("ReplicateAbilityVFX") :: RemoteEvent

local localCooldowns: { [string]: number } = {}
local activeHeroId: string? = nil

-- Check if local cooldown has elapsed
local function canCastLocally(abilityId: string, cooldown: number): boolean
    local lastCast = localCooldowns[abilityId] or 0
    return (os.clock() - lastCast) >= cooldown
end

-- Render Client Visual Effects
local VFXHandlers = {
    LightningStrike = function(data: any)
        local target = data.target :: Vector3
        local beamPart = Instance.new("Part")
        beamPart.Name = "LightningStrikeBolt"
        beamPart.Size = Vector3.new(0.8, 120, 0.8)
        beamPart.CFrame = CFrame.new(target + Vector3.new(0, 60, 0))
        beamPart.Color = data.color or Color3.fromRGB(65, 225, 255)
        beamPart.Material = Enum.Material.Neon
        beamPart.Anchored = true
        beamPart.CanCollide = false
        beamPart.Parent = workspace

        -- Quick flash and fade
        local tween = TweenService:Create(beamPart, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Transparency = 1,
            Size = Vector3.new(0.1, 120, 0.1),
        })
        tween:Play()
        tween.Completed:Connect(function()
            beamPart:Destroy()
        end)
    end,

    ThunderHammerSlam = function(data: any)
        local origin = data.origin :: Vector3
        local ring = Instance.new("Part")
        ring.Name = "ThunderShockwave"
        ring.Shape = Enum.PartType.Cylinder
        ring.Size = Vector3.new(0.5, 4, 4)
        ring.CFrame = CFrame.new(origin) * CFrame.Angles(0, 0, math.rad(90))
        ring.Color = data.color or Color3.fromRGB(80, 240, 255)
        ring.Material = Enum.Material.Neon
        ring.Anchored = true
        ring.CanCollide = false
        ring.Parent = workspace

        local tween = TweenService:Create(ring, TweenInfo.new(0.4, Enum.EasingStyle.ExponentialOut), {
            Size = Vector3.new(0.2, data.radius * 2 or 32, data.radius * 2 or 32),
            Transparency = 1,
        })
        tween:Play()
        tween.Completed:Connect(function()
            ring:Destroy()
        end)
    end,

    StormShield = function(data: any)
        local caster = data.caster :: Model
        if not caster then return end
        local hrp = caster:FindFirstChild("HumanoidRootPart") :: BasePart
        if not hrp then return end

        local shieldSphere = Instance.new("Part")
        shieldSphere.Name = "StormShieldSphere"
        shieldSphere.Shape = Enum.PartType.Ball
        shieldSphere.Size = Vector3.new(8, 8, 8)
        shieldSphere.CFrame = hrp.CFrame
        shieldSphere.Color = data.color or Color3.fromRGB(65, 225, 255)
        shieldSphere.Material = Enum.Material.ForceField
        shieldSphere.CanCollide = false
        shieldSphere.Massless = true
        shieldSphere.Parent = caster

        local weld = Instance.new("WeldConstraint")
        weld.Part0 = hrp
        weld.Part1 = shieldSphere
        weld.Parent = shieldSphere

        task.delay(data.duration or 4.0, function()
            local fade = TweenService:Create(shieldSphere, TweenInfo.new(0.3), { Transparency = 1 })
            fade:Play()
            fade.Completed:Connect(function()
                shieldSphere:Destroy()
            end)
        end)
    end,

    LightningDash = function(data: any)
        local startPos = data.startPos :: Vector3
        local endPos = data.endPos :: Vector3
        local distance = (endPos - startPos).Magnitude

        local trail = Instance.new("Part")
        trail.Name = "DashBoltTrail"
        trail.Size = Vector3.new(0.6, 0.6, distance)
        trail.CFrame = CFrame.new(startPos:Lerp(endPos, 0.5), endPos)
        trail.Color = data.color or Color3.fromRGB(110, 240, 255)
        trail.Material = Enum.Material.Neon
        trail.Anchored = true
        trail.CanCollide = false
        trail.Parent = workspace

        local fade = TweenService:Create(trail, TweenInfo.new(0.3), { Transparency = 1 })
        fade:Play()
        fade.Completed:Connect(function()
            trail:Destroy()
        end)
    end,
}

-- Handle input for ability casts
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or not activeHeroId then return end

    local characterConfig = CharacterRegistry.GetCharacter(activeHeroId)
    if not characterConfig then return end

    for _, abilityId in ipairs(characterConfig.abilities) do
        local spec = AbilityConfig[abilityId]
        if spec and input.KeyCode == spec.inputKey then
            if canCastLocally(abilityId, spec.cooldown) then
                localCooldowns[abilityId] = os.clock()

                -- Fetch mouse target position if raycast needed
                local mouse = player:GetMouse()
                local targetPos = mouse.Hit.Position

                -- Send cast request to server
                castAbilityEvent:FireServer(abilityId, targetPos)
                print(string.format("[AbilityController] Requesting cast: %s (%s)", spec.name, abilityId))
            else
                print(string.format("[AbilityController] %s is on cooldown.", spec.name))
            end
            break
        end
    end
end)

-- Receive replicated VFX
abilityVFXEvent.OnClientEvent:Connect(function(vfxType: string, data: any)
    local handler = VFXHandlers[vfxType]
    if handler then
        handler(data)
    end
end)

-- Update active hero upon server load confirmation
local heroLoadedEvent = networkFolder:WaitForChild("HeroLoaded") :: RemoteEvent
heroLoadedEvent.OnClientEvent:Connect(function(heroId: string)
    activeHeroId = heroId
    table.clear(localCooldowns)
    print(string.format("[AbilityController] Active hero set to %s. Abilities ready.", heroId))
end)

return {}
