jsEvents = require "__ghost__.jsEvents"

-- Initial params

NEW_DRAW_TOOL = false
SHOW_TEXT_ACTORS = true
DEBUG_FLOOD_FILL = false

function castle.onQuit()
end

Common = {}
Common.receivers = {}
Client =
    setmetatable(
    {
        receivers = setmetatable({}, {__index = Common.receivers})
    },
    {__index = Common}
)

require "Common"

-- Client modules

require "select"
require "touch"
require "ui"
require "notify"

-- Start / stop

local isEditing
local playInstance
local editInstance
local currentSnapshot
local currentVariables
local sentGameLoadedEvent

function Client:_new()
    local result = setmetatable({}, {__index = self})
    result.receivers = setmetatable({}, {__index = Client.receivers})
    return result
end

function love.load()
    sentGameLoadedEvent = false

    local initialParams = castle.game.getInitialParams()
    local scene = initialParams.scene
    local deckState = scene.deckState or {}
    local variables = deckState.variables or {}
    local snapshot = nil

    if scene and scene.data and scene.data.snapshot then
        snapshot = scene.data.snapshot
    end

    currentSnapshot = snapshot
    currentVariables = variables

    if initialParams.isEditing then
        isEditing = true
        editInstance = Client:_new()
        editInstance:load(true, snapshot, variables)

        local tempSnapshot = editInstance:createSnapshot()
        editInstance:setLastSuccessfulSaveSnapshot(tempSnapshot)
    else
        isEditing = false
        playInstance = Client:_new()
        playInstance:load(false, snapshot, variables)
    end
end

function currentInstance()
    if isEditing then
        return editInstance
    else
        return playInstance
    end
end

function beginEditing()
    if isEditing then
        return
    end

    isEditing = true
    playInstance = nil
end

function endEditing()
    if not isEditing then
        return
    end

    currentSnapshot = editInstance:createSnapshot()
    editInstance:saveScene(currentSnapshot)
    editInstance:saveScreenshot()

    playInstance = Client:_new()
    playInstance:load(false, currentSnapshot, currentVariables)
    isEditing = false
end

function Client:load(isEditing, snapshot, variables)
    self.clientId = 0
    self:start()

    --self.photoImages = {}

    self:startSelect()

    self:startTouch()

    self:startUi()

    self:startNotify()

    self:resetView()
    self.viewTransform = love.math.newTransform()

    if isEditing then
        self:send("setPerforming", false)
    end

    self:send("updateVariables", variables)

    if snapshot then
        self:restoreSnapshot(snapshot)
    end
end

function castle.uiupdate(...)
    currentInstance():uiupdate(...)
end

-- Begin / end editing

function Common:restartScene()
    self:send("setPaused", true)
    self:restoreSnapshot(currentSnapshot)
    self:send("setPaused", false)
end

-- JS Events

-- Connect / reconnect / disconnect

--[[function Client:connect()
    Common.start(self)

    -- Send `me`
    local me = castle.user.getMe()
    self:send("me", self.clientId, me)
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
    -- unused for now
    --[[
    local photoUrl = self.mes[clientId].photoUrl
    if photoUrl then
        network.async(
            function()
                self.photoImages[clientId] = love.graphics.newImage(photoUrl)
            end
        )
    end
    ] ]
    --
end
]]
jsEvents.listen(
    "SCENE_CREATOR_EDITING",
    function(params)
        if params.isEditing then
            beginEditing()
        else
            endEditing()
        end
    end
)

jsEvents.listen(
    "SELECT_ACTOR",
    function(params)
        local self = currentInstance()
        if self then
            if self.performing then
                -- playing scene, fire 'tap' if applicable
                local textBehavior = self.behaviorsByName.Text
                if textBehavior:has(params.actorId) then
                    -- NOTE: could also do something like
                    -- component.jsSelected = true
                    -- and check inside TextBehavior.handlers:prePerform() on next step.
                    textBehavior:fireTrigger("tap", params.actorId)
                end
            else
                -- editing scene, select actor
                self:deselectAllActors()
                if params.actorId ~= nil then
                    self:selectActor(params.actorId)
                    self:applySelections()
                end
            end
        end
    end
)

