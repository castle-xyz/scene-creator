jsEvents = require "__ghost__.jsEvents"
require('profiler')

-- Initial params

DEBUG_PHYSICS_BODIES = false

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
require "sound"
require "ui"
require "notify"
require "screenshot"
require "capture"

-- Start / stop

local isEditing
local isEditable
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

local function buildEditInstance(snapshot, variables, isNewScene)
   editInstance = Client:_new()
   editInstance:load(true, snapshot, variables, isNewScene)

   local tempSnapshot = editInstance:createSnapshot()
   editInstance:setLastSuccessfulSaveSnapshot(tempSnapshot)
end

local function buildPlayInstance(snapshot, variables)
   playInstance = Client:_new()
   playInstance:load(false, snapshot, variables, false)
end

function love.load()
    sentGameLoadedEvent = false

    local initialParams = castle.game.getInitialParams()
    local scene = initialParams.scene
    local deckState = scene.deckState or {}
    local variables = deckState.variables or {}
    local snapshot = nil
    local isNewScene = false

    if scene and scene.data then
        if scene.data.snapshot then
            snapshot = scene.data.snapshot
        end

        if scene.data.empty then
            isNewScene = true
        end
    end

    currentSnapshot = snapshot
    currentVariables = variables

    if initialParams.isDebug then
        DEBUG = true
    else
        DEBUG = false
    end

    if initialParams.isEditable then
        isEditable = true
    else
        isEditable = false
    end

    if initialParams.isEditing then
        isEditing = true
        buildEditInstance(snapshot, variables, isNewScene)
    else
        isEditing = false
        buildPlayInstance(snapshot, variables)
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
    if playInstance ~= nil then
        playInstance:send("clearScene")
    end
    playInstance = nil

    if editInstance == nil then
       buildEditInstance(currentSnapshot, currentVariables, false)
    end
end

function endEditing()
    if not isEditing then
        return
    end

    currentSnapshot = editInstance:createSnapshot()
    editInstance:saveScene(currentSnapshot)

    buildPlayInstance(currentSnapshot, currentVariables)
    isEditing = false
end

function Client:load(isEditing, snapshot, variables, isNewScene)
    self.clientId = 0
    self.isEditable = isEditable
    self.isNewScene = isNewScene

    -- body component uses performing to determine collision shapes
    self:start(not isEditing)

    --self.photoImages = {}

    self:startSelect()

    self:startTouch()

    self:startUi()

    self:startNotify()
    self:startBelt()

    self:resetView()
    self.viewTransform = love.math.newTransform()
    self.cameraTransform = love.math.newTransform()

    if snapshot then
        self:restoreSnapshot(snapshot)
    end

    self:send("setPerforming", not isEditing)
    self:send("updateVariables", variables)
end

function castle.uiupdate(...)
    local varArgs = {...}

    return profileFunction('castle.uiupdate', function()
        currentInstance():uiupdate(unpack(varArgs))
    end)
end

-- Begin / end editing

function Common:restartScene()
    self:send("setPaused", true)
    self:startCamera()
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

