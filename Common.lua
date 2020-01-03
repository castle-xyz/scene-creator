local Physics = require 'multi.physics'


love.physics.setMeter(64)


MAIN_RELIABLE_CHANNEL = 0
SECONDARY_RELIABLE_CHANNEL = 99


-- Behavior base

local Behavior = {}

function Behavior:setProperties(opts, ...)
    local actorId
    if type(opts) == 'table' then
        actorId = opts.actorId
    else
        actorId = opts
    end

    local function replaceNames(name, value, ...)
        if name ~= nil then
            local id = self.propertyIds[name]
            if not id then
                error("behavior '" .. self.name .. "' has no property named '" .. name .. "'")
            end
            return id, value, replaceNames(...)
        end
    end

    self.game:send(opts, actorId, self.behaviorId, replaceNames(...))
end


-- Core behaviors

local BodyBehavior = {
    name = 'body',
    propertyNames = {
        'worldId',
    },
}

function BodyBehavior.handlers:addBehavior()
    self._physics = Physics.new({
        game = self.game,
        updateRate = 120,
        reliableChannel = MAIN_RELIABLE_CHANNEL,
    })

    if self.game.server then
        self:setProperties(nil, 'worldId', self._physics:newWorld(0, 32 * 64, true))
    end
end

function BodyBehavior.handlers:removeBehavior()
    self._physics:objectForId(self.globals.worldId):destroy()
end

function BodyBehavior.handlers:preSyncClient(clientId)
    self._physics:syncNewClient({
        clientId = clientId,
        channel = MAIN_RELIABLE_CHANNEL,
    })
end

function BodyBehavior.handlers:addComponent(component)
    -- TODO(nikki): If server, create body and set `bodyId`
end

function BodyBehavior.handlers:removeComponent(component)
    -- TODO(nikki): If server, destroy body
end


local ImageBehavior = {
    name = 'image',
    propertyNames = {
        'url',
    },
}


CORE_BEHAVIORS = {
    BodyBehavior,
    ImageBehavior,
}


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
    local reliableToAll = {
        to = 'all',
        reliable = true,
        channel = MAIN_RELIABLE_CHANNEL,
        selfSend = true,
        forward = true,
        rate = 20,
    }
    self:defineMessageKind('addActor', reliableToAll)
    self:defineMessageKind('removeActor', reliableToAll)
    self:defineMessageKind('addBehavior', reliableToAll)
    self:defineMessageKind('removeBehavior', reliableToAll)
    self:defineMessageKind('addComponent', reliableToAll)
    self:defineMessageKind('removeComponent', reliableToAll)
    self:defineMessageKind('setProperties', reliableToAll)
end


-- Start / stop

function Common:start()
    -- Shared initialization


    -- Physics

    self:startPhysics()


    -- Users

    self.mes = {}


    -- Actors / behaviors

    self.actors = {} -- `actorId` -> actor-level properties
    self.behaviors = {} -- `behaviorId` -> behavior-global properties
    self.actorBehaviorComponent = {} -- `actorId` -> `behaviorId` -> component
    self.behaviorActorComponent = {} -- `behaviorId` -> `actorId` -> component

    for behaviorId, behaviorSpec in pairs(CORE_BEHAVIORS) do
        self.receivers.addBehavior(self, 0, behaviorId, behaviorSpec)
    end
end

function Common:stop()
    for behaviorId, behavior in pairs(self.behaviors) do
        self.receivers.removeBehavior(self, 0, behaviorId)
    end
end


-- Users

function Common.receivers:me(time, clientId, me)
    self.mes[clientId] = me
end


-- Actors / behaviors

function Common.receivers:addActor(time, actorId)
    assert(not self.actors[actorId], 'addActor: this `actorId` is already used')

    self.actors[actorId] = {}

    self.actorBehaviorComponent[actorId] = {}
end

function Common.receivers:removeActor(time, actorId)
    assert(self.actors[actorId], 'removeActor: no such actor')

    for behaviorId in pairs(self.actorBehaviorComponent) do
        self.behaviorActorComponent[behaviorId][actorId] = nil
    end
    self.actorBehaviorComponent[actorId] = nil

    self.actors[actorId] = nil
