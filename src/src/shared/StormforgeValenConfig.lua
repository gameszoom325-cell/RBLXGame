--!strict
--[[
    StormforgeValenConfig.lua
    Complete character configuration for Stormforge Valen.
    Legendary Lightning Warrior & Fantasy Hero.
    Production fixes: verified attachment points for gauntlets, left boot, and right boot.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))

local StormforgeValenConfig: Types.CharacterConfig = {
    id = "StormforgeValen",
    name = "Stormforge Valen",
    title = "The Thunder Champion",
    role = "Legendary Lightning Warrior",
    description = "A noble titan forged in the heart of tempest storms. Channeling thunderous fury through the sacred Stormforge Warhammer, Valen guards the realm with electrified fortitude.",

    stats = {
        health = 250,
        walkSpeed = 18,
        jumpPower = 54,
        power = 120,
        armor = 85,
    },

    scaling = {
        height = 1.08,
        width = 1.15,
        depth = 1.05,
        head = 0.95,
        bodyType = 1.0,
        proportions = 0.0,
    },

    colors = {
        ArmorSilver = Color3.fromRGB(215, 225, 235),
        ArmorNavy = Color3.fromRGB(20, 32, 55),
        LightningNeon = Color3.fromRGB(65, 225, 255),
        CapeCrimson = Color3.fromRGB(190, 35, 45),
        HairNavy = Color3.fromRGB(15, 22, 38),
        HammerGlow = Color3.fromRGB(80, 240, 255),
    },

    accessories = {
        Hair = {
            id = "Valen_Hair",
            name = "Swept-Back Tempest Hair",
            attachmentPoint = "HairAttachment",
            parentPart = "Head",
            accessoryType = "Hair",
            color = Color3.fromRGB(15, 22, 38),
            material = Enum.Material.SmoothPlastic,
        },
        ChestArmor = {
            id = "Valen_Chestplate",
            name = "Storm Crown Breastplate",
            attachmentPoint = "BodyFrontAttachment",
            parentPart = "UpperTorso",
            accessoryType = "Front",
            color = Color3.fromRGB(215, 225, 235),
            material = Enum.Material.Metal,
        },
        LeftPauldron = {
            id = "Valen_LeftShoulder",
            name = "Thunder Spire Left Guard",
            attachmentPoint = "LeftShoulderAttachment",
            parentPart = "LeftUpperArm",
            accessoryType = "Shoulder",
            color = Color3.fromRGB(20, 32, 55),
            material = Enum.Material.Metal,
        },
        RightPauldron = {
            id = "Valen_RightShoulder",
            name = "Thunder Spire Right Guard",
            attachmentPoint = "RightShoulderAttachment",
            parentPart = "RightUpperArm",
            accessoryType = "Shoulder",
            color = Color3.fromRGB(20, 32, 55),
            material = Enum.Material.Metal,
        },
        Cape = {
            id = "Valen_Cape",
            name = "Vanguard Crimson Cloak",
            attachmentPoint = "BodyBackAttachment",
            parentPart = "UpperTorso",
            accessoryType = "Back",
            color = Color3.fromRGB(190, 35, 45),
            material = Enum.Material.Fabric,
        },
        ArmGauntlets = {
            id = "Valen_Gauntlets",
            name = "Conductor Gauntlets",
            attachmentPoint = "RightGripAttachment",
            parentPart = "RightHand",
            accessoryType = "Front",
            color = Color3.fromRGB(215, 225, 235),
            material = Enum.Material.Metal,
        },
        LeftBoot = {
            id = "Valen_Boots",
            name = "Tempest Left Greave",
            attachmentPoint = "LeftFootAttachment",
            parentPart = "LeftFoot",
            accessoryType = "Front",
            color = Color3.fromRGB(20, 32, 55),
            material = Enum.Material.Metal,
        },
        RightBoot = {
            id = "Valen_RightBoot",
            name = "Tempest Right Greave",
            attachmentPoint = "RightFootAttachment",
            parentPart = "RightFoot",
            accessoryType = "Front",
            color = Color3.fromRGB(20, 32, 55),
            material = Enum.Material.Metal,
        },
    },

    weapon = {
        id = "StormforgeWarhammer",
        name = "Stormforge Warhammer",
        gripAttachment = "RightGripAttachment",
        damage = 65,
        range = 9,
        modelName = "StormforgeWarhammerModel",
        glowColor = Color3.fromRGB(80, 240, 255),
    },

    abilities = {
        "LightningStrike",
        "ThunderHammerSlam",
        "StormShield",
        "LightningDash",
    },

    animations = {
        Idle = "rbxassetid://507766388",
        Walk = "rbxassetid://507777826",
        Run = "rbxassetid://507767714",
        Jump = "rbxassetid://507765000",
        Attack = "rbxassetid://522635533",
        HeavyAttack = "rbxassetid://522638767",
        AbilityCast = "rbxassetid://522634455",
        VictoryPose = "rbxassetid://522639900",
    },
}

return StormforgeValenConfig
