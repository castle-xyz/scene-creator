-- Prefetch all hosted files
if (portal.basePath:match('^https?://api%.castle%.games/') and
        CASTLE_INITIAL_DATA and CASTLE_INITIAL_DATA.hostedFiles and
        network.findPersistedFetchResult) then
    local ignore = {
        ['cover.png'] = true,
        ['.castleid'] = true,
        ['project.castle'] = true,
    }
    local filenames = {}
    for filename, target in pairs(CASTLE_INITIAL_DATA.hostedFiles) do
        if not ignore[filename] then
            local path = portal.basePath .. '/' .. filename
            if not network.findPersistedFetchResult(target, 'GET') then
                network.async(function()
                    network.fetch(path, 'HEAD')
                end)
                network.async(function()
                    network.fetch(path, 'GET')
                end)
            end
        end
    end
end


-- 'multi' boilerplate
LOCAL_SERVER = true -- Enable to force a local server and never use a remote one
function GET_SERVER_MODULE_NAME()
    return 'Server'
end
Game = require('multi.client', { root = true })
Common, Server, Client = Game.Common, Game.Server, Game.Client
require 'Common'


-- Initial params

INITIAL_PARAMS = castle.game.getInitialParams()


-- Client modules

require 'select'
require 'touch'
require 'ui'
require 'notify'


-- Start / stop

local instance

function Client:start()
    instance = self

    self.lastPingSentTime = nil

    self.photoImages = {}

    self:startSelect()

    self:startTouch()

    self:startUi()

    self:startNotify()

    self:resetView()
    self.viewTransform = love.math.newTransform()
end


-- Connect / reconnect / disconnect

function Client:connect()
    Common.start(self)

    -- Send `me`
    local me = castle.user.getMe()
    self:send('me', self.clientId, me)
end

function Client:reconnect()
    Common.stop(self)
    Common.start(self)
end


-- Debug receive

--function Client:debugReceive(kind, time, ...)
--    if kind ~= '_ping' and kind ~= '_pong' then
--        print(kind, ...)
--    end
--end


-- Users

function Client.receivers:me(time, clientId, me)
    Common.receivers.me(self, time, clientId, me)

    -- Also load the photo image
    local photoUrl = self.mes[clientId].photoUrl
    if photoUrl then
        network.async(function()
            self.photoImages[clientId] = love.graphics.newImage(photoUrl)
        end)
    end
end


-- Begin / end editing

function Client:beginEditing()
    if self.performing then
        if self.rewindSnapshotId then
            self:send('restoreSnapshot', self.rewindSnapshotId)
            self:send('removeSnapshot', self.rewindSnapshotId)
        else
            self:send('setPerforming', false)
        end
    end
end

function Client:endEditing()
    if self.performing then
        if self.rewindSnapshotId then
            self:send('restoreSnapshot', self.rewindSnapshotId, { stopPerforming = false })
        end
    else
        self:saveScreenshot()
        local snapshot = self:createSnapshot()
        self:saveScene(snapshot)
        self:send('addSnapshot', util.uuid(), snapshot, { isRewind = true })
        self:send('setPerforming', true)
        self:send('setPaused', false)
    end
end


-- Ready

function Client.receivers:ready(time)
    if not self.initialParamsRead and INITIAL_PARAMS then
        local scene = INITIAL_PARAMS.scene
        --if scene then
        --    print('scene', serpent.block(scene))
        --end
        self.sceneId = scene and scene.sceneId
        if scene and scene.data and scene.data.snapshot then
            self:send('addSnapshot', util.uuid(), scene.data.snapshot, { isRewind = true })
            self:send('restoreSnapshot', self.rewindSnapshotId, {
                stopPerforming = not not INITIAL_PARAMS.isEditing,
            })
        elseif INITIAL_PARAMS.isEditing then
            self:beginEditing()
        end

        self.initialParamsRead = true
    end

    -- Do garbage collection cycles soon
    network.async(function()
        collectgarbage()
        collectgarbage()
        copas.sleep(0.05)
        collectgarbage()
        collectgarbage()
    end)
end


-- JS Events

