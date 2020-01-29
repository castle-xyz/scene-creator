-- Start / stop

function Client:startTouch()
    self.touches = {} -- `touchId` -> touch
    self.numTouches = 0 -- Number of current touches (including 'just released' ones)
    self.maxNumTouches = 0 -- Max number of touches in the current gesture
    self.allTouchesReleased = false -- Whether we are at the end of a gesture
end


-- Update

function Client:updateTouches()
    -- Clear old released touches
    for touchId, touch in pairs(self.touches) do
        if touch.released then
            self.touches[touchId] = nil
        end
    end

    -- Track active touches
    local activeTouches = {}
    for _, touchId in ipairs(love.touch.getTouches()) do
        activeTouches[touchId] = true

        local x, y = self.viewTransform:inverseTransformPoint(love.touch.getPosition(touchId))

        local touch = self.touches[touchId]
        if not touch then -- Press
            touch = {}

            touch.initialX, touch.initialY = x, y
            touch.x, touch.y = x, y
            touch.dx, touch.dy = 0, 0
            touch.pressTime = love.timer.getTime()
            touch.pressed = true
            touch.released = false

            self.touches[touchId] = touch
        else -- Move
            touch.pressed = false
            touch.dx, touch.dy = x - touch.x, y - touch.y
            touch.x, touch.y = x, y
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
end


