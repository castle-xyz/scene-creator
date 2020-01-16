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


-- Update

function GrabTool.handlers:update(dt)
    local physics = self.dependencies.Body:getPhysics()
    local touchData = self:getTouchData()

    if touchData.numTouches == 1 or touchData.numTouches == 2 then
        local moveX, moveY = 0, 0
        local centerX, centerY
        local rotation
        local cosRotation, sinRotation

        if touchData.numTouches == 1 then -- Pure-move
            local touchId, touch = next(touchData.touches)
            moveX, moveY = touch.dx, touch.dy
        elseif touchData.numTouches == 2 then -- Move and rotate
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
            cosRotation, sinRotation = math.cos(rotation), math.sin(rotation)
        end

        if not (moveX == 0 and moveY == 0 and (rotation == nil or rotation == 0)) then
            -- If an actual motion is happening and performance is on, turn it off
            if self.game.performing then
                self.game:send('setPerforming', false)
            end
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
                    local lX, lY = x - centerX, y - centerY
                    lX = cosRotation * lX - sinRotation * lY
                    lY = sinRotation * lX + cosRotation * lY
                    newX, newY = centerX + moveX + lX, centerY + moveY + lY
                    newAngle = angle + rotation
                else
                    newX, newY = x + moveX, y + moveY
                    newAngle = angle
                end

                -- When not performing we need to actually send the sync messages. We also
                -- send a reliable message on touch release to make sure the final state is
                -- reflected.
                local sendOpts = {
                    reliable = touchData.allTouchesReleased,
                    channel = touchData.allTouchesReleased and physics.reliableChannel or nil,
                }
                physics:setPosition(sendOpts, bodyId, newX, newY)
                if body:getType() == 'dynamic' then
                    physics:setLinearVelocity(sendOpts, bodyId, 0, 0)
                    physics:setAngularVelocity(sendOpts, bodyId, 0)
                end
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
end


