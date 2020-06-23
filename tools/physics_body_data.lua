PhysicsBodyData = {}

local function defaultPointsSets()
    local pointsSets = {}

    local points = {}
    table.insert(pointsSets, points)

    local angle = math.pi * 2.0
    local angleDiff = math.pi * 2.0 / 8.0
    local scale = DRAW_DATA_SCALE
    local centerX = scale * 0.25
    local centerY = scale * 0.5
    local radius = scale * 0.23

    for i = 1, 8 do
        table.insert(points, centerX + math.cos(angle) * radius)
        table.insert(points, centerY + math.sin(angle) * radius)

        angle = angle - angleDiff
    end

    points = {}
    table.insert(pointsSets, points)

    angle = math.pi * 2.0
    centerX = scale * 0.75

    for i = 1, 8 do
        table.insert(points, centerX + math.cos(angle) * radius)
        table.insert(points, centerY + math.sin(angle) * radius)

        angle = angle - angleDiff
    end

    return pointsSets
end

function PhysicsBodyData:clone()
    return PhysicsBodyData:new(self)
end

function PhysicsBodyData:new(obj)
    if not obj or obj == nil then
        obj = {}
    end

    local newObj = {
        pointsSets = obj.pointsSets or defaultPointsSets(),
        scale = obj.scale or DRAW_DATA_SCALE,
    }

    setmetatable(newObj, self)
    self.__index = self

    return newObj
end

function PhysicsBodyData:serialize()
    local data = {
        pointsSets = self.pointsSets,
        scale = self.scale,
    }

    return data
end

function PhysicsBodyData:getShapesForBody(physics, width, height)
    local shapes = {}

    for _, points in pairs(self.pointsSets) do
        local newPoints = {}

        for i = 1, #points, 2 do
            table.insert(newPoints, (points[i] * 1.0 / self.scale - 1.0 / 2.0) * width)
            table.insert(newPoints, (points[i + 1] * 1.0 / self.scale - 1.0 / 2.0) * height)
        end

        table.insert(shapes, physics:newPolygonShape(newPoints))
    end

    return shapes
end