DRAW_DATA_SCALE = 10.0
local DRAW_MAX_VIEW_WIDTH = DEFAULT_VIEW_WIDTH * 2.5
DRAW_MAX_SIZE = 10.0

local HANDLE_DRAW_RADIUS = 12

local SUBTOOLS = {}
local FUNCTIONS_TO_ADD_TO_SUBTOOLS = {
    "drawData", "saveDrawing", "addPathData", "clearTempGraphics", "resetTempGraphics", "addTempPathData", "bind", "removePathData", "physicsBodyData", "scaleRotateData", "getPixelScale", "selectedSubtools", "getZoomAmount", "setTempTranslation", "drawDataFrame"
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
require('tools.draw.subtools.draw_move_subtool')
require('tools.draw.subtools.draw_move_all_subtool')
require('tools.draw.subtools.draw_bend_subtool')
require('tools.draw.subtools.draw_fill_subtool')
require('tools.draw.subtools.draw_erase_subtool')
require('tools.draw.subtools.draw_erase_segment_subtool')
require('tools.draw.subtools.physics_body_shapes_subtool')
require('tools.draw.subtools.physics_body_move_subtool')
require('tools.draw.subtools.physics_body_move_all_subtool')
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
        hideBodyOutline = true,
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
        artwork_erase = "erase_medium",
        collision = "collision_draw",
        collision_draw = "rectangle",
        collision_move = "move",
    }
    self._copiedCell = nil

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

function DrawTool:setTempTranslation(x, y)
    self.tempTranslateX = x
    self.tempTranslateY = y
end

function DrawTool:getPixelScale()
    return self.game:getPixelScale()
end

function DrawTool:selectedSubtools()
    return self._selectedSubtools
end

function DrawTool:getZoomAmount()
    return self.viewWidth / DEFAULT_VIEW_WIDTH
end

function DrawTool:addPathData(pathData)
    if pathData.points[1].x ~= pathData.points[2].x or pathData.points[1].y ~= pathData.points[2].y then
        -- deep copy so that each point is a different object
        -- otherwise, "move all" will move some points twice
        pathData = util.deepCopyTable(pathData)
        if not pathData.color then
            pathData.color = util.deepCopyTable(self._drawData.color)
        end
        table.insert(self._drawData:currentPathDataList(), pathData)
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
    for i = #self._drawData:currentPathDataList(), 1, -1 do
        if self._drawData:currentPathDataList()[i] == pathData then
            table.remove(self._drawData:currentPathDataList(), i)
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

function DrawTool:drawDataFrame()
    return self._drawData:currentLayerFrame()
end

function DrawTool:scaleRotateData()
    return self._scaleRotateData
end

function DrawTool:physicsBodyData()
    return self._physicsBodyData
end

function DrawTool:saveDrawing(commandDescription, c)
    self._drawData:updateFramePreview()
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
            self.game:updateBlueprintFromActor(actorId, { updateBase64Png = true })
        end,
        function()
            self:sendSetProperties(actorId, "drawData", oldDrawData)
            self:sendSetProperties(actorId, "physicsBodyData", oldPhysicsBodyData)
            self:sendSetProperties(actorId, "hash", oldHash)
            self.game:updateBlueprintFromActor(actorId, { updateBase64Png = true })
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

