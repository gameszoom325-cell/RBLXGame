--!strict
--[[
    WorldUIController.client.lua
    Client-side UI for Zone Exploration, Cinematic Zone Banners,
    and Live Quest HUD Tracker.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local networkFolder = ReplicatedStorage:WaitForChild("Network")
local zoneChangedEvent = networkFolder:WaitForChild("ZoneChanged") :: RemoteEvent
local questUpdatedEvent = networkFolder:WaitForChild("QuestUpdated") :: RemoteEvent
local rewardClaimedEvent = networkFolder:WaitForChild("RewardClaimed") :: RemoteEvent
local showDialogueEvent = networkFolder:WaitForChild("ShowDialogue") :: RemoteEvent

-- Construct Master World GUI
local function createWorldGui(): ScreenGui
    local existing = playerGui:FindFirstChild("WorldUI")
    if existing then existing:Destroy() end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "WorldUI"
    screenGui.ResetOnSpawn = false
    screenGui.DisplayOrder = 5

    -- 1. Cinematic Zone Entry Banner (Top Center)
    local bannerFrame = Instance.new("Frame")
    bannerFrame.Name = "ZoneBannerFrame"
    bannerFrame.Size = UDim2.new(0, 450, 0, 75)
    bannerFrame.Position = UDim2.new(0.5, -225, 0.12, 0)
    bannerFrame.BackgroundColor3 = Color3.fromRGB(15, 20, 32)
    bannerFrame.BackgroundTransparency = 1
    bannerFrame.BorderSizePixel = 0
    bannerFrame.Parent = screenGui

    local bannerTitle = Instance.new("TextLabel")
    bannerTitle.Name = "BannerTitle"
    bannerTitle.Size = UDim2.new(1, 0, 0, 38)
    bannerTitle.BackgroundTransparency = 1
    bannerTitle.Text = ""
    bannerTitle.TextColor3 = Color3.fromRGB(65, 225, 255)
    bannerTitle.TextTransparency = 1
    bannerTitle.Font = Enum.Font.GothamBold
    bannerTitle.TextSize = 24
    bannerTitle.Parent = bannerFrame

    local bannerDesc = Instance.new("TextLabel")
    bannerDesc.Name = "BannerDesc"
    bannerDesc.Size = UDim2.new(1, 0, 0, 24)
    bannerDesc.Position = UDim2.new(0, 0, 0, 40)
    bannerDesc.BackgroundTransparency = 1
    bannerDesc.Text = ""
    bannerDesc.TextColor3 = Color3.fromRGB(200, 215, 235)
    bannerDesc.TextTransparency = 1
    bannerDesc.Font = Enum.Font.Gotham
    bannerDesc.TextSize = 13
    bannerDesc.Parent = bannerFrame

    -- 2. Quest HUD Tracker (Docked Top Left)
    local questHUD = Instance.new("Frame")
    questHUD.Name = "QuestHUD"
    questHUD.Size = UDim2.new(0, 260, 0, 160)
    questHUD.Position = UDim2.new(0, 18, 0, 18)
    questHUD.BackgroundColor3 = Color3.fromRGB(18, 24, 38)
    questHUD.BackgroundTransparency = 0.2
    questHUD.BorderSizePixel = 0
    questHUD.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = questHUD

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 215, 65)
    stroke.Thickness = 1
    stroke.Parent = questHUD

    local hudTitle = Instance.new("TextLabel")
    hudTitle.Size = UDim2.new(1, -20, 0, 30)
    hudTitle.Position = UDim2.new(0, 10, 0, 5)
    hudTitle.BackgroundTransparency = 1
    hudTitle.Text = "ACTIVE QUESTS"
    hudTitle.TextColor3 = Color3.fromRGB(255, 215, 65)
    hudTitle.Font = Enum.Font.GothamBold
    hudTitle.TextSize = 13
    hudTitle.TextXAlignment = Enum.TextXAlignment.Left
    hudTitle.Parent = questHUD

    local questListContainer = Instance.new("Frame")
    questListContainer.Name = "QuestList"
    questListContainer.Size = UDim2.new(1, -20, 1, -40)
    questListContainer.Position = UDim2.new(0, 10, 0, 35)
    questListContainer.BackgroundTransparency = 1
    questListContainer.Parent = questHUD

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 6)
    listLayout.Parent = questListContainer

    -- Handle Zone Entry Cinematic Banner
    zoneChangedEvent.OnClientEvent:Connect(function(zoneName: string, zoneDesc: string, isSafe: boolean)
        bannerTitle.Text = string.upper(zoneName)
        bannerDesc.Text = zoneDesc
        bannerTitle.TextColor3 = if isSafe then Color3.fromRGB(65, 225, 255) else Color3.fromRGB(255, 90, 90)

        -- Fade In
        local tweenIn1 = TweenService:Create(bannerTitle, TweenInfo.new(0.4), { TextTransparency = 0 })
        local tweenIn2 = TweenService:Create(bannerDesc, TweenInfo.new(0.4), { TextTransparency = 0 })
        tweenIn1:Play()
        tweenIn2:Play()

        -- Fade Out after 3.2s
        task.delay(3.2, function()
            local tweenOut1 = TweenService:Create(bannerTitle, TweenInfo.new(0.5), { TextTransparency = 1 })
            local tweenOut2 = TweenService:Create(bannerDesc, TweenInfo.new(0.5), { TextTransparency = 1 })
            tweenOut1:Play()
            tweenOut2:Play()
        end)
    end)

    -- Handle Quest Updates
    questUpdatedEvent.OnClientEvent:Connect(function(questId: string, title: string, current: number, target: number, isCompleted: boolean)
        local row = questListContainer:FindFirstChild(questId) :: TextLabel?
        if not row then
            row = Instance.new("TextLabel")
            row.Name = questId
            row.Size = UDim2.new(1, 0, 0, 32)
            row.BackgroundTransparency = 1
            row.Font = Enum.Font.GothamMedium
            row.TextSize = 11
            row.TextXAlignment = Enum.TextXAlignment.Left
            row.TextWrapped = true
            row.Parent = questListContainer
        end

        if isCompleted then
            row.Text = string.format("[✓] %s: Ready to claim!", title)
            row.TextColor3 = Color3.fromRGB(80, 255, 120)
        else
            row.Text = string.format("• %s: (%d/%d)", title, current, target)
            row.TextColor3 = Color3.fromRGB(220, 230, 245)
        end
    end)

    -- 3. Interactive Dialogue Frame (Bottom Center)
    local dialogueBox = Instance.new("Frame")
    dialogueBox.Name = "DialogueBox"
    dialogueBox.Size = UDim2.new(0, 520, 0, 95)
    dialogueBox.Position = UDim2.new(0.5, -260, 0.78, 0)
    dialogueBox.BackgroundColor3 = Color3.fromRGB(15, 22, 34)
    dialogueBox.BackgroundTransparency = 1
    dialogueBox.BorderSizePixel = 0
    dialogueBox.Parent = screenGui

    local dCorner = Instance.new("UICorner")
    dCorner.CornerRadius = UDim.new(0, 10)
    dCorner.Parent = dialogueBox

    local dStroke = Instance.new("UIStroke")
    dStroke.Color = Color3.fromRGB(65, 225, 255)
    dStroke.Thickness = 1.5
    dStroke.Transparency = 1
    dStroke.Parent = dialogueBox

    local speakerLabel = Instance.new("TextLabel")
    speakerLabel.Name = "SpeakerLabel"
    speakerLabel.Size = UDim2.new(1, -24, 0, 26)
    speakerLabel.Position = UDim2.new(0, 12, 0, 8)
    speakerLabel.BackgroundTransparency = 1
    speakerLabel.Font = Enum.Font.GothamBold
    speakerLabel.TextSize = 14
    speakerLabel.TextColor3 = Color3.fromRGB(65, 225, 255)
    speakerLabel.TextTransparency = 1
    speakerLabel.TextXAlignment = Enum.TextXAlignment.Left
    speakerLabel.Parent = dialogueBox

    local speechLabel = Instance.new("TextLabel")
    speechLabel.Name = "SpeechLabel"
    speechLabel.Size = UDim2.new(1, -24, 0, 50)
    speechLabel.Position = UDim2.new(0, 12, 0, 36)
    speechLabel.BackgroundTransparency = 1
    speechLabel.Font = Enum.Font.Gotham
    speechLabel.TextSize = 13
    speechLabel.TextColor3 = Color3.fromRGB(235, 242, 255)
    speechLabel.TextTransparency = 1
    speechLabel.TextWrapped = true
    speechLabel.TextXAlignment = Enum.TextXAlignment.Left
    speechLabel.TextYAlignment = Enum.TextYAlignment.Top
    speechLabel.Parent = dialogueBox

    -- Handle Dialogue Events
    showDialogueEvent.OnClientEvent:Connect(function(speakerName: string, message: string, titleTag: string?)
        speakerLabel.Text = string.format("%s%s", speakerName, if titleTag then string.format(" [%s]", titleTag) else "")
        speechLabel.Text = message

        -- Fade In Dialogue Box
        TweenService:Create(dialogueBox, TweenInfo.new(0.25), { BackgroundTransparency = 0.15 }):Play()
        TweenService:Create(dStroke, TweenInfo.new(0.25), { Transparency = 0 }):Play()
        TweenService:Create(speakerLabel, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()
        TweenService:Create(speechLabel, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()

        -- Auto fade out after reading duration
        task.delay(5.5, function()
            TweenService:Create(dialogueBox, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
            TweenService:Create(dStroke, TweenInfo.new(0.4), { Transparency = 1 }):Play()
            TweenService:Create(speakerLabel, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
            TweenService:Create(speechLabel, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
        end)
    end)

    -- Handle Reward Notification
    rewardClaimedEvent.OnClientEvent:Connect(function(title: string, gold: number, xp: number, level: number)
        print(string.format("[WorldUI] Claimed rewards for '%s': +%d Gold, +%d XP! (Current Level: %d)", title, gold, xp, level))
    end)

    screenGui.Parent = playerGui
    return screenGui
end

createWorldGui()
print("[WorldUIController] Initialized: Cinematic Zone Banners & Quest HUD Tracker active.")
