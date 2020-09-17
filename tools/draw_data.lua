DrawData = {}
local FILL_CANVAS_SIZE = 256

function DrawData:gridCellSize()
    return self.scale / (self.gridSize - 1)
end

function DrawData:globalToGridCoordinates(x, y)
    local gridX = 1.0 + (self.gridSize - 1) * x / self.scale
    local gridY = 1.0 + (self.gridSize - 1) * y / self.scale
    return gridX, gridY
end

function DrawData:gridToGlobalCoordinates(x, y)
    local globalX = (x - 1.0) * self:gridCellSize()
    local globalY = (y - 1.0) * self:gridCellSize()
    return globalX, globalY
end

function DrawData:roundGlobalDiffCoordinatesToGrid(x, y)
    local gridX, gridY = self:globalToGridCoordinates(x, y)

    gridX = math.floor(gridX + 0.5)
    gridY = math.floor(gridY + 0.5)

    return self:gridToGlobalCoordinates(gridX, gridY)
end

function DrawData:roundGlobalCoordinatesToGrid(x, y)
    local gridX, gridY = self:globalToGridCoordinates(x, y)

    gridX = math.floor(gridX + 0.5)
    gridY = math.floor(gridY + 0.5)

    if gridX <= 0 then
        gridX = 1
    elseif gridX > self.gridSize then
        gridX = self.gridSize
    end

    if gridY <= 0 then
        gridY = 1
    elseif gridY > self.gridSize then
        gridY = self.gridSize
    end

    return self:gridToGlobalCoordinates(gridX, gridY)
end

function DrawData:clampGlobalCoordinates(x, y)
    if x < 0 then
        x = 0
    elseif x > self.scale then
        x = self.scale
    end

    if y < 0 then
        y = 0
    elseif y > self.scale then
        y = self.scale
    end

    return x, y
end

function DrawData:roundGlobalDistanceToGrid(d)
    local x, y = self:roundGlobalCoordinatesToGrid(d, 0)
    return x
end

local function makeSubpathsFromSubpathData(pathData)
    for i = 1, #pathData.subpathDataList do
        local subpathData = pathData.subpathDataList[i]
        local subpath = tove.newSubpath()
        pathData.tovePath:addSubpath(subpath)
        pathData.tovePathThin:addSubpath(subpath)

        if subpathData.type == 'line' then
            subpath:moveTo(subpathData.p1.x, subpathData.p1.y)
            subpath:lineTo(subpathData.p2.x, subpathData.p2.y)
        elseif subpathData.type == 'arc' then
            subpath:arc(subpathData.center.x, subpathData.center.y, subpathData.radius, subpathData.startAngle * 180 / math.pi, subpathData.endAngle * 180 / math.pi)
        end
    end
end

local function addLineSubpathData(pathData, p1x, p1y, p2x, p2y)
    table.insert(pathData.subpathDataList, {
        type = 'line',
        p1 = {
            x = p1x,
            y = p1y
        },
        p2 = {
            x = p2x,
            y = p2y
        }
    })
end

local function addCircleSubpathData(pathData, centerX, centerY, radius, startAngle, endAngle)
    table.insert(pathData.subpathDataList, {
        type = 'arc',
        center = {
            x = centerX,
            y = centerY
        },
        radius = radius,
        startAngle = startAngle,
        endAngle = endAngle
    })
end

function DrawData:drawEndOfArc(pathData, p1x, p1y, p2x, p2y)
    if p1x == p2x and p1y == p2y then
        return
    end

    -- TODO: fix
    p1x, p1y = self:roundGlobalCoordinatesToGrid(p1x, p1y)
    p2x, p2y = self:roundGlobalCoordinatesToGrid(p2x, p2y)

    addLineSubpathData(pathData, p1x, p1y, p2x, p2y)
end

