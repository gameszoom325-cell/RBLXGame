--!strict
--[[
    AtmosphereController.lua
    Environment & Lighting Controller:
    Configures fantasy adventure atmospheric lighting, twilight sky colors, and bloom.
]]

local Lighting = game:GetService("Lighting")

local AtmosphereController = {}

function AtmosphereController.ApplyFantasyPreset()
    Lighting.ClockTime = 17.5
    Lighting.GeographicLatitude = 23.5
    Lighting.OutdoorAmbient = Color3.fromRGB(75, 90, 115)
    Lighting.Ambient = Color3.fromRGB(45, 55, 70)
    Lighting.Brightness = 2.2
    Lighting.ColorShift_Top = Color3.fromRGB(240, 225, 210)
    Lighting.ColorShift_Bottom = Color3.fromRGB(30, 45, 65)

    -- Atmosphere Instance
    local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
    if not atmosphere then
        atmosphere = Instance.new("Atmosphere")
        atmosphere.Parent = Lighting
    end
    atmosphere.Density = 0.32
    atmosphere.Offset = 0.25
    atmosphere.Color = Color3.fromRGB(150, 180, 215)
    atmosphere.Decay = Color3.fromRGB(90, 105, 135)
    atmosphere.Glare = 0.4
    atmosphere.Haze = 1.1

    -- Bloom Effect
    local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
    if not bloom then
        bloom = Instance.new("BloomEffect")
        bloom.Parent = Lighting
    end
    bloom.Intensity = 0.75
    bloom.Size = 24
    bloom.Threshold = 0.95

    -- God Rays (SunRaysEffect)
    local sunRays = Lighting:FindFirstChildOfClass("SunRaysEffect")
    if not sunRays then
        sunRays = Instance.new("SunRaysEffect")
        sunRays.Parent = Lighting
    end
    sunRays.Intensity = 0.25
    sunRays.Spread = 0.85

    -- Rich Fantasy Color Correction
    local colorCorr = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
    if not colorCorr then
        colorCorr = Instance.new("ColorCorrectionEffect")
        colorCorr.Parent = Lighting
    end
    colorCorr.Brightness = 0.03
    colorCorr.Contrast = 0.12
    colorCorr.Saturation = 0.18

    print("[AtmosphereController] Fantasy lighting, volumetric god rays, and atmospheric presets applied.")
end

return AtmosphereController
