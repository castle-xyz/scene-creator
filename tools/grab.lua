local GrabTool = {
    name = 'Grab',
    propertyNames = {
    },
    dependencies = {
        'Body',
    },
    handlers = {},
    tool = {
        icon = 'move',
        iconFamily = 'Feather',
    },
}

registerCoreBehavior(GrabTool)


local HANDLE_TOUCH_RADIUS = 18
local HANDLE_DRAW_RADIUS = 10


-- Methods

function GrabTool:getHandles()
    local handles = {}

    if not self.game.performing then
        -- Single, rectangle-shaped selection?
        local singleRectangleActorId
        local singleRectangleWidth, singleRectangleHeight
        for actorId, component in pairs(self.components) do
            if self.game.clientId == component.clientId then
                if singleRectangleActorId then -- Multiple?
                    singleRectangleActorId = nil
                    singleRectangleWidth, singleRectangleHeight = nil
                    break
                end
                singleRectangleWidth, singleRectangleHeight = self.dependencies.Body:getRectangleSize(actorId)
                if singleRectangleWidth and singleRectangleHeight then -- Found a candidate
                    singleRectangleActorId = actorId
                else -- Found non-rectangle
                    break
                end
            end
        end
        if singleRectangleActorId then
            local bodyId, body = self.dependencies.Body:getBody(singleRectangleActorId)
            for i = -1, 1, 1 do
                for j = -1, 1, 1 do
                    local x, y = body:getWorldPoint(i * 0.5 * singleRectangleWidth, j * 0.5 * singleRectangleHeight)
                    if i ~= 0 and j ~= 0 then -- Corner
                        table.insert(handles, {
                            x = x,
                            y = y,
                            actorId = singleRectangleActorId,
                            rectangleWidth = singleRectangleWidth,
                            rectangleHeight = singleRectangleHeight,
                            handleType = 'rectangleCornerResize',
                        })
                    elseif i ~= 0 or j ~= 0 then -- Edge
                        table.insert(handles, {
                            x = x,
                            y = y,
                            actorId = singleRectangleActorId,
                            rectangleWidth = singleRectangleWidth,
                            rectangleHeight = singleRectangleHeight,
                            handleType = i ~= 0 and 'rectangleWidthResize' or 'rectangleHeightResize',
                        })
                    end
                end
            end
            do -- Rotate
                local centerX, centerY = body:getWorldPoint(0, 0)
                local x, y = body:getWorldPoint(0, -0.5 * singleRectangleHeight - 8 * HANDLE_DRAW_RADIUS)
                local endX, endY = body:getWorldPoint(0, -0.5 * singleRectangleHeight) 
                table.insert(handles, {
                    x = x,
                    y = y,
                    handleType = 'rotate',
                    pivotX = centerX,
                    pivotY = centerY,
                    endX = endX,
                    endY = endY,
                })
            end
        end
    end

    return handles
end

function GrabTool:moveRotate(moveX, moveY, rotation, pivotX, pivotY)
    -- Move and rotate multiple actors around a pivot. `rotation` may be `nil` to skip.

    local physics = self.dependencies.Body:getPhysics()
    local touchData = self:getTouchData()

    local cosRotation, sinRotation 
    if rotation then
        cosRotation, sinRotation = math.cos(rotation), math.sin(rotation)
    end

    for actorId, component in pairs(self.components) do
        if self.game.clientId == component.clientId then
            local bodyId, body = self.dependencies.Body:getBody(actorId)

            local x, y
            local angle

            -- We use these `.save` values to override stale incoming updates to the body
            -- from other hosts that had not yet received the `setPerforming` message
            if component.save then
                x, y = component.save.x, component.save.y
                angle = component.save.angle
            else
                x, y = body:getPosition()
                angle = body:getAngle()
            end

            local newX, newY, newAngle
            if rotation then
                local lX, lY = x - pivotX, y - pivotY
                lX = cosRotation * lX - sinRotation * lY
                lY = sinRotation * lX + cosRotation * lY
                newX, newY = pivotX + moveX + lX, pivotY + moveY + lY
                newAngle = angle + rotation
            else
                newX, newY = x + moveX, y + moveY
                newAngle = angle
            end

            -- When not performing we need to actually send the sync messages. We also send a
            -- reliable message on gesture end to make sure the final state is reflected.
            local sendOpts = {
                reliable = touchData.allTouchesReleased,
                channel = touchData.allTouchesReleased and physics.reliableChannel or nil,
            }
            physics:setPosition(sendOpts, bodyId, newX, newY)
            physics:setAngle(sendOpts, bodyId, newAngle)

            -- Write back to `.save`, or clear it out if the gesture ended
            if touchData.allTouchesReleased then
                component.save = nil
            else
                component.save = {}
                component.save.x, component.save.y = newX, newY
                component.save.angle = newAngle
            end
        end
    end
