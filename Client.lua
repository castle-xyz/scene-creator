-- 'multi' boilerplate
LOCAL_SERVER = true -- Enable to force a local server and never use a remote one
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
    Common.start(self)

    self.photoImages = {}

    self:startSelect()

    self:startTouch()

    self:startUi()
end


-- Connect / reconnect / disconnect

function Client:connect()
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

    self:preUpdateSelect()

    Common.update(self, dt)

    self:postUpdateTouch()
end


-- Draw

local debugFont = love.graphics.newFont(14)

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

    do -- Behaviors
        local order = {}
        self:callHandlers('draw', order)
        table.sort(order, function(o1, o2)
            if o1.depth < o2.depth then
                return true
            end
            if o1.depth > o2.depth then
                return false
            end
            return o1.id < o2.id
        end)
        for _, o in ipairs(order) do
            o.draw()
        end
    end

    do -- Selections
        love.graphics.setColor(0, 1, 0)
        love.graphics.setLineWidth(1.5 * love.graphics.getDPIScale())
        local activeTool = self.activeToolBehaviorId and self.tools[self.activeToolBehaviorId]
        for actorId in pairs(self.selectedActorIds) do
            if self.behaviorsByName.Body:has(actorId) then
                if activeTool then
                    local component = activeTool.components[actorId]
                    if component and self.clientId ~= component.clientId then
                        love.graphics.setColor(1, 0, 0)
                    else
                        love.graphics.setColor(0, 1, 0)
                    end
                end
                self.behaviorsByName.Body:drawBodyOutline(actorId)
            end
        end
    end

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

