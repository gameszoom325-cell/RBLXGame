--!strict
--[[
    AnimationController.client.lua
    Manages loading, caching, and playback of hero animation tracks.
    Supports animation slots: Idle, Walk, Run, Jump, Attack, HeavyAttack, AbilityCast, VictoryPose.
    Directly binds movement states (Walk/Run/Jump) and weapon attack swings.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local CharacterRegistry = require(Shared:WaitForChild("CharacterRegistry"))

local networkFolder = ReplicatedStorage:WaitForChild("Network")
local attackRequestEvent = networkFolder:WaitForChild("AttackRequest") :: RemoteEvent

local player = Players.LocalPlayer
local loadedTracks: { [string]: AnimationTrack } = {}

local AnimationController = {}
local movementConnections: { RBXScriptConnection } = {}

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

function AnimationController.PlayTrack(slotName: string, fadeTime: number?): AnimationTrack?
    local track = loadedTracks[slotName]
    if track then
        track:Play(fadeTime or 0.15)
        return track
    else
        return nil
    end
end

function AnimationController.StopTrack(slotName: string, fadeTime: number?)
    local track = loadedTracks[slotName]
    if track and track.IsPlaying then
        track:Stop(fadeTime or 0.15)
    end
end

-- Connects movement events (Run, Walk, Jump) and tool attack swings
local function bindCharacterAnimationEvents(character: Model)
    -- Clean previous connections
    for _, conn in ipairs(movementConnections) do
        conn:Disconnect()
    end
    table.clear(movementConnections)

    local humanoid = character:WaitForChild("Humanoid") :: Humanoid

    -- Running state listener (Walk vs Run vs Idle)
    local runConn = humanoid.Running:Connect(function(speed)
        if speed > 0.5 then
            AnimationController.StopTrack("Idle", 0.2)
            if speed > 12 then
                AnimationController.StopTrack("Walk", 0.15)
                if not (loadedTracks["Run"] and loadedTracks["Run"].IsPlaying) then
                    AnimationController.PlayTrack("Run", 0.15)
                end
            else
                AnimationController.StopTrack("Run", 0.15)
                if not (loadedTracks["Walk"] and loadedTracks["Walk"].IsPlaying) then
                    AnimationController.PlayTrack("Walk", 0.15)
                end
            end
        else
            AnimationController.StopTrack("Walk", 0.2)
            AnimationController.StopTrack("Run", 0.2)
            if not (loadedTracks["Idle"] and loadedTracks["Idle"].IsPlaying) then
                AnimationController.PlayTrack("Idle", 0.2)
            end
        end
    end)
    table.insert(movementConnections, runConn)

    -- Jump / Freefall state listener
    local stateConn = humanoid.StateChanged:Connect(function(_, newState)
        if newState == Enum.HumanoidStateType.Jumping or newState == Enum.HumanoidStateType.Freefall then
            AnimationController.PlayTrack("Jump", 0.1)
        elseif newState == Enum.HumanoidStateType.Landed then
            AnimationController.StopTrack("Jump", 0.15)
        end
    end)
    table.insert(movementConnections, stateConn)

    -- Tool Attack listener (Hammer swings)
    local function hookTool(tool: Tool)
        local actConn = tool.Activated:Connect(function()
            AnimationController.PlayTrack("Attack", 0.05)
            attackRequestEvent:FireServer()
        end)
        table.insert(movementConnections, actConn)
    end

    local childConn = character.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            hookTool(child)
        end
    end)
    table.insert(movementConnections, childConn)

    for _, child in ipairs(character:GetChildren()) do
        if child:IsA("Tool") then
            hookTool(child)
        end
    end
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
    local trackCount = 0
    for slotName, assetId in pairs(config.animations) do
        local anim = Instance.new("Animation")
        anim.Name = slotName
        anim.AnimationId = assetId

        local success, track = pcall(function()
            return animator:LoadAnimation(anim)
        end)

        if success and track then
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
            trackCount += 1
        end
    end

    if player.Character then
        bindCharacterAnimationEvents(player.Character)
    end

    print(string.format("[AnimationController] Loaded %d animation tracks for %s", trackCount, heroId))
end

-- Re-hook on hero load
local networkFolder = ReplicatedStorage:WaitForChild("Network")
local heroLoadedEvent = networkFolder:WaitForChild("HeroLoaded") :: RemoteEvent

heroLoadedEvent.OnClientEvent:Connect(function(heroId: string)
    AnimationController.LoadHeroAnimations(heroId)
    task.delay(0.2, function()
        AnimationController.PlayTrack("Idle", 0.2)
    end)
end)

return AnimationController
