local DragBehavior =
    defineCoreBehavior {
    name = "Drag",
    displayName = "Drag",
    allowsDisableWithoutRemoval = true,
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

function DragBehavior.handlers:disableComponent(component, opts)
   if not opts.removeActor then
      -- immediately release any touches corresponding to this component
      local touchData = self:getTouchData()
      for touchId, touch in pairs(touchData.touches) do
         if self.components[touch.actorId] == component then
            self:_releaseComponentTouch(component, touch)
         end
      end
   end
end

function DragBehavior:_releaseComponentTouch(component, touch)
   if component then
      component._numTouches = math.max(0, component._numTouches - 1)
      if component._numTouches == 0 then
         component._clientId = nil
      end
   end
   if not touch._mouseJoint:isDestroyed() then
      touch._mouseJoint:destroy()
   end
end

function DragBehavior.getters:isInteractive(component)
   return not component.disabled
end

-- Perform

function DragBehavior.handlers:prePerform(dt)
    -- Client-only
    if not self.game.clientId then
        return
    end

    if not self:hasAnyEnabledComponent() then
        return
    end

    local touchData = self:getTouchData()
    for touchId, touch in pairs(touchData.touches) do
        -- Mark touch presses on our bodies
        if touch.pressed then
            local hits = self.dependencies.Body:getActorsAtPoint(touch.x, touch.y)
            local actorId, maxDrawOrder
            for candidateActorId in pairs(hits) do -- Use topmost actor
                local candidateActor = self.game.actors[candidateActorId]
                if candidateActor and not maxDrawOrder or candidateActor.drawOrder > maxDrawOrder then
                    actorId = candidateActor.actorId
                    maxDrawOrder = candidateActor.drawOrder
                end
            end
            if actorId then
                local component = self.components[actorId]
                if component and not component.disabled then
                    touch.used = true
                    touch.dragging = true
                    touch.actorId = actorId

                    local bodyId, body = self.dependencies.Body:getBody(actorId)
                    local members = self.dependencies.Body:getMembers(actorId)
                    local touchX = touch.x
                    local touchY = touch.y
                    touch._mouseJointRelative = false

                    if members.layer and members.layer.relativeToCamera then
                        local cameraX, cameraY = self.game:getCameraPosition()
                        touchX = touchX - cameraX
                        touchY = touchY - cameraY
                        touch._mouseJointRelative = true
                    end

                    touch._mouseJoint = love.physics.newMouseJoint(body, touchX, touchY)
                    touch._localX, touch._localY = body:getLocalPoint(touchX, touchY)

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
        if component._clientId == self.game.clientId and not component.disabled then
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
                self:_releaseComponentTouch(component, touch)
            else
                if not touch._mouseJoint:isDestroyed() then
                    -- Drag, move
                    local touchX = touch.x
                    local touchY = touch.y

                    if touch._mouseJointRelative then
                        local cameraX, cameraY = self.game:getCameraPosition()
                        touchX = touchX - cameraX
                        touchY = touchY - cameraY
                    end

                    touch._mouseJoint:setTarget(touchX, touchY)
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

    if not self:hasAnyEnabledComponent() then
        return
    end
    
    local touchData = self:getTouchData()
    for touchId, touch in pairs(touchData.touches) do
        if touch.dragging and not touch.released then
            local bodyId, body = self.dependencies.Body:getBody(touch.actorId)
            if body then
                local worldX, worldY = body:getWorldPoint(touch._localX, touch._localY)
                if touch._mouseJointRelative then
                    local cameraX, cameraY = self.game:getCameraPosition()
                    worldX = worldX + cameraX
                    worldY = worldY + cameraY
                end

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
