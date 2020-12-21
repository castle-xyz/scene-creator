local EraseTool = defineDrawSubtool {
    category = "artwork",
    name = "erase",
}

local ERASE_RADIUS = 1.2

function EraseTool:getRadius()
    return ERASE_RADIUS * self:getZoomAmount()
end

function EraseTool.handlers:addSubtool()
    self._didChange = false
    self._lastTouchPosition = nil
end

function EraseTool.handlers:onSelected()
    self:drawData():updatePathsCanvas()
end

local function isPointInCircle(p, circleX, circleY, circleR)
    local dx = p.x - circleX
    local dy = p.y - circleY
    return math.sqrt(dx * dx + dy * dy) < circleR
end

function EraseTool.handlers:onTouch(component, touchData)
    self._lastTouchPosition = {
        x = touchData.touchX,
        y = touchData.touchY,
    }

    for i = #self:drawData().pathDataList, 1, -1 do
        if self:drawData().pathDataList[i].tovePath:nearest(touchData.touchX, touchData.touchY, self:getRadius()) then
            local pathData = self:drawData().pathDataList[i]
            self:removePathData(pathData)

            if pathData.bendPoint == nil and pathData.style == 1 then
                -- we can potentially cut this path data
                pathData.tovePath = nil

                local addPoints = function (p1, p2)
                    local newPathData = util.deepCopyTable(pathData)
                    newPathData.points = {p1, p2}
                    self:addPathData(newPathData)
                end

                for p = 1, #pathData.points - 1, 2 do
                    local p1 = pathData.points[p]
                    local p2 = pathData.points[p + 1]
                    local isP1InCircle = isPointInCircle(p1, touchData.touchX, touchData.touchY, self:getRadius())
                    local isP2InCircle = isPointInCircle(p2, touchData.touchX, touchData.touchY, self:getRadius())

                    if isP1InCircle and isP2InCircle then
                        -- both points are in circle, can erase this segment completely
                    else
                        local intersections = subpathDataIntersection({
                            type = "line",
                            p1 = p1,
                            p2 = p2,
                        }, {
                            type = "arc",
                            center = {
                                x = touchData.touchX,
                                y = touchData.touchY,
                            },
                            radius = self:getRadius(),
                            startAngle = 0.0,
                            endAngle = 2 * math.pi,
                        })

                        if #intersections > 0 then
                            if isP1InCircle then
                                addPoints(intersections[1], p2)
                            elseif isP2InCircle then
                                addPoints(p1, intersections[1])
                            else
                                -- neither point is in circle, but line still passes through circle
                                if #intersections == 2 then
                                    -- this should always be true. not sure what it'd mean if this is false

                                    if pointsDistance(p1, intersections[1]) < pointsDistance(p1, intersections[2]) then
                                        addPoints(p1, intersections[1])
                                        addPoints(intersections[2], p2)
                                    else
                                        addPoints(p1, intersections[2])
                                        addPoints(intersections[1], p2)
                                    end
                                end
                            end
                        else
                            addPoints(p1, p2)
                        end
                    end
                end
            end

            self:drawData():resetGraphics()
            self._didChange = true
        end
    end

    if self:drawData():floodClear(touchData.touchX, touchData.touchY, self:getRadius()) then
        self._didChange = true
    end

    if touchData.touch.released then
        if self._didChange then
            self:drawData():resetGraphics()
            self:drawData():resetFill()
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
