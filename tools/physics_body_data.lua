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
        version = obj.version or nil,
    }

    newObj = util.deepCopyTable(newObj)

    setmetatable(newObj, self)
    self.__index = self

    newObj:migrateV1ToV2()

    return newObj
end

function PhysicsBodyData:migrateV1ToV2()
    if self.version ~= nil and self.version >= 2 then
        return
    end

    self.version = 2

    local d = -self.scale / 2.0

    for i = 1, #self.shapes do
        local shape = self.shapes[i]
        self.shapes[i] = self:moveShapeByIgnoreBounds(shape, d, d)
    end

    if #self.shapes == 0 then
        table.insert(self.shapes, {
            type = "circle",
            x = 0.0,
            y = 0.0,
            radius = self.scale / 2.0,
        })
    end
end

function PhysicsBodyData:serialize()
    local data = {
        shapes = self.shapes,
        scale = self.scale,
        version = self.version,
    }

    return data
end

function PhysicsBodyData:getCenterOfShape(shape)
    local handles = self:getHandlesForShape(shape)
    local x = 0
    local y = 0
    local count = 0

    for i = 1, #handles do
        x = x + handles[i].x
        y = y + handles[i].y
        count = count + 1
    end

    return x / count, y / count
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
        local handle = {
            x = x,
            y = y,
            oppositeX = x - (x - centerX) * 2.0,
            oppositeY = y - (y - centerY) * 2.0,
        }

        table.insert(results, handle)
    end

    return results
end

function PhysicsBodyData:_centerOfShape(shape)
    local type = shape.type

    if type == "circle" then
        return shape.x, shape.y
    elseif type == "rectangle" then
        return (shape.p1.x + shape.p2.x) / 2.0, (shape.p1.y + shape.p2.y) / 2.0
    elseif type == "triangle" then
        return (shape.p1.x + shape.p2.x + shape.p3.x) / 3.0, (shape.p1.y + shape.p2.y + shape.p3.y) / 3.0
    end
end

function PhysicsBodyData:_pointsForShape(shape)
    local type = shape.type

    if type == "circle" then
        local numPoints = 30
        local angle = 0
        local points = {}
        for i = 1, numPoints do
            local diffX = shape.radius * math.cos(angle)
            local diffY = shape.radius * math.sin(angle)
            table.insert(points, shape.x + diffX)
            table.insert(points, shape.y + diffY)

            angle = angle - math.pi * 2.0 / numPoints
        end

        return points
    end

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
        local p3 = shape.p3
        local points = {
            p1.x, p1.y,
            p2.x, p2.y,
            p3.x, p3.y,
        }

        local isCounterclockwise = (p2.x - p1.x) * (p3.y - p1.y) - (p3.x - p1.x) * (p2.y - p1.y) > 0
        if not isCounterclockwise then
            points = {
                p3.x, p3.y,
                p2.x, p2.y,
                p1.x, p1.y,
            }
        end

        return points
    end
end

function PhysicsBodyData:_drawDashedPoints(points)
    local startsWithDash = true
    local leftoverAmount = 0

    for i = 1, #points, 2 do
        local next = i + 2
        if next > #points then
            next = next - #points
        end

        startsWithDash, leftoverAmount = self:_drawDashedLine({
            x = points[i],
            y = points[i + 1],
        }, {
            x = points[next],
            y = points[next + 1],
        }, startsWithDash, leftoverAmount)
    end
end

function PhysicsBodyData:_drawDashedLine(p1, p2, startsWithDash, leftoverAmount)
    local DASH_LENGTH = 0.3
    local BLANK_LENGTH = 0.3

    local totalLength = math.sqrt(math.pow(p2.x - p1.x, 2.0) + math.pow(p2.y - p1.y, 2.0))

    local unitVect = {
        x = p2.x - p1.x,
        y = p2.y - p1.y,
    }
    local l = math.sqrt(unitVect.x * unitVect.x + unitVect.y * unitVect.y)
    unitVect.x = unitVect.x / l
    unitVect.y = unitVect.y / l

    local currentDist = 0
    local isDash = startsWithDash

    while currentDist < totalLength do
        local currentSegmentLength

        if leftoverAmount > 0 then
            currentSegmentLength = leftoverAmount
            leftoverAmount = 0
        else
            if isDash then
                currentSegmentLength = DASH_LENGTH
            else
                currentSegmentLength = BLANK_LENGTH
            end
        end

        local drawCurrentSegmentLength = currentSegmentLength
        local cutOffSegment = false
        if drawCurrentSegmentLength + currentDist > totalLength then
            drawCurrentSegmentLength = totalLength - currentDist
            cutOffSegment = true
        end

        if isDash then
            love.graphics.line(
                p1.x + unitVect.x * currentDist,
                p1.y + unitVect.y * currentDist,
                p1.x + unitVect.x * (currentDist + drawCurrentSegmentLength),
                p1.y + unitVect.y * (currentDist + drawCurrentSegmentLength)
            )
        end

        if not cutOffSegment then
            isDash = not isDash
        end
        currentDist = currentDist + currentSegmentLength
    end

    return isDash, currentDist - totalLength