jsEvents.listen('SCENE_CREATOR_EDITING', function(params)
    local self = instance
    if self then
        if params.isEditing ~= nil then
            if params.isEditing then
                self:beginEditing()
            else
                self:endEditing()
            end
        end
    end
end)


-- Update

function Client:twoFingerPan()
    if self.numTouches == 2 then
        self.gestureStolen = true

        local moveX, moveY = 0, 0
        local centerX, centerY
        local scale

        local touchId1, touch1 = next(self.touches)
        local touchId2, touch2 = next(self.touches, touchId1)

        local touch1PrevSX, touch1PrevSY = touch1.screenX - touch1.screenDX, touch1.screenY - touch1.screenDY
        local touch2PrevSX, touch2PrevSY = touch2.screenX - touch2.screenDX, touch2.screenY - touch2.screenDY

        local centerSX, centerSY = 0.5 * (touch1.screenX + touch2.screenX), 0.5 * (touch1.screenY + touch2.screenY)
        local centerPrevSX, centerPrevSY = 0.5 * (touch1PrevSX + touch2PrevSX), 0.5 * (touch1PrevSY + touch2PrevSY)

        moveX, moveY = (centerSX - centerPrevSX) / self:getViewScale(), (centerSY - centerPrevSY) / self:getViewScale()

        local px, py = touch1.screenX - touch2.screenX, touch1.screenY - touch2.screenY
        local pl = math.sqrt(px * px + py * py)
        local prevPX, prevPY = touch1PrevSX - touch2PrevSX, touch1PrevSY - touch2PrevSY
        local initialPX, initialPY = touch1.initialScreenX - touch2.initialScreenX, touch1.initialScreenY - touch2.initialScreenY
        local initialPL = math.sqrt(initialPX * initialPX + initialPY * initialPY)
        if (touch1.zooming or touch2.zooming or
                not (self.viewWidth == DEFAULT_VIEW_WIDTH and math.abs(initialPL - pl) <= 0.175 * initialPL)) then
            -- Don't zoom if close to 1:1
            local prevPL = math.sqrt(prevPX * prevPX + prevPY * prevPY)
            if not (touch1.zooming and touch2.zooming) then
                touch1.zooming = true
                touch2.zooming = true
                prevPL = initialPL
            end
            scale = prevPL / pl
        end

        centerX, centerY = self.viewTransform:inverseTransformPoint(centerSX, centerSY)

        if scale then
            local prevViewWidth = self.viewWidth
            self.viewWidth = math.max(MIN_VIEW_WIDTH, math.min(scale * self.viewWidth, MAX_VIEW_WIDTH))
            if math.abs(self.viewWidth - DEFAULT_VIEW_WIDTH) < 0.1 * DEFAULT_VIEW_WIDTH then
                self.viewWidth = DEFAULT_VIEW_WIDTH
            end
            scale = self.viewWidth / prevViewWidth -- Recompute to account for clamping above
            moveX = moveX - (1 - scale) * (centerX - self.viewX)
            moveY = moveY - (1 - scale) * (centerY - self.viewY)
        end
        if not (touch1.noPan or touch2.noPan) then
            local prevX, prevY = self.viewX, self.viewY
            self.viewX, self.viewY = self.viewX - moveX, self.viewY - moveY
            if self.viewWidth == DEFAULT_VIEW_WIDTH then -- Move snap only when zoom is 1:1
                local prevL = math.sqrt(prevX * prevX + prevY * prevY)
                local l = math.sqrt(self.viewX * self.viewX + self.viewY * self.viewY)
                if l < prevL and l < 0.2 * UNIT then -- Moved close to center? Snap and disable pan for rest of gesture.
                    self.viewX, self.viewY = 0, 0
                    touch1.noPan = true
                    touch2.noPan = true
                end
            end
        end
    end
end

