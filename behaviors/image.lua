local ImageBehavior = {
    name = 'Image',
    propertyNames = {
        'url',
        'depth',
        'filter',
        'fitMode',
        'cropEnabled',
        'cropX',
        'cropY',
        'cropWidth',
        'cropHeight',
    },
    dependencies = {
        'Body',
    },
    handlers = {},
    description = [[
Uses an image to represent the actor in the scene. The source image can be cropped to only use a
part of it.
]],
}

registerCoreBehavior(2, ImageBehavior)


-- Component management

function ImageBehavior.handlers:addComponent(component, bp, opts)
    -- NOTE: All of this must be pure w.r.t the arguments since we're directly setting and not sending
    component.properties.url = bp.url or CHECKERBOARD_IMAGE_URL
    component.properties.depth = bp.depth or 0
    component.properties.filter = bp.filter or 'nearest'
    component.properties.fitMode = bp.fitMode or 'contain'
    if bp.cropEnabled ~= nil then
        component.properties.cropEnabled = bp.cropEnabled
    else
        component.properties.cropEnabled = false
    end
    component.properties.cropX = bp.cropX or 0
    component.properties.cropY = bp.cropY or 0
    component.properties.cropWidth = bp.cropWidth or 32
    component.properties.cropHeight = bp.cropHeight or 32
end

function ImageBehavior.handlers:removeComponent(component, opts)
end

function ImageBehavior.handlers:blueprintComponent(component, bp)
    bp.url = component.properties.url
    bp.depth = component.properties.depth
    bp.filter = component.properties.filter
    bp.fitMode = component.properties.fitMode
    bp.cropEnabled = component.properties.cropEnabled
    bp.cropX = component.properties.cropX
    bp.cropY = component.properties.cropY
    bp.cropWidth = component.properties.cropWidth
    bp.cropHeight = component.properties.cropHeight
end


-- Draw

local theTransform = love.math.newTransform()
local theQuad = love.graphics and love.graphics.newQuad(0, 0, 32, 32, 32, 32)

function ImageBehavior.handlers:draw(order)
    for actorId, component in pairs(self.components) do
        table.insert(order, {
            id = actorId,
            depth = component.properties.depth,
            draw = function()
                -- Load image drawable
                component._imageHolder = resource_loader.loadImage(
                    component.properties.localUrl or component.properties.url,
                    component.properties.filter)
                local image = component._imageHolder.image
                local imageWidth, imageHeight = image:getDimensions()

                -- Compute quad from crop
                local quad
                if component._imageHolder.loaded and component.properties.cropEnabled then
                    theQuad:setViewport(component.properties.cropX, component.properties.cropY,
                        component.properties.cropWidth, component.properties.cropHeight,
                        imageWidth, imageHeight)
                    imageWidth, imageHeight = component.properties.cropWidth, component.properties.cropHeight
                else
                    theQuad:setViewport(0, 0, imageWidth, imageHeight, imageWidth, imageHeight)
                end

                -- Compute scale from body size
                local bodyWidth, bodyHeight = self.dependencies.Body:getSize(actorId)
                local scaleX, scaleY = bodyWidth / imageWidth, bodyHeight / imageHeight
                if component._imageHolder.loaded and component.properties.fitMode == 'contain' then
                    scaleX = math.min(scaleX, scaleY)
                    scaleY = scaleX
                end

                -- Get position and angle from body
                local bodyId, body = self.dependencies.Body:getBody(actorId)
                local x, y = body:getPosition()
                local angle = body:getAngle()

                love.graphics.draw(
                    image,
                    theQuad,
                    x, y,
                    angle,
                    scaleX, scaleY,
                    0.5 * imageWidth, 0.5 * imageHeight)
            end,
        })
    end
end


-- UI

function ImageBehavior.handlers:uiComponent(component, opts)
    ui.filePicker(component.properties.localUrl and 'image (uploading...)' or 'image',
        component.properties.localUrl or component.properties.url, {
        id = 'image',
        type = 'image',
        onChange = function(newUrl)
            if not newUrl then
                self:sendSetProperties(component.actorId, 'url', CHECKERBOARD_IMAGE_URL)
            elseif newUrl:match('^file://') then
                component.properties.localUrl = newUrl
            else
                component.properties.localUrl = nil
                self:sendSetProperties(component.actorId, 'url', newUrl)
            end
        end,
    })

    util.uiRow('fit-mode-and-scaling-style', function()
        ui.dropdown('fit mode', component.properties.fitMode, { 'contain', 'stretch' }, {
            onChange = function(newFitMode)
                self:sendSetProperties(component.actorId, 'fitMode', newFitMode)
            end,
        })
    end, function()
        ui.dropdown('scaling style',
            component.properties.filter == 'nearest' and 'pixelated' or 'smooth', { 'pixelated', 'smooth' }, {
            onChange = function(newScalingStyle)
                if newScalingStyle == 'pixelated' then
                    self:sendSetProperties(component.actorId, 'filter', 'nearest')
                elseif newScalingStyle == 'smooth' then
                    self:sendSetProperties(component.actorId, 'filter', 'linear')
                end
            end,
        })
    end)

    ui.numberInput('depth', component.properties.depth, {
        onChange = function(newDepth)
            self:sendSetProperties(component.actorId, 'depth', newDepth)
        end,
    })

    util.uiRow('crop', function()
        ui.toggle('crop off', 'crop on', component.properties.cropEnabled, {
            onToggle = function(newCropEnabled)
                self:sendSetProperties(component.actorId, 'cropEnabled', newCropEnabled)
            end,
        })
    end, function()
        if component.properties.cropEnabled and component._imageHolder then
            local image = component._imageHolder.image
            local imageWidth, imageHeight = image:getDimensions()
            ui.markdown('base image is ' .. imageWidth .. ' by ' .. imageHeight)
        end
    end)
    if component.properties.cropEnabled then
        util.uiRow('crop-position', function()
            ui.numberInput('crop x', component.properties.cropX, {
                onChange = function(newCropX)
                    self:sendSetProperties(component.actorId, 'cropX', newCropX)
                end,
            })
        end, function()
            ui.numberInput('crop y', component.properties.cropY, {
                onChange = function(newCropY)
                    self:sendSetProperties(component.actorId, 'cropY', newCropY)
                end,
            })
        end)
        util.uiRow('crop-size', function()
            ui.numberInput('crop width', component.properties.cropWidth, {
                onChange = function(newCropWidth)
                    self:sendSetProperties(component.actorId, 'cropWidth', newCropWidth)
                end,
            })
        end, function()
            ui.numberInput('crop height', component.properties.cropHeight, {
                onChange = function(newCropHeight)
                    self:sendSetProperties(component.actorId, 'cropHeight', newCropHeight)
                end,
            })
        end)
    end
end


