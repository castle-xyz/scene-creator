DRAW_DATA_SCALE = 10.0
local DRAW_MAX_VIEW_WIDTH = DEFAULT_VIEW_WIDTH * 2
DRAW_MAX_SIZE = 10.0

--local BACKGROUND_COLOR = {r = 62.0 / 255.0, g = 52.0 / 255.0, b = 81.0 / 255.0}
local BACKGROUND_COLOR = {r = 0.0, g = 0.0, b = 0.0}

local HANDLE_DRAW_RADIUS = 12

local SUBTOOLS = {}
local FUNCTIONS_TO_ADD_TO_SUBTOOLS = {
    "drawData", "saveDrawing", "addPathData", "clearTempGraphics", "resetTempGraphics", "addTempPathData", "bind", "removePathData", "physicsBodyData", "scaleRotateData", "getPixelScale", "selectedSubtools"
}

function defineDrawSubtool(subtoolSpec)
    subtoolSpec.handlers = subtoolSpec.handlers or {}
    table.insert(SUBTOOLS, subtoolSpec)
    return subtoolSpec
end

require('tools.draw_algorithms')
require('tools.draw_data')
require('tools.grid_shader')

require('tools.draw.subtools.draw_shapes_subtool')
require('tools.draw.subtools.draw_pencil_no_grid_subtool')
require('tools.draw.subtools.draw_line_subtool')
require('tools.draw.subtools.draw_pencil_subtool')
require('tools.draw.subtools.draw_move_subtool')
require('tools.draw.subtools.draw_bend_subtool')
require('tools.draw.subtools.draw_fill_subtool')
require('tools.draw.subtools.draw_erase_subtool')
require('tools.draw.subtools.physics_body_shapes_subtool')
require('tools.draw.subtools.physics_body_move_subtool')
require('tools.draw.subtools.physics_body_scale_rotate_subtool')
require('tools.draw.subtools.physics_body_erase_subtool')

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

local TEST_POINT = nil

function DrawTool:callSubtoolHandler(subtool, handlerName, ...)
    local handler = subtool.handlers[handlerName]
    if handler then
        return handler(subtool, ...)
    end
end

function DrawTool.handlers:addBehavior(opts)
    self._viewTransform = love.math.newTransform()
    self._drawData = nil
    self._physicsBodyData = nil

    self._tempGraphics = nil
    self._selectedSubtools = {
        root = "artwork",
        artwork = "artwork_draw",
        artwork_draw = "pencil_no_grid",
        artwork_move = "move",
        collision = "collision_draw",
        collision_draw = "rectangle",
        collision_move = "move",
    }

    self._subtools = {}
    for _, SUBTOOL in pairs(SUBTOOLS) do
        local subtool = {}

        subtool.name = SUBTOOL.name
        subtool.category = SUBTOOL.category

        -- Copy methods
        for methodName, method in pairs(SUBTOOL) do
            if type(method) == "function" then
                subtool[methodName] = method
            end
        end

        -- Copy handlers and properties
        subtool.handlers = {}
        for handlerName, handler in pairs(SUBTOOL.handlers) do
            subtool.handlers[handlerName] = handler
        end

        for _, functionName in pairs(FUNCTIONS_TO_ADD_TO_SUBTOOLS) do
            subtool[functionName] = function(...)
                -- remove the first 'self' arg and replace with DrawTool's
                -- self so that we can use self:addPathData syntax in subtools
                -- instead of self.addPathData
                local args = {...}
                table.remove(args, 1)
                return self[functionName](self, unpack(args))
            end
        end

        if subtool.handlers.addSubtool ~= nil then
            self:callSubtoolHandler(subtool, "addSubtool")
        end

        table.insert(self._subtools, subtool)
    end
end

-- Methods

function DrawTool:getPixelScale()
    return self.game:getPixelScale()
end

function DrawTool:selectedSubtools()
    return self._selectedSubtools
end

function DrawTool:addPathData(pathData)
    if pathData.points[1].x ~= pathData.points[2].x or pathData.points[1].y ~= pathData.points[2].y then
        if not pathData.color then
            pathData.color = util.deepCopyTable(self._drawData.color)
        end
        table.insert(self._drawData.pathDataList, pathData)
    end
end

function DrawTool:addTempPathData(pathData)
    if not pathData.color then
        pathData.color = util.deepCopyTable(self._drawData.color)
    end
    self._drawData:updatePathDataRendering(pathData)
    self._tempGraphics:addPath(pathData.tovePath)
