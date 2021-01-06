require('tools.draw_data')
require('tools.physics_body_data')

local Drawing2Behavior =
    defineCoreBehavior {
    name = "Drawing2",
    displayName = "Drawing",
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
       base64PngFrames = {  -- derived from drawData
          method = 'data',
       },
       initialFrame = {
          method = 'numberInput',
       },
       currentFrame = {
        method = 'numberInput',
        label = 'Current frame',
        props = { decimalDigits = 1 },
        rules = {
            get = true,
            set = true,
         },
       },
       playMode = {
        method = 'dropdown',
        label = 'Play mode',
        props = { items = {"still", "play once", "loop"} },
        rules = {
            set = true,
         },
       }, -- this isn't stored in the bp. only used for the rn ui
       loop = {},
       playing = {},
       framesPerSecond = {
        method = 'numberInput',
        label = 'Frames per second',
        props = { min = -30, max = 30, decimalDigits = 1 },
        rules = {
            set = true,
            get = true,
         },
       },
       loopStartFrame = {
        method = 'numberInput',
        label = 'Loop start frame',
        props = { decimalDigits = 1 },
        rules = {
            get = true,
            set = true,
         },
       },
       loopEndFrame = {
        method = 'numberInput',
        label = 'Loop end frame',
        props = { decimalDigits = 1 },
        rules = {
            get = true,
            set = true,
         },
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
          cache[hash].base64Png = cache[hash].drawData:renderPreviewPng(component.properties.initialFrame, 256)
          cache[hash].base64PngFrames = cache[hash].drawData:renderPreviewPngForFrames(256)
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
        result.base64PngFrames = nil
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
    self.dependencies.Body:sendSetProperties(component.actorId, "editorBounds", drawData:getBounds(component.properties.initialFrame))
    self.dependencies.Body:setShapes(component.actorId, physicsBodyData:getShapesForBody())

    component._hash = component.properties.hash
end

-- Component management

function Drawing2Behavior.handlers:addComponent(component, bp, opts)
    -- NOTE: All of this must be pure w.r.t the arguments since we're directly setting and not sending
    component.properties.drawData = bp.drawData or DEFAULT_DATA
    component.properties.physicsBodyData = bp.physicsBodyData or DEFAULT_DATA
    component.properties.hash = bp.hash or self:hash(component.properties.drawData, component.properties.physicsBodyData)

    -- animation properties
    component.properties.initialFrame = bp.initialFrame or 1
    component.properties.currentFrame = component.properties.initialFrame
    component.properties.loop = bp.loop
    if component.properties.loop == nil then
        component.properties.loop = false
    end
    component.properties.playing = bp.playing
    if component.properties.playing == nil then
        component.properties.playing = false
    end
    component.properties.framesPerSecond = bp.framesPerSecond or 4

    -- these can only be set from "set property" responses
    component.properties.loopStartFrame = nil
    component.properties.loopEndFrame = nil

    component._viewInContextAnimationState = nil
end

function Drawing2Behavior:setViewInContextAnimationState(component, animationState)
    component._viewInContextAnimationState = animationState
end

function Drawing2Behavior.handlers:enableComponent(component, opts)
    self:updateBodyShape(component)

    local data = self:cacheDrawing(component, component.properties)
    local drawData = data.drawData
    component.animationState = drawData:newAnimationState()
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
    -- don't blueprint base64Png or base64PngFrames, derive from drawing data

    -- animation properties
    bp.initialFrame = component.properties.initialFrame
    bp.loop = component.properties.loop
    bp.playing = component.properties.playing
    bp.framesPerSecond = component.properties.framesPerSecond
end

function Drawing2Behavior.handlers:blueprintPng(component)
    local data = self:cacheDrawing(component, component.properties)
    return data.drawData:renderPreviewPng(component.properties.initialFrame, 256)
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

function Drawing2Behavior.getters:base64PngFrames(component)
    if self.game.activeToolBehaviorId == self.game.behaviorsByName.Draw2.behaviorId then
       -- no need to render drawing previews when the draw tool is active
       return nil
    end
    local data = self:cacheDrawing(component, component.properties)
    return data.base64PngFrames
end

function Drawing2Behavior.setters:base64PngFrames(component, ...)
    -- noop, this is derived from drawData
end

function Drawing2Behavior.setters:initialFrame(component, value)
    component.properties.initialFrame = value
    component.properties.currentFrame = value

    local data = self:cacheDrawing(component, component.properties)
    local drawData = data.drawData
    self.dependencies.Body:sendSetProperties(component.actorId, "editorBounds", drawData:getBounds(component.properties.initialFrame))
end

function Drawing2Behavior.getters:playMode(component)
    if not component.properties.playing then
        return "still"
    end

    if component.properties.loop then
        return "loop"
    else
        return "play once"
    end
 end

function Drawing2Behavior.setters:playMode(component, value)
    if value == "still" then
        component.properties.playing = false
        component.properties.loop = false
    elseif value == "play once" then
        component.properties.playing = true
        component.properties.loop = false
    else
        component.properties.playing = true
        component.properties.loop = true
    end
end

Drawing2Behavior.triggers["animation end"] = {
    description = "When the animation ends",
    category = "draw",
}

Drawing2Behavior.triggers["animation loop"] = {
    description = "When the animation loops",
    category = "draw",
}

-- Draw

-- use postPerform so that destroying/hiding an actor in the
-- "animation loop" trigger happens the same frame as the loop
function Drawing2Behavior.handlers:postPerform(dt)
    if not self.game.performing then
        return
    end

    self.game:forEachActorByDrawOrder(
        function(actor)
            local component = self.components[actor.actorId]
            if component and component.animationState then
                local fireTrigger = function (eventName)
                    self:fireTrigger(eventName, actor.actorId)
                end

                local data = self:cacheDrawing(component, component.properties)
                local drawData = data.drawData
                drawData:runAnimation(component.animationState, component.properties, dt, fireTrigger)
            end
        end
    )
end

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

    local animationProperties = component.properties
    if component._viewInContextAnimationState then
        animationProperties = component._viewInContextAnimationState
    end
    drawData:render(animationProperties)

    -- Pop transform
    love.graphics.pop()
end


-- UI

function Drawing2Behavior.handlers:uiComponent(component, opts)
end
