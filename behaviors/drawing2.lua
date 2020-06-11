require('tools.draw_data')

local Drawing2Behavior =
    defineCoreBehavior {
    name = "Drawing2",
    propertyNames = {
        "data"
    },
    dependencies = {
        "Body"
    }
}

local ffi = require "ffi"
local C = ffi.C

-- TODO
local DEFAULT_DATA = ''

-- Loading

local cache = setmetatable({}, {__mode = "v"})

function Drawing2Behavior:cacheDrawing(data, opts)
    opts = opts or {}

    local cacheEntry = cache[data]
    if not cacheEntry then
        cacheEntry = {}
        cache[data] = cacheEntry
    end
    local graphics = cacheEntry.graphics
    if not graphics then
        if not cacheEntry.graphicsRequested then
            cacheEntry.graphicsRequested = true
            
            cacheEntry.size, cacheEntry.graphics, cacheEntry.data = self:deserialize(data)
        end
    end
    return cacheEntry
end

function Drawing2Behavior:serialize(size, graphics, data)
    local payload = {}

    -- Width, height
    payload.size = size
    payload.data = data

    -- Paths
    payload.paths = {}
    local readPaths = graphics.paths
    for pathI = 1, readPaths.count do
        local readPath = readPaths[pathI]
        local writePath = {}
        payload.paths[pathI] = writePath

        -- Subpaths
        writePath.subpaths = {}
        local readSubpaths = readPath.subpaths
        for subpathI = 1, readSubpaths.count do
            local readSubpath = readSubpaths[subpathI]
            local writeSubpath = {}
            writePath.subpaths[subpathI] = writeSubpath

            -- Points
            writeSubpath.points = {}
            local readPoints = readSubpath.points
            for pointI = 1, readPoints.count do
                local readPoint = readPoints[pointI]
                writeSubpath.points[2 * (pointI - 1) + 1] = readPoint.x
                writeSubpath.points[2 * (pointI - 1) + 2] = readPoint.y
            end

            -- Closed?
            writeSubpath.isClosed = readSubpath.isClosed
        end

        -- Line
        local lineColor = readPath:getLineColor()
        if lineColor then
            writePath.lineColor = lineColor:serialize()
            writePath.lineWidth = readPath:getLineWidth()
            writePath.lineJoin = readPath:getLineJoin()
            writePath.miterLimit = readPath:getMiterLimit()
        end

        -- Fill
        local fillColor = readPath:getFillColor()
        if fillColor then
            writePath.fillColor = fillColor:serialize()
            writePath.fillRule = readPath:getFillRule()
        end

        -- Opacity
        writePath.opacity = readPath:getOpacity()
    end

    local encoded = bitser.dumps(payload)
    --print('encoded', #encoded)
    local compressed = love.data.compress("string", "zlib", encoded)
    --print('compressed', #compressed)
    local base64 = love.data.encode("string", "base64", compressed)
    --print('base64', #base64)
    return base64
end

function Drawing2Behavior:deserialize(base64)
    print('Drawing2Behavior:deserialize')

    local graphics = tove.newGraphics()
    graphics:setDisplay("mesh", 1024)

    if base64 == nil or string.len(base64) == 0 then
        return 0, graphics, {}
    end

    local compressed = love.data.decode("string", "base64", base64)
    local encoded = love.data.decompress("string", "zlib", compressed)
    local payload = bitser.loads(encoded)

    print(inspect(payload))

    -- Width, height
    local size = payload.size or 0
    local data = payload.data or {}

    -- Paths
    for _, readPath in ipairs(payload.paths or {}) do
        local writePath = tove.newPath()
        graphics:addPath(writePath)

        -- Subpaths
        for _, readSubpath in ipairs(readPath.subpaths or {}) do
            local writeSubpath = tove.newSubpath()
            writePath:addSubpath(writeSubpath)

            -- Points
            if readSubpath.points then
                C.SubpathSetPoints(
                    writeSubpath,
                    ffi.new("float[?]", #readSubpath.points, readSubpath.points),
                    #readSubpath.points / 2
                )
            end

            -- Closed?
            if readSubpath.isClosed then
                writeSubpath.isClosed = true
            end
        end

        -- Line
        if readPath.lineColor then
            writePath:setLineColor(tove.newPaint(readPath.lineColor))
            if readPath.lineWidth then
                writePath:setLineWidth(readPath.lineWidth)
            end
            if readPath.lineJoin then
                writePath:setLineJoin(readPath.lineJoin)
            end
            if readPath.miterLimit then
                writePath:setMiterLimit(readPath.miterLimit)
            end
        end

        -- Fill
        if readPath.fillColor then
            writePath:setFillColor(tove.newPaint(readPath.fillColor))
            if readPath.fillRule then
                writePath:setFillRule(readPath.fillRule)
            end
        end

        -- Opacity
        if readPath.opacity then
            writePath:setOpacity(readPath.opacity)
        end
    end

    return size, graphics, data
end

-- Component management

function Drawing2Behavior.handlers:addComponent(component, bp, opts)
    -- NOTE: All of this must be pure w.r.t the arguments since we're directly setting and not sending
    component.properties.data = bp.data or DEFAULT_DATA

    self:cacheDrawing(
        component.properties.data,
        {}
    )
end

function Drawing2Behavior.handlers:blueprintComponent(component, bp)
    bp.data = component.properties.data
end


-- Draw

function Drawing2Behavior.handlers:drawComponent(component)
    -- Body attributes
    local bodyWidth, bodyHeight = self.dependencies.Body:getSize(component.actorId)
    local bodyId, body = self.dependencies.Body:getBody(component.actorId)
    local bodyX, bodyY = body:getPosition()
    local bodyAngle = body:getAngle()

    local graphics, graphicsWidth, graphicsHeight

    -- Check if the draw tool is acting on us
    local drawComponent = self.dependents.Draw:get(component.actorId)
    --if NEW_DRAW_TOOL and drawComponent and drawComponent._graphics then
    --    graphics = drawComponent._graphics
    --    graphicsWidth, graphicsHeight = drawComponent._graphicsWidth, drawComponent._graphicsHeight
    --else -- Use `data`
        -- Load graphics
        local cacheEntry =
            self:cacheDrawing(
            component.properties.data,
            {}
        )
        component._cacheEntry = cacheEntry -- Maintain strong reference
        graphics = cacheEntry.graphics or component._lastGraphics
        component._lastGraphics = graphics
        graphicsWidth, graphicsHeight = cacheEntry.size or 1024, cacheEntry.size or 1024
    --end

    -- Push transform
    love.graphics.push()
    love.graphics.translate(bodyX, bodyY)
    love.graphics.rotate(bodyAngle)
    love.graphics.translate(-bodyWidth / 2.0, -bodyHeight / 2.0)
    love.graphics.scale(bodyWidth / graphicsWidth, bodyHeight / graphicsHeight)

    -- Draw!
    love.graphics.setColor(1, 1, 1, 1)
    if graphics then
        graphics:draw()
    end

    -- Pop transform
    love.graphics.pop()
end


-- UI

function Drawing2Behavior.handlers:uiComponent(component, opts)
end
