-- 'multi' boilerplate
Game = require('multi.server', { root = true })
Common, Server, Client = Game.Common, Game.Server, Game.Client
require 'Common'


-- Connect / reconnect / disconnect

function Server:syncClient(clientId)
    -- Perform a full synchronization for a new or reconnecting client

    local function send(kind, ...) -- Shorthand to send messages to this client only
        self:send({
            kind = kind,
            to = clientId,
            selfSend = false,
            channel = MAIN_RELIABLE_CHANNEL,
        }, ...)
    end

    for clientId, me in pairs(self.mes) do
        send('me', clientId, me)
    end

    self:syncClientLibrary(clientId, send)

    self:syncClientActorBehavior(clientId, send)

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
