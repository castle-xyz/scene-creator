local function addSubtool(obj)
    obj._initialCoord = nil
end

local function onTouch(obj, component, touchData)
    if obj._initialCoord == nil then
        obj._initialCoord = touchData.roundedCoord
    end

    local shape
    if obj:selectedSubtools().collision_draw == 'rectangle' then
        shape = obj:physicsBodyData():getRectangleShape(obj._initialCoord, touchData.roundedCoord)
    elseif obj:selectedSubtools().collision_draw == 'circle' then
        local roundDx = floatUnit(obj._initialCoord.x - touchData.touchX)
        local roundDy = floatUnit(obj._initialCoord.y - touchData.touchY)

        shape = obj:physicsBodyData():getCircleShape(obj._initialCoord, touchData.roundedCoord, obj:bind(obj:drawData(), 'roundGlobalCoordinatesToGrid'), obj:bind(obj:drawData(), 'roundGlobalDistanceToGrid'), touchData.roundDx, touchData.roundDy)
    elseif obj:selectedSubtools().collision_draw == 'triangle' then
        shape = obj:physicsBodyData():getTriangleShape(obj._initialCoord, touchData.roundedCoord)
    end

    if shape then
        obj:physicsBodyData().tempShape = shape
    end

    if touchData.touch.released then
        if obj:physicsBodyData():commitTempShape() then
            obj:saveDrawing('add ' .. obj:selectedSubtools().collision_draw, component)
        end

        obj._initialCoord = nil
    end
end

-- Rectangle
local RectangleTool = defineDrawSubtool {
    category = "collision_draw",
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
    category = "collision_draw",
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
    category = "collision_draw",
    name = "triangle",
}

function TriangleTool.handlers:addSubtool()
    addSubtool(self)
end

function TriangleTool.handlers:onTouch(component, touchData)
    onTouch(self, component, touchData)
end
