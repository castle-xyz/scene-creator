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

local DEBUG_FLOOD_FILL = true

-- Behavior management

local _paths
local _initialCoord
local _graphics

local _tempGraphics
local _subtool
local _grabbedPaths

local _lineColor
local _fillColor

function DrawTool.handlers:addBehavior(opts)
    
end

-- Methods

local GRID_HORIZONTAL_PADDING = 0.05 * DEFAULT_VIEW_WIDTH
local GRID_TOP_PADDING = 0.2 * DEFAULT_VIEW_WIDTH
local GRID_SIZE = 15
local GRID_WIDTH = DEFAULT_VIEW_WIDTH - GRID_HORIZONTAL_PADDING * 2.0
local BACKGROUND_COLOR = {r = 0.95, g = 0.95, b = 0.95}

local pathsCanvas
local fillCanvas

-- http://will.thimbleby.net/scanline-flood-fill/
function floodFillScanline(x, y, width, height, diagonal, test, paint)
    -- xMin, xMax, y, down[true] / up[false], extendLeft, extendRight
    local ranges = {}
    table.insert(ranges, {
        xMin = x,
        xMax = x,
        y = y,
        direction = nil,
        extendLeft = true,
        extendRight = true,
    })

    paint(x, y)

    while #ranges > 0 do
        local r = table.remove(ranges)
        -- print(inspect(r))
        local down = r.direction == 'down'
        local up =   r.direction == 'up'

        -- extendLeft
        local minX = r.xMin
        local y = r.y
        if r.extendLeft then
            while minX > 0 and test(minX-1, y) do
                minX = minX - 1
                paint(minX, y)
            end
        end

        local maxX = r.xMax
        -- extendRight
        if r.extendRight then
            while maxX < width - 1 and test(maxX+1, y) do
                maxX = maxX + 1
                paint(maxX, y)
            end
        end

        if diagonal then
            -- extend range looked at for next lines
            if minX>0 then minX = minX - 1 end
            if maxX<width-1 then maxX = maxX + 1 end
        else
            -- extend range ignored from previous line
            r.xMin = r.xMin - 1
            r.xMax = r.xMax + 1
        end

        local function addNextLine(newY, isNext, direction)
            local rMinX = minX
            local inRange = false
            for x=minX, maxX do
                -- skip testing, if testing previous line within previous range
                local empty = (isNext or (x<r.xMin or x>r.xMax)) and test(x, newY)
                if (not inRange) and empty then
                    rMinX = x
                    inRange = true
                elseif inRange and (not empty) then
                    table.insert(ranges, {
                        xMin = rMinX,
                        xMax = x - 1,
                        y = newY,
                        direction = direction,
                        extendLeft = rMinX==minX,
                        extendRight = false,
                    })

                    inRange = false
                end

                if inRange then
                    paint(x, newY)
                end
                -- skip
                if (not isNext) and x==r.xMin then
                    x = r.xMax
                end
            end
            if inRange then
                table.insert(ranges, {
                    xMin = rMinX,
                    xMax = x - 1,
                    y = newY,
                    direction = direction,
                    extendLeft = rMinX==minX,
                    extendRight = true,
                })
            end
        end

        if(y<height-1) then
            addNextLine(y+1, not up, 'down')
        end
        if(y>0) then
            addNextLine(y-1, not down, 'up')
        end
    end
end

function floodFill8Way(startX, startY, width, height, test, paint)
    local queue = {}

    if startX < 0 or startX < 0 or startX >= width or startX >= height then
        return
    end

    table.insert(queue, {
        x = startX,
        y = startY,
    })

    while #queue > 0 do
        local item = table.remove(queue)
        local x = item.x
        local y = item.y

        if test(x, y) then
            paint(x, y)

            for dx = -1, 1 do
                for dy = -1, 1 do
                    local skip = false
                    if dx == 0 and dy == 0 then
                        skip = true
                    end

                    local newX = x + dx
                    local newY = y + dy

                    if newX < 0 or newY < 0 or newX >= width or newY >= height then
                        skip = true
                    end

                    if not skip then
                        if test(newX, newY) then
                            table.insert(queue, {
                                x = newX,
                                y = newY,
                            })
                        end
                    end
                end
            end
        end
    end
end

