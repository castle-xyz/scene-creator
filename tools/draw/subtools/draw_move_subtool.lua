local MoveTool = defineDrawSubtool {
    category = "artwork_move",
    name = "move",
}

function MoveTool.handlers:addSubtool()
    self._grabbedPaths = nil
end

function MoveTool.handlers:onTouch(component, touchData)
    if self._grabbedPaths == nil then
        self._grabbedPaths = {}

        for i = 1, #self:drawDataFrame().pathDataList do
            if not self:drawDataFrame().pathDataList[i].isFreehand then
                for p = 1, #self:drawDataFrame().pathDataList[i].points do
                    local distance = math.sqrt(math.pow(touchData.touchX - self:drawDataFrame().pathDataList[i].points[p].x, 2.0) + math.pow(touchData.touchY - self:drawDataFrame().pathDataList[i].points[p].y, 2.0))

                    if distance < self:drawData().scale * 0.05 then
                        self:drawDataFrame().pathDataList[i].grabPointIndex = p
                        table.insert(self._grabbedPaths, self:drawDataFrame().pathDataList[i])
                        break
                    end
                end
            end
        end

        for i = 1, #self._grabbedPaths do
            self:removePathData(self._grabbedPaths[i])
        end

        if #self._grabbedPaths == 0 then
            for i = 1, #self:drawDataFrame().pathDataList do
                if not self:drawDataFrame().pathDataList[i].isFreehand then
                    local pathData = self:drawDataFrame().pathDataList[i]
                    local distance, t, subpath = pathData.tovePath:nearest(touchData.touchX, touchData.touchY, 0.5 * self:getZoomAmount())
                    if subpath then
                        local pointX, pointY = subpath:position(t)
                        self:removePathData(pathData)
                        local touchPoint = {x = touchData.touchX, y = touchData.touchY}

                        -- todo: figure out path ids here
                        local newPathData1 = {
                            points = {
                                pathData.points[1],
                                touchPoint
                            },
                            style = pathData.style,
                            color = pathData.color,
                            grabPointIndex = 2
                        }

                        local newPathData2 = {
                            points = {
                                touchPoint,
                                pathData.points[2]
                            },
                            style = pathData.style,
                            color = pathData.color,
                            grabPointIndex = 1
                        }

                        table.insert(self._grabbedPaths, newPathData1)
                        table.insert(self._grabbedPaths, newPathData2)

                        break
                    end
                end
            end
        end

        if #self._grabbedPaths > 0 then
            self:drawDataFrame():resetGraphics()
        end
    end

    for i = 1, #self._grabbedPaths do
        self._grabbedPaths[i].points[self._grabbedPaths[i].grabPointIndex].x = touchData.roundedX
        self._grabbedPaths[i].points[self._grabbedPaths[i].grabPointIndex].y = touchData.roundedY

        self._grabbedPaths[i].tovePath = nil
    end

    if touchData.touch.released then
        if self._grabbedPaths and #self._grabbedPaths > 0 then
            for i = 1, #self._grabbedPaths do
                self:addPathData(self._grabbedPaths[i])
            end

            self:drawDataFrame():resetGraphics()
            self:drawDataFrame():resetFill()
            self:drawData():updateBounds()
            self:saveDrawing("move", component)
        end

        self._grabbedPaths = nil
        self:clearTempGraphics()
    else
        self:resetTempGraphics()

        for i = 1, #self._grabbedPaths do
            self:addTempPathData(self._grabbedPaths[i])
        end
    end
end
