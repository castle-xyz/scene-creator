require 'love.system'
require 'love.image'
local jsEvents = require '__ghost__.jsEvents'

local Capture = {
   running = false,
   buffer = {},
   intervalSinceCapture = 0
}

local CAPTURE_FPS = 8
local CAPTURE_MAX_FRAMES = 12
local CAPTURE_OPTS = {
   width = 768,
}

function Client:startCapture()
   if not Capture.running then
      Capture.running = true
      Capture.intervalSinceCapture = 0
      Capture.buffer = {}
   end
end

function Client:isCapturing()
   return Capture.running
end

function Client:stopCapture()
   if Capture.running then
      Capture.running = false
      -- local channel = love.thread.getChannel("SCENE_CREATOR_ENCODE_CAPTURE")
      -- channel:push(Capture.buffer)
      -- love.thread.originalNewThread(
          -- require 'love.system'
          -- require 'love.image'
          -- local channel = love.thread.getChannel('SCENE_CREATOR_ENCODE_CAPTURE')
      print('rendering capture buffer...')
      local buffer = Capture.buffer -- channel:pop()
      if buffer then
         local baseFilename = 'capture-'
         for index, imageData in ipairs(buffer) do
            if imageData then
               local filename = baseFilename .. index .. '.png'
               imageData:encode('png', filename)
            end
         end
         jsEvents.send('GHOST_CAPTURE', {
                          path = love.filesystem.getSaveDirectory() .. '/' .. baseFilename,
                          numFrames = #buffer,
         })
      end
      -- ):start()

      print('finished rendering capture buffer')
      Capture.buffer = {}
   end
end

function Client:performCapture(dt)
   if Capture.running then
      Capture.intervalSinceCapture = Capture.intervalSinceCapture + dt
      if Capture.intervalSinceCapture >= 1.0 / CAPTURE_FPS then
         print('capturing frame')
         Capture.intervalSinceCapture = 0
         table.insert(Capture.buffer, self:renderScreenshotImageData(CAPTURE_OPTS))
         if #Capture.buffer == CAPTURE_MAX_FRAMES then
            self:stopCapture()
         end
      end
   end
end
