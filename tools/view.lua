local ViewTool = {
    name = 'View',
    propertyNames = {
    },
    dependencies = {
    },
    handlers = {},
    tool = {
        icon = 'magnifying-glass',
        iconFamily = 'Entypo',
        noSelect = true,
    },
}

registerCoreBehavior(ViewTool)


-- Update

function ViewTool.handlers:preUpdate(dt)
    if not self:isActive() then
        return
    end

    -- Steal all touches
    local touchData = self:getTouchData()
    for touchId, touch in pairs(touchData.touches) do
        touch.used = true
    end
end

function ViewTool.handlers:update(dt)
    if not self:isActive() then
        return
    end

    local touchData = self:getTouchData()

    -- Still allow tap-to-select
    if self.numTouches == 1 and self.maxNumTouches == 1 then
        local touchId, touch = next(self.touches)
        if (touch.released and
                touch.x - touch.initialX == 0 and touch.y - touch.initialY == 0 and
                love.timer.getTime() - touch.pressTime < 0.2) then
            self:selectActorAtTouch(touch)
            return
        end
    end

    if touchData.numTouches == 1 or touchData.numTouches == 2 then
        local moveX, moveY = 0, 0
        local centerX, centerY

        if touchData.numTouches == 1 then -- 1-finger move
            local touchId, touch = next(touchData.touches)
            moveX, moveY = touch.screenDX / self.game:getViewScale(), touch.screenDY / self.game:getViewScale()
        elseif touchData.numTouches == 2 then -- 2-finger move and rotate
            local touchId1, touch1 = next(touchData.touches)
            local touchId2, touch2 = next(touchData.touches, touchId1)

            local touch1PrevX, touch1PrevY = touch1.x - touch1.dx, touch1.y - touch1.dy
            local touch2PrevX, touch2PrevY = touch2.x - touch2.dx, touch2.y - touch2.dy

            centerX, centerY = 0.5 * (touch1.x + touch2.x), 0.5 * (touch1.y + touch2.y)
            local centerPrevX, centerPrevY = 0.5 * (touch1PrevX + touch2PrevX), 0.5 * (touch1PrevY + touch2PrevY)

            moveX, moveY = centerX - centerPrevX, centerY - centerPrevY
        end

        self.game.viewX, self.game.viewY = self.game.viewX - moveX, self.game.viewY - moveY
    end
end


-- UI

function ViewTool.handlers:uiSettings(closeSettings)
    if ui.button('reset') then
        self.game:resetView()
    end
end