jsEvents.listen(
    "REQUEST_SCREENSHOT",
    function(params)
        local self = editInstance
        if self then
            local screenshotData = self:getScreenshotData()
            jsEvents.send(
                "GHOST_MESSAGE",
                {
                    messageType = "SCREENSHOT_DATA",
                    data = screenshotData
                }
            )
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
    profileFunction('love.update', function()
        currentInstance():update(dt)
    end)
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

    self:updateBelt(dt) -- Early to allow belt to steal touches

    self:callHandlers("preUpdate", dt)

    if not self.performing and not self:isActiveToolFullscreen() then
        self:touchToSelect() -- Do these after `preUpdate` to allow tools to steal touches first
        self:twoFingerPan()
    end

    if self.performing then
       self:touchToShowHints()
    end
    
    self:callHandlers("update", dt)
    self:callHandlers("postUpdate", dt)

    self:fireOnEndOfFrame()
    self:performCapture(dt)

    self:updateNotify(dt)
    self:updateCamera(dt)

    self:updateAutoSaveScene()
    self:sendVariableUpdate()

    if REQUEST_EDIT_STATUS_CHANGE and EDIT_LOCK == 0 then
        if REQUEST_EDIT_STATUS_CHANGE == "begin" then
            self:BEGIN_EDITING_WITH_LOCK()
        elseif REQUEST_EDIT_STATUS_CHANGE == "end" then
            self:END_EDITING_WITH_LOCK()
        end

        REQUEST_EDIT_STATUS_CHANGE = nil
    end

    profilerUpdate(dt)
end

-- Draw

local debugFont = love.graphics.newFont(14)

function Client:resetViewPosition()
    self.viewX, self.viewY = 0, 0
end

function Client:resetViewSize()
    self.viewWidth = DEFAULT_VIEW_WIDTH
end

function Client:getZoomAmount()
    return self.viewWidth / DEFAULT_VIEW_WIDTH
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
    if performing then
       self:buildSoundPool()
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

    profileFunction('drawScene.background', function()
        do -- Background
            local bgColor = self.sceneProperties.backgroundColor
            if opts.boundary then
                love.graphics.clear(0.8, 0.8, 0.8)
                love.graphics.push("all")
                love.graphics.setColor(bgColor.r, bgColor.g, bgColor.b)

                love.graphics.rectangle(
                    "fill",
                    -0.5 * DEFAULT_VIEW_WIDTH,
                    -self:getDefaultYOffset(),
                    DEFAULT_VIEW_WIDTH,
                    DEFAULT_VIEW_WIDTH * VIEW_HEIGHT_TO_WIDTH_RATIO
                )
                love.graphics.pop()
            else
                love.graphics.clear(bgColor.r, bgColor.g, bgColor.b)
            end
        end
    end)

    profileFunction('drawScene.behaviors', function()
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
    end)


    profileFunction('drawScene.hintOverlay', function()
        do -- Hint overlay
        self:drawNoTouchesHintOverlay()
        end
    end)
end

function love.draw()
    profileFunction('love.draw', function()
        currentInstance():draw()
    end)
end

function Client:drawInner()
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

            local cameraX, cameraY = self:getCameraPosition()
            self.cameraTransform:reset()
            self.cameraTransform:translate(-cameraX, -cameraY)

            self.viewTransform:reset()
            self.viewTransform:scale(windowWidth / self.viewWidth)
            self.viewTransform:translate(-self.viewX, -self.viewY)
            self.viewTransform:translate(0.5 * self.viewWidth, self:getYOffset())
            love.graphics.applyTransform(self.viewTransform)
            love.graphics.applyTransform(self.cameraTransform)
        end


        profileFunction('draw.drawScene', function()
            self:drawScene(
                {
                    boundary = not self.performing
                }
            )
        end)
    else
        self.viewTransform:reset()
    end

    do -- Overlays

        if not self.beltHighlightEnabled and not self:isActiveToolFullscreen() then
            -- Boundary
            if not self.performing then
                love.graphics.setLineWidth(1.75 * self:getPixelScale())
                love.graphics.setColor(0.596, 0.631, 0.659)
                love.graphics.rectangle(
                    "line",
                    -0.5 * DEFAULT_VIEW_WIDTH,
                    -self:getDefaultYOffset(),
                    DEFAULT_VIEW_WIDTH,
                    DEFAULT_VIEW_WIDTH * VIEW_HEIGHT_TO_WIDTH_RATIO
                )
            end

            if not self.performing then
                local activeTool = self.activeToolBehaviorId and self.tools[self.activeToolBehaviorId]

                if not activeTool or not activeTool.tool or not activeTool.tool.hideBodyOutline then
                    -- All body outlines
                    love.graphics.setLineWidth(1.25 * self:getPixelScale())
                    love.graphics.setColor(0.8, 0.8, 0.8, 0.8)
                    for actorId, component in pairs(self.behaviorsByName.Body.components) do
                        if not self.actors[actorId].isGhost then
                            self.behaviorsByName.Body:drawBodyOutline(component)
                        end
                    end

                    -- Selection outlines
                    love.graphics.setLineWidth(2 * self:getPixelScale())
                    love.graphics.setColor(0, 1, 0, 0.8)
                    for actorId in pairs(self.selectedActorIds) do
                        if not self.actors[actorId].isGhost and self.behaviorsByName.Body:has(actorId) then
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
        end

        -- Tool
        self:callHandlers("drawOverlay")
    end

    if DEBUG_PHYSICS_BODIES and not self:isActiveToolFullscreen() then -- Physics bodies
        local physics = self.behaviorsByName.Body:getPhysics()

        for _, layerName in pairs(self.behaviorsByName.Body:getLayerNames()) do
            local worldId, world = self.behaviorsByName.Body:getWorld(layerName)
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
                            local x, y = body:getWorldPoints(shape:getPoint())
                            love.graphics.circle("line", x, y, shape:getRadius())
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
    end

    love.graphics.pop()

    -- Screen-space edit overlays
    if not self.performing then
        self:drawBeltHighlight()

        self:drawNotify()
    end

    if DEBUG then -- Debug overlay
        local networkText = ""
        if self.connected then
            networkText = networkText .. "    ping: " .. self.client.getPing() .. "ms"
            networkText = networkText .. "    mem: " .. math.floor(collectgarbage("count")) .. "kb"
        end

        love.graphics.push("all")
        love.graphics.setFont(debugFont)
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("fill", windowWidth - 110, 0, 110, 50)
        love.graphics.setColor(0, 0, 0)
        love.graphics.print(
            "fps: " .. love.timer.getFPS() .. networkText,
            windowWidth - 100,
            16
        )
        love.graphics.pop()
    end

    if not sentGameLoadedEvent then
        sentGameLoadedEvent = true

        jsEvents.send("SCENE_CREATOR_GAME_LOADED", {})
    end
end

function Client:draw()
    local activeTool = self.activeToolBehaviorId and self.tools[self.activeToolBehaviorId]
    local hideBelt = activeTool and activeTool.tool and activeTool.tool.hideBelt
    if not hideBelt and self.isEditable then
        local windowWidth, windowHeight = love.graphics.getDimensions()
        local cardWidth, cardHeight = windowWidth, windowHeight - BELT_HEIGHT

        -- Draw to a canvas then render that canvas with a Y offset, to leave space for the belt above
        if not self.innerCanvas then
            self.innerCanvas = love.graphics.newCanvas(cardWidth, cardHeight)
        end
        self.innerCanvas:renderTo(function()
            self:drawInner()
        end)
        love.graphics.draw(self.innerCanvas, 0, self:getBeltYOffset())

        -- Rounded corners
        love.graphics.push("all")
        love.graphics.setColor(1, 1, 1)
        if not self.roundedCornersCanvas then
            self.roundedCornersCanvas = love.graphics.newCanvas(cardWidth, cardHeight)
            self.roundedCornersCanvas:renderTo(function()
                love.graphics.clear(0, 0, 0, 1)
                local br = 18 * love.graphics.getDPIScale()
                love.graphics.rectangle('fill', 0, 0, cardWidth, cardHeight, br)
            end)
        end
        love.graphics.setBlendMode("multiply", "premultiplied")
        love.graphics.draw(self.roundedCornersCanvas, 0, self:getBeltYOffset())
        love.graphics.pop()

        self:drawBelt()
    else
        self:drawInner()
    end
end
