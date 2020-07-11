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
        tempShape = nil,
    }

    newObj = util.deepCopyTable(newObj)

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

function PhysicsBodyData:getHandlesForShape(shape)
    local type = shape.type
    local points

    if type == "circle" then
        points = {
            shape.x + shape.radius, shape.y,
            shape.x, shape.y + shape.radius,
            shape.x - shape.radius, shape.y,
            shape.x, shape.y - shape.radius,
        }
    else
        points = self:_pointsForShape(shape)
    end

    local centerX, centerY = self:_centerOfShape(shape)

    local results = {}
    for i = 1, #points, 2 do
        local x = points[i]
        local y = points[i + 1]

        table.insert(results, {
            x = x,
            y = y,
            oppositeX = x - (x - centerX) * 2.0,
            oppositeY = y - (y - centerY) * 2.0,
        })
    end

    return results
end

function PhysicsBodyData:_centerOfShape(shape)
    local type = shape.type

    if type == "circle" then
        return shape.x, shape.y
    else
        return (shape.p1.x + shape.p2.x) / 2.0, (shape.p1.y + shape.p2.y) / 2.0
    end
end

function PhysicsBodyData:_pointsForShape(shape)
    local type = shape.type

    local p1 = shape.p1
    local p2 = shape.p2

    if p1.x > p2.x then
        local t = p2
        p2 = p1
        p1 = t
    end

    if type == "rectangle" then
        return {
            p1.x, p1.y,
            p1.x, p2.y,
            p2.x, p2.y,
            p2.x, p1.y,
        }
    elseif type == "triangle" then
        local points = {
            p1.x, p1.y,
            p1.x, p2.y,
            p2.x, p2.y,
            p2.x, p1.y,
        }

        table.remove(points, shape.orientation * 2 + 1)
        table.remove(points, shape.orientation * 2 + 1)
        return points
    end
end

function PhysicsBodyData:_drawShape(shape)
    love.graphics.setLineWidth(0.1)

    local ty = shape.type
    if ty == "circle" then
        love.graphics.circle("line", shape.x, shape.y, shape.radius)
    else
        love.graphics.polygon("line", self:_pointsForShape(shape))
    end
end

function PhysicsBodyData:draw()
    for _, shape in pairs(self.shapes) do
        self:_drawShape(shape)
    end

    if self.tempShape then
        self:_drawShape(self.tempShape)
    end
end

local function _isBetweenNumbers(x, n1, n2)
    local low = math.min(n1, n2)
    local high = math.max(n1, n2)
    return x >= low and x <= high
end

local function signForTriangleTest(p1, p2, p3)
    return (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y)
end

function PhysicsBodyData:isPointInShape(point, shape)
    local type = shape.type
    if type == "rectangle" then
        return _isBetweenNumbers(point.x, shape.p1.x, shape.p2.x) and _isBetweenNumbers(point.y, shape.p1.y, shape.p2.y)
    elseif type == "circle" then
        local dist = math.sqrt(math.pow(point.x - shape.x, 2.0) + math.pow(point.y - shape.y, 2.0))
        return dist <= shape.radius
    elseif type == "triangle" then
        local points = self:_pointsForShape(shape)

        local d1, d2, d3
        local has_neg, has_pos
    
        d1 = signForTriangleTest(point, {
            x = points[1],
            y = points[2]
        }, {
            x = points[3],
            y = points[4]
        })
        d2 = signForTriangleTest(point, {
            x = points[3],
            y = points[4]
        }, {
            x = points[5],
            y = points[6]
        })
        d3 = signForTriangleTest(point, {
            x = points[5],
            y = points[6]
        }, {
            x = points[1],
            y = points[2]
        })
    
        has_neg = (d1 < 0) or (d2 < 0) or (d3 < 0)
        has_pos = (d1 > 0) or (d2 > 0) or (d3 > 0)
    
        return not (has_neg and has_pos)
    end
end

function PhysicsBodyData:isPointInBounds(point)
    return point.x >= -0.001 and point.x <= self.scale and point.y >= -0.001 and point.y <= self.scale
end

function PhysicsBodyData:isShapeInBounds(shape)
    local type = shape.type

    if type == "rectangle" or type == "triangle" then
        return self:isPointInBounds(shape.p1) and self:isPointInBounds(shape.p2)
    elseif type == "circle" then
        return self:isPointInBounds({
            x = shape.x + shape.radius,
            y = shape.y
        }) and self:isPointInBounds({
            x = shape.x,
            y = shape.y + shape.radius
        }) and self:isPointInBounds({
            x = shape.x,
            y = shape.y - shape.radius
        }) and self:isPointInBounds({
            x = shape.x - shape.radius,
            y = shape.y
        })
    end
end

local function numberSign(n)
    if n < 0 then
        return -1
    elseif n > 0 then
        return 1
    else
        return 0
    end
end

