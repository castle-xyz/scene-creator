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

local HANDLE_TOUCH_RADIUS = 30
local HANDLE_DRAW_RADIUS = 12

-- Behavior management

function GrabTool.handlers:addBehavior(opts)
    self._gridEnabled = true
    self._gridSize, self._gridSize = 0.5 * UNIT, 0.5 * UNIT

    self._rotateIncrementEnabled = true
    self._rotateIncrementDegrees = 5
end

-- Methods

function GrabTool:getHandles()
    if self.game.performing then
        return {}
    end

    local handleTouchRadius = HANDLE_TOUCH_RADIUS * self.game:getPixelScale()
    local handleDrawRadius = HANDLE_DRAW_RADIUS * self.game:getPixelScale()

    local handles = {}

    -- Single selection?
    local singleActorId
    for actorId, component in pairs(self.components) do
        if self.game.clientId == component.clientId then
            if singleActorId then
                singleActorId = nil
                break
            end
            singleActorId = actorId
        end
    end

    if singleActorId then
        -- Figure out shape type and dimensions
        local shapeType
        local width, height = self.dependencies.Body:getRectangleSize(singleActorId)
        if width and height then
            shapeType = "rectangle"
        else
            width, height = self.dependencies.Body:getSize(singleActorId)
            local bodyId, body = self.dependencies.Body:getBody(singleActorId)
            local fixture = body:getFixtures()[1]
            if fixture then
                local shape = fixture:getShape()
                shapeType = shape:getType()
            end
        end
        if not shapeType then
            return {}
        end

        -- Resizing
        local bodyId, body = self.dependencies.Body:getBody(singleActorId)
        for i = -1, 1, 1 do
            for j = -1, 1, 1 do
                local x, y = body:getWorldPoint(i * 0.5 * width, j * 0.5 * height)
                local oppositeX, oppositeY = body:getWorldPoint(i * -0.5 * width, j * -0.5 * height)
                local unitVecX = x - oppositeX
                local unitVecY = y - oppositeY
                local dist = math.sqrt(math.pow(unitVecX, 2.0) + math.pow(unitVecY, 2.0))
                unitVecX = unitVecX / dist
                unitVecY = unitVecY / dist

                local handle = {
                    x = x,
                    y = y,
                    oppositeX = oppositeX,
                    oppositeY = oppositeY,
                    unitVecX = unitVecX,
                    unitVecY = unitVecY,
                    singleActorId = singleActorId,
                    width = width,
                    height = height,
                    shapeType = shapeType,
                    touchRadius = handleTouchRadius
                }
                if shapeType == "rectangle" and i ~= 0 and j ~= 0 then -- Corner
                    handle.handleType = "corner"
                    table.insert(handles, handle)
                elseif i ~= 0 and j == 0 then -- Width edge
                    handle.handleType = "width"
                    table.insert(handles, handle)
                elseif i == 0 and j ~= 0 then -- Height edge
                    handle.handleType = "height"
                    table.insert(handles, handle)
                end
            end
        end

        -- Rotation
        local centerX, centerY = body:getWorldPoint(0, 0)
        local x, y = body:getWorldPoint(0, -0.5 * height - 6 * handleDrawRadius)
        local endX, endY = body:getWorldPoint(0, -0.5 * height)
        table.insert(
            handles,
            {
                x = x,
                y = y,
                handleType = "rotate",
                touchRadius = 1.5 * handleTouchRadius, -- Make rotate handles a bit easier to touch
                pivotX = centerX,
                pivotY = centerY,
                endX = endX,
                endY = endY
            }
        )
        return handles
    else -- Multiple selections
        -- TODO(nikki): Multiple selections
    end

    return handles
end

function GrabTool:moveRotate(description, moveX, moveY, rotation, pivotX, pivotY)
    -- Move and rotate multiple actors around a pivot. `rotation` may be `nil` to skip.

    --if not (moveX ~= 0 or moveY ~= 0 or (rotation and rotation ~= 0)) then
    --    return
    --end

    local cosRotation, sinRotation
    if rotation then
        cosRotation, sinRotation = math.cos(rotation), math.sin(rotation)
    end

    local before, after = {}, {}
    local actorIds = {}

    for actorId, component in pairs(self.components) do
        if self.game.clientId == component.clientId then
            table.insert(actorIds, actorId)

            local bodyId, body = self.dependencies.Body:getBody(actorId)

            local x, y = body:getPosition()
            local angle = body:getAngle()

            local newX, newY, newAngle
            if rotation then
                local lX, lY = x - pivotX, y - pivotY
                lX = cosRotation * lX - sinRotation * lY
                lY = sinRotation * lX + cosRotation * lY
                if self._gridEnabled then
                    lX = util.quantize(lX, self._gridSize, x - pivotX)
                    lY = util.quantize(lY, self._gridSize, y - pivotY)
                end
                newX, newY = pivotX + moveX + lX, pivotY + moveY + lY
                newAngle = angle + rotation
            else
                newX, newY = x + moveX, y + moveY
                newAngle = angle
            end

            before[actorId] = {x = x, y = y, angle = angle}
            after[actorId] = {x = newX, y = newY, angle = newAngle}
        end
    end

    local touchData = self:getTouchData()

    self:command(
        description,
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
                physics:setAngle(sendOpts, bodyId, values.angle)
            end
        end
    )
