local screenshotCanvas

local function _createScreenshotCanvas()
    if not screenshotCanvas then
        screenshotWidth = 1350

        screenshotCanvas =
            love.graphics.newCanvas(
            screenshotWidth,
            screenshotWidth * VIEW_HEIGHT_TO_WIDTH_RATIO,
            {
                dpiscale = 1,
                msaa = 4
            }
        )
    end
end

function Client:_drawScreenshot()
   love.graphics.push("all")

   love.graphics.origin()
   love.graphics.scale(screenshotWidth / DEFAULT_VIEW_WIDTH)
   love.graphics.translate(0, 0)
   love.graphics.translate(0.5 * DEFAULT_VIEW_WIDTH, self:getDefaultYOffset())

   love.graphics.clear(0.0, 0.0, 0.0, 0.0)
   self:drawScene()

   love.graphics.pop()
end

function Client:_renderScreenshotImageData()
    _createScreenshotCanvas()
    screenshotCanvas:renderTo(
        function()
           self:_drawScreenshot()
        end
    )
    return screenshotCanvas:newImageData()
end

function Client:getScreenshotData()
    local fileData = self:_renderScreenshotImageData():encode("png")
    return love.data.encode("string", "base64", fileData:getString())
end

function Client:saveScreenshot()
    local channel = love.thread.getChannel("SCENE_CREATOR_ENCODE_SCREENSHOT")
    channel:push(self:_renderScreenshotImageData())
    love.thread.originalNewThread(
        [[
        require 'love.system'
        require 'love.image'
        jsEvents = require '__ghost__.jsEvents'
        local channel = love.thread.getChannel('SCENE_CREATOR_ENCODE_SCREENSHOT')
        local imageData = channel:pop()
        if imageData then
            local filename = 'screenshot.png'
            imageData:encode('png', filename)
            jsEvents.send('GHOST_SCREENSHOT', {
                path = love.filesystem.getSaveDirectory() .. '/' .. filename,
            })
        end
    ]]
    ):start()

    -- todo: we need to clean this up or we run out of memory eventually, but calling release right here is too early
    -- screenshotCanvas:release()
end
