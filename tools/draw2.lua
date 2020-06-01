require('tools.draw_algorithms')

local DrawTool =
    defineCoreBehavior {
    name = "Draw",
    propertyNames = {},
    dependencies = {
        "Body",
        "Drawing"
    },
    tool = {
        icon = "pencil-alt",
        iconFamily = "FontAwesome5",
        needsPerformingOff = true,
        isFullScreen = true,
    }
}

local DEBUG_FLOOD_FILL = true

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

function DrawTool.handlers:addBehavior(opts)
    
end

-- Methods

local GRID_HORIZONTAL_PADDING = 0.05 * DEFAULT_VIEW_WIDTH
local GRID_TOP_PADDING = 0.2 * DEFAULT_VIEW_WIDTH
local GRID_SIZE = 15
local GRID_WIDTH = DEFAULT_VIEW_WIDTH - GRID_HORIZONTAL_PADDING * 2.0
local BACKGROUND_COLOR = {r = 0.95, g = 0.95, b = 0.95}

local pathsCanvas
local fillCanvas

function floodFill(x, y, color)
    local windowWidth, windowHeight = love.graphics.getDimensions()

    pathsCanvas:renderTo(
        function()
            love.graphics.push("all")

            love.graphics.origin()
            love.graphics.scale(windowWidth / DEFAULT_VIEW_WIDTH)

            love.graphics.clear(0, 0, 0, 0)
            love.graphics.setColor(1, 1, 1, 1)
            _graphics:draw()

            love.graphics.pop()
        end
    )

    local pathsImageData = pathsCanvas:newImageData()
    local fillImageData = fillCanvas:newImageData()

    local scale = windowWidth / DEFAULT_VIEW_WIDTH

    local ir, ig, ib, ia = fillImageData:getPixel(math.floor(x * scale), math.floor(y * scale))
    --print(ir .. ' ' .. ig .. ' ' .. ib)

    fillCanvas:renderTo(
        function()
            love.graphics.push("all")

            love.graphics.origin()
            --love.graphics.scale(windowWidth / DEFAULT_VIEW_WIDTH)

            love.graphics.setColor(color.r, color.g, color.b, 1)
            
            love.graphics.setPointSize(1.0)

            local points = {}
            local lookup = {}

            local function test(x, y)
                if lookup[x] and lookup[x][y] then
                    return false
                end

                if x < scale * GRID_HORIZONTAL_PADDING or x > scale * (GRID_HORIZONTAL_PADDING + GRID_WIDTH) then
                    return false
                end

                if y < scale * GRID_TOP_PADDING or y > scale * (GRID_TOP_PADDING + GRID_WIDTH) then
                    return false
                end

                if x < 0 or y < 0 or x >= pathsImageData:getWidth() or y >= pathsImageData:getHeight() then
                    return false
                end

                local r, g, b, a = pathsImageData:getPixel(x, y)
                if a > 0.0 then
                    return false
                end

                --r, g, b, a = fillImageData:getPixel(x, y)
                --local colorThreshold = 0.01
                --if math.abs(r - ir) > colorThreshold or math.abs(g - ig) > colorThreshold or math.abs(b - ib) > colorThreshold then
                --    return false
                --end

                return true
            end

            local function paint(x, y)
                table.insert(points, x)
                table.insert(points, y)

                if lookup[x] == nil then
                    lookup[x] = {}
                end
                lookup[x][y] = true
            end

            floodFill8Way(math.floor(x * scale), math.floor(y * scale), windowWidth, windowHeight, test, paint)

            love.graphics.points(points)

            love.graphics.pop()
        end
    )
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

_INTERSECTIONS = {}
local function resetGraphics()
    _graphics = tove.newGraphics()
    _graphics:setDisplay("mesh", 1024)
    _INTERSECTIONS = {}

    for i = 1, #_pathDataList do
        _graphics:addPath(_pathDataList[i].path)

        for j = 1, #_pathDataList[i].subpathDataList do
            local subpathData = _pathDataList[i].subpathDataList[j]

            for k = 1, i - 1 do
                for l = 1, #_pathDataList[k].subpathDataList do
                    local otherSubpathData = _pathDataList[k].subpathDataList[l]

                    local p1, p2 = subpathDataIntersection(subpathData, otherSubpathData)
                    if p1 then
                        table.insert(_INTERSECTIONS, p1)
                        table.insert(_INTERSECTIONS, p2)
                    end
                end
            end
        end
    end
end

local function resetTempGraphics()
    _tempGraphics = tove.newGraphics()
    _tempGraphics:setDisplay("mesh", 1024)
end

local function makeSubpathsFromSubpathData(pathData)
    for i = 1, #pathData.subpathDataList do
        local subpathData = pathData.subpathDataList[i]
        local subpath = tove.newSubpath()
        pathData.path:addSubpath(subpath)

        if subpathData.type == 'line' then
            subpath:moveTo(subpathData.p1.x, subpathData.p1.y)
            subpath:lineTo(subpathData.p2.x, subpathData.p2.y)
        elseif subpathData.type == 'arc' then
            subpath:arc(subpathData.center.x, subpathData.center.y, subpathData.radius, subpathData.startAngle, subpathData.endAngle)
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

    addLineSubpathData(pathData, p1x, p1y, p2x, p2y)
end

