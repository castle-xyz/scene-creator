ui = castle.ui


UNIT = 1
MAX_BODY_SIZE = UNIT * 40
MIN_BODY_SIZE = UNIT / 4
DEFAULT_VIEW_WIDTH = 9 * UNIT
MIN_VIEW_WIDTH = DEFAULT_VIEW_WIDTH / 10
MAX_VIEW_WIDTH = DEFAULT_VIEW_WIDTH * 4

CHECKERBOARD_IMAGE_URL = 'https://raw.githubusercontent.com/nikki93/edit-world/4c9d0d6f92b3a67879c7a5714e6608530093b45a/assets/checkerboard.png'


serpent = require 'https://raw.githubusercontent.com/pkulchenko/serpent/879580fb21933f63eb23ece7d60ba2349a8d2848/src/serpent.lua'
bitser = require 'https://raw.githubusercontent.com/gvx/bitser/214ad35f62d5abbc0c9a421287aa0964f6f63003/bitser.lua'

jsEvents = require '__ghost__.jsEvents'
jsBridge = require '__ghost__.bridge'
cjson = require 'cjson'
copas = require 'copas'


-- Modules

if not castle.system.isRemoteServer() then
    tove = require 'lib.tove'
end

resource_loader = require 'resource_loader'
util = require 'util'
helps = require 'helps'


require 'actor_behavior'

require 'behaviors.body'

require 'behaviors.image'
require 'behaviors.drawing'

require 'behaviors.circle_shape'

require 'behaviors.solid'
require 'behaviors.bouncy'

require 'behaviors.moving'
require 'behaviors.falling'
require 'behaviors.rotating_motion'
require 'behaviors.sling'

require 'tools.grab'
require 'tools.draw'


require 'library'
require 'snapshot'
require 'command'


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
    self:defineMessageKind('ping', {
        reliable = true,
        channel = self.channels.secondaryReliable,
        selfSend = true,
        forward = true,
    })


    self:defineActorBehaviorMessageKinds()
    self:defineLibraryMessageKinds()
    self:defineSnapshotMessageKinds()


    self:defineMessageKind('setPerforming', self.sendOpts.reliableToAll)
    self:defineMessageKind('setPaused', self.sendOpts.reliableToAll)

    self:defineMessageKind('ready', {
        from = 'server',
        reliable = true,
        channel = self.channels.mainReliable,
        selfSend = false,
        forward = false,
    })
end


-- Start / stop

function Common:start()
    self.mes = {}
    self.lastPingTimes = {}

    self:startActorBehavior()
    self:startLibrary()
    self:startSnapshot()
    self:startCommand()

    self.performing = true
    self.paused = true
end

function Common:stop()
    self:stopActorBehavior()
end


-- Users

function Common.receivers:me(time, clientId, me)
    self.mes[clientId] = me
end

function Common.receivers:ping(time, clientId)
    self.lastPingTimes[clientId] = time
end


-- Performance

function Common:updatePerformance(dt)
    if self.performing and not self.paused then
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

function Common.receivers:setPaused(time, paused)
    if self.paused ~= paused then
        self.paused = paused
        self:callHandlers('setPaused', paused)
    end
end

