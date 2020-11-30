
GRID_HORIZONTAL_PADDING = 0.05 * DEFAULT_VIEW_WIDTH
GRID_TOP_PADDING = 0.1 * DEFAULT_VIEW_WIDTH
GRID_WIDTH = DEFAULT_VIEW_WIDTH - GRID_HORIZONTAL_PADDING * 2.0

DRAW_DATA_SCALE = 10.0

BACKGROUND_COLOR = {r = 0.0, g = 0.0, b = 0.0}

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

    for _, subtool in pairs(SUBTOOLS) do
        if subtool.handlers.addSubtool ~= nil then
            --subtool.drawTool = self
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

            self:callSubtoolHandler(subtool, "addSubtool")
        end
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

    for _, subtool in pairs(SUBTOOLS) do
        if subtool.category == currentCategory and subtool.name == currentName then
            return subtool
        end
    end

    return nil
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
        local data = self.dependencies.Drawing2:cacheDrawing(drawingComponent, drawingComponent.properties)

        c._lastHash = drawingComponent.properties.hash
        self._drawData = data.drawData:clone()
        self._physicsBodyData = data.physicsBodyData:clone()

        if self._scaleRotateData and self._scaleRotateData.index and self._scaleRotateData.index > self._physicsBodyData:getNumShapes() then
            self._scaleRotateData.index = self._physicsBodyData:getNumShapes()
        end
    end


    local touchData = self:getTouchData()
    if touchData.numTouches == 1 and touchData.maxNumTouches == 1 then
        -- Get the single touch
        local touchId, touch = next(touchData.touches)
        local touchX, touchY = self._viewTransform:inverseTransformPoint(touch.x, touch.y)

        local roundedX, roundedY = self._drawData:roundGlobalCoordinatesToGrid(touchX, touchY)
        local roundedCoord = {x = roundedX, y = roundedY}
        local clampedX, clampedY = self._drawData:clampGlobalCoordinates(touchX, touchY)
    
        local touchData = {
            touch = touch,
            touchX = touchX,
            touchY = touchY,
            roundedX = roundedX,
            roundedY = roundedY,
            roundedCoord = roundedCoord,
            clampedX = clampedX,
            clampedY = clampedY,
        }

        local subtool = self:getCurrentSubtool()
        if subtool then
            self:callSubtoolHandler(subtool, "onTouch", c, touchData)
        end
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

function DrawTool:drawPoints(points, radius)
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

    self._viewTransform:reset()
    self._viewTransform:translate(GRID_HORIZONTAL_PADDING, GRID_TOP_PADDING)
    self._viewTransform:scale(GRID_WIDTH / self._drawData.scale)
    love.graphics.applyTransform(self._viewTransform)

    love.graphics.clear(BACKGROUND_COLOR.r, BACKGROUND_COLOR.g, BACKGROUND_COLOR.b)

    love.graphics.setColor(1, 1, 1, 1)

    if self._selectedSubtools.root == 'artwork' then
        self._physicsBodyData:draw()
        self._drawData:renderFill()
    else
        self._drawData:renderFill()
        self:drawShapes()

        love.graphics.setColor(0, 0, 0, 0.5)
        local padding = 0.1
        love.graphics.rectangle('fill', -padding, -padding, self._drawData.scale + padding * 2.0, self._drawData.scale + padding * 2.0)
    end

    -- grid
    --if self._selectedSubtools.root ~= 'artwork' or (self._selectedSubtools.artwork_draw == 'line' or self._selectedSubtools.artwork_draw == 'pencil' or self._selectedSubtools.artwork_move == 'move' or self._selectedSubtools.artwork_draw == 'rectangle' or self._selectedSubtools.artwork_draw == 'circle' or self._selectedSubtools.artwork_draw == 'triangle') then
        love.graphics.setColor(0.5, 0.5, 0.5, 1.0)
        --love.graphics.setPointSize(10.0)

        local points = {}

        for x = 1, self._drawData.gridSize do
            for y = 1, self._drawData.gridSize do
                local globalX, globalY = self._drawData:gridToGlobalCoordinates(x, y)
                table.insert(points, globalX)
                table.insert(points, globalY)
            end
        end

        self:drawPoints(points)
    --end

    if self._selectedSubtools.root == 'artwork' then
        self:drawShapes()
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
        love.graphics.setPointSize(30.0)
        love.graphics.points(movePoints)
    end

    if self._selectedSubtools.root == 'collision' then
        self._physicsBodyData:draw()

        if self._selectedSubtools.collision == 'collision_move' and self._selectedSubtools.collision_move == 'scale-rotate' and self._scaleRotateData.index then
            love.graphics.setColor(1.0, 0.0, 0.0, 1.0)
            love.graphics.setPointSize(30.0)
            --love.graphics.points()

            local handleDrawRadius = HANDLE_DRAW_RADIUS * self.game:getPixelScale()
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
        love.graphics.setPointSize(30.0)

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
