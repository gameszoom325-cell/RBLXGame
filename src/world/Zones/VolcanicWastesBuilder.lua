--!strict
--[[
    VolcanicWastesBuilder.lua
    Procedural builder for Zone 3: The Volcanic Wastes.
    Basalt crater terrain, molten lava fissures, obsidian spires, return portal, and fiery predator spawn nodes.
]]

local Workspace = game:GetService("Workspace")

local VolcanicWastesBuilder = {}

function VolcanicWastesBuilder.BuildZone(): Folder
    local existing = Workspace:FindFirstChild("Zone_VolcanicWastes")
    if existing then existing:Destroy() end

    local zone = Instance.new("Folder")
    zone.Name = "Zone_VolcanicWastes"
    zone.Parent = Workspace

    -- 1. Scorched Basalt Floor (300, 15, -300 studs)
    local floor = Instance.new("Part")
    floor.Name = "VolcanicFloor"
    floor.Size = Vector3.new(240, 2, 240)
    floor.CFrame = CFrame.new(300, 15, -300)
    floor.Color = Color3.fromRGB(35, 24, 22)
    floor.Material = Enum.Material.Basalt
    floor.Anchored = true
    floor.CanCollide = true
    floor.Parent = zone

    -- 2. Molten Lava Fissure Pools
    local function createLavaPool(cf: CFrame, size: Vector3)
        local lava = Instance.new("Part")
        lava.Name = "LavaPool"
        lava.Size = size
        lava.CFrame = cf
        lava.Color = Color3.fromRGB(255, 95, 25)
        lava.Material = Enum.Material.Neon
        lava.Anchored = true
        lava.CanCollide = false
        lava.Parent = zone

        local light = Instance.new("PointLight")
        light.Color = Color3.fromRGB(255, 120, 30)
        light.Brightness = 2.0
        light.Range = 28
        light.Parent = lava
    end

    createLavaPool(CFrame.new(300, 15.6, -300), Vector3.new(45, 0.4, 25))
    createLavaPool(CFrame.new(340, 15.6, -260), Vector3.new(25, 0.4, 35))
    createLavaPool(CFrame.new(260, 15.6, -340), Vector3.new(35, 0.4, 20))

    -- 3. Obsidian Spires
    local function createObsidianSpire(cf: CFrame, height: number, width: number)
        local spire = Instance.new("Part")
        spire.Name = "ObsidianSpire"
        spire.Size = Vector3.new(width, height, width)
        spire.CFrame = cf
        spire.Color = Color3.fromRGB(18, 18, 22)
        spire.Material = Enum.Material.Granite
        spire.Anchored = true
        spire.CanCollide = true
        spire.Parent = zone
    end

    createObsidianSpire(CFrame.new(380, 35, -380), 40, 8)
    createObsidianSpire(CFrame.new(220, 30, -380), 32, 7)
    createObsidianSpire(CFrame.new(380, 32, -220), 36, 7)
    createObsidianSpire(CFrame.new(220, 40, -220), 44, 9)

    -- 4. Ambient Ember and Smoke Particles
    local emberAnchor = Instance.new("Part")
    emberAnchor.Name = "EmberAnchor"
    emberAnchor.Size = Vector3.new(180, 1, 180)
    emberAnchor.CFrame = CFrame.new(300, 17, -300)
    emberAnchor.Transparency = 1
    emberAnchor.CanCollide = false
    emberAnchor.Anchored = true
    emberAnchor.Parent = zone

    local emberEmitter = Instance.new("ParticleEmitter")
    emberEmitter.Name = "Embers"
    emberEmitter.Color = ColorSequence.new(Color3.fromRGB(255, 140, 40), Color3.fromRGB(255, 40, 20))
    emberEmitter.Size = NumberSequence.new(0.3, 0.7)
    emberEmitter.Rate = 90
    emberEmitter.Speed = NumberRange.new(4, 10)
    emberEmitter.Lifetime = NumberRange.new(2, 4)
    emberEmitter.EmissionDirection = Enum.NormalId.Top
    emberEmitter.SpreadAngle = Vector2.new(20, 20)
    emberEmitter.LightEmission = 0.9
    emberEmitter.Parent = emberAnchor

    -- 5. Return Portal to Grand Sanctuary
    local returnPortal = Instance.new("Model")
    returnPortal.Name = "SanctuaryReturnPortal"

    local base = Instance.new("Part")
    base.Name = "ReturnBase"
    base.Size = Vector3.new(12, 1, 10)
    base.CFrame = CFrame.new(300, 16.5, -220)
    base.Color = Color3.fromRGB(45, 25, 20)
    base.Material = Enum.Material.Metal
    base.Anchored = true
    base.CanCollide = true
    base.Parent = returnPortal

    local returnGate = Instance.new("Part")
    returnGate.Name = "TeleportGatePart"
    returnGate.Shape = Enum.PartType.Cylinder
    returnGate.Size = Vector3.new(0.4, 10, 10)
    returnGate.CFrame = CFrame.new(300, 22, -220)
    returnGate.Color = Color3.fromRGB(255, 95, 30)
    returnGate.Material = Enum.Material.Neon
    returnGate.Transparency = 0.35
    returnGate.Anchored = true
    returnGate.CanCollide = false
    returnGate:SetAttribute("TargetZone", "Lobby")
    returnGate.Parent = returnPortal

    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 220, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 6.5, 0)
    billboard.AlwaysOnTop = true
    local text = Instance.new("TextLabel")
    text.Size = UDim2.new(1, 0, 1, 0)
    text.BackgroundTransparency = 1
    text.Text = "RETURN TO SANCTUARY"
    text.TextColor3 = Color3.fromRGB(255, 140, 50)
    text.Font = Enum.Font.GothamBold
    text.TextSize = 14
    text.Parent = billboard
    billboard.Parent = returnGate

    returnPortal.Parent = zone

    -- 6. Enemy Spawn Nodes
    local enemyNodesFolder = Instance.new("Folder")
    enemyNodesFolder.Name = "EnemySpawnNodes"
    enemyNodesFolder.Parent = zone

    local function createNode(name: string, pos: Vector3, enemyType: string)
        local node = Instance.new("Part")
        node.Name = name
        node.Size = Vector3.new(2, 0.5, 2)
        node.CFrame = CFrame.new(pos)
        node.Transparency = 1
        node.Anchored = true
        node.CanCollide = false
        node:SetAttribute("EnemyType", enemyType)
        node.Parent = enemyNodesFolder
    end

    createNode("SpawnNode_Magma_1", Vector3.new(320, 17, -310), "MagmaStalker")
    createNode("SpawnNode_Magma_2", Vector3.new(280, 17, -310), "MagmaStalker")
    createNode("SpawnNode_FireBeast_1", Vector3.new(300, 17, -350), "StormBeast")

    print("[VolcanicWastesBuilder] Zone 3: The Volcanic Wastes built successfully.")
    return zone
end

return VolcanicWastesBuilder
