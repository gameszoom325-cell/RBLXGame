--!strict
--[[
    WeatherService.lua
    Server-authoritative Dynamic Weather Simulation:
    - Rotates realm weather states: Clear, Rain, Storm, HeavyStorm, DenseFog
    - Weather influences combat attributes (e.g. storms empower lightning damage by +10% to +15%)
    - Broadcasts WeatherChanged event for smooth client lighting/atmospheric interpolation
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local networkFolder = ReplicatedStorage:WaitForChild("Network")
local weatherChangedEvent = networkFolder:WaitForChild("WeatherChanged") :: RemoteEvent

export type WeatherType = "Clear" | "Rain" | "Storm" | "HeavyStorm" | "DenseFog"

export type WeatherSettings = {
    name: WeatherType,
    clockTime: number,
    brightness: number,
    atmosphereDensity: number,
    atmosphereHaze: number,
    lightningDamageMultiplier: number, -- e.g. 1.15 = +15%
    colorShift: Color3,
    description: string,
}

local WeatherService = {}

local WEATHER_PRESETS: { [WeatherType]: WeatherSettings } = {
    Clear = {
        name = "Clear",
        clockTime = 14.0,
        brightness = 2.2,
        atmosphereDensity = 0.30,
        atmosphereHaze = 0.5,
        lightningDamageMultiplier = 1.0,
        colorShift = Color3.fromRGB(255, 245, 230),
        description = "Clear skies with bright sunlight illuminating the sanctuary.",
    },

    Rain = {
        name = "Rain",
        clockTime = 16.5,
        brightness = 1.4,
        atmosphereDensity = 0.45,
        atmosphereHaze = 2.0,
        lightningDamageMultiplier = 1.05,
        colorShift = Color3.fromRGB(180, 200, 225),
        description = "Gentle rain falls across the outer wilds.",
    },

    Storm = {
        name = "Storm",
        clockTime = 18.0,
        brightness = 1.0,
        atmosphereDensity = 0.60,
        atmosphereHaze = 4.0,
        lightningDamageMultiplier = 1.10,
        colorShift = Color3.fromRGB(120, 160, 210),
        description = "Thunderclouds roll in. Lightning damage increased by +10%!",
    },

    HeavyStorm = {
        name = "HeavyStorm",
        clockTime = 20.5,
        brightness = 0.6,
        atmosphereDensity = 0.70,
        atmosphereHaze = 6.0,
        lightningDamageMultiplier = 1.15,
        colorShift = Color3.fromRGB(80, 130, 195),
        description = "Cataclysmic tempest raging! Lightning damage empowered by +15%!",
    },

    DenseFog = {
        name = "DenseFog",
        clockTime = 6.0,
        brightness = 1.1,
        atmosphereDensity = 0.80,
        atmosphereHaze = 8.0,
        lightningDamageMultiplier = 1.0,
        colorShift = Color3.fromRGB(160, 175, 195),
        description = "Dense mist shrouds vision across the realm.",
    },
}

local currentWeather: WeatherType = "Clear"

function WeatherService.GetCurrentWeather(): WeatherSettings
    return WEATHER_PRESETS[currentWeather]
end

function WeatherService.GetLightningMultiplier(): number
    local current = WEATHER_PRESETS[currentWeather]
    return if current then current.lightningDamageMultiplier else 1.0
end

function WeatherService.SetWeather(newWeather: WeatherType)
    if not WEATHER_PRESETS[newWeather] then return end
    currentWeather = newWeather

    local settings = WEATHER_PRESETS[newWeather]
    weatherChangedEvent:FireAllClients(settings)
    print(string.format("[WeatherService] Weather transitioned to [%s] (Lightning Multiplier: x%.2f)",
        newWeather, settings.lightningDamageMultiplier))
end

-- Automatic Weather Cycle (Rotates every 6 minutes)
task.spawn(function()
    local CYCLE_ORDER: { WeatherType } = { "Clear", "Rain", "Storm", "HeavyStorm", "DenseFog", "Clear" }
    local cycleIdx = 1

    while true do
        task.wait(360) -- 6 minutes per weather phase
        cycleIdx = (cycleIdx % #CYCLE_ORDER) + 1
        WeatherService.SetWeather(CYCLE_ORDER[cycleIdx])
    end
end)

return WeatherService