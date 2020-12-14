local NoTouchState = {
   INACTIVE = 0,
   ACTIVE = 1,
}

-- Start / stop

local overlayShader

function Client:startTouch()
    self.touches = {} -- `touchId` -> touch
    self.numTouches = 0 -- Number of current touches (including 'just released' ones)
    self.maxNumTouches = 0 -- Max number of touches in the current gesture
    self.allTouchesReleased = false -- Whether we are at the end of a gesture
    self.gestureId = nil -- Unique id for this gesture
    self.gestureStolen = false
    self.hintState = {
       counter = 0,
       consecutiveUselessTaps = 0,
       state = NoTouchState.INACTIVE,
       startTime = 0,
       lastUselessTapTime = 0,
    }
    overlayShader = love.graphics.newShader(
       [[
        extern number transition;
        extern number intensity;
        vec4 effect( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords )
        {
              color = Texel(texture, texture_coords);
              number a = (1.0 - step(0.0, -color.a)) * transition;
              return vec4(intensity, intensity, intensity, a);
        }
       ]]
    )
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
        local x, y = self.viewTransform:inverseTransformPoint(screenX, screenY - self:getBeltYOffset())

        screenX, screenY = self.cameraTransform:inverseTransformPoint(screenX, screenY)
        x, y = self.cameraTransform:inverseTransformPoint(x, y)

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
            touch.previousActorsTouched = {}

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

local hintOverlayCanvas

function Client:_heatUpNoTouchOverlay(count)
   self.hintState.counter = self.hintState.counter + count
   if self.hintState.counter > 45 and self.hintState.state ~= NoTouchState.ACTIVE then
      self.hintState.state = NoTouchState.ACTIVE
      self.hintState.startTime = love.timer.getTime()
   end
   if self.hintState.counter > 240 then
      self.hintState.counter = 240
   end
end

function Client:_coolDownNoTouchOverlay(count)
   self.hintState.counter = self.hintState.counter - count
   if self.hintState.counter < 0 then
      self.hintState.counter = 0
      self.hintState.state = NoTouchState.INACTIVE
      if hintOverlayCanvas ~= nil then
         hintOverlayCanvas:release()
         hintOverlayCanvas = nil
      end
   end
end

-- if the player repeatedly touches stuff that's non-interactive,
-- highlight interactive objects in the scene
function Client:touchToShowHints()
   local triggered = false
   local time = love.timer.getTime()
   if self.numTouches > 0 then
      local anyTouchUsed = false
      local anyTapDidNothing = false
      local cumulativeCooldown = 0
      for touchId, touch in pairs(self.touches) do
         if touch.used or touch.usedBy then
            anyTouchUsed = true
            cumulativeCooldown = cumulativeCooldown + (touch.stepsUnused or 0)
            touch.stepsUnused = 0
         else
            touch.stepsUnused = touch.stepsUnused or 0
            touch.stepsUnused = touch.stepsUnused + 1
         end
         if not touch.used and not touch.usedBy and touch.released
            and not touch.movedNear and time - touch.pressTime < 0.2 -- it's a tap
            and touch.pressTime - self.hintState.lastUselessTapTime > 0.5 -- it's been some time since last tap
         then
            anyTapDidNothing = true
         end
      end
      if anyTapDidNothing then
         -- bring up the hint overlay after 4 or more taps in the scene that did nothing
         self.hintState.consecutiveUselessTaps = self.hintState.consecutiveUselessTaps + 1
         if self.hintState.consecutiveUselessTaps >= 4 then
            self:_heatUpNoTouchOverlay(180)
         end
         self.hintState.lastUselessTapTime = time
         triggered = true
      elseif not anyTouchUsed then
         -- bring up the hint overlay if people press/drag/hold in empty space for long enough
         self:_heatUpNoTouchOverlay(1)
         triggered = true
      else
         -- user succeeded in interacting, reset touch counter and cool down faster
         self.hintState.consecutiveUselessTaps = 0
         self:_coolDownNoTouchOverlay(cumulativeCooldown + 2)
      end
   end

   if not triggered then
      -- cool down when the user is doing nothing at all
      self:_coolDownNoTouchOverlay(1)
   end
end

function Client:drawNoTouchesHintOverlay()
   if self.hintState.state == NoTouchState.ACTIVE then
      -- darken the whole card
      local overlayAlpha = math.min(math.max(0, self.hintState.counter - 45) / 15, 1)
      love.graphics.push("all")
      love.graphics.setColor(0, 0, 0, overlayAlpha * 0.7)
      love.graphics.applyTransform(self.cameraTransform:inverse())
      love.graphics.rectangle(
         "fill",
            -0.5 * DEFAULT_VIEW_WIDTH,
            -self:getDefaultYOffset(),
         DEFAULT_VIEW_WIDTH,
         DEFAULT_VIEW_WIDTH * VIEW_HEIGHT_TO_WIDTH_RATIO
      )
      love.graphics.pop()

      if hintOverlayCanvas == nil then
         hintOverlayCanvas = love.graphics.newCanvas()
      end

      -- draw interactive actors to overlay canvas
      hintOverlayCanvas:renderTo(
         function()
            love.graphics.push("all")
            love.graphics.origin()
            love.graphics.scale(hintOverlayCanvas:getWidth() / DEFAULT_VIEW_WIDTH)
            love.graphics.translate(0, 0)
            love.graphics.translate(0.5 * DEFAULT_VIEW_WIDTH, self:getDefaultYOffset())
            love.graphics.clear(0, 0, 0, 0)

            love.graphics.applyTransform(self.cameraTransform)

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

            love.graphics.pop()
         end
      )

      -- render actor overlay with silhouette shader
      love.graphics.push("all")
      love.graphics.origin()
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.setShader(overlayShader)
      overlayShader:send("transition", overlayAlpha)
      overlayShader:send(
         "intensity",
         0.8 + 0.2 * math.cos((love.timer.getTime() - self.hintState.startTime) * 6)
      )
      love.graphics.draw(hintOverlayCanvas)
      love.graphics.pop()
   end
end
