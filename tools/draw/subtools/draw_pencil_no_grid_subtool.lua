local PencilNoGridTool = defineDrawSubtool {
    category = "artwork_draw",
    name = "pencil_no_grid",
}

function PencilNoGridTool.handlers:addSubtool()
    self._initialCoord = nil
    self._currentPathData = nil
    self._currentPathDataList = {}
end

function PencilNoGridTool.handlers:onTouch(component, touchData)
    if self._initialCoord == nil then
       self._initialCoord = {
            x = touchData.clampedX,
            y = touchData.clampedY,
        }
        self._currentPathData = nil
        self._currentPathDataList = {}
    end

    local newCoord = {
        x = touchData.clampedX,
        y = touchData.clampedY,
    }

    self._currentPathData = {}
    self._currentPathData.points = {self._initialCoord, newCoord}
    self._currentPathData.style = 1
    self._currentPathData.isFreehand = true

    local dist = math.sqrt(math.pow(self._initialCoord.x - touchData.clampedX, 2.0) + math.pow(self._initialCoord.y - touchData.clampedY, 2.0))
    if dist > 0.2 then
        self._initialCoord = newCoord
        table.insert(self._currentPathDataList, self._currentPathData)
        self._currentPathData = nil
    end

    if touchData.touch.released then
        if self._currentPathData ~= nil and (self._currentPathData.points[1].x ~= self._currentPathData.points[2].x or self._currentPathData.points[1].y ~= self._currentPathData.points[2].y) then
            table.insert(self._currentPathDataList, self._currentPathData)
        end

        for i = 1, #self._currentPathDataList do
            self._currentPathDataList[i].tovePath = nil
            self:addPathData(self._currentPathDataList[i])
        end
        self:drawData():resetGraphics()
        self:drawData():resetFill()
        self:saveDrawing("freehand pencil", component)

        self._initialCoord = nil
        self._currentPathData = nil
        self._currentPathDataList = {}
        self:clearTempGraphics()
    else
        self:resetTempGraphics()
        for i = 1, #self._currentPathDataList do
            self:addTempPathData(self._currentPathDataList[i])
        end

        if self._currentPathData ~= nil then
            self:addTempPathData(self._currentPathData)
        end
    end
end