local function updatePathDataRendering(pathData)
    local path = tove.newPath()

    path:setLineColor(0.0, 0.0, 0.0, 1.0)
    path:setLineWidth(0.2)
    path:setMiterLimit(1)
    path:setLineJoin("round")
    pathData.path = path
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
        addLineSubpathData(pathData, p1.x, p1.y, p2.x, p2.y)
    else
        local circleCenter = {}
        local startAngle

        if p1.y > p2.y then
            startAngle = 0.0
            if isOver then
                startAngle = startAngle + 180.0
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
            startAngle = 90.0
            if isOver then
                startAngle = startAngle + 180.0
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

        addCircleSubpathData(pathData, circleCenter.x, circleCenter.y, radius, startAngle, startAngle + 90.0)
    end

    makeSubpathsFromSubpathData(pathData)
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
    _grabbedPaths = nil
    _initialCoord = nil
    _tempGraphics = nil
    _subtool = 'draw'

    _lineColor = {hexStringToRgb(DEFAULT_PALETTE[6])}
    _fillColor = {hexStringToRgb(DEFAULT_PALETTE[7])}

    resetGraphics()

    local windowWidth, windowHeight = love.graphics.getDimensions()
    pathsCanvas =
    love.graphics.newCanvas(
        windowWidth,
        windowHeight,
        {
            dpiscale = 1,
            msaa = 4
        }
    )
    fillCanvas =
    love.graphics.newCanvas(
        windowWidth,
        windowHeight,
        {
            dpiscale = 1,
            msaa = 4
        }
    )


    fillCanvas:renderTo(
        function()
            love.graphics.push("all")
            love.graphics.origin()
            love.graphics.clear(BACKGROUND_COLOR.r, BACKGROUND_COLOR.g, BACKGROUND_COLOR.b, 1)
            love.graphics.pop()
        end
    )
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
            updatePathDataRendering(pathData)

            if touch.released then
                addPathData(pathData)
                resetGraphics()

                _initialCoord = nil
                _tempGraphics = nil
            else
                resetTempGraphics()
                _tempGraphics:addPath(pathData.path)
            end
        elseif _subtool == 'pencil' then
            if _initialCoord == nil then
                _initialCoord = roundedCoord
                _currentDirection = nil
                _currentPathData = nil
            end

            if _initialCoord.x ~= roundedCoord.x or _initialCoord.y ~= roundedCoord.y then
                local direction = {x = roundedCoord.x - _initialCoord.x, y = roundedCoord.y - _initialCoord.y}
                local directionDist = math.sqrt(direction.x * direction.x + direction.y * direction.y)
                direction.x = direction.x / directionDist
                direction.y = direction.y / directionDist

                if _currentDirection == nil then
                    _currentDirection = direction
                elseif _currentDirection.x ~= direction.x or _currentDirection.y ~= direction.y then
                    -- new direction. end old line
                    addPathData(_currentPathData)
                    resetGraphics()

                    --print('current ' .. _currentDirection.x .. ' ' .. _currentDirection.y)
                    --print('new ' .. direction.x .. ' ' .. direction.y)

                    _initialCoord = _currentPathData.points[2]

                    direction = {x = roundedCoord.x - _initialCoord.x, y = roundedCoord.y - _initialCoord.y}
                    directionDist = math.sqrt(direction.x * direction.x + direction.y * direction.y)
                    direction.x = direction.x / directionDist
                    direction.y = direction.y / directionDist

                    _currentDirection = direction
                end
            end
                
            _currentPathData = {}
            _currentPathData.points = {_initialCoord, roundedCoord}
            _currentPathData.style = 1
            updatePathDataRendering(_currentPathData)

            if touch.released then
                addPathData(_currentPathData)
                resetGraphics()

                _initialCoord = nil
                _currentDirection = nil
                _currentPathData = nil
                _tempGraphics = nil
            else
                resetTempGraphics()
                _tempGraphics:addPath(_currentPathData.path)
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
                        local distance, t, subpath = pathData.path:nearest(touch.x, touch.y, 0.5)
                        if subpath then
                            local pointX, pointY = subpath:position(t)
                            removePathData(pathData)
                            local touchPoint = {x = touch.x, y = touch.y}

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

                if #_grabbedPaths then
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

                    resetGraphics()
                end

                _grabbedPaths = nil
                _tempGraphics = nil
            else
                resetTempGraphics()

                for i = 1, #_grabbedPaths do
                    _tempGraphics:addPath(_grabbedPaths[i].path)
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
                        updatePathDataRendering(_pathDataList[i])

                        resetGraphics()

                        break
                    end
                end
            end
        elseif _subtool == 'fill' then
            floodFill(touch.x, touch.y, {r = _fillColor[1], g = _fillColor[2], b = _fillColor[3]})
        elseif _subtool == 'erase line' then
            for i = 1, #_pathDataList do
                if _pathDataList[i].path:nearest(touch.x, touch.y, 0.5) then
                    removePathData(_pathDataList[i])
                    resetGraphics()
                    break
                end
            end
        elseif _subtool == 'erase fill' then
            floodFill(touch.x, touch.y, BACKGROUND_COLOR)
        end
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
end

-- Draw

function DrawTool.handlers:drawOverlay()
    if not self:isActive() then
        return
    end

    love.graphics.clear(BACKGROUND_COLOR.r, BACKGROUND_COLOR.g, BACKGROUND_COLOR.b)

    love.graphics.setColor(1, 1, 1, 1)
    if fillCanvas ~= nil then
        local windowWidth, windowHeight = love.graphics.getDimensions()
        love.graphics.draw(fillCanvas, 0, 0, 0, DEFAULT_VIEW_WIDTH / windowWidth, DEFAULT_VIEW_WIDTH / windowWidth)
    end

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

    love.graphics.setColor(0.0, 1.0, 0.0, 1.0)
    love.graphics.setPointSize(30.0)
    love.graphics.points(_INTERSECTIONS)
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
