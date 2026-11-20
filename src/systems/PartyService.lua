--!strict
--[[
    PartyService.lua
    Server-authoritative Multiplayer Party System:
    - Party Size: up to 4 players
    - Invite, Accept, Decline, Leave, Kick, Leadership transfer
    - In-party chat broadcast and synchronized health replication
    - Shared Party XP (+15% bonus per nearby member within 80 studs)
    - Shared encounter loot rolls for party members
    - Downed state and nearby channel-revive mechanism (12-stud range)
]]

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Systems = ReplicatedStorage:WaitForChild("Systems")

local ProgressionTypes = require(Shared:WaitForChild("ProgressionTypes"))
local ProgressionManager = require(Systems:WaitForChild("ProgressionManager"))
local EconomyManager = require(Systems:WaitForChild("EconomyManager"))
local InventoryManager = require(Systems:WaitForChild("InventoryManager"))

type PartyMember = ProgressionTypes.PartyMember
type PartyData = ProgressionTypes.PartyData

local networkFolder = ReplicatedStorage:WaitForChild("Network")
local partyActionEvent = networkFolder:WaitForChild("PartyAction") :: RemoteEvent
local partyUpdatedEvent = networkFolder:WaitForChild("PartyUpdated") :: RemoteEvent
local partyInviteReceivedEvent = networkFolder:WaitForChild("PartyInviteReceived") :: RemoteEvent

local PartyService = {}

local MAX_PARTY_SIZE = 4
local PARTY_SHARE_RADIUS = 85.0
local REVIVE_DISTANCE = 14.0

-- Internal store
local activeParties: { [string]: PartyData } = {}
local playerToPartyId: { [number]: string } = {}
local pendingInvites: { [number]: { [string]: { inviterName: string, partyId: string, timestamp: number } } } = {}

local function createPartyMember(player: Player, isLeader: boolean): PartyMember
    local char = player.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    local curHp = if humanoid then humanoid.Health else 200
    local maxHp = if humanoid then humanoid.MaxHealth else 200
    local lvl = player:GetAttribute("Level") or 1

    return {
        userId = player.UserId,
        name = player.Name,
        level = lvl,
        health = curHp,
        maxHealth = maxHp,
        isLeader = isLeader,
        isDowned = (curHp <= 0),
    }
end

function PartyService.GetParty(player: Player): PartyData?
    local partyId = playerToPartyId[player.UserId]
    return if partyId then activeParties[partyId] else nil
end

function PartyService.GetPartyById(partyId: string): PartyData?
    return activeParties[partyId]
end

function PartyService.GetPartyMembers(player: Player): { Player }
    local party = PartyService.GetParty(player)
    if not party then return { player } end

    local list: { Player } = {}
    for userId, _ in pairs(party.members) do
        local p = Players:GetPlayerByUserId(userId)
        if p then table.insert(list, p) end
    end
    return list
end

function PartyService.SyncParty(partyId: string)
    local party = activeParties[partyId]
    if not party then return end

    -- Update live healths of all members
    for userId, member in pairs(party.members) do
        local p = Players:GetPlayerByUserId(userId)
        if p and p.Character then
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                member.health = hum.Health
                member.maxHealth = hum.MaxHealth
                member.level = p:GetAttribute("Level") or member.level
                member.isDowned = (hum.Health <= 0)
            end
        end
    end

    for userId, _ in pairs(party.members) do
        local p = Players:GetPlayerByUserId(userId)
        if p then
            partyUpdatedEvent:FireClient(p, party)
        end
    end
end

function PartyService.CreateParty(leader: Player): PartyData
    -- Leave existing party if already in one
    PartyService.LeaveParty(leader)

    local partyId = "Party_" .. HttpService:GenerateGUID(false):sub(1, 8)
    local party: PartyData = {
        id = partyId,
        leaderUserId = leader.UserId,
        members = {
            [leader.UserId] = createPartyMember(leader, true)
        },
    }

    activeParties[partyId] = party
    playerToPartyId[leader.UserId] = partyId

    PartyService.SyncParty(partyId)
    print(string.format("[PartyService] %s created party %s", leader.Name, partyId))
    return party
end

function PartyService.InvitePlayer(inviter: Player, targetPlayer: Player): (boolean, string)
    if inviter == targetPlayer then
        return false, "Cannot invite yourself."
    end

    local partyId = playerToPartyId[inviter.UserId]
    local party = partyId and activeParties[partyId]

    if not party then
        -- Automatically form new party with inviter as leader
        party = PartyService.CreateParty(inviter)
        partyId = party.id
    end

    if party.leaderUserId ~= inviter.UserId then
        return false, "Only the party leader can invite players."
    end

    local memberCount = 0
    for _ in pairs(party.members) do memberCount += 1 end
    if memberCount >= MAX_PARTY_SIZE then
        return false, "Party is currently full (4/4 members)."
    end

    if playerToPartyId[targetPlayer.UserId] then
        return false, string.format("%s is already in a party.", targetPlayer.Name)
    end

    local targetId = targetPlayer.UserId
    pendingInvites[targetId] = pendingInvites[targetId] or {}
    pendingInvites[targetId][partyId] = {
        inviterName = inviter.Name,
        partyId = partyId,
        timestamp = os.clock(),
    }

    partyInviteReceivedEvent:FireClient(targetPlayer, partyId, inviter.Name)
    print(string.format("[PartyService] %s invited %s to party %s", inviter.Name, targetPlayer.Name, partyId))
    return true, "Invitation sent!"
