local ImageBehavior = {
    name = 'Image',
    propertyNames = {
        'url',
        'color',
        'depth',
        'filter',
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
}

registerCoreBehavior(ImageBehavior)


-- Component management

function ImageBehavior.handlers:addComponent(component, bp, opts)
    -- NOTE: All of this must be pure w.r.t the arguments since we're directly setting and not sending
    component.properties.url = bp.url or CHECKERBOARD_IMAGE_URL
    component.properties.color = bp.color or { 1, 1, 1, 1 }
    component.properties.depth = bp.depth or 0
    component.properties.filter = bp.filter or 'nearest'
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

function ImageBehavior.handlers:blueprintComponent(component, bp)
    bp.url = component.properties.url
    bp.color = util.deepCopyTable(component.properties.color)
    bp.depth = component.properties.depth
    bp.filter = component.properties.filter
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
                -- Image drawable
                component._imageHolder = resource_loader.loadImage(
                    component.properties.localUrl or component.properties.url,
                    component.properties.filter)
                local image = component._imageHolder.image
                local imageWidth, imageHeight = image:getDimensions()

                -- Quad from crop
                local quad
                if component._imageHolder.loaded and component.properties.cropEnabled then
                    theQuad:setViewport(component.properties.cropX, component.properties.cropY,
                        component.properties.cropWidth, component.properties.cropHeight,
                        imageWidth, imageHeight)
                    imageWidth, imageHeight = component.properties.cropWidth, component.properties.cropHeight
                else
                    theQuad:setViewport(0, 0, imageWidth, imageHeight, imageWidth, imageHeight)
                end

                -- Scale from body size
                local bodyWidth, bodyHeight = self.dependencies.Body:getSize(actorId)
                local scaleX, scaleY = bodyWidth / imageWidth, bodyHeight / imageHeight

                -- Position and angle from body
                local bodyId, body = self.dependencies.Body:getBody(actorId)
                local x, y = body:getPosition()
                local angle = body:getAngle()

                -- Color
                love.graphics.setColor(component.properties.color)

                -- Draw!
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

    ui.box('color-and-opacity', { flexDirection = 'row', alignItems = 'flex-start' }, function()
        ui.box('color', { flex = 1 }, function()
            local color = component.properties.color
            ui.colorPicker('color', color[1], color[2], color[3], 1, {
                enableAlpha = false,
                onChange = function(newColor)
                    self:sendSetProperties(component.actorId, 'color', { newColor.r, newColor.g, newColor.b, color[4] })
                end,
            })
        end)
        ui.box('color', { flex = 3 }, function()
            ui.slider('opacity', component.properties.color[4], 0, 1, {
                step = 0.01,
                onChange = function(newOpacity)
                    local color = component.properties.color
                    self:sendSetProperties(component.actorId, 'color', { color[1], color[2], color[3], newOpacity })
                end,
            })
        end)
    end)

    util.uiRow('depth-and-scaling-style', function()
        ui.numberInput('depth', component.properties.depth, {
            onChange = function(newDepth)
                self:sendSetProperties(component.actorId, 'depth', newDepth)
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