function DrawTool.handlers:onSetActive(toolOptions)
    self._toolOptions = toolOptions
    self._drawData = DrawData:new()
    self._physicsBodyData = PhysicsBodyData:new()
    self:clearTempGraphics()
    self._scaleRotateData = {}
    self.viewWidth = DEFAULT_VIEW_WIDTH
    self.hasResetViewWidth = false
    self.viewX, self.viewY = 0, 0
    self.viewInContext = false
    self.isPlayingAnimation = false
    self.animationState = nil
    self.isOnionSkinningEnabled = false
    self.tempTranslateX, self.tempTranslateY = 0, 0
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

        local prevPL = math.sqrt(prevPX * prevPX + prevPY * prevPY)
        if not (touch1.zooming and touch2.zooming) then
            touch1.zooming = true
            touch2.zooming = true
            prevPL = initialPL
        end
        scale = prevPL / pl

        centerX, centerY = self._viewTransform:inverseTransformPoint(centerSX, centerSY)

        if scale then
            local prevViewWidth = self.viewWidth
            self.viewWidth = math.max(MIN_VIEW_WIDTH, math.min(scale * self.viewWidth, DRAW_MAX_VIEW_WIDTH))
            scale = self.viewWidth / prevViewWidth -- Recompute to account for clamping above
            moveX = moveX - (1 - scale) * (centerX - self.viewX)
            moveY = moveY - (1 - scale) * (centerY - self.viewY)
        end
        if not (touch1.noPan or touch2.noPan) then
            local prevX, prevY = self.viewX, self.viewY
            self.viewX, self.viewY = self.viewX - moveX, self.viewY - moveY

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

    c._lastHash = drawingComponent.properties.hash
    local editorSettings = nil
    if self._drawData then
        editorSettings = self._drawData:saveEditorSettings()
    end
    self._drawData = DrawData:new(drawingComponent.properties.drawData or {})
    self._drawData:applyEditorSettings(editorSettings)
    self._physicsBodyData = PhysicsBodyData:new(drawingComponent.properties.physicsBodyData or {})

    if self._scaleRotateData and self._scaleRotateData.index and self._scaleRotateData.index > self._physicsBodyData:getNumShapes() then
        self._scaleRotateData.index = self._physicsBodyData:getNumShapes()
    end

    if not self.hasResetViewWidth then
        self.hasResetViewWidth = true

        local bounds = self:drawDataFrame():getPathDataBounds()
        local maxBound = 1.0

        if math.abs(bounds.minX) > maxBound then
            maxBound = math.abs(bounds.minX)
        end
        if math.abs(bounds.maxX) > maxBound then
            maxBound = math.abs(bounds.maxX)
        end
        if math.abs(bounds.minY) > maxBound then
            maxBound = math.abs(bounds.minY)
        end
        if math.abs(bounds.maxY) > maxBound then
            maxBound = math.abs(bounds.maxY)
        end

        if maxBound > 1.0 then
            self.viewWidth = maxBound * 2.0
        end
    end

    if self._toolOptions then
        if self._toolOptions.selectedFrame then
            self._drawData:selectFrame(self._toolOptions.selectedFrame)
            self:saveDrawing('select frame', c)
        elseif self._toolOptions.addNewFrame then
            self._drawData:addFrame()
            self:saveDrawing('add frame', c)
        end

        self._toolOptions = nil
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
        if not self.isPlayingAnimation then
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
                if touch.pressed then
                    self._drawData:unlinkCurrentCell()
                end

                self:callSubtoolHandler(subtool, "onTouch", c, childTouchData)
                if touch.released then
                    subtool._hasTouch = false
                    self:loadLastSave()
                else
                    subtool._hasTouch = true
                end
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

    if self.isPlayingAnimation then
        self._drawData:runAnimation(self.animationState, self.animationState, dt)
    end

    if self.viewInContext then
        local actorId = c.actorId
        local animationState = self.animationState

        if animationState == nil then
            animationState = {
                currentFrame = self._drawData.selectedFrame
            }
        end

        self.dependencies.Drawing2:setViewInContextAnimationState(self.dependencies.Drawing2:get(actorId), animationState)
    end
end

-- Draw

function DrawTool:getIsBackgroundDark()
    local bgColor = self.game.sceneProperties.backgroundColor
    local brightness = (bgColor.r * 299 + bgColor.g * 587 + bgColor.b * 114) / 1000;
    return brightness < 0.5
end

function DrawTool.handlers:isFullScreen()
    return not self.viewInContext
end

