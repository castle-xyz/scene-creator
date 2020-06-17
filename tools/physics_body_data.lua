PhysicsBodyData = {}

local function defaultPoints()
    local points = {}
    local angle = math.pi * 2.0
    local angleDiff = math.pi * 2.0 / 8.0
    local scale = DRAW_DATA_SCALE
    local center = scale * 0.5
    local radius = scale * 0.5

    for i = 1, 8 do
        table.insert(points, center + math.cos(angle) * radius)
        table.insert(points, center + math.sin(angle) * radius)

        angle = angle - angleDiff
    end

    return points
end

function PhysicsBodyData:clone()
    return PhysicsBodyData:new(self)
end

function PhysicsBodyData:new(obj)
    if not obj or obj == nil then
        obj = {}
    end

    local newObj = {
        points = obj.points or defaultPoints(),
        scale = obj.scale or DRAW_DATA_SCALE,
    }

    setmetatable(newObj, self)
    self.__index = self

    return newObj
end

function PhysicsBodyData:serialize()
    local data = {
        points = self.points,
        scale = self.scale,
    }

    return data
end

function PhysicsBodyData:getNormalizedPoints()
    local points = {}

    for i = 1, #self.points, 2 do
        table.insert(points, self.points[i] * 1.0 / self.scale - 1.0 / 2.0)
        table.insert(points, self.points[i + 1] * 1.0 / self.scale - 1.0 / 2.0)
    end

    return points
end