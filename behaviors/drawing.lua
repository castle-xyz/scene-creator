local DrawingBehavior = {
    name = 'Drawing',
    propertyNames = {
        'url',
        'wobble',
    },
    dependencies = {
        'Body',
    },
    handlers = {},
}

registerCoreBehavior(DrawingBehavior)


local ffi = require 'ffi'
local C = ffi.C


-- Default

local DEFAULT_URL = 'assets/rectangle.svg'
local DEFAULT_GRAPHICS
if not castle.system.isRemoteServer() then
    DEFAULT_GRAPHICS = tove.newGraphics(love.filesystem.newFileData(DEFAULT_URL):getString(), 1024)
end


-- Wobble

local AMOUNT = 3
local NOISE_SCALE = 0.08
local FRAMES = 3
local TWEEN = 1
local SPEED = 10
local POINTS = false

local function wobblePoint(x, y, seed)
    seed = seed * 100
    local dx1 = AMOUNT * (2 * love.math.noise(NOISE_SCALE * x, NOISE_SCALE * y, 1, seed) - 1)
    local dy1 = AMOUNT * (2 * love.math.noise(NOISE_SCALE * x, NOISE_SCALE * y, 10, seed) - 1)
    local dx2 = AMOUNT * AMOUNT * (2 * love.math.noise(NOISE_SCALE * NOISE_SCALE * x, NOISE_SCALE * NOISE_SCALE * y, 100, seed) - 1)
    local dy2 = AMOUNT * AMOUNT * (2 * love.math.noise(NOISE_SCALE * NOISE_SCALE * x, NOISE_SCALE * NOISE_SCALE * y, 1000, seed) - 1)
    return x + dx1 + dx2, y + dy1 + dy2
end

local function copyCurve(dest, src)
    dest.x0, dest.y0 = src.x0, src.y0
    dest.cp1x, dest.cp1y = src.cp1x, src.cp1y
    dest.cp2x, dest.cp2y = src.cp2x, src.cp2y
    dest.x, dest.y = src.x, src.y
end

local function wobbleCurve(dest, src, seed)
    dest.x0, dest.y0 = wobblePoint(src.x0, src.y0, seed)
    dest.cp1x, dest.cp1y = wobblePoint(src.cp1x, src.cp1y, seed)
    dest.cp2x, dest.cp2y = wobblePoint(src.cp2x, src.cp2y, seed)
    dest.x, dest.y = wobblePoint(src.x, src.y, seed)
end

local function wobbleDrawing(drawing)
    local frames = {}
    local display = drawing:getDisplay()
    for f = 1, FRAMES do
        local clone = drawing:clone()
        for i = 1, clone.paths.count do
            local path = clone.paths[i]
            local origPath = drawing.paths[i]
            for j = 1, path.subpaths.count do
                local subpath = path.subpaths[j]
                local origSubpath = origPath.subpaths[j]
                subpath:warp(function(x, y, c)
                    local newX, newY = wobblePoint(x, y, f * FRAMES + j)
                    return newX, newY, c
                end)
                if not subpath.isClosed then -- Need to fix ends if not closed
                    local numCurves = subpath.curves.count
                    if display ~= 'texture' then
                        copyCurve(subpath.curves[1], origSubpath.curves[1])
                        copyCurve(subpath.curves[numCurves - 1], origSubpath.curves[numCurves - 1])
                    end
                    copyCurve(subpath.curves[numCurves], origSubpath.curves[numCurves])
                end
            end
        end
        table.insert(frames, clone)
    end
    local tween = tove.newTween(frames[1])
    for i = 2, #frames do
        tween = tween:to(frames[i], 1)
    end
    tween = tween:to(frames[1], 1)
    return tove.newFlipbook(TWEEN, tween)
end


-- Loading

local cache = setmetatable({}, { __mode = 'v' })

