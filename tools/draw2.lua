require('tools.draw_algorithms')

local DrawTool =
    defineCoreBehavior {
    name = "Draw",
    propertyNames = {},
    dependencies = {
        "Body",
        "Drawing2"
    },
    tool = {
        icon = "pencil-alt",
        iconFamily = "FontAwesome5",
        needsPerformingOff = true,
        isFullScreen = true,
    }
}

--[[

tove's coordinate system for angles looks like this

             270


180 deg      (0,0)     0 deg


             90 deg

we use the same system but in radians

]]--


-- TODO: don't allow completely overlapping lines

DEBUG_FLOOD_FILL = false
ONLY_RESET_FLOOD_FILL_ON_RELEASE = false

-- Behavior management

local _pathDataList
local _initialCoord
local _currentPathData
local _graphics

local _tempGraphics
local _subtool
local _grabbedPaths

local _lineColor
local _fillColor

local _floodFillFaceDataList
local _floodFillColoredSubpathIds
local _nextPathId = 0

function DrawTool.handlers:addBehavior(opts)
    
end

-- Methods

local GRID_HORIZONTAL_PADDING = 0.05 * DEFAULT_VIEW_WIDTH
local GRID_TOP_PADDING = 0.1 * DEFAULT_VIEW_WIDTH
local GRID_SIZE = 15
local GRID_WIDTH = DEFAULT_VIEW_WIDTH - GRID_HORIZONTAL_PADDING * 2.0
local BACKGROUND_COLOR = {r = 0.95, g = 0.95, b = 0.95}

function nextPathId()
    _nextPathId = _nextPathId + 1
    return _nextPathId
end


local function globalToGridCoordinates(x, y)
    local gridX = 1.0 + (GRID_SIZE - 1) * (x - GRID_HORIZONTAL_PADDING) / GRID_WIDTH
    local gridY = 1.0 + (GRID_SIZE - 1) * (y - GRID_TOP_PADDING) / GRID_WIDTH
    return gridX, gridY
end

local function gridToGlobalCoordinates(x, y)
    local globalX = GRID_HORIZONTAL_PADDING + ((x - 1.0) * GRID_WIDTH / (GRID_SIZE - 1))
    local globalY = GRID_TOP_PADDING + ((y - 1.0) * GRID_WIDTH / (GRID_SIZE - 1))
    return globalX, globalY
end

local function roundGlobalCoordinatesToGrid(x, y)
    local gridX, gridY = globalToGridCoordinates(x, y)

    gridX = math.floor(gridX + 0.5)
    gridY = math.floor(gridY + 0.5)

    if gridX <= 0 then
        gridX = 1
    elseif gridX > GRID_SIZE then
        gridX = GRID_SIZE
    end

    if gridY <= 0 then
        gridY = 1
    elseif gridY > GRID_SIZE then
        gridY = GRID_SIZE
    end

    return gridToGlobalCoordinates(gridX, gridY)
end

local function updatePathDataIds(pathData)
    if not pathData.id then
        pathData.id = nextPathId()
    end

    for i = 1, #pathData.subpathDataList do
        pathData.subpathDataList[i].id = pathData.id .. '*' .. i
    end
end

local function addPathData(pathData)
    if pathData.points[1].x ~= pathData.points[2].x or pathData.points[1].y ~= pathData.points[2].y then
        table.insert(_pathDataList, pathData)
    end
end

local function removePathData(pathData)
    for i = #_pathDataList, 1, -1 do
        if _pathDataList[i] == pathData then
            table.remove(_pathDataList, i)
        end
    end
end

_SLABS = {}

local function resetTempGraphics()
    _tempGraphics = tove.newGraphics()
    _tempGraphics:setDisplay("mesh", 1024)
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

    p1x, p1y = roundGlobalCoordinatesToGrid(p1x, p1y)
    p2x, p2y = roundGlobalCoordinatesToGrid(p2x, p2y)

    addLineSubpathData(pathData, p1x, p1y, p2x, p2y)
end

