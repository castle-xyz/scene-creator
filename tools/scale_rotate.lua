local ScaleRotateTool =
    defineCoreBehavior {
    name = "ScaleRotate",
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

function ScaleRotateTool.handlers:addBehavior(opts)
    self._gridEnabled = true
    self._gridSize, self._gridSize = 0.5 * UNIT, 0.5 * UNIT

    self._rotateIncrementEnabled = true
    self._rotateIncrementDegrees = 5
end

-- Methods

function ScaleRotateTool:getHandles()
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
                local unitVecX = i
                local unitVecY = j

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

function ScaleRotateTool:rotate(rotation, pivotX, pivotY)
    local before, after = {}, {}
    local actorIds = {}

    for actorId, component in pairs(self.components) do
        if self.game.clientId == component.clientId then
            table.insert(actorIds, actorId)

            local bodyId, body = self.dependencies.Body:getBody(actorId)

            local angle = body:getAngle()
            local newAngle = angle + rotation
            
            before[actorId] = {angle = angle}
            after[actorId] = {angle = newAngle}
        end
    end

    local touchData = self:getTouchData()

    self:command(
        "rotate",
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
                physics:setAngle(sendOpts, bodyId, values.angle)
            end
        end
    )
end

-- Update

function ScaleRotateTool.handlers:preUpdate(dt)
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

function ScaleRotateTool.handlers:update(dt)
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
                    local desiredWidth, desiredHeight = math.abs(touch.x - handle.oppositeX), math.abs(touch.y - handle.oppositeY)
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

                    local angle = body:getAngle()
                    local offsetX = newWidth * handle.unitVecX * 0.5
                    local offsetY = newHeight * handle.unitVecY * 0.5

                    local newx = handle.oppositeX + math.cos(angle) * offsetX - math.sin(angle) * offsetY
                    local newy = handle.oppositeY + math.cos(angle) * offsetY + math.sin(angle) * offsetX

                    if newWidth and newHeight then
                        self:command(
                            "resize",
                            {
                                coalesceSuffix = touchData.gestureId .. "-" .. actorId,
                                paramOverrides = {
                                    ["do"] = {width = newWidth, height = newHeight, position = {x = newx, y = newy}},
                                    ["undo"] = {width = handle.width, height = handle.height, position = {x = worldx, y = worldy}}
                                },
                                params = {
                                    gestureEnded = touchData.allTouchesReleased
                                }
                            },
                            function(params)
                                self.dependencies.Body:setRectangleShape(actorId, params.width, params.height)

                                local physics = self.dependencies.Body:getPhysics()
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
                self:rotate(rotation, handle.pivotX, handle.pivotY)
            end

            return -- We processed a handle, skip other gestures
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

function ScaleRotateTool:drawGrid()
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

function ScaleRotateTool.handlers:drawOverlay()
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

function ScaleRotateTool.handlers:uiSettings()
    -- Grid
    ui.box(
        "resize grid box",
        {flexDirection = "row"},
        function()
            self._gridEnabled = ui.toggle("Resize grid snap", "Resize grid snap", self._gridEnabled)
        end
    )

    if self._gridEnabled then
        ui.box(
            "resize grid size box",
            { flex = 1 },
            function()
                self._gridSize = ui.numberInput("Resize grid size", self._gridSize, {min = 0, step = 0.5 * UNIT})
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
