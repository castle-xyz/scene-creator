require('tools.draw_data')
require('tools.physics_body_data')

local Drawing2Behavior =
    defineCoreBehavior {
    name = "Drawing2",
    propertyNames = {
        "hash",
        "drawData",
        "physicsBodyData"
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

function Drawing2Behavior:cacheDrawing(data)
    local hash = data.hash

    if not cache[hash] then
        cache[hash] = self:deserialize(data)
    end

    return cache[hash]
end

function Drawing2Behavior:hash(drawData, physicsBodyData)
    local payload = {
        drawData = drawData,
        physicsBodyData = physicsBodyData,
    }
    local encoded = bitser.dumps(payload)
    local compressed = love.data.compress("string", "zlib", encoded)
    local base64 = love.data.encode("string", "base64", compressed)
    return base64
end

function Drawing2Behavior:deserialize(payload)
    local result = {}

    if payload == nil then
        result.drawData = DrawData:new({})
        result.physicsBodyData = PhysicsBodyData:new({})
    else
        result.drawData = DrawData:new(payload.drawData or {})
        result.physicsBodyData = PhysicsBodyData:new(payload.physicsBodyData or {})
    end

    return result
end

function Drawing2Behavior:updateBodyShape(component, physicsBodyData)
    self.dependencies.Body:setPoints(component.actorId, {physicsBodyData:getNormalizedPoints()})
end

-- Component management

function Drawing2Behavior.handlers:addComponent(component, bp, opts)
    -- NOTE: All of this must be pure w.r.t the arguments since we're directly setting and not sending
    component.properties.drawData = bp.drawData or DEFAULT_DATA
    component.properties.physicsBodyData = bp.physicsBodyData or DEFAULT_DATA
    component.properties.hash = self:hash(component.properties.drawData, component.properties.physicsBodyData)

    local data = self:cacheDrawing(component.properties)
    self:updateBodyShape(component, data.physicsBodyData)
end

function Drawing2Behavior.handlers:removeComponent(component, opts)
    if opts.isOrigin and not opts.removeActor then
        self.dependencies.Body:resetShapes(component.actorId)
    end
end

function Drawing2Behavior.handlers:blueprintComponent(component, bp)
    bp.drawData = component.properties.drawData
    bp.physicsBodyData = component.properties.physicsBodyData
end


-- Draw

function Drawing2Behavior.handlers:drawComponent(component)
    -- Body attributes
    local bodyWidth, bodyHeight = self.dependencies.Body:getSize(component.actorId)
    local bodyId, body = self.dependencies.Body:getBody(component.actorId)
    local bodyX, bodyY = body:getPosition()
    local bodyAngle = body:getAngle()

    local data = self:cacheDrawing(component.properties)
    local drawData = data.drawData

    if component._hash ~= component.properties.hash then
        self:updateBodyShape(component, data.physicsBodyData)
    end
    component._hash = component.properties.hash

    component._drawData = drawData -- Maintain strong reference
    local graphicsSize = drawData.scale or 10

    -- Push transform
    love.graphics.push()
    love.graphics.translate(bodyX, bodyY)
    love.graphics.rotate(bodyAngle)
    love.graphics.translate(-bodyWidth / 2.0, -bodyHeight / 2.0)
    love.graphics.scale(bodyWidth / graphicsSize, bodyHeight / graphicsSize)

    -- Draw!
    love.graphics.setColor(1, 1, 1, 1)
    drawData:graphics():draw()

    -- Pop transform
    love.graphics.pop()
end


-- UI

function Drawing2Behavior.handlers:uiComponent(component, opts)
end
