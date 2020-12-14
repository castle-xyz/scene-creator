-- width -> canvas
local screenshotCanvases = {}

local function _createScreenshotCanvas(opts)
    local screenshotWidth = 1350
    if opts ~= nil and opts.width ~= nil then
        screenshotWidth = opts.width
    end
    if not screenshotCanvases[screenshotWidth] then
        screenshotCanvases[screenshotWidth] =
            love.graphics.newCanvas(
            screenshotWidth,
            screenshotWidth * VIEW_HEIGHT_TO_WIDTH_RATIO,
            {
                dpiscale = 1,
                msaa = 4
            }
        )
    end
    return screenshotCanvases[screenshotWidth]
end

function Client:_drawScreenshot(opts)
    local screenshotWidth = 1350
    if opts ~= nil and opts.width ~= nil then
        screenshotWidth = opts.width
    end
    local cameraX, cameraY = self:getCameraPosition()
   love.graphics.push("all")

   love.graphics.origin()
   love.graphics.scale(screenshotWidth / DEFAULT_VIEW_WIDTH)
   love.graphics.translate(0, 0)
   love.graphics.translate(0.5 * DEFAULT_VIEW_WIDTH, self:getDefaultYOffset())
   if self.performing then
      love.graphics.translate(-cameraX, -cameraY)
   end

   love.graphics.clear(0.0, 0.0, 0.0, 0.0)
   self:drawScene()

   love.graphics.pop()
end

function Client:renderScreenshotImageData(opts)
    local canvas = _createScreenshotCanvas(opts)
    canvas:renderTo(
        function()
           self:_drawScreenshot(opts)
        end
    )
    return canvas:newImageData()
end

function Client:getScreenshotData()
    local fileData = self:renderScreenshotImageData():encode("png")
    return love.data.encode("string", "base64", fileData:getString())
end

function Client:saveScreenshot()
    local channel = love.thread.getChannel("SCENE_CREATOR_ENCODE_SCREENSHOT")
    channel:push(self:renderScreenshotImageData())
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