local function updateFloodFillFaceDataRendering(floodFillFaceData)
    if floodFillFaceData.tovePath and floodFillFaceData.tovePath ~= nil then
        return
    end

    local fillSubpath = tove.newSubpath()
    local fillPath = tove.newPath()
    fillPath:addSubpath(fillSubpath)
    fillPath:setFillColor(_fillColor[1], _fillColor[2], _fillColor[3], 1.0)

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

local function updatePathDataRendering(pathData)
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

local function cleanUpPathsAndFaces()
    for i = 1, #_floodFillFaceDataList do
        updateFloodFillFaceDataRendering(_floodFillFaceDataList[i])
    end

    for i = 1, #_pathDataList do
        updatePathDataRendering(_pathDataList[i])
        updatePathDataIds(_pathDataList[i])
    end
end

local function resetFill()
    cleanUpPathsAndFaces()
    _SLABS = findAllSlabs(_pathDataList)

    _FACE_POINTS = {}
    local facesToColor = {}

    local newFaces = {}
    local newColoredSubpathIds = {}
    colorAllSlabs(_SLABS, _pathDataList, GRID_TOP_PADDING, GRID_TOP_PADDING + GRID_SIZE, _floodFillColoredSubpathIds, newFaces, newColoredSubpathIds, GRID_WIDTH / GRID_SIZE)
    _floodFillFaceDataList = newFaces

    _floodFillColoredSubpathIds = {}
    for i = 1, #newColoredSubpathIds do
        _floodFillColoredSubpathIds[newColoredSubpathIds[i]] = true
    end
end

local function resetGraphics()
    cleanUpPathsAndFaces()

    _graphics = tove.newGraphics()
    _graphics:setDisplay("mesh", 1024)
    _SLABS = findAllSlabs(_pathDataList)

    if not DEBUG_FLOOD_FILL then
        for i = 1, #_floodFillFaceDataList do
            _graphics:addPath(_floodFillFaceDataList[i].tovePath)
        end
    end

    for i = 1, #_pathDataList do
        _graphics:addPath(_pathDataList[i].tovePath)
    end

    if DEBUG_FLOOD_FILL then
        for i = 1, #_floodFillFaceDataList do
            _graphics:addPath(_floodFillFaceDataList[i].tovePath)
        end
    end
end

function serializeData()
    local data = {
        pathDataList = {},
        floodFillFaceDataList = {},
        floodFillColoredSubpathIds = _floodFillColoredSubpathIds,
        nextPathId = _nextPathId,
    }

    for i = 1, #_pathDataList do
        local pathData = _pathDataList[i]
        table.insert(data.pathDataList, {
            points = pathData.points,
            style = pathData.style,
            id = pathData.id,
        })
    end

    for i = 1, #_floodFillFaceDataList do
        local floodFillFaceData = _floodFillFaceDataList[i]
        table.insert(data.floodFillFaceDataList, {
            points = floodFillFaceData.points,
            id = floodFillFaceData.id,
        })
    end

    print(inspect(data))

    return data
end

function deserializeData(data)
    _pathDataList = {}
    _floodFillFaceDataList = {}
    _floodFillColoredSubpathIds = {}
    _nextPathId = 0

    if data.pathDataList then
        for i = 1, #data.pathDataList do
            local pathData = data.pathDataList[i]
            table.insert(_pathDataList, pathData)
        end
    end

    if data.floodFillFaceDataList then
        for i = 1, #data.floodFillFaceDataList do
            local floodFillFaceData = data.floodFillFaceDataList[i]
            table.insert(_floodFillFaceDataList, floodFillFaceData)
        end
    end

    if data.floodFillColoredSubpathIds then
        _floodFillColoredSubpathIds = data.floodFillColoredSubpathIds
    end

    if data.nextPathId then
        _nextPathId = data.nextPathId
    end
end