function DrawTool.handlers:drawOverlay()
    if not self:isActive() then
        return
    end

    if self.viewInContext then
        return
    end

    local windowWidth, windowHeight = love.graphics.getDimensions()
    -- DrawingCardHeader.js height is 180 and DrawingCardBottomActions.js height is 80
    local topOffset = 0.5 * (self.viewWidth * VIEW_HEIGHT_TO_WIDTH_RATIO - ((200 + 64) / (windowWidth / self.viewWidth)))

    love.graphics.push()

    self._viewTransform:reset()
    self._viewTransform:scale(windowWidth / self.viewWidth)
    self._viewTransform:translate(-self.viewX, -self.viewY)
    self._viewTransform:translate(0.5 * self.viewWidth, topOffset)
    love.graphics.applyTransform(self._viewTransform)

    local bgColor = self.game.sceneProperties.backgroundColor
    love.graphics.clear(bgColor.r, bgColor.g, bgColor.b)

    love.graphics.setColor(1, 1, 1, 1)

    if self._selectedSubtools.root ~= 'artwork' then
        self._drawData:render(self.animationState)

        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle('fill', -DRAW_MAX_SIZE * 2.0, -DRAW_MAX_SIZE * 2.0, DRAW_MAX_SIZE * 4.0, DRAW_MAX_SIZE * 4.0)
    end

    -- grid
    if self:getIsBackgroundDark() then
        love.graphics.setColor(1.0, 1.0, 1.0, 0.2)
        drawGrid(self._drawData:gridCellSize(), DRAW_MAX_SIZE + self._drawData:gridCellSize() * 0.5, self:getViewScale(), self.viewX, self.viewY, 0.5 * self.viewWidth, topOffset, 2, true, 0.5)
    else
        love.graphics.setColor(0.0, 0.0, 0.0, 0.1)
        drawGrid(self._drawData:gridCellSize(), DRAW_MAX_SIZE + self._drawData:gridCellSize() * 0.5, self:getViewScale(), self.viewX, self.viewY, 0.5 * self.viewWidth, topOffset, 2, true, 0.3)
    end

    if self._selectedSubtools.root == 'artwork' then
        love.graphics.setColor(1, 1, 1, 1)

        self._drawData:renderForTool(self.animationState, self.tempTranslateX, self.tempTranslateY, self._tempGraphics)
    end

    if self.isOnionSkinningEnabled and not self.isPlayingAnimation then
        if not self.onionSkinningCanvas then
            self.onionSkinningCanvas = love.graphics.newCanvas(
                512,
                512,
                {
                    dpiscale = 1,
                    msaa = 4,
                }
            )
        end

        self.onionSkinningCanvas:renderTo(
            function()
                love.graphics.push("all")

                love.graphics.origin()
                love.graphics.scale(512 / (DRAW_MAX_SIZE * 2.0))
                love.graphics.translate(DRAW_MAX_SIZE, DRAW_MAX_SIZE)

                love.graphics.clear(0.0, 0.0, 0.0, 0.0)
                love.graphics.setColor(1, 1, 1, 1)
                self._drawData:renderOnionSkinning()

                love.graphics.pop()
            end
        )

        love.graphics.setColor(1.0, 1.0, 1.0, 0.2)
        love.graphics.draw(self.onionSkinningCanvas, -DRAW_MAX_SIZE, -DRAW_MAX_SIZE, 0, DRAW_MAX_SIZE * 2.0 / 512.0, DRAW_MAX_SIZE * 2.0 / 512.0)
    end

    love.graphics.setColor(1, 1, 1, 1)

    if self._selectedSubtools.root == 'artwork' then
        self._physicsBodyData:draw()
    end

    if self._selectedSubtools.root == "artwork" and self._selectedSubtools.artwork == "artwork_move" and self._selectedSubtools.artwork_move == "move" then
        local movePoints = {}

        for i = 1, #self._drawData:currentPathDataList() do
            if not self._drawData:currentPathDataList()[i].isFreehand then
                for p = 1, #self._drawData:currentPathDataList()[i].points do
                    table.insert(movePoints, self._drawData:currentPathDataList()[i].points[p].x)
                    table.insert(movePoints, self._drawData:currentPathDataList()[i].points[p].y)
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

    local subtool = self:getCurrentSubtool()
    if subtool then
        love.graphics.setColor(1.0, 1.0, 1.0, 1.0)
        self:callSubtoolHandler(subtool, "drawOverlay")
    end

    if TEST_POINT ~= nil then
        love.graphics.setColor(0.0, 1.0, 0.0, 1.0)
        love.graphics.setPointSize(30)

        love.graphics.points(TEST_POINT.x, TEST_POINT.y)
    end

    love.graphics.pop()
end

-- UI

function DrawTool:setIsPlayingAnimation(c, isPlayingAnimation)
    self.isPlayingAnimation = isPlayingAnimation

    if isPlayingAnimation then
        local actorId = c.actorId

        self.animationState = self._drawData:newAnimationState()
        self.animationState.playing = true
        self.animationState.loop = true
        self.animationState.framesPerSecond = self.dependencies.Drawing2:get(actorId).properties.framesPerSecond
        self.animationState.currentFrame = 1
    else
        self.animationState = nil
    end
