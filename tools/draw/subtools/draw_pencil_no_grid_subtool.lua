local PencilNoGridTool = defineDrawSubtool {
    category = "artwork_draw",
    name = "pencil_no_grid",
}

function PencilNoGridTool.handlers:addSubtool()
    self._lastSegmentAngle = nil
    self._pathData = nil
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

local function updateControlPoints(pathData)
    local xPoints = {}
    local yPoints = {}
    for i = 1, #pathData.points do
        table.insert(xPoints, pathData.points[i].x)
        table.insert(yPoints, pathData.points[i].y)
    end


    if #xPoints > 2 then
        local xControlPoints = computeControlPoints(xPoints)
        local yControlPoints = computeControlPoints(yPoints)

        for i = 2, #pathData.points do
            pathData.points[i].cp1x = xControlPoints.p1[i - 1]
            pathData.points[i].cp2x = xControlPoints.p2[i - 1]
            pathData.points[i].cp1y = yControlPoints.p1[i - 1]
            pathData.points[i].cp2y = yControlPoints.p2[i - 1]
        end
    end
end

function PencilNoGridTool.handlers:onTouch(component, touchData)
    if self._pathData == nil then
       local initialCoord = {
            x = touchData.clampedX,
            y = touchData.clampedY,
        }

        self._pathData = {}
        self._pathData.points = {initialCoord, initialCoord}
        self._pathData.style = 1
        self._pathData.isFreehand = true
        self._lastSegmentAngle = nil
    end

    local newCoord = {
        x = touchData.clampedX,
        y = touchData.clampedY,
    }

    local lastCoord = self._pathData.points[#self._pathData.points - 1]
    self._pathData.points[#self._pathData.points] = newCoord

    local dist = math.sqrt(math.pow(lastCoord.x - touchData.clampedX, 2.0) + math.pow(lastCoord.y - touchData.clampedY, 2.0))
    local angle = math.atan2(lastCoord.y - touchData.clampedY, lastCoord.x - touchData.clampedX)
    local addPoint = false

    if dist > 0.8 * self:getZoomAmount() then
        addPoint = true
    elseif self._lastSegmentAngle and dist > 0.3 * self:getZoomAmount() and diffAngle(self._lastSegmentAngle, angle) > 0.5 then
        --addPoint = true
    end

    if touchData.touch.released then
        updateControlPoints(self._pathData)
        self:addPathData(util.deepCopyTable(self._pathData))

        self:drawDataFrame():resetGraphics()
        self:drawDataFrame():resetFill()
        self:drawData():updateBounds()
        self:saveDrawing("freehand pencil", component)

        self._pathData = nil
        self._lastSegmentAngle = nil
        self:clearTempGraphics()
    else
        if addPoint then
            self._lastSegmentAngle = angle
            table.insert(self._pathData.points, newCoord)
        end

        updateControlPoints(self._pathData)

        self:resetTempGraphics()
        self:addTempPathData(util.deepCopyTable(self._pathData))
    end
end
