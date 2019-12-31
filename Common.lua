local Physics = require 'multi.physics'


love.physics.setMeter(64)


MAIN_RELIABLE_CHANNEL = 0
SECONDARY_RELIABLE_CHANNEL = 99


-- Define

function Common:define()
    -- Users
    self:defineMessageKind('me', {
        reliable = true,
        channel = SECONDARY_RELIABLE_CHANNEL,
        selfSend = true,
        forward = true,
    })

    -- Actors / behaviors
    local actorBehaviorMessageDefaults = {
        to = 'all',
        reliable = true,
        channel = MAIN_RELIABLE_CHANNEL,
        selfSend = true,
        forward = true,
    }
    self:defineMessageKind('addActor', actorBehaviorMessageDefaults)
    self:defineMessageKind('removeActor', actorBehaviorMessageDefaults)
    self:defineMessageKind('linkBehavior', actorBehaviorMessageDefaults)
    self:defineMessageKind('unlinkBehavior', actorBehaviorMessageDefaults)
    self:defineMessageKind('setProperty', actorBehaviorMessageDefaults)
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

    self.actors = {}
    self.behaviors = {}
    self.actorBehaviorComponent = {}
    self.behaviorActorComponent = {}
end


-- Users

function Common.receivers:me(time, clientId, me)
    self.mes[clientId] = me
end


-- Actors / behaviors


-- Update

function Common:update(dt)
    -- Update physics
    local worldId, world = self.physics:getWorld()
    if worldId then
        self.physics:updateWorld(worldId, dt)
        self.physics:sendSyncs(worldId)
    end
end
