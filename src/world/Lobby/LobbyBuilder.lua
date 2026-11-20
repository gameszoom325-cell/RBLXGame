--!strict
--[[
    LobbyBuilder.lua
    Procedurally constructs the Main Lobby (Grand Storm Sanctuary).
    Includes Hero Selection Dais, Valen Statue, Portal to Tempest Wilds,
    Training Arena Archway, Quest Board, and NPC Anchors.
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyBuilder = {}

-- Utility to create anchored parts with standard fantasy styling
local function createPillar(parent: Instance, cframe: CFrame, height: number, color: Color3): Part
    local pillar = Instance.new("Part")
    pillar.Name = "SanctuaryPillar"
    pillar.Size = Vector3.new(2.4, height, 2.4)
    pillar.CFrame = cframe
    pillar.Color = color
    pillar.Material = Enum.Material.Metal
    pillar.Anchored = true
    pillar.CanCollide = true
    pillar.Parent = parent

    -- Top neon accent cap
    local cap = Instance.new("Part")
    cap.Name = "NeonCap"
    cap.Size = Vector3.new(2.8, 0.4, 2.8)
    cap.CFrame = cframe * CFrame.new(0, height / 2, 0)
    cap.Color = Color3.fromRGB(65, 225, 255)
    cap.Material = Enum.Material.Neon
    cap.Anchored = true
    cap.CanCollide = false
    cap.Parent = pillar

    return pillar
end

function LobbyBuilder.BuildLobby(): Folder
    local existing = Workspace:FindFirstChild("MainLobby")
    if existing then existing:Destroy() end

    local lobby = Instance.new("Folder")
    lobby.Name = "MainLobby"
    lobby.Parent = Workspace

    -- 1. Grand Sanctuary Floor (180 x 2 x 180 studs)
    local mainFloor = Instance.new("Part")
    mainFloor.Name = "SanctuaryMainFloor"
    mainFloor.Size = Vector3.new(180, 2, 180)
    mainFloor.CFrame = CFrame.new(0, -1, 0)
    mainFloor.Color = Color3.fromRGB(22, 28, 40)
    mainFloor.Material = Enum.Material.Concrete
    mainFloor.Anchored = true
    mainFloor.CanCollide = true
    mainFloor.Parent = lobby

    -- Outer border trim
    local border = Instance.new("SelectionBox")
    border.Color3 = Color3.fromRGB(65, 215, 255)
    border.LineThickness = 0.08
    border.Adornee = mainFloor
    border.Parent = mainFloor

    -- 2. Hero Selection Area (Central Elevated Dais)
    local selectionDais = Instance.new("Part")
    selectionDais.Name = "HeroSelectionDais"
    selectionDais.Shape = Enum.PartType.Cylinder
    selectionDais.Size = Vector3.new(1.2, 24, 24)
    selectionDais.CFrame = CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, math.rad(90))
    selectionDais.Color = Color3.fromRGB(30, 42, 62)
    selectionDais.Material = Enum.Material.Metal
    selectionDais.Anchored = true
    selectionDais.CanCollide = true
    selectionDais.Parent = lobby

    local daisRing = Instance.new("Part")
    daisRing.Name = "DaisNeonRing"
    daisRing.Shape = Enum.PartType.Cylinder
    daisRing.Size = Vector3.new(0.2, 20, 20)
    daisRing.CFrame = CFrame.new(0, 1.25, 0) * CFrame.Angles(0, 0, math.rad(90))
    daisRing.Color = Color3.fromRGB(65, 225, 255)
    daisRing.Material = Enum.Material.Neon
    daisRing.Anchored = true
    daisRing.CanCollide = false
    daisRing.Parent = lobby

    -- Central Spawn Location
    local spawnLocation = Instance.new("SpawnLocation")
    spawnLocation.Name = "SanctuarySpawn"
    spawnLocation.Size = Vector3.new(8, 0.4, 8)
    spawnLocation.CFrame = CFrame.new(0, 1.3, 0)
    spawnLocation.Transparency = 1
    spawnLocation.Anchored = true
    spawnLocation.CanCollide = false
    spawnLocation.Duration = 0
    spawnLocation.Parent = lobby

    -- 3. Hero Statue: Stormforge Valen
    local statueModel = Instance.new("Model")
    statueModel.Name = "StormforgeValenStatue"

    local plinth = Instance.new("Part")
    plinth.Name = "StatuePlinth"
    plinth.Size = Vector3.new(8, 4, 8)
    plinth.CFrame = CFrame.new(-35, 2, -35)
    plinth.Color = Color3.fromRGB(35, 45, 65)
    plinth.Material = Enum.Material.Metal
    plinth.Anchored = true
    plinth.CanCollide = true
    plinth.Parent = statueModel

    local plaque = Instance.new("BillboardGui")
    plaque.Name = "StatuePlaque"
    plaque.Size = UDim2.new(0, 220, 0, 50)
    plaque.StudsOffset = Vector3.new(0, 3, 0)
    plaque.AlwaysOnTop = true
    local plaqueText = Instance.new("TextLabel")
    plaqueText.Size = UDim2.new(1, 0, 1, 0)
    plaqueText.BackgroundTransparency = 1
    plaqueText.Text = "STORMFORGE VALEN\nThe Thunder Champion"
    plaqueText.TextColor3 = Color3.fromRGB(65, 225, 255)
    plaqueText.Font = Enum.Font.GothamBold
    plaqueText.TextSize = 14
    plaqueText.Parent = plaque
    plaque.Parent = plinth

    -- Bronze/Silver Hero Statue Effigy
    local statueBody = Instance.new("Part")
    statueBody.Name = "StatueEffigy"
    statueBody.Size = Vector3.new(3, 7, 2)
    statueBody.CFrame = CFrame.new(-35, 7.5, -35)
    statueBody.Color = Color3.fromRGB(200, 210, 225)
    statueBody.Material = Enum.Material.Metal
    statueBody.Anchored = true
    statueBody.CanCollide = true
    statueBody.Parent = statueModel

    -- Raised warhammer statue arm
    local statueHammer = Instance.new("Part")
    statueHammer.Name = "StatueHammer"
    statueHammer.Size = Vector3.new(1.5, 6, 1.5)
    statueHammer.CFrame = CFrame.new(-33, 11, -35) * CFrame.Angles(0, 0, math.rad(30))
    statueHammer.Color = Color3.fromRGB(65, 225, 255)
    statueHammer.Material = Enum.Material.Neon
    statueHammer.Anchored = true
    statueHammer.CanCollide = false
    statueHammer.Parent = statueModel

    statueModel.Parent = lobby

    -- 4. Portal Area (North Entrance leading to Tempest Wilds)
    local portalArea = Instance.new("Model")
    portalArea.Name = "TempestWildsPortal"

    local portalBase = Instance.new("Part")
    portalBase.Name = "PortalDais"
    portalBase.Size = Vector3.new(16, 1.5, 12)
    portalBase.CFrame = CFrame.new(0, 0.75, 55)
    portalBase.Color = Color3.fromRGB(25, 35, 50)
    portalBase.Material = Enum.Material.Metal
    portalBase.Anchored = true
    portalBase.CanCollide = true
    portalBase.Parent = portalArea

    -- Vertical Ring Frame
    local portalRing = Instance.new("Part")
    portalRing.Name = "PortalRing"
    portalRing.Shape = Enum.PartType.Cylinder
    portalRing.Size = Vector3.new(1.2, 14, 14)
    portalRing.CFrame = CFrame.new(0, 8.5, 55)
    portalRing.Color = Color3.fromRGB(15, 22, 35)
    portalRing.Material = Enum.Material.Metal
    portalRing.Anchored = true
    portalRing.CanCollide = false
    portalRing.Parent = portalArea

    -- Glowing Energy Vortex Gateway
    local portalGate = Instance.new("Part")
    portalGate.Name = "TeleportGatePart"
    portalGate.Shape = Enum.PartType.Cylinder
    portalGate.Size = Vector3.new(0.4, 12, 12)
    portalGate.CFrame = CFrame.new(0, 8.5, 55)
    portalGate.Color = Color3.fromRGB(65, 215, 255)
    portalGate.Material = Enum.Material.Neon
    portalGate.Transparency = 0.35
    portalGate.Anchored = true
    portalGate.CanCollide = false
    portalGate:SetAttribute("TargetZone", "TempestWilds")
    portalGate.Parent = portalArea

    -- Billboard Title
    local portalBillboard = Instance.new("BillboardGui")
    portalBillboard.Name = "PortalSign"
    portalBillboard.Size = UDim2.new(0, 240, 0, 45)
    portalBillboard.StudsOffset = Vector3.new(0, 8, 0)
    portalBillboard.AlwaysOnTop = true
    local signText = Instance.new("TextLabel")
    signText.Size = UDim2.new(1, 0, 1, 0)
    signText.BackgroundTransparency = 1
    signText.Text = "PORTAL: THE TEMPEST WILDS"
    signText.TextColor3 = Color3.fromRGB(65, 225, 255)
    signText.Font = Enum.Font.GothamBold
    signText.TextSize = 16
    signText.Parent = portalBillboard
    portalBillboard.Parent = portalGate

    portalArea.Parent = lobby

    -- 5. Training Area Entrance (East Wing)
    local trainingWing = Instance.new("Model")
    trainingWing.Name = "TrainingWingEntrance"

    createPillar(trainingWing, CFrame.new(55, 6, -10), 12, Color3.fromRGB(30, 40, 58))
    createPillar(trainingWing, CFrame.new(55, 6, 10), 12, Color3.fromRGB(30, 40, 58))

    local archLintel = Instance.new("Part")
    archLintel.Name = "ArchLintel"
    archLintel.Size = Vector3.new(3, 2, 22)
    archLintel.CFrame = CFrame.new(55, 12, 0)
    archLintel.Color = Color3.fromRGB(30, 40, 58)
    archLintel.Material = Enum.Material.Metal
    archLintel.Anchored = true
    archLintel.CanCollide = true
    archLintel.Parent = trainingWing

    local trainingPortal = Instance.new("Part")
    trainingPortal.Name = "TrainingGatePart"
    trainingPortal.Size = Vector3.new(1, 10, 18)
    trainingPortal.CFrame = CFrame.new(55, 6, 0)
    trainingPortal.Color = Color3.fromRGB(255, 195, 45)
    trainingPortal.Material = Enum.Material.Neon
    trainingPortal.Transparency = 0.45
    trainingPortal.Anchored = true
    trainingPortal.CanCollide = false
    trainingPortal:SetAttribute("TargetZone", "TrainingSanctuary")
    trainingPortal.Parent = trainingWing

    trainingWing.Parent = lobby

    -- 6. Interactive Quest Board (West Wing)
    local questBoard = Instance.new("Model")
    questBoard.Name = "SanctuaryQuestBoard"

    local boardFrame = Instance.new("Part")
    boardFrame.Name = "BoardPost"
    boardFrame.Size = Vector3.new(1.2, 8, 12)
    boardFrame.CFrame = CFrame.new(-35, 4.5, 0) * CFrame.Angles(0, math.rad(90), 0)
    boardFrame.Color = Color3.fromRGB(45, 35, 25)
    boardFrame.Material = Enum.Material.WoodPlanks
    boardFrame.Anchored = true
    boardFrame.CanCollide = true
    boardFrame.Parent = questBoard

    local boardHeader = Instance.new("Part")
    boardHeader.Name = "BoardHeader"
    boardHeader.Size = Vector3.new(1.6, 1.2, 13)
    boardHeader.CFrame = CFrame.new(-35, 9, 0) * CFrame.Angles(0, math.rad(90), 0)
    boardHeader.Color = Color3.fromRGB(30, 40, 60)
    boardHeader.Material = Enum.Material.Metal
    boardHeader.Anchored = true
    boardHeader.CanCollide = true
    boardHeader.Parent = questBoard

    local questPrompt = Instance.new("ProximityPrompt")
    questPrompt.ActionText = "Review Quests"
    questPrompt.ObjectText = "Grand Quest Board"
    questPrompt.HoldDuration = 0.25
    questPrompt.MaxActivationDistance = 14
    questPrompt.Parent = boardFrame

    local boardBillboard = Instance.new("BillboardGui")
    boardBillboard.Size = UDim2.new(0, 180, 0, 40)
    boardBillboard.StudsOffset = Vector3.new(0, 5.5, 0)
    boardBillboard.AlwaysOnTop = true
    local boardText = Instance.new("TextLabel")
    boardText.Size = UDim2.new(1, 0, 1, 0)
    boardText.BackgroundTransparency = 1
    boardText.Text = "QUEST BULLETIN"
    boardText.TextColor3 = Color3.fromRGB(255, 215, 65)
    boardText.Font = Enum.Font.GothamBold
    boardText.TextSize = 16
    boardText.Parent = boardBillboard
    boardBillboard.Parent = boardFrame

    questBoard.Parent = lobby

    -- 7. Spawn Friendly NPCs and Sanctuary Merchants
    local function spawnFriendlyNPC(name: string, title: string, cframe: CFrame, color: Color3, merchantId: string?)
        local npc = Instance.new("Model")
        npc.Name = name

        local root = Instance.new("Part")
        root.Name = "HumanoidRootPart"
        root.Size = Vector3.new(2, 2, 1)
        root.CFrame = cframe
        root.Transparency = 1
        root.Anchored = true
        root.CanCollide = false
        root.Parent = npc
        npc.PrimaryPart = root

        local torso = Instance.new("Part")
        torso.Name = "UpperTorso"
        torso.Size = Vector3.new(2, 2.4, 1.1)
        torso.CFrame = cframe
        torso.Color = color
        torso.Material = Enum.Material.SmoothPlastic
        torso.Anchored = true
        torso.CanCollide = true
        torso.Parent = npc

        local head = Instance.new("Part")
        head.Name = "Head"
        head.Size = Vector3.new(1.2, 1.2, 1.2)
        head.CFrame = cframe + Vector3.new(0, 2.1, 0)
        head.Color = Color3.fromRGB(230, 190, 150)
        head.Material = Enum.Material.SmoothPlastic
        head.Anchored = true
        head.CanCollide = false
        head.Parent = npc

        local humanoid = Instance.new("Humanoid")
        humanoid.DisplayName = name
        humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.AlwaysOn
        humanoid.Parent = npc

        local prompt = Instance.new("ProximityPrompt")
        prompt.ActionText = if merchantId then "Trade / Browse" else "Talk"
        prompt.ObjectText = title
        prompt.HoldDuration = 0
        prompt.MaxActivationDistance = 12
        prompt.Parent = torso

        if merchantId then
            npc:SetAttribute("MerchantId", merchantId)
        end

        npc.Parent = lobby
    end

    -- Quest & Combat Guides
    spawnFriendlyNPC("Archivist Orin", "Keeper of Records", CFrame.new(-32, 2, 8) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(65, 140, 215))
    spawnFriendlyNPC("Instructor Kael", "Master-at-Arms", CFrame.new(48, 2, 0) * CFrame.Angles(0, math.rad(-90), 0), Color3.fromRGB(210, 160, 45))

    -- Sanctuary Market Merchants
    spawnFriendlyNPC("Weaponsmith Garrick", "Grand Armorer", CFrame.new(-45, 2, 25) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(180, 80, 50), "WeaponMerchant")
    spawnFriendlyNPC("Vanguard Vane", "Plate Master", CFrame.new(-45, 2, 40) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(80, 110, 190), "ArmorMerchant")
    spawnFriendlyNPC("Alchemist Lyra", "Apothecary of the Mists", CFrame.new(45, 2, 25) * CFrame.Angles(0, math.rad(-90), 0), Color3.fromRGB(60, 180, 120), "PotionMerchant")
    spawnFriendlyNPC("Forge Master Keith", "Master of the Spark", CFrame.new(45, 2, 40) * CFrame.Angles(0, math.rad(-90), 0), Color3.fromRGB(190, 140, 40), "Blacksmith")

    print("[LobbyBuilder] Grand Storm Sanctuary Main Lobby constructed successfully.")
    return lobby
end

return LobbyBuilder