function DrawTool:saveDrawing(commandDescription, c)
    local actorId = c.actorId
    local newData = self.dependencies.Drawing2:serialize(GRID_WIDTH, _graphics, serializeData())
    c._lastData = newData -- Prevent reloading since we're already in sync
    local oldData = self.dependencies.Drawing2:get(actorId).properties.data
    self.dependencies.Drawing2:command(
        commandDescription,
        {
            params = {"oldData", "newData"}
        },
        function()
            self:sendSetProperties(actorId, "data", newData)
        end,
        function()
            self:sendSetProperties(actorId, "data", oldData)
        end
    )
end

function DrawTool:getSingleComponent()
    local singleComponent
    for actorId, component in pairs(self.components) do
        if self.game.clientId == component.clientId then
            if singleComponent then
                return nil
            end
            singleComponent = component
        end
    end
    return singleComponent
end

-- Update

function DrawTool.handlers:onSetActive()
    _pathDataList = {}
    _floodFillFaceDataList = {}
    _floodFillColoredSubpathIds = {}
    _grabbedPaths = nil
    _initialCoord = nil
    _tempGraphics = nil
    _subtool = 'pencil'

    _lineColor = {hexStringToRgb(DEFAULT_PALETTE[6])}
    _fillColor = {hexStringToRgb(DEFAULT_PALETTE[7])}

    resetGraphics()
end

function DrawTool.handlers:preUpdate(dt)
    if not self:isActive() then
        return
    end

    -- Steal all touches
    local touchData = self:getTouchData()
    for touchId, touch in pairs(touchData.touches) do
        touch.used = true
    end
end

