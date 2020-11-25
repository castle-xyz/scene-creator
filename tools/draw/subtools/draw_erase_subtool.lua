local EraseTool = defineDrawSubtool {
    category = "draw",
    name = "erase",
}

function EraseTool.handlers:addSubtool()
    self._didChange = false
end

function EraseTool.handlers:onTouch(component, touchData)
    for i = 1, #self:drawData().pathDataList do
        if self:drawData().pathDataList[i].tovePath:nearest(touchData.touchX, touchData.touchY, 0.5) then
            self:removePathData(self:drawData().pathDataList[i])
            self:drawData():resetGraphics()
            self._didChange = true
            break
        end
    end

    if self:drawData():floodClear(touchData.touchX, touchData.touchY) then
        self._didChange = true
    end

    if touchData.touch.released then
        if self._didChange then
            self:drawData():resetGraphics()
            self:drawData():resetFill()
            self:saveDrawing("erase", component)
        end
        self._didChange = false
    end
end