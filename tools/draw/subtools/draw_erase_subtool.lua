local SMALL_RADIUS = 0.8
local MEDIUM_RADIUS = 1.4
local LARGE_RADIUS = 2.5

local function addSubtool(obj)
    obj._didChange = false
    obj._lastTouchPosition = nil
end

local function onSelected(obj)
    obj:drawData():updatePathsCanvas()
end

local function isPointInCircle(p, circleX, circleY, circleR)
    local dx = p.x - circleX
    local dy = p.y - circleY
    return math.sqrt(dx * dx + dy * dy) < circleR
end

local function onTouch(obj, component, touchData)
    obj._lastTouchPosition = {
        x = touchData.touchX,
        y = touchData.touchY,
    }

    for i = #obj:drawData():currentPathDataList(), 1, -1 do
        if obj:drawData():currentPathDataList()[i].tovePath:nearest(touchData.touchX, touchData.touchY, obj:getRadius()) then
            local pathData = obj:drawData():currentPathDataList()[i]
            obj:removePathData(pathData)

            if pathData.bendPoint == nil and pathData.style == 1 then
                -- we can potentially cut this path data
                pathData.tovePath = nil

                local addPoints = function (p1, p2)
                    local newPathData = util.deepCopyTable(pathData)
                    newPathData.points = {p1, p2}
                    obj:addPathData(newPathData)
                end

                for p = 1, #pathData.points - 1, 2 do
                    local p1 = pathData.points[p]
                    local p2 = pathData.points[p + 1]
                    local isP1InCircle = isPointInCircle(p1, touchData.touchX, touchData.touchY, obj:getRadius())
                    local isP2InCircle = isPointInCircle(p2, touchData.touchX, touchData.touchY, obj:getRadius())

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
                            radius = obj:getRadius(),
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

            obj:drawData():resetGraphics()
            obj._didChange = true
        end
    end

    if obj:drawData():floodClear(touchData.touchX, touchData.touchY, obj:getRadius()) then
        obj._didChange = true
    end

    if touchData.touch.released then
        if obj._didChange then
            obj:drawData():resetGraphics()
            obj:drawData():resetFill()
            obj:drawData():updateBounds()
            obj:saveDrawing("erase", component)
        end
        obj._didChange = false
        obj._lastTouchPosition = nil
    end
end

local function drawOverlay(obj)
    if obj._lastTouchPosition then
        love.graphics.setColor(1.0, 1.0, 1.0, 0.3)
        love.graphics.circle('fill', obj._lastTouchPosition.x, obj._lastTouchPosition.y, obj:getRadius())
    end
end

-- Small erase
local SmallEraseTool = defineDrawSubtool {
    category = "artwork_erase",
    name = "erase_small",
}

function SmallEraseTool:getRadius()
    return SMALL_RADIUS * self:getZoomAmount()
end

function SmallEraseTool.handlers:addSubtool()
    addSubtool(self)
end

function SmallEraseTool.handlers:onSelected()
    onSelected(self)
end

function SmallEraseTool.handlers:onTouch(component, touchData)
    onTouch(self, component, touchData)
end

function SmallEraseTool.handlers:drawOverlay()
    drawOverlay(self)
end

-- Medium erase
local EraseMediumTool = defineDrawSubtool {
    category = "artwork_erase",
    name = "erase_medium",
}

function EraseMediumTool:getRadius()
    return MEDIUM_RADIUS * self:getZoomAmount()
end

function EraseMediumTool.handlers:addSubtool()
    addSubtool(self)
end

function EraseMediumTool.handlers:onSelected()
    onSelected(self)
end

function EraseMediumTool.handlers:onTouch(component, touchData)
    onTouch(self, component, touchData)
end

function EraseMediumTool.handlers:drawOverlay()
    drawOverlay(self)
end

-- Large erase
local LargeEraseTool = defineDrawSubtool {
    category = "artwork_erase",
    name = "erase_large",
}

function LargeEraseTool:getRadius()
    return LARGE_RADIUS * self:getZoomAmount()
end

function LargeEraseTool.handlers:addSubtool()
    addSubtool(self)
end

function LargeEraseTool.handlers:onSelected()
    onSelected(self)
end

function LargeEraseTool.handlers:onTouch(component, touchData)
    onTouch(self, component, touchData)
end

function LargeEraseTool.handlers:drawOverlay()
    drawOverlay(self)
end