end

function DrawTool:removePathData(pathData)
    for i = #self._drawData.pathDataList, 1, -1 do
        if self._drawData.pathDataList[i] == pathData then
            table.remove(self._drawData.pathDataList, i)
        end
    end
end

function DrawTool:resetTempGraphics()
    self._tempGraphics = tove.newGraphics()
    self._tempGraphics:setDisplay("mesh", 1024)
end

function DrawTool:clearTempGraphics()
    self._tempGraphics = nil
end

function DrawTool:drawData()
    return self._drawData
end

function DrawTool:scaleRotateData()
    return self._scaleRotateData
end

function DrawTool:physicsBodyData()
    return self._physicsBodyData
end

function DrawTool:saveDrawing(commandDescription, c)
    local actorId = c.actorId
    local newDrawData = self._drawData:serialize()
    local newPhysicsBodyData = self._physicsBodyData:serialize()
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
    self._drawData = DrawData:new()
    self._physicsBodyData = PhysicsBodyData:new()
    self:clearTempGraphics()
    self._scaleRotateData = {}
    self.viewWidth = DEFAULT_VIEW_WIDTH
    self.viewX, self.viewY = 0, 0
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

function DrawTool:bind(t, k)
    return function(...) return t[k](t, ...) end
end

function DrawTool:getCurrentSubtool()
    local currentCategory = 'root'
    local currentName = self._selectedSubtools[currentCategory]

    while self._selectedSubtools[currentName] do
        currentCategory = currentName
        currentName = self._selectedSubtools[currentName]
    end

    for _, subtool in pairs(self._subtools) do
        if subtool.category == currentCategory and subtool.name == currentName then
            return subtool
        end
    end

    return nil
end

function DrawTool:getViewScale()
    local scale = self._viewTransform:getMatrix()
    return scale
end

function DrawTool:getPixelScale()
    return love.graphics.getDPIScale() / self:getViewScale()
end

function DrawTool:twoFingerPan(touchData)
    if touchData.numTouches == 2 then
        local moveX, moveY = 0, 0
        local centerX, centerY
        local scale

        local touchId1, touch1 = next(touchData.touches)
        local touchId2, touch2 = next(touchData.touches, touchId1)

        local touch1PrevSX, touch1PrevSY = touch1.screenX - touch1.screenDX, touch1.screenY - touch1.screenDY
        local touch2PrevSX, touch2PrevSY = touch2.screenX - touch2.screenDX, touch2.screenY - touch2.screenDY

        local centerSX, centerSY = 0.5 * (touch1.screenX + touch2.screenX), 0.5 * (touch1.screenY + touch2.screenY)
        local centerPrevSX, centerPrevSY = 0.5 * (touch1PrevSX + touch2PrevSX), 0.5 * (touch1PrevSY + touch2PrevSY)

        moveX, moveY = (centerSX - centerPrevSX) / self:getViewScale(), (centerSY - centerPrevSY) / self:getViewScale()

        local px, py = touch1.screenX - touch2.screenX, touch1.screenY - touch2.screenY
        local pl = math.sqrt(px * px + py * py)
        local prevPX, prevPY = touch1PrevSX - touch2PrevSX, touch1PrevSY - touch2PrevSY
        local initialPX, initialPY =
            touch1.initialScreenX - touch2.initialScreenX,
            touch1.initialScreenY - touch2.initialScreenY
        local initialPL = math.sqrt(initialPX * initialPX + initialPY * initialPY)
        if
            (touch1.zooming or touch2.zooming or
                not (self.viewWidth == DEFAULT_VIEW_WIDTH and math.abs(initialPL - pl) <= 0.175 * initialPL))
         then
            -- Don't zoom if close to 1:1
            local prevPL = math.sqrt(prevPX * prevPX + prevPY * prevPY)
            if not (touch1.zooming and touch2.zooming) then
                touch1.zooming = true
                touch2.zooming = true
                prevPL = initialPL
            end
            scale = prevPL / pl
        end

        centerX, centerY = self._viewTransform:inverseTransformPoint(centerSX, centerSY)

        if scale then
            local prevViewWidth = self.viewWidth
            self.viewWidth = math.max(MIN_VIEW_WIDTH, math.min(scale * self.viewWidth, DRAW_MAX_VIEW_WIDTH))
            if math.abs(self.viewWidth - DEFAULT_VIEW_WIDTH) < 0.1 * DEFAULT_VIEW_WIDTH then
                self.viewWidth = DEFAULT_VIEW_WIDTH
            end
            scale = self.viewWidth / prevViewWidth -- Recompute to account for clamping above
            moveX = moveX - (1 - scale) * (centerX - self.viewX)
            moveY = moveY - (1 - scale) * (centerY - self.viewY)
        end
        if not (touch1.noPan or touch2.noPan) then
            local prevX, prevY = self.viewX, self.viewY
            self.viewX, self.viewY = self.viewX - moveX, self.viewY - moveY
            if self.viewWidth == DEFAULT_VIEW_WIDTH then -- Move snap only when zoom is 1:1
                local prevL = math.sqrt(prevX * prevX + prevY * prevY)
                local l = math.sqrt(self.viewX * self.viewX + self.viewY * self.viewY)
                if l < prevL and l < 0.2 * UNIT then -- Moved close to center? Snap and disable pan for rest of gesture.
                    self.viewX, self.viewY = 0, 0
                    touch1.noPan = true
                    touch2.noPan = true
                end
            end

            if self.viewX < -DRAW_MAX_SIZE then
                self.viewX = -DRAW_MAX_SIZE
            end
            if self.viewY < -DRAW_MAX_SIZE then
                self.viewY = -DRAW_MAX_SIZE
            end
            if self.viewX > DRAW_MAX_SIZE then
                self.viewX = DRAW_MAX_SIZE
            end
            if self.viewY > DRAW_MAX_SIZE then
                self.viewY = DRAW_MAX_SIZE
            end
        end
    end
