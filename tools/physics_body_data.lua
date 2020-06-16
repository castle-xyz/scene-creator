PhysicsBodyData = {}

function PhysicsBodyData:clone()
    return PhysicsBodyData:new(self)
end

function PhysicsBodyData:new(obj)
    if not obj or obj == nil then
        obj = {}
    end

    local newObj = {}


    setmetatable(newObj, self)
    self.__index = self

    return newObj
end

function PhysicsBodyData:serialize()
    local data = {}

    return data
end
