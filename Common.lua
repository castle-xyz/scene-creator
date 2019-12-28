local Physics = require 'multi.physics'


love.physics.setMeter(64)


MAIN_RELIABLE_CHANNEL = 0


-- Define

function Common:define()
    -- Mes
    self:defineMessageKind('me', {
        reliable = true,
        channel = MAIN_RELIABLE_CHANNEL,
        selfSend = true,
        forward = true,
    })

    -- Test
    self:defineMessageKind('remove', {
        reliable = true,
        channel = MAIN_RELIABLE_CHANNEL,
        selfSend = false,
        forward = false,
    })
end


-- Start / stop

function Common:startPhysics()
    -- (Re)start physics

    if self.physics then -- Destroy underlying world of old physics
        local worldId, world = self.physics:getWorld()
        world:destroy()
        -- We overwrite `self.physics` below so the old physics module won't
        -- be referred-to anymore
    end

    self.physics = Physics.new({
        game = self,
        updateRate = 120,
        reliableChannel = MAIN_RELIABLE_CHANNEL,
    })
end

function Common:start()
    -- Shared initialization

    self:startPhysics()

    self.mes = {}
end


-- Mes

function Common.receivers:me(time, clientId, me)
    self.mes[clientId] = me
end


-- Update

function Common:update(dt)
    -- Update physics
    local worldId, world = self.physics:getWorld()
    if worldId then
        self.physics:updateWorld(worldId, dt)
        self.physics:sendSyncs(worldId)
    end
end
