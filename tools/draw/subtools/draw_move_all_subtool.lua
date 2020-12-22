local MoveTool = defineDrawSubtool {
    category = "artwork_move",
    name = "move_all",
}

function MoveTool.handlers:addSubtool()
    self._lastCoord = nil
    self._bounds = nil
    self._clampedDiff = nil
    self:setTempTranslation(0, 0)
end

function MoveTool.handlers:onTouch(component, touchData)
    if self._lastCoord == nil then
        self._lastCoord = {
            x = touchData.touchX,
            y = touchData.touchY,
        }
        self._clampedDiff = {
            x = 0,
            y = 0,
        }

        local pathDataBounds = self:drawData():getPathDataBounds()
        self._bounds = {
            minX = -DRAW_MAX_SIZE - pathDataBounds.minX,
            minY = -DRAW_MAX_SIZE - pathDataBounds.minY,
            maxX = DRAW_MAX_SIZE - pathDataBounds.maxX,
            maxY = DRAW_MAX_SIZE - pathDataBounds.maxY,
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
            for i = 1, #self:drawData().pathDataList do
                local pathData = self:drawData().pathDataList[i]
                pathData.tovePath = nil

                for j = 1, #pathData.points do
                    pathData.points[j].x = pathData.points[j].x + self._clampedDiff.x
                    pathData.points[j].y = pathData.points[j].y + self._clampedDiff.y
                end

                if pathData.bendPoint then
                    pathData.bendPoint.x = pathData.bendPoint.x + self._clampedDiff.x
                    pathData.bendPoint.y = pathData.bendPoint.y + self._clampedDiff.y
                end
            end

            self:drawData().bounds = {
                minX = self:drawData().bounds.minX + self._clampedDiff.x,
                minY = self:drawData().bounds.minY + self._clampedDiff.y,
                maxX = self:drawData().bounds.maxX + self._clampedDiff.x,
                maxY = self:drawData().bounds.maxY + self._clampedDiff.y,
            }
        
            self:drawData().fillImageBounds = {
                minX = self:drawData().fillImageBounds.minX + self:drawData().fillPixelsPerUnit * self._clampedDiff.x,
                minY = self:drawData().fillImageBounds.minY + self:drawData().fillPixelsPerUnit * self._clampedDiff.y,
                maxX = self:drawData().fillImageBounds.maxX + self:drawData().fillPixelsPerUnit * self._clampedDiff.x,
                maxY = self:drawData().fillImageBounds.maxY + self:drawData().fillPixelsPerUnit * self._clampedDiff.y,
            }

            self:drawData():resetGraphics()
            self:saveDrawing("move all", component)
        end

        self._lastCoord = nil
        self._bounds = nil
        self._clampedDiff = nil
        self:setTempTranslation(0, 0)
    else
        self:setTempTranslation(self._clampedDiff.x, self._clampedDiff.y)
    end
end