function DrawingBehavior:cacheDrawing(url, opts)
    opts = opts or {}
    local async = opts.async
    local wobble = opts.wobble

    local cacheEntry = cache[url]
    if not cacheEntry then
        cacheEntry = {}
        cache[url] = cacheEntry
    end
    local graphics = cacheEntry.graphics
    if not graphics then
        if not cacheEntry.graphicsRequested then
            cacheEntry.graphicsRequested = true
            if url:match('^ser:') then -- Serialized
                cacheEntry.graphics, cacheEntry.graphicsWidth, cacheEntry.graphicsHeight = self:deserialize(url:sub(5))
                --cacheEntry.graphics:setDisplay('texture', 1024)
            else -- Network loaded
                network.async(function()
                    local fileContents = love.filesystem.newFileData(url):getString()
                    cacheEntry.graphics = tove.newGraphics(fileContents, 1024)
                    cacheEntry.graphics:setDisplay('mesh', 'rigid', 4)
                    cacheEntry.graphicsWidth, cacheEntry.graphicsHeight = nil, nil
                    if wobble then
                        cacheEntry.flipbook = wobbleDrawing(cacheEntry.graphics)
                    end
                end)
            end
        end
    end
    return cacheEntry
end

function DrawingBehavior:serialize(graphics, width, height)
    local payload = {}

    -- Width, height
    payload.width, payload.height = width, height

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
            --writePath.lineJoin = readPath:getLineJoin()
            writePath.miterLimit = readPath:getMiterLimit()
        end

        -- Fill
        local fillColor = readPath:getFillColor()
        if fillColor then
            writePath.fillColor = fillColor:serialize()
            --writePath.fillRule = readPath:getFillRule()
        end

        -- Opacity
        --writePath.opacity = readPath:getOpacity()
    end

    local encoded = bitser.dumps(payload)
    --print('encoded', #encoded)
    local compressed = love.data.compress('string', 'zlib', encoded)
    --print('compressed', #compressed)
    local base64 = love.data.encode('string', 'base64', compressed)
    --print('base64', #base64)
    return base64
end

function DrawingBehavior:deserialize(base64)
    local compressed = love.data.decode('string', 'base64', base64)
    local encoded = love.data.decompress('string', 'zlib', compressed)
    local payload = bitser.loads(encoded)

    -- Width, height
    local width, height = payload.width, payload.height

    local graphics = tove.newGraphics()
    graphics:setDisplay('mesh', 1024)

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
                    ffi.new('float[?]', #readSubpath.points, readSubpath.points),
                    #readSubpath.points / 2)
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

    return graphics, width, height
end


-- Component management

function DrawingBehavior.handlers:addComponent(component, bp, opts)
    -- NOTE: All of this must be pure w.r.t the arguments since we're directly setting and not sending
    component.properties.url = bp.url or DEFAULT_URL
    if bp.wobble ~= nil then
        component.properties.wobble = bp.wobble
    else
        component.properties.wobble = false
    end
    self:cacheDrawing(component.properties.url, {
        wobble = component.properties.wobble,
    })
end

function DrawingBehavior.handlers:blueprintComponent(component, bp)
    bp.url = component.properties.url
    bp.wobble = component.properties.wobble
end


-- Draw

function DrawingBehavior.handlers:drawComponent(component)
    -- Body attributes
    local bodyWidth, bodyHeight = self.dependencies.Body:getSize(component.actorId)
    local bodyId, body = self.dependencies.Body:getBody(component.actorId)
    local bodyX, bodyY = body:getPosition()
    local bodyAngle = body:getAngle()

    local graphics, flipbook, graphicsWidth, graphicsHeight

    -- Check if the draw tool is acting on us
    local drawComponent = self.dependents.Draw:get(component.actorId)
    if drawComponent and drawComponent._graphics then
        graphics = drawComponent._graphics
        graphicsWidth, graphicsHeight = drawComponent._graphicsWidth, drawComponent._graphicsHeight
    else -- Use `url`
        -- Load graphics
        local cacheEntry = self:cacheDrawing(component.properties.url, {
            wobble = component.properties.wobble,
        })
        component._cacheEntry = cacheEntry -- Maintain strong reference
        graphics = cacheEntry.graphics or component._lastGraphics or DEFAULT_GRAPHICS
        component._lastGraphics = graphics

        -- Graphics size
        graphicsWidth, graphicsHeight = cacheEntry.graphicsWidth, cacheEntry.graphicsHeight
        if not (graphicsWidth and graphicsHeight) then
            local minX, minY, maxX, maxY = graphics:computeAABB('high')
            graphicsWidth, graphicsHeight = maxX - minX, maxY - minY
            cacheEntry.graphicsWidth, cacheEntry.graphicsHeight = graphicsWidth, graphicsHeight
        end

        -- Wobble
        if component.properties.wobble and cacheEntry.graphics then
            flipbook = cacheEntry.flipbook
            if not flipbook then
                flipbook = wobbleDrawing(graphics)
                cacheEntry.flipbook = flipbook
            end
        end
    end

    -- Push transform
    love.graphics.push()
    love.graphics.translate(bodyX, bodyY)
    love.graphics.rotate(bodyAngle)
    love.graphics.scale(bodyWidth / graphicsWidth, bodyHeight / graphicsHeight)

    -- Draw!
    if flipbook then
        if not component._wobblePhase then
            component._wobblePhase = math.random(0, flipbook._duration - 1)
            component._wobbleSign = math.random(2) == 1 and -1 or 1
        end
        flipbook.t = (component._wobbleSign * SPEED * love.timer.getTime() + component._wobblePhase) % flipbook._duration
        flipbook:draw()
    else
        graphics:draw()
    end

    -- Pop transform
    love.graphics.pop()
end


-- UI

function DrawingBehavior.handlers:uiComponent(component, opts)
    local actorId = component.actorId

    ui.box('preview and picker', { flexDirection = 'row', alignItems = 'flex-start' }, function()
        if not component.properties.url:match('^ser:') then
            ui.box('preview', {
                width = '28%',
                aspectRatio = 1,
                margin = 4,
                marginLeft = 8,
                backgroundColor = 'white',
            }, function()
                ui.image(CHECKERBOARD_IMAGE_URL, { flex = 1, margin = 0 })

                if component.properties.url then
                    ui.image(component.properties.url, {
                        position = 'absolute',
                        left = 0, top = 0, bottom = 0, right = 0,
                        margin = 0,
                    })
                end
            end)

            ui.box('spacer', { width = 8 }, function() end)
        end

        ui.box('library picker', {
            flex = 1,
            alignSelf = 'stretch',
            flexDirection = 'row',
            alignItems = 'flex-start',
            justifyContent = 'flex-start',
        }, function()
            ui.button('choose from library', {
                icon = 'book',
                iconFamily = 'FontAwesome',
                popoverAllowed = true,
                popoverStyle = { width = 300, height = 300 },
                popover = function(closePopover)
                    self.game:uiLibrary({
                        id = 'drawing',
                        filterType = 'drawing',
                        emptyText = 'No assets!',
                        buttons = function(entry)
                            ui.button('use', {
                                flex = 1,
                                icon = 'plus',
                                iconFamily = 'FontAwesome5',
                                onClick = function()
                                    closePopover()

                                    local oldUrl = component.properties.url
                                    local newUrl = entry.drawing.url
                                    self:command('change drawing', {
                                        params = { 'oldUrl', 'newUrl' },
                                    }, function()
                                        self:sendSetProperties(actorId, 'url', newUrl)
                                    end, function()
                                        self:sendSetProperties(actorId, 'url', oldUrl)
                                    end)
                                end,
                            })
                        end,
                    })
                end,
            })
        end)
    end)

    self:uiProperty('toggle', 'wobble', actorId, 'wobble')
end


