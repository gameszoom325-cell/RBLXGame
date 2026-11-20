--!strict
--[[
    ObjectPool.lua
    Zero-allocation Object Pooling Engine for Roblox RPG:
    - Eliminates GC pressure and runtime memory fragmentation
    - Reusable pools for BillboardGuis, VFX parts, particles, and hit spark anchors
    - Automatic reset and grow-on-demand mechanics
]]

export type Pool<T> = {
    Acquire: (self: Pool<T>) -> T,
    Release: (self: Pool<T>, object: T) -> (),
    Prewarm: (self: Pool<T>, count: number) -> (),
    Clear: (self: Pool<T>) -> (),
}

local ObjectPool = {}

function ObjectPool.New<T>(factory: () -> T, reset: ((T) -> ())?, initialSize: number?): Pool<T>
    local freeList: { T } = {}
    local size = initialSize or 10

    local pool: Pool<T> = {} :: any

    function pool:Acquire(): T
        local obj = table.remove(freeList)
        if not obj then
            obj = factory()
        end
        return obj
    end

    function pool:Release(object: T)
        if reset then
            reset(object)
        end
        table.insert(freeList, object)
    end

    function pool:Prewarm(count: number)
        for _ = 1, count do
            local obj = factory()
            if reset then
                reset(obj)
            end
            table.insert(freeList, obj)
        end
    end

    function pool:Clear()
        table.clear(freeList)
    end

    if size > 0 then
        pool:Prewarm(size)
    end

    return pool
end

return ObjectPool