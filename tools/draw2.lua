
GRID_HORIZONTAL_PADDING = 0.05 * DEFAULT_VIEW_WIDTH
GRID_TOP_PADDING = 0.1 * DEFAULT_VIEW_WIDTH
GRID_WIDTH = DEFAULT_VIEW_WIDTH - GRID_HORIZONTAL_PADDING * 2.0

DRAW_DATA_SCALE = 10.0

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

local _viewTransform = love.math.newTransform()
local _drawData

local _initialCoord
local _currentPathData

local _tempGraphics
local _subtool
local _grabbedPaths

function DrawTool.handlers:addBehavior(opts)
    
end

-- Methods





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
    local newDrawData = _drawData:serialize()
    local newData = self.dependencies.Drawing2:serialize(newDrawData)
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
        local cacheDrawData = self.dependencies.Drawing2:cacheDrawing(drawingComponent.properties.data)
        if not cacheDrawData then
            return
        end

        c._lastData = drawingComponent.properties.data
        _drawData = cacheDrawData:clone()
    end


    local touchData = self:getTouchData()
    if touchData.numTouches == 1 and touchData.maxNumTouches == 1 then
        -- Get the single touch
        local touchId, touch = next(touchData.touches)
        local touchX, touchY = _viewTransform:inverseTransformPoint(touch.x, touch.y)

        local roundedX, roundedY = _drawData:roundGlobalCoordinatesToGrid(touchX, touchY)
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
                _drawData:updatePathDataRendering(pathData)
                _tempGraphics:addPath(pathData.tovePath)
            end
        elseif _subtool == 'pencil' then
            if _initialCoord == nil then
                _initialCoord = roundedCoord
                _currentPathData = nil
                _currentPathDataList = {}
            end

            local angle = math.atan2(touchY - _initialCoord.y, touchX - _initialCoord.x)
            if angle < 0.0 then
                angle = angle + math.pi * 2.0
            end
            local angleRoundedTo8Directions = math.floor((angle + (math.pi * 2.0) / (8.0 * 2.0)) * 8.0 / (math.pi * 2.0))
            if angleRoundedTo8Directions > 7 then
                angleRoundedTo8Directions = 0
            end
            local distFromOriginalPoint = math.sqrt(math.pow(touchX - _initialCoord.x, 2.0) + math.pow(touchY - _initialCoord.y, 2.0))
            local newAngle = (angleRoundedTo8Directions * (math.pi * 2.0) / 8.0)
            local direction = {x = math.cos(newAngle), y = math.sin(newAngle)}

            local cellSize = _drawData.scale / _drawData.gridSize

            if distFromOriginalPoint > cellSize then
                if _currentPathData ~= nil and (_currentPathData.points[1].x ~= _currentPathData.points[2].x or _currentPathData.points[1].y ~= _currentPathData.points[2].y) then
                    table.insert(_currentPathDataList, _currentPathData)

                    _initialCoord = _currentPathData.points[2]
                end
            end

            distFromOriginalPoint = math.sqrt(math.pow(touchX - _initialCoord.x, 2.0) + math.pow(touchY - _initialCoord.y, 2.0)) - cellSize * 0.5
            local newRoundedX, newRoundedY = _drawData:roundGlobalCoordinatesToGrid(_initialCoord.x + direction.x * distFromOriginalPoint, _initialCoord.y + direction.y * distFromOriginalPoint)
                
            _currentPathData = {}
            _currentPathData.points = {_initialCoord, {
                x = newRoundedX,
                y = newRoundedY,
            }}
            _currentPathData.style = 1
            _drawData:updatePathDataRendering(_currentPathData)

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
                        local distance, t, subpath = pathData.tovePath:nearest(touchX, touchY, 0.5)
                        if subpath then
                            local pointX, pointY = subpath:position(t)
                            removePathData(pathData)
                            local touchPoint = {x = touchX, y = touchY}

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
                    _drawData:updatePathDataRendering(_grabbedPaths[i])
                    _tempGraphics:addPath(_grabbedPaths[i].tovePath)
                end
            end
        elseif _subtool == 'bend' then
            if _grabbedPaths == nil then
                _grabbedPaths = {}

                for i = 1, #_drawData.pathDataList do
                    if _drawData.pathDataList[i].tovePath:nearest(touchX, touchY, 0.5) then
                        table.insert(_grabbedPaths, _drawData.pathDataList[i])
                        removePathData(_drawData.pathDataList[i])
                        _drawData:resetGraphics()
                        break
                    end
                end
            end

            if #_grabbedPaths > 0 then
                _grabbedPaths[1].bendPoint = {
                    x = touchX,
                    y = touchY,
                }
                _grabbedPaths[1].tovePath = nil
            end

            if touch.released then
                if #_grabbedPaths > 0 then
                    addPathData(_grabbedPaths[1])
                end
                
                _drawData:resetFill()
                _drawData:resetGraphics()
                self:saveDrawing("bend", c)

                _grabbedPaths = nil
                _tempGraphics = nil
            else
                if #_grabbedPaths > 0 then
                    resetTempGraphics()
                    _drawData:updatePathDataRendering(_grabbedPaths[1])
                    _tempGraphics:addPath(_grabbedPaths[1].tovePath)
                end
            end
        elseif _subtool == 'fill' then