end

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
        self.viewInContext = false
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

    actions['onViewInContext'] = function(viewInContext)
        local actorId = c.actorId

        if viewInContext == 'true' then
            self.viewInContext = true
        else
            self.viewInContext = false

            local actorId = c.actorId
            self.dependencies.Drawing2:setViewInContextAnimationState(self.dependencies.Drawing2:get(actorId), nil)
        end
    end

    actions['updateColor'] = function(opts)
        self._drawData:updateColor(opts.r, opts.g, opts.b)
        self:saveDrawing("update color", c)
    end

    actions['onClearArtwork'] = function()
        self._drawData:clearFrame()
        self:saveDrawing('clear all artwork', c)
    end

    actions['onClearCollisionShapes'] = function()
        self._physicsBodyData = PhysicsBodyData:new()
        self:saveDrawing('clear all collision shapes', c)
    end

    ui.fastData("draw-tools", {
        selectedSubtools = self._selectedSubtools,
        color = self._drawData.color,
    }, {
        actions = actions,
    })

    local layerActions = {}

    layerActions['onAddLayer'] = function()
        self._drawData:addLayer()
        self:saveDrawing('add layer', c)
    end

    layerActions['onAddFrame'] = function()
        self._drawData:addFrame()
        self:saveDrawing('add frame', c)
    end

    layerActions['onAddFrameAtPosition'] = function(position)
        self._drawData:addFrameAtPosition(position)
        self:saveDrawing('add frame', c)
    end

    layerActions['onSelectLayer'] = function(layerId)
        self:setIsPlayingAnimation(c, false)
        self._drawData:selectLayer(layerId)
        self:saveDrawing('select layer', c)
    end

    layerActions['onSelectFrame'] = function(frame)
        self:setIsPlayingAnimation(c, false)
        self._drawData:selectFrame(frame)
        self:saveDrawing('select frame', c)
    end

    layerActions['onSelectLayerAndFrame'] = function(layerAndFrame)
        self:setIsPlayingAnimation(c, false)
        self._drawData:selectLayer(layerAndFrame.layerId)
        self._drawData:selectFrame(layerAndFrame.frame)
        self:saveDrawing('select cell', c)
    end

    layerActions['onDeleteLayer'] = function(layerId)
        self._drawData:deleteLayer(layerId)
        self:saveDrawing('delete layer', c)
    end

    layerActions['onDeleteFrame'] = function(frame)
        self._drawData:deleteFrame(frame)
        self:saveDrawing('delete frame', c)
    end

    layerActions['onSetCellLinked'] = function(opts)
        self._drawData:setCellLinked(opts.layerId, opts.frame, opts.isLinked)

        if opts.isLinked then
            self:saveDrawing('link cell', c)
        else
            self:saveDrawing('unlink cell', c)
        end
    end

    layerActions['onSetLayerIsVisible'] = function(opts)
        self._drawData:setLayerIsVisible(opts.layerId, opts.isVisible)
        self:saveDrawing('update layer visibility', c)
    end

    layerActions['onReorderLayers'] = function(opts)
        self._drawData:reorderLayers(opts)
        self:saveDrawing('reorder layer', c)
    end

    layerActions['onSetIsPlayingAnimation'] = function(isPlayingAnimation)
        self:setIsPlayingAnimation(c, isPlayingAnimation)
    end

    layerActions['onStepBackward'] = function(opts)
        self._drawData:stepBackward(opts)
    end

    layerActions['onStepForward'] = function(opts)
        self._drawData:stepForward(opts)
    end

    layerActions['onSetIsOnionSkinningEnabled'] = function(isOnionSkinningEnabled)
        self.isOnionSkinningEnabled = isOnionSkinningEnabled
    end

    layerActions['onCopyCell'] = function(opts)
        self._copiedCell = self._drawData:copyCell(opts.layerId, opts.frame)
    end

    layerActions['onPasteCell'] = function(opts)
        if self._copiedCell then
            self._drawData:pasteCell(opts.layerId, opts.frame, util.deepCopyTable(self._copiedCell))
            self:saveDrawing('paste cell', c)
        end
    end

    local layerData = self._drawData:getLayerData()
    layerData.isPlayingAnimation = self.isPlayingAnimation
    layerData.isOnionSkinningEnabled = self.isOnionSkinningEnabled
    layerData.canPaste = self._copiedCell ~= nil
    ui.fastData('draw-layers', layerData, {
        actions = layerActions,
    })
end
