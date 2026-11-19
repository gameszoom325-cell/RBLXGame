--!strict
--[[
    TestArenaBuilder.server.lua
    Bootstraps the Combat Proving Grounds / Combat Test Arena:
    Delegates arena construction to src/world/TestArena/CombatTestArenaBuilder.
    Constructs 5 Tempest Drones, 2 Storm Beasts, and 1 Damage Test Dummy.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local World = ReplicatedStorage:WaitForChild("World")
local CombatTestArenaBuilder = require(World:WaitForChild("TestArena"):WaitForChild("CombatTestArenaBuilder"))

CombatTestArenaBuilder.BuildArena()
