local function addSubtool(obj)
    obj._initialCoord = nil
    obj._currentPathDataList = nil
end

local function onTouch(obj, component, touchData)
    if obj._initialCoord == nil then
        obj._initialCoord = touchData.roundedCoord
        obj._currentPathDataList = {}
    end

    local shape
    if obj:selectedSubtools().artwork_draw == 'rectangle' then
        shape = obj:drawData():getRectangleShape(obj._initialCoord, touchData.roundedCoord)
    elseif obj:selectedSubtools().artwork_draw == 'circle' then
        local roundDx = floatUnit(obj._initialCoord.x - touchData.touchX)
        local roundDy = floatUnit(obj._initialCoord.y - touchData.touchY)

        shape = obj:drawData():getCircleShape(
            obj._initialCoord,
            touchData.roundedCoord,
            obj:bind(obj:drawData(), 'roundGlobalCoordinatesToGrid'),
            obj:bind(obj:drawData(), 'roundGlobalDistanceToGrid'),
            roundDx,
            roundDy)
    elseif obj:selectedSubtools().artwork_draw == 'triangle' then
        shape = obj:drawData():getTriangleShape(obj._initialCoord, touchData.roundedCoord)
    end

    if shape then
        obj._currentPathDataList = shape
    end

    if touchData.touch.released then
        for i = 1, #obj._currentPathDataList do
            obj._currentPathDataList[i].tovePath = nil
            obj:addPathData(obj._currentPathDataList[i])
        end

        obj:drawData():resetGraphics()
        obj:drawData():resetFill()
        obj:drawData():updateBounds()
        obj:saveDrawing('add ' .. obj:selectedSubtools().artwork_draw, component)

        obj._initialCoord = nil
        obj._currentPathDataList = {}
        obj:clearTempGraphics()
    else
        obj:resetTempGraphics()
        for i = 1, #obj._currentPathDataList do
            obj:addTempPathData(obj._currentPathDataList[i])
        end
    end
end

-- Rectangle
local RectangleTool = defineDrawSubtool {
    category = "artwork_draw",
    name = "rectangle",
}

function RectangleTool.handlers:addSubtool()
    addSubtool(self)
end

function RectangleTool.handlers:onTouch(component, touchData)
    onTouch(self, component, touchData)
end

-- Circle
local CircleTool = defineDrawSubtool {
    category = "artwork_draw",
    name = "circle",
}

function CircleTool.handlers:addSubtool()
    addSubtool(self)
end

function CircleTool.handlers:onTouch(component, touchData)
    onTouch(self, component, touchData)
end

-- Triangle
local TriangleTool = defineDrawSubtool {
    category = "artwork_draw",
    name = "triangle",
}

function TriangleTool.handlers:addSubtool()
    addSubtool(self)
end

function TriangleTool.handlers:onTouch(component, touchData)
    onTouch(self, component, touchData)
end