function DrawTool.handlers:update(dt)
    if not self:isActive() then
        return
    end

    -- Make sure we have exactly one actor active
    local c = self:getSingleComponent()
    if not c then
        return
    end

    local drawingComponent = self.dependencies.Drawing2:get(c.actorId)
    if c._lastData ~= drawingComponent.properties.data then
        local cacheEntry = self.dependencies.Drawing2:cacheDrawing(drawingComponent.properties.data)
        if not cacheEntry then
            return
        end

        c._lastData = drawingComponent.properties.data
        deserializeData(cacheEntry.data)
        resetGraphics()
    end


    local touchData = self:getTouchData()
    if touchData.numTouches == 1 and touchData.maxNumTouches == 1 then
        -- Get the single touch
        local touchId, touch = next(touchData.touches)
        local roundedX, roundedY = roundGlobalCoordinatesToGrid(touch.x, touch.y)
        local roundedCoord = {x = roundedX, y = roundedY}

        if _subtool == 'draw' then
            if _initialCoord == nil then
                _initialCoord = roundedCoord
            end

            local pathData = {}
            pathData.points = {_initialCoord, roundedCoord}
            pathData.style = 1

            if touch.released then
                addPathData(pathData)
                resetFill()
                resetGraphics()
                self:saveDrawing("line", c)

                _initialCoord = nil
                _tempGraphics = nil
            else
                resetTempGraphics()
                updatePathDataRendering(pathData)
                _tempGraphics:addPath(pathData.tovePath)
            end
        elseif _subtool == 'pencil' then
            if _initialCoord == nil then
                _initialCoord = roundedCoord
                _currentPathData = nil
                _currentPathDataList = {}
            end

            local angle = math.atan2(touch.y - _initialCoord.y, touch.x - _initialCoord.x)
            if angle < 0.0 then
                angle = angle + math.pi * 2.0
            end
            local angleRoundedTo8Directions = math.floor((angle + (math.pi * 2.0) / (8.0 * 2.0)) * 8.0 / (math.pi * 2.0))
            if angleRoundedTo8Directions > 7 then
                angleRoundedTo8Directions = 0
            end
            local distFromOriginalPoint = math.sqrt(math.pow(touch.x - _initialCoord.x, 2.0) + math.pow(touch.y - _initialCoord.y, 2.0))
            local newAngle = (angleRoundedTo8Directions * (math.pi * 2.0) / 8.0)
            local direction = {x = math.cos(newAngle), y = math.sin(newAngle)}

            local cellSize = GRID_WIDTH / GRID_SIZE

            if distFromOriginalPoint > cellSize then
                if _currentPathData ~= nil and (_currentPathData.points[1].x ~= _currentPathData.points[2].x or _currentPathData.points[1].y ~= _currentPathData.points[2].y) then
                    table.insert(_currentPathDataList, _currentPathData)

                    _initialCoord = _currentPathData.points[2]
                end
            end

            distFromOriginalPoint = math.sqrt(math.pow(touch.x - _initialCoord.x, 2.0) + math.pow(touch.y - _initialCoord.y, 2.0)) - cellSize * 0.5
            local newRoundedX, newRoundedY = roundGlobalCoordinatesToGrid(_initialCoord.x + direction.x * distFromOriginalPoint, _initialCoord.y + direction.y * distFromOriginalPoint)
                
            _currentPathData = {}
            _currentPathData.points = {_initialCoord, {
                x = newRoundedX,
                y = newRoundedY,
            }}
            _currentPathData.style = 1
            updatePathDataRendering(_currentPathData)

            if touch.released then
                if _currentPathData ~= nil and (_currentPathData.points[1].x ~= _currentPathData.points[2].x or _currentPathData.points[1].y ~= _currentPathData.points[2].y) then
                    table.insert(_currentPathDataList, _currentPathData)
                end

                local newPathDataList = simplifyPathDataList(_currentPathDataList)

                for i = 1, #newPathDataList do
                    newPathDataList[i].tovePath = nil
                    addPathData(newPathDataList[i])
                end
                resetFill()
                resetGraphics()
                self:saveDrawing("pencil", c)

                _initialCoord = nil
                _currentPathData = nil
                _currentPathDataList = {}
                _tempGraphics = nil
            else
                resetTempGraphics()
                for i = 1, #_currentPathDataList do
                    _tempGraphics:addPath(_currentPathDataList[i].tovePath)
                end
                _tempGraphics:addPath(_currentPathData.tovePath)
            end
        elseif _subtool == 'move' then
            if _grabbedPaths == nil then
                _grabbedPaths = {}

                for i = 1, #_pathDataList do
                    for p = 1, 2 do
                        if roundedX == _pathDataList[i].points[p].x and roundedY == _pathDataList[i].points[p].y then
                            _pathDataList[i].grabPointIndex = p
                            table.insert(_grabbedPaths, _pathDataList[i])
                            break
                        end
                    end
                end

                for i = 1, #_grabbedPaths do
                    removePathData(_grabbedPaths[i])
                end

                if #_grabbedPaths == 0 then
                    for i = 1, #_pathDataList do
                        local pathData = _pathDataList[i]
                        local distance, t, subpath = pathData.tovePath:nearest(touch.x, touch.y, 0.5)
                        if subpath then
                            local pointX, pointY = subpath:position(t)
                            removePathData(pathData)
                            local touchPoint = {x = touch.x, y = touch.y}

                            -- todo: figure out path ids here
                            local newPathData1 = {
                                points = {
                                    pathData.points[1],
                                    touchPoint
                                },
                                style = pathData.style,
                                grabPointIndex = 2
                            }

                            local newPathData2 = {
                                points = {
                                    touchPoint,
                                    pathData.points[2]
                                },
                                style = pathData.style,
                                grabPointIndex = 1
                            }

                            table.insert(_grabbedPaths, newPathData1)
                            table.insert(_grabbedPaths, newPathData2)

                            break
                        end
                    end
                end

                if #_grabbedPaths > 0 then
                    resetGraphics()
                end
            end

            for i = 1, #_grabbedPaths do
                _grabbedPaths[i].points[_grabbedPaths[i].grabPointIndex].x = roundedX
                _grabbedPaths[i].points[_grabbedPaths[i].grabPointIndex].y = roundedY

                updatePathDataRendering(_grabbedPaths[i])
            end

            if touch.released then
                if _grabbedPaths and #_grabbedPaths > 0 then
                    for i = 1, #_grabbedPaths do
                        addPathData(_grabbedPaths[i])
                    end

                    resetFill()
                    resetGraphics()
                    self:saveDrawing("move", c)
                end

                _grabbedPaths = nil
                _tempGraphics = nil
            else
                resetTempGraphics()

                for i = 1, #_grabbedPaths do
                    _tempGraphics:addPath(_grabbedPaths[i].tovePath)
                end
            end
        elseif _subtool == 'bend' then
            if touch.released then
                for i = 1, #_pathDataList do
                    if _pathDataList[i].path:nearest(touch.x, touch.y, 0.5) then
                        _pathDataList[i].style = _pathDataList[i].style + 1
                        if _pathDataList[i].style > 3 then
                            _pathDataList[i].style = 1
                        end
                        _pathDataList[i].tovePath = nil -- reset rendering

                        resetFill()
                        resetGraphics()
                        self:saveDrawing("bend", c)

                        break
                    end
                end
            end
        elseif _subtool == 'fill' then