end

function PartyService.AcceptInvite(player: Player, partyId: string): (boolean, string)
    local userId = player.UserId
    local invites = pendingInvites[userId]
    if not invites or not invites[partyId] then
        return false, "No pending invitation found."
    end

    local party = activeParties[partyId]
    if not party then
        invites[partyId] = nil
        return false, "Party no longer exists."
    end

    local count = 0
    for _ in pairs(party.members) do count += 1 end
    if count >= MAX_PARTY_SIZE then
        invites[partyId] = nil
        return false, "Party is now full."
    end

    PartyService.LeaveParty(player)

    party.members[userId] = createPartyMember(player, false)
    playerToPartyId[userId] = partyId
    invites[partyId] = nil

    PartyService.SyncParty(partyId)
    print(string.format("[PartyService] %s joined party %s", player.Name, partyId))
    return true, "Joined party!"
end

function PartyService.DeclineInvite(player: Player, partyId: string)
    local userId = player.UserId
    if pendingInvites[userId] then
        pendingInvites[userId][partyId] = nil
    end
end

function PartyService.LeaveParty(player: Player)
    local userId = player.UserId
    local partyId = playerToPartyId[userId]
    if not partyId then return end

    local party = activeParties[partyId]
    playerToPartyId[userId] = nil
    partyUpdatedEvent:FireClient(player, nil) -- Clear UI for leaving player

    if not party then return end

    party.members[userId] = nil

    local remainingCount = 0
    local nextLeaderId: number? = nil

    for mId, _ in pairs(party.members) do
        remainingCount += 1
        if not nextLeaderId then nextLeaderId = mId end
    end

    if remainingCount == 0 then
        activeParties[partyId] = nil
        print(string.format("[PartyService] Party %s disbanded.", partyId))
    else
        if party.leaderUserId == userId and nextLeaderId then
            party.leaderUserId = nextLeaderId
            party.members[nextLeaderId].isLeader = true
            print(string.format("[PartyService] Leadership transferred to %s in party %s", party.members[nextLeaderId].name, partyId))
        end
        PartyService.SyncParty(partyId)
    end
end

function PartyService.KickMember(leader: Player, targetUserId: number): (boolean, string)
    local party = PartyService.GetParty(leader)
    if not party or party.leaderUserId ~= leader.UserId then
        return false, "Only party leader can kick members."
    end

    if leader.UserId == targetUserId then
        return false, "Cannot kick yourself. Use Leave Party."
    end

    if not party.members[targetUserId] then
        return false, "Player is not in your party."
    end

    local targetPlayer = Players:GetPlayerByUserId(targetUserId)
    if targetPlayer then
        PartyService.LeaveParty(targetPlayer)
    else
        party.members[targetUserId] = nil
        playerToPartyId[targetUserId] = nil
        PartyService.SyncParty(party.id)
    end

    return true, "Member kicked."
end

function PartyService.PartyChat(sender: Player, message: string)
    local party = PartyService.GetParty(sender)
    if not party then return end

    local cleanMsg = message:sub(1, 140)
    for userId, _ in pairs(party.members) do
        local p = Players:GetPlayerByUserId(userId)
        if p then
            partyActionEvent:FireClient(p, "ChatMessage", sender.Name, cleanMsg)
        end
    end
end

-- =============================================================================
-- SHARED XP & LOOT MULTIPLIERS
-- =============================================================================