jsEvents.listen(
    "UPDATE_DECK_STATE",
    function(params)
        local deckState = params.deckState or {}
        local variables = deckState.variables or {}
        currentVariables = variables

        local self = editInstance
        if self then
            self:send("updateVariables", variables)
        end
    end
)

jsEvents.listen(
    "LOAD_SNAPSHOT",
    function(params)
        local self = editInstance
        if self then
            local tempSnapshot = self:createSnapshot()
            self:saveScene(tempSnapshot)

            if params.data and params.data.snapshot then
                self:restoreSnapshot(params.data.snapshot)
            else
                self:restoreSnapshot(nil)
            end
        end
    end
)

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
        local initialPX, initialPY =
            touch1.initialScreenX - touch2.initialScreenX,
            touch1.initialScreenY - touch2.initialScreenY
        local initialPL = math.sqrt(initialPX * initialPX + initialPY * initialPY)
        if
            (touch1.zooming or touch2.zooming or
                not (self.viewWidth == DEFAULT_VIEW_WIDTH and math.abs(initialPL - pl) <= 0.175 * initialPL))
         then
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

function love.update(dt)
    currentInstance():update(dt)
end

function Client:update(dt)
    local currTime = love.timer.getTime()
    --if not self.lastPingSentTime or currTime - self.lastPingSentTime > 2 then
    --    self.lastPingSentTime = currTime
    --    self:send("ping", self.clientId)
    --end

    self:updateTouches()

    self:updatePerformance(dt)
    self:applySelections() -- Performance may have added or removed actors or components, so apply changes

    self:callHandlers("preUpdate", dt)

    if not self.performing and not self:isActiveToolFullscreen() then
        self:touchToSelect() -- Do these after `preUpdate` to allow tools to steal touches first
        self:twoFingerPan()
    end

    self:callHandlers("update", dt)
    self:callHandlers("postUpdate", dt)

    self:fireOnEndOfFrame()

    self:updateNotify(dt)

    self:updateAutoSaveScene()

    if REQUEST_EDIT_STATUS_CHANGE and EDIT_LOCK == 0 then
        if REQUEST_EDIT_STATUS_CHANGE == "begin" then
            self:BEGIN_EDITING_WITH_LOCK()
        elseif REQUEST_EDIT_STATUS_CHANGE == "end" then
            self:END_EDITING_WITH_LOCK()
        end

        REQUEST_EDIT_STATUS_CHANGE = nil
    end
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
            width = self.viewWidth
        }
        self:resetView()
    end

    -- Exiting perform?
    if self.performing and not performing then
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
            love.graphics.push("all")
            love.graphics.setColor(0.82, 0.749, 0.639)
            love.graphics.rectangle(
                "fill",
                -0.5 * DEFAULT_VIEW_WIDTH,
                -0.5 * DEFAULT_VIEW_WIDTH,
                DEFAULT_VIEW_WIDTH,
                DEFAULT_VIEW_WIDTH * VIEW_HEIGHT_TO_WIDTH_RATIO
            )
            love.graphics.pop()
        else
            love.graphics.clear(0.82, 0.749, 0.639)
        end
    end

    do -- Behaviors
        local drawBehaviors = self.behaviorsByHandler["drawComponent"] or {}
        self:forEachActorByDrawOrder(
            function(actor)
                for behaviorId, behavior in pairs(drawBehaviors) do
                    local component = actor.components[behaviorId]
                    if component then
                        behavior:callHandler("drawComponent", component)
                    end
                end
            end
        )
    end
end

function Client:saveScreenshot()
    local screenshotWidth = 1350

    local screenshotCanvas =
        love.graphics.newCanvas(
        screenshotWidth,
        screenshotWidth * VIEW_HEIGHT_TO_WIDTH_RATIO,
        {
            dpiscale = 1,
            msaa = 4
        }
    )

    screenshotCanvas:renderTo(
        function()
            love.graphics.push("all")

            love.graphics.origin()
            love.graphics.scale(screenshotWidth / DEFAULT_VIEW_WIDTH)
            love.graphics.translate(0, 0)
            love.graphics.translate(0.5 * DEFAULT_VIEW_WIDTH, 0.5 * DEFAULT_VIEW_WIDTH)

            self:drawScene()

            love.graphics.pop()
        end
    )
    local channel = love.thread.getChannel("SCENE_CREATOR_ENCODE_SCREENSHOT")
    channel:push(screenshotCanvas:newImageData())
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