end

-- Update

function GrabTool.handlers:preUpdate(dt)
    if not self:isActive() then
        return
    end

    -- Check for handle touches and steal them
    local touchData = self:getTouchData()
    if touchData.numTouches == 1 then
        local touchId, touch = next(touchData.touches)
        if touch.pressed then
            for _, handle in ipairs(self:getHandles()) do
                local distX, distY = handle.x - touch.x, handle.y - touch.y
                if distX * distX + distY * distY <= handle.touchRadius * handle.touchRadius then
                    touch.grabHandle = handle
                    touch.used = true
                    break
                end
            end
        end
    end
end

function GrabTool.handlers:update(dt)
    if not self:isActive() then
        return
    end

    local touchData = self:getTouchData()

    -- Continuing a handle gesture?
    if touchData.numTouches == 1 then
        local touchId, touch = next(touchData.touches)
        if touch.grabHandle then
            local handle = touch.grabHandle

            if handle.singleActorId then -- Single actor?
                local actorId = handle.singleActorId
                local bodyId, body = self.dependencies.Body:getBody(actorId)

                local worldx, worldy = body:getPosition()
                local lx, ly = body:getLocalPoint(touch.x, touch.y)

                if handle.shapeType == "rectangle" then
                    local desiredWidth, desiredHeight = 2 * math.abs(lx), 2 * math.abs(ly)
                    if self._gridEnabled then
                        desiredWidth = util.quantize(desiredWidth, self._gridSize)
                        desiredHeight = util.quantize(desiredHeight, self._gridSize)
                    end
                    desiredWidth = math.max(MIN_BODY_SIZE, math.min(desiredWidth, MAX_BODY_SIZE))
                    desiredHeight = math.max(MIN_BODY_SIZE, math.min(desiredHeight, MAX_BODY_SIZE))
                    local newWidth, newHeight
                    if handle.handleType == "corner" then
                        local s = math.max(desiredWidth / handle.width, desiredHeight / handle.height)
                        newWidth, newHeight = s * handle.width, s * handle.height
                    elseif handle.handleType == "width" then
                        newWidth, newHeight = desiredWidth, handle.height
                    elseif handle.handleType == "height" then
                        newWidth, newHeight = handle.width, desiredHeight
                    end
                    if newWidth and newHeight then
                        self:command(
                            "resize",
                            {
                                coalesceSuffix = touchData.gestureId .. "-" .. actorId,
                                paramOverrides = {
                                    ["do"] = {width = newWidth, height = newHeight},
                                    ["undo"] = {width = handle.width, height = handle.height}
                                }
                            },
                            function(params)
                                self.dependencies.Body:setRectangleShape(actorId, params.width, params.height)
                            end
                        )
                    end
                elseif handle.shapeType == "circle" then
                    local desiredRadius = 0.5 * math.sqrt(math.pow(touch.x - handle.oppositeX, 2.0) + math.pow(touch.y - handle.oppositeY, 2.0))
                    if self._gridEnabled then
                        desiredRadius = util.quantize(desiredRadius, 0.5 * self._gridSize)
                    end
                    desiredRadius = math.max(0.5 * MIN_BODY_SIZE, math.min(desiredRadius, 0.5 * MAX_BODY_SIZE))

                    local newx = handle.oppositeX + desiredRadius * handle.unitVecX
                    local newy = handle.oppositeY + desiredRadius * handle.unitVecY

                    self:command(
                        "resize",
                        {
                            coalesceSuffix = touchData.gestureId .. "-" .. actorId,
                            paramOverrides = {
                                ["do"] = {radius = desiredRadius, position = {x = newx, y = newy}},
                                ["undo"] = {radius = 0.5 * handle.width, position = {x = worldx, y = worldy}}
                            },
                            params = {
                                gestureEnded = touchData.allTouchesReleased
                            }
                        },
                        function(params)
                            local physics = self.dependencies.Body:getPhysics()
                            self.dependencies.Body:setShape(actorId, physics:newCircleShape(params.radius))

                            local reliable = params.gestureEnded or not live
                            local sendOpts = {
                                reliable = reliable,
                                channel = reliable and physics.reliableChannel or nil
                            }
                            local bodyId, body = self.dependencies.Body:getBody(actorId)
                            physics:setPosition(sendOpts, bodyId, params.position.x, params.position.y)
                        end
                    )
                end
            end

            if handle.handleType == "rotate" then
                local angle = math.atan2(touch.y - handle.pivotY, touch.x - handle.pivotX)
                local prevAngle = math.atan2(touch.y - touch.dy - handle.pivotY, touch.x - touch.dx - handle.pivotX)
                if self._rotateIncrementEnabled then
                    local increment = self._rotateIncrementDegrees * math.pi / 180
                    local initialAngle = math.atan2(touch.initialX - handle.pivotY, touch.initialY - handle.pivotX)
                    angle = util.quantize(angle, increment, initialAngle)
                    prevAngle = util.quantize(prevAngle, increment, initialAngle)
                end
                rotation = angle - prevAngle
                self:moveRotate("rotate", 0, 0, rotation, handle.pivotX, handle.pivotY)
            end

            return -- We processed a handle, skip other gestures
        end
    end

    -- No handle gestures, check for other gestures
    local moved = false
    for touchId, touch in pairs(touchData.touches) do
        if touch.x ~= touch.initialX or touch.y ~= touch.initialY then
            moved = true
        end
    end
    if moved and touchData.numTouches == 1 or touchData.numTouches == 2 then
        local moveX, moveY = 0, 0
        local rotation
        local centerX, centerY

        if touchData.numTouches == 1 then -- 1-finger move
            local touchId, touch = next(touchData.touches)
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
        elseif touchData.numTouches == 2 then -- 2-finger move and rotate
            local touchId1, touch1 = next(touchData.touches)
            local touchId2, touch2 = next(touchData.touches, touchId1)
            touch1.used = true
            touch2.used = true

            local touch1PrevX, touch1PrevY = touch1.x - touch1.dx, touch1.y - touch1.dy
            local touch2PrevX, touch2PrevY = touch2.x - touch2.dx, touch2.y - touch2.dy

            centerX, centerY = 0.5 * (touch1.x + touch2.x), 0.5 * (touch1.y + touch2.y)
            local centerPrevX, centerPrevY = 0.5 * (touch1PrevX + touch2PrevX), 0.5 * (touch1PrevY + touch2PrevY)

            if self._gridEnabled then
                local centerInitialX = 0.5 * (touch1.initialX + touch2.initialX)
                local centerInitialY = 0.5 * (touch1.initialY + touch2.initialY)

                centerPrevX = util.quantize(centerPrevX, self._gridSize, centerInitialX)
                centerPrevY = util.quantize(centerPrevY, self._gridSize, centerInitialY)

                centerX = util.quantize(centerX, self._gridSize, centerInitialX)
                centerY = util.quantize(centerY, self._gridSize, centerInitialY)
            end

            moveX, moveY = centerX - centerPrevX, centerY - centerPrevY

            local angle = math.atan2(touch2.y - touch1.y, touch2.x - touch1.x)
            local prevAngle = math.atan2(touch2PrevY - touch1PrevY, touch2PrevX - touch1PrevX)
            if self._rotateIncrementEnabled then
                local increment = self._rotateIncrementDegrees * math.pi / 180
                local initialAngle = math.atan2(touch2.initialY - touch1.initialY, touch2.initialX - touch1.initialX)
                angle = util.quantize(angle, increment, initialAngle)
                prevAngle = util.quantize(prevAngle, increment, initialAngle)
            end
            rotation = angle - prevAngle
        end

        local description = touchData.maxNumTouches > 1 and "move and rotate" or "move"
        self:moveRotate(description, moveX, moveY, rotation, centerX, centerY)
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
        gridShader:send("gridSize", dpiScale * self._gridSize * self.game:getViewScale())
        gridShader:send("dotRadius", dpiScale * 2)
        gridShader:send(
            "offset",
            {
                dpiScale * (self.game.viewX % self._gridSize - 0.5 * self.game.viewWidth) * self.game:getViewScale(),
                dpiScale * (self.game.viewY % self._gridSize - 0.5 * self.game.viewWidth) * self.game:getViewScale()
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

    local handleDrawRadius = HANDLE_DRAW_RADIUS * self.game:getPixelScale()
    for _, handle in ipairs(self:getHandles()) do
        love.graphics.circle("fill", handle.x, handle.y, handleDrawRadius)
        if handle.endX and handle.endY then
            love.graphics.line(handle.x, handle.y, handle.endX, handle.endY)
        end
    end
end

-- UI

function GrabTool.handlers:uiSettings()
    -- Grid
    ui.box(
        "grid box",
        {flexDirection = "row"},
        function()
            self._gridEnabled = ui.toggle("Grid snap", "Grid snap", self._gridEnabled)
        end
    )

    if self._gridEnabled then
        ui.box(
            "grid size box",
            { flex = 1 },
            function()
                self._gridSize = ui.numberInput("Grid size", self._gridSize, {min = 0, step = 0.5 * UNIT})
            end
        )
    end

    -- Rotate increment
    ui.box(
        "rotate increment box",
        {flexDirection = "row"},
        function()
            self._rotateIncrementEnabled = ui.toggle("Rotation snap", "Rotation snap", self._rotateIncrementEnabled)
        end
    )

    if self._rotateIncrementEnabled then
        ui.box(
            "rotate increment value box",
            {
                flex = 1
            },
            function()
                self._rotateIncrementDegrees =
                    ui.numberInput("Increment (degrees)", self._rotateIncrementDegrees, {min = 0, step = 5})
            end
        )
    end
end
