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

function DrawData:roundGlobalDistanceToGrid(d)
    local x, y = self:roundGlobalCoordinatesToGrid(d, 0)
    return x
end

function DrawData:updateFloodFillFaceDataRendering(floodFillFaceData)
    if floodFillFaceData.tovePath and floodFillFaceData.tovePath ~= nil then
        return
    end

    local fillSubpath = tove.newSubpath()
    local fillPath = tove.newPath()
    fillPath:addSubpath(fillSubpath)
    fillPath:setFillColor(self.fillColor[1], self.fillColor[2], self.fillColor[3], 1.0)

    if DEBUG_FLOOD_FILL then
        fillPath:setLineColor(1.0, 0.0, 1.0, 1.0)
        fillPath:setLineWidth(0.02)
        fillPath:setMiterLimit(1)
        fillPath:setLineJoin("round")
    end

    floodFillFaceData.tovePath = fillPath

    if #floodFillFaceData.points < 3 then
        return
    end

    fillSubpath:moveTo(floodFillFaceData.points[1].x, floodFillFaceData.points[1].y)

    for i = 2, #floodFillFaceData.points do
        fillSubpath:lineTo(floodFillFaceData.points[i].x, floodFillFaceData.points[i].y)
    end

    fillSubpath.isClosed = true
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
    path:setLineColor(self.lineColor[1], self.lineColor[2], self.lineColor[3], 1.0)
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

    --[[
    local bendPoint = pathData.bendPoint

    if not bendPoint or bendPoint == nil then
        addLineSubpathData(pathData, p1.x, p1.y, p2.x, p2.y)
        makeSubpathsFromSubpathData(pathData)
        return
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

    if isAngleBetween(angleBendPoint, angle1, angle2) then
        addCircleSubpathData(pathData, circleCenterX, circleCenterY, radius, angle1, angle2)
    else
        addCircleSubpathData(pathData, circleCenterX, circleCenterY, radius, angle2, angle1)
    end
    ]]--

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

function DrawData:cleanUpPathsAndFaces()
    for i = 1, #self.floodFillFaceDataList do
        self:updateFloodFillFaceDataRendering(self.floodFillFaceDataList[i])
    end

    for i = 1, #self.pathDataList do
        self:updatePathDataRendering(self.pathDataList[i])
        self:updatePathDataIds(self.pathDataList[i])
    end
end

function DrawData:resetFill()
    self:cleanUpPathsAndFaces()
    _SLABS = findAllSlabs(self.pathDataList)

    _FACE_POINTS = {}
    local facesToColor = {}

    local newFaces = {}
    local newColoredSubpathIds = {}
    colorAllSlabs(_SLABS, self.pathDataList, 0, self.gridSize, self.floodFillColoredSubpathIds, newFaces, newColoredSubpathIds, self.scale / self.gridSize)
    self.floodFillFaceDataList = newFaces

    self.floodFillColoredSubpathIds = {}
    for i = 1, #newColoredSubpathIds do
        self.floodFillColoredSubpathIds[newColoredSubpathIds[i]] = true
    end
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
        floodFillFaceDataList = obj.floodFillFaceDataList or {},
        floodFillColoredSubpathIds = obj.floodFillColoredSubpathIds or {},
        nextPathId = obj.nextPathId or 0,
        fillColor = obj.fillColor or {hexStringToRgb(DEFAULT_PALETTE[7])},
        lineColor = obj.lineColor or {hexStringToRgb("a866ee")},
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
        floodFillFaceDataList = {},
        floodFillColoredSubpathIds = self.floodFillColoredSubpathIds,
        nextPathId = self.nextPathId,
        fillColor = self.fillColor,
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
        })
    end

    for i = 1, #self.floodFillFaceDataList do
        local floodFillFaceData = self.floodFillFaceDataList[i]
        table.insert(data.floodFillFaceDataList, {
            points = floodFillFaceData.points,
            id = floodFillFaceData.id,
        })
    end

    if self.fillImageData then
        local fileData = self.fillImageData:encode("png")
        data.fillPng = love.data.encode("string", "base64", fileData:getString())
    end

    return data
end

function DrawData:fill(x, y)
    local pathsImageData = self.pathsCanvas:newImageData()
    self.fillImageData:floodFill(x * self.fillCanvasSize / self.scale, y * self.fillCanvasSize / self.scale, pathsImageData, self.fillColor[1], self.fillColor[2], self.fillColor[3], 1.0)
    self.fillImage:replacePixels(self.fillImageData)
end

function DrawData:renderFill()
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

    if self.fillImageData == nil then
        self.fillImageData = love.image.newImageData(self.fillCanvasSize, self.fillCanvasSize)
    end

    if self.fillImage == nil then
        self.fillImage = love.graphics.newImage(self.fillImageData)
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

    love.graphics.draw(self.fillImage, 0.0, 0.0, 0.0, self.scale / self.fillCanvasSize, self.scale / self.fillCanvasSize)
end

function DrawData:graphics()
    if self._graphicsNeedsReset then
        self._graphicsNeedsReset = false
        self:cleanUpPathsAndFaces()

        self._graphics = tove.newGraphics()
        self._graphics:setDisplay("mesh", 1024)
        _SLABS = findAllSlabs(self.pathDataList)

        if not DEBUG_FLOOD_FILL then
            for i = 1, #self.floodFillFaceDataList do
                --self._graphics:addPath(self.floodFillFaceDataList[i].tovePath)
            end
        end

        for i = 1, #self.pathDataList do
            self._graphics:addPath(self.pathDataList[i].tovePath)
        end

        if DEBUG_FLOOD_FILL then
            for i = 1, #self.floodFillFaceDataList do
                --self._graphics:addPath(self.floodFillFaceDataList[i].tovePath)
            end
        end
    end
    
    return self._graphics
end

function DrawData:graphicsForPathsCanvas()
    if self._graphicsForPathsCanvasNeedsReset then
        self._graphicsForPathsCanvasNeedsReset = false
        self:cleanUpPathsAndFaces()

        self._graphicsForPathsCanvas = tove.newGraphics()
        self._graphicsForPathsCanvas:setDisplay("mesh", 1024)
        _SLABS = findAllSlabs(self.pathDataList)

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

    for i = 1, #self.floodFillFaceDataList do
        self.floodFillFaceDataList[i].tovePath = nil
    end
end

function DrawData:updateFillColor(r, g, b)
    if r == self.fillColor[1] and g == self.fillColor[2] and b == self.fillColor[3] then
        return false
    end

    self.fillColor[1] = r
    self.fillColor[2] = g
    self.fillColor[3] = b

    self:clearGraphics()
    return true
end

function DrawData:updateLineColor(r, g, b)
    if r == self.lineColor[1] and g == self.lineColor[2] and b == self.lineColor[3] then
        return false
    end

    self.lineColor[1] = r
    self.lineColor[2] = g
    self.lineColor[3] = b

    self:clearGraphics()
    return true
end