function DrawData:updatePathDataRendering(pathData)
    if pathData.tovePath and pathData.tovePath ~= nil then
        return
    end

    local path = tove.newPath()
    if pathData.color then
        path:setLineColor(pathData.color[1], pathData.color[2], pathData.color[3], 1.0)
    else
        path:setLineColor(self.lineColor[1], self.lineColor[2], self.lineColor[3], 1.0)
    end
    path:setLineWidth(0.2)
    path:setMiterLimit(1)
    path:setLineJoin("round")
    pathData.tovePath = path

    local pathThin = tove.newPath()
    pathThin:setLineColor(1.0, 1.0, 1.0, 1.0)
    pathThin:setLineWidth(0.05)
    pathThin:setMiterLimit(1)
    pathThin:setLineJoin("round")
    pathData.tovePathThin = pathThin

    pathData.subpathDataList = {}

    local p1 = pathData.points[1]
    local p2 = pathData.points[2]
    local style = pathData.style
    local bendPoint = pathData.bendPoint

    if bendPoint then
        local midpointP1P2 = {
            x = (p1.x + p2.x) / 2.0,
            y = (p1.y + p2.y) / 2.0,
        }
        local radiusP1P2 = math.sqrt(math.pow(p1.x - p2.x, 2.0) + math.pow(p1.y - p2.y, 2.0)) / 2.0
        local distFromMidpointToBendPoint = math.sqrt(math.pow(midpointP1P2.x - bendPoint.x, 2.0) + math.pow(midpointP1P2.y - bendPoint.y, 2.0))
    
        if distFromMidpointToBendPoint > radiusP1P2 then
            local scaleAmt = radiusP1P2 / distFromMidpointToBendPoint

            bendPoint = {
                x = (bendPoint.x - midpointP1P2.x) * scaleAmt + midpointP1P2.x,
                y = (bendPoint.y - midpointP1P2.y) * scaleAmt + midpointP1P2.y,
            }
        end

        local p1NormalVector = {
            dx = -(bendPoint.y - p1.y),
            dy = bendPoint.x - p1.x
        }
        local p2NormalVector = {
            dx = -(bendPoint.y - p2.y),
            dy = bendPoint.x - p2.x
        }
        local p1Midpoint = {
            x = (bendPoint.x + p1.x) / 2.0,
            y = (bendPoint.y + p1.y) / 2.0,
        }
        local p2Midpoint = {
            x = (bendPoint.x + p2.x) / 2.0,
            y = (bendPoint.y + p2.y) / 2.0,
        }
    
        local circleCenterX, circleCenterY = rayRayIntersection(
            p1Midpoint.x, p1Midpoint.y,
            p1Midpoint.x + p1NormalVector.dx, p1Midpoint.y + p1NormalVector.dy,
            p2Midpoint.x, p2Midpoint.y,
            p2Midpoint.x + p2NormalVector.dx, p2Midpoint.y + p2NormalVector.dy
        )
    
        if circleCenterX == nil then
            addLineSubpathData(pathData, p1.x, p1.y, p2.x, p2.y)
            makeSubpathsFromSubpathData(pathData)
            return
        end
    
        local radius = math.sqrt(math.pow(p1.y - circleCenterY, 2.0) + math.pow(p1.x - circleCenterX, 2.0))
    
        if radius > 50 then
            addLineSubpathData(pathData, p1.x, p1.y, p2.x, p2.y)
            makeSubpathsFromSubpathData(pathData)
            return
        end
    
        local angle1 = math.atan2(p1.y - circleCenterY, p1.x - circleCenterX)
        local angleBendPoint = math.atan2(bendPoint.y - circleCenterY, bendPoint.x - circleCenterX)
        local angle2 = math.atan2(p2.y - circleCenterY, p2.x - circleCenterX)
        local startAngle, endAngle
    
        if isAngleBetween(angleBendPoint, angle1, angle2) then
            startAngle = angle1
            endAngle = angle2
        else
            startAngle = angle2
            endAngle = angle1
        end

        addCircleSubpathData(pathData, circleCenterX, circleCenterY, radius, startAngle, endAngle)
        makeSubpathsFromSubpathData(pathData)

        --[[
        for i = 1, pathData.tovePath.subpaths.count do
            local subpath = pathData.tovePath.subpaths[i]
            local numPoints, pointsPtr = subpath:getPoints()

            for j = 0, numPoints - 1, 3 do
                local testPoint = {
                    x = pointsPtr[2 * j + 0],
                    y = pointsPtr[2 * j + 1]
                }

                if not self:isPointInBounds(testPoint) then
                    pathData.style = 1
                    local tempBendPoint = pathData.bendPoint
                    pathData.bendPoint = nil
                    pathData.tovePath = nil
                    self:updatePathDataRendering(pathData)
                    pathData.bendPoint = tempBendPoint
                    return
                end
            end
        end]]--
    else
        if style == 1 then
            addLineSubpathData(pathData, p1.x, p1.y, p2.x, p2.y)
            makeSubpathsFromSubpathData(pathData)
            return
        end

        local isOver = style == 2

        if p1.x > p2.x or (p1.x == p2.x and p1.y > p2.y) then
            local t = p1
            p1 = p2
            p2 = t
        end

        local radius = math.min(math.abs(p2.x - p1.x), math.abs(p2.y - p1.y))
        local xIsLonger = math.abs(p2.x - p1.x) > math.abs(p2.y - p1.y)

        if radius == 0 then
            radius = math.sqrt(math.pow(p2.x - p1.x, 2.0) + math.pow(p2.y - p1.y, 2.0)) / 2.0
            local circleCenter = {
                x = (p2.x + p1.x) / 2.0,
                y = (p2.y + p1.y) / 2.0,
            }

            local startAngle

            if p1.x == p2.x then
                if isOver then
                    startAngle = math.pi * 3.0 / 2.0
                else
                    startAngle = math.pi / 2.0
                end
            else
                if isOver then
                    startAngle = math.pi
                else
                    startAngle = 0.0
                end
            end

            local testPoint = {
                x = circleCenter.x + math.cos(startAngle + math.pi / 2.0) * radius,
                y = circleCenter.y + math.sin(startAngle + math.pi / 2.0) * radius,
            }

            if not self:isPointInBounds(testPoint) then
                pathData.style = pathData.style + 1
                if pathData.style > 3 then
                    pathData.style = 1
                end

                pathData.tovePath = nil
                self:updatePathDataRendering(pathData)
                return 
            end

            addCircleSubpathData(pathData, circleCenter.x, circleCenter.y, radius, startAngle, startAngle + math.pi / 2.0)
            addCircleSubpathData(pathData, circleCenter.x, circleCenter.y, radius, startAngle + math.pi / 2.0, startAngle + math.pi)
        else
            local circleCenter = {}
            local startAngle

            if p1.y > p2.y then
                startAngle = 0.0
                if isOver then
                    startAngle = startAngle + math.pi
                end

                if xIsLonger then
                    --
                    --             .
                    -- .
                    --
                    if isOver then
                        circleCenter.x = p1.x + radius
                        circleCenter.y = p2.y + radius

                        self:drawEndOfArc(pathData, p1.x + radius, p2.y, p2.x, p2.y)
                    else
                        circleCenter.x = p2.x - radius
                        circleCenter.y = p1.y - radius

                        self:drawEndOfArc(pathData, p1.x, p1.y, p2.x - radius, p1.y)
                    end
                else
                    --
                    --   .
                    --
                    --
                    --
                    -- .
                    --
                    if isOver then
                        circleCenter.x = p1.x + radius
                        circleCenter.y = p2.y + radius

                        self:drawEndOfArc(pathData, p1.x, p1.y, p1.x, p2.y + radius)
                    else
                        circleCenter.x = p2.x - radius
                        circleCenter.y = p1.y - radius

                        self:drawEndOfArc(pathData, p2.x, p1.y - radius, p2.x, p2.y)
                    end
                end
            else
                startAngle = math.pi / 2.0
                if isOver then
                    startAngle = startAngle + math.pi
                end

                if xIsLonger then
                    --
                    -- .
                    --             .
                    --
                    if isOver then
                        circleCenter.x = p2.x - radius
                        circleCenter.y = p1.y + radius

                        self:drawEndOfArc(pathData, p1.x, p1.y, p2.x - radius, p1.y)
                    else
                        circleCenter.x = p1.x + radius
                        circleCenter.y = p2.y - radius

                        self:drawEndOfArc(pathData, p1.x + radius, p2.y, p2.x, p2.y)
                    end
                else
                    --
                    -- .
                    --
                    --
                    --
                    --   .
                    --
                    if isOver then
                        circleCenter.x = p2.x - radius
                        circleCenter.y = p1.y + radius

                        self:drawEndOfArc(pathData, p2.x, p1.y + radius, p2.x, p2.y)
                    else
                        circleCenter.x = p1.x + radius
                        circleCenter.y = p2.y - radius

                        self:drawEndOfArc(pathData, p1.x, p1.y, p1.x, p2.y - radius)
                    end
                end
            end

            addCircleSubpathData(pathData, circleCenter.x, circleCenter.y, radius, startAngle, startAngle + math.pi / 2.0)
        end
    end

    makeSubpathsFromSubpathData(pathData)
