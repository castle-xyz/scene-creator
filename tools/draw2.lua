
GRID_HORIZONTAL_PADDING = 0--0.05 * DEFAULT_VIEW_WIDTH
GRID_TOP_PADDING = 0--0.1 * DEFAULT_VIEW_WIDTH
GRID_SIZE = 15
GRID_WIDTH = DEFAULT_VIEW_WIDTH - GRID_HORIZONTAL_PADDING * 2.0
BACKGROUND_COLOR = {r = 0.95, g = 0.95, b = 0.95}

require('tools.draw_algorithms')
require('tools.draw_data')

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


-- Behavior management

local _drawData

local _initialCoord
local _currentPathData

local _tempGraphics
local _subtool
local _grabbedPaths

function DrawTool.handlers:addBehavior(opts)
    
end

-- Methods



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
        table.insert(_drawData.pathDataList, pathData)
    end
end

local function removePathData(pathData)
    for i = #_drawData.pathDataList, 1, -1 do
        if _drawData.pathDataList[i] == pathData then
            table.remove(_drawData.pathDataList, i)
        end
    end
end

_SLABS = {}

local function resetTempGraphics()
    _tempGraphics = tove.newGraphics()
    _tempGraphics:setDisplay("mesh", 1024)
end

function DrawTool:saveDrawing(commandDescription, c)
    local actorId = c.actorId
    local newData = self.dependencies.Drawing2:serialize(DEFAULT_VIEW_WIDTH, _drawData:serialize())
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
    _drawData = DrawData:new()
    _grabbedPaths = nil
    _initialCoord = nil
    _tempGraphics = nil
    _subtool = 'pencil'
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
        _drawData = cacheEntry.drawData
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
                _drawData:resetFill()
                _drawData:resetGraphics()
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
                _drawData:resetFill()
                _drawData:resetGraphics()
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

                for i = 1, #_drawData.pathDataList do
                    for p = 1, 2 do
                        if roundedX == _drawData.pathDataList[i].points[p].x and roundedY == _drawData.pathDataList[i].points[p].y then
                            _drawData.pathDataList[i].grabPointIndex = p
                            table.insert(_grabbedPaths, _drawData.pathDataList[i])
                            break
                        end
                    end
                end

                for i = 1, #_grabbedPaths do
                    removePathData(_grabbedPaths[i])
                end

                if #_grabbedPaths == 0 then
                    for i = 1, #_drawData.pathDataList do
                        local pathData = _drawData.pathDataList[i]
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
                    _drawData:resetGraphics()
                end
            end

            for i = 1, #_grabbedPaths do
                _grabbedPaths[i].points[_grabbedPaths[i].grabPointIndex].x = roundedX
                _grabbedPaths[i].points[_grabbedPaths[i].grabPointIndex].y = roundedY

                _grabbedPaths[i].tovePath = nil
            end

            if touch.released then
                if _grabbedPaths and #_grabbedPaths > 0 then
                    for i = 1, #_grabbedPaths do
                        addPathData(_grabbedPaths[i])
                    end

                    _drawData:resetFill()
                    _drawData:resetGraphics()
                    self:saveDrawing("move", c)
                end

                _grabbedPaths = nil
                _tempGraphics = nil
            else
                resetTempGraphics()

                for i = 1, #_grabbedPaths do
                    updatePathDataRendering(_grabbedPaths[i])
                    _tempGraphics:addPath(_grabbedPaths[i].tovePath)
                end
            end
        elseif _subtool == 'bend' then
            if touch.released then
                for i = 1, #_drawData.pathDataList do
                    if _drawData.pathDataList[i].tovePath:nearest(touch.x, touch.y, 0.5) then
                        _drawData.pathDataList[i].style = _drawData.pathDataList[i].style + 1
                        if _drawData.pathDataList[i].style > 3 then
                            _drawData.pathDataList[i].style = 1
                        end
                        _drawData.pathDataList[i].tovePath = nil -- reset rendering

                        _drawData:resetFill()
                        _drawData:resetGraphics()
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

            for i = 1, #_drawData.floodFillFaceDataList do
                currentFaces[_drawData.floodFillFaceDataList[i].id] = true
            end

            findFaceForPoint(_SLABS, _drawData.pathDataList, GRID_TOP_PADDING, GRID_TOP_PADDING + GRID_SIZE, {
                x = touch.x,
                y = touch.y
            }, newFaces, newColoredSubpathIds, currentFaces, GRID_WIDTH / GRID_SIZE)

            for i = 1, #newFaces do
                table.insert(_drawData.floodFillFaceDataList, newFaces[i])
            end

            for i = 1, #newColoredSubpathIds do
                _drawData.floodFillColoredSubpathIds[newColoredSubpathIds[i]] = true
            end

            -- todo only save when there's a change
            _drawData:resetGraphics()
            self:saveDrawing("fill", c)
        elseif _subtool == 'erase line' then
            for i = 1, #_drawData.pathDataList do
                if _drawData.pathDataList[i].tovePath:nearest(touch.x, touch.y, 0.5) then
                    removePathData(_drawData.pathDataList[i])
                    _drawData:resetFill()
                    _drawData:resetGraphics()
                    self:saveDrawing("erase line", c)
                    break
                end
            end
        elseif _subtool == 'erase fill' then
            _FACE_POINTS = {}
            local newFaces = {}
            local newColoredSubpathIds = {}
            local currentFaces = {}

            findFaceForPoint(_SLABS, _drawData.pathDataList, GRID_TOP_PADDING, GRID_TOP_PADDING + GRID_SIZE, {
                x = touch.x,
                y = touch.y
            }, newFaces, newColoredSubpathIds, currentFaces, GRID_WIDTH / GRID_SIZE)

            for i = 1, #newFaces do
                for j = #_drawData.floodFillFaceDataList, 1, -1 do
                    if _drawData.floodFillFaceDataList[j].id == newFaces[i].id then
                        table.remove(_drawData.floodFillFaceDataList, j)
                    end
                end
            end

            for i = 1, #newColoredSubpathIds do
                _drawData.floodFillColoredSubpathIds[newColoredSubpathIds[i]] = nil
            end

            -- todo only save when there's a change
            _drawData:resetGraphics()
            self:saveDrawing("erase fill", c)
        end
    end
end

-- Draw

function DrawTool.handlers:drawOverlay()
    if not self:isActive() then
        return
    end


    love.graphics.push()
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

    _drawData:graphics():draw()

    if _tempGraphics ~= nil then
        _tempGraphics:draw()
    end

    if _subtool == "move" then
        local movePoints = {}

        for i = 1, #_drawData.pathDataList do
            for p = 1, 2 do
                table.insert(movePoints, _drawData.pathDataList[i].points[p].x)
                table.insert(movePoints, _drawData.pathDataList[i].points[p].y)
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

    love.graphics.pop()
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
            _drawData.fillColor[1], _drawData.fillColor[2], _drawData.fillColor[3] =
                uiPalette(_drawData.fillColor[1], _drawData.fillColor[2], _drawData.fillColor[3])
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

    ui.toggle(
        "debug",
        "debug",
        DEBUG_FLOOD_FILL,
        {
            onToggle = function(enabled)
                DEBUG_FLOOD_FILL = enabled
            end
        }
    )
end

function DrawTool.handlers:contentHeight()
    local windowWidth, windowHeight = love.graphics.getDimensions()
    return windowHeight * 0.2
end