end

function DrawTool:loadLastSave()
    local c = self:getSingleComponent()
    local drawingComponent = self.dependencies.Drawing2:get(c.actorId)
    local data = self.dependencies.Drawing2:cacheDrawing(drawingComponent, drawingComponent.properties)

    c._lastHash = drawingComponent.properties.hash
    self._drawData = data.drawData:clone()
    self._physicsBodyData = data.physicsBodyData:clone()

    if self._scaleRotateData and self._scaleRotateData.index and self._scaleRotateData.index > self._physicsBodyData:getNumShapes() then
        self._scaleRotateData.index = self._physicsBodyData:getNumShapes()
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
        self:loadLastSave()
    end


    local touchData = self:getTouchData()
    local subtool = self:getCurrentSubtool()

    if touchData.numTouches == 1 and touchData.maxNumTouches == 1 then
        -- Get the single touch
        local touchId, touch = next(touchData.touches)
        local touchX, touchY = self._viewTransform:inverseTransformPoint(touch.x, touch.y)

        local roundedX, roundedY = self._drawData:roundGlobalCoordinatesToGrid(touchX, touchY)
        local roundedCoord = {x = roundedX, y = roundedY}
        local clampedX, clampedY = self._drawData:clampGlobalCoordinates(touchX, touchY)
    
        local childTouchData = {
            touch = touch,
            touchX = touchX,
            touchY = touchY,
            roundedX = roundedX,
            roundedY = roundedY,
            roundedCoord = roundedCoord,
            clampedX = clampedX,
            clampedY = clampedY,
        }

        if subtool then
            self:callSubtoolHandler(subtool, "onTouch", c, childTouchData)
            if touch.released then
                subtool._hasTouch = false
            else
                subtool._hasTouch = true
            end
        end
    else
        if subtool and subtool._hasTouch then
            subtool._hasTouch = false
            self:callSubtoolHandler(subtool, "addSubtool")
            self:clearTempGraphics()
            self:loadLastSave()
        end

        self:twoFingerPan(touchData)
    end
end

-- Draw

function DrawTool:drawShapes()
    love.graphics.setColor(1, 1, 1, 1)

    self._drawData:graphics():draw()

    if self._tempGraphics ~= nil then
        self._tempGraphics:draw()
    end
end