------ create set of all verices added for an entire flood fill and use that as the key. check for the same 3 verteces in a row


            _FACE_POINTS = {}
            local newFaces = {}
            local newColoredSubpathIds = {}
            local currentFaces = {}

            for i = 1, #_floodFillFaceDataList do
                currentFaces[_floodFillFaceDataList[i].id] = true
            end

            findFaceForPoint(_SLABS, _pathDataList, GRID_TOP_PADDING, GRID_TOP_PADDING + GRID_SIZE, {
                x = touch.x,
                y = touch.y
            }, newFaces, newColoredSubpathIds, currentFaces, GRID_WIDTH / GRID_SIZE)

            for i = 1, #newFaces do
                table.insert(_floodFillFaceDataList, newFaces[i])
            end

            for i = 1, #newColoredSubpathIds do
                _floodFillColoredSubpathIds[newColoredSubpathIds[i]] = true
            end

            resetGraphics()
            self:saveDrawing("fill", c)
        elseif _subtool == 'erase line' then
            for i = 1, #_pathDataList do
                if _pathDataList[i].path:nearest(touch.x, touch.y, 0.5) then
                    removePathData(_pathDataList[i])
                    resetFill()
                    resetGraphics()
                    self:saveDrawing("erase line", c)
                    break
                end
            end
        elseif _subtool == 'erase fill' then
            _FACE_POINTS = {}
            local newFaces = {}
            local newColoredSubpathIds = {}
            local currentFaces = {}

            findFaceForPoint(_SLABS, _pathDataList, GRID_TOP_PADDING, GRID_TOP_PADDING + GRID_SIZE, {
                x = touch.x,
                y = touch.y
            }, newFaces, newColoredSubpathIds, currentFaces, GRID_WIDTH / GRID_SIZE)

            for i = 1, #newFaces do
                for j = #_floodFillFaceDataList, 1, -1 do
                    if _floodFillFaceDataList[j].id == newFaces[i].id then
                        table.remove(_floodFillFaceDataList, j)
                    end
                end
            end

            for i = 1, #newColoredSubpathIds do
                _floodFillColoredSubpathIds[newColoredSubpathIds[i]] = nil
            end

            resetGraphics()
            self:saveDrawing("erase fill", c)
        end
    end
end

-- Draw

