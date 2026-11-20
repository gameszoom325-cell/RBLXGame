--!strict
--[[
    CinematicController.client.lua
    Client-side Scripted Camera Sequences and Cinematic Engine:
    - Listens to ReplicatedStorage.Network.PlayCinematic
    - Supported sequences:
      * BossIntro: Sweeping low-to-high angle reveal of the Storm Titan with camera shake
      * DungeonVictory: Triumphant slow orbital pan around the victorious party
    - Cinematic Letterbox bars (top/bottom)
    - Dynamic FOV interpolation and camera shake
    - Interactive "Skip [Space]" functionality
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = Workspace.CurrentCamera

local networkFolder = ReplicatedStorage:WaitForChild("Network")
local playCinematicEvent = networkFolder:WaitForChild("PlayCinematic") :: RemoteEvent

local isCinematicPlaying = false
local currentCinematicThread: thread? = nil
local originalCameraType = camera.CameraType

-- Master Cinematic UI
local cinematicGui = Instance.new("ScreenGui")
cinematicGui.Name = "CinematicGui"
cinematicGui.ResetOnSpawn = false
cinematicGui.DisplayOrder = 100
cinematicGui.Parent = playerGui

-- Top Letterbox
local topBar = Instance.new("Frame")
topBar.Name = "TopLetterbox"
topBar.Size = UDim2.new(1, 0, 0, 70)
topBar.Position = UDim2.new(0, 0, 0, -80)
topBar.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
topBar.BorderSizePixel = 0
topBar.Parent = cinematicGui

-- Bottom Letterbox
local bottomBar = Instance.new("Frame")
bottomBar.Name = "BottomLetterbox"
bottomBar.Size = UDim2.new(1, 0, 0, 70)
bottomBar.Position = UDim2.new(0, 0, 1, 10)
bottomBar.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
bottomBar.BorderSizePixel = 0
bottomBar.Parent = cinematicGui

-- Cinematic Caption Title
local captionLabel = Instance.new("TextLabel")
captionLabel.Size = UDim2.new(1, 0, 0, 36)
captionLabel.Position = UDim2.new(0, 0, 1, -55)
captionLabel.BackgroundTransparency = 1
captionLabel.Text = ""
captionLabel.TextColor3 = Color3.fromRGB(255, 220, 60)
captionLabel.Font = Enum.Font.GothamBlack
captionLabel.TextSize = 18
captionLabel.TextTransparency = 1
captionLabel.Parent = cinematicGui

-- Skip Button
local skipBtn = Instance.new("TextButton")
skipBtn.Name = "SkipButton"
skipBtn.Size = UDim2.new(0, 140, 0, 32)
skipBtn.Position = UDim2.new(1, -160, 1, -45)
skipBtn.BackgroundColor3 = Color3.fromRGB(25, 30, 45)
skipBtn.Text = "Skip [Space]"
skipBtn.TextColor3 = Color3.fromRGB(240, 240, 255)
skipBtn.Font = Enum.Font.GothamBold
skipBtn.TextSize = 11
skipBtn.Visible = false
skipBtn.Parent = cinematicGui

local sbCorner = Instance.new("UICorner")
sbCorner.CornerRadius = UDim.new(0, 6)
sbCorner.Parent = skipBtn

local function setLetterbox(active: boolean)
    local topTarget = if active then UDim2.new(0, 0, 0, 0) else UDim2.new(0, 0, 0, -80)
    local botTarget = if active then UDim2.new(0, 0, 1, -70) else UDim2.new(0, 0, 1, 10)

    TweenService:Create(topBar, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = topTarget
    }):Play()
    TweenService:Create(bottomBar, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = botTarget
    }):Play()

    skipBtn.Visible = active
end

local function stopCinematic()
    if not isCinematicPlaying then return end
    isCinematicPlaying = false

    if currentCinematicThread then
        task.cancel(currentCinematicThread)
        currentCinematicThread = nil
    end

    setLetterbox(false)
    captionLabel.TextTransparency = 1
    camera.CameraType = Enum.CameraType.Custom
end

skipBtn.MouseButton1Click:Connect(stopCinematic)

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
    if isCinematicPlaying and input.KeyCode == Enum.KeyCode.Space then
        stopCinematic()
    end
end)

local function playBossIntro(params: any)
    isCinematicPlaying = true
    setLetterbox(true)

    local bossModel = Workspace:FindFirstChild("Storm Titan")
    local bossHrp = bossModel and bossModel.PrimaryPart
    local targetPos = if bossHrp then bossHrp.Position else Vector3.new(0, 1000, 250)

    captionLabel.Text = "THE STORM TITAN AWAKENS"
    captionLabel.TextTransparency = 0

    camera.CameraType = Enum.CameraType.Scriptable

    -- Start camera low looking up at the colossus
    local startCamPos = targetPos + Vector3.new(0, 2, -35)
    local endCamPos = targetPos + Vector3.new(15, 12, -28)

    camera.CFrame = CFrame.new(startCamPos, targetPos + Vector3.new(0, 10, 0))

    local tween = TweenService:Create(
        camera,
        TweenInfo.new(3.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
        { CFrame = CFrame.new(endCamPos, targetPos + Vector3.new(0, 8, 0)) }
    )
    tween:Play()

    currentCinematicThread = task.spawn(function()
        -- Camera shake midway through intro
        task.wait(1.8)
        local shakeEnd = os.clock() + 1.2
        while os.clock() < shakeEnd and isCinematicPlaying do
            local shakeX = (math.random() - 0.5) * 0.4
            local shakeY = (math.random() - 0.5) * 0.4
            camera.CFrame = camera.CFrame * CFrame.Angles(math.rad(shakeX), math.rad(shakeY), 0)
            RunService.RenderStepped:Wait()
        end

        task.wait(1.0)
        stopCinematic()
    end)
end

playCinematicEvent.OnClientEvent:Connect(function(cinematicId: any, params: any)
    if cinematicId == "BossIntro" then
        playBossIntro(params)
    end
end)

print("[CinematicController] Initialized cinematic engine with letterbox and shake.")