end

function DrawData:getNextPathId()
    self.nextPathId = self.nextPathId + 1
    return self.nextPathId
end

function DrawData:updatePathDataIds(pathData)
    if not pathData.id then
        pathData.id = self:getNextPathId()
    end

    for i = 1, #pathData.subpathDataList do
        pathData.subpathDataList[i].id = pathData.id .. '*' .. i
    end
end

function DrawData:cleanUpPaths()
    for i = 1, #self.pathDataList do
        self:updatePathDataRendering(self.pathDataList[i])
        self:updatePathDataIds(self.pathDataList[i])
    end
end

function DrawData:resetFill()
    self:cleanUpPaths()

    self:updatePathsCanvas()

    local pathsImageData = self.pathsCanvas:newImageData()
    self.fillImageData:updateFloodFillForNewPaths(pathsImageData)
    self.fillImage:replacePixels(self.fillImageData)
end

function DrawData:clone()
    return DrawData:new(self)
end

function DrawData:new(obj)
    if not obj or obj == nil then
        obj = {}
    end

    --print(inspect(obj))

    local newObj = {
        _graphics = nil,
        _graphicsNeedsReset = true,
        _graphicsForPathsCanvas = nil,
        _graphicsForPathsCanvasNeedsReset = true,
        pathDataList = obj.pathDataList or {},
        nextPathId = obj.nextPathId or 0,
        color = obj.color or obj.fillColor or {hexStringToRgb("f9a31b")},
        lineColor = obj.lineColor or {hexStringToRgb("f9a31b")},
        gridSize = obj.gridSize or 15,
        scale = obj.scale or DRAW_DATA_SCALE,
        pathsCanvas = nil,
        fillImageData = nil,
        fillImage = nil,
        fillCanvasSize = obj.fillCanvasSize or FILL_CANVAS_SIZE,
        fillPng = obj.fillPng or nil,
    }

    setmetatable(newObj, self)
    self.__index = self

    newObj:clearGraphics()
    newObj = util.deepCopyTable(newObj)

    setmetatable(newObj, self)
    self.__index = self

    newObj:graphics()

    if obj.fillPng then
        local fileDataString = love.data.decode("string", "base64", obj.fillPng)
        local fileData = love.filesystem.newFileData(fileDataString, "fill.png")
        newObj.fillImageData = love.image.newImageData(fileData)
    end

    return newObj
