--!strict
--[[
    TempestWildsBuilder.lua
    Procedural builder for Zone 1: The Tempest Wilds.
    Features rocky combat terrain, storm obelisks, return portal, and enemy spawn nodes.
]]

local Workspace = game:GetService("Workspace")

local TempestWildsBuilder = {}

function TempestWildsBuilder.BuildZone(): Folder
    local existing = Workspace:FindFirstChild("Zone_TempestWilds")
    if existing then existing:Destroy() end

    local zone = Instance.new("Folder")
    zone.Name = "Zone_TempestWilds"
    zone.Parent = Workspace

    -- 1. Wilds Floor (200, -1, 200 studs)
    local floor = Instance.new("Part")
    floor.Name = "WildsFloor"
    floor.Size = Vector3.new(220, 2, 220)
    floor.CFrame = CFrame.new(200, -1, 200)
    floor.Color = Color3.fromRGB(32, 38, 48)
    floor.Material = Enum.Material.Slate
    floor.Anchored = true
    floor.CanCollide = true
    floor.Parent = zone

    -- 2. Return Portal to Grand Sanctuary
    local returnPortal = Instance.new("Model")
    returnPortal.Name = "SanctuaryReturnPortal"

    local base = Instance.new("Part")
    base.Name = "ReturnBase"
    base.Size = Vector3.new(12, 1, 10)
    base.CFrame = CFrame.new(200, 0.5, 120)
    base.Color = Color3.fromRGB(25, 35, 50)
    base.Material = Enum.Material.Metal
    base.Anchored = true
    base.CanCollide = true
    base.Parent = returnPortal

    local returnGate = Instance.new("Part")
    returnGate.Name = "TeleportGatePart"
    returnGate.Shape = Enum.PartType.Cylinder
    returnGate.Size = Vector3.new(0.4, 10, 10)
    returnGate.CFrame = CFrame.new(200, 6, 120)
    returnGate.Color = Color3.fromRGB(65, 215, 255)
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
    text.TextColor3 = Color3.fromRGB(65, 215, 255)
    text.Font = Enum.Font.GothamBold
    text.TextSize = 14
    text.Parent = billboard
    billboard.Parent = returnGate

    returnPortal.Parent = zone

    -- 3. Enemy Spawn Nodes (Anchors for EnemyManager)
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

    createNode("SpawnNode_Drone_1", Vector3.new(180, 1, 190), "TempestDrone")
    createNode("SpawnNode_Drone_2", Vector3.new(220, 1, 190), "TempestDrone")
    createNode("SpawnNode_Drone_3", Vector3.new(170, 1, 230), "TempestDrone")
    createNode("SpawnNode_Beast_1", Vector3.new(230, 1, 240), "StormBeast")

    print("[TempestWildsBuilder] Zone 1: The Tempest Wilds built successfully.")
    return zone
end

return TempestWildsBuilder