------ create set of all verices added for an entire flood fill and use that as the key. check for the same 3 verteces in a row


            --_FACE_POINTS = {}
            local newFaces = {}
            local newColoredSubpathIds = {}
            local currentFaces = {}

            for i = 1, #_drawData.floodFillFaceDataList do
                currentFaces[_drawData.floodFillFaceDataList[i].id] = true
            end

            findFaceForPoint(_SLABS, _drawData.pathDataList, -0.01, 0.01 + _drawData.scale, {
                x = touchX,
                y = touchY
            }, newFaces, newColoredSubpathIds, currentFaces, _drawData.scale / _drawData.gridSize)

            if #newFaces > 0 then
                for i = 1, #newFaces do
                    table.insert(_drawData.floodFillFaceDataList, newFaces[i])
                end

                for i = 1, #newColoredSubpathIds do
                    _drawData.floodFillColoredSubpathIds[newColoredSubpathIds[i]] = true
                end

                _drawData:resetGraphics()
                self:saveDrawing("fill", c)
            end
        elseif _subtool == 'erase line' then
            for i = 1, #_drawData.pathDataList do
                if _drawData.pathDataList[i].tovePath:nearest(touchX, touchY, 0.5) then
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

            findFaceForPoint(_SLABS, _drawData.pathDataList, 0, 0 + _drawData.scale, {
                x = touchX,
                y = touchY
            }, newFaces, newColoredSubpathIds, currentFaces, _drawData.scale / _drawData.gridSize)

            local didChange = false
            for i = 1, #newFaces do
                for j = #_drawData.floodFillFaceDataList, 1, -1 do
                    if _drawData.floodFillFaceDataList[j].id == newFaces[i].id then
                        didChange = true
                        table.remove(_drawData.floodFillFaceDataList, j)
                    end
                end
            end

            for i = 1, #newColoredSubpathIds do
                _drawData.floodFillColoredSubpathIds[newColoredSubpathIds[i]] = nil
            end

            if didChange then
                _drawData:resetGraphics()
                self:saveDrawing("erase fill", c)
            end
        end
    end
end

-- Draw

function DrawTool.handlers:drawOverlay()
    if not self:isActive() then
        return
    end


    love.graphics.push()

    _viewTransform:reset()
    _viewTransform:translate(GRID_HORIZONTAL_PADDING, GRID_TOP_PADDING)
    _viewTransform:scale(GRID_WIDTH / DRAW_DATA_SCALE)
    love.graphics.applyTransform(_viewTransform)

    love.graphics.clear(BACKGROUND_COLOR.r, BACKGROUND_COLOR.g, BACKGROUND_COLOR.b)

    love.graphics.setColor(1, 1, 1, 1)

    if _subtool == 'draw' or _subtool == 'pencil' or _subtool == 'move' then
        love.graphics.setColor(0.5, 0.5, 0.5, 1.0)
        love.graphics.setPointSize(10.0)

        local points = {}

        for x = 1, _drawData.gridSize do
            for y = 1, _drawData.gridSize do
                local globalX, globalY = _drawData:gridToGlobalCoordinates(x, y)
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
            love.graphics.line(_SLABS[i].x, 0, _SLABS[i].x, 0 + _drawData.scale)
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
            _drawData.gridSize =
                ui.numberInput(
                "grid size",
                _drawData.gridSize,
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
