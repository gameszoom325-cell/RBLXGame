--!strict
--[[
    AudioManager.lua
    Centralized Audio Management Pipeline:
    - Dynamic BGM crossfading (Lobby <-> Wilds <-> Boss <-> Dungeon)
    - Sound effect synthesis with pitch randomization to prevent repetition fatigue
    - Automatic spatial positioning and volume balancing
    - Event-driven hooks into combat, level up, and UI interactions
]]

local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AudioConfig = require(Shared:WaitForChild("AudioConfig"))

local networkFolder = ReplicatedStorage:WaitForChild("Network")
local combatFeedbackEvent = networkFolder:WaitForChild("CombatFeedback") :: RemoteEvent
local levelUpEvent = networkFolder:WaitForChild("LevelUpEvent") :: RemoteEvent
local bossStateUpdatedEvent = networkFolder:WaitForChild("BossStateUpdated") :: RemoteEvent
local audioEvent = networkFolder:WaitForChild("AudioEvent") :: RemoteEvent

local AudioManager = {}

local activeMusicTrack: Sound? = nil
local activeMusicTrackName: string? = nil
local soundPoolFolder: Folder

-- Initialize dedicated sound holder
local existingFolder = SoundService:FindFirstChild("GameAudioPool")
if existingFolder and existingFolder:IsA("Folder") then
    soundPoolFolder = existingFolder
else
    soundPoolFolder = Instance.new("Folder")
    soundPoolFolder.Name = "GameAudioPool"
    soundPoolFolder.Parent = SoundService
end

-- =============================================================================
-- SOUND EFFECTS
-- =============================================================================

function AudioManager.PlaySFX(sfxKey: string, parentInstance: Instance?)
    local def = (AudioConfig.SFX :: any)[sfxKey]
    if not def then return end

    local sound = Instance.new("Sound")
    sound.Name = "SFX_" .. sfxKey
    sound.SoundId = def.soundId
    sound.Volume = def.volume or 0.5

    if def.pitchRange then
        local pMin = def.pitchRange[1] or 1.0
        local pMax = def.pitchRange[2] or 1.0
        sound.PlaybackSpeed = pMin + (math.random() * (pMax - pMin))
    else
        sound.PlaybackSpeed = 1.0
    end

    sound.Parent = parentInstance or soundPoolFolder
    sound:Play()

    sound.Ended:Connect(function()
        sound:Destroy()
    end)
end

-- =============================================================================
-- BACKGROUND MUSIC CROSSFADING
-- =============================================================================

function AudioManager.PlayMusic(trackName: string)
    if activeMusicTrackName == trackName then return end

    local def = (AudioConfig.Music :: any)[trackName]
    if not def then return end

    local oldTrack = activeMusicTrack
    activeMusicTrackName = trackName

    local newTrack = Instance.new("Sound")
    newTrack.Name = "BGM_" .. trackName
    newTrack.SoundId = def.id
    newTrack.Looped = true
    newTrack.Volume = 0
    newTrack.Parent = soundPoolFolder
    newTrack:Play()

    local fadeTime = def.fadeTime or 2.0

    -- Fade in new track
    TweenService:Create(newTrack, TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Volume = def.volume
    }):Play()

    -- Fade out old track
    if oldTrack then
        local fadeOut = TweenService:Create(oldTrack, TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Volume = 0
        })
        fadeOut:Play()
        fadeOut.Completed:Connect(function()
            oldTrack:Stop()
            oldTrack:Destroy()
        end)
    end

    activeMusicTrack = newTrack
    print(string.format("[AudioManager] Crossfaded BGM to '%s'", trackName))
end

-- =============================================================================
-- AUTOMATED EVENT HOOKS
-- =============================================================================

combatFeedbackEvent.OnClientEvent:Connect(function(data: any)
    if not data then return end
    AudioManager.PlaySFX("HammerSwing")
    if data.hitCount and data.hitCount > 0 then
        AudioManager.PlaySFX("HeavyImpact")
        if data.isCrit then
            AudioManager.PlaySFX("CritStrike")
        end
        if data.comboStep == 3 then
            AudioManager.PlaySFX("ThunderCrack")
        end
    end
end)

levelUpEvent.OnClientEvent:Connect(function()
    AudioManager.PlaySFX("LevelUp")
end)

bossStateUpdatedEvent.OnClientEvent:Connect(function(bossState: any)
    if bossState and bossState.name then
        AudioManager.PlayMusic("BossTheme")
    else
        -- Return to Lobby or Wilds ambient music
        AudioManager.PlayMusic("LobbyTheme")
    end
end)

audioEvent.OnClientEvent:Connect(function(action: string, param: string)
    if action == "PlayMusic" then
        AudioManager.PlayMusic(param)
    elseif action == "PlaySFX" then
        AudioManager.PlaySFX(param)
    end
end)

-- Start default Lobby theme
task.spawn(function()
    task.wait(1.0)
    AudioManager.PlayMusic("LobbyTheme")
end)

return AudioManager