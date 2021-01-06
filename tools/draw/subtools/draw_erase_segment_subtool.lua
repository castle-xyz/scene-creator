local EraseTool = defineDrawSubtool {
    category = "artwork_erase",
    name = "erase_segment",
}

local ERASE_RADIUS = 1.0

function EraseTool:getRadius()
    return ERASE_RADIUS * self:getZoomAmount()
end

function EraseTool.handlers:addSubtool()
    self._didChange = false
    self._lastTouchPosition = nil
end

function EraseTool.handlers:onSelected()
    self:drawDataFrame():updatePathsCanvas()
end

function EraseTool.handlers:onTouch(component, touchData)
    self._lastTouchPosition = {
        x = touchData.touchX,
        y = touchData.touchY,
    }

    for i = #self:drawDataFrame().pathDataList, 1, -1 do
        if self:drawDataFrame().pathDataList[i].tovePath:nearest(touchData.touchX, touchData.touchY, self:getRadius()) then
            self:removePathData(self:drawDataFrame().pathDataList[i])
            self:drawDataFrame():resetGraphics()
            self._didChange = true
        end
    end

    if self:drawDataFrame():floodClear(touchData.touchX, touchData.touchY, self:getRadius()) then
        self._didChange = true
    end

    if touchData.touch.released then
        if self._didChange then
            self:drawDataFrame():resetGraphics()
            self:drawDataFrame():resetFill()
            self:drawData():updateBounds()
            self:saveDrawing("erase", component)
        end
        self._didChange = false
        self._lastTouchPosition = nil
    end
end

function EraseTool.handlers:drawOverlay()
    if self._lastTouchPosition then
        love.graphics.setColor(1.0, 1.0, 1.0, 0.3)
        love.graphics.circle('fill', self._lastTouchPosition.x, self._lastTouchPosition.y, self:getRadius())
    end
end