function PartyService.DistributeSharedXP(killer: Player, baseXP: number, sourceName: string)
    local party = PartyService.GetParty(killer)
    if not party then
        ProgressionManager.AddXP(killer, baseXP, sourceName)
        return
    end

    local killerChar = killer.Character
    local killerHrp = killerChar and killerChar:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not killerHrp then
        ProgressionManager.AddXP(killer, baseXP, sourceName)
        return
    end

    -- Find all party members within encounter radius
    local nearbyMembers: { Player } = {}
    for userId, _ in pairs(party.members) do
        local p = Players:GetPlayerByUserId(userId)
        if p and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
            if hrp and (hrp.Position - killerHrp.Position).Magnitude <= PARTY_SHARE_RADIUS then
                table.insert(nearbyMembers, p)
            end
        end
    end

    -- Party XP Bonus: +15% XP per nearby party member!
    local bonusMultiplier = 1.0 + (math.max(0, #nearbyMembers - 1) * 0.15)
    local finalXP = math.floor(baseXP * bonusMultiplier)

    for _, member in ipairs(nearbyMembers) do
        ProgressionManager.AddXP(member, finalXP, string.format("Party:%s", sourceName))
    end

    print(string.format("[PartyService] Distributed %d XP (+%d%% party bonus) to %d nearby member(s)",
        finalXP, math.floor((bonusMultiplier - 1.0) * 100), #nearbyMembers))
end

function PartyService.DistributeSharedLoot(killer: Player, totalGold: number, rolledItems: { { id: string, count: number } }, sourceName: string)
    local party = PartyService.GetParty(killer)
    if not party then
        EconomyManager.AddGold(killer, totalGold, sourceName)
        for _, item in ipairs(rolledItems) do
            InventoryManager.AddItem(killer, item.id, item.count)
        end
        return
    end

    local killerChar = killer.Character
    local killerHrp = killerChar and killerChar:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not killerHrp then
        EconomyManager.AddGold(killer, totalGold, sourceName)
        for _, item in ipairs(rolledItems) do
            InventoryManager.AddItem(killer, item.id, item.count)
        end
        return
    end

    local nearbyMembers: { Player } = {}
    for userId, _ in pairs(party.members) do
        local p = Players:GetPlayerByUserId(userId)
        if p and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
            if hrp and (hrp.Position - killerHrp.Position).Magnitude <= PARTY_SHARE_RADIUS then
                table.insert(nearbyMembers, p)
            end
        end
    end

    -- Distribute gold and duplicate/share loot roll to all nearby adventurers
    for _, member in ipairs(nearbyMembers) do
        EconomyManager.AddGold(member, totalGold, string.format("Party:%s", sourceName))
        for _, item in ipairs(rolledItems) do
            InventoryManager.AddItem(member, item.id, item.count)
        end
    end
end

-- =============================================================================
-- NEARBY REVIVE MECHANISM
-- =============================================================================

function PartyService.NearbyRevive(reviver: Player, downedPlayer: Player): (boolean, string)
    if reviver == downedPlayer then return false, "Cannot revive yourself." end

    local party1 = PartyService.GetParty(reviver)
    local party2 = PartyService.GetParty(downedPlayer)
    if not party1 or not party2 or party1.id ~= party2.id then
        return false, "Target is not in your party."
    end

    local reviverChar = reviver.Character
    local downedChar = downedPlayer.Character
    if not reviverChar or not downedChar then return false, "Invalid character." end

    local reviverHrp = reviverChar:FindFirstChild("HumanoidRootPart") :: BasePart?
    local downedHrp = downedChar:FindFirstChild("HumanoidRootPart") :: BasePart?
    local downedHum = downedChar:FindFirstChildOfClass("Humanoid")

    if not reviverHrp or not downedHrp or not downedHum then return false, "Invalid targets." end

    if (reviverHrp.Position - downedHrp.Position).Magnitude > REVIVE_DISTANCE then
        return false, "Too far from fallen ally to revive."
    end

    -- Restore 50% health and cancel downed state
    downedHum.Health = math.floor(downedHum.MaxHealth * 0.5)
    downedChar:SetAttribute("IsDowned", false)

    PartyService.SyncParty(party1.id)
    print(string.format("[PartyService] %s revived party member %s!", reviver.Name, downedPlayer.Name))
    return true, "Ally revived!"
end

-- =============================================================================
-- NETWORK LISTENER
-- =============================================================================

partyActionEvent.OnServerEvent:Connect(function(player: Player, action: string, param1: any, param2: any)
    if typeof(action) ~= "string" then return end

    if action == "Invite" and typeof(param1) == "string" then
        local target = Players:FindFirstChild(param1)
        if target and target:IsA("Player") then
            PartyService.InvitePlayer(player, target)
        end
    elseif action == "Accept" and typeof(param1) == "string" then
        PartyService.AcceptInvite(player, param1)
    elseif action == "Decline" and typeof(param1) == "string" then
        PartyService.DeclineInvite(player, param1)
    elseif action == "Leave" then
        PartyService.LeaveParty(player)
    elseif action == "Kick" and typeof(param1) == "number" then
        PartyService.KickMember(player, param1)
    elseif action == "Chat" and typeof(param1) == "string" then
        PartyService.PartyChat(player, param1)
    elseif action == "Revive" and typeof(param1) == "string" then
        local target = Players:FindFirstChild(param1)
        if target and target:IsA("Player") then
            PartyService.NearbyRevive(player, target)
        end
    end
end)

Players.PlayerRemoving:Connect(function(player: Player)
    PartyService.LeaveParty(player)
    pendingInvites[player.UserId] = nil
end)

return PartyService