end

function DrawData:resetGraphics()
    self._graphicsNeedsReset = true
    self._graphicsForPathsCanvasNeedsReset = true
end

function DrawData:serialize()
    local data = {
        pathDataList = {},
        nextPathId = self.nextPathId,
        color = self.color,
        lineColor = self.lineColor,
        gridSize = self.gridSize,
        scale = self.scale,
        fillCanvasSize = self.fillCanvasSize,
    }

    for i = 1, #self.pathDataList do
        local pathData = self.pathDataList[i]
        table.insert(data.pathDataList, {
            points = pathData.points,
            style = pathData.style,
            bendPoint = pathData.bendPoint,
            id = pathData.id,
            isFreehand = pathData.isFreehand,
            color = pathData.color,
        })
    end

    if self.fillImageData then
        local fileData = self.fillImageData:encode("png")
        data.fillPng = love.data.encode("string", "base64", fileData:getString())
    end

    return data
end

function DrawData:floodFill(x, y)
    self:updatePathsCanvas()
    local pathsImageData = self.pathsCanvas:newImageData()
    local pixelCount = self.fillImageData:floodFill(x * self.fillCanvasSize / self.scale, y * self.fillCanvasSize / self.scale, pathsImageData, self.color[1], self.color[2], self.color[3], 1.0)
    self.fillImage:replacePixels(self.fillImageData)

    return pixelCount > 0
