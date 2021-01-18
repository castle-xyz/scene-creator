require('tools.grid_shader')

local GrabTool =
    defineCoreBehavior {
    name = "Grab",
    propertyNames = {},
    dependencies = {
        "Body"
    },
    tool = {
        icon = "mouse-pointer",
        iconFamily = "FontAwesome5",
        needsPerformingOff = true,
        emptySelect = true
    }
}

-- Behavior management

function GrabTool.handlers:addBehavior(opts)
    self._gridEnabled = true
    self._gridSize, self._gridSize = 0.25 * UNIT, 0.25 * UNIT
end

-- Methods

function GrabTool:move(moveX, moveY)
    local before, after = {}, {}
    local actorIds = {}

    for actorId, component in pairs(self.components) do
        if self.game.clientId == component.clientId then
            table.insert(actorIds, actorId)

            local bodyId, body = self.dependencies.Body:getBody(actorId)

            local x, y = body:getPosition()

            local newX, newY
            newX, newY = x + moveX, y + moveY

            before[actorId] = {x = x, y = y}
            after[actorId] = {x = newX, y = newY}
        end
    end

    local touchData = self:getTouchData()

    -- Don't save undos when placing from belt, belt logic adds a coalesced
    -- "add actor" command at the end of the gesture
    local noSaveUndo = false
    for touchId, touch in pairs(touchData.touches) do
        if touch.beltPlaced then
            noSaveUndo = true
        end
    end

    self:command(
        "move",
        {
            coalesceSuffix = touchData.gestureId .. "-" .. table.concat(actorIds, "-"),
            paramOverrides = {
                ["do"] = {values = after},
                ["undo"] = {values = before}
            },
            params = {
                gestureEnded = touchData.allTouchesReleased
            },
            noSaveUndo = noSaveUndo
        },
        function(params, live)
            -- Make sure actors still exist
            for actorId, values in pairs(params.values) do
                local bodyId, body = self.dependencies.Body:getBody(actorId)
                if not bodyId then
                    return "actor was deleted"
                end
            end

            -- Decide whether messages will be reliable, then send the messages
            local physics = self.dependencies.Body:getPhysics()
            local reliable = params.gestureEnded or not live
            local sendOpts = {
                reliable = reliable,
                channel = reliable and physics.reliableChannel or nil
            }
            for actorId, values in pairs(params.values) do
                local bodyId, body = self.dependencies.Body:getBody(actorId)
                physics:setPosition(sendOpts, bodyId, values.x, values.y)
            end
        end
    )
end

function GrabTool:getGridSize()
    return self._gridSize
end

-- Update

function GrabTool.handlers:preUpdate(dt)
    if not self:isActive() then
        return
    end
end

function GrabTool.handlers:update(dt)
    if not self:isActive() then
        return
    end

    local touchData = self:getTouchData()

    local moved = false
    for touchId, touch in pairs(touchData.touches) do
        if touch.x ~= touch.initialX or touch.y ~= touch.initialY then
            moved = true
        end
    end
    if moved and touchData.numTouches == 1 then
        local moveX, moveY = 0, 0

        local touchId, touch = next(touchData.touches)
        if not touch.beltUsed then
            touch.used = true
            if self._gridEnabled then
                local touchPrevX, touchPrevY = touch.x - touch.dx, touch.y - touch.dy

                local qTouchPrevX = util.quantize(touchPrevX, self._gridSize, touch.initialX)
                local qTouchPrevY = util.quantize(touchPrevY, self._gridSize, touch.initialY)

                local qTouchX = util.quantize(touch.x, self._gridSize, touch.initialX)
                local qTouchY = util.quantize(touch.y, self._gridSize, touch.initialY)

                moveX, moveY = qTouchX - qTouchPrevX, qTouchY - qTouchPrevY
            else
                moveX, moveY = touch.dx, touch.dy
            end

            self:move(moveX, moveY)
        end
    end
end

-- Draw

function GrabTool:drawGrid()
    if self._gridEnabled and self._gridSize > 0 then
        love.graphics.setColor(0, 0, 0, 0.5)
        drawGrid(self._gridSize * 2, -1, self.game:getViewScale(), self.game.viewX, self.game.viewY, 0.5 * self.game.viewWidth, self.game:getYOffset(), 2, false, 0.0)
    end
end

function GrabTool.handlers:drawOverlay()
    if not self:isActive() then
        return
    end

    self:drawGrid()
end

-- UI

function GrabTool.handlers:uiSettings(data, actions)
   data.dragGridEnabled = self._gridEnabled
   actions.setDragGridEnabled = function(enabled)
      self._gridEnabled = enabled
   end

   data.dragGridSize = self._gridSize
   actions.setDragGridSize = function(size)
      self._gridSize = size -- TODO: * UNIT
   end
end
