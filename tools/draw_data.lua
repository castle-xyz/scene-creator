DrawData = {}

function DrawData:updateFloodFillFaceDataRendering(floodFillFaceData)
    if floodFillFaceData.tovePath and floodFillFaceData.tovePath ~= nil then
        return
    end

    local fillSubpath = tove.newSubpath()
    local fillPath = tove.newPath()
    fillPath:addSubpath(fillSubpath)
    fillPath:setFillColor(self.fillColor[1], self.fillColor[2], self.fillColor[3], 1.0)

    if DEBUG_FLOOD_FILL then
        fillPath:setLineColor(1.0, 0.0, 0.0, 1.0)
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

local function drawEndOfArc(pathData, p1x, p1y, p2x, p2y)
    if p1x == p2x and p1y == p2y then
        return
    end

    -- TODO: fix
    p1x, p1y = roundGlobalCoordinatesToGrid(p1x, p1y)
    p2x, p2y = roundGlobalCoordinatesToGrid(p2x, p2y)

    addLineSubpathData(pathData, p1x, p1y, p2x, p2y)
end

function updatePathDataRendering(pathData)
    if pathData.tovePath and pathData.tovePath ~= nil then
        return
    end

    local path = tove.newPath()

    path:setLineColor(0.0, 0.0, 0.0, 1.0)
    path:setLineWidth(0.2)
    path:setMiterLimit(1)
    path:setLineJoin("round")
    pathData.tovePath = path
    pathData.subpathDataList = {}

    local p1 = pathData.points[1]
    local p2 = pathData.points[2]
    local style = pathData.style

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

                    drawEndOfArc(pathData, p1.x + radius, p2.y, p2.x, p2.y)
                else
                    circleCenter.x = p2.x - radius
                    circleCenter.y = p1.y - radius

                    drawEndOfArc(pathData, p1.x, p1.y, p2.x - radius, p1.y)
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

                    drawEndOfArc(pathData, p1.x, p1.y, p1.x, p2.y + radius)
                else
                    circleCenter.x = p2.x - radius
                    circleCenter.y = p1.y - radius

                    drawEndOfArc(pathData, p2.x, p1.y - radius, p2.x, p2.y)
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

                    drawEndOfArc(pathData, p1.x, p1.y, p2.x - radius, p1.y)
                else
                    circleCenter.x = p1.x + radius
                    circleCenter.y = p2.y - radius

                    drawEndOfArc(pathData, p1.x + radius, p2.y, p2.x, p2.y)
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

                    drawEndOfArc(pathData, p2.x, p1.y + radius, p2.x, p2.y)
                else
                    circleCenter.x = p1.x + radius
                    circleCenter.y = p2.y - radius

                    drawEndOfArc(pathData, p1.x, p1.y, p1.x, p2.y - radius)
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
        updatePathDataRendering(self.pathDataList[i])
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
    colorAllSlabs(_SLABS, self.pathDataList, GRID_TOP_PADDING, GRID_TOP_PADDING + GRID_SIZE, self.floodFillColoredSubpathIds, newFaces, newColoredSubpathIds, GRID_WIDTH / GRID_SIZE)
    self.floodFillFaceDataList = newFaces

    self.floodFillColoredSubpathIds = {}
    for i = 1, #newColoredSubpathIds do
        self.floodFillColoredSubpathIds[newColoredSubpathIds[i]] = true
    end
end

function DrawData:new(obj)
    if not obj or obj == nil then
        obj = {}
    end

    --print(inspect(obj))

    local newObj = {
        _graphics = nil,
        _graphicsNeedsReset = true,
        pathDataList = obj.pathDataList or {},
        floodFillFaceDataList = obj.floodFillFaceDataList or {},
        floodFillColoredSubpathIds = obj.floodFillColoredSubpathIds or {},
        nextPathId = obj.nextPathId or 0,
        fillColor = obj.fillColor or {hexStringToRgb(DEFAULT_PALETTE[7])},
    }

    setmetatable(newObj, self)
    self.__index = self

    return newObj
end

function DrawData:resetGraphics()
    self._graphicsNeedsReset = true
end

function DrawData:serialize()
    local data = {
        pathDataList = {},
        floodFillFaceDataList = {},
        floodFillColoredSubpathIds = self.floodFillColoredSubpathIds,
        nextPathId = self.nextPathId,
        fillColor = self.fillColor,
    }

    for i = 1, #self.pathDataList do
        local pathData = self.pathDataList[i]
        table.insert(data.pathDataList, {
            points = pathData.points,
            style = pathData.style,
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

    return data
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
                self._graphics:addPath(self.floodFillFaceDataList[i].tovePath)
            end
        end

        for i = 1, #self.pathDataList do
            self._graphics:addPath(self.pathDataList[i].tovePath)
        end

        if DEBUG_FLOOD_FILL then
            for i = 1, #self.floodFillFaceDataList do
                self._graphics:addPath(self.floodFillFaceDataList[i].tovePath)
            end
        end
    end
    
    return self._graphics
end
