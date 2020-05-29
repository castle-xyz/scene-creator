local DrawTool =
    defineCoreBehavior {
    name = "Draw",
    propertyNames = {},
    dependencies = {
        "Body",
        "Drawing"
    },
    tool = {
        icon = "pencil-alt",
        iconFamily = "FontAwesome5",
        needsPerformingOff = true,
        isFullScreen = true,
    }
}


-- Behavior management

local _paths
local _initialCoord
local _graphics

local _tempGraphics

function DrawTool.handlers:addBehavior(opts)
    
end

-- Methods

local GRID_HORIZONTAL_PADDING = 0.1 * DEFAULT_VIEW_WIDTH
local GRID_TOP_PADDING = 0.2 * DEFAULT_VIEW_WIDTH
local GRID_SIZE = 10
local GRID_WIDTH = DEFAULT_VIEW_WIDTH - GRID_HORIZONTAL_PADDING * 2.0

local function globalToGridCoordinates(x, y)
    local gridX = 1.0 + (GRID_SIZE - 1) * (x - GRID_HORIZONTAL_PADDING) / GRID_WIDTH
    local gridY = 1.0 + (GRID_SIZE - 1) * (y - GRID_TOP_PADDING) / GRID_WIDTH
    return gridX, gridY
end

local function gridToGlobalCoordinates(x, y)
    local globalX = GRID_HORIZONTAL_PADDING + ((x - 1.0) * GRID_WIDTH / (GRID_SIZE - 1))
    local globalY = GRID_TOP_PADDING + ((y - 1.0) * GRID_WIDTH / (GRID_SIZE - 1))
    return globalX, globalY
end

local function roundGlobalCoordinatesToGrid(x, y)
    local gridX, gridY = globalToGridCoordinates(x, y)

    gridX = math.floor(gridX + 0.5)
    gridY = math.floor(gridY + 0.5)

    if gridX <= 0 then
        gridX = 1
    elseif gridX > GRID_SIZE then
        gridX = GRID_SIZE
    end

    if gridY <= 0 then
        gridY = 1
    elseif gridY > GRID_SIZE then
        gridY = GRID_SIZE
    end

    return gridToGlobalCoordinates(gridX, gridY)
end

local function addPath(path)
    table.insert(_paths, path)
end

local function removePath(path)
    for i = #_paths, 1, -1 do
        if _paths[i] == path then
            table.remove(_paths, i)
        end
    end
end

local function resetGraphics()
    _graphics = tove.newGraphics()
    _graphics:setDisplay("mesh", 1024)

    for i = 1, #_paths do
        _graphics:addPath(_paths[i].path)
    end
end

local function drawEndOfArc(path, p1x, p1y, p2x, p2y)
    if p1x == p2x and p1y == p2y then
        return
    end

    local subpath = tove.newSubpath()
    path:addSubpath(subpath)
    subpath:moveTo(p1x, p1y)
    subpath:lineTo(p2x, p2y)
end

local function drawPath(pathData)
    local path = pathData.path
    local p1 = pathData.p1
    local p2 = pathData.p2
    local style = pathData.style

    local subpath = tove.newSubpath()
    path:addSubpath(subpath)

    if style == 1 then
        subpath:moveTo(p1.x, p1.y)
        subpath:lineTo(p2.x, p2.y)
        return
    end

    local isOver = style == 2

    if p1.x > p2.x or (p1.x == p2.x and p1.y > p2.y) then
        local t = p1
        p1 = p2
        p2 = t
    end

    local radius = math.min(math.abs(p2.x - p1.x), math.abs(p2.y - p1.y))
    local xIsLonger = math.abs(p2.x - p1.x) > math.abs(p2.y - p1.y)

    if radius == 0 then
        subpath:moveTo(p1.x, p1.y)
        subpath:lineTo(p2.x, p2.y)
    else
        local circleCenter = {}
        local startAngle

        if p1.y > p2.y then
            startAngle = 0.0
            if isOver then
                startAngle = startAngle + 180.0
            end

            if xIsLonger then
                --
                --             .
                -- .
                --
                if isOver then
                    circleCenter.x = p1.x + radius
                    circleCenter.y = p2.y + radius

                    drawEndOfArc(path, p1.x + radius, p2.y, p2.x, p2.y)
                else
                    circleCenter.x = p2.x - radius
                    circleCenter.y = p1.y - radius

                    drawEndOfArc(path, p1.x, p1.y, p2.x - radius, p1.y)
                end
            else
                --
                --   .
                --
                --
                --
                -- .
                --
                if isOver then
                    circleCenter.x = p1.x + radius
                    circleCenter.y = p2.y + radius

                    drawEndOfArc(path, p1.x, p1.y, p1.x, p2.y + radius)
                else
                    circleCenter.x = p2.x - radius
                    circleCenter.y = p1.y - radius

                    drawEndOfArc(path, p2.x, p1.y - radius, p2.x, p2.y)
                end
            end
        else
            startAngle = 90.0
            if isOver then
                startAngle = startAngle + 180.0
            end

            if xIsLonger then
                --
                -- .
                --             .
                --
                if isOver then
                    circleCenter.x = p2.x - radius
                    circleCenter.y = p1.y + radius

                    drawEndOfArc(path, p1.x, p1.y, p2.x - radius, p1.y)
                else
                    circleCenter.x = p1.x + radius
                    circleCenter.y = p2.y - radius

                    drawEndOfArc(path, p1.x + radius, p2.y, p2.x, p2.y)
                end
            else
                --
                -- .
                --
                --
                --
                --   .
                --
                if isOver then
                    circleCenter.x = p2.x - radius
                    circleCenter.y = p1.y + radius

                    drawEndOfArc(path, p2.x, p1.y + radius, p2.x, p2.y)
                else
                    circleCenter.x = p1.x + radius
                    circleCenter.y = p2.y - radius

                    drawEndOfArc(path, p1.x, p1.y, p1.x, p2.y - radius)
                end
            end
        end

        --print('center:' .. circleCenter.x .. ', ' .. circleCenter.y .. ' radius:' .. radius .. ' startangle:' .. startAngle)
        subpath:arc(circleCenter.x, circleCenter.y, radius, startAngle, startAngle + 90.0)
        --subpath:arc(0.0, 0.0, 4.0, 0.0, 90.0)
    end
