--!strict
--[[
    CharacterController.client.lua
    Manages local player character state, hero selection UI flow,
    and third-person camera setup for Hero Roleplay.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local CharacterRegistry = require(Shared:WaitForChild("CharacterRegistry"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local networkFolder = ReplicatedStorage:WaitForChild("Network")
local openHeroSelectionEvent = networkFolder:WaitForChild("OpenHeroSelection") :: RemoteEvent
local selectHeroFunction = networkFolder:WaitForChild("SelectHero") :: RemoteFunction

local CharacterController = {}

-- Construct Hero Selection ScreenGui
local function createHeroSelectionUI(): ScreenGui
    local existingGui = playerGui:FindFirstChild("HeroSelectionGui")
    if existingGui then
        return existingGui :: ScreenGui
    end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "HeroSelectionGui"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 520, 0, 380)
    mainFrame.Position = UDim2.new(0.5, -260, 0.5, -190)
    mainFrame.BackgroundColor3 = Color3.fromRGB(18, 24, 38)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = mainFrame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(65, 215, 255)
    stroke.Thickness = 2
    stroke.Parent = mainFrame

    -- Header Title
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.Size = UDim2.new(1, 0, 0, 50)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "CHOOSE YOUR HERO"
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 22
    titleLabel.TextColor3 = Color3.fromRGB(240, 245, 255)
    titleLabel.Parent = mainFrame

    -- Hero Card Container
    local cardFrame = Instance.new("Frame")
    cardFrame.Name = "CardFrame"
    cardFrame.Size = UDim2.new(1, -40, 1, -130)
    cardFrame.Position = UDim2.new(0, 20, 0, 60)
    cardFrame.BackgroundColor3 = Color3.fromRGB(26, 36, 56)
    cardFrame.BorderSizePixel = 0
    cardFrame.Parent = mainFrame

    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 8)
    cardCorner.Parent = cardFrame

    local heroNameLabel = Instance.new("TextLabel")
    heroNameLabel.Size = UDim2.new(1, -20, 0, 36)
    heroNameLabel.Position = UDim2.new(0, 10, 0, 10)
    heroNameLabel.BackgroundTransparency = 1
    heroNameLabel.Text = "Stormforge Valen"
    heroNameLabel.Font = Enum.Font.GothamBold
    heroNameLabel.TextSize = 20
    heroNameLabel.TextColor3 = Color3.fromRGB(65, 225, 255)
    heroNameLabel.TextXAlignment = Enum.TextXAlignment.Left
    heroNameLabel.Parent = cardFrame

    local heroRoleLabel = Instance.new("TextLabel")
    heroRoleLabel.Size = UDim2.new(1, -20, 0, 24)
    heroRoleLabel.Position = UDim2.new(0, 10, 0, 46)
    heroRoleLabel.BackgroundTransparency = 1
    heroRoleLabel.Text = "Role: Legendary Lightning Warrior | Weapon: Stormforge Warhammer"
    heroRoleLabel.Font = Enum.Font.Gotham
    heroRoleLabel.TextSize = 13
    heroRoleLabel.TextColor3 = Color3.fromRGB(180, 200, 220)
    heroRoleLabel.TextXAlignment = Enum.TextXAlignment.Left
    heroRoleLabel.Parent = cardFrame

    local heroDescLabel = Instance.new("TextLabel")
    heroDescLabel.Size = UDim2.new(1, -20, 0, 70)
    heroDescLabel.Position = UDim2.new(0, 10, 0, 75)
    heroDescLabel.BackgroundTransparency = 1
    heroDescLabel.Text = "Channels thunderous fury through the sacred Stormforge Warhammer. Features Lightning Strike, Thunder Hammer Slam, Storm Shield, and Lightning Dash."
    heroDescLabel.Font = Enum.Font.Gotham
    heroDescLabel.TextSize = 12
    heroDescLabel.TextColor3 = Color3.fromRGB(210, 220, 235)
    heroDescLabel.TextWrapped = true
    heroDescLabel.TextXAlignment = Enum.TextXAlignment.Left
    heroDescLabel.Parent = cardFrame

    -- Select Hero Button
    local selectBtn = Instance.new("TextButton")
    selectBtn.Name = "SelectButton"
    selectBtn.Size = UDim2.new(1, -40, 0, 46)
    selectBtn.Position = UDim2.new(0, 20, 1, -60)
    selectBtn.BackgroundColor3 = Color3.fromRGB(0, 160, 230)
    selectBtn.Text = "SPAWN AS STORMFORGE VALEN"
    selectBtn.Font = Enum.Font.GothamBold
    selectBtn.TextSize = 15
    selectBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    selectBtn.Parent = mainFrame

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = selectBtn

    selectBtn.MouseButton1Click:Connect(function()
        selectBtn.Text = "LOADING HERO..."
        selectBtn.Active = false

        local success = selectHeroFunction:InvokeServer("StormforgeValen")
        if success then
            screenGui.Enabled = false
            print("[CharacterController] Successfully selected Stormforge Valen!")
        else
            selectBtn.Text = "SELECTION FAILED - RETRY"
            selectBtn.Active = true
        end
    end)

    screenGui.Parent = playerGui
    return screenGui
end

-- Open Selection UI when requested by server
openHeroSelectionEvent.OnClientEvent:Connect(function()
    local gui = createHeroSelectionUI()
    gui.Enabled = true
end)

return CharacterController
