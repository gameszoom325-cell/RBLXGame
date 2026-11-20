--!strict
--[[
    MultiplayerUIController.client.lua
    Master Client Interface for Phase 8 Multiplayer Systems:
    - Party UI & Invite Modal (Top-Left)
    - Cinematic Boss Health Bar with Phase Markers & Enrage Countdown (Top-Center)
    - Dungeon Objective Tracker, Lives & Countdown Timer (Top-Right)
    - Dungeon Results Victory/Defeat Screen
    - Global World Event Marquee Banner
    - Achievement Unlock Celebration Banner
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProgressionTypes = require(Shared:WaitForChild("ProgressionTypes"))

local networkFolder = ReplicatedStorage:WaitForChild("Network")
local partyActionEvent = networkFolder:WaitForChild("PartyAction") :: RemoteEvent
local partyUpdatedEvent = networkFolder:WaitForChild("PartyUpdated") :: RemoteEvent
local partyInviteReceivedEvent = networkFolder:WaitForChild("PartyInviteReceived") :: RemoteEvent
local dungeonActionEvent = networkFolder:WaitForChild("DungeonAction") :: RemoteEvent
local dungeonStateUpdatedEvent = networkFolder:WaitForChild("DungeonStateUpdated") :: RemoteEvent
local dungeonResultsEvent = networkFolder:WaitForChild("DungeonResults") :: RemoteEvent
local bossStateUpdatedEvent = networkFolder:WaitForChild("BossStateUpdated") :: RemoteEvent
local worldEventUpdatedEvent = networkFolder:WaitForChild("WorldEventUpdated") :: RemoteEvent
local achievementUnlockedEvent = networkFolder:WaitForChild("AchievementUnlocked") :: RemoteEvent

-- Master ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MultiplayerSystemsGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- =============================================================================
-- 1. PARTY UI (TOP-LEFT)
-- =============================================================================

local partyFrame = Instance.new("Frame")
partyFrame.Name = "PartyContainer"
partyFrame.Size = UDim2.new(0, 200, 0, 190)
partyFrame.Position = UDim2.new(0, 16, 0, 50)
partyFrame.BackgroundColor3 = Color3.fromRGB(16, 22, 34)
partyFrame.BorderSizePixel = 0
partyFrame.Parent = screenGui

local pfCorner = Instance.new("UICorner")
pfCorner.CornerRadius = UDim.new(0, 8)
pfCorner.Parent = partyFrame

local pfStroke = Instance.new("UIStroke")
pfStroke.Color = Color3.fromRGB(50, 130, 220)
pfStroke.Thickness = 1.2
pfStroke.Parent = partyFrame

local pfHeader = Instance.new("TextLabel")
pfHeader.Size = UDim2.new(1, -50, 0, 28)
pfHeader.Position = UDim2.new(0, 10, 0, 2)
pfHeader.BackgroundTransparency = 1
pfHeader.Text = "PARTY (1/4)"
pfHeader.TextColor3 = Color3.fromRGB(240, 245, 255)
pfHeader.Font = Enum.Font.GothamBold
pfHeader.TextSize = 12
pfHeader.TextXAlignment = Enum.TextXAlignment.Left
pfHeader.Parent = partyFrame

local inviteOpenBtn = Instance.new("TextButton")
inviteOpenBtn.Size = UDim2.new(0, 24, 0, 22)
inviteOpenBtn.Position = UDim2.new(1, -54, 0, 4)
inviteOpenBtn.BackgroundColor3 = Color3.fromRGB(40, 120, 200)
inviteOpenBtn.Text = "+"
inviteOpenBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
inviteOpenBtn.Font = Enum.Font.GothamBlack
inviteOpenBtn.TextSize = 14
inviteOpenBtn.Parent = partyFrame
local ioCorner = Instance.new("UICorner")
ioCorner.CornerRadius = UDim.new(0, 4)
ioCorner.Parent = inviteOpenBtn

local leaveBtn = Instance.new("TextButton")
leaveBtn.Size = UDim2.new(0, 24, 0, 22)
leaveBtn.Position = UDim2.new(1, -28, 0, 4)
leaveBtn.BackgroundColor3 = Color3.fromRGB(160, 40, 40)
leaveBtn.Text = "X"
leaveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
leaveBtn.Font = Enum.Font.GothamBold
leaveBtn.TextSize = 11
leaveBtn.Parent = partyFrame
local lbCorner = Instance.new("UICorner")
lbCorner.CornerRadius = UDim.new(0, 4)
lbCorner.Parent = leaveBtn

leaveBtn.MouseButton1Click:Connect(function()
    partyActionEvent:FireServer("Leave")
end)

local partyMembersList = Instance.new("Frame")
partyMembersList.Size = UDim2.new(1, -12, 1, -36)
partyMembersList.Position = UDim2.new(0, 6, 0, 32)
partyMembersList.BackgroundTransparency = 1
partyMembersList.Parent = partyFrame

local pListLayout = Instance.new("UIListLayout")
pListLayout.Padding = UDim.new(0, 4)
pListLayout.Parent = partyMembersList

-- Quick Invite Prompt Modal
local inviteModal = Instance.new("Frame")
inviteModal.Name = "InviteModal"
inviteModal.Size = UDim2.new(0, 220, 0, 90)
inviteModal.Position = UDim2.new(0, 225, 0, 50)
inviteModal.BackgroundColor3 = Color3.fromRGB(18, 24, 38)
inviteModal.BorderSizePixel = 0
inviteModal.Visible = false
inviteModal.Parent = screenGui

local imCorner = Instance.new("UICorner")
imCorner.CornerRadius = UDim.new(0, 6)
imCorner.Parent = inviteModal

local imStroke = Instance.new("UIStroke")
imStroke.Color = Color3.fromRGB(65, 215, 255)
imStroke.Thickness = 1.2
imStroke.Parent = inviteModal

local imBox = Instance.new("TextBox")
imBox.Size = UDim2.new(1, -20, 0, 28)
imBox.Position = UDim2.new(0, 10, 0, 12)
imBox.BackgroundColor3 = Color3.fromRGB(10, 14, 22)
imBox.Text = ""
imBox.PlaceholderText = "Enter Username to invite..."
imBox.TextColor3 = Color3.fromRGB(255, 255, 255)
imBox.Font = Enum.Font.Gotham
imBox.TextSize = 11
imBox.Parent = inviteModal
local imbCorner = Instance.new("UICorner")
imbCorner.CornerRadius = UDim.new(0, 4)
imbCorner.Parent = imBox

local imSendBtn = Instance.new("TextButton")
imSendBtn.Size = UDim2.new(1, -20, 0, 26)
imSendBtn.Position = UDim2.new(0, 10, 0, 48)
imSendBtn.BackgroundColor3 = Color3.fromRGB(40, 140, 90)
imSendBtn.Text = "Send Invitation"
imSendBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
imSendBtn.Font = Enum.Font.GothamBold
imSendBtn.TextSize = 11
imSendBtn.Parent = inviteModal
local imsCorner = Instance.new("UICorner")
imsCorner.CornerRadius = UDim.new(0, 4)
imsCorner.Parent = imSendBtn

inviteOpenBtn.MouseButton1Click:Connect(function()
    inviteModal.Visible = not inviteModal.Visible
end)

imSendBtn.MouseButton1Click:Connect(function()
    local target = imBox.Text
    if target and target ~= "" then
        partyActionEvent:FireServer("Invite", target)
        imBox.Text = ""
        inviteModal.Visible = false
    end
end)

-- Invite Received Banner Modal
local inviteReceivedModal = Instance.new("Frame")
inviteReceivedModal.Name = "InviteReceivedModal"
inviteReceivedModal.Size = UDim2.new(0, 260, 0, 80)
inviteReceivedModal.Position = UDim2.new(0.5, -130, 0.15, 0)
inviteReceivedModal.BackgroundColor3 = Color3.fromRGB(20, 26, 42)
inviteReceivedModal.BorderSizePixel = 0
inviteReceivedModal.Visible = false
inviteReceivedModal.Parent = screenGui

local irCorner = Instance.new("UICorner")
irCorner.CornerRadius = UDim.new(0, 8)
irCorner.Parent = inviteReceivedModal

local irStroke = Instance.new("UIStroke")
irStroke.Color = Color3.fromRGB(255, 215, 60)
irStroke.Thickness = 1.5
irStroke.Parent = inviteReceivedModal

local irText = Instance.new("TextLabel")
irText.Size = UDim2.new(1, -16, 0, 36)
irText.Position = UDim2.new(0, 8, 0, 4)
irText.BackgroundTransparency = 1
irText.Text = "Party Invitation from ..."
irText.TextColor3 = Color3.fromRGB(240, 245, 255)
irText.Font = Enum.Font.GothamBold
irText.TextSize = 11
irText.Parent = inviteReceivedModal

local irAcceptBtn = Instance.new("TextButton")
irAcceptBtn.Size = UDim2.new(0.46, 0, 0, 26)
irAcceptBtn.Position = UDim2.new(0, 8, 1, -32)
irAcceptBtn.BackgroundColor3 = Color3.fromRGB(40, 140, 80)
irAcceptBtn.Text = "Accept"
irAcceptBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
irAcceptBtn.Font = Enum.Font.GothamBold
irAcceptBtn.TextSize = 11
irAcceptBtn.Parent = inviteReceivedModal
local iraCorner = Instance.new("UICorner")
iraCorner.CornerRadius = UDim.new(0, 4)
iraCorner.Parent = irAcceptBtn

local irDeclineBtn = Instance.new("TextButton")
irDeclineBtn.Size = UDim2.new(0.46, 0, 0, 26)
irDeclineBtn.Position = UDim2.new(0.54, 0, 1, -32)
irDeclineBtn.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
irDeclineBtn.Text = "Decline"
irDeclineBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
irDeclineBtn.Font = Enum.Font.GothamBold
irDeclineBtn.TextSize = 11
irDeclineBtn.Parent = inviteReceivedModal
local irdCorner = Instance.new("UICorner")
irdCorner.CornerRadius = UDim.new(0, 4)
irdCorner.Parent = irDeclineBtn

local pendingPartyIdToJoin: string? = nil

partyInviteReceivedEvent.OnClientEvent:Connect(function(partyId: string, inviterName: string)
    pendingPartyIdToJoin = partyId
    irText.Text = string.format("%s invited you to join their Party!", inviterName)
    inviteReceivedModal.Visible = true
end)

irAcceptBtn.MouseButton1Click:Connect(function()
    if pendingPartyIdToJoin then
        partyActionEvent:FireServer("Accept", pendingPartyIdToJoin)
    end
    inviteReceivedModal.Visible = false
end)

irDeclineBtn.MouseButton1Click:Connect(function()
    if pendingPartyIdToJoin then
        partyActionEvent:FireServer("Decline", pendingPartyIdToJoin)
    end
    inviteReceivedModal.Visible = false
end)

partyUpdatedEvent.OnClientEvent:Connect(function(party: any)
    for _, child in ipairs(partyMembersList:GetChildren()) do
        if child:IsA("GuiObject") and child ~= pListLayout then
            child:Destroy()
        end
    end

    if not party or not party.members then
        pfHeader.Text = "SOLO CHAMPION"
        return
    end

    local count = 0
    for _, member in pairs(party.members) do
        count += 1
        local mRow = Instance.new("Frame")
        mRow.Size = UDim2.new(1, 0, 0, 32)
        mRow.BackgroundColor3 = Color3.fromRGB(24, 32, 48)
        mRow.BorderSizePixel = 0
        mRow.Parent = partyMembersList

        local mrCorner = Instance.new("UICorner")
        mrCorner.CornerRadius = UDim.new(0, 4)
        mrCorner.Parent = mRow

        local mName = Instance.new("TextLabel")
        mName.Size = UDim2.new(0.65, 0, 0, 16)
        mName.Position = UDim2.new(0, 6, 0, 2)
        mName.BackgroundTransparency = 1
        local leaderBadge = if member.isLeader then "👑 " else ""
        mName.Text = string.format("%s%s [Lv.%d]", leaderBadge, member.name, member.level or 1)
        mName.TextColor3 = if member.isLeader then Color3.fromRGB(255, 220, 60) else Color3.fromRGB(240, 240, 255)
        mName.Font = Enum.Font.GothamBold
        mName.TextSize = 10
        mName.TextXAlignment = Enum.TextXAlignment.Left
        mName.Parent = mRow

        -- Health bar
        local hpBg = Instance.new("Frame")
        hpBg.Size = UDim2.new(1, -12, 0, 6)
        hpBg.Position = UDim2.new(0, 6, 0, 20)
        hpBg.BackgroundColor3 = Color3.fromRGB(15, 18, 25)
        hpBg.BorderSizePixel = 0
        hpBg.Parent = mRow

        local hpFill = Instance.new("Frame")
        local hpRatio = math.clamp((member.health or 200) / (member.maxHealth or 200), 0, 1)
        hpFill.Size = UDim2.new(hpRatio, 0, 1, 0)
        hpFill.BackgroundColor3 = if member.isDowned then Color3.fromRGB(255, 40, 40) else Color3.fromRGB(65, 215, 255)
        hpFill.BorderSizePixel = 0
        hpFill.Parent = hpBg
    end

    pfHeader.Text = string.format("PARTY (%d/4)", count)
end)

-- =============================================================================
-- 2. BOSS HEALTH BAR (TOP-CENTER)
-- =============================================================================

local bossBarContainer = Instance.new("Frame")
bossBarContainer.Name = "BossBarContainer"
bossBarContainer.Size = UDim2.new(0, 520, 0, 75)
bossBarContainer.Position = UDim2.new(0.5, -260, 0, 18)
bossBarContainer.BackgroundColor3 = Color3.fromRGB(16, 20, 32)
bossBarContainer.BorderSizePixel = 0
bossBarContainer.Visible = false
bossBarContainer.Parent = screenGui

local bbCorner = Instance.new("UICorner")
bbCorner.CornerRadius = UDim.new(0, 8)
bbCorner.Parent = bossBarContainer

local bbStroke = Instance.new("UIStroke")
bbStroke.Color = Color3.fromRGB(255, 65, 65)
bbStroke.Thickness = 2
bbStroke.Parent = bossBarContainer

local bossNameLabel = Instance.new("TextLabel")
bossNameLabel.Size = UDim2.new(1, 0, 0, 22)
bossNameLabel.Position = UDim2.new(0, 0, 0, 4)
bossNameLabel.BackgroundTransparency = 1
bossNameLabel.Text = "STORM TITAN  [Phase I]"
bossNameLabel.TextColor3 = Color3.fromRGB(255, 220, 60)
bossNameLabel.Font = Enum.Font.GothamBlack
bossNameLabel.TextSize = 15
bossNameLabel.Parent = bossBarContainer

local bossTitleLabel = Instance.new("TextLabel")
bossTitleLabel.Size = UDim2.new(1, 0, 0, 14)
bossTitleLabel.Position = UDim2.new(0, 0, 0, 24)
bossTitleLabel.BackgroundTransparency = 1
bossTitleLabel.Text = "The Tempest Colossus"
bossTitleLabel.TextColor3 = Color3.fromRGB(170, 200, 235)
bossTitleLabel.Font = Enum.Font.Gotham
bossTitleLabel.TextSize = 10
bossTitleLabel.Parent = bossBarContainer

local bossHpBg = Instance.new("Frame")
bossHpBg.Size = UDim2.new(1, -24, 0, 14)
bossHpBg.Position = UDim2.new(0, 12, 0, 42)
bossHpBg.BackgroundColor3 = Color3.fromRGB(25, 28, 40)
bossHpBg.BorderSizePixel = 0
bossHpBg.Parent = bossBarContainer

local bossHpFill = Instance.new("Frame")
bossHpFill.Size = UDim2.new(1, 0, 1, 0)
bossHpFill.BackgroundColor3 = Color3.fromRGB(255, 55, 55)
bossHpFill.BorderSizePixel = 0
bossHpFill.Parent = bossHpBg

local bossHpText = Instance.new("TextLabel")
bossHpText.Size = UDim2.new(1, 0, 1, 0)
bossHpText.BackgroundTransparency = 1
bossHpText.Text = "5000 / 5000 HP"
bossHpText.TextColor3 = Color3.fromRGB(255, 255, 255)
bossHpText.Font = Enum.Font.GothamBold
bossHpText.TextSize = 10
bossHpText.Parent = bossHpBg

local enrageBadge = Instance.new("TextLabel")
enrageBadge.Size = UDim2.new(0, 100, 0, 14)
enrageBadge.Position = UDim2.new(1, -112, 0, 58)
enrageBadge.BackgroundTransparency = 1
enrageBadge.Text = ""
enrageBadge.TextColor3 = Color3.fromRGB(255, 80, 80)
enrageBadge.Font = Enum.Font.GothamBold
enrageBadge.TextSize = 9
enrageBadge.Parent = bossBarContainer

bossStateUpdatedEvent.OnClientEvent:Connect(function(state: any)
    if not state or not state.name then
        bossBarContainer.Visible = false
        return
    end

    bossBarContainer.Visible = true
    local phaseRoman = if state.phase == 3 then "III" elseif state.phase == 2 then "II" else "I"
    bossNameLabel.Text = string.format("%s  [Phase %s]", state.name, phaseRoman)
    bossTitleLabel.Text = state.title or "Boss"

    local cur = state.currentHealth or 0
    local max = state.maxHealth or 5000
    local ratio = math.clamp(cur / max, 0, 1)

    bossHpText.Text = string.format("%d / %d HP", cur, max)
    TweenService:Create(bossHpFill, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.new(ratio, 0, 1, 0)
    }):Play()

    if state.isEnraged then
        bossHpFill.BackgroundColor3 = Color3.fromRGB(255, 20, 20)
        enrageBadge.Text = string.format("ENRAGE: %ds", state.enrageTimeRemaining or 0)
    else
        bossHpFill.BackgroundColor3 = Color3.fromRGB(255, 65, 65)
        enrageBadge.Text = ""
    end
end)

-- =============================================================================
-- 3. DUNGEON OBJECTIVES & TIMER HUD (TOP-RIGHT)
-- =============================================================================

local dungeonHud = Instance.new("Frame")
dungeonHud.Name = "DungeonHUD"
dungeonHud.Size = UDim2.new(0, 260, 0, 140)
dungeonHud.Position = UDim2.new(1, -276, 0, 50)
dungeonHud.BackgroundColor3 = Color3.fromRGB(16, 20, 32)
dungeonHud.BorderSizePixel = 0
dungeonHud.Visible = false
dungeonHud.Parent = screenGui

local dhCorner = Instance.new("UICorner")
dhCorner.CornerRadius = UDim.new(0, 8)
dhCorner.Parent = dungeonHud

local dhStroke = Instance.new("UIStroke")
dhStroke.Color = Color3.fromRGB(255, 215, 60)
dhStroke.Thickness = 1.2
dhStroke.Parent = dungeonHud

local dhTitle = Instance.new("TextLabel")
dhTitle.Size = UDim2.new(1, -16, 0, 24)
dhTitle.Position = UDim2.new(0, 8, 0, 4)
dhTitle.BackgroundTransparency = 1
dhTitle.Text = "TEMPLE OF STORMS"
dhTitle.TextColor3 = Color3.fromRGB(255, 220, 60)
dhTitle.Font = Enum.Font.GothamBold
dhTitle.TextSize = 12
dhTitle.TextXAlignment = Enum.TextXAlignment.Left
dhTitle.Parent = dungeonHud

local dhTimer = Instance.new("TextLabel")
dhTimer.Size = UDim2.new(0, 80, 0, 24)
dhTimer.Position = UDim2.new(1, -88, 0, 4)
dhTimer.BackgroundTransparency = 1
dhTimer.Text = "10:00"
dhTimer.TextColor3 = Color3.fromRGB(65, 225, 255)
dhTimer.Font = Enum.Font.GothamBlack
dhTimer.TextSize = 13
dhTimer.TextXAlignment = Enum.TextXAlignment.Right
dhTimer.Parent = dungeonHud

local dhLives = Instance.new("TextLabel")
dhLives.Size = UDim2.new(1, -16, 0, 16)
dhLives.Position = UDim2.new(0, 8, 0, 26)
dhLives.BackgroundTransparency = 1
dhLives.Text = "Team Lives: ❤❤❤❤❤"
dhLives.TextColor3 = Color3.fromRGB(255, 80, 80)
dhLives.Font = Enum.Font.GothamBold
dhLives.TextSize = 10
dhLives.TextXAlignment = Enum.TextXAlignment.Left
dhLives.Parent = dungeonHud

local dhObjectivesList = Instance.new("Frame")
dhObjectivesList.Size = UDim2.new(1, -16, 1, -50)
dhObjectivesList.Position = UDim2.new(0, 8, 0, 46)
dhObjectivesList.BackgroundTransparency = 1
dhObjectivesList.Parent = dungeonHud

local dhoLayout = Instance.new("UIListLayout")
dhoLayout.Padding = UDim.new(0, 3)
dhoLayout.Parent = dhObjectivesList

dungeonStateUpdatedEvent.OnClientEvent:Connect(function(state: any)
    if not state or state.status ~= "Active" then
        dungeonHud.Visible = false
        return
    end

    dungeonHud.Visible = true
    dhTitle.Text = string.format("%s [%s]", state.name, state.difficulty)

    local mins = math.floor(state.timeRemaining / 60)
    local secs = state.timeRemaining % 60
    dhTimer.Text = string.format("%02d:%02d", mins, secs)

    local hearts = string.rep("❤", state.livesRemaining or 5)
    dhLives.Text = "Team Lives: " .. hearts

    for _, child in ipairs(dhObjectivesList:GetChildren()) do
        if child:IsA("GuiObject") and child ~= dhoLayout then
            child:Destroy()
        end
    end

    for _, obj in ipairs(state.objectives or {}) do
        local oLabel = Instance.new("TextLabel")
        oLabel.Size = UDim2.new(1, 0, 0, 18)
        oLabel.BackgroundTransparency = 1
        local check = if obj.isCompleted then "✓ " else "• "
        oLabel.Text = string.format("%s%s (%d/%d)", check, obj.description, obj.currentCount, obj.targetCount)
        oLabel.TextColor3 = if obj.isCompleted then Color3.fromRGB(80, 255, 120) else Color3.fromRGB(200, 215, 235)
        oLabel.Font = Enum.Font.Gotham
        oLabel.TextSize = 10
        oLabel.TextXAlignment = Enum.TextXAlignment.Left
        oLabel.Parent = dhObjectivesList
    end
end)

-- =============================================================================
-- 4. DUNGEON RESULTS SCREEN
-- =============================================================================

local resultsModal = Instance.new("Frame")
resultsModal.Name = "DungeonResultsModal"
resultsModal.Size = UDim2.new(0, 420, 0, 320)
resultsModal.Position = UDim2.new(0.5, -210, 0.5, -160)
resultsModal.BackgroundColor3 = Color3.fromRGB(18, 24, 38)
resultsModal.BorderSizePixel = 0
resultsModal.Visible = false
resultsModal.Parent = screenGui

local rmCorner = Instance.new("UICorner")
rmCorner.CornerRadius = UDim.new(0, 10)
rmCorner.Parent = resultsModal

local rmStroke = Instance.new("UIStroke")
rmStroke.Color = Color3.fromRGB(255, 215, 60)
rmStroke.Thickness = 2
rmStroke.Parent = resultsModal

local rmTitle = Instance.new("TextLabel")
rmTitle.Size = UDim2.new(1, 0, 0, 44)
rmTitle.BackgroundTransparency = 1
rmTitle.Text = "★ DUNGEON VICTORY! ★"
rmTitle.TextColor3 = Color3.fromRGB(255, 220, 60)
rmTitle.Font = Enum.Font.GothamBlack
rmTitle.TextSize = 20
rmTitle.Parent = resultsModal

local rmSubtitle = Instance.new("TextLabel")
rmSubtitle.Size = UDim2.new(1, -30, 0, 20)
rmSubtitle.Position = UDim2.new(0, 15, 0, 44)
rmSubtitle.BackgroundTransparency = 1
rmSubtitle.Text = "Cleared in 04:32"
rmSubtitle.TextColor3 = Color3.fromRGB(65, 225, 255)
rmSubtitle.Font = Enum.Font.GothamBold
rmSubtitle.TextSize = 12
rmSubtitle.Parent = resultsModal

local rmRewardsList = Instance.new("Frame")
rmRewardsList.Size = UDim2.new(1, -30, 0, 180)
rmRewardsList.Position = UDim2.new(0, 15, 0, 72)
rmRewardsList.BackgroundColor3 = Color3.fromRGB(12, 16, 26)
rmRewardsList.BorderSizePixel = 0
rmRewardsList.Parent = resultsModal

local rmrCorner = Instance.new("UICorner")
rmrCorner.CornerRadius = UDim.new(0, 6)
rmrCorner.Parent = rmRewardsList

local rmRewardsText = Instance.new("TextLabel")
rmRewardsText.Size = UDim2.new(1, -20, 1, -20)
rmRewardsText.Position = UDim2.new(0, 10, 0, 10)
rmRewardsText.BackgroundTransparency = 1
rmRewardsText.Text = ""
rmRewardsText.TextColor3 = Color3.fromRGB(230, 240, 255)
rmRewardsText.Font = Enum.Font.GothamMedium
rmRewardsText.TextSize = 12
rmRewardsText.TextXAlignment = Enum.TextXAlignment.Left
rmRewardsText.TextYAlignment = Enum.TextYAlignment.Top
rmRewardsText.Parent = rmRewardsList

local rmCloseBtn = Instance.new("TextButton")
rmCloseBtn.Size = UDim2.new(0, 160, 0, 32)
rmCloseBtn.Position = UDim2.new(0.5, -80, 1, -42)
rmCloseBtn.BackgroundColor3 = Color3.fromRGB(40, 140, 80)
rmCloseBtn.Text = "Claim & Return"
rmCloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
rmCloseBtn.Font = Enum.Font.GothamBold
rmCloseBtn.TextSize = 12
rmCloseBtn.Parent = resultsModal

local rmcCorner = Instance.new("UICorner")
rmcCorner.CornerRadius = UDim.new(0, 6)
rmcCorner.Parent = rmCloseBtn

rmCloseBtn.MouseButton1Click:Connect(function()
    resultsModal.Visible = false
    dungeonActionEvent:FireServer("Leave")
end)

dungeonResultsEvent.OnClientEvent:Connect(function(res: any)
    if not res then return end

    if res.victory then
        rmTitle.Text = "★ DUNGEON VICTORY! ★"
        rmTitle.TextColor3 = Color3.fromRGB(255, 220, 60)
        rmStroke.Color = Color3.fromRGB(255, 215, 60)
        rmSubtitle.Text = string.format("Temple Cleared in %ds!", res.timeElapsed or 0)

        local lines = {
            string.format("• Experience: +%d XP", res.xpGained or 2500),
            string.format("• Gold: +%d Gold", res.goldGained or 1000),
            "• Equipment: Stormforged Cuirass [Epic]",
            "• Materials: 3x Pulsing Storm Core, 1x Ancient Relic Fragment",
            string.format("• Title Unlocked: [%s]", res.titleUnlocked or "Conqueror of the Tempest"),
        }
        rmRewardsText.Text = table.concat(lines, "\n\n")
    else
        rmTitle.Text = "DUNGEON DEFEAT"
        rmTitle.TextColor3 = Color3.fromRGB(255, 60, 60)
        rmStroke.Color = Color3.fromRGB(255, 60, 60)
        rmSubtitle.Text = "Your party fell to the Storm Temple."
        rmRewardsText.Text = "Regroup at the Sanctuary and try again with stronger gear."
    end

    resultsModal.Visible = true
end)

-- =============================================================================
-- 5. WORLD EVENT MARQUEE BANNER (TOP)
-- =============================================================================

local marqueeBanner = Instance.new("Frame")
marqueeBanner.Name = "WorldEventMarquee"
marqueeBanner.Size = UDim2.new(0, 480, 0, 36)
marqueeBanner.Position = UDim2.new(0.5, -240, 0, 6)
marqueeBanner.BackgroundColor3 = Color3.fromRGB(20, 24, 38)
marqueeBanner.BorderSizePixel = 0
marqueeBanner.Visible = false
marqueeBanner.Parent = screenGui

local mbCorner = Instance.new("UICorner")
mbCorner.CornerRadius = UDim.new(0, 6)
mbCorner.Parent = marqueeBanner

local mbStroke = Instance.new("UIStroke")
mbStroke.Color = Color3.fromRGB(65, 225, 255)
mbStroke.Thickness = 1.2
mbStroke.Parent = marqueeBanner

local mbText = Instance.new("TextLabel")
mbText.Size = UDim2.new(1, 0, 1, 0)
mbText.BackgroundTransparency = 1
mbText.Text = "⚡ WORLD EVENT: METEOR SHOWER (02:45)"
mbText.TextColor3 = Color3.fromRGB(255, 220, 60)
mbText.Font = Enum.Font.GothamBold
mbText.TextSize = 12
mbText.Parent = marqueeBanner

worldEventUpdatedEvent.OnClientEvent:Connect(function(eventState: any)
    if not eventState or not eventState.isActive then
        marqueeBanner.Visible = false
        return
    end

    marqueeBanner.Visible = true
    local mins = math.floor(eventState.durationRemaining / 60)
    local secs = eventState.durationRemaining % 60
    mbText.Text = string.format("⚡ %s (%02d:%02d REMAINING)", eventState.title, mins, secs)
end)

-- =============================================================================
-- 6. ACHIEVEMENT UNLOCK BANNER
-- =============================================================================

local achBanner = Instance.new("Frame")
achBanner.Name = "AchievementBanner"
achBanner.Size = UDim2.new(0, 360, 0, 70)
achBanner.Position = UDim2.new(0.5, -180, 0.12, 0)
achBanner.BackgroundColor3 = Color3.fromRGB(18, 24, 38)
achBanner.BorderSizePixel = 0
achBanner.Visible = false
achBanner.Parent = screenGui

local abCorner = Instance.new("UICorner")
abCorner.CornerRadius = UDim.new(0, 8)
abCorner.Parent = achBanner

local abStroke = Instance.new("UIStroke")
abStroke.Color = Color3.fromRGB(255, 215, 60)
abStroke.Thickness = 1.8
abStroke.Parent = achBanner

local abHeader = Instance.new("TextLabel")
abHeader.Size = UDim2.new(1, 0, 0, 22)
abHeader.Position = UDim2.new(0, 0, 0, 6)
abHeader.BackgroundTransparency = 1
abHeader.Text = "🏆 ACHIEVEMENT UNLOCKED!"
abHeader.TextColor3 = Color3.fromRGB(255, 220, 60)
abHeader.Font = Enum.Font.GothamBlack
abHeader.TextSize = 13
abHeader.Parent = achBanner

local abTitle = Instance.new("TextLabel")
abTitle.Size = UDim2.new(1, 0, 0, 18)
abTitle.Position = UDim2.new(0, 0, 0, 26)
abTitle.BackgroundTransparency = 1
abTitle.Text = "Titan Slayer"
abTitle.TextColor3 = Color3.fromRGB(65, 225, 255)
abTitle.Font = Enum.Font.GothamBold
abTitle.TextSize = 12
abTitle.Parent = achBanner

local abDesc = Instance.new("TextLabel")
abDesc.Size = UDim2.new(1, -20, 0, 18)
abDesc.Position = UDim2.new(0, 10, 0, 44)
abDesc.BackgroundTransparency = 1
abDesc.Text = "+1,000 XP | +500 Gold"
abDesc.TextColor3 = Color3.fromRGB(180, 215, 245)
abDesc.Font = Enum.Font.Gotham
abDesc.TextSize = 10
abDesc.Parent = achBanner

achievementUnlockedEvent.OnClientEvent:Connect(function(def: any)
    if not def then return end

    abTitle.Text = def.title or "Achievement"
    abDesc.Text = string.format("+%d XP  |  +%d Gold  %s", def.xpReward or 0, def.goldReward or 0,
        if def.titleReward then string.format(" | Title: [%s]", def.titleReward) else "")

    achBanner.Visible = true
    achBanner.Position = UDim2.new(0.5, -180, 0.08, 0)
    achBanner.BackgroundTransparency = 0.5

    TweenService:Create(achBanner, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -180, 0.12, 0),
        BackgroundTransparency = 0,
    }):Play()

    task.delay(3.2, function()
        local out = TweenService:Create(achBanner, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(0.5, -180, 0.08, 0),
            BackgroundTransparency = 1,
        })
        out:Play()
        out.Completed:Connect(function()
            achBanner.Visible = false
        end)
    end)
end)

print("[MultiplayerUIController] Initialized: Party UI, Boss Health Bar, Dungeon Tracker, Results, and Event Marquee.")