local MoveAllTool = defineDrawSubtool {
    category = "collision_move",
    name = "move_all",
}

function MoveAllTool.handlers:addSubtool()
    self._lastCoord = nil
    self._bounds = nil
    self._clampedDiff = nil

    if self:physicsBodyData() then
        self:physicsBodyData():setTempTranslation(0, 0)
    end
end

function MoveAllTool.handlers:onTouch(component, touchData)
    if self._lastCoord == nil then
        self._lastCoord = {
            x = touchData.touchX,
            y = touchData.touchY,
        }
        self._clampedDiff = {
            x = 0,
            y = 0,
        }

        local physicsBodyBounds = self:physicsBodyData():getBounds()
        self._bounds = {
            minX = -DRAW_MAX_SIZE - physicsBodyBounds.minX,
            minY = -DRAW_MAX_SIZE - physicsBodyBounds.minY,
            maxX = DRAW_MAX_SIZE - physicsBodyBounds.maxX,
            maxY = DRAW_MAX_SIZE - physicsBodyBounds.maxY,
        }
    end

    self._clampedDiff = {
        x = self._clampedDiff.x + touchData.touchX - self._lastCoord.x,
        y = self._clampedDiff.y + touchData.touchY - self._lastCoord.y,
    }
    self._lastCoord = {
        x = touchData.touchX,
        y = touchData.touchY,
    }

    if self._clampedDiff.x < self._bounds.minX then
        self._clampedDiff.x = self._bounds.minX
    end
    if self._clampedDiff.y < self._bounds.minY then
        self._clampedDiff.y = self._bounds.minY
    end
    if self._clampedDiff.x > self._bounds.maxX then
        self._clampedDiff.x = self._bounds.maxX
    end
    if self._clampedDiff.y > self._bounds.maxY then
        self._clampedDiff.y = self._bounds.maxY
    end

    if touchData.touch.released then
        if not floatEquals(self._clampedDiff.x, 0.0) or not floatEquals(self._clampedDiff.y, 0.0) then
            for i = 1, #self:physicsBodyData().shapes do
                local shape = self:physicsBodyData().shapes[i]
                self:physicsBodyData().shapes[i] = self:physicsBodyData():moveShapeByIgnoreBounds(shape, self._clampedDiff.x, self._clampedDiff.y)
            end

            self:saveDrawing("move all", component)
        end

        self._lastCoord = nil
        self._bounds = nil
        self._clampedDiff = nil
        self:physicsBodyData():setTempTranslation(0, 0)
    else
        self:physicsBodyData():setTempTranslation(self._clampedDiff.x, self._clampedDiff.y)
    end
end