function DrawTool.handlers:drawOverlay()
    if not self:isActive() then
        return
    end

    local windowWidth, windowHeight = love.graphics.getDimensions()
    -- DrawingCardHeader.js height is 180 and DrawingCardBottomActions.js height is 80
    local topOffset = 0.5 * (self.viewWidth * VIEW_HEIGHT_TO_WIDTH_RATIO - ((180 + 80) / (windowWidth / self.viewWidth)))

    love.graphics.push()

    self._viewTransform:reset()
    self._viewTransform:scale(windowWidth / self.viewWidth)
    self._viewTransform:translate(-self.viewX, -self.viewY)
    self._viewTransform:translate(0.5 * self.viewWidth, topOffset)
    love.graphics.applyTransform(self._viewTransform)

    love.graphics.clear(BACKGROUND_COLOR.r, BACKGROUND_COLOR.g, BACKGROUND_COLOR.b)

    love.graphics.setColor(1, 1, 1, 1)

    if self._selectedSubtools.root ~= 'artwork' then
        self._drawData:renderFill()
        self:drawShapes()

        love.graphics.setColor(0, 0, 0, 0.5)
        local padding = 1
        love.graphics.rectangle('fill', -DRAW_MAX_SIZE - padding, -DRAW_MAX_SIZE - padding, (DRAW_MAX_SIZE + padding) * 2.0, (DRAW_MAX_SIZE + padding) * 2.0)
    end

    -- grid
    --if self._selectedSubtools.root ~= 'artwork' or (self._selectedSubtools.artwork_draw == 'line' or self._selectedSubtools.artwork_draw == 'pencil' or self._selectedSubtools.artwork_move == 'move' or self._selectedSubtools.artwork_draw == 'rectangle' or self._selectedSubtools.artwork_draw == 'circle' or self._selectedSubtools.artwork_draw == 'triangle') then
        love.graphics.setColor(0.3, 0.3, 0.3, 1.0)
        drawGrid(self._drawData:gridCellSize(), DRAW_MAX_SIZE + self._drawData:gridCellSize() * 0.5, self:getViewScale(), self.viewX, self.viewY, 0.5 * self.viewWidth, topOffset, 4, true)

    --end

    if self._selectedSubtools.root == 'artwork' then
        love.graphics.setColor(1, 1, 1, 1)
        self._drawData:renderFill()
        self:drawShapes()
        self._physicsBodyData:draw()
    end

    love.graphics.setColor(1, 1, 1, 1)

    if self._selectedSubtools.root == "artwork" and self._selectedSubtools.artwork == "artwork_move" and self._selectedSubtools.artwork_move == "move" then
        local movePoints = {}

        for i = 1, #self._drawData.pathDataList do
            if not self._drawData.pathDataList[i].isFreehand then
                for p = 1, 2 do
                    table.insert(movePoints, self._drawData.pathDataList[i].points[p].x)
                    table.insert(movePoints, self._drawData.pathDataList[i].points[p].y)
                end
            end
        end

        love.graphics.setColor(1.0, 0.6, 0.6, 1.0)
        love.graphics.setPointSize(30)
        love.graphics.points(movePoints)
    end

    if self._selectedSubtools.root == 'collision' then
        self._physicsBodyData:draw()

        if self._selectedSubtools.collision == 'collision_move' and self._selectedSubtools.collision_move == 'scale-rotate' and self._scaleRotateData.index then
            love.graphics.setColor(1.0, 0.0, 0.0, 1.0)
            love.graphics.setPointSize(30)
            love.graphics.setLineWidth(self:getPixelScale())
            --love.graphics.points()

            local handleDrawRadius = HANDLE_DRAW_RADIUS * self:getPixelScale()
            local scaleRotateShape = self._physicsBodyData:getShapeAtIndex(self._scaleRotateData.index)
            for _, handle in ipairs(self._physicsBodyData:getHandlesForShape(scaleRotateShape)) do
                love.graphics.circle("fill", handle.x, handle.y, handleDrawRadius)
                if handle.endX and handle.endY then
                    love.graphics.line(handle.x, handle.y, handle.endX, handle.endY)
                end
            end
        end
    end

    if TEST_POINT ~= nil then
        love.graphics.setColor(0.0, 1.0, 0.0, 1.0)
        love.graphics.setPointSize(30)

        love.graphics.points(TEST_POINT.x, TEST_POINT.y)
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

    actions['onSelectSubtool'] = function(s)
        category, name = s:match("([^:]+):([^:]+)")

        if self._selectedSubtools[category] ~= name then
            self._selectedSubtools[category] = name

            local subtool = self:getCurrentSubtool()
            if subtool then
                self:callSubtoolHandler(subtool, "addSubtool")
                self:callSubtoolHandler(subtool, "onSelected")
            end
        end
    end

    actions['updateColor'] = function(opts)
        self._drawData:updateColor(opts.r, opts.g, opts.b)
        self:saveDrawing("update color", c)
    end

    ui.data({
        selectedSubtools = self._selectedSubtools,
        color = self._drawData.color,
    }, {
        actions = actions,
    })
end
