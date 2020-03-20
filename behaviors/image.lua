local ImageBehavior = defineCoreBehavior {
    name = 'Image',
    propertyNames = {
        'url',
        'color',
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
}


-- Component management

function ImageBehavior.handlers:addComponent(component, bp, opts)
    -- NOTE: All of this must be pure w.r.t the arguments since we're directly setting and not sending
    component.properties.url = bp.url or CHECKERBOARD_IMAGE_URL
    component.properties.color = util.deepCopyTable(bp.color) or { 1, 1, 1, 1 }
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
    bp.filter = component.properties.filter
    bp.cropEnabled = component.properties.cropEnabled
    bp.cropX = component.properties.cropX
    bp.cropY = component.properties.cropY
    bp.cropWidth = component.properties.cropWidth
    bp.cropHeight = component.properties.cropHeight
end


-- Draw

local theQuad = love.graphics and love.graphics.newQuad(0, 0, 32, 32, 32, 32)

function ImageBehavior.handlers:drawComponent(component)
    -- Image drawable
    component._imageHolder = resource_loader.loadImage(
        component._localUrl or component.properties.url,
        component.properties.filter)
    local image = component._imageHolder.image
    local imageWidth, imageHeight = image:getDimensions()

    -- Quad from crop
    if component._imageHolder.loaded and component.properties.cropEnabled then
        theQuad:setViewport(component.properties.cropX, component.properties.cropY,
            component.properties.cropWidth, component.properties.cropHeight,
            imageWidth, imageHeight)
        imageWidth, imageHeight = component.properties.cropWidth, component.properties.cropHeight
    else
        theQuad:setViewport(0, 0, imageWidth, imageHeight, imageWidth, imageHeight)
    end

    -- Scale from body size
    local bodyWidth, bodyHeight = self.dependencies.Body:getSize(component.actorId)
    local scaleX, scaleY = bodyWidth / imageWidth, bodyHeight / imageHeight

    -- Position and angle from body
    local bodyId, body = self.dependencies.Body:getBody(component.actorId)
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
end


-- UI

IMAGE_UI_COUNTER = 1 -- Forces resetting of the image `filePicker` ui id so old uploades don't override new ones

function ImageBehavior.handlers:uiComponent(component, opts)
    local actorId = component.actorId

    ui.box('image picker', { flexDirection = 'row', alignItems = 'flex-start' }, function()
        ui.box('file picker', { flex = 1 }, function()
            ui.filePicker(component._localUrl and 'image (uploading...)' or 'image',
                component._localUrl or component.properties.url, {
                id = 'image-' .. IMAGE_UI_COUNTER,
                type = 'image',
                onChange = function(newUrl)
                    local oldCropEnabled = component.properties.cropEnabled
                    if not newUrl then -- Removing?
                        IMAGE_UI_COUNTER = IMAGE_UI_COUNTER + 1
                        component._localUrl = nil
                        local oldUrl = component.properties.url
                        self:command('remove image', {
                            coalesceSuffix = 'remove image',
                            params = { 'oldCropEnabled', 'oldUrl' },
                        }, function()
                            self:sendSetProperties(actorId, 'cropEnabled', false)
                            self:sendSetProperties(actorId, 'url', CHECKERBOARD_IMAGE_URL)
                        end, function()
                            self:sendSetProperties(actorId, 'cropEnabled', oldCropEnabled)
                            self:sendSetProperties(actorId, 'url', oldUrl)
                        end)
                    elseif newUrl:match('^file://') then -- Local, still uploading
                        component._localUrl = newUrl
                        local oldUrl = component.properties.url
                        self:command('change image', {
                            coalesceSuffix = 'image-' .. newUrl,
                            coalesceInterval = 30,
                            params = { 'oldCropEnabled', 'oldUrl' },
                        }, function()
                            self:sendSetProperties(actorId, 'cropEnabled', false)
                        end, function()
                            IMAGE_UI_COUNTER = IMAGE_UI_COUNTER + 1
                            self.components[actorId]._localUrl = nil
                            self:sendSetProperties(actorId, 'cropEnabled', oldCropEnabled)
                            self:sendSetProperties(actorId, 'url', oldUrl)
                        end)
                    else -- Uploaded
                        if component._localUrl then
                            local oldUrl = component.properties.url
                            self:command('change image', {
                                coalesceSuffix = 'image-' .. component._localUrl,
                                coalesceInterval = 30,
                                params = { 'oldCropEnabled', 'oldUrl', 'newUrl' },
                            }, function()
                                IMAGE_UI_COUNTER = IMAGE_UI_COUNTER + 1
                                self.components[actorId]._localUrl = nil
                                self:sendSetProperties(actorId, 'cropEnabled', false)
                                self:sendSetProperties(actorId, 'url', newUrl)
                            end, function()
                                IMAGE_UI_COUNTER = IMAGE_UI_COUNTER + 1
                                self.components[actorId]._localUrl = nil
                                self:sendSetProperties(actorId, 'cropEnabled', oldCropEnabled)
                                self:sendSetProperties(actorId, 'url', oldUrl)
                            end)
                        end
                    end
                end,
            })
        end)
        ui.box('library picker', {
            flex = 3,
            alignSelf = 'stretch',
            flexDirection = 'row',
            alignItems = 'flex-end',
            justifyContent = 'flex-start',
        }, function()
            ui.button('choose from library', {
                icon = 'book',
                iconFamily = 'FontAwesome',
                popoverAllowed = true,
                popoverStyle = { width = 300, height = 300 },
                popover = function(closePopover)
                    self.game:uiLibrary({
                        id = 'image',
                        filterType = 'image',
                        emptyText = 'No images!',
                        buttons = function(entry)
                            ui.button('use', {
                                flex = 1,
                                icon = 'plus',
                                iconFamily = 'FontAwesome5',
                                onClick = function()
                                    closePopover()

                                    local oldCropEnabled = component.properties.cropEnabled
                                    local oldUrl = component.properties.url
                                    local newUrl = entry.image.url
                                    self:command('change image', {
                                        params = { 'oldCropEnabled', 'oldUrl', 'newUrl' },
                                    }, function()
                                        self:sendSetProperties(actorId, 'cropEnabled', false)
                                        self.components[actorId]._localUrl = nil
                                        self:sendSetProperties(actorId, 'cropEnabled', false)
                                        self:sendSetProperties(actorId, 'url', newUrl)
                                    end, function()
                                        IMAGE_UI_COUNTER = IMAGE_UI_COUNTER + 1
                                        self.components[actorId]._localUrl = nil
                                        self:sendSetProperties(actorId, 'cropEnabled', oldCropEnabled)
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

    ui.box('color and opacity', { flexDirection = 'row', alignItems = 'flex-start' }, function()
        ui.box('color', { flex = 1 }, function()
            local color = component.properties.color
            self:uiValue('colorPicker', 'color', { color[1], color[2], color[3], 1 }, {
                props = { enableAlpha = false },
                onChange = function(params)
                    local color = self.components[actorId].properties.color
                    self:sendSetProperties(actorId, 'color',
                        { params.value[1], params.value[2], params.value[3], color[4] })
                end,
            })
        end)
        ui.box('opacity', { flex = 3 }, function()
            self:uiValue('slider', 'opacity', component.properties.color[4], {
                props = { min = 0, max = 1, step = 0.01 },
                onChange = function(params)
                    local color = self.components[actorId].properties.color
                    self:sendSetProperties(actorId, 'color', { color[1], color[2], color[3], params.value })
                end,
            })
        end)
    end)

    self:uiValue('dropdown', 'scaling style', component.properties.filter == 'nearest' and 'pixelated' or 'smooth', {
        props = { items = { 'pixelated', 'smooth' } },
        onChange = function(params)
            if params.value == 'pixelated' then
                self:sendSetProperties(actorId, 'filter', 'nearest')
            elseif params.value == 'smooth' then
                self:sendSetProperties(actorId, 'filter', 'linear')
            end
        end,
    })

    util.uiRow('crop', function()
        local cropEnabled = component.properties.cropEnabled
        ui.toggle('crop', 'crop', cropEnabled, {
            onToggle = function(newCropEnabled)
                local newCropSize, cropSize
                if not cropEnabled and newCropEnabled and component._imageHolder then
                    -- Reset crop size to image dimensions when enabling
                    newCropSize, cropSize = {}, {}
                    cropSize.x, cropSize.y = component.properties.cropX, component.properties.cropY
                    cropSize.width, cropSize.height = component.properties.cropWidth, component.properties.cropHeight
                    local image = component._imageHolder.image
                    local imageWidth, imageHeight = image:getDimensions()
                    newCropSize.x, newCropSize.y = 0, 0
                    newCropSize.width, newCropSize.height = imageWidth, imageHeight
                end
                self:command('change crop', {
                    noCoalesce = true,
                    params = { 'cropEnabled', 'newCropEnabled', 'cropSize', 'newCropSize' },
                }, function()
                    if newCropSize then
                        self:sendSetProperties(actorId,
                            'cropX', newCropSize.x, 'cropY', newCropSize.y,
                            'cropWidth', newCropSize.width, 'cropHeight', newCropSize.height)
                    end
                    self:sendSetProperties(actorId, 'cropEnabled', newCropEnabled)
                end, function()
                    if cropSize then
                        self:sendSetProperties(actorId,
                            'cropX', cropSize.x, 'cropY', cropSize.y,
                            'cropWidth', cropSize.width, 'cropHeight', cropSize.height)
                    end
                    self:sendSetProperties(actorId, 'cropEnabled', cropEnabled)
                end)
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
        util.uiRow('crop position', function()
            self:uiProperty('numberInput', 'crop x', actorId, 'cropX')
        end, function()
            self:uiProperty('numberInput', 'crop y', actorId, 'cropY')
        end)
        util.uiRow('crop size', function()
            self:uiProperty('numberInput', 'crop width', actorId, 'cropWidth')
        end, function()
            self:uiProperty('numberInput', 'crop height', actorId, 'cropHeight')
        end)
    end
end


