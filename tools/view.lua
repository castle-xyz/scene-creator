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
        needsPerformingOff = true,
        noSelect = true,
        noHistory = true,
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

    -- Still allow selection with touch-and-release
    if touchData.numTouches == 1 and touchData.maxNumTouches == 1 then
        local touchId, touch = next(touchData.touches)
        if (touch.released and
                touch.x - touch.initialX == 0 and touch.y - touch.initialY == 0 and
                love.timer.getTime() - touch.pressTime < 0.2) then
            self.game:selectActorAtTouch(touch)
            self.game:applySelections()
            --if next(self.game.selectedActorIds) then
            --    for i = #self.game.activeToolHistory - 1, 1, -1 do
            --        if self.game.applicableTools[self.game.activeToolHistory[i]] then
            --            self.game:setActiveTool(self.game.activeToolHistory[i])
            --            break
            --        end
            --    end
            --end
            return
        end
    end

    if touchData.numTouches == 1 or touchData.numTouches == 2 then
        local moveX, moveY = 0, 0
        local scale

        if touchData.numTouches == 1 then -- 1-finger move
            local touchId, touch = next(touchData.touches)
            moveX, moveY = touch.screenDX / self.game:getViewScale(), touch.screenDY / self.game:getViewScale()
        elseif touchData.numTouches == 2 then -- 2-finger move and scale
            local touchId1, touch1 = next(touchData.touches)
            local touchId2, touch2 = next(touchData.touches, touchId1)

            local touch1PrevSX, touch1PrevSY = touch1.screenX - touch1.screenDX, touch1.screenY - touch1.screenDY
            local touch2PrevSX, touch2PrevSY = touch2.screenX - touch2.screenDX, touch2.screenY - touch2.screenDY

            local centerSX, centerSY = 0.5 * (touch1.screenX + touch2.screenX), 0.5 * (touch1.screenY + touch2.screenY)
            local centerPrevSX, centerPrevSY = 0.5 * (touch1PrevSX + touch2PrevSX), 0.5 * (touch1PrevSY + touch2PrevSY)

            moveX, moveY = (centerSX - centerPrevSX) / self.game:getViewScale(), (centerSY - centerPrevSY) / self.game:getViewScale()

            local px, py = touch1.screenX - touch2.screenX, touch1.screenY - touch2.screenY
            local prevPX, prevPY = touch1PrevSX - touch2PrevSX, touch1PrevSY - touch2PrevSY
            scale = math.sqrt(prevPX * prevPX + prevPY * prevPY) / math.sqrt(px * px + py * py)

            local centerX, centerY = self.game.viewTransform:inverseTransformPoint(centerSX, centerSY)
            moveX = moveX - (1 - scale) * (centerX - self.game.viewX)
            moveY = moveY - (1 - scale) * (centerY - self.game.viewY)
        end

        self.game.viewX, self.game.viewY = self.game.viewX - moveX, self.game.viewY - moveY
        if scale then
            self.game.viewWidth = math.max(MIN_VIEW_WIDTH, math.min(scale * self.game.viewWidth, MAX_VIEW_WIDTH))
        end
    end
end


-- Draw

function ViewTool.handlers:drawOverlay()
    self.game.behaviorsByName.Grab:drawGrid()
end


-- UI

function ViewTool.handlers:uiSettings(closeSettings)
    util.uiRow('position and reset position', function()
        ui.markdown('position: ' .. util.quantize(self.game.viewX, 0.01) .. ', ' .. util.quantize(self.game.viewY, 0.01))
    end, function()
        ui.button('reset position', {
            icon = 'crosshairs',
            iconFamily = 'FontAwesome',
            onClick = function()
                self.game:resetViewPosition()
            end,
        })
    end)

    ui.box('spacer', { height = 32 }, function() end)

    util.uiRow('zoom level and reset zoom', function()
        local prefix
        local scale = self.game.viewWidth / DEFAULT_VIEW_WIDTH
        if scale < 1 then
            prefix = 'zoomed in: '
            scale = 1 / scale
        elseif scale > 1 then
            prefix = 'zoomed out: '
        else
            prefix = 'no zoom'
        end
        ui.markdown(prefix .. (scale ~= 1 and (util.quantize(scale, 0.01) .. 'x') or ''))
    end, function()
        ui.button('reset zoom', {
            icon = 'dot-circle-o',
            iconFamily = 'FontAwesome',
            onClick = function()
                self.game:resetViewSize()
            end,
        })
    end)

    util.uiRow('zoom in out', function()
        ui.button('zoom in', {
            icon = 'zoom-in',
            iconFamily = 'Feather',
            onClick = function()
                self.game.viewWidth = math.max(MIN_VIEW_WIDTH, math.min(0.5 * self.game.viewWidth, MAX_VIEW_WIDTH))
            end,
        })
    end, function()
        ui.button('zoom out', {
            icon = 'zoom-out',
            iconFamily = 'Feather',
            onClick = function()
                self.game.viewWidth = math.max(MIN_VIEW_WIDTH, math.min(2 * self.game.viewWidth, MAX_VIEW_WIDTH))
            end,
        })
    end)
end