end

function DrawTool:getSingleComponent()
    local singleComponent
    for actorId, component in pairs(self.components) do
        if self.game.clientId == component.clientId then
            if singleComponent then
                return nil
            end
            singleComponent = component
        end
    end
    return singleComponent
end


-- Update

function DrawTool.handlers:onSetActive()
    _paths = {}
    _initialCoord = nil
    _tempGraphics = nil

    resetGraphics()
end

function DrawTool.handlers:preUpdate(dt)
    if not self:isActive() then
        return
    end

    -- Steal all touches
    local touchData = self:getTouchData()
    for touchId, touch in pairs(touchData.touches) do
        touch.used = true
    end

    local touchData = self:getTouchData()
    if touchData.numTouches == 1 and touchData.maxNumTouches == 1 then
        -- Get the single touch
        local touchId, touch = next(touchData.touches)
        local roundedX, roundedY = roundGlobalCoordinatesToGrid(touch.x, touch.y)
        local roundedCoord = {x = roundedX, y = roundedY}
        
        if _initialCoord == nil then
            _initialCoord = roundedCoord
        end

        local pathData = {}
        local path = tove.newPath()

        path:setLineColor(0.0, 0.0, 0.0, 1.0)
        path:setLineWidth(0.2)
        path:setMiterLimit(1)
        path:setLineJoin("round")

        pathData.path = path
        pathData.p1 = _initialCoord
        pathData.p2 = roundedCoord
        pathData.style = 1
        drawPath(pathData)

        if touch.released then
            if pathData.p1.x == pathData.p2.x and pathData.p1.y == pathData.p2.y then
                for i = 1, #_paths do
                    if _paths[i].path:nearest(touch.x, touch.y, 0.5) then
                        local path = tove.newPath()
    
                        path:setLineColor(0.0, 0.0, 0.0, 1.0)
                        path:setLineWidth(0.2)
                        path:setMiterLimit(1)
                        path:setLineJoin("round")
    
                        _paths[i].path = path
                        _paths[i].style = _paths[i].style + 1
                        if _paths[i].style > 3 then
                            _paths[i].style = 1
                        end
                        drawPath(_paths[i])
                        resetGraphics()
                    end
                end
            else
                addPath(pathData)
                resetGraphics()
            end

            _initialCoord = nil
            _tempGraphics = nil
        else
            _tempGraphics = tove.newGraphics()
            _tempGraphics:setDisplay("mesh", 1024)
            _tempGraphics:addPath(path)
        end
    end
end

function DrawTool.handlers:update(dt)
    if not self:isActive() then
        return
    end

    -- Make sure we have exactly one actor active
    local c = self:getSingleComponent()
    if not c then
        return
    end
end

-- Draw

function DrawTool.handlers:drawOverlay()
    if not self:isActive() then
        return
    end

    love.graphics.clear(0.95, 0.95, 0.95)

    love.graphics.setColor(0.5, 0.5, 0.5, 1.0)
    love.graphics.setPointSize(10.0)

    local points = {}

    for x = 1, 10 do
        for y = 1, 10 do
            local globalX, globalY = gridToGlobalCoordinates(x, y)
            table.insert(points, globalX)
            table.insert(points, globalY)
        end
    end

    love.graphics.points(points)

    love.graphics.setColor(1, 1, 1, 1)
    _graphics:draw()

    if _tempGraphics ~= nil then
        _tempGraphics:draw()
    end
end

-- UI

function DrawTool.handlers:uiPanel()
    if not self:isActive() then
        return
    end

    local c = self:getSingleComponent()
    if not c then
        return
    end
end
