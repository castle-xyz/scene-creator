local BendTool = defineDrawSubtool {
    category = "draw",
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

        for i = 1, #self:drawData().pathDataList do
            if not self:drawData().pathDataList[i].isFreehand and self:drawData().pathDataList[i].tovePath:nearest(touchData.touchX, touchData.touchY, 0.5) then
                table.insert(self._grabbedPaths, self:drawData().pathDataList[i])
                self:removePathData(self:drawData().pathDataList[i])
                self:drawData():resetGraphics()
                break
            end
        end
    end

    local distance = math.sqrt(math.pow(self._initialCoord.x - touchData.touchX, 2.0) + math.pow(self._initialCoord.y - touchData.touchY, 2.0))
    if distance > 0.1 then
        self._isUsingBendPoint = true
    end

    if #self._grabbedPaths > 0 then
        if self._isUsingBendPoint then
            self._grabbedPaths[1].style = 1
            self._grabbedPaths[1].bendPoint = {
                x = touchData.touchX,
                y = touchData.touchY,
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
