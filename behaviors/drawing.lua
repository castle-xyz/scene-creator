local DrawingBehavior = {
    name = 'Drawing',
    propertyNames = {
        'url',
    },
    dependencies = {
        'Body',
    },
    handlers = {},
}

registerCoreBehavior(DrawingBehavior)


-- Default drawing

local DEFAULT_URL = 'assets/rectangle.svg'
local DEFAULT_GRAPHICS
if not castle.system.isRemoteServer() then
    DEFAULT_GRAPHICS = tove.newGraphics(love.filesystem.newFileData(DEFAULT_URL):getString(), 1024)
end


-- Wobble

local NORMAL_WOBBLE_AMOUNT = 8.07
local WOBBLE_NOISE_SCALE = 1
local WOBBLE_FRAMES = 8
local WOBBLE_TWEEN = 1
local WOBBLE_SPEED = 8
local WOBBLE_POINTS = false

local function wobblePoint(x, y, amount, seed, scale)
    local dx = amount * (2 * love.math.noise(scale * x, scale * y, 1, seed) - 1)
    local dy = amount * (2 * love.math.noise(scale * x, scale * y, 2, seed) - 1)
    return x + dx, y + dy
end

local function wobbleDrawing(drawing, amount)
    amount = amount or 3
    local frames = {}
    for f = 1, WOBBLE_FRAMES do
        local clone = drawing:clone()
        for i = 1, clone.paths.count do
            local path = clone.paths[i]
            for j = 1, path.subpaths.count do
                local subpath = path.subpaths[j]
                local numCurves = subpath.curves.count
                for k = 1, numCurves do
                    local seed = WOBBLE_FRAMES * f + j
                    local curve = subpath.curves[k]
                    curve.cp1x, curve.cp1y = wobblePoint(curve.cp1x, curve.cp1y, amount, seed, WOBBLE_NOISE_SCALE)
                    curve.cp2x, curve.cp2y = wobblePoint(curve.cp2x, curve.cp2y, amount, seed, WOBBLE_NOISE_SCALE)
                    if WOBBLE_POINTS then
                        curve.x0, curve.y0 = wobblePoint(curve.x0, curve.y0, amount, seed, WOBBLE_NOISE_SCALE)
                        curve.x, curve.y = wobblePoint(curve.x, curve.y, amount, seed, WOBBLE_NOISE_SCALE)
                    end
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
    return tove.newFlipbook(WOBBLE_TWEEN, tween, 'mesh', 1024)
end


-- Component management

function DrawingBehavior.handlers:addComponent(component, bp, opts)
    -- NOTE: All of this must be pure w.r.t the arguments since we're directly setting and not sending
    component.properties.url = bp.url or DEFAULT_URL
end

function DrawingBehavior.handlers:blueprintComponent(component, bp)
    bp.url = component.properties.url
end


-- Draw

local cache = setmetatable({}, { __mode = 'v' })

local sizeCache = setmetatable({}, { __mode = 'k' })

function DrawingBehavior.handlers:drawComponent(component)
    -- Body attributes
    local bodyWidth, bodyHeight = self.dependencies.Body:getSize(component.actorId)
    local bodyId, body = self.dependencies.Body:getBody(component.actorId)
    local bodyX, bodyY = body:getPosition()
    local bodyAngle = body:getAngle()

    -- Load graphics
    local cacheKey = component.properties.url
    local cacheEntry = cache[cacheKey]
    if not cacheEntry then
        cacheEntry = {}
        cache[cacheKey] = cacheEntry
        print('loading svg: ' .. cacheKey)
    end
    component._cacheEntry = cacheEntry -- Maintain strong reference
    local graphics, flipbook = cacheEntry.graphics, cacheEntry.flipbook
    if not graphics then
        if not cacheEntry.graphicsRequested then
            cacheEntry.graphicsRequested = true
            network.async(function()
                local fileContents = love.filesystem.newFileData(component.properties.url):getString()
                cacheEntry.graphics = tove.newGraphics(fileContents)
                cacheEntry.graphics:setDisplay('mesh', 1024)
                cacheEntry.graphicsWidth, cacheEntry.graphicsHeight = nil, nil
                if true then
                    cacheEntry.flipbook = wobbleDrawing(cacheEntry.graphics, NORMAL_WOBBLE_AMOUNT)
                end
            end)
        end
        graphics = component._lastGraphics or DEFAULT_GRAPHICS
    end
    component._lastGraphics = graphics

    -- Graphics size
    local graphicsWidth, graphicsHeight = cacheEntry.graphicsWidth, cacheEntry.graphicsHeight
    if not (graphicsWidth and graphicsHeight) then
        local minX, minY, maxX, maxY = graphics:computeAABB('high')
        graphicsWidth, graphicsHeight = maxX - minX, maxY - minY
        cacheEntry.graphicsWidth, cacheEntry.graphicsHeight = graphicsWidth, graphicsHeight
    end

    -- Push transform
    love.graphics.push()
    love.graphics.translate(bodyX, bodyY)
    love.graphics.rotate(bodyAngle)
    love.graphics.scale(bodyWidth / graphicsWidth, bodyHeight / graphicsHeight)

    -- Draw!
    if flipbook then
        flipbook.t = (WOBBLE_SPEED * love.timer.getTime()) % flipbook._duration
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
end


