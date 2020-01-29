-- Start / stop

function Client:startTouch()
    self.touches = {} -- `touchId` -> touch
    self.numTouches = 0 -- Number of currently active touches
    self.maxNumTouches = 0 -- Max number of touches in the current gesture
    self.allTouchesReleased = false -- Whether we are at the end of a gesture
end


-- Methods

function Client:flushTouches()
    -- Clear touch state
    for touchId, touch in pairs(self.touches) do
        if touch.released then
            self.touches[touchId] = nil
            self.numTouches = self.numTouches - 1
            if self.numTouches == 0 then
                self.maxNumTouches = 0
            end
        else
            touch.pressed = false
            touch.dx, touch.dy = 0, 0
        end
    end
    self.allTouchesReleased = false
end


-- Main touch events

function Client:screenToWorld(x, y, dx, dy)
    if dx and dy then
        local prevX, prevY = self.viewTransform:inverseTransformPoint(x - dx, y - dy)
        x, y = self.viewTransform:inverseTransformPoint(x, y)
        return x, y, x - prevX, y - prevY
    else
        return self.viewTransform:inverseTransformPoint(x, y)
    end
end

function Client:touchpressed(touchId, x, y, dx, dy)
    if not self.connected then
        return
    end

    x, y, dx, dy = self:screenToWorld(x, y, dx, dy)

    local touch = {}

    touch.initialX, touch.initialY = x, y
    touch.x, touch.y, touch.dx, touch.dy = x, y, dx, dy
    touch.pressTime = love.timer.getTime()
    touch.pressed = true
    touch.released = false

    self.touches[touchId] = touch

    self.numTouches = self.numTouches + 1
    self.maxNumTouches = math.max(self.maxNumTouches, self.numTouches)
end

function Client:touchreleased(touchId, x, y, dx, dy)
    local touch = self.touches[touchId]
    if touch then
        x, y, dx, dy = self:screenToWorld(x, y, dx, dy)

        touch.x, touch.y, touch.dx, touch.dy = x, y, dx, dy
        touch.released = true

        -- Check if end of gesture
        self.allTouchesReleased = true
        for touchId, touch in pairs(self.touches) do
            if not touch.released then
                self.allTouchesReleased = false
            end
        end
    end
end

function Client:touchmoved(touchId, x, y, dx, dy)
    local touch = self.touches[touchId]
    if touch then
        x, y, dx, dy = self:screenToWorld(x, y, dx, dy)

        touch.x, touch.y, touch.dx, touch.dy = x, y, dx, dy
    end
end