end

function DrawData:floodClear(x, y)
    self:updatePathsCanvas()
    local pathsImageData = self.pathsCanvas:newImageData()
    local pixelCount = self.fillImageData:floodFill(x * self.fillCanvasSize / self.scale, y * self.fillCanvasSize / self.scale, pathsImageData, 0.0, 0.0, 0.0, 0.0)
    self.fillImage:replacePixels(self.fillImageData)

    return pixelCount > 0
end

function DrawData:updatePathsCanvas()
    if self.pathsCanvas == nil then
        self.pathsCanvas = love.graphics.newCanvas(
            self.fillCanvasSize,
            self.fillCanvasSize,
            {
                dpiscale = 1,
                msaa = 4
            }
        )
    end

    self.pathsCanvas:renderTo(
        function()
            love.graphics.push("all")

            love.graphics.origin()
            love.graphics.scale(self.fillCanvasSize / self.scale)

            love.graphics.clear(0.0, 0.0, 0.0, 0.0)
            love.graphics.setColor(1.0, 1.0, 1.0, 1.0)
            self:graphicsForPathsCanvas():draw()

            love.graphics.pop()
        end
    )
end

function DrawData:renderPreviewPng(size)
    local previewCanvas = love.graphics.newCanvas(
        size,
        size,
        {
            dpiscale = 1,
            msaa = 4
        }
    )

    previewCanvas:renderTo(
        function()
            local padding = self.scale * 0.025

            love.graphics.push("all")

            love.graphics.origin()
            love.graphics.scale(size / (self.scale * 1.05))
            love.graphics.translate(padding, padding)

            love.graphics.clear(0.0, 0.0, 0.0, 0.0)
            love.graphics.setColor(1.0, 1.0, 1.0, 1.0)
            self:renderFill()
            self:graphics():draw()

            love.graphics.pop()
        end
    )

    local fileData = previewCanvas:newImageData():encode("png")
    return love.data.encode("string", "base64", fileData:getString())
end

function DrawData:render(width, height)
    if DEBUG then
        if not self.printedSize then
            print(width .. ' ' .. height)
            self.printedSize = true
        end
    end

    self:renderFill()
    self:graphics():draw()
end

function DrawData:renderFill()
    if self.fillImageData == nil then
        self.fillImageData = love.image.newImageData(self.fillCanvasSize, self.fillCanvasSize)
    end

    if self.fillImage == nil then
        self.fillImage = love.graphics.newImage(self.fillImageData)
    end

    love.graphics.draw(self.fillImage, 0.0, 0.0, 0.0, self.scale / self.fillCanvasSize, self.scale / self.fillCanvasSize)
end

function DrawData:graphics()
    if self._graphicsNeedsReset then
        self._graphicsNeedsReset = false
        self:cleanUpPaths()

        self._graphics = tove.newGraphics()
        self._graphics:setDisplay("mesh", 1024)

        for i = 1, #self.pathDataList do
            self._graphics:addPath(self.pathDataList[i].tovePath)
        end
    end
    
    return self._graphics
