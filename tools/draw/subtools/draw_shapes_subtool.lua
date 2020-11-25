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
    if obj.drawTool._subtool == 'rectangle' then
        shape = obj.drawTool:drawData():getRectangleShape(obj._initialCoord, touchData.roundedCoord)
    elseif obj.drawTool._subtool == 'circle' then
        local roundDx = floatUnit(obj._initialCoord.x - touchData.touchX)
        local roundDy = floatUnit(obj._initialCoord.y - touchData.touchY)

        shape = obj.drawTool:drawData():getCircleShape(
            obj._initialCoord,
            touchData.roundedCoord,
            obj.drawTool:bind(obj.drawTool:drawData(), 'roundGlobalCoordinatesToGrid'),
            obj.drawTool:bind(obj.drawTool:drawData(), 'roundGlobalDistanceToGrid'),
            roundDx,
            roundDy)
    elseif obj.drawTool._subtool == 'triangle' then
        shape = obj.drawTool:drawData():getTriangleShape(obj._initialCoord, touchData.roundedCoord)
    end

    if shape then
        obj._currentPathDataList = shape
    end

    if touchData.touch.released then
        for i = 1, #obj._currentPathDataList do
            obj._currentPathDataList[i].tovePath = nil
            obj.drawTool:addPathData(obj._currentPathDataList[i])
        end

        obj.drawTool:drawData():resetGraphics()
        obj.drawTool:drawData():resetFill()
        obj.drawTool:saveDrawing('add ' .. obj.drawTool._subtool, component)

        obj._initialCoord = nil
        obj._currentPathDataList = {}
        obj.drawTool:clearTempGraphics()
    else
        obj.drawTool:resetTempGraphics()
        for i = 1, #obj._currentPathDataList do
            obj.drawTool:addTempPathData(obj._currentPathDataList[i])
        end
    end
end

-- Rectangle
local RectangleTool = defineDrawSubtool {
    category = "draw",
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
    category = "draw",
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
    category = "draw",
    name = "triangle",
}

function TriangleTool.handlers:addSubtool()
    addSubtool(self)
end

function TriangleTool.handlers:onTouch(component, touchData)
    onTouch(self, component, touchData)
end
