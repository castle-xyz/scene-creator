-- 'multi' boilerplate
Game = require('multi.server', { root = true })
Common, Server, Client = Game.Common, Game.Server, Game.Client
require 'Common'


-- Start / stop

function Server:start()
    Common.start(self)

    self.rewindSnapshot = nil
end


-- Connect / reconnect / disconnect

function Server:syncClient(clientId)
    -- Perform a full synchronization for a new or reconnecting client

    local function send(kind, ...) -- Shorthand to send messages to this client only
        self:send({
            kind = kind,
            to = clientId,
            selfSend = false,
            channel = self.channels.mainReliable,
        }, ...)
    end

    for clientId, me in pairs(self.mes) do
        send('me', clientId, me)
    end

    self:syncClientLibrary(clientId, send)

    self:syncClientActorBehavior(clientId, send)

    self:syncClientSnapshot(clientId, send)

    send('setPerforming', self.performing)
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


-- Performance

function Server.receivers:setPerforming(time, performing)
    if not self.performing and performing then
        -- About to start performing, save a rewind snapshot
    end

    Common.receivers.setPerforming(self, time, performing)

    if self.performing ~= performing then
        self.performing = performing
        self:callHandlers('setPerforming', performing)
    end
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