function floodFill(x, y, color)
    local windowWidth, windowHeight = love.graphics.getDimensions()

    pathsCanvas:renderTo(
        function()
            love.graphics.push("all")

            love.graphics.origin()
            love.graphics.scale(windowWidth / DEFAULT_VIEW_WIDTH)

            love.graphics.clear(0, 0, 0, 0)
            love.graphics.setColor(1, 1, 1, 1)
            _graphics:draw()

            love.graphics.pop()
        end
    )

    local pathsImageData = pathsCanvas:newImageData()
    local fillImageData = fillCanvas:newImageData()

    local scale = windowWidth / DEFAULT_VIEW_WIDTH

    local ir, ig, ib, ia = fillImageData:getPixel(math.floor(x * scale), math.floor(y * scale))
    --print(ir .. ' ' .. ig .. ' ' .. ib)

    fillCanvas:renderTo(
        function()
            love.graphics.push("all")

            love.graphics.origin()
            --love.graphics.scale(windowWidth / DEFAULT_VIEW_WIDTH)

            love.graphics.setColor(color.r, color.g, color.b, 1)
            
            love.graphics.setPointSize(1.0)

            local points = {}
            local lookup = {}

            local function test(x, y)
                if lookup[x] and lookup[x][y] then
                    return false
                end

                if x < scale * GRID_HORIZONTAL_PADDING or x > scale * (GRID_HORIZONTAL_PADDING + GRID_WIDTH) then
                    return false
                end

                if y < scale * GRID_TOP_PADDING or y > scale * (GRID_TOP_PADDING + GRID_WIDTH) then
                    return false
                end

                if x < 0 or y < 0 or x >= pathsImageData:getWidth() or y >= pathsImageData:getHeight() then
                    return false
                end

                local r, g, b, a = pathsImageData:getPixel(x, y)
                if a > 0.0 then
                    return false
                end

                --r, g, b, a = fillImageData:getPixel(x, y)
                --local colorThreshold = 0.01
                --if math.abs(r - ir) > colorThreshold or math.abs(g - ig) > colorThreshold or math.abs(b - ib) > colorThreshold then
                --    return false
                --end

                return true
            end

            local function paint(x, y)
                table.insert(points, x)
                table.insert(points, y)

                if lookup[x] == nil then
                    lookup[x] = {}
                end
                lookup[x][y] = true
            end

            floodFill8Way(math.floor(x * scale), math.floor(y * scale), windowWidth, windowHeight, test, paint)

            love.graphics.points(points)

            love.graphics.pop()
        end
    )
