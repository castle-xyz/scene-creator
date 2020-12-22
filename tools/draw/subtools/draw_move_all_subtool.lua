local MoveTool = defineDrawSubtool {
    category = "artwork_move",
    name = "move_all",
}

function MoveTool.handlers:addSubtool()
    self._initialCoord = nil
    self._bounds = nil
    self:setTempTranslation(0, 0)
end

function MoveTool.handlers:onTouch(component, touchData)
    if self._initialCoord == nil then
        self._initialCoord = {
            x = touchData.touchX,
            y = touchData.touchY,
        }

        local pathDataBounds = self:drawData():getPathDataBounds()
        self._bounds = {
            minX = -DRAW_MAX_SIZE - pathDataBounds.minX,
            minY = -DRAW_MAX_SIZE - pathDataBounds.minY,
            maxX = DRAW_MAX_SIZE - pathDataBounds.maxX,
            maxY = DRAW_MAX_SIZE - pathDataBounds.maxY,
        }
    end

    local clampedDiff = {
        x = touchData.touchX - self._initialCoord.x,
        y = touchData.touchY - self._initialCoord.y,
    }

    if clampedDiff.x < self._bounds.minX then
        clampedDiff.x = self._bounds.minX
    end
    if clampedDiff.y < self._bounds.minY then
        clampedDiff.y = self._bounds.minY
    end
    if clampedDiff.x > self._bounds.maxX then
        clampedDiff.x = self._bounds.maxX
    end
    if clampedDiff.y > self._bounds.maxY then
        clampedDiff.y = self._bounds.maxY
    end

    if touchData.touch.released then
        if not floatEquals(clampedDiff.x, 0.0) or not floatEquals(clampedDiff.y, 0.0) then
            for i = 1, #self:drawData().pathDataList do
                local pathData = self:drawData().pathDataList[i]
                pathData.tovePath = nil

                for j = 1, #pathData.points do
                    pathData.points[j].x = pathData.points[j].x + clampedDiff.x
                    pathData.points[j].y = pathData.points[j].y + clampedDiff.y
                end

                if pathData.bendPoint then
                    pathData.bendPoint.x = pathData.bendPoint.x + clampedDiff.x
                    pathData.bendPoint.y = pathData.bendPoint.y + clampedDiff.y
                end
            end

            self:drawData().bounds = {
                minX = self:drawData().bounds.minX + clampedDiff.x,
                minY = self:drawData().bounds.minY + clampedDiff.y,
                maxX = self:drawData().bounds.maxX + clampedDiff.x,
                maxY = self:drawData().bounds.maxY + clampedDiff.y,
            }
        
            self:drawData().fillImageBounds = {
                minX = self:drawData().fillImageBounds.minX + self:drawData().fillPixelsPerUnit * clampedDiff.x,
                minY = self:drawData().fillImageBounds.minY + self:drawData().fillPixelsPerUnit * clampedDiff.y,
                maxX = self:drawData().fillImageBounds.maxX + self:drawData().fillPixelsPerUnit * clampedDiff.x,
                maxY = self:drawData().fillImageBounds.maxY + self:drawData().fillPixelsPerUnit * clampedDiff.y,
            }

            self:drawData():resetGraphics()
            self:saveDrawing("move all", component)
        end

        self._initialCoord = nil
        self._bounds = nil
        self:setTempTranslation(0, 0)
    else
        self:setTempTranslation(clampedDiff.x, clampedDiff.y)
    end
end
