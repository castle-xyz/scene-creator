local NoTouchState = {
   INACTIVE = 0,
   ACTIVE = 1,
}

-- Start / stop

function Client:startTouch()
    self.touches = {} -- `touchId` -> touch
    self.numTouches = 0 -- Number of current touches (including 'just released' ones)
    self.maxNumTouches = 0 -- Max number of touches in the current gesture
    self.allTouchesReleased = false -- Whether we are at the end of a gesture
    self.gestureId = nil -- Unique id for this gesture
    self.gestureStolen = false
    self.noTouchesUsed = {
       counter = 0,
       state = NoTouchState.INACTIVE,
    }
end

-- Update

local TOUCH_MOVE_THRESHOLD = 35

function Client:updateTouches()
    -- Clear old released touches
    for touchId, touch in pairs(self.touches) do
        if touch.released then
            self.touches[touchId] = nil
        end
    end

    -- Track active touches
    local activeTouches = {}
    ui.setUpdatesPaused(false)
    for _, touchId in ipairs(love.touch.getTouches()) do
        activeTouches[touchId] = true

        if not self.performing then
            ui.setUpdatesPaused(true)
        end

        local screenX, screenY = love.touch.getPosition(touchId)
        local x, y = self.viewTransform:inverseTransformPoint(screenX, screenY)

        local touch = self.touches[touchId]
        if not touch then -- Press
            touch = {}

            touch.initialX, touch.initialY = x, y
            touch.x, touch.y = x, y
            touch.dx, touch.dy = 0, 0
            touch.screenX, touch.screenY = screenX, screenY
            touch.initialScreenX, touch.initialScreenY = screenX, screenY
            touch.screenDX, touch.screenDY = 0, 0
            touch.pressTime = love.timer.getTime()
            touch.pressed = true
            touch.released = false
            touch.movedNear = false
            touch.movedFar = false

            self.touches[touchId] = touch
        else -- Move
            touch.pressed = false
            touch.dx, touch.dy = x - touch.x, y - touch.y
            touch.x, touch.y = x, y
            touch.screenDX, touch.screenDY = screenX - touch.screenX, screenY - touch.screenY
            touch.screenX, touch.screenY = screenX, screenY
            
            if not (util.similar(touch.screenX, touch.initialScreenX, TOUCH_MOVE_THRESHOLD) and
                    util.similar(touch.screenY, touch.initialScreenY, TOUCH_MOVE_THRESHOLD)) then
                touch.movedFar = true
            end

            if not (touch.screenX == touch.initialScreenX and touch.screenY == touch.initialScreenY) then
                touch.movedNear = true
            end
        end
    end

    -- Just released
    for touchId, touch in pairs(self.touches) do
        if not activeTouches[touchId] then
            touch.released = true
        end
    end

    -- End of gesture?
    self.allTouchesReleased = false
    for touchId, touch in pairs(self.touches) do
        if touch.released then
            self.allTouchesReleased = true
        else
            self.allTouchesReleased = false
            break
        end
    end

    -- Count
    self.numTouches = 0
    for touchId, touch in pairs(self.touches) do
        self.numTouches = self.numTouches + 1
    end
    if self.numTouches == 0 then
        self.maxNumTouches = 0
    else
        self.maxNumTouches = math.max(self.maxNumTouches, self.numTouches)
    end

    -- Gesture id
    if self.numTouches > 0 then
        self.gestureId = self.gestureId or util.uuid()
    else
        self.gestureId = nil
        self.gestureStolen = false
    end
end

-- if the player repeatedly touches stuff that's non-interactive,
-- highlight interactive objects in the scene
function Client:touchToShowHints()
   local triggered = false
   if self.numTouches > 0 then
      local anyTouchUsed = false
      for touchId, touch in pairs(self.touches) do
         if touch.used then
            anyTouchUsed = true
         end
      end
      if not anyTouchUsed then
         triggered = true
         self.noTouchesUsed.counter = self.noTouchesUsed.counter + 1
         if self.noTouchesUsed.counter > 45 and self.noTouchesUsed.state ~= NoTouchState.ACTIVE then
            self.noTouchesUsed.state = NoTouchState.ACTIVE
         end
         if self.noTouchesUsed.counter > 60 then
            self.noTouchesUsed.counter = 60
         end
      end
   end

   if not triggered then
      self.noTouchesUsed.counter = self.noTouchesUsed.counter - 2
      if self.noTouchesUsed.counter < 0 then
         self.noTouchesUsed.counter = 0
         self.noTouchesUsed.state = NoTouchState.INACTIVE
      end
   end
end

function Client:drawNoTouchesHintOverlay()
   if self.noTouchesUsed.state == NoTouchState.ACTIVE then
      -- darken the whole card
      local overlayAlpha = (math.max(0, self.noTouchesUsed.counter - 45) / 15) * 0.7
      love.graphics.push("all")
      love.graphics.setColor(0, 0, 0, overlayAlpha)
      love.graphics.rectangle(
         "fill",
            -0.5 * DEFAULT_VIEW_WIDTH,
            -0.5 * DEFAULT_VIEW_WIDTH,
         DEFAULT_VIEW_WIDTH,
         DEFAULT_VIEW_WIDTH * VIEW_HEIGHT_TO_WIDTH_RATIO
      )
      love.graphics.pop()

      -- draw interactive actors only
      local drawBehaviors = self.behaviorsByHandler["drawComponent"] or {}
      self:forEachActorByDrawOrder(
         function(actor)
            if self:isActorInteractive(actor.actorId) then
               for behaviorId, behavior in pairs(drawBehaviors) do
                  local component = actor.components[behaviorId]
                  if component then
                     behavior:callHandler("drawComponent", component)
                  end
               end
            end
         end
      )
   end
end