function love.draw()
    currentInstance():draw()
end

function Client:draw()
    local windowWidth, windowHeight = love.graphics.getDimensions()

    --if not self.connected then -- Not connected?
    --    love.graphics.setFont(debugFont)
    --    love.graphics.setColor(0, 0, 0)
    --    local peer = self.client.getENetPeer()
    --    local text = peer and ("connection state: " .. peer:state()) or "trying to connect..."
    --    love.graphics.print(text, 16, windowHeight - debugFont:getHeight() - 16)
    --    return
    --end

    love.graphics.push("all")


    if not self:isActiveToolFullscreen() then
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

        self:drawScene(
            {
                boundary = not self.performing
            }
        )
    else
        self.viewTransform:reset()
        self.viewTransform:scale(windowWidth / DEFAULT_VIEW_WIDTH)
        love.graphics.applyTransform(self.viewTransform)
    end

    do -- Overlays

        if not self:isActiveToolFullscreen() then
            -- Boundary
            if not self.performing then
                love.graphics.setLineWidth(1.75 * self:getPixelScale())
                love.graphics.setColor(0.596, 0.631, 0.659)
                love.graphics.rectangle(
                    "line",
                    -0.5 * DEFAULT_VIEW_WIDTH,
                    -0.5 * DEFAULT_VIEW_WIDTH,
                    DEFAULT_VIEW_WIDTH,
                    DEFAULT_VIEW_WIDTH * VIEW_HEIGHT_TO_WIDTH_RATIO
                )
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
        end

        -- Tool
        self:callHandlers("drawOverlay")
    end

    if false then -- Physics bodies
        local physics = self.behaviorsByName.Body:getPhysics()
        local worldId, world = physics:getWorld()
        if world then
            love.graphics.setLineWidth(5 * self:getPixelScale())
            for _, body in ipairs(world:getBodies()) do
                local bodyId = physics:idForObject(body)
                local ownerId = physics:getOwner(bodyId)
                if ownerId then
                    local c = ownerId + 1
                    love.graphics.setColor(c % 2, math.floor(c / 2) % 2, math.floor(c / 4) % 2)
                else
                    love.graphics.setColor(1, 1, 1)
                end

                -- Draw shapes
                for _, fixture in ipairs(body:getFixtures()) do
                    local shape = fixture:getShape()
                    local ty = shape:getType()
                    if ty == "circle" then
                        love.graphics.circle("line", body:getX(), body:getY(), shape:getRadius())
                    elseif ty == "polygon" then
                        love.graphics.polygon("line", body:getWorldPoints(shape:getPoints()))
                    elseif ty == "edge" then
                        love.graphics.polygon("line", body:getWorldPoints(shape:getPoints()))
                    elseif ty == "chain" then
                        love.graphics.polygon("line", body:getWorldPoints(shape:getPoints()))
                    end
                end
            end
        end
    end

    love.graphics.pop()

    do -- Screen-space overlay
        self:drawNotify()
    end

    if false then -- Debug overlay
        local networkText = ""
        if self.connected then
            networkText = networkText .. "    ping: " .. self.client.getPing() .. "ms"
            networkText = networkText .. "    mem: " .. math.floor(collectgarbage("count")) .. "kb"
        end

        love.graphics.setFont(debugFont)
        love.graphics.setColor(0, 0, 0)
        love.graphics.print(
            "fps: " .. love.timer.getFPS() .. networkText,
            16,
            windowHeight - debugFont:getHeight() - 16
        )
    end

    if not sentGameLoadedEvent then
        sentGameLoadedEvent = true

        jsEvents.send("SCENE_CREATOR_GAME_LOADED", {})
    end
end

