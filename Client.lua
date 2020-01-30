-- 'multi' boilerplate
--LOCAL_SERVER = true -- Enable to force a local server and never use a remote one
function GET_SERVER_MODULE_NAME()
    return 'Server'
end
Game = require('multi.client', { root = true })
Common, Server, Client = Game.Common, Game.Server, Game.Client
require 'Common'


-- Client modules

require 'select'
require 'touch'
require 'ui'


-- Start / stop

function Client:start()
    self.photoImages = {}

    self:startSelect()

    self:startTouch()

    self:startUi()

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


-- Update

function Client:update(dt)
    if not self.connected then
        return
    end

    self:updateTouches()

    self:updatePerformance(dt)
    self:applySelections() -- Performance may have added or removed actors or components, so apply changes

    self:callHandlers('preUpdate', dt)

    self:touchToSelect() -- Do this after `preUpdate` to allow tools to steal touches first

    self:callHandlers('update', dt)
    self:callHandlers('postUpdate', dt)
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
    if not self.performing and performing then
        -- Save paused view state and reset view size
        self._pausedView = {
            x = self.viewX,
            y = self.viewY,
            width = self.viewWidth,
        }
        self:resetViewSize()
    end

    if self.performing and not performing and self._pausedView then
        -- Load paused view state
        self.viewX, self.viewY = self._pausedView.x, self._pausedView.y
        self.viewWidth = self._pausedView.width
        self._pausedView = nil
    end

    Common.receivers.setPerforming(self, time, performing)
end

function Client:draw()
    local windowWidth, windowHeight = love.graphics.getDimensions()

    do -- Background color
        love.graphics.clear(1, 0.98, 0.98)
    end

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
        if self.performing and next(self.selectedActorIds) then
            -- In perform mode, make view follow selected actor
            local actorId = next(self.selectedActorIds)
            local bodyId, body = self.behaviorsByName.Body:getBody(actorId)
            if body then
                local GUTTER = 2 * UNIT
                local x, y = body:getPosition()
                local viewHeight = self.viewWidth * windowHeight / windowWidth
                if x < self.viewX - 0.5 * self.viewWidth + GUTTER then
                    self.viewX = x + 0.5 * self.viewWidth - GUTTER
                end
                if x > self.viewX + 0.5 * self.viewWidth - GUTTER then
                    self.viewX = x - 0.5 * self.viewWidth + GUTTER
                end
                if y < self.viewY - 0.5 * self.viewWidth + GUTTER then
                    self.viewY = y + 0.5 * self.viewWidth - GUTTER
                end
                if y > self.viewY + 0.5 * self.viewWidth - GUTTER then
                    self.viewY = y - 0.5 * self.viewWidth + GUTTER
                end
            end
        end

        self.viewTransform:reset()
        self.viewTransform:scale(windowWidth / self.viewWidth)
        self.viewTransform:translate(-self.viewX, -self.viewY)
        self.viewTransform:translate(0.5 * self.viewWidth, 0.5 * self.viewWidth)
        love.graphics.applyTransform(self.viewTransform)
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

    do -- Overlays
        local activeTool = self.activeToolBehaviorId and self.tools[self.activeToolBehaviorId]

        -- All body outlines (if not performing)
        love.graphics.setLineWidth(1.25 * self:getPixelScale())
        love.graphics.setColor(0.8, 0.8, 0.8, 0.8)
        if not self.performing then
            for actorId, component in pairs(self.behaviorsByName.Body.components) do
                self.behaviorsByName.Body:drawBodyOutline(component)
            end
        end

        -- Selection outlines
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

        -- Tool
        if activeTool then
            love.graphics.setColor(0, 1, 0, 0.8)
            activeTool:callHandler('drawOverlay')
        end
    end

    love.graphics.pop()

    do -- Debug overlay
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