function PhysicsBodyData:moveShapeByIgnoreBounds(shape, diffX, diffY)
    local type = shape.type

    local result = util.deepCopyTable(shape)
    if type == "rectangle" or type == "triangle" then
        result.p1.x = shape.p1.x + diffX
        result.p2.x = shape.p2.x + diffX
        result.p1.y = shape.p1.y + diffY
        result.p2.y = shape.p2.y + diffY
    elseif type == "circle" then
        result.x = shape.x + diffX
        result.y = shape.y + diffY
    end

    return result
end

function PhysicsBodyData:moveShapeBy(shape, diffX, diffY, cellSize)
    local type = shape.type

    local currXDiff, currYDiff = 0.0, 0.0
    local incrementX = cellSize * numberSign(diffX)
    local incrementY = cellSize * numberSign(diffY)


    while math.abs(currXDiff) < math.abs(diffX) do
        currXDiff = currXDiff + incrementX
        local tempResult = self:moveShapeByIgnoreBounds(shape, currXDiff, currYDiff)

        if not self:isShapeInBounds(tempResult) then
            currXDiff = currXDiff - incrementX
            break
        end
    end

    while math.abs(currYDiff) < math.abs(diffY) do
        currYDiff = currYDiff + incrementY
        local tempResult = self:moveShapeByIgnoreBounds(shape, currXDiff, currYDiff)

        if not self:isShapeInBounds(tempResult) then
            currYDiff = currYDiff - incrementY
            break
        end
    end

    return self:moveShapeByIgnoreBounds(shape, currXDiff, currYDiff)
end

function PhysicsBodyData:getShapeIdxAtPoint(point)
    for i = #self.shapes, 1, -1 do
        if self:isPointInShape(point, self.shapes[i]) then
            return i
        end
    end

    return nil
end

function PhysicsBodyData:getNumShapes()
    return #self.shapes
end

function PhysicsBodyData:getShapeAtIndex(idx)
    return self.shapes[idx]
end

function PhysicsBodyData:removeShapeAtIndex(idx)
    local result = self.shapes[idx]
    table.remove(self.shapes, idx)
    return result
end

function PhysicsBodyData:commitTempShape()
    if self.tempShape then
        table.insert(self.shapes, self.tempShape)
        self.tempShape = nil
        return true
    end

    return false
end

local function floatEquals(f1, f2)
    return f1 > f2 - 0.001 and f1 < f2 + 0.001
end

local function sortPoints(p1, p2)
    if p1.x > p2.x then
        local t = p1
        p1 = p2
        p2 = t
    end

    local newP1 = {
        x = p1.x,
    }
    local newP2 = {
        x = p2.x
    }

    if p1.y > p2.y then
        local t = p1
        p1 = p2
        p2 = t
    end

    newP1.y = p1.y
    newP2.y = p2.y

    return newP1, newP2
end

function PhysicsBodyData:getRectangleShape(p1, p2)
    local shape = {
        type = "rectangle",
        p1 = p1,
        p2 = p2,
    }

    if self:isShapeInBounds(shape) and not floatEquals(p1.x, p2.x) and not floatEquals(p1.y, p2.y) then
        return shape
    else
        return nil
    end
end

function PhysicsBodyData:getTriangleShape(p1, p2)
    p1, p2 = sortPoints(p1, p2)

    local shape = {
        type = "triangle",
        p1 = p1,
        p2 = p2,
        orientation = 0,
    }

    if self:isShapeInBounds(shape) and not floatEquals(p1.x, p2.x) and not floatEquals(p1.y, p2.y) then
        return shape
    else
        return nil
    end
end

function PhysicsBodyData:getCircleShape(p1, p2, roundFn, roundDistFn)
    local shape = {
        type = "circle",
        x = (p1.x + p2.x) / 2.0,
        y = (p1.y + p2.y) / 2.0,
        radius = math.sqrt(math.pow(p2.x - p1.x, 2.0) + math.pow(p2.y - p1.y, 2.0)) / 2.0
    }

    local leftX = shape.x - shape.radius
    local leftY = shape.y

    leftX, leftY = roundFn(leftX, leftY)

    shape.radius = roundDistFn(shape.radius)
    shape.x = leftX + shape.radius
    shape.y = leftY

    if self:isShapeInBounds(shape) and shape.radius > 0 then
        return shape
    else
        return nil
    end
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
            local points = self:_pointsForShape(shape)
            local newPoints = {}

            for i = 1, #points, 2 do
                table.insert(newPoints, convertXCoord(points[i]))
                table.insert(newPoints, convertYCoord(points[i + 1]))
            end

            table.insert(shapes, physics:newPolygonShape(newPoints))

            --[[if ty == "polygon" then
                table.insert(shapes, physics:newPolygonShape(newPoints))
            elseif ty == "edge" then
                table.insert(shapes, physics:newEdgeShape(newPoints))
            elseif ty == "chain" then
                table.insert(shapes, physics:newChainShape(newPoints))
            end--]]
        end
    end

    if #shapes == 0 then
        table.insert(shapes, physics:newCircleShape(0, 0, math.min(width, height) * 0.5))
    end

    return shapes
end
