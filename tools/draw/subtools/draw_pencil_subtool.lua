local PencilTool = defineDrawSubtool {
    category = "artwork_draw",
    name = "pencil",
}

function PencilTool.handlers:addSubtool()
    self._initialCoord = nil
    self._currentPathData = nil
    self._currentPathDataList = {}
end

function PencilTool.handlers:onTouch(component, touchData)
    if self._initialCoord == nil then
        self._initialCoord = touchData.roundedCoord
        self._currentPathData = nil
        self._currentPathDataList = {}
    end

    local angle = math.atan2(touchData.touchY - self._initialCoord.y, touchData.touchX - self._initialCoord.x)
    if angle < 0.0 then
        angle = angle + math.pi * 2.0
    end
    local angleRoundedTo8Directions = math.floor((angle + (math.pi * 2.0) / (8.0 * 2.0)) * 8.0 / (math.pi * 2.0))
    if angleRoundedTo8Directions > 7 then
        angleRoundedTo8Directions = 0
    end
    local distFromOriginalPoint = math.sqrt(math.pow(touchData.touchX - self._initialCoord.x, 2.0) + math.pow(touchData.touchY - self._initialCoord.y, 2.0))
    local newAngle = (angleRoundedTo8Directions * (math.pi * 2.0) / 8.0)
    local direction = {x = math.cos(newAngle), y = math.sin(newAngle)}

    local cellSize = self:drawData():gridCellSize()

    if distFromOriginalPoint > cellSize then
        if self._currentPathData ~= nil and (self._currentPathData.points[1].x ~= self._currentPathData.points[2].x or self._currentPathData.points[1].y ~= self._currentPathData.points[2].y) then
            table.insert(self._currentPathDataList, self._currentPathData)

            self._initialCoord = self._currentPathData.points[2]
        end
    end

    distFromOriginalPoint = math.sqrt(math.pow(touchData.touchX - self._initialCoord.x, 2.0) + math.pow(touchData.touchY - self._initialCoord.y, 2.0)) - cellSize * 0.5
    local newRoundedX, newRoundedY = self:drawData():roundGlobalCoordinatesToGrid(self._initialCoord.x + direction.x * distFromOriginalPoint, self._initialCoord.y + direction.y * distFromOriginalPoint)
        
    self._currentPathData = {}
    self._currentPathData.points = {self._initialCoord, {
        x = newRoundedX,
        y = newRoundedY,
    }}
    self._currentPathData.style = 1

    if touchData.touch.released then
        if self._currentPathData ~= nil and (self._currentPathData.points[1].x ~= self._currentPathData.points[2].x or self._currentPathData.points[1].y ~= self._currentPathData.points[2].y) then
            table.insert(self._currentPathDataList, self._currentPathData)
        end

        local newPathDataList = simplifyPathDataList(self._currentPathDataList)

        for i = 1, #newPathDataList do
            newPathDataList[i].tovePath = nil
            self:addPathData(newPathDataList[i])
        end
        self:drawData():resetGraphics()
        self:drawData():resetFill()
        self:saveDrawing("pencil", component)

        self._initialCoord = nil
        self._currentPathData = nil
        self._currentPathDataList = {}
        self:clearTempGraphics()
    else
        self:resetTempGraphics()
        for i = 1, #self._currentPathDataList do
            self:addTempPathData(self._currentPathDataList[i])
        end
        self:addTempPathData(self._currentPathData)
    end
end
