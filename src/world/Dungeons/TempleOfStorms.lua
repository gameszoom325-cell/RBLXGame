--!strict
--[[
    TempleOfStorms.lua
    Procedural map builder for the first RPG Dungeon:
    "Temple of the Storm Sovereign"
    Built in isolated airspace (Y = 1000) to ensure zero overlap with Lobby or Wilds.
    Features:
    - Chamber 1: Guardian Antechamber (Spawn & 4 Storm Guardians)
    - Chamber 2: Conduit Sanctuary (2 Overloadable Lightning Conduits)
    - Chamber 3: Sovereign Throne Arena (Storm Titan Arena)
    - Entrance Dais and Exit Portal
]]

local Workspace = game:GetService("Workspace")

local TempleOfStorms = {}

local DUNGEON_ORIGIN = Vector3.new(0, 1000, 0)

function TempleOfStorms.BuildDungeon(): Folder
    local existing = Workspace:FindFirstChild("Dungeon_TempleOfStorms")
    if existing then existing:Destroy() end

    local dungeonFolder = Instance.new("Folder")
    dungeonFolder.Name = "Dungeon_TempleOfStorms"
    dungeonFolder.Parent = Workspace

    -- =========================================================================
    -- CHAMBER 1: GUARDIAN ANTECHAMBER (Center at 0, 1000, 0)
    -- =========================================================================
    local floor1 = Instance.new("Part")
    floor1.Name = "Chamber1_Floor"
    floor1.Size = Vector3.new(90, 2, 90)
    floor1.CFrame = CFrame.new(DUNGEON_ORIGIN)
    floor1.Color = Color3.fromRGB(24, 30, 45)
    floor1.Material = Enum.Material.Cobblestone
    floor1.Anchored = true
    floor1.CanCollide = true
    floor1.Parent = dungeonFolder

    -- Border trim
    local b1 = Instance.new("SelectionBox")
    b1.Color3 = Color3.fromRGB(65, 215, 255)
    b1.LineThickness = 0.05
    b1.Adornee = floor1
    b1.Parent = floor1

    -- Dungeon Spawn Point
    local spawnLocation = Instance.new("SpawnLocation")
    spawnLocation.Name = "DungeonSpawn"
    spawnLocation.Size = Vector3.new(8, 0.2, 8)
    spawnLocation.CFrame = CFrame.new(DUNGEON_ORIGIN + Vector3.new(0, 1.2, -35))
    spawnLocation.Transparency = 1
    spawnLocation.Anchored = true
    spawnLocation.CanCollide = false
    spawnLocation.Duration = 0
    spawnLocation.Parent = dungeonFolder

    -- Corridor 1 -> 2
    local corridor1 = Instance.new("Part")
    corridor1.Name = "Corridor1_2"
    corridor1.Size = Vector3.new(20, 2, 40)
    corridor1.CFrame = CFrame.new(DUNGEON_ORIGIN + Vector3.new(0, 0, 65))
    corridor1.Color = Color3.fromRGB(20, 25, 38)
    corridor1.Material = Enum.Material.Slate
    corridor1.Anchored = true
    corridor1.CanCollide = true
    corridor1.Parent = dungeonFolder

    -- =========================================================================
    -- CHAMBER 2: CONDUIT SANCTUARY (Center at 0, 1000, 120)
    -- =========================================================================
    local chamber2Origin = DUNGEON_ORIGIN + Vector3.new(0, 0, 120)

    local floor2 = Instance.new("Part")
    floor2.Name = "Chamber2_Floor"
    floor2.Size = Vector3.new(100, 2, 80)
    floor2.CFrame = CFrame.new(chamber2Origin)
    floor2.Color = Color3.fromRGB(28, 35, 52)
    floor2.Material = Enum.Material.Metal
    floor2.Anchored = true
    floor2.CanCollide = true
    floor2.Parent = dungeonFolder

    -- Two Interactive Lightning Conduits
    local conduitPositions = {
        chamber2Origin + Vector3.new(-28, 6, 0),
        chamber2Origin + Vector3.new(28, 6, 0),
    }

    local conduitsFolder = Instance.new("Folder")
    conduitsFolder.Name = "Conduits"
    conduitsFolder.Parent = dungeonFolder

    for idx, cPos in ipairs(conduitPositions) do
        local pillar = Instance.new("Part")
        pillar.Name = "LightningConduit_" .. idx
        pillar.Size = Vector3.new(4, 12, 4)
        pillar.CFrame = CFrame.new(cPos)
        pillar.Color = Color3.fromRGB(65, 225, 255)
        pillar.Material = Enum.Material.Neon
        pillar.Anchored = true
        pillar.CanCollide = true
        pillar.Parent = conduitsFolder

        local prompt = Instance.new("ProximityPrompt")
        prompt.ActionText = "Overload Conduit"
        prompt.ObjectText = string.format("Lightning Conduit #%d", idx)
        prompt.HoldDuration = 1.5
        prompt.MaxActivationDistance = 14
        prompt.Parent = pillar
    end

    -- Corridor 2 -> 3
    local corridor2 = Instance.new("Part")
    corridor2.Name = "Corridor2_3"
    corridor2.Size = Vector3.new(24, 2, 50)
    corridor2.CFrame = CFrame.new(chamber2Origin + Vector3.new(0, 0, 65))
    corridor2.Color = Color3.fromRGB(20, 25, 38)
    corridor2.Material = Enum.Material.Slate
    corridor2.Anchored = true
    corridor2.CanCollide = true
    corridor2.Parent = dungeonFolder

    -- =========================================================================
    -- CHAMBER 3: SOVEREIGN THRONE ARENA (Center at 0, 1000, 250)
    -- =========================================================================
    local arenaOrigin = chamber2Origin + Vector3.new(0, 0, 130)

    local floor3 = Instance.new("Part")
    floor3.Name = "Chamber3_ArenaFloor"
    floor3.Shape = Enum.PartType.Cylinder
    floor3.Size = Vector3.new(2, 140, 140)
    floor3.CFrame = CFrame.new(arenaOrigin) * CFrame.Angles(0, 0, math.rad(90))
    floor3.Color = Color3.fromRGB(18, 22, 34)
    floor3.Material = Enum.Material.DiamondPlate
    floor3.Anchored = true
    floor3.CanCollide = true
    floor3.Parent = dungeonFolder

    -- Outer Perimeter Neon Ring
    local outerRing = Instance.new("Part")
    outerRing.Name = "ArenaOuterRing"
    outerRing.Shape = Enum.PartType.Cylinder
    outerRing.Size = Vector3.new(0.4, 144, 144)
    outerRing.CFrame = CFrame.new(arenaOrigin + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
    outerRing.Color = Color3.fromRGB(65, 225, 255)
    outerRing.Material = Enum.Material.Neon
    outerRing.Anchored = true
    outerRing.CanCollide = false
    outerRing.Parent = dungeonFolder

    -- Exit Portal Gate (Appears upon Boss Defeat)
    local exitGate = Instance.new("Part")
    exitGate.Name = "DungeonExitPortal"
    exitGate.Shape = Enum.PartType.Cylinder
    exitGate.Size = Vector3.new(0.5, 12, 12)
    exitGate.CFrame = CFrame.new(arenaOrigin + Vector3.new(0, 7, 50))
    exitGate.Color = Color3.fromRGB(255, 220, 60)
    exitGate.Material = Enum.Material.Neon
    exitGate.Transparency = 0.4
    exitGate.Anchored = true
    exitGate.CanCollide = false
    exitGate.Visible = false
    exitGate.Parent = dungeonFolder

    print("[TempleOfStorms] Constructed 3-chamber dungeon layout at Y = 1000.")
    return dungeonFolder
end

function TempleOfStorms.GetSpawnCFrame(): CFrame
    return CFrame.new(DUNGEON_ORIGIN + Vector3.new(0, 4, -35))
end

function TempleOfStorms.GetBossSpawnPosition(): Vector3
    return DUNGEON_ORIGIN + Vector3.new(0, 2, 250)
end

return TempleOfStorms