end

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
    local p1 = pathData.points[1]
    local p2 = pathData.points[2]
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
    _grabbedPaths = nil
    _initialCoord = nil
    _tempGraphics = nil
    _subtool = 'draw'

    _lineColor = {hexStringToRgb(DEFAULT_PALETTE[6])}
    _fillColor = {hexStringToRgb(DEFAULT_PALETTE[7])}

    resetGraphics()

    local windowWidth, windowHeight = love.graphics.getDimensions()
    pathsCanvas =
    love.graphics.newCanvas(
        windowWidth,
        windowHeight,
        {
            dpiscale = 1,
            msaa = 4
        }
    )
    fillCanvas =
    love.graphics.newCanvas(
        windowWidth,
        windowHeight,
        {
            dpiscale = 1,
            msaa = 4
        }
    )


    fillCanvas:renderTo(
        function()
            love.graphics.push("all")
            love.graphics.origin()
            love.graphics.clear(BACKGROUND_COLOR.r, BACKGROUND_COLOR.g, BACKGROUND_COLOR.b, 1)
            love.graphics.pop()
        end
    )
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

        if _subtool == 'draw' then
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
            pathData.points = {_initialCoord, roundedCoord}
            pathData.style = 1
            drawPath(pathData)

            if touch.released then
                if pathData.points[1].x ~= pathData.points[2].x or pathData.points[1].y ~= pathData.points[2].y then 
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
        elseif _subtool == 'move' then
            if _grabbedPaths == nil then
                _grabbedPaths = {}

                for i = 1, #_paths do
                    for p = 1, 2 do
                        if roundedX == _paths[i].points[p].x and roundedY == _paths[i].points[p].y then
                            _paths[i].grabPointIndex = p
                            table.insert(_grabbedPaths, _paths[i])
                            break
                        end
                    end
                end

                for i = 1, #_grabbedPaths do
                    removePath(_grabbedPaths[i])
                end

                if #_grabbedPaths then
                    resetGraphics()
                end
            end

            for i = 1, #_grabbedPaths do
                _grabbedPaths[i].points[_grabbedPaths[i].grabPointIndex].x = roundedX
                _grabbedPaths[i].points[_grabbedPaths[i].grabPointIndex].y = roundedY

                local path = tove.newPath()

                path:setLineColor(0.0, 0.0, 0.0, 1.0)
                path:setLineWidth(0.2)
                path:setMiterLimit(1)
                path:setLineJoin("round")
                _grabbedPaths[i].path = path
                drawPath(_grabbedPaths[i])
            end

            if touch.released then
                if _grabbedPaths and #_grabbedPaths > 0 then
                    for i = 1, #_grabbedPaths do
                        addPath(_grabbedPaths[i])
                    end

                    resetGraphics()
                else
                    local foundPath = false
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

                            foundPath = true
                            break
                        end
                    end
                end

                _grabbedPaths = nil
                _tempGraphics = nil
            else
                _tempGraphics = tove.newGraphics()
                _tempGraphics:setDisplay("mesh", 1024)

                for i = 1, #_grabbedPaths do
                    _tempGraphics:addPath(_grabbedPaths[i].path)
                end
            end
        elseif _subtool == 'fill' then
            floodFill(touch.x, touch.y, {r = _fillColor[1], g = _fillColor[2], b = _fillColor[3]})
        elseif _subtool == 'erase line' then
            if touch.released then
                for i = 1, #_paths do
                    if _paths[i].path:nearest(touch.x, touch.y, 0.5) then
                        removePath(_paths[i])
                        resetGraphics()
                        break
                    end
                end
            end
        elseif _subtool == 'erase fill' then
            floodFill(touch.x, touch.y, BACKGROUND_COLOR)
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

    love.graphics.clear(BACKGROUND_COLOR.r, BACKGROUND_COLOR.g, BACKGROUND_COLOR.b)

    love.graphics.setColor(1, 1, 1, 1)
    if fillCanvas ~= nil then
        local windowWidth, windowHeight = love.graphics.getDimensions()
        love.graphics.draw(fillCanvas, 0, 0, 0, DEFAULT_VIEW_WIDTH / windowWidth, DEFAULT_VIEW_WIDTH / windowWidth)
    end

    if _subtool == 'draw' or _subtool == 'move' then
        love.graphics.setColor(0.5, 0.5, 0.5, 1.0)
        love.graphics.setPointSize(10.0)

        local points = {}

        for x = 1, GRID_SIZE do
            for y = 1, GRID_SIZE do
                local globalX, globalY = gridToGlobalCoordinates(x, y)
                table.insert(points, globalX)
                table.insert(points, globalY)
            end
        end

        love.graphics.points(points)
    end

    love.graphics.setColor(1, 1, 1, 1)

    _graphics:draw()

    if _tempGraphics ~= nil then
        _tempGraphics:draw()
    end

    if _subtool == "move" then
        local movePoints = {}

        for i = 1, #_paths do
            for p = 1, 2 do
                table.insert(movePoints, _paths[i].points[p].x)
                table.insert(movePoints, _paths[i].points[p].y)
            end
        end

        love.graphics.setColor(1.0, 0.6, 0.6, 1.0)
        love.graphics.setPointSize(30.0)
        love.graphics.points(movePoints)
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

    ui.box(
        "fill row",
        {flexDirection = "row"},
        function()

            ui.toggle(
                "draw",
                "draw",
                _subtool == 'draw',
                {
                    onToggle = function(newlineEnabled)
                        _subtool = 'draw'
                    end
                }
            )

            ui.toggle(
                "move",
                "move",
                _subtool == 'move',
                {
                    onToggle = function(newlineEnabled)
                        _subtool = 'move'
                    end
                }
            )

            ui.toggle(
                "fill",
                "fill",
                _subtool == 'fill',
                {
                    onToggle = function(newlineEnabled)
                        _subtool = 'fill'
                    end
                }
            )

            ui.toggle(
                "erase line",
                "erase line",
                _subtool == 'erase line',
                {
                    onToggle = function(newlineEnabled)
                        _subtool = 'erase line'
                    end
                }
            )

            ui.toggle(
                "erase fill",
                "erase fill",
                _subtool == 'erase fill',
                {
                    onToggle = function(newlineEnabled)
                        _subtool = 'erase fill'
                    end
                }
            )
        end
    )

    ui.box(
        "fill color box",
        {
            flex = 1,
            alignItems = "flex-start",
            justifyContent = "flex-end"
        },
        function()
            _fillColor[1], _fillColor[2], _fillColor[3] =
                uiPalette(_fillColor[1], _fillColor[2], _fillColor[3])
        end
    )

    ui.box(
        "grid size box",
        {
            flex = 1,
            justifyContent = "flex-end"
        },
        function()
            GRID_SIZE =
                ui.numberInput(
                "grid size",
                GRID_SIZE,
                {
                    hideLabel = false,
                    min = 3,
                    max = 25,
                    step = 1
                }
            )
        end
    )
end
