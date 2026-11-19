--!strict
--[[
    TestArenaBuilder.server.lua
    Procedural Developer Test Environment:
    Instantiates a lightweight test arena with spawn point, camera test angles,
    distance markers, and target dummies for ability testing.
]]

local Workspace = game:GetService("Workspace")

local ARENA_FOLDER_NAME = "StormforgeTestArena"

local function buildArena()
    local existingArena = Workspace:FindFirstChild(ARENA_FOLDER_NAME)
    if existingArena then
        existingArena:Destroy()
    end

    local arena = Instance.new("Folder")
    arena.Name = ARENA_FOLDER_NAME
    arena.Parent = Workspace

    -- 1. Main Testing Arena Floor
    local floor = Instance.new("Part")
    floor.Name = "ArenaFloor"
    floor.Size = Vector3.new(140, 2, 140)
    floor.CFrame = CFrame.new(0, -1, 0)
    floor.Color = Color3.fromRGB(24, 30, 42)
    floor.Material = Enum.Material.Concrete
    floor.Anchored = true
    floor.CanCollide = true
    floor.Parent = arena

    -- Grid accent lines
    local border = Instance.new("SelectionBox")
    border.Color3 = Color3.fromRGB(65, 215, 255)
    border.LineThickness = 0.08
    border.Adornee = floor
    border.Parent = floor

    -- 2. Hero Spawn Platform
    local spawn = Instance.new("SpawnLocation")
    spawn.Name = "HeroSpawnPoint"
    spawn.Size = Vector3.new(12, 1, 12)
    spawn.CFrame = CFrame.new(0, 0.5, 0)
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
    spawnRing.CFrame = CFrame.new(0, 1.05, 0) * CFrame.Angles(0, 0, math.rad(90))
    spawnRing.Color = Color3.fromRGB(65, 225, 255)
    spawnRing.Material = Enum.Material.Neon
    spawnRing.Anchored = true
    spawnRing.CanCollide = false
    spawnRing.Parent = arena

    -- 3. Camera Observation Platform
    local camPlatform = Instance.new("Part")
    camPlatform.Name = "CameraObservationPad"
    camPlatform.Size = Vector3.new(10, 6, 10)
    camPlatform.CFrame = CFrame.new(0, 3, -35)
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

    -- 4. Dash Distance Testing Markers (10, 20, 30 studs forward)
    local function createDistancePillar(distance: number)
        local pillar = Instance.new("Part")
        pillar.Name = string.format("DistanceMarker_%d_Studs", distance)
        pillar.Size = Vector3.new(1.5, 8, 1.5)
        pillar.CFrame = CFrame.new(0, 4, distance)
        pillar.Color = Color3.fromRGB(30, 40, 58)
        pillar.Material = Enum.Material.Metal
        pillar.Anchored = true
        pillar.CanCollide = true
        pillar.Parent = arena

        local beacon = Instance.new("Part")
        beacon.Name = "Beacon"
        beacon.Shape = Enum.PartType.Ball
        beacon.Size = Vector3.new(1.8, 1.8, 1.8)
        beacon.CFrame = CFrame.new(0, 8.5, distance)
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
    createDistancePillar(30) -- Dash Target
    createDistancePillar(50)

    -- 5. Ability Target Training Dummies
    local function createTargetDummy(name: string, position: Vector3)
        local dummy = Instance.new("Model")
        dummy.Name = name

        local hrp = Instance.new("Part")
        hrp.Name = "HumanoidRootPart"
        hrp.Size = Vector3.new(2, 2, 1)
        hrp.CFrame = CFrame.new(position)
        hrp.Transparency = 1
        hrp.Anchored = true
        hrp.CanCollide = false
        hrp.Parent = dummy
        dummy.PrimaryPart = hrp

        local torso = Instance.new("Part")
        torso.Name = "Torso"
        torso.Size = Vector3.new(2, 2.5, 1)
        torso.CFrame = CFrame.new(position)
        torso.Color = Color3.fromRGB(150, 40, 40)
        torso.Material = Enum.Material.SmoothPlastic
        torso.Anchored = true
        torso.CanCollide = true
        torso.Parent = dummy

        local head = Instance.new("Part")
        head.Name = "Head"
        head.Size = Vector3.new(1.2, 1.2, 1.2)
        head.CFrame = CFrame.new(position + Vector3.new(0, 2, 0))
        head.Color = Color3.fromRGB(210, 180, 140)
        head.Material = Enum.Material.SmoothPlastic
        head.Anchored = true
        head.CanCollide = false
        head.Parent = dummy

        local humanoid = Instance.new("Humanoid")
        humanoid.MaxHealth = 500
        humanoid.Health = 500
        humanoid.DisplayName = name
        humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.AlwaysOn
        humanoid.Parent = dummy

        dummy.Parent = arena
    end

    createTargetDummy("TrainingDummy_Left", Vector3.new(-12, 1.5, 25))
    createTargetDummy("TrainingDummy_Center", Vector3.new(0, 1.5, 30))
    createTargetDummy("TrainingDummy_Right", Vector3.new(12, 1.5, 25))

    print("[TestArenaBuilder] Developer test environment constructed with targets and distance markers.")
end

buildArena()
