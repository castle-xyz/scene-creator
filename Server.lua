-- 'multi' boilerplate
Game = require('multi.server', { root = true })
Common, Server, Client = Game.Common, Game.Server, Game.Client
require 'Common'


-- Connect / reconnect / disconnect

function Server:syncClient(clientId)
    -- Perform a full synchronization for a new or reconnecting client

    local function send(kind, ...)
        self:send(kind, ...)
    end

    self:transact({
        to = clientId,
        reliable = true,
        selfSend = false,
        channel = self.channels.mainReliable,
    }, function()
        for clientId, me in pairs(self.mes) do
            send('me', clientId, me)
        end
        for clientId, lastPingTime in pairs(self.lastPingTimes) do
            send({ time = lastPingTime, kind = 'ping' }, clientId)
        end

        self:syncClientLibrary(clientId, send)

        self:syncClientActorBehavior(clientId, send)

        self:syncClientSnapshot(clientId, send)

        send('setPerforming', self.performing)

        send('ready')
    end)
end

function Server:connect(clientId)
    self:syncClient(clientId)
end

function Server:reconnect(clientId)
    self:syncClient(clientId)
end

function Server:disconnect(clientId)
    self:disconnectActorBehavior(clientId)
end


-- Update

function Server:update(dt)
    -- Server doesn't have tools so this is simple...

    self:updatePerformance(dt)

    self:callHandlers('preUpdate', dt)
    self:callHandlers('update', dt)
    self:callHandlers('postUpdate', dt)

    self:forEachActorByDrawOrder() -- Keeps draw order dense
end