end


-- Update

function GrabTool.handlers:preUpdate(dt)
    -- Check for handle touches and steal them
    local handleTouchRadius = love.graphics.getDPIScale() * HANDLE_TOUCH_RADIUS
    local touchData = self:getTouchData()
    if touchData.numTouches == 1 then
        local touchId, touch = next(touchData.touches)
        if touch.pressed then
            for _, handle in ipairs(self:getHandles()) do
                local distX, distY = handle.x - touch.x, handle.y - touch.y
                if distX * distX + distY * distY <= handleTouchRadius * handleTouchRadius then
                    touch.grabHandle = handle
                    touch.used = true
                    break
                end
            end
        end
    end
end

function GrabTool.handlers:update(dt)
    local touchData = self:getTouchData()

    -- Continuing a handle gesture?
    if touchData.numTouches == 1 then
        local touchId, touch = next(touchData.touches)
        if touch.grabHandle then
            local handle = touch.grabHandle

            if handle.actorId then -- Single actor?
                local actorId = handle.actorId
                local bodyId, body = self.dependencies.Body:getBody(actorId)

                local lx, ly = body:getLocalPoint(touch.x, touch.y)

                if handle.rectangleWidth and handle.rectangleHeight then -- Rectangle resize?
                    local desiredWidth, desiredHeight = math.max(UNIT, 2 * math.abs(lx)), math.max(UNIT, 2 * math.abs(ly))
                    if handle.handleType == 'rectangleCornerResize' then
                        local s = math.max(desiredWidth / handle.rectangleWidth, desiredHeight / handle.rectangleHeight)
                        self.dependencies.Body:setRectangleShape(actorId, s * handle.rectangleWidth, s * handle.rectangleHeight)
                    elseif handle.handleType == 'rectangleWidthResize' then
                        self.dependencies.Body:setRectangleShape(actorId, desiredWidth, handle.rectangleHeight)
                    elseif handle.handleType == 'rectangleHeightResize' then
                        self.dependencies.Body:setRectangleShape(actorId, handle.rectangleWidth, desiredHeight)
                    end
                end
            end

            if handle.handleType == 'rotate' then
                local angle = math.atan2(touch.y - handle.pivotY, touch.x - handle.pivotX)
                local prevAngle = math.atan2(touch.y - touch.dy - handle.pivotY, touch.x - touch.dx - handle.pivotX)
                rotation = angle - prevAngle
                self:moveRotate(0, 0, rotation, handle.pivotX, handle.pivotY)
            end

            return -- We processed a handle, skip other gestures
        end
    end

    -- No handle gestures, check for other gestures
    if touchData.numTouches == 1 or touchData.numTouches == 2 then
        local moveX, moveY = 0, 0
        local rotation
        local centerX, centerY

        if touchData.numTouches == 1 then -- 1-finger move
            local touchId, touch = next(touchData.touches)
            moveX, moveY = touch.dx, touch.dy
        elseif touchData.numTouches == 2 then -- 2-finger move and rotate
            local touchId1, touch1 = next(touchData.touches)
            local touchId2, touch2 = next(touchData.touches, touchId1)

            local touch1PrevX, touch1PrevY = touch1.x - touch1.dx, touch1.y - touch1.dy
            local touch2PrevX, touch2PrevY = touch2.x - touch2.dx, touch2.y - touch2.dy

            centerX, centerY = 0.5 * (touch1.x + touch2.x), 0.5 * (touch1.y + touch2.y)
            local centerPrevX, centerPrevY = 0.5 * (touch1PrevX + touch2PrevX), 0.5 * (touch1PrevY + touch2PrevY)

            moveX, moveY = centerX - centerPrevX, centerY - centerPrevY

            local angle = math.atan2(touch2.y - touch1.y, touch2.x - touch1.x)
            local prevAngle = math.atan2(touch2PrevY - touch1PrevY, touch2PrevX - touch1PrevX)
            rotation = angle - prevAngle
        end

        -- If will make changes and performance is on, turn it off
        if not (moveX == 0 and moveY == 0 and (rotation == nil or rotation == 0)) then
            if self.game.performing then
                self.game:send('setPerforming', false)
            end
        end

        self:moveRotate(moveX, moveY, rotation, centerX, centerY)
    end
end


-- Draw

function GrabTool.handlers:drawOverlay(dt)
    local handleDrawRadius = love.graphics.getDPIScale() * HANDLE_DRAW_RADIUS
    for _, handle in ipairs(self:getHandles()) do
        love.graphics.circle('fill', handle.x, handle.y, handleDrawRadius)
        if handle.endX and handle.endY then
            love.graphics.line(handle.x, handle.y, handle.endX, handle.endY)
        end
    end
end