function Client:update(dt)
    if not self.connected then
        return
    end

    local currTime = love.timer.getTime()
    if not self.lastPingSentTime or currTime - self.lastPingSentTime > 2 then
        self.lastPingSentTime = currTime
        self:send('ping', self.clientId)
    end

    self:updateTouches()

    self:updatePerformance(dt)
    self:applySelections() -- Performance may have added or removed actors or components, so apply changes

    self:callHandlers('preUpdate', dt)

    if not self.performing then
        self:touchToSelect() -- Do these after `preUpdate` to allow tools to steal touches first
        self:twoFingerPan()
    end

    self:callHandlers('update', dt)
    self:callHandlers('postUpdate', dt)

    self:updateNotify(dt)

    self:updateAutoSaveScene()
end


-- Draw

local debugFont = love.graphics.newFont(14)

function Client:resetViewPosition()
    self.viewX, self.viewY = 0, 0
end

function Client:resetViewSize()
    self.viewWidth = DEFAULT_VIEW_WIDTH
end

function Client:resetView()
    self:resetViewPosition()
    self:resetViewSize()
end

function Client:getViewScale()
    local scale = self.viewTransform:getMatrix()
    return scale
end

function Client:getPixelScale()
    return love.graphics.getDPIScale() / self:getViewScale()
end

function Client.receivers:setPerforming(time, performing)
    -- Entering perform?
    if not self.performing and performing then
        -- Save paused view state and reset view
        self._pausedView = {
            x = self.viewX,
            y = self.viewY,
            width = self.viewWidth,
        }
        self:resetView()

        -- Close blueprints and inspector
        self:snapBlueprintsPane(3)
        self:snapInspectorPane(2)
    end

    -- Exiting perform?
    if self.performing and not performing then
        -- Open inspector or blueprints
        if next (self.selectedActorIds) then
            self:snapBlueprintsPane(2)
            self:snapInspectorPane(1)
        else
            self:snapBlueprintsPane(1)
            self:snapInspectorPane(2)
        end

        if self._pausedView then
            -- Load paused view state
            self.viewX, self.viewY = self._pausedView.x, self._pausedView.y
            self.viewWidth = self._pausedView.width
            self._pausedView = nil
        end
    end

    self:clearNotify()

    Common.receivers.setPerforming(self, time, performing)
end

function Client:drawScene(opts)
    opts = opts or {}

    do -- Background
        if opts.boundary then
            love.graphics.clear(0.749, 0.773, 0.788)
            love.graphics.push('all')
            love.graphics.setColor(0.82, 0.749, 0.639)
            love.graphics.rectangle('fill',
                -0.5 * DEFAULT_VIEW_WIDTH, -0.5 * DEFAULT_VIEW_WIDTH,
                DEFAULT_VIEW_WIDTH, DEFAULT_VIEW_WIDTH * 16 / 9)
            love.graphics.pop()
        else
            love.graphics.clear(0.82, 0.749, 0.639)
        end
    end

    do -- Behaviors
        local drawBehaviors = self.behaviorsByHandler['drawComponent'] or {}
        self:forEachActorByDrawOrder(function(actor)
            for behaviorId, behavior in pairs(drawBehaviors) do
                local component = actor.components[behaviorId]
                if component then
                    behavior:callHandler('drawComponent', component)
                end
            end
        end)
    end
end

local screenshotWidth, screenshotHeight = 1350, 2400
local screenshotCanvas = love.graphics.newCanvas(screenshotWidth, screenshotHeight, {
    dpiscale = 1,
    msaa = 4,
})

function Client:saveScreenshot()
    screenshotCanvas:renderTo(function()
        love.graphics.push('all')

        love.graphics.origin()
        love.graphics.scale(screenshotWidth / DEFAULT_VIEW_WIDTH)
        love.graphics.translate(0, 0)
        love.graphics.translate(0.5 * DEFAULT_VIEW_WIDTH, 0.5 * DEFAULT_VIEW_WIDTH)

        self:drawScene()

        love.graphics.pop()
    end)
    local channel = love.thread.getChannel('SCENE_CREATOR_ENCODE_SCREENSHOT')
    channel:push(screenshotCanvas:newImageData())
    love.thread.originalNewThread([[
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
    ]]):start()
end

