-- 'multi' boilerplate
Game = require('multi.server', { root = true })
Common, Server, Client = Game.Common, Game.Server, Game.Client
require 'Common'


-- Core library

local CORE_LIBRARY = {
    {
        entryType = 'actorBlueprint',
        title = 'dog',
        description = 'A canine friend that falls and rolls around!',
        actorBlueprint = {
            Image = {
                url = 'https://art.pixilart.com/5d29768f5c3f448.png',
                width = 300,
                height = 300,
            },
            Body = {
                fixture = {
                    shapeType = 'polygon',
                    points = {
                        -80, -100,
                        -80, 60,
                        60, 60,
                        60, -100,
                    },
                },
                bodyType = 'dynamic',
                gravityScale = 1,
            },
        },
    },
    {
        entryType = 'actorBlueprint',
        title = 'ice platform',
        description = 'Something to stand on...',
        actorBlueprint = {
            Image = {
                url = 'http://www.photonstorm.com/wp-content/uploads/2015/01/ice-platform.png',
                width = 384,
                height = 96,
            },
            Body = {
                fixture = {
                    shapeType = 'polygon',
                    points = {
                        -192, -48,
                        -192, 48,
                        192, 48,
                        192, -48,
                    },
                },
                bodyType = 'static',
            },
        },
    },
}


-- Start / stop

function Server:start()
    Common.start(self)
end


-- Connect / reconnect / disconnect

function Server:start()
    Common.start(self)


    -- Library

    for _, entrySpec in pairs(CORE_LIBRARY) do
        local entryId = self:generateId()
        local entry = util.deepCopyTable(entrySpec)
        entry.entryId = entryId
        self.library[entryId] = entry
    end
end

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


    -- Library

    for entryId, entry in pairs(self.library) do
        send('addLibraryEntry', entryId, entry)
    end


    -- Actors / behaviors

    for behaviorId, behavior in pairs(self.behaviors) do
        if not CORE_BEHAVIORS[behaviorId] then
            send('addBehavior', self.clientId, behaviorId, behavior.behaviorSpec)
        end

        behavior:sendSetProperties({
            to = clientId,
            selfSend = false,
            channel = MAIN_RELIABLE_CHANNEL,
        }, util.unpackPairs(behavior.globals))
    end

    for behaviorId, behavior in pairs(self.behaviors) do
        behavior:callHandler('preSyncClient', clientId)
    end

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
            }, util.unpackPairs(component.properties))
        end
    end

    for behaviorId, behavior in pairs(self.behaviors) do
        behavior:callHandler('postSyncClient', clientId)
    end


    -- Performance

    send('setPerforming', self.performing)
end

function Server:connect(clientId)
    self:syncClient(clientId)
end

function Server:reconnect(clientId)
    self:syncClient(clientId)
end

function Server:disconnect(clientId)
    -- Clear tool components for this client
    for behaviorId, tool in pairs(self.tools) do
        for actorId, component in pairs(tool.components) do
            if component.clientId == clientId then
                self:send('removeComponent', self.clientId, actorId, behaviorId)
            end
        end
    end
end


-- Update

function Server:update(dt)
    Common.update(self, dt)
end
