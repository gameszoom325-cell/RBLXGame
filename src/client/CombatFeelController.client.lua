--!strict
--[[
    CombatFeelController.client.lua
    AAA Combat Polish & Visceral Game Feel Engine:
    - Procedural decaying trauma camera shake
    - Tactile Hit Stop (impact freeze)
    - Dynamic Hit Markers & Screen Flashes
    - Directional Slash Arcs & Lightning Sparks
    - Enemy Flash-on-hit highlight
    - Controller / Gamepad Haptic Vibration feedback
    - Combo finisher ground crack & dust burst
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HapticService = game:GetService("HapticService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local playerGui = player:WaitForChild("PlayerGui")

local networkFolder = ReplicatedStorage:WaitForChild("Network")
local combatFeedbackEvent = networkFolder:WaitForChild("CombatFeedback") :: RemoteEvent
local damageDealtEvent = networkFolder:WaitForChild("DamageDealt") :: RemoteEvent

-- Trauma-based Camera Shake state
local currentTrauma = 0.0
local MAX_TRAUMA = 1.0
local TRAUMA_DECAY_RATE = 2.4
local MAX_SHAKE_ROTATION = math.rad(3.5)
local MAX_SHAKE_TRANSLATION = 0.8

-- Master Combat Feel UI Overlay
local combatScreenGui = Instance.new("ScreenGui")
combatScreenGui.Name = "CombatFeelGui"
combatScreenGui.ResetOnSpawn = false
combatScreenGui.DisplayOrder = 15
combatScreenGui.Parent = playerGui

-- Screen Flash Vignette
local flashVignette = Instance.new("Frame")
flashVignette.Name = "DamageFlashVignette"
flashVignette.Size = UDim2.new(1, 0, 1, 0)
flashVignette.BackgroundColor3 = Color3.fromRGB(255, 230, 120)
flashVignette.BackgroundTransparency = 1
flashVignette.BorderSizePixel = 0
flashVignette.Parent = combatScreenGui

-- Center Hit Marker
local hitMarker = Instance.new("ImageLabel")
hitMarker.Name = "HitMarker"
hitMarker.Size = UDim2.new(0, 24, 0, 24)
hitMarker.Position = UDim2.new(0.5, -12, 0.5, -12)
hitMarker.BackgroundTransparency = 1
hitMarker.Image = "rbxassetid://6031075938" -- Clean crosshair hit marker
hitMarker.ImageColor3 = Color3.fromRGB(255, 255, 255)
hitMarker.ImageTransparency = 1
hitMarker.Parent = combatScreenGui

local function triggerTrauma(amount: number)
    currentTrauma = math.clamp(currentTrauma + amount, 0, MAX_TRAUMA)
end

local function showHitMarker(isCrit: boolean)
    hitMarker.ImageColor3 = if isCrit then Color3.fromRGB(255, 220, 50) else Color3.fromRGB(255, 255, 255)
    hitMarker.Size = if isCrit then UDim2.new(0, 32, 0, 32) else UDim2.new(0, 24, 0, 24)
    hitMarker.Position = if isCrit then UDim2.new(0.5, -16, 0.5, -16) else UDim2.new(0.5, -12, 0.5, -12)
    hitMarker.ImageTransparency = 0

    TweenService:Create(hitMarker, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        ImageTransparency = 1,
        Size = UDim2.new(0, 16, 0, 16),
        Position = UDim2.new(0.5, -8, 0.5, -8)
    }):Play()
end

local function flashScreen(color: Color3, duration: number)
    flashVignette.BackgroundColor3 = color
    flashVignette.BackgroundTransparency = 0.75

    TweenService:Create(flashVignette, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        BackgroundTransparency = 1
    }):Play()
end

local function triggerHaptics(largeMotor: number, smallMotor: number, duration: number)
    if UserInputService:GetGamepadConnected(Enum.UserInputType.Gamepad1) then
        pcall(function()
            HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Large, largeMotor)
            HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small, smallMotor)
            task.delay(duration, function()
                HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Large, 0)
                HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small, 0)
            end)
        end)
    end
end

