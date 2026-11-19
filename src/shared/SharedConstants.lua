--!strict
--[[
    SharedConstants.lua
    Shared configurations, types, and constants accessible to both Server and Client.
]]

export type GameConfig = {
    version: string,
    debugMode: boolean,
}

local SharedConstants = {
    VERSION = "0.1.0",
    DEBUG_MODE = true,
}

return SharedConstants
