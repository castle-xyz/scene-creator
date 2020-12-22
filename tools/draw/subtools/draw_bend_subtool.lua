local BendTool = defineDrawSubtool {
    category = "artwork_move",
    name = "bend",
}

function BendTool.handlers:addSubtool()
    self._grabbedPaths = nil
    self._initialCoord = {}
    self._isUsingBendPoint = false
end

function BendTool.handlers:onTouch(component, touchData)
    if self._grabbedPaths == nil then
        self._grabbedPaths = {}
        self._initialCoord = {
            x = touchData.touchX,
            y = touchData.touchY,
        }
        self._isUsingBendPoint = false

        for i = 1, #self:drawData():currentPathDataList() do
            if not self:drawData():currentPathDataList()[i].isFreehand and self:drawData():currentPathDataList()[i].tovePath:nearest(touchData.touchX, touchData.touchY, 0.5 * self:getZoomAmount()) then
                table.insert(self._grabbedPaths, self:drawData():currentPathDataList()[i])
                self:removePathData(self:drawData():currentPathDataList()[i])
                self:drawData():resetGraphics()
                break
            end
        end
    end

    local distance = math.sqrt(math.pow(self._initialCoord.x - touchData.touchX, 2.0) + math.pow(self._initialCoord.y - touchData.touchY, 2.0))
    if distance > 0.1 * self:getZoomAmount() then
        self._isUsingBendPoint = true
    end

    if #self._grabbedPaths > 0 then
        if self._isUsingBendPoint then
            self._grabbedPaths[1].style = 1
            self._grabbedPaths[1].bendPoint = {
                x = touchData.clampedX,
                y = touchData.clampedY,
            }
        end
        self._grabbedPaths[1].tovePath = nil
    end

    if touchData.touch.released then
        if #self._grabbedPaths > 0 then
            if not self._isUsingBendPoint then
                if self._grabbedPaths[1].bendPoint then
                    self._grabbedPaths[1].style = 1
                    self._grabbedPaths[1].bendPoint = nil
                else
                    self._grabbedPaths[1].style = self._grabbedPaths[1].style + 1
                    if self._grabbedPaths[1].style > 3 then
                        self._grabbedPaths[1].style = 1
                    end
                end
            end

            self:addPathData(self._grabbedPaths[1])

            self:drawData():resetFill()
            self:drawData():resetGraphics()
            self:drawData():updateBounds()
            self:saveDrawing("bend", component)
        end

        self._grabbedPaths = nil
        self:clearTempGraphics()
        self._initialCoord = nil
    else
        if #self._grabbedPaths > 0 then
            self:resetTempGraphics()
            self:addTempPathData(self._grabbedPaths[1])
        end
    end
end
