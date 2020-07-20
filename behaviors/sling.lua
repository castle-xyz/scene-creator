local SlingBehavior =
    defineCoreBehavior {
    name = "Sling",
    displayName = "Slingshot",
    dependencies = {
        "Moving",
        "Body"
    },
    propertySpecs = {
       speed = {
          method = 'numberInput',
          label = 'Speed',
          props = { min = 0, max = 10, step = 0.5 },
          rules = {
             set = true,
          },
       },
    },
}

local MAX_DRAG_LENGTH = 3 * UNIT

local DRAW_MULTIPLIER = 0.8

local CIRCLE_RADIUS = 18 * UNIT
local TRIANGLE_LENGTH = 25 * UNIT
local TRIANGLE_WIDTH = 10 * UNIT

-- Component management

function SlingBehavior.handlers:addComponent(component, bp, opts)
    component.properties.speed = bp.speed or 3.5
end

function SlingBehavior.handlers:blueprintComponent(component, bp)
    bp.speed = component.properties.speed
end

-- Perform

function SlingBehavior.handlers:postPerform(dt)
    -- Do this in `postPerform` to allow other behaviors to steal the touch

    -- Client-only
    if not self.game.clientId then
        return
    end

    -- Make sure we have some actors
    if not next(self.components) then
        return
    end

    local physics = self.dependencies.Body:getPhysics()

    local touchData = self:getTouchData()
    if touchData.maxNumTouches == 1 and touchData.allTouchesReleased then
        local touchId, touch = next(touchData.touches)
        if not touch.used and touch.movedNear then
            local dragX, dragY = touch.initialX - touch.x, touch.initialY - touch.y
            local dragLen = math.sqrt(dragX * dragX + dragY * dragY)
            if dragLen > MAX_DRAG_LENGTH then
                dragX, dragY = dragX * MAX_DRAG_LENGTH / dragLen, dragY * MAX_DRAG_LENGTH / dragLen
                dragLen = MAX_DRAG_LENGTH
            end

            for actorId, component in pairs(self.components) do
                -- Own the body, then just set velocity locally and the physics system will sync it
                local bodyId, body = self.dependencies.Body:getBody(actorId)
                if physics:getOwner(bodyId) ~= self.game.clientId then
                    physics:setOwner(bodyId, self.game.clientId, true, 0)
                end
                body:setLinearVelocity(component.properties.speed * dragX, component.properties.speed * dragY)
                self:fireTrigger("sling", actorId)
            end
        end
    end
end

SlingBehavior.triggers.sling = {
   description = "When this is slung",
   category = "controls",
}

-- Draw

function SlingBehavior.handlers:drawOverlay()
    if not self.game.performing then
        return
    end

    -- Make sure we have some actors
    if not next(self.components) then
        return
    end

    -- Look for a single-finger drag
    local touchData = self:getTouchData()
    if touchData.maxNumTouches == 1 then
        local touchId, touch = next(touchData.touches)
        if not touch.used and touch.movedNear then
            local dragX, dragY = touch.initialX - touch.x, touch.initialY - touch.y
            local dragLen = math.sqrt(dragX * dragX + dragY * dragY)
            if dragLen > 0 then
                if dragLen > MAX_DRAG_LENGTH then
                    dragX, dragY = dragX * MAX_DRAG_LENGTH / dragLen, dragY * MAX_DRAG_LENGTH / dragLen
                    dragLen = MAX_DRAG_LENGTH
                end

                love.graphics.setColor(1, 1, 1, 0.8)
                love.graphics.setLineWidth(1.25 * self.game:getPixelScale())

                local circleRadius = CIRCLE_RADIUS * self.game:getPixelScale()
                local triangleLength = TRIANGLE_LENGTH * self.game:getPixelScale()
                local triangleWidth = TRIANGLE_WIDTH * self.game:getPixelScale()

                -- Circle with solid outline and transparent fill
                love.graphics.circle("line", touch.initialX, touch.initialY, circleRadius)
                love.graphics.setColor(1, 1, 1, 0.3)
                love.graphics.circle("fill", touch.initialX, touch.initialY, circleRadius)
                love.graphics.setColor(1, 1, 1, 0.8)

                -- Line and triangle
                local endX, endY = touch.initialX + DRAW_MULTIPLIER * dragX, touch.initialY + DRAW_MULTIPLIER * dragY
                love.graphics.line(
                    touch.initialX,
                    touch.initialY,
                    endX - triangleLength * dragX / dragLen,
                    endY - triangleLength * dragY / dragLen
                )
                love.graphics.polygon(
                    "fill",
                    endX,
                    endY,
                    endX - triangleLength * dragX / dragLen - triangleWidth * dragY / dragLen,
                    endY - triangleLength * dragY / dragLen + triangleWidth * dragX / dragLen,
                    endX - triangleLength * dragX / dragLen + triangleWidth * dragY / dragLen,
                    endY - triangleLength * dragY / dragLen - triangleWidth * dragX / dragLen
                )
            end
        end
    end
end
