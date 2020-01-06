-- 'multi' boilerplate
function GET_SERVER_MODULE_NAME()
    return 'Server'
end
Game = require('multi.client', { root = true })
Common, Server, Client = Game.Common, Game.Server, Game.Client
require 'Common'


-- Start / stop

function Client:start()
    Common.start(self)

    self.photoImages = {}
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
    -- Not connected?
    if not self.connected then
        return
    end

    -- Common update
    Common.update(self, dt)
end


-- Draw

function Client:draw()
    do -- Behaviors
        local order = {}
        self:callHandlers('draw', order)
        table.sort(order, function(o1, o2)
            return o1.depth < o2.depth
        end)
        for _, o in ipairs(order) do
            o.draw()
        end
    end

    do -- Debug overlay
        local networkText = ''
        if self.connected then
            networkText = networkText .. '    ping: ' .. self.client.getPing() .. 'ms'
            networkText = networkText .. '    mem: ' .. math.floor(collectgarbage('count')) .. 'kb'
        end

        love.graphics.setColor(1, 1, 1)
        love.graphics.print('fps: ' .. love.timer.getFPS() .. networkText, 22, 2)
    end
end


-- Mouse

function Client:mousepressed(x, y, button)
    if button == 1 then
        local removedSomething = false

        self.behaviorsByName.Body:getWorld():queryBoundingBox(
            x - 1, y - 1, x + 1, y + 1,
            function(fixture)
                if fixture:testPoint(x, y) then
                    local actorId = self.behaviorsByName.Body:getActorForBody(fixture:getBody())
                    if actorId then
                        self:send('removeActor', self.clientId, actorId)
                        removedSomething = true
                        return false
                    end
                end
                return true
            end)

        if not removedSomething then
            local actorId = self:generateId()
            self:send('addActor', self.clientId, actorId)
            self:send('addComponent', self.clientId, actorId, self.behaviorsByName.Body.behaviorId, {
                x = x,
                y = y,
                fixture = {
                    shapeType = 'polygon',
                    points = { -32, -32, -32, 32, 32, 32, 32, -32 },
                },
            })
        end
    end
end


-- UI

local ui = castle.ui

function Client:uiupdate()
    if false then -- UI for disconnection testing
        if self.connected then
            ui.markdown("You are connected! Click 'kick' to disconnect yourself.")
            if ui.button('kick') then
                self:kick()
            end
        elseif not self.connected and self.clientId then
            ui.markdown("You are disconnected. Click 'retry' to try reconnecting.")
            if ui.button('retry') then
                self:retry()
            end
        end
        ui.markdown("Auto-retry automatically retries connecting if a disconnection is noticed.")
        self.autoRetry = ui.toggle('auto-retry disabled', 'auto-retry enabled', self.autoRetry)
    end
end