end

function Common.receivers:addBehavior(time, behaviorId, behaviorSpec)
    assert(not self.behaviors[behaviorId], 'addBehavior: this `behaviorId` is already used')
    assert(behaviorSpec, 'addBehavior: need a `behaviorSpec`')

    -- Basics
    local behavior = setmetatable({}, { __index = Behavior })
    behavior.behaviorId = behaviorId
    behavior.behaviorSpec = behaviorSpec
    behavior.name = behaviorSpec.name
    behavior.game = self
    behavior.globals = {}

    -- Copy property names
    behavior.propertyIds
    behavior.propertyNames = {}
    for propertyId, propertyName in ipairs(behaviorSpec.propertyNames) do
        behavior.propertyIds[propertyName] = propertyId
        behavior.propertyNames[propertyId] = propertyName
    end

    -- Copy handlers and setters
    behavior.handlers = {}
    if behaviorSpec.handlers then
        for handlerName, handler in pairs(behaviorSpec.handlers) do
            behavior.handlers[handlerName] = handler
        end
    end
    behavior.setters = {}
    if behaviorSpec.setters then
        for setterName, setter in pairs(behaviorSpec.setters) do
            behavior.setters[setterName] = setter
        end
    end

    -- Set in maps
    self.behaviors[behaviorId] = behavior
    self.behaviorActorComponent[behaviorId] = {}

    -- Notify `addBehavior`
    if behavior.handlers.addBehavior then
        behavior.handlers.addBehavior(behavior)
    end
end

function Common.receivers:removeBehavior(time, behaviorId)
    assert(self.behaviors[behaviorId], 'removeBehavior: this `behaviorId` is already used')

    -- Notify `removeBehavior`
    if behavior.handlers.removeBehavior then
        behavior.handlers.removeBehavior(behavior)
    end

    -- Unset in maps
    for actorId in pairs(self.behaviorActorComponent) do
        self.actorBehaviorComponent[actorId][behaviorId] = nil
    end
    self.behaviorActorComponent[behaviorId] = nil
    self.behaviors[behaviorId] = nil
end

function Common.receivers:addComponent(time, actorId, behaviorId)
    assert(self.actors[actorId], 'addComponent: no such actor')
    local behavior = assert(self.behaviors[behaviorId], 'addComponent: no such behavior')

    -- Basics
    local component = {}
    component.actorId = actorId
    component.properties = {}

    -- Set in maps
    self.actorBehaviorComponent[actorId][behaviorId] = component
    self.behaviorActorComponent[behaviorId][actorId] = component

    -- Notify `addComponent`
    if behavior.handlers.addComponent then
        behavior.handlers.addComponent(behavior, component)
    end
end

function Common.receivers:removeComponent(time, actorId, behaviorId)
    assert(self.actors[actorId], 'removeComponent: no such actor')
    local behavior = assert(self.behaviors[behaviorId], 'removeComponent: no such behavior')

    -- Notify `removeComponent`
    if behavior.handlers.removeComponent then
        local component = self.actorBehaviorComponent[actorId][behaviorId]
        behavior.handlers.removeComponent(behavior, component)
    end

    -- Unset in maps
    self.actorBehaviorComponent[actorId][behaviorId] = nil
    self.behaviorActorComponent[behaviorId][actorId] = nil
end

function Common.receivers:setProperties(time, actorId, behaviorId, ...)
    local behavior = assert(self.behaviors[behaviorId], 'setProperties: no such behavior')

    local component
    if actorId then
        assert(self.actors[actorId], 'setProperties: no such actor')
        component = self.actorBehaviorComponent[actorId][behaviorId]
    end

    for i = 1, select('#', ...), 2 do
        local id, value = select(i, ...)
        local name = behavior.propertyNames[id]
        if not name then
            error('setProperties: bad property id')
        end
        local setter = behavior.setters[name]
        if actorId then
            if setter then
                setter(behavior, component, value)
            else
                component.properties[name] = value
            end
        else
            if setter then
                setter(behavior, value)
            else
                behavior.globals[name] = value
            end
        end
    end
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
