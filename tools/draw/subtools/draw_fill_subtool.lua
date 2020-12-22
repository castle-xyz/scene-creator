local FillTool = defineDrawSubtool {
    category = "artwork",
    name = "fill",
}

function FillTool:getRadius()
    return 0.5 * self:getZoomAmount()
end

function FillTool.handlers:addSubtool()
    self._didChange = false
end

function FillTool.handlers:onSelected()
    self:drawData():updatePathsCanvas()
end

function FillTool.handlers:onTouch(component, touchData)
    for i = #self:drawData().pathDataList, 1, -1 do
        if self:drawData().pathDataList[i].tovePath:nearest(touchData.touchX, touchData.touchY, self:getRadius()) then
            self:drawData().pathDataList[i].shouldFill = true
        end
    end

    for i = #self:drawData().pathDataList, 1, -1 do
        if self:drawData().pathDataList[i].shouldFill then
            for j = i - 1, 1, -1 do
                if self:drawData().pathDataList[j].shouldFill then
                    break
                end

                if not self:drawData():arePathDatasFloodFillable(self:drawData().pathDataList[j], self:drawData().pathDataList[j + 1]) then
                    break
                end

                self:drawData().pathDataList[j].shouldFill = true
            end

            for j = i + 1, #self:drawData().pathDataList do
                if self:drawData().pathDataList[j].shouldFill then
                    break
                end

                if not self:drawData():arePathDatasFloodFillable(self:drawData().pathDataList[j - 1], self:drawData().pathDataList[j]) then
                    break
                end

                self:drawData().pathDataList[j].shouldFill = true
            end
        end
    end

    local filledPath = false
    for i = #self:drawData().pathDataList, 1, -1 do
        if self:drawData().pathDataList[i].shouldFill then
            self:drawData().pathDataList[i].tovePath = nil
            self:drawData().pathDataList[i].color = util.deepCopyTable(self:drawData().color)
            self:drawData().pathDataList[i].shouldFill = nil
            filledPath = true
        end
    end

    if filledPath then
        self._didChange = true
        self:drawData():resetGraphics()
    else
        -- don't allow filling both path and fill in the same frame.
        -- makes it easier to fill only a path
        if self:drawData():floodFill(touchData.touchX, touchData.touchY) then
            self._didChange = true
        end
    end

    if touchData.touch.released then
        if self._didChange then
            self:saveDrawing("fill", component)
        end
        self._didChange = false
    end
end
