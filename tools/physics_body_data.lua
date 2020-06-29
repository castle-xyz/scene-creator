PhysicsBodyData = {}

function PhysicsBodyData:clone()
    return PhysicsBodyData:new(self)
end

function PhysicsBodyData:new(obj)
    if not obj or obj == nil then
        obj = {}
    end

    local newObj = {
        shapes = obj.shapes or {},
        scale = obj.scale or DRAW_DATA_SCALE,
    }

    setmetatable(newObj, self)
    self.__index = self

    return newObj
end

function PhysicsBodyData:serialize()
    local data = {
        shapes = self.shapes,
        scale = self.scale,
    }

    return data
end

function PhysicsBodyData:draw()
    for _, shape in pairs(self.shapes) do
        local ty = shape.type
        if ty == "circle" then
            love.graphics.circle("line", shape.x, shape.y, shape.radius)
        elseif ty == "polygon" then
            love.graphics.polygon("line", shape.points)
        elseif ty == "edge" then
            love.graphics.polygon("line", shape.points)
        elseif ty == "chain" then
            love.graphics.polygon("line", shape.points)
        end
    end
end

function PhysicsBodyData:addCircle()
    table.insert(self.shapes, {
        type = "circle",
        x = self.scale * 0.5,
        y = self.scale * 0.5,
        radius = self.scale * 0.3,
    })
end

function PhysicsBodyData:addRectangle()
    local centerX = self.scale * 0.5
    local centerY = self.scale * 0.5
    local halfWidth = self.scale * 0.3
    local halfHeight = self.scale * 0.3

    table.insert(self.shapes, {
        type = "polygon",
        points = {
            centerX - halfWidth,
            centerY - halfHeight,
            centerX - halfWidth,
            centerY + halfHeight,
            centerX + halfWidth,
            centerY + halfHeight,
            centerX + halfWidth,
            centerY - halfHeight,
        },
    })
end

function PhysicsBodyData:getShapesForBody(physics, width, height)
    local shapes = {}

    local convertXCoord = function (x)
        return (x * 1.0 / self.scale - 1.0 / 2.0) * width
    end
    local convertYCoord = function (y)
        return (y * 1.0 / self.scale - 1.0 / 2.0) * height
    end
    local convertScale = function (s)
        return (s / self.scale) * width
    end

    for _, shape in pairs(self.shapes) do
        local ty = shape.type
        if ty == "circle" then
            table.insert(shapes, physics:newCircleShape(convertXCoord(shape.x), convertYCoord(shape.y), convertScale(shape.radius)))
        else
            local newPoints = {}

            for i = 1, #shape.points, 2 do
                table.insert(newPoints, convertXCoord(shape.points[i]))
                table.insert(newPoints, convertYCoord(shape.points[i + 1]))
            end

            if ty == "polygon" then
                table.insert(shapes, physics:newPolygonShape(newPoints))
            elseif ty == "edge" then
                table.insert(shapes, physics:newEdgeShape(newPoints))
            elseif ty == "chain" then
                table.insert(shapes, physics:newChainShape(newPoints))
            end
        end
    end

    if #shapes == 0 then
        table.insert(shapes, physics:newCircleShape(convertXCoord(0), convertYCoord(0), 0.3))
    end

    return shapes
end
