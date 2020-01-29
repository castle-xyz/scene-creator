-- Start / stop

function Client:startTouch()
    self.touches = {} -- `touchId` -> touch
    self.numTouches = 0 -- Number of current touches (including 'just released' ones)
    self.maxNumTouches = 0 -- Max number of touches in the current gesture
    self.allTouchesReleased = false -- Whether we are at the end of a gesture
end


-- Update

function Client:preUpdateTouches()
    self.numTouches = 0

    -- Active touches
    local activeTouches = {}
    for _, touchId in ipairs(love.touch.getTouches()) do
        activeTouches[touchId] = true

        self.numTouches = self.numTouches + 1

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

    -- Releases
    local someTouchReleased = false
    for touchId, touch in pairs(self.touches) do
        if not activeTouches[touchId] then
            self.numTouches = self.numTouches + 1
            touch.released = true
            someTouchReleased = true
        end
    end
    self.allTouchesReleased = someTouchReleased and not next(activeTouches)

    -- Update max touches
    if self.numTouches == 0 then
        self.maxNumTouches = 0
    else
        self.maxNumTouches = math.max(self.maxNumTouches, self.numTouches)
    end
end

function Client:postUpdateTouches()
    -- Remove released touches
    for touchId, touch in pairs(self.touches) do
        if touch.released then
            self.touches[touchId] = nil
        end
    end
end

