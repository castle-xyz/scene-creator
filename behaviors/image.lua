local ImageBehavior =
    defineCoreBehavior {
    name = "Image",
    dependencies = {
        "Body"
    },
    propertySpecs = {
       url = {
          method = 'textInput',
          label = 'url',
       },
       color = {
          method = 'colorPicker',
          label = 'color',
       },
       filter = {
          method = 'dropdown',
          label = 'scaling style',
          props = { items = {"pixelated", "smooth"} },
       },
       cropEnabled = {
          method = 'toggle',
          label = 'crop',
       },
       cropX = {},
       cropY = {},
       cropWidth = {},
       cropHeight = {},
    },
}

-- Component management

function ImageBehavior.handlers:addComponent(component, bp, opts)
    -- NOTE: All of this must be pure w.r.t the arguments since we're directly setting and not sending
    component.properties.url = bp.url or CHECKERBOARD_IMAGE_URL
    component.properties.color = util.deepCopyTable(bp.color) or {1, 1, 1, 1}
    component.properties.filter = bp.filter or "nearest"
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
    component._imageHolder =
        resource_loader.loadImage(component._localUrl or component.properties.url, component.properties.filter)
    local image = component._imageHolder.image
    local imageWidth, imageHeight = image:getDimensions()

    -- Quad from crop
    if component._imageHolder.loaded and component.properties.cropEnabled then
        theQuad:setViewport(
            component.properties.cropX,
            component.properties.cropY,
            component.properties.cropWidth,
            component.properties.cropHeight,
            imageWidth,
            imageHeight
        )
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
    love.graphics.draw(image, theQuad, x, y, angle, scaleX, scaleY, 0.5 * imageWidth, 0.5 * imageHeight)
end

function ImageBehavior.getters:filter(component)
   return component.properties.filter == "nearest" and "pixelated" or "smooth"
end

function ImageBehavior.setters:filter(component, value)
   if value == "pixelated" then
      component.properties.filter = "nearest"
   elseif params.value == "smooth" then
      component.properties.filter = "linear"
   end
end

function ImageBehavior.setters:cropEnabled(component, newCropEnabled)
    local newCropSize, cropSize
    if not cropEnabled and newCropEnabled and component._imageHolder then
        -- Reset crop size to image dimensions when enabling
        newCropSize, cropSize = {}, {}
        cropSize.x, cropSize.y = component.properties.cropX, component.properties.cropY
        cropSize.width, cropSize.height =
            component.properties.cropWidth,
            component.properties.cropHeight
        local image = component._imageHolder.image
        local imageWidth, imageHeight = image:getDimensions()
        newCropSize.x, newCropSize.y = 0, 0
        newCropSize.width, newCropSize.height = imageWidth, imageHeight
    end
    self:command(
        "change crop",
        {
            noCoalesce = true,
            params = {"cropEnabled", "newCropEnabled", "cropSize", "newCropSize"}
        },
        function()
            if newCropSize then
                self:sendSetProperties(
                    actorId,
                    "cropX",
                    newCropSize.x,
                    "cropY",
                    newCropSize.y,
                    "cropWidth",
                    newCropSize.width,
                    "cropHeight",
                    newCropSize.height
                )
            end
            component.properties.cropEnabled = newCropEnabled
        end,
        function()
            if cropSize then
                self:sendSetProperties(
                    actorId,
                    "cropX",
                    cropSize.x,
                    "cropY",
                    cropSize.y,
                    "cropWidth",
                    cropSize.width,
                    "cropHeight",
                    cropSize.height
                )
            end
            component.properties.cropEnabled = newCropEnabled
        end
    )
end

function ImageBehavior:onChangeImageUrl(actorId, component, newUrl)
    local oldCropEnabled = component.properties.cropEnabled
    if not newUrl then -- Removing?
        IMAGE_UI_COUNTER = IMAGE_UI_COUNTER + 1
        component._localUrl = nil
        local oldUrl = component.properties.url
        self:command(
            "remove image",
            {
                coalesceSuffix = "remove image",
                params = {"oldCropEnabled", "oldUrl"}
            },
            function()
                self:sendSetProperties(actorId, "cropEnabled", false)
                self:sendSetProperties(actorId, "url", CHECKERBOARD_IMAGE_URL)
            end,
            function()
                self:sendSetProperties(actorId, "cropEnabled", oldCropEnabled)
                self:sendSetProperties(actorId, "url", oldUrl)
            end
        )
    elseif newUrl:match("^file://") then -- Local, still uploading
        component._localUrl = newUrl
        local oldUrl = component.properties.url
        self:command(
            "change image",
            {
                coalesceSuffix = "image-" .. newUrl,
                coalesceInterval = 30,
                params = {"oldCropEnabled", "oldUrl"}
            },
            function()
                self:sendSetProperties(actorId, "cropEnabled", false)
            end,
            function()
                IMAGE_UI_COUNTER = IMAGE_UI_COUNTER + 1
                self.components[actorId]._localUrl = nil
                self:sendSetProperties(actorId, "cropEnabled", oldCropEnabled)
                self:sendSetProperties(actorId, "url", oldUrl)
            end
        )
    else -- Uploaded
        if component._localUrl then
            local oldUrl = component.properties.url
            self:command(
                "change image",
                {
                    coalesceSuffix = "image-" .. component._localUrl,
                    coalesceInterval = 30,
                    params = {"oldCropEnabled", "oldUrl", "newUrl"}
                },
                function()
                    IMAGE_UI_COUNTER = IMAGE_UI_COUNTER + 1
                    self.components[actorId]._localUrl = nil
                    self:sendSetProperties(actorId, "cropEnabled", false)
                    self:sendSetProperties(actorId, "url", newUrl)
                end,
                function()
                    IMAGE_UI_COUNTER = IMAGE_UI_COUNTER + 1
                    self.components[actorId]._localUrl = nil
                    self:sendSetProperties(actorId, "cropEnabled", oldCropEnabled)
                    self:sendSetProperties(actorId, "url", oldUrl)
                end
            )
        end
    end
end
