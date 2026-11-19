--!strict
--[[
    CombatTestArenaBuilder.lua
    Procedural Builder for the Combat Proving Grounds:
    Constructs an optimized combat proving arena containing:
      - 5 Tempest Drones (spawners with aerial AI)
      - 2 Storm Beasts (spawners with ground AI)
      - 1 Damage Test Dummy (with high HP & auto-regen)
      - Distance Markers (15, 30, 50 studs)
      - Observation Platform & Sanctuary Return Portal
    Adheres strictly to existing modular world architecture.
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Systems = ReplicatedStorage:WaitForChild("Systems")
local EnemyManager = require(Systems:WaitForChild("EnemyManager"))

local CombatTestArenaBuilder = {}

local ARENA_FOLDER_NAME = "StormforgeTestArena"
local ARENA_CENTER = Vector3.new(0, 0, -180)

function CombatTestArenaBuilder.BuildArena(): Folder
    local existingArena = Workspace:FindFirstChild(ARENA_FOLDER_NAME)
    if existingArena then
        existingArena:Destroy()
    end

    local arena = Instance.new("Folder")
    arena.Name = ARENA_FOLDER_NAME
    arena.Parent = Workspace

    -- 1. Arena Main Floor (140 x 2 x 140 studs)
    local floor = Instance.new("Part")
    floor.Name = "ArenaFloor"
    floor.Size = Vector3.new(140, 2, 140)
    floor.CFrame = CFrame.new(ARENA_CENTER + Vector3.new(0, -1, 0))
    floor.Color = Color3.fromRGB(24, 30, 42)
    floor.Material = Enum.Material.Concrete
    floor.Anchored = true
    floor.CanCollide = true
    floor.Parent = arena

    local border = Instance.new("SelectionBox")
    border.Color3 = Color3.fromRGB(65, 215, 255)
    border.LineThickness = 0.08
    border.Adornee = floor
    border.Parent = floor

    -- 2. Hero Proving Ground Spawn Location
    local spawn = Instance.new("SpawnLocation")
    spawn.Name = "HeroSpawnPoint"
    spawn.Size = Vector3.new(12, 1, 12)
    spawn.CFrame = CFrame.new(ARENA_CENTER + Vector3.new(0, 0.5, 0))
    spawn.Color = Color3.fromRGB(18, 24, 36)
    spawn.Material = Enum.Material.Metal
    spawn.Anchored = true
    spawn.CanCollide = true
    spawn.Duration = 0
    spawn.Parent = arena

    local spawnRing = Instance.new("Part")
    spawnRing.Name = "SpawnNeonRing"
    spawnRing.Shape = Enum.PartType.Cylinder
    spawnRing.Size = Vector3.new(0.2, 10, 10)
    spawnRing.CFrame = CFrame.new(ARENA_CENTER + Vector3.new(0, 1.05, 0)) * CFrame.Angles(0, 0, math.rad(90))
    spawnRing.Color = Color3.fromRGB(65, 225, 255)
    spawnRing.Material = Enum.Material.Neon
    spawnRing.Anchored = true
    spawnRing.CanCollide = false
    spawnRing.Parent = arena

    -- 3. Camera Observation Platform
    local camPlatform = Instance.new("Part")
    camPlatform.Name = "CameraObservationPad"
    camPlatform.Size = Vector3.new(10, 6, 10)
    camPlatform.CFrame = CFrame.new(ARENA_CENTER + Vector3.new(0, 3, -45))
    camPlatform.Color = Color3.fromRGB(35, 45, 62)
    camPlatform.Material = Enum.Material.SmoothPlastic
    camPlatform.Anchored = true
    camPlatform.CanCollide = true
    camPlatform.Parent = arena

    local camLabel = Instance.new("BillboardGui")
    camLabel.Name = "CameraPadLabel"
    camLabel.Size = UDim2.new(0, 180, 0, 40)
    camLabel.StudsOffset = Vector3.new(0, 4, 0)
    camLabel.AlwaysOnTop = true
    local labelText = Instance.new("TextLabel")
    labelText.Size = UDim2.new(1, 0, 1, 0)
    labelText.BackgroundTransparency = 1
    labelText.Text = "OBSERVATION PLATFORM"
    labelText.TextColor3 = Color3.fromRGB(65, 225, 255)
    labelText.Font = Enum.Font.GothamBold
    labelText.TextSize = 14
    labelText.Parent = camLabel
    camLabel.Parent = camPlatform

    -- 4. Distance Markers (15, 30, 50 studs)
    local function createDistancePillar(distance: number)
        local pillar = Instance.new("Part")
        pillar.Name = string.format("DistanceMarker_%d_Studs", distance)
        pillar.Size = Vector3.new(1.5, 8, 1.5)
        pillar.CFrame = CFrame.new(ARENA_CENTER + Vector3.new(0, 4, distance))
        pillar.Color = Color3.fromRGB(30, 40, 58)
        pillar.Material = Enum.Material.Metal
        pillar.Anchored = true
        pillar.CanCollide = true
        pillar.Parent = arena

        local beacon = Instance.new("Part")
        beacon.Name = "Beacon"
        beacon.Shape = Enum.PartType.Ball
        beacon.Size = Vector3.new(1.8, 1.8, 1.8)
        beacon.CFrame = CFrame.new(ARENA_CENTER + Vector3.new(0, 8.5, distance))
        beacon.Color = Color3.fromRGB(65, 225, 255)
        beacon.Material = Enum.Material.Neon
        beacon.Anchored = true
        beacon.CanCollide = false
        beacon.Parent = pillar

        local gui = Instance.new("BillboardGui")
        gui.Size = UDim2.new(0, 100, 0, 30)
        gui.StudsOffset = Vector3.new(0, 2, 0)
        gui.AlwaysOnTop = true
        local txt = Instance.new("TextLabel")
        txt.Size = UDim2.new(1, 0, 1, 0)
        txt.BackgroundTransparency = 1
        txt.Text = string.format("%d STUDS", distance)
        txt.TextColor3 = Color3.fromRGB(240, 245, 255)
        txt.Font = Enum.Font.GothamBold
        txt.TextSize = 13
        txt.Parent = gui
        gui.Parent = beacon
    end

    createDistancePillar(15)
    createDistancePillar(30)
    createDistancePillar(50)

    -- 5. Return Portal to Grand Sanctuary
    local returnPortal = Instance.new("Model")
    returnPortal.Name = "TrainingReturnPortal"

    local retBase = Instance.new("Part")
    retBase.Name = "ReturnBase"
    retBase.Size = Vector3.new(12, 1, 10)
    retBase.CFrame = CFrame.new(ARENA_CENTER + Vector3.new(0, 0.5, -55))
    retBase.Color = Color3.fromRGB(25, 35, 50)
    retBase.Material = Enum.Material.Metal
    retBase.Anchored = true
    retBase.CanCollide = true
    retBase.Parent = returnPortal

    local retGate = Instance.new("Part")
    retGate.Name = "TeleportGatePart"
    retGate.Shape = Enum.PartType.Cylinder
    retGate.Size = Vector3.new(0.4, 10, 10)
    retGate.CFrame = CFrame.new(ARENA_CENTER + Vector3.new(0, 6, -55))
    retGate.Color = Color3.fromRGB(255, 195, 45)
    retGate.Material = Enum.Material.Neon
    retGate.Transparency = 0.35
    retGate.Anchored = true
    retGate.CanCollide = false
    retGate:SetAttribute("TargetZone", "Lobby")
    retGate.Parent = returnPortal

    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 220, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 6.5, 0)
    billboard.AlwaysOnTop = true
    local text = Instance.new("TextLabel")
    text.Size = UDim2.new(1, 0, 1, 0)
    text.BackgroundTransparency = 1
    text.Text = "RETURN TO SANCTUARY"
    text.TextColor3 = Color3.fromRGB(255, 195, 45)
    text.Font = Enum.Font.GothamBold
    text.TextSize = 14
    text.Parent = billboard
    billboard.Parent = retGate

    returnPortal.Parent = arena

    -- 6. Spawn 1 Damage Test Dummy (Center Proving Marker)
    local dummy = Instance.new("Model")
    dummy.Name = "DamageTestDummy"

    local dummyHrp = Instance.new("Part")
    dummyHrp.Name = "HumanoidRootPart"
    dummyHrp.Size = Vector3.new(2, 2, 1)
    dummyHrp.CFrame = CFrame.new(ARENA_CENTER + Vector3.new(0, 1.5, 25))
    dummyHrp.Transparency = 1
    dummyHrp.Anchored = true
    dummyHrp.CanCollide = false
    dummyHrp.Parent = dummy
    dummy.PrimaryPart = dummyHrp

    local torso = Instance.new("Part")
    torso.Name = "Torso"
    torso.Size = Vector3.new(2.4, 3, 1.2)
    torso.CFrame = CFrame.new(ARENA_CENTER + Vector3.new(0, 2, 25))
    torso.Color = Color3.fromRGB(160, 45, 45)
    torso.Material = Enum.Material.Metal
    torso.Anchored = true
    torso.CanCollide = true
    torso.Parent = dummy

    local head = Instance.new("Part")
    head.Name = "Head"
    head.Size = Vector3.new(1.2, 1.2, 1.2)
    head.CFrame = CFrame.new(ARENA_CENTER + Vector3.new(0, 4, 25))
    head.Color = Color3.fromRGB(230, 190, 150)
    head.Material = Enum.Material.SmoothPlastic
    head.Anchored = true
    head.CanCollide = false
    head.Parent = dummy

    local dummyHum = Instance.new("Humanoid")
    dummyHum.MaxHealth = 1000
    dummyHum.Health = 1000
    dummyHum.DisplayName = "Damage Test Dummy [Lv. 10]"
    dummyHum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.AlwaysOn
    dummyHum.Parent = dummy

    dummy:SetAttribute("EnemyType", "TestDummy")
    dummy:SetAttribute("MaxHealth", 1000)
    dummy:SetAttribute("CurrentHealth", 1000)

    dummy.Parent = arena

    -- 7. Spawn 5 Tempest Drones & 2 Storm Beasts via EnemyManager
    task.delay(0.5, function()
        -- 5 Tempest Drones
        local dronePositions = {
            ARENA_CENTER + Vector3.new(-28, 2, 15),
            ARENA_CENTER + Vector3.new(28, 2, 15),
            ARENA_CENTER + Vector3.new(-22, 2, 40),
            ARENA_CENTER + Vector3.new(22, 2, 40),
            ARENA_CENTER + Vector3.new(0, 2, 50),
        }
        for _, pos in ipairs(dronePositions) do
            EnemyManager.SpawnEnemy("TempestDrone", pos)
        end

        -- 2 Storm Beasts
        local beastPositions = {
            ARENA_CENTER + Vector3.new(-14, 1.5, 30),
            ARENA_CENTER + Vector3.new(14, 1.5, 30),
        }
        for _, pos in ipairs(beastPositions) do
            EnemyManager.SpawnEnemy("StormBeast", pos)
        end
    end)

    print("[CombatTestArenaBuilder] Combat Test Arena built with 5 Drones, 2 Beasts, and 1 Damage Dummy.")
    return arena
end

return CombatTestArenaBuilder
