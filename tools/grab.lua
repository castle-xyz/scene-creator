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
            }
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

local gridShader

if GRID_SHADER then
    gridShader = GRID_SHADER
elseif love.graphics then
    gridShader =
        love.graphics.newShader(
        [[
        uniform float gridSize;
        uniform float dotRadius;
        uniform vec2 offset;
        vec4 effect(vec4 color, Image tex, vec2 texCoords, vec2 screenCoords)
        {
            vec2 f = mod(screenCoords + offset + dotRadius, gridSize);
            float l = length(f - dotRadius);
            float s = 1.0 - smoothstep(dotRadius - 1.0, dotRadius + 1.0, l);
            return vec4(color.rgb, s * color.a);
        }
    ]],
        [[
        vec4 position(mat4 transformProjection, vec4 vertexPosition)
        {
            return transformProjection * vertexPosition;
        }
    ]]
    )
end

function GrabTool:drawGrid()
    if self._gridEnabled and self._gridSize > 0 then
        love.graphics.push("all")

        local windowWidth, windowHeight = love.graphics.getDimensions()

        local dpiScale = love.graphics.getDPIScale()
        local gridSize = self._gridSize * 2
        gridShader:send("gridSize", dpiScale * gridSize * self.game:getViewScale())
        gridShader:send("dotRadius", dpiScale * 2)
        gridShader:send(
            "offset",
            {
                dpiScale * (self.game.viewX % gridSize - 0.5 * self.game.viewWidth) * self.game:getViewScale(),
                dpiScale * (self.game.viewY % gridSize - self.game:getYOffset()) * self.game:getViewScale()
            }
        )
        love.graphics.setShader(gridShader)

        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.origin()
        love.graphics.rectangle("fill", 0, 0, windowWidth, windowHeight)

        love.graphics.pop()
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
