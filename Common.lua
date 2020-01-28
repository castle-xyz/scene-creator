ui = castle.ui


UNIT = 100
MAX_BODY_SIZE = 40 * UNIT
MIN_BODY_SIZE = UNIT

CHECKERBOARD_IMAGE_URL = 'https://raw.githubusercontent.com/nikki93/edit-world/4c9d0d6f92b3a67879c7a5714e6608530093b45a/assets/checkerboard.png'


serpent = require 'https://raw.githubusercontent.com/pkulchenko/serpent/879580fb21933f63eb23ece7d60ba2349a8d2848/src/serpent.lua'


-- Modules

resource_loader = require 'resource_loader'
util = require 'util'
helps = require 'helps'

require 'actor_behavior'

require 'behaviors.body'
require 'behaviors.image'
require 'tools.grab'
require 'behaviors.solid'
require 'behaviors.circle_shape'
require 'behaviors.free_motion'
require 'behaviors.rotating_motion'
require 'tools.sling'

require 'library'
require 'snapshot'


-- Message kind definition

function Common:define()
    self.channels = {}

    self.channels.mainReliable = 0
    self.channels.secondaryReliable = 99

    self.sendOpts = {}
    self.sendOpts.reliableToAll = {
        to = 'all',
        reliable = true,
        channel = self.channels.mainReliable,
        selfSend = true,
        forward = true,
        rate = 20, -- In case a `reliable = false` override is used
    }


    self:defineMessageKind('me', {
        reliable = true,
        channel = self.channels.secondaryReliable,
        selfSend = true,
        forward = true,
    })


    self:defineActorBehaviorMessageKinds()
    self:defineLibraryMessageKinds()
    self:defineSnapshotMessageKinds()


    self:defineMessageKind('setPerforming', {
        to = 'all',
        reliable = true,
        channel = self.channels.mainReliable,
        selfSend = true,
        forward = true,
        forwardToOrigin = true,
    })
end


-- Start / stop

function Common:start()
    self.mes = {}

    self:startActorBehavior()
    self:startLibrary()
    self:startSnapshot()

    self.performing = false
end

function Common:stop()
    self:stopActorBehavior()
end


-- Users

function Common.receivers:me(time, clientId, me)
    self.mes[clientId] = me
end


-- Performance

function Common:updatePerformance(dt)
    if self.performing then
        self:callHandlers('prePerform', dt)
        self:callHandlers('perform', dt)
        self:callHandlers('postPerform', dt)
    end
end

function Common.receivers:setPerforming(time, performing)
    if self.performing ~= performing then
        self.performing = performing
        self:callHandlers('setPerforming', performing)
    end
end

