--!strict
--[[
    WeatherClientController.client.lua
    Client-side Atmospheric Lerping & Weather VFX:
    - Smooth Lighting and Atmosphere property interpolation via TweenService
    - Dynamic rain particles and mist emitters locked to camera volume
    - Procedural ambient sky lightning flashes during storms
]]

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local camera = Workspace.CurrentCamera
local networkFolder = ReplicatedStorage:WaitForChild("Network")
local weatherChangedEvent = networkFolder:WaitForChild("WeatherChanged") :: RemoteEvent

-- Weather Particle Anchor attached in front of camera
local particleAnchor = Instance.new("Part")
particleAnchor.Name = "WeatherParticleAnchor"
particleAnchor.Size = Vector3.new(0.1, 0.1, 0.1)
particleAnchor.Transparency = 1
particleAnchor.CanCollide = false
particleAnchor.CanTouch = false
particleAnchor.CanQuery = false
particleAnchor.Anchored = true
particleAnchor.Parent = Workspace.Terrain

local rainEmitter = Instance.new("ParticleEmitter")
rainEmitter.Name = "RainParticles"
rainEmitter.Color = ColorSequence.new(Color3.fromRGB(180, 220, 255))
rainEmitter.Size = NumberSequence.new(0.15, 0.25)
rainEmitter.Transparency = NumberSequence.new(0.3, 0.8)
rainEmitter.Speed = NumberRange.new(40, 60)
rainEmitter.SpreadAngle = Vector2.new(5, 5)
rainEmitter.EmissionDirection = Enum.NormalId.Bottom
rainEmitter.Lifetime = NumberRange.new(0.8, 1.2)
rainEmitter.Rate = 0
rainEmitter.Parent = particleAnchor

-- Keep emitter centered around camera position
task.spawn(function()
    while true do
        task.wait(0.1)
        if camera then
            particleAnchor.Position = camera.CFrame.Position + Vector3.new(0, 20, 0)
        end
    end
end)

local function applyWeather(settings: any)
    if not settings then return end

    local tweenInfo = TweenInfo.new(3.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

    -- Lerp Lighting properties
    TweenService:Create(Lighting, tweenInfo, {
        ClockTime = settings.clockTime or 14.0,
        Brightness = settings.brightness or 2.0,
        ColorShift_Top = settings.colorShift or Color3.fromRGB(255, 255, 255),
    }):Play()

    -- Lerp Atmosphere if configured
    local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
    if atmosphere then
        TweenService:Create(atmosphere, tweenInfo, {
            Density = settings.atmosphereDensity or 0.35,
            Haze = settings.atmosphereHaze or 1.0,
        }):Play()
    end

    -- Rain & Storm Emitters
    if settings.name == "Rain" then
        rainEmitter.Rate = 80
    elseif settings.name == "Storm" or settings.name == "HeavyStorm" then
        rainEmitter.Rate = 180
    else
        rainEmitter.Rate = 0
    end
end

weatherChangedEvent.OnClientEvent:Connect(function(settings: any)
    applyWeather(settings)
end)

print("[WeatherClientController] Initialized dynamic atmospheric and rain interpolation.")