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

function Drawing2Behavior:cacheDrawing(data)
    if not cache[data] then
        cache[data] = self:deserialize(data)
    end

    for k, v in pairs(cache) do
        if k ~= data then
            cache[k]:clearGraphics()
        end
    end

    return cache[data]
end

function Drawing2Behavior:serialize(drawData)
    return drawData
end

function Drawing2Behavior:deserialize(payload)
    if payload == nil then
        return DrawData:new({})
    end
    return DrawData:new(payload)
end

-- Component management

function Drawing2Behavior.handlers:addComponent(component, bp, opts)
    -- NOTE: All of this must be pure w.r.t the arguments since we're directly setting and not sending
    component.properties.data = bp.data or DEFAULT_DATA

    self:cacheDrawing(component.properties.data)
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

    local drawData = self:cacheDrawing(component.properties.data)

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
