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
    local drawData = cacheEntry.drawData
    if not drawData then
        if not cacheEntry.drawDataRequested then
            cacheEntry.drawDataRequested = true
            
            cacheEntry.size, cacheEntry.drawData = self:deserialize(data)
        end
    end
    return cacheEntry
end

function Drawing2Behavior:serialize(size, drawData)
    local payload = {}

    -- Width, height
    payload.size = size
    payload.drawData = drawData

    local encoded = bitser.dumps(payload)
    --print('encoded', #encoded)
    local compressed = love.data.compress("string", "zlib", encoded)
    --print('compressed', #compressed)
    local base64 = love.data.encode("string", "base64", compressed)
    --print('base64', #base64)
    return base64
end

function Drawing2Behavior:deserialize(base64)
    if base64 == nil or string.len(base64) == 0 then
        return 0, DrawData:new({})
    end

    local compressed = love.data.decode("string", "base64", base64)
    local encoded = love.data.decompress("string", "zlib", compressed)
    local payload = bitser.loads(encoded)

    print(inspect(payload))

    -- Width, height
    local size = payload.size or 0
    local drawData = payload.drawData or {}

    return size, DrawData:new(drawData)
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

    local cacheEntry =
        self:cacheDrawing(
        component.properties.data,
        {}
    )
    component._cacheEntry = cacheEntry -- Maintain strong reference
    local graphicsSize = cacheEntry.size or 1024

    -- Push transform
    love.graphics.push()
    love.graphics.translate(bodyX, bodyY)
    love.graphics.rotate(bodyAngle)
    love.graphics.translate(-bodyWidth / 2.0, -bodyHeight / 2.0)
    love.graphics.scale(bodyWidth / graphicsSize, bodyHeight / graphicsSize)

    -- Draw!
    love.graphics.setColor(1, 1, 1, 1)
    cacheEntry.drawData:graphics():draw()

    -- Pop transform
    love.graphics.pop()
end


-- UI

function Drawing2Behavior.handlers:uiComponent(component, opts)
end
