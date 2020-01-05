-- 'multi' boilerplate
Game = require('multi.server', { root = true })
Common, Server, Client = Game.Common, Game.Server, Game.Client
require 'Common'


-- Utilities

local function unpackProperties(t)
    local rets, nArgs = {}, 0
    for k, v in pairs(t) do
        rets[nArgs + 1], rets[nArgs + 2] = k, v
        nArgs = nArgs + 2
    end
    return unpack(rets, 1, nArgs)
end


-- Start / stop

function Server:start()
    Common.start(self)
end


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

    -- Users
    for clientId, me in pairs(self.mes) do
        send('me', clientId, me)
    end

    -- Behaviors
    for behaviorId, behavior in pairs(self.behaviors) do
        if not CORE_BEHAVIORS[behaviorId] then
            send('addBehavior', self.clientId, behaviorId, behavior.behaviorSpec)
        end

        behavior:sendSetProperties({
            to = clientId,
            selfSend = false,
            channel = MAIN_RELIABLE_CHANNEL,
        }, unpackProperties(behavior.globals))
    end

    -- Notify `preSyncClient`
    for behaviorId, behavior in pairs(self.behaviors) do
        behavior:callHandler('preSyncClient', clientId)
    end

    -- Actors, components
    for actorId, actor in pairs(self.actors) do
        send('addActor', self.clientId, actorId)

        for behaviorId, component in pairs(actor.components) do
            send('addComponent', self.clientId, actorId, behaviorId)

            local behavior = self.behaviors[behaviorId]
            behavior:sendSetProperties({
                to = clientId,
                selfSend = false,
                channel = MAIN_RELIABLE_CHANNEL,
                actorId = actorId,
            }, unpackProperties(component.properties))
        end
    end

    -- Notify `postSyncClient`
    for behaviorId, behavior in pairs(self.behaviors) do
        behavior:callHandler('postSyncClient', clientId)
    end
end

function Server:connect(clientId)
    self:syncClient(clientId)

    local actorId = self:generateId()
    self:send('addActor', self.clientId, actorId)
    self:send('addComponent', self.clientId, actorId, self.behaviorsByName.Body.behaviorId)
    self:send('addComponent', self.clientId, actorId, self.behaviorsByName.Image.behaviorId)
end

function Server:reconnect(clientId)
    self:syncClient(clientId)
end

function Server:disconnect(clientId)
end


-- Update

function Server:update(dt)
    Common.update(self, dt)
end