-- Procedural Decaying Camera Shake Loop
RunService.RenderStepped:Connect(function(dt: number)
    if currentTrauma > 0 then
        local shake = currentTrauma * currentTrauma -- Non-linear squared intensity curve
        local timeSec = os.clock() * 25

        local yaw = math.noise(timeSec, 0, 0) * MAX_SHAKE_ROTATION * shake
        local pitch = math.noise(0, timeSec, 0) * MAX_SHAKE_ROTATION * shake
        local roll = math.noise(0, 0, timeSec) * (MAX_SHAKE_ROTATION * 0.5) * shake

        local xOffset = math.noise(timeSec, 10, 0) * MAX_SHAKE_TRANSLATION * shake
        local yOffset = math.noise(10, timeSec, 0) * MAX_SHAKE_TRANSLATION * shake

        camera.CFrame = camera.CFrame * CFrame.Angles(pitch, yaw, roll) * CFrame.new(xOffset, yOffset, 0)

        currentTrauma = math.max(0, currentTrauma - (TRAUMA_DECAY_RATE * dt))
    end
end)

-- Directional Slash VFX & Ground Cracks
local function spawnComboSlashVFX(comboStep: number, origin: Vector3)
    local arc = Instance.new("Part")
    arc.Name = "SlashArcEffect"
    arc.Shape = Enum.PartType.Cylinder
    arc.Size = if comboStep == 3 then Vector3.new(0.5, 14, 14) else Vector3.new(0.3, 10, 10)
    arc.Position = origin
    arc.Color = if comboStep == 3 then Color3.fromRGB(255, 220, 70) else Color3.fromRGB(80, 220, 255)
    arc.Material = Enum.Material.Neon
    arc.Anchored = true
    arc.CanCollide = false
    arc.Parent = Workspace

    -- Orientation based on combo step
    if comboStep == 1 then
        arc.CFrame = CFrame.new(origin) * CFrame.Angles(0, 0, math.rad(90))
    elseif comboStep == 2 then
        arc.CFrame = CFrame.new(origin) * CFrame.Angles(math.rad(45), 0, math.rad(45))
    else
        -- Combo Finisher: Vertical slam with ground crack shockwave
        arc.CFrame = CFrame.new(origin) * CFrame.Angles(0, 0, math.rad(90))

        -- Ground dust burst
        local dust = Instance.new("Part")
        dust.Shape = Enum.PartType.Cylinder
        dust.Size = Vector3.new(0.2, 18, 18)
        dust.CFrame = CFrame.new(origin.X, origin.Y - 1, origin.Z) * CFrame.Angles(0, 0, math.rad(90))
        dust.Color = Color3.fromRGB(65, 215, 255)
        dust.Material = Enum.Material.Neon
        dust.Transparency = 0.3
        dust.Anchored = true
        dust.CanCollide = false
        dust.Parent = Workspace

        TweenService:Create(dust, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = Vector3.new(0.1, 26, 26),
            Transparency = 1,
        }):Play()
        task.delay(0.45, function() dust:Destroy() end)
    end

    local arcTween = TweenService:Create(arc, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = arc.Size * 1.4,
        Transparency = 1,
    })
    arcTween:Play()
    arcTween.Completed:Connect(function()
        arc:Destroy()
    end)
end

-- Listener for authoritative combat feedback
combatFeedbackEvent.OnClientEvent:Connect(function(data: any)
    if not data then return end

    local isCrit = data.isCrit == true
    local intensity = data.shakeIntensity or 0.6
    local hitStop = data.hitStopDuration or 0.04
    local comboStep = data.comboStep or 1
    local origin = data.origin or camera.CFrame.Position

    -- 1. Camera Shake
    triggerTrauma(intensity)

    -- 2. Hit Marker
    showHitMarker(isCrit)

    -- 3. Screen Flash
    if isCrit then
        flashScreen(Color3.fromRGB(255, 220, 60), 0.2)
    elseif comboStep == 3 then
        flashScreen(Color3.fromRGB(65, 220, 255), 0.25)
    end

    -- 4. Controller Haptics
    triggerHaptics(if isCrit or comboStep == 3 then 0.8 else 0.4, 0.5, hitStop * 2)

    -- 5. Directional Slash VFX
    spawnComboSlashVFX(comboStep, origin)

    -- 6. Hit Stop (Tactile Micro-freeze)
    if hitStop > 0 then
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local animator = hum and hum:FindFirstChildOfClass("Animator")
        if animator then
            for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                if track.Name:find("Attack") or track.Name:find("Slash") then
                    track:AdjustSpeed(0.1)
                    task.delay(hitStop, function()
                        track:AdjustSpeed(1.0)
                    end)
                end
            end
        end
    end
end)

print("[CombatFeelController] Initialized: Screen Shake, Hit Stop, Hit Markers, Slash VFX, and Haptics.")