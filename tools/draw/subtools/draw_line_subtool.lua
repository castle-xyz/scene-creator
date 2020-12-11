local LineTool = defineDrawSubtool {
    category = "artwork_draw",
    name = "line",
}

function LineTool.handlers:addSubtool()
    self._initialCoord = nil
end

function LineTool.handlers:onTouch(component, touchData)
    if self._initialCoord == nil then
        self._initialCoord = touchData.roundedCoord
    end

    local pathData = {}
    pathData.points = {self._initialCoord, touchData.roundedCoord}
    pathData.style = 1

    if touchData.touch.released then
        self:addPathData(pathData)
        self:drawData():resetGraphics()
        self:drawData():resetFill()
        self:drawData():updateBounds()
        self:saveDrawing("line", component)

        self._initialCoord = nil
        self:clearTempGraphics()
    else
        self:resetTempGraphics()
        self:addTempPathData(pathData)
    end
end