end

function DrawData:graphicsForPathsCanvas()
    if self._graphicsForPathsCanvasNeedsReset then
        self._graphicsForPathsCanvasNeedsReset = false
        self:cleanUpPaths()

        self._graphicsForPathsCanvas = tove.newGraphics()
        self._graphicsForPathsCanvas:setDisplay("mesh", 1024)

        for i = 1, #self.pathDataList do
            self._graphicsForPathsCanvas:addPath(self.pathDataList[i].tovePathThin)
        end
    end

    return self._graphicsForPathsCanvas
end

function DrawData:clearGraphics()
    self._graphics = nil
    self._graphicsNeedsReset = true
    self._graphicsForPathsCanvasNeedsReset = true

    for i = 1, #self.pathDataList do
        self.pathDataList[i].tovePath = nil
        self.pathDataList[i].tovePathThin = nil
        self.pathDataList[i].subpathDataList = nil
    end
end

function DrawData:updateColor(r, g, b)
    if r == self.color[1] and g == self.color[2] and b == self.color[3] then
        return false
    end

    self.color[1] = r
    self.color[2] = g
    self.color[3] = b

    return true
end

function DrawData:isPointInBounds(point)
    return point.x >= -0.001 and point.x <= self.scale and point.y >= -0.001 and point.y <= self.scale
end

function DrawData:_pointsToPaths(points)
    local paths = {}

    for i = 1, #points, 2 do
        local nextI = i + 2
        if nextI > #points then
            nextI = nextI - #points
        end

        table.insert(paths, {
            points = {
                {
                    x = points[i],
                    y = points[i + 1],
                },
                {
                    x = points[nextI],
                    y = points[nextI + 1],
                },
            },
            style = 1,
        })
    end

    return paths
end

function DrawData:getRectangleShape(p1, p2)
    if self:isPointInBounds(p1) and self:isPointInBounds(p2) and not floatEquals(p1.x, p2.x) and not floatEquals(p1.y, p2.y) then
        return self:_pointsToPaths({
            p1.x, p1.y,
            p1.x, p2.y,
            p2.x, p2.y,
            p2.x, p1.y,
        })
    else
        return nil
    end
end

function DrawData:getTriangleShape(p1, p2, p3)
    if not p3 then
        p3 = {
            x = p1.x,
            y = p2.y,
        }
    end

    local isColinear = math.abs((p2.x - p1.x) * (p3.y - p1.y) - (p3.x - p1.x) * (p2.y - p1.y)) < 0.01

    if self:isPointInBounds(p1) and self:isPointInBounds(p2) and self:isPointInBounds(p3) and isColinear == false then
        return self:_pointsToPaths({
            p1.x, p1.y,
            p2.x, p2.y,
            p3.x, p3.y,
        })
    else
        return nil
    end
end

function DrawData:getCircleShape(p1, p2, roundFn, roundDistFn, roundDx, roundDy)
    local shape = {
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

    local topPoint = {
        x = shape.x,
        y = shape.y - shape.radius,
    }
    local bottomPoint = {
        x = shape.x,
        y = shape.y + shape.radius,
    }
    local rightPoint = {
        x = shape.x + shape.radius,
        y = shape.y,
    }
    local leftPoint = {
        x = shape.x - shape.radius,
        y = shape.y,
    }

    if self:isPointInBounds(topPoint) and self:isPointInBounds(bottomPoint) and self:isPointInBounds(leftPoint) and self:isPointInBounds(rightPoint) and shape.radius > 0 then
        return {
            {
                points = {topPoint, rightPoint},
                style = 2,
            },
            {
                points = {rightPoint, bottomPoint},
                style = 3,
            },
            {
                points = {bottomPoint, leftPoint},
                style = 3,
            },
            {
                points = {leftPoint, topPoint},
                style = 2,
            },
        }
    else
        return nil
    end
end
