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


local DEFAULT_URL = 'assets/rectangle.svg'
local DEFAULT_CONTENTS = love.filesystem.newFileData(DEFAULT_URL):getString()


-- Component management

function DrawingBehavior.handlers:addComponent(component, bp, opts)
    -- NOTE: All of this must be pure w.r.t the arguments since we're directly setting and not sending
    component.properties.url = bp.url or DEFAULT_URL
end

function DrawingBehavior.handlers:blueprintComponent(component, bp)
    bp.url = component.properties.url
end


-- Draw

local graphicsCache = setmetatable({}, { __mode = 'k' })
local sizeCache = setmetatable({}, { __mode = 'k' })

function DrawingBehavior.handlers:drawComponent(component)
    -- Load graphics
    local fileDataHolder = resource_loader.loadFileData(component.properties.url)
    component._fileDataHolder = fileDataHolder
    local fileData = fileDataHolder.fileData
    local fileContents = (fileData and fileData:getString()) or DEFAULT_CONTENTS
    local graphics = graphicsCache[fileContents]
    if not graphics then
        graphics = tove.newGraphics(fileContents, 256)
        graphics:setResolution(4)
        graphicsCache[fileContents] = graphics
    end

    -- Size
    local size = sizeCache[graphics]
    if not size then
        local minX, minY, maxX, maxY = graphics:computeAABB('high')
        size = { width = maxX - minX, height = maxY - minY }
        sizeCache[graphics] = size
    end

    -- Scale from body size
    local bodyWidth, bodyHeight = self.dependencies.Body:getSize(component.actorId)
    local scaleX, scaleY = bodyWidth / size.width, bodyHeight / size.height

    -- Position and angle from body
    local bodyId, body = self.dependencies.Body:getBody(component.actorId)
    local x, y = body:getPosition()
    local angle = body:getAngle()

    -- Draw!
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(angle)
    love.graphics.scale(scaleX, scaleY)
    graphics:draw()
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