end

function PhysicsBodyData:_drawShape(shape)
    love.graphics.setLineWidth(0.06)
    self:_drawDashedPoints(self:_pointsForShape(shape))
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
    return point.x >= -DRAW_MAX_SIZE and point.x <= DRAW_MAX_SIZE and point.y >= -DRAW_MAX_SIZE and point.y <= DRAW_MAX_SIZE
end

function PhysicsBodyData:isShapeInBounds(shape)
    local type = shape.type

    if type == "rectangle" then
        return self:isPointInBounds(shape.p1) and self:isPointInBounds(shape.p2)
    elseif type == "triangle" then
        return self:isPointInBounds(shape.p1) and self:isPointInBounds(shape.p2) and self:isPointInBounds(shape.p3)
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
    if type == "rectangle" then
        result.p1.x = shape.p1.x + diffX
        result.p2.x = shape.p2.x + diffX
        result.p1.y = shape.p1.y + diffY
        result.p2.y = shape.p2.y + diffY
    elseif type == "triangle" then
        result.p1.x = shape.p1.x + diffX
        result.p2.x = shape.p2.x + diffX
        result.p3.x = shape.p3.x + diffX
        result.p1.y = shape.p1.y + diffY
        result.p2.y = shape.p2.y + diffY
        result.p3.y = shape.p3.y + diffY
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

function PhysicsBodyData:updateShapeAtIdx(idx, shape)
    self.shapes[idx] = shape
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

function PhysicsBodyData:getTriangleShape(p1, p2, p3)
    if not p3 then
        p3 = {
            x = p1.x,
            y = p2.y,
        }
    end

    local shape = {
        type = "triangle",
        p1 = p1,
        p2 = p2,
        p3 = p3,
    }

    local isColinear = math.abs((p2.x - p1.x) * (p3.y - p1.y) - (p3.x - p1.x) * (p2.y - p1.y)) < 0.01

    if self:isShapeInBounds(shape) and isColinear == false then
        return shape
    else
        return nil
    end
end

function PhysicsBodyData:getCircleShape(p1, p2, roundFn, roundDistFn, roundDx, roundDy)
    local shape = {
        type = "circle",
        x = (p1.x + p2.x) / 2.0,
        y = (p1.y + p2.y) / 2.0,
        radius = math.sqrt(math.pow(p2.x - p1.x, 2.0) + math.pow(p2.y - p1.y, 2.0)) / 2.0
    }

    if not roundDx then
        roundDx = -1
    end
    if not roundDy then
        roundDy = 0
    end

    local leftX = shape.x + roundDx * shape.radius
    local leftY = shape.y + roundDy * shape.radius

    leftX, leftY = roundFn(leftX, leftY)

    shape.radius = roundDistFn(shape.radius)
    shape.x = leftX - roundDx * shape.radius
    shape.y = leftY - roundDy * shape.radius

    if self:isShapeInBounds(shape) and shape.radius > 0 then
        return shape
    else
        return nil
    end
end

function PhysicsBodyData:getShapesForBody()
    local shapes = {}

    for _, shape in pairs(self.shapes) do
        local ty = shape.type
        if ty == "circle" then
            table.insert(shapes, {
                shapeType = "circle",
                x = shape.x,
                y = shape.y,
                radius = shape.radius,
            })
        else
            table.insert(shapes, {
                shapeType = "polygon",
                points = self:_pointsForShape(shape),
            })
        end
    end

    return shapes
end
