-- 'multi' boilerplate
Game = require('multi.server', { root = true })
Common, Server, Client = Game.Common, Game.Server, Game.Client
require 'Common'


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
            send('addBehavior', behaviorId, behavior.behaviorSpec)
        end

        local args, nArgs = {}, 0
        for name, value in pairs(behavior.globals) do
            args[nArgs + 1], args[nArgs + 2] = name, value
            nArgs = nArgs + 2
        end
        behavior:setProperties({
            to = clientId,
            selfSend = false,
            channel = MAIN_RELIABLE_CHANNEL,
        }, unpack(args, 1, nArgs))
    end

    -- Notify `preSyncClient`
    for behaviorId, behavior in pairs(self.behaviors) do
        if behavior.handlers.preSyncClient then
            behavior.handlers.preSyncClient(behavior, clientId)
        end
    end

    -- Actors
    for actorId in pairs(self.actors) do
        send('addActor', actorId)
    end

    -- Components
    for actorId, behaviorComponent in pairs(self.actors) do
        for behaviorId, component in pairs(behaviorComponent) do
            local behavior = self.behaviors[behaviorId]
            send('addComponent', actorId, behaviorId)

            local args, nArgs = {}, 0
            for name, value in pairs(component.properties) do
                args[nArgs + 1], args[nArgs + 2] = name, value
                nArgs = nArgs + 2
            end
            behavior:setProperties({
                to = clientId,
                selfSend = false,
                channel = MAIN_RELIABLE_CHANNEL,
                actorId = actorId,
            }, unpack(args, 1, nArgs))
        end
    end

    -- Notify `postSyncClient`
    for behaviorId, behavior in pairs(self.behaviors) do
        if behavior.handlers.postSyncClient then
            behavior.handlers.postSyncClient(behavior, send, clientId)
        end
    end
end

function Server:connect(clientId)
    self:syncClient(clientId)
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
