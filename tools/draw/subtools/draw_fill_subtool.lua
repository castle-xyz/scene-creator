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
    for i = #self:drawData():currentPathDataList(), 1, -1 do
        if self:drawData():currentPathDataList()[i].tovePath:nearest(touchData.touchX, touchData.touchY, self:getRadius()) then
            if not floatArrayEquals(self:drawData().color, self:drawData():currentPathDataList()[i].color) then
                self:drawData():currentPathDataList()[i].shouldFill = true
            end
        end
    end

    for i = #self:drawData():currentPathDataList(), 1, -1 do
        if self:drawData():currentPathDataList()[i].shouldFill then
            for j = i - 1, 1, -1 do
                if self:drawData():currentPathDataList()[j].shouldFill then
                    break
                end

                if not self:drawData():arePathDatasFloodFillable(self:drawData():currentPathDataList()[j], self:drawData():currentPathDataList()[j + 1]) then
                    break
                end

                self:drawData():currentPathDataList()[j].shouldFill = true
            end

            for j = i + 1, #self:drawData():currentPathDataList() do
                if self:drawData():currentPathDataList()[j].shouldFill then
                    break
                end

                if not self:drawData():arePathDatasFloodFillable(self:drawData():currentPathDataList()[j - 1], self:drawData():currentPathDataList()[j]) then
                    break
                end

                self:drawData():currentPathDataList()[j].shouldFill = true
            end
        end
    end

    local filledPath = false
    for i = #self:drawData():currentPathDataList(), 1, -1 do
        if self:drawData():currentPathDataList()[i].shouldFill then
            self:drawData():currentPathDataList()[i].tovePath = nil
            self:drawData():currentPathDataList()[i].color = util.deepCopyTable(self:drawData().color)
            self:drawData():currentPathDataList()[i].shouldFill = nil
            filledPath = true
        end
    end

    if filledPath then
        self._didChange = true
        self:drawData():resetGraphics()
    else
        -- don't allow filling both path and fill in the same frame.
        -- makes it easier to fill only a path
        if self:drawData():currentLayerFrame():floodFill(touchData.touchX, touchData.touchY) then
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
