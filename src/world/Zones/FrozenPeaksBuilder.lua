--!strict
--[[
    FrozenPeaksBuilder.lua
    Procedural builder for Zone 2: The Frozen Peaks.
    Permafrost mountains, glacial spires, return portal, and high-level frost enemy spawn nodes.
]]

local Workspace = game:GetService("Workspace")

local FrozenPeaksBuilder = {}

function FrozenPeaksBuilder.BuildZone(): Folder
    local existing = Workspace:FindFirstChild("Zone_FrozenPeaks")
    if existing then existing:Destroy() end

    local zone = Instance.new("Folder")
    zone.Name = "Zone_FrozenPeaks"
    zone.Parent = Workspace

    -- 1. Glacial Mountain Floor (-300, 20, -300 studs)
    local floor = Instance.new("Part")
    floor.Name = "GlacialFloor"
    floor.Size = Vector3.new(240, 2, 240)
    floor.CFrame = CFrame.new(-300, 20, -300)
    floor.Color = Color3.fromRGB(205, 225, 245)
    floor.Material = Enum.Material.Ice
    floor.Anchored = true
    floor.CanCollide = true
    floor.Friction = 0.4
    floor.Parent = zone

    -- 2. Glacial Spires & Permafrost Pillars
    local function createSpire(cf: CFrame, height: number, width: number)
        local spire = Instance.new("Part")
        spire.Name = "GlacialSpire"
        spire.Size = Vector3.new(width, height, width)
        spire.CFrame = cf
        spire.Color = Color3.fromRGB(170, 215, 250)
        spire.Material = Enum.Material.Glass
        spire.Transparency = 0.2
        spire.Anchored = true
        spire.CanCollide = true
        spire.Parent = zone

        -- Ice crystal light glow
        local light = Instance.new("PointLight")
        light.Color = Color3.fromRGB(150, 220, 255)
        light.Brightness = 1.2
        light.Range = 25
        light.Parent = spire
    end

    createSpire(CFrame.new(-380, 40, -380), 45, 8)
    createSpire(CFrame.new(-220, 35, -380), 35, 7)
    createSpire(CFrame.new(-380, 38, -220), 40, 7)
    createSpire(CFrame.new(-220, 42, -220), 48, 9)
    createSpire(CFrame.new(-300, 35, -390), 32, 6)

    -- 3. Ambient Snow Emitter
    local snowAnchor = Instance.new("Part")
    snowAnchor.Name = "SnowAnchor"
    snowAnchor.Size = Vector3.new(200, 1, 200)
    snowAnchor.CFrame = CFrame.new(-300, 60, -300)
    snowAnchor.Transparency = 1
    snowAnchor.CanCollide = false
    snowAnchor.Anchored = true
    snowAnchor.Parent = zone

    local snowEmitter = Instance.new("ParticleEmitter")
    snowEmitter.Name = "Snowfall"
    snowEmitter.Color = ColorSequence.new(Color3.fromRGB(240, 250, 255))
    snowEmitter.Size = NumberSequence.new(0.3, 0.6)
    snowEmitter.Rate = 120
    snowEmitter.Speed = NumberRange.new(5, 12)
    snowEmitter.Lifetime = NumberRange.new(4, 7)
    snowEmitter.EmissionDirection = Enum.NormalId.Bottom
    snowEmitter.SpreadAngle = Vector2.new(15, 15)
    snowEmitter.Transparency = NumberSequence.new(0.2, 0.5)
    snowEmitter.Parent = snowAnchor

    -- 4. Return Portal to Grand Sanctuary
    local returnPortal = Instance.new("Model")
    returnPortal.Name = "SanctuaryReturnPortal"

    local base = Instance.new("Part")
    base.Name = "ReturnBase"
    base.Size = Vector3.new(12, 1, 10)
    base.CFrame = CFrame.new(-300, 21.5, -220)
    base.Color = Color3.fromRGB(30, 45, 65)
    base.Material = Enum.Material.Metal
    base.Anchored = true
    base.CanCollide = true
    base.Parent = returnPortal

    local returnGate = Instance.new("Part")
    returnGate.Name = "TeleportGatePart"
    returnGate.Shape = Enum.PartType.Cylinder
    returnGate.Size = Vector3.new(0.4, 10, 10)
    returnGate.CFrame = CFrame.new(-300, 27, -220)
    returnGate.Color = Color3.fromRGB(120, 220, 255)
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
    text.TextColor3 = Color3.fromRGB(150, 230, 255)
    text.Font = Enum.Font.GothamBold
    text.TextSize = 14
    text.Parent = billboard
    billboard.Parent = returnGate

    returnPortal.Parent = zone

    -- 5. Enemy Spawn Nodes
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

    createNode("SpawnNode_FrostGolem_1", Vector3.new(-320, 22, -310), "FrostGolem")
    createNode("SpawnNode_FrostGolem_2", Vector3.new(-270, 22, -310), "FrostGolem")
    createNode("SpawnNode_FrostDrone_1", Vector3.new(-300, 22, -340), "TempestDrone")
    createNode("SpawnNode_FrostDrone_2", Vector3.new(-330, 22, -350), "TempestDrone")

    print("[FrozenPeaksBuilder] Zone 2: The Frozen Peaks built successfully.")
    return zone
end

return FrozenPeaksBuilder