function Client:draw()
    local windowWidth, windowHeight = love.graphics.getDimensions()

    if not self.connected then -- Not connected?
        love.graphics.setFont(debugFont)
        love.graphics.setColor(0, 0, 0)
        local peer = self.client.getENetPeer()
        local text = peer and ('connection state: ' .. peer:state()) or 'trying to connect...'
        love.graphics.print(text, 16, windowHeight - debugFont:getHeight() - 16)
        return
    end

    love.graphics.push('all')

    do -- View transform
        -- NOTE(nikki): Not doing view-following, will add it back as a behavior...
        --if self.performing and next(self.selectedActorIds) then
        --    -- In perform mode, make view follow selected actor
        --    local actorId = next(self.selectedActorIds)
        --    local bodyId, body = self.behaviorsByName.Body:getBody(actorId)
        --    if body then
        --        local GUTTER = 2 * UNIT
        --        local x, y = body:getPosition()
        --        local viewHeight = self.viewWidth * windowHeight / windowWidth
        --        if x < self.viewX - 0.5 * self.viewWidth + GUTTER then
        --            self.viewX = x + 0.5 * self.viewWidth - GUTTER
        --        end
        --        if x > self.viewX + 0.5 * self.viewWidth - GUTTER then
        --            self.viewX = x - 0.5 * self.viewWidth + GUTTER
        --        end
        --        if y < self.viewY - 0.5 * self.viewWidth + GUTTER then
        --            self.viewY = y + 0.5 * self.viewWidth - GUTTER
        --        end
        --        if y > self.viewY + 0.5 * self.viewWidth - GUTTER then
        --            self.viewY = y - 0.5 * self.viewWidth + GUTTER
        --        end
        --    end
        --end

        self.viewTransform:reset()
        self.viewTransform:scale(windowWidth / self.viewWidth)
        self.viewTransform:translate(-self.viewX, -self.viewY)
        self.viewTransform:translate(0.5 * self.viewWidth, 0.5 * self.viewWidth)
        love.graphics.applyTransform(self.viewTransform)
    end

    self:drawScene({
        boundary = not self.performing,
    })

    do -- Overlays
        -- Boundary
        if not self.performing then
            love.graphics.setLineWidth(1.75 * self:getPixelScale())
            love.graphics.setColor(0.596, 0.631, 0.659)
            love.graphics.rectangle('line',
                -0.5 * DEFAULT_VIEW_WIDTH, -0.5 * DEFAULT_VIEW_WIDTH,
                DEFAULT_VIEW_WIDTH, DEFAULT_VIEW_WIDTH * 16 / 9)
        end

        -- All body outlines
        if not self.performing then
            love.graphics.setLineWidth(1.25 * self:getPixelScale())
            love.graphics.setColor(0.8, 0.8, 0.8, 0.8)
            for actorId, component in pairs(self.behaviorsByName.Body.components) do
                self.behaviorsByName.Body:drawBodyOutline(component)
            end
        end

        -- Selection outlines
        if not self.performing then
            local activeTool = self.activeToolBehaviorId and self.tools[self.activeToolBehaviorId]
            love.graphics.setLineWidth(2 * self:getPixelScale())
            love.graphics.setColor(0, 1, 0, 0.8)
            for actorId in pairs(self.selectedActorIds) do
                if self.behaviorsByName.Body:has(actorId) then
                    if activeTool then
                        local component = activeTool.components[actorId]
                        if component and self.clientId ~= component.clientId then
                            love.graphics.setColor(1, 0, 0, 0.8)
                        else
                            love.graphics.setColor(0, 1, 0, 0.8)
                        end
                    end
                    self.behaviorsByName.Body:drawBodyOutline(actorId)
                end
            end
        end

        -- Tool
        self:callHandlers('drawOverlay')
    end

    love.graphics.pop()

    do -- Screen-space overlay
        self:drawNotify()
    end

    if false then -- Debug overlay
        local networkText = ''
        if self.connected then
            networkText = networkText .. '    ping: ' .. self.client.getPing() .. 'ms'
            networkText = networkText .. '    mem: ' .. math.floor(collectgarbage('count')) .. 'kb'
        end

        love.graphics.setFont(debugFont)
        love.graphics.setColor(0, 0, 0)
        love.graphics.print('fps: ' .. love.timer.getFPS() .. networkText, 16, windowHeight - debugFont:getHeight() - 16)
    end
end

