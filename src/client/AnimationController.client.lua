--!strict
--[[
    AnimationController.client.lua
    Manages loading, caching, and playback of hero animation tracks.
    Supports animation slots: Idle, Walk, Run, Jump, Attack, HeavyAttack, AbilityCast, VictoryPose.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local CharacterRegistry = require(Shared:WaitForChild("CharacterRegistry"))

local player = Players.LocalPlayer
local loadedTracks: { [string]: AnimationTrack } = {}

local AnimationController = {}

local function getAnimator(): Animator?
    local character = player.Character
    if not character then return nil end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return nil end
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = humanoid
    end
    return animator
end

function AnimationController.LoadHeroAnimations(heroId: Types.CharacterId)
    local config = CharacterRegistry.GetCharacter(heroId)
    if not config then return end

    local animator = getAnimator()
    if not animator then return end

    -- Clear existing tracks
    for _, track in pairs(loadedTracks) do
        track:Stop(0.1)
        track:Destroy()
    end
    table.clear(loadedTracks)

    -- Load new animation tracks
    for slotName, assetId in pairs(config.animations) do
        local anim = Instance.new("Animation")
        anim.Name = slotName
        anim.AnimationId = assetId

        local success, track = pcall(function()
            return animator:LoadAnimation(anim)
        end)

        if success and track then
            -- Configure priority based on slot
            if slotName == "Idle" then
                track.Priority = Enum.AnimationPriority.Idle
                track.Looped = true
            elseif slotName == "Walk" or slotName == "Run" then
                track.Priority = Enum.AnimationPriority.Movement
                track.Looped = true
            elseif slotName == "Attack" or slotName == "HeavyAttack" then
                track.Priority = Enum.AnimationPriority.Action
            elseif slotName == "AbilityCast" or slotName == "VictoryPose" then
                track.Priority = Enum.AnimationPriority.Action2
            end

            loadedTracks[slotName] = track
        end
    end

    print(string.format("[AnimationController] Loaded %d animation tracks for %s", #config.abilities, heroId))
end

function AnimationController.PlayTrack(slotName: string, fadeTime: number?): AnimationTrack?
    local track = loadedTracks[slotName]
    if track then
        track:Play(fadeTime or 0.15)
        return track
    else
        warn(string.format("[AnimationController] Animation track %s not loaded.", slotName))
        return nil
    end
end

function AnimationController.StopTrack(slotName: string, fadeTime: number?)
    local track = loadedTracks[slotName]
    if track and track.IsPlaying then
        track:Stop(fadeTime or 0.15)
    end
end

-- Re-hook on hero load
local networkFolder = ReplicatedStorage:WaitForChild("Network")
local heroLoadedEvent = networkFolder:WaitForChild("HeroLoaded") :: RemoteEvent

heroLoadedEvent.OnClientEvent:Connect(function(heroId: string)
    AnimationController.LoadHeroAnimations(heroId)
    -- Start idle track
    task.delay(0.2, function()
        AnimationController.PlayTrack("Idle")
    end)
end)

return AnimationController
