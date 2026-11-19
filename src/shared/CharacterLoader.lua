--!strict
--[[
    CharacterLoader.lua
    Modular character builder, R15 rig assembler, and hero spawner.
    Supports procedural R15 creation, modular accessory welding, and weapon mounting.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local CharacterRegistry = require(Shared:WaitForChild("CharacterRegistry"))

local CharacterLoader = {}

-- Utility to create a motor joint between two parts
local function createMotor6D(name: string, part0: BasePart, part1: BasePart, c0: CFrame, c1: CFrame): Motor6D
    local motor = Instance.new("Motor6D")
    motor.Name = name
    motor.Part0 = part0
    motor.Part1 = part1
    motor.C0 = c0
    motor.C1 = c1
    motor.Parent = part0
    return motor
end

-- Utility to create an attachment
local function createAttachment(name: string, parent: BasePart, cframe: CFrame?): Attachment
    local attachment = Instance.new("Attachment")
    attachment.Name = name
    if cframe then
        attachment.CFrame = cframe
    end
    attachment.Parent = parent
    return attachment
end

-- Constructs a mathematically compliant standard R15 humanoid rig from scratch
function CharacterLoader.BuildBaseR15Model(name: string?): Model
    local model = Instance.new("Model")
    model.Name = name or "StormforgeValen"

    -- 1. HumanoidRootPart
    local hrp = Instance.new("Part")
    hrp.Name = "HumanoidRootPart"
    hrp.Size = Vector3.new(2, 2, 1)
    hrp.Transparency = 1
    hrp.CanCollide = false
    hrp.RootPriority = 127
    hrp.Parent = model
    model.PrimaryPart = hrp
    createAttachment("RootRigAttachment", hrp, CFrame.new(0, 0, 0))

    -- 2. LowerTorso
    local lowerTorso = Instance.new("Part")
    lowerTorso.Name = "LowerTorso"
    lowerTorso.Size = Vector3.new(2, 0.4, 1)
    lowerTorso.Color = Color3.fromRGB(20, 32, 55)
    lowerTorso.Material = Enum.Material.Metal
    lowerTorso.CanCollide = false
    lowerTorso.Parent = model
    createAttachment("RootRigAttachment", lowerTorso, CFrame.new(0, -0.2, 0))
    createAttachment("WaistRigAttachment", lowerTorso, CFrame.new(0, 0.2, 0))
    createAttachment("WaistCenterAttachment", lowerTorso, CFrame.new(0, 0, 0))

    -- 3. UpperTorso
    local upperTorso = Instance.new("Part")
    upperTorso.Name = "UpperTorso"
    upperTorso.Size = Vector3.new(2.2, 1.6, 1.1)
    upperTorso.Color = Color3.fromRGB(215, 225, 235)
    upperTorso.Material = Enum.Material.Metal
    upperTorso.CanCollide = false
    upperTorso.Parent = model
    createAttachment("WaistRigAttachment", upperTorso, CFrame.new(0, -0.8, 0))
    createAttachment("NeckRigAttachment", upperTorso, CFrame.new(0, 0.8, 0))
    createAttachment("NeckAttachment", upperTorso, CFrame.new(0, 0.8, 0))
    createAttachment("BodyFrontAttachment", upperTorso, CFrame.new(0, 0, -0.55))
    createAttachment("BodyBackAttachment", upperTorso, CFrame.new(0, 0, 0.55))
    createAttachment("LeftCollarAttachment", upperTorso, CFrame.new(-1.1, 0.8, 0))
    createAttachment("RightCollarAttachment", upperTorso, CFrame.new(1.1, 0.8, 0))
    createAttachment("LeftShoulderRigAttachment", upperTorso, CFrame.new(-1.1, 0.6, 0))
    createAttachment("RightShoulderRigAttachment", upperTorso, CFrame.new(1.1, 0.6, 0))

    -- 4. Head
    local head = Instance.new("Part")
    head.Name = "Head"
    head.Size = Vector3.new(1.2, 1.2, 1.2)
    head.Color = Color3.fromRGB(235, 185, 145)
    head.Material = Enum.Material.SmoothPlastic
    head.CanCollide = false
    head.Parent = model
    createAttachment("NeckRigAttachment", head, CFrame.new(0, -0.6, 0))
    createAttachment("HairAttachment", head, CFrame.new(0, 0.6, 0))
    createAttachment("HatAttachment", head, CFrame.new(0, 0.6, 0))
    createAttachment("FaceCenterAttachment", head, CFrame.new(0, 0, -0.6))

    -- 5. Left Arm
    local leftUpperArm = Instance.new("Part")
    leftUpperArm.Name = "LeftUpperArm"
    leftUpperArm.Size = Vector3.new(1, 1.2, 1)
    leftUpperArm.Color = Color3.fromRGB(20, 32, 55)
    leftUpperArm.Material = Enum.Material.Metal
    leftUpperArm.CanCollide = false
    leftUpperArm.Parent = model
    createAttachment("LeftShoulderRigAttachment", leftUpperArm, CFrame.new(0, 0.5, 0))
    createAttachment("LeftShoulderAttachment", leftUpperArm, CFrame.new(0, 0.5, 0))
    createAttachment("LeftElbowRigAttachment", leftUpperArm, CFrame.new(0, -0.5, 0))

    local leftLowerArm = Instance.new("Part")
    leftLowerArm.Name = "LeftLowerArm"
    leftLowerArm.Size = Vector3.new(1, 1.2, 1)
    leftLowerArm.Color = Color3.fromRGB(215, 225, 235)
    leftLowerArm.Material = Enum.Material.Metal
    leftLowerArm.CanCollide = false
    leftLowerArm.Parent = model
    createAttachment("LeftElbowRigAttachment", leftLowerArm, CFrame.new(0, 0.5, 0))
    createAttachment("LeftWristRigAttachment", leftLowerArm, CFrame.new(0, -0.5, 0))

    local leftHand = Instance.new("Part")
    leftHand.Name = "LeftHand"
    leftHand.Size = Vector3.new(1, 0.6, 1)
    leftHand.Color = Color3.fromRGB(20, 32, 55)
    leftHand.Material = Enum.Material.Metal
    leftHand.CanCollide = false
    leftHand.Parent = model
    createAttachment("LeftWristRigAttachment", leftHand, CFrame.new(0, 0.25, 0))
    createAttachment("LeftGripAttachment", leftHand, CFrame.new(0, -0.2, 0))

    -- 6. Right Arm
    local rightUpperArm = Instance.new("Part")
    rightUpperArm.Name = "RightUpperArm"
    rightUpperArm.Size = Vector3.new(1, 1.2, 1)
    rightUpperArm.Color = Color3.fromRGB(20, 32, 55)
    rightUpperArm.Material = Enum.Material.Metal
    rightUpperArm.CanCollide = false
    rightUpperArm.Parent = model
    createAttachment("RightShoulderRigAttachment", rightUpperArm, CFrame.new(0, 0.5, 0))
    createAttachment("RightShoulderAttachment", rightUpperArm, CFrame.new(0, 0.5, 0))
    createAttachment("RightElbowRigAttachment", rightUpperArm, CFrame.new(0, -0.5, 0))

    local rightLowerArm = Instance.new("Part")
    rightLowerArm.Name = "RightLowerArm"
    rightLowerArm.Size = Vector3.new(1, 1.2, 1)
    rightLowerArm.Color = Color3.fromRGB(215, 225, 235)
    rightLowerArm.Material = Enum.Material.Metal
    rightLowerArm.CanCollide = false
    rightLowerArm.Parent = model
    createAttachment("RightElbowRigAttachment", rightLowerArm, CFrame.new(0, 0.5, 0))
    createAttachment("RightWristRigAttachment", rightLowerArm, CFrame.new(0, -0.5, 0))

    local rightHand = Instance.new("Part")
    rightHand.Name = "RightHand"
    rightHand.Size = Vector3.new(1, 0.6, 1)
    rightHand.Color = Color3.fromRGB(20, 32, 55)
    rightHand.Material = Enum.Material.Metal
    rightHand.CanCollide = false
    rightHand.Parent = model
    createAttachment("RightWristRigAttachment", rightHand, CFrame.new(0, 0.25, 0))
    createAttachment("RightGripAttachment", rightHand, CFrame.new(0, -0.2, 0))

    -- 7. Left Leg
    local leftUpperLeg = Instance.new("Part")
    leftUpperLeg.Name = "LeftUpperLeg"
    leftUpperLeg.Size = Vector3.new(1, 1.4, 1)
    leftUpperLeg.Color = Color3.fromRGB(20, 32, 55)
    leftUpperLeg.Material = Enum.Material.Metal
    leftUpperLeg.CanCollide = false
    leftUpperLeg.Parent = model
    createAttachment("LeftHipRigAttachment", leftUpperLeg, CFrame.new(0, 0.6, 0))
    createAttachment("LeftKneeRigAttachment", leftUpperLeg, CFrame.new(0, -0.6, 0))

    local leftLowerLeg = Instance.new("Part")
    leftLowerLeg.Name = "LeftLowerLeg"
    leftLowerLeg.Size = Vector3.new(1, 1.4, 1)
    leftLowerLeg.Color = Color3.fromRGB(215, 225, 235)
    leftLowerLeg.Material = Enum.Material.Metal
    leftLowerLeg.CanCollide = false
    leftLowerLeg.Parent = model
    createAttachment("LeftKneeRigAttachment", leftLowerLeg, CFrame.new(0, 0.6, 0))
    createAttachment("LeftAnkleRigAttachment", leftLowerLeg, CFrame.new(0, -0.6, 0))

    local leftFoot = Instance.new("Part")
    leftFoot.Name = "LeftFoot"
    leftFoot.Size = Vector3.new(1, 0.6, 1.2)
    leftFoot.Color = Color3.fromRGB(20, 32, 55)
    leftFoot.Material = Enum.Material.Metal
    leftFoot.CanCollide = false
    leftFoot.Parent = model
    createAttachment("LeftAnkleRigAttachment", leftFoot, CFrame.new(0, 0.25, 0))
    createAttachment("LeftFootAttachment", leftFoot, CFrame.new(0, -0.2, 0))

    -- 8. Right Leg
    local rightUpperLeg = Instance.new("Part")
    rightUpperLeg.Name = "RightUpperLeg"
    rightUpperLeg.Size = Vector3.new(1, 1.4, 1)
    rightUpperLeg.Color = Color3.fromRGB(20, 32, 55)
    rightUpperLeg.Material = Enum.Material.Metal
    rightUpperLeg.CanCollide = false
    rightUpperLeg.Parent = model
    createAttachment("RightHipRigAttachment", rightUpperLeg, CFrame.new(0, 0.6, 0))
    createAttachment("RightKneeRigAttachment", rightUpperLeg, CFrame.new(0, -0.6, 0))

    local rightLowerLeg = Instance.new("Part")
    rightLowerLeg.Name = "RightLowerLeg"
    rightLowerLeg.Size = Vector3.new(1, 1.4, 1)
    rightLowerLeg.Color = Color3.fromRGB(215, 225, 235)
    rightLowerLeg.Material = Enum.Material.Metal
    rightLowerLeg.CanCollide = false
    rightLowerLeg.Parent = model
    createAttachment("RightKneeRigAttachment", rightLowerLeg, CFrame.new(0, 0.6, 0))
    createAttachment("RightAnkleRigAttachment", rightLowerLeg, CFrame.new(0, -0.6, 0))

    local rightFoot = Instance.new("Part")
    rightFoot.Name = "RightFoot"
    rightFoot.Size = Vector3.new(1, 0.6, 1.2)
    rightFoot.Color = Color3.fromRGB(20, 32, 55)
    rightFoot.Material = Enum.Material.Metal
    rightFoot.CanCollide = false
    rightFoot.Parent = model
    createAttachment("RightAnkleRigAttachment", rightFoot, CFrame.new(0, 0.25, 0))
    createAttachment("RightFootAttachment", rightFoot, CFrame.new(0, -0.2, 0))

    -- Motor6D Joint Graph Assembly
    createMotor6D("RootJoint", hrp, lowerTorso, CFrame.new(0, 0, 0), CFrame.new(0, 0, 0))
    createMotor6D("Waist", lowerTorso, upperTorso, CFrame.new(0, 0.2, 0), CFrame.new(0, -0.8, 0))
    createMotor6D("Neck", upperTorso, head, CFrame.new(0, 0.8, 0), CFrame.new(0, -0.6, 0))

    createMotor6D("LeftShoulder", upperTorso, leftUpperArm, CFrame.new(-1.1, 0.6, 0), CFrame.new(0, 0.5, 0))
    createMotor6D("LeftElbow", leftUpperArm, leftLowerArm, CFrame.new(0, -0.5, 0), CFrame.new(0, 0.5, 0))
    createMotor6D("LeftWrist", leftLowerArm, leftHand, CFrame.new(0, -0.5, 0), CFrame.new(0, 0.25, 0))

    createMotor6D("RightShoulder", upperTorso, rightUpperArm, CFrame.new(1.1, 0.6, 0), CFrame.new(0, 0.5, 0))
    createMotor6D("RightElbow", rightUpperArm, rightLowerArm, CFrame.new(0, -0.5, 0), CFrame.new(0, 0.5, 0))
    createMotor6D("RightWrist", rightLowerArm, rightHand, CFrame.new(0, -0.5, 0), CFrame.new(0, 0.25, 0))

    createMotor6D("LeftHip", lowerTorso, leftUpperLeg, CFrame.new(-0.5, -0.2, 0), CFrame.new(0, 0.6, 0))
    createMotor6D("LeftKnee", leftUpperLeg, leftLowerLeg, CFrame.new(0, -0.6, 0), CFrame.new(0, 0.6, 0))
    createMotor6D("LeftAnkle", leftLowerLeg, leftFoot, CFrame.new(0, -0.6, 0), CFrame.new(0, 0.25, 0))

    createMotor6D("RightHip", lowerTorso, rightUpperLeg, CFrame.new(0.5, -0.2, 0), CFrame.new(0, 0.6, 0))
    createMotor6D("RightKnee", rightUpperLeg, rightLowerLeg, CFrame.new(0, -0.6, 0), CFrame.new(0, 0.6, 0))
    createMotor6D("RightAnkle", rightLowerLeg, rightFoot, CFrame.new(0, -0.6, 0), CFrame.new(0, 0.25, 0))

    -- Humanoid Configuration
    local humanoid = Instance.new("Humanoid")
    humanoid.RigType = Enum.HumanoidRigType.R15
    humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
    humanoid.Parent = model

    return model
end

-- Applies Hero scaling numbers
function CharacterLoader.ApplyScaling(humanoid: Humanoid, scaling: Types.R15Scaling)
    local function setScale(name: string, val: number)
        local valueObj = humanoid:FindFirstChild(name) :: NumberValue
        if not valueObj then
            valueObj = Instance.new("NumberValue")
            valueObj.Name = name
            valueObj.Parent = humanoid
        end
        valueObj.Value = val
    end

    setScale("BodyHeightScale", scaling.height)
    setScale("BodyWidthScale", scaling.width)
    setScale("BodyDepthScale", scaling.depth)
    setScale("HeadScale", scaling.head)
    setScale("BodyTypeScale", scaling.bodyType)
    setScale("BodyProportionScale", scaling.proportions)
end

-- Equips modular accessories onto the character
function CharacterLoader.EquipAccessories(character: Model, config: Types.CharacterConfig)
    local humanoid = character:WaitForChild("Humanoid") :: Humanoid

    -- Look for prebuilt assets in ReplicatedStorage.Assets if available
    local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
    local accessoriesFolder = assetsFolder and assetsFolder:FindFirstChild("Characters")
        and assetsFolder.Characters:FindFirstChild("StormforgeValen")
        and assetsFolder.Characters.StormforgeValen:FindFirstChild("Accessories")

    for _, accSpec in pairs(config.accessories) do
        local prebuilt = accessoriesFolder and accessoriesFolder:FindFirstChild(accSpec.id) :: Accessory
        if prebuilt then
            local clone = prebuilt:Clone()
            humanoid:AddAccessory(clone)
        else
            -- Programmatic fallback accessory
            local parentPart = character:FindFirstChild(accSpec.parentPart) :: BasePart
            if parentPart then
                local accessory = Instance.new("Accessory")
                accessory.Name = accSpec.id

                local handle = Instance.new("Part")
                handle.Name = "Handle"
                handle.Size = Vector3.new(1.2, 1.2, 0.8)
                handle.Color = accSpec.color or Color3.fromRGB(200, 200, 200)
                handle.Material = accSpec.material or Enum.Material.SmoothPlastic
                handle.CanCollide = false
                handle.Massless = true
                handle.Parent = accessory

                local attachment = Instance.new("Attachment")
                attachment.Name = accSpec.attachmentPoint
                attachment.Parent = handle

                humanoid:AddAccessory(accessory)
            end
        end
    end
end

-- Equips the Stormforge Warhammer tool
function CharacterLoader.EquipWeapon(player: Player, config: Types.CharacterConfig)
    local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
    local weaponsFolder = assetsFolder and assetsFolder:FindFirstChild("Weapons")
    local warhammerAsset = weaponsFolder and weaponsFolder:FindFirstChild("StormforgeWarhammer") :: Tool

    local tool: Tool
    if warhammerAsset then
        tool = warhammerAsset:Clone()
    else
        tool = Instance.new("Tool")
        tool.Name = config.weapon.name
        tool.RequiresHandle = true
        tool.CanBeDropped = false

        local handle = Instance.new("Part")
        handle.Name = "Handle"
        handle.Size = Vector3.new(1.4, 4.2, 1.8)
        handle.Color = Color3.fromRGB(215, 225, 235)
        handle.Material = Enum.Material.Metal
        handle.CanCollide = false
        handle.Parent = tool
    end

    tool:SetAttribute("Damage", config.weapon.damage)
    tool:SetAttribute("Range", config.weapon.range)
    tool:SetAttribute("WeaponId", config.weapon.id)
    tool.Parent = player.Backpack
end

-- Full Spawning Pipeline for a player
function CharacterLoader.SpawnHero(player: Player, heroId: Types.CharacterId): Model?
    local config = CharacterRegistry.GetCharacter(heroId)
    if not config then
        warn(string.format("[CharacterLoader] Hero %s not found in registry.", heroId))
        return nil
    end

    -- If player already has an R15 character, morph it, otherwise build from scratch
    local character = player.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then
        character = CharacterLoader.BuildBaseR15Model(player.Name)
        character.Parent = workspace
        player.Character = character
    end

    local humanoid = character:WaitForChild("Humanoid") :: Humanoid
    humanoid.MaxHealth = config.stats.health
    humanoid.Health = config.stats.health
    humanoid.WalkSpeed = config.stats.walkSpeed
    humanoid.JumpPower = config.stats.jumpPower

    -- Apply Scaling
    CharacterLoader.ApplyScaling(humanoid, config.scaling)

    -- Attach Accessories
    CharacterLoader.EquipAccessories(character, config)

    -- Equip Weapon Tool
    CharacterLoader.EquipWeapon(player, config)

    -- Tag metadata
    character:SetAttribute("HeroId", config.id)
    character:SetAttribute("HeroTitle", config.title)
    character:SetAttribute("HeroRole", config.role)

    print(string.format("[CharacterLoader] Successfully spawned hero %s for player %s", config.name, player.Name))
    return character
end

return CharacterLoader
