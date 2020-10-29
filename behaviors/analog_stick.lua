local AnalogStickBehavior =
    defineCoreBehavior {
    name = "AnalogStick",
    displayName = "Analog Stick",
    dependencies = {
        "Moving",
        "Body"
    },
    allowsDisableWithoutRemoval = true,
    propertySpecs = {
       speed = {
          method = 'numberInput',
          label = 'Speed',
          props = { min = 0, max = 50, step = 0.5 },
          rules = {
             set = true,
          },
       },
       turnFriction = {
          method = 'numberInput',
          label = 'Turn Friction',
          props = { min = 0, max = 10, step = 0.1 },
          rules = {
             set = true,
          },
       },
    },
}

local MAX_DRAG_LENGTH = 2 * UNIT

local DRAW_MULTIPLIER = 0.8

local TOUCH_RADIUS = 38 * UNIT
local TRIANGLE_LENGTH = 25 * UNIT
local TRIANGLE_WIDTH = 10 * UNIT

-- Component management

function AnalogStickBehavior.handlers:addComponent(component, bp, opts)
    component.properties.speed = bp.speed or 6
    component.properties.turnFriction = bp.turnFriction or 3
end

function AnalogStickBehavior.handlers:blueprintComponent(component, bp)
    bp.speed = component.properties.speed
    bp.turnFriction = component.properties.turnFriction
end

function AnalogStickBehavior.getters:isInteractive(component)
   return not component.disabled
end

-- Perform

-- this method causes the center of the analog stick to pull toward
-- the touch.
function AnalogStickBehavior:_updateCenter(touch)
   local dragX, dragY = touch.x - self._centerX, touch.y - self._centerY
   local dragLen = math.sqrt(dragX * dragX + dragY * dragY)
   local dragAngle = math.atan2(dragY, dragX)
   
   local centerVelocity
   if dragLen > MAX_DRAG_LENGTH then
      centerVelocity = dragLen * 0.06
   else
      centerVelocity = dragLen * 0.02
   end

   self._centerX = self._centerX + centerVelocity * math.cos(dragAngle)
   self._centerY = self._centerY + centerVelocity * math.sin(dragAngle)
end

local diffAngle = function(a1, a2)
   return ((a1 - a2 + math.pi) % (2 * math.pi) - math.pi)
end

function AnalogStickBehavior.handlers:postPerform(dt)
    -- Do this in `postPerform` to allow other behaviors to steal the touch

    -- Client-only
    if not self.game.clientId then
        return
    end

    -- Make sure we have some actors
    if not self:hasAnyEnabledComponent() then
        return
    end

    local physics = self.dependencies.Body:getPhysics()

    local touchData = self:getTouchData()
    if touchData.maxNumTouches == 1 then
        local touchId, touch = next(touchData.touches)
        if not touch.used and touch.movedNear then
           local gestureStarted = false
           if touch.usedBy == nil or not touch.usedBy.analogStick then
              touch.usedBy = touch.usedBy or {}
              touch.usedBy.analogStick = true -- mark the touch without `used` so we detect player interaction
              self._centerX, self._centerY = touch.initialX, touch.initialY
              gestureStarted = true
           else
              self:_updateCenter(touch)
           end
            local dragX, dragY = touch.x - self._centerX, touch.y - self._centerY
            local dragLen = math.sqrt(dragX * dragX + dragY * dragY)
            if dragLen > MAX_DRAG_LENGTH then
                dragX, dragY = dragX * MAX_DRAG_LENGTH / dragLen, dragY * MAX_DRAG_LENGTH / dragLen
                dragLen = MAX_DRAG_LENGTH
            end

            for actorId, component in pairs(self.components) do
                if not component.disabled then
                    local bodyId, body = self.dependencies.Body:getBody(actorId)
                    if physics:getOwner(bodyId) ~= self.game.clientId then
                        physics:setOwner(bodyId, self.game.clientId, true, 0)
                    end
                    local m = body:getMass()
                    local impulsePerFrame = component.properties.speed / 60

                    -- boost the analog stick magnitude if the player's direction
                    -- is pointed against the analog stick's direction
                    if component.properties.turnFriction ~= nil and component.properties.turnFriction > 0 then
                       local vx, vy = body:getLinearVelocity()
                       local actorDirection = math.atan2(vy, vx)
                       local dragDirection = math.atan2(dragY, dragX)
                       impulsePerFrame = impulsePerFrame * (1 + math.abs(diffAngle(actorDirection, dragDirection) / math.pi) * component.properties.turnFriction)
                    end

                    body:applyLinearImpulse(m * impulsePerFrame * dragX, m * impulsePerFrame * dragY)

                    if gestureStarted then
                       self:fireTrigger("analog stick begins", actorId)
                    end
                end
            end
        end
    end
    if touchData.allTouchesReleased then
       if self._centerX ~= nil or self._centerY ~= nil then
          self._centerX = nil
          self._centerY = nil
          for actorId, component in pairs(self.components) do
             if not component.disabled then
                self:fireTrigger("analog stick ends", actorId)
             end
          end
       end
    end
end

-- Rules

AnalogStickBehavior.triggers["analog stick begins"] = {
   description = "When analog stick input begins",
   category = "controls",
}

AnalogStickBehavior.triggers["analog stick ends"] = {
   description = "When analog stick input ends",
   category = "controls",
}

-- Draw

function AnalogStickBehavior.handlers:drawOverlay()
    if not self.game.performing then
        return
    end

    -- Make sure we have some actors
    if not self:hasAnyEnabledComponent() then
        return
    end

    -- Look for a single-finger drag
    local touchData = self:getTouchData()
    if touchData.maxNumTouches == 1 then
        local touchId, touch = next(touchData.touches)
        if not touch.used and touch.movedNear then
            local touchX, touchY = touch.x, touch.y
            local dragX, dragY = touchX - self._centerX, touchY - self._centerY
            local dragLen = math.sqrt(dragX * dragX + dragY * dragY)
            if dragLen > 0 then
                if dragLen > MAX_DRAG_LENGTH then
                    dragX, dragY = dragX * MAX_DRAG_LENGTH / dragLen, dragY * MAX_DRAG_LENGTH / dragLen
                    dragLen = MAX_DRAG_LENGTH
                    local dragAngle = math.atan2(dragY, dragX)
                    touchX = self._centerX + dragLen * math.cos(dragAngle)
                    touchY = self._centerY + dragLen * math.sin(dragAngle)
                end

                love.graphics.setColor(1, 1, 1, 0.8)
                love.graphics.setLineWidth(1.25 * self.game:getPixelScale())

                local touchRadius = TOUCH_RADIUS * self.game:getPixelScale()
                local maxRadius = MAX_DRAG_LENGTH + touchRadius

                -- At the center of the analog stick,
                -- a circle with solid outline and transparent fill
                love.graphics.circle("line", self._centerX, self._centerY, maxRadius)
                love.graphics.setColor(1, 1, 1, 0.3)
                love.graphics.circle("fill", self._centerX, self._centerY, maxRadius)
                love.graphics.setColor(1, 1, 1, 0.8)

                -- Under the (clamped) touch,
                -- a circle with solid outline and transparent fill
                love.graphics.circle("line", touchX, touchY, touchRadius)
                love.graphics.setColor(1, 1, 1, 0.3)
                love.graphics.circle("fill", touchX, touchY, touchRadius)
                love.graphics.setColor(1, 1, 1, 0.8)
            end
        end
    end
end
