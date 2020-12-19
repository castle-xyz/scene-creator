require('tools.draw_data')
require('tools.physics_body_data')

local Drawing2Behavior =
    defineCoreBehavior {
    name = "Drawing2",
    dependencies = {
        "Body"
    },
    propertySpecs = {
       hash = {},
       drawData = {},
       physicsBodyData = {},
       base64Png = {  -- derived from drawData
          method = 'data',
       },
    },
}

local ffi = require "ffi"
local C = ffi.C

-- TODO
local DEFAULT_DATA = ''

-- Loading

-- TODO: we should use a weak map in edit mode but not in play mode. using a weak map in play mode causes stutters
-- because drawing get garage collected too aggressively
--local cache = setmetatable({}, {__mode = "v"})
local cache = setmetatable({}, {})

function Drawing2Behavior:preloadDrawing(data)
    if not data.hash then
        data.hash = self:hash(data.drawData, data.physicsBodyData)
    end

    local cacheData = self:cacheDrawing(nil, data)
    local drawData = cacheData.drawData
    drawData:preload()
end

function Drawing2Behavior:cacheDrawing(component, data)
    local hash = data.hash

    if not cache[hash] then
        cache[hash] = self:deserialize(data)
    end

    if not cache[hash].base64Png and not self.game.isPerforming then
       local selectedActorId = next(self.game.selectedActorIds)
       if component ~= nil and component.actorId == selectedActorId then
          cache[hash].base64Png = cache[hash].drawData:renderPreviewPng(256)
       end
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
        result.base64Png = nil
    else
        result.drawData = DrawData:new(payload.drawData or {})
        result.physicsBodyData = PhysicsBodyData:new(payload.physicsBodyData or {})
    end

    return result
end

function Drawing2Behavior:updateBodyShape(componentOrActorId)
    local component = type(componentOrActorId) == "table" and componentOrActorId or self.components[componentOrActorId]

    local data = self:cacheDrawing(component, component.properties)
    local drawData = data.drawData
    local physicsBodyData = data.physicsBodyData

    self.dependencies.Body:sendSetProperties(component.actorId, "isNewDrawingTool", true)
    self.dependencies.Body:sendSetProperties(component.actorId, "editorBounds", drawData:getBounds())
    self.dependencies.Body:setShapes(component.actorId, physicsBodyData:getShapesForBody())

    component._hash = component.properties.hash
end

-- Component management

function Drawing2Behavior.handlers:addComponent(component, bp, opts)
    -- NOTE: All of this must be pure w.r.t the arguments since we're directly setting and not sending
    component.properties.drawData = bp.drawData or DEFAULT_DATA
    component.properties.physicsBodyData = bp.physicsBodyData or DEFAULT_DATA
    component.properties.hash = bp.hash or self:hash(component.properties.drawData, component.properties.physicsBodyData)
end

function Drawing2Behavior.handlers:enableComponent(component, opts)
    self:updateBodyShape(component)
end

function Drawing2Behavior.handlers:disableComponent(component, opts)
    if opts.isOrigin and not opts.removeActor then
        self.dependencies.Body:resetShapes(component.actorId)
    end

    self.dependencies.Body:sendSetProperties(component.actorId, "isNewDrawingTool", false)
end

function Drawing2Behavior.handlers:blueprintComponent(component, bp)
    bp.drawData = component.properties.drawData
    bp.physicsBodyData = component.properties.physicsBodyData
    bp.hash = component.properties.hash
    -- don't blueprint base64Png, derive from drawing data
end

function Drawing2Behavior.handlers:blueprintPng(component)
    local data = self:cacheDrawing(component, component.properties)
    return data.drawData:renderPreviewPng(256)
end

function Drawing2Behavior.getters:base64Png(component)
   if self.game.activeToolBehaviorId == self.game.behaviorsByName.Draw2.behaviorId then
      -- no need to render drawing previews when the draw tool is active
      return nil
   end
   local data = self:cacheDrawing(component, component.properties)
   return data.base64Png
end

function Drawing2Behavior.setters:base64Png(component, ...)
   -- noop, this is derived from drawData
end

-- Draw

function Drawing2Behavior.handlers:drawComponent(component)
    local bodyComponent = self.dependencies.Body.components[component.actorId]
    if (bodyComponent.properties.visible == false or bodyComponent.properties.visible == 0)
    and self.game.performing then
        return
    end

    -- Body attributes
    local bodyWidthScale, bodyHeightScale = self.dependencies.Body:getScale(component.actorId)
    local bodyId, body = self.dependencies.Body:getBody(component.actorId)
    local bodyX, bodyY = body:getPosition()
    local bodyAngle = body:getAngle()

    local members = self.dependencies.Body:getMembers(component.actorId)
    if members and members.layer and members.layer.relativeToCamera then
        local cameraX, cameraY = self.game:getCameraPosition()
        bodyX = bodyX + cameraX
        bodyY = bodyY + cameraY
    end

    -- TODO: fix for scale conversion
    --[[
    if self.game.performing then
        local cameraCornerX, cameraCornerY = self.game:getCameraCornerPosition()
        local cameraWidth, cameraHeight = self.game:getCameraSize()
        local bodySizeForCamera = bodyWidth
        if bodyHeight > bodyWidth then
            bodySizeForCamera = bodyHeight
        end

        if bodyX + bodySizeForCamera < cameraCornerX or bodyX - bodySizeForCamera > cameraCornerX + cameraWidth or bodyY + bodySizeForCamera < cameraCornerY or bodyY - bodySizeForCamera > cameraCornerY + cameraHeight then
            return
        end
    end]]--

    local data = self:cacheDrawing(component, component.properties)
    local drawData = data.drawData

    if component._hash ~= component.properties.hash then
        self:updateBodyShape(component)
    end

    component._drawData = drawData -- Maintain strong reference

    -- Push transform
    love.graphics.push("all")
    love.graphics.translate(bodyX, bodyY)
    love.graphics.rotate(bodyAngle)
    love.graphics.scale(bodyWidthScale, bodyHeightScale)

    -- Draw!
    love.graphics.setColor(1, 1, 1, 1)
    drawData:render()

    -- Pop transform
    love.graphics.pop()
end


-- UI

function Drawing2Behavior.handlers:uiComponent(component, opts)
end
