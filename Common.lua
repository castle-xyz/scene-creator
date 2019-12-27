local Physics = require 'multi.physics'


love.physics.setMeter(64)


MAIN_RELIABLE_CHANNEL = 0


-- Define

function Game.Common:define()
    --
    -- User
    --

    -- Client sends user profile info when it connects, forwarded to all and self
    self:defineMessageKind('me', {
        reliable = true,
        channel = MAIN_RELIABLE_CHANNEL,
        selfSend = true,
        forward = true,
    })

    --
    -- Players
    --

    -- Server sends add or remove player events to all
    self:defineMessageKind('addPlayer', {
        to = 'all',
        reliable = true,
        channel = MAIN_RELIABLE_CHANNEL,
        selfSend = true,
    })
    self:defineMessageKind('removePlayer', {
        to = 'all',
        reliable = true,
        channel = MAIN_RELIABLE_CHANNEL,
        selfSend = true,
    })
end


-- Start / stop

function Game.Common:startPhysics()
    if self.physics then
        local worldId, world = self.physics:getWorld()
        world:destroy()
    end
    self.physics = Physics.new({
        game = self,
        reliableChannel = MAIN_RELIABLE_CHANNEL,
    })
end

function Game.Common:start()
    self:startPhysics()

    self.mes = {}
    self.players = {}
end


-- Mes

function Game.Common.receivers:me(time, clientId, me)
    self.mes[clientId] = me
end


-- Players

function Game.Common.receivers:addPlayer(time, clientId, bodyId)
    local player = {
        clientId = clientId,
        bodyId = bodyId,
    }

    self.players[clientId] = player
end

function Game.Common.receivers:removePlayer(time, clientId)
    self.players[clientId] = nil
end


-- Update

function Game.Common:update(dt)
    -- Update physics
    local worldId, world = self.physics:getWorld()
    if worldId then
        self.physics:updateWorld(worldId, dt)
        self.physics:sendSyncs(worldId)
    end
end
