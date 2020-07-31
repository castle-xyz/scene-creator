
GRID_HORIZONTAL_PADDING = 0.05 * DEFAULT_VIEW_WIDTH
GRID_TOP_PADDING = 0.1 * DEFAULT_VIEW_WIDTH
GRID_WIDTH = DEFAULT_VIEW_WIDTH - GRID_HORIZONTAL_PADDING * 2.0

DRAW_DATA_SCALE = 10.0

BACKGROUND_COLOR = {r = 0.0, g = 0.0, b = 0.0}

local HANDLE_TOUCH_RADIUS = 30
local HANDLE_DRAW_RADIUS = 12

require('tools.draw_algorithms')
require('tools.draw_data')

local DrawTool =
    defineCoreBehavior {
    name = "Draw2",
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
local _physicsBodyData

local _initialCoord
local _currentPathData

local _tempGraphics
local _tool
local _subtool
local _physicsBodySubtool
local _grabbedPaths

local _didChange

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
    local newPhysicsBodyData = _physicsBodyData:serialize()
    local newHash = self.dependencies.Drawing2:hash(newDrawData, newPhysicsBodyData) -- Prevent reloading since we're already in sync
    c._lastHash = newHash
    local oldDrawData = self.dependencies.Drawing2:get(actorId).properties.drawData
    local oldPhysicsBodyData = self.dependencies.Drawing2:get(actorId).properties.physicsBodyData
    local oldHash = self.dependencies.Drawing2:get(actorId).properties.hash

    self.dependencies.Drawing2:command(
        commandDescription,
        {
            params = {"oldDrawData", "newDrawData", "oldPhysicsBodyData", "newPhysicsBodyData", "oldHash", "newHash"}
        },
        function()
            self:sendSetProperties(actorId, "drawData", newDrawData)
            self:sendSetProperties(actorId, "physicsBodyData", newPhysicsBodyData)
            self:sendSetProperties(actorId, "hash", newHash)
        end,
        function()
            self:sendSetProperties(actorId, "drawData", oldDrawData)
            self:sendSetProperties(actorId, "physicsBodyData", oldPhysicsBodyData)
            self:sendSetProperties(actorId, "hash", oldHash)
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
    _physicsBodyData = PhysicsBodyData:new()
    _grabbedPaths = nil
    _initialCoord = nil
    _tempGraphics = nil
    _didChange = false
    _tool = 'draw'
    _subtool = 'pencil'
    _physicsBodySubtool = 'rectangle'
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

local _grabbedShape = nil
local _scaleRotateData = {}

local function bind(t, k)
    return function(...) return t[k](t, ...) end
end

function DrawTool:updatePhysicsBodyTool(c, touch)
    local touchX, touchY = _viewTransform:inverseTransformPoint(touch.x, touch.y)

    local roundedX, roundedY = _drawData:roundGlobalCoordinatesToGrid(touchX, touchY)
    local roundedCoord = {x = roundedX, y = roundedY}

    if _physicsBodySubtool == 'rectangle' or _physicsBodySubtool == 'circle' or _physicsBodySubtool == 'triangle' then
        if _initialCoord == nil then
            _initialCoord = roundedCoord
        end

        local shape
        if _physicsBodySubtool == 'rectangle' then
            shape = _physicsBodyData:getRectangleShape(_initialCoord, roundedCoord)
        elseif _physicsBodySubtool == 'circle' then
            shape = _physicsBodyData:getCircleShape(_initialCoord, roundedCoord, bind(_drawData, 'roundGlobalCoordinatesToGrid'), bind(_drawData, 'roundGlobalDistanceToGrid'))
        elseif _physicsBodySubtool == 'triangle' then
            shape = _physicsBodyData:getTriangleShape(_initialCoord, roundedCoord)
        end

        if shape then
            _physicsBodyData.tempShape = shape
        end

        if touch.released then
            if _physicsBodyData:commitTempShape() then
                self:saveDrawing('add ' .. _physicsBodySubtool, c)
            end

            _initialCoord = nil
        end
    elseif _physicsBodySubtool == 'move' then
        if _initialCoord == nil then
            _initialCoord = {
                x = touchX,
                y = touchY
            }
            local idx = _physicsBodyData:getShapeIdxAtPoint(_initialCoord)
            if idx then
                _grabbedShape = _physicsBodyData:removeShapeAtIndex(idx)
            end
        end

        if _grabbedShape then
            local diffX, diffY = _drawData:roundGlobalDiffCoordinatesToGrid(touchX - _initialCoord.x, touchY - _initialCoord.y)

            _physicsBodyData.tempShape = _physicsBodyData:moveShapeBy(_grabbedShape, diffX, diffY, _drawData:gridCellSize())
        end

        if touch.released then
            if _physicsBodyData:commitTempShape() then
                self:saveDrawing("move", c)
            end

            _initialCoord = nil
            _grabbedShape = nil
        end
    elseif _physicsBodySubtool == 'scale-rotate' then
        if _initialCoord == nil then
            _initialCoord = {
                x = touchX,
                y = touchY
            }

            local grabbledHandle = false
            if _scaleRotateData.shape then
                local handleTouchRadius = HANDLE_TOUCH_RADIUS * self.game:getPixelScale()
            
                for _, handle in ipairs(_physicsBodyData:getHandlesForShape(_scaleRotateData.shape)) do
                    local distance = math.sqrt(math.pow(touchX - handle.x, 2.0) + math.pow(touchY - handle.y, 2.0))
                    if distance < handleTouchRadius then
                        _scaleRotateData.handle = handle
                        _scaleRotateData.shape = _physicsBodyData:removeShapeAtIndex(_scaleRotateData.index)
                        _scaleRotateData.isGrabbed = true
                        grabbledHandle = true
                        break
                    end
                end

                if not grabbledHandle and _scaleRotateData.shape.type == "triangle" then
                    local centerX, centerY = _physicsBodyData:getCenterOfShape(_scaleRotateData.shape)
                    local distance = math.sqrt(math.pow(touchX - centerX, 2.0) + math.pow(touchY - centerY, 2.0))
                    if distance < handleTouchRadius * 2.0 then
                        _scaleRotateData.shape.pivot = _physicsBodyData:rotatePivot(_scaleRotateData.shape.pivot)
                        self:saveDrawing("rotate", c)
                        grabbledHandle = true
                    end
                end
            end

            -- only allow choosing a new shape if we didn't find a handle
            if not grabbledHandle and _scaleRotateData.handle == nil then
                local index = _physicsBodyData:getShapeIdxAtPoint(_initialCoord)

                if index then
                    _scaleRotateData.shape = _physicsBodyData:getShapeAtIndex(index)
                    _scaleRotateData.index = index
                end
            end
        end

        if _scaleRotateData.shape and _scaleRotateData.isGrabbed then
            local otherCoord = {
                x = _scaleRotateData.handle.oppositeX,
                y = _scaleRotateData.handle.oppositeY,
            }
            local type = _scaleRotateData.shape.type
            local shape

            if type == 'rectangle' then
                shape = _physicsBodyData:getRectangleShape(otherCoord, roundedCoord)
            elseif type == 'circle' then
                shape = _physicsBodyData:getCircleShape(otherCoord, roundedCoord, bind(_drawData, 'roundGlobalCoordinatesToGrid'), bind(_drawData, 'roundGlobalDistanceToGrid'))
            elseif type == 'triangle' then
                shape = _physicsBodyData:getTriangleShape(otherCoord, roundedCoord)
                if shape then
                    shape.pivot = _scaleRotateData.shape.pivot
                end
            end

            if shape then
                _physicsBodyData.tempShape = shape
                _scaleRotateData.shape = shape
            end
        end

        if touch.released then
            if _scaleRotateData.handle and _physicsBodyData:commitTempShape() then
                self:saveDrawing("scale", c)

                local index = _physicsBodyData:getNumShapes()
                _scaleRotateData.shape = _physicsBodyData:getShapeAtIndex(index)
                _scaleRotateData.index = index
            end

            _initialCoord = nil
            _scaleRotateData.handle = nil
            _scaleRotateData.isGrabbed = false
        end
    elseif _physicsBodySubtool == 'erase' then
        if _initialCoord == nil then
            _initialCoord = roundedCoord

            local idx = _physicsBodyData:getShapeIdxAtPoint(_initialCoord)
            if idx then
                _physicsBodyData:removeShapeAtIndex(idx)
                self:saveDrawing("erase", c)
            end
        end

        if touch.released then
            _initialCoord = nil
        end
    end
end

function DrawTool:updateDrawTool(c, touch)
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
            _drawData:resetGraphics()
            _drawData:resetFill()
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
            _drawData:resetGraphics()
            _drawData:resetFill()
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
                    if floatEquals(roundedX, _drawData.pathDataList[i].points[p].x) and floatEquals(roundedY, _drawData.pathDataList[i].points[p].y) then
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

                _drawData:resetGraphics()
                _drawData:resetFill()
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
        if touch.released then
            for i = 1, #_drawData.pathDataList do
                if _drawData.pathDataList[i].tovePath:nearest(touchX, touchY, 0.5) then
                    _drawData.pathDataList[i].style = _drawData.pathDataList[i].style + 1
                    if _drawData.pathDataList[i].style > 3 then
                        _drawData.pathDataList[i].style = 1
                    end
                    _drawData.pathDataList[i].tovePath = nil -- reset rendering

                    _drawData:resetGraphics()
                    _drawData:resetFill()
                    self:saveDrawing("bend", c)

                    break
                end
            end
        end
    elseif _subtool == 'fill' then
        if _drawData:floodFill(touchX, touchY) then
            _didChange = true
        end

        if touch.released then
            if _didChange then
                self:saveDrawing("fill", c)
            end
            _didChange = false
        end
    elseif _subtool == 'erase' then
        for i = 1, #_drawData.pathDataList do
            if _drawData.pathDataList[i].tovePath:nearest(touchX, touchY, 0.5) then
                removePathData(_drawData.pathDataList[i])
                _drawData:resetGraphics()
                _didChange = true
                break
            end
        end

        if _drawData:floodClear(touchX, touchY) then
            _didChange = true
        end

        if touch.released then
            if _didChange then
                _drawData:resetGraphics()
                _drawData:resetFill()
                self:saveDrawing("erase", c)
            end
            _didChange = false
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

    local drawingComponent = self.dependencies.Drawing2:get(c.actorId)
    if c._lastHash ~= drawingComponent.properties.hash then
        local data = self.dependencies.Drawing2:cacheDrawing(drawingComponent.properties)

        c._lastHash = drawingComponent.properties.hash
        _drawData = data.drawData:clone()
        _physicsBodyData = data.physicsBodyData:clone()
    end


    local touchData = self:getTouchData()
    if touchData.numTouches == 1 and touchData.maxNumTouches == 1 then
        -- Get the single touch
        local touchId, touch = next(touchData.touches)

        if _tool == "draw" then
            self:updateDrawTool(c, touch)
        else
            self:updatePhysicsBodyTool(c, touch)
        end
    end
end

-- Draw

local function drawShapes()
    love.graphics.setColor(1, 1, 1, 1)

    _drawData:graphics():draw()

    if _tempGraphics ~= nil then
        _tempGraphics:draw()
    end
end

local function drawPoints(points, radius)
    if radius == nil then
        radius = 0.07
    end

    for i = 1, #points, 2 do
        love.graphics.circle("fill", points[i], points[i + 1], radius)
    end
end

function DrawTool.handlers:drawOverlay()
    if not self:isActive() then
        return
    end


    love.graphics.push()

    _viewTransform:reset()
    _viewTransform:translate(GRID_HORIZONTAL_PADDING, GRID_TOP_PADDING)
    _viewTransform:scale(GRID_WIDTH / _drawData.scale)
    love.graphics.applyTransform(_viewTransform)

    love.graphics.clear(BACKGROUND_COLOR.r, BACKGROUND_COLOR.g, BACKGROUND_COLOR.b)

    love.graphics.setColor(1, 1, 1, 1)

    if _tool == 'draw' then
        _physicsBodyData:draw()
        _drawData:renderFill()
    else
        _drawData:renderFill()
        drawShapes()
    end

    if _tool ~= 'draw' or (_subtool == 'draw' or _subtool == 'pencil' or _subtool == 'move') then
        love.graphics.setColor(0.5, 0.5, 0.5, 1.0)
        --love.graphics.setPointSize(10.0)

        local points = {}

        for x = 1, _drawData.gridSize do
            for y = 1, _drawData.gridSize do
                local globalX, globalY = _drawData:gridToGlobalCoordinates(x, y)
                table.insert(points, globalX)
                table.insert(points, globalY)
            end
        end

        drawPoints(points)
    end

    if _tool == 'draw' then
        drawShapes()
    end

    love.graphics.setColor(1, 1, 1, 1)

    if _tool == "draw" and _subtool == "move" then
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

    if _tool == 'physics_body' then
        _physicsBodyData:draw()

        if _physicsBodySubtool == 'scale-rotate' and _scaleRotateData.shape then
            love.graphics.setColor(1.0, 0.0, 0.0, 1.0)
            love.graphics.setPointSize(30.0)
            love.graphics.points()

            local handleDrawRadius = HANDLE_DRAW_RADIUS * self.game:getPixelScale()
            for _, handle in ipairs(_physicsBodyData:getHandlesForShape(_scaleRotateData.shape)) do
                love.graphics.circle("fill", handle.x, handle.y, handleDrawRadius)
                if handle.endX and handle.endY then
                    love.graphics.line(handle.x, handle.y, handle.endX, handle.endY)
                end
            end
        end
    end

    love.graphics.pop()
end

-- UI

function DrawTool.handlers:uiData()
    if not self:isActive() then
        return
    end

    local c = self:getSingleComponent()
    if not c then
        return
    end

    local actions = {}
    actions['onSelectArtwork'] = function()
        _tool = 'draw'
    end

    actions['onSelectCollision'] = function()
        _tool = 'physics_body'
    end

    actions['onSelectArtworkSubtool'] = function(name)
        _subtool = name

        if _subtool == 'fill' or _subtool == 'erase' then
            _drawData:updatePathsCanvas()
        end
    end

    actions['onSelectCollisionSubtool'] = function(name)
        _physicsBodySubtool = name
    end

    actions['updateFillColor'] = function(opts)
        _drawData:updateFillColor(opts.r, opts.g, opts.b)
        self:saveDrawing("update fill color", c)
    end

    actions['updateLineColor'] = function(opts)
        _drawData:updateLineColor(opts.r, opts.g, opts.b)
        self:saveDrawing("update line color", c)
    end

    ui.data({
        currentMode = (_tool == 'draw' and 'artwork' or 'collision'),
        fillColor = _drawData.fillColor,
        lineColor = _drawData.lineColor,
        artworkSubtool = _subtool,
        collisionSubtool = _physicsBodySubtool,
    }, {
        actions = actions,
    })
end