function DrawTool.handlers:drawOverlay()
    if not self:isActive() then
        return
    end

    love.graphics.clear(BACKGROUND_COLOR.r, BACKGROUND_COLOR.g, BACKGROUND_COLOR.b)

    love.graphics.setColor(1, 1, 1, 1)

    if _subtool == 'draw' or _subtool == 'pencil' or _subtool == 'move' then
        love.graphics.setColor(0.5, 0.5, 0.5, 1.0)
        love.graphics.setPointSize(10.0)

        local points = {}

        for x = 1, GRID_SIZE do
            for y = 1, GRID_SIZE do
                local globalX, globalY = gridToGlobalCoordinates(x, y)
                table.insert(points, globalX)
                table.insert(points, globalY)
            end
        end

        love.graphics.points(points)
    end

    love.graphics.setColor(1, 1, 1, 1)

    _graphics:draw()

    if _tempGraphics ~= nil then
        _tempGraphics:draw()
    end

    if _subtool == "move" then
        local movePoints = {}

        for i = 1, #_pathDataList do
            for p = 1, 2 do
                table.insert(movePoints, _pathDataList[i].points[p].x)
                table.insert(movePoints, _pathDataList[i].points[p].y)
            end
        end

        love.graphics.setColor(1.0, 0.6, 0.6, 1.0)
        love.graphics.setPointSize(30.0)
        love.graphics.points(movePoints)
    end

    if DEBUG_FLOOD_FILL then
        love.graphics.setColor(0.0, 1.0, 0.0, 1.0)
        love.graphics.setLineWidth(0.1)
        local slabPoints = {}
        for i = 1, #_SLABS do
            love.graphics.line(_SLABS[i].x, GRID_TOP_PADDING, _SLABS[i].x, GRID_TOP_PADDING + GRID_SIZE)
            for j = 1, #_SLABS[i].points do
                table.insert(slabPoints, _SLABS[i].x)
                table.insert(slabPoints, _SLABS[i].points[j].y)
            end
        end

        love.graphics.setColor(0.0, 0.0, 1.0, 1.0)
        love.graphics.setPointSize(20.0)
        love.graphics.points(slabPoints)

        love.graphics.setColor(1.0, 0.0, 0.0, 1.0)
        love.graphics.setPointSize(30.0)
        love.graphics.points(_FACE_POINTS)
    end
end

-- UI

function DrawTool.handlers:uiPanel()
    if not self:isActive() then
        return
    end

    local c = self:getSingleComponent()
    if not c then
        return
    end

    ui.box(
        "draw row",
        {flexDirection = "row"},
        function()

            ui.toggle(
                "pencil",
                "pencil",
                _subtool == 'pencil',
                {
                    onToggle = function(newlineEnabled)
                        _subtool = 'pencil'
                    end
                }
            )

            ui.toggle(
                "line",
                "line",
                _subtool == 'draw',
                {
                    onToggle = function(newlineEnabled)
                        _subtool = 'draw'
                    end
                }
            )

            ui.toggle(
                "move",
                "move",
                _subtool == 'move',
                {
                    onToggle = function(newlineEnabled)
                        _subtool = 'move'
                    end
                }
            )

            ui.toggle(
                "bend",
                "bend",
                _subtool == 'bend',
                {
                    onToggle = function(newlineEnabled)
                        _subtool = 'bend'
                    end
                }
            )

            ui.toggle(
                "fill",
                "fill",
                _subtool == 'fill',
                {
                    onToggle = function(newlineEnabled)
                        _subtool = 'fill'
                    end
                }
            )
        end
    )


    ui.box(
        "erase row",
        {flexDirection = "row"},
        function()
            ui.toggle(
                "erase line",
                "erase line",
                _subtool == 'erase line',
                {
                    onToggle = function(newlineEnabled)
                        _subtool = 'erase line'
                    end
                }
            )

            ui.toggle(
                "erase fill",
                "erase fill",
                _subtool == 'erase fill',
                {
                    onToggle = function(newlineEnabled)
                        _subtool = 'erase fill'
                    end
                }
            )
        end
    )

    ui.box(
        "fill color box",
        {
            flex = 1,
            alignItems = "flex-start",
            justifyContent = "flex-end"
        },
        function()
            _fillColor[1], _fillColor[2], _fillColor[3] =
                uiPalette(_fillColor[1], _fillColor[2], _fillColor[3])
        end
    )

    ui.box(
        "grid size box",
        {
            flex = 1,
            justifyContent = "flex-end"
        },
        function()
            GRID_SIZE =
                ui.numberInput(
                "grid size",
                GRID_SIZE,
                {
                    hideLabel = false,
                    min = 3,
                    max = 25,
                    step = 1
                }
            )
        end
    )
end

function DrawTool.handlers:contentHeight()
    local windowWidth, windowHeight = love.graphics.getDimensions()
    return windowHeight * 0.2
end
