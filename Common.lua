ui = castle.ui

UNIT = 1
MAX_BODY_SIZE = UNIT * 40
MIN_BODY_SIZE = UNIT / 4
DEFAULT_VIEW_WIDTH = 10 * UNIT
MIN_VIEW_WIDTH = DEFAULT_VIEW_WIDTH / 10
MAX_VIEW_WIDTH = DEFAULT_VIEW_WIDTH * 4
VIEW_HEIGHT_TO_WIDTH_RATIO = 7 / 5

CHECKERBOARD_IMAGE_URL =
    "https://raw.githubusercontent.com/nikki93/edit-world/4c9d0d6f92b3a67879c7a5714e6608530093b45a/assets/checkerboard.png"

serpent = require "vendor.serpent"
bitser = require "vendor.bitser"
inspect = require "vendor.inspect"
sfxr = require "vendor.sfxr"

jsEvents = require "__ghost__.jsEvents"
jsBridge = require "__ghost__.bridge"
cjson = require "cjson"
copas = require "copas"

function printObject(obj)
    local result = inspect(obj)
    for s in result:gmatch("[^\r\n]+") do
        print(s)
    end
end

-- Modules

if not castle.system.isRemoteServer() then
    tove = require "vendor.tove"
end

resource_loader = require "resource_loader"
util = require "util"
helps = require "helps"

require "actor_behavior" -- -- -- Message kind definition -- Start / stop

require "behaviors.body"
require "behaviors.image"
require "behaviors.drawing"

require "behaviors.circle_shape"

require "behaviors.solid"
require "behaviors.bouncy"

require "behaviors.moving"
require "behaviors.falling"
require "behaviors.sliding"
require "behaviors.slowdown"
require "behaviors.friction"
require "behaviors.speed_limit"
require "behaviors.rotating_motion"

require "behaviors.sling"
require "behaviors.drag"

require "behaviors.rules"
require "behaviors.tags"
require "behaviors.counter"
require "behaviors.text"

require "behaviors.drawing2"
require "behaviors.analog_stick"

require "tools.grab"

require "tools.drawUtils"
require "tools.draw"
require "tools.draw2"

require "tools.scale_rotate"

require "library"
require "belt"
require "snapshot"
require "command"
require "variables"
require "scene_properties"
require "camera"
require "expressions.expression"
require "expressions.behavior_property"

function Common:start(isPerforming)
    self.onEndOfFrames = {}

    self._nextIdSuffix = 1

    self:startSceneProperties()
    self:startActorBehavior()
    self:startLibrary()
    self:startSnapshot()
    self:startCommand()
    self:startVariables()
    self:startCamera()

    self.performing = isPerforming
    self.paused = false
end

function Common:stop()
    self:stopActorBehavior()
end

function Common:send(opts, ...)
    if type(opts) == "string" then -- Shorthand
        opts = {kind = opts}
    end

    local kind = opts.kind
    assert(type(kind) == "string", "send: `kind` needs to be a string")

    --print("send calling " .. kind .. "()")

    self.receivers[kind](self, 0, ...)
end

function Common:generateId()
    local suffix = tostring(self._nextIdSuffix)
    self._nextIdSuffix = self._nextIdSuffix + 1

    local prefix = "0"

    return prefix .. "-" .. suffix
end

-- Users

function Common.receivers:me(time, clientId, me)
    self.mes[clientId] = me
end
--
--function Common.receivers:ping(time, clientId)
--   self.lastPingTimes[clientId] = time
--end

-- Performance

function Common:updatePerformance(dt)
    if self.performing and not self.paused then
        self:callHandlers("prePerform", dt)
        self:callHandlers("perform", dt)
        self:callHandlers("postPerform", dt)
    end
end

function Common.receivers:setPerforming(time, performing)
    if self.performing ~= performing then
        self.performing = performing
        self:callHandlers("setPerforming", performing)
    end
end

function Common.receivers:setPaused(time, paused)
    if self.paused ~= paused then
        self.paused = paused
        self:callHandlers("setPaused", paused)
    end
end

function Common.receivers:clearScene(time)
    self:callHandlers("clearScene", self.paused)
end
--

-- Methods

function Common:fireOnEndOfFrame()
    local onEndOfFrames = self.onEndOfFrames
    for _, func in ipairs(onEndOfFrames) do
        func()
    end
    self.onEndOfFrames = {}
end
