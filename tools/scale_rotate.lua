require('tools.grid_shader')

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
local HANDLE_DRAW_RADIUS = 10

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
        local bounds = self.dependencies.Body:getScaledEditorBounds(singleActorId)

        -- Resizing
        local bodyId, body = self.dependencies.Body:getBody(singleActorId)
        for i = -1, 1, 1 do
            for j = -1, 1, 1 do
                local x, y = body:getWorldPoint(bounds.centerX + i * 0.5 * bounds.width, bounds.centerY + j * 0.5 * bounds.height)
                local oppositeX, oppositeY = body:getWorldPoint(bounds.centerX + i * -0.5 * bounds.width, bounds.centerY + j * -0.5 * bounds.height)
                local unitVecX = i
                local unitVecY = j

                local handle = {
                    x = x,
                    y = y,
                    bodyX = body:getX(),
                    bodyY = body:getY(),
                    oppositeX = oppositeX,
                    oppositeY = oppositeY,
                    unitVecX = unitVecX,
                    unitVecY = unitVecY,
                    singleActorId = singleActorId,
                    width = bounds.width,
                    height = bounds.height,
                    touchRadius = handleTouchRadius
                }
                if i ~= 0 and j ~= 0 then -- Corner
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
        local centerX, centerY = body:getX(), body:getY()
        local rotateYPosition = bounds.minY
        if rotateYPosition > 0 then
            rotateYPosition = 0
        end

        local x, y = body:getWorldPoint(0, rotateYPosition - 8 * handleDrawRadius)
        table.insert(
            handles,
            {
                x = x,
                y = y,
                handleType = "rotate",
                touchRadius = 1.5 * handleTouchRadius, -- Make rotate handles a bit easier to touch
                pivotX = centerX,
                pivotY = centerY,
                endX = centerX,
                endY = centerY
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
        if not touch.beltUsed and touch.pressed then
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

local function rotatePoint(x, y, angle)
    return math.cos(angle) * x - math.sin(angle) * y, math.cos(angle) * y + math.sin(angle) * x
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
                local angle = body:getAngle()

                local desiredWidth, desiredHeight = handle.width, handle.height

                --math.abs(touch.x - handle.oppositeX), math.abs(touch.y - handle.oppositeY)
                if handle.handleType == "corner" then
                    -- rotate touch around handle
                    local touchOffsetX = touch.x - handle.oppositeX
                    local touchOffsetY = touch.y - handle.oppositeY
                    local rotatedTouchOffsetX = math.cos(-angle) * touchOffsetX - math.sin(-angle) * touchOffsetY
                    local rotatedTouchOffsetY = math.cos(-angle) * touchOffsetY + math.sin(-angle) * touchOffsetX

                    desiredWidth, desiredHeight = math.abs(rotatedTouchOffsetX), math.abs(rotatedTouchOffsetY)
                elseif handle.handleType == "width" then
                    desiredWidth = math.sqrt(math.pow(touch.x - handle.oppositeX, 2.0) + math.pow(touch.y - handle.oppositeY, 2.0))
                elseif handle.handleType == "height" then
                    desiredHeight = math.sqrt(math.pow(touch.x - handle.oppositeX, 2.0) + math.pow(touch.y - handle.oppositeY, 2.0))
                end

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

                -- world coordinates
                local oldDistToOriginX = handle.bodyX - handle.oppositeX
                local oldDistToOriginY = handle.bodyY - handle.oppositeY

                -- body coordinates
                local oldDistToOriginXUnrotated, oldDistToOriginYUnrotated = rotatePoint(oldDistToOriginX, oldDistToOriginY, -angle)

                local newDistToOriginXUnrotated = oldDistToOriginXUnrotated * newWidth / handle.width
                local newDistToOriginYUnrotated = oldDistToOriginYUnrotated * newHeight / handle.height

                -- back to world coordinates
                local newDistToOriginX, newDistToOriginY = rotatePoint(newDistToOriginXUnrotated, newDistToOriginYUnrotated, angle)

                local newx = newDistToOriginX + handle.oppositeX
                local newy = newDistToOriginY + handle.oppositeY

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
                            self.dependencies.Body:resize(actorId, params.width, params.height)

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

function ScaleRotateTool:drawGrid()
    if self._gridEnabled then
        love.graphics.setColor(0, 0, 0, 0.5)
        drawGrid(self._gridSize, -1, self.game:getViewScale(), self.game.viewX, self.game.viewY, 0.5 * self.game.viewWidth, self.game:getYOffset(), 2, false)
    end
end

local function drawArrow(arcCenterX, arcCenterY, startRadius, endRadius, startAngle, endAngle)
    local startX = arcCenterX + startRadius * math.cos(startAngle)
    local startY = arcCenterY + startRadius * math.sin(startAngle)
    local endX = arcCenterX + endRadius * math.cos(endAngle)
    local endY = arcCenterY + endRadius * math.sin(endAngle)
    love.graphics.line(startX, startY, endX, endY)
end

function ScaleRotateTool.handlers:drawOverlay()
    if not self:isActive() then
        return
    end

    self:drawGrid()

    love.graphics.setColor(0, 1, 0, 0.8)
    local handleDrawRadius = HANDLE_DRAW_RADIUS * self.game:getPixelScale()
    for _, handle in ipairs(self:getHandles()) do
        love.graphics.circle("fill", handle.x, handle.y, handleDrawRadius)
        if handle.endX and handle.endY then
            local circleRadius = 0.3
            local dist = math.sqrt(math.pow(handle.x - handle.endX, 2.0) + math.pow(handle.y - handle.endY, 2.0))
            local unitX = (handle.endX - handle.x) / dist
            local unitY = (handle.endY - handle.y) / dist
            local distToInnerCircle = dist - circleRadius

            love.graphics.line(handle.x, handle.y, handle.x + distToInnerCircle * unitX, handle.y + distToInnerCircle * unitY)
            love.graphics.circle("line", handle.endX, handle.endY, circleRadius)

            -- arcRadius could also be a fn of dist?
            local zoomAmount = self.game:getZoomAmount()
            local arcRadius = 1.0 * zoomAmount
            local arcAngle = 0.7
            local arcCenterX = handle.x + arcRadius * unitX
            local arcCenterY = handle.y + arcRadius * unitY
            local angle = math.atan2(handle.y - arcCenterY, handle.x - arcCenterX)
            love.graphics.arc("line", "open", arcCenterX, arcCenterY, arcRadius, angle, angle + arcAngle, 10)
            love.graphics.arc("line", "open", arcCenterX, arcCenterY, arcRadius, angle, angle - arcAngle, 10)

            local arrowAngle = 0.15
            local arrowRadius = 0.15 * zoomAmount

            -- right arrow
            drawArrow(arcCenterX, arcCenterY, arcRadius, arcRadius + arrowRadius, angle + arcAngle, angle + arcAngle - arrowAngle)
            drawArrow(arcCenterX, arcCenterY, arcRadius, arcRadius - arrowRadius, angle + arcAngle, angle + arcAngle - arrowAngle)

            -- left arrow
            drawArrow(arcCenterX, arcCenterY, arcRadius, arcRadius + arrowRadius, angle - arcAngle, angle - arcAngle + arrowAngle)
            drawArrow(arcCenterX, arcCenterY, arcRadius, arcRadius - arrowRadius, angle - arcAngle, angle - arcAngle + arrowAngle)
        end
    end
end

-- UI

function ScaleRotateTool.handlers:uiSettings(data, actions)
   data.scaleGridEnabled = self._gridEnabled
   actions.setScaleGridEnabled = function(enabled)
      self._gridEnabled = enabled
   end

   data.scaleGridSize = self._gridSize
   actions.setScaleGridSize = function(size)
      self._gridSize = size -- TODO:
   end

   data.rotateIncrementEnabled = self._rotateIncrementEnabled
   actions.setRotateIncrementEnabled = function(enabled)
      self._rotateIncrementEnabled = enabled
   end

   data.rotateIncrementDegrees = self._rotateIncrementDegrees
   actions.setRotateIncrementDegrees = function(increment)
      self._rotateIncrementDegrees = increment
   end
end
