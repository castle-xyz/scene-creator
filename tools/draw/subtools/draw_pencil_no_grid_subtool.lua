local PencilNoGridTool = defineDrawSubtool {
    category = "artwork_draw",
    name = "pencil_no_grid",
}

function PencilNoGridTool.handlers:addSubtool()
    self._initialCoord = nil
    self._lastSegmentAngle = nil
    self._currentPathData = nil
    self._currentPathDataList = {}
end

local function diffAngle(a1, a2)
    local d = math.abs(a1 - a2)
    while d > math.pi * 2.0 do
        d = d - math.pi * 2.0
    end

    if math.abs(d - math.pi * 2.0) < d then
        d = math.abs(d - math.pi * 2.0)
    end

    return d
end

-- view-source:https://www.particleincell.com/wp-content/uploads/2012/06/circles.svg
local function computeControlPoints(knots)
    local p1 = {}
    local p2 = {}

    -- rhs vector
    local a = {}
    local b = {}
    local c = {}
    local r = {}

    -- left most segment
    a[1] = 0
    b[1] = 2
    c[1] = 1
    r[1] = knots[1] + 2 * knots[2]

    -- internal segments
    for i = 2, #knots - 2 do
        a[i] = 1
        b[i] = 4
        c[i] = 1
        r[i] = 4 * knots[i] + 2 * knots[i + 1]
    end

    -- right segment
    a[#knots - 1] = 2
    b[#knots - 1] = 7
    c[#knots - 1] = 0
    r[#knots - 1] = 8 * knots[#knots - 1] + knots[#knots]

    -- solves Ax=b with the Thomas algorithm (from Wikipedia)
    for i = 2, #knots - 1 do
        local m = a[i] / b[i - 1]
        b[i] = b[i] - m * c[i - 1]
        r[i] = r[i] - m * r[i - 1]
    end

    p1[#knots - 1] = r[#knots - 1] / b[#knots - 1]
    for i = #knots - 2, 1, -1 do
        p1[i] = (r[i] - c[i] * p1[i + 1]) / b[i]
    end

    -- we have p1, now compute p2
    for i = 1, #knots - 2 do
        p2[i] = 2 * knots[i + 1] - p1[i + 1]
    end

    p2[#knots - 1] = 0.5 * (knots[#knots] + p1[#knots - 1])

    return {
        p1 = p1,
        p2 = p2,
    }
end

function PencilNoGridTool.handlers:onTouch(component, touchData)
    if self._initialCoord == nil then
       self._initialCoord = {
            x = touchData.clampedX,
            y = touchData.clampedY,
        }
        self._currentPathData = nil
        self._currentPathDataList = {}
        self._lastSegmentAngle = nil
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
    local angle = math.atan2(self._initialCoord.y - touchData.clampedY, self._initialCoord.x - touchData.clampedX)
    local addPoint = false

    if dist > 0.5 * self:getZoomAmount() then
        addPoint = true
    elseif self._lastSegmentAngle and dist > 0.1 and diffAngle(self._lastSegmentAngle, angle) > 0.5 then
        addPoint = true
    end

    if addPoint then
        self._initialCoord = newCoord
        table.insert(self._currentPathDataList, self._currentPathData)
        self._currentPathData = nil
        self._lastSegmentAngle = angle

        local xPoints = {}
        for i = 1, #self._currentPathDataList do
            table.insert(xPoints, self._currentPathDataList[i].points[1].x)
        end

        if #xPoints > 2 then
            printObject(xPoints)
            printObject(computeControlPoints(xPoints))
        end
    end

    if touchData.touch.released then
        if self._currentPathData ~= nil and (self._currentPathData.points[1].x ~= self._currentPathData.points[2].x or self._currentPathData.points[1].y ~= self._currentPathData.points[2].y) then
            table.insert(self._currentPathDataList, self._currentPathData)
        end

        for i = 1, #self._currentPathDataList do
            self._currentPathDataList[i].tovePath = nil
            self:addPathData(self._currentPathDataList[i])
        end
        self:drawDataFrame():resetGraphics()
        self:drawDataFrame():resetFill()
        self:drawData():updateBounds()
        self:saveDrawing("freehand pencil", component)

        self._initialCoord = nil
        self._currentPathData = nil
        self._currentPathDataList = {}
        self._lastSegmentAngle = nil
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
