local DragBehavior =
    defineCoreBehavior {
    name = "Drag",
    displayName = "Drag",
    propertyNames = {},
    dependencies = {
        "Moving",
        "Body"
    }
}

local CIRCLE_RADIUS = 18 * UNIT

-- Component management

function DragBehavior.handlers:addComponent(component, bp, opts)
    component._numTouches = 0
    component._clientId = nil
end

-- Perform

function DragBehavior.handlers:prePerform(dt)
    -- Client-only
    if not self.game.clientId then
        return
    end

    local touchData = self:getTouchData()
    for touchId, touch in pairs(touchData.touches) do
        -- Mark touch presses on our bodies
        if touch.pressed then
            local hits = self.dependencies.Body:getActorsAtPoint(touch.x, touch.y)
            for actorId in pairs(hits) do
                local component = self.components[actorId]
                if component then
                    touch.used = true
                    touch.dragging = true
                    touch.actorId = actorId

                    local bodyId, body = self.dependencies.Body:getBody(actorId)
                    touch._mouseJoint = love.physics.newMouseJoint(body, touch.x, touch.y)
                    touch._localX, touch._localY = body:getLocalPoint(touch.x, touch.y)

                    component._numTouches = component._numTouches + 1
                    component._clientId = self.game.clientId
                end
            end
        end
    end
end

function DragBehavior.handlers:perform(dt)
    -- Client-only
    if not self.game.clientId then
        return
    end

    local physics = self.dependencies.Body:getPhysics()

    for actorId, component in pairs(self.components) do
        if component._clientId == self.game.clientId then
            local bodyId, body = self.dependencies.Body:getBody(actorId)
            if physics:getOwner(bodyId) ~= self.game.clientId then
                physics:setOwner(bodyId, self.game.clientId, true)
            end
        end
    end

    local touchData = self:getTouchData()
    for touchId, touch in pairs(touchData.touches) do
        if touch.dragging then
            if touch.released then
                -- Released, unmark
                local component = self.components[touch.actorId]
                if component then
                    component._numTouches = math.max(0, component._numTouches - 1)
                    if component._numTouches == 0 then
                        component._clientId = nil
                    end
                end
                if not touch._mouseJoint:isDestroyed() then
                    touch._mouseJoint:destroy()
                end
            else
                if not touch._mouseJoint:isDestroyed() then
                    -- Drag, move
                    touch._mouseJoint:setTarget(touch.x, touch.y)
                end
            end
        end
    end
end

-- Draw

function DragBehavior.handlers:drawOverlay()
    if not self.game.performing then
        return
    end

    local touchData = self:getTouchData()
    for touchId, touch in pairs(touchData.touches) do
        if touch.dragging and not touch.released then
            local bodyId, body = self.dependencies.Body:getBody(touch.actorId)
            if body then
                local worldX, worldY = body:getWorldPoint(touch._localX, touch._localY)

                love.graphics.setColor(1, 1, 1, 0.8)
                love.graphics.setLineWidth(1.25 * self.game:getPixelScale())

                local circleRadius = CIRCLE_RADIUS * self.game:getPixelScale()

                love.graphics.circle("line", touch.x, touch.y, circleRadius)
                love.graphics.setColor(1, 1, 1, 0.3)
                love.graphics.circle("fill", touch.x, touch.y, circleRadius)
                love.graphics.setColor(1, 1, 1, 0.8)

                love.graphics.circle("line", worldX, worldY, circleRadius)
                love.graphics.setColor(1, 1, 1, 0.3)
                love.graphics.circle("fill", worldX, worldY, circleRadius)
                love.graphics.setColor(1, 1, 1, 0.8)

                love.graphics.line(worldX, worldY, touch.x, touch.y)
            end
        end
    end